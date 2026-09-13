#!/bin/sh
# Referans materyalini repo kokundeki .tmp/ altina indirir.
# Kullanim:  sh docs/fetch-reference-sources.sh
# .tmp/ git'te ASLA izlenmez (.gitignore); indeks: docs/reference-sources.md
# Surum pinleri playbooks/roles/k3s_setup/defaults/main.yml ile ayni tutulmali.
set -u
cd "$(dirname "$0")/.." && mkdir -p .tmp && cd .tmp || exit 1
fail=0
get() { # get <hedef dosya> <url>
  mkdir -p "$(dirname "$1")"
  if curl -sSfL --max-time 90 -o "$1" "$2"; then printf 'ok   %s\n' "$1"
  else printf 'FAIL %s  <- %s\n' "$1" "$2"; fail=$((fail+1)); fi
}
GH=https://raw.githubusercontent.com

# ---------------- k3s (k3s-io/docs main) ----------------
K=$GH/k3s-io/docs/main/docs
get k3s/install.sh                     https://get.k3s.io
get k3s/architecture.md                $K/architecture.md
get k3s/installation-requirements.md   $K/installation/requirements.md
get k3s/installation-configuration.md  $K/installation/configuration.md
get k3s/installation-private-registry.md $K/installation/private-registry.md
get k3s/installation-uninstall.md      $K/installation/uninstall.md
get k3s/installation-packaged-components.md $K/installation/packaged-components.md
get k3s/datastore-ha-embedded.md       $K/datastore/ha-embedded.md
get k3s/datastore-backup-restore.md    $K/datastore/backup-restore.md
get k3s/cli-server.md                  $K/cli/server.md
get k3s/cli-agent.md                   $K/cli/agent.md
get k3s/cli-etcd-snapshot.md           $K/cli/etcd-snapshot.md
get k3s/cli-token.md                   $K/cli/token.md
get k3s/networking-basic-options.md    $K/networking/basic-network-options.md
get k3s/networking-services.md         $K/networking/networking-services.md
get k3s/upgrades-manual.md             $K/upgrades/manual.md
get k3s/upgrades-automated.md          $K/upgrades/automated.md
get k3s/cluster-access.md              $K/cluster-access.md
get k3s/add-ons-helm.md                $K/add-ons/helm.md
get k3s/advanced.md                    $K/advanced.md
get k3s/security-hardening-guide.md    $K/security/hardening-guide.md
get k3s/known-issues.md                $K/known-issues.md
get k3s/related-projects.md            $K/related-projects.md

# ---------------- Kubernetes (kubernetes/website main) ----------------
KW=$GH/kubernetes/website/main/content/en
get kubernetes/version-skew-policy.md          $KW/releases/version-skew-policy.md
get kubernetes/taint-and-toleration.md         $KW/docs/concepts/scheduling-eviction/taint-and-toleration.md
get kubernetes/assign-pod-node.md              $KW/docs/concepts/scheduling-eviction/assign-pod-node.md
get kubernetes/safely-drain-node.md            $KW/docs/tasks/administer-cluster/safely-drain-node.md
get kubernetes/configure-pdb.md                $KW/docs/tasks/run-application/configure-pdb.md
get kubernetes/storage-classes.md              $KW/docs/concepts/storage/storage-classes.md
get kubernetes/gateway.md                      $KW/docs/concepts/services-networking/gateway.md
get kubernetes/service.md                      $KW/docs/concepts/services-networking/service.md
get kubernetes/kubectl-wait.md                 $KW/docs/reference/kubectl/generated/kubectl_wait/_index.md
get kubernetes/kubectl-drain.md                $KW/docs/reference/kubectl/generated/kubectl_drain/_index.md
get kubernetes/kubectl-apply.md                $KW/docs/reference/kubectl/generated/kubectl_apply/_index.md
get kubernetes/server-side-apply.md            $KW/docs/reference/using-api/server-side-apply.md
get kubernetes/jsonpath.md                     $KW/docs/reference/kubectl/jsonpath.md
get kubernetes/admission-controllers.md        $KW/docs/reference/access-authn-authz/admission-controllers.md

# ---------------- Helm (helm/helm-www main) ----------------
H=$GH/helm/helm-www/main/docs
get helm/get-helm-3.sh          $GH/helm/helm/main/scripts/get-helm-3
get helm/install.mdx            $H/intro/install.mdx
get helm/using-helm.mdx         $H/intro/using_helm.mdx
get helm/helm_install.md        $H/helm/helm_install.md
get helm/helm_upgrade.md        $H/helm/helm_upgrade.md
get helm/helm_repo_add.md       $H/helm/helm_repo_add.md
get helm/helm_show_values.md    $H/helm/helm_show_values.md
get helm/values_files.mdx       $H/chart_template_guide/values_files.mdx
get helm/subcharts_and_globals.md $H/chart_template_guide/subcharts_and_globals.md

