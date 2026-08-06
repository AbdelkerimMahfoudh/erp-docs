# ERP Current Handoff

## Session control

- Status: IN_PROGRESS
- Active account: CLAUDE-A
- Owner: CLAUDE-A
- Session started / started_at_utc: 2026-08-06 21:45 UTC (CLAUDE-A, G1 mobile
  completion)
- Last updated: 2026-08-06 21:45 UTC

> ### ⚠️ Account-label correction (2026-08-06, CLAUDE-A)
>
> **Every session in this workspace has been performed in the CLAUDE-A account.**
> Several earlier entries — including the G1 backend and G1-mobile sessions —
> recorded themselves as `CLAUDE-B`. That label was wrong; the *work*, commits
> and verification described in them are correct and unaffected.
>
> Nothing has been rewritten: `SESSION_LOG.md` is append-only, so the correction
> is appended there rather than edited into the old entries. Code commits are
> untouched, because a label error is not a reason to rewrite correct history.
> Read any `CLAUDE-B` attribution in entries dated 2026-08-05/06 as **CLAUDE-A**.
- Current authorised task: **none.** G1 backend is complete, live-validated and
  green; the Catalog **list** and **detail** screens are done. The **manual
  create/edit form (+ scanner) and the category-management screen are NOT
  started** — that is the exact next checkpoint. Nothing is half-applied.
- **G1 status:** backend contract + permission + tests **done** and now
  **live-validated against real MySQL** (backend `fb1ad67`); mobile catalog
  **list + detail + full EN/AR i18n** done (mobile `c36eeaf`).
  **Pending:** shared create/edit form, scanner integration in that form,
  category-management screen.
- **Defect found and fixed this session:** catalog **specification search
  returned nothing on real MySQL**. Prisma's `string_contains` on a JSON column
  needs an explicit `path`, which category-defined specs cannot supply, so the
  filter silently matched nothing. The unit double had implemented it as a
  `JSON.stringify` match — more permissive than the database — so the suite
  stayed green. Now a bounded, company-scoped raw query feeds matching ids back
  as an `OR id IN (…)` predicate. **Lesson: a mocked filter can hide a
  database-behaviour defect; the live check is what caught it.**
- Paused / not authorised: OTP, invitations, passcodes, biometrics, WhatsApp
  provider, price-edit redesign, Excel import, suppliers, transfers, returns,
  subscriptions.
- Takeover verified at 20:44 UTC — reality matched the brief exactly: backend
  `6192fd8`, mobile `ddc23cb`, docs `e1298f7`, migration `0025`,
  **41 suites / 454 tests passing**, all three trees clean and level with
  `origin/master`, `READY_FOR_HANDOFF`/NONE, WhatsApp/OTP present but disabled
  with no provider configured.

### G1 repository-truth audit (before any edit)

**Reuse as-is (no second catalog, no second price source):**
- `Product` **already IS an exact sellable variant** — `@@unique([companyId,
  brand, model, variant])` plus a `specifications` JSON. No identity redesign
  needed; brand/model group for display only.
- `ProductCategory` (company-shared, `isActive`, `defaultTrackingType`,
  `attributeSchema`) and its `POST/PATCH /v1/categories` already exist and are
  correct — reuse, do not duplicate.
- `ProductRecognition` + the recognition outbox already learn a product's
  barcode transactionally on create.

**Current price truth (traced end to end):**
- **Serialized (phones/Units):** `Unit` has `cost` but **no price column**.
  `sales.service` resolves the line price via
  `sales-policy.resolvePrice(provided, product.defaultPrice)` — i.e. the price
  typed at sale time, falling back to **`Product.defaultPrice`**.
- **Quantity (accessories):** `StockItem.price` **per branch**, seeded at
  receiving from `dto.price ?? Product.defaultPrice`
  (`inventory.service`/`purchasing.service`).
- ⇒ `Product.defaultPrice` is the existing authoritative *fallback*; G1 only
  **displays** it and must not introduce a competing source. **`Unit` still has
  no individual price — that is the exact next Pricing milestone.**

