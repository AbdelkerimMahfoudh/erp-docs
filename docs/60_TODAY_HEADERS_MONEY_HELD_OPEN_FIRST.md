# 60 — Today first, the two closing headers, money held, the open-first rule, partial splits (2026-09-27)

The user's follow-up brief of 2026-09-27 (08:2xZ), after `docs/59`: the simple design; no pictures, scanner or refund
work; live records unchanged; Home, Money and the Daily closing stay **pending the phone review**. Recorded in
`docs/21` (D85–D92), `docs/04` rules 19, 25 and 26a, and `docs/24` §47. Corrects `docs/59` D76, D77, D78, D81 and D83.

---

## 1. What the audit found

| Area | Finding (evidence in the session log) |
|---|---|
| Home opened on 7 days | Home's period was component state hard-coded to `'week'` (`app/(tabs)/index.tsx`, since `40c73d0`); the shared period store started on `'month'`. Nothing was saved; the phone behaved as written. |
| "Only 4" on the phone | NativeWind's interop **drops a Pressable style given as a function** on native. The history header's purple, padding and height lived in `style={({ pressed }) => …}`, so on the phone only the white pill's purple digit was visible on the white card. The web takes another path, which is why every web check passed. Thirteen Pressables in the app used the same pattern — among them the stock picker's rows (D84), the before-06:00 choice sheet, the debtor picker and the money rows. |
| Money's top card | No method had a reliable position. Cash is anchored only by a **locked close whose drawer was counted**; every close on live so far is attested, reopened or never locked. Accounts had no opening anywhere (rule 26a: recorded movement, never a balance). The card of `docs/59` was the day's recorded movement, which restarts at 06:00. |
| The closed store | `POST /sales` and `POST /purchases` called `autoReopenTx`, which silently reopened a locked day (live: sale 00009 reopened the 26th at 05:08). The phone's lock covered only people with `closing.count` on a new build. |
| Splits | Only the equal-total check (`split_must_equal_total`, D83) stopped a split from paying part of a sale; the debtor rules (0074) and the overpayment refusal already existed. |

## 2. Decisions

