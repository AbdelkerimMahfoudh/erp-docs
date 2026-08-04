# 16 — Sprint 2 Design Specification: The Product Spine

> **Status:** DESIGN for review. No business code yet.
> **Scope:** the end-to-end "spine" that makes the app worth using — **receive stock → scan IMEI → recognize product → sell → profit → timeline → notify → dashboard/health → close the day**, plus **branch transfers** and **offline** behavior.
> **Builds on Sprint 1** (auth, RBAC, tenant isolation, TENANT_PRISMA, NotificationsService, audit_logs, exact per-unit costing, sold-once generated column, DailyClosing/DailyDigest). References [`06`](06_TECHNICAL_ARCHITECTURE.md) · [`10`](10_DATABASE_SCHEMA.md) · [`15`](15_SECURITY_ARCHITECTURE.md).
> **Out of scope for Sprint 2:** full dashboard/BI UI, reports, WhatsApp send, ML — only the spine + the hooks the spine emits into them.

---

## 0. Principles carried into every workflow
- **Fewest taps.** The common path is 2–3 taps. Scan/pick/confirm — never free-type what can be derived.
- **Fail closed & explain in plain words.** Every block/warning states *why* and *what to do*.
- **Server is the source of truth** for IMEI uniqueness, sold-once, cost, and money — the device is optimistic and reconciles.
- **Everything leaves a trail.** Money-affecting and status-changing actions write `audit_logs` (append-only) and feed the unit timeline.
- **Exact per-unit costing (D4).** Profit uses the specific unit's `cost`, captured on the sale line — never an average.
- **Tenant + branch scoped.** Every query carries `company_id` (auto) and, where relevant, the active branch.

### Permission map (from the 17-key catalog)
| Workflow | Permission(s) |
|---|---|
| Receive / purchases | `unit.add`, `purchase.manage`, `supplier.manage`, `import.run` |
| Sell | `sale.create`, `discount.apply`, `discount.override`, `sale.return` |
| See cost/profit | `cost.view` |
| Transfers | `unit.transfer` |
| Daily closing | `closing.perform` |
| Expenses | `expense.manage` |

---

## 1. Quick Actions Home Screen

The home screen is a **launcher of verbs**, not a menu of nouns. It adapts to the signed-in role and the branch.

```
┌───────────────────────────────────────────┐
│  Good morning, Karim · Main Store          │  ← greeting + branch switcher
│  Today: 6 sales · +18% vs yesterday        │  ← one alive headline (cost.view only)
├───────────────────────────────────────────┤
│   [ 📷 SELL ]        [ ➕ ADD STOCK ]       │  ← two giant primary actions
│                                            │
│   [ 🔍 Find IMEI ]   [ 🔁 Transfer ]        │
│   [ 🧾 Purchases ]   [ 🌙 Close Day ]        │  ← secondary, role-filtered
├───────────────────────────────────────────┤
│  ⚠ Needs attention (3)                     │  ← tap → attention feed
│   • iPhone 16 Pro — 3 left (~5 days)       │
│   • Karim's shop owes 12,000 (9d late)     │
├───────────────────────────────────────────┤
│  🔔 3   ⚙                                   │  ← notifications, settings
└───────────────────────────────────────────┘
```

**Rules**
- The **two biggest, thumb-reachable buttons are SELL and ADD STOCK** — both open straight into the camera.
- Buttons render **only if the role has the permission** (e.g. Close Day needs `closing.perform`; the money headline needs `cost.view`).
- The greeting headline is a single alive sentence; the attention list is the top 2–3 items (full list one tap away).
- **Branch switcher** in the header sets the active branch (`X-Branch-Id`) for every subsequent action.
- Long-press SELL/ADD STOCK offers "type instead" for the rare no-camera case.

**Performance:** the home payload is a single lightweight `GET /home` aggregate (greeting, headline number, attention count + top items, unread count) served from **rollup tables + Redis**, target < 200 ms; never scans base tables.

---

## 2. Smart Forms Philosophy

