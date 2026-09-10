# 40 — Report export: the contract, the columns and the gating

Six reports leave the app as CSV. Nothing here defines a metric: every figure
comes from the service that already owns it, because a second query for "profit
by product" is a second definition of profit, and the first time the two
disagreed the shop would have no way to tell which was right.

---

## The endpoint

```
GET /api/v1/reports/:kind.csv?days=<1-366>&locale=<en|fr|ar>
```

Authenticated, gated on **`report.view`**, and subject to the same company,
branch and entitlement rules as every other read. `days` is accepted only by a
period report; sending it to a current-balances report is a **400**, not a
silent ignore.

Responses carry `Content-Type: text/csv; charset=utf-8`, a
`Content-Disposition` attachment filename, `Cache-Control: private, no-store`
and `X-Report-Rows`. A refusal is the project's ordinary JSON error — never an
error message dressed as a CSV.

---

## The six reports

| Kind | Source | Scope | Beyond `report.view` | Columns |
|---|---|---|---|---|
| `profit-by-product` | `AnalyticsService.productPerformance` | period | — | product, tracking, qtySold, revenue, **cogs**, **grossProfit** |
| `profit-by-employee` | `DashboardService.employeePerformance` | period | — | employee, salesCount, revenue, **margin** |
| `profit-by-branch` | `DashboardService.branchComparison` | period | — | branch, revenue, **grossProfit**, **netProfit** |
| `movers` | `AnalyticsService.productPerformance`, ranked by quantity | period | — | product, tracking, qtySold, sold30d, lastSoldAt, revenue, **grossProfit** |
| `dead-stock` | `DashboardService.deadStock` | **as-of** | — | product, tracking, inStock, lastSoldAt, **inventoryValue** |
| `debtors-creditors` | `LoansService.list` + `SuppliersService.list` | **as-of** | `loan.view` | direction, source, counterparty, status, since, outstanding |

**Bold** columns are financial and disappear entirely without `cost.view`.

### Period versus as-of

Four reports measure a **window** of trading. Two describe **right now** — what
is on the shelf, what is owed. Giving the second kind a date range would invite
somebody to read a current balance as money that moved last week, which is the
mistake `SummaryService.balances` already refuses to make.

Nothing inside the file distinguishes them, so **the filename does**:

```
profit-by-product_2026-08-12_to_2026-09-10_en.csv
dead-stock_as-of_2026-09-10_en.csv
```

### Completeness

Exports are complete, not the screen saved to a file. The dashboard's ten
dead-stock rows and the loan screen's two hundred are card-sized; the export
asks for everything, and suppliers are paged to the end. Past
**`MAX_EXPORT_ROWS` (100 000)** the request is **refused** — a spreadsheet that
silently stops is worse than none, because nothing in the file says so.

`movers` and `profit-by-product` are the same rows in different orders. A shop
asks "what is shifting?" and "what is earning?" as different questions.

### Debtors and creditors

One file, with the direction on every row, because the two are read together
and a reader holding two files has to remember which is which. `direction` is
`owed_to_us` or `owed_by_us` from this company's point of view;
`source` is `loan` or `supplier`, so a total can be taken per source without
adding together two accounting ideas that are not the same idea — the reason
`SummaryService.balances` gives for keeping them apart.

A settled debt is omitted rather than written as a zero row. A supplier whose
balance the caller may not see is **not written at all**: "we owe nothing" and
"you may not know what we owe" cannot share a cell.

---

## Authorization happens before serialization

**A CSV is a string, and a string has no keys left to strip.**

`CostGatingInterceptor` protects JSON by mapping over the response object after
the controller returns. A file written straight to the response never reaches
it — Nest's own documentation notes that a directly-piped response skips
post-controller interceptors. So the gating cannot live downstream.

The order in `ReportsService.export` is the whole security argument:

1. **Authorize** — the report's extra permissions, on every request.
2. **Bound** the period, in whichever way this report is bounded at all.
3. **Choose the columns** this caller may receive — before any data is read.
4. **Fetch** through the owning services.
5. **Project, then serialize.**

By the time a string exists there is nothing in it to strip, which is why
nothing downstream is asked to strip anything.

### Absent, not blank

A forbidden column is **removed**, not emptied. A blank cell under a
`Gross profit` header tells the reader a number exists and is being withheld,
and invites them to go and find it. The column not being there is the honest
shape of what they may know.

### One list, two consumers

A column marked `financial` must have an id in **`FINANCIAL_FIELDS`** — the same
set the interceptor uses. `financialColumnDrift()` asserts it, so a new
financial field cannot be added to the strip list and forgotten here.

### A report of nothing but forbidden figures is refused

Stripped to a list of product names, a profit report is not a smaller report —
it is a different, useless one, and returning it as a success is a misleading
substitute. The caller gets a **403** naming the permission instead.

### Roles

No role's permissions changed. As the catalogue stands, `owner` and
`store_manager` both hold `report.view` **and** `cost.view`, and a delegated
grant can only ADD permissions — so **no assignable store role produces the
"reports without cost" shape.** That combination exists in the catalogue
(`administrator`) and is covered by unit tests; it is not reachable over HTTP
today, and no HTTP proof of it is claimed.

