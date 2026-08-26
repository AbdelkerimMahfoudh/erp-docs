# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Active account / Owner: **CLAUDE-B**
- `started_at_utc:` `2026-08-26T20:25Z`
- **Authorised task — repair the default tenant-role provisioning defect**
  found in staging: one canonical provisioning source (CP1), atomic
  self-registration (CP2), a guarded restricted backfill (CP3), and real
  staging verification to 33/33 (CP4).
- Explicitly NOT authorised: changing the permission catalogue, expanding any
  role, granting tenant users platform-administrator access, or a schema
  migration. **Do not begin the IMEI scanner milestone.**
- HEADs at takeover — `erp-backend` `5dbc64e` · `erp-mobile` `b973f64` ·
  `retail-erp-control-web` `ad923df` · `erp-docs` `0e59c33`.
- Next intended action: move the canonical matrix under `src/` so runtime code
  can reach it — `tsconfig.build.json` excludes `prisma/seed-data` from the
  production build.

### HEADs — all four repositories clean and pushed

| Repository | HEAD |
|---|---|
| `erp-backend` | `5dbc64e` |
| `erp-mobile` | `b973f64` |
| `retail-erp-control-web` | `ad923df` |
| `erp-docs` | *this commit* |

`retail-erp-control-web` now has a remote and its full history is pushed.
Nothing was force-pushed and no history was rewritten.

---

## ⚠ The most important result: self-service registration grants no permissions

**A business that registers itself through the website gets an Owner who can
sign in and then do nothing.** Every guarded route answers:

```
403  {"error":"FORBIDDEN","message":"Missing permission(s): report.view"}
```

Measured in staging, both synthetic tenants:

```
role owner  0 permissions · store_manager 0 · store_employee 0
permissions catalogue: 44 rows
```

**Cause.** `AccessService.getEffectivePermissions` resolves authority only from
`role_permissions`. `RegistrationService` creates the three roles with a key and
a name and **no `role_permissions` rows**, so the union is empty. The demo
company works only because `prisma/seed.ts` separately applies the
`ROLE_PERMISSIONS` matrix — a step registration never performs.

**Not fixed in this checkpoint, deliberately.** It changes how permissions are
granted, which `CLAUDE.md` places behind an approval gate, and the authorised
scope here was the staging environment rather than application behaviour. The
full plan, files, risks and backfill note are in
[`docs/39` §10](docs/39_STAGING_ENVIRONMENT.md).

**This is the checkpoint working.** The defect was invisible until the whole
workflow ran end to end, and it was found by staging rather than by a shop.

---

## What was built

Full detail in **[`docs/39_STAGING_ENVIRONMENT.md`](docs/39_STAGING_ENVIRONMENT.md)**.

- **Isolation.** Staging runs on its own database, `prisma_staging`, with its
  own credentials and its own session and signing secrets. Verified after the
  acceptance run: `prisma_staging` has 2 companies / 1 grant / 1 billing period
  / 1 administrator; `phonestore` still has 1 company / 9 users / **0** grants /
  **0** billing periods / **0** administrators. **The demo database was never
  touched.**
- **One origin.** An edge on `:8088` serves the site and proxies `/api/*` to the
  API on `:3011`. This removes the Phase 2 cookie failure by construction rather
  than working around it. No hostname is hardcoded in application code.
- **Two layers on `/admin`.** Platform-administrator authentication, plus a
  network boundary that refuses any non-loopback peer with `404` before
  application code runs. **The API port is part of that boundary** — it binds
  loopback only, so the administration ENDPOINTS are not reachable while the
  administration PAGES are refused. `/public` and `/account` stay reachable from
  the LAN so a phone can test. Measured: API from LAN refused; `/admin` 404 from
  LAN and 200 from loopback; `/public/*` 200 from LAN.
- **Strict SQL.** The staging MySQL runs `STRICT_ALL_TABLES`. The development
  server's `sql_mode` is empty, which silently coerces a bad ENUM to `''`.
- **Guarded commands.** `staging-reset`, `staging-verification-code`,
  `staging-cleanup` — each refuses outside staging, by `APP_ENV` rather than
  `NODE_ENV` (staging sets `NODE_ENV=production` on purpose).
