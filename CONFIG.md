# Network Configuration for K3s Homelab Nodes

## Node IP Assignments

| Node | IP | Role | Hardware |
|------|----|----- |----------|
| cp-a7f3 | 10.0.1.129 | Control Plane (Bootstrap) | Raspberry Pi 4 |
| cp-b9e1 | 10.0.1.130 | Control Plane | Raspberry Pi 4 |
| cp-c4d8 | 10.0.1.131 | Control Plane | Raspberry Pi 4 |
| worker-x1y2 | 10.0.1.132 | Worker | Raspberry Pi 5 + NVMe |
| worker-z5w9 | 10.0.1.133 | Worker | Raspberry Pi 5 + NVMe |
| worker-m3n7 | 10.0.1.134 | Worker | Raspberry Pi 5 + NVMe |

Virtual IP: 10.0.1.128 (HAProxy load balancer)

## Netplan Configurations

### Control Plane Node cp-a7f3 (10.0.1.129)

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - 10.0.1.129/24
      routes:
        - to: default
          via: 10.0.1.1
      nameservers:
        addresses:
          - 10.0.1.1
        search:
          - local
```

### Control Plane Node cp-b9e1 (10.0.1.130)

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - 10.0.1.130/24
      routes:
        - to: default
          via: 10.0.1.1
      nameservers:
        addresses:
          - 10.0.1.1
        search:
          - local
```

### Control Plane Node cp-c4d8 (10.0.1.131)

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - 10.0.1.131/24
      routes:
        - to: default
          via: 10.0.1.1
      nameservers:
        addresses:
          - 10.0.1.1
        search:
          - local
```

### Worker Node worker-x1y2 (10.0.1.132)

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - 10.0.1.132/24
      routes:
        - to: default
          via: 10.0.1.1
      nameservers:
        addresses:
          - 10.0.1.1
        search:
          - local
```

### Worker Node worker-z5w9 (10.0.1.133)

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - 10.0.1.133/24
      routes:
        - to: default
          via: 10.0.1.1
      nameservers:
        addresses:
          - 10.0.1.1
        search:
          - local
```

### Worker Node worker-m3n7 (10.0.1.134)

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:
      dhcp4: false
      addresses:
        - 10.0.1.134/24
      routes:
        - to: default
          via: 10.0.1.1
      nameservers:
        addresses:
          - 10.0.1.1
        search:
          - local
```

## Installation Instructions

1. Create the netplan configuration file on each node:
   ```bash
   sudo nano /etc/netplan/01-static.yaml
   ```

2. Copy the appropriate configuration for each node from above

3. Apply the configuration:
   ```bash
   sudo netplan apply
   ```

4. Verify the configuration:
   ```bash
   ip addr show eth0
   ip route show
   ```

## Network Parameters

- **Gateway**: 10.0.1.1
- **DNS**: 10.0.1.1
- **Subnet**: 10.0.1.0/24
- **Static IP Range**: 10.0.1.129-134 (cluster nodes)
- **Virtual IP**: 10.0.1.128 (HAProxy)
- **Load Balancer Pool**: 10.0.1.200-220 (Cilium L2)

## Notes

- All nodes use static IP addresses to ensure consistent cluster networking
- The virtual IP (10.0.1.128) is managed by keepalived for HA
- Cilium will use the range 10.0.1.200-220 for LoadBalancer services
- Network interface is assumed to be `eth0` (standard for Raspberry Pi)


# k3s token

```bash
# Generate with
mkdir -p /var/lib/rancher/k3s/server && openssl rand -hex 32 | tee /var/lib/rancher/k3s/server/token
```

# chezmoi

```bash
# Install with:
sh -c "$(curl -fsLS get.chezmoi.io)"
```


```bash
# Init with:
bin/chezmoi init https://github.com/prtzb/chezmoi-l8s

# Update:
bin/chezmoi update
```