**Gaps / inconsistencies found:**
- `POST /v1/products` is guarded by **`unit.add`**, which **Store Employees
  hold** — employees can create catalog products today. This is the concrete
  reason `catalog.manage` is needed.
- Category writes are guarded by `settings.manage` (**Owner-only**), so a Store
  Manager cannot manage categories at all.
- `GET /v1/products` has **no pagination** (fixed `take: 200`), no filters, and
  no detail endpoint; `search` is capped at 50 and covers only brand/model/
  variant. **No PATCH/update endpoint exists at all.**
- `Product.defaultCost` exists (a generic permanent product cost, contrary to
  the approved rule) but is already stripped by the cost-gating interceptor —
  left untouched, and deliberately **not** surfaced in the new catalog form.

**Lifecycle — no schema change required:** `Product` has no `isActive`, but
`catalog.list/search/suggest` filter `deletedAt: null` **while Sell, Receive,
Inventory and Scanner do not filter it at all**. So `deletedAt` already yields
exactly the approved archive semantics — hidden from receiving/creation
selectors, still visible in Inventory, still sellable until depleted, fully
reversible. The API exposes it as a derived `isActive`, matching the project's
derived-status convention.

**Would break if changed:** any narrowing of `products/suggest`, `search`, or
the `Product.defaultPrice` fallback would break Receive and Sell; the
`(companyId, brand, model, variant)` and `(companyId, barcode)` unique keys and
the recognition outbox contract must be preserved.
- Last completed checkpoint: **Stage 4A.1 complete** (mobile `ddc23cb`) — the
  Store Account ID copy action now uses `expo-clipboard`, asynchronously, and
  confirms only after the write actually lands. **Mobile-only. No OTP,
  messaging, authentication, backend or database change.**
- Takeover: CLAUDE-A took ownership at 2026-08-06 17:20 UTC from a clean
  `READY_FOR_HANDOFF`/NONE state. Verified before any change: backend
  `6192fd8`, mobile `e936e4e`, docs `926896c`, migration `0025`,
  **41 suites / 454 tests passing**, all three trees clean and level with
  `origin/master`. Reality matched the brief exactly.
- Previous takeover: CLAUDE-A took over from CLAUDE-B at 2026-08-06 16:30 UTC
  for Stage 4A (backend `6fde7bb`, mobile `fca89f4`, docs `55a7c78`, migration
  `0024`, 38/390 verified).
- **NETWORK:** GitHub was unreachable at the very start of the session but
  **recovered before the first commit**; every checkpoint below was pushed
  successfully and all three trees are level with `origin`.
- Last completed checkpoint: **Stage 4A complete** — Store Account ID visible to
  the Owner, provider-neutral messaging boundary, OTP challenge + verification
  intent (`0025`), 64 new tests. **No provider integrated, no message sent, OTP
  not active in production, new-device login still blocked.**
<!-- superseded: Stage 3.2 checkpoint —
- Last completed checkpoint: **F1 Stage 3.2 complete** — the mobile fail-closed
  bypass is removed (blocking verification state instead), the public Store
  Account ID (`0024`) is the pre-login tenant selector, login is
  `{ storeAccountId, login, password, device? }` resolving the company server-side
  and failing non-enumerating + timing-safe, and the mobile keys its device
  credential by `env + storeId + login` with a one-time legacy migration. All
  committed, pushed and live-verified (multi-company); three trees clean.
-->
<!-- superseded: Stage 3.1 checkpoint —
  live-verified; three trees clean.
-->
- Takeover history: CLAUDE-B resumed after its own F1 Stage 3.1. At takeover the
  expected state matched exactly (backend `8a5ee5c`, mobile `2188a34`, docs
  `fba767e`, migration `0023`, 37/377), all clean and level with origin. Earlier
  session history is retained below.
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
| Backend (`erp-backend`) | master | `fb1ad67` | `fb1ad67` | clean |
| Mobile (`erp-mobile`) | master | `c36eeaf` | `c36eeaf` | clean |
| Documentation (`erp-docs`) | master | *current HEAD contains this handoff* | same | clean |

