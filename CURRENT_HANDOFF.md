# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF** — trees clean and green. The **security
  correction is complete**; the UI and acceptance work is not. See below.
- Active account / Owner: **NONE** (last worked by CLAUDE-B)
- `started_at_utc:` `2026-08-28T09:00Z` — completing the partial registration
  milestone with an authorised, narrowly scoped registration-authentication
  design.
- HEADs at takeover, verified against Git: `erp-backend` `3a43ca8` ·
  `erp-mobile` `14b9d33` · `retail-erp-control-web` `3d0e277` · `erp-docs`
  `0954a33`. All four clean and level.
- Baseline verified: backend **100 suites / 1731 tests** · mobile **20 pure
  suites**, EN/AR/FR **1796** identical · website **14/14**, `tsc -b` and
  production build clean · registration retired · modal unmounted · mobile
  registration screen absent.
- **Discrepancy — migration state.** `0059` and `0060` are applied to
  **staging only**. Neither is applied to development (`phonestore`), so the
  handoff's description of `0059` as completed was true of staging and false of
  development.
- **`0060` pre-existed this takeover** (commit `3a43ca8`) and is *one enum
  value* on `verification_intents`, not a new table.
- `started_at_utc:` `2026-08-26T23:05Z`
- **Authorised task — move account creation into the mobile app**, retire
  website registration, add a secure one-time mobile→website portal handoff,
  and show a payment-instruction modal (five providers, all temporarily `00000`).
  Supersedes every earlier requirement placing public registration on the website.
- `resumed_at_utc:` `2026-08-27T20:00Z` — **CLAUDE-B resuming its own
  interrupted session.** Same account label, so this is a resume and not a
  takeover; every dirty file was inspected first, as the protocol requires.
- HEADs at RESUME (verified against Git, not trusted from this file):
  `erp-backend` **`3a43ca8`** · `erp-mobile` `b973f64` ·
  `retail-erp-control-web` `ad923df` · `erp-docs` `78fe428`.
- **Discrepancies found at resume:**
  1. The backend was **one commit ahead** of what this file recorded
     (`c05d04c` → `3a43ca8`). The portal handoff is already built and
     committed: `POST portal-handoff`, an exchange that 302-redirects to a
     clean URL, `PortalHandoffService`, and `GET payment-instructions`.
  2. **Migration `0060_portal_handoff_intent` already exists** and was not
     recorded here. It is authorised by the current prompt for exactly this.
  3. The claim that no mobile or website change was needed is **stale**.
  4. `retail-erp-control-web` had **4 uncommitted files**: registration retired
     (CP2, essentially complete) and `PaymentModal.tsx` written but **never
     mounted** — no module imported it.
  5. **The website suite was RED**: 13/14. `PaymentModal.tsx` used
     `rgba(0,0,0,.55)`, which the project's own raw-colour contract refuses.
  6. **CP1 was not started**: mobile had no registration route, and
     `lib/signup.ts` still opened a web URL — the superseded behaviour.
- Baseline suites at resume: backend **100 suites / 1731 tests** green · mobile
  `tsc` clean and **19 pure suites** green · website **13/14**.
- **Superseded-prompt work, retained:** a scan-card artifact, a git-ignored
  `mobile/.env.local` pointing the app at the staging edge, and synthetic
  staging logins (`owner|manager|employee@example.invalid`). The Expo dev
  server and the website-registration acceptance flow are STOPPED.
- Previously completed and preserved: migration `0059`, the permission
  catalogue work, staging, and all documentation.
- Completed task — **migration `0059`**, which publishes the 61-key permission
  catalogue as reference data, so a database built by `prisma migrate deploy`
  alone no longer needs the demo seed to be usable.
- **Do not begin** hosting, production deployment, CI/CD, administrator MFA,
  Bankily integration, real contact delivery, or the IMEI scanner milestone.



### Registration authentication — the security correction is DONE

`erp-backend` `93b13c7`. **101 suites / 1748 tests** green, `tsc` clean,
`prisma validate` clean.

