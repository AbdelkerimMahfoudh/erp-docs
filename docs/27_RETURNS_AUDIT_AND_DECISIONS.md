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

## 15. I1 — what was built, and what it means for I2

Phase I1 built the foundation the ReturnRequest lifecycle needs. **No return can
be created, approved or refunded yet.** That is I2.

### 15.1 The unsafe endpoint is gone, not merely closed

`POST /sales/:id/returns` answers **410 Gone** with `legacy_return_disabled` and
performs no database write of any kind. The five dangers §2 catalogued are
unreachable because the code that did them no longer exists: `returnUnit` and
`ReturnSaleDto` are **deleted**, not commented out or hidden behind a flag.

410 rather than 404 so a stale client learns *why* it stopped working instead of
guessing at a bad URL. The route is deliberately **not** guarded on
`sale.return` any more — a permission gating nothing but a refusal would imply
the behaviour still exists somewhere.

`sale.return` survives in the permission catalogue only so an older session's
permission set still maps to a known key. It guards no route. Nothing should be
gated on it, in either repository.

### 15.2 Every sale now carries its own return policy

Migration **`0035`** adds four columns to `sales`:

| Column | Meaning |
|---|---|
| `return_window_hours` | What was promised, in hours. `0` = no returns. |
| `return_deadline_at` | `sold_at + window`, computed by the SERVER. `NULL` when the window is 0. |
| `return_policy_overridden_by` | Set only when a Manager or Owner changed it at sale time. |
| `return_policy_override_reason` | Why. |

Two CHECK constraints make an inconsistent pair unwritable by any future code
path: the window is 0..8760, and *window = 0 if and only if there is no
deadline*. "No deadline" and "deadline already passed" are different facts and
must not share a representation — a screen has to say different things about
them, and a past date standing in for "no returns" would make an expired sale
and a no-returns sale indistinguishable.

**Why snapshotted rather than looked up:** `company_settings.return_window_hours`
is what the shop offers *today*. Computing eligibility from it would let an
Owner shortening the window tomorrow retroactively cancel a right already
promised, and lengthening it silently grant one nobody offered. The customer's
rights are fixed at the moment of sale, so the sale carries them. Written once,
never updated.

**Why existing sales got 0/NULL:** audited before the migration was written —
the company window is `0` and the newest of the seven existing sales was 263
hours old, so no existing sale sat inside any previously promised period. 0/NULL
states the literal truth rather than a convenient default. The migration says so
in its header and requires any other environment to rerun that audit before
deploying.

### 15.3 The rules, as one place

`backend/src/sales/return-policy.ts` holds three decisions as pure functions, so
I2's return endpoint reuses them unchanged rather than restating them:

- **`snapshotPolicy`** — the deadline is derived from the server's own sale
  timestamp, so the two can never disagree.
- **`resolveWindowForSale`** — who may change the policy at sale time.
  Re-stating the default is *not* an override (an ordinary sale needs no reason
  and no permission). Asking for something different without
  `return.policy.override` is **refused, not quietly downgraded**: an employee
  must never be told a sale succeeded under a policy it does not have. A real
  change demands a reason. **A positive window may be removed entirely or
  extended, but not shortened to another positive value** — trimming 48 hours
  to 2 sells a worse promise under the same banner, while `0` is an explicit
  decision the customer is told about at the till.
- **`evaluateEligibility`** — computed from the server clock and the sale's own
  snapshot, returning ONE reason a screen can turn into a sentence:
  `no_return_policy · within_window · window_expired · already_returned ·
  quantity_not_supported · sale_reversed`.

The 0..8760 bounds come from `settings.constants`, not a second copy: a sale
must never be able to carry a window the Owner could not have saved.

### 15.4 Reading sales is now a permission

`sale.view` and `return.policy.override` are added by `0035` (not by the seed —
`migrate deploy` never runs it, the D2.1 lesson). Both are **branch-scoped**:
absent from `COMPANY_PERMISSIONS`, so `getEffectivePermissions` refuses a branch
the caller is not assigned to, and keeps only company-wide keys when there is no
branch header — which cannot include either of these.

| Role | `sale.view` | `return.policy.override` |
|---|---|---|
| Owner | ✅ | ✅ |
| Store manager | ✅ | ✅ |
| Store employee | ✅ | ❌ |

`sale.view` is deliberately **not** `report.view`: seeing what the branch sold
is ordinary counter work, and profit dashboards are not. Cost and margin remain
gated independently by `cost.view` through the global gating interceptor — the
sales reads do not re-implement that strip, and the routes do not also demand
`cost.view`, which (since the guard requires ALL listed keys) would have locked
the whole screen for an employee instead of hiding two numbers on it.

### 15.5 The sales-read defect (§2.8) is closed

`GET /sales` and `GET /sales/:id` required **no permission at all**, and the
list fell back to `{}` when no branch header was present — so any signed-in user
could read every sale in the company, cost and margin included, by sending no
header. `take: 100` with no paging quietly amputated the history of any shop
past its first weeks.

Now: both routes require `sale.view`; the list refuses to run without an active
branch; paging is keyset on the UUIDv7 primary key (a total order, so a sale
completed mid-scroll cannot shift the page under the reader); and **every filter
is applied in SQL** — invoice, employee, customer, IMEI, serial, product,
variant, barcode, pay status, payment method and a sold-at range. An unknown
status or method is a 400 rather than an ignored filter, because silently
dropping it widens the query and shows everything under a heading claiming
otherwise.

