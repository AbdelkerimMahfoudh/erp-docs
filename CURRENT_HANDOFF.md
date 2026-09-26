# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Owner: **CLAUDE-A**
- `started_at_utc: 2026-09-26T04:43Z` — takeover HEADs (all clean, level with `origin` after a fetch): docs `2b4ad31` ·
  backend `9a1155a` · mobile `578df5d`; 80 migrations, database up to date. MySQL (session process), the API on 3010
  and Metro still running.
- **Active phase and scope (the user's brief of 2026-09-26; Home, Daily closing reached from Home, and their direct
  data and navigation dependencies; no pictures, no page redesign beyond Home):** (1) investigate the real opening at
  ~03:41 boutique time on 26 Sep 2026 and the two sales and two expenses that followed — timestamps, business dates,
  branch, the opening event — and report; no silent reassignment; any correction proposed for review first.
  (2) The pre-06:00 Open the boutique flow: the date choice before the opening is recorded — Continue the previous
  business day selected by default, Start the new business day early as the explicit alternative — with exact dates
  and boutique-local time, which date receives new transactions, what a staff member without early-start permission
  sees, the choice preserved on Reopen, the opening recorded with actor, timestamp, business date and audit history,
  an unclosed previous day kept visible as needing review, no transactions moved. (3) The approved simple Home design
  on the working behaviour. (4) EN/FR/AR RTL, light/dark, 320–430 pt, large text, real navigation; the 03:41 choice,
  staff permission, repeat taps, closed and unclosed previous day, the 06:00 boundary — on an isolated database.
- Next intended action: read the live opening event and the business-date rules; report; then the plan.
- Last session: **CLAUDE-A**, `started_at_utc: 2026-09-26T03:28Z` — **the review sheet's Close at 48 points and the
  corrected-draft check** (Home / Money / Home → Receive scope; no pictures, no live purchase): the design-system
  sheet's Close is the touch minimum (D49); the review checked with a partly corrected and excluded 100-phone draft —
  the footer totals matched an independent count at every step, corrections and exclusions survived navigation and
  restore, no purchase posted — and measured against the fresh file (no cost to the corrected state); on the way,
  Match product offered only where a choice exists (D50) and the "Corrected" caption only when the cost changed (D51)
  (`docs/55` §6, `docs/21` addendum). Takeover HEADs were docs `eab5b75` · backend `9a1155a` · mobile `2b3b739`.
  No backend change; no migration; this session wrote nothing to live.
- **Live moved by the user's hand during this session:** the phone (192.168.100.251) used the API on 3010 from
  03:41Z to 04:05Z — sign-in, `devices/adopt`, `closings/open`, **two `POST /sales` at 03:44 and two `POST /expenses`
  with their confirmations at 03:46** (all 201), then Home, Money, the closing's view/report/overview and inventory.
  Live (`phonestore`) now holds **13 sales** (11 + today's 2) and **7 expenses** (5 + today's 2).
- **Running — started by CLAUDE-A after the 2026-09-25 shutdown, left running for the phone:**
  - **MySQL as a session process** (pid 14604, port 3306) with the WAMP service's own configuration
    (`C:/Users/HP/AppData/Local/Temp/claude/session-my.ini`: `sql_mode` empty, `utf8mb4_unicode_ci`, no binary log).
    The WAMP service `wampmysqld64` is **Stopped** and cannot be started from the non-elevated shell. **Before
    starting the service, stop this process:** `mysqladmin -uroot --protocol=tcp -P3306 shutdown`.
  - **The API on 0.0.0.0:3010** (pid 14576) from `backend/dist` built from `9a1155a`; log
    `C:/Users/HP/AppData/Local/Temp/claude/api-3010.log`. The phone reaches it (above).
  - **Metro on 0.0.0.0:8081** (pid 7632, launcher 14128), `expo start --clear` in `mobile/`; log
    `C:/Users/HP/AppData/Local/Temp/claude/metro-8081.log`. It serves the working tree, i.e. mobile `578df5d`.
- Next intended action: **the phone** (`docs/24` §43 T1–T13, then §42, §41 and the older backlog). Reload Expo Go
  (`exp://192.168.100.3:8081`); the review's own timings appear as `[timing]` lines in the Metro terminal.

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed by this phase.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`9a1155a`** — untouched this phase | level | 0 |
| `erp-mobile` | `reports-export` | **`578df5d`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

This phase: mobile `925fb22` (the sheet's Close at 48 pt), `578df5d` (Match product only where a choice exists; the
Corrected caption only when the cost changed; pins). The phase before, same day: `6ca8ab1`, `99c5b69`, `5c3adae`,
`46bdeb9`, `2b3b739` (`docs/55` §1–§5). Docs: `docs/55` §6, `docs/21` addendum, `docs/24` §43 T12–T13, the session
log and this file.

