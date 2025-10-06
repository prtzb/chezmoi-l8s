# FluxCD Homelab Cluster (l8s)

## Repository Overview
This repository contains FluxCD GitOps configuration for a homelab Kubernetes cluster named "l8s". The cluster uses Flux v2.7.0 for continuous delivery and automated reconciliation.

## Repository Structure

```
flux-l8s/
├── clusters/l8s/          # Cluster-specific Flux configuration
│   ├── flux-system/       # Core Flux components (sync, kustomization)
│   ├── apps.yaml          # Apps kustomization (depends on infra)
│   └── infra.yaml         # Infrastructure kustomizations (namespaces, secrets, controllers, configs)
├── infra/                 # Infrastructure components
│   ├── namespaces/        # Namespace definitions
│   ├── secrets/           # SOPS-encrypted secrets (currently empty)
│   ├── controllers/       # Controller deployments (Helm)
│   └── configs/           # Configuration resources (certificates, issuers)
├── apps/                  # Application deployments (currently empty)
└── .sops.yaml            # SOPS configuration for secret encryption
```

## Infrastructure Components

### Namespaces
Defined in [infra/namespaces/namespaces.yaml](infra/namespaces/namespaces.yaml):
- `secrets` - Secret management
- `cert-manager` - Certificate management
- `reflector` - Secret/ConfigMap reflection across namespaces
- `ingress-nginx` - Ingress controller (defined but not yet deployed)
- `tailscale` - VPN/networking (defined but not yet deployed)

### Controllers (Helm-based)

#### cert-manager
- **Location**: [infra/controllers/cert-manager/cert-manager.yaml](infra/controllers/cert-manager/cert-manager.yaml)
- **Chart**: jetstack.io/cert-manager ^1.18.2
- **Purpose**: Automated TLS certificate management
- **Features**: CRD auto-installation, auto-remediation with 3 retries

#### reflector
- **Location**: [infra/controllers/reflector/reflector.yaml](infra/controllers/reflector/reflector.yaml)
- **Chart**: emberstack/reflector ^9.2.0
- **Purpose**: Sync secrets/configmaps across namespaces
- **Use case**: Distribute certificates to multiple namespaces

### Certificate Infrastructure

The cluster implements a self-signed CA hierarchy:

1. **Self-Signed ClusterIssuer** ([infra/configs/clusterissuer-ca.yaml](infra/configs/clusterissuer-ca.yaml))
   - Name: `cert-manager-clusterissuer-ca`
   - Type: Self-signed root

2. **Root CA Certificate** ([infra/configs/root-certificate.yaml](infra/configs/root-certificate.yaml))
   - Name: `cert-manager-ca`
   - Organization: `l8s-ca-prod`
   - Algorithm: ECDSA-256
   - Duration: 10 years (87600h)
   - Secret: `root-secret` (in cert-manager namespace)
   - **Note**: Uses commonName for iOS trust compatibility

3. **CA ClusterIssuer** ([infra/configs/clusterissuer.yaml](infra/configs/clusterissuer.yaml))
   - Name: `cert-manager-clusterissuer`
   - Issues certificates signed by the root CA
   - Uses secret: `root-secret`

## Deployment Order & Dependencies

The infrastructure is deployed in a specific order defined in [clusters/l8s/infra.yaml](clusters/l8s/infra.yaml):

1. **namespaces** (no dependencies)
2. **controllers** (depends on namespaces and secrets)
3. **configs** (depends on: controllers)
4. **apps** (depends on: all infra components) - defined in [clusters/l8s/apps.yaml](clusters/l8s/apps.yaml)

## Secret Management

- **Encryption**: SOPS with age encryption
- **Key**: `age1975egh39qnurx5gnwdw523cfz6ce25dpgpl3xm8mr2v2r0hq9gdqt8stuc`
- **Encrypted fields**: `data` and `stringData` in Kubernetes secrets
- **Flux decryption**: Configured in secrets kustomization, references `sops-age` secret in flux-system namespace
- **Secrets repo**: A separate private repo holds the encrypted secrets

## Flux Configuration

- **Source**: GitRepository `flux-system`
- **Reconciliation interval**: 10 minutes (most kustomizations), 1 hour (configs)
- **Prune**: Enabled (removes resources deleted from git)
- **Wait**: Enabled (waits for resources to be ready)
- **Timeout**: 5 minutes (standard), varies by component

## Current State

### Deployed
- ✅ Flux system components
- ✅ Namespace structure
- ✅ cert-manager controller
- ✅ reflector controller
- ✅ Self-signed CA infrastructure

### Pending
- ⏳ Encrypted secrets (directory exists but empty)
- ⏳ Application deployments (apps directory empty)
- ⏳ ingress-nginx controller (namespace defined, deployment pending)
- ⏳ tailscale integration (namespace defined, deployment pending)

## Working with This Repo

### Adding Applications
1. Create app manifests in `apps/` directory
2. Ensure dependencies are met (check apps.yaml dependencies)
3. Commit and Flux will reconcile within 10 minutes

### Certificate Usage
- Use `cert-manager-clusterissuer` ClusterIssuer for issuing certificates
- Certificates will be signed by the l8s-ca-prod root CA
- Use reflector annotations to sync certificates across namespaces

## Notes
- The cluster name "l8s" is a numeronym for "Linnaeus" - the last name of the owner of this project
- All Helm charts use semantic versioning with caret (^) for automatic minor/patch updates
- The root CA is configured with a 10-year lifetime, sufficient for homelab use
- iOS compatibility is explicitly considered (commonName in root certificate)