- **Mobile.** `EXPO_PUBLIC_API_ORIGIN` / `_SIGNUP_URL` / `_PORTAL_URL` /
  `_APP_ENV`, all overrides — production defaults unchanged. A staging build
  carries a persistent `STAGING — test data only` strip mounted at the app root.

### Two things found late, and fixed

- **HSTS was leaking from helmet.** The edge never set it, but helmet's defaults
  did on every `/api/*` response, `includeSubDomains` and all, and the proxy
  passed it through. Invisible over plain HTTP — and it would have pinned a real
  parent domain's siblings for six months the moment staging ran on HTTPS. Now
  dropped by the API in staging and stripped at the edge. Verified absent on
  both.
- **The staging scripts were reading the development database.**
  `@prisma/client` loads `.env` as an import side effect, before
  `loadEnv({ path: '.env.staging' })` runs, and dotenv will not replace a
  variable that is already set. `APP_ENV` is absent from `.env` so it *was* set
  from `.env.staging` and every staging guard passed, while `DATABASE_URL`
  silently stayed on development. **Nothing destructive could have run:** the
  reset, cleanup and seed guards test the database NAME, and `phonestore` fails
  the staging shape, so they would have refused. Fixed with `override: true`.

### Secrets

No secret is in any commit, image, build argument, mobile bundle or client
variable. Only `.env.staging.example` files — names and safe descriptions — are
committed. A `.env.*` rule had been swallowing the examples; a negation admits
`*.example` only, and `.env`, `.env.staging` and `.env.local` were each verified
still ignored. No secret value appears in this file, in any log, or in the
session report.

---

## Verification

| Gate | Result |
|---|---|
| Backend suite | **95 suites / 1657 tests, all pass** |
| Backend `tsc --noEmit` | clean |
| `prisma validate` | valid |
| Migration status | 57 applied, 0 pending |
| Clean replay from empty | 57 migrations, 83 tables, 24 triggers |
| Mobile `tsc --noEmit` | clean |
| Mobile pure suites | 9 files, 0 failures; 30 drift assertions |
| Website `tsc --noEmit` | clean |
| Website tests | 14/14 |
| Website build | clean, 301.87 kB (90.73 kB gzip) |
| Website `npm audit --omit=dev` | 0 vulnerabilities |
| Website lint (**oxlint**, not ESLint) | 0 errors, 4 warnings |

**Staging acceptance: 31 of 33 checks passed.** The two remaining failures are
precisely and only the permissions defect above — the suite was corrected so a
failure now means a real fault rather than my own wrong expectation.

Confirmed by the run: a new business is `pending` until an administrator acts ·
operational access is blocked before activation and the portal stays readable ·
an administrative grant confers `complimentary` with `canWrite: true` and
**fabricates no payment row** · suspension blocks operations while the portal
stays readable · reinstatement restores access · a wrong administrator password
(`403`) and a stale version (`409`) both refuse to move state · an Owner is
refused by the administration API and cannot read another business · the
timeline carries `registered`, `administrative_grant`, `suspended`,
`reinstated` · the audit trail names the administrator and contains no password
or code · a verification code never appears in a response · signing out revokes
the administrator session · `/health/ready` discloses nothing.

### What the suite now says

One earlier failure was my own: I asserted `state === 'active'` after a grant,
when the correct state is **`complimentary`** (`canWrite: true`,
`isComplimentary: true`, `status: 'activated'`) — the same state that makes "no
payment row was fabricated" true. That expectation is fixed.

The two that remain are the real defect: `403 Missing permission(s):
report.view`, a permissions failure and not an entitlement one. They are
labelled as such in the run output, so nobody has to rediscover which is which.

---

## ⛔ Two external decisions, both stopped before the mutation

Per the brief, no ambiguous external mutation was performed. **No cost of any
kind was created. Nothing was purchased, no subscription started, no DNS
changed, no repository made public.**

### 1. Where staging should be hosted

- **Configured now:** four Git remotes on one authenticated account. **No
  hosting account, no domain, no DNS zone, no container registry and no
  reverse-proxy service** was found configured anywhere.
- **Missing decision:** which hosting account to deploy to, and who accepts the
  charge.
