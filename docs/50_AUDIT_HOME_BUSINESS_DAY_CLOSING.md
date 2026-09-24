# 50 — Audit before the Home dashboard and the business-day closing (2026-09-23)

> Written **before any code changed**, as the rulebook requires: what the
> repository actually does today, where it contradicts the six reference screens
> and the brief, what is missing from the backend contract, and the plan, the
> files and the risks. Decisions taken here supersede the earlier ones they name
> and are recorded in `docs/21` under the same date.

## 1. Baseline

| Repository | Branch | HEAD at takeover | Dirty |
|---|---|---|---|
| `erp-docs` | `master` | `f1284e4` | 0 |
| `erp-backend` | `reports-export` | `decb699` | 0 |
| `erp-mobile` | `reports-export` | `e43b551` | 0 |

All three level with `origin`; `CURRENT_HANDOFF.md` said `READY_FOR_HANDOFF` /
owner `NONE`, and the commit ids it records are the ones found. No other agent's
uncommitted work exists. The brief named no commit hashes to check against.

Live database (read-only readings, `phonestore`): 2 companies, both
`timezone = 'UTC'`, `currency = 'USD'`; 9 sales (3 of them between 00:00 and
05:59 UTC), 9 payments (3 before 06:00), 4 expenses (1 confirmed before 06:00),
0 refund payouts; **one** `daily_closings` row (2026-09-15, status `counted`,
never locked, expected 0 / counted 0); 6 `daily_rollups` rows (the known
2026-09-10 / 2026-08-08 overstatement of 388 340 is still awaiting the approved
repair and is **not** touched here); 43 units in stock, 10 sold; 2
counterparties, 0 consignments, 2 loans, 0 sales with a partner-store debtor;
0 delegated grants; roles in use: 10 owner, 3 store_manager, 10 store_employee
assignments; **no user has a phone number**; WhatsApp settings `en`, amounts off.

## 2. What the repository does today, against the brief

| Area | Today | The brief / the reference screens |
|---|---|---|
| Day boundary | Every "day" is a **UTC calendar day**: `dayKey()` = `toISOString().slice(0,10)`. Sales and payments are bucketed by instant at read time; expenses, refunds, settlements, corrections, reversals and ledgers store a DATE assigned as `dayKey(new Date())` at write time. `companies.timezone` exists (default `UTC`, registration writes `Africa/Nouakchott`) and **nothing reads it**. `docs/21` records "period boundaries are UTC, no timezone feature" as a known gap. | A business day begins **06:00:00 in the branch's local timezone**; immutable instants stored **alongside** assigned business dates; one assignment everywhere. |
| Closing | `counting → counted → locked`. A locked day is final: `close` and `recordCount` throw 409; comments and `docs/21` Milestone E say "a locked day stays locked… never by reopening"; rule 25 says "closed once". A sale on a locked day is **not prevented** (sales never look at the closing); a later payment, an expense confirmation, a correction and a return approval into a locked day **are refused**. | A close is a counted snapshot + history event, never prevents a sale; **reopen before the boundary**, `Reopened · review due`, fresh count, reclose; earlier snapshot kept; Owner 03:00 choice; automatic audited reopen when a seller sells after a close. |
| Expected cash | `expected = cash in − refunds out − supplier out − expenses out + corrections in`, **no opening float** (rule 26a: "each day is reconciled on its own"). | Carry cash forward as an **opening balance**, not income. |
| Home | `app/(tabs)/index.tsx` shows month-to-date figures from `/analytics/summary` (profit card + three tiles), pending work, Sell/Receive. No Today/7 days/month switch, no graph, no top partner, no arrivals, no closing card. `GET /home` exists but is unused by the app. | Screens 01/02: Today / 7 days / This month (server-defined business dates, exact ranges), Sales value, Collected / Expenses / Still owed, a bar graph whose bars sum to the sales value, Top boutique all-time, Latest phones received, Daily closing card, an honest "refreshed" footer. |
| Partner ranking | `GET connections/:id/summary` gives balances and custody for one partner; there is **no per-partner completed-trade value**. `docs/21` records the **contract gap**: no bilateral inter-store sale exists. The existing model has two completed-trade records with a value: a **settled consignment** (source side, `receivable_raised` ledger entries) and a **fully paid sale whose debtor is a partner store** (`sales.counterparty_id`, 0074). | Screen 03: rank / name / completed trades / value, "All time", value then count with a stable tie-breaker, honest empty state if unsubstantiated. |
| Stock deep-link | `GET /inventory` filters by `status`, `productId`, `search`; orders by `id desc` (UUIDv7 ≈ newest first); **no tracking-type filter in units mode** and no sort parameter; the screen reads only `productId`. | Screen 04: Phones + All statuses + Newest received first preselected; the same newest three as Home even if since sold. |
| Delegation | Only `price.edit` is delegatable, to a Store Manager, one explicit route pair. `closing.perform` is held by Owner **and Store Manager** by role. | Owner + up to two named employees granted closing privilege may review/count/close/reopen; Owner replaces/revokes; a clear maximum; enforced on every mutation and protected read. |
| Owner WhatsApp | The messaging boundary sends **only** the login OTP template; `CompanySettings.whatsapp*` exist ("nothing is sent in this phase"); rule 36 limits WhatsApp to daily/monthly summaries. Deduplicated in-app notifications exist (`dedupeKey` unique, P2002 = already told). | Reopened / each sale in the reopened interval / reclosed notices to the Owner, deduplicated by stable event ids, never blocking a sale or a close, stubbed in tests. |

