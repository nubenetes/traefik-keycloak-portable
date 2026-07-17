#!/usr/bin/env bash
# =============================================================================
# Imperative deploy of Traefik + Keycloak-protected dashboard (no ArgoCD).
# Portable across Kubernetes distributions via the traefik-keycloak umbrella
# chart and a platform preset from sites/.
#
# Usage:
#   ./install.sh <platform> [extra helm args...]
#
#   <platform> is one of: openshift rke2 k3s kubeadm tanzu-nsx tanzu-kubevip
#              (matches a file sites/values-<platform>.yaml)
#
# Example:
#   ./install.sh rke2 \
#     --set dashboard.host=traefik.apps.mycluster.com \
#     --set dashboard.cookieDomain=.apps.mycluster.com \
#     --set keycloak.issuerUrl=https://keycloak.apps.mycluster.com/realms/myrealm
#
# Prerequisites still done out-of-band (see helm/traefik-keycloak/README.md):
#   - LoadBalancer provider + address pool
#   - TLS Secret (dashboard.tlsSecretName) in the namespace
#   - oauth2-proxy Secret (unless you pass --set secret.mode=inline ...)
#   - Keycloak client + traefik-admin role
# =============================================================================
set -euo pipefail

NS="${NS:-traefik}"
CHART_DIR="$(cd "$(dirname "$0")" && pwd)/helm/traefik-keycloak"
RELEASE="${RELEASE:-traefik}"

PLATFORM="${1:-}"
if [[ -z "$PLATFORM" ]]; then
  echo "ERROR: platform required. Usage: ./install.sh <platform> [helm args...]" >&2
  echo "       platforms: openshift rke2 k3s kubeadm tanzu-nsx tanzu-kubevip" >&2
  exit 1
fi
shift || true

PRESET="$(dirname "$0")/sites/values-${PLATFORM}.yaml"
if [[ ! -f "$PRESET" ]]; then
  echo "ERROR: preset not found: $PRESET" >&2
  exit 1
fi

# kubectl works on every distro; on OpenShift `oc` is a superset and also works.
KUBECTL="${KUBECTL:-kubectl}"

echo ">> 1. Namespace + PodSecurity 'restricted' label"
"$KUBECTL" create namespace "$NS" --dry-run=client -o yaml | "$KUBECTL" apply -f -
"$KUBECTL" label namespace "$NS" \
  pod-security.kubernetes.io/enforce=restricted --overwrite

echo ">> 2. Deploy the umbrella chart with the ${PLATFORM} preset"
echo "      (Traefik chart is vendored in charts/ — no internet pull)"
helm upgrade --install "$RELEASE" "$CHART_DIR" \
  -n "$NS" \
  -f "$PRESET" \
  "$@"

echo ">> 3. LoadBalancer address assigned to the traefik Service:"
"$KUBECTL" get svc -n "$NS" -l app.kubernetes.io/name=traefik -o wide || \
  "$KUBECTL" get svc -n "$NS"

echo ">> Done. Point DNS for your dashboard host at that IP, then open"
echo "   https://<dashboard.host>/dashboard/"
