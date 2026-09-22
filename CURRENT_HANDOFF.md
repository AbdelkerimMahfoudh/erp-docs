# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF** (for the correction phase below; see the parallel scope for its own state)
- Owner: **NONE** — the correction phase (CLAUDE-A, `started_at_utc: 2026-09-22T03:24Z`) closed at
  `2026-09-22T13:22Z`.
- Completed phase: **correction of the previous session's work** — the failed generic-selling
  implementation, the worsened Excel-review performance and the three screens that had not
  received the approved restyle. Six focused commits, each pushed; the decision record is
  `docs/21` "Correction of the generic selling, Excel-review performance and the three
  restyles (2026-09-22, second phase)"; the device checks are `docs/24` **§35**.
- Next intended action: **the handset run of `docs/24` §35** (S1–S15) against the live API — the
  only checks this phase could not perform. No feature is next; the product-image upgrade is
  explicitly not started.

### Parallel scope — invoice, Daily Closing, alerts, platform administration

- **Second CLAUDE-A conversation, by the user's explicit instruction** ("strictly separate
  scope … handled elsewhere"), claimed `started_at_utc: 2026-09-22T05:30Z`. Same working
  trees as the correction phase above; disjoint files.
- Scope: customer invoice PDF (`mobile/lib/receipt.ts`, share points), Daily Closing
  (`mobile/app/closing.tsx`, `mobile/lib/closing.ts`), Analyses "À examiner"
  (`mobile/components/analytics/AttentionList.tsx`, `mobile/app/analytics.tsx`,
  `mobile/lib/anomalies.ts`, `backend/src/anomalies/*`), platform Super Admin
  (`backend/src/platform/*`, `backend/src/entitlement/*`, new `mobile/app/platform/*`,
  new `mobile/lib/platform-admin*.ts`), website inclusion in mobile
  (`mobile/app/subscription-blocked.tsx`, `mobile/hooks/useAccountPortal.ts`,
  `mobile/lib/portal.ts`, `mobile/app/(auth)/verify.tsx`), and the docs they need.
- **Never touched by this conversation:** every file in the correction phase's dirty set
  (Sell an item, Choose from stock, Excel review, scanner, `BottomSheet`, `DialogHost`,
  `PhonePicker`, `quick-sell`, `sell.tsx`, `receive/file.tsx`, the receiving/selection
  rules and their tests). i18n catalogues (dirty there): this conversation stages only its
  own hunks, never the file.
