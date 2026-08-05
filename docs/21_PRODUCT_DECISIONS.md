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

---

## 7. Goals · 8. Money & reconciliation · 9. Returns

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

### Step 5 — `Unit.price` override
Nullable column + scope/actor/timestamp audit trail. Unblocks §6 pricing completely.

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
