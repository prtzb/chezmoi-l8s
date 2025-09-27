# Chezmoi K3s Homelab Configuration

## Project Overview

This is a **chezmoi-based configuration management repository** for deploying and managing a **high-availability K3s Kubernetes cluster** across multiple Raspberry Pi nodes. The project automates the complete setup of a production-ready homelab cluster with infrastructure-as-code principles.

## Architecture

**Cluster Design:**
- **3x Control Plane Nodes**: Raspberry Pi 4 with HAProxy + keepalived for HA
- **3x Worker Nodes**: Raspberry Pi 5 with NVMe storage for high performance
- **Virtual IP**: 10.0.1.128 (load balanced API server access)
- **Network Range**: 10.0.1.128-255 static IP allocation
- **CNI**: Cilium with L2 load balancing and network observability
- **Load Balancer Pool**: 10.0.1.200-220 for service LoadBalancer IPs

**High Availability Features:**
- HAProxy load balancer for K3s API server
- keepalived for virtual IP failover
- etcd clustering across control plane nodes
- Automatic node failure detection and recovery

## Key Technologies

- **[Chezmoi](https://chezmoi.io/)**: Dotfile and configuration management
- **[K3s](https://k3s.io/)**: Lightweight Kubernetes distribution
- **[Cilium](https://cilium.io/)**: eBPF-based CNI with L2 load balancing and Hubble observability
- **HAProxy**: Load balancer for API server HA
- **keepalived**: Virtual IP management and failover
- **Longhorn**: Distributed block storage (prepared for)
- **KubeVirt**: Virtualization platform (prepared for)

## Project Structure

```
chezmoi-l8s/
├── .chezmoiroot                 # Specifies "root" as source directory
├── README.md                    # Detailed setup documentation
├── CLAUDE.md                    # This project overview
└── root/                        # Chezmoi managed files directory
    ├── .chezmoi.yaml.tmpl       # Node configuration and templating data
    ├── .chezmoiignore.tmpl      # Files to ignore per node type
    ├── root/nodes.yaml          # Centralized node definitions
    ├── scripts/run_once_*.sh    # Orchestrated setup scripts
    ├── etc/                     # System configuration files
    │   ├── rancher/k3s/         # K3s unified configs and variables
    │   ├── haproxy/             # Load balancer configuration
    │   ├── keepalived/          # HA virtual IP management
    │   ├── netplan/             # Static network configuration
    │   └── hosts.tmpl           # Host file entries
    ├── dot_kube/                # kubectl configuration
    ├── dot_ssh/                 # SSH client configuration
    └── scripts/                 # Additional utility scripts
```

## Automation Flow

The cluster deploys automatically via chezmoi's run scripts in order:

1. **Node Setup** (`run_once_after_01-setup-node.sh`) - System prep, packages, kernel modules
2. **HA Services** (`run_once_after_10-install-ha-services.sh`) - HAProxy + keepalived (control plane only)
3. **Bootstrap** (`run_once_after_20-bootstrap-k3s.sh`) - Initial cluster creation (bootstrap node only)
4. **Control Plane Join** (`run_once_after_30-join-control-plane.sh`) - Additional control plane nodes
5. **Worker Join** (`run_once_after_40-join-worker.sh`) - Worker nodes join cluster
6. **Cilium CNI** (`run_once_after_50-install-cilium-cli.sh`) - CNI installation with L2 load balancing and Hubble

## Node Configuration

| Node | IP | Role | Hardware |
|------|----|----- |----------|
| cp-a7f3 | 10.0.1.129 | Control Plane (Bootstrap) | Raspberry Pi 4 |
| cp-b9e1 | 10.0.1.130 | Control Plane | Raspberry Pi 4 |
| cp-c4d8 | 10.0.1.131 | Control Plane | Raspberry Pi 4 |
| worker-x1y2 | 10.0.1.132 | Worker | Raspberry Pi 5 + NVMe |
| worker-z5w9 | 10.0.1.133 | Worker | Raspberry Pi 5 + NVMe |
| worker-m3n7 | 10.0.1.134 | Worker | Raspberry Pi 5 + NVMe |

## Advanced Features

**Networking:**
- Cilium CNI with eBPF dataplane for high performance
- L2 load balancing for LoadBalancer services (10.0.1.200-220)
- Hubble for network observability and troubleshooting
- VXLAN tunneling for pod-to-pod communication

**Storage Preparation:**
- Longhorn prerequisites (open-iscsi, nvme-tcp modules)
- NVMe storage optimization for Pi 5 workers

**Virtualization Ready:**
- KubeVirt kernel modules pre-loaded
- libvirt configuration for VM workloads

**Security:**
- Firewall rules per node type
- TLS certificate management
- Cluster token authentication

## Usage

Deploy to each node:
```bash
export K3S_TOKEN="your-cluster-token"
curl -sfL https://get.chezmoi.io | sh
sudo mv ./bin/chezmoi /usr/local/bin/
chezmoi init --apply https://github.com/your-username/chezmoi-l8s.git
```

Each node automatically configures itself based on its hostname and joins the cluster in the correct role.

## Management

- **Updates**: `chezmoi update` pulls latest configs
- **Monitoring**: HAProxy stats at `http://10.0.1.128:8404/stats`
- **Network Observability**: Hubble UI via `cilium hubble ui` for network troubleshooting
- **Backups**: Built-in etcd snapshot functionality
- **Scaling**: Add nodes by updating `/root/nodes.yaml` and redeploying