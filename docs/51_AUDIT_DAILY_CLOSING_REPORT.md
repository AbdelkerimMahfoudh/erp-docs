# 51 — Daily closing report: accounting audit and contract

> Audit of 2026-09-24 (CLAUDE-A), before any edit, at backend `3fa4801` / mobile `904e3ac`. Eleven subsystems were
> mapped read-only, each map re-checked claim by claim against the code by an independent verifier; the verifier's
> version is used where they disagreed. §1–§11 are that synthesis. §12 is the completeness pass and §13 the decisions
> this implementation takes. Paths are relative to `backend/src` and `mobile/` unless given in full.

**Audit baseline.** Backend `3fa4801`, mobile `904e3ac`. Both working trees were clean. This was a read-only audit: no file, database or migration was touched.

**Conventions.**
- **D** is the business date and **B** is the branch.
- "Server" means the backend computes the figure. "Client" means the mobile app computes it.
- Where a map reader and its adversarial verifier disagreed, the verifier's version is used. Claims the verifier refuted are left out, or marked as refuted where the refutation matters.
- **"Real money"** means the row status that the closing and rollup queries actually filter on.

**File legend.** File names are unique, so full paths are given only here.

| Short name | Path |
|---|---|
| `closing.service.ts`, `closing.controller.ts`, `closing-lifecycle.ts`, `channels.ts`, `debt-rules.ts`, `discrepancies.service.ts`, `closing-notices.ts` | `backend/src/closing/` |
| `create-closing.dto.ts`, `record-count.dto.ts` | `backend/src/closing/dto/` |
| `rollup.service.ts`, `summary.service.ts`, `dashboard.service.ts`, `dashboard.controller.ts`, `accounting-rules.ts`, `held-value.ts`, `in-process-rollup-queue.ts`, `analytics.service.ts` | `backend/src/analytics/` |
| `sales.service.ts`, `sale-payments.service.ts`, `sale-payment-rules.ts`, `sales-policy.service.ts`, `sales.controller.ts` | `backend/src/sales/` (DTOs in `dto/`) |
| `returns.service.ts`, `return-workflow.ts`, `refund-payout.ts`, `returns.controller.ts` | `backend/src/returns/` |
| `corrections.service.ts`, `corrections.controller.ts`, `correction-rules.ts`, `correction-sql.ts`, `correction.dto.ts` | `backend/src/corrections/` (DTO in `dto/`) |
| `expenses.service.ts`, `expense-rules.ts` | `backend/src/expenses/` |
| `purchasing.service.ts`, `purchasing.controller.ts` | `backend/src/purchasing/` |
| `business-day.service.ts` / `business-day.ts` | `backend/src/common/business-day/` / `backend/src/common/` |
| `cost-gating.interceptor.ts`, `financial-fields.ts` | `backend/src/common/interceptors/` |
| `role-permissions.ts`, `permission-scope.ts`, `access.service.ts`, `role-provisioning.ts`, `permissions.guard.ts` | `backend/src/rbac/` |
| `user-management.service.ts`, `users.controller.ts` | `backend/src/users/` |
| `schema.prisma`, `00NN_*/migration.sql` | `backend/prisma/`, `backend/prisma/migrations/` |
| `count.tsx`, `closing/index.tsx` | `mobile/app/closing/` |
| `lib/closing.ts`, `home-day.ts`, `home.ts`, `period.ts`, `en.ts` (`i18n/`), `permissions.ts`, `money-overview.ts`, `expense-rules.ts` (mobile) | `mobile/lib/` |
| `(tabs)/index.tsx`, `money-hub.tsx`, `sell.tsx` | `mobile/app/(tabs)/` |

**Key findings in one screen**

1. Every money figure the report needs already sits on stored business-date columns. There is one channel sign table and one channel builder (`channels.ts:27-33, 149-157`), plus one movement query (`closing.service.ts:1550-1637`). The report should reuse them rather than add another summing path.
2. Three pieces are missing:
   - No server code separates money collected against day D's sales from money collected against older debts. `payments.kind` is used in no aggregate (`sales.service.ts:1288` is the only filter on it).
   - The "owed on these sales" figure uses the current `balance_due`, not the value as it stood at the end of D (`dashboard.service.ts:150-152`, `closing.service.ts:1026`).
   - A missing cost cannot be detected, because cost is NOT NULL and a missing cost is stored as 0 (`schema.prisma:888, 1047, 1338`; `row-validation.ts:196-204`).
3. Figures that call themselves "sales" and "profit" disagree today:
   - Rollup revenue (closing `total_sales`, digest, notification) leaves out the whole-sale discount, which the Sell tab always sends (`rollup.service.ts:97-108`; `sales.service.ts:272-275, 425`; `sell.tsx:475`).
   - The summary's profit formula ignores return adjustments (`accounting-rules.ts:173-188` against `rollup.service.ts:212, 275`).
4. A close cannot honestly record "not verified" today:
   - `daily_closings.counted_cash` and `difference` are NOT NULL (`0001_init/migration.sql:392-393`).
   - The opening-cash chain treats the last locked `counted_cash` as a real count (`closing.service.ts:1500-1514`).
   - Reconciling a skipped channel treats "no difference" as 0 (`closing-lifecycle.ts:169`).
   - A **small migration is required** (§6).
5. Account channels have no opening balance (`channels.ts:149`), yet the count screen asks for "Balance shown by the account" (`en.ts:127`, `count.tsx:417-418`). This produces a false discrepancy every day.
6. "Needs review" does not look at activity. The previous-day objects return `standing:'open'` with `needsReview:true` for a date that has no closing row (`closing-lifecycle.ts:24, 39-41`), so the three surfaces disagree.
7. The only post-confirmation correction for day money is Milestone B on a confirmed refund payout (`correction.dto.ts:13-15`). Sale payments, confirmed expenses and purchase payments cannot be corrected.

---

## 1. The accounting model as it exists

**Business date.** `BusinessDayService.assign(branch, instant)` returns the local date in the company's timezone. Instants before 06:00 fall on the previous date, unless the Owner has started the next day early (`business-day.service.ts:59-72, 80-90`; `business-day.ts:17, 92-94`). The date is assigned once, when the row is written. Rows that existed before 0076 were backfilled with `DATE(ts)` in UTC, not the 06:00 rule (`0076_business_day_and_reopen/migration.sql:21-27, 41, 56, 71`).

### 1a. Sales and money coming in

| Record | Table · amount column | Real money when | Channel / account column | Business-date column | Written by (route · permission · code) |
|---|---|---|---|---|---|
| Sale header | `sales` · `total` = subtotal − (Σ line discount + saleDiscount). Also stored: `total_cost`, `margin` = total − total_cost, `amount_paid`, `balance_due`, `pay_status` (`sales.service.ts:271-278, 394-402`; `sales-policy.service.ts:50-59`) | On insert. There is no void path: `is_reversed` is never set to true anywhere (reads only, e.g. `sales.service.ts:810, 915`; `schema.prisma:1285`) | n/a (tender lives in `payments`) | `sales.business_date` (`sales.service.ts:359-366, 393`) | `POST /v1/sales` · `sale.create` · `createSale` (`sales.service.ts:91-710`) |
| Sale line | `sale_items` · `price`, `quantity`, `discount` (line only; saleDiscount is **not** allocated to lines), `cost` snapshot (`sales.service.ts:187, 241, 414-429`) | Inserted with the sale. `voided` is never written; the legacy return route answers 410 (`sales.controller.ts:155-168`) | n/a | through `sales.business_date` | same |
| Checkout tender | `payments` with `kind='at_sale'` · `amount` (CHECK > 0, `0074_sale_receivables/migration.sql:68`) | **On insert.** The table has no status column (`schema.prisma:1359-1422`). The money is recorded as received on the employee's word (`record-payment.dto.ts:6-12`). `recorded_by_id` is the only "who confirmed" field (`schema.prisma:1374-1376`) | `method`. Cash carries no account (CHECK `ck_payments_cash_no_account`, `0045_progressive_closing/migration.sql:73-75`). Non-cash needs an active `receiving_account_id`; label and provider are snapshotted (`sales.service.ts:507-567`). A split tender is N rows (`sales.service.ts:494-570`) | `payments.business_date` = the sale's date (`sales.service.ts:553-556`) | `createSale` |
| Later collection | `payments` with `kind='collection'` · `amount` | On insert. It raises `amount_paid`, lowers `balance_due` and recomputes `pay_status` (`sale-payments.service.ts:169, 198-201`; `sale-payment-rules.ts:24-41`). No revenue event fires (`sale-payments.service.ts:38-39`) | Same rules. Cash sent with an account is refused (`sale-payments.service.ts:85-92`) | `assign(branch, paid_at)`. `paid_at` may be back-dated, but not before `sold_at` and not more than 60 s ahead (`sale-payment-rules.ts:128-145`; `sale-payments.service.ts:129, 136, 180`) | `POST /v1/sales/:id/payments` · `sale.create` (`sales.controller.ts:125-135`; `sale-payments.service.ts:60-235`) |
| Customer debt cache | `customers.balance` | Not money. It is a cache: += `balance_due` at the sale, −= amount at a collection (`sales.service.ts:572-579`; `sale-payments.service.ts:203-209`) | — | none | the same writers |

### 1b. Money going out and money coming back

