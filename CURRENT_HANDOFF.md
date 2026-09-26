# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Owner: **CLAUDE-A**
- `started_at_utc: 2026-09-26T03:28Z` — takeover HEADs (all clean, level with `origin` after a fetch): docs `eab5b75` ·
  backend `9a1155a` · mobile `2b3b739`; live at 0081. MySQL (session process), the API on 3010 and Metro still running.
- **Active phase and scope (the user's brief of 2026-09-26, Home / Money / Home → Receive; no pictures, no live
  purchase):** the review sheet's Close control at least 48 points; the review checked with a partly corrected and
  excluded 100-phone draft — corrections surviving navigation, the footer totals right — and any difference from the
  fresh-file performance run reported; commit; handoff.
- Next intended action: the sheet's Close, then the corrected-draft scenario on the isolated copy.
- Last session: **CLAUDE-A**, `started_at_utc: 2026-09-26T01:38Z` — **Home/Money follow-up and the imported-stock
  review**: the French tab label at 320 points, Money's today-only figures kept by the 0074 decision and their hints
  naming the day, Home and Money links and error states verified, and the review of the 100-phone workbook measured
  stage by stage, its bottleneck (the views a row mounts) fixed, its filters, footer and native text hardened
  (`docs/55`, `docs/21` "Home/Money follow-up"). Takeover HEADs were docs `21168a3` · backend `9a1155a` · mobile
  `056bb6e`. No backend change; no migration; nothing written to live.
- **Running — started by CLAUDE-A after the 2026-09-25 shutdown, left running for the phone check:**
  - **MySQL as a session process** (pids 9440 → 14604, port 3306) with the WAMP service's own configuration
    (`C:/Users/HP/AppData/Local/Temp/claude/session-my.ini`: `sql_mode` empty, `utf8mb4_unicode_ci`, no binary log).
    The WAMP service `wampmysqld64` is **Stopped** and cannot be started from the non-elevated shell. **Before
    starting the service, stop this process:** `mysqladmin -uroot --protocol=tcp -P3306 shutdown`.
  - **The API on 0.0.0.0:3010** (pid 14576) from `backend/dist` built from `9a1155a`; log
    `C:/Users/HP/AppData/Local/Temp/claude/api-3010.log`. The phone has not called it since the restart.
  - **Metro on 0.0.0.0:8081** (pid 7632, launcher 14128), `expo start --clear` in `mobile/`; log
    `C:/Users/HP/AppData/Local/Temp/claude/metro-8081.log`. It serves the working tree, i.e. mobile `2b3b739`.
- Next intended action: **the phone** (`docs/24` §43 T1–T11, then §42, §41 and the older backlog). Reload Expo Go
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
| `erp-mobile` | `reports-export` | **`2b3b739`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

This phase: mobile `6ca8ab1` (compact tab label below 360 pt), `99c5b69` (i18n), `5c3adae` (Money's hints name the day;
the reply check requires `today`), `46bdeb9` (dev-build stage timings), `2b3b739` (the review: light row actions,
filters in view, the footer, native text shrink); docs `docs/55` (new), `docs/21`, `docs/24` §43, the session log and
this file.

## What changed (no schema change, no data change)

| Where | Now |
|---|---|
| **Tab bar** | Below 360 points the label is the compact 10-point token; "Partenaires" fits at 320 (D43) |
| **Money** | Accounts today and Daily expenses stay today's, by the 0074 decision — no period totals were agreed, none added; both hints name the business day: "Today only (26 Sep 2026) — …", "…each account today (26 Sep 2026)…" (D42) |
| **Imported-stock review** | Accept / Edit / Exclude / Include again are light named actions, 48 pt, no icon, no animation library (D44); the four filters wrap into view at 320 pt, each 48 pt (D45); the footer: ready · total beside "N remain" (amber) or "Left out N", Continue disabled exactly as before, payment reached only through it (D46); texts in a row may shrink so a name, count or amount cannot run past a phone's row edge; the group's name keeps ≥ half its row (D47) |
| **Development build** | `[timing]` lines for parse, first list, filter, group opened, change applied and each draft write, forwarded by Expo Go to Metro; nothing in production (D48) |

## Verification

| Kind | Result |
|---|---|
| **The 100-phone workbook** (real parse on the copy; web export with temporary counters; CPU 4× throttled; before → after) | 100 entries, 10 groups, 70 unknown / 30 ambiguous. Parse 82 → 71 ms; first render 593 → **402**; filter 114 → 56; **expand 754 → 308**; edit 778 → 461; exclude 108 → no long task; scroll 78 → 70 (0 row re-renders); DOM open group 499 → 333. Profile: layout/paint 1 009 → 650 ms on expand, script flat. Draft path negligible in JS (43 KB, 0.08 ms stringify, 0.7 ms guard). After each run: 100 entries, the correction and exclusion intact, "0 ready · 0 MRU", Continue disabled |
| **Review pages read, no pictures** | 21 of 21 clean (EN/FR/AR, 320/393, light/dark, 130 % text; collapsed, open, filtered, sheet, excluded); no clipped element, no control under 48 pt but the sheet's own Close |
| **Money and Home pages** | 29 of 29 clean: the dated hints (with an account paid today, an expense today, rent due tomorrow not listed); View all sales, View all expenses, Add expense, Results, Daily closing, Outstanding payments; older-server and failed-server states on the overview, sales by day and Home; "Partenaires" whole at 320 in French |
| **Gates** | mobile tsc clean · **74 pure suites** · parity 3 187 · `expo lint` 0 errors (33 pre-existing warnings); backend untouched |
| **Phone** | **Not run** — `docs/24` §43 |

## Data and process safety

- Live received nothing. The copy `prisma_verify_home` was rebuilt per run and **dropped**; 3012, 19012 and 9334 are
  free; the temporary instrumentation never reached a commit (the file was restored from its saved clean copy).
- MySQL (session process), the API on 3010 and Metro are running for the phone check (above).

## 🔴 Blockers and pending approvals

- **Native build blocker (pre-existing):** `npm install`'s postinstall fails — `expo-camera` 57.0.5 is installed but the
  Android scan-region patch was cut against 57.0.4. Expo Go is unaffected.
- `GET /closings/overview` under MySQL's default `sql_mode` (`ONLY_FULL_GROUP_BY`): not re-checked; live runs with
  `sql_mode=""`.
- **WhatsApp:** no provider adapter exists and none is faked; the closing templates await approved copy.
- **Deferred by instruction:** the control website (`docs/38`) is unchanged.

## 📋 Known, not fixed

- The review's **draft** is still the whole batch (43 KB) on every change — measured negligible in JavaScript; its
  native write is the one part not measurable off the phone.
- The design-system **sheet's Close** is a 36-point icon button (every sheet).
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

1. **Phone:** reload Expo Go (`exp://192.168.100.3:8081`) and run `docs/24` §43 T1–T11 — the review on the 100-phone
   workbook with the `[timing]` lines from the Metro terminal as the handset's figures — then §42 N1–N10, §41 N1–N8,
   §40 L1–L6 and the older backlog. No sample record on the live store unless the user asks.
2. When the WAMP service is wanted back: stop the session MySQL (`mysqladmin -uroot --protocol=tcp -P3306 shutdown`),
   then start `wampmysqld64` from an elevated prompt or the WAMP tray.
3. Fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy.
