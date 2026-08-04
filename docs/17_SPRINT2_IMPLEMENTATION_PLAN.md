# 17 — Sprint 2 Technical Implementation Plan (Product Spine)

> **Status:** PLAN for approval. **No business code until this is approved.**
> Implements the workflows in [`16_SPRINT2_PRODUCT_SPINE_DESIGN.md`](16_SPRINT2_PRODUCT_SPINE_DESIGN.md) on the Sprint-1 foundation. Boundary (O1): **backend services + REST endpoints**; mobile app later.
> Follows CLAUDE.md: explain-before-build, sub-phase checkpoints, tests + docs.

---

## 1. Scope
**In:** catalog/product recognition, receiving (purchases→units), sales+profit, returns, branch transfers, unit timeline, rollups + a minimal dashboard aggregate, rules-based Health, daily-closing/digest generation, and the notification/audit hooks the spine emits.
**Out (later sprints):** mobile app, full BI/reporting UI, WhatsApp send, ML, reservations (O5), trade-ins (O6), CSV import UI (service stub only).

---

## 2. New dependencies & infra
| Need | Choice | Note |
|---|---|---|
| Background jobs (rollups, digests) | `@nestjs/bullmq` + `bullmq` + `ioredis` | **Requires Redis.** See ⚠️ P1. |
| — | (no other new deps) | class-validator/transformer, Prisma, cls already present |

**⚠️ P1 — Redis/BullMQ infra decision.** Rollup + digest recompute (O4) uses BullMQ, which needs Redis. Redis is **not** installed locally. Proposal: introduce a **`RollupQueue` abstraction** with two implementations:
- `InProcessRollupQueue` (default in dev / when `REDIS_URL` unset) — runs recompute inline/after-commit, no Redis.
- `BullRollupQueue` (prod / when `REDIS_URL` set) — enqueues to BullMQ.

This keeps Sprint 2 runnable on your WAMP box today and production-ready later, with the same service API. **Approve this approach (or say "install Redis for dev").**

---

## 3. Module architecture
```
src/
├── catalog/        Product CRUD + TAC recognition (products, tac_catalog)
├── suppliers/      Supplier CRUD + payables
├── purchasing/     Purchases → units/stock intake (receiving)  [WF1]
├── inventory/      Units, stock_items, movements, unit state machine, IMEI lookup  [WF2,3,5,8]
├── sales/          Sell, returns, payments, profit, invoice no.  [WF6,7]
├── transfers/      Branch transfers (send/receive/cancel)  [WF15]
├── closing/        Daily closing + DailyDigest generation  [WF12]
├── analytics/      Rollup service + jobs + dashboard aggregate + Health  [WF10,11]
└── common/
    ├── audit/      AuditService (append-only audit_logs writer)
    ├── tenant/     TenantContext helper (companyId/branchId from CLS, fail-closed)
    └── numbering/  InvoiceNumberService (branch_counters, atomic)
```
Every feature module: **imports RbacModule** (`@RequirePermissions`), **injects `TENANT_PRISMA`** and the shared services, and emits via `NotificationsService` + `AuditService`.

---

## 4. Shared building blocks (built first, in 2A)

### 4.1 TenantContext (common/tenant)
- `companyId(): Buffer` and `branchId(): Buffer | undefined` from CLS; **throws** if company missing (mirrors fail-closed).
- **Rule for transactions:** the tenant Prisma extension may not apply inside interactive `$transaction(async tx => …)` callbacks. So **inside transactions we pass `companyId` explicitly** on every `where`/`data` (belt-and-suspenders), and treat the extension as the safety net for non-transactional reads. First implementation task: **verify extension-in-transaction behavior** and codify the rule in a short doc note.

### 4.2 AuditService (common/audit)
- `record(tx, { entityType, entityId, action, before?, after?, reason?, branchId? })` — inserts into `audit_logs` (append-only; app user can INSERT). Accepts a transaction client so the audit row commits **in the same transaction** as the change.
- `companyId`/`userId`/`ip` pulled from CLS; ids passed as Buffers.

### 4.3 InvoiceNumberService (common/numbering)
- Atomic per-branch sequence via `branch_counters` (migration 0004): `SELECT … FOR UPDATE`/`UPDATE … SET seq = seq+1` inside the sale transaction → format with `settings.invoice_no_format` (e.g. `MAIN-00042`). Gap-free, concurrency-safe.

### 4.4 UnitStateMachine (inventory)
- Pure function `canTransition(from, to): boolean` + `assertTransition(...)` encoding the WF5 diagram; used by sales/transfers/returns. Unit-tested.