The detail read fails closed three ways that answer **identically**: another
company's sale is invisible (the tenant extension scopes the unique lookup),
another branch's sale is refused, and an unknown id is not found. A different
message for any of them would confirm that an invoice exists elsewhere in the
company.

### 15.6 What the customer is told

The receipt states the policy the sale was sold under — the window in words a
person repeats back ("2 days", not "48 hours") and the exact deadline, because a
window alone leaves the customer doing arithmetic from a time they may not
remember. The receipt also stopped dating itself from the phone's clock:
`soldAt` now comes from the server, so the moment printed and the deadline
measured from it come from the same machine.

Mobile gained `/sales` and `/sales/[id]`, with the return status on **every row**
— "can this still be brought back?" is the question the history gets opened for.
The device never recomputes eligibility; it renders the server's answer.

The Sell screen shows the policy in the payment sheet, immediately above
Complete. An employee sees it read-only rather than not at all; a manager or
owner may change it, and Complete is blocked until a changed policy has a
reason, so the refusal happens before the customer's money moves.

### 15.6b Proven over HTTP, not only by tests

**78 live checks, all passing**, against a verification backend on port 3099
using five temporary probe identities — Owner, Store Manager, Store Employee, a
warehouse-only Manager and a cross-company Owner — created on existing role rows
and removed in the same run. The demo Owner's password was not changed.

Proven live: both endpoints · `?limit=` conversion · keyset paging across three
pages with zero overlap and every sale exactly once · invoice, IMEI, serial and
partial-identifier search · whole-day date ranges · a warehouse manager seeing
zero sales rather than the company · a forged branch header refused · a missing
branch header refused rather than defaulting to the company · another company
seeing nothing and receiving an identical 404 · the policy snapshot matching the
stored row and reporting `no_return_policy` rather than "expired" · and the
disabled legacy return answering 410 while moving no sale, sale item, unit,
stock, payment, return, closing, notification or audit row.

**One defect was found that 868 tests had approved.** `GET /sales/:id` with a
malformed id returned **500**, because `uuidToBin` throws on a non-UUID. That
broke the fail-closed rule above: a 500 announces "structurally invalid" where a
real-but-not-yours id says "not found", which is exactly the distinction the
identical-404 answer exists to withhold. A malformed id is the fourth way in and
now answers like the other three. Fixed in backend `309a399` with a regression
test over five shapes.

**A gap worth naming: cost gating has no live negative case.** Every store role
— including `store_employee` — currently holds `cost.view`, so all three roles
correctly received cost and margin, and the gating interceptor never actually
strips a field on these endpoints today. The strip itself is covered by unit
tests. Whether an employee should see profit is a **product** question for
`docs/03`, and deliberately was not settled by editing a role matrix during
verification.

### 15.7 What I2 inherits

- A sale it can look up, search, and read safely.
- A policy snapshot it must **recompute against**, never trust from a screen.
- `evaluateEligibility`, which already answers "is this still open?" — I2 adds
  what happens next.
- An audit convention: the sale-time policy override records under the existing
  `override` action with `field: 'returnPolicy'`, distinguishing it from the
  below-cost override that shares the action. If I2 adds enough distinct return
  events to justify it, that is the point to consider an `AuditAction` migration
  — deliberately not done here, where it would have been a schema change for a
  label.

**Still not built, by design:** ReturnRequest, custody, approval, restocking
disposition, refunds, idempotent execution, the Owner expired-deadline
exception, and accessory dispositions. Decisions 1–8 in §14 govern all of them.


---

## 16. I2.0 — the audit before the workflow (2026-08-14, CLAUDE-B)

Read before designing anything. The conclusion first, because it decides whether
I2 can proceed at all:

> **The immutable dated reversal CAN be represented without redesigning closing
> or accounting, and without rewriting a single historical row.** The reasons are
> in §16.5. No stop condition was triggered.

### 16.1 What already exists that I2 must reuse, not reinvent

Every primitive this phase needs is already present, proven in production paths,
and tested. Building a second one of any of these would be the mistake.

| Need | What exists | Where |
|---|---|---|
| Idempotent create | `clientUuid` + `clientRequestHash` (payload fingerprint) + `@@unique([companyId, clientUuid])` | `StockTransfer`, `Purchase`, `Sale` |
| "Same key, different payload" → 409 | the fingerprint comparison | `StockTransfer` |
| Exactly-one-winner transitions | `version Int @default(0)` + `updateMany({ where: { id, companyId, version }, data: { version: { increment: 1 } } })`, `count === 0` → 409 `refresh_required` | `transfers.service.ts` |
| Audit | `AuditService.recordTx(tx, …)` — same transaction, append-only, DB triggers reject UPDATE/DELETE | `common/audit` |
| Notifications | `NotificationsService.emit`, written inside the transaction | `notifications/` |
| Branch + permission gating | `@RequirePermissions`, branch-scoped by absence from `COMPANY_PERMISSIONS`, `assertAssignedToBranch` for unguarded reads | `rbac/` |
| Cost/margin gating | global `CostGatingInterceptor` + `FINANCIAL_FIELDS` | `common/interceptors` |
| Keyset pagination + SQL search | the I1 sales reads are the reference implementation | `sales.service.ts` |
| Ids | UUIDv7 `BINARY(16)`, `newUuidV7Bin` | `common/utils/uuid.util` |

### 16.2 The Unit lifecycle already has the states this needs

`UnitStatus` is `in_stock · reserved · sold · returned · faulty · in_transit ·
transferred_out`. **`returned` and `faulty` already exist** — no enum migration
is required for custody.

The machine (`inventory/unit-state-machine.ts`) allows:

