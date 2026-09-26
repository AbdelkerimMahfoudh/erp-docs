# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Owner: **NONE**
- Last session: **CLAUDE-A**, `started_at_utc: 2026-09-26T06:05Z` — **the compact Daily closing** (Home → Daily
  closing and its direct Money / correction / history paths; no pictures; live untouched): the screen reorganised on
  the same report, count, close, reopen and opening — the statement first (sales and items; gross profit, expenses
  and result where permitted and calculable), Sales details as its one expandable with the way to the transactions,
  Check balances per channel with Count cash / Check balance and expected · counted · difference once checked, Money
  movements behind a disclosure, Review and close, Correct a transaction and Closing history where they were
  (D63–D68); `spent_on` said apart from the business date (rule 24c); the three memo-dated rows **not edited**. The
  real 03:41 scenario verified on a copy of live (17/17); the screens read from the page (23/23). `docs/58`,
  `docs/21` "The compact Daily closing", `docs/04` 24c, `docs/24` §45. Takeover HEADs were docs `28f7154` · backend
  `4bc2d72` · mobile `05c76bf`. Backend unchanged; no migration; nothing written to live.
- **Awaiting the user's decision:** the tidy-up of three expenses' `spent_on` to their confirmation date
  (`docs/57` §1.5, `docs/58` §2) — no figure moves; not authorised in this phase; not done.
- **Running — left running for the phone:**
  - **MySQL as a session process** (pid 14604, port 3306) with the WAMP service's own configuration
    (`C:/Users/HP/AppData/Local/Temp/claude/session-my.ini`: `sql_mode` empty, `utf8mb4_unicode_ci`, no binary log).
    The WAMP service `wampmysqld64` is **Stopped** and cannot be started from the non-elevated shell. **Before
    starting the service, stop this process:** `mysqladmin -uroot --protocol=tcp -P3306 shutdown`.
  - **The API on 0.0.0.0:3010** (`backend/dist` from **`4bc2d72`**, **pid 14540**, `node --enable-source-maps
    dist/src/main` in `backend/`); logs `C:/Users/HP/AppData/Local/Temp/claude/api-3010.out.log` / `.err.log`. The
    phone had not called it since its restart at 05:19Z.
  - **Metro on 0.0.0.0:8081** (pid 7632, launcher 14128), `expo start --clear` in `mobile/`; log
    `C:/Users/HP/AppData/Local/Temp/claude/metro-8081.log`. It serves the working tree, i.e. mobile `ad78607`.
- Next intended action: **the phone** (`docs/24` §45 V1–V12, then §44 U1–U13, §43 T1–T13 and the older backlog).
  Reload Expo Go (`exp://192.168.100.3:8081`). "Before 06:00" means by the boutique's clock (UTC on live).

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed by this phase.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`4bc2d72`** — unchanged this phase | level | 0 |
| `erp-mobile` | `reports-export` | **`ad78607`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

This phase: mobile `0601ccb` (the compact Daily closing: `app/closing/index.tsx`, `app/closing/count.tsx` with
`?focus=`, eleven `dailyReport.*` keys × 3 languages, `lib/daily-closing-screen.test.ts`), `ad78607` (the result's
lines folded into Sales details — one expandable under the statement, as the approved references show). Docs:
`docs/58` (new), `docs/21` entry, `docs/04` rule 24c, `docs/24` §45, the session log, this file. Earlier the same day:
`docs/56` (backend `4f63ccd`, `4bc2d72`; mobile `00a0575`, `407b1fd`) and `docs/57` (mobile `6c03889`, `05c76bf`).

## What changed (no schema change, no data change)

