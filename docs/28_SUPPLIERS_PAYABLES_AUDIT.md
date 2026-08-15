# 28 — Suppliers and Payables: audit and decisions

> **Phase J0, read-only.** Nothing in this document changed behaviour. It records
> what the code and the live database actually do, so J1 builds on measured
> facts rather than on what the model names imply.

---

## 1. What already exists

### 1.1 Schema

| Model | Relevant columns | Notes |
|---|---|---|
| `Supplier` | `name`, `phone`, `notes`, **`balance` `DECIMAL(14,2)`**, `deletedAt` | `@@unique(companyId, name)`. **Company-scoped — no `branchId`.** |
| `Purchase` | `total`, `subtotal`, `taxTotal`, **`amountPaid`**, **`status`**, `dueDate`, `referenceNo`, `clientUuid` + `clientRequestHash` | Branch-scoped. `supplierId` is **required**. |
| `PurchaseItem` | `productId`, `quantity`, `unitCost`, `taxAmount` | |
| **`SupplierPayment`** | `supplierId`, `purchaseId?`, `amount`, `method`, `paidAt`, `createdById` | **The table already exists.** |
| `PurchaseStatus` | `unpaid` · `partial` · `paid` | |

**`SupplierPayment` already exists and is almost unused.** It has no lifecycle
(no reported/confirmed states), no version, no `clientUuid`, no account
reference, no account-label snapshot, no confirmer and no branch. One code path
writes it: the down-payment taken at receiving, hardcoded `method: 'cash'`.

### 1.2 The only place a payable is created

`PurchasingService.commit()`, inside the purchase transaction:

```ts
const payable = Number((total - amountPaid).toFixed(2));
if (payable !== 0) {
  await tx.supplier.update({ where: { id: supplier.id }, data: { balance: { increment: payable } } });
}
if (amountPaid > 0) {
  await tx.supplierPayment.create({ /* … method: 'cash' */ });
}
```

`Purchase.status` is computed **once**, at creation, and never updated again.

### 1.3 API surface

| Route | Guard | Reality |
|---|---|---|
| `GET /v1/suppliers` | **none** | Any signed-in user. Returns the whole row, **including `balance`**. `take: 200`, no pagination, no search, no filter. |
| `POST /v1/suppliers` | `supplier.manage` | Name, phone, notes. No duplicate handling beyond the unique key. |
| `POST /v1/purchases` | `purchase.manage` + `unit.add` | Idempotent by `clientUuid`. |

**There is no supplier detail, no edit, no deactivate, no reactivate, no payment
endpoint of any kind.** A supplier paid after the goods arrive cannot be
recorded at all today.

### 1.4 Permissions, as the migration actually grants them

| Role | `supplier.manage` | `purchase.manage` | `cost.view` |
|---|---|---|---|
| Owner | ✅ | ✅ | ✅ |
| Store Manager | ✅ | ✅ | ✅ |
| Store Employee | ❌ | ✅ | ✅ |

An Employee can therefore receive stock — which creates a payable — but cannot
manage the supplier it is owed to. That split is sensible and is kept.

### 1.5 Mobile

There is **no supplier screen at all**. The only supplier surface is the picker
inside `app/receive.tsx`, which calls `GET /suppliers` and can create one inline
by name. `qk.suppliers` exists; `supplier.manage` exists in the permission list;
`lib/design/status.ts` already defines `purchaseStatus` tones and label keys for
`paid` / `partial` / `unpaid`, which nothing renders yet.

Reusable from I3: `RefundPayoutSheet` (method + account + reference + note),
`RefundSections` (owed / claimed / confirmed wording) and `RefundReconciliation`
are the right shape to imitate, though not to share directly — see §3.8.

### 1.6 Live data, measured

| Supplier | Stored `balance` | Purchases | `SUM(total)` | `SUM(amountPaid)` | Payments |
|---|---|---|---|---|---|
| TechDist 844113836 | 3 890 | 4 | 3 890 | 0 | 0 |
| RU Dist 261557253 | 2 350 | 2 | 2 350 | 0 | 0 |
| V Dist 2033266574 | 4 945 | 3 | 4 945 | 0 | 0 |

9 purchases, **all `unpaid`**, 0 supplier payments, total payable **11 185**.
Every stored balance equals `SUM(total − amountPaid)` exactly. **No legacy drift
to reconcile.**

---

## 2. The twelve questions, answered

**1. Does a Purchase already create an authoritative supplier payable?**
Partly. It increments a **stored** `Supplier.balance` and records
`Purchase.total` / `amountPaid` / `status`. But the balance is an aggregate
nobody recomputes, and the per-purchase status is frozen at creation, so the
figures are authoritative only until something happens to them — and today
nothing can.

**2. Is the payable branch-scoped or company-wide?**
**Company-wide.** `Supplier` has no `branchId`; `Purchase` does. So a debt is
owed by the company while the goods landed in one branch. Both facts matter, and
J1 reports them separately rather than picking one.

**3. Can one Purchase have multiple partial payments?**
Structurally yes — `SupplierPayment.purchaseId` is a plain nullable FK with no
uniqueness. Functionally no: nothing writes a payment after creation, and
nothing recomputes `amountPaid` or `status`.

**4. Can current data distinguish unpaid, partly paid and fully paid?**
The enum can express all three; the data only ever says `unpaid` unless money
was handed over at the counter during receiving. It is **not maintained**.

**5. Does receiving stock without a Supplier create a liability?**
`Purchase.supplierId` is required, so a *purchase* always has one.
**But purchases are not the only intake path** — `InventoryService.upsertStock`
and quick-add create stock, and therefore inventory cost, with no purchase and
no payable. Recorded in §4 as a real gap, out of scope here.

