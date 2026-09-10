# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Active account / Owner: **CLAUDE-A**
- `started_at_utc:` **2026-09-10T02:40Z**
- Active phase: **Phase 5 report export (CSV).** Branch `reports-export` on both code repositories, cut from the verified baseline; `pre-reports` tags the point before it.
- Baseline at takeover: backend **113 suites / 1973 tests**, mobile **39 suites**. No discrepancies — all four repositories clean, level and matching this handoff.
- Previous owner: **CLAUDE-A**, `2026-09-10T01:13:06Z` → `2026-09-10T02:10Z`, handoff complete.
- Phase closed: **the two objective gaps before the device test.** Both done.
  Not a redesign phase; the indigo UI is untouched.
- 🔴 **Nothing has run on a handset.** [`docs/24` §14](docs/24_DEVICE_QA_CHECKLIST.md)
  is the single script — now **32 checks**, every row red.

### HEAD now

| Repository | Branch | HEAD | Was |
|---|---|---|---|
| `erp-backend` | `master` | **`67352af`** | `0ec9d4b` |
| `erp-mobile` | `sdk-57-upgrade` | **`c2422c6`** | `337719f` |
| `erp-mobile` `master` | — | `f47a155`, preserved untouched | — |
| `retail-erp-control-web` | `master` | `c764d63` (untouched) | — |
| `erp-docs` | `master` | *this commit* | `d1e3134` |

All clean, level with their remotes, and pushed.

Checkpoints: `pre-scan-contract` on `erp-mobile` (`337719f`) and `erp-backend`
(`0ec9d4b`); earlier, `pre-redesign-part2` → `7d7a7ce`.

### Commits this session

| Repository | Commit | |
|---|---|---|
| `erp-backend` | `67352af` | `/scan` answers "do we already have this phone?" |
| `erp-mobile` | `7e36929` | the warning, and the intake it refuses |
| `erp-mobile` | `c2422c6` | expo 57.0.21 / expo-router 57.0.20, isolated |

## What changed

### The scan duplicate contract

`POST /api/v1/scan { code, secondary?, hint? }` now also returns **`inventory`**:

```
alreadyInInventory          boolean
matchedIdentifierPosition   'primary' | 'secondary' | null
unit                        { productLabel, branchName, status } | null
elsewhere                   boolean
conflictingUnits            boolean
```

`null` for a barcode — a barcode names a reusable product, not one physical
thing. `secondary` carries the second IMEI of a dual-SIM phone so both are
checked as **one handset**, in one request.

**Recognition is not existence.** `recognized` is a catalogue fact (a TAC
resolved); `inventory` is a stock fact. Nothing is inferred from the first.

**Tenant and branch privacy.** IMEI uniqueness is global (migration 0042's
trigger, no company filter) while the tenant client is company-scoped. The
scoped client returns the safe summary for a unit this user can reach. The
system client is asked for a **`count`** and nothing else — a number has no
shape for another tenant's data to travel in. Anything out of reach (another
company, or a branch this user is not assigned to) sets `elsewhere: true` and
carries no company, branch, product, owner or identifier position. Intake is
refused; the holder is not named. **Global cross-column uniqueness is
untouched.** Full reasoning: `docs/21`, "Recognition is not existence".

Home of the logic: `InventoryService.describeIdentifierConflict`, reusing the
both-columns lookup `findByIdentifier` already owns.

On the phone: the localized sentence, product and branch **only** when the
server sent a summary, and **"Use this IMEI" disabled** while it stands. No
cost, no margin, no internal id, anywhere. Scan lock, camera pause, animation
order and the single haptic are unchanged.

### The dependency checkpoint

| Package | Before | After |
|---|---|---|
| `expo` | 57.0.20 | **57.0.21** |
| `expo-router` | 57.0.19 | **57.0.20** |
| `expo-modules-jsi` (transitive) | 57.0.8 | **57.1.0** |
| `expo-camera` | 57.0.4 | **57.0.4 — deliberately unchanged** |

Both are the versions the installed SDK 57 asks for. Everything else that moved
is an `@expo/*` patch release. `expo-camera+57.0.4.patch` still names the
installed version, applies cleanly, **6 anchors verified**, no rebase needed,
strict ROI trust handling as written.

## Verification

