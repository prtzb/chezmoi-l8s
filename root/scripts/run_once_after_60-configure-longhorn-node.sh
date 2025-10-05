#!/bin/bash
set -euo pipefail

source /etc/rancher/k3s/node_vars.env

echo "Configuring Longhorn node annotations for $HOSTNAME..."

until command -v kubectl &> /dev/null; do
    echo "Waiting for kubectl..."
    sleep 2
done

until kubectl get node "$HOSTNAME" &> /dev/null; do
    echo "Waiting for node $HOSTNAME to be registered..."
    sleep 5
done

echo "Waiting for Longhorn deployment..."
until kubectl get namespace longhorn-system &> /dev/null; do
    echo "Waiting for longhorn-system namespace..."
    sleep 10
done

echo "Waiting for Longhorn manager to be ready..."
until kubectl get pods -n longhorn-system -l app=longhorn-manager --field-selector spec.nodeName="$HOSTNAME" -o jsonpath='{.items[*].status.phase}' 2>/dev/null | grep -q Running; do
    echo "Waiting for longhorn-manager pod on $HOSTNAME..."
    sleep 10
done

echo "Waiting for Longhorn to register node..."
until kubectl get nodes.longhorn.io -n longhorn-system "$HOSTNAME" &> /dev/null; do
    echo "Waiting for Longhorn node $HOSTNAME..."
    sleep 10
done

# Configure disk scheduling based on node type
if [[ "$IS_SERVER" == "true" ]]; then
    # Control plane nodes: disable storage scheduling
    echo "Configuring control plane node - disabling storage scheduling"
    kubectl annotate node "$HOSTNAME" \
        node.longhorn.io/default-disks-config='[{"path":"/var/lib/longhorn","allowScheduling":false}]' \
        --overwrite

else
    # Worker nodes: enable storage scheduling
    echo "Configuring worker node - enabling storage scheduling"
    kubectl annotate node "$HOSTNAME" \
        node.longhorn.io/default-disks-config='[{"path":"/var/lib/longhorn","allowScheduling":true}]' \
        --overwrite

fi

echo "Longhorn node configuration completed for $HOSTNAME"
kubectl get nodes.longhorn.io "$HOSTNAME" -n longhorn-system
