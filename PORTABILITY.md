# Portability notes — how this repo relates to the OpenShift-only sibling

This repo is the **multi-distribution** version of
[`traefik-keycloak-openshift-gitops`](https://github.com/nubenetes/traefik-keycloak-openshift-gitops).
Same core (Traefik + oauth2-proxy + Keycloak-protected dashboard), generalised
from OpenShift-only to **OpenShift, RKE2, k3s, kubeadm and VMware Tanzu/TKG**
through an umbrella Helm chart with feature-flag presets.

For architecture, the orthogonal-axes model, the platform × load-balancer matrix,
the preset summary and the flag reference, see the **[README](README.md)** (§2–§4,
§9). This file only records *why the design differs* and the *bugs it fixes*.

## Design differences vs the OpenShift-only sibling

| Aspect | OpenShift-only sibling | This repo |
|---|---|---|
| Packaging | Single `helm/values-traefik.yaml` + raw `manifests/` (Kustomize) | Umbrella Helm chart with the Traefik chart as a dependency |
| Platform coupling | OpenShift SCC / Routes / `oc` assumptions | `platform` flag; `kubectl`; validated per distro |
| Load balancer | MetalLB | `loadBalancer.backend`: metallb / nsx-alb / kube-vip / cilium / generic |
| CA trust | OpenShift trusted-CA injector | `caTrust.mode`: none / openshift-injector / configmap / insecure |
| Secrets backend | ESO + Vault as raw `manifests/vault/` | `secret.mode`: external / inline / **external-secrets** (ESO + Vault, chart-templated) |
| NetworkPolicy | — (none) | Optional `networkPolicy.enabled` for default-deny CNIs |
| Airgap (chart) | Chart pulled from `traefik.github.io` | Chart **vendored** in `charts/*.tgz` |
| Airgap (images) | OpenShift `ImageDigestMirrorSet` (cluster-wide) | `image.registry` / `traefik.image.registry` value overrides (works anywhere) |
| ArgoCD | App-of-Apps (two child Applications) | Single multi-source Application |

Both approaches are valid; the sibling is deliberately OpenShift-tuned, this one
trades some OpenShift-nativeness for cross-distribution reach.

## Two bugs in the OpenShift-only design (fixed here)

While generalising the code, two defects surfaced that also exist in the sibling
repo (tracked there separately):

1. **The values did not validate against the pinned chart (41.0.2).** The old
   `helm/values-traefik.yaml` used keys from an earlier chart generation, so
   `helm install` aborted with a schema error:
   - `logs.general.level` / `logs.access.enabled` → `log.level` + `accessLog.enabled`
   - `ports.web.redirectTo` → `ports.web.http.redirections.entryPoint`
   - `ports.websecure.tls` → `ports.websecure.http.tls`

   This chart carries the corrected schema (and enables access logging via
   `accessLog.enabled`, since an empty `accessLog` map leaves it off).

2. **The pod UID was pinned despite claims to the contrary.** Chart 41.0.2
   defaults `podSecurityContext.runAsUser`/`runAsGroup` to **65532**, and Helm's
   deep-merge keeps them unless deleted. So the Traefik pod shipped UID 65532 and
   OpenShift's `restricted-v2` SCC would reject it. This chart deletes the default
   with an explicit `null` in `values.yaml`, and each non-OpenShift preset adds
   back a valid non-root UID.

   > Subtlety: a `-f` preset **cannot** inject a subchart-level `null` (Helm
   > deletes the key from the overrides and the subchart re-inherits its own
   > default). Only an explicit `null` in this chart's `values.yaml` survives the
   > subchart coalesce — which is why the UID default lives there and the presets
   > add UIDs rather than the reverse. See the comment in
   > [`values.yaml`](helm/traefik-keycloak/values.yaml).

## Still applies from the shared design

The Keycloak client setup (`keycloak/`), TLS guidance (`docs/tls-secret.md`),
secret template (`secrets/`) and the MetalLB example (`metallb/`) carry over
unchanged.
