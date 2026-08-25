# 39 — The staging environment

> **Staging is not production, and this document does not claim it is.** It
> exists so the Owner can walk the whole account-creation and subscription
> workflow from a real browser and a real phone, on synthetic data, without the
> unfinished administration system being reachable from the internet and without
> touching the demo database.

Companion documents: [`37_PLATFORM_CONTROL.md`](37_PLATFORM_CONTROL.md) (the
control-plane contract), [`38_CONTROL_WEBSITE.md`](38_CONTROL_WEBSITE.md) (the
website), [`22_BACKUP_AND_ROLLBACK.md`](22_BACKUP_AND_ROLLBACK.md) (database
safety).

---

## 1. What staging is isolated from

Three things had to stay untouched, and each is isolated by a different
mechanism rather than by care:

| Isolated from | How |
| --- | --- |
| The demo/development database (`phonestore`) | Staging uses a **different database**, `prisma_staging`, reached through a different `DATABASE_URL`. Nothing is copied between them. |
| Production | No production exists yet. Nothing here writes to one, and nothing here holds a credential that could. |
| Local development | Different port, different database, different session and signing secrets, its own log stream. A development server and the staging server can run side by side without either seeing the other's sessions. |

**Verified, not assumed.** After the full acceptance run:

```
prisma_staging   companies 1   users 1   grants 1   billing periods 1   admins 1
phonestore       companies 1   users 9   grants 0   billing periods 0   admins 0
```

The demo database has no platform administrator, no billing period and no
subscription event. Staging never reached it.

---

## 2. Shape: one origin

```
                     ┌──────────────────────────────┐
   browser / phone ──▶│  edge   :8088                │
                     │   /            → website     │
                     │   /public/*    → website     │
                     │   /account/*   → website     │
                     │   /admin/*     → LOOPBACK ONLY
                     │   /api/*       → proxy ──────┼──▶ API :3011 ──▶ prisma_staging
                     └──────────────────────────────┘
```

**Everything on one hostname, deliberately.** Phase 2 lost a day to a session
cookie that was set correctly and never sent, because the page was on
`localhost` and the API on `127.0.0.1` — different sites, so `SameSite=Lax`
withheld it exactly as designed. One origin removes that entire class of
failure rather than working around it. The mobile app follows the same rule via
`EXPO_PUBLIC_API_ORIGIN`.

No hostname is hardcoded anywhere in application code. The website resolves its
API from `window.location`; the app resolves its origin from configuration.

### Provider-neutral artifacts

The environment is described by files, not by a provider account, so it can be
stood up anywhere:

| File | Purpose |
| --- | --- |
| `deploy/docker-compose.staging.yml` | The whole environment: MySQL, API, website. Only the web port is published. |
| `deploy/nginx-site.conf` | The edge — routing, security headers, the `/admin` boundary. |
| `backend/Dockerfile` | Multi-stage, non-root, `HEALTHCHECK` on `/api/health/ready`. |
| `retail-erp-control-web/Dockerfile` | Static build served by nginx. |
| `*/.env.staging.example` | Names and safe descriptions. **No values.** |

The MySQL service runs with `--sql-mode=STRICT_ALL_TABLES,NO_ENGINE_SUBSTITUTION`.
This is not cosmetic: the development server's `sql_mode` is **empty**, which
silently coerces an invalid ENUM to `''` instead of failing. Staging fails
loudly, which is the behaviour a real deployment must have.

---

## 3. The `/admin` boundary — two layers, and one honest limitation

`/admin` requires **two** independent things:

1. **Platform-administrator authentication** — a session issued against a
   `platform_admins` row. Store Owners are refused; verified in the acceptance
   run.
2. **A network boundary** — the edge refuses `/admin` to any peer that is not
   loopback, **before any application code runs**, and answers `404` rather than
   `403` so a refusal does not confirm the portal exists.

`/public/*` and `/account/*` stay reachable from the LAN, so a phone can test
registration and the customer portal while the administration portal stays on
the machine.

> ### Limitation, stated plainly
>
> **Administrator MFA is not implemented, and no identity-aware proxy, VPN or
> IP-allowlist mechanism is available in this environment.** The `/admin`
> boundary is therefore *loopback or nothing*: to use the administration portal
> from elsewhere, tunnel to the staging host over authenticated SSH
> (`ssh -L 8088:127.0.0.1:8088 …`) so the request still arrives from loopback.
>
> **Do not remove the loopback check to make `/admin` convenient.** Until MFA
> exists, an obscure URL is not protection, and a single administrator password
> is the only thing between the internet and every tenant's subscription state.

