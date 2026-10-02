# 66 — The daily and monthly report PDFs, and the visual review of 2026-10-01

> The user's brief of 2026-10-01: (A) the existing daily and monthly reports prepared as **PDFs inside the app** —
> open the report, choose the day or month as the reporting design already allows, review the figures, *Generate PDF*,
> preview or open it, and optionally share or save it through the phone's own sheet; server figures only, the 06:00
> business-day rules, EN/FR/AR with right-to-left Arabic, user text escaped, a stable contract a later server-side
> WhatsApp phase can reuse. **Automatic WhatsApp delivery, recipients, templates, schedules, jobs and WhatsApp report
> APIs are postponed and were not built** (D111). (B) a complete visual review of every reachable page, tab and state
> of the web app, with screenshots, contact sheets, an index and the sample PDFs.

Companion decisions: [`docs/21`](21_PRODUCT_DECISIONS.md) D111–D115. Device checks: [`docs/24`](24_DEVICE_QA_CHECKLIST.md)
§52–§53. The CSV exports stay as they were ([`docs/40`](40_REPORT_EXPORT.md)); the dated accounting rules are
[`docs/53`](53_REPORTING_CONSISTENCY.md)'s.

---

## 1. One contract, two documents

```
GET /api/v1/reports/daily?date=YYYY-MM-DD     report.view + closing.count   (no date: today's business date)
GET /api/v1/reports/monthly?month=YYYY-MM     report.view                    (no month: the current one)
```

Both answer `Cache-Control: private, no-store`, are branch- and company-scoped like every read, and write one audit row
(`report_export`, `report_document_served`, the kind, the date or month, its source and the sections served). The body
is a **report document**, version `REPORT_DOCUMENT_VERSION = 1` (`erp-backend/src/reports/report-documents.ts`). A
client that receives another version or another kind refuses it whole rather than print it half understood.

**Not a second reporting system.** Every figure is copied from a calculation the server already owns:

| Document | Source of every figure |
|---|---|
| Daily | The Daily closing's own report (`closing-report.ts`), gated for the caller — or, for a closed day, **the snapshot the day was closed on**, with `changed_since_close` when something was recorded after. Refunds from the returns workflow's summary for that date; amounts still owed from the open sale balances at generation. |
| Monthly | The period summary's profit and expenses (`summary.service.ts`, from the daily rollups, net of reversals); the dated period figures (`period-figures.ts`) for the counts and the optional day-by-day sales; the refund summary over the month; open sale balances, loans and consignments receivable now. |

The only arithmetic in the contract is the monthly split of the expenses the rollup already keeps net of reversals:
**variable = total − fixed**, **other fixed = fixed − salaries**, and **result before fixed costs = gross profit −
variable**. The document checks that the parts add back up to the summary's own net result and that the rollup and the
dated figures agree on sales, invoices, expenses and confirmed refunds; any disagreement prints `figures_disagree`
(an error, with how many figures disagree) and is never smoothed over. A month still running carries
`month_in_progress` (to its last day so far).

