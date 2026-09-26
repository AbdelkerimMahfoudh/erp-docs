# 54 — Home, completed: a whole-invoice discount, store time, and the connected reporting checks

> The user's brief of 2026-09-25 (Home, its direct links and the reporting consistency just completed; no workflow, no
> pictures; the three-day repair not rerun): a whole-invoice discount agreeing on Home, its chart, the Daily closing,
> Results, Money, Analytics and goals, fixed on the recorded invoice total; Home's latest-phone labels in the store's
> timezone; Home's sales block for a day holding only a cancellation or return; Home's links, refresh, permissions and
> narrow layout in EN/FR/AR; the revenue goal's label; Analytics' movement labels after cancellations; the units-sold
> goal = sale units − units on whole-sale cancellations − approved returned units, each on its approval date.
>
> Added during the work: Expo Go crashed on Home (`figures.returns.count` of undefined) — the phone was reaching the
> user's API on 3010, still the build from before docs/53. The API was rebuilt and restarted, and a reply missing a
> figure now shows an error instead of crashing or showing zero.

## 1. What was wrong (audit, before any change)

| # | Finding | Where |
|---|---|---|
| A1 | **A whole-invoice discount** — the only discount the Sell tab sends (`saleDiscount`) — was counted by the invoice readers (Home, its chart, Money, the Daily closing, the sellers) and dropped by every per-line reader: the rollup (Results, branch goals, branches, the snapshot), the product and category report, personal goals and the closing digest valued a line at price × quantity − its own discount. A sale of 10 040 with 1 000 off read **9 040** on Home and **10 040** in Results | `rollup.service`, `period-figures.productAdjustments`, `goals.service`, `closing.service` digest |
| A2 | **A return from a discounted invoice refunded more than was paid**: the gross refund was the line's price less its own discount — 10 000 back for a phone paid 9 500. The documented rule (`docs/27`: the refund uses the rollup's revenue expression, so a return cancels what its sale earned) was kept; its formula carried the same gap as A1 | `return-workflow.grossRefundOf`, `returns.service` (4 sites) |
| A3 | **The units-sold goal** did not take returned units off (by `docs/53` R6) | `goal-progress.ADJUSTMENT`, `goals.service` |
| A4 | **Home's latest phones** were labelled by the phone's clock and zone (`isToday`, `formatTime`); **every bare date** (`YYYY-MM-DD`) was read as UTC midnight and shown in the phone's zone — a phone west of UTC showed Home's range, the Daily closing and its history, the closing sheets, expenses and corrections one day early | `app/(tabs)/index.tsx`, `lib/format.ts`, 9 call sites |
| A5 | **Home's sales block**: net sales was sent (`netSalesValue`) and never shown; nothing said the chart plots sales as invoiced; "Collected" did not say it includes payments on older sales; the error notice read "This month's figures did not load" on Today and 7 days | `app/(tabs)/index.tsx` |
| A6 | **Pull-to-refresh** called `refetch()` on queries disabled for lack of permission — TanStack Query runs a disabled query on `refetch()`, so a seller without `transfer.view`/`return.view` asked for both and was refused | `app/(tabs)/index.tsx` |
| A7 | **Analytics' movement labels** ("sold in 30 days", "last sold", "not moving") came from a snapshot rebuilt on stock events, over 30 days counted back from the last rebuild: after a quiet week sales older than 30 days stayed in the count, and a company-wide read took one branch's row. A cancelled sale was already left out (its lines are released) | `rollup.recomputeVelocity`, readers in `analytics`, `dashboard`, `health` |
| A8 | **The revenue goal** was called "Money taken" (FR "Argent encaissé", AR "المبالغ المحصّلة") — cash words — while it measures net sales | `lib/i18n` |
| A9 | **A server one version behind** crashed Home (`figures.returns.count` of undefined) and would have shown a missing amount as 0 on Money | `lib/home.ts`, `lib/money-overview.ts` |
| A10 | **At 320 points**: French "Réceptionner" needed 90 of the 71 points a half-width counter button leaves; in Arabic, the tracking chip and the value left a product's name 54 points in Analytics | measured on the page (§5.3) |

## 2. Decisions (D36–D41)

