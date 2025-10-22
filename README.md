# K3s Homelab Configuration with Chezmoi

This repository contains chezmoi configuration files for managing a high-availability K3s cluster across Raspberry Pi nodes.

## Cluster Architecture

- **Control Plane**: 3x Raspberry Pi 4 with HAProxy/keepalived for HA
- **Worker Nodes**: 3x Raspberry Pi 5 with NVMe storage
- **Network**: 10.0.1.128-255 static IP range
- **Virtual IP**: 10.0.1.128 (HAProxy load balancer)
- **CNI**: Cilium with L2 load balancing and Hubble observability
- **Load Balancer Pool**: 10.0.1.200-220 for service LoadBalancer IPs
- **Storage**: Longhorn distributed storage with v2 data engine
- **GitOps**: FluxCD v2.7.0 for continuous delivery
- **K3s Version**: v1.33.4+k3s1

### Node Configuration

| Node | IP Address | Role | Hardware |
|------|------------|------|----------|
| cp-a7f3 | 10.0.1.129 | Control Plane (Bootstrap) | Raspberry Pi 4 |
| cp-b9e1 | 10.0.1.130 | Control Plane | Raspberry Pi 4 |
| cp-c4d8 | 10.0.1.131 | Control Plane | Raspberry Pi 4 |
| worker-x1y2 | 10.0.1.132 | Worker | Raspberry Pi 5 + NVMe |
| worker-z5w9 | 10.0.1.133 | Worker | Raspberry Pi 5 + NVMe |
| worker-m3n7 | 10.0.1.134 | Worker | Raspberry Pi 5 + NVMe |

## Setup Instructions

### 1. Prepare the Nodes

Flash Ubuntu Server 22.04 LTS to SD cards/NVMe drives and ensure SSH access is configured.

### 2. Install Chezmoi on Each Node

```bash
# Install chezmoi
curl -sfL https://get.chezmoi.io | sh
sudo mv ./bin/chezmoi /usr/local/bin/

# Initialize with this repository
chezmoi init --apply https://github.com/your-username/chezmoi-l8s.git
```

### 3. Set Required Environment Variables

```bash
# Generate a cluster token (run once, use same token for all nodes)
export K3S_TOKEN=$(openssl rand -hex 16)

# Optional: Set keepalived auth password
export KEEPALIVED_AUTH_PASS="your-secure-password"
```

### 4. Bootstrap the Cluster

The cluster bootstraps **automatically** in two phases:

#### Phase 1: Cluster Setup (Chezmoi)

The process is orchestrated through chezmoi run scripts:

**Automatic Execution Order:**
1. **Node Setup** (`run_once_after_01-setup-node.sh`) - Runs first on all nodes
2. **HA Services** (`run_once_after_10-install-ha-services.sh`) - Control plane only
3. **Bootstrap** (`run_once_after_20-bootstrap-k3s.sh`) - Bootstrap node only
4. **Join Control Plane** (`run_once_after_30-join-control-plane.sh`) - Other control plane nodes
5. **Join Workers** (`run_once_after_40-join-worker.sh`) - Worker nodes only
6. **Install Cilium CNI** (`run_once_after_50-install-cilium-cli.sh`) - Bootstrap node installs Cilium
7. **Configure Longhorn** (`run_once_after_60-configure-longhorn-node.sh`) - All nodes configure storage

**Deploy to Each Node:**
```bash
# Set the K3S_TOKEN (via cloud-init userdata or manually)
export K3S_TOKEN="your-cluster-token"

# Install chezmoi and apply configuration
curl -sfL https://get.chezmoi.io | sh
sudo mv ./bin/chezmoi /usr/local/bin/
chezmoi init --apply https://github.com/your-username/chezmoi-l8s.git
```

Each node will automatically:
- Configure networking and system settings
- Install and configure required services
- Bootstrap or join the K3s cluster based on its role
- Install Cilium CNI with L2 load balancing and Hubble observability (bootstrap node)
- Deploy Longhorn storage system
- Configure node-specific storage settings

#### Phase 2: GitOps Deployment (FluxCD)

Once the cluster is running, install FluxCD to manage infrastructure and applications:

```bash
# Bootstrap Flux (from bootstrap node)
flux bootstrap github \
  --owner=your-username \
  --repository=chezmoi-l8s \
  --path=flux/clusters/l8s \
  --personal
```

Flux will automatically deploy:
1. **Infrastructure** - cert-manager, ingress-nginx, reflector
2. **Configurations** - Self-signed CA, certificates, ingress rules
3. **Applications** - Nextcloud, Vaultwarden, Pi-hole, Kured, and custom services

**Continuous Updates:**
- Chezmoi automatically updates every 5 minutes (via cron)
- Flux reconciles from git every 10 minutes
- All changes are automatically applied to the cluster

### 5. Verify Cluster

