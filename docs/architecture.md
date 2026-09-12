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
inventory/group_vars/all/vault.yml   (şifreli, git'te yok) vault_keepalived_auth_pass
collections/requirements.yml         community.general, ansible.posix
playbooks/roles/
  k3s_setup/           kurulum; vars/main.yml = TÜM ayarlar (bkz. variables.md)
  extra_node_cluster/  node ekleme; k3s_setup'ın _resolve_user ve keepalived'ini include_role ile kullanır
  update_cluster/      rolling upgrade; k3s_setup/vars/main.yml'i vars_files ile alır
```

## `k3s_setup.yml` akışı (`hosts: all`, rol: k3s_setup)

`tasks/main.yml` yalnızca `import_tasks` listesidir; sıra ve kapsam:

| # | Dosya | Hostlar | Ne yapar |
|---|---|---|---|
| 0 | `_resolve_user.yml` (`tags: always`) | all | `getent passwd` → `user_home_directory` fact'i. `--tags` ile kısmi çalıştırmada da gelir. |
| 1 | `00_system_requirements.yml` | all | CPU/RAM uyarısı (fail etmez), swap kapatma, overlay/br_netfilter, sysctl, chrony + `chrony.j2`. |
| 2 | `00_prerequisites.yml` | all | acl + open-iscsi + nfs-common (RHEL karşılıkları), iscsid, firewalld aktifse 6443/tcp 8472/udp 10250/tcp ve pod/service CIDR'ları trusted. |
| 3 | `01_configure_hostname.yml` | all | hostname ≠ inventory_hostname ise hostnamectl + /etc/hosts + **reboot**. |
| 4 | `02_install_keepalived.yml` | master | paket her master'a; `master_count >= 3` ise `keepalived.conf.j2` (state/priority envanter sırasından, `chk_k3s` track_script). |
| 5 | `03_install_k3s.yml` | all | HA bloğu (`>=3`) veya single bloğu (`<3`): ilk master `--cluster-init`, token oku, ek master'lar `server --server`, worker'lar `agent`. Sonra `~/.kube/config` → `/etc/rancher/k3s/k3s.yaml` symlink + `.bashrc` KUBECONFIG. |
| 6 | `03_wait_api_ready.yml` | master[0] | `kubectl get --raw=/readyz` 30×10 sn; olmazsa fail. |
| 7 | `00_wellcome.yml` | all | `/etc/motd` (`wellcome.j2`), update-motd.d scriptlerinin exec biti düşürülür. |
| 8 | `04_install_helm.yml` `[helm]` | master | helm binary (get-helm-3), `files/my-charts/` → `~/my-charts/`, domain içeren 6 manifest `templates/my-charts/*.j2`'den render. |
| 9 | `05_gateway_api_install.yml` `[gateway-api]` | master[0] / master | Gateway API CRD'leri `--server-side` apply + pin, `traefik-gateway-config.yml` → `/var/lib/rancher/k3s/server/manifests/` (HelmChartConfig), GatewayClass Accepted bekle. |
| 10 | `06_metallb_install.yml` `[metallb]` | master[0] | helm upgrade --install, controller Available bekle, `metallb-config.yml.j2` (IPAddressPool + L2Advertisement) apply. |
| 11 | `07_cert_manager_install.yml` `[cert-manager]` | master[0] | helm (`crds.enabled=true`), selfsigned ClusterIssuer, **wildcard Certificate + paylaşılan Gateway** (kube-system/homelab). |
| 12 | `08_longhorn_install.yml` `[longhorn]` | master[0] | helm, `longhorn-storageclass.yml.j2` (6 StorageClass), local-path default'u kaldır, HTTPRoute. |
| 13 | `09_grafana_install.yml` `[grafana, monitoring]` | master[0] | `kube-prometheus-stack-values.yml.j2` render (storageClass), helm, PVC Bound bekle, HTTPRoute, parola göster. |
| 14 | `10_rancher_install.yml` `[rancher]` | master[0] | `rancher-deployment.yml.j2` (chart değil, düz Deployment) apply, bootstrap parolası. |
| 15 | `11_argocd_install.yml` `[argocd]` | master[0] | helm, 3 deployment Running bekle, HTTPRoute, admin parolası. |
| 16 | `99_result.yml` | master[0] | Özet tablo: Gateway IP, URL'ler, parolalar. |

8–15 arası her adım `when: <x>_install` ile kapılıdır; varsayılanda hepsi `false`
(saf k3s). Bağımlılık: `helm_install → gateway_api_install → cert_manager_install →
diğerleri`. HTTPRoute'lar (08–11) ayrıca `cert_manager_install` ister çünkü Gateway
orada oluşur.

## `add_node.yml` akışı (rol: extra_node_cluster)

1. `_resolve_user` (k3s_setup'tan include_role).
2. Paket + iscsid (main.yml içinde, 00_prerequisites'in kopyası; firewalld/swap/sysctl **yok** — todo A2).
3. `00_system_requirements.yml`: hostname (+reboot) ve chrony (`ntp_server`).
4. `01_check_existing_node.yml`: `systemctl is-active k3s|k3s-agent` → `node_already_joined`.
5. master ise `02_add_master_node.yml`: token, `existing_master_count`, ilk master
   `--cluster-init` ile mi kurulmuş kontrolü (etcd dizini), join (VIP veya IP), `kubectl get nodes` ile doğrula.
6. master ise `02_install_keepalived` (k3s_setup'tan include_role) — eklemeden sonra 3'e ulaşıldıysa VIP kurulur.
7. worker ise `03_add_worker_node.yml`: token, join, Ready bekle.

## `upgrade.yml` akışı (rol: update_cluster)

- **Play 1** `hosts: all, serial: 1`: `01_check_versions.yml` (hedef = `k3s_upgrade_version`
  yoksa `k3s_version`; `is version(..., '<', semver)`) → `02_upgrade_masters.yml` →
  `03_upgrade_workers.yml`. Her node: drain → install script ile yeniden kur → uncordon → bekle.
  Host sırası envanter sırasıdır (todo A7).
- **Play 2** `hosts: master` (serial yok): `05_cleanup_stuck_nodes` → `06_rebalance_pods`
  (todo A1: sil) → `04_verify_cluster`.

## `verify.yml` akışı

Play 1 (all): servis aktif mi, VRRP arabirimi UP mı. Play 2 (master[0], root +
`/etc/rancher/k3s/k3s.yaml`): node/pod sayıları, VIP ping (>=3), bileşen namespace'lerinde
Running olmayan pod, Gateway Programmed, HTTPRoute Accepted; `[OK]/[FAIL]/[SKIP]` listesi ve
`RESULT` satırı.

## Komutlar nerede, hangi kullanıcıyla çalışır

- `kubectl`/`helm`: **master[0]**'da, `become_user: {{ ansible_user }}`,
  `KUBECONFIG={{ user_home_directory }}/.kube/config` (symlink → `/etc/rancher/k3s/k3s.yaml`,
  mod 644). Bu yüzden `_resolve_user` her rolde ilk adımdır ve hedefte `acl` paketi gerekir.
- verify.yml ve `extra_node_cluster/02_add_master_node.yml` doğrulaması root ile
  `/etc/rancher/k3s/k3s.yaml` kullanır.
- Manifest ve values dosyaları hedefte `~/my-charts/<bileşen>/` altında durur:
  `files/my-charts/` kopyalanır, `templates/my-charts/*.j2` ve diğer `.j2`'ler oraya render edilir.
- Install script her node'da `curl -sfL https://get.k3s.io | sh -` ile çalışır; k3s install
  script'i systemd unit'ini **her çalıştırmada** `INSTALL_K3S_EXEC`'e göre yeniden yazar.
  Bu yüzden server flag'leri tek kaynaktan gelir: `k3s_server_args` (ilk kurulum, ekleme, upgrade).

## Değişken akışı

1. `inventory/cluster_inventory.yml` `all.vars`: yalnızca bağlantı (`ansible_user`, key).
   gather_facts'ten önce, ilk SSH'ta geçerli olması için envanterde.
2. `playbooks/roles/k3s_setup/vars/main.yml`: diğer her şey. **Rol vars'ı envanter,
   group_vars, host_vars ve play vars_files'ın üstündedir**; yalnızca `-e` ezer (todo B1).
3. `inventory/group_vars/all/vault.yml` (`ansible-vault`): `vault_keepalived_auth_pass`;
   vars/main.yml `keepalived_auth_pass: "{{ vault_keepalived_auth_pass | default(...) }}"` ile alır.
4. `add_node.yml`, `upgrade.yml`, `verify.yml` aynı vars/main.yml'i `vars_files` ile yükler.
5. Çalışma zamanı fact'leri: `user_home_directory`, `master_count`, `k3s_token`,
   `first_master_ip`, `k3s_version_env`, `keepalived_network`, `node_already_joined`,
   `upgrade_needed`, `k3s_target_version`.
