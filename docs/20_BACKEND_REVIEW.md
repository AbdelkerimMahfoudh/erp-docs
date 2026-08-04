# 20 — Backend Review (pre-Sprint 2E)

> Complete review of the Electronics Retail Management System backend after Sprint 2D.5.
> Purpose: establish a shared, accurate picture of what exists, how it holds together, and what must be addressed — before Sprint 2E (hardening).
> **Status at review:** build clean · **17 test suites / 89 tests green** · Prisma drift clean · ~6,800 LOC (src, excl. tests).

---

## 1. Executive summary

The backend is a **NestJS 10 + Prisma 5 + MySQL 8 (InnoDB)** monolith for an **Electronics Retail Management System**. It is feature-complete through the **product spine** (catalog, receiving, sales, transfers), the **2C.5 generalization** (IMEI / serial / quantity tracking, adaptive categories, learning scanner), and **Sprint 2D analytics** (rollups, dashboards, inventory intelligence, daily closing/digest, health score).

- **Architecture is sound**: clear layering, fail-closed multi-tenancy, event-driven side effects, a queue abstraction ready for BullMQ.
- **The system is tracking-type independent end to end** — analytics and financials never read an identifier; everything derives from `sale_items` and inventory tables.
- **The main outstanding risk is cost/profit exposure** — the permission-aware serializer is the committed Sprint 2E deliverable and is **not yet in place**, so cost/margin fields are currently returned to any authenticated caller on several endpoints.
- **Automated test coverage is unit-level only**; transactional flows and rollup SQL are proven via manual live e2e runs, not committed integration tests.

Overall: **a solid, coherent foundation ready for 2E hardening**, with a short list of concrete gaps below.

---

## 2. Module map

**Infrastructure / global:** `PrismaModule` (system + tenant clients), `TenantModule`, `AuditModule`, `NumberingModule`, `EventsModule`, `HashingModule`, `RbacModule`, `StorageModule`, `AppConfigModule`.

**Domain:**
| Module | Responsibility |
|---|---|
| `auth` | login / refresh / logout / me / permissions (JWT + rotating refresh) |
| `users` | user management foundation |
| `catalog` | product templates, TAC recognition, `findOrSuggest` |
| `categories` | category CRUD + adaptive attribute schema, active/inactive |
| `tracking` | `TrackingStrategyRegistry` (imei/serial/quantity) + `ProductAttributesService` |
| `scanner` | `POST /scan` pipeline + `RecognitionService` (learning) + pluggable confidence |
| `inventory` | units, quantity stock, quick-add, unit timeline, state machine |
| `suppliers` | suppliers + payables |
| `purchasing` | unified receiving (`items[]`), teach-on-confirm, branch refresh |
| `sales` | atomic sell, returns, profit, invoice numbering |
| `transfers` | branch transfers (send/receive-preview/confirm/cancel) |
| `analytics` | rollups, queue, dashboards, inventory value, health score |
| `expenses` | expense capture (feeds net profit) |
| `closing` | daily closing + digest + historical comparison |
| `notifications` | in-app notification center |
| `health` | liveness/DB health check |

16 controllers, 20 modules.

---

## 3. Data model & migrations

