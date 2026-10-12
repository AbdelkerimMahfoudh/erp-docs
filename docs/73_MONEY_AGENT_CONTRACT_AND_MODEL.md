# 73 — The Money Services Agent activity: contract and model (2026-10-08, checkpoint 1)

The owner's brief of 2026-10-08: a new activity for independent agents who exchange cash for Bankily, Sedad or other
providers' digital credit — a transaction register, balances and reports — chosen per branch on the subscription
website, beside or instead of the electronics store. This page is **checkpoint 1**: the rules mapped, the model and
its equations with worked examples, the configuration blanks the owner left open, and the test plan — written
**before the first schema edit**, as the brief asks. Decisions **D153–D157** in `docs/21`. The Keep defect the brief
asked to fix first is D153 (backend `258b04d`, mobile `bf30299`).

> **Status.** Nothing on live is touched; no real agent transaction can be recorded until a provider's rate and
> settlement configuration is complete (§1.2) and the owner approves enabling it. The disposable rehearsal and the
> HTTP journeys use clearly labelled invented rates.

---

## 1. The binding decisions and the blanks

### 1.1 Approved (the brief, recorded as D154–D157)

| # | Rule |
|---|---|
| A1 | Activity is **per branch**: `electronics` (500 MRU/month), `money_agent` (300), `both` (700 — never 500 + 300). A company may mix branch types; one Owner, one subscription timeline. |
| A2 | The Owner may request another activity later without a new account. **Upgrade during a paid month: the difference at once** (agent→both 400, electronics→both 200). **Downgrade: at the next renewal.** The seat rules of 2026-10-05 (`docs/69` §1) are untouched. The quote is itemized and server-calculated; payment confirmation and activation follow the established flow. No ERP price, purchase prompt or payment instruction inside the customer app. |
| A3 | The app **records** agent transactions; it never initiates or verifies a transfer with a provider. Version 1: transaction history and business reports; **no customer receipt, no customer PDF**. |
| A4 | Commission = the whole amount × the provider's configured rate (never brackets); different providers, and — when a real schedule says so — different rates per direction; the exact rate/version and the calculated commission are preserved on every transaction. Earned at completion. **The commission destination and any provider deduction are configured explicitly; nothing guesses, no zero, no sample rate, no manual commission as a production fallback.** A provider with an incomplete configuration cannot post real transactions. |
| A5 | Two directions, unmistakable: **Receive cash / Send digital credit** (agent cash ↑, that provider's float ↓) and **Give cash / Receive digital credit** (cash ↓, float ↑). Before confirmation: amount, provider, direction, both principal movements, the commission and its configured settlement. Exchanged principal is never revenue; commission is. |
| A6 | Required data: branch, provider, direction, amount, **customer number (mandatory, separate from the provider reference)**, provider reference per the provider's rule, server-calculated commission with its configuration snapshot, server timestamp and business day, **the authenticated person** (derived on the server; a name snapshot kept; never a form field, never a client-supplied employee id). |
| A7 | An Employee records and may report a mistake; the Owner or a Manager performs an audited reversal that counters every leg and the commission **exactly once**, keeping the original. Nothing completed is edited or deleted. |
| A8 | A distinct **rebalancing** operation (buying float, moving money between cash and a provider) that never inflates count, volume or commission. |
| A9 | Cash and each provider's float are separate, per branch. A combined branch has **one** physical cash drawer, counted once, and **one** daily closing. Unknown stays unknown, never zero; no fabricated expected total; negative positions are shown as what they are. The existing business-day boundary (06:00, early start) applies. |
| A10 | Offline recording with a persistent client UUID, secure user/company/branch-scoped storage, "Pending synchronization" and "Provisional" labels, idempotent retries, drafts that survive restarts, no cross-account leakage, explicit handling of two devices, stale configuration, entitlement changes, day rollover, reversals and conflicts; the day is not finalized while the branch has unsynchronized transactions; a provisional record is never shown as confirmed. |
| A11 | Website: Electronics / Money services / Both for the first branch and for later branch or activity requests; Super Admin sees activity and price components with versioned decisions and audit. Mobile: agent-only branches get Home · Transactions · Money · Reports · More and no electronics actions; electronics-only branches are unchanged; combined branches get both without a crowded tab bar. EN/FR/AR with parity and RTL; an independent agent is never called a bank employee. |

### 1.2 The blanks — configuration, never guessed

> **Superseded 2026-10-12 by D164** (`docs/75`, §12 below): there is no rate, destination or deduction; the employee types the commission the customer pays, for every exchange. Kept as the record of exchanges marked `legacy_rate`.

Each is a **field of the provider configuration** (§4.2) that the Owner fills in from the real schedule. While any
required one is blank for a provider, that provider's `readyForTransactions` is false: the counter screen lists it as
*Not set up yet*, `POST /agent/transactions` answers 409 `provider_not_configured`, and nothing is ever posted with a
zero, a sample or a typed commission.

| Blank | Field | Required before the provider can post |
|---|---|---|
| Bankily commission rate | `rate_in_bp` / `rate_out_bp` on the Bankily provider's configuration version | yes (both, or one with `same_rate_both_directions = true`) |
| Sedad commission rate | the same, on Sedad | yes |
| Other providers' rates | the same, on each `other` provider | yes |
| Same rate in both directions? | `same_rate_both_directions` (true → one rate copied to both; false → two rates) | yes |
| Where the commission lands | `commission_destination`: `cash` · `provider_float` · `held_separately` · *(unset)* | yes |
| Fee deducted from the principal or settled separately | `principal_fee_mode`: `separate` · `deducted` · *(unset)* | yes |
| Which providers issue references and require them | `reference_rule`: `required` · `optional` · `none` · *(unset)* | yes |

Test fixtures use **invented** rates (1.00 % both directions, settled separately, credited to the provider float,
reference optional) and say so in their names; they never reach a production configuration.

---

## 2. What exists, and what binds this feature

| Area | What is there today (verified in code) | What this feature does with it |
|---|---|---|
| **Pricing** | One plan `standard`, versioned (`plan_versions`: v1 500/2/100, v2 500/1/100 from `0086`); `quoteFor(size, plan)` is pure and integer-only (`src/billing/pricing-rules.ts`): `branchFee = activeBranchCount × branchMonthly`, `staffFee = Σ paidSeats × 100`; `assessPeriod` keeps a per-component **high-water mark** (no prorating: growth costs the whole month at once, a release lands at the next renewal); `openPeriod` freezes the unit prices into `billing_periods` at approval; `extend` only moves `current_period_end` — **no renewal roll exists**. The census (`seat-census.ts`) counts every active branch, warehouses included. | Plan **v3** adds the three activity prices; `branchFee = Σ activityFee(branch)`; the seat terms unchanged. **Renewal is defined** (D154): the Super Admin's extension/approval that moves the period end forward closes the current billing period and opens the next one, applying scheduled downgrades first. Warehouses stay `electronics` (billed as today) and cannot be agent branches. |
| **Requests** | `seat_allocations` (kind `seat` / `store`, `pending_payment → paid / granted / …`), the Owner's `POST platform/my-subscription/{seat,store}-requests`, the Super Admin's confirm-payment / refuse / release with a reference and a version guard; the store is created at confirmation. | A store request carries the new store's **activity**; a new kind **`activity`** carries a branch's activity change: an upgrade is `pending_payment` for **the difference** and applies at confirmation (`assessNow` raises the period); a downgrade is recorded at once as `activity_next`, free, applied at the next renewal. |
| **Roles** | Permission-based everywhere; the catalogue and matrix live in `src/rbac/role-permissions.ts` (64 keys), mirrored by SQL migrations (`role-matrix-drift.spec.ts`), with Owner-only money keys outside the Administrator's blacklist (`money.anchor.record`, `closing.perform`, …). Store Manager 42 keys (reports and confirms money, requests corrections), Store Employee 20 (records and reports). | Nine new keys (§7), granted exactly as the catalogue's patterns: the counter records and reports; the Manager reverses and rebalances; the Owner alone sets positions and configures providers. |
| **Money & closing** | Per-branch cash drawer with the pinned equation `expected = opening + salesIn − refundsOut − supplierOut − expensesOut + correctionsIn − correctionsOut (+ set adjustment)` (`reconciliation.spec.ts`, `channels.ts`), counted and locked once a day; company-wide receiving accounts anchored by the Owner (D89, `money_anchors`); the opening decision (D100–D102, D146, D153); `trackedMoney` with each method's day movement (D152). | **Agent cash is the drawer's cash.** Two new components, `agentIn` / `agentOut`, enter the same equation on every path (the report's channel row, the closing's independent check, the rollup) — one physical cash, one figure. **Provider floats are per-branch positions** (`agent_positions`), anchored by the Owner and compared at the same closing (`agent_float_counts`), with the existing discrepancy workflow. |
| **Receiving accounts vs floats** | A company-wide Bankily *receiving account* is where an **electronics sale's** money lands (D98/D102: company scope, Owner-anchored, shown on Money for every shop). | An agent's Bankily **float** is the branch's own stock of digital credit it sells and buys at the counter. Same provider name, different money: the float is a per-branch inventory of credit, the receiving account is the company's till for sales. They are never the same row, never summed, and a float is never "reused because the label matches" (A9). |
| **Offline** | Milestone J: a file queue (`lib/offline/queue*.ts`) scoped by company/branch/user, idempotent replay with a client UUID, timeout-as-uncertain, `needs_attention`; drafts (`lib/offline/drafts.ts`) in a scoped envelope with forbidden-content checks; **only money-neutral reports are queueable** (`policy.ts`). SecureStore exists (2 KB per value). | D155 supersedes that rule for **one** kind: `agent.exchange.record` is queueable because it is the counter's report of an exchange that already happened physically; the server still decides everything (§5.3). |
| **Entitlement** | Company-level read/write gate (`EntitlementInterceptor`), per-store seat math, `GET /entitlement` always readable. Milestone K: no feature flags, no per-feature tiers. | D156 supersedes Milestone K for **activity**: a branch's activity gates which money routes it may write (agent routes need `money_agent`/`both`; sell/receive need `electronics`/`both`), with a stable 403 `activity_not_subscribed`. The app learns each branch's activity from `GET /entitlement` (`seatsByStore[].activity`) — a flag, never a price. |
| **Rules that bind** | Nothing financial hard-deleted; corrections are reversals with audit; rules on the server; no prices in the app; the business day assigned by the server; Owner-only company actions; customer numbers masked and never logged (`docs/04` 19f, `docs/64`); backups before any migration (`docs/22`); device claims only as NOT DEVICE VERIFIED without a phone (`docs/70` §7). | All kept. |

---

## 3. Activity and pricing — model, equations, examples

### 3.1 Model (migration `0088`, additive)

- `branches.activity ENUM('electronics','money_agent','both') NOT NULL DEFAULT 'electronics'` — every existing branch
  backfills to `electronics`, so no invoice moves; `branches.activity_next ENUM(...) NULL` — a scheduled downgrade,
  applied at the next renewal; `branches.activity_changed_at`.
- `plan_versions` + `billing_periods` gain `agent_monthly`, `both_monthly` (v1 and v2 rows backfilled with 300/700 so
  an old period still re-prices with its own copied figures); **plan version 3** = 500 / 300 / 700 / 1 included seat /
  100 per extra seat, in force from the migration.
- `seat_allocations.kind` gains `activity`; new columns `activity_from`, `activity_to`, `effective` (`now` | `renewal`).
  A store request records the requested activity in `activity_to`.
- `billing_periods` gains `assessed_activity_fee_by_branch JSON` so an upgrade's "difference" is the branch's own.

### 3.2 Equations (pure, `pricing-rules.ts`)

```
activityFee(b)   = { electronics: 500, money_agent: 300, both: 700 }[b.activity]       (plan v3 figures)
branchFee        = Σ activityFee(b) over active branches                                 (was count × 500)
seatFee(b)       = paidSeats(b) × 100 ;  staffFee = Σ seatFee(b)                          (unchanged)
monthlyTotal     = branchFee + staffFee
upgrade now      = activityFee(to) − activityFee(from)  > 0 → a request for exactly that difference, this period
downgrade        = activityFee(to) − activityFee(from)  < 0 → activity_next = to; applied at the next renewal; no refund
period assessed  = max(previously assessed, today's quote), per component (unchanged high-water rule)
```

An upgrade applies the new activity at payment confirmation and calls `assessNow`: the period's branch fee rises by
the difference; the next renewal prices the branch at its new activity in full. A downgrade changes nothing this
period; at the renewal the branch takes `activity_next`, the new period is opened at the new size. A sideways change
(`electronics → money_agent`, 500 → 300) is a downgrade; (`money_agent → electronics`, 300 → 500) an upgrade of 200.

**The renewal, precisely (D154 a, refined 2026-10-09 after review):** a renewal is the moment the next paid period
begins — the later of the current period's end and the Super Admin's action. An approval, an extension or a lengthening
period-end change on a company whose latest billing period has already ended rolls at once (scheduled changes applied,
the ended period kept as it was, the next period opened at the new size). The same actions on a company whose period
is **still running** (the Owner prepaid) only move the end: the roll is **due at the old period's end** and is applied
the first time the company is evaluated after that instant (every authenticated request passes through the
entitlement check, which applies a due roll once, race-safe, with no scheduler and no new column: "due" ⇔ the latest
billing period ended and the subscription's end lies beyond it). Shortening never renews. The upgrade difference is
charged only against a **running paid month** and priced with that period's own copied prices (a plan version scheduled
mid-period changes nothing for it); with no paid period running — pending, lapsed, suspended — an upgrade is scheduled
like a downgrade and the next renewal prices the branch in full.

### 3.3 Worked examples (integer MRU)

| Business | Monthly | Why |
|---|---|---|
| one electronics store, Owner alone | **500** | as today |
| one money-agent branch, Owner alone | **300** | the agent price; the included seat as for any store |
| one money-agent branch, two employees | **400** | 300 + one paid seat (the seat rule is untouched) |
| one combined branch | **700** | never 500 + 300 |
| an electronics store and an agent branch | **800** | 500 + 300 |
| the same, one extra seat at the agent branch | **900** | + 100 |
| agent → both on the 12th of a paid month | **+400 now**, 700 from the renewal | the difference, immediately; the period's assessed branch fee rises 300 → 700 |
| electronics → both on the 12th | **+200 now**, 700 from the renewal | |
| both → agent on the 20th | **0 now**; 300 from the renewal | the downgrade waits; 700 stays assessed this period |
| both → agent on the 5th, then "keep both" on the 25th | 0, then **0** | the branch never stopped being `both` (700 is assessed this period): the request withdraws the scheduled downgrade; nothing is charged, nothing is refunded (corrected 2026-10-09 — an earlier draft said +400, which would have charged for a change that did not happen) |
| agent → both on the 25th of a lapsed month (no paid period running) | **0 now**; 700 from the renewal | the difference is only ever charged against a running paid month; otherwise the change is scheduled and the next renewal prices the branch in full |
| both → agent scheduled, the Owner pays the next month early on the 20th | 0 now; `both` kept until the paid month ends; 300 from the day the old month ends | a renewal is the moment the next paid period begins — the later of the old period's end and the payment — never earlier |
| a warehouse | **500** | `electronics` by default, as billed today; a warehouse cannot be an agent branch |

---

## 4. The agent ledger — model and equations

### 4.1 Tables (migration `0089`, additive; every id `BINARY(16)` UUIDv7; every money column `DECIMAL(14,2)`)

| Table | Holds | Invariants |
|---|---|---|
| `agent_providers` | a company's providers: `kind` (`bankily`/`sedad`/`other`), `label`, `is_active`, `sort_order` | unique (company, label); never deleted |
| `agent_provider_configs` | **versioned** configuration per provider: `rate_in_bp`, `rate_out_bp` (basis points, NULL = blank), `same_rate_both_directions`, `commission_destination`, `principal_fee_mode`, `reference_rule`, `effective_from`, `recorded_by`, `reason` | append-only; the version in force = the latest `effective_from ≤ now`; `ready_for_transactions` is computed, never stored |
| `agent_positions` | per branch per account (`cash` is the drawer — see §4.5 — so rows exist only for `provider` and `commission_held` accounts): the latest **anchor** (`amount`, `at`, `business_date`, `recorded_by`, `source` = `set` / `confirmed` / `counted_close`) | append-only like `money_anchors`; no row = unknown |
| `agent_transactions` | the customer exchange: `branch_id`, `provider_id`, `direction` (`cash_in_credit_out` / `cash_out_credit_in`), `amount`, `customer_number` (normalized, see §4.6), `customer_number_last4`, `provider_reference`, `commission_amount`, `commission_rate_bp`, `config_version_id`, `config_snapshot JSON`, `business_date`, `recorded_at` (server), `device_recorded_at` (the phone's claim, informational), `recorded_by_id`, `recorded_by_name`, `client_uuid`, `client_request_hash`, `status` (`completed` / `reversed`), `reversed_by_id`, `reversed_at`, `reversal_reason` | unique (company, client_uuid); a changed payload under the same key is 409 `idempotency_conflict`; never updated except `status`/reversal fields, once |
| `agent_movements` | the immutable legs: `branch_id`, `account` (`cash` / `provider:<id>` / `commission_held:<id>` / `external`), `direction` (`in`/`out`), `amount`, `kind` (`principal` / `commission` / `reversal` / `rebalancing`), `source_transaction_id` / `source_rebalancing_id`, `business_date`, `recorded_at` | append-only; the only thing positions and the closing read |
| `agent_rebalancings` | `branch_id`, `reason`, `note`, legs (in `agent_movements`), `external_counterparty` (`owner_capital` / `provider_settlement` / `other`, with a note) when the legs do not net to zero, `recorded_by`, `client_uuid` | ≥ 1 leg; legs net to zero unless an external counterparty is declared for exactly the difference |
| `agent_mistake_reports` | an Employee's claim about a transaction: `transaction_id`, `kind` (`wrong_amount` / `wrong_direction` / `wrong_provider` / `wrong_number` / `other`), `note`, `status` (`open` / `reversed` / `dismissed`), decided by, when | moves nothing |
| `agent_float_counts` | at the daily closing, per provider: `closing_id`, `provider_id`, `expected` (NULL when unknown), `counted`, `difference`, `explanation`, `counted_by`, `counted_at` | unique (closing, provider); a `closing_discrepancies` row (new nullable `agent_float_count_id`) when the difference is not zero |

### 4.2 Commission and settlement — the configured matrix

> **Superseded 2026-10-12 by D164** (`docs/75`, §12 below): there is no rate, destination or deduction; the employee types the commission the customer pays, for every exchange. Kept as the record of exchanges marked `legacy_rate`.

With `A` the amount, `r` the rate for the direction, `C = round2(A × r)` — counted exactly in whole cents and basis points, a half cent up (837 MRU at 0.50 % is 4.19; reviewed 2026-10-09, backend `292991c`):

| `principal_fee_mode` | `commission_destination` | Legs posted at completion |
|---|---|---|
| `separate` | `provider_float` | principal legs on cash and the float for `A`; a **commission leg** `in` on the float for `C` |
| `separate` | `cash` | principal legs for `A`; a commission leg `in` on cash for `C` (the drawer gains `C`: an `agentIn` component) |
| `separate` | `held_separately` | principal legs for `A`; a commission leg `in` on `commission_held:<provider>` for `C` — a third per-branch account, shown on Money as *Commission held by {provider}*, settled later by a rebalancing (`provider_settlement`) |
| `deducted` | `provider_float` | the float leg is **netted**: direction 1 `out` for `A − C`, direction 2 `in` for `A + C`; no separate commission leg; `commission_amount` is still recorded as earned |
| `deducted` | `cash` / `held_separately` | **refused as a configuration** (a provider cannot deduct from the principal and pay elsewhere) — the Owner is told why |
| any blank | any | the provider is not ready; nothing posts |

### 4.3 The two directions, in legs

```
Receive cash / Send digital credit (cash_in_credit_out), amount A:
    cash              in   A          → the drawer's agentIn
    provider:<id>     out  A          (or A − C when deducted)
    + commission per §4.2

Give cash / Receive digital credit (cash_out_credit_in), amount A:
    cash              out  A          → the drawer's agentOut
    provider:<id>     in   A          (or A + C when deducted)
    + commission per §4.2
```

**Reversal** (A7): every leg of the transaction gets one counter-leg of the same amount in the opposite direction, kind
`reversal`, on the day of the reversal; the transaction's `status` becomes `reversed`, with who, when and why; the
original rows stay; one audit entry. A reversed transaction cannot be reversed again (409 `already_reversed`); its
mistake report, if any, closes as `reversed`.

*As built (review of 2026-10-09):* a reversal and a rebalancing follow the exchange's **open-first** rule — refused
while the branch's current business day is closed or not opened (409 `store_closed`, "Nothing was reversed" /
"Nothing was moved"), before the write and again under the day's lock — because a cash leg posted on a locked day would
never reach the next opening (backend `df34c73`). **Reports book a reversal on the day it was made**, as its legs:
an exchange stands in its own period's figures unless it was reversed within that same period; a later reversal
appears on the later period's reversals line and its commission comes off that period's commission (which can then be
negative); a period that is over never changes (backend `af1512c`). A retry of the same reversal under the same key
answers with it, even when it raced its twin.

**Rebalancing** (A8): legs over the branch's internal accounts only — e.g. *buy Bankily float with cash*: cash `out`
100 000, `provider:bankily` `in` 100 000; *move credit Bankily → Sedad through cash*: two rebalancings, or one with
three legs; *the Owner brings cash in*: cash `in` 50 000 with `external_counterparty = owner_capital` for 50 000; *the
provider pays the held commission in cash*: cash `in` C, `commission_held` `out` C. Rebalancings never count as
transactions, never add to volume, never earn commission; reports list them on their own line.

### 4.4 Positions

```
position(branch, account) = latest anchor amount + Σ movements after the anchor's instant        (D89's rule)
unknown                   = no anchor → shown as Unknown with the day's movement beside it (D152's rule)
negative                  = shown as negative, in words and colour, with "more recorded out than in" — never hidden,
                            never zeroed; an opening cannot keep it (D153's rule applies to floats too)
```

### 4.5 Cash: one drawer, one closing

The agent's cash **is** the branch's drawer. No `agent_positions` row exists for cash: the drawer's position is the
existing one (opening decision or counted close + movements, D89/D102), and the agent legs enter it as two new
components of the pinned equation, on every path that computes it:

```
expected cash = opening + salesIn − refundsOut − supplierOut − expensesOut + correctionsIn − correctionsOut
                + agentIn − agentOut (+ set adjustment)
agentIn  = cash legs `in`  from agent_movements on the business day (principal, commission to cash, reversals, rebalancing)
agentOut = cash legs `out` from agent_movements on the business day
```

`channels.ts` gains the two components and their signs; `channelMovements`, the closing's independent check
(`const expectedCash`), the report's channel row and the rollup carry them; `reconciliation.spec.ts` pins them. The
drawer is counted once, as today. **Provider floats** join the same closing as `agent_float_counts`: for each active
provider of an agent branch, expected (or *Unknown*) vs counted, difference and explanation; a difference opens a
closing discrepancy with the existing resolution workflow. An agent-only branch has no electronics channels to count
beyond the drawer; a combined branch counts the drawer, the receiving-account channels **and** the floats in the one
closing. Locking is refused while a float of an active provider is uncounted (409 `float_count_required`, the same
shape as the drawer's), unless the provider is explicitly skipped with a reason, like a channel.

*As built:* a float counted for a day still behind the boundary is compared with the float at that day's end, and the
`counted_close` anchor its lock writes carries that same instant (the count instant on the day itself), so the next
morning's legs stay after it (backend `95e3a79`).

### 4.6 Customer numbers and references

- The number is **normalized** with the existing payer-number rule (`payer-number.ts`: digits, an optional leading
  `+`, Arabic-Indic digits mapped, 4–30 digits; no country assumed, no digit guessed) and stored once; `last4` is a
  separate column for the masked list and the masked search (`•••• 1234`). Lists and searches never return the full
  number; the detail returns it only to `agent.customer.reveal` holders; it never reaches logs, exports, notifications
  or reports (an allow-list spec, as for the payer number, D151).
- The provider reference is validated per `reference_rule` (required / optional / none) and kept apart from the
  number; a reference-only correction is a separate audited fact that moves nothing (the D151 pattern).

### 4.7 Worked examples (fixture rates: 1.00 % both directions, settled separately, credited to the float; **invented**)

> **Superseded 2026-10-12 by D164** (`docs/75`, §12 below): there is no rate, destination or deduction; the employee types the commission the customer pays, for every exchange. Kept as the record of exchanges marked `legacy_rate`.

| # | Event | Cash (drawer) | Bankily float | Sedad float | Commission (revenue) | Count / volume |
|---|---|---|---|---|---|---|
| 0 | Owner sets: drawer 10 000 (opening), Bankily 50 000, Sedad **unknown** | 10 000 | 50 000 | Unknown | — | — |
| 1 | Receive cash 20 000 / send Bankily credit | 30 000 | 50 000 − 20 000 + 200 = **30 200** | Unknown | 200 | 1 / 20 000 |
| 2 | Give cash 15 000 / receive Sedad credit | 15 000 | 30 200 | Unknown (+15 000 +150 moved today) | 350 | 2 / 35 000 |
| 3 | Reversal of #1 (wrong direction) | 35 000 | 30 200 + 20 000 − 200 = **50 000** | Unknown | 150 | 1 completed, 1 reversed / 15 000 |
| 4 | Rebalancing: buy 100 000 Bankily float with cash — refused: cash would go to −65 000 → recorded only if the Owner confirms the negative, shown as negative (*as built:* 409 `rebalancing_negative` naming each account and what it would read; `confirmNegative` is honoured only for `agent.position.set`, the Owner's; an unknown position refuses nothing) | 35 000 | 50 000 | | 150 | unchanged |
| 4' | Rebalancing: Owner brings 100 000 cash (`owner_capital`), then buys 100 000 float | 35 000 | 150 000 | | 150 | unchanged |
| 5 | Sedad set at 40 000 by the Owner at 14:00 | | | **40 000** + later movements | | |
| 6 | Closing: drawer counted 35 000 (0), Bankily counted 149 900 (−100 → discrepancy), Sedad counted 40 000 (0) | | | | | |

With `principal_fee_mode = deducted` on Bankily, event 1 would leave the float at 50 000 − (20 000 − 200) = 30 200 —
the same figure, by one netted leg instead of two, which is why the mode is a configuration and not a guess.

---

## 5. The phone

### 5.1 Navigation (D157)

| Branch activity | Tabs | Hidden |
|---|---|---|
| `money_agent` | **Home · Transactions · Money · Reports · More** | Stock, Sell, Receive, Returns, Catalog, Import, Partners (reachable from More only if the role has them and the company has electronics branches elsewhere) |
| `electronics` | unchanged: Home · (Partners) · Money · Stock · More | the agent screens |
| `both` | **Home · Exchanges · Money · Stock · More** (five); Partners moves to More for such a branch; agent Reports live under Money beside Results | — |

Proposed and rendered in a navigation test per activity and role before committing (checkpoint 4); the combined bar
is checked at 320 pt and 1.3× text in EN/FR/AR. Home for an agent branch: today's exchanges, commission, the drawer
and floats, a big **New exchange** action.

### 5.2 The counter flow

Direction first, as two large cards with the money arrows in words (*Receive cash → send {provider} credit* / *Give
cash → receive {provider} credit*); provider; amount; customer number (phone pad, `+` allowed); reference when the
provider requires it; then **one review**: both movements in words and figures, the commission and where it goes, and
*Confirm*. Short enough for a queue at the counter; nothing typed twice.

### 5.3 Offline (D155)

- `agent.exchange.record` is a **queueable** kind of the Milestone J queue, with a client UUID per draft; the
  **customer number is not written to the queue file**: it is kept in SecureStore under the draft's UUID (well under
  the 2 KB limit) and joined only when sending, so the file never carries a number. The queue is scoped by
  company/branch/user as today; another account on the same phone cannot read it.
- The phone shows queued exchanges as **Pending synchronization**, and the day's cash and float figures as
  **Provisional** (server position ± queued legs) until the queue is empty; a provisional record is never shown as
  confirmed, never gets a server timestamp.
- The server assigns the business day from the **posting instant** (the existing rule for money; the phone's time is
  kept as `device_recorded_at` and shown); two devices recording offline simply post in the order they sync; the same
  UUID again returns the same record; a changed payload under it is 409 `idempotency_conflict` → *needs attention*; a
  configuration version older than the one in force is 409 `stale_configuration` (both versions named) → *needs
  attention*, resent only by a person who sees the new rate; an expired or changed entitlement is 403 → *needs
  attention*; a reversal is never queued (online only, like every decision).
- Finalizing the day: the phone refuses to open the closing while its queue holds items for the branch; the server
  cannot see another device's queue, so the closing report also lists how many exchanges were posted after the day's
  count started (**a warning, not a guarantee**). Airplane mode, kill/relaunch, repeated taps and uncertain responses
  are **NOT DEVICE VERIFIED** until run on a phone (`docs/24` §61).

---

## 6. The website and the Super Admin

- **Apply**: a third field — Electronics / Money services / Both — for the first branch, with the price per month
  shown from `GET platform/plan` (v3 carries the three); the estimate (`POST platform/quote`) takes `activities[]`.
- **Account**: *Request another store* asks for its activity; *Change this branch's activity* shows the itemized
  difference (upgrade) or the renewal date (downgrade) from the server, then the established pending-payment state.
  *As built (review of 2026-10-09):* both read `GET platform/my-subscription/activity-options` — for every store but a
  warehouse, each other activity with the request's own decision (`now` / `renewal` / `keep` / `requested` /
  `refused` with its code), `dueNow` at the chargeable prices and `monthlyAfter` at the plan the next paid period opens
  at, and what a new store of each activity is charged — one pure function decides for the read and the request
  (`activity-decision.ts`), and a spec asks every offered option in every starting state. The page computes no charge.
- **Super Admin**: the seat-request queue shows `activity` requests with their components; a business page shows each
  branch's activity and the scheduled change; `platform/plans` edits the three prices; every decision is an audit event.

---

## 7. Permissions (nine keys; catalogue 64 → 73)

| Key | Owner | Store Manager | Store Employee | Notes |
|---|---|---|---|---|
| `agent.transaction.record` | ✓ | ✓ | ✓ | the counter |
| `agent.transaction.view` | ✓ | ✓ | ✓ | lists masked |
| `agent.customer.reveal` | ✓ | ✓ | — | the full number on a detail |
| `agent.mistake.report` | ✓ | ✓ | ✓ | moves nothing |
| `agent.transaction.reverse` | ✓ | ✓ | — | audited, once |
| `agent.rebalance` | ✓ | ✓ | — | |
| `agent.position.set` | ✓ | — | — | not delegable, outside `ADMIN_KEYS` (the `money.anchor.record` precedent) |
| `agent.report.view` | ✓ | ✓ | — | |
| `agent.provider.manage` | ✓ | — | — | company-scoped; outside `ADMIN_KEYS` |

Counting floats at the closing reuses `closing.count`; locking stays `closing.perform`. Mirrored in
`lib/permissions.ts`, the SQL migration and the drift specs.

---

## 8. Migrations and the rehearsal

`0088_branch_activity_pricing` (branches, plan versions v3, periods, seat allocation kind), `0089_agent_ledger` (the
eight tables, the two cash components on `closing_channel_counts` and `daily_rollups`, the discrepancy link),
`0090_agent_permissions` (the nine keys and their grants). All additive; the reverse SQL in each header. Rehearsed on
a disposable copy per `docs/22` (drill record E.4 there): dump with `--hex-blob`, verify the trailer, `migrate deploy`,
`prisma migrate diff` drift check, the restore drill, the identifiers in the handoff. **No live migration.**

### 8.1 Rehearsal record (2026-10-08, disposable only)

Throwaway MySQL 8.0.46 on `127.0.0.1:3310` in the OS temporary directory; database `prisma_qa_ma` at `0001`–`0087`
with the QA boutiques (10 companies, 12 branches, 16 users, 800 units) — **not live, not the PC's database**.

| Step | Result |
|---|---|
| Dump before any new migration | `prisma_qa_ma-before-0088-20261008-173135.sql`, 1 657 866 bytes, `-- Dump completed` trailer present, sha256 `ccb838f39abf6b46…` |
| `prisma migrate diff` (schema vs. migrations) | silent on every new object (the pre-existing drift of hand-written migrations unchanged) |
| `prisma migrate deploy` | `0088`, `0089`, `0090` applied in order — 89 migrations applied in all, status clean |
| After `0088` | plan version 3 = 500 / 300 / 700 / 1 included seat / 100 per extra seat; all 12 branches `electronics`, `activity_next` NULL |
| After `0089` | 8 tables, 12 triggers (`*_block_update` / `*_block_delete` for the application identity), `closing_discrepancies.agent_float_count_id` with its FK and index, the four cash-component columns |
| After `0090` | 9 permission rows; grants 90 (Owner) / 70 (Store Manager) / 30 (Store Employee) rows across the 10 companies; the Administrator 0 |
| Restore drill | the pre-dump sanitised (31 definers stripped, `docs/22` path 2) and restored into `prisma_qa_ma_restore`: identical row counts, 97 tables, **no** `activity` column (the `0087` state) — then dropped |
| Dump after | `prisma_qa_ma-after-0090-20261008-174132.sql`, sha256 `636e4c452c425e79…` |
| Cleanup | `prisma_qa_ma` and `prisma_qa_ma_shadow` dropped and the throwaway server stopped at the end of the session (the handoff says when) |

### 8.2 `0088`–`0090` on live — the runbook, for the owner's approval (NOT applied)

Live is at `0083`. **Order is fixed:** `0084`, `0085` (`docs/67` §7), `0086` with its transition (`docs/69` §2),
`0087` (`docs/71` §6), then `0088`, `0089`, `0090` in one `migrate deploy`. All three are additive: every existing row
satisfies the new defaults (`electronics`, prices 300/700 on existing plan and period rows, NULL links), the old API
ignores every new column and table, and the **new API reads them**, so the migrations must precede the new API; the
**new app must not reach phones before the new API** (it asks for `GET entitlement` activities and the agent routes,
which the old API does not serve).

1. **Backup** per `docs/22` §2 (`--single-transaction --routines --triggers --events --no-tablespaces --hex-blob`);
   verify size, the `-- Dump completed` trailer, the table count and the trigger count; record the dump in the handoff.
2. **Apply** with the migrator identity: `npx prisma migrate deploy` (takes every pending migration, in order).
3. **Verify the schema:** `SHOW COLUMNS FROM branches LIKE 'activity%'` → `enum('electronics','money_agent','both')`
   default `electronics`, `activity_next` NULL, `activity_changed_at` NULL; `SELECT version, branch_monthly,
   agent_monthly, both_monthly FROM plan_versions ORDER BY version` → the third row 500 / 300 / 700; `SHOW TABLES LIKE
   'agent\_%'` → 8; `SELECT COUNT(*) FROM information_schema.triggers WHERE trigger_name LIKE 'agent\_%'` → 12
   *(corrected 2026-10-10: this read 16; `0089` creates 12, as §8.1 recorded — with `0091`, see §8.3)*;
   `SELECT COUNT(*) FROM permissions WHERE \`key\` LIKE 'agent.%'` → 9; every company's Owner role holds 9 agent
   grants, the Administrator 0; `prisma migrate status` up to date; **every branch still `electronics`** (nothing is
   enabled by the migration — a branch becomes an agent only through the website's request and the Super Admin's
   confirmation).
4. **Deploy the API** at the checkpoint-2 commit or later. Smoke, on an electronics branch: `GET entitlement`
   `seatsByStore[].activity` = `electronics`; `GET agent/providers` → **200 with no provider** (a read is never gated,
   D156 as refined) and `POST agent/transactions` → 403 `activity_not_subscribed` (a write is); a cash sale and the
   Daily closing report unchanged (no float lines, no agent lines); `GET platform/plan` carries 500/300/700;
   `GET platform/my-subscription/activity-options` (an Owner) names each other activity with the server's figures;
   `npx ts-node scripts/verify-audit-chain.ts` reports no broken chain. *(Corrected 2026-10-09: the step first expected
   the provider list to be refused, which a correct deploy never does since `3b26e95`.)*
5. **Then the website** (its activity choice and quotes read the new API), **then the app**.
6. **Enabling a real agent branch** is a separate, owner-approved step: the website request, the Super Admin's
   payment confirmation, the Owner's providers configured with the **real** rates and settlement rules (§1.2) — until
   then every provider refuses with `provider_not_configured`.
7. **Rollback:** stop the API; restore the dump (`docs/22` §3) — or, for a database you would rather not restore,
   the reverse SQL in each migration header, in the order `0090`, `0089`, `0088` — and redeploy the previous API, website
   and app. A Git rollback does not roll back the database.

### 8.3 `0091_stabilization` — rehearsed, and the runbook's additions (NOT applied)

`0091` is additive: `daily_closings.money_version` (`INT UNSIGNED NOT NULL DEFAULT 0`); on `seat_allocations` the
nullable `replaces_branch_id` (FK, index), `replacement_credit` and `replacement_period_id`; the append-only
`branch_replacements` (one row per slot and per replacement branch) and `agent_request_keys` (one per company and
request id), each with its `*_block_update` / `*_block_delete` triggers for the application identity. The reverse SQL is
in its header. **Rehearsed** with `0088`–`0090` on the disposable `prisma_qa_st` (`docs/22` drill E.5, 2026-10-10):
dump before, `migrate deploy` 0088 → 0091, every pre-existing row and trigger body unchanged, the path-2 restore
identical to the pre-0088 fingerprint, the dump after verified. **Not applied** to live (`0083`) or to the PC (`0087`).

On live it runs in the same `migrate deploy` as `0088`–`0090`, after them, in the §8.2 order. Its checks, added to step 3:
`SHOW COLUMNS FROM daily_closings LIKE 'money_version'` → `int unsigned`, default 0; `SHOW COLUMNS FROM
seat_allocations LIKE 'replace%'` → the three columns, all NULL; `SHOW TABLES LIKE 'agent\_%'` → **9**; triggers named
`agent\_%` → **14**, on `branch_replacements` → **2** (the database's trigger total grows by **16** over `0087`); both new
tables empty. The API at backend `bea454c` or later **needs `0091`** (it reads `money_version` and writes the request keys
and replacement links), and the app at `2fc01a1` or later needs that API (provider writes carry `clientRequestId`): so the
order stays migrations → API → website → app. Rollback: the reverse SQL in `0091`'s header first (drop the triggers and
the two tables, then the columns), then §8.2 step 7 — or restore the dump.

---

## 9. Test plan (the brief's list)

| Scenario | Where |
|---|---|
| both directions, each provider isolated | pure ledger specs; real HTTP |
| known / zero / unknown starting balances | pure positions; HTTP; the card |
| a combined branch: an electronics sale and an agent exchange in one closing | HTTP (one closing, one drawer) |
| same UUID retry; changed payload conflict; concurrent devices | HTTP matrix, two sessions |
| correction/reversal exactly once; rebalancing excluded; rate change preserving history | pure + HTTP |
| actor spoofing refused (no employee id accepted) | DTO spec + HTTP |
| branch/company isolation | HTTP |
| subscription upgrades/downgrades, pending approval, expiry/read-only | pricing specs + lifecycle HTTP |
| business-day rollover; closing with pending offline items | shifted-clock HTTP; rendered test for the refusal |
| app restart and synchronization conflicts | pure queue specs; **device: NOT DEVICE VERIFIED** |

---

## 10. Stop conditions, and decisions taken here

- No unknown changes a **posted** amount: every blank gates its provider (§1.2), so nothing is posted on a guess.
- No migration is destructive: every change is additive with a reverse script.
- Decisions this page takes and records for the owner's confirmation (all reversible, D154–D157): the definition of
  "renewal"; the sideways change (electronics ↔ agent) treated as a downgrade or an upgrade by price; warehouses stay
  `electronics`; reversal authority on the Owner and the Store Manager directly (the brief's words) rather than through
  the sale-correction workflow; the one queueable kind; the business day of an offline exchange from its posting
  instant; the Administrator role holds no agent key by default.

---

## 11. Stabilization (2026-10-10) — billing decisions, closing staleness, idempotent provider settings, refused offline exchanges, the grant's own dates

The owner's brief of 2026-10-10 (D158–D161). Everything here is enforced by the server; the phone and the website
display its answer. One additive migration, `0091_stabilization` (§8.3). Built on backend `reports-export` (`2a8151e` …
`bea454c`), mobile `money-agent-4` = `reports-export` (`a90a0b8` … `2fc01a1`), website `money-agent-3` (`8161014`,
`36f04b2`).

### 11.1 The billing decisions (D158)

| # | Decision (the owner's words) | As built |
|---|---|---|
| B1 | A downgrade keeps the current activity until the paid period ends; no refund; the lower price starts at renewal. | Unchanged from D154: `activity_next`, applied by the renewal; the period stays assessed at the higher fee. |
| B2 | Replacing an archived branch in the same paid period costs no additional base charge when the previous one is archived, never active at the same time, and the replacement's activity is the same or cheaper. | A store request takes a **replacement slot**; priced `max(0, fee(new) − slot)`. Zero → the store opens at once (`granted`). |
| B3 | A dearer replacement pays only the activity-price difference. | `pending_payment` for exactly the difference; the store opens at the Super Admin's payment confirmation. |
| B4 | A simultaneous additional active branch pays the full monthly price. | No slot → full fee. The assessment never goes below a plain quote of the active branches, so an archived store brought back beside its replacement is charged in full. |
| B5 | An immutable trail links the archived branch, the replacement, the decision and the billing result. | `branch_replacements` (append-only) + the tenant or platform audit + a timeline row. |
| B6 | Concurrent requests and retries never grant two free replacements or charge twice. | Requests serialised on the subscription row; a slot reserved by an open request is invisible to the next; `UNIQUE (billing_period_id, archived_branch_id)` and `UNIQUE (replacement_branch_id)`; the same name again answers with the open request; a confirmed request confirmed again is a no-op. |

**Replacement slot.** Only while the subscription is **activated** and a paid period `P` runs (a suspended, cancelled
or lapsed business is offered none). A branch `A` offers a slot when it is no longer active, `P` billed it (it is in
`P`'s per-branch map), no `branch_replacements` row of `P` names it and no open store request reserves it. Its value is
`max(assessedFee(A), credit(A))` — what this period already paid for that location, carried along a chain. With several,
the smallest that covers the new fee in full, else the largest. The assessment charges each branch
`max(0, highWater(b) − credit(b))`. An upgrade of a replacement in the same period is priced against its credit:
fully covered → applied at once (`granted`, nothing to pay); otherwise `pending_payment` for what is left.

**Staleness.** A difference is the running period's figure alone. A store request carries its reserved slot (archived
branch, credit, period); an activity upgrade priced against a credit carries the credit and the period. The Super
Admin's confirmation re-reads them under the subscription lock and refuses with **409 `replacement_no_longer_applies`**,
nothing written, when the period has renewed, the archived store is active again or another store took its place;
asked again, the request is priced afresh. The status that lets a credit apply a change at once is read under the same
lock.

| Case (plan v3, one paid month running) | Due now |
|---|---|
| Electronics A (500) archived; a new electronics store | **0**, opens at once |
| Both A (700) archived; a new money-agent store | **0** (nothing refunded) |
| Money-agent A (300) archived; a new electronics store | **200** |
| Money-agent A (300) archived; a new both store | **400** |
| Electronics A still active; a new electronics store | **500** (B4) |
| A (700) archived; R electronics at 0; R upgraded to both | **0**, applied at once |
| A (300) archived; R electronics (200 paid); R upgraded to both | **200** |
| A (300) archived; R electronics (200 paid); R archived; R2 both | **200** (slot(R) = max(500, 300)) |
| A (500) archived; R money-agent at 0; R → both priced 200; confirmed after the renewal | **409 `replacement_no_longer_applies`**; asked again: 400 |
| Two store requests at once for one 500 slot | one at 0, the other 500 |

### 11.2 The closing refuses a confirmation made on money that moved (D159)

1. **`daily_closings.money_version`**: every money write bumps the row of the business day it lands on, in its own
   transaction, under the day row's `FOR UPDATE` — sales, payments, receipts, exchanges, reversals and rebalancings
   through `assertCounterOpenTx`; expense and refund confirmation, return approval, a back-dated payment, the opening
   review, a float set and a correction's approval through `lockDayForMoneyTx`. A back-dated write bumps every later
   unlocked day too.
2. **`reportVersion`** includes `money_version` when it is not zero. The close compares it before and again under the
   lock: a version the phone loaded before money moved → **409 `report_changed`** with the current report.
3. **Money moved after a count.** A counted (not skipped) drawer, account or float whose expected figure has moved since
   its count is stale: the report marks it (`movedSinceCount`, `expectedAtCount`) and warns `money_moved_after_count`
   with how many exchanges, reversals and rebalancings came after; a close on the current version is refused with
   **409 `money_moved_after_count`** naming each channel and float to count again, with the report. Counting again
   clears it. On every branch: an electronics cash sale after the drawer was counted is stale money too.
4. **A reopened day's own close.** The close anchors each counted float at what the provider's app showed, with the
   figure the count was held against (`tracked_before`). On a day reopened since, the count, the report and the live
   view all read that anchor the same way: the float runs on from `tracked_before` plus what moved after, so a
   difference the close recorded survives the recount and its question stays open (a review finding, fixed before
   merge: the recount had read the counted amount as the base and closed the question as *no difference remains*).
5. **Counts cannot race a close.** A count runs behind the day's lock and refuses a locked day (**409
   `already_closed`**); a float count takes the provider row shared before the day row (the order an exchange takes),
   and a float set is retried on a lock conflict. The Owner's opening review is refused on a closed day (**409
   `day_already_closed`**); the phone offers it only while the day is open.