---

## 4. Secrets

- Staging generates **its own** session and signing secrets, independent of any
  other environment. They are not derived from development values.
- Secrets exist only in `.env.staging` files, which are **git-ignored**. Only
  `.env.staging.example` files — names and descriptions, never values — are
  committed.
- Nothing is baked into a container image, a build argument, source code, a
  mobile bundle, or a client environment variable. A mobile test asserts the
  bundled config module contains no `DATABASE_URL`, `JWT_SECRET`,
  `SESSION_SECRET`, `ADMIN_PASSWORD`, `MYSQL_` or `PRIVATE_KEY`, so this cannot
  regress quietly.
- Secret **values** appear in no log, no handoff file and no report.

### The database account

Staging connects as `phonestore_app`, not as the migrator. This matters: the
append-only triggers test `USER() LIKE 'phonestore\_app@%'`, so connecting as
anything else would **bypass the very protections staging exists to exercise**.
The migrator holds `ALL` only on `phonestore` and `prisma\_%`, which is why the
staging database is named `prisma_staging` — it satisfies that grant pattern
and the reset guard's staging shape at once.

---

## 5. Operating it

### Reset

```bash
npx ts-node scripts/staging-reset.ts
```

Refuses unless **all** of the following hold:

- `APP_ENV === 'staging'`;
- the database name matches `^[a-z0-9_]*stag(e|ing)[a-z0-9_]*$`;
- the name is not `phonestore`, and contains no `prod`, `production`, `live` or
  `demo`;
- the name is not empty, not a wildcard, and contains no unresolved `${VAR}`;
- the operator **types the database name** and it matches the configured one.

It takes a verified `mysqldump` backup before dropping anything.

### Migrations and seed

All migrations replay in order from empty — 57 migrations, 83 tables, 24
triggers. The seed inserts **only the minimum pricing configuration** (one plan
version). It seeds no company, no user, no branch. The demo company is **not**
copied, and no real user, phone, IMEI, sale or financial record exists in
staging.

### Verification codes

No email or WhatsApp provider is configured, and this checkpoint does not add
one. **Nothing in staging claims a message was delivered, because nothing
delivered one.**

The outbox is an explicit opt-in — `APP_ENV=staging` **plus**
`STAGING_CONTACT_OUTBOX=enabled` — rather than "anything that is not
production", so an unlabelled environment cannot inherit it by accident.

To read a code:

```bash
npx ts-node scripts/staging-verification-code.ts <email-or-number>
```

- Refuses unless `APP_ENV=staging`. It runs nowhere else.
- Answers about **one contact you already named**; it deliberately cannot list
  contacts.
- Needs shell access to the staging host.

The code appears in **no** registration response, browser console, platform
audit record, general server log, public page or administration dashboard. A
separate gate (`codeMayBeReturned`) keeps it out of HTTP responses in staging
even though staging uses the outbox — a code in a response body would make the
whole verification meaningless, since anybody could then "verify" any address.

**This command is temporary infrastructure.** It goes when a real provider
arrives.

### Health

| Endpoint | Answers |
| --- | --- |
| `/api/health` | Liveness. |
| `/api/health/ready` | `{ready, databaseReachable, migrationsApplied, pendingMigrations, environment, checkedAt}` |
| `/api/health/version` | `{commit, builtAt, environment}` |

No secret, no connection string, no stack trace and no tenant data is
disclosed. Database errors are swallowed into `databaseReachable: false` rather
than returned as a message.

Observability is the container logs and these endpoints. **No external
analytics, tracking or error-monitoring provider is used**, and none is
configured.

---

## 6. Browser and indexing

The edge sets, on every response: a `Content-Security-Policy` with
`default-src 'self'` and `frame-ancestors 'none'`, `X-Frame-Options: DENY`,
`X-Content-Type-Options: nosniff`, `Referrer-Policy`, a `Permissions-Policy`
denying camera/microphone/geolocation/payment, and
`X-Robots-Tag: noindex, nofollow, noarchive`. `/robots.txt` disallows
everything.

**No HSTS**, deliberately. An HSTS header can pin a browser to HTTPS for a
parent domain it was never meant to affect — a mistake that outlives the
environment that made it.

The CSP has already earned its place: it caught a build in which Git Bash
path-mangled `VITE_API_BASE=/api/v1` into a Windows path, turning every API call
into a blocked `file://` request. Without the CSP that would have been a
mystifying runtime failure.

---

## 7. The mobile staging build

`mobile/.env.staging` (git-ignored; see `.env.staging.example`):

