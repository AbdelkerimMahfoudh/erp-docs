# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Active account / Owner: **CLAUDE-A**
- `started_at_utc:` **2026-09-10T23:25Z**
- Previous owner: **CLAUDE-A**, `2026-09-10T18:30Z` → `2026-09-10T22:45Z` — closed complete
- HEADs at takeover: docs `4ebab79` · backend `0da5a72` · mobile `20619e4` — all clean and level
- Active scope: **the CP6 repair, explicitly authorised by the owner** — remove the
  stale `discount.override` grant from the retired `branch_manager` role through
  a forward migration, invalidate any session that could still carry it, and
  re-prove Owner-only approval over real HTTP with zero failures.
- **The milestone is NOT closed.** 91/92 is not a pass.
- Next intended action: determine whether sessions or tokens cache permissions.
- Phase closed: **the mistake-prevention suite, CP4–CP6.** CP1–CP3 were
  inherited complete and are unchanged except where a proven defect required a
  focused correction.
- 🟢 **The app is running and waiting for the owner to test it.** See §5.
- 🔴 **Nothing has run on a handset yet.** [`docs/24` §14](docs/24_DEVICE_QA_CHECKLIST.md)
  is now **58 checks**, every row red. Rows 36–58 are new and cover the approval
  workflow and the attention panel.

### Checkpoint state

| CP | Scope | State |
|---|---|---|
| CP1 | one shared `DECIMAL(14,2)` monetary boundary | ✅ `d3ab914` |
| CP2 | warning + acknowledgement engine | ✅ `e2cb6b1`, `483cab9` |
| CP3 | configured-price floor, Owner approval lifecycle, migration 0065 | ✅ `6287b61` |
| **CP4** | **magnitude detectors + the complete mobile workflow** | ✅ `fe81f5d`, `9aa98d2`, `c42c61f`, `68f02dd` |
| **CP5** | **six deterministic anomaly rules, migration 0066** | ✅ `4d0736d`, `20619e4` |
| **CP6** | **live HTTP against real MySQL, and what it found** | ✅ `0da5a72` |

### HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | **`reports-export`** | **`0da5a72`** | level | 0 |
| `erp-mobile` | **`reports-export`** | **`20619e4`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

## 1. Verified this session

| Backend | |
|---|---|
| `tsc --noEmit` | clean |
| Full suite | **123 suites / 2311 tests** (from 119 / 2232) |
| `prisma validate` | valid |
| `prisma migrate status` | **65 applied, up to date** (0066 added) |
| Permission catalogue | **61 / 61 keys** |
| Permission **grants** | 🔴 **REFUSES — one extra grant.** See §3 |
| Live HTTP run | **91 / 92**, plus a 6/6 rejection run. The one failure is that grant |

| Mobile | |
|---|---|
| `tsc --noEmit` | clean |
| Expo lint | **0 errors, 33 warnings** — unchanged, no new debt |
| Pure suites | **42** (from 40) |
| EN/FR/AR parity | **1985 keys each, identical order** (from 1860) |
| Web export | clean, **70 routes** (from 68) |

Backend lint is **not** a gate here and never has been: there is no
`eslint.config.*` in that repository, so `npm run lint` fails identically on a
clean checkout. Recorded rather than worked around.

## 2. What CP4–CP6 built

### CP4 — the workflow, and the detectors it needed first

**A1's detectors did not exist.** CP2 declared five `magnitude.*` codes and
nothing computed one, so no mutation could return `warnings_pending` and the
sale flow had no warning to acknowledge. `magnitude.sale_price` is now live on
`sale.create`, comparing against the configured price the sale itself priced
from and falling back to ninety days of that product's sales at that branch,
minimum five.

The threshold is ten because **a missing or extra zero is exactly a factor of
ten** — not a tuned statistic. The reported factor is a bucket (10, 100, 1000),
which is load-bearing: `acknowledgement.ts` binds parameters into the
fingerprint and excludes the reference, and that is only safe while the
parameters do not move when a median drifts by a unit.

The mobile workflow shows **twelve states and keeps them distinct**. The phone
never infers an approval: it opens the sheet because the server refused, and it
completes the sale by sending the sale again — the server consumes the approval
inside the sale's own transaction. Every refusal is read from `e.code`, never
from prose, because a regular expression over an English sentence works in
exactly one of three languages.

### CP5 — six rules, by name

