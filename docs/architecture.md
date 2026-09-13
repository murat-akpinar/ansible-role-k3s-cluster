# Mimari ve Çalışma Akışı

## Topoloji

- **master** grubu: k3s server (gömülü etcd + control plane). `groups['master'][0]`
  her zaman "ilk master"dır: `--cluster-init` ile kurulur, token buradan okunur,
  tüm `kubectl`/`helm` komutları burada çalışır.
- **worker** grubu: k3s agent.
- **HA eşiği: `master_count >= 3`.** Bu eşik her yerde aynı karar noktasıdır:

| Karar | `< 3` master | `>= 3` master |
|---|---|---|
| Keepalived | paket kurulur, **yapılandırılmaz** | keepalived.conf yazılır, VIP aktif |
| Ek master / worker `K3S_URL` | `https://<ilk master IP>:6443` | `https://{{ keepalived_vip }}:6443` |
| ↳ nerede karar veriliyor | `_facts.yml` → `k3s_api_endpoint` (tek yer) | aynı |
| Helm values dosyası | `values-single-master.yml` | `values-ha.yml` |
| kube-prometheus-stack | temel + `-single-master` + `-master-only` | temel + `-master-only` |
| verify.yml VIP ping | `[SKIP]` | kontrol edilir |

- Tek master bile `--cluster-init` ile kurulur (SQLite değil etcd) ki sonradan
  `add_node.yml` ile HA'ya dönüştürülebilsin.
- `--tls-san {{ keepalived_vip }}` her zaman eklenir; VIP henüz yokken de sertifikada
  bulunur, HA'ya geçişte sertifika yenilenmez.

## Repo düzeni

```
k3s_setup.yml / add_node.yml / upgrade.yml / verify.yml   giriş playbook'ları
ansible.cfg                inventory yolu, roles_path=playbooks/roles, become, profile_tasks
inventory/cluster_inventory.yml      all.vars = ansible_user, ansible_ssh_private_key_file
inventory/group_vars/all/main.yml    kullanıcı override'ları (örnek; tamamı yorumlu)
inventory/group_vars/all/vault.yml   (şifreli, git'te yok) vault_keepalived_auth_pass
collections/requirements.yml         community.general, ansible.posix
playbooks/roles/
  k3s_setup/           kurulum; defaults/main.yml = TÜM ayarlar (bkz. variables.md)
  extra_node_cluster/  node ekleme; ön hazırlığın tamamını k3s_setup'tan include_role ile alır
  update_cluster/      rolling upgrade; k3s_setup ayarlarını `public: true` include ile alır
```

## `k3s_setup.yml` akışı (`hosts: all`, rol: k3s_setup)

`tasks/main.yml` yalnızca `import_tasks` listesidir; sıra ve kapsam:

