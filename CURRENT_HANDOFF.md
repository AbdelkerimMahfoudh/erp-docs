# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Owner: **NONE**
- Previous session: **CLAUDE-A**, `started_at_utc: 2026-09-24T09:39Z`, closed `2026-09-25T05:45Z`. Takeover HEADs were
  docs `8f2c9e6` · backend `f4c3381` · mobile `1e316e9` (all clean, level with `origin` after a fetch); the previous
  handoff (`READY_FOR_HANDOFF`, owner `NONE`) matched the repositories and live (`migrate status` up to date, 0078).
- **Completed phase: closing delegates verified, and the correction path for sales, payments, expenses and purchases
  (migration 0079).** Decision record: `docs/21` "Closing delegates verified, and the correction path for sales,
  payments, expenses and purchases (2026-09-25)" — the formulas, the contract and what stays unavailable are there;
  plan, decisions D12–D20 and risks: `docs/51` §15; rules 28 and 28a in `docs/04` §F; device checks: `docs/24` §39
  K1–K14.
- Authorisation: the user's follow-up (Daily closing scope only, no workflow) — verify that the Owner can delegate
  closing to at most two employees who can close and reclose while other employees cannot; complete the correction
  path for erroneous sales, payments, expenses and purchases as authorised reversals or adjustments with a required
  reason and a permanent audit history, never overwriting a confirmed record or an earlier closing snapshot; name any
  action left unavailable and why. Physical phone checks may stay pending.
- ⚠️ **The WAMP MySQL service is STOPPED** — it was found stopped during this session (the machine had restarted; the
  user's API on 3010 and Metro on 8081 were down too) and was left as found. Start it (WAMP tray, or
  `net start wampmysqld64` as administrator), then the API and Metro, before the handset run.
- Next intended action: **the handset runs** — `docs/24` §39 K1–K14 first, then §38 R1–R14, §37 (H1–H10, C1–C16),
  §36, §35 and the older backlog, against the live API in Expo Go. No feature is next.

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed by this phase.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`b091286`** | level | 0 |
| `erp-mobile` | `reports-export` | **`9130a9c`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

This phase's backend commits, in order: `2b7ba08`, `2c98658`, `b091286`. Mobile: `a9b9226`, `9130a9c`. Docs during the
phase: `06fa1d4`, `dbaf448`, `7e570ce`, then this commit. Every one is on `origin`. Earlier phases: backend `42bfd76`,
`ff531dd`, `e352cf3`, `f4c3381` (0078), `3fa4801` (0077); mobile `8346398`, `7ed67bc`, `1e316e9` (0078), `904e3ac` (0077).

## What changed

