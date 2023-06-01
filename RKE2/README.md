This README provides a set of commands to set up a Kubernetes cluster using RKE2 and Kube-VIP. The cluster consists of three master nodes and two worker nodes.

# Prerequisites
- 5 Linux-based machines (virtual or physical) running Ubuntu 20.04
- Root access to all machines

# Steps :
## On all nodes :

1. Connect to each node via SSH as the root user

# On master1 :


 2. Create a file named `master.yaml` and copy the following content into it:


    ```
    tls-san:
    - master1
    - 10.10.10.175
    disable:
        - rke2-canal
        - rke2-ingress-nginx
        - rke2-kube-proxy
    cni:
    - cilium
    ```

 3. Install RKE2 by running the following commands:

    ```
    sudo -s
    mkdir -p /etc/rancher/rke2
    cp master.yaml /etc/rancher/rke2/config.yaml
    curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION="v1.26.0%2Brke2r2" sh -
    systemctl enable rke2-server
    systemctl start rke2-server
    ```

4. Wait for RKE2 to be ready


5. Add in the `~/.bashrc` : 

    ```
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
    ```


6. Run the following command to check if the nodes are ready:

    ```
    kubectl get nodes -w
    ```


# Kube-VIP Installation

# Set up environment


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


## check logs

```k get po -n kube-system | grep kube-vip```

>root@demo-a:~# k get po -n kube-system | grep kube-vip
>kube-vip-ds-8595m                           1/1     Running     0          48s

```k logs kube-vip-ds-9lmkl -n kube-system --tail 1```

>root@demo-a:~# k logs kube-vip-ds-8595m -n kube-system --tail 1
>time="2023-01-15T12:18:34Z" level=info msg="Broadcasting ARP update for 10.10.10.175 (be:40:66:0a:87:f9) via eth0"

```ping $VIP```

>PING 10.10.10.175 (10.10.10.175) 56(84) bytes of data.
>64 bytes from 10.10.10.175: icmp_seq=1 ttl=64 time=0.198 ms
>64 bytes from 10.10.10.175: icmp_seq=2 ttl=64 time=0.039 ms


### Save Token from master 1  !!!


    cat /var/lib/rancher/rke2/server/node-token

> K1072d3bd38fb9dcfd7283ff63bcec4b2cf9aab7e9150871a5450abc69aabb30296::server:24ff086eee4c88db2a603250b4ddc0f8


# Master 2

    cat > master.yaml<<'EOF'
    token: K1072d3bd38fb9dcfd7283ff63bcec4b2cf9aab7e9150871a5450abc69aabb30296::server:24ff086eee4c88db2a603250b4ddc0f8
    server: https://10.10.10.175:9345
    tls-san:
    - 10.10.10.175
    disable: 
    - rke2-ingress-nginx
    - rke2-kube-proxy
    cni:
    - cilium
    EOF

## Add in the `~/.bashrc` : 

    ```
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
    ```

### Run Master2 

    mkdir -p /etc/rancher/rke2
    cp master.yaml /etc/rancher/rke2/config.yaml
    curl -sfL https://get.rke2.io | INSTALL_RKE2_VERSION="v1.26.0%2Brke2r2" sh -
    systemctl enable rke2-server
    systemctl start rke2-server
    kubectl get nodes

### Kube-VIP Installation

#### Set up environment


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





# On master1 :

    kubectl get nodes -w
    k get po -n kube-system | grep kube-vip
    k logs kube-vip-ds-9lmkl -n kube-system --tail 1

# on Master2:

    cp /etc/rancher/rke2/rke2.yaml .
    nano rke2.yaml

> change 127.0.0.1:6443 -> 10.10.10.175

    k --kubeconfig ./rke2.yaml get no



# Worker 

    cat > worker.yaml<<'EOF'
    token: K1072d3bd38fb9dcfd7283ff63bcec4b2cf9aab7e9150871a5450abc69aabb30296::server:24ff086eee4c88db2a603250b4ddc0f8
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


# cilium check 

    curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/latest/download/cilium-linux-amd64.tar.gz{,.sha256sum}
    sha256sum --check cilium-linux-amd64.tar.gz.sha256sum
    sudo tar xzvfC cilium-linux-amd64.tar.gz /usr/local/bin

    cilium status



# check pods and nodes

kubectl get pods -o wide                      # List all pods in the current namespace, with more details
kubectl get nodes -w
