# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Active account / Owner: **CLAUDE-A**
- `started_at_utc`: **2026-08-13 09:10 UTC** — explicit account switch requested
  by the user; ownership passed from `NONE` to `CLAUDE-A`. **No earlier
  CLAUDE-B attribution was relabelled or reinterpreted.**
- Current authorised task: **Phase H1.4 — quantity-tracked accessory
  transfers.** Partial quantities selected at request time; shipment and receipt
  stay **all-or-nothing per transfer**. Explicitly out of scope: partial
  shipment, partial receipt, discrepancy handling, return-to-source, proof
  photos, consignment, WhatsApp, returns, customer credit, technician features,
  notification-broadcast redesign.
- Takeover verification (2026-08-13, checked not assumed): backend `45e9b55` ·
  mobile `112e035` · docs `f8fee9b` · latest migration `0033` · all three trees
  clean and level with `origin/master` · `READY_FOR_HANDOFF` / owner `NONE`.
  Every expected value in the H1.4 brief matched reality.
- Last session: **CLAUDE-B**, 2026-08-09 — **H1.3, Serialized Transfer
  Notifications and the Complete Mobile Workflow** (complete). Migration
  **`0033`**.
- **Serialized transfers are now usable end to end.** Request → approve → ship →
  receive, with notifications at every step and full mobile screens. Everything
  the H0 audit found is closed.
- Previous: H1.2 (`0031`, `0032`), H1.1 (`0030`), H0 audit, G2A-CP1…CP4.5

### Takeover check (verified, not assumed)

Backend `d7f4653` · mobile `30440df` · docs `1a15041`, all clean and level;
**47 suites / 617 tests**, **31 migrations**, latest `0032`, schema up to date.
Every expected value in the H1.3 brief matched reality, so nothing needed
correcting before work began.
- **The H0 authorization gap is CLOSED.** `unit.transfer` no longer guards any
  route and is revoked from both store roles; an employee cannot approve, and
  cannot cancel anyone else's request.
- Previous: H1.1 (`0030`), H0 audit, G2A-CP1…CP4.5

> **Account labels.** The user set this session's account to **`CLAUDE-B`**
> explicitly; CP2 and CP3 ran as `CLAUDE-A`. Separately, several older entries
> (G1 backend, G1 mobile, G2A-CP1) recorded themselves as `CLAUDE-B` when the
> work was actually `CLAUDE-A` — **only those ownership labels were wrong**; the
> work, commits, audits and verification in them are correct and unaffected.
> Nothing was rewritten: `SESSION_LOG.md` is append-only, so that correction is
> appended there and no commit was amended. Read any `CLAUDE-B` attribution
> dated **2026-08-05/06** as `CLAUDE-A`.

## Repository state

All clean, all `master`, all level with `origin`.

| Repository | Branch | Local HEAD | Remote HEAD | Working tree |
|---|---|---|---|---|
| Backend (`erp-backend`) | master | `45e9b55` | `45e9b55` | clean |
| Mobile (`erp-mobile`) | master | `112e035` | `112e035` | clean |
| Documentation (`erp-docs`) | master | *the commit carrying this handoff* | same | clean |

H1.3 commits — backend `82e9393` (CP1: the seven H1.2 requirements pinned) ·
`9013d26` (CP2: migration 0033 + transfer notifications) · `fea136b` (CP3: list,
counts and detail contract) · `45e9b55` (CP7: the two live-found defects) ·
mobile `112e035` (CP4/5/6: the whole transfer UI).
H1.2 commits — backend `0026790`, `04e1463`, `d7f4653` · mobile `30440df`.
H1.1 commits — backend `e40af13`, `b63e5c6`, `d3ea0c6` · mobile `84b5b84`.

**Note:** the documentation row is deliberately not a hash. A file cannot contain
the id of the commit that introduces it. Read it with
`git -C <docs repo> log --oneline -1`.

**Layout:** the documentation repository is the **workspace root**
(`C:\wamp64\www\PhoneStoreERP`). `backend/` and `mobile/` are nested inside its
working tree but are separate repositories, excluded via the root `.gitignore`.
From either code repository the documentation repository is `../`.

## Verified baseline (end of H1.3)

- **Backend tests: 50 suites / 688 tests passing**, 0 failing (H1.2 baseline
  47/617; H1.3 added 71 across authority, notifications and the list contract).
- **H1.3 live verification: 76/76** against the running API and real MySQL with
  five real sessions — Owner, source Manager, source Employee, destination
  Manager, and an Employee assigned to **both** branches.
- Migration status: latest **`0033_notification_dedupe_and_payload`** —
  **32 migrations**, *"Database schema is up to date!"*, **4 triggers** intact.
- **Mobile:** TypeScript clean · `expo lint` clean · **expo-doctor 18/18** ·
  `expo export --platform web` built **32 routes**, including `/transfers`,
  `/transfers/[id]` and `/transfers/new`. Pure Node suites **11 + 5 + 7 + 6 +
  11**. **EN and AR both 676 keys**, no missing, extra or duplicate.
- **Demo baseline restored exactly** after verification: products 12 · units 11 ·
  sales 7 · `sum_total = 10051.00` · sale_items 14 · stock 4 · reserved 0 ·
  transfers 0 · notifications 41 · `units` checksum
  `2a1dc9bf284afde32b402ad108d38a76` unchanged · no odd unit statuses · no
  temporary databases.

### Previous baseline (end of H1.2), kept for comparison

- **Backend tests: 47 suites / 617 tests passing**, 0 failing (H1.1 baseline
  47/607; H1.2 added 10 lifecycle, permission-split and drift tests).
- **H1.1 race suite re-proved at H1.2 takeover: 32/32.** Re-run before changing
  any lifecycle behaviour, so no H1.1 invariant regressed.
