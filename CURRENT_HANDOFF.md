# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Owner: **CLAUDE-A**
- `started_at_utc: 2026-09-25T08:21Z` — takeover HEADs (all clean, level with `origin` after a fetch): docs `7ddf674` ·
  backend `68c21e9` · mobile `40a9b2f`; live at 0081, up to date. The user's API (3010, from `backend/dist`) and Metro
  (8081) are running and are not touched; nothing is built into `backend/dist` while they run.
- **Active phase and scope (the user's brief of 2026-09-25, reporting consistency only, no workflow, no pictures, the
  completed three-day repair not rerun):** Money, Home, Analytics and goals follow the Daily closing's and Results'
  dated rules — a sale on its sale date and its cancellation as a negative adjustment on the approval date; an approved
  return on its approval date for revenue, profit and returned units, its refund moving money on the confirmation date
  with no second profit effect; a confirmed expense on its date and its reversal on the correction date, shown apart;
  sales count = invoices less whole-sale cancellations, a return a separate event, the definition stated where shown.
  Audit first; preserve original dates and closing snapshots; cost and profit stay gated; scenarios tested on a copy.
- Next intended action: the audit of every endpoint and rollup that feeds those screens.
- Previous session: **CLAUDE-A**, `started_at_utc: 2026-09-25T08:04Z`, closed `2026-09-25T08:06Z` — **documentation
  only**: `docs/52` §5 ("Completed on live, 2026-09-25") and `docs/21` ("Stale days on live — repaired 2026-09-25") now
  record the completed three-day repair — before/after figures, backup names, the zero-stale-day result, the date —
  with the procedure kept as the record of how it was done. No repair was run; no database or code change. Takeover HEADs
  were docs `52c1248` · backend `68c21e9` · mobile `40a9b2f` (all clean, level with `origin`).
- **Completed phase before it: the approved live daily-totals repair, Main Store only** (07:47Z–07:56Z). The three
  stale branch-days of `docs/52` §5 were recomputed through the durable queue — three `rollup_requests` rows
  (`repair_drift`) worked by the user's running API — exactly as documented; no sale, payment, expense, stock, audit row
  or closing snapshot was edited; the repair was not expanded. Its full record: `docs/52` §5 and the session log.
- Authorisation: the user's approval of 2026-09-25 (no workflow, no pictures) — a fresh restore-proved backup, the
  read-only `rollup-drift` comparison on a fresh copy showing exactly the three unclosed days with the reported
  differences (it did), the documented requests, a fresh-copy drift check → 0 stale, Main Store July–September Results
  revenue 10 051 MRU, source-record counts and checksums before and after.
- **The WAMP MySQL service is RUNNING** and the **user's API is running on 3010** (started by the user at 07:45:14Z
  from `backend/dist`, built from `68c21e9`); neither was restarted or touched. Metro (8081) is not running.
- Next intended action: **the handset runs** — `docs/24` §40 L1–L6 and §39 K1–K14 first, then §38 R1–R14, §37, §36,
  §35 and the older backlog, against the live API in Expo Go. No feature is next.

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed by this phase.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`68c21e9`** — no code change this phase | level | 0 |
| `erp-mobile` | `reports-export` | **`40a9b2f`** — untouched | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

Docs: the repair `91c1f24`, `52c1248`; its record in `docs/52` and `docs/21` `6c47a0b`, then this commit. Earlier:
backend `97695a8`, `68c21e9` (0081, the drift audit),
`ceba0ed`, `cdbf404` (0080); mobile `8cd38ff`, `40a9b2f` (0080).

## What changed (data only, through the production recompute)

| Branch-day (Main Store) | Before | After | Product facts |
|---|---|---|---|
| 2026-07-30 | **no rollup row** | revenue 9 051.00 · cost 6 232.80 · gross profit 2 818.20 · 6 sales · 35 units · expenses 500.00 (cash 500.00, 1) · net profit 2 318.20 | 9 rows (35 units, 9 051.00) already present — rebuilt with the same values |
| 2026-08-08 | revenue 40.00 · cost 8.20 · gross profit 31.80 · 1 sale · 2 units · net 31.80 | all zero | its 1 row (2 units, 40.00) removed |
| 2026-09-10 | revenue 388 300.00 · cost 60 000.00 · gross profit 328 300.00 · 6 sales · 6 units · net 328 300.00 | all zero | none, before or after |

Every other rollup row and product fact is byte-identical to before. `rollup_requests`: 3 rows, `repair_drift`,
submitted 07:52:36Z, `done` at 07:52:53Z, attempt 1, no error.

## Verification

