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


---

## 5. J1 as shipped — supplier operations and payables

### 5.1 Schema (`0039`)

| Table | Purpose |
|---|---|
| `supplier_settlements` | One payment, `reported` → `confirmed`. Amount, method, frozen account label, version, client uuid + fingerprint, reporter, confirmer, **confirmation date** |
| `supplier_settlement_allocations` | Which purchases it settles, and by how much. UNIQUE `(settlement, purchase)` |
| `daily_closings` | + `supplier_paid_total`, `supplier_paid_cash`, both defaulted to 0 |

**Its own model, not a generalised `RefundPayout`.** A refund is one per return
with a locked amount and no allocation; a supplier payment is many, partial and
split across purchases. One table for both would make the amount rule
conditional on a type column.

Database rules, not application hopes: a payment is positive · a cash payment
must not name an account and an account payment must · a confirmed row carries
who, when and which business day or none of them · one request id per company ·
one allocation per purchase per settlement.

### 5.2 Permissions

| Role | `supplier.manage` | `supplier.payment.report` | `supplier.payment.confirm` |
|---|---|---|---|
| Owner | ✅ | ✅ | ✅ |
| Store Manager | ✅ | ✅ | ✅ |
| Store Employee | ❌ | ✅ | ❌ |

An Employee hands the money over and reports it; only a Manager or Owner
vouches for it. Proved live: an Employee confirming gets **403**.

### 5.3 Liability, and the three timings

**Outstanding is derived**, every time, from purchase totals minus confirmed
allocations. `Supplier.balance` is kept in step as a cache and a drift check
compares them — nothing decides from it.

- **Purchase** creates the payable.
- **Report** is a workflow event: no cash, no change to what is owed.
- **Confirmation** settles the liability exactly once, books the cash movement
  on the confirmation day, and has **no profit effect at all** — inventory cost
  reaches profit through COGS when the goods sell.

Purchase totals are **never rewritten**. `amountPaid` and `status` are
recomputed as a projection of the allocations.

### 5.4 Allocation, and overpayment

Always explicit. Oldest-first is offered as a **suggestion**, returned to the
caller and shown before anything is sent — money that lands somewhere nobody
looked at is money nobody can explain later.

Overpayment is refused three ways: per line against what that purchase owes, in
total against the amount handed over, and again **inside the confirmation
transaction against committed rows**. The last one is what stops two managers
confirming at once from overpaying the same debt.

### 5.5 Reconciliation

Expected cash = cash taken − confirmed cash refunds − **confirmed cash supplier
payments**. Before J1 the last term did not exist, so a day the shop paid a
supplier in cash reported a shortage that was not a shortage. Only the cash part
is subtracted; an account transfer never touched the drawer. Neither figure
appears in gross profit, expenses or net profit.

### 5.6 Deactivation

`deletedAt` got its endpoints. An inactive supplier disappears from the Receive
picker and from new payments, and stays everywhere history is shown. **No
supplier is ever hard-deleted** — proved live: MySQL refuses to delete one a
settlement or a purchase names.

### 5.7 Mobile

`/suppliers` (searchable, filterable, paged) · `/suppliers/[id]` (ledger,
pending payments, payment history, deactivate/reactivate) · `/suppliers/new`.

The money is **absent, not zero**, for anyone without permission, and the detail
says so in words rather than rendering a misleading 0.

### 5.8 Verification — 52 live checks, 0 failures

Against a **separate backend on port 3112** and real MySQL, reusing the three
spent probes. Duplicate supplier 409 · Employee refused supplier creation ·
search by name and phone · money gating for list and detail · payable derived
per purchase · oldest-first suggestion · Employee reports · report changes
nothing owed · replay · changed-payload 409 · Employee confirmation 403 ·
Manager correction with a frozen label and an unchanged amount · stale
correction 409 · rename/deactivate neither rewrites nor strands · confirmation
settles once · partial leaves the exact balance · purchase total never rewritten
· duplicate confirmation refused · overpayment refused · allocation mismatch
refused · exact final payment clears it · two partials sum to the total · paying
a settled purchase refused · no profit effect and no supplier column in the
profit rollup · deactivate/reactivate with history intact · inactive supplier
takes no payment · unknown 404 · malformed id 404 · cross-branch refused ·
paging repeats no row · **the cached balance still agrees with the derived
figure**.

### 5.9 One real defect found by running it

`GET /suppliers/not-a-uuid` returned **500**. `uuidToBin` throws a plain Error
and the global filter maps it to a server error; the returns module already
guards with `isUuid` for this exact reason and suppliers did not. An id that
cannot name anything is a 404 — a 500 says the server broke and sends somebody
looking for a fault that is not there.

Two other things the plan did not anticipate, both recorded in the J1-A commit:
MySQL error 3823 forced the receiving-account foreign key to `RESTRICT` on both
actions, and the `permissions` table has a `label` column rather than
`description`.

**One breaking change TypeScript could not catch.** The supplier list became
paged, and `app/receive.tsx` still typed it as a bare array — `api.get<T>` is an
assertion, not a check, so the build stayed green while the Receive picker would
have shown nothing. Found by reading the call site rather than by a tool.

### 5.10 Still not done, and not claimed

- **Nothing was exercised on a device or in a visible browser.** `docs/24` §9g
  lists what a device pass must cover.
- **No post-confirmation correction exists** for a supplier payment, exactly as
  for an I3 refund. Deliberate — an unreviewed reversal is how money leaves
  twice — but a genuine mistake has no route back today. **This is now the most
  significant open gap in the financial workflows.**
- **Stock can still enter without a payable** through `upsertStock` and
  quick-add (§4).
- **A payable is tax-inclusive while inventory cost is not**, which only agrees
  today because tax is always zero.
- Supplier liability is **company-wide**; the ledger shows each purchase's
  branch, but there is no per-branch payable total.
