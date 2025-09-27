#!/bin/bash
set -euo pipefail

source /etc/rancher/k3s/node_vars.env

if [[ "$IS_SERVER" != "true" ]]; then
    echo "This node is not a server node (IS_SERVER=$IS_SERVER), skipping HA services..."
    exit 0
fi

echo "Enabling haproxy and keepalived..."

systemctl enable keepalived
systemctl start keepalived

systemctl enable haproxy
systemctl start haproxy

if systemctl is-active --quiet haproxy; then
    echo "HAProxy is running"
else
    echo "HAProxy failed to start"
    systemctl status haproxy
fi

if systemctl is-active --quiet keepalived; then
    echo "Keepalived is running"
else
    echo "Keepalived failed to start"
    systemctl status keepalived
fi

echo "HA services installed and configured on $HOSTNAME"