# Sorun Giderme

Kaynak: CHANGELOG'daki düzeltmeler, todo.md bulguları ve rolün bekleme/hata mesajları.

## Belirti → neden → düzeltme

| Belirti | Olası neden | Bak / yap |
|---|---|---|
| Playbook sadece `localhost`'a koşuyor, `No inventory was parsed` | `-i` verilmedi ve ansible.cfg'deki yol bozuk | `ansible-inventory --graph` envanterdeki hostları göstermeli; `ansible.cfg: inventory=inventory/cluster_inventory.yml` |
| `couldn't resolve module/action 'ansible.posix.firewalld'` / `community.general.modprobe` | collection kurulu değil | `ansible-galaxy collection install -r collections/requirements.yml` |
| İlk SSH bağlantısı yanlış kullanıcı/anahtar ile | bağlantı değişkenleri rol vars'ında | Envanter `all.vars`'ta olmalı; `--private-key`/`-u` ile ez |
| Kurulum "başarılı" ama Gateway/MetalLB/… hiç kurulmadı | bayrak `false` (varsayılan saf k3s) veya ilk master `groups['master'][0]` değil | `defaults/main.yml` `*_install`; envanterde master sırası |
| `Kubernetes API sunucusu beklenen surede hazir olmadi` | k3s başlamadı / etcd quorum yok / VIP yanlış node'da | `journalctl -u k3s -f`, `k3s check-config`, `ip a | grep <vip>` |
| Ek master join'de `connection refused` / `x509` | `K3S_URL` VIP'e gidiyor ama VIP yok (keepalived <3'te yapılandırılmaz) veya `--tls-san` eksik | `master_count`; `openssl s_client -connect VIP:6443 \| openssl x509 -noout -text \| grep -A1 "Subject Alternative"` |
| Worker `NotReady`, pod'lar arası trafik yok, MetalLB webhook `context deadline exceeded` | RHEL/Rocky firewalld flannel VXLAN 8472/udp'yi kesiyor. Port artık kaynak kısıtlı: node IP'si `trusted` zone'da değilse (envanterdeki `ansible_host` ≠ flannel'ın kullandığı IP, çok NIC'li host) kesilir | `firewall-cmd --zone=trusted --list-sources` tüm node IP'lerini göstermeli; eksikse `ansible_host`'u düzelt ve playbook'u tekrar koş, ya da elle `firewall-cmd --permanent --zone=trusted --add-source=<node IP>` |
| HA'da 2./3. master etcd'ye katılamıyor, keepalived'ler hepsi MASTER | etcd (2379-2380/tcp) ve VRRP node IP'lerinin `trusted` zone'da olmasıyla açılır; master IP'si listede değilse ikisi de kesilir | `firewall-cmd --zone=trusted --list-sources`; eksikse `firewall-cmd --permanent --zone=trusted --add-source=<master IP> && firewall-cmd --reload` |
| `Cannot add additional master nodes! ... --cluster-init` | ilk master elle/SQLite ile kurulmuş | `/var/lib/rancher/k3s/server/db/etcd` yok → yeniden kurulum |
| Yeni node `kubelet version newer than apiserver` / NotReady | `k3s_version` elle cluster'dan yeni bir sürüme pinlenmiş (boşken rol zaten cluster sürümüne pinler) | `k3s_version`'ı `ssh master-1 k3s --version` çıktısına eşitle ya da boşalt, node'u `k3s-*-uninstall.sh` ile sil, tekrar ekle |
| `TARGET VERSION NOT SPECIFIED` | `k3s_upgrade_version` ve `k3s_version` boş | birini doldur |
| Upgrade'de worker drain 10 dk takılıyor, sonra devam ediyor | PDB `minAvailable` karşılanamıyor (master'lar drain edilmez, yalnızca cordon) | `kubectl get pdb -A`; `upgrade_drain_timeout`; replika sayısını artır |
| Upgrade'de `Wait for monitoring …` task'ı `...ignoring` bastı | Süre doldu (180 sn); upgrade uyarıyla devam eder | Sıradaki worker'dan önce `kubectl get pods -n monitoring` |
| `GatewayClass traefik` gelmiyor (20 deneme) | HelmChartConfig helm-controller tarafından işlenmedi / traefik pod restart | `kubectl -n kube-system get helmchartconfig traefik -o yaml`, `kubectl -n kube-system logs job/helm-install-traefik`, `kubectl -n kube-system get gatewayclass` |
| `gateway/homelab` Programmed değil | listener port 8443 ≠ Traefik entryPoint; secret yok; GatewayClass yok | `kubectl -n kube-system describe gateway homelab` conditions; `kubectl -n kube-system get secret homelab-wildcard-tls` |
| HTTPRoute Accepted değil (`verify.yml` FAIL) | `sectionName: websecure` yanlış, hostname `*.cluster_domain` ile eşleşmiyor, namespace izinli değil | `kubectl describe httproute -n <ns> <ad>` `.status.parents[].conditions` |
| Başka namespace'ten kube-system'deki bir pod'a erişim zaman aşımı (DNS, metrics-server, Traefik, svclb hariç); kube-system'e kurulan bir webhook/exporter `context deadline exceeded` | `k3s_hardening` NetworkPolicy'si: kube-system'e dışarıdan yalnızca izin verilen pod'lara trafik girer | `kubectl -n kube-system get netpol`; o pod için ayrı bir policy ekle (policy'ler toplanır) ya da bileşeni kendi namespace'ine kur. Düşen paketleri görmek: `.tmp/k3s/advanced.md` "Additional Network Policy Logging" |
| `certificate/homelab-wildcard` Ready değil | ClusterIssuer yok, cert-manager webhook hazır değil | `kubectl describe clusterissuer selfsigned-issuer`; `kubectl -n cert-manager get pods`; `kubectl -n kube-system describe certificate homelab-wildcard` |
| Tarayıcı `NET::ERR_CERT_AUTHORITY_INVALID` | self-signed (beklenen) | CA zinciri (todo C2) ya da istisna ekle |
| `*.homelab.local` bazen çözülmüyor | `.local` mDNS (systemd-resolved/avahi) | `resolvectl query`, domain'i `home.arpa` yap (todo C3) |
| Monitoring PVC Pending | `monitoring_storage_class` yok (varsayılan `local-path`), HA `podAntiAffinity: required` için worker yetersiz | `kubectl get sc`; `kubectl -n monitoring describe pvc` |
| Alertmanager sürekli `KubeControllerManagerDown/KubeSchedulerDown/KubeProxyDown/etcd*` | k3s bu bileşenleri ayrı pod olarak sunmaz (todo C1) | values'ta ilgili `*.enabled: false` |
| Rancher pod CrashLoop | Kubernetes sürümü Rancher'ın desteklediği pencerede değil / minor atlandı | `kubectl -n cattle-system logs deploy/rancher`; `rancher_version` ile `.tmp/rancher/installation-requirements.md` |
| ArgoCD `argocd-initial-admin-secret` yok | secret silinmiş (normal) | `argocd admin initial-password` ya da parola sıfırla |
| Her playbook koşusunda her şey `changed` | command/shell task'ları changed_when'siz (todo D2) | beklenen; gerçek değişiklik için `--diff` anlamsız |
| verify.yml `[FAIL] Keepalived VIP` tek master'da | eski davranış; artık `[SKIP]` | güncel `verify.yml` |
| `become_user` ile `Failed to set permissions ... setfacl` | hedefte `acl` paketi yok | `00_prerequisites.yml` kurar; elle `apt install acl` |

## Teşhis komutları (master[0])

```sh
kubectl get nodes -o wide
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded
kubectl get gatewayclass,gateway -A
kubectl get httproute -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{" "}{.status.parents[*].conditions[?(@.type=="Accepted")].status}{"\n"}{end}'
kubectl -n kube-system get certificate,secret homelab-wildcard-tls
helm list -A
sudo k3s check-config
sudo journalctl -u k3s --since -10m        # worker: k3s-agent
sudo k3s etcd-snapshot ls
sudo cat /etc/systemd/system/k3s.service | grep ExecStart -A8   # gerçek flag'ler
ip -br a | grep <keepalived_vip>; sudo journalctl -u keepalived --since -10m
sudo firewall-cmd --list-all               # RHEL
```

Ansible tarafı:

```sh
ansible-inventory -i inventory/cluster_inventory.yml --graph
ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml --syntax-check
ansible-playbook ... --list-tasks --tags cert-manager
ansible-playbook ... -vvv --start-at-task "Install Cert-Manager Helm chart"
ansible all -i inventory/cluster_inventory.yml -m ping
```