| Commit | Where | In one line |
|---|---|---|
| backend `2b7ba08` | `prisma/migrations/0079_correction_path`, `schema.prisma`, `src/corrections/*` (`correction-targets.ts` new, `corrections.service.ts` rewritten, `correction-rules.ts`, the DTO), specs | migration 0079 (four target kinds, the action, `financial_correction_legs` append-only by trigger, a sale line's release, `voided` units, four rollup columns); one plan per target for the preview and the approval; approval in one transaction that locks the day's closing row and the rows it changes, re-plans, writes the legs, the sale caches, the units with their own audit rows, a line's release and stock; audit before (the full preview) and after (the legs) |
| backend `2c98658` | `src/closing/closing-report*.ts`, `closing.service.ts`, `src/analytics/*` (rollup, summary, accounting rules, goals, partner ranking, dashboard), specs | the report counts cancellations, expense reversals and every correction's legs (invariants and fingerprint extended); the sources list with actions, open requests and refusals; a close stores its unchecked balances as "not verified" (the 0078 "changed since close" defect); the rollup, Results and goals net cancellations and reversals |
| backend `b091286` | `src/sales/*`, `src/returns/*`, `src/expenses/*`, `src/inventory/*`, `src/purchasing/*`, the unit state machine, specs | a cancelled sale refuses payments and returns and says so; an expense shows its reversal; voided phones leave stock; receiving a voided IMEI reactivates the same record |
| mobile `a9b9226` | `lib/closing-report.ts` + `closing-report-view.ts` (+ test), `components/corrections/CorrectionSheet.tsx` + `DecideSheet.tsx` (new), `app/closing/sources.tsx`, `app/closing/index.tsx`, `components/ui/ListRow.tsx`, i18n | one correction sheet for every record with the server's preview and the Owner's approve-now; "Waiting for the Owner" with approve and reject; the report's new lines |
| mobile `9130a9c` | `app/sales/[id].tsx`, `app/sales/index.tsx`, `components/money/SaleRow.tsx`, `app/expenses/[id].tsx`, `types/api.ts`, `lib/design/status.ts`, `lib/unit-history.ts`, i18n | a cancelled sale and a reversed expense say so and are corrected from the record itself; the voided status in a phone's history |
| docs `dbaf448`, this commit | `docs/51` §15, `docs/04` rules 28 and 28a, `docs/21`, `docs/24` §39, `SESSION_LOG.md`, this file | the plan and decisions, the rules (delegation wording corrected), the decision record with the formulas, the device checklist, the session entry |

## Verification

| Kind | Result |
|---|---|
| **Backend gate** | tsc clean · `nest build` clean · `prisma validate` · `migrate status` up to date (0079) · full suite re-run on the committed HEAD **153 suites / 2 758 tests, 0 failed** (new `correction-path.spec` 31, `correction-readers.spec` 11; the corrected day in `closing-report.spec`; reactivation in `purchase-dual-imei.spec`). Jest prints its usual "worker failed to exit gracefully" notice |
| **Real-MySQL lifecycles (isolated copy, built API, fake clock)** | `delegation-lifecycle.mjs` **24/24** · `corrections-lifecycle.mjs` **40/40** (every correction on a day recomputed independently in SQL; a closed day's correction waiting then posting the next day with the stored close byte-identical; forced and natural double requests; a cancellation racing a close; company and branch isolation; the audit; reactivation of a voided IMEI) · the 0078 `report-lifecycle.mjs` **45/45** on the new shape |
| **Migration 0079** | backup `~/erp-backups/phonestore-before-0079-20260925-052300.sql` (870 568 B, trailer present, 0 raw binary) → restore-proved into `prisma_verify_home` (90 tables / 24 triggers, counts and the `units` checksum equal) → 0079 rehearsed on that exact copy → **applied to live at `2026-09-25T05:23:45Z`** |
| **Mobile gate** | tsc clean · `expo lint` 0 errors · **70 pure suites pass** (re-run at close-out) · parity **3 161** keys (116 added, 20 retired), identical order, 0 duplicates · web export |
| **Render checks (no pictures, at the user's request)** | `corrections-checks.mjs` **38 views** + the 0078 checks re-run **25 views** — EN/FR/AR, light and dark, 320 and 393 pt, 130 % text — **0 problems** after two fixes (a purchase row sent its payment id; an Arabic row cut at 320 pt). Web renders, not device verification |
| **Physical device** | 🔴 **not run** — `docs/24` §39 K1–K14 (and §38, §37, §36, §35 from the previous phases) |

## Data and process safety

- **Live `phonestore` received exactly one change from this phase: migration 0079**, after the backup and its
  restore-proof. Read back at close-out: 9 sales / 53 units / 865 audit rows / 9 payments / 1 closing / 6 rollups /
  0 corrections / 0 legs / 63 permissions; 91 tables / 26 triggers; latest migration `0079_correction_path`;
  `migrate status` up to date. No sample sale, payment, expense, purchase or correction was written to live; no
  message was sent.
- Every other write went to the copy `prisma_verify_home`, **dropped at close-out**.
- The known **388 340.00 rollup overstatement is untouched** and still awaits the approved repair.
- MySQL: the service was found stopped and is still stopped. A session `mysqld` ran from a copy of the service's own
  settings group (`sql_mode=""`, `utf8mb4_unicode_ci`, binary log off) against the WAMP data directory and was shut
  down cleanly at close-out. Its first start, before the binary log was switched off, left `binlog.000011` (181 B)
  and `binlog.000012` (213 396 B) there.
- Processes started here and stopped: the session `mysqld` (3306), the isolated API (3012), the static server (19012),
  headless Chrome (9334) — all free at close-out.
- Scratch tooling lives in the OS temp directory only; no file holding a token or a credential was written inside
  any repository.

## 🔴 Blockers and pending approvals

- **MySQL service stopped** (see Session control) — start it before anything that needs the database.
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

- **Corrections not available, by name:** reversing a purchase payment as "not paid" (purchases are paid in full and
  there is no supplier debt to carry it — cancel the purchase instead); editing a sale line or cancelling part of a
  sale (cancel and sell again); a sale with a return (correct it on the return); a purchase whose goods have moved
  (correct the later record first). Reassigning a stored business date is still an Owner correction that does not
  exist.
- A branch's **units-sold** goal still counts a cancelled sale's items (no rollup column for it); revenue, profit and
  count goals and personal goals do not.
- Home's period figures count a sale on the day it was sold, as they count a sale later returned; the Daily closing
  and Results show a cancellation on its own day.
- The approval audit's `before` is now the full preview (`$.payment.method`, `$.move`, …) rather than 0078's flat
  fields; any saved query on the old shape must follow.
- Loans, consignment and employee-debt cash are outside the report, as they are outside the closing.
- Rollup revenue, the digest and Results still leave out the whole-sale discount; the report reads `sales.total`.
- Expense and refund confirmations check the day's lock without taking the closing row's lock, as the close, a sale's
  reopen and a correction approval do.
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

1. Start the WAMP MySQL service, then the user's API (3010) and Metro (8081).
2. **Handset:** `docs/24` §39 K1–K14 — a named employee closes and recloses and another does not; the third
   delegate refused; "Correct a transaction" and each correction sheet (payment never received, moved, sale
   cancelled, expense reversed, purchase payment moved, purchase cancelled and received again), the Owner's
   decisions, a correction on a closed day; the keyboard over each sheet; EN/FR/AR, dark, 320 pt, large text — on
   the physical phone against the live API (Expo Go). No sample record on the live store unless the user asks.
3. Then `docs/24` §38 R1–R14, §37 H1–H10, C1–C16, §36 P1–P15, §35 S1–S15 and the older backlog (§34 … §30).
4. Decide the live rollup repair; fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy.
