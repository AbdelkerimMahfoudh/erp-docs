# 41 — Release readiness: assessment, gates and risk register

Audited **2026-09-10** against the repositories and the running configuration,
not against the documentation. Where this disagrees with an earlier document,
this one was checked and that one was written.

**Nothing was merged, rebased, deployed, or pointed at a vendor.** Two objective
configuration defects were proven and fixed (§5); everything else is recorded.

---

## 1. Where the roadmap actually stands

Phase 5's reporting bullet is done. What remains in [`docs/08`](08_DEVELOPMENT_ROADMAP.md):

| Item | State | Blocked by |
|---|---|---|
| Full mistake-prevention suite | **unbuilt, technically unblocked** | nothing — see §1.1 |
| Offline-first hardening + sync conflict resolution | partly built | **device acceptance**, and one owner decision |
| Bulk actions, templates, onboarding polish | unbuilt | subjective UI judgement — explicitly out of scope |
| Phase 6 (trade-ins, label printing, CRM, tax export, LLM) | unbuilt | P2, optional |

Platform control Phases 2–4 are **built**, not pending: the website, the approved
pricing, in-app registration with contact verification, and the subscription
lifecycle wired into the app. What is left there is not code — MFA, a delivery
provider, a payment provider, domain, DNS, TLS. Those are in
[`docs/45`](45_EXTERNAL_DECISIONS.md).

### 1.1 The one unblocked non-device milestone, scoped but not started

**Full mistake-prevention suite.** Recorded here so the next session does not
have to rediscover it. It was **not begun** — this milestone is an audit.

Already built: duplicate-IMEI block (global trigger, migration `0042`),
below-cost warning, category-authoritative tracking type, idempotency on intake,
the reviewed return and transfer lifecycles.

Genuinely missing, and none of it needs a device or a vendor:

1. **Order-of-magnitude typo catch** — a cost or price entered 10× or 100× off
   the product's own history. Needs a threshold rule and a confirm step; the
   data (`ProductVelocity`, `InventoryValuation`, prior costs) already exists.
2. **Discount-limit approvals** — `discount.apply` and `discount.override`
   already exist in the catalogue and gate the *act*; there is no configured
   *limit* above which a second person is required.
3. **Anomaly detection** — the rules engine behind the health score exists;
   nothing yet flags a pattern (a seller whose margin collapses, a branch whose
   counted cash drifts one way).

Each is server-side, testable without hardware, and touches the sacred rules —
so each needs the four-step approval in `CLAUDE.md` before implementation.

---

## 2. Verification gates, and which of them anyone has actually passed

Five gates. **Only the first two have been passed.**

| # | Gate | Status | What it proves |
|---|---|---|---|
| 1 | **Automated verification** | ✅ **passed 2026-09-10** | Types, tests, migrations, permissions, parity, patches. §3 |
| 2 | **Browser verification** | ✅ **passed 2026-09-10** | The web build signs in, and a real download produced a correctly named CSV. `docs/40` |
| 3 | **Physical-device acceptance** | 🔴 **not started** | `docs/24` §14, **35 checks, every row red** |
| 4 | **Staging deployment** | 🔴 **not started** | Entry criteria in [`docs/44`](44_STAGING_AND_LAUNCH_CHECKLISTS.md) |
| 5 | **Production launch** | 🔴 **not started** | Blocked on external decisions — [`docs/45`](45_EXTERNAL_DECISIONS.md) |

Gate 3 does not follow gate 2 automatically: it needs the owner and the handset.
Gate 4 cannot start until gate 3 passes, because staging exists to rehearse a
build that has been shown to work on a phone.

### What gate 1 must never be read as

**No claim is made** that native CSV sharing, spreadsheet compatibility, scanner
behaviour, RTL layout, dark mode, haptics, camera behaviour or Reduce Motion
work. Every one of those is a device fact. The sign-in crash of an earlier
session is the standing proof: types, lint, 713 assertions, Expo Doctor and a
web export all passed while a worklet died on the UI thread of a real iPhone.

---

## 3. Gate 1 — rerun in full for this audit

Every number below was produced during this session, not copied.

### Backend

