# 27 — Returns: audit, findings and decisions (I0)

> ## AUDIT ONLY (I0) — NOTHING WAS IMPLEMENTED IN THIS AUDIT
>
> **All eight decisions were APPROVED on 2026-08-14 — see §14.** Phase I1 then
> built the secure foundation (§15); the ReturnRequest lifecycle is I2.
>
> No schema was migrated, no return behaviour was changed, no permission was
> granted or revoked, no sale was created or returned, no mobile screen was
> added, and no financial fixture was created. Everything below is traced from
> the code, the schema and read-only queries against the development database.
>
> Phase **I0**, owner **CLAUDE-B**. Baseline verified at takeover: backend
> `e964c71` · mobile `3c016e3` · docs `bef8719` · 33 migrations · 56 suites /
> 778 tests · stock costs 4.27 / 5.00 / 5.00 / 8.67 · notifications 41 · sales
> 7 / 10 051.00.

---

## 1. The headline

**Returns are already implemented, and what exists contradicts almost every
approved rule.** `POST /sales/:id/returns` is a single call that finalises a
return immediately: it voids the sale line, rewrites the original sale's
totals, restocks the phone as ordinary sellable stock by default, and accepts
**any refund amount the client sends**.

There is no request, no review, no approval, no responsibility, no evidence, no
return-window check, no idempotency and no concurrency protection. The approved
lifecycle does not exist in any form.

The reported concern was accurate. It was also incomplete — see §2.4 and §2.5.

---

## 2. Current backend truth

### 2.1 The one route

| | |
|---|---|
| Route | `POST /v1/sales/:id/returns` |
| Permission | `sale.return` |
| Branch context | **Optional** — `this.tenant.branchId() ?? undefined` |
| DTO | `identifier` (required), `restock?`, `refundAmount?`, `reason?` |
| Idempotency | **none** |
| Version / CAS | **none** |
| Notification | **none** |
| Rollup refresh | **none** |
| Events emitted | **none** |

### 2.2 What `returnUnit` actually does, in order

1. Loads the sale; 404 if missing.
2. Loads the unit by IMEI **or** serial — company-scoped by the tenant client.
3. Finds the sale line where `saleId + unitId + voided = false`; 404 otherwise.
4. `restock = dto.restock ?? true` → final unit status `in_stock` **or** `faulty`.
5. Checks the unit state machine allows `sold → returned → finalStatus`.
6. `refund = dto.refundAmount ?? round(price × quantity − discount)`.
7. In one transaction:
   - `saleItem.voided = true`
   - `unit.status = finalStatus`, **`unit.dateSold = null`**
   - creates a `Return` row
   - **rewrites `sale.total`, `sale.totalCost`, `sale.margin`**
   - sets `sale.isReversed = true` when no unvoided line remains
   - writes two audit rows

### 2.3 Measured against the approved rules

| # | Approved rule | Reality |
|---|---|---|
| 1 | Employee may request, not finalise | ❌ one call finalises everything |
| 2 | Manager/Owner reviews | ❌ no review exists |
| 3 | Begins pending investigation | ❌ no state at all |
| 4 | Responsibility assigned after review | ❌ not modelled |
| 5 | Customer damage rejected without Owner exception | ❌ not modelled |
| 6 | Legitimate defect → full refund | ⚠️ refund is whatever the client sends |
| 7 | Records refund amount, account, confirmation time | ⚠️ amount only — **no account, no confirmation** |
| 8 | Refund timestamp automatic | ✅ `returnedAt` defaults to now |
| 9–12 | Configurable window, per-sale override | ❌ **never enforced** (§4) |
| 13 | Optional evidence | ❌ no field, no storage |
| 14–15 | Screen protectors non-returnable; accessories returned or paid | ❌ not modelled |
| 16 | Shareable return receipt | ❌ none |
| 18 | History never rewritten | ❌ **the sale is rewritten in place** (§2.4) |

### 2.4 History **is** rewritten — the most serious finding

