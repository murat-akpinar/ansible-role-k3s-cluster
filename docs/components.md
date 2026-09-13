# Bileşenler

Her bölüm: rolün ne yaptığı → ilgili dosyalar → bekleme stratejisi → bilinen tuzaklar.
Upstream referans: `.tmp/<bileşen>/` (indeks: `docs/reference-sources.md`).

## k3s (her zaman)

- **Dosyalar:** `tasks/03_install_k3s.yml`, `03_wait_api_ready.yml`, `defaults/main.yml` (`k3s_*`).
- Gömülü gelenler: Traefik (Ingress + Gateway sağlayıcısı kapalı), ServiceLB/klipper,
  CoreDNS, local-path-provisioner, metrics-server. Rol saf modda bunlara dokunmaz.
- Server/agent flag'leri **tek dosya**: `templates/k3s-config.yaml.j2` →
  `/etc/rancher/k3s/config.yaml` (0600), `tasks/03_k3s_config.yml` yazar ve üç rol de
  çağırır. Install script systemd unit'ini her çalıştırmada yeniden yazar ama bu dosyaya
  dokunmaz, o yüzden flag'ler upgrade'de kaybolmaz (eski yöntem `k3s_server_args` idi, cd7de00).
- `k3s_hardening: true` (varsayılan) ile CIS sıkılaştırması: etcd'de `secrets-encryption`,
  API audit log (`files/k3s-audit-policy.yaml` → `server/audit.yaml`, `server/logs/` 0700; `RequestReceived`,
  lease get/update, Event ve health check kaydedilmez — değişince k3s restart gerekir),
  Pod Security Admission baseline (`files/k3s-psa.yaml` → `server/psa.yaml`, muaf namespace'ler
  içinde), `protect-kernel-defaults` + kubelet flag'leri (gerekli sysctl'leri aynı task yazar:
  `99-k3s-hardening.conf`; ayrı dosyada olsaydı `upgrade.yml` onu çalıştırmadığı için eski bir
  cluster upgrade'de kubelet'i başlatamazdı). Çalışan bir cluster'da ayar dosyası
  değişirse k3s **yeniden başlatılmalı**; task bunu ekranda hatırlatır, kendisi restart etmez.
- NetworkPolicy (CIS 5.3.2, `k3s_hardening`): `files/k3s-network-policy.yaml` → master'larda
  `server/manifests/` (0600). k3s'in deploy controller'ı açılışta ve dosya değişince uygular,
  restart gerekmez; kuralları gömülü kube-router netpol controller'ı uygular. Yalnızca ingress:
  kube-system'e namespace içi + her yerden DNS (53) ve CoreDNS metrikleri (9153) +
  metrics-server/Traefik/tüm svclb pod'ları herkese açık; kube-public ve kube-node-lease yalnızca
  namespace içi. `default` ve bileşen namespace'leri bilerek yok (Traefik/NodePort trafiği bekler).
  Tuzaklar: dosyayı silmek ya da `k3s_hardening: false` policy'leri **silmez**
  (`.tmp/k3s/installation-packaged-components.md:7`); upstream örnek svclb için yalnızca
  `svcname: traefik` seçer, `default`'taki bir LoadBalancer servisi kopardı; 9153 upstream'de yok,
  kube-prometheus-stack'in CoreDNS hedefi düşerdi. kube-system'e başka namespace'ten erişilen
  bir şey kurulursa kendi policy'si gerekir (policy'ler toplanır).
- İlk master `--cluster-init` (tek master'da da), ek master `server --server <URL>`,
  worker `agent`. **Server** join'leri `/var/lib/rancher/k3s/server/node-token`,
  **worker** join'leri `/var/lib/rancher/k3s/server/agent-token` kullanır; ikincisi
  `k3s_agent_token` boşken birincisine symlink'tir (yani davranış aynı, ama vault'a
  `vault_k3s_agent_token` koyunca worker'lar server ekleyemeyen bir token'a geçer).