#### Why `isVerified(destination)` is not authentication

It answers for the **most recent consumed verification of an address, ever** —
no bound on when, by whom, or in which attempt. An endpoint issuing a session
on it would hand an Owner session to anyone who could name an address somebody
had once verified, with no password in the story. It keeps its existing callers
but now carries a warning saying exactly what it is not.

#### The chain that replaced it

    one registration attempt
  + one short-lived continuation credential      (15 min, hash-only, single-use)
  + one verification challenge BOUND to it       (verification_intents.challenge_id)
  + successful consumption of that exact challenge
  = one normal Owner session from SessionsService

Every link is re-checked at spend time. The challenge and the continuation are
consumed **in one transaction**, so neither can be spent without the other, and
two concurrent completions yield exactly one session.

Other properties: the destination comes from the **Owner record, never the
request**, so a stolen continuation cannot redirect a code. Completion marks the
contact proved, which is what stops a public idempotency key minting a second
continuation for an account that now has a working password. A resend rebinds,
so an older code stops working.

#### `0061` — needed, and one enum value

`verification_intents` already carries every link of the chain and already
implements and tests single-use consumption under concurrency, so `0061` adds
only `registration_continuation` to `OtpPurpose` — the same shape as `0060`.

The purpose is **distinct from `portal_handoff` on security grounds**:
`resolve()` matches on purpose, so one shared value would make a ticket minted
to open a subscription page spendable to complete somebody's registration. A
test pins this.

`confirmChallenge()` is new because `confirm()` does a destination lookup,
which is precisely the hole.

#### 🔴 Migrations are NOT applied

| Environment | 0059 | 0060 | 0061 |
|---|---|---|---|
| development (`phonestore`) | ✗ | ✗ | ✗ |
| staging (`prisma_staging`) | ✓ | ✓ | ✗ |

`0060` **pre-existed this takeover** (commit `3a43ca8`) — it was not created
here. Applying anything needs the backup and restore-proof ritual in
`docs/22`, and that was not rushed at the end of a long session.

### What remains

- **CP4 — the mobile screens.** `app/(auth)/register.tsx` still does not exist
  and `login.tsx` still calls `openSignup()`. The rules
  (`lib/registration.ts`, 20 assertions) and all EN/AR/FR copy are in place and
  unused. The backend endpoints they need now exist:
  `POST platform/register` (returns a continuation, never a session),
  `POST platform/register/verify/start`, `POST platform/register/verify/confirm`.
- **CP5** — the adversarial audit of the pre-existing portal handoff.
- **CP6** — mount `PaymentModal.tsx`; it is green and still imported by nothing.
- **CP8** — the 37-step real-MySQL and browser acceptance. **Nothing was run
  against a live server or a device this session**, so no synthetic company was
  created, there are no fixtures to clean, and the demo tenant is untouched.
- `docs/21`, `24`, `37`, `38`, `39`.

### Next exact action

Apply `0059`–`0061` to development behind the `docs/22` ritual (backup,
restore proof, clean-database replay), then staging. Then build
`register.tsx` against the three endpoints above and mount the payment modal.

---

### Registration pivot — PARTIAL. Read this before continuing.

All four trees are clean, pushed and green, so the workspace is safe to pick
up. **The milestone itself is unfinished.** What follows is exact.

| Repository | HEAD |
|---|---|
| `erp-backend` | `3a43ca8` (unchanged this session) |
| `erp-mobile` | `14b9d33` |
| `retail-erp-control-web` | `3d0e277` |
| `erp-docs` | *this commit* |

### Done

- **CP2 — website registration retired.** `Register.tsx` is a 58-line stub: the
  old address resolves, renders no form and submits nothing. The landing page no
  longer offers `Create account`. Committed `3d0e277`.
- **CP4 component — the payment modal exists and is green.** Server-driven
  provider list, `dir="ltr"` code, and it states on its face that it takes no
  money. **It is NOT mounted** — no route imports it.
