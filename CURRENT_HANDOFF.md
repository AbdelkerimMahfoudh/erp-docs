# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF** — all trees clean and pushed.
- Active account / Owner: **NONE** (last worked by CLAUDE-A)
- Completed: **the token migration is finished and the shared surface system is
  in place.** Every authenticated route is free of raw colours and NativeWind
  styling, and the audit is now enforced by tests rather than by habit.
- 🔴 **Nothing here has run on a handset.** The consolidated device script is
  [`docs/24` §13](docs/24_DEVICE_QA_CHECKLIST.md) — 30 checks, all red.
- ⚠️ **The redesign is NOT complete.** See "what remains" below; several screens
  named in the brief were deliberately not touched.

### HEAD at takeover

| Repository | Branch | HEAD |
|---|---|---|
| `erp-docs` | `master` | `bddaf6b` |
| `erp-backend` | `master` | `0ec9d4b` |
| `erp-mobile` | `sdk-57-upgrade` | `ca8525d` |
| `erp-mobile` `master` | — | `f47a155`, preserved |
| `retail-erp-control-web` | `master` | `c764d63` |

All four clean and level with their remotes. Baseline recalculated
independently rather than trusted: **35 suites, 692 assertions, 0 failing**;
i18n 1838 × 3; tsc clean; lint 0 errors / 33 warnings.

Checkpoints: `pre-indigo-refresh` → `3622280` (before any visual work) and
**`pre-redesign-completion` → `ca8525d`** (the verified foundation: SDK 57, the
sign-in crash fix, overlay motion obeying Reduce Motion).

### What was done

| Commit | |
|---|---|
| `e647c22` | token migration finished; `RowGroup` added; `ListRow.flat` stopped self-separating |
| `7d7a7ce` | Home and product-detail grouping; the audit turned into tests |

**Screens redesigned:** `catalog/index` (fully off NativeWind — shared
`SearchInput`, `FilterChip`, `ErrorState` replace hand-rolled copies),
`analytics` (rebuilt on tokens; tabular money; signed profit; localised tracking
badge), `(tabs)/index` (three grouped runs instead of stacked bordered cards),
`(tabs)/inventory` (row runs grouped), `catalog/[id]` (per-branch stock
grouped).

**Shared primitives changed:** new `RowGroup`; `ListRow.flat` no longer draws
its own hairline; `Section` gained an optional icon.

### What remains — the redesign is not finished

Deliberately not touched, and **not** because they are correct:

| Screen | State |
|---|---|
| `sales/[id]` | 6 nested cards — brief asks for 4 grouped sections |
| `returns/[id]` | 7 nested cards — brief asks for 5, with amber pending payout |
| `suppliers/[id]` | 6 nested cards |
| `transfers/new` | 8 nested cards |
| `(tabs)/more` | 4 cards — brief asks for grouped destinations |
| `notifications` | flat-list treatment not applied |
| `receive` | category-aware presentation not refined |
| Scanner | presentation refinements (explicit "Scanner paused", labelled IMEI 2) not done |
| Selector sheets | already correct on keyboard/options; the confirm-action pattern was not revisited |

Flat-list coverage is **3 of 19** `ListRow` consumers. The system and the
primitives to finish the rest are in place; the remaining work is applying them
screen by screen.

I stopped here rather than continuing because the quality of each screen matters
more than the count, and a half-applied treatment across nine more screens would
be worse than none. The next account should work the table above in order.

### Discrepancies found at takeover

1. **The handoff was not `READY_FOR_HANDOFF`.** It still read `IN_PROGRESS` /
   `CLAUDE-A` from the crash investigation, which ended by handing the user a QR
   rather than closing the session. Same account continuing, so no ownership
   conflict — recorded because the protocol expects a clean claim.
2. **Its HEAD table was three commits stale** for `erp-mobile` (`993cf13`,
   actually `ca8525d`) and one behind for `erp-docs` (`22b6ba9` → `bddaf6b`).
   The missing commits are `2b58d4b` (sign-in crash fix), `a0eaaaf` (sign-in
   error copy) and `ca8525d` (overlay motion). **Both required commits are
   present and verified.**
