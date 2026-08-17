# 31 — Inter-store consignment and money loans: truth audit

> Milestones H and I. Written before any schema change, against the code and
> database as they actually are.

---

## H0 — what exists today

### 1. The only safe cross-tenant handle already exists

`Company.publicStoreId` — 10 uppercase hex characters, unique, immutable through
store-facing APIs, and explicitly **non-secret** (F1 Stage 3.2). It was built to
select a company *before* login, which is precisely the property inter-store
discovery needs: it identifies a shop without revealing anything about it.

The binary `Company.id` must never leave the server. It is the key the tenant
extension scopes every query on, and publishing it would hand one tenant the
identifier used to scope another.

### 2. The public profile fields the brief assumes DO NOT EXIST

`Company` carries exactly: `id`, `name`, `publicStoreId`, `currency`,
`timezone`, `settingsJson`, `isActive`, timestamps.

There is **no logo, no city, no public phone**. A discovery preview showing
"store name, logo, city" cannot be built from the current schema — those fields
have to be added, and adding them is a deliberate act of publication, not a
convenience. Everything a company puts there becomes visible to strangers.

### 3. Tenant isolation is fail-closed, and consignment is the first thing that legitimately spans two tenants

`tenant.extension.ts` injects `companyId` into every query. `GLOBAL_MODELS` is
exactly `{ Permission, TacCatalog }` — two tables that belong to the platform,
not to any shop.

**A consignment belongs to two companies at once.** That is a genuinely new
shape, and it is the central risk of this milestone:

- A single row with one `company_id` is invisible to the counterparty.
- Two mirrored rows can diverge, and a divergence in a money record is a dispute
  nobody can settle.
- One row with `source_company_id` + `destination_company_id` is correct, but it
  must be excluded from automatic scoping — which means **the guard that has
  protected every other table stops protecting this one**, and every read path
  has to be scoped by hand.

The decision and its mitigation are recorded in `docs/21`. Nothing else in this
codebase relaxes tenant scoping, and nothing else should.

### 4. The Unit state machine has no custody state

`UnitStatus` = `in_stock · reserved · sold · returned · faulty · in_transit ·
transferred_out`.

`transferred_out` is **internal** — it means the unit left this branch for
another branch of the same company. Reusing it for consignment would make a
phone that is legally still ours indistinguishable from one that has left.
Consignment needs its own state.

### 5. The reservation pattern to reuse is already proven

`transfers.service.ts` reserves with a compare-and-swap:

```ts
updateMany({ where: { id, status: 'in_stock' }, data: { status: 'reserved' } })
```

`count === 0` means somebody else claimed it first. The comment there records
why it was moved to reserve-first: the clash used to surface later, at ship.
This is the pattern H must use for the double-claim guarantee.

### 6. `SaleItem.cost` is the cost basis, and it makes private resale accounting almost free

A sale line carries its own `price` and `cost`. For a consigned resale, Store 2's
line cost is **the agreed consignment amount** — so Store 2's margin is correct
by construction and Store 1's real cost never enters Store 2's database.

**But `SaleItem.unitId` points at `units`, and the unit belongs to Store 1.** A
consigned sale therefore must NOT set `unitId`; it references the consignment
line instead. Setting it would either fail tenant scoping or create a foreign
key from one tenant's sale into another tenant's inventory.

### 7. Financial patterns worth reusing verbatim

| Pattern | Where it is proven |
|---|---|
| Immutable append-only ledger with derived balance | `employee_debt_entries` (0045), Milestone E |
| Report → confirm two-party money flow | refund payouts (I3), supplier settlements (J1) |
| Correction of a confirmed payment | `financial_corrections` (0040), Milestone B |
| Optimistic concurrency + `refresh_required` 409 | every service since F1 |
| Idempotency via `clientUuid` + payload hash | corrections, expenses, debt entries |
| Account label snapshot at the moment of movement | expenses, refunds, settlements |
| Mandatory reason on any forgiveness or write-off | `debt-rules.ts`, Milestone E |

The employee debt ledger is the closest existing thing to what I needs, and its
rules — a charge cannot be posted directly, settling more than is owed is
refused, forgiveness writes both the charge and the waiver — were argued out
already and should not be re-argued.

### 8. Notifications are per-user or per-branch, never per-company-pair

`emit()` targets a user or a branch. A consignment notification has to reach
*the other company*, which no existing call site does. Blocking must suppress
non-essential notifications without suppressing the ones that carry money.

---

## What may safely cross a tenant boundary

**Before a connection is accepted** — anonymous or public preview:

| Allowed | Reason |
|---|---|
| `publicStoreId` | Non-secret by design; the handle itself |
| Store name | The shop chose to be findable |
| Logo | Same, once the field exists |
| City | Coarse location only; never an address |
| "Verified badge coming soon" | A literal placeholder, not a claim |

**Never, at any stage:** the binary company id · branches · users · inventory ·
sales · suppliers · cost · margin · private settings · precise contact details.

**After acceptance**, additionally: the contact details the shop published for
this purpose. Nothing else changes.

**Within an accepted consignment**, Store 2 sees only: the product identity,
exact variant, the identifier under established privacy rules, condition,
explicitly shared defect information, and the agreed amount. It never sees
Store 1's cost, supplier, purchase or margin.

Store 1 sees only that the phone was sold and the agreed amount is now owed. It
never sees Store 2's customer, resale price or margin.

**Search must be bounded** and must not permit bulk enumeration: exact-match on
Store Account ID or phone, prefix-limited on name, a hard result cap, and
identical fail-closed responses whether a store does not exist or is blocked —
otherwise the difference between the two answers is itself an oracle.

---

## I0 — what H leaves reusable for loans

Deliberately recorded before H is built, so the primitives are designed to be
shared rather than retrofitted:

**Reusable:** the counterparty concept (connected company, manual store, manual
person), the immutable ledger shape, report → confirm → correct, forgiveness
with a mandatory reason, and the direction-as-data rule.

**Not reusable:** custody, shipment, condition, return and any consignment
disposition table. A loan has no phone in it, and modelling one as "a
consignment with no unit" would put custody states on a record that can never
have custody — the kind of shortcut that reads as clever and becomes unmaintainable.

**Direction is explicit data, never a sign.** `they_owe_us` / `we_owe_them` as a
column, because a negative amount is ambiguous the moment somebody corrects a
payment, and a sign flip is a silent reversal of who owes whom.
