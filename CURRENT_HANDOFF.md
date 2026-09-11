# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Active account / Owner: **CLAUDE-A**, `started_at_utc: 2026-09-11T12:33Z`
- Takeover HEADs: docs `c2f8d3c` · backend `3554c5e` · mobile `abd834a` · control-web `c764d63`
- Active scope: **Checkpoint 3 — operational screens** on the Stock visual system:
  safeguards (history folding, visual guard) → 3a Sell → 3b Receive (+ serial through
  Create product) → 3c Transfers/consignment → 3d Money → 3e More. Each sub-checkpoint
  committed separately; stop and report after 3e. Home "Improvement", catalogue
  images and portal redesign stay deferred.
- **Done so far:** safeguards mobile **`ea5419d`**; **3a Sell** mobile **`f073ce5`**
  (renders FR/AR/dark live; refusal and success on isolated `prisma_verify_sell`;
  `docs/24` §18 SL1–SL12 open). Gap reported, not built: no customer or
  receiving-account selection on Sell.
- Services restarted after a session restart: API `:3010` (`npm run start:dev`),
  Metro `:8081`; isolated API `127.0.0.1:3011` on `prisma_verify_sell` still up —
  stop and drop it after 3b.
- **3b Receive** mobile **`679e074`**: serial kept through Create product and its
  cancellation (4 new tests, rendered FR/AR/dark); arrow-only back on Receive;
  labelled unit cost. `docs/24` §19 RC1–RC8 open.
- Next intended action: **3c Transfers and consignment** — human-language states,
  stock movement kept separate from settlement, who holds the item and who acts next.
- **Checkpoint 2 committed** (`12:22Z → 12:30Z`): mobile **`abd834a`** — sign-in rebuilt
  on the Text primitive, InlineNotice and tokens; registration and verification off
  utility classes; `labelStrong` / `captionStrong` / `tabLabel` added to the type scale
  and used by Chip, FilterChip, StatTile, Toast, the tab bar and Store ID; new guard
  `lib/design/visual-system.test.ts`. Verified: tsc clean, lint 33 (baseline), 46 pure
  suites, web export 70 routes, sign-in/registration renders FR light, FR error, AR,
  FR dark; Metro bundle contains the new variants. No behaviour change, no backend change.
- Audit result for the rest of the app: **no raw colours, raw font sizes/weights, font
  families or utility classes remain in any screen or component**. Further alignment
  is layout-level (spacing, card structure, fixed actions) and must be judged screen
  by screen on renders.
- **Next exact action:** checkpoint 3 — render Sell, Receive, Transfers and the More
  hubs in FR/AR, compare against the Stock reference, and correct structural drift
  through shared primitives only. Home dashboard "Improvement", catalogue images and
  the portal redesign stay out.
- Last owner: **CLAUDE-A**, `2026-09-11T11:46Z` → `2026-09-11T12:20Z` — **Stock
  visual system, checkpoint 1: Unit detail and History**. Takeover HEADs: docs
  `7fdea94` · backend `488effd` · mobile `09d0e59` · control-web `c764d63`.
- **Checkpoint 1 committed:** backend **`3554c5e`** (history as language-free facts,
  newest 200, reservation audited, transfer destinations named, supplier/purchase
  reference on the unit), mobile **`b5b8a4b`** (arrow-only back app-wide, history in
  words with day groups, folding and "Show N more", item summary, French dates).
- Verified: backend 127 suites / 2369 tests; mobile tsc, lint 33 (baseline), 45
  pure suites (unit-history 21), parity 2082 × 3, web export 70 routes; French and
  Arabic renders with no raw code or `(tabs)`; API PID **21100** serving `3554c5e`;
  Metro PID **26348** bundle contains `history.event.received`, `history.more`,
  `headerBackButtonDisplayMode`, `unit.imei2`.
- 🔴 No handset: `docs/24` **§17 U1–U11** open, including the back arrow itself.
- **Next exact action:** checkpoint 2 — apply the approved Stock visual system to
  the next screens (Sell, Receive, Transfers, More hubs), one coherent group per
  checkpoint, through shared tokens/primitives only. Home dashboard "Improvement",
  catalogue images and the portal redesign (plan awaiting approval) stay out.
- Earlier today, same account: **Receiving correction** `04:16Z → 04:45Z`
  (backend `488effd`, mobile `09d0e59`).
- Earlier today, same account: Stock correction pass `03:30Z → 04:10Z`; Indigo
  Stock screen `00:26Z → 03:22Z` (times from commits; earlier recorded times were wrong).
- 🟢 **Ready to test on a handset** — see §4.
- 🔴 **Nothing has run on a handset.** [`docs/24`](docs/24_DEVICE_QA_CHECKLIST.md)
  §14 (58), §15 S1–S25 and new **§16 R1–R12**, every row open. **Native draft
  save/restore (R9) is open** — no device was available; web cannot prove it.
- **No migration.** `units.imei_secondary` and `0042`'s cross-column triggers
  already existed. Backup taken and restore proved anyway (below).
- Home dashboard "Improvement" **not started**; catalogue images remain the
  separate [`docs/47`](docs/47_CATALOGUE_IMAGES_SCOPE.md) follow-up.

### What changed

| Repository | Commit | |
|---|---|---|
| `erp-backend` | **`488effd`** | purchase lines accept `units[] = { identifier, imeiSecondary? }`; IMEI 2 validated and checked in the delivery and against both columns; response names `accepted.identifiers` / `accepted.stockProductIds` (also on replay); `/scan` adds `hintCode` / `hintParams` |
| `erp-mobile` | **`09d0e59`** | IMEI 2 from camera, cost sheet or "Add IMEI 2"; existing phone blocked before cost with "Open this phone"; Choose product; Create product returns to the same Receive with the product selected; translated scan hints; Finish via `lib/receive-outcome.ts` (all / none / partial with new key / uncertain locked under same key) |
| `erp-docs` | *this commit* | handoff, session log, `docs/21` Receiving decisions, `docs/24` §16 |

### HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`488effd`** | level | 0 |
| `erp-mobile` | `reports-export` | **`09d0e59`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` | untouched | — |

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
