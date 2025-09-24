#!/bin/bash
set -euo pipefail

# Source node configuration
source /etc/rancher/k3s/node_vars.env

# Exit early if this is not a server node
if [[ "$IS_SERVER" != "true" ]]; then
    echo "This node is not a server node (IS_SERVER=$IS_SERVER), skipping HA services..."
    exit 0
fi

echo "Enabling haproxy and keepalived..."

# Enable and start services
sudo systemctl enable keepalived
sudo systemctl start keepalived

sudo systemctl enable haproxy
sudo systemctl start haproxy

# Verify services are running
if sudo systemctl is-active --quiet haproxy; then
    echo "HAProxy is running"
else
    echo "HAProxy failed to start"
    sudo systemctl status haproxy
fi

if sudo systemctl is-active --quiet keepalived; then
    echo "Keepalived is running"
else
    echo "Keepalived failed to start"
    sudo systemctl status keepalived
fi

echo "HA services installed and configured on $HOSTNAME"