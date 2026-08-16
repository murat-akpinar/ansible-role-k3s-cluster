## [unreleased]

### 🚀 Features

- Yapısal değişiklikler nginx ingress kaldırıldı yapı revize edildi ([810bb07](https://github.com/murat-akpinar/ansible-role-k3s-cluster/commit/810bb076386af9dcb68e64980af2722393f2f7ac))
- Interface bilgi kontolü eklendi ([5926fc1](https://github.com/murat-akpinar/ansible-role-k3s-cluster/commit/5926fc159196db8cff5ff3ae403a7304249845c2))
- Yapı düzenlenmesi ([2bc036c](https://github.com/murat-akpinar/ansible-role-k3s-cluster/commit/2bc036cf78c494db96e863e07d5b656c63207158))
- Longhorn olmadan grafana kurulumu için ayarlar yapıldu ([7a3dbd7](https://github.com/murat-akpinar/ansible-role-k3s-cluster/commit/7a3dbd703cfbe972951c27fdc7dc8de68045e2bb))
- Merkezi bekleme adımı eklendi ([dde887e](https://github.com/murat-akpinar/ansible-role-k3s-cluster/commit/dde887e5a95367ea9cd95bd208f4f7a28c3cfd9e))
- Taint true false eklendi ([839fd32](https://github.com/murat-akpinar/ansible-role-k3s-cluster/commit/839fd32539f9fc7e74f400d258c319177a64ffcb))
- Ingress kaynaklari Gateway API'ye tasindi ([24dce96](https://github.com/murat-akpinar/ansible-role-k3s-cluster/commit/24dce967c9f83f5e29820ed8b55c00380ae0680a)) — k3s gomulu Traefik'in Gateway saglayicisi acildi; 4 Ingress kaynagi HTTPRoute'a cevrildi ve host basina sertifikalar tek wildcard sertifikada birlestirildi.
- Bilesen surumleri guncellendi ve tek yerden yonetiliyor ([7933c07](https://github.com/murat-akpinar/ansible-role-k3s-cluster/commit/7933c07a756bd8b246cfa5577af1dcde1e58fc7e)) — cert-manager v1.13.1 (2023) -> v1.21.1, Rancher v2.8.2 -> v2.15.0. Digerleri "" idi (her kurulumda en son); bugunun surumlerine sabitlendi.

### 🐛 Bug Fixes

- Disable servicelb eklendi ([be071cb](https://github.com/murat-akpinar/ansible-role-k3s-cluster/commit/be071cb1bfb40c8d8101ef84e579edd5265a00ce))
- Çıktı ingilizceye çevrildi ([919e1ad](https://github.com/murat-akpinar/ansible-role-k3s-cluster/commit/919e1ad237b6f94b9effb8cd54e07ee1c9e63127))
- Acl kontrol ([27f424b](https://github.com/murat-akpinar/ansible-role-k3s-cluster/commit/27f424b2c73952aea91f00f7876d95bea7edf20f))
- Tls sorunu düzeltildi ([7fbd3ea](https://github.com/murat-akpinar/ansible-role-k3s-cluster/commit/7fbd3ea0e4ae33788e2457777301491ce7abd991))
- Os-family ([6b4fb83](https://github.com/murat-akpinar/ansible-role-k3s-cluster/commit/6b4fb83faac2feb32e1c709836c6d1335ed2484a))
- API bekleme adımı eklendi ([846115c](https://github.com/murat-akpinar/ansible-role-k3s-cluster/commit/846115c6b9c82e0689ae0d3953c7b1a412cb20ba))
- Pod affinityler düzeltildi ([627eb38](https://github.com/murat-akpinar/ansible-role-k3s-cluster/commit/627eb3802c5e4e8cae24b11d25fb17a80bc5e459))
- Ek master nodelar için k3s.yaml bekleme adımı eklendi ([7f4c2a8](https://github.com/murat-akpinar/ansible-role-k3s-cluster/commit/7f4c2a8814d31757c8843234eded2e92f8d3c2a9)) — Ek master nodelarında symlink oluşturulmadan önce k3s.yaml dosyasının oluşması bekleniyor; race condition düzeltildi.
- HTTPRoute'lar mevcut cluster'da uygulanmiyordu ([f2b0165](https://github.com/murat-akpinar/ansible-role-k3s-cluster/commit/f2b0165cb8113bd0a386ad6dbe0b6f9c5fcbf7ba)) — Ingress'ten devralinan namespace sarti gecisi mevcut bir cluster'da tamamen etkisiz birakiyordu; ayrica CRD kurulumunda ve verify sayiminda iki hata vardi.
- Cert-manager kapaliyken verify yanlis FAIL veriyordu ([deb6c35](https://github.com/murat-akpinar/ansible-role-k3s-cluster/commit/deb6c352122f76d83894031a37ad03c61f718ce6)) — Gateway ve HTTPRoute'lar 07_cert_manager_install.yml icinde olusturuluyor, yani cert_manager_install: false iken hic var olmuyorlar. verify.yml bunlari kosulsuz kontrol ettigi icin desteklenen bir yapilandirmada olmayan kaynagi FAIL diye raporluyordu.
- Helm values'lardaki sessizce yok sayilan anahtarlar duzeltildi ([0fe9ffa](https://github.com/murat-akpinar/ansible-role-k3s-cluster/commit/0fe9ffa166e2bb7b5fe89e6d0b182d6ecba416e6)) — Values dosyalari sabitlenen chart surumlerine karsi "helm template" ile render edilip cikti incelendi; iki ayar hic uygulanmiyordu.
- K3s server flag'leri upgrade ve node ekleme sirasinda kayboluyordu ([cd7de00](https://github.com/murat-akpinar/ansible-role-k3s-cluster/commit/cd7de0075f5c23a3d631609b0d430614719d6cc4)) — Ayni flag dizisi 8 yerde elle tekrarlanmis ve 3 farkli sekilde eksilmisti. k3s install script'i her calistiginda systemd unit'ini INSTALL_K3S_EXEC'e gore YENIDEN YAZDIGI icin eksik flag = kalici kayip.
