#!/bin/bash
set -euo pipefail

source /etc/rancher/k3s/node_vars.env

if [[ "$IS_AGENT" != "true" ]]; then
    echo "This node is not an agent node (IS_AGENT=$IS_AGENT), skipping..."
    exit 0
fi

echo "Joining $HOSTNAME to K3s cluster as worker..."

if [[ ! -f "/var/lib/rancher/k3s/server/token" ]]; then
    echo "K3S token file /var/lib/rancher/k3s/server/token does not exist"
    echo "This file must be present before joining as worker"
    exit 1
fi

K3S_TOKEN=$(cat /var/lib/rancher/k3s/server/token)

echo "⏳ Waiting for cluster API at $VIRTUAL_IP:6443..."
timeout 300 bash -c "until nc -z $VIRTUAL_IP 6443; do
    echo 'Waiting for cluster API...'
    sleep 10
done"

echo "⚙️ Installing K3s agent..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" sh -s - agent

echo "⏳ Waiting for $HOSTNAME to be ready..."
timeout 300 bash -c "until curl -s --connect-timeout 5 http://$VIRTUAL_IP:6443/api/v1/nodes/$HOSTNAME >/dev/null 2>&1; do sleep 5; done"

echo "$HOSTNAME joined cluster successfully!"
echo "Node registered as worker"

# Note: Workers don't get kubeconfig by default - that's managed from control plane
echo "Use kubectl from a control plane node to manage the cluster"