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
prisma_staging   companies 2   users 2   admins 1   audit events 44   catalogue 61
phonestore       companies 1   users 9   admins 0   sales 7 / 10 051.00   catalogue 61
```

The demo database has no platform administrator and no subscription event, and
its role-permission fingerprint is byte-identical before and after every run in
this environment. Staging never reached it.

> **The scripts nearly broke this, and the guards held.** `@prisma/client`
> loads `.env` as an import side effect, and ES imports run before any
> statement in the file — so `loadEnv({ path: '.env.staging' })` could not
> replace a `DATABASE_URL` that was already set. `APP_ENV` is absent from
> `.env`, so it *was* set from `.env.staging` and every staging guard passed,
> while the connection silently stayed on development. The reset, cleanup and
> seed commands would have **refused** rather than acted, because they test the
> database NAME and `phonestore` fails the staging shape — so nothing
> destructive could have run. Fixed with `override: true`; `PrismaClient`
> resolves its URL when constructed, not when imported.

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

**The API port is part of that boundary.** Refusing the administration PAGES
while the administration ENDPOINTS stay open on the API port would leave a
password as the only layer — exactly what this is supposed to avoid. So the API
binds loopback only (`API_BIND=127.0.0.1`) and is reachable solely through the
edge; under Docker the same is achieved with `expose` rather than `ports`.
Measured:

```
API direct from LAN      connection refused
/admin        from LAN   404      from loopback  200
/public/*     from LAN   200      (a phone can test)
/api/health   from LAN   200      (through the edge)
```

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

It was not free. The edge never set HSTS, but **helmet's defaults did**, on
every `/api/*` response, complete with `includeSubDomains` — and the proxy
passed it straight through. Over plain HTTP a browser ignores it, so this was
invisible until measured; the moment staging ran on HTTPS under a real domain it
would have pinned that domain's siblings for six months. Now closed twice over:
the API drops HSTS when `APP_ENV=staging`, and the edge strips the header from
anything upstream sends (`proxy_hide_header Strict-Transport-Security`).
Verified absent on both website and API responses.

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
| ~~`EXPO_PUBLIC_SIGNUP_URL`~~ | No longer read (2026-09-22): registration happens in the app. |
| ~~`EXPO_PUBLIC_PORTAL_URL`~~ | No longer read (2026-09-22): the app no longer opens the website; an inactive Owner is told to contact the administrator. |
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

## 10. What staging found — and how it was repaired

**Staging's most valuable result was a defect no unit test could have caught,
because every unit test used the seeded demo company.** It is now fixed,
verified end to end, and the affected tenants have been repaired.

### The root cause

Two things had to be true at once:

1. `AccessService.getEffectivePermissions` resolves authority **only** from
   `role_permissions`.
2. `RegistrationService` created three `roles` rows — a key and a name — and
   **no `role_permissions` at all**.

So every shop that signed up through the website got an Owner who could sign in
and then do nothing: `403 Missing permission(s): report.view` on every screen.

The demo company worked because `prisma/seed.ts` carried its **own separate
copy** of the provisioning loop and applied the matrix itself. That second
implementation is what hid the bug — the only tenant anybody looked at was
provisioned by different code from the one real shops used.

Underneath both sat a structural cause worth naming: the canonical matrix lived
in `prisma/seed-data/permissions.ts`, and **`tsconfig.build.json` excludes
`prisma/seed-data` from the production build**. The seed could read the matrix;
the server could not. Registration was not careless so much as unable.

### The repair

**One canonical source.** The matrix moved to `src/rbac/role-permissions.ts`,
where runtime code can reach it, with `prisma/seed-data/permissions.ts` left as
a pure re-export so the seed and every existing import keep working against
exactly one definition. Verified unchanged across the move: 61 permissions,
`owner` 61 / `store_manager` 43 / `store_employee` 20, and a SHA-256 over the
catalogue, matrix, labels and store-facing list identical before and after
(`0ddb8c04…`). **No permission key was added, removed, renamed or moved between
roles.**

**One implementation.** `src/rbac/role-provisioning.ts` is now the only place
that creates a role or a `role_permissions` row — registration, the seed and the
historical repair all call it. It takes the caller's transaction client, refuses
an unknown role key, refuses to provision a *partial* role when the catalogue is
short a permission, stays company-scoped, and is idempotent at the database
rather than by checking first: `roles` is unique on `(company_id, key)` and
`role_permissions` is keyed on `(role_id, permission_id)`, so a replay — or two
concurrent replays — inserts nothing the second time instead of racing.

**Atomic registration.** Provisioning happens inside the transaction that
creates the company, so roles, permissions, Owner and subscription now succeed
or roll back together. A half-built tenant is not something a shopkeeper can
fix, and not obviously broken to anyone else.

A drift test fails the build if a second hand-maintained matrix ever appears
anywhere outside the canonical file.

### The historical repair — eligibility rules

`scripts/staging-repair-role-permissions.ts`. **Dry run by default**; writing
requires `--apply`, spelled out.

Before any write it forces `.env.staging` with `override: true`, demands
`APP_ENV=staging`, rejects a database whose name is not unmistakably staging
(and any name matching `phonestore`, `prod`, `production`, `live` or `demo`),
takes a `mysqldump`, and **restore-proves that dump into a disposable database**
which is then dropped. A dump that exists is not a backup; a dump that restores
is.

A company is repaired only when **all** of the following are proven — and they
are re-proven inside the write transaction, because between printing a report
and writing, somebody could have configured that company by hand:

- it came through the affected self-registration path (a `registration_attempts`
  row names it);
- it has exactly the three default role keys, no more and no fewer;
- **all three** roles have zero `role_permissions`;
- it is not the demo tenant.

**Anything partial or customised is skipped whole**, and reported for manual
review. Completing somebody's deliberately narrowed manager would be inventing a
decision they never made — a worse bug than the empty roles, and a quieter one.
Nothing here completes, normalises or replaces an existing mapping.

Audited as `adminId: null`, `actor: 'system:role-permission-repair'`. A person
did not do this, and recording one would put a name on a change they never made.

### What the repair did in staging

| | |
| --- | --- |
| Companies examined | 6 |
| Repaired | **4** — each `owner 0→61`, `store_manager 0→43`, `store_employee 0→20` (+124 mappings) |
| Skipped | 0 on the first run; **4 on the second, as "already provisioned with the canonical matrix"** — the replay is a no-op |
| Backup | `prisma_staging-before-role-repair-…sql`, restore-proved into a disposable database (83 tables) which was then dropped |
| Demo tenant | **untouched** — 7 roles, 159 mappings, checksum `ee023046b819dbfd`, 1 company / 9 users / 7 sales / 10 051.00, identical before and after |

### A second gap it exposed

The repair refused its first run: `Permission "sale.create" is not in the
database catalogue.` **Staging held 44 of the 61 permission keys.**

The catalogue is reference data every environment needs, and **no migration
creates it** — the base keys are inserted only by `prisma/seed.ts`, which also
seeds the demo company and therefore never runs against staging. `seed-staging.ts`
now seeds the catalogue through the same `PERMISSIONS` constant; 17 keys were
added.

That refusal is the guard doing its job. Silently granting 60 of 61 permissions
would have been far worse than stopping.

> **Closed by migration `0059`.** A database built by `prisma migrate deploy`
> alone now holds all 61 keys. See
> [§11](#11-migration-0059--the-catalogue-as-reference-data) and
> [`37_PLATFORM_CONTROL.md`](37_PLATFORM_CONTROL.md).
>
> Staging no longer needs `seed-staging.ts` to repair a short catalogue. That
> step remains, idempotent and harmless, so an environment created before `0059`
> still converges — but **deployment does not depend on it**, and it is not a
> recovery mechanism any more.

### Acceptance

**44 of 44 checks pass**, covering the 16-step CP4 flow — including a company
registered *after* the fix receiving exactly 61/43/20 with no repair involved,
Manager and Employee allowed and denied operations, cross-company refusal, every
tenant role refused by the platform administration API, `/admin` 404 from the
LAN and 200 from loopback, the API port unreachable from the LAN, and idempotent
replay of both registration and the repair.

Note that `report.view` is **branch-scoped**: without an `x-branch-id` header
only company-wide permissions resolve. That is the branch-safety boundary
working, not a defect — an earlier acceptance run mistook it for one.

---

## 11. Migration `0059` — the catalogue as reference data

### Why `prisma migrate deploy` produced only 44 keys

The permission catalogue is reference data every environment needs, and **no
migration created it.** The base keys — `sale.create`, `report.view`,
`user.manage` and 14 others — were inserted only by `prisma/seed.ts`. Later
migrations (0044, 0047, 0049, 0050 and others) each added the handful of keys
their own feature introduced, which is how a deploy-only database reached 44.

### Why the demo seed concealed it

`prisma/seed.ts` does two jobs at once: it seeds the reference catalogue **and**
the demo company. Every environment anybody had ever looked at ran it, so the
catalogue was always complete there — and the gap was invisible precisely
because the thing that hid it was also the thing everybody used.

Staging was the first environment built deliberately **without** the demo
company. It was therefore also the first to show the defect, and it did so
loudly: the role repair refused to run rather than provision a partial Owner.

### Why `0059` is reference data, not schema or authority

It inserts catalogue **rows**. It grants nothing.

- No schema change — no `ALTER`, no `CREATE TABLE`, no Prisma schema edit.
- No `role_permissions`, so no role's authority moves. Owner 61 / Manager 43 /
  Employee 20 are untouched, and the role-matrix SHA-256 is unchanged.
- No tenant, user, branch, subscription, sale or demo record.
- No existing row modified.

```sql
INSERT INTO `permissions` (`id`, `key`, `label`)
SELECT * FROM ( … 61 candidate rows … ) AS want
WHERE NOT EXISTS (SELECT 1 FROM `permissions` p WHERE p.`key` = want.k);
```

**`NOT EXISTS`, never `INSERT IGNORE` or `REPLACE`.** `IGNORE` would also
swallow a genuine error — a truncated label under strict mode, a broken
constraint — and leave the catalogue quietly short, which is the exact class of
silent failure this migration exists to end. `REPLACE` would delete and
reinsert, discarding ids that `role_permissions` rows point at.

### Semantics

| Starting state | Result |
| --- | --- |
| Empty (clean install) | all 61 rows inserted |
| The 44-key pre-`0059` state | **exactly 17** rows inserted; the 44 existing rows untouched |
| Already complete | nothing inserted, nothing changed |

### Provenance, and the rule for future permissions

The SQL is generated from `src/rbac/role-permissions.ts` by
`scripts/generate-catalogue-migration.ts`, so nobody hand-maintains a second
list of keys — a duplicate of exactly that kind is what let registration ship
without permissions. `--check` regenerates and compares, and
`permission-catalogue.spec.ts` fails the build if the migration and the
canonical source drift apart.

**The SQL is an immutable historical snapshot, not a second runtime source of
authority.** Nothing under `src/` reads a migration file, and a test enforces
that.

> **Adding a permission later means a NEW migration. Never edit `0059`.** Every
> database that has already applied it would silently stop matching the file
> that claims to describe it.

### The deployment gate

```bash
npx ts-node scripts/verify-permission-catalogue.ts
```

Exits non-zero when the catalogue is missing a key, holds a key the codebase
does not define, or holds a duplicate. Run it after `migrate deploy` and refuse
to start on a failure — `scripts/staging-apply-migrations.ts` already chains the
two.

It **never deletes**. An unknown key fails the gate and is reported for a person
to decide about: removing it automatically could revoke authority a deliberate
change granted, and the command cannot tell those apart. A drifted *label* is
reported but does not fail, because labels are display text and failing a
deployment over wording teaches people to ignore the gate.

It reports *matched of canonical* rather than a bare total — a database missing
one canonical key and carrying one unknown key has the same row count as a
correct one.

### Migration, backup and rollback

`scripts/staging-apply-migrations.ts` applies pending migrations to staging
behind the usual guards: `.env.staging` with `override: true`, `APP_ENV=staging`,
a database name that is unmistakably staging, a `mysqldump`, and a
**restore-proof** of that dump into a disposable database which is then dropped.

Rolling `0059` back is a data question, not a schema one. There is nothing to
un-migrate structurally; if the inserted rows must go, restore the recorded
backup. **Deleting catalogue rows by hand is not a rollback** — `role_permissions`
references them, and removing a row a role points at revokes authority silently.

### Proof

Both paths were run on real, disposable MySQL databases, dropped afterwards.

| | |
| --- | --- |
| **Clean install** | 58 migrations, highest `0059`, **61 keys**, zero tenant data; a self-registered company received exactly **61/43/20** with no seed; 25/25 live checks |
| **Upgrade** | 44 → 61, **exactly 17 rows added**; all 44 pre-existing rows byte-identical in id, key and label; replaying deploy changed nothing |
| **Strict mode** | re-executing the statement under `STRICT_ALL_TABLES` left the catalogue fingerprint identical |
| **Staging** | migration recorded; catalogue stayed at 61; role mappings unchanged (checksum `c2cf1e55732161f7` before and after); both repaired companies still 124 |
| **Demo** | unchanged — checksum `ee023046b819dbfd`, 1 company / 9 users / 7 sales / 10 051.00 |

The 17 keys added on the upgrade path: `branch.manage`, `closing.perform`,
`cost.view`, `discount.apply`, `discount.override`, `expense.manage`,
`import.run`, `integrations.manage`, `purchase.manage`, `report.view`,
`sale.create`, `sale.return`, `settings.manage`, `supplier.manage`, `unit.add`,
`unit.transfer`, `user.manage`.

### `seedPermissions()` after this

`prisma/seed.ts` still seeds the catalogue, which stays useful for local
development where the seed is run anyway. **Deployment no longer depends on it**,
and it is no longer a way to repair migration state.

---

## Cleanup, and the SQL mode question

### `staging-cleanup.ts` is now dry-run by default

It used to fail outright — `Foreign key constraint violated: admin_id` — so the
documented way to tidy staging did not work at all.

`platform_audit_events.admin_id` is a nullable foreign key with no delete
action, so it RESTRICTS. The repair releases the reference and **keeps** the
audit event, which is what the schema always intended: the actor's name is
stored as text beside the reference precisely so the record still reads once the
admin row is gone.

A second defect surfaced while testing the first: the synthetic-company set was
a `Set` of `Buffer`s, which dedupes by object identity rather than value. It
reported 7 companies where staging has 3, and would have tried to delete each
one twice.

```bash
npx ts-node scripts/staging-cleanup.ts                    # reports only
npx ts-node scripts/staging-cleanup.ts --apply            # deletes
npx ts-node scripts/staging-cleanup.ts --apply --remove-admin
```

**The staging administrator is preserved** unless `--remove-admin` is passed. It
is deliberate infrastructure, not test litter; sweeping it away meant the next
session had to recreate it before it could do anything.

Unspent registration continuations and portal-handoff tickets are expired too —
both live in `verification_intents`, and both are credentials nobody is watching
once a run ends.

### 🔴 Unresolved: this MySQL is not strict

`@@GLOBAL.sql_mode` is **empty**. Migration replay is verified under an explicit
strict session (`STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION`),
and the original value is always restored afterwards — but the **server**
remains non-strict.

Making it strict is deployment work and a decision to take deliberately rather
than inherit: a database that silently truncates is a database that silently
loses money.

---

## `COOKIE_SECURE` — and why `NODE_ENV` could not decide it

`.env.staging` sets `NODE_ENV=production`, deliberately: the build should be
production-like. Session cookies used to read their `Secure` flag straight off
that, and on a staging host served over plain HTTP that is not a stricter
cookie — it is **no cookie at all**. The browser discards it silently, and the
only symptom is being asked to sign in again.

`localhost` hides the problem completely, because browsers treat it as a
trustworthy origin and keep the cookie anyway. The CP8 acceptance walked the
same handoff twice:

| Origin | Cookie kept | Result |
| --- | --- | --- |
| `http://localhost:8088` | yes | landed in the portal, signed in |
| `http://192.168.100.3:8088` | **no** | landed on a password form |

The second is the LAN path this document deliberately keeps open so a phone can
test registration and the portal. So the flag is now explicit:

```bash
COOKIE_SECURE=false   # this host is plain HTTP; TLS terminates in front elsewhere
```

`cookieSecure()` in `backend/src/common/http/cookies.ts` reads it, falls back to
`NODE_ENV === 'production'` when it is unset, and ignores a value it does not
understand rather than guessing — a typo must not silently turn `Secure` off in
production.

> **Production must leave this unset, or set it to `true`.** Turning it off
> means session cookies travel in clear text. Put TLS in front of the edge.

## Cleaning up after a run

```bash
npx ts-node scripts/staging-cleanup.ts                                   # reports only
npx ts-node scripts/staging-cleanup.ts --since=2026-08-29T02:00:00.000Z  # this run only
npx ts-node scripts/staging-cleanup.ts --apply --since=... --remove-admin
```

### `--since`, and why it had to exist

"The owner has an `@example.invalid` address" identifies test data — but every
company in staging is test data, including the fixtures each session starts
from. A dry run proposed deleting **41** companies, three of which were the
baseline. With `--since`, a company must be synthetic **and** newer than the
moment the run began; the same window applies to a temporary administrator, so a
run can take its own away without touching the deliberate staging one.

Inside a window, a company with **no** email address counts too. A WhatsApp-only
registration leaves an owner with a phone and no address, so the email rule
cannot see it — six such shops were invisible to the first dry run.

### 🔴 A staging tenant cannot actually be deleted

`companies` is referenced by seventy-odd tables and **every one of them
restricts deletion** — `branches`, `users`, `roles`, `role_permissions` and
`subscriptions` among them, all of which registration itself creates. So
`company.delete()` cannot succeed for any shop that has ever registered, and
this script has never removed one.

It used to report `companies: 38` in a dry run and then remove nothing, which
reads exactly like success. It now reports `companyCandidates` before the fact
and `companiesRefused` after it, and says plainly that the tenants remain.

**Deleting the children in dependency order is not the fix.** "Nothing financial
is hard-deleted" is a rule of this system, not an obstacle to route around.
Reclaiming staging tenants means restoring the database per
[`22_BACKUP_AND_ROLLBACK.md`](22_BACKUP_AND_ROLLBACK.md) — a deliberate act.

What the script *does* reliably remove: administrator sessions, spent and
unspent verification intents, expired continuations and handoff tickets, and a
windowed temporary administrator. It **preserves** every audit event: the
`admin_id` reference is released and the row is kept, because the actor's name
is stored as text beside it precisely so the record still reads afterwards.
Measured: 29 events had their reference released, and all 29 still name their
actor, action, target and reason.

### After the CP8 acceptance

Staging holds **41 companies / 56 users** — the 3-company baseline plus 38
tenants this acceptance created and the schema will not let go. One platform
administrator (the deliberate one). Audit 71, subscription events 62,
**subscription payments 0**.

## Serving the app's web export from the edge

Not part of the deployed arrangement, but worth recording because the acceptance
needed it: the app's API origin is baked at build time, so the export can only be
driven in a browser from that same origin. Mounting `mobile/dist` at `/app/`
alongside `/_expo/` on the edge makes the real registration screens reachable
without a second origin and without touching CORS.

---

## The retained fixture: `Test Store`

```bash
npx ts-node scripts/staging-fixture-store.ts                       # reports only
FIXTURE_OWNER_PASSWORD=… npx ts-node scripts/staging-fixture-store.ts --apply
```

One shop that is meant to survive, so there is always somewhere to sign in and
see stock. Everything else in staging is litter the schema will not let go of;
this is deliberate.

| | |
| --- | --- |
| Company / branch | `Test Store` / `Main Store` |
| Owner | `store@test.com` — **the password is not recorded anywhere in this repository** |
| Contact | verified, through the real continuation and challenge |
| Subscription | **activated by a 30-day administrative grant**, complimentary, expiring `2026-09-28` |
| Payments | **none.** A grant is not money, and none is invented |
| Monthly | 500 MRU — one branch, Owner only, no chargeable staff |
| Stock | 20 iPhone variants · 20 units, all `in_stock` · 5 dual-SIM |
| Not present | staff, sales, expenses, customers, trial |

### The password

It arrives in `FIXTURE_OWNER_PASSWORD` or through a non-echoing prompt, and is
hashed by the ordinary authentication path. It is **staging-only**: it is not in
a tracked file, not printed, not logged, and must never be reused anywhere else
or on a production account. A test asserts the command contains no literal
password and that no `console.log` in it mentions one.

### Everything goes through the real services

`RegistrationService` creates the company, branch, Owner, canonical roles and
permission mappings and the pending subscription. The continuation and challenge
verify the contact — and the session that completion issues is revoked
immediately, because a fixture is a shop to sign into later, not a live session
left open on a shared host. `SubscriptionLifecycleService` records the grant, so
it is audited and attributed.

A grant sets `complimentaryUntil` and leaves `currentPeriodEnd` **null**, which
is not an omission: it is what stops a grant reading like a period somebody paid
for.

### The IMEIs are synthetic, and safe to publish

No real device identifier is involved. The first eight digits are a
non-allocated test range, the next six a deterministic sequence, and the
fifteenth is the Luhn check digit — computed with the application's own helper
and then checked by the application's own validator before anything is stored.
Primaries and secondaries occupy disjoint bands, so a primary can never equal a
secondary, and uniqueness is checked against **both** columns before insertion:
an identifier that already exists as somebody's secondary is just as taken as
one that exists as a primary.

Because the sequence is deterministic, a rerun provisions nothing new. That is
what makes the command idempotent rather than merely careful.

### Guards

Refuses unless `APP_ENV=staging`; refuses a database whose name is not
unmistakably staging, and specifically refuses `phonestore`, anything matching
`prod`, `live` or `demo`; dry-run by default; and **refuses outright to adopt an
existing `store@test.com` that belongs to a different company** rather than
granting a subscription to somebody else's Owner.

### Counts after this checkpoint

Staging holds **42 companies / 57 users**: the 3-company baseline, the 38
retained acceptance tenants the schema will not release, and `Test Store`.
20 products, 20 units, one platform administrator, **0 subscription payments**.

---

## The device catalogue, and the fixture's synthetic TACs

Migration `0062` adds `device_brands` and `device_models` and gives
`tac_catalog` provenance. **13 brands / 323 models** in both databases,
`source = 'curated'`, reviewed `2026-08-30`.

### Updating the catalogue without a mobile release

The catalogue is read from the database at request time, so correcting or
extending it is reference-data work, not a release:

```bash
npx ts-node scripts/generate-device-catalogue-migration.ts
```

Edit `src/catalog/device-catalogue.ts`, regenerate, and the next migration
carries the change. `device-catalogue.spec.ts` fails the build if the source
and the snapshot ever drift — the same guard `0059` uses for permissions. Every
insert is `NOT EXISTS`, so a replay changes nothing.

### The fixture's twenty TACs

Each `Test Store` iPhone has its own synthetic TAC, `0100` + the model index:

| | |
| --- | --- |
| Range | `01000000` – `01000019` (**not** an allocated TAC range) |
| Source | `synthetic_staging` |
| Maps to | Apple, and the one iPhone model that phone represents |
| Live result | **20/20** resolve to the intended model over real HTTP |

A single shared TAC would have made the recognition test meaningless — every
scan would resolve identically whether the lookup worked or not.

> **The guard is at the READ, not only at the write.**
> `TacMappingService.resolve()` excludes `synthetic_staging` unless
> `APP_ENV=staging`. If those rows ever travelled — a dump restored in the
> wrong place, a copied database — they must not become suggestions somebody
> acts on, and the command that wrote them is not what a stray database has
> already run. Measured: 20 rows in staging, **0** in development.

### The fixture is now product-keyed

Unit matching finds the unit by its PRODUCT, not by its identifier. Keyed on
the IMEI it would have provisioned twenty more phones the moment the
identifiers changed — which is exactly what giving each model its own TAC did.
A rerun now corrects identifiers in place and reports `0 created`.

---

## Migration `0063` — the display order

`release_rank` was the release year and was also ordering the list. It cannot
do both: a family spans years, so `iPhone 17e` (2026) belongs **below**
`iPhone 17 Pro Max` (2025), and sorting by year also fell back to alphabetical
and put `iPhone 16e` above `iPhone 17`.

`0063` adds `display_rank` and backfills it from
`src/catalog/device-catalogue.ts`. **`release_rank` is not touched** — the year
is real curated data and stays separately queryable.

Backed up and restore-proven first, both databases, into `prisma_restore_proof`
(dropped afterwards). Applied to a restored copy of staging in
`prisma_migrate_probe` before anything real: 42 companies, 20 units, 323 models,
20 TAC rows, years still `2017`–`2026`, `0` models left unranked. Probe dropped.

> **The trailer check earned its keep.** The first demo dump ended at
> `-- Dumping routines` with no `-- Dump completed`. `docs/22` says a dump you
> have not checked is not a backup, and this is exactly the failure it
> describes — the re-run completed cleanly and was restore-proven.

## Two commands worth knowing

```bash
npx ts-node scripts/tac-coverage.ts
```

Counts the selector catalogue, the TAC rows and the company mappings
**separately**, and prints how many catalogue models can actually be recognised
from an IMEI. Pass `--staging` with `APP_ENV=staging` for the staging database.

```bash
APP_ENV=staging npx ts-node scripts/staging-scan-sheet.ts > sheet.html
```

Renders the fixture's twenty phones as Code 128 barcodes, primary and secondary,
for pointing a camera at. It refuses any database that is not a staging one —
it checks the **database name**, not `APP_ENV`, because the script loads
`.env.staging` itself and a guard that can never fail is not a guard.

The page is pinned to a light colour scheme on purpose: a dark-mode browser
renders black bars on a dark card, and a barcode without contrast does not scan.

**Printing the sheet is not camera verification.** It says so on its face.

---

## Reading the coverage report

```bash
npx ts-node scripts/tac-coverage.ts                                # development
APP_ENV=staging npx ts-node scripts/tac-coverage.ts --staging
APP_ENV=staging npx ts-node scripts/tac-coverage.ts --staging --company "Test Store"
```

Four parts, never one number:

1. **Selector catalogue** — 13 brands / 323 models. Choosing from it needs no
   IMEI at all.
2. **Global TAC catalogue** — by source and by brand, with distinct TACs and
   distinct models for each. Staging: **20 TACs / 19 models**, all
   `synthetic_staging`, all Apple. Development: **0**.
3. **Company-confirmed mappings** — per company. Development: **3**, all one
   company. Staging: **0**.
4. **Effective per-company** — the union of 2 and 3, deduplicated by TAC.

> **A confirmed mapping needs no global row.** Development has an empty
> `tac_catalog` and still resolves three codes, to exact products. An earlier
> report said the opposite; `docs/21` §6p records the correction.

`5.9%` is **staging's generic synthetic catalogue coverage** and nothing wider.
Development's equivalent is 0% while still resolving three codes.

---

## The scan sheet is complete — all ten fixture types

```bash
cd backend
APP_ENV=staging npx ts-node scripts/staging-scan-sheet.ts > ../scan-sheet.html
```

Output: `C:\wamp64\www\PhoneStoreERP\scan-sheet.html`

**31 cards · 29 Code 128 · 2 QR.** Cases 2 and 3 carry `IMEI: <imei>` and
`IMEI1: …\nIMEI2: …` — black on white, medium error correction, four-module
quiet zone.

### The dependency

`qrcode@1.5.4` and `@types/qrcode@1.5.6`, both pinned **devDependencies**, used
in exactly one file. Confirmed absent from `dependencies`, from the production
install tree, from the compiled `dist/`, from the mobile package and from the
mobile web bundle. Production advisories measured before and after: **17 both
times**, and `qrcode` is implicated in none of them.

Code 128 stays hand-rolled — it is small and entirely mechanical. QR is not:
Reed–Solomon, masking and format information are exactly the things a
hand-written encoder gets subtly wrong, producing a symbol that looks right and
does not decode. That would be the worst possible fixture, because it fails a
test the scanner actually passed.

> `tsc -p` compiled the script without the types package, which was misleading:
> `scripts/` is not in tsconfig's `include`, so the project build never reads
> it. `ts-node` does, and raised TS7016 the moment the script ran.

---

## Superseded in part by `docs/99` (2026-10-17, CLAUDE)

The internet-reachable staging API is `https://staging-api.tsxmr.com`, deployed as described in `docs/99`.

- **Shape (§2).** The staging API is its own origin, behind a Caddy edge. The website is on Cloudflare Pages and is
  not part of the stack. The "one origin" shape here described a local acceptance environment.
- **Database.** The database is the schema `phonestore_staging` on a dedicated MySQL 8.4 server inside the stack
  (D191). It is not `prisma_staging` beside development.
- **Provider-neutral artifacts (§2).** The file table named a `deploy/docker-compose.staging.yml`, a
  `deploy/nginx-site.conf` and a `backend/Dockerfile` that were never committed to `erp-backend`. The real ones are
  `Dockerfile`, `deploy/docker-compose.staging.yml`, `deploy/staging/*` and `.env.staging.example` (`33723da`).
- **Verification codes (§5).** The retrieval command still works, now on keyed (`OTP_PEPPER`) codes too (`0c12bf2`).
  It runs inside the stack's `tools` container (`docs/99` §6 step 9).
- **SQL mode.** Staging uses MySQL 8's strict default, the same as CI, rather than `STRICT_ALL_TABLES` alone.

What stays:
- fictitious data only;
- every staging-only command guarded by `APP_ENV=staging`;
- the `/admin` boundary of §3 for any future web console.

