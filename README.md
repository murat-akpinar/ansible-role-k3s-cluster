#  Ansible Role: K3S Cluster
![release](https://img.shields.io/badge/release-v1.0-blue)
- Şuan sadece ubutnu 22.04 denedim fakat `curl -sfL https://get.k3s.io | sh -` scripti ile kurduğu için sanırım diğer dağıtımlarda sorun olmayacaktır.


<img src="https://k3s.io/img/k3s-logo-light.svg" alt="k3s" style="max-width: 100%;">

 
# Ansible Role: K3S Cluster Kurulumu

Bu Ansible rolü, otomatik olarak **K3S** tabanlı Kubernetes kümesi kurulumunu gerçekleştirir. Kurulum, bir adet master ve birden fazla worker düğümünden oluşan bir yapıyı destekler.

## Önkoşullar

- Etcd : Bir kümenin çoğunlukla çalışmasını gerektirir. İki master düğümün bulunduğu bir kümede, bir master düğüm kapandığında çoğunluk kaybolur ve bu nedenle küme yönetilemez hale gelir. BU yüzden en az 3 Mastner node olmalı

- **Ansible** ve galaxy collectionları yüklü olması.

```bash
ansible-galaxy collection install community.general

```

- **SSH** erişimi olan ve sudo yetkisine sahip Linux tabanlı hedef sunucular.
````bash
ssh-copy-id -i ~/.ssh/mykey root@192.168.1.152
ssh-copy-id -i ~/.ssh/mykey root@192.168.1.153
ssh-copy-id -i ~/.ssh/mykey root@192.168.1.154
ssh-copy-id -i ~/.ssh/mykey root@192.168.1.156
````

Aynı zamanda root kullanıcısın authorized_keys dosyasında güvenlik için aşşağıda ki satır olabilir bu komut ile onu kaldırabilirsiniz.

```bash
no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command="echo 'Please login as the user \"user\" rather than the user \"root\".';echo;sleep 10;exit 142"
```

```bash
sed -i 's/^no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command="echo.*exit 142" *//g' ~/.ssh/authorized_keys

```

- **keepalived_vip:** vars dizininden keepalived için bir ip adresi belirtmeniz gerekli bu ip adresi ile nodlar bir birine bağlanacaktır.
```bash
keepalived_vip: 192.168.1.244
```

- İstediğiniz **Helm** içerikleri yüklemek veya yüklememek için vars/main.yml dosyasından true - false olarak yönetebilirsiniz.

```bash
traefik_uninstall: true
ingress_install: true
metallb_install: true
cert_manager_install: true
longhorn_install: true
grafana_install: true

```

2. **Envanter Dosyasını Düzenle**: Projenin kök dizinindeki `cluster_inventory.yml` dosyasını kendi ortamınıza göre ayarlayın.
- Eğer hiç **worker** istemiyorsanız o kısmı açıklama satırı haline getirebilirsiniz sadece **3 Master Node HA** şeklinde kurabilirsiniz.
Örnek yapılandırma:
```
all:
  children:
    master:
      hosts:
        master-1:
          ansible_host: 192.168.1.152
        master-2:
          ansible_host: 192.168.1.153
        master-3:
          ansible_host: 192.168.1.154
    worker:
      hosts:
        worker-1:
          ansible_host: 192.168.1.156
        # worker-2:
        #   ansible_host: 192.168.1.156
        # worker-3:
        #   ansible_host: 192.168.1.157
```

4. **Playbook'u Çalıştırılması**: 
- Eğer **k3s cluster**  kurmak isterseniz site.yml kullanabilirsiniz. Eğer farklı bir key kullanıyorsanız `--key-file ~/.ssh/key-name` parametresi ile belirtebilirsiniz.

```bash
ansible-playbook -i inventory/cluster_inventory.yml site.yml 
```

## Yapılandırma

`vars/main.yml` dosyasında bulunan değişkenleri kendi ihtiyaçlarınıza göre düzenleyebilirsiniz. Bu değişkenler, cluster kurulumu sırasında kullanılacak ayarları içerir.

### Master/Worker Pod Dağılımı

Kurulum, **master sayısına göre otomatik olarak** values dosyalarını seçer:
- **3+ Master (HA)**: `values-ha.yml` dosyaları kullanılır
- **1 Master (Single)**: `values-single-master.yml` dosyaları kullanılır

**Pod Dağılımı Stratejisi:**
- **System Pod'lar** (Prometheus, Alertmanager, Cert-Manager, Ingress, MetalLB Controller): Master node'larda çalışır
- **Application Pod'lar** (Grafana): Worker node'larda çalışır
- **Storage Pod'lar** (Longhorn): Master preferred, worker fallback stratejisi ile çalışır

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

### SSL/TLS Sertifikaları

Tüm servisler için SSL/TLS sertifikaları `cert-manager` ile otomatik olarak yönetilir. Cert dosyaları ayrı dizinlerde tutulur:

- **Grafana**: `files/my-charts/grafana/cert/`
  - `homelab.grafana.yml` - Ingress
  - `homelab-grafana-certificate.yml` - Certificate
  - Domain: `grafana.homelab.local`

- **Longhorn**: `files/my-charts/longhorn/cert/`
  - `homelab.longhorn.yml` - Ingress
  - `homelab-longhorn-certificate.yml` - Certificate
  - Domain: `longhorn.homelab.local`

- **Rancher**: `files/my-charts/rancher/cert/`
  - `rancher.homelab.yml` - Ingress
  - `rancher-homelab-certificate.yml` - Certificate
  - Domain: `rancher.homelab.local`

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

### Longhorn StorageClass ve Veri Kalıcılığı

Longhorn, Kubernetes için dağıtılmış blok depolama sağlar. Kurulum sırasında otomatik olarak 6 farklı StorageClass oluşturulur:

#### StorageClass'lar

| StorageClass | ReclaimPolicy | Replica Sayısı | Kullanım Amacı |
|-------------|---------------|---------------|----------------|
| `longhorn-retain-1` | Retain | 1 | Single Master kurulumlar için |
| `longhorn-retain-2` | Retain | 2 | HA kurulumlar için (önerilen) |
| `longhorn-retain-3` | Retain | 3 | Yüksek veri güvenliği gereken durumlar |
| `longhorn-delete-1` | Delete | 1 | Geçici veriler için |
| `longhorn-delete-2` | Delete | 2 | Geçici veriler için (HA) |
| `longhorn-delete-3` | Delete | 3 | Geçici veriler için (yüksek güvenlik) |

#### Mevcut PVC Yapılandırması

Kurulumda kullanılan StorageClass'lar:

- **Prometheus**: `longhorn-retain-2` (HA için 2 replica)
- **Alertmanager**: `longhorn-retain-2` (HA için 2 replica)
- **Grafana**: `longhorn-retain-2` (HA için 2 replica)

#### Veri Kalıcılığı ve Güvenlik

✅ **ReclaimPolicy: Retain** - PVC silinse bile volume'lar korunur, manuel temizlik gerekir
✅ **Pod Restart**: Veri korunur (PVC bağlı kalır)
✅ **Node Restart**: Veri korunur (Longhorn volume'lar farklı node'larda replike edilir)
✅ **HA Kurulum**: `longhorn-retain-2` ile bir node çökse bile veri kaybı olmaz

#### StorageClass Kontrolü

Mevcut StorageClass'ları kontrol etmek için:

```bash
kubectl get storageclass
```

PVC'leri kontrol etmek için:

```bash
kubectl get pvc -A
```

#### Öneriler

- **HA Kurulumlar (3+ Master)**: `longhorn-retain-2` veya `longhorn-retain-3` kullanın
- **Single Master**: `longhorn-retain-1` yeterlidir
- **Production Ortamları**: En az 2 replica (`longhorn-retain-2`) kullanın
- **Kritik Veriler**: 3 replica (`longhorn-retain-3`) kullanın

### K3s Cluster Upgrade (Rolling Update)

Cluster'ınızı **kesintisiz** bir şekilde güncellemek için rolling update stratejisi kullanılır. Upgrade işlemi node'ları sırayla günceller, böylece cluster çalışmaya devam eder.

#### Upgrade Süreci

1. **Versiyon Kontrolü**: Tüm node'ların mevcut K3s versiyonları kontrol edilir
2. **Master Node'ları Güncelleme** (Sırayla):
   - Master node'lar **tek tek** (`serial: 1`) güncellenir
   - Her master node için:
     - Node **drain** edilir (pod'lar diğer node'lara taşınır)
     - K3s upgrade edilir
     - Node **uncordon** edilir (yeni pod'lar alabilir)
     - Pod'ların stabilize olması beklenir (60 saniye)
3. **Worker Node'ları Güncelleme** (Sırayla):
   - Worker node'lar **tek tek** (`serial: 1`) güncellenir
   - Her worker node için aynı süreç uygulanır
4. **Cluster Doğrulama**: Tüm node'ların Ready durumda olduğu ve pod'ların çalıştığı kontrol edilir

#### Upgrade Çalıştırma

1. **Versiyon Belirleme**: `playbooks/roles/update_cluster/vars/main.yml` dosyasında güncellenecek versiyonu belirtin:

```yaml
k3s_target_version: "v1.31.6+k3s1"  # Güncellenecek K3s versiyonu
```

2. **Upgrade Komutu**:

```bash
ansible-playbook -i inventory/cluster_inventory.yml upgrade.yml
```

#### Upgrade Yapılandırması

`playbooks/roles/update_cluster/vars/main.yml` dosyasında ayarlanabilir parametreler:

```yaml
k3s_target_version: "v1.31.6+k3s1"  # Güncellenecek versiyon
upgrade_drain_timeout: 300          # Drain timeout (saniye)
upgrade_wait_for_pods: 60           # Pod stabilize bekleme süresi (saniye)
upgrade_force: false                 # Versiyon eşleşse bile zorla upgrade
```

#### Önemli Notlar

⚠️ **Backup**: Upgrade öncesi önemli verilerinizi yedekleyin
⚠️ **Test**: Production'a uygulamadan önce test ortamında deneyin
⚠️ **Versiyon Uyumluluğu**: K3s versiyonları arasında uyumluluk kontrolü yapın
⚠️ **Etcd**: HA kurulumlarda etcd uyumluluğu önemlidir, master node'ları önce güncelleyin
⚠️ **Rolling Update**: Node'lar sırayla güncellenir, cluster kesintisiz çalışmaya devam eder

#### Upgrade Sonrası Kontrol

Upgrade sonrası cluster durumunu kontrol etmek için:

```bash
# Node durumunu kontrol et
kubectl get nodes

# Pod durumunu kontrol et
kubectl get pods --all-namespaces

# K3s versiyonunu kontrol et
kubectl version --short
```

#### Troubleshooting

Upgrade sırasında sorun yaşarsanız:

1. Node durumunu kontrol edin:
   ```bash
   kubectl get nodes
   ```

2. Node'u manuel olarak uncordon edin:
   ```bash
   kubectl uncordon <node-name>
   ```

3. K3s servis durumunu kontrol edin:
   ```bash
   systemctl status k3s  # Master node'larda
   systemctl status k3s-agent  # Worker node'larda
   ```

### Extra Node Ekleme (Mevcut Cluster'a Yeni Node Ekleme)

Mevcut K3s cluster'ınıza yeni master veya worker node'lar ekleyebilirsiniz. Bu işlem **idempotent**'tir, yani zaten cluster'a eklenmiş node'ları tekrar eklemez.

#### Önkoşullar

1. **Inventory'ye Yeni Node Ekleme**: `inventory/cluster_inventory.yml` dosyasına yeni node'u ekleyin:

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
        worker-3:
          ansible_host: 192.168.1.247
        worker-4:  # Yeni worker node
          ansible_host: 192.168.1.249
```

2. **SSH Erişimi**: Yeni node'lara SSH erişimi olmalı ve sudo yetkisi bulunmalıdır.

#### Kullanım Örnekleri

**1. Tek bir worker node eklemek için:**
```bash
ansible-playbook -i inventory/cluster_inventory.yml add_node.yml --limit worker-4
```

**2. Tek bir master node eklemek için:**
```bash
ansible-playbook -i inventory/cluster_inventory.yml add_node.yml --limit master-4
```

**3. Tüm yeni node'ları eklemek için:**
```bash
ansible-playbook -i inventory/cluster_inventory.yml add_node.yml
```

**4. Sadece worker node'ları eklemek için:**
```bash
ansible-playbook -i inventory/cluster_inventory.yml add_node.yml --limit worker
```

**5. Sadece master node'ları eklemek için:**
```bash
ansible-playbook -i inventory/cluster_inventory.yml add_node.yml --limit master
```

#### Özellikler

✅ **Otomatik Hostname Yapılandırması**: Yeni node'un hostname'i otomatik olarak ayarlanır (gerekirse reboot yapılır)
✅ **NTP Yapılandırması**: Chrony kurulumu ve yapılandırması otomatik yapılır
✅ **Idempotent**: Zaten cluster'a eklenmiş node'ları tekrar eklemez
✅ **Versiyon Uyumluluğu**: Yeni node'lar mevcut cluster versiyonu ile uyumlu kurulur
✅ **HA Desteği**: 3+ master node'lu HA cluster'lara master ekleyebilir
✅ **Single Master Desteği**: Tek master node'lu cluster'lara master ekleyerek HA'ya dönüştürebilir

#### Önemli Notlar

⚠️ **Versiyon Uyumluluğu**: Yeni node'ların versiyonu mevcut cluster versiyonu ile uyumlu olmalıdır. Versiyon `playbooks/roles/k3s_setup/vars/main.yml` dosyasındaki `k3s_version` değişkeninden alınır.

⚠️ **Hostname Değişikliği**: Eğer node'un hostname'i inventory'deki isimle eşleşmiyorsa, hostname değiştirilir ve sistem reboot edilir.

⚠️ **Token Güvenliği**: K3s token'ı otomatik olarak ilk master node'dan alınır.

#### Doğrulama

Node'un başarıyla eklendiğini kontrol etmek için:

```bash
kubectl get nodes
```

Yeni node'un `Ready` durumunda olduğunu görmelisiniz.

## Yapılacaklar

### K3S Cluster Kurulumu
- [x] Sistem Gereksinimlerinin Kontrol Edilmesi
- [X] hostname'in ayarlanması
- [X] NTP için chrony yüklenmesi ve sekronize edilmesi
- [X] keeplived'in Kurulumu
- [X] k3s'nin Kurulumu
- [X] Kubectl Komutlarının Normal Kullanıcılar Tarafından Sudo İhtiyacı Olmadan Çalıştırılması
- [X] Worker Node'ların Master Node'a Bağlanması
- [ ] Worker Node'ların Rollendirilmesi

### Ön Tanımlı Gelecek Paketler
- [x] install metallb
- [x] install longhorn
- [x] install cert-manager
- [x] install ingress-nginx
- [x] install rancher  
- [x] install Grafana (kube-prometheus-stack ile entegre)
- [x] SSL/TLS sertifikaları (cert-manager ile otomatik yönetim)
- [x] Master/Worker pod dağılımı (master preferred, worker fallback)
- [x] HA ve Single Master desteği (otomatik values dosyası seçimi)

###  Örnek Çıktı
````bash
TASKS RECAP **********************************************************************************************************************
Cumartesi 22 Kasım 2025  19:46:13 +0300 (0:00:07.231)       0:16:14.163 *******
===============================================================================
Gathering Facts ----------------------------------------------------------------------------------------------------------- 4.24s
k3s_setup : Check minimum CPU requirements -------------------------------------------------------------------------------- 0.89s
k3s_setup : Verify CPU count ---------------------------------------------------------------------------------------------- 0.07s
k3s_setup : Check minimum RAM requirements -------------------------------------------------------------------------------- 0.88s
k3s_setup : Gather OS distribution facts ---------------------------------------------------------------------------------- 2.34s
k3s_setup : Set OS family variable ---------------------------------------------------------------------------------------- 0.06s
k3s_setup : Check if Chrony is installed (Debian-based) ------------------------------------------------------------------- 0.67s
k3s_setup : Debug - Show if Chrony is installed (Debian-based) ------------------------------------------------------------ 0.08s
k3s_setup : Install NTP package (Debian-based) --------------------------------------------------------------------------- 18.41s
k3s_setup : Check if Chrony service is enabled (Debian-based) ------------------------------------------------------------- 0.70s
k3s_setup : Start and enable NTP service (Debian-based) ------------------------------------------------------------------- 0.06s
k3s_setup : Check if Chrony is installed (RHEL-based) --------------------------------------------------------------------- 0.06s
k3s_setup : Debug - Show if Chrony is installed (RHEL-based) -------------------------------------------------------------- 0.06s
k3s_setup : Install NTP package (RHEL-based) ------------------------------------------------------------------------------ 0.06s
k3s_setup : Check if Chrony service is enabled (RHEL-based) --------------------------------------------------------------- 0.05s
k3s_setup : Start and enable NTP service (RHEL-based) --------------------------------------------------------------------- 0.05s
k3s_setup : Check if NTP server is already configured (Debian-based) ------------------------------------------------------ 0.63s
k3s_setup : Configure NTP server (Debian-based) --------------------------------------------------------------------------- 0.84s
k3s_setup : Check if NTP server is already configured (RHEL-based) -------------------------------------------------------- 0.07s
k3s_setup : Deploy Chrony configuration (Debian-based) -------------------------------------------------------------------- 1.62s

PLAYBOOK RECAP *******************************************************************************************************************
Playbook run took 0 days, 0 hours, 16 minutes, 14 seconds
```


````bash
>>=======================================================================<<
||                                                                       ||
||   _  __ _____ ____     ____  _     _   _  ____  _____  _____  ____    ||
||  | |/ /|___ // ___|   / ___|| |   | | | |/ ___||_   _|| ____||  _ \   ||
||  | ' /   |_ \\___ \  | |    | |   | | | |\___ \  | |  |  _|  | |_) |  ||
||  | . \  ___) |___) | | |___ | |___| |_| | ___) | | |  | |___ |  _ <   ||
||  |_|\_\|____/|____/   \____||_____|\___/ |____/  |_|  |_____||_| \_\  ||
||                                                                       ||
>>=======================================================================<<

