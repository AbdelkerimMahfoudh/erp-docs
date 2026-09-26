# 53 — Reporting consistency: one set of dated rules for every screen

> The user's brief of 2026-09-25 (reporting consistency only, no workflow, no pictures, the completed three-day repair
> not rerun): Money, Home, Analytics and goals follow the same dated accounting rules as the Daily closing and Results;
> audit the endpoints and rollups first; preserve original dates and every closing snapshot; keep cost and profit
> hidden without permission; test same-day and later-day cancellations, partial and full returns, expense reversals,
> refunds paid later and periods holding only a negative adjustment; document any metric whose meaning needs a product
> decision.

## 1. The rules (the Daily closing's, and Results')

| # | Rule |
|---|---|
| R1 | A sale stays on its **sale date** (its stored business date). Its **cancellation** is a separate negative adjustment on the **approval date** (`correction_date`). |
| R2 | An approved **return** affects revenue, profit and returned-unit measures on its **approval date**: revenue falls by the **net refund due** (gross refund − adjustments the shop keeps), profit by gross refund − adjustments − cost credited (`return-accounting-correction.spec`: over a sale and its return, profit equals the adjustments). |
| R3 | A **refund confirmation** moves money on its **confirmation date**; it has no profit effect. |
| R4 | A confirmed **expense** stays on its recorded date — a variable one on its confirmation date, a fixed one on its due date. An approved **reversal** reduces expenses on the **correction date**, shown apart so a negative net is understandable. |
| R5 | **Sales count** = invoices on the dates − whole-sale cancellations approved on the dates. A returned item is a separate **return** event and does not change the count. |
| R6 | Units follow the count: **units sold** = units on the invoices − units on the cancelled invoices (cancellation dates); **units returned** is its own measure on the approval dates. *The units-sold goal also takes returned units off on their approval dates — `docs/54` D37, the user's decision of 2026-09-25; Money's "Items sold" and Analytics keep them apart.* |

## 2. Audit (before any change, 2026-09-25)

| Screen · figure | Source | Today | Disagrees with |
|---|---|---|---|
| **Results** · net revenue, gross profit, final profit | `summary.service` → `profit()` over `daily_rollups` | subtracts the **gross** refund of a return | R2, the Daily closing, the rollup's own `net_profit` — whenever a return keeps an adjustment |
| **Results** · comparison | the same | `comparison.netOperatingProfit` is not a cost-gated key | cost gating: it reaches a user without `cost.view` |
| **Home** · sales value, cancelled (0080) | sales + corrections, live | returns absent | R2 |
| **Home** · expenses | confirmed expenses, live | not net of reversals | R4 |
| **Home** · `salesCount`, `phonesSold` (API) | sales, live | invoices only | R5, R6 |
| **Money** · phones sold, sales value | `closing.overview`, live | invoices only; no cancellation or return anywhere | R1, R2, R6 |
| **Money** · "Items sold" (found while fixing it) | `closing.overview` `phonesSold` | counted **phones only** — accessories and serial-tracked items never appeared under "Items sold" | R6 |
| **Money** · sales by day (`/sales/by-day`) | sales, live | one row per sale day; a cancellation or return day never appears | R1, R2 |
| **Money** · today's expenses | expenses `confirmation_date = today` | a fixed expense due today but confirmed earlier is missing; one confirmed today but due later is shown; reversals absent | R4 |
| **Sales for the period** header | `closing.overview` | as Money | R1, R2 |
| **Analytics** · best sellers, most/least profitable, product and category reports (and their exports) | `product_daily_rollups` | sale-date facts only: a cancelled or returned item still counts as sold and earned | R1, R2, R6 |
| **Analytics** · employees (and the export, and the seller-margin anomaly) | `sales` grouped by `sold_at` instant | cancelled sales count and earn; returns ignored; the window is the sale instant, not the business date | R1, R2, R5 |
| **Analytics** · branches (and the export) | `daily_rollups` | revenue and gross profit gross of returns and cancellations (net profit already net) | R1, R2 |
| **Analytics** · `today`/`month` snapshot (API only) | `daily_rollups` | gross figures; "today" is the UTC date | R1, R2, R5 |
| **Goals** · branch revenue, profit | `daily_rollups` | cancellations off (0079/0080); **returns never deducted** | R2 |
| **Goals** · personal revenue, profit | sales, live | returns never deducted | R2 |
| **Goals** · gross profit goal | goals are readable by every branch user | shows profit to a user without `cost.view` | cost gating |
| **Daily closing** · "N sales · M items" | the report | invoices and their items; cancellations on their own line | R5, R6 (the count shown is not the defined count) |