```
sold      → returned            ✅ custody intake
returned  → faulty              ✅ approval, into return hold
returned  → in_stock            ✅ (exists; NOT used by I2 — approval must never
                                    make a returned phone sellable)
faulty    → in_stock            ✅ (a later inspection milestone, not I2)
```

**One gap.** Rejection has to hand the phone back and restore it to `sold`, and
`returned → sold` is **not** currently a legal transition. That is a
one-line, data-driven addition to `TRANSITIONS`, not a redesign — and it needs
its own test, because "returned → sold" must be reachable ONLY via rejection
with recorded hand-back, never as a general-purpose escape from return hold.

**A returned or faulty unit is already inert.** All three sellability gates
independently require `in_stock`:

- `SalesPolicyService.assertSellable` → cannot be sold
- `PricingService.assertUnitPriceable` → cannot be priced
- `transfers.service` eligibility + the `status: 'in_stock'` compare-and-swap in
  the reservation → cannot be transferred or reserved

So the custody states are safe by construction. I2 must add tests that pin this
rather than new guards.

**But its asset value disappears.** `held-value.ts` counts units
`WHERE u.status = 'in_stock'`, so a `faulty` unit contributes nothing to
inventory value. For I2 this is *not* a regression — the phone left inventory at
sale time and its value is already out of stock value — but it does mean
faulty/return-held stock is currently invisible as an asset. Reporting it
separately is an additive change, and §16.5 keeps it out of `totalStockValue` so
the "must not move when stock is merely travelling" guarantee is untouched.

### 16.3 The legacy `returns` table — empty, dead, and not to be reused

`Return` still exists in the schema with exactly the fields the I0 audit
condemned: a client-supplied `refundAmount` and a `restock Boolean @default(true)`
that would put a defective phone back on the shelf.

- **0 rows.** Nothing to migrate, nothing to reconcile.
- Its only remaining references are the `returns` relation used for the I1
  `hasReturn` eligibility check, and one audit-history query in
  `inventory.service.ts` that includes `entityType: 'Return'`.

**Decision: do not reuse it and do not drop it in I2.** Reusing a table whose
shape encodes the exact defect being fixed would reintroduce the defect's
vocabulary. Dropping it is destructive, needs its own backup-and-decision cycle,
and buys nothing while it holds no rows. It is marked deprecated here; the I1
`hasReturn` check moves to the new request table, and removal becomes a small,
isolated task for a later phase.

### 16.4 Linked accessories cannot be attributed automatically — and must not pretend to be

Accessory lines are identifiable **per sale** (a `SaleItem` with `productId` set
is a quantity line) but not **per phone**. Measured on the demo data:

| Invoice | Serialized lines | Accessory lines |
|---|---|---|
| 00001 / 00002 / 00003 | 2 | 1 |
| 00004 / 00005 | 0 | 1 |
| 00006 | 1 | 1 |
| 00007 | 1 | 0 |

Three sales carry **two phones and one accessory line**. Nothing in the data says
which phone the screen protector belonged to, because nothing ever recorded it.

**Therefore I2 does not infer accessory linkage.** A Manager or Owner enters each
retained-accessory or screen-protector charge as an explicit adjustment line
during review, fully audited, exactly as decision 4 requires. Inferring it would
be inventing a fact — and on a two-phone sale it would be wrong half the time.

### 16.5 The dated reversal fits — here is precisely why

This was the stop condition worth checking hardest.

**`DailyRollup` is derived, not remembered.** `RollupService.recomputeDaily`
recomputes a branch-day from `sale_items ⋈ sales` filtered on `s.sold_at`, then
upserts. Adding a returns component computed from the new reversal table, keyed
on the **approval date**, is therefore additive: it changes what a day's rollup
reports without touching one sale row.

**`DailyClosing` is an immutable locked snapshot.** It stores `totalSales` /
`totalProfit` at close time, `isLocked` defaults true, and nothing recomputes it.
A reversal dated later cannot reach backwards into it.

**The sale's own day is provably unchanged.** The original `Sale`, `SaleItem`,
`Payment` rows are never written by the return flow — no `voided`, no total
rewrite. So recomputing the sale's day yields byte-identical figures. *(This is
exactly what the deleted legacy endpoint got wrong: it set `voided = true`, and
because the rollup filters `si.voided = 0`, a return silently rewrote a past
day's revenue and profit — including days already closed.)*

**The one real hazard, and its answer.** If a return is approved on a day that
is **already closed** for that branch, the locked snapshot would permanently
disagree with a recomputed rollup for the same day. The workflow must refuse:
approval on a closed business day returns an actionable **409**, and nothing
reopens or rewrites a closing automatically. This is the single accounting rule
I2 must not get wrong.

**What this costs:** additive columns on `daily_rollups` for the returns
component (so a day reports its reversals separately rather than netting them
invisibly into revenue), and a new immutable reversal table. No change to
`DailyClosing`, `DailyDigest`, `DigestLine`, or any existing calculation's
meaning.

### 16.6 What the I1 foundation already provides

- `sales.return_window_hours` / `return_deadline_at` — the policy the sale was
  sold under, snapshotted, never updated.
- `return-policy.ts` — `evaluateEligibility` already answers *is this still
  open?* from the server clock, returning `no_return_policy · within_window ·
  window_expired · already_returned · quantity_not_supported · sale_reversed`.
  **I2 must recompute against this, never trust an eligibility a screen sends.**
- `sales.return_policy_overridden_by` / `_reason` — who changed the promise at
  sale time, and why.
