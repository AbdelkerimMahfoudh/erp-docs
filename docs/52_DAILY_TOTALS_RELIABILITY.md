# 52 — Daily totals reliability: durable recompute requests (0081)

> The user's brief of 2026-09-25, daily totals reliability only, no workflow, no pictures: make the recalculation
> request durable, so a committed sale cannot lose its update if the API stops or the recalculation fails; retry
> pending work on restart without counting a sale twice; check every transaction type that changes daily figures;
> test a shutdown or failure between the commit and the recalculation and verify that Results and goals recover;
> document the days that could still be stale with a separate, exact repair plan. The 388 340 repair and live
> historical totals: not touched.

## 1. What was wrong

`daily_rollups` (and the product facts beside it) are **derived**: Results, branch goals and the close's digest read
them. They are rebuilt from the source records by `RollupService.recomputeDaily`. Every change that moves them asked
for that recompute **after its transaction committed, in memory**:

| Change | How it asked | What a stop or a failure did |
|---|---|---|
| Sale recorded | `sale.recorded` event → `InProcessRollupQueue` (fire-and-forget) | stop before/while the recompute ran: the sale committed, the day never learned of it; failure: logged and forgotten |
| Expense confirmed | `enqueueDailyRecompute` (fire-and-forget) | the same |
| Return approved | `await recomputeDaily` after the transaction | stop: lost; failure: the committed approval answered **500** and the day stayed stale |
| Refund payout confirmed | `await recomputeDaily` after the transaction | the same |
| Correction approved | `await recomputeDaily` after the transaction (+ branch refresh) | the same |
| Purchase received, transfer shipped/received | `enqueueBranchRefresh` / `stock.moved` (fire-and-forget) | stock snapshots (valuation, velocity) stale until the next sale |

Nothing ever revisited a stale day: the next change to the **same** branch-day repaired it by accident, and a day
with no later change stayed wrong. Found on the copy (2026-09-25): stopping the API right after a sale left that
day's rollup without the sale.

## 2. What it does now (decisions D25–D28)

