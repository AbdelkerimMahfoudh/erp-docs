# 46 — Mistake prevention: approval packet, and what was built

> **Status: A0–A3 approved by the owner on 2026-09-10**, with a binding
> correction to A2 — *the configured selling price is the floor, not cost*.
> **CP1–CP6 are implemented and live-verified with zero failures.** Backend
> `d3ab914`, `e2cb6b1`, `483cab9`, `6287b61`, `fe81f5d`, `9aa98d2`, `c42c61f`,
> `4d0736d`, `0da5a72`, `6ff7f16`; mobile `68f02dd`, `20619e4`.
> CP6 first ran 91/92: the retired `branch_manager` role still held
> `discount.override` in the database. Migration `0067` removed it with the
> owner's authorisation, and the rerun on the repaired database is 92/92, with
> the repair itself proved 3/3 before the migration and 14/14 after.
> **Not closed:** physical-device acceptance has not started, and A1's
> remaining four detectors are not wired (below).
> Where §3 below describes cost as the floor, §A2 is superseded by the
> correction recorded in [`docs/21`](21_PRODUCT_DECISIONS.md).
>
> **Two deviations from the packet, both deliberate and both recorded:**
>
> 1. **A1's remaining four detectors are not wired.** The engine, the rules and
>    the ten translations exist and are tested; `magnitude.sale_price` is live
>    on `sale.create`. Intake cost, price change, expense amount and debt
>    payment each need their own mutation wired to the gate, and that is the
>    precise remaining task — not a redesign.
> 2. **Rule 3 reads sale receivables, not a loan ledger.** §3/A3 says "loan
>    ledger", and this codebase's existing definition of an overdue debt is the
>    health score's: a sale with a balance still owed and a due date in the
>    past. Loans carry no due date at all. Writing a second definition of
>    "overdue" is exactly what A3 forbids, so the existing one was used.

This began as the four-step approval the rulebook requires before a change that
touches the sacred rules. It is kept as written — including §1, whose evidence
was true when it was gathered — so the reasoning that led to the decision
survives alongside the decision:

> **BEFORE EVERY MAJOR IMPLEMENTATION** — Do all four, in order, and stop:
> 1. Explain the plan. 2. Explain the files that will change. 3. Explain
> possible risks. 4. **Wait for approval before large changes.**
>
> "Major" = new feature, schema change, new dependency, architectural change, or
> anything touching the sacred rules.

All three features touch **margin/cost** and **permissions**, which the rulebook
names as sacred. So this stops at step 4.

The owner's answer can be as short as *"approve A1, A2, A3"* or a targeted
correction to any numbered decision.

---

## 1. Evidence: what exists today

Audited in the code, not in the roadmap.

### 1.1 The pricing floor is COST, and it is a permission, not an approval

`SalesPolicyService.assertBelowCostAllowed` is the whole rule:

```ts
if (margin < -EPSILON) {
  if (!hasOverride) throw new ForbiddenException('Selling below cost requires the discount.override permission');
  if (!reason?.trim()) throw new BadRequestException('An override reason is required to sell below cost');
}
```

So today:

- **The floor is unit cost.** There is no configured minimum price, no percentage
  discount cap, and no per-product or per-category floor anywhere.
- **The check is synchronous and binary.** A seller either holds
  `discount.override` or the sale is refused. There is **no request, no
  approver, no waiting state, no approval record** — the concept does not exist.
- A reason string is required and stored, which is the audit trail today.
- `role-permissions.ts` is explicit that `store_employee` keeps `discount.apply`
  precisely *because* it "cannot bypass the cost floor" — the two permissions
  are deliberately separate.

**`discount.apply` and `discount.override` both already exist in the catalogue
(61 keys).** No new permission is needed for a limit; only for an *approval*.

### 1.2 There is no order-of-magnitude check anywhere

`SalesPolicyService.resolvePrice` takes whatever it is given:

```ts
resolvePrice(provided, defaultPrice) {
  if (provided !== undefined) return provided;   // no bound, no comparison
  ...
}
```

Nothing in intake, pricing, expenses, payments, loans, consignments or
reconciliation compares a typed amount against any reference.

### 1.3 Numeric bounds are inconsistent — a real, separate defect

`pricing/dto/pricing.dto.ts` defines bounds correctly:

