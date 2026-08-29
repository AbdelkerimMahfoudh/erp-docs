# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF** — all four trees clean and pushed. CP4 is
  complete and CP8 has been run live.
- Active account / Owner: **NONE** (last worked by CLAUDE-B)
- Live acceptance result: **66/67**, one item device-pending. Six defects found
  and fixed; none of them was visible to 1,787 passing tests.

| Repository | HEAD |
|---|---|
| `erp-backend` | `343191e` (after `96a75a2`, `4380f1e`, `06e081c`) |
| `retail-erp-control-web` | `c764d63` |
| `erp-mobile` | `a710d64` (unchanged — no mobile source was touched) |
| `erp-docs` | *this commit* |






### CP4 complete. CP8 run live: **66/67**.

The environment: the documented single origin, reproduced without Docker (it is
not installed here) as a Node transcription of `deploy/nginx-site.conf` — same
headers, same SPA fallback, same `/admin` loopback rule. API on :3011 bound to
loopback, edge on :8088. `docs/39`'s measured boundary table reproduced exactly:
API direct from the LAN refused, `/admin` 404 from the LAN and 200 from
loopback, `/account` and `/api/health` 200 from the LAN.

#### Six defects, found by running it

| # | What | Where |
|---|---|---|
| 1 | Manager and Employee could each mint an Owner portal ticket (**201**) | `platform.controller.ts` |
| 2 | The one-time ticket was written to the log in full, twice per request | `app.module.ts` |
| 3 | A **pending** shop was refused the payment instructions, so the dialog silently never opened | `route-classification.ts` |
| 4 | `Secure` cookies on plain-HTTP staging — discarded by the browser, hidden by localhost | `cookies.ts` |
| 5 | The portal gated on a bearer token, so arriving from the app showed a password form | `Portal.tsx` |
| 6 | Cleanup proposed deleting the staging baseline, and promised tenant deletions it can never make | `staging-cleanup.ts` |

Every one had a green suite around it at the time. Each fix carries a
regression test naming the live run.

#### CP4 — both missing halves proved

**Role refusals**, over real HTTP with real users of a real company: Manager
403, Employee 403, platform administrator 401 (an admin session is not a tenant
JWT), tenant Owner refused all four administrator routes and refused
`suspend` outright. Another Owner's ticket lands in **their** company. The
handoff is Owner-gated on `settings.manage` — company-scoped, undelegatable,
held by the Owner and the company administrator alone.