`returnUnit` mutates the original sale row: `total`, `totalCost` and `margin`
are recomputed and overwritten, and the sale line is flagged `voided`.

That breaks approved rule 18 directly, and it interacts badly with closing:

- `RollupService.recomputeDaily` excludes voided lines (`AND si.voided = 0`).
- `DailyClosing` rows are written with `isLocked: true` and are **not**
  recomputed.

So a return dated today **retroactively lowers the revenue and COGS of the day
the sale happened** — but only the next time that branch-day is recomputed.
`returnUnit` emits no event and refreshes nothing, so the drift does not appear
at return time. It appears later, at an unrelated moment, and the locked
closing figure then disagrees with the rollup it was derived from, with nothing
recording why.

**A return must instead post a linked reversal dated the day it happened, and
leave the original sale untouched.**

### 2.5 Anyone with the permission can name their own refund

`refundAmount` is an optional client-supplied field with only `@Min(0)`. It is
never compared to what the customer actually paid. A caller may refund **more
than the line was sold for**, and nothing refuses it.

Combined with §2.6, this is the sharpest edge in the current implementation.

### 2.6 A defective phone becomes sellable immediately

`restock` defaults to **true**, so the default path returns the phone straight
to `in_stock`. The very next customer can buy a phone that was returned as
faulty ten seconds earlier. Marking it `faulty` requires the caller to opt in.

### 2.7 Answers to the specific questions

| Question | Answer |
|---|---|
| Can quantity lines be returned? | **No.** The code requires a `Unit` found by identifier and a line with `unitId`. Accessory lines are unreachable. |
| Whole invoice or one line? | **One line per call.** `isReversed` is set when the last line is voided. |
| Can the same line be returned twice? | **No** — the lookup filters `voided: false`, so a second attempt 404s. That is the *only* accidental protection present. |
| Return after transfer? | The unit is company-scoped, not branch-scoped, and branch context is optional — so a unit transferred elsewhere can still be returned against the original sale, and it is restocked wherever the code lands it. **Untested and unguarded.** |
| Returned unit immediately sellable? | **Yes, by default** (§2.6). |
| Original unit cost survives? | **Yes.** `unit.cost` is never touched, and `SaleItem.cost` is the immutable snapshot. |
| Refund uses original or current price? | **Original line price** by default — correct — but overridable (§2.5). |
| Below-cost effect on refund? | **None.** Below-cost gating applies to selling prices, not refunds. |
| External commissions reversed? | **Not modelled anywhere.** No commission concept exists. |
| Employee sale credit / goals reversed? | **No goals model exists.** Per-user sales are derivable from `sales.user_id`; a voided line silently changes that derivation. |
| Stock valuation refreshed? | **No.** No event, no rollup refresh (§2.4). |
| Original payment account recorded? | **No.** `Payment` has `method` only — no link to `ReceivingAccount`, which exists since Phase E. |
| Can a different refund account be recorded? | **No field exists.** |
| Receipt supports a reversal document? | **No.** `lib/receipt.ts` renders sales only. |

### 2.8 Cross-company and wrong-branch

Company isolation holds — every read goes through the tenant client. **Branch
isolation does not**: `branchId` is optional, and `GET /sales` and
`GET /sales/:id` carry **no `@RequirePermissions` at all**, so
`PermissionsGuard` exits early and never validates branch assignment. This is
the same defect class fixed for `/inventory` in H1.4.1 (`assertAssignedToBranch`).
It is **pre-existing and not introduced by Returns**, but Returns will build on
these reads, so it should be closed as part of the work.

---

## 3. Permissions truth

`sale.return` is a single permission that today means *finalise a return*.

| Role | Holds `sale.return`? |
|---|---|
| `owner` | ✅ |
| `administrator` | ✅ |
| `store_manager` | ✅ |
| `store_employee` | ❌ — deliberately audited out in `0018` |
| `branch_manager` *(legacy)* | ✅ |
| `sales_employee` *(legacy)* | ✅ |