**What a document never carries:** an id of any kind (channel keys and account ids are dropped), a note, a person's
contact details, or a cost, margin or profit figure for somebody without `cost.view` — the result is `{status:
'hidden'}` and the global cost gating strips the same keys again on the way out. The identity is names only (company,
branch, the company's time zone).

### 1.1 Definitions

- **Business date**: from 06:00 to 06:00 the next day in the store's zone (`docs/56`). The daily document states its
  window; a figure belongs to the business date it was recorded on, never to the calendar date of the PDF.
- **Daily result**: the operating result **before fixed costs** (D111's companion, `docs/21` §10: fixed recurring
  costs are monthly accounting). Net sales − cost of units sold = gross profit; − variable expenses = result before
  fixed costs; − fixed expenses falling due that day = result after expenses. A day whose sold lines have no recorded
  cost says *cannot calculate yet* and prints no profit.
- **Monthly net result**: the summary's net operating profit = result before fixed costs − rent and other fixed costs −
  salaries. Salaries are shown apart.
- **Money per channel** (daily): the movement recorded through Cash and each account that day — **recorded movement,
  never a provider balance** (`basis: recorded_movement_not_balance`), with the debts of earlier days collected that day
  shown apart. The cash check (expected, counted, difference, verified or not) is the closing's own.
- **Refunds**: confirmed (the money left, on its confirmation date), reported and awaiting confirmation (a claim, not
  an outflow), and the outstanding liability (approved minus confirmed, derived from immutable rows, at generation).
- **Receivables**: sale balances still owed (count and amount); monthly adds loans receivable and payable and
  consignments receivable.
- **External commissions**: not recorded anywhere in the system today — the monthly document says so (`commissions:
  {recorded: false}`) rather than printing a zero.

### 1.2 Who sees what

| Caller | Daily | Monthly |
|---|---|---|
| Owner | everything | everything |
| Manager (store_manager) | everything (holds `report.view`, `closing.count`, `cost.view`, `return.view`) | everything |
| A role with `report.view` but not `cost.view` | sales, expenses, money, checks; **result hidden — said, never zero** | sales and expenses; result hidden |
| A role without `return.view` | refunds **withheld** (said) | refunds withheld |
| Employee (store_employee) | **403** (no `report.view`) — the *Generate PDF* row is not offered | **403** |
| No session / another company's branch | 401 / 403 | 401 / 403 |

No store-facing role today holds `report.view` without `cost.view`, so the hidden-result path was proven with the
technical *administrator* role on the disposable database and by unit tests; it stays the contract for any future role.

## 2. The PDF in the app

- **Where.** The Daily closing (for the business date shown, offered to whoever holds `report.view` and may count) and
  Results (for the month shown on *This month*). The row reads *Generate PDF* with the date or month under it.
- **Flow.** One GET of the document → the app's pure builder (`erp-mobile/lib/report-pdf-html.ts`) lays it out →
  `expo-print` writes an A4 PDF into the app's cache (`reports/pdf/<branch>/`, swept each time) under its name → a
  *PDF ready* card: the file name, **Open** (native: the system print preview; web: a new tab), **Share or save**
  (native only: the system share sheet — saving to Files, mail, or WhatsApp **only as the person's own choice in the
  OS sheet**), and the warning that the file leaves the app once shared. A second tap while a PDF is being made starts
  nothing; a branch switched during the read or the write discards the result.
- **Layout.** White A4, 14 × 16 mm margins, one restrained violet accent (`#5146D9`), tabular figures aligned on the
  end edge, a true minus sign and a colour *and* a word for every state. A heading never ends a page alone, a table
  row never splits, a section stays whole when it fits, and the footer never takes a page of its own. Logical CSS
  properties throughout, so Arabic mirrors without a second stylesheet; figures and dates are isolated left-to-right.
- **Escaping.** Every string that came from a person (store, branch, category, channel labels) is HTML-escaped before
  it reaches the page; the builder is pure and tested with hostile names.
- **File name.** `RetailERP_<Branch>_Daily_<YYYY-MM-DD>_<LANG>.pdf`, `RetailERP_<Branch>_Monthly_<YYYY-MM>_<LANG>.pdf` —
  the branch (or company) name reduced to ASCII words in PascalCase, at most 40 characters, `Store` when nothing is
  left.
- **Nothing else moves.** Generating reads once; sharing hands the file to the OS; a dismissed or failed share is a
  cancellation and the server is untouched. No payment, messaging, subscription or notification call is made
  (pinned by `lib/report-pdf-flow.test.ts`).

## 3. Tests and evidence

| Where | What |
|---|---|
| Backend `src/reports/report-documents.spec.ts`, `report-documents.service.spec.ts` | **39 tests**: built from the real `assembleReport` / `gateReport` / profit functions — empty, ordinary and large-figure days and months, a negative result, refunds confirmed/reported/outstanding, a closed day from its snapshot and changed after, an open day, a day that cannot be calculated, the hidden result without `cost.view`, refunds withheld without `return.view`, no ids in the body, the month range rules, the invariants and `figures_disagree` |
| Mobile `lib/report-pdf-html.test.ts` | **34 tests**: every section in EN/FR/AR, Arabic `dir="rtl"`, hostile names escaped, MRU formatting with a true minus, the hidden result and withheld refunds said in words, the file names, deterministic output |
| Mobile `lib/report-pdf-flow.test.ts` | **11 tests**: one GET only, nothing sent/paid/scheduled/addressed, a stale branch discarded, a newer contract refused, a second tap ignored, a refusal and a printer failure surfaced, a dismissed or failed share = cancelled with the server untouched |
| Real HTTP on a disposable database (`prisma_qa_pdf`, ten QA boutiques plus a September history) | **43 of 43**: today (79 750 sold, gross profit 9 980, result 9 580, a 30 500 refund reported not confirmed), 20 Sep closed (cash −300, a 24 500 refund confirmed, 5 000 of an older debt collected), 14 Sep needing review with a 300 cancellation, 10 Sep inactive; September (10 invoices, 1 cancellation, 2 returns → 9 sales, net 169 000, gross profit 22 000, variable 2 000, rent 25 000, salaries 35 000, **net result −40 000**, refunds 24 500 confirmed and 30 500 outstanding, receivables 22 500); the Manager, the hidden-result role (no cost key in the body), the legacy role (daily 403, monthly refunds withheld), the Employee (403/403), another company (403), no session (401); 21 business tables checksummed before and after every read — none changed — and exactly one audit row per document served, naming the document and its sections, never a figure. **Re-run on the final backend `1a4bd6f` (2 Oct): 43 of 43**, the API's clock fixed at 1 Oct 22:00 UTC because the business day had turned |
| Sample PDFs (the review package's `pdf-samples/`) | 18 files rendered by Chromium from the server's saved documents through the app's builder, every page rasterised and inspected: daily 1 Oct EN/FR/AR (the French one runs to a third page holding its warnings, kept whole), 20 Sep EN/FR/AR, 14 Sep, 10 Sep; monthly September EN/FR/AR, October in progress; the hidden-result role's daily EN/AR and monthly; the role without refunds; a synthetic large-figure day EN/AR |

## 4. Not built, on purpose (D111)

No WhatsApp button, destination, recipient list, template, schedule, background job, Cloud API request or report API
for WhatsApp. The existing *WhatsApp summaries* settings (language, amounts, daily, monthly) keep saying *Saved now,
sent once WhatsApp is connected*; nothing sends them. A later pre-production phase may render or summarise the same
version-1 document on the server; the phone holds nothing that phase would need.

## 5. Open for the owner

- **A past month's PDF** (D115): the server serves any month (`?month=`); the app offers the month on Results' *This
  month* only, marked in progress. Whether to offer the previous complete month, and where, is a design choice.
- **Commissions**: no record exists; the monthly PDF says so.

## 6. The visual review: what was looked at

Every reachable page of the app, opened in a browser from the **committed web export of mobile `e484b58`**
(`expo export --platform web --clear`, served statically the way a host would serve it), signed in against the API of
backend `1a4bd6f` on the disposable `prisma_qa_pdf` (ten QA boutiques, a September history, synthetic IMEIs,
`@test.com` logins, no phone numbers — no live data, no real customer; dropped at the end). Chromium through Playwright at 393 × 852 pt and 2× (iPhone 15
class); full-page images, very long pages in top / middle / bottom segments. The package delivered with this phase
(`visual-review-e484b58/`, in six zip parts that unzip into that one folder; its contact sheets also on a private page
for the owner) holds every image, `INDEX.md` (totals, a caption and links for every page state,
findings by severity), the contact sheets, the permissions and 320 pt matrices, the machine-readable results and the
sample PDFs. It is **not committed** anywhere: screenshots of a fixture belong to no repository.

| | |
|---|---|
| Routes in the app's registry | **78**; three left out on purpose: `/stores` and `/` (`app/index.tsx`) are invisible redirects, `/dev/gallery` is development-only and never linked |
| Page states | **90** — 82 signed-in states (each dynamic route opened on a real fixture record, once per state worth seeing: a price approval pending and expired, a consignment proposed and handed over, a return at each stage, an import in review, …) + 8 signed-out and platform pages |
| Owner, every page with every tab, every closed section opened, *PDF ready* and the PDF itself | EN **121** · FR **121** · AR **121** images |
| Manager and Employee | every state visited in all three languages; an image only where the page differs from the Owner's: Manager EN 11 refused / 44 same / **38** images · FR 11 refused / 44 same / **38** images · AR 11 refused / 44 same / **38** images; Employee EN 20 refused / 23 same / **59** images · FR 20 refused / 23 same / **59** images · AR 20 refused / 23 same / **59** images |
| States outside the route run | EN **51** · FR **51** · AR **51** images: signed out, sign-in errors, branch choice, every sheet, the account and its deletion, empty lists, a suspended / expired / grace-period / pending shop (with More, where the subscription notice lives), and the platform administration signed in — the overview and its eight state filters, a business in each state, *Create a business*, the audit trail |
| 320 pt × 1.3× text (iPhone SE, every text element 1.3× after the page settled) | Owner EN **82/82** · FR **82/82** · AR **82/82**; Employee EN **82/82** · FR **82/82** · AR **82/82**; the states outside the route run EN **51/51** · FR **51/51** · AR **51/51** pass — machine-readable evidence in `results/*-320L.json` |
| Permissions matrix | **246 rows** (82 states × Owner / Manager / Employee): expected from the server's role definitions and gates, observed in the app — **246 PASS, 0 FAIL**; no figure is drawn behind a refusal |

**Checked on every page**, automatically and then by eye: horizontal overflow, text clipped by the screen edge, text
cut by an ellipsis, text squeezed into a narrow column (several words on four lines or more in under 45 % of the
screen — added at the end, it found the sale header), overlapping text, raw translation keys, `undefined` / `NaN` /
`null` / `[object Object]`, JavaScript errors, error boundaries, a missing back arrow, and every API answer of 400 or
more. The only API errors are expected
ones: a wrong password (401, the sign-in error state), the branch list of a suspended or pending shop (403, behind the
refusal screens), an expired shop's background device registration (403 — every write is refused), and a link to
somebody else's expense (404 — another person's expense is not disclosed). At 320 pt with 1.3× text, header titles,
one-line list titles and plain button labels may end in an ellipsis — each is listed in `layout-matrix-320.md`;
amounts and statuses never do.

**Corrected before the final capture** (the capture's own faults, not the app's): the platform administration had been
photographed *signed out* in every earlier run — its session lives in memory by design and the harness reloaded the
page between screens; Arabic tab images overwrote one another (labels with no ASCII letters gave every tab one file
name); and the fixture's platform grants (running to 2027) hid the *expired* and *grace* states, so the two shops that
were meant to show them opened as ordinary shops. The final run signs in to the platform once and navigates inside it,
numbers every tab image, and ends those two grants on the disposable fixture — the server then reports *expired* and
*grace (49 h left)*.

**The code audits** on `e484b58`: no hard-coded user-facing text and no colour literal in the 188 screen and component
files; the EN / FR / AR catalogues hold the same **3 410** keys in the same order, none empty, every placeholder the
same in all three (`lib/visual-review.test.ts`).

**Not captured, on purpose:** the scanner's camera (native only — the web's *No camera here* sheet is captured) and
the native print preview and share sheet of the report PDF (the web opens the PDF in a tab, which is captured; on a
phone: `docs/24` §52).

