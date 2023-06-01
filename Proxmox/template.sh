#!/bin/bash

# Variables

ID_TEMPLATE=1015
NAME_TEMPLATE="Worker-template"
RAM=4096
SOCKETS=1
CORES=2
SSH_KEY="/root/.ssh/id_rsa.pub"


# if fichier ubuntu-22.04-cloudinit-template exist
if [ -f "ubuntu-22.04-server-cloudimg-amd64-disk-kvm.img" ]; then
    echo "[TEMPLATE] file already exists"
else
    echo "[TEMPLATE] file not found"
    wget https://cloud-images.ubuntu.com/releases/22.04/release/ubuntu-22.04-server-cloudimg-amd64-disk-kvm.img
fi

# if il existe déjà un template sous le même nom et id on le supprime
if [ -f "/etc/pve/qemu-server/${ID_TEMPLATE}.conf" ]; then
    echo "[TEMPLATE] template already exists"
    exit 1
fi

echo "[TEMPLATE] create template"

# Create the instance
qm create ${ID_TEMPLATE} -name ${NAME_TEMPLATE} -memory ${RAM} -net0 virtio,bridge=vmbr0,firewall=1 -cores ${CORES} -sockets ${SOCKETS}

# Import the OpenStack disk image to Proxmox storage
qm importdisk ${ID_TEMPLATE} ubuntu-22.04-server-cloudimg-amd64-disk-kvm.img local-lvm

# Attach the disk to the virtual machine
qm set ${ID_TEMPLATE} -scsihw virtio-scsi-pci -scsi0 local-lvm:vm-${ID_TEMPLATE}-disk-0

qm set ${ID_TEMPLATE} -ipconfig0 ip=dhcp

# Set the bootdisk to the imported Openstack disk
qm set ${ID_TEMPLATE} -boot c -bootdisk scsi0

# Allow hotplugging of network, USB and disks
qm set ${ID_TEMPLATE} -hotplug disk,network,usb

# Enable the Qemu agent
qm set ${ID_TEMPLATE} -agent 1

# Add serial output and a video output
qm set ${ID_TEMPLATE} -serial0 socket -vga serial0

# Set a second hard drive, using the inbuilt cloudinit drive
qm set ${ID_TEMPLATE} -ide2 local-lvm:cloudinit

#qm set $ID_TEMPLATE -vmgenid 1
qm set $ID_TEMPLATE -ciuser Fire
qm set $ID_TEMPLATE -sshkey $SSH_KEY

# Enable cloud-init
#qm set ${ID_TEMPLATE} --cicustom "user=local:snippets/cloudinit.yaml"

# Resize the primary boot disk
qm resize ${ID_TEMPLATE} scsi0 +20G


echo "[TEMPLATE] set to template"

# Convert the VM to the template
#qm template ${ID_TEMPLATE}

echo "[TEMPLATE] Successful"