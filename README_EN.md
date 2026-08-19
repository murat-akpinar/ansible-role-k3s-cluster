# Ansible Role: K3S Cluster

![release](https://img.shields.io/badge/release-v1.0-blue)

This Ansible role automates the installation of a **K3S**-based Kubernetes cluster. It supports HA (High Availability) and Single Master modes, provides VIP management with Keepalived, and sets up a production-ready Kubernetes environment.

<img src="https://k3s.io/img/k3s-logo-light.svg" alt="k3s" style="max-width: 100%;">

## 📋 Table of Contents

- [Features](#-features)
- [Architecture](#-architecture)
- [Prerequisites](#-prerequisites)
- [Playbooks](#-playbooks)
- [Quick Start](#-quick-start)
- [Detailed Installation](#-detailed-installation)
- [Configuration](#-configuration)
- [Security](#-security)
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
- ✅ **Gateway API**: Gateway API via the k3s built-in Traefik (no Ingress resources)
- ✅ **Management**: Cluster management with Rancher
- ✅ **GitOps**: Continuous delivery (CD) with ArgoCD

## 🏗️ Architecture

A typical HA topology: 3 masters (embedded etcd + control plane) and 4 workers. Keepalived manages a
**VIP** (Virtual IP) across the master nodes; all `kubectl`/agent traffic reaches the API server
through this VIP. MetalLB hands out IPs for LoadBalancer services.

```text
                         ┌─────────────────────────────┐
                         │   Client / kubectl / agent   │
                         └──────────────┬──────────────┘
                                        │
                         Keepalived VIP │ 192.168.1.244:6443
                         (VRRP failover)│
                ┌───────────────────────┼───────────────────────┐
                │                       │                        │
        ┌───────┴───────┐       ┌───────┴───────┐        ┌───────┴───────┐
        │   master-1    │       │   master-2    │        │   master-3    │
        │ etcd + API +  │◄─────►│ etcd + API +  │◄──────►│ etcd + API +  │
        │ scheduler/cm  │ etcd  │ scheduler/cm  │  etcd  │ scheduler/cm  │
        └───────────────┘ quorum└───────────────┘ quorum └───────────────┘
                │                       │                        │
                └───────────────────────┼────────────────────────┘
                                        │ (cluster network / flannel)
        ┌──────────────┬────────────────┼────────────────┬──────────────┐
   ┌────┴─────┐   ┌────┴─────┐     ┌─────┴────┐      ┌─────┴────┐
   │ worker-1 │   │ worker-2 │     │ worker-3 │      │ worker-4 │
   │ app pods │   │ app pods │     │ app pods │      │ app pods │
   └──────────┘   └──────────┘     └──────────┘      └──────────┘

   MetalLB IP pool: 192.168.1.242 (Traefik Gateway → *.homelab.local)
```

- **VIP (Keepalived)**: If the active master fails, VRRP moves the VIP to another master; API access is not interrupted.
- **etcd quorum**: With 3 masters the cluster keeps running after losing one node (majority preserved).
- **Pod distribution**: System/infra pods prefer masters, application pods prefer workers (see [Pod Distribution](#-pod-distribution-and-replica-strategy)).
- **Single Master**: Can also be installed with a single master; Keepalived kicks in automatically once a 3rd master is added.

## 🔧 Prerequisites

### 1. Ansible and Required Collections

```bash
# Ansible must be installed (2.9+)
ansible --version

# Install required collections (community.general + ansible.posix)
ansible-galaxy collection install -r collections/requirements.yml
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
- **Operating System**: Tested on Ubuntu 22.04 and Rocky Linux 9 (including mixed clusters)
  - On the RHEL family (Rocky/Alma/RHEL) firewalld is enabled by default and blocks flannel VXLAN; the role **opens the required ports automatically** (see [Step 1](#step-1-system-preparation))

#### Approximate Per-Component Resource Cost

The values below are approximate **idle** consumption; real usage grows with workload.
The default install is plain k3s: only the k3s rows and the bundled Traefik below apply. Every other component is **off** in `vars/main.yml`; each one you enable adds the cost below.

| Component | CPU (idle) | RAM (idle) | Note |
|-----------|-----------|------------|------|
| **K3s control plane (master)** | ~0.5 vCPU | ~512 MB–1 GB | includes etcd; per master |
| **K3s agent (worker)** | ~0.2 vCPU | ~256 MB | per-worker baseline |
| **Traefik (bundled)** | ~0.1 vCPU | ~64 MB | ships with k3s |
| **MetalLB** | ~0.1 vCPU | ~128 MB | controller + speaker (DaemonSet) |
| **cert-manager** | ~0.1 vCPU | ~128 MB | controller + webhook + cainjector |
| **Longhorn** ⚠️ | ~0.5 vCPU | ~500 MB–1 GB | manager + CSI on every node; **heavy** |
| **kube-prometheus-stack (Grafana/Prometheus)** ⚠️ | ~0.5 vCPU | ~1–2 GB | Prometheus TSDB memory grows with data; **heavy** |
| **Rancher** ⚠️ | ~0.5 vCPU | ~1 GB | 2 replicas; **heavy** |
| **ArgoCD** | ~0.3 vCPU | ~512 MB | repo-server + application-controller |

> Components marked ⚠️ are the biggest resource consumers. **With all components enabled**, at least
> **4 GB RAM** per master (3 masters in HA) and **16 GB+ RAM** cluster-wide are recommended for
> comfortable operation. Longhorn requires additional free disk on worker nodes.

### 4. ETCD and HA Note

ETCD cluster operates on a quorum principle:
- **2 Masters**: If one master fails, the cluster becomes unmanageable
- **3+ Masters**: Cluster continues to operate even if one master fails
- **Recommended**: Use at least 3 master nodes for production environments

## 📚 Playbooks

Entry-point playbooks in the repo (all run with `-i inventory/cluster_inventory.yml`):

| Playbook | Purpose | Example |
|----------|---------|---------|
| `k3s_setup.yml` | Installs the cluster from scratch (system prep, k3s, helm, all components) | `ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml` |
| `upgrade.yml` | Upgrades an existing cluster with a **rolling, zero-downtime** strategy — masters then workers, one by one | `ansible-playbook -i inventory/cluster_inventory.yml upgrade.yml` |
| `add_node.yml` | Adds new master/worker nodes to an existing cluster (idempotent) | `ansible-playbook -i inventory/cluster_inventory.yml add_node.yml` |
| `verify.yml` | Runs a post-install health-check / verification checklist | `ansible-playbook -i inventory/cluster_inventory.yml verify.yml` |

> For `upgrade.yml` details see [K3s Cluster Upgrade](#-k3s-cluster-upgrade), and for `add_node.yml`
> see [Adding Extra Nodes](#-adding-extra-nodes).

## 🚀 Quick Start

### 1. Edit Inventory File

Edit the `inventory/cluster_inventory.yml` file according to your environment:

```yaml
all:
  # Connection settings live HERE, not in vars/main.yml: these values apply
  # before gather_facts — i.e. on the very first SSH connection — and keep the
  # role shareable.
  vars:
    ansible_user: root
    ansible_ssh_private_key_file: ~/.ssh/homelab
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

**Note**: If `ansible_user` is not root it must have sudo rights; the role writes `~/.kube/config` into that user's home directory.

### 2. Configure Variables

Edit the `playbooks/roles/k3s_setup/vars/main.yml` file:

```yaml
# Keepalived VIP (all master nodes connect through this IP)
keepalived_vip: 192.168.1.244

# K3s Version
k3s_version: "v1.32.8+k3s1"  # For initial installation
k3s_upgrade_version: "v1.32.9+k3s1"  # For upgrade (optional)

# Specify which services to install (defaults shipped in the repo)
helm_install: false
gateway_api_install: false
metallb_install: false
cert_manager_install: false
longhorn_install: false
grafana_install: false
rancher_install: false
argocd_install: false
```

**The default install is plain k3s**: the role installs nothing into the
cluster besides k3s itself. All you get is k3s and what ships **bundled** with
it — Traefik, ServiceLB (klipper), CoreDNS, local-path-provisioner,
metrics-server.

> Traefik comes with k3s; the role has no step that installs it. **Gateway API
> does not come with k3s**: the role installs its CRDs and enables Traefik's
> Gateway provider, so with `gateway_api_install: false` Traefik runs as a
> plain Ingress controller.

If you want more, set the matching variable to `true` **before** running the
playbook:

| What you want | What to do |
|---|---|
| Any component installed via Helm | `helm_install: true` — the helm binary and the `my-charts` templates (Gateway/HTTPRoute/values files) are produced by that step; nothing below can install without it |
| Use `Gateway` / `HTTPRoute` resources | `gateway_api_install: true` — installs the CRDs and enables the bundled Traefik's Gateway provider |
| Reach services at `https://<name>.homelab.local` | `cert_manager_install: true` — the shared Gateway and the `*.homelab.local` wildcard certificate are created by that step; with it off no Gateway exists at all |
| Hand out LoadBalancer IPs from a pool on your network | `metallb_install: true` **+** `k3s_disable_servicelb: true` — leaving both LB controllers on makes klipper and MetalLB race for the same Service |
| Persistent/replicated disks (PVC) | `longhorn_install: true` |
| Prometheus + Grafana + Alertmanager | `grafana_install: true` |
| Rancher management UI | `rancher_install: true` (Rancher needs cert-manager for its own TLS, enable both) |
| GitOps / ArgoCD | `argocd_install: true` |

Dependency order: `helm_install` → `gateway_api_install` →
`cert_manager_install` → the rest. When enabling a component, everything to its
left must be enabled too.

> For any of these to be reachable by hostname, both `gateway_api_install` and
> `cert_manager_install` must be on; otherwise they install fine but are only
> reachable through `kubectl port-forward` / NodePort.

To enable something after the cluster is up, set the variable to `true` and
re-run the playbook with the matching tags (e.g. `--tags helm,grafana`).

### 3. Install Cluster

```bash
# Install on all nodes
ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml

# If using a different SSH key
ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml --key-file ~/.ssh/your_key

```

## 📖 Detailed Installation

### Step 1: System Preparation

On every node the playbook does the following (`00_system_requirements.yml`):
- Checks CPU count (minimum 2 on master) and RAM (minimum 2GB on master) — fails fast if insufficient
- **Disables swap** (at runtime and permanently in `/etc/fstab`)
- Loads the kernel modules Kubernetes needs: `overlay`, `br_netfilter` (persisted via `/etc/modules-load.d/k3s.conf`)
- Applies the sysctl settings: `net.bridge.bridge-nf-call-iptables`, `net.bridge.bridge-nf-call-ip6tables`, `net.ipv4.ip_forward`
- Installs and configures Chrony (see Step 3)

Next, `00_prerequisites.yml` installs the shared packages on every node: `acl`
(needed for `become` with an unprivileged `ansible_user`), `open-iscsi`/`nfs-common`
(`iscsi-initiator-utils`/`nfs-utils` on RHEL) and the `iscsid` service — so the
node is ready if Longhorn is enabled later.

**firewalld (RHEL family only)**: if firewalld is running, the same file opens the following; the step is skipped on Ubuntu/Debian.

| What | Why |
|---|---|
| `6443/tcp` | kube-apiserver |
| `8472/udp` | flannel VXLAN — **if blocked**, nodes look Ready but the apiserver cannot reach pods on other nodes |
| `10250/tcp` | kubelet metrics/exec |
| `10.42.0.0/16`, `10.43.0.0/16` → `trusted` zone | pod and service networks |

> ⚠️ If you change the networks with `--cluster-cidr` / `--service-cidr`, update the trusted CIDR list in `tasks/00_prerequisites.yml` as well.

### Step 2: Hostname Configuration

Each node's hostname must match the inventory name. The playbook automatically:
- Checks the hostname
- Changes it if necessary
- Updates the `/etc/hosts` file
- Reboots if necessary

### Step 3: NTP Configuration

Time synchronization between cluster nodes is critical. The playbook:
- Installs Chrony
- Configures the server from the `ntp_server` variable (default `time.google.com`)
- Starts and enables the service (`chrony` on Debian, `chronyd` on RHEL)

### Step 4: Keepalived Installation (Master Nodes)

Keepalived is used for VIP management in HA clusters:
- **3+ Masters**: Keepalived is installed, configured, and started
- **1-2 Masters**: Keepalived is installed but not configured (ready for future use)

If `keepalived_interface` is left empty the VRRP interface is auto-detected from `ansible_default_ipv4.interface`; if the wrong interface is picked, set a fixed value in `vars/main.yml` (`eth0`, `ens18`, etc.).

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

The following services are installed based on configuration (✅ = on by default):

| Service | Default | What it does |
|---|:---:|---|
| **Traefik** | ✅ | Ships **bundled** with k3s, the role does not install it and it has no flag of its own |
| **ServiceLB (klipper)** | ✅ | Bundled with k3s; gives LoadBalancer services a node IP (turn off with `k3s_disable_servicelb`) |
| **Gateway API** | ❌ | Installs the CRDs and enables Traefik's Gateway provider — **not** part of k3s, the role adds it |
| **MetalLB** | ❌ | Hands out LoadBalancer IPs from a pool on your network (instead of klipper) |
| **Cert-Manager** | ❌ | SSL/TLS certificate management + the shared Gateway |
| **Longhorn** | ❌ | Distributed block storage |
| **kube-prometheus-stack** | ❌ | Prometheus + Grafana + Alertmanager |
| **Rancher** | ❌ | Kubernetes management UI |
| **ArgoCD** | ❌ | GitOps continuous delivery (CD) — `argocd.homelab.local` (see [Access ArgoCD](#access-argocd)) |

> ⚠️ The shared Gateway depends on the wildcard certificate: with `cert_manager_install: false` the Gateway and HTTPRoutes are **not created at all**, so no service is reachable by hostname. The Gateway's only listener is HTTPS and requires the `homelab-wildcard-tls` secret, which cert-manager produces.

## ⚙️ Configuration

### Main Configuration File

All configuration variables are found in `playbooks/roles/k3s_setup/vars/main.yml`:

```yaml
# NOTE: connection variables (`ansible_user`, `ansible_ssh_private_key_file`)
# live in `inventory/cluster_inventory.yml` under `all.vars`, NOT here, so they
# apply to the very first SSH connection and the role stays shareable.

# Cluster domain: the Gateway, the wildcard certificate, every HTTPRoute and the
# summary screen URLs are all generated from this single variable.
cluster_domain: homelab.local

# Keepalived
keepalived_vip: 192.168.1.244
# Empty = auto-detect from ansible_default_ipv4.interface (e.g. "eth0", "ens18")
keepalived_interface: ""
# Give a different VRRP router ID (1-255) if a second cluster shares the L2 network
keepalived_router_id: 51
# Password is read from Vault; falls back to the default if undefined (see Security section)
keepalived_auth_pass: "{{ vault_keepalived_auth_pass | default('P@ssw0rd123!') }}"

# K3s Versions
k3s_version: "v1.32.8+k3s1"
k3s_upgrade_version: "v1.32.9+k3s1"  # Optional

# Service Installations — default: plain k3s, everything off
# Dependency order: helm_install -> gateway_api_install -> cert_manager_install -> the rest
helm_install: false
# Gateway API CRDs + the bundled Traefik's Gateway provider (not part of k3s)
gateway_api_install: false
# LoadBalancer IP pool; if you enable it, also set k3s_disable_servicelb: true
metallb_install: false
# Owns the Gateway and the wildcard certificate; set true for hostname access
cert_manager_install: false
longhorn_install: false
grafana_install: false
rancher_install: false
argocd_install: false

# MetalLB IP pool — multiple ranges/CIDRs can be added
metallb_ip_pool_name: "first-pool"
metallb_ip_addresses:
  - "192.168.1.242-192.168.1.242"

# Must match the version Traefik was built against (Traefik 3.7.x -> v1.5.1)
gateway_api_version: "v1.5.1"

# NTP server (chrony)
ntp_server: time.google.com
```

Other variables living in the same file:

| Variable | What it does |
|---|---|
| `k3s_server_args` | k3s server flags in **one place**: initial install, node addition and upgrade all use the same string. If omitted during an upgrade the install script rewrites the systemd unit and flags like `--disable servicelb` / `--tls-san` silently disappear |
| `k3s_disable_servicelb` | When `true`, disables the k3s bundled ServiceLB (klipper). Defaults to `false`: MetalLB is off too, so klipper hands out LoadBalancer IPs. **Do not turn both off** — no LB controller would be left and the `traefik` service stays `<pending>`. If you set `metallb_install: true`, set this to `true` as well |
| `k3s_master_taint` / `k3s_master_taint_value` | Protects masters from heavy workloads (see [Master/Worker Pod Distribution](#masterworker-pod-distribution)) |
| `monitoring_storage_class` | StorageClass for the monitoring PVCs (see [Longhorn StorageClass](#-longhorn-storageclass)) |
| `longhorn_storage_classes` | List of StorageClasses to generate — `reclaim` and `replicas` are managed here |
| `helm_repo_*`, `helm_install_script_url`, `k3s_install_url` | External source URLs; change these for air-gapped/mirrored environments |

### Master/Worker Pod Distribution

Installation **automatically selects** values files based on master count:
- **3+ Masters (HA)**: `values-ha.yml` files are used
- **1 Master (Single)**: `values-single-master.yml` files are used

**Pod Distribution Strategy:**
- **System Pods** (Prometheus, Alertmanager, Cert-Manager, Traefik, MetalLB Controller): Run on master nodes
- **Application Pods** (Grafana): Run on worker nodes
- **Storage Pods** (Longhorn): Run with master preferred, worker fallback strategy

## 🔐 Security

### SSH Private Key

The SSH private key path is **not hardcoded in `vars/main.yml`** (personal/environment-specific paths should not be committed). Use one of three methods:

```bash
# 1) Command line (recommended)
ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml --key-file ~/.ssh/homelab
```

```yaml
# 2) Group-level in inventory/cluster_inventory.yml
all:
  vars:
    ansible_ssh_private_key_file: ~/.ssh/homelab
```

```sshconfig
# 3) Per-host in ~/.ssh/config
Host 192.168.1.*
  IdentityFile ~/.ssh/homelab
```

### Secret Management with Ansible Vault

Sensitive values (e.g. `keepalived_auth_pass`) should not be committed in plaintext. This role can read values via Ansible Vault:

```bash
# 1) Copy the example template
cp inventory/group_vars/all/vault.yml.example inventory/group_vars/all/vault.yml

# 2) Fill in the values (vault_keepalived_auth_pass, etc.) and encrypt
ansible-vault encrypt inventory/group_vars/all/vault.yml

# 3) Run the playbook with the vault password
ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml --ask-vault-pass
#   or with a password file:
ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml --vault-password-file ~/.vault_pass
```

The definition in `vars/main.yml` prefers the Vault variable and falls back to the default if undefined:

```yaml
keepalived_auth_pass: "{{ vault_keepalived_auth_pass | default('P@ssw0rd123!') }}"
```

> **Note**: The encrypted `inventory/group_vars/all/vault.yml` and `.vault_pass` files are excluded from commits via `.gitignore`. Only the `vault.yml.example` template is kept in the repo. For production, it is recommended to remove the default password and source it exclusively from Vault.

### kubeconfig Access

K3s creates the kubeconfig file (`/etc/rancher/k3s/k3s.yaml`) with `--write-kubeconfig-mode 644`, so the `ansible_user` on the master node can run `kubectl` via the `~/.kube/config` symlink. The user's UID and home directory are resolved with `getent passwd {{ ansible_user }}` (there is no hardcoded UID 1000 assumption).

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

### Access ArgoCD

To get the ArgoCD admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

Access ArgoCD: `https://argocd.homelab.local` (with admin username). The password is also shown in the `99_result.yml` summary output after installation.

### Installing / Re-running a Single Component (Tags)

If the cluster is already set up, you can run only a specific component with `--tags` (without running the whole playbook):

```bash
# Install/update Longhorn only
ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml --tags longhorn

# Monitoring (Grafana/Prometheus) only
ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml --tags monitoring

# Multiple components
ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml --tags "gateway-api,metallb"
```

Available tags: `helm`, `gateway-api`, `metallb`, `cert-manager`, `longhorn`, `grafana`/`monitoring`, `rancher`, `argocd`.

> **Note**: Tagged runs assume the cluster is **already installed** (k3s, helm, etc. must be ready). For the initial installation, run the full playbook without tags.

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
| **Traefik (k3s built-in)** | managed by k3s | managed by k3s |
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
| **Traefik (k3s bundled)** | kube-system | 1 | 1 | k3s default |
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

All services share a **single wildcard certificate**, issued and renewed automatically by `cert-manager`.

### Wildcard certificate + shared Gateway
- **Directory**: `templates/my-charts/gateway/` (templated, they contain the domain)
- **Files**:
  - `wildcard-certificate.yml.j2` — `*.homelab.local` Certificate (ns: `kube-system`, secret: `homelab-wildcard-tls`)
  - `gateway.yml.j2` — `kube-system/homelab` Gateway, HTTPS listener, `allowedRoutes.namespaces.from: All`
- The certificate lives in the same namespace as the Gateway, so `certificateRefs` is not cross-namespace and **no ReferenceGrant is required**.

### Service routing (HTTPRoute)

Each service attaches to the shared Gateway with an `HTTPRoute` in its own namespace:

| Service | File | Namespace | Domain |
|---|---|---|---|
| Grafana | `templates/my-charts/grafana/httproute.yml.j2` | `monitoring` | `grafana.homelab.local` |
| Longhorn | `templates/my-charts/longhorn/httproute.yml.j2` | `longhorn-system` | `longhorn.homelab.local` |
| Rancher | `templates/my-charts/rancher/httproute.yml.j2` | `cattle-system` | `rancher.homelab.local` |
| ArgoCD | `templates/my-charts/argocd/httproute.yml.j2` | `argocd` | `argocd.homelab.local` |

Publishing a new service needs no new certificate — the wildcard already covers it, just add an `HTTPRoute`.

> **Careful**: the listener port in `gateway.yml` is **8443**, not 443. That is Traefik's `websecure` **entryPoint** port; the Traefik Service exposes it externally as 443. Using 443 there matches no entryPoint and leaves the Gateway `Programmed=False`.

### Hosts File Configuration

Add the following lines to your `/etc/hosts` file for local access:

```bash
# K3s Cluster Services
192.168.1.242    rancher.homelab.local
192.168.1.242    grafana.homelab.local
192.168.1.242    longhorn.homelab.local
```

**Note**: The IP address (`192.168.1.242`) is the MetalLB LoadBalancer IP. To check the address assigned to the Gateway:

```bash
kubectl get gateway -n kube-system homelab
```

### Component Versions

All live in `playbooks/roles/k3s_setup/vars/main.yml`. `""` = pull the newest release each install.

| Component | Variable | Version |
|---|---|---|
| MetalLB | `metallb_chart_version` | `0.16.1` |
| cert-manager | `cert_manager_chart_version` | `v1.21.1` |
| Longhorn | `longhorn_chart_version` | `1.12.1` |
| kube-prometheus-stack | `kube_prometheus_stack_chart_version` | `88.3.0` |
| ArgoCD | `argocd_chart_version` | `10.3.3` |
| Rancher | `rancher_version` | `v2.15.0` |
| k3s | `k3s_version` | `""` |

```bash
helm repo update && helm search repo jetstack/cert-manager --versions | head -3
```

> ⚠️ Rancher does not allow skipping minor versions. Jumping `rancher_version` from 2.8 to 2.15 on a running install breaks the DB migration; step through the minors.

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

The StorageClass for monitoring (Prometheus/Alertmanager/Grafana) PVCs comes from the `monitoring_storage_class` variable; it is **not hard-coupled to Longhorn**:

- **If Longhorn is installed** (`longhorn_install: true`) → defaults to `longhorn-retain-2` (2 replicas for HA)
- **If Longhorn is disabled** (`longhorn_install: false`) → automatically `local-path` (k3s built-in, no replication, node-local)
- You can pin it manually in `vars/main.yml` (e.g. `longhorn-retain-1`, or any other StorageClass)

> So with `longhorn_install: false` + `grafana_install: true` you can install **monitoring without Longhorn**.

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

### Webhook Calls Fail With "context deadline exceeded"

Typical symptom: the MetalLB `IPAddressPool` apply step fails with
`failed calling webhook ... context deadline exceeded`, and because the master drops out
cert-manager/Grafana/Rancher/ArgoCD never get installed. Nodes look `Ready` but the
apiserver cannot reach pods on other nodes — usually because firewalld blocks flannel
VXLAN (UDP 8472) on the RHEL family.

```bash
# Is firewalld active?
systemctl is-active firewalld

# Are the ports/CIDRs the role should have opened still there?
firewall-cmd --list-ports
firewall-cmd --zone=trusted --list-sources

# If missing, open them manually (the role does this automatically in Step 1)
firewall-cmd --permanent --add-port=8472/udp
firewall-cmd --permanent --zone=trusted --add-source=10.42.0.0/16
firewall-cmd --reload
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
├── collections
│   └── requirements.yml
├── inventory
│   └── cluster_inventory.yml
├── playbooks
│   └── roles
│       ├── extra_node_cluster
│       │   ├── tasks
│       │   │   ├── 00_system_requirements.yml
│       │   │   ├── 01_check_existing_node.yml
│       │   │   ├── 02_add_master_node.yml
│       │   │   ├── 03_add_worker_node.yml
│       │   │   └── main.yml
│       │   └── vars
│       │       └── main.yml
│       ├── k3s_setup
│       │   ├── files                       # static manifests/values (not templated)
│       │   │   ├── my-charts
│       │   │   │   ├── argocd
│       │   │   │   │   ├── values-ha.yml
│       │   │   │   │   └── values-single-master.yml
│       │   │   │   ├── cert-manager
│       │   │   │   │   ├── selfsigned-issuer.yml
│       │   │   │   │   ├── values-ha.yml
│       │   │   │   │   └── values-single-master.yml
│       │   │   │   ├── grafana
│       │   │   │   │   ├── kube-prometheus-stack-values-master-only.yml
│       │   │   │   │   └── kube-prometheus-stack-values-single-master.yml
│       │   │   │   ├── longhorn
│       │   │   │   │   ├── values-ha.yml
│       │   │   │   │   └── values-single-master.yml
│       │   │   │   └── metallb
│       │   │   │       ├── values-ha.yml
│       │   │   │       └── values-single-master.yml
│       │   │   └── traefik-gateway-config.yml
│       │   ├── handlers
│       │   │   ├── .gitkeep
│       │   │   └── main.yml
│       │   ├── meta
│       │   │   ├── .gitkeep
│       │   │   └── main.yml
│       │   ├── tasks
│       │   │   ├── 00_prerequisites.yml       # packages, iscsid, firewalld
│       │   │   ├── 00_system_requirements.yml
│       │   │   ├── 00_wellcome.yml
│       │   │   ├── 01_configure_hostname.yml
│       │   │   ├── 02_install_keepalived.yml
│       │   │   ├── 03_install_k3s.yml
│       │   │   ├── 03_wait_api_ready.yml      # central "is the API ready" gate
│       │   │   ├── 04_install_helm.yml
│       │   │   ├── 05_gateway_api_install.yml
│       │   │   ├── 06_metallb_install.yml
│       │   │   ├── 07_cert_manager_install.yml
│       │   │   ├── 08_longhorn_install.yml
│       │   │   ├── 09_grafana_install.yml
│       │   │   ├── 10_rancher_install.yml
│       │   │   ├── 11_argocd_install.yml
│       │   │   ├── 99_result.yml
│       │   │   ├── _resolve_user.yml        # resolves ansible_user -> home directory
│       │   │   └── main.yml
│       │   ├── templates                    # rendered from cluster_domain etc.
│       │   │   ├── my-charts
│       │   │   │   ├── argocd
│       │   │   │   │   └── httproute.yml.j2
│       │   │   │   ├── gateway
│       │   │   │   │   ├── gateway.yml.j2
│       │   │   │   │   └── wildcard-certificate.yml.j2
│       │   │   │   ├── grafana
│       │   │   │   │   └── httproute.yml.j2
│       │   │   │   ├── longhorn
│       │   │   │   │   └── httproute.yml.j2
│       │   │   │   └── rancher
│       │   │   │       └── httproute.yml.j2
│       │   │   ├── chrony.j2
│       │   │   ├── keepalived.conf.j2
│       │   │   ├── kube-prometheus-stack-values.yml.j2
│       │   │   ├── longhorn-storageclass.yml.j2
│       │   │   ├── metallb-config.yml.j2
│       │   │   ├── rancher-deployment.yml.j2
│       │   │   └── wellcome.j2
│       │   └── vars
│       │       └── main.yml
│       └── update_cluster
│           ├── tasks
│           │   ├── 01_check_versions.yml
│           │   ├── 02_upgrade_masters.yml
│           │   ├── 03_upgrade_workers.yml
│           │   ├── 04_verify_cluster.yml
│           │   ├── 05_cleanup_stuck_nodes.yml
│           │   ├── 06_rebalance_pods.yml
│           │   └── main.yml
│           ├── vars
│           │   └── main.yml
│           └── README.md
├── .gitignore
├── add_node.yml
├── ansible.cfg
├── CHANGELOG.md
├── cliff.toml
├── k3s_setup.yml
├── LICENSE
├── README.md
├── README_EN.md
├── upgrade.yml
└── verify.yml
```

---

**Note**: This role has been tested on Ubuntu 22.04 and Rocky Linux 9 (including mixed clusters). Since K3s's official installation script (`curl -sfL https://get.k3s.io | sh -`) is used, it is expected to work on other Linux distributions as well.