---

## The CSV itself

- **UTF-8 with a BOM.** Excel reads UTF-8 as the system codepage without it,
  which turns Arabic into mojibake. `parseCsv` strips it back off.
- **Comma, always.** The reader *detects* `,`, `;` or tab because it is handed
  other people's files; the writer chooses. The BOM is what makes a
  comma-delimited file open correctly in a semicolon locale, and
  `detectDelimiter` resolves ties to the comma, so the round trip holds.
- **RFC 4180 quoting**, CRLF line endings, trailing newline.
- **A plain rectangle**: header row, then data. A provenance block above the
  table was tried and removed — `parseCsv` skips blank lines *and* all-empty
  rows, so the separator vanished and the metadata arrived as data, and an
  empty report stopped being a header-only file.
- **Money** is `-1234.50` — two decimals, dot separator, no grouping, no
  symbol. The currency is named once, in the header: `Revenue (MRU)`.
- **Missing is not zero.** An uncomputed metric is an empty cell. A zero claims
  something was measured and found to be nothing.
- **Zero and negative survive**, and `-0` is normalised to `0`.
- **Headers and status words in EN/FR/AR**, from a server-side dictionary — a
  header the client supplies is a header a client can relabel.

### Formula injection

A cell opening `=`, `+`, `-`, `@`, tab or CR can be executed when a spreadsheet
opens the file. **Quoting does not prevent this**: quoting is about parsing, and
evaluation happens afterwards.

**What is done.** Free text a user typed — product labels, names, counterparty
names — is prefixed with an apostrophe when it starts with a trigger. Excel and
LibreOffice treat that as literal text.

**What is deliberately not done.** Money is **never** armoured. Prefixing a
negative balance would turn `-4000` into text and break the arithmetic the
export exists for. The distinction is applied per column type, not per cell.

**Limitations.** A legitimate note beginning `--` gains an apostrophe, which is
in the file though not shown in the cell. And a spreadsheet told to import the
column as a formula can still do so — the protection is at the file level and
cannot reach past a user who overrides it.

**A report file is not an import file.** It shares CSV syntax with the intake
importer and nothing else; none of these are shaped to be received as stock or
purchases.

---

## Audit

Every generated file writes one `report_export` row through the existing audit
service: actor, company and branch scope, kind, normalized period or as-of
date, locale, the **column ids** that were allowed, row count, timestamp and
outcome.

**Never a cell of the file.** An audit log holding the shop's margins would be a
second copy of exactly what the column gating exists to control.

The event is named **`report_export_generated`**. The server saw itself produce
bytes; whether they reached a person, a share sheet, an email or a bin is not
something this process observed, and an audit trail that claims otherwise is
worse than one that says less. A refused export writes nothing.

Exports change no inventory, sale, balance, refund or reconciliation state.

---

## The app

An **Export** action on Analytics and Money opens one sheet listing the reports
this user may ask for, with the branch and period stated before anything is
requested. There is no reports screen: exporting is something you do while
looking at figures.

- The download goes through the app's own API layer — same token, same
  `X-Branch-Id`, same timeout, same refresh-once-on-401. A second client would
  drift, and the symptom would be a report from the wrong branch.
- The response is **validated** before anything is written: a 200 carrying a
  captive-portal page is a real thing on shop wifi.
- The **branch is captured before the request and compared after it.** Switch
  shops mid-generation and the result is discarded unsaved.
- Files live in the **app-private cache**, scoped by branch, swept before each
  export, and **all dropped on sign-out**.
- The shared file is **not** deleted immediately: iOS resolves `shareAsync` when
  the sheet closes, which can be before Mail has finished reading it.
- **Web** gets a browser download built from the bytes already fetched — a plain
  link would be unauthenticated, and a token in the URL would land in history,
  logs and the referer header. Expo Sharing has no local file URI on web.
- `expo-print` is not involved. It renders HTML to PDF; a CSV is already text.

The client-side permission filter is **UX, not security**. The server checks
again on every request.

---

## What a browser found that no test did

`Content-Disposition` is not on the CORS-safelisted response header list, so a
browser hid it. The endpoint answered 200 with the right bytes and the web
client read `null` for the filename, falling back to `report.csv` — every
export would have saved under the same name, losing the report, period and
branch that the filename is the only place to carry.

Fixed with `exposedHeaders: ['Content-Disposition', 'X-Report-Rows']`. Native
fetch was never affected, because this is a browser rule.

---

## Not verified

**Native sharing has not run on a handset.** Writing the file, the iOS share
sheet, and what Mail or WhatsApp do with the attachment are device facts. They
are checks #33–35 in [`docs/24` §14](24_DEVICE_QA_CHECKLIST.md).

**Spreadsheet compatibility has not been checked in a spreadsheet.** The BOM,
the delimiter and the formula armour are verified against this project's own
parser and asserted in tests. Whether Excel, LibreOffice and Google Sheets each
open an Arabic file correctly is a separate check, and it has not been done.