| Gate | Result |
|---|---|
| Backend suite | **113 suites / 1973 tests**, 0 failing |
| Backend `tsc` / Prisma validate | clean |
| Migrations | **63, up to date** |
| Permission catalogue | **61/61**, no drift |
| **Live HTTP vs real MySQL** | **16/16** — fixtures created and removed under `ZZ-SCAN-VERIFY`, audit rows preserved |
| Mobile `tsc --noEmit` | clean |
| Expo lint | **0 errors**, 33 warnings — unchanged |
| Pure suites | **39 suites**, 0 failing (from 38) |
| EN/FR/AR parity | **1840 keys each, identical order** — no new keys needed |
| Web export | clean, **68 routes** |
| Camera patch | **6 anchors**, filename matches installed 57.0.4 |
| **Expo Doctor** | ✅ **21/21 — no issues** |
| Raw-colour / NativeWind / hardcoded-copy | clean |
| Worklet safety / Reduce Motion | clean |

`zod` was **not** removed. A simple import search calls it unused; that is not
the same as being unused, and dependency cleanup was not the purpose of this
closure.

## The consolidated device test — running now

| | |
|---|---|
| API | **`http://192.168.100.3:3010`**, LAN-reachable, serving `67352af` |
| Metro | **`exp://192.168.100.3:8081`**, started `--clear --lan` |
| MySQL | up on `3306` |
| Sign in as | **`devtest@example.com`** (or personal ID `U-QZRNQJV5`) — Owner, branches Main Store and Warehouse |
| Password | **not written here.** Handed to the user in chat; reset with `npx ts-node prisma/create-user.ts <login> <password> owner` |

Login was verified over the LAN address and returns an access token; `/scan` was
verified over the same address and returns the `inventory` object.

⚠️ `mobile/.env.local` holds the API origin and is **gitignored**, so every
network change has to be made by hand. It moved twice in one session — a stale
`192.168.100.3`, then `172.20.10.2`, then back — and each time Metro had to be
restarted, because `EXPO_PUBLIC_*` is baked into the bundle at start. A phone
that loads the app and then fails every request is this, not the API.

**The script is [`docs/24` §14](docs/24_DEVICE_QA_CHECKLIST.md) — 32 checks.**
Rows 1–30 are the redesign; **#31–32** are the duplicate warning. Every row
needs the physical iPhone; #9–13 and #31–32 additionally need real handsets with
real IMEIs, and #31 needs one whose IMEI is already in stock.

**No device verification is claimed.**

## Still open

- 🔴 **The whole iPhone acceptance run**, 32 checks, all red. Four sessions of
  work sit on this branch with no device behind any of it. Highest risk, in
  order: the **RTL separator inset** (#26 — a `marginStart`, so it *should*
  follow direction, but that is an assertion about a layout engine and is
  invisible in English); the scanner **through** the reveal (#9–11); first/last
  row treatment across eight converted lists (#24); dark mode over the newly
  grouped surfaces (#25).
- 🔴 **Android strict-ROI placement on a handset** — open before the SDK
  upgrade, still open, on a rebased mapping.
- 🟠 **`Televisions` is still `serial`, with five units of stock.** The rule
  going forward is imei-or-quantity, but converting the category would
  reinterpret real stock. **A person must decide about those five units.**
  Nothing is broken meanwhile.
- 🟡 **A staged quantity cannot be edited after the fact** in the receive flow;
  correcting it means removing the line and re-scanning.
- 🟡 **React Compiler lint debt** — 32 warnings, deliberately deferred.
- 🟡 **Merge `sdk-57-upgrade` → `master`** once the run passes. Not before.
- 🟢 A stray staff account created by a mis-typed password reset was deactivated
  and soft-deleted the same minute. It never authenticated and holds no data.

## The next exact action

**Work `docs/24` §14 on the iPhone — 32 checks.** The QR, the API and MySQL are
running and were verified from this machine minutes ago. Sign in as
`devtest@example.com`.

Do not start another feature and do not merge to `master` before the run.

## Running services

Left **running deliberately** for the device test:

- **API on `:3010`** — a build of `67352af`, LAN-reachable at `192.168.100.3`.
- **Metro on `:8081`** — `expo start --clear --lan`, `exp://192.168.100.3:8081`.
- **MySQL on `:3306`**.

⚠️ **Check freshness before trusting any server you find running.** Three
separate failures on this project — a 404 on an endpoint that existed, a Metro
predating a fix, and a `PluginError` from a bundler started before
`node_modules` was wiped — were all one stale process. A stale Metro on `8081`
was found and stopped during this very session. Resolve the PID and compare its
start time against the last build before concluding anything.