- The 410 `legacy_return_disabled` route, proven mutation-free over HTTP.
- Mobile `/sales` and `/sales/[id]`, which is where "Request return" belongs.

### 16.7 Consequences for the I2 design

1. Two new tables — a return **request** (lifecycle, custody, responsibility,
   idempotency, version) and an append-only **reversal** (the money snapshot) —
   plus adjustment lines. No new notification, audit, money-ledger or role
   mechanism.
2. `returned → sold` added to the unit state machine, reachable only via
   rejection with recorded hand-back.
3. Additive returns columns on `daily_rollups`; `DailyClosing` untouched.
4. Approval refused with 409 when its own business day is already closed.
5. Gross refund comes from the immutable `SaleItem` snapshot; adjustments are
   explicit, server-summed; net = gross − adjustments.
6. The legacy `returns` table is deprecated in place, not reused and not dropped.

### 16.8 Backup and restore proof for I2

- Backup: `~/erp-backups/phonestore-i2-20260814-185656.sql` — **305 824 bytes**,
  55 tables, 4 triggers, **0 raw `_binary`**, trailer `-- Dump completed`.
- Restore proven on the disposable database `prisma_i2_pre` via
  `scripts/sanitize-dump.js` (4 definers stripped on 4 lines), restoring as the
  migrator: **55 tables, 4 triggers, sales 7 / 10 051.00, units 11, audit 281,
  returns 0**.
- Binary ids verified, not assumed: `units` id checksum
  **`2a1dc9bf284afde32b402ad108d38a76`**, identical to the value recorded in
  migration `0035` during I1; `sale_items` price/cost checksum
  **`50f6e146fb9e7c5822fa65c37cb45edc`**.
- The sanitised copy was deleted; the original dump is the backup.


### 16.9 CP2.1 — the 58-versus-57 table discrepancy, reconciled

CP2 reported 58 tables on the restored pre-I2 database after `0036` and 57 on
the clean all-migrations database. A one-table difference between "what a
restore looks like" and "what a fresh deployment looks like" is exactly the kind
of thing that must be explained before application code depends on the schema,
so both were rebuilt and their table-name **sets** compared rather than their
counts.

**Result: one table differs, and it is `_prisma_migrations`.**

```
restored: 58   clean: 57
only in RESTORED:  _prisma_migrations
only in CLEAN:     (none)
```

Every business table is identical. Against the Prisma schema, which declares
**57** mapped models:

| Comparison | Result |
|---|---|
| in schema, not in clean | none |
| in clean, not in schema | none |
| in schema, not in restored | none |
| in restored, not in schema | `_prisma_migrations` |

**Category: a counting/tooling artifact of how the clean database was built.**
Not legacy residue, not an omitted migration, not `db push` drift:

- `_prisma_migrations` is **Prisma's own migration-history bookkeeping table**.
  It is created and maintained by `prisma migrate`, is not a model, and is
  deliberately absent from `schema.prisma`.
- The restored copy has it because it came from a dump of dev, which Prisma
  manages. Dev currently holds **36** rows there, one per applied migration.
- The clean database lacked it **only because it was built by feeding the
  migration SQL files to the `mysql` client**, which never creates it. That
  route was chosen in CP2 because `prisma migrate deploy` cannot target an
  overridden `DATABASE_URL` on this machine (see the note below).

**A real clean deployment is therefore correct and has 58 tables**, because a
real deployment runs `prisma migrate deploy`, which creates `_prisma_migrations`
before applying anything. The 57 was an artifact of the proof method, never of
the migration.

**Why runtime code cannot depend on the differing table.** Nothing in the
application may read or write `_prisma_migrations`: it is Prisma CLI state, its
shape is owned by the tool and can change between Prisma versions, it is absent
from the generated client, and it is absent entirely from a database built by
any route other than the Prisma CLI. Anything needing to know "which migration
is applied" belongs to deployment tooling, not to a service.

**The legacy `returns` table was NOT dropped to equalise counts.** It is present
in both databases and in the schema as `model Return`, holds zero rows, and
stays deprecated in place per §16.3.

No corrective migration is required, so none was written. Adding a migration to
"fix" a difference that does not exist in a real deployment would have been a
schema change made to satisfy a miscount.

#### Preserved finding — Prisma's schema engine and alternate databases

`prisma migrate deploy` / `migrate status` fail with **``Unknown authentication
plugin `sha256_password'``** whenever `DATABASE_URL` is overridden to any
database other than `phonestore`, while:

- the **query engine** connects to the very same database with the very same
  credentials and reads data successfully;
- the `mysql` client connects to it fine;
- `phonestore_migrator` holds `ALL PRIVILEGES ON prisma\_%`, so privileges are
  not the cause (a database named outside that pattern is a *different*,
  correctly-reported `ERROR 1044 Access denied`).

It is a schema-engine/driver quirk, not a credentials, privileges or migration
problem, and it did not block any required proof: the restored, clean and
rerun proofs were applied with the `mysql` client, and the dev proof used the
real `prisma migrate deploy` path, which works because it uses `.env` unchanged.
Recorded here so the next session does not rediscover it; deliberately not
investigated further, since it costs session time and blocks nothing.

**One practical consequence worth knowing:** a temporary database used with the
`mysql` client must be named `prisma_…` to fall under the migrator's grant.
`i2_restored` failed with `ERROR 1044` for exactly that reason.


### 16.10 I2-CP3 and CP4 — the workflow, as built

Migration `0036`. Backend `6b75ee0` (request, custody, investigation,
adjustments, queries) and `bc5071d` (approval, rejection, reversal, accounting).

#### Lifecycle

```
pending_investigation ──► under_review ──┬──► approved_refund_due   (terminal)
          │                              └──► rejected              (terminal)
          └────────────────────────────────►  either, directly
