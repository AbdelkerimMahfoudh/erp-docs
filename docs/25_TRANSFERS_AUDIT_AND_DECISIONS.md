# 25 — Transfers: audit, findings and workflow decisions (H0)

> **Read-only audit.** No application code, schema, permission or transfer
> behaviour was changed. Everything below is what the code **does today**, traced
> from source and confirmed against the running API — not what any document says
> it should do.
>
> **Status: §8 answered · H1.1 SHIPPED (`0030`) · H1.2 SHIPPED (`0031`, `0032`).**
> Every defect this audit found is now closed. §4.1, §4.2 and the idempotency gap
> in §7 were fixed in H1.1; **the permission gap in §3 is fixed in H1.2**, which
> replaced the blanket `unit.transfer` with six stable keys and added the
> approval lifecycle. The sections below are kept as the original audit — struck
> findings are marked FIXED rather than rewritten, so the record of what was
> actually wrong survives.

---

## 1. What exists today

Transfers move **store-owned serialized units between branches of one company**.
That is the whole feature. It shipped as "Sub-phase 2C" and has not been revised
since.

| Piece | State |
|---|---|
| `StockTransfer` / `TransferItem` models | Present |
| `TransferStatus` enum | `ready_to_ship · in_transit · received · cancelled` |
| API routes | 5 mutating + 2 read + 1 settings |
| Serialized units | Supported |
| **Quantity stock** | **Not supported — see §5** |
| **Approval step** | **Does not exist — see §3** |
| **Mobile UI** | **Does not exist at all — see §6** |
| Backend tests | 2 files, 6 tests: the state-machine table and the discrepancy helper. **No service, authorization or lifecycle test.** |

The enum carries a comment naming `draft`, `pending_approval` and `rejected` as
"future (design-only)". They were never built.

---

## 2. The real lifecycle

Traced from `transfers.service.ts`, not from the design note.

```
                    ┌──────────────────┐
   POST /transfers  │  ready_to_ship   │  created directly — there is no draft
   (source branch)  └────────┬─────────┘  and no approval
                             │
        POST :id/ship        │            POST :id/cancel
        (source branch)      │            (source branch)
                             ▼
                    ┌──────────────────┐  POST :id/cancel
                    │    in_transit    │──────────────────►┌───────────┐
                    └────────┬─────────┘  (source branch)  │ cancelled │
                             │                             └───────────┘
   POST :id/receive/confirm  │            terminal — no reopen, no reversal
   (destination branch)      ▼
                    ┌──────────────────┐
                    │     received     │  terminal
                    └──────────────────┘
```

`POST :id/receive/preview` is a **read-only discrepancy report**. It mutates
nothing and is the only "dry run" in the feature.

### Transition table

| From → To | Endpoint | Permission | Branch required | Inventory effect | Still sellable? | Audit | Notification | Idempotent | Reversible |
|---|---|---|---|---|---|---|---|---|---|
| — → `ready_to_ship` | `POST /transfers` | `unit.transfer` | active = **source** | **none** | **yes** | yes | no | **no** | via cancel |
| `ready_to_ship` → `in_transit` | `POST :id/ship` | `unit.transfer` | active = source | `Unit.status → in_transit` | **no** | yes | yes → destination branch | no | via cancel |
| `in_transit` → `received` | `POST :id/receive/confirm` | `unit.transfer` | active = **destination** | `Unit.status → in_stock`, **`Unit.branchId → destination`** | yes | yes | yes → destination branch | no | **no** |
| `ready_to_ship` → `cancelled` | `POST :id/cancel` | `unit.transfer` | active = source | none | yes | yes | no | no | **no** |
| `in_transit` → `cancelled` | `POST :id/cancel` | `unit.transfer` | active = source | `Unit.status → in_stock`, branch rewritten to source | yes | yes | no | no | **no** |

Reads (`GET /transfers`, `GET /transfers/:id`) carry **no `@RequirePermissions`
at all** — any signed-in user of the company may list and open transfers. They
are still tenant-scoped, so no cross-company leak.

---

## 3. Permission findings — the headline

**Every mutating transfer route is guarded by the single permission
`unit.transfer`, and all three store roles hold it.** ✅ **FIXED in H1.2
(`0031`).** `unit.transfer` is revoked from both store roles and guards no
route; the six `transfer.*` keys replaced it. Verified live: an employee holds
`request`/`ship`/`receive`/`cancel_own` and is refused `approve` and general
`cancel`.