```ts
const MONEY = { min: 0, max: 999_999_999_999.99 };  // DECIMAL(14,2)
```

…but it is **local to that one file**. Elsewhere:

| Field | `@Min` | `@Max` |
|---|---|---|
| `SetPriceDto.price` | ✅ 0 | ✅ `MONEY.max` |
| `SaleLineDto.price` | ✅ 0 | ❌ **none** |
| `SaleLineDto.discount` | ✅ 0 | ❌ **none** |
| `PaymentInputDto.amount` | ✅ 0.01 | ❌ **none** |
| `CreateExpenseDto.amount` | ✅ 0 | ❌ **none** |

A sale line priced `1e15` passes validation and fails at MySQL, or truncates.
This is the same family as an extra-zero typo but is **not** the same fix: a
bound is a hard validation failure, a typo check is a warning. Both are needed,
and they are separate decisions below (**A0** and **A1**).

### 1.4 What already exists and must be reused, not duplicated

| Concern | Where it lives | Notes |
|---|---|---|
| Idempotency | `client_uuid` + `client_request_hash`, `idempotency_conflict` on payload mismatch | Already on expenses, corrections, consignments, discrepancies, closing |
| Stale-version protection | `version Int @default(0)` on prices, loans, consignments, transfers and others | `SetPriceDto` already requires the version being replaced |
| Cost/margin gating | `CostGatingInterceptor` + `FINANCIAL_FIELDS` | One list; `report-catalogue.ts` already defers to it |
| Audit | `AuditService.record` / `recordTx` | Append-only, commits in the same transaction as the change |
| Notifications | `NotificationsService.emit` / `listForUser` / `markRead` | In-app channel exists |
| Money parsing | `mobile/lib/price-input.ts` — `parsePrice`, `canSave` | Two decimals enforced client-side |
| Confirm dialogs | `mobile/lib/dialog.ts` — its own doc comment example is *"Sell below cost?"* | The pattern exists |
| Offline classification | `mobile/lib/offline/policy.ts` — `local_draft` / `queueable` / `online_only` | **Anything that DECIDES something is `online_only`** |
| Velocity / history | `ProductVelocity`, `ProductDailyRollup`, `InventoryValuation` | The reference data a typo check needs |

### 1.5 Duplicated, contradictory, client-only or bypassable rules found

| Finding | Severity |
|---|---|
| **`MONEY` bounds are defined in one DTO and not shared.** Four money fields have no upper bound at all (§1.3) | 🟠 real gap |
| **`parsePrice` is client-only.** Two-decimal enforcement on the phone is duplicated by `@IsNumber({maxDecimalPlaces: 2})` server-side — consistent today, but two definitions | 🟡 note |
| **`EPSILON = 0.005` is local to `SalesPolicyService`;** `round2` lives in `suppliers/payable.ts`. Money rounding has two homes | 🟡 note |
| No contradictory rule found between client and server on the cost floor — the client shows a dialog, the server refuses. Correct shape | ✅ |

---

## 2. Proven gaps

1. **No reference-based sanity check** on any typed amount. A missing or extra
   zero is accepted silently everywhere.
2. **No upper bound** on sale price, discount, payment or expense amounts.
3. **No approval workflow.** Below-cost selling is a permission held or not
   held; there is no way for an employee to *ask*, and no record of a decision
   distinct from the sale itself.
4. **No anomaly surface.** The health score exists; nothing flags a pattern.

---

## 3. Recommended contracts

### A0 — Bound the money fields (recommend approving separately, and first)

Not a new feature: it closes §1.3. Move `MONEY` to a shared constant and apply
`@Max(MONEY.max)` to `SaleLineDto.price`, `SaleLineDto.discount`,
`PaymentInputDto.amount`, `CreateExpenseDto.amount` and any other money field
that lacks one.

**This is a hard validation failure (400), not a warning.** No schema change, no
permission change, no UI change beyond the existing error path.

> **A0 — approve?** *"Bound every money field to DECIMAL(14,2) and share one
> MONEY constant."*

---

### A1 — Order-of-magnitude typo prevention

**Principle.** Detect a plausible missing or extra zero against a
**server-trusted reference**, warn before committing, **never alter a value**,
**never reject a legitimate value**, and produce **no warning when there is no
meaningful reference**.

