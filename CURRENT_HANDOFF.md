# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Owner: **NONE**
- Last owner: **CLAUDE-A** · `started_at_utc: 2026-09-16` · finished `2026-09-16`
  (the prompt said CLAUDE-B; the user confirmed this account stays CLAUDE-A)
- Last phase: **bulk receiving from Excel and text PDF files** — complete.
- Takeover HEADs verified: docs `d920375` · backend `3540388` · mobile `494cd09`,
  all clean and level.

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. **Goals, Analytics, anomalies and the WhatsApp
summary settings are live features.** No further removal without the user's
explicit approval; a mockup that omits a feature does not authorise deleting it.
Camera OCR stays retired. Nothing was removed this phase.

## What changed — receiving a delivery from a file

| Part | Commits | Summary |
|---|---|---|
| **Backend** | `06ab826`, `80853b6` | new module `src/receiving-files/`: a tolerant `.xlsx` reader over JSZip (exceljs cannot open a namespace-prefixed workbook, which is what the shop's own file is), a pdfjs text reader, EN/FR/AR heading detection and sheet scoring, entry building with cost parsing, in-file and stored-IMEI duplicate detection across both identifier columns, catalogue matching, and `POST /purchases/file/parse` behind `import.run` + `purchase.manage`. `80853b6` fixes PDF column association: pieces keep x and width, data rows align to the heading positions, and an item spanning the next column is split by its measured width |
| **Mobile — the feature** | `5f1aba0` | the Excel button at the physical top right of the Receive header (header controls swapped in Arabic so it stays top right while text and navigation stay RTL), the picker with sheet choice, the review of 100+ phones (groups, counts, filters, per-entry and bulk corrections, exclusions, source references), confirmation through the existing `POST /purchases`, 71 keys × EN/FR/AR, 21 pure tests |
| **Mobile — fixes found by verification** | `018fe2c`, `ac62b47`, `56136e5`, `bbd5cd7` | upload the real `File` on web (the uri part uploaded nothing); the picker waits for the branch, saying so, instead of a bare 403; the paid amount moved into the success sentence (it was a stranded figure under Done); the batch kept as a draft under its own key, leaving a part-scanned delivery untouched |

**No schema migration was created or applied**, none is required, and the live
database was never written to.

### HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`80853b6`** | level | 0 |
| `erp-mobile` | `reports-export` | **`bbd5cd7`** | level | 0 |

New backend dependencies, at the user's explicit direction: `pdfjs-dist ^4.10.38`
and `jszip ^3.10.2`. Nothing else was added, upgraded or removed.

⚠️ `56136e5` carries two concerns — the success-sentence fix it names, and the
review screen's half of the draft persistence completed in `bbd5cd7`. An edit
script failed after the commit had already been chained; the commit was already
pushed, so it was completed rather than rewritten.

### Supported formats and limits

`.xlsx` and text PDFs · 8 MB · 2000 phones a file · 50 sheets · 20 000 rows a
sheet · 200 PDF pages. Formulas are read from the cached value, never executed;
macros and external links are ignored. Identifiers stay strings; a rounded
scientific-notation cell is flagged, not guessed. An image-only PDF is refused
with an explanation; a mixed PDF names the pages it could not read. OCR and
uploads to an external AI service are out of scope.

## Verification

| Kind | Result |
|---|---|
| **Backend** | `tsc` clean · **132 suites / 2 423 tests, 0 failed** (+`file-receiving` 33) |
| **Mobile** | `tsc` clean · lint **0 errors**, 1 pre-existing memoization warning in `app/receive.tsx` (present before this phase) · **53 pure suites, 0 failed** (+`file receiving` 21) · EN/FR/AR parity at compile time · every route exported, `/receive/pick` and `/receive/file` classified |
| **Expo Doctor** | **20/21** — pre-existing patch drift, `expo` 57.0.22 vs ~57.0.23 and `expo-sharing` 57.0.19 vs ~57.0.20. **Not touched**: the brief forbade dependency upgrades. Left for a deliberate upgrade |
| **End to end, isolated DB** (`prisma_verify_files`, API on `127.0.0.1:3011`) | **27 / 27**: the demo workbook read (100 phones, Read me marked as instructions, 50 dual-IMEI, 150 identifiers at 15 digits, every entry knowing its sheet and row); reading wrote nothing; unknown products flagged and never created; 100 ready once the ten fixture products exist through the normal `POST /products`; total 1 242 000 as the workbook states; **exactly 100 units created**, one purchase paid in full with no supplier, **"paid for stock" recorded once** for the whole total; either IMEI resolves the same unit (200/200); re-reading flags all 100 as already in stock; the same key with the same payload replays, with a changed payload is refused 409; two simultaneous confirmations create nothing new; a registered phone is refused while the new one is received; **a delivery whose every phone is refused creates no unit, no purchase and no payment**; an Employee is refused (403); another tenant sees none of this shop's stock; **opening inventory still creates no cash movement** |
| **PDF fixtures, isolated DB** | **11 / 11**: two-page delivery; the repeated header is not a phone; page numbers and totals are not phones; each phone knows its page; a second IMEI stays on the line it was printed on; the price on a line belongs to that line; storage and colour are read only when printed; a variant-less row is flagged rather than guessed; an image-only PDF is refused with `pdf_image_only`; a mixed PDF reads 4 and names page 2 |
| **Renders** (isolated API, 360 pt) | 28 captures — the Receive header, picker, review, needs-attention filter, bulk edit, the unsupported-file error and the received state, in EN/FR/AR × light/dark. The button measures **48×48 at x=312 of 360 in every language, Arabic included**; the scan row is untouched. No clipping, no sideways scroll, no leaked keys, no "Supplier" anywhere. One defect found and fixed (the stranded total on the success screen) |
| **Physical device** | 🔴 **none.** `docs/24` **§30 F1–F21** is open, and the file chooser (F5, F6) is an OS screen no headless browser can open |

**Verification limitation, stated plainly.** A headless browser cannot open the
operating system's file chooser, so the rendered runs were handed the workbook
through a seed parameter that existed only in a throwaway verification build.
**That hook has been removed and was never committed**; the picker in the
repository reaches the file only through `DocumentPicker`.

## Live data and cleanup

- **Live database unchanged.** The fingerprints taken before and after are
  identical — tables 88, triggers 24, units 53, sales 7 / 10 051, purchases
  10 / 21 185, payments 7, expenses 2 / 600, audit 837, role_permissions 282,
  migrations 72 (through `0073`). No demo phone reached live stock.
- Backup taken before the phase:
  `~/erp-backups/phonestore-20260916-010819-pre-file-receiving.sql`.
- `prisma_verify_files` **dropped**; the sanitised dump deleted; the web-export
  fixtures (`dist/demo.xlsx`, `dist/notes.txt`) removed.
- Isolated API `:3011`, static server `:19006` and headless Chrome `:9333`
  **stopped by port-owning PID**. The user's API `:3010`, Metro `:8081` and
  MySQL `:3306` were left running and untouched, as instructed.

## 🔴 Still pending separate approval — live rollup repair (NOT applied, NOT part of this phase)

**Proven cause:** the audit trail shows `Sale create` ×28 on 2026-09-10 and ×4 on
2026-08-08 with no surviving `sales` rows — verification fixtures hard-deleted
outside the app — and `RollupListener` has no path that recomputes a rollup when
source rows vanish.

| Branch-day (Demo Phone Store / Main Store) | Rollup revenue | Ledger | Rollup net | Sales r/l |
|---|---|---|---|---|
| 2026-08-03 | 1 000.00 | 1 000.00 | 200.00 | 1/1 — correct |
| **2026-08-08** | 40.00 | 0.00 | 31.80 | 1/0 |
| **2026-09-10** | 388 300.00 | 0.00 | 328 300.00 | 6/0 |

Overstated by **388 340.00**; proven repairable on an isolated restore. Live Home
still shows 328 300 profit. Procedure (from `backend/`): backup per `docs/22` →
`DB=phonestore node scripts/rollup-audit.js` (confirm exactly these 2 rows) →
`DB=phonestore node scripts/rollup-audit.js --repair`.

## 📋 Known, not fixed

- On web, a screen pushed from a tab announces its back button as "(tabs),
  back" (the route-group name). The native stack offers no label option; it
  needs a navigation-level fix.
- Home's month figures on live still include the overstated rollups above.
- There is no Customers screen; building one would be a new feature.
- Serial-tracked items keep their serial through Create product only when typed
  again; the pending intake holds IMEIs and product barcodes, not serials.
- No catalogue images — [`docs/47`](docs/47_CATALOGUE_IMAGES_SCOPE.md).

## Unresolved risks and decisions

Fifteen risks with severity, evidence, owner and gate in
[`docs/41`](docs/41_RELEASE_READINESS.md) §6 — 🔴 R1 nothing has run on a
physical iPhone · R2 no Administrator MFA · R3 no off-machine database backup ·
🟠 R4 dependency advisories recorded and not bumped · R5–R10 · 🟡 R11–R15.

Ten owner decisions in [`docs/45`](docs/45_EXTERNAL_DECISIONS.md); **D4 hosting,
D5 database hosting and D6 backups are the critical path and block staging.**
The pre-release security gate (`docs/48`) remains a release blocker and is not
started.

## Gates

| # | Gate | State |
|---|---|---|
| 1 | Automated verification | ✅ green — backend 2 423, mobile 53 suites, isolated 27 + 11 |
| 2 | Browser verification | ✅ passed |
| 3 | **Physical-device acceptance** | 🔴 not started — `docs/24` §30 (21 checks), §29, §28, §27, §26 and §25 all open |
| 4 | Staging deployment | 🔴 not started |
| 5 | Production launch | 🔴 not started |

⚠️ **Check freshness before trusting any server you find running.** Several
failures on this project were one stale process: resolve the PID and compare its
start time against the last commit before concluding anything.

## The next exact action

1. **Run `docs/24` §30 F1–F21 on a handset** with a real 100-phone workbook and
   a real PDF — especially the file chooser (F5, F6), which nothing automated
   can exercise.
2. **Approve or decline the live rollup repair** above.
3. Then the remaining device sections, §29 and §28 first.