```

There is deliberately **no `refunded` state**. Approval creates an obligation;
confirming money moved is I3, and a state that does not exist cannot be set by
accident.

#### Custody, and the one new transition

| Custody | Unit status | When |
|---|---|---|
| `customer_holds` | `sold` | request raised, phone still with the customer |
| `store_holds` | `returned` | the shop physically received it |
| `handed_back` | `sold` | rejected, and given back |
| `retained_hold` | `faulty` | approved, held and unsellable |

`returned → sold` was added to the unit state machine and is reachable **only**
through rejection, together with a recorded hand-back. A returned or faulty unit
was already un-sellable, un-priceable and un-transferable, because all three
gates independently require `in_stock` — proven live: selling a returned phone
was refused.

#### Money

Gross refund is `price × quantity − discount` from the immutable sale line —
**the same expression the daily rollup uses for revenue**. Any other expression
would fail to cancel the revenue it reverses, and the books would disagree by
exactly the discount.

Adjustments are explicit positive lines; the server multiplies and sums. They
may not exceed the gross, so a customer never finishes a return owing money.
`net = gross − adjustments`, enforced by a CHECK as well as by code.

#### Accounting — what is reversed, and what deliberately is not

Revenue falls by the **net** refund: anything withheld as an adjustment is money
the shop kept.

**COGS is not credited back.** The returned phone is held as `faulty`, and
`held-value` counts only `in_stock`, so the goods are not an asset again.
Crediting the cost while the asset is absent from inventory would book the same
benefit twice and flatter the month. `returns_cogs` exists and stays 0 until the
later inspection milestone decides whether the phone returns to stock or is
written off. The profit impact of an approved return is therefore the full net
refund — the conservative reading.

The reversal is dated the **approval day**, so the sale's own day recomputes
byte-identically. Approving on an already-closed day returns a 409 naming the
day; no closing is ever reopened or rewritten.

#### Authority

| | view | request | review | approve | reject | exception |
|---|---|---|---|---|---|---|
| Owner | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Store Manager | ✅ | ✅ | ✅ | ✅ | ✅ | ❌ |
| Store Employee | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |

Two cases require `return.exception` **and** a written reason: an expired or
absent policy window, and customer-caused damage. Both are departures from what
the customer was promised.

Custody intake is guarded on `return.request`, not `return.review`: the employee
handed the phone records it. Waiting for a manager would either stall the
customer or record an arrival time that never happened.

#### Verification

- Backend **65 suites / 935 tests**, `tsc` clean, `prisma validate` valid,
  **36 migrations**, schema up to date.
- **62 of 63 live HTTP checks** passed against real MySQL on the first clean
  run. The single failure was the harness comparing a MySQL `DATE` through
  `String()` against an ISO slice; the recorded approval date was already
  correct (`2026-08-15`, verified independently from audit row 900).

#### Two defects live verification found

1. **The notifier wrote a `data` field that does not exist on `Notification`.**
   Prisma rejected it, and the global exception filter reported **"Invalid query
   parameters"** — a `PrismaClientValidationError` is mapped to that message
   regardless of cause, which is misleading enough to be worth knowing when
   debugging. Worth revisiting in a later phase.
2. **The existing deduplication mechanism was being ignored.** Fixing (1)
   surfaced that `Notification` already carries `payload`, `actionLink` and a
   `dedupeKey` with a UNIQUE index, built in H1.3 so a duplicate is an insert
   the database refuses rather than one the application tries to avoid. Retried
   delivery now uses it, and the refusal is caught so it cannot roll back the
   transition it was reporting.

#### Demo-data integrity after verification

Sales, sale items, payments and closings fingerprinted identical before and
after. 0 return requests and 0 reversals remain. The legacy `returns` table is
still empty and still 410 from its endpoint, proven mutation-free again.

**Reported, as required:** the run created **8 append-only audit rows** (281 →
289) which were preserved, and because `audit_logs.user_id` references them,
**3 probe users could not be deleted**. They were deactivated and renamed
`i2p9b1b04_{own,mgr,emp}_spent`. Deleting them would have required editing or
deleting audit history, which is forbidden. A future phase may prefer probe
identities that never touch audited paths, or an agreed retention rule for spent
probe users.


### 16.11 I2-CP4.1 — the returned phone is an asset, not an instant write-off

CP4 shipped `returns_cogs = 0` while a returned phone, held as `faulty`, was
excluded from every inventory figure. Together those are a **full write-off of
an asset the shop still owns**, decided before anyone has inspected the phone.
That was never approved, and §16.5's own reasoning was wrong on this point: it
argued that crediting the cost while the asset was absent from inventory would
double-count, when the correct fix was to stop the asset being absent.

#### The corrected treatment

At approval:

1. reverse the original line's **revenue** (gross refund);
2. **credit back** the line's immutable **COGS snapshot**;
3. **reinstate that same cost** as faulty/return-held inventory value;
4. keep it entirely out of sellable/available stock;
5. record the withheld **adjustments** as their own component.

```
profit effect = − gross refund + adjustments + COGS credit
```

Across a sale and its return, cumulative profit is the adjustment income alone:

| | revenue | cost | profit |
|---|---|---|---|
| sale | + gross | − cost | + gross − cost |
| return | − gross | + cost | − gross + adjustments + cost |
| **net** | | | **+ adjustments** |

That is the honest position until a later Technician/Owner inspection restores
the phone to stock, repairs it, records a partial impairment, or writes it off.
Approval must not anticipate that decision.

#### Counted once

The COGS credit and the reinstated asset are **the same money**. `returns_cogs`
is the unit's own cost; `faultyHeldValue` sums that same figure. A test asserts
the difference between the old and corrected profit effects is exactly the cost,
so neither can drift into double-counting.

#### Reporting

`inventoryValue` has always meant SELLABLE stock, and still does. Added:

| Figure | Meaning |
|---|---|
| `sellableInventoryValue` | what can actually be sold (`in_stock` only) |
| `faultyHeldValue` / `faultyHeldUnits` | owned, unsellable, awaiting inspection (`returned` + `faulty`) |
| `totalOwnedInventoryValue` | sellable + in-transit + faulty-held |

`totalStockValue` keeps its documented meaning and its guarantee that it does
not move when stock is merely travelling. "What can I sell?" must never include
a faulty phone; "what do I own?" must never exclude one — one number cannot
answer both.

`DailyRollup` gains `returns_adjustments`; `DailyClosing` gains
`total_return_adjustments` and `total_returns_cogs_credited`. All positive
magnitudes, added or subtracted explicitly.

#### Migration `0037`

Additive and rerun-safe (guarded `information_schema` probes through prepared
statements, as `0036`). Backup
`~/erp-backups/phonestore-i2cp41-20260815-030708.sql` — 330 019 bytes, 58 tables,
6 triggers, 0 raw `_binary`. Proven on a restored copy, a rerun of it, a clean
build of all 36 migrations (0001–0037, 0005 unused), and dev; reverse SQL executed; `prisma_p41` and
`prisma_c41` dropped; sanitised copy removed. Dev unchanged: sales 7 / 10 051.00,
units checksum `2a1dc9bf284afde32b402ad108d38a76`.

**Backend 66 suites / 956 tests.**

#### Technical debt recorded, not fixed here

The global exception filter reports **every** `PrismaClientValidationError` as
`"Invalid query parameters"`, whatever the cause. It cost real debugging time in
CP4 when the notifier wrote a field that did not exist on `Notification`.
Deliberately not redesigned — I2 is not the phase to rework the global filter.


### 16.12 I2-CP5 and CP6 — the mobile workflow, and the green run

Mobile `c7dfadc`. **Phase I2 is complete.**

#### Screens and routes

| Route | Purpose |
|---|---|
| `/returns` | branch-scoped, keyset-paged list; SQL search by invoice, IMEI, serial; status filters |
| `/returns/new` | one shared request form, reached by scan, manual IMEI, or from a sale line |
| `/returns/[id]` | detail, timeline, money, and every role-gated action |

Plus `CustodySheet` (intake) and `InvestigationSheet` (responsibility, notes,
draft adjustments). The Returns entry appears in **More** for `return.view`.

#### What the screens will and will not say

Every figure is labelled **provisional** until approval and **agreed** after it.
An approved return shows *"Refund due — payment has not yet been confirmed"*
beside *"The phone is held and is not for sale."* The word **"refunded" appears
nowhere in I2**, because nothing has been: this milestone records an obligation,
and I3 pays it.

`approved_refund_due` is toned `info`, not `success`. Nothing good has finished
happening — the shop now owes money it has not paid, and green reads as
"settled" to somebody glancing at a list.

Cost shows **"Hidden"** when `cost.view` gated it, never `0`: an absent field
and a zero cost are different facts.

Status comes from the shared registry, so a colour without words is not
expressible. Adding the three return domains was a **type error** until their EN
and AR strings existed — 871 keys each side, verified equal.

#### Actions are gated twice

Permission **and** lifecycle. A reachable route never implies an available
decision: Approve is disabled until the phone is physically held; customer-caused
damage warns that only the Owner can approve it *before* a manager tries; the
Owner exception path demands a written reason and never falls back to a normal
approval. A 409 is never retried — it means the server already decided, so the
screen refreshes and shows the outcome that won.

One `clientUuid` per logical request, reused across retries, so a flaky
connection cannot turn one complaint into two claims.

"Request return" appears on a sale line **only for serialized items** —
an accessory has no unit to present, and inventing an independent quantity
return is exactly what §16.4 says cannot be inferred.

#### CP6 — the live run

**74 checks passed, 0 failed** against real MySQL over real HTTP. The earlier
62/63 run predated CP4.1 and does not count; this run replaces it.

Covered: employee request with customer custody and with store intake · exact
IMEI matching and mismatch refusal · idempotent replay · changed-payload 409 ·
duplicate active claim refused · manager investigation · draft adjustment
create/remove · server-calculated totals · adjustments over gross refused ·
negative adjustment refused · stale-version 409 · employee refused
review/approve/adjust · manager refused an out-of-policy approval · Owner
refused without a reason, then approving with one · exactly one reversal · second
approval refused · approved return not then rejectable · returned phone refused
for sale · malformed and unknown ids · legacy endpoint still 410 and
mutation-free · list paging, `?limit=` conversion, search and filters.

**Accounting proved against the database:**

| Claim | Result |
|---|---|
| gross refund = immutable line revenue | ✅ |
| COGS credit = immutable line cost | ✅ |
| net = gross − adjustments | ✅ |
| profit effect = − gross + adjustments + COGS credit | ✅ |
| adjustments counted exactly once | ✅ |
| rollup records gross, adjustments and COGS separately | ✅ |
| unit becomes `faulty`, cost preserved not zeroed | ✅ |
| returned phone excluded from sellable stock | ✅ |
| faulty-held inventory carries that cost | ✅ |
| sale, sale items, payments, closings byte-identical | ✅ |

#### Verification identities — reused, not multiplied

The three probes the CP4 run could not delete (`audit_logs.user_id` references
them, and audit history is append-only) were **reused**: reactivated, given a
password that existed only in the process, exercised, then returned to
deactivated spent state. **No new permanent identity was created.** Total users
remains 9 — six demo, three spent probes.

#### Demo-data integrity after CP6

Sales **7 / 10 051.00**, units checksum
**`2a1dc9bf284afde32b402ad108d38a76`**, unit statuses back to `in_stock=3,
sold=8`, 0 return requests / reversals / adjustments, notifications back to
**41**. Audit grew **289 → 305**: 16 append-only rows from legitimate
verification, preserved and reported. The demo Owner password was not touched.

#### Still device-only

Camera scanning of a phone's `*#06#` display, haptics, bottom-sheet gestures,
Arabic **visual** RTL and keyboard behaviour are unverified by anything but a
type checker, a linter and a web export. `docs/24` §9e lists them.


