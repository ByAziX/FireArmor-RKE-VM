# **Proxmox And Cloud-init**

Steps: 
1. Proxmox installation
2. Proxmox cluster
3. Cloud-init VM template

# Proxmox instalation 

To create the bootable USB key you will need to download a [ISO Proxmox](https://www.proxmox.com/en/downloads/category/iso-images-pve) 

From the [Rufus](https://rufus.ie/en/) software choose your USB key and your ISO file (Be careful all the data on the key will be deleted). Then click on the start button.

So, for this exemple we have installed proxmox on 5 mac

# Proxmox cluster

Youtube video of how to make a proxmox cluster : [Proxmox cluster](https://www.youtube.com/watch?v=gDrvdZRdeY8) 


# Cloud-init template


**Creates an SSH key**

We will be using SSH Keys to login to root account on all the kubernetes nodes. I am not going to set a passphrase for this ssh keypair.

Create an ssh keypair on the host machine

```
ssh-keygen -t rsa -b 2048
```

Go to a node of the proxmox cluster, create a script template.sh on it.

modify the script if necessary with the right SSH, characteristic of your VM and [Ubuntu Cloud Images](https://cloud-images.ubuntu.com/releases/)

run this script [template.sh]()

> template.sh 
```
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

# Resize the primary boot disk
qm resize ${ID_TEMPLATE} scsi0 +20G

echo "[TEMPLATE] set to template"

# Convert the VM to the template
#qm template ${ID_TEMPLATE}

echo "[TEMPLATE] Successful"
```

**click on the vm that has just been created look on the right panel for cloud-init and change the password**



**Then start the VM 1015 and add its commands in the terminal**

Allows you to do the basic configuration :

```
sudo ufw disable
swapoff -a; sed -i '/swap/d' /etc/fstab

cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

sudo apt-get update

sudo apt-get install \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update

sudo apt-get install docker-ce docker-ce-cli containerd.io docker-compose-plugin

sudo docker run hello-world


sudo usermod -aG docker ${USER}

su - ${USER}

id -nG

sudo chmod 666 /var/run/docker.sock
```

Allows to remove the same machine id at each vm creation :
```
sudo cloud-init clean
sudo rm -rf /var/lib/cloud/instances
sudo truncate -s 0 /etc/machine-id
sudo rm /var/lib/dbus/machine-id
sudo ln -s /etc/machine-id /var/lib/dbus/machine-id
ls -l /var/lib/dbus/machine-id
cat /etc/machine-id
```


**Turn off the VM then execute this command in the proxmox node**

Create Template :
```
qm template 1015
```

Create VM from the template :
```
qm clone 1015 100 --name worker1 --full 1
```


**Ok it's over but you can create infinite VMs with this template.**

**Next step [RKE2 cluster]()** 





# Sources

https://pve.proxmox.com/pve-docs/

https://pve.proxmox.com/pve-docs/qm.1.html

https://github.com/justmeandopensource/kubernetes/tree/master/rancher/rke

https://docs.docker.com/engine/install/ubuntu/

https://docs.docker.com/engine/install/ubuntu/#install-using-the-repository

