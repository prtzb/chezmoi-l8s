#!/bin/bash
set -euo pipefail

# Source node configuration
source /etc/rancher/k3s/node_vars.env

# Install Cilium CLI and configure CNI on this node
echo "Installing Cilium CLI and configuring CNI..."

# Check if cilium CLI is already installed
if ! command -v cilium &> /dev/null; then
    echo "Installing Cilium CLI..."

    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) CLI_ARCH=amd64;;
        aarch64) CLI_ARCH=arm64;;
        armv7l) CLI_ARCH=arm;;
        *) echo "Unsupported architecture: $ARCH"; exit 1;;
    esac

    # Get latest Cilium CLI version
    CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)

    # Download and install Cilium CLI
    CLI_URL="https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz"
    echo "Downloading Cilium CLI ${CILIUM_CLI_VERSION} for ${CLI_ARCH}..."

    curl -L --fail --remote-name-all ${CLI_URL}{,.sha256sum}
    sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
    sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
    rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

    # Verify installation
    cilium version --client
    echo "Cilium CLI installed successfully on $HOSTNAME"
else
    echo "Cilium CLI already installed"
fi

# Only install Cilium CNI on the bootstrap node
if [[ "$IS_BOOTSTRAP" == "true" ]]; then

    # Check if Cilium is already installed
    if kubectl get daemonset -n kube-system cilium >/dev/null 2>&1; then
        echo "Cilium already installed, checking status..."
        cilium status --wait
    else
        echo "Installing Cilium..."

        # Install Cilium with custom configuration
        cilium install \
            --set cluster.name="$CLUSTER_NAME" \
            --set cluster.id=1 \
            --set ipam.mode=kubernetes \
            --set tunnelProtocol=vxlan \
            --set l2announcements.enabled=true \
            --set hubble.enabled=true \
            --set hubble.listenAddress=":4244" \
            --set hubble.relay.enabled=true \
            --set hubble.ui.enabled=true \
            --set operator.replicas=1 \
            --set ipv4NativeRoutingCIDR="$CLUSTER_CIDR" \
            --set autoDirectNodeRoutes=false \
            --set bandwidthManager.enabled=true \
            --set bandwidthManager.bbr=true \
            --set localRedirectPolicy=true \
            --set enableIPv4Masquerade=true \
            --set enableIPv6Masquerade=false \
            --wait

        echo "Cilium installation completed"
    fi

    # Wait for Cilium to be ready
    echo "Waiting for Cilium to be ready..."
    cilium status --wait

    # Create L2 announcement policy and IP pool
    echo "Configuring L2 load balancer..."
    kubectl apply -f - <<EOF
apiVersion: "cilium.io/v2alpha1"
kind: CiliumL2AnnouncementPolicy
metadata:
  name: default-l2-policy
  namespace: kube-system
spec:
  loadBalancerIPs: true
  interfaces:
  - eth0
  nodeSelector:
    matchLabels: {}
---
apiVersion: "cilium.io/v2alpha1"
kind: CiliumLoadBalancerIPPool
metadata:
  name: default-pool
  namespace: kube-system
spec:
  blocks:
  - start: "10.0.1.200"
    stop: "10.0.1.220"
  serviceSelector:
    matchLabels: {}
EOF

    echo "Cilium installation and configuration completed successfully"
    echo "Cluster networking is now ready"

    # Display final status
    echo "Cilium status:"
    cilium status

    echo "To access Hubble UI, run: cilium hubble ui"
else
    echo "This is not the bootstrap node (IS_BOOTSTRAP=$IS_BOOTSTRAP), skipping Cilium CNI installation..."
fi