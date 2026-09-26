# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Owner: **CLAUDE-A**
- `started_at_utc: 2026-09-26T01:38Z` — takeover HEADs (all clean, level with `origin` after a fetch): docs `21168a3` ·
  backend `9a1155a` · mobile `056bb6e`; live at 0081 (11 sales). Running, started by this account after the shutdown:
  MySQL as a session process (3306), the API on 3010 from `9a1155a`, Metro on 8081.
- **Active phase and scope (the user's brief of 2026-09-26; no pictures; physical-phone checks left for the user's
  final test):** the 320-pt "Partenaires" tab clipping; Money's today-only expenses and account movements checked
  against the recorded decisions (period totals only if agreed; labels explicit); Home and Money links and error
  states verified; and the imported-stock review reached from Home → Receive: the 100-phone workbook reproduced on the
  current build, clipped names/counts/amounts fixed, the horizontal filters made clearly usable, the pinned footer
  tidied, the lag measured per stage (parse, first render, filter, expand, edit, scroll, draft save) and the measured
  bottleneck fixed, all 100 items and their corrections kept, unresolved rows never hidden, payment never enabled
  while items need review; timings before and after.
- Next intended action: instrument and measure the review screen on the current build (the "before"), then the
  Money labels and the tab fix.
- Last session: **CLAUDE-A**, `started_at_utc: 2026-09-25T09:16Z` — **Home completed**: a whole-invoice discount
  agreeing everywhere, Home in the store's time, Home's sales block, links, refresh, permissions and narrow layout, the
  revenue goal renamed, movement labels read live, the units-sold goal less returned units, and an older server shown
  as a notice instead of a crash (`docs/54`, `docs/21` "Home completed"). Takeover HEADs were docs `9ef563c` · backend
  `5acab28` · mobile `73fee6d`. No migration; nothing of this work wrote to live.
- **The PC shut down** during the documentation (2026-09-25); on 2026-09-26 the docs edits were found whole and kept,
  backend and mobile clean and level, and the services were brought back (below).
- **Running now — started by CLAUDE-A, left running for the phone check:**
  - **MySQL as a session process** (pids 9440 → 14604, port 3306) with the WAMP service's own configuration
    (`C:/Users/HP/AppData/Local/Temp/claude/session-my.ini`: `sql_mode` empty, `utf8mb4_unicode_ci`, no binary log).
    The WAMP service `wampmysqld64` is **Stopped** and cannot be started from the non-elevated shell. **Before
    starting the service, stop this process:** `mysqladmin -uroot --protocol=tcp -P3306 shutdown`.
  - **The API on 0.0.0.0:3010** (pid 14576) from `backend/dist` built from `9a1155a`; log
    `C:/Users/HP/AppData/Local/Temp/claude/api-3010.log`.
  - **Metro on 0.0.0.0:8081** (pid 7632, launcher 14128), `expo start --clear` in `mobile/`; log
    `C:/Users/HP/AppData/Local/Temp/claude/metro-8081.log`.
- Next intended action: **the phone** — open Home in Expo Go (`exp://192.168.100.3:8081`) and confirm it opens
  (`docs/24` §42 N1); the API log shows the phone's `GET /api/v1/home` when it does. Then §42 N2–N10, §41, §40 and the
  older backlog.

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed by this phase.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`9a1155a`** | level | 0 |
| `erp-mobile` | `reports-export` | **`056bb6e`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

This phase: backend `3c3f629` (invoice-total shares), `75cc60f` (rollup, product report, digest), `c6b1bba` (return
refund), `a33f47e` (goals), `416268b` (movement), `da00ed2` (Home store time), `9a1155a` (specs); mobile `9969e2d`
(i18n), `d2ffcea` (calendar dates), `8272b33` (reply check), `3b96d1a` (Home), `056bb6e` (Analytics); docs `docs/54`
(new), `docs/53` (R6 and §4 settled), `docs/21`, `docs/24` §42, the session log and this file.

## What changed (no schema change, no data change)

| Where | Now |
|---|---|
| **Every reader** | A line is worth its share of the recorded invoice total: a whole-invoice discount reaches Results, branch and personal goals, branches, the product report and the digest (Results said 10 040 where Home said 9 040) |
| **Returns** | A returned line refunds its share of what the invoice charged (it refunded the list price: 10 000 for a phone paid 9 500) |
| **Goals** | Units sold less cancelled units less returned units, each on its approval day; the sales count unchanged; the revenue goal is named **Net sales** |
| **Home** | Arrivals in the store's time ("Today"/"Yesterday" by the store's calendar); Net sales under the gross value and adjustments; the chart says it plots sales as invoiced; Collected says it includes older debts; refresh within permissions; counter buttons stack below ~360 pt |
| **Every screen** | A bare date is the same calendar day on every phone (a day early west of UTC before) |
| **App vs server** | A reply missing a figure is refused whole: "This screen needs an updated server" — no crash, no zero |
| **Analytics** | Sold in 30 days / last sold / not moving read live from sales that stand (a cancelled sale left out, a return still sold); the rule stated; product names keep their width in Arabic |

Contract details: `docs/54` §3.

## Verification

