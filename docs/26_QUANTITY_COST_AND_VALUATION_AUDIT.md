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

Events that trigger it: `sale.recorded` and `stock.moved` (transfers).
**Purchase receiving emits neither**, so a purchase does not refresh valuation
at all until an unrelated sale or transfer happens to touch that branch.

### The consequence, stated precisely

| Read | Source | Stale window |
|---|---|---|
| Inventory value, Dashboard, Health | `InventoryValuation` rollup | from commit until the queued refresh lands — **and indefinitely after a purchase**, which never enqueues one |
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
| Purchase: company value += received × incoming cost | ❌ **twice wrong** — cost is stale, *and* no refresh is enqueued |
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
2. **Make a purchase refresh valuation**, as sales and transfers already do.
   *(Proceeding — a one-line omission, not a redesign.)*
3. **Stop coercing a missing price to `0`** on quick Add Stock; leave the row
   unpriced. *(Proceeding — `0` means "free", which is never what was meant.)*
4. 🔴 **Historical backfill of the two drifted rows — NOT proceeding without
   approval.** The correction is deterministic (§6b) but the stored values are
   stale rather than invalid. Recommended, and left to the user.
5. 🔴 **Durable rollup refresh** (dirty flag + retry, or compute-on-read) is
   **out of scope**: no finalized record depends on it, and doing it properly is
   a background-jobs phase. Recorded, not silently expanded.
