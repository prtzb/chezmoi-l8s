#!/bin/bash

set -euo pipefail

source /etc/rancher/k3s/node_vars.env

echo "Setting up $HOSTNAME for K3s cluster..."

echo "Updating system packages..."
apt-get update && apt-get upgrade -y

echo "Installing required packages..."
apt-get install -y curl wget git netcat-openbsd \
    open-iscsi nfs-common \
    qemu-kvm libvirt-daemon-system libvirt-clients bridge-utils \
    haproxy keepalived

# Enable required kernel modules for k3s, Longhorn, and KubeVirt
echo "Configuring kernel modules..."
tee /etc/modules-load.d/k3s.conf <<EOF
# K3s networking
br_netfilter
overlay

# Longhorn storage
nvme-tcp
iscsi_tcp
scsi_mod

# KubeVirt virtualization
kvm
kvm_intel
kvm_amd
vhost
vhost_net
vhost_scsi
vfio
vfio_pci
vfio_iommu_type1
EOF

# K3s modules
modprobe br_netfilter
modprobe overlay

# Longhorn modules
modprobe nvme-tcp || echo "nvme-tcp module not available (may need kernel update)"
modprobe iscsi_tcp || echo "iscsi_tcp module not available"
modprobe scsi_mod || echo "scsi_mod module not available"

# KubeVirt modules
modprobe kvm || echo "kvm module not available"
modprobe kvm_intel || echo "kvm_intel module not available (expected on ARM)"
modprobe kvm_amd || echo "kvm_amd module not available (expected on ARM/Intel)"
modprobe vhost || echo "vhost module not available"
modprobe vhost_net || echo "vhost_net module not available"
modprobe vhost_scsi || echo "vhost_scsi module not available"
modprobe vfio || echo "vfio module not available"
modprobe vfio_pci || echo "vfio_pci module not available"
modprobe vfio_iommu_type1 || echo "vfio_iommu_type1 module not available"

echo "Configuring sysctl parameters..."
tee /etc/sysctl.d/k3s.conf <<EOF
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
net.ipv4.ip_nonlocal_bind = 1
EOF

sysctl --system

echo "Disabling swap..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

echo "Setting hostname..."
hostnamectl set-hostname "$HOSTNAME"

if ufw status | grep -q "Status: active"; then
    echo "Configuring firewall rules..."

    if [[ "$IS_SERVER" == "true" ]]; then
        # Control plane ports
        ufw allow 6443/tcp  # Kubernetes API
        ufw allow 2379:2380/tcp  # etcd
        ufw allow 10250/tcp # kubelet
        ufw allow 10259/tcp # kube-scheduler
        ufw allow 10257/tcp # kube-controller-manager
        # HAProxy stats
        ufw allow 8404/tcp
    fi

    if [[ "$IS_AGENT" == "true" ]]; then
        # Worker ports
        ufw allow 10250/tcp # kubelet
    fi

    # SSH and cluster internal communication
    ufw allow 22/tcp
    ufw allow from 10.0.1.0/24
fi

# Enable and start services for Longhorn and KubeVirt
echo "Configuring storage and virtualization services..."
systemctl enable iscsid
systemctl start iscsid

# Add user to libvirt group for KubeVirt (if user exists)
if id "ubuntu" &>/dev/null; then
    usermod -aG libvirt ubuntu
fi

echo "Node $HOSTNAME setup completed"
