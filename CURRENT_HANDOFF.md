# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Owner: **CLAUDE-A** · `started_at_utc: 2026-09-21T23:52Z` — the visual-fidelity conversation, resumed after the 23:48Z reboot to close its evidence and handoff
- Last owner: **CLAUDE-A** · 2026-09-21
- Last phase: **visual fidelity of the approved screens** — complete in code, pushed,
  rendered on the final build; **handset checks owed**.
- **Claimed, not started:** at 21:25Z a second CLAUDE-A conversation claimed the next
  brief — *inventory correction, Excel-review performance, generic selling and the global
  card hierarchy* (seven checkpoints, CP1 audit → CP7 Money terminology). It changed no
  code, schema or data; its last activity was 21:36:52Z and it is not running. That brief
  is the next work — see "The next exact action".

### What happened on 2026-09-21 — two conversations, one label

The clock on this PC is UTC+0 (Greenwich Standard Time); times below are real UTC.

- 18:09Z the visual-fidelity conversation took ownership; 19:25–19:31Z it drafted its
  closing docs **ahead of** its final render and teardown, and left them uncommitted.
- ~20:04Z and again from 21:25Z the user worked in a **second conversation with the same
  label**. Reading the uncommitted draft as an interrupted session, it committed those
  files as found (`d7155bb`), appended a reconstructed log entry, claimed the next
  brief, and stopped the isolated API, static server, headless Chrome and the
  `prisma_verify_ui` schema — which the first conversation was still using. Both ran
  against one working tree from 21:25Z to ~21:37Z. No file was edited by both; the only
  loss was the render run then in flight.
- 21:32Z the first conversation pushed mobile `45f4905` (the last narrow-width fixes),
  which the 21:25Z baseline (`71970bf`) does not include.
- 23:48Z the PC was restarted; every process ended. 23:52Z this conversation resumed.

**Lesson recorded:** one label for two conversations defeats the ownership rule. A draft
closing handoff must never sit uncommitted on disk while work continues; write it last.

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed this phase; fixed costs, salary, reference, note, discount,
return policy and split payment moved under one-tap disclosures, never away.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`c4d4534`** (unchanged this phase) | level | 0 |
| `erp-mobile` | `reports-export` | **`45f4905`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

## What changed this phase

The approved screenshots are the binding references; the decision record is
`docs/21` "the approved screens, as drawn". No server contract changed, no
migration, no dependency, no config. Mobile commits `2be363c` … `45f4905` (10).

