# ERP Current Handoff

## Session control

- Status: IN_PROGRESS
- Active account: CLAUDE-B
- Owner: CLAUDE-B
- Session started / started_at_utc: 2026-08-05 23:04 UTC (CLAUDE-B, second session)
- Last updated: 2026-08-05 23:35 UTC
- Current authorised task: **F1.1 deactivation/session hardening**, then the
  **F1 Stage 2 branch-authorization audit** (a hard gate) and — only if that gate
  passes — **F1 Stage 2** (per-user branch-scoped delegated `price.edit`).
- Active phase and scope: (F1.1) atomically revoke a user's sessions on
  deactivation + bind access-token validity to the session so both token types
  die on deactivation and stay dead after reactivation; restore the `settingsprobe`
  password from the pre-test backup. (Stage 2) audit branch permission resolution
  first; **stop before the migration if permissions union across branches**.
- Takeover history: same account (CLAUDE-B) resuming its own completed Stage 1.
  Verified READY_FOR_HANDOFF / NONE, all trees clean and level with remote.
- HEADs at takeover: backend `564b3b9` · mobile `2e63aa8` · docs `5ba0e01`
  (all match the Stage 1 handoff exactly). Migration `0020` applied, up to date.
- Last completed checkpoint: takeover verified; ownership taken.

## Repository state

All clean, all `master`, all pushed and level with `origin`.

| Repository | Branch | Local HEAD | Remote HEAD | Working tree |
|---|---|---|---|---|
| Backend (`erp-backend`) | master | `564b3b9` | `564b3b9` | clean |
| Mobile (`erp-mobile`) | master | `2e63aa8` | `2e63aa8` | clean |
| Documentation (`erp-docs`) | master | *current HEAD contains this handoff* | same | clean |

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

Measured by CLAUDE-B on 2026-08-05 after Stage 1.

- Backend tests: **32 suites / 286 tests passing** (`npx jest`) — Stage 1 was
  30/266; F1.1 added +2 suites (`jwt.strategy`, `sessions.service`) and +20 tests
- Backend TypeScript: clean (`npx tsc --noEmit`)
- Mobile TypeScript: clean (`npx tsc --noEmit`)
- Expo lint: clean (`npx expo lint`)
- Live verification (Stage 1, against the running backend on :3010, reversible):
  no-token 401; Owner `GET /users` 200 with 6 users, no hashes, derived status,
  branch+role; phone set normalized to E.164 with `phoneVerifiedAt` null;
  duplicate phone 409; invalid phone 400; self-deactivation 400; revert to null;
  employee (`store_employee`) `GET`/`PATCH /users` both 403. Demo left clean
  (0 users with a phone; `settingsprobe` restored to inactive).
- Latest Prisma migration: **`0020_user_contact_fields`** (applied by CLAUDE-B
  via `migrate deploy`; backend `1991a01`)
- Database migration status: `prisma migrate status` → *"Database schema is up
  to date!"*, 19 migrations found, no drift

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

## Work currently in progress

- F1.1 hardening: **complete, committed (`318ea81`), pushed, verified.**
- **F1 Stage 2 (delegated permissions): BLOCKED at the mandatory branch-audit
  gate — no migration created.** See "Stage 2 branch-authorization audit" below.
  Awaiting a user decision on the resolution approach before any schema change.
- Temporary data or databases created: none.
- Uncommitted work: none (docs updated + committed).

## Stage 2 branch-authorization audit (hard gate) — FIRED

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
| Per-user permission overrides do not exist, so "per-user price editing is Owner-delegated" cannot be expressed | Technical work required (F1 stage 2) |
| WhatsApp/OTP provider unchosen — blocks real OTP delivery and end-to-end invitation/new-device verification | Product decision required |
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
- Temporary databases: **none.** Scratch databases must be named `prisma_*`
  (the migrator's grants cover `phonestore` and `prisma\_%` only) and dropped
  after verification.
- Demo records that must not be deleted: companies 1 · branches 2 · users 6 ·
  products 12 · units 11 · sales 7 · purchases 9 · audit_logs **83**
  (was 77; +6 append-only rows from Stage 1 live verification — legitimate
  contact-edit audits, not corruption) · company_settings 1 · receiving_accounts 3.
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

**Awaiting a user decision on the Stage 2 branch-resolution approach** (the audit
gate fired — see above). The two options put to the user:

- **A (recommended):** Build Stage 2 as `UserBranchPermission` grants attached to
  a `UserBranch` row, resolved **only** in the branch-scoped path and **excluded
  from the union**; future price-edit endpoints must require `X-Branch-Id`
  (fail-closed if absent). Narrowest change; delegation cannot leak; leaves the
  pre-existing role-permission union untouched (a separate hardening concern).
- **B:** First tighten branch resolution broadly (e.g. make the no-branch union
  fail-closed for branch-scoped permissions) before adding delegation.

Once the approach is chosen, Stage 2 is a schema change (`UserBranchPermission` +
a `price.edit` permission): take a fresh `--hex-blob` backup, generate SQL with
`prisma migrate diff --from-schema-datamodel <git HEAD schema> …` (shadow DB
unavailable), apply with `migrate deploy`, enforce the delegatable allowlist
(only `price.edit`; never `discount.override`/`user.manage`/`settings.manage`).

## Explicit boundaries

Not authorised in the current milestone:

- Implementing any product feature — this bootstrap authorises **coordination
  files and Git commits only**
- Returns, Transfers, Users, Goals, Money & reconciliation, Consignment,
  Subscription or Expenses workflows
- Any Prisma schema change or migration
- Widening any permission to close the two approval gaps above
- Adding dependencies to either code repository
- Guessing a WhatsApp, OTP or Bankily integration
- Deleting demo data, resetting the database, or force-pushing any repository

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
