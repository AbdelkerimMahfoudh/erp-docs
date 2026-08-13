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

## 10c. H1.3 CP1 — the seven H1.2 requirements, reconciled

H1.2 proved its behaviour live, with real sessions against real MySQL, but left
**no standing test** for any of it — so nothing in the suite would catch a
regression, and the report never clearly evidenced Manager/Owner auto-approval
on create. CP1 re-checked all seven requirements against the code and pinned
each one in `transfer-authority.spec.ts` (**25 tests**).

**No production behaviour needed fixing.** All seven already held:

| # | Requirement | Verdict |
|---|---|---|
| 1 | Employee request starts `pending_approval` | holds — reserved, `auto_approved` false, no approver recorded |
| 2 | Manager/Owner request starts `approved` | **holds** — now evidenced: `approved_by` set, `approved_at` set, `auto_approved` true |
| 3 | Employee cancels only their own **pending** request | holds — refused for somebody else's, and refused once approved |
| 4 | Manager/Owner cancels any eligible `pending_approval` or `approved` transfer in the source branch | holds |
| 5 | Nothing cancels `in_transit`, `received`, `rejected` or `cancelled` | holds |
| 6 | An employee in **both** branches still cannot approve or reject | holds |
| 7 | Approve and cancel use version compare-and-swap | holds — stale attempts 409 and release nothing |

Two details worth recording, because they are easy to get wrong later:

- **Auto-approval is decided by the permission held in the ACTIVE branch**, never
  by a role name. The same manager requesting stock out of a branch where they
  lack `transfer.approve` produces a `pending_approval` request. This is pinned
  by a test.