- Bekleme: node-token dosyası (`wait_for`), ek master'da `/etc/rancher/k3s/k3s.yaml`,
  sonra merkezi `kubectl get --raw=/readyz` (30×10 sn).
- kubeconfig: config.yaml `write-kubeconfig-mode: "0600"` (sıkılaştırma kapalıysa `0644`);
  `~/.kube/config` **kopya** (symlink değil, kaynak 0600), `03_k3s_post_install.yml`; `.bashrc` KUBECONFIG.
- Sürüm: `k3s_version` boşsa `_resolve_k3s_version.yml` master[0]'daki çalışan sürümü okur
  ve tüm node'lara pinler (kurulum ve node ekleme); boş cluster'da latest kurulur.
- Tuzaklar: taint `true` iken (varsayılan `false`) worker'sız
  cluster'da tolere etmeyen pod'lar Pending; `--disable servicelb` yalnızca yeni unit'te etkili.

## Keepalived (master, yalnızca `master_count >= 3`)

- **Dosyalar:** `tasks/02_install_keepalived.yml`, `templates/keepalived.conf.j2`.
- `state`: master[0] MASTER, diğerleri BACKUP; `priority = 100 + N - index`;
  `virtual_router_id = keepalived_router_id`; `auth_pass` vault'tan; `interface` otomatik
  (`ansible_default_ipv4.interface`) ya da `keepalived_interface`.
- `vrrp_script chk_k3s`: `/usr/bin/pidof k3s`, weight -20, fall/rise 2 → k3s ölünce VIP devreder.
- `keepalived.conf` değişince handler `Reload keepalived` (`systemd state: reloaded`, SIGHUP) koşar;
  restart değil, tüm master'larda aynı anda VIP düşmesin diye.
- `enable_script_security` + `script_user keepalived_script` (rol kullanıcıyı oluşturur;
  `/usr/bin/pidof` `root:root 0755` tutulur — eski sürümler sahibini `keepalived_script` yapıyordu).
- VRRP firewalld'de node IP'leri `trusted` zone'da olduğu için açıktır (`00_prerequisites.yml`),
  yani yalnızca cluster node'larından kabul edilir. `auth_pass`'ın ilk 8 karakteri kullanılır
  (`keepalived.conf(5)`) ve VRRPv2 PASS auth düz metindir — asıl koruma bu kaynak kısıtıdır.
- Tuzaklar: multicast VRRP'yi kesen ağlarda `unicast_peer` yok; `nopreempt` yok, master-1
  dönünce VIP geri zıplar.

## Helm (`helm_install`)

- **Dosyalar:** `tasks/04_install_helm.yml`, `files/my-charts/`, `templates/my-charts/`.
- `helm_version` arşivi (`get.helm.sh`, `unarchive`) → `/usr/local/bin/helm`. Kurulu sürüm farklıysa
  yükseltir, aynıysa atlar. Tüm master'lara kurulur, yalnızca master[0] kullanır. Arch eşlemesi
  x86_64/aarch64/armv7l; başka mimaride task tanımsız anahtar hatası verir.
- `files/my-charts/` → `~/my-charts/` kopya; domain içeren 5 manifest `.j2`'den render:
  gateway/gateway.yml, gateway/wildcard-certificate.yml, {argocd,grafana,rancher}/httproute.yml.
- Her chart adımı aynı kalıp: `helm upgrade --install <release> <chart> --repo {{ helm_repo_<x> }}
  --wait --timeout 10m --version X -f values` (3 retry × 30 sn) → ek manifest apply. `helm repo add`
  yok; `--wait` chart'ın Deployment/StatefulSet/DaemonSet/PVC'lerini hazır bekler, ayrı "pod Running"
  task'ı yok. `kubectl apply` task'ları yalnızca `created`/`configured` satırı varsa `changed`.
