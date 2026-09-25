# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Owner: **CLAUDE-A**
- `started_at_utc: 2026-09-25T06:43Z` — takeover HEADs (all clean, level with `origin` after a fetch): docs `2695f99` ·
  backend `cdbf404` · mobile `40a9b2f`; live at 0080 (`migrate status` up to date at 06:12Z). The WAMP MySQL service
  is running and is used as it is; the user's API (3010) and Metro (8081) are not running. The handoff below matched.
- **Active phase and scope (the user's brief of 2026-09-25, daily totals reliability only, no workflow, no pictures):**
  make every request to recalculate the daily figures durable — written in the same transaction as the change, retried
  after a stop or a failure, never counting a sale twice; cover every transaction type that changes daily figures; test
  a stop and a failure between commit and recalculation and prove Results and goals recover; document the days that
  could still be stale with a separate, exact repair plan. The 388 340 repair and live historical totals: untouched.
- **Checkpoint 2026-09-25T07:33Z — migration 0081 is on live.** Backup
  `~/erp-backups/phonestore-before-0081-20260925-071413.sql` (879 111 B, trailer present, 0 raw binary) →
  restore-proved into `prisma_verify_home` (91 tables / 26 triggers, counts and the `units` checksum equal) → 0081
  rehearsed and re-run (idempotent) → `prisma migrate deploy` on live at `2026-09-25T07:32:20Z` (`migrate status` up
  to date). Live read back: 9 sales / 53 units / 865 audit rows / 9 payments / 1 closing / 6 rollups / 0 corrections /
  63 permissions / 0 rollup requests; 92 tables / 26 triggers; `units` and `daily_rollups` checksums unchanged — no
  historical total touched. Verified on the copy: `rollup-durability` lifecycle 22/22; the stale-day audit (3 days)
  and its repair rehearsed on a copy (0 stale after); backend 155 suites. Code still uncommitted at this checkpoint.
- Next intended action: commit backend, write `docs/52`, `docs/21`, the session log and this handoff, drop the copies
  `prisma_verify_home` and `prisma_verify_drift`.
- Previous session: **CLAUDE-A**, `started_at_utc: 2026-09-25T05:38Z`, closed `2026-09-25T06:22Z`. Takeover HEADs were
  docs `bff3cb6` · backend `b091286` · mobile `9130a9c` (all clean, level with `origin` after a fetch); the previous
  handoff (`READY_FOR_HANDOFF`, owner `NONE`) matched the repositories and live (0079, up to date). Its recorded close
  time (05:45Z) was late: that commit was at 05:33:57Z.
- **Completed phase: a cancellation in its own period — the units-sold goal, Home, the Daily closing and Results
  (migration 0080).** Decision record with the expected-and-actual table: `docs/21` "A cancellation in its own
  period"; plan, decisions D21–D24, formulas and risks: `docs/51` §16; rule 28 in `docs/04` §F; device checks:
  `docs/24` §40 L1–L6.
- Authorisation: the user's follow-up (Daily closing scope, no workflow, no pictures) — the units-sold goal reverses a
  cancelled sale's units in the appropriate reporting period; Home shows the original sale and its later cancellation;
  the totals across both dates reconcile with the Daily closing and Results; focused tests for the same day and a later
  business day; earlier closing snapshots immutable; the 388 340 repair untouched.
- **The WAMP MySQL service is RUNNING** (started by the user at 05:39:37Z) and was left running. The user's API (3010)
  and Metro (8081) were not running and were not started.
- Next intended action: **the handset runs** — `docs/24` §40 L1–L6 and §39 K1–K14 first, then §38 R1–R14, §37
  (H1–H10, C1–C16), §36, §35 and the older backlog, against the live API in Expo Go. No feature is next.

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed by this phase.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`cdbf404`** | level | 0 |
| `erp-mobile` | `reports-export` | **`40a9b2f`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

This phase's backend commits, in order: `ceba0ed`, `cdbf404`. Mobile: `8cd38ff`, `40a9b2f`. Docs during the phase:
`903da43`, `147baff`, then this commit. Every one is on `origin`. Earlier phases: backend `2b7ba08`, `2c98658`,
`b091286` (0079), `42bfd76`, `ff531dd`, `e352cf3`, `f4c3381` (0078); mobile `a9b9226`, `9130a9c` (0079), `8346398`,
`7ed67bc`, `1e316e9` (0078).

## What changed

| Commit | Where | In one line |
|---|---|---|
| backend `ceba0ed` | `prisma/migrations/0080_cancelled_units`, `schema.prisma`, `src/analytics/rollup.service.ts`, `src/goals/goal-progress.ts`, `src/goals/goals.service.ts`, goal and reader specs | `daily_rollups.cancelled_qty` (guarded, backfilled); the rollup writes it on the correction day; the units-sold goal subtracts it; a personal goal counts the seller's sales on their business date and takes off the seller's sales cancelled in the period |
| backend `cdbf404` | `src/analytics/dashboard.service.ts`, `src/closing/closing-report.ts` + `.queries.ts`, `closing-report.spec.ts`, `src/analytics/cancellation-periods.spec.ts` (new) | Home's `figures.cancellations {count, value, phones}` keyed on the approval day; the Daily closing's `sales.cancellations.items`; the focused spec for both scenarios |
| mobile `8cd38ff` | `app/(tabs)/index.tsx`, `lib/home.ts`, `app/closing/index.tsx`, `lib/closing-report.ts`, i18n, `lib/layout.test.ts` | Home's "Sales cancelled in this period (n)" line under the sales value; "Sales cancelled (1 · 3 items)" on the Daily closing |
| mobile `40a9b2f` | `app/money.tsx`, `lib/results.ts`, `lib/analytics-summary.ts`, i18n, `lib/layout.test.ts` | Results' breakdown: "Cancelled sales" and "Net sales", so it adds up; a period holding only a cancellation or a return is not "No sales or expenses" |
| docs (this commit) | `docs/51` §16, `docs/04` rule 28, `docs/21`, `docs/24` §40, `SESSION_LOG.md`, this file | the plan and decisions, the rule, the decision record with the figures, the device checks, the session entry |

## Verification

| Kind | Result |
|---|---|
| **Backend gate** | tsc clean · `nest build` clean · `prisma validate` · `migrate status` up to date (0080) · full suite **154 suites / 2 771 tests, 0 failed** (new `cancellation-periods.spec` 13 — fails 4 against the old units rule) |
| **Lifecycle (isolated copy, built API, fake clock)** | `cancellation-lifecycle.mjs` **31/31 steps, 106/106 figures as expected** — the same day (2026-10-06) and a later day (sold and closed 2026-11-09, cancelled 2026-11-10): Home, the units-sold goal (branch and personal), the other goals, the Daily closing and Results each against figures written before the run, raw SQL agreeing, D1's stored close byte-identical; the 0079 lifecycles re-run: corrections **40/40**, report **45/45** |
| **Migration 0080** | backup `~/erp-backups/phonestore-before-0080-20260925-055659.sql` (878 859 B, trailer present, 0 raw binary) → restore-proved into `prisma_verify_home` (91 tables / 26 triggers, counts and the `units` checksum equal) → 0080 rehearsed and re-run (idempotent) → **applied to live at `2026-09-25T06:12:46Z`** |
| **Mobile gate** | tsc clean · `expo lint` 0 errors (33 warnings, all pre-existing) · **70 pure suites pass** · parity **3 163** keys (3 added, 1 retired) · web export |
| **Render checks (no pictures)** | **35 views, 0 problems** — Home (7 days, Today), the Daily closing, Results (This month, Today) in EN/FR/AR, light and dark, 320 and 393 pt, 130 % text, plus five views that pass only with the right period's amounts. Web renders, not device verification |
| **Physical device** | 🔴 **not run** — `docs/24` §40 L1–L6 (and §39, §38, §37, §36, §35) |

## Data and process safety

- **Live `phonestore` received exactly one change from this phase: migration 0080**, after the backup and its
  restore-proof. Read back: 9 sales / 53 units / 865 audit rows / 9 payments / 1 closing / 6 rollups (`cancelled_qty`
  all 0) / 0 corrections / 63 permissions; 91 tables / 26 triggers; latest `0080_cancelled_units`; `units` checksum
  unchanged. No sample record written to live, no message sent. Live holds no stored close event, so no closed day
  reads differently (adding the cancelled items changes the report's version).
- Every other write went to the copy `prisma_verify_home`, rebuilt from the backup before each run and **dropped at
  close-out**.
- The known **388 340.00 rollup overstatement is untouched** and still awaits the approved repair.
- Processes started here and stopped: the isolated API (3012), the static server (19012), headless Chrome (9334, own
  profile, removed) — all free at close-out. A session `mysqld` launched before the running service was noticed exited
  at once without touching it.
- Scratch tooling lives in the OS temp directory only; no file holding a token or a credential was written inside
  any repository.

## 🔴 Blockers and pending approvals

- **Native build blocker (pre-existing):** `npm install`'s postinstall fails — `expo-camera` 57.0.5 is installed but the
  Android scan-region patch was cut against 57.0.4. Expo Go is unaffected.
- **Live rollup repair — still awaiting approval (NOT applied).** Audit shows `Sale create` ×28 on 2026-09-10 and ×4 on
  2026-08-08 with no surviving sales; rollups for those days overstate revenue by **388 340.00**. Procedure: backup per
  `docs/22` → `DB=phonestore node scripts/rollup-audit.js` (confirm exactly 2 rows) → `… --repair`.
- `GET /closings/overview` under MySQL's default `sql_mode` (`ONLY_FULL_GROUP_BY`): not re-checked; live runs with
  `sql_mode=""`.
- **WhatsApp:** no provider adapter exists and none is faked; the closing templates await approved copy.
- **Deferred by instruction:** the control website (`docs/38`) is unchanged.

## 📋 Known, not fixed

- **The rollup queue is in-process and fire-and-forget:** if the API stops right after a sale, that day's rollup can
  miss it until the day is recomputed — Results and branch goals then read low (the Daily closing and Home read the
  sales directly). Seen on the copy; the same family as the 388 340 overstatement.
- The **Money tab**'s period figures and the **Analytics** screen's best sellers and employee performance still count a
  cancelled sale on the day it was sold, with no cancellation line.
- Goals do not deduct returns; Home's expenses are not net of 0079 expense reversals.
- A goal whose period holds only a cancellation reads below zero (intended, `docs/51` D21); the phone's bar is empty.
- **Corrections not available, by name:** reversing a purchase payment as "not paid" (cancel the purchase instead);
  editing a sale line or cancelling part of a sale (cancel and sell again); a sale with a return (correct it on the
  return); a purchase whose goods have moved (correct the later record first). Reassigning a stored business date is
  still an Owner correction that does not exist.
- The approval audit's `before` is the full preview (`$.payment.method`, `$.move`, …) since 0079.
- Loans, consignment and employee-debt cash are outside the report, as they are outside the closing.
- Rollup revenue, the digest and Results still leave out the whole-sale discount; the report reads `sales.total`.
- Expense and refund confirmations check the day's lock without taking the closing row's lock.
- Returns and refund flows in the report are proved by pure and service tests, not by the real-database lifecycle.
- Selling a phone outright to another store is still the documented contract gap in the partner ranking.
- The Stock tab's own list shows full identifiers (rule 19d); the list reached from Home masks.
- Filter chips are 36 pt tall by design-system decision, with hit slop restoring a 48 pt target.
- Two scripts logging in the same user concurrently deadlock on `users.last_login`; harmless for one phone.
- On web, a screen pushed from a tab announces its back button as "(tabs), back". Dynamic type is handset-only.
- Prisma drift report: `units.identifier` is a stored generated column from 0008 that Prisma cannot model.
- `npx eslint .` over the whole app reports one pre-existing error in `scripts/verify-native-patch.js` (`__dirname`),
  outside `expo lint`'s scope.

## The next exact action

1. Start the user's API (3010) and Metro (8081) on the running MySQL service.
2. **Handset:** `docs/24` §40 L1–L6 — a sale cancelled the same day and on a later day: Home's cancelled line (Today,
   7 days), the Daily closing's "Sales cancelled (1 · 3 items)", Results' "Cancelled sales" and "Net sales", the
   units-sold goals for each day and both; then §39 K1–K14 (delegates and every correction sheet) — on the physical
   phone against the live API (Expo Go). No sample record on the live store unless the user asks.
3. Then `docs/24` §38 R1–R14, §37 H1–H10, C1–C16, §36 P1–P15, §35 S1–S15 and the older backlog (§34 … §30).
4. Decide the live rollup repair; fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy.
