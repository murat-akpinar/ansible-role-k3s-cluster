#  Ansible Role: K3S Cluster
![release](https://img.shields.io/badge/release-v1.0-blue)
- Şuan sadece ubutnu 22.04 denedim fakat `curl -sfL https://get.k3s.io | sh -` scripti ile kurduğu için sanırım diğer dağıtımlarda sorun olmayacaktır.


<img src="https://k3s.io/img/k3s-logo-light.svg" alt="k3s" style="max-width: 100%;">


# Ansible Role: K3S Cluster Kurulumu

Bu Ansible rolü, otomatik olarak **K3S** tabanlı Kubernetes kümesi kurulumunu gerçekleştirir. Kurulum, bir adet master ve birden fazla worker düğümünden oluşan bir yapıyı destekler.

## Önkoşullar

- Etcd : Bir kümenin çoğunlukla çalışmasını gerektirir. İki master düğümün bulunduğu bir kümede, bir master düğüm kapandığında çoğunluk kaybolur ve bu nedenle küme yönetilemez hale gelir. BU yüzden en az 3 Mastner node olmalı

- **Ansible** ve galaxy, kubernetes collectionları yüklü olması.

```bash
ansible-galaxy collection install community.kubernetes
ansible-galaxy collection install community.general

```

- **SSH** erişimi olan ve sudo yetkisine sahip Linux tabanlı hedef sunucular.
````bash
ssh-copy-id -i ~/.ssh/mykey root@192.168.1.152
ssh-copy-id -i ~/.ssh/mykey root@192.168.1.153
ssh-copy-id -i ~/.ssh/mykey root@192.168.1.154
ssh-copy-id -i ~/.ssh/mykey root@192.168.1.156
````
- **keepalived_network:** vars dizininden keepalived için geçerli network kartınızı ve keeplived için bir ip adresi belirtmeniz gerekli.
```bash
keepalived_vip: 192.168.1.244
keepalived_network: enp0s3
```


2. **Envanter Dosyasını Düzenle**: Projenin kök dizinindeki `cluster_inventory.yml` dosyasını kendi ortamınıza göre ayarlayın. Örnek yapılandırma:

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

4. **Playbook'u Çalıştır**: Aşağıdaki komut ile Ansible playbook'unu çalıştırın:

```bash
ansible-playbook -i inventory/cluster_inventory.yml site.yml
```

## Yapılandırma

`vars/main.yml` dosyasında bulunan değişkenleri kendi ihtiyaçlarınıza göre düzenleyebilirsiniz. Bu değişkenler, cluster kurulumu sırasında kullanılacak ayarları içerir.

## Yapılacaklar

### K3S Cluster Kurulumu
- [x] Sistem Gereksinimlerinin Kontrol Edilmesi
- [X] hostname'in ayarlanması
- [X] keeplived'in Kurulumu
- [X] k3s'nin Kurulumu
- [X] Kubectl Komutlarının Normal Kullanıcılar Tarafından Sudo İhtiyacı Olmadan Çalıştırılması
- [X] Worker Node'ların Master Node'a Bağlanması
- [ ] Worker Node'ların Rollendirilmesi

### Ön Tanımlı Gelecek Paketler
- [ ] install metallb
- [ ] install longhorn
- [ ] install cert-manager
- [ ] install ingress-nginx

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

k3s Cluster / Ver: "1.0"  / Developped by: Murat Akpınar

Versions:
  - k3s
````


````bash
kubectl get nodes
NAME       STATUS   ROLES                       AGE    VERSION
master-1   Ready    control-plane,etcd,master   117s   v1.29.5+k3s1
master-2   Ready    control-plane,etcd,master   85s    v1.29.5+k3s1
master-3   Ready    control-plane,etcd,master   85s    v1.29.5+k3s1
worker-1   Ready    <none>                      44s    v1.29.5+k3s1
````


# Yapı

```bash
ansible-role-k3s-cluster/
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
│           │       │   └── values.yaml
│           │       ├── ingress
│           │       │   └── values.yaml
│           │       ├── longhorn
│           │       │   ├── homelab.longhorn.yaml
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
│           │   ├── 01_configure_hostname.yml
│           │   ├── 02_install_keepalived.yml
│           │   ├── 03_install_k3s.yml
│           │   └── main.yml
│           ├── templates
│           │   ├── keepalived-backup.j2
│           │   ├── keepalived-master.j2
│           │   └── wellcome.j2
│           └── vars
│               └── main.yml
├── README.md
└── site.yml

16 directories, 24 files
```
