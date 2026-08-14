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