3. **The development database was mutated** during the crash session: one new
   user `devtest` (owner, both branches) created with the project's own
   `prisma/create-user.ts`, and a reserved `@example.com` address set on that
   same new user. Nothing existing was changed or deleted. The password is
   deliberately absent from Git and from these documents.

### Previously completed (retained)

**The indigo visual refresh and motion system**, mobile only — a UI refinement
that altered no business rule, scanner correction or category-aware intake
behaviour. **Nothing visual or animated has run on a device**, and it sits on
`sdk-57-upgrade`, whose own iPhone acceptance run is still owed.

### Verification (this session)

| Gate | Result |
|---|---|
| `tsc --noEmit` | clean |
| Expo lint | **0 errors**, 33 warnings — the same pre-existing React Compiler debt, none added |
| Pure suites | **37 suites, 706 assertions, 0 failing** (from 35 / 692) |
| EN/FR/AR parity | **1839 keys each, identical order** |
| Web export | clean — **68 routes**; catalog, new, edit, categories, analytics, receive, notifications, settings all present |
| Camera patch | applies on `expo-camera@57.0.4`, **6 anchors** verified |
| Raw-colour audit | **0** across all 56 authenticated routes — now a test |
| NativeWind audit | **0** across all 56 — now a test |
| Hardcoded-copy audit | `trackingLabel` removed from screens; now a test |
| Worklet-safety audit | no `withTiming` family call inside any `useAnimatedStyle` |
| Reduce Motion audit | every `entering`/`exiting` defers to `ReduceMotion.System`; no duration literals |
| Live HTTP login | `devtest@example.com` → **200** (password not recorded in Git or docs) |
| **Expo Doctor** | ⚠️ **1 check failed** — two upstream patch releases, unchanged from before |

⚠️ **Expo Doctor** still reports `expo@57.0.20 → 57.0.21` and
`expo-router@57.0.19 → 57.0.20`. Not caused by this session — the lockfile is
untouched. Deliberately **not** bumped: the brief forbids mixing a dependency
upgrade into a UI correction, and the branch's device acceptance is still owed.
Do it as an isolated checkpoint and re-verify the camera patch afterwards.

**Dependency audit caveat.** A naive import scan flags nine packages as unused;
eight are Expo/expo-router peers used through config rather than imports
(`react-dom`, `react-native-web`, `react-native-screens`, `expo-font`,
`expo-system-ui`, `expo-image`, `@expo/vector-icons`, `react-native-svg`).
**`zod` is genuinely unimported** — a real candidate for removal, left alone
because a dependency change does not belong in a UI milestone.

## Still open

- 🔵 **The whole iPhone acceptance run.** Nothing about it is verified, and both
  the inventory work and now the visual refresh ride on the same branch.
- 🔴 **Every visual and motion claim is unverified on hardware.** The single
  consolidated script is [`docs/24` §13](docs/24_DEVICE_QA_CHECKLIST.md) — 30
  checks, all red; it supersedes §11 and §12, which were written before the
  sign-in crash was found. Highest risk: the scanner **through** the reveal
  animation (one result, one haptic), the indigo reticle against a glossy box
  under a strip light — a colour on a camera image, so its contrast could only
  be chosen, never computed — and the RTL separator indentation.
- ⚠️ **The redesign itself is incomplete.** Nine screens named in the brief were
  not touched; see "what remains". The primitives to finish them exist.
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

Two things, in this order:

1. **Work `docs/24` §13 on a handset** — 30 checks, all red. Sign in with
   `devtest@example.com`. Nothing in this milestone is device-verified.
2. **Finish the screens in "what remains"**, in the order listed. The
   primitives are in place; it is application, not design.

Do not merge `sdk-57-upgrade` into `master` until §10 passes at minimum.

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
