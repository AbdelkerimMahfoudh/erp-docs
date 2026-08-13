# 26 — Quantity-stock cost and inventory valuation (H1.4.1)

> **Read-only audit, taken before any code changed.** Everything below is what
> the code and the database **do today**, traced from source and measured
> against real MySQL — not what any document says they should do.
>
> Phase **H1.4.1**, owner **CLAUDE-B**. H1.4 (CLAUDE-A) closed quantity
> transfers and correctly averaged cost on transfer receipt; it recorded, in its
> own handoff, that **purchase intake still does not average cost.** This is
> that gap, measured.

---

## 1. The defect, in one sentence

**Receiving more of an accessory at a different price keeps the first price
forever.** Quantity moves, cost does not — so the shop's cost of goods drifts
away from what it actually paid, silently, and always in the direction that
makes the business look *more* profitable than it is.

---

## 2. Every path that creates or increases quantity stock

Traced by searching for every `stockItem` write and every raw statement naming
`stock_items`. Fixtures and seed code are listed separately in §2b.

| # | Path | Code | Creates / increments | Incoming cost from | Averages? |
|---|---|---|---|---|---|
| 1 | **Purchase receiving** (manual, scanned and grouped — one endpoint) | `purchasing.service.ts` `upsert` | both | the purchase line | ❌ **NO** |
| 2 | **Quick "Add Stock"** (`POST /inventory/units`, `unit.add`) | `inventory.service.ts` `upsertStock` | both | the request body | ❌ **NO** |
| 3 | **Transfer receipt into an existing row** | `quantity-reservation.ts` `receiveIntoExisting` | increments | the shipment snapshot | ✅ yes |
| 4 | **Transfer receipt into a new row** | `transfers.service.ts` `stockItem.create` | creates | the shipment snapshot | ✅ n/a — first stock |

There is **no** import path that writes stock (`ImportBatch` has no writer), and
**no** adjustment, correction, recount or stocktake path exists at all. Offline
replay is not implemented for purchases; the only replay seam is the
`clientUuid` idempotency key, covered in §5.

### Outflow and price-only paths, for completeness

| Path | Code | Effect on cost |
|---|---|---|
| Sale of quantity stock | `sales.service.ts` conditional decrement | none — correct under weighted average |
| Transfer shipment | `quantity-reservation.ts` `shipQuantity` | none — correct |
| Transfer reserve / release | `reserveQuantity` / `releaseQuantity` | none; `quantity` untouched |
| Branch price edit | `pricing.service.ts` `updateMany` + version CAS | price only |

### 2b. Fixtures and seed — NOT production

`prisma/seed.ts` and the spec doubles under `src/**/__testing__/` also create
stock rows. They are development scaffolding, are never reachable from the API,
and are deliberately excluded from every count in this document.

---

## 3. The two defective writes, quoted

Both are the same mistake, written twice.

```ts
// purchasing.service.ts — purchase receiving
await tx.stockItem.upsert({
  where:  { companyId_productId_branchId: { companyId, productId: l.productId, branchId } },
  create: { …, quantity: l.quantity, cost: l.cost, price: l.price },
  update: { quantity: { increment: l.quantity } },   // ← cost is never touched
});
```

```ts
// inventory.service.ts — quick "Add Stock"
await this.db.stockItem.upsert({
  where:  { companyId_productId_branchId: { companyId, productId, branchId } },
  create: { …, quantity, cost, price },
  update: { quantity: { increment: quantity } },     // ← same omission
});
```

The `create` branch is right: first stock in a branch takes the incoming cost.
The `update` branch increments quantity and leaves `cost` at whatever the
**first ever** receipt paid.

**Neither is a concurrency bug.** `upsert` with `{ increment }` is atomic, so no
quantity is lost. The defect is purely financial: the cost is stale.

### A third, smaller defect on the same line

`inventory.service.ts` passes `dto.price ?? Number(product.defaultPrice ?? 0)`.
`price` has been **nullable since `0034`** precisely so a row can be *unpriced*.
Coercing a missing default to `0` creates stock that reads as "sells for free"
rather than "nobody has priced this yet". Zero such rows exist today (§6), so
this is a latent trap rather than live damage.

---

## 4. Every consumer of `StockItem.cost`

