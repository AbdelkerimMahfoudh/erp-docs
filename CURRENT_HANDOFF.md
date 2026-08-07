# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Active account / Owner: **NONE**
- Last session: **CLAUDE-A**, 2026-08-07 — **Phase G2A-CP3, Pricing Resolution
  and Secure Backend Operations** (complete). Backend only; no mobile pricing UI,
  no G2B proposals.
- Previous session: **CLAUDE-A**, 2026-08-07 — G2A-CP2 (complete)

> **Account label — current truth: this account is `CLAUDE-A`.** Several earlier
> entries (G1 backend, G1 mobile, G2A-CP1) recorded themselves as `CLAUDE-B`.
> **Only the ownership label was wrong** — the work, commits, audits and
> verification described in them are correct and unaffected. Nothing was
> rewritten: `SESSION_LOG.md` is append-only, so the correction is appended
> there, and no commit was amended. Read any `CLAUDE-B` attribution dated
> 2026-08-05/07 as **CLAUDE-A**. This account stays `CLAUDE-A` until the user
> explicitly switches it.

## Repository state

All clean, all `master`, all level with `origin`.

| Repository | Branch | Local HEAD | Remote HEAD | Working tree |
|---|---|---|---|---|
| Backend (`erp-backend`) | master | `103588f` | `103588f` | clean |
| Mobile (`erp-mobile`) | master | `65edca8` | `65edca8` | clean |
| Documentation (`erp-docs`) | master | *the commit carrying this handoff* | same | clean |

Mobile is unchanged — CP3 is backend-only, and its TypeScript/lint checks were
run to confirm the shared and generated types still hold.

CP3 backend commits: `159c4f3` (0028 audit-trigger repair) · `72b8861` (pricing
service, API, Sell and transfer integration, 0029) · `103588f` (branch-context
fixes found by live verification).

**Note:** the documentation row is deliberately not a hash. A file cannot contain
the id of the commit that introduces it. Read it with
`git -C <docs repo> log --oneline -1`.

**Layout:** the documentation repository is the **workspace root**
(`C:\wamp64\www\PhoneStoreERP`). `backend/` and `mobile/` are nested inside its
working tree but are separate repositories, excluded via the root `.gitignore`.
From either code repository the documentation repository is `../`.

## Verified baseline (measured at the end of G2A-CP3)

- **Backend tests: 45 suites / 579 tests passing**, 0 failing. CP3 added
  `price-resolution.spec.ts` (18) and `pricing.service.spec.ts` (42) and grew the
  migration-contract spec to 24, over the CP2 baseline of 43 suites / 515 tests.
- **Live verification: 55 checks, 0 failures** (30 + 25) against the running API
  and real MySQL. Temporary fixtures removed; demo data byte-identical to the
  CP2 baseline afterwards.
- Backend TypeScript **clean** · `prisma validate` **valid** · `prisma generate`
  regenerated the client (3 500 references to the new models; both `tsc` and the
  suite compile against it). The `EPERM … query_engine-windows.dll` rename
  warning is the known WAMP file-lock from another running dev server, not a
  generation failure.
- Mobile TypeScript **clean** · `expo lint` **clean**. No mobile file changed;
  this only confirms the shared/generated types were not broken.
- Migration status: *"Database schema is up to date!"* — **28 migrations**,
  latest **`0029_stock_item_version`**.
- **Trigger inventory (exact, live dev):** `audit_logs_block_update` BEFORE
  UPDATE · `audit_logs_block_delete` BEFORE DELETE · `price_change_events_block_update`
  BEFORE UPDATE · `price_change_events_block_delete` BEFORE DELETE. **4 total**,
  all DEFINER `phonestore_migrator@localhost`. A clean database built from all 28
  migrations now produces the same 4.
- **No temporary databases remain** (`prisma_cp3_trig` and `prisma_cp3_pre`
  dropped). No temporary business fixtures remain.

## Phase G2A — Pricing Foundation

