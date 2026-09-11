# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Active account / Owner: **NONE**
- Last owner: **CLAUDE-A**, `2026-09-11T08:10Z` → `2026-09-11T13:30Z` — the
  **Indigo Stock screen**. Asked to work as `CLAUDE-B`; this account is
  `CLAUDE-A` per the user's standing correction.
- Phase closed: **the Stock tab redesigned and wired to the existing receiving
  workflow.** No dashboard work, no new receiving engine, no schema change.
- ⚠️ **The attached visual reference was not visible in that session.** The screen
  follows the written description of "A · Indigo"; fidelity to the picture is
  unverified.
- 🟢 **Ready to test on a handset** — see §4.
- 🔴 **Nothing has run on a handset.** [`docs/24`](docs/24_DEVICE_QA_CHECKLIST.md)
  §14 (58 checks) and new **§15 S1–S20** for this screen, every row open.

### What changed

| Repository | Commit | |
|---|---|---|
| `erp-backend` | **`63ce639`** | `GET /inventory/summary` — one row per variant, price range, low stock; shared `low-stock.ts` |
| `erp-mobile` | **`564d224`** | the Stock screen, `StockRow`, `lib/stock-price.ts`, EN/FR/AR keys, summary invalidation |
| `erp-docs` | *this commit* | handoff, session log, `docs/21` decision, `docs/24` §15 |

### HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`63ce639`** | level | 0 |
| `erp-mobile` | `reports-export` | **`564d224`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` | level | 0 |

### Verified this session

| Gate | Result |
|---|---|
| Backend `tsc` | clean |
| Backend full suite | **124 suites / 2344 tests**, 0 failed |
| **Live HTTP vs MySQL** | **11 passed, 0 failed** — summary cost-free at both branches, refused without a branch, counts equal the unit list, and a two-IMEI fixture found by **either** IMEI (fixture created and removed) |
| Mobile `tsc` | clean |
| Expo lint | **0 errors, 33 warnings** (baseline) |
| Pure suites | **43**, 0 failed (new stock-screen suite: 25) |
| EN/FR/AR parity | **2000 keys each, identical order** |
| Web export | **70 routes** (baseline) |
| Expo Doctor | **21/21** |
| Camera patch | **6 anchors** |
| Rendered (web) | French light, dark, Arabic, Receive entry — **Arabic copy renders; layout not mirrored on web** (`forceRTL` is native-only) |

### The earlier milestone

CP1–CP6 of the mistake-prevention suite and the `branch_manager` grant repair
are complete; their detail follows unchanged in §1–§3.


## 1. Verified — final totals

| Live, real HTTP against real MySQL, repaired database | |
|---|---|
| CP6 full run | **92 / 92** — *"a legacy Branch Manager may NOT decide"*, the check that failed at 91/92, passes |
| Rejection run | **6 / 6** |
| Repair, before migration 0067 | **3 / 3** — the defect reproduced with the session later tested |
| Repair, after migration 0067 | **14 / 14** — checks 1–6 below |
| **Total** | **115 checks, 0 failed** |

| Backend at `6ff7f16` | |
|---|---|
| `tsc --noEmit` | clean |
| Full suite | **123 suites / 2327 tests, 0 failed** |
| `prisma validate` | valid |
| `prisma migrate status` | **66 applied, up to date** (0067 added) |
| Permission catalogue | **61 / 61 keys** |
| Permission **grants** | ✅ **exit 0 — "catalogue and grants complete"** |

`Administrator` is reported as *narrowed* by the grant gate. That is
informational by design — a missing grant is usually a deliberate narrowing — and
needs no action.

| Mobile at `20619e4` — tree untouched by the repair | |
|---|---|
| `tsc --noEmit` | clean |
| Expo lint | **0 errors, 33 warnings** — unchanged, no new debt |
| Pure suites | **42** |
| EN/FR/AR parity | **1985 keys each, identical order** |
| Web export | clean, **70 routes** |

Backend lint is **not** a gate here and never has been: there is no
`eslint.config.*` in that repository, so `npm run lint` fails identically on a
clean checkout.

## 2. The repair

### What was wrong

A2 made `discount.override` approval authority, **Owner-only**. `6287b61`
removed it from `ROLE_PERMISSIONS.branch_manager` in code, and **no migration
followed** — so every seeded installation kept the grant, and `AccessService`
resolves authority from `role_permissions` and nothing else. CP6 proved a
Branch Manager could approve a discount over real HTTP.

### Measured before touching anything, across every tenant

Exactly **one** row (Demo Phone Store / Branch Manager). `discount.override`
held by `owner` and `branch_manager` only. **Zero** users assigned the retired
role; **zero** of their sessions live.

### Migration 0067

`prisma/migrations/0067_revoke_branch_manager_discount_override` — the project's
established revoke mechanism, in `0018_store_role_revoke`'s exact shape. It
resolves the permission **by key** through a JOIN, because permission ids are
generated per installation (`0059` uses `UUID()`; a seeded database has the
seed's ids). One pair, nothing inserted, idempotent. `role_permissions`
**159 → 158**; `discount.override` is now held by `owner` alone.

Backup first: `~/erp-backups/phonestore-20260910-232828.sql` — **711 927 bytes,
88 tables, 24 triggers, 0 raw `_binary` literals, trailer present.** (The
earlier `phonestore-20260910-191750.sql` preceded `0066`.)

### Sessions: nothing to revoke, and proved

The access token carries only `sub`, `companyId`, `type` and `sid`. Permissions
are resolved from the database on every request and held in CLS, which is
mounted per request. **No token, session row or process cache holds them**, so
no session was revoked — it would have signed people out to fix nothing.

Proved with a two-phase harness against **one API process never restarted**
(PID 25572 throughout): a legacy Branch Manager session issued at 23:31:26
**approved** a discount before the migration; after it, that **same session —
still valid, `/auth/me` 200, same user id — was refused.**

### The eight required proofs

| # | Proof | Result |
|---|---|---|
| 1 | Owner can approve | ✅ approved; record names the Owner as approver |
| 2 | Owner self-approves through the audited workflow | ✅ requested and approved by the Owner, sold at the approved price, consumed once; both audit events attributed to the Owner |
| 3 | Store Manager cannot approve | ✅ 403 |
| 4 | Employee cannot approve | ✅ 403 |
| 5 | Retired Branch Manager, fresh session | ✅ 403, `discount.override` missing |
| 6 | Retired Branch Manager, session issued before the repair | ✅ 403, session confirmed still valid |
| 7 | Permission-grant drift fully green | ✅ exit 0 |
| 8 | Previously failed CP6 check passes | ✅ CP6 92/92 |

The four refusals changed nothing: the request stayed pending at the same
version. The pre-repair approval by the legacy Branch Manager is **preserved in
the audit trail** — it happened.

### Two gates that were themselves wrong

- **The grant gate matched roles by display name.** A renamed "Branch Manager"
  would have kept its grant while the gate reported green. It now matches
  `roles.key`, with a test for exactly that case.
- **The catalogue guard refused the migration.** It judged "touches
  `permissions`" by the table's name appearing at all, which fails every grant or
  revocation — they must name it to resolve a key. It now detects **writes by
  target** and still catches all eleven write forms, including a delete or update
  through a join alias; three cases pin the reads. The full suite caught this, not
  the focused specs, which is why nothing was committed before it was green.

## 3. Demo-data integrity, measured either side of the repair run

| | before | after | |
|---|---|---|---|
| units · sales · payments · products · users | 11 · 7 · 7 · 14 · 13 | identical | ✅ |
| approvals · dismissals · notifications | 0 · 0 · 45 | identical | ✅ |
| sale total · margin · unit cost · payments | 10 051 · 3 018.20 · 9 800 · 10 051 | identical | ✅ |
| SHA-256 over `units.id` and `sales.id` | — | identical | ✅ |
| `audit_logs` | 752 | **783** | the run's own trail, preserved |
| `role_permissions` | 159 | **158** | the one authorised removal |

Fixtures under `ZZ-CP6` removed: 4 users, 4 branch assignments, 1 product,
16 units, 6 sales with items and payments, 8 approvals, 1 dismissal and 45
notifications (15 on the probes, 30 left on the demo Owners). **0 dangling
`/approvals/…` links. No temporary database was created.** `phonestore_shadow`
from an earlier session still exists and is still needed by `prisma migrate diff`.

⚠️ **Do not run `prisma migrate diff` against this history and apply it.** It
produces 1172 lines dropping foreign keys on unrelated tables. `0066` and `0067`
are hand-written for that reason.

## 4. Ready to test the new Stock screen

**On the iPhone:** open Expo Go on the same Wi-Fi and scan
**`exp://192.168.100.3:8081`**. Sign in as `devtest@example.com`, choose
**Main Store**, then tap **Stock** in the bottom bar.