- **H1.2 live verification: 40/40** against the running API and real MySQL with
  five real sessions — Owner, Manager, Employee-in-both-branches, source-only and
  destination-only.
  *Correction: commit `88e25bd`'s message says "9 added / 591" — the real
  figures are 7 added and 589 at that point. History was not rewritten for a
  count error.*
- **CP4 preflight: 24/24** · **CP4.5 role + notification verification: 28/28**
  against the live API with three real sessions (Owner, delegated Manager,
  Employee).
- **Interactive UI verification:** the app was run for real (Expo web against the
  live API) and driven through the pricing flows — see the CP4.5 section.
- **Mobile:** TypeScript clean · `expo lint` clean · **expo-doctor 18/18** ·
  `expo export --platform web` built **29 routes**, including `/pricing/unit`,
  `/pricing/history` and `/notifications`. Node pure suites: **11 + 5 + 6 + 7**.
- **i18n:** EN and AR both **559 keys**, no missing, no extra, no duplicates;
  every literal `t()` key resolves; no `text-start`; no dead routes.
- Backend TypeScript **clean** · `prisma validate` **valid** · `prisma generate`
  regenerated the client (3 500 references to the new models; both `tsc` and the
  suite compile against it). The `EPERM … query_engine-windows.dll` rename
  warning is the known WAMP file-lock from another running dev server, not a
  generation failure.
- Migration status: *"Database schema is up to date!"* — latest
  **`0032_manager_cancel_route_permission`** — **31 migrations**.
- **Trigger inventory (exact, live dev):** `audit_logs_block_update` BEFORE
  UPDATE · `audit_logs_block_delete` BEFORE DELETE · `price_change_events_block_update`
  BEFORE UPDATE · `price_change_events_block_delete` BEFORE DELETE. **4 total**,
  all DEFINER `phonestore_migrator@localhost`. Re-verified after `0031`/`0032`.
- **No temporary databases remain** (`prisma_cp3_trig` and `prisma_cp3_pre`
  dropped). No temporary business fixtures remain.

## Phase G2A — Pricing Foundation

### CP1 ✅ — pricing-truth audit and decision record (docs `e4de6b9`)

Traced end to end; no code changed. Conclusion: **no contradiction** with the
approved pricing rules, so G2A could proceed as specified.

| Field | Scope | Mutability | Role |
|---|---|---|---|
| `Product.defaultPrice` | Company-wide | Mutable default | Company fallback |
| `StockItem.price` | Branch | Set on **first receive only** | Authoritative branch price for **quantity** stock |
| `SaleItem.price` · `DigestLine.salePrice` | Sale line | **Immutable snapshot** | What was actually charged |
| `Unit.cost` | Unit | Set at receiving | **There was no `Unit` price** — the gap G2A fills |

Nothing mutates `defaultPrice` except catalog create, already behind
`price.edit`. Margin is computed server-side (`round(total − totalCost)`) and the
client's numbers are never trusted. No read path recomputes a completed sale, so
**a price edit cannot alter history.**

### CP2 ✅ — pricing schema and migration `0027_pricing_foundation` (backend `167bbcf`)

Schema only. **No API, no resolution service, no notification, no UI.** Nothing
reads these tables yet, so there is no half-enforced state.

| Table | Identity rule | Purpose |
|---|---|---|
| `branch_variant_prices` | `UNIQUE (product_id, branch_id)` | current price of one exact variant in one branch |
| `unit_price_overrides` | `UNIQUE (unit_id)`, **plus `branch_id`** | current price of one individual unit |
| `price_change_events` | append-only, no uniqueness | every price change, forever |

`DECIMAL(14,2)` money and `BINARY(16)` UUIDv7 keys throughout.
`version INT DEFAULT 0` on both current-price tables gives compare-and-swap →
**409** on a stale edit, so two managers repricing the same phone cannot
silently overwrite each other.

**The one design correction carried from CP1.** CP1 proposed keying
`UnitPriceOverride` on `unit_id` alone. That was wrong: an override set by a
Manager in Branch A would follow the phone into Branch B and take effect under
authority nobody granted there. `branch_id` records the **branch whose authority
created the price** — deliberately *not* a foreign key to the unit's current
location, because the two must be allowed to diverge and that divergence is the
signal CP3 acts on. The FK to `units` also means quantity stock can never
acquire a unit override.

**Constraints honoured:** `Product.defaultPrice` untouched (still the fallback) ·
`StockItem.price` untouched (still authoritative for quantity — no parallel
quantity-price source) · **no backfill**, because copying `defaultPrice` into
every branch would invent prices nobody set and permanently destroy the fallback
· no earlier migration modified, squashed or regenerated · additive only, with no
`ALTER`, `INSERT` or `DROP` against any existing table.

**Append-only enforced by the database, not by convention.**
`price_change_events` carries `BEFORE UPDATE` and `BEFORE DELETE` triggers that
`SIGNAL SQLSTATE '45000'` when `USER()` is the application account — the
`audit_logs` pattern. Unlike `audit_logs`, these triggers live **inside the
migration**, so a fresh deployment gets them automatically rather than depending
on someone running an init script. Four `CHECK` constraints reject negative
money.

### Backup (taken BEFORE the migration)

- **Path:** `~/erp-backups/phonestore-20260807-051508.sql` — `--hex-blob`,
  `--single-transaction`, routines + triggers + events, no tablespaces.
  Credentials were never printed or placed on a command line.
- **Verified:** 207 450 bytes · trailer `-- Dump completed on 2026-08-07 5:15:09`
  · **0 raw `_binary` literals** / 1 622 hex literals · valid UTF-8 round trip ·
  52 `CREATE TABLE` · 2 triggers.
- **Restore proven BEFORE migrating**, through the documented DEFINER-safe path
  (`scripts/sanitize-dump.js` → restore as the migrator) into `prisma_g2a_pre`:
  **52/52 tables, 2/2 triggers**, and the `units` `HEX(id)` MD5
  `2a1dc9bf284afde32b402ad108d38a76` **byte-identical to live**.

### Deployment proofs — all four passed

