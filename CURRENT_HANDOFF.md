# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Owner: **CLAUDE-A** · `started_at_utc: 2026-09-18` — Money redesign: balances, period
  sales/collected/outstanding, partial payments with customer/store debtors,
  later collections, daily expenses. Takeover HEADs: docs `20fb84f` · backend
  `2e34ce1` · mobile `2530b22`, all clean and level. Next: audit the existing
  sale, payment, customer, partner, account and closing contracts.
- ⚠️ **Migration `0074_sale_receivables` APPLIED TO LIVE** at 2026-09-18 14:02 UTC. Backups:
  `~/erp-backups/phonestore-20260918-132538-pre-0074-receivables.sql` (845 704 B, restored
  into `prisma_verify_money` with a fingerprint identical to live) and
  `phonestore-20260918-140210-pre-0074-apply.sql` (845 704 B, taken immediately before; live
  proven unchanged between the two). 7 of 7 payments backfilled with their seller as recorder.
  Backend `c7e1900` pushed. Temporary DB `prisma_verify_money` still exists (drop at the end).
- Last phase: **the file review screen, rebuilt as a staged workflow** after a
  physical-iPhone finding. Takeover HEADs were docs `1a1035b` · backend
  `2e34ce1` · mobile `bc2efe5`, all clean and level. (The prompt said CLAUDE-B;
  this account stays CLAUDE-A per the user's standing correction.)
- The phase before: **the iPhone upload path** — code complete, device proof owed.
- Last owner: **CLAUDE-A** · finished `2026-09-16` (the prompt said CLAUDE-B; the
  user confirmed this account stays CLAUDE-A).
- The phase before: **bulk receiving from Excel and text PDF files** — complete.

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
| `erp-backend` | `reports-export` | **`2e34ce1`** | level | 0 |
| `erp-mobile` | `reports-export` | **`2530b22`** | level | 0 |

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
| **Backend** | `tsc` clean · **132 suites / 2 427 tests, 0 failed** (+`file-receiving` 37, including four that keep the route wired into `AppModule`) |
| **Mobile** | `tsc` clean · `expo lint` **0 errors / 32 warnings** (baseline) · **53 pure suites, 0 failed** (`file receiving` 21 → **55**; `registry` 52) · EN/FR/AR parity at compile time and asserted per screen · every route exported |
| **Expo Doctor** | **20/21** — pre-existing patch drift, `expo` 57.0.22 vs ~57.0.23 and `expo-sharing` 57.0.19 vs ~57.0.20. **Not touched**: the brief forbade dependency upgrades. Left for a deliberate upgrade |
| **End to end, isolated DB** (`prisma_verify_files`, API on `127.0.0.1:3011`) | **27 / 27**: the demo workbook read (100 phones, Read me marked as instructions, 50 dual-IMEI, 150 identifiers at 15 digits, every entry knowing its sheet and row); reading wrote nothing; unknown products flagged and never created; 100 ready once the ten fixture products exist through the normal `POST /products`; total 1 242 000 as the workbook states; **exactly 100 units created**, one purchase paid in full with no supplier, **"paid for stock" recorded once** for the whole total; either IMEI resolves the same unit (200/200); re-reading flags all 100 as already in stock; the same key with the same payload replays, with a changed payload is refused 409; two simultaneous confirmations create nothing new; a registered phone is refused while the new one is received; **a delivery whose every phone is refused creates no unit, no purchase and no payment**; an Employee is refused (403); another tenant sees none of this shop's stock; **opening inventory still creates no cash movement** |
| **PDF fixtures, isolated DB** | **11 / 11**: two-page delivery; the repeated header is not a phone; page numbers and totals are not phones; each phone knows its page; a second IMEI stays on the line it was printed on; the price on a line belongs to that line; storage and colour are read only when printed; a variant-less row is flagged rather than guessed; an image-only PDF is refused with `pdf_image_only`; a mixed PDF reads 4 and names page 2 |
| **Renders** (isolated API, 360 pt) | 28 captures — the Receive header, picker, review, needs-attention filter, bulk edit, the unsupported-file error and the received state, in EN/FR/AR × light/dark. The button measures **48×48 at x=312 of 360 in every language, Arabic included**; the scan row is untouched. No clipping, no sideways scroll, no leaked keys, no "Supplier" anywhere. One defect found and fixed (the stranded total on the success screen) |
| **Backend, from a PC script** | **17 / 17** against the live API on `192.168.100.3:3010`. Proves the backend, **not** the phone |
| **iOS bundle** | `expo export --platform ios` clean; the new upload path is in the bundle |
| **Physical device** | 🔴 **still none.** `docs/24` **§30 F1–F21** and **§30b F22–F33** are open. The file chooser itself (F5, F6, F33) is an OS screen no automated run can open |

**Verification limitation, stated plainly.** A headless browser cannot open the
operating system's file chooser, so the rendered runs were handed the workbook
through a seed parameter that existed only in a throwaway verification build.
**That hook has been removed and was never committed**; the picker in the
repository reaches the file only through `DocumentPicker`.

## 🖥 The review screen, rebuilt (physical-iPhone finding)

The workbook uploads and parses on the handset. The **review** of the hundred
phones did not survive a real screen: "Exclude all 100" overlapped the sentence
explaining what to do, the reason each phone was held up was never shown, a
warning icon sat beside a perfectly good price, IMEIs ran as an unlabelled
column, tiny chevrons offered no action, and the whole payment section filled
the screen while nothing was ready to pay for.

**It is now Review → Payment → Confirm.**

- **Review** opens on a stacked summary card: the headline, a sentence, a
  Ready / Needs attention / Excluded breakdown, and one action aimed at the real
  problem ("Match products"). A compact footer carries ready, excluded and the
  total, with **Continue to payment** disabled — and saying why — until every
  phone is corrected or deliberately excluded.
- **Payment is not rendered at all** until the review is finished. Paid-in-full
  receiving, the idempotency key and the exactly-once accounting are untouched.
- **One collapsed card per exact variant**: count, subtotal, the reason it is
  held up, and "Match product for all 10" where one choice answers the group.
  Only products every phone in the group matched are offered; nothing is
  auto-created.
- **Phones render only while their group is open**, in a `FlatList` — a file of
  2000 scrolls like one of 10.
- **Every value is labelled** (IMEI 1, IMEI 2, Unit cost, From) on its own
  divided card, so two identifiers never read as two phones, and the warning is
  attached to a written reason instead of to the money.
- **"Bulk edit"** replaces "Change several at once", names the field it changes,
  and states how many phones it affects **and how many already differ** first.
  **"Exclude all"** left the alert for the quiet end of the review.
- Nothing inside a card is absolutely positioned.

**The floating blue gear is Expo Go's, not the app's** — no `expo-dev-client`
dependency, and no absolutely-positioned control in the app's tree. It does not
exist in a production build.

### Renders — 5 languages/themes × 4 widths, isolated API

100 needing product matching · one group corrected and 90 left · the
needs-attention filter · bulk edit · the match sheet · an expanded group with
single- and dual-IMEI phones · all ready · the payment step. EN/FR/AR, light and
dark, at 320, 360, 390 and 430 pt.

**No overlapping text in the normal flow, nothing clipped, no sideways scroll,
no leaked keys, no missing control.** Two measurements need saying plainly:

- The filter chips measure 36 pt painted, with `hitSlop` restoring 48 — the
  app's existing, deliberate pattern, which a DOM measurement cannot see.
- **A bottom sheet's Close button is a 36 pt `IconButton` with no hit slop.**
  Pre-existing and app-wide, not introduced here, so it was left alone rather
  than changing shared chrome unilaterally. The sheet is still dismissible by
  backdrop and swipe. Worth a deliberate fix.
- **Dynamic type could not be exercised.** React Native Web emits fixed pixel
  sizes: at a 135 % root font size every control measured identically. It stays
  a handset check (`docs/24` §30d F62).

## 🔧 The iPhone upload — two faults, one after the other

### Fault 1 (fixed): the server was not running the feature

Covered below. Real, and not the whole story.

### Fault 2 (fixed in code, **unproved on a handset**): React Native built the multipart part from a uri iOS would not let it read

The second attempt failed with "The app could not reach the server" on an iPhone
that **had just registered a phone and completed a sale**. Connectivity,
authentication and the API origin were all known good; the failure was in the
upload alone, and the message was wrong.

On a phone the picked file belongs to Files, iCloud Drive or another document
provider and is readable only while iOS says so. React Native assembles its
multipart part from that uri inside the networking layer, so an unreadable uri
fails there — no status, no response, nothing to tell apart from bad Wi-Fi. The
app's own fallback then reported "offline", which is what the screen showed.

**Now:** the file is copied into the app's cache and checked there (exists, has
bytes, the count matches what the picker declared, a workbook begins with
`PK\x03\x04`, the name still ends `.xlsx`, the MIME type filled in when the
picker gave none), then uploaded from that verified copy by **Expo's native
uploader** — field `file`, boundary generated by the platform, the shared
`API_V1_URL` and the same authorisation and branch headers as the working
register-phone and sale calls. No URL is constructed in the upload helper, and
no content type is set by hand.