| Consumer | Reads | Classification |
|---|---|---|
| Below-cost protection (`pricing.service`) | `stock.cost` live | **direct source-of-truth** |
| Quantity sale margin | `SaleItem.cost` **snapshot**, written at sale time | direct, immutable |
| Transfer shipment snapshot | source `stock.cost` at ship | direct, then frozen on the line |
| Transfer receipt averaging | destination row, inside the UPDATE | direct |
| Inventory list / catalog detail | `stock.cost`, cost-gated | direct |
| **Inventory value** (`/analytics/inventory-value`) | `InventoryValuation` table | **persisted rollup, eventual** |
| **Dashboard** | `InventoryValuation` | **persisted rollup, eventual** |
| **Health score** | `InventoryValuation` | **persisted rollup, eventual** |
| In-transit value | `transfer_items` joined live | **direct source-of-truth** |
| Daily closing | `dailyRollup`, **refreshed synchronously first** | persisted rollup, but *awaited* |
| Daily/branch COGS | `sale_items.cost` snapshots | direct, immutable |

**No monthly summary exists** — the grep returns nothing. That row of the brief
describes a surface that has not been built.

---

## 5. Idempotency and concurrency, as they stand

| Property | Purchase receiving | Quick Add Stock |
|---|---|---|
| Idempotency key | `clientUuid` + payload fingerprint, `UNIQUE (company_id, client_uuid)` | **none** |
| Replay behaviour | returns the original purchase | would add stock again |
| Atomic with payable/audit/outbox | yes — one `$transaction` | n/a (no payable) |
| Quantity safe under concurrency | yes (`{ increment }`) | yes (`{ increment }`) |
| Cost safe under concurrency | **n/a — never written** | **n/a — never written** |

Quick Add Stock has no idempotency key at all. It is a single-product manual
action rather than a delivery, so this is recorded as a known limit rather than
treated as part of this phase.

---

## 6. Historical-data audit — measured, not assumed

Against the live development database, read-only.

| Check | Result |
|---|---|
| `stock_items.cost` nullable? | **NO** — `decimal(14,2) NOT NULL` |
| Positive quantity with NULL cost | **0** |
| Zero quantity retaining a cost | 0 |
| Negative quantity | 0 |
| Negative reserved | 0 |
| `reserved_quantity > quantity` | 0 |
| Positive quantity with cost ≤ 0 | 0 |
| Rows priced `0` ("sells for free") | 0 |
| Unpriced (`price IS NULL`) rows | 0 |
| Units with NULL or zero cost | 0 of 11 |
| CHECK constraints present | 3 — `reserved ≤ quantity`, `reserved ≥ 0`, `quantity ≥ 0` |

**The §3 stop condition does not fire.** `cost` is `NOT NULL` at the database
level, so "positive quantity, null cost" is structurally impossible and no
remediation decision is needed.

### 6b. Stored cost vs reconstructable purchase history

Reconstruction is **reliable for this dataset**: zero quantity transfer lines
have ever been received (`transfer_items` with a `product_id`: **0**), there is
no adjustment path, and sales do not alter cost under weighted average. So the
weighted average of the purchase lines *is* what the stored cost should be.

| Product | Stock qty | Stored cost | Purchase history | Should be | Drift |
|---|---|---|---|---|---|
| **Apple USB-C Cable** | 52 | **4.10** | 50 @ 4.10, then 10 @ 5.00 | **4.25** | **−0.15** |
| **Anker PowerCore 10000** | 15 | **8.50** | 10 @ 8.50, then 5 @ 9.00 | **8.6667** | **−0.1667** |
| Belkin Cable RU | 90 | 5.00 | 100 @ 5.00 | 5.00 | 0 |
| Belkin Cable V | 90 | 5.00 | 100 @ 5.00 | 5.00 | 0 |

The pattern is exact: **drift appears only where a second receipt arrived at a
different price.** The two single-price products are correct, which is precisely
what the defect predicts.

Understated inventory value today: **7.80 + 2.50 = 10.30 MRU** — trivial in the
demo, and unbounded in a real shop, because the error compounds with every
re-order at a new price and never self-corrects.

**No backfill is proposed here.** The stored values are *stale*, not *provably
invalid* — 4.10 was a real price really paid — so under the phase rule a
historical correction needs explicit approval. Recorded for the user's decision
in §9.

---

## 7. Valuation: what is authoritative and what is eventual

### How the refresh actually works

`InventoryValuation` is a **persisted rollup**, wiped and rebuilt per branch by
`RollupService.recomputeInventoryValuation`. It is triggered by an in-process
queue that is explicitly **fire-and-forget**:

```ts
enqueueBranchRefresh(job) {
  void this.rollups.refreshBranch(...).catch((e) => this.log.error(...));  // swallowed
}
```

Sales and transfers reach it through the spine event bus (`sale.recorded`,
`stock.moved`). **Purchase receiving calls the queue directly**, post-commit:

```ts
// purchasing.service.ts, after the transaction
this.rollups.enqueueBranchRefresh({ companyId, branchId });
```