`anomaly.low_stock` · `anomaly.dead_stock` · `anomaly.overdue_debt` ·
`anomaly.seller_margin_drop` · `anomaly.cash_shortfall` ·
`anomaly.below_cost_cluster`

**Not one computes a metric.** Every input is a figure the app already shows.
Margin is compared as a rate, never an amount — a quieter month is not a
collapse. Every rule states a minimum sample and says nothing below it. A rule
the caller may not see is **never computed**, not computed and filtered.

Migration **0066** stores dismissals only — seven days, company-wide, audited,
dropped after ninety by whoever reads next. The anomalies themselves are never
stored, because a stored anomaly is a second copy of a figure that is stale by
the time anybody reads it.

### CP6 — three defects no unit test could see

1. **The refusal arrived stripped.** `approval_required` attached the unit, the
   line, the set price and `belowCost`; the global exception filter dropped all
   of them, because its allowlist was `['problems','units']`. The phone got
   "something needs approval" and no way to know which phone. **This is the
   second time that allowlist has silently eaten a field a client depends on** —
   the filter's own comment describes the first. Every test passed because they
   all asserted that an exception was thrown, never what a client receives.
2. **Both reads of an approval answered 400.** The detail select asked for
   `product.name`; a product has a brand and a model and has never had a name.
   Prisma refused the query, the filter reported "Invalid query parameters", and
   the list's `scope` never arrived. Source-text tests cannot catch a query that
   does not run.
3. **The retired `branch_manager` role can still approve a discount.** §3.

Both code defects are fixed, and both now have regression tests that assert what
a **client receives** rather than what a service throws.

## 3. 🔴 One finding left open, and it needs a decision

**`role_permissions` still grants `discount.override` to `branch_manager`.**

A2 made approval Owner-only and removed the key from the code catalogue. The
database row stayed, and `AccessService` resolves authority from that table and
nothing else — so a live HTTP request from a Branch Manager **approved a
discount**, twice, in front of me.

The deploy gate reported *"61/61, catalogue complete"* throughout, because it
only ever checked that the KEYS exist. **A catalogue can be perfect while the
grants are wrong.** `verify-permission-catalogue` now compares each role's
actual grants against `ROLE_PERMISSIONS` and refuses on an extra grant, while
reporting a narrowed role without failing — an extra grant is authority nobody
decided to give; a missing one is usually a shop that meant it.

That command now **exits non-zero on this database**, naming exactly one row:

```
! Branch Manager (branch_manager) holds: discount.override
```

**Nothing was deleted.** Removing a grant is the owner's call, and the rulebook
forbids deleting demo records without authorisation. Current exposure is
**zero**: the only user holding the retired role was a verification fixture, and
it was removed. The repair is one statement, whenever the owner wants it:

```sql
DELETE rp FROM role_permissions rp
  JOIN roles r ON r.id = rp.role_id
  JOIN permissions p ON p.id = rp.permission_id
 WHERE r.name = 'Branch Manager' AND p.`key` = 'discount.override';
```

The gate will then pass. It also reports `Administrator` as *narrowed* — that
one is not a failure and needs no action.

## 4. The live run, and what it left behind

**91 of 92 checks passed**, plus a separate 6/6 run proving a refusal is
terminal and authorises nothing. Covered live: monetary boundaries in both
directions · magnitude warnings high and low, and silence just under the
threshold · a warned sale writing nothing · an acknowledgement accepted,
re-issued on a changed payload, refused for another person and for a forged
signature · the configured-price floor refusing a still-profitable sale · below
cost as its high-risk subset · request by an Employee, refusal to decide by
Employee, Manager and the retired role · a stale-version conflict · approve,
replay, and a reversed decision refused · exact price, exact unit, single
consumption · scope `mine` versus `company` · a manager refused a deep link ·
Owner self-approval through the same route · idempotent replay and its conflict ·
withdrawal · branch isolation · all six anomaly rules with their gating,
dismissal and its seven days · and twelve existing endpoints still answering.

### Backup, and the migration it preceded

`~/erp-backups/phonestore-20260910-191750.sql` — **687 997 bytes, 87 tables,
24 triggers, 0 raw `_binary` literals, `-- Dump completed` trailer present.**
Taken before migration `0066`, which is additive: one table, no column altered,
no data migrated. A code rollback leaves it in place and unused.

### Demo-data integrity, measured

