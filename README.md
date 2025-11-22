# Ansible Role: K3S Cluster

![release](https://img.shields.io/badge/release-v1.0-blue)

Bu Ansible rolü, **K3S** tabanlı Kubernetes cluster kurulumunu otomatikleştirir. HA (High Availability) ve Single Master modlarını destekler, Keepalived ile VIP yönetimi sağlar ve production-ready bir Kubernetes ortamı kurar.

<img src="https://k3s.io/img/k3s-logo-light.svg" alt="k3s" style="max-width: 100%;">

## 📋 İçindekiler

- [Özellikler](#-özellikler)
- [Önkoşullar](#-önkoşullar)
- [Hızlı Başlangıç](#-hızlı-başlangıç)
- [Detaylı Kurulum](#-detaylı-kurulum)
- [Yapılandırma](#-yapılandırma)
- [Kullanım Örnekleri](#-kullanım-örnekleri)
- [K3s Cluster Upgrade](#-k3s-cluster-upgrade)
- [Extra Node Ekleme](#-extra-node-ekleme)
- [HA Modu Kontrolü](#-ha-modu-kontrolü)
- [Pod Dağılımı ve Replica Stratejisi](#-pod-dağılımı-ve-replica-stratejisi)
- [SSL/TLS Sertifikaları](#-ssltls-sertifikaları)
- [Longhorn StorageClass](#-longhorn-storageclass)
- [Troubleshooting](#-troubleshooting)

## ✨ Özellikler

- ✅ **HA (High Availability) Desteği**: 3+ master node ile yüksek erişilebilirlik
- ✅ **Single Master Desteği**: Tek master node ile başlayıp sonradan HA'ya dönüştürme
- ✅ **Keepalived VIP**: Otomatik VIP yönetimi ile master failover
- ✅ **Rolling Update**: Kesintisiz cluster upgrade
- ✅ **Idempotent**: Güvenli tekrar çalıştırma
- ✅ **Otomatik Values Seçimi**: Master sayısına göre otomatik Helm values seçimi
- ✅ **Pod Dağılımı**: System pod'lar master'da, application pod'lar worker'da
- ✅ **SSL/TLS**: Cert-manager ile otomatik sertifika yönetimi
- ✅ **Monitoring**: Prometheus + Grafana + Alertmanager
- ✅ **Storage**: Longhorn ile distributed block storage
- ✅ **Load Balancer**: MetalLB ile bare metal load balancing
- ✅ **Ingress**: NGINX Ingress Controller
- ✅ **Management**: Rancher ile cluster yönetimi

## 🔧 Önkoşullar

### 1. Ansible ve Gerekli Collection'lar

```bash
# Ansible yüklü olmalı (2.9+)
ansible --version

# Gerekli collection'ı yükleyin
ansible-galaxy collection install community.general
```

### 2. SSH Erişimi ve Sudo Yetkisi

Tüm node'lara SSH ile erişim ve sudo yetkisi gereklidir:

```bash
# SSH key'i tüm node'lara kopyalayın
ssh-copy-id -i ~/.ssh/your_key root@192.168.1.145
ssh-copy-id -i ~/.ssh/your_key root@192.168.1.146
ssh-copy-id -i ~/.ssh/your_key root@192.168.1.147
ssh-copy-id -i ~/.ssh/your_key root@192.168.1.156
```

**Not**: Eğer root kullanıcısının `authorized_keys` dosyasında güvenlik kısıtlaması varsa, şu komutla kaldırabilirsiniz:

```bash
sed -i 's/^no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command="echo.*exit 142" *//g' ~/.ssh/authorized_keys
```

### 3. Sistem Gereksinimleri

- **Master Node'lar**: Minimum 2 CPU, 2GB RAM (HA için en az 3 master)
- **Worker Node'lar**: Minimum 1 CPU, 1GB RAM
- **Disk**: Minimum 20GB boş alan
- **İşletim Sistemi**: Ubuntu 22.04 test edilmiştir (diğer Linux dağıtımları da çalışabilir)

### 4. ETCD ve HA Notu

ETCD cluster'ı çoğunluk (quorum) prensibi ile çalışır:
- **2 Master**: Bir master çökerse cluster yönetilemez hale gelir
- **3+ Master**: Bir master çökse bile cluster çalışmaya devam eder
- **Önerilen**: Production ortamlar için en az 3 master node kullanın

## 🚀 Hızlı Başlangıç

### 1. Inventory Dosyasını Düzenleyin

`inventory/cluster_inventory.yml` dosyasını kendi ortamınıza göre düzenleyin:

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

**Not**: Eğer worker node istemiyorsanız, worker bölümünü yorum satırı yapabilirsiniz. Sadece 3 master node ile HA cluster kurabilirsiniz.

### 2. Yapılandırma Değişkenlerini Ayarlayın

`playbooks/roles/k3s_setup/vars/main.yml` dosyasını düzenleyin:

```yaml
# Keepalived VIP (tüm master node'lar bu IP üzerinden bağlanır)
keepalived_vip: 192.168.1.244

# K3s Versiyonu
k3s_version: "v1.32.8+k3s1"  # İlk kurulum için
k3s_upgrade_version: "v1.32.9+k3s1"  # Upgrade için (opsiyonel)

# Hangi servisleri kurmak istediğinizi belirtin
helm_install: false
traefik_uninstall: false
ingress_install: true
metallb_install: true
cert_manager_install: true
longhorn_install: true
grafana_install: true
rancher_install: true
```

### 3. Cluster'ı Kurun

```bash
# Tüm node'larda kurulum
ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml

# Farklı SSH key kullanıyorsanız
ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml --key-file ~/.ssh/your_key
```

## 📖 Detaylı Kurulum

### Adım 1: Sistem Gereksinimlerinin Kontrolü

Playbook otomatik olarak şunları kontrol eder:
- CPU sayısı (minimum 2 master'da)
- RAM miktarı (minimum 2GB master'da)
- Disk alanı
- İşletim sistemi

### Adım 2: Hostname Yapılandırması

Her node'un hostname'i inventory'deki isimle eşleşmelidir. Playbook otomatik olarak:
- Hostname'i kontrol eder
- Gerekirse değiştirir
- `/etc/hosts` dosyasını günceller
- Gerekirse reboot yapar

### Adım 3: NTP Yapılandırması

Cluster node'ları arasında zaman senkronizasyonu kritiktir. Playbook:
- Chrony kurulumu yapar
- `time.google.com` NTP sunucusunu yapılandırır
- Servisi başlatır ve enable eder

### Adım 4: Keepalived Kurulumu (Master Node'larda)

Keepalived, HA cluster'larda VIP yönetimi için kullanılır:
- **3+ Master**: Keepalived kurulur, yapılandırılır ve başlatılır
- **1-2 Master**: Keepalived kurulur ama yapılandırılmaz (gelecek için hazır)

### Adım 5: K3s Kurulumu

K3s kurulumu master sayısına göre otomatik olarak yapılır:

**Single Master (1 master):**
```bash
k3s server --cluster-init --tls-san <keepalived_vip>
```

**HA Mode (3+ master):**
- İlk master: `k3s server --cluster-init --tls-san <keepalived_vip>`
- Diğer master'lar: `k3s server --server https://<keepalived_vip>:6443 --token <token>`

**Worker Node'lar:**
```bash
k3s agent --server https://<keepalived_vip>:6443 --token <token>
```

### Adım 6: Helm Kurulumu

Helm, Kubernetes paket yöneticisi olarak kurulur (eğer `helm_install: true` ise).

### Adım 7: Servis Kurulumları

Yapılandırmaya göre şu servisler kurulur:
- **Traefik Kaldırma**: Varsayılan Traefik ingress kaldırılır
- **NGINX Ingress**: Ingress controller kurulur
- **MetalLB**: Load balancer kurulur
- **Cert-Manager**: SSL/TLS sertifika yönetimi
- **Longhorn**: Distributed block storage
- **kube-prometheus-stack**: Prometheus + Grafana + Alertmanager
- **Rancher**: Kubernetes management platform

## ⚙️ Yapılandırma

### Ana Yapılandırma Dosyası

`playbooks/roles/k3s_setup/vars/main.yml` dosyasında tüm yapılandırma değişkenleri bulunur:

```yaml
# Kullanıcı ve SSH
ansible_user: root
ansible_ssh_private_key_file: /home/user/.ssh/homelab

# Keepalived
keepalived_vip: 192.168.1.244
keepalived_auth_pass: P@ssw0rd123!

# K3s Versiyonları
k3s_version: "v1.32.8+k3s1"
k3s_upgrade_version: "v1.32.9+k3s1"  # Opsiyonel

# Servis Kurulumları
helm_install: false
traefik_uninstall: false
ingress_install: true
metallb_install: true
cert_manager_install: true
longhorn_install: true
grafana_install: true
rancher_install: true
```

### Master/Worker Pod Dağılımı

Kurulum, **master sayısına göre otomatik olarak** values dosyalarını seçer:
- **3+ Master (HA)**: `values-ha.yml` dosyaları kullanılır
- **1 Master (Single)**: `values-single-master.yml` dosyaları kullanılır

**Pod Dağılımı Stratejisi:**
- **System Pod'lar** (Prometheus, Alertmanager, Cert-Manager, Ingress, MetalLB Controller): Master node'larda çalışır
- **Application Pod'lar** (Grafana): Worker node'larda çalışır
- **Storage Pod'lar** (Longhorn): Master preferred, worker fallback stratejisi ile çalışır

## 💻 Kullanım Örnekleri

### Cluster Kurulumu

```bash
# Tüm node'larda kurulum
ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml
```

### Cluster Upgrade

```bash
# Tüm node'larda upgrade etme
ansible-playbook -i inventory/cluster_inventory.yml upgrade.yml
```

### Cluster'a Yeni Node Ekleme

```bash
# Extra node ekleme
ansible-playbook -i inventory/cluster_inventory.yml add_node.yml
```

### Cluster Durumunu Kontrol Etme

```bash
# Master node'a SSH ile bağlanın
ssh root@192.168.1.145

# Node'ları kontrol edin
kubectl get nodes -o wide

# Pod'ları kontrol edin
kubectl get pods -A -o wide

# Servisleri kontrol edin
kubectl get svc -A
```

### Rancher'a Erişim

Rancher kurulumundan sonra bootstrap şifresini almak için:

```bash
kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}{{"\n"}}'
```

Rancher'a erişim: `https://rancher.homelab.local` (MetalLB IP'si ile `/etc/hosts` dosyanızı güncelleyin)

### Grafana'ya Erişim

Grafana admin şifresini almak için:

```bash
kubectl get secret --namespace monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```

Grafana'ya erişim: `https://grafana.homelab.local` (admin kullanıcı adı ile)

## 🔄 K3s Cluster Upgrade

Cluster'ınızı **kesintisiz** bir şekilde güncellemek için rolling update stratejisi kullanılır.

### Upgrade Süreci

1. **Versiyon Kontrolü**: Tüm node'ların mevcut K3s versiyonları kontrol edilir
2. **Downgrade Önleme**: Mevcut versiyon hedef versiyondan yüksekse upgrade atlanır
3. **Master Node'ları Güncelleme** (Sırayla):
   - Master node'lar **tek tek** (`serial: 1`) güncellenir
   - Her master node için:
     - Node **drain** edilir (pod'lar diğer node'lara taşınır)
     - K3s upgrade edilir
     - Node **uncordon** edilir
     - Pod'ların stabilize olması beklenir
4. **Worker Node'ları Güncelleme** (Sırayla):
   - Worker node'lar **tek tek** güncellenir
   - Aynı süreç uygulanır
5. **Otomatik Temizlik**: `SchedulingDisabled` durumunda kalan node'lar otomatik uncordon edilir
6. **Pod Rebalancing**: Upgrade sonrası pod'lar yeniden dağıtılır
7. **Cluster Doğrulama**: Tüm node'ların Ready durumda olduğu kontrol edilir

### Upgrade Çalıştırma

**1. Versiyon Belirleme**: `playbooks/roles/k3s_setup/vars/main.yml` dosyasında:

```yaml
# İlk kurulum versiyonu
k3s_version: "v1.32.8+k3s1"

# Upgrade versiyonu (opsiyonel - belirtilmezse k3s_version kullanılır)
k3s_upgrade_version: "v1.32.9+k3s1"
```

**2. Upgrade Komutu**:

```bash
# Tüm node'ları upgrade et
ansible-playbook -i inventory/cluster_inventory.yml upgrade.yml
```

### Upgrade Yapılandırması

`playbooks/roles/update_cluster/vars/main.yml` dosyasında ayarlanabilir parametreler:

```yaml
upgrade_drain_timeout: 600          # Drain timeout (saniye) - PVC-heavy workload'lar için artırıldı
upgrade_drain_grace_period: 120     # Pod termination grace period (saniye)
upgrade_wait_for_pods: 60           # Pod stabilize bekleme süresi (saniye)
upgrade_force: false                 # Versiyon eşleşse bile zorla upgrade (önerilmez)
```

### Önemli Notlar

⚠️ **Backup**: Upgrade öncesi önemli verilerinizi yedekleyin  
⚠️ **Test**: Production'a uygulamadan önce test ortamında deneyin  
⚠️ **Versiyon Uyumluluğu**: K3s versiyonları arasında uyumluluk kontrolü yapın  
⚠️ **Etcd**: HA kurulumlarda etcd uyumluluğu önemlidir, master node'ları önce güncelleyin  
⚠️ **Rolling Update**: Node'lar sırayla güncellenir, cluster kesintisiz çalışmaya devam eder  
⚠️ **Downgrade Önleme**: Mevcut versiyon hedef versiyondan yüksekse upgrade yapılmaz

### Upgrade Sonrası Kontrol

```bash
# Node durumunu kontrol et
kubectl get nodes -o wide

# Node versiyonlarını kontrol et
kubectl get nodes -o custom-columns=NAME:.metadata.name,VERSION:.status.nodeInfo.kubeletVersion

# Pod durumunu kontrol et
kubectl get pods -A

# K3s versiyonunu kontrol et
kubectl version --short
```

## ➕ Extra Node Ekleme

Mevcut K3s cluster'ınıza yeni master veya worker node'lar ekleyebilirsiniz. Bu işlem **idempotent**'tir.

### Önkoşullar

**1. Inventory'ye Yeni Node Ekleme**: `inventory/cluster_inventory.yml` dosyasına yeni node'u ekleyin:

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
        master-4:  # Yeni master node
          ansible_host: 192.168.1.148
    worker:
      hosts:
        worker-1:
          ansible_host: 192.168.1.245
        worker-2:
          ansible_host: 192.168.1.246
        worker-3:  # Yeni worker node
          ansible_host: 192.168.1.247
```

**2. SSH Erişimi**: Yeni node'lara SSH erişimi olmalı ve sudo yetkisi bulunmalıdır.

### Kullanım Örnekleri

**Tüm yeni node'ları eklemek için:**
```bash
ansible-playbook -i inventory/cluster_inventory.yml add_node.yml
```

### Özellikler

✅ **Otomatik Hostname Yapılandırması**: Yeni node'un hostname'i otomatik olarak ayarlanır (gerekirse reboot yapılır)  
✅ **NTP Yapılandırması**: Chrony kurulumu ve yapılandırması otomatik yapılır  
✅ **Idempotent**: Zaten cluster'a eklenmiş node'ları tekrar eklemez  
✅ **Versiyon Uyumluluğu**: Yeni node'lar mevcut cluster versiyonu ile uyumlu kurulur  
✅ **HA Desteği**: 3+ master node'lu HA cluster'lara master ekleyebilir  
✅ **Single Master Desteği**: Tek master node'lu cluster'lara master ekleyerek HA'ya dönüştürebilir  
✅ **Keepalived Otomatik Yapılandırma**: 3+ master olduğunda Keepalived otomatik yapılandırılır

### Önemli Notlar

⚠️ **Versiyon Uyumluluğu**: Yeni node'ların versiyonu mevcut cluster versiyonu ile uyumlu olmalıdır. Versiyon `playbooks/roles/k3s_setup/vars/main.yml` dosyasındaki `k3s_version` değişkeninden alınır.

⚠️ **Hostname Değişikliği**: Eğer node'un hostname'i inventory'deki isimle eşleşmiyorsa, hostname değiştirilir ve sistem reboot edilir.

⚠️ **Token Güvenliği**: K3s token'ı otomatik olarak ilk master node'dan alınır.

⚠️ **Single Master'dan HA'ya Dönüşüm**: İlk master node `--cluster-init` ile kurulmuş olmalıdır. Aksi halde ek master eklenemez.

### Doğrulama

Node'un başarıyla eklendiğini kontrol etmek için:

```bash
kubectl get nodes -o wide
```

Yeni node'un `Ready` durumunda olduğunu görmelisiniz.

## 🔍 HA Modu Kontrolü

Cluster'ınızın HA modunda çalışıp çalışmadığını kontrol etmek için:

### Komple Kontrol Komutu

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

### Tek Tek Kontrol

```bash
# 1. Master node sayısı (3+ = HA)
kubectl get nodes -l node-role.kubernetes.io/master --no-headers | wc -l

# 2. ETCD node sayısı (3+ = HA)
kubectl get nodes -l node-role.kubernetes.io/etcd --no-headers | wc -l

# 3. Keepalived VIP kontrolü
ip -4 a show ens3 | grep 192.168.1.244

# 4. ETCD cluster dizini (varsa = HA)
ls -d /var/lib/rancher/k3s/server/db/etcd

# 5. Tüm master node'ları listele
kubectl get nodes -l node-role.kubernetes.io/master -o wide
```

**HA Modu Kriterleri:**
- ✅ 3 veya daha fazla master node
- ✅ Her master'da ETCD çalışıyor
- ✅ `--cluster-init` ile başlatılmış (etcd cluster dizini var)
- ✅ Keepalived VIP yapılandırılmış (opsiyonel ama önerilir)

## 📊 Pod Dağılımı ve Replica Stratejisi

### Replica Dağılımı

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

### Pod Dağılımı Tablosu

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

## 🔐 SSL/TLS Sertifikaları

Tüm servisler için SSL/TLS sertifikaları `cert-manager` ile otomatik olarak yönetilir. Cert dosyaları ayrı dizinlerde tutulur:

### Grafana
- **Dizin**: `files/my-charts/grafana/cert/`
- **Dosyalar**:
  - `homelab.grafana.yml` - Ingress
  - `homelab-grafana-certificate.yml` - Certificate
- **Domain**: `grafana.homelab.local`

### Longhorn
- **Dizin**: `files/my-charts/longhorn/cert/`
- **Dosyalar**:
  - `homelab.longhorn.yml` - Ingress
  - `homelab-longhorn-certificate.yml` - Certificate
- **Domain**: `longhorn.homelab.local`

### Rancher
- **Dizin**: `files/my-charts/rancher/cert/`
- **Dosyalar**:
  - `rancher.homelab.yml` - Ingress
  - `rancher-homelab-certificate.yml` - Certificate
- **Domain**: `rancher.homelab.local`

### Hosts Dosyası Yapılandırması

Yerel erişim için `/etc/hosts` dosyanıza şu satırları ekleyin:

```bash
# K3s Cluster Services
192.168.1.242    rancher.homelab.local
192.168.1.242    grafana.homelab.local
192.168.1.242    longhorn.homelab.local
```

**Not**: IP adresi (`192.168.1.242`) MetalLB LoadBalancer IP'sidir. Ingress Controller servisinin IP'sini kontrol etmek için:

```bash
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

## 💾 Longhorn StorageClass

Longhorn, Kubernetes için dağıtılmış blok depolama sağlar. Kurulum sırasında otomatik olarak 6 farklı StorageClass oluşturulur:

### StorageClass'lar

| StorageClass | ReclaimPolicy | Replica Sayısı | Kullanım Amacı |
|-------------|---------------|---------------|----------------|
| `longhorn-retain-1` | Retain | 1 | Single Master kurulumlar için |
| `longhorn-retain-2` | Retain | 2 | HA kurulumlar için (önerilen) |
| `longhorn-retain-3` | Retain | 3 | Yüksek veri güvenliği gereken durumlar |
| `longhorn-delete-1` | Delete | 1 | Geçici veriler için |
| `longhorn-delete-2` | Delete | 2 | Geçici veriler için (HA) |
| `longhorn-delete-3` | Delete | 3 | Geçici veriler için (yüksek güvenlik) |

### Mevcut PVC Yapılandırması

Kurulumda kullanılan StorageClass'lar:

- **Prometheus**: `longhorn-retain-2` (HA için 2 replica)
- **Alertmanager**: `longhorn-retain-2` (HA için 2 replica)
- **Grafana**: `longhorn-retain-2` (HA için 2 replica)

### Veri Kalıcılığı ve Güvenlik

✅ **ReclaimPolicy: Retain** - PVC silinse bile volume'lar korunur, manuel temizlik gerekir  
✅ **Pod Restart**: Veri korunur (PVC bağlı kalır)  
✅ **Node Restart**: Veri korunur (Longhorn volume'lar farklı node'larda replike edilir)  
✅ **HA Kurulum**: `longhorn-retain-2` ile bir node çökse bile veri kaybı olmaz

### StorageClass Kontrolü

Mevcut StorageClass'ları kontrol etmek için:

```bash
kubectl get storageclass
```

PVC'leri kontrol etmek için:

```bash
kubectl get pvc -A
```

### Öneriler

- **HA Kurulumlar (3+ Master)**: `longhorn-retain-2` veya `longhorn-retain-3` kullanın
- **Single Master**: `longhorn-retain-1` yeterlidir
- **Production Ortamları**: En az 2 replica (`longhorn-retain-2`) kullanın
- **Kritik Veriler**: 3 replica (`longhorn-retain-3`) kullanın

## 🔧 Troubleshooting

### Node'lar Ready Durumunda Değil

```bash
# Node durumunu kontrol et
kubectl get nodes

# Node detaylarını kontrol et
kubectl describe node <node-name>

# K3s servis durumunu kontrol et
systemctl status k3s  # Master node'larda
systemctl status k3s-agent  # Worker node'larda

# K3s loglarını kontrol et
journalctl -u k3s -n 50 --no-pager
```

### Pod'lar Çalışmıyor

```bash
# Tüm pod'ları listele
kubectl get pods -A

# Problemli pod'ları kontrol et
kubectl describe pod <pod-name> -n <namespace>

# Pod loglarını kontrol et
kubectl logs <pod-name> -n <namespace>
```

### Keepalived VIP Çalışmıyor

```bash
# Keepalived servis durumunu kontrol et
systemctl status keepalived

# Keepalived loglarını kontrol et
journalctl -u keepalived -n 50 --no-pager

# VIP'in hangi node'da olduğunu kontrol et
ip -4 a show ens3 | grep 192.168.1.244
```

### Upgrade Sonrası Sorunlar

```bash
# Node'u manuel olarak uncordon et
kubectl uncordon <node-name>

# Node'u manuel olarak drain et
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# K3s servisini yeniden başlat
systemctl restart k3s  # Master node'larda
systemctl restart k3s-agent  # Worker node'larda
```

### Rancher Bootstrap Şifresi

```bash
kubectl get secret --namespace cattle-system bootstrap-secret -o go-template='{{.data.bootstrapPassword|base64decode}}{{"\n"}}'
```

### Grafana Admin Şifresi

```bash
kubectl get secret --namespace monitoring kube-prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode
```

## 📁 Yapı

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

**Not**: Bu role şu anda Ubuntu 22.04 üzerinde test edilmiştir. K3s'in resmi kurulum scripti (`curl -sfL https://get.k3s.io | sh -`) kullanıldığı için diğer Linux dağıtımlarında da çalışması beklenir.
