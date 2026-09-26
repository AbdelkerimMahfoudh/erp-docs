# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Owner: **CLAUDE-A**
- `started_at_utc: 2026-09-26T07:40Z` — takeover HEADs (all clean, level): docs `8d548c0` · backend `4bc2d72` · mobile
  `1ad460f`. Set before any edit.
- **Active phase and scope (the user's brief of 2026-09-26, Daily closing UI correction only; accounting,
  permissions, counting, closing and reopening unchanged; no pictures; no other page):** Sales details as figure rows
  only (invoiced, cancellations/returns when nonzero, net, cost of items, gross profit, expenses, result) with the
  explanations behind a small accessible (?) beside the title; the collected / owed block and *See the transactions*
  removed from it; Money movements always visible as a short list — each configured channel's recorded movement, a
  divider, debt settled for this day (already inside the channels, not added again), the total recorded movement
  across the channels said as such, never as cash or a balance; checked on a narrow phone in EN/FR/AR and the page's
  text returned for review.
- Next intended action: the screen, the keys, the pins, the page check on a copy of live.
- Last session: **CLAUDE-A**, `started_at_utc: 2026-09-26T07:05Z` — **the Daily closing copy pass** (copy only, EN/FR/AR;
  `docs/58` §1.2, D69): the drawer's figure named "Recorded cash movement, from a 0 start" whenever no counted opening
  anchors it (report, review sheet, counting screen) and "Should be in the drawer" only when one does; accounts as
  *recorded movement* and *movement shown by the account app* everywhere — "Checked against the app", "Check
  movement", "Check the drawer and accounts" — never a balance, never a count. Calculations, optional checks, the close
  contract and live data unchanged. Takeover HEADs were docs `466ddb0` · backend `4bc2d72` · mobile `ad78607`; the
  `IN_PROGRESS` mark (`ac5de45`) was set after the first edits — noted in the log. Before it, the same day: the
  compact Daily closing (`docs/58`), the expense's two dates and the Home reference pass (`docs/57`), the pre-06:00
  opening choice and the simple Home (`docs/56`).
- **Awaiting the user's decision:** the tidy-up of three expenses' `spent_on` to their confirmation date
  (`docs/57` §1.5, `docs/58` §2) — no figure moves; not authorised; not done.
- **Running — left running for the phone:**
  - **MySQL as a session process** (pid 14604, port 3306) with the WAMP service's own configuration
    (`C:/Users/HP/AppData/Local/Temp/claude/session-my.ini`: `sql_mode` empty, `utf8mb4_unicode_ci`, no binary log).
    The WAMP service `wampmysqld64` is **Stopped** and cannot be started from the non-elevated shell. **Before
    starting the service, stop this process:** `mysqladmin -uroot --protocol=tcp -P3306 shutdown`.
  - **The API on 0.0.0.0:3010** (`backend/dist` from **`4bc2d72`**, **pid 14540**, `node --enable-source-maps
    dist/src/main` in `backend/`); logs `C:/Users/HP/AppData/Local/Temp/claude/api-3010.out.log` / `.err.log`.
  - **Metro on 0.0.0.0:8081** (pid 7632, launcher 14128), `expo start --clear` in `mobile/`; log
    `C:/Users/HP/AppData/Local/Temp/claude/metro-8081.log`. It serves the working tree, i.e. mobile `1ad460f`.
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
| `erp-backend` | `reports-export` | **`4bc2d72`** — unchanged since `docs/56` | level | 0 |
| `erp-mobile` | `reports-export` | **`1ad460f`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

This pass: mobile `1ad460f` (`app/closing/index.tsx`, `app/closing/count.tsx`, `components/closing/CloseReviewSheet.tsx`,
`lib/closing-report-view.ts` + test, `lib/daily-closing-screen.test.ts`, `lib/closing-screen.test.ts`, i18n EN/FR/AR).
Docs: `docs/58` §1.2, `docs/21` D69, `docs/24` §45 V3/V5, the session log, this file. The day's earlier commits:
mobile `0601ccb`, `ad78607` (the compact Daily closing), `6c03889`, `05c76bf` (`docs/57`), `00a0575`, `407b1fd`
(`docs/56`); backend `4f63ccd`, `4bc2d72` (`docs/56`).

## What changed (copy only; no schema, data, calculation or request change)