k3s Cluster / Ver: "1.1"  / Developped by: Murat Akpınar

Versions:
  - k3s v1.29.5+k3s1
  - Cert-Manager v1.13.1
  - Ingress-Nginx v1.10.0
  - Longhorn v1.6.1
  - MetalLB v0.14.5
  - Rancher v2.8.2
  - kube-prometheus-stack (Prometheus & Grafana entegre)

Features:
  - ✅ HA (3+ Masters) ve Single Master desteği
  - ✅ Otomatik values dosyası seçimi (master sayısına göre)
  - ✅ Master/Worker pod dağılımı (system pods master'da, apps worker'da)
  - ✅ SSL/TLS sertifikaları (cert-manager ile otomatik)
  - ✅ Ingress ile domain yönetimi (homelab.local)
````


````bash
kubectl get nodes
NAME       STATUS   ROLES                  AGE    VERSION
master-1   Ready    control-plane,master   104m   v1.31.6+k3s1
worker-1   Ready    <none>                 103m   v1.31.6+k3s1
worker-2   Ready    <none>                 103m   v1.31.6+k3s1
worker-3   Ready    <none>                 103m   v1.31.6+k3s1
````

# Yapı

```bash
├── ansible.cfg
├── collections
│   └── requirements.yml
├── hosts
├── inventory
│   └── cluster_inventory.yml
├── LICENSE
├── playbooks
│   └── roles
│       └── k3s_setup
│           ├── files
│           │   └── my-charts
│           │       ├── cert-manager
│           │       │   ├── selfsigned-issuer.yml
│           │       │   ├── values-ha.yml
│           │       │   └── values-single-master.yml
│           │       ├── grafana
│           │       │   ├── cert
│           │       │   │   ├── homelab-grafana-certificate.yml
│           │       │   │   └── homelab.grafana.yml
│           │       │   ├── kube-prometheus-stack-values-master-only.yml
│           │       │   ├── kube-prometheus-stack-values-single-master.yml
│           │       │   └── kube-prometheus-stack-values.yml
│           │       ├── ingress
│           │       │   ├── values-ha.yml
│           │       │   └── values-single-master.yml
│           │       ├── longhorn
│           │       │   ├── cert
│           │       │   │   ├── homelab-longhorn-certificate.yml
│           │       │   │   └── homelab.longhorn.yml
│           │       │   ├── storageclass.yml
│           │       │   ├── values-ha.yml
│           │       │   └── values-single-master.yml
│           │       ├── metallb
│           │       │   ├── metallb-config.yml
│           │       │   ├── values-ha.yml
│           │       │   └── values-single-master.yml
│           │       └── rancher
│           │           ├── cert
│           │           │   ├── rancher-homelab-certificate.yml
│           │           │   └── rancher.homelab.yml
│           │           └── rancher-deployment.yml
│           ├── handlers
│           │   └── main.yml
│           ├── meta
│           ├── tasks
│           │   ├── 00_system_requirements.yml
│           │   ├── 00_traefik_uninstall.yml
│           │   ├── 00_wellcome.yml
│           │   ├── 01_configure_hostname.yml
│           │   ├── 02_install_keepalived.yml
│           │   ├── 03_install_k3s.yml
│           │   ├── 04_install_helm.yml
│           │   ├── 05_ingress_install.yml
│           │   ├── 06_metallb_install.yml
│           │   ├── 07_cert_manager_install.yml
│           │   ├── 08_longhorn_install.yml
│           │   ├── 09_grafana_install.yml
│           │   ├── 10_rancher_install.yml
│           │   └── main.yml
│           ├── templates
│           │   ├── chrony.j2
│           │   ├── keepalived-backup.j2
│           │   ├── keepalived-master.j2
│           │   └── wellcome.j2
│           └── vars
│               └── main.yml
├── README.md
└── site.yml

22 directories, 48 files
```