| Proof | Result |
|---|---|
| **Clean database** (`prisma_g2a_clean`, from zero) | 55 tables · 3 pricing tables · 2 pricing triggers · 4 CHECKs · 13 pricing FKs · 26 migrations applied |
| **Restored pre-migration database** (`prisma_g2a_pre`) | `0027` applied alone, **seed never ran** · 12 products / 11 units / 7 sales / 14 sale_items / 4 stock all preserved · **`bvp=0 upo=0 pce=0`** (no backfill) · audit triggers 2 + price triggers 2 · `sum_total=10051.00`, `sum_item_price=9615.00`, identical to live |
| **Existing dev database** | applied; status *"Database schema is up to date!"*, 26 migrations |
| **Rerun** | idempotent — nothing changed |

**Append-only and CHECK exercised against real MySQL as `phonestore_app`: 7/7** —
read ✅ · insert ✅ · **UPDATE blocked** ✅ · **DELETE blocked** ✅ · negative price
rejected ✅ · history intact after both blocked attempts ✅. This is why
`pricing-migration.spec.ts` asserts the migration's *contract* instead of mocking
Prisma: a mocked constraint only tests the mock.

**Cleanup:** probe events removed, `prisma_g2a_clean` and `prisma_g2a_pre`
**dropped**, sanitized dump copy deleted. Demo integrity re-checked afterwards —
products 12 · units 11 · sales 7 · `sum_total=10051.00` · `bvp=0 upo=0 pce=0`.

### 🔴 Open issue for G2B — who may establish `StockItem.price`

**Not approved, and not silently accepted as correct.** `upsertStock` writes
`price` on the **first receive of a quantity product into a branch**, and
receiving is open to a **Store Employee** — so an Employee performing ordinary
intake can establish the branch selling price without holding `price.edit`.
Later receives increment quantity and leave the price alone, so it happens
exactly once per product per branch and is easy to miss.

CP2 deliberately did **not** change it: altering intake behaviour is outside a
schema phase and would have shipped an unreviewed workflow change alongside a
migration. Three candidate resolutions are recorded in
[`docs/21` §6](docs/21_PRODUCT_DECISIONS.md). **Treat it as known, tolerated and
unapproved until the user decides in G2B.**

### CP3 ✅ — pricing resolution and secure backend operations (backend `103588f`)

**Backend complete. No mobile pricing UI, no G2B proposals.**

**One `PricingService` is the only authority on selling price** — Sell, product
detail and the pricing API all ask it rather than re-deriving precedence.
Effective price, first match wins, with the source always returned:
`unit_override` → `branch_variant` → `stock_item` (quantity only) →
`product_default` → `unpriced`.

A unit override applies **only when the override's branch, the unit's current
branch and the active request branch all match**. A stale override is reported
as `staleOverrideIgnored` and never applied, so a transfer that failed to
invalidate is visible rather than silently charging the wrong price. Product-level
resolution structurally cannot see an override — one phone's price is not the
model's price.

**API:** narrow, explicit routes under `/v1/pricing`. **No generic endpoint**
taking a model, field, permission or target branch from the body. Reads of the
effective price are open to any signed-in user; writes and history need
branch-scoped `price.edit`.

**Concurrency:** compare-and-swap on `version`, `409` on a stale update or
removal, and a lost create race translated from the unique-key rejection into
`409 refresh_required` rather than overwriting the winner.

**Below cost:** `discount.override` plus a non-blank reason, recorded. Purely
permission-based — a Manager is refused because that permission is Owner-only and
never delegatable. A branch price must clear the most expensive in-stock unit;
the refusal states how many items are affected and never a cost.

**Atomicity:** price change + `PriceChangeEvent` + audit row + Owner
notification are one transaction. A failed history or notification write rolls
the price back.

**Notifications** exclude the actor — one rule covering both cases — and
deduplicate an Owner assigned to several branches. No cost, no margin, no
threshold, no WhatsApp.

**Transfer invalidation** runs inside the receive transaction. The override is
**deleted**, so a returning phone cannot resurrect it; history keeps the value
with `initiator = 'system'`, `reason = 'branch_transfer'`.
`transfers.receiveConfirm` is the **only** production path that changes
`Unit.branchId`; `cancel` writes the origin branch back to where the unit
already was, and that no-op is skipped.

### CP3 migrations

| Migration | Why |
|---|---|
| `0028_audit_append_only_triggers` | **Repairs a real gap.** The `audit_logs` guard lived only in a manual init script, so a clean database built from every migration had **no** `audit_logs` triggers — a fresh production deployment would have shipped a mutable audit log. Idempotent (`DROP IF EXISTS` + `CREATE`); `0027` untouched. |
| `0029_stock_item_version` | Adds `version` to `stock_items` for quantity-price compare-and-swap. `updatedAt` cannot serve: MySQL keeps microseconds, a JS `Date` only milliseconds, so a CAS on it would round-trip lossily. |

Backups taken before each: `phonestore-20260807-140256.sql` (before `0028`) and
`phonestore-20260807-141018.sql` (before `0029`) — both `--hex-blob`,
`--single-transaction`, routines/triggers/events, no tablespaces, 0 raw
`_binary`, valid UTF-8, 55 tables. The DEFINER-safe restore was proven **before**
migrating: 55/55 tables, 4/4 triggers, `units` checksum identical to live. Both
migrations verified on clean, restored and dev databases, and on rerun.

### Two defects the live verification caught that the unit suite could not

1. **The active branch was resolved inside `PermissionsGuard`**, which exits
   early on routes needing no permission — so open reads had no branch at all and
   returned 400 for a header the client had sent. Branch is request context, not
   an authorization result; it now comes from the CLS middleware.
2. **That left open reads unchecked** — no permission meant nothing verified the
   branch, so an employee could have read another branch's prices by changing a
   header. `PricingService.activeBranch()` now confirms the caller is assigned
   to the branch, on reads as well as writes.