### 4.5 RollupQueue + RollupService (analytics) — see ⚠️ P1
- `RollupService.markDirty(branchId, day)` → enqueues (or inline-runs) a **branch-day recompute** that upserts `daily_rollups` + refreshes `product_velocity`.

---

## 5. New migrations (design — each reviewed before applying)

### 5.1 `0004_branch_counters`
```
branch_counters(
  company_id BINARY(16), branch_id BINARY(16), kind VARCHAR(30),   -- e.g. 'invoice'
  seq BIGINT NOT NULL DEFAULT 0, updated_at DATETIME(6),
  PRIMARY KEY (branch_id, kind), KEY (company_id)
)  -- atomic increment inside the sale tx
```

### 5.2 `0005_rollups` (tracking-type-INDEPENDENT — see §5.3)
```
daily_rollups(                              -- store totals per branch/day
  id BINARY(16) PK, company_id, branch_id, day DATE,
  revenue DECIMAL(14,2), cogs DECIMAL(14,2), gross_profit DECIMAL(14,2),
  sales_count INT, qty_sold INT, expenses DECIMAL(14,2), net_profit DECIMAL(14,2),
  refreshed_at DATETIME(6),
  UNIQUE(branch_id, day), KEY(company_id, day)
)
product_daily_rollups(                      -- per-PRODUCT fact (any tracking type)
  id BINARY(16) PK, company_id, branch_id, day DATE,
  product_id BINARY(16), category_id BINARY(16) NULL,   -- category denormalized for fast grouping
  qty_sold INT, revenue DECIMAL(14,2), cogs DECIMAL(14,2), gross_profit DECIMAL(14,2),
  refreshed_at DATETIME(6),
  UNIQUE(branch_id, day, product_id), KEY(company_id, day), KEY(company_id, category_id, day)
)
product_velocity(                           -- movement / dead-stock signal
  id BINARY(16) PK, company_id, branch_id, product_id,
  sold_7d INT, sold_30d INT, last_sold_at DATETIME(6), refreshed_at DATETIME(6),
  UNIQUE(company_id, branch_id, product_id)
)
inventory_valuation(                        -- current $ invested + expected profit, per product/branch
  id BINARY(16) PK, company_id, branch_id, product_id, category_id BINARY(16) NULL,
  units_count INT, quantity INT,
  inventory_value DECIMAL(14,2),            -- at COST: Σ in_stock units.cost + Σ stock_items.qty*cost
  expected_revenue DECIMAL(14,2),           -- at SELLING price (units → product.default_price; stock → stock_item.price)
  expected_profit DECIMAL(14,2),            -- expected_revenue − inventory_value
  refreshed_at DATETIME(6),
  UNIQUE(company_id, branch_id, product_id)
)
```
- **Category rollups** are derived by grouping `product_daily_rollups`/`inventory_valuation` on `category_id` (no separate table). Store/day/month/year totals aggregate up from `product_daily_rollups`; `daily_rollups` is the cached store-level view.
- **Inventory value (`inventory_valuation`)** is a periodic snapshot combining **both storage shapes**: `Σ units.cost WHERE status='in_stock'` **plus** `Σ stock_items.quantity × stock_items.cost`, grouped by product (and its `category_id`). Answers "$ invested in inventory" and, with `product_velocity`, "high value + low velocity".
(No `unit_events` table yet — timelines are audit-derived per O3.)

### 5.3 Tracking-type-INDEPENDENT profit model (Universal Analytics Requirement)
**Profit is computed at the `sale_item` level, which is identical for every tracking type.** Each `sale_item` already stores `price`, `cost`, `discount`, `quantity` — captured at sale time — whether the line is:
- an **IMEI** unit (phone/tablet/cellular): `quantity = 1`, `cost` = that unit's exact cost;
- a **serial** unit (TV/laptop/console/camera): `quantity = 1`, `cost` = that unit's exact cost;
- a **quantity** product (chargers/cables/accessories): `quantity = N`, `cost` = per-unit cost × N.

So for any line: `line_revenue = price×qty − discount`, `line_cogs = cost×qty`, `line_profit = line_revenue − line_cogs`, `margin% = line_profit / line_revenue`. Rollups aggregate lines by `product_id` and `product.category_id`. **No analytics query references IMEI/serial** — the identifier never enters a financial calculation. Individual (unit) and quantity (stock_item) inventory both contribute to `inventory_valuation` uniformly.