**Contradictions surfaced, resolved by supersession (recorded in `docs/21`):**

1. Rule 25 and Milestone E ("locked… never by reopening") → superseded by the
   reopen/reclose lifecycle **inside the same business day only**. After the
   boundary a day is still final and corrected only through Milestone B.
2. Rule 26a "no opening float carried over" → superseded for **cash**: the
   drawer's opening balance is the counted cash at the last locked close plus
   the net cash movement of any unclosed days between. Accounts keep rule 26a
   (recorded movement, never a balance).
3. Rule 36 "WhatsApp summary only" → widened by three operational notices to
   the Owner, under the same privacy constraints (no full IMEI, no cost, no
   customer phone, no other tenant's data).
4. "Period boundaries are UTC, no timezone feature" (`docs/21`,
   `lib/home-metrics.ts`) → superseded by the branch business date. The
   timezone is the company's `timezone` column (a branch has no column of its
   own; the shops of one company share a country). Live companies say `UTC`,
   so on live only the 06:00 cutoff moves anything.
5. Milestone E's "a Manager holds `closing.perform`" → superseded: closing
   authority is the Owner plus **at most two** delegated assignments per
   branch (Store Manager or Store Employee). Counting (`closing.count`) is
   unchanged.

## 3. The backend contract, decided here

### 3.1 Business date

`src/common/business-day.ts` (pure): `businessDateOf(instant, timezone)` =
the local calendar date of the instant, minus one day when the local hour is
before 06:00. `dayWindow(date, timezone)` = the half-open instant window
`[date 06:00 local, date+1 06:00 local)`. No DST shortcut: the local hour is
read with `Intl.DateTimeFormat`, so a zone with DST still cuts at its own 06:00.

`BusinessDayService.assign(branchId, instant)` returns the stored date for a new
record: the natural date, **or** the following date when the Owner elected
"Start new business day now" for that branch at or before the instant
(a `closing_events` row of kind `day_started_early`, one per branch and date).
Once a date has been started early, 06:00 does not start it again — the natural
rule already yields it.

**Stored:** `sales.business_date`, `payments.business_date`,
`supplier_payments.business_date` (the three instant-keyed money tables).
Expenses, refunds, settlements, corrections, reversals and ledgers keep their
existing DATE columns, now assigned through the same service instead of
`dayKey(new Date())`. Rollups, the closing, Money, the summary, the daily sales
series and Home all key on these.