Both are fixed and covered by tests. **Lesson: a guard that also does context
resolution silently changes behaviour for every route that skips the guard.**

### Live verification — 55 checks, 0 failures

Against the running API and real MySQL: per-branch prices differ for the same
variant · one phone differs from another of the same model · removal reveals the
layer beneath · stale version 409 · lost create race 409 · delegated Manager can
edit only the granted branch · Employee cannot write but can read · Employee
cannot read history · no-branch write fails closed · `catalog.manage` alone
cannot price · forged product, identifier and branch all fail closed · Manager
below-cost refused with no cost revealed · Owner below-cost needs and records a
reason · quantity uses `stock_items.price` with its own 409 · a shipped-but-not-
received transfer does **not** invalidate · a completed transfer does, with the
previous price preserved and `initiator='system'` · a returning phone does not
resurrect its price · price history rejects UPDATE and DELETE from the
application account · **completed sale totals, cost and margin unchanged after
every price scope change**.

**Fixtures created and removed:** two temporary users (`cp3mgr` with
`price.edit` delegated in Main Store only, `cp3emp`), their assignments, grants
and sessions; two stock transfers and their items; all pricing rows. The
accessory price touched by the quantity check was restored to 19.00/version 0.
Demo data afterwards: products 12 · units 11 (all back in Main Store) · sales 7 ·
`sum_total = 10051.00` · stock 4 · bvp/upo/pce 0 — **identical to the CP2
baseline**.

**Retained after cleanup, deliberately:** the `audit_logs` rows written by the
verification transfers (Unit and StockTransfer status changes). They are
append-only and were left in place rather than archived. The pricing-specific
`price_change_events`, `audit_logs` rows for `BranchVariantPrice`/
`UnitPriceOverride`, and `price.changed` notifications **were** removed by the
migrator account, which the append-only design permits for a DBA; this is
recorded here rather than left implicit. The transfer invoice-number sequence
advanced by two and was not rewound.

### CP4 ✅ — mobile pricing experience (mobile `0d0d9a0`, backend `63cae31`)

**Backend contracts connected to the app. No G2B. No migration was needed.**

The app renders the server's decision and never re-derives precedence: it
displays the `price`, `source`, `version` and `fallback` the CP3 endpoints
return. Sources are translated to shop language (EN + AR) with a sentence
explaining why each applies, shown as a labelled chip — **words plus tone, never
colour alone**.

**Who sees what.** All roles see the effective price and its source. Edit
controls need branch-scoped `price.edit`, so a delegated Manager gets them in
the granted branch only, an Employee gets **none at all** (not disabled ones),
and `catalog.manage` shows nothing. Branch changes re-resolve both, since the
branch is in the query key. Cost moved to its own section; withheld cost still
reads "Hidden", never `0`.

**Two serialized actions, deliberately separate screens** — a single screen with
a scope toggle is how someone reprices the whole shop by accident. One phone is
priced via `*#06#` and scanning the IMEI **off the phone**, not the box, with
manual entry always available. Quantity products edit `stock_items.price`
through the `0029` version and never touch overrides.

**One shared `PriceEditor`** for all three scopes. `parsePrice` is a separate
dependency-free module (11 Node tests): blank, `NaN`, negative and over-precise
values cannot reach the API, where `DECIMAL(14,2)` would silently truncate.
409 explains what was tried versus what it now is and stops — never a silent
refresh-and-resubmit. Below cost stays the server's call; an Owner's
authorisation resends **the same price and version**.

### CP4 preflight — the defect it caught

CP3 moved active-branch resolution into CLS middleware. The preflight checked
the routes that legitimately run without a branch, and found a **lock-out**:

`CostGatingInterceptor` resolved permissions for the active branch and let
`AccessService`'s 403 escape, so a restored session holding a branch the user
had been removed from failed **every** request — including `GET /auth/branches`,
the one screen needed to pick a different branch. Retry could only 403 again.

Cost gating decides what to *strip*, not who may call. It now degrades to the
strictest gating and does not cache that set. `/auth/permissions` still answers
403 — the honest answer — and the client drops the branch, which routes it to the
picker. The decision is a pure `classifyPermissionFailure()` with 5 Node tests.

**Standing lesson: a guard that also resolves context changes behaviour for every
route that skips the guard — and only a real request through the real stack
shows it.**

### What CP4 did NOT verify — stated plainly

- **No mobile UI was driven by a human or a device.** Verification was
  TypeScript, lint, expo-doctor, a web export proving every route's module graph
  loads, the Node pure suites, and API-level checks. The screens were not
  exercised by tapping through them.
- **Camera scanning was not physically verified.** It needs a real device or
  emulator; this environment has neither. The manual-entry path is code-complete
  and the scanner reuses the existing `ScannerSheet`.
- **Role behaviour was proven at the API level in CP3** (Owner, delegated
  Manager, Employee, forged identifiers, below-cost, 409). CP4 changed **no**
  authorization code, so that evidence still stands — but the *client-side*
  gating (which controls each role actually sees) was not verified by running
  the app as those roles.
- **Sell, Receive, Inventory and Notifications were not re-exercised through the
  UI.** Sell's server-side resolution was proven live in CP3; the mobile Sell
  screen was not re-run.

### Notifications — still incomplete

`price.changed` notifications are created by the backend and carry no cost or
margin (CP3, verified live). The mobile Notifications screen was **not** upgraded
in CP4, so Owners will see these through whatever the existing prototype renders.
**Record the Notifications milestone as still incomplete.**

### CP4.5 ✅ — pricing UI verified by driving the app (mobile `55f52b0`, backend `7adf598`)

CP4 shipped on TypeScript, lint and a web export. CP4.5 **ran the app** — Expo
web against the live API and the real database — and that found three things
compilation could not.