---

## 17. I3.0 — the audit before refund settlement (2026-08-15, CLAUDE-B)

The conclusion first, because it decides the shape of everything else:

> **An outgoing refund CANNOT reuse `Payment`, and MUST NOT.** It can and should
> reuse `ReceivingAccount`. A new, additive `RefundPayout` model represents the
> settlement. No stop condition was triggered.

### 17.1 `Payment` is strictly incoming sale money

```prisma
model Payment {
  saleId  Bytes  @map("sale_id")   // REQUIRED, not nullable
  method  PaymentMethod
  amount  Decimal
  sale    Sale   @relation(...)     // REQUIRED
}
```

Two independent reasons it cannot carry a refund:

1. **Every payment belongs to a sale.** A refund has no sale of its own — it
   reverses a line of an existing one. Attaching a refund row to the original
   sale would make that sale's payment history untrue, and the original sale is
   immutable by decision.
2. **Its only consumer treats it as income.** `closing.service.ts` computes
   `expectedCash` as `SUM(amount) WHERE method = 'cash' AND sale.branchId = …`.
   A refund row would be counted as **cash the shop received**, which is the
   exact inversion of what happened. A negative amount would be worse: it would
   silently flip the sign of a table every other reader assumes is positive.

**Decision: `Payment` is untouched.** Refund settlement gets its own model.