**Effective-date / backfill policy.** Existing rows are backfilled with the
**UTC calendar date they were always reported under** (`DATE(sold_at)`,
`DATE(paid_at)`), never recomputed with the 06:00 rule: every past report,
rollup and the one existing closing stay byte-identical, which the isolated
run proves by comparing rollup totals before and after. The rule applies to
records written **after** migration 0076 is applied (`effective_from` recorded
in the migration comment and in `docs/21`). Nothing historical is reassigned;
a later correction of a stored business date is an audited Owner act that this
phase does not build (recorded as owed).

### 3.2 Closing lifecycle

`daily_closings.status` gains `reopened`. New columns: `first_closed_at`,
`first_closed_by_id` (kept forever), `reopened_at`, `reopened_by_id`,
`reopen_count`. `closing_channel_counts.opening_balance` (cash only). New table
`closing_events` (kind `count_saved | closed | reopened | auto_reopened |
reclosed | day_started_early`, `at`, `actor_id`, `payload` JSON with the
snapshot the event froze, `dedupe_key` unique per company).

- **Close** (existing `POST /closings`): unchanged for a `counting`/`counted`
  day; writes a `closed` event with the frozen snapshot and the actor.
- **Reopen** (`POST /closings/reopen`, `closing.perform`): only the **current
  business date**; `locked → reopened`; keeps the row's first snapshot fields,
  writes a `reopened` event; `mode: 'continue'` (default) or `'start_new'`
  (Owner only, `closing.start_early`, offered only after local midnight and
  before 06:00) which writes `day_started_early` for the next date and leaves
  the closed day closed.
- **Reclose** (`POST /closings` on a `reopened` day): requires every countable
  channel to be counted **after** `reopened_at`; freezes again; writes a
  `reclosed` event whose payload distinguishes movement since the first count
  from the revised whole-day total. Unresolved discrepancies are updated to the
  new difference (or resolved as `error_corrected` when none remains); a
  discrepancy somebody already decided stays, and a remaining delta opens a new
  one.
- **Sale after a close** (same business date): the sale succeeds; the service
  reopens the day automatically (`auto_reopened` event, audited) and notifies.
  A later debt payment on a locked current day does the same; a backdated
  payment into an earlier locked day is still refused (Milestone B).
- **06:00**: the next request computes the next date; the previous day, if
  not locked, reads `Needs review`. No scheduler.

### 3.3 Delegation

`closing.perform` becomes delegatable (`DELEGATABLE_PERMISSIONS`), to a Store
Manager **or** Store Employee assignment, **maximum two grants per branch**
(`CLOSING_DELEGATES_MAX = 2`, enforced in the grant service and refused with
409). Routes `PUT/DELETE /users/:userId/branches/:branchId/delegations/closing`.
`store_manager` loses `closing.perform` by role (43 → 42 keys; the drift and
store-role specs are updated with the reason). New Owner-only key
`closing.start_early` (catalogue 62 → 63).

### 3.4 Owner notices

`ClosingNoticeService`: after commit, for a day that had been counted-closed —
`closing.reopened`, `closing.sale` (each completed sale while reopened),
`closing.reclosed`. Each is an in-app notification to every Owner with a
`dedupeKey` (`closing:<id>:reopened:<n>`, `closing-sale:<saleId>`,
`closing:<id>:reclosed:<n>`); the WhatsApp send uses the same key as
`idempotencyKey` through `WHATSAPP_CHANNEL`, only when the Owner has a phone,
in the company's `whatsappLanguage`, amounts only when `whatsappIncludeAmounts`.
Failure is logged and recorded on the event payload; it never throws into the
sale or the close. Tests inject `TestWhatsAppChannel`. On live nobody has a
phone number, so nothing can be sent there.

### 3.5 Home, ranking, Stock

