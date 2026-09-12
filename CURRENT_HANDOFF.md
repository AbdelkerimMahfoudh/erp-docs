# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Owner: **NONE**
- Last owner: **CLAUDE-A**, `2026-09-12T06:35Z` → `2026-09-12T19:10Z` (one account
  usage-limit pause mid-way, resumed in the same session) — **completing the
  Home / Quick Sell / Quick Receive milestone**: optional-seller receiving,
  Quick Receive, the proven cause of the wrong Home figures, and the missing
  real-HTTP verification.
- Takeover HEADs, verified against the trees: docs `3f55942` · backend `66b53f7`
  · mobile `4e9ce19`, all clean and level.
- **Sections §1–§9 further below are retained history from earlier phases.** The
  tables in this section are current.

### What changed

| Part | Commits | Summary |
|---|---|---|
| **Optional-seller receiving** | backend `f426253` | migration `0070`: `purchases.supplier_id` and `supplier_payments.supplier_id` nullable, FKs kept. No supplier only when `paidAmount` equals the total, stated explicitly; a balance with nobody named is refused (`supplier_required_for_balance`); no placeholder supplier; payment, units and audit still written; named suppliers unchanged |
| **Quick Receive** | mobile `207b735` | Home → Receive → scan or type → recognised, chosen or created product → cost → Add to stock → server-confirmed result. Seller under *More details*; IMEI 2 optional; registered IMEI refused; detour and draft state preserved; one request key across retries |
| **Draft warning on web** | mobile `86a5de0` | `useDraft` no longer reports a browser that keeps no drafts (`unsupported`) as a refused draft |
| **Expo Doctor** | mobile `e960ef6` | 14 packages moved one patch within SDK 57; **doctor 21/21** |
| **Rollup audit / repair tool** | backend `8c576b5` | `scripts/rollup-audit.js` — read-only by default; `--repair` recomputes only drifted rows through the production service |

### HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`8c576b5`** | level | 0 |
| `erp-mobile` | `reports-export` | **`207b735`** | level | 0 |

### Migration applied this phase

| # | What | Evidence |
|---|---|---|
| `0070_optional_supplier_on_purchase` | `purchases.supplier_id`, `supplier_payments.supplier_id` → NULL; nothing dropped or backfilled; 4 FKs to `suppliers` kept | Backup first: `~/erp-backups/phonestore-20260912-173146-pre-optional-supplier.sql` — 820 048 B, `-- Dump completed`, 88 tables, 24 triggers (grep said 25: one wrapped form double-counted; names compared equal), 0 raw binary. Restored into `prisma_verify_optional` (88 tables, 24 triggers, trigger names identical to live), migrated and lifecycle-tested there, **then** `prisma migrate deploy` on live: 69 applied, up to date; live rows unchanged |

### 🔴 Needs review — live rollup repair (NOT applied)