- Values seçimi: `master_count >= 3` → `values-ha.yml`, aksi `values-single-master.yml`.
  HA values'ları master taint'ini **tolere etmez** (worker'a yerleşir), `podAntiAffinity: preferred`.

## Gateway API + Traefik (`gateway_api_install`)

- **Dosyalar:** `tasks/05_gateway_api_install.yml`, `files/traefik-gateway-config.yml`,
  `templates/my-charts/gateway/*.j2`, `vars: gateway_api_version`.
- CRD'ler zaten k3s'in traefik-crd chart'ıyla gelir; rol `standard-install.yaml`'ı
  `--server-side --force-conflicts` ile uygular (httproutes CRD 460 KB, client-side apply sığmaz).
- `HelmChartConfig traefik` (`/var/lib/rancher/k3s/server/manifests/`): `providers.kubernetesGateway.enabled: true`,
  `gateway.enabled: false` (chart'ın HTTP:8000 Gateway'i yerine bizimki). helm-controller yeniden
  kurar, restart gerekmez. `GatewayClass traefik` Accepted olana kadar 20×15 sn.
- Paylaşılan Gateway `kube-system/homelab` (cert-manager adımında oluşur): tek listener
  `websecure` **port 8443** (Traefik entryPoint portu; Service dışarıya 443), hostname
  `*.{{ cluster_domain }}`, TLS Terminate, secret `homelab-wildcard-tls`, `allowedRoutes: All`.
- HTTPRoute kalıbı: `parentRefs: {name: homelab, namespace: kube-system, sectionName: websecure}`,
  hostname `<svc>.{{ cluster_domain }}`, backend Service:port.
- Tuzaklar: HTTP listener yok → `http://` boş (todo C6); `cluster_domain` `.local` olursa mDNS çakışması;
  Gateway API sürümü Traefik'in derlendiği sürümle eşleşmeli.

## MetalLB (`metallb_install`)

- **Dosyalar:** `tasks/06_metallb_install.yml`, `templates/metallb-config.yml.j2`,
  `files/my-charts/metallb/values-*.yml`.
- `k3s_disable_servicelb: true` zorunlu; ikisi aynı Service'e IP atamaya çalışır.
- Bekleme: helm `--wait` (controller Ready), IPAddressPool apply 6×10 sn retry (webhook caBundle yayılımı).
- `speaker` DaemonSet master taint'ini tolere eder (master'daki LB servisleri için), controller etmez.
- L2 modu: tek node anons eder, failover ~saniyeler.

## cert-manager (`cert_manager_install`)

- **Dosyalar:** `tasks/07_cert_manager_install.yml`, `files/my-charts/cert-manager/*`,
  `templates/my-charts/gateway/wildcard-certificate.yml.j2`.
- `--set crds.enabled=true`; HA: controller 2, webhook 3, cainjector 2.
- `ClusterIssuer selfsigned-issuer` → `Certificate homelab-wildcard` (kube-system, 8760h,
  renewBefore 2160h, `*.domain` + `domain`) → secret `homelab-wildcard-tls` → Gateway apply →
  `Programmed` bekle. Bu adım Gateway'in sahibi olduğu için HTTPRoute'lar buna bağımlı.
- Issuer apply 6×10 sn retry: helm `--wait` webhook pod'unu bekler, cainjector'ın CA'yı yazması biraz sürer.
- Tuzak: self-signed → her istemcide uyarı; CA zinciri ile tek sefer güven (todo C2).

## Monitoring / kube-prometheus-stack (`grafana_install`)

- **Dosyalar:** `tasks/09_grafana_install.yml`, `templates/kube-prometheus-stack-values.yml.j2`
  (storageClass, kaynaklar, HA replikalar, affinity), `files/my-charts/grafana/*-single-master.yml`
  (replicas 1), `*-master-only.yml` (nodeAffinity master DoesNotExist), `vars: monitoring_storage_class`.
- Values sırası: temel `.j2` → (single ise) `-single-master` → `-master-only`; sonraki öncekini ezer.
- Prometheus 10Gi/30d, Alertmanager 2Gi, Grafana 10Gi; Grafana `adminPassword: admin`.
- Grafana `grafana.ini.server.domain/root_url` = `https://grafana.{{ cluster_domain }}` (boşken linkler localhost).
- `kube-state-metrics` subchart ayarları **subchart anahtarı altında** (`kube-state-metrics:`),
  `kubeStateMetrics:` altına yazılırsa yok sayılır (0fe9ffa).