### CP1 ✅ — pricing-truth audit and decision record (docs `e4de6b9`)

Traced end to end; no code changed. Conclusion: **no contradiction** with the
approved pricing rules, so G2A could proceed as specified.

| Field | Scope | Mutability | Role |
|---|---|---|---|
| `Product.defaultPrice` | Company-wide | Mutable default | Company fallback |
| `StockItem.price` | Branch | Set on **first receive only** | Authoritative branch price for **quantity** stock |
| `SaleItem.price` · `DigestLine.salePrice` | Sale line | **Immutable snapshot** | What was actually charged |
| `Unit.cost` | Unit | Set at receiving | **There was no `Unit` price** — the gap G2A fills |

Nothing mutates `defaultPrice` except catalog create, already behind
`price.edit`. Margin is computed server-side (`round(total − totalCost)`) and the
client's numbers are never trusted. No read path recomputes a completed sale, so
**a price edit cannot alter history.**

### CP2 ✅ — pricing schema and migration `0027_pricing_foundation` (backend `167bbcf`)

Schema only. **No API, no resolution service, no notification, no UI.** Nothing
reads these tables yet, so there is no half-enforced state.

| Table | Identity rule | Purpose |
|---|---|---|
| `branch_variant_prices` | `UNIQUE (product_id, branch_id)` | current price of one exact variant in one branch |
| `unit_price_overrides` | `UNIQUE (unit_id)`, **plus `branch_id`** | current price of one individual unit |
| `price_change_events` | append-only, no uniqueness | every price change, forever |

`DECIMAL(14,2)` money and `BINARY(16)` UUIDv7 keys throughout.
`version INT DEFAULT 0` on both current-price tables gives compare-and-swap →
**409** on a stale edit, so two managers repricing the same phone cannot
silently overwrite each other.

**The one design correction carried from CP1.** CP1 proposed keying
`UnitPriceOverride` on `unit_id` alone. That was wrong: an override set by a
Manager in Branch A would follow the phone into Branch B and take effect under
authority nobody granted there. `branch_id` records the **branch whose authority
created the price** — deliberately *not* a foreign key to the unit's current
location, because the two must be allowed to diverge and that divergence is the
signal CP3 acts on. The FK to `units` also means quantity stock can never
acquire a unit override.

**Constraints honoured:** `Product.defaultPrice` untouched (still the fallback) ·
`StockItem.price` untouched (still authoritative for quantity — no parallel
quantity-price source) · **no backfill**, because copying `defaultPrice` into
every branch would invent prices nobody set and permanently destroy the fallback
· no earlier migration modified, squashed or regenerated · additive only, with no
`ALTER`, `INSERT` or `DROP` against any existing table.

**Append-only enforced by the database, not by convention.**
`price_change_events` carries `BEFORE UPDATE` and `BEFORE DELETE` triggers that
`SIGNAL SQLSTATE '45000'` when `USER()` is the application account — the
`audit_logs` pattern. Unlike `audit_logs`, these triggers live **inside the
migration**, so a fresh deployment gets them automatically rather than depending
on someone running an init script. Four `CHECK` constraints reject negative
money.

### Backup (taken BEFORE the migration)

- **Path:** `~/erp-backups/phonestore-20260807-051508.sql` — `--hex-blob`,
  `--single-transaction`, routines + triggers + events, no tablespaces.
  Credentials were never printed or placed on a command line.
- **Verified:** 207 450 bytes · trailer `-- Dump completed on 2026-08-07 5:15:09`
  · **0 raw `_binary` literals** / 1 622 hex literals · valid UTF-8 round trip ·
  52 `CREATE TABLE` · 2 triggers.
- **Restore proven BEFORE migrating**, through the documented DEFINER-safe path
  (`scripts/sanitize-dump.js` → restore as the migrator) into `prisma_g2a_pre`:
  **52/52 tables, 2/2 triggers**, and the `units` `HEX(id)` MD5
  `2a1dc9bf284afde32b402ad108d38a76` **byte-identical to live**.