Confirmed from the role matrix in the database:

| Role | `unit.transfer` |
|---|---|
| Owner | ✅ |
| Store Manager | ✅ |
| **Store Employee** | ✅ |

Confirmed live against the running API. Each mutating endpoint was aimed at a
**non-existent transfer id**, so the guard's answer is unambiguous and nothing
moved: `403` = denied, `404` = guard passed.

| Actor | create | ship | receive/preview | receive/confirm | cancel |
|---|---|---|---|---|---|
| Owner (assigned branch) | allowed | allowed | allowed | allowed | allowed |
| Store Manager (assigned branch) | allowed | allowed | allowed | allowed | allowed |
| **Store Employee (assigned branch)** | **allowed** | **allowed** | **allowed** | **allowed** | **allowed** |
| Store Employee, **unassigned** branch | 403 | 403 | 403 | 403 | 403 |
| Store Employee, **no active branch** | 403 | 403 | 403 | 403 | 403 |
| Store Employee, forged branch id | 403 | 403 | 403 | 403 | 403 |
| Deactivated user | cannot log in — `401 Invalid credentials` | | | | |

### So: can a Store Employee run the whole lifecycle alone?

> ✅ **No longer.** H1.2 added `pending_approval`, and an employee cannot
> approve — proven live, including an employee assigned to **both** branches who
> still cannot self-approve. What follows is the original finding.

**Yes — within one branch pair, if assigned to both branches.** They can create,
ship, receive, confirm and cancel. There is no second pair of eyes anywhere in
the flow, and no approval state exists to require one.

The one real constraint is **branch assignment**, and it is enforced properly:
ship and cancel demand the active branch be the **source**; receive demands it be
the **destination**. An employee assigned to only one branch therefore cannot
complete a round trip by themselves — they can send, but someone at the other end
must receive. **An employee assigned to both branches can do everything alone.**

This is the gap the brief anticipated, now measured rather than assumed.

### What is correctly fail-closed

- Cross-company destination → **404 "Destination branch not found"**. The tenant
  client scopes the lookup, so another company's branch simply does not resolve.
- Transfer to the same branch → `400`.
- Unknown identifier, sold unit, unit in another branch → `400 "Some units cannot
  be transferred"` with a per-identifier reason.
- No active branch → `403`, because `unit.transfer` is branch-scoped and the
  no-branch resolution path returns company permissions only.

---

## 4. Serialized-unit behaviour, and the pricing invariant

### Eligibility, checked at create

`status === 'in_stock'` **and** the unit is at the active branch. Sold, faulty,
in-transit and other-branch units are all rejected with a reason.

### Two real defects

**4.1 — Creating a transfer reserves nothing.** ✅ **FIXED in H1.1 (`0030`).** After `POST /transfers` the unit
is still `in_stock` at the source branch and **fully sellable**. Verified live:
a unit sitting in an open transfer resolved normally through the pricing endpoint
with `status=in_stock, canPrice=true`. Someone can sell a phone that another
member of staff has already promised to a different branch. The clash only
surfaces later, at `ship`, as "Some units are no longer in stock at this branch".

**4.2 — Two open transfers can claim the same unit.** ✅ **FIXED in H1.1.** Verified live: with one
`ready_to_ship` transfer already holding a unit, a second create for the same
unit returned **`201 Created`**. Nothing prevents it, because nothing is
reserved. The first `ship` wins; the second fails late.

Also noted: duplicate identifiers **inside one request** are silently deduplicated
(`new Set`) and accepted with `201` rather than reported.

### The CP3 pricing invariant — verified intact

| Requirement | Result |
|---|---|
| Requested / shipped but not received must **not** drop the price override | ✅ Nothing in `create` or `ship` touches pricing |
| Completed receipt invalidates it **atomically** with the branch move | ✅ `invalidateOnBranchMoveTx` runs inside the same `$transaction` as the `Unit.branchId` write |
| The old unit price never follows the phone | ✅ The row is **deleted**, and resolution additionally requires the override's `branchId` to match |
| A returning phone must not resurrect the old price | ✅ Deletion, not a flag — proven live in CP3 |
| History identifies the system invalidation | ✅ `initiator='system'`, `reason='branch_transfer'`, previous price preserved |
| A failed/rolled-back transfer preserves the override | ✅ Same transaction, so both roll back together |