6. **The close retried.** Its key is bound to its meaning (date, attestation, acknowledgement, reason): the same key and
   meaning replays the close; another meaning under it is **409 `idempotency_conflict`**. A day changed under a close is
   **409 `refresh_required`**. One closing, one event, one set of frozen rows.

The phone: on either refusal it shows the refusal's report at once, says **Money changed after counting began**, names
what to count again and what was recorded since (*Count again: Cash drawer. Recorded since the count: 1 exchange.*),
opens the count step for those, and sends the confirmation again only with a new version. A report it already knows
is stale holds the close button until the recount.

### 11.3 Provider settings are idempotent (D160)

`POST agent/providers`, `PATCH agent/providers/:id` and `POST agent/providers/:id/configs` require a `clientRequestId`
(UUID). `agent_request_keys` (append-only, one per company and key) keeps the operation, the target, a SHA-256 of the
canonical request and the response. Same key and payload → the first answer replayed (`replayed: true`, HTTP 200);
another payload or operation under the key → **409 `idempotency_conflict`**; two identical requests at once → one
write. Configuration versions stay append-only, every write keeps its audit row, and a provider with a blank rate,
settlement or reference rule still answers **409 `provider_not_configured`**.

### 11.4 A refused offline exchange has a clear outcome (D161)

