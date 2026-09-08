# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF** — all trees clean and pushed.
- Active account / Owner: **NONE** (last worked by CLAUDE-A)
- Completed: **category-aware product creation and stock intake.** Phones stay
  individually IMEI-tracked; every other category is received by quantity, and
  the category — not the client — decides which.
- 🔵 The SDK 57 **iPhone acceptance run is still owed**, and this work sits on
  that branch. Nothing below is device-verified.

### HEAD now

| Repository | Branch | HEAD | Was |
|---|---|---|---|
| `erp-backend` | `master` | **`0ec9d4b`** | `b5b9461` |
| `erp-mobile` | `sdk-57-upgrade` | **`3622280`** | `f530c7c` |
| `erp-mobile` `master` | — | `f47a155`, preserved untouched | — |
| `retail-erp-control-web` | `master` | `c764d63` (untouched) | — |
| `erp-docs` | `master` | *this commit* | `8ea65be` |

All four trees were clean and level with their remotes at takeover
(2026-09-08T20:18:38Z), and are clean and pushed now. No discrepancy was found
between the recorded commits and actual local or remote state.

### What changed

**Backend** (`0ec9d4b`, four focused commits)

| Commit | |
|---|---|
| `ed7d8d7` | `src/tracking/tracking-modes.ts` — the one place the rule lives |
| `00e417b` | the category decides the mode; category/product change guards |
| `5bab2d2` | `stock_receipts` + migration `0064` |
| `0ec9d4b` | contradictory intake refused instead of discarded |

**Mobile** (`3622280`) — tracking picker replaced by a derived statement, the
free-form Details editor removed, `serial` no longer offered in category
management, EN/FR/AR updated.

### The defects this closed

1. **The client owned the tracking mode.** `trackingType ?? category.default…`
   let a request name the Phone category and ask for `quantity` — a phone
   received in bulk that never gets an IMEI — or name Accessories and demand an
   IMEI for a cable. Now a 400.
2. **A category change silently changed tracking.** Re-filing a phone under
   Accessories left a quantity product whose rows were all `Unit`s.
3. **A category's mode could change under its products**, reinterpreting all of
   them at once. Now refused while any product uses it.
4. **`hasHistory` missed transfers**, so a product that had only ever moved
   between branches looked untouched.
5. **Contradictory intake was discarded, not refused.** "Receive 50" on a phone
   created ONE unit and threw 49 away, reporting success.
6. **A retried quantity receipt delivered the goods twice.** No event record
   existed to make the retry recognisable.

### Verification

| Gate | Result |
|---|---|
| Backend `tsc --noEmit` | clean |
| Backend Jest | **112 suites / 1963 tests / 0 failing** (from 109 / 1901) |
| Mobile `tsc --noEmit` | clean |
| Mobile lint | **0 errors**, 33 warnings (the pre-existing React Compiler debt) |
| Mobile suites | **32 suites / 645 assertions / 0 failing** (from 640) |
| EN/FR/AR parity | **1838 keys each, identical order** |
| Raw colours / hardcoded copy | clean on every changed file |
| **Live, real MySQL** | **10/10** — see below |

The live run exercised the production functions against the real `phonestore`
database: weighted average correct through two receipts at different costs
(10 @ 100 then 30 @ 200 → 40 @ 175.00), price left unpriced, a duplicate
idempotency key refused, **five simultaneous identical retries leaving exactly
one survivor**, and the CHECK refusing zero and negative quantities. Fixtures
were created under a marker brand and **all removed** — verified by re-count.

**Not verified:** no authenticated HTTP round trip was made (that needs real
credentials, which were not fabricated), and nothing was run on a handset.

### Migration applied this session

| | |
|---|---|
| Migration | `0064_stock_receipt_idempotent_quantity_intake` |
| Database | `phonestore` (development) |
| Pre-migration backup | `~/erp-backups/phonestore-20260908-204622.sql` (598K, ends `-- Dump completed`) |
| Shape | **purely additive** — one `CREATE TABLE stock_receipts`. No ALTER, no data change, no back-fill. |
| Rollback | `DROP TABLE stock_receipts;` — the balances in `stock_items` are untouched by it |
| Verified | `SHOW CREATE TABLE` shows the unique key and the CHECK; a `quantity = 0` insert was refused by the database itself (ERROR 3819) |
| Temporary databases | **none** — see the blocker below |

