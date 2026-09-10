# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Active account / Owner: **CLAUDE-A**
- `started_at_utc:` **2026-09-10T01:13:06Z**
- Active phase: **two objective gaps before the device test** — the scan
  duplicate contract, then an isolated SDK 57 patch bump. Not a redesign phase.
- Checkpoints: `pre-scan-contract` on both `erp-mobile` (`337719f`) and
  `erp-backend` (`0ec9d4b`). No discrepancies at takeover.
- Completed: **the indigo redesign is applied across every named surface.** All
  19 `ListRow` consumers are deliberately classified and the classification is
  asserted by tests.
- 🔴 **Nothing has run on a handset.** [`docs/24` §14](docs/24_DEVICE_QA_CHECKLIST.md)
  is the single 30-step script; every row is red.

### HEAD now

| Repository | Branch | HEAD | Was |
|---|---|---|---|
| `erp-mobile` | `sdk-57-upgrade` | **`337719f`** | `7d7a7ce` |
| `erp-mobile` `master` | — | `f47a155`, preserved untouched | — |
| `erp-backend` | `master` | `0ec9d4b` (untouched) | — |
| `retail-erp-control-web` | `master` | `c764d63` (untouched) | — |
| `erp-docs` | `master` | *this commit* | `8d3dabd` |

Checkpoints: `pre-indigo-refresh` → `3622280`, `pre-redesign-completion` →
`ca8525d`, **`pre-redesign-part2` → `7d7a7ce`**.

No discrepancies at takeover: all four repositories clean, level,
`READY_FOR_HANDOFF`, and every prior redesign commit present and verified.

### Commits this session

| Commit | |
|---|---|
| `ce5b8de` | every repeated operational record grouped; `ListSeparator` added |
| `337719f` | scanner paused-state and indigo detection; surface classification tests |

### Screens completed this session

`sales/[id]` (items + payments grouped, totals card kept), `returns/[id]` (item
and source sale grouped, refund summary card kept), `suppliers/[id]` (deliveries
and both settlement lists grouped, separately), `transfers/new` (review list
grouped; form steps kept one surface per step), `(tabs)/more` (grouped
destinations, sign-out isolated), `notifications` (flat list, unread wash + word
+ accessibility label), the scanner result panel, and eight index lists —
suppliers, expenses, loans, consignments, discrepancies, imports, team, devices.

### The 19 `ListRow` consumers, classified

**grouped (13)** — Home, Inventory, More, Analytics, `catalog/[id]`,
consignments, devices, discrepancies, expenses, imports, loans, suppliers, team.

**card retained (3)** — Money hub, `hub/[id]`, settings: metrics and panels
meant to be looked at rather than read through.

**custom retained (3)** — `select-branch`, `catalog/categories`, `dev/gallery`:
a one-off pre-app choice, a management sheet, and a component gallery.

Asserted in `lib/design/surface-classification.test.ts`, which also enforces
that a grouped screen actually separates its rows and that financial summaries
were **not** flattened.

### Shared primitives changed

`ListSeparator` (new) — one place that decides the row rule and its start-side
inset. `Section` gained an icon slot in the previous pass; `RowGroup` and
`ListRow.flat` unchanged this session.

### Verification

| Gate | Result |
|---|---|
| `tsc --noEmit` | clean |
| Expo lint | **0 errors**, 33 warnings — unchanged, no new debt |
| Pure suites | **38 suites, 713 assertions, 0 failing** (from 37 / 706) |
| EN/FR/AR parity | **1840 keys each, identical order** |
| Web export | clean — **68 routes**; every redesigned route present |
| Camera patch | applies on `expo-camera@57.0.4`, **6 anchors** |
| Raw-colour audit | **0** across 56 authenticated routes (test) |
| NativeWind audit | **0** across 56 (test) |
| Hardcoded-copy audit | no `trackingLabel` in screens (test) |
| Worklet-safety audit | no `withTiming` inside any `useAnimatedStyle` (test) |
| Reduce Motion audit | every layout animation defers to `ReduceMotion.System` (test) |
| Live HTTP login | `devtest@example.com` → **200** (password absent from Git and docs) |
| **Expo Doctor** | ⚠️ **1 check failed** — two upstream patch releases |

⚠️ **Expo Doctor** reports `expo@57.0.20 → 57.0.21` and `expo-router@57.0.19 →
57.0.20`. Not caused here — the lockfile is untouched across all three redesign
sessions. Deliberately not bumped: mixing a dependency upgrade into a UI
milestone is forbidden by the brief, and the branch's device acceptance is still
owed. Do it as an isolated checkpoint and re-verify the camera patch.

### One concrete blocker, not a design concern

**The scanner's existing-inventory warning cannot be built.** `docs/24` asks the
result panel to warn when a scanned IMEI is already in stock, and the string
`scan.alreadyInInventory` exists — but `ScanResult` carries no such field and
`/scan` does not return one. Rendering it needs a backend change, which this
milestone forbids. The key is left in place for whoever adds the field.

## Still open

- 🔵 **The whole iPhone acceptance run.** Nothing about it is verified, and both
  the inventory work and now the visual refresh ride on the same branch.
- 🔴 **Every visual and motion claim is unverified on hardware.** The single
  script is [`docs/24` §14](docs/24_DEVICE_QA_CHECKLIST.md) — 30 checks, all
  red; it supersedes §11–§13. Highest risk, in order: the **RTL separator
  inset** (a `marginStart`, so it *should* follow direction, but that is an
  assertion about a layout engine and is invisible in English); the scanner
  **through** the reveal animation; **first/last row treatment** across eight
  converted lists; and dark mode over many newly grouped surfaces.
- 🟡 **Expo Doctor is 1-check-failed on two upstream patch releases**
  (`expo`, `expo-router`). Not caused by this session — the lockfile is
  untouched. Bump them with the SDK-57 device run, not before it.
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

**Work `docs/24` §14 on a handset.** 30 checks, all red. Sign in as
`devtest@example.com`. Four sessions of work now sit on this branch with no
device behind any of it.

After it passes, two isolated follow-ups — each its own checkpoint, never mixed:
bump the two Expo patch releases and re-verify the camera patch, then merge
`sdk-57-upgrade` into `master`.

Do not merge before §10 passes at minimum.

## Running services

**Nothing is left running by this session except MySQL.**

- **MySQL is up**, started directly as `mysqld.exe --defaults-file=… --console`
  because `Start-Service wampmysqld64` needs elevation this session did not
  have. It is listening on `3306`. If it is gone, that is why.
- The API was started on `:3010` from a **fresh** `nest build` for verification
  and **has been stopped again**. The `dist/` in the tree is that build.

⚠️ **Check freshness before trusting any server you find running.** Three
separate failures this project has hit — a 404 on an endpoint that existed, a
Metro bundler predating a fix, and a `PluginError` from a bundler started before
`node_modules` was wiped — were all one stale process. Resolve the PID and
compare its start time against the last build before concluding anything from
what it returns.