### 17.2 `ReceivingAccount` is a channel label, and is safely reusable

It carries `provider`, `providerName`, `label`, `isActive`, `sortOrder` — and
**no balance, no credentials, no token, no direction**. It is the answer to
"which channel did the money move through?", which is the same question in both
directions.

Its own comment already anticipates this:

> *"Deactivated rather than deleted, so past transactions keep pointing at a real
> account once money movement is recorded against it."*

**Decision: reuse it.** Building a second account/settings system for outgoing
money would duplicate the Owner's configuration, and two lists of the same
accounts drift the moment one is edited.

The label is additionally **snapshotted onto the payout at confirmation**, so a
receipt printed months later still reads what the employee actually chose, even
if the Owner has since renamed or deactivated that account.

### 17.3 Reconciliation: where the money and the profit each belong

The two dates are already separate, and I3 keeps them that way:

| | Approval date (I2) | Confirmation date (I3) |
|---|---|---|
| revenue reversal | ✅ | — |
| adjustment income | ✅ | — |
| COGS credit | ✅ | — |
| profit effect | ✅ | **none** |
| refund liability | **created** | **settled** |
| cash / account outflow | — | ✅ |

**Confirmation creates no second profit effect.** Profit was reversed at
approval; paying the money out is a balance-sheet movement, not a new loss.
Subtracting it again is the "double-counting" the brief warns about, and it is
the single easiest thing to get wrong here.

`expectedCash` in `closing.service` must therefore become *cash in − cash
refunds confirmed out* for that day. That is an additive change to one formula.

### 17.4 The receipt path already exists

`mobile/lib/receipt.ts` renders HTML → PDF via `expo-print` and hands it to
`expo-sharing`. It is 80 mm wide, RTL-aware through `isRtlLanguage`, escapes
user data, and **persists nothing** — the PDF is generated on demand and shared.

**Decision: reuse it.** A refund receipt is the same pipeline with different
content and a different title. Nothing is persisted server-side either: the
receipt is a projection of the confirmed payout, so it can always be regenerated
and can never drift from the record.

There is no separate receipt-numbering system — a sale receipt is identified by
its `invoiceNo`. A refund receipt therefore references the **original invoice
number** plus the return's own id, which is already stable and unique.

### 17.5 What the reports must distinguish

Four distinct states, and today nothing separates the last three:

| State | Meaning |
|---|---|
| refund **approved** | I2 wrote the reversal; profit already reversed |
| refund **due** | approved and not yet settled — an outstanding liability |
| refund **reported** | an employee says the money was handed over |
| refund **confirmed** | a manager or owner agrees it was |

Only the fourth is authoritative. The reporter's word is a claim; the confirmer's
is the record. That separation is the entire point of the phase, and it is why
`reported_pending_confirmation` must never be styled or worded as settled.

### 17.6 Consequences for the design

1. New `RefundPayout` model — one per approved `ReturnRequest`, with
   `clientUuid` + fingerprint idempotency, `version`, and lifecycle
   `reported_pending_confirmation → confirmed`. `Payment` untouched.
2. `ReceivingAccount` reused as the channel, with its label snapshotted at
   confirmation.
