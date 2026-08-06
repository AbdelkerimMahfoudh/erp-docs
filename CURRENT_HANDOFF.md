# ERP Current Handoff

## Session control

- Status: READY_FOR_HANDOFF
- Active account: NONE
- Owner: NONE (last worked by CLAUDE-B)
- Session started / started_at_utc: 2026-08-06 03:55 UTC (CLAUDE-B, Stage 3.1)
- Last updated: 2026-08-06 04:23 UTC
- Current authorised task: **none — F1 Stage 3.1 is complete.** Awaiting an
  explicit user instruction. The next planned step (Stage 4 OTP) is not
  authorised and is blocked on a provider choice + an auth-contract decision.
- Last completed checkpoint: **F1 Stage 3.1 complete** — the incorrect-credential
  decision tree now fails closed (backend `8a5ee5c`), the mobile recovers without
  lock-out and keeps its device credential on logout (mobile `2188a34`), secret
  exposure was re-verified, and the docs' Stage 4 "no migration" claim + the
  company-ambiguous mobile key were corrected/reported. All committed, pushed and
  live-verified; three trees clean.
- Takeover history: CLAUDE-B resumed after CLAUDE-A completed F1 Stage 3.
  Verified `READY_FOR_HANDOFF`/`NONE`, all three trees clean and level with
  origin, and every expected HEAD/migration/test count matched exactly at
  takeover (backend `91bbb44`, mobile `e5b7db6`, docs `647beea`, migration
  `0023`, 36/367).
- Takeover history:
  1. CLAUDE-B resumed its own completed Stage 1 from `READY_FOR_HANDOFF`/`NONE`.
     HEADs at that takeover: backend `564b3b9` · mobile `2e63aa8` · docs
     `5ba0e01`; migration `0020` applied.
  2. **2026-08-06 00:05 UTC — CLAUDE-A took over from CLAUDE-B, explicitly
     authorised by the user because CLAUDE-B reached its five-hour account
     limit mid-implementation.** Not concurrent editing: CLAUDE-B has stopped.
     Its last handoff was **interrupted** — the file still said
     `IN_PROGRESS / CLAUDE-B` and its "Work currently in progress" section was
     stale (it described Stage 2 as *blocked at the audit gate*, while commits
     `cfa2dc8` and `a7ff563` show the gate was resolved and the Stage 2 core
     landed). Three files were left uncommitted; all were preserved and are
     described under "Work currently in progress".
- HEADs verified at the CLAUDE-A takeover (after `git fetch`, all level with
  `origin`): backend `a7ff563` · mobile `2e63aa8` · docs `8115067`.
  Migration `0021` applied; `prisma migrate status` clean.
- Last completed checkpoint: **F1 Stage 3 complete** — device identity (0023),
  legacy-session adoption, device APIs, Security → Devices screen, plus a Stage 2
  lifecycle fix. All committed, pushed and live-verified.

## Repository state

All clean, all `master`, all pushed and level with `origin`.

| Repository | Branch | Local HEAD | Remote HEAD | Working tree |
|---|---|---|---|---|
| Backend (`erp-backend`) | master | `8a5ee5c` | `8a5ee5c` | clean |
| Mobile (`erp-mobile`) | master | `2188a34` | `2188a34` | clean |
| Documentation (`erp-docs`) | master | *current HEAD contains this handoff* | same | clean |

Stage 3.1 commit trail — backend `8a5ee5c` (fail-closed device recognition),
mobile `2188a34` (fail-closed recovery + logout/credential consistency), docs
`42f82e2` (ownership) + the commit carrying this handoff. No new migration.

Stage 1 commit trail — backend: `5638a52` (protocol), `1991a01` (schema+0020),
`564b3b9` (Users API+tests). Mobile: `89466ed` (protocol), `2e63aa8` (Team
screen). Docs: `60f718c` (protocol+ownership) + the commit carrying this handoff.

**Note:** the documentation row is deliberately not a hash. A file cannot
contain the id of the commit that introduces it, and writing a follow-up commit
just to record the previous one produces an endless self-referential chain. To
read it: `git -C <docs repo> log --oneline -1`.

**Layout:** the documentation repository is the **workspace root**
(`C:\wamp64\www\PhoneStoreERP`). `backend/` and `mobile/` are nested inside its
working tree but are separate repositories, excluded via the root `.gitignore`.
From either code repository the documentation repository is the **parent
directory** (`../`), not a sibling.

