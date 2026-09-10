# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Active account / Owner: **CLAUDE-A**
- `started_at_utc:` **2026-09-10T04:20Z**
- Active phase: **release-readiness audit and staging preparation.** No product feature, no UI work, no merge, no deploy.
- Baseline verified at takeover, no discrepancies: backend `51c93ad` (`b0f3fc5` an ancestor), mobile `ed7d614`, docs `37f381a`, `reports-export` on both code repositories, `pre-reports` tags at `67352af` and `c2422c6`, all four trees clean and level.
- Previous session: **CLAUDE-A**, `2026-09-10T02:40Z` → `2026-09-10T04:05Z`, handoff complete.
- Phase closed: **Phase 5 report export (CSV).** Six reports leave the app as
  spreadsheets. Full contract in [`docs/40`](docs/40_REPORT_EXPORT.md).
- 🔴 **Nothing has run on a handset.** [`docs/24` §14](docs/24_DEVICE_QA_CHECKLIST.md)
  is the single script — now **35 checks**, every row red.

### HEAD now

| Repository | Branch | HEAD | Was |
|---|---|---|---|
| `erp-backend` | **`reports-export`** | **`51c93ad`** | `67352af` (`master`) |
| `erp-mobile` | **`reports-export`** | **`ed7d614`** | `c2422c6` (`sdk-57-upgrade`) |
| `erp-mobile` `master` | — | `f47a155`, preserved untouched | — |
| `retail-erp-control-web` | `master` | `c764d63` (untouched) | — |
| `erp-docs` | `master` | *this commit* | `fce7f31` |

All clean, level with their remotes, and pushed.

**Branches.** `reports-export` was cut from the verified baseline on both code
repositories, and **`pre-reports` tags the point before it** — `67352af` on the
backend, `c2422c6` on mobile. The redesign checkpoints (`pre-scan-contract`,
`pre-redesign-part2`) are untouched. Merging is outside this task, and the
device run is still owed on the mobile work underneath.

### Commits this session

| Repository | Commit | |
|---|---|---|
| `erp-backend` | `b0f3fc5` | the six reports, as spreadsheets |
| `erp-backend` | `51c93ad` | CORS: let a browser read the report filename |
| `erp-mobile` | `ed7d614` | export what you are looking at |

## What changed

### `GET /api/v1/reports/:kind.csv?days=&locale=`

Gated on `report.view`; `debtors-creditors` also needs `loan.view`. Six kinds:

| Kind | Source | Scope |
|---|---|---|
| `profit-by-product` | `AnalyticsService.productPerformance` | period |
| `profit-by-employee` | `DashboardService.employeePerformance` | period |
| `profit-by-branch` | `DashboardService.branchComparison` | period (always company-wide) |
| `movers` | the same rows, ranked by quantity | period |
| `dead-stock` | `DashboardService.deadStock` | **as-of** |
| `debtors-creditors` | `LoansService` + `SuppliersService` | **as-of** |

**No metric is defined here.** Every figure comes from the service that already
owns it. `days` is rejected outright on an as-of report rather than ignored.

**Authorization happens before serialization.** A CSV is a string with no keys
left to strip, and `CostGatingInterceptor` never sees a file written straight to
the socket — so columns are chosen from the caller's real permissions *before
any data is read*. Forbidden columns are removed, not blanked. A report left
with nothing but figures the caller may not see is **refused**.

**Complete, or refused.** The dashboard's ten dead-stock rows and the loan
screen's two hundred are card-sized; the export asks for everything and pages
suppliers to the end. Past 100 000 rows it refuses rather than truncating.

**The file is a plain rectangle** — header row, then data — and the provenance
lives in the filename: `dead-stock_as-of_2026-09-10_en.csv` cannot be mistaken
for `profit-by-product_2026-08-12_to_2026-09-10_en.csv`. UTF-8 with a BOM, RFC
4180, comma, EN/FR/AR headers from a server-side dictionary. Money is a bare
number; the currency is named once in the header. Typed text is armoured against
formula injection; **money never is**, because prefixing `-4000` would turn it
into text.

**Audited as `report_export_generated`** — never as a download, because the
server only saw itself produce bytes. The row carries the allowed column ids and
the row count, never a cell of the file. A refused export writes nothing.

**No schema change. No role broadened.** The catalogue is still 61/61.

### The app

An **Export** action on Analytics and Money, and one sheet listing the reports
this user may ask for. No new screen and no new route. The download goes through
the app's own API layer, so it carries the same token, branch header, timeout
and refresh as every other call. The branch is captured before the request and
compared after it — switch shops mid-generation and the result is discarded
unsaved. Files live in the app-private cache, are swept before each export, and
are all dropped on sign-out. Web gets a browser download built from bytes
already fetched; native gets the share sheet. No token in any URL or filename.