> A form is a **confirmation surface**, not a data-entry surface. The app arrives with an answer; the user nudges it.

Principles applied to every form in the spine:
1. **Scan first.** IMEI, and (where possible) the product, come from the camera.
2. **Recognize, then prefill.** Product, storage, default price, last supplier, current branch, today's date, the logged-in employee — all pre-filled.
3. **Smart defaults from history.** The shop's own most-frequent product/price/supplier float to the top.
4. **One decision per screen.** Break anything long into scannable, mostly-prefilled steps; the user taps "confirm" more than they type.
5. **Inline validation with plain-language help**, never a wall of red at submit.
6. **Bulk by default** for repetitive work (add 10 of the same model in one motion).
7. **Undo over confirm-dialogs** where the action is reversible.
8. **Progressive disclosure** — advanced fields (IMEI2, serial, notes, cost override) hidden behind "more".

**"Taps to complete" targets:** Sell a scanned in-stock phone at list price = **2 taps** (scan → confirm). Add one scanned unit at default cost = **2 taps**. Bulk-add N identical units = **1 tap + N scans**.

---

## Workflow specification format
Each workflow below is specified as: **User steps · System actions · Validations · Failure scenarios · Notifications · Audit events · Performance.**

---

## 3. Workflow 1 — Receiving Inventory (Purchase → Stock)

Turn arriving stock (from a supplier) into tracked `units` / `stock_items`, and record what's owed.

**User steps**
1. Tap **Purchases → New** (or **Add Stock** for a quick, supplier-less intake).
2. Pick supplier (searchable; "last used" on top) — or skip for quick intake.
3. Scan each unit's IMEI (see WF2); the product auto-recognizes (WF3). Confirm cost (defaults to last cost for that product).
4. For accessories, pick product + quantity.
5. Review the batch total; set amount paid now (full / partial / unpaid) + due date.
6. Confirm.

**System actions**
- Create a `Purchase` (+ `purchase_items`) and, for serialized lines, one `Unit` per IMEI (`status=in_stock`, `branch_id`=active branch, `cost`=entered, `supplier_id`, `purchase_id`).
- For accessories, upsert `stock_items.quantity`.
- Update the supplier **payable** balance (total − amount_paid).
- Emit timeline `unit.created` events; refresh stock-coverage rollups.

**Validations**
- IMEI valid (15 digits + Luhn) and **globally unique** (not already in stock/sold) — server-authoritative.
- `cost > 0`; quantity > 0; amount_paid ≤ total.
- Supplier belongs to the company (tenant-scoped).
- Requires `unit.add` (+ `purchase.manage` for the payable side).

**Failure scenarios**
- **Duplicate IMEI** → block that line, keep the rest; "This IMEI is already in stock (added 12 Jul) / already sold." Offer "view unit".
- Invalid IMEI → reject line with reason; allow OCR/manual retry.
- Partial batch commit: valid lines commit, rejected lines listed for correction (never lose the good ones).
- Supplier over-credit / negative paid → block with explanation.

**Notifications**
- Owner/manager: "Received 12 units (value 1,240,000) from Karim Trading" (in-app; batched, not per-unit).
- If payable created with near due date → adds a "Needs attention" item.

**Audit events**
- `Unit.create` (per unit), `Purchase.create`, `SupplierPayment.create` (if paid), payable change. Each with actor + branch.

**Performance**
- Bulk insert units in **one transaction** (chunked for large batches); IMEI duplicate check via the unique index (O(log n) each) + a single pre-check query for the scanned set.
- Camera/scan is on-device; server sees validated candidates only.

---

## 4. Workflow 2 — IMEI Scanning

The on-device capture pipeline (client-side; server validates).

**User steps**
1. Point camera at the box barcode (or device screen `*#06#`).
2. App reads it instantly; shows "iPhone 16 Pro · IMEI ✓". For dual-SIM, prompts for the 2nd if present.
3. Tap confirm (or it auto-advances in bulk mode).