#### Fields, references and rules

There is **no universal threshold**, because the fields do not share a
reference. Each row is a separate decision.

| # | Field | Reference (server-trusted) | Rule | If no reference |
|---|---|---|---|---|
| 1 | Sale line `price` | The product's **current branch price** (`price-resolution`) | warn if `≥ 10×` or `≤ 1/10` | silent |
| 2 | Sale line `price` | else the product's **median sale price, 90 days, this branch** (`ProductDailyRollup`) | same, **min 5 sales** | silent |
| 3 | Intake `cost` | The product's **weighted-average cost** (`InventoryValuation`) | warn if `≥ 10×` or `≤ 1/10` | silent — a first receipt has no history |
| 4 | `SetPriceDto.price` | The **price being replaced** (already sent as `version`) | warn if `≥ 10×` or `≤ 1/10` | silent when creating the first price |
| 5 | Expense `amount` | **Median of the same expense category, 180 days, this company** | warn if `≥ 10×`, **min 3 expenses** | silent |
| 6 | Payment `amount` | The **sale total** it is paying | warn if `> total` — *already a hard error*, so **no change** | n/a |
| 7 | Loan / consignment payment | The **outstanding balance** | warn if `≥ 10×` balance | silent if balance is 0 |
| 8 | Declared cash at closing | **Expected cash** for the day | **already a discrepancy workflow — no change** | n/a |

**Why 10×.** A missing or extra zero is exactly a factor of ten. A 3× threshold
would fire on ordinary variation and train people to dismiss it; that is how a
warning becomes noise and stops working.

#### Treatment of the awkward values

- **Zero** — never a magnitude warning. Zero is a legitimate price (a giveaway,
  a warranty replacement) and is already governed by the below-cost rule.
- **Negative** — not accepted by any of these fields (`@Min(0)`); A0 keeps that.
- **New product / no history** — **silent.** A first receipt has nothing to
  compare against, and inventing a category-wide reference would fire on every
  genuinely new item.
- **Missing reference below the minimum sample** — silent. Two sales is not a
  median.

#### Behaviour

- **Advisory only.** Server returns the warning with the computed reference; the
  client shows it. **The server never blocks on a magnitude warning alone.**
- **Deliberate confirmation** for the high-risk mutations — sale line price,
  intake cost, price change, expense — via the existing `dialog.confirm`,
  showing the reference: *"You typed 170 000. Similar sales are around 17 000."*
- **Never auto-corrects.** No "did you mean" that fills the field.
- **MRU arithmetic is untouched.** The check compares; it does not compute a
  stored value. All comparison is on the same `DECIMAL(14,2)` numbers.
- **Retries and offline replay.** The warning is computed on the request that
  carries the value. A replayed request with the same `client_uuid` is
  idempotent and returns the original outcome — **it does not re-warn**, because
  the user already answered.

#### Roles, audit, notification

- **Any role that may perform the action may proceed** after confirming. A typo
  check is not a permission boundary and must not become one.
- **Audit:** when a user confirms past a warning, the audit row for the action
  carries `magnitudeWarningAccepted: { field, value, reference }`. A dismissed
  warning on an abandoned form records nothing.
- **No notification.** A confirmed typo warning is not news for the Owner. It is
  visible in the audit trail if anyone looks.

#### Wording (EN / FR / AR)

| Key | EN | FR | AR |
|---|---|---|---|
| `check.magnitude.high` | This looks about {factor}× higher than usual. | Ce montant semble environ {factor}× plus élevé que d'habitude. | يبدو هذا أعلى بنحو {factor}× من المعتاد. |
| `check.magnitude.low` | This looks about {factor}× lower than usual. | Ce montant semble environ {factor}× plus bas que d'habitude. | يبدو هذا أقل بنحو {factor}× من المعتاد. |
| `check.magnitude.reference` | Similar {noun} are around {amount} MRU. | Les {noun} similaires sont d'environ {amount} MRU. | القيم المشابهة حوالي {amount} أوقية. |
| `check.magnitude.confirm` | Yes, that is right | Oui, c'est correct | نعم، هذا صحيح |
| `check.magnitude.edit` | Let me check | Je vérifie | دعني أتحقق |