| Kind | Result |
|---|---|
| **Scenarios on an isolated copy** (store at UTC+4 on the copy only; built API, fake clock) | `home-lifecycle` **42/42 steps, 37/37 screen checks expected = actual**; the same acts on the pre-phase build recorded the "before" (`docs/54` §5.1) |
| **Links and permissions** | ranking, Stock (same three phones, masked on Home only), closing card agree with their screens; store and warehouse employees see no money — hidden, not zero |
| **Rendered and read, no pictures** | 35 views EN/FR/AR, light/dark, 320/393 pt, 130 % text, and a server one version behind: 30 clean; 5 show only the French tab label "Partenaires" 2 pt too wide at 320 pt |
| **Regression on the new build** | docs/53 lifecycle 59/59 (units goals per D37) · Daily closing 45/45 · corrections 40/40 · cancellation 31/31 |
| **Backend** | tsc clean · **158 suites / 2 825 tests** |
| **Mobile** | tsc clean · **73 pure suites** · parity 3 187 · `expo lint` 0 errors (33 pre-existing warnings) |
| **Phone** | **Not seen** — the phone had not reached the final build before the shutdown; stack running for it now |

## Data and process safety

- Nothing of this work wrote to live. The user sold twice meanwhile (00003, 00004, no discount), rolled up by the
  running API; the new basis gives the same figures. Live now: 0081, 11 sales, 8 rollup requests done.
- The user's `npm run start` API chain was stopped by PID on the user's instruction and replaced by detached restarts
  (09:23Z on `5acab28`; after the commits on `9a1155a`; after the shutdown, pid 14576).
- The copy `prisma_verify_home` was dropped. 3012, 19012, 9334 free. Scratch tooling lives in OS temp only.

## 🔴 Blockers and pending approvals

- **Native build blocker (pre-existing):** `npm install`'s postinstall fails — `expo-camera` 57.0.5 is installed but the
  Android scan-region patch was cut against 57.0.4. Expo Go is unaffected.
- `GET /closings/overview` under MySQL's default `sql_mode` (`ONLY_FULL_GROUP_BY`): not re-checked; live runs with
  `sql_mode=""`.
- **WhatsApp:** no provider adapter exists and none is faked; the closing templates await approved copy.
- **Deferred by instruction:** the control website (`docs/38`) is unchanged.

## 📋 Known, not fixed

- **French tab label at 320 pt:** "Partenaires" needs 56 of 54 points on the web's font (the navigator's inner inset);
  check on the phone (`docs/24` §42 N9).
- **`product_velocity`** is no longer read or written — drop it in a later migration.
- **The Catalogue's "Last sold"** finds quantity lines only, so a phone never shows one (outside this scope).
- `closingHistory.title` is unused; the exports keep their movement headers.
- The Analytics **snapshot** (`today`/`month`, API only, on no screen) reads "today" as the UTC date.
- A count or a goal whose period holds only a cancellation or return reads below zero (intended); the goal's bar is empty.
- **Rollup recovery time:** a request whose recompute died mid-way waits for its lease (60 s) and the next sweep (30 s)
  — up to ~90 s after a restart. `done` requests are kept and not pruned; a failing request is visible only in
  `rollup_requests.last_error` and the log. One API process assumed (a second is safe by lease and retry).
- `scripts/rollup-audit.js` (revenue-only, `DATE(sold_at)`, existing rows only) is superseded by `rollup-drift.js`.
- **Corrections not available, by name:** reversing a purchase payment as "not paid" (cancel the purchase instead);
  editing a sale line or cancelling part of a sale (cancel and sell again); a sale with a return (correct it on the
  return); a purchase whose goods have moved (correct the later record first). Reassigning a stored business date is
  still an Owner correction that does not exist.
- The approval audit's `before` is the full preview (`$.payment.method`, `$.move`, …) since 0079.
- Loans, consignment and employee-debt cash are outside the report, as they are outside the closing.
- Expense and refund confirmations check the day's lock without taking the closing row's lock.
- Selling a phone outright to another store is still the documented contract gap in the partner ranking.
- The Stock tab's own list shows full identifiers (rule 19d); the list reached from Home masks.
- Filter chips are 36 pt tall by design-system decision, with hit slop restoring a 48 pt target.
- Two scripts logging in the same user concurrently deadlock on `users.last_login`; harmless for one phone.
- On web, a screen pushed from a tab announces its back button as "(tabs), back". Dynamic type is handset-only.
- Prisma drift report: `units.identifier` is a stored generated column from 0008 that Prisma cannot model.
- `npx eslint .` over the whole app reports one pre-existing error in `scripts/verify-native-patch.js` (`__dirname`),
  outside `expo lint`'s scope. The backend has a `lint` script but no ESLint configuration.

## The next exact action

1. **Phone:** open Home in Expo Go (`exp://192.168.100.3:8081`) — `docs/24` §42 N1; confirm in
   `C:/Users/HP/AppData/Local/Temp/claude/api-3010.log` that the phone's `GET /api/v1/home` answered 200. Then §42
   N2–N10, §41 N1–N8, §40 L1–L6 and the older backlog. No sample record on the live store unless the user asks.
2. When the WAMP service is wanted back: stop the session MySQL (`mysqladmin -uroot --protocol=tcp -P3306 shutdown`),
   then start `wampmysqld64` from an elevated prompt or the WAMP tray.
3. Fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy.
