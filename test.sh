#!/bin/bash 

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y git wget net-tools

# Prereqs

modprobe overlay
modprobe br_netfilter


swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system


# Install Containerd as Runtime
apt-get install -yq \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg-agent \
    gnupg \
    software-properties-common
    
mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
   
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" |  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt-get update

apt-get install -yq containerd.io

containerd config default |  tee /etc/containerd/config.toml >/dev/null 2>&1
sed -i 's/SystemdCgroup \= false/SystemdCgroup \= true/g' /etc/containerd/config.toml

systemctl restart containerd
systemctl enable containerd

# Install kubeadm, kubectl and kubelet

KUBERNETES_VERSION=1.29

sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$KUBERNETES_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$KUBERNETES_VERSION/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list


apt-get update -y

apt-get install -y  kubelet kubeadm kubectl kubernetes-cni nfs-common

# Set the Hostname to master
sudo hostnamectl set-hostname master$(hostname -i)

# Initailize the cluster
sudo kubeadm init --pod-network-cidr=192.168.0.0/16 --upload-certs --control-plane-endpoint $(hostname -I | awk '{print $1}'):6443 > /home/ubuntu/output.log 2>&1

# Give ubuntu access to the kubernetes configuration file
sudo su -c 'mkdir -p $HOME/.kube' ubuntu
sudo su -c 'sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config' ubuntu
sudo su -c 'sudo chown $(id -u):$(id -g) $HOME/.kube/config' ubuntu

# Install weave work pod network
sudo su -c 'kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml' ubuntu