> ### ⚠️ Correction to the first version of this audit
>
> The CP1 commit (`11f1540`) claimed purchases "emit neither event, so a
> purchase does not refresh valuation at all". **That was wrong.** It came from
> grepping the event bus and missing the direct queue call above. All three
> inflows do enqueue a refresh; the weakness below is uniform across them, not
> special to purchasing. Corrected here rather than by rewriting history, in
> keeping with how earlier count errors were handled.

### The consequence, stated precisely

| Read | Source | Stale window |
|---|---|---|
| Inventory value, Dashboard, Health | `InventoryValuation` rollup | from commit until the queued refresh lands — **indefinitely if it throws or the process dies first** |
| In-transit value | live query over `transfer_items` | none |
| Daily closing | `dailyRollup`, **`await`ed before reading** | none |
| COGS / margin / profit | `sale_items` snapshots | none |

**The crash case:** the refresh runs after commit, outside any transaction, with
its failure logged and discarded. If the process dies between commit and
refresh — or the refresh throws — the rollup stays stale **permanently**. There
is no dirty flag, no retry, and no reconciliation job.

### ✅ The finding that bounds this phase

**No finalized financial record depends on the eventual rollup.**

Daily closing calls `await this.rollups.recomputeDaily(...)` and then reads
`dailyRollup`, whose figures come straight from `sale_items` — the immutable
per-line cost snapshots. Closing never reads `InventoryValuation`. Neither does
any digest or locked record.

So the staleness is confined to three **reporting** surfaces (Inventory value,
Dashboard, Health). That is a real defect worth fixing, but it is *not* the
"closing silently depends on a stale rollup" scenario the brief guards against,
and it does **not** require an accounting redesign.

### Invariants, and where they hold today

| Invariant | Holds? |
|---|---|
| Purchase: company value += received × incoming cost | ❌ **wrong** — the refresh *is* enqueued, but it recomputes from a `cost` the purchase never updated, so the wrong figure is faithfully republished |
| Request / approval: company value unchanged | ✅ |
| Shipment: branch-held ↓, in-transit ↑, total unchanged | ⚠️ eventually — held is a rollup, in-transit is live |
| Receipt: in-transit ↓, destination-held ↑, total unchanged | ⚠️ eventually, same reason |

Mixing a **live** in-transit figure with a **stale** held figure is what makes
held + in-transit fail to reconcile inside the window. H1.4 recorded this as
"eventual, not instantaneous"; this audit adds *why*, and that purchases never
refresh at all.

---

## 8. Permissions and error surfaces — unchanged expectations

`cost.view` gating, per-line structured purchase errors, company/branch
isolation, audit logging and the recognition outbox all sit outside the cost
calculation and must not move. Transfer notifications carry no cost (H1.3), and
nothing in this phase adds one.

---

## 9. Decisions this audit asks for

1. **Fix both write paths** to average cost inside an atomic statement, reusing
   the `receiveIntoExisting` primitive H1.4 already proved. *(Proceeding — this
   is the phase.)*
2. ~~Make a purchase refresh valuation.~~ **Withdrawn — it already does.** See
   the correction in §7. Nothing to change.
3. **Stop coercing a missing price to `0`** on quick Add Stock; leave the row
   unpriced. *(Proceeding — `0` means "free", which is never what was meant.)*
4. 🔴 **Historical backfill of the two drifted rows — NOT proceeding without
   approval.** The correction is deterministic (§6b) but the stored values are
   stale rather than invalid. Recommended, and left to the user.
5. 🔴 **Durable rollup refresh** (dirty flag + retry, or compute-on-read) is
   **out of scope**: no finalized record depends on it, and doing it properly is
   a background-jobs phase. Recorded, not silently expanded.

---

## 10. What shipped (H1.4.1)

**No migration.** Nothing about the schema was wrong: `cost` is already
`NOT NULL`, the CHECK constraints already hold, and `price` has been nullable
since `0034`. The defect was entirely in how three code paths wrote to it, so
creating a migration would have been ceremony.

### One rule, three inflows

`inventory/stock-cost.ts` is now the only way quantity stock enters a branch —
purchase receiving, quick "Add Stock" and transfer receipt all call it.

```sql
INSERT INTO stock_items (…) VALUES (…) AS incoming
ON DUPLICATE KEY UPDATE
  cost     = (stock_items.quantity * stock_items.cost
              + incoming.quantity * incoming.cost)
             / (stock_items.quantity + incoming.quantity),
  quantity = stock_items.quantity + incoming.quantity,
  updated_at = NOW(6)
```