| Variable | Meaning |
| --- | --- |
| `EXPO_PUBLIC_API_ORIGIN` | The staging origin, scheme and port included. |
| `EXPO_PUBLIC_SIGNUP_URL` | Where `Create account` opens. |
| `EXPO_PUBLIC_PORTAL_URL` | Where an inactive Owner manages the subscription. |
| `EXPO_PUBLIC_APP_ENV=staging` | Turns on the staging label. |

**Production defaults are unchanged.** Every one of these is an override; unset,
the app behaves exactly as before.

A staging build carries a persistent `STAGING — test data only` strip mounted at
the app root. It renders `null` when the flag is unset, so a production build
pays nothing for it and no screen can forget to include it. A staging build
looks exactly like a production one, and the only thing between a test IMEI and
a real ledger is knowing which build is in your hand.

**No database credential, administrator credential or server secret is in the
mobile build.** Everything `EXPO_PUBLIC_` is inlined into the bundle and
readable by anybody holding the app; only public configuration may appear there.

---

## 8. After acceptance testing

The environment is **retained** for the Owner's acceptance testing. When it is
finished with:

1. Delete the synthetic tenants and users (they are removable; nothing depends
   on them).
2. Remove the temporary administrator account and revoke its sessions.
3. Confirm no verification code remains unexpired.
4. **Preserve the audit and subscription-event rows.** They are append-only by
   trigger, and deleting them is neither possible as the application user nor
   desirable — the point of an immutable timeline is that cleanup cannot edit
   it.

---

## 9. What staging does not prove

- **It is not a production readiness statement.** No production deployment, no
  real contact delivery, no Bankily integration, no administrator MFA, no
  administrator impersonation.
- It runs on synthetic identities only. No real customer, employee or business
  information is present.
- It has no external hosting. See `CURRENT_HANDOFF.md` for the two external
  decisions still open: the hosting destination, and the private-access layer
  that would let `/admin` be reached safely from outside the host.

---

## 10. What staging found: self-service registration grants no permissions

**This is the checkpoint's most important result, and it is a defect, not a
pass.** It was invisible until the whole workflow ran end to end, which is
precisely what a staging environment is for.

### The finding

A business that registers itself through the website gets an Owner who **can
sign in and then do nothing**. Every screen answers:

```
403  {"error":"FORBIDDEN","message":"Missing permission(s): report.view"}
```

Verified in staging across both synthetic tenants:

```
role owner            permissions: 0
role store_manager    permissions: 0
role store_employee   permissions: 0
permissions catalogue rows: 44
```

### Why

`AccessService.getEffectivePermissions` resolves a user's authority **only**
from `role_permissions` rows. `RegistrationService` creates the three roles with
a `key` and a `name` and **no `role_permissions` rows at all**, so the union is
empty and every guarded route refuses. The demo company works only because
`prisma/seed.ts` separately applies the `ROLE_PERMISSIONS` matrix from
`prisma/seed-data/permissions.ts` — a step self-service registration never
performs.

Note this is *not* an entitlement failure, and the entitlement machinery is
sound: after an administrative grant the subscription correctly reads
`state: complimentary, canWrite: true, isComplimentary: true` with **no payment
row fabricated**. Suspension and reinstatement both flip operational access
correctly. The tenant simply has no permissions to exercise.

### The proposed fix — NOT applied

**Not implemented in this checkpoint.** It changes how permissions are granted,
which `CLAUDE.md` places behind an explicit approval gate, and the authorised
scope here was the staging environment rather than application behaviour.

- **Plan.** Make the `ROLE_PERMISSIONS` matrix the single source of truth for
  both callers. Move it to `src/rbac/role-permissions.ts`, have
  `prisma/seed-data/permissions.ts` re-export it so the seed is unchanged, and
  have `RegistrationService` write the matching `role_permissions` rows inside
  the transaction that already creates the roles.
- **Files.** `src/platform/registration.service.ts`,
  `src/rbac/role-permissions.ts` (new), `prisma/seed-data/permissions.ts`,
  plus a registration test asserting a fresh Owner holds `ALL_PERMISSION_KEYS`
  and a fresh employee does not.
- **Risks.** It touches a sacred rule. Getting the matrix wrong in the other
  direction — granting an employee more than intended — is worse than the
  present failure, because it is silent. The test must pin both roles, not only
  the Owner. No schema change and no migration are required; the tables and the
  matrix already exist.
- **Existing tenants.** Any company already registered self-service needs the
  rows backfilled. In staging that is a reset. There is no production tenant.
