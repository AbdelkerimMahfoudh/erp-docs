# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF** — all trees clean and pushed.
- Active account / Owner: **NONE** (last worked by CLAUDE-A)
- Completed: **Expo SDK 54 → 57.0.20**, to restore iPhone testing through Expo
  Go. Infrastructure only; no product behaviour was intentionally changed.
- 🔵 **The iPhone acceptance run has not been done.** It needs a person and a
  phone. Steps are below and in [`docs/24` §10](docs/24_DEVICE_QA_CHECKLIST.md).

| Repository | HEAD |
|---|---|
| `erp-mobile` | **branch `sdk-57-upgrade` → `f530c7c`** |
| `erp-mobile` `master` | **`f47a155`, preserved untouched** as instructed |
| `erp-backend` | `b5b9461` (untouched — no compatibility defect required it) |
| `retail-erp-control-web` | `c764d63` (untouched) |
| `erp-docs` | *this commit* |

The upgrade is **on a branch on purpose.** `master` still holds the SDK 54 app
that is known to work, so nothing is staked on an upgrade whose device
behaviour nobody has seen yet. Merge after the iPhone run passes.

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

- 🔵 **The whole iPhone acceptance run.** Nothing about it is verified.
- 🔴 **Android strict-ROI placement on a handset.** Open before this upgrade,
  still open, and now on a rebased mapping — so it matters more, not less.
- 🟡 **React Compiler lint debt** — 32 warnings, deliberately deferred.
- 🟡 **Merge to `master`** once the iPhone run passes.

## Running services

API `:3011` and edge `:8088` were up during this session for the phone-facing
stack. Restart with `.env.staging` loaded before `dist/src/main.js`;
`401` on `/api/v1/device-catalogue/attributes` means live, `404` means stale.
