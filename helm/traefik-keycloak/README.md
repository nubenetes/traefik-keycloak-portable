# traefik-keycloak

![Chart](https://img.shields.io/badge/chart-0.1.0-0f1689)
![Traefik](https://img.shields.io/badge/Traefik-v3.7.6%20(41.0.2)-24a1c1)
![Platforms](https://img.shields.io/badge/platforms-OpenShift%20%7C%20RKE2%20%7C%20k3s%20%7C%20kubeadm%20%7C%20Tanzu-326ce5)
![Airgap](https://img.shields.io/badge/airgap-ready-2ea44f)

Umbrella Helm chart: the **official Traefik chart** (vendored, v41.0.2 =
Traefik v3.7.6) plus a **Keycloak-protected dashboard** (oauth2-proxy +
ForwardAuth, role-gated), portable across on-prem / airgapped Kubernetes
distributions through a small set of **feature flags**.

It replaces the previous OpenShift-only flow (raw manifests + a `helm/values`
file that no longer validated against chart 41.0.2). One chart, many platforms.

## TL;DR

```bash
# Pick your platform preset, fill in the 3 real values, install:
helm install traefik ./helm/traefik-keycloak -f sites/values-rke2.yaml \
  --set dashboard.host=traefik.apps.mycluster.com \
  --set dashboard.cookieDomain=.apps.mycluster.com \
  --set keycloak.issuerUrl=https://keycloak.apps.mycluster.com/realms/myrealm
```

Before it starts serving you still need, out-of-band: the TLS Secret
(`dashboard.tlsSecretName`), the oauth2-proxy Secret (unless `secret.mode=inline`),
a LoadBalancer provider, DNS, and the Keycloak client. See "Prerequisites".

## Platform presets (`sites/`)

| Preset | Platform | LB backend | Notes |
|---|---|---|---|
| `values-openshift.yaml` | OpenShift 4.x | MetalLB | Pod UID left null (SCC injects it); CA via OpenShift injector |
| `values-rke2.yaml` | Rancher RKE2 | MetalLB | Disable bundled ingress-nginx at cluster install |
| `values-k3s.yaml` | k3s | MetalLB | Install k3s with `--disable traefik` |
| `values-kubeadm.yaml` | vanilla kubeadm | MetalLB | Generic PSA-restricted profile |
| `values-tanzu-nsx.yaml` | Tanzu / TKG | NSX ALB (Avi) | VIP via AKO; annotations are environment-specific |
| `values-tanzu-kubevip.yaml` | Tanzu / TKG (bare-metal) | kube-vip | kube-vip in service mode |

A preset is only a small delta over `values.yaml`. Copy one and edit it, or layer
`--set` / a second `-f` on top.

## Feature flags

All flags live in [`values.yaml`](values.yaml) (fully commented). The important ones:

| Flag | Values | What it does |
|---|---|---|
| `platform` | `generic` `openshift` `rke2` `k3s` `kubeadm` | Distribution profile. Drives pod-security expectations, validated. |
| `loadBalancer.backend` | `metallb` `nsx-alb` `kube-vip` `generic` | Documents/validates the LB. Actual Service annotations go in `traefik.service.annotations` (set by the preset). |
| `image.registry` | `""` or a host | **Airgap** registry prefix for the oauth2-proxy image. Traefik's image mirror goes in `traefik.image.registry`. |
| `caTrust.mode` | `none` `openshift-injector` `configmap` `insecure` | How oauth2-proxy trusts the Keycloak TLS cert. |
| `secret.mode` | `external` `inline` | Reference a pre-created Secret (recommended) or render one from values (dev). |
| `dashboard.*`, `keycloak.*`, `oauth2Proxy.*` | — | Hostnames, OIDC issuer, role gate. |

### Why platform and LB are two separate flags

They are orthogonal: OpenShift can run MetalLB *or* another LB; Tanzu can use
NSX ALB *or* kube-vip. Any `platform` × `loadBalancer.backend` combination that
makes sense is allowed; the chart validates the few that don't.

## Fail-fast validation

`helm install`/`helm template` runs [`templates/_validate.tpl`](templates/_validate.tpl)
first and aborts with an actionable message on an impossible combination — you
never ship a broken deployment. Enforced rules:

- Enum checks on `platform`, `loadBalancer.backend`, `caTrust.mode`, `secret.mode`.
- `caTrust.mode=openshift-injector` ⇒ requires `platform=openshift` (the injector
  label is a no-op elsewhere).
- `platform=openshift` ⇒ `traefik.podSecurityContext.runAsUser` must be null
  (pinning a UID breaks restricted-v2).
- `platform≠openshift` ⇒ a non-root `runAsUser` must be set (nothing injects one).
- `secret.mode=inline` ⇒ `clientSecret` and `cookieSecret` must be set.
- `dashboard.host` and `keycloak.issuerUrl` must be non-empty.

Because of rule 4, **a bare `helm install` with no preset fails on purpose** — it
tells you to pick a `sites/` preset.

## Airgap

The chart is self-contained for disconnected clusters:

1. **Traefik chart is vendored** in `charts/traefik-41.0.2.tgz` — no pull from
   `traefik.github.io` at install or at every ArgoCD sync.
2. **Image registries are parameterized.** Point them at your internal mirror:
   ```bash
   --set image.registry=harbor.internal.example.com \
   --set traefik.image.registry=harbor.internal.example.com
   ```
   → `harbor.internal.example.com/oauth2-proxy/oauth2-proxy:v7.7.1` and the
   Traefik image from the same mirror. Mirror both images beforehand.

## The one Helm subtlety worth knowing

Helm cannot template a subchart's values, and a `-f` preset **cannot** null out
a subchart default (Helm deletes the key from your overrides and the subchart
re-inherits its own default). So the Traefik chart's built-in `runAsUser: 65532`
is deleted by an explicit `null` in **this chart's** `values.yaml`, and the
non-OpenShift presets *add back* an explicit `65532`. That is why the UID lives
where it does; see the comments in `values.yaml`. Everything this chart renders
itself (oauth2-proxy, routes, CA trust) is driven normally by the flags.

## Prerequisites (unchanged from the manual flow)

- A LoadBalancer provider (MetalLB / NSX ALB / kube-vip …) with an address pool.
- TLS Secret `dashboard.tlsSecretName` in the release namespace (Traefik
  terminates TLS). See `../../docs/tls-secret.md`.
- oauth2-proxy Secret (`secret.mode=external`) with `OAUTH2_PROXY_CLIENT_ID`,
  `_CLIENT_SECRET`, `_COOKIE_SECRET`. See `../../secrets/` and
  `../../keycloak/keycloak-client-setup.md`.
- Keycloak confidential client + client role `traefik-admin`.
- DNS A record for `dashboard.host` → the LoadBalancer IP.
