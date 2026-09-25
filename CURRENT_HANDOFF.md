# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Owner: **CLAUDE-A**
- `started_at_utc: 2026-09-24T09:39Z` — takeover HEADs (all clean, level with `origin` after a fetch): docs `8f2c9e6` ·
  backend `f4c3381` · mobile `1e316e9`; live `migrate status` up to date (0078). The handoff below matched. The
  user's API (3010) and Metro (8081) are running and are not touched.
- **Active phase and scope (the user's follow-up of 2026-09-24, still the Daily closing scope, no workflow):**
  (1) verify that the Owner can delegate closing to at most two employees, that they can close and reclose and that
  other employees cannot — restore delegation if anything removed it; (2) complete the correction path for erroneous
  sales, payments, expenses and purchases as authorised reversals or adjustments with a required reason and a
  permanent audit history, never overwriting a confirmed record or an earlier closing snapshot; name exactly any
  action left unavailable and why. Physical phone checks may stay pending.
- **Checkpoint 2026-09-25T03:40Z — delegation verified, plan written.** `delegation-lifecycle.mjs` 24/24 on the
  isolated copy (nothing had removed delegation; only 0078's "Owner-only" wording about roles was wrong). The
  correction plan is `docs/51` §15 (D12–D20, migration 0079). MySQL: the WAMP service was found STOPPED with the
  user's API and Metro down (the machine had restarted); a session `mysqld` runs from a copy of the service's own
  settings group (`sql_mode=""`, `utf8mb4_unicode_ci`, binary log off) and is shut down at close-out.
- Next intended action: migration 0079 and the backend correction engine on the isolated copy; no live change
  before a restore-proved backup.
- Previous session: **CLAUDE-A**, `started_at_utc: 2026-09-24T04:21Z`, closed `2026-09-24T08:31Z`. Takeover HEADs were
  docs `f5c4d5b` · backend `3fa4801` · mobile `904e3ac` (all clean, level with `origin` after a fetch); the previous
  handoff (`READY_FOR_HANDOFF`, owner `NONE`) matched the repositories and live (`migrate status` up to date, 0077).
- **Completed phase: the Daily closing report, closing without a physical check, and "Correct a transaction"
  (migration 0078).** Decision record: `docs/21` "The Daily closing report, closing without a physical check, and
  'Correct a transaction' (2026-09-24)" — the exact formulas are there; audit, contract and decisions D1–D11:
  `docs/51`; rules 24b, 25, 26, 26a, 27, 28, 28a in `docs/04` §F; device checks: `docs/24` §38 R1–R14.
- Authorisation: the user's brief of 2026-09-24 (Daily closing scope only) and their clarification the same day —
  physical cash and account checks are optional; a close without them records them as **unverified** with an
  explicit acknowledgement and a reason, never as matched or counted; the real count stays available; no further
  multi-agent workflow.
- Next intended action: **the handset runs** — `docs/24` §38 R1–R14 first, then §37 (H1–H10, C1–C16), §36, §35 and the
  older backlog, against the live API in Expo Go. No feature is next.

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed by this phase.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`f4c3381`** | level | 0 |
| `erp-mobile` | `reports-export` | **`1e316e9`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

This phase's backend commits, in order: `42bfd76`, `ff531dd`, `e352cf3`, `f4c3381`. Mobile: `8346398`, `7ed67bc`,
`1e316e9`. Every one is on `origin`. Earlier phases: backend `29b9cc7`, `003efb2`, `a8fc4fe` (0076), `3fa4801` (0077);
mobile `40c73d0`, `8230802`, `944459e`, `57deb64` (0076), `904e3ac` (0077).

## What changed

| Commit | Where | In one line |
|---|---|---|
| backend `42bfd76` | `prisma/migrations/0078_closing_report_and_payment_corrections`, `schema.prisma`, `src/closing/closing-report.ts` + `closing-report.queries.ts` (new), `closing.service.ts`, `closing.controller.ts`, `closing-lifecycle.ts`, `channels.ts`, `closing-notices.ts`, the close / count DTOs, `src/analytics/dashboard.service.ts`, `src/common/interceptors/financial-fields.ts`, specs | `GET /closings/report` (sales, money per channel with older debts apart, expenses, the result gated by `cost.view`, expected balances; invariants asserted on every read; sections built per caller); the close rewritten — optional physical check, `NOT_VERIFIED_AT_CLOSE`, acknowledgement + reason, idempotent by `clientUuid`, bound to `reportVersion` and an in-transaction movement fingerprint under the closing row's lock, the whole report stored in every close's event; the opening drawer anchored on a counted close only; the inactive standing; the timeline whitelist; the close broadcast without figures |
| backend `ff531dd` | `src/corrections/*`, `closing.service.ts` (`GET /closings/sources`, correction arms), `src/analytics/rollup.service.ts`, specs | "Correct a transaction": the date's source records with their flow or a named refusal; `POST /corrections/preview`; moving all or part of a payment to the channel it really reached (request with a reason, Owner approval in one locked transaction, one per payment, posted to the current open day, audit with before/after); `corrections_out`; the rollup reads only the two older correction kinds; a branch-day's recompute runs one at a time |
| backend `e352cf3` | `src/purchasing/*`, `src/expenses/expenses.service.ts`, `closing.service.ts`, specs | a purchase paid on a closed current day reopens it, as a sale does; a fixed expense due on a closed day is refused, as a variable one already was |
| backend `f4c3381` | `src/rbac/role-permissions.ts`, `role-matrix-drift.spec.ts`, `src/users/user-management.service.ts` | `closing.perform` held by the Owner role only (0078 revokes it from administrator and branch_manager; no live user held either); granting a delegate locks the branch row, so three simultaneous grants leave two |
| mobile `8346398` | `app/closing/index.tsx`, `components/closing/CloseReviewSheet.tsx` (new), `lib/closing-report.ts` + `closing-report-view.ts` (+ test, new), `lib/query-keys.ts`, `lib/closing.ts`, `lib/home-day.ts`, `lib/loans.ts`, i18n EN/FR/AR | the Daily closing report screen (date selector, freshness, warnings, the five sections with expandable detail, its own `ScrollView`) and Review and close (final figures, the unverified balances, acknowledgement and reason; confirm never waits for a count) |
| mobile `7ed67bc` | `app/closing/count.tsx`, `lib/closing-screen.test.ts`, i18n | the counting screen becomes the optional "Check physical cash or account balance": no phone totals, no "0 of 2 counted", recount a saved or stale count, an account asked for its movement, not its balance |
| mobile `1e316e9` | `app/closing/sources.tsx` (new), `lib/navigation/registry.ts`, i18n | "Correct a transaction": the day's records, the move sheet with the server's preview, refusals by name on their own line |
| docs (this commit) | `docs/51` (new), `docs/04` §F, `docs/21`, `docs/24` §38, `SESSION_LOG.md`, this file | the audit and decisions, the business rules, the decision record with the formulas, the device checklist, the session entry |

## Verification

| Kind | Result |
|---|---|
| **Backend gate** | tsc clean · `nest build` clean · `prisma validate` · `migrate status` up to date (0078) · full suite on the committed HEAD **151 suites / 2 696 tests, 0 failed** (new `closing-report.spec` 22, a worked day recomputed independently) |
| **Lifecycle (isolated copy, built API, fake clock)** | `report-lifecycle.mjs` **45/45** — the step list is in `docs/21` (the worked day against independent SQL; the sources list and its refusal to a seller; section gating for a seller and a manager without `cost.view`; non-delegates refused; `report_changed`; a counted −500 drawer; close with two accounts not verified; double tap and a second key; a sale after the close; the reclose without a recount; the reclassification refused on a closed day, then approved; one per payment; the audit; a correction racing a close; two racing taps; 05:59:30 vs 06:00:30; the opening carried from the last counted close; inactive vs needs review; missing cost; a purchase reopening a closed day; a fixed expense refused on a closed day; company isolation; three delegations at once; no role but the Owner's holds closing) |
| **Migration 0078** | backup `~/erp-backups/phonestore-before-0078-20260924-082406.sql` (869 033 B, hex-blob, trailer present, 0 raw binary) → restore-proved into `prisma_verify_home` (90 tables / 24 triggers, counts and the `units` checksum equal) → 0078 on the copy → lifecycle and render checks → **applied to live at `2026-09-24T08:24:43Z`**. An identical backup of 07:42 was restore-proved too and is kept |
| **Mobile gate** | tsc clean · `expo lint` 0 errors, 0 warnings in this scope's files · **70 pure suites pass** (new `closing-report-view.test`) · parity **3 065** keys (149 new), identical order, 0 duplicates · web export |
| **Render checks (no pictures, at the user's request)** | `report-checks.mjs`: **28 views** — the report, Review and close, the physical check, "Correct a transaction" and its move sheet in EN/FR/AR, light and dark, 320 and 393 pt, 130 % text, as a seller, a manager without `cost.view` and the Owner — **0 problems** after fixing the three the checks found (the sources SQL column, the secondary button cut at 320 pt, the Arabic refusal cut). Web renders, not device verification |
| **Physical device** | 🔴 **not run** — `docs/24` §38 R1–R14 (and §37, §36, §35 from the previous phases) |

## Data and process safety

- **Live `phonestore` received exactly one change from this phase: migration 0078**, after the backup and its
  restore-proof. Read back at close-out: 9 sales / 53 units / 865 audit rows / 9 payments / 1 closing / 6 rollups /
  0 corrections / 63 permissions; 90 tables / 24 triggers; latest migration
  `0078_closing_report_and_payment_corrections`; `migrate status` up to date; `closing.perform` on the Owner role only.
  No sample sale, payment, expense or correction was written to live.
- Every other write went to the copy `prisma_verify_home` (throwaway credentials, a `cost.view` removal from the
  manager role, one zero cost on a copy sale for the missing-cost case), **dropped at close-out**.
- The known **388 340.00 rollup overstatement is untouched** and still awaits the approved repair.
- Processes started here and stopped: the isolated API (3012, restarted per fake-clock phase), the static server
  (19012), headless Chrome (9334, own profile) — all three ports free at close-out. The user's MySQL service, API
  (3010) and Metro (8081) were never touched and are still running.
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
- **WhatsApp:** no provider adapter exists and none is faked; the closing templates await approved copy. On live no
  user has a phone number, so nothing can be sent.
- **Deferred by instruction:** the control website (`docs/38`) is unchanged.

## 📋 Known, not fixed

- **Owed corrections:** reversing a payment that was never received; correcting a confirmed expense or a purchase
  payment; editing a sale. "Correct a transaction" refuses each by name.
- Loans, consignment and employee-debt cash are outside the report, as they are outside the closing (their ledgers
  use UTC dates).
- Rollup revenue, the digest and Results still leave out the whole-sale discount; the report reads `sales.total` and
  is internally consistent (`docs/51` §3.1).
- Expense and refund confirmations check the day's lock without taking the closing row's lock, as the close, a sale's
  reopen and a correction approval now do.
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

1. **Handset:** `docs/24` §38 R1–R14 — the report's sections and their gating as a seller, a manager without
   `cost.view` and the Owner; scrolling with the finger starting on a card; Review and close with and without a
   physical check, the acknowledgement and reason; the double tap; a sale after the close; "Correct a transaction"
   and its sheet with the keyboard; EN/FR/AR, dark, 320 pt, large text — on the physical phone against the live API
   (Expo Go). No sample sale on the live store unless the user asks for one.
2. Then `docs/24` §37 H1–H10, C1–C16, §36 P1–P15, §35 S1–S15 and the older backlog (§34 … §30).
3. Decide the live rollup repair; fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy.