**Classification now separates** the file being gone, the file being empty, an
upload that would not start, a server that did not answer, a server that
refused, and a workbook that could not be parsed. "Offline" is claimed only
after asking whether the server answers — the question that was never asked.
A retry reuses the verified cached copy when the provider will not hand the file
over again.

**Traced in development**, metadata only: `picked` → `copied` → `verified` →
`started` → `answered`, carrying url, name, MIME type, declared and copied
sizes, uri scheme, status and error code. Never contents, never a token.

### ⚠️ What is proved, and what is not

| Claim | Evidence |
|---|---|
| The backend accepts the exact workbook | 17/17 from a PC script — **backend only**, it never exercised an iOS document-provider uri or React Native transport |
| The new upload path compiles and ships to iOS | `expo export --platform ios` bundles clean; the bundle contains the route, the new codes and the new messages |
| The mapping and the transport rules hold | 37 pure tests, 12 of them written for these two faults |
| **The iPhone can upload the workbook** | 🔴 **NOT PROVED.** This account cannot drive the handset. `docs/24` **§30c F34–F46** is the outstanding proof |

## 🔧 Fault 1 in detail — the server was not running the feature

**Reported:** the iPhone showed "That file could not be read" for
`demo-receiving-100-phones.xlsx` — the workbook this account had already proved
valid.

