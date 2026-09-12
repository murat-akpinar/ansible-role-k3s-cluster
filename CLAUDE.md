# CLAUDE.md

Ansible ile k3s cluster kurulumu (HA/single-master, Keepalived VIP), node ekleme, rolling
upgrade ve sağlık kontrolü. Opsiyonel bileşenler: Gateway API (Traefik), MetalLB,
cert-manager, Longhorn, kube-prometheus-stack, Rancher, ArgoCD. Varsayılan: saf k3s.

## Yer imleri — neyi nerede bulurum

| İhtiyaç | Yer |
|---|---|
| Akış, roller, HA eşiği (`master_count >= 3`), komutlar nerede çalışır | `docs/architecture.md` |
| Bir değişkenin varsayılanı / hangi dosyada kullanıldığı | `docs/variables.md` |
| Bileşenin rolde nasıl kurulduğu, bilinen tuzaklar | `docs/components.md` |
| Kurulum / node ekleme / upgrade / doğrulama adımları | `docs/runbooks.md` |
| Belirti → neden → komut | `docs/troubleshooting.md` |
| Commit/CHANGELOG kuralı, todo.md formatı, yeni bileşen kalıbı, yerel kontroller | `docs/development.md` |
| Açık bulgular ve iyileştirme sırası (A/B/C/D, `dosya:satır`) | `todo.md` (git'te yok) |
| Upstream dokümanlar (k3s flag'leri, chart values, Gateway API, keepalived.conf, ansible-doc) | `.tmp/<bileşen>/`; indeks **`docs/reference-sources.md`**; yoksa `sh docs/fetch-reference-sources.sh` |
| Kullanıcıya dönük anlatım | `README.md` (TR), `README_EN.md` |

Sık kullanılan upstream dosyalar:
`.tmp/k3s/cli-server.md` (server flag'leri) · `.tmp/k3s/installation-requirements.md` (port tablosu) ·
`.tmp/k3s/install.sh` (INSTALL_K3S_* env) · `.tmp/<chart>/values-<pin>.yaml` (values anahtarları) ·
`.tmp/gateway-api/httproute.md` · `.tmp/traefik/provider-kubernetes-gateway.md` ·
`.tmp/keepalived/keepalived.conf.5.man` · `.tmp/ansible/modules/<fqcn>.txt` · `.tmp/ansible/guide-variables.rst` (öncelik).

## Repo haritası

```
k3s_setup.yml  add_node.yml  upgrade.yml  verify.yml     giriş playbook'ları
inventory/cluster_inventory.yml                          bağlantı değişkenleri (all.vars) + hostlar
playbooks/roles/k3s_setup/vars/main.yml                  TÜM ayarlar (rol vars = yüksek öncelik)
playbooks/roles/k3s_setup/tasks/main.yml                 sıralı import_tasks; NN_<adım>.yml
playbooks/roles/k3s_setup/{files,templates}/my-charts/   chart values ve HTTPRoute/Gateway manifestleri
playbooks/roles/extra_node_cluster/                      node ekleme (k3s_setup'tan include_role kullanır)
playbooks/roles/update_cluster/                          rolling upgrade
```

## Komutlar

```sh
ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml [--tags helm,cert-manager] [--ask-vault-pass]
ansible-playbook -i inventory/cluster_inventory.yml add_node.yml
ansible-playbook -i inventory/cluster_inventory.yml upgrade.yml
ansible-playbook -i inventory/cluster_inventory.yml verify.yml
ansible-playbook -i inventory/cluster_inventory.yml <playbook> --syntax-check
git cliff -o CHANGELOG.md          # CHANGELOG üretimi (ayrı chore(changelog) commit'i)
sh docs/fetch-reference-sources.sh                   # referans materyalini indir/yenile
```

## Kurallar

- Commit mesajı `tip(kapsam): mesaj`, Türkçe, **aksansız**; task adları İngilizce, task
  yorumları aksansız Türkçe. docs/ ve README aksanlı Türkçe.
- Server flag'leri yalnızca `k3s_server_args`'ta; ilk master her yerde `groups['master'][0]`
  (asla `master-1` sabiti); HA/single kararı yalnızca `master_count >= 3`.
- kubectl/helm task'ları: master[0], `become_user: "{{ ansible_user }}"`,
  `KUBECONFIG: "{{ user_home_directory }}/.kube/config"`; `user_home_directory` `_resolve_user.yml`'den.
- Chart sürümü değişirse `vars/main.yml` + `docs/fetch-reference-sources.sh` tag'i + `docs/reference-sources.md` birlikte güncellenir.
- `.tmp/` ve `todo.md` git'te ASLA izlenmez (commit/push etme); indirme scripti ve indeks `docs/` altında.
- Bir bulgu kapanınca `todo.md`'de `[x]` ve commit gövdesinde madde numarası.
- `helm`/`ansible-lint`/`yamllint` yerelde yok; `kubectl`, `ansible-doc`, `git-cliff` var. ansible-core 2.21.3.
- `inventory/cluster_inventory.yml` yerelde skip-worktree: değişiklikleri `git status` göstermez.