| # | Found by running it | Fixed in |
|---|---|---|
| 1 | A **sold** phone could be given a price: the screen offered the action and the API returned 200 | backend `88e25bd` |
| 2 | The 409 dialog quoted **its own stale snapshot** — "It is now 500 MRU" when the server held 1234 | mobile `7049ea4` |
| 3 | **Notifications did not exist at all** — CP4 called the screen a prototype; there was only an unused query key | `7adf598` + `55f52b0` |

#### Interactively driven (real DOM events, not asserted from source)

Branch price: default → set 1200 → immediate re-render → update 1300 → remove →
default restored, with **Warehouse visibly unaffected at 1 000 while Main Store
showed 1 200** · Save disabled until the value parses *and* differs · removal
confirmation showed **"Without it: 1 000 MRU"** · exact-phone override set by
manual IMEI, source became "This phone's own price" · sold phone refused with an
explanation and no action · unknown identifier "No item with that number" · a
real 409 race producing **"You tried 888 MRU. It is now 1 234 MRU."** · Owner
below-cost reason dialog with blank-reason blocked and the reason stored ·
quantity price 19 → 22 with the version incrementing and **zero** parallel price
rows · price history showing previous → new, actor, scope and reason ·
notifications list, read state and an action link landing on the pricing section
· Arabic strings across the whole pricing section.

#### Verified at the API with three real sessions (28/28)

Manager edits only the granted branch and holds `catalog.manage` in **both**
(proving that is not what gates pricing) · Manager refused below cost with a
**count** and never a cost figure · Manager never holds `discount.override` ·
Employee reads prices, is 403 on writes and on history, sees no `cost` field,
and never receives the Owner's notification.

#### Not verified — and not claimed

The browser pane was `visibilityState: hidden` for the entire session, so
**clicks could not be dispatched and no screenshot or animation evidence was
taken**; the UI was driven with real DOM pointer events instead. That is good
evidence for logic, text and state, and **no evidence at all** for layout.

- **No physical device.** Camera scanning, haptics, keyboard avoidance, sheet
  gestures, torch and clipboard are untested.
- **Arabic *strings* render; Arabic *layout* was not verified.** No claim is made
  about mirroring, wrapping or control order.
- Sell, Receive and Inventory were **not** re-driven through the UI this session.
  Their server-side behaviour was proven in CP3 and CP4.5 changed none of it.

[`docs/24_DEVICE_QA_CHECKLIST.md`](docs/24_DEVICE_QA_CHECKLIST.md) is the
checklist for the user's own device pass, separating what is already verified
from what only a phone can answer.

### ⚠️ Incident — session tokens briefly committed

Running the UI needed an authenticated session. Rather than type a password into
a form, a script logged in server-side and wrote the resulting **ephemeral
tokens** to `mobile/public/cp45-session.json` for the page to pick up. A
`git add -A` then swept that file into commit `7049ea4`; it was removed in
`55f52b0`. Both are pushed.

**Mitigation:** every session for `owner`, `cp45mgr` and `cp45emp` was revoked,
and the committed tokens were re-tested afterwards — **access 401, refresh 401**.
They are dead. History was **not** rewritten: the protocol forbids force-pushing
shared history, and invalidating the credential is the fix that actually matters.

No password, `.env` value or database dump was ever committed. The lesson: work
files belong in the scratchpad, never inside a repository working tree.

## Phase H0 ✅ — Transfers truth and workflow audit (read-only)

Full findings: [`docs/25_TRANSFERS_AUDIT_AND_DECISIONS.md`](docs/25_TRANSFERS_AUDIT_AND_DECISIONS.md).

**Transfers today = serialized units moving between branches of one company.**
Lifecycle is `ready_to_ship → in_transit → received | cancelled`. There is no
draft, no approval and no rejection — the enum names them as "future
(design-only)" and they were never built.

### The four findings that matter

1. **One permission guards everything.** All five mutating routes use
   `unit.transfer`, and **all three roles hold it, Store Employee included** —
   confirmed from the role matrix and live against the API. A Store Employee can
   create, ship, receive, confirm and cancel. Branch assignment is the only real
   constraint, and it is enforced correctly (ship/cancel need the source branch,
   receive needs the destination) — so an employee assigned to **both** branches
   can run a whole transfer alone.
2. **Creating a transfer reserves nothing.** The unit stays `in_stock` and fully
   sellable — verified live (`status=in_stock, canPrice=true` for a unit sitting
   in an open transfer). It can be sold out from under a promised transfer; the
   clash only surfaces later at `ship`.
3. **Two open transfers can claim the same unit** — verified live, the second
   create returned **201**. And there is **no idempotency anywhere**: a retried
   `POST /transfers` makes a second transfer.
4. **Quantity stock cannot be transferred at all.** The DTO takes only IMEI/serial
   identifiers. `TransferItem.productId` and `quantity` exist in the schema and
   are dead. This is a product gap, not a bug.

**Mobile has no transfer UI whatsoever** — no screens, no calls to `/transfers`,
only an unused query key plus status labels and tones. The backend emits transfer
notifications the Owner can now see (CP4.5), and tapping one has nowhere to go.

### Verified intact

The CP3 pricing invariant holds: request and ship do **not** touch the override;
receipt invalidates it atomically with the branch move; the row is deleted so a
returning phone cannot resurrect it; history records `initiator='system'`,
`reason='branch_transfer'`. Cross-company destination fails closed (404), same
branch 400, sold/unknown/wrong-branch units 400, deactivated user 401.

### Session-token incident — re-verified closed

The file is absent from every working tree and every current HEAD, and is not
staged. All `owner` sessions show **84 total, 0 live**. The committed tokens were
re-tested against the running API: **access 401, refresh 401 — both dead.** A
value-free history scan found **no** JWT secret, seed password or database
credential in any commit of any repository. History was not rewritten, per
protocol. `CLAUDE.md` now **requires** scratch and tooling files to live in an OS
temporary directory outside every repository, and requires invalidating a leaked
credential rather than force-pushing.

## Transfer decisions — ANSWERED (2026-08-07)

