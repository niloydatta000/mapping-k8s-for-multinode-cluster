# Infrastructure Exposure: MetalLB and NGINX Ingress

## Enable Strict ARP Mode

MetalLB requires the cluster's network proxy to ignore `ARP` requests for the `LoadBalancer` IPs so that MetalLB can handle them directly. Without this, the Linux kernel might respond incorrectly, causing intermittent connectivity.

```bash
kubectl get configmap kube-proxy -n kube-system -o yaml | \
sed 's/strictARP: false/strictARP: true/' | \
kubectl apply -f -
```

## Install MetalLB Infrastructure

This deploys the speakers (which announce IPs to your network) and the controller (which assigns IPs to services). We use a verified stable version to ensure cluster reliability.

```bash
export METALLB_VERSION="v0.14.3"
curl -L -o metallb.yaml "https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/manifests/metallb-native.yaml"
kubectl apply -f metallb.yaml
```

## Define the IP Address Pool and L2 Advertisement

This configuration tells the cluster which specific IPs it is allowed to use for the `LoadBalancer` service type. The Advertisement layer ensures these IPs are reachable from outside the cluster.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: node-ip-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.0.105-192.168.0.110
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
```

## Deploy the NGINX Ingress Controller

The Ingress Controller acts as the "Front Door." While [MetalLB](https://github.com/metallb/metallb) provides the IP address, [NGINX](https://github.com/kubernetes/ingress-nginx) looks at the HTTP host header (e.g., `my-app.com`) to decide which internal service should receive the traffic.

```bash
export NGINX_CONTROLLER_VERSION="controller-v1.9.4"
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/${NGINX_CONTROLLER_VERSION}/deploy/static/provider/cloud/deploy.yaml
```

## Verify LoadBalancer Allocation
We must confirm that the NGINX service has successfully requested and received an IP from our defined `node-ip-pool`.

```bash
kubectl get service -n ingress-nginx ingress-nginx-controller
```
> **Note:** The EXTERNAL-IP should now display `192.168.0.105`.

## Finalize Network Synchronization

We must ensure all nodes are aware of the new strictARP settings and are correctly routing traffic to the Ingress pods, we perform a rolling restart of the network daemonset.

```bash
kubectl rollout restart daemonset kube-proxy -n kube-system
```

## Conclusion

This architecture utilizes **Layer 2 (ARP)** Advertisement. It allows a 3-node cluster to provide a `LoadBalancer` experience without external hardware. The External IP assigned to the **`NGINX` Ingress** is a Virtual IP managed by the MetalLB speakers running as a DaemonSet across the worker nodes.
