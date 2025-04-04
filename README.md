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
- [x] install Grafana ( Grafana Dashboard : 15760, 15757, 15759, 8171, 18283 )


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
  - Ingress-Nginx v1.0
  - Longhorn v1.6.1
  - Metallb v0.14.5
  - Rancehr v2.8.2
  - Prometheus & Grafana
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
│           │       │   ├── selfsigned-issuer.yaml
│           │       │   └── values.yaml
│           │       ├── grafana
│           │       │   ├── cert
│           │       │   │   ├── homelab-grafana-certificate.yaml
│           │       │   │   └── homelab.grafana.yaml
│           │       │   ├── grafana-values.yaml
│           │       │   └── prometheus-values.yaml
│           │       ├── ingress
│           │       │   └── values.yaml
│           │       ├── longhorn
│           │       │   ├── cert
│           │       │   │   ├── homelab-longhorn-certificate.yaml
│           │       │   │   └── homelab.longhorn.yaml
│           │       │   ├── storageclass.yaml
│           │       │   └── values.yaml
│           │       ├── metallb
│           │       │   └── metallb-config.yaml
│           │       └── rancher
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
│           │   ├── 05_ingress_install.yaml
│           │   ├── 06_metallb_install.yaml
│           │   ├── 07_cert_manager_install.yaml
│           │   ├── 08_longhorn_install.yaml
│           │   ├── 09_grafana_install.yaml
│           │   ├── 10_rancher_install.yaml
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

21 directories, 40 files
```
