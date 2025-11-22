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