**Proven cause:** audit trail shows `Sale create` ×28 on 2026-09-10 and ×4 on
2026-08-08 with no surviving `sales` rows — verification fixtures hard-deleted
outside the app — and `RollupListener` has no path that recomputes a rollup when
source rows vanish. Not tenant contamination (one company, one branch;
`sale_items.company_id` always equals its sale's).

| Branch-day (Demo Phone Store / Main Store) | Rollup revenue | Ledger | Rollup net | Sales r/l |
|---|---|---|---|---|
| 2026-08-03 | 1 000.00 | 1 000.00 | 200.00 | 1/1 — correct |
| **2026-08-08** | 40.00 | 0.00 | 31.80 | 1/0 |
| **2026-09-10** | 388 300.00 | 0.00 | 328 300.00 | 6/0 |

Overstated by **388 340.00**. Proven on the isolated restore: recompute of the two
rows → every row matched the ledger; 2026-08-03 unchanged. **Live Home still shows
328 300 profit until this is approved.** Procedure (from `backend/`, needs a
current build): backup per `docs/22` → `DB=phonestore node scripts/rollup-audit.js`
(confirm exactly these 2 rows) → `DB=phonestore node scripts/rollup-audit.js
--repair` → expect "every rollup row now matches the source ledger".

### Verified, by kind

| Kind | Result |
|---|---|
| **Backend** | `tsc` clean · **131 suites / 2415 tests** (was 130/2403; +`optional-supplier` 12) · `prisma validate` · migrate status 69 up to date |
| **Mobile** | `tsc` clean · lint **0 errors / 33 warnings** (baseline — one new warning found and fixed) · **51 pure suites** · EN/FR/AR parity via `Catalogue` · web export (`quick-receive.html`) · **Expo Doctor 21/21** |
| **Real HTTP, isolated DB** (`prisma_verify_optional` on `127.0.0.1:3011`) | **24 passed, 0 failed**: no-seller + explicit full payment; refusal with a balance and with the amount omitted; named seller left owing (outstanding +2 000 exactly); dual-IMEI as one unit found by either IMEI; registered IMEI refused; replay returns original with no second unit; same key + different delivery → 409; non-cash sale without account refused; received phone sold at configured price with margin = price − cost; sale replay not double-charged; unit leaves stock; Home before/after moved exactly (profit +8 500, sales +10 000, collected +10 000). SQL: no-seller purchases `paid` with a payment row (`supplier_id` NULL), units keep cost |
| **Renders** (isolated API, request-rewritten) | Home + Quick Receive, **FR and AR, light and dark** — empty, already-registered, unrecognised, product picker, recognised details, More details, server-confirmed *Added to stock*. `dir` correct, no leaked internals. 32 screenshots |
| **Receipt privacy** | unchanged and still asserted by `receipt-privacy.test.ts` (in the 51 suites) |
| **Physical device** | 🔴 **none.** `docs/24` §26 R1–R16 and §25 Q1–Q24 open |

Two genuine defects were found by rendering and fixed before commit: Quick
Receive offered only *Create product* for an unknown model (no *Choose product*),
and the web draft warning. Script bugs caught and corrected, not counted as
passes: a sale priced below the configured floor, a vacuous replay assertion,
and non-unique test IMEIs.

### Live data

**Business records unchanged:** purchases 9 · units 52 · sales 7 · payments 7 ·
supplier_payments 0. Unit-id MD5 `8a62750e3c298bd34f1a9891ff2ad17f`, sale-id MD5
`1e9d9c8cc20104d1a7f9182891bfd19b` — identical to before. **Audit 828, zero rows
written since the backup**: every sign-in and write in this phase went to the
isolated database. The one change to live was the schema (`0070`). Live
`daily_rollups` untouched (audited read-only).

### Services

| Service | State |
|---|---|
| API `:3010` | running from a fresh `nest build` including `0070`; stopped and restarted by exact PID |
| Metro `:8081` | listening; not started by this phase |
| MySQL `:3306` | the user's WAMP stack |
| Isolated API `:3011`, static server `:19006`, headless Chrome `:9333` | started for verification and **stopped** |
| `prisma_verify_optional` | **dropped**; only pre-existing `prisma_staging*` remain. Sanitised dump deleted |

### The next exact action

1. **Review and approve the live rollup repair** above (two rows, one command).
2. `docs/24` **§26 R1–R16** and **§25 Q1–Q24** on a handset — nothing has run on one.
3. Still deferred: catalogue images, portal redesign. The **pre-release security
   gate** (`docs/48`) remains a release blocker, not started. No new feature was
   begun.

### Verified this session, by kind

| Kind | Result |
|---|---|
| **Code — backend** | `tsc` clean · **126 suites / 2360 tests**, 0 failed (new: dual-IMEI purchase 9, scanner hint codes 5). One earlier full run showed 1 failure while MySQL and two API processes were being restarted; the rerun and a third full run were 2360/2360 |
| **Code — mobile** | `tsc` clean · lint **0 errors, 33 warnings** (baseline) · **44 pure suites**, 0 failed (new receive-outcome 18) · EN/FR/AR **2044 × 3, identical order** |
| **Backup + restore proof** | `~/erp-backups/phonestore-20260911-043354-pre-receiving.sql` — 729 058 B, `-- Dump completed`, 24 triggers, 0 raw binary. Sanitised copy restored into `prisma_verify_receiving`: 88 tables, 24 triggers, sales 7, units 11, audit 787, unit-id MD5 `2a1dc9bf…` — **identical to live**. Sanitised copy deleted |
| **Isolated MySQL, successful lifecycle** (API on `127.0.0.1:3011`, database `prisma_verify_receiving`) | **14 passed, 0 failed**: product create writes no unit/stock/purchase; unknown IMEI carries `hintCode`; primary-only + dual-IMEI phones + 3 cables in one delivery → units +2, purchases +1, stock +3; IMEI 2 stored on the same unit; `/units/<IMEI 1>` and `/units/<IMEI 2>` return one id; search by IMEI 2 finds it; audit 1 Purchase + 2 Unit rows; lost-response retry replays with the same accepted lines; 5 concurrent identical retries → no second purchase, unit, stock or audit movement; partial delivery names C1 + stock line, refuses A1, moves units +1 / stock +2; corrected remainder under a new key moves only itself |
| **Isolated MySQL, expected refusals** | **7 passed, 0 failed**: all refused (IMEI 1 registered; IMEI 2 registered as another phone's IMEI 2, pair named); IMEI 2 equal to an existing IMEI 1; a number used as IMEI 2 and IMEI 1 in one delivery → duplicate in batch; malformed IMEI 2 → 400; key reused with a different delivery → 409; `/scan` with new IMEI 1 + registered IMEI 2 → already in inventory; refusals wrote nothing beyond the one legitimate phone |
| **Isolation teardown** | isolated API stopped by PID after matching its command line; database dropped (0 schemas remain); live `phonestore` unchanged — purchases 9, units 11, sales 7, audit 787, 0 `ZZ-` products |
| **Live API (read-only)** | unknown IMEI → `hintCode: unknown_imei`; new IMEI 1 + registered IMEI 2 → `alreadyInInventory: true` |
| **Handset** | **none** |

Limitation of the isolated run: its API used the migrator account for both
connections (the application account has no grant on `prisma_*` schemas), so
the audit append-only trigger was present but not exercised as the app user.

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

## 4. Ready to test Receiving (and the Stock screen)

**On the iPhone:** open Expo Go on the same Wi-Fi, scan
**`exp://192.168.100.3:8081`** (or reload), sign in as `devtest@example.com`,
choose **Main Store**, then **Stock → Receive stock**.

| Service | Detail |
|---|---|
| API | `http://192.168.100.3:3010`, PID **20912**, backend **`488effd`** (started from the identical working tree, then committed) |
| Metro | `exp://192.168.100.3:8081`, PID **26348**, `expo start --clear --lan`, serving source at mobile **`09d0e59`** — iOS bundle fetched after the commit contains `receive.imei2.label`, `receive.existing.open`, `receive.uncertain.retry`, `scan.hint.unknownImei`, `purchaseItems` and origin `192.168.100.3:3010` |
| MySQL | `:3306`, the user's WAMP stack; live data unchanged by this session |

Device checks: [`docs/24`](docs/24_DEVICE_QA_CHECKLIST.md) **§16 R1–R12**
(Receiving) and §15 S1–S25 (Stock), all open. Only a handset settles: camera
capture of both IMEIs (R1), **native draft save/restore after an app kill (R9)**,
airplane-mode Finish (R11), screen readers (R12), and §15's S11, S13, S17, S18,
S20, S21.

### Known limitations

- **Serial-tracked items** keep their serial across Create product only when
  typed again; the pending intake holds IMEIs and product barcodes, not serials.
- **No catalogue images** — separate follow-up, [`docs/47`](docs/47_CATALOGUE_IMAGES_SCOPE.md).
- Drafts are not kept on web by design; R9 is handset-only.
- The isolated verification API ran as the migrator; the audit append-only
  trigger was not exercised as the application user there.

## 5. Running services — left up on purpose

- **API** PID 20912 on `:3010` — PID 6624 (confirmed as `ts-node src/main.ts`)
  stopped by PID so the new contract is served.
- **Metro** PID 26348 on `:8081` — **not restarted**; bundle verified.
- The isolated API (`127.0.0.1:3011`, PID 24844, and its launcher) was stopped
  by PID; `prisma_verify_receiving` is dropped.
- Backup kept: `~/erp-backups/phonestore-20260911-043354-pre-receiving.sql`.

## 6. The next exact action

**Reload Expo Go and run `docs/24` §16 R1–R12**, then §15 and §14, on the
iPhone. Do not start the Home dashboard "Improvement" work or catalogue images
until the owner asks.


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