⚠️ **The disposable-database rehearsal could not be done.** `phonestore_migrator`
has no `CREATE DATABASE` privilege, so the usual "restore the dump into a temp
database and migrate that first" step was unavailable, and elevation was not
possible. The migration was applied directly to `phonestore` after the verified
backup. That was acceptable *only* because this migration is one additive
`CREATE TABLE`: it cannot corrupt an existing row, and a failed `CREATE TABLE`
leaves nothing behind. **A migration that alters or back-fills anything must not
take this shortcut** — resolve the privilege first.

Related discrepancy: [`docs/22`](docs/22_BACKUP_AND_ROLLBACK.md) line 49 shows the
option file containing `user=root`, but `~/.my.cnf` actually authenticates as
`phonestore_migrator`. The doc and the machine disagree. Nothing was changed
about either; it is recorded so the next account is not misled.

### Carried-in risk this work stacks on

🔵 **The SDK 57 iPhone acceptance run was never done.** This inventory work
lands on `sdk-57-upgrade`, a branch whose device behaviour nobody has seen. It
does not block backend work and it does not block writing mobile code — but no
mobile claim may be called device-verified, and the iPhone run stays owed.
`master` still holds the working SDK 54 app.

---

## Previous session (Expo SDK 54 → 57.0.20) — retained for reference

The upgrade is **on a branch on purpose.** Merge after the iPhone run passes.

---

## Why the upgrade was forced

Expo Go is one App Store binary supporting one SDK at a time. It moved to SDK 57
and stopped opening the SDK 54 project, which ended physical iPhone testing. On
Windows with no paid Apple Developer membership, **Expo Go is the iPhone route**
— an EAS device build does not substitute for it here.

## The path, and what actually broke

`54 → 55 → 56 → 57.0.20`, with the full gate set at every stop. Each checkpoint
is its own commit.

| | Breaking change | What was done |
|---|---|---|
| **55** (`4c2acac`) | Legacy Architecture dropped → `newArchEnabled` no longer exists; `android.edgeToEdgeEnabled` removed (always on now); Expo majors synchronise to the SDK | Both keys deleted. The project was already `newArchEnabled: true`, so nothing moved. |
| **56** (`7c1721f`) | `expo-router` **vendors** React Navigation; the published packages must not be direct deps. React Compiler lint rules → errors | Three `@react-navigation/*` deps removed; `lib/navigation/router-internals.ts` added; lint rules demoted to warnings |
| **57** (`f530c7c`) | Hermes V1 memory regression at 56 | `57.0.20`, not `57.0.0` — fixed in `expo@57.0.9`+ |

**Versions now:** React Native 0.86.3 · React 19.2.3 · expo-router 57.0.19 ·
expo-camera 57.0.4 · Reanimated 4.5.1 · Worklets 0.10.1.

### The react-navigation split was a correctness matter

A standalone `@react-navigation/elements` is a **different module instance** from
the one `expo-router` vendors, so its `HeaderShownContext` is a different React
context object that no provider ever fills. `useContext` would return the default
forever, `Screen` would believe no header is shown on routes that have one, and
the status-bar inset would be reserved twice — silently restoring the ~50pt band
that was already fixed once, visible only to somebody holding the phone.

`router-internals.ts` is the one place reaching into the vendored tree, and a
test asserts those paths still resolve and that nothing imports or declares the
standalone packages.

### React Compiler rules are warnings, not fixed

They fire 32 times; every one is a pre-existing pattern written and
device-verified before the rule existed. Rewriting eighteen `setState`-in-effect
sites across the scanner, keyboard handling and catalogue selectors would risk
exactly what this upgrade must preserve, to satisfy a linter. **Recorded as
follow-up work with device retesting, not smuggled into a dependency bump.**

---

## The camera patch: rebased, and smaller

I read the `expo-camera@57.0.4` Android source before deciding. Of the three
defects the patch fixed, **upstream now fixes two**: the missing translation on
an aspect-fill crop, and the transposed corner-point read. Those hunks are gone
(10 → 8).

It still exists for two reasons:

1. **Rotation is still ignored upstream.** No rotation term anywhere in that
   path, and a scale-and-offset model cannot express rotation without becoming a
   matrix — at which point it is a worse `CoordinateTransform`.
2. **`coordinateSpace` does not exist upstream.** That marker is what
   `ScannerSheet` gates strict ROI on, precisely so a patch that failed to apply
   cannot be mistaken for one that did.

Upstream also still calls `barcodes.first()`, discarding every other code in the
frame — on a phone box, where IMEI 1 and IMEI 2 are separate barcodes, one
arrives and which one is arbitrary. The patch keeps one event per barcode.