## Verified baseline

Measured by CLAUDE-B on 2026-08-06 after F1 Stage 3.1.

- Backend tests: **37 suites / 377 tests passing** (`npx jest`) — Stage 3.1 added
  `auth.service.spec.ts` (10: the A–E login decision tree + 20 repeated claims
  → 0 device rows)
- Backend TypeScript: clean · Mobile TypeScript: clean · Expo lint: clean
- Latest Prisma migration: **`0023_device_identity`** (Stage 3.1 added no
  migration — it is behaviour + docs only)
- Database migration status: *"Database schema is up to date!"*, **22 migrations**
- Stage 3.1 live verification (backend on :3010, fixtures fully removed, DB clean):
  - **A** no credential → enrolls, secret once, `trustMethod: password`
  - **B** valid pair → recognised, no secret returned, no re-enrollment
  - **C** known id + wrong secret → `401 { code: device_unrecognized }`, **no new
    device**, no secret echoed
  - **D** unknown id + secret → 401, not enrolled
  - **E** revoked credential → 401, no new trusted device
  - Repeated bad claims → device count **unchanged** (no unbounded growth)
  - Device list shows the revoked device as history + the current one; **no
    secret / secretHash / argon2**, every `otpVerified` false
  - Owner lists an employee device (200, no secret); employee on the Owner route
    → **403**; a cross-user credential (faithful cross-company) → 401 fail-closed
  - Logout set `reverifyRequired`; recognition still succeeded next sign-in (no
    lock-out with no OTP). Mobile now KEEPS the credential on logout so the flag
    governs the same device
  - Cleanup: all test device rows + sessions deleted, `settingsprobe` restored to
    its backed-up hash and `is_active = 0`. **+1 append-only `audit_logs` row**
    (the E revoke). Users 6, `user_devices` 0
- Live verification (2026-08-06, backend on :3010, fixtures fully removed):
  - First sign-in with no credential **enrolls**; `trustMethod: password`;
    43-char secret, distinct from the public id
  - Returning sign-in presenting the pair is **recognised** — no re-enrollment
  - A **wrong secret** is not a login failure (the password was right): it
    enrolls a *new* device and leaves the old one alone
  - Device list: current one flagged, **no secret, no `secretHash`, no
    `argon2`** anywhere in the payload; every `otpVerified` false
  - Revoking another device killed its session (1 revoked) and left the current
    session working; the revoked row **stays listed as history**
  - A **revoked credential cannot re-enroll as trusted** — it becomes a new
    device and the old row stays revoked
  - Revoke is idempotent (`alreadyRevoked: true`, 0 sessions)
  - Revoking the **current** device returns `wasCurrent: true` and the token is
    401 on the next call
  - **Explicit logout** set `reverifyRequired: true`; the device is still
    recognised (no lock-out with no OTP to recover) and `otpVerified` stays false
  - Reopening the app and restoring a session left `reverifyRequired: false`
  - Employee sees only their own device; **403** on the Owner list route
  - Owner listed and revoked an employee device (session died, 401); a
    cross-user device id under that employee → **404**
- Migration-only deployment proof: a temp database restored from the pre-`0023`
  backup ran `migrate deploy` **with no seed** — `user_devices` created,
  `device_record_id` added, **all 65 existing sessions preserved and unbound**,
  enum `('legacy','password','otp')`, FKs `RESTRICT`/`CASCADE` as designed.
  Re-running the SQL twice changed nothing. Temp database dropped.

## Completed milestones

- Design-system foundation: tokens, i18n (EN/AR + RTL), primitives, overlays,
  camera scanner, Product Confirmation Card, frontend permission awareness
- Screens: Sell (POS), Receive, Inventory, Catalog, Analytics, Daily closing
- Inventory: cursor pagination + server-side search; accessory/quantity stock fixed
- Scanner confidence correction; durable recognition outbox (transactional,
  lease-based, no Redis)
- Purchase idempotency (client request identity + payload fingerprint)
- Role migration to Owner / Store Manager / Store Employee (`0016`–`0018`),
  with a SQL-vs-TypeScript drift test