Correct already, and the reference: the Daily closing's value, returns (net refund due), cancellations, net sales,
expenses (recorded − reversed), money per channel and refunds on their confirmation date; Results' cancellations and
expenses; the rollup's `net_profit`; branch goals' cancellations; Home's cancellation line.

## 3. Decisions (D29–D35)

| # | Decision |
|---|---|
| D29 | **One definition, one place** (`src/analytics/period-figures.ts`): for a branch and a range of business dates — invoices (count, value, units, phones), cancellations (count, value, units, phones, cost, margin) on their approval dates, returns (count, net refund due, cost credited, profit effect, phones) on their approval dates, expenses recorded and reversed. Home, Money, sales by day, the employees and the product/category reports read it; the rollup-based readers (Results, branch goals, branches) use the rollup columns that hold the same facts. |
| D30 | **Results takes the net refund due** (R2): `profit()` receives `returns_revenue − returns_adjustments`; its "Approved returns" line is what went back, as the Daily closing's is. |
| D31 | **Where money is shown**, the sale value stays the invoices' value on the sale date, the cancellations and returns of the period are separate negative lines, and **net sales** = value − returns − cancellations. |
| D32 | **Where a count or units are shown**, they are the defined ones (R5, R6), with the definition stated on the screen; returns are shown as their own count. |
| D33 | **Expenses**: recorded (their own dates) − reversed (correction dates) = net; Home and Money show the reversed part apart; Money's today's rows follow the accounting-day rule and list each reversal as its own negative row. |
| D34 | **Attribution**: a seller carries their invoices on the sale dates and their own sales' cancellations and returns on the approval dates; a product carries its lines the same way. |
| D35 | **Cost gating**: `netOperatingProfit`, `netCogs`, `returnsCogs`, `cancelledCogs`, `returnsGrossProfit` and the new cost-side keys join the stripped set; a gross-profit goal is not listed for, nor readable by, a user without `cost.view`. |

## 4. What cannot be reconciled without a product decision

*All four were settled on 2026-09-25 — see [`docs/54`](54_HOME_COMPLETION.md): 1 by D37, 2 by D36, 3 by D41, 4 by
D39. Item 4 as written here was also inaccurate: the movement snapshot already left a cancelled sale out; what was
wrong was its window (docs/54 A7).*

1. **Does a return reduce "items sold"?** R6 keeps units sold net of cancellations only and shows returned units
   apart, as R5 does for the count. So the units-sold goal and "best sellers" count a returned phone as sold, while
   revenue and profit goals lose its refund. If the shop wants a units goal net of returns, the change is one rollup
   column away (`returns_count` is already there).
2. **A whole-sale discount.** The Daily closing, Home, Money and the employees read the invoice total; Results, goals,
   branches and the product/category reports read the lines (price × quantity − line discount). A discount on the
   whole invoice belongs to no line, so the two disagree by exactly that discount, and a product's share of it needs
   an allocation rule. **Live holds no such sale today** (checked 2026-09-25), so nothing disagrees yet.
3. **"Money taken"** is the revenue goal's label; after D30 it is net sales, not cash collected. The label is the
   shop's to choose.
4. **Movement labels stay invoice facts.** Analytics' "sold in 30 days", "last sold" and dead stock describe stock
   movement, not accounting, and still read the invoices: a phone sold and cancelled still counts as having moved. Say
   if they should net cancellations.

## 5. What changed (backend `1a5105e`…`5acab28`, mobile `dd309fc`…`73fee6d`; no migration)

No schema change was needed: the rollup already holds the return and cancellation columns, and the live readers take
the adjustments from their source rows. No live record, historical total or stored closing was touched.