Announced by screen readers as an alert; the confirm dialog already traps focus.

> **A1 — approve?** *"Approve order-of-magnitude warnings for fields 1–5 and 7,
> at 10×, advisory only, never auto-correcting, silent without a reference."*
> Corrections welcome on any row, the 10× factor, or the minimum samples.

---

### A2 — Discount-limit approval

**Preserves the existing model.** The floor stays **unit cost**; `discount.apply`
and `discount.override` keep their current meanings. This adds the *request*
that does not exist today.

#### The gap

An employee who needs to sell below cost is refused with a 403 and no way
forward except finding someone with `discount.override` to make the sale
themselves. That is why below-cost sales concentrate on whoever holds the
permission, which is the opposite of an audit trail.

#### The contract

| Aspect | Decision |
|---|---|
| **Who may request** | Any role with `sale.create` |
| **Who may approve** | `discount.override` — Owner and Manager today. **No new permission** |
| **Scope of an approval** | **Exactly one unit** (or one product+quantity for quantity stock), one branch, one amount, MRU. **Never reusable** |
| **Expiry** | **30 minutes**, and **single use** |
| **Stale price** | The approval records the price it was granted for. If the sale is submitted at a different price, the approval is **void** — `approval_price_changed` |
| **Concurrent sale** | The unit is not reserved. If it sells first, the approval is void — `unit_no_longer_sellable` |
| **Offline** | **`online_only`.** An approval is a *decision*, and `mobile/lib/offline/policy.ts` already classifies decisions that way. A queued approval request would be answered into a world that has moved |
| **Idempotent replay** | Request and grant both carry `client_uuid`; replay returns the original decision, never a second approval |
| **Cancellation / rejection** | Requester may cancel while pending; approver may reject with a reason. Both are terminal and audited |
| **Receipt** | Shows the **final price only**. Not the approval, not the approver, and **never the cost or the margin** |
| **Cost/margin gating** | Unchanged — `CostGatingInterceptor` strips them for anyone without `cost.view`. **The approver needs `cost.view` to judge, and already has it** |

**An approval is not a permission.** It authorises one sale of one unit at one
price and then it is spent. This is the single most important line in A2.

#### Events

| Event | Audit | Notification |
|---|---|---|
| requested | ✅ | → approvers, **deduplicated per request** |
| approved | ✅ | → requester |
| rejected | ✅ (with reason) | → requester |
| cancelled | ✅ | none |
| expired | ✅ (lazily, on read) | none |
| consumed by a sale | ✅ on the sale row | none |

#### Schema

**One new table** — `discount_approvals`: id, companyId, branchId, requesterId,
approverId, unitId/productId, requestedPrice, unitCost snapshot, status, reason,
`client_uuid`, `client_request_hash`, version, timestamps. Additive; no existing
column changes.

> **A2 — approve?** *"Approve a single-use, 30-minute, one-unit discount
> approval, requested by `sale.create`, granted by `discount.override`, voided by
> a price change, online-only, never shown on the receipt."*

---

### A3 — Anomaly detection

**Deterministic rules only.** No machine learning, no external service, no
opaque score. Every warning must be explainable in one sentence with the numbers
that produced it.

#### The anomalies, taken from the roadmap and product decisions

| # | Anomaly | Source | Window | Min sample | Who sees it |
|---|---|---|---|---|---|
| 1 | **Low stock with days-left** | `ProductVelocity`, `InventoryValuation` | 30 d | 5 sales | `report.view` |
| 2 | **Dead stock** | already computed by `DashboardService.deadStock` | `dead_stock_days` setting | n/a | `report.view` |
| 3 | **Overdue debt** | loan ledger | as-of | n/a | `loan.view` |
| 4 | **Seller margin collapse** | `sales.margin` per seller | 30 d vs prior 30 d | **20 sales each** | **Owner only** |
| 5 | **Repeated cash shortfall** | `closing` discrepancies | 30 d | **3 closings** | Owner + `closing.perform` |
| 6 | **Below-cost cluster** | below-cost overrides per seller | 30 d | **3 overrides** | **Owner only** |

**Nothing here computes a new metric.** Every input is an existing rollup or
ledger. Anomaly detection must never become a second definition of revenue,
profit, cost, liability, expected cash or inventory status — so it reads the
same services the screens read, exactly as the report export does.