| Check | Result |
|---|---|
| `tsc --noEmit` | clean |
| Full suite | **116 suites / 2071 tests**, 0 failing |
| — before this session's fix | 115 / 2046 |
| `prisma validate` | valid |
| `prisma migrate status` | **63 migrations, up to date** |
| Permission drift | **61 in catalogue, 61 in database, 0 missing, 0 extra** |
| Report-export regression | **73 tests**, 0 failing |
| Production-config guard (new) | **25 tests**, 0 failing |

### Mobile

| Check | Result |
|---|---|
| `tsc --noEmit` | clean |
| Expo lint | **0 errors**, 33 warnings (unchanged React Compiler debt) |
| Pure suites | **40 suites**, 0 failing |
| EN/FR/AR parity | **1860 keys each, identical order** |
| Expo Doctor | **21/21** |
| Web export | clean, **68 routes** |
| Camera patch | `expo-camera@57.0.4`, **6 anchors** |

### Not rerun

The **107/107 live HTTP run** against MySQL is from the previous session and is
**not re-claimed here**. The API was stopped as verification residue (§4); a
fresh count would require rerunning it, and quoting an old number as a new one
is exactly the kind of claim this audit exists to prevent.

---

## 4. Operational residue, resolved

Every listener was resolved to a PID, executable and command line before
anything was stopped.

| Port | Was | Action |
|---|---|---|
| `8081` | `node …/scratchpad/serve.js` — a static server for the web build, left by the previous session | **stopped**, script deleted. It could have been mistaken for Metro |
| `3010` | `node dist/src/main.js` — the API, created for verification | **stopped**. Device acceptance is postponed, so nothing needs it running |
| `3306` | `mysqld.exe` from `C:\wamp64\bin\mysql\mysql8.4.7` — the user's WAMP stack | **left running.** Not created by this project's verification, and other work on this machine may depend on it |

No audit history was deleted. The soft-deleted verification accounts
(`reportmgr`, `rptemp`) were **not** recreated, and the 109 `report_export`
audit rows stand.

---

## 5. Objective defects proven and fixed

Both are in `erp-backend` `6bb0d53`, with 25 regression tests, and the full
backend suite was rerun after them.

### 5.1 Production could start with four fail-open defaults

Each already had a documented correct value and **no enforcement**. The failure
mode was identical every time: the application starts, and is quietly less safe
than the documentation claims.

| Setting | Default | What the default does in production |
|---|---|---|
| `COOKIE_SECURE` | follows `NODE_ENV`, but `false` is accepted | Session cookies travel **in clear text**. `cookies.ts` said so; nothing checked |
| `SWAGGER_ENABLED` | **`true`** | The whole API surface published to anyone who asks |
| `API_INGRESS` | *(was: a blanket rejection of `0.0.0.0`)* | ⚠️ **This rule was wrong and was corrected in `3833677`.** It would have refused this project's own containerised staging stack. The invariant is that the API port is reachable only through the edge, which loopback binding and network isolation both satisfy — see [`docs/46`](46_MISTAKE_PREVENTION_APPROVAL.md) and the session log |
| `CORS_ORIGINS` | fail-closed when empty | A list still naming `localhost` is a copied `.env`, granting a laptop browser a credentialed path into real data |

`assertProductionConfig()` now runs **before anything is built or bound**,
reports every problem at once rather than one per restart, and is **silent
outside production** — a developer's phone still has to reach `0.0.0.0` over the
LAN, and `docs/39` keeps a plain-HTTP LAN path open deliberately.

Proven live: with all four wrong, the process refuses to start and prints the
three applicable reasons. With them right, development boots and answers
`/api/health` 200.

### 5.2 `AUTH_THROTTLE_LIMIT` was a control that controlled nothing

Validated by Joi, exposed on `AppConfigService`, and **consumed by nothing** —
`auth.controller.ts` hardcoded `{ limit: 10 }`. An operator tightening it after
a credential-stuffing attempt would have changed nothing, and no test or log
would have said so. Now read from the environment, with the fallback pinned to
the schema's own default so a missing variable behaves exactly as before.

**Dead configuration is worse than none, because it looks like a control.**

---

## 6. Risk register

Severity is about consequence if it reaches production unaddressed.