| Screen | Now |
|---|---|
| **Home** | Sales value = the invoices on their sale dates (the bars); **Sales cancelled** and **Returns** each on their own line on their approval dates; sales count and phones net of whole-sale cancellations; expenses = recorded − reversed, captioned "After N reversed" when a reversal fell in the range. |
| **Money** | **Items sold** = units sold as defined (was phones only); the period's cancellations and returns on their own lines, then **net sales**; the definition stated under the figures; each day row shows the day's net and what came off it, and a day holding only an adjustment appears; **today's expenses** take a fixed expense on its due date and list each reversal as its own negative row ("Transport, corrected"). **Sales for the period** says what came off. |
| **Analytics** | Products and categories: units sold net of cancelled lines, **returned units** apart, revenue, cost and profit net of both on their approval dates; a product whose only movement is an adjustment appears with negative figures. Sellers: invoices on the sale dates (business dates, no longer the sale instant) less their own cancellations and returns on the approval dates; returns counted apart. Branches: net revenue and gross profit. The exports and the seller-margin anomaly read the same figures. |
| **Goals** | Branch and personal revenue and profit goals lose returns on their approval dates (cancellations already did); each goal states what it counts; a gross-profit goal is neither listed for nor readable by a user without `cost.view`. |
| **Daily closing** | Its "N sales · M items" line shows the defined count and units (1 · 1 after a same-day cancellation of a 3-item sale, beside "Sales cancelled (1 · 3 items)") and states the rule. |
| **Results** | Approved returns = the net refund due; its cost-side comparison keys are stripped without `cost.view`. |

**Contract.** `GET /v1/home` `figures`: `salesCount` and `phonesSold` are now net (R5, R6); new `returns {count, value,
phones}`, `netSalesValue`, `expensesRecorded`, `expensesReversed`; `expenses` is net and may be negative.
`GET /v1/closings/overview`: `period.unitsSold`, `cancellations`, `returns`, `adjusted`, `netSalesValue`, and
`salesCount` now net; `expensesToday {total, recorded, reversed, rows[]}` with `rows[].kind` (`expense` | `reversal`)
and `expenseId`. `GET /v1/sales/by-day`: each day adds `units`, `cancelled`, `returned`, `returns`, `adjusted`, `net`;
`sales` is net. `GET /v1/closings/report`: `sales.salesCount`, `sales.unitsSold` (both outside the report version, so
every stored close still matches; a stored close signed before them has only `count`, and the phone falls back to it).
`GET /v1/analytics/products|categories`: `unitsReturned`. `GET /v1/dashboard`: `employeePerformance[].returnsCount`.

## 6. Verification (2026-09-25)

**On an isolated copy** (`prisma_verify_home`, restored from `phonestore-after-rollup-repair-20260925-075339.sql`,
migrations deployed, throwaway credentials on the copy only), through the API built into OS temp with a fake clock —
the user's API and `backend/dist` untouched. Every expected figure was written from the catalogue before the run: a
phone 10 000 at cost 6 000, a cable 20 at cost 5.00. Each scenario sits in its own month so the 30-day windows hold only
it. **`reporting-lifecycle`: 59/59 steps, 53/53 screen checks with expected = actual.**

