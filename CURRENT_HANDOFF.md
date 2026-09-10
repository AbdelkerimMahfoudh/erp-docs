# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Active account / Owner: **NONE**
- Last owner: **CLAUDE-A**, `2026-09-10T23:25Z` → `2026-09-10T23:45Z` — the
  authorised `branch_manager` grant repair. Before that, CLAUDE-A
  `18:30Z` → `22:45Z` built CP4–CP6.
- Phase closed: **CP1–CP6 of the mistake-prevention suite, implemented and
  live-verified with zero failures** — including the stale grant that held CP6
  at 91/92, now removed by migration `0067` with the owner's authorisation.
- 🟢 **Ready for visible UI testing** — the final code is genuinely being served.
  See §4.
- 🔴 **The milestone is not "fully ready".** Nothing has run on a handset
  ([`docs/24` §14](docs/24_DEVICE_QA_CHECKLIST.md), **58 checks, every row
  red**), and A1's remaining four detectors are not wired.

### Checkpoint state

| CP | Scope | State |
|---|---|---|
| CP1 | one shared `DECIMAL(14,2)` monetary boundary | ✅ `d3ab914` |
| CP2 | warning + acknowledgement engine | ✅ `e2cb6b1`, `483cab9` |
| CP3 | configured-price floor, Owner approval lifecycle, migration 0065 | ✅ `6287b61` |
| CP4 | magnitude detectors + the complete mobile workflow | ✅ `fe81f5d`, `9aa98d2`, `c42c61f`, `68f02dd` |
| CP5 | six deterministic anomaly rules, migration 0066 | ✅ `4d0736d`, `20619e4` |
| CP6 | live HTTP against real MySQL; two code defects fixed | ✅ `0da5a72` |
| **Repair** | **stale `branch_manager` grant removed, migration 0067; both gates corrected** | ✅ **`6ff7f16`** |

### HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | **`reports-export`** | **`6ff7f16`** | level | 0 |
| `erp-mobile` | **`reports-export`** | **`20619e4`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

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

## 4. Ready for visible UI testing

**The API on 3010 runs the repaired backend.** The pre-repair process (PID 23300,
started 22:27:27) was stopped. PID **4636** started **23:40:41**, after
`6ff7f16` landed at 23:39:27, from a clean checkout; listening on `0.0.0.0:3010`
at 23:41:04; **196 routes**, including all 5 discount-approval and both anomaly
routes. From the LAN address the phone will use: `/api/health` **200**;
unauthenticated `/discount-approvals`, `/anomalies` and `/sales` **401** (the
routes exist); a made-up path **404**.

**Metro still serves mobile `20619e4`.** PID **8460**, started 22:28:12 as
`expo start --clear` from `C:\wamp64\www\PhoneStoreERP\mobile`; mobile HEAD
`20619e4`, clean. The bundle was re-fetched and is **byte-identical** to the one
proven at 22:30 — **17 117 577 bytes** — with `approval.needed.title` ×5,
`approvals.confirmTitle` ×4, `warning.magnitude.salePrice.high` ×3,
`attention.title` ×4, `warning.anomaly.belowCostCluster` ×3,
`status.approval.consumed` ×4, `discount-approvals` ×13, `/anomalies` ×4,
`nav.approvals` ×4, `reissuedBecause` ×1 and the inlined origin
`192.168.100.3:3010` ×1. **192.168.100.3 is this machine's current Wi-Fi
address**, re-checked against the adapter.

**Scan `exp://192.168.100.3:8081` with Expo Go**, on the same Wi-Fi.

### Where the changes are unmistakable

| Screen | What is new |
|---|---|
| **Home** | The redesigned grouping — adjoining rows, hairline separators, no rule under the last row |
| **Analytics** | **Needs your attention** at the top: sentences with their numbers, worst first, each dismissible for a week |
| **Money / export** | Export from what you are looking at; the share sheet and a readable spreadsheet |
| **Sell — price warning** | Type ten times the price: *"Does this look right?"* with what you typed and what similar items cost. Nothing sells until you answer |
| **Sell — discount request** | Sell below the set price: the sheet opens on that phone with the set price, your price, the discount, the percentage and a reason field |
| **Approvals — Owner review** | More → Price approvals, or straight from the notification. Item, branch, requester, reason, minutes left — and the cost only if you may see it |
| **Approvals — the states** | Waiting for the Owner → Approved with the minutes left → Used. Or Not approved, Expired, No longer valid — each says something different |
| **Notifications** | *A price needs your approval*, in your language, landing on **that** request |
| **Arabic (RTL)** | The whole approval flow mirrors; prices stay left-to-right; the sentences read naturally |
| **Dark mode** | Approvals and the attention panel, warning tones legible |

**No claim is made about any of this on a physical device.** The list is where
to look, not what was verified.

## 5. Running services — left up on purpose

| Port | What | PID | Started by |
|---|---|---|---|
| `3010` | API from backend `6ff7f16`, bound `0.0.0.0` | 4636 | this session, for the owner's test |
| `8081` | Expo / Metro, cache cleared, serving mobile `20619e4` | 8460 | CP4–CP6 session |
| `3306` | `mysqld.exe` from the user's WAMP install | — | not this session's to stop |

The verification API on `3013` is **stopped** and its port confirmed released.

## 6. The next exact action

**Work [`docs/24` §14](docs/24_DEVICE_QA_CHECKLIST.md) on the iPhone — 58
checks**, of which 36–58 cover the approval workflow and the attention panel.
Both servers are already running the final code.

Then: **wire A1's remaining four detectors** — intake cost, price change, expense
amount, debt payment. The engine, rules and ten translations exist and are
tested; each needs its mutation wired to `WarningGate` the way `sale.create` is,
and its screen taught to answer `warnings_pending`.

Do not merge and do not deploy.

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