| Decision | Answer |
|---|---|
| Who does what | **Option A** — Employee requests · Manager/Owner approves or rejects · source ships · destination receives · Manager/Owner cancels after shipment |
| No Manager present | **Owner approves remotely** — still `transfer.approve` **in the source branch**, so branch scoping is unchanged |
| Quantity accessories | **Transferable — in H1** |
| Stock stops being sellable | **At request** |

Recorded in [`docs/21` §6b](docs/21_PRODUCT_DECISIONS.md) and
[`docs/25` §8/§10](docs/25_TRANSFERS_AUDIT_AND_DECISIONS.md).

### Two findings that shape the work

- **Serialized reservation is nearly free.** `UnitStatus.reserved` already
  exists and is unused, the unit state machine already allows
  `in_stock ↔ reserved`, and `assertSellable` already refuses anything that is
  not `in_stock` — so reserved stock stops being sellable with no enum migration.
  *(Caveat for H1: the state machine also permits `reserved → sold`, which Sell
  refuses. Harmless today, but the two should be made to agree.)*
- **Quantity reservation has no primitive.** `StockItem` has only `quantity`, so
  it needs `reservedQuantity`, and sellable quantity becomes
  `quantity − reservedQuantity` **everywhere stock is checked, including Sell**.
  This is the largest piece of H1.

### Still open, small enough to settle during H1

- **Destination cost for quantity stock** — weighted average, or carry source
  cost? Affects margin, so it is a product decision.
- **Destination price for quantity stock** — recommend the CP3 rule: destination
  keeps its own price, else company default; never inherit the source's.
- Partial receipt · cancellation/rejection reasons · which transitions notify the
  Owner · history grouping · shipment photos.

## Phase H1.1 ✅ — reservation and idempotency (backend `d3ea0c6`, mobile `84b5b84`)

Migration **`0030_transfer_reservation_and_idempotency`**. Closes both
stock-integrity defects the H0 audit proved live.

**Reserve at request.** A request moves every unit `in_stock → reserved` in the
same transaction as the transfer. Sell and Pricing already demanded `in_stock`,
so a promised phone stopped being sellable and priceable with no change to
either.

**One active claim.** A compare-and-swap — `updateMany` with
`status: 'in_stock'` in the WHERE. MySQL row-locks the UPDATE until commit, so a
concurrent request blocks, re-reads a `reserved` row and matches nothing.
Exactly one transaction can see the unit free. An application read could not
promise that: true when checked, false when acted on.

**Idempotency.** `clientUuid` mandatory, with a payload fingerprint under
`UNIQUE (company_id, client_uuid)`. Replay returns the original; a different
payload under the same key is 409; identifier order is normalised; duplicates in
one request are **reported**, not silently deduplicated.

**Quantity foundation.** `StockItem.reservedQuantity` + two CHECKs (non-negative,
never above physical). `quantity` stays PHYSICAL and is never reduced to express
unavailability — reserved goods are still owned and still valued. Sell consumes
only `quantity − reservedQuantity`. **No quantity transfer lines yet** (H1.4).

### The two defects the live races found

| Found by running it | Fix |
|---|---|
| **Sell and a transfer request both returned 201** — Sell's unit write was blind, so a transfer reserved the phone between `assertSellable` and the write and the sale stamped it `sold` anyway. A phone both sold and promised, both callers told "success" | Sell now CLAIMS the unit with a compare-and-swap; loser gets 409 |
| **Concurrent identical requests** — the loser reported a conflict for work that had succeeded, because only `P2002` was treated as a race and the reservation swap can lose first | Both paths look up the request id and return the winner's transfer |

**Races: 32/32** against the running API and real MySQL — both races above,
replay, reordering, cross-payload 409, missing key, cancel release, ship and
receive retries, quantity availability, all three database invariants, and
valuation unchanged by reservation.

### Backup and deployment

- **Backup:** `~/erp-backups/phonestore-20260808-035107.sql` — 55 tables, 4
  triggers, 0 raw `_binary`, valid UTF-8. DEFINER-safe restore proven **before**
  migrating: 55/55 tables, 4/4 triggers, `sum_total = 10051.00`, and units,
  sales and stock_items ID checksums byte-identical to live.
- **Legacy audit:** zero transfers, zero items, **zero duplicate active claims**,
  zero reserved/in-transit units — so `0030` invented no reservation. *A
  production database needs this audit rerun before deploying.*
- **Deployment proved** on the restored pre-migration database (11 units, 7 sales,
  `sum_total` preserved, every stock row reserved 0), on a clean database from
  zero, on dev, and on rerun. Four triggers intact throughout. Reverse SQL is in
  the `0030` commit message.

### 🔴 Unresolved — the permission gap (H1.2)

`unit.transfer` still guards request, ship, receive and cancel alike, and
**all three roles still hold it**. A Store Employee assigned to both branches can
still run a transfer end to end alone. H1.1 deliberately did not touch this;
it is **recorded as an unresolved authorization gap, not approved behaviour**.

Also deferred: cancellation after shipment still rewrites the unit's branch back
to source without proof it physically returned (H1.3).

## H1.2 ✅ — permission split + serialized approval lifecycle

Full detail: [`docs/25` §10b](docs/25_TRANSFERS_AUDIT_AND_DECISIONS.md).

**The H0 authorization gap is closed.** `unit.transfer` guarded request, ship,
receive and cancel alike and all three roles held it. It now guards **nothing**
(zero production call sites, verified by grep) and is revoked from both store
roles. Six stable keys replaced it, and an employee holds neither `approve` nor
general `cancel`.

**Lifecycle:** `pending_approval → approved → in_transit → received`, with
`rejected` and `cancelled` as terminal exits. Both pre-shipment states hold
units **reserved**, so H1.1's guarantee still runs from the moment stock is
promised. Nothing leaves `in_transit` except `received` — cancelling a shipment
would mean guessing where the goods physically are.

**Auto-approval:** a requester who already holds `transfer.approve` here creates
an approved transfer, flagged `auto_approved` so the trail never shows an
approved transfer with no approver.

