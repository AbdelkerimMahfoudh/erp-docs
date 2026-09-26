# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Owner: **NONE**
- Last session: **CLAUDE-A**, `started_at_utc: 2026-09-26T07:40Z` — **the Daily closing UI correction** (`docs/58`
  §1.3, D70; presentation only): Sales details as figure rows with the words behind an accessible (?); the collected /
  owed block and its link gone from it; Money movements always in view as a short channel list ending in "Money in
  the shop — recorded movement" with its one-line meaning. Checked on a copy of live in EN/FR/AR at 320 and 393 pt
  (14/14); the page's text returned to the user for review, who has not yet reviewed it on the phone. Takeover HEADs
  were docs `8d548c0` · backend `4bc2d72` · mobile `1ad460f`. Earlier the same day: the copy pass (`docs/58` §1.2), the
  compact Daily closing (`docs/58`), `docs/57`, `docs/56`.
- **Awaiting the user:** (1) the visual review of the Daily closing on the phone before it is called finished
  (Metro serves the working tree, mobile `fe55588`); the label "Money in the shop — recorded movement" was shipped in
  that form because the bare words would claim a balance the accounts cannot make — the user may rename it;
  (2) the tidy-up of three expenses' `spent_on` (`docs/57` §1.5, `docs/58` §2) — not authorised, not done.
- **Running — left running for the phone:**
  - **MySQL as a session process** (pid 14604, port 3306) with the WAMP service's own configuration
    (`C:/Users/HP/AppData/Local/Temp/claude/session-my.ini`: `sql_mode` empty, `utf8mb4_unicode_ci`, no binary log).
    The WAMP service `wampmysqld64` is **Stopped** and cannot be started from the non-elevated shell. **Before
    starting the service, stop this process:** `mysqladmin -uroot --protocol=tcp -P3306 shutdown`.
  - **The API on 0.0.0.0:3010** (`backend/dist` from **`4bc2d72`**, **pid 14540**, `node --enable-source-maps
    dist/src/main` in `backend/`); logs `C:/Users/HP/AppData/Local/Temp/claude/api-3010.out.log` / `.err.log`.
  - **Metro on 0.0.0.0:8081** (pid 7632, launcher 14128), `expo start --clear` in `mobile/`; log
    `C:/Users/HP/AppData/Local/Temp/claude/metro-8081.log`. It serves the working tree, i.e. mobile `fe55588`.
- Next intended action: **the user's review of the Daily closing on the phone**, then `docs/24` §45 V1–V12, §44,
  §43 and the older backlog. Reload Expo Go (`exp://192.168.100.3:8081`).

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed by this phase.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`4bc2d72`** — unchanged since `docs/56` | level | 0 |
| `erp-mobile` | `reports-export` | **`fe55588`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

This pass: mobile `41d2ae3` (Sales details as rows with the (?), the collected / owed block gone, Money movements in
view as the channel list; four keys EN/FR/AR; the pins), `fe55588` (the drawer's word aligned between the card and the
list). Docs: `docs/58` §1.3 and §3.4, `docs/21` D70, `docs/24` §45 V2/V6, the session log, this file. The day's earlier
commits: mobile `1ad460f` (copy pass), `0601ccb`, `ad78607` (the compact closing), `6c03889`, `05c76bf` (`docs/57`),
`00a0575`, `407b1fd` (`docs/56`); backend `4f63ccd`, `4bc2d72` (`docs/56`).

## What changed (presentation only; no schema, data, calculation, permission or request change)

| Where | Now |
|---|---|
| **Sales details** | figure rows only — Invoiced sales, Sales cancelled / Returns approved only when nonzero, Net sales, Cost of items sold, Gross profit, Expenses, Result after expenses; no paragraph; a small accessible **(?)** beside the title ("What these figures mean") opens the counting rule, the result's formula and the fixed-cost scope — or "Cannot calculate yet…" — in a dialog, only when asked. No collected / at-the-till / paid-later / still-owed lines, no "See the transactions" |
| **Money movements** | always in view, nothing to expand: a heading; one line per configured channel with its recorded net movement (the drawer named "Cash drawer" as its card is; the unattributed bucket only when it holds something); a rule; "Debt settled for this day (included above)" (`totals.olderDebts`, inside the channels, never added again); **"Money in the shop — recorded movement"** (`totals.net`) with the line "The net of what was recorded through these channels this day — not counted cash, not provider balances." The Received / Paid out / Net block, Details by channel and the expenses subsection are gone |
| **Unchanged** | the statement, Check balances and its per-channel checks, Review and close, Correct a transaction, Closing history, the accounting, the `verification` states, reopening and the before-06:00 choice |

## Verification