| Kind | Result |
|---|---|
| **Backup before** | `~/erp-backups/phonestore-before-rollup-repair-20260925-075114.sql` (881 146 B, trailer present, 0 raw binary) → restored into `prisma_verify_home`: 92 tables / 26 triggers, and **all 25 fingerprinted tables identical to live row for row** |
| **Drift before (fresh copy of that backup, live read only)** | 7 branch-days, **3 stale**, all Main Store, none closed — the same days and differences as reported: 07-30 no row (recomputed 9 051.00 · 500.00 expense), 08-08 40.00 → 0.00, 09-10 388 300.00 → 0.00 |
| **Source records, before → after** | 22 tables, row count and whole-row checksum each **unchanged**: sales 9 · sale_items 16 · payments 9 · expenses 4 · purchases 10 · purchase_items 21 · supplier_payments 1 · units 53 · stock_items 18 · audit_logs 865 · daily_closings 1 · closing_channel_counts 1 · users 14 · branches 3; returns, refunds, corrections, legs, transfers, closing events and customers 0 · derived: `daily_rollups` 6 → 7, `product_daily_rollups` 16 → 15, `rollup_requests` 0 → 3 |
| **Backup after** | `~/erp-backups/phonestore-after-rollup-repair-20260925-075339.sql` (882 058 B, trailer present, 0 raw binary) → restored: 92 / 26, identical to live on all 25 tables |
| **Drift after (fresh copy of that backup)** | 7 branch-days, **0 stale** |
| **Results, Main Store, 2026-07-01 → 2026-09-30** | **10 051 MRU** (gross = net; gross profit 3 018.20; expenses 500; net operating 2 518.20) — through the real `analytics/summary` endpoint on the post-repair copy, and the same from live's own rollups (4 rows). Per day: 07-30 9 051 · 08-08 0 · 09-10 0. Before the repair the same window read 389 340 |

## Data and process safety

- Live received exactly **three `rollup_requests` rows**; the user's running API recomputed the three branch-days with
  the production code. No source record changed (checksums above). No closing, no audit row, no sale touched.
- Every other write went to the copies `prisma_verify_home` and `prisma_verify_drift` (throwaway credentials on the
  copy only, for the Results endpoint), **dropped at close-out**. Live was never signed into.
- Processes started here and stopped: the isolated API on 3012 (against the copy). 3012, 19012, 9334 free. The user's
  API and the MySQL service were left running. Scratch tooling and fingerprints live in the OS temp directory only.

## 🔴 Blockers and pending approvals

- **Native build blocker (pre-existing):** `npm install`'s postinstall fails — `expo-camera` 57.0.5 is installed but the
  Android scan-region patch was cut against 57.0.4. Expo Go is unaffected.
- `GET /closings/overview` under MySQL's default `sql_mode` (`ONLY_FULL_GROUP_BY`): not re-checked; live runs with
  `sql_mode=""`.
- **WhatsApp:** no provider adapter exists and none is faked; the closing templates await approved copy.
- **Deferred by instruction:** the control website (`docs/38`) is unchanged.

## 📋 Known, not fixed

- **Rollup recovery time:** a request whose recompute died mid-way waits for its lease (60 s) and the next sweep (30 s)
  — up to ~90 s after a restart. `done` requests are kept and not pruned; a request that keeps failing is visible only
  in `rollup_requests.last_error` and the log. One API process assumed (a second is safe by lease and retry).
- `scripts/rollup-audit.js` (revenue-only, `DATE(sold_at)`, existing rows only) is superseded by `rollup-drift.js`.
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
- Selling a phone outright to another store is still the documented contract gap in the partner ranking.
- The Stock tab's own list shows full identifiers (rule 19d); the list reached from Home masks.
- Filter chips are 36 pt tall by design-system decision, with hit slop restoring a 48 pt target.
- Two scripts logging in the same user concurrently deadlock on `users.last_login`; harmless for one phone.
- On web, a screen pushed from a tab announces its back button as "(tabs), back". Dynamic type is handset-only.
- Prisma drift report: `units.identifier` is a stored generated column from 0008 that Prisma cannot model.
- `npx eslint .` over the whole app reports one pre-existing error in `scripts/verify-native-patch.js` (`__dirname`),
  outside `expo lint`'s scope. The backend has a `lint` script but no ESLint configuration.

## The next exact action

1. **Handset:** `docs/24` §40 L1–L6, then §39 K1–K14, §38 R1–R14, §37 H1–H10, C1–C16, §36, §35 and the older backlog —
   on the physical phone against the live API (Expo Go; start Metro). No sample record on the live store unless the
   user asks.
2. Fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy.