# ---------------- Keepalived (acassen/keepalived master) ----------------
KA=$GH/acassen/keepalived/master
get keepalived/keepalived.conf.5.man     $KA/doc/man/man5/keepalived.conf.5.in
get keepalived/sample-keepalived.conf.vrrp.scripts $KA/doc/samples/keepalived.conf.vrrp.scripts
get keepalived/sample-keepalived.conf.vrrp $KA/doc/samples/keepalived.conf.vrrp
get keepalived/sample-keepalived.conf.vrrp.localcheck $KA/doc/samples/keepalived.conf.vrrp.localcheck

# ---------------- MetalLB (chart 0.16.1 -> metallb v0.16.1) ----------------
M=$GH/metallb/metallb
get metallb/values-0.16.1.yaml     $M/v0.16.1/charts/metallb/values.yaml
get metallb/configuration.md       $M/main/website/content/configuration/_index.md
get metallb/installation.md        $M/main/website/content/installation/_index.md
get metallb/concepts-layer2.md     $M/main/website/content/concepts/layer2.md
get metallb/usage.md               $M/main/website/content/usage/_index.md
get metallb/troubleshooting.md     $M/main/website/content/troubleshooting/_index.md

# ---------------- cert-manager (chart v1.21.1) ----------------
C=$GH/cert-manager
get cert-manager/values-v1.21.1.yaml   $C/cert-manager/v1.21.1/deploy/charts/cert-manager/values.yaml
get cert-manager/installation-helm.md  $C/website/master/content/docs/installation/helm.md
get cert-manager/configuration-selfsigned.md $C/website/master/content/docs/configuration/selfsigned.md
get cert-manager/configuration-ca.md   $C/website/master/content/docs/configuration/ca.md
get cert-manager/usage-certificate.md  $C/website/master/content/docs/usage/certificate.md
get cert-manager/usage-gateway.md      $C/website/master/content/docs/usage/gateway.md
get cert-manager/troubleshooting.md    $C/website/master/content/docs/troubleshooting/README.md

# ---------------- kube-prometheus-stack (chart 88.3.0) ----------------
P=$GH/prometheus-community/helm-charts/kube-prometheus-stack-88.3.0/charts/kube-prometheus-stack
get kube-prometheus-stack/README-88.3.0.md   $P/README.md
get kube-prometheus-stack/values-88.3.0.yaml $P/values.yaml
get kube-prometheus-stack/grafana-subchart-values.yaml $GH/grafana-community/helm-charts/main/charts/grafana/values.yaml

# ---------------- ArgoCD (chart 10.3.3 -> ArgoCD v3.5.1) ----------------
A=$GH/argoproj
get argocd/chart-README-10.3.3.md    $A/argo-helm/argo-cd-10.3.3/charts/argo-cd/README.md
get argocd/values-10.3.3.yaml        $A/argo-helm/argo-cd-10.3.3/charts/argo-cd/values.yaml
get argocd/operator-ingress.md       $A/argo-cd/v3.5.1/docs/operator-manual/ingress.md
get argocd/operator-high-availability.md $A/argo-cd/v3.5.1/docs/operator-manual/high_availability.md
get argocd/operator-installation.md  $A/argo-cd/v3.5.1/docs/operator-manual/installation.md
get argocd/getting-started.md        $A/argo-cd/v3.5.1/docs/getting_started.md

# ---------------- Rancher (rancher/rancher-docs main) ----------------
R=$GH/rancher/rancher-docs/main/docs
get rancher/installation-requirements.md   $R/getting-started/installation-and-upgrade/installation-requirements/installation-requirements.md
get rancher/install-on-kubernetes.md       $R/getting-started/installation-and-upgrade/install-upgrade-on-a-kubernetes-cluster/install-upgrade-on-a-kubernetes-cluster.md
get rancher/helm-chart-options.md          $R/getting-started/installation-and-upgrade/installation-references/helm-chart-options.md
get rancher/upgrades.md                    $R/getting-started/installation-and-upgrade/install-upgrade-on-a-kubernetes-cluster/upgrades.md

# ---------------- Gateway API (v1.5.1) ----------------
G=$GH/kubernetes-sigs/gateway-api/v1.5.1
get gateway-api/api-overview.md        $G/site-src/concepts/api-overview.md
get gateway-api/gatewayclass.md        $G/site-src/api-types/gatewayclass.md
get gateway-api/gateway.md             $G/site-src/api-types/gateway.md
get gateway-api/httproute.md           $G/site-src/api-types/httproute.md
get gateway-api/referencegrant.md      $G/site-src/api-types/referencegrant.md
get gateway-api/guide-http-routing.md  $G/site-src/guides/http-routing.md
get gateway-api/guide-tls.md           $G/site-src/guides/tls.md
get gateway-api/guide-http-redirect-rewrite.md $G/site-src/guides/http-redirect-rewrite.md
get gateway-api/standard-install-v1.5.1.yaml https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.5.1/standard-install.yaml

