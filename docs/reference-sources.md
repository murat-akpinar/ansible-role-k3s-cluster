# Referans Materyali İndeksi (`.tmp/`)

`.tmp/` altındaki dosyalar upstream projelerden indirilmiş **salt okunur** kaynaklardır.
`.tmp/` git'te hiçbir zaman izlenmez; `sh docs/fetch-reference-sources.sh` ile yeniden
indirilir (~4,5 MB, 160+ dosya, 1-2 dakika). Aşağıdaki yollar `.tmp/` köküne görelidir.

Sürüm pinleri `playbooks/roles/k3s_setup/vars/main.yml` ile aynı tutulur. Bir chart
sürümü değişince buradaki `values-*.yaml` satırını ve `fetch-reference-sources.sh`'deki
tag'i güncelle.

| Bileşen | Pin (vars/main.yml) | Kaynak tag/branch |
|---|---|---|
| k3s | `k3s_version: ""` (latest) | k3s-io/docs `main` |
| MetalLB | chart 0.16.1 | metallb/metallb `v0.16.1` |
| cert-manager | chart v1.21.1 | cert-manager/cert-manager `v1.21.1` |
| Longhorn | chart 1.12.1 | longhorn/longhorn `v1.12.1`, docs `1.12.1` |
| kube-prometheus-stack | chart 88.3.0 | helm-charts `kube-prometheus-stack-88.3.0` |
| ArgoCD | chart 10.3.3 (ArgoCD v3.5.1) | argo-helm `argo-cd-10.3.3`, argo-cd `v3.5.1` |
| Gateway API | v1.5.1 | gateway-api `v1.5.1` |
| Traefik | 3.7.x (k3s gömülü) | traefik `v3.7`, chart `master` |
| Ansible | core 2.21.3 (yerel) | ansible-documentation `devel` + yerel `ansible-doc` |