## 7. Fixed by the review — each re-verified in the final screenshots

Every fix answers a rule already decided — the rulebook's core principles, `docs/61`'s fitting rules, the server's
own permissions — and none changes what the server allows.

| Severity | Finding | Fix |
|---|---|---|
| High | **Business settings → Returns → Custom** with no hours typed read as 0 hours: the control jumped to *No returns*, the field never opened, and *Save changes* would have stored a no-returns policy nobody chose | mobile `c7c6265` |
| High | A screen opened directly (reload, link, notification) sent its first branch-scoped reads **without the branch**: 403 *Missing permission* / 400 *X-Branch-Id header is required* on ~30 endpoints before it recovered | mobile `3055799` |
| Medium | **Return detail / Request a return**: the pinned buttons covered the end of the history and the custody warning for good — unreachable by scrolling | mobile `c7c6265` |
| Medium | **The difference**: the four decisions cut in every language (*A record was …*) | mobile `c7c6265` |
| Medium | **A debt this shop proposed** offered *Agree* and *Propose another amount* (the server refuses: your own offer); a disputed debt offered a second dispute (refused) | backend `1a4bd6f` (`ownOffer`), mobile `c7c6265` |
| Medium | **Analytics** opened by a role without `report.view` drew the refused reads as *Nothing needs attention — stock, debts and the drawer all look normal* | mobile `aec0d95` |
| Medium | **320 pt with 1.3× text**: a status chip could not shrink, so it ran off the screen or over the time beside it — 12 page states in French, 4 in English, 3 in Arabic (transfers, a debt, a consignment, a price approval, returns, the sales list, an import, Settings' *Copy*, Analytics' *View all alerts*); after midnight a weekday time (*jeudi 23:36*) ran under the notifications' chips | mobile `248288f`, `e484b58` |
| Medium | **Set a target** as a Manager: *One person* opened on no names (the team list needs `user.manage`) and could never be saved | mobile `248288f` (offered only with `user.manage`; the server list for `goal.manage` is open, below) |
| Medium | The **refusal screen** opened by an active shop said *Subscription ended* | mobile `c7c6265` |
| Low | **Platform administration at 320 pt with 1.3× text**: *Create a business* ran off the screen (EN, FR); in French a pending business's state and *Nouvelle invitation du propriétaire* ran off it; a long state cut a business's name to *B…* | mobile `ec5eac6` |
| Low | A heading squeezed onto two lines by its action (*À / examiner* beside *Voir les 19 alertes*); a price approval's product name broken word by word beside its status | mobile `248288f` (the amount-row rule: the action or status moves below when it needs more than half the row) |
| Low | **Sale details** (FR, AR; EN when part-paid): the payment state beside the product squeezed its name to one word a line (*Apple / iPhone / 15 Pro / 128 GB / · Blue*) — found by a squeezed-text check run on every page for every role and language | mobile `220994b` (the state sits under the invoice) |
| Low | **Sale details**: short values (*1 Oct 2026 · 20:53*, the seller) squeezed onto three lines (against `docs/61` §8) | mobile `c7c6265` |
| Low | The server key **`CASH`** and ISO dates (*On 2026-09-20*) on the differences; **Targets**: a bare *10675 a day* and ISO dates | mobile `c7c6265` |
| Low | **Edit product**: *Because it is filed under {Accessories}* (a double-braced placeholder, EN/FR/AR) | mobile `c7c6265` |
| Low | Plurals: *1 items*, *in 1 lines*, *1 phones*, *the 1 days before*, *the 1 days left*; *1 differences*, *1 refunds* on the Daily closing **and in the PDF** | mobile `c7c6265`, `3e819d4` |
| Low | An empty *What you can do* card on a consignment waiting on the other store | mobile `c7c6265` |
| Low | Team showed retired roles as keys (*branch manager*), untranslated | mobile `c7c6265` |
| Low | **Outstanding payments** for a role without `report.view`: *did not load — Try again*, a retry that could never work | mobile `aec0d95` |
| Low | *Record a debt*, *Set a target*, *Import Excel or PDF* opened in full by a link for a role the server refuses at the end (buttons were already hidden) | mobile `aec0d95`, `3e819d4` |