- Takeover HEADs for this scope: docs `df5f37d` · backend `59381f3` (brief said
  `e9f8e7e`; `59381f3` is a clean pushed fix on top and is the baseline) · mobile
  `c26f42b` (+ the other conversation's 22 uncommitted files). Isolated work uses its own
  ports (API 3012, static 19010+, Chrome 9334) and schema (`prisma_verify_platform`).
- Progress is recorded per checkpoint in this block; the closing entry goes to
  `SESSION_LOG.md` under this conversation's own heading.
- **CP4 + CP5 backend landed (2026-09-22 ~06:05Z).** Backend `60bd6c1` (anomalies: newest-first total order, `limit`/`page` + `total`, idempotent dismiss; 44 tests), `c9e7a23` (0075: `rejected` status/state + ENTITLEMENT_REJECTED, approve/reject/setPeriodEnd, audit actor override), `f2d97f7` (POST platform/businesses with a one-time hashed Owner invitation, POST businesses/:id/owner-invitation, public owner-invitation/accept, approve/reject/period routes, state filter fixed to filter before paging; `platform-boundary.spec.ts`). 210 platform/entitlement tests green; tsc clean. **Migration 0075 applied live** after backup `~/erp-backups/phonestore-before-0075-20260922-055832.sql` (862 536 B, trailer present, hex-blob, 0 raw binary) was restore-proved into the scratch schema `prisma_verify_platform` (88 tables / 24 triggers as live; sales/units/audit_logs counts and the `units` id checksum equal; all 24 trigger bodies identical) and migrated forward there first. Live after: 2 subscriptions still `activated`, 0 coerced event kinds, 9/53/862 rows unchanged. Sanitised restore copy deleted; `prisma_verify_platform` is kept for the CP7 lifecycle run and dropped at the end. The other conversation's backend `22d8227` and mobile `de20990` (both trees clean) are preserved.

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed this phase.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 (this phase) |
| `erp-backend` | `reports-export` | **`22d8227`** is this phase's last commit (refusal names the unit by its own identifier); HEAD at closing is the parallel scope's `e7eddab`, pushed | level | the parallel scope's uncommitted work (3 files) — nothing of this phase |
| `erp-mobile` | `reports-export` | **`3cfd598`** is this phase's last commit (review ref written after render); HEAD at closing is the parallel scope's `f5c1441`, not yet pushed by it | 1 ahead (theirs) | the parallel scope's uncommitted work (13 files) — nothing of this phase |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

_Takeover baseline: docs `d0eeb74` · backend `e9f8e7e` · mobile `c26f42b`._

Backend commits this phase: `59381f3` (serial lookup whole; 409 `idempotency_conflict`;
`GET /v1/sales/client/:clientUuid`), `22d8227` (refusal message). The backend log also carries
`60bd6c1` (anomalies), which belongs to the parallel scope.
Mobile commits this phase, in order: `68a8a57` (sale selection/checkout fixes), `f62a27c` (flat
virtualized review list), `ef2c795` (review restyle), `d8e352e` (Sell an item), `de20990`
(Choose from stock), `3cfd598` (the review's group ref written in an effect, not during render).

**The backend and mobile working trees are not clean, and not because of this phase.** Backend:
`prisma/schema.prisma`, `src/entitlement/*`, `src/platform/*` and `prisma/migrations/0075_…`
(applied live by that scope after its own backup). Mobile: `app/closing.tsx`, the alerts /
anomalies files, `lib/navigation/registry.ts`, `lib/query-keys.ts` and i18n hunks. All of it is the
parallel conversation's in-progress work (its block above). This phase staged every one of its
commits by path, never touched those files, and leaves them exactly as found. Every commit of this
phase is on `origin` (`git branch -r --contains` checked for `3cfd598` and `22d8227`).

## What changed this phase

| Commit | Where | In one line |
|---|---|---|
| backend `59381f3` | `src/sales/sale-selection-rules.ts`, `sales.service.ts`, `sales.controller.ts` (+3 specs, new `sales-idempotency.spec.ts`) | presentation characters stripped only from a 15-digit IMEI, so a dashed serial is found; a changed replay of a client key → 409 `idempotency_conflict`; `GET /v1/sales/client/:clientUuid` |
| backend `22d8227` | `src/sales/sales-policy.service.ts` (+spec) | "Unit null …" refusals name the unit by IMEI or serial, else "That unit" |
| mobile `68a8a57` | `lib/phone-selection-rules.ts`, new `lib/sale-submission.ts`, `lib/sale-recovery.ts`, `lib/sheet-stack.ts`, `components/overlay/DialogHost.tsx`, `BottomSheet.tsx`, `app/quick-sell.tsx`, `app/(tabs)/sell.tsx`, i18n | client normalisation mirrors the server; lookup failure shown with the button; quantity stepper for counted products (price × quantity, receipt quantity); timeout → `GET /sales/client/:uuid` (found → finish, 404 → same key again, silent → hold + refresh); key rotated only for a new sale or a 409; duplicate-tap guard; loading released on every path; dialogs drawn inside the top-most sheet; approval sheet after the payment sheet closes; `day-range`/`expense-rules` suites repaired |
| mobile `f62a27c` | new `lib/file-review-rows.ts` (+test), `app/receive/file.tsx`, `lib/file-receiving-rules.ts` (`maskIdentifier`) | one flat virtualized list (header per group, rows of the open group only), memoised rows on primitives, derived data once per change |
| mobile `ef2c795` | `app/receive/file.tsx`, i18n | summary tiles, one filter row, flat group headers, rows with masked identifier / cost / status in words, Accept·Edit·Exclude with names, item sheet, short statuses ×14; 18 dead keys removed |
| mobile `d8e352e` | `components/sell/PhonePicker.tsx` (`PhoneChooser`), `app/quick-sell.tsx`, i18n | one section of three rows + one outlined "Sell several items" |
| mobile `de20990` | `components/sell/PhonePicker.tsx` (`StockPicker`), `app/quick-sell.tsx`, i18n | search + 48pt Filter on one row, one paginated FlatList as the screen's scroller, trailing selection column, fixed "Selected: … / Continue with this item" |

**Preserved untouched:** Money, expenses, partial payments, returns, the scanner and navigation.
No migration, no new dependency, no config change. i18n 2626 → **2646** keys, EN/FR/AR parity kept.

## Verification

| Kind | Result |
|---|---|
| **Root causes, reproduced** | serial Continue: server `normalizeIdentifier` stripped the dashes stored serials carry → 404 → notice rendered under a 30-row list beneath the fixed footer (web reproduction of the previous build; both identifier forms 404 over HTTP). Pixel: **no sale was created** (live, read-only: both Pixels in stock, no sale item, no audit row); server 201/403/201 in 85/48/38 ms; the only never-ending client path is a dialog raised over the payment sheet as a second native modal. Lost answer: the previous client said "try again" while the server had recorded the sale (22 s held response; server invoice present). Changed replay under one key silently returned the original sale. |
| **HTTP proof (isolated copy)** | `cp3-proof.cjs` **28/28**: sales of iPhone by IMEI 1 / IMEI 2 (same unit), Pixel, camera + console by serial, accessory ×2 by barcode; quantity 0 / −1 / excessive refused; sold / faulty / reserved (real transfer) refused; other branch "elsewhere" + refused; other company plain not-found, no leak; invalid serial / checksum / barcode; duplicate key = same invoice, counted once; changed payload → 409; thrown-away answer → key lookup finds it, retry replays, counted once; partial payment for every kind; Money overview and outstanding moved by exactly the sales made. Fixtures cleaned to baseline; **+23 audit rows kept** on the copy. |
| **Client reproductions (web build)** | before/after JSON in `%TEMP%\claude\cp1-client-{before,after}.json`: serial Continue 404 → **200 and the review**; below-cost and magnitude dialogs shown; plain sale; held answer — after: "No answer yet — checking…" → "The sale was recorded — the answer arrived late" → success screen. |
| **Real 100-row workbook** | `review-measure-{before,after}.json`: one open → 10 rows + **2** headers mounted (before 10 + 10 cards), DOM 498 vs 599; exclude / edit one row → **1 row + 1 header** re-render (before 1 + 10); scroll pass +15 header renders (before +20); no long tasks. Web render — the handset run is owed. |
| **Backend gate** | tsc clean · `nest build` clean · full suite **2560 tests, 0 failed** (139 suites + sales-idempotency 11, sales-policy 17) |
| **Mobile gate** | tsc clean · `expo lint` 0 errors · **31 warnings, the pre-existing set** (the single warning this phase had added — a ref written during render — was removed in mobile `3cfd598`) · **all 64 pure suites pass** · parity **2646**, identical order, 0 dups · `expo export --platform web` clean, routes `quick-sell`, `receive/file`, `(tabs)/sell` present (78 html routes) · audits on every changed screen: 0 raw colours, 0 images, 0 hardcoded copy · Expo Doctor: the same 4 pre-existing patch-version mismatches |
| **Visual matrix** | **197 captures** — EN/FR/AR × light/dark × 320/390 (12 combos) plus EN and AR at 320 with 130 % text, **14 states each** (Sell an item; stock picker unselected / selected / filter sheet; iPhone, Pixel, serial and quantity checkouts; identifier not found; review collapsed / one group open / item sheet / Accept confirmation / Exclude confirmation) and the lost-answer recovery at 390: **0 leaked keys, 0 clipped text, 0 sideways overflow, 0 overlapping text.** Every "target under 44 pt" reading is the design system's 36 pt filter chip or sheet Close (hit slop restores 48 pt) or a toast. PNGs in `%TEMP%\claude\shots-matrix\` (driver `ui-matrix.cjs`, all states verified by eye in EN, FR and AR). |
| **Physical device** | 🔴 **not run** — `docs/24` §35 S1–S15; the handset is authoritative for smoothness and the native-modal behaviour. |

## Data and process safety

- Isolated copy `prisma_verify_sell` restored from the byte-safe dump
  `C:\Users\HP\AppData\Local\Temp\claude\phonestore-20260922-pre-sell-fix.sql` (855 596 B; restore-proof: counts and
  checksums equal to live at capture). **Dropped at the end of this phase**; the dump is kept.
- Processes started by this phase and stopped by verified PID at the end: isolated API (launcher + `dist/src/main`
  on 3011), three static servers (19006/19007/19008), headless Chrome 9333. The user's MySQL (pid 22368) was never
  touched; no `mysqladmin shutdown`.
- **Live `phonestore` was not written by this phase.** Every write here went to the copy. Live did change during the
  session — 11 audit rows, one sale (invoice 00002, 5 200.00 at 04:40:18Z) and one unit, all by the `owner` account;
  none by `test@test.com` or `devtest@example.com`, the only accounts these scripts use. The 100 workbook rows were
  never imported into live stock; no permanent user was created.

## 🔴 Blockers and pending approvals

- **Native build blocker (pre-existing):** `npm install`'s postinstall fails — `expo-camera` 57.0.5 is installed but the
  Android scan-region patch was cut against 57.0.4. Expo Go is unaffected.
- **Live rollup repair — still awaiting approval (NOT applied).** Audit shows `Sale create` ×28 on 2026-09-10 and ×4 on
  2026-08-08 with no surviving sales; rollups for those days overstate revenue by **388 340.00**. Procedure: backup per
  `docs/22` → `DB=phonestore node scripts/rollup-audit.js` (confirm exactly 2 rows) → `… --repair`.
- `GET /closings/overview` fails under MySQL's default `sql_mode` (`ONLY_FULL_GROUP_BY`; `closing.service.ts` ~L911).

## 📋 Known, not fixed

- Filter chips are 36 pt tall by design-system decision, with hit slop restoring a 48 pt target; a DOM measurement
  reports them under 44 pt.
- Two scripts logging in the same user concurrently deadlock on `users.last_login` (`setLastLogin`) and one gets
  BAD_REQUEST — harmless for one phone, noted for load.
- On web, a screen pushed from a tab announces its back button as "(tabs), back". Dynamic type is handset-only.

## The next exact action

1. **Handset:** `docs/24` §35 S1–S15 on the physical phone against the live API (Expo Go). S8/S9 (airplane mode /
   slow network) prove the lost-answer path natively; S3–S5 prove the dialogs inside the sheet.
2. Then the older handset backlog: `docs/24` §34 G1–G16, §33, §32, §31, §30.
3. Fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy; decide the live rollup repair.
