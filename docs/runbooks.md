# Runbook'lar

Tüm komutlar repo kökünden; `ansible.cfg` envanteri zaten gösteriyor ama açıkça
`-i inventory/cluster_inventory.yml` vermek alışkanlığı korunmuş.

## 1. Sıfırdan kurulum

1. Collection'lar: `ansible-galaxy collection install -r collections/requirements.yml`
2. Envanter: `inventory/cluster_inventory.yml` — `master`/`worker` hostları, `ansible_host`,
   `all.vars` altında `ansible_user` ve key. **İlk master, `master` grubunda ilk yazılandır.**
3. Ayarlar: `playbooks/roles/k3s_setup/defaults/main.yml` — `keepalived_vip`, `cluster_domain`,
   `metallb_ip_addresses`, `k3s_version` (pinle), `*_install` bayrakları (bkz. variables.md).
   MetalLB açılacaksa `k3s_disable_servicelb: true`.
4. Vault (isteğe bağlı ama önerilir):
   ```sh
   cp inventory/group_vars/all/vault.yml.example inventory/group_vars/all/vault.yml
   $EDITOR inventory/group_vars/all/vault.yml     # vault_keepalived_auth_pass
   ansible-vault encrypt inventory/group_vars/all/vault.yml
   ```
5. Kur:
   ```sh
   ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml --ask-vault-pass
   ```
   Hostname değişecekse node reboot olur (10 dk timeout). Sonda `K3s CLUSTER KURULUM OZETI`
   tablosu Gateway IP'sini, URL'leri ve parolaları basar.
6. Doğrula: `ansible-playbook -i inventory/cluster_inventory.yml verify.yml` → `RESULT: ALL CHECKS PASSED`.
7. Hostname erişimi için istemci `/etc/hosts`'una Gateway IP'sini ekle:
   `192.168.1.x grafana.homelab.local argocd.homelab.local longhorn.homelab.local rancher.homelab.local`

## 2. Mevcut cluster'a bileşen açma / tek bileşeni yeniden çalıştırma

Bayrağı `true` yap, ilgili tag ile çalıştır (bağımlılık sırasına dikkat):

```sh
ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml --tags helm,gateway-api,cert-manager
ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml --tags longhorn
ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml --tags monitoring
```

Tag'ler: `helm`, `gateway-api`, `metallb`, `cert-manager`, `longhorn`, `grafana`/`monitoring`,
`rancher`, `argocd`. `_facts` `always` olduğu için kısmi çalıştırma güvenli; ama
`03_wait_api_ready` tag'siz, API kapalıysa ilk helm komutu retry'a düşer.
Tüm helm adımları `helm upgrade --install` — tekrar çalıştırmak values/sürüm değişikliğini uygular.

## 3. Node ekleme

1. Envantere hostu ekle (master veya worker grubuna).
2. `k3s_version` boş kalabilir: `_resolve_k3s_version.yml` master[0]'daki çalışan sürümü
   okuyup yeni node'a onu pinler. Elle pinleyeceksen cluster'ın sürümünü ver, daha
   yenisini değil (kubelet apiserver'dan yeni olamaz).
3. `ansible-playbook -i inventory/cluster_inventory.yml add_node.yml`
4. Zaten katılmış node'lar (`systemctl is-active k3s|k3s-agent` aktif) join adımlarında
   atlanır; playbook tüm envantere karşı çalıştırılmalıdır (`hosts: all`): eski node'ların
   firewalld `trusted` zone'una yeni node'un IP'si bu sayede eklenir, yoksa node-arası
   trafik (VXLAN/kubelet/etcd) yeni node'a kesik kalır.
5. Eklenen node ilk kurulumla aynı ön hazırlığı alır (swap, kernel modülleri, sysctl,
   chrony, paketler, firewalld, hostname) — hepsi k3s_setup'tan `include_role` ile.

Tek master → HA dönüşümü: ilk master `--cluster-init` ile kurulmuş olmalı (rol bunu
yapar; elle kurulduysa `02_add_master_node.yml` etcd dizini yoksa fail eder). 2. master
ilk master IP'si üzerinden katılır; 3. master eklendiğinde `master_count` 3 olur,
keepalived **tüm** master'larda yapılandırılır ve VIP kalkar. Sonraki node'lar VIP'e katılır.

> ⚠️ 2 → 3 master geçişi şu an tam çalışmıyor: `add_node.yml` join adımını
> keepalived'den **önce** koşuyor, `master_count` zaten 3 olduğu için 3. master
> henüz var olmayan VIP'e bağlanmaya çalışır (`connection refused` — bkz.
> [troubleshooting](troubleshooting.md)). Geçici çözüm: 3. master'ı eklerken
> `-e k3s_api_endpoint=<ilk master IP>` verin.

## 4. Upgrade

