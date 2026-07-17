{{/*
Common helpers for the traefik-keycloak umbrella chart.
*/}}

{{/* Fully qualified oauth2-proxy image, honouring the airgap registry prefix. */}}
{{- define "tk.oauth2ProxyImage" -}}
{{- $reg := .Values.image.registry | default .Values.oauth2Proxy.image.defaultRegistry -}}
{{- printf "%s/%s:%s" $reg .Values.oauth2Proxy.image.repository .Values.oauth2Proxy.image.tag -}}
{{- end -}}

{{/* Standard labels for resources owned by this chart. */}}
{{- define "tk.labels" -}}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: traefik-keycloak
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" }}
{{- end -}}

{{/* True when oauth2-proxy must mount a CA bundle (configmap or openshift-injector). */}}
{{- define "tk.caTrust.mounts" -}}
{{- or (eq .Values.caTrust.mode "configmap") (eq .Values.caTrust.mode "openshift-injector") -}}
{{- end -}}