- **CP1 rules — `mobile/lib/registration.ts`** with 20 pure assertions, and the
  full EN/AR/FR vocabulary (**1796 keys each**, identical order). Committed
  `14b9d33`.
- **CP3 backend was already built** by the interrupted session (`3a43ca8`):
  `POST portal-handoff`, an exchange that 302-redirects to a clean URL,
  `PortalHandoffService`, `GET payment-instructions`, and migration
  `0060_portal_handoff_intent`.

### Two defects found in the interrupted session's uncommitted work

Both were in `PaymentModal.tsx`, and both were found by **running the gates**
rather than reading the file:

1. A raw `rgba(0,0,0,.55)` scrim. The project's own colour contract test
   refuses it, so the website suite was **red at baseline** — and it would have
   been wrong in dark mode too. There is a `--surface-scrim` token for this.
2. A `ref` passed to the shared `Button`, which does not forward one. `tsc -b`
   **and the production build** both failed, while `vitest` passed — because
   vitest does not typecheck. A green test run was not a green repository.

### What remains — none of this is started

- **CP1 screen.** `mobile/app/(auth)/register.tsx` does not exist. `login.tsx`
  still calls `openSignup()`, which opens a browser — the superseded behaviour.
  The rules and every translation key are in place and unused.
- **CP1 verification UI**, against the existing
  `verify-contact/start` ` / confirm` endpoints.
- **🔴 OPEN DESIGN QUESTION — the post-verification session.**
  `POST /platform/register` returns `{companyId, publicStoreId, branchId,
  ownerUserId, status, created}` and **no tokens**. The brief forbids replaying
  the registration password to simulate login, so the Owner session must be
  issued another way.
  `ContactVerificationService.isVerified(destination)` exists and looks like the
  obvious binding — **it is not sufficient on its own.** As written it answers
  for the most recent consumed verification of that destination, so an endpoint
  trusting it alone would let anyone who ever verified a contact mint an Owner
  session with no password. Any design must bind to the specific registration
  attempt, be single-use and short-lived. **This was deliberately not
  improvised at the end of a long session.**
- **CP3 mobile half** — open the portal via the handoff. `.env.local` already
  exports `EXPO_PUBLIC_PORTAL_URL`.
- **CP4 wiring** — mount the modal in `Portal.tsx`, auto-open once after a
  handoff, reopenable.
- **CP5 / CP6**, the backend / mobile / website test lists, the 40-step
  real-MySQL and browser acceptance, and `docs/21`, `24`, `37`, `38`, `39`.

### Verification at this checkpoint

- Backend **100 suites / 1731 tests** green (untouched this session).
- Mobile `tsc` clean · `expo lint` clean · **20 pure suites** · EN/AR/FR
  **1796 keys**, identical order.
- Website **14/14** · `tsc -b` clean · **production build clean** · oxlint clean.
- No migration was added this session; `0060` already existed.
- **Nothing was run against a device, and no acceptance flow was executed.**
  No synthetic company was created, so there are no fixtures to clean and the
  demo tenant is untouched.

### Next exact action

Settle the post-verification session design first — it gates CP1's final step
and it is the only genuinely security-weighted decision left. Then build
`register.tsx` against the rules already in `lib/registration.ts`, wire
`login.tsx` to navigate internally instead of calling `openSignup()`, and mount
the payment modal.

---

### HEADs — all four repositories clean and level with their remotes

| Repository | HEAD |
|---|---|
| `erp-backend` | `c05d04c` |
| `erp-mobile` | `b973f64` (unchanged — no mobile change was needed) |
| `retail-erp-control-web` | `ad923df` (unchanged — no website change was needed) |
| `erp-docs` | *this commit* |

Nothing was force-pushed and no shared history was rewritten.

---

## The defect this closed

**A tenant's authority is only ever as complete as the catalogue behind it.**
`AccessService` resolves permissions solely from `role_permissions`, and those
rows can only reference `permissions` rows that exist.