**System actions (client)**
- ML Kit barcode → fallback OCR of printed "IMEI:"; extract 15-digit candidate(s); validate length + **Luhn** locally for instant feedback; check the **local** DB for duplicates.
- Optionally store the scan image for dispute (uploaded lazily).

**System actions (server, on sync/commit)**
- Re-validate + enforce **global uniqueness** authoritatively.

**Validations**
- Exactly 15 digits, Luhn-valid; dual-SIM = two distinct valid IMEIs.

**Failure scenarios**
- Unreadable barcode → auto-switch to OCR → manual entry as last resort ("type it instead").
- Local duplicate → immediate block; server duplicate on sync → conflict surfaced (WF14).
- Bad lighting/glare → guidance overlay.

**Notifications** — none (silent, in-flow).

**Audit events** — none at scan time; the resulting add/sell/transfer carries the audit.

**Performance** — fully on-device, no network; sub-second. The 15-digit unique index makes server duplicate checks trivial.

---

## 5. Workflow 3 — Automatic Product Recognition

Turn an IMEI/scan into a known catalog product with as few taps as possible.

**User steps**
1. After a scan, the app shows the recognized product; user confirms or corrects (searchable picker).
2. If unknown, a **1-line "new product?"** prompt prefilled from TAC guess.

**System actions**
- Map **TAC** (first 8 IMEI digits) → make/model via `tac_catalog`; combine with the shop's **own catalog** and **learned history** (most-sold/most-recent) to pre-select `Product` (+ default storage/variant, default price/cost).
- On confirmation of a new product, create a `Product` (guarded by catalog permission) and learn it for next time.

**Validations**
- Product belongs to the company; storage/variant sane vs recognized model (soft warning on mismatch).

**Failure scenarios**
- TAC unknown / ambiguous → present best guesses + search; never block, always allow manual pick.
- Wrong auto-match → one tap to correct; the correction is learned.

**Notifications** — none.

**Audit events** — `Product.create` when a new product is added.

**Performance** — `tac_catalog` PK lookup + a small per-company catalog cache; recognition is instant and offline-capable (TAC table shipped/cached on device).

---

## 6. Workflow 4 — Smart Forms with Minimal Typing
(Cross-cutting — governs WF1/WF6/WF15 forms; see §2 for philosophy.)

**User steps** — confirm prefilled values; expand "more" only when needed.

**System actions** — prefill from: recognition, last-used supplier, current branch, default price/cost, today's date, logged-in employee; compute margin live as price changes.

**Validations** — inline, per field, plain language; block only on hard rules (below-cost needs override, invalid IMEI, negative qty).

**Failure scenarios** — never lose entered data on validation error; keep the batch; highlight only the offending field.

**Notifications** — none.

**Audit events** — inherited from the committing action; **overrides** (e.g. price below cost, discount above limit) are audited with `reason`.

**Performance** — no server round-trips for prefill (client cache); one submit per batch.

---

## 7. Workflow 5 — Inventory Movements (Unit lifecycle)

The state machine every serialized unit obeys. Movements are **status changes**, always logged.

```
                 reserve                 sell
   in_stock ───────────────► reserved ─────────► sold
      │  ▲   (release)  ◄───────┘                  │
      │  └───────────────── return ◄───────────────┘
      │
      ├── transfer_out ──► in_transit ──receive──► in_stock (new branch)
      │                                   │
      │                              (cancel) ─► in_stock (origin)
      └── mark_faulty ──► faulty
```

**User steps** — implicit (a sell, a transfer, a return triggers the move); explicit for "mark faulty" / "reserve".

**System actions**
- Apply the transition, set `branch_id`/`date_sold` as appropriate, write a timeline event, refresh coverage rollups.

**Validations**
- Only legal transitions allowed (e.g. can't sell `in_transit`/`faulty`/`sold`; can't transfer `sold`).
- **Sold-once** enforced by the DB (`active_unit_id` unique) as the backstop.

**Failure scenarios**
- Illegal transition → block with plain reason ("This unit is in transit to Branch B and can't be sold here").
- Concurrent move (two devices) → server resolves; loser gets a clear conflict (WF14).