| Reference | Route / component | What changed |
|---|---|---|
| Money — Today · 7 days · This month | `app/(tabs)/money-hub.tsx` | tinted *Cash in store now* card (accounts one tap away); filled period switch with exact days ("14–18 Sep 2026", `formatDayRange`); one card with Phones sold · Sales value · Collected · Still owed; *Phone sales* (today, 3 rows) or *Sales by day* (a week; a month's latest three days + one folded line naming the earlier span — never a sum on the phone); *Daily expenses* with *Add expense*, today's rows and *View all expenses*; registry rows |
| Phone sales | `app/sales/period.tsx` | title "Phone sales"; tinted *Sales total* with phones, Collected, Still owed; **FlatList** of sale rows (today) or day cards opening in place (week/month); `?day=` opens a day |
| Sale details | `app/sales/[id].tsx` | phone card first (name, variant, status chip, **full IMEI/serial**), tinted *Selling price*, facts (method, received, owed, sold on, sold by), buyer/debtor row, payment history, return policy, totals, **View receipt** (built from the sale) |
| Add expense / Review / Daily expenses | `app/expenses/new.tsx`, `app/expenses/index.tsx` | Description, Amount (MRU), *Paid from* (Cash or Choose account), Payment date (typed, today by default), Add receipt; *More options* holds fixed/salary/reference/note; **Review expense** with, for an Owner, *Expected cash after recording* and **Record paid expense** (report + confirm in one explicit act); others *Send for approval*. Daily expenses: banner, cash card, today's rows, all expenses with filters, pinned *Add expense* / *Back to Money* |
| Sale payment | `components/sell/PaymentSheet.tsx`, `DebtorPicker.tsx`, `components/money/ReceivedVia.tsx` | what is sold, *Sale total*, *Amount received now*, *Received via* (Cash or Choose account → account chips; the account implies the method), amber *Remaining to pay* + status, *Who owes the balance?* (Customer: name + optional phone or *Select existing customer*; Store: picker + *Add a store*), "Only X recorded as received", **Review sale** (worded confirmation of the balance); discount/return policy/split under one disclosure; the sheet remounts fresh on open |
| Record payment | `app/sales/pay/[id].tsx` | debtor · sale card, amber *Remaining before payment*, amount, *Received via*, date/time, reference, note, tinted *This payment* beside *Remaining afterward*, pinned **Record payment**; "Payment recorded" banner on return (`lib/recent-success.ts`) |
| Sell a phone · Enter IMEI · Choose from stock · Review sale | `app/quick-sell.tsx`, `components/sell/PhonePicker.tsx` | three choice cards; per-mode titles and header back to the chooser; live lookup at the fifteenth digit with the complete IMEI on the found card; search, brand chips, "N phones available", rows with variant, masked IMEI, ladder price (from `/inventory/summary`), Available chip, selection and a pinned *Continue*; review card with masked IMEI, Available, price field, *Found by*, note; *Continue to payment* / *Choose another phone* |
| Primitives | `SegmentedControl` (`filled`, `buttons` looks, icons), `Card` (`accent`, `warning`), `MoneyValue` `large`, `Thumbnail`, `DayRow`, `LinkRow`, `ExpenseLine`, `PeriodSelector` | design-system additions only; nothing existing restyled except where these screens use them |

**Not drawn, on purpose (not server figures):** "Payments recorded" by method for a
period; per-source subtotals under today's expenses; a month's folded-days subtotal.
**Deviations:** honest icon thumbnails (no catalogue photos, `docs/47`); typed
`YYYY-MM-DD` date fields (no picker without a dependency); full IMEI on the completed
sale (confirmed policy); Quick Sell stays a stack screen (no tab bar beneath it).

**Found, not fixed (backend, recorded for the next session):** `GET /closings/overview`
answers 400 "Database request error" under MySQL 8's default `sql_mode`
(`ONLY_FULL_GROUP_BY`): `closing.service.ts` ~L911 selects a non-aggregated
`receiving_account_id` in a GROUP BY. Live works only because WAMP's service group sets
`sql_mode=""`. Any default-configured deployment (staging, `docs/45`) will hit it.

## Verification

| Kind | Result |
|---|---|
| **Mobile** | `tsc` clean · `expo lint` **0 errors / 32 warnings** (baseline; the one new warning was removed) · **68 pure suites, 0 failed** (+`day-range`, +`expense-rules`; every existing assertion kept) · EN/FR/AR parity (58 new keys, 19 reworded) · web export with every route · raw-colour, literal-copy and dependency audits clean · Expo Doctor: 4 packages out of date (pre-existing drift, unchanged) |
| **Backend** | unchanged (`c4d4534`); the isolated copy served every screen through the real API |
| **Renders** | On the `71970bf` build: **288 captures** (24 states × EN/FR/AR × light/dark × 320/390 pt) — no leaked key, no overlap, no sideways scroll; three clipping classes at 320 pt (product names in sale rows, the "All expenses" row titles, a long French customer hint) → fixed in `45f4905`. **Re-render of the final build in progress.** |
| **Evidence** | before: `%TEMP%\claude\shots-money\` (2026-09-18, the previous screens); after: `%TEMP%\claude\shots-ui\` (EN/light/390 first pass) and `%TEMP%\claude\shots-ui-matrix\` (the matrix) — 24 states per language × theme × width: Money today/week/month, sales month/week/today, sale paid, sale part-paid with history, record payment, expense form, expense review, daily expenses, outstanding, sell chooser, IMEI found/invalid/not found, review sale, payment full/partial customer/partial store/store pick, stock picker plain/selected |
| **Physical device** | 🔴 **none**. `docs/24` **§33 V1–V14**, plus §32, §31, §30 |

## Services

- **MySQL `:3306`** — a user-level `mysqld --sql-mode=` (PID 2292, started 23:51Z by this
  conversation for the final render; WAMP's service is Stopped and needs elevation).
  It will be shut down when the render is done.
- **Live API `:3010`** and **Metro `:8081`** — down since the 23:48Z reboot; not started.
- **Isolated verification** — `prisma_verify_ui`, API 3011, static 19006–19008, Chrome
  9333: being rebuilt for the final render; torn down and verified afterwards.

## 🔴 Blockers and pending approvals

- **Native build blocker (pre-existing):** `npm install`'s postinstall fails —
  `expo-camera` 57.0.5 is installed but the Android scan-region patch was cut
  against 57.0.4 (alignment `e960ef6`). Expo Go is unaffected. A native build must
  re-cut the patch and re-verify scanning on Android.
- **Live rollup repair — still awaiting approval (NOT applied).** Audit shows
  `Sale create` ×28 on 2026-09-10 and ×4 on 2026-08-08 with no surviving sales
  (fixtures hard-deleted outside the app); rollups for those days overstate
  revenue by **388 340.00** (Home shows 328 300 profit). Procedure: backup per
  `docs/22` → `DB=phonestore node scripts/rollup-audit.js` (confirm exactly 2
  rows) → `… --repair`.

## 📋 Known, not fixed

- On web, a screen pushed from a tab announces its back button as "(tabs), back".
- A bottom sheet's Close button is 36 pt with no hit slop (app-wide, pre-existing).
- Dynamic type cannot be exercised in a web render; handset only.
- No catalogue images (`docs/47`). The pre-release security gate (`docs/48`) is
  not started. Owner decisions D4–D6 (hosting, database hosting, backups) block
  staging (`docs/45`); release risks in `docs/41` §6.

## The next exact action

1. Start WAMP (MySQL), then the live API from backend `c4d4534` and Metro; reload Expo Go.
2. Resume the brief claimed at 21:25Z — *inventory correction, Excel-review performance,
   generic selling, global card hierarchy* — at **CP1: audit the real contracts**
   (permissions, unit fields, versioning, IMEI uniqueness, identifier lookup, import draft
   states, review rendering, thumbnails, nested cards) before any implementation. Nothing
   of it exists yet. Its instruction named handset screenshots that never arrived.
3. Handset: **`docs/24` §33 V1–V14** (the approved screens), then §32, §31, §30.
4. Fix the `ONLY_FULL_GROUP_BY` defect in `closing.service.ts` (~L911) before any staging deploy.
5. Decide the live rollup repair.