| # | Decision |
|---|---|
| D25 | **The request is a row, written inside the business transaction** (`rollup_requests`, migration 0081, via `requestRollupTx`). It commits with the change or not at all. `daily` names a branch-day; `branch` asks for the branch's stock snapshots. Each row keeps its cause and the record that asked (`source_id`). |
| D26 | **A worker drains the requests** (`RollupOutboxService`, the recognition outbox's design): after each commit (the caller kicks it), once at start-up (whatever a stop left behind) and every 30 s (retries). It claims the rows it has seen with a **lease** (60 s), recomputes once per branch-day or branch, then marks exactly those rows `done`. A failure puts them back to `pending` with the error and a capped backoff (5 s doubling to 30 min) — **never abandoned**. |
| D27 | **Never counted twice.** The recompute rebuilds the branch-day from its source records (an upsert of computed figures; product facts deleted and written again) — it never adds to a total. Working a request again (a stop after the recompute but before `done`, an expired lease taken over, a replayed pass) writes the same figures. A request committed *during* a recompute is not in that pass's claim: it stays pending for the next pass, so no change can be swallowed by a recompute that started before it. |
| D28 | **A committed change is never failed by its recompute.** The return, refund and correction paths still wait for the recompute (the caller sees fresh figures), but a failure there leaves the request pending and answers success. The close keeps recomputing its own day before its transaction, and refuses to close if that fails — nothing has committed yet. |

## 3. Every transaction type that changes the figures

The rollup reads: sales and their lines (business date), confirmed expenses (confirmation date, or a fixed
expense's due date), approved return reversals (approval date), confirmed refund payouts (confirmation date) and
approved corrections (correction date). The branch snapshots read stock. Every writer of those, and its request:

| Transaction | Request, inside its own transaction | Worked |
|---|---|---|
| Sale recorded | `daily` (sale's business date) + `branch` | after commit (event), in the background |
| Expense confirmed | `daily` (the day it lands on) — the confirmation is now a transaction with its request | after commit, background |
| Return approved | `daily` (approval day) | after commit, awaited, never failing |
| Refund payout confirmed | `daily` (confirmation day) | after commit, awaited, never failing |
| Correction approved (every kind) | `daily` (correction day) + `branch` when goods moved | after commit, awaited, never failing |
| Purchase received | `branch` | after commit, background |
| Transfer shipped / received | `branch` for **both** ends | after commit (event), background |

Checked and changing nothing derived: a sale payment collected later, an expense reported or rejected, a return
requested/investigated/rejected, a refund reported or edited before confirmation, a correction requested or rejected,
a closing's count, close or reopen.

## 4. Tests

**Specs (backend, 155 suites / 2 791 tests).** `rollup-outbox.spec` (12): a stop before the recompute leaves the
request for the next start; many requests for one branch-day are one recompute; a failure waits with its error and a
backoff, the caller is never failed, the retry after the backoff recovers; twelve failures in a row are still pending
(backoff capped at 30 min); a lease held blocks others and an expired one is taken over; a sale committed during its
day's recompute is not swallowed; the same request worked twice counts the sale once; the error kept is its cause
line. Two mutations — a failure marked `done`, a caller's pass dropped mid-pass — each fail it.
`rollup-requests-coverage.spec` (10): every writer of §3 requests inside its transaction, with its day and cause;
nothing recomputes outside the worker but the close's own day; the rollup never increments; the transfer path end to
end through the real service (both ends, shipped and received).

**Real database (`rollup-durability.mjs`, a restore-proved copy, the built API, a fake clock): 22/22.**

| Phase | What happened | Results and goals |
|---|---|---|
| A — 2026-12-01 | Purchase, 2 sales, an expense, a return approved and refunded, a correction, a transfer shipped and received: every request written in its transaction with its day and cause, all `done`; the day's rollup equals its records | Results: 20 000 sold, 10 000 returned, net 10 000, gross profit 4 000, expenses 300 — exact |
| B — 2026-12-02, **the recompute fails** (a trigger rejects every rollup write) | 2 sales commit (201); a sale cancellation, a path that used to answer 500, commits (201); all 3 requests `pending`, attempt 1, "simulated rollup failure" | **during:** Results 0, branch units goal 0, revenue goal 0 (stale; the seller's own goal read 1, as it should — personal goals, Home and the Daily closing read the records directly, not the rollup). **After the fault clears, the running API retries on its own:** Results 20 000 / 10 000 cancelled / net 10 000; units 1, revenue 10 000 |
| C — 2026-12-03, **the API is killed mid-recompute** (its rollup write blocked by a table lock, the process terminated, its statement killed) | the sale committed; its request held `processing` under the lease; no rollup row | **restarted after the lease ran out:** the start-up sweep takes it over (attempt 2) — Results 10 000, units 1, revenue 10 000 |
| D — **the API stops with a failed request pending** | the sale committed, request `pending` | **at the next start:** Results 20 000, units 2, revenue 20 000 |
| E — **every one of the 23 requests worked again** | — | every rollup row byte-identical; Results over the three days unchanged (60 000 sold, 10 000 returned, 10 000 cancelled, net 40 000, gross profit 16 000); each day's rollup equals its records |

## 6. What is still owed, by name

- **The three stale days on live** (§5) were repaired on 2026-09-25, on a separate approval; a drift check on a fresh
  copy afterwards reads 0 stale.
- **Recovery time.** A request whose recompute died mid-way waits for its lease (60 s) and the next sweep (30 s): up to
  about 90 s after a restart before Results and branch goals catch up. Home, the Daily closing and personal goals read
  the records directly and are never stale.
- **One process.** The lease makes two processes safe (only one claims a row), but two recomputes of the same
  branch-day from two processes could race on the product facts; the loser fails and is retried. The API runs as one
  process today.
- **Growth.** `done` rows are kept (one per change) as the history of each recompute; nothing prunes them yet.
- **Failure visibility.** A request that keeps failing stays `pending` with its `last_error` and is logged at each
  attempt; nothing on the phone shows it.
- `scripts/rollup-audit.js` is left as it is; the 388 340 procedure that named it was closed by the §5 repair, and
  `rollup-drift.js` answers the question exactly.
- The API was tested as the migration user on the copy; live connects as `phonestore_app`, whose schema-wide
  SELECT/INSERT/UPDATE/DELETE on `phonestore` covers the new table (checked with its own `SHOW GRANTS`).

## 5. Days that were stale on live, and their repair (completed 2026-09-25)

0081 protects every change from now on. It does not revisit the past: a day that lost its recompute before 0081 is
stale until it is recomputed. Which days, exactly, was measured without writing to live:

**Method (`backend/scripts/rollup-drift.js`).** Restore a fresh backup of live into a `prisma_*` copy; the tool refuses
to run unless the copy's records and rollups fingerprint-match live. On the **copy** it runs the production
`RollupService.recomputeDaily` for every branch-day that has a source record or a stored row; then it compares every
`daily_rollups` column and every product fact with what **live** stores. Live is only read (SELECT). This supersedes
`scripts/rollup-audit.js` for this purpose: that script compares only revenue and sales count, keys sales on
`DATE(sold_at)` rather than the stored business date, and looks only at days that already have a rollup row — so it
cannot see a day that was never rolled up.

**Result on live, 2026-09-25 (backup `phonestore-before-0081-20260925-071413.sql`, 7 branch-days, Main Store):
3 stale, none closed.**

| Day | Stored | From its records | Effect on Results and branch goals |
|---|---|---|---|
| 2026-07-30 | **no row** | revenue 9 051.00 · cost 6 232.80 · gross profit 2 818.20 · 6 sales · 35 units · expenses 500.00 · net profit 2 318.20 | **understated**: the day's sales and its expense are missing entirely |
| 2026-08-08 | revenue 40.00 · cost 8.20 · 1 sale · 2 units · net 31.80 · product facts | nothing | overstated by 40.00 |
| 2026-09-10 | revenue 388 300.00 · cost 60 000.00 · 6 sales · 6 units · net 328 300.00 | nothing | overstated by 388 300.00 |

The two overstated days are the known **388 340** overstatement (awaiting approval when found; repaired with the
third day on 2026-09-25 — see "Completed on live" below). 2026-07-30 is **new**: its
sales predate the rollups' first row (2026-08-03) and were never rolled up; the existing audit could not see it.
Every other branch-day (08-03, 09-14, 09-15, 09-22) matches its records column for column.

**The repair procedure** — written as a separate decision, approved by the Owner for the Main Store only and carried
out exactly as below on 2026-09-25; kept as the record of how it was done:

1. The Owner approves the list above by name (the three days, their before and after).
2. Backup of live per `docs/22` §2 and its restore-proof per §3.
3. Restore that backup into `prisma_verify_drift`; `npm run build`;
   `COPY=prisma_verify_drift node scripts/rollup-drift.js` — confirm the list is still exactly these three days
   (anything new is reviewed first).
4. With the API running on 0081, ask it to recompute exactly those branch-days through the durable queue (the
   statement the tool prints):
   ```sql
   INSERT INTO rollup_requests (id, company_id, branch_id, kind, day, cause, status, attempts, requested_at, next_attempt_at) VALUES
     (UUID_TO_BIN(UUID(), 1), UNHEX('018F0000000070008000000000000001'), UNHEX('019FB2EBD9707333AB0167454AB5BBCE'), 'daily', '2026-07-30', 'repair_drift', 'pending', 0, NOW(6), NOW(6)),
     (UUID_TO_BIN(UUID(), 1), UNHEX('018F0000000070008000000000000001'), UNHEX('019FB2EBD9707333AB0167454AB5BBCE'), 'daily', '2026-08-08', 'repair_drift', 'pending', 0, NOW(6), NOW(6)),
     (UUID_TO_BIN(UUID(), 1), UNHEX('018F0000000070008000000000000001'), UNHEX('019FB2EBD9707333AB0167454AB5BBCE'), 'daily', '2026-09-10', 'repair_drift', 'pending', 0, NOW(6), NOW(6));
   ```
   The worker recomputes them within 30 s (or at the next start) with the production code; the rows stay as the
   record of the repair.
5. Verify: `SELECT status FROM rollup_requests WHERE cause = 'repair_drift'` → three `done`; a new backup restored into
   a copy and the tool run again → **0 stale**.
6. Rollback, if ever needed: the backup of step 2 (a Git rollback does not roll back the database).

The repair changes Results and branch goals for those three days only — for the Main Store, July to September revenue
as Results reads it goes from 389 340.00 to 10 051.00 (07-30 +9 051.00, 08-08 −40.00, 09-10 −388 300.00); no closing
snapshot, sale or other record changes, and none of the three days has a closing.

**Rehearsed on a copy, never on live (2026-09-25).** The backup above restored into `prisma_verify_home` with 0081;
the three statements inserted; the API started: its start-up sweep worked the three requests (`done`), the rollups read
07-30 9 051.00 · cost 6 232.80 · 6 sales · 35 units · expenses 500.00 · net 2 318.20, 08-08 and 09-10 all zero, and
Results read 9 051 / 0 / 0 for the three days; the repaired copy dumped, restored and audited again: **0 stale**.

### Completed on live, 2026-09-25 (Main Store only)

Carried out by CLAUDE-A on the Owner's approval, following steps 2–5 above; no sale, payment, expense, stock, audit row
or closing snapshot was edited, and nothing beyond the three branch-days was requested.

- **Backup before** (step 2): `~/erp-backups/phonestore-before-rollup-repair-20260925-075114.sql` (881 146 B, trailer
  present, 0 raw binary) — restored into a copy: 92 tables / 26 triggers, **identical to live row for row** on the 25
  tables fingerprinted (row count and whole-row checksum of every source and derived table).
- **Drift before** (step 3, a fresh copy of that backup, live only read): 7 branch-days, **3 stale — exactly the three
  above**, all Main Store (`019FB2EBD9707333AB0167454AB5BBCE`), none closed, with the same differences. Live was
  fingerprinted again just before the requests: unchanged since the backup.
- **Requests** (step 4): the three statements above, inserted at **07:52:36 UTC**; the user's running API (started
  07:45:14 UTC from a build of backend `68c21e9`, 0081) worked all three at **07:52:53 UTC**, attempt 1, no error.

| Branch-day | Before | After | Product facts |
|---|---|---|---|
| 2026-07-30 | no rollup row | revenue 9 051.00 · cost 6 232.80 · gross profit 2 818.20 · 6 sales · 35 units · expenses 500.00 (cash, 1) · net profit 2 318.20 | its 9 rows (35 units, 9 051.00) rebuilt with the same values |
| 2026-08-08 | revenue 40.00 · cost 8.20 · gross profit 31.80 · 1 sale · 2 units · net profit 31.80 | all zero | its 1 row (2 units, 40.00) removed |
| 2026-09-10 | revenue 388 300.00 · cost 60 000.00 · gross profit 328 300.00 · 6 sales · 6 units · net profit 328 300.00 | all zero | none, before or after |

- **Source records, before → after:** all 22 source tables with the same row count and whole-row checksum — sales 9,
  sale_items 16, payments 9, expenses 4, purchases 10, purchase_items 21, supplier_payments 1, units 53, stock_items 18,
  audit_logs 865, daily_closings 1, closing_channel_counts 1, users 14, branches 3; return requests, return reversals,
  refund payouts, corrections and their legs, transfers, closing events and customers 0. Only the derived tables moved:
  `daily_rollups` 6 → 7, `product_daily_rollups` 16 → 15, `rollup_requests` 0 → 3. Every other rollup row and product
  fact is byte-identical to before.
- **Backup after:** `~/erp-backups/phonestore-after-rollup-repair-20260925-075339.sql` (882 058 B, trailer present,
  0 raw binary) — restored identical to live on all 25 tables.
- **Drift after** (step 5, a fresh copy of that backup): 7 branch-days, **0 stale**.
- **Results, Main Store, 2026-07-01 → 2026-09-30:** **10 051 MRU** (389 340 before) — gross = net 10 051, gross profit
  3 018.20, expenses 500, net operating 2 518.20; per day 9 051 · 0 · 0. Read through the real `analytics/summary`
  endpoint on a copy of the post-repair backup, and the same from live's own rollups.
- **Rollback** (step 6), if ever needed: the backup before. The three `repair_drift` rows stay in `rollup_requests` as
  the record of the repair.
