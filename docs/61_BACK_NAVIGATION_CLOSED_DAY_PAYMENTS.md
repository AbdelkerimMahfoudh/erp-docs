# 61 — Back navigation, closed-day debt payments, the 51/52 check, 0082 verified (2026-09-27; correction pass 2026-09-28)

The user's brief of 2026-09-27 (21:1xZ), after `docs/60`: one focused navigation and verification pass, worked inline.
Five parts only — a visible back arrow on every authenticated child screen; a later payment on a debt refused while the
business day is closed; the one failed page check of `docs/60` named and resolved; migration 0082 verified with
authentication; the Owner's phone review recorded. **No redesign** of Home, Money, the Daily closing, Sell, Receive,
stock selection or the tab bar; no refund, scanner/OCR or other milestone. Decisions D93 (back navigation) and D94 (a
later payment waits for the store). Recorded in `docs/21`, `docs/04` rule 25 and
`docs/24` §47 (status) and §48 (the next checks). **The correction pass of 2026-09-28** (§8–§11: money never cut, a
payment in its sale's minute, the four routes without an arrow, a matrix at 192 of 192) is D95–D97 and `docs/24` §49.

---

## 1. Back navigation

### 1.1 The rule, as built

| | |
|---|---|
| **Which screens** | Every authenticated child route. The five parent tabs (Home, Partners, Money, Stock, More) have none. |
| **One map** | `lib/navigation/back.ts`: `BACK_PARENTS` names each child route's logical parent; `NO_BACK` names every route without an arrow and why. A route is in exactly one of them — a test fails otherwise. |
| **The header** | The root stack shows the header on every route in `BACK_PARENTS`, **in every state** (loading and errors included), so the arrow is there before the screen has its data. A screen names its own title. |
| **With history** | On the phone the native back button stays, and with it the **native swipe** (`gestureEnabled: true`, iOS keeping its own push transition, which carries the interactive pop). The arrow and the swipe are then the same pop of the same stack. |
| **Without history** | A notification opened from outside, a deep link (`retailerp://…`), a restored session, a cold start or a replaced route: our arrow (`components/navigation/HeaderBack.tsx`) replaces the screen with its **logical parent** from the map — never nothing, never closing the app, never a screen from another branch or company (the parent is a route of the same signed-in branch; the server scopes what it shows). A parent that needs an id it does not have falls back to its own parent (`/sales/pay/[id]` → `/sales/{id}`, or `/sales` with no id). |
| **On the web** | Our arrow always (the web has no swipe); it goes back when there is history and to the parent when there is none. |
| **The arrow** | `ArrowLeft` in English and French, `ArrowRight` in Arabic; the shared `IconButton` (48 × 48 pt target, the app's colours); labelled "Back" / « Retour » / «رجوع» for screen readers; iOS shows the arrow alone (`headerBackButtonDisplayMode: 'minimal'`), never "‹ (tabs)". |
| **One arrow only** | A screen never draws a second: the four flows with their own arrow (below) replace the header's; no screen sets `headerBackVisible: false` or `headerLeft` except those, and none hides the header. |
| **Sheets, dialogs, camera** | Keep their Close / Cancel — unchanged. |
| **Multi-step flows** | Their own arrow steps back **inside** the flow first, then leaves by the same map: Quick sell (back to choosing, then out), Quick receive, Receive, and New expense's review step (back to the form; the form step has the shared arrow). |
| **Sell** | A hidden tab reached from Home, so it has no stack header: its title row carries the same arrow, acting on the parent stack — the step the swipe takes. The closed-store panel that stands in for Sell carries it too. |

### 1.2 The audit

**72 authenticated screens** (the signed-out `(auth)` group — login, register, verify — is outside the brief):
**63 children with an arrow** — 58 on the shared header, Sell in its title row, 4 flows with their own — and **9 without**,
each for a stated reason. Every one of the 72 is in the web export. No screen disables the swipe.

| Parent | Child route → no-history fallback |
|---|---|
| **Home** `/` | `/sell` → `/` · `/quick-sell` → `/` (own arrow) · `/quick-receive` → `/` (own) · `/receive` → `/` (own) · `/receive/pick` → `/receive` · `/receive/file` → `/receive` · `/partners/ranking` → `/` |
| **Money** `/money-hub` | `/money` (Results) · `/sales/period` · `/expenses` · `/closing` · `/loans` · `/outstanding` → `/money-hub` · `/expenses/[id]`, `/expenses/new` (own on review) → `/expenses` · `/closing/sources`, `/discrepancies` → `/closing` · `/discrepancies/[id]` → `/discrepancies` · `/loans/[id]`, `/loans/new` → `/loans` |
| **Stock** `/inventory` | `/transfers` · `/unit/[identifier]` · `/unit/edit` · `/pricing/unit` · `/pricing/history` → `/inventory` · `/transfers/[id]`, `/transfers/new` → `/transfers` |
| **Partners** `/partners` | `/partners/[id]`, `/consignments` → `/partners` · `/consignments/[id]`, `/consignments/new` → `/consignments` |
| **More** `/more` | `/sales` · `/returns` · `/approvals` · `/catalog` · `/imports` · `/analytics` · `/goals` · `/team` · `/subscription` · `/settings` · `/appearance` · `/devices` · `/sync` · `/notifications` · `/hub/[id]` · `/dev/gallery` → `/more` · `/sales/[id]` → `/sales` · `/sales/pay/[id]` → `/sales/{id}` · `/returns/[id]`, `/returns/new` → `/returns` · `/approvals/[id]` → `/approvals` · `/catalog/[id]`, `/catalog/new`, `/catalog/edit`, `/catalog/categories` → `/catalog` · `/imports/[id]` → `/imports` · `/goals/new` → `/goals` · `/alerts` → `/analytics` |
| **Platform** (its own identity) | `/platform/[id]`, `/platform/new`, `/platform/audit` → `/platform` · `/platform/sign-in` → `/login` · *since the correction pass (§10):* `/platform` → `/login` |
| **No arrow** | the five tabs; `/platform` (the platform identity's home); `/select-branch` (an entry flow reached by replacement — the choice replaces the whole app, and Sign out is offered); `/subscription-blocked` (shown instead of the app); `/stores` (a legacy link that replaces itself with Partners). *Reviewed in the correction pass (§10): `/platform` now has the arrow; `/stores` is an invisible redirect; branch choice and the access refusal are authentication roots.* |

**Every row alike:** with history, back is a pop (the native arrow and the swipe on the phone; our arrow on the web); in
English and French the arrow points left at the left edge, in Arabic right at the right edge. **Notifications** are
in-app and open their target with a push, so back returns to Notifications; their targets are `/closing`,
`/analytics`, `/approvals/[id]`, `/transfers/[id]`, `/catalog/[id]` and `/returns/[id]`, each in the map. **A deep link**
to any of these opens with no history and falls back as listed.

### 1.3 What fails a future screen

`lib/navigation/back.test.ts` (10 tests) reads the `app/` folder: a new route file that is in neither map, a map entry
with no screen, a parent that is not a screen or whose chain does not end at a tab (or the platform home, or sign-in),
a screen that sets `gestureEnabled: false`, hides the header, or draws its own arrow without being one of the four
approved flows (which must use the direction-aware arrow, the translated label and the shared fallback), or a
screen that leaves with a bare `router.back()` (§1.5) — each fails the suite. The root layout's header rule, the
arrow's 48-point target and the fallback targets are pinned.

### 1.4 The swipe

Proven in code and tests: the swipe is enabled on every screen, the native back button is kept wherever there is
history, and iOS keeps the transition that carries its interactive pop. **Not provable on the web** (there is no swipe
there): that the swipe and the arrow land on the same screen on a real iPhone and Android is `docs/24` §48.

### 1.5 Every other way out follows the same rule

The audit found thirteen bare `router.back()` calls on ten authenticated screens — and some were back controls: the
receiving file's **Back** button when its file is gone, **Cancel** on New transfer and New return, the receiving
file's **Discard**, and the step back after a save (an approval cancelled, a product or unit edited, a discrepancy
resolved, a goal or a later payment saved). Opened with no history, each did nothing. All now leave through the same
rule (`useLeave`): back with history, the logical parent without — a later payment saved from a deep link lands on its
sale. A test refuses any new bare `router.back()`; the one guarded step back with its own way out (Catalogue → New
product returns to the delivery it came from, else Receive) is allowed. The signed-out register screen keeps its own.

## 2. A later payment on a debt while the day is closed

**The last automatic reopen is gone.** `POST /sales/{id}/payments` while the branch's current business day is closed
answers **409 `store_closed`** — "The store is closed for business day {date}. Nothing was recorded: the Owner or a
named delegate must open the store first." — with the day as its own field (`businessDate`). Nothing is written: no
payment, no change to what is owed, no money movement, no reopen and no reopen event. It is decided twice: before any
work (after the replay check), and again inside the transaction on the locked closing row, so a close committed
meanwhile is seen. `autoReopenTx` and everything that served it were removed; older `auto_reopened` events still read
"Reopened by a payment" in the history. A payment back-dated into an earlier closed day is refused as before.

**Idempotency.** A refused request stores nothing under its key. The same key sent again while the day is still closed
is refused again — never a replayed success. After the store is opened, the same key records the payment for real,
once; a further retry replays that one payment.

**Every client.** The refusal is the server's: an older app build, or a raw call, gets the same 409 and writes nothing.
Sales and receipts were already refused the same way (`docs/60` D91); the body now names the day for all three.

**On the phone** (Record payment, `app/sales/pay/[id].tsx`): the form stays exactly as typed. A notice says
**"The store is closed"** — "Nothing was recorded. Your payment stays here, to send once the store is open." Beneath it,
for the Owner or a named delegate (`closing.perform`), **Open store now** — the existing reopen, with the before-06:00
choice unchanged — and once the store is open the notice clears and the person sends the same payment again, on purpose,
under the same key. Anyone else reads "The business day ({date}) is closed. Only the Owner or a named delegate can open
the store." — no dead button. The close popup now says "After closing, Sell, Receive and payments on debts wait until
the Owner or a named delegate opens the store again." (EN/FR/AR.)

## 3. The 51/52 result of `docs/60`

**The failed check.** `split-partial-form-en` — on Quick sell's payment sheet, four split parts typed 200 each, then
900 + 200 + 200 + 200 against a 1 000 sale; the assertion **`OVER:yes`** expected "The parts add up to 1 500 MRU, more
than the 1 000 MRU due." It found no such line.

**Root cause: the harness, not the app.** The harness typed into "the last four visible fields without a placeholder".
Those were the four parts only until the first part fell below the total — at that moment the sheet asks who owes the
rest and adds the customer's name and phone fields at the end of the page. From then on "the last four" were the third
and fourth parts plus the name and the phone: the second amount went into the fourth part, the third and fourth into
the name and the phone. The page dump shows it — the first read-back `+200+200+200` (the third part empty, then the
fourth part, the name and the phone at 200), and at the end "Remaining to pay 200 MRU … Only 800 MRU is recorded as received": in the second round the 900
landed in a part, the total went over, the debtor fields left, the list shifted back, and the next 200 overwrote the
900. The app answered every input correctly; the over-total state was simply never typed. The first round's
`VALUES:200+200+200+200` expectation had passed only because the second round's read-back happened to match it.

**What changed.** Each part's field is now found through its own row (the row's Remove button), never by position;
the amounts are typed as a keyboard types them (Chrome's `Input.insertText` into the focused, selected field); each
read-back has its own tag and the field count. The same page now reads `PARTS-1:200+200+200+200 FIELDS:4` (debtor
asked, *Review sale* held), the fifth method refused, `PARTS-2:900+200+200+200 FIELDS:4`, **`OVER:yes`**, and the
button (*Complete sale* once nothing is owed) disabled.

**Three more harness faults found and fixed on the way** — none of them the app's:
- **A warned sale is not a sale.** The server answers a sale that needs an acknowledgement with **201**
  `warnings_pending` and writes nothing; the harness acknowledged only a 200. So `docs/60`'s "after Open store now, the
  same sale goes through (201)" was a warning, not a sale — **that line of `docs/60` §3 was not proven**. The harness
  now acknowledges the warning as the app does and counts a sale only by its id and its row: after Open store now the
  same sale is **recorded — invoice 00011**, the price warning (`magnitude.sale_price`) acknowledged.
- **The page's clock.** The later-payment form defaults its date and time to the phone's clock; the browser ran at the
  real evening while the server ran on a fixed noon, so the second submission was refused as "in the future". Checks
  that submit such a form now give the page the server's clock, and wait until the sale is a minute old (below).
- **Text through the command line.** An account renamed with an en dash through the SQL client's argument arrived as
  "?"; statements now go through its input as UTF-8.

**The green count.** The full matrix, rerun on a fresh copy of live (22:01Z) with the final build: **90 checks, 88
clean — 40 of 42 page checks and 48 of 48 server facts.** `split-partial-form-en` is green on all its assertions
(`OVER:yes` among them). The two page checks that are not green are one finding, not a harness fault: the large-text
back checks on Results and Expenses pass every header assertion (the arrow there, 48 × 48, pointing left, overlapped by
nothing) but also read a money figure cut short at 320 pt with text at 1.3× (§6). They stay counted as failures.

## 4. Migration 0082 and tracked money, verified

### 4.1 Live — read-only

No Owner credential may be typed into live and none exists for it in the tooling, so **no authenticated request was
made to live**. What was read, without writing anything:

- `prisma migrate status`: 81 migrations, the database schema up to date; `0082_money_anchors` finished 19:56:49Z.
- Both triggers present, word for word as the migration wrote them: `money_anchors_block_update` and
  `money_anchors_block_delete`, `BEFORE`, raising SQLSTATE 45000 when `USER()` is the app account.
- `money.anchor.record` granted to the `owner` role of each of the two companies and to no other role.
- The anchors: **two**, both the Test Store's, both recorded from the Owner's phone — **Bankily 2 000.00** at 21:11:13Z
  and **Owner1 10 000.00** (a switched-off account) at 21:11:21Z, business date 27 Sep, tracked-before unknown — each
  with its `MoneyAnchor create` audit row. The live API's own log shows the phone's authenticated `POST /money/anchors`
  (201, twice, from the Expo client on the Test Store's branch) and the Money overview read back (200) at those
  minutes.
- Nothing was created, replaced or deleted.

### 4.2 A copy — the whole lifecycle through authenticated HTTP

A fresh read-only dump of live (22:01Z, the two anchors in it) restored as `prisma_verify_home`, the built API on a fixed
clock, real logins with throwaway credentials — dropped afterwards.

| # | Checked | Result |
|---|---|---|
| 1 | No anchor → unknown | Demo on the 28th: Cash unknown (`no_counted_close`), Masrvi and Bankily unknown (`no_anchor`), total `null` |
| 2 | The Owner sets a starting amount | 0 for three accounts: 201, tracked before `null`; a replay answers the same anchor; the same key with another amount 409; −5 and 1.234 → 400 `amount_invalid` |
| 3 | Anchor + later movements | 23:00 on the 29th: Cash 3 400 + Bankily 2 000 + Masrvi 1 600 + Second Shop 0 = **7 000** |
| 4 | Midnight does not reset | 07:00 on the 30th, nothing moved: **still 7 000**, recorded today 0 |
| 5 | A correction counted once | The Owner re-reads Bankily at **700** (tracked before 2 700, difference −2 000) and Masrvi at **4 200** (before 2 200, +2 000); then the 2 000 of the 29th is moved from Bankily to Masrvi (request 201, approval 201; legs out 2 000 Bankily, in 2 000 Masrvi): **Bankily 700, Masrvi 4 200, total 9 950 — unchanged**. The anchors already held the truth; the move is not applied again |
| 6 | Switched off and renamed | Second Shop renamed and deactivated: still listed under its new name, `isActive` false, **500 unchanged**, the total unchanged |
| 7 | Not the Owner | A Store Manager's anchor: **403**; the manager's overview has the drawer only, no account figures, no total |
| 8 | Append-only | The anchor count only grows (Demo 4, then 6 after the re-reads; none changed). **As the app's own database user** (§4.3): UPDATE and DELETE refused with SQLSTATE 45000 |
| 9 | Company and branch | The Warehouse (same company) lists the same accounts and positions; its own drawer unknown, so no total. The Test Store's Owner sees only its own accounts — **Bankily 2 000 and Owner1 10 000, the live anchors** — anchoring a Demo account is 404 `account_not_found`; Demo's Owner reading the Test Store is refused (403) |
| 10 | An untracked active method hides the total | A new account (Sedad) appears: total `null`, Sedad named as unknown, the other rows kept |
| 11 | Its anchor brings the total back | The Owner sets Sedad at 250 from Money: **9 950** |
| 12 | Cash needs a counted close | The drawer is known only from the 28th's close counted at 0 (locked, 0.00); before it, unknown |

**The body the phone reads.** For the Owner, the Warehouse, the other company and a manager alike, `trackedMoney` has
exactly the fields of the phone's `TrackedMoney` (`lib/money-overview.ts`) — `accountsVisible, asOf, basis,
branchCount, businessDate, methods, total, unknownKeys` — and every method exactly `TrackedMethod`'s, with their
types and allowed values (`channel`, `scope`, `unknownReason`, `anchor.source`), a known method always with a figure and
an unknown one never. Nothing is compensated in the app.

### 4.3 The append-only rule, as the app's database user

The runtime user may reach only the live database and two named staging databases. The copy after the lifecycle was
restored into the disposable `prisma_staging_cleaninstall_proof` (no grant changed), and there, **as the app user**:
the table held 8 anchors (sum 17 150.00); `UPDATE … SET amount = amount + 1` → **ERROR 1644 (45000)**
"money_anchors is append-only: record a new anchor instead"; `DELETE` → **ERROR 1644 (45000)** "… an anchor is never
deleted"; an `INSERT` was accepted (the app appends); afterwards the 8 original rows and their sum were unchanged.
The database was dropped afterwards.

## 5. The phone review — user-reported

**The Owner reports that the `docs/24` §47 review (X1–X15) was completed on the phone with no new defect.** This is the
user's report, not an automated result; no individual observation was captured beyond that statement, and none is
recorded here. The next checks are `docs/24` §48.

## 6. Found, not fixed — the large money figures at 320 pt *(fixed in the correction pass, §8)*

The large-text back checks read the whole page, and on two Money screens found a figure cut short at **320 pt with
text at 1.3×**: Results' **Profit "+38 350 MRU"** needs 269 px and has 254; Expenses' **Cash in store now**
(26 000 MRU when measured) needs 240 px and has 198. At normal text, and at 393 pt with 1.3×, both are whole. It is the shared
`MoneyValue`, whose display size keeps one line and deliberately never shrinks (`adjustsFontSizeToFit={false}`), and
the app sets no cap on the system's text size — so a phone this narrow with large text would show an ellipsis there.
Not caused by this pass (both screens had these headers before); changing the shared figure is outside this brief and
reverses a recorded choice, so it is the user's call. The two checks are counted as failures.

**And a small edge in the app, found by the same check.** The form's time is to the minute (15:10), and the server
refuses a payment earlier than its sale. A payment recorded in the **same minute** as the sale it pays is therefore
refused — "A payment cannot be earlier than the sale it pays for" — until the next minute. Rare at a counter (a debt
paid within a minute of the sale), harmless (nothing is written, the form stays), and not changed here. *(Fixed in the
correction pass, §9.)*

## 7. Verification and commits

**Gates.** Backend: `tsc` clean; **165 suites / 2 961 tests**, the focused closed-day and permission specs 84 of 84
(the payment refusal's own spec, the sale and receipt refusals, the role-matrix drift and the permission catalogue);
`prisma validate`; `prisma migrate status` on live up to date (81); `nest build`. Mobile: `tsc` clean; **81 pure
suites, 1 249 cases**, all passing; `expo lint` 0 errors, 31 warnings (the baseline); translation parity **3 222** keys
in EN, FR and AR, same order; the web export builds with all 72 screens; the Android bundle builds through Metro.
**Expo Doctor: 20 of 21 checks** — the miss is six Expo packages a patch behind SDK 57's latest (`expo` 57.0.22 →
~57.0.25, `expo-router` 57.0.21 → ~57.0.23, `expo-constants`, `expo-image-picker`, `expo-linking`,
`expo-sharing`); no dependency changed in this pass, and upgrading is outside it (with the known `npm install`
postinstall blocker). Each commit checked alone from a clean export: backend `eea15e3` `tsc` clean and 681
closing/sales/purchasing/rbac tests; mobile `fd57d26` and `6edad6b` the same as the pre-pass `6b6b651` (the export
lacks the generated CSS declaration and three suites read untracked files, at every commit alike) plus the new
navigation suite.

**Back, in numbers.** Opened with no history (EN, 393 pt): Daily closing → Money, Results → Money, Expenses → Money,
the period's sales → Money, Settings → More, Notifications → More, Transfers → Stock, Quick sell → Home, Sell → Home,
Record payment → its sale — each with the arrow at the top left, pointing left, 48 × 48, overlapping nothing, the tap
landing on the parent. Arabic at 320 pt (Daily closing, Settings, Quick sell, Sell): the arrow at the right, pointing
right, the same landings. 320 × 568 with text 1.3× (Results, Daily closing, Expenses, Settings): the arrow whole and
clear of the title. With history, Home → Daily closing → back lands on Home. The Money tab has no arrow. The receiving
file's in-page Back, opened with no file and no history, lands on Receive.

**The payment, in numbers** (Test Store, the 27th). A sale of 20 000 with 5 000 paid; the day closed. An older client's
payment → 409 `store_closed`, `businessDate` 2026-09-27; payments 1 → 1, paid 5 000 → 5 000, reopen events 5 → 5, the
day still locked. The same key again → 409 again. Opened (201); the same key → 201, payments 2, paid 6 000; once more →
the replay, still 2 and 6 000. On the page: 2 000 typed, *Record payment* → "The store is closed — Nothing was
recorded…", *Open store now* enabled, the 2 000 still typed; opened from the page → the notice gone, the 2 000 kept;
sent → payments 3, paid 8 000, and the screen, opened with no history, landed on its sale. A Store Manager on Demo's
closed 28th: the reopen 403; the page kept the 300 typed, said only the Owner or a named delegate can open the store,
showed no *Open store now*; nothing written.

**Live.** Unchanged by this pass: 17 sales, 7 expenses, 13 closing events, 3 closing rows, 17 payments, 2 anchors,
910 audit rows (read at 22:01Z and again at 23:3xZ). The machine restarted at 22:30Z (it stopped a matrix run, the API
and Metro); the API on 3010 was restarted on the new build (`eea15e3`, pid 13032) and Metro on 8081 (pid 1684) serves
`6edad6b`; no migration in this pass. `prisma_verify_home` and `prisma_staging_cleaninstall_proof` dropped; 3012,
19012 and 9334 free.

**Commits.** Backend `eea15e3`; mobile `fd57d26` (back navigation) and `6edad6b` (the refused payment's form); docs
last.

## 8. Money is never cut (the correction pass, 2026-09-28)

The user's brief of 2026-09-28 (00:0xZ): a monetary amount always shows every digit, its sign, its decimals and the
whole `MRU`, and nothing ends in "…". Decision D95 in `docs/21`.

**The figure itself — `MoneyValue`, the one component every amount goes through.** It no longer limits its lines.
Its box is never wider than the space it is given, and it fits the width it has, in this order (`lib/money-fit.ts`,
pure and tested):

1. **one line, full size**;
2. **one line, a little smaller** — down to the app's established floor for a fitted figure (`StatTile`'s
   `minimumFontScale`, 0.7) and never below body size (15 pt): a display figure may go to 70 %, a large one to 70 %,
   a row figure to body size, a small one not at all;
3. **`MRU` on the next line**, the number alone on the first — full size, or shrunk no further than that floor;
4. only then, **the number broken between whole digit groups** at the floor, `MRU` below.

The widths are measured on the device: the figure's own box, and the number and the whole figure at full size by an
invisible copy that is never shown, never read aloud and (on the web) out of the page's text. A figure at the end of
a row hugs its text, so once fitted its box only echoes the fit; the room then changes only when the box is clearly
larger (more space arrived) or clearly narrower (it was squeezed) — otherwise a row's figure would shrink itself
again on every layout. Screen readers read the whole figure once, however it is laid out.

**The rows — a label beside an amount (`lib/design/amount-row.ts`).** Side by side while the amount needs at most half
of the row; beyond that the amount moves **below** the label, on its own line with the row's full width, and the label
keeps the width to be read — never squeezed to a sliver or cut. Plain flex (`flexWrap` with the label's basis at half
the row), so it holds on the phone and the web without measuring. Used by the shared list row (`ListRow`: every list
of the app — Expenses, Sales, Outstanding, pickers) and by the statement lines of Results, the Daily closing and its
close popup.

**The other one-line paths an amount could reach**, found by a scan of every `formatMoney` in the app:

- *Sell*'s charge button carries the total in its label: a `Button` may now **wrap** (`wrap`), and this one does;
- *Sell*'s customer picker gave a balance to a one-line row as text: it now passes a `MoneyValue`
  (`SelectSheet`'s value may be one);
- the design gallery's demos passed money strings to a tile and rows: now `MoneyValue`.
- **seventeen standalone amounts drawn as plain text** — which cannot fit or break (their spaces do not break) and ran
  off the card with a long figure: a sale's lines, payments, subtotal, discount and total, the sales list, Outstanding,
  the receipt totals and their done screens, the file receipt's total, a staged item, the cart line, the sale-success
  figure, the refund payout, the returns breakdown and its investigation sheet, the gallery's specimen. Each is now a
  `MoneyValue` of the same size (display, title → large, heading → default, bold body → small; plain body and
  captions → small, the captions muted), and the rows holding them follow the half-row rule. *Found by the
  boundary checks on a sale at 320 pt with 1.3× text, where the figure was clipped by its card.*

A test (`lib/money-fit.test.ts`, 12) refuses any money figure in a line-limited text, a standalone amount drawn as
plain text, a money string handed to a row,
tile, picker or confirmation label, a button label with an amount that does not wrap, `MoneyValue` limiting its lines
or shrinking by itself, and pins the rows' rule; the fit's four steps, the floor and the boundary figures (0, −9 500,
27 648, 999 999, 12 345 678, +38 350, 1 234,50) are tested directly. Removing the charge button's `wrap` fails it.

## 9. A later payment in the same displayed minute as its sale (correction pass)

The phone names a minute (10:15, sent as 10:15:00); the sale is an instant inside one (10:15:47). The server had
refused the payment as earlier than the sale. **Now** (`resolvePaidAt`, D97): a payment whose minute is the sale's
minute is valid, and is **stored at the sale's own instant** — never before the sale, still in its minute, so still
10:15 wherever it is shown, and in the sale's business day (the day's boundaries, midnight and 06:00, fall on whole
minutes). The minute the person chose is kept in the audit (`paidAtRequested`) when it was lifted. **An earlier
minute is still refused** (`paid_at_before_sale`), to the millisecond: 10:14:59.999 against a sale at 10:15:00 is
refused. The comparison is on the instant, so the store's, the phone's and the server's time zones do not matter —
every zone is whole minutes (India +05:30 and Nepal +05:45 tested). Server-side, so an older app is covered.

The closed store is decided first: a same-minute payment on a closed day is refused with `store_closed` and writes
nothing; after *Open store now* the same key records it once; a retry replays it; the same key with another amount is
refused (`idempotency_key_reused`). Focused tests: `sale-payment-same-minute.spec.ts`, 14 — 9 fail without the change.

## 10. The four routes without an arrow — named and resolved (correction pass)

The pass before counted 72 authenticated screens: 63 with an arrow, 9 without — the five tabs and four others. Every
route file is now exactly one class (D96, `lib/navigation/back.ts`, `back.test.ts`):

| Route | Before | Now |
|---|---|---|
| **`/platform`** | "no arrow — the platform identity's home" | **Corrected.** A visible page (businesses, search, buttons): it gets the **shared arrow** — with history the same pop as the swipe, without history to the shop's sign-in it is entered from (`/login`). As the first screen of its own navigator it has no native back button, so ours is always drawn there (and on the platform sign-in). The platform session stays until *Sign out* |
| **`/stores`** | "a legacy link" | **Invisible redirect** — renders only `<Redirect href="/(tabs)/partners" />`: no page, no parameter, no data |
| **`/select-branch`** | "an entry flow" | **Authentication root**, outside the signed-in app: the branch is the last step of signing in; switching from More clears it first and the guard brings any other route back here, so an arrow would lead nowhere. Its way on: choose a branch, or *Sign out* (always shown); a failed list has *Try again* |
| **`/subscription-blocked`** | "shown instead of the app" | **Authentication root**: the server refuses the shop access and the guard returns here from anywhere. Its way on: *Check again*, *Sign out* |

**The whole map** — 76 route files: **5 parent tabs**; **64 children with the shared back arrow** (4 flows with their
own arrow inside, Sell in its title row); **0 modal or sheet routes** (sheets and dialogs are components with Close or
Cancel); **1 invisible redirect** (`/stores`) and **1 bootstrap splash** (`app/index.tsx`, a spinner); **5
authentication roots** outside the signed-in app (sign-in, register, verify, the branch choice, the access refusal).
None unclassified; none in two classes; every one in the web export.

**The redirect and the splash never strand anybody.** The sign-in guard's decision is now a pure function
(`lib/navigation/entry.ts`, 8 tests) used by `useAuth`: a session that expired → sign-in; a restore that failed (the
session is cleared) → sign-in; access refused → the refusal screen; no branch → the branch choice; the access check
itself failing → nobody shut out; `/stores` needs no parameter and its target is a real tab (pinned); every
combination of session, branch, access and route settles within two steps, never back where it started. On the web:
`/stores` lands on Partners with the tab bar as the Owner and as a Store Employee, and on sign-in when signed out or
with an expired token.

## 11. Correction pass — verification and commits

**The matrix** — a fresh read-only copy of live (22:01Z), the built API on a fixed clock, the final build: **192 of 192
clean — 53 of 53 server facts and 139 of 139 page checks.** They are:
- **the existing 90** (48 facts, 42 page checks), every one, now with the money scan on every page;
- **91 money boundary checks** — seven screens (Home, Money, Results, Expenses, the Daily closing, a sale, Record
  payment) with every money figure in their replies set to 0, −9 500, 27 648, 999 999 and 12 345 678 at 320 pt with
  1.3× text in English; the extreme and the negative in French and Arabic; 393 pt at 1× and 1.3×; dark at 320 pt —
  each page scrolled through with the scan at every step;
- **5 same-minute facts** over real HTTP; **6 route checks**.

**699 money figures scanned**, none ending in "…", incomplete, outside its box or its card, over other text, or below
body size. The scan was proven not blind: a figure pushed over its label is reported as an overlap, one forced to
"…" as an ellipsis and cut. Its false positives were removed on the way — a tab kept mounted behind the one on screen,
a dialog over the page, a folded panel, a list's rows under its footer: an overlap counts only where both texts are in
front on the screen. The payment page for a sale that owes nothing (0 or less) rightly shows "Nothing is owed on this
sale" — that, not a figure, is what its check expects.

**Found, not money — reported, not failed.** At 320 pt with 1.3× text the French tab label **"Partenaires"** and, in
Arabic, the Home header's branch name **"Main Store"** end in "…" (six of the boundary checks). Neither is an amount;
the tab bar and the header are outside this pass, which redesigns nothing. The user's call.

**The same minute, over real HTTP** (the Test Store, the 27th). A sale at 12:07:22.035 with 5 000 paid. The store
closed: the same-minute payment, and one for the minute before, refused with `store_closed` — payments 1 → 1, paid
5 000 → 5 000, no reopen. Opened: the minute before refused (400 `paid_at_before_sale`), nothing written; the
same-minute payment recorded (201) with `paid_at` 12:07:22.035 = `sold_at`, business day 27 Sep for both, the chosen
minute 12:07:00 audited, cash now 33 000 → 34 500 — once. The same key again returned the same payments; the same key
with 1 600 was refused (409 `idempotency_key_reused`); nothing more written.

**The routes, on the page.** `/stores` lands on Partners with the tab bar as the Owner and as a Store Employee, on
sign-in when signed out and with an expired token. The platform sign-in opened cold: the arrow at the left, 48 × 48,
to `/login`. A throwaway platform administrator on the copy only, signed in through the page: the overview shows the
arrow and, with no history, it goes to `/login`.

**Gates.** Backend: `tsc`; **166 suites / 2 975 tests**; the focused specs **140 of 140** (the same minute 14, the
payment rules, the closed-day payment, sales and receipts on a closed day, the permission drift and catalogue);
`prisma validate`; `prisma migrate status` on live up to date (81); `nest build`. Mobile: `tsc`; **83 suites /
1 270 cases**; `expo lint` 0 errors (31 warnings, the baseline); parity **3 222** × 3; the web export with all 76 route
files; the Android bundle through Metro; Expo Doctor 20/21 (the six SDK patch versions, as documented — no dependency
changed). Each commit alone from a clean export: backend `f66c1ff` `tsc` clean and 695 closing/sales/purchasing/rbac
tests; mobile `61f0f56` and `2476430` the same as the pre-pass baseline plus their new suite.

**Live.** This pass wrote nothing to live — read-only queries, `prisma migrate status` and the earlier read-only dump
only. Live moved by the user's hand during it: between 00:53Z and 01:05Z, from two iPhones on Expo Go (on the LAN,
…100.251 and …100.246) — scans, two products, a receipt, sale 00011 (3 500: 2 500 cash + 1 000 mobile), a loan created
and decided (the API's own log). Now 18 sales, 7 expenses, 13 closing events, 3 closing rows, 19 payments, 2 anchors,
919 audit rows. The copies were rebuilt per run and dropped; 3012, 19012 and 9334 are free. The API on 3010 was
restarted on `f66c1ff` (pid 6596); Metro on 8081 (pid 1684) serves `2476430`.

**Commits.** Backend `f66c1ff`; mobile `61f0f56` (money never cut) and `2476430` (routes); docs last.

## 12. Owed

- **The user's call:** the French tab label "Partenaires" and the Arabic Home header's branch name end in "…" at
  320 pt with 1.3× text (§11) — not money; the tab bar and the header are outside this pass.
- **The phone** (`docs/24` §48 and §49): the back arrow and the swipe landing on the same screen; the no-history
  fallback from a cold start and a deep link; the Arabic arrow; the swipe kept everywhere; the header at the largest
  text; the refused payment's form kept and sent after *Open store now*; the money figures at the phone's own largest
  text; a payment in its sale's minute; the platform overview's arrow.