**The status lookup.** `GET agent/transactions/client/:clientUuid` — company-scoped (no branch header), readable in
every subscription state, never gated by activity; to the person who recorded it or a holder of
`agent.transaction.view` at its branch (403 `permission_denied` otherwise); 400 `client_uuid_invalid` for a malformed
key. It answers `{ recorded: false }` or `{ recorded: true, transaction: { id, branchId, status, direction, providerId,
providerLabel, amount, commission, customerNumberMasked, businessDate, recordedAt, recordedByName, configVersionId,
deviceRecordedAt } }` — exactly those fields: never the number, the reference, the legs, a note or a reversal's reason.

**Stable refusal codes.** 403 `permission_denied` with `missing`; 403 `branch_access_denied`; 403 `branch_inactive`; 403
`ENTITLEMENT_WRITE_BLOCKED` with its `state` (`expired`, `suspended`, `cancelled`, `pending`, `rejected` — a suspended
business is never told it ended); a malformed path id is 400, never 500.

| Refusal of `POST agent/transactions` | Code | Queue outcome |
|---|---|---|
| expired / cancelled / suspended | 403 `ENTITLEMENT_WRITE_BLOCKED`, `state` | resubmit — *Send again* once access returns |
| activity removed | 403 `activity_not_subscribed` | re-enter |
| permission removed | 403 `permission_denied` | re-enter — someone allowed records it |
| branch not assigned / closed | 403 `branch_access_denied` / `branch_inactive` | re-enter |
| provider switched off | 400 `provider_inactive` | resubmit — *Send again* |
| provider not configured; configuration changed | 409 `provider_not_configured`; 409 `stale_configuration` | resubmit — *Review and send* |
| day closed or not opened | 409 `store_closed` | resubmit — *Send again* once open |
| a field refused | 400 | resubmit — *Edit and send* |
| the key already holds a different exchange | 409 `idempotency_conflict` | re-enter — a Manager reverses the wrong one |
| timeout, 5xx, an answer lost | — | uncertain → the lookup |
| session expired | 401 | stays waiting; sent after sign-in |

