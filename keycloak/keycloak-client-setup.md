# Keycloak client setup

Create a **confidential** client in the realm you use for the dashboard.

## 1. Create the client

Admin Console → *Clients* → **Create client**

| Field | Value |
|---|---|
| Client type | **OpenID Connect** |
| Client ID | `traefik-dashboard` |
| Name | Traefik Dashboard |

**Capability config:**

| Option | Value |
|---|---|
| Client authentication | **On** (confidential) |
| Authorization | Off |
| Standard flow | **On** |
| Direct access grants | Off (not needed) |

## 2. Redirect URLs

In the client's *Settings* (dummy host `traefik.apps.example.com`, replace it):

| Field | Value |
|---|---|
| Valid redirect URIs | `https://traefik.apps.example.com/oauth2/callback` |
| Valid post logout redirect URIs | `https://traefik.apps.example.com/*` |
| Web origins | `https://traefik.apps.example.com` |

## 3. Copy the secret

*Credentials* → copy the **Client secret**.
It goes into `secrets/oauth2-proxy-secret.yaml` → `OAUTH2_PROXY_CLIENT_SECRET`.

## 4. Restrict access by role (ENABLED in this deployment)

The chart sets `oauth2Proxy.allowedRoles=traefik-dashboard:traefik-admin`, so
**only** users with that role reach the dashboard. You must create it:

1. *Clients → traefik-dashboard → Roles* → **Create role**: `traefik-admin`.
2. *Users → (user) → Role mapping* → **Assign role** → `traefik-admin`.
3. oauth2-proxy's `keycloak-oidc` provider already reads the token roles
   (`resource_access.<client>.roles` and `realm_access.roles`); you need no extra
   mappers for client roles.

> ⚠️ If you assign the role to no one, **nobody** can get in (you will see a 403
> after login). For a **realm** role instead of a client role, set the chart value
> `oauth2Proxy.allowedRoles` to just `traefik-admin`.

## 5. Issuer

- Keycloak 17+ (Quarkus): `https://keycloak.apps.example.com/realms/myrealm`
- Legacy Keycloak (WildFly, with `/auth`): `https://keycloak.apps.example.com/auth/realms/myrealm`

Verify the real issuer by opening:
`https://keycloak.apps.example.com/realms/myrealm/.well-known/openid-configuration`