## What changed (no schema change, no data change)

| Where | Now |
|---|---|
| **Every sheet** | Close is a 48-point target (was 36) (D49) |
| **Imported-stock review** | Match product appears only on a group whose phones share a candidate, and Match products opens the first such group — the seven "No product match" groups no longer offer a sheet that can only say nothing matches (D50); a row says "Corrected. The file said …" only when its cost was corrected, not for a product choice (D51). From the phase before: light named row actions (D44), the four filters wrapping into view at 48 pt (D45), the footer's ready · total beside "N remain" / "Left out N" with Continue disabled exactly as before (D46), native text that shrinks (D47), `[timing]` lines in the development build (D48) |
| **Tab bar / Money** | Unchanged this phase: the compact 10-pt label below 360 pt (D43); Accounts today and Daily expenses today-only by 0074, hints naming the day (D42) |

## Verification

| Kind | Result |
|---|---|
| **The corrected and excluded 100-phone draft** (isolated copy, the real controls, CPU 4× throttled, 24 of 24 steps) | Fresh 0 ready · 100 remain → Match product on the first group with a choice: 10 ready · 165 000 · 90 remain → two costs corrected: 164 000 → three rows excluded: 87 remain, three Include again. Leave for Home and back: unchanged, both captions and all three exclusions kept; the store cleared ("Nothing to check") and restored: unchanged. Exclude all → "Left out 90", Continue enabled only then; the payment step "Paying now for 10 phones", back: unchanged; one Include again → 1 remain, Continue disabled. Close 48 × 48; closing lands on the same open group. `POST /purchases`: none |
| **Fresh file vs the corrected draft, same session** | expand 671 → 500 ms (corrected group 367); filter 308 → 151; edit 1 037 → 553; scroll 60 → no long task; DOM 369 → 392/368. No cost to the corrected state; this session's machine was slower than the one behind `docs/55` §3.4 (fresh first render 1 531 vs 402), so only same-session figures compare |
| **Gates** | mobile tsc clean · **74 pure suites** (`review-screen.test` 9) · parity 3 187 · `expo lint` 0 errors (33 pre-existing warnings); backend untouched |
| **From the phase before** | Review pages 21 of 21 clean; Money and Home 29 of 29; the workbook's before/after timings (`docs/55` §3–§4) |
| **Phone** | **Not run by this session** — `docs/24` §43 T1–T13. The user opened Home, Money and the closing on the phone and posted two sales and two expenses without an error reply |

## Data and process safety

- This session wrote nothing to live; the user's phone did (above). The copy `prisma_verify_home` was rebuilt per run
  and **dropped**; 3012, 19012 and 9334 are free; the temporary instrumentation never reached a commit (the file was
  restored from its saved clean copy; the mobile tree is clean at `578df5d`).
- MySQL (session process), the API on 3010 and Metro are running for the phone (above).

## 🔴 Blockers and pending approvals

- **Native build blocker (pre-existing):** `npm install`'s postinstall fails — `expo-camera` 57.0.5 is installed but the
  Android scan-region patch was cut against 57.0.4. Expo Go is unaffected.
- `GET /closings/overview` under MySQL's default `sql_mode` (`ONLY_FULL_GROUP_BY`): not re-checked; live runs with
  `sql_mode=""`.
- **WhatsApp:** no provider adapter exists and none is faked; the closing templates await approved copy.
- **Deferred by instruction:** the control website (`docs/38`) is unchanged.

## 📋 Known, not fixed

- **Resuming a half-checked delivery** after the app was killed means picking the same file again on Receive — the
  saved draft then replaces the fresh read (and would replace a *different* file's read until discarded). Receive could
  offer "Continue the delivery you were checking"; a product decision, not taken here.
- The review's **draft** is still the whole batch (43 KB) on every change — measured negligible in JavaScript; its
  native write is the one part not measurable off the phone.
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
  return); a purchase whose goods have moved (correct the later record first). Reassigning a stored business date is
  still an Owner correction that does not exist.
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

1. **Phone:** reload Expo Go (`exp://192.168.100.3:8081`) and run `docs/24` §43 T1–T13 — the review on the 100-phone
   workbook with the `[timing]` lines from the Metro terminal as the handset's figures, the sheet's Close, and a
   partly corrected draft resumed after a kill — then §42 N1–N10, §41 N1–N8, §40 L1–L6 and the older backlog. No
   sample record on the live store unless the user asks.
2. When the WAMP service is wanted back: stop the session MySQL (`mysqladmin -uroot --protocol=tcp -P3306 shutdown`),
   then start `wampmysqld64` from an elevated prompt or the WAMP tray.
3. Fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy.