| Where | Now |
|---|---|
| **Daily closing — first view** | the boutique, the date, the recorded opening, the standing, the freshness; one statement card: the sales value with "{n} sales · {m} items", Gross profit / Expenses / Result after expenses each only where the server sent it, "Result: cannot calculate yet ({n} items without a recorded cost)" otherwise; a person without the sales section sees money received and the line saying who sees sales and expenses (D63) |
| **Sales details** (the statement's one expandable) | invoiced, cancelled today, returned today, net sales, then how the result follows (cost of items sold, gross profit, expenses, result after, before fixed, scope, the rule — or "Cannot calculate yet"), then collected for these sales (at the till, later the same day, taken back by corrections), still owed, the counting rule, *See the transactions* → `/sales/period?day=` (D64) |
| **Check balances** | "Optional. An unchecked balance is closed as not verified — never as matched."; the Cash drawer (opening anchored on the last counted close or "starts from 0", received, paid out, *Should be in the drawer*, Counted and Difference once counted, **Count cash**); each account (*Recorded movement*, received, paid out, *Movement in the account app* and Difference once checked, **Check balance**); the note that these are what staff recorded, not balances. Both actions open the counting screen on that channel (`?focus=cash` / `?focus=<accountId>`), its field focused (D65) |
| **Money movements** | one disclosure, closed, the day's net beside it: every channel's money in, Received / Older debts collected / Paid out / Net, Details by channel, the Expenses (by category, reversals, total, fixed, every expense) (D66) |
| **Actions and history** | Open the boutique, Review and close (secondary while Open is offered; disabled offline), Reopen, the Correct a transaction row, the notYours line, Closing history — unchanged conditions and contract (`clientUuid`, `reportVersion`, acknowledgement + reason, `report_changed`, delegates, repeat taps); the generic "Check physical…" row gone since every channel has its own (D67). A past day reads the same statement read-only (D68). Reopening and the before-06:00 choice untouched |
| **Rule 24c (`docs/04`)** | an expense's `spent_on` is a memo date that moves no figure; the accounting day is the confirmation date (fixed: due date) |

## Verification

| Kind | Result |
|---|---|
| **The real 03:41 scenario** (a read-only dump of live restored as the copy; built API, fake clock) | **17 of 17** (`docs/58` §3.1): at 03:41 on the 26th the business day is the 25th with 4 sales (6 748) and 3 confirmed expenses (840), 00005/00006 and Sbou7/Courent among them, open and closable; the statement's arithmetic the server's; the drawer's expected figure, Bankily a recorded movement; a cash count → expected / counted / +50 and the close still needing the acknowledgement; 06:00:30 → the 26th empty with the warning, the 25th *Needs review* with its records, count and opening, not closable from the phone; nothing moved |
| **The screens, read from the page** (web export of `ad78607`, the same copy) | **23 of 23 views passed** (`docs/58` §3.2): the 25th at 03:41 in EN/FR/AR at 320–430 pt, dark, 130 % text; Sales details, Money movements, Count cash, Check balance and Review and close through the real controls; the +50 count; a store employee's view; 06:00 with the 25th read-only in history. Offline read in the source, left to the phone |
| **Gates** | **Mobile:** `tsc` clean, **77 pure suites / 1 079 cases, 0 failed**, i18n parity **3 213**, `expo lint` **0 errors** (31 pre-existing warnings). **Backend:** unchanged at `4bc2d72` — 159 suites / 2 835 tests passed at its last full run |
| **Phone** | **Not run** — `docs/24` §45 V1–V12 |

## Data and process safety

- Live received nothing; no sale, expense, opening or closing changed; the four `spent_on 2026-09-18` rows are as
  they were. The dump of live (`~/erp-backups/phonestore-verify-20260926-060646.sql`) is read-only and outside every
  repository. The copy `prisma_verify_home` was rebuilt per run and **dropped**; 3012, 19012 and 9334 are free.
  Backend, the API on 3010, MySQL and Metro untouched this phase. Scratch tooling in OS temp only; the three trees
  are clean.

## 🔴 Blockers and pending approvals

- **Pending the user's decision:** `spent_on` tidy-up of three expenses (`docs/57` §1.5, `docs/58` §2).
- **Native build blocker (pre-existing):** `npm install`'s postinstall fails — `expo-camera` 57.0.5 is installed but the
  Android scan-region patch was cut against 57.0.4. Expo Go is unaffected.
- `GET /closings/overview` under MySQL's default `sql_mode` (`ONLY_FULL_GROUP_BY`): not re-checked; live runs with
  `sql_mode=""`.
- **WhatsApp:** no provider adapter exists and none is faked; the closing templates await approved copy.
- **Deferred by instruction:** the control website (`docs/38`) is unchanged.

## 📋 Known, not fixed

- **A stored business date cannot be corrected from any screen** (the optional 03:41 correction of `docs/56` §1.3 would
  be a scripted, backed-up, approved change; the rules did not require it).
- **Only D−1 is checked for *Needs review*** (docs/51 limit): the 22nd's unclosed day is not announced.
- **A past *Needs review* day cannot be closed from the phone** (docs/51 limit, unchanged): it stays read-only.
- `GET /expenses?date=` filters on `spent_on`, the memo date — no screen calls it; if one ever does, it should filter
  on the accounting day instead.
- The history *section* and the history *disclosure* both read "Closing history" (as before); a page-text check must
  tap the last match.
- **Resuming a half-checked delivery** after the app was killed means picking the same file again on Receive — the
  saved draft then replaces the fresh read. Receive could offer "Continue the delivery you were checking".
- The review's **draft** is still the whole batch (43 KB) on every change — measured negligible in JavaScript.
- Home's failed-server body still reads "Everything else on this screen still works" although the cards that need the
  same reply (top boutique, latest phones, closing) are absent; Sell, Receive and the pending rows are what still work.
- **`product_velocity`** is no longer read or written — drop it in a later migration.
- **The Catalogue's "Last sold"** finds quantity lines only, so a phone never shows one.
- `closingHistory.title` is unused; the exports keep their movement headers.
- The Analytics **snapshot** (`today`/`month`, API only, on no screen) reads "today" as the UTC date.
- A count or a goal whose period holds only a cancellation or return reads below zero (intended); the goal's bar is empty.
- **Rollup recovery time:** a request whose recompute died mid-way waits for its lease (60 s) and the next sweep (30 s)
  — up to ~90 s after a restart. `done` requests are kept and not pruned; a failing request is visible only in
  `rollup_requests.last_error` and the log. One API process assumed (a second is safe by lease and retry).
- `scripts/rollup-audit.js` (revenue-only, `DATE(sold_at)`, existing rows only) is superseded by `rollup-drift.js`.
- **Corrections not available, by name:** reversing a purchase payment as "not paid" (cancel the purchase instead);
  editing a sale line or cancelling part of a sale (cancel and sell again); a sale with a return (correct it on the
  return); a purchase whose goods have moved (correct the later record first).
- The approval audit's `before` is the full preview (`$.payment.method`, `$.move`, …) since 0079.
- Loans, consignment and employee-debt cash are outside the report, as they are outside the closing.
- Expense and refund confirmations check the day's lock without taking the closing row's lock.
- Selling a phone outright to another store is still the documented contract gap in the partner ranking.
- The Stock tab's own list shows full identifiers (rule 19d); the list reached from Home masks.
- Filter chips are 36 pt tall by design-system decision, with hit slop restoring a 48 pt target — except the review's,
  which are 48 pt because they sit inside a scrolling list (D45).
- Two scripts logging in the same user concurrently deadlock on `users.last_login`; harmless for one phone.
- On web, a screen pushed from a tab announces its back button as "(tabs), back"; the tab navigator keeps inactive
  tabs mounted, so a page-text check must assert the route, not the absence of another tab's words. Dynamic type is
  handset-only.
- Prisma drift report: `units.identifier` is a stored generated column from 0008 that Prisma cannot model.
- `npx eslint .` over the whole app reports one pre-existing error in `scripts/verify-native-patch.js` (`__dirname`),
  outside `expo lint`'s scope. The backend has a `lint` script but no ESLint configuration. Jest's full run ends with
  one worker force-exited (a pre-existing teardown leak; every test passes).

## The next exact action

1. **Phone:** reload Expo Go (`exp://192.168.100.3:8081`) and run `docs/24` §45 V1–V12 — the statement, Sales details
   and *See the transactions*, Check balances with Count cash (+50) and Check balance on Bankily, Money movements,
   Review and close with an unchecked account (the acknowledgement and reason, one close on a double tap), a store
   employee's view, the before-06:00 case and *Yesterday* in history, FR/AR at 320 pt and large text, dark, flight
   mode — then §44 U1–U13, §43 T1–T13 and the older backlog. No sample record on the live store unless the user asks;
   a real count or close before 06:00 records a real event on the 25th's successor.
2. **If the user approves it:** the `spent_on` tidy-up of `docs/57` §1.5 (three rows, audited, after a backup per
   `docs/22`). If the Owner says the 03:41 records were meant for 26 September: `docs/56` §1.3, same conditions.
3. When the WAMP service is wanted back: stop the session MySQL (`mysqladmin -uroot --protocol=tcp -P3306 shutdown`),
   then start `wampmysqld64` from an elevated prompt or the WAMP tray.
4. Fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy.