- `GET /home?period=today|week|month` (auth only; sections gated by the
  caller's permissions): range with exact business dates, figures
  (`report.view`), series (hourly / seven daily / grouped bars from the same
  query as the sales value), `topPartner` (`consignment.view`), `arrivals`
  (branch members), `closing` (`closing.count`), `generatedAt`.
- `GET /partners/ranking?page&limit` (`consignment.view`): completed trades =
  settled consignments from this branch + fully paid partner-store sales at
  this branch, grouped by counterparty, ordered value desc, count desc, name,
  id. The outright inter-store sale stays a documented gap.
- `GET /inventory?trackingType=imei` — the new filter; ordering stays
  `id desc`, which is also how Home picks its three arrivals, so the two agree.

## 4. Files

Backend: `prisma/schema.prisma`, `prisma/migrations/0076_business_day_and_reopen/`,
`src/common/business-day.ts` (+spec), `src/closing/business-day.service.ts`,
`src/closing/closing.service.ts`, `closing.controller.ts`, `closing.module.ts`,
`src/closing/closing-lifecycle.ts` (+spec), `closing-notices.ts` (+spec), DTOs,
`src/analytics/rollup.service.ts`, `summary.service.ts`, `dashboard.service.ts`,
`dashboard.controller.ts`, `home-series.ts` (+spec), `src/sales/sales.service.ts`,
`sale-payments.service.ts`, `src/expenses/expenses.service.ts`,
`src/corrections/corrections.service.ts`, `src/returns/returns.service.ts`,
`src/loans/loans.service.ts`, `src/consignment/consignments.service.ts`,
`connections.controller.ts` + `partner-ranking.service.ts`,
`src/inventory/dto/inventory-query.dto.ts`, `inventory.service.ts`,
`src/rbac/role-permissions.ts`, `permission-scope.ts`, `src/users/*`,
`src/messaging/templates.ts`, specs that pin the changed text.

Mobile: `app/(tabs)/index.tsx`, `app/(tabs)/inventory.tsx`, `app/closing.tsx`
(now Closing & history), `app/closing/count.tsx` (the counting screen),
`app/partners/ranking.tsx`, `app/team.tsx`, `lib/home.ts`, `lib/closing.ts`,
`lib/business-day.ts` (+tests), `lib/query-keys.ts`, `lib/navigation/registry.ts`,
`components/home/*`, i18n `en/fr/ar`.

Docs: `docs/04` §F, `docs/21`, `docs/24` §37, `docs/50` (this), handoff, log.

## 5. Risks

- **Migration 0076 touches money tables** (adds NOT NULL DATE columns with a
  backfill). Backup and restore-proof first; live rows counted before and after.
- **The 06:00 rule changes which day a late-night sale belongs to** from the
  effective date on. Documented; historical rows are untouched.
- **Managers lose sign-off until delegated.** On live three Store Manager
  assignments exist; the Owner delegates two per branch from Team.
- **Specs that pin the closing SQL text** (`period-movements.spec.ts` and
  friends) are rewritten to pin the new keying, not deleted.
- **No provider**: WhatsApp notices are recorded as `channel_unavailable` on
  live; the in-app notification still reaches the Owner.
- **Live rollup repair** stays unapplied; Home's month figures on live still
  carry the 388 340 overstatement until the approved repair runs.

---

## 6. Addendum (2026-09-24) — the date selector, the physical opening, and three corrections

The user's brief of 2026-09-24, in the same scope. Audited against the code as committed at
backend `a8fc4fe` / mobile `57deb64` before any change.

### 6.1 What the repository did, against the brief

| Ask | Found | Gap |
|---|---|---|
| Choose a business date on Closing & history, incl. 15 days ago | `GET /closings/open/view?date=` already accepts any date and computes that day's standing, channels and history; the screen never passed one | No selector; the history of a day closed before 0076 was empty (its closing row and counts were never read back as events); no store-local time on the rows (the phone formatted the instant in its own zone) |
| "No opening time recorded"; a first sale as "First activity" | Nothing recorded a physical opening; the day's "Open" standing was the reporting boundary; sales appeared in the history only after the first close | No opening concept at all; the first sale was invisible before a close |
| "Opened today · 07:25" after an explicit open; "Reopened today" when the day was already closed | The reopen existed (0076); an explicit open did not | An event kind, an action, the card line, the timeline row |
| The early-start choice only before 06:00 | The server already offers `start_new` only between local midnight and 06:00; the sheet's title used the **phone's** clock, so under the render matrix's fake clock it read "Reopen at 07:25" above a choice the server had offered at 03:00 | The sheet must show the server's clock; the choice list already was the server's |
| "Still owed" cut at 320 pt | The scope caption was limited to two lines | One attribute |
| Masked identifiers in the Stock list reached from "Latest phones" | Full identifiers, as before | The arrivals mode masks |

### 6.2 The contract

- **`opened` event kind (migration 0077).** `closing_events.kind` gains `opened`. Only a person creates one, through `POST /closings/open` (`closing.count`): the physical opening, with its instant and its actor. **The 06:00 cutoff starts a reporting date and never creates an opening event.** `closing_id` is NULL when no closing row exists yet, exactly like `day_started_early`.
- **Only the current business date can be opened**, never twice while open, and never a closed day: a closed day is *reopened* (`POST /closings/reopen`, `closing.perform`) and the timeline says "Reopened". Refusals are 409 `open_already_open`, `open_day_closed`, `open_past_day`, `open_future_day`. Two taps at once meet the dedupe key `closing:open:<branch>:<date>:<n>` and the second changes nothing.
- **The door** (`doorState`, pure): `opened` / `reopened` / `auto_reopened` open it; `closed` / `reclosed` close it; a day with no such event is `never_opened`, however many sales it has. The view carries `door`, `opening` (the latest opening: kind, instant, store-local date and time, actor — or null), `canOpen` and `openRefusal`.
- **The timeline** (`history`, unchanged route): every event; the **first sale of the date as `first_activity`** (its actor is the seller); after the first close, each later sale as `sale`; and, for a day closed **before 0076**, its closing row read back as a `closed` entry and its channel counts as `count_saved` entries (`payload.fromRow: true`) — nothing recorded is ever dropped. Every row carries `localDate` and `localTime` in the company's zone; the view carries `localNow`, `localNowDate` and `lastCountedLocalTime`. The phone shows those strings and never formats an instant in its own zone on this screen.
- **A past date with no closing row reads "Needs review"** (`standingOf`), not "Open": a day behind the boundary that was never closed is exactly what needs review.
- **The sheet's clock is the server's.** The reopen sheet's title shows `localNow`; its choices were already the server's (`reopenChoices`), so at 07:25 by the store's clock the early start is never offered, whatever the phone's clock says.
- **The Stock list reached from "Latest phones received"** shows `•••• 5930` for every unit, as Home does; the full identifier still opens the unit but is not what the glance shows. The normal Stock list is unchanged.
- **"Still owed"'s scope line wraps** instead of being cut.

### 6.3 Files

Backend: `prisma/schema.prisma` (enum), `prisma/migrations/0077_physical_opening/migration.sql`, `src/common/business-day.ts` (`localTimeOf`) + spec, `src/closing/closing-lifecycle.ts` (`doorState`, `openingOf`, `canOpen`, `standingOf` for a rowless past day) + spec, `src/closing/dto/open-day.dto.ts`, `closing.controller.ts` (`POST closings/open`), `closing.service.ts` (`open`, `timeline` replacing `history`, the view's new fields), `closing-routes.spec.ts`.
Mobile: `lib/closing.ts` (types, `useOpenDay`), `lib/home-day.ts` (`openingKey`, `shiftDay`, `dayChoices`, `dayWordKey`, keys) + test, `app/closing/index.tsx` (the selector, the opening line, the open action, store-local rows), `components/closing/ReopenSheet.tsx` (`now`), `app/(tabs)/index.tsx` (the caption), `app/(tabs)/inventory.tsx` (masking), i18n EN/FR/AR (19 keys).

### 6.4 Risks

- 0077 is one enum value; the backfill is none. Applied to live only after a fresh backup is restore-proved, per `docs/22`.
- The selector reaches back sixty days; older days remain readable through the route but not through the sheet (a decision for the Owner if ever needed).
- A pre-0076 closing's derived `count_saved` rows carry the count's own time and person; a pre-0045 closing (counted and locked in one step) shows its `closed` row only.
- The timeline's "First activity" is the first **non-reversed** sale; a day whose only sale was reversed shows none, by design.
