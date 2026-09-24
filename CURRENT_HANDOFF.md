# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Owner: **NONE**
- Last session: **CLAUDE-A**, `started_at_utc: 2026-09-24T02:20Z`, closed `2026-09-24T04:05Z`. Takeover HEADs were docs `a6d0762` ·
  backend `a8fc4fe` · mobile `57deb64` (all clean, level); the previous handoff matched the repositories.
- **Completed phase: the physical opening, the date selector and three corrections (migration 0077).** Decision
  record: `docs/21` "The physical opening, the date selector and three corrections (2026-09-24)"; audit and contract:
  `docs/50` §6; rules 25a and 27 in `docs/04`; device checks: `docs/24` §37 H9–H10, C12–C16.
- Next intended action: **the handset runs** — `docs/24` §37 (H1–H10, C1–C16), then §36, §35 and the older backlog,
  against the live API in Expo Go. No feature is next.
- The session before: **CLAUDE-A**, `started_at_utc: 2026-09-23T05:58Z`, closed `2026-09-24T02:05Z`. The user's usage limit
  paused it between ~`2026-09-23T07:35Z` and `2026-09-24`; on resume the machine's MySQL was found stopped
  (service `wampmysqld64` STOPPED, no `mysqld`) and a session `mysqld` on the WAMP data directory was run for
  the remaining verification and shut down again at close-out — the service is left exactly as found.
- Its takeover HEADs were docs `f1284e4` · backend `decb699` · mobile `e43b551` (all clean, level with `origin`);
  the previous handoff was complete and matched the repositories.
- Completed before it: **the Home dashboard and the business-day closing (migration 0076).** Decision record:
  `docs/21` "The Home dashboard and the business-day closing (2026-09-23)"; audit and contract: `docs/50`;
  business rules: `docs/04` §F (24a–28b, 36); device checks: `docs/24` §37 (H1–H8, C1–C11).

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed by this phase.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`3fa4801`** | level | 0 |
| `erp-mobile` | `reports-export` | **`904e3ac`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

Backend commits, in order: `29b9cc7`, `003efb2`, `a8fc4fe` (0076), `3fa4801` (0077). Mobile: `40c73d0`, `8230802`,
`944459e`, `57deb64` (0076), `904e3ac` (0077). Every one is on `origin`.

## What changed

| Commit | Where | In one line |
|---|---|---|
| backend `29b9cc7` | `prisma/migrations/0076_business_day_and_reopen`, `schema.prisma`, `src/common/business-day.ts` + `business-day/`, `src/closing/*`, `src/messaging/templates.ts`, `whatsapp-channel.ts`, `src/analytics/rollup.service.ts`, `summary.service.ts`, `src/sales/*`, the expenses / corrections / returns / purchasing services | the 06:00 local business date as one pure rule and one assigning service; `business_date` stored on `sales`, `payments`, `supplier_payments` (backfilled with the old UTC keying); rollups, the closing, the movements and "collected" keyed on it; a close is a counted snapshot plus a `closing_events` row; reopen, auto-reopen on a sale or a payment, reclose with fresh counts and the discrepancy reconciliation; cash carried forward as the opening balance; the Owner's early start; the Owner notices (in-app first under a dedupe key, then the WhatsApp boundary) |
| backend `003efb2` | `src/rbac/*`, `src/users/user-management.service.ts`, `users.controller.ts`, `scripts/generate-catalogue-migration.ts` | `closing.perform` delegable to a manager or an employee, at most two per branch (`PUT/DELETE /users/:userId/branches/:branchId/delegations/closing`); the Store Manager role no longer holds it; the Owner-only `closing.start_early` (catalogue 63) |
| backend `a8fc4fe` | `src/analytics/dashboard.*`, `home-series.ts`, `src/consignment/partner-ranking.service.ts`, `connections.controller.ts`, `src/inventory/*` | `GET /home?period=today\|week\|month` (exact business-date ranges, bars asserted to sum to the value, the top partner, three masked arrivals, the closing card); `GET /partners/ranking?page&limit` (settled consignments and fully paid partner-store sales, nothing counted twice); `GET /inventory?trackingType=` |
| mobile `40c73d0` | `app/(tabs)/index.tsx`, `lib/home.ts`, `lib/home-day.ts` (+ test), `components/home/SalesBars.tsx`, `lib/period.ts`, `lib/query-keys.ts`, the Money and Results screens, `PeriodSelector`, i18n EN/FR/AR, `lib/layout.test.ts`; `lib/home-figures.ts` removed | Home rebuilt on the one read: the period control, four figures with the owed scope, bars as plain views, the top boutique, the latest phones masked, the closing card, an honest "refreshed" footer; Money and Results ask the server which business day it is |
| mobile `8230802` | `app/closing/index.tsx` (new), `app/closing/count.tsx` (moved), `components/closing/ReopenSheet.tsx`, `app/partners/ranking.tsx`, `lib/closing.ts`, the registry, `lib/closing-screen.test.ts` | Closing & history with the standing in words and colour, expected cash with its opening balance, the movement since the last count, one action, the history; the before-06:00 choice (Owner: continue or start early; anybody else the safe default alone); the boutique ranking |
| mobile `944459e` | `app/(tabs)/inventory.tsx`, `app/team.tsx`, `types/api.ts` | Stock's newest-received deep-link (Phones + All statuses + newest received, `trackingType=imei`); Team's closing delegates with the limit stated |
| mobile `57deb64` | `app/partners/ranking.tsx` | the ranking’s "refreshed" footer counts from the phone’s own receipt of the data, as Home does (the fake clock exposed the server-stamped version); the duplicate `lib/format` import merged |
| backend `3fa4801` | `prisma/migrations/0077_physical_opening`, `schema.prisma`, `src/common/business-day.ts`, `src/closing/closing-lifecycle.ts`, `closing.service.ts`, `closing.controller.ts`, `dto/open-day.dto.ts`, specs | the `opened` event kind; `POST /closings/open` (`closing.count`); the door rules; the timeline with *First activity*, pre-0076 rows read back and store-local times; `opening` / `door` / `canOpen` / `localNow` / `lastCountedLocalTime` on the view; a rowless past day needs review |
| mobile `904e3ac` | `app/closing/index.tsx`, `components/closing/ReopenSheet.tsx`, `lib/closing.ts`, `lib/home-day.ts` (+ test), `app/(tabs)/index.tsx`, `app/(tabs)/inventory.tsx`, i18n EN/FR/AR | the date selector, the opening line, *Open the boutique*, store-local rows; the sheet on the server's clock; the owed line wraps at 320; the Stock list from Home masks |
| docs (this commit) | `docs/50` (new), `docs/04` §F, `docs/21`, `docs/24` §37, `SESSION_LOG.md`, this file | the audit and contract, rules 24a–28b and 36, the decision record, the device checklist, the session entry |