`receiveConfirm` is the **only** production path that changes `Unit.branchId`.
`cancel` writes the source branch back to where the unit already was, and the
pricing helper skips that no-op.

---

## 5. Quantity stock — a product gap

**Quantity-tracked products cannot be transferred at all.**

`CreateTransferDto` accepts only `identifiers: string[]` (IMEI/serial). There is
no product id, no quantity, and no code path that reads or writes `StockItem`
during any transfer operation.

The schema half-anticipates it — `TransferItem` already has nullable `productId`
and a `quantity` column defaulting to `1` — but the API only ever writes
`unitId` with `quantity: 1`. Those columns are dead today.

So none of the quantity questions in the brief (partial quantities, reservation,
double-ship races, source decrement timing, destination `StockItem.price`, cost,
cancellation restore, over-transfer) have an implementation to audit. **They are
design decisions, not findings.** See §8, question 3.

---

## 6. Mobile — nothing exists

| Surface | State |
|---|---|
| Transfer list / history | **Absent** |
| Transfer detail | **Absent** |
| Create / ship / receive / cancel screens | **Absent** |
| Any call to `/transfers` | **None** |
| `qk.transfers` query key | Present, **unused** — same pattern as the notifications key before CP4.5 |
| Transfer **status** labels (EN + AR) and tones | Present in `lib/design/status.ts` and both catalogues |
| `transfer.incoming` / `transfer.received` notifications | **Render** in the CP4.5 Notifications screen |

So the backend emits transfer notifications that an Owner can now see, and
tapping one has nowhere useful to go. Everything else is groundwork only: no
screen, no dead route, no prototype.

---

## 7. Atomicity, idempotency and crash windows

Each of `ship`, `receiveConfirm` and `cancel` wraps its writes in one
`$transaction`, so unit status, transfer status, audit rows and (on receive)
price invalidation commit or roll back together. `create` is likewise
transactional across the transfer, its items, the number and the audit row.

**There is no idempotency anywhere in the feature.**

| Risk | Present? | Note |
|---|---|---|
| Transfer created but items not attached | No | one transaction |
| Unit moved but transfer status unchanged | No | one transaction |
| Received but override not invalidated | No | same transaction (CP3) |
| **Duplicate retry creates a second transfer** | **Yes** | no client request id, no unique key — a flaky connection on Send produces two transfers |
| **Two transfers claim the same unit** | **Yes** | §4.2, verified live |
| **A pending transfer's unit is sold underneath it** | **Yes** | §4.1, verified live |
| Concurrent receive vs. receive | Partly | both enter the transaction; the state machine rejects the second, but there is no row lock or version — under real concurrency this is a race, not a guarantee |
| Concurrent cancel vs. receive | Partly | same |

Sales solved exactly this with a client-generated `clientUuid` plus a
company-scoped unique key. Transfers has no equivalent. **The operation that
needs one first is `POST /transfers`**, then the three transitions.

`stock_transfers` has `@@unique([fromBranchId, transferNo])`, which protects the
human-readable number — not the operation.

---

## 8. Decisions — ANSWERED by the user (2026-08-07)

**The user chose Option A**, plus the three answers below. These are now approved
product decisions and govern H1.

| # | Decision | Answer |
|---|---|---|
| 1 | Who may create/approve/ship/receive/cancel | **Option A** — Employee requests · Manager/Owner approves · source ships · destination receives · Manager/Owner cancels after shipment |
| 2 | No Manager present | **The Owner may approve remotely** — approval is never blocked by who is physically in the shop |
| 3 | Quantity accessories transferable | **Yes — included in H1** |
| 4 | When stock stops being sellable | **At request** — reserved as soon as it is promised |

Remaining questions below are smaller and can be settled during H1 design rather
than before it.

1. **Who may create, approve, ship, receive and cancel?** Today all three roles
   can do all five. *(Recommend: Employee creates and ships; Manager/Owner
   approves; destination user receives; Manager/Owner cancels after shipping.)*
2. **What happens when a branch has no Manager present?** A hard approval
   requirement can strand stock. *(Options: Owner can always approve remotely ·
   a timeout auto-approves · small shops configure approval off.)*
3. **Should quantity accessories be transferable?** They cannot be today. This is
   the single biggest scope question in H1.
4. **When does stock stop being sellable — request, approval, or shipment?**
   Today: only at shipment, which is why §4.1 exists.
