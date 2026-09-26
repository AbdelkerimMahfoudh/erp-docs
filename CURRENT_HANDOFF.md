# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Owner: **NONE**
- Last session: **CLAUDE-A**, `started_at_utc: 2026-09-26T04:43Z` — **the pre-06:00 opening choice and the simple
  Home** (Home, the Daily closing reached from Home, their direct dependencies; no pictures): the real 03:41 opening
  investigated and reported (consistent with the rules; no correction required, none made); *Open the boutique*
  before 06:00 now asks which business day first — the Owner's two-day sheet with *Continue yesterday* selected, a
  notice for anybody else — and records the choice with actor, instant, business date and audit (D52–D55); Home
  rebuilt on its working behaviour: the shared header on one tint with the store's date and the before-06:00 note,
  sales value first with a server-supplied comparison and one compact chart, three plain money lines, one Daily
  closing entry (D56–D60). `docs/56`, `docs/21` "The pre-06:00 opening choice and the simple Home", `docs/04` rule
  25a, `docs/24` §44. Takeover HEADs were docs `2b4ad31` · backend `9a1155a` · mobile `578df5d`. No migration;
  nothing written to live.
- **Running — left running for the phone:**
  - **MySQL as a session process** (pid 14604, port 3306) with the WAMP service's own configuration
    (`C:/Users/HP/AppData/Local/Temp/claude/session-my.ini`: `sql_mode` empty, `utf8mb4_unicode_ci`, no binary log).
    The WAMP service `wampmysqld64` is **Stopped** and cannot be started from the non-elevated shell. **Before
    starting the service, stop this process:** `mysqladmin -uroot --protocol=tcp -P3306 shutdown`.
  - **The API on 0.0.0.0:3010 — restarted this session on the new build** (`backend/dist` from **`4bc2d72`**,
    **pid 14540**, started with `node --enable-source-maps dist/src/main` in `backend/`); logs
    `C:/Users/HP/AppData/Local/Temp/claude/api-3010.out.log` / `api-3010.err.log`. The phone had not called it since
    the restart at the time of this handoff.
  - **Metro on 0.0.0.0:8081** (pid 7632, launcher 14128), `expo start --clear` in `mobile/`; log
    `C:/Users/HP/AppData/Local/Temp/claude/metro-8081.log`. It serves the working tree, i.e. mobile `407b1fd`.
- Next intended action: **the phone** (`docs/24` §44 U1–U11, then §43 T1–T13 and the older backlog). Reload Expo Go
  (`exp://192.168.100.3:8081`). A test "before 06:00" means before 06:00 **by the boutique's clock (UTC on live)**.

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed by this phase.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`4bc2d72`** | level | 0 |
| `erp-mobile` | `reports-export` | **`407b1fd`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

This phase: backend `4f63ccd` (the opening's `mode`, `openChoices`, the shared early start, `closing-open.spec`),
`4bc2d72` (Home's `figures.comparison`); mobile `00a0575` (`openingPrompt`, `DayChoiceSheet` for open and reopen,
`useOpenDay(mode?)`, the `openChoice.*` keys), `407b1fd` (`HomeHeader`, the Home layout, `comparison` in the type and
the reply check, the pins). Docs: `docs/56` (new), `docs/21`, `docs/04` rule 25a, `docs/24` §44, the session log, this
file.

## What changed (no schema change, no data change)

| Where | Now |
|---|---|
| **`POST /closings/open`** | `mode: continue \| start_new`. `continue` (default) opens the running business date — before 06:00, the previous calendar day. `start_new` (Owner, `closing.start_early`, midnight–06:00; `not_before_day_start` otherwise) writes the same `day_started_early` event a reopen writes, then opens the new date. The `opened` payload and audit row carry `choice` and `calendarDate` whenever a choice existed. Nothing already recorded moves. A closed day is still a reopen (`open_day_closed`); an open one still `open_already_open` |
| **`GET /closings/open/view`** | `openChoices` beside `reopenChoices` (both days for the Owner before 06:00, else `['continue']`) |
| **Open the boutique (phone)** | Before recording anything: the Owner's sheet (*Continue {yesterday}* selected, *Start {today} early*, the store's time, both dates, which date receives new sales and expenses, "Nothing already recorded moves to another day"), or — without the early start — a notice naming the day and that only the Owner may start today early, with Cancel; after 06:00 nothing is asked. `mode` sent only when chosen. The reopen sheet is the same component with its own words — unchanged behaviour |
| **`GET /home`** | `figures.comparison`: the invoiced sales value against the preceding window of equal length, `available: false` on a zero base |
| **Home** | `HomeHeader`: the shared `TabHeader` on one restrained svg tint, the bell, the store's calendar date (server's, informational), and before 06:00 "Sales still count for {yesterday} until 06:00"; sales value first with the range and the comparison (only when supplied; rounded whole percent, signed, worded), the compact chart (96 pt) under it, then cancellations / returns / net as before; Collected · Expenses · Still owed as three plain lines with their scope, no icon; one Daily closing entry (row → `/closing`, "Today · {standing}" or "{date} · {standing}" when the business day is not the calendar date, the *Yesterday needs review* chip); Top boutique, Latest phones + filtered Stock link, pending rows, five tabs, all gating and states kept; "{branch} · {period}" and "Ready when you are." dropped |
| **Rule 25a (`docs/04`)** | extended: before 06:00 the opening names its business day first |