- **Phase E — Settings foundation (`0019`): complete.** `company_settings`
  (return window, WhatsApp summary preferences, auto-lock maximum) and
  `receiving_accounts`; `GET/PUT /settings`, receiving-account create/patch/
  reorder; Owner Settings screen in EN/AR
- Backup/restore hardened: `--hex-blob` mandatory, tested dump sanitiser,
  restore drill verified end to end
- F0 read-only audit of Users/auth/device security → [`docs/23`](docs/23_USERS_AUTH_AUDIT_AND_PLAN.md)
- **F1.1 — deactivation/session hardening: complete** (backend `318ea81`).
  Access tokens are now bound to their `auth_sessions` row (`sid`) and every
  request revalidates the session (not revoked/expired) + the user (active, not
  deleted). Deactivation atomically sets `is_active=false` AND revokes all the
  user's sessions, so access + refresh tokens die immediately and reactivation
  does not revive them (fresh login required). Live-verified end to end. Note:
  pre-existing access tokens without `sid` are now rejected — a one-time re-login
  for anyone currently signed in.
- **F1 Stage 1 — contactable users (`0020`): complete.** Nullable `phone`
  (E.164), `email`, `phoneVerifiedAt`, `emailVerifiedAt` on `User` +
  `@@unique([companyId, phone])`; Owner-only `GET/GET:id/PATCH /v1/users`
  (name/phone/email/active, no role or password field); mobile Team screen
  (EN/AR). Existing users untouched; no hard delete; contact change resets
  verification. See [`docs/23`](docs/23_USERS_AUTH_AUDIT_AND_PLAN.md) Stage 1.
- **F1 Stage 2 — branch-scoped delegated `price.edit`: complete**
  (`cfa2dc8`, `a7ff563`, `0b6cbd9`, `7047c93`, mobile `80bc285`).
  The no-branch resolution path now returns only company-scoped permissions, so
  branch authority cannot leak; unknown permissions default to branch-scoped.
  `UserBranchPermission` attaches a grant to ONE assignment (`0021`), `0022`
  makes `price.edit` survive a seedless `migrate deploy`, and
  `PUT|DELETE /v1/users/:userId/branches/:branchId/delegations/price-edit`
  grants and revokes it idempotently, Owner-only. Only `price.edit` is
  delegatable, only to a Store Manager, and the client never names a permission
  — it is in the route path. See [`docs/23`](docs/23_USERS_AUTH_AUDIT_AND_PLAN.md)
  Stage 2.
- **F1 Stage 3 — device identity (`0023`): complete** (CLAUDE-A; backend
  `91bbb44`, mobile `e5b7db6`). Server-issued `UserDevice` (public UUIDv7 + a
  32-byte secret returned once, only the Argon2id hash stored), session linkage,
  atomic device revocation, legacy-session adoption, Owner device APIs, and a
  Security → Devices screen. See [`docs/23`](docs/23_USERS_AUTH_AUDIT_AND_PLAN.md)
  Stage 3.
- **F1 Stage 3.1 — device-security hardening: complete** (CLAUDE-B; backend
  `8a5ee5c`, mobile `2188a34`). Login now fails a wrong/unknown/revoked/foreign
  device credential **closed** instead of enrolling a new trusted device, decided
  before any session exists; repeated bad claims create nothing. Mobile recovers
  from the fail-closed error (forget + re-enroll) and keeps the credential on
  logout for `reverifyRequired` consistency. Secret exposure re-verified; pino
  redaction extended. docs corrected: the mobile credential key is
  company-ambiguous (needs an auth-contract change), and **Stage 4 needs a fresh
  backup + an additive OTP-challenge migration** — the enum value alone is not an
  OTP implementation. See [`docs/23`](docs/23_USERS_AUTH_AUDIT_AND_PLAN.md)
  Stage 3.1.

## Work currently in progress

**Nothing. F1 Stage 3.1 is complete, committed, pushed and verified.**

- Uncommitted work: none in any repository.
- Migrations applied this session (Stage 3.1): **none** — behaviour + docs only.
  Latest remains `0023_device_identity`.
- Temporary databases: none.
- Temporary fixtures: `settingsprobe` was briefly reactivated with throwaway
  passwords for the device live tests, then **restored to its backed-up Argon2id
  hash and `is_active = 0`**. All test `user_devices` rows and their sessions were
  deleted. Users 6, `user_devices` **0**.