The rebase had to notice two upstream changes: `BarcodeAnalyzer` lost its
`lensFacing` parameter, and the event classes gained `@OptimizedRecord`. The
verifier's anchors were updated; the transposition anchor is kept, relabelled, as
a guard against upstream regressing what it just fixed.

`patches/expo-camera+57.0.4.patch` · guard passes with **6 anchors after a clean
`npm ci`**.

---

## Verification

| Gate | Result |
|---|---|
| Clean `npm ci` + postinstall | patch applied, guard verified 6 anchors |
| `tsc --noEmit` | clean |
| Expo Doctor | **21/21** |
| Expo lint | **0 errors**, 33 warnings (32 demoted React Compiler + 1 pre-existing unused var) |
| Pure suites | **32 suites, 640 assertions, 0 failing** |
| EN/AR/FR parity | **1840 keys each, identical order** |
| Web export | clean — **23 routes**, all app routes present |
| OCR absence | clean — no OCR library, only historical comments |
| Raw colour / hardcoded copy | clean on every changed file |

**Baseline correction.** The previous handoff recorded *19 suites / 311
assertions*. That was wrong — it globbed `lib/*.test.ts` and missed every nested
suite, including all of `lib/scan/`. The true pre-upgrade baseline was **31
suites / 635 assertions / 0 failing**. `SESSION_LOG.md` is append-only, so the
earlier entry stands and the correction is recorded in the new one.

### Android compilation — submitted, not yet finished

EAS build `f77fe728-5c72-49b8-81e0-e5b86124d61a`, profile `preview`,
account `salah_rim`. It was still **in queue** when this handoff was written.

https://expo.dev/accounts/salah_rim/projects/phonestore-erp/builds/f77fe728-5c72-49b8-81e0-e5b86124d61a

**A green build proves the rebased Kotlin compiles. It proves nothing about
where ROI coordinates land.**

---

## 🔵 What the owner must do next: the iPhone run

Expo Go now requires the CLI and the phone to be signed into the **same** Expo
account. The CLI is already signed in as **`salah_rim`**
(`abdelkerim.mahfoudh@gmail.com`) — verified this session. An Expo account is
free; no Apple Developer membership is involved.

1. On the iPhone: **Expo Go → Profile → Log in** as `salah_rim`.
2. On this machine:
   ```bash
   cd mobile
   git checkout sdk-57-upgrade
   npm ci
   npx expo start --lan
   ```
3. Scan the QR with the **Camera app**; let it hand off to Expo Go.

If the project does not appear, the two sides are on different accounts or
different Wi-Fi. Both fail silently.

Then work `docs/24` §10 — 21 checks covering navigation, the header/safe-area
work SDK 56 replaced the context for, the keyboard behaviours, Storage/Colour
including the airplane-mode fallback, and the scanner including strict iOS ROI.

**None of those may be called green until you report the result.**

---

## Still open

- 🔵 **The whole iPhone acceptance run.** Nothing about it is verified, and this
  inventory work now rides on the same branch.
- 🔴 **Android strict-ROI placement on a handset.** Open before the upgrade,
  still open, on a rebased mapping — so it matters more, not less.
- 🟠 **`Televisions` is still `serial`, with five units of stock.** The rule
  going forward is imei-or-quantity, but converting an existing category would
  reinterpret real stock, which is exactly what this work forbids. **A person
  must decide what happens to those five units.** Nothing is broken meanwhile:
  the category keeps working and can still be renamed.
- 🟡 **A staged quantity cannot be edited after the fact** in the receive flow.
  The quantity is typed once when the product is first scanned — so nobody
  registers pieces one at a time — but correcting it means removing the line and
  re-scanning. Noticed while tracing the flow; out of scope here.
- 🟡 **No authenticated HTTP verification** of the new refusals. They are covered
  by unit tests and by real-database tests, not by a live round trip.
- 🟡 **React Compiler lint debt** — 32 warnings, deliberately deferred.
- 🟡 **Merge to `master`** once the iPhone run passes.

## The next exact action

Run the iPhone acceptance in [`docs/24` §10](docs/24_DEVICE_QA_CHECKLIST.md),
which now also covers category-aware intake (§11). Until that is done, neither
the SDK 57 upgrade nor this inventory work may be called device-verified, and
`sdk-57-upgrade` must not be merged into `master`.

## Running services

API `:3011` and edge `:8088` were up during this session for the phone-facing
stack. Restart with `.env.staging` loaded before `dist/src/main.js`;
`401` on `/api/v1/device-catalogue/attributes` means live, `404` means stale.