## Verification

| Kind | Result |
|---|---|
| **The 03:41 records on live** (read-only) | `opened` 2026-09-25 nth 1 at 03:41 by the Owner; sales 00005/00006 business date 2026-09-25; the two expenses confirmation date 2026-09-25; no early start; the 25th unclosed. Consistent with rules 24a/25a and with the new flow's default. **No change made.** The exact optional correction is `docs/56` §1.3 |
| **The rules, built API on a fake clock, isolated copy** | **31 of 31** (`docs/56` §4.1): the choice at 03:41 (Owner both, seller *continue* only, seller's early start 403), `start_new` → two events + two audit rows, the 6th started early, the unclosed 5th *needs_review* everywhere, sales dated right and nothing moved, repeat taps inert, `continue` on record, 05:59:30 vs 06:00:30, a closed previous day → reopen with both choices, the comparison real |
| **The screens, read from the page** (web export) | **32 of 33** (`docs/56` §4.2): Home at 03:41 in EN/FR/AR at 320–430 pt, light/dark, 130 % text; the notice; the sheet in three languages with *Continue* selected (`aria-checked`); Continue and Start early through the sheet; 06:00:30 without a prompt; the closed day's reopen sheet unchanged. The one finding: the harness's own expectation on the Stock page |
| **Gates** | backend 95 specs green, `tsc` clean; mobile `tsc` clean, **75 pure suites**, i18n parity **3 202**, `expo lint` 0 errors (31 pre-existing warnings) |
| **Phone** | **Not run** — `docs/24` §44 |

## Data and process safety

- Live received nothing; the 03:41 records are untouched. The copy `prisma_verify_home` was rebuilt per run and
  **dropped**; 3012, 19012 and 9334 are free. The API on 3010 restarted on the new build (above); MySQL and Metro
  untouched. Scratch tooling in OS temp only; the three trees are clean.

## 🔴 Blockers and pending approvals

- **Native build blocker (pre-existing):** `npm install`'s postinstall fails — `expo-camera` 57.0.5 is installed but the
  Android scan-region patch was cut against 57.0.4. Expo Go is unaffected.
- `GET /closings/overview` under MySQL's default `sql_mode` (`ONLY_FULL_GROUP_BY`): not re-checked; live runs with
  `sql_mode=""`.
- **WhatsApp:** no provider adapter exists and none is faked; the closing templates await approved copy.
- **Deferred by instruction:** the control website (`docs/38`) is unchanged.

## 📋 Known, not fixed

- **A stored business date cannot be corrected from any screen** (the optional 03:41 correction of `docs/56` §1.3 would
  be a scripted, backed-up, approved change).
- **Only D−1 is checked for *Needs review*** (docs/51 limit): the 22nd's unclosed day is not announced.
- **The expense form kept `spent_on 2026-09-18`** across the 03:46 entries on the phone — the accounting day is the
  confirmation date, so the figures are right, but the form's remembered date is worth a look (expenses scope).
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
- On web, a screen pushed from a tab announces its back button as "(tabs), back". Dynamic type is handset-only.
- Prisma drift report: `units.identifier` is a stored generated column from 0008 that Prisma cannot model.
- `npx eslint .` over the whole app reports one pre-existing error in `scripts/verify-native-patch.js` (`__dirname`),
  outside `expo lint`'s scope. The backend has a `lint` script but no ESLint configuration.

## The next exact action

1. **Phone:** reload Expo Go (`exp://192.168.100.3:8081`) and run `docs/24` §44 U1–U11 — Home's header, date and
   before-06:00 note; the opening sheet as the Owner and the notice as a store employee **before 06:00 by the
   boutique's clock**; Continue, Start early, repeat taps, the 06:00 boundary, a closed previous day's reopen; FR/AR,
   320 pt, large text — then §43 T1–T13 and the older backlog. No sample record on the live store unless the user
   asks; a real opening before 06:00 records a real event.
2. If the Owner says the 03:41 records were meant for 26 September: the scripted correction of `docs/56` §1.3, after
   a backup per `docs/22`, on written approval only.
3. When the WAMP service is wanted back: stop the session MySQL (`mysqladmin -uroot --protocol=tcp -P3306 shutdown`),
   then start `wampmysqld64` from an elevated prompt or the WAMP tray.
4. Fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy.