Until now **no migration created the catalogue.** The base keys — `sale.create`,
`report.view`, `user.manage` and 14 others — were inserted only by
`prisma/seed.ts`. Later feature migrations each added the handful of keys they
introduced, which is how a deploy-only database reached exactly **44 of 61**.

**The demo seed concealed it** by doing two jobs at once: it seeds the reference
catalogue *and* the demo company. Every environment anybody had looked at ran
it, so the catalogue was always complete there. Staging — the first environment
built deliberately without the demo company — was the first to show the gap, and
did so loudly, because the role repair refused to provision a partial Owner.

---

## Migration `0059_permission_catalogue_reference_data`

**Reference data only.** It inserts catalogue rows and grants nothing:

- no schema change — no `ALTER`, no `CREATE TABLE`, no Prisma schema edit;
- no `role_permissions`, so no role's authority moves;
- no tenant, user, branch, subscription, sale or demo record;
- **no existing row modified.**

`NOT EXISTS`, never `INSERT IGNORE` or `REPLACE`. `IGNORE` would also swallow a
genuine error — a truncated label under strict mode, a broken constraint — and
leave the catalogue quietly short, the exact class of silent failure this ends.
`REPLACE` would delete and reinsert, discarding ids `role_permissions` points at.

Generated from `src/rbac/role-permissions.ts` by
`scripts/generate-catalogue-migration.ts`, so nobody hand-maintains a second
list of keys. The SQL is an **immutable historical snapshot, not a second
runtime source** — nothing under `src/` reads a migration file, and a test
enforces it.

> **A future permission needs a FUTURE migration. Never edit `0059`.**

### Hashes — unchanged by all of this

| | |
|---|---|
| Canonical key-set SHA-256 | `52b7200d09710a251d424a97fe24900e9dbff01e250195ba73e6e83ab388b4ec` |
| **Role-matrix SHA-256** | `fc577f63451ec8c0792b8dc034f33f5dabbf402f2190a6cb75647c51933cf687` |
| Full-canon SHA-256 | `0ddb8c04314656dc98f4c293726dedc2dcefbdc414fc1d78fd0ae967af9d668e` |

Owner 61 / Manager 43 / Employee 20, unchanged. No permission key was added,
removed, renamed or reinterpreted.

---

## Proof, on real disposable MySQL databases

Both were dropped afterwards; no `%proof%` database remains.

### Clean installation — `prisma_staging_cleaninstall_proof`

Migrations only, **no demo seed**: 58 applied, highest `0059`, **61 keys**, and
`companies=0 users=0 roles=0 role_permissions=0 sales=0`. Then, live against a
backend on port 3012: **25 of 25 checks passed** — self-registration succeeded on
a seedless database, its roles received exactly **61/43/20**, entitlement was
`pending` and business actions gated, activation worked, the Owner reached a
`report.view` route with `x-branch-id`, Manager was allowed `report.view` and
denied `user.manage`, Employee was denied both and allowed the sales surface,
all three tenant roles were refused by the platform administration API, and a
branch the tenant does not own was refused.

### Upgrade path — `prisma_staging_upgrade_proof`

Built to the pre-`0059` state (57 migrations, **44 keys**), per-row checksums
captured, then `0059` applied:

- **exactly 17 rows added** (44 → 61);
- **all 44 pre-existing rows byte-identical** in id, key and label;
- replaying `migrate deploy` — "No pending migrations to apply" — changed nothing;
- re-executing the statement under `STRICT_ALL_TABLES` left the catalogue
  fingerprint identical, ids included.

**The 17 keys:** `branch.manage`, `closing.perform`, `cost.view`,
`discount.apply`, `discount.override`, `expense.manage`, `import.run`,
`integrations.manage`, `purchase.manage`, `report.view`, `sale.create`,
`sale.return`, `settings.manage`, `supplier.manage`, `unit.add`,
`unit.transfer`, `user.manage`.

---

## Applied to staging

Behind `scripts/staging-apply-migrations.ts`: `.env.staging` with
`override: true`, `APP_ENV=staging`, a database name that is unmistakably
staging, a `mysqldump`, and a **restore-proof** of that dump into a disposable
database (83 tables, 61 permission rows) which was then dropped.