**Concurrency:** every transition carries `expectedVersion` through one
compare-and-swap helper. Live: approve-vs-reject and ship-vs-cancel each have
exactly one winner; a stale approval is 409.

### Two defects found by verification, not by the suite

1. **A manager could not cancel at all.** The cancel route is guarded on
   `transfer.cancel_own`, `PermissionsGuard` requires ALL listed permissions, and
   `0031` gave managers only `transfer.cancel`. Fixed by `0032`: the route takes
   the **narrow** key (everyone who cancels holds it) and breadth stays a service
   decision. Guarding on the broad key would have locked employees out instead.
2. **A broken build was pushed.** Commit `0026790` changed the `TransferStatus`
   enum but left the state machine and its spec on `ready_to_ship`, so `tsc`
   failed. Repaired in the very next commit (`04e1463`) and recorded rather than
   quietly amended.

### Legacy remap rule (for a production database)

`ready_to_ship` → `approved`: such a row was created and could ship, which is
what `approved` now means. Nothing is marked received, and `approved_by` stays
NULL with `auto_approved` false, so no decision is invented. Development held
zero transfers, so the remap was a no-op here — **rerun the H1.1 legacy audit
before deploying `0031` anywhere with real transfer history.**

### ✅ CLOSED by H1.3 — the invisibility gap H1.2 deferred

Every lifecycle transition now notifies the people it concerns, in the same
transaction as the transition. A pending request no longer sits unseen.

## H1.3 ✅ — transfer notifications and the mobile workflow

Full detail: [`docs/25` §10c/§10d](docs/25_TRANSFERS_AUDIT_AND_DECISIONS.md).

**Migration `0033`** adds two nullable columns and one unique index to
`notifications`: `dedupe_key` with `UNIQUE (company_id, target_user_id,
dedupe_key)`, so a duplicate is an INSERT the **database** rejects rather than
one the application tries to avoid; and `payload JSON`, so the app can compose
the message in Arabic instead of reading server-written English forever.
Additive only — all 41 existing notifications work unchanged with both NULL.

**Seven events notify**, with recipients resolved from **permissions in the
relevant branch** (never role names), deduplicated, actor excluded. A refusal
goes only to the requester. Every action link opens the exact transfer.

**The list contract was rebuilt**: status filter, SQL search (reference, both
branch names, product, IMEI/serial) and keyset paging on the UUIDv7 key, plus a
bounded `/transfers/counts`. Detail returns, per action, whether it is allowed,
**why not**, and the branch it must be performed from — which is what lets a
notification opened in the wrong branch offer "Switch to X" rather than refuse.

**Mobile now has the whole workflow**: entry point with counts, list with
history tabs and search, detail with a timeline and branch-aware actions,
scan-first create with duplicate/accessory refusals and a reused request id, and
localised notifications.

### CP1 — the seven H1.2 requirements, reconciled

All seven already held; **no production behaviour needed fixing**. They had no
standing test, and Manager/Owner auto-approval on create was never clearly
evidenced — both fixed by 25 tests. The cancel-key compromise (managers hold
`transfer.cancel_own` only to pass the route guard) is now documented in
`docs/25` §10c as a known decision, not a puzzle.

### Three defects found by running it, not by the suite

1. **Recipient resolution never worked at all.** `holdersOf` filtered on
   `role: { permissions: … }`, but `Role` declares **`rolePermissions`**. Real
   Prisma rejected the query, so `POST /transfers` answered **400 for every
   request** — the feature was dead on arrival. The suite stayed green because
   the test double had been written to the same wrong assumption. The double
   now throws on any unrecognised `role` filter key.
2. **`?limit=` was a 400 for every client.** Query parameters arrive as strings
   and the global pipe runs with `enableImplicitConversion: false`; service
   tests pass a number and never touch the pipe. Fixed and pinned by DTO-level
   tests that go *through* validation.
3. **An existing broadcast defect, found while auditing** — see below.

### 🔴 Open — untargeted notifications are company-wide

`listForUser` scopes on `targetUserId = me OR targetUserId IS NULL` and **never
reads `branch_id`**, so a notification with no target user reaches every user in
the company whatever branch it names — and `markRead` marks the shared row, so
one person reading a broadcast marks it read for everyone. The old
`transfer.incoming`/`transfer.received` emits worked exactly that way, *after*
the transaction. Transfers no longer use that path, but **`closing.completed`
and any future untargeted type still do.** Fixing it means deciding what a
broadcast means (branch-scoped visibility plus per-user read state) — a
notifications phase, not a transfers one.

## Next exact action

**H1.3 is complete. Nothing is authorised beyond it.**

The intended next phase is **H1.4 — quantity-tracked accessory transfers**:
partial quantities, writing `StockItem.reservedQuantity` (the column and its
CHECKs exist since `0030` but nothing ever writes it), weighted-average
destination cost, and independent destination selling prices.