| Service | Detail |
|---|---|
| API | `http://192.168.100.3:3010`, PID **25480**, backend **`63ce639`** |
| Metro | `exp://192.168.100.3:8081`, PID **26348**, `expo start --clear --lan` from mobile **`564d224`** — native bundle contains `/inventory/summary`, `stock.receive`, `stock.priceFrom` and origin `192.168.100.3:3010` |
| MySQL | `:3306`, the user's WAMP stack, untouched |

Device checks for this screen are [`docs/24` §15](docs/24_DEVICE_QA_CHECKLIST.md),
S1–S20. The ones only a handset can settle: **Arabic mirroring (S17)**, the
scanner from the search field (S11), draft resumption through Receive stock
(S14), larger text (S18), VoiceOver (S20), and the last row scrolling clear of
the footer on a real safe area (S13).

### Known limitations

- **No product photos** — none exist in the app; rows use a neutral category tile.
- **Serial-tracked devices** (e.g. TVs) appear under **All** only; Phones is
  IMEI-tracked, Accessories is quantity-tracked.
- **"Available" excludes reserved quantity; "low" compares physical quantity**,
  the dashboard's existing rule — the two can differ by the reserved amount.
- A price range shows **"From"** the minimum; the maximum is on the unit list.
- The reference image was not visible; visual fidelity to it is unverified.

## 5. Running services — left up on purpose

- **API** PID 25480 on `:3010` — restarted from the committed backend so the new
  route exists; the stale PID 4636 was stopped by PID.
- **Metro** PID 26348 on `:8081` — restarted with a cleared cache from the final
  mobile HEAD; the stale PID 8460 was stopped by PID and command line.
- Headless Chrome (`:9333`) and the static web server (`:19006`) were
  verification helpers and are **stopped**.

## 6. The next exact action

**Run `docs/24` §15 S1–S20 on the iPhone**, then §14. Do not start the Home
dashboard "Improvement" work until the owner asks for it.


## 7. Unresolved risks

Fifteen, with severity, evidence, owner and gate, in [`docs/41`](docs/41_RELEASE_READINESS.md) §6.

- 🔴 **R1 Nothing has run on a physical iPhone.**
- 🔴 **R2 Administrator MFA does not exist.** `/admin` is a password plus a proxy.
- 🔴 **R3 No off-machine database backup.** A disk failure loses everything.
- 🟠 **R4 17 backend / 18 mobile production dependency advisories**, recorded
  and not bumped: dependency work is its own isolated checkpoint.
- 🟠 **R5** one static `PLATFORM_ADMIN_KEY` · **R6** no contact-delivery provider ·
  **R7** `SEED_DEMO` is opt-out · **R8** no restore drill since 2026-08-05 ·
  **R9** no spreadsheet has opened an exported CSV · **R10** no error reporting.
- 🟡 **R11–R15** unvalidated env reads, lint debt, `Televisions` still `serial`,
  a bare `setInterval` outbox, Android strict-ROI unverified.
- 🟡 `CORS_ORIGINS` in the backend `.env` names `192.168.100.100:8081`, one octet
  from this machine. Web preview only; Expo Go is unaffected.

## 8. Decisions required from the owner

Ten, in [`docs/45`](docs/45_EXTERNAL_DECISIONS.md). **D4 hosting, D5 database
hosting and D6 backups are the critical path and block staging.** D1 domain comes
first in practice because the mobile bundle compiles those URLs in.

The `branch_manager` grant decision is **resolved**: authorised and applied.

## 9. Gates

| # | Gate | State |
|---|---|---|
| 1 | Automated verification | ✅ **green — backend, mobile, catalogue and grants; live 115/0** |
| 2 | Browser verification | ✅ passed (earlier session) |
| 3 | **Physical-device acceptance** | 🔴 **not started — 58 checks, all red** |
| 4 | Staging deployment | 🔴 not started |
| 5 | Production launch | 🔴 not started |

**Nothing device-dependent is marked verified** — not native sharing, spreadsheet
opening, scanner behaviour, RTL layout, dark mode, haptics, camera behaviour or
Reduce Motion.

⚠️ **Check freshness before trusting any server you find running.** Several
failures on this project — a 404 on an endpoint that existed, a Metro predating a
fix, a `PluginError` from a bundler started before `node_modules` was wiped, and a
static file server sitting on Metro's port — were all one stale process. Resolve
the PID and compare its start time against the last commit before concluding
anything.
