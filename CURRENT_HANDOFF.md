# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Active account / Owner: **CLAUDE-A**
- `started_at_utc:` **2026-09-10T18:30Z**
- Previous owner: **CLAUDE-A**, `2026-09-10T11:10Z` → `2026-09-10T18:20Z`
- Phase: **implementing A0–A3** (owner-approved, with the binding A2 correction).
  **CP1, CP2 and CP3 are complete and pushed. CP4–CP6 are this session's scope.**
- Next intended action: **CP4 — the mobile requester and Owner approval
  workflow**, preceded by the A1 magnitude detectors the sale flow needs in
  order to have a warning to acknowledge (see the discrepancy note below).

### Takeover verification — 2026-09-10T18:30Z

Every reported baseline figure was re-measured, not trusted.

| Claim | Measured | |
|---|---|---|
| CP1 `d3ab914`, CP2 `e2cb6b1`, CP3 `6287b61` | present, in that order, on `reports-export` | ✅ |
| Backend suite | **119 suites / 2232 tests**, all passing | ✅ |
| Migration `0065` | applied; **64 migrations**, schema up to date | ✅ |
| Permissions | **61 / 61** | ✅ |
| Configured-price floor | resolved through `PricingService.resolveForSaleTx` — `UnitPriceOverride` → `BranchVariantPrice` → `Product.defaultPrice` | ✅ |
| `discount.override` | Owner-only; removed from the retired `branch_manager` | ✅ |
| Backup / restore proof | `phonestore-20260910-174638.sql`, 684 483 bytes, on disk | ✅ |
| `erp-backend`, `erp-mobile` trees | clean and level | ✅ |

**Three discrepancies, all recorded rather than papered over:**

1. **`erp-docs` read dirty for the first ninety seconds, and it was not a
   defect.** My first inspection saw HEAD `48d3adb` saying `IN_PROGRESS` /
   `CLAUDE-A` with `CURRENT_HANDOFF.md` and `SESSION_LOG.md` modified — the
   previous session's closing commit `1f993a1` landed **18:27:18Z**, seconds
   into that read, and pushed. Re-checked: HEAD and `origin/master` are both
   `1f993a1`, and its handoff says `READY_FOR_HANDOFF` / `NONE`. **The previous
   account closed correctly; I simply arrived mid-write.** Recorded because a
   handoff that looks abandoned and a handoff being written are indistinguishable
   in a single snapshot — the second look is what separates them.
2. **A fourth backend commit exists**, `483cab9`, between CP2 and CP3 — the
   fingerprint safeguard binding field, severity and parameters. Correct and
   already described in the log; the three-commit baseline just under-reports it.
3. **A1's detectors do not exist.** CP2 built the acknowledgement engine and
   `warning.types.ts` declares five `magnitude.*` codes, but **nothing computes
   one** — no mutation returns `warnings_pending`. The declared union is
   currently dead. CP4 cannot show "warning acknowledgement" in the sale flow
   until the server can raise one, so the detectors are built first, inside CP4.

The permission verifier also reports `discount.override` as **relabelled** —
display text only, not drift, and expected after CP3.
- 🔴 **Nothing has run on a handset.** [`docs/24` §14](docs/24_DEVICE_QA_CHECKLIST.md),
  **35 checks, every row red.** No approval-UI checks are added yet because the
  UI does not exist.

### Checkpoint state

| CP | Scope | State |
|---|---|---|
| **CP1** | one shared `DECIMAL(14,2)` monetary boundary | ✅ `d3ab914` |
| **CP2** | warning + acknowledgement engine | ✅ `e2cb6b1`, safeguard `483cab9` |
| **CP3** | configured-price floor, Owner approval lifecycle, migration 0065 | ✅ `6287b61` |
| **CP4** | **mobile approval workflow** | 🔵 **next — not started** |
| CP5 | six deterministic anomaly rules | 🔵 not started |
| CP6 | live HTTP run (its backup/restore half is **done** — see below) | 🔵 partly done |

### HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | **`reports-export`** | **`6287b61`** | level | 0 |
| `erp-mobile` | **`reports-export`** | **`ed7d614`** — untouched | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

### Verified this session

| Backend | |
|---|---|
| `tsc --noEmit` | clean |
| Full suite | **119 suites / 2232 tests** (from 116 / 2094) |
| `prisma validate` | valid |
| `prisma migrate status` | **64 applied, up to date** (0065 added) |
| Permission drift | **61 / 61** |
| Boot proof | all four `discount-approvals` routes mapped, `/api/health` 200 |