**H1.4 is blocked on two product decisions** still open in
[`docs/21` §6b](docs/21_PRODUCT_DECISIONS.md): the destination **cost** rule
(weighted average vs carry source cost — it changes margin) and confirmation of
the destination **price** rule (recommended: the destination keeps its own
price, else the company default; never inherit the source's).

Also still open, in dependency order: partial receipt and
discrepancy/return-to-source (which is what would let a shipped transfer be
cancelled safely) · proof photos · the broadcast-notification defect above.

**Deferred — do not start without the user:** G2B pricing proposals · Returns ·
Suppliers · consignment (must not reuse the transfer model) · loans · expenses ·
subscriptions · WhatsApp · authentication · technician functionality.

### Device pass still outstanding

The transfer workflow has **never been touched on a device**. Camera scanning,
haptics, sheet gestures, Arabic visual RTL and the whole action flow are
unverified by anything but a browser and a test runner.
[`docs/24` §9b](docs/24_DEVICE_QA_CHECKLIST.md) adds 31 transfer checks for the
user's own pass.

## Completed milestones

- Design-system foundation: tokens, i18n (EN/AR + RTL), primitives, overlays,
  camera scanner, Product Confirmation Card, frontend permission awareness
- Screens: Sell (POS), Receive, Inventory, Catalog, Analytics, Daily closing
- Inventory cursor pagination + server-side search · scanner confidence
  correction · durable recognition outbox (transactional, lease-based, no Redis)
  · purchase idempotency
- Role migration to Owner / Store Manager / Store Employee (`0016`–`0018`), with
  a SQL-vs-TypeScript drift test
- **Phase E — Settings foundation (`0019`)**: `company_settings`,
  `receiving_accounts`, Owner Settings screen in EN/AR
- Backup/restore hardened: `--hex-blob` mandatory, tested dump sanitiser,
  restore drill verified end to end
- **F1 — Users/auth:** Stage 1 contactable users (`0020`) · F1.1 session-bound
  access tokens + atomic deactivation revocation · Stage 2 branch-scoped
  `price.edit` delegation
- **Stage 3.1** — fail-closed device recognition, multi-company credential-key
  scoping, secret-exposure regression tests
- **Stage 3.2** — Store Account ID (`0024`) and mobile Store ID login
- **Stage 4A** — OTP challenge/intent schema (`0025`); inactive, no provider
  configured, new-device login still blocks on `device_unrecognized`
- **Phase G1 — Product Catalog: complete** (backend `b3cfcbc`, mobile `65edca8`).
  `catalog.manage` (`0026`), paginated/filtered `GET /products`, detail, metadata
  `PATCH`, archive/restore, the real-MySQL JSON specification-search fix, legacy
  `GET /products/all` removed; mobile catalog list, detail, **one shared
  `ProductForm`** for create and edit, scanner, category management, EN/AR
- **Phase H1.3 — transfer notifications and the mobile workflow: complete**
  (`0033`). Serialized transfers are usable end to end, on the phone.
- **Phase H1.2 — permission split and approval lifecycle: complete**
  (`0031`, `0032`).
- **Phase H1.1 — reservation and idempotency: complete** (`0030`).
- **Phase H0 — Transfers audit: complete (read-only).** Findings and workflow
  options in `docs/25`; blocked on the user's decisions.
- **Phase G2A — Pricing Foundation: CP1–CP4.5 complete.** Mobile pricing UI
  landed in CP4 and was verified by driving the app in CP4.5; in-app
  notifications now exist. Device pass still outstanding.
- **Phase G2A backend: CP1, CP2 and CP3.** Audit, schema
  (`0027`), and the full backend pricing behaviour — resolver, API,
  authorization, concurrency, below-cost, atomic history, Owner notifications,
  transfer invalidation and Sell integration (`0028`, `0029`).

## Standing lessons

- **A mocked filter can hide a database-behaviour defect.** G1's specification
  search returned nothing on real MySQL while the suite stayed green, because the
  unit double was more permissive than the database. This is why CP2's
  constraints were proven against real MySQL rather than mocked.
- **A double written from the same assumption as the code proves only that you
  are consistent.** H1.3's recipient query filtered on a relation name `Role`
  does not have; real Prisma rejected it and `POST /transfers` was a 400 for
  every request, while 92 tests stayed green — because the double accepted the
  same wrong name. A double must be built from the schema, and should **throw**
  on shapes the database would reject rather than quietly tolerate them.
- **A service test never touches the validation pipe.** `?limit=` was a 400 for
  every client because a query parameter arrives as a string and the global pipe
  does not implicitly convert. Anything a client sends as text needs a test that
  goes *through* validation, not around it.
- **A guard that also resolves context changes behaviour for every route that
  skips the guard.** CP3's branch resolution lived in `PermissionsGuard`, so
  routes needing no permission silently had no branch. Only a real request
  through the real stack showed it.
- **Nothing fails when a guard is merely absent.** The `audit_logs` triggers were
  missing from every clean deployment for as long as they lived in a manual
  script, and no test, migration or startup check noticed. Protection belongs in
  the migration chain, not in a runbook.
- **A guard that also resolves context changes behaviour for every route that
  skips it.** CP3 put branch resolution in `PermissionsGuard`; CP4's preflight
  found it had silently left unguarded routes with no branch — and cost gating
  turned that into a lock-out. Only a real request through the real stack showed
  either.
- **An interceptor must not decide authorization.** Cost gating exists to strip
  fields. When it was allowed to throw, it failed requests that guards had
  already cleared.
- **Compiling is not working.** CP4 passed TypeScript, lint and a web export and
  still shipped a sold phone that could be priced, a conflict dialog that quoted
  the wrong price, and a Notifications screen that did not exist. Running the app
  found all three in one session.
- **A screen with no entry point is a dead route.** Notifications had a query key
  and no way in; the pricing screens were only ever reached by typed URLs until
  CP4.5 exercised the real buttons.
- **A single permission guarding a whole workflow is a workflow with no
  controls.** `unit.transfer` gates request, ship, receive and cancel alike, so
  the feature has no second pair of eyes anywhere — separation of duties has to
  be designed in, it does not emerge.
- **Nothing is reserved until something says it is.** Transfers promised stock
  without holding it, so the same phone could be sold or promised twice. Fixed in
  H1.1 by reserving at request.
- **A blind update is not a claim.** Sell overwrote a unit's status without
  checking what it was, so a sale and a transfer could both "succeed" on the same
  phone. Any write that takes exclusive ownership of a row must state the state it
  expects — and only a real concurrent race showed it.
- **A Git rollback does not roll back the database.** Restoring the dump is a
  separate, deliberate step.
- **`prisma migrate deploy` never runs the seed**, so anything reference-like
  must live in a migration.
- Authorisation is **permission-based, never role-name-based**, and anything not
  in the `COMPANY_PERMISSIONS` allowlist is branch-scoped and fail-closed.