| | before | after | |
|---|---|---|---|
| units · sales · payments · products · users | 11 · 7 · 7 · 14 · 13 | identical | ✅ |
| approvals · dismissals | 0 · 0 | 0 · 0 | ✅ |
| sale total · margin · unit cost · payments | 10 051 · 3 018.20 · 9 800 · 10 051 | identical | ✅ |
| SHA-256 over `units.id` and `sales.id` | — | identical | ✅ |
| `audit_logs` | 671 | **752** | deliberate |
| notifications | 46 | 45 | see below |

The audit trail **grew and was preserved** — 14 requests, 10 approvals, 4
withdrawals, 4 dismissals and the sales that consumed them. It is append-only
behind a trigger and could not have been deleted deliberately, which is the
point of it.

Notifications went 46 → 45 because the run's own litter was cleaned, including
one `sale.recorded` row left by my first, aborted attempt. No dangling
`/approvals/…` link remains.

**Fixtures were created under the marker `ZZ-CP6` and removed**: 4 users, 4
branch assignments, 1 product, 12 units, 5 sales with their items and payments,
5 approvals, 1 dismissal, 14 notifications. Verified gone. **No temporary
database was created this session**; `phonestore_shadow` from the previous one
still exists and is still needed by `prisma migrate diff`.

⚠️ **Do not run `prisma migrate diff` against this history and apply it.** It
produces 1172 lines dropping foreign keys on unrelated tables, because the
history carries hand-tuned SQL the datamodel does not describe. `0066` is
hand-written for that reason, and says so in its own header.

## 5. Ready for visible UI testing

The bundle now being served **is** the final code. Proven, not assumed:

- Mobile HEAD `20619e4` contains every redesign commit (`ca8525d`, `e647c22`,
  `7d7a7ce`, `ce5b8de`, `337719f`, `7e36929`, `c2422c6`, `ed7d614`) plus CP4
  `68f02dd` and CP5 `20619e4`.
- **No stale process existed.** Every `node.exe` was resolved by PID and command
  line before anything started: Adobe Creative Cloud, and two Claude tooling
  processes. The Expo server the previous handoff mentioned on `:8081` had
  already exited, and ports 8081, 19000, 19001, 3010 and 3013 were all free.
- Metro was started **`--clear`**, from `C:\wamp64\www\PhoneStoreERP\mobile`,
  and reports `Bundler cache is empty, rebuilding`.
- It loaded `.env.local`, so `EXPO_PUBLIC_API_ORIGIN=http://192.168.100.3:3010`
  is inlined — and **192.168.100.3 is this machine's current Wi-Fi address**,
  confirmed against the adapter rather than assumed.
- The API is up on **`0.0.0.0:3010`** and answers `/api/health` **200 at the LAN
  address the phone will use**, not only on loopback.
- **The served bundle was fetched and searched**, 17 117 577 bytes:
  `approval.needed.title` ×5 · `approvals.confirmTitle` ×4 ·
  `warning.magnitude.salePrice.high` ×3 · `attention.title` ×4 ·
  `warning.anomaly.belowCostCluster` ×3 · `status.approval.consumed` ×4 ·
  `discount-approvals` ×13 · `/anomalies` ×4 · `nav.approvals` ×4 ·
  `reissuedBecause` ×1 · `192.168.100.3:3010` ×1.

**Scan `exp://192.168.100.3:8081` with Expo Go**, on the same Wi-Fi.

### Where the changes are unmistakable

| Screen | What is new |
|---|---|
| **Home** | The redesigned grouping — adjoining rows, hairline separators, no rule under the last row |
| **Analytics** | **Needs your attention** at the top: sentences with their numbers, worst first, each dismissible for a week |
| **Money / export** | Export from what you are looking at; the share sheet and a readable spreadsheet |
| **Sell — price warning** | Type ten times the price: *"Does this look right?"* with what you typed and what similar items cost. Nothing sells until you answer |
| **Sell — discount request** | Sell below the set price: the sheet opens on that phone with the set price, your price, the discount and the percentage, and a reason field |
| **Approvals — Owner review** | From More → Price approvals, or straight from the notification. Item, branch, requester, reason, minutes left — and the cost only if you may see it |
| **Approvals — the states** | Waiting for the Owner → Approved with the minutes left → Used. Or Not approved, Expired, No longer valid — each says something different |
| **Notifications** | *A price needs your approval*, in your language, landing on **that** request |
| **Arabic (RTL)** | The whole approval flow mirrors; prices stay left-to-right; the sentences read naturally |
| **Dark mode** | Approvals and the attention panel, warning tones legible |