| Scenario | Screen | Expected = actual |
|---|---|---|
| **S1 same-day cancellation** (2027-01-11: sale A a phone 10 000; sale B a phone + 2 cables 10 040, cancelled the same day) | Home, Today | value 20 040 · cancelled 1 / 10 040 · net 10 000 · **1 sale · 1 phone** |
| | Money, Today | items sold 1 · 1 sale · value 20 040 · cancelled 10 040 · net 10 000; by day: one row, net 10 000 |
| | Analytics | iPhone 1 sold / 10 000 / cost 6 000 / profit 4 000; cable **0** sold / 0; phones category 1 / 10 000; the seller 1 sale / 10 000 / margin 4 000; branch 10 000 / 4 000 |
| | Goals (branch · the seller's) | revenue 10 000 · profit 4 000 · sales 1 · units 1 |
| | Daily closing | value 20 040 · 2 invoices / **1 sale** · 4 items / **1 unit** · cancelled 1 / 10 040 / 3 items · net 10 000 · profit 4 000 |
| | Results | sales 20 040 · cancelled 10 040 · net 10 000 · profit 4 000 |
| **S2 later-day cancellation** (sold 2027-03-08 and **closed**; cancelled 2027-03-09 — a day holding only the negative adjustment) | the closed day | stored close event byte-identical, same report version, no "changed since close" |
| | Home | sale day: 10 000, 1 sale · cancellation day: value 0, cancelled 10 000, **net −10 000, −1 sale, −1 phone** · 7 days: 10 000 − 10 000 = 0, 0 sales |
| | Money | cancellation day: items −1 · −1 sale · net −10 000; by day: 03-09 −1 / net −10 000 · 03-08 1 / net 10 000 |
| | Analytics | iPhone, the cancellation day: −1 / −10 000 / cost −6 000 / profit −4 000; both days 0; the seller 0 / 0, branch 0 / 0 |
| | Goals (branch · the seller's) | sale day 10 000 / 4 000 / 1 / 1 · cancellation day **−10 000 / −4 000 / −1 / −1** · both 0 |
| | Daily closing, cancellation day | value 0 · −1 sale · −1 unit · cancelled 1 / 10 000 · net −10 000 · profit −4 000 |
| | Results | cancellation day: net −10 000, profit −4 000 · both days: 10 000 − 10 000 = 0, profit 0 |
| **S3 partial return, refund later** (2 phones 20 000 on 2027-05-10; one returned with a 500 restocking fee kept, approved 05-11; refund 9 500 confirmed 05-12) | Home, approval day | value 0 · **returns 1 / 9 500** · net −9 500 · 0 sales |
| | Money | approval day: returns 9 500 · net −9 500 · 0 items; by day 05-11 net −9 500 · 05-10 net 20 000; **refund day: refunds 9 500, no sales figure moves** |
| | Analytics | iPhone, approval day: 0 sold / **1 returned** / −9 500 / cost −6 000 / profit −3 500; both days 2 sold / 1 returned / 10 500 / 4 500; the seller 1 sale, 1 return, 10 500 / 4 500; branch 10 500 / 4 500 |
| | Goals (branch · the seller's) | approval day −9 500 / −3 500 / 0 / 0 · all three days **10 500 / 4 500 / 1 / 2** |
| | Daily closing | approval day: returns 1 / net refund due 9 500 / adjustments 500 · net −9 500 · profit −3 500 · refund day: 9 500 out of the drawer, net 0, profit 0 |
| | Results | approval day: returns **9 500** (10 000 before D30) · net −9 500 · profit −3 500 · refund day: 0 · all three days: net 10 500 · profit **4 500** (the kept 500 + the phone kept, 4 000) |
| **S4 full return, refund later** (a phone 10 000 sold and returned 2027-07-12; refund confirmed 07-13) | Home · Money · Daily closing · Results | value 10 000 · returns 1 / 10 000 · net 0 · 1 sale (a return is its own event) · profit 0 |
| | Analytics · goals | iPhone 1 sold / 1 returned / 0 / 0; the seller 1 sale, 1 return, 0; goals 0 / 0 / 1 / 1 |
| | Refund day | Money: refunds 10 000, nothing else; Daily closing: 10 000 out, net 0, profit 0; Results 0 |
| **S5 expense reversal** (2027-08-09: transport 800 confirmed; rent 2 000 confirmed the same day, due 08-10; 08-11: 300 of the transport reversed — a day holding only the reversal) | Money, today's expenses | day 1: **Transport 800 only** (the rent is not today's) · day 2: **Rent 2 000** · day 3: **"Transport, corrected" −300**, total −300 |
| | Home | day 1: 800 · day 3: **−300** (0 recorded, 300 reversed) · 7 days: 2 800 − 300 = **2 500** |
| | Daily closing | 800 · 2 000 · recorded 0 / reversed 300 / **−300** |
| | Results | day 3: expenses −300 · all three days 2 500 |
| **Cost gating** (a store manager without `cost.view`, on a day with rows) | Analytics, dashboard, Results, goals | products, categories, sellers and branches carry no cost, profit or margin; Results has no profit block and its comparison only `netRevenue`; no gross-profit goal listed, and reading one is 404; the Owner still sees cost and profit on the same rows |

**Regression on the new build** (each on a fresh copy): the Daily closing lifecycle **45/45**, corrections **40/40**,
cancellation **31/31 with 106/106 figures** — after its three Home counts were updated to R5 (after a same-day
cancellation, 1 sale, not 2; on the cancellation day, −1; over both days, 1). That change is the brief's, not a
regression.

**Gates.** Backend: tsc clean · full suite **156 suites / 2 806 tests** (new `reporting-consistency.spec`, 15).
Mobile: tsc clean · **71 pure suites** (new `reporting-rules.test`, 6) · i18n parity **3 180** keys · `expo lint`
0 errors (33 warnings, all pre-existing).

**Database impact.** None on live: no migration, no backup needed, no write. The copy was dropped after verification.

## 7. Not changed, by name

- The Analytics **snapshot** (`today`/`month`, API only, shown on no screen) reads "today" as the UTC date; its figures
  are now net.
- The exports carry the net figures but have no returned-units or returns-count column, and do not state the rule.
- The Daily closing report keeps the invoice facts `count` and `itemsSold` beside the defined `salesCount` and
  `unitsSold`, because stored closes were signed with them.
- **Physical device: not run** — `docs/24` §41.