- Unavoidable append-only rows: **+1 `audit_logs` entry** (a `UserDevice`
  status_change from the case-E revoke). Total **92**.
- No financial or inventory record touched.

### Stage 2 lifecycle fix shipped first (backend `0db0fc4`)

An audit of every write path found **no role-management API exists** — only
`prisma/create-user.ts` (a dev utility whose upsert doubles as a role changer)
and the seed's legacy remap can change a `UserBranch` role, and nothing anywhere
deletes an assignment. The CLI did not prune delegated grants, so a downgrade
followed by a re-promotion would have silently restored `price.edit`.

The rule now lives in `src/rbac/delegation-lifecycle.ts` — used by the CLI today
and required of any future role API — and prunes inside the same transaction as
the role change. Cascade re-verified on the live database.
Deactivation is deliberately **not** a lapse: it does not change the role, the
Owner withdrew nothing, and F1.1 already cuts off access.

### Uncommitted work inherited from CLAUDE-B — all resolved

| Repo | File | Outcome |
|---|---|---|
| docs | `CURRENT_HANDOFF.md` | The `0021` checkpoint was kept and extended by this update |
| backend | `src/users/user-management.service.ts` | **Completed, not rewritten.** Its direction was right; the only thing dropped was a speculative `GrantDto` import, because the shipped contract names the authority in the route path and accepts no permission key from the client. Committed in `7047c93` |
| mobile | `lib/permissions.ts` | Kept — the `price.edit` catalogue addition. Committed in `80bc285` |

The backend tree did not compile at takeover (`./dto/grant.dto` was missing);
it does now. The Stage 1 spec harness — which predated the new `permissions`
select and was the deeper reason that suite failed — was updated to model
assignments and grants for real.

## Stage 2 branch-authorization audit (hard gate) — FIRED, then RESOLVED

> **Historical.** Kept because it explains why the delegation model is
> assignment-scoped rather than user-scoped. The leak described below was
> closed by `cfa2dc8` before any delegation shipped.

`AccessService.getEffectivePermissions(userId, branchId?)`:
- **With** `branchId` (from the `X-Branch-Id` header): permissions for the user's
  role **at that branch only**, and it 403s if the user is not assigned there.
  This path is sound and branch-scoped.
- **Without** `branchId`: it **unions permissions across every `UserBranch`
  assignment**. Consumers that can hit this path with no `X-Branch-Id`:
  `permissions.guard`, `auth.controller /auth/permissions`,
  `cost-gating.interceptor`, and company-level services (`settings`).

A user can be Store Manager in branch A and Store Employee in branch B (role is
per `UserBranch`). With no `X-Branch-Id`, the union grants manager authority
company-wide. Permissions are resolved per request (not embedded in the JWT) and
cached per-request (CLS) server-side and per-branch (react-query) on the client.

**Why this blocks Stage 2:** if a delegated `price.edit` grant were added to the
union, a grant made for branch A would apply in every branch whenever a request
omits `X-Branch-Id` — exactly the leak the gate forbids. Per the instruction,
**stop before the migration and report.** A safe design exists (delegated grants
resolved only in the branch-scoped path and excluded from the union; price
endpoints must require `X-Branch-Id`), but the approach is a user decision.

## Product and architecture decisions affecting the current task

No implementation task is authorised, so only the standing constraints apply.

- [`docs/21_PRODUCT_DECISIONS.md`](docs/21_PRODUCT_DECISIONS.md) — approved
  product decisions and their four-state reconciliation (Implemented /
  Approved-not-implemented / Blocked / Needs-decision). **Authoritative for
  intended behaviour.**
- [`docs/22_BACKUP_AND_ROLLBACK.md`](docs/22_BACKUP_AND_ROLLBACK.md) —
  mandatory before any schema migration.
- [`docs/23_USERS_AUTH_AUDIT_AND_PLAN.md`](docs/23_USERS_AUTH_AUDIT_AND_PLAN.md)
  — F0 audit and the dependency-ordered F1 plan, if Users work is authorised next.
- [`CLAUDE.md`](CLAUDE.md) — the development rulebook. Wins over habit and
  convenience.

Standing rules worth restating: authorization is **permission-based, never
role-name-based**; business rules and permissions are enforced **server-side**;
nothing financial is hard-deleted; schema changes need a written reason and a
migration.

## Known gaps and blockers

