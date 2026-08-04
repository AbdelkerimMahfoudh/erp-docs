# 07 — Database Requirements

The data model that makes the business rules enforceable. This is **conceptual** — entities, key fields, and relationships — not final SQL. Final schema follows once the stack is confirmed (see architecture doc).

Design priorities: **multi-tenant isolation, IMEI integrity, exact per-unit costing, per-branch scoping, and a complete audit trail.**

> **Multi-tenancy rule (see [`06_TECHNICAL_ARCHITECTURE.md`](06_TECHNICAL_ARCHITECTURE.md) §3):** a **Company** is the top tenant. **Every table below carries `company_id`** and is scoped by it (enforced server-side), even where not repeated on each entity. `branch_id` scopes within a company.

---

## Tenancy & access entities

### Company (top tenant)
- id, name, currency, timezone, settings (JSON), is_active
- Relationships: has many Branches, Users, and every other record (via `company_id`).
- Root of all data isolation — no query crosses companies.

### Role
- id, company_id, key (`owner|administrator|branch_manager|sales_employee|warehouse_employee`), name
- Relationships: has many Permissions (via RolePermission); assigned to Users (per branch).
- **Administrator** = technical setup admin (users/settings/integrations); money visibility is a *separate* permission grant, not implied. See [`03_USER_ROLES.md`](03_USER_ROLES.md).

### Permission
- id, key (e.g. `sale.create`, `cost.view`, `discount.override`, `branch.manage`, `report.view`), description
- **RolePermission** join (role ↔ permissions).
- Checked **server-side** on every request; drives field stripping (e.g. cost/profit hidden for roles without `cost.view`).

---

## Core entities

### Branch
- id, company_id, name, type (`store|warehouse`), address, phone, is_active
- Relationships: has many Users (via UserBranch), Units, Sales, Expenses, Closings.

### User (staff)
- id, company_id, name, phone/login, password_hash (Argon2id), is_active
- **UserBranch** join (a user ↔ branches they can access, with a **role per branch**).
- Relationships: makes Sales, performs actions in AuditLog. Role/permissions resolved via Role + Permission above (not a bare string).

### Product (catalog / model, not a physical unit)
- id, brand, model, variant (storage, color), category (`phone|accessory|...`), default_cost, default_price, is_serialized (true for phones/IMEI, false for accessories), reorder_threshold
- Relationships: has many Units (if serialized) or StockItems (if not).

### Unit  ← the IMEI-tracked physical phone (the heart of the system)
- id, product_id, **imei_primary (UNIQUE)**, imei_secondary (nullable, unique when present), serial_no
- cost (actual purchase cost of THIS unit), status (`in_stock|reserved|sold|returned|faulty|in_transit|transferred_out`)
- branch_id (current location), supplier_id (where it came from), purchase_id
- date_in, date_sold (nullable)
- **Constraints:** imei_primary globally unique; a unit can be linked to at most one completed Sale.
- Relationships: belongs to Product, Branch, Supplier; has one Sale (when sold); has many status-change AuditLog entries.

### StockItem  ← non-serialized inventory (accessories, chargers)
- id, product_id, branch_id, quantity (>= 0), cost, price
- **Constraint:** quantity cannot go negative.

### Supplier
- id, name, phone, notes
- Relationships: has many Purchases; has a running Payable balance.

### Purchase (buying stock from a supplier)
- id, supplier_id, branch_id, user_id, date, total_amount, amount_paid, status (`paid|partial|unpaid`), due_date
- Relationships: has many PurchaseItems / Units added to stock.
- **PurchaseItem:** purchase_id, product_id, quantity, unit_cost (+ links to the specific Units created).

