#!/bin/bash

set -euxo pipefail


# Declare Variables
METALLB_VERSION="v0.14.3"
NGINX_CONTROLLER_VERSION="controller-v1.9.4"


# Enable Strict ARP Mode
kubectl get configmap kube-proxy -n kube-system -o yaml | sed 's/strictARP: false/strictARP: true/' | kubectl apply -f -

# Install MetalLB Infrastructure
curl -L -o metallb.yaml "https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml"
kubectl apply -f metallb.yaml

# Define the IP Address Pool and L2 Advertisement
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: node-ip-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.0.105
  - 192.168.0.110
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: network-announcement
  namespace: metallb-system
spec:
  ipAddressPools:
  - node-ip-pool
EOF

# Deploy the NGINX Ingress Controller
kubectl apply -f "https://raw.githubusercontent.com/kubernetes/ingress-nginx/${NGINX_CONTROLLER_VERSION}/static/provider/cloud/deploy.yaml"

# Verify LoadBalancer Allocation
kubectl get service -n ingress-nginx ingress-nginx-controller

# Finalize Network Synchronization
kubectl rollout restart daemonset kube-proxy -n kube-system
