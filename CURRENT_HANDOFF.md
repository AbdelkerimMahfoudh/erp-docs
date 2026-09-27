# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Owner: **CLAUDE-A**
- `started_at_utc: 2026-09-27T08:26Z` — takeover HEADs (all clean, level with their remotes): docs `e1ee11b` · backend
  `56c3649` · mobile `c577d53`; `prisma migrate status` on live: 80 migrations, up to date. Set before any edit.
  Previous session: CLAUDE-A, 05:50Z–08:00Z, handed off complete (`READY_FOR_HANDOFF`).
- **Active phase and scope (the user's follow-up brief of 2026-09-27, 08:2xZ):** (1) Today as the starting period on
  every screen with Today / 7 days / This month — on launch, on a fresh visit and after leaving and returning; kept
  while the person stays, through refreshes; the boutique's business day for figures, Home's header the calendar date,
  the before-06:00 boundary checked; history and detail dates untouched. (2) Daily closing **Sales details ›  (?)**:
  a light-violet, clearly tappable control, the chevron after the words turning down as the rows slide out from under
  it, the (?) at the far end, amounts in the right-hand column, Reduce Motion / large text / RTL. (3) **Closing
  history**'s header visibly titled, the count as "4 events", full purple with the prominence of *Close the business
  day*, the chevron on the right open or closed (Arabic too), the same turn-and-slide; empty history and an event
  arriving while open tested. (4) **Money's top card as tracked money held** across Cash and the configured accounts,
  each method beneath, the total their sum, carried across midnight (3 400 + 3 600 = 7 000 still in the morning);
  today's in/out kept separate; each method's anchor audited — unknown shown as unknown with the missing anchor, never
  a fabricated zero or total; any ledger/opening-position contract built and tested on a copy first, backup and
  migration per `docs/22`. (5) **The closed-store rule on the server** for Sell and Receive: a clear closed-store error
  to any client, never a silent reopen through a sale; Open store now, its before-06:00 choice, permissions,
  idempotency and historical dates intact; other entry points audited, unrelated accounting untouched. (6) **Partial
  split payments restored**: up to four distinct methods (Cash one of them) may pay part and the rest becomes a
  recorded debt under the debtor rules; each part valid, no duplicates, no overpayment, paid + owed = the sale amount;
  full splits still work; the same rules on the phone and the server.
- **Constraints:** no pictures, scanner or refund work; live business records unchanged; scratch in OS temp only;
  Home, Money and the Daily closing stay *pending the phone review*.
- Next intended action: audit the six areas (period selectors, the Money anchors on a copy, the Sell/Receive entry
  points, the split rules, the two disclosure headers), then implement area by area; verify on a fresh copy of live.
- **Checkpoint 09:05Z:** a fresh verified dump of live, `~/erp-backups/phonestore-now-20260927-082820.sql` (919 KB, ends "Dump completed"), is the base of every copy and the backup for 0082. **Migration `0082_money_anchors` is written (backend, uncommitted) and proven on the copy `prisma_verify_home`** — the table, its two append-only triggers, `money.anchor.record` granted to both Owner roles; the Prisma model matches it (only the usual FK-action drift). **Not applied to live.** The Prisma client was regenerated, which needed the API on 3010 stopped and restarted on the unchanged `56c3649` build (now pid 36640). Implementation runs in two chains (backend: the store-closed refusal, partial splits, tracked money; mobile: the Pressable style fix, the two headers, Today, splits, the refusal, the Money card), uncommitted until reviewed.
- **Live at takeover** (read-only, 08:24Z): 17 sales, 7 expenses, 11 closing events, 3 closing rows (15 Sep
  *counted*, 26 Sep *locked*, 27 Sep *reopened*), 10 purchases, 17 payments — unchanged since 05:32Z.

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Removed in this phase **at the user's request only**: *Sell several items* on Home (still inside Sell), the Daily
closing's *Money owed* card (its server endpoint stays), and the sale's return-policy reason.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`56c3649`** | level | 0 |
| `erp-mobile` | `reports-export` | **`c577d53`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

This pass: backend `c210b61` (`moneyToday` on the overview), `23efe77` (no reason for a return-window change),
`56c3649` (a split: at most four places, each once, equal to the total); mobile `8d080bf` (the payment form: no
reason, the four-place split), `fcbea6a` (Choose from stock), `815d0c0` (Daily closing: one amount column, no Money
owed, the purple history header), `52375c8` (Money's card and Today on each arrival), `c577d53` (Home's order, the day
lock, Open store now, the six guarded routes). Docs: `docs/59` (new), `docs/21`, `docs/04` rules 19 and 25, `docs/24`
§46, the session log, this file.

## What changed

| Where | Now |
|---|---|
| **Home** | Receive, then Sell (Arabic mirrors: Receive on the right); no *Sell several items*. While the current business day is closed: both locked, **Open store now** beneath — the existing reopen, the before-06:00 choice included; who-can-open for anyone without `closing.perform`. Read from `GET /closings/business-day`, again on focus, foreground and pull |
| **Guards** | Quick Sell, Sell, Quick Receive, Receive, the receiving file picker and review show "The store is closed" with Open store now instead of mounting while the day is closed |
| **Money** | "Money recorded today": the server's total = the sum of the rows beneath it, every configured method's in / out / net for the business day, no opening, no drawer estimate; the total on its own line; cents on every figure when any has them; Today on the first visit and after another tab, a choice kept through refetches and Results |
| **Daily closing** | Sales details' amounts in one right-hand column, the chevron beside the title, the (?) on its line; no Money owed card; *Debt settled for this day* kept; Closing history under one purple header, centred title and count, a 28-pt chevron held at the right edge in LTR and RTL |
| **Sale** | no "Why is this sale different?" (form and server); a split in at most four places, each once, equal to the amount due — form and server (`too_many_payment_methods`, `duplicate_payment_destination`, `split_must_equal_total`); a partial payment keeps one method and a named debtor |
| **Choose from stock** | evenly set cards (16 pt margins, 8 pt apart, 64 pt minimum target), spaced lines, the selected card outlined, a steady long list |
| **Shared** | `SegmentedControl` grows to two lines under large text; `MoneyValue` takes `decimals` |
| **Unchanged** | the server's business-date rules, its automatic reopen on a sale or paid receipt, the closing history, discounts and pricing approval, `accountsToday` on the overview |

## Verification

| Kind | Result |
|---|---|
| **Web harness** (a fresh read-only copy of live of 2026-09-27 06:34Z, the new backend on a fixed clock, the web export) | **42 of 42** — Home open/closed EN/FR/AR 320 pt and 320 × 568 × 1.3; the guarded routes; Open store now through the server; the employee's view; the before-06:00 sheet and *Start 28 Sep early*; **Money 3 400 + 2 000 + 1 600 (+ 0 + 0) = 7 000** (server and card, three languages; `cashNow` 3 400 kept out); Today → 7 days kept → Today after another tab, no reload; Sales details 9 amounts within 0 px; the history chevron 16 px from the right, unmoved, EN and AR; no reason field; four parts, the fifth refused, 500 + 200 of 1 000 held; the server's three refusals and three acceptances; a 68-phone longer shelf scrolled and chosen |
| **Found by the checks, fixed** | the Money total cut at large text; the Today reset keyed on a route that never changes for a mounted tab |
| **Gates** | backend `tsc` clean, **160 suites / 2 854 tests**, `nest build`; mobile `tsc` clean, **76 suites / 1 071 cases / 0 failed**, parity **3 191 / 3 191 / 3 191**, `expo lint` 0 errors (31 pre-existing warnings); each mobile commit checked alone from a clean export |
| **Phone** | **Not run** — `docs/24` §46 W1–W14 |

## Data and process safety

- This session wrote nothing to live: read-only queries and one read-only dump
  (`~/erp-backups/phonestore-now-20260927-063419.sql`, outside every repository).
- The copy `prisma_verify_home` was rebuilt per run and **dropped**; 3012, 19012 and 9334 are free.
- **The API on 3010 runs `56c3649`** (pid 34308, `dist` rebuilt, restarted 07:55Z); Metro on 8081 (pid 23768) serves
  the mobile tree at `c577d53`. Scratch tooling in OS temp only; the three trees are clean.

## 🔴 Blockers and pending approvals

- **Awaiting the user's review on the phone** of this phase (`docs/24` §46) and of the Daily closing popup of the
  previous one (§45 as amended).
- **The user's call:** the Arabic Home order (Receive on the right, mirrored, or on the left as in English).
- **Awaiting the user's decision:** counting by a store employee without the closing delegation.
- **Pending the user's decision:** the `spent_on` tidy-up of three expenses (`docs/57` §1.5, `docs/58` §2); the
  "Money in the shop — recorded movement" label and "Debt settled for this day".
- **Deploy order:** the backend before the app. An older app still works against the new server (it keeps
  `accountsToday` and accepts a reason) but a split it sends with more than four places, a repeated place or parts
  short of the total is now refused, shown as a generic error.
- **Native build blocker (pre-existing):** `npm install`'s postinstall fails — `expo-camera` 57.0.5 is installed but the
  Android scan-region patch was cut against 57.0.4. Expo Go is unaffected.
- `GET /closings/overview` under MySQL's default `sql_mode` (`ONLY_FULL_GROUP_BY`): not re-checked; live runs with
  `sql_mode=""`.
- **WhatsApp:** no provider adapter exists and none is faked; the closing templates await approved copy.
- **Deferred by instruction:** the control website (`docs/38`), scanner and refund work.

## 📋 Known, not fixed

- **The server still reopens a closed day automatically** on a sale or paid receipt (rule 25); the phone no longer lets
  Sell or Receive reach one, but an older build or another client would. Nobody without `closing.count` is locked by
  the phone (the lock reads that view).
- **`/loans/closing-reminders`** is served and no longer read by the app.
- **A split can no longer leave a debt** (`docs/59`, the judgement): a partial payment is one method with a named debtor.
- **Older wording seen on the real data:** a sale paid through an account reads "+0 MRU cash" in the closing history;
  counts of one read "1 balances", "1 payments".
- **A snapshot stored before `b4e4342`** keeps what it stored (a person's acknowledged skip as *not verified*); live's
  closes (the 26th and 27th, from 05:05Z on the 27th) were all made on `b4e4342`, so none is affected.
- **Skipping a channel with a reason** no longer has a screen (the counting page is gone); the popup's two ways are the
  amount or the attestation (D71). The server still accepts a skip.
- **The keyboard and the system's own large text** are the handset's to prove; the web checks emulate both.
- On the iPhone's **web** browser the signed amount field offers a digits-only pad (the native app uses the signed pads).
- Reanimated's own Reduce Motion (the sheets, the buttons) is read at launch; only the history's reveal follows a change
  made while the app is open.
- **The day's expenses by category no longer appear on the Daily closing** (removed from Money movements at the
  user's request); the Expenses figure stays on the statement and in Sales details; the list itself is on Money →
  Expenses.
- **"Debt settled for this day" is `totals.olderDebts`** — older debts collected on the day; if the user meant this
  day's sales paid later the same day, the line should read `sales.collected.laterSameDay` instead.
- **A stored business date cannot be corrected from any screen** (`docs/56` §1.3 would be a scripted, approved change).
- **Only D−1 is checked for *Needs review*** (docs/51 limit): the 22nd's unclosed day is not announced.
- **A past *Needs review* day cannot be closed from the phone** (docs/51 limit, unchanged).
- `GET /expenses?date=` filters on `spent_on`, the memo date — no screen calls it.
- **Resuming a half-checked delivery** after the app was killed means picking the same file again on Receive.
- The review's **draft** is still the whole batch (43 KB) on every change — measured negligible in JavaScript.
- Home's failed-server body still reads "Everything else on this screen still works" although the cards that need the
  same reply are absent.
- **`product_velocity`** is no longer read or written — drop it in a later migration.
- **The Catalogue's "Last sold"** finds quantity lines only, so a phone never shows one.
- `closingHistory.title` is unused; the exports keep their movement headers.
- The Analytics **snapshot** (`today`/`month`, API only, on no screen) reads "today" as the UTC date.
- A count or a goal whose period holds only a cancellation or return reads below zero (intended); the goal's bar is empty.
- **Rollup recovery time:** up to ~90 s after a restart; `done` requests kept; a failing request visible only in
  `rollup_requests.last_error` and the log.
- `scripts/rollup-audit.js` is superseded by `rollup-drift.js`.
- **Corrections not available, by name:** reversing a purchase payment as "not paid"; editing a sale line or cancelling
  part of a sale; a sale with a return; a purchase whose goods have moved.
- The approval audit's `before` is the full preview since 0079.
- Loans, consignment and employee-debt cash are outside the report, as they are outside the closing.
- Expense and refund confirmations check the day's lock without taking the closing row's lock.
- Selling a phone outright to another store is still the documented contract gap in the partner ranking.
- The Stock tab's own list shows full identifiers (rule 19d); the list reached from Home masks.
- Filter chips are 36 pt tall by design-system decision (hit slop to 48) — except the review's, which are 48 pt (D45).
- Two scripts logging in the same user concurrently deadlock on `users.last_login`; harmless for one phone.
- On web, a screen pushed from a tab announces its back button as "(tabs), back"; the tab navigator keeps inactive
  tabs mounted.
- Prisma drift report: `units.identifier` is a stored generated column from 0008 that Prisma cannot model.
- `npx eslint .` reports one pre-existing error in `scripts/verify-native-patch.js`; the backend has no ESLint
  configuration.

## The next exact action

1. **The user's review on the phone** (reload Expo Go, `exp://192.168.100.3:8081`; the API on 3010 already runs the
   new backend): `docs/24` §46 W1–W14 — Home open and closed, Open store now after and before 06:00, a guarded route,
   the Money card and its period, Sales details and the purple history (Arabic, Reduce Motion), a sale with a 3-day
   window, a four-method split and the fifth, a long Choose from stock. The phase is called complete only on the
   user's word; a close or reopen made during the review is the user's own act on live.
2. **The user's call** on the Arabic Home order; change only what they choose (one line).
3. **The user's decision** on counting by a store employee; build only what they choose.
4. Then `docs/24` §45 (as amended by §46), §44 U1–U13, §43 T1–T13 and the older backlog.
5. **If the user approves it:** the `spent_on` tidy-up of `docs/57` §1.5 (three rows, audited, after a backup per
   `docs/22`).
6. When the WAMP service is wanted back: stop the session MySQL (`mysqladmin -uroot --protocol=tcp -P3306 shutdown`),
   then start `wampmysqld64` from an elevated prompt or the WAMP tray.
7. Fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy; deploy the backend before the app.