A refusal raised before the key is read (entitlement, activity, permission, branch) on an item that may already be
recorded runs the lookup first.

**The phone's six states** (`lib/offline/exchange-rules.ts`): pending (`waiting_for_connection`), synchronizing
(`sending`), confirmed (`synced` — the server's time, business day, recorder and commission), `uncertain` (*Checking
whether it was recorded* — resolved only by the lookup: recorded and matching → confirmed; recorded and different →
re-enter; not recorded → sent again under the same key; unreachable → stays uncertain with **Check again**),
`rejected_resubmit` and `rejected_reenter`. Nothing rejected is retried on its own or shown as waiting; every state
counts as held for the closing until confirmed or removed. The customer's number lives in SecureStore under
`agent.exchange.number.<company>.<branch>.<user>.<uuid>` (an older unscoped key is moved on first read), removed when
the item ends; signing out resets the in-memory queue.

### 11.5 The grant's own dates (website)

The account page once said "granted until {the latest billing period's start}". The server now returns
`complimentary: { status, until, paidUntil }` (`entitlement-rules.ts` `complimentaryOf`), read from the subscription's
grant fields: `active` (a grant running to `until`), `ended` (it ran out on `until`; access follows the paid period),
`superseded` (it ran out and a paid period runs past it, to `paidUntil`), `indefinite` (defensive only — the database
refuses a grant with no end), `none`. A newer grant replaces the older one's end (`complimentaryUntil` is overwritten;
the older end survives in the timeline). The website shows exactly that: the lead and the period card say the grant's
own end; an expired business with no paid period is told when its grant ended (or that no paid period has started),
never "ended on —"; with no grant view (an older API) it makes no claim about a date; the console's list shows, for a
business on a grant, the later of the grant's end and the paid end. *(The design said `grantedAt` and a
grant-by-grant `superseded`; as built, `paidUntil`, and a newer grant is simply `active` with its own end.)*