| # | Decision |
|---|---|
| **D36** | **A line is worth its share of the recorded invoice total** (`src/sales/sale-shares.ts`): share = line net × `sales.total` ÷ Σ line nets, in whole cents, half-up, the rounding cent on the largest line (the first created on a tie) — so a sale's shares add up to `sales.total` exactly. Without a whole-invoice discount a share is the line's own net, unchanged. The rollup's revenue, product facts and a cancellation's revenue, the product report's cancelled lines, **a return's gross refund** and the closing digest use it; personal goals read the sale's total and cost. The `docs/27` principle — a refund uses the value the rollup gave the line as revenue — stands; its formula is superseded. |
| **D37** | **The units-sold goal** = units on sales − units on whole-sale cancellations − units returned, each subtraction on its approval date (branch: `qty_sold − (cancelled_qty + returns_count)`; personal: one unit per return of the seller's sales). A return is one identified unit (a return needs a unit line; unit lines are quantity 1), so `returns_count` is the units returned — **no migration**. The **sales count is unchanged**: a returned item is not a cancelled invoice. **No conflict with a binding decision**: the original goals decision (`docs/21` §7) already says "returns reduce progress"; it supersedes `docs/53` R6 for this goal only — Money's "Items sold" and Analytics' units sold keep returned units apart, as their captions say. |
| **D38** | **A reply missing a figure is refused whole** (`lib/contract.ts`): Home, Money's overview and sales by day name every figure they read; if one is absent or not a number the screen says "This screen needs an updated server", shows no figure — never a zero — and does not retry. `null` figures (a person without `report.view`) stay valid: hidden, not missing. |
| **D39** | **Movement is read from the sales that stand, when asked** (`src/analytics/movement.ts`): sold in 30 days = units on sales of the last 30 dates (business dates, today included); last sold = the latest such sale; not moving = in stock with no such sale for `dead_stock_days`. A **cancelled** sale is left out wherever it falls — its goods never left, so it is not movement (unlike the accounting figures, which keep it on its sale date and take it off on its approval date). A **returned** item still counts as sold. The snapshot writer (`recomputeVelocity`) is gone; the `product_velocity` table is no longer read or written (drop it in a later migration). Analytics states the rule under "Not moving". |
| **D40** | **Home speaks the store's time**: each arrival carries `receivedLocalDate`/`receivedLocalTime` read in the store's timezone and Home carries `businessDay.localDate`; "Today"/"Yesterday" compare those, never the phone's clock. **A bare date is a calendar day** on every phone (`lib/format.ts` `toDate`, `calendarDate`). |
| **D41** | **Home's sales block**: when a cancellation or return falls in the period, **Net sales** (the Daily closing's) is shown under the gross value and its adjustment lines — below zero on a day holding only an adjustment; the chart says it plots **sales as invoiced, each on its own day, before cancellations and returns**; Collected says **"Received in this period, older debts included"**. Refresh asks only for what the person may read. Below ~360 points the counter buttons stack. **The revenue goal is named Net sales** (EN/FR/AR, the same words Money uses). |

## 3. What changed (backend `3c3f629`…`9a1155a`, mobile `9969e2d`…`056bb6e`; no migration)

**Contract.** `GET /v1/home`: `businessDay.localDate`; `arrivals[].receivedLocalDate`, `arrivals[].receivedLocalTime`.
`GET /v1/dashboard`: `deadStockDays`. Revenue-type figures of Results, branch goals, branches, the snapshot, the
product and category reports and personal goals now include a whole-invoice discount; a return's `grossRefund` (and so
`netRefundDue`) is the returned line's share of the invoice. `sold30d`/`lastSoldAt` are read live. The units-sold
goal's `achieved` subtracts returned units. Nothing else changed shape.

**The app.** Home: net sales line, chart and Collected captions, store-time arrivals, the incompatible-server notice,
permission-bound refresh, stacking counter buttons. Money and the period screen: the incompatible-server notice. Goals:
"Net sales", and the units rule naming returns. Analytics: the "Not moving" rule, the tracking type under the product
name. Every screen: bare dates read as calendar days.

## 4. The phone crash, and the API on 3010

- **Cause:** Expo Go loaded the working tree from Metro (8081) — the docs/53 app, which reads `figures.returns` — and
  called `http://192.168.100.3:3010`, the user's API, still running `backend/dist` built at 07:45Z from `68c21e9`
  (before docs/53), whose Home has no `returns`.
