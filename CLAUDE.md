# Chezmoi K3s Homelab Configuration

## Project Overview

This is a **chezmoi-based configuration management repository** for deploying and managing a **high-availability K3s Kubernetes cluster** across multiple Raspberry Pi nodes. The project automates the complete setup of a production-ready homelab cluster with infrastructure-as-code principles, combined with **FluxCD GitOps** for continuous application delivery.

## Architecture

**Cluster Design:**
- **3x Control Plane Nodes**: Raspberry Pi 4 with HAProxy + keepalived for HA
- **3x Worker Nodes**: Raspberry Pi 5 with NVMe storage for high performance
- **Virtual IP**: 10.0.1.128 (load balanced API server access)
- **Network Range**: 10.0.1.128-255 static IP allocation
- **CNI**: Cilium with L2 load balancing and network observability
- **Load Balancer Pool**: 10.0.1.200-220 for service LoadBalancer IPs
- **GitOps**: FluxCD v2.7.0 for automated application deployment

**High Availability Features:**
- HAProxy load balancer for K3s API server
- keepalived for virtual IP failover
- etcd clustering across control plane nodes
- Automatic node failure detection and recovery

## Key Technologies

- **[Chezmoi](https://chezmoi.io/)**: Dotfile and configuration management for cluster bootstrap
- **[K3s](https://k3s.io/)**: Lightweight Kubernetes distribution (v1.33.4+k3s1)
- **[FluxCD](https://fluxcd.io/)**: GitOps continuous delivery (v2.7.0)
- **[Cilium](https://cilium.io/)**: eBPF-based CNI with L2 load balancing and Hubble observability
- **[Longhorn](https://longhorn.io/)**: Distributed block storage with v2 data engine
- **[cert-manager](https://cert-manager.io/)**: Automated TLS certificate management
- **[ingress-nginx](https://kubernetes.github.io/ingress-nginx/)**: Ingress controller
- **[Tailscale Operator](https://tailscale.com/kb)**: For exposing services securely.
- **HAProxy**: Load balancer for API server HA
- **keepalived**: Virtual IP management and failover
- **SOPS + Age**: Secret encryption for GitOps

## Project Structure

```
chezmoi-l8s/
├── .chezmoiroot                 # Specifies "root" as source directory
├── README.md                    # Detailed setup documentation
├── CLAUDE.md                    # This project overview
├── CONFIG.md                    # Network configuration reference
├── flux/                        # FluxCD GitOps configuration
│   ├── clusters/l8s/            # Cluster-specific Flux configs
│   │   ├── flux-system/         # Core Flux components
│   │   ├── infra.yaml           # Infrastructure kustomizations
│   │   ├── apps.yaml            # Applications kustomizations
│   │   └── secrets.yaml         # Secrets kustomization (SOPS)
│   ├── infra/                   # Infrastructure components
│   │   ├── namespaces/          # Namespace definitions
│   │   ├── controllers/         # Helm-based controllers
│   │   │   ├── cert-manager/    # Certificate management
│   │   │   ├── ingress-nginx/   # Ingress controller
│   │   │   ├── reflector/       # Secret/ConfigMap sync
│   │   │   └── tailscale/       # VPN integration
│   │   └── configs/             # Configuration resources
│   │       ├── cert-manager/    # CA and issuers
│   │       └── longhorn/        # Storage ingress
│   ├── apps/                    # Application deployments
│   │   ├── nextcloud/           # Nextcloud file sync
│   │   ├── vaultwarden/         # Password manager
│   │   ├── pihole/              # DNS ad-blocking
│   │   ├── kured/               # Reboot manager
│   │   └── sonos-anti-abuse/    # Custom service
│   ├── .sops.yaml               # SOPS encryption config
│   └── CLAUDE.md                # Flux-specific documentation
├── manifests/                   # Test manifests
└── root/                        # Chezmoi managed files directory
    ├── .chezmoi.yaml.tmpl       # Node configuration and templating data
    ├── .chezmoiignore.tmpl      # Files to ignore per node type
    ├── root/nodes.yaml          # Centralized node definitions
    ├── scripts/run_once_*.sh    # Orchestrated setup scripts
    ├── etc/                     # System configuration files
    │   ├── rancher/k3s/         # K3s unified configs and variables
    │   ├── haproxy/             # Load balancer configuration
    │   ├── keepalived/          # HA virtual IP management
    │   ├── cron.d/              # Automated chezmoi updates
    │   └── hosts.tmpl           # Host file entries
    ├── var/lib/rancher/k3s/     # K3s server manifests
    │   └── server/manifests/    # Auto-applied manifests
    │       └── longhorn.yaml    # Longhorn storage deployment
    └── scripts/                 # Additional utility scripts
```

## Automation Flow

### Phase 1: Cluster Bootstrap (Chezmoi)

The cluster deploys automatically via chezmoi's run scripts in order:

1. **Node Setup** (`run_once_after_01-setup-node.sh`) - System prep, packages, kernel modules
2. **HA Services** (`run_once_after_10-install-ha-services.sh`) - HAProxy + keepalived (control plane only)
3. **Bootstrap** (`run_once_after_20-bootstrap-k3s.sh`) - Initial cluster creation with Longhorn manifest (bootstrap node only)
4. **Control Plane Join** (`run_once_after_30-join-control-plane.sh`) - Additional control plane nodes
5. **Worker Join** (`run_once_after_40-join-worker.sh`) - Worker nodes join cluster
6. **Cilium CNI** (`run_once_after_50-install-cilium-cli.sh`) - CNI installation with L2 load balancing and Hubble
7. **Longhorn Config** (`run_once_after_60-configure-longhorn-node.sh`) - Node-specific storage configuration

### Phase 2: GitOps Deployment (FluxCD)

Once the cluster is running, FluxCD manages the lifecycle of infrastructure and applications:

1. **Namespaces** - Created first for all components
2. **Controllers** - cert-manager, ingress-nginx, reflector, tailscale
3. **Configs** - Self-signed CA hierarchy, certificates, ingress rules
4. **Apps** - Nextcloud, Vaultwarden, Pi-hole, Kured, custom services

**Continuous Reconciliation:**
- Flux monitors the git repository every 10 minutes
- Changes are automatically applied to the cluster
- Infrastructure updates deployed before applications
- Secrets encrypted with SOPS/Age and auto-decrypted by Flux

**Secrets management:**
All k8s secrets are stored in a separate repo sourced in `flux/clusters/l8s/secrets.yaml`. That repo is private and unavailable to you. The user manages all secrets manually. If you want to add a secret you must ask the user to do it for you (but you are encouraged to give the user bash oneliners that can generate the secret). You must never store secrets in this repo.

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
- Ingress-nginx for HTTP/HTTPS traffic routing

**Storage:**
- Longhorn distributed block storage with v2 data engine
- Automatic node configuration (control plane nodes disabled, workers enabled)
- 2 replicas default with best-effort auto-balancing
- Storage only scheduled on worker nodes with NVMe storage
- Manager runs on all nodes for discovery and management

**Certificate Management:**
- Self-signed CA infrastructure with 10-year root certificate
- cert-manager for automated certificate lifecycle
- iOS-compatible root CA configuration
- Reflector for cross-namespace certificate distribution

**GitOps & Automation:**
- FluxCD for declarative infrastructure and app management
- SOPS encryption for secrets in git
- Automated chezmoi updates via cron (every 5 minutes)
- Kured for coordinated node reboots

**Security:**
- Firewall rules per node type
- TLS certificate management via cert-manager
- Cluster token authentication
- Encrypted secrets in GitOps workflow

## Usage

Deploy to each node:
```bash
export K3S_TOKEN="your-cluster-token"
curl -sfL https://get.chezmoi.io | sh
sudo mv ./bin/chezmoi /usr/local/bin/
chezmoi init --apply https://github.com/your-username/chezmoi-l8s.git
```

Each node automatically configures itself based on its hostname and joins the cluster in the correct role.

## Deployed Applications

The following applications are managed via FluxCD:

- **[Nextcloud](https://nextcloud.com/)** - Self-hosted file sync and collaboration platform
- **[Vaultwarden](https://github.com/dani-garcia/vaultwarden)** - Lightweight Bitwarden-compatible password manager
- **[Pi-hole](https://pi-hole.net/)** - Network-wide ad blocking and DNS management
- **[Kured](https://kured.dev/)** - Kubernetes Reboot Daemon for coordinated node updates
- **Sonos Anti-Abuse** - Custom service for Sonos device management

## Management

### Cluster Configuration
- **Node updates**: `chezmoi update` pulls latest configs (auto-runs every 5 minutes via cron)
- **GitOps updates**: Flux automatically applies changes from git repo every 10 minutes
- **Manual Flux sync**: `flux reconcile source git flux-system` to trigger immediate sync

### Monitoring & Observability
- **HAProxy stats**: `http://10.0.1.128:8404/stats` - API server load balancer status
- **Network observability**: `cilium hubble ui` - Hubble network monitoring
- **Longhorn UI**: Access via ingress (configured in flux/infra/configs/longhorn/)
- **Flux status**: `flux get all` - View all Flux resources

### Backups & Recovery
- **etcd snapshots**: Built-in K3s etcd snapshot functionality
- **Longhorn snapshots**: Automated storage backups via Longhorn
- **GitOps state**: All cluster configuration stored in git

### Scaling & Updates
- **Add nodes**: Update `/root/nodes.yaml`, commit, and apply via chezmoi
- **Add applications**: Create manifests in `flux/apps/`, commit to git
- **Update versions**: Edit Helm chart versions in flux manifests, commit to git