## Verification

| Gate | Result |
|---|---|
| Backend suite | **115 suites / 2046 tests**, 0 failing (from 113 / 1973) |
| Backend `tsc` / Prisma validate | clean |
| Migrations | **63, up to date — no schema change** |
| Permission catalogue | **61/61, unchanged** |
| **Live HTTP vs real MySQL** | **107/107** — all six kinds, bytes inspected |
| **Real browser download** | driven through the app's own UI in the web build |
| Mobile `tsc --noEmit` | clean |
| Expo lint | **0 errors**, 33 warnings — unchanged |
| Pure suites | **40 suites**, 0 failing (from 39) |
| EN/FR/AR parity | **1860 keys each, identical order** (from 1840) |
| Web export | clean, **68 routes** — the export is a sheet, not a route |
| Camera patch | **6 anchors**, `expo-camera@57.0.4` |
| **Expo Doctor** | ✅ **21/21** |

The live run compares the file against `/analytics/products` over a **matched
365-day window** and agrees on revenue, profit and quantity for all nine real
products. The default 30 days returns nothing from either side, and two empty
answers agreeing would have proved nothing.

### One defect a browser found and no test could

`Content-Disposition` is not CORS-safelisted, so a browser hid it: the endpoint
answered 200 with the right bytes and the web client read `null` for the
filename, falling back to `report.csv`. Every export would have saved under the
same name, losing the provenance the filename had just become the only place to
carry. Fixed with `exposedHeaders` (`51c93ad`) and pinned by a regression test.
Native fetch was never affected — it is a browser rule.

### One thing that cannot be proved over HTTP, and is not claimed

`owner` and `store_manager` both hold `report.view` **and** `cost.view`, and a
delegated grant can only ADD permissions — so **no assignable store role
produces the "reports without cost" shape.** It exists in the catalogue as
`administrator` and is covered by unit tests, where the decision is actually
made. What the wire does prove is the harder boundary: a real `store_employee`
is refused all six kinds, and an unauthenticated caller gets 401 with no bytes.

## Still open

- 🔴 **The iPhone acceptance run**, now **35 checks**, all red. #1–30 the
  redesign, #31–32 the scan duplicate warning, **#33–35 native CSV sharing**.
  Highest risk unchanged: the RTL separator inset (#26), the scanner through the
  reveal (#9–11), first/last row treatment (#24), dark mode (#25).
- 🔴 **No spreadsheet has opened one of these files.** The BOM, the delimiter
  and the formula armour are asserted against this project's own parser. Whether
  Excel, LibreOffice and Google Sheets each render Arabic correctly is a
  separate check and nobody has done it.
- 🔴 **Android strict-ROI placement on a handset** — open before the SDK
  upgrade, still open.
- 🟠 **`Televisions` is still `serial`, with five units of stock.** A person must
  decide about those five units. Nothing is broken meanwhile.
- 🟡 **PDF reports** were deliberately deferred. CSV first: an accountant wants
  columns, and `expo-print` is already in the project if a PDF is wanted later.
- 🟡 **A staged quantity cannot be edited after the fact** in the receive flow.
- 🟡 **React Compiler lint debt** — 32 warnings, deliberately deferred.
- 🟡 **Merging** `reports-export` and `sdk-57-upgrade` — outside this task, and
  the device run is owed first.
- 🟢 Two fixture accounts (`reportmgr`, `rptemp`) are deactivated and
  soft-deleted. **109 `report_export` audit rows are preserved deliberately** —
  they are true statements about exports that happened.

## The next exact action

**Work `docs/24` §14 on the iPhone — 35 checks.** Sign in as
`devtest@example.com`. Nothing on that branch has been near a handset.

Separately, and not device work: **open one exported Arabic CSV in a real
spreadsheet** and record the result. It is the one claim in `docs/40` that a
parser cannot make.

## Running services

- **API on `:3010`** — a build of `51c93ad`, LAN-reachable at `192.168.100.3`.
- **MySQL on `:3306`**.
- ⚠️ **No Metro.** The native bundler was stopped so the web build could be
  served on `8081` for the browser verification, and that static server was left
  running there. **Stop it before starting Expo**, or Metro will take another
  port and the QR will point at a static file server.

⚠️ **Check freshness before trusting any server you find running.** Several
failures on this project — a 404 on an endpoint that existed, a Metro predating
a fix, a `PluginError` from a bundler started before `node_modules` was wiped —
were all one stale process. Resolve the PID and compare its start time against
the last build before concluding anything.
