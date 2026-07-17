# Dashboard TLS certificate (`traefik-dashboard-tls`)

**Traefik terminates TLS** (there is no OpenShift Route in front), so it needs a
`kubernetes.io/tls` Secret with the certificate for your dashboard host
(`dashboard.host`, e.g. `traefik.apps.example.com`).

It is managed **out-of-band** (not by ArgoCD) — like the oauth2-proxy Secret.
With **cert-manager** (option A) it becomes declarative: the `Certificate` can
live in git and cert-manager creates the Secret for you.

The Secret name must match `dashboard.tlsSecretName` in the chart values
(default `traefik-dashboard-tls`).

## Option A — cert-manager (recommended, GitOps-friendly)

If you have cert-manager + a ClusterIssuer, apply this `Certificate` (commit it to
git so ArgoCD / your pipeline manages it):

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: traefik-dashboard-tls
  namespace: traefik
spec:
  secretName: traefik-dashboard-tls
  dnsNames:
    - traefik.apps.example.com
  issuerRef:
    name: YOUR_CLUSTERISSUER
    kind: ClusterIssuer
```

## Option B — existing certificate (out-of-band)

```bash
kubectl create secret tls traefik-dashboard-tls \
  -n traefik \
  --cert=tls.crt --key=tls.key
```

## Option C — self-signed (testing only)

```bash
openssl req -x509 -newkey rsa:2048 -nodes -days 365 \
  -keyout tls.key -out tls.crt -subj "/CN=traefik.apps.example.com"
kubectl create secret tls traefik-dashboard-tls -n traefik --cert=tls.crt --key=tls.key
```

> The browser will warn about the self-signed cert; the OIDC flow still works.
