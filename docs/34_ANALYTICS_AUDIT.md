# 34 — Analytics audit and accounting dictionary (Milestone L)

> **L0.** Where every reported number already comes from, what it means, and
> when it moves.
>
> The rule this milestone obeys: **do not build a competing accounting system.**
> Every figure below already has a canonical owner. L consolidates and presents
> them; it does not recompute them a second way, because two ways of computing
> profit is how a shop ends up with two answers and trusts neither.

---

## What already exists

| Source | What it owns |
|---|---|
| `daily_rollups` + `RollupService` | The canonical daily figures: revenue, COGS, gross profit, expenses, net profit, returns, refunds paid, corrections |
| `DashboardService` | The Home and dashboard read models |
| `AnalyticsService` | Inventory value, per-product and per-category breakdowns |
| `HealthService` | The health score |
| `held-value.ts`, `in-transit-value.ts` | Faulty-held and in-transit inventory value |
| `DailyClosing` + `closing_channel_counts` + `closing_discrepancies` | Counted cash per channel, and differences |
| `loan_ledger` (`remaining()`) | Loan receivables and payables |
| `consignment_ledger` (`outstanding()`) | Consignment balances |
| Supplier settlements | Payables and what has been settled |
| `goal_progress` | Goal attainment |

`daily_rollups` is refreshed by a listener rather than computed per request, and
already carries the hard-won distinctions: **only confirmed expenses count**,
returns carry both a revenue reversal and a COGS credit, refunds paid are
tracked separately from returns approved, and corrections have their own totals.

---

## The accounting dictionary

Seven categories, and the reason they are kept visibly apart is that a shop
reading one as another makes a decision on a number that does not mean what they
think.

| Category | Question it answers |
|---|---|
| **Profit** | Did we earn anything? |
| **Cash movement** | Did money physically move? |
| **Liability** | What do we owe? |
| **Receivable** | What are we owed? |
| **Inventory value** | What is sitting on the shelf? |
| **Discrepancy** | What did not add up? |
| **Workflow** | What is provisional, and what is confirmed? |

### Timing — when each event moves which number

| Event | Profit | Cash | Liability / receivable |
|---|---|---|---|
| **Sale** (sale date) | Revenue and COGS, so gross profit | Received amount, per channel | — |
| **Return approved** | Revenue reversal **and** COGS credit | — | Creates a refund liability |
| **Refund reported** | **Nothing** | **Nothing** | Nothing — it is a claim |
| **Refund confirmed** | **Nothing** — profit already moved at approval | Cash out | Settles the refund liability |
| **Purchase / receiving** | — | — | Creates a supplier liability |
| **Supplier payment confirmed** | **Nothing** | Cash out | Reduces the supplier liability |
| **Expense confirmed** | Reduces profit | Cash out, per the expense model | — |
| **Consignment disposition** | Profit at sale of the consigned unit | — | Creates a balance between the two shops |
| **Loan principal** | **Never** | Movement only | Receivable or payable, by direction |
| **Loan / consignment payment confirmed** | **Never** | Cash | Reduces the balance |
| **Closing discrepancy** | **Never profit** | It is a difference, not a movement | May become an employee debt |

**The two mistakes this table exists to prevent.** Counting a return twice —
once at approval and again when the refund is paid — and treating a loan or a
consignment principal as revenue or an expense. Both make a shop look
dramatically more or less profitable than it is, and both are easy to write.

Corrections flow through the existing compensating-record semantics. Nothing is
edited in place, so a corrected figure is the sum of the original and its
reversal rather than a rewritten row.

---

## Gaps, recorded rather than filled

Where a metric has no canonical source it is **omitted**, not defaulted to zero.
A zero is a claim that something was measured and found to be nothing, and a
shop cannot tell it apart from a number nobody computed.

- **Commissions and fees** have no model. There is no fee concept in the schema,
  so nothing about them is reported.
- **Per-channel expected movement** exists for the closing, which computes it
  from the day's payments; analytics reuses that rather than deriving a second
  expectation.
- **Unattributed legacy payments** — payments recorded before receiving accounts
  existed carry no channel. They are reported as unattributed rather than
  silently assigned to cash, because assigning them would make one channel's
  reconciliation permanently wrong.

---

## Permission gating

Cost and margin are gated by `CostGatingInterceptor`, which strips financial
fields after Decimals are converted. That gating applies to analytics exactly as
it applies everywhere else — a summary endpoint must not become the hole through
which somebody without `report.view` reads the shop's margins.

Branch and company scoping come from the tenant extension and the branch header,
unchanged.

---

## Comparison semantics

A period is compared with the **immediately preceding period of equal length**,
so a 7-day window compares with the 7 days before it.

When the preceding period's value is zero, the server returns an explicit
**unavailable** state rather than infinity, `NaN`, or a percentage computed
against nothing. "Up 100%" from a base of zero is not information; it is a
division nobody checked.