## ansible/
| Dosya | Ne için |
|---|---|
| `modules/<fqcn>.txt` | Repoda kullanılan her modülün `ansible-doc` çıktısı; kurulu sürümle birebir. Parametre/dönüş değeri sorusunda ilk bakılacak yer. |
| `modules/kubernetes.core.helm*.txt`, `k8s*.txt`, `k8s_drain.txt` | Shell yerine modül kullanılırsa (todo B3) gereken imzalar. |
| `modules/ansible.builtin.version.test.txt` | `is version(...)` testi (update_cluster/01_check_versions.yml). |
| `modules/ansible.posix.profile_tasks.callback.txt` | ansible.cfg'deki callback. |
| `ansible-config-list.txt` | Tüm ansible.cfg anahtarları ve varsayılanları. |
| `guide-variables.rst` | **Değişken öncelik sırası** (role vars > inventory; todo B1'in dayanağı). |
| `guide-strategies.rst` | `serial`, `run_once`, `order` (upgrade.yml). |
| `guide-loops.rst` | `until/retries/delay`, `loop_control`. |
| `guide-delegation.rst` | `delegate_to`, `run_once` ile fact yayılımı. |
| `guide-conditionals.rst`, `guide-blocks.rst`, `guide-error-handling.rst` | `when`, block/rescue, `failed_when/changed_when`. |
| `guide-tags.rst` | `tags: always` davranışı (main.yml). |
| `guide-reuse-roles.rst` | `include_role tasks_from`, defaults/ vs vars/. |
| `guide-filters.rst`, `guide-tests.rst` | `regex_replace`, `selectattr`, `map('extract')`, `version`. |
| `guide-privilege-escalation.rst` | `become_user` + acl gereksinimi. |
| `guide-handlers.rst`, `vault.rst`, `inventory-intro.rst`, `playbooks-best-practices.rst` | Handler notify, vault akışı, YAML envanter, dizin düzeni önerileri. |

## k3s/
| Dosya | Ne için |
|---|---|
| `install.sh` | get.k3s.io scripti: `INSTALL_K3S_VERSION`, `INSTALL_K3S_EXEC`, `K3S_URL/K3S_TOKEN`, `INSTALL_K3S_SKIP_DOWNLOAD` vb. tüm env değişkenleri. |
| `cli-server.md` | **Tüm server flag'leri** (`--tls-san`, `--disable`, `--node-taint`, `--write-kubeconfig-*`, `--etcd-*`, `--cluster-init`). |
| `cli-agent.md` | Agent flag'leri. |
| `cli-etcd-snapshot.md`, `datastore-backup-restore.md` | Snapshot alma/geri yükleme (todo C4). |
| `datastore-ha-embedded.md` | 3+ server HA kurulum akışı, join sırası. |
| `installation-requirements.md` | **Port tablosu** (2379-2380, 6443, 8472, 10250...), OS/donanım gereksinimleri (todo A3). |
| `installation-configuration.md` | config.yaml ile flag verme, env değişkenleri. |
| `networking-basic-options.md`, `networking-services.md` | Flannel backend'leri, ServiceLB (klipper), Traefik HelmChartConfig, CoreDNS. |
| `upgrades-manual.md`, `upgrades-automated.md` | Install script ile upgrade; **system-upgrade-controller Plan** (todo B6). |
| `add-ons-helm.md` | HelmChart / HelmChartConfig CRD'leri (05_gateway_api_install.yml). |
| `cluster-access.md` | kubeconfig konumu/izinleri. |
| `security-hardening-guide.md` | CIS sertleştirme, kubeconfig modu (todo C7). |
| `advanced.md`, `known-issues.md`, `architecture.md`, `related-projects.md`, `installation-private-registry.md`, `installation-uninstall.md`, `cli-token.md` | Diğer. |

## kubernetes/
| Dosya | Ne için |
|---|---|
| `version-skew-policy.md` | kubelet apiserver'dan yeni olamaz (todo A4/A7). |
| `taint-and-toleration.md`, `assign-pod-node.md` | Master taint, nodeAffinity/podAntiAffinity (values dosyaları). |
| `safely-drain-node.md`, `configure-pdb.md`, `kubectl-drain.md` | Drain semantiği, PDB ile etkileşim (update_cluster). |
| `storage-classes.md` | StorageClass alanları, default class annotation'ı. |
| `gateway.md` | Gateway API'nin Kubernetes tarafı özeti. |
| `kubectl-wait.md`, `kubectl-apply.md`, `server-side-apply.md`, `jsonpath.md` | `kubectl wait --for=condition`, `--server-side`, jsonpath ifadeleri. |
| `service.md` | Service tipleri / LoadBalancer. |

## helm/
| Dosya | Ne için |
|---|---|
| `get-helm-3.sh` | Install scripti; `DESIRED_VERSION` env'i (todo C11). |
| `helm_upgrade.md`, `helm_install.md` | `--install`, `--repo`, `--wait`, `--atomic`, `--version` (todo B3). |
| `helm_repo_add.md`, `helm_show_values.md` | Repo yönetimi, values görüntüleme. |
| `values_files.mdx`, `subcharts_and_globals.md` | Values birleştirme sırası, **subchart values'ın nereye yazılacağı** (0fe9ffa hatasının kökü). |
| `install.mdx`, `using-helm.mdx` | Genel. |

## keepalived/
| Dosya | Ne için |
|---|---|
| `keepalived.conf.5.man` | Tam keepalived.conf referansı (roff; `man -l` ile okunur): `vrrp_script`, `track_script`, `unicast_peer`, `nopreempt`, `enable_script_security`. |
| `sample-keepalived.conf.vrrp` | Temel VRRP örneği. |
| `sample-keepalived.conf.vrrp.scripts` | vrrp_script / weight / fall / rise örneği (templates/keepalived.conf.j2 ile karşılaştır). |
| `sample-keepalived.conf.vrrp.localcheck` | Yerel sağlık kontrolü örneği (todo C5). |

## metallb/
| Dosya | Ne için |
|---|---|
| `values-0.16.1.yaml` | Pinli chart'ın tüm values anahtarları (files/my-charts/metallb/values-*.yml doğrulaması). |
| `configuration.md` | IPAddressPool / L2Advertisement (templates/metallb-config.yml.j2). |
| `concepts-layer2.md` | L2 modu kısıtları (tek node anons eder). |
| `installation.md`, `usage.md`, `troubleshooting.md` | Kurulum önkoşulları (kube-proxy strictARP), webhook sorunları. |

## cert-manager/
| Dosya | Ne için |
|---|---|
| `values-v1.21.1.yaml` | Pinli chart values (`crds.enabled`, replicaCount, affinity). |
| `configuration-selfsigned.md`, `configuration-ca.md` | SelfSigned issuer; **CA issuer zinciri** (todo C2). |
| `usage-certificate.md` | Certificate alanları (duration, renewBefore, dnsNames). |
| `usage-gateway.md` | Gateway API ile cert-manager (gateway-shim) alternatifi. |
| `installation-helm.md`, `troubleshooting.md` | Kurulum, "certificate not Ready" ayıklama. |

## longhorn/
| Dosya | Ne için |
|---|---|
| `values-v1.12.1.yaml`, `chart-README-v1.12.1.md` | Pinli chart values (`persistence.defaultClassReplicaCount`, `csi.*ReplicaCount`, tolerations). |
| `install-requirements.md` | open-iscsi, nfs, kernel, **multipathd** notu (todo C8). |
| `best-practices.md` | Node/disk düzeni, replica sayısı. |
| `storage-class-parameters.md` | `numberOfReplicas` vb. (templates/longhorn-storageclass.yml.j2). |
| `install-with-helm.md`, `upgrade.md`, `troubleshooting.md`, `longhornctl-preflight.md` | Kurulum/yükseltme/ayıklama, `longhornctl check preflight`. |

## kube-prometheus-stack/
| Dosya | Ne için |
|---|---|
| `values-88.3.0.yaml` | Pinli chart'ın tüm values'ı; `kubeControllerManager/kubeScheduler/kubeProxy/kubeEtcd` bölümleri (todo C1), `grafana.*`, `prometheus.prometheusSpec.*`. |
| `README-88.3.0.md` | Upgrade notları (major sürüm CRD adımları), k3s bölümü. |
| `grafana-subchart-values.yaml` | Grafana subchart'ının kendi values'ı (`adminPassword`, `persistence`). |

## argocd/
| Dosya | Ne için |
|---|---|
| `values-10.3.3.yaml`, `chart-README-10.3.3.md` | Pinli chart values (`configs.params."server.insecure"`, `redis-ha`, replicas). |
| `operator-ingress.md` | TLS sonlandırma / insecure mod / Gateway API örnekleri. |
| `operator-high-availability.md` | HA replika önerileri, redis-ha. |
| `operator-installation.md`, `getting-started.md` | Kurulum ve ilk admin parolası. |

## rancher/
| Dosya | Ne için |
|---|---|
| `installation-requirements.md` | **Desteklenen Kubernetes sürüm penceresi** (todo C10), kaynaklar. |
| `install-on-kubernetes.md`, `helm-chart-options.md` | Resmi chart ile kurulum seçenekleri (templates/rancher-deployment.yml.j2 alternatifi). |
| `upgrades.md` | Minor atlamama kuralı. |

## gateway-api/
| Dosya | Ne için |
|---|---|
| `standard-install-v1.5.1.yaml` | k3s'in kurduğu CRD paketi (05_gateway_api_install.yml ile aynı). |
| `gateway.md`, `httproute.md`, `gatewayclass.md`, `referencegrant.md` | API alanları: listeners, parentRefs/sectionName, allowedRoutes, cross-namespace. |
| `guide-http-routing.md`, `guide-tls.md`, `guide-http-redirect-rewrite.md` | HTTPRoute örnekleri, TLS Terminate, **HTTP→HTTPS redirect** (todo C6). |
| `api-overview.md` | Kavramlar. |

## traefik/
| Dosya | Ne için |
|---|---|
| `provider-kubernetes-gateway.md` | `providers.kubernetesGateway.*` seçenekleri (files/traefik-gateway-config.yml). |
| `routing-gateway-api.md` | Traefik'in desteklediği Gateway API alt kümesi, entryPoint↔listener port eşlemesi (8443 notu). |
| `entrypoints.md` | web/websecure entrypoint yapılandırması. |
| `helm-chart-values.yaml`, `helm-chart-README.md` | k3s'in HelmChartConfig ile ezdiği chart values'ı (`gateway.enabled`, `ports.*`). |

## system-upgrade-controller/
| Dosya | Ne için |
|---|---|
| `README.md`, `example-k3s-upgrade.yaml` | Plan CRD alanları ve k3s örneği (todo B6). |

## chrony/
| Dosya | Ne için |
|---|---|
| `chrony.conf.adoc` | chrony.conf direktifleri (templates/chrony.j2). |
