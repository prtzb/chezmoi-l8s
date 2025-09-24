#!/bin/bash
set -euo pipefail

# Source node configuration
source /etc/rancher/k3s/node_vars.env

# Exit early if this is not a server node or if it's the bootstrap node
if [[ "$IS_SERVER" != "true" ]]; then
    echo "This node is not a server node (IS_SERVER=$IS_SERVER), skipping..."
    exit 0
fi

if [[ "$IS_BOOTSTRAP" == "true" ]]; then
    echo "This is the bootstrap node (IS_BOOTSTRAP=$IS_BOOTSTRAP), skipping join..."
    exit 0
fi

# Join control plane node to K3s cluster
echo "Joining $HOSTNAME to K3s cluster as control plane..."

# Verify K3S token file exists
if [[ ! -f "/var/lib/rancher/k3s/server/token" ]]; then
    echo "K3S token file /var/lib/rancher/k3s/server/token does not exist"
    echo "This file must be present before joining control plane"
    exit 1
fi

K3S_TOKEN=$(cat /var/lib/rancher/k3s/server/token)

# Wait for virtual IP to be available (bootstrap node should have it)
echo "⏳ Waiting for virtual IP $VIRTUAL_IP to be available..."
timeout 300 bash -c "until ping -c 1 $VIRTUAL_IP >/dev/null 2>&1; do
    echo 'Waiting for virtual IP...'
    sleep 10
done"

# Wait for K3s API to be available
echo "⏳ Waiting for K3s API at $VIRTUAL_IP:6443..."
timeout 300 bash -c "until nc -z $VIRTUAL_IP 6443; do
    echo 'Waiting for K3s API...'
    sleep 10
done"

# Install K3s server (joining existing cluster)
echo "Installing K3s server and joining cluster..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" K3S_TOKEN="$K3S_TOKEN" sh -s - server

# Wait for this node to be ready
echo "Waiting for $HOSTNAME to be ready..."
timeout 300 bash -c "until sudo k3s kubectl get node/$HOSTNAME >/dev/null 2>&1; do sleep 5; done"
sudo k3s kubectl wait --for=condition=Ready "node/$HOSTNAME" --timeout=300s

# Copy kubeconfig with proper permissions
echo "Setting up kubeconfig..."
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config

# Update kubeconfig to use virtual IP
sed -i "s/127.0.0.1/$VIRTUAL_IP/g" ~/.kube/config

# Display cluster info
echo "$HOSTNAME joined cluster successfully!"
echo "Cluster nodes:"
kubectl get nodes -o wide