- Bekleme: helm `--wait` (Grafana, operator, kube-state-metrics, node-exporter, Grafana PVC);
  Prometheus StatefulSet'ini operator oluşturduğu için ayrıca
  `kubectl wait --for=condition=Available prometheuses.monitoring.coreos.com/kube-prometheus-stack-prometheus` (600 sn).
- k3s controller-manager/scheduler/kube-proxy/etcd'yi tek binary içinde çalıştırır; chart'ın bunlar
  için Service/ServiceMonitor/kuralları values'ta `*.enabled: false` (yoksa `Kube*Down` kurulumdan
  itibaren firing). Bu bileşenlerin metrikleri ve Grafana panoları yok.
- Tuzaklar: HA'da `podAntiAffinity: required` + replicas 2 → en az 2 worker.

## Rancher (`rancher_install`)

- **Dosyalar:** `tasks/10_rancher_install.yml`, `templates/rancher-deployment.yml.j2`, `vars: rancher_version`.
- Chart değil: Namespace + SA (cluster-admin) + Deployment (2 replika, podAntiAffinity preferred,
  `imagePullPolicy: Always`) + ClusterIP Service. Probe yok.
- Bekleme: `kubectl rollout status deployment/rancher` (600 sn). Probe olmadığı için "hazır" =
  konteyner başladı; Rancher'ın gerçekten cevap vermesi birkaç dakika daha sürebilir.
- Bootstrap parolası `cattle-system/bootstrap-secret` (20×10 sn bekler).
- Tuzaklar: Rancher'ın k8s sürüm penceresi dar, minor atlanamaz (todo C10).

## ArgoCD (`argocd_install`)

- **Dosyalar:** `tasks/11_argocd_install.yml`, `files/my-charts/argocd/values-*.yml`,
  `templates/my-charts/argocd/httproute.yml.j2`.
- `configs.params."server.insecure": "true"` — TLS Gateway'de biter, backend HTTP.
- `--set global.domain=argocd.{{ cluster_domain }}` → `argocd-cm` `url` (chart varsayılanı `argocd.example.com`).
- HA: server/controller/repoServer/applicationSet 2 replika; redis tek instance (redis-ha kapalı).
- Bekleme: helm `--wait` (server, repo-server, applicationset Deployment'ları, application-controller StatefulSet).
- İlk parola `argocd-initial-admin-secret` (silinebilir; rol `failed_when: false`).

## Sistem hazırlığı (her node)

- `00_system_requirements.yml`: CPU/RAM uyarı, swap kapalı (+fstab), `overlay`/`br_netfilter`
  (+`/etc/modules-load.d/k3s.conf`), sysctl bridge-nf-call-*/ip_forward (`/etc/sysctl.d/99-k3s.conf`),
  chrony (`chrony.j2`, handler ile restart).
- `00_prerequisites.yml`: acl (become_user için), firewalld aktifse `6443/tcp`
  herkese; node IP'leri (`ansible_host`) ve pod/service CIDR'ları `trusted` zone — node-arası
  `8472/udp`, `10250/tcp`, `2379-2380/tcp` ve VRRP böylece yalnızca node'lardan gelir. Eski
  "herkese açık `8472/udp` + `10250/tcp`" kuralı `state: disabled` ile kapatılır. firewalld
  yoksa (Ubuntu/Debian) tek `[WARN]` satırı; rol firewalld kurmaz (LoadBalancer/NodePort
  trafiğini kesmemek için).
- `01_configure_hostname.yml`: hostname ≠ inventory_hostname ise değiştir (hostnamectl anında etkili, reboot yok).
- `00_wellcome.yml`: MOTD (`wellcome.j2`: rol, topoloji, bileşen kutuları, sürümler).