#### Behaviour

- **Advisory, never blocking.** No anomaly refuses a sale, an intake or a
  closing.
- **Branch- and company-scoped** by the tenant client, like every other read.
- **Sensitive by construction:** #4 and #6 involve margin and cost, so they are
  gated on `cost.view` **and** restricted to the Owner. An employee must never
  see a colleague's margin.
- **False positives** are handled by the minimum samples and by
  **acknowledgement**: any recipient may dismiss an anomaly, which suppresses
  that anomaly for that company for **7 days**. Dismissal is audited.
- **Retention:** 90 days, then dropped. An anomaly is a prompt, not a record.
- **Offline / stale:** anomalies are read-only server output. Offline the app
  shows nothing rather than a cached warning — a stale anomaly about yesterday's
  cash is worse than none.
- **Notification** for #3, #5 and #6 only, deduplicated per anomaly key per day.
  #1, #2 and #4 appear on screen without a notification.

> **A3 — approve?** *"Approve six deterministic anomaly rules, advisory only,
> Owner-only for the two that involve margin, dismissible for 7 days, 90-day
> retention, no ML and no external service."*

---

## 4. Alternatives considered

| Decision | Alternative | Why not recommended |
|---|---|---|
| 10× magnitude factor | 3× or 5× | Fires on ordinary variation. A warning people dismiss by reflex is worse than none |
| Warn on magnitude | **Block** it | Would refuse legitimate values — a genuinely expensive phone, a one-off bulk expense. The rulebook says prevent mistakes, not prevent unusual truths |
| Approval per unit | Approval per **seller per day** | Becomes a standing permission to sell anything below cost. Exactly what A2 must not create |
| Approval expiry 30 min | 24 hours | Prices and stock move within a day; a stale approval is an approval for a different sale |
| Approval online-only | Queueable | A queued *request* is defensible; a queued *grant* is a decision made against a world that has moved. `policy.ts` already draws this line |
| Anomalies as rules | A statistical/ML score | Unexplainable to a shopkeeper, and this project's UX rules require plain language and a reason |
| Seller margin visible to managers | Owner only | A manager seeing a colleague's margin is a personnel problem the app should not create |

---

## 5. Proposed changes, by surface

### Database

| Change | Necessity |
|---|---|
| `discount_approvals` table (A2) | **Genuinely necessary** — there is nowhere to record a decision distinct from the sale |
| `anomaly_dismissals` table (A3) | Necessary for the 7-day suppression. Small: company, anomaly key, user, until |
| **A0 and A1: no schema change** | Bounds are validation; warnings are computed and returned, never stored |

Both tables are **additive**. No column is altered, no data is migrated, no enum
value is added. Per `docs/22`, a verified backup is still required before either
migration is applied.

### API

```
POST /discount-approvals            request one        sale.create
GET  /discount-approvals?status=    list pending       discount.override
POST /discount-approvals/:id/approve                   discount.override
POST /discount-approvals/:id/reject                    discount.override
POST /discount-approvals/:id/cancel                    requester only
GET  /anomalies                     advisory list      report.view (+ cost.view for 4, 6)
POST /anomalies/:key/dismiss        7-day suppression  report.view
```

Magnitude warnings (A1) add **no endpoint**. They ride on the existing responses
as a `warnings: [...]` array, and the client re-submits with
`acknowledgedWarnings: [...]` after the user confirms.

**Error and conflict codes:** `magnitude_warning` (advisory, 200 with the
payload), `approval_required`, `approval_expired`, `approval_price_changed`,
`unit_no_longer_sellable`, `approval_already_decided`, `idempotency_conflict`
(existing).

### Mobile

Reuse only: `dialog.confirm`, `parsePrice`, the existing indigo components, the
notification centre, and the offline classifier. **No new screen** for A1. A2
adds a pending-approvals list to More for approvers. A3 extends the existing
"Needs your attention" surface.

Cache invalidation: an approval decision invalidates the approvals query and the
sale draft; an anomaly dismissal invalidates the anomalies query. All EN/FR/AR
with RTL, parity asserted by the existing 1860-key check.

---

## 6. Security and accounting invariants

These must hold after implementation, and each gets a test:

1. **No new definition of a metric.** Every reference and every anomaly reads an
   existing service. A second definition of profit is the failure mode.
