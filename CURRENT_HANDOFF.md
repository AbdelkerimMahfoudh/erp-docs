# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **AWAITING_OWNER_APPROVAL**
- Active account / Owner: **NONE**
- Last owner: **CLAUDE-A**, `2026-09-10T05:30Z` → `2026-09-10T06:40Z`
- Phase closed: **pre-implementation approval checkpoint** for the Phase 5
  mistake-prevention suite, plus a correction to the production bind guard.
  **No feature implementation started.**
- 🟡 **Four approval statements are waiting on the owner** — [`docs/46`](docs/46_MISTAKE_PREVENTION_APPROVAL.md) §9.
  The rulebook requires approval before anything touching the sacred rules, and
  all three features touch margin, cost and permissions.
- 🔴 **Nothing has run on a handset.** [`docs/24` §14](docs/24_DEVICE_QA_CHECKLIST.md),
  **35 checks, every row red.**

### What changed this session

**The bind rule I added last session was wrong and would have blocked staging.**
`6bb0d53` rejected `API_BIND=0.0.0.0` outright; the project is containerised and
`deploy/docker-compose.staging.yml` says explicitly not to bind loopback inside
a container. `docs/39` §3 states the real invariant — *the API port is reachable
only through the edge* — which two implementations satisfy with **opposite** bind
addresses. Corrected in `3833677` with `API_INGRESS=loopback|network`, declared
rather than detected, neither value recommended.

The same declaration fixed a second defect it exposed: **`trust proxy` was never
configured**, so behind the edge `req.ip` was the edge — making
`AUTH_THROTTLE_LIMIT` a budget shared by every user on the platform rather than
per-client. And a third instance of the same error class was removed: the
`APP_DATABASE_URL` localhost check refused an ordinary single-VPS deployment.

Every other protection from `6bb0d53` stands.

### Verified this session

| Backend | |
|---|---|
| `tsc --noEmit` | clean |
| Full suite | **116 suites / 2094 tests** (from 116 / 2071) |
| `prisma validate` | valid |
| `prisma migrate status` | **63 applied, up to date** |
| Permission drift | **61 / 61** |
| Production-guard focused | **48 tests** (from 25) |

**Four startup proofs, all run:** invalid production refuses with three reasons ·
`API_INGRESS=network` starts on `0.0.0.0:3011` (the deployment the old rule
blocked) · `API_INGRESS=loopback` starts on `127.0.0.1:3012` · development
unchanged. All four answered `/api/health` 200 where they started.

| Mobile — unchanged tree at `ed7d614` | |
|---|---|
| Pure suites | **40 suites** |
| EN/FR/AR parity | **1860 keys each, identical order** |
| Expo Doctor | **21/21** |
| Camera patch | **6 anchors** |

Expo Doctor first reported "2 checks failed" under heavy parallel load and
**21/21** on a clean rerun; it performs registry lookups and is not hermetic.
Not a defect. The **68-route web export was not rerun** — the mobile tree is
unchanged since it was last measured, and re-exporting an identical tree proves
nothing new.

### Commits this session

| Repository | Commit | |
|---|---|---|
| `erp-backend` | `3833677` | the API bind rule was wrong, and would have blocked staging |
| `erp-docs` | `9aeff3e` | ownership claim |
| `erp-docs` | *this commit* | the approval packet |

### What the owner is being asked

Four statements in [`docs/46`](docs/46_MISTAKE_PREVENTION_APPROVAL.md) §9:

- **A0** — bound every money field to `DECIMAL(14,2)` with one shared constant.
  This closes a defect that exists **today**: `SaleLineDto.price`, `discount`,
  `PaymentInputDto.amount` and `CreateExpenseDto.amount` have no upper bound,
  while `pricing.dto.ts` defines a correct one locally and shares it with nobody.
  **The smallest of the four, and it can ship alone.**
- **A1** — order-of-magnitude warnings, 10×, advisory, never auto-correcting,
  silent where there is no reference.
- **A2** — a single-use, 30-minute, one-unit discount approval. Requested by
  `sale.create`, granted by `discount.override`, **no new permission key**, never
  a reusable licence to sell below cost.
- **A3** — six deterministic anomaly rules, Owner-only for the two involving
  margin, dismissible for 7 days. No machine learning, no external service.

A short "approve A0–A3" or a targeted correction is enough to proceed.

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

**MySQL on `:3306` only.** The API and Metro were both stopped as verification
residue.

⚠️ **Check freshness before trusting any server you find running.** Several
failures on this project — a 404 on an endpoint that existed, a Metro predating
a fix, a `PluginError` from a bundler started before `node_modules` was wiped,
and a static file server sitting on Metro's port — were all one stale process.
Resolve the PID and compare its start time against the last build before
concluding anything.