```bash
# Check cluster status
kubectl get nodes -o wide

# Check HA status
curl http://10.0.1.128:8404/stats  # HAProxy stats

# Check Cilium status
cilium status

# Access Hubble UI (from bootstrap node)
cilium hubble ui

# Check Longhorn status
kubectl get pods -n longhorn-system

# Check Flux status
flux get all

# Check deployed applications
kubectl get pods --all-namespaces
```

## Configuration Files

### Chezmoi-Managed (Node Level)
- **Node Config**: `/root/nodes.yaml` - Centralized node definitions and roles
- **Network**: `/etc/netplan/01-network-config.yaml` - Static IP configuration
- **K3s Config**: `/etc/rancher/k3s/config.yaml` - Unified K3s server/agent configuration
- **Node Variables**: `/etc/rancher/k3s/node_vars.env` - Environment variables for scripts
- **HAProxy**: `/etc/haproxy/haproxy.cfg` - Load balancer for API server
- **Keepalived**: `/etc/keepalived/keepalived.conf` - Virtual IP management
- **Longhorn Manifest**: `/var/lib/rancher/k3s/server/manifests/longhorn.yaml` - Storage deployment
- **Cron**: `/etc/cron.d/chezmoi-update` - Automated configuration updates

### FluxCD-Managed (Cluster Level)
- **Flux System**: `flux/clusters/l8s/` - FluxCD bootstrap and kustomizations
- **Infrastructure**: `flux/infra/` - Controllers, configs, and namespaces
- **Applications**: `flux/apps/` - Application deployments (Helm and manifests)
- **Secrets**: Encrypted with SOPS (`.sops.yaml` for config)

## Maintenance

### Update Configuration
```bash
# Node configuration (chezmoi) - updates automatically every 5 minutes
# Manual update:
chezmoi update

# GitOps updates (Flux) - syncs automatically every 10 minutes
# Manual sync:
flux reconcile source git flux-system

# Force reconciliation of all kustomizations:
flux reconcile kustomization --all
```

### Add New Nodes
1. Add node details to `/root/nodes.yaml`
2. Update IP allocation in network configs
3. Update load balancer pool range if needed (for LoadBalancer services)
4. Commit changes and apply via chezmoi to new node

### Add New Applications
1. Create application manifests in `flux/apps/<app-name>/`
2. Add kustomization entry to `flux/apps/kustomization.yaml`
3. Commit and push to git
4. Flux will reconcile within 10 minutes (or force with `flux reconcile`)

### Backup/Restore
```bash
# Backup etcd (from any control plane node)
sudo k3s etcd-snapshot save backup-$(date +%Y%m%d-%H%M%S)

# List snapshots
sudo k3s etcd-snapshot ls

# Restore from snapshot
sudo k3s server --cluster-reset --cluster-reset-restore-path=/var/lib/rancher/k3s/server/db/snapshots/backup-file

# Longhorn backups
# - Configure in Longhorn UI via ingress
# - Automatic snapshots and backups per storage class

# GitOps state backup
# - All configuration stored in git repository
# - Secrets encrypted with SOPS
```

## Troubleshooting

### Check HA Status
```bash
# Keepalived status
sudo systemctl status keepalived
sudo journalctl -u keepalived -f

# HAProxy status
sudo systemctl status haproxy
sudo journalctl -u haproxy -f

# Test virtual IP
ping 10.0.1.128
```

### Check K3s Status
```bash
# Service status
sudo systemctl status k3s

# Logs
sudo journalctl -u k3s -f

# Cluster info
kubectl cluster-info
kubectl get nodes
kubectl get pods --all-namespaces

# Check CNI status
cilium status
cilium connectivity test  # Network connectivity test
```

### Check Storage Status
```bash
# Longhorn status
kubectl get pods -n longhorn-system
kubectl get nodes.longhorn.io -n longhorn-system

# Check node storage configuration
kubectl get nodes.longhorn.io -n longhorn-system <node-name> -o yaml

# Check volumes
kubectl get pv
kubectl get pvc --all-namespaces
```

### Check GitOps Status
```bash
# Flux overall status
flux get all

# Check specific kustomizations
flux get kustomizations

# Check Helm releases
flux get helmreleases --all-namespaces

# View Flux logs
flux logs --all-namespaces --follow

# Check for reconciliation errors
flux get sources all
```

### Network Issues
```bash
# Test connectivity
nc -zv 10.0.1.128 6443  # API server
nc -zv control-plane-ip 2379  # etcd

# Check firewall
sudo ufw status

# Test Cilium connectivity
cilium connectivity test

# Check LoadBalancer IPs
kubectl get svc --all-namespaces | grep LoadBalancer
```

## Deployed Applications

The cluster runs the following applications via FluxCD:

- **Nextcloud** - Self-hosted file sync and collaboration
- **Vaultwarden** - Lightweight Bitwarden-compatible password manager
- **Pi-hole** - Network-wide ad blocking and DNS management
- **Kured** - Kubernetes Reboot Daemon for coordinated node updates
- **Sonos Anti-Abuse** - Custom Sonos device management service

All applications are defined in the `flux/apps/` directory and managed through GitOps.