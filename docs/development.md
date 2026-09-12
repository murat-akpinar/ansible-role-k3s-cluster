# Geliştirme Kuralları

## Commit ve CHANGELOG

- Biçim: `tip(kapsam): mesaj` — mesaj **Türkçe, aksansız** (ı→i, ş→s, ğ→g...). Gövde varsa
  ilk paragraf CHANGELOG'a "—" ile eklenir (cliff.toml `body`).
- Kullanılan tipler: `feat`, `fix`, `bugfix`, `docs`, `refactor`, `chore`. Kapsam örnekleri:
  `k3s_setup`, `vars`, `changelog`.
- CHANGELOG `git-cliff` ile üretilir: `git cliff -o CHANGELOG.md` → ayrı commit
  `chore(changelog): CHANGELOG yeniden uretildi`. (todo B8: yalnızca tag atarken üretmek önerildi.)
- Tag yok; README `v1.0` rozeti taşıyor. İlk tag `v1.0.0` olmalı.

## todo.md — bulgu defteri

- Git'te izlenmez (`.gitignore`). Bölümler: A (davranış/risk), B (yapısal), C (platform),
  D (küçük); her madde `dosya:satır`, neden, düzeltme, `- [ ]` kutusu; sonda "Onerilen sira".
- Bir madde kapanınca `[x]` işaretle ve commit mesajında madde numarasını an
  (`b842382` örneği: "todo.md A1-A14, B1-B5, C1-C5").

## `.tmp/` — referans materyali

- `sh docs/fetch-reference-sources.sh` upstream dokümanları indirir; `docs/reference-sources.md` hangi dosyanın ne için
  olduğunu listeler. `.tmp/` git'te asla izlenmez; script ve indeks `docs/` altında.
- `ansible/modules/*.txt` yerel `ansible-doc` çıktısıdır (core 2.21.3); modül parametresi
  sorusunda web yerine buraya bak.
- Chart sürümü pinlenince: `vars/main.yml` + `docs/fetch-reference-sources.sh` tag'i + `docs/reference-sources.md` tablosu birlikte değişir.

## Yerel kontroller (CI yok — todo B7)

```sh
ansible-playbook -i inventory/cluster_inventory.yml k3s_setup.yml --syntax-check
ansible-playbook -i inventory/cluster_inventory.yml upgrade.yml --syntax-check
ansible-playbook -i inventory/cluster_inventory.yml add_node.yml --syntax-check
ansible-playbook -i inventory/cluster_inventory.yml verify.yml --syntax-check
ansible-inventory -i inventory/cluster_inventory.yml --list | head
pipx install ansible-lint yamllint   # kurulu değil
ansible-lint playbooks/ *.yml
```

`helm` yerelde kurulu değil; values doğrulaması için chart'ı `.tmp/<bileşen>/values-*.yaml`
ile karşılaştır ya da master[0]'da `helm template ... -f values | less`.

## Yeni bileşen ekleme kalıbı

1. `vars/main.yml`: `<x>_install: false`, `helm_repo_<x>`, `<x>_chart_version` (yorumla pin tarihi).
2. `tasks/NN_<x>_install.yml`: helm kalıbı (06_metallb örneği), `when: inventory_hostname == groups['master'][0]`,
   `become_user: "{{ ansible_user }}"` + `KUBECONFIG: "{{ user_home_directory }}/.kube/config"`,
   `kubectl wait` ile bekleme, HTTPRoute apply (`cert_manager_install` şartıyla).
3. `tasks/main.yml`: `import_tasks` + `when: <x>_install | default(false)` + `tags: ['<x>']`.
4. `files/my-charts/<x>/values-ha.yml` ve `values-single-master.yml` (master taint tolere etme,
   podAntiAffinity preferred); domain içeriyorsa `templates/my-charts/<x>/httproute.yml.j2` ve
   `04_install_helm.yml` render listesine ekle.
5. `verify.yml` `components` listesi, `99_result.yml` özet satırı, `templates/wellcome.j2` kutusu.
6. README (TR + EN) "Adım 7" tablosu ve vars örneği; `docs/fetch-reference-sources.sh` + `docs/reference-sources.md`.

## Yerel notlar

- `inventory/cluster_inventory.yml` bu makinede `git update-index --skip-worktree` ile
  işaretli: düzenlemeler `git status`'ta görünmez, commit'e girmez. Geri almak:
  `git update-index --no-skip-worktree inventory/cluster_inventory.yml`.
- `ansible.cfg` `host_key_checking = False` ve `deprecation_warnings = False` (todo D3).