| # | Dosya | Hostlar | Ne yapar |
|---|---|---|---|
| 0 | `_facts.yml` (`tags: always`) | all | `getent passwd` → `user_home_directory`; ayrıca `master_count`, `first_master_ip` ve `k3s_api_endpoint` (3+ master ise VIP, altında ilk master IP'si). `--tags` ile kısmi çalıştırmada da gelir. |
| 0b | `_resolve_k3s_version.yml` | all (`run_once` master[0]) | `k3s_version` boşsa cluster'da çalışan sürümü okur ve tüm node'lara pinler (sürüm kayması). Boş cluster'da no-op. Sonunda `k3s_version_env`'i (kurulum satırlarının `INSTALL_K3S_VERSION` öneki) üretir. |
| 1 | `00_system_requirements.yml` | all | CPU/RAM uyarısı (fail etmez), swap kapatma, overlay/br_netfilter, sysctl, chrony + `chrony.j2`. |
| 2 | `00_prerequisites.yml` | all | acl, firewalld aktifse: `6443/tcp` herkese açık; node IP'leri + pod/service CIDR'ları `trusted` zone (node-arası 8472/udp, 10250/tcp, 2379-2380/tcp, VRRP yalnızca node'lardan); eski herkese-açık 8472/10250 kuralı kapatılır. firewalld yoksa `[WARN]`. |
| 3 | `01_configure_hostname.yml` | all | hostname ≠ inventory_hostname ise hostnamectl + /etc/hosts + **reboot**. |
| 4 | `02_install_keepalived.yml` | master | paket her master'a; `master_count >= 3` ise `keepalived.conf.j2` (state/priority envanter sırasından, `chk_k3s` track_script). |
| 5 | `03_k3s_config.yml` | all | **k3s'ten önce**: `k3s-config.yaml.j2` → `/etc/rancher/k3s/config.yaml` (0600), sıkılaştırma sysctl'leri, `audit.yaml` + `psa.yaml` + `k3s-network-policy.yaml` → `server/manifests/` (master). Çalışan k3s varsa restart hatırlatması. |
| 6 | `03_install_k3s.yml` | all | Tek akış: ilk master `--cluster-init`, token oku, ek master'lar `server --server https://{{ k3s_api_endpoint }}:6443`, worker'lar `agent` (**agent-token** ile). HA/single farkı yalnızca `k3s_api_endpoint`. |
| 7 | `03_wait_api_ready.yml` | master[0] | `kubectl get --raw=/readyz` 30×10 sn; olmazsa fail. |
| 8 | `03_k3s_post_install.yml` | master | `~/.kube/config` kopyası (0600) + `.bashrc` KUBECONFIG; PKI `*.crt` 0600 (CIS 1.1.20); default SA token automount kapalı (CIS 5.1.5). |
| 7 | `00_wellcome.yml` | all | `/etc/motd` (`wellcome.j2`), update-motd.d scriptlerinin exec biti düşürülür. |
| 8 | `04_install_helm.yml` `[helm]` | master | helm binary (get-helm-3), `files/my-charts/` → `~/my-charts/`, domain içeren 5 manifest `templates/my-charts/*.j2`'den render. |
| 9 | `05_gateway_api_install.yml` `[gateway-api]` | master[0] / master | Gateway API CRD'leri `--server-side` apply + pin, `traefik-gateway-config.yml` → `/var/lib/rancher/k3s/server/manifests/` (HelmChartConfig), GatewayClass Accepted bekle. |
| 10 | `06_metallb_install.yml` `[metallb]` | master[0] | helm upgrade --install `--wait`, `metallb-config.yml.j2` (IPAddressPool + L2Advertisement) apply. |
| 11 | `07_cert_manager_install.yml` `[cert-manager]` | master[0] | helm (`crds.enabled=true`), selfsigned ClusterIssuer, **wildcard Certificate + paylaşılan Gateway** (kube-system/homelab). |
| 12 | `09_grafana_install.yml` `[grafana, monitoring]` | master[0] | `kube-prometheus-stack-values.yml.j2` render (storageClass), helm `--wait`, Prometheus CR Available bekle, HTTPRoute, parola göster. |
| 13 | `10_rancher_install.yml` `[rancher]` | master[0] | `rancher-deployment.yml.j2` (chart değil, düz Deployment) apply, `rollout status`, bootstrap parolası. |
| 14 | `11_argocd_install.yml` `[argocd]` | master[0] | helm `--wait`, HTTPRoute, admin parolası. |
| 15 | `99_result.yml` | master[0] | Özet tablo: Gateway IP, URL'ler, parolalar. |

8–14 arası her adım `when: <x>_install` ile kapılıdır; varsayılanda hepsi `false`
(saf k3s). Bağımlılık: `helm_install → gateway_api_install → cert_manager_install →
diğerleri`. HTTPRoute'lar (09–11) ayrıca `cert_manager_install` ister çünkü Gateway
orada oluşur.

## `add_node.yml` akışı (rol: extra_node_cluster)

1. `_facts`, `00_system_requirements`, `00_prerequisites`, `01_configure_hostname` —
   dördü de k3s_setup'tan `include_role`; rol artık kopya tutmuyor. Eklenen node ilk kurulumla
   aynı hazırlığı alır (swap, kernel modülleri, sysctl, chrony, paketler, firewalld, hostname).
2. `add_node.yml` `hosts: all` olduğu için bu adımlar **eski node'larda da** koşar:
   `00_prerequisites`'in `trusted` zone kuralı yeni node'un IP'sini eskilere ekler.
3. `01_check_existing_node.yml`: `systemctl is-active k3s|k3s-agent` → `node_already_joined`.
5. master ise `02_add_master_node.yml`: token, `master_count` (`_facts`'ten), ilk master
   `--cluster-init` ile mi kurulmuş kontrolü (etcd dizini), join (VIP veya IP), `kubectl get nodes` ile doğrula.
6. master ise `02_install_keepalived` (k3s_setup'tan include_role) — eklemeden sonra 3'e ulaşıldıysa VIP kurulur.
7. worker ise `03_add_worker_node.yml`: token, join, Ready bekle.

## `upgrade.yml` akışı (rol: update_cluster)

- **Play 1** `hosts: master` (serial yok, `run_once` + `delegate_to master[0]`):
  `k3s etcd-snapshot save --name pre-upgrade` ve `prune --snapshot-retention 5`
  (on-demand snapshot'ların retention'ı yok, her upgrade bir dosya bırakır).
- **Play 2** `hosts: master, serial: 1` → **Play 3** `hosts: worker, serial: 1`: aynı rol
  (`update_cluster`), `01_check_versions.yml` (hedef = `k3s_upgrade_version` yoksa
  `k3s_version`; `is version(..., '<', semver)`) → `02_upgrade_masters.yml` /
  `03_upgrade_workers.yml`. Master: cordon → install script ile yeniden kur → bekle →
  uncordon (`always:`, upgrade fail etse de). Worker: drain → yeniden kur → uncordon →
  bekle (worker'da `kubectl wait` ile monitoring beklemesi; uyarı niteliğinde). **Master'lar worker'lardan önce**: kubelet apiserver'dan yeni olamaz (skew).
  İki ayrı play olmasının sebebi bu; `hosts: all` iken sıra envanterdeki grup dizilişine
  kalıyordu.
- **Play 4** `hosts: master` (serial yok): `05_cleanup_stuck_nodes` → `04_verify_cluster`.

## `verify.yml` akışı

Play 1 (all): servis aktif mi, VRRP arabirimi UP mı. Play 2 (master[0], root +
`/etc/rancher/k3s/k3s.yaml`): node/pod sayıları, VIP ping (>=3), bileşen namespace'lerinde
Running olmayan pod, Gateway Programmed, HTTPRoute Accepted; `[OK]/[FAIL]/[SKIP]` listesi ve
`RESULT` satırı.

## Komutlar nerede, hangi kullanıcıyla çalışır

- `kubectl`/`helm`: **master[0]**'da, `become_user: {{ ansible_user }}`,
  `KUBECONFIG={{ user_home_directory }}/.kube/config` (symlink → `/etc/rancher/k3s/k3s.yaml`,
  mod 600, kendi kopyası). Bu yüzden `_facts` her rolde ilk adımdır ve hedefte `acl` paketi gerekir.
- verify.yml ve `extra_node_cluster/02_add_master_node.yml` doğrulaması root ile
  `/etc/rancher/k3s/k3s.yaml` kullanır.
- Manifest ve values dosyaları hedefte `~/my-charts/<bileşen>/` altında durur:
  `files/my-charts/` kopyalanır, `templates/my-charts/*.j2` ve diğer `.j2`'ler oraya render edilir.
- Install script her node'da `curl -sfL https://get.k3s.io | sh -` ile çalışır; k3s install
  script'i systemd unit'ini **her çalıştırmada** `INSTALL_K3S_EXEC`'e göre yeniden yazar.
  Bu yüzden server/agent flag'leri unit'te değil k3s'in kendi ayar dosyasında tutulur:
  `templates/k3s-config.yaml.j2` → `/etc/rancher/k3s/config.yaml` (`tasks/03_k3s_config.yml`,
  k3s kurulumundan hemen önce; `extra_node_cluster` ve `update_cluster` aynı task'ı
  `include_role ... tasks_from: 03_k3s_config` ile çağırır). Install script bu dosyaya
  dokunmadığı için flag'ler upgrade'de kaybolmaz.

## Değişken akışı

1. `inventory/cluster_inventory.yml` `all.vars`: yalnızca bağlantı (`ansible_user`, key).
   gather_facts'ten önce, ilk SSH'ta geçerli olması için envanterde.
2. `playbooks/roles/k3s_setup/defaults/main.yml`: diğer her şey. **Rol defaults'u
   öncelik sırasında en alttadır**: envanter, `group_vars`, `host_vars` ve `-e`
   hepsi ezebilir. `update_cluster/defaults/main.yml` upgrade zaman aşımlarını tutar.
3. `playbooks/roles/k3s_setup/vars/main.yml`: yalnızca `k3s_server_args: ""`.
   Rol vars'ı group_vars'ın üstünde olduğu için buradaki değer **bilerek**
   ezilemez (CLI flag'i verilirse config.yaml'daki listeyi tümüyle eziyor).
4. `inventory/group_vars/all/main.yml`: kullanıcının override dosyası (örnek,
   tamamı yorumlu). Aynı dizindeki `vault.yml` (`ansible-vault`):
   `vault_keepalived_auth_pass`, `vault_k3s_agent_token`; defaults/main.yml
   `"{{ vault_* | default(...) }}"` ile alır.
5. Rol dışındaki playbook'lar ayarları nasıl görür: `verify.yml` boş bir görev
   listesi olan `k3s_setup/tasks/_load_config.yml`'i `import_role` ile çağırır;
   `extra_node_cluster` / `update_cluster` ise ilk görevleri olan
   `include_role: _facts`'e `public: true` ekler. İkisi de değişkenleri
   rol-defaults önceliğiyle getirir — eski `vars_files` hack'i group_vars'ı
   eziyordu (todo B1).
6. Çalışma zamanı fact'leri: `user_home_directory`, `master_count`, `first_master_ip`,
   `k3s_api_endpoint` (dördü de `_facts.yml`), `k3s_token`, `k3s_version_env`,
   `keepalived_network`, `node_already_joined`, `upgrade_needed`, `k3s_target_version`.
