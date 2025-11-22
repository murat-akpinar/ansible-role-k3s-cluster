# Ansible Role: K3S Cluster

![release](https://img.shields.io/badge/release-v1.0-blue)

This Ansible role automates the installation of a **K3S**-based Kubernetes cluster. It supports HA (High Availability) and Single Master modes, provides VIP management with Keepalived, and sets up a production-ready Kubernetes environment.

<img src="https://k3s.io/img/k3s-logo-light.svg" alt="k3s" style="max-width: 100%;">

## 📋 Table of Contents

- [Features](#-features)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Detailed Installation](#-detailed-installation)
- [Configuration](#-configuration)
- [Usage Examples](#-usage-examples)
- [K3s Cluster Upgrade](#-k3s-cluster-upgrade)
- [Adding Extra Nodes](#-adding-extra-nodes)
- [HA Mode Verification](#-ha-mode-verification)
- [Pod Distribution and Replica Strategy](#-pod-distribution-and-replica-strategy)
- [SSL/TLS Certificates](#-ssltls-certificates)
- [Longhorn StorageClass](#-longhorn-storageclass)
- [Troubleshooting](#-troubleshooting)

## ✨ Features

- ✅ **HA (High Availability) Support**: High availability with 3+ master nodes
- ✅ **Single Master Support**: Start with a single master node and convert to HA later
- ✅ **Keepalived VIP**: Automatic VIP management with master failover
- ✅ **Rolling Update**: Zero-downtime cluster upgrades
- ✅ **Idempotent**: Safe to run multiple times
- ✅ **Automatic Values Selection**: Automatic Helm values file selection based on master count
- ✅ **Pod Distribution**: System pods on masters, application pods on workers
- ✅ **SSL/TLS**: Automatic certificate management with cert-manager
- ✅ **Monitoring**: Prometheus + Grafana + Alertmanager
- ✅ **Storage**: Distributed block storage with Longhorn
- ✅ **Load Balancer**: Bare metal load balancing with MetalLB
- ✅ **Ingress**: NGINX Ingress Controller
- ✅ **Management**: Cluster management with Rancher

## 🔧 Prerequisites

### 1. Ansible and Required Collections

```bash
# Ansible must be installed (2.9+)
ansible --version

# Install required collection
ansible-galaxy collection install community.general
```

### 2. SSH Access and Sudo Privileges

SSH access and sudo privileges are required for all nodes:

```bash
# Copy SSH key to all nodes
ssh-copy-id -i ~/.ssh/your_key root@192.168.1.145
ssh-copy-id -i ~/.ssh/your_key root@192.168.1.146
ssh-copy-id -i ~/.ssh/your_key root@192.168.1.147
ssh-copy-id -i ~/.ssh/your_key root@192.168.1.156
```

**Note**: If the root user's `authorized_keys` file has security restrictions, you can remove them with:

```bash
sed -i 's/^no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command="echo.*exit 142" *//g' ~/.ssh/authorized_keys
```

### 3. System Requirements

- **Master Nodes**: Minimum 2 CPU, 2GB RAM (at least 3 masters for HA)
- **Worker Nodes**: Minimum 1 CPU, 1GB RAM
- **Disk**: Minimum 20GB free space
- **Operating System**: Tested on Ubuntu 22.04 (other Linux distributions may work)

### 4. ETCD and HA Note

ETCD cluster operates on a quorum principle:
- **2 Masters**: If one master fails, the cluster becomes unmanageable
- **3+ Masters**: Cluster continues to operate even if one master fails
- **Recommended**: Use at least 3 master nodes for production environments

## 🚀 Quick Start

### 1. Edit Inventory File

Edit the `inventory/cluster_inventory.yml` file according to your environment:

```yaml
all:
  children:
    master:
      hosts:
        master-1:
          ansible_host: 192.168.1.145
        master-2:
          ansible_host: 192.168.1.146
        master-3:
          ansible_host: 192.168.1.147
    worker:
      hosts:
        worker-1:
          ansible_host: 192.168.1.245
        worker-2:
          ansible_host: 192.168.1.246
```

**Note**: If you don't want worker nodes, you can comment out the worker section. You can install an HA cluster with only 3 master nodes.

### 2. Configure Variables

Edit the `playbooks/roles/k3s_setup/vars/main.yml` file:

```yaml
# Keepalived VIP (all master nodes connect through this IP)
keepalived_vip: 192.168.1.244

# K3s Version
k3s_version: "v1.32.8+k3s1"  # For initial installation
k3s_upgrade_version: "v1.32.9+k3s1"  # For upgrade (optional)

# Specify which services to install
helm_install: false
traefik_uninstall: false
ingress_install: true
metallb_install: true
cert_manager_install: true
longhorn_install: true
grafana_install: true
rancher_install: true
```

### 3. Install Cluster

```bash
# Install on all nodes
ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml

# If using a different SSH key
ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml --key-file ~/.ssh/your_key

```

## 📖 Detailed Installation

### Step 1: System Requirements Check

The playbook automatically checks:
- CPU count (minimum 2 on master)
- RAM amount (minimum 2GB on master)
- Disk space
- Operating system

### Step 2: Hostname Configuration

Each node's hostname must match the inventory name. The playbook automatically:
- Checks the hostname
- Changes it if necessary
- Updates the `/etc/hosts` file
- Reboots if necessary

### Step 3: NTP Configuration

Time synchronization between cluster nodes is critical. The playbook:
- Installs Chrony
- Configures `time.google.com` as NTP server
- Starts and enables the service

### Step 4: Keepalived Installation (Master Nodes)

Keepalived is used for VIP management in HA clusters:
- **3+ Masters**: Keepalived is installed, configured, and started
- **1-2 Masters**: Keepalived is installed but not configured (ready for future use)

### Step 5: K3s Installation

K3s installation is performed automatically based on master count:

**Single Master (1 master):**
```bash
k3s server --cluster-init --tls-san <keepalived_vip>
```

**HA Mode (3+ masters):**
- First master: `k3s server --cluster-init --tls-san <keepalived_vip>`
- Other masters: `k3s server --server https://<keepalived_vip>:6443 --token <token>`

**Worker Nodes:**
```bash
k3s agent --server https://<keepalived_vip>:6443 --token <token>
```

### Step 6: Helm Installation

Helm is installed as the Kubernetes package manager (if `helm_install: true`).

### Step 7: Service Installations

The following services are installed based on configuration:
- **Traefik Removal**: Default Traefik ingress is removed
- **NGINX Ingress**: Ingress controller is installed
- **MetalLB**: Load balancer is installed
- **Cert-Manager**: SSL/TLS certificate management
- **Longhorn**: Distributed block storage
- **kube-prometheus-stack**: Prometheus + Grafana + Alertmanager
- **Rancher**: Kubernetes management platform

## ⚙️ Configuration

### Main Configuration File

All configuration variables are found in `playbooks/roles/k3s_setup/vars/main.yml`:

```yaml
# User and SSH
ansible_user: root
ansible_ssh_private_key_file: /home/user/.ssh/homelab

# Keepalived
keepalived_vip: 192.168.1.244
keepalived_auth_pass: P@ssw0rd123!

# K3s Versions
k3s_version: "v1.32.8+k3s1"
k3s_upgrade_version: "v1.32.9+k3s1"  # Optional

# Service Installations
helm_install: false
traefik_uninstall: false
ingress_install: true
metallb_install: true
cert_manager_install: true
longhorn_install: true
grafana_install: true
rancher_install: true
```

### Master/Worker Pod Distribution

Installation **automatically selects** values files based on master count:
- **3+ Masters (HA)**: `values-ha.yml` files are used
- **1 Master (Single)**: `values-single-master.yml` files are used

**Pod Distribution Strategy:**
- **System Pods** (Prometheus, Alertmanager, Cert-Manager, Ingress, MetalLB Controller): Run on master nodes
- **Application Pods** (Grafana): Run on worker nodes
- **Storage Pods** (Longhorn): Run with master preferred, worker fallback strategy

## 💻 Usage Examples

### Cluster Installation

```bash
# Install on all nodes
ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml
```

### Check Cluster Status

```bash
# SSH to master node
ssh root@192.168.1.145

# Check nodes
kubectl get nodes -o wide

# Check pods
kubectl get pods -A -o wide

# Check services
kubectl get svc -A
```

### Access Rancher

After Rancher installation, to get the bootstrap password:

```bash
kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}{{"\n"}}'
```

Access Rancher: `https://rancher.homelab.local` (update your `/etc/hosts` file with the MetalLB IP)

### Access Grafana

To get the Grafana admin password:

```bash
kubectl get secret --namespace monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```

Access Grafana: `https://grafana.homelab.local` (with admin username)

## 🔄 K3s Cluster Upgrade

A rolling update strategy is used to update your cluster **without downtime**.

### Upgrade Process

1. **Version Check**: Current K3s versions of all nodes are checked
2. **Downgrade Prevention**: Upgrade is skipped if current version is higher than target
3. **Master Node Updates** (Sequentially):
   - Master nodes are updated **one by one** (`serial: 1`)
   - For each master node:
     - Node is **drained** (pods are moved to other nodes)
     - K3s is upgraded
     - Node is **uncordoned**
     - Wait for pods to stabilize
4. **Worker Node Updates** (Sequentially):
   - Worker nodes are updated **one by one**
     - Same process is applied
5. **Automatic Cleanup**: Nodes stuck in `SchedulingDisabled` state are automatically uncordoned
6. **Pod Rebalancing**: Pods are redistributed after upgrade
7. **Cluster Verification**: All nodes are verified to be in Ready state

### Running Upgrade

**1. Set Version**: In `playbooks/roles/k3s_setup/vars/main.yml`:

```yaml
# Initial installation version
k3s_version: "v1.32.8+k3s1"

# Upgrade version (optional - uses k3s_version if not specified)
k3s_upgrade_version: "v1.32.9+k3s1"
```

**2. Upgrade Command**:

```bash
# Upgrade all nodes
ansible-playbook -i inventory/cluster_inventory.yml upgrade.yml
```

### Upgrade Configuration

Configurable parameters in `playbooks/roles/update_cluster/vars/main.yml`:

```yaml
upgrade_drain_timeout: 600          # Drain timeout (seconds) - increased for PVC-heavy workloads
upgrade_drain_grace_period: 120     # Pod termination grace period (seconds)
upgrade_wait_for_pods: 60           # Pod stabilization wait time (seconds)
upgrade_force: false                 # Force upgrade even if versions match (not recommended)
```

### Important Notes

⚠️ **Backup**: Backup important data before upgrade  
⚠️ **Test**: Test in a test environment before applying to production  
⚠️ **Version Compatibility**: Check compatibility between K3s versions  
⚠️ **Etcd**: In HA installations, etcd compatibility is important, update master nodes first  
⚠️ **Rolling Update**: Nodes are updated sequentially, cluster continues to operate without interruption  
⚠️ **Downgrade Prevention**: Upgrade is not performed if current version is higher than target

### Post-Upgrade Verification

```bash
# Check node status
kubectl get nodes -o wide

# Check node versions
kubectl get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion

# Check pod status
kubectl get pods -A

# Check K3s version
kubectl version --short
```

## ➕ Adding Extra Nodes

You can add new master or worker nodes to your existing K3s cluster. This operation is **idempotent**.

### Prerequisites

**1. Add New Node to Inventory**: Add the new node to `inventory/cluster_inventory.yml`:

```yaml
all:
  children:
    master:
      hosts:
        master-1:
          ansible_host: 192.168.1.145
        master-2:
          ansible_host: 192.168.1.146
        master-3:
          ansible_host: 192.168.1.147
        master-4:  # New master node
          ansible_host: 192.168.1.148
    worker:
      hosts:
        worker-1:
          ansible_host: 192.168.1.245
        worker-2:
          ansible_host: 192.168.1.246
        worker-3:  # New worker node
          ansible_host: 192.168.1.247
```

**2. SSH Access**: New nodes must have SSH access and sudo privileges.

### Usage Examples


**To add all new nodes:**
```bash
ansible-playbook -i inventory/cluster_inventory.yml add_node.yml
```

### Cluster Upgrade

```bash
# Upgrade on all nodes
ansible-playbook -i inventory/cluster_inventory.yml upgrade.yml
```

### Adding a New Node to the Cluster

```bash
# Adding an extra node
ansible-playbook -i inventory/cluster_inventory.yml add_node.yml
```

### Features

✅ **Automatic Hostname Configuration**: New node's hostname is automatically set (reboot if necessary)  
✅ **NTP Configuration**: Chrony installation and configuration is done automatically  
✅ **Idempotent**: Does not re-add nodes already in the cluster  
✅ **Version Compatibility**: New nodes are installed with version compatible with current cluster  
✅ **HA Support**: Can add masters to HA clusters with 3+ master nodes  
✅ **Single Master Support**: Can add masters to single master clusters to convert to HA  
✅ **Automatic Keepalived Configuration**: Keepalived is automatically configured when 3+ masters exist

### Important Notes

⚠️ **Version Compatibility**: New nodes' version must be compatible with current cluster version. Version is taken from `k3s_version` variable in `playbooks/roles/k3s_setup/vars/main.yml`.

⚠️ **Hostname Change**: If the node's hostname doesn't match the inventory name, hostname is changed and system is rebooted.

⚠️ **Token Security**: K3s token is automatically retrieved from the first master node.

⚠️ **Single Master to HA Conversion**: The first master node must be installed with `--cluster-init`. Otherwise, additional masters cannot be added.

### Verification

To verify the node was successfully added:

```bash
kubectl get nodes -o wide
```

You should see the new node in `Ready` state.

## 🔍 HA Mode Verification

To check if your cluster is running in HA mode:

### Complete Check Command

```bash
echo "=== HA MODE CHECK ===" && \
echo "Master nodes:" && \
kubectl get nodes -l node-role.kubernetes.io/master --no-headers | wc -l && \
echo "ETCD nodes:" && \
kubectl get nodes -l node-role.kubernetes.io/etcd --no-headers | wc -l && \
echo "Keepalived VIP:" && \
ip -4 a show ens3 | grep 192.168.1.244 && \
echo "ETCD directory:" && \
ls -d /var/lib/rancher/k3s/server/db/etcd 2>/dev/null && \
echo "HA Mode: YES (3+ masters with etcd cluster)" || echo "HA Mode: NO"
```

### Individual Checks

```bash
# 1. Master node count (3+ = HA)
kubectl get nodes -l node-role.kubernetes.io/master --no-headers | wc -l

# 2. ETCD node count (3+ = HA)
kubectl get nodes -l node-role.kubernetes.io/etcd --no-headers | wc -l

# 3. Keepalived VIP check
ip -4 a show ens3 | grep 192.168.1.244

# 4. ETCD cluster directory (if exists = HA)
ls -d /var/lib/rancher/k3s/server/db/etcd

# 5. List all master nodes
kubectl get nodes -l node-role.kubernetes.io/master -o wide
```

**HA Mode Criteria:**
- ✅ 3 or more master nodes
- ✅ ETCD running on each master
- ✅ Started with `--cluster-init` (etcd cluster directory exists)
- ✅ Keepalived VIP configured (optional but recommended)

## 📊 Pod Distribution and Replica Strategy

### Replica Distribution

| Component | HA (3+ Masters) | Single Master |
|-----------|----------------|---------------|
| **Ingress-Nginx** | 2 replicas | 1 replica |
| **Cert-Manager Controller** | 2 replicas | 1 replica |
| **Cert-Manager Webhook** | 3 replicas | 1 replica |
| **Cert-Manager CA Injector** | 2 replicas | 1 replica |
| **Prometheus** | 2 replicas | 1 replica |
| **Alertmanager** | 2 replicas | 1 replica |
| **Longhorn UI** | 2 replicas | 1 replica |
| **Longhorn CSI Attacher** | 3 replicas | 1 replica |
| **Longhorn CSI Provisioner** | 3 replicas | 1 replica |
| **Longhorn CSI Resizer** | 3 replicas | 1 replica |
| **Longhorn CSI Snapshotter** | 3 replicas | 1 replica |
| **Grafana** | 1 replica | 1 replica |
| **Rancher** | 2 replicas | 2 replicas |

### Pod Distribution Table

| Component | Namespace | HA Replicas | Single Replicas | Node Preference |
|-----------|-----------|-------------|-----------------|-----------------|
| **Ingress-Nginx Controller** | ingress-nginx | 2 | 1 | Master |
| **MetalLB Controller** | metallb-system | 1 | 1 | Master |
| **MetalLB Speaker** | metallb-system | DaemonSet | DaemonSet | All Nodes |
| **Cert-Manager Controller** | cert-manager | 2 | 1 | Master |
| **Cert-Manager Webhook** | cert-manager | 3 | 1 | Master |
| **Cert-Manager CA Injector** | cert-manager | 2 | 1 | Master |
| **Prometheus** | monitoring | 2 | 1 | Master (preferred) |
| **Alertmanager** | monitoring | 2 | 1 | Master (preferred) |
| **Grafana** | monitoring | 1 | 1 | Worker |
| **Kube State Metrics** | monitoring | 1 | 1 | Master (preferred) |
| **Longhorn Manager** | longhorn-system | DaemonSet | DaemonSet | All Nodes |
| **Longhorn UI** | longhorn-system | 2 | 1 | Master (preferred) |
| **Longhorn CSI Components** | longhorn-system | 3 | 1 | Master (preferred) |
| **Rancher** | cattle-system | 2 | 2 | Any |

## 🔐 SSL/TLS Certificates

SSL/TLS certificates for all services are automatically managed by `cert-manager`. Certificate files are kept in separate directories:

### Grafana
- **Directory**: `files/my-charts/grafana/cert/`
- **Files**:
  - `homelab.grafana.yml` - Ingress
  - `homelab-grafana-certificate.yml` - Certificate
- **Domain**: `grafana.homelab.local`

### Longhorn
- **Directory**: `files/my-charts/longhorn/cert/`
- **Files**:
  - `homelab.longhorn.yml` - Ingress
  - `homelab-longhorn-certificate.yml` - Certificate
- **Domain**: `longhorn.homelab.local`

### Rancher
- **Directory**: `files/my-charts/rancher/cert/`
- **Files**:
  - `rancher.homelab.yml` - Ingress
  - `rancher-homelab-certificate.yml` - Certificate
- **Domain**: `rancher.homelab.local`

### Hosts File Configuration

Add the following lines to your `/etc/hosts` file for local access:

```bash
# K3s Cluster Services
192.168.1.242    rancher.homelab.local
192.168.1.242    grafana.homelab.local
192.168.1.242    longhorn.homelab.local
```

**Note**: The IP address (`192.168.1.242`) is the MetalLB LoadBalancer IP. To check the Ingress Controller service IP:

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

## 💾 Longhorn StorageClass

Longhorn provides distributed block storage for Kubernetes. During installation, 6 different StorageClasses are automatically created:

### StorageClasses

| StorageClass | ReclaimPolicy | Replica Count | Use Case |
|-------------|---------------|---------------|----------|
| `longhorn-retain-1` | Retain | 1 | For Single Master installations |
| `longhorn-retain-2` | Retain | 2 | For HA installations (recommended) |
| `longhorn-retain-3` | Retain | 3 | For high data security requirements |
| `longhorn-delete-1` | Delete | 1 | For temporary data |
| `longhorn-delete-2` | Delete | 2 | For temporary data (HA) |
| `longhorn-delete-3` | Delete | 3 | For temporary data (high security) |

### Current PVC Configuration

StorageClasses used in installation:

- **Prometheus**: `longhorn-retain-2` (2 replicas for HA)
- **Alertmanager**: `longhorn-retain-2` (2 replicas for HA)
- **Grafana**: `longhorn-retain-2` (2 replicas for HA)

### Data Persistence and Security

✅ **ReclaimPolicy: Retain** - Volumes are preserved even if PVC is deleted, manual cleanup required  
✅ **Pod Restart**: Data is preserved (PVC remains attached)  
✅ **Node Restart**: Data is preserved (Longhorn volumes are replicated across different nodes)  
✅ **HA Installation**: No data loss even if one node fails with `longhorn-retain-2`

### StorageClass Verification

To check existing StorageClasses:

```bash
kubectl get storageclass
```

To check PVCs:

```bash
kubectl get pvc -A
```

### Recommendations

- **HA Installations (3+ Masters)**: Use `longhorn-retain-2` or `longhorn-retain-3`
- **Single Master**: `longhorn-retain-1` is sufficient
- **Production Environments**: Use at least 2 replicas (`longhorn-retain-2`)
- **Critical Data**: Use 3 replicas (`longhorn-retain-3`)

## 🔧 Troubleshooting

### Nodes Not in Ready State

```bash
# Check node status
kubectl get nodes

# Check node details
kubectl describe node <node-name>

# Check K3s service status
systemctl status k3s  # On master nodes
systemctl status k3s-agent  # On worker nodes

# Check K3s logs
journalctl -u k3s -n 50 --no-pager
```

### Pods Not Running

```bash
# List all pods
kubectl get pods -A

# Check problematic pods
kubectl describe pod <pod-name> -n <namespace>

# Check pod logs
kubectl logs <pod-name> -n <namespace>
```

### Keepalived VIP Not Working

```bash
# Check Keepalived service status
systemctl status keepalived

# Check Keepalived logs
journalctl -u keepalived -n 50 --no-pager

# Check which node has the VIP
ip -4 a show ens3 | grep 192.168.1.244
```

### Post-Upgrade Issues

```bash
# Manually uncordon node
kubectl uncordon <node-name>

# Manually drain node
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Restart K3s service
systemctl restart k3s  # On master nodes
systemctl restart k3s-agent  # On worker nodes
```

### Rancher Bootstrap Password

```bash
kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}{{"\n"}}'
```

### Grafana Admin Password

```bash
kubectl get secret --namespace monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```

## 📁 Structure

```bash
├── ansible.cfg
├── collections
│   └── requirements.yml
├── hosts
├── inventory
│   └── cluster_inventory.yml
├── LICENSE
├── playbooks
│   └── roles
│       └── k3s_setup
│           ├── files
│           │   └── my-charts
│           │       ├── cert-manager
│           │       │   ├── selfsigned-issuer.yml
│           │       │   ├── values-ha.yml
│           │       │   └── values-single-master.yml
│           │       ├── grafana
│           │       │   ├── cert
│           │       │   │   ├── homelab-grafana-certificate.yml
│           │       │   │   └── homelab.grafana.yml
│           │       │   ├── kube-prometheus-stack-values-master-only.yml
│           │       │   ├── kube-prometheus-stack-values-single-master.yml
│           │       │   └── kube-prometheus-stack-values.yml
│           │       ├── ingress
│           │       │   ├── values-ha.yml
│           │       │   └── values-single-master.yml
│           │       ├── longhorn
│           │       │   ├── cert
│           │       │   │   ├── homelab-longhorn-certificate.yml
│           │       │   │   └── homelab.longhorn.yml
│           │       │   ├── storageclass.yml
│           │       │   ├── values-ha.yml
│           │       │   └── values-single-master.yml
│           │       ├── metallb
│           │       │   ├── metallb-config.yml
│           │       │   ├── values-ha.yml
│           │       │   └── values-single-master.yml
│           │       └── rancher
│           │           ├── cert
│           │           │   ├── rancher-homelab-certificate.yml
│           │           │   └── rancher.homelab.yml
│           │           └── rancher-deployment.yml
│           ├── handlers
│           │   └── main.yml
│           ├── meta
│           ├── tasks
│           │   ├── 00_system_requirements.yml
│           │   ├── 00_traefik_uninstall.yml
│           │   ├── 00_wellcome.yml
│           │   ├── 01_configure_hostname.yml
│           │   ├── 02_install_keepalived.yml
│           │   ├── 03_install_k3s.yml
│           │   ├── 04_install_helm.yml
│           │   ├── 05_ingress_install.yml
│           │   ├── 06_metallb_install.yml
│           │   ├── 07_cert_manager_install.yml
│           │   ├── 08_longhorn_install.yml
│           │   ├── 09_grafana_install.yml
│           │   ├── 10_rancher_install.yml
│           │   └── main.yml
│           ├── templates
│           │   ├── chrony.j2
│           │   ├── keepalived-backup.j2
│           │   ├── keepalived-master.j2
│           │   └── wellcome.j2
│           └── vars
│               └── main.yml
├── README.md
└── site.yml

22 directories, 48 files
```

---

**Note**: This role has been tested on Ubuntu 22.04. Since K3s's official installation script (`curl -sfL https://get.k3s.io | sh -`) is used, it is expected to work on other Linux distributions as well.