**No claim is made about any of this on a physical device.** Nothing has been
run on a handset; the list above is where to look, not what was verified.

## 6. Running services — left up on purpose

| Port | What | Started by |
|---|---|---|
| `3010` | the API, bound `0.0.0.0`, health 200 on the LAN | **this session**, for the owner's test |
| `8081` | Expo / Metro, cache cleared, serving mobile `20619e4` | **this session** |
| `3306` | `mysqld.exe` from the user's WAMP install | not this session's to stop |

The verification API on `3013` was time-boxed and **is stopped**; the port was
confirmed released.

## 7. The next exact action

**Work [`docs/24` §14](docs/24_DEVICE_QA_CHECKLIST.md) on the iPhone — 58
checks**, of which 36–58 are the new approval and anomaly rows. Both servers are
already running and serving the final code.

Then, in order of value:

1. **Decide the `branch_manager` grant** (§3). One statement, and the permission
   gate goes green.
2. **Wire A1's remaining four detectors** — intake cost, price change, expense
   amount, debt payment. The engine, the rules and the ten translations exist
   and are tested; each needs its mutation wired to `WarningGate` the way
   `sale.create` is, and its screen taught to answer `warnings_pending`.
3. Everything in §8, unchanged.

Do not merge and do not deploy.

## 8. Unresolved risks

Fifteen, with severity, evidence, owner and gate, in [`docs/41`](docs/41_RELEASE_READINESS.md) §6.

- 🔴 **R1 Nothing has run on a physical iPhone.** Four milestones ride on it.
- 🔴 **R2 Administrator MFA does not exist.** `/admin` is a password plus a proxy.
- 🔴 **R3 No off-machine database backup.** A disk failure loses everything.
- 🟠 **R4 17 backend / 18 mobile production dependency advisories.** Recorded,
  not bumped: dependency work is its own isolated checkpoint here.
- 🟠 **R5** one static `PLATFORM_ADMIN_KEY` grants cross-tenant provisioning ·
  **R6** no contact-delivery provider · **R7** `SEED_DEMO` is opt-out ·
  **R8** no restore drill since 2026-08-05 · **R9** no spreadsheet has opened an
  exported CSV · **R10** no error reporting or alerting.
- 🟡 **R11–R15** unvalidated env reads, lint debt, `Televisions` still `serial`,
  a bare `setInterval` outbox, Android strict-ROI unverified.
- 🟡 **New:** `CORS_ORIGINS` in the backend `.env` still names
  `192.168.100.100:8081`, one octet away from this machine. It affects the web
  preview only — Expo Go makes native requests and is unaffected — but it will
  waste somebody's afternoon eventually.

## 9. Decisions required from the owner

Ten, in [`docs/45`](docs/45_EXTERNAL_DECISIONS.md). **D4 hosting, D5 database
hosting and D6 backups are the critical path and block staging.** D1 domain
comes first in practice because everything embeds it — including the mobile
bundle, where those URLs are compiled in, not read at runtime.

Plus the one in §3, which is new and takes ten seconds.

## 10. Gates

| # | Gate | State |
|---|---|---|
| 1 | Automated verification | 🟠 **backend and mobile green; the permission-grant gate refuses on one row** (§3) |
| 2 | Browser verification | ✅ passed (earlier session) |
| 3 | **Physical-device acceptance** | 🔴 **not started — 58 checks, all red** |
| 4 | Staging deployment | 🔴 not started |
| 5 | Production launch | 🔴 not started |

**Nothing device-dependent is marked verified** — not native sharing, spreadsheet
opening, scanner behaviour, RTL layout, dark mode, haptics, camera behaviour or
Reduce Motion.

**Staging entry:** device acceptance passed · gate 1 green on the deployed
commit · a host that is not a laptop · off-machine backup possible. Full list in
[`docs/44`](docs/44_STAGING_AND_LAUNCH_CHECKLISTS.md).

**Production entry:** staging passed and stable · administrator MFA · a real
delivery provider · domain, DNS, TLS · scheduled verified off-machine backups ·
error reporting and alerting · dependency advisories triaged · a payment
provider **or** a written decision to launch on administrative grants.

⚠️ **Check freshness before trusting any server you find running.** Several
failures on this project — a 404 on an endpoint that existed, a Metro predating
a fix, a `PluginError` from a bundler started before `node_modules` was wiped,
and a static file server sitting on Metro's port — were all one stale process.
Resolve the PID and compare its start time against the last build before
concluding anything.
