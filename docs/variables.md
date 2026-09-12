# Değişken Referansı

Kaynak: `playbooks/roles/k3s_setup/defaults/main.yml` (aksi belirtilmedikçe),
`playbooks/roles/update_cluster/defaults/main.yml`, `inventory/cluster_inventory.yml`.

**Nereden değiştirilir:** buradaki her değer rol `defaults/`'unda, yani öncelik
sırasının en altında. Üç yol da geçerli, üstteki alttakini ezer:

1. `-e cluster_domain=ornek.local` (tek seferlik),
2. `inventory/group_vars/all/main.yml` (kalıcı override dosyası; örnek tamamı
   yorumlu gelir — `git pull` ile gelen rol güncellemeleri bu dosyayı bozmaz),
3. `playbooks/roles/k3s_setup/defaults/main.yml`'i doğrudan düzenlemek.

Tek istisna `k3s_server_args`: `k3s_setup/vars/main.yml`'de durur ve **bilerek**
ezilemez (yalnızca `-e`). Bkz. [architecture.md](architecture.md) "Değişken akışı".

## Bağlantı (envanter `all.vars`)

| Değişken | Varsayılan | Not |
|---|---|---|
| `ansible_user` | `root` | Hedefte kubectl/helm bu kullanıcıyla çalışır; `~/.kube/config` ve `~/my-charts` bu kullanıcının ev dizinine yazılır. |
| `ansible_ssh_private_key_file` | `/home/shyuuhei/.ssh/id_rsa` | Kişiye özel; komut satırından `--private-key` ile ezilebilir. |

## Keepalived / ağ

| Değişken | Varsayılan | Kullanıldığı yer |
|---|---|---|
| `keepalived_vip` | `192.168.1.244` | `keepalived.conf.j2`; `k3s_server_args` (`--tls-san`); HA join `K3S_URL`; verify.yml ping; MOTD. |
| `keepalived_auth_pass` | `{{ vault_keepalived_auth_pass \| default('P@ssw0rd123!') }}` | `keepalived.conf.j2` `auth_pass`. Vault'tan ver. keepalived yalnızca **ilk 8 karakteri** kullanır (`keepalived.conf(5)`); VRRP'yi asıl koruyan `00_prerequisites.yml`'nin kaynak kısıtı. |
| `keepalived_interface` | `""` (= `ansible_default_ipv4.interface`) | `02_install_keepalived.yml` → `keepalived_network`; verify.yml. |
| `keepalived_router_id` | `51` | `virtual_router_id`; aynı L2'de ikinci cluster varsa değiştir. |
| `cluster_domain` | `homelab.local` | Gateway listener hostname, wildcard Certificate, 4 HTTPRoute, 99_result URL'leri. |

## Bileşen bayrakları (varsayılan: hepsi kapalı = saf k3s)

| Değişken | Kapı | Bağımlılık |
|---|---|---|
| `helm_install` | `04_install_helm.yml` + my-charts kopyası/render | — (diğer hepsi bunu ister) |
| `gateway_api_install` | `05_gateway_api_install.yml` | helm |
| `metallb_install` | `06_metallb_install.yml` | helm; `k3s_disable_servicelb: true` ile birlikte |
| `cert_manager_install` | `07_cert_manager_install.yml` + Gateway + wildcard cert | helm, gateway_api |
| `longhorn_install` | `08_longhorn_install.yml`; `monitoring_storage_class`'ı etkiler | helm (HTTPRoute için cert_manager) |
| `grafana_install` | `09_grafana_install.yml` | helm (HTTPRoute için cert_manager) |
| `rancher_install` | `10_rancher_install.yml` | helm (HTTPRoute için cert_manager) |
| `argocd_install` | `11_argocd_install.yml` | helm (HTTPRoute için cert_manager) |

## k3s

| Değişken | Varsayılan | Not |
|---|---|---|
| `k3s_install_url` | `https://get.k3s.io` | Her node'da `curl \| sh`. |
| `k3s_version` | `""` | `INSTALL_K3S_VERSION`. Boşken `_resolve_k3s_version.yml` master[0]'daki çalışan sürüme pinler; cluster tamamen boşsa latest kurulur. Elle verirken cluster sürümünü aş**ma** (kubelet > apiserver olamaz). Örnek: `v1.32.9+k3s1`. |
| `k3s_upgrade_version` | `""` | update_cluster hedefi; boşsa `k3s_version`; ikisi de boşsa upgrade fail eder. |
| `k3s_disable_servicelb` | `false` | config.yaml'a `disable: [servicelb]`. MetalLB açıksa `true` yap; ikisi birden kapalıysa LoadBalancer IP veren kalmaz. |
| `k3s_master_taint` | `true` | config.yaml'a `node-taint`. Yalnızca yeni kaydolan node'a etki eder. Worker yoksa Pending riski. (Yorum "VARSAYILAN KAPALI" diyor — todo A8.) |
| `k3s_master_taint_value` | `node-role.kubernetes.io/master=system:NoSchedule` | values dosyalarındaki toleration'lar bu key/value'ya göre. |
| `k3s_server_args` (`vars/main.yml`) | `""` | **Boş bırakın.** Flag'ler artık `templates/k3s-config.yaml.j2` → `/etc/rancher/k3s/config.yaml`'dan geliyor (`03_k3s_config.yml`). Burada verilen bir anahtar CLI'dan geldiği için config'teki listeyi tümüyle ezer. |
| `k3s_hardening` | `true` | CIS sıkılaştırması: `secrets-encryption`, audit log, Pod Security Admission (baseline), `protect-kernel-defaults` + kubelet flag'leri, kubeconfig `0600`, PKI `*.crt` `0600`, default SA token automount kapalı. Gerekli sysctl'leri aynı task yazar (`99-k3s-hardening.conf`). `false` → yalnızca temel server anahtarları ve eski `0644` kubeconfig. |
| `k3s_agent_token` | `{{ vault_k3s_agent_token \| default('') }}` | Worker'ların join token'ı (`agent-token`). Boşken k3s bunu **server token'ına** eşitler, yani her worker cluster-admin değerinde bir secret taşır. Vault'tan verin. |
| `gateway_api_version` | `v1.5.1` | CRD pin; Traefik'in derlendiği sürümle eşleşmeli (3.7.x → v1.5.1). |
| `ntp_server` | `time.google.com` | `chrony.j2` (`server ... iburst prefer`), extra_node NTP. |