| Gap | Type |
|---|---|
| `unit.transfer` guards all five transfer endpoints — one permission both initiates and completes a transfer | Product decision required, then technical work |
| `purchase.manage` creates a **final** purchase immediately; the approved model wants employee-entered cost to await approval | Product decision required, then technical work |
| `import.run` guards **no endpoint at all** | Technical work required |
| Request/approval splits (`return.request`, `import.prepare` / `import.approve`) | Deferred — belong to Returns and Import workflows |
| Mobile device-credential storage key is **company-ambiguous** (login-only); a collision-free key needs an **auth-contract change** — a company/store id known before login (docs/23 Stage 3.1). Fail-closed recovery prevents lock-out meanwhile | Product decision required |
| WhatsApp/OTP provider unchosen — blocks real OTP delivery and end-to-end invitation/new-device verification | Product decision required |
| **Stage 4 OTP needs a fresh `--hex-blob` backup + an additive OTP-challenge migration** (durable challenge state: purpose, target, destination snapshot, hashed code, expiry, attempts, states, resend, idempotency). The `otp` enum value + `otpVerifiedAt` are only the *outcome*, not an implementation | Technical work + provider choice |
| Camera, haptics, Arabic RTL end-to-end, receipt sharing, scroll-triggered pagination, and all bottom sheets | **Real-device verification required** |
| `settings.discount_limits_by_role` still names retired roles (`sales_employee`, `branch_manager`); nothing reads it | Deferred — belongs with discount monitoring |
| `mobile` has no test runner; adding one is a new dependency | Deferred — needs explicit approval |
| Subscription / seat enforcement | Deferred intentionally |

## Database safety

- Shared database: **`phonestore`** on local MySQL 8.4.7 (WAMP). Treat as shared
  mutable state — both accounts use the same instance.
- Latest verified backup: **`~/erp-backups/phonestore-20260805-213342.sql`**
  (178 854 bytes, trailer `-- Dump completed on 2026-08-05 21:33:44`, `--hex-blob`,
  0 raw `_binary` literals, 1431 hex literals). Taken by CLAUDE-B immediately
  before migration `0020`. (Prior verified backup with full restore drill:
  `phonestore-20260805-203646.sql`.)
- Backup taken before latest migration: yes — `phonestore-20260805-213342.sql`
  precedes `0020_user_contact_fields`.
- **Post-`0021` backup (CLAUDE-A, before migration `0022`):**
  **`~/erp-backups/phonestore-20260806-005021.sql`** — 186 087 bytes, trailer
  `-- Dump completed on 2026-08-06  0:50:22`, `--hex-blob`, 0 raw `_binary`
  literals, 1479 hex literals, valid UTF-8 round trip, contains
  `user_branch_permissions` and `price.edit`.
- **Pre-Stage-3 backup (CLAUDE-A, before migration `0023`):**
  **`~/erp-backups/phonestore-20260806-022141.sql`** — 187 935 bytes, trailer
  `-- Dump completed on 2026-08-06  2:21:42`, `--hex-blob`, 0 raw `_binary`,
  1494 hex literals, valid UTF-8 round trip, contains `auth_sessions` rows.