`prisma/seed-data/permissions.ts` already documents *why* it was removed from
`store_employee`: "`returnUnit` voids the sale line, restocks the unit and
computes a REFUND … the approved rule is that an employee only requests one.
Needs a future `return.request`." **This audit confirms that reasoning.**

**Dormant risk:** the legacy `sales_employee` role still grants it, in both the
TypeScript matrix and the live database. **No live user is assigned to a legacy
role** (verified: every assignment is `owner` or `store_employee`), so nothing
is exposed today — but the grant should be revoked with the permission split.

### Proposed split

| Capability | Owner | Manager | Employee |
|---|:--:|:--:|:--:|
| `return.view` | ✅ | ✅ | ✅ |
| `return.request` | ✅ | ✅ | ✅ |
| `return.review` | ✅ | ✅ | ❌ |
| `return.approve` | ✅ | ✅ | ❌ |
| `return.reject` | ✅ | ✅ | ❌ |
| `return.refund_confirm` | ✅ | ✅ | ❌ |
| `return.exception` (customer damage) | ✅ | ❌ | ❌ |
| `return.exception_window` (expired deadline) | ✅ | delegated only | ❌ |

All must be **branch-scoped**, like every other operational permission —
anything absent from `COMPANY_PERMISSIONS` is branch-scoped and fail-closed.
An Owner acts "remotely" exactly as with transfers (H1.2): by explicitly
selecting the sale's branch. No cross-branch escape hatch is needed, because an
Owner is assigned everywhere.

**Guard note carried from H1.2:** `PermissionsGuard` requires **all** listed
permissions. If a route needs "review OR approve", it must be guarded on the
narrow key everyone holds, with breadth decided in the service — otherwise the
broad key locks out the people who should reach the route. This is the
`transfer.cancel_own` / `transfer.cancel` lesson (`docs/25` §10c) and it will
recur here verbatim.

---

## 4. Return-window truth

| Question | Finding |
|---|---|
| Field | `company_settings.return_window_hours`, `Int @default(0)` |
| Meaning of `0` | "The shop does not accept returns" |
| Who may edit | Owner, via `settings.manage`, with version CAS |
| Bounds | `0 … RETURN_WINDOW_MAX_HOURS` (one year) |
| **Enforced anywhere?** | **NO.** Zero references in `src/sales/`. The schema comment says so explicitly: *"nothing consumes this yet."* |
| Per-sale override | **Does not exist** |
| Deadline on the sale | **Does not exist** |
| Receipt shows a deadline | **No** |
| Timezone | Not modelled; `soldAt` is `DateTime(6)` written as `now()` in server time |
| Mobile | `app/settings.tsx` offers 0 / 24h / 48h / custom — configured, never enforced |

**So the demo shop is configured for "no returns" (`0`) and the return endpoint
works anyway.** The setting is decorative.

### Recommendation

Snapshot the deadline on the sale when the sale completes:

```text
sale.return_deadline_at = sale.sold_at + (per-sale window ?? company default)
```

Stored, immutable, **server-calculated**. Changing company settings later must
never alter an earlier customer's rights, and the client must never compute
eligibility. A null deadline means "no returns accepted for this sale", which
is what `0` means at sale time — and it stays true even if the Owner changes
the policy tomorrow.

Also snapshot the window actually applied, so a receipt can state the deadline
and an auditor can see which policy was in force.

Three authority paths, none implemented yet:
- **Remove the window for one sale** — Manager/Owner at sale time (null deadline, or an explicit "no returns" flag).
- **Lengthen or shorten at sale time** — Manager/Owner; an Employee may *request* a different window but not grant it (approved rule 12).
- **Post-sale exception on an expired deadline** — recorded on the return request as an explicit override, with who granted it and why.

---

## 5. Data-model gaps

`Return` today is a *completed-return receipt*, not a lifecycle:

```prisma
model Return {
  id, companyId, saleId, saleItemId?, unitId?,
  reason?, refundAmount, restock, returnedAt, createdById
}
```

It can express **none** of the following:

| Needed | Present? |
|---|---|
| Request distinct from completed return | ❌ |
| Lifecycle status | ❌ |
| Requester vs reviewer | ⚠️ `createdById` only |
| Responsibility (store / product / customer) | ❌ |
| Defect category | ❌ |
| Customer-caused damage flag | ❌ |
| Owner exception + who granted it | ❌ |
| Evidence / photo reference | ❌ |
| Requested / reviewed / approved / refunded timestamps | ❌ (one `returnedAt`) |
| Requested vs approved vs paid refund | ❌ (one `refundAmount`) |
| Refund account | ❌ |
| Rejection reason | ⚠️ one shared `reason` |
| Accessory disposition | ❌ |
| Idempotency key + payload fingerprint | ❌ |
| Optimistic version | ❌ |
| Immutable financial reversal | ❌ |

Adjacent gaps: `Sale` has no return deadline and no payment-account link;
`Payment` records `method` but never which `ReceivingAccount` took the money —
so the app cannot even state where the original payment went, let alone refund
to the same place.

**No existing status or notes column should be reused to avoid a migration.**
`Return.reason` in particular must not be overloaded to carry rejection reason,
responsibility and exception justification at once.

---

## 6. Inventory custody

Current `UnitStatus`: `in_stock · reserved · sold · returned · faulty ·
in_transit · transferred_out`, with `sold → returned → {in_stock | faulty}`.

`returned` exists but is **transient** — `returnUnit` passes straight through it
in one transaction. Nothing ever rests in `returned`.

`faulty` exists and is unsellable, but it means "broken", not "under
investigation", and it carries no link to the return that produced it.

### Recommended custody model

| Situation | Recommended state |
|---|---|
| 1. Customer still has the phone during investigation | No unit state change — the request records custody as *with customer*. The unit stays `sold`. |
| 2. Phone left with the store for investigation | New **`return_hold`** — physically here, **not sellable**, not yet ours to resell |
| 3. Approved return completed | Stays `return_hold` — approval settles the money, not the fitness for resale |
| 4. Awaiting repair or inspection | `return_hold` (technician workflow deferred) |
| 5. Explicitly cleared for resale | `in_stock`, by an explicit Manager/Owner action that is audited |
| 6. Rejected, phone returned to customer | Back to `sold` — the sale stands and was never reversed |

**The safety rule: an approved defective return must never become `in_stock`
automatically.** Today it does, by default.

`return_hold` is an **explicit migration decision** — a new `UnitStatus` enum
member plus state-machine edges. It cannot be faked with `faulty` without
losing the distinction between "broken" and "returned, not yet judged", which
is exactly the distinction that stops a defective phone being resold.

Valuation note: `return_hold` stock is owned and must still be counted in
inventory value (`heldValueRows` counts `status = 'in_stock'` only, so this
needs a deliberate decision at implementation time — a held-but-unsellable
bucket, not an invisible one).

---

## 7. Financial reversal plan

**Principle: the original sale is immutable. A return creates a linked reversal
event dated the day the return happened.**

| Concern | Recommendation |
|---|---|
| Original sale | Never rewritten. No `voided` flag flipped, no totals recomputed. |
| Reversal | A new dated record referencing sale + line, carrying reversed revenue, reversed COGS and reversed margin **from the sale's own snapshots** |
| Revenue / COGS / margin | Reversed using `SaleItem.price`, `SaleItem.cost`, `SaleItem.discount` — **never** current price or current average cost |
| Daily closing | The sale's day keeps its locked figures. The return's day carries the reversal. Closing must include reversals for its own day. |
| Monthly reports | No monthly surface exists yet; whatever is built must read reversals as dated events |
| Employee credit / goals | Not modelled; when built, credit follows the same dated-reversal rule |
| External commissions | Not modelled; out of scope until a commission concept exists |
| Inventory valuation | A returned phone re-enters company value at its **original unit cost**, which survives untouched |

Three amounts must stay separately visible and must not be collapsed:

```text
gross refund   the eligible phone amount, from the sale snapshot
adjustments    non-returnable items (screen protector) and accessory charges
net cash       what is actually handed back
```