| Where | Now |
|---|---|
| **Report — Cash drawer** | "Should be in the drawer" only when a counted close anchors the opening; otherwise **"Recorded cash movement, from a 0 start"** (the review sheet's line likewise). The opening line still says "No counted opening yet — starts from 0" |
| **Report — each account** | "Recorded movement" (received, paid out); once checked "Movement in the account app" and Difference; the chip **"Checked against the app"** (or "Checked before reopening"); the action **"Check movement"** (was "Check balance"); a history row "{amount} shown by the account app" |
| **Counting screen** | titled **"Check the drawer and accounts"**; the drawer's row "Expected in the drawer" / "Recorded cash movement, from a 0 start" by the report's anchor ("Expected" until known); the account's row "Recorded movement", its field "Movement shown by the account app", its chips "Checked" / "Not checked yet", its settled line "Movement in the account app" · Difference · "Less/More than the recorded movement.", after a reopen "Checked before the day was reopened — check again" / "Check again". The drawer keeps Counted / Count again / "The drawer is short…" |
| **Unchanged** | the statement, Sales details, Money movements, Review and close and its acknowledgement, Correct a transaction, Closing history, the `verification` states, the accounting, reopening and the before-06:00 choice |

## Verification

| Kind | Result |
|---|---|
| **Focused suites** | `daily-closing-screen` 6 · `closing-screen` **14 pass / 0 fail** · `closing-report-view` 13 · `home-screen` 8 · `reporting-rules` 10 · `layout` 16 — every new word pinned in the source |
| **Whole set** | `tsc` clean; **77 pure suites / 1 079 cases, 0 failed**; i18n parity **3 224 / 3 224 / 3 224** in one order; `expo lint` 0 errors (31 pre-existing warnings) |
| **Backend** | unchanged at `4bc2d72` (159 suites / 2 835 tests at its last full run) |
| **Earlier the same day, on this screen** (`docs/58` §3) | the real 03:41 scenario on a copy of live 17/17; the screens read from the page 23/23 (before the copy pass; wording only since) |
| **Phone** | **Not run** — `docs/24` §45 V1–V12 |

## Data and process safety

- Live received nothing; no record changed; the four `spent_on 2026-09-18` rows are as they were. No copy was needed
  for a wording pass; 3012, 19012 and 9334 are free. Backend, the API on 3010, MySQL and Metro untouched. Scratch
  tooling in OS temp only; the three trees are clean.

## 🔴 Blockers and pending approvals

- **Pending the user's decision:** `spent_on` tidy-up of three expenses (`docs/57` §1.5, `docs/58` §2).
- **Native build blocker (pre-existing):** `npm install`'s postinstall fails — `expo-camera` 57.0.5 is installed but the
  Android scan-region patch was cut against 57.0.4. Expo Go is unaffected.
- `GET /closings/overview` under MySQL's default `sql_mode` (`ONLY_FULL_GROUP_BY`): not re-checked; live runs with
  `sql_mode=""`.
- **WhatsApp:** no provider adapter exists and none is faked; the closing templates await approved copy.
- **Deferred by instruction:** the control website (`docs/38`) is unchanged.

## 📋 Known, not fixed

- **The counting screen learns the drawer's anchor from the report's cached reply**; opened by a direct route with no
  report read yet, its drawer row says the neutral "Expected" until the report arrives. The open view carries no
  anchor field of its own (a read-only addition, if ever wanted).
- **A stored business date cannot be corrected from any screen** (the optional 03:41 correction of `docs/56` §1.3 would
  be a scripted, backed-up, approved change; the rules did not require it).
- **Only D−1 is checked for *Needs review*** (docs/51 limit): the 22nd's unclosed day is not announced.
- **A past *Needs review* day cannot be closed from the phone** (docs/51 limit, unchanged): it stays read-only.
- `GET /expenses?date=` filters on `spent_on`, the memo date — no screen calls it.
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

1. **Phone:** reload Expo Go (`exp://192.168.100.3:8081`) and run `docs/24` §45 V1–V12 — with V3 and V5 reading the
   new words ("Recorded cash movement, from a 0 start" on an unanchored drawer; "Recorded movement", "Movement shown
   by the account app", "Checked against the app", "Check movement", "Check the drawer and accounts") — then §44
   U1–U13, §43 T1–T13 and the older backlog. No sample record on the live store unless the user asks.
2. **If the user approves it:** the `spent_on` tidy-up of `docs/57` §1.5 (three rows, audited, after a backup per
   `docs/22`). If the Owner says the 03:41 records were meant for 26 September: `docs/56` §1.3, same conditions.
3. When the WAMP service is wanted back: stop the session MySQL (`mysqladmin -uroot --protocol=tcp -P3306 shutdown`),
   then start `wampmysqld64` from an elevated prompt or the WAMP tray.
4. Fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy.
