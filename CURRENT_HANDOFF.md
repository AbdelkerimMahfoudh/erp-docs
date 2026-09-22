# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Owner: **NONE** — both 2026-09-22 conversations are closed: the correction phase (CLAUDE-A,
  `started_at_utc: 2026-09-22T03:24Z`, closed `13:22Z`) and the parallel scope (CLAUDE-A,
  `started_at_utc: 2026-09-22T05:30Z`, closed ~`14:40Z`).
- Completed phases:
  1. **Correction of the previous session's work** — the failed generic-selling implementation, the
     worsened Excel-review performance and the three screens that had not received the approved
     restyle. Decision record: `docs/21` "Correction of the generic selling, Excel-review performance
     and the three restyles (2026-09-22, second phase)"; device checks `docs/24` §35.
  2. **Invoice, Daily Closing, alerts preview, platform administration, website deferral** — the
     parallel scope. Decision record: `docs/21` "Invoice, Daily Closing, alerts preview, platform
     administration, website deferral (2026-09-22, parallel scope)"; audit `docs/49`; platform
     `docs/37` Phase 5; device checks `docs/24` §36.
- Next intended action: **the handset runs** — `docs/24` §36 (P1–P15) and §35 (S1–S15) against the
  live API in Expo Go. No feature is next.

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed by either phase.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`decb699`** (parallel scope) — the correction phase's last is `22d8227` | level | 0 |
| `erp-mobile` | `reports-export` | **`e43b551`** (parallel scope) — the correction phase's last is `3cfd598` | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched by both phases | level | 0 |

_Takeover baselines: correction phase docs `d0eeb74` · backend `e9f8e7e` · mobile `c26f42b`; parallel scope docs `df5f37d` · backend `59381f3` · mobile `c26f42b`._

Backend commits, in order: `59381f3`, `60bd6c1`*, `22d8227`, `c9e7a23`*, `f2d97f7`*, `e7eddab`*, `d16dc1e`*, `decb699`*
(* = parallel scope). Mobile: `68a8a57`, `f62a27c`, `ef2c795`, `d8e352e`, `de20990`, `3cfd598` (correction phase);
`f5c1441`, `afda01a`, `baa6528`, `2a00f25`, `a6182fe`, `3397e90`, `e43b551` (parallel scope). Every one is on `origin`.

## What changed — the parallel scope

| Commit | Where | In one line |
|---|---|---|
| backend `60bd6c1` | `src/anomalies/*` | each rule dates its anomaly from its own records; newest → serious → key total order; `GET /anomalies?limit=&page=` + `total`; idempotent dismiss |
| backend `c9e7a23` | `prisma/migrations/0075_…`, `schema.prisma`, `src/entitlement/*`, `src/platform/subscription-lifecycle.service.ts` | `rejected` status/state + `ENTITLEMENT_REJECTED`; approve (months or exact end; reverses a refusal), reject (reason), setPeriodEnd (shortening needs a reason); `approved`/`rejected`/`period_corrected` events; `owner_invitations` |
| backend `f2d97f7` | `src/platform/owner-invitation.service.ts`, `platform.controller.ts`, `platform-boundary.spec.ts` | `POST platform/businesses` (random unknown password + one-time hashed 72 h invitation, manual delivery), `…/owner-invitation`, public `owner-invitation/accept`, approve/reject/period routes, dashboard counts `rejected`, state filter before paging, the boundary spec |
| backend `e7eddab` | `auth.controller.ts`, `users.service.ts` | `/auth/me` carries `companyName` |
| backend `d16dc1e`, `decb699` | `src/anomalies/*` | `POST /anomalies/:key/undismiss` (ends the standing dismissal, audited); the route's decorators corrected + `anomalies.controller.spec.ts` |
| mobile `f5c1441` | `lib/receipt-html.ts` (new), `lib/receipt.ts`, `app/sales/[id].tsx`, `types/api.ts`, i18n | one full-page invoice generator (≈83 % of A4/Letter, repeating table header, print-safe ink, escaped values, LTR figures in RTL), all server-confirmed content (Rule 19e) |
| mobile `afda01a` | `app/closing.tsx`, `lib/closing-screen.test.ts`, i18n | own SafeAreaView/KeyboardAvoidingView/FlatList, memoised rows in one surface, summary surface, explicit Save per row, pinned "Review and close" with its reason |
| mobile `baa6528` | `components/analytics/AlertRow.tsx` (new), `AttentionList.tsx`, `app/alerts.tsx` (new), `lib/anomalies.ts`, `lib/attention-rules.ts`, `lib/query-keys.ts`, registry, i18n | three newest alerts in one compact surface, "I understand" + Undo toast, "View all N", the paginated full list |
| mobile `2a00f25` | `app/subscription-blocked.tsx`, `app/(auth)/verify.tsx`, `constants/config.ts`, deletions (`lib/portal.ts`, `hooks/useAccountPortal.ts`, `lib/signup.ts`, `lib/account-portal.test.ts`), `lib/website-deferred.test.ts`, i18n | the website withdrawn from the app; blocked screen with `rejected`, contact guidance, Check again, Sign out |
| mobile `a6182fe`, `3397e90`, `e43b551` | `app/platform/*` (new), `lib/platform-admin.ts`, `lib/platform-state.ts`, `hooks/useAuth.tsx`, `lib/entitlement.ts`, `app/(auth)/login.tsx`, registry, i18n | the Super Admin area on its own session and routes (sign-in, overview, business, create, audit); the closed-shop gate at the root; audit actions in words |

The correction phase's own table is in `docs/21` and the previous handoff commit (`1286b43`).

## Verification — the parallel scope