Pinned in mobile `lib/visual-review.test.ts` (15 tests, reading each rule from the source), `lib/branch-restore.test.ts`
(4), `lib/closing-report-view.test.ts` and `lib/report-pdf-html.test.ts` (the singular sentences), and backend
`src/loans/loan-rules.spec.ts` (`isOwnOffer`). Device checks: `docs/24` §53 (AD1–AD15).

## 8. Left for the owner

| Severity | Finding | Why not fixed here |
|---|---|---|
| Medium | **Notifications** for sales, closings, refunds, returns, debts, consignments and purchases are stored as English sentences with raw numbers (*Sale 00014 — 22000*, *1 item(s)*, *Day 2026-09-20 closed*, *Purchase total 1622550*) and stay English in French and Arabic; only transfers and price approvals are rebuilt in the reader's language | Needs the server to store each type's fields, as transfers already do — a backend and app change per notification type, not a low-risk fix |
| Medium | **A Manager cannot set a personal target**: `goal.manage` lets the server accept one, but the people to choose from come from `GET /users`, which needs `user.manage`. The app now offers *One person* only to a role that can list people | A narrow people list for `goal.manage` (names only) is a new server read on the permissions surface — for the owner to approve |
| Medium | **An expired shop is told only on More**: its Home and Money still offer *Open the boutique*, *Sell*, *Receive* and *Add expense*, and the server refuses each at the end; the red *Your subscription has ended* notice sits on More (Milestone N's placement) | Where an expired shop is told, and whether write actions hide, is a product decision — the server already refuses every write |
| Medium | **Terminology**: *Phone sales* and *{n} phones sold* in an all-electronics product, while the list also holds accessories (the count is phones only) | A wording and product decision |
| Low | **Full identifiers** on detail pages business rule 19d does not name — a price approval, consignment and transfer lines, a return, the import review (*Line 2 · 356938035643809*); 19d masks stock lists, previews, notifications and compact summaries, and shows the full number on the scanner result, the completed sale and the receipt. Every identifier in this package is a synthetic fixture value | Whether 19d's masked list extends to these pages is a privacy decision |
| Low | Lazy plurals *(s)* in seven strings (*1 phone(s)*, *1 item(s)*, *unit(s)* …) and Arabic plural classes (*10 دقيقة* where *10 دقائق* is right) | A plural helper across the catalogue — a copy pass of its own |
| Low | Two-line list subtitles cut at 393 pt: FR consignments (*Envoyé · 1 téléphone(s) · En route — arrivée non confirmée*), AR price approvals | The list row's design; the detail shows everything |
| Low | At 320 pt with 1.3× text a four-way choice breaks words inside its segments (*Set a target* → *What to aim at*: *Vent / es…*); the segment allows two lines, then cuts | The control's own limit (≈ four options); a picker sheet at that size is a design choice |
| Low | *Refreshed 0 seconds ago* (Boutique ranking) | Copy |
| Low | Import review: *2 will be added. 1 cannot, and are listed below.* | Copy |
| Low | Edit product labels an accessory's variant *Storage* (*iPhone 15*) | The field is generic; a label per category is a product choice |
| Low | *Return policy* shows a lower-case *no returns* line beside a *No returns* chip | Copy |
| Low | Sales list: *Wednesday 09:00* for yesterday (the same-week weekday rule) | Copy rule |
| Web only | A focused text field draws the browser's focus ring inside its border | React Native Web's default; native unaffected |
| Web only | At 320 pt with 1.3× text a long header title runs under the header's button (*Entreprises* × *Se déconnecter*) | The browser pass enlarges text after the navigation header measured itself; on a phone the header measures the system's text size |

**Subjective — for the owner's review, not changed:**

- The difference's decision rows look plain without a marker on the chosen one (Settings' lock list shares the style).
- The Arabic Home chart runs its hours right to left (consistent with RTL; a time axis is sometimes kept left to right).
- Transfer detail: *What is being sent* sits tight under the card above it.
- The Partners detail's *Consignment · phones: 1* phrasing.
- Results offers the PDF for *This month* only (D115).
- Home's three figures: the *Collected* note runs to four lines in its third-width tile in French (*Reçu sur la période, dettes anciennes comprises*).
- The platform overview's state counts are a sideways strip whose last tile is cut at the screen's edge (it scrolls); *Create a business* starts in French.

