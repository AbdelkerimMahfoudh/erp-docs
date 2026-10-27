# 106 — Expo SDK 58 for the app (D222)

Session: CLAUDE (local session, the owner's PC), 2026-10-26. Owner-approved the same day, after a written plan, files
and risks. **Nothing deployed.** erp-test (app `9e0b38b`), dukan-test, the API, the database, the backend, the console,
DNS, tsxmr.com, email, WhatsApp and activation are unchanged.

## 1. Why

The owner's iPhone runs Expo Go for SDK 58. Expo Go on iOS ships only for the current SDK and refuses an SDK 57 project,
so the app could no longer be opened on the phone for review.

## 2. What changed

Branch **erp-mobile `sdk-58`**, from `9e0b38b` (the build on erp-test). `browser-input-setup-code`, `master` and
`promoter-attribution` are untouched; `promoter-attribution` (D221) changes no package, patch, `BottomSheet` or root
layout, so it merges with this branch without overlap.

| Package | Before | After |
| --- | --- | --- |
| expo (and every `expo-*`) | 57.0.30 | **58.0.19** (each `expo-*` at SDK 58's version) |
| react, react-dom | 19.2.3 | 19.3.0 |
| react-native | 0.86.3 | **0.88.0** |
| react-native-gesture-handler | 2.32 | **3.3** |
| react-native-reanimated / worklets | 4.5.1 / 0.10.1 | 4.7.1 / 0.13.0 |
| screens / safe-area / svg / web | 4.26 / 5.7 / 15.15 / 0.21.2 | 4.30 / 5.10 / 15.16 / 0.21.4 |
| jest / jest-expo | 29.7 / 57 | 30.5 / 58 |
| @testing-library/react-native | 13.3 | **14.1** (expo-router 58 requires ≥ 14) |
| react-test-renderer | 19.2.3 | removed — **test-renderer 1.3** (RNTL 14; React 19.3's line) |

The lockfile is written by npm 11.

### 2.1 Found by the upgrade, fixed in the app

- **Every bottom sheet would have failed on the phone.** A React Native `Modal` is a root of its own, outside the app's
  `GestureHandlerRootView`. Gesture Handler 2 tolerated the sheet's `GestureDetector` there; Gesture Handler 3 throws
  ("GestureDetector must be used as a descendant of GestureHandlerRootView"). `BottomSheet` now carries its own root,
  inside `ModalBoundary` (D219 keeps the boundary the first thing in every Modal), at the same absolute-fill geometry,
  so nothing moves.
- **Every `.xlsx` import would have been refused.** `FileHandle.readBytes` became asynchronous in expo-file-system 58,
  so the workbook signature check received a Promise. `lib/file-receiving` now uses `readBytesSync`, the same read of
  only the head. The other File/Directory calls the offline queue and drafts use (`write`, `delete`, `create`, `list`,
  `copy`) are unchanged upstream (compared declaration by declaration).
- **The web build would have been blank.** Every exported page was a 604-byte shell with no script. Two causes, both
  upstream changes:
  - expo-router 58 defaults to lazy routes on the web, so `app.json` sets `["expo-router", { "asyncRoutes": false }]`;
  - a custom `app/+html.tsx` must now place the export's own nodes, so it reads `useServerDocumentContext()` and renders
    `headNodes` in the head and `bodyNodes` after the children. The access-boundary test allows that one new name.
  With both, the web smoke renders sign-in (`ready: true`).
- React Native 0.88 types `View`, `ScrollView` and `TextInput` as function components: refs use `ViewInstance`,
  `ScrollViewInstance`, `TextInputInstance`. FlatList slots take `undefined`, not `null`. `RefreshControl.onRefresh`
  returns nothing (`() => void refetch()`).

### 2.2 The native patch (Android scanner), re-cut

`patches/expo-camera+58.0.12.patch` replaces `+57.0.6`: the same four changes (every barcode in a frame, CameraX
`CoordinateTransform`, the `coordinateSpace` capability marker, frame ids), re-applied by hand because upstream changed
three of the four files: `BarcodeAnalyzer` gained a primary constructor taking the ML Kit client and became
`Closeable`, and the camera view keeps the analyzer to release it. The PreviewView provider goes into both
constructors. It applies cleanly to a fresh 58.0.12 and `scripts/verify-native-patch.js` pins it with the same six
anchors. **Not compiled or run on an Android device** — Expo Go does not load custom native code, and this PC has no
Android toolchain. It must be checked on a native Android build before any Android release.

### 2.3 Tests

- **RNTL 14:** `render`, `fireEvent`, `act`, `rerender`, `unmount` and `renderHook` are promises; every call is
  awaited, helpers included (`team-refusals` also awaits the edit callback it is given).
- **The removed `UNSAFE_*ByType` queries** are replaced by `__tests__/tree.ts`: host text inputs from the container,
  and the app's own components — what sits above a FlatList, a TextField's props, what can be pressed inside a card —
  from React's fiber tree, so no assertion was weakened.
- **Reanimated 4.7 under Jest:** the iOS preset loads Reanimated's native initializer, which calls a method its JS
  fallback throws on by design; `__tests__/setup.ts` maps it to the platform-neutral initializer. Gesture Handler 3's
  own `jestSetup` is loaded.
- **expo-router 58:** the module-level router is bound only after a navigator renders; `no-browser` builds the same
  router (`createImperativeRouter`) around a recording queue and now also asserts that no external address reaches it.
  `deep-links` reads the route as expo-router's own `renderRouter` does (the router store is gone).
- `field-focus-ring`: the input is the host element, so the well is its parent.
- Two source-reading pure tests follow upstream: `readBytesSync`, and the navigator's tab padding read by value (still 5).

### 2.4 The bundle audits

- **Metro now writes indexed source maps** (`{ version, sections }`, one section per module). Read as before, they have
  no top-level `sources`: `audit-bundle.js` threw and `audit-shipped-deps.js` read 92 maps with 0 modules, so neither
  checked anything. `scripts/source-map-flat.cjs` turns an indexed map into the equivalent plain map; both audits call
  it after parsing and nothing else in them changes. Checked against the SDK 58 iOS map Metro served: 5,023 sections and
  sources kept; 2,178,246 mapped segments at their moved places with 0 mismatches; a plain map re-encodes byte for byte.
- **React DOM 19.3** has two page-navigation sites more than 19.2 (pinned 10 → 12). Run through the audit's own scanner
  on both versions, they are one expression inside React's view-transition update,
  `ownerWindow.navigation && ownerWindow.navigation.transition`, which waits for a pending navigation and never starts
  one. The app uses no view transition.

## 3. Verification

| Gate | Result |
| --- | --- |
| TypeScript (app and tests) | clean |
| `expo lint` | 0 errors, 28 warnings (the baseline; CI limit 40) |
| Pure tests (Linux) | **123/123** files |
| Rendered tests (Linux) | **38/38** suites, **364/364** |
| Release configuration | PASS |
| Secret scan | clean |
| Expo Doctor | **20/20, no issues** — the documented patch-version finding (docs/75 §15.6) is gone |
| Web and iOS exports | PASS |
| Shipped dependencies | 9,361 modules from 78 packages; no high or critical advisory shipped |
| Bundle audit | PASS on `fca75c5` (render-tests run 40516796050; web and iOS exports, `audit-bundle`, `audit-shipped-deps`, web smoke all exit 0) |
| security CI on the final commit | **success**, run 40516759707 on `fca75c5` |
| visual-check (WebKit, Chromium) | **success**, run 40544916619 (`ops/visual-check` `031b684`, target `fca75c5`; the earlier run 40515071046 was cancelled during install and proved nothing) |
| iOS bundle in Expo Go | builds (5,016 modules, no warning); manifest `sdkVersion 58.0.0`, signed, same Expo scope |

**Local limits (this PC):** Windows Smart App Control blocks Jest 30's resolver (`unrs-resolver`'s native binary), as
it already blocked the web export, so rendered tests and exports run on Linux only. Four pure suites fail on Windows
only, from path and line-ending handling in source-reading tests; they pass on Linux.

**Tooling, never merged:**
- erp-mobile **`ops/render-tests`** (new): every pure test file, both exports, both bundle audits and the rendered suite
  on Linux, each output committed under `evidence/<commit>-<run>/` — the security workflow's job log is not readable
  without repository rights.
- erp-mobile **`ops/visual-check`**: targets the final commit and now commits each run's results under `evidence/runs/`
  after its secret check.

## 4. Decision

D222 (`docs/21`): the app moves to Expo SDK 58.

## 5. Open

- **Android:** compile and run the re-cut scanner patch on a native Android build; the scan region must still be the
  visible frame (`docs/30`).
- **A native iOS build** (TestFlight) is a separate step, not taken.
- **erp-test** still serves `9e0b38b` (SDK 57). Moving the browser test site to SDK 58 is a separate, owner-approved
  deployment, with `docs/103` §5.
- **Merge:** `sdk-58` is not merged. `promoter-attribution` (D221) is on SDK 57 and merges with it without overlap.
- Expo Go cannot apply right-to-left layout (docs/70); Arabic on the phone needs a real build.
