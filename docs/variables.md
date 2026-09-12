# Değişken Referansı

Kaynak: `playbooks/roles/k3s_setup/vars/main.yml` (aksi belirtilmedikçe),
`playbooks/roles/update_cluster/vars/main.yml`, `inventory/cluster_inventory.yml`.

**Öncelik uyarısı:** rol `vars/` dosyasındaki değerler envanter/group_vars/host_vars'tan
**ezilemez**; değiştirmek için ya dosyayı düzenle ya `-e var=deger` ver. `defaults/`'a
taşınana kadar (todo B1) bu böyle.

## Bağlantı (envanter `all.vars`)

| Değişken | Varsayılan | Not |
|---|---|---|
| `ansible_user` | `root` | Hedefte kubectl/helm bu kullanıcıyla çalışır; `~/.kube/config` ve `~/my-charts` bu kullanıcının ev dizinine yazılır. |
| `ansible_ssh_private_key_file` | `/home/shyuuhei/.ssh/id_rsa` | Kişiye özel; komut satırından `--private-key` ile ezilebilir. |

## Keepalived / ağ

| Değişken | Varsayılan | Kullanıldığı yer |
|---|---|---|
| `keepalived_vip` | `192.168.1.244` | `keepalived.conf.j2`; `k3s_server_args` (`--tls-san`); HA join `K3S_URL`; verify.yml ping; MOTD. |
| `keepalived_auth_pass` | `{{ vault_keepalived_auth_pass \| default('P@ssw0rd123!') }}` | `keepalived.conf.j2` `auth_pass`. Vault'tan ver. |
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
| `k3s_version` | `""` (latest) | `INSTALL_K3S_VERSION`. Boşken sonradan eklenen node daha yeni sürüm alabilir (todo A4). Örnek: `v1.32.9+k3s1`. |
| `k3s_upgrade_version` | `""` | update_cluster hedefi; boşsa `k3s_version`; ikisi de boşsa upgrade fail eder. |
| `k3s_disable_servicelb` | `false` | `k3s_server_args`'a `--disable servicelb`. MetalLB açıksa `true` yap; ikisi birden kapalıysa LoadBalancer IP veren kalmaz. |
| `k3s_master_taint` | `true` | `--node-taint {{ k3s_master_taint_value }}`. Yalnızca yeni kaydolan node'a etki eder. Worker yoksa Pending riski. (Yorum "VARSAYILAN KAPALI" diyor — todo A8.) |
| `k3s_master_taint_value` | `node-role.kubernetes.io/master=system:NoSchedule` | values dosyalarındaki toleration'lar bu key/value'ya göre. |
| `k3s_server_args` | türetilmiş | `--tls-san VIP --write-kubeconfig-mode 644 [--disable servicelb] [--node-taint ...]`. İlk kurulum, node ekleme ve upgrade'de aynı string. |
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

## update_cluster (`update_cluster/vars/main.yml`)

| Değişken | Varsayılan | Not |
|---|---|---|
| `upgrade_drain_timeout` | `600` | `kubectl drain --timeout` (sn). |
| `upgrade_drain_grace_period` | `120` | worker drain `--grace-period`. |
| `upgrade_wait_for_pods` | `60` | Her node sonrası `pause`. |
| `upgrade_force` | `false` | Sürüm eşit/yüksek olsa da yeniden kur; hedef boşsa fail'i de atlar. |

## Çalışma zamanı fact'leri (set_fact ile üretilir)

| Fact | Üretildiği yer | Anlamı |
|---|---|---|
| `user_home_directory` | `k3s_setup/tasks/_resolve_user.yml` | `getent passwd ansible_user` → ev dizini. Her rol ilk adımda üretir. |
| `master_count` | `02_install_keepalived`, `03_install_k3s`, 06/07/08/09/11, update_cluster 02/03 | `groups['master'] \| length`. HA eşiği. |
| `k3s_token` / `single_k3s_token` | token okuma task'ları | `/var/lib/rancher/k3s/server/node-token` (master[0]). |
| `first_master_ip` | `03_install_k3s` (single), extra_node 02 | `hostvars[master0].ansible_host \| default(master0)`. |
| `k3s_version_env` | `03_install_k3s`, extra_node 02/03 | `INSTALL_K3S_VERSION=...` veya boş. |
| `keepalived_network` | `02_install_keepalived` | VRRP arabirimi. |
| `node_already_joined` | `extra_node/01_check_existing_node` | systemd servisi aktifse `true` → join atlanır. |
| `upgrade_needed`, `k3s_target_version`, `current_k3s_version` | `update_cluster/01_check_versions` | semver karşılaştırma sonucu. |
| `*_values_file` | 06/07/08/11 | HA/single values yolu. |