## Helm / chart sürümleri

| Değişken | Varsayılan | Not |
|---|---|---|
| `helm_install_script_url` | `.../helm/main/scripts/get-helm-3` | Sürümsüz (todo C11). |
| `helm_repo_metallb` | `https://metallb.github.io/metallb` | |
| `helm_repo_cert_manager` | `https://charts.jetstack.io` | |
| `helm_repo_longhorn` | `https://charts.longhorn.io` | |
| `helm_repo_prometheus` | `https://prometheus-community.github.io/helm-charts` | |
| `helm_repo_grafana` | `https://grafana.github.io/helm-charts` | Tanımlı ama kullanılmıyor. |
| `helm_repo_argo` | `https://argoproj.github.io/argo-helm` | |
| `metallb_chart_version` | `0.16.1` | `""` = en son. |
| `cert_manager_chart_version` | `v1.21.1` | |
| `longhorn_chart_version` | `1.12.1` | |
| `kube_prometheus_stack_chart_version` | `88.3.0` | Prometheus Operator v0.93.0 |
| `argocd_chart_version` | `10.3.3` | ArgoCD v3.5.1 |
| `rancher_version` | `v2.15.0` | Chart değil, `rancher/rancher:<tag>` imajı. Minor atlamadan yükselt. |
| `prometheus_data_url` | `http://kube-prometheus-stack-prometheus.monitoring.svc.cluster.local:9090` | Yalnızca debug çıktısı. |

## Storage / LB

| Değişken | Varsayılan | Not |
|---|---|---|
| `monitoring_storage_class` | `longhorn-retain-2` (longhorn açıksa) / `local-path` | `kube-prometheus-stack-values.yml.j2` PVC'leri. |
| `metallb_ip_pool_name` | `first-pool` | `metallb-config.yml.j2` |
| `metallb_ip_addresses` | `["192.168.1.242-192.168.1.242"]` | Aralık veya CIDR listesi. |
| `longhorn_storage_classes` | 6 giriş: `longhorn-{retain,delete}-{1,2,3}` | `{name, reclaim, replicas}`; `longhorn-storageclass.yml.j2`. Chart'ın kendi `longhorn` class'ı ayrıca default olarak gelir. |

## update_cluster (`update_cluster/defaults/main.yml`)

| Değişken | Varsayılan | Not |
|---|---|---|
| `upgrade_drain_timeout` | `600` | `kubectl drain --timeout` (sn). |
| `upgrade_drain_grace_period` | `120` | worker drain `--grace-period`. |
| `upgrade_wait_for_pods` | `60` | Her node sonrası `pause`. |
| `upgrade_force` | `false` | Sürüm eşit/yüksek olsa da yeniden kur; hedef boşsa fail'i de atlar. |

## Çalışma zamanı fact'leri (set_fact ile üretilir)

| Fact | Üretildiği yer | Anlamı |
|---|---|---|
| `user_home_directory` | `k3s_setup/tasks/_facts.yml` | `getent passwd ansible_user` → ev dizini. Her rol ilk adımda üretir. |
| `master_count` | `k3s_setup/tasks/_facts.yml` | `groups['master'] \| length`. HA eşiği; tek yerde üretilir. |
| `first_master_ip` | `k3s_setup/tasks/_facts.yml` | `hostvars[master0].ansible_host \| default(master0)`. |
| `k3s_api_endpoint` | `k3s_setup/tasks/_facts.yml` | Cluster'a katılan node'un konuştuğu adres: `master_count >= 3` ise `keepalived_vip`, değilse `first_master_ip`. HA/single ayrımının **tek** yeri; kurulum, node ekleme ve upgrade aynı değeri kullanır. |
| `k3s_token` | token okuma task'ları | `/var/lib/rancher/k3s/server/node-token` (master[0]); worker'lar için `agent-token`. |
| `k3s_version_env` | `_resolve_k3s_version.yml` | `INSTALL_K3S_VERSION=...` veya boş. Pin çözüldükten **sonra** üretilir. |
| `keepalived_network` | `02_install_keepalived` | VRRP arabirimi. |
| `node_already_joined` | `extra_node/01_check_existing_node` | systemd servisi aktifse `true` → join atlanır. |
| `upgrade_needed`, `k3s_target_version`, `current_k3s_version` | `update_cluster/01_check_versions` | semver karşılaştırma sonucu. |
| `*_values_file` | 06/07/08/11 | HA/single values yolu. |
