#!/bin/bash
set -euo pipefail

source /etc/rancher/k3s/node_vars.env

echo "Installing Cilium CLI and configuring CNI..."

if ! command -v cilium &> /dev/null; then
    echo "Installing Cilium CLI..."

    ARCH=$(uname -m)
    case $ARCH in
        x86_64) CLI_ARCH=amd64;;
        aarch64) CLI_ARCH=arm64;;
        armv7l) CLI_ARCH=arm;;
        *) echo "Unsupported architecture: $ARCH"; exit 1;;
    esac

    CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)

    CLI_URL="https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz"
    echo "Downloading Cilium CLI ${CILIUM_CLI_VERSION} for ${CLI_ARCH}..."

    curl -L --fail --remote-name-all ${CLI_URL}{,.sha256sum}
    sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
    tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
    rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}

    cilium version --client
    echo "Cilium CLI installed successfully on $HOSTNAME"
else
    echo "Cilium CLI already installed"
fi

if [[ "$IS_BOOTSTRAP" == "true" ]]; then

    if kubectl get daemonset -n kube-system cilium >/dev/null 2>&1; then
        echo "Cilium already installed, checking status..."
        cilium status --wait
    else
        echo "Installing Cilium..."

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

    echo "Cilium status:"
    cilium status

    echo "To access Hubble UI, run: cilium hubble ui"
else
    echo "This is not the bootstrap node (IS_BOOTSTRAP=$IS_BOOTSTRAP), skipping Cilium CNI installation..."
fi