**Mobile was not touched** and its gates were not rerun — the tree is identical
to the last measurement (40 suites, 1860 × 3 keys, Doctor 21/21, 68 routes,
6 camera anchors).

### The A2 correction, as implemented

**The floor is the configured selling price**, from the existing ladder
(`UnitPriceOverride` → `BranchVariantPrice` → `Product.defaultPrice`). Selling
below it needs Owner approval **even when the sale is still profitable**. Below
cost is a high-risk subset: same approval, plus a reason. **No second editable
floor was invented** — the ladder already is one, and its `version` voids a
stale approval.

`discount.override` is now **Owner-only approval authority** and no longer a
bypass. ⚠️ **Correction to the earlier handoff: `store_manager` never held it.**
The holders were `owner` and the legacy `branch_manager`; it was removed from
`branch_manager`, which is retired but still mapped for older sessions.
Catalogue unchanged at **61**.

An approval is one sale, one unit, one exact price, one branch, thirty minutes,
then spent. Consumption is a **conditional update inside the sale's
transaction**, so two concurrent sales produce exactly one winner. The sale uses
the **approved** price, never the requested one. The floor is checked **per
line**, never on the sale's total margin.

### Migration 0065, and the backup that preceded it

Additive: one table, no column altered, no data migrated. A code rollback leaves
it in place and unused.

**Backup:** `~/erp-backups/phonestore-20260910-174638.sql` — 684 483 bytes,
86 tables, `--hex-blob`, trailer present.

**Restore proof** into disposable `phonestore_restore_20260910174638`: row
counts, money sums, **binary-id SHA-256 checksums** and **all 24 triggers**
matched. The temporary database was **dropped** and its absence verified. This
satisfies CP6's pre-migration requirement.

⚠️ `prisma migrate diff` against the history produced **1172 lines dropping
foreign keys on unrelated tables** — the history carries hand-tuned SQL the
datamodel does not describe. Only the additive part was taken. **Do not run that
diff and apply it.**

### Provisioned as root, and recorded because it did not exist before

- **`phonestore_shadow`** created and granted to `phonestore_migrator`.
  `prisma migrate diff` needs a shadow database and the migrator cannot create
  one. **It persists.**
- The restore-proof database — created and dropped in the same session.

### The next exact action — CP4

**Mobile approval workflow**, into the existing sale flow, with no parallel
sales screen. `mobile/` is clean at `ed7d614` and nothing is half-applied.

- **Requester:** below the configured price → explain that Owner approval is
  needed, show configured and proposed price and the discount, require a reason,
  submit one idempotent request, show `Pending Owner approval`. Never create or
  locally infer a sale. Below cost shows the stronger loss warning **only** to
  users with `cost.view`; others get a safe "enhanced approval is required".
- **Owner:** a notification-linked review surface — unit, product, branch,
  configured price, requested price, requester, reason, expiry; cost and margin
  only when authorized; approve and reject with **high-friction** confirmation
  stating one sale, that exact price, thirty minutes.
- **Completion:** refresh server state, complete the exact sale, consume on
  success, show conflict / expired / voided accurately. Request submission is
  never approval; approval is never a completed sale.
- Endpoints exist: `POST /discount-approvals`, `GET /discount-approvals`,
  `POST /discount-approvals/:id/decide`, `POST /discount-approvals/:id/cancel`.
- EN/FR/AR parity, RTL, no hardcoded copy, no raw colours, Reduce Motion,
  accessible labels; query keys include company, branch, unit and approval.

Then CP5 (six anomaly rules through the warning engine) and the remaining CP6
live HTTP run.

## Running services

**MySQL on `:3306` only** — the user's WAMP stack, not started by this session.

- **No API.** The `:3010` instance used for the boot proof was time-boxed and
  has exited.
- **No Metro.** The Expo dev server started earlier at the user's request has
  also exited.
- ⚠️ **Both are stale relative to the code.** The backend has moved three
  commits since either last ran, and the mobile bundle predates CP1–CP3. Start
  fresh rather than trusting anything found running.

⚠️ **Check freshness before trusting any server you find running.** Several
failures on this project — a 404 on an endpoint that existed, a Metro predating
a fix, a `PluginError` from a bundler started before `node_modules` was wiped,
and a static file server sitting on Metro's port — were all one stale process.