# ---------------- Traefik (v3.7 docs + helm chart) ----------------
T=$GH/traefik/traefik/v3.7/docs/content
get traefik/provider-kubernetes-gateway.md  $T/reference/install-configuration/providers/kubernetes/kubernetes-gateway.md
get traefik/routing-gateway-api.md          $T/reference/routing-configuration/kubernetes/gateway-api.md
get traefik/entrypoints.md                  $T/reference/install-configuration/entrypoints.md
get traefik/helm-chart-values.yaml          $GH/traefik/traefik-helm-chart/master/traefik/values.yaml
get traefik/helm-chart-README.md            $GH/traefik/traefik-helm-chart/master/README.md

# ---------------- system-upgrade-controller ----------------
S=$GH/rancher/system-upgrade-controller/master
get system-upgrade-controller/README.md            $S/README.md
get system-upgrade-controller/example-k3s-upgrade.yaml $S/examples/k3s-upgrade.yaml

# ---------------- chrony ----------------
get chrony/chrony.conf.adoc  https://gitlab.com/chrony/chrony/-/raw/master/doc/chrony.conf.adoc

# ---------------- Ansible (ansible/ansible-documentation devel) ----------------
AD=$GH/ansible/ansible-documentation/devel/docs/docsite/rst
get ansible/guide-variables.rst        $AD/playbook_guide/playbooks_variables.rst
get ansible/guide-conditionals.rst     $AD/playbook_guide/playbooks_conditionals.rst
get ansible/guide-loops.rst            $AD/playbook_guide/playbooks_loops.rst
get ansible/guide-strategies.rst       $AD/playbook_guide/playbooks_strategies.rst
get ansible/guide-delegation.rst       $AD/playbook_guide/playbooks_delegation.rst
get ansible/guide-blocks.rst           $AD/playbook_guide/playbooks_blocks.rst
get ansible/guide-error-handling.rst   $AD/playbook_guide/playbooks_error_handling.rst
get ansible/guide-tags.rst             $AD/playbook_guide/playbooks_tags.rst
get ansible/guide-reuse-roles.rst      $AD/playbook_guide/playbooks_reuse_roles.rst
get ansible/guide-filters.rst          $AD/playbook_guide/playbooks_filters.rst
get ansible/guide-tests.rst            $AD/playbook_guide/playbooks_tests.rst
get ansible/guide-privilege-escalation.rst $AD/playbook_guide/playbooks_privilege_escalation.rst
get ansible/guide-handlers.rst         $AD/playbook_guide/playbooks_handlers.rst
get ansible/vault.rst                  $AD/vault_guide/vault.rst
get ansible/inventory-intro.rst        $AD/inventory_guide/intro_inventory.rst
get ansible/playbooks-best-practices.rst $AD/tips_tricks/ansible_tips_tricks.rst

# ---------------- ansible-doc (yerel, kurulu surumle birebir) ----------------
mkdir -p ansible/modules
for m in ansible.builtin.command ansible.builtin.shell ansible.builtin.set_fact \
  ansible.builtin.debug ansible.builtin.template ansible.builtin.copy ansible.builtin.file \
  ansible.builtin.lineinfile ansible.builtin.replace ansible.builtin.systemd_service \
  ansible.builtin.service ansible.builtin.user ansible.builtin.reboot \
  ansible.builtin.wait_for ansible.builtin.wait_for_connection ansible.builtin.get_url \
  ansible.builtin.getent ansible.builtin.stat ansible.builtin.fail ansible.builtin.assert \
  ansible.builtin.pause ansible.builtin.package ansible.builtin.apt \
  ansible.builtin.dnf ansible.builtin.find ansible.builtin.hostname ansible.builtin.setup \
  ansible.builtin.include_role ansible.builtin.import_tasks ansible.builtin.include_tasks \
  ansible.builtin.import_role ansible.builtin.import_playbook ansible.builtin.uri \
  ansible.builtin.slurp ansible.builtin.include_vars \
  ansible.posix.firewalld ansible.posix.sysctl community.general.modprobe \
  kubernetes.core.helm kubernetes.core.helm_repository kubernetes.core.k8s \
  kubernetes.core.k8s_info kubernetes.core.k8s_drain; do
  if ansible-doc "$m" > "ansible/modules/$m.txt" 2>/dev/null; then printf 'ok   ansible/modules/%s.txt\n' "$m"
  else printf 'FAIL ansible/modules/%s.txt (ansible-doc)\n' "$m"; rm -f "ansible/modules/$m.txt"; fail=$((fail+1)); fi
done
ansible-doc -t callback ansible.posix.profile_tasks > ansible/modules/ansible.posix.profile_tasks.callback.txt 2>/dev/null && echo "ok   ansible/modules/ansible.posix.profile_tasks.callback.txt"
ansible-doc -t filter ansible.builtin.regex_replace > ansible/modules/ansible.builtin.regex_replace.filter.txt 2>/dev/null && echo "ok   ansible/modules/ansible.builtin.regex_replace.filter.txt"
ansible-doc -t test ansible.builtin.version > ansible/modules/ansible.builtin.version.test.txt 2>/dev/null && echo "ok   ansible/modules/ansible.builtin.version.test.txt"
ansible-config list > ansible/ansible-config-list.txt 2>/dev/null && echo "ok   ansible/ansible-config-list.txt"

echo "---- bitti: $fail hata ----"
exit $fail
