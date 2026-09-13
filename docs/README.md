# Proje Dokümantasyonu

README.md kullanıcıya dönük "nasıl kurarım" anlatımıdır. Buradaki dosyalar
**kodun nasıl çalıştığını ve nasıl bakım yapılacağını** anlatır; her satır
repodaki gerçek dosyalardan türetilmiştir.

| Dosya | Ne zaman okunur |
|---|---|
| [architecture.md](architecture.md) | Playbook akışı, roller, HA/single-master karar noktaları, komutların nerede çalıştığı. Koda ilk kez dokunmadan önce. |
| [variables.md](variables.md) | Tüm değişkenler: varsayılan, hangi dosyada kullanıldığı, öncelik kuralı. Bir ayarı değiştirmeden önce. |
| [components.md](components.md) | Bileşen bazında (k3s, keepalived, helm, Gateway API, MetalLB, cert-manager, monitoring, Rancher, ArgoCD) rolün ne yaptığı ve bilinen tuzaklar. |
| [runbooks.md](runbooks.md) | Operasyon adımları: kurulum, node ekleme, upgrade, doğrulama, domain/IP değişikliği, chart sürüm yükseltme, sıfırlama. |
| [troubleshooting.md](troubleshooting.md) | Belirti → neden → düzeltme tablosu ve teşhis komutları. |
| [development.md](development.md) | Repo kuralları: commit/CHANGELOG, todo.md, `.tmp/` referans materyali, yerel kontroller, yeni bileşen ekleme kalıbı. |

İlgili diğer yerler:
- `todo.md` — açık bulgu/iyileştirme listesi (git'te izlenmez).
- `docs/reference-sources.md` — upstream dokümanların indeksi; `sh docs/fetch-reference-sources.sh` ile indirilir.
- `CLAUDE.md` — yer imleri ve çalışma kuralları (Claude Code için, insanlar için de özet).