5. **At the destination, should the price be inherited, kept, or fall back?**
   Today the override is deleted and the destination's own branch price (or the
   company default) applies. *(Recommend: keep as is — it matches CP3.)*
6. **May a transfer be partially received?** Today it is all-or-nothing: unmatched
   units silently stay `in_transit` while the transfer becomes `received`.
7. **Is a reason required for cancellation or rejection?** Today: no reason field
   exists anywhere.
8. **Which transitions notify the Owner in-app?** Today only ship and receive
   notify, and they notify the **branch**, not the Owner.
9. **Should history be grouped Pending / In transit / Received / Cancelled?**
10. **Is a photo required at shipping or receipt** — required, optional, or not at
    all? No attachment mechanism exists for transfers today.

---

## 9. Workflow options

### Option A — request and confirmation separation ✅ **CHOSEN**

Employee requests → Manager/Owner approves → source ships → destination reports
receipt → Manager/Owner confirms the inventory movement. Cancellation after
shipping is Manager/Owner only. The same person should not both initiate and
give final confirmation **when another authorised user is available**.

- **Actions:** 4–5
- **Fraud/error risk:** low — separates who asks from who confirms
- **Small shops:** workable, provided the fallback in question 2 is answered
- **One employee present:** blocked at approval unless the Owner can approve
  remotely — this is exactly why question 2 matters
- **Destination confirmation:** yes
- **Permissions:** split `unit.transfer` into `transfer.request`,
  `transfer.approve`, `transfer.ship`, `transfer.receive`, `transfer.cancel`
- **Migration size:** medium — 3 enum values, approval/rejection columns, reason,
  a permission split with a backfill, new endpoints

### Option B — Manager/Owner only *(not chosen)*

Only Manager or Owner may create, ship, receive or cancel.

- **Actions:** 3
- **Fraud/error risk:** lowest
- **Small shops:** poor — employees do the daily stock moves in practice
- **One employee present:** completely blocked
- **Destination confirmation:** yes
- **Permissions:** revoke `unit.transfer` from Store Employee (one seed/migration change)
- **Migration size:** small

### Option C — employee operational flow with Owner visibility *(not chosen)*

Employees execute every transition; the app compensates with strong audit records
and immediate Owner notifications.

- **Actions:** 3
- **Fraud/error risk:** **highest** — one person can move stock end to end, which
  is roughly today's behaviour plus alerting
- **Small shops:** fastest
- **One employee present:** fully unblocked
- **Destination confirmation:** still required (someone must receive)
- **Permissions:** unchanged
- **Migration size:** smallest — notifications and audit only

---

## 10. What the answers mean for H1

### The lifecycle the decisions produce

```
  request            approve                 ship              receive
  (Employee,      (Manager/Owner,         (source)         (destination)
   source)         source branch)
      │                  │                     │                  │
      ▼                  ▼                     ▼                  ▼
pending_approval ──► ready_to_ship ──►    in_transit    ──►    received
      │                  │                     │
      │ reject           │ cancel              │ cancel (Manager/Owner only)
      ▼                  ▼                     ▼
   rejected          cancelled             cancelled
```

**Stock is reserved at `pending_approval`** — the moment it is promised — and
released on `rejected` or `cancelled`.

### Two findings that shrink the work

**Serialized reservation needs no enum migration.** `UnitStatus.reserved`
already exists, is unused, and `unit-state-machine.ts` already permits
`in_stock → reserved` and `reserved → in_stock`. Better still,
`SalesPolicyService.assertSellable` requires `in_stock`, so a reserved unit is
**already unsellable** — decision 4 is enforced the moment transfers start
setting the status.

*One caveat to settle in H1:* the state machine also allows `reserved → sold`,
which Sell refuses. Those two disagree today with no practical effect; H1 should
make them agree rather than leave a latent contradiction. And if hold-for-customer
is built later, it will need to be distinguishable from a transfer reservation —
either a reason column or a separate status.

**Quantity reservation has no primitive at all.** `StockItem` has `quantity` and
nothing else, so decision 3 + decision 4 together require a new
`reservedQuantity` column, with sellable quantity becoming
`quantity − reservedQuantity` everywhere stock is checked. That is the single
largest piece of H1 and it touches Sell.

### Decision 2, made precise

"The Owner may approve remotely" does **not** mean weakening branch scoping.
Approval requires `transfer.approve` **in the source branch**; an Owner is
assigned to every branch, so they can approve by selecting that branch from
anywhere. Nothing needs a cross-branch escape hatch, and the branch rules that
already work stay exactly as they are.