Staging already held all 61 keys from the earlier repair, so as predicted the
migration **recorded itself and changed no data**:

| | Before | After |
|---|---|---|
| Catalogue | 61 | **61** |
| Roles / mappings | 6 / 248 | **6 / 248** |
| Role-mapping checksum | `c2cf1e55732161f7` | **`c2cf1e55732161f7`** |
| Repaired companies | 124 mappings each | **124 each** |

No manual catalogue bootstrap was needed afterwards. The gate reports
`61/61 canonical keys present`.

---

## Verification

| Gate | Result |
|---|---|
| Backend suite | **99 suites / 1714 tests, all pass** (was 98 / 1698) |
| Backend `tsc --noEmit` | clean |
| `prisma validate` | valid |
| Migrations | **58 in the tree, highest `0059`** (`0005` has never existed) |
| Staging migration status | 58 applied, **0 pending** |
| Catalogue gate vs staging | `61/61 present`, exit 0 |
| Generator drift check | in step with the canonical source |
| Website `tsc` · tests · build · audit · oxlint | clean · **14/14** · clean · **0 vulnerabilities** · 0 errors, 4 pre-existing warnings |
| Mobile `tsc` · pure suites · i18n parity | clean · 9 files, 0 failures · **en/ar/fr 1752 each** |

**Staging acceptance after the migration: 33/33 original, 44/44 expanded.**

### Demo integrity — unchanged

1 company · 9 users · 7 sales · **10 051.00 MRU** · 7 roles · 159 mappings ·
catalogue 61 · 0 subscription payments · 0 administrative grants ·
role-mapping checksum **`ee023046b819dbfd`** before and after.

---

## ⚠ The one thing deliberately left undone

**The development database was not migrated**, because the task's binding
boundaries forbid touching it. `npx prisma migrate status` against `phonestore`
therefore reports `0059` as pending. That is expected, not a defect:

- it is a **data-only** migration, and dev already holds all 61 keys from the seed;
- applying it there is a one-command no-op whenever someone chooses —
  `npx prisma migrate deploy`.

### Takeover discrepancies

**None.** Every stated expectation matched: HEADs `44ceddd` / `b973f64` /
`ad923df` / `849fca7`, 98 suites / 1698 tests, 57 actual migrations with `0058`
highest and `0005` genuinely absent, no pending migration, 61/43/20, full-canon
SHA-256 `0ddb8c04…`, staging healthy on 8088, four repositories clean and level,
`READY_FOR_HANDOFF` under owner `NONE`.

*(Carried forward from the previous session, still unresolved and still out of
scope: the website suite once reported "no tests" and exited 0 — a false-green
risk for any CI eventually configured. It did not recur in any run this session.)*

---

## State of staging

**Retained and healthy on port 8088.** Single origin preserved; `/admin` is
loopback plus administrator authentication; the API binds loopback only.

- Two fixtures kept: `Staging Test Shop` and `CP4 Shop …`, both with 124
  mappings.
- Acceptance-run tenants removed; administrator sessions revoked; unexpired
  verification codes consumed; **44 audit events preserved**.
- The temporary staging administrator is **deliberately kept** — removing it
  would make the control portal inaccessible.
- All identities synthetic (`@example.invalid`, RFC 2606). No real customer,
  employee or business information exists in staging.
- Temporary ports released: the clean-install backend on 3012 is stopped, and
  both disposable databases are dropped. Only `3011` (loopback), `8088` and
  MySQL `3306` listen.

---

## Next exact action

Nothing is in flight. The permission catalogue is now complete on any database
built by `migrate deploy` alone, and the gate refuses a deployment that is not.

The remaining open decisions are unchanged from the staging checkpoint and are
the Owner's to make: **where staging should be hosted**, and **the private-access
layer for `/admin`** — see [`docs/39`](docs/39_STAGING_ENVIRONMENT.md).

**This is not a production readiness statement.**
