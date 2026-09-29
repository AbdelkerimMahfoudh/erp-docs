# 63 — Money's one card, the Daily closing from Home, and the money a shop opens with (2026-09-28)

The user's brief of 2026-09-28 ("Money and opening flow"), approved with the user's corrections the same day. Three
parts: Money's top area becomes one compact card; the Daily closing leaves the Money list and is reached from Home;
opening the boutique includes the money it opens with. Decisions **D98–D102** in `docs/21`; rules 25, 25a and 26a in
`docs/04`; the phone's checks are `docs/24` §50. Migration **0083** (additive), on live since 2026-09-28 21:50Z.
Backend `b0f9bd0`, `90ef14a`, `55c1a3b`; mobile `c3eb47e`, `9d54803`, `812ba09`.

The user's corrections, verbatim in substance:

- *At a shop opening, the Owner may set that shop's cash. Company-wide Bankily and other shared accounts carry forward;
  changing one requires a separate, clearly company-wide Owner action. Do not silently change every shop's account
  figure from one shop's opening.*
- *A permitted non-Owner may open with carried amounts, but create a visible awaiting-Owner-review state. Do not label
  those amounts verified.*
- *Keep preserves unknown amounts as unknown. Set requires explicit values for the methods being set; 0 is valid but
  must be chosen.*
- *Make the server require an opening event before new-day sales and receipts, including older clients. For any
  existing pre-opening transactions during rollout, anchor an entered amount at its actual confirmation time and count
  only later movements. Do not backdate a "money remaining now" value.*
- *"The store stays closed if saving fails" must be true on the server for a new business day.*

---

## 1. Money's one card (D98)

| | |
|---|---|
| **Title** | *Expected money in store today* · « Argent attendu en boutique aujourd’hui » · «المال المتوقع في المتجر اليوم» |
| **The figure** | The server's total (`trackedMoney.total`) — one large figure. For anybody but the Owner, the drawer's own position; a line says the account amounts are shown to the Owner (TM-3, unchanged). |
| **The lines** | Cash, then each configured account, one short aligned row each: the position, or the word **Unknown** — never 0. A company account says *(whole business)* when the company has more than one shop. |
| **Unknown** | While any method is unknown there is **no total**: the card says *Unknown until every amount is known: {names}*. Nothing unknown is turned into 0, and nothing claims a provider verified a balance. |
| **Awaiting review** | When the day was opened with carried amounts, the card says so (*Opened with the carried amounts — awaiting the Owner's review*) and, for the Owner, offers **Review opening amounts**. |
| **Removed from the top** | The anchor explanations under each line, the per-account **Set amount** buttons, and the separate *Money recorded today* card. The period reports and every other Money function stay below, unchanged. |
| **The company action** | The Owner's accounts are set from their own row further down, **Company account amounts** (*Shared by every shop*): a sheet listing each account, and the existing amount sheet (`POST /money/anchors`), which now says before saving that *the amount you set is the one every shop sees*. |

The phone adds nothing up: the figures are the server's (`GET /closings/overview`), the same ones Home and the Daily
closing read.

## 2. The Daily closing is reached from Home (D99)

- The Money list no longer has a *Daily closing* row (`lib/navigation/registry.ts`: Money's children are Results,
  Expenses, Loans, Outstanding payments). `/closing` and everything in it are unchanged.
- Home's Daily closing card keeps the day's standing and gains one clear action, **Review closing**, which opens
  `/closing`. The card is shown to everybody who counts (`closing.count`), as before — nobody loses access.
- Somebody who only counts the drawer (no Results, Expenses, Loans or Outstanding) no longer sees a Money tab that would
  hold nothing for them; they reach the Daily closing from Home. The back arrow from `/closing` leads to Home.

## 3. The opening step (D100)

Opening the boutique — **Open the boutique** on Home, the Daily closing's *Open the boutique* and *Reopen*, and the
covers of Sell, Receive and a refused later payment — is one flow (`components/day/useOpeningFlow.tsx`), shown only on
a **closed-to-open transition**, never on app launch:

1. **Before 06:00, the day first** (`docs/56`, unchanged): the Owner chooses *Continue {date}* or *Start {date} early*;
   anybody else is told which day runs. The day sheet's button now says **Next**, because nothing opens yet.
2. **The amounts** (`components/day/OpeningMoneySheet.tsx`):
   - **The previous amounts** — the shop's cash (*This shop's drawer*) and, for the Owner, each company account as it
     carries forward (*Company account · carries forward*, or *Shared by every shop* with more than one shop). Unknown
     is written **Unknown**.
   - **The Owner chooses, explicitly — nothing is selected**: **Keep the previous amounts** (*nothing changes; an
     unknown amount stays unknown*) or **Set today's opening amounts** (*enter the cash in the drawer now*). Set opens a
     cash field prefilled with the drawer's known amount (empty when unknown — never a made-up 0), editable to any
     amount, with **Set to 0** for an emptied drawer; the total that results is shown before confirming, or *Unknown
     until every amount is known*. A note says company accounts carry forward and are changed from *Company account
     amounts* on Money. The confirmation, **Confirm amounts and open the boutique**, stays disabled until a valid choice.
   - **Anybody else who may open** sees the drawer as it carries forward — the accounts are the Owner's — and *The Owner
     will review today's opening amounts*; they confirm with **Open the boutique** (or *Open the store again*). Nothing
     for them to type.