| # | Decision |
|---|---|
| **D85** | **Today is the starting period** on the two tabs that own one, Home and Money: on launch, on the first visit, and after leaving for another tab and returning. A choice made there stays while the person stays — refreshes and refetches, and screens opened from the tab and their way back (the Daily closing, Quick sell, Results, a day's sales). One hook for both (`lib/use-tab-arrival.ts`): Today before the first paint, and again when the tab bar's own state shows another tab (a mounted tab never sees its route change). The shared store starts on Today. Results and a day's sales keep Money's choice, and the Daily closing's date bar is a date, not a period — untouched. Figures stay on the boutique's business day (before 06:00, Today is the day still running); Home's header keeps the store's calendar date. *Back to Money* on Expenses returns to the existing tabs (`dismissTo`) instead of pushing a second Money that would reset. |
| **D86** | **Sales details ›  …  (?)** — one shared `Expandable` (`components/ui/Expandable.tsx`): the words underlined in the accent colour on a light-violet wash, the chevron right after them pointing forward (right; left in Arabic), turning down as the rows slide out from beneath the header and folding back the same way (240 ms; none under Reduce Motion, read live). The (?) sits at the end of the same row, outside the toggle, and only explains. The rows keep their styles, so every amount stays in the statement's right-hand column. |
| **D87** | **Closing history** — the same component in its solid form: a purple header as prominent as *Close the business day* (the primary button's colour, radius and white text), **"Closing history"** with the count beneath it as "4 events" / "1 event" / "No events", the chevron at the physical right whether closed or open, in Arabic too, the same turn and slide. Every event, its order, captions and accessibility (a button, its expanded state, hidden content hidden from readers) kept; a panel open while an event arrives eases to its new height. **Corrects D81**: its purple never rendered on a phone. |
| **D88** | **No Pressable is styled by a function** anywhere in the app: all thirteen converted to `usePressed` with a plain style array; a test (`lib/design/pressable-style.test.ts`) fails on any new one. |
| **D89** | **Money held — tracked, never a provider balance.** The top card is the money the app tracks as held per method: **each method's latest anchor plus every movement recorded after it**, the total the server's sum of the rows, carried across midnight and 06:00. The drawer is anchored only by a **locked close whose drawer was counted** — the closing's own anchor, so Money and the closing never disagree; the day's counted close is itself the position once locked. An account is anchored by the amount the Owner read in the provider's app (**`money_anchors`, migration 0082**, append-only). After an anchor, money counts from the moment it moved: received and purchase payments when paid; refunds, supplier settlements and variable expenses when **reported** (the Owner's later confirmation moves nothing again); a fixed expense on its due day, once that day has come; a correction that **fixes a record** at that record's own moment (an anchor taken after the mistake is already true); a cancellation when approved. A method without an anchor is **Unknown**, with what is missing ("count the drawer when you close the day"; "no starting amount"), and then **there is no total** — never a zero, never a partial sum. A deactivated account that ever recorded money is listed (unknown until it has an amount); one that never did is not. The accounts are the company's, so their positions are shown to whoever may record them — the Owner; anyone else reads this branch's drawer and "Account amounts are shown to the Owner." Today's recorded in and out stays as its own card beneath. |
| **D90** | **Set amount (the Owner).** On each account row: a sheet — "Open the {account} app and enter the amount it shows now" — posting `POST /money/anchors` (`money.anchor.record`, the Owner's alone: not the Administrator, not delegated). The server stamps its own clock and business date, stores what it tracked just before and the difference, audits it, and answers a replay with the same anchor. The phone keeps one request key per opening of the sheet; a lost answer says "the amount may have been saved — check Money held". |
| **D91** | **Open first, on the server.** While the branch's current business day is closed (locked), `POST /sales` and `POST /purchases` answer **409 `store_closed`** — "The store is closed for business day {date}. Nothing was sold / received: the Owner or a named delegate must open the store first." — to every client, old builds included; nothing is written and nothing reopens. Checked before any pricing, warning or approval, and again inside the transaction on the locked row. A replay of a sale or receipt made before the close is still answered. *Open store now* (the reopen, continue or start early before 06:00, its permissions) is unchanged. **A later payment on an existing sale still reopens today's closed day** (0076) — the one automatic reopen left, now labelled "Reopened by a payment". On the phone a refusal covers the screen with the closed-store panel instead of unmounting it, so the sale in progress is still there after *Open store now*. The close popup now says "After closing, Sell and Receive wait until the Owner or a named delegate opens the store again." |
| **D92** | **Partial splits restored** (amends D83). A split takes at most four places — Cash one of them — each once, and pays **all or part** of the sale; what is left is owed by the named debtor (0074), never more than the total (400 `overpayment`), and amount paid + amount owed = the sale amount. The phone checks each part as the server does (a positive amount, two decimals at most), seeds the first part from the amount already typed, lets the last part be removed (back to the single field), asks for the debtor after the parts, and lists every part in the review, with cents shown whenever any figure has them. |

## 3. Verification

**Gates.** Backend: `tsc` clean; **164 suites / 2 957 tests**; `nest build`. Mobile: `tsc` clean; **80 pure suites /
1 123 cases**; lint 0 errors, 31 warnings (the baseline); translation parity **3 220** keys in EN, FR and AR, same
order. Each commit checked alone from a clean export: backend 640 / 670 / 677 closing-sales-purchasing-rbac tests;
mobile the same result as the final commit (the export lacks the generated `global.css` and three suites that read
untracked files, at every commit alike). A rolled-back proof of the account windows on a copy: **15 of 15** (a payment
moved to its real account after an anchor leaves both accounts at their anchors; an expense reported before and
confirmed after an anchor is not deducted twice; a cancellation after an anchor counts; a fixed expense counts only
once its due day has come).

**Reviewed before it shipped.** Six independent reviewers, each finding checked by a sceptic: 16 confirmed, 2 refuted,
all 16 fixed — among them a correction approved after an anchor that would have applied a mistake twice, an outflow
reported before an anchor and confirmed after it, company-wide account figures shown to a branch manager, an unused
deactivated account dropped from a "complete" total, a request key that could replay an old anchor after a lost answer,
the close popup still saying a sale reopens the day, a closed-store refusal that unmounted the sale in progress, and
three split traps (a last part that could not be removed, the typed amount thrown away, cents rounded apart).

**The web harness** — headless Chrome on the exported web build, the built backend on a fixed clock, a fresh copy of the
live dump of 2026-09-27 08:28Z with 0082 applied (`prisma_verify_home`, dropped afterwards): **51 of 52 checks and
33 of 33 server facts**.

| Area | Checked |
|---|---|
| Today first | Home opens on **Today** (its first request is `/home?period=today`); 7 days picked, kept through the Daily closing and back; Money opens on Today, keeps 7 days through 3 s of refetching and through Results and back; Home and Money both back on Today after another tab; no page reload. Before 06:00 (03:00 on the 28th): Home's Today is the business day 27 Sep with the header "Mon 28 Sep" and "Sales still count for 27 Sep 2026 until 06:00"; Money asks for `from=2026-09-27&to=2026-09-27`. |
| Sales details | EN and AR at 320 pt: folded, the chevron turned −90° (right) in English and +90° (left) in Arabic, 4 px after the words; open, 0° (down), the rows shown; underlined title on the wash rgb(238,236,252); the (?) on the same line at the row's end, 48 × 48; **10 amounts within 0 px** of one column; tapping the (?) leaves the panel folded. Whole at 320 × 568 with text 1.3×. |
| Closing history | EN and AR at 320 pt: the purple rgb(81,70,217) header reads **"Closing history" / "4 events"** (label "Closing history, 4 events"; AR "سجل الإقفال" / "عدد الأحداث: 4"); the chevron 16 px from the right edge at the same place folded and open, −90° / +90° folded, 0° open. An empty day reads "No events". **A drawer amount saved from the close popup with the history open: the server went from 4 to 5 events and the open panel grew.** |
| Motion | With the page told to reduce motion, both panels are fully open on the first read (228 → 228 px, 335 → 335 px). The animated run recorded no figures (the check made no assertion); the reveal is pinned in the tests. |
| The closed store (older client) | Test Store's 27th closed on the owner's word; a raw sale → **409 `store_closed`** "The store is closed for business day 2026-09-27. Nothing was sold: the Owner or a named delegate must open the store first."; a raw receipt → 409 `store_closed` "… Nothing was received: …"; the row still `locked`, auto_reopened events 1 → 1; the sale made before the close still found by its key (00010); the reopen unchanged (201); a Quick sell open under the close shows "The store is closed. Nothing was sold — open the store first." and the lock; after Open store now the same sale goes through (201). Demo's counted 28th refuses an older client's sale the same way. |
| Money held — before | Demo at 10:00 on the 28th: **Cash unknown (no counted close), Masrvi and Bankily unknown (no starting amount), no total**; the card shows "Not every method is tracked yet", Unknown on each row, what is missing, and no figure. |
| Anchors | A Store Manager: 403. −5 and 1.234: 400 `amount_invalid`; another company's account: 404 `account_not_found`. The Owner sets 0 for Bankily – Main Counter, Masrvi and Bankily – Second Shop (201, tracked before: unknown); the same key and amount answers the same anchor; the same key with another amount: 409. The 28th closed with the drawer counted at 0 (locked, 0.00): every method known, **total 0**. |
| **Across midnight** | Sales on the 29th: 3 400 cash, 2 000 Bankily, 1 600 Masrvi. **23:00 on the 29th: Cash 3 400 + Bankily 2 000 + Masrvi 1 600 + Bankily – Second Shop 0 = 7 000** (recorded today 7 000). **07:00 on the 30th, nothing moved: Cash 3 400, Bankily 2 000, Masrvi 1 600, Second Shop 0 = still 7 000**; recorded today 0; business day 30 Sep. The card shows 7 000 MRU with the rows in EN, FR and AR at 320 pt and whole at 1.3×; "Money recorded today" stays its own card beneath. A Store Manager reads only the drawer (3 400) and "Account amounts are shown to the Owner." — no total. |
| Partial four-place sale | 1 500 paid 300 cash + 300 Bankily + 300 Masrvi + 300 Bankily – Second Shop, 300 owed by the named customer: 201, stored total 1 500.00, paid 1 200.00, owed 300.00, `partial`, 4 payments. Refused: a fifth method (`too_many_payment_methods`), cash twice (`duplicate_payment_destination`), 1 600 of 1 500 (`overpayment`), a remainder with nobody named (`debtor_required`). A full four-way split: 201 `paid`. Afterwards: Cash 4 300 + Bankily 2 700 + Masrvi 2 200 + Second Shop 500 = **9 700**. On the form: four parts 200 each of 1 000 → "Remaining to pay 200 MRU · Partially paid · Who owes the balance? · Review sale" (held until a debtor is named); a fifth refused with "A sale can be split across at most four payment methods." (the over-total line is pinned in the tests; the harness could not type into the first part a second time). |
| Set amount | A fifth account appears (Sedad): **no total**, Sedad named as unknown, the other rows kept. The Owner opens Set amount on Sedad from Money, types 250, saves: the card shows 9 950 and the stored anchor 250.00 with tracked-before unknown; four anchors, none changed. |

**Live.** Records unchanged (17 sales, 7 expenses, 11 closing events, 3 closing rows, 17 payments, before and after).
**Migration 0082 applied to live** at 19:57Z after a verified backup
(`~/erp-backups/phonestore-before-0082-20260927-195629.sql`, 919 KB, "Dump completed"): the table empty, both triggers,
`money.anchor.record` granted to each company's Owner role. The API on 3010 runs the new build; Metro on 8081 serves
the new app (the Android bundle builds).

## 4. What the web establishes, and what needs the phone

**The web establishes** the server's rules and figures on a copy of live, the rendered labels, geometry and states in
EN/FR/AR at 320 pt and scaled text, the tab-arrival logic on the web tab bar, and reduced motion as the browser
reports it.

**It does not establish, and the phone must check** (`docs/24` §47): that the purple header, the underlined Sales
details and every converted row actually render on native (the web never showed the defect); the reveal and the
chevron's turn on native, and Reduce Motion switched on in the phone's settings; the chevron in Arabic after a
relaunch; the phone's own large text; Today after a real cold start and after switching tabs on the phone's tab bar;
the closed-store panel covering a screen (touch blocked, keyboard dismissed, TalkBack/VoiceOver silent behind it); the
Set amount sheet with the keyboard up; the split sheet with four parts and the keyboard.

## 5. Owed

- **The phone review** (`docs/24` §47). Home, Money and the Daily closing stay **pending** until then.
- **Live has no tracked position yet**: no close has counted the drawer, and no account has a starting amount. The
  Owner sets each account from Money (Set amount) and counts the drawer at the next close; until then the card says
  what is missing and shows no total. This is the Owner's own act on live.
- **Kept on purpose:** a later payment on an existing sale still reopens today's closed day (0076) — the one automatic
  reopen left, labelled "Reopened by a payment". Refusing it too is the user's call.
- **Known limits:** positions include only what the app records (not loans, consignment, owner drawings, transfers or
  provider fees) — re-anchoring absorbs the drift and records the difference; a count saved and then a sale before
  the close still leaves that sale out of the next opening (the closing's existing rule, unchanged); the account
  queries scan company-wide from each anchor (fine at this volume).
- **Deploy order:** the backend first. An older app still works against the new server (it gets `store_closed` as a
  message, keeps `accountsToday`); a new app on an older server shows "update the server" on Money.
- **Still open from before:** counting by a store employee; "+0 MRU cash" and "1 balances"; the three `spent_on` rows.