- **09:23Z:** the user's `npm run start` chain (pid 23560 → `nest start` → `node dist/src/main`, pid 16444) stopped by
  PID, `backend/dist` rebuilt from the clean `5acab28`, the API restarted detached on 0.0.0.0:3010 (pid 6480, log in OS
  temp); reachable on the LAN address; no error; `rollup_requests` unchanged.
- **After this phase's commits:** stopped by PID again, `backend/dist` rebuilt from `9a1155a`, restarted detached (pid
  6796) — the build the app's contract check accepts (§5.2 H6).
- **The PC shut down** while this document was being written (2026-09-25, after the commits; the docs edits survived
  whole). On 2026-09-26 at 00:26Z: the WAMP MySQL service could not be started from the non-elevated shell, so MySQL
  was started as a detached process with the service's own configuration section (`sql_mode` empty,
  `utf8mb4_unicode_ci`, no binary log; no startup error; live unchanged — 0081, 11 sales, 8 rollup requests done);
  the API restarted from the same `9a1155a` build (pid 14576); Metro restarted with `expo start --clear` (pid 7632).
  The phone had not reached the final build before the shutdown, so **Home opening on the phone is not yet seen**.
- **Live data:** nothing written by this work. The user sold twice on live during the phase (invoices 00003 and 00004,
  2026-09-25, no discount), which the running API rolled up; with no discount the new basis gives the same figures.

## 5. Verification (2026-09-25)

### 5.1 Scenarios on an isolated copy, expected = actual, with what the build before this phase answered

`prisma_verify_home` restored from `phonestore-after-rollup-repair-20260925-075339.sql`, migrations deployed, the store's
timezone set to **Asia/Dubai (UTC+4) on the copy only**, throwaway credentials; the API built into OS temp, fake clock.
`home-lifecycle`: **42/42 steps, 37/37 screen checks expected = actual.** The same acts through the build deployed before
this phase (`5acab28`, `BUILD=old`) recorded the "before" column. A phone 10 000 at cost 6 000; a cable 20 at cost 5.

