# 21 — Product Decisions & Reconciliation

> **Status:** living record. Supplements [`ERP.docx`](../../Users/HP/Documents/ERP.docx) (Volumes I–II) and the earlier development handoffs.
> **Purpose:** hold approved product decisions in one place, reconciled against what the repository actually contains — so nobody re-derives them, and nobody assumes something is built when it is not.
> **Reconciled at:** backend 19 suites / 98 tests green · mobile `tsc --noEmit` clean.

**How to read this.** Four states, deliberately separated:

| State | Meaning |
|---|---|
| ✅ **Implemented** | In the code, verified running |
| 🟡 **Approved, not implemented** | Decided; buildable today; not yet built |
| ⛔ **Blocked** | Decided, but a required API or model does not exist |
| ❓ **Needs decision** | Cannot proceed without an answer; guessing would be inventing a business rule |

---

## 1. Repository facts worth knowing

**Resolved.** All three areas are now under version control with private GitHub
remotes — see [`22_BACKUP_AND_ROLLBACK.md`](22_BACKUP_AND_ROLLBACK.md):

| Area | Repository | Files |
|---|---|---|
| `docs/` + `CLAUDE.md` | `erp-docs` | 19 |
| `backend/` | `erp-backend` | 180 |
| `mobile/` | `erp-mobile` | 119 |

- `mobile/node_modules` was **staged but never committed**, so untracking it needed no history rewriting.
- No secret ever entered any commit; `.env.example` has been sanitised to placeholders.
- `ImportBatch` / `ImportRow` models already exist and are branch-scoped, so "one import session targets one branch" is already modelled.
- `Unit` carries `cost` but **no `price`** — see §6.

---

## 2. Roles and permissions

### ✅ MIGRATED (0016) — three store-facing roles

Store-facing roles are **Owner · Store Manager · Store Employee**.

- **Store Employee replaces both `sales_employee` and `warehouse_employee`.** One employee may sell, receive and do normal store work — the split was artificial and caused the `POST /purchases` 403.
- **Technician** stays a separate future role, built last.
- **Platform Administrator** remains as an internal SaaS role. It is *not* a store employee role and does not belong in the store role matrix.
- **Existing role records must not be deleted or renamed without a safe data migration** mapping Sales and Warehouse employees onto Store Employee.

#### Completed — migration 0016 + seed remap

Store-facing roles are now **Owner · Store Manager · Store Employee**.

| Before | After | Assignments |
|---|---|---|
| `sales_employee` | `store_employee` | 3 |
| `warehouse_employee` | `store_employee` | 2 |
| `branch_manager` | `store_manager` | 0 (none existed) |
| `owner` | unchanged | 4 |
| `administrator` | untouched (internal SaaS role) | 0 |

Counts went `{owner: 4, sales_employee: 3, warehouse_employee: 2}` →
`{owner: 4, store_employee: 5}`; total assignments unchanged at 9. Assignment
ids, users, branches and companies were all preserved — only the role value
moved. The exact per-row mapping is printed by the seed and recorded in the
migration report.

**Final permission matrix** *(corrected by the D2.1 semantics audit)*

| Permission | Owner | Store Manager | Store Employee |
|---|:--:|:--:|:--:|
| sale.create | ✅ | ✅ | ✅ |
| cost.view | ✅ | ✅ | ✅ |
| discount.apply | ✅ | ✅ | ✅ |
| unit.add / unit.transfer | ✅ | ✅ | ✅ |
| **purchase.manage** *(the 403)* | ✅ | ✅ | ✅ |
| sale.return *(completes a refund)* | ✅ | ✅ | **—** |
| import.run *(activates inventory)* | ✅ | ✅ | **—** |
| supplier.manage / closing.perform | ✅ | ✅ | — |
| report.view | ✅ | ✅ | **—** |
| **discount.override** *(below-cost gate)* | ✅ | **—** | **—** |
| expense.manage | ✅ | **—** | **—** |
| branch/user/settings/integrations.manage | ✅ | — | — |

Totals: Owner 17 · Store Manager 11 · Store Employee 6.

#### D2.1 — deployment safety and semantics audit

**Deployment hole, fixed.** 0016 only added enum values; the remap and the new
permission matrices lived in the SEED, and `prisma migrate deploy` never runs
`prisma db seed`. A production deploy would have applied 0016 and left every
employee on a legacy role with no permission rows — a silently broken system
where applying migrations looked successful.

- **0017_store_role_backfill** — creates both store roles per company, grants
  their permissions by stable KEY, and remaps legacy assignments. Every
  statement is guarded by `NOT EXISTS` or matches only rows still in the old
  state, so reruns are no-ops.
- **0018_store_role_revoke** — removes grants the audit withdrew. 0017 only
  inserts, so a database that already ran the D2 seed would otherwise keep
  permissions that were since revoked. Grants must shrink as well as grow.

Verified on a temporary database restored from a pre-D2 dump: `migrate deploy`
alone remapped 5 assignments and installed 11 + 6 permission rows, with no seed.
A drift test fails the build if the SQL and the TypeScript matrix disagree.

**Three permissions removed because their real behaviour is final authority:**

| Removed from | Permission | What it actually does |
|---|---|---|
| Store Employee | `sale.return` | `returnUnit` voids the sale line, restocks the unit and computes a **refund** — it completes a return rather than requesting one |
| Store Employee | `import.run` | Reserved for **activating** imported inventory, not preparing it |
| Store Manager | `discount.override` | Despite the name, this is the **below-cost selling** gate in `assertBelowCostAllowed` |

`discount.apply` is retained for Store Employee only because the cost floor is
enforced independently on `discount.override`, which the role does not have —
verified: it guards no endpoint of its own.

**Approval gaps found, not expanded:**
- `unit.transfer` guards **all five** transfer endpoints, including
  `receive/confirm` and `cancel` — one permission both initiates and completes.
- `purchase.manage` creates a **final** purchase immediately; the approved
  model wants employee-entered cost to await approval while remaining usable.
- `import.run` currently guards **no endpoint at all**.

Two deliberate narrowings, both recorded rather than inherited:

- **Store Manager has no `expense.manage`**, although `branch_manager` did. The
  approved decisions describe a narrower manager, and inheriting spend authority
  because a permission happened to exist would be inventing a business rule.
- **Store Employee sees cost but not reports.** That separation is the reason
  `cost.view` and `report.view` are distinct permissions.

**Blocked on future work**

- **Price editing** has no permission to grant. It stays Owner-delegated and
  needs per-user permission overrides, which do not exist.
- **Submit-only expenses.** The model cannot distinguish "submit an expense"
  from "manage expenses", so neither store role gets either.
- **`return.request`** — so an employee can report a return without completing
  the refund.
- **`import.prepare` / `import.approve`** — so an employee can upload, map and
  correct a draft without activating inventory.

**Sessions.** No revocation was needed: the JWT carries only `{sub, companyId,
type}` — no roles or permissions — and permissions resolve from the database on
every request, cached only in request-scoped CLS. A role change therefore takes
effect on the next request. The mobile client now also re-resolves permissions
on app resume so a stale UI cannot outlive a role change.

**Legacy enum members** `administrator`, `branch_manager`, `sales_employee`,
`warehouse_employee` remain. Safe to retire once no `user_branches` row
references them **and** no seed or utility can write them — the latter is now
true. `administrator` should be kept: it is the internal Platform Administrator.

#### Audit — the migration was far smaller than feared

Role keys appear in exactly three places, all of them data definition:

| Location | What |
|---|---|
| `prisma/schema.prisma` | `RoleKey` enum |
| `prisma/seed-data/permissions.ts` | union type, permission matrix, labels |
| `prisma/create-user.ts` | dev utility's accepted values |

**Zero references in `backend/src`. Zero in the mobile app.** Authorization is entirely permission-based (`@RequirePermissions` + the frontend permission store); nothing branches on a role name. So this migration touches the enum, the seed matrix and existing rows — **no call sites at all**.

Live data at time of audit:

```
assignments by role: { owner: 4, sales_employee: 3, warehouse_employee: 2 }
administrator: 0 assignments   branch_manager: 0 assignments
```

Five `UserBranch` rows need remapping. `administrator` and `branch_manager` carry no assignments, so retiring or renaming them costs nothing.

### ✅ RESOLVED — employee cost visibility

Store Employees **may** see product cost and the last selling price.

Critically, **cost visibility and profit/report management stay separate permissions**. Employees do *not* automatically get financial dashboards, total profit reports, expense management, or the Owner's WhatsApp summaries.

This supersedes `docs/03` and ERP.docx §9 on cost visibility only. The existing design already supports it cleanly: `cost.view` is its own permission, distinct from `report.view` and `expense.manage`, and the `CostGatingInterceptor` keys off `cost.view` alone. The change is granting `cost.view` to the Store Employee role — the separation the decision requires is already structural.

### 🟡 Approved, not implemented

Owner does not consume an employee seat · Manager price editing requires an Owner grant and always notifies the Owner · Employee may propose cost and price, self-confirm the typed value, and sell at a proposed price while approval is pending, with profit provisional until cost approval · Historical margins must **not** be revealed to help an employee enter a cost.

⛔ Approval workflows generally — there is no approvals model, no `user.manage` API, and no notification targeting by role.

---

## 3. Inventory *(this milestone)*

✅ **Implemented**
- Serialized units listed individually with status (colour **and** word, via `StatusChip`).
- Quantity-tracked stock listed as aggregate lines — previously invisible, because `listStock` returned only `Unit` rows. 242 accessory units were hidden by this.
- Zero-quantity rows excluded (a product that once had stock here is not stock).
- Branch scoping via CLS tenant context and `X-Branch-Id`.
- Cost/profit stripped automatically by the global interceptor — verified: owner sees `cost`, `sales_employee` does not, `price` visible to both.
- Loading skeletons, empty, error, and 403 → "Not available to you" **with no retry action**.
- Scanner lookup routed through `POST /scan` (recognition keeps learning) with the unit lookup in parallel.
- Typed discriminated response — see the API contract note in §10.

✅ **Pagination and server-side search — implemented (Phase B)**

The silent `take: 200` is gone. `GET /inventory` now returns
`{ rows, nextCursor, hasMore, totals }`:

- **Keyset pagination**, not offset — stock changes while a user scrolls, and
  offset paging would skip a row every time one is sold mid-scroll.
- **Value-based**, not Prisma's `cursor` — Prisma's variant locates an anchor
  row, so when that unit is sold and leaves an `in_stock` filter the listing
  silently ends early. Comparing values has no such failure mode.
- **Tie-safe.** `date_in` is `DATETIME(6)` and a bulk receive can stamp a whole
  delivery inside one microsecond, so the cursor carries the ids already emitted
  at the boundary and accumulates them while that boundary does not advance.
  Without accumulation, paging loops forever on a large tie group — caught by an
  adversarial fixture where all 220 rows share one timestamp.
- **`totals` counts the whole filtered result**, so the UI shows "3 of 340"
  rather than implying a page is the entire branch.
- **Search runs on the server** across product name, variant, barcode, both
  IMEIs and serial number. Filtering only downloaded rows would answer "we don't
  have it" for stock sitting on the shelf.

`Bytes` has no `lt`/`gt` in Prisma, which is why the keyset compares timestamps
and excludes tied ids via `notIn` — the one comparison the type does expose.

---

## 4. Inventory intake (opening stock)

🟡 **Approved, not implemented.** Five intake routes: official Excel template · column mapping for an existing spreadsheet · smart scanning · hybrid scan-and-verify · manual product entry.

Excel rules recorded: one session per branch (already modelled) · serialized phones one physical unit per row · IMEI1 expected, IMEI2 optional · accessories one row per exact variant with quantity · invalid/duplicate rows must be corrected or explicitly excluded before approval · Ready rows may activate while unclear rows stay in draft · estimated cost allowed for old stock but resulting profit must be labelled **estimated** · imported stock may be active-but-unverified and verified gradually during normal operations · **workers must not be made to rescan hundreds of phones after import** · unknown products may create product drafts · accessory discrepancies found are opening stock, **not purchases**.

### ✅ RESOLVED — validation and workflow are separate concepts

`ImportRowStatus` (`valid | warning | error`) is **row validation** and stays exactly as it is.

The approved states — **Ready · Needs clarification · Excluded · Imported-unverified · Verified** — are a **workflow lifecycle** and get their own field later. A row can be `valid` *and* `Needs clarification`; collapsing the two would lose information.

⛔ Still blocked on the `import.run` API surface, which does not exist.

---

## 5. Scanning

✅ Scan pipeline, confirmation card, manual fallback, duplicate suppression, torch, continuous mode.
✅ Accessories can already be found by barcode scan **or** manual search — not restricted to manual entry.

🟡 Phone sale must scan the IMEI shown by `*#06#` on the device itself, not the box · IMEI1 and IMEI2 are the same physical phone · if IMEI2 cannot be obtained, warn but allow · always show a confirmation step (already the case) · assisting employee must confirm from their own account.

⛔ Quick-creation of unknown accessories with quantity, cost and proposed price — depends on the approvals model.

---

## 6. Pricing

### ✅ RESOLVED — per-unit pricing approved, schema change deferred

A **nullable selling-price override on the serialized `Unit`**. When absent, price falls back to the exact-variant / product price. Every override records **scope, actor, timestamp and audit history**.

**Do not implement this schema change yet** — it is sequenced after the role migration (see §12).

Approved scopes: this unit only *(default)* · exact variant in the active branch · exact variant across branches *(Owner-only)*.

Current state: `Unit` has `cost` but no `price`; selling price lives on `Product.defaultPrice` and `StockItem.price`.

Recorded: an iPhone 13 Pro Max repriced 17,500 → 17,000 MRU must **not** move every iPhone 13 Pro Max unless exact-variant scope is chosen deliberately · every edit notifies the Owner with old price, new price, cost, employee, timestamp and scope · "Restore previous price" affects future unsold inventory, never completed sales · below-cost still requires Owner approval and a recorded reason (✅ already enforced server-side and surfaced in Sell).

### ✅ RESOLVED — the pricing schema (G2A-CP2, migration `0027_pricing_foundation`)

The schema above is no longer deferred. **Migration `0027` is applied.** It adds
three tables and changes nothing that already existed.

| Table | Holds | Identity rule |
|---|---|---|
| `branch_variant_prices` | the current price of one **exact variant** in one **branch** | `UNIQUE (product_id, branch_id)` |
| `unit_price_overrides` | the current price of one **individual unit** | `UNIQUE (unit_id)` |
| `price_change_events` | every price change, forever | append-only, no uniqueness |

All money is `DECIMAL(14,2)`, all keys are `BINARY(16)` UUIDv7, matching the rest
of the schema.

**Effective price — first match wins:**

1. `unit_price_overrides` for that unit, **if its `branch_id` is the branch selling it**
2. `branch_variant_prices` for that exact variant in that branch
3. `StockItem.price` — for quantity-tracked stock only
4. `Product.defaultPrice`

**Why `Product.defaultPrice` was not replaced.** It is the company-wide fallback,
and step 4 is what makes an absent row meaningful. It is set once at catalog
create and nothing else mutates it. Replacing it would have forced a value into
every branch on day one.

**Why the migration backfills nothing.** Copying `defaultPrice` into
`branch_variant_prices` for every product × branch would invent prices nobody
set, and would permanently destroy the fallback — once every branch has a row,
step 4 can never be reached again, and changing the catalog price would silently
stop reaching the shops. Verified on the restored pre-migration database: 12
products, 11 units, and `bvp=0 upo=0 pce=0` afterwards.

**Why `StockItem.price` stays authoritative for quantity stock.** Quantity stock
has no unit to override, and its branch price is already there. Adding a second
quantity-price source would create two answers to one question. It stays at
step 3. *(See the open issue below — who may set it is not settled.)*

**Why a unit override carries `branch_id`.** CP1 proposed keying the override on
`unit_id` alone. That is wrong: a price set by a Manager in Branch A would follow
the phone into Branch B and take effect there under authority nobody granted.
`branch_id` records the **branch whose authority created the price**, not where
the unit currently is. It is deliberately *not* a foreign key to the unit's
current location — the two must be allowed to diverge, because that divergence is
exactly the signal CP3 acts on.

**Mandatory CP3 behaviour — transfer invalidation.** When a unit moves to a
different branch, its override must **stop applying** (resolution step 1 fails
its branch test) and a `price_change_events` row must record the invalidation
with `initiator = 'system'`. The receiving branch prices from step 2 or below
until someone with `price.edit` **in that branch** sets a new one. The schema
makes this enforceable; CP3 must implement it. **Until CP3 ships, no code reads
these tables at all**, so there is no half-enforced state.

**Concurrency.** Both current-price tables carry `version INT DEFAULT 0`.
Updates are compare-and-swap on `(id, version)`; a stale write affects 0 rows and
returns **409**, the same pattern as the catalog. Two managers repricing the same
phone cannot silently overwrite each other. `price_change_events` needs no
version — it is never updated.

**Append-only, enforced by the database.** `price_change_events` has
`BEFORE UPDATE` and `BEFORE DELETE` triggers that `SIGNAL SQLSTATE '45000'` when
`USER()` is the application account — the same mechanism as `audit_logs`, and for
the same reason: service convention does not survive a mistake, a script, or a
future refactor. A DBA account can still archive by date range. Unlike
`audit_logs`, these triggers live **inside the migration**, so a fresh deployment
gets them automatically instead of depending on someone running an init script.
Proven against real MySQL as `phonestore_app`: read ✅ insert ✅ update **blocked**
✅ delete **blocked** ✅ negative price rejected by CHECK ✅ history intact ✅ (7/7).

Nullable `previous_price` / `new_price` let *created*, *changed* and *removed*
share one append-only shape — a removed override is recorded, never erased.

**Backup and deployment.** Pre-migration backup
`phonestore-20260807-051508.sql` (`--hex-blob`, `--single-transaction`, routines,
triggers, events, no tablespaces; 52 tables, 2 triggers). The DEFINER-safe
restore path in [`22`](22_BACKUP_AND_ROLLBACK.md) was **proven before** applying:
restored copy matched live table-for-table and `units` HEX(id) checksums were
identical. `0027` then deployed cleanly on a clean database, on the restored
pre-migration database, on dev, and on rerun; all temporary databases dropped.

### ✅ RESOLVED — pricing behaviour (G2A-CP3, backend complete)

**One `PricingService` is the only authority on selling price.** Sell, product
detail, the pricing API and the future mobile screens all ask it. Two places
each implementing "override, else branch, else default" is how a shop ends up
with two answers at the counter.

**Effective price, first match wins** — every response names its `source`:

| # | Source | Applies to |
|---|---|---|
| 1 | `unit_override` | one exact item, **only when the override's branch, the unit's current branch and the active branch all match** |
| 2 | `branch_variant` | that exact variant in that branch |
| 3 | `stock_item` | quantity products only |
| 4 | `product_default` | company-wide fallback |
| 5 | `unpriced` | nothing is set — stated, never guessed |

A product view with no unit selected **cannot** see rung 1: one phone's price is
not the model's price. A stale override is reported as `staleOverrideIgnored`
rather than applied, so a transfer that somehow failed to invalidate is visible
instead of silently charging the wrong price.

**Authorization.** Writes and history need branch-scoped `price.edit`; reads of
the effective price are open to any signed-in user, because the counter needs
them. `catalog.manage` grants nothing here — live-verified with a Manager who
holds `catalog.manage` in both branches but `price.edit` in only one.

**Below cost** is expressed purely in permissions: `discount.override` plus a
non-blank reason, recorded in history. A Manager is refused because that
permission is Owner-only and never delegatable — no role name is compared. A
branch price must clear the most expensive in-stock unit of that variant; the
refusal states **how many** items are affected and never a cost. With no units
in stock the price is allowed, and Sell still enforces the real unit-cost floor
at the counter.

**Concurrency.** Compare-and-swap on `version`; a stale update or removal is
`409`. A lost create race is translated from the unique-key rejection into
`409 refresh_required` — the winner's price is never overwritten.

**Atomicity.** The price change, its `PriceChangeEvent`, the audit row and the
Owner notification are one transaction. A failed history or notification write
rolls the price back, so a price without its history cannot exist.

**Owner notifications** reuse the existing `Notification` model and exclude the
actor. That one rule covers both cases: a Manager's change reaches every active
Owner; an Owner's own change notifies nobody, while still being audited and in
history. An Owner assigned to several branches gets one message, not one per
branch. No cost, no margin, no threshold in the payload. No WhatsApp, and the
dormant OTP/WhatsApp infrastructure is not called.

**Transfer invalidation** runs inside the receive transaction, so the move and
the invalidation commit or roll back together. The override row is **deleted**,
not flagged, so a phone that comes back cannot resurrect a price nobody
re-approved; history keeps the value with `initiator = 'system'` and
`reason = 'branch_transfer'`. `transfers.receiveConfirm` is the **only**
production path that changes `Unit.branchId` — `cancel` writes the origin branch
back to where the unit already was, and that no-op is skipped.

**`initiator` is `user` | `system`**, not CP2's sketched `owner` | `manager`:
`actorId` already records who acted, roles change afterwards while history must
not, and a copied role would drift from the real one. A third `scope` value,
`stock_item`, covers quantity price changes.

**Migration `0029_stock_item_version`** adds `version` to `stock_items`.
`updatedAt` could not serve: MySQL keeps microseconds but a JavaScript `Date`
carries only milliseconds, so a compare-and-swap on it would round-trip lossily,
and two writes in the same millisecond are indistinguishable. Faking the check
in application memory was the alternative and is worse — it cannot see a
concurrent writer at all.

**Migration `0028_audit_append_only_triggers`** moved the `audit_logs` guard into
the migration chain. It had lived only in a manual init script, so a clean
database built from every migration had **no** `audit_logs` triggers and a fresh
production deployment would have shipped a mutable audit log. Grants cannot
substitute: `partial_revokes` is schema-level only.

### ✅ RESOLVED — the mobile pricing experience (G2A-CP4)

**The app renders the server's decision and never re-derives precedence.** Every
pricing screen displays the `price`, `source`, `version` and `fallback` the
CP3 endpoints return. Two implementations of one ladder is how a screen and a
till start disagreeing about a price.

**Source in shop language, never database words.** `unit_override` →
"This phone's own price" · `branch_variant` → "This branch's price for this
model" · `stock_item` → "This branch's price for this item" · `product_default`
→ "Company price" · `unpriced` → "No price set". Each carries a sentence saying
*why* that one applies, and is rendered as a labelled chip — **words plus tone,
never colour alone**. Full EN and AR.

**Who sees what.** Every store role sees the effective price and its source;
the counter needs it most. Edit controls require branch-scoped `price.edit`, so
a delegated Manager sees them in the granted branch and not in another, and an
Employee sees **no controls at all** rather than disabled ones. `catalog.manage`
shows nothing. Changing branch re-resolves both price and controls, because the
branch is part of the query key.

**Cost was moved out of the pricing section** into its own block. Mixing what a
thing cost with what it sells for is how a counter charges the wrong number.
Withheld cost still reads "Hidden", never `0`.

**Two clearly different serialized actions**, deliberately not one screen with a
scope toggle — that is how someone reprices the whole shop by accident:

1. **This model's price here**, stating explicitly that other variants, other
   branches and individual phones are unaffected.
2. **One phone's price**, reached by `*#06#` on the dialer and scanning the IMEI
   **off the phone itself**. Scanning the box is *not* offered as the preferred
   route: boxes get separated from phones and the price follows the wrong one.
   Manual entry is always available, not only when the camera fails.

**Quantity products** edit `stock_items.price` through the `0029` version, and
never touch a unit override or create a branch-variant row.

**One shared `PriceEditor`** for all three scopes. Three editors would be three
chances for version handling, the below-cost flow or the scope wording to drift.
Save stays disabled until the value both parses and differs; closing dirty asks
first.

**`parsePrice` is a separate dependency-free module** (11 Node tests) so blank,
`NaN`, negative and over-precise values cannot reach the API — `DECIMAL(14,2)`
would silently truncate the last of those into a price nobody typed. Arabic-Indic
digits are accepted because the Arabic keyboard produces them. `Intl` is not
used; Hermes ships inconsistent ICU data.

**409 explains and stops.** The user is told what they tried and what it is now,
then chooses. Silently refreshing and resubmitting would overwrite the decision
someone else just made. Invalidation is scoped to pricing, the product and the
branch's inventory — not a blanket refetch of the whole app for one edit.

**Below cost stays the server's call.** A refusal is shown as-is with no bypass
offered; an Owner's authorisation reuses `dialog.confirmWithReason` and resends
**the same price and the same version**, so the retry is the edit that was just
reviewed and not a different one.

**History** is bounded to one keyset page, shows `previous → new` or "Price
removed", and reports a transfer invalidation as *Automatic*. It never infers a
historical role from the actor's current one — `initiator` stays `user|system`
as CP3 decided.

### ✅ RESOLVED — cost gating must not fail a request it only meant to filter

Found by the CP4 preflight. `CostGatingInterceptor` resolved permissions for the
active branch and let `AccessService`'s 403 escape, so a restored session holding
a branch the user had been removed from failed **every** request — including
`GET /auth/branches`, the one screen needed to pick a different branch. That was
a lock-out with no way back.

Cost gating decides what to *strip*, not who may call. Guards run first and have
already rejected anything genuinely branch-scoped, so a failed resolution now
degrades to the strictest gating (no `cost.view`) and is not cached.
`/auth/permissions` still answers **403** — the honest answer to a question about
a branch the user cannot use — and the client recovers by dropping the branch,
which routes it to the branch picker.

### ✅ RESOLVED — CP4 verified by driving the app (G2A-CP4.5)

CP4 shipped on TypeScript, lint and a web export. CP4.5 ran the app for real —
Expo web against the live API and the real database — and that found three
things compilation never could.

**1. A sold phone could be given a price.** The exact-phone screen offered
"Change one phone's price" for a sold unit and the API accepted it with 200.
CP4 required refusing ineligible units; nothing enforced it. `setUnitOverride`
now requires `in_stock`, mirroring `SalesPolicyService.assertSellable` so the
set of things you can price and the set you can sell cannot drift. Removal stays
allowed, so a stale override can still be cleared after a sale. The read endpoint
returns `status` and `canPrice`, and the screen explains instead of offering a
control the server will refuse.

**2. The stale-edit dialog quoted its own stale number.** In a real race — a
second session moved a price to 1234 while an editor sat open — the 409 was
handled correctly but the message read "It is now 500 MRU", the snapshot the
editor had opened with. That is the one number guaranteed to be wrong in that
message. It now re-reads the server before composing the text.

**3. Notifications did not exist.** CP4 recorded the screen as "still a
prototype"; there was no screen at all, only an unused query key, so the Owner
notification CP3 writes had nowhere to appear. CP4.5 adds the minimum: a bounded
keyset-paginated list, unread state in words plus tone, mark-as-read through the
existing endpoint, and an action that follows the server's link. No push, no
provider, no preferences, no second model. Notification list pagination replaced
a fixed `take: 100` that was bounded but could never reach anything older.

**Interactively verified** (driven through the UI, not asserted from source):
branch price set → update → remove → fallback restored, with another branch
visibly unaffected · exact-phone override set/update/remove by manual IMEI ·
sold and unknown identifiers refused · quantity price edited with the version
incrementing and **no** second price row · Owner below-cost reason dialog, blank
reason blocked, reason stored in history · a real 409 race · price history
rendering · notification list, read state and action link · Arabic strings
across the pricing section.

**Verified at the API with three real sessions:** Manager edits only the granted
branch, holds `catalog.manage` in both (proving that is not what gates pricing),
is refused below cost with a count and never a cost figure, and never holds
`discount.override`; Employee reads prices, is 403 on writes and on history, and
never receives the Owner's notification.

**Not verified, and not claimed:** no physical device, so camera scanning,
haptics, keyboard behaviour, sheet gestures and **visual RTL layout** are
untested — the browser pane was `visibilityState: hidden` throughout, so no
screenshot or animation evidence was taken. Arabic *strings* were confirmed to
render; Arabic *layout* was not. [`docs/24`](24_DEVICE_QA_CHECKLIST.md) is the
checklist for the user's own device pass.

### 🔴 OPEN — who may establish `StockItem.price` (belongs to G2B)

**Not settled, and not silently approved.** Today, `upsertStock` writes `price`
on the **first receive of a quantity product into a branch** — and receiving is
open to a **Store Employee**. So an Employee performing an ordinary intake can
establish the branch selling price for that product, without holding
`price.edit`. Subsequent receives do not overwrite it, so this happens exactly
once per product per branch and is easy to miss.

This is current behaviour, discovered during the CP1 audit. It is **not** an
approved pricing rule, and CP2 deliberately did not change it — changing intake
behaviour is outside the schema phase and would have shipped an unreviewed
workflow change alongside a migration.

Three candidate resolutions, for the user to decide in **G2B**:

1. Receive never sets price; the branch price comes from the pricing tables or
   the fallback chain. Cleanest, but a first receive with no price anywhere means
   the product sells at `defaultPrice`.
2. Receive may set price only if the actor holds `price.edit` **in that branch**;
   otherwise the field is ignored and the fallback applies.
3. Receive may propose a price that stays pending until someone with `price.edit`
   confirms it — consistent with the deferred employee-proposal subphase.

Until this is decided, treat the Employee write as **known, tolerated, and
unapproved** — not as the pricing model's intended behaviour.

**CP3 left receiving untouched, deliberately.** The first quantity receive still
establishes `StockItem.price`; later receives increment quantity and leave the
price alone. Serialized receives set no price of their own and now resolve
through the ladder above. Nothing in receiving mutates `Product.defaultPrice`.
Changing any of this is a workflow decision for G2B, not a side effect of a
pricing phase.

---

## 6b. Transfers *(approved 2026-08-07 — serialized transfers now SHIPPED)*

Audit and full reasoning: [`25_TRANSFERS_AUDIT_AND_DECISIONS.md`](25_TRANSFERS_AUDIT_AND_DECISIONS.md).

> **Status: serialized transfers are complete and usable end to end.**
> H1.1 (`0030`) reservation and idempotency · H1.2 (`0031`, `0032`) the
> permission split and approval lifecycle · H1.3 (`0033`) notifications and the
> mobile workflow. **Quantity-tracked stock is still not transferable** — that
> is H1.4, and the two open cost/price questions below must be answered first.
>
> One naming correction to the plan below: the approved state was called
> `ready_to_ship`, but it shipped as **`approved`**, because the state means "a
> person with the authority agreed", which is a decision rather than a
> readiness. `ready_to_ship` was remapped to it by `0031`.

**Transfers move one company's own stock between its own branches.** They are not
inter-store consignment and the model must not be stretched to cover it.

### ✅ APPROVED — Option A, request and confirmation separation

| Decision | Approved answer |
|---|---|
| Who does what | **Employee requests** · **Manager/Owner approves or rejects** · source records shipment · destination reports receipt · **Manager/Owner cancels after shipment** |
| No Manager present | **The Owner may approve remotely.** Approval still requires `transfer.approve` **in the source branch** — an Owner is assigned everywhere, so this needs no cross-branch escape hatch and branch scoping is unchanged |
| Quantity accessories | **Transferable — in scope for H1** |
| When stock stops being sellable | **At request.** Reserved the moment it is promised, released on rejection or cancellation |

The same actor should not both initiate and give final confirmation **when another
authorised user is available**.

### What this changes

- **Lifecycle:** `pending_approval → ready_to_ship → in_transit → received`, with
  `rejected` and `cancelled` as terminal exits. Today's flow starts at
  `ready_to_ship` and has no approval at all.
- **Permissions:** `unit.transfer` splits into `transfer.request`,
  `transfer.approve`, `transfer.ship`, `transfer.receive`, `transfer.cancel`.
  Today one permission guards every transition and **all three roles hold it**, so
  an employee assigned to both branches can run a transfer end to end alone.
- **Reservation:** serialized units use the existing unused `UnitStatus.reserved`
  — no enum migration, and `assertSellable` already refuses anything that is not
  `in_stock`, so reserved stock stops being sellable for free. Quantity stock has
  **no** reservation primitive and needs a `StockItem.reservedQuantity` column;
  sellable quantity becomes `quantity − reservedQuantity` everywhere.
- **Idempotency:** `POST /transfers` needs a client-generated request id, as Sale
  already has. Today a retry creates a second transfer, and two open transfers can
  claim the same unit.

### ✅ Settled during H1.3

- **Which transitions notify, and whom.** All seven, with recipients resolved
  from the permission the next step needs rather than from role names, the actor
  excluded, and people deduplicated. A **refusal goes only to the requester** —
  broadcasting it helps nobody and embarrasses somebody. Notification text
  carries branch names, the reference, an item count, the actor and any reason,
  and **never cost, price or margin**, because it is read outside the request
  that authorized it.
- **Cancellation and rejection reasons** are mandatory at the API, stored on the
  transfer, shown on the detail screen, and carried in the notification.
- **History grouping.** Status tabs — waiting, approved, on the way, received,
  refused, cancelled — over one server-paginated list, with server-side search
  by reference, branch, product or IMEI. Completed and refused transfers stay
  reachable rather than ageing off a fixed page.

### ✅ ANSWERED (2026-08-13) — the two rules H1.4 was blocked on

**Destination cost — weighted average.** On receipt the destination cost becomes

```text
(destination physical quantity × destination cost + received quantity × shipment cost snapshot)
÷ (destination physical quantity + received quantity)
```

using **physical** destination quantity, not available. Existing destination
reservations stay reservations. With no destination row, or a physical quantity
of zero, the received cost simply becomes the destination cost. Full precision
is kept in the database and rounding happens only for display.

The cost that is averaged in is **snapshotted from the source at shipment, not
at request** — the goods are only really gone once they leave, and a cost that
changed while a request sat waiting for approval should not be the one that
travels. **Zero is never used for an unknown cost**: shipment fails with an
actionable error instead of inventing one.

**Destination selling price — branch-private, never inherited.** Selling price
does **not** follow the goods. On receipt:

1. an existing destination `StockItem` **keeps its own price, unchanged**;
2. a new row resolves its price from the destination `BranchVariantPrice`, then
   `Product.defaultPrice`, otherwise **unpriced**;
3. the source `StockItem.price` is never copied, and is never shown to the
   destination as a hint.

This is the CP3 rule made explicit for quantity stock: a price is an act of
authority in one branch, so carrying it into another would apply a decision
nobody there made.

**Total company inventory value is invariant across the whole movement.**
Request and approval change nothing. Shipment moves value out of the source
branch and into an explicit **in-transit** bucket of exactly the same size.
Receipt moves it out of in-transit and into the destination. Reports must
distinguish stock physically held from stock in transit, and must not double
count. Profit and sale history are untouched.

> Audit backing these rules, including the three contradictions it found in the
> existing financial code, is in
> [`docs/25` §12](25_TRANSFERS_AUDIT_AND_DECISIONS.md).

### 🔴 Still open

- **Purchase intake does not average cost** (`docs/25` §12e-A). Buying the same
  accessory again at a different price leaves the branch cost at whatever the
  first receipt set, so margin is overstated afterwards. Pre-existing, unrelated
  to transfers, and **deliberately not fixed inside H1.4** — changing purchase
  costing needs its own approval. After H1.4 cost is averaged on transfer
  receipt but still not on purchase receipt.
- Partial receipt · discrepancy and return-to-source · shipment/receipt photos.
  Until return-to-source exists, **nothing may cancel a shipped transfer** —
  rewriting the unit's branch back would be a guess about where the goods are.

---

## 6c. Quantity-stock cost — APPROVED and SHIPPED (H1.4.1)

Full audit and proofs: [`26_QUANTITY_COST_AND_VALUATION_AUDIT.md`](26_QUANTITY_COST_AND_VALUATION_AUDIT.md).

**Quantity-tracked stock is valued at a weighted average cost.** One rule for
every way it enters a branch — purchase receiving, quick "Add Stock", and
transfer receipt:

```text
new average = (physical quantity × current cost + received × incoming cost)
              / (physical quantity + received)
```

| Decision | Approved answer |
|---|---|
| Which quantity weights the average | **Physical**, not available. Stock promised to a transfer is still owned and was still bought at a price |
| Reservations | **Untouched** by receiving — what is here changes, what is promised does not |
| First stock in a branch | The incoming cost becomes the average |
| Zero physical stock | The incoming cost becomes the average (no special case: the formula gives it) |
| Precision | `DECIMAL(14,2)`, the money precision of the whole schema. Division happens in SQL; nothing is rounded in application code first |
| Supplier payable and purchase history | Keep the **actual** cost paid. Averaging never touches them |
| Past sales and stored margins | **Never recalculated.** A sale's cost is the snapshot taken when it happened |
| New sales | Use the current average through the existing snapshot model |
| Serialized items (phones) | **No averaging, ever.** Each unit keeps its own actual cost |
| A missing price | The row is **unpriced** (`NULL`), never `0` — zero means "free", which nobody chose |

### Why cost never touches the selling price

Receiving at a new cost does not reprice the shelf. `StockItem.price`,
`BranchVariantPrice`, `Product.defaultPrice`, `UnitPriceOverride` and historic
`SaleItem.price` are all untouched by an inflow. A branch's price is its own
decision and does not travel with the goods.

### Inventory valuation — what is authoritative

**Closing and finalized records never read the eventual rollup.** Daily closing
awaits its own recompute and reads `sale_items` — the immutable per-line cost
snapshots. `/analytics/inventory-value` computes held value live from source,
so `held + in-transit` reconciles at the instant it is served.

Dead-stock listings and the health score keep reading the persisted rollup:
they rank per product, where a moment's lag changes an ordering, not a total.

### ✅ Historical drift — CORRECTED (H1.4.2, user-authorised)

Both rows were repaired, **database-only: no code, no migration, no generic
backfill**. Full lineage proof in
[`docs/26` §11](26_QUANTITY_COST_AND_VALUATION_AUDIT.md).

| Product | Physical | Old cost | Corrected | Valuation |
|---|---|---|---|---|
| Apple USB-C Cable | 52 | 4.10 | **4.27** | +8.84 |
| Anker PowerCore 10000 | 15 | 8.50 | **8.67** | +2.55 |

Company held value 4 140.70 → **4 152.09** (+11.39).

**A correction is only permitted where the complete chronological ledger
reproduces the actual physical quantity, reserved quantity and branch identity
exactly.** Averaging historical purchase prices is NOT sufficient and produced a
wrong answer here: eight cables were sold between the two deliveries, so the
true cost is 4.27 rather than the 4.25 a purchase-price average gives.

The write was a compare-and-swap on row id, old cost, physical quantity and
reserved quantity together, updating **only** cost, with a durable
`stock.cost_corrected` audit record in the same transaction. Quantities,
reservations, selling prices, purchase lines, supplier payable, sale history and
stored margins were all left untouched — verified by whole-table checksums, of
which only `stock_items` and `audit_logs` changed.

### 🔴 Superseded — the original open item

Two development rows still carry the cost of their **first** receipt: the Apple
USB-C Cable at 4.10 (should be **4.27**) and the Anker PowerCore at 8.50 (should
be **8.67**). **They do not re-average themselves** — the new average takes the
stored cost as its opening value, so the error dilutes but never clears while
any physical quantity remains (corrected in H1.4.2; see
[`docs/26` §9](26_QUANTITY_COST_AND_VALUATION_AUDIT.md)). The correction is
deterministic; the stored values
are stale rather than invalid, so **a backfill needs explicit approval** and was
deliberately not performed.

---

## 7. Goals · 8. Money & reconciliation · 9. Returns

> **I0 audit + approval (2026-08-14):** the Returns rules below were approved
> but almost entirely unimplemented, and the endpoint that existed contradicted
> several of them. Traced in full in
> [`docs/27`](27_RETURNS_AUDIT_AND_DECISIONS.md).
>
> **All eight open decisions are now APPROVED** — see [`docs/27` §14](27_RETURNS_AUDIT_AND_DECISIONS.md).
> Notably: the phone must be physically presented and scanned before approval;
> an approved returned phone is **unsellable**; approval creates **refund_due**
> with payment confirmation separate; accessory charges are **explicit
> adjustment lines**, never netted silently; only the **Owner** may override an
> expired deadline; the first implementation is **serialized phones only**; and
> the original sale and locked closing stay **immutable**, with an approved
> return posting a **dated reversal**.
>
> **"Provisional profit" is a display warning only.** Revenue is recognised at
> sale; closing stays locked and immutable; the reversal is dated its own
> approval day. It does NOT delay recognition or make closing mutable.

> **I1 built the foundation (2026-08-14, migration `0035`).** Three of the
> Returns decisions above are now **implemented**, and one long-standing defect
> is closed. Detail in [`docs/27` §15](27_RETURNS_AUDIT_AND_DECISIONS.md).
>
> - **Per-sale override and server-calculated deadline: DONE.** Every sale
>   carries `return_window_hours` and `return_deadline_at`, snapshotted at
>   completion from the server's own clock and never updated. The shop changing
>   its policy tomorrow cannot reach a sale made today — in either direction.
>   Two CHECK constraints make "no returns" and "has a deadline" unable to
>   disagree.
> - **Who may change it: DONE.** `return.policy.override` (Manager and Owner).
>   Re-stating the shop default is not an override; a real change is refused
>   without the permission rather than quietly downgraded, demands a reason, and
>   is audited. A positive window may be removed or extended but **not shortened
>   to another positive value** — trimming 48 hours to 2 sells a worse promise
>   under the same banner, while 0 is explicit and stated at the till.
> - **Reading sales is a permission: DONE.** `sale.view`, branch-scoped, held by
>   every store role — deliberately not `report.view`, since seeing what the
>   branch sold is counter work and profit dashboards are not. Cost and margin
>   stay gated by `cost.view` independently.
> - **The unsafe endpoint is deleted.** `POST /sales/:id/returns` answers 410
>   and writes nothing; `returnUnit` and its DTO no longer exist. `sale.return`
>   remains in the catalogue only so older sessions map to a known key — it
>   guards no route, and nothing may be gated on it.
> - **Sale history and search: DONE.** Permissioned, branch-scoped, keyset-paged
>   and searched entirely in SQL, with sale detail showing the snapshotted
>   policy and the server's eligibility verdict.
>
> **Still not built (I2):** ReturnRequest, custody, approval, restocking
> disposition, refunds, idempotent execution, the Owner expired-deadline
> exception, accessory dispositions, and the "provisional profit" display.


> **I2 built the return workflow (2026-08-15, migration `0036`).** Detail in
> [`docs/27` §16](27_RETURNS_AUDIT_AND_DECISIONS.md).
>
> - **Request → investigate → decide: DONE.** An employee raises a return against
>   one serialized sale line and may take the phone in; a manager investigates
>   and assigns responsibility; a manager or owner approves or rejects. Six
>   narrow permissions replaced the blunt `sale.return`.
> - **Owner-only exceptions: DONE.** An expired or absent policy window, and
>   customer-caused damage, each require `return.exception` **and** a written
>   reason. A manager cannot approve either.
> - **Approval creates an OBLIGATION, not a payment.** The state is
>   `approved_refund_due`, the notification says "refund due — NOT yet paid",
>   and there is deliberately no `refunded` state at all. Confirming that money
>   moved is I3.
> - **Immutable dated reversal: DONE.** One append-only row per approved sale
>   line, snapshotting revenue, cost, margin, gross refund, adjustments and net,
>   dated the approval day. The original Sale, SaleItem, Payment and locked
>   closings are never written — verified by checksum before and after.
> - **Approval on an already-closed day is refused with a 409.** No closing is
>   reopened or rewritten, ever.
> - **Adjustments are explicit, audited and server-calculated.** They cannot
>   exceed the gross refund, so a customer never ends a return owing money.
>   Accessory linkage is never inferred — it cannot be, and `docs/27` §16.4
>   shows why.
> - **The returned phone is held as `faulty` and is not sellable.** Rejection
>   hands it back and restores it to `sold` — the only route to that transition.
> - **Profit treatment (corrected in CP4.1):** revenue is reversed by the gross
>   refund, the line's immutable COGS snapshot is credited back, and that same
>   cost is reinstated as **faulty/return-held inventory value** — owned, but
>   never sellable. The profit effect is
>   `− gross refund + adjustments + COGS credit`, so cumulative profit across a
>   sale and its return equals the adjustment income alone. The earlier CP4
>   treatment (no COGS credit, no asset) was a full write-off decided before
>   inspection and was never approved. Impairment or recovery belongs to the
>   later Technician/Owner inspection milestone.
> - **Inventory is reported in three figures:** sellable, faulty/return-held and
>   total owned. One number cannot answer both "what can I sell?" and "what do I
>   own?".
>
> **Still open (I3):** refund payout confirmation, receiving-account selection,
> refund receipt, supplier reimbursement, customer-credit settlement, technician
> inspection and cost recovery, independent quantity-product returns.
>
> **The mobile workflow shipped in CP5.** Returns list, request (scan or manual
> IMEI, or from a sale line), detail with timeline, custody intake,
> investigation with draft adjustments, and role-gated approve/reject including
> the Owner-only exception. Every figure is provisional until approval; an
> approved return says "refund due — payment has not yet been confirmed". The
> word "refunded" appears nowhere in I2.

🟡 **Partly unblocked (0019).** Migration `0019_settings_foundation` created the
two things several of these decisions were waiting on:

- **`company_settings.return_window_hours`** — the configurable window, stored as
  hours with `0` meaning "no returns". `24`, `48` and any custom value are the
  same field, so there is no second flag to contradict it. **Defaults to `0`**:
  today `returnUnit` has no window check at all, and defaulting to a window
  nobody chose would grant a refund period the Owner never agreed to.
- **`receiving_accounts`** — multiple accounts per provider, each with a required
  human label, active/inactive state and an explicit order. Cash is deliberately
  not a row: it is always available and needs no configuration.

Still blocked: goals, progressive reconciliation, per-sale return overrides,
server-calculated deadlines, provisional profit during the window. Those belong
to the Returns and Money workflows, not to settings.

⛔ **The rest remains blocked** — no models exist for goals or progressive
reconciliation.

Recorded decisions, in brief:
- **Goals:** types (gross-profit amount, units sold, product/exact-variant quantity) · scopes (business, branch, employee, category, exact variant) · periods (daily, weekly, monthly, custom) · visible to Owner and Manager only · returns reduce progress · pending costs make progress provisional · sale credit belongs to the assisting employee, correctable by a Manager with audit · in-app notifications at 50/80/100%, behind-target, period-end · **never via WhatsApp**.
- **Money:** the app records money movement, it does **not** process customer payments · destinations are Cash, a configured receiving account, or Awaiting money · Owner configures accounts (multiple per provider, labelled) · employee reports receipt, Manager/Owner confirms · reconciliation is progressive (ask total first; only open per-account detail on mismatch) · results classify as Balanced/Short/Over · a shortage starts as **Pending investigation** and **never automatically creates employee debt**.
- **Returns:** configurable window (none/24h/48h/custom), per-sale override, server-calculated deadline · unit marks Sold immediately and counts in daily totals · **profit stays provisional during the window** (this affects the existing rollup design) · lookup by IMEI or secure receipt QR · approved returns are for defects only; customer damage rejected unless the Owner makes an exception · consumed screen protector must be paid for · returned phone becomes **Faulty awaiting inspection**, not sellable · refund method chosen by Manager/Owner · all changes audited.
- Warranty and technician workflows are **explicitly postponed**. Do not design them now.

---

## 10. Expenses, summaries, consignment, auth, offline, subscription

⛔ **All blocked** — no supporting models or APIs. Decisions recorded here so they survive:

- **Expenses:** variable expenses hit daily profit; **fixed recurring expenses do not** — they belong to monthly accounting only. Monthly fixed entries may be prepared automatically but need Owner confirmation. Blank expense explanations warn once, may still be approved, and are audited as approved-without-clarification. Employee balances may be deferred, deducted, partially or fully forgiven — forgiveness needs confirmation and audit.
- **WhatsApp summaries:** daily (sales, gross profit, variable expenses, commissions separately, operating profit before fixed costs) and monthly (adds rent, salaries separately, net profit, outstanding receivables). Owner chooses language and whether amounts appear at all. External commissions are other income and do not touch inventory.
- **Inter-store consignment:** permanent Store ID · public search exposes only name, logo, city and a "Coming soon" verified badge · blocking never erases debts · receiver sees phone info but never sender cost, margin, customer or resale price · sender records the agreed amount, receiver keeps resale upside · partial payments; sender confirms before balances move · forgiveness is a write-off, not a payment · disputes carry counteramount, reason, evidence and full history · navigation is Needs Attention / Active / Closed.
- **Auth:** WhatsApp/phone verification, optional email recovery, OTP only for new device / explicit logout / revoked or expired session — **not** merely because the app closed or lost network · private passcode + optional Face ID · auto-lock choices with **no "Never"** (🟡 the *business maximum* is now stored and validated in `company_settings.auto_lock_max_seconds` — 0/30/60/300/900 seconds, with no value able to express "never"; the per-user preference still belongs to the Users API) · 5 failures cooldown, 10 require OTP · Owner may revoke devices but never see or reset a passcode · employee onboarding by temporary ID / one-time code / QR · **no fake email accounts**.
  ✅ **Store ID is the pre-login tenant selector (F1 Stage 3.2).** The permanent, public **Store ID** (the same identifier the consignment decision above relies on) now gates login: sign-in is `{ Store ID + login + password }`. The server resolves the company from the public Store ID *before* finding the user, so the same `login` (e.g. `owner`) can exist in many companies without collision, and a Store-ID/login mismatch fails with a single non-enumerating error. It is a shareable code shown to the Owner, **never a secret or a password**, and it is not the internal company id, a branch id, a device id or a subscription id. The mobile keys its per-device credential by Store ID + login so no company's device credential can cross into another's. See [`docs/23`](23_USERS_AUTH_AUDIT_AND_PLAN.md) Stage 3.2.
- **Product catalog (G1 — implemented):** **one Product row IS one exact sellable variant** (iPhone 13 Pro Max · 256 GB · Sierra Blue), enforced by the existing `UNIQUE(company_id, brand, model, variant)` plus a bounded `specifications` JSON; brand/model group for display only and never erase variant identity. Tracking mode (IMEI / serial / quantity) is chosen at setup, defaults from the category, and **freezes once units, stock, purchase or sale history exist** — reinterpreting existing history is not an edit. IMEI/serial belong to received **Units**, never to the product definition; defect/condition stays optional at receiving. Barcode is optional, normalized, unique per company, and a conflict is a **409, never a silent re-attachment**; moving a barcode moves its scanner-learning alias so the old code cannot resolve to the wrong product. **Costs belong to receiving/unit/stock, not to product metadata**, and cost/price/margin keys are rejected inside specifications. **No hard delete:** archiving hides a product from the catalog and receiving selectors while existing stock stays visible in Inventory and **stays sellable until depleted**; restoring is always possible; status shows in colour *and* words. Catalog administration is gated on a new narrow **`catalog.manage`** (Owner ✔ · Store Manager ✔ · Store Employee ✘), which is branch-scoped — the catalog is company-shared, but a manager acts within a branch they are assigned to. **`catalog.manage` never implies `price.edit`.** See [`docs/23`](23_USERS_AUTH_AUDIT_AND_PLAN.md) and migration `0026`.
- **Price ownership (unchanged by G1):** the authoritative selling price today is the price typed at sale time, falling back to **`Product.defaultPrice`**; quantity stock additionally carries **`StockItem.price` per branch**. **`Unit` has a per-unit `cost` but no per-unit price** — so an exact serialized price does not exist yet. G1 only *displays* existing price information and introduces no competing source; the per-unit / per-variant price workflow is the **next Pricing milestone**.
- **Offline:** essential. Visible status by colour **and** words (Offline · N waiting / Syncing / Synced) · cache only the user's branch data · queue with stable IDs · **never silently resolve conflicting IMEI transactions** — first server-valid wins, the other freezes in a Conflict Center for Manager/Owner · offline manually-entered unknown IMEIs are High-risk pending review.
  *Note:* `SyncDevice` and `OutboxChange` models exist but are unused; `clientUuid` idempotency is already honoured by Sell.
- **Subscription:** 500 MRU per branch per month, monthly only at launch · Owner seat free · two pooled employee seats per branch, extra seats 100 MRU, charged in full mid-cycle, no refunds, seat reusable to period end · unified renewal date, prorated first partial period · 72-hour grace, then employees lose transaction creation while the Owner keeps read-only and export · **never auto-delete business data**.
  **Mobile app must contain no price, no amount, no payment method, no payment button, no website link and no purchasing flow.** Approved copy: *"Subscription access ends in X days. Check the message sent to the Owner's WhatsApp for renewal information."*
  All payment integration is website- and server-side only, provider-independent, activated by verified invoice reference — **never by amount alone**.

  ✅ **RESOLVED — no automatic free trial.** Registration and basic business setup may be completed, but **operational access requires an active entitlement**: paid, promotional, partner, or manual exception. Promotional access must be granted deliberately by a Platform Administrator and must record **issuer, reason, start date and expiration date**. Activation instructions reach the Owner externally over WhatsApp.

  ✅ **RESOLVED — grace behaviour.** After the 72-hour grace period, employees lose *operational* access while the **Owner retains read-only and export access**. Renewal restores all data and **never charges for inactive months**.

  This makes **entitlement, not payment, the access gate** — the two must stay separate in the data model.
  ⚠️ **Bankily has no confirmed public API.** Do not implement a guessed integration. Moosyl may be evaluated but must not be treated as an official Bankily API without contractual and technical verification.

---

## 11. Open issues carried forward

| Issue | Status |
|---|---|
| `warehouse_employee` 403 on `POST /purchases` | ✅ **Resolved by the role decision** (§2) — Store Employee sells *and* receives, so the split that caused it disappears. |
| Scanner teaching lowers confidence 1.0 → 0.333 | Confirmed by measurement. A learned mapping should never score below the deterministic fallback for the same code. Backend fix, not yet made. |
| Branch naming / `BranchType` | ✅ **Direction set** (§11a below). Branches are physical locations; store vs warehouse is not a user-facing entity type. Avoid generic names like "Warehouse". |
| MRU decimals | Currently 0 decimals in display, full precision retained internally. ❓ Still needs explicit confirmation. |
| Missing APIs | customers, settings, users, branch management, `PATCH /products`, supplier payments, pagination |
| Device-only verification | camera scanning, haptics, Arabic RTL end-to-end, receipt sharing |

### 11a. `BranchType` audit

Requested before proposing any migration. The concept is **shallower than expected** — three references, none of them business logic:

| Location | Use |
|---|---|
| `prisma/schema.prisma:41,189` | `BranchType` enum + `Branch.type` field, defaults to `store` |
| `backend/src/rbac/access.service.ts:56` | passes `type` through in `getUserBranches` — read only |
| `mobile/app/select-branch.tsx:41,45` | picks a Warehouse vs Store icon, and prints the type as a label |

**No permission, stock, transfer or pricing behaviour depends on it.** Nothing branches on the value. Removing it is a display change plus a column drop — not a behavioural migration.

Live data: two branches — `Main Store` (`store`) and `Warehouse` (`warehouse`). The latter is exactly the generic name ERP.docx §8 forbids, so it needs renaming to something meaningful regardless of the enum's fate.

---

## 12. Migration order

Every step is independently revertible and leaves the app working. Nothing below has been implemented.

### Step 0 — Safety, before any backend migration
Backend is unversioned. See §13. **Do not start Step 1 until this exists.**

### Step 1 — Role model *(no call sites, 5 data rows)*
1. Add `store_manager` and `store_employee` to the `RoleKey` enum. **Add only** — do not drop anything yet.
2. Seed the two new roles with their permission sets. Store Employee gets `sale.create`, `sale.return`, `discount.apply`, `unit.add`, `unit.transfer`, `purchase.manage`, **`cost.view`** — deliberately *without* `report.view` or `expense.manage`, keeping cost visibility separate from profit/report management.
3. Remap the 5 existing `UserBranch` rows: `sales_employee` → `store_employee`, `warehouse_employee` → `store_employee`. `branch_manager` → `store_manager` (currently 0 rows).
4. Verify: log in as each migrated user, confirm the tab set and that receiving no longer 403s.
5. **Only then**, in a separate later migration, retire the unused enum members once nothing references them.

Retaining `administrator` is optional — it maps to the internal Platform Administrator, which is not a store role. Recommend keeping the record, removing it from the store-facing matrix.

### Step 2 — Branch naming
1. Rename the branch literally called "Warehouse" to a meaningful location name.
2. Drop `BranchType` from the mobile display (icon + label) — 2 references.
3. Leave the column in place initially; drop it in a later migration once nothing reads it. It has no behavioural dependents (§11a).

### Step 3 — Settings API ✅ DONE (0019)

`GET/PUT /settings` plus `POST/PATCH /settings/receiving-accounts` and
`PUT /settings/receiving-accounts/order`. Owner writes require
`settings.manage`; the read is open to any signed-in user but the **response is
narrowed by permission** — an employee receives the return window, the auto-lock
maximum and the *active* account labels, and never the WhatsApp preferences, the
concurrency token, or inactive accounts.

**What the audit found first (E1), and how it was reconciled:**

| Existing thing | Decision |
|---|---|
| `settings` key/value table (`low_stock_threshold`, `dead_stock_days`, `health_score_weights`, `transfer_prefix`) — live, read directly by the analytics services, with no API, validation, audit or guard | **Kept as-is** and documented in the schema as *internal tuning only*. Owner-facing policy must not go here |
| `settings.whatsapp_schedule` (`{enabled, time}`), seeded but read by **no code** | **Removed** in 0019. Two answers to "is the summary on?" is exactly the duplicate concept this step exists to prevent |
| `companies.settings` JSON blob, seeded to `{}`, read by nothing | **Left untouched, deliberately unused.** E3 rules out an unrestricted JSON blob for policy |
| `settings.manage`, already guarding `POST/PATCH /categories` and `PUT /transfers/config/prefix` | Reused. No new permission was invented |
| `PaymentMethod` enum (`cash card mobile bank other`) | Left alone. `ReceivingProvider` is a different axis — *which shop account*, not *how the customer paid* |
| `returnUnit` — **no time-window check exists anywhere today** | The field is stored and validated; nothing reads it yet. Enforcement belongs to the Returns workflow |

**Scope decision:** company-wide, not per branch. The approved decisions describe
one return policy, one set of shop accounts, one Owner receiving summaries and
one security floor. `Setting` already supports a branch dimension; adding one
here would have been inventing a requirement.

**Deliberately excluded:** MRU decimals, subscription pricing, payment
configuration, Bankily API credentials, website links, warranty/technician
settings, customer credit, and branch naming/type.

**~~Web-only BottomSheet defect~~ — WITHDRAWN. This was a measurement artifact,
not a defect.** The E5 report claimed `BottomSheet` never animates in on Expo
web and stays parked at `translateY(<screen height>)` with the backdrop at
`opacity: 0`.

Re-checked in E.2 with the obvious question asked first: **is the page actually
animating anything?** It is not. In the automated browser pane
`document.visibilityState === 'hidden'` and a `requestAnimationFrame` loop
delivers **0 frames**. Reanimated drives web animations from rAF, so *every*
animation in the app is frozen at its initial value there — and the initial
values are exactly `translateY = screenHeight` and `opacity = 0`, the two
numbers that were reported as the bug.

No change was made to the sheet. Nothing was proven broken, and speculatively
editing the primitive that every picker, scanner and confirmation sits on —
with no device or emulator to check native behaviour against — would have been
the larger risk.

**How to actually verify sheets:** on a physical device or emulator, or in a
browser whose tab is genuinely visible. Any animation assertion made through a
hidden/headless pane is meaningless. This applies to the toast and dialog hosts
too.

**Known gap left in place:** `settings.discount_limits_by_role` still names the
retired `sales_employee` and `branch_manager` roles. Nothing reads it, so it was
not touched here; it belongs with discount monitoring.

### Step 4 — Users API
Employee onboarding, seat allocation, and the approvals model that Goals, Returns and Consignment all depend on.

### Step 5 — `Unit.price` override ✅ DONE (0027), as three tables not a column
Delivered by `0027_pricing_foundation` (§6). A nullable column on `Unit` was
rejected: it cannot record the branch authority that set the price, and a column
cannot be made append-only. Schema only — resolution, APIs and UI are CP3.

### Step 6 — Inventory pagination
Cursor or `hasMore`/`total`. Required before any store approaches 200 rows (§3).

### Then — screens needing only what exists
Product Details · Categories · Suppliers · Transfers.

### Then — larger modules, in dependency order
Approvals → Returns (window + provisional profit) → Money & reconciliation → Goals → Excel intake → Offline sync + Conflict Center → Consignment → Subscription website.

Warranty and Technician stay last, by decision.

---

## 13. Version-control plans *(proposed — not executed)*

Git structure must not be changed automatically. These are proposals for approval.

### 13a. Backend rollback safety

`backend/` and the repo root are not git repositories, so backend edits are currently unrecoverable. Options, cheapest first:

**Option A — initialise `backend/` as its own repository** *(recommended)*
- Mirrors the existing structure, where `mobile/` is already standalone.
- Needs a `.gitignore` covering `node_modules`, `dist`, `.env` **before** the first `git add` — `.env` holds `OWNER_SEED_PASSWORD` and DB credentials and must never be committed.
- Zero effect on `mobile/` history.

**Option B — one repository at the project root**
- Cleaner long term, keeps backend and mobile in step.
- More disruptive: `mobile/` history would need to be preserved via subtree merge, or the nested repo left as-is.

**Interim safety, available immediately:** a timestamped copy of `backend/src` and `backend/prisma` before each migration. Crude, but it beats nothing and costs seconds.

Whichever option: take a **database dump before each schema migration**. Application-level rollback does not undo a migration.

### 13b. Untracking `node_modules` in `mobile/`

10,531 tracked files. The fix must not delete the local installation or lose history.

```bash
# 1. Confirm the ignore rule exists first
grep -q '^node_modules' mobile/.gitignore || echo 'node_modules/' >> mobile/.gitignore

# 2. Remove from the index ONLY — --cached leaves files on disk untouched
git -C mobile rm -r --cached node_modules

# 3. Verify the working tree is intact before committing
ls mobile/node_modules | head

# 4. Commit the removal
git -C mobile commit -m "chore: untrack node_modules"
```

`--cached` is the critical flag: it untracks without touching the filesystem, so the install survives and no reinstall is needed.

**Scope note:** this removes them from *future* commits. History still contains them, so the repository stays large on disk. Rewriting history (`filter-repo`) would shrink it but rewrites every commit hash — not worth it unless clone size becomes a real problem. Since these files were never committed to a shared remote in a meaningful history, the simple untrack is the proportionate fix.


---

## 6f. Refund payout — I3, SHIPPED

### ✅ APPROVED and implemented — reporting is not paying

A refund has **three separate moments**, and collapsing any two of them is how a
shop pays a refund twice:

1. **Approval** reverses profit and creates the obligation.
2. **Reporting** records that a person handed money over. It is a *claim*: no
   cash movement, no change to what is owed. An **Employee** may do it.
3. **Confirmation** is the record. Cash leaves, the liability settles, and there
   is **no second profit effect**. Only an **Owner or Manager** may do it.

The app says so in words at every step, and only a confirmed refund is ever
shown in a success tone. The phone stays `faulty` and not for sale throughout —
settling the money does not put the handset back on the shelf.

### ✅ APPROVED — the amount cannot be negotiated at the counter

Locked to the immutable net refund due. No partial payout; a payout that does
not match it is a different obligation, not a correction. A Manager may correct
**how** it was paid — method, account, reference, note — never how much.

### ✅ APPROVED — an account label is frozen, not looked up

Captured when the payout is reported and frozen at confirmation. Renaming an
account must not retitle a movement that already happened, and deactivating one
must not strand a refund already owed: reporting needs an active account,
confirming does not.

### ✅ APPROVED — no provider is ever implied

Cash or account only. The app performs no balance lookup, holds no credential,
calls no payment API, and the receipt claims no bank or provider verified
anything. It records what a person says happened at the counter.

> Detail, and the 55 live checks behind it, in
> [`docs/27` §20](27_RETURNS_AUDIT_AND_DECISIONS.md).


---

## 6g. Supplier payables — J1, SHIPPED

### ✅ APPROVED — the app records payments, it does not move money

No provider is called, no balance is looked up, no credential is held. A
supplier payment is what a person says happened at the counter, and the shop's
own purchases are what it is measured against.

### ✅ APPROVED — a purchase creates the debt, only confirmation settles it

Three moments, kept apart for the same reason refunds keep theirs apart:

1. **Purchase** creates the payable.
2. **Report** records that somebody handed money over. No cash movement, no
   change to what is owed. An **Employee** may do it.
3. **Confirmation** settles the liability exactly once and books the cash
   movement on the confirmation day. Only an **Owner or Manager** may do it, and
   it has **no profit effect** — inventory cost reaches profit through COGS when
   the goods sell.

### ✅ APPROVED — the debt is derived, never a stored counter

Outstanding = purchase totals − confirmed allocations. Purchase totals are never
rewritten to express payment; `amountPaid` and `status` are projections.
`Supplier.balance` survives as a cache with a drift check.

### ✅ APPROVED — money is allocated explicitly, and overpayment is refused

A payment names which deliveries it settles. Oldest-first is a suggestion the
person sees before sending, never a silent server decision. Partial payments are
allowed; overpayment is refused, including when two managers confirm at once.

### ✅ APPROVED — suppliers are deactivated, never deleted

An inactive supplier vanishes from new receiving and stays in every history.
Nothing referenced may be hard-deleted.

### 🔴 REQUIRED, NOT BUILT — controlled correction after confirmation

Neither a confirmed supplier payment nor a confirmed refund can be reversed.
That is deliberate for now, but a real mistake currently has no route back.
**A reviewed correction workflow is required before either is considered
finished.**

> Detail, and the 52 live checks behind it, in
> [`docs/28` §5](28_SUPPLIERS_PAYABLES_AUDIT.md).

---

## Milestone B — correcting confirmed money (approved, implemented)

**A confirmed refund payout and a confirmed supplier settlement can be
corrected, and neither is ever edited.** A correction is an append-only record
beside the original; the liability returns because every derivation of "what is
owed" excludes a payment carrying an approved correction.

- `financial.correction.request` — Owner and **Store Manager**.
- `financial.correction.approve` — **Owner only.** Approving is what actually
  restores a settled liability.
- A Store Employee holds **neither**. The person who reported a payment must not
  be able to open the process that unwinds it.

**The compensating movement posts to the current open business day**, never to
the day of the original payment. If today is closed, the correction waits — a
filed closing is never reopened. The original day keeps its figures, and its
receipt is never rewritten; a corrected receipt gains a `correctedAt` field and
nothing else changes.

**A correction moves cash and liability only.** No sale, no expense, no second
return profit effect. Profit was reversed at return approval; a supplier payment
never had one.

At most **one approved correction per payment**, enforced by the database. A
replacement payment may follow — which is why `0041` moved the payout uniqueness
onto "one *live* payout per return".

> Detail and the 41 live checks in `docs/29` §10 and the migration headers for
> `0040`/`0041`.

---

## Milestone C — TAC recognition: two layers, never merged (approved, implemented)

**Decided:** a **per-company overlay**. A store user's confirmation must never
write into or rename the globally shared `tac_catalog`.

| | `tac_catalog` | Company TAC mapping (`product_recognition`) |
|---|---|---|
| Scope | **Global**, shared by every company | **Company-scoped** |
| Control | Platform only | The shop itself |
| Holds | Generic manufacturer / model / TAC | That company's own **Product** |
| Written by | Reviewed, official or licensed data, later | Explicit store confirmation |
| Store users | **Never write to it** | Propose and confirm |

A global record **never points at one tenant's Product** — the table has neither
a `company_id` nor a `product_id`, so it cannot, even by mistake.

**Authority:** an **Employee may propose** a mapping while receiving; **Owner
and Store Manager confirm** it. No new permission was created: `unit.add`
already gates receiving and all three store roles hold it, and `catalog.manage`
already means "manage the product catalog", which is what deciding a code's
product is. The **service** decides proposal-versus-confirmation from the
caller's permission, so a client cannot assert an authority it does not have.

**The resolution ladder is deterministic:**

1. a **confirmed** company mapping returns that company's exact Product;
2. a **pending proposal** is shown, flagged, and returns **no product id** — it
   can never be auto-selected;
3. otherwise the global catalogue gives **manufacturer and model only**;
4. otherwise **unknown**, and a human chooses.

**Storage, colour, condition, cost and selling price are never inferred from a
TAC.** Confidence is reported but never used to demote a confirmed mapping.
Conflicting evidence requires explicit review rather than a silent pick, and a
replaced mapping is **superseded, never deleted**.

**Dual-SIM:** two TACs describe **one** phone. Agreeing is one strong
suggestion; one resolving is still usable; **disagreeing blocks automatic
selection**, because picking one would create a record for a device that does
not exist.

> Detail in [`docs/30`](30_IMEI_OCR_AND_TAC_AUDIT.md); 41 live checks behind it.

---

## Milestone D — expenses and controlled cash outflow (approved, implemented)

**Two accounting classes, and the difference is not cosmetic.**

- **Variable** — electricity, food, supplies, transport. Counted on the day it
  is **confirmed**.
- **Fixed** — rent, salaries, recurring owner-defined costs. Counted on its
  **due date**, and never spread across every day.
- **Salaries** are summed separately from other fixed costs. No payroll
  calculation beyond the approved employee salary fields.

**The workflow.** Reported → confirmed or rejected. A report changes no cash, no
account, no profit and no report figure. Only confirmation does, exactly once. A
confirmed expense is immutable: a mistake is put right through Milestone B's
append-only correction workflow, never by editing or deleting.

**Permissions — a three-way split.** The seed used to note that the model could
not express "submit" separately from "manage"; it can now.

- `expense.submit` — Owner, Store Manager, **Store Employee**. The person who
  spent the money reports it. **A submitter sees only their own expenses**, so
  reporting never hands somebody the shop's whole outgoings.
- `expense.review` — **Owner only.** Confirming is when the money counts as gone.
- `expense.manage` — **Owner only, unchanged.** Categories, templates, settings.
  Deliberately **not** widened.

**A missing reason** is an explicit `reasonOmitted` state, never invented copy.
The Owner is asked *"Are you sure you do not want to clarify the reason?"* and
may proceed — "Miscellaneous" in a ledger is indistinguishable from a real
category a year later.

**Accounts.** Reporting requires an **active** account; the label is snapshotted
at report time, so a later rename or deactivation cannot retitle the movement or
strand its confirmation.

**The reconciliation equation**, with every movement appearing exactly once:

```
expected cash = cash taken in
              − refunds paid in cash
              − supplier payments in cash
              − expenses paid in cash
              + corrections returned in cash
```

Pending reports appear nowhere. **A supplier payment and a refund remain
liability settlements, not expenses.** Milestone E builds on this equation and
must not create a second closing system.

> 45 live checks. Detail in the `0044` migration header.

---

## Milestone E — the closing becomes progressive, per-channel and answerable

### What the E0 audit found

Three things, and the first stops an employee working.

1. **An Employee could not enter a count at all.** `closing.perform` recorded
   the count *and* locked the day, and only Owner and Manager held it. So the
   person physically holding the drawer could not report what was in it without
   somebody senior standing there.
2. **The closing was cash-only.** A shop taking Bankily had no expected figure
   for it, so an account could drift indefinitely and nothing noticed.
3. **A difference had nowhere to go.** It was a number on a locked row: no
   investigation, no decision, no record of who was held responsible, no ledger
   if somebody agreed to repay. A shortage was either silently absorbed or
   settled verbally.

### The asymmetry that had to be fixed first

Money going **out** was already attributed to an account — `refund_payouts`,
`supplier_settlements` and `expenses` all carry `receiving_account_id`. Money
coming **in** was not: `payments` recorded only a method, so a per-account
expected figure was arithmetically impossible.

`0045` adds it and the sell flow now sets it. **Payments taken before `0045`
stay NULL and are reported as unattributed**, never guessed into an account —
inventing which account a sale from six months ago reached would be fabricating
a financial record. Unattributed money is shown and is deliberately **not
countable**: there is no balance behind it to compare a count against.

### Counting and signing off are two acts

| Permission | Held by | Means |
|---|---|---|
| `closing.count` | Owner · Manager · **Employee** | Record what is in front of you. Locks nothing. |
| `closing.perform` | Owner · Manager | Sign the day off. The figures become a snapshot. |
| `debt.manage` | **Owner only** | Decide who is responsible, collect, or forgive. |

`debt.manage` is deliberately **not** folded into `closing.perform`, which a
Manager holds. Deciding that a named person owes the business money is not an
operational act.

**A locked day stays locked.** Correcting one goes through Milestone B's
append-only correction workflow, never by reopening.

### The equation is extended, never forked

Every channel uses the same five movements with the same signs the till uses:

```
expected = sales in
         - refunds out - supplier out - expenses out
         + corrections in
```

Cash is simply the channel whose account is NULL. The signs live in one table
(`channels.ts`), and `reconciliation.spec.ts` asserts the closing computes no
expected figure of its own.

**Which channels must be counted**, and why each rule exists:

- **Cash always**, even on a day with no movement. A day where nobody counted
  the drawer must not read as balanced.
- **Every active account**, even with no movement - an account that did nothing
  should still be confirmed as unchanged.
- **A deactivated account that moved money today.** Otherwise deactivating an
  account would be a way to stop reconciling it.
- **A skip is recorded with a reason**, never inferred from a missing count.
  An account balance cannot always be read at closing time; silence and a
  decision must not look the same.

### A difference becomes a question

A discrepancy opens `pending_investigation` and is **never auto-assigned**. The
system observes that a channel is out; it does not accuse whoever was counting.
A skipped or uncounted channel opens nothing - nobody claimed a figure, so there
is nothing to disagree with.

Rules that protect the person on the wrong end of a shortage:

- **Every resolution requires a reason.** There is no resolving one silently.
- **Naming somebody and then absorbing the loss is refused** - that records an
  accusation that led to nothing.
- **A surplus can never become a debt.** Nobody owes money for having too much
  of it; unexplained extra cash is a mis-recorded sale until shown otherwise.
- **A charge can never be posted directly.** It comes only from resolving a real
  discrepancy - otherwise it is a way to make somebody owe money with no till,
  no day and no shortage behind it.
- **Settling more than is owed is refused**, which catches the same repayment
  entered twice.
- **Forgiving writes both the charge and the waiver**, so an Owner can still see
  somebody came up short three times even when every one was forgiven.

**The balance is derived from the ledger every time and stored nowhere** - a
stored balance can disagree with its own history. It is not clamped at zero
either: if the shop has taken more than it was owed, that shows as negative
rather than being swallowed. The ledger is append-only, enforced by triggers.

`GET /debt/me` is deliberately ungated. Somebody being asked to repay money
should never need permission to see the record of it; it reads only their own
rows, and reading anybody else's needs `debt.manage`.

> 72 live checks. `0045` carries the schema reasoning; `0046` records a
> constraint `0045` got wrong - see below.

### A constraint `0045` got wrong, and how it was found

`ck_closings_counted_fields` asserted `(status = 'counting') = (counted_at IS
NULL)`: a day still being counted has nobody's count on it. That reads
plausibly and is wrong. A shop that has counted the drawer but not yet checked
its Bankily balance is legitimately **both** `counting` **and** holding a real
count - so the first live count against a multi-channel day failed with MySQL
3819.

No unit test could have caught it: the rule only breaks once a real second
channel exists, which is exactly what the live run supplies. `0046` replaces it
with the two rules actually meant - the *who* and the *when* travel together,
and `counted` implies somebody counted.

---

## Milestone F — goals

### What the F0 audit found

Nothing. No goal model, no service, no screen. But two things already existed
and neither may be duplicated.

`daily_rollups` already carries revenue, gross profit, sales count and units
sold per branch-day, and already accounts for returns. A goal asks a different
question — progress toward a target over a period — but it asks it of the
**same figures**. Recomputing them would create a second definition of gross
profit, which is exactly the drift Milestone E spent a checkpoint pinning shut.

`sales.user_id` is immutable, so per-person attribution needs no new column. A
sale belongs to whoever made it, permanently — credit cannot be reassigned after
the fact, which is what makes a personal target trustworthy.

### Progress is derived, never stored

Recomputed on every read, the same rule the employee debt balance follows. A
stored figure can disagree with the sales it claims to summarise, and it would
need invalidating on every sale, return, refund and correction. `0047` has no
progress column at all, and `goals-source.spec.ts` asserts it never gains one.

### What a goal may measure, and what it may not

| Metric | Reads |
|---|---|
| `gross_profit` | `daily_rollups.gross_profit` (returns already deducted) |
| `revenue` | `daily_rollups.revenue` |
| `sales_count` | `daily_rollups.sales_count` |
| `units_sold` | `daily_rollups.qty_sold` |

**There is deliberately no `net_profit`.** Expenses are not the salesperson's
doing, and a target somebody cannot influence is not a goal, it is a grievance.
Enforced in the mapping, the DTO validator and the database enum — all three.

Per person, `sales_count` counts **sales, not lines**. Three phones on one
receipt is one sale, which is what "how many sales did you make" means to the
person being measured; summing lines would flatter whoever sells in bundles.

### The words a goal answers in

`not_started` · `on_track` · `behind` · `met` · `missed`

Two of these carry a decision:

- **A target reached reads as `met`, not as ahead of pace.** Somebody who hit
  their month on the 8th should be told they made it — that is the news.
- **A closed period that fell short is `missed`, not `behind`.** Nothing can be
  done about it, and calling it "behind" asks somebody to catch up on days that
  no longer exist.

Pace is `null` before a period starts, because pace against zero elapsed days is
not a number. The percentage is uncapped — 103% is worth knowing — while the
progress bar caps visually, since a fill that overflows its track just looks
broken.

### Scope, and who may see what

A personal goal is **branch-scoped**: somebody working across two shops has two
jobs, and one merged number would hide which is going badly.

| Action | Who |
|---|---|
| Set or archive a goal | `goal.manage` — Owner and Manager |
| Read a goal | **Ungated** |

Reading is ungated on purpose. An employee with a personal target must be able
to see it, and `report.view` — the obvious-looking gate — would hand them the
shop's profit reporting at the same time. That is exactly the split `cost.view`
and `report.view` already keep apart.

Somebody else's personal target answers **404, not 403**, so the existence of
another person's number is not itself disclosed.

### Archived, never deleted

With a mandatory reason. A goal that was missed is a fact about the shop's
history, and deleting it would make every past period look met. Archived goals
are out of the way by default and still readable on request; the active-row
uniqueness is on a generated column, so two live targets for the same person,
metric and period cannot both exist — "am I on target" has one answer.

> 34 live checks, green on the first run. `0047` carries the schema reasoning
> and was proven on a restored copy first: 14 constraint cases against real
> MySQL, including all four half-scoped goals refused.

---

## Milestone G — bringing a shop's stock list in

### What the G0 audit found

1. **The schema existed; the feature did not.** `import_batches` and
   `import_rows` already modelled a proper parse → preview → commit flow with
   per-row `valid`/`warning`/`error`. Nothing was ever built on them.
2. **`import.run` guarded nothing.** Granted to Owner, Manager and the legacy
   warehouse roles, labelled "Run Excel/CSV inventory import", and present in
   zero `@RequirePermissions`. A permission that guards nothing is a promise the
   app does not keep.
3. **No spreadsheet parser was installed.**

### The dependency, and why it was asked about

`exceljs` (MIT) was added with approval, because the rulebook makes a new
dependency a major change. The deciding argument was not convenience: **Excel in
an Arabic locale exports CSV as windows-1256**, which silently mangles Arabic
product names into characters a shopkeeper can neither recognise nor fix. A
`.xlsx` carries UTF-8 natively and avoids the whole class of problem.

CSV is still supported, through a **hand-written** RFC 4180 reader. The format
is small enough that a correct implementation is shorter than the argument for
another dependency, and the cases that break real files are exactly what
`split(',')` gets wrong: a comma inside a product name, a newline inside a
quoted note, and the byte-order mark Excel writes — which, left in place,
becomes part of the first header and makes the IMEI column invisible.

**The delimiter is detected, never configured.** "Is your file comma or
semicolon separated" is not a question a shop can answer.

### Columns are guessed, then shown

A shop's list was written by the shop: `imei`, `IMEI No`, `الرقم التسلسلي`.
Making somebody map twelve columns by hand before importing anything is the
step where people give up and go back to the notebook. So the mapping is
guessed and displayed for confirmation; nobody builds one from nothing.

Arabic headers normalise alef, ya, ta-marbuta, diacritics and Arabic-Indic
digits, because `الماركه` and `الماركة` are the same word to everybody except a
string comparison, and which one appears depends on the keyboard.

**What kind of stock a sheet describes is decided by its identifier column**, not
asked. A column of IMEIs is phones. Asking again is asking somebody to restate
their own file.

**Three columns are required** — an identifier, a product name, and a cost — and
every missing one is reported at once. Cost is required as a product decision:
stock imported without it reports infinite margin on every sale, and the shop
finds out only once the profit figures are already wrong.

### A bad row fails alone

200 phones with three mistyped IMEIs gives **197 phones and three things to
fix**. All-or-nothing sounds safer and is, in practice, what sends somebody back
to the notebook. What makes it safe rather than sloppy is that **nothing is
written until the shop has seen the count**.

| Case | Verdict | Why |
|---|---|---|
| IMEI fails its check digit | **error** | The worst outcome of an import is a phone that looks imported and can never be found by scanning the real one |
| No cost | **error** | Infinite margin on every sale |
| Cost is zero | **warning** | Free stock is real; a whole column of zeros is more likely an empty column |
| Price below cost | **warning** | Clearance is a real decision, and also what a swapped column looks like |
| Already in stock / twice in the file | **error**, worded differently | The two need different fixes |

A **warning imports**. A warning that blocks is an error with a friendlier
colour, and it teaches people to ignore both.

### Other decisions

- **The uploaded file is never written to disk.** A stock list is commercially
  sensitive; keeping a copy nobody asked us to keep is a liability with no
  matching benefit. What persists is the parsed result.
- **A file whose columns cannot be understood is recorded as `failed`, not
  refused.** The shop can then see which columns were found and which were
  missing.
- **Quantity stock merges.** 50 cables imported onto an existing 20 makes 70,
  not two rows nobody can reconcile.
- **Forty A15s make one product**, matched on brand + model + variant, or they
  could never be reported on together.
- **Row numbers are the shop's own** — the first data row is line 2, because
  line 1 is the header they can see.
- **A committed batch is never deleted.** It is the record of where the stock
  came from.

> 41 live checks, green on the first run, including a real `.xlsx` with Arabic
> headers and an empty leading worksheet. `0048` carries the schema reasoning.

---

## Milestone H — inter-store consignment

*Approved and implemented. Schema `0049`. 71 live checks across two temporary
companies, green.*

### The binding architectural decision

**Consignment does not extend `StockTransfer`.** Not the model, not the routes,
not the permissions, not the lifecycle. A transfer moves stock between two
branches of one company; a consignment moves it between two companies that must
never see each other's books. Reusing the transfer would have put a
cross-company row inside a structure whose every query assumes one tenant — the
kind of reuse that looks economical until the day it leaks.

What *was* reused is the thinking: compare-and-swap reservation, idempotency
keys, optimistic versioning, immutable money ledgers, notifications and audit.

### Privacy is structural, not careful

The rule is not "the screens are careful not to show cost". It is that **the
other side's cost never reaches the client at all** — `consignment_lines` has no
cost column, and the API for the receiving company cannot select what does not
exist. A screen cannot leak what it never receives.

| Store 1 (sender) never learns | Store 2 (holder) never learns |
|---|---|
| Store 2's resale price | Store 1's cost |
| Store 2's customer | Store 1's margin |
| Store 2's own stock, staff or sales | Store 1's suppliers or settings |

### Discovery cannot be used as a directory

A public preview is exactly four things: **name, city, logo, and a badge that
says "Verified badge coming soon"** — worded so nobody mistakes it for an
achieved status. Never the internal company ID, branches, users, inventory,
sales, suppliers, or detailed contact data before a connection is accepted.

Search needs three characters and is bounded. Crucially, **every reason a store
is absent produces the identical answer**: no such store, not discoverable,
inactive, blocked you, or is you — all simply absent. Distinguishing them would
turn the search box into an oracle for who exists and who has blocked whom.

### Blocking stops new business, and touches nothing owed

Blocking prevents new requests and suppresses non-essential notifications. It
**never** deletes history and **never** erases an outstanding liability. A debt
does not disappear because the two shops stopped speaking; pretending otherwise
would make blocking a way to escape money owed.

### "Confirmed" means the money moved

The three tabs are Waiting, Agreed and Settled, and the boundary is deliberate:
**accepting a proposal is not final confirmation.** Final confirmation means the
money was received, or the phone physically came back. The grouping lives on the
server so the client cannot drift away from it.

Two-party integrity throughout: nobody answers their own offer; the debtor
cannot confirm their own payment; a custody mismatch is refused rather than
silently rewriting the expected IMEI; and a damaged return goes to faulty for
inspection, never straight back onto the shelf.

### A person is a counterparty, never a company

> **Partially superseded (Partners milestone):** a *store* can no longer be
> recorded by hand to start new dealings — new inter-store business needs an
> accepted connection. Recording a *person* by hand is unchanged. Existing
> manual store records stay readable and settleable.

Somebody who does not use the app is recorded as a **counterparty**. No
fabricated `Company`, branch or user — an invented company would appear in
searches, be able to own inventory, and quietly become a tenant nobody created.

### Accounting, counted once

Profit is recognised at **disposition** — when the consigned phone is sold — and
a payment moves cash and liability only. Counting it twice is the failure this
exists to prevent. Forgiveness is the creditor's Owner alone, requires a reason,
and is never treated as cash.

---

## Milestone I — money loans

*Approved and implemented. Schema `0050`. 53 live checks across two temporary
companies, green.*

### A loan is not a consignment with the phone left out

Separate module, separate tables. A consignment with no unit would carry custody,
shipment, condition and disposition states that can never apply — a shortcut
that reads as clever and becomes unmaintainable. Loans reuse the counterparty
concept and the ledger *shape*, both designed to be shared in `0049` rather than
retrofitted here.

### Direction is data. Never a sign.

`they_owe_us` and `we_owe_them` are an explicit column. A negative amount becomes
ambiguous the instant somebody corrects a payment, and a sign flip is a silent
reversal of who owes whom.

One row, read from both ends: what Alpha sees as `they_owe_us`, Beta sees as
`we_owe_them`. Both are correct, and the server does the flipping — verified
live from both sides.

**Who may act follows the direction, not authorship.** The creditor is derived
from which way the debt points, so the debtor cannot confirm their own
repayment even holding every permission. The live run confirms the 403.

### Nothing becomes a debt by default

No debt is ever accepted automatically. The worked example, verified live:

> 20,000 MRU proposed → countered at 18,000 → **the original proposer decides**.
> The accepted principal is 18,000, and from that moment it is immutable.

A proposer cannot accept their own offer, and a counter-offerer cannot accept
their own counter — both refused with 409.

### A report is a claim; only the creditor turns it into a payment

`payment_reported` has a balance effect of **zero**. It is shown prominently,
beside the balance, and never subtracted. Only the person owed the money can
confirm it arrived, and that is what moves the figure.

An optional evidence reference may be attached. It is labelled as something
somebody attached by hand and is **never** presented as verification — no
payment API is called, and no provider has confirmed anything.

### The balance is derived, always

The ledger is append-only, enforced by database triggers. **No mutable balance is
stored as the authority**; every figure is calculated from the entries. A
correction puts the debt back rather than erasing the claim, and both entries
stay in the history.

### A loan is neither revenue nor expense

Principal does not create profit. A repayment moves cash and reduces a liability,
touching profit never, and **never modifies a prior closing**. Forgiveness is the
creditor's Owner alone, requires a reason, and is not cash.

Closing reminders are counts and a nudge — the payload states
`affectsExpectedCash: false`, and the screen reads that rather than asserting it.

### Permissions

| Role | Loan permissions |
|---|---|
| Owner | view, manage, payment.report, payment.confirm, forgive |
| Store manager | view, payment.report |
| Employee | **none** |

Separate keys from consignment: lending money is a different decision from
lending stock, and a shop may reasonably want somebody who can do one but not
the other. No role below Owner may write a debt off.

### Cross-company reads fail closed

`loans` sits outside the automatic tenant scoping by design, so every read goes
through one helper applying an explicit two-column filter. A stranger gets
**404, never 403** — a 403 would confirm the record exists.

> A defect found during final verification, not by a test:
> `awaitingConfirmation` totalled every payment ever reported, including the
> confirmed ones, so a settled payment kept showing as still in the air and the
> shop would chase money it had already received. Answered-ness now comes from
> the explicit `refersToId` link, and three tests pin it.

---

## Milestone J — the safe offline foundation

*Approved and implemented. Schema `0051`. 35 live checks over real HTTP and
MySQL, green. The classification itself is pinned by 34 unit tests.*

### The decision everything else follows from

**There is no server-issued inventory lease.**

Nothing in this system can promise a disconnected device that an IMEI is still
unsold. Another phone, another browser, another branch may sell it while this
device is dark, and neither side would know until the connection returned.

Therefore:

- an offline cart **may** be preserved;
- a sale **may** be prepared offline;
- the customer **must not** be charged, and the sale **must not** be shown as
  completed, until the server accepts it;
- **Charge is online-only.**

This is not a limitation waiting for better engineering. It is what the absence
of a lease actually means, and the same reasoning governs every authoritative
stock and money operation.

### Three classes, and an unclassified operation is authority

Every mutation in the app appears exactly once in
`mobile/lib/offline/policy.ts`, with the reason it is where it is. A test fails
the build if the two disagree, because prose cannot.

| Class | Meaning |
|---|---|
| **Local draft** | The shop's own unfinished work. Kept here, never sent by itself, never called sent, reserved, paid, approved, confirmed or completed |
| **Queueable** | An append-only *report* of something that already happened |
| **Online-only** | Anything that decides something |

`classify()` returns `online_only` for anything it does not recognise. A future
milestone that adds a mutation and forgets this file gets the safe answer rather
than the convenient one.

### Only four operations may wait

An operation may be queued only if it is a report, carries a stable client UUID,
is idempotent server-side, moves no stock, settles no money, grants no authority,
and can fail later without corrupting business truth.

| Operation | Why it is safe to send late |
|---|---|
| `expense.submit` | Money already spent. Grants nothing — somebody still confirms it |
| `loan.payment.report` | Says "I paid you". **Balance effect zero** until confirmed |
| `consignment.payment.report` | The same claim, same zero effect |
| `notification.read` | A flag on the reader's own notification |

**A queued payment report means one thing: waiting to tell the server.** It never
means the payment was confirmed.

Reporting is deliberately open to **both** sides of a debt — a creditor who
receives cash should be able to record it without waiting for the debtor. What
is restricted is *confirmation*, which remains the creditor's alone.

### The gap the audit found, and closed

`loan_ledger` and `consignment_ledger` carried `client_uuid` but no payload
fingerprint, and replayed on the key alone. Harmless while every request is made
online and immediately; **not** harmless behind a queue — edit a queued 5,000
report to 8,000, keep the key, and the server would silently answer about the
original while the phone displayed *synced*. The shop would believe it had
reported a figure the server never saw.

Migration `0051` adds `client_request_hash` to both, matching what `expenses`
already did. All three queueable endpoints now refuse a changed payload with a
409. **Verified live**, on each of the three.

### No `failed` state

The queue's states are `draft`, `waiting_for_connection`, `sending`, `synced`,
`needs_attention`, `cancelled`. A conflict is not a failure — it is a question
for a person: the amount changed, the permission went away, the branch moved.
Calling it "failed" invites the app to retry it and invites an employee to
ignore it.

Validation, authorization and conflict failures stop and wait for somebody. Only
transient network and server failures back off — exponentially, capped at five
minutes, bounded at eight attempts. **The payload is never quietly edited to
make one pass.**

### A timeout is not a failure

`fetch` had no timeout at all, so a request on a dying connection could hang
indefinitely and "the server did not answer" was not a state the app could
represent. It is now bounded, and treated as **uncertain** rather than failed:
the request arrived and only the answer was lost, so it is retried under the
same client UUID before anybody is told to create a second record.

A timeout also does not mark the shop offline — the server was reached, and
saying otherwise would hide a server that is merely slow.

### Session identity is re-checked at replay

Not merely at enqueue. A shared counter phone changes hands, branches switch,
roles are revoked. The queue is keyed by user, company and branch — that triple
*is* the filename — and permissions are refreshed before every pass.

Drafts **survive sign-out** rather than being destroyed: an employee whose shift
ended has not abandoned the sale they were building. They become readable again
only to the same person in the same branch, because the next person to sign in
opens a different file.

### No new dependency

The queue and drafts are built on `expo-file-system`, which was already
installed. `expo-secure-store` was the wrong tool — Android warns above roughly
2 KB per value, and a queue is unbounded by nature. Nothing carrying a
credential-shaped field may be written at all, checked recursively.

Corrupted or foreign-versioned queue data is **quarantined with its bytes
intact**, not deleted: a queue that silently drops what it cannot parse is worse
than one that admits it lost something. Drafts, which are evidence of nothing
owed, are simply discarded.

---

## Milestone J.1 — offline drafts for every long form

*Approved and implemented. 19 tests.*

J proved the Sell cart survives a process kill. Six other forms did not, and
each was losing work somebody had typed or scanned: a receiving session of
twenty phones, a consignment proposal, an expense report, a return taken at the
counter, a loan proposal, a goal.

**Scope is the filename** — user, company, branch, form and record — so
isolation is structural rather than a check somebody could forget. An
investigation note about one return can never surface on another.

**Nothing binary or secret reaches the disk**, refused *before* any write. A
refusal afterwards would be an apology rather than a guarantee. Oversized
payloads are refused too: that is somebody persisting a server response by
accident, which is both a privacy problem and a way to fill a cheap phone.

**Restores are visible.** Silently repopulating a form is how somebody submits
yesterday's numbers believing they typed them today, so the notice says when the
work was saved and offers to start fresh. Drafts clear only on confirmed
acceptance or explicit discard — never on a failed submission, and never because
a restored draft turned out to be stale.

**Server state is re-read, never restored.** A restored consignment re-asks
about every phone before proposing; one another branch sold is dropped from the
list and named, rather than the whole draft being thrown away.

**Import preparation is deliberately not drafted.** The file is uploaded to a
server-side preview immediately, so there is nothing local to lose — and the
spreadsheet bytes are exactly what must never be persisted.

---

## Milestone K — subscription entitlement

*Approved and implemented. Schema `0052`. 59 live checks, green.*

### One plan, no tiers

A shop either has a live subscription or it does not, and the only thing that
changes when it lapses is whether the server accepts writes. No feature flags in
business services, and nothing that would make a role change a billing event.

| Rule | Value |
|---|---|
| Base | 500 MRU per subscribed branch per month |
| Included seats | 2 non-Owner staff per subscribed branch, **pooled company-wide** |
| Owner | Consumes no seat |
| Additional seats | 100 MRU each, not prorated |
| Free trial | None · Annual billing deferred |
| Complimentary | Supported, audited, never self-grantable |

**Prices live in provisioning, not in the app.** The mobile client shows no
amount, no checkout, no payment link and no Bankily claim — nothing that would
have to be kept in step with a price list the app has no business knowing.

### States, from a server clock

`active` · `grace` (exactly 72 hours, **derived** from the period so the two
cannot drift) · `expired` · `complimentary`.

**Writes continue through grace.** A shop three hours past renewal is still open;
refusing its sales over an administrative boundary would cost it real money.

**Expiry never hides anything.** Authentication works, history reads, exports
work, branch selection and sign-out work. Only new business truth stops. A shop
locked out of yesterday's sales reaches for the notebook immediately.

### Nobody is deactivated to balance an invoice

A company over its seat limit keeps every employee. It is told, blocked from
adding more, and left to decide who stays. Seats are checked at the moment of
activation, so two Owners filling the last place at once cannot both succeed —
and deactivating is never blocked, or a company would be trapped over its limit.

### Enforcement is central, and fails closed

One interceptor, not a check in twenty-eight controllers. A mutation nobody
classified is **refused** for a lapsed shop, so an endpoint added in a later
milestone fails closed rather than conveniently.

> It was written as a global guard first. The live run refused **every** write
> through the fail-closed branch, because global guards run in registration
> order and this one ran before authentication. Interceptors are guaranteed by
> the request lifecycle to run after every guard. The fail-closed default is
> exactly why the wrong answer was impossible to miss — had it defaulted to
> allowing, every shop would have kept writing and nothing would have looked
> wrong.

A tenant Owner cannot reach provisioning at all: it skips the tenant JWT guard
and is gated on a platform key no tenant holds. An unset key **closes** the
surface rather than opening it.

`ENTITLEMENT_WRITE_BLOCKED` is stable and machine-readable; the app never parses
English. The error is non-transient, so a queued report stops rather than
looping against a condition retrying cannot resolve.

---

## Milestone L — analytics that keep their categories apart

*Approved and implemented. 30 tests, 41 live checks.*

### Do not build a competing accounting system

Every figure already had a canonical owner. L consolidates and presents them and
recomputes nothing: two ways of computing profit is how a shop ends up with two
answers and trusts neither.

### The timing that matters

| Event | Profit | Cash |
|---|---|---|
| Sale | ✔ | ✔ |
| **Return approved** | ✔ (revenue out, COGS credited) | — |
| Refund reported | — | — |
| **Refund confirmed** | **✗ — already counted at approval** | ✔ |
| Supplier payment confirmed | ✗ | ✔ |
| Loan / consignment principal | **✗ — never revenue or expense** | ✔ |
| Closing discrepancy | **✗ — a question, not a loss** | ✗ |

The two mistakes this prevents: counting a return twice, and treating lending as
earning. Both make a shop look dramatically wrong, and both are easy to write.

### Never manufacture a figure

A metric with no canonical source is **named as unavailable**, not defaulted to
zero — a shop cannot tell a measured zero from a number nobody calculated, and
the difference matters when it is what they owe a supplier. Refund liability,
supplier liability, commissions and unattributed legacy payments are all
reported this way.

A comparison against a zero base returns **unavailable**, not infinity and not a
percentage. "Up 100%" from nothing is a division nobody checked.

### On screen

Profit first, then what actually moved, then who owes whom, then what did not
add up — the order the questions actually arrive in a shop. Profit and cash are
never mixed: a shop can be profitable and short of cash in the same week, and
presenting one as the other is the most misleading thing a retail report can do.

> Two bugs the live run found and unit tests could not: the requested window was
> ignored (a regex whose escaping had been lost matched the literal
> `dddd-dd-dd`, so every request silently reported **today** while answering 200
> with a perfectly shaped body), and the summary reported every branch whichever
> branch was selected. Both are now pinned by tests.


---

## 6h. Language, and the back gesture — M, SHIPPED

### ✅ APPROVED — the app speaks English, French and Arabic

French joins a catalogue set that was already complete in Arabic. Every locale
covers the **entire** key set — `Catalogue = Record<TranslationKey, string>`
makes a missing key a build failure, so a half-translated screen cannot ship.

### ✅ APPROVED — the language switcher belongs to every role, in More

Not in Business settings. Settings is Owner-only, and language is a **personal
preference, not a company rule** — an employee reading Arabic and an owner
reading French share one shop.

It sits **first in the Account section** and is never permission-gated.
Somebody who has landed in a language they cannot read must be able to get out,
so every language is written **in its own words** — `English`, `Français`,
`العربية`. "Arabic" spelled in French helps nobody who only reads Arabic.

> **This was the actual bug.** Arabic had been complete for milestones, but the
> only switcher in the codebase was in `app/dev/gallery.tsx`, a developer
> screen not linked from navigation. The app was Arabic-capable and
> English-only in practice. A translation nobody can reach is not a feature.

### ✅ APPROVED — French follows the shop voice, not accounting French

"Argent encaissé", never "chiffre d'affaires", wherever a shop assistant reads
it. Reported money is never worded as paid. The wording rules that separate
*owed* / *reported* / *confirmed* hold in all three languages.

### ✅ APPROVED — the Owner summary language may be French too

Separate setting, separate question, widened in migration `0053`. The two are
chosen independently on purpose — an Owner may read the app in one language and
want the nightly message in another — but neither may be unable to express what
the other can.

### ✅ APPROVED — the back gesture is edge-swipe, not full-screen

Restored on iOS by letting the platform own its transition. Deliberately **not**
the full-screen variant: `inventory`, `sales`, `returns` and `transfers` carry
horizontal filter rows a full-screen swipe would fight, and edge-swipe is what
iOS itself does.

**Android has no equivalent gesture** in a native stack and keeps its system
back button. That is a platform difference, not a gap to paper over.

### 🔴 REQUIRED, NOT DONE — a native-speaker review of both translations

Arabic already carried this warning; French now carries it too. The keys,
placeholders and plumbing are final and verified. **The wording is not
reviewed**, and this is a shop that handles other people's money in a
francophone and arabophone market.


---

## 6i. Navigation architecture — N, SHIPPED

### ✅ APPROVED — More holds containers, not features

Six business hubs, in a fixed order: **Sales & returns · Stock & purchasing ·
Money · Store network · Performance · Team & business**. Then a visually quieter
**Account & security**, and sign out kept apart and destructive-toned.

Twenty-one equally-loud rows made nothing findable because nothing was
subordinate to anything else. Every feature is now **at most two taps** from
More: one to its hub, one to itself. No third level, and Home still exposes
urgent work directly.

### ⤴ SUPERSEDED — the four bottom tabs do not change

Home · Sell · Inventory · More. No fifth tab.

> Superseded twice: Money became a tab, and the Partners milestone replaced Sell
> with Partners. The bar is now **Home · Partners · Money · Stock · More**.

### ✅ APPROVED — one typed registry owns route, permission and membership

`lib/navigation/registry.ts` is the only place a destination's route is paired
with its permission. A drift test fails the build when a route is added without
being classified, when a child lands in two hubs, when a hub would render empty,
or when a permission does not exist.

That test exists because this has already gone wrong: **Suppliers shipped and
stayed unreachable from More for a whole milestone** (`docs/29` S2).

### ✅ APPROVED — hubs are navigation only

They fetch nothing, count nothing and add no endpoint. A count shown in two
places eventually disagrees with itself.

### ✅ APPROVED — user-facing renames, with routes untouched

"Where the money is" → **Cash & accounts** · "Money spent" → **Expenses** ·
"Money owed" → **Loans** · "Other stores" → **Partner stores** · "Stock with
other stores" → **Consignments** · "Bring in stock" → **Import stock** ·
"Waiting to send" → **Sync center**.

Values of existing translation keys only. **No route, file or backend concept
was renamed.** Loans keeps its direction distinction — money owed *to* the shop
is never merged with money the shop owes.

Arabic keeps the term it already had where that term was better: المصروفات for
expenses, الأهداف for targets, and بضاعة الأمانة for consignments rather than
the literal description.

### 🔴 FOUND, NOT FIXED — the web build crashes on sign-in

Pre-existing and unrelated to navigation: the offline queue asks
`expo-file-system` for a document directory that does not exist on web. See
`docs/29` §12.


---

## 6j. IMEI intake — O, SHIPPED

### ✅ APPROVED — OCR is retired

Reading a `*#06#` screen with on-device text recognition is gone: the mode, the
module, the native dependency. The supported intake methods are now:

1. scan an **IMEI barcode or QR code**;
2. scan an ordinary **product barcode**;
3. **type the IMEI**.

### ✅ APPROVED — typing is permanent, and that is not a fallback apology

**Whether a phone shows a scannable code beside its IMEI is up to its
manufacturer.** Many print only digits. Manual entry is therefore a first-class
route, always reachable, and the screen says so in words rather than leaving
somebody to discover it while a customer waits.

Nothing in the product may describe barcode availability as universal.

### ✅ APPROVED — one IMEI is enough

Primary is required for an IMEI-tracked phone. **Secondary is optional.** A
single-SIM phone, an eSIM phone, or any device exposing one identifier is never
blocked, and nothing requires two scans before continuing.

### ✅ APPROVED — two IMEIs are ONE phone

A dual-SIM handset is one physical inventory unit carrying two identifiers.
Both are stored when both are available, **either one finds the same unit**, and
neither may belong to another unit — enforced by `0042`'s cross-column triggers.

### ✅ APPROVED — IMEI and Product barcode are different things

An **IMEI** identifies one individual phone and populates a unit's identifier
fields. A **product barcode** identifies a reusable model and populates the
product.

An IMEI may **never** be written into the Product barcode field — not even to
solve lost state across the Create-product detour, which is the shortcut this
milestone explicitly refused. Doing so would poison recognition for every unit
of that model.

### ✅ APPROVED — the scanner shows its result immediately

An explicit state machine (`idle → scanning → validating → result → accepted`,
with `cancelled` always reachable). The first valid detection takes a
synchronous lock, the camera is detached, and the result appears **inside the
sheet** — not when the user closes it. Only an explicit `Scan again` releases
the lock. Invalid data is explained and never submitted silently.

### 🔴 FIXED — either IMEI now finds the phone

Four lookup paths searched `imei_primary` and `serial_no` only, so a dual-SIM
phone scanned by its second identifier could not be **found, sold, priced, or
detected as a duplicate on import**. Proven live, fixed, and pinned by a drift
test. No migration was needed — `0042` already guaranteed the uniqueness these
widened lookups depend on.

---

## Two approved product corrections (CP1–CP3)

### ⤴ SUPERSEDED (Partners milestone) — Money is a bottom tab, beside Sell

> The bar is now **Home · Partners · Money · Stock · More**. Sell is no longer a
> tab; see *"Partners replaces Sell on the bar"* at the end of this file. Money
> stays a tab, now beside Partners.

The bar is **Home · Sell · Money · Inventory · More**, with Money adjacent to
Sell because the two are the same errand: taking money and accounting for it.
The **complete** hub moved — Cash & accounts, Expenses, Daily closing, Loans —
and the duplicate card in More was removed in the same edit, so no state exists
where both are present.

Money is **not** an Owner-only tab. It appears whenever the person has
permission for at least one child, and shows only the children they may open.
Verified live: an Owner and a Manager see four, an Employee sees two (Expenses,
Daily closing) — and still gets the tab.

Placement is one field on the hub (`placement: 'tab'`), not a second copy of the
menu, so the registry stays the single source of truth and the drift tests keep
covering it. `/hub/money` still resolves — old deep links were not broken.

### 🔴 FIXED — the web sign-in crash was structural, not cosmetic

`queue-store.ts` built a native `Directory(Paths.document, …)` at import time,
and `AuthProvider` imports it, so the login page crashed on web before it could
render. The fix is not an early return bolted on afterwards: the platform check
now precedes **every** native construction, and a source-shape test enforces
that ordering rather than trusting a guard to stay in front.

**Web is explicitly online-only.** `enqueue` refuses rather than accepting work
a closed tab would erase, and Sync Center says so. No `localStorage` fallback
was invented — a test refuses one — because "durably queued" must never be
claimed for storage a browser can drop.

### ✅ APPROVED — nobody types a Store ID to sign in

Sign-in is **one identifier and a password**. The identifier is a phone number
**or** a generated personal ID; the app deliberately does not guess which, since
guessing could refuse something the server would accept.

Two identifiers now exist and are not interchangeable:

| | Store Account ID | Personal login ID |
|---|---|---|
| Who holds it | the business | the person |
| Typed at sign-in | **never** | yes |
| Purpose | support reference | half a credential |
| Example | `F62B8D1EEB` | `U-R6H5NWRY` |

`U-` + 8 characters from a 30-glyph alphabet with `0 1 I L O U` removed, so it
survives being read aloud and written down. Not sequential, not the binary UUID,
case-insensitive, and it cannot be mistaken for a phone number. Every existing
user was backfilled by migration `0054`; the database enforces uniqueness.

**The decision was made by an audit, not an assumption.** 0 of 10 users had a
phone number on file — so a phone-only design would have locked every one of
them out. See [`docs/35`](35_AUTHENTICATION_IDENTITY_AUDIT.md).

Tenant resolution moved from the client to the credential. An unauthenticated
request no longer names the company at all, which is strictly stronger than a
Store ID selecting the tenant *before* any password was checked.

### ✅ APPROVED — one phone, two shops: ask, but only after the password

A phone number is unique within a company, not across them. When one genuinely
matches a verified password at more than one shop, the server returns a
short-lived, purpose-bound continuation token and the shop names, and the app
shows a picker.

The order matters and is tested: **no company name is returned before the
credential is proven.** A wrong password on an ambiguous phone produces the same
generic failure as an unknown identifier. The rejected alternative was asking
everybody for a Store ID up front — paying for a rare case on every sign-in.

### 🔴 FIXED — the login screen shipped real credentials

It carried a real store code (`F62B8-D1EEB`) and the login `owner` as
placeholders: readable in the bundle, and read straight off the running page in
a browser. Both are gone, and a drift test now fails the build if a
credential-shaped placeholder returns.

Settings was telling Owners that "your staff type this when they sign in" about
the Store ID — caught in the browser, corrected in all three languages. The one
screen an Owner reads while setting up must not teach the habit this change
removes.

---

## Login by contact, and app-wide dark mode (CP1–CP3)

### ✅ APPROVED — sign in with an email address or a WhatsApp number

One field, one password. The identifier is something the person **already
knows**, rather than a code the product invented and asked them to keep. No
Store ID, branch, company, personal ID, username, and never both an email and a
phone at once.

The app deliberately does not guess which of the two was typed. Guessing lets
the client refuse an identifier the server would have accepted, and the person
holding the phone has no way to argue with it. The keyboard stays general for
the same reason: a phone pad cannot type an email.

Migration `0055` gives email the **per-company** uniqueness phone already had —
not global, so one address used at two shops still reaches the password-first
account chooser instead of being refused at enrolment.

**"WhatsApp number" is a label, not a claim.** Nothing verifies the number is
registered with WhatsApp; no verification service exists. Technically it is a
normalised phone identifier. See [`docs/36`](36_LOGIN_CONTACT_TRANSITION.md).

### 🔴 FIXED — the change would have locked out every active user

Audited before any code changed: **five of five** active users had neither an
email nor a phone. Restricting sign-in to contacts would have locked 100% of
them out of their own shop.

So the generated personal ID is **still accepted by the server and offered by
nothing** — not a field, not a hint, not a documented way in, and a drift test
fails the build if it reappears on the login screen. It is a ramp, not a
feature, and `docs/36` records the exact condition for removing it.

### ✅ APPROVED — every new user needs a contact, and changing one is guarded

At least one of email or phone is required to create a user — enforced in the
service, not a DTO, so the seed and the CLI cannot walk around it.

Changing a login contact asks the **actor** to re-type their own password, ends
the **target's** sessions, cannot strip somebody's last way in, and is audited.
The actor's password rather than the target's: an Owner correcting an
employee's number does not know theirs, and demanding it would push shops
toward sharing passwords.

### ✅ APPROVED — two-step verification is a direction, not a switch

2FA does not exist and **no toggle pretends otherwise**. A switch that saved a
preference and protected nothing would be worse than its absence, because
somebody would trust it. A test refuses any 2FA UI until it is real. The
approved shape — optional per user, under Account & security, delivered by a
verified contact — is recorded in `docs/36`.

### ✅ APPROVED — dark mode, from a single semantic layer

An on/off switch. Off is Light, on is Dark; existing users default to Light so
nobody's app changes appearance after an update.

**No "System" option.** With it selected the switch shows the *current*
appearance, so a shopkeeper toggling it at dusk cannot tell whether they
changed the setting or the sun did.

The preference is stored **on the device, not against the account**. A shop's
counter phone is shared, and the person who prefers dark is choosing for that
handset in that lighting. It is not sensitive — it reveals nothing about the
account — so signing out deliberately leaves it alone.

**Dark is not an inversion.** Every token means what it meant in light: success
stays green, danger stays red, warning stays amber. Only the lightness
relationship flips. Elevation is carried by lightness rather than shadow,
because a shadow on near-black is invisible, and text is never dimmed with
opacity — stacking translucent layers is how secondary text quietly falls below
readable contrast on one surface while passing on another.

### 🔴 FIXED — the palette could not have followed a theme at all

`colors` was a frozen object read inside a module-scope `StyleSheet.create` in
46 files. That captures the light values **once, at import**, so swapping the
object at runtime would have changed nothing — silently, with no error. Colour
now resolves during render through `makeStyles`/`makeTokens`, memoised per
theme.

Six defects were found and fixed along the way, three of them pre-existing in
light mode:

- a warning button at 4.23:1 with white text, under the 4.5 bar;
- an input placeholder at 1.8:1, invisible on a sunlit shop counter;
- hint text at 2.9:1 on the canvas — the contrast test had only checked it
  against the card, passed, and shipped it;
- React Navigation's own `rgb(242,242,242)` behind every screen, the largest
  surface in the app and not in the token layer at all;
- colour utility classes chosen at runtime, marking **selected** state — the
  thing a shopkeeper looks at;
- `text.inverse` redefined for dark as "on a light fill" when all five callers
  mean "on a brand button", which would have shipped dark text on indigo.

### ✅ APPROVED — Appearance & language is one screen, under Account & security

Dark mode and the language selector together, because both are **personal
preferences, not business configuration**: two people sharing a shop can
disagree about them without either being wrong. They are not in store-wide
Settings, where a change means "this is how the shop works".

The language selector **moved**; it is not a second copy. A test asserts exactly
one screen may render it. Theme and language are independent — verified live in
both directions.

---

## Platform control: registration, subscriptions, administration

Full architecture in [`docs/37`](37_PLATFORM_CONTROL.md).

### ✅ APPROVED — one backend, three areas, strict separation

Public registration, a customer portal for Owners, and a private administration
portal for us. The existing backend is the source of truth; there is **no second
subscription engine**. Entitlement is still calculated by `entitlement-rules.ts`.

### ✅ APPROVED — Store IDs are generated, never typed

Not at login, and not at registration. No Store ID, company id, branch id,
personal ID or tenant code is ever asked for. Every internal reference is
generated server-side. Login remains **email or WhatsApp number, plus password**.

### ✅ APPROVED — new businesses begin pending, and there is no free trial

Registration creates the company, first branch, Owner and a `pending_activation`
subscription in one transaction. Succeeding at registration grants nothing; a
person decides activation and the decision is recorded.

A `pending` business cannot reach the operational app at all — it has no history
to withhold, and opening the till would be a free trial by accident. Its Owner
keeps the limited account surface, so they can always find out where they stand.

**Expiry still hides nothing.** That rule is unchanged and load-bearing.

### 🔴 FIXED — the brief's subscription contract did not exist

Milestone K deliberately built no plans, no prices, no subscription payments and
no lifecycle. Recorded before any code changed, and it shaped everything: the
lifecycle states, the payment table and the administrator realm are all new, and
`Payment` was left alone because it is a *till* payment carrying a `sale_id`.

### ✅ APPROVED — no money is shown, because the server computes none

There is no plan price or per-seat charge anywhere on the server, and the
canonical decision is that there is one functional plan. So the portal shows
status, period, grace, branches and seats — and **no currency figure**. The
dashboard returns `revenue: null` deliberately: payment history is incomplete by
construction, and a total would look authoritative without being so.

Pricing is a separate decision with a Plan model behind it. Inventing one here
would have meant inventing numbers.

### ✅ APPROVED — a manual activation is a grant, never a fabricated payment

An **administrative grant** says we gave this shop access, for a reason, for a
period, and creates no payment row. A **payment** is a separate append-only
record of money a named person says they saw. Collapsing them would let a test
activation look, months later, exactly like a shop that paid.

Recording a payment does not extend anything — bundling them would mean a
mistyped amount silently moved an expiry date.

**Bankily and every other provider is deferred.** Nothing contacts a provider,
and every payment response carries `providerVerified: false` explicitly.

### ✅ APPROVED — platform administrators are not tenant Owners

Their own table with no `company_id`. A `RoleKey` on `users` was rejected
because a tenant role lives inside a company — a shop able to create roles would
have a path to minting a platform administrator.

Created only by CLI, with the password from the environment rather than an
argument. No default credential exists anywhere in the repository. Sessions are
HttpOnly cookies, never `localStorage`; high-impact actions re-verify the
password; sign-out revokes.

### ✅ APPROVED — the platform portal does not expose operational shop data

No sales, IMEIs, cost prices, margins or expenses — not filtered out, but never
queried. Being able to see a shop's takings is not part of administering a
platform. No impersonation.

### ✅ APPROVED — contact verification is not two-step login verification

Different feature, different purpose. 2FA still does not exist and still has no
toggle. No delivery provider is configured, so the boundary and a development
outbox exist and production refuses rather than claiming a message was sent.

---

## Subscription pricing, and the control website (Phase 2)

Architecture in [`docs/37`](37_PLATFORM_CONTROL.md); website setup and security
in [`docs/38`](38_CONTROL_WEBSITE.md).

### ✅ APPROVED — the Standard plan, verbatim

- **One subscription per company.**
- **500 MRU per month per active branch.**
- **Two active staff accounts included per branch**, pooled **company-wide**.
- **100 MRU per month per additional active non-Owner account.**
- A user assigned to several branches **counts once**.
- The **Owner is never charged**.
- **No prorating.** An addition costs the complete month immediately; a removal
  reduces only the **next** renewal.
- **No free trial.**
- **72-hour grace**, unchanged.
- **Integer MRU** throughout. No float touches an amount.

The five approved examples, verified against the live server:

| Branches | Staff (excl. Owner) | Monthly |
|---|---|---|
| 1 | 0 | 500 MRU |
| 1 | 2 | 500 MRU |
| 1 | 3 | 600 MRU |
| 2 | 4 | 1 000 MRU |
| 2 | 5 | 1 100 MRU |

The allowance is pooled rather than per-branch because a shop that hires its
second person at the quieter branch has not changed what it owes, and a
per-branch allowance would penalise exactly that sensible arrangement.

### ✅ APPROVED — a period's price cannot be rewritten later

Plan versions are **effective-dated**, and a scheduled price may never start in
the past. Each billing period **copies** the unit prices in force when it opened
rather than joining to the plan. A join would mean the figure a shop saw in
March changes the day somebody schedules a new price — precisely what an
immutable snapshot exists to prevent.

The period keeps a **high-water mark per component**, not on the total. That
matters for one case that is easy to get wrong: a shop with one branch and three
staff has been charged 100 MRU for the third; adding a second branch raises the
pool to four, and a naive recalculation would price the staff fee at zero and
hand back money the no-prorating rule says is not refundable.

A company that has never been billed reports **`available: false`**, not zero.
Zero would read as "billed nothing", which is a different and untrue statement.
**No billing history was fabricated for the demo tenant.**

### ✅ APPROVED — one website, three areas, one security boundary

`/public`, `/account` and `/admin` in a single React + TypeScript application.
An Owner can never enter `/admin`: the areas read different credentials from
different backend realms, so the refusal is structural.

**No credential is ever written to browser storage.** The administrator session
is an HttpOnly cookie; the Owner's tenant token lives in memory for a visit.
Exactly two storage keys exist, both preferences.

**The website computes no price.** Every figure is the server's, and a test
refuses any component that multiplies a unit price.

### ✅ APPROVED — contact verification, without pretending

At least one contact is verified during registration. No provider is configured,
so codes go to a development outbox, the screen says plainly that nothing was
sent, and **production refuses rather than claiming delivery**. Codes are
purpose-bound, single-use, short-lived, attempt-limited, rate-limited and stored
only as a hash folded with the destination.

This is **not** login 2FA, which still does not exist and still has no toggle.

### ✅ APPROVED — the mobile app can now send somebody to sign up

A clear secondary `Create account` action on the login screen, opening a
**configured** URL — never a hardcoded localhost or production domain. A second
tap cannot open two browser sessions, and a missing configuration is reported
differently from a browser that will not open.

Pending, suspended and expired each get their own screen, chosen by the
**server's** state with no date arithmetic on the device. Re-checking lets a
newly activated shop straight in, with no reinstall and no clearing storage.


---

## 6k. Registration, the portal and payment instructions — SHIPPED

### ✅ APPROVED — registration is mobile-only

Account creation and contact verification happen **in the app**. The website
holds no registration form and no public account-creation action; its old
address resolves, explains that registration is in the app, and submits nothing.

Setting a shop up means scanning stock, and scanning happens on the phone.
Splitting sign-up across a browser and an app meant typing the longest form in
the product on the surface with the worst keyboard, then doing the real work
somewhere else.

### ✅ APPROVED — the session comes from proving THIS attempt

    registration attempt
  + a 15-minute, hash-only, single-use continuation
  + the exact verification challenge bound to it
  + atomic consumption of both
  = one ordinary Owner session from `SessionsService`

A destination-wide `isVerified()` **never** issues a session. The registration
password is never replayed. Registration and portal handoff hold **distinct**
purposes, so neither ticket can be spent as the other.

### ✅ APPROVED — signed in to the portal is not subscribed

After registration the Owner is authenticated and the subscription is still
`pending`. Opening the portal, choosing a provider and copying a code change
nothing: **no payment row, no grant, no activation, no provider call.**

A pending Owner **may** mint a portal handoff — every new shop is pending by
definition, and that route leads to the page which ends the pending state.
That is the single allowance; no operational route follows it, and a test pins
the allow-list by name.

### ✅ APPROVED — five providers, all showing `00000`

Bankily (default), Masrivi, Sedad, Bimbank, Click. Every code is currently
`00000`. The list, its order and the codes are **server-owned**, so a real code
replaces a placeholder without an app release. The code renders `dir="ltr"`
even in Arabic: it is a sequence to be typed into a banking app, and mirroring
it would have somebody enter it backwards.

The dialog states that it shows instructions and takes no money. Its tests
assert the absence of the words *paid*, *confirmed*, *verified* and *activated*,
and that no `fetch` occurs when a provider is selected or a code copied.

### 🔴 DEFERRED — real payment-provider integration

No provider is called, integrated or contacted. Production must refuse or
replace the `00000` placeholders before launch.

### 🔴 UNRESOLVED — strict SQL mode in production

The development MySQL runs with an **empty `sql_mode`**. Migration replay is
verified under an explicit strict session, but making the server itself strict
is deployment work, recorded in `docs/39`.

---

## 6l. What a live acceptance changed — SHIPPED

Six things a full staging run found that 1,787 passing tests did not. Recorded
because each one had a test suite around it that was green at the time.

### ✅ APPROVED — the portal handoff is Owner-only

Gated on `settings.manage`: company-scoped, never delegatable to a branch, held
by the Owner and the company administrator and nobody else. A Store Manager and
a Store Employee were each minting tickets and getting `201`.

The portal is the account surface — what the shop is charged, what it owes, how
to pay. A manager runs a branch; an employee sells. Neither settles the bill.

No new permission key was invented: one more key means a catalogue migration,
and the authority already existed.

### ✅ APPROVED — a pending shop may read how to pay

`platform/payment-instructions` joins `platform/my-subscription` in
`ALWAYS_READABLE`. It was outside, so the entitlement guard refused it with
`ENTITLEMENT_PENDING` — and because the portal treats an instructions failure as
non-fatal, the dialog silently never opened **for the only kind of shop that
needs it**. Both halves of one page now behave the same way.

### ✅ APPROVED — a one-time ticket never reaches a log

`redact.paths` cannot see inside a URL, so `autoLogging` wrote
`portal-session?t=<ticket>` verbatim, twice per request. The path is kept and
the value replaced. The rule was already written down in
`scripts/staging-verification-code.ts`: *a code in a log file is a working
credential sitting in a file that gets copied around.*

### ✅ APPROVED — `Secure` on a session cookie is a transport question

Not a `NODE_ENV` question. `.env.staging` sets `NODE_ENV=production` on purpose,
and a `Secure` cookie on a plain-HTTP origin is discarded by the browser without
a word. `localhost` hid it entirely. **Production must leave `COOKIE_SECURE`
unset or `true`.**

### ✅ APPROVED — the portal accepts a cookie session

The website gated on an in-memory bearer token that only its own sign-in form
ever set, so somebody arriving from the app — cookie set, API answering `200` —
was shown a password form. A script cannot read an `HttpOnly` cookie, so the
page asks the API and believes the answer, and falls back to sign-in only on a
real `401`. The auto-open marker now matches what the API actually sends.

### 🔴 UNRESOLVED — a staging tenant cannot be deleted

Every table referencing `companies` restricts deletion, including ones
registration itself creates. The cleanup script has never removed a tenant; it
now says so instead of reporting a count it cannot honour. Deleting children in
dependency order is **not** the answer — nothing financial is hard-deleted.
Reclaiming staging tenants means restoring the database.

---

## 6m. The staging banner, language before sign-in, and one retained shop — SHIPPED

### ✅ APPROVED — the visible staging banner is removed

A strip across the top of every screen read `STAGING — test data only`. It is
gone from the interface.

The people looking at this build are shopkeepers being shown their own shop, and
a permanent warning band over a demonstration reads as *this software is
unfinished* rather than *this data is not real*.

**Nothing underneath moved.** `APP_ENV`, the separate database and its guards,
the staging-only scripts that refuse to run anywhere else, loopback-bound
administration, separate secrets and staging log classification are all exactly
as they were. **The build is still staging.** A drift test now forbids the
phrase — in every casing and dash — across the layout, all three authentication
screens, the subscription screen and all three catalogues, and the exported
bundle is scanned for it too.

### ✅ APPROVED — the language switcher belongs before sign-in

The setting lived behind the sign-in screen. Somebody handed a phone showing a
language they cannot read could not sign in to change the language, and could
not change the language without signing in.

English · Français · العربية, each written in its own words, on sign-in, on
account creation and — compact — on verification. **No flags:** a flag is a
country, not a language. Arabic is not one country's, and a French flag on a
screen in Nouakchott says something nobody meant to say.

It writes the same `erp.language` preference the settings row writes, changes
the words immediately, and **leaves every typed field in place** — confirmed by
switching mid-form during a live run. The restart notice appears only after
somebody switches *there*: it is also raised during hydration, which on a
sign-in screen meant telling somebody to restart the app when they had not
touched anything.

The customer-portal and administrator sign-in pages already carried the
established control, so neither needed one added.

### ✅ APPROVED — one shared way into the portal

`subscription-blocked` opened the account URL directly, with no ticket — so the
one screen where somebody taps "manage my subscription" landed an authenticated
Owner on a password form. It now uses the same handoff the registration flow
uses, through one hook rather than a second copy of the reasoning.

The duplicate-tap guard is a **ref**: `if (busy) return` reads state React has
not updated yet, and two taps in one frame would mint two tickets.

### ✅ APPROVED — a retained staging shop

`Test Store` / `Main Store`, Owner `store@test.com` (the password is not
recorded anywhere in this repository), verified contact, **activated by a
30-day administrative grant** — complimentary, with **no payment row invented**
— one active branch, no extra staff, no sales, no expenses, no customers.
500 MRU a month.

Twenty iPhone variants and twenty in-stock units, five dual-SIM. **A dual-SIM
phone is one unit with two identifiers, not two units.** Every IMEI is generated
locally from a non-allocated test range with the application's own Luhn helper,
validated before insertion and checked against both identifier columns.

It is provisioned by a guarded, idempotent command that refuses outside staging,
writes nothing without `--apply`, and **refuses to adopt a `store@test.com` it
did not create** — the worst thing a fixture command could do on a shared
database.

---

## 6n. The device catalogue, dependent selectors and TAC recognition — SHIPPED

### ✅ APPROVED — the catalogue is server-owned, and curated

Brands and models live in the database (`device_brands`, `device_models`) and
are read over `/device-catalogue`. **No second list is bundled in the app.** A
list compiled into a release drifts from the server's, and the one you cannot
fix without shipping is the one people are looking at.

**13 brands, 323 models, `source = 'curated'`.** Not `official`, which is
reserved for a licensed feed — calling a hand-assembled list official would be
a claim nobody could check. `/device-catalogue/version` returns
`complete: false` **in the payload**, because a client that believed it held
every phone would stop offering the manual field.

Redmi and POCO are Xiaomi's, recorded as `parentKey`, and are still listed,
searched and sold as brands in their own right. Nesting them under Xiaomi would
hide them from somebody typing the name printed on the box.

**Broad production coverage needs licensed GSMA data.** This is a starter
catalogue and says so everywhere it can.

### ✅ APPROVED — a model is a commercial name, and nothing else

Storage, colour, cosmetic condition and an individual IMEI are **not** models.
`products.variant` already carries storage and colour; the unit carries the
identifier. A test forbids `128 GB` or `Black` in a model name: folding them in
would multiply the catalogue by every SKU and make search and reporting
worthless.

### ✅ APPROVED — typing is never a failure

`Other brand` and `Other model` are ordinary options, not error states. A shop
receiving a handset nobody has catalogued books it in **now**. Legacy free-text
products open in manual mode ready to edit, and a lower-case `samsung` still
matches Samsung. Changing the brand clears the model **and nothing else**.

The catalogue is a source of choices, never a constraint on what a product may
be called.

### ✅ APPROVED — a TAC suggests, and proves nothing

The existing ladder is unchanged and was reused rather than replaced: a
confirmed company mapping wins, a proposal is shown but never auto-selected,
otherwise the global table gives generic identity, otherwise unknown.

A TAC is the first **eight** digits. It never infers storage, colour,
condition, cost or price. A valid Luhn checksum proves **nothing** about
authenticity, ownership or theft status. No external service is called, and if
one ever is it receives the TAC — never the full IMEI.

Company corrections stay in `ProductRecognition`, company-scoped: one shop's
decision cannot rewrite the catalogue for everybody.

### ✅ APPROVED — offline is honest

The last catalogue is cached with the durable **non-secret** file storage the
drafts use — a brand list is not a credential. When a cached list is shown the
screen says so. Claiming a live lookup that did not happen is the one thing the
client must never do, and IMEI uniqueness stays server-authoritative.

---

## 6o. Model order, and what a TAC can actually recognise — SHIPPED

### ✅ APPROVED — the list order is a product decision, made once, on the server

Release year was deciding it and could not. **Two facts, two columns:**
`release_rank` is the release YEAR and stays separately queryable;
`display_rank` is where the model sits in its brand's list.

They genuinely conflict, which is why one integer could not hold both:

| | Order by year | Order by family |
| --- | --- | --- |
| `iPhone 17e` (2026) | first | **below** `iPhone 17` |
| `iPhone 17 Pro Max` (2025) | below `17e` | **first** |
| `iPhone 16e` (2025) | above `iPhone 17`, alphabetically | below the whole 17 family |

**Newest family first; within a family, premium first** — Pro Max, Pro,
Air/Plus, standard, then value variants (`e`, mini, SE). Samsung reads Ultra,
Plus, standard, FE.

`display_rank` comes from each model's **position in the source list**, so
correcting the order means moving a line. Ranks are spaced by ten so a model
can be slipped in without renumbering a brand, and every model has a distinct
rank — which removes the tie-break entirely. That last part matters: a
comparator falling back to a NAME would sort differently in Arabic than in
English, and the catalogue must read the same in all three.

**The API returns the canonical order and clients do not re-sort.** A test greps
the mobile client for `.sort(` and `localeCompare` and fails on either.

### ✅ APPROVED — three different counts, never added together

These get confused constantly, so they are reported separately and always will
be:

| | What it is | Staging | Development |
| --- | --- | --- | --- |
| **Selector catalogue** | what somebody can *choose* | 13 brands / **323 models** | 13 / 323 |
| **TAC rows** | what an IMEI can be *recognised* from | **20** (all `synthetic_staging`, all Apple) | **0** |
| **Company mappings** | what one shop has *decided* | 0 | 7 confirmed |

**19 of 323 selectable models can be recognised from an IMEI — 5.9%.** The rest
are chosen from the list or typed. Saying "323 models" and meaning "323
recognisable" would be the easiest lie to tell here, so `scripts/tac-coverage.ts`
prints all three and refuses to total them.

Broad recognition needs **licensed GSMA data**. Nothing substitutes for it.

### 🔴 PENDING — camera verification

`scripts/staging-scan-sheet.ts` prints the fixture's synthetic identifiers as
Code 128 barcodes so a phone can be pointed at them. **Printing it is not
verification, and the sheet says so on its own face.** Web export, HTTP tests
and Expo Doctor are none of them a camera.

---

## 6p. What a confirmed mapping needs, and what coverage means

### ✅ CORRECTED — a confirmed company mapping resolves on its own

An earlier coverage report said development had zero `tac_catalog` rows, seven
confirmed `ProductRecognition` records, and that **no IMEI resolved there**. Two
of those three statements were wrong.

**Four of the seven were BARCODE mappings.** Only three are `codeType: 'tac'`,
and only that kind answers "what phone is this IMEI".

**Those three resolve with no global row at all.** `resolveTac()` returns
`company_confirmed` with the shop's exact `productId`; the global entry supplies
only the generic brand and model LABELS. A missing global row costs the labels,
not the resolution — and the company's answer is the stronger one, because it
names a product rather than a manufacturer.

**There is no dependency to document.** Confirmed mappings stand alone.

Proved by seven unit tests and nine real-HTTP checks: the owning company
resolves it with zero global rows in existence; an **entitled** other company
gets `none`; a generic row added afterwards cannot displace it; an unmapped TAC
stays unknown; an Employee's submission is a proposal that selects nothing.

> The other company had to be an *activated* one. A pending tenant is refused by
> the entitlement guard before the resolver runs, which proves the guard rather
> than the isolation.

### ✅ APPROVED — coverage is reported in four parts, never as one number

| | What it answers |
| --- | --- |
| Selector catalogue | what can be *chosen* — needs no IMEI at all |
| Global TAC catalogue | what resolves *generically*, by source and by brand |
| Company-confirmed mappings | what one shop has *decided*, per company |
| Effective per-company | the union of the two above, deduplicated by TAC |

**`5.9%` keeps its label or it does not get used.** It is *staging's generic
synthetic catalogue coverage* — 19 of 323 models, source `synthetic_staging`.
It is **not** system coverage and **not** production coverage. Development's
equivalent figure is **0%** while still resolving three codes, which is the
clearest demonstration that the number does not mean what it looks like.

Broad *generic* recognition needs licensed GSMA data.

---

## 6q. Counting by model, and what `variant` has always meant — SHIPPED

### ✅ APPROVED — one phone is one Unit; "four in stock" is a presentation

A phone is one `Unit` with its own IMEI, and that never changes. It is how a
handset is found, sold, warranted and traced, and it is the only record of a
specific physical object the shop owns.

But nobody stands in a shop and says *"I have IMEI 01000000… and IMEI
01000012…"*. They say **"I have four 17 Pro Max"**, and the stock list only ever
answered the first question — so counting a model meant counting rows by eye.

Both answers are now available and **the model answer is the default**, because
it is the one asked fifty times a day. Tapping a model shows its units; typing
in the search box switches to units on its own, because searching an IMEI is a
question about one handset. Nothing about the data changes: every phone is still
an individual unit, still findable by either identifier.

### ✅ APPROVED — the count is derived, never stored, never client-side

`GET /inventory/by-model` groups `in_stock` units on every request, scoped to
the company by the tenant client and to the active branch by the same
`assertAssignedToBranch` check the unit list makes.

There is deliberately **no stored total and no client-side counter.** A number
that is maintained rather than derived drifts the first time a sale, a transfer
or a refused duplicate takes a path nobody remembered to update — and that drift
is silent. Deriving it makes the failure impossible rather than tested-for:

- scanning changes nothing, because scanning creates no row;
- choosing a model or a product changes nothing, for the same reason;
- a refused duplicate IMEI changes nothing — it never became a row;
- a sale, a transfer or a fault moves the count through the **existing status
  model**, without the counting code being told anything.

### ✅ APPROVED — folded by brand and model, not by product id

Storage and colour live in `products.variant`, which is part of the
`(company, brand, model, variant)` unique key. Four 17 Pro Max in four colours
are therefore four *product* rows, and grouping by product id would report
`1, 1, 1, 1` — arithmetically true and useless.

The headline is per **model**. The colours sit one level down, in the detail
view, and always add up to the headline.

### ✅ APPROVED — `variant` means storage and colour, and nothing else

Audited rather than assumed. `schema.prisma` states it outright on
`DeviceModel`: *"`products.variant` already carries storage and colour"*, and
`catalog.service.ts` calls a product row "the exact-variant identity".

Two consequences, both deliberate:

- **There is no market or region selector.** A region would be a new fact about
  a phone that nothing in the schema, the API or any shop's data has ever
  recorded, and it would add a fourth term to the unique key — one more product
  row per market, for a distinction nobody has made. If a shop ever needs it, it
  is a decision with a migration behind it, not a dropdown.
- **`Pro`, `Plus` and `Ultra` are not variant values.** They are part of the
  commercial model name and arrive from the model selector. Offering them again
  would file one phone under two identities.

### ✅ APPROVED — storage and colour are lists, and no typed value is ever lost

The field was free text, so one shelf held `128GB`, `128 gb`, `128 Go` and
`128`: four product rows for one phone. Ten capacities and sixteen colours are
now served from `/device-catalogue/attributes` — from the server, so the app
holds no list of its own to drift from.

`Other` is an ordinary row at the end of both lists, not an error state, and it
is also the fallback when there is no signal and no cached copy. **Every value a
shop has ever typed still opens, still shows and still saves.**

The one thing deliberately rewritten is a **known synonym**: `Grey` becomes
`Gray`, `128GB` becomes `128 GB`. One spelling per value is the entire point.
Nothing unrecognised is ever dropped.

### ✅ APPROVED — a phone is never counted as a quantity

"How is it counted?" no longer offers **Quantity** for a phone. Twelve iPhone 15
with no IMEIs behind them cannot be sold to a named handset, warranted, traced
after a theft, or told apart — and the loss is silent and permanent. Each of
those twelve stops being a thing and becomes a number.

Removed rather than disabled: a greyed-out control invites *"why can I not press
that?"*, and the honest answer is that it was never a choice.

The signal is the brand being in the **device catalogue**, which is a catalogue
of phones, server-owned, and not editable into being wrong from a handset. A
category's `defaultTrackingType` answers a different question — *how does this
shop usually count things like this* — and a shop that set it wrongly would get
exactly the outcome this prevents. When the catalogue cannot tell, the answer is
"not a phone", so **accessories keep quantity tracking**: a shop cannot book in
cables one by one.

### ✅ APPROVED — legacy duplicate products are reported, never merged

`scripts/audit-duplicate-products.ts` is permanently read-only. Two rows that
look identical to a string comparison can be a real distinction somebody made
deliberately, and merging them moves units between products — which moves cost,
margin and history with them. That is a decision for a person who knows the
shop, informed by the list.

It separates **collapsible** groups (spelling differences, from the free-text
era) from **variant-only** groups (same model, different storage or colour),
which are usually correct. Model-level counting already folds both into one
line, so this is about tidiness and reporting, not a wrong number on screen.

Current staging state: 13 products, 0 duplicate groups of either kind.

### 🔴 PENDING — the number on the screen

`scripts/staging-verify-model-count.ts` proved the rule against MySQL: 20 units
across 19 models, iPhone 11 went 2 → 3 on one added unit, no other model moved,
the duplicate was refused by the database itself, and the fixture returned to
20 with the temporary unit removed.

**That proves the rule and not the screen.** Whether the number a shopkeeper
sees changes after a save on a real phone is still open — `docs/24` §9q steps
8–15.

---

## 6r. Acceptance is earned, not immediate — SHIPPED

### ✅ APPROVED — a barcode must be HELD, not merely seen

Three physical attempts, three failures. The scanner recognised something in
well under a second — before anybody had finished bringing the phone to the
label — accepted it, and removed the camera. On a sheet of adjacent codes it
frequently took a neighbour, or one only half in shot.

The decoder was not wrong. A barcode partly in frame is still a barcode. **The
product decision that was missing is that the first thing seen is not the thing
meant**, and those coincide only when the camera is already still.

A payload is accepted when the same normalized bytes have been decoded at least
**3 times**, spanning at least **1 000 ms**, with **no gap over 400 ms** between
sightings. The gap clause is the one that carries the meaning: a code that
drifts out of frame and returns was passed over twice, not aimed at.

### ✅ APPROVED — no delay may be blind

`docs/24` §9p left a test asserting that "detection is never delayed", banning
every delay mechanism. It was written when the fault was a frozen frame, and it
read "fast detection is acceptable" as "acceptance must never take time". **3/3
device failures is what that cost**, and the assertion has been replaced.

The rule that survives is narrower and correct: **nothing that fires on its own
may accept anything.** A `setTimeout` that takes whatever is current after a
second accepts the *last* thing seen rather than the first, and fires when the
camera may point anywhere — the same defect wearing a different hat. Every
decision is made from an observation that actually arrived, on a monotonic
clock. The one interval in the scanner drives a *label* and is asserted to be
incapable of accepting anything.

### ✅ APPROVED — nothing happens during stabilization

Until the rule passes: the **camera stays live**, there is **no result screen,
no lookup, no haptic**, and **no Product or IMEI is committed**. One haptic
fires, once, after acceptance. Buzzing at every decode is what made sweeping a
sheet feel like a successful scan.

The window resets on a different payload, on a gap, on cancel, on "Scan again",
on "Add second IMEI", and on every new scanner session — a window half-built
when the sheet closed must never be completed by the next opening.

**An invalid IMEI never becomes a candidate.** Holding still on a mistyped code
must not turn it into a good one: stability is evidence of aim, never of
correctness. An *unusable* read also does not destroy a window somebody is
already holding, because sweeping past a damaged label while aiming at a good
one is evidence of nothing either way.

### ✅ APPROVED — the frame guides, and does not claim to gate

There is a central aiming frame with two lines of plain language — *"Position
the barcode inside the frame"*, then *"Hold steady…"*. No "checksum", no "Luhn",
no "stabilizing": the person is being asked to do one physical thing.

It is **guidance, not a constraint**, and the copy never says otherwise.
`expo-camera` documents `bounds` as sometimes an empty rectangle and sometimes
"the area used by the scanner" rather than the code, and `cornerPoints` as often
absent, with **corner order differing per platform** and no documented
coordinate space. Guessing wrong would silently reject every scan on whichever
platform was guessed wrong — on hardware nobody here can test.

`withinGuide` and the bounds path in the stabilizer are written and tested, so
enabling this later is returning a value from one function.

### ✅ APPROVED — physical QA uses one fixture at a time

The QA sheet holds thirty-two cards, several of which are in frame at once. A
wrong result on that page could be the scanner's fault or the page's, with no
way to tell — so it was never usable for judging the scanner.

Every code now opens **alone, full screen**: one barcode at twice the height,
white to the edges, a wide quiet margin, the expected result underneath, and a
way back. One code per view, dual-SIM cards included — two identifiers on one
page would reintroduce exactly what this removes.

No identifier is regenerated: the grid and the solo view read from the same
built strings. CSS `:target` alone — no script, no network, staging-only.

### 🔴 PENDING — a camera has still not confirmed any of this

`lib/scan/stabilizer.test.ts` proves the rule exactly, with a clock the tests
advance by hand: 999 ms rejected and 1 000 ms accepted, resets on payload change
and on gaps, invalid IMEIs never candidates, no haptic or lookup during
stabilization.

**That is arithmetic, not a camera.** Whether a real decoder produces callbacks
often enough to satisfy the rule comfortably, and whether one second feels right
in the hand, are open until `docs/24` §9r is run on a phone.

---

## 6s. Target acquisition on a crowded label — SHIPPED

### ✅ APPROVED — one candidate is not enough

`expo-camera` fires `onBarcodeScanned` **once per barcode, not once per frame**.
A phone label carries IMEI 1, IMEI 2, a serial and a model number, so a
stationary camera produces four interleaved callbacks.

Tracking a single candidate and resetting on every payload change meant those
callbacks cancelled each other — **4 950 ms held perfectly still, 0 accepted.**
The scanner could not book in a phone at all. Candidates are now tracked
concurrently, each earning its own window, and one is selected.

Interleaving is the normal case for this product, not an edge case.

### ✅ APPROVED — dominance is judged against every live candidate

The first fix had the original defect hiding one level up: whichever code
crossed the one-second line **first** won uncontested, because no rival was yet
eligible to compare against. Since callbacks arrive one barcode at a time, that
is decided by decoder emission order — which is exactly "accept whichever
arrived first".

A candidate must now lead every *live* rival, not merely every eligible one.

### ✅ APPROVED — a code that cannot be used never blocks one that can

A serial number decodes as readily as an IMEI and often sits nearer the reticle.
Ranking everything together and checking usability afterwards meant the scan
failed with "that is not an IMEI" **while the IMEI was in frame throughout**.

Usable candidates are considered first and separately. When the caller is
booking a phone in, an IMEI also outranks a stray product barcode — ranking
only, because the same sheet reads ordinary barcodes and must keep working.

### ✅ APPROVED — indecision is preferable to a coin toss, but must be bounded

Two equally-held candidates with no trustworthy position cannot be told apart.
Acquisition continues rather than picking one, and `AMBIGUITY_GRACE_MS` caps
that so it can never hang: after it, the ordering decides — arbitrary between
true equals, but stable.

### ✅ APPROVED — the reticle ranks, and never gates

Established from the native source in `node_modules/expo-camera`:

- **iOS AVFoundation** passes barcodes through
  `previewLayer.transformedMetadataObject` — preview points, usable against the
  measured preview size.
- **iOS Vision** reports `VNBarcodeObservation.bounds`, already normalised 0–1.
- **Android ML Kit** reports image pixels ÷ display density, and **the image
  dimensions are never forwarded to JS**. No denominator exists.

Android therefore ranks by stability alone. **No scan is ever refused for want
of a coordinate**, and no speculative Android normalisation was attempted: its
failure mode is a scanner that rejects everything, on hardware nobody here can
test.

### ✅ APPROVED — an unusable code is a note, not a dead end

A barcode aimed at for a full second that cannot be used gets one brief message
in the existing vocabulary, over a **still-live camera**, with the sheet still
open and nothing committed. A cooldown stops it repeating every frame; it
expires, because somebody who came back deserves telling again.

### ✅ APPROVED — the acquisition is visible

The reticle fills as the window builds. A silent second reads as a frozen app —
the same complaint as the original defect, from the opposite direction.

### 🔴 PENDING — the constants have not met a phone

Every threshold is exported and documented so it can be tuned after a device
test rather than hunted for. `MAX_GAP_MS` is the one most likely to need it: it
answers "is this code still in frame?" and must not assume a callback rate, so
it is deliberately generous for a slow device showing a busy label.

38 stabilizer assertions and 44 scanner-behaviour assertions pass with a
hand-advanced clock. **That is arithmetic, not a camera** — `docs/24` §9s.

---

## 6t. Several visible IMEIs: ask, never guess — SHIPPED

### ✅ APPROVED — timing cannot identify intent

With three IMEIs in frame the scanner alternated between them, sometimes waited
indefinitely, and sometimes chose one nobody meant.

The previous rule waited for one candidate to *dominate*. Two IMEIs held side by
side accumulate at the same rate and never separate — so it waited, and when the
grace period expired it picked one arbitrarily. **The hang and the wrong pick
were the same line of code.**

The principle that replaced it: **stability says a barcode is being held still;
it never says it is the one somebody wanted.** No constant bridges that gap, so
the scanner stops guessing and asks.

### ✅ APPROVED — one is not a question; two or more is

| Valid IMEIs | Behaviour |
| --- | --- |
| one | continues automatically after its window |
| two | camera stops; choose one, or *"Use both — one phone"* |
| three or more | camera stops; all listed; **never** auto-selected; at most two |

Asking is for ambiguity. Making somebody confirm a single unambiguous scan would
tax the common case to fix the rare one, and this app is measured against a
notebook.

### ✅ APPROVED — nothing happens while the question is open

Camera **off**, so the list cannot change under somebody reading it. **No
haptic**, because nothing has succeeded. **No recognition request** — `/scan` is
driven by a confirmed identifier and a question has none, which is also what
prevents a response for an unintended candidate arriving later and replacing the
visible result. Nothing is committed.

### ✅ APPROVED — "both" is confirmed, never assumed

Two IMEIs near each other are not evidence of one handset: a bench, a drawer or
a display card can put two phones in frame. **"Both IMEIs belong to one phone."**
is stated *with* the choice rather than in a confirmation afterwards, because
filing two handsets as one is not correctable later.

Two is also not a UI limit — a `Unit` carries a primary and a secondary, so a
third selected identifier would have nowhere to go.

### ✅ APPROVED — a candidate must be seen repeatedly to be offered

One stray decode from a neighbouring label is not a plausible target. Offering
it would turn ordinary scans into multiple-choice questions, so candidates clear
the same `MIN_OBSERVATIONS` bar the accept path uses. Invalid identifiers are
never offered and never displace a valid one.

### ✅ APPROVED — the reticle ranks the list and decides nothing

Where coordinates are trustworthy the panel opens best-aimed first. That is
presentation only. On Android no coordinate can be normalised, so the order
carries no positional information and the person simply chooses — **explicit
selection is the Android fallback, not a stability-only guess.**

### ✅ APPROVED — IMEI 1 is never at risk while adding IMEI 2

It is excluded from collection entirely, so it cannot be offered, counted as a
rival to the identifier being looked for, or picked twice. Only one further
identifier may be selected, and *"Scan again"* from the panel keeps it.

### ✅ APPROVED — four result meanings, kept apart

| Situation | What is shown |
| --- | --- |
| valid IMEI, recognised TAC | the product |
| valid IMEI, unknown TAC | **IMEI detected** + **Product not recognized** |
| 15 digits, bad checksum | the invalid-IMEI explanation |
| nothing was an IMEI | **No IMEI found** |

A valid IMEI whose product is unknown is a **successful** scan of an
uncatalogued phone. Reporting it as "nothing found" told people the scan had
failed when it had worked, and sent them back to rescan a correct code.

### 🔴 PENDING — none of this has met a camera

49 stabilizer, 28 machine and 58 scanner-behaviour assertions pass with a
hand-advanced clock, including alternating callbacks reaching a question rather
than hanging. **That is arithmetic, not a device** — `docs/24` §9t, which must
be run on **Android and iOS separately** because they take different code paths.

---

## 6u. The scan region — SHIPPED, and enforceable on one platform

### ✅ APPROVED — the frame is the boundary, and containment is total

Only a barcode **completely** inside the rectangle may be considered. A callback
that fails is dropped before classification, stabilization, haptics, recognition
or any message — it never happened.

**The centre is not the test.** A barcode straddling an edge has its centre
inside while half of it is out of shot, and that is the read that produces a
wrong digit. Two barcodes each crossing the frame is *no detection*, not a guess
at whichever is more covered.

### ✅ APPROVED — one frame, sized for one barcode

Two overlapping shapes — corner brackets and a rounded rectangle — meant the
active area was whichever one you read. **Two frames on a scanner is worse than
none**: it promises a boundary and leaves you to guess which.

One wide, shallow rectangle, 84% of the preview width and 0.34 of that as
height, with the accents drawn on it so they cannot drift. Tied to width rather
than to the preview's height, because the constraint is "one barcode", not "a
proportion of the screen" — a frame that grew on a long phone would end up
holding two stacked codes on exactly the devices where that is easiest to do by
accident.

Drawn from the same rectangle the gate tests, so the shape on screen and the
boundary in the code cannot diverge.

### ✅ APPROVED — the mask is guidance, and is never the mechanism

Four scrim panels around the rectangle rather than a cutout, which needs no mask
layer; inside stays clear glass, because a barcode read through a tint is read
worse. No blur — `expo-blur` is not installed and none was added for it.

### 🔴 PLATFORM LIMITATION — enforceable on iOS, not on Android

Audited from the native source in `node_modules/expo-camera@17.0.10`.

**iOS can.** `MetaDataDelegate.swift` passes metadata through
`previewLayer.transformedMetadataObject`, so corners arrive in preview points
with aspect-fill, rotation and mirroring applied — the same space `onLayout`
reports. It loops all `metadataObjects`, so each barcode is judged on its own
geometry.

**Android cannot.** ML Kit corner points are rotated *image* pixels;
`BarcodeScannerResultSerializer.kt` divides by display density and sends
`data · raw · type · extra · cornerPoints · bounds`. The image dimensions are
captured in Kotlin and **never put into that bundle**. No denominator, no
rotation, no mapping. It also reports `barcodes.first()` only.

**Nothing is inferred.** Guessing an extent fails by silently rejecting every
scan, on hardware that cannot be tested from here. `no-geometry` is never
treated as `inside` — collapsing those is how a hard region becomes decorative
while still being described as hard. `bounds` is not consulted at all: Expo
documents it as sometimes empty and as not necessarily bounding the whole
barcode, which is precisely this use.

On Android the frame guides, the existing stability and explicit-selection rules
protect the scan, and the copy claims nothing more.

**Proposed and not implemented**, smallest first: forward `width`/`height` (and
rotation) in `toBundle` — a few lines, upstreamable, and this gate would work
unchanged; then a config plugin cropping the analyzer input; a different scanner
dependency only if both are proven insufficient. No dependency was added or
replaced.

### ✅ APPROVED — a development overlay, with no identifiers in it

The measured rectangle, the received corners and the verdict, behind `__DEV__`.
Coordinates and the **last four digits** only — an overlay printing payloads
would put complete IMEIs on screen and into whatever captured it. Nothing is
logged or persisted.

### 🔴 PENDING — a source test cannot prove a coordinate transform

22 ROI assertions and 58 scanner-behaviour assertions pass. Whether the reported
corners land where the frame is drawn on a real iOS device — through aspect-fill
cropping, at each rotation and aspect ratio — is exactly what they cannot show.
`docs/24` §9u step 8 settles it.

The two device screenshots that prompted this work were **not received**; the
geometry follows the written brief and has not been compared with what the
device displayed.

---

## 6v. The Android scan region, and a committed native patch — SHIPPED, UNCOMPILED

### ✅ CORRECTED — Android was never short of information

§6u recorded that Android could not enforce a scan region because the image
dimensions never reach JavaScript. **That was wrong**, and it came from reading
a file that is not on the active path.

`ExpoCameraView.kt` does map corner points. It maps them with scale and no
translation (so an aspect-fill crop is off by the crop offset), ignores
rotation, and the emitter reads them back **transposed** — corners are written
`[x, y, …]` and read as `y = points[i]`. It also forwarded `barcodes.first()`
only, so neighbours could not be rejected even in principle.

The frame never matched the acceptance boundary because of that, not because
the information was missing.

### ✅ APPROVED — CameraX does the transform, not us

`patches/expo-camera+17.0.10.patch` replaces the arithmetic with
`CoordinateTransform`, built from `ImageProxyTransformFactory` and
`PreviewView.outputTransform`. Those handle crop, rotation and scale together,
which is what they exist for; a hand-rolled formula had already been wrong three
ways at once.

`isUsingRotationDegrees` is on, because ML Kit receives a rotated `InputImage`
and the spaces would otherwise disagree by 90° in a way that looks plausible.

The API surface was verified by downloading `camera-view-1.5.0-rc01.aar` and
running `javap` on it. `getOutputTransform()` still exists in 1.5.0-rc01 —
§6u assumed it had been removed, and that assumption was also wrong.

### ✅ APPROVED — every barcode, non-coalescing

`.first()` is removed. One event per barcode, carrying
`frameId`/`indexInFrame`/`countInFrame`, so *three at once* is distinguishable
from *one, three times* — the two situations the chooser has to tell apart.
Every added field has a default, so the change is additive and existing
consumers are untouched.

### ✅ APPROVED — the capability is read, never assumed

Enforcement is decided **per callback** from a `coordinateSpace` marker the
patch emits. Not from a version number: a patch that failed to apply must not be
mistaken for one that did. Not once per session either, because
`PreviewView.outputTransform` is null until the preview is laid out — the first
frames after opening the camera genuinely have no answer.

An unpatched binary, or Expo Go, never sends `view`, so the strict path stays
off and the existing stability and chooser rules carry the scan. That is the
honest degradation. **Rejecting everything** because geometry could not be
verified would be worse than the defect; **trusting unverified coordinates**
would be worse still.

### ✅ APPROVED — a patch that cannot fail silently

`postinstall` runs `patch-package` and then a verifier that checks the installed
version and six anchors **inside `node_modules`**, exiting non-zero if any is
missing.

A quietly unapplied patch is the worst outcome available here: the scanner keeps
working, every test keeps passing, and the frame stops being the boundary —
visible only to somebody holding a phone against a label. Checking the result
rather than trusting the step is the only defence.

### ✅ APPROVED — one new devDependency, and no more

`patch-package`. No `expo-dev-client` — an internal EAS build is enough to
compile and test, and a dev client is only worth adding if repeated native
iteration proves necessary. No replacement scanner dependency. `android/` and
`ios/` stay generated and uncommitted under CNG; the patch is what makes the
native change durable.

### 🔴 PENDING — never compiled, never run

**There is no `eas.json` and no EAS login in this repository.** The Kotlin has
not been through a compiler and the transform has not executed. No credentials
were invented and no build was claimed.

`docs/24` §9v carries the build command and the retest. Step 1 (does the overlay
say `view`?) tells you the patch is in the binary; step 7 (do the overlay's
corners agree with the drawn frame?) tells you the mapping is right.

**Android strict ROI is not complete until both pass on a physical device.**

---

## Storage and Colour: searchable selectors, with a bundled floor

**Approved.** Storage and Colour are searchable selectors with the same shape as
Brand and Model, and they never depend on what a shop happens to have registered
before.

### Where the options come from

| Order | Source | Notes |
|---|---|---|
| 1 | The server, `GET /device-catalogue/attributes` | **Authoritative.** When it answers, its lists are used. |
| 2 | The last saved copy on the device | Used when the request fails and a copy exists. |
| 3 | A bundled baseline in the app | Used **only** when the request fails and no copy exists. |
| — | `Other` | Always present, always last. Reveals a text field; the typed value is stored verbatim. |

The origin travels with the answer — `live`, `cached`, `fallback`,
`unavailable` — so the screen never presents a failure as a normal result.

### Company history is deliberately NOT a source

Considered and rejected. `/device-catalogue/attributes` is unscoped reference
data with no tenant filter, and aggregating "values this company used before"
would make it company-scoped — a real isolation surface — to add capacities and
colours the curated list already covers. The curated defaults are what make a
brand-new company useful on day one; history adds little and risks more.

### Model-specific variants

**Not implemented, deliberately.** There is no reliable mapping from a model to
its official capacities and colours, and inventing one would put false facts in
front of a shopkeeper. If such a mapping ever exists, model-specific options are
shown first — until then the lists are generic and nothing claims otherwise.

### Why a bundled list exists at all, against the no-second-catalogue rule

Brands and models keep the strict rule: **the app holds no list of its own**,
because they change constantly and a stale bundled copy would be worse than
none. Storage and colour are a narrow exception, for one reason: capacities and
basic colour names do not change. 128 GB and "Black" will mean the same thing
next year, while models appear every autumn.

The failure that forced it: when the attributes request failed, **both lists
came back empty** and the shopkeeper was pushed into typing — at a counter,
holding a handset. A bundled floor is worth the drift risk there, and the drift
risk is contained by a test that reads the server's own list and fails when
either side moves.

### The four states stay distinct

| State | What is shown |
|---|---|
| Loading | A loading line. |
| Loaded with results | The options, immediately, before any typing. |
| Successful empty response | "The list is empty. Choose *Something else*." **Not** a failure. |
| Request failure | The bundled options, a non-blocking warning that the latest could not be fetched, and **Retry**. |
| Search matched nothing | "No matches for …" and *Something else*. **Never** alongside a load failure. |

Opening a chooser shows options without opening the keyboard. The keyboard opens
only when the search input is tapped, and outside-tap dismissal follows the
already device-verified behaviour.

### Canonical values

Storage `4 GB … 2 TB` and sixteen colours, keyed canonically (`128gb`, `gray`)
with display labels. `128GB`, `128 gb`, `128 Go` and bare `128` all normalise to
one option; `grey` normalises to `gray`. `Other` appears exactly once, last.

---

## Supported runtime: Expo SDK 57

**Approved.** The app targets **Expo SDK 57** (`57.0.20` or later) on React
Native 0.86.

### Why the upgrade was forced

Expo Go is a single App Store binary that supports one SDK at a time. When it
moved to SDK 57 it stopped opening SDK 54 projects, and physical iPhone testing
stopped with it. The owner develops on Windows with no paid Apple Developer
membership, so Expo Go **is** the iPhone testing route — an EAS device build is
not a substitute for this purpose.

### The path taken

`54 → 55 → 56 → 57`, deliberately, with the full gate set at each stop. The
intermediate breaking changes are real and would have been invisible in a single
jump:

| Checkpoint | What broke, and why |
|---|---|
| **55** | Legacy Architecture dropped, so `newArchEnabled` no longer exists. `android.edgeToEdgeEnabled` removed — edge-to-edge is now always on. Expo package majors synchronise to the SDK (`expo-router` 6.x → 55.x, `expo-camera` 17.x → 55.x). |
| **56** | `expo-router` **vendors** React Navigation; the published `@react-navigation/*` packages must not be direct dependencies. React Compiler lint rules promoted to errors. |
| **57** | Hermes V1 memory regression present at 56, fixed in `expo@57.0.9`+. Hence 57.0.20, not 57.0.0. |

### The react-navigation split is a correctness matter, not tidiness

A standalone `@react-navigation/elements` is a **different module instance** from
the one `expo-router` vendors, so its `HeaderShownContext` is a different React
context object that no provider ever fills. `useContext` would return the
default forever, `Screen` would believe no header is shown on routes that have
one, and the status-bar inset would be reserved twice — silently restoring the
~50pt of dead space that was already fixed once, visible only to somebody
holding the phone.

`lib/navigation/router-internals.ts` is the single place that reaches into
Expo Router's vendored tree for the two symbols it does not re-export
(`HeaderShownContext`, `usePreventRemove`). Deep internal paths may move, so a
test asserts they still resolve and that nothing imports or declares the
standalone packages.

### React Compiler lint rules are warnings, deliberately

SDK 56 promoted them to errors; they fire 32 times, and every one is a
pre-existing pattern written and device-verified long before the rule existed.
They are demoted to warnings — not silenced, not fixed. Rewriting eighteen
`setState`-in-effect sites across the scanner, keyboard handling and catalogue
selectors would risk exactly the behaviour the upgrade exists to preserve, to
satisfy a linter. **That is its own task, with device retesting.**

### The Android camera patch survives, smaller

Of the three defects it fixed, upstream `expo-camera` 57.0.4 now fixes two — the
missing translation on an aspect-fill crop, and the transposed corner-point
read. Those hunks are gone (10 hunks → 8).

Two reasons it still exists:

1. **Rotation is still ignored upstream.** There is no rotation term anywhere in
   that path, and a scale-and-offset model cannot express rotation without
   becoming a matrix — at which point it is a worse `CoordinateTransform`.
2. **`coordinateSpace` does not exist upstream.** That marker is what the app
   gates strict ROI on, so a patch that failed to apply cannot be mistaken for
   one that did. Without it the app silently stops enforcing a scan region.

Upstream also still calls `barcodes.first()`, discarding every other code in the
frame — on a phone box, where IMEI 1 and IMEI 2 are separate barcodes, one
arrives and which one is arbitrary. The patch keeps one event per barcode.

---

## Category-aware intake: phones are counted one by one, everything else is counted

**Decision.** A product's **category** decides how it is received, and the
server is the only thing that decides it.

- **Phone categories → `imei`.** Each handset is registered individually. The
  primary IMEI is required; the second is optional and lives on the same `Unit`
  row, so either IMEI finds the same phone. One phone is one unit of stock.
- **Every other category → `quantity`.** No IMEI field, no scanner instruction,
  no duplicate check. Stock arrives as a number, and a second delivery of the
  same thing increases the number rather than creating rows. **Nobody registers
  identical pieces one at a time.**
- A product barcode stays optional and company-scoped. It identifies the
  reusable *product*, never an individual unit, and is never an IMEI.

### Nothing reads a category name

Category names are company-owned free text and are translated in the UI, so
"Phone", "Téléphone" and "هاتف" are one workflow. Behaviour keyed to a label
would depend on a shop's spelling. The stable server-side
`ProductCategory.defaultTrackingType` is the only signal, and
`src/tracking/tracking-modes.ts` is the only place the rule lives.

### The category is authoritative, and a contradiction is refused

The old code read `trackingType ?? category.defaultTrackingType` under a comment
claiming the category drove it. It did the opposite — the client won. A request
could name the Phone category and ask for `quantity`, producing a phone received
in bulk that never gets an IMEI, or name Accessories and ask for `imei`,
demanding a serial number for a charging cable.

A contradicting mode is now a **400**, not a silent override, so the form and the
server can never tell the employee different stories. Re-filing a product under a
different category re-derives the mode, because that is a tracking change even
when the request never mentions one.

### `serial` is retired, not deleted

Only `imei` and `quantity` may be chosen. `serial` remains in the enum, keeps
working, and may be re-saved unchanged — the development database has a
`Televisions` category holding **five serial-tracked units**, and reinterpreting
them was never on the table. What is refused is *newly choosing* it.

> This is a deliberate, recorded exception to "all non-phone categories use
> quantity". That rule governs what may be *chosen from now on*; it does not
> authorise rewriting stock that already exists. Converting Televisions would
> require a decision about those five units that nobody has made.

### Existing stock is never reinterpreted

A tracking mode freezes as soon as the product has units, stock, purchases,
sales **or transfers** — transfers were previously missed, so a product that had
only ever moved between branches looked untouched. Reservations ride on the
stock row and returns on the sale line, so both were already covered.

The same protection applies one level up: a **category's** mode cannot change
while products use it. That is the realistic accident — an owner tidying up
categories turning a shelf of counted accessories into things the app demands
IMEIs for. The refusal says how many products are affected.

Five `Unit` rows are not a `StockItem` of five: each carried its own cost and its
own IMEI. There is no honest automatic conversion, so none is offered. The answer
is a new product.

### A retry must not deliver the goods twice

Serialized intake was always retry-safe by accident of design: the `Unit` row is
the event and the IMEI is a natural key, so a duplicate collides on the index.
Counted goods had neither. `stock_items` holds a *balance*, never the receipts
behind it, so a lost response followed by a second tap added the goods again —
stock rose, the weighted average absorbed items that never arrived, and nothing
recorded that it had happened.

`stock_receipts` (migration **0064**) is that missing event, carrying the same
`client_uuid` + `client_request_hash` pair purchases, transfers and corrections
have used since 0013. Same key and same payload replays the first answer; same
key and a *different* payload is a conflict, because that is a second delivery
wearing the first one's identity. The unique index decides the race, not an
application read — verified on real MySQL with five simultaneous identical
requests, of which exactly one survived.

It is deliberately not back-filled: a balance cannot be decomposed into the
receipts that produced it.

### Costing is unchanged

Receiving still goes through `receiveQuantityAtCost` — one
`INSERT … ON DUPLICATE KEY UPDATE`, weighted average on physical quantity, cost
assigned before quantity because MySQL evaluates left to right. **Receiving never
reprices the shelf.** No FIFO, LIFO or new averaging rule was introduced.

### "Details" is gone from the form; the data is not

The free-form key/value **Details** editor is removed — it duplicated, in worse
form, what category attribute schemas already do. `Product.specifications` stays:
it is searched by raw SQL, returned as `keySpecifications`, shown on the detail
screen and validated against the category's schema. The form simply omits the
key, which on a PATCH means "leave it alone", so historical values survive
untouched. **No migration was added to drop a column that is still load-bearing.**

Storage and colour were never in that object. They live in `products.variant` via
`VariantSelect` and remain structured selectors.

---

## The indigo refresh, and a motion system that is never in the way

**Decision.** Indigo is the app's one interaction colour. It marks what is
*actionable or chosen* — primary actions, selection, focus, navigation
emphasis — and nothing else. It never means "good".

### Status colour, and never colour alone

| Meaning | Colour |
|---|---|
| Selected, actionable, primary | **indigo** |
| Completed, confirmed | **green** |
| Pending, low stock, needs attention | **amber** |
| Error, destructive, invalid | **red** |
| Informational, inactive | **neutral** |

Green is reserved for a **server-confirmed business outcome**. A barcode being
detected is not success — it is a reading, and it may still be rejected. This is
why the scanner's accepted-detection mark is indigo, not green: the phone has
been *identified*, not *added*.

Every one of these is paired with a word, an icon, or both. `status.ts` is where
that pairing lives, and it is the reason no state in the app is expressible in
colour alone.

### The palette is measured, not chosen by eye

Approved values: primary `#5146D9`, selected wash `#EEECFC`, background
`#F7F8FB`, text `#172033`, surfaces white. The accent ramp was re-cut around the
two approved anchors rather than having them dropped into the old scale, because
two transplanted steps band visibly exactly where the accent is used most.

Contrast is asserted in the test suite, not asserted in prose: white on primary
6.51:1, primary on the selected wash 5.59:1, text on surface 16.27:1.

**Dark mode is chosen, not derived.** The readable accent becomes a light indigo
and the selected wash a deep one — `#EEECFC` behind a selected row at night is a
torch. A test fails if any dark semantic token equals its light counterpart.

A flat `semantic` vocabulary (`primary`, `primarySoft`, `divider`, `textMuted`,
…) exists as **aliases onto the palette**, never a second source of truth.
Components may use either vocabulary; they may not invent a third, and they may
not reach into the raw ramp — the theme suite enforces that, and caught the
scanner reticle doing it.

### Motion

| What | Duration |
|---|---|
| Button press (scale to 0.98) | 120 ms |
| Selection, checkmark | 150 ms |
| Content or result reveal | 200 ms |
| Bottom sheet in/out | 260 ms |

**Animation is presentation. It never gates behaviour.** No save, mutation,
validation, scanner lock or navigation decision waits on an animation. The
motion module contains no timer, no promise and no `await`, and a test asserts
that — the tempting failure is making a caller wait so the animation "finishes
first", which is exactly how a fade ends up delaying a lock.

`motion.ts` imports nothing at all, so the timings and the Reduce Motion
decision are testable under bare node; `motion-easing.ts` binds the curves to
Reanimated. That boundary is asserted too.

**Reduce Motion removes movement, it does not shorten it.** For some people
travelling UI causes genuine nausea, and a fast lurch is still a lurch. Movement
is replaced by a 100 ms cross-fade — never an instant swap, which is its own
accessibility problem. The sheet stops travelling and fades in place; buttons do
not scale at all.

Destructive buttons are excluded from the press scale. A refund should feel like
a decision, not a satisfying tap — the friction is the feature.

No looping, decorative, bouncing or attention-seeking animation exists anywhere,
and none may be added.

### The scanner may animate, under conditions

The result surface fades in over 200 ms, opacity only — text that slides while
somebody reads back a 15-digit number is worse than no animation.

It is safe **structurally, not carefully**: the result branch renders only once
the machine is in `result`, by which point the synchronous lock has been held
since inside the camera callback, the camera is stopped and the haptic has
fired. A hundred callbacks during the reveal change nothing, and tests hold that
line. The strict ROI rules and the `coordinateSpace` trust marker are untouched.

The reticle is the accent, using a **light** step: it is drawn over a live camera
feed, which may be a dark stockroom or a glossy white box under a strip light.
Its contrast cannot be computed against an unknown photograph — it is a device
check, not a test.

### Flatter operational lists

Catalog and stock rows are flat, full-bleed and hairline-separated rather than
stacked cards. A card suits rows considered one at a time; it is wrong when
there are forty and the job is scanning a column for one name.

`flat` is a **mode on the shared row**, not a second row component, so a stock
list and a picker cannot drift apart. The leading mark is a category icon:
there is no product image in the API or the model, and adding one would mean a
storage feature nobody asked for.

### The product form is led by the category

Category, then how it will be received (**derived, never chosen**), then brand
and model, then structured attributes, then the optional barcode.

The category decides the intake workflow, so asking for it last would let the
answer change underneath a form already filled in. The tracking mode is no
longer a control at all — the server derives it and would refuse a
contradiction, so a picker here could only produce a rejection the employee did
not cause and cannot fix.

Storage and Colour remain structured selectors, the free-form `Details` editor
stays removed, and `Product.specifications` and category attribute validation
are untouched. A scanned IMEI can never populate the product barcode.

### Selector sheets

Opaque surface, grabber, title, close, search — and the list **already full**
before anybody types, with the keyboard closed. A picker that opens empty and
waits to be searched only helps someone who already knows what they want. Both
properties are now pinned by tests rather than left to be rediscovered.

---

## Completing the redesign: three surfaces, not one

**Decision.** The app uses three container shapes, chosen by what the content
*is* rather than by taste. Getting this wrong in either direction is how the
screens drifted.

| Shape | For | Why |
|---|---|---|
| **Flat rows + hairlines** | repeated operational records — products, stock, sales, notifications | Forty of them, scanned down a column for one name. A border, corner and gap on every line makes a list read as a pile |
| **`RowGroup`** | related facts about ONE thing — an order's status, branch and payment | The border says "these belong together"; the internal hairlines say "these are separate facts" |
| **`Card`** | metrics, warnings, financial summaries | Meant to be *looked at*, not read through. Flattening these until they lose hierarchy is the opposite mistake |

The failure this replaces: detail screens wrapped every field in its own card,
so a sale became six floating boxes with nothing more important than anything
else — and the naive correction, flat rows everywhere, would have destroyed the
financial summaries that need to stand out.

### Separation belongs to the container

A flat row draws **no separator of its own**. A `FlatList` separator or a
`RowGroup` draws it. Separation is a fact about the gap *between* two rows, so
whatever owns both owns the rule. A row drawing its own bottom hairline left a
stray rule under the last item and doubled up inside any group.

Separator insets are **start-side margins**, never `marginLeft`. In Arabic a
physical margin indents from the wrong side — the rule cuts under the text and
stops short of the icon, exactly inverted.

### The token layer is the whole point

Re-anchoring the accent on `#5146D9` reached all 56 authenticated routes without
any screen being edited. That only works while **zero screens hold a colour**,
which is now a test rather than a habit — along with no NativeWind styling, no
utility colour class hiding in a lookup table (how `text-slate-700` survived an
earlier audit and put 1.7:1 text on the dark canvas), and no untranslated
`trackingLabel` showing "Quantity" to Arabic readers.

### Direction is shown, not coloured

Profit and loss were told apart by red and green text of identical shape. Any
auto-toned money is now also **signed**, so the direction survives colour
blindness and a monochrome screenshot. Money uses tabular figures so a column
can be compared down the page.

### Motion is centralised or it is not motion

No component holds a millisecond literal. Dialogs and toasts defer to
`ReduceMotion.System`; nothing springs, overshoots or bounces — a dialog asking
whether to refund money is the worst possible place for a control that bounces
cheerfully into view. All of it is asserted, because the sign-in crash proved
that an animation defect can be invisible to every non-device gate in this
project.

---

## Which surface, decided once

Applying the three-surface rule across every remaining screen produced one
useful artefact: a **classification of all 19 `ListRow` consumers**, asserted in
`lib/design/surface-classification.test.ts`. The target was never "everything
flat" — it was "nothing un-decided".

| Kind | Screens |
|---|---|
| **grouped** | Home, Inventory, More, Analytics, product detail, consignments, devices, discrepancies, expenses, imports, loans, suppliers, team |
| **card** | Money hub, hub landings, settings — metrics and panels meant to be looked at |
| **custom** | branch chooser, category management, dev gallery — a shape that is the point |

Two rules the test enforces, because each had already been broken once:

1. **A grouped screen must actually separate its rows.** Marking a row `flat`
   and forgetting the container leaves borderless text blocks with a gap —
   worse than the cards they replaced, because at least a card had an edge. The
   test caught `imports/index.tsx` doing exactly this.
2. **Financial summaries were not flattened.** Sale totals and the refund
   summary stay cards. Flattening what somebody opens the screen to read is the
   mistake in the other direction, and a "make everything flat" pass causes it.

### Separation is decided in one place

`ListSeparator` exists because eight index screens each needed a rule between
rows, and eight screens each choosing an inset is eight chances to write
`marginLeft` and have it indent from the wrong side in Arabic — invisible to
anyone testing in English. Decided once, it can be wrong only once.

### The scanner says the camera stopped

The result panel leads with an indigo glyph, "IMEI detected", and an explicit
**"Scanner paused"**. A still camera is ambiguous: it looks exactly like a
frozen app. The state machine has already left `scanning` before this renders,
so the panel reports a fact rather than creating one.

**Indigo, never green.** A detected IMEI is a *reading* — the phone has been
identified, not added to stock, and it can still be rejected on the next
screen. Green is reserved for a server-confirmed outcome, and using it here is
how somebody walks away believing the intake finished.

### Refund tone is a money rule, not a palette choice

Approved-but-unpaid and reported-but-unconfirmed are both **amber**; only a
confirmed payout is **green**. Each carries a word as well as a tone, so the
distinction survives a colour-blind reader. Reported is a claim; confirmed is a
settlement; the app must never let the first look like the second.

### Recognition is not existence

`POST /scan` answers two different questions and keeps them apart:

- **`recognized`** — a catalogue fact. A TAC resolved to a product. Every
  iPhone 15 on earth shares that TAC, so this says nothing about stock.
- **`inventory`** — a stock fact. The server looked for *this* handset.

Collapsing them would warn about every phone the shop has ever sold, and the
scanner previously did neither: the duplicate surfaced only when intake hit the
global IMEI uniqueness trigger, after a cost had been typed, as a database
error two forms later.

**`inventory` shape.** `alreadyInInventory`, `matchedIdentifierPosition`
(`primary` | `secondary` | `null`), `unit` (a safe `productLabel` /
`branchName` / `status` summary, or `null`), `elsewhere`, `conflictingUnits`.
It is `null` for a barcode, which names a reusable product rather than one
physical thing. Both IMEIs of a dual-SIM phone are checked together, in one
request, because checking them separately is how two numbers off one box get
attached to two different units.

**The privacy rule.** IMEI uniqueness in this database is global — migration
0042's trigger queries `units` with no company filter — while the tenant client
is company-scoped. Left alone that is the worst of both: the duplicate is
invisible *and* unreceivable. So the contract asks twice. The **scoped** client
returns a safe summary for a unit this user can actually reach. The **system**
client is asked for a `count` and nothing else: a number has no shape for
another tenant's data to travel in.

A unit outside the caller's reach — another company, or a branch they are not
assigned to — sets `elsewhere: true` and carries no company, branch, product,
owner, status or identifier position. Intake is refused; the holder is not
named. This reveals nothing the insert trigger would not reveal a minute later
in plainer words.

**Never cost, never margin, never an internal id.** Not in the response, not on
the screen. The mobile warning shows the localized sentence, plus product and
branch only when the server sent a summary at all, and disables "Use this
IMEI" while it stands — so the refusal arrives with its reason attached rather
than as a failure the employee cannot act on.

**Two identifiers, two units, no guess.** If the primary and secondary IMEIs
resolve to *different* units, `conflictingUnits` is true and `unit` is `null`.
Something is wrong with the box, the label or the data, and picking one to
display would silently attach the pair to whichever the query happened to
return first.

### A report leaves the app as a rectangle, and the name carries the rest

Six reports export as CSV — profit by product, by employee, by branch, movers,
dead stock, and who owes what. Full contract in
[`docs/40`](40_REPORT_EXPORT.md); the decisions worth restating are these.

**The export defines no metric.** Every figure comes from the service that
already owns it. A second query for "profit by product" would be a second
definition of profit, and the first time the two disagreed the shop would have
no way to tell which was right.

**Authorization happens before serialization, not after.** A CSV is a string,
and a string has no keys left to strip — `CostGatingInterceptor` maps over a
JSON response and never sees a file written straight to the socket. So the
columns a caller may receive are chosen from their real permissions *before any
data is read*. A forbidden column is **removed, not blanked**: an empty cell
under a `Gross profit` header says a number exists and is being withheld, which
invites somebody to go looking. And a report left with nothing but figures the
caller may not see is **refused**, because a list of product names is not a
smaller profit report — it is a different, useless one.

**Complete, or refused.** The dashboard's ten dead-stock rows and the loan
screen's two hundred are card-sized, not report-sized; the export asks for
everything. Past a stated limit it refuses rather than truncating — a
spreadsheet that silently stops at row 50 000 is worse than no spreadsheet,
because nothing in the file says it is incomplete.

**The file is a plain rectangle.** A provenance block above the table was built
and then removed: `parseCsv` skips blank lines *and* all-empty rows, so the
separator vanished and the metadata arrived as data — and an empty report
stopped being a header-only file, the one shape every spreadsheet handles. So
which report, which period and which branch live in the **filename**, where
every export tool puts them and nothing can misread them as figures.
`dead-stock_as-of_2026-09-10_en.csv` cannot be mistaken for a month of trading.

**Money is a number, not a presentation.** Two decimals, a dot, no grouping, no
symbol — the cell has to add up in Excel, and `4 000,00 MRU` is text. The
currency is named once in the header. Missing stays empty and zero stays zero,
because a shop cannot otherwise tell a measured nothing from a figure nobody
computed.

**Free text is armoured against formulas; money never is.** A cell opening `=`,
`+`, `-` or `@` can execute when a spreadsheet opens the file, and quoting does
not prevent it — quoting is about parsing, and evaluation happens afterwards.
So typed text gets a leading apostrophe. A negative balance does **not**:
prefixing `-4000` would turn it into text and break the arithmetic the export
exists for.

**An export is audited as a generation, not a download.** The server saw itself
produce bytes. Whether they reached a person, a share sheet, an email or a bin
is not something it observed, and an audit trail that claims otherwise is worse
than one that says less. The row records what was asked for and which columns
were allowed — never a cell of the file, which would be a second copy of exactly
what the gating exists to control.

**A downloaded file is no longer protected**, and the sheet says so before
anything is exported. Nothing in the app can un-share a spreadsheet.

### The floor is the price the shop set, not what it paid

Approved by the owner as a binding correction to A2, and implemented in
`erp-backend` `6287b61`.

**The configured selling price is the normal minimum selling price.** It comes
from the ladder `price-resolution.ts` already owns — `UnitPriceOverride` →
`BranchVariantPrice` → `Product.defaultPrice`. Selling below it requires an
Owner-approved exception **even when the sale is still profitable**, because the
configured price is the shop's decision about what a thing sells for, and a
seller quietly undercutting it is the mistake this prevents.

**Below cost is a high-risk subset, not a separate gate.** Same Owner approval,
plus an explicit reason and a loss warning. Cost and margin stay
permission-gated, so a seller without `cost.view` is told that enhanced approval
is required without being shown the figure.

**No second editable floor was invented.** The requirement was to preserve the
recorded decision that the configured price itself is the floor, and prove a
second one is needed before adding it. It is not: the ladder is already the
single authority, and its `version` is exactly what tells an approval that the
price moved underneath it.

**The two thresholds are independent.** An unpriced product has no configured
floor to except — and selling it below cost is still a loss, so it still needs
the Owner.

### An approval is one sale, not a licence

`discount.override` is now **approval authority, held by the Owner alone**. It
no longer lets its holder sell below the floor directly, which is what it did
before — meaning the person who wanted the discount was the person who granted
it. It was removed from the retired `branch_manager` role; the catalogue is
unchanged at 61 keys.

An Owner may approve their own request, and should. It routes their exception
through the same audited workflow rather than letting it happen invisibly.

Each approval is scoped to **one company, one branch, one physical unit, one
exact final price**, lives **thirty minutes**, and is **single-use**. It is
spent by a conditional update inside the sale's own transaction, so two
concurrent sales produce exactly one winner — reading first and writing after
would let both through. It is voided if the unit sells, transfers or changes
branch, or if the configured price or the confirmed cost moves: a decision made
about a different world is not a decision about this sale.

**The sale uses the approved price, never the requested one.** Otherwise an
approval for 15 000 would authorise a sale at 1 500.

**The floor is checked per line**, never on the sale's total margin. An
aggregate check lets a healthy accessory line pay for a phone sold far below its
price.

The receipt shows the actual selling price and discount as it always did. It
carries no approval id, no reason, no cost, no margin.

### A warned mutation has not happened yet

A warning is advisory: it never blocks, never alters a value, never authorises
anything. What it changes is that the mutation **is not persisted** — the caller
returns with an acknowledgement, or nothing happened. Persisting first and
warning afterwards would make the warning decorative.

**The acknowledgement is bound to the payload, not the person.** A boolean in
the body is something any client can send. A per-user "confirmed once" flag is
worse: confirm 170 000, then submit 1 700 000 with the flag still set. So the
token covers a hash of the normalized payload, together with actor, company,
branch, operation, the warning set and an expiry.

**The warning set is part of the binding** — code, field, severity and stable
parameters. Two warnings that say different things must not be interchangeable,
so the same code at a different severity requires a fresh acknowledgement. The
reference figure is deliberately excluded: a median shifting by one unit is the
same warning about the same thing, and re-asking for it trains people to click
through, which is how a warning stops working.

**This is what makes offline replay safe.** A queued request returning to a
world that has moved fails as `warnings_changed` — the signal to pause that
queue item for a human, rather than proceed silently or vanish.

### Money is bounded before the database, not by it

Every money column is `DECIMAL(14,2)`, and one shared boundary now enforces it
across 28 fields. **A database overflow is not a validation mechanism**: it
reports the wrong thing, at the wrong layer, in the wrong language, inside a
transaction that has already begun.

The comparison is exact decimal arithmetic, never floating point — a scale check
written `n * 100 === Math.round(n * 100)` is wrong for precisely the values at
the edge. Each field keeps its own minimum, because a floor is a business
question; the ceiling belongs to the column. A CSV row that cannot fit is
reported as a bad row with a reason the shop can act on. No error message names
a column, a type, or MySQL.

---

## Mistake prevention, CP4–CP6 (2026-09-10)

### An approval is a server fact, and the phone never infers one

The Sell screen opens its request sheet **only because the server refused with
`approval_required`**. It never decides for itself that a price is below the
floor — the floor is the pricing ladder's answer, and only the server resolves
the ladder.

Completing the sale is a second, separate act: the sale is submitted again, and
the server consumes the approval **inside the sale's own transaction**, so the
grant and the sale either both happen or neither does. The Owner's yes and the
sale are two events. Pretending otherwise is how a customer walks out with a
phone that was never sold.

### Twelve visible states, and they stay distinct

Set price · proposed price · discount · reason · warning acknowledged ·
approval required · waiting for the Owner · approved with the minutes left ·
rejected · expired · no longer valid · used.

Collapsing them into "not approved" would send an employee back to ask again in
the one case where the Owner has already said no. "Expired" means nobody
answered; "voided" means the world moved underneath; "rejected" is an answer.

### The client branches on codes, never on sentences

Every refusal carries a machine-readable `code`. The app runs in three
languages, and a regular expression over an English sentence works in exactly
one of them — the developer's. A code the build does not recognise falls through
to the server's own message rather than to a branch chosen by a regex.

### Cost is gated by the gate that already exists

An approval carries `unitCost`, which is in `FINANCIAL_FIELDS`, so
`CostGatingInterceptor` strips it for every caller without `cost.view` — the
same mechanism as the rest of the app, rather than this feature inventing a
second rule to remember. Where the cost does not arrive, the loss is not
estimated from anything: the screen says a stronger approval is needed, which
is true and discloses nothing.

### The six anomaly rules compute nothing new

1. `anomaly.low_stock` · 2. `anomaly.dead_stock` · 3. `anomaly.overdue_debt` ·
4. `anomaly.seller_margin_drop` · 5. `anomaly.cash_shortfall` ·
6. `anomaly.below_cost_cluster`

Every input is a figure the app already shows. Dead stock is the list
`DashboardService` already produces; low stock uses the shop's own threshold;
a seller's margin comes from `employeePerformance`, which gained an
`endingDaysAgo` so both windows come from **one** definition; overdue debt is
the health score's existing definition; the shortfall rule counts discrepancies
the closing already raised; the below-cost rule counts approvals actually
**spent on a sale**, because asking is not selling.

**Margin is compared as a rate, not an amount.** A quieter month is not a
collapse, and an amount-based rule would accuse somebody of something that did
not happen. Collapse means halved — a threshold that can be said in a sentence.

Every rule states a minimum sample and says nothing below it. Without a floor
the rules fire loudest at the smallest shops, which is the opposite of useful.

**Anomalies are never stored.** A stored anomaly is a second copy of a figure
that is stale by the time anybody reads it. What is stored is the only thing
that cannot be recomputed: that a person looked and said "I know" — seven days,
company-wide, audited, and dropped after ninety.

**A rule the caller may not see is never computed**, not computed and filtered.
A figure that is never fetched cannot escape through a log line or a refactor
that forgets which list was the safe one.

### A catalogue can be perfect while the grants are wrong

The deploy gate checked that all 61 permission keys exist and reported "61/61,
catalogue complete" — while the database still granted `discount.override` to
the retired `branch_manager` role, which A2 had taken away in code.
`AccessService` resolves authority from `role_permissions` and nothing else, so
that role could still approve a discount.

`verify-permission-catalogue` now compares each role's actual grants against
`ROLE_PERMISSIONS`. **An extra grant fails the gate; a missing one does not** —
they are not symmetrical. An extra grant is authority nobody decided to give,
which is the shape of every privilege escalation. A missing one is usually a
shop that deliberately narrowed a role, and this command has no business
overruling that.

### Taking a permission away in code is not finished until a migration takes it away in data (2026-09-10)

A2 removed `discount.override` from `branch_manager` in `ROLE_PERMISSIONS`, and
no migration followed — so every seeded installation kept the grant, and a
Branch Manager approved a discount over real HTTP. **A permission removed from
the matrix must ship with a forward migration that removes it from
`role_permissions`**, in `0018`'s shape, resolving the permission by key because
permission ids are generated per installation. `0067` is that migration for
this grant; the owner authorised it.

**Roles are compared by key, never by display name.** The grant gate first
matched on the label, which would have let a shop that renamed "Branch Manager"
keep a drifted grant while the gate reported green.

**No session carries authority.** The access token holds user, company, token
type and session id only; permissions are resolved from `role_permissions` on
every request and live in request-scoped CLS. Removing a grant therefore takes
effect on the next request of every existing session, with nothing to revoke —
proved live with a session issued before `0067` and an API process that was
never restarted.

**The catalogue has one owner, and that is judged by what a migration writes.**
A later migration may *read* `permissions` to resolve a key; it may not insert,
replace, update, delete, alter, drop, truncate or rename it — directly or
through a join alias.

### The Stock tab lists variants; handsets are one tap or one search away

Implemented 2026-09-11 (backend `63ce639`, mobile Stock screen commit recorded in the handoff).

**One row per exact variant**, from `GET /inventory/summary`: brand and model,
storage and colour, what it sells for, how many can be sold today, and whether
that is low. It replaces the earlier by-model view on this screen, which folded
colours together and never listed accessories. The by-model endpoint is left in
place and unused by this screen.

**Every phone is still a unit.** Tapping a phone variant, or searching, shows
the existing paginated unit list, searched on the server by name, barcode,
**either IMEI** and serial — proven over HTTP with a unit carrying both IMEIs.
A search is a question about one handset, so it answers with handsets.

**Category is not status.** All / Phones / Accessories narrows the variant list
(complete, so filtering it on the phone hides nothing). In stock / Sold / Faulty
are unit lifecycle statuses and keep their server meaning on the unit list. The
two never share a row of chips. Phones are IMEI-tracked products, accessories are
quantity-tracked; serial-tracked devices appear under All.

**The price never overstates what is known.** Each unit is resolved through the
sale's own price ladder. One price for every unit shows "Price …"; units that
resolve differently (a unit override) show "From …"; nothing priced shows "No
price set", never zero; unpriced units are counted rather than hidden.

**No product photos, deliberately.** The app has no product image
infrastructure; the only image field is one handset's `units.image_ref`, and
showing it as every phone of that variant would present a different device as
exact. Rows use a neutral category tile. Adding real product images is a separate
decision.

**"Low" has one definition.** The dashboard, the health score and this screen
share `low-stock.ts`: the shop's `low_stock_threshold` (default 3), inclusive,
compared on in-stock units for serialized goods and on physical quantity for bulk
stock, as the dashboard always has. "Available" on the row excludes reserved
quantity; the low-stock comparison does not. Recorded because the two numbers can
differ by exactly the reserved amount.

**No cost or margin on the summary**, in any shape. Unit rows still show cost
only when the server sends it.

**Receive stock opens the existing receiving workflow**, gated on
`purchase.manage` exactly as Home is. Its draft is already scoped to company,
branch and user, so the button resumes the right delivery. No staged/batch
receiving model was added; the existing workflow already stages scans by product
and commits once.

**English now says "Stock"** for the tab and title, matching French and the
screen's purpose. Arabic keeps «المخزون».

#### Correction pass (2026-09-11, later the same day)

- **Serial-tracked devices have their own chip**, "Other devices", shown when
  the branch holds any. They stay under All. The line above that said they
  appear "under All" only is superseded.
- **Filter numbers count products, not pieces**, and the screen says so in one
  line above the rows.
- **Available, reserved and low are shown together.** The summary now also
  sends `onHand` and `reserved`. A row with reserved stock says "Reserved: 1 ·
  On hand: 3" beside its Low stock chip, so the warning (judged on physical
  quantity, the dashboard's shared rule — unchanged) and the available count no
  longer appear to disagree.
- **French agrees "disponible/disponibles" with the count.**
- **Arabic mirrors on web too.** React Native Web 0.21 ignores
  `I18nManager.forceRTL`; the app now sets the document's `dir` and `lang`, and
  every "is this RTL?" question goes through `layoutIsRTL()`. Native keeps
  `forceRTL` and its restart. Editable fields carry a writing direction so an
  Arabic placeholder containing "IMEI" keeps its word order; identifiers stay LTR.
- **The tab bar no longer clips its labels.** A fixed 60-point height with
  `paddingBottom: 8` replaced the navigator's safe-area handling and squeezed an
  overflow-hidden label to 9 of its 15 points. Height is now 64 plus the bottom
  inset, and the label has a fixed line height that cannot shrink.
- **Receive never calls a refused delivery received.** `POST /purchases` answers
  200 with refused lines listed. The done screen used to count what was staged,
  so a delivery whose every IMEI was already registered showed as received. Now:
  nothing written → the delivery stays on screen with "Nothing was received" and
  each refused identifier with its reason; partly refused → the count excludes
  refused units and they are listed.
- **Catalogue images remain a separate, unapproved feature** —
  [`docs/47`](47_CATALOGUE_IMAGES_SCOPE.md). Rows keep the neutral tile.
- **Receiving does not store a second IMEI.** The purchase contract has no field
  for it (a request carrying `imeiSecondary` is refused 400). Only quick add
  records one. Left as found; closing it means a purchase contract change and is
  a decision, not a correction.

---

## Receiving correction — IMEI 2, existing phones, and what Finish means

Implemented 2026-09-11 (backend and mobile commits recorded in the handoff).
Builds on the approved decisions *one IMEI is enough*, *two IMEIs are ONE
phone* and *IMEI and Product barcode are different things*. **No migration:**
`units.imei_secondary` already existed with a unique index, and `0042`'s
cross-column triggers already refuse a number that is anybody's IMEI 1, IMEI 2
or serial.

### ✅ IMPLEMENTED — IMEI 2 survives the whole of Receiving

The purchase contract gains one optional form, `items[].units[] = { identifier,
imeiSecondary? }`, beside the existing `identifiers[]`. IMEI 2 is Luhn-checked,
may not equal IMEI 1, may not appear on a product without IMEIs, and is checked
in the delivery (as anybody's IMEI 1 or IMEI 2) and against stock (both
columns) — a failure refuses that one phone, with the pair kept together in the
refusal. The idempotency fingerprint covers IMEI 2 only when one is sent, so a
retry of a delivery received before this change still matches.

On the phone IMEI 2 comes from the camera when both were captured, from an
optional field on the cost sheet, or from **Add IMEI 2** on a staged phone. It
is kept in the draft, carried through Create product and its cancellation, and
sent at Finish. It is never written to a Product barcode.

### ✅ IMPLEMENTED — an existing phone is stopped before cost

Every IMEI or serial scan is looked up — with IMEI 2 when there is one — before
the phone may join the delivery. A phone already in stock opens a blocking card
naming it, with **Open this phone** when it is in reach; a number already in
this delivery is refused on the spot. Finish still checks everything again, for
changes made by somebody else in the meantime.

### ✅ IMPLEMENTED — the unknown-product flow finishes

**Choose product** (search, filtered to the scan's tracking type) corrects a
suggestion or resolves an unknown one; confirming it teaches recognition
through the existing recognition key. **Create new product** holds both IMEIs,
and returns to the same Receive screen with the created product selected;
cancelling returns to the same phone. Creating a product creates no inventory —
proved over HTTP.

### ✅ IMPLEMENTED — scanner guidance is translated

`POST /scan` adds a stable `hintCode` (and `hintParams` for a contested
mapping). The English `hint` remains for older clients and is no longer shown
anywhere. The unknown-IMEI copy says the IMEI is kept for this phone only, and
the "we will remember" note for an IMEI says the MODEL is remembered, not the
number.

### ✅ IMPLEMENTED — Finish counts only what the server names

`POST /purchases` returns `accepted: { identifiers, stockProductIds }`, also on
a replay (rebuilt from the stored purchase). The phone reads it through
`lib/receive-outcome.ts`:

| Answer | Screen |
|---|---|
| everything accepted | done, with server-confirmed counts |
| nothing written | delivery unchanged, each refusal listed with its reason |
| partly accepted | received lines leave the phone, refused lines stay with "correct or remove, then finish again", **new request key** |
| no answer (timeout, dropped connection, 5xx) | everything locked under the **same key**; **Check again** replays |
| key reused with a different delivery (409) | explained, nothing resent |

Proved on an isolated real-MySQL copy: a lost response and five concurrent
identical retries produce one purchase, one set of units and one stock movement.

---

## The Stock screen is the visual reference; checkpoint 1 — Unit detail and History

Approved 2026-09-11 by the owner: the current Stock screen is the visual
reference for the rest of the mobile app — indigo for primary actions and
selected states, white cards on the cool light background, strong dark titles
and values, muted grey supporting text, green for confirmed/positive, amber for
warnings, red only for destructive actions and failures, the system typography
(with the Arabic system font), and consistent rounded cards, fields, sheets,
spacing and fixed-action placement. Choices live in the existing tokens and
shared primitives; screens do not carry raw colours. The Home dashboard
"Improvement" and catalogue images stay deferred.

### ✅ IMPLEMENTED — no internal route name as a back label

iOS labelled the back button with the previous screen's title, and a tab
screen's parent is the `(tabs)` route group, so every detail screen opened from
a tab read "‹ (tabs)". The root stack now uses an icon-only back button
(`headerBackButtonDisplayMode: 'minimal'`); VoiceOver still announces "Back".

### ✅ IMPLEMENTED — history in business language

The server sends stable facts per audit entry: `fromStatus`, `toStatus` (null
when not recorded — nothing inferred), a `context` code for the English system
reasons services wrote (`return_intake`, `return_approved`, `return_rejected`,
`transfer_cancelled`, `transfer_rejected`), the actor's name and role at that
branch, and branch/destination/origin names. **The server translates nothing.**
Legacy fields remain.

The app (`lib/unit-history.ts`) maps them to words: *Received into stock*,
*Sold*, *Reserved for a transfer to …*, *Sent to …*, *Received at …*, *Transfer
cancelled — back in stock*, *Returned by the customer*, *Return approved — held
as faulty*, *Marked as faulty*, *Returned to stock*, *Status changed from … to
…*, and **Inventory updated** for anything it cannot describe. Raw codes are
never the label. Tone follows meaning: a sale is informational, a cancellation
neutral, red only for faulty.

### ✅ IMPLEMENTED — a timeline that can be read

Newest first, grouped by day (*Today*, *Yesterday*, then the date in the
selected language), one card per day, each row an icon, the meaning, who (name ·
role, or *Automatic*), where, and the time. Consecutive identical entries fold
into one row with a count that opens to each time. Beyond eight rows, *Show N
more events*. **Every audit entry stays reachable; none is merged away, hidden
permanently or deleted.**

### Investigated — the repeated rows were not duplicate writes

On the reported phone every repeated sent/received/cancelled pair came from
verification runs whose transfers were later cleaned up (0 transfers remain for
it), and on another phone 13 return intake/approval pairs came from probe users
whose return requests were cleaned up. The audit log keeps them, as it must.

Two real defects found and fixed at the source: **reserving a unit for a
transfer was never audited**, so the history jumped from *In stock* to *sent*;
and the timeline returned the **oldest** 200 entries, cutting off recent
history. Sent/received entries now name destination, origin and transfer.

### ✅ IMPLEMENTED — the item summary

Product and variant, current status, identifiers (**IMEI 1, IMEI 2 and serial
number each by their own name**), location, purchase (received date, supplier,
reference, and cost only when the server sent it), then history. French dates
now use French month names; they previously fell back to English.

### ✅ IMPLEMENTED — checkpoint 2: one type scale, no local sizes or weights

Every screen and component now takes size and weight from `tokens.ts` through
the `Text` primitive. The scale gained `labelStrong`, `captionStrong` and
`tabLabel` so chips, filter pills, stat tiles, the toast action, the tab bar and
the Store ID stop overriding them locally. Sign-in, registration and
verification no longer use utility classes. `lib/design/visual-system.test.ts`
keeps it that way: a raw size, weight, family or colour in a screen or
component, a screen utility class, or a direct React Native `Text` fails the
suite.

### ✅ IMPLEMENTED — checkpoint 3a: Sell in the Stock visual system

A cart line reads like a Stock row: what it is on the left (name, variant,
tracking chip, identifier), what it comes to on the right, and underneath the two
things a seller changes — quantity and a **labelled** unit price. Selling below
cost is flagged in words on the line; cost itself is never shown. Payment method,
split entries and return policy are wrapping filter chips (a segmented control
truncated *Paiement mobile* and *Virement bancaire*). The header names the branch.
Every amount placed inside a sentence — charge button, profit, below-cost and
warning dialogs — is direction-isolated, so Arabic reads *الربح 500 MRU*, not
*MRU 500*. No behaviour change: the minimum-price approval, magnitude warning and
below-cost confirmation are the existing server and client rules.

**Gap reported, not built:** the sale API accepts `customerId` and
`receivingAccountId`, but Sell has no customer or receiving-account selection.
Adding it is a feature, not a visual pass, and awaits the owner.

### ✅ IMPLEMENTED — checkpoint 3b: Receive aligned; serial kept through Create product

The documented lost-state gap is closed. A scanned **serial number** (a TV, a
laptop) is now held across the Create-product detour exactly as an IMEI was: the
pending intake carries it in its own `serial` field — never in `productBarcode`,
never alongside an IMEI — and Receive looks it up again on return. Cancelling
Create product reopens the same serial; creating the product returns with it
selected. Creating a product still creates no unit.

Back on Receive is an arrow only (mirrored in Arabic) and still asks before a
delivery is left behind; it was the last text "Back" in the app. A staged line
labels its per-unit cost (*9 MRU l’unité*) so it is not read as the line total.
IMEI 1 / optional IMEI 2, existing-phone refusal, unknown-product actions, draft
notice and outcomes are unchanged.

**Observed, not changed:** Create product opened from a serial scan still
proposes *un par un, chacun avec son propre IMEI* until a category is chosen;
choosing the TV category sets serial tracking. Pre-selecting it from the scan is
a form behaviour change and awaits the owner.

### ✅ IMPLEMENTED — checkpoint 3c: transfers and consignments say who has it, who acts next, and the money

`lib/custody-state.ts` (19 pure tests) derives, **from the server's status only**,
three separate answers: where the items are, whose move it is, and — for a
consignment only — the money state. Stock movement and settlement are never one
label: *the phone arrived* is not *we were paid*; only `settled` reads as paid, a
write-off never does.

- **Transfer detail:** *Les articles — Toujours à Main Store / En route vers
  Warehouse / À Warehouse* and *Prochaine étape — Expédition depuis … /
  Réception à … / Rien — terminé*. Transfers carry no money and say nothing
  about it.
- **Consignment detail and list:** the status is translated (15 keys) instead of
  the backend's English `statusText`; the amount is labelled *Montant demandé*,
  *Contre-proposition* or *Montant convenu* (an offer is not an agreement);
  *Les téléphones / Prochaine étape / L’argent* rows; the declared-but-unconfirmed
  amount is formatted and isolated; errors use the translated friendly message.
- **Accept / counter** are offered only to the side whose answer is awaited. The
  server derives `lastProposalBy` from status alone (request = sender's offer,
  counter-offer = holder's); the app mirrors it, so the buttons that could only
  be refused are gone. Dispute and cancel are unchanged.
- Consignment filters are chips, as on Stock and Transfers.

**Reported, not changed:** (1) opening `/transfers/<id>` directly on web sends the
first request before the saved branch is restored; the API answers 403 without
`X-Branch-Id` and the screen, which never retries, says *Ce transfert n’existe
plus*. A cold-start notification deep link may do the same — handset check
TC7. (2) A transfer cancelled after approval, never shipped, lists *Envoyé par
quelqu’un* in its history. (3) Consignment stages after *requested* could not be
rendered: with a manual counterparty nobody on the system can accept.

### ✅ IMPLEMENTED — checkpoint 3d: Money labelled by period, statuses in words

No accounting semantic changed and nothing is recomputed on the phone.

- **Cash and accounts:** period chips (*Aujourd’hui / 7 jours / 30 jours*); the
  profit and cash blocks carry the period as a subtitle, balances already say
  *Tel qu’à cet instant*. Expense breakdown and discrepancy total are formatted
  money; trend percentages are grouped whole numbers (*141 531 %*, previously
  *141530.72 %*), isolated in Arabic.
- **Loans:** status translated (9 keys) instead of the backend's English
  `statusText`; principal, reported-but-unconfirmed and confirm-payment amounts
  formatted; friendly translated errors; filter chips; the group chip that
  repeated the filter removed.
- **Expenses:** filter chips. **Daily closing:** friendly errors, formatted
  outstanding total, localised closed-day date, token spacing.
- **French copy:** the 21 values still using a straight apostrophe now use ’.

Pending and confirmed stay distinct as before: reported expenses amber,
confirmed green; a reported loan payment is shown and never deducted.

### ✅ IMPLEMENTED — checkpoint 3e: More as grouped sections, one tap to a screen

More now lists destinations directly under **Boutique · Équipe · Produits et
réglages · Rapports · Sécurité · Langue et apparence · Compte**, followed by the
separate *Se déconnecter*. Previously it showed hub rows, each costing a second
tap before anything useful.

- `MORE_GROUPS` in `lib/navigation/registry.ts` names **existing destinations by
  id only** — it cannot add a route, and no feature was invented (there is no
  Support screen, so there is no Support row). The hubs still own membership,
  permissions and `/hub/<id>` deep links, which keep working.
- Money stays a bottom tab; none of its four children appears on More.
- Five drift tests: every non-tab destination grouped exactly once; no Money
  child duplicated; fixed order; only permitted rows, never an empty group
  (Owner, Manager, Employee, nobody); group names in EN/FR/AR.
- Bell, branch control, sync and subscription notices are unchanged.

**Observed, not changed:** on the Arabic web render the branch card's chevron is
not visible (it uses `mirror()`); the row chevrons are. Handset check MR4.

### ✅ IMPLEMENTED — reported gaps: two defects fixed, one measured and left alone

Follow-up to checkpoint 3, after the owner asked for the reported gaps that are
defects rather than features. Backend `2b48143`, mobile `192f4ba`.

**A deep link now waits for the branch (gap 2).** The server resolves permissions
from `X-Branch-Id`, and the saved branch is restored asynchronously at start-up —
so a link opened cold asked before it existed, got a 403, and the screen showed
*Ce transfert n’existe plus*. Transfer, consignment and loan detail now ask only
once the branch is known. Proved on the web build by watching the request: it
carries the branch, and an unknown id answers **404, not 403**.

**A cancelled transfer no longer claims it was shipped (gap 3).**
`stock_transfers.sent_at` carries `DEFAULT now()`, so every row has a value
whether or not anything left the shop. Blanking it by status alone missed the
transfer cancelled *after approval*, which then listed *Envoyé par quelqu’un* —
nobody named — for goods that never moved. `shippedAt()` answers from `sentById`,
which only shipping writes, keeping the status check for older rows. One new spec.

**The Arabic chevron is drawn (gap 5).** More's branch chevron was mirrored by
putting a transform on the icon. On an SVG element that does not turn the glyph
round: it moves the drawing out of its own box, where the SVG's `overflow` clips
it — so the chevron simply disappeared in Arabic. It is now mirrored on a
wrapping `View`, like every list row, and points left. `mirror()` documents the
rule, and the registry test pins the wrapper and refuses the old pattern.

**The charge button's thousands space (gap 6) — measured, not changed.** The
character is there and is not dropped: the button's text contains U+202F exactly
as the cart total does, and measured at every weight it adds the same ~2.2 px.
It is simply a ~2 px gap at button text size, beside a total that renders it at
display size — so *1 015 MRU* reads clearly while the button reads *1015 MRU*.
Making it obvious means widening the group separator everywhere (a normal
no-break space is twice as wide), which changes every screen already approved.
**That is a formatting decision, not a defect, and it is left to the owner.**

Gaps 1 (no customer or receiving account on Sell), 4 (Create product proposes IMEI
after a serial scan) and 7 (stages that could not be rendered) remain with the owner.

### ✅ IMPLEMENTED — 4a: a customer to attribute a sale to, and the account the money reached

**Customer.** `sales.customer_id` has existed since the beginning, a credit or
partial sale REQUIRES one, and the sale list already searched by customer name
and phone — but no endpoint could find or create a customer, so the field could
only ever be filled by something outside this application. There is now a
`customers` module: search by name, phone or id, and create.

- Finding is gated on `sale.create`, not on customer administration: a cashier
  who may take a credit sale must be able to name the person, and gating the
  lookup would gate the sale.
- Creating is the new **`customer.manage`** (migration `0068`), held by Owner,
  Store Manager and Administrator. An Employee may attribute a sale to an
  existing customer and may not invent one.
- Selection is **optional** on Sell, deliberately: an ordinary cash sale needs
  nobody, and stopping to identify a walk-in would slow the commonest
  transaction in the shop. Choosing or creating never touches the cart, the
  discount or the scanned lines.
- Isolation is structural — every query goes through the tenant client, so one
  company cannot search, read or create into another's customers.

**Receiving account.** Cash remains its own method and carries no account: the
drawer belongs to none, and `ck_payments_cash_no_account` refuses the
alternative. Every other method must now name an **active** account:

- a non-cash payment with no account is refused (it used to be recorded as
  "unattributed", which nothing could reconcile);
- a deactivated account is refused for a new sale, while past payments keep
  pointing at it — which is why it is deactivated and never deleted;
- another company's account is simply not found;
- provider **and** label are shown before Complete, in a split as well as a
  single payment, and Complete stays disabled until every non-cash line names
  one;
- **`payments.account_provider_snapshot`** (migration `0069`) freezes the
  provider beside the label. The label alone was not enough: renaming "Bankily –
  Main Counter" to "Counter 1", or switching an account's provider, would
  otherwise rewrite what a receipt already said. Historical rows stay NULL
  rather than being backfilled with a guess.
- The account feeds the existing payment/reconciliation model — no second
  accounting path was created — and split payments were preserved exactly as
  they were.

### ✅ IMPLEMENTED — 4b: Create product suggests what the scan actually classified

Scanning a television's serial opened Create product proposing **IMEI**: the
classification was already known and simply ignored, so the form asked for a
number the device does not have.

- `lib/scan/suggested-tracking.ts`: an IMEI suggests IMEI; a serial suggests
  serial — never IMEI because a serial happens to be numeric; a genuine
  EAN/UPC suggests **nothing at all**, because it names a model rather than a
  unit, and prefills only the Product barcode.
- The suggestion is never final: the form shows a chooser and the user confirms
  or changes it.
- A category still **decides** the mode wherever one is chosen, and the server
  refuses a contradiction, so the form states no opinion there and
  `trackingType` travels only for an uncategorised product.
- Each identifier has exactly one field it may land in, so IMEI, IMEI 2, serial
  and product barcode cannot cross-populate; the pending intake keeps them in
  separate fields, scoped by user, company and branch, and no unit is created
  until receiving succeeds.

**Serial is selectable again** (reversing the earlier "not offered" decision, on
the owner's instruction). It was withdrawn to stop a box of cables being
registered one at a time; that guard cost more than it saved, because the shop
sells televisions, laptops and power stations that carry a serial and no IMEI.
The protection that actually matters is unchanged: a category decides the mode,
and a mode change is still blocked once stock or history exists.

### ✅ IMPLEMENTED — 4c: one money formatter, with a separator people can see

The thousands separator was a NARROW no-break space (U+202F), about 2 px at body
size. On the charge button — the most-read number in the app — *1 015 MRU*
reached the eye as *1015 MRU*, while the same string in the big total showed its
gap clearly. The character was never missing; it was too small to read at the
size that matters.

- Grouping now uses a normal non-breaking space: `1 030 MRU`, `38 000 MRU`,
  `1 500 000 MRU` — about twice as wide, still unbreakable.
- One shared formatter, `lib/money-format.ts`, which imports **nothing** and is
  re-exported by `lib/format.ts`, so every screen, button, card, receipt and
  export uses one implementation and no string was patched individually.
- Negatives, decimals, signed deltas and "absent is not zero" all preserved;
  Arabic keeps Latin digits and one unbroken run so the amount isolates
  correctly; identifiers, years and storage sizes are never grouped, and a test
  scans the call sites to keep it that way.
- Reports CSV is deliberately untouched: those cells must stay machine-readable.

### ✅ IMPLEMENTED — 4d: every consignment and loan state, rendered from real workflows

The later stages had never been seen because demo data never reached them. They
were built on an **isolated copy** of a verified backup, through the real API,
by two real signed-in stores — never by writing lifecycle rows by hand.

All **14 consignment states** (requested, counter-proposed, disputed, agreed
awaiting custody, on the way, in custody, sold awaiting settlement, part paid,
settled, return started, return in transit, returned, written off, cancelled)
and all **9 loan states** (proposed, counter-proposed, disputed, agreed, payment
reported, part paid, settled, written off, cancelled) were reached and rendered.

Each screen states, in words: who holds the item, what happened, who acts next,
the amount agreed / paid / outstanding, and whether physical custody and money
are pending or confirmed — with **custody and settlement kept as separate
answers**. The two ends genuinely read differently: the sender sees *Vous avez
envoyé ceci · Chez Test Store · En attente de Test Store*, the holder sees *Vous
détenez ceci · Chez vous · À vous*.

Rendered in French and Arabic, light and dark, at phone width, from both sides.
The isolated database was dropped afterwards and live data proved untouched.

### ✅ IMPLEMENTED — Home ("Improvement"): a greeting, two shortcuts, four figures

The landing screen stopped being a report and became a place to start work.

- **The welcome says only what is known.** A compact branch line, then the
  signed-in person's name, then whether the screen is ready. The decorative
  phone and the marketing slogan are gone — they were space spent on nothing
  anybody can act on. There is deliberately **no** "you sold N today, keep
  going": an encouraging figure nobody asked for is a performance claim, and
  this screen has no business inventing one.
- **Sell and Receive replace Sell and Scanner.** Both open the camera as soon as
  the branch and the permission set have resolved — and not before, so a
  viewfinder never appears in front of somebody about to be told they may not
  sell here. Typing stays permanently available underneath, because whether a
  handset carries a scannable code is the manufacturer's decision.
- **The shortcuts never touch the full workflows' drafts.** A quick sale holds
  its own single line and keeps no draft; the Sell tab's cart is left exactly as
  it was. A shortcut that quietly emptied half a built sale would be worse than
  no shortcut at all.

### ✅ IMPLEMENTED — the four monthly figures, and where each one comes from

Audited before anything was wired. Every figure is the server's; Home chooses
the window and says what the number means, and computes no money of its own.

| Card | Server field | What it actually is |
|---|---|---|
| **This month's profit so far** | `summary.profit.netOperatingProfit` | net revenue − net COGS − **confirmed** expenses |
| Sales this month | `summary.profit.netRevenue` | gross sales − revenue reversed by returns approved in the period |
| Expenses this month | `summary.expenseDetail.total` | confirmed expenses only; a variable one on its confirmation date, a fixed one on its due date |
| Money collected this month | `summary.collected.total` | **new** — see below |

- **Profit is never sales minus stock purchases.** Buying inventory is a
  balance-sheet movement (`accounting-rules.ts` says so as data); a good month
  of restocking would otherwise read as a catastrophe. Cost reaches profit
  through COGS when the goods sell.
- **A return is counted once.** Profit reverses on the **approval** date and the
  cash leaves on the **confirmation** date, and the refund carries no profit
  component — subtracting it twice is the single easiest mistake in this area
  and the rollup is written to prevent it.
- **The comparison is like-for-like.** The server compares the preceding window
  of EQUAL LENGTH, so twelve days into a month are measured against the twelve
  days before them. The screen says how many days rather than "vs last month",
  which would describe a comparison nobody made. A zero base reports
  *no comparison* instead of a percentage divided by nothing.
- **Money collected is new, because nothing answered it.** `cash.salesReceived`
  was net revenue used as a stand-in — what was *billed*, not what *arrived* —
  so a credit sale inflated it. It now counts `payments` rows, split cash vs
  account by `method` (not by account id, or every pre-`0045` unattributed
  payment would vanish). Refunds are **not** netted off: they are money going
  the other way and keep their own line. It is never profit and never an
  available balance.
- **Absent is not zero.** A figure the server cannot produce — including an
  older server that does not send `collected` at all — is named as unavailable.
  A shop cannot tell a measured zero from one nobody computed.

### ✅ IMPLEMENTED — Quick Sell, and what the customer never sees

Home → Sell → scanner → the exact phone → price and a private summary →
payment → confirmed.

- Either IMEI finds the same handset; the server already looks up primary,
  secondary and serial alike.
- Availability, custody and branch are the server's facts and are only reported:
  a reserved unit is on somebody's transfer and a sold one is gone.
- The configured selling price is prefilled. Changing it is allowed exactly as
  on the Sell tab — the server refuses anything below the floor without an
  owner's approval, and that approval flow is reused rather than reimplemented.
- **The private summary is private by construction.** `ReceiptData` has no cost
  and no margin field, so the printed and shared receipt has nowhere to put
  them; `receipt-privacy.test.ts` asserts it against the type, against every
  interpolation the receipt renders, and against the screen that builds it.
- Cost is shown only where the role may see it **and** the field is present —
  without `cost.view` the server strips it, and a dash there reads as "free".
- **A loss is shown as a loss.** Flooring the expected result at zero would hide
  exactly the sale somebody needs to think again about.
- One idempotency key per **sale**, not per attempt, so a timeout retry cannot
  charge a customer twice. A new key is taken only when a new sale is started.

### ⤴ SUPERSEDED — "supplier optional" was blocked; resolved below (optional-seller receiving)

Quick Receive was specified with supplier under *More details*, optional, with
"no blocking validation when omitted". The contract cannot express it:
`CreatePurchaseDto.supplierId` is `@IsUUID()` with no `@IsOptional()`,
`Purchase.supplierId` is **NOT NULL** with a required FK, and the service
resolves it, raises `NotFound` without it, and drives the payable balance and
the settlement row off it.

Delivering the requirement means making a **financial column nullable** and
deciding what a purchase owing nobody means for payables. The rulebook classes a
schema change as *major* and requires approval first; inventing a placeholder
supplier is explicitly forbidden; and leaving the validation in place would ship
the opposite of what was asked. **The screen is therefore not built**, pending a
choice between making `purchases.supplier_id` nullable (with a backup and
migration per `docs/22`) or amending the requirement.

### 📋 RECORDED — two contract gaps found while auditing, neither invented around

- **Period boundaries are UTC.** There is no business-timezone setting anywhere:
  the server keys every rollup on a UTC day and the summary window slices a UTC
  string. Home matches the server rather than being independently "more
  correct", so the phone and the server never disagree about which day it is —
  but a shop trading late in a UTC+2 evening has those takings land on
  tomorrow's figures. Stated in `home-metrics.ts` and asserted by its test.
- **Stock age is honest and does not reset.** `units.date_in` is set once, from
  the schema default, when the purchase is received. Receiving a transfer
  rewrites `status` and `branch_id` and **does not touch it**, so a phone moved
  between shops does not look newly delivered; it is NOT NULL, so there is no
  missing case tempting anybody to invent a date. Where the client has no date
  it says so rather than showing "arrived today".

### ✅ IMPLEMENTED — optional-seller receiving (migration `0070`)

The everyday purchase is a handset bought from whoever walked in with it and
paid on the spot. The owner authorised the minimal schema change; these are the
rules:

- **A purchase fully paid may name no supplier.** `purchases.supplier_id` and
  `supplier_payments.supplier_id` are nullable. Nothing dropped, nothing
  backfilled, both foreign keys kept.
- **Omitting the supplier never implies payment.** `paidAmount` must be sent and
  must equal the total; a missing amount is refused, not defaulted.
- **A balance needs a payee.** No supplier + anything outstanding is refused with
  `supplier_required_for_balance`: *"Name who this was bought from, or record the
  full amount as paid. An unpaid balance has to be owed to somebody."*
- **No "Unknown supplier".** No placeholder counterparty is ever created.
- **Records are kept without a supplier.** Purchase, purchase items, units (cost,
  `date_in`, purchase link), the payment row and the audit entry are all written.
- **Named suppliers are unchanged.** Payables, supplier detail, settlements and
  the reports' supplier balances all key on a concrete supplier id, so a
  no-seller purchase is simply not a payable. `outstandingBySupplier` skips NULL
  rows explicitly.

**Quick Receive** (Home → Receive): scanner or typed identifier → recognised or
chosen/created product → cost (prefilled from the product, to confirm) → **Add to
stock** → server-confirmed result. The seller sits under *More details*; with none
named the screen states the purchase is recorded as paid in full and why. IMEI 2
optional; a registered identifier refused before any cost is typed; identifiers
and cost survive the Create-product detour; one request key per purchase across
retries; its own draft key, leaving the full Receive delivery untouched.

### 📋 FOUND AND PROVEN — why live Home figures were wrong

**Cause: stale derived rows left by deleted verification fixtures, plus no
invalidation path.** The append-only audit trail records `Sale create` ×28 on
2026-09-10 and ×4 on 2026-08-08; the `sales` table has no rows on either day.
Those fixture sales (the `ZZ-CP6` cleanup and an earlier one) were hard-deleted
outside the application, and their `daily_rollups` rows were never recomputed.
`RollupListener` subscribes only to `sale.recorded` and `stock.moved`; nothing
re-enqueues a recompute when source rows disappear. Not cross-tenant
contamination: every affected row belongs to one company and branch, and
`sale_items.company_id` always equals its sale's.

**Exact affected scope on live** (read-only audit, nothing written):

| Company / branch | Day | Rollup revenue | Ledger revenue | Rollup net | Sales rollup/ledger |
|---|---|---|---|---|---|
| Demo Phone Store / Main Store | 2026-08-03 | 1 000.00 | 1 000.00 | 200.00 | 1/1 — correct, untouched |
| Demo Phone Store / Main Store | **2026-08-08** | 40.00 | **0.00** | 31.80 | 1/0 |
| Demo Phone Store / Main Store | **2026-09-10** | 388 300.00 | **0.00** | 328 300.00 | 6/0 |

Rollups total 389 340.00 against a ledger of 1 000.00 — **overstated by
388 340.00**. Home's *"This month's profit so far — 328 300 MRU"* on live comes
entirely from the 2026-09-10 row.

**Repair, proved on an isolated restore:** `RollupService.recomputeDaily` — the
production code path, not a hand-written UPDATE — for the two drifted
branch-days. After: every rollup row matched the ledger; the correct 2026-08-03
row was unchanged. No sale, payment or audit row is touched: rollups are a cache.

**Live repair is NOT applied — awaiting review.** Procedure:

1. Take and verify a backup per `docs/22`.
2. `DB=phonestore node rollup-audit.js` — confirm the scope is still exactly
   these two rows.
3. `DB=phonestore node rollup-audit.js --repair` — recomputes only drifted rows
   and re-audits; expected result "every rollup row now matches the source
   ledger", live September figures falling to what the ledger supports.

Until it runs, **live Home still shows the stale 328 300**. The collections card
already reads the payments ledger and shows 0 beside it, which is the visible
signal. Going forward, any out-of-application data removal must be followed by
the same audit.

### 📋 DOCUMENTED — the four Home figures, exactly

Month-to-date, the selected branch, **UTC day boundaries** — the existing
business convention everywhere in this product (rollups key on a UTC day); no
timezone feature added.

| Card | Source | Counts | Excludes |
|---|---|---|---|
| This month's profit so far | `summary.profit.netOperatingProfit` | net revenue − (COGS − COGS credited by approved returns) − **confirmed** expenses | pending/rejected expenses; stock purchases (never an expense) |
| Sales this month | `summary.profit.netRevenue` | `price × qty − discount` of non-voided lines by `sold_at`, less revenue reversed by returns **approved** in the period | refund payouts (cash, not revenue) |
| Expenses this month | `summary.expenseDetail.total` | **confirmed** only — variable on confirmation date, fixed on due date | submitted/under-review and rejected expenses |
| Money collected this month | `summary.collected.total` | **gross** customer payments (`payments`) for sales in the window, cash and account together | refunds — **not netted**; they stay in `cash.refundsPaid`, on the confirmation date |

Profit reverses on the return's **approval** date; cash leaves on the refund's
**confirmation** date; neither is counted twice. Verified over real HTTP on an
isolated copy: a 10 000 sale of a phone costing 1 500 moved profit +8 500, sales
+10 000 and collections +10 000 exactly.

---

## Partners milestone

### ✅ IMPLEMENTED — Partners replaces Sell on the bar

**Supersedes** *"the four bottom tabs do not change"* and *"Money is a bottom tab,
beside Sell"*.

The bar is **Home · Partners · Money · Stock · More** — *Partners / Partenaires /
الشركاء*, icon Handshake.

- **Selling did not move.** The scan-first Sell and Receive shortcuts stay on
  Home. The full multi-item sale is reached from Home (*Sale with several items*)
  and from Quick Sell.
- **The Sell route was not removed.** It is still declared, only taken off the
  bar (`href: null`), so `/sell` links, notifications, back navigation and the
  saved cart under the same `sell.cart` draft all keep working.
- **The badge** counts only incoming connection requests *this* user may answer
  (`connection.manage`). A badge asking somebody to do what they may not is one
  they learn to ignore.
- **Old links resolve.** `/stores` redirects to Partners, and More's row lands
  there.

### ✅ IMPLEMENTED — new inter-store business needs an accepted connection

**Binding rule, supersedes the earlier allowance** to start manually recorded
inter-store dealings without a connection. A store may start a NEW dealing with
another store only while that store has **accepted** a connection.

- **What needs it.** Proposing, accepting or counter-offering a loan; proposing,
  accepting or counter-offering a consignment; handing consigned phones over.
- **Checked at commit.** The check re-reads the connection with a row lock inside
  the transaction that writes the dealing. An old screen or a saved draft
  authorises nothing, and a removal racing a proposal is serialised.
- **Pending, declined, withdrawn, removed and blocked** authorise nothing new.
- **Acceptance authorises dealing, not deals.** Every loan and consignment still
  needs its own agreement, custody confirmation and payment confirmation from the
  other store.
- **A connection shares nothing private.** No partner inventory, purchase costs,
  margins, customers or dealings with anybody else. The connected-store summary
  reads only dealings between exactly the two companies.
- **Legacy manual route closed.** A store can no longer be recorded by hand
  (`connection_required`), and an existing hand-recorded store can start nothing
  new. Its records stay readable and settleable.
- **Out of scope, unchanged:** lending to or recording a *person* or an employee,
  retail sales, purchases from individuals, and same-company branch transfers.

### ✅ IMPLEMENTED — requesting, answering, withdrawing and removing

Migration `0071` adds `cancelled` and `removed` to the connection status.

- **Adding a store is by exact code.** The store behind the code — name, city,
  the not-yet-verified note — and any existing relationship are shown before
  sending. Search stays bounded; nothing here became a directory, and every
  hidden store (not discoverable, inactive, blocked) is still just "no such
  store".
- **Own code** is refused plainly.
- **A retry of my own request** writes nothing.
- **A request crossing theirs** is refused, never auto-accepted, and says to
  answer theirs instead. Two simultaneous requests resolve to one row: proved
  live, one stands and the other is told to accept it.
- **Only the requester may withdraw**, while the request waits; **only the
  addressee may answer**; **either store may remove** an accepted connection.
- **A declined, withdrawn or removed pair may ask again.** The same row is
  reopened as a new request, which must be accepted again.

### ✅ IMPLEMENTED — removing a connection never traps a phone or a debt

Removal stops new business only. Still allowed, for both stores:

- reporting and confirming payments;
- confirming a hand-over that was already sent;
- returning consigned phones and acknowledging them;
- disputing, rejecting or cancelling proposals, and forgiveness;
- reading the shared history.

No balance, custody, audit entry or receipt is altered, and nobody has to
reconnect to return a phone or settle a debt. Proved over real HTTP: after
removal a 2 000 repayment was reported and confirmed, and a consigned phone
returned and acknowledged, with no new connection.

### ✅ IMPLEMENTED — a connected store's screen

- **Relationship:** identity, status in words, and what the status allows.
- **Money:** *They owe us* and *We owe them* as separate rows, never netted.
- **Phones:** *Our phones they hold* and *Their phones we hold*, held or on the
  way. Custody is shown as phones, not money.
- **Waiting on someone:** each open dealing with whose move it is.
- **History:** everything shared, including finished dealings.
- **Actions** (only while connected): *Lend money* and *Give a phone on
  consignment*, opening the existing flows with the store preselected.

### 🟡 CONTRACT GAP — selling a phone outright to another store

**No bilateral inter-store sale exists.** Retail sales know a customer, not a
store, and a consignment's "sold" means sold to *their* customer. The action is
shown as *not yet available — give it on consignment instead*, and is **not
faked** with a customer sale: that would leave the buyer with no purchase, no
receipt of ownership, and one IMEI told two ways.

Smallest proposal (not built):

1. An `inter_store_sale` proposed by the seller for specific units and a price,
   over an accepted connection.
2. The buyer accepts, counters or refuses.
3. The seller hands the phones over; the buyer confirms receipt by scanning, as
   consignment custody already does.
4. At confirmation, ownership moves: the seller records the disposition (revenue
   and COGS, as a consignment disposition does), and the buyer receives stock at
   the agreed price as its cost.
5. Payment is reported by the buyer and confirmed by the seller, with the
   balance owed shown on both stores' Partners screens.

**Decisions needed before building:**

- **(a) The IMEI across companies.** IMEI uniqueness is global, so the buyer
  cannot simply create a second unit with the same IMEI. Either the `Unit` row
  moves between companies (and its history boundary is decided), or the seller's
  unit is closed and a successor unit is linked to it.
- **(b) When revenue is recognised:** at acceptance, at custody confirmation, or
  at payment.
- **(c) Returns and warranty** between two shops after the sale.
- **(d) Whether a partly paid sale** is allowed, and who carries the risk.

### 📋 NOT SUPPORTED — adding a store by QR code

No QR format for store codes exists, so adding is by typed code only. Scanning
one would need an agreed QR payload and the scanner to recognise it; neither was
invented here.

## First-release scope (2026-09-15)

### ✅ IMPLEMENTED — Suppliers leave the launch app

No supplier directory, create/edit, picker, balance, settlement, report row, More
link or supplier name on any screen. Customers, Partner stores, loan counterparties
and payment accounts are unrelated and unchanged. **Nothing historical was
deleted:** `suppliers`, `supplier_settlements` and old supplier references on
purchases and units stay in the database, dormant. The `supplier.*` permission
keys stay in the backend catalogue and grants (no route checks them, the app no
longer knows them) so no grants migration was needed; remove them in a later
cleanup if Suppliers is not coming back.

### ✅ IMPLEMENTED — every ordinary purchase is paid in full (migration `0072`)

- Receiving asks only **how** it was paid: cash, or an **active** receiving
  account. There is no amount paid, no paid/partly/unpaid choice, no due date,
  and no placeholder counterparty.
- The server sets the payment to the purchase total. `supplierId`, `paidAmount`
  and `dueDate` are rejected (400). Cash with an account, non-cash without one,
  an unknown account and an inactive account are each refused before anything is
  written. Purchase, payment and units remain one transaction; the payment
  method and account are part of the idempotency fingerprint.
- `0072` adds nullable `receiving_account_id` and `account_label_snapshot` to
  `supplier_payments` (table name kept for compatibility). Nothing backfilled.
- **Accounting fix found on the way:** purchase payments were invisible to the
  closing's expected cash, the per-channel movements and the period summary.
  They are now counted as money *paid for stock* (component name `supplierOut`
  / `supplierPaymentsConfirmed` kept for client compatibility). A cash purchase
  lowers expected drawer cash; an account purchase lowers that account.
- The legacy `POST /units` quick-add (stock with no purchase and no payment) is
  no longer exposed.
- **Purchase on credit is postponed.** Buying on terms between stores belongs
  to Partners.

### ✅ IMPLEMENTED — inventory import is Owner-only (migration `0073`)

`import.run` revoked from every non-owner role. Import has no supplier column
and never creates a purchase payment: opening stock moves no cash.

### ✅ IMPLEMENTED — no low stock

No "Running low" on Home, no low badge on Stock, no low-stock anomaly, no stock
coverage in the health score, no threshold reads. Out of stock (nothing
available) is still stated, and a sale still refuses an unavailable unit.

### ✅ IMPLEMENTED — Home keeps only what is actionable

Greeting, Sell and Receive shortcuts, pending work, and the four server figures.
The stock section and the duplicate "everything else" navigation list are gone.
The known Home rollup discrepancy is **not** repaired or hidden here.

### ↩ REVERSED (2026-09-15) — "postponed modules are unreachable"

**Not authorised.** Only Suppliers and low stock were approved for removal. The
removal of the Goals and Analytics screens, the hidden WhatsApp summaries
settings section, the hidden "verified badge coming soon" line and the removed
disabled "Sell to this store" row were all restored in mobile `fe30eb7`. Goals,
Analytics, anomalies and WhatsApp summary settings are current, reachable
features. No CRM, SAV/technician or OCR surface existed before, and none was
added.

### 🔭 Future updates (not scheduled)

- Suppliers and purchase credit, if a shop needs payables again — reuse the
  dormant tables; decide whether `supplier.*` keys return or are deleted.
- Low-stock alerts with per-product thresholds.
- Inter-store outright sale (four decisions above) and store QR codes.

## Scope rule and six-screen layout (2026-09-15)

### ✅ DECIDED — exactly two features are absent from the first release

**Suppliers** (and supplier balances, supplier credit, supplier selection) and
**low stock / reordering**. Nothing else is removed. A design mockup that omits a
feature does not authorise deleting it; any further removal needs the user's
explicit approval first. Old supplier rows stay as inert legacy data; no
supplier schema migration is planned.

Standing decisions restated: acquisition is paid in full and creates no
supplier debt; barcode/QR scanning with permanent manual entry is the scanner
design (OCR was retired before this milestone); Customers, Results, Goals,
Analytics, anomalies, WhatsApp summary settings, Partners, loans and
consignments remain; outright inter-store sales and Partner QR codes remain
undecided future work.

### ✅ IMPLEMENTED — navigation

Bottom tabs: **Home · Partners · Money · Stock · More**. Sell remains a route
(`/sell`) reached from Home and Quick Sell; its saved cart is unchanged.
`/money` is the **Results** screen, reached from the Money tab. More groups:
**Activity** (sales history, returns, price approvals), **Reports** (Analytics,
Goals), **Manage** (team, Owner-only import, catalogue, business settings),
**Account** (appearance & language, subscription, devices, sync). Transfers,
Partner stores and Consignments are not repeated on More because a tab leads to
them (Stock header, the Partners tab itself, a Consignments row on Partners) —
recorded in `REACHED_FROM_TABS` with the reason, and still registry
destinations with their deep links.

There is no Customers screen today; listing one on More would mean building a
new feature, so it is not listed.

### ✅ IMPLEMENTED — the six layouts (light and dark, EN/FR/AR)

- **One header** (`TabHeader`) on every tab: context line, one heading, optional
  line, actions at the end edge. Nothing in it waits for data.
- **Home:** Sell (primary) and Receive (outlined) side by side, "Sale with
  several items" below, pending work, and the month's four server figures —
  Profit (large, with a closed "How profit is calculated"), Sales, Expenses,
  Collected. Without `cost.view` the server strips the profit block, so Profit
  and Sales are hidden, not zeroed. One sentence when the month is empty. No
  stock value or menu section on Home (stock cost is on Stock).
- **Money:** Today / 7 days / This month with the exact dates, **shared with
  Results**; recorded Money in / out / Net, labelled as recorded in the app and
  not a bank or wallet balance; Cash & accounts in a disclosure; then Results,
  Expenses, Daily closing, Loans from the registry. Figures need `report.view`.
- **Results:** one Profit figure, the breakdown (sales, approved returns, sales
  after returns, cost of sold items, profit before expenses, expenses, final
  profit) and the returns timing, both closed by default; balances owed and
  discrepancies kept below.
- **Partners:** branch header, own store code with copy, requests waiting on
  this user first, connected stores opening in place to what both stores share
  (they owe us / we owe them, phones each way, open items and whose move, Lend
  and Consign), requests sent, ended relationships. Add is in the header, or in
  the empty state when the loaded list is empty — never both.
- **Stock:** shared header with the server's in-stock count and stock cost
  (cost only with `cost.view`), a transfers button, and the existing search by
  model or either IMEI, scanner, filters and unit rows.
- **More:** branch · role context, the bell, the branch switch, and the groups
  above.

### ✅ IMPLEMENTED — `GET /closings/movements?from&to`

Recorded money in, out and net per channel (cash and each account) for an
inclusive period, needing `report.view` and an active branch. It is the daily
closing's own movement query generalised from one day to a range **in place**,
so Money and the closing cannot disagree; the closing still asks for exactly
one day. No schema change.

### ✅ FIXED — deactivated accounts offered at the till

Full Sell and Quick Sell offered an Owner's deactivated receiving accounts
(which the server then refused). Both now offer only `isActive !== false`;
payment labels already recorded still read the full list; the server's refusal
is unchanged.

### 📋 KNOWN — not fixed here

- On web, a screen pushed from a tab announces its back button as "(tabs),
  back" (the route-group name). The native stack offers no label option; it
  needs a navigation-level fix.
- Home's month figures on the live database still include the overstated
  rollups recorded in `CURRENT_HANDOFF.md`; the repair awaits approval.

### ✅ IMPLEMENTED — receiving a delivery from an Excel or PDF file

A shop that is handed a hundred phones on a spreadsheet should not type them in
one at a time. Receive stock now accepts a file. No schema change.

**Where it is.** An Excel icon sits at the physical right of the "Receive stock"
title, in the top header, above the scan row — in Arabic too, where the header
controls are swapped so the button stays physically top-right while text and
navigation stay RTL. It is 48×48, labelled "Import Excel or PDF", and shown only
to someone holding **both** `import.run` (Owner-only since `0073`) and
`purchase.manage`. Scanning and manual entry are untouched.

**What can be read.** `.xlsx` workbooks and PDFs whose text can be selected, up
to 8 MB, 2000 phones, 50 sheets, 20 000 rows a sheet, 200 PDF pages. Headings
are recognised in English, French and Arabic and can be re-mapped by hand; a
workbook's sheets are scored so an instructions sheet is offered but marked as
instructions, never read as stock. Formulas are read from the value the file
already holds — never executed — and macros and external links are ignored.
Identifiers stay strings, so leading zeros survive and a rounded
scientific-notation cell is flagged rather than guessed.

**What is never inferred.** Nothing missing is invented: storage, colour and
cost are never derived from an IMEI. PDF rows are held together by geometry —
each printed piece keeps its x position and width, data rows are aligned to the
heading positions, and an item spanning into the next column is split by its
measured width — so a price is never attached to a line by proximity alone. A
printed line counts as a phone only when it carries an identifier, or both a
model and a price, which keeps page numbers, repeated headers and totals out of
the stock.

**One row is one phone.** IMEI 2 is optional and two IMEIs are one unit.
Duplicates are caught inside a row, across the selected rows, sheets and pages,
and against both stored identifier columns within the tenant and branch. An IMEI
never reaches the product barcode field. Products are matched against the
existing catalogue; ambiguous matches are flagged for review and unknown ones
need an explicit choice or the existing Create product flow — nothing is
auto-created.

**Reading writes nothing.** Parsing creates no stock and no payment, and says so
before the picker opens. The review groups the phones by category, product and
exact variant, counts ready, needs-attention and excluded, filters on those,
shows each phone's sheet and row (or PDF page) and its problems, and offers
individual corrections and explicit bulk edits that state how many phones they
change. Every problematic phone must be corrected or deliberately excluded —
the good rows are never quietly received on their own — and exclusions are shown
at confirmation. Extracted values are kept apart from corrections. The batch is
saved through the shared draft mechanism under its own key, so a part-scanned
delivery is left alone.

**It is a normal purchase.** Confirmation goes through the existing
`POST /purchases`: a branch, cash or an active receiving account, paid in full,
atomic, with the totals recalculated and revalidated on the server, one "paid
for stock" outflow, and no supplier and no supplier debt. The idempotency key is
bound to the payload, so a replay repeats the same receipt and a changed payload
is refused. **It deliberately does not use the opening-inventory import
endpoint,** which has different cash semantics: opening inventory stays
Owner-only and still moves no money.

**Limits, stated plainly.** An image-only PDF is refused with an explanation
rather than an empty list, and a mixed PDF names the pages it could not read
instead of implying the whole file was processed. OCR and uploading files to an
external AI service remain out of scope; camera OCR stays retired.

### ✅ FIXED — the phone blamed the workbook for a server that was not restarted

The first real-device attempt at file receiving failed with "That file could not
be read". The workbook was perfect. The API process serving the shop had been
started before the feature existed, so `POST /purchases/file/parse` answered
**404** — the route was in Git and in no running process — and the app turned
every failure into that one sentence.

**Each failure now says what happened**: the server cannot be reached; the
server is older than this phone and needs updating; the session has ended; the
role may not import; no branch is chosen; the file is too large, empty,
unsupported, damaged, or holds no sheet of phones; the PDF is photographs; or
the server failed while reading. Technical detail (status, code, file name, MIME
type) goes to a development log only, never to the shop's screen, and the notice
carries a Try again.

**A phone also never uploads a uri it could not open.** React Native builds the
multipart part from the file's uri, and a uri it cannot read fails inside the
networking layer as a bare "Network request failed" — indistinguishable from bad
Wi-Fi. The picked file is checked first, so "gone" and "empty" are said plainly,
and a request that never left retries once with the real bytes. The uri part
stays the first attempt, because it is the transport the rest of the app already
uses, and no content type is set by hand — doing so loses the generated boundary
and the server sees no file at all.

**Operational rule this establishes:** shipping a new endpoint is not done until
the process serving the shop has been restarted on the new build. A backend
check now fails if the module leaves `AppModule`, the route is renamed, or
either parser leaves `package.json` — but only a restart puts it in the running
process.

### ✅ FIXED — the phone's upload, and why it looked like being offline

The stale-server fix above was real but was not the whole fault. The next device
attempt failed with "The app could not reach the server" on an iPhone that had
just registered a phone and completed a sale — so connectivity, authentication
and the API origin were all known good, and the failure was in the upload alone.

**Cause.** On a phone the picked file belongs to Files, iCloud Drive, WhatsApp or
another document provider, and is readable only while iOS says so. React Native
builds its multipart part from that uri inside the networking layer, so a uri
that is no longer readable fails there — with no status, no response and a
message that cannot be told apart from the shop's Wi-Fi dropping.

**The file is now copied into the app's own cache and verified there** before
anything is sent: it exists, it has bytes, the count matches what the picker
declared, a workbook begins with `PK\x03\x04`, the name still ends in `.xlsx`,
and the MIME type is filled in when the picker gave none. The upload is then
handed to **Expo's native uploader** from that verified copy — multipart field
`file`, boundary generated by the platform, the shared API origin and the same
authorisation and branch headers as every other call. No URL is written in the
upload helper.

**A local failure is never reported as the server being offline.** The file being
gone, the file being empty, and an upload that would not start each say so, and
"offline" is claimed only after asking whether the server answers — which is
precisely the question that was never asked. A retry reuses the verified cached
copy when the document provider will not hand the file over a second time.

Every stage — picked, copied, verified, started, answered — is traced in
development with metadata only: url, name, MIME type, sizes, uri scheme, status
and error code. Never the workbook's contents, never a token.

### ✅ IMPLEMENTED — the file review is a staged workflow

The first review screen worked on a test harness and failed on a real iPhone: it
asked how the shop would like to pay before telling it anything was wrong, and
it never said *why* any phone was held up. Rebuilt as **Review → Payment →
Confirm**.

**Review** opens on a stacked summary card — the headline ("100 phones need
attention"), a sentence of explanation, a Ready / Needs attention / Excluded
breakdown, and one action aimed at the actual problem ("Match products"). No
action is placed over explanatory text, and nothing inside a card is positioned
absolutely. A compact footer carries the ready count, the excluded count and the
selected total, with a **Continue to payment** that stays disabled — saying how
many are still unresolved — until every phone has been corrected or deliberately
excluded.

**Payment** is not rendered at all until then, so the shop is never asked to pay
for a delivery it has not finished checking. It is the existing picker, Cash or
an active account, paid in full, with the existing exactly-once accounting
untouched.

**Groups before phones.** A hundred rows of the same model with the same missing
product are one decision. The list is one collapsed card per exact variant with
its count, its subtotal and the reason it is held up; where every held-up phone
in a group is waiting on the same product question, one choice answers all of
them. Only products **every** phone in the group already matched are offered;
nothing is auto-created, and an unknown model still goes through Create product.
After a group correction the counts and totals move immediately.

**Phones are labelled.** Opening a group renders its phones — and only then, so a
file of two thousand costs no more to scroll than one of ten. Each is a separate
card, divided from its neighbours, with **IMEI 1**, **IMEI 2**, **Unit cost** and
**From** named, so two identifiers can never read as two phones. The warning sits
beside the written reason, never beside the price: a correct price on a phone
whose product is unknown is still a correct price.

**"Bulk edit"** replaces "Change several at once", says which field it can change,
and states before applying both how many phones it affects and **how many already
hold a different value** — nothing is overwritten silently. **"Exclude all"** left
the alert; it sits quietly at the end of the review and still asks first, naming
the count.

The floating gear seen on the device is **Expo Go's**, not the app's: there is no
`expo-dev-client` dependency and no absolutely-positioned control in the app's
tree.

### ✅ IMPLEMENTED — the Money redesign, partial payments and who owes (migration `0074`)

**The Money overview** answers four questions and keeps their words apart:

| Figure | Meaning | Source |
|---|---|---|
| **Cash in the drawer** | What the drawer should hold now, after today's cash in and out | The daily closing's own expected-cash computation — Money and the closing cannot disagree |
| **Accounts today** | What was recorded into and out of each active account today | Recorded movement, **never called a balance** |
| **Phones sold · Sales value** | IMEI-tracked units sold; the full selling price of everything sold | The sales, on the sale's own day |
| **Collected** | Money actually received in the period | Payments, dated by when the money **arrived** |
| **Still owed** | What the period's sales still owe | Each sale's `balance_due` |

No "total available" is shown, and accounts carry no balance: the model reconciles each drawer day on its own (no opening float) and never learns an account's opening balance or what the owner moves out privately, so neither figure can be stated honestly. The brief allowed exactly this condition. Below the figures: three sales with **View all sales** (today as a list; 7 days and a month a day at a time, each day's sales fetched only when opened), today's expenses with where each was paid from, and the registry actions — Results, Expenses, Daily closing, Loans and, new, **Outstanding payments** (`report.view`).

**Partial payment at the counter.** The amount received now defaults to the whole total, so an ordinary sale is still one tap. Lowering it shows the remaining balance and the resulting status (Paid in full / Partially paid / Unpaid — now the only three names in the app) and asks who owes the rest: a **customer** — chosen from the list, or typed with a required name and optional phone, created inside the sale so nobody is duplicated and an employee needs only `sale.create` — or a **partner store**. Nothing received at all is a real sale. More than the total is never taken.

**A store as debtor — deliberately narrow.** `docs/21` previously refused to fake an outright inter-store sale with a customer sale. This records **our** sale with a balance a store owes: the unit leaves our stock and the receivable sits on our sale. **Nothing is written into the other store's company**, and the balance is not added to the shared Partners summary, whose privacy guard forbids reading sales there. Only a store with an **accepted** connection can be given new credit (the approved Partners rule); a person, or a store whose connection was removed, is refused. The bilateral inter-store sale remains undecided.

**A later payment is not a second sale.** `POST /sales/:id/payments` (`sale.create`) records money received later: dated when it arrived, into cash (drawer only) or one active account (that account only), with an optional reference and note, the recorder, and the account label frozen. Revenue, cost, profit, sales count and phones sold never move. The sale row is locked while deciding, so racing payments cannot overpay; a payload-bound key makes a retry answer the same and a reused key a 409. Zero, negative, overpayment, an inactive account, a future or pre-sale date and a signed-off day are refused. The sale detail shows every payment with its time, label-as-it-was, reference and recorder; **Record payment** reviews before saving and shows the balance before and after.

**Dating by arrival.** Closing's expected cash, its per-channel movements and "collected" now read `payments.paid_at`, not the sale's `sold_at`. No past day moved: all seven earlier payments arrived in the same second as their sales.

**Expenses.** Description, amount, paid from (cash or an active account), date (today by default) and an optional receipt photo; no category chips, no employee. The approval workflow is unchanged — a report moves nothing; money leaves exactly one source when the Owner confirms, and "Paid out today" lists confirmed expenses. Fixed costs and salaries stay separate, as before.

**Permissions.** Owner and Manager see branch figures and Outstanding (`report.view`). Anyone who may sell (`sale.create`) records a sale with a balance and a later collection. Store lists follow the existing `consignment.view`. Every query and write is company- and branch-scoped.

### ✅ IMPLEMENTED — Sell a phone: three ways in, one selection

"Sell a phone" (Quick Sell) starts with **Scan IMEI**, **Enter IMEI manually** or **Choose from stock**. All three end in one read-only server lookup, `GET /sales/selection/:identifier` (`sale.create`), which finds the existing unit by either IMEI or its serial, in this company, and answers its availability **for the active branch** (available, sold, faulty, reserved, other branch, unavailable), the product with storage and colour, a **masked** identifier, and the price from the sale's own ladder (only when sellable). The same selected-phone card shows how the phone was found, then **Continue to payment** opens the existing payment sheet — full or partial, the same debt, receipt and accounting. There is one selling system.

- **Scan** is the existing scanner, unchanged (raw, labelled, dual-IMEI QR; scan lock; paused result).
- **Manual**: presentation characters removed, exactly 15 digits, checksum; the server checks again. Invalid, not found, sold, faulty, reserved, other branch and network failure each have their own words.
- **Stock**: this branch's in-stock phones, searchable, paged; tapping one runs the same lookup.
- **Never**: a Product or Unit created, stock added, or an IMEI written into a barcode.
- **Not exposed**: internal ids, the full IMEI, the staff timeline, other-branch names, other companies' data; `cost` only through the existing cost-gating interceptor. *(The brief was truncated at "Do not expose"; this interpretation was used — confirm.)*


### ✅ IMPLEMENTED — Who may see which phone, and how much of its IMEI (confirmed by the user, 2026-09-18)

These are intentional rules, not gaps.

- **Another branch.** Without `branch.manage`, the server answers a phone elsewhere — in stock, sold or otherwise — exactly as a number that exists nowhere: *"This phone is not available in this branch."* (`not_available_here`), so the lookup cannot probe other branches. With `branch.manage`, it answers `other_branch` and the branch **name** (no id, no price). The server decides; the app never infers it. Another company's phone is never found (tenant client).
- **Full IMEI or serial, intentionally:** the manual-entry field and the scanner result (the operator verifying the phone); the **completed Sale detail** for authorised staff (warranty, returns, matching the physical phone), under the existing company, branch and route permissions; and the **customer's receipt**, which is warranty and ownership proof. The receipt still carries no cost, margin, internal id or unrelated staff/customer information.
- **Masked (last four):** stock browsing lists, the selected-phone preview before payment, Money overview previews, notifications and other compact summaries.
- **Always:** no internal database or binary ids; cost only with `cost.view`; no unrelated staff history. The server looks up and enforces uniqueness on the complete IMEI.

*This replaces the note "confirm" in the three-way selection entry above.*

### ✅ IMPLEMENTED — the approved screens, as drawn (visual-fidelity pass, 2026-09-21)

The approved screenshots for Money, period sales, daily expenses, partial and later payments, and the three-way phone selection are the binding references. This pass made the running app follow them; the server contracts did not change.

**Money.** Branch and title; the tinted *Cash in store now* card (the closing's own expected drawer, "Expected balance" underneath, accounts one tap away); the filled period switch with the exact days ("14–18 Sep 2026"); one card with the four period facts — Phones sold, Sales value, Collected, Still owed; then *Phone sales* (today: a few sales, then *View all sales*) or *Sales by day* (a week: every day; a month: the latest three days and one folded line naming the earlier span and how many days it holds — **never a sum made on the phone**); then *Daily expenses* with *Add expense*, today's paid expenses and *View all expenses*; then the registry rows.

**Phone sales.** Period switch, the tinted *Sales total* card with phones, Collected and Still owed, and a virtualised list: today's sales as rows, a week or month as day cards that open in place. "Payments recorded" by method for a period is **not** in the overview contract and is not drawn: the phone does not add payments up.

**Sale details.** The phone first — name, variant, status chip, and its **full IMEI or serial** (the confirmed policy) — then the tinted *Selling price*, then how it was paid, when and by whom, who bought it or owes it, the payment history, the return policy, the totals, and *View receipt*, which prints the customer's receipt from the sale itself (full identifier, no cost, no margin).

**Add expense.** Description (free text, no suggestions), Amount (MRU), Paid from (Cash or one account), Payment date (today, typed as `YYYY-MM-DD` — there is no native date picker without a new dependency), Add receipt (optional); fixed costs, salary, reference and note wait under *More options*. *Review expense* then shows the details and, for an **Owner**, *Expected cash after recording* (before, expense, after — a preview the closing recomputes) and **Record paid expense**, which reports and confirms in one explicit act. Anybody else sends the report for an Owner to confirm, and the review says so. The accounting rule is unchanged: a report moves nothing; money leaves exactly one source when an Owner confirms.

**Daily expenses.** "Expense recorded", the cash card, today's paid expenses with where each came from, then every expense with its status filter; *Add expense* and *Back to Money* pinned. Per-source subtotals are not server figures and are not drawn.

**Sale payment.** What is being sold, *Sale total*, *Amount received now*, *Received via* (Cash | Choose account — the account implies the method), then, only when less than the total is taken, the amber *Remaining to pay* with its status, *Who owes the balance?* (Customer: a name and an optional phone, or *Select existing customer*; Store: a partner-store picker and *Add a store*), "Only X is recorded as received", and **Review sale**, which states the balance in words before sending. Discount, return policy and split payment wait under one disclosure. Nothing about pricing, approval or receipts moved.

**Record payment.** Who owes and for which sale, the amber *Remaining before payment*, amount, *Received via*, date, reference, note, then *This payment* beside *Remaining afterward*, and **Record payment** (still reviewed in words first). Back on the sale, "Payment recorded" is said once, in a banner.

**Sell a phone.** Three cards — Scan IMEI, Enter IMEI manually, Choose from stock — each its own screen. *Enter IMEI* validates as typed, looks the number up the moment it is a real IMEI, shows the found phone with its **complete** IMEI, *Use this phone*, *Choose from stock instead* and the note that nothing is created. *Choose from stock* searches, filters by brand, counts, lists each available phone with its variant, masked IMEI and the ladder price, and continues with the selected one. *Review sale* shows the phone with its masked IMEI, Available, the selling price, how it was found, *Continue to payment*, *Choose another phone*, and that the phone leaves stock only when the sale is confirmed.

**Deliberate deviations from the mock-ups:** no product photos exist (`docs/47`), so every picture slot is an honest tinted icon; the completed Sale detail shows the full IMEI (the mock masks it, the confirmed policy does not); Quick Sell stays a stack screen, so the tab bar is not under the chooser; segment pills are 42 pt inside a 48 pt track, chips 36 pt with hit slop, and the sheet's Close button 36 pt — all pre-existing geometry.

## Inventory correction, Excel-review performance, generic selling and the global card hierarchy (2026-09-22)

Seven checkpoints (CP1 audit → CP7 Money terminology), each committed and pushed on its own. The binding decisions:

### ✅ IMPLEMENTED — CP2: correcting an in-stock item (`PATCH /units/:id`, no migration)

An intake mistake — a mistyped IMEI, the wrong product, a cost off by a digit — could not be fixed: the inventory controller could receive and mark faulty, but never correct. It now can, deliberately narrowly.

- **The endpoint** is `PATCH /v1/units/:id`, guarded by **`unit.add`** — the same branch-scoped authority that receives stock and marks it faulty; correcting an intake mistake is the same person's job as making it. No new permission key, no migration.
- **In-stock only.** A sold, reserved, in-transit, returned or faulty unit is refused; those states have their own workflows, and a silent edit would contradict a sale, a transfer or a receipt already on the books.
- **The unit's own columns only.** The product is *re-associated* (`productId`), which is how its model, variant, storage, colour and barcode are fixed — by pointing at the right catalogue entry, never by rewriting the shared one, which would rewrite every other unit and every past sale. An IMEI has no route to the barcode field, because barcode is not a unit column. The branch never changes here (that is a transfer) and neither does the status.
- **The tracking type shapes it.** An imei-tracked unit takes IMEIs and refuses a serial; a serial-tracked unit the reverse. The client never picks the mode.
- **Sensitive changes are explained.** Any IMEI, serial or cost change needs a reason, recorded on the audit entry (`before`/`after`). **Cost** may be touched only by a caller with **`cost.view`** — you cannot fix a number you may not see — and it is stripped on the way out by the existing gating interceptor.
- **Optimistic concurrency without a version column.** The write matches on `updatedAt` (compare-and-swap via `updateMany`); a stale correction writes nothing and asks the caller to look again. The migration-0042 cross-column triggers and the unique indexes remain the race backstop, mapped to a 409. **No schema change was needed or made.**
- **Mobile.** A pencil appears on a unit's detail only when the server would allow the edit (`unit.add` and in-stock). The decision logic lives in a pure `lib/unit-correction` module with its own test.

### ✅ IMPLEMENTED — CP3: one bordered surface per section (the card-in-card is gone)

A dozen screens drew a box inside a box — a Card wrapping a bordered Toggle, a Card wrapping bordered ListRows. The rule, now enforced: **one visible bordered surface per logical section; the container owns the edge and its rows are flat.**

- `Toggle` gains a `flat` prop (matching `ListRow`'s), the shared primitive this needed.
- **Appearance & language** is one `RowGroup`: a dark-mode row and the language rows separated by a hairline, with the restart notice moved outside the panel. Hub tiles, the settings auto-lock choices, and the brand/model/storage/colour/tracking pickers all flatten their rows.
- Guarded by `lib/design/no-nested-surfaces.test` — an **AST** check (not a regex) that fails if any Card, RowGroup, StatTile or non-flat ListRow/Toggle is nested in another. InlineNotice, plain/sunken Cards, dialogs and sheets are deliberately *not* surfaces for this rule.

### ✅ IMPLEMENTED — CP4: the file-delivery review, made fast and triageable

The review dragged on a handset because every opened group stayed open (a hundred rows could all be mounted) and nothing was memoised.

- **One group open at a time** (`openKey`): opening a group closes whichever was open, so mounted rows never grow with the delivery. `GroupCard` and `EntryCard` are `React.memo`; `EntryCard` gets only primitive props (problems arrive pre-joined), so correcting one phone re-renders that phone, not the group.
- **Three actions per phone**, always in the same place: **Accept** (a check), **Edit** (a pencil), **Remove** (a bin) — 48pt icon buttons with spoken labels. Accept and Remove carry native confirmations; Accept names the product, identifier and cost and says "Mark this item as ready for this delivery." None creates stock.
- **Accept earns its place.** A cost that came from a spreadsheet formula (`formula_value`) is **advisory**, not a blocker — but until now any flag held a row out of the delivery, so a phone with a perfectly good price could only be **excluded**, never received. Accepting is how a person says "I looked, it is right." Hard problems (missing / invalid / duplicate / unknown / ambiguous) are never waivable. The batch carries an `acknowledged` set beside corrections and exclusions, defaulted on restore so older drafts still open.

### ✅ IMPLEMENTED — CP5/CP6: sell an item, not just a phone

- **The one lookup resolves three kinds of code.** `GET /sales/selection/:identifier` stops assuming every code is an IMEI. It refuses only nothing at all and a **fifteen-digit number with a wrong checksum** — a mistyped IMEI is an *invalid IMEI*, said so, never quietly reinterpreted as a barcode (the "guess the type from altered digits" mistake). A serial, a barcode, or any other number is left for the lookup to resolve.
- **A barcode sells only a counted product.** When no unit matches, the identifier is tried as a product barcode; only a **quantity** product answers, as a `kind:"product"` selection carrying the branch's own sellable stock (owned − reserved) and its ladder price — **no unit, and no cost** (a counted product has no single per-unit cost). A serialized product's box barcode names a model, not the item in hand, so it cannot pick one to sell; that still needs the unit's own IMEI or serial. This reuses the existing `POST /sales` quantity line — it is **not** a `sale.create` contract change.
- **The selection says its `kind`** — `unit` or `product` — so the sale sends an identifier for one, a product id and a quantity of one for the other. One shared selection state, one checkout (pricing, partial payment, debtor, channels, receipt, audit, branch).
- **Choose from stock, redesigned.** Thumbnail boxes gone; the wrapping brand chips replaced by one **Filter** action opening a sheet (brand and type, with Reset) plus a one-line active-filter summary. Compact rows: name, variant, the masked identifier **labelled by what it is** (IMEI / Serial — never a made-up IMEI for what has none), the price and a selection circle; the redundant "Available" badge is gone. The picker lists the **serialized** items you pick one of; **counted accessories are added by scanning their barcode**, because "which cable" has no answer — so "no fake IMEI for untracked" is honoured by keeping untracked items out of the pick list entirely.
- **Generic "item" language** across EN/FR/AR, IMEI-specific wording kept only where it genuinely is (the IMEI validity hint, the full-IMEI display on manual entry and the completed sale).

### ✅ IMPLEMENTED — CP7: Money terminology

"Items sold" and "{count} items" replace the phone wording; the sales card is headed "Item sales" with a neutral package icon. The **daily-expense card** now says plainly that it is **today's** total and is **not** moved by the period switch above it (the switch controls sales). Figures, sources, reconciliation and the `period.phonesSold` data field are unchanged — only the words.

### 📋 VERIFICATION — deterministic gate green; the isolated render matrix and handset run are owed

Backend: tsc, `nest build`, `prisma validate`, migration status (up to date, no drift), permission catalogue (62/62) and the full suite (**138 suites / 2529 tests**) all green. Mobile: tsc, `expo lint` (0 errors; 31 pre-existing warnings), **59 pure suites** (2 pre-existing extensionless-import failures unrelated to this work), i18n parity (2626 keys, identical order), the AST card-nesting guard, and a clean `expo export --platform web` (all routes build, including the new `/unit/edit`). The card-flattening is proven by the AST test more strongly than a screenshot could; the generic copy and single-open/memo structure by parity and source-scan tests. **Owed and recorded as pending:** the EN/FR/AR × light/dark × 320/390 isolated web-render matrix, the real 100-item workbook reproduction, and physical-device performance and Dynamic Type — none of which a deterministic suite or a web render can stand in for. Expo Doctor's four patch-version package mismatches are pre-existing.

## Correction of the generic selling, Excel-review performance and the three restyles (2026-09-22, second phase)

A focused correction of the previous session's work — no new feature. Every cause below was **reproduced** (over real HTTP on an isolated copy of live, and on the web build of the previous HEAD in headless Chrome) before anything was changed, and reproduced again afterwards. Commits: backend `59381f3`, `22d8227`; mobile `68a8a57` (sale fixes), `f62a27c` (review performance), `ef2c795` (review restyle), `d8e352e` (Sell an item), `de20990` (Choose from stock), `3cfd598` (lint: the review's group ref written in an effect).

### 🔎 What was actually wrong

- **"Continue" on a camera, a console or any serial-tracked item did nothing.** The server's `normalizeIdentifier` stripped dashes, dots, slashes and spaces out of *every* identifier, and the client did the same before asking; stored serials carry their dashes (`CAN-1662030-0019`), so the lookup hit nothing (404 for both the stripped and the whole form). On the handset the "not found" notice rendered at the **foot of a thirty-row list, under the fixed footer**, so the tap looked dead. Reproduced on the previous build (GET `/sales/selection` → 404, notice below the fold); after the fix the same tap opens the review (GET → 200).
- **The Pixel sale that "loaded for ever" created no sale.** Read-only on live at takeover: both Pixel units in stock, no sale item, no audit row; the server path is healthy and fast (201 in 85 ms at the ladder price; 403 `approval_required` in 48 ms below cost; 201 `warnings_pending` in 38 ms for an extra zero). The one client path that leaves the button loading indefinitely is an **unanswerable question**: a dialog raised while the payment sheet is open (the below-cost reason, the "does this look right?" warning, the debt review) was a second root-level native modal over the sheet's modal, which iOS does not reliably present — the promise never resolves. On the web build the dialogs do appear (reproduced), so the handset check remains authoritative; the arrangement is removed either way.
- **A lost answer was reported as "not sent".** With the `/sales` answer held past the client's 20-second timeout, the previous client said "check the connection and try again" while the server had recorded the sale (invoice on the server, unit sold); the seller was told the opposite of the truth.
- **A changed payload with the same client key silently returned the original sale** — a stale retry could pass for the sale it claimed to be.
- **Refusals for serial-tracked units read "Unit null is 'reserved'".**

### ✅ IMPLEMENTED — the generic sale contract, corrected (backend `59381f3`, `22d8227`; mobile `68a8a57`)

- **Identifier normalisation, one rule on both sides:** presentation characters are removed **only when what remains is a fifteen-digit IMEI**; anything else — a serial, a barcode — is looked up exactly as trimmed. Either IMEI selects the same unit (`matchedBy: imei1 | imei2`).
- **A counted product asks how many.** Selection `kind: "product"` carries `quantityAvailable`; the checkout shows a stepper (default 1, at most the branch's stock), refuses zero, negatives and more than available before asking the server (the server refuses them too: 400 / 409 "Only N available to sell"), charges price × quantity and puts the quantity on the receipt. Serialized units are sold by the identifier they were found by; nothing is invented.
- **Idempotency is honest.** A replay with the same key returns the same sale; a **different payload** with the same key is refused with **409 `idempotency_conflict`**. New **`GET /v1/sales/client/:clientUuid`** (`sale.create`) answers what a key recorded: 200 the sale, 404 nothing, 400 not a key.
- **A lost answer is unknown, never "not sent".** On a timeout the client asks what its key recorded: found → the sale finishes with that record ("The sale was recorded — the answer arrived late"); nothing → the same key may be sent again; still no answer → hold, and refresh sales, inventory, Home and Money. **The key is rotated only for a new sale or on `idempotency_conflict`** (then the lists are refreshed and the sale starts again). A second tap while a submission is in flight starts nothing (`inFlight` ref); loading is released on success, on every named refusal and on a timeout.
- **One modal at a time.** A dialog raised while a bottom sheet is open is drawn **inside the top-most sheet** (`SheetDialogLayer`; the root `DialogHost` yields while any sheet is open). The approval sheet opens only after the payment sheet reports itself closed. Both checkouts (Sell an item and the Sell tab) follow the same rules.
- Refusals name the unit by the identifier it has, or say "That unit".

### ✅ IMPLEMENTED — the file review, flattened (mobile `f62a27c`)

The list is **one virtualized sequence** of records — a header per group, then the rows of the single open group and nothing for a closed one — built by the pure `lib/file-review-rows` rule; headers and rows are memoised on primitives with callbacks keyed by row; counts, purchase payload and its fingerprint are computed once per change; the draft is written on change, never on scroll. Measured on the real 100-row workbook (instrumented web build, same method before and after): one group open → **10 rows + 2 headers mounted** (before: 10 rows + all 10 cards); excluding or editing one row → **1 row + 1 header re-render** (before: 1 row + **10 cards**); DOM 498 vs 599 nodes; no long tasks either way. No new dependency.

### ✅ IMPLEMENTED — the file review, as drawn (mobile `ef2c795`)

Three-figure summary (ready / needs review / excluded), one sideways filter row, compact flat group headers (name, variant, a short reason, count, subtotal, "Match product" when one choice answers the group), thin dividers, no nested cards, no repeated warning cards. Each row: spreadsheet row · identifier masked to its last four and labelled IMEI or serial · a second-IMEI indicator · unit cost · status in words · **Accept / Edit / Exclude with their names**. Accept is disabled while a blocking issue remains and, when enabled, asks a native confirmation naming product, identifier and unit cost — it only marks the row ready. Exclude asks a destructive confirmation and removes only that row (recoverable from the Excluded filter). Edit opens the item sheet (source, product, whole identifiers, cost, what blocks it, candidates, cost field, the same actions) and returns to the same open group. Stock is created by the final delivery confirmation alone. Short statuses exist for all fourteen problems in EN/FR/AR; eighteen keys nothing reads any more were removed.

### ✅ IMPLEMENTED — Sell an item and Choose from stock, as drawn (mobile `d8e352e`, `de20990`)

Sell an item: one section of three design-system rows (functional icon · title and one short line · chevron; the whole row is the target) and one outlined full-width "Sell several items" action beneath. Choose from stock: search and a 48pt Filter on one row ("Name or identifier"); one virtualized list that loads the next page as its end comes into view — the screen's own scroller, never a list inside a scroll view; flat rows with hairlines: name, variant, identifier masked and labelled by type, price, and the selection control in one fixed trailing column beside the price; selected row accented; a fixed footer "Selected: <item>" + "Continue with this item", enabled only with a selection, that always either opens the checkout or shows the failure in words beside the button.

### 📋 VERIFICATION

- **HTTP proof on the isolated copy (`cp3-proof.cjs`): 28/28.** iPhone by IMEI 1 and by IMEI 2 (same unit), Pixel, camera and console by serial, accessory by barcode ×2 (stock −2); zero/negative/excessive quantity refused; sold, faulty (`POST /units/:id/faulty`) and reserved (a real transfer) refused; other branch says "elsewhere" (named only for an owner) and refuses the sale; other company gets a plain not-found with nothing about the owner; invalid serial / bad-checksum IMEI / unknown barcode handled; duplicate key → same invoice, nothing counted twice; changed payload → 409; a thrown-away answer → the key lookup reveals the sale and the retry replays it, counted once; partial payment for an IMEI unit, a serial unit and a counted product (`payStatus: partial`, balance 100); the Money overview and the outstanding list moved by exactly the sales made. Fixtures cleaned to baseline; **23 audit rows kept** on the copy.
- **Client reproductions** (headless Chrome, web build, isolated API): serial Continue 404 → 200 and the review; the below-cost and magnitude dialogs; a plain sale; the 22-second held answer — before: "try again" with the sale recorded; after: "No answer yet — checking…", "The sale was recorded — the answer arrived late", and the success screen.
- **Gates:** backend tsc / build / full suite **2560 tests, 0 failed** (sales-idempotency 11, sales-policy 17); mobile tsc, `expo lint` 0 errors, **all 64 pure suites pass** (the two extensionless-import suites repaired), EN/FR/AR parity **2646 keys, identical order, 0 duplicates**, web export clean with every route (`quick-sell`, `receive/file`, `(tabs)/sell`), Expo Doctor: the same four pre-existing patch-version mismatches. Render matrix: 197 captures (EN/FR/AR × light/dark × 320/390, plus EN and AR at 320 with 130 % text; 14 states each, plus the lost-answer recovery) — 0 leaked keys, 0 clipped text, 0 sideways overflow, 0 overlapping text.
- **Physical device:** not run in this phase — `docs/24` §35 lists the checks; the handset stays authoritative for smoothness and native modal behaviour.

## Invoice, Daily Closing, alerts preview, platform administration, website deferral (2026-09-22, parallel scope)

A second CLAUDE-A conversation, by the user's instruction, in a scope disjoint from the correction phase above. The audit that preceded every change is `docs/49`. Commits — backend: `60bd6c1` (alerts order/paging/idempotent dismiss), `c9e7a23` (0075: `rejected`, approve/reject/period), `f2d97f7` (admin-created business, Owner invitation, boundary spec), `e7eddab` (`/auth/me` carries the business name), `d16dc1e` (undo a dismissal), `decb699` (the undo route's decorators, with a route spec); mobile: `f5c1441` (invoice), `afda01a` (Daily Closing), `baa6528` (alerts), `2a00f25` (website withdrawn), `a6182fe` (platform area), `3397e90` (root state gate), plus the audit-label commit recorded in the handoff.

### ✅ IMPLEMENTED — the customer's invoice (mobile `f5c1441`, backend `e7eddab`)

One generator, split into a pure HTML builder (`lib/receipt-html.ts`, labels and formatters handed in, testable under bare node) and the share wrapper. The page is a column of about 83 % of A4 and Letter alike (16 mm × 18 mm margins) — the 80 mm thermal strip is gone; hierarchy store name → invoice number → total → **Paid / Partially paid / Unpaid**; the table header repeats on every printed page and no row or totals block splits across one; flat print-safe ink, no gradient, no photo; a logo slot that stays empty until the server exposes a store logo. Content, all server-confirmed, is Business Rule **19e**. Figures, dates, identifiers and phone numbers are isolated LTR so Arabic reads "329 000 MRU". Every value escaped. The full IMEI/serial stays on the customer's copy (19d, confirmed 2026-09-18). `/auth/me` now carries the business name so the invoice can be headed with it. **Owed to the selling scope:** the two counter receipts (Quick Sell, the Sell tab) keep compiling and print the new layout — status, paid and remaining are derived from the payments — but do not yet name the customer, because those screens belong to the other conversation.

### ✅ IMPLEMENTED — Daily Closing, one list (mobile `afda01a`)

Root cause of the handset lag, reproduced on the web build and stated honestly: (a) `Screen` wraps its body in a full-screen keyboard-dismissal `Pressable` — a JavaScript responder above every row, so a drag that began on a label was claimed before the native list could scroll; (b) one `Card` per channel with a nested field surface; (c) saving a count re-rendered **every** card (a fresh `onSubmit` closure per card and `record.isPending` flipping on all of them); (d) the clipped purple text at the left edge was the full-width ghost "Discrepancies" button. Now: the open day composes its own SafeAreaView, KeyboardAvoidingView and a **FlatList** — nothing invisible sits above the rows; rows are one bordered surface, each `React.memo`'d on the figures it shows, a submit handler that never changes identity, a "saving" flag naming one row; one summary surface (date, progress, expected in total, counted so far, difference), a section title with the remaining count, one explicit Save per row, skipping for accounts only, compact loan reminders, and **Review and close** pinned under the list, disabled with its reason until every count is saved, confirming with the totals. `keyboardShouldPersistTaps="handled"`, the footer's measured height reserved, rows never clipped away. **Measured** (un-minified web exports, 25 channels, React commit counting per keystroke and per save, before → after): rows mounted at load 25 → 16, DOM nodes 1 022 → 744, mounted inputs 19 → 7; per keystroke one row update in both; per save row updates **50 → 2**, component updates 1 664 → 309, script 160 ms → 64 ms, task 195 ms → 114 ms. `closing-screen.test.ts` pins the structure. Native touch behaviour is a handset check (`docs/24` §36).

### ✅ IMPLEMENTED — "Needs your attention": three newest, the rest on /alerts (backend `60bd6c1`, `d16dc1e`, `decb699`; mobile `baa6528`)

Nothing is stored: each rule dates its anomaly from its **own records** (the overdue due date, the day a shelf went quiet, the latest short closing, the latest below-cost sale, the day of the margin comparison), and the list is a total order — newest first, then the serious, then by key — so the overview's three and the full list agree on every read. `GET /anomalies?limit=&page=` slices that order and returns `total`. The overview shows the three newest in one compact surface (type and weight in a word, when, the sentence, **"I understand" / "J'ai compris" / "فهمت"**); acknowledging removes the row at once and the next moves up; the toast offers **Undo** (`POST …/undismiss`, ends the standing dismissal, audited) instead of a confirm dialog — docs/05's rule; "View all 12 alerts to review" appears only past three and opens `/alerts` (twenty a page, virtualised, loading / error / empty / end states). Dismissal is idempotent on the server (a repeat answers the standing dismissal). Company/branch isolation and permissions unchanged (server-side). The undo route had been attached to the dismiss decorators — found by the render matrix, fixed with a route-metadata spec.

### ✅ APPROVED — subscription states, and the decisions behind them (backend `c9e7a23`, `f2d97f7`)

- PENDING_APPROVAL = `pending_activation`; ACTIVE / GRACE / EXPIRED are derived from `current_period_end` by the server clock (grace = +72 h, **never stored**: a corrected period carries its grace; an administrator ends grace by suspending and lengthens it by extending); SUSPENDED = `suspended`; **REJECTED = `rejected` (new, 0075)** — a refusal is a decision like suspension and not an ended subscription; the app is closed to it with its own code `ENTITLEMENT_REJECTED` and words. `cancelled` is kept as the existing valid ended state.
- Approve (months 1–60 or an exact end date; also reverses a refusal), reject (reason), set/correct the end date (shortening needs a reason), extend, suspend (reason), reinstate, cancel (reason): every one re-asks the administrator's password, carries a `version` (409 `subscription_changed` for the loser), is idempotent for a same-state retry, and writes a subscription event **and** an immutable audit row with before/after. Nothing is deleted.
- **Admin-created business** with a random password nobody knows and a **one-time Owner invitation**: hash only, 72 h, single-use, atomically claimed, revoked as a set when reissued; accepted on a public throttled route that sets the Owner's password and issues no session; **delivery is manual and says so** — no provider sends anything. No default administrator credential anywhere; bootstrap unchanged (`PLATFORM_ADMIN_PASSWORD`). MFA still does not exist and none was invented.
- **Enforcement is the server's**: an old build, a changed phone date, a direct API call, a stale session or a different branch header cannot open a closed shop; the locked surface stays `entitlement`, `auth/me`, `auth/logout`, `auth/refresh`, `health`, `platform/my-subscription`, `platform/payment-instructions`. Proved by `platform-boundary.spec.ts` and live on the isolated copy (42 steps; `docs/37` Phase 5).

### ✅ IMPLEMENTED — the platform's own surface in the app (mobile `a6182fe`, `3397e90`)

`app/platform/*` on its own identity: sign-in, overview (counts by state, search, state filter, compact rows), a business (identity, state and dates, people and their verification, history, recorded payments, controlled actions by state, the invitation shown once), create a business, the audit trail in words. Its client sends the platform session only — no tenant token, no branch or company header — kept in memory and ended on a 401; the tenant redirects leave the group alone; nothing in a shop's tabs or menus leads to it; the only entry is a small link at the end of the sign-in screen. Every action is a form (months or date, reason where access is taken away, the administrator's own password) → a confirmation naming the business → the server's answer; a concurrent change reads "refreshed", never applied twice. The shop side: a closed shop (pending, suspended, cancelled, rejected) is sent to the state screen **at the root, before any branch is chosen** — the live run showed the branch list itself is refused while closed, so a tabs-level gate would never have run.

### ✅ APPROVED — the website is not included from the app (mobile `2a00f25`)

Removed from the app: the portal handoff helper and hook, the website registration link, the "Manage your account" button, the automatic browser open after registration, `EXPO_PUBLIC_PORTAL_URL` / `EXPO_PUBLIC_SIGNUP_URL`, and every "extend it through our official website" sentence. The blocked screen says whom to contact, in neutral words, with "Check again" and "Sign out" — no website, no payment link, no price. The server's handoff route and every record stay; the website repository is untouched. **Deferred:** the website does not know `rejected` and has none of the new actions (`docs/38`).

### 📋 VERIFICATION

- **Backend:** tsc clean · `nest build` clean · `prisma validate` · `migrate status` up to date (0075) · **drift check**: the only difference the Prisma diff reports is the pre-existing stored generated column `units.identifier` from 0008, which Prisma cannot model — nothing from this scope · full suite **2 605 tests, 0 failed** (145 suites; anomalies 49 incl. the route spec, platform/entitlement 210) · the 42-step live lifecycle on the restore-proved copy.
- **Database:** backup `phonestore-before-0075-20260922-055832.sql` (862 536 B, hex-blob, trailer present) → restore-proved into `prisma_verify_platform` (88 tables / 24 triggers, counts and the `units` checksum equal, trigger bodies identical) → 0075 forward there → live. Live rows unchanged before and after (9 sales / 53 units / 862 audit rows); the scratch schema and its throwaway administrator dropped at the end.
- **Mobile:** tsc clean · `expo lint` 0 errors (the 31 pre-existing warnings; 0 in this scope's files) · Expo Doctor: the same four pre-existing patch mismatches · **all 66 pure suites pass** (new: receipt-html 23, receipt-privacy 9, closing-screen 13, attention-rules 8, website-deferred 6, platform-admin 13) · parity **2 793 keys** identical order, no duplicates, placeholders match · web export clean, every route present (83) · audits on this scope's screens: 0 raw colours, 0 hardcoded copy, 0 unlabeled controls · `expo-linking` stays as expo-router's own dependency.
- **Visual:** the invoice rendered to real PDFs through headless Chrome — A4 and Letter, EN/FR/AR, one / twelve / forty lines, paid / partial / unpaid, customer and partner-store debtor — and inspected as images; the render matrix on the final export: Daily Closing EN/FR/AR × light/dark × 320/390, keyboard open (EN, AR), 130 % text, one account and twenty-five; Analyses with seven, three, one and zero alerts and the full list (EN, AR); the blocked screen pending / rejected / suspended (EN, AR), grace with hours left and expired on the subscription page; platform sign-in (EN, AR), overview (EN, FR dark), a pending business with its actions, the approve form, create (AR), the audit trail — **44 captures, 0 leaked keys, 0 sideways overflow** (the one "platform." hit is a probe administrator's e-mail in real audit data).
- **Physical device: not run** — `docs/24` §36 lists what only a handset can show.


## The Home dashboard and the business-day closing (2026-09-23)

Audit, contract and plan: [`docs/50`](50_AUDIT_HOME_BUSINESS_DAY_CLOSING.md). Reference screens: the six PNGs the brief attached (Home overview and scrolled, Boutique ranking, Stock "newest received", Closing & history, the before-06:00 choice). Backend on `reports-export`, mobile on `reports-export`, migration **0076**.

### ✅ APPROVED — the business day begins at 06:00 local, and every money record stores its business date (backend `29b9cc7`)

- **Rule:** the business date of an instant is the company's local calendar date, minus one day when the local hour is before 06:00 (`src/common/business-day.ts`, pure; 11 tests at 05:59:59 / 06:00:00, month, leap and year edges, zones with and without daylight saving, an unknown zone refused). The timezone is `companies.timezone` (a branch has no column; the shops of one company share a country). Both live companies say `UTC`, so on live only the 06:00 cutoff moves anything.
- **Stored, not recomputed:** `sales.business_date`, `payments.business_date`, `supplier_payments.business_date` beside the immutable instants; expenses, refund payouts, supplier settlements, corrections and return reversals keep their existing DATE columns, now assigned through one `BusinessDayService` instead of `dayKey(new Date())`. Rollups, the closing, the per-channel movements, "collected", the Money overview, the daily sales series and Home all key on the stored date. Loan and consignment ledgers keep their UTC `entry_date`: they are balances, not day reports.
- **Effective-date / backfill policy (compared before deciding):** 0076 backfills existing rows with `DATE(sold_at)` / `DATE(paid_at)` — the UTC calendar date every past report used. Proved on the copy: 0 rows where the stored date differs from the old keying, `daily_rollups` and the one existing closing byte-identical before and after. The rule applies to records written after 0076 is applied (live: `2026-09-23T07:14:50Z`). Nothing historical is reassigned; a later correction of a stored business date is an audited Owner act that does not exist yet (owed).
- **Supersedes:** "Period boundaries are UTC; there is no timezone feature" (Money & reports, 2026-09-1x, and `lib/home-metrics.ts`) — the UTC month-to-date remains only as the client's fallback while the server's business date loads. Rule 26a's `paid_at` keying becomes `payments.business_date`.

### ✅ IMPLEMENTED — a close is a counted snapshot and a history event; the same business day reopens (backend `29b9cc7`)

- `daily_closings.status` gains `reopened`; `first_closed_at` / `first_closed_by_id` are written once and never move; `reopened_at` / `reopened_by_id` / `reopen_count`; `closing_channel_counts.opening_balance` (cash only); a new `closing_events` table (`count_saved`, `closed`, `reopened`, `auto_reopened`, `reclosed`, `day_started_early`, with the frozen snapshot in `payload` and a stable `dedupe_key`).
- **Reopen** (`POST /closings/reopen`, `closing.perform`): only the current business date; `locked → reopened`; a fresh count of every channel is required before the **reclose** (`POST /closings` on a reopened day, `fresh_count_required` otherwise); the reclose event distinguishes the movement since the first count from the revised whole-day total. Discrepancies: undecided ones follow the new figure or close as "no difference remains"; decided ones stay and a remainder opens a new one.
- **A sale after the close reopens the day inside the sale's own transaction** (`autoReopenTx`, audited `auto_reopened_by_sale`); a debt payment on the current business day does the same; a payment back-dated into an earlier locked day is still refused. Expenses, corrections and returns keep their refusals on a locked day — they confirm once the day is open again.
- **Cash carries forward:** the opening balance of a business day is the counted cash at the last locked close plus the net cash movement of any unclosed day between; a shop that never locked a day starts from zero, so the first close anchors the chain. Accounts keep rule 26a: recorded movement, never a balance. The reconciliation equation gains this one term (`reconciliation.spec.ts` pins six terms and the five signed components).
- **06:00:** the next request computes the next date; no scheduler. A day behind the boundary that is not locked reads **Needs review**; a locked one is final (`reopen_past_day`).
- **The Owner's early start** (`mode: 'start_new'`, `closing.start_early`, Owner only, only between local midnight and 06:00): a `day_started_early` event for the next date; sales from that instant carry the new date; the closed day stays closed; a second election changes nothing; at 06:00 nothing starts twice; the election is per branch (the Warehouse stayed on the 23rd while Main Store had moved).
- **Supersedes:** rule 25 "closed once" and Milestone E's "a locked day stays locked… never by reopening" — for the same business day only; after the boundary the append-only correction workflow is still the only way.

### ✅ APPROVED — closing authority is the Owner plus two named delegates per branch (backend `003efb2`, mobile ``8230802``)

- `closing.perform` is delegatable (`PUT/DELETE /users/:userId/branches/:branchId/delegations/closing`) to a **Store Manager or Store Employee** assignment, **at most two per branch** (`CLOSING_DELEGATES_MAX`, 409 `closing_delegates_limit` on a third); revoking frees the seat. The Store Manager role no longer holds `closing.perform` (43 → 42 keys; 0076 revokes the mapping on existing databases). `closing.count` is unchanged for every store role. New Owner-only key `closing.start_early` (catalogue 62 → 63; the administrator does not get it). A role change prunes only the delegated keys the new role may not hold.
- Team → a person → **Closing delegates**: one switch per eligible branch, the limit stated beside it, the server's 409 worded.
- **Supersedes:** Milestone E's "a Manager holds `closing.perform`".

### ✅ APPROVED — the Owner is told after a counted close changes (backend `29b9cc7`)

`closing.reopened`, `closing.sale` (each sale completed while the day is open again) and `closing.reclosed`: an in-app notification to every active Owner first, under the event's stable dedupe key (a retry meets the unique index and sends nothing again), then WhatsApp through the existing `WHATSAPP_CHANNEL` boundary with the same key as idempotency reference, in the Owner's `whatsappLanguage`, amounts only when `whatsappIncludeAmounts`. The variables carry the branch, the local time and the business date; a sale carries its item and value with collected and owed shown apart; a full identifier or a cost is refused by construction (`assertNoticeSafe`). Delivery runs after commit and never throws into the sale or the close. Three templates are registered with `providerTemplateName: null` — no provider exists (Stage 4B); on live no user has a phone number, so nothing can be sent there. **Supersedes** rule 36's "summary only".

### ✅ IMPLEMENTED — Home, the ranking and the Stock deep-link (backend `a8fc4fe`, mobile ``40c73d0``, ``8230802``, ``944459e``, ``57deb64``)

- `GET /home?period=today|week|month` (no route permission; sections gated inside by the caller's permissions): exact business-date range; sales value by sale date, collected (money received on those dates, later debt included), expenses (confirmed, keyed as the rollup keys them), still owed with its scope (`these_sales`); hourly / seven daily / weeks-of-the-month bars cut from the same rows, so `barsSumTo` holds by construction and is asserted on every read; the top partner; the three latest phones received (masked to four digits — the full identifier never travels); the closing card with yesterday's standing. Replaces the unused old `/home` (`/dashboard` keeps the old snapshot as `snapshot()`).
- `GET /partners/ranking?page&limit` (`consignment.view`): a completed trade is a **settled consignment from this branch** (its raised receivable) or a **fully paid sale whose debtor is a partner store** — disjoint, nothing counted twice, scoped by tenant; ordered value, count, name, id. The outright sale of a phone to another store stays the documented contract gap and is not approximated.
- `GET /inventory?trackingType=imei`: units of one tracking type; ordering unchanged (`id desc`, intake order) so Home's three arrivals and the Stock list agree.
- Mobile: the ranking’s "refreshed" footer counts from the phone’s own receipt of the data, as Home does — the matrix’s fake clock showed the server-stamped version reading "in 21 hours" (`57deb64`). Home rebuilt on the one read (period control, the four figures, the bars as plain views, the three cards, an honest "refreshed" footer, offline said outright); `/partners/ranking`; Stock preselects Phones + All statuses + "Newest received first" from the deep-link; Closing & history at `/closing` with the counting screen moved to `/closing/count`; the before-06:00 sheet; Money and Results ask the server which business day it is (`usePeriodRange`). Pending work (transfers, returns, refunds) stays on Home when there is any.

### 🟡 CONTRACT GAPS AND OWED

- Selling a phone outright to another store: unchanged (see the Partners entry above).
- Correcting a stored business date after the fact: an audited Owner act, not built.
- A provider adapter for WhatsApp: not built, not faked; the three templates await approved copy.
- The counting screen's own "Since last count" figure: shown on Closing & history, not on the counting rows.

### 📋 VERIFICATION

- **Backend:** tsc clean · `nest build` clean · `prisma validate` · full suite **150 suites / 2 653 tests, 0 failed** (new: `business-day.spec` 11, `closing-lifecycle.spec` 11, `closing-notices.spec` 6, `closing-notice.service.spec` 4, `home-series.spec` 5, `closing-routes.spec` 7; the specs that pinned the UTC keying and the manager's closing rewritten to pin 0076).
- **Database:** backup `phonestore-before-0076-20260923-063747.sql` (864 179 B, hex-blob, trailer present, 0 raw binary) → restore-proved into `prisma_verify_home` (89 tables / 24 triggers; sales, units, payments and audit counts and the `units` checksum equal) → 0076 forward there (`migrate status` up to date) → backfill equal to the old keying on every row → live.
- **Live lifecycle on the copy** (`home-lifecycle.mjs`, the built API on a fake clock per phase, development-log WhatsApp channel): **57/57** — six phones received; Home's three arrivals = Stock's first three; a cash sale and a partial sale; Home today 20 000 / 16 000 / 4 000 with the hourly bars summing and both sales in the 14:00 bar of a day that starts at 06:00; an expense confirmed; expected cash 15 500 with opening 0; two delegates named, a third refused, a manager refused by role, the delegate's authority in Main Store only; the delegate counts and closes (first close, no difference); a duplicate close refused; reopen by a manager refused, by the delegate allowed (`Reopened · review due`, first snapshot kept, history close → reopen, every Owner told once, the dev channel carried it); reopening an open day refused; the early start refused at 14:00; a sale while reopened in the history and told to the Owner without an identifier; a close with the stale count refused; two concurrent recloses — one wins, one conflicts; the reclose separates 1 sale / 10 000 since the first count from the whole day (25 500); the row keeps its first close; a seller's sale after the reclose reopens the day automatically, audited, told; the Owner's third close (35 500, 2 sales since the first count); no Owner told twice; the ranking honest and empty; Home's week bars summing to 40 000, no top boutique claimed; a seller's Home without figures; another company's branch refused to an Owner — then at 03:00 the next day: still the 23rd, the early start offered to the Owner alone, refused to a delegate, taken once (the 23rd stays closed, one event, a second election a no-op), a sale on the early-started 24th, yesterday's balance collected today (payment dated the 24th, the 23rd's figures unchanged), the new day opening on 35 500 carried forward (49 500 expected); a revoked delegate can count but not reopen; no crossing into the Warehouse; the freed seat given to somebody else — then 05:59:30 (Main Store on the 24th, the Warehouse still on the 23rd) and 06:00:30 (both on the 24th, the early-started day not started twice, the Warehouse's 23rd needing review, a reopen of the 23rd refused as behind the boundary, a sale at 06:00:30 on the 24th, the month bars summing) — then 02:00 on 1 October (business day 30 September) and 05:30 on 1 January 2027 (business day 31 December, a 7-day range across the year).
- **Mobile:** tsc clean · `expo lint` 0 errors (0 warnings in this scope's files) · Expo Doctor the same four pre-existing mismatches · **69 pure suites pass** (new `home-day.test.ts` 9; `layout`, `registry`, `stock-screen`, `closing-screen`, the design audits updated) · parity **2 897** keys, identical order, 0 duplicates · web export with every route.
- **Render matrix** (`home-matrix.mjs`, the export against the copy on a fake clock, headless Chrome at 3×): **48 captures** — Home EN/FR/AR × light/dark at 393, 320/360/430, 130 % text, Today and This month, AR dark 320, a seller's Home; the Stock deep-link EN/AR/FR-dark-360; the ranking with two real partner stores (the Test Store connected through the product’s own request-and-accept path, then three credit sales settled in full; one settled sale row for a manual store written by SQL on the copy) EN/FR/AR + dark 320; Team's closing delegates EN/AR; Closing & history open → closed (EN/AR) → reopened with a sale in the history (EN/FR/AR, dark 320, 130 %), a delegate's view, the counting screen; then at 03:00 the closed day and the reopen sheet (EN/FR/AR, dark, 320) — 0 leaked keys, 0 sideways overflow, 0 empty screens. The first run's three ranking captures were empty: the fixture's connection request met a non-discoverable Test Store (the 404 the product gives by design) and a third trade priced below the set price was refused; the rerun connects through the product's own request-and-accept path and prices at or above the set price. The one defect the matrix exposed — the ranking footer formatting the server's timestamp, which read "in 21 hours" under the fake clock — is fixed in `57deb64`. Web renders, not device verification.
- **Physical device: not run** — `docs/24` §37 (H1–H8, C1–C11).
## The physical opening, the date selector and three corrections (2026-09-24)

Audit, contract and plan: [`docs/50` §6](50_AUDIT_HOME_BUSINESS_DAY_CLOSING.md). Backend `3fa4801`, mobile `904e3ac`, migration **0077**.

### ✅ APPROVED — the boutique's opening is a recorded act, never an inference (backend `3fa4801`, mobile `904e3ac`)

- **Rule 25a.** `closing_events.kind` gains `opened` (0077: one enum value, no backfill). `POST /closings/open` (`closing.count`) records the physical opening with its instant and its actor; the day's card reads *Opened today · date · time* and its timeline gains *Boutique opened · time · by name*. **The 06:00 cutoff starts a reporting date and never creates an opening event.** A day nobody recorded reads *No opening time recorded*; its first non-reversed sale is *First activity*, never *Opened*. Opening a closed day is the reopen of rule 25 (the closing authority) and reads *Reopened today*.
- Only the current business date can be opened, never twice while it is open (409 `open_already_open`), never a closed day (409 `open_day_closed`), never a past or future date. Two taps at once meet one dedupe key; the second changes nothing. The view carries `door`, `opening`, `canOpen`, `openRefusal`.
- **Supersedes** nothing: rule 24a's boundary is unchanged; this adds the act the boundary never was.

### ✅ IMPLEMENTED — Closing & history opens any business date (backend `3fa4801`, mobile `904e3ac`)

- The selector (Today · Yesterday · Choose a date, the last sixty days in a sheet) drives the existing `GET /closings/open/view?date=`. Every timeline row carries `localDate` and `localTime` in the company's zone and the actor; the view carries `localNow` and `lastCountedLocalTime`, so the phone formats no instant of this screen in its own zone.
- The timeline now holds the first sale as `first_activity`; a day closed before 0076 has its closing row and channel counts read back as `closed` / `count_saved` rows (`payload.fromRow: true`); every earlier snapshot stays. A past date with no closing row reads *Needs review*, not *Open*. A past day offers no action.
- **Rule 27** records the selector.

### ✅ IMPLEMENTED — three corrections (mobile `904e3ac`)

- **The reopen sheet's clock is the server's**: its title shows `localNow`; its choices were already the server's, so at 07:25 by the store's clock the early start is never offered, whatever the phone's clock says (the first render matrix had shown "Reopen at 07:25" above a 03:00 choice under its fake clock — a display fault, now closed).
- **"Still owed"'s scope line wraps** at 320 pt instead of being cut.
- **The Stock list reached from "Latest phones received" masks** every identifier to `•••• 5930`, as Home does; the full identifier still opens the unit. *Deviation kept, recorded:* rule 19d asks every stock list to mask; the Stock tab's own list still shows full identifiers, as before this brief — the brief asked for the list reached from Home.

### 🟡 OWED

- Masking on the Stock tab's own list (rule 19d), if the Owner wants it there too.
- Days older than sixty in the selector: readable through the route, not through the sheet.

### 📋 VERIFICATION

- **Backend:** tsc clean · `nest build` clean · `prisma validate` · full suite **150 suites / 2 658 tests, 0 failed** (new: the door rules in `closing-lifecycle.spec`, `localTimeOf`, the open route's permission).
- **Database:** backup `phonestore-before-0077-20260924-034205.sql` (868 828 B, hex-blob, trailer present, 0 raw binary) → restore-proved into `prisma_verify_home` (90 tables / 24 triggers; sales, units, payments and audit counts and the `units` checksum equal) → 0077 forward there → live at `2026-09-24T03:56:36Z` (`migrate status` up to date; live rows unchanged: 9 sales / 53 units / 865 audit rows / 9 payments / 1 closing / 6 rollups / 63 permissions / 0 closing events; 90 tables / 24 triggers; latest migration 0077_physical_opening).
- **Live lifecycle on the copy** (`open-lifecycle.mjs`, the built API on a fake clock per phase): **29 steps, 0 failed** — at 07:25 no opening recorded and no early start offered even to the Owner; a warehouse employee (no `closing.count`) and another company's Owner refused; the seller opens at 07:25 (event, actor, store time, audit row); a second opening refused; the first sale is *First activity* after the opening; the Owner counts and closes (door closed, the opening line kept, "open" refused as *day closed*); the seller cannot reopen; the Owner reopens (*Reopened today*), a second explicit opening refused; a reclose and a second reopen on the same date (opened 1, closed 1, reclosed 1, reopened 2, every snapshot kept, rows in time order); 15 days ago: nothing recorded, *Needs review*, cannot be opened; 2026-09-22: *First activity* with its seller; 2026-09-15: the pre-0076 counts read back with the person and the time; past and future dates refused; 05:59:30 still the 24th (the store clock 05:59, the early start offered) and an opening then refused by name as the 24th's; 06:00:30 the 25th with no opening recorded and no first activity; the seller opens at 06:00; yesterday from the selector needs review and can neither be opened nor reopened.
- **Mobile:** tsc clean · `expo lint` 0 errors (0 warnings in this scope's files) · **69 pure suites** pass (`home-day.test` 11) · parity **2 916** keys, identical order, 0 duplicates · web export.
- **Render matrix** (`open-matrix.mjs`, the export against the copy, headless Chrome at 3×): **26 captures** — the unopened day (a seller, the Owner in Arabic), the Owner's tap on *Open the boutique* at 07:25 and the opened card EN/FR/AR, dark 320, 130 % text; *Yesterday* EN/FR/AR; the date sheet EN/AR; a day 15 days ago (nothing recorded) and the busy 24th (opened, first activity, closed, reopened, closed again) at 393 and 320; Home 320 EN/FR/AR with the owed line whole; the masked Stock list EN/AR and FR dark 320; the closed day and the reopen sheet at 03:00 by the store's clock EN/AR/FR-320 — 0 leaked keys, 0 sideways overflow, 0 empty screens, 0 full identifiers on the masked list (the coarse check first flagged the three Stock captures because it had joined a demo product name's ten digits, the masked last four and a price across lines; re-captured with a per-line check: 0 findings; the read-back of a pre-0076 count was proved on the Test Store's own branch, the one place the copy holds such a row). Web renders, not device verification.
- **Physical device: not run** — `docs/24` §37 H9–H10 and C12–C16.

## The Daily closing report, closing without a physical check, and "Correct a transaction" (2026-09-24)

Audit, contract and decisions: [`docs/51`](51_AUDIT_DAILY_CLOSING_REPORT.md) (§1–§11 the verified audit, §12 the completeness pass, §13 decisions D1–D11). Backend `42bfd76`, `ff531dd`, `e352cf3`, `f4c3381`, mobile `8346398`, `7ed67bc`, `1e316e9`, migration **0078**. The user's brief of 2026-09-24 and the clarification the same day ("physical cash and account checks are optional; if someone closes without checking them, record them as unverified with an explicit acknowledgement and reason; never show them as matched or counted; keep the option to perform a real count") are the authorisation.

### ✅ IMPLEMENTED — the report is built from records, never re-entered (D1, D6, D7)

`GET /v1/closings/report?date=` (`closing.count`), one business date at the branch, stored business dates only, every total asserted against its lines on every read (`reportInvariants`; a close on a report that does not reconcile is refused, `409 report_integrity`):

```
Sales       value     = Σ sales.total                               (sales.business_date = D, not reversed)
            returns   = Σ return_reversals.net_refund_due            (approval_date = D) — their own line
            collected = Σ payments on D's sales with payments.business_date ≤ D   (at the till · later the same day)
            owed      = value − collected                            (as it stood at the end of D)
Money       per channel (cash, each account, unattributed), one channel builder (channels.ts):
            in  = payments dated D (split: D's sales | older debts, on the sale's business date) + corrections in
            out = confirmed refunds + stock paid (purchases, settlements) + confirmed expenses + corrections out
            net = in − out;  pending refund / expense REPORTS are warnings, never movement
Expenses    confirmed; variable on its confirmation date, fixed on its due date (Milestone D) — never a refund, never stock
Result      net sales            = value − returns.net_refund_due
            cost of items sold   = Σ sales.total_cost − Σ return line_cost      (the recorded cost snapshot)
            gross profit         = net sales − cost of items sold
            result after expenses = gross profit − expenses recorded to D (fixed costs in full on their due date)
            any sold / returned line with cost ≤ 0.005 → "Cannot calculate yet" (count), every profit field null
Expected    drawer   = opening + cash in − cash out;  opening = counted cash at the last locked close whose
                       drawer was COUNTED + the cash movement of every day since (D4)
            account  = recorded movement (in − out) — "not the balance, not confirmed with the provider"
```

Sections are built per caller, never stripped afterwards: money and expected balances `closing.count`; sales and expenses `report.view` or `closing.perform`; the result additionally `cost.view` (the result keys are also in the interceptor list). A locked day is shown as the report stored with its latest close (`source: snapshot`), with a warning if its live figures have moved since. The close broadcast and the closing timeline carry no figures beyond what `closing.count` shows (§12.1–2: the timeline had been returning the stored `netProfit`).

### ✅ APPROVED — a physical check is optional; an unchecked balance is recorded as not verified (D2, D3, D4, D5)

- **Supersedes** Milestone E's "every countable channel is counted or skipped with a reason" and 0076's "a reclose needs a fresh count of every channel".
- `POST /v1/closings` `{date, clientUuid, reportVersion, acknowledgeUnverified, reason}` (`closing.perform`). A channel counted after any reopen is closed as **counted** (its difference and discrepancy as before). Every other countable channel is closed **not verified**: `is_skipped = 1`, `skip_reason = 'NOT_VERIFIED_AT_CLOSE'`, `counted = NULL` — never a zero, never the expected figure, never "matched". Closing with any unverified channel requires `acknowledgeUnverified: true` **and** a reason, both stored in the close's event and the audit row; without them `400 acknowledgement_required` naming the channels. A count from before a reopen is stale and never reused.
- Migration **0078**: `daily_closings.counted_cash` and `difference` NULL-able together (`ck_closings_counted_pair`); `NULL` = the drawer was not verified at that close. The opening drawer anchors only on a **counted** close (D4).
- Discrepancies: a channel not checked at a close answers nothing — an earlier question stays as it was; a counted one is reconciled against the sum of decided rows, so repeated recloses never count one shortage twice.
- **Idempotent**: the same `clientUuid` replays the close (also when two taps race); a different key on a closed day is `409 already_closed`. **Bound to what was seen**: a close whose `reportVersion` no longer matches is `409 report_changed`, and the close re-reads a movement fingerprint inside its transaction after locking the day's closing row — the row every sale's auto-reopen and every correction approval now also lock — so money landing mid-close is either in the snapshot or refuses the close; never lost in a locked day.
- Every close stores its whole report in its event; a reopen, a recount or a correction never changes an earlier record.

### ✅ IMPLEMENTED — "Correct a transaction" (D9)

`GET /v1/closings/sources?date=` lists the date's payments, confirmed refunds, expenses, stock payments and corrections with time, amount, channel, status and either the existing flow (the return's correction, the expense, the sale) or a named refusal. One new narrow contract, inside the existing Milestone B workflow: **move all or part of a payment to the channel it really reached** — `financial_corrections.target_kind = 'sale_payment'` with its destination (0078), `POST /v1/corrections/preview` (nothing written), request with a mandatory reason, Owner approval (the request and the approval are recorded apart even when one person does both), at most one approved correction per payment, posted to the current open day, the payment row and every earlier close untouched, an audit row with the source payment and before/after. The money leaves one channel (`corrections_out`, 0078) and enters the other; totals do not change. Approval is now one transaction that locks the day's closing row. **Refused and owed:** reversing a payment that was never received, correcting a confirmed expense or a purchase payment, editing a sale.

### ✅ APPROVED — an inactive past day is not an overdue closing (D8)

**Supersedes** the 2026-09-24 decision "a past date with no closing row reads Needs review". A past day with no closing row reads **No activity recorded** when nothing at all was recorded on it (EXISTS over closing rows and events, sales, payments dated there, return approvals, confirmed refunds, stock payments, supplier settlements, confirmed expenses under their date key, approved corrections); with real activity it still reads **Needs review**. One rule for Closing & history, the report, the previous-day notice and Home.

### ✅ APPROVED — closing authority is literally the Owner and at most two delegates (§12.5)

`closing.perform` revoked from `administrator` and `branch_manager` (0078; no live user held either role). Granting a delegate now locks the branch row, so three simultaneous grants leave exactly two. The report's close action, the Home entry (which only opens the report) and `POST /closings` all rest on the same key; reading the report confers nothing.

### ✅ IMPLEMENTED — late money on a closed day (D10) and two consistency fixes found by the lifecycle

- A purchase paid on a closed current day reopens it, as a sale does. Confirming a fixed expense due on a closed day is refused, as a variable one already was.
- **Found by the real-database lifecycle:** two recomputes of the same branch-day at once (a close and a correction approval, or two taps) interleaved the rollup's delete-then-insert and failed with a unique-key error *after* the correction had committed — the phone was told it failed. The recompute now runs one at a time per branch-day, and the headline rollup row retries once on a concurrent insert.

### 📱 Mobile (`8346398`, `7ed67bc`, `1e316e9`)

Closing & history becomes the **Daily closing**: date selector, status and the recorded opening, "Last updated" / offline / stale said plainly, the headline figure, a compact warning list, the five sections with expandable detail, **Review and close** (the final figures, the unverified balances, the acknowledgement and the reason; confirm disabled only for stale/offline figures or a missing acknowledgement — never for a missing count), **Check physical cash or account balance** (the old counting screen, now optional: no phone totals, no "0 of 2 counted", recount a saved or stale count, the account asked for its movement not its balance), **Correct a transaction**, and the history. The report scrolls in its own `ScrollView` with nothing above the rows. 149 catalogue keys EN/FR/AR (parity 3 065).

### 🟡 OWED

- Reversing a payment that was never received; correcting a confirmed expense or a purchase payment; editing a sale (the refusals say so).
- Loans, consignment and employee-debt cash are outside the report, as they are outside the closing (their ledgers use UTC dates).
- Rollup revenue, the digest and Results still leave out the whole-sale discount; the report reads `sales.total` and is internally consistent (`docs/51` §3.1).
- Expense and refund confirmations still check the day's lock without taking the closing row's lock.

### 📋 VERIFICATION

- **Backend:** tsc · `nest build` · `prisma validate` · full suite **151 suites / 2 696 tests, 0 failed** (new: `closing-report.spec` 22 — a worked day recomputed independently, gating, missing cost, verification, version; the lifecycle, reconciliation, channel, route, correction and role-drift specs extended).
- **Database:** backup `phonestore-before-0078-20260924-082406.sql` (869 033 B, hex-blob, trailer present, 0 raw binary; taken minutes before the live migration — an identical 07:42 backup was restore-proved too and kept) → restore-proved (90 tables / 24 triggers, counts and the `units` checksum equal) → 0078 on the copy → lifecycle → live at `2026-09-24T08:24:43Z` (9 sales · 53 units · 865 audit rows · 9 payments · 1 closing · 6 rollups · 0 corrections · 63 permissions; 90 tables / 24 triggers; latest 0078, `migrate status` up to date).
- **Real-MySQL lifecycle on the copy** (`report-lifecycle.mjs`, the built API, fake clock): **45/45** — the worked day (split tender, part-paid sale and its later payment, an older debt, a variable and a fixed expense, stock paid in cash, a Bankily sale) with every section recomputed independently and against SQL; "Correct a transaction" listing the day's six payments, two expenses and the stock payment, and refused to the seller; the seller and a manager without cost.view; refusals for non-delegates; the stale-version refusal; a counted drawer with a −500 difference; the close with two accounts not verified; double tap and a second key; the stored report and reason; a sale after the close; the reclose without recount; the payment reclassification refused on a closed day then approved; one per payment; the audit; a correction racing a close; two taps racing; 05:59:30 vs 06:00:30; the carried opening; inactive vs needs review; missing cost; a purchase reopening a closed day; a fixed expense refused on a closed day; company isolation; three delegations at once.
- **Mobile:** tsc · lint 0 errors / 0 warnings in this scope · **70 pure suites** (new `closing-report-view.test`) · parity 3 065 · web export.
- **Render checks, no pictures** (`report-checks.mjs`): 28 views — the report, Review and close, the physical check and "Correct a transaction" with its move sheet, in EN/FR/AR, light and dark, 320 and 393 pt, 130 % text, a seller, a manager without cost.view and the Owner — 0 problems after fixing the three the checks found: the sources list read a column that does not exist (`supplier_payments.created_at`, now `paid_at`); "Check physical cash or account balance" was cut at 320 pt as a one-line button (the two secondary paths are now wrapping rows); a refusal was cut in an Arabic correction row (it now has its own line). Web renders, not device verification.
- **Physical device: not run** — `docs/24` §38 R1–R14.

## Closing delegates verified, and the correction path for sales, payments, expenses and purchases (2026-09-25)

Plan, decisions D12–D20 and risks: [`docs/51`](51_AUDIT_DAILY_CLOSING_REPORT.md) §15. Backend `2b7ba08`, `2c98658`, `b091286`; mobile `a9b9226`, `9130a9c`; migration **0079**. The user's follow-up of 2026-09-25 is the authorisation: stay on the Daily closing scope with no workflow; verify that the Owner can delegate closing to up to two employees who can close and reclose while other employees cannot; complete the correction path for erroneous sales, payments, expenses and purchases as authorised reversals or adjustments with a required reason and a permanent audit history, never overwriting a confirmed record or an earlier closing snapshot; name any action left unavailable and why.

### ✅ VERIFIED — closing authority is the Owner and at most two named delegates per branch

Nothing had removed delegation. 0078 took `closing.perform` away from two **roles** (`administrator`, the retired `branch_manager`); the per-branch delegation of 0076 stayed exactly as it was. The 0078 wording "held by the Owner role only" was about roles and read as "Owner-only"; rule 28a in `docs/04` now says it plainly. Proved on a real database (`delegation-lifecycle.mjs`, **24/24**): an employee and a manager named; a third and a fourth refused; both delegates' permissions, the report's close verdict and the server route agree; the employee closes, the manager recloses after a later sale, the employee reopens and recloses; other employees are refused the close, the reclose and the reopen; the delegation holds at its own branch only; a delegate can neither name another delegate nor approve a correction; a withdrawn delegate is refused again and the place can go to another employee; every naming and withdrawal is audited.

### ✅ IMPLEMENTED — every record can be corrected, never edited (D12–D17)

| Record wrong | Correction | What moves, on the current open day |
|---|---|---|
| A payment in the wrong channel, all or part | move (0078) | out of the recorded channel, into the real one |
| A payment never received, all or part | reverse | out of its channel; the customer or partner store owes it again (a walk-in sale: cancel the sale instead) |
| A sale that should not exist as recorded | cancel, whole | its value and recorded cost off the day's figures; phones back to stock (freed from sold-once), accessories back on the shelf; the money it still holds leaves the channels it is in; nothing owed on it |
| A confirmed expense, all or part | reverse | back into its channel; the day's expenses fall by it (not before the day it counts on) |
| A purchase paid from another channel, all or part | move | back into the recorded channel, out of the one that paid |
| A purchase that should not exist as recorded | cancel, whole | its phones leave the books (`voided`), its accessories leave stock at its cost (average undone), the money paid comes back; receiving the same IMEI again reactivates the same record |

**Contract.** `POST /v1/corrections` `{targetKind: sale_payment|sale|expense|supplier_payment|purchase|refund_payout|supplier_settlement, action?: reverse|reclassify|cancel, targetId, toMethod?, toAccountId?, amount?, reason, supportingReference?, clientUuid}` (`financial.correction.request`) — the record's own figures are never sent; a 0078 request naming a destination and no action is still a move. `POST /v1/corrections/preview` (same body, nothing written; a refusal comes back by name). `POST /v1/corrections/:id/approve|reject` (`financial.correction.approve`) unchanged: approval is one transaction that locks the day's closing row and the rows it changes, re-plans against what is there now, writes the legs and what follows (sale receivable caches, unit status with its own audit row, a line's release, stock), and audits before (the full preview) and after (the legs). `GET /v1/corrections/:id` gains `action` and `legs`. `GET /v1/closings/sources` rows carry `actions[]`, `open` and `refusal`, plus `pending[]` (with `superseded`) and `canApprove`. `GET /v1/sales/:id` gains `cancellation`; the sales list `cancelled`, `cancellationRequested`; `GET /v1/expenses/:id` gains `reversal`.

**Supersedes** `docs/51` D9's "refused and owed" list (reversing a payment never received, correcting a confirmed expense or a purchase payment) and its "sale void is not narrow" line.

### Formulas (0079 additions to the Daily closing report)

```
Sales     cancelled            = Σ sales.total of sales cancelled on D (correction_date = D, any sale date)
          net sales            = value − returns.net_refund_due − cancelled
          collected (D's sales) = Σ payments on D's sales dated ≤ D + Σ legs of those payments posted ≤ D (in − out)
          owed (D's sales)      = value − collected − value of D's own sales cancelled by the end of D
Result    cost of items sold   = Σ D's sales.total_cost − Σ return line_cost(D) − Σ cancelled sales' total_cost(D)
          cannot calculate     also when a cancelled sale's line had no recorded cost
Expenses  recorded             = Σ confirmed (as before)
          reversed             = Σ expense reversals approved on D;  total = recorded − reversed
          result after expenses = gross profit − total;  before fixed = gross profit − (variable − variable reversed)
Money     corrections in / out = Σ legs of corrections approved on D, per channel — one arm for every kind
Rollup    expenses = confirmed − reversed;  expenses_cash = confirmed cash (a reversal returns through its leg)
          net_profit = gross − returns effect − (cancelled_revenue − cancelled_cogs) − expenses
```

### ✅ IMPLEMENTED — found and fixed while verifying

- **0078 defect:** a close stored its report with the pre-close verification ("not counted"), while the closed day reads its unchecked balances back as "not verified" — every closed day with an unchecked balance warned "changed since close". The stored report now records them as the close left them.
- Two requests raced in for one record blocked each other's approval for ever; an open request now stops only a new request, and the one-approved-per-record key settles who wins (proved by forcing the race).
- A purchase row's payment id was sent as the purchase to cancel (render checks); a long payment row was cut in Arabic at 320 pt (render checks).

### 🟡 NOT AVAILABLE, BY NAME

Reversing a purchase payment as "not paid" — purchases are paid in full by rule and there is no supplier debt to carry it (Suppliers is out of the first release); cancel the purchase instead. Editing a sale line in place, or cancelling part of a sale — cancel it and sell again. A sale with a return — correct it on the return. A purchase whose goods have moved — correct the later record first. A branch's **units-sold** goal still counts a cancelled sale's items (no rollup column for it); revenue, profit and count goals and personal goals do not. Home's period figures count a sale on the day it was sold, as they count a sale later returned; the Daily closing and Results show the cancellation on its own day. The approval audit's `before` is now the full preview (`$.payment.method`, `$.move`, …) rather than 0078's flat fields.

### 📋 VERIFICATION

- **Backend:** tsc · `nest build` · `prisma validate` · full suite **153 suites / 2 758 tests, 0 failed** (new `correction-path.spec` 31, `correction-readers.spec` 11, the corrected day in `closing-report.spec` 8, reactivation in `purchase-dual-imei.spec` 6; the correction, rollup, goals and movement pins moved to the new design, none loosened).
- **Real-MySQL lifecycles on the copy** (built API, fake clock): `delegation-lifecycle` **24/24**; `corrections-lifecycle` **40/40** — every correction on a day recomputed independently in SQL (sales, cancellations, collected, owed, expenses, the drawer, the result, the rollup), a closed day's correction waiting then posting the next day with the stored close byte-identical, an older sale cancelled the next day, forced and natural double requests, a cancellation racing a close, company and branch isolation, the audit history, the phone's history, reactivation of a voided IMEI as the same record; the 0078 `report-lifecycle` **45/45** (three expectations moved to the new shape: `collected.corrections`, the audit's `before.payment`, the sources' actions).
- **Database:** backup `phonestore-before-0079-20260925-052300.sql` (870 568 B, trailer present, 0 raw binary) → restore-proved (90 tables / 24 triggers, counts and the `units` checksum equal) → 0079 rehearsed on that exact copy → live at `2026-09-25T05:23:45Z` (91 tables / 26 triggers; 9 sales · 53 units · 865 audit rows · 9 payments · 1 closing · 6 rollups · 0 corrections · 63 permissions; `units` checksum unchanged).
- **Mobile:** tsc · `expo lint` 0 errors (no warning in a changed file) · **70 pure suites** · parity **3 161** (116 keys added, 20 retired) · web export.
- **Render checks, no pictures:** `corrections-checks.mjs` **38 views** (every correction sheet, the Owner's decision, the report's new lines, the cancelled sale and reversed expense, two real submissions through the screens) and the 0078 checks re-run **25 views** — EN/FR/AR, light and dark, 320 and 393 pt, 130 % text — **0 problems** after the two fixes above. Web renders, not device verification.
- **Physical device: not run** — `docs/24` §39 K1–K14 (and §38).

## A cancellation in its own period: the units-sold goal, Home, the Daily closing and Results (2026-09-25)

Plan, decisions D21–D24, formulas and risks: [`docs/51`](51_AUDIT_DAILY_CLOSING_REPORT.md) §16. Backend `ceba0ed`, `cdbf404`; mobile `8cd38ff`, `40a9b2f`; migration **0080**. The user's brief, Daily closing scope, no workflow, no pictures: fix the units-sold goal so a cancelled sale's units are reversed in the appropriate reporting period; verify that Home shows both the original sale and its later cancellation accurately and that the totals across both dates reconcile with the Daily closing and Results; keep earlier closing snapshots immutable; focused tests for a sale cancelled the same day and on a later business day, with expected and actual figures; leave the 388 340 repair untouched.

### ✅ IMPLEMENTED — one rule for every reader (D21)

A cancelled sale counts in the period it was sold — that day's Daily closing shows it and never changes — and comes off in the period its cancellation was approved. Same day: it nets to nothing that day. Sold one day, cancelled the next: the first day keeps it, the second loses it (a period holding only the cancellation reads below zero), and the two together net to nothing.

- **Units-sold goal:** `daily_rollups.cancelled_qty` (0080), written by the rollup on the correction day and subtracted by the goal, as revenue, count and profit already were. **Personal goals** now follow the same rule on the stored business date (they used to drop the cancelled lines from the sale's own period, keyed on the UTC calendar date — rewriting a period already shown). Supersedes `docs/51` D18's "cancelled sales leave … goal progress".
- **Home:** `figures.cancellations {count, value, phones}` for the range, keyed on the approval day; the sales value and its bars keep each sale on its own day. The phone shows **Sales cancelled in this period (n)** with the value taken off, under the sales value. Collected stays the money that arrived (as Results' collected); money given back is the Daily closing's "corrections out".
- **Daily closing:** `sales.cancellations.items`; the line reads **Sales cancelled (1 · 3 items)**.
- **Results (phone):** a **Cancelled sales** line and **Net sales** — the breakdown adds up again (it had shown Sales − Returns = "Sales after returns" while the server's figure also subtracted cancellations); a period holding only a cancellation or a return is no longer "No sales or expenses".

**Contract.** `GET /v1/home` → `figures.cancellations: { count, value, phones }`. `GET /v1/closings/report` → `sales.cancellations.items`. Goals' responses unchanged in shape (achieved may be negative in a period holding only a cancellation).

### 📋 VERIFICATION — expected (written before the run) and actual

Sale **S**: a phone 10 000 (cost 6 000) + 2 cables × 20 (cost 5.00) = 10 040, cost 6 010, 3 units. Sale **T**: a phone 10 000, cost 6 000, 1 unit. Both by the seller, cash. `cancellation-lifecycle.mjs` on a restore-proved copy through the built API: **31/31 steps, 106/106 figures as expected**; raw SQL agreed on every day.

| Scenario | Reader | Expected = actual |
|---|---|---|
| **Same day** (2026-10-06) | Daily closing | value 20 040 · 2 sales · 4 items · cancelled 1 / 10 040 / 3 items · net 10 000 · collected 10 000 · owed 0 · cost 6 000 · gross profit 4 000 |
| | Home, Today | before the cancellation: 20 040, none cancelled; after: 20 040 and **cancelled 1 · 10 040 · 1 phone** (20 040 − 10 040 = 10 000) |
| | Results | sales 20 040 · cancelled 10 040 · net 10 000 · net cost 6 000 · gross profit 4 000 |
| | Goals | **units 1** (branch and the seller's) · revenue 10 000 · sales 1 · gross profit 4 000 |
| **Later day** (sold 2026-11-09 and closed; cancelled 2026-11-10) | Daily closing D1 (closed) | value 20 040 · 4 items · no cancellation · net 20 040 · gross profit 8 030 — **stored close event, closing row, rollup row and report version byte-identical after the cancellation; no "changed since close"** |
| | Daily closing D2 | value 0 · cancelled 1 / 10 040 / 3 items · net −10 040 · cost −6 010 · gross profit −4 030 · 10 040 out of the drawer as a correction |
| | Home | D1 Today: 20 040, none cancelled · D2 Today: 0 and cancelled 1 · 10 040 · D2 7 days: 20 040 and cancelled 10 040 |
| | Results | D1: 20 040 / 0 / 20 040 / GP 8 030 · D2: 0 / 10 040 / −10 040 / GP −4 030 · both: 20 040 / 10 040 / **10 000** / GP **4 000** |
| | Units-sold goal | branch: **D1 4 · D2 −3 · both 1 · November 1**; the seller's: D1 4 · D2 −3 · both 1. Before the fix: branch D1 4 · D2 0 · both 4; the seller's D1 fell to 1 once the sale was cancelled (its own period rewritten) |
| | Other goals, both days | revenue 10 000 · sales 1 · gross profit 4 000 |
| **Both scenarios** | reconciliation | over the two dates Home (value − cancelled) = Σ Daily closing net = Results net = revenue goal = **10 000**; units goal = Σ closing (items − cancelled items) = **1**; gross profit 4 000 everywhere; the later-day scenario ends where the same-day one does |

- **Backend:** tsc · build · `prisma validate` · full suite **154 suites / 2 771 tests** (new `cancellation-periods.spec` 13: both scenarios through the goal's own SQL expression, `profit()` and `assembleReport()`, plus source pins; it fails 4 tests against the old units rule). The 0079 lifecycles re-run on the new code: corrections **40/40**, report **45/45**.
- **Mobile:** tsc · `expo lint` 0 errors (33 warnings, all pre-existing) · **70 pure suites** (`layout.test`: both scenarios' breakdowns add up; the Home line) · parity **3 163**.
- **Render checks, no pictures:** **35 views, 0 problems** — Home (7 days, Today), the Daily closing and Results (This month, Today) in EN/FR/AR, light and dark, 320 and 393 pt, 130 % text, and five views that can pass only with the right period's amounts. Web renders, not device verification.
- **Database:** backup `phonestore-before-0080-20260925-055659.sql` (878 859 B, trailer present, 0 raw binary) → restore-proved (91 tables / 26 triggers, counts and the `units` checksum equal) → 0080 rehearsed and re-run on that copy → live at `2026-09-25T06:12:46Z`; live unchanged (9 sales · 53 units · 865 audit rows · 9 payments · 1 closing · 6 rollups · 0 corrections · 63 permissions; `units` checksum unchanged). Live holds no stored close event, so no closed day reads differently.
- **Physical device: not run** — `docs/24` §40 L1–L6.

### 🟡 NOT CHANGED, BY NAME

- The **Money tab**'s period figures (sales value, phones sold) and the **Analytics** screen's best sellers and employee performance still count a cancelled sale on the day it was sold, with no cancellation line.
- Goals do not deduct **returns** (unchanged; revenue and units goals count a returned sale).
- Home's **expenses** are not net of 0079 expense reversals (the Daily closing's and Results' are).
- **Found while testing, not fixed:** the rollup queue runs inside the API process, fire-and-forget. If the API stops right after a sale, that day's rollup can miss the sale until the day is recomputed — Results and branch goals would then read low (the Daily closing and Home read the sales directly). Seen on the copy when the harness restarted the API immediately after a sale; the same family as the 388 340 overstatement (still untouched, awaiting approval).

## Daily totals reliability: durable recompute requests (2026-09-25)

Design, coverage, tests, the stale days, the repair procedure and its completion on 2026-09-25: [`docs/52`](52_DAILY_TOTALS_RELIABILITY.md). Backend `97695a8` (0081), `68c21e9` (the drift audit). The user's brief: make the recalculation request durable, so a committed sale cannot lose its update if the API stops or the recalculation fails; retry pending work on restart without counting a sale twice; check every transaction type that changes daily figures; test a shutdown or failure between the commit and the recalculation and verify that Results and goals recover; document the days that could still be stale with a separate, exact repair plan; do not apply the 388 340 repair or change live historical totals.

### ✅ IMPLEMENTED (D25–D28)

- **The request is written inside the business transaction** (`rollup_requests`, 0081): sale (its business day + branch), expense confirmation (the day it lands on), return approval, refund confirmation, correction approval (+ branch when goods moved), purchase received, transfer shipped/received (both ends). It commits with the change or not at all. Supersedes the in-memory `InProcessRollupQueue` and the awaited post-commit recomputes.
- **A worker drains it** after each commit, at start-up and every 30 s, under a 60 s lease, one recompute per branch-day; a failure waits with its cause and a capped backoff (5 s → 30 min) and is never abandoned.
- **Never counted twice**: the recompute rebuilds a branch-day from its records; working a request again writes the same figures; a request committed during a recompute stays for the next pass.
- **A committed return, refund or correction is no longer failed by its recompute** (it answered 500 before).

### 📋 VERIFICATION

- **Backend:** tsc · build · `prisma validate` · **155 suites / 2 791 tests** (new `rollup-outbox.spec` 12 — two mutations each caught; `rollup-requests-coverage.spec` 10).
- **Real database** (`rollup-durability.mjs`, restore-proved copy, built API, fake clock): **22/22** — every transaction type requested and worked; **failure** (every rollup write rejected): sales and a correction commit, requests wait, Results 0 and branch goals 0 during, then **20 000 / 10 000 cancelled / net 10 000, 1 unit** after the running API retries; **API killed mid-recompute**: request held under the lease, recovered at restart (10 000, 1 unit); **API stopped with a request pending**: recovered at the next start (20 000, 2 units); **all 23 requests worked again**: every rollup row byte-identical, Results over three days unchanged (60 000 sold, net 40 000).
- **Database:** backup `phonestore-before-0081-20260925-071413.sql` (879 111 B, trailer present, 0 raw binary) → restore-proved (91 / 26, counts and the `units` checksum equal) → 0081 rehearsed and re-run → live at `2026-09-25T07:32:20Z`; live read back unchanged (9 sales · 53 units · 865 audit rows · 9 payments · 1 closing · 6 rollups · 0 rollup requests; `units` and `daily_rollups` checksums unchanged — no historical total touched).

### ✅ STALE DAYS ON LIVE — REPAIRED 2026-09-25 (a separate approval, Main Store only)

**Found** by the read-only drift audit (production recompute on a copy, every column compared): **3 of 7 branch-days stale, none closed** — 2026-07-30 had **no rollup row** (9 051.00 revenue, 6 sales, 35 units, a 500.00 expense missing from Results and branch goals — **new**, invisible to the old audit), 2026-08-08 overstated by 40.00 and 2026-09-10 by 388 300.00 (the known 388 340). The exact repair — three `rollup_requests` rows worked by the API — was written in `docs/52` §5 and rehearsed on a copy (0 stale after); it was not part of the 0081 change.

**Repaired on live on 2026-09-25**, on the Owner's approval for the Main Store only, by the procedure of `docs/52` §5 (kept there as the record of how it was done), with nothing edited by hand and nothing beyond the three branch-days requested:

- **Backup before:** `phonestore-before-rollup-repair-20260925-075114.sql` (881 146 B) — restored identical to live on all 25 fingerprinted tables. **Drift before** on a fresh copy of it: exactly the three days above, same differences, none closed.
- **Requests:** inserted 07:52:36 UTC; worked by the running API (backend `68c21e9`, 0081) at 07:52:53 UTC, attempt 1, no error.
- **Before → after:** 2026-07-30 no row → revenue 9 051.00 · cost 6 232.80 · gross profit 2 818.20 · 6 sales · 35 units · expenses 500.00 · net 2 318.20; 2026-08-08 revenue 40.00 · cost 8.20 · 1 sale · 2 units · net 31.80 → all zero (its one product fact removed); 2026-09-10 revenue 388 300.00 · cost 60 000.00 · 6 sales · 6 units · net 328 300.00 → all zero.
- **Source records:** 22 tables, row counts and whole-row checksums identical before and after; only `daily_rollups` (6 → 7), `product_daily_rollups` (16 → 15) and `rollup_requests` (0 → 3) moved.
- **Backup after:** `phonestore-after-rollup-repair-20260925-075339.sql` (882 058 B) — restored identical to live. **Drift after** on a fresh copy of it: **0 stale**.
- **Results, Main Store, July–September 2026: 10 051 MRU** (389 340 before); per day 9 051 · 0 · 0.

### Still owed

Recovery after a crash mid-recompute takes up to ~90 s; `done` rows are not pruned; a request that keeps failing is visible only in the table and the log; one API process assumed (a second is safe by lease and retry). Supersedes the "found while testing, not fixed" rollup-queue note of the previous entry.

## Reporting consistency: one set of dated rules for Money, Home, Analytics and goals (2026-09-25)

Rules R1–R6, the audit, decisions D29–D35, the contract, every scenario's figures and what is left: [`docs/53`](53_REPORTING_CONSISTENCY.md). Backend `1a5105e`, `60fe7e3`, `c9be28e`, `b17be0c`, `c7bd82c`, `0a694a8`, `bf525b2`, `f380747`, `5acab28`; mobile `dd309fc`, `11f3d8d`, `2c22628`, `4cea1c8`, `5c1cb91`, `7ba2449`, `73fee6d`. **No migration.** The user's brief (reporting consistency only, no workflow, no pictures, the completed three-day repair not rerun): Money, Home, Analytics and goals use the Daily closing's and Results' dated rules; audit first; preserve original dates and closing snapshots; keep cost and profit gated; test cancellations, returns, reversals and refunds paid later; document what needs a product decision.

### ✅ APPROVED RULES, NOW EVERYWHERE

- **A sale** stays on its sale date; **its cancellation** is a separate negative adjustment on the approval date.
- **An approved return** changes revenue (by its **net refund due** — gross refund less the adjustments the shop keeps), profit and returned units on its approval date. **Its refund confirmation** moves money on its confirmation date, with no second profit effect.
- **A confirmed expense** stays on its accounting day (variable: confirmation date; fixed: due date); **a reversal** reduces expenses on its correction date and is shown apart, so a negative net reads as a reversal.
- **Sales count** = invoices less whole-sale cancellations; a returned item is a separate return event. **Units sold** = invoiced units less units on cancelled invoices; returned units are their own measure. The definition is stated on Money, Analytics, goals and the Daily closing.

### ✅ IMPLEMENTED (D29–D35)

- **One definition** (`period-figures.ts`) feeds Home, Money, sales by day, sellers and products; the rollup readers (Results, branch goals, branches) use the rollup's columns for the same facts.
- **Results** subtracts the net refund due (D30): a kept restocking fee stays revenue, as the Daily closing and the rollup's `net_profit` already had it.
- **Home:** returns on their own line; count and phones net; expenses net of reversals with the reversed part stated.
- **Money:** "Items sold" counted **phones only** (found while fixing it) — now units sold as defined; cancellations and returns apart; net sales; each day row is the day's net, and a day holding only an adjustment appears; today's expenses follow the accounting-day rule (a fixed expense on its due date) and list a reversal as its own negative row.
- **Analytics:** products and categories net of cancelled lines and returns, returned units apart; sellers by business date, net of their own cancellations and returns, returns counted apart; branches net. Exports and the seller-margin anomaly follow.
- **Goals:** returns come off branch and personal revenue and profit goals on their approval dates; a gross-profit goal is hidden from, and 404 for, a user without `cost.view`.
- **Cost gating:** Results' `comparison.netOperatingProfit` and its cost-side keys are now stripped without `cost.view`.
- **Snapshots:** no stored close, closing row or report version changes — the report's new `salesCount`/`unitsSold` sit outside the version; a closed day stayed byte-identical after a later cancellation.

### 📋 VERIFICATION

- **Isolated copy, built API, fake clock** (`reporting-lifecycle`): **59/59 steps, 53/53 screen checks with expected = actual** — same-day cancellation, later-day cancellation over a closed day (the cancellation day reads −10 000, −1 sale, −1 unit on every screen), partial return with a 500 fee kept and the refund paid two days later (Results over the three days: net 10 500, profit 4 500; the refund day moves money only), full return with a later refund, expense reversal on a day holding only it (Money's row "Transport, corrected" −300; Home −300; Daily closing and Results −300; 7 days 2 500), and cost gating on a day with rows. The figures per screen: `docs/53` §6.
- **Regression on the new build:** Daily closing lifecycle 45/45, corrections 40/40, cancellation 31/31 (106/106 figures, its three Home counts updated to the sales-count rule).
- **Backend:** tsc · **156 suites / 2 806 tests**. **Mobile:** tsc · **71 pure suites** · parity 3 180 · `expo lint` 0 errors (33 pre-existing warnings).
- **Database:** no migration, no backup needed; live untouched. The copy was dropped.
- **Physical device: not run** — `docs/24` §41.

### 🟡 NEEDS A PRODUCT DECISION (`docs/53` §4)

1. Should a return reduce **units sold** (and the units-sold goal)? Today it does not — returned units are apart, as the rule states.
2. A **whole-sale discount** would make line-based readers (Results, goals, branches, products) and invoice-based ones (Daily closing, Home, Money, sellers) disagree by the discount; live has none today.
3. The revenue goal's **"Money taken"** label now means net sales, not cash collected.
4. Analytics' **movement labels** ("sold in 30 days", "last sold", dead stock) still count a cancelled sale as movement.

Supersedes, in the previous entries' "not changed" lists: the Money tab and Analytics counting a cancelled sale on its sale day only; goals not deducting returns; Home's expenses gross of reversals.

## Home completed: a whole-invoice discount, the store's time, and the connected reporting checks (2026-09-25)

Findings, decisions D36–D41, the contract, every scenario's figures before and after, the links, the layout checks and what is left: [`docs/54`](54_HOME_COMPLETION.md). Backend `3c3f629`, `75cc60f`, `c6b1bba`, `a33f47e`, `416268b`, `da00ed2`, `9a1155a`; mobile `9969e2d`, `d2ffcea`, `8272b33`, `3b96d1a`, `056bb6e`. **No migration.** The user's brief (Home, its direct links and the reporting consistency just completed; no workflow, no pictures; the three-day repair not rerun), and, during it: Expo Go crashed on Home (`figures.returns.count` of undefined) — check whether the phone reaches the old API on 3010, update and restart it when safe, verify Home opens, and make an incompatible reply show an error instead of crashing or showing zeros.

### ✅ APPROVED BY THE USER, NOW IMPLEMENTED

- **The units-sold goal** = units on sales − units on whole-sale cancellations − approved returned units, each subtraction on its approval date. The sales count is unchanged: a returned item is not a cancelled invoice (D37). **No conflict with a binding decision** — the goals decision above (§7, "returns reduce progress") already said so; it supersedes `docs/53` R6 for this goal only.
- **The revenue goal is named "Net sales"** (EN/FR/AR), what it measures since `docs/53` D30.
- **Disagreements from a whole-invoice discount are fixed on the recorded invoice total** (D36): each line is worth its share of `sales.total` (in cents, rounding cent on the largest line). Results, branch goals, branches, the product and category reports, personal goals and the closing digest now agree with Home, its chart, Money and the Daily closing. **A returned line refunds its share** — it refunded the undiscounted price (10 000 for a phone paid 9 500); `docs/27`'s principle (the refund is what the rollup gave the line) is kept, its formula superseded.
- **Home's latest phones in the store's timezone**, "Today"/"Yesterday" included (D40); **a bare date is the same calendar day on every phone** (Home's range, the Daily closing and its history, the closing sheets, expenses and corrections were a day early west of UTC).
- **Home's sales block** (D41): Net sales under the gross value and its adjustment lines when a cancellation or return falls in the period (below zero on a day holding only one); the chart says it plots sales as invoiced; Collected says it includes older debts. Refresh asks only for what the person may read.
- **Analytics' movement labels** (D39): read from the sales that stand, when asked — a cancelled sale is left out wherever it falls (its goods never left), a returned item still counts as sold; the window is the last 30 business dates ending today (it ended at the last stock event). The rule is stated under "Not moving".
- **A server reply missing a figure is refused whole** (D38): Home, Money's overview and sales by day say "This screen needs an updated server" — no crash, no missing amount as zero, no retry.

### 📋 VERIFICATION

- **The crash:** the phone called `192.168.100.3:3010`, the user's API still running `backend/dist` from `68c21e9`. Restarted by PID on `5acab28` at 09:23Z, then on `9a1155a` after the commits (detached, log in OS temp); the new build's Home passes the app's check. Nothing written to live by this work; the user's two sales of the day (no discount) were rolled up by the running API.
- **Isolated copy** (store at UTC+4 on the copy only, built API, fake clock): `home-lifecycle` **42/42 steps, 37/37 screens expected = actual**; the same acts on the build before this phase recorded the "before" (`docs/54` §5.1) — Results 10 040 where Home said 9 040; a refund of 10 000 for a phone paid 9 500; the units goal 2 after a same-day return; "sold in 30 days" 2 weeks after the window moved on; the app refusing that build's Home instead of crashing.
- **Links and permissions:** ranking, Stock (the same three phones, masked on Home only) and the closing card agree with their screens; a store employee and a warehouse employee see no money — hidden, not zero.
- **Rendered and read, no pictures:** 35 views in EN/FR/AR, light/dark, 320/393 pt, 130 % text, including a server one version behind — 30 clean; 5 show only the French tab label "Partenaires" 2 points too wide at 320 pt (navigator inset, left for the phone). Fixed on the way: the counter buttons stack below ~360 pt; Arabic product names in Analytics keep their width.
- **Regression on the new build:** docs/53 lifecycle 59/59 (units goals updated to D37), Daily closing 45/45, corrections 40/40, cancellation 31/31. **Backend** 158 suites / 2 825 tests; **mobile** 73 pure suites, parity 3 187, lint 0 errors.
- **Physical phone: not run** — `docs/24` §42.

### 🟡 NOT CHANGED, BY NAME

The French tab label at 320 pt; `product_velocity` unused (drop later); the Catalogue's "Last sold" finds quantity lines only; the exports' movement headers unchanged. Supersedes `docs/53` §4's four open questions.

## Home/Money follow-up and the imported-stock review on the 100-phone workbook (2026-09-26)

Findings, decisions D42–D48, the measurements before and after, the checks and what is owed: [`docs/55`](55_HOME_MONEY_FOLLOWUP_AND_FILE_REVIEW.md). Mobile ``6ca8ab1` (the tab label), `99c5b69` (i18n), `5c3adae` (Money), `46bdeb9` (dev timings), `2b3b739` (the review)`; no backend change; no migration. The user's brief (no pictures; physical-phone checks left for the user's final test): fix the 320-point "Partenaires" tab clipping; compare Money's today-only expenses and account movements against the recorded decisions and implement period totals only if they were agreed, keeping the labels explicit; verify the Home and Money links and error states; finish the imported-stock review reached from Home → Receive — reproduce the 100-phone file, fix clipped names, counts and amounts, make the horizontal filters clearly usable, tidy the pinned payment footer, measure where the lag occurs and fix the measured bottleneck, keep all 100 items and their corrections, never hide unresolved rows or enable payment while items need review, report timings before and after.

### ✅ DECIDED AND IMPLEMENTED

- **Money's account movements and expenses stay today's (D42).** The 0074 decision defines *Accounts today* and the *Daily expenses* card as today's recorded movement, and no recorded decision agrees period totals for either — so none were implemented. Their hints now name the business day ("Today only (26 Sep 2026) — the period above changes sales, not this."; "…each account today (26 Sep 2026)…"), in EN/FR/AR, and the app's reply check requires `today`.
- **The tab label (D43)** takes 3 points of the navigator's own inset on each side; "Partenaires" fits at 320 points with the type unchanged.
- **The review's rows carry light named actions (D44):** Accept, Edit, Exclude and Include again are a plain pressable and a word, 48 points tall, no icon, no animation library — the three design-system Buttons per row were most of the views an open group mounted. **Every filter in view (D45):** the four chips wrap at 320 points instead of scrolling sideways with one off-screen, each 48 points tall (supersedes the sideways row of `ef2c795`). **The pinned footer (D46):** ready and its total beside what still stands in the way ("100 remain", amber) or, once nothing does, what was left out; Continue to payment disabled exactly as before and the payment step reached only through it. **Native text may shrink (D47)** where a row's name, count or amount could run past its edge on a phone. **Stage timings in the development build (D48):** `[timing]` lines in the Metro terminal for parsing, first list, filter, group opened, change applied and each draft write — nothing in a production build.

### 📋 VERIFICATION

- **The 100-phone workbook**, through the real parse endpoint on the isolated copy: 100 entries, 10 groups, 70 unknown / 30 ambiguous products, 0 ready — reproduced on the current build and measured (web export, CPU throttled 4×, same method before and after): parse 82 → 71 ms; first render 593 → **402 ms**; filter 114 → 56; **expanding a group 754 → 308 ms**; editing an item 778 → 461; excluding a row 108 → no long task; scroll 78 → 70 with 0 row re-renders; DOM for an open group 499 → 333. The profile put the time in layout and paint, not script (expand: 1 009 → 650 ms of layout, script 554 → 408). The draft path was measured negligible in JavaScript (43 KB, stringify 0.08 ms, guard 0.7 ms) and left as designed. After each run: 100 entries, the correction and the exclusion intact, "0 ready · 0 MRU", Continue disabled.
- **Read from the page, no pictures:** the review in EN/FR/AR at 320 and 393 pt, light and dark, 130 % text — collapsed, open, filtered, the item sheet, an excluded row: **21 of 21 clean**; no clipped text, no sideways overflow, no control under 48 points but the design-system sheet's Close. Money and Home: **29 of 29 clean** — the hints with the date, the links (View all sales, View all expenses, Add expense, Results, Daily closing, Outstanding payments), an older server and a failed server on Money (overview and sales by day) and on Home, and "Partenaires" whole at 320 in French.
- **Gates:** mobile tsc · **74 pure suites** (new `review-screen.test` 7) · parity 3 187 · `expo lint` 0 errors (33 pre-existing warnings). Backend unchanged.
- **Physical phone: not run** — `docs/24` §43 T1–T11, with the handset's own timings from the Metro terminal.

#### Addendum — the sheet's Close and the corrected draft (2026-09-26, later; `docs/55` §6)

- **The design-system sheet's Close is 48 points (D49)** — the one control under the minimum on the review's item sheet; every sheet.
- **A group offers Match product only where a shared choice exists (D50).** All ten groups carried the button, seven of them with a sheet that could only say nothing in the catalogue matches; the headline Match products opened that empty sheet first. The button now appears for a group whose phones share at least one candidate, and Match products opens the first such group. Rules unchanged.
- **"Corrected. The file said {cost}" speaks only when the cost was corrected (D51).** A product-only correction printed it for a cost that had not moved.
- **Verification (isolated copy, real controls, CPU 4×, no purchase posted):** a 100-phone draft with one group matched (10 ready · 165 000), two costs corrected (164 000), three rows excluded (87 remain) — the footer matched an independent count at every step; the corrections and exclusions survived leaving for Home and coming back, and the store's clear-and-restore; Exclude all → "Left out 90" and Continue enabled only then; the payment step said "Paying now for 10 phones"; one Include again → 1 remain, Continue disabled again; Close 48 × 48 and the sheet closes onto the same open group. **Against the fresh file in the same session:** expand 671 → 500 ms, filter 308 → 151, edit 1 037 → 553, scroll 60 → no long task — no cost to the corrected state; the spread between sessions was the machine's. Gates: mobile tsc · 74 pure suites (`review-screen.test` 9) · parity 3 187 · `expo lint` 0 errors. **Known, not fixed:** on the phone, resuming a half-checked delivery after the app was killed means picking the same file again — the saved draft then replaces the fresh read (a product decision for Receive). Phone: `docs/24` §43 T1–T13 not run.

## The pre-06:00 opening choice and the simple Home (2026-09-26)

The audit and the measurements are in [`docs/56`](56_PRE_0600_OPENING_AND_SIMPLE_HOME.md); the rule is 25a in `docs/04`; the phone's checks are `docs/24` §44.

### 📋 WHAT THE APP RECORDED AT 03:41 ON 26 SEPTEMBER

Test Store, Main Store, the Owner, boutique time UTC. `POST /closings/open {}` at 03:41:54 wrote an **`opened` event for business date 2026-09-25** (nth 1 — the 25th had never been opened; it already held two daytime sales) with the store time 03:41; the two sales at 03:44 (00005 850 MRU, 00006 3 600 MRU) carry **business date 2026-09-25**; the two expenses at 03:46 (100 cash, 500 Bankily; `spent_on` 18 Sep as left in the form) carry **confirmation date 2026-09-25**. No `day_started_early` exists; the 25th has no closing row and reads *Needs review*. **This is what rules 24a and 25a prescribe, and exactly the default the Owner would have been offered under the new flow (*Continue 25 September*).** Nothing was reassigned; no correction is required. If the Owner meant the 26th, the exact scripted change is written in `docs/56` §1.3 and would be made only on written approval.

### ✅ DECIDED AND IMPLEMENTED

- **The opening chooses its business day before it is recorded (D52–D55).** `POST /closings/open` takes `mode`: `continue` (default; the previous business date, all anybody but the Owner can do) or `start_new` (`closing.start_early`, between midnight and 06:00, `not_before_day_start` otherwise) — which writes the **same `day_started_early` event a reopen writes**, then opens the new date. The `opened` event and its audit row carry `choice` and `calendarDate` whenever a choice existed; a plain opening after 06:00 claims none. `GET /closings/open/view` returns `openChoices` beside `reopenChoices`. The phone sends `mode` only when a choice was made (an older server refuses unknown fields), and asks first: the Owner gets the **choice sheet** — *Continue {yesterday}* selected, *Start {today} early* second, the store's time in the title, both dates in full, which date receives new sales and expenses, "Nothing already recorded moves to another day"; a staff member before 06:00 gets a **notice** naming the day and that only the Owner may start today early; after 06:00 nothing is asked. One `DayChoiceSheet` serves the opening and the reopen, so the **reopen's choice is preserved**. Nothing already recorded moves; the day left behind, if never closed, reads *Needs review*.
- **The simple Home (D56–D60).** The shared `TabHeader` on one restrained tint (react-native-svg, no dependency added) with the bell and the **store's calendar date** (the server's, informational, never a picker); before 06:00 the line "Sales still count for {yesterday} until 06:00". Sales value first with the exact range and, **only when the server supplies one**, the comparison against the preceding window of equal length (`figures.comparison`, the analytics `compare` rule: none on a zero base); one compact chart under it; the cancellation, return and net lines as before. Collected / Expenses / Still owed as three plain lines with their scope, no icon, colour only on the amount. One Daily closing entry that opens the report and closes nothing, reading "{date} · Not closed" whenever the business day is not the calendar date, with the *Yesterday needs review* chip. Top boutique, Latest phones and the filtered Stock link, the pending rows, the five tabs, every gate and state kept; the "{branch} · {period}" line and "Ready when you are." dropped.

### 📋 VERIFICATION

- **The rules, through the built API on a fake clock (isolated copy): 31 of 31.** At 03:41 the Owner is offered both days and the seller only *continue*; the seller's `start_new` is 403; the Owner's `start_new` writes `day_started_early` and `opened` (choice, calendar date, actor, two audit rows); the business day becomes the 6th and the unclosed 5th reads *needs_review* on `business-day`, on Home and on the open view; a sale then carries the 6th while the 5th's sale did not move; repeat taps and a second early start change nothing; *continue* lands the opening on the 5th with the choice on record and the 5th stays the business day until 06:00; 05:59:30 still offers the start, 06:00:30 does not (`not_before_day_start`) and a plain opening records no choice; a closed previous day is refused as an opening (`open_day_closed`) and the reopen keeps its two choices; Home's comparison is real (−100 %, then 0 %). Live received nothing.
- **The screens, read from the page (web export, isolated API, fake clock): 32 of 33** — Home at 03:41 in EN/FR/AR at 320–430 pt, light and dark, text at 130 %, all clean (the date, the note, the entry naming the 5th, the three lines, Arabic mirrored); the seller's notice and its Cancel; the Owner's sheet in three languages and at larger text with *Continue* selected (`aria-checked` read from the radios); Continue and Start early confirmed through the sheet; 06:00:30 with no prompt; the closed 6th's reopen sheet unchanged at 03:30. The one finding was the harness's own expectation on the Stock page. Found on the way: the radios' checked state must be the `aria-checked` prop (react-native-web 0.21 no longer maps `accessibilityState`) — fixed in the shared sheet.
- **Gates:** backend 95 specs green (new `closing-open.spec`), `tsc` clean; mobile `tsc` clean, 75 pure suites, i18n parity 3 202 in one order, `expo lint` 0 errors.

### 🟡 OWED

- The phone (`docs/24` §44 U1–U11). The stored-business-date correction still has no screen. Only D−1 is checked for *Needs review*.

#### Addendum — the expense's two dates and the Home reference pass (2026-09-26, later; `docs/57`)

- **The two 03:46 expenses (`docs/57` §1).** `spent_on` is the typed "day it was spent" and drives no money: Home's Expenses, Money's Daily expenses, the Daily closing, rollups and goals all use the **confirmation date** (a fixed expense its due date), so both count for **25 September**; the phone shows `spent_on` nowhere after submission; the API's `?date=` filter on it is used by no screen; the "unusual amount" warning's 180-day sample window contains it either way. **Why 18 September:** the draft hook wrote on every render and so put the just-submitted form back the moment `clear()` re-rendered the screen, and Discard reset everything but the date — the first entry's default (18 Sep, the rejected "Etay") became the date of every expense since. **Fixed for future entries** (mobile `6c03889`): a draft is written only when its content changed and not after a clear; the date is restored only if the person set it (`dateTouched`), else today's; Discard resets it; the field's example is today. **Records untouched**; the optional tidy-up of the three rows' `spent_on` to their confirmation date (no figure changes) is written out in `docs/57` §1.5 for the user's decision.
- **Home against the reference (D61–D62, mobile `05c76bf`).** The greeting keeps "Ready when you are." on every day; before 06:00 the business-date line is a further line under the header on the same tint, never in the greeting's place. Collected / Expenses / Still owed are **three distinct quiet text-first cards** — word, amount, unit, scope, a soft tint that follows the amount's meaning, no icon — three abreast where they fit, two and one at 320 pt, stacked when the system text is 1.2× or larger. The one chart, the header tint, the calendar date by the bell, every link, the pending rows and the accounting lines kept; no sample figure.
- **Verification.** The page check rerun after the last discrepancy was resolved (the Stock destination is a tab that keeps Home mounted on the web; the check now reads the route reached): **33 of 33 views passed**. **Gates in full:** backend `npm test` **159 suites / 2 835 tests passed**, `tsc` clean; mobile `tsc` clean, **76 pure suites / 1 073 cases, 0 failed**, i18n parity 3 202 / 3 202 / 3 202, `expo lint` 0 errors (31 pre-existing warnings). Phone: `docs/24` §44 U1–U13 not run.

## The compact Daily closing (2026-09-26)

The screen and its verification are in [`docs/58`](58_COMPACT_DAILY_CLOSING.md); the report's contract is `docs/51`; the phone's checks are `docs/24` §45. Rule 24c (`docs/04`) says what an expense's `spent_on` is, apart from its accounting day.

### ✅ DECIDED AND IMPLEMENTED (mobile `0601ccb`; backend unchanged)

- **The first view is a statement (D63):** the boutique, the business date, the recorded opening and the standing; then the sales value with "{n} sales · {m} items", and — each only where the server sent it — Gross profit, Expenses and Result after expenses (never "net profit"); a result that cannot be calculated says so in one line.
- **Sales details, the statement's one expandable, with the way to the records (D64):** invoiced sales, sales cancelled today, returns approved today, net sales, then how the result follows (cost of items sold, gross profit, expenses, result after expenses, the scope — or "Cannot calculate yet"), then collected for these sales (at the till, later the same day, taken back by corrections), still owed, the counting rule, *See the transactions* → the day's sales. The approved references (the user's, from another conversation; example numbers only, none typed in) show this hierarchy: statement → Sales details → Cash drawer and each account with its own check → Money movements → Review & close, Correct a transaction, Closing history.
- **Check balances per channel, each with its own action (D65):** the Cash drawer — opening (anchored on the last counted close, or "starts from 0"), received, paid out, *Should be in the drawer*, Counted and Difference once counted, **Count cash**; each account — its **Recorded movement** (never a balance; the note says so), *Movement in the account app* and Difference once checked, **Check balance**. Both open the counting screen on that channel (`?focus=`), its field focused. "Optional. An unchecked balance is closed as not verified — never as matched."
- **Money movements behind one disclosure (D66):** every channel's money in, Received / Older debts collected / Paid out / Net, Details by channel, the Expenses by category with reversals, total, fixed and every expense.
- **Review and close, Correct a transaction and Closing history stay where they were (D67)**, on the same contract — `clientUuid`, `reportVersion`, the acknowledgement and reason, `report_changed`, the delegate rule, repeat taps; the generic "Check physical…" row is gone since every channel has its own. **A past day reads the same statement read-only (D68).** Reopening and the before-06:00 choice untouched.
- **`spent_on` said apart (rule 24c):** the day the person says the money went out — a memo that moves no figure; the accounting day is the confirmation date (fixed: the due date). The three memo-dated rows of `docs/57` §1.1 are **not authorised for editing and were not touched**.
- **The popup and the close, hardened after review (D74, `docs/58` §1.4; rule 26 extended):** the question is the first step's own text and the title may wrap, so neither is cut at large text; the amount step scrolls under the keyboard; a typed amount is saved or cleared, never dropped (Continue waits and says why, a Change can be Cancelled); only a valid amount is saved — Arabic-Indic digits are the amount, a minus only on an account's movement, two decimals at most; **Close waits while the report is read again** after a count or a 409, so it never signs figures nobody saw. The closing-time loan reminders stay, now on the Daily closing page. The server refuses a count carrying the close's machine keys (`reserved_reason`) and a close that both attests and acknowledges (`conflicting_statements`); a person's skip and the stored close agree on both paths (no more false "changed since close"); a reclose freezes no stale warning. The shared money field turns Arabic-Indic digits into the amount everywhere. **Open question for the user:** a store employee without the closing delegation can no longer enter a count — the only counting place is now inside the closing popup.
- **The closing popup and the attestation (D71, `docs/58` §1.4; rule 26 extended):** "Close the business day" opens a short popup — *Have you checked today's cash and account movements?* — with **Enter the amounts** (a compact count inside the popup, saved figure by figure, then back to closing) or **I've checked** (an attestation). The smallest contract change: `POST /closings` takes `attestChecked`; a channel without an amount is closed as **attested** — the person and the time kept, no amount, no difference, never matched — shown as "Checked; amounts not recorded"; a reopen makes it stale; the older acknowledgement + reason still works; the history never lists the rows a close froze as saved counts. `clientUuid` replay and `report_changed` unchanged. **The history as one rectangle (D72):** one header, the chevron at the end, a short slide-out reveal, none under reduced motion, every entry kept. **No balance cards (D73):** the Check balances section and the counting page removed; *Unsettled differences* moved beside *Correct a transaction*; recorded counts and server data preserved.
- **The UI correction against the phone screenshots (D70, presentation only; `docs/58` §1.3):** Sales details is figure rows only — Invoiced sales, (cancelled / returned when nonzero), Net sales, Cost of items sold, Gross profit, Expenses, Result after expenses — with the explanations behind an accessible (?) beside the title, shown only when asked; the collected / owed block and *See the transactions* removed from it. Money movements always in view, no expand/collapse: each configured channel's recorded movement, a line, "Debt settled for this day (included above)", "Money in the shop — recorded movement" with the line that it is the net of what was recorded through these channels — not counted cash, not provider balances (the bare label would claim a balance the accounts cannot make; flagged). Server figures only; nothing added on the phone.
- **The words, checked (D69, copy only; `docs/58` §1.2):** the drawer's figure is "Should be in the drawer" only when a counted close anchors it — with no counted opening it reads **"Recorded cash movement, from a 0 start"** (report, review sheet and counting screen alike); an account is never counted and has no balance here: **"Recorded movement"**, **"Movement shown by the account app"**, **"Movement in the account app"**, its chips **"Checked against the app"** / "Checked before reopening" / "Not checked yet", its action **"Check movement"** (was "Check balance"), its history row "{amount} shown by the account app", its settled line "Less/More than the recorded movement."; the counting screen is titled **"Check the drawer and accounts"**. EN/FR/AR in parity. Calculations, optional checks, the close contract and live data unchanged.

### 📋 VERIFICATION

- **The real 03:41 scenario on a copy of live, through the built API on a fake clock: 17 of 17** (`docs/58` §3.1) — at 03:41 on the 26th the business day is the 25th with its 4 sales (6 748, 00005 and 00006 among them) and 3 confirmed expenses (840, Sbou7 and Courent among them), open and closable; the drawer's expected figure and Bankily's recorded movement (never a balance); a cash count shows expected, counted and +50, and the close still needs the acknowledgement for the unchecked account; at 06:00:30 the 26th begins empty with the warning, the 25th reads *Needs review* with its records, its count and its 03:41 opening, not closable from the phone; nothing moved.
- **The screens, read from the page (web export of `ad78607`, the same copy): 23 of 23, every view passed** (`docs/58` §3.2) — the 25th at 03:41 in EN/FR/AR at 320–430 pt, dark, 130 % text; Sales details, Money movements, Count cash, Check balance and Review and close through the real controls; a saved cash count showing expected, counted and +50; a store employee's view; 06:00 with the 25th read-only in history. Offline read in the source only.
- **Gates in full:** backend unchanged at `4bc2d72` (its last full run: 159 suites / 2 835 tests passed); mobile `tsc` clean, **77 pure suites / 1 079 cases, 0 failed** (new `daily-closing-screen.test`), i18n parity **3 213 / 3 213 / 3 213** in one order, `expo lint` 0 errors (31 pre-existing warnings).

### 🟡 OWED

- The phone (`docs/24` §45 V1–V12); offline on the report read in the source, not driven off the phone. The three `spent_on` rows, on the user's decision.