### Deployment proofs — all four passed

| Proof | Result |
|---|---|
| **Clean database** (`prisma_g2a_clean`, from zero) | 55 tables · 3 pricing tables · 2 pricing triggers · 4 CHECKs · 13 pricing FKs · 26 migrations applied |
| **Restored pre-migration database** (`prisma_g2a_pre`) | `0027` applied alone, **seed never ran** · 12 products / 11 units / 7 sales / 14 sale_items / 4 stock all preserved · **`bvp=0 upo=0 pce=0`** (no backfill) · audit triggers 2 + price triggers 2 · `sum_total=10051.00`, `sum_item_price=9615.00`, identical to live |
| **Existing dev database** | applied; status *"Database schema is up to date!"*, 26 migrations |
| **Rerun** | idempotent — nothing changed |

**Append-only and CHECK exercised against real MySQL as `phonestore_app`: 7/7** —
read ✅ · insert ✅ · **UPDATE blocked** ✅ · **DELETE blocked** ✅ · negative price
rejected ✅ · history intact after both blocked attempts ✅. This is why
`pricing-migration.spec.ts` asserts the migration's *contract* instead of mocking
Prisma: a mocked constraint only tests the mock.

**Cleanup:** probe events removed, `prisma_g2a_clean` and `prisma_g2a_pre`
**dropped**, sanitized dump copy deleted. Demo integrity re-checked afterwards —
products 12 · units 11 · sales 7 · `sum_total=10051.00` · `bvp=0 upo=0 pce=0`.

### 🔴 Open issue for G2B — who may establish `StockItem.price`

**Not approved, and not silently accepted as correct.** `upsertStock` writes
`price` on the **first receive of a quantity product into a branch**, and
receiving is open to a **Store Employee** — so an Employee performing ordinary
intake can establish the branch selling price without holding `price.edit`.
Later receives increment quantity and leave the price alone, so it happens
exactly once per product per branch and is easy to miss.

CP2 deliberately did **not** change it: altering intake behaviour is outside a
schema phase and would have shipped an unreviewed workflow change alongside a
migration. Three candidate resolutions are recorded in
[`docs/21` §6](docs/21_PRODUCT_DECISIONS.md). **Treat it as known, tolerated and
unapproved until the user decides in G2B.**

### CP3 ✅ — pricing resolution and secure backend operations (backend `103588f`)

**Backend complete. No mobile pricing UI, no G2B proposals.**

**One `PricingService` is the only authority on selling price** — Sell, product
detail and the pricing API all ask it rather than re-deriving precedence.
Effective price, first match wins, with the source always returned:
`unit_override` → `branch_variant` → `stock_item` (quantity only) →
`product_default` → `unpriced`.

A unit override applies **only when the override's branch, the unit's current
branch and the active request branch all match**. A stale override is reported
as `staleOverrideIgnored` and never applied, so a transfer that failed to
invalidate is visible rather than silently charging the wrong price. Product-level
resolution structurally cannot see an override — one phone's price is not the
model's price.

**API:** narrow, explicit routes under `/v1/pricing`. **No generic endpoint**
taking a model, field, permission or target branch from the body. Reads of the
effective price are open to any signed-in user; writes and history need
branch-scoped `price.edit`.

**Concurrency:** compare-and-swap on `version`, `409` on a stale update or
removal, and a lost create race translated from the unique-key rejection into
`409 refresh_required` rather than overwriting the winner.

**Below cost:** `discount.override` plus a non-blank reason, recorded. Purely
permission-based — a Manager is refused because that permission is Owner-only and
never delegatable. A branch price must clear the most expensive in-stock unit;
the refusal states how many items are affected and never a cost.

**Atomicity:** price change + `PriceChangeEvent` + audit row + Owner
notification are one transaction. A failed history or notification write rolls
the price back.

