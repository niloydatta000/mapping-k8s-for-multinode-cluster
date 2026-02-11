#!/bin/bash

set -euxo pipefail

# Declaring Important Variables
ARCH="$(dpkg --print-architecture)"
KUBERNETES_VERSION="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
PACKAGE_VERSION="$(echo "${KUBERNETES_VERSION}" | cut -d'.' -f1-2)"

# Installing Prerequisites
sudo apt update
sudo apt install -y curl gpg gnupg software-properties-common apt-transport-https ca-certificates

# Installing Containerd Runtime
echo "deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt update
sudo apt install containerd.io

sudo systemctl daemon-reload
sudo systemctl enable containerd --now
sudo systemctl start containerd.service

echo "Containerd runtime installed successfully"

# Generate the default containerd configuration
sudo containerd config default | sudo tee /etc/containerd/config.toml

# Enable SystemdCgroup clear
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

# Restart containerd to apply changes
sudo systemctl restart containerd

curl -LO "https://github.com/kubernetes-sigs/cri-tools/releases/download/${KUBERNETES_VERSION}/crictl-${KUBERNETES_VERSION}-linux-${ARCH}.tar.gz"
sudo tar zxvf "crictl-${KUBERNETES_VERSION}-linux-${ARCH}.tar.gz" -C /usr/local/bin
rm -f "crictl-${KUBERNETES_VERSION}-linux-${ARCH}.tar.gz"
curl -fsSL "https://pkgs.k8s.io/core:/stable:/${PACKAGE_VERSION}/deb/Release.key" | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/${PACKAGE_VERSION}/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt update && sudo apt install -y kubelet kubeadm kubectl

# Hold kubes from automatic updates
sudo apt-mark hold kubelet kubeadm kubectl
