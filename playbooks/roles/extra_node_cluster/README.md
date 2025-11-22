# Extra Node Cluster Role

Bu role, mevcut K3s cluster'ınıza yeni master veya worker node'lar eklemenizi sağlar.

## Özellikler

✅ **Idempotent**: Zaten cluster'a eklenmiş node'ları tekrar eklemez
✅ **HA Desteği**: 3+ master node'lu HA cluster'lara master ekleyebilir
✅ **Single Master Desteği**: Tek master node'lu cluster'lara master ekleyerek HA'ya dönüştürebilir
✅ **Worker Node Ekleme**: İstediğiniz kadar worker node ekleyebilirsiniz
✅ **Versiyon Kontrolü**: Mevcut cluster versiyonu ile uyumlu node ekler

## Kullanım

### 1. Inventory'ye Yeni Node Ekleme

`inventory/cluster_inventory.yml` dosyasına yeni node'u ekleyin:

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
          ansible_host: 192.168.1.149
        worker-2:
          ansible_host: 192.168.1.150
        worker-3:  # Yeni worker node
          ansible_host: 192.168.1.151
```

### 2. Versiyon Belirleme (Opsiyonel)

Eğer mevcut cluster'ınızın versiyonunu belirtmek isterseniz:

```yaml
# playbooks/roles/extra_node_cluster/vars/main.yml
k3s_version: "v1.32.9+k3s1"  # Mevcut cluster versiyonu
```

Boş bırakırsanız en son versiyon kurulur (mevcut cluster ile uyumsuzluk olabilir).

### 3. Yeni Node Ekleme

**Tek bir node eklemek için:**
```bash
# Master node için:
ansible-playbook -i inventory/cluster_inventory.yml add_node.yml --limit master-4

# Worker node için:
ansible-playbook -i inventory/cluster_inventory.yml add_node.yml --limit worker-3
```

**Tüm yeni node'ları eklemek için:**
```bash
ansible-playbook -i inventory/cluster_inventory.yml add_node.yml
```

**Sadece worker node'ları eklemek için:**
```bash
ansible-playbook -i inventory/cluster_inventory.yml add_node.yml --limit worker
```

## Örnek Senaryolar

### Senaryo 1: HA Cluster'a Yeni Master Ekleme

Mevcut 3 master node'lu HA cluster'ınıza 4. master node eklemek:

```bash
# 1. Inventory'ye master-4 ekleyin
# 2. Çalıştırın:
ansible-playbook -i inventory/cluster_inventory.yml add_node.yml --limit master-4
```

### Senaryo 2: Single Master'ı HA'ya Dönüştürme

Tek master node'lu cluster'ınıza 2. ve 3. master ekleyerek HA'ya dönüştürmek:

```bash
# 1. Inventory'ye master-2 ve master-3 ekleyin
# 2. Çalıştırın:
ansible-playbook -i inventory/cluster_inventory.yml add_node.yml --limit master
```

### Senaryo 3: Worker Node Ekleme

Cluster'ınıza yeni worker node'lar eklemek:

```bash
# 1. Inventory'ye worker node'ları ekleyin
# 2. Çalıştırın:
ansible-playbook -i inventory/cluster_inventory.yml add_node.yml --limit worker
```

## Önemli Notlar

⚠️ **Versiyon Uyumluluğu**: Yeni node'ların versiyonu mevcut cluster versiyonu ile uyumlu olmalıdır. Farklı versiyonlar sorunlara yol açabilir.

⚠️ **Token Güvenliği**: K3s token'ı otomatik olarak ilk master node'dan alınır.

⚠️ **Idempotency**: Role idempotent'tir. Zaten cluster'a eklenmiş node'ları tekrar eklemez.

⚠️ **HA Gereksinimleri**: HA cluster için en az 3 master node gerekir. 2 master node ile HA oluşturulamaz.

## Doğrulama

Node'un başarıyla eklendiğini kontrol etmek için:

```bash
kubectl get nodes
```

Yeni node'un `Ready` durumunda olduğunu görmelisiniz.

