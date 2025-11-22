# K3s Cluster Upgrade Role

Bu role, K3s cluster'ınızı **rolling update** stratejisi ile güvenli bir şekilde günceller.

## Özellikler

✅ **Rolling Update**: Node'lar sırayla güncellenir, cluster kesintisiz çalışmaya devam eder
✅ **Versiyon Kontrolü**: Mevcut versiyonları kontrol eder, gereksiz upgrade'leri önler
✅ **Drain/Uncordon**: Pod'lar güvenli şekilde diğer node'lara taşınır
✅ **HA Desteği**: 3+ master node'lu HA kurulumlarını destekler
✅ **Single Master Desteği**: Tek master node'lu kurulumları destekler
✅ **Otomatik Doğrulama**: Upgrade sonrası cluster durumunu kontrol eder

## Kullanım

### 1. Versiyon Belirleme

`playbooks/roles/update_cluster/vars/main.yml` dosyasında güncellenecek versiyonu belirtin:

```yaml
k3s_target_version: "v1.31.6+k3s1"  # Güncellenecek K3s versiyonu
```

### 2. Upgrade Çalıştırma

```bash
ansible-playbook -i inventory/cluster_inventory.yml upgrade.yml
```

### 3. Upgrade Süreci

1. **Versiyon Kontrolü**: Tüm node'ların mevcut versiyonları kontrol edilir
2. **Master Node'ları Güncelleme**: 
   - Master node'lar sırayla (serial: 1) güncellenir
   - Her master node:
     - Drain edilir (pod'lar diğer node'lara taşınır)
     - K3s upgrade edilir
     - Uncordon edilir (yeni pod'lar alabilir)
     - Pod'ların stabilize olması beklenir
3. **Worker Node'ları Güncelleme**:
   - Worker node'lar sırayla (serial: 1) güncellenir
   - Her worker node aynı süreçten geçer
4. **Cluster Doğrulama**: Tüm node'ların Ready durumda olduğu kontrol edilir

## Yapılandırma

`playbooks/roles/update_cluster/vars/main.yml` dosyasında ayarlanabilir parametreler:

```yaml
k3s_target_version: "v1.31.6+k3s1"  # Güncellenecek versiyon
upgrade_drain_timeout: 300          # Drain timeout (saniye)
upgrade_wait_for_pods: 60           # Pod stabilize bekleme süresi (saniye)
upgrade_force: false                 # Versiyon eşleşse bile zorla upgrade
```

## Önemli Notlar

⚠️ **Backup**: Upgrade öncesi önemli verilerinizi yedekleyin
⚠️ **Test**: Production'a uygulamadan önce test ortamında deneyin
⚠️ **Versiyon Uyumluluğu**: K3s versiyonları arasında uyumluluk kontrolü yapın
⚠️ **Etcd**: HA kurulumlarda etcd uyumluluğu önemlidir, master node'ları önce güncelleyin

## Troubleshooting

### Upgrade sırasında hata alırsanız:

1. Node durumunu kontrol edin:
   ```bash
   kubectl get nodes
   ```

2. Pod durumunu kontrol edin:
   ```bash
   kubectl get pods --all-namespaces
   ```

3. K3s servis durumunu kontrol edin:
   ```bash
   systemctl status k3s  # Master node'larda
   systemctl status k3s-agent  # Worker node'larda
   ```

4. Node'u manuel olarak uncordon edin:
   ```bash
   kubectl uncordon <node-name>
   ```

## Örnek Çıktı

```
PLAY [master] **************************************************************

TASK [update_cluster : Check Current K3s Versions] **********************
ok: [master-1] => {
    "msg": "Node master-1: Current version = v1.29.5+k3s1, Target version = v1.31.6+k3s1"
}

TASK [update_cluster : Drain first master node] **************************
changed: [master-1]

TASK [update_cluster : Upgrade K3s on first master (HA mode)] ***********
changed: [master-1]

TASK [update_cluster : Wait for K3s to be ready on first master] ********
ok: [master-1]

TASK [update_cluster : Uncordon first master node] ***********************
changed: [master-1]

...
```