| Kind | Result |
|---|---|
| **The page, a copy of live at 03:41 on the 26th** (web export of `fe55588`) | **14 of 14 views clean**: EN/FR/AR at 320 and 393 pt, EN dark, EN 320 at 130 % text — Sales details closed and opened, the (?) dialog, Money movements in view; "Cash drawer +5 558 · Bankily +350 · Debt settled 0 · Money in the shop — recorded movement +5 908" (the channel lines add up to the last). The page's text per language kept in OS temp for the review |
| **Gates** | `tsc` clean; **77 pure suites / 1 079 cases, 0 failed**; i18n parity **3 228 / 3 228 / 3 228**; `expo lint` 0 errors (31 pre-existing warnings). Backend unchanged at `4bc2d72` (159 / 2 835 at its last full run) |
| **Phone** | **Not run** — the user's visual review first, then `docs/24` §45 V1–V12 |

## Data and process safety

- This session wrote nothing to live; the four `spent_on 2026-09-18` rows are as they were. **Live moved by the user's
  hand meanwhile** (Test Store · Main Store, read-only from the database at 08:0xZ): the boutique **opened for the
  26th at 06:57** (after 06:00 — no choice, as designed); sales **00007** (2 500) at 06:58 and **00008** (3 200) at
  06:59, both **business date 2026-09-26**, both paid through Bankily; Bankily **skipped twice at 07:01** then
  **checked at 07:12 — 5 700 shown by the app against a recorded movement of 5 700, difference 0**; the 26th's
  closing row stands at *counting*. Live now holds **15 sales, 7 expenses, 5 closing events**. The user was therefore
  driving the new screens on the phone during this session. The copy `prisma_verify_home` was rebuilt per run from
  the read-only live dump of 06:06Z (which predates that activity) and **dropped**; 3012, 19012 and 9334 are free.
  Backend, the API on 3010, MySQL and Metro untouched. Scratch tooling in OS temp only; the three trees are clean.

## 🔴 Blockers and pending approvals

- **Awaiting the user's visual review** of the Daily closing on the phone; the label "Money in the shop — recorded
  movement" flagged for their decision.
- **Pending the user's decision:** `spent_on` tidy-up of three expenses (`docs/57` §1.5, `docs/58` §2).
- **Native build blocker (pre-existing):** `npm install`'s postinstall fails — `expo-camera` 57.0.5 is installed but the
  Android scan-region patch was cut against 57.0.4. Expo Go is unaffected.
- `GET /closings/overview` under MySQL's default `sql_mode` (`ONLY_FULL_GROUP_BY`): not re-checked; live runs with
  `sql_mode=""`.
- **WhatsApp:** no provider adapter exists and none is faked; the closing templates await approved copy.
- **Deferred by instruction:** the control website (`docs/38`) is unchanged.

## 📋 Known, not fixed

- **The day's expenses by category no longer appear on the Daily closing** (removed from Money movements at the
  user's request); the Expenses figure stays on the statement and in Sales details; the list itself is on Money →
  Expenses.
- **"Debt settled for this day" is `totals.olderDebts`** — older debts collected on the day; if the user meant this
  day's sales paid later the same day, the line should read `sales.collected.laterSameDay` instead.
- **The counting screen learns the drawer's anchor from the report's cached reply**; opened cold, its drawer row says
  the neutral "Expected" until the report arrives.
- **A stored business date cannot be corrected from any screen** (`docs/56` §1.3 would be a scripted, approved change).
- **Only D−1 is checked for *Needs review*** (docs/51 limit): the 22nd's unclosed day is not announced.
- **A past *Needs review* day cannot be closed from the phone** (docs/51 limit, unchanged).
- `GET /expenses?date=` filters on `spent_on`, the memo date — no screen calls it.
- The history *section* and the history *disclosure* both read "Closing history"; a page-text check must tap the last
  match.
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
  tabs mounted. Dynamic type is handset-only.
- Prisma drift report: `units.identifier` is a stored generated column from 0008 that Prisma cannot model.
- `npx eslint .` reports one pre-existing error in `scripts/verify-native-patch.js`; the backend has no ESLint
  configuration; Jest's full run ends with one worker force-exited (a pre-existing teardown leak; every test passes).

## The next exact action

1. **The user's visual review** of the Daily closing on the phone (reload Expo Go, `exp://192.168.100.3:8081`, Home →
   the Daily closing entry): the statement, Sales details and its (?), Check balances, Money movements and its last
   line. If "Money in the shop — recorded movement" or "Debt settled for this day" should read otherwise, change the
   two `dailyReport.movements.*` values in EN/FR/AR only.
2. Then `docs/24` §45 V1–V12, §44 U1–U13, §43 T1–T13 and the older backlog. No sample record on the live store unless
   the user asks.
3. **If the user approves it:** the `spent_on` tidy-up of `docs/57` §1.5 (three rows, audited, after a backup per
   `docs/22`).
4. When the WAMP service is wanted back: stop the session MySQL (`mysqladmin -uroot --protocol=tcp -P3306 shutdown`),
   then start `wampmysqld64` from an elevated prompt or the WAMP tray.
5. Fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy.
