# GitOps deployment with ArgoCD

Declarative deployment of the `traefik-keycloak` umbrella chart with ArgoCD.
Works with OpenShift GitOps and vanilla ArgoCD alike. (The imperative
`install.sh <platform>` at the repo root is the non-GitOps alternative.)

```
argocd/project.yaml               AppProject 'traefik' (bounds repos/destination/resources)
argocd/apps/traefik-keycloak.yaml Application → vendored umbrella chart + a sites/ preset
```

One Application, one chart. The Traefik chart is vendored inside the umbrella
(`helm/traefik-keycloak/charts/traefik-41.0.2.tgz`), so ArgoCD pulls nothing from
`traefik.github.io` at sync time — this is airgap-ready. The Application is
multi-source: it feeds the platform preset (`sites/values-<platform>.yaml`) to
the chart via the `$values` ref.

## 0. Prerequisites

- **ArgoCD ≥ 2.6** (OpenShift GitOps ≥ 1.8) — required for multi-source and
  `managedNamespaceMetadata`. Namespace: `openshift-gitops` on OpenShift GitOps,
  usually `argocd` on vanilla ArgoCD.
- The ArgoCD instance allowed to deploy into the `traefik` namespace.
- Your code in a git repo ArgoCD can reach.

## 1. Fill in the placeholders

In the **2** files under `argocd/`, replace:

| Placeholder | With |
|---|---|
| `https://github.com/CHANGEME/traefik-keycloak.git` | **Your** git repo URL |
| `targetRevision: main` | Your branch or tag |
| `namespace: argocd` (metadata) | Your ArgoCD namespace (e.g. `openshift-gitops`) |

Then pick your platform preset in `argocd/apps/traefik-keycloak.yaml`
(`valueFiles: [$values/sites/values-<platform>.yaml]`) and set the real values
(`dashboard.host`, `dashboard.cookieDomain`, `keycloak.issuerUrl`) — either via
the commented `helm.parameters` block or by editing a committed copy of the preset.

Quick sweep (Git Bash / Linux / macOS):

```bash
ARGO_NS=openshift-gitops           # or 'argocd'
REPO=https://github.com/your-org/your-repo.git
grep -rl 'CHANGEME' argocd/ | xargs sed -i "s#https://github.com/CHANGEME/traefik-keycloak.git#$REPO#g"
sed -i "s/^  namespace: argocd .*/  namespace: $ARGO_NS/" argocd/apps/*.yaml argocd/project.yaml
```

## 2. Create the secrets (out-of-band, once)

ArgoCD does **not** manage the secrets (they are not in git). Create them by hand
(`kubectl` works everywhere; on OpenShift `oc` also works):

```bash
kubectl create namespace traefik   # if it does not exist yet

# oauth2-proxy (Keycloak client secret + cookie secret)
cp secrets/oauth2-proxy-secret.example.yaml secrets/oauth2-proxy-secret.yaml
# edit the real values, then:
kubectl apply -f secrets/oauth2-proxy-secret.yaml

# dashboard TLS (see docs/tls-secret.md; declarative with cert-manager)
kubectl create secret tls traefik-dashboard-tls -n traefik --cert=tls.crt --key=tls.key
```

> Alternatively set `secret.mode=inline` in the chart to have it render the
> oauth2-proxy Secret from values (dev only; keep the values out of public git).

## 3. Bootstrap (once)

```bash
# 1) Dedicated AppProject (must exist BEFORE the Application that uses it)
kubectl apply -n openshift-gitops -f argocd/project.yaml       # adjust the namespace
# 2) The Application
kubectl apply -n openshift-gitops -f argocd/apps/traefik-keycloak.yaml
```

Follow progress in the ArgoCD UI or CLI:

```bash
argocd app get traefik-keycloak
```

## 4. Operations

- **Everything goes through git**: edit the preset in `sites/…` (or the
  Application), commit and push — ArgoCD reconciles (auto-sync + self-heal on).
- **Bump the Traefik version**: replace the vendored chart in
  `helm/traefik-keycloak/charts/` (`helm pull traefik/traefik --version <X.Y.Z>`),
  update `dependencies.version` in `Chart.yaml`, commit and push. Keep Traefik
  **≥ v3.4** (the errors-middleware `statusRewrites` requirement).
- **Update secrets**: reapply the Secret and restart oauth2-proxy
  (`kubectl rollout restart deploy/oauth2-proxy -n traefik`) — changing a Secret
  does not restart the pod on its own.
- **Uninstall**: delete the Application; the finalizer cascades to its resources:
  `kubectl delete -n openshift-gitops application/traefik-keycloak`. Then clean up
  the external bits (secrets, DNS, Keycloak client, Traefik CRDs).

## Notes

- `ServerSideApply=true` avoids the *"metadata.annotations: Too long"* error on
  Traefik's large CRDs.
- The namespace is created and labelled
  (`pod-security.kubernetes.io/enforce: restricted`) via
  `managedNamespaceMetadata` — no standalone Namespace manifest.
- The Application uses the dedicated **AppProject `traefik`**
  (`argocd/project.yaml`): it bounds `sourceRepos` (just this repo, since the
  chart is vendored), `destinations` (only the `traefik` namespace), and the
  allowed cluster-scoped resources.
- **Secret in git (optional):** instead of the out-of-band apply, seal it with
  `kubeseal` (Sealed Secrets) or use External Secrets, and reference it with
  `secret.mode=external` (the default).
