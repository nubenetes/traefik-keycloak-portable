# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

> ⚠️ This project is **AI-generated and has not been tested or validated on a
> live Kubernetes cluster**. Validation so far is limited to `helm lint`,
> `helm template`, `kubeconform` (offline schema checks) and mermaid parsing.

## [Unreleased]

## [0.1.0] - 2026-07-17

Initial release — the multi-distribution sibling of
`traefik-keycloak-openshift-gitops`.

### Added
- **Umbrella Helm chart `traefik-keycloak`**: the official Traefik chart
  (**vendored** as `charts/traefik-41.0.2.tgz` = Traefik `v3.7.6`) plus an
  oauth2-proxy + ForwardAuth dashboard protected by Keycloak and gated on the
  `traefik-admin` role.
- **Feature flags** with fail-fast validation of impossible combinations:
  - `platform`: `openshift` / `rke2` / `k3s` / `kubeadm` / `generic`.
  - `loadBalancer.backend`: `metallb` / `nsx-alb` / `kube-vip` / `cilium` / `generic`.
  - `caTrust.mode`: `none` / `openshift-injector` / `configmap` / `insecure`.
  - `secret.mode`: `external` / `inline` / `external-secrets`.
  - `image.registry` (air-gap registry prefix) and `networkPolicy.enabled`.
- **Platform presets** under `sites/`: openshift, rke2, k3s, kubeadm, tanzu-nsx,
  tanzu-kubevip.
- **Air-gapped support**: vendored Traefik chart (no `traefik.github.io` pull) and
  `image.registry` / `traefik.image.registry` overrides for an internal mirror.
- **External Secrets Operator integration** (`secret.mode=external-secrets`):
  chart-templated `SecretStore` + `ExternalSecret` for HashiCorp Vault
  (Kubernetes auth) — no secret material in git.
- **Optional NetworkPolicies** (`networkPolicy.enabled`) for default-deny CNIs.
- **GitOps**: a single multi-source ArgoCD Application + dedicated AppProject.
- **Documentation** (English) with a full README, `PORTABILITY.md`, chart README
  and `docs/` (`tls-secret.md`, `air-gapped.md`, `external-secrets.md`,
  `network-policies.md`), including 8 collapsible, parser-validated Mermaid
  diagrams. Answers the CNI/CSI question (CSI N/A — stateless; CNI only via
  NetworkPolicy). The architecture diagram is a **full delivery + runtime view**
  (all components, all LB backends, ESO/Vault, air-gap mirror, GitOps) with a
  colour **legend**.
- **CI** (`.github/workflows/ci.yml`): `helm lint` + `helm template`/`kubeconform`
  for every preset, optional-feature render, validation-rule checks, `yamllint`,
  `shellcheck`, and mermaid parsing (`scripts/validate-mermaid.mjs`).
- **Governance**: MIT `LICENSE`, `.gitattributes` (LF), `.yamllint.yml`, README
  badges, repository topics and About description.

### Notes
- **Not tested or validated on a live cluster.** All checks are offline
  (`helm lint`/`template`, `kubeconform`, mermaid parsing).

[Unreleased]: https://github.com/nubenetes/traefik-keycloak-portable/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/nubenetes/traefik-keycloak-portable/releases/tag/v0.1.0