3. Two narrow permissions: `refund.report` (all three store roles) and
   `refund.confirm` (Owner and Store Manager only).
4. Amount is **not** client-authored: it is validated to equal the immutable
   `net_refund_due` from the I2 reversal.
5. `expectedCash` becomes cash in − confirmed cash refunds out, on the
   confirmation day only.
6. Confirmation on a locked day is a 409 — the same rule approval already obeys.
7. The refund receipt is generated on demand from the confirmed payout, never
   persisted, and carries no cost, margin or internal id.



---

## 20. I3 CP5–CP7 — the refund payout on the phone, and what proved it

### 20.1 The workflow, as a person experiences it

| State | What the screen says | Who acts |
|---|---|---|
| `approved_refund_due`, no payout | **"Refund due — payment has not yet been confirmed"**, warning tone | Owner, Manager, **Employee** may report |
| reported, unconfirmed | **"Waiting for Manager or Owner confirmation"**, warning tone | Owner/Manager may correct or confirm; Employee sees it read-only |
| confirmed | **"Refund confirmed"**, success tone, receipt offered | nobody — it is the record |

**Only the confirmed state is ever green.** The phone stays `faulty` and not
for sale in all three, and every state says so.

### 20.2 Permissions

`refund.report` — Owner, Manager and Employee. `refund.confirm` — Owner and
Manager. Holding the first never implies the second: handing money over and
vouching that it happened are different authorities. The route is reachable by
anyone with `return.view`; **route visibility never implies mutation
authority**, and the server refuses regardless — proved live, an Employee
confirming gets **403**.

### 20.3 Money, and the three timings

Locked to the immutable net refund due, with no partial payout. Method is
`cash` or `account` **only** — the DTO accepts nothing else, so the app offers
nothing else rather than inventing an "Other" the backend would refuse.

- **approval date** — profit reverses, the liability appears
- **report date** — a workflow event. **No cash moves and the liability does not
  change.** Proved live.
- **confirmation date** — cash leaves, the liability settles, and there is **no
  second profit effect**. Proved live: profit effect 150 → 150 across
  confirmation.

Expected cash = cash taken that day − confirmed cash refunds, **subtracted
once**. Proved live: with nothing sold that day and a confirmed cash refund of
1 000, expected cash was **−1 000**, not −2 000, and re-reading it did not
subtract again.

### 20.4 Account snapshots

The label is captured at report time and frozen at confirmation. Reporting needs
an **active** account; confirming does not, so retiring an account cannot strand
a refund already owed. Proved live: after renaming *and* deactivating the
account mid-flight, the payout kept its original label and stayed confirmable,
and the receipt still shows the label the payout was made under.

### 20.5 The receipt

Generated **only** from `GET /returns/:id/refund/receipt`, which is a 409 until
confirmed — so a receipt cannot exist for money nobody has vouched for. Same
`expo-print` → `expo-sharing` path as the sale receipt, no new dependency, no
persistence beyond the temporary file handed to the share sheet.

Carries: store identity, "Refund Receipt", the stable reference
`R-<invoice>-<short id>`, the original invoice, the server confirmation time,
product and exact variant, the identifier **masked to its last four** as sale
receipts do, gross, every adjustment, the deduction total, the net returned, the
method/account snapshot, an optional transaction reference, and the confirmed
status.

Carries none of: cost, margin, internal ids, permissions, audit metadata, or any
claim that a bank or provider verified the transaction — **the app never spoke
to one**. All dynamic text is HTML-escaped; direction follows the language.

### 20.6 Verification — 55 live checks, 0 failures

Two runs against a **separate backend on port 3111** and real MySQL, reusing the
three spent probes rather than creating identities.

**Lifecycle, 47/47** — request · custody · investigation · adjustment ·
approval · reversal with gross/adjustments/COGS/net · liability created ·
Employee reports · duplicate report replays without paying twice · changed
payload 409 · a pending report moves no cash and stays owed · Employee
confirmation 403 · Manager correction with a label snapshot and an unchanged
amount · stale correction 409 · rename/deactivate does not rewrite or strand ·
stale confirmation 409 · Owner confirmation · liability settles exactly once ·
cash moves on the confirmation day · no second profit effect · the phone stays
faulty · the receipt's contents and its cost-free payload · duplicate
confirmation safe · cross-branch refused without disclosure · malformed and
unknown ids · notification dedupe · the legacy endpoint still **410** and
mutation-free.

**Expected cash and a locked day, 8/8** — including confirming into a closed day,
refused with **409** and the payout left pending rather than half-settled, with
the closing not reopened.

### 20.7 One real defect the lifecycle found

`money.provisional` was hardcoded `true`, so an approved return described its
own immutable, already-reversed figures as provisional. The I2 screen derived
its wording from `status` instead and was never wrong to a user, which is why
nothing noticed — but I3's refund screens read the money block directly. Fixed,
extracted into `isProvisionalMoney()` and given tests.

**Four other first-run failures were the verification script's own errors**, not
defects: a guessed `responsibility` enum, a missing `exceptionReason`, the wrong
reversal cost column, and the wrong legacy route. They are recorded because a
verification script lies as readily as the code it checks.

### 20.8 Not verified, and not claimed

**Nothing was exercised on a physical device or in a visible browser.** Camera,
haptics, native share, the PDF's appearance, bottom-sheet gestures and Arabic
**visual** RTL are unverified. `docs/24` §9f lists them.

The mobile screens were verified by TypeScript, lint, a web export that renders
every Return route, EN/AR key parity and pure Node tests over the receipt
builder — **not by tapping through them**.