`refund_due` (approved) and `refund_confirmed` (money actually returned) are
**different events with different timestamps and different actors**. The app
does not move money; it records that a human did.

---

## 8. Concurrency and idempotency risks

| Risk | Today | Needed |
|---|---|---|
| Duplicate employee request | nothing | mandatory `clientUuid` + payload fingerprint, as Sale/Purchase/Transfer already do |
| Retry after timeout | creates a second return | replay returns the original request |
| Two managers reviewing at once | both succeed | version CAS on the request |
| Approve vs reject | both succeed | one winner, loser gets 409 |
| Refund confirmed twice | duplicate refund record | CAS on lifecycle status |
| Return vs transfer of the same unit | unguarded | conditional unit-status update |
| Two requests for the same sale line | **partially blocked** by `voided: false` — accidental, not designed | `UNIQUE` partial index: one *active* request per sale line |
| Quantity return vs concurrent sale | n/a (unsupported) | the H1.4.1 atomic pattern when quantity returns arrive |
| Stale mobile screen | no version sent | `expectedVersion` on every transition |

Every one of these has a proven precedent in this codebase — transfers (H1.1–
H1.3) solved the same shapes. Returns should reuse those patterns rather than
invent new ones.

---

## 9. Mobile truth

| Question | Finding |
|---|---|
| Return surface | **None.** No screen, no API call, no query key |
| Sale history / sale detail screen | **Does not exist.** The only history screen is `pricing/history.tsx` |
| How to find the original sale | **Impossible in the app today** |
| Backend sale search | `GET /sales` is `take: 100`, newest first, **no search, no filters, no pagination** — cannot find an older sale by invoice, IMEI or date |
| Scan the returned IMEI | `ScannerSheet` + `ProductConfirmationCard` exist and are reusable |
| Verify the IMEI belongs to the sale | Backend already does this correctly (line lookup by `saleId + unitId`) |
| Notification deep-link | Infrastructure exists (H1.3: typed payload, `actionLink`, dedupe key) and is directly reusable |
| Wrong-branch handling | Solved pattern exists (H1.3 transfer detail: name the branch, offer an explicit switch, never switch silently) |
| Photo / evidence infrastructure | **None.** No image picker, no upload path |
| Return receipt | `lib/receipt.ts` (HTML → PDF → share sheet, RTL-aware) is reusable for a reversal document |

### Proposed screens

1. **Returns list / history** — status groups mirroring the transfer list (Pending · Under review · Approved · Refund due · Refunded · Rejected), server-side search and paging.
2. **New return request** — open from a sale, scan or type the IMEI, reason, optional evidence.
3. **Return detail / investigation** — the lifecycle, evidence, responsibility, and server-computed available actions.
4. **Refund confirmation** — amount, account, confirmation.
5. **Sale detail return action** — which first requires a **sale detail screen to exist at all**.

**Dependency worth surfacing early: Returns needs sale search and a sale detail
screen, and neither exists on the backend or the phone.** That is real work
that must be sequenced before the return flow, not discovered during it.

---

## 10. Recommended lifecycle

```text
requested ──review──► under_review ──approve──► approved ──confirm──► refunded
    │                      │                        │
    └──cancel──►cancelled  └──reject──► rejected    └─(unit stays return_hold
                                                       until explicitly cleared)
```

- **requested** — employee or anyone with `return.request`; records custody, reason, optional evidence. Unit unchanged.
- **under_review** — a reviewer has taken it; responsibility and defect category assigned here.
- **rejected** — reason mandatory; phone goes back to the customer; the sale stands.
- **approved** — responsibility settled, refund amount fixed **from the sale snapshot**, reversal posted, unit moves to `return_hold`.
- **refunded** — a separate confirmation that money was actually returned, with account and timestamp.

Customer-caused damage may only reach `approved` with an Owner exception. An
expired deadline may only be overridden by an Owner (initially).

---

## 11. Proposed sequence

