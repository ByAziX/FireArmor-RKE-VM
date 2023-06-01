#!/bin/bash

hostname="Fire"
ip_master1="10.10.10.146"
ip_master2="10.10.10.48"  # Assuming these are the IP addresses
ip_master3="10.10.10.74"
ip_worker1="10.10.10.100"
ip_worker2="10.10.10.32"

password="FarmorD3v"


# Function to set up master1 node
function setup_master1() {

    touch master.yaml
    chmod u+w master.yaml 

    cat > master.yaml << EOF
tls-san:
- master1
- 10.10.10.175
disable:
  - rke2-canal
  - rke2-ingress-nginx
  - rke2-kube-proxy
cni:
- cilium
EOF

    sudo -s
    mkdir -p /etc/rancher/rke2
    cp master.yaml /etc/rancher/rke2/config.yaml
    curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION="v1.26.0%2Brke2r2" sh -
    systemctl enable rke2-server
    systemctl start rke2-server
    
    # Wait for master1 to be ready
    while true; do
        if kubectl get nodes | grep master1 | grep -q ' Ready'; then
            break
        fi
        echo "Waiting for master1 to be ready..."
        sleep 10
    done
    
    cat << EOF >> ~/.bashrc
export VIP=10.10.10.175
export TAG=v0.3.8
export INTERFACE=eth0
export CONTAINER_RUNTIME_ENDPOINT=unix:///run/k3s/containerd/containerd.sock
export CONTAINERD_ADDRESS=/run/k3s/containerd/containerd.sock
export PATH=/var/lib/rancher/rke2/bin:\$PATH
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
alias k=kubectl
ln -fs /var/lib/rancher/rke2/bin/{kubectl,crictl,ctr} /usr/local/bin/
EOF
    source ~/.bashrc
    kubectl get nodes -w

}



# Function to connect to nodes via SSH as root
function connect_to_nodes() {
    # Start master1
    echo "Starting master1..."
    sshpass -p "$password" ssh -tt $hostname@$ip_master1 "echo $password | sudo -S bash -c '$(declare -f setup_master1 install_kube_vip save_master1_token); setup_master1; install_kube_vip; save_master1_token'"
    echo "master1 is ready"

    # Once master1 is ready, start the rest of the nodes
    echo "Starting master2..."
    sshpass -p "$password" ssh -tt $hostname@$ip_master2 "echo $password | sudo -S bash -c '$(declare -f configure_master2); configure_master2'"
    echo "master2 is ready"
    
    echo "Starting master3..."
    sshpass -p "$password" ssh -tt $hostname@$ip_master3 "echo $password | sudo -S bash -c '$(declare -f configure_master2); configure_master2'"
    echo "master3 is ready"

    echo "Starting worker1..."
    sshpass -p "$password" ssh -tt $hostname@$ip_worker1 "echo $password | sudo -S bash -c '$(declare -f configure_worker); configure_worker'"
    echo "worker1 is ready"

    echo "Starting worker2..."
    sshpass -p "$password" ssh -tt $hostname@$ip_worker2 "echo $password | sudo -S bash -c '$(declare -f configure_worker); configure_worker'"
    echo "worker2 is ready"
}




# Call the function to connect to nodes



# Function to install Kube-VIP
function install_kube_vip() {
    curl -s https://kube-vip.io/manifests/rbac.yaml > /var/lib/rancher/rke2/server/manifests/kube-vip-rbac.yaml
    crictl pull docker.io/plndr/kube-vip:$TAG
    alias kube-vip="ctr --namespace k8s.io run --rm --net-host docker.io/plndr/kube-vip:$TAG vip /kube-vip"
    kube-vip manifest daemonset \
        --arp \
        --interface $INTERFACE \
        --address $VIP \
        --controlplane \
        --leaderElection \
        --taint \
        --services \
        --inCluster | tee /var/lib/rancher/rke2/server/manifests/kube-vip.yaml
}

# Function to save the token from master1
function save_master1_token() {
    token=$(cat /var/lib/rancher/rke2/server/node-token)
}

# Function to configure master2 node
function configure_master2() {
    cat > master.yaml << EOF
token: $token
server: https://10.10.10.175:9345
tls-san:
- 10.10.10.175
disable: 
- rke2-ingress-nginx
- rke2-kube-proxy
cni:
- cilium
EOF

    cat << EOF >> ~/.bashrc
export VIP=10.10.10.175
export TAG=v0.3.8
export INTERFACE=eth0
export CONTAINER_RUNTIME_ENDPOINT=unix:///run/k3s/containerd/containerd.sock
export CONTAINERD_ADDRESS=/run/k3s/containerd/containerd.sock
export PATH=/var/lib/rancher/rke2/bin:\$PATH
export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
alias k=kubectl
ln -fs /var/lib/rancher/rke2/bin/{kubectl,crictl,ctr} /usr/local/bin/
EOF
    source ~/.bashrc

    mkdir -p /etc/rancher/rke2
    cp master.yaml /etc/rancher/rke2/config.yaml
    curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION="v1.26.0%2Brke2r2" sh -
    systemctl enable rke2-server
    systemctl start rke2-server
    kubectl get nodes
}

# Function to configure worker node
function configure_worker() {
    cat > worker.yaml << EOF
token: $token
server: https://10.10.10.175:9345
tls-san:
- 10.10.10.175
disable: 
- rke2-ingress-nginx
- rke2-kube-proxy
cni:
- cilium
EOF

    export CONTAINER_RUNTIME_ENDPOINT=unix:///run/k3s/containerd/containerd.sock
    export CONTAINERD_ADDRESS=/run/k3s/containerd/containerd.sock
    export PATH=/var/lib/rancher/rke2/bin:$PATH
    export KUBECONFIG=/etc/rancher/rke2/rke2.yaml
    alias k=kubectl

    sudo -s
    mkdir -p /etc/rancher/rke2
    cp worker.yaml /etc/rancher/rke2/config.yaml
    curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" INSTALL_RKE2_VERSION="v1.26.0%2Brke2r2" sh -
    systemctl start rke2-agent.service
}

# Function to check cilium status
function check_cilium_status() {
    curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz{,.sha256sum}
    sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
    sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin
    cilium status
}

# Function to check pods and nodes
function check_pods_and_nodes() {
    kubectl get pods -o wide                      # List all pods in the current namespace, with more details
    kubectl get nodes                             # List all nodes in the
}

# Call your functions
connect_to_nodes
check_cilium_status
check_pods_and_nodes