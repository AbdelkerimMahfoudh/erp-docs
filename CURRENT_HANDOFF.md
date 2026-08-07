# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Active account / Owner: **NONE**
- Last session: **CLAUDE-A**, 2026-08-07 from 05:14 UTC — **Phase G2A-CP2,
  Pricing Schema and Migration**
- Last updated: 2026-08-07, at the end of G2A-CP2

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
| Backend (`erp-backend`) | master | `167bbcf` | `167bbcf` | clean |
| Mobile (`erp-mobile`) | master | `65edca8` | `65edca8` | clean |
| Documentation (`erp-docs`) | master | *the commit carrying this handoff* | same | clean |

Mobile is unchanged this session — CP2 was schema-only. Docs `b3409ac` carried
the ownership correction and the verified backup record.

**Note:** the documentation row is deliberately not a hash. A file cannot contain
the id of the commit that introduces it. Read it with
`git -C <docs repo> log --oneline -1`.

**Layout:** the documentation repository is the **workspace root**
(`C:\wamp64\www\PhoneStoreERP`). `backend/` and `mobile/` are nested inside its
working tree but are separate repositories, excluded via the root `.gitignore`.
From either code repository the documentation repository is `../`.

## Verified baseline (measured at the end of G2A-CP2)

- **Backend tests: 43 suites / 515 tests passing**, 0 failing. CP2 added
  `src/pricing/pricing-migration.spec.ts` (**20 tests**) over the G1 baseline of
  42 suites / 495 tests.
- Backend TypeScript **clean** · `prisma validate` **valid** · `prisma generate`
  regenerated the client (3 500 references to the new models; both `tsc` and the
  suite compile against it). The `EPERM … query_engine-windows.dll` rename
  warning is the known WAMP file-lock from another running dev server, not a
  generation failure.
- Mobile TypeScript **clean** · `expo lint` **clean**. No mobile file changed;
  this only confirms the shared/generated types were not broken.
- Migration status: *"Database schema is up to date!"* — **26 migrations**,
  latest **`0027_pricing_foundation`**.

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

## Next exact action — Phase G2A-CP3 (not started)

None of this exists yet. In order:

1. **Price resolution service**, returning an explicit `source`:
   `unit_override` (**only when the override's `branch_id` is the selling
   branch**) → `branch_variant` → `stock_item` (quantity only) →
   `product_default` → `unpriced`.
2. **Write APIs** gated on `price.edit` **in the target branch** — it is
   branch-scoped and must never be implied by `catalog.manage`. Compare-and-swap
   on `version`; every write appends a `price_change_event` in the same
   transaction.
3. **Transfer invalidation (mandatory).** When a unit moves branch its override
   stops applying, and a `price_change_events` row records the invalidation with
   `initiator = 'system'`.
4. **Owner notification** — reuse the existing `Notification` model (it already
   has `companyId`, `branchId`, `targetUserId`, `type`, `title`, `body`,
   `actionLink`, `isRead` and the right index). No second notification system,
   and **no cost or margin in the payload**.
5. Mobile pricing UI last.

**Deferred — do not start without the user:** employee price proposals and
approvals (**G2B**, including the open issue above) · Excel import · suppliers ·
transfers · returns · subscriptions · OTP, invitations, passcodes, biometrics ·
WhatsApp provider.

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
- **Phase G2A — Pricing Foundation: CP1 + CP2 complete**

## Standing lessons

- **A mocked filter can hide a database-behaviour defect.** G1's specification
  search returned nothing on real MySQL while the suite stayed green, because the
  unit double was more permissive than the database. This is why CP2's
  constraints were proven against real MySQL rather than mocked.
- **A Git rollback does not roll back the database.** Restoring the dump is a
  separate, deliberate step.
- **`prisma migrate deploy` never runs the seed**, so anything reference-like
  must live in a migration.
- Authorisation is **permission-based, never role-name-based**, and anything not
  in the `COMPANY_PERMISSIONS` allowlist is branch-scoped and fail-closed.