**Owner-dashboard questions this answers** (all tracking-type-blind):
profit today/month/year (store & per branch) · top products by profit · top categories by revenue · **loss-making products** (`gross_profit < 0`) · **not-selling products** (no `product_daily_rollups` rows in window / stale `last_sold_at`) · **$ invested in inventory** (`inventory_valuation`) · **best branch** (`daily_rollups` by branch). Examples like *"iPhone 16 Pro → $20k profit"*, *"Chargers → $5k profit"*, *"TV category → 30% of revenue"*, *"Power stations $100k value, low velocity"* are all `product_daily_rollups` + `inventory_valuation` + `product_velocity` queries.

### 5.4 Universal Profit & Analytics — coverage confirmation
Every required per-item field and dashboard metric maps to existing/planned storage — **no new migration beyond `0007` + `0005`**:

| Required (per item) | Source |
|---|---|
| Purchase cost | `units.cost` (individual) · `stock_items.cost` (quantity) |
| Selling price | realized: `sale_items.price`; list: `products.default_price` (units) · `stock_items.price` (quantity) |
| Revenue / Gross profit / Margin% | derived from `sale_items` (`price`,`cost`,`discount`,`quantity`) — identical for all types |
| Sales history | `sales` + `sale_items` (by `product_id`) |
| Stock-movement history | individual: unit timeline (`audit_logs`); quantity: derivable from `purchase_items` (in) + `sale_items` (out) — a dedicated `stock_movements` ledger is a *future* option, not needed now |
| Inventory value | `inventory_valuation.inventory_value` |

| Required (dashboard) | Source |
|---|---|
| Revenue/gross-profit day-month-year | `daily_rollups` (+ month/year aggregation) |
| **Net profit after expenses** | `daily_rollups.net_profit` = gross − `expenses` |
| Profit by product / category / branch | `product_daily_rollups` (grouped by `product_id` / `category_id` / `branch_id`) |
| Best performing / slow-moving | `product_daily_rollups` + `product_velocity` |
| No sales for X days | `product_velocity.last_sold_at` / absence of rollup rows in window |
| Total inventory value at cost | `inventory_valuation.inventory_value` |
| **Expected profit from current inventory** | `inventory_valuation.expected_profit` (units priced at `products.default_price`, quantity at `stock_items.price`) |