**Fixture artefacts (not the app):** Names that repeat the brand (*Redmi Redmi Note 13*, *POCO POCO X6 Pro*, *Xiaomi Xiaomi 14*): the QA seed's model names include the brand. Return timelines on back-dated rows mix the API's fake clock and the database's `NOW()` (a refund *confirmed 20 Sep* listed after *reported 1 Oct*). *5 of 2 in use* staff places: the fixture's extra logins (the legacy and administrator roles used for the PDF permission proofs). Price approvals expire after 30 minutes: both the *expired* fixture and a *pending* one are captured. Boutique 4 and Boutique 5 held platform grants running to 2027, which outrank an ended period — so the *expired* and *grace* states never showed. Their grants were ended on the disposable fixture (`complimentary_until` 15 Sep), and the server now reports *expired* and *grace (49 h left)*. The platform's audit trail lists the review's own administrator sign-ins; *Devices* lists one *Web browser* per capture sign-in; *Notifications* and *Price approvals* list the approvals the review asked for, one per run.

**Not verified on any device** (the web export stands in for the phone): the camera and scanning; the native print
preview, the PDF's file name in the share sheet, saving to Files and every share target (`docs/24` §52); haptics; the
system text size on a real phone (the 1.3× pass scales text in the browser — `docs/24` §53 AD12 asks for the largest
size on an iPhone SE); the keyboard over forms; safe areas and the home indicator; Arabic right-to-left as the native
layout engine mirrors it; the fonts the phone substitutes.