**Notifications** exclude the actor — one rule covering both cases — and
deduplicate an Owner assigned to several branches. No cost, no margin, no
threshold, no WhatsApp.

**Transfer invalidation** runs inside the receive transaction. The override is
**deleted**, so a returning phone cannot resurrect it; history keeps the value
with `initiator = 'system'`, `reason = 'branch_transfer'`.
`transfers.receiveConfirm` is the **only** production path that changes
`Unit.branchId`; `cancel` writes the origin branch back to where the unit
already was, and that no-op is skipped.

### CP3 migrations

| Migration | Why |
|---|---|
| `0028_audit_append_only_triggers` | **Repairs a real gap.** The `audit_logs` guard lived only in a manual init script, so a clean database built from every migration had **no** `audit_logs` triggers — a fresh production deployment would have shipped a mutable audit log. Idempotent (`DROP IF EXISTS` + `CREATE`); `0027` untouched. |
| `0029_stock_item_version` | Adds `version` to `stock_items` for quantity-price compare-and-swap. `updatedAt` cannot serve: MySQL keeps microseconds, a JS `Date` only milliseconds, so a CAS on it would round-trip lossily. |

Backups taken before each: `phonestore-20260807-140256.sql` (before `0028`) and
`phonestore-20260807-141018.sql` (before `0029`) — both `--hex-blob`,
`--single-transaction`, routines/triggers/events, no tablespaces, 0 raw
`_binary`, valid UTF-8, 55 tables. The DEFINER-safe restore was proven **before**
migrating: 55/55 tables, 4/4 triggers, `units` checksum identical to live. Both
migrations verified on clean, restored and dev databases, and on rerun.

### Two defects the live verification caught that the unit suite could not

1. **The active branch was resolved inside `PermissionsGuard`**, which exits
   early on routes needing no permission — so open reads had no branch at all and
   returned 400 for a header the client had sent. Branch is request context, not
   an authorization result; it now comes from the CLS middleware.
2. **That left open reads unchecked** — no permission meant nothing verified the
   branch, so an employee could have read another branch's prices by changing a
   header. `PricingService.activeBranch()` now confirms the caller is assigned
   to the branch, on reads as well as writes.

Both are fixed and covered by tests. **Lesson: a guard that also does context
resolution silently changes behaviour for every route that skips the guard.**

### Live verification — 55 checks, 0 failures

Against the running API and real MySQL: per-branch prices differ for the same
variant · one phone differs from another of the same model · removal reveals the
layer beneath · stale version 409 · lost create race 409 · delegated Manager can
edit only the granted branch · Employee cannot write but can read · Employee
cannot read history · no-branch write fails closed · `catalog.manage` alone
cannot price · forged product, identifier and branch all fail closed · Manager
below-cost refused with no cost revealed · Owner below-cost needs and records a
reason · quantity uses `stock_items.price` with its own 409 · a shipped-but-not-
received transfer does **not** invalidate · a completed transfer does, with the
previous price preserved and `initiator='system'` · a returning phone does not
resurrect its price · price history rejects UPDATE and DELETE from the
application account · **completed sale totals, cost and margin unchanged after
every price scope change**.

**Fixtures created and removed:** two temporary users (`cp3mgr` with
`price.edit` delegated in Main Store only, `cp3emp`), their assignments, grants
and sessions; two stock transfers and their items; all pricing rows. The
accessory price touched by the quantity check was restored to 19.00/version 0.
Demo data afterwards: products 12 · units 11 (all back in Main Store) · sales 7 ·
`sum_total = 10051.00` · stock 4 · bvp/upo/pce 0 — **identical to the CP2
baseline**.

**Retained after cleanup, deliberately:** the `audit_logs` rows written by the
verification transfers (Unit and StockTransfer status changes). They are
append-only and were left in place rather than archived. The pricing-specific
`price_change_events`, `audit_logs` rows for `BranchVariantPrice`/
`UnitPriceOverride`, and `price.changed` notifications **were** removed by the
migrator account, which the append-only design permits for a DBA; this is
recorded here rather than left implicit. The transfer invoice-number sequence
advanced by two and was not rewound.