| # | Risk | Sev | Evidence | Owner | Gate |
|---|---|---|---|---|---|
| R1 | **Nothing has run on a physical iPhone.** Four milestones of UI, the scanner contract and native sharing all ride on it | 🔴 **High** | `docs/24` §14, 35 checks, all red. The earlier sign-in crash passed every automated gate | Owner | **3** |
| R2 | **Administrator MFA does not exist.** The `/admin` boundary is a password plus an edge proxy | 🔴 **High** | No `mfa`/`totp` anywhere in `backend/src`; `main.ts` names the gap itself | Owner | **5** |
| R3 | **No off-machine database backup.** A disk failure loses every sale, unit and audit row | 🔴 **High** | `docs/22` §5, "Database dumps are still local-only" | Owner | **4** |
| R4 | **17 production-dependency advisories** (5 high, 10 moderate, 2 low) in the backend; 18 (3 high, 15 moderate) in mobile | 🟠 **Medium** | `npm audit --omit=dev`. `@nestjs/core`, `body-parser` need `--force`; `brace-expansion`, `js-yaml`, `joi`, `file-type` do not | CLAUDE | **4** |
| R5 | **`PLATFORM_ADMIN_KEY` is one static shared secret** granting cross-tenant provisioning, compared non-constant-time, with no rotation story | 🟠 **Medium** | `provisioning.controller.ts:83`. Fail-closed when unset or <16 chars, and throttled — so not open, but a single long-lived bearer secret | Owner | **5** |
| R6 | **No contact-delivery provider.** Verification codes are retrieved by shell access to the host | 🟠 **Medium** | `docs/37`; `scripts/staging-verification-code.ts` | Owner | **5** |
| R7 | **`SEED_DEMO` is opt-OUT.** Demo company, branch and owner are seeded unless it is explicitly `false` | 🟠 **Medium** | `prisma/seed.ts:178` | CLAUDE | **4** |
| R8 | **No restore drill since 2026-08-05**, and none scheduled. A drill is only true for the schema it ran against; 63 migrations exist now | 🟠 **Medium** | `docs/22` §5, "Restores are unscheduled" | Owner | **4** |
| R9 | **No spreadsheet has opened an exported CSV.** BOM, delimiter and formula armour are asserted only against this project's own parser | 🟠 **Medium** | `docs/40`, "Not verified" | Owner | **3** |
| R10 | **No error reporting or alerting.** Structured logs exist and nothing watches them | 🟠 **Medium** | No Sentry/OTel in either `package.json`; `pino` writes to stdout | Owner | **4** |
| R11 | **`COOKIE_SECURE`, `API_BIND`, `APP_ENV`, `PLATFORM_ADMIN_KEY` bypass the Joi schema**, read straight from `process.env` against the project's own rule | 🟡 **Low** | `env.validation.ts` vs `grep process.env`. Mitigated by §5.1 for the two that matter most | CLAUDE | **4** |
| R12 | **React Compiler lint debt** — 33 warnings, `set-state-in-effect` and unused vars | 🟡 **Low** | `expo lint`; unchanged across five sessions | CLAUDE | none |
| R13 | **`Televisions` is still `serial`, with five units of stock.** Converting reinterprets real stock | 🟡 **Low** | Standing item since the tracking-type milestone | **Owner decision** | none |
| R14 | **`recognition-outbox` uses a bare `setInterval`.** No scheduler, no visibility, no backoff record | 🟡 **Low** | `recognition-outbox.service.ts:81` | CLAUDE | **4** |
| R15 | **Android strict-ROI placement unverified on hardware**, on a rebased mapping | 🟡 **Low** | Standing since the SDK 57 upgrade | Owner | **3** |

### Why R4 was recorded and not fixed

The non-breaking half is one command. It is still a dependency change across two
lockfiles, and this project has already established that dependency work is its
own isolated checkpoint with its own verification — the SDK 57 patch bump was
handled exactly that way. Bumping transitive packages inside an audit, then
reporting "audit clean", would be the least honest thing available. It is a
scoped follow-up, not a line in this commit.

---

## 7. What this audit did not do

Did not merge, rebase, force-push, delete a branch, or touch a protected branch.
Did not select a vendor, create an account, buy anything, change DNS, or deploy.
Did not take or restore a production backup. Did not recreate deleted accounts.
Did not begin a product feature. Did not mark any device-dependent behaviour as
verified.