1. Return deadline snapshot on `Sale` (+ per-sale window at sale time)
2. `ReturnRequest` + immutable reversal schema
3. Permission split with deployment-safe backfill, revoking the legacy grant
4. **Sale search + sale detail** (backend contract, then mobile) — prerequisite
5. Employee request
6. Investigation / approval / rejection
7. `return_hold` custody + explicit clear-for-resale
8. Refund due + refund confirmation (account, timestamp)
9. Closing / analytics reversal, dated correctly
10. Notifications (reuse H1.3 infrastructure)
11. Mobile screens + return receipt
12. Real-MySQL concurrency tests
13. Device QA

Steps 1–3 are schema and authority and should land before any workflow. Step 4
is the dependency §9 exposes.

---

## 12. Decisions needed before implementation

### 1. Custody during investigation
Must the customer leave the phone with the store while the claim is
investigated?
**Recommended:** custody is an optional recorded field at request time, **but
approval requires the phone to be physically present.**
*Consequence:* judging a defect you cannot hold is guesswork, and approving a
refund while the customer keeps the phone risks paying out and losing the goods.

### 2. Returned phone after approval
**Recommended:** `return_hold` — unsellable until a Manager/Owner explicitly
clears it for resale or hands it to a future technician flow.
*Consequence:* prevents reselling a known-defective phone. Costs one enum value,
one state-machine edge, and a deliberate decision about whether held stock
counts in inventory value (recommended: yes, at original cost).

### 3. Refund lifecycle
**Recommended:** approval creates **refund due**; a separate confirmation
records that money was actually returned, with the account and time.
*Consequence:* the shop can see what it owes versus what it has paid. Collapsing
them would make "approved" mean "paid", which is false the moment a customer
leaves before the cash is counted.

### 4. Screen-protector and accessory accounting
**Needs your decision.** Do non-returnable charges *reduce the cash handed back*,
or are they recorded as a *separate new sale*?
**Recommended:** separate adjustment lines on the return, so **gross refund** and
**net cash** both stay visible.
*Consequence:* netting them silently makes the refund look smaller than the
phone's price and makes reconciliation at closing very hard to explain.

### 5. Expired-window authority
**Recommended:** only the **Owner** may override an expired deadline initially;
Manager delegation can follow once the flow is proven.
*Consequence:* the return window is the shop's main protection against
open-ended liability. Delegating the override on day one removes it.

### 6. Quantity accessories
**Recommended:** serialized phone returns first. Accessories handled only as
linked dispositions/charges on a phone return; independent accessory returns
follow once the phone flow is proven.
*Consequence:* accessory returns need the H1.4.1 atomic weighted-average path in
reverse, which is real work and shouldn't block the phone workflow.

### 7. Pre-existing defect — decide whether it is in scope
`GET /sales` and `GET /sales/:id` carry **no permission and no branch
validation** (§2.8), the same defect fixed for `/inventory` in H1.4.1.
**Recommended:** fix it as part of step 4, since Returns will read sales
heavily.
*Consequence:* left alone, any signed-in user can read another branch's sales —
and, once Returns exists, act on them.

---

## 12b. Two approved rules found in `docs/21` §9 that change the plan

Re-reading the approved decisions after the code audit surfaced two rules worth
stating separately, because both affect design and neither is implemented.

**1. "Returned phone becomes *Faulty awaiting inspection*, not sellable."**
This is already approved — so §6's custody recommendation is not a new product
decision, it is the existing one being honoured. The only open question is
whether to reuse `faulty` or add `return_hold`. **Recommended: a distinct
`return_hold`**, because `faulty` already means "broken" for stock that was
never sold, and collapsing the two loses the link to the return and the reason
the phone is unsellable. If you prefer no new enum value, `faulty` plus a
mandatory link to the return would work, at the cost of a muddier inventory
screen.

**2. "Profit stays provisional during the return window."**
This is the largest unexamined consequence in the milestone, and it was flagged
in the approved decision itself: *"this affects the existing rollup design."*