## Next exact action — Phase G2A-CP4 or G2B (not started)

Backend pricing is complete. Nothing is half-enforced. The open choices are:

1. **Mobile pricing UI** — the read endpoints already return everything a screen
   needs: price, source, version, whether it can be removed, and the fallback
   preview. Deliberately not started this session.
2. **G2B — employee price proposals**, including the open `StockItem.price`
   question recorded above, which needs a user decision before any code.

**Deferred — do not start without the user:** Excel import · suppliers ·
transfers UI · returns · loans · consignment · goals · expenses · subscriptions ·
WhatsApp integration · authentication work · technician functionality.

## Completed milestones

- Design-system foundation: tokens, i18n (EN/AR + RTL), primitives, overlays,
  camera scanner, Product Confirmation Card, frontend permission awareness
- Screens: Sell (POS), Receive, Inventory, Catalog, Analytics, Daily closing
- Inventory cursor pagination + server-side search · scanner confidence
  correction · durable recognition outbox (transactional, lease-based, no Redis)
  · purchase idempotency
- Role migration to Owner / Store Manager / Store Employee (`0016`–`0018`), with
  a SQL-vs-TypeScript drift test
- **Phase E — Settings foundation (`0019`)**: `company_settings`,
  `receiving_accounts`, Owner Settings screen in EN/AR
- Backup/restore hardened: `--hex-blob` mandatory, tested dump sanitiser,
  restore drill verified end to end
- **F1 — Users/auth:** Stage 1 contactable users (`0020`) · F1.1 session-bound
  access tokens + atomic deactivation revocation · Stage 2 branch-scoped
  `price.edit` delegation
- **Stage 3.1** — fail-closed device recognition, multi-company credential-key
  scoping, secret-exposure regression tests
- **Stage 3.2** — Store Account ID (`0024`) and mobile Store ID login
- **Stage 4A** — OTP challenge/intent schema (`0025`); inactive, no provider
  configured, new-device login still blocks on `device_unrecognized`
- **Phase G1 — Product Catalog: complete** (backend `b3cfcbc`, mobile `65edca8`).
  `catalog.manage` (`0026`), paginated/filtered `GET /products`, detail, metadata
  `PATCH`, archive/restore, the real-MySQL JSON specification-search fix, legacy
  `GET /products/all` removed; mobile catalog list, detail, **one shared
  `ProductForm`** for create and edit, scanner, category management, EN/AR
- **Phase G2A — Pricing Foundation: CP1, CP2 and CP3 complete.** Audit, schema
  (`0027`), and the full backend pricing behaviour — resolver, API,
  authorization, concurrency, below-cost, atomic history, Owner notifications,
  transfer invalidation and Sell integration (`0028`, `0029`).

## Standing lessons

- **A mocked filter can hide a database-behaviour defect.** G1's specification
  search returned nothing on real MySQL while the suite stayed green, because the
  unit double was more permissive than the database. This is why CP2's
  constraints were proven against real MySQL rather than mocked.
- **A guard that also resolves context changes behaviour for every route that
  skips the guard.** CP3's branch resolution lived in `PermissionsGuard`, so
  routes needing no permission silently had no branch. Only a real request
  through the real stack showed it.
- **Nothing fails when a guard is merely absent.** The `audit_logs` triggers were
  missing from every clean deployment for as long as they lived in a manual
  script, and no test, migration or startup check noticed. Protection belongs in
  the migration chain, not in a runbook.
- **A Git rollback does not roll back the database.** Restoring the dump is a
  separate, deliberate step.
- **`prisma migrate deploy` never runs the seed**, so anything reference-like
  must live in a migration.
- Authorisation is **permission-based, never role-name-based**, and anything not
  in the `COMPANY_PERMISSIONS` allowlist is branch-scoped and fail-closed.
