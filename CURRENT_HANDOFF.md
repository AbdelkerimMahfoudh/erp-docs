# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Owner: **NONE**
- Last session: **CLAUDE-A**, `started_at_utc: 2026-09-26T05:40Z` — **the expense's two dates, the Home reference
  pass and the check rerun** (Home / Money / Daily closing; no pictures; live untouched): the two 03:46 expenses'
  `spent_on 18 Sep` explained (a continuity column that drives no money — both count for 25 Sep everywhere) and its
  cause fixed for future entries (the draft was written back after `clear()`; Discard kept the date); Home's greeting
  line restored with the before-06:00 note beside it, and the three money figures as distinct quiet cards (D61–D62);
  the page check's last discrepancy resolved and **33 of 33 views passed**; full gate totals recorded. `docs/57`,
  `docs/21` addendum, `docs/24` §44 U12–U13. Takeover HEADs were docs `d8f9e00` · backend `4bc2d72` · mobile
  `407b1fd`. Backend unchanged; no migration; nothing written to live.
- **Awaiting the user's decision:** the tidy-up of three expenses' `spent_on` (25 Sep "Le9de" 240, 26 Sep "Sbou7" 100
  and "Courent" 500) to their confirmation date — `docs/57` §1.5; no figure moves; not done.
- **Running — left running for the phone:**
  - **MySQL as a session process** (pid 14604, port 3306) with the WAMP service's own configuration
    (`C:/Users/HP/AppData/Local/Temp/claude/session-my.ini`: `sql_mode` empty, `utf8mb4_unicode_ci`, no binary log).
    The WAMP service `wampmysqld64` is **Stopped** and cannot be started from the non-elevated shell. **Before
    starting the service, stop this process:** `mysqladmin -uroot --protocol=tcp -P3306 shutdown`.
  - **The API on 0.0.0.0:3010** (`backend/dist` from **`4bc2d72`**, **pid 14540**, `node --enable-source-maps
    dist/src/main` in `backend/`); logs `C:/Users/HP/AppData/Local/Temp/claude/api-3010.out.log` / `.err.log`. The
    phone had not called it since its restart at 05:19Z.
  - **Metro on 0.0.0.0:8081** (pid 7632, launcher 14128), `expo start --clear` in `mobile/`; log
    `C:/Users/HP/AppData/Local/Temp/claude/metro-8081.log`. It serves the working tree, i.e. mobile `05c76bf`.
- Next intended action: **the phone** (`docs/24` §44 U1–U13, then §43 T1–T13 and the older backlog). Reload Expo Go
  (`exp://192.168.100.3:8081`). A test "before 06:00" means before 06:00 **by the boutique's clock (UTC on live)**.

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed by this phase.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`4bc2d72`** — unchanged this phase | level | 0 |
| `erp-mobile` | `reports-export` | **`05c76bf`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

This phase: mobile `6c03889` (the draft hook writes only on change and not after a clear; the expense date restored
only when the person set it; Discard resets it), `05c76bf` (the greeting's line back, the note under the header, the
three `FigureCard`s). Earlier the same day: backend `4f63ccd`, `4bc2d72`; mobile `00a0575`, `407b1fd` (`docs/56`).
Docs: `docs/57` (new), `docs/21` addendum, `docs/24` §44 U12–U13, the session log, this file.

## What changed (no schema change, no data change)

| Where | Now |
|---|---|
| **Expense form** | The date comes back from a draft only if the person set it; otherwise it is today's, whatever day the draft was written (this also retires the stale drafts already on phones). Discard puts the date back to today. The field's example is today's date |
| **Every draft screen** (`useDraft`) | A draft is written only when its content changed, and never straight after `clear()` — the just-submitted form no longer comes back as a "restored" draft |
| **Home header** | "Ready when you are." / "Getting your shop ready…" under the greeting again; before 06:00 the line "Sales still count for {yesterday} until 06:00" sits under the header on the same tint, behind a hairline — beside the greeting, not in its place (D61) |
| **Home money figures** | Collected · Expenses · Still owed as three distinct quiet cards: word, amount, MRU, scope, a soft tint by meaning, no icon; three abreast at ≥ 360 pt, two and one at 320, stacked when the system text ≥ 1.2× (D62) |
| **Unchanged** | the one chart, the header tint and calendar date, the comparison rule (D58), the closing entry, every link, the pending rows, the five tabs, the accounting lines; the opening choice of `docs/56` |

## Verification

| Kind | Result |
|---|---|
| **The 03:46 expenses** (live, read-only) | `spent_on 2026-09-18` on the last three entries since the 18th; `confirmation_date 2026-09-25`; counted on the 25th on Home, Money, the Daily closing, rollups and goals; `spent_on` shown nowhere on the phone after submission and used by no screen's filter. Cause: two draft defects (above). **No record changed** |
| **The screens, read from the page** (web export re-built on `05c76bf`, isolated API, fake clock) | **33 of 33 views passed** (`docs/57` §3.1): Home at 03:41 with the greeting line *and* the note in EN/FR/AR at 320–430 pt, light/dark, 130 % text, the three cards uncut; the four links (Stock asserted by the route reached); the notice, the sheet with *Continue* selected in three languages, both choices confirmed, 06:00:30, the reopen sheet |
| **Gates, in full** | **Backend:** `npm test -- --ci` **159 suites / 2 835 tests passed**, `tsc` clean. **Mobile:** `tsc` clean, **76 pure suites / 1 073 cases, 0 failed**, i18n parity **3 202 / 3 202 / 3 202**, `expo lint` **0 errors** (31 pre-existing warnings) |
| **Phone** | **Not run** — `docs/24` §44 U1–U13 |

## Data and process safety

- Live received nothing. The copy `prisma_verify_home` was rebuilt per run and **dropped**; 3012, 19012 and 9334 are
  free. The API on 3010 (`4bc2d72`), MySQL and Metro untouched this phase. Scratch tooling in OS temp only; the three
  trees are clean.

## 🔴 Blockers and pending approvals

- **Pending the user's decision:** `spent_on` tidy-up of three expenses (`docs/57` §1.5).
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
- `GET /expenses?date=` filters on `spent_on`, the continuity column — no screen calls it; if one ever does, it should
  filter on the accounting day instead.
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

1. **Phone:** reload Expo Go (`exp://192.168.100.3:8081`) and run `docs/24` §44 U1–U13 — the header's greeting line
   and, before 06:00 by the boutique's clock, the note beside it; the three cards at 320 pt and with the system text
   at its largest; the opening sheet as the Owner and the notice as a store employee; Continue, Start early, repeat
   taps, the 06:00 boundary, a closed previous day's reopen; an expense the day after another (today's date, an empty
   form after a submission, Discard resets the date) — then §43 T1–T13 and the older backlog. No sample record on the
   live store unless the user asks; a real opening before 06:00 records a real event.
2. **If the user approves it:** the `spent_on` tidy-up of `docs/57` §1.5 (three rows, audited, after a backup per
   `docs/22`). If the Owner says the 03:41 records were meant for 26 September: `docs/56` §1.3, same conditions.
3. When the WAMP service is wanted back: stop the session MySQL (`mysqladmin -uroot --protocol=tcp -P3306 shutdown`),
   then start `wampmysqld64` from an elevated prompt or the WAMP tray.
4. Fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy.