- Temporary databases: **none.** Scratch databases must be named `prisma_*`
  (the migrator's grants cover `phonestore` and `prisma\_%` only) and dropped
  after verification.
- Demo records that must not be deleted: companies 1 · branches 2 · users 6 ·
  products 12 · units 11 · sales 7 · purchases 9 · audit_logs **92**
  (append-only; grew from Stage 1 / F1.1 / Stage 2 / Stage 3 / Stage 3.1 live
  verification — legitimate contact/device/status audits, never corruption) ·
  company_settings 1 · receiving_accounts 3 · `user_devices` 0.
- Live-verification side-effects (all benign, on the shared demo DB): during
  Stage 1 and F1.1, `settingsprobe` was temporarily reactivated with throwaway
  passwords for 403/deactivation tests. **F1.1 restored its ORIGINAL password
  hash from the pre-test backup `phonestore-20260805-213342.sql`** (97-char
  argon2id) and left it `is_active = 0` — matching the backup. `owner`/`settingsprobe`
  `last_login_at` + `auth_sessions` reflect normal logins; a few append-only
  `audit_logs` `status_change` rows were added by the deactivation tests. No user
  holds a phone/email (verified: 0). No financial or inventory record was touched.
- `audit_logs` is append-only, enforced by database triggers for the
  application account. Never attempt to edit it.
- **Never** run `prisma migrate reset` against `phonestore`.

No credentials appear in this file. Database and app credentials live in
`backend/.env` and `~/.my.cnf`, neither of which is committed.

## Next exact action

**None authorised. Wait for an explicit user instruction.**

F1 Stages 1–3 and the 3.1 hardening are finished and everything is pushed. When
work is authorised again, the receiving account must, in order:

1. Read this file and the relevant parts of `docs/21_PRODUCT_DECISIONS.md`.
2. `git fetch` and `git status` in all three repositories; confirm the HEADs in
   the table above still match.
3. Run `npx prisma migrate status` before any database-related work.
4. Set `Status: IN_PROGRESS`, the account label and the authorised task here,
   **before** changing anything.

The next planned step — **not authorised yet, and blocked on a provider choice** —
is [`docs/23`](docs/23_USERS_AUTH_AUDIT_AND_PLAN.md) **Stage 4: OTP provider
abstraction**. Two decisions gate it: (a) which WhatsApp/OTP provider; and (b)
the **auth-contract change** for a collision-free mobile device key (a company/
store identifier known before login — docs/23 Stage 3.1). Stage 4 **is a schema
change**: it needs a fresh `--hex-blob` backup and an **additive OTP-challenge
migration** (durable challenge state — the existing `otp` enum value and
`otpVerifiedAt` record only the outcome). Generate the SQL with
`prisma migrate diff --from-schema-datamodel <git HEAD schema> …` (the migrator
cannot reach `phonestore_shadow`) and apply with `migrate deploy`. Do **not**
implement a guessed WhatsApp integration; ship `LogOtpChannel` first.

## Explicit boundaries

Nothing is authorised right now. When the next task is authorised, these stay
off the table until named explicitly:

- **F1 Stage 3** device identity · OTP or WhatsApp providers · invitations ·
  passcodes or biometrics
- **The actual price-editing workflow.** Stage 2 decided *who may*; the Pricing
  phase builds *what they do*. Nothing in the app should imply it already exists
- Below-cost delegation — `discount.override` stays Owner-only and undelegatable
- Subscription seats · technician work · Returns, Loans or Consignment
- Widening any permission to close the two approval gaps above
- Adding dependencies to either code repository
- Deleting demo data, resetting the database, or force-pushing any repository
- Editing an applied migration. `0021` and `0022` are recorded in
  `_prisma_migrations`; corrections move forward as a new migration

---

## Appendix — bootstrap corrections (2026-08-05, CLAUDE-A)

The bootstrap instruction listed prior state to *verify rather than copy*. Six
items differed from repository and database evidence:

| Reported | Verified | Explanation |
|---|---|---|
| 26 suites / 181 tests | **28 suites / 235 tests** | Settings, sanitiser and role-matrix suites were added after that report |
| Latest migrations `0017`/`0018` | **`0019_settings_foundation`** | Phase E landed and is applied |
| Phase E/Settings "treat as not started" | **Complete** | Evidence: migration `0019` applied, `backend/src/settings/`, `mobile/app/settings.tsx`, live-verified API and screen |
| Store Employee assignments: 5 | **7** | 2 belong to `settingsprobe`, a **deactivated** account created by CLAUDE-A on 2026-08-05 to prove employee 403s. `is_active = 0`; kept so its audit trail stays attributable |
| — | `0017_store_role_backfill` appears **twice** in `_prisma_migrations` | The first attempt failed on a wrong column and was resolved with `migrate resolve --rolled-back`; the second succeeded. Not drift — `migrate status` reports the schema up to date |
| A "web-only BottomSheet defect" recorded earlier | **Withdrawn** | A measurement artifact: the automated browser pane reports `visibilityState: hidden`, so `requestAnimationFrame` delivers zero frames and every animation sits frozen at its initial value. See `docs/21` |

Confirmed correct as reported: Owner assignments 4 · legacy Sales/Warehouse
assignments 0 · permission matrix Owner 17 / Store Manager 11 / Store Employee 6
· inventory pagination, scanner-confidence correction, recognition outbox and
role migration all complete · demo data intact · both approval gaps still open
· real-device verification still outstanding.