3. **One request** records the opening and its money together. Refused or unanswered, the sheet stays open with what was
   entered and says why; the store stays closed. The same request again keeps its key, so a retry or a second tap is
   answered with the first.

An **older server** (no `openingMoney` in the day's view) is never sent a step it would refuse: the opening goes as it
always did.

## 4. The server (D101)

### 4.1 The counter waits for an opening

`assertCounterOpen` / `assertCounterOpenTx` refuse a **sale, a receipt and a later payment** with 409 `store_closed`
while the branch's current business day is **closed** (`closedReason: 'closed'`, as before) **or not yet opened**
(`closedReason: 'not_opened'`: no `opened`, `reopened` or `auto_reopened` event for that day). For every client, older
app builds included; nothing is written. The field is named `closedReason` — not `reason`, which the global error
filter deliberately never passes (free text on other mutations) — and is on the filter's allowlist.

`GET /closings/business-day` adds `door` (`never_opened` · `open` · `closed`) and `opening` (the day's opening state);
the phone's gate covers Sell and Receive for `never_opened` exactly as for a closed day, offering the opening to
whoever counts.

### 4.2 Recording an opening

`POST /closings/open` and `POST /closings/reopen` accept `openingMoney: { clientUuid, decision?, cashAmount? }`.

| Who | Sends | Recorded |
|---|---|---|
| The Owner (`money.anchor.record`) | `decision: 'keep'` | the drawer as Money shows it; unknown stays unknown |
| The Owner | `decision: 'set', cashAmount ≥ 0` (≤ 2 decimals) | that amount, true from this instant |
| Anybody else who may open (`closing.count` for an opening; `closing.perform` or a closing delegate for a reopen) | `clientUuid` only | `carried` — the drawer as tracked; **awaiting the Owner's review** |

Refusals, each leaving the day exactly as it was (no event, no decision): no decision from the Owner → 400
`opening_amounts_required` (nothing is chosen for them — an older Owner phone must be updated); a non-Owner sending
`set` → 403 `opening_amounts_owner_only`; an invalid amount → 400 `amount_invalid`; an amount with keep → 400
`amount_not_expected`. **The opening event, the decision (with its values, the person, the instant, every method as
shown and the total) and their audit rows are written in one transaction**: if any part fails, nothing is written and
the store stays closed — for a new business day too.

**Retries are safe.** The key is bound to a sha256 of the request (date, mode, decision, amount); the same key and
request answer with the day as recorded; the same key with another request is 409 `idempotency_conflict`. A second
opening of an open day is 409 `open_already_open`. Two identical requests at once: one records, the other answers with
it. An opening and a reopen share one kind, so an older phone's reopen of a day nobody opened (answered as the opening,
below) finds its own retry.

**Older phones.** Their *Open store now* is a reopen; on a current day that is neither closed nor opened it is answered
as the opening — carried for a staff member; refused with `opening_amounts_required` for the Owner, whose phone must be
updated. Their sales on an unopened day are refused like any other.

### 4.3 The Owner's review

`POST /closings/opening/review` (`money.anchor.record`): `{ clientUuid, decision: 'keep' | 'set', cashAmount? }` on
today's opening when it is `carried` and not yet reviewed (else 409 `no_opening_to_review`). The review is **its own
row** — the opening is never rewritten (append-only) — true from **its own instant**: a sale made between the opening
and the review is never added twice. Until then the day and Money say *awaiting the Owner's review*, never "checked".

## 5. The accounting (D102)

**An opening amount is a position, never a sale or an expense.** It appears in no sales total, no expense, no profit
figure and no history row; it changes only what the drawer is expected to hold.

**The anchor is the confirmation instant.** A decision records `cash_amount` (X), its instant `at` (T) and `cash_day_net`
— the day's recorded net cash movement at T (N). From then on:

- **The day's expected cash** (Money, the Daily closing, the close) = opening balance + the day's net + the set
  adjustment, where **set adjustment = X − N − opening balance**. It comes to X plus what the day recorded **after** T:
  a sale recorded before the opening is never counted twice, and nothing is backdated.
- **A later day's opening balance** = X − N + the recorded net of every day from the decision's day to the day before.
- **The chain starts from the latest anchor**: a locked close whose drawer was counted (its count instant, as before) or
  a decision with an amount — whichever is later.
- **Keep and carried record the amount Money showed** (the count of a day closed with its drawer counted, else the
  day's expected figure); an unknown drawer records no amount and anchors nothing. **Set** records the Owner's amount.
- **The close checks the same equation.** Its independent cross-check now carries the set adjustment as its own term
  (`reconciliation.spec.ts` pins every term); without it a day whose drawer the Owner set could not be closed
  (found by the verification below).

**Scope.** Cash is a shop's (branch). Receiving accounts are the company's: a shop's opening never sets one — its
decision only records what each showed. Changing an account is the Owner's company-wide `POST /money/anchors`, whose
figure every shop then sees.

### Worked examples (all verified over HTTP, §7)

| Situation | Result |
|---|---|
| The Owner sets 3 400 in cash; the accounts hold 2 600 and 1 000 | Money: cash 3 400, total **7 000**; the Daily closing expects 3 400 |
| Then a 1 500 cash sale and a 500 Bankily sale | cash 4 900, Bankily 3 100, total 9 000; both screens agree |
| The next day, **Keep**, no movement | 4 900 and 9 000 before and after — nothing changes |
| **All zero**: a reopen setting cash 0, and the company action setting each account to 0 | total 0; a 100 cash sale after → 100 |
| **Partial**: cash set, an account unknown | the cash as set; no total while the account is unknown |
| Keep on an unknown drawer | still Unknown — no total, no anchor |
| A staff member opens (carried 250); a 150 sale; the Owner reviews and sets 280 | 280 from the review — the 150 before it not added again; a later 120 → 400 |
| **Rollout**: a 700 cash sale recorded before any opening; the Owner then sets 3 400 | 3 400 (the 700 kept in the day's history, not added again); a later 200 → 3 600 |
| The Warehouse opens with 0 | its drawer 0; the Main Store's cash and every account unchanged |

## 6. Data — migration 0083 (additive)

One table, `opening_decisions`: id, company, branch, business date, `kind` (`opening` · `owner_review`), `decision`
(`keep` · `set` · `carried`), the opening event it was recorded with, the opening a review answers (unique — one review
per opening), the instant, whether the drawer was known, the tracked figure, the amount (NULL when unknown), the day's
net at the instant, every method as shown (JSON), the total (NULL when any method was unknown), the person, the request
key (unique per company) and its fingerprint. CHECKs: amount ≥ 0; *set* has an amount; a review has what it reviews and
is never *carried*. Append-only for the application account (update and delete triggers), like every financial record.
The reverse SQL is in the migration's comment. No existing row changes.

## 7. Verification

- **HTTP proof on a disposable copy** (`prisma_verify_home`, restored from a fresh read-only dump of live, 19:19Z; the
  built API on a fake clock, 30 Sep → 6 Oct): **58 of 58 facts** — every row of §5's table; the refusals leaving the
  store closed (no event, no decision, a sale refused `not_opened`); keep/set/carried recorded with the opening event,
  actor and instant; the same request twice (one decision, one opening), the same key with another amount, a second
  opening; the 06:00 choice (the manager's early start refused; the Owner's start of 3 Oct with 250, events
  `day_started_early, opened`; the Warehouse's *continue*); the Employee's carried opening, its retry, their refused
  review, the Owner's review and its retry, a second review refused; a Store Manager refused a reopen until named a
  closing delegate, then reopening as carried; older phones (the Owner refused, staff carried); the rollout day; the
  counted closes after a set. **Live unchanged** throughout (sales, payments, expenses, closing events, closings,
  anchors and the migration level compared before and after).
- **Web renders** (the web export against the same kind of copy, headless Chrome, read from the page — text, cut
  labels, every money figure, right to left): **55 of 56 — 48 of 48 page checks, 7 of 8 facts** (the eighth expected a total of 250 where the app rightly recorded 3 850: 250 in cash plus the accounts’ 2 600 and 1 000); 284 money figures scanned, none cut; no label cut — the opening step (Owner and staff), Money's card (known,
  unknown, awaiting review, somebody other than the Owner, dark), *Company account amounts* and setting an account from
  it, the Owner's review, Home's *Review closing*, the before-06:00 day choice followed by the amounts; EN/FR/AR, 320 and
  393 pt, ordinary and 1.3× text. Web renders, not the phone.
- **Found and fixed by the verification:**
  1. the refusal's reason never reached the phone — the error filter drops `reason` by design — now `closedReason`,
     allowlisted and pinned by a filter test (HTTP proof);
  2. a day whose drawer was set could not be closed (`report_integrity`: the close's independent cross-check lacked the
     set adjustment) — now a declared term of the equation (HTTP proof);
  3. **before 06:00 the Owner could not reach the amounts**: a sheet reports its close when its exit animation ends, and
     the day sheet's late close reset the flow after *Next* had opened the amounts — each sheet now returns the flow to
     idle only while its own step is current; the same late close took the *Company account amounts* list away for good
     once an account was chosen — it now steps aside and comes back (renders);
  4. the French row title « Montants des comptes de l’entreprise » needed three lines at 320 pt with 1.3× text where
     the shared row allows two — now « Comptes de l’entreprise » (renders);
  5. an account's name in the company sheet ended in "…" in Arabic at 320 pt with 1.3× text — `ListRow` takes
     `titleLines` (two by default; the sheet lets the name wrap whole) (renders).
- **Gates:** backend 168 suites / 3 049 tests, `tsc` clean; mobile 83 pure suites, `tsc` clean, lint 0 errors (no new
  warning), i18n parity 3 250 × 3; each mobile commit alone from a clean export equals the known baseline.

## 8. Rollout

1. A verified backup of live (`docs/22`), recorded in the handoff; then `prisma migrate deploy` (0083). The running API
   is unaffected (an additive table).
2. **The new rules start when the API is restarted on the new build.** From then on a day must be opened before it
   takes a sale, a receipt or a later payment. A day already opened (an `opened` or `reopened` event) keeps selling; a
   day that was started early or never opened waits for its opening.
3. **Transactions recorded before the opening** stay where they are, in the day's history and profit. An amount the
   Owner sets at the opening is anchored at its confirmation instant; only movements after it count.
4. The phone must run the new build (Metro): an older Owner phone cannot open (it sends no decision).

## 9. What the phone must check — `docs/24` §50

The opening sheet at the phone's own largest text (the radios, the cash field above the keyboard, *Set to 0*, the
total); a refusal keeping the typed amount; a double tap recording one opening; the staff member's carried opening and
the Owner's review from Money; Money's card with an unknown method and with every method known; *Company account
amounts*; Home's *Review closing*; the before-06:00 choice followed by the amounts; Arabic right to left throughout.

## 10. The iPhone before 06:00 (29 Sep) — one modal at a time; the early start inside the opening

**Reported** at 01:09 on the Owner's iPhone (Test Store): choosing either day and tapping *Suivant* closed the choice
sheet, showed no amounts, and left *Open* doing nothing until the screen changed. **Live, read only:** the 28th was not
closed by anybody — the Owner started it early at 05:25:40Z on the 28th under the build before 0083 (no opening
recorded then), there is no closing row for it and nothing was recorded after; under the new rule it is a day never
opened, so the opening with its day choice was the right offer. The failed attempt wrote nothing (no decision, no event,
no audit row).

**Cause.** `BottomSheet` unmounted its native `Modal` and reported its close in the same moment, so the flow presented the
amounts sheet while iOS was still dismissing the day sheet — and iOS does not present a modal during another's
dismissal. The web has no native modals, which is why the renders of §7 passed. **Fix (mobile `3bd2937`):**

- `BottomSheet` keeps its `Modal` rendered, hidden, until UIKit reports the dismissal (`onDismiss`; a short wait stands
  in for a modal never presented), then calls `onDismissed`; on Android and the web at once. A sheet asked to open
  while still leaving opens once gone.
- The opening flow shows the amounts only from the day sheet's `onDismissed`. An older server's reopen dialog no longer
  follows the day sheet. Before 06:00 a staff member's notice of which day runs is shown **in** the amounts sheet, not
  in a dialog before it. *Company account amounts* sequences its list and its amount sheet the same way.
- **A failure keeps everything:** refused or unanswered, and also when the sheet is closed and opened again, the chosen
  day, the amounts and the request's key stay; only a success, or a fresh start after none failed, begins from nothing.

**The early start is part of the opening (backend `285ba78`, D103).** Before, the early start was written on its own and
then the opening in a second transaction, so a refused or failed amounts step could move the business day with nothing
opened. Now the new date is computed, not read back, and the early start, the opening, the decision and their audit rows
are one transaction.

**Verified.** HTTP on a disposable copy: **10 of 10** — a refused amount, then a save forced to fail inside the
transaction (a trigger on the copy) for *start early* and for *continue*: the business day, the events, the decision and
the audit untouched; the same request then recorded once. Web renders **14 of 14** — both choices reach the amounts
(looking records nothing), the staff notice in the sheet, the company round trip, the early start confirmed. Suites:
backend 168 / 3 052; mobile 83. **The iOS part is the phone's to prove** (`docs/24` §50 AA12a).
