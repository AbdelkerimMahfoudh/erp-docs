# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Owner: **CLAUDE-A**
- `started_at_utc: 2026-09-25T07:47Z` — takeover HEADs (all clean, level with `origin` after a fetch): docs `24c6dcd` ·
  backend `68c21e9` · mobile `40a9b2f`; live at 0081, up to date. The user's API is now running on 3010 (started
  07:45:14Z from `backend/dist`, built 07:44–07:45Z from the clean `68c21e9` tree — the 0081 worker is in it); it is
  not restarted or touched. The handoff below matched.
- **Active phase and scope (the user's approval of 2026-09-25, no workflow, no pictures):** apply the live daily-totals
  repair for the Main Store only — a fresh restore-proved backup; the read-only `rollup-drift` comparison on a fresh
  copy must still show exactly the three unclosed days with the reported differences (else stop and show it); then the
  three `rollup_requests` rows of `docs/52` §5, worked by the running API; a fresh-copy drift check → 0 stale; Main
  Store July–September Results revenue 10 051; source-record counts and checksums before and after. No direct edit of
  sales, payments, expenses, stock, audit rows or closing snapshots; the repair is not expanded.
- Next intended action: the backup and its restore-proof, then the drift comparison.
- Previous session: **CLAUDE-A**, `started_at_utc: 2026-09-25T06:43Z`, closed `2026-09-25T07:37Z`. Takeover HEADs were
  docs `2695f99` · backend `cdbf404` · mobile `40a9b2f` (all clean, level with `origin` after a fetch); the previous
  handoff (`READY_FOR_HANDOFF`, owner `NONE`) matched the repositories and live (0080, up to date).
- **Completed phase: daily totals reliability — durable recompute requests (migration 0081).** Design, coverage of
  every transaction type, tests, the stale days on live and the exact repair plan: `docs/52`; decision record:
  `docs/21` "Daily totals reliability: durable recompute requests".
- Authorisation: the user's brief of 2026-09-25 (daily totals reliability only, no workflow, no pictures) — durable
  recalculation requests that survive a stop or a failure, retried on restart without double counting; every
  transaction type that changes daily figures; a shutdown and a failure tested, Results and goals shown to recover;
  stale days documented with a separate, exact repair plan; the 388 340 repair and live historical totals untouched.
- **The WAMP MySQL service is RUNNING** (the user's; used as it was, not stopped). The user's API (3010) and Metro
  (8081) are not running and were not started. When the API is started on backend `68c21e9`, its start-up sweep finds
  `rollup_requests` empty.
- Next intended action: **decide the stale-day repair** (`docs/52` §5: three branch-days, rehearsed on a copy, not
  applied); then **the handset runs** — `docs/24` §40 L1–L6 and §39 K1–K14 first, then §38 R1–R14, §37, §36, §35 and
  the older backlog, against the live API in Expo Go.

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed by this phase.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`68c21e9`** | level | 0 |
| `erp-mobile` | `reports-export` | **`40a9b2f`** — untouched this phase | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

This phase's backend commits, in order: `97695a8`, `68c21e9`. Docs during the phase: `ec35bec`, `5f2fade`, then this
commit. Every one is on `origin`. Earlier phases: backend `ceba0ed`, `cdbf404` (0080), `2b7ba08`, `2c98658`, `b091286`
(0079); mobile `8cd38ff`, `40a9b2f` (0080), `a9b9226`, `9130a9c` (0079).

## What changed

| Commit | Where | In one line |
|---|---|---|
| backend `97695a8` | `prisma/migrations/0081_rollup_requests`, `schema.prisma`, `src/analytics/rollup-queue.ts`, `rollup-outbox.service.ts` (new, replaces `in-process-rollup-queue.ts`), `analytics.module.ts`, `rollup.listener.ts`, `src/sales/sales.service.ts`, `src/expenses/expenses.service.ts`, `src/returns/returns.service.ts`, `src/corrections/corrections.service.ts`, `src/purchasing/purchasing.service.ts`, `src/transfers/transfers.service.ts`, specs and test doubles | every transaction that changes the figures writes its recompute request inside itself; a worker drains them after commit, at start-up and every 30 s, under a lease, with a capped backoff, never abandoning one; a committed return, refund or correction is no longer failed by its recompute |
| backend `68c21e9` | `scripts/rollup-drift.js` (new) | which days are stale, exactly: the production recompute on a restored copy, every column compared with live, live only read |
| docs (this commit) | `docs/52` (new), `docs/21`, `SESSION_LOG.md`, this file | the design, the coverage table, the tests, the stale days and the exact repair plan |

## Verification

| Kind | Result |
|---|---|
| **Backend gate** | tsc clean · `nest build` clean · `prisma validate` · `migrate status` up to date (0081) · full suite **155 suites / 2 791 tests, 0 failed** (new `rollup-outbox.spec` 12 — a failure marked done and a dropped mid-pass request each make it fail; `rollup-requests-coverage.spec` 10) |
| **Real database (restore-proved copy, built API, fake clock)** | `rollup-durability.mjs` **22/22**: every transaction type requested inside its transaction and worked; a failing recompute (every rollup write rejected) — sales and a correction commit (201), requests wait, Results 0 and branch goals 0 during, then the running API retries to 20 000 / 10 000 cancelled / net 10 000, 1 unit; the API killed mid-recompute — the lease is taken over at restart (10 000, 1 unit); the API stopped with a request pending — worked at the next start (20 000, 2 units); every one of 23 requests worked again — every rollup row byte-identical |
| **Stale-day audit (read-only on live)** | `rollup-drift.js` against a restored copy: 7 branch-days, **3 stale**, none closed (`docs/52` §5); the repair rehearsed on a copy → **0 stale** after |
| **Migration 0081** | backup `~/erp-backups/phonestore-before-0081-20260925-071413.sql` (879 111 B, trailer present, 0 raw binary) → restore-proved into `prisma_verify_home` (91 tables / 26 triggers, counts and the `units` checksum equal) → 0081 rehearsed and re-run (idempotent) → **applied to live at `2026-09-25T07:32:20Z`** |
| **Physical device** | not applicable to this phase (backend only); the handset backlog is unchanged — `docs/24` §40, §39, §38, §37, §36, §35 |

## Data and process safety

- **Live `phonestore` received exactly one change from this phase: migration 0081**, after the backup and its
  restore-proof. Read back: 9 sales / 53 units / 865 audit rows / 9 payments / 1 closing / 6 rollups / 0 corrections /
  63 permissions / 0 rollup requests; 92 tables / 26 triggers; latest `0081_rollup_requests`; the `units` and
  `daily_rollups` checksums unchanged — **no historical total was changed**. No sample record, no message.
- Every other write went to the copies `prisma_verify_home` and `prisma_verify_drift`, rebuilt from the backup for each
  run and **dropped at close-out**; the drift audit issued only SELECT statements against live.
- The **388 340.00 overstatement is untouched**, and so is the newly found 2026-07-30 gap (`docs/52` §5).
- Processes started here and stopped: the isolated API (3012), killed and restarted by the lifecycle on purpose — free
  at close-out. Scratch tooling lives in the OS temp directory only; the rehearsal's dump was deleted.

## 🔴 Blockers and pending approvals

- **Stale days on live — a repair awaiting approval (NOT applied).** The exact read-only audit (`docs/52` §5) finds 3
  branch-days, none closed: **2026-07-30 never rolled up** (9 051.00 revenue, 6 sales, 35 units, a 500.00 expense missing
  from Results and branch goals — new), **2026-08-08** overstated by 40.00 and **2026-09-10** by 388 300.00 (the known
  388 340). The repair — three `rollup_requests` rows worked by the API, with a docs/22 backup first — is written in
  `docs/52` §5 and was rehearsed on a copy (0 stale after). It supersedes, for these days, the older
  `scripts/rollup-audit.js` procedure, which cannot see 2026-07-30.
- **Native build blocker (pre-existing):** `npm install`'s postinstall fails — `expo-camera` 57.0.5 is installed but the
  Android scan-region patch was cut against 57.0.4. Expo Go is unaffected.
- `GET /closings/overview` under MySQL's default `sql_mode` (`ONLY_FULL_GROUP_BY`): not re-checked; live runs with
  `sql_mode=""`.
- **WhatsApp:** no provider adapter exists and none is faked; the closing templates await approved copy.
- **Deferred by instruction:** the control website (`docs/38`) is unchanged.

## 📋 Known, not fixed

- **Rollup recovery time:** a request whose recompute died mid-way waits for its lease (60 s) and the next sweep (30 s)
  — up to ~90 s after a restart; Results and branch goals lag by that much, while Home, the Daily closing and personal
  goals read the records directly. `done` requests are kept and not pruned; a request that keeps failing is visible
  only in `rollup_requests.last_error` and the log. One API process assumed (a second is safe by lease and retry).
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

1. **Decide the stale-day repair** (`docs/52` §5). If approved: backup per `docs/22`, restore into
   `prisma_verify_drift`, `npm run build`, `COPY=prisma_verify_drift node scripts/rollup-drift.js` (confirm the same
   three days), start the API on backend `68c21e9`, insert the three `rollup_requests` rows printed there, check they
   are `done`, re-audit a fresh copy → 0 stale.
2. Start the user's API (3010) and Metro (8081) on the running MySQL service.
3. **Handset:** `docs/24` §40 L1–L6, then §39 K1–K14, §38 R1–R14, §37 H1–H10, C1–C16, §36, §35 and the older backlog —
   on the physical phone against the live API (Expo Go). No sample record on the live store unless the user asks.
4. Fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy.