**Session fixation**, with actual cookies and actual session rows. An attacker
cookie planted before the exchange acquires nothing (401), the exchange issues a
**new** cookie, the new `auth_sessions` row is bound to the correct Owner and
company (sessions n → n+1, joined back to the Owner's email), the planted cookie
is still worth nothing afterwards, the ticket is consumed exactly once, replay
fails to the same neutral destination, the landing URL is `/account?welcome=1`
and clean, the cookie is HttpOnly + SameSite=Lax + path-scoped, nothing reaches
the log or the audit detail, and **no payment, grant or entitlement transition**
happened.

#### CP8 — 66/67 live, 1 device-pending

52 API/database checks and 22 browser checks, on real MySQL over real HTTP.
Highlights that are easy to under-claim:

- The **real app** was driven in a browser (its web export, served from the edge
  so the origin matches): `Create account` navigated `/login` → `/register`
  with **zero** `window.open` calls, the form asks for no Store ID and no
  personal ID, and the whole registration → verification → session → portal
  chain ran end to end.
- **Item 20 is proved, not asserted.** The app's own request order was
  `register` → `verify/start` → `verify/confirm` (session issued) →
  `portal-handoff` → `portal-session`. The handoff is authenticated, so it
  cannot precede the session.
- The payment dialog was measured with a `fetch` spy: selecting a provider and
  copying a code issue **no network request at all**, a refused clipboard is
  harmless, focus is contained and restored, `Escape` closes, the code stays
  `dir="ltr"` in Arabic, and no payment row exists.
- EN/AR/FR with correct `lang`/`dir`, light and dark, 375 px and 1280 px, no
  overflow, nothing clipped, and **empty** `localStorage`/`sessionStorage`.

**Device-pending: item 25** — browser-opening failure preserving the session. On
a web export a browser cannot be refused the way a phone refuses one. It stays
pinned by unit test and by the ordering above. `docs/24` §9j records what the
browser did and did not cover.

#### Cleanup, and one thing it cannot do

Dry run → `--apply --since --remove-admin` → dry run, all recorded. The scoped
run targeted **38** companies — exactly the 38 created in the window, value-
deduplicated — and left the 3 baseline companies alone. Administrator sessions,
intents, continuations and the temporary administrator are gone; the deliberate
staging administrator is kept; **71 audit events preserved**, 29 with their
`admin_id` released and **all 29 still naming their actor, action, target and
reason**. The replay is a no-op.

🔴 **Staging did NOT return to 3 companies / 7 users.** It is **41 / 56**, and
cannot be otherwise: every table referencing `companies` restricts deletion,
including ones registration itself creates, so `company.delete()` can never
succeed for a registered shop. Deleting children in dependency order is not the
fix — nothing financial is hard-deleted here. Reclaiming them means restoring
the database (`docs/22`).

#### Integrity

**The demo is byte-identical.** 60 migrations through `0061`, permissions 61,
role_permissions 159, checksum `41df5104…`, mappings
`owner=61 administrator=15 branch_manager=13 sales_employee=4 warehouse_employee=3 store_manager=43 store_employee=20`,
1 company, 9 users, 7 sales, **10 051.00**, units checksum `7336ef18…`, audit
559, **0 subscription payments**. Zero CP4/CP8 rows in development.

#### Verification

- Backend **104 suites / 1787 tests** · `tsc` clean · `prisma validate` clean ·
  both databases up to date · catalogue **61/61**.
- Website **37 tests** (32 + 5 new) · `tsc -b` clean · production build clean ·
  oxlint clean.
- Mobile **20 pure suites** · `tsc` clean · `expo lint` clean · **Doctor 18/18**
  · EN/AR/FR **1796** identical · export **68 routes** · raw-colour audit clean
  (its one hit is a comment saying not to) · secure-storage audit clean · every
  `openURL` builds from configuration.
- `sql_mode` on this server is still empty. **Not touched.** Still deployment
  work.

### What remains

1. **`app/subscription-blocked.tsx` opens `accountPortalUrl()` directly**, with
   no handoff ticket — so the one screen where somebody taps "manage my
   subscription" lands them on a sign-in form. It should call
   `openAccountPortal()`, which is now proven end to end. Left alone because no
   acceptance item covers it and it needs its own outcome handling (a Manager
   now gets `refused`).
2. **`lib/signup.ts` is dead code** — nothing imports it. It opens a browser to
   register, which is the behaviour the pivot retired. Removing it also means
   removing `auth.signup.*` from three locales (parity 1796 → 1794) and a line
   from the drift test.
3. **`lib/portal.ts`'s `isTrusted()` comment overstates what it checks** — it
   validates the scheme, not the origin. The origin is correct by construction
   (the URL is built from `API_V1_URL`), so this is a comment, not a hole.
4. `accountPortalUrl()`'s fallback still points at `:5173`, the old Vite dev
   port, not the single-origin edge. Unused when `EXPO_PUBLIC_PORTAL_URL` is set.
5. **Nothing has run on a physical device.** `docs/24` §9j.

### Next exact action

Fix (1) — point `subscription-blocked` at `openAccountPortal()` and handle its
outcome — then (2) and (3). None needs a migration.

---

### CP3, CP5 and CP6 complete. CP4 partly proven. CP8 not started.

| Repository | HEAD |
|---|---|
| `erp-backend` | `7e2f356` |
| `erp-mobile` | `a710d64` |
| `retail-erp-control-web` | `ea80b47` |
| `erp-docs` | *this commit* |

#### CP3 — registration is in the app

`Create account` pushes a screen; nothing opens a browser to register.
`app/(auth)/register.tsx` and `app/(auth)/verify.tsx` run against the exact
CP2-proven contract.

- One idempotency key per attempt, generated on mount, reused on every retry.
- The duplicate guard is a **ref**, because two taps land before React renders.
- The password is cleared the moment registration returns and **never replayed**.
- The continuation lives in SecureStore through the existing wrapper and is
  deleted on success, restart and cancellation.
- **Order is pinned by test:** the session is adopted BEFORE the browser is
  tried, so a refused browser leaves the account and session alone. No failure
  path deletes a valid session, and every portal attempt asks for a **fresh**
  ticket — a spent or uncertain one is treated as spent.
- The URL carries the one-time ticket and nothing else.

The navigation drift test caught both new routes unclassified, exactly as
designed.

#### CP5 — the payment dialog is mounted

Opens once automatically for somebody arriving from the app, closable,
reopenable from a control that is always present. Instructions are fetched
alongside the subscription; **their failure is not the page's failure**.

18 rendering tests, mostly about what must not happen: selecting any provider
sends nothing (asserted against a `fetch` spy), copying sends nothing and
copies the selected provider, a blocked clipboard is harmless, and the dialog
never contains *paid*, *confirmed*, *verified* or *activated*. All five
providers show `00000`; Bankily is default and always returnable to; the code
stays `dir="ltr"`.

#### CP6 — staging cleanup repaired

It **failed outright** before. `platform_audit_events.admin_id` is a nullable
FK with no delete action, so it RESTRICTS; the repair **releases the reference
and keeps the audit event**, which is what the schema always intended.

A second defect surfaced while fixing the first: the synthetic-company `Set`
held `Buffer`s, which dedupe by identity — it reported **7** companies where
staging has **3**. Now dry-run by default (`--apply` to delete), the staging
administrator is preserved unless `--remove-admin`, and unspent continuations
and handoff tickets are expired. 9 focused safety tests.

**No migration.** The schema was right; the script was wrong.

#### CP4 — partly proven

The pre-existing `portal-handoff.spec.ts` already covers **17** of the audit
points: company/user/purpose binding, 90-second TTL, hash-only storage,
single-use, replay refusal, concurrency, expiry, wrong purpose, cross-company,
disabled and deleted users, no payment/grant/subscription change, the ticket
absent from logs, and the HttpOnly cookie. CP2 additionally proved live that a
portal ticket cannot complete a registration.

**Added here:** the `ALWAYS_ALLOWED` list is now pinned **by name**, with tests
that no operational route (sales, units, inventory, purchases, transfers,
returns, refunds, expenses, closing, suppliers, loans, consignments, products,
pricing, goals, imports) survives a lapsed subscription, and that the handoff is
the only `platform/` route allowed through.

**Still unproven:** Manager / Employee / platform-administrator handoff refusal
over real HTTP, and session fixation.

#### Verification

- Backend **102 suites / 1760 tests** · `tsc` clean · `prisma validate` clean ·
  schema up to date · both databases 60 applied through `0061`.
- Mobile **20 pure suites** (identifier drift now 37 assertions) · `tsc` clean ·
  `expo lint` clean · **Expo Doctor 18/18** · EN/AR/FR **1796** identical ·
  web export **68 routes** including both new ones.
- Website **32 tests** (14 + 18 new) · `tsc -b` clean · production build clean ·
  oxlint clean · `npm audit` **0 vulnerabilities**.
- **Demo byte-identical**: 1 company, 9 users, 7 sales, **10 051.00**, units
  checksum `7336ef1871b1216954e2921b1c0e05fa`, role mappings
  `owner=61 store_manager=43 store_employee=20`, **0 subscription payments**.
- Staging intact at 3 companies / 7 users. Verification port released.

### What remains

- **CP8 — the 37-step staging acceptance was NOT run.** No browser or device
  session took place this checkpoint, so no live count is claimed. CP2's 29/29
  HTTP proof stands from the previous session and covers the authentication
  chain, but not the portal in a browser, the dialog on screen, grant/suspend/
  reinstate, or the language and viewport checks.
- The three CP4 items above.
- `docs/37` and `docs/38` were not updated; `21`, `24` and `39` were.
- **Nothing was run on a physical device.** `docs/24` §9j lists 20 checks, and
  they cover most of what this flow actually is — a keyboard, a browser hand-off
  and an app switcher, none of which a type checker opens.

### Next exact action

Run CP8 against staging with a browser: the portal landing, the dialog, all five
providers, grant/suspend/reinstate, and the language and viewport passes. Then
the three remaining CP4 refusals over HTTP.

---

### CP1 — migrations aligned. CP2 — authentication proven over real HTTP.

`erp-backend` `eed3219`. **101 suites / 1748 tests**, `tsc` clean.

#### CP1 · both environments now at `0061`

| | before | after |
|---|---|---|
| development (`phonestore`) | 57 applied, highest `0058` | **60 applied, highest `0061`, zero pending** |
| staging (`prisma_staging`) | 59 applied, highest `0060` | **60 applied, highest `0061`, zero pending** |

Development: target name validated before anything ran, full state recorded,
backup taken (`phonestore-pre0059-20260829-013551.sql`, 555 232 bytes, 83
tables, **0 raw `_binary`**, valid UTF-8), and **restore-proved** into a
disposable database whose every checksum matched the live record exactly.

Staging went through `scripts/staging-apply-migrations.ts`, which owns the
load-bearing `override: true` env-order safeguard, refuses a non-staging name,
and restore-proves its own dump. Catalogue gate after: **61/61**.

Both diffs show **only three lines changed**: the migration count, the highest
migration name, and the `purpose` enum. Permission catalogue, role mappings
(`owner=61 store_manager=43 store_employee=20`), tenant data, subscriptions,
payments and unit checksums all byte-identical.

**Clean replay** on a disposable strict-mode database: full history through
`0061`, schema valid, **61/61 catalogue from migrations alone**, the two
purposes distinct, and **zero tenant or demo rows created**. All three
disposable databases dropped.

> ⚠️ **Finding:** this MySQL runs with an **empty `sql_mode`** — not strict at
> all. The first replay was therefore not a strict-mode replay. It was redone
> with `STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION`
> set globally, and the original empty value restored afterwards. Worth deciding
> whether the server should run strict permanently.

#### CP2 · 29/29 over real HTTP and real MySQL

Backend on port **3012** against staging. Successful path: continuation issued
and **no session**; stored **hash-only**; challenge **bound to that exact
continuation**; code retrieved the staging-only way; completion issues **exactly
one** session; contact marked verified; **both credentials consumed**;
subscription still **pending**; portal handoff available; **protected ERP data
blocked**.

Every adversarial refusal passed: a historical consumed verification, another
registration's challenge, cross-company, a **portal ticket used for
registration**, an expired continuation, a rotated challenge, a wrong code, a
replayed continuation, an unknown continuation, a disabled Owner.

**Concurrency was measured by SESSION ROWS, not HTTP status**: three
simultaneous completions → one session, one 200.

#### Two defects real HTTP found that unit tests could not

1. **Completion died with "Database request error".** `SessionsService.create`
   used its own connection while completion held an exclusive lock on the
   Owner's row; `auth_sessions` has an FK to `users`, so the insert waited on a
   lock its own request held. `create` now takes an optional transaction
   client — which also makes the rollback honest. **The pre-existing portal
   handoff does not have this bug**: it never locks the user row first.
2. **A pending Owner could not create a portal handoff (403).**
   `ALWAYS_ALLOWED` blocks by default so a new route is refused "until somebody
   decides otherwise". Every new shop is pending by definition and this is the
   route to the page that ends that state, so it is now allowed, with the
   reasoning recorded in the rule.

#### Fixtures and integrity

21 synthetic tenants created and **all removed**; staging back to its original
3 companies / 7 users. Both environment snapshots are **identical to their
post-migration records apart from the label line**. Development was never
touched by CP2. Port 3012 released.

> ⚠️ `scripts/staging-cleanup.ts` **fails** with a foreign-key violation on
> `platformAdmin.deleteMany()`. Pre-existing, unrelated to this work, and it is
> why the fixtures were removed with a scoped script instead.

### What remains

- **CP3 — the mobile screens.** Not started. `app/(auth)/register.tsx` does not
  exist; `login.tsx` still calls `openSignup()`. The rules
  (`lib/registration.ts`, 20 assertions) and all EN/AR/FR copy are in place, and
  the endpoints they need are now **proven working**:
  `POST platform/register` → `{ status, created, publicStoreId, verification,
  continuation: { token, expiresAt, expiresInSeconds }, next }`;
  `POST platform/register/verify/start` → `{ delivery }`;
  `POST platform/register/verify/confirm` → `{ accessToken, refreshToken, expiresIn }`.
- Mounting `PaymentModal.tsx` (still imported by nothing), the portal-handoff
  audit, and the browser/device acceptance.

> **The instruction for this session was truncated** mid-sentence in CP3's
> failure handling. Anything after that — further checkpoints, test lists,
> gates, cleanup and documentation requirements — never arrived and was
> deliberately not guessed at.

---

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