### Still open, but small enough to settle during H1

- **Destination price on receipt** — the CP3 rule already governs: the unit
  override is deleted and the destination's own branch price or the company
  default applies. For **quantity** stock this is new: the destination
  `StockItem` must **not** inherit the source's price. Recommend it follows the
  same rule — destination price, else company default.
- **Destination cost on receipt (quantity only).** Genuinely undecided. Moving 10
  cables worth 4.10 into a branch holding 5 at 5.00 needs a rule: weighted
  average, or carry the source cost. This affects margin, so it is a real product
  decision, not an implementation detail.
- Partial receipt, cancellation/rejection reasons, which transitions notify the
  Owner, history grouping, and shipment photos — all listed in the questions above
  and none block the schema.

## 10b. H1.1 — what shipped (migration `0030`)

**Reservation begins at request.** A transfer request moves every unit
`in_stock → reserved` in the same transaction that creates the transfer. Sell
and Pricing already required `in_stock`, so a promised phone stopped being
sellable and stopped being priceable for free.

**One active claim, arbitrated by the database.** The claim is a compare-and-swap
— `updateMany` with `status: 'in_stock'` in the WHERE. MySQL takes a row lock
for the UPDATE and holds it to commit, so a concurrent request blocks, re-reads a
row that is already `reserved`, and matches nothing. Exactly one transaction can
see the unit as `in_stock`. An application-level "is it free?" read could never
promise that: true when checked, false when acted on.

**Idempotency.** `clientUuid` is mandatory, stored with a payload fingerprint
under `UNIQUE (company_id, client_uuid)`. Replay returns the original; a
different payload under the same key is 409; identifier order is normalised;
duplicates inside one request are now **reported** rather than silently
deduplicated.

**Quantity availability.** `StockItem.reservedQuantity` with two CHECK
constraints — non-negative, and never above physical. `quantity` remains the
PHYSICAL total and is deliberately never reduced to express unavailability,
because reserved goods are still company-owned and still count in valuation.
Available to sell is `quantity − reservedQuantity`. H1.1 does **not** create
quantity transfer lines; this is the foundation H1.4 will use.

**State machine corrected.** `reserved → sold` is now illegal, matching
`assertSellable`, which always refused it.

### Two defects the live races found that code review had not

| Found | Fix |
|---|---|
| **Sell and a transfer request both returned 201.** Sell's unit write was a blind update, so a transfer reserved the phone between `assertSellable` and the write, and the sale stamped it `sold` anyway — a phone simultaneously sold and promised, both callers told "success" | Sell now CLAIMS the unit with a compare-and-swap on `in_stock`; the loser gets a clear 409 |
| **Concurrent identical requests:** the loser reported a conflict for work that had in fact succeeded, because only `P2002` was treated as a race — the reservation swap can lose first | Both failure paths now look up the request id and return the winner's transfer |

**Race suite: 32/32** against the running API and real MySQL, covering both
races above, replay, reordering, cross-payload 409, missing key, cancel release,
ship/receive retries, quantity availability, the three database invariants, and
valuation being unaffected by reservation.

### Still open after H1.1

- **The permission gap is untouched.** `unit.transfer` still guards every
  transition and all three roles still hold it, so a Store Employee assigned to
  both branches can still run a transfer alone. That is **H1.2**, and it is
  recorded here as an unresolved authorization gap rather than approved
  behaviour.
- Cancellation after shipment still rewrites the unit's branch back to source
  without proof it physically returned. Recorded for H1.3.
- Quantity transfer lines, partial receipt, approval states: H1.3/H1.4.

## 10b. H1.2 as shipped — permissions and the approval lifecycle

Migrations `0031` and `0032`. Serialized only; quantity transfer execution,
partial receipt, proof photos and the mobile UI are still future work.

### The lifecycle now

```
  request              approve                ship            receive
  (transfer.request,  (transfer.approve,   (transfer.ship,  (transfer.receive,
   source branch)      source branch)       source)          DESTINATION)
        │                    │                   │                 │
        ▼                    ▼                   ▼                 ▼
 pending_approval ──► approved ──────────► in_transit ────────► received
        │  │                │
        │  └─reject────► rejected            nothing leaves in_transit
        └─cancel──────► cancelled            except received
```