Today profit is final the moment a sale commits — `daily_rollups` are computed
from `sale_items` and `DailyClosing` is written `isLocked: true`. If profit is
provisional for 24 or 48 hours, then **a day can be closed before its sales are
final**, and today's design has no way to express that.

Options, none free:
- **(a)** Keep closing as-is and post reversals on the return's own date. Simple, matches §7, but profit is *not* provisional — it is final and later adjusted.
- **(b)** Mark rollup figures provisional until every sale of that day is past its deadline, and delay or re-open closing. Truthful, and a substantial change to closing.
- **(c)** Report both: a final "as closed" figure and a "net of later returns" figure. More honest than (a), less disruptive than (b).

**Recommended: (a) for the first release, with (c) as the reporting follow-up.**
Reversal-on-return-date is the standard accounting treatment, keeps closed days
immutable, and does not destabilise a closing flow that already works. But this
is a **product decision about what "profit" means to the Owner**, and it should
be answered explicitly rather than settled by implementation convenience.

---

## 13. What must not be lost

- The original sale, its invoice and any closed-day record are **permanently
  immutable**. The current implementation violates this and must be replaced,
  not extended.
- Refunds are computed from **sale snapshots**, never current price or current
  average cost.
- The app **records** money movement; it never moves it.
- Warranty and technician/SAV workflows stay deferred — but `return_hold` exists
  precisely so a defective phone can wait for them safely.
---

## 14. APPROVED — the eight decisions (2026-08-14)

The user approved every I0 recommendation. These are now **decided**, not
proposed, and supersede the open questions in §12 and §12b.

| # | Decision | Approved answer |
|---|---|---|
| 1 | Custody during investigation | **The phone must be physically presented and scanned before approval.** Custody may be recorded at request time, but approval cannot happen without the device in hand. |
| 2 | Returned phone after approval | Becomes **unsellable** — `faulty` / return-hold custody. It never re-enters `in_stock` automatically. |
| 3 | Refund lifecycle | Approval creates **`refund_due`**. Payment confirmation is a **separate** act, separately recorded. |
| 4 | Screen protector and retained accessories | **Explicit return adjustment lines**, so gross refund and net cash both stay visible. Never netted silently. |
| 5 | Expired-deadline override | **Owner only**, initially. Manager delegation may follow once the flow is proven. |
| 6 | Scope of the first implementation | **Serialized-phone returns.** Accessories are *linked dispositions* on a phone return, not independent returns. |
| 7 | Historical integrity | The **original sale and closing remain immutable**. An approved return posts a **dated reversal**. |
| 8 | Profit and the return window | Profit is **recognised at sale**, **displayed as subject to return** during the window, and **reversed on the approval date**. |

### 14.1 What "provisional profit" means — and does not mean

Decision 8 was the one open question that could have been mis-implemented into
a large accounting change. It is deliberately narrow:

**It IS:** a *display and operational warning*. While a sale is inside its
return window, surfaces that show profit may mark it as subject to return, so
an Owner reading today's figure knows part of it could still come back.

**It is NOT:**

- ❌ It does **not** delay revenue recognition. Revenue, COGS and margin are
  recognised when the sale commits, exactly as today.
- ❌ It does **not** make closing mutable. `DailyClosing` stays locked, and a
  day may be closed while sales inside it are still returnable.
- ❌ It does **not** retroactively adjust the sale's own day. A later approved
  return posts a **separate reversal dated the approval date**.
- ❌ It does **not** touch the original sale, its invoice, its lines, its cost
  snapshots, its margin snapshot, or any locked closing record. All remain
  immutable, permanently.

This is standard accounting treatment — recognise, then adjust with a dated
reversal — and it means no change to the closing flow that already works.

### 14.2 What this leaves open

Nothing blocking. Decisions 1–8 answer every question I0 raised. The remaining
sequencing is engineering, not product:

- The pre-existing sales-read defect (§2.8) is **in scope for I1** and closed
  there.
- Sale search and sale detail (§9) are **in scope for I1**, because a return
  cannot start without finding the sale.
- The ReturnRequest lifecycle itself is **I2**.