| Rule | How it is met |
|---|---|
| Physical quantity, not available | `stock_items.quantity` is the physical column; `reserved_quantity` is never read or written here |
| Reservations unchanged | absent from the `UPDATE` clause entirely |
| No row → incoming cost becomes the average | the `INSERT` branch of the same statement |
| Zero physical → incoming cost | falls out of the formula: `(0 × cost + r × u) / r = u`, so there is no special case to drift |
| Database precision preserved | the division happens in SQL, stored at the column's `DECIMAL(14,2)`; nothing is rounded in JavaScript first |
| Purchase and payable keep the ACTUAL cost | `purchase_items.unit_cost` and the supplier balance are untouched by averaging |
| No historical rewrite | no past purchase, sale or stored margin is read or modified |
| Never a product default, never zero | the incoming cost is passed through; a missing price yields `NULL`, not `0` |

**Assignment order is load-bearing.** `cost` is assigned before `quantity`
because MySQL evaluates `ON DUPLICATE KEY UPDATE` left to right and a later
assignment sees the earlier one's new value. Averaging after the increment would
under-weight the incoming goods. A test pins the order.

### Precision, stated honestly

`stock_items.cost` is `DECIMAL(14,2)`, the money precision of the entire schema.
The Anker case averages to `8.6667` and is stored as `8.67`. That rounding is at
the column, not in application code, and widening it would make cost precision
inconsistent with every other money column — a schema and accounting decision,
not a hardening one. Recorded, not silently changed.

### Three defects found by running it

Each was invisible to the unit suite by construction.

1. **Making the average atomic introduced a deadlock, and lost a purchase.**
   `INSERT … ON DUPLICATE KEY UPDATE` takes insert-intention gap locks the old
   read-then-write did not, so two simultaneous purchases of the same product
   deadlocked and MySQL rolled one back entirely — 150 units where 200 were
   bought. Fixed by deterministic lock ordering plus a discriminating retry
   (`common/db/deadlock-retry.ts`): lock conflicts are re-run, unique violations
   and domain conflicts are rethrown untouched.
2. **A simultaneous identical replay returned a misleading 409** telling the
   caller "a duplicate identifier was detected" for a delivery that had actually
   succeeded. It now resolves to the winning purchase, as transfers have since
   H1.1.
3. **`GET /inventory` exposed every branch's stock and average cost.** The route
   has no `@RequirePermissions`, so `PermissionsGuard` exits early and never
   checks branch assignment — while the active branch comes from the
   `X-Branch-Id` header. Changing one header returned another branch's costs.
   This is the G2A-CP3 defect recurring on a route nobody re-examined; the
   assignment check is now a shared helper used by inventory and pricing alike.

### Valuation

`/analytics/inventory-value` computes held value **live from source**, so
`totalStockValue` = held + in-transit holds at the instant the request is
served instead of eventually. `heldValueRows` is the single query used by both
the live report and the rollup rebuild, so the reported and stored figures
cannot drift apart.

Dead-stock listings and the health score deliberately keep reading the rollup:
they rank and score per product, where being a moment behind changes an ordering
rather than a reported total.

**Not attempted, and recorded rather than silently expanded into:** making the
rollup refresh durable (dirty flag, retry, reconciliation). Nothing finalized
depends on it — closing awaits its own recompute and reads `sale_items` — so
that is a background-jobs phase.

### 🔴 Still open for the user to decide

**The two drifted rows are unchanged**, exactly as §9 said they would be:

| Product | Stored | Reconstructs to |
|---|---|---|
| Apple USB-C Cable (52) | **4.10** | 4.25 |
| Anker PowerCore (15) | **8.50** | 8.6667 |

From now on they will re-average correctly on the next receipt, but the existing
drift does not heal itself. Correcting it is deterministic (§6b) and remains
**recommended but unapproved** — the values are stale, not provably invalid.

### Verified

Backend **56 suites / 778 tests**, TypeScript clean, `prisma validate` valid,
**33 migrations** with none added, 4 triggers intact.

**Live: 42/42** against the running API and real MySQL — the weighted average
across dearer, cheaper and equal receipts; physical-vs-available weighting
distinguished; reservations untouched; zero-quantity; unpriced staying unpriced;
payable and purchase lines keeping the actual cost; serialized units keeping
their own cost; idempotent replay and changed-payload 409; multi-line
atomicity; immediate valuation after purchase; the held/in-transit invariant
across shipment and receipt; cost visibility following the permission; and
cross-branch reads refused.

**Races, genuinely simultaneous:** purchase vs purchase into an existing row
(exact combined average), two purchases into an absent row (exactly one row,
both quantities), purchase vs transfer receipt into one destination, purchase vs
selling the last available quantity, and a simultaneous replay applying once
with both callers told about the same purchase.

Mobile needed no change: Receive already asks for "What it cost you — per unit,
before any selling price", which is the incoming cost, and no API type moved.
Showing the resulting average in the success state was considered and **not**
added — the response does not carry it, and adding an API field for decoration
is not what this phase is for.