12 migrations (`0001`–`0012`, numbering skips `0005`), all applied, **drift clean** (only the expected generated-column extras Prisma can't model: `units.identifier`, `sale_items.active_unit_id`, `settings.branch_scope` + FULLTEXT).

- **Ids:** UUIDv7 as `BINARY(16)`, app-generated; API emits/accepts canonical UUID strings via `BinaryUuidInterceptor`.
- **Money:** `DECIMAL(14,2)`; **timestamps:** `DATETIME(6)` UTC.
- **Tracking:** `Unit` (imei/serial, nullable + generated `identifier`) vs `StockItem` (quantity). `Product.trackingType` drives everything.
- **Learning:** `product_recognition` with rich stats (`confirmations`, `corrections`, `last_confirmed_at`, `last_corrected_at`, `source_stats`).
- **Analytics:** `daily_rollups`, `product_daily_rollups`, `product_velocity`, `inventory_valuation` (derived, no FKs, `category_id`+`tracking_type` denormalized).
- **Closing/finance:** `daily_closings`, `daily_digests`, `digest_lines` (renamed `imei`→`identifier`), `expenses`, `expense_templates`.

---

## 4. Security posture

**Strong:**
- **Fail-closed tenant isolation** — Prisma client extension injects `company_id` into every tenant query (incl. `groupBy`/`aggregate`) and **throws** if no context; verified inside `$transaction`. Tenant creates pass `companyId` explicitly.
- **Two DB roles** — `phonestore_migrator` (DDL) vs `phonestore_app` (DML only, append-only `audit_logs` via triggers).
- **AuthN** — Argon2id, short JWT access + rotating opaque refresh (reuse-revoke).
- **AuthZ** — `@RequirePermissions` + `PermissionsGuard`, per-branch resolution.
- Global: helmet, CORS allowlist, rate limiting (tighter on `/auth`), strict validation, problem+json errors with request ids.

**Gap (Sprint 2E):**
- ⚠️ **No cost/profit field gating yet.** `cost`, `margin`, `total_cost`, COGS, and profit figures are returned to any authenticated user on sales detail, inventory, analytics, dashboard, digest and health endpoints. The permission-aware serializer (`cost.view`) is the primary 2E task and must land before any non-owner role is issued.

---

## 5. Domain capability status

- **Catalog / categories / attributes** — complete; unknown attributes allowed as `extras`, strict on required/type.
- **Scanner / learning** — `POST /scan` single entry; recognition memory with corrections that never overwrite; confidence pluggable. *Reserved:* serial-prefix learning, QR parsing, sale-time reinforcement.
- **Receiving** — unified `items[]`, product-first, strategy-dispatched, atomic; teaches recognition (strongest signal), stamps supplier.
- **Sales** — one atomic transaction (unit/stock, profit, invoice, audit, notification), idempotent via `clientUuid`, sold-once DB backstop; returns reverse profit.
- **Transfers** — full lifecycle with discrepancy report; generalized to identifiers.
- **Analytics** — rollups on `sale.recorded`; inventory value + velocity; `/home`, `/dashboard`, `/analytics/*`, `/health-score`.
- **Closing** — authoritative recompute → `DailyClosing`+`DailyDigest`+lines in one tx; net profit, cash reconciliation, historical comparison, in-app notify.

---

## 6. Analytics & rollup architecture

- **`RollupService`** uses the **system** Prisma client (no CLS) → portable to a background worker; every query explicitly filtered by `company_id`.
- **`RollupQueue`** abstraction: `InProcessRollupQueue` (fire-and-forget after commit) today; `BullRollupQueue` (Redis) later with no emitter changes.
- **Triggers:** `sale.recorded` → daily recompute + branch refresh; receiving → branch refresh; expense create → daily recompute.
- **Tracking-type independence** proven: product resolved via `COALESCE(sale_item.product_id, unit.product_id)`; verified against ground-truth SQL.

---

## 7. Testing status

- **13 spec files / 89 unit tests**, all green. Strong on pure logic: tracking strategies, attribute validation, recognition statistics, confidence scoring, code classifier, health scoring, discrepancy, state machines, invoice/uuid/duration utils, permissions guard, tenant extension.
- **Verification of transactional & SQL-heavy paths is via manual live e2e scripts** (receive/sell/scan/rollup/closing against WAMP MySQL), each checkpoint matched to ground-truth SQL.
- **Gap:** no committed integration/e2e harness (supertest + seeded login) — the manual scripts are not repeatable CI artifacts.

---

## 8. Known gaps, risks & tech debt

**Security**
1. **Cost/profit gating missing** (2E) — highest priority.

**Data freshness (rollups)**
2. **Returns don't refresh rollups.** `sales.returnUnit` adjusts the sale but emits no event → `daily_rollups` / `inventory_valuation` stay stale until the next sale or the daily closing recompute. Intraday dashboards can overstate revenue/profit after a return.
3. **Transfers & mark-faulty don't refresh `inventory_valuation`.** Moving/retiring stock leaves both branches' valuation snapshots stale until a sale/receive there.

**Analytics scope (by design, worth noting)**
4. Company-wide expenses (`branch_id NULL`) are not attributed to any branch rollup — expenses require a branch.
5. Employee performance and supplier profitability are live/absent (no rollup) — supplier profitability reserved.
6. `digest_lines.method` left null (per-line payment method ambiguous with multi-payment sales).

**Operational**
7. `RollupQueue` is in-process only; no Redis/BullMQ wired (fine for dev, required for prod scale).
8. List endpoints use fixed `take` caps (100–200), **no pagination**.
9. Migration numbering skips `0005` (cosmetic).

**Deferred features (intentional, not debt)**
10. Product images, serial-prefix learning, QR parsing, sale-time learning, server-persisted receiving sessions.

---

## 9. Recommendations for Sprint 2E

1. **Permission-aware cost/profit serializer** (committed 2E scope) + tests asserting fields are stripped for roles without `cost.view`. **Do this first.**
2. **Close the rollup-freshness gaps** — emit a spine event (or enqueue) on **return**, **transfer receive/cancel**, and **mark-faulty** so `daily_rollups` + `inventory_valuation` refresh like sales/receiving do.
3. **Add an integration test harness** (supertest + seeded owner) covering the flows currently proven only by manual scripts: receive→sell→rollup, closing, tenant isolation, cost-gating.
4. **Full test pass + docs refresh** (the rest of 2E scope).
5. Defer (with tickets): pagination, BullMQ wiring, supplier profitability rollup.

**Verdict:** the backend is coherent and production-shaped. Sprint 2E should focus on **cost gating**, **rollup-freshness on non-sale mutations**, and a **repeatable integration test layer** — after which the backend is ready to support the frontend.
