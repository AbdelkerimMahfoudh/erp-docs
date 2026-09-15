# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Owner: **NONE**
- Last owner: **CLAUDE-A** · `2026-09-15` (the prompt said CLAUDE-B; this
  account is CLAUDE-A, per the user's standing correction)
- Last phase: **scope correction + six-screen layout** — complete.
- Takeover HEADs were: docs `fdfc5e4` · backend `80e25ef` · mobile `e30f609`,
  clean and level; migrations through `0073`.

### ⚠️ The scope rule, after a correction

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. The previous milestone removed more than was
authorised; that was reversed here (mobile `fe30eb7`). **Goals, Analytics,
anomalies and the WhatsApp summary settings are live features.** No further
removal without the user's explicit approval, and a mockup that omits a feature
does not authorise deleting it.

### What changed

| Part | Commits | Summary |
|---|---|---|
| **Restored** (not authorised for removal) | mobile `fe30eb7` | Analytics and Goals screens and `lib/goals.ts`; the Performance hub and Reports group; closing sign-off landing on Analytics; the WhatsApp summaries settings section; the "verified badge coming soon" line; the disabled "Sell to this store" row; 72 translation keys × EN/FR/AR; the tests covering them |
| **Sell account bug** | mobile `b9fd2e9` | full Sell and Quick Sell offered an Owner's deactivated receiving accounts, which the server then refused. Both now offer `selectableAccounts()`; snapshot labels still read the full list |
| **Period movements** | backend `3540388` | `GET /closings/movements?from&to` (`report.view`): recorded money in/out/net per channel. The closing's own query generalised to a range **in place**; the closing still asks for one day. No schema change |
| **Six layouts** | mobile `c0dafbd` | shared `TabHeader` and `Disclosure`; Home (two actions side by side, four figures, expandable profit); Money (shared period, in/out/net, cash & accounts, four actions); Results (`/money`, same period, closed breakdown and returns timing); Partners (own code, expandable connected stores, Consignments row); Stock (server count and stock cost, transfers button); More (Activity / Reports / Manage / Account). Every money-moving mutation invalidates Home, Money and Results |
| **Render fixes** | mobile `494cd09` | Arabic dates were reversed by LTR isolation; Partners' empty state was pushed down a page; period segments under 44pt; Stock header said "phones" for a mixed count |

**No schema migration was created or applied in this phase**, and the live
database was not written to at any point.

### HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`3540388`** | level | 0 |
| `erp-mobile` | `reports-export` | **`494cd09`** | level | 0 |

### Verification

| Check | Result |
|---|---|
| Backend | `tsc` clean · **131 suites / 2 390 tests** (+`period-movements` 6) · `prisma validate` · migrate status up to date (through `0073`) · permission drift clean |
| Mobile | `tsc` clean · lint **0 errors / 32 warnings** · **54 pure suites** (+`layout` 14, +`receiving-accounts` 5) · EN/FR/AR parity at compile time · web export · every route exported, none for suppliers · no raw colours or hardcoded copy in the new screens |
| Expo Doctor | **20/21** — two Expo patch versions drifted upstream (`expo` 57.0.22 vs ~57.0.23, `expo-sharing` 57.0.19 vs ~57.0.20). No dependency was touched here; left for a deliberate upgrade |
| Isolated API (`prisma_verify_layout`, 127.0.0.1:3011) | **15/15 + 2 + 5**: suppliers gone and non-mutating; receive without a supplier (primary-only and dual IMEI); either IMEI finds the same unit; cash sale; expense confirmed; faulty unit; per-channel movement matching the closing exactly; Employee refused figures (403); reversed range refused; connection request, acceptance, a 5 000 loan accepted, and a shared summary with no cost, customer or stock of the other store |
| Renders | **136 captures**: Home, Partners, Money, Results, Stock, More in EN/FR/AR × light/dark at 360, 390 and 430 pt, plus empty / incoming request / connected Partners, zero-activity and populated Money and Results, mixed stock, an Employee's restricted view, and loading and error states. Four defects found and fixed (above); no clipped text, no horizontal overflow, no leaked keys, no development gear |

Web rendering is not device verification: `docs/24` §29 L1–L25 are open, and
§28 S1–S15 remain open from the previous phase.

### 🧹 Outstanding cleanup (needs the user)

The machine rebooted at 17:46 on 2026-09-15, which stopped the live API, Metro
and MySQL (WAMP is a manual service and this account cannot start it). Left
behind:

- **Temporary database `prisma_verify_layout` still exists.** Drop it once WAMP
  is running: `mysql --defaults-extra-file=~/.my.cnf -e "DROP DATABASE prisma_verify_layout"`.
- The live API is **not running** and, when started, will serve the new build
  including `GET /closings/movements`; the mobile Money tab needs it.
- Backups from this phase: `~/erp-backups/phonestore-20260915-063543-pre-0072.sql`
  and `phonestore-20260915-082022-layout-verify.sql` (838 452 B, verified,
  restored with an identical fingerprint).

Live data was read (one `mysqldump`) and never written: every fixture went to
the isolated copy through the isolated API. The last live fingerprint taken
(08:20) matched the post-`0073` state exactly — units 53, sales 7 / 10 051,
purchases 10 / 21 185, payments 7, expenses 2 / 600, audit 836,
role_permissions 282, migrations 72.

### 📋 Known, not fixed

- On web, a screen pushed from a tab announces its back button as "(tabs),
  back". The native stack exposes no label option; it needs a navigation fix.
- There is no Customers screen; More does not list one, because building it
  would be a new feature.

### 🔴 Still pending separate approval — live rollup repair (NOT applied, NOT part of this phase)

**Proven cause:** audit trail shows `Sale create` ×28 on 2026-09-10 and ×4 on
2026-08-08 with no surviving `sales` rows — verification fixtures hard-deleted
outside the app — and `RollupListener` has no path that recomputes a rollup when
source rows vanish.

| Branch-day (Demo Phone Store / Main Store) | Rollup revenue | Ledger | Rollup net | Sales r/l |
|---|---|---|---|---|
| 2026-08-03 | 1 000.00 | 1 000.00 | 200.00 | 1/1 — correct |
| **2026-08-08** | 40.00 | 0.00 | 31.80 | 1/0 |
| **2026-09-10** | 388 300.00 | 0.00 | 328 300.00 | 6/0 |

Overstated by **388 340.00**; proven repairable on an isolated restore. Live Home
still shows 328 300 profit. Procedure (from `backend/`, current build): backup per
`docs/22` → `DB=phonestore node scripts/rollup-audit.js` (confirm exactly these 2
rows) → `DB=phonestore node scripts/rollup-audit.js --repair`.

### Verified, by kind

| Kind | Result |
|---|---|
| **Backend** | `tsc` clean · **132 suites / 2442 tests** (was 131/2415; +`dealing-authorization` 27) · `prisma validate` · migrate status up to date · permission catalogue and grants complete |
| **Mobile** | `tsc` clean · lint **0 errors / 33 warnings** (baseline) · **52 pure suites** (+`partners` 16; registry updated for the new bar) · EN/FR/AR parity via `Catalogue` · web export emits `(tabs)/partners`, `partners/[id]`, `stores` · **Expo Doctor 21/21** |
| **Real HTTP, two signed-in stores, isolated DB** (`prisma_verify_partners` on `127.0.0.1:3011`) | **53 passed, 0 failed**: lookup preview; self-request refused; manual store refused; request, retry, crossed request refused, requester cannot accept own, decline, reopen, withdraw (and the other side cannot); simultaneous requests → one stands, one told to accept it; accept, double-accept refused; loan and consignment through custody; both stores' summaries mirror money and phones; no cost/margin/customer/purchase in the other store's summary; partner's unit unreadable; removal during an in-flight loan blocks its acceptance but not its rejection; after removal no new loan or consignment either way, while repayment report/confirm and phone return/acknowledge still work; history readable; reconnect; acceptance raced against removal — no 5xx |
| **SQL proof** | the raced acceptance committed at `15:42:47.867`, removal at `.896` — serialised. A hand-inserted legacy `manual_store` counterparty was refused for a loan and a consignment (`connection_required`); lending to a person still worked |
| **Renders** (isolated API, both stores) | FR and AR, light and dark: incoming request with badge, add-store preview, sent request, connected list, connected-store detail from both sides, lend preselected, Home full-sale link, disconnected detail, legacy `/stores`; phones held by each side read from the rendered page. No raw keys or leaks. One wording defect fixed ("1 téléphones") |
| **Physical device** | 🔴 **none.** `docs/24` §27 P1–P23, §26 R1–R16, §25 Q1–Q24 open |

### Live data

**Business records preserved.** Before `0071`: units 53 · sales 7 · purchases 10 ·
payments 7 · audit 831; after: identical. The one unit, product and purchase added
since the earlier backup were created at Test Store by a real user of the app at
15:44–15:45, not by this work — every verification sign-in and write went to the
isolated database. Live has no connections, loans or consignments; the only change
this phase made to live is the schema (`0071`).

### Services

| Service | State |
|---|---|
| API `:3010` | running from a fresh `nest build` including `0071`; previous instance stopped by exact PID |
| Metro `:8081` | listening; not started by this phase |
| MySQL `:3306` | the user's WAMP stack |
| Isolated API `:3011`, static server `:19006`, headless Chrome `:9333` | started for verification and **stopped** |
| `prisma_verify_partners` | **dropped**; only pre-existing `prisma_staging*` remain; sanitised dump deleted |

### The next exact action

1. **Approve or decline the live rollup repair** (above).
2. **Decide the direct inter-store sale** questions in `docs/21` before it is built.
3. Handset checks: `docs/24` §27 P1–P23 (two phones, one per store), then §26 and §25.
4. The **pre-release security gate** (`docs/48`) remains a release blocker, not
   started. Catalogue images, portal redesign and publishing were not begun.

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