### 11.6 What this phase does not do

- **No in-product branch archive action exists** (no endpoint, screen or column; only account deletion deactivates
  branches). The replacement rule is built and tested with a branch deactivated directly in the disposable database;
  offering *Archive this store* — what becomes of its stock, drawer, floats, staff and debts — is the owner's decision.
- The phone's access screen still reads the paid period's end while a grant runs (`app/access.tsx`; pre-existing,
  outside §11.5's website scope): a follow-up should show the later of the grant's and the paid end.
- No live or PC migration, no deployment, no real provider, rate or customer number.

### 11.7 Verification (2026-10-10, cloud session, disposable data only)

| Gate | Result |
|---|---|
| Backend `bea454c` | `tsc` clean; jest **207 suites / 3 803 passed / 3 skipped** (from 200 / 3 630 at `35b5836`); `prisma validate` clean; permission drift and tenant specs inside the suite |
| Real HTTP + real MySQL (`prisma_qa_st` at 0091) | **66/66** — A billing 19, B closing 14, C provider keys 8, D refusals and the lookup 18, E the grant 5, F electronics 2 |
| Website `36f04b2` | `tsc`, **8 files / 48 tests**, production build; Chromium against the real API **12/12** (EN/FR/AR at 360, RTL, no sideways scroll, the console list) |
| Mobile `2fc01a1` | `tsc` clean; **103/103** pure suites; jest **14 suites / 150 tests**; `expo lint` 0 errors / 29 warnings (baseline); parity **3 754 × 3**, identical order; web export clean, all 64 static routes exported (16 dynamic); expo-doctor 19/21 (two network checks); the web export against the real API **7/7** |
| Adversarial review | 17 agents: 12 findings confirmed (2 major — the credit-priced upgrade after a renewal, the reopened day's recount — both fixed with tests that fail without the fix), 1 refuted; every confirmed finding fixed except the phone's access-screen date (§11.6, pre-existing) |
| Migration rehearsal | `docs/22` E.5: 0088 → 0091 on the disposable copy, demo data unchanged, path-2 restore identical |
| Phone | **NOT DEVICE VERIFIED** — `docs/24` §62 |

### 11.8 Found on the device and fixed (2026-10-10 → 2026-10-11, PC run, `docs/24` §63)

- **The offline counter (D155).** The provider list lived only in the query cache: a refresh that failed without a
  network replaced it with an error, and a relaunch had none, so no exchange could be prepared offline. The providers
  query now keeps every list the server sends, one file per branch (`lib/offline/kept-providers.ts`, rules in
  `kept-providers-rules.ts`), and answers from it only when the server cannot be reached (no network, unreachable,
  timeout, 5xx) — never on a refusal. The counter says *The providers as this phone last read them, …*; a kept rate is
  safe because an exchange on an older version is refused as `stale_configuration` and shown again (seen on the device).
  Mobile `0c814be`.
- **The Daily closing while an exchange is queued.** The *Exchanges still on this phone* notice lived inside the report,
  so with the API unreachable the page was empty. It is now one notice at the top, steady from the first frame. Mobile
  `6a4afc8`.
- **D159 and a float the app does not know.** Unknown at the count and Unknown now compare equal, so an exchange after an
  Unknown float's count closed silently. A counted float that was Unknown at its count now reads `movedAfterCount` from
  the movements (one read on `ix_agent_movements_account_at`) and is counted again; a known float is unchanged.
  Backend `c7034c8`.
- **D162** — the customer number is exactly eight digits (backend `b75b637`, mobile `10369b6`).

## 12. The typed commission (D164, 2026-10-12)

The contract now (backend `9c9005a`, migration `0092`; mobile `8bb9201`; detail in `docs/75` §2–§5):

- `POST agent/transactions` takes `commissionAmount` — **required**, whole MRU, ≥ 0, and ≤ `amount` when cash is
  handed over. Refusals (400): `commission_required` (absent, null or empty — never zero), `commission_invalid`,
  `commission_exceeds_amount`; each ends "Nothing was recorded." `configVersionId` is accepted from older phones and
  ignored except to replay an exchange recorded under a rate. `provider_not_configured` and `stale_configuration`
  no longer exist.
- The recorder, company, branch and business day come from the session; a body naming a recorder is refused.
- Legs: receive cash = cash in A, provider out A, cash in C (commission); give cash = cash out A, provider in A, cash in C.
- The view: `commission: { amount, source: 'manual' | 'legacy_rate', legacy: { rateBp, destination, principalFeeMode,
  configVersionId } | null }`; the status lookup adds `commissionSource`.
- Fingerprint (idempotency): `v:2` including the commission; a legacy row keeps its own.
- Provider configuration: `POST agent/providers/:id/configs { clientRequestId, referenceRule, reason }` only; a version
  view carries `referenceRule` and `legacy` (the rates of a version written before D164). A provider has no readiness:
  any provider switched on is usable.
- Reports (`GET agent/reports`): cash and credit from each exchange's stored principal and commission legs, plus
  `routes` per direction (count, volume, commission).
- The update trigger: commission, source and money columns immutable; only the D165 redactions are allowed.
