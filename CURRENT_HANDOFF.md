# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Owner: **NONE**
- Last owner: **CLAUDE-A** · 2026-09-22 (01:37Z → complete)
- Last phase: **inventory correction, Excel-review performance, generic selling and the
  global card hierarchy** — seven checkpoints, **all done, committed and pushed**. Money,
  partial payments, expenses, the scanner and navigation are preserved as built.
- Took ownership from a clean **READY_FOR_HANDOFF** at docs `035a60e` · backend `c4d4534`
  · mobile `45f4905` · control-web `c764d63`. Same account (CLAUDE-A); a resumption.
- **What shipped (see [`docs/21`](docs/21_PRODUCT_DECISIONS.md) for the full decisions):**
  - **CP1 audit** — established there was no unit-correction endpoint, no `version` column
    (`updatedAt` is the optimistic lock), that model/variant/barcode live on `Product`, and
    the exact card-nesting offenders (by an AST audit).
  - **CP2 stock-item correction** — backend `PATCH /units/:id` (`22bd19f`) and the mobile
    pencil + correction screen (`69cc1a0`). `unit.add` + `cost.view` for cost; `updatedAt`
    compare-and-swap; **no migration**.
  - **CP3 card hierarchy** — `Toggle.flat`; Appearance & language rebuilt as one RowGroup;
    hub/settings/catalogue pickers flattened; AST `no-nested-surfaces` guard (`fa3f89b`).
  - **CP4 review performance** — single open group, memoised rows, per-phone
    Accept/Edit/Remove, the `formula_value` advisory/Accept model (`fc5be5c`).
  - **CP5/CP6 generic selling** — the selection lookup resolves IMEI / serial / barcode
    (barcode → quantity product), a `kind` discriminator, the redesigned Choose-from-stock
    picker, generic "item" copy (backend `e9f8e7e`, mobile `365daf4`).
  - **CP7 Money terminology** — "Items sold", "Item sales", today-only daily-expense
    (`c26f42b`).
- Next intended action: **none — the brief is complete.** The only work owed is device /
  isolated-render verification (see Verification and docs/24 §34); nothing is blocking.

### What happened on 2026-09-21 — two conversations, one label

The clock on this PC is UTC+0 (Greenwich Standard Time); times below are real UTC.

- 18:09Z the visual-fidelity conversation took ownership; 19:25–19:31Z it drafted its
  closing docs **ahead of** its final render and teardown, and left them uncommitted.
- ~20:04Z and again from 21:25Z the user worked in a **second conversation with the same
  label**. Reading the uncommitted draft as an interrupted session, it committed those
  files as found (`d7155bb`), appended a reconstructed log entry, claimed the next
  brief, and stopped the isolated API, static server, headless Chrome and the
  `prisma_verify_ui` schema — which the first conversation was still using. Both ran
  against one working tree from 21:25Z to ~21:37Z. No file was edited by both; the only
  loss was the render run then in flight.
- 21:32Z the first conversation pushed mobile `45f4905` (the last narrow-width fixes),
  which the 21:25Z baseline (`71970bf`) does not include.
- 23:48Z the PC was restarted; every process ended. 23:52Z this conversation resumed.

**Lesson recorded:** one label for two conversations defeats the ownership rule. A draft
closing handoff must never sit uncommitted on disk while work continues; write it last.

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed this phase; fixed costs, salary, reference, note, discount,
return policy and split payment moved under one-tap disclosures, never away.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`e9f8e7e`** — generic sale selection | level | 0 |
| `erp-mobile` | `reports-export` | **`c26f42b`** — Money terminology | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

_Takeover baseline: backend `c4d4534` · mobile `45f4905` · docs `035a60e`._

Backend commits this phase: `22bd19f` (CP2 correction), `e9f8e7e` (CP5 selection).
Mobile commits this phase: `69cc1a0` (CP2), `fa3f89b` (CP3), `fc5be5c` (CP4),
`365daf4` (CP5/CP6), `c26f42b` (CP7).

## What changed this phase

The full decision record is `docs/21` "Inventory correction, Excel-review
performance, generic selling and the global card hierarchy (2026-09-22)"; the
device checklist is `docs/24` §34. One backend contract changed (the sale
selection lookup, additively), **no migration**, no dependency, no config.

| Checkpoint | Where | In one line |
|---|---|---|
| CP2 correction | backend `inventory.*`, mobile `app/unit/edit.tsx`, `app/unit/[identifier].tsx`, `lib/unit-correction.ts` | `PATCH /v1/units/:id` (`unit.add`; cost needs `cost.view`); in-stock only; product re-association; `updatedAt` compare-and-swap, no migration; pencil on the unit detail |
| CP3 card hierarchy | `components/ui/Toggle.tsx` (+`flat`), `app/appearance.tsx`, `components/navigation/LanguageRow.tsx`, `app/hub/[id].tsx`, `app/settings.tsx`, `components/catalog/*` | one bordered surface per section; AST guard `lib/design/no-nested-surfaces.test` |
| CP4 review perf | `app/receive/file.tsx`, `lib/file-receiving-rules.ts`, `lib/file-batch-store.ts` | single open group, memoised rows, per-phone Accept/Edit/Remove; `formula_value` advisory + `acknowledged` |
| CP5/CP6 generic selling | backend `sale-selection*`, mobile `components/sell/PhonePicker.tsx`, `app/quick-sell.tsx`, `lib/phone-selection-rules.ts`, `types/api.ts` | selection resolves IMEI/serial/barcode (barcode→quantity product), `kind` discriminator; Choose-from-stock redesigned (no thumbnails, Filter sheet, type-labelled rows); generic "item" copy |
| CP7 Money | `app/(tabs)/money-hub.tsx` | "Items sold", "Item sales", today-only daily expenses |