## Verification

| Kind | Result |
|---|---|
| **Backend gate** | tsc clean · `nest build` clean · `prisma validate` · `migrate status` up to date (0076) · full suite **150 suites / 2 653 tests, 0 failed** |
| **Live lifecycle (isolated copy, built API, fake clock per phase, development-log WhatsApp channel)** | `home-lifecycle.mjs` **57/57** — the step list is in `docs/21` (same-day close → reopen → sale → reclose; a seller's sale after the close reopening the day; two concurrent recloses; deduplicated Owner notices; two delegates, a third refused, revocation, cross-branch and cross-company refusals; the 03:00 early start once; 05:59 vs 06:00 per branch; the month and year edges; a later debt payment; the opening balance carried forward) |
| **Migration 0076** | backup `~/erp-backups/phonestore-before-0076-20260923-063747.sql` (864 179 B, hex-blob, trailer present, 0 raw binary) → restore-proved into `prisma_verify_home` (89 tables / 24 triggers, counts and the `units` checksum equal) → 0076 forward there (0 rows where the stored date differs from the old keying; rollups and the one closing byte-identical) → **applied to live at `2026-09-23T07:14:50Z`** (`migrate status` up to date; live rows unchanged around it: 9 sales / 53 units / 862 audit rows / 9 payments / 1 closing / 6 rollups; `permissions` 62 → 63; the manager's `closing.perform` mapping gone; the status enum extended) |
| **Mobile gate** | tsc clean · `expo lint` 0 errors, 0 warnings in this scope's files · Expo Doctor's four pre-existing mismatches · **69 pure suites pass** · parity **2 897** keys, identical order, 0 duplicates · web export with every route |
| **Render matrix** | **48 captures** (`home-matrix.mjs` + `ranking-matrix.mjs`: the export against the copy, headless Chrome at 3×): Home EN/FR/AR × light/dark at 393, 320/360/430, 130 % text, Today / 7 days / This month, a seller's Home, scrolled; the Stock deep-link; the ranking with two real partner stores EN/FR/AR + dark 320; Team's closing delegates EN/AR; Closing & history open → closed → reopened with a sale in the history (EN/FR/AR, dark 320, 130 %), a delegate's view, the counting screen; at 03:00 the closed day and the reopen sheet (EN/FR/AR, dark, 320) — 0 leaked keys, 0 sideways overflow, 0 empty screens. The first run's three ranking captures were empty: the fixture's connection request met a non-discoverable Test Store (the 404 the product gives by design) and a third trade priced below the set price was refused; the rerun connects through the product's own request-and-accept path and prices at or above the set price. The one defect the matrix exposed — the ranking footer formatting the server's timestamp, which read "in 21 hours" under the fake clock — is fixed in `57deb64`. Web renders, not device verification |
| **0077 phase — backend** | full suite **150 suites / 2 658 tests, 0 failed** · tsc, `nest build`, `prisma validate` clean |
| **0077 phase — lifecycle (isolated copy)** | `open-lifecycle.mjs` **29/29** — the step list is in `docs/21` (07:25 with no opening and no early start; permission and cross-company refusals; open / refuse twice / first activity / close / reopen / reclose / reopen on one date; 15 days ago, 2026-09-22, 2026-09-15 through the selector; 05:59 vs 06:00 with openings) |
| **Migration 0077** | backup `~/erp-backups/phonestore-before-0077-20260924-034205.sql` (868 828 B, hex-blob, trailer present, 0 raw binary) → restore-proved (90 tables / 24 triggers, counts and the `units` checksum equal) → 0077 on the copy → **applied to live at `2026-09-24T03:56:36Z`** (live rows unchanged: 9 sales / 53 units / 865 audit rows / 9 payments / 1 closing / 6 rollups / 63 permissions / 0 closing events; 90 tables / 24 triggers; latest migration 0077_physical_opening) |
| **0077 phase — mobile** | tsc clean · lint 0 errors · 69 pure suites · parity **2 916** · render matrix **26 captures** — 0 leaked keys, 0 sideways overflow, 0 empty screens, 0 full identifiers on the masked list (the coarse check first flagged the three Stock captures because it had joined a demo product name's ten digits, the masked last four and a price across lines; re-captured with a per-line check: 0 findings; the read-back of a pre-0076 count was proved on the Test Store's own branch, the one place the copy holds such a row) |
| **Physical device** | 🔴 **not run** — `docs/24` §37 H1–H10, C1–C16 (and §36, §35 from the previous phases) |

## Data and process safety

- **Live `phonestore` received exactly one change from each phase: migration 0076, then migration 0077** (each after
  a backup and its restore-proof). Every other write went to the copy `prisma_verify_home`, **dropped at close-out**.
  Live read back after the 0076 close-out: 9 sales / 53 units / 862 audit rows / 9 payments / 1 closing / 6 rollups / 63 permissions / 0 store connections / 0 closing events / 0 discoverable companies / 0 users with a phone number; 90 tables / 24 triggers; latest migration `0076_business_day_and_reopen`.
- The known **388 340.00 rollup overstatement is untouched** and still awaits the approved repair.
- Processes started here and stopped: the isolated API (3012, restarted per fake-clock phase), the static
  server (19012), headless Chrome (9334, own profile), and the session `mysqld` described above. The user's API
  and Metro were never touched.
- Throwaway credentials (a password hash on five demo logins and on the Test Store's Owner, e-mails on two
  soft-deleted logins, one phone number) existed on the copy only. No file holding a token or a credential was
  written inside any repository.

## 🔴 Blockers and pending approvals

- **Native build blocker (pre-existing):** `npm install`'s postinstall fails — `expo-camera` 57.0.5 is installed but the
  Android scan-region patch was cut against 57.0.4. Expo Go is unaffected.
- **Live rollup repair — still awaiting approval (NOT applied).** Audit shows `Sale create` ×28 on 2026-09-10 and ×4 on
  2026-08-08 with no surviving sales; rollups for those days overstate revenue by **388 340.00**. Procedure: backup per
  `docs/22` → `DB=phonestore node scripts/rollup-audit.js` (confirm exactly 2 rows) → `… --repair`.
- `GET /closings/overview` under MySQL's default `sql_mode` (`ONLY_FULL_GROUP_BY`): not re-checked in this phase; live
  runs with `sql_mode=""`.
- **WhatsApp:** no provider adapter exists and none is faked; the three closing templates are registered with
  `providerTemplateName: null` and await approved copy. On live no user has a phone number, so nothing can be sent.
- **Deferred by instruction:** the control website (`docs/38`) is unchanged.

## 📋 Known, not fixed

- Selling a phone outright to another store is still the documented contract gap: the ranking counts settled
  consignments and fully paid partner-store sales only, and says so.
- The Stock tab's own list shows full identifiers (rule 19d asks for masking there too); the list reached from Home's
  "Latest phones received" masks, as briefed on 2026-09-24.
- Home keeps its pending-work rows (transfers, returns, refunds) when there are any — not in the reference, kept on purpose.
- Team's closing delegates live inside the person's sheet, beside the price-edit delegation.
- The counting screen shows no "since last count" figure; Closing & history does.
- Filter chips are 36 pt tall by design-system decision, with hit slop restoring a 48 pt target.
- Two scripts logging in the same user concurrently deadlock on `users.last_login`; harmless for one phone.
- On web, a screen pushed from a tab announces its back button as "(tabs), back". Dynamic type is handset-only.
- Prisma drift report: `units.identifier` is a stored generated column from 0008 that Prisma cannot model.

## The next exact action

1. **Handset:** `docs/24` §37 H1–H10 (Home at each period, the bars, the top boutique, the arrivals, the closing
   card, the offline and stale labels, 130 % text, RTL, the owed line at 320, the masked list from Home) and C1–C16
   (count → close → reopen → sale → reclose, the 03:00 choice as Owner and as a delegate, the 06:00 cutoff, the
   Owner's in-app notices, *Open the boutique*, the selector, a past day, the sheet on the store's clock), on the
   physical phone against the live API (Expo Go).
2. Then `docs/24` §36 P1–P15, §35 S1–S15 and the older backlog (§34 … §30).
3. Decide the live rollup repair; fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy.
