{{/*
=============================================================================
Fail-fast validation of feature-flag combinations.
Rendered (and thus enforced) via templates/_validate-run.yaml, which is what
actually invokes this at `helm template` / `helm install` time.
Each check calls `fail` with an actionable message.
=============================================================================
*/}}
{{- define "tk.validate" -}}

{{- $platforms := list "generic" "openshift" "rke2" "k3s" "kubeadm" -}}
{{- if not (has .Values.platform $platforms) -}}
  {{- fail (printf "platform=%q is invalid. Choose one of: %s" .Values.platform (join ", " $platforms)) -}}
{{- end -}}

{{- $backends := list "metallb" "nsx-alb" "kube-vip" "cilium" "generic" -}}
{{- if not (has .Values.loadBalancer.backend $backends) -}}
  {{- fail (printf "loadBalancer.backend=%q is invalid. Choose one of: %s" .Values.loadBalancer.backend (join ", " $backends)) -}}
{{- end -}}

{{- $caModes := list "none" "openshift-injector" "configmap" "insecure" -}}
{{- if not (has .Values.caTrust.mode $caModes) -}}
  {{- fail (printf "caTrust.mode=%q is invalid. Choose one of: %s" .Values.caTrust.mode (join ", " $caModes)) -}}
{{- end -}}

{{- $secretModes := list "external" "inline" "external-secrets" -}}
{{- if not (has .Values.secret.mode $secretModes) -}}
  {{- fail (printf "secret.mode=%q is invalid. Choose one of: %s" .Values.secret.mode (join ", " $secretModes)) -}}
{{- end -}}

{{/* --- Cross-axis rules ---------------------------------------------------- */}}

{{/* 1. The OpenShift CA injector label only works on OpenShift. */}}
{{- if and (eq .Values.caTrust.mode "openshift-injector") (ne .Values.platform "openshift") -}}
  {{- fail (printf "caTrust.mode=openshift-injector requires platform=openshift (got platform=%q). Use caTrust.mode=configmap on other distributions." .Values.platform) -}}
{{- end -}}

{{/* runAsUser is "unset" when it is null/absent (kind "invalid"). Any numeric
     kind (int/int64/float64, from YAML or --set) counts as "pinned". */}}
{{- $uid := (.Values.traefik.podSecurityContext).runAsUser -}}
{{- $uidPinned := not (kindIs "invalid" $uid) -}}

{{/* 2. OpenShift must NOT pin the Traefik pod UID (SCC injects it). */}}
{{- if and (eq .Values.platform "openshift") $uidPinned -}}
  {{- fail (printf "platform=openshift but traefik.podSecurityContext.runAsUser is pinned to %v. OpenShift's restricted-v2 SCC assigns a per-namespace UID; leave runAsUser and runAsGroup null (see sites/values-openshift.yaml)." $uid) -}}
{{- end -}}

{{/* 3. Non-OpenShift with a null UID + runAsNonRoot has no UID source -> pod is
      blocked or runs as the image user. Require an explicit non-root UID. */}}
{{- if and (ne .Values.platform "openshift") (not $uidPinned) -}}
  {{- fail (printf "platform=%q requires an explicit non-root traefik.podSecurityContext.runAsUser (e.g. 65532). Only OpenShift injects one automatically. Install with a sites/ preset." .Values.platform) -}}
{{- end -}}

{{/* 4. inline secret mode needs the actual secret material. */}}
{{- if eq .Values.secret.mode "inline" -}}
  {{- if or (empty .Values.secret.clientSecret) (empty .Values.secret.cookieSecret) -}}
    {{- fail "secret.mode=inline requires both secret.clientSecret and secret.cookieSecret to be set." -}}
  {{- end -}}
{{- end -}}

{{/* 4b. external-secrets mode needs a store to read from. */}}
{{- if eq .Values.secret.mode "external-secrets" -}}
  {{- $es := .Values.secret.externalSecrets -}}
  {{- if and $es.createStore (empty (($es.vault).server)) -}}
    {{- fail "secret.mode=external-secrets with createStore=true requires secret.externalSecrets.vault.server (the Vault address)." -}}
  {{- end -}}
  {{- if empty (($es.storeRef).name) -}}
    {{- fail "secret.mode=external-secrets requires secret.externalSecrets.storeRef.name." -}}
  {{- end -}}
{{- end -}}

{{/* 5. configmap CA trust needs either an inline bundle or a pre-created ConfigMap name. */}}
{{- if and (eq .Values.caTrust.mode "configmap") (empty .Values.caTrust.configMapName) -}}
  {{- fail "caTrust.mode=configmap requires caTrust.configMapName (the ConfigMap to mount; the chart creates it if caTrust.bundle is set, otherwise it must already exist)." -}}
{{- end -}}

{{/* 6. Required user-facing values must be filled in. */}}
{{- if empty .Values.dashboard.host -}}
  {{- fail "dashboard.host is required (the public FQDN of the Traefik dashboard)." -}}
{{- end -}}
{{- if empty .Values.keycloak.issuerUrl -}}
  {{- fail "keycloak.issuerUrl is required (the OIDC issuer URL)." -}}
{{- end -}}

{{- end -}}