| Record | Table · amount column | Real money when | Channel / account column | Business-date column | Written by |
|---|---|---|---|---|---|
| Return approval (profit reversal plus refund obligation) | `return_reversals` · `gross_refund` = price×qty − line discount (`return-workflow.ts:25-27`), `adjustment_total`, `net_refund_due` = gross − adj (CHECK `0036_returns_workflow/migration.sql:269-270`), `line_cost` | Profit effect at insert. **Not cash.** Append-only (UPDATE/DELETE triggers, `0036:281-298`) | none | `approval_date` = today's business date (`returns.service.ts:537-538, 586`) | `POST /v1/returns/:id/approve` · `return.approve` (+ `return.exception`) (`returns.service.ts:493-642`). Refused on a locked day (`returns.service.ts:539-547`) |
| Refund payout | `refund_payouts` · `reported_amount` (= `net_amount_due`, CHECK `0038_refund_payout/migration.sql:133`) | **Only `status='confirmed'`** (`rollup.service.ts:227-236`; `closing.service.ts:1574-1581`). `reported_pending_confirmation` is a claim that carries no date (`returns.service.ts:793-818`; `schema.prisma:3010`) | `method` cash\|account, `receiving_account_id` | `confirmation_date` = today at confirmation (`returns.service.ts:958-959, 984-988`) | Report: `POST …/refund/report` · `refund.report`. Confirm: `POST …/refund/confirm` · `refund.confirm` (`returns.service.ts:729-852, 942-1032`). Confirmation is refused on a locked day (`returns.service.ts:966-974`) |
| Financial correction | `financial_corrections` · `amount` (copied from the target, `corrections.service.ts:134-136`) | `status='approved'` (`rollup.service.ts:255-267`) | method copied; account = `COALESCE(payout, settlement)` account (`closing.service.ts:1616-1626`) | `correction_date` = today at the target's branch (`corrections.service.ts:184-185, 209`) | `POST /v1/corrections` (`financial.correction.request`), `/:id/approve` (`financial.correction.approve`) (`corrections.controller.ts:27-72`) |
| Expense | `expenses` · `amount` | `status='confirmed'` (`rollup.service.ts:133-146`) | `method` cash\|account (CHECK `0044_expense_workflow/migration.sql:124-132`) | **No business_date column.** Variable: `confirmation_date` = today at confirm (`expenses.service.ts:201-203`). Fixed: `due_date`, typed by the client (`expenses.service.ts:161`). The key is `IF(expense_class='fixed', due_date, confirmation_date)` (`closing.service.ts:1611-1612`) | Report `POST /v1/expenses` · `expense.submit`. Confirm/reject · `expense.review` (`expenses.service.ts:196-292`) |
| Stock purchase payment | `supplier_payments` · `amount` = purchase total (paid in full) (`purchasing.service.ts:295-307, 397-411`) | On insert; no status (`schema.prisma:1172-1206`) | `method` from the client; non-cash needs an active account (`purchasing.service.ts:162-187`). The branch comes only through `purchases.branch_id` | `business_date` = assign(now) (`purchasing.service.ts:408`) | `POST /v1/purchases` · `purchase.manage` AND `unit.add` (`purchasing.controller.ts:13-18`). **No locked-day guard** |
| Supplier settlement (legacy) | `supplier_settlements` · `amount` | `status='confirmed'` | cash\|account | `confirmation_date` | No writer since the Suppliers module was removed (commit `47c2e06`). Still read (`closing.service.ts:1523-1528, 1585-1591`) |

### 1c. Closing and reconciliation records

| Record | Key columns | Meaning |
|---|---|---|
| `daily_closings` | `expected_cash`, `counted_cash` (NOT NULL), `difference` (NOT NULL), `total_sales` (= rollup revenue), `total_profit` (= rollup `net_profit`), the refunds/corrections/expenses/supplier cash components, `status` counting\|counted\|locked\|reopened, `first_closed_*`, `reopened_*`, `reopen_count`, `version` (`schema.prisma:1650-1742`; `0001_init/migration.sql:392-393`) | The figures mean something only when `status='locked'`. A counting row stores 0 placeholders (`closing.service.ts:1341-1360`). A reopened row still holds the previous close's figures (`closing.service.ts:618-629`) |
| `closing_channel_counts` | `sales_in`, `refunds_out`, `supplier_out`, `expenses_out`, `corrections_in`, `opening_balance` (cash only), `expected`, `counted?`, `difference?`, `is_skipped`, `skip_reason` (`schema.prisma:1754-1811`; CHECKs `0045:198-203`) | Upserted on each count (`closing.service.ts:1363-1397`). Frozen at lock and **overwritten in place** on a reclose (`closing.service.ts:343-381, 365`) |
| `closing_discrepancies` | signed `amount`, `status`, `resolution` | Opened at lock for each counted, non-skipped channel whose difference is not 0 (`debt-rules.ts:160-167`; `closing.service.ts:389-423`) |
| `closing_events` | `business_date`, `kind`, `payload` JSON, `dedupe_key` (`schema.prisma:1881-1922`) | The closed/reclosed payload holds expectedCash, countedCash, difference, openingCash, totalSales, netProfit and a channel summary (`closing.service.ts:443-472`). This is the only record of a first close's figures that survives a reclose |

### 1d. Money outside the closing model

- **Ledgers the closing never reads.** `loan_ledger`, `consignment_ledger` and `employee_debt_entries` carry a cash/account method, but `channelMovements` never reads them (`closing.service.ts:1556-1627`).
  - Their `entry_date` is the UTC calendar day, not the business date (`loans.service.ts:299, 368, 405, 490, 530`; `consignments.service.ts:594, 670, 748, 803`; `discrepancies.service.ts:141, 249`).
  - Only the loan exclusion is documented as a design choice (`loans.service.ts:545-591`; `docs/21_PRODUCT_DECISIONS.md:5695-5696`).
  - Owner withdrawals, deposits to a bank and account-to-account transfers are not modelled at all (`docs/21_PRODUCT_DECISIONS.md:5502`).
- **Receiving accounts** belong to the company. They have no branch column and no balance column (`schema.prisma:2269-2314`). Every branch's closing lists every active account (`closing.service.ts:1472-1478`).
- **`daily_rollups`** (`rollup.service.ts:89-379`) is derived:
  - `revenue` = Σ(price×qty − line discount). It excludes saleDiscount and does not filter on `is_reversed`.
  - `cogs` = Σ cost×qty.
  - `expenses` uses the IF key above.
  - `returns_*` keys on `approval_date`, `refunds_paid_*` on `confirmation_date`, and `corrections_*` on `correction_date` (both target kinds).
  - `net_profit` = gross − returns_gross_profit − expenses (`rollup.service.ts:97-108, 133-150, 178-212, 227-275`).
  - It is recomputed synchronously by close (`closing.service.ts:189`), return approval, refund confirmation and correction approval. For sales and expenses the recompute is fire-and-forget and errors are swallowed (`in-process-rollup-queue.ts:16-26`).

---

## 2. What the server computes and what the client infers

### 2a. Server figures (endpoint · function · date key)