**Cause: the API process serving the shop predated the feature.** PID 19632 on
`:3010` was started at 2026-09-15 23:37 from a `dist/` built before
`src/receiving-files/` existed. The previous handoff recorded that API as "left
untouched", which was true and was exactly the problem: the route was in Git, in
`node_modules`, and in no running process.

**The HTTP failure observed on the first attempt:**

| Probe | Before the restart | After |
|---|---|---|
| `POST /api/v1/purchases/file/parse` | **404** | **401** (route exists, auth required) |
| `POST /api/v1/purchases` (a route the old build had) | 401 | 401 |
| `dist/src/receiving-files/` | absent | present |
| `pdfjs-dist`, `jszip` in `node_modules` | present all along | present |

**Repaired** by `npx nest build` and restarting **only** that process, by its
exact verified PID, after confirming its command line. Metro (`:8081`) and MySQL
(`:3306`) were not touched and are still up. The API is healthy on both
`127.0.0.1:3010` and `192.168.100.3:3010`, which is the origin the phone build
compiles in (`EXPO_PUBLIC_API_ORIGIN`).

**The second fault, which hid the first.** The app turned every failure into one
sentence that accused the workbook. Twelve messages now replace it, in EN/FR/AR,
with a Try again and with status, code, file name and MIME type going only to a
development log. A phone also no longer uploads a uri it could not open: the
picked file is checked first, and a request that never left retries once with
the real bytes before the network is blamed.

### Proof on the real path — 17/17, against the live API on the phone's origin

The exact workbook, sent as the phone sends it (field `file`, real bytes, .xlsx
name and spreadsheet type, no hand-set content type): **201**, 12 047 bytes
parsed, `Phones` chosen and `Read me` marked instructions, **100 phones**, **50
with one IMEI and 50 with two**, total **1 242 000**. Reading it again is safe
and identical. A corrupt workbook, an empty file, a .txt, a 9 MB file, no
session and no branch each produce their own message (400 `file_unreadable`,
400, 400 `file_type_unsupported`, 413, 401, 403). **Live counts before and
after were identical — units 53, purchases 10, payments 7, audit 839 — so
parsing created no stock and no payment.**

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

1. **Reload the app on the iPhone and run `docs/24` §30d F47–F64**, then §30c
   F34–F46. Import the workbook, check the staged review on the real screen, and
   **stop before confirming** — the demo phones must not enter live inventory.
   Dynamic type (F62) and the file chooser can only be settled there.
   ⚠️ The API on `:3010` is already the new build (PID 21568, started 04:03) —
   do not start a second one. If the parse route ever answers 404 again, that is
   the old process: rebuild and restart it by its PID.
   Then §30 F1–F21 and §30b F22–F33.
2. **Approve or decline the live rollup repair** above.
3. Then the remaining device sections, §29 and §28 first.