Stage 3.2 commit trail — mobile `da34e1f` (CP1: remove fail-closed bypass +
blocking state), backend `044234b` (CP2: Store Account ID + auth contract +
migration `0024`), backend `6fde7bb` + mobile `fca89f4` (CP3: publicStoreId in
responses; Store ID login + scoped credential key + legacy migration), docs
`916f50b` (ownership) + the commit carrying this handoff.

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

Measured by CLAUDE-A on 2026-08-06 after Stage 4A.

- Stage 4A.1 re-verification (2026-08-06 17:55): mobile TypeScript clean ·
  `expo lint` clean · **`expo-doctor` 18/18 checks passed** · `expo export
  --platform web` succeeded and statically rendered all 23 routes **including
  `/settings`**, which proves the screen's module graph loads with no undefined
  native module. Backend untouched, so its 41/454 baseline below still stands
  (measured again at takeover, unchanged).
- **Device-only check still outstanding:** an actual paste on a physical
  Android/iOS device or Expo Go. The web export proves the module resolves and
  the screen renders; it does not prove the native clipboard write.
- Backend tests: **42 suites / 494 tests passing** (G1: +37 catalog + 3 matrix). Previously 41/454 — Stage 4A added
  `messaging.spec.ts` (19), `otp-code.util.spec.ts` (18) and
  `otp.service.spec.ts` (27)
- Backend TypeScript: clean · Mobile TypeScript: clean · Expo lint: clean
- Latest Prisma migration: **`0026_catalog_manage_permission`** (G1; backup `phonestore-20260806-204539.sql` taken first). Previously **`0025_otp_challenge_and_intent`**
- Database migration status: *"Database schema is up to date!"*, **24 migrations**
- Migration-only-deploy proof (scratch `prisma_s4a_deploy`, restored from the
  pre-`0025` backup, **NO seed**): 6 users / 76 sessions / 0 devices all
  preserved; both tables created; both UNIQUE indexes present; FKs
  `RESTRICT`/`CASCADE`/`SET NULL` as designed; SQL rerun twice changed nothing.
  Clean-database run produced 52 tables. Both scratch DBs dropped.
- **Database-level proof of the "one live challenge" rule:** MySQL accepted two
  terminal rows with `active_key = NULL` and rejected a second row with the same
  non-NULL `active_key` (`ERROR 1062`). That is the mechanism, verified.
- Local channel verification: the backend starts and is healthy with **no
  `OTP_PEPPER` and no provider configured**, and `device_unrecognized` still
  blocks in `auth.service.ts`. A grep confirms **nothing in the login flow calls
  `OtpService` or `VerificationIntentService`.**


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
- **F1 Stage 3.2 — Store Account ID + bypass fix: complete** (CLAUDE-B; backend
  `6fde7bb`, mobile `fca89f4`, migration `0024`). Removed the mobile fail-closed
  bypass (no more auto forget-and-retry; a rejected device shows a blocking
  translated verification state, credential kept). Added
  `companies.public_store_id` — a public, non-secret, unique, immutable Store
  Account ID — and made login `{ storeAccountId, login, password, device? }`:
  the company is resolved from the public code (never a client binary id), the
  user is found within it, and a bad Store ID / login / password fail identically
  and timing-safe. Mobile keys the device credential by `env + storeId + login`
  and migrates legacy `erp.device.<login>` credentials one-time from the user's
  own session. Multi-company live-verified. See
  [`docs/23`](docs/23_USERS_AUTH_AUDIT_AND_PLAN.md) Stage 3.2.

## Work currently in progress

**Nothing. Stage 4A and the Stage 4A.1 correction are complete, committed,
pushed and verified.**

- Uncommitted work: none in any repository.
- Migrations applied by Stage 4A: **`0025_otp_challenge_and_intent`** (additive;
  `0024` untouched). **Stage 4A.1 applied none** — it is mobile-only.