**Preserved untouched:** the Money redesign, partial payments, expenses, the
scanner and navigation. i18n grew from 2577 → 2626 keys, EN/FR/AR parity kept.

**Found, not fixed (backend, recorded for the next session):** `GET /closings/overview`
answers 400 "Database request error" under MySQL 8's default `sql_mode`
(`ONLY_FULL_GROUP_BY`): `closing.service.ts` ~L911 selects a non-aggregated
`receiving_account_id` in a GROUP BY. Live works only because WAMP's service group sets
`sql_mode=""`. Any default-configured deployment (staging, `docs/45`) will hit it.

## Verification

| Kind | Result |
|---|---|
| **Backend** | `tsc` clean · `nest build` clean · `prisma validate` clean · migration status **up to date, no drift** (no migration added) · permission catalogue **62/62** · full suite **138 suites / 2529 tests, 0 failed** (was 2524; +5 correction/authorization/barcode tests) |
| **Mobile** | `tsc` clean · `expo lint` **0 errors / 31 warnings** (baseline, no new) · **59 pure suites pass** (repaired `phone-selection` to run; the 2 remaining failures — `day-range`, `expense-rules` — are pre-existing extensionless-import issues untouched by this work) · EN/FR/AR **parity 2626, identical order, 0 dups** · AST `no-nested-surfaces` **0 offences / 143 files** · `expo export --platform web` clean, all routes build (incl. the new `/unit/edit`) · audits clean (no raw hex, no product images, no hardcoded copy in the changed files) · Expo Doctor: **4 packages out of date (pre-existing patch drift)** |
| **Isolated web-render matrix** | 🔴 **owed** — EN/FR/AR × light/dark × 320/390 of the changed screens (Appearance, file review, sell picker, Money, unit edit). The card-flattening is proven more strongly by the AST guard than a screenshot; copy and structure by parity + source-scan tests. |
| **Real 100-item workbook** | 🔴 **owed** — the single-open/unmount behaviour is proven by source-scan assertions; the physical reproduction on isolated data is not yet run. |
| **Physical device** | 🔴 **none** — Dynamic Type and touch smoothness cannot be stood in for; `docs/24` **§34** lists the checks. |

## Services

- **Nothing was started or stopped by this phase.** No dev server, no isolated
  environment, no database process was launched — the work is code, and every check
  above is a build, a type-check, a unit suite or a static export. If the user's
  live MySQL `:3010`/Metro `:8081` are running they were not touched; if they are
  down they can be started normally (WAMP MySQL → live API → Metro).
- The isolated verification environment (per the memory note) was **not** rebuilt;
  the owed render matrix would use it. No `prisma_verify_*` schema exists from this
  phase.

## 🔴 Blockers and pending approvals

- **Native build blocker (pre-existing):** `npm install`'s postinstall fails —
  `expo-camera` 57.0.5 is installed but the Android scan-region patch was cut
  against 57.0.4 (alignment `e960ef6`). Expo Go is unaffected. A native build must
  re-cut the patch and re-verify scanning on Android.
- **Live rollup repair — still awaiting approval (NOT applied).** Audit shows
  `Sale create` ×28 on 2026-09-10 and ×4 on 2026-08-08 with no surviving sales
  (fixtures hard-deleted outside the app); rollups for those days overstate
  revenue by **388 340.00** (Home shows 328 300 profit). Procedure: backup per
  `docs/22` → `DB=phonestore node scripts/rollup-audit.js` (confirm exactly 2
  rows) → `… --repair`.

## 📋 Known, not fixed

- On web, a screen pushed from a tab announces its back button as "(tabs), back".
- A bottom sheet's Close button is 36 pt with no hit slop (app-wide, pre-existing).
- Dynamic type cannot be exercised in a web render; handset only.
- No catalogue images (`docs/47`). The pre-release security gate (`docs/48`) is
  not started. Owner decisions D4–D6 (hosting, database hosting, backups) block
  staging (`docs/45`); release risks in `docs/41` §6.

## The next exact action

The seven-checkpoint brief is **complete and pushed**; nothing about it is left to
implement. What remains is verification and pre-existing debt, none of it blocking:

1. **Owed verification of this phase:** run the isolated web-render matrix (EN/FR/AR ×
   light/dark × 320/390) and the real 100-item workbook reproduction against isolated
   data, then the handset checks in **`docs/24` §34**. Use the isolated environment from
   the memory note; do **not** import the 100 items into live stock.
2. Handset backlog from the earlier phase still stands: **`docs/24` §33 V1–V14**, then §32, §31, §30.
3. Fix the `ONLY_FULL_GROUP_BY` defect in `closing.service.ts` (~L911) before any staging deploy.
4. Decide the live rollup repair (still awaiting approval — see Blockers).