**Notifications** — status-dependent (e.g. "unit received", "unit marked faulty" to manager).

**Audit events** — `Unit.status_change` with from/to status, actor, branch, reason.

**Performance** — single-row update by PK + one audit insert, in a transaction; `(company_id, branch_id, status)` index keeps "in-stock at branch" queries fast.

---

## 8. Workflow 6 — Selling a Phone (the fastest flow)

**User steps** (target **2 taps** for the standard case)
1. Tap **SELL** → camera opens → scan IMEI. App shows product, **suggested price**, and (if `cost.view`) live margin.
2. (Optional) adjust price/discount, add trade-in/accessory, pick payment method, attach customer for credit.
3. Tap **Confirm sale** → receipt to print/share.

**System actions**
- Load the in-stock unit by IMEI (must be `in_stock` at the active branch).
- Create `Sale` (+ `sale_items` capturing `price` **and** `cost` from the unit, D4), `payments`; set unit `status=sold`, `date_sold`.
- Compute and store `total_cost`, `margin`; generate `invoice_no` (per-branch sequential).
- Record seller (`user_id`), branch, timestamp; append timeline + audit; emit notifications; refresh day rollups.
- For credit: set `balance_due`, `due_date`, update customer receivable.

**Validations**
- Unit exists, in stock, at this branch, not reserved/faulty/in-transit → else block.
- Payments sum to `amount_paid`; `amount_paid ≤ total` (credit for remainder).
- **Below-cost / abnormally-low price** → warn + require `discount.override`; **discount above role limit** → require approval (only if discount monitoring enabled).
- Requires `sale.create` (+ `discount.apply`/`discount.override` as needed).

**Failure scenarios**
- Selling an already-sold IMEI → **blocked** (sold-once); "already sold on 3 Aug at Branch A."
- Selling a unit that's in transit/faulty → blocked with reason.
- Payment mismatch → block with the exact delta.
- Offline double-sell of the "same" unit at two branches → server accepts first, **rejects second** on sync (WF14).

**Notifications**
- Owner/manager (in-app, possibly batched): "Sale: iPhone 16 Pro — 950,000 (margin 120,000) by Karim." Cost/margin shown only to `cost.view` roles.
- Milestone nudges ("3rd Samsung A55 this week — your fastest mover").

**Audit events** — `Sale.create`, `Unit.status_change → sold`, `Payment.create`, any `override` (below-cost/discount) with reason.

**Performance** — the whole sale in **one DB transaction**; IMEI lookup via unique index; `invoice_no` generation must be concurrency-safe (per-branch counter — see Open Question O2). Target < 300 ms server-side.

---

## 9. Workflow 7 — Profit Calculation

**User steps** — none (automatic); `cost.view` roles see margin live and on the receipt/day summary.