| Figure | Endpoint · function | Date key and notes |
|---|---|---|
| salesValue, salesCount, stillOwed, collected, expenses (Home) | `GET /v1/home` · `DashboardService.home` (`dashboard.service.ts:55-160`). No route permission; figures need `report.view` (`dashboard.service.ts:59-60`) | salesValue = Σ `sales.total` by `sales.business_date`. collected = Σ payments by `payments.business_date`. stillOwed = **current** Σ `balance_due` of the range's sales. expenses use the IF key (`dashboard.service.ts:95-113, 144-152`) |
| Money overview | `GET /v1/closings/overview` · `overview()` (`closing.service.ts:955-1044`), `report.view` | cashNow = today's cash expected including the opening; cashOpening (`:1009-1010`); accountsToday in/out/net; period {phonesSold (IMEI rows only, `:973-979`), salesCount, salesValue, collected = Σ salesIn over all channels, outstanding (current), refunds = Σ refundsOut}; outstandingAll; expensesToday keyed on **confirmation_date for both classes** (`:985-998`) |
| Period movements | `GET /v1/closings/movements` · `periodMovements()` (`closing.service.ts:926-946`), `report.view` | Per channel moneyIn/moneyOut/net, no opening |
| Live day view | `GET /v1/closings/open/view` · `openView()` (`closing.service.ts:1052-1155`), `closing.count` | Per-channel components, expected, counted, difference **recomputed live for any date, locked days included** (`:1065-1090`); complete (`:1115`); expectedCash, openingCash, sinceLastCount (`:1118-1121`); standing (`:1099`); previousDay (`:1142-1153`); history (`:1164-1265`) |
| Close snapshot | `POST /v1/closings` · `close()` (`closing.service.ts:162-537`), `closing.perform` | Response: digest, cash, channels, paidOut, sinceFirstCount, comparison (`:505-536`). **The mobile app discards it** (`lib/closing.ts:151-152`) |
| Raw closing row | `GET /v1/closings/:date` · `getClosing()` (`closing.service.ts:881-889`), `closing.perform` | Returns counting-row placeholders as they are |
| Digest | `GET /v1/digests/:date` · `getDigest()` (`closing.service.ts:891-919`), `report.view` | Frozen revenue/cogs/gross next to **live** rollup expenses and netProfit |
| Expected cash (scalar, stored) | inside `close()` (`closing.service.ts:205-238`) | Payments aggregate + rollup refunds/expenses/corrections + `stockPaidOn` (`:1521-1539`). At sign-off it matches the channel path (the verifier's correction). The divergence to watch is snapshot against live |
| Per-channel expected | `expectedChannels()` → `channelMovements()` → `buildChannels()` (`closing.service.ts:1465-1489, 1550-1637`; `channels.ts:92-157`) | Each component uses its own stored date column |
| Opening cash | `openingCash()` (`closing.service.ts:1500-1514`) | Last **locked** `counted_cash` + expected cash movement of the unlocked days in between |
| Period P&L | `GET /v1/analytics/summary` · `accounting-rules.profit()` (`summary.service.ts:101-107, 190-225`; `accounting-rules.ts:173-188`) | Ignores returns_adjustments. cash.inflow = billed revenue (`summary.service.ts:129-136`) |
| Refund summary | `GET /v1/returns/refunds/summary` · `refundSummary()` (`returns.service.ts:1142-1247`), `return.view` | approved (approval_date), liability (all time, `:1165-1178`), awaitingConfirmation (all time, `:1180-1184`), confirmed (confirmation_date) |
| By-day and outstanding | `GET /v1/sales/by-day` (`sales.service.ts:896-933`), `GET /v1/sales/outstanding` (`:807-887`, **limited to 500 rows**) | by-day keys on `sales.business_date`; outstanding is a point-in-time figure |

**Computed nowhere on the server:**
- money collected at checkout (`kind='at_sale'`) as an aggregate;
- the split between collections for D's sales and collections against older debts;
- the amount owed on D's sales as of the end of D;
- a count of lines with missing cost;
- the whole-sale-discount difference between `sales.total` and rollup revenue;
- a "physically verified" flag on a close;
- an activity-based day standing;
- returns, refunds and corrections counts in the closing snapshot (they exist only in `daily_rollups`, `schema.prisma:2517, 2523, 2536`).

### 2b. Client inferences

| Inference | Where | Risk |
|---|---|---|
| Count-screen "Expected in total / Counted so far / Difference" and done/total | `count.tsx:139-146, 209-245` | Adds the cash balance (opening included) to account day-flows. Expected covers every countable row, while Counted and Difference cover only counted rows, so the three figures stop adding up once any row is uncounted or skipped. Sums are not rounded |
| Review dialog message | `count.tsx:166-175` | Built from those same phone-side sums |
| History captions `Number(v ?? 0)` | `closing/index.tsx:318-345` | An absent amount prints as 0. A fully Bankily-paid sale reads "+0 cash" |
| "Nothing was recorded for this day" | `closing/index.tsx:290-293` | Based on `history.length===0`, but the history omits collections on older sales, expenses, refunds and purchases (`closing.service.ts:1164-1229`) |
| Period window | `period.ts:32-38`; `home.ts:106-121` | Falls back to the **UTC** date while loading, or when `/closings/business-day` is refused (it needs `closing.count`) |
| Export day count | `period.ts:51-54` | UTC |
| Date chips | `home-day.ts:161-177` | Calendar arithmetic from the server's `today` |
| Expense cash-after preview | `expense-rules.ts:12-15`; `expenses/new.tsx:284-291` | Subtracts every cash expense from today, although a fixed expense lands on its due date |
| Receipt status / owed | `receipt-html.ts:197-202, 212-213`; `sell.tsx:396-421` | A partly paid sale's post-sale receipt prints "Paid" |
| Refund stage "awaitingReport" | `returns/[id].tsx:119-122` | Ignores correction state |
| Corrections list cache | `lib/corrections.ts:20-27` | Keyed per branch while the server list covers the whole company (`corrections.service.ts:302-316`) |

---

## 3. The five report sections: formulas over existing records

In all SQL below, `company_id` scoping is implied.

### 3.1 Sales

```sql
-- S1: completed sales of D (every sale is completed; there is no pending sale state)
SELECT COUNT(*) AS sales_count, SUM(s.total) AS sales_value,
       SUM(s.total_cost) AS cogs, SUM(s.discount) AS discount_total
FROM sales s
WHERE s.branch_id=:B AND s.business_date=:D AND s.is_reversed=0;

-- S2: returns approved on D (they may concern earlier sales)
SELECT COUNT(*) returns_count, SUM(gross_refund) gross, SUM(adjustment_total) adj,
       SUM(net_refund_due) net_refund_due, SUM(line_cost) cost_credited
FROM return_reversals WHERE branch_id=:B AND approval_date=:D;

-- S3: money held against D's own sales, as of the end of D
SELECT p.kind, SUM(p.amount)
FROM payments p JOIN sales s ON s.id=p.sale_id
WHERE s.branch_id=:B AND s.business_date=:D AND s.is_reversed=0
  AND p.business_date <= :D
GROUP BY p.kind;   -- at_sale = "at checkout"; collection = "later the same day"
```

**Report lines**
- `salesCount`, `salesValue` = S1. This is the same basis as Home and the Money overview (`dashboard.service.ts:95-104`; `closing.service.ts:968-972, 1024`). **Do not** use rollup revenue: it is higher by Σ saleDiscount (`rollup.service.ts:98`; `sales.service.ts:272-275, 425`).
- `returns` = S2, as its own line, labelled "approved today". `netSalesValue = salesValue − S2.net_refund_due`. Revenue falls by the gross refund, and adjustments are kept as revenue (`rollup.service.ts:212`).
- `collectedForTheseSales` = Σ S3 (sub-lines: at checkout, later the same day). `owedOnTheseSales = salesValue − collectedForTheseSales`. Because `amount_paid` = Σ payments (only `createSale` and `SalePaymentsService.record` write it, `sales.service.ts:400-402`; `sale-payments.service.ts:198`), this equals the current Σ `balance_due` while D is today, and gives the correct as-of figure for a past D.
- `itemsSold`: `SUM(si.quantity)` over non-voided lines. The existing `phonesSold` counts only IMEI rows (`closing.service.ts:973-979`).

**Existing code to reuse.** The S1 aggregates in `overview()` (`closing.service.ts:968-972`) and the S2 query in `recomputeDaily` (`rollup.service.ts:178-192`).

**Missing.** S3 as a query. The only `kind='at_sale'` filter is the replay check (`sales.service.ts:1288`). An items-sold count for all tracking types.

### 3.2 Money movement

Reuse `expectedChannels(B, D, D, opening)` (`closing.service.ts:1465-1489`), which feeds `buildChannels` (`channels.ts:92-157`). It already gives, per channel (cash, each account, unattributed):
- `salesIn` (payments by `payments.business_date`, `:1559-1571`)
- `correctionsIn` (`:1616-1626`)
- `refundsOut` (confirmed only, `:1574-1581`)
- `supplierOut` (supplier payments + legacy confirmed settlements, `:1583-1602`)
- `expensesOut` (confirmed, IF key, `:1604-1613`)

**One new query** splits `salesIn` by debt age:

```sql
SELECT IF(p.method='cash','cash','account') ch, p.receiving_account_id acct,
  SUM(IF(s.business_date = :D, p.amount, 0)) todays_sales,
  SUM(IF(s.business_date <  :D, p.amount, 0)) older_debts
FROM payments p JOIN sales s ON s.id=p.sale_id
WHERE s.branch_id=:B AND p.business_date=:D
GROUP BY ch, acct;
-- check: todays_sales + older_debts = channel.salesIn
```

Split on `sales.business_date` against D, **not** on `payments.kind`: a same-day balance payment has kind `collection` (`sale-payments.service.ts:176, 180`).

**Lines per channel.**
- In: "for today's sales", "collected on older debts", "refund corrections returned".
- Out: "refunds paid (confirmed)", "stock purchases paid", "expenses paid".
- Net. Totals across channels.
- The unattributed bucket is shown and included in the totals, but it is never countable (`channels.ts:147, 204-206`; `closing.service.ts:1002`).

**Excluded explicitly, shown as information only.**
- Refund payouts in `reported_pending_confirmation`. Only a currently-pending list can be shown, because a report carries no business date (`returns.service.ts:1180-1184`).
- Reported expenses.
- Loan, consignment and employee-debt money (§1d).
- A reported cash refund has usually already left the drawer. It therefore creates a shortage on the report day and a surplus on the confirmation day (`closing.service.ts:213, 234-238`). The report must warn about it, not book it.

**Account inflows** are labelled "recorded by staff; not verified with the provider". There is no pending or verified state on payments (`schema.prisma:1359-1422`).

### 3.3 Expenses

```sql
SELECT id, category, expense_class, is_salary, amount, method, account_label_snapshot,
       IF(expense_class='fixed', due_date, confirmation_date) AS key_date, confirmed_at
FROM expenses
WHERE branch_id=:B AND status='confirmed'
  AND IF(expense_class='fixed', due_date, confirmation_date) = :D;
```

- Totals: total, cash, account, fixed, salaries, count. They must equal `rollup.expenses/expenses_cash/expenses_fixed/expenses_salary` (`rollup.service.ts:133-150`) and Σ channel `expensesOut` (same key, `closing.service.ts:1611-1612`).
- **Do not reuse** `overview.expensesToday`. It keys fixed expenses on the confirmation date (`closing.service.ts:985-986`).
- A confirmed refund is never an expense: `expenses.service.ts` is the only writer of `expenses` (`expenses.service.ts:148, 217, 261, 360`).
- Stock purchasing is never an expense and never COGS. It is `supplierOut` in §3.2 only; the rollup has no purchase input (`rollup.service.ts:97-108, 269-275`).
- Category is free text (`create-expense.dto.ts:25-28`), so the "breakdown" groups by category string, capped to the top N plus "other".

### 3.4 Result

Under the existing model, COGS is the recorded sale-line cost snapshot: unit cost, or the weighted-average stock cost (`sales.service.ts:187, 241`; `stock-cost.ts:15-18`). Returns credit back the snapshotted `line_cost` on the approval date (`returns.service.ts:581`; `rollup.service.ts:178-212`).

```text
netSales              = S1.sales_value − S2.net_refund_due
costOfUnitsSold       = S1.cogs − S2.cost_credited          (Σ sales.total_cost = Σ si.cost×qty; sales.service.ts:277)
grossProfit           = netSales − costOfUnitsSold
variableExpenses      = §3.3 where class='variable'
resultBeforeFixed     = grossProfit − variableExpenses
fixedExpenses         = §3.3 where class='fixed'   (in full, on the due date)
resultAfterExpenses   = resultBeforeFixed − fixedExpenses
```

- This equals `rollup.net_profit − (Σ sales.discount − Σ sale_items.discount)`. The difference is exactly the unallocated whole-sale discount. Emit a warning when it is not zero, because the digest and notification profit will differ.
- **Do not reuse** `accounting-rules.profit()`: it ignores adjustments (`accounting-rules.ts:173-188`).
- Compute from source tables, not from `daily_rollups`. That table can be stale after a swallowed async recompute (`in-process-rollup-queue.ts:16-26`). Extract the read part of `recomputeDaily` into a pure `dayAccounting(B, D)` so the rollup and the report share one query set; `recomputeDaily` itself writes.
- **Cannot calculate yet** (§5): if any S1 sale line, or any S2 reversal, has cost ≤ 0.005, every profit field is `null` with reason `cost_missing` and a line count. Never 0.

### 3.5 Expected balances

**Cash drawer**, every signed term, reusing `buildChannels` for the cash channel (`channels.ts:149-157`; `closing.service.ts:1559-1626`):

```text
expectedCash(D) = openingCash(D)
  + Σ payments.amount            [method='cash', business_date=D, sales.branch_id=B]
  + Σ financial_corrections.amount [status='approved', method='cash', correction_date=D, branch=B]
  − Σ refund_payouts.reported_amount [status='confirmed', method='cash', confirmation_date=D, branch=B]
  − Σ supplier_payments.amount   [method='cash', business_date=D, purchases.branch_id=B]
  − Σ supplier_settlements.amount [status='confirmed', method='cash', confirmation_date=D, branch=B]   (legacy)
  − Σ expenses.amount            [status='confirmed', method='cash', branch=B, IF(fixed,due_date,confirmation_date)=D]

openingCash(D) = counted_cash(L) + Σ_{d=L+1..D−1} cashNet(d)     (closing.service.ts:1500-1514)
  where L = latest daily_closings row with status='locked' and closing_date < D; 0 if there is none
```

**Each account A.** The opening is always 0 (`channels.ts:149`).

```text
expectedMovement(A,D) = Σ payments[method<>'cash', account=A] + Σ corrections[target account=A]
  − Σ refunds[method='account', account=A] − Σ supplier_payments/settlements[account=A]
  − Σ expenses[method='account', account=A]
```

**Labels**
- Cash: "Expected in the drawer: opening from the last closed count on {L}, plus today's recorded movement". Show `anchorDate`, and "no counted opening yet" when L does not exist.
- Account: "Movement recorded through {label} today. This is not the account balance. Bankily receipts are recorded by staff and not confirmed with the provider." The backend stores no account balance (`schema.prisma:2271-2277`; `docs/04_BUSINESS_RULES.md:51`).

**Data that is missing.** Any account opening or balance. Negative expected figures: counts must be ≥ 0 (`record-count.dto.ts:37-42`), but an account's net movement, and the cash expected when no day was ever locked, can be negative.

---

## 4. Double-count hazards and how each formula avoids them

| Hazard | Where it bites today | How the §3 formulas avoid it |
|---|---|---|
| **Split tenders** | A sale has N `payments` rows (`sales.service.ts:494-570`) | Money is summed from `payments` per channel. Sales value comes from `sales.total` exactly once. `amount_paid` is never summed next to payments |
| **Debt collections against today's sales** | "collected" mixes older-debt money into D (`dashboard.service.ts:107`; `closing.service.ts:1002`). Summing `amount_paid` for D's sales and adding collections dated D counts **collections on those sales dated inside D** twice (verifier's correction) | One split on `s.business_date` against D. The check `todays_sales + older_debts = salesIn` must hold, and Σ `todays_sales` must equal S3 |
| **Partial payments / "owed"** | stillOwed is the *current* `balance_due` (`dashboard.service.ts:126, 133`). For a period, collected + stillOwed is not a double count (the reader's claim was refuted). It is off by a missing term (later collections) and an extra term (older-debt money) | `owed = salesValue − S3`, using `p.business_date ≤ D`, so it reconciles by construction |
| **Returns against refunds** | Profit reverses at `approval_date`; cash moves at `confirmation_date` (`rollup.service.ts:178-239`). `daily_closings.total_returns` is the **gross** figure (`closing.service.ts:198`) | Returns go in §3.1 and §3.4 only (net_refund_due, line_cost). Refund cash goes in §3.2 only. Refunds paid are never subtracted from profit |
| **A return on a credit or partial sale** | A full refund becomes due while `balance_due` is left alone (`returns.service.ts:516-528`; there is no balance code in returns/) | The report must not add the refund liability to receivables. It shows a warning `return_on_unpaid_sale` |
| **Refund approval against payout** | `reported_pending_confirmation` counts nowhere, by design | Pending payouts appear only under "pending", never in the channel lines |
| **Refund correction** | The original payout stays on its day; the correction is +correctionsIn on the correction day. Filtering out the corrected payout as well would remove the money twice (`rollup.service.ts:241-254`; `correction-sql.ts:16-35`) | Channel lines keep both. `correctionsTotal` also includes supplier-settlement corrections (`rollup.service.ts:255-264`), so its label must not say "refund" only |
| **Reopen / reclose periods** | A reclose recomputes the whole day. `sinceFirstCount` is a subset (`closing.service.ts:1268-1281`). Channel rows are overwritten in place (`:365`). Discrepancy rows **over-count** after several recloses, because only the newest row is compared (`closing.service.ts:390-399`; `closing-lifecycle.ts:171-176`, verifier trace −1200 against a real −700) | The report is always the whole day. `sinceFirstCount` is never added. Discrepancy status comes from the latest channel difference, never from Σ discrepancy amounts. Each close's report is stored in its own event payload (§6) |
| **Stale counts after a reopen** | Counts taken before `reopened_at` stay non-null (`closing.service.ts:1088`) | A stale count is treated as "not verified" and never added to counted totals |
| **Opening balance** | cash `expected`, `expectedCash` and `cashNow` already include the opening (`channels.ts:149-151`; `closing.service.ts:1009`). Summing daily expected cash across days counts the drawer twice | Opening is shown once and the day's movement once. Period views use `periodMovements` (no opening) |
| **Two expected-cash paths** | Scalar (`closing.service.ts:209-238`) and channel (`:247`). They agree at sign-off. The real hazard is mixing frozen and live figures | The report uses only the channel path, and asserts it equals `daily_closings.expected_cash` at sign-off |
| **Supplier payments** | Three copies of the same union: `stockPaidOn` (`:1521-1539`), channel `supplierOut` (`:1583-1602`), summary `stockPaid` (`summary.service.ts:286-305`). `supplier_paid_total` already contains the cash part | Only channel `supplierOut` is used. It is never added to expenses or COGS |
| **Transfers** | Inter-branch stock transfers move no money (`transfers.service.ts:1027`). Account-to-account and drawer-to-bank transfers do not exist | Nothing to count. A bank deposit shows up as a cash shortage plus an account surplus, flagged as a known limitation |
| **Corrections** | An account-method correction goes into that account's channel only (`closing.service.ts:1616-1626`) | It is taken per channel from `correctionsIn` |
| **Whole-sale discount** | Rollup revenue, digest and `total_sales` are higher than Σ `sales.total` by Σ saleDiscount | The report uses the `sales.total` / `total_cost` basis and shows a warning with the difference |
| **customers.balance** | A cache of the same Σ `balance_due`, company-wide (`sales.service.ts:572-579`) | Never used |
| **Company-wide accounts** | Listed in every branch (`closing.service.ts:1474-1477`). Typed balances summed across branches count the same account once per branch | Accounts are shown as per-branch *movement* only |
| **Fixed expenses** | `expensesToday` (confirmation date) against rollup and channels (due date) (`closing.service.ts:986` vs `:1612`) | One key, the IF key, everywhere |
| **Activity check** | A cash sale produces both a `sales` row and a `payments` row | Standing uses `EXISTS`, never sums (§8) |

---

## 5. Cost gating, missing cost and fixed expenses

### Where `cost.view` is enforced today

- **Global interceptor.** `CostGatingInterceptor` (`cost-gating.interceptor.ts:30-66`) deep-strips the key names in `FINANCIAL_FIELDS` (`financial-fields.ts:7-36, 43-61`) from successful responses only (`:65`). If permission resolution fails, it strips everything (`:43-61`). It is registered after `EntitlementInterceptor` (`app.module.ts:188-190`).
- **CSV exports** drop financial columns column by column (`report-catalogue.ts:241-259`).
- **Roles** (`role-permissions.ts:200-209, 234-235, 289, 318-320, 338-390, 401-405`):
  - `cost.view` is held by owner, store_manager, store_employee and branch_manager, but not by administrator.
  - `report.view` is held by owner, store_manager, administrator and branch_manager, but not by store_employee.
  - Stated rule: cost visibility must not drag profit dashboards along with it (`role-permissions.ts:318-320`).

### Known leaks

These are why the report must not rely on key stripping:
- `cogsCredited` and `profitEffect` (`returns.service.ts:1219, 1224`, route needs `return.view`).
- `totalReturnsCogsCredited` and `totalReturnsProfitImpact` on `GET /closings/:date` (`closing.service.ts:881-889`).
- `comparison.netOperatingProfit` / `netRevenue`. From these the whole profit block can be rebuilt (`summary.service.ts:163-168`; `accounting-rules.ts:224-234`).
- `sellableInventoryValue`, `faultyHeldValue` and `totalOwnedInventoryValue` (`analytics.service.ts:130, 137, 144-146`).
- Goals progress, which has no route permission (`goals.controller.ts:14-37`).
- The `closing.completed` broadcast text "Net profit Y" (`closing.service.ts:485-491`; `notifications.service.ts:39`).
- The closed-event `netProfit`, sent to store employees who hold `cost.view` but not `report.view` (`closing.service.ts:461-470`).
- The `approval_required` error body, which can be probed to find cost (`sales-policy.service.ts:134-144`; errors are not stripped, `cost-gating.interceptor.ts:65`).
- Sort order of profit rankings (`dashboard.service.ts:277-279`).

### Required report behaviour

1. Build the `result` block in the service only when the caller holds `cost.view` **and** either `report.view` or `closing.perform`. Otherwise return `result: { status: 'hidden' }` with no numbers.
2. Also withhold every field that would let someone derive profit. That covers `S1.cogs`, `S2.cost_credited`, and any comparison or delta of profit. The rest of the report exposes only sales, net refund due, expenses and money, from which profit cannot be derived.
3. As defence in depth, add the new key names (`grossProfit` already, plus `costOfUnitsSold`, `resultBeforeFixed`, `resultAfterExpenses`, `returnsCostCredited`, `missingCostLines`) to `FINANCIAL_FIELDS`, and add a spec that asserts they are absent for a caller without `cost.view`.
4. The report snapshot stored in `closing_events.payload` goes through the same builder when it is read back. It is never returned raw.
5. Remove `Net profit` from the broadcast body, or target it at Owners only.

### Missing-cost detection

The schema has no "cost unknown" state: all cost columns are NOT NULL (`schema.prisma:888, 1047, 1338, 1279-1280`). A zero cost can get in two ways:
- an explicit 0 in the opening import, accepted with only a warning (`row-validation.ts:196-204`). A *missing* import cost is a row error (`row-validation.ts:124-127, 191`; `imports.service.ts:229`);
- a transfer passing a 0 cost through (`transfers.service.ts:1004-1009`).

A sold unit's cost can never be corrected afterwards (`inventory.service.ts:1104-1108`). Rule:

```sql
SELECT COUNT(*) FROM sale_items si JOIN sales s ON s.id=si.sale_id
WHERE s.branch_id=:B AND s.business_date=:D AND si.voided=0 AND si.cost <= 0.005;
-- plus return_reversals approved on D with line_cost <= 0.005
```

If the count is above 0, the result is `{status:'cannot_calculate', reason:'cost_missing', missingCostLines:n}` and every profit figure is null. The honest message: "Cannot calculate yet: N items sold today have no recorded cost."

Errors this rule cannot detect, to be listed as known limits:
- the import merge that skips cost re-averaging (`imports.service.ts:263-269`);
- rounding of the 2-decimal average (`schema.prisma:1047`; `stock-cost.ts:99-101`);
- consignment dispositions, which recognise no revenue or COGS at all (`consignments.service.ts:563-596`; `consignment-money.ts:149-165` has no callers).

### Fixed expenses

- The older rule (§10, fixed costs do not hit daily profit, `docs/21_PRODUCT_DECISIONS.md:931-932`) sits in a section marked blocked (`:929`).
- The approved Milestone D rule books fixed expenses in full on their due date (`docs/21_PRODUCT_DECISIONS.md:1294-1299`). The rollup implements that (`rollup.service.ts:143-144, 275`).
- **Decision: fixed expenses apply on their due date.** The report shows both `resultBeforeFixed` and `resultAfterExpenses`, labelled "Result after expenses recorded to {D}. Fixed costs are counted in full on their due date, not spread over the month."
- Do not call it "net profit". It is a single-day figure that omits unpaid stock, loans and consignment.

---

## 6. The close contract: today and required

### Today (`POST /v1/closings`, `closing.perform`, body `{countedCash?, date?}`; `create-closing.dto.ts:15-25`)

| Aspect | Current behaviour |
|---|---|
| Date | Refuses future dates only (`closing.service.ts:165-167`). Any past unlocked day can be closed through the API. The mobile never sends a date (`lib/closing.ts:152`), so across 06:00 it closes the *new* day |
| First close | Needs only a cash figure: a recorded, non-skipped cash count, or `dto.countedCash` (`closing.service.ts:277-289`). Account completeness is **not** checked on the server; `countingComplete` is used only by `openView` (`:1115`). The client disables sign-off until `day.complete` (`count.tsx:299`) |
| Reclose | Every countable channel must be counted or skipped with `countedAt ≥ reopenedAt` (409 `fresh_count_required`), **and** there must be a recorded cash count; `countedCash` is refused as a substitute (`closing.service.ts:254-276, 286-288`; `closing-lifecycle.ts:121-137`) |
| Skip | Per channel, with a reason; a skipped channel has no counted value (`closing.service.ts:1297-1312`; CHECK `0045:198-200`). The server allows skipping cash, and then close fails with 400 (`:278, 286-288`) |
| Snapshot | Writes `daily_closings` (NOT NULL counted/difference) and freezes channel rows (`:297-381`). Discrepancies open for counted, non-skipped channels with a difference (`debt-rules.ts:160-167`). The one-step `countedCash` path opens **no** discrepancy (`:289-290, 345-357, 395`) |
| Reconcile | `reconcileDiscrepancy(existing, null)` treats null as 0. Skipping on a reclose auto-resolves a pending discrepancy, or opens a reverse one (`closing-lifecycle.ts:168-177`; `closing.service.ts:394-421`) |
| Consistency | The rollup recompute (a write) and every read happen **before** the transaction (`:189-293` vs `:295`). A sale committed in that window does not auto-reopen the day and is missing from the snapshot (`:739-743`) |
| Idempotency | None. A retry returns 409 "already closed" (`:182-184`). With no row, a concurrent create hits P2002, mapped to 409 (`all-exceptions.filter.ts:160-161`). The event dedupe keys are `closing:<id>:closed` / `…:reclosed:<n>` (`:449, 460`) |
| Reclose history | Channel rows are overwritten, and digest lines are **hard-deleted** and recreated (`:365, 428-441`). The first close survives only in the event payload |
| Late money | Sales and same-day collections auto-reopen the day (`closing.service.ts:733-774`; `sales.service.ts:632-636`; `sale-payments.service.ts:141-150`). Refund confirmation, return approval, variable expenses and corrections are refused with 409 `day_already_closed`. **Purchases and fixed expenses land on a locked day with no guard** (`purchasing.service.ts:397-411`; `expenses.service.ts:205-215`). Their outflow then falls outside every expected-cash figure, because the next opening anchors on the counted cash |

### What blocks closing without counts

1. The server demands a cash figure (`closing.service.ts:277-289`).
2. The client requires `day.complete` (`count.tsx:299`).
3. A reclose demands fresh counts (`closing.service.ts:254-276`).
4. `counted_cash` and `difference` are NOT NULL (`0001_init/migration.sql:392-393`).
5. `openingCash` would anchor on whatever is stored (`closing.service.ts:1500-1514`).

The mobile adds a sixth block: stale rows cannot be recounted (`count.tsx:354, 392-393`), so a day auto-reopened by a late sale can never be closed again from the phone.

### Decision: a small schema change is required

Writing 0 would fake a shortage and set the next opening to 0. Writing `expected` would fake a match. The unused `notes` TEXT column (`schema.prisma:1707`) is unstructured, and every reader would still read `counted_cash`. So the change is:

**Migration (backup first, per `docs/22_BACKUP_AND_ROLLBACK.md`):**
```sql
ALTER TABLE daily_closings
  MODIFY counted_cash DECIMAL(14,2) NULL,
  MODIFY difference   DECIMAL(14,2) NULL,
  ADD CONSTRAINT ck_closings_counted_pair CHECK ((counted_cash IS NULL) = (difference IS NULL));
```

**No other schema change for the close:**
- A channel that is not verified reuses the existing skip columns: `is_skipped=1`, `skip_reason='NOT_VERIFIED_AT_CLOSE'` (a machine key, like `CASH_LABEL`/`UNATTRIBUTED_LABEL` in `channels.ts:41-42`), `counted_by_id` = the closer. This satisfies `ck_channel_counts_skip`.
- The human reason and `verified:false` go into the closed/reclosed event payload (JSON, `schema.prisma:1907`). The event kind stays the same, so no ENUM change.

**Code changes**

1. **DTO.** `{ date (required from new clients), clientUuid, reportVersion, physicalCheck: 'counted' | 'not_verified', reason? }`. A reason is required when any countable channel has no fresh count. Nothing is ever inferred from a missing `countedCash`. Keep `countedCash` for legacy clients.
2. **Real counts stay.** A fresh recorded count stays a count: its difference is stored and its discrepancy opens as today. Only channels without a fresh count become `NOT_VERIFIED_AT_CLOSE`. Stale counts (taken before the reopen) are **not** reused as counts.
3. **Cash not verified.** `counted_cash = difference = NULL`. `expected_cash` is still stored.
4. **Discrepancies.** `reconcileDiscrepancy` takes an explicit "none" for skipped or not-verified channels. It leaves a pending discrepancy untouched and opens no reverse delta. Also compare against the channel's net recorded discrepancies, not only the newest row (fixes the over-count in `closing.service.ts:390-399`).
5. **Opening cash.** `openingCash` anchors only on locked closes where `counted_cash IS NOT NULL`. A locked day that was not verified becomes a carry day: its expected movement is added. The report shows `anchorDate` and `anchorVerified`.
6. **Idempotency.**
   - If the day is locked and the latest closed/reclosed event has `payload.clientUuid = dto.clientUuid` with a matching fingerprint, return that stored report (200, `replayed:true`). Otherwise return 409 `already_closed`.
   - Treat P2002 on create the same way.
   - No schema change: `clientUuid` lives in the payload, and the existing `dedupe_key` stays.
7. **Binding to what the confirmer saw.** Recompute the report inside the transaction after `SELECT … FOR UPDATE` on the closing row. Make `autoReopenTx` lock the same row (today it reads without a lock, `closing.service.ts:739-743`). If the recomputed `reportVersion` (a hash of the figures) differs from `dto.reportVersion`, return 409 `report_changed` with the new report.
8. **Keep old snapshots.** Store the full report JSON in every closed/reclosed event payload. Stop hard-deleting digest lines, or accept that the event payload is the record. `daily_closings` keeps only the latest close.
9. **Late money on a locked day.** Purchases on a locked current day call `autoReopenTx`, as sales do. Confirming a fixed expense whose `due_date` is a locked day is refused with 409.
10. **Notices null-safe.** `reclosedNotice` reads counted/difference (`closing-notices.ts:176, 185, 201`). The first-close notification carries no count (`closing.service.ts:486-491`).

---

## 7. Corrections

### Existing flows per source type

| Source | Existing flow · route · permission | Reason | Locked-day rule | Audit | Status |
|---|---|---|---|---|---|
| Checkout payment (`payments.at_sale`) | **None.** No update or delete of payments anywhere in src. `is_reversed` has no writer | — | — | sale create only | Wrong channel or amount is permanent |
| Later collection | None to correct. Recording only: `POST /sales/:id/payments` · `sale.create` | none | Back-dating into a locked day is refused with the *expense* message (`sale-payments.service.ts:16, 152`; `expense-rules.ts:116-123`). The current day auto-reopens | Sale `update` with `after` only (`sale-payments.service.ts:211-218`) | Cannot be reversed. The code comment points to "Milestone B", which does not cover payments (`correction.dto.ts:13-15`) |
| Refund payout, reported | `PATCH /v1/returns/:id/refund` · `refund.confirm`: method, account, reference, note. Amount locked (`returns.service.ts:861-932`) | none | — | before/after | Works |
| Refund payout, confirmed | Milestone B: `POST /corrections` (`financial.correction.request`), then `/:id/approve\|reject` (`financial.correction.approve`) | Required, 1-255 chars, plus DB CHECK (`correction-rules.ts:70-79`; `0040:126`) | Lands on the target branch's current day. 409 if that day is locked (`correction-rules.ts:107-116`) | Request `create`. Approve `status_change` with no `before` and the caller's branch (`corrections.service.ts:143-157, 251-259`) | Defects: approval is **not** transactional (`:198-259`); the target is not checked against the caller's branch (`:124, 363-390`); the replacement payout is probably unreachable (`returns.service.ts:873, 948-956`; `returns/[id].tsx:119-122`, not verified at runtime) |
| Supplier settlement | Same module | same | same | same | Historical rows only (no writer) |
| Expense, reported | Reject and report again (`expense.review`) | optional | — | yes | No edit |
| Expense, confirmed | **None.** The 409 says "Correct it instead" (`expense-rules.ts:82-91`) | — | — | — | Dead end |
| Purchase payment | **None** (`purchasing.controller.ts:13-18`) | — | — | — | — |
| Sale void / price | None. Only the return workflow, which is serialized-only and custody-bound (`returns.service.ts:143-147`) | — | — | — | Quantity lines can never be reversed |
| Channel count | Re-save until locked (`closing.service.ts:1289-1455`). Reopen only on the current day (`closing-lifecycle.ts:45-50`) | skip only | A past locked day is final | count_saved event + audit | — |
| Discrepancy | `POST /discrepancies/:id/resolve` · `debt.manage`, e.g. `error_corrected` | required | — | yes | Explains the difference; changes no record (`debt-rules.ts:103-105`). The client's `expectedVersion` is ignored (`discrepancies.service.ts:114-115`) |
| business_date | None | — | — | — | Owed (`docs/21_PRODUCT_DECISIONS.md:5696, 5729`) |
| Loan payment | Loans' own `correct` action (`loans.service.ts:375-414`) | — | Outside the closing | — | Not day money |

### Minimal new server contract

**Payment correction is essential.** Payments are most of the channel movement. Without a correction, a Cash-for-Bankily mistake misstates both channels' movement in every report and every period view. The only escape today, `error_corrected`, changes no record.

Expense and supplier-payment corrections use the same contract with other target kinds, in a later phase. Sale void and price correction are **not** narrow and stay out of scope: they are refused, with a pointer to the return workflow.

- **Schema** (migration + backup):
  - `financial_corrections.target_kind` += `sale_payment`;
  - `target_payment_id` (FK payments);
  - `action` ENUM(`reverse`,`reclassify`);
  - `to_method`, `to_receiving_account_id`, `to_account_label_snapshot`;
  - a generated unique on the approved payment target (the pattern of `0040:88-94`);
  - `closing_channel_counts.corrections_out`, plus `COMPONENT_SIGN.correctionsOut = −1` (`channels.ts:27-33`). Today's `correctionsIn` can only *add* money, so a move between channels would inflate the total (`closing.service.ts:1616-1626`);
  - make the channel path the only source of `expected_cash`, to avoid adding rollup columns.
- **Preview.** `POST /v1/corrections/preview` returns, without writing: the payment before and after (method, account, amount), the sale before and after (`amount_paid`, `balance_due`, `pay_status`), the customer cache, the channel legs with the correction date, whether that day is locked, and any refusal code.
- **Request.** `POST /v1/corrections {targetKind:'sale_payment', targetId, action, to…, reason, supportingReference?, clientUuid}` · `financial.correction.request`. It moves nothing.
- **Approve.** `POST /v1/corrections/:id/approve {expectedVersion}` · `financial.correction.approve`. **One transaction** covering:
  - the status update and `correction_date` = today at the target's branch;
  - for a reversal: `amount_paid −= a`, `balance_due += a`, `pay_status` recomputed (`sale-payment-rules.ts:24-41`), `customers.balance += a`;
  - an audit row with before/after and `branchId` = the target's branch.
  After commit, one idempotent `recomputeDaily(correction_date)`. The original payment row, its day, and every snapshot and event payload stay untouched.
- **Locked-day policy.** Consistent with `correction-rules.ts:107-116`: 409 `day_already_closed` if the correction day is locked.
- **Immutability.** The DELETE trigger already exists (`0040:151`). Add a BEFORE UPDATE trigger that allows only the decision fields to change once.
- **Explicit refusals:**
  - the target is at another branch than the caller's (fixes `corrections.service.ts:124`);
  - an approved correction already exists;
  - partial amounts (full reversal only);
  - reclassifying to cash with an account, or to an inactive account;
  - a reversal that would leave a balance > 0.005 on a sale with no debtor (`sale-payment-rules.ts:81-117`);
  - a sale that is already fully refunded by an approved return;
  - **externally confirmed records**: consignment and loan ledger rows confirmed by the counterparty company (`consignment-money.ts:36-43`), return reversals (append-only), refund payouts already corrected, and legacy `returns` rows.

### "Correct a transaction" list

`GET /v1/closings/sources?date=D` returns every source row of D with business date, amount, channel/account label, status, recordedBy/confirmedBy, and `correctable` plus the route, or a refusal code:
- payments with kind and invoice, including `business_date`, which the payment view omits today (`sale-payments.service.ts:284-314`);
- confirmed refund payouts;
- expenses under the IF key;
- supplier payments;
- approved corrections;
- pending refund reports and pending expenses, as information only.

The mobile links each row to its existing flow (return detail `CorrectionSection`, expense detail, sale detail) or to the new payment-correction sheet.

---

## 8. Inactive-day standing

**Today.** The standing is decided in four places:
- `standingOf(null)` returns `'open'` even for a past date (`closing-lifecycle.ts:24`);
- `openView` overrides a past date with no row to `needs_review` (`closing.service.ts:1099`);
- `previousDayNeedsReview(null)` returns true (`closing-lifecycle.ts:39-41`);
- the previous-day objects in `businessDayView` (`closing.service.ts:146-150`), `openView` (`:1142-1153`) and Home `closingCard` (`dashboard.service.ts:211-220`).

Only the last two are rendered (`(tabs)/index.tsx:305-307`; `closing/index.tsx:278-285`). So an idle past day reads "Yesterday needs review" on Home, "Not closed" in the history notice, and "Needs review" above "Nothing was recorded". This matches the currently approved text (`docs/21_PRODUCT_DECISIONS.md:5754, 5772`), which must be amended.

**Where to compute it, once.**
1. Pure rules in `closing-lifecycle.ts`:
   - `standingOf(row, current, hadActivity)`: no row and past gives `hadActivity ? 'needs_review' : 'inactive'`, which absorbs the special case at `closing.service.ts:1099`;
   - `previousDayNeedsReview(row, hadActivity) = row ? row.status !== 'locked' : hadActivity`;
   - add `'inactive'` to `DayStanding` (`closing-lifecycle.ts:16`).
2. One async helper, `DayStandingService.standing(B, date, today)`, exported by `ClosingModule`. It loads the row and runs a single activity `EXISTS` query.
3. Call it from `businessDayView`, `openView` (standing and previousDay) and `DashboardService.closingCard`; inject it into `DashboardService`.
4. Mobile:
   - add `'inactive'` to `DayStanding` (`home-day.ts:19`) with a neutral tone and `closing.standing.inactive` in en/fr/ar (parity is enforced by `keys.ts:8-11` and `auth-language.test.ts:166-173`);
   - replace the `history.length===0` inference (`closing/index.tsx:290-293`) with the server's standing.
   The Home chip already keys on `needsReview`, so it follows automatically.

**What counts as activity on (B, D).** Use `EXISTS` only, never sums:
- a `daily_closings` row at (B, D) in any status. A count creates the row (`closing.service.ts:1341-1360`);
- `closing_events` with `business_date=D` and kind in `opened, count_saved, closed, reopened, auto_reopened, reclosed, day_started_early`. `day_started_early` is stored under the *new* day (`closing.service.ts:569-583`), so it counts for that day, never for the day that ended;
- `sales` with `business_date=D`, `is_reversed=0` (credit sales included);
- `return_reversals` with `approval_date=D`;
- any non-empty arm of `channelMovements(D,D)`: payments at `business_date=D` through `sales.branch_id` (including collections on older sales), `supplier_payments` at `business_date=D`, confirmed refunds at `confirmation_date=D`, confirmed supplier settlements, confirmed expenses under the IF key (so a cash **fixed** expense due on D counts, because it changes that day's expected cash, `closing.service.ts:1604-1613`), and approved corrections at `correction_date=D`.

**Not activity:**
- pending reports (they have no business date);
- loan, consignment and debt ledgers (UTC dates, outside the closing);
- work with no money or a timestamp only (receiving without payment does not exist, since purchases are always paid).

A back-dated collection can later turn an inactive day active. Standing is therefore computed live and never stored.

A known limit: only D−1 is checked for needing review (`dashboard.service.ts:200`). An earlier unclosed day drops out of the notice.

---

## 9. Permissions consistency

| Path | Client gate | Server gate | Who passes |
|---|---|---|---|
| Home closing card, "Review closing" → `/closing` | card shown if the server returns it (`(tabs)/index.tsx:295-311`) | `closingCard` needs `closing.count` (`dashboard.service.ts:63`) | owner, store_manager, store_employee, administrator (`role-permissions.ts:289, 358`) |
| Closing & history → `/closing/count` ("Review and close" / "Daily closing") | `isToday && closing.count`; label depends on `closing.perform` (`closing/index.tsx:125-126, 252-263`) | `GET /closings/open/view` · `closing.count` (`closing.controller.ts:64-65`) | same |
| Count screen sign-off footer | `closing.perform` and `day.complete` (`count.tsx:284-304`) | `POST /closings` · `closing.perform` (`closing.controller.ts:111-116`) | Owner; up to two delegates per branch (store_manager/store_employee, `permission-scope.ts:41, 56-59`; `access.service.ts:63-67`); administrator and branch_manager by matrix |
| Reopen | `isToday && closing.perform && canReopen` (`closing/index.tsx:249`) | `POST /closings/reopen` · `closing.perform`; `start_new` also checks `closing.start_early` in the service (`closing.service.ts:554-557`) | Owner; delegates |
| Auto-reopen | — | any `sale.create` sale or same-day collection (`sales.service.ts:632-636`; `sale-payments.service.ts:141-149`) | by design, any seller |
| Count / open | row inputs need `closing.count` (`count.tsx:158`) | `POST /closings/count`, `POST /closings/open` · `closing.count` | counters |

**Inconsistencies found**

1. **"Owner + at most two delegates" is not the whole set.** Administrator (`ADMIN_KEYS`) and the retired branch_manager hold `closing.perform` by the role matrix (`role-permissions.ts:200-209, 392, 404`). This applies only where those roles were seeded; registration provisions only owner, store_manager and store_employee (`role-provisioning.ts:37-45`; effective permissions are read from the DB, `access.service.ts:39-43`).
2. **branch_manager has `closing.perform` but not `closing.count`.** It can close through the API but cannot open any closing view.
3. **The two-delegate cap** is check-then-insert with no lock or DB cap, and it counts grants held by deactivated users (`user-management.service.ts:404-426, 272-301`).
4. **First-close completeness is enforced only by the client** (§6). The server also accepts closing past days and counting any date, future included (`closing.service.ts:165-167, 1292-1293`), while the UI offers neither (`docs/21_PRODUCT_DECISIONS.md:5754`).
5. **`start_new` does not require the day to be locked** (`closing.service.ts:554-572`).
6. **A new delegate's phone learns of the grant only on resume or branch switch.** The `['permissions']` invalidation hits a zustand store, not react-query (`team.tsx:462-463`; `permissions.ts:183-234`).
7. **Delegates may not be able to read the report they confirm.** A store_employee delegate has `closing.perform` without `report.view`. The new report must grant the sales and expenses sections to `closing.perform` holders; the result block additionally requires `cost.view` (§10).
8. **`GET /closings/business-day` needs `closing.count`.** Users with only `report.view` get UTC-dated Money periods (`home.ts:106-121`; `closing.controller.ts:57-58`).
9. **Stale comment.** The `GET closings/movements` comment says `closing.count`; the decorator is `report.view` (`closing.controller.ts:22-30`).
10. **`financial.correction.approve` and `expense.review` are in ADMIN_KEYS,** although the code calls them "Owner only" (`role-permissions.ts:200-209`; `0040:186-196`).
11. **Correction targets are not branch-scoped** (§7).
12. **Loan reminders** are fetched on the count screen without `loan.view`, which gives a 403 for store_employee (`count.tsx:496-501`; `loans.controller.ts:28-29`).

---

## 10. Proposed backend contract, mobile changes and risks

### `GET /v1/closings/report?date=YYYY-MM-DD`

The route requires `closing.count`. Sections are gated in the service from the CLS permission set, the way Home does it.

| Field | Gate | Source |
|---|---|---|
| `date, branchId, window{startsAt,endsAt,timezone}, standing, source: 'live'\|'snapshot', snapshotAt?, closeKind?, reportVersion` | `closing.count` | `DayStandingService`; for a locked day the snapshot comes from the closed/reclosed payload, otherwise live |
| `sales{count, value, itemsSold, returns{count, grossRefund, adjustments, netRefundDue}, netSalesValue, collectedForTheseSales{atCheckout, laterSameDay, total}, owedOnTheseSales}` | `report.view` OR `closing.perform` | §3.1 |
| `money{channels[{key, channel, accountId, label, isUnattributed, countable, in{todaysSales, olderDebts, correctionsBack}, out{refunds, stockPurchases, expenses}, net}], totals{in, out, net}, pending{refundReports{count, amount, cash}, expenseReports{count, amount}}, excluded[{kind, note}]}` | `closing.count` | §3.2 |
| `expenses{total, cash, account, count, variable, fixed, salaries, byCategory[], lines[{id, category, class, isSalary, amount, method, accountLabel, keyDate}]}` | `report.view` OR `closing.perform` | §3.3 |
| `result{status:'ok'\|'cannot_calculate'\|'hidden', reason?, missingCostLines?, netSales, costOfUnitsSold, returnsCostCredited, grossProfit, variableExpenses, resultBeforeFixed, fixedExpenses, resultAfterExpenses, scope:'fixed_costs_on_due_date'}` | (`report.view` OR `closing.perform`) AND `cost.view`; the service builds it explicitly, and the keys are also added to `FINANCIAL_FIELDS` | §3.4 |
| `expected{cash{opening{amount, anchorDate, anchorVerified, carriedDays}, in, out, expected, counted\|null, difference\|null, verification:'counted'\|'skipped'\|'not_verified'\|'stale'\|'not_counted'}, accounts[{accountId, label, expectedMovement, counted\|null, difference\|null, verification, basis:'recorded_movement_not_balance'}]}` | `closing.count` | §3.5 |
| `warnings[{code, severity, detail}]`: `uncounted_or_stale_channels`, `pending_refund_reports`, `cost_missing`, `unattributed_money`, `accounts_recorded_not_verified`, `fixed_expense_in_day`, `return_on_unpaid_sale`, `sale_discount_not_in_rollup`, `negative_expected`, `no_counted_opening`, `late_movement_on_locked_day` (drift between snapshot and live), `previous_day_needs_review`, `open_discrepancies` | per the gate of the section each warning describes | — |
| `close{canClose, kind:'first'\|'reclose', refusal?, requiresUnverifiedReason}` | `closing.perform` | `closeKindOf` (`closing-lifecycle.ts:102-106`) |

**Invariants asserted in the service and in a spec**
- `sales.value = collectedForTheseSales.total + owedOnTheseSales`
- `todaysSales + olderDebts = salesIn` for each channel
- Σ `todaysSales` = `collectedForTheseSales.total`
- channel `net = Σin − Σout`
- `expected.cash.expected = opening + cash.net`
- `expenses.total = Σ lines = Σ channel expensesOut`
- `grossProfit = netSales − costOfUnitsSold`
- `resultAfterExpenses = grossProfit − expenses.total`
- at sign-off, `expected.cash.expected = daily_closings.expected_cash`

**`POST /v1/closings`.** Extended as in §6. It returns the frozen report (same shape, `source:'snapshot'`), stored in the event payload.

**`GET /v1/closings/sources?date=`.** Returns the §7 list. Gate: `closing.perform` OR `financial.correction.request`.

**Correction endpoints.** `POST /v1/corrections/preview` plus the `sale_payment` target (§7).

**Backend work, in order**
1. Extract the pure `dayAccounting(B, D)` from `recomputeDaily`, and add `ClosingReportService`.
2. Add `DayStandingService`.
3. Close contract changes (§6), with the migration and backup.
4. Fix `reconcileDiscrepancy` (null handling and multi-reclose).
5. Add the locked-day guards for purchases and fixed expenses.
6. Extend `FINANCIAL_FIELDS`, and remove net profit from the broadcast.
7. Payment correction (migration).
8. Fix correction approval to be transactional and branch-scoped.
9. Record the product decisions in `docs/21_PRODUCT_DECISIONS.md`: the inactive standing, closing when not verified, and the report definitions.

### Mobile changes
1. **New "Review and close" screen** (registered in the registry, or excluded with a reason, `registry.ts:289, 327-328`):
   - renders the server report sections and warnings, with no client sums;
   - the physical check is optional per channel;
   - "Close without physical check" requires a reason and an explicit acknowledgement;
   - the confirm step sends `date`, `clientUuid` and `reportVersion`;
   - the close response is shown, not discarded (`lib/closing.ts:151-152`).
2. **`count.tsx`:**
   - pin the displayed date on count and close (`count.tsx:105-106, 178`);
   - read `row.stale` and allow a recount or unskip, which fixes the dead end;
   - allow correcting a saved count;
   - change the account prompt to "Today's net movement shown by {label}";
   - drop the phone-side totals (`count.tsx:139-146`);
   - gate loan reminders on `loan.view`;
   - implement or remove the `closing.counts` draft policy (`policy.ts:193`).
3. **`closing/index.tsx`:**
   - history rows show "not verified" instead of `Number(null ?? 0)` (`:318-345`);
   - add the `inactive` standing;
   - past days show the read-only snapshot report.
4. **Home:** add the tone for `inactive`.
5. **"Correct a transaction":** the sources list, linking to existing flows and the new payment-correction sheet.
6. **i18n and tests:**
   - en/fr/ar parity;
   - update `closing-screen.test.ts` in the same change, because it pins `count.tsx`'s source text (`:15-110`);
   - add `home-day` tests for `inactive`;
   - add pure tests for report formatting.

### Risks
- **Migrations on a shared database.** Two changes: nullable counts, and the payment-correction columns with `corrections_out`. They need a verified backup and a handoff record (`docs/22_BACKUP_AND_ROLLBACK.md`; CLAUDE.md database rules).
- **Live views of history will shift.** Changing the `openingCash` anchor rule changes live views of historical days. Snapshots stay as they are.
- **Visible disagreement between screens.** Report figures (`sales.total` basis, adjustments added back) will differ from the digest, the notification, Results and `total_sales`. Either label each figure, or fix the rollup basis (allocate saleDiscount to lines) in a separate, approved change.
- **Lock contention.** `FOR UPDATE` on the closing row inside `autoReopenTx` serialises sales against a close. It needs a concurrency test.
- **Payload size.** A full report JSON goes into every closed/reclosed event.
- **Backward compatibility.** Old app versions post `POST /closings` without `date` or `clientUuid`. The server must keep today's behaviour for them, and never apply the "not verified" path implicitly.
- **Opening chains before 0076** may anchor on counts taken with no opening float (`docs/50_AUDIT_HOME_BUSINESS_DAY_CLOSING.md:38, 50-53`). This cannot be verified from code.
- **Shared receiving accounts across branches** keep their meaning problem.
- **Negative expected figures** conflict with `counted ≥ 0` (`record-count.dto.ts:37-42`). Relaxing it for account movement is a DTO change.
- **Changing the approved decision** (`docs/21:5754, 5772`) needs the user's explicit approval.
- **Scope.** The report does not include consignment revenue, loans or debt cash. The known-limits notice must say so.

---

## 11. Open questions the code cannot answer

| Question | Safest default |
|---|---|
| Should counters without `report.view` or `closing.perform` see sales value and expenses? | No. Show them only the money movement and expected balances they already see in `openView` |
| Should the day result include fixed expenses? | Show both "before fixed costs" and "after expenses recorded to this date" (§5) |
| Who may close without a physical check, and on a reclose too? | `closing.perform` holders, with a mandatory reason, on a first close and a reclose, for the current business day only |
| Does a close that was not verified anchor the next opening? | No. Carry its expected movement forward |
| Sales value basis: `sales.total` or rollup revenue? | `sales.total`, with a warning showing the saleDiscount difference |
| Does "collected for today's sales" include same-day later collections? | Yes, with an "at checkout" sub-line |
| Items sold: IMEI only, or all quantities? | Σ quantity across all tracking types, labelled "items" |
| Pending refund reports on D? | A warning only; never movement |
| Loan, consignment or debt cash handled at the drawer? | Excluded, with a known-limits notice. Do not date them (they use UTC `entry_date`) |
| What does an account "count" mean? | Today's net movement, not the balance. Default: not verified unless counted |
| Can past "Needs review" days be closed from mobile? | No (`docs/21:5754`). They stay read-only, with the snapshot and the sources list |
| Payment corrections: approve on a locked current day, or auto-reopen? | Refuse with 409, consistent with `correction-rules.ts:107-116` |
| Is a zero cost ever legitimate (a free gift)? | Treat cost ≤ 0.005 as missing; the result is "Cannot calculate yet" |
| Hide the whole result when some lines lack cost, or show a partial one? | Hide the whole result, with a reason and count |
| Does `day_started_early` make the new day active? | Yes, for the date it is stored under |
| Should `employee_debt` and consignment exclusions become design decisions? | Record them as open in `docs/21`; the report shows the exclusion |
| Should the digest's hard-deleted lines be preserved? | Keep the full report in the event payload; stop hard-deleting in a later change |

---

## 12. Completeness pass (done inline; the workflow's critic stage failed on a session limit)

Re-read against the code before any edit. Each item changes the contract above.

1. **The timeline leaks the close's figures.** `timeline()` returns every event's `payload` as stored (`closing.service.ts:1225`) to anyone holding `closing.count`. The closed/reclosed payload carries `netProfit` and `totalSales`, and would carry the full report once §6 stores it. `netProfit` is stripped only for callers without `cost.view` (`financial-fields.ts:19-20`), and every store role holds `cost.view`. **Fix:** the timeline returns a per-kind whitelist of payload fields; the stored report is never returned through it.
2. **The close broadcast carries revenue and net profit to every user** (`closing.service.ts:485-491`; `notifications.service.ts:39`, `targetUserId: null`). **Fix:** the body names the day and branch only; the report is one tap away and gated.
3. **A payment reclassification would be miscounted by two existing readers.** `channelMovements`' `correctionsIn` arm and the rollup's `corrections_*` sums read every approved correction (`closing.service.ts:1621`; `rollup.service.ts:259`). A new target kind must be filtered out of both, or a reclassification would be counted as money coming back, into the unattributed bucket.
4. **Account counts cannot be negative** (`record-count.dto.ts:37-42`), but an account's expected movement can be. With the account prompt changed to "net movement", a negative count must be allowed for accounts; cash stays ≥ 0.
5. **Closing authority by role.** Live `role_permissions` gives `closing.perform` to `administrator` and `branch_manager` as well as `owner`; no live user holds either role (read 2026-09-24). Revoking both makes "the Owner and at most two delegates" literally true with no effect on any person.
6. **The race between a sale and a close is real and not only theoretical.** `autoReopenTx` reads the closing row without a lock (`closing.service.ts:739-743`), and `close()` reads every figure before its transaction (`:189-293`). A sale committed in that window lands in a day that then locks without it. **Fix:** both lock the same closing row (`SELECT … FOR UPDATE`); the close makes sure the row exists first, then re-reads a movement fingerprint inside its transaction and answers `409 report_changed` if anything moved.

No material gap found in: branch/company isolation of the §3 queries (every one filters `company_id` and the branch through `sales.branch_id`, `purchases.branch_id` or its own `branch_id`); early-started days (the stored `business_date` already carries the election); payments on reversed sales (no writer sets `is_reversed`, and every query still filters it).

---

## 13. Decisions taken for this implementation (the brief of 2026-09-24 is the authorisation)

| # | Decision | Supersedes |
|---|---|---|
| D1 | **The report is built on the server** (`GET /v1/closings/report?date=`), from stored records only, with the §3 formulas and the §10 invariants asserted on every read. The phone sums nothing. | The count screen's phone-side totals |
| D2 | **Physical checks are optional.** A close needs no count. A channel with no fresh count is recorded as **not verified** (`is_skipped=1`, `skip_reason='NOT_VERIFIED_AT_CLOSE'`, `counted=NULL`), never as counted, matched or zero. Closing with any channel not verified requires an **explicit acknowledgement and a reason**, stored in the closed/reclosed event. A real count stays a count, with its difference and its discrepancy. | Milestone E "every channel must be counted or skipped"; 0076 "a reclose needs a fresh count of every channel" |
| D3 | **Migration 0078**: `daily_closings.counted_cash` and `difference` become NULL-able together (a CHECK ties them); `closing_channel_counts.corrections_out`; `financial_corrections` gains the `sale_payment` target with its "to" channel; `closing.perform` revoked from `administrator` and `branch_manager`. Backup and restore-proof first. | — |
| D4 | **The opening drawer anchors only on a verified cash count.** A locked day whose cash was not verified is carried forward by its recorded movement. The report shows the anchor date and whether it was verified. | 0076 "the last locked close's counted cash" |
| D5 | **A close is idempotent** by `clientUuid` (replayed from the event), and bound to what the confirmer saw by `reportVersion` (`409 report_changed` with the fresh report). The sale path and the close lock the same row. Every closed/reclosed event stores the whole report; earlier snapshots are never rewritten. | — |
| D6 | **Sections are gated in the service.** Money and expected balances: `closing.count`. Sales and expenses: `report.view` or `closing.perform`. Result (cost, gross profit, result after expenses): additionally `cost.view`. The new keys are added to the interceptor list as a second defence. | — |
| D7 | **Result scope.** Gross profit = sales value − approved returns' net refund − (recorded cost of units sold − cost credited back by returns). Result after expenses = gross profit − expenses recorded to the date, with fixed costs counted in full on their due date (Milestone D). Any sold line or return with no recorded cost (cost ≤ 0.005) makes the whole result "Cannot calculate yet", with the count; never zero. Not called "net profit". | — |
| D8 | **An inactive past day** (no closing row, no closing event, no sale, no payment, no confirmed refund, supplier payment, expense or correction, no return approval) reads **"No activity recorded"**, not "Needs review". A past day with real unclosed activity still reads "Needs review". Computed once, live. | `docs/21` 2026-09-24 "a past date with no closing row reads Needs review" |
| D9 | **Correct a transaction**: a list of the date's source records, each linked to its existing flow or refused by name. One new narrow contract: **reclassify a checkout or later payment to another channel** (all or part of its amount), through the existing correction request → approval (reason, preview, Owner approval, one approved correction per payment, the movement posted to the current open day, the original payment and every snapshot untouched). Reversing a payment that was never received, editing a sale and correcting a confirmed expense or a purchase payment are refused with the reason and remain owed. | — |
| D10 | **Late money on a locked day.** A purchase paid on a locked current day reopens it, as a sale does. Confirming a fixed expense due on a locked day is refused, as a variable one already is. | — |
| D11 | **The broadcast and the timeline carry no figures** beyond what `closing.count` already shows (§12.1–2). | — |

Out of scope and recorded as owed: reversing a payment that was never received; correcting a confirmed expense or a purchase payment; editing a sale; loans, consignment and employee-debt cash in the drawer; the whole-sale discount missing from rollup revenue (the report reads `sales.total` and is internally consistent; the digest and Results keep their basis).

---

## 14. Status (2026-09-24, close of the session)

D1–D11 are implemented and verified: backend `42bfd76`, `ff531dd`, `e352cf3`, `f4c3381`; mobile `8346398`, `7ed67bc`, `1e316e9`; migration 0078 applied to live at `2026-09-24T08:24:43Z` after a restore-proved backup. The formulas as built, the lifecycle (45/45) and the render checks are recorded in `docs/21`, "The Daily closing report, closing without a physical check, and 'Correct a transaction' (2026-09-24)". The out-of-scope list above is unchanged and remains owed. Not yet verified on a handset: `docs/24` §38 R1–R14.

---

## 15. Follow-up of 2026-09-25: delegation check and the full correction path

The user's follow-up: verify that the Owner can delegate closing to at most two employees who can then close and reclose, while other employees cannot; and complete the correction path for erroneous **sales, payments, expenses and purchases** as authorised reversals or adjustments, with a required reason and a permanent audit history, never overwriting a confirmed record or an earlier closing snapshot. Any action that cannot be completed safely is to be named with its reason.

### 15.1 Delegation (verified, unchanged)

0078 removed `closing.perform` from two **roles** (`administrator`, the retired `branch_manager`). Per-branch delegation (0076) was untouched: `user_branch_permissions` grants `closing.perform` to a `store_manager` or `store_employee` assignment, at most two per branch, and `AccessService` honours it for that branch only. Proved on a real database (`delegation-lifecycle.mjs`, 24/24): the Owner names an employee and a manager; a third and a fourth are refused; the delegates' effective permissions, the report's close verdict and the server route agree; the employee delegate closes, the manager delegate recloses after a later sale, the employee reopens and recloses; the other employees are refused the close, the reclose and the reopen; the delegation holds at its own branch only; a delegate can neither name another delegate nor approve a correction; a withdrawn delegate is refused again and the freed place can be given to another employee; every naming and withdrawal is audited. The wording "Owner-only" in the 0078 record was about roles and is corrected: closing authority is **the Owner plus at most two people the Owner names per branch**.

### 15.2 What each correction does (decisions D12–D20)

Every correction is a `financial_corrections` row: requested with a mandatory reason (`financial.correction.request`), previewed by the server with nothing written, approved by the Owner (`financial.correction.approve`) in one transaction that locks the target and the current day's closing row, posted to the **current open business day** of the target's branch (refused `409 day_already_closed` while that day is closed), idempotent by `clientUuid`, one approved correction per target (a generated unique key), append-only, audited at request and at approval with before/after. The corrected record is never edited; its own day, its rollup and every closing snapshot stay as they were.

| # | Erroneous record | Correction | What moves, on the correction day |
|---|---|---|---|
| D12 | Money moved by any correction | **One ledger of legs** (`financial_correction_legs`): direction, channel, account, amount, and the payment, purchase payment or expense it came from | Each leg is a `correctionsIn` or `correctionsOut` of its channel. The 0078 reclassification is re-expressed as two legs (backfilled); refund-payout and settlement corrections keep their arms |
| D13 | A sale payment recorded but **never received** (all or part) | `sale_payment` · `reverse` | An out leg from the channel the money is in; the debt comes back to the sale's customer or partner store (`amount_paid` down, `balance_due` up, the pay status, the customer's balance cache). Refused for a sale with no debtor: cancel the sale instead |
| D14 | A **sale** that should not exist as recorded (wrong item, wrong price, duplicate, test) | `sale` · `cancel`, the whole sale | Its value and recorded cost come off the correction day's sales and result (`sales.cancellations`, rollup `cancelled_*`); every phone goes back to stock (`sold` to `in_stock`, the line released from sold-once by `sale_items.released_by_correction_id`); quantity lines go back to their stock; the money still held against it leaves the channels it is in (given back or never received) as out legs; its balance is cleared. The right sale is then recorded again. Refused: a sale with a return claim or approval, a pending correction on it or its payments, a phone no longer `sold` |
| D15 | A confirmed **expense** that was wrong (all or part) | `expense` · `reverse` | An in leg back to the expense's channel; the correction day's expenses fall by the amount (`expenses.reversed`; rollup `expense_reversals`, and rollup `expenses` becomes net) |
| D16 | A **purchase payment** recorded in the wrong channel (all or part) | `supplier_payment` · `reclassify` | An out leg from the recorded channel and an in leg to the real one; nothing else changes |
| D17 | A **purchase** that should not exist as recorded (goods not received, wrong cost, wrong product, wrong quantity) | `purchase` · `cancel`, the whole purchase | Its phones leave stock as `voided` (they never entered the books); quantity lines leave their stock at the purchase's cost (the branch average re-computed); the money paid comes back to its channel as in legs. The right purchase is then recorded again: receiving an IMEI that belongs to a voided phone of the company **reactivates that record** instead of creating a second one, so IMEI uniqueness is enforced exactly as before. Refused: any phone no longer `in_stock` at the purchase's branch, fewer items in stock than were bought, a quantity cost that would fall below zero |
| D18 | Readers of "what exists now" | Cancelled sales leave the partner ranking, goal progress and velocity; their return and payment flows refuse them; the sale shows "Cancelled" with who, when and why. Voided phones are in no stock, value or sale. Historical day figures keep them, with the reversal on its own day |
| D19 | Readers of profit | The report's result, rollup `net_profit` and Results subtract cancelled revenue and cost and reversed expenses on the correction day; returns keep their own line |
| D20 | "Correct a transaction" | Lists the day's sales, payments, refunds, expenses, purchases and corrections with every action that applies or a refusal by name, and the requests waiting for the Owner (approve or reject in place) |

### 15.3 Formulas added to the report (§3)

```
Sales     cancellations         = Σ sale.total of sales cancelled on D (any sale date)
          net sales             = value − returns.net_refund_due − cancellations.value
          collected (D's sales) = Σ payments on D's sales dated ≤ D + Σ legs of those payments posted ≤ D (in − out)
          owed (D's sales)      = value − collected − value of D's sales cancelled on D
Result    cost of items sold    = Σ D's sales.total_cost − Σ return line_cost(D) − Σ cancelled sales' recorded cost(D)
          missing cost          also counts the cancelled sales' lines
Expenses  recorded              = Σ confirmed lines (as before);  reversed = Σ expense reversals posted on D
          total                 = recorded − reversed;  result after expenses = gross profit − total
Money     corrections in / out  = Σ legs of corrections approved on D, per channel
```

### 15.4 Schema (migration 0079, after a restore-proved backup)

- `financial_corrections`: `target_kind` gains `sale`, `expense`, `supplier_payment`, `purchase`; `action` (`reverse`, `reclassify`, `cancel`); `target_sale_id`, `target_expense_id`, `target_supplier_payment_id`, `target_purchase_id` with foreign keys and approved-only unique keys; `method` NULL-able for a sale or purchase cancellation (its legs carry the channels); CHECKs for one target per kind, the allowed actions and the destination of a reclassification.
- `financial_correction_legs` (new, append-only by trigger).
- `sale_items.released_by_correction_id`; `active_unit_id` = `IF(voided = 0 AND released_by_correction_id IS NULL, unit_id, NULL)`.
- `units.status` gains `voided`.
- `daily_rollups` gains `cancelled_revenue`, `cancelled_cogs`, `cancelled_count`, `expense_reversals`.

### 15.5 Risks and what stays unavailable

- **Sold-once and IMEI uniqueness (sacred).** Sold-once changes only for a line released by an approved cancellation. IMEI uniqueness does not change at all: a voided phone is reactivated, never duplicated. Both are covered by specs and by the real-database lifecycle.
- **Double counting.** An expense reversal reaches expected cash only through its leg (the rollup's cash column stays gross); a cancellation's money only through its legs; a reclassification nets to zero on the sale. Every report invariant is extended and asserted on every read.
- **Races.** Approval re-checks eligibility inside the transaction after locking the target rows and the day's closing row; a return, a sale or a transfer landing first makes the approval refuse with its reason.
- **Unavailable, by name:** reversing a purchase payment as "not paid" (purchases are paid in full by rule and there is no supplier debt to carry it; cancel the purchase instead); editing a sale line in place (cancel and sell again); cancelling part of a sale; a sale with a return (correct it on the return); a purchase whose goods have moved (correct the later record first).

### 15.6 Status (2026-09-25, close of the session)

Implemented and verified on a real database: backend `2b7ba08`, `2c98658`, `b091286`; mobile `a9b9226`, `9130a9c`; migration 0079 applied to live at `2026-09-25T05:23:45Z` after a restore-proved backup. Delegation 24/24, corrections 40/40, the 0078 report lifecycle 45/45, backend 153 suites / 2 758 tests, mobile 70 pure suites, 63 web render views with 0 problems. Two further limits found while verifying and recorded in `docs/21`: a branch's units-sold goal still counts a cancelled sale's items, and Home's period figures count a sale on its own day. Physical device checks: `docs/24` §39 K1–K14, not run.