- Only dependency ever added by this line of work: **`expo-clipboard@~8.0.8`**
  (Stage 4A.1). No backend dependency; still no messaging SDK and no HTTP
  client.
- Temporary databases: `prisma_s4a_deploy` and `prisma_s4a_clean` — **both
  dropped**. None remain.
- Live fixtures created: **none.** Stage 4A needed no live data, so no fixture
  cleanup and **no new append-only audit rows** were produced.
- No financial or inventory record was touched.

### What Stage 4A deliberately does NOT do

- No Meta / Twilio / Infobip integration and no messaging SDK installed.
- No real WhatsApp message is sent; `disabled` is the default channel.
- OTP is **not active in production**: `OTP_PEPPER` is unset, so challenge
  creation refuses.
- New-device login **still blocks** on `device_unrecognized`.
- Nothing marks a phone or a device verified. `otpVerifiedAt` and
  `phoneVerifiedAt` are still never written.
- No public OTP endpoint exists — the services are internal.


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
| ~~Mobile device-credential storage key company-ambiguous~~ — **RESOLVED (Stage 3.2)**: login now carries the public Store Account ID, the key is `env + storeId + login`, and legacy credentials migrate one-time from their own session | Done |
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
- **Pre-Stage-3.2 backup (CLAUDE-B, before migration `0024`):**
  **`~/erp-backups/phonestore-20260806-152840.sql`** — 195 544 bytes, trailer
  `-- Dump completed on 2026-08-06 15:28:42`, `--hex-blob`, 0 raw `_binary`.
  Taken immediately before `0024_company_public_store_id`.
- Temporary databases: **none.** Scratch databases must be named `prisma_*`
  (the migrator's grants cover `phonestore` and `prisma\_%` only) and dropped
  after verification.
- Demo records that must not be deleted: companies 1 (public Store ID
  **`F62B8D1EEB`**) · branches 2 · users 6 · products 12 · units 11 · sales 7 ·
  purchases 9 · audit_logs **93** (append-only; grew from Stage 1 / F1.1 / Stage
  2 / Stage 3 / 3.1 / 3.2 live verification — legitimate contact/device/status
  audits, never corruption) · company_settings 1 · receiving_accounts 3 ·
  `user_devices` 0.
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

**The exact next checkpoint is the G1 manual create/edit form and the category
screen.** Everything they depend on is live, tested and pushed:

1. ~~Product detail screen~~ — **DONE** (`app/catalog/[id].tsx`, mobile `960e3c1`).
2. **Manual create/edit form** — progressive sections (identity → category →
   tracking → barcode → specifications → review), `SelectSheet` for category,
   dirty-state protection, per-field validation, scanner shortcut for the
   barcode that calls the existing authoritative scan path and shows the
   existing product instead of duplicating it. `PATCH /v1/products/:id` exists;
   there is deliberately **no price field** on it.
3. **Category management** — reuse `GET/POST/PATCH /v1/categories` (now
   `catalog.manage`, so Store Managers can finally use them). No merging.
4. **EN/AR strings + RTL** for all of the above, and a Catalog entry in the More
   menu gated on nothing (browsing) with create/edit gated on `catalog.manage`.
5. Then: mobile TypeScript, Expo lint, Expo Doctor, web export, and a live pass
   over Sell / Receive / Inventory to confirm no regression.

**Legacy `GET /v1/products/all` — consumer audit (2026-08-06): ZERO consumers.**
No mobile caller (`grep` over `app/`, `components/`, `lib/`, `hooks/`), and the
only backend reference is its own controller route. It is **safe to delete in
the next pass**; it was kept this session only because the brief said not to
remove it yet. `GET /v1/products/search` still has no mobile caller either but
remains part of the public contract.

`app/catalog/new.tsx` still posts the old create shape. It works and the
endpoint is `catalog.manage`-guarded, but it should be replaced by the shared
create/edit form rather than extended.

When work is authorised again, the receiving account must, in order:

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
