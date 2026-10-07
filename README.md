# mossyleaf accounts

Single sign-on for the mossyleaf apps at **https://accounts.mossyleaf.studio**: a self-hosted [Authentik](https://goauthentik.io) **2026.8.3** where MossyDew and MossyTrunk are OpenID Connect clients. One account per person, one group per app, no public sign-up.

Everything is configuration: Authentik runs from its official image and the blueprints in `blueprints/` declare the groups, OIDC providers, applications, access bindings, flows and brand, so a fresh install is ready on its first start.

| Path | What |
|---|---|
| `compose.yaml` | Local stack: Authentik server (http://localhost:9000) + worker, PostgreSQL 18, Mailpit (http://localhost:8027) |
| `blueprints/mossyleaf-accounts.yaml` | Sign-in, recovery and password-change flows, invitation email, password policy, brand |
| `blueprints/mossyleaf-apps.yaml` | Groups `mossydew` / `mossytrunk`, their OIDC providers and applications, group bindings, `zoneinfo` claim |
| `branding/` | Logo, favicon, background, `branding.css` (the brand's custom CSS) and self-hosted fonts, served at `/static/dist/custom/` |
| `templates/email/` | Invitation and password-reset emails (HTML + text, French or English from the user's locale) |
| `scripts/invite.py` | Creates or updates a user, adds groups and emails the invitation (run by `make invite`) |
| `deploy/` | Server compose file, `.env.dist` and the [server README](deploy/README.md) |

## Local use

```bash
make up                 # http://localhost:9000, admin: akadmin / admin-password
make invite EMAIL=ada@example.com NAME="Ada Lovelace" GROUPS="mossydew mossytrunk"
open http://localhost:8027   # Mailpit: the invitation link
make apply              # reapply the blueprints now (needed after editing branding/branding.css)
make shots              # sign-in page screenshots (phone + desktop) into shots/
make logs / make down
```

The worker reapplies a blueprint whenever its YAML changes; `branding.css` is read by the brand blueprint (`!File`), so a CSS-only change needs `make apply`.

Local client secrets: `mossydew-local-secret` and `mossytrunk-local-secret` (override with `MOSSYDEW_CLIENT_SECRET` / `MOSSYTRUNK_CLIENT_SECRET` in a root `.env`).

## Contract with the apps

| | MossyDew | MossyTrunk |
|---|---|---|
| `client_id` | `mossydew` | `mossytrunk` |
| `client_secret` | `MOSSYDEW_CLIENT_SECRET` | `MOSSYTRUNK_CLIENT_SECRET` |
| Redirect URIs (strict) | `https://mossydew.mossyleaf.studio/login/check`, `http://localhost:8090/login/check` | `https://mossytrunk.mossyleaf.studio/login/check`, `http://localhost:8080/login/check` |
| Post-logout redirect URIs (strict) | `https://mossydew.mossyleaf.studio/`, `http://localhost:8090/` | `https://mossytrunk.mossyleaf.studio/`, `http://localhost:8080/` |
| Group allowed to sign in | `mossydew` | `mossytrunk` |

Endpoints (`<slug>` = `mossydew` or `mossytrunk`; locally `http://localhost:9000` instead of the host):

- Discovery: `https://accounts.mossyleaf.studio/application/o/<slug>/.well-known/openid-configuration`
- Issuer: `https://accounts.mossyleaf.studio/application/o/<slug>/`
- Authorize: `https://accounts.mossyleaf.studio/application/o/authorize/`
- Token: `https://accounts.mossyleaf.studio/application/o/token/`
- Userinfo: `https://accounts.mossyleaf.studio/application/o/userinfo/`
- End session: `https://accounts.mossyleaf.studio/application/o/<slug>/end-session/`
- JWKS: `https://accounts.mossyleaf.studio/application/o/<slug>/jwks/` (ID tokens are RS256)

Flow: authorization code with PKCE S256 (confidential client, `client_secret_basic` or `client_secret_post`), scopes `openid email profile`; add `offline_access` to also get a refresh token (30 days). Access tokens last 1 hour. No consent screen.

Userinfo (and ID token) claims, as observed locally:

```json
{
  "sub": "05017b12731d24a6d10cf9bac65724200ad3986da59b482a2e107055f8e7d7e5",
  "email": "ada@example.com",
  "email_verified": false,
  "name": "Ada Lovelace",
  "given_name": "Ada Lovelace",
  "preferred_username": "ada@example.com",
  "nickname": "ada@example.com",
  "groups": ["mossydew"],
  "zoneinfo": "Europe/Paris"
}
```

- `sub` is a hash of the user id and the install's identifier: stable, identical in every app, kept by a database restore (a brand-new install gives new values). Use it as the account key, not the email (users can change their email).
- `email_verified` is always `false` with Authentik's default mapping, even though every account proved its email by choosing its password from an emailed link.
- `zoneinfo` comes from the user attribute `timezone` (set by `make invite`, editable in the admin user form); absent when unset.
- A user outside the app's group gets Authentik's "Permission denied" page and the app never receives a code.

Logout (RP-initiated): redirect the browser to `/application/o/<slug>/end-session/?id_token_hint=<id token>&post_logout_redirect_uri=https://<app host>/&state=<optional>`. `id_token_hint` is **required** whenever `post_logout_redirect_uri` is sent (Authentik answers "invalid request" otherwise), and the URI must be one of the registered post-logout URIs above. It signs the user out of Authentik too (the next sign-in asks for the password again), then redirects to `post_logout_redirect_uri?state=…`. Without `post_logout_redirect_uri` the user ends on the sign-in page.

## Accounts

- **Invitation**: `make invite` (or the admin interface, see the server README) creates the user without a password, adds the groups and emails a link valid 7 days. The link opens a confirmation step (so mail scanners cannot burn it), then asks for a password (at least 12 characters), signs the user in and shows their application dashboard.
- **Forgot password**: "Forgot username or password?" on the sign-in page asks for the email and sends a link valid 30 minutes, same 12-character rule.
- **Sessions** last 30 days, so phones stay signed in.
- **Account page** (`/if/user/`): name, email, language, password (12-character rule), sessions, and optional two-factor devices: passkeys/WebAuthn, TOTP apps, recovery codes. Two-factor is never forced; a user with a device is asked for it after the password, and a passkey can also be used straight from the sign-in field.

## Branding

`branding.css` maps the mossyleaf tokens (accent `#5b7f3a` on `#f5f5f3`, white surfaces, thin borders, 0.5rem radius, Patua One for titles, Inter for text) onto Authentik's PatternFly variables. Authentik injects the brand CSS into the page and into every web component, so plain selectors such as `.pf-c-login__main` work. The theme is pinned to light. `logo.svg` is a hand-drawn leaf with the wordmark converted to outlines from Patua One; `favicon.svg` is the leaf; `background.svg` is a hand-built blur of greens with leaf silhouettes.

### Third-party assets

| Asset | Licence |
|---|---|
| Patua One (LatinoType), `branding/fonts/patua-one-*.woff2`, also outlined in `logo.svg` | SIL Open Font License 1.1, `branding/fonts/LICENSE-patua-one.txt` (via `@fontsource/patua-one` 5.3.0) |
| Inter (The Inter Project Authors), `branding/fonts/inter-*.woff2` | SIL Open Font License 1.1, `branding/fonts/LICENSE-inter.txt` (via `@fontsource-variable/inter` 5.3.0) |
| Authentik `ghcr.io/goauthentik/server` | MIT (open-source edition; no enterprise features used) |
| PostgreSQL `postgres:18-alpine` | PostgreSQL License |
| Mailpit `axllent/mailpit` (local only) | MIT |

## Server

See [deploy/README.md](deploy/README.md): first install, `.env`, nginx block and certificate, first admin, invitations, new apps, backups, updates. `make deploy-files` / `make deploy` copy the files to `user@server:/path/to/mossyleaf-accounts`.