**6. Can a Supplier be deactivated without hiding historical purchases?**
The column exists (`deletedAt`, filtered by `list()`), and `Purchase.supplierId`
is a hard FK so history cannot be orphaned. **But no endpoint sets or clears
it**, so deactivation is not a workflow that exists.

**7. Would reusing Sale `Payment` corrupt incoming cash?**
**Yes, and it must not be done.** `Payment.sale_id` is required and every
consumer counts it as cash *received*. A supplier payment there would appear as
sales income — the identical trap I3 documented for refunds (`docs/27` §17).

**8. Can the I3 refund-payout model be generalized, or does supplier settlement
need its own model?**
**Its own model, with I3's discipline copied deliberately.** The *shape* —
report → confirm, optimistic version, client UUID + fingerprint, account label
snapshotted and frozen, locked-day 409, no profit effect — generalises perfectly
and should be reused as a pattern. The *table* must not be: a refund payout is
**one per return with a locked amount and no allocation**, while a supplier
payment is **many per supplier, partial, and allocated across several
purchases**. Forcing one table to be both would make the amount rule and the
allocation rule conditional on a type column, which is how invariants stop being
enforceable.

**9. How should confirmed supplier payments affect reconciliation?**
Exactly like confirmed refunds: on the **confirmation day**, a cash payment
reduces expected cash once; an account payment lands against that account.
`DailyClosing` already carries `refundsPaidCash` / `refundsPaidTotal` and has
**no supplier equivalent** — new columns are needed.

**10. Does paying a supplier affect profit?**
**It must not, and today it cannot** — profit comes from sale digest lines, and
inventory cost reaches profit through COGS when the goods sell. Paying a
supplier moves a liability to cash. J1 keeps it that way and proves it.

**11. Are supplier balances recalculated or stored?**
**Stored**, incremented in one place, never recomputed. Any future write path
that forgets the increment drifts silently and nothing notices.

**12. Are there legacy records needing reconciliation?**
**No.** Every stored balance matches the derived figure exactly, all 9 purchases
are `unpaid`, and there are no payments. Whatever J1 does, it starts from a
consistent state — *and that state must be re-audited before deploying anywhere
with real purchase history.*

---

## 3. Decisions for J1

Nothing in the audit contradicts the approved conservative rules, so J1
proceeds. These are the choices the audit forces.

### 3.1 Liability is DERIVED, and the stored balance becomes a cache

Outstanding = `SUM(purchase.total) − SUM(confirmed payment allocations)`, per
supplier, computed from immutable rows. This is the I3 lesson applied: a debt
that lives in a mutable counter is a debt that can silently disappear.

`Supplier.balance` is **kept and maintained** for compatibility, but no screen
and no decision reads it as truth. A drift test compares it against the derived
figure.

### 3.2 Purchase totals are never rewritten

`Purchase.total` is what was agreed with the supplier. Payment is expressed by
**allocation rows**, not by editing history. `Purchase.amountPaid` and `status`
are maintained as a projection of those allocations, never as the source.

### 3.3 Payment carries an explicit allocation

A payment names which purchases it settles and by how much. **Money is never
silently spread**: when the app offers oldest-first as a convenience, the
resulting allocation is shown before submitting and returned in the response.

### 3.4 Report and confirm, exactly as I3

`supplier.payment.report` — Owner, Manager, **Employee**.
`supplier.payment.confirm` — Owner, Manager.
A report moves no money and changes no liability. Confirmation settles it once,
on the confirmation day, with no profit effect.

### 3.5 Overpayment is refused, including under concurrency

The allocation total may not exceed what is outstanding at confirmation time,
checked against the committed rows inside the transaction — not against what the
screen was showing.

### 3.6 Deactivation, not deletion

`deletedAt` gets its endpoints. An inactive supplier disappears from the Receive
picker and from new payments, and stays visible everywhere history is shown. No
supplier is ever hard-deleted.

### 3.7 An Employee must stop seeing every supplier's debt

`GET /suppliers` is unguarded and returns `balance` to anyone signed in. That
contradicts the rule that the financial ledger is for Owner and Manager. J1
narrows the list response by permission: everyone who can receive stock still
gets the name and phone they need to pick one; **the money is gated**.

### 3.8 The I3 components are a pattern, not a dependency

`RefundPayoutSheet` is copied in spirit — method, active account, reference,
note, locked figures, high-friction confirmation — but supplier payment has an
amount the user chooses and an allocation it does not, so sharing the component
would mean a prop that turns off half of it.

---

## 4. Found on the way, out of scope, recorded

- **🔴 Stock can enter without a payable.** `upsertStock` and quick-add create
  inventory cost with no purchase and no supplier debt. Whether that should be
  possible is a product question; today it silently understates what the shop
  owes.
- **🟡 A payable equals a tax-inclusive total, inventory cost does not.**
  `Purchase.total` is `subtotal + taxTotal`, while `PurchaseItem.taxAmount` is
  written as `0` on every line and unit cost is tax-exclusive. The rule
  "liability equals authoritative inventory cost" therefore holds **only because
  tax is always zero today.** The moment tax is charged, the debt exceeds the
  inventory value and the two must be reconciled deliberately.
- **🟡 `Supplier.balance` has no drift detection.** J1 adds a test; a periodic
  check belongs in the later Analytics work.
- **🔴 No post-confirmation correction exists, by design.** A confirmed supplier
  payment cannot be reversed in this milestone. That is deliberate — an
  unreviewed reversal is how money leaves twice — but it means a genuine mistake
  currently has no route back. **Recorded as a required future controlled
  correction workflow**, alongside the same gap for I3 refunds.