**Selling-price reference for in-stock individual units:** a `Unit` has no per-unit price until sold, so *expected* revenue/profit for in-stock units uses **`products.default_price`** (when unset, that product's units are excluded from expected-profit with a "no list price" flag). Realized profit always uses the exact `sale_items.price`/`cost`. **No analytics path references IMEI/serial.**

Migrations run as `phonestore_migrator`; app user's schema-level grant already covers new tables; append-only triggers are unaffected.

---

## 6. REST endpoints (all `/api/v1`, bearer + `@RequirePermissions`, `X-Branch-Id` where branch-scoped)

| Module | Endpoint | Permission | Purpose |
|---|---|---|---|
| catalog | `GET /products` `POST /products` `PATCH /products/:id` | (varies) / `settings.manage` | catalog CRUD |
| catalog | `GET /products/search?q=` | authed | FULLTEXT search |
| catalog | `GET/POST /categories` `PUT /categories/:id` | `settings.manage` | categories + attribute schema (2C.5) |
| scanner | `POST /scan` | `unit.add`\|`sale.create` | IMEI/serial/barcode/unknown (2C.5) |
| suppliers | `GET/POST/PATCH /suppliers`, `POST /suppliers/:id/payments` | `supplier.manage` | suppliers + payables |
| purchasing | `POST /purchases` | `purchase.manage`,`unit.add` | receive batch → units/stock |
| inventory | `POST /units` (quick add) | `unit.add` | supplier-less quick add |
| inventory | `GET /units/:identifier` | `unit.add`\|`sale.create` | unit detail (imei/serial) + **timeline** |
| inventory | `GET /inventory?status=&productId=` | authed | branch stock list |
| inventory | `POST /units/:id/faulty` | `unit.add` | mark faulty |
| sales | `POST /sales` | `sale.create` (+`discount.*`) | sell (transactional) |
| sales | `POST /sales/:id/returns` | `sale.return` | return/reverse |
| sales | `GET /sales` `GET /sales/:id` | authed (cost gated) | list/detail |
| transfers | `POST /transfers` `/:id/ship` `/:id/receive/{preview,confirm}` `/:id/cancel` | `unit.transfer` | branch transfers |
| closing | `POST /closings` `GET /closings/:date` `GET /digests/:date` | `closing.perform` | close day + digest |
| analytics | `GET /home` `GET /dashboard` | authed (cost gated) | store totals + trends |
| analytics | `GET /analytics/products` `GET /analytics/categories` | `report.view`+`cost.view` | profit by product/category, losers, non-sellers |
| analytics | `GET /analytics/inventory-value` | `report.view`+`cost.view` | $ invested (units + stock), by product/category/branch |
| analytics | `GET /health-score` | authed | health (R-A-G) |

**Cost/profit gating:** a response serializer strips `cost`/`margin`/`total_cost`/COGS fields for roles lacking `cost.view` (extends the Sprint-1 interceptor with a permission-aware rule).

---

## 7. DTOs (key shapes — conceptual, class-validator)
- `CreatePurchaseDto { supplierId?, paidAmount?, dueDate?, lines: [{ imeiPrimary, imeiSecondary?, productId?, cost }], accessories?: [{ productId, quantity, cost, price }] }`
- `CreateSaleDto { lines: [{ imei? | productId+quantity }], discount?, payments: [{ method, amount }], customerId?, priceOverrides?, overrideReason? }` (+ `clientUuid` for idempotency)
- `CreateTransferDto { toBranchId, unitIds | imeis[] }` · `ReceiveTransferDto { unitIds? }`
- `CreateClosingDto { countedCash }`
All ids are UUID strings at the boundary → converted to Buffers server-side.

---

## 8. Transaction boundaries
- **Sell:** one interactive transaction — validate unit(s) in-stock → increment invoice counter → create `Sale`/`sale_items`/`payments` → set unit(s) `sold` → write audit → (after commit) `RollupService.markDirty` + notifications. Sold-once DB index is the final backstop.
- **Receive (bulk):** chunked transactions (e.g. 200 units/chunk) → units + purchase + payable + audit; valid lines commit, rejects returned.
- **Transfer send/receive:** one transaction (status changes + audit).
- **Return:** one transaction (void sale line via `voided`, restore unit, adjust balances, audit).
- **Closing:** aggregate → create `DailyClosing` + `DailyDigest`(+lines) → lock → audit; digest generation may be a job for large days.
- **Idempotency:** `Sale.clientUuid` unique → offline retries never double-apply.

---

## 9. Testing plan
- **Unit:** `UnitStateMachine`, invoice formatting, profit math, cost-gating serializer, recognition (TAC mapping), rollup math.
- **Integration (against WAMP MySQL):** receive→sell happy path; duplicate-IMEI block; sell-not-in-stock block; sold-once under concurrency; below-cost override + audit; transfer send/receive; return reverses profit; closing locks + digest lines; tenant isolation (cross-company read returns nothing); cost fields hidden without `cost.view`.
- Extend the Sprint-1 Jest setup; add a small integration harness that logs in as the seeded owner.

---

## 10. Build sub-phases (checkpoints)
- **2A — Shared + Catalog + Receiving:** TenantContext, AuditService, InvoiceNumberService, UnitStateMachine, migration 0004; catalog + recognition + purchasing/inventory intake. *Done: receive stock end-to-end, IMEI unique enforced.*
- **2B — Sales + Profit + Timeline:** sell (transactional), returns, payments, profit, `GET /units/:imei` timeline. *Done: scan→sell works; profit exact; sold-once holds.*
- **2C — Transfers:** send/receive/cancel + in-transit safety. *Done: move stock between branches.*
- **2D — Analytics + Closing:** migration 0005, RollupService/queue, `/home` `/dashboard` `/health-score`, closing + digest. *Done: dashboards read rollups; day closes with digest.*
- **2E — Wiring + hardening:** notification events across the spine, cost-gating serializer, full test pass, docs. *Done: spine complete + tested.*

Each sub-phase ends with a build + test + short report, per CLAUDE.md.

---

## 11. Risks
- **Extension-in-transaction** (see 4.1) → mitigated by explicit `companyId` in transactional ops; verified first.
- **Concurrency** (sold-once, invoice seq) → DB unique index + `FOR UPDATE` counter; covered by a concurrency test.
- **Redis absence** → `RollupQueue` abstraction with in-process fallback (P1).
- **Cost leakage** → permission-aware serializer + tests asserting fields are stripped.
- **Scope creep** → reservations/trade-ins/CSV-UI explicitly deferred.

---

## 12. Decisions needed before coding
- **⚠️ P1 — Rollup infra:** approve the **`RollupQueue` abstraction (in-process dev / BullMQ prod)**, or direct me to install Redis for dev now.
- **⚠️ P2 — Migrations 0004 + 0005** column designs (§5) — approve as drafted, or adjust.
- **⚠️ P3 — Sub-phase gating:** OK to proceed **2A → 2E** with a checkpoint (build+test+report) after each, without re-approval between sub-phases (only re-approving on a genuine architectural deviation or a new migration)?

## 13. Next step
On approval of P1–P3, begin **Sub-phase 2A** (shared building blocks + migration 0004 + catalog/receiving), explaining each major piece before writing it and checking in at the 2A checkpoint.