**`pending_approval` and `approved` both hold their units reserved**, so H1.1's
guarantee still runs from the moment stock is promised. Only `rejected` and
`cancelled` release it.

**Nothing leaves `in_transit` except `received`.** Cancelling a shipment would
mean deciding where the goods physically are, and rewriting the unit back to the
source branch would be a guess. Return-to-source is deliberately future work.

### The permission split

| Key | Owner | Manager | Employee |
|---|:--:|:--:|:--:|
| `transfer.view` | ✅ | ✅ | ✅ |
| `transfer.request` | ✅ | ✅ | ✅ |
| `transfer.approve` | ✅ | ✅ | **—** |
| `transfer.ship` | ✅ | ✅ | ✅ |
| `transfer.receive` | ✅ | ✅ | ✅ |
| `transfer.cancel` *(breadth)* | ✅ | ✅ | **—** |
| `transfer.cancel_own` *(route)* | ✅ | ✅ | ✅ |
| ~~`unit.transfer`~~ | inert | **revoked** | **revoked** |

**The two cancel keys do different jobs**, and conflating them was a real bug
found by live verification: `transfer.cancel_own` is the **route** key (may
reach the endpoint), `transfer.cancel` is the **breadth** key (may cancel
somebody else's). `PermissionsGuard` requires ALL listed permissions, so
guarding on the broad key would lock employees out of withdrawing their own
request, and guarding on both would lock managers out entirely — which is
exactly what `0031` did until `0032` fixed it. The route takes the narrow key;
breadth stays a service decision.

**`unit.transfer` has zero production call sites.** The permission record is
kept because historical audit rows reference it. It becomes safe to delete once
no `role_permissions` row references it **and** no audit or reporting query
reads the key — neither is true today.

### Auto-approval

A requester who already holds `transfer.approve` in the source branch creates an
**approved** transfer directly, flagged `auto_approved`. Making a manager approve
their own request would be ceremony, not control, and the flag stops the audit
trail showing an approved transfer with no approver.

### Concurrency

Every transition carries `expectedVersion` and moves through one compare-and-swap
helper. Proven live: approve-vs-reject and ship-vs-cancel each produce exactly
one winner; a stale approval is 409.

### Legacy remap

`ready_to_ship` → `approved`. The only reading that invents no history: such a
row was created and could ship, which is what `approved` now means. Nothing is
marked received, and `approved_by` stays NULL with `auto_approved` false, so the
trail never claims a decision nobody made. Development held zero transfers, so
the remap was a no-op here.

### Still deferred

- **Notifications** — approval work is currently invisible: nobody is told a
  request awaits them, or that theirs was approved or refused. Deferred to H1.5
  rather than half-built here. **This is the most user-visible gap.**
- Quantity transfer execution, partial receipt, discrepancy/return-to-source,
  proof photos, mobile UI.

## 11. Proposed H1 order

1. **H1.1 — reservation + idempotency.** Fixes §4.1, §4.2 and §7. A
   client-generated request id on create, `Unit.status → reserved` at request,
   and `StockItem.reservedQuantity`. Everything else is unsafe until stock
   cannot be double-promised. **Touches Sell**, so it needs the same care as a
   pricing change.
2. **H1.2 — permission split.** `unit.transfer` → `transfer.request`,
   `transfer.approve`, `transfer.ship`, `transfer.receive`, `transfer.cancel`.
   Migration + backfill + drift test, following the `0016`–`0018` pattern where
   the matrix lives in a migration and not only in the seed.
3. **H1.3 — lifecycle states.** `pending_approval` and `rejected`, approval and
   rejection columns, reasons.
4. **H1.4 — quantity transfers.** Destination `StockItem` creation, the cost rule
   once decided, and `0029`'s version for concurrency.
5. **H1.5 — notifications and audit** for the new transitions.
6. **H1.6 — mobile transfer UI**, built last against a settled contract, reusing
   the transfer status labels and tones that already exist.
7. **H1.7 — tests.** Transfers has 6 tests covering a lookup table and a helper.
   It needs authorization, lifecycle, concurrency and pricing-invariant coverage
   before it is trusted with stock.

**Inter-store consignment remains out of scope.** Transfers move one company's
own stock between its own branches; consignment involves a separately owned
store, payment and settlement. The current model cannot express it — `companyId`
is on every row and the tenant client narrows every query — and it must not be
stretched to try. Cross-company transfer already fails closed (404); that stays.
