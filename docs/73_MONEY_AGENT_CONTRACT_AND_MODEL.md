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
| both → agent on the 5th, then agent → both on the 25th | 0, then **+400** | the scheduled downgrade is cancelled by the later upgrade request; nothing is refunded |
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

With `A` the amount, `r` the rate for the direction, `C = round2(A × r)`:

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

### 4.6 Customer numbers and references

- The number is **normalized** with the existing payer-number rule (`payer-number.ts`: digits, an optional leading
  `+`, Arabic-Indic digits mapped, 4–30 digits; no country assumed, no digit guessed) and stored once; `last4` is a
  separate column for the masked list and the masked search (`•••• 1234`). Lists and searches never return the full
  number; the detail returns it only to `agent.customer.reveal` holders; it never reaches logs, exports, notifications
  or reports (an allow-list spec, as for the payer number, D151).
- The provider reference is validated per `reference_rule` (required / optional / none) and kept apart from the
  number; a reference-only correction is a separate audited fact that moves nothing (the D151 pattern).

### 4.7 Worked examples (fixture rates: 1.00 % both directions, settled separately, credited to the float; **invented**)

| # | Event | Cash (drawer) | Bankily float | Sedad float | Commission (revenue) | Count / volume |
|---|---|---|---|---|---|---|
| 0 | Owner sets: drawer 10 000 (opening), Bankily 50 000, Sedad **unknown** | 10 000 | 50 000 | Unknown | — | — |
| 1 | Receive cash 20 000 / send Bankily credit | 30 000 | 50 000 − 20 000 + 200 = **30 200** | Unknown | 200 | 1 / 20 000 |
| 2 | Give cash 15 000 / receive Sedad credit | 15 000 | 30 200 | Unknown (+15 000 +150 moved today) | 350 | 2 / 35 000 |
| 3 | Reversal of #1 (wrong direction) | 35 000 | 30 200 + 20 000 − 200 = **50 000** | Unknown | 150 | 1 completed, 1 reversed / 15 000 |
| 4 | Rebalancing: buy 100 000 Bankily float with cash — refused: cash would go to −65 000 → recorded only if the Owner confirms the negative, shown as negative | 35 000 | 50 000 | | 150 | unchanged |
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
seven tables, the two cash components on `closing_channel_counts` and `daily_rollups`, the discrepancy link),
`0090_agent_permissions` (the nine keys and their grants). All additive; the reverse SQL in each header. Rehearsed on
a disposable copy per `docs/22`: dump with `--hex-blob`, verify the trailer, `migrate deploy`, `prisma migrate diff`
drift check, the restore drill, the identifiers in the handoff. **No live migration.**

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