- **Options.**
  1. **Keep it local (what exists today).** Runs on the WAMP machine; a phone on
     the same Wi-Fi can reach `/public` and `/account`. Cost **0**. Not reachable
     off the LAN.
  2. **A small VPS** (~US$5–7/month) with the committed compose file and a real
     certificate. Reachable from anywhere; needs a hostname and a payment method.
  3. **A managed container host** on an existing cloud account, if one exists
     that I could not see. Cost depends on the account.
- **Recommended: option 1 for now.** It already works, it costs nothing, and it
  is enough for the Owner to walk the whole workflow from a browser and a phone.
  Move to option 2 only when someone outside the LAN must test — and the
  artifacts to do that are already committed.
- **Minimum needed to proceed:** the provider and account to use, who pays, and
  a hostname.

### 2. The private-access layer for `/admin`

- **Configured now:** nothing. No VPN, no identity-aware proxy, no IP allowlist,
  and **administrator MFA is not implemented**.
- **Consequence, stated plainly:** `/admin` is reachable **only from loopback on
  the staging host**. To use it from elsewhere, tunnel over authenticated SSH
  (`ssh -L 8088:127.0.0.1:8088 …`) so the request still arrives from loopback.
- **Options.** (a) keep loopback-plus-SSH — costs nothing, works today;
  (b) implement administrator MFA — the real fix, a milestone of its own;
  (c) put an identity-aware proxy in front — needs the hosting decision first.
- **Recommended: (a) now, (b) before any internet exposure.** **Do not remove
  the loopback check to make `/admin` convenient.** Until MFA exists, one
  administrator password is the only thing between the internet and every
  tenant's subscription state.

---

## State of the staging environment

**Retained and running**, as the brief requires, for the Owner's acceptance
testing:

- API `:3011` (`APP_ENV=staging`, `STAGING_CONTACT_OUTBOX=enabled`), edge
  `:8088`, database `prisma_staging`.
- Two synthetic tenants (`staging.owner@…` and `staging.second@…`, both
  `@example.invalid` — RFC 2606, never a real domain) and one temporary
  administrator.
- **No real customer, employee or business information exists in staging.** No
  demo record was copied.

### Before the environment is retired

Run `npx ts-node scripts/staging-cleanup.ts`, which removes the synthetic
tenants, deletes the temporary administrator, revokes every administrator
session and consumes every unexpired verification code — while **preserving the
audit and subscription-event rows**, which are append-only by trigger.

The temporary administrator is **still present**, deliberately: deleting it now
would leave the Owner unable to open the administration portal for the
acceptance testing this environment exists for. Its password lives only in a
file outside every repository and appears in no commit and no log. Remove it
with the cleanup command when testing is done; create a fresh one with
`PLATFORM_ADMIN_PASSWORD=… npx ts-node prisma/create-platform-admin.ts <email> <name>`.

---

## Not done, and not started

**This is not a production readiness statement.** Not begun, per the brief:
production deployment · Bankily integration · real email or WhatsApp delivery ·
optional login 2FA · administrator impersonation · **the IMEI scanner
milestone**.

Also outstanding from the brief's list, and honestly not delivered:

- **A CI/CD pipeline.** Not built. The release path is the committed compose
  file and Dockerfiles, run by hand. No CI provider is configured on the Git
  account.
- **Device QA** (`docs/24`) was not re-run against a staging build on a physical
  phone — the staging mobile profile is committed but no device build was
  produced.
- **The three-language and light/dark sweep at 375px** was verified for the
  website during Phase 2, not re-run against staging.

---

## Next exact action

**Get a decision on the permissions defect above**, then implement the fix in
`docs/39` §10: move `ROLE_PERMISSIONS` to `src/rbac/role-permissions.ts`,
re-export it from `prisma/seed-data/permissions.ts`, and write the matching
`role_permissions` rows inside the transaction in `RegistrationService` that
already creates the roles. Pin **both** the Owner and the employee in a test —
granting an employee too much would be a worse and quieter failure than the
present one. No schema change and no migration are needed.

Then reset staging (`scripts/staging-reset.ts`) so the synthetic tenants are
re-created with correct permissions, and re-run the acceptance flow.
