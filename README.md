#  Ansible Role: RKE2 Cluster
![release](https://img.shields.io/badge/release-v1.0-blue)
- Şuan sadece ubutnu 22.04 denedim fakat `curl -sfL https://get.rke2.io | sh -` scripti ile kurduğu için sanırım diğer dağıtımlarda sorun olmayacaktır.


<img src="https://camo.githubusercontent.com/e8b5779608fb6e9487657a97573e6658fa8ad24ac193c00c4424bd5d83b818a1/68747470733a2f2f646f63732e726b65322e696f2f696d672f6c6f676f2d686f72697a6f6e74616c2d726b65322e737667" alt="RKE2" data-canonical-src="https://docs.rke2.io/img/logo-horizontal-rke2.svg" style="max-width: 100%;">


# Ansible Role: RKE2 Cluster Kurulumu

Bu Ansible rolü, otomatik olarak **RKE2** tabanlı Kubernetes kümesi kurulumunu gerçekleştirir. Kurulum, bir adet master ve birden fazla worker düğümünden oluşan bir yapıyı destekler.

## Önkoşullar

- **Ansible** ve galaxy, kubernetes collectionları yüklü olması.

```bash
ansible-galaxy collection install community.kubernetes
ansible-galaxy collection install community.general

```

- **SSH** erişimi olan ve sudo yetkisine sahip Linux tabanlı hedef sunucular.
````bash
ssh-copy-id -i ~/.ssh/mykey root@192.168.1.152
ssh-copy-id -i ~/.ssh/mykey root@192.168.1.153
ssh-copy-id -i ~/.ssh/mykey root@192.168.1.156
````
- Master ve Worker nodların hostnameleri bir birinden farklı olmalı. Hostnamectl komutu ile değiştirmeniz mümkün.
````bash
hostnamectl set-hostname
````

## Hızlı Başlangıç

1. **Hosts Dosyasını Düzenle**: Projenin kök dizinindeki `hosts` dosyasını kendi ortamınıza göre ayarlayın. Örnek yapılandırma:

```
master1 ansible_host=192.168.1.152
worker1 ansible_host=192.168.1.153
worker2 ansible_host=192.168.1.156
```

2. **Envanter Dosyasını Düzenle**: Projenin kök dizinindeki `cluster_inventory.yml` dosyasını kendi ortamınıza göre ayarlayın. Örnek yapılandırma:

```
all:
  children:
    master:
      hosts:
        master1:
          ansible_host: 192.168.1.152
    worker:
      hosts:
        worker1:
          ansible_host: 192.168.1.153
        worker2:
          ansible_host: 192.168.1.156

```
3. **01_install_rke2.yml**: `Label the Kubernetes nodes with specific roles` bölümünde kaç adet worker node olacaksa loop kısmı ona göre değiştirilmeli.
```bash
  loop:
    - { name: '{{ worker_hostnames[0] }}', role: 'worker-1' }
    - { name: '{{ worker_hostnames[1] }}', role: 'worker-2' }
```

4. **Playbook'u Çalıştır**: Aşağıdaki komut ile Ansible playbook'unu çalıştırın:

```bash
ansible-playbook -i inventory/cluster_inventory.yml site.yml
```

## Yapılandırma

`vars/main.yml` dosyasında bulunan değişkenleri kendi ihtiyaçlarınıza göre düzenleyebilirsiniz. Bu değişkenler, cluster kurulumu sırasında kullanılacak ayarları içerir.

## Yapılacaklar

### RKE Cluster Kurulumu
- [x] Sistem Gereksinimlerinin Kontrol Edilmesi
- [X] RKE2'nin Kurulumu
- [X] Kubectl Komutlarının Normal Kullanıcılar Tarafından Sudo İhtiyacı Olmadan Çalıştırılması
- [X] Worker Node'ların Master Node'a Bağlanması
- [X] Worker Node'ların Rollendirilmesi

### Ön Tanımlı Gelecek Paketler
- [X] install metallb
- [X] install longhorn
- [X] install cert-manager
- [X] install ingress-nginx

````bash
  _____  _        ___     _____ _           _            
 |  __ \| |      |__ \   / ____| |         | |           
 | |__) | | _____   ) | | |    | |_   _ ___| |_ ___ _ __ 
 |  _  /| |/ / _ \ / /  | |    | | | | / __| __/ _ \ '__|
 | | \ \|   <  __// /_  | |____| | |_| \__ \ ||  __/ |   
 |_|  \_\_|\_\___|____|  \_____|_|\__,_|___/\__\___|_|   
                                                         
Rke2 Cluster / Ver: "1.0"  / Developped by: Murat Akpınar

Versions:
  - rke2 v1.27.11+rke2r1
  - metallb
  - longhorn
  - cert-manager
  - ingress-nginx


kubectl get nodes
NAME           STATUS   ROLES                       AGE     VERSION
rke2-master    Ready    control-plane,etcd,master   4m31s   v1.27.11+rke2r1
rke2-worker    Ready    worker-1                    2m40s   v1.27.11+rke2r1
rke2-worker2   Ready    worker-2                    2m30s   v1.27.11+rke2r1
````


# Yapı

```bash
ansible-role-rke2-cluster/
├── ansible.cfg
├── collections
│   └── requirements.yml
├── hosts
├── inventory
│   └── cluster_inventory.yml
├── LICENSE
├── playbooks
│   └── roles
│       └── rke2_setup
│           ├── files
│           │   └── my-charts
│           │       ├── cert-manager
│           │       │   └── values.yaml
│           │       ├── ingress
│           │       │   └── values.yaml
│           │       ├── longhorn
│           │       │   ├── homelab.longhorn.yaml
│           │       │   ├── LoadBalancer.sh
│           │       │   └── values.yaml
│           │       └── metallb
│           │           ├── metallb-config.yaml
│           │           └── metallb.yaml
│           ├── handlers
│           │   └── main.yml
│           ├── meta
│           ├── tasks
│           │   ├── 00_system_requirements.yml
│           │   ├── 00_wellcome.yml
│           │   ├── 01_install_rke2.yml
│           │   ├── 02_file_transfer.yml
│           │   ├── 03_install_helm.yml
│           │   ├── 04_ingress_install.yaml
│           │   ├── 05_metallb_install.yaml
│           │   ├── 06_longhorn_install.yaml
│           │   ├── 07_cert_manager_install.yaml
│           │   └── main.yml
│           ├── templates
│           │   ├── rke2_agent_config.j2
│           │   └── wellcome.j2
│           └── vars
│               └── main.yml
├── README.md
└── site.yml

16 directories, 28 files
```
