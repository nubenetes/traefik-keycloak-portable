# Air-gapped / disconnected deployment

In a disconnected cluster nothing may reach the public internet, so two things
must resolve locally: the **Traefik Helm chart** and the **container images**.
This chart handles both.

## 1. The Traefik chart is vendored (no chart pull)

The official Traefik chart is committed inside the umbrella as
`helm/traefik-keycloak/charts/traefik-41.0.2.tgz`. Helm reads it from `charts/`,
so neither `helm install` nor an ArgoCD sync ever contacts
`traefik.github.io`. The ArgoCD Application points at the chart **path in git**,
not at a remote Helm repo (see [`../argocd/README.md`](../argocd/README.md)).

Nothing to do here — it works air-gapped out of the box. To change the pinned
version, replace the `.tgz` and update `dependencies.version` in
`helm/traefik-keycloak/Chart.yaml` (see the repo README §11).

## 2. Point images at your internal mirror

Two images are used:

| Image | Default | Value to override |
|---|---|---|
| oauth2-proxy | `quay.io/oauth2-proxy/oauth2-proxy:v7.7.1` | `image.registry` |
| Traefik | `docker.io/traefik:v3.7.6` | `traefik.image.registry` |

Mirror both into your registry first, then:

```bash
helm upgrade --install traefik ./helm/traefik-keycloak -n traefik \
  -f sites/values-<platform>.yaml \
  --set image.registry=harbor.internal.example.com \
  --set traefik.image.registry=harbor.internal.example.com
```

renders:

```
harbor.internal.example.com/oauth2-proxy/oauth2-proxy:v7.7.1
harbor.internal.example.com/traefik:v3.7.6
```

Under GitOps, set the same two values in `argocd/apps/traefik-keycloak.yaml`
(`helm.parameters`) or in a committed copy of the preset.

### Mirroring the images (example)

```bash
# On a connected host, then transfer / push into the disconnected registry:
skopeo copy docker://quay.io/oauth2-proxy/oauth2-proxy:v7.7.1 \
  docker://harbor.internal.example.com/oauth2-proxy/oauth2-proxy:v7.7.1
skopeo copy docker://docker.io/traefik:v3.7.6 \
  docker://harbor.internal.example.com/traefik:v3.7.6
```

## 3. OpenShift alternative: cluster-wide mirror (no per-value override)

On OpenShift you can redirect images cluster-wide with an
`ImageDigestMirrorSet`/`ImageTagMirrorSet` instead of setting the registry in
values. Then keep the upstream references in the chart and let the cluster
rewrite them. This is the approach used by the OpenShift-only sibling repo; it is
optional here and orthogonal to the `image.registry` flags above — use whichever
your platform team standardises on.

## 4. Pull secrets

If your mirror needs authentication, create an image pull Secret in the `traefik`
namespace and attach it to the ServiceAccounts (or set it cluster-wide). This
chart does not manage pull secrets; add them the way your platform expects.

## Checklist

- [ ] `oauth2-proxy:v7.7.1` mirrored into the internal registry.
- [ ] `traefik:v3.7.6` mirrored into the internal registry.
- [ ] `image.registry` and `traefik.image.registry` set to the mirror.
- [ ] Pull secret in place if the mirror is authenticated.
- [ ] `helm template` rendered offline and reviewed before applying.