| Kind | Result |
|---|---|
| **Backend gate** | tsc clean · `nest build` clean · `prisma validate` · `migrate status` up to date (0075) · drift: only the pre-existing generated `units.identifier` (0008) · full suite **2 605 tests / 145 suites, 0 failed** |
| **Live lifecycle (isolated copy, built API)** | `platform-lifecycle.mjs` **42/42**: create/retry/step-up/hash-only; invitation once/expired/revoked; Owner sign-in; pending lock incl. the branch list; Owner JWT, forged company/branch headers, anonymous and self-approval all 401 on platform routes; no operational data in the platform view; reject → `ENTITLEMENT_REJECTED`; stale version 409; approve → reads open; period correction; suspend → `ENTITLEMENT_SUSPENDED` with the account surface open; reinstate; extend; grace with hours and writes; expired reads-only; audit trail complete and secret-free; sign-out; disabled administrator; identical refusals |
| **Mobile gate** | tsc clean · `expo lint` 0 errors, 0 warnings in this scope's files · Expo Doctor's four pre-existing mismatches · **66 pure suites pass** · parity **2 793** keys, identical order, 0 duplicates · web export with all 83 routes · 0 raw colours / 0 hardcoded copy / 0 unlabeled controls in this scope's screens |
| **Closing profile** | un-minified exports, 25 channels, React commit counting before → after: per save row updates **50 → 2**, component updates 1 664 → 309, script 160 → 64 ms, task 195 → 114 ms; per keystroke 1 row in both; DOM 1 022 → 744 at load; inputs mounted 19 → 7 |
| **Invoice** | real PDFs through headless Chrome: A4 + Letter, EN/FR/AR, 1/12/40 lines, paid/partial/unpaid, customer and partner-store debtor — inspected as images |
| **Render matrix** | **44 captures** on the final export: closing EN/FR/AR × light/dark × 320/390, keyboard open (EN, AR), 130 % text, one account; analyses 7/3/1/0 alerts + full list (EN, AR); blocked pending/rejected/suspended (EN, AR), grace, expired; platform sign-in (EN, AR), overview (EN, FR dark), a pending business, the approve form, create (AR), audit — 0 leaked keys, 0 sideways overflow |
| **Physical device** | 🔴 **not run** — `docs/24` §36 P1–P15 (and §35 from the correction phase) |

## Data and process safety

- Backup before 0075: `~/erp-backups/phonestore-before-0075-20260922-055832.sql` (862 536 B, hex-blob,
  trailer present), restore-proved into `prisma_verify_platform` (88 tables / 24 triggers, counts and
  the `units` checksum equal, trigger bodies identical), then 0075 forward there, then live. Live rows
  unchanged around it (9 sales / 53 units / 862 audit rows). The correction phase's dump
  (`phonestore-20260922-pre-sell-fix.sql`, in `%TEMP%\claude`) is kept as well.
- **Live `phonestore` received exactly one change from the parallel scope: migration 0075.** Every
  other write went to the copy.
- Processes: the correction phase stopped its own (API 3011, static 19006–19008, Chrome 9333); the
  parallel scope stopped its own (API 3012, static 19010–19012, Chrome 9334). The user's MySQL, API
  and Metro were never touched by either.
- The scratch schema `prisma_verify_platform` (its throwaway administrator and three "Verification
  Boutique" businesses) was **dropped at close-out**; the correction phase's `prisma_verify_sell` was
  dropped by that phase. MySQL was found **stopped** (service `wampmysqld64` STOPPED, no `mysqld`) at
  close-out; a session `mysqld` on the same data directory (`--sql-mode=`, as `docs/49`'s memory note
  records) ran for under a minute for the drop and the integrity readings and was shut down again — the
  service is left exactly as found. Live after: 9 sales / 53 units / 862 audit rows / 2 companies /
  0 platform administrators / 0 owner invitations; both subscriptions `activated`; 89 tables / 24 triggers.

## 🔴 Blockers and pending approvals

- **Native build blocker (pre-existing):** `npm install`'s postinstall fails — `expo-camera` 57.0.5 is installed but the
  Android scan-region patch was cut against 57.0.4. Expo Go is unaffected.
- **Live rollup repair — still awaiting approval (NOT applied).** Audit shows `Sale create` ×28 on 2026-09-10 and ×4 on
  2026-08-08 with no surviving sales; rollups for those days overstate revenue by **388 340.00**. Procedure: backup per
  `docs/22` → `DB=phonestore node scripts/rollup-audit.js` (confirm exactly 2 rows) → `… --repair`.
- `GET /closings/overview` fails under MySQL's default `sql_mode` (`ONLY_FULL_GROUP_BY`; `closing.service.ts` ~L911).
- **Deferred by instruction:** the control website does not know `rejected` and has none of the new platform
  actions (`docs/38`); administrator MFA and a delivery provider for invitations do not exist and are not faked.

## 📋 Known, not fixed

- Filter chips are 36 pt tall by design-system decision, with hit slop restoring a 48 pt target.
- Two scripts logging in the same user concurrently deadlock on `users.last_login`; harmless for one phone.
- On web, a screen pushed from a tab announces its back button as "(tabs), back". Dynamic type is handset-only.
- The counter receipts (Quick Sell, the Sell tab) print the new invoice layout but do not yet name the
  customer — those screens belong to the selling scope.
- Prisma drift report: `units.identifier` is a stored generated column from 0008 that Prisma cannot model.

## The next exact action

1. **Handset:** `docs/24` §36 P1–P15 (invoice on paper/WhatsApp, the closing drag from a label, keyboard and Save,
   the alerts and Undo, the closed-shop states, the platform sign-in) and §35 S1–S15, on the physical phone against
   the live API (Expo Go).
2. Then the older handset backlog: `docs/24` §34, §33, §32, §31, §30.
3. Fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy; decide the live rollup repair.