| Scenario | Screen | Expected = actual (after) | Before |
|---|---|---|---|
| **H1 whole-invoice discount** — phone + 2 cables, 1 000 off: **9 040** | Home Today (value = chart = net) · Money · sales by day · Daily closing | 9 040 · 3 items · 1 sale · gross profit 3 030 | the same |
| | Results | sales 9 040 · net 9 040 · profit 3 030 | **10 040 · 10 040 · 4 030** |
| | Analytics products | iPhone 9 003.98 / profit 3 003.98 · cable 36.02 / 26.02 (sum 9 040) | **10 000 / 4 000 · 40 / 30** |
| | the seller · the branch | 9 040 / 3 030 · 9 040 / 3 030 | 9 040 / 3 030 · **10 040 / 4 030** |
| | Goals branch · personal | 9 040 · 3 030 · 1 sale · 3 units | **10 040 · 4 030** |
| **H2 return from a discounted invoice, later day** — 2 phones, 1 000 off (19 000); one returned the next day; refund the day after | refund offered and approved | **9 500** (its share) | **10 000** |
| | Home, the return day (a day holding only it) | value 0 · chart 0 · returns 9 500 · **net −9 500** | −10 000 |
| | Daily closing · Results, return day | −9 500 · profit −3 500 | −10 000 · −4 000 |
| | Results, both days · Analytics iPhone both days | net 9 500 · profit 3 500 · 2 sold, 1 returned | 10 000 · 4 000 |
| | Goals branch = personal: sale day · return day · both | 19 000/7 000/1/**2** · −9 500/−3 500/0/**−1** · 9 500/3 500/1/**1** | 20 000/8 000/1/2 · −10 000/−4 000/0/**0** · 10 000/4 000/1/**2** |
| | refund day | 9 500 out of the drawer; money only | 10 000 |
| **H3 return the same day** — 2 phones, 1 returned | Goals branch · personal | 10 000 · 4 000 · **1 sale · 1 unit** | 1 sale · **2 units** |
| | Home · Money | net 10 000; Items sold 2 with the return apart (R6) | the same |
| **H4 discounted sale cancelled next day** | Home, the cancellation day | value 0 · cancelled 9 040 · **net −9 040** · −1 sale | the same |
| | Results, cancellation day | cancelled **9 040** · profit −3 030 | **10 040 · −4 030** |
| | Analytics, cancellation day | iPhone −9 003.98 · cable −36.02 | −10 000 · −40 |
| | Goals, cancellation day · both | −9 040/−3 030/−1/−3 · 0 | **−10 040/−4 030** · 0 |
| **H5 movement** — sold 20 Jan and 8 Feb; one sold and cancelled 9 Feb | 9 Feb: sold in 30 days · last sold · not moving | 2 (the cancelled sale left out) · 8 Feb 09:00 · the cable (last sale that stands 12 Oct; its January sale was cancelled) | the same (days not sent) |
| | 5 March, nothing since | **1** — 20 January has left the 30 days | **2** (the snapshot's window ended 9 Feb) |
| **H6 store time** — 3 phones received 21:30 UTC = **01:30 in the store** | Home on the 13th (store 11:00) | store date 2027-04-13; "Today · 01:30" ×3 (UTC said 12 Apr 21:30) | the app refuses this Home: `businessDay.localDate`, `arrivals.*.receivedLocal*` missing |
| | the next day | "Yesterday · 01:30" ×3 | — |
| **H7 Collected** — 10 000 sold, 6 000 paid; 4 000 collected next day | Home Today, sale day · next day · 7 days | 6 000 in, 4 000 owed · **no sale, 4 000 collected** (older debt) · 10 000 / 10 000 / 0 | — |

### 5.2 Links and permissions (H6, through the API)

- **Ranking link**: Home's top partner shown with `consignment.view`; `partners/ranking` 200 for the owner.
- **Latest phones → Stock**: Home's three are the Stock list's first three (`inventory?trackingType=imei`), masked to
  their last four on Home only; the full identifiers never travel in Home's reply.
- **Closing card → Closing & history**: the card's date and standing equal `closings/business-day`'s.
- **A store employee** (no `report.view`): figures and series `null` — hidden, never zero; ranking and closing card by
  their own permissions. **A warehouse employee** (on the copy): no money, no ranking (403), no closing card, no report
  (403); the latest phones and Stock open. **Every Home reply of the new build passes the app's check.**

### 5.3 Rendered and read, no pictures (web export, headless Chrome, the page's own text and boxes)

**35 views**: Home Today in EN/FR/AR × light/dark × 320/393 pt, 130 % text, 7 days at 320 pt; the ranking, Stock and
closing links; a warehouse employee's Home; Analytics and Goals at 320 pt; and **a server one version behind** (Home's
reply stripped of `figures.returns` in flight) in EN/FR/AR. The targeted view shows Sales cancelled (1) −9 040, Net
sales, the chart and Collected captions, 4 000 collected and "Today · 01:30". The older-server views show "This screen
needs an updated server" and no sales figure — the crash replaced by a notice. **30 views without a problem; 5 with one**:
the French tab label "Partenaires" is 2 points too wide at 320 pt (see §6). Fixed on the way: "Réceptionner" cut in its
button (the buttons now stack below ~360 pt) and Arabic product names squeezed to 54 points in Analytics.

### 5.4 Regression and gates

- On the new build, each on a fresh copy: docs/53 lifecycle **59/59** (53/53 screens, its units goals updated to D37:
  S3 approval day −1, three days 1; S4 0), Daily closing **45/45**, corrections **40/40**, cancellation **31/31**
  (106/106 figures).
- **Backend:** tsc · **158 suites / 2 825 tests** (new `sale-shares.spec` 9, `home-completion.spec` 9).
- **Mobile:** tsc · **73 pure suites** (new `contract.test` 8, `store-time.test` 5 — run as phones in UTC, New York,
  Tokyo, Kiritimati and Pago Pago) · parity **3 187** · `expo lint` 0 errors (33 pre-existing warnings).
- **Database:** no migration, no backup needed; live written by nothing of this work. The copy was dropped.

## 6. Not changed, and still owed

- **French tab label at 320 pt**: "Partenaires" needs 56 of 54 points on the web's font. The 5-point inset is the
  navigator's own button style; changing it means replacing the tab button app-wide, so it is left for the phone check
  (device fonts differ) — `docs/24` §42 N9.
- **`product_velocity`** is no longer read or written; drop it in a later migration.
- **The product detail's "Last sold"** (Catalogue, not Analytics) finds quantity lines only, so a phone never shows one —
  found, outside this scope.
- `closingHistory.title` is no longer used by any screen (the Daily closing screen carries the history).
- The exports keep their headers ("Sold in 30 days", "Last sold"); the rule is stated in the app.
- **Physical phone: not run** — `docs/24` §42.