1. `k3s_upgrade_version: "v1.3X.Y+k3s1"` (defaults/main.yml). Bir seferde bir minor.
2. `ansible-playbook -i inventory/cluster_inventory.yml upgrade.yml`
   - Play 1: `k3s etcd-snapshot save --name pre-upgrade` (master[0], otomatik) ve son 5
     pre-upgrade snapshot'ı bırakan `prune`. Snapshot alınamazsa upgrade orada durur —
     yedeksiz upgrade istemiyoruz. Listelemek için `sudo k3s etcd-snapshot ls`.
   - Play 2 (master'lar) → Play 3 (worker'lar), her biri `serial: 1`: sürüm karşılaştırması
     → drain → install script ile yeniden kurulum (flag'ler `/etc/rancher/k3s/config.yaml`'dan,
     upgrade öncesi `03_k3s_config` ile tazelenir) → uncordon → `upgrade_wait_for_pods` sn.
     Master'lar her zaman önce: kubelet apiserver'dan yeni olamaz.
   - Sürümü hedefe eşit/yüksek node'lar `SKIP`. `upgrade_force: true` ile zorlanır.
   - Sonda play 4: takılı cordon temizliği, (rebalance — todo A1), node/pod özeti.
3. `verify.yml` çalıştır; `kubectl get nodes` ile tüm `VERSION` sütunu aynı olmalı.
4. Geri alma: `k3s etcd-snapshot restore` (bkz. `.tmp/k3s/datastore-backup-restore.md`);
   binary'yi eski sürümle yeniden kur (`INSTALL_K3S_VERSION=eski`).

## 5. Domain / VIP / IP havuzu değişikliği

| Değişen | Düzenle | Sonra çalıştır |
|---|---|---|
| `cluster_domain` | defaults/main.yml | `--tags helm,cert-manager,longhorn,monitoring,rancher,argocd` (manifestler yeniden render + apply; wildcard cert yeni dnsNames ile yeniden kesilir; istemci /etc/hosts güncelle) |
| `metallb_ip_addresses` | defaults/main.yml | `--tags metallb` (IPAddressPool apply); mevcut LB IP'leri değişmez, servisi yeniden oluştur |
| `keepalived_vip` | defaults/main.yml | Kurulu cluster'da **değiştirme**: `--tls-san` ve tüm `K3S_URL`'ler buna bağlı; yeniden kurulum gerekir |
| `keepalived_auth_pass` | vault.yml | `k3s_setup.yml` tam çalıştır (keepalived adımının tag'i yok); ya da `ansible master -m template -a "src=... dest=/etc/keepalived/keepalived.conf"` + restart |
| `k3s_disable_servicelb` / `k3s_master_taint` | defaults/main.yml | Yalnızca yeni kurulan/upgrade edilen node'da etki eder (install script unit'i yeniden yazar); mevcut cluster için `upgrade.yml` `upgrade_force: true` |

## 6. Chart sürümü yükseltme

1. `helm search repo <repo>/<chart> --versions | head` (helm yerelde yoksa upstream
   `Chart.yaml`/release sayfası) → `*_chart_version`'ı güncelle.
2. Major atlamada chart README'sindeki upgrade notlarına bak (kube-prometheus-stack CRD
   adımları, ArgoCD, Longhorn "bir minor at" kuralı); `.tmp/<bileşen>/` altındaki README.
3. `--tags <bileşen>` ile çalıştır.
4. `docs/fetch-reference-sources.sh` içindeki tag'i ve `docs/reference-sources.md` tablosunu güncelle, `sh docs/fetch-reference-sources.sh`.

## 7. Node'u sıfırlama / cluster'ı kaldırma

```sh
# worker
sudo /usr/local/bin/k3s-agent-uninstall.sh
# master
sudo /usr/local/bin/k3s-uninstall.sh
sudo systemctl disable --now keepalived; sudo rm -f /etc/keepalived/keepalived.conf
# Longhorn kullandıysa
sudo rm -rf /var/lib/longhorn
```
Node cluster'dan da silinmeli: `kubectl delete node <ad>`. Sonra `add_node.yml` ile geri alınabilir.

## 8. Parolalar

| Bileşen | Nereden |
|---|---|
| Grafana | `kubectl -n monitoring get secret kube-prometheus-stack-grafana -o jsonpath='{.data.admin-password}' \| base64 -d` (values'ta `admin`) |
| ArgoCD | `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' \| base64 -d` |
| Rancher | `kubectl -n cattle-system get secret bootstrap-secret -o jsonpath='{.data.bootstrapPassword}' \| base64 -d` |
| Keepalived VRRP | `ansible-vault view inventory/group_vars/all/vault.yml` |
| k3s join token | `sudo cat /var/lib/rancher/k3s/server/node-token` (master) |
