#!/bin/bash
set -euo pipefail

source /etc/rancher/k3s/node_vars.env

if [[ "$IS_SERVER" != "true" ]]; then
    echo "This node is not a server node (IS_SERVER=$IS_SERVER), skipping..."
    exit 0
fi

if [[ "$IS_BOOTSTRAP" == "true" ]]; then
    echo "This is the bootstrap node (IS_BOOTSTRAP=$IS_BOOTSTRAP), skipping join..."
    exit 0
fi

echo "Joining $HOSTNAME to K3s cluster as control plane..."

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

echo "⏳ Waiting for K3s API at $VIRTUAL_IP:6443..."
timeout 300 bash -c "until nc -z $VIRTUAL_IP 6443; do
    echo 'Waiting for K3s API...'
    sleep 10
done"

echo "Installing K3s server and joining cluster..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" K3S_TOKEN="$K3S_TOKEN" sh -s - server

echo "Waiting for $HOSTNAME to be ready..."
timeout 300 bash -c "until k3s kubectl get node/$HOSTNAME >/dev/null 2>&1; do sleep 5; done"
k3s kubectl wait --for=condition=Ready "node/$HOSTNAME" --timeout=300s

echo "Setting up kubeconfig..."
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config

sed -i "s/127.0.0.1/$VIRTUAL_IP/g" ~/.kube/config

echo "$HOSTNAME joined cluster successfully!"
echo "Cluster nodes:"
kubectl get nodes -o wide