2. **Cost and margin stay gated** by `CostGatingInterceptor` in every new
   response, and the anomaly rules that carry margin are Owner-only.
3. **An approval authorises one sale**, and is spent. It can never be replayed
   into a second sale.
4. **The client cannot infer approval.** Only the server's stored `approved`
   status permits a below-cost sale; a client claiming approval is refused.
5. **A warning is not authorisation.** Acknowledging a magnitude warning changes
   nothing about permissions.
6. **Tenant and branch scope** come from the tenant client and the branch
   header, never from a request body.
7. **Nothing financial is hard-deleted** — a rejected or expired approval is a
   status, not a delete.
8. **MRU arithmetic is unchanged.** No new rounding, no new money helper.

### The six states, kept distinct

| State | Meaning | Blocks? |
|---|---|---|
| **Warning** | The server thinks this looks wrong | ❌ advisory |
| **Acknowledgement** | The user said "yes, that is right" | ❌ recorded on the action |
| **Approval request** | Somebody has asked | ⏸ the sale waits |
| **Approval** | Someone with authority said yes, once, for this | ✅ unblocks that one sale |
| **Rejection** | Someone with authority said no | ✅ terminal |
| **Hard validation failure** | The value is impossible (A0 bounds, negative, >2dp) | ✅ 400, no path forward |

---

## 7. Test matrix

| Area | Cases |
|---|---|
| A0 bounds | each money field at max, max+0.01, negative, 3 decimals |
| A1 references | each of rows 1–5, 7: above, below, exactly 10×, just under, no history, below min sample, zero |
| A1 non-interference | a warned request that is acknowledged succeeds; one that is not is **still not blocked** |
| A1 replay | same `client_uuid` returns the original outcome and does not re-warn |
| A2 lifecycle | request → approve → consume; reject; cancel; expire; double-consume refused |
| A2 voiding | price changed after grant; unit sold first; branch mismatch |
| A2 authorisation | requester cannot approve their own; a client-asserted approval is refused |
| A2 receipt | rendered receipt contains no approver, no cost, no margin |
| A3 rules | each rule at threshold, below min sample, empty data |
| A3 gating | Owner sees 4 and 6; Manager and Employee do not, in headers **and** body |
| A3 isolation | another company's data never appears |
| A3 dismissal | suppresses for 7 days, then returns; is audited |
| Cross-cutting | EN/FR/AR parity and key order; audit rows present and free of cost values |
| **Real MySQL** | one authenticated HTTP run per feature, inspecting responses and audit rows, fixtures cleaned, audit rows preserved |

---

## 8. Migration and rollback

- **A0, A1:** no migration. Rollback is a revert.
- **A2, A3:** one additive table each, forward-only, no data migration. A code
  rollback leaves the tables in place and unused, which is harmless.
- **A Git rollback does not roll back the database** (`docs/22`). Neither table
  holds financial truth, so no restore is needed to undo either.
- A verified backup is required before applying either migration, per the
  rulebook's database rules.

---

## 9. The exact approval statements requested

Please reply with the ones you approve, and corrections to any others.

> **A0.** *"Bound every money field to DECIMAL(14,2) with one shared MONEY
> constant. Hard validation failure."*

> **A1.** *"Approve order-of-magnitude warnings for sale price, intake cost,
> price change, expense amount and loan/consignment payment, at a 10× factor,
> against the references in §3/A1. Advisory only, never auto-correcting, silent
> where there is no reference, acknowledgement recorded in the audit row."*

> **A2.** *"Approve a `discount_approvals` table and its endpoints: requested by
> `sale.create`, granted by `discount.override`, one unit, one price, one
> branch, single use, 30-minute expiry, voided by a price change or the unit
> selling first, online-only, never on the receipt, never a reusable permission.
> No new permission key."*

> **A3.** *"Approve six deterministic anomaly rules as listed, advisory only,
> Owner-only for seller margin and below-cost clustering, dismissible for 7
> days, 90-day retention, one additive `anomaly_dismissals` table. No machine
> learning and no external service."*

**Implementation will not begin on any of these until the corresponding
statement is approved.** If you would rather change the order — A0 alone is the
smallest and closes a real defect today — say so and it can ship on its own.