### Sale
- id, branch_id, user_id (seller), customer_id (nullable), date/timestamp
- subtotal, discount, total, **total_cost** (sum of sold units' actual cost → exact margin), margin (derived)
- payment_status (`paid|partial|credit`), amount_paid, balance_due, due_date (nullable)
- Relationships: has many SaleItems, has many Payments.
- **SaleItem:** sale_id, unit_id (for serialized) or product_id+quantity (for non-serialized), price, cost, discount.
- **Payment:** sale_id, method (`cash|card|mobile|other`), amount, timestamp. (Sum of payments must reconcile to amount_paid.)

### Return
- id, sale_id, unit_id/product_id, reason, date, user_id, refund_amount, restock (bool → back to in_stock or faulty)
- Reverses the relevant Sale figures; never deletes the Sale.

### Customer (optional, lightweight)
- id, name, phone, notes, balance (receivable if they owe on credit)

### StockTransfer (between branches)
- id, from_branch_id, to_branch_id, user_id_sent, user_id_received, status (`in_transit|received|cancelled`), date_sent, date_received
- **TransferItem:** transfer_id, unit_id (or product+qty).
- Drives the `in_transit` unit status until received.

### Expense
- id, branch_id, category (`rent|salary|utilities|misc`), amount, date, is_recurring, recurrence, note
- Recurring expenses generate monthly instances.

### DailyClosing
- id, branch_id, date, user_id, expected_cash, counted_cash, difference, total_sales, total_profit, is_locked, notes
- One (locked) closing per branch per day.

### Notification
- id, branch_id/user_id (target), type, title, body (plain language), is_read, action_link, created_at

### AuditLog  ← append-only, the trust backbone
- id, user_id, branch_id, entity_type, entity_id, action (`create|update|delete|status_change|override|login`), before/after (or diff), reason, timestamp
- Never updated or deleted from app flows.

### Setting / Threshold (per shop / per branch)
- low_stock threshold, dead_stock_days, discount limits per role, health-score weights, summary schedule, etc.

### DailyDigest (in-app notification center snapshot)
- id, company_id, branch_id, date, revenue, cost_of_goods_sold, gross_profit, generated_at (immutable)
- **DigestLine** (one per sold unit): imei, product, employee_id, sale_price, purchase_cost, profit, payment_method, sold_at
- Purpose: the **full detail** that stays inside the app when opening a day (per the vision). WhatsApp sends only the header totals, never these lines.
- Snapshot at closing; references source Sales but is stored immutably for fast, permanent history.

### ImportBatch / ImportRow (Excel/CSV inventory import)
- ImportBatch: id, company_id, branch_id, user_id, file_ref (S3), status (`parsing|preview|committed|failed`), total_rows, valid_rows, error_rows, created_at
- ImportRow: id, batch_id, row_number, raw (JSON), parsed (product/imei/cost), status (`valid|warning|error`), message
- Validated (IMEI valid? duplicate? product known? cost present?) before commit; only valid rows create Units.

### Report (definition + generated snapshot)
- ReportDefinition: id, company_id, name, type (`profit|movers|dead_stock|debtors|employee|...`), params (JSON), owner_user_id
- ReportSnapshot: id, definition_id, generated_at, range, file_ref (export in object storage)
- Reports **reference** source tables; a snapshot is an export, never a second source of truth.

### SyncState / Outbox (offline support — see architecture §5)
- Device: id, company_id, user_id, device_id, last_pull_cursor, last_seen_at
- OutboxChange (client-side, mirrored server-side for idempotency): id (client UUID), device_id, entity_type, entity_id, op, payload, status (`pending|accepted|conflict|rejected`), reason
- Client UUID makes every change **idempotent** so retries never double-apply.

---

## Key relationships (at a glance)
- Branch **1—∞** Users (via UserBranch), Units, Sales, Expenses, Closings.
- Product **1—∞** Units (serialized) / **1—∞** StockItems (non-serialized).
- Unit **1—1** Sale (when sold); Unit **∞—1** Supplier & Purchase.
- Sale **1—∞** SaleItems, **1—∞** Payments; Sale **1—∞** Returns.
- Supplier **1—∞** Purchases; Purchase **1—∞** Units.
- StockTransfer moves Units between two Branches.

## Integrity requirements (enforced at DB + API level)
1. **imei_primary UNIQUE** globally; imei_secondary unique when present.
2. A Unit reaches `sold` through exactly one Sale; re-selling a `sold` unit is impossible.
3. StockItem.quantity and Payable/Receivable balances **cannot go negative**.
4. Payments on a Sale reconcile to amount_paid; SaleItems reconcile to subtotal.
5. Money records are **never hard-deleted** — corrections are reversals with audit entries.
6. Cost/profit columns are **omitted server-side** for roles without permission.
7. All timestamps stored in a consistent timezone (UTC) with branch-local display.

## Reporting/derived data (computed, not hand-entered)
- Margin = price − cost (per unit, exact). Net profit = margin − expenses.
- Days-of-stock-left = quantity ÷ recent sales velocity.
- Health Score = weighted formula over trends, coverage, debts, dead stock.
- These may be **rolled up into summary tables** / cached for dashboard speed but always derive from source tables. *(MySQL has no materialized views — maintained rollup tables are used; see [`10`](10_DATABASE_SCHEMA.md) M5.)*

## 🔒 Decisions (frozen 2026-07-29)
- **Engine = MySQL 8 (InnoDB) + Prisma** *(changed from PostgreSQL 2026-07-29)*. Tenant isolation is **app-layer** (no RLS); UUIDv7 stored as **BINARY(16)**; sold-once / company-wide-settings uniqueness via **generated columns**; timestamps **DATETIME(6) UTC**. See [`06`](06_TECHNICAL_ARCHITECTURE.md) M1–M6 and [`10`](10_DATABASE_SCHEMA.md).
- **Costing = exact per-unit.** Each Unit carries its own `cost`; profit uses that specific unit's cost. (D4)
- **Tax/VAT deferred to v2, schema tax-ready.** Single currency in v1. Monetary lines store explicit **net** amounts; reserved `tax_total` (Sale/Purchase) and per-line `tax_amount` default `0` now, so v2 adds no structural change. (D9)
- **Scale target v1:** ~500k Units · ~100k sales/year · up to 100 branches, with headroom to grow. At these volumes plain indexing suffices; tables are designed **partition-ready** for later. (D10)
- **Administrator role** kept separate from Owner; money visibility is a distinct permission grant. (D11)
- Customer entity stays **lightweight** (name + phone + balance) in v1.

> The concrete columns, types, keys, and indexes live in [`10_DATABASE_SCHEMA.md`](10_DATABASE_SCHEMA.md).
