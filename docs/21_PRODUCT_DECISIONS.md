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

### ✅ APPROVED — the four bottom tabs do not change

Home · Sell · Inventory · More. No fifth tab.

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
