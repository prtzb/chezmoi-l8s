#!/bin/bash
set -euo pipefail

source /etc/rancher/k3s/node_vars.env

if [[ "$IS_BOOTSTRAP" != "true" ]]; then
    echo "This node is not the bootstrap node (IS_BOOTSTRAP=$IS_BOOTSTRAP), skipping..."
    exit 0
fi

echo "Bootstrapping K3s cluster on $HOSTNAME..."

if [[ ! -f "/var/lib/rancher/k3s/server/token" ]]; then
    echo "K3S token file /var/lib/rancher/k3s/server/token does not exist"
    echo "This file must be present before running K3s bootstrap"
    exit 1
fi

K3S_TOKEN=$(cat /var/lib/rancher/k3s/server/token)

echo "Installing K3s server..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" K3S_TOKEN="$K3S_TOKEN" sh -s - server

echo "Setting up kubeconfig..."
mkdir -p ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config

echo "K3s server bootstrapped successfully"
echo "API server is running, waiting for CNI installation to complete node readiness"

echo ""
echo "Cluster token for other nodes: $K3S_TOKEN"
echo "Bootstrap complete - CNI installation will follow"