- **A terminal transfer is refused by two different rules**, and which one speaks
  depends on who asks. The requester is stopped by ownership ("already been acted
  on") because it is no longer pending; a manager gets past that and is stopped
  by the state machine ("cannot become 'cancelled'"). Both are refusals and
  neither is a state change, but the messages differ by role.

### The cancel-key compromise — recorded, deliberately not redesigned

`PermissionsGuard` requires **ALL** listed permissions on a route. That single
fact forces the current arrangement:

| Key | Job | Held by |
|---|---|---|
| `transfer.cancel_own` | the **route** key — may reach `POST :id/cancel` at all | Employee, Manager, Owner |
| `transfer.cancel` | the **breadth** key — may cancel somebody *else's* transfer | Manager, Owner |

So managers hold `transfer.cancel_own` **only to pass the route guard**; it grants
them nothing they did not already have. Breadth is decided inside the service,
not by the guard.

The alternatives are both worse: guarding the route on `transfer.cancel` locks
employees out of withdrawing their own request, and guarding on both locks
managers out entirely — which is exactly what `0031` did until `0032` fixed it.

**This is a known compromise, not a defect.** A cleaner fix is an ANY-of
semantics for route permissions, but changing the global guard would alter
authorization on every route in the system, which is far outside a transfers
phase. Recorded here so the next person meets it as a decision rather than a
puzzle. **Do not "tidy" a manager's `cancel_own` grant away** — cancellation
would break for managers, and the suite pins it (`role-matrix-drift.spec.ts`).

## 10d. H1.3 as shipped — notifications and the mobile workflow

Migration **`0033`**. Serialized only. Quantity lines, partial shipment/receipt,
proof photos, consignment and WhatsApp remain out of scope.

### The notification audit, and what it found

The existing system was reused — same `Notification` model, same
`NotificationsService`, same `/v1/notifications` API, same mobile screen. No
second subsystem, and the recognition outbox was not touched.

Auditing it first turned up **a real defect that predates this phase**:

> `listForUser` scopes to `targetUserId = me OR targetUserId IS NULL`, and
> **`branch_id` is never read**. A notification with no target user is therefore
> a **company-wide broadcast**, whatever branch it names. The old
> `transfer.incoming` and `transfer.received` notifications were emitted exactly
> that way, so **every user of every branch saw them**. They were also emitted
> *after* the transaction, so a failed emit meant stock moved with nobody told.

Both transfer paths now target named people inside the transaction, which closes
it for transfers by construction. **The general defect remains** for any other
untargeted notification — see the open item below.

### Migration `0033` — two nullable columns and one unique index

| Column | Why |
|---|---|
| `dedupe_key VARCHAR(120)` | An application-level "already sent?" read is true when checked and false when acted on. `UNIQUE (company_id, target_user_id, dedupe_key)` makes the **database** reject a duplicate instead. Key shape: `transfer:<hex>:<event>`. NULLs do not collide in MySQL, so every existing notification is unaffected. |
| `payload JSON` | `title`/`body` are English text written by the server, so an Arabic shop would read English forever. Storing the **fields** lets the app compose the sentence in the reader's language, with the stored text as the fallback. Carries branch names, the reference, an item **count**, the actor and any reason — deliberately no cost, price or margin. |

Additive only. All 41 existing notifications keep working with both columns
NULL. Reverse SQL is in the migration header and was **executed** on a restored
copy: columns and index gone, every row and every business total intact.

### Who is told what

Recipients are resolved from **permissions in the relevant branch** — the same
question the guard asks — never from role names, then deduplicated, with the
actor removed.

| Event | Recipients |
|---|---|
| `requested` | source-branch holders of `transfer.approve` |
| `created_approved` | destination holders of `transfer.receive` |
| `approved` | the requester · source `transfer.ship` · destination `transfer.receive` |
| `rejected` | **the requester only** — a broadcast refusal helps nobody |
| `shipped` | destination holders of `transfer.receive` |
| `received` | the requester · source holders of `transfer.approve` |
| `cancelled` | the requester · source approvers · destination receivers |

Every notification's action resolves to `/transfers/<id>` — the exact transfer,
never a list.

### The list, counts and detail contract

`GET /transfers` was `take: 100`, no filter, no search, raw Prisma rows. It now
takes a status filter, a search term and a keyset cursor on the UUIDv7 primary
key, scoped to the active branch's two ends. **Search runs in SQL** across the
reference, both branch names, the product and the IMEI/serial.

`GET /transfers/counts` returns the three badge numbers in one grouped query.
It is declared **before** `:id`, or Nest routes it as a transfer whose id is
"counts".

`GET /transfers/:id` returns identity, branches, people, timestamps, items and —
per action — whether it is allowed, **why not**, and the branch it must be
performed from. Reason order is status → permission → branch, deliberately: a
finished transfer must not send anyone to another branch, and someone lacking
authority must not be invited to switch branches to find that out.

Detail is readable from **any branch the caller is assigned to**, so a
notification can open the transfer it is about while the app points at the other
end; the action's `branchName` is what lets the screen offer "Switch to X".

`requestedAt` is derived from the UUIDv7 key. There is no `created_at`, and
`sent_at` cannot stand in — it carries `DEFAULT now()` **and** is rewritten on
shipment, so a pending transfer's `sent_at` is a creation time wearing a
shipping label. It now reads `null` until the transfer actually ships.

### Two defects only the live run could find

1. **Recipient resolution never worked.** `holdersOf` filtered on
   `role: { permissions: … }`, but `Role` declares **`rolePermissions`**. Real
   Prisma rejected the query outright, so `POST /transfers` answered 400 for
   every request. The unit suite was green throughout, because the test double
   had been written to the same wrong assumption — it agreed with the code
   instead of with the schema. The double now **throws** on any `role` filter key
   other than `key`/`rolePermissions`.
2. **`?limit=` was a 400 for every client.** A query parameter arrives as a
   string and the global pipe runs with `enableImplicitConversion: false`, so
   `@IsInt()` alone rejected every value. Service-level tests pass a number and
   never touch the pipe. Fixed with the same explicit `@Transform` the catalog
   uses, and pinned by DTO-level tests.

### 🔴 Open, recorded rather than fixed

**Untargeted notifications are still company-wide, and a broadcast's read state
is shared.** `listForUser` ignores `branch_id`, and `markRead` sets `is_read` on
the shared row, so one person reading a broadcast marks it read for everyone.
Transfers no longer rely on that path, but `closing.completed` and any future
untargeted type still do. Fixing it means deciding what a broadcast means —
branch-scoped visibility, plus per-user read state — which is a notifications
phase, not a transfers one.

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

---

## 12. H1.4-CP1 — the quantity-stock truth, audited before any SQL

Read-only. No behaviour changed in this checkpoint. Everything below was checked
against the running API, the real schema and the live dev database rather than
inferred from the model file.

### 12a. Baseline re-proved before touching anything

The serialized workflow was re-run end to end against a **freshly started**
backend on port 3010 (no server left over from another session) with five real
sessions and its own temporary product, units and users: **29/29 checks passed.**

Reservation at request · reserved stock refused by both Sell and Pricing ·
employee `pending_approval` · manager and owner `approved` with `autoApproved`
recorded · approval reserving nothing a second time and adding no item ·
reject and cancel each releasing the reservation · shipment holding the goods
`in_transit` and still unsellable · receipt restoring `in_stock` at the
destination · the source unit-price override surviving shipment and being
**deleted** by receipt · wrong-branch ship `403` · unknown transfer `404` ·
replay returning the original transfer · the same key with a different payload
`409` · notification replay creating no duplicate.

**Four of those checks failed on the first run and none was a regression** — the
script had called a pricing route that does not exist (`PUT /pricing/unit`
rather than `PUT /pricing/units/:identifier/price`) and had reused units that an
earlier step in the same script had already reserved. Recorded because a
verification script is as capable of lying as the code it checks.

### 12b. Exact types, checked in `information_schema`

| Column | Type | Null | Default |
|---|---|---|---|
| `stock_items.quantity` | `int` | **NO** | `0` |
| `stock_items.reserved_quantity` | `int` | **NO** | `0` |
| `stock_items.cost` | `decimal(14,2)` | **NO** | — |
| `stock_items.price` | `decimal(14,2)` | **NO** | — |
| `stock_items.version` | `int` | **NO** | `0` |
| `transfer_items.unit_id` | `binary(16)` | YES | — |
| `transfer_items.product_id` | `binary(16)` | YES | — |
| `transfer_items.quantity` | `int` | **NO** | `1` |
| `products.default_price` | `decimal(14,2)` | **YES** | — |

Existing CHECKs: `transfer_items_quantity_pos_chk (quantity > 0)` ·
`stock_items_quantity_nonneg_chk` · `chk_stock_reserved_nonneg` ·
`chk_stock_reserved_le_quantity`. `stock_items` is UNIQUE on
`(company_id, product_id, branch_id)`. **`transfer_items` has no unique index at
all** — only four non-unique indexes.

### 12c. Every consumer of the quantity fields

| Consumer | Reads | Behaviour |
|---|---|---|
| `SalesService.create` | `quantity`, `reservedQuantity`, `cost`, `price` | Sellable = `quantity − reservedQuantity`; COGS from `cost`; price via `PricingService` |
| `InventoryService.upsertStock` | — | `quantity: { increment }`, **cost untouched** |
| `PurchasingService.commit` | — | `quantity: { increment }`, **cost untouched** |
| `InventoryService.list/detail` | all four | Returns physical, reserved and `availableQuantity` |
| `PricingService` / `resolveQuantity` | `price`, `version` | `stock_item` price wins whenever the row exists |
| `RollupService.recomputeInventoryValuation` | `quantity`, `cost`, `price` | `si.quantity * si.cost`, per branch, `quantity > 0` |
| `DashboardService.lowStock` | `quantity` | **Physical**, not available |
| `CatalogService` | `quantity` | Presence and totals |

### 12d. The five questions, answered

**1. Can `TransferItem.productId` / `quantity` be activated, or must they be
migrated?** **Activated.** They are dead but correctly shaped: `product_id` is
already nullable with an FK to `products`, and `quantity` is already `NOT NULL
DEFAULT 1` with a `> 0` CHECK. The live database holds **0 transfers and 0
transfer items**, so no legacy row can violate a new constraint here. *A
production database must have this audit re-run before the migration is applied.*

**2. Can one transfer carry both serialized and quantity lines?** **Yes, and
nothing in the schema objects.** Both discriminating columns are nullable on the
same table, so the mix is a row-level property. It needs a CHECK to stop a row
being both, because today nothing prevents `unit_id` and `product_id` being set
together.

**3. Can `StockItem.cost` or `price` be null?** **No — both are `NOT NULL`.**
Two consequences. Cost is always present, so §4.1's "never invent a cost" is
satisfiable by construction rather than by a runtime guard *(the guard is still
written, because a `NOT NULL` column is a promise about the schema, not about a
future migration)*. Price, however, means **an unpriced quantity row cannot be
represented**, which §4.3 case 2 requires — see 12e.

**4. Would company valuation fall while goods are shipped but not received?**
**Yes — and it already does today, for serialized transfers.**
`recomputeInventoryValuation` is keyed on `(company, branch)` and counts units
`WHERE status = 'in_stock'` and stock rows `WHERE quantity > 0`. A shipped unit
is `in_transit`, so it leaves the source total; its `branch_id` only changes on
receipt, so it never joins the destination total. **Between ship and receive it
is worth nothing to any report.** H1.3 shipped that hole; quantity lines would
widen it. §8 is therefore a fix to existing behaviour, not only new work.

**5. Does receiving already use weighted-average cost, and can it be reused?**
**No, and there is nothing to reuse.** Both intake paths —
`InventoryService.upsertStock` and `PurchasingService.commit` — do
`update: { quantity: { increment } }` and **never touch `cost`**. The first
receive into a branch sets the cost and every later receipt inherits it forever.
H1.4 will contain the project's first weighted-average implementation.

### 12e. Contradictions found, and what was done about them

**🔴 A — purchase intake does not average cost, and that is a real defect.**
Buying 50 cables at 4.10 and then 50 more at 8.00 leaves the branch cost at
4.10, so COGS is understated and margin overstated on everything sold
afterwards. This is **pre-existing, out of H1.4's scope, and not caused by
transfers**. It is recorded here rather than fixed, because changing purchase
costing is a financial change that needs its own approval and its own
verification. **After H1.4, cost will be averaged when goods arrive by transfer
and not when they arrive by purchase** — an inconsistency the shop can see, and
one that should be closed deliberately rather than silently.

**🟡 B — `stock_items.price` is `NOT NULL`, so "unpriced" cannot be stored.**
§4.3 case 2 ends in "otherwise unpriced", which today is unrepresentable. The
smallest safe additive correction is to make the column nullable and let a NULL
price fall through the existing ladder to `product_default` and then `unpriced`
— a state `PriceSource` already models. Blocking receipt to satisfy a column
would hold goods hostage to a price nobody has set, and writing `0` would invent
one. Carried into CP2.

**🟡 C — §4.3's destination `BranchVariantPrice` rung is currently unreachable.**
`resolveQuantity` never reads `branch_variant_prices`, deliberately, and the
table holds **0 rows**. The rung is implemented as specified because it is
approved and harmless, but it can only ever fire once something starts writing
branch variant prices for quantity products. Stated so a later reader does not
mistake dead code for a bug.

**None of these blocks H1.4.** B and C are handled by §4.3's own instruction to
make the smallest safe correction; A is a finding about a different feature.

### 12f. Decisions this pins for the implementation

- **Quantity line identity is `product_id`**, resolved against the transfer's
  own `from_branch_id`. `stock_items` is UNIQUE on
  `(company_id, product_id, branch_id)`, so that pair names exactly one source
  row and no ambiguity is possible. A separate `stock_item_id` column would be a
  second source of truth for the same fact.
- **Duplicate quantity lines are prevented by the database**, with
  `UNIQUE (transfer_id, product_id)`. MySQL lets NULLs repeat under a unique
  index, so serialized rows — which have `product_id IS NULL` — are unaffected.
  This is the same partial-uniqueness pattern already used for the OTP active
  key and the notification dedupe key.
- **A serialized line keeps `quantity = 1`.** The XOR CHECK is written in terms
  of which id is present, so the existing `DEFAULT 1` stays meaningful and no
  existing row needs rewriting.
- **The shipment cost snapshot cannot be a CHECK.** "Absent before shipment,
  present after" depends on the parent transfer's status, and MySQL CHECK
  constraints cannot reference another table. It is a service invariant with
  tests, and this document says so rather than implying the database enforces it.

---

## 13. H1.4-CP2 — schema, migration `0034`, and the proofs

### 13a. Backup, taken and verified BEFORE anything was altered

`~/erp-backups/phonestore-20260813-173135.sql` — `--hex-blob`,
`--single-transaction`, routines + triggers + events, no tablespaces.
**262 269 bytes · trailer `-- Dump completed on 2026-08-13 17:31:36` · 0 raw
`_binary` literals · 2 104 hex literals · 55 `CREATE TABLE` · 4 triggers · UTF-8
round-trip byte-identical.** No credential was printed or placed on a command
line.

**Restore proven before migrating**, through the documented DEFINER-safe path
(`scripts/sanitize-dump.js`, 4 definers stripped → restore as the migrator) into
`prisma_h14_pre`: **55/55 tables, 4/4 triggers with byte-identical bodies**, and
three independent binary-key checksums matching live exactly —
units `2a1dc9bf284afde32b402ad108d38a76`,
stock_items `681660e728243c70f1cc67f59b792dbe`,
sales `1e9d9c8cc20104d1a7f9182891bfd19b` — with
products/units/sales/sale_items/stock and `SUM(total) = 10051.00` all identical.

### 13b. What `0034` changes

| # | Change | Why |
|---|---|---|
| 1 | `transfer_items.shipped_unit_cost DECIMAL(14,2) NULL` | The cost the goods left with. NULL until shipment |
| 2 | `unit_id` and `product_id` FKs → `ON DELETE RESTRICT ON UPDATE RESTRICT` | See below — this one was forced, and it was also right |
| 3 | `transfer_items_line_kind_chk` | A line is serialized **or** quantity, never both and never neither |
| 4 | `transfer_items_snapshot_kind_chk` | A snapshot belongs only to a quantity line, and is never negative |
| 5 | `UNIQUE (transfer_id, product_id)` | Duplicate quantity lines refused by the database |
| 6 | `stock_items.price` → nullable | An unpriced quantity row becomes representable |

**The foreign-key change was not planned, and the database is what found it.**
The first deploy failed with MySQL **error 3823**: a CHECK constraint may not
reference a column whose foreign key carries a referential action. Both optional
relations carried Prisma's default `ON DELETE SET NULL`, so the line-kind CHECK
could not be created at all.

That default was independently wrong here, and this session had already seen it
happen: deleting a unit during fixture cleanup silently NULLed `unit_id` and
left a transfer line pointing at nothing — a movement record that has forgotten
what it moved, and under the new CHECK an invalid row. `RESTRICT` is the honest
rule for financial history: a product or unit a transfer moved may not be erased
from under it. Products are soft-deleted and units are not deleted in
production, so no legitimate workflow is blocked.

**Why `stock_items.price` became nullable.** §4.3 requires a received quantity
row to end at *unpriced* when the destination has no branch price and the
product has no default. A `NOT NULL` column left only two answers, and both are
worse than the truth: invent a price, or refuse goods that have physically
arrived. NULL now means unpriced and falls through the ladder the resolver
already models. **It is never read as zero** — see 13e.

### 13c. Deployment proofs — all four passed

| Proof | Result |
|---|---|
| **Restored pre-migration database** (`prisma_h14_pre`, **seed never ran**) | `0034` applied alone · 12 products / 11 units / 7 sales / 14 sale_items / 4 stock preserved · `SUM(total)=10051.00` · units and stock checksums **byte-identical** · 55 tables · 4 triggers |
| **Clean database from zero** (`prisma_h14_clean`) | 55 tables · 4 triggers · **33 migrations** · 3 CHECKs on `transfer_items` |
| **Existing dev database** | applied; *"Database schema is up to date!"*, 33 migrations, units checksum unchanged, **0 null prices** (no backfill) |
| **Rerun** | idempotent on both — *"No pending migrations to apply."* |

### 13d. The constraints exercised against real MySQL — 13/13

Run as SQL against `prisma_h14_pre`, because a mocked constraint only tests the
mock:

| # | Attempt | Result |
|---|---|---|
| 1 | serialized line (unit, qty 1) | accepted |
| 2 | serialized line with qty 5 | **rejected** `3819 line_kind_chk` |
| 3 | line with BOTH unit and product | **rejected** `3819 line_kind_chk` |
| 4 | line with NEITHER | **rejected** `3819 line_kind_chk` |
| 5 | quantity line (product, qty 10) | accepted |
| 6 | duplicate quantity line, same product | **rejected** `1062` on the unique key |
| 7 | a second serialized line on the same transfer | accepted — NULLs repeat under the index, as designed |
| 8 | cost snapshot on a serialized line | **rejected** `3819 snapshot_kind_chk` |
| 9 | negative cost snapshot | **rejected** `3819 snapshot_kind_chk` |
| 10 | cost snapshot on a quantity line | accepted |
| 11 | delete a unit a transfer line names | **rejected** `1451` on `transfer_items_unit_id_fkey`, and it deletes cleanly once the line is removed |
| 12 | `price = NULL` on a stock row | accepted |
| 13 | `reserved_quantity = quantity + 1` | **rejected** `3819 chk_stock_reserved_le_quantity` — `0030` intact |

*Check 11 was run twice. The first attempt was blocked by a **different** FK
(`sale_items`), which proves nothing about `transfer_items`; it was redone
against a unit with no sale history so the rejection names the intended
constraint. An inconclusive proof that looks like a pass is worse than a
failure.*

### 13e. Reverse SQL — documented in the migration and executed

The full reversal was run against `prisma_h14_pre` and returned the schema to
the `0033` shape: snapshot column gone · `transfer_items` back to its single
original CHECK · no unique index · `price` `NOT NULL` again · both FKs back to
`SET NULL` · 11 units / 7 sales / `SUM(total)=10051.00` intact.

**Two of its steps are destructive, and the migration says so rather than
implying a clean undo.** Quantity transfer lines cannot exist in the `0033`
schema at all, so reversing means deciding what happens to them — deleting them
abandons the movement they describe, and their reservations must be released
first or `reserved_quantity` is left overstating what is promised. Restoring
`NOT NULL` needs a value for every unpriced row, and `0` is written only because
the reversed column cannot hold the truth.

### 13f. The null-price fallout, fixed where types could not see it

Making a column nullable is a change every reader has to survive. TypeScript
caught three; **two more it could not, because `Number(null)` is `0` and
perfectly legal**:

- **Sell** built its price input with `Number(stock.price)`, which for an
  unpriced row would have offered the item **free**. It now passes `null` and
  lets the ladder answer — and passes the real `Product.defaultPrice`, which it
  had hard-coded to `null` back when a stock row always had a price so the
  fallback was unreachable. With neither, `SalesPolicy.resolvePrice` refuses
  with "A price is required", which is the honest outcome.
- **Inventory valuation** computed `si.quantity * si.price`, and one NULL price
  would have turned an entire product's expected revenue NULL and silently
  removed it from the total. Now `COALESCE(si.price, p.default_price, 0)`.
  **Inventory *value* is unaffected** — it is driven by cost, and the goods are
  owned whether or not anyone has priced them.

`PricingService.row()` now treats a NULL-priced row as no row at all, so the
existing precedence produces `product_default` and then `unpriced` with no new
branch in the ladder.

### 13g. Verification at this checkpoint

Backend **51 suites / 704 tests** passing (16 added by
`quantity-migration.spec.ts`) · `tsc` clean · `prisma validate` valid ·
`migrate status` up to date with **33 migrations** · **4 triggers** intact ·
demo baseline unchanged: products 12 · units 11 · sales 7 ·
`sum_total = 10051.00` · stock 4 · transfers 0 · notifications 41 · reserved 0 ·
units checksum `2a1dc9bf284afde32b402ad108d38a76`.

**Both temporary databases were dropped** (`prisma_h14_pre`, `prisma_h14_clean`)
and the sanitised dump copy deleted; the original backup is untouched.

---

## 14. H1.4 as shipped — quantity-tracked accessory transfers

Partial quantities chosen when the request is made. **Shipment and receipt stay
all-or-nothing per transfer** — partial shipment, partial receipt, discrepancy
handling and return-to-source are untouched and remain future work.

### 14a. The words, defined once

| Term | Means | Where it lives |
|---|---|---|
| **Physical** | What the branch owns and can count on the shelf | `stock_items.quantity` |
| **Reserved** | Promised to an open transfer, still owned, not sellable | `stock_items.reserved_quantity` |
| **Available** | `physical − reserved` — what may be sold or promised | derived, never stored |
| **In transit** | Shipped, not yet received. Owned by the company, held by no branch | derived from the movement |

Physical is **never** reduced to express unavailability. Reserved goods are
still company property and still count in valuation; only shipment takes
something off the shelf.

### 14b. Cost

Snapshotted from the source **at shipment**, onto `transfer_items.shipped_unit_cost`.
Not at request: a request can wait days for approval while the branch receives
more of the same thing at a different price, and what travels is the cost of the
goods that actually left. **Zero is never used for an unknown cost** — shipment
refuses with an actionable error instead.

On receipt, into an existing destination row:

```text
new cost = (physical × cost + received × snapshot) ÷ (physical + received)
```

computed **inside the UPDATE**, from the row's own committed values. With no
destination row, or a physical quantity of zero, the snapshot simply becomes the
destination cost. Full `DECIMAL(14,2)` precision is kept; **that is the
database's precision, so a repeated average rounds at two decimals** — the
worked example `(5 × 5 + 10 × 10) ÷ 15 = 8.3333` stores as `8.33`.

### 14c. Price

Branch-private, and it does **not** travel. An existing destination row keeps
its own price untouched. A new row resolves from the destination's
`BranchVariantPrice`, then `Product.defaultPrice`, otherwise **unpriced**. The
source's price is never copied and never shown to the destination.

*`stock_items.price` became nullable in `0034` to make "unpriced" expressible —
see §13b. Selling an unpriced item asks the cashier for a price rather than
quietly charging one nobody set.*

> ⚠️ The `BranchVariantPrice` rung is implemented as approved but is currently
> **unreachable in practice**: nothing writes a branch variant price for a
> quantity product, and the table holds zero rows. It becomes live the day
> something does.

### 14d. Concurrency

Every quantity operation is **one conditional SQL statement** whose WHERE clause
carries the rule:

| Operation | Condition |
|---|---|
| reserve | `quantity - reserved_quantity >= wanted` |
| release | `reserved_quantity >= amount` |
| ship | `reserved_quantity >= amount AND quantity >= amount` |
| receive | weighted average computed in the UPDATE itself |

Prisma cannot express a comparison between two columns of one row, so these are
raw statements with `company_id` written out — raw SQL does not pass through the
tenant extension. MySQL holds the row lock for the duration of the UPDATE, so a
competitor blocks, re-evaluates against the committed result, and matches
nothing. A read followed by an update could not promise this: the row is free
when you look and taken when you write.

A failed line throws, rolling the transaction back, so **a mixed request whose
last line cannot be met leaves no phone reserved and no transfer created.**

### 14e. Valuation

```text
company stock value = branch-held + in-transit
```

In-transit value is computed from the movement itself — the unit's own cost for
a serialized line, `quantity × shipped_unit_cost` for a quantity line — and
credited to the **source** branch, reported as its own figure so "held" still
means held. Only outbound is added to a total, or every movement would count
twice. It is cost-derived, so it is stripped by the same `cost.view` gating as
cost; the **counts** stay visible, because knowing ten chargers are on the way
is operational rather than financial.

**Eventual, not instantaneous.** `inventory_valuation` is a rollup refreshed
after commit — as it always has been for sales — so the invariant holds once the
refresh lands, typically within a second. Making it synchronous would be the
materially larger redesign §8 says to stop and report before attempting.

### 14f. Tests and live verification

- **Backend: 54 suites / 748 tests** (H1.3 baseline 50/688).
- **Serialized baseline re-proved 29/29** against the final build, so nothing in
  H1.1–H1.3 was weakened by adding quantity lines.
- **Quantity end to end: 44/44** live — reservation, Sell seeing less, approval
  not re-reserving, detail shape and counts, cancel and reject releasing,
  over-request refused with physical/reserved/available/requested, duplicate
  lines refused, a phone refused as a quantity line, replay and 409, weighted
  average into an existing row, all four destination-price outcomes, mixed
  atomicity, the shipment snapshot, the valuation invariant, cost gating, search,
  and a retried receive adding stock exactly once.
- **Concurrency: 18/18** against real MySQL, every check genuinely simultaneous.
  Two requests for the last stock · Sell versus Transfer · two mixed requests
  competing for one scarce line, where the loser reserved nothing at all ·
  duplicate ship · ship versus cancel · duplicate receive · concurrent replay of
  one request id · and the database invariants intact throughout.

**The essential one passed:** two *different* transfers of the same product
received into the same destination row at the same instant produced quantity
**30** and cost exactly **8.00** — `(10 × 4 + 20 × 10) ÷ 30` — with no lost
update. A read-modify-write would have lost one of them.

- **Mobile:** TypeScript clean · `expo lint` clean · **expo-doctor 18/18** ·
  `expo export --platform web` built **32 routes** including all three transfer
  routes · **EN and AR both 695 keys**, no missing, extra or duplicate ·
  **24 pure Node tests** over the draft rules.

### 14g. Three defects the live run found, none of them new

1. **The global error filter discarded every structured detail.** It kept only
   `message` and `code`. Transfers have attached `problems` since H1.1 — which
   phone, and why not — and `mobile/lib/transfers.ts` has read `body.problems`
   since H1.3 to list refusals item by item. It always got `undefined`, so the
   user only ever saw the generic sentence. **No test noticed, because every one
   of them asserted the status code.** Fixed with an explicit allowlist, not a
   spread; pinned by `error-detail.spec.ts`.
2. **Nothing refreshed valuation after a transfer.** Only `sale.recorded` ever
   triggered a recompute, so from the moment H1.3 shipped serialized transfers
   the source branch went on reporting stock it no longer had. H1.4's in-transit
   figure made it visible rather than causing it. Both branches now refresh via
   a `stock.moved` event, emitted after commit.
3. **A flaky catalog test.** It searched `JSON.stringify(entry)` for bare
   numbers, which also searched the `entityId` buffer of a random UUIDv7 —
   `"160"` contains `"60"` — so it failed about one run in three for reasons
   unrelated to what it tested.

### 14h. Fixtures and cleanup

Every live script created its own products, stock, users and transfers, and
removed them. The Sell-versus-Transfer race records a **real sale**, which was
removed with its lines and payments rather than left to inflate the demo
baseline.

Demo data afterwards, identical to the H1.3 record: products 12 · units 11 ·
sales 7 · `sum_total = 10051.00` · sale_items 14 · stock 4 · reserved 0 ·
transfers 0 · notifications 41 · `units` checksum
`2a1dc9bf284afde32b402ad108d38a76` · 4 triggers · **0 temporary databases** ·
0 null-priced stock rows · 0 probe products.

**Deliberately removed and recorded rather than left implicit:** notifications
created by the live runs (dated today; the 41 older rows are the recorded
baseline and were untouched), via the migrator account. **The transfer
invoice-number sequence advanced and was not rewound.**

### 14i. Still not done, and not claimed

- **Nothing was verified on a physical device.** Camera scanning of an accessory
  barcode, haptics, the stepper under a thumb, sheet gestures and Arabic
  **visual** RTL are unverified by anything but a browser, a type checker and a
  test runner. `docs/24` §9c adds the H1.4 checks.
- **Partial shipment and partial receipt do not exist.** A transfer ships whole
  or not at all, and receives whole or not at all.
- **Discrepancies and return-to-source remain future work**, so a shipped
  transfer still cannot be cancelled.
- **Purchase intake still does not average cost** (§12e-A). After H1.4, cost is
  averaged when goods arrive by transfer and **not** when they arrive by
  purchase. That inconsistency is real, visible to the shop, and deliberately
  left for its own approved change.
- **Untargeted notifications remain company-wide** (H1.3's open item);
  `closing.completed` still uses that path.

---

## 14. H1.4.1 — transfer receipt now shares the one cost rule

H1.4 averaged cost correctly on transfer receipt while purchase receiving did
not, so the same question had two answers depending on how stock arrived.
H1.4.1 made it one: `receiveQuantityAtCost` in `inventory/stock-cost.ts` is now
used by transfer receipt, purchase receiving and quick "Add Stock" alike.

For transfers specifically:

- `receiveIntoExisting` is **gone**, not left as a second way to do it. Its
  "destination stock changed while receiving" conflict went with it — the
  single `INSERT … ON DUPLICATE KEY UPDATE` makes that state unreachable, since
  the row being absent and the row existing are now the same operation rather
  than a branch chosen by an earlier read.
- The destination's price decision is unchanged: its own branch variant price,
  else the catalogue default, else **unpriced**. Resolved before the write and
  used only if the row is created.
- Receipt is now wrapped in the lock-conflict retry, because this phase changed
  its lock profile. Two receipts landing on one destination row at the same
  instant can deadlock on the unique key; InnoDB rolls the victim back
  completely, and the version compare-and-swap keeps the retry from applying
  anything twice.

Re-proved live after the change: purchase racing transfer receipt into one
destination row keeps both quantities and produces the exact combined weighted
average, and the held/in-transit invariant holds across shipment and receipt.