## 1. The roadmap conclusion

**Phase 5's reporting bullet is done. Nothing else on the roadmap is both
unblocked and in scope for an audit session.**

| Remaining work | State |
|---|---|
| Full mistake-prevention suite | **unbuilt and technically unblocked** — scoped in [`docs/41`](docs/41_RELEASE_READINESS.md) §1.1, deliberately **not started** |
| Offline hardening / sync conflicts | blocked on device acceptance, plus one staleness decision |
| Bulk actions, onboarding polish | subjective UI — out of scope by instruction |
| Phase 6 | P2, optional |

Platform control Phases 2–4 are **built**: the website, the approved pricing,
in-app registration with contact verification, and the subscription lifecycle
wired into the app. What is left there is MFA, providers, domain, DNS and TLS —
owner decisions, not code. See [`docs/45`](docs/45_EXTERNAL_DECISIONS.md).

The mistake-prevention suite is the correct next build. All three parts touch
the sacred rules, so it needs the four-step approval in `CLAUDE.md` first.

## 2. Repository state

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `master` | `67352af` | level | 0 |
| `erp-backend` | **`reports-export`** | **`6bb0d53`** | level | 0 |
| `erp-mobile` | `master` | `f47a155` | level | 0 |
| `erp-mobile` | `sdk-57-upgrade` | `c2422c6` | level | 0 |
| `erp-mobile` | **`reports-export`** | **`ed7d614`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` | level | 0 |

Baseline verified at takeover with **no discrepancies**. Tags `pre-reports`
(`67352af`, `c2422c6`), `pre-scan-contract`, `pre-redesign-*` — all pushed.

**`reports-export` is stacked on `sdk-57-upgrade`, not on `master`.** Merge order,
conflict assessment (zero markers, checked with `merge-tree`) and rollback points
are in [`docs/43`](docs/43_MERGE_AND_ROLLBACK.md). **Nothing was merged.**

### Commits this session

| Repository | Commit | |
|---|---|---|
| `erp-backend` | `6bb0d53` | refuse to start production with unsafe defaults |
| `erp-docs` | `5516413` | ownership claim |
| `erp-docs` | *this commit* | the audit and its five documents |

## 3. Process state

Every listener resolved to a PID, executable and command line before anything
was stopped.

| Port | Was | Now |
|---|---|---|
| `8081` | a scratch static server left by the previous session, easy to mistake for Metro | **stopped**, script deleted |
| `3010` | the API, created for verification | **stopped** — device acceptance is postponed, nothing needs it |
| `3306` | `mysqld.exe` from the user's WAMP install | **left running** — not this project's to stop |

No audit history deleted. The soft-deleted verification accounts (`reportmgr`,
`rptemp`) were **not** recreated. The 109 `report_export` audit rows stand.

## 4. Verified totals — rerun this session

| Backend | |
|---|---|
| `tsc --noEmit` | clean |
| Full suite | **116 suites / 2071 tests** (from 115 / 2046) |
| `prisma validate` | valid |
| `prisma migrate status` | **63 applied, up to date** |
| Permission drift | **61 catalogue / 61 database / 0 missing / 0 extra** |
| Report-export regression | **73 tests** |
| Production-config guard (new) | **25 tests** |

| Mobile | |
|---|---|
| `tsc --noEmit` | clean |
| Expo lint | **0 errors**, 33 warnings (unchanged) |
| Pure suites | **40 suites** |
| EN/FR/AR parity | **1860 keys each, identical order** |
| Expo Doctor | **21/21** |
| Web export | clean, **68 routes** |
| Camera patch | **6 anchors**, `expo-camera@57.0.4` |

**The 107/107 live HTTP run is NOT re-claimed.** It is from the previous session
and was not rerun; the API is stopped.

## 5. Objective fixes made

`erp-backend` `6bb0d53`, 25 regression tests, full backend suite rerun after.

**Production could start with four fail-open defaults**, each with a documented
correct value and no enforcement: `COOKIE_SECURE=false` (session cookies in
clear text), `SWAGGER_ENABLED` defaulting **true** (the API surface published),
`API_BIND` defaulting to **every interface** (administration endpoints answering
beside the proxy meant to gate them, with no administrator MFA behind it), and a
`CORS_ORIGINS` list still naming `localhost`. `assertProductionConfig()` now
refuses to boot before anything is built or bound, reports every problem at
once, and is silent outside production. Proven live in both directions.

**`AUTH_THROTTLE_LIMIT` was a control that controlled nothing** — validated,
exposed, and consumed by nothing while the controller hardcoded 10. Now wired,
with the fallback pinned to the schema's own default.

## 6. Unresolved risks

Fifteen, with severity, evidence, owner and gate, in [`docs/41`](docs/41_RELEASE_READINESS.md) §6.

- 🔴 **R1 Nothing has run on a physical iPhone.** Four milestones ride on it.
- 🔴 **R2 Administrator MFA does not exist.** `/admin` is a password plus a proxy.
- 🔴 **R3 No off-machine database backup.** A disk failure loses everything.
- 🟠 **R4 17 backend / 18 mobile production dependency advisories.** Recorded,
  not bumped: dependency work is its own isolated checkpoint in this project,
  and "audit clean" after a silent bump would be the least honest option.
- 🟠 **R5** one static `PLATFORM_ADMIN_KEY` grants cross-tenant provisioning ·
  **R6** no contact-delivery provider · **R7** `SEED_DEMO` is opt-out ·
  **R8** no restore drill since 2026-08-05 · **R9** no spreadsheet has opened an
  exported CSV · **R10** no error reporting or alerting.
- 🟡 **R11–R15** unvalidated env reads, lint debt, `Televisions` still `serial`,
  a bare `setInterval` outbox, Android strict-ROI unverified.

## 7. Decisions required from the owner

Ten, in [`docs/45`](docs/45_EXTERNAL_DECISIONS.md). **D4 hosting, D5 database
hosting and D6 backups are the critical path and block staging.** D1 domain
comes first in practice because everything embeds it — including the mobile
bundle, where those URLs are compiled in, not read at runtime.

D9 payment has a real alternative: the audited administrative grant already
exists and carries no fabricated payment. Launching on grants is legitimate —
it just has to be a written decision rather than an oversight.

## 8. Gates

| # | Gate | State |
|---|---|---|
| 1 | Automated verification | ✅ passed, rerun this session |
| 2 | Browser verification | ✅ passed (previous session) |
| 3 | **Physical-device acceptance** | 🔴 **not started — 35 checks, all red** |
| 4 | Staging deployment | 🔴 not started |
| 5 | Production launch | 🔴 not started |

**Nothing device-dependent is marked verified** — not native sharing, spreadsheet
opening, scanner behaviour, RTL layout, dark mode, haptics, camera behaviour or
Reduce Motion.

**Staging entry:** device acceptance passed · gate 1 green on the deployed commit
· a host that is not a laptop · off-machine backup possible. Full list in
[`docs/44`](docs/44_STAGING_AND_LAUNCH_CHECKLISTS.md).

**Production entry:** staging passed and stable · administrator MFA · a real
delivery provider · domain, DNS, TLS · scheduled verified off-machine backups ·
error reporting and alerting · dependency advisories triaged · a payment
provider **or** a written decision to launch on administrative grants.

## 9. The next exact action

**Work `docs/24` §14 on the iPhone — 35 checks.** Sign in as
`devtest@example.com`. The API and Metro both need starting first; nothing is
running but MySQL.

If the owner would rather build than test: the **mistake-prevention suite**
(`docs/41` §1.1) is the one unblocked milestone, and it needs the four-step
approval before implementation.

Do not merge and do not deploy.

## Running services

- **MySQL on `:3306`** — the user's WAMP stack.
- **An Expo dev server on `:8081`** — `expo/bin/cli start` in `mobile/`, started
  `10:40:29` today. **Not started by this session** and not stopped, because the
  instruction was to leave unrelated or user-owned processes alone. If it
  predates the current mobile HEAD (`ed7d614`), restart it before the device run
  rather than trusting it — a Metro predating a fix is one of the stale-process
  failures this project has already hit.
- **No API.** The three verification instances (`:3010`, `:3011`, `:3012`) were
  each time-boxed and are all stopped; the device run will need one started.

⚠️ **Check freshness before trusting any server you find running.** Several
failures on this project — a 404 on an endpoint that existed, a Metro predating
a fix, a `PluginError` from a bundler started before `node_modules` was wiped,
and a static file server sitting on Metro's port — were all one stale process.
Resolve the PID and compare its start time against the last build before
concluding anything.