**System actions**
- Per line: `line_margin = price − discount − cost` (cost = the specific unit's cost, D4).
- Per sale: `total_cost = Σ line.cost`, `margin = total − discount − total_cost` (stored on `Sale`).
- Day/period: `gross_profit = Σ sale.margin`; `net_profit = gross_profit − expenses` (period); feeds `DailyDigest`, dashboard rollups, and Health.
- Returns reverse the corresponding margin.

**Validations** — cost present on every sold unit (guaranteed at intake); money uses `DECIMAL(14,2)` (no float).

**Failure scenarios** — missing cost (shouldn't happen; intake enforces) → flagged for correction, sale still recorded with a cost-review flag.

**Notifications** — surfaced via day summaries, not per-sale (except milestone/alive nudges).

**Audit events** — none beyond the sale/return; profit is derived, not entered.

**Performance** — computed at write time (stored on `Sale`) so dashboards read rollups, never recompute across millions of rows.

---

## 10. Workflow 8 — Timeline Event Generation (Unit history)

Every unit has a reconstructable life story; every sale/day too.

**User steps** — tap a unit (or scan its IMEI into search) → **timeline**: added → transferred → reserved → sold → returned, each with who/when/price.

**System actions**
- Timeline is a **read model derived from `audit_logs`** (entity_type in Unit/Sale/…) plus source rows (purchase, sale, transfer, return). Optionally a lightweight `unit_events` projection for fast reads (Open Question O3).
- Events are generated as a side effect of WF1/5/6/15 (never entered by hand).

**Validations** — read-only; tenant + permission scoped (cost fields hidden without `cost.view`).

**Failure scenarios** — none (read path); missing gaps impossible because audit is append-only.

**Notifications** — none.

**Audit events** — the timeline **is** the audit surface, presented human-readably.

**Performance** — `audit_logs (company_id, entity_type, entity_id, at)` index; per-unit timeline is a bounded, indexed lookup. Consider the `unit_events` projection if timelines get hot.

---

## 11. Workflow 9 — Internal Notifications

The spine emits domain events; the notification center + channels (Sprint 1 infra) deliver them.

**User steps** — tap 🔔 → list (own + broadcast); tap an item → deep link to the unit/sale/attention; mark read.

**System actions**
- Spine services call `NotificationsService.emit(...)` on: big/first-of-kind sale, low-stock threshold crossed, transfer received, payable/receivable due, cash variance at closing, anomaly flagged.
- In-app channel persists now; FCM/WhatsApp later (same interface). **Batching/de-dupe** to avoid noise (e.g. one "received 12 units", not 12).

**Validations** — target scoping (user vs branch vs company broadcast); tenant-scoped.

**Failure scenarios** — channel failure (future FCM) → in-app remains the source of truth; retry via job.

**Audit events** — notification emission itself is not audited (the underlying business event is).

**Performance** — writes are cheap single inserts; list read via `(company_id, target_user_id, is_read, created_at)` index; noisy events are aggregated by a debounce window.

---

## 12. Workflow 10 — Dashboard Updates

The spine keeps **rollup tables** fresh so the dashboard is instant (MySQL has no materialized views).

**User steps** — open home/dashboard → see today's revenue/COGS/gross profit/inventory value with trend vs prior period.

**System actions**
- On each sale/return/purchase/expense, either incrementally update **rollup rows** (per branch/day) or enqueue a **BullMQ job** to recompute the affected day (see Open Question O4 — incremental vs job).
- Metrics: revenue, COGS, gross profit (day/month/year), inventory value (Σ in-stock cost), sales velocity, days-of-stock-left, dead-stock age, debt aging. Cached in Redis.

**Validations** — rollups always reconcilable to source tables (a nightly reconciliation job checks drift).

**Failure scenarios** — rollup lag/failure → dashboard shows "as of HH:MM" and a recompute is retried; source data never wrong, only the cache is eventually consistent.

**Notifications** — none (dashboard is pull).

**Audit events** — none (derived data).

**Performance** — dashboards **never scan base tables**; read pre-aggregated rollups + Redis; recompute is incremental/branch-day scoped. Read replica for heavy reporting.

---

## 13. Workflow 11 — Business Health Updates

**User steps** — see the Health Score (0–100 / R-A-G) on home; tap → top factors in plain words.

**System actions**
- A scheduled job (and/or triggered on material events) recomputes the weighted score over: profit trend, cash flow, stock coverage (days left), overdue debts, dead-stock ratio, sales velocity — weights from `settings.health_score_weights`.
- Stores the score + factor breakdown per company/branch (small rollup); regenerates the **Needs Attention** feed.

**Validations** — weights sum sanity; explainability required (store the top contributing factors).

**Failure scenarios** — insufficient data (new shop) → show "warming up" instead of a misleading score.

**Notifications** — a significant health drop can emit an owner notification (threshold configurable).

**Audit events** — none (derived); weight changes are audited via `settings` update.

**Performance** — computed by a job over rollups (not raw rows); cheap to read; recompute cadence configurable (e.g. every sale batch or every N minutes).

---

## 14. Workflow 12 — Daily Closing Integration

The spine feeds the Sprint-1 `DailyClosing`/`DailyDigest` (closing UI itself may be later, but the spine must produce correct numbers).

**User steps** — tap **Close Day** → review day totals (sales, profit, per-employee, per-payment-method) → count cash → confirm.

**System actions**
- Aggregate the day's sales/returns/expenses for the branch; compute `expected_cash`, accept `counted_cash`, store `difference`, `total_sales`, `total_profit`; **lock** the day (`is_locked`, one per branch/day).
- Generate the immutable **`DailyDigest`** (+ `digest_lines`: per sold unit — IMEI, employee, price, cost, profit, method, time).
- Emit the owner summary event (in-app now; **WhatsApp short summary** is a later sprint but the digest is the source).

**Validations**
- Requires `closing.perform`; warn if a prior day is unclosed; a day closes **once**.
- Cash variance beyond a threshold → flagged (possible shortage).

**Failure scenarios** — attempt to re-close → blocked; post-close correction requires a higher role and is logged as an adjustment.

**Notifications** — owner/manager: the closing summary; cash-variance alert if over threshold.

**Audit events** — `DailyClosing.create`, day lock, any post-close adjustment (with reason).

**Performance** — day aggregation from rollups where possible; digest generation is a bounded per-branch-day job; `UNIQUE(branch_id, closing_date)` prevents double close.

---

## 15. Workflow 13 — Error Handling (Mistake-Prevention layer)

Cross-cutting. Every spine action passes through consistent guards.

**Categories & responses**
- **Block (hard):** duplicate IMEI, sell-already-sold, sell not-in-stock/faulty/in-transit, negative quantity, re-close a day. Plain reason + suggested fix.
- **Warn + override (soft):** below-cost/abnormally-low price, order-of-magnitude typo ("Did you mean 45,000 not 4,500?"), discount above role limit (if monitoring on), storage/variant mismatch. Requires the right permission + captures `reason`.
- **Flag (async):** inventory mismatch (expected vs counted), cash variance, unusual employee patterns → surfaced to manager, not blocking.

**System actions** — validation happens server-side (authoritative) and client-side (instant feedback); errors returned as the Sprint-1 `problem+json` with a stable machine `code` the app maps to friendly copy.

**Failure/edge** — never leak SQL/stack; always actionable message + request id.

**Notifications** — flags (not blocks) emit manager notifications.

**Audit events** — every override and every block-that-was-forced is audited with actor + reason.

**Performance** — validations are index-backed lookups; no heavy scans on the hot path.

---

## 16. Workflow 14 — Offline Behavior

The shop keeps selling with no internet; nothing is lost or double-counted on reconnect.

**User steps** — identical UX offline; a subtle "offline · N pending" indicator; actions feel instant.

**System actions**
- **Optimistic local writes** to the device DB (Drift); each change appended to the **outbox** with a client UUIDv7, device id, timestamp.
- On reconnect, the sync engine **pushes** the outbox and **pulls** server changes (catalog, prices, transfers). Every change is **idempotent** (client UUID) — retries never double-apply.
- **Server is authoritative** on IMEI uniqueness and sold-once.

**Validations / conflict resolution**
- **Two branches sold the "same" unit offline** → server accepts the first synced, **rejects the second**; the app shows "already sold at Branch X — please resolve" and the local sale is reversed.
- **Price/catalog edits** → server wins for shared catalog; a completed sale keeps the price captured at sale time.
- Non-critical fields → last-writer-wins by `updated_at`; **integrity is never last-writer-wins**.

**Failure scenarios**
- Long offline → "stale catalog" warning after a safe window.
- Sync error on an item → item stays pending with a clear per-item status (accepted/conflict/rejected + reason), rest proceed.

**Notifications** — on conflict rejection, a targeted "action needed" notification to the seller/manager.

**Audit events** — server records the accepted change normally; rejected/conflicted attempts recorded in `outbox_changes` with reason (traceable, not silent).

**Performance** — batched push/pull; server validates the scanned/sold set with index lookups; conflict resolution is per-item, not whole-batch abort.

---

## 17. Workflow 15 — Branch Transfers

Move units between branches with in-transit safety.

**User steps**
1. **Transfer → New**, pick destination branch.
2. Scan the units to move (WF2); review list.
3. Send. At the destination, staff **Receive** (scan or confirm) to complete.

**System actions**
- Create `StockTransfer` (+ `transfer_items`); set moved units `status=in_transit` (still owned by company, not sellable anywhere).
- On **receive**: units → `in_stock` at destination (`branch_id` updated), transfer `status=received`, `received_at/by`. On **cancel**: units revert to origin `in_stock`.

**Validations**
- `from_branch ≠ to_branch` (DB CHECK); units must be `in_stock` at origin; requires `unit.transfer`; user must have access to the relevant branch(es).
- Can't sell an `in_transit` unit at either end.

**Failure scenarios**
- Receiving a unit not in the transfer / already received → block with reason.
- Partial receive → receive scanned units, leave the rest `in_transit`; discrepancy flagged to managers.
- Lost-in-transit (never received) → surfaces in attention feed after N days.

**Notifications** — destination manager: "Incoming transfer: 5 units from Branch A." Origin: "Transfer received/partially received."

**Audit events** — `StockTransfer.create`, per-unit `status_change` (→ in_transit, → in_stock@dest), receive/cancel.

**Performance** — batch status updates in a transaction; `(company_id, branch_id, status)` index keeps per-branch stock views fast.

---

## 18. Cross-cutting catalogs

### 18.1 Audit event catalog (spine)
`Unit.create` · `Unit.status_change` · `Product.create` · `Purchase.create` · `SupplierPayment.create` · `Sale.create` · `Sale.override` (below-cost/discount, with reason) · `Payment.create` · `Return.create` · `StockTransfer.create/receive/cancel` · `DailyClosing.create` · post-close `adjustment`. All append-only, actor + branch + timestamp.

### 18.2 Notification event catalog (spine)
`sale.recorded` (batched) · `sale.milestone` · `stock.low` · `stock.dead` · `transfer.incoming` · `transfer.received` · `debt.due` · `closing.summary` · `cash.variance` · `sync.conflict` · `anomaly.flagged`. Debounced/aggregated to avoid noise; cost fields gated by `cost.view`.

### 18.3 Performance summary
- **Hot paths** (sell, add, scan-lookup): index-backed single-row ops in one transaction, < 300 ms.
- **Dashboards/health**: rollup tables + Redis, never base-table scans; recompute is branch-day scoped via jobs.
- **Bulk intake/transfer**: chunked transactions.
- **Offline sync**: idempotent, per-item, batched.

---

## 19. Decisions (✅ approved 2026-07-29)
- **O1 — Sprint 2 boundary:** ✅ **Backend services + REST endpoints** for the spine; mobile app in a later sprint.
- **O2 — Invoice numbering:** ✅ **Dedicated `branch_counters` table** with atomic increment (gap-free, concurrency-safe).
- **O3 — Unit timeline:** ✅ **Audit-derived** to start; add a `unit_events` projection only if timelines become hot.
- **O4 — Rollup maintenance:** ✅ **Per-branch-day recompute jobs** (BullMQ) for isolation; incremental later if latency needs it.
- **O5 — Reservations:** ✅ **Deferred.**
- **O6 — Trade-ins:** ✅ **Deferred.**
- **O7 — New schema:** ✅ Approve in principle: `branch_counters` + rollup tables; each ships as its own migration reviewed in the implementation plan ([`17`](17_SPRINT2_IMPLEMENTATION_PLAN.md)).

**Status: design approved → technical implementation plan in [`17_SPRINT2_IMPLEMENTATION_PLAN.md`](17_SPRINT2_IMPLEMENTATION_PLAN.md).**

---

## 20. Recommended next step
On approval of §19, produce the **Sprint 2 technical implementation plan** (module list, endpoints, DTOs, transaction boundaries, new migrations) — then implement per-CLAUDE.md with explain-before-build gating. No business code is written until that plan is approved.
