# 59 — Home, Money, the Daily closing and the sale flow from Home (2026-09-27)

The user's brief of 2026-09-27: keep the approved simple design; no scanner or refund work; no pictures; live records
unchanged. Home's two actions and the business-day lock; Money's top card and its period; four Daily closing
refinements; the sale flow's return-policy reason, split payments and *Choose from stock*. Recorded in `docs/21`
(D75–D84), `docs/04` rules 19 and 25, and `docs/24` §46.

---

## 1. Decisions

| # | Decision |
|---|---|
| **D75** | **Home: Receive on the start side, Sell on the end side** (left and right in English and French; Arabic mirrors, as every row does). Each keeps what it does — Receive opens Quick Receive, Sell opens Quick Sell. *Sell several items* is gone from Home: selling several items stays inside Sell (Quick Sell's own link to the full sale). |
| **D76** | **The counter lock.** While the boutique's **current business day is closed** (the server's day view: `standing: 'closed'` for today's business date), Home shows Sell and Receive disabled and **Open store now** beneath them. Open store now is the existing reopen flow (`POST /closings/reopen`, `closing.perform` — the Owner or a named delegate): before 06:00, when the Owner may start the next day early, the choice sheet asks which business day new sales use (*Continue {date}* or *Start {next} early*); otherwise one confirmation. Success reads the day again and Sell and Receive open. Someone who may not open the store (a store employee without the delegation) sees the lock and "Only the Owner or a named delegate can open the store." — no dead button. **The routes are guarded too:** Quick Sell, the full Sell, Quick Receive, Receive, the receiving file picker and the file review default-export a guard that shows "The store is closed" with Open store now instead of mounting the screen, so a link, the Stock tab or the back stack cannot sell or receive while the day is closed. The lock reads the light business-day view (`GET /closings/business-day`, `closing.count`), not the heavy closing view: Home reads it again when it comes back into view, when the app returns to the foreground and on pull to refresh (a close made elsewhere, 06:00 passing); a guard reads it fresh and shows a spinner, not the screen, until the first answer. Open store now loads the reopen choices itself, only for someone who may open, and stays disabled offline, while they load, while the confirmation is open and while the reopen runs; the lock lifts only after the day, the reopen view and Home have been read again, and a failed reopen reads the day again. **Not changed on the server:** a sale or a paid receipt that still reaches a closed day reopens it automatically (rule 25, 0076) — the phone no longer lets that happen from Sell or Receive, but an older app build or another client would still trigger it; nobody without `closing.count` (the view's permission) is locked by the phone. The reopen sheet's note now reads "Sell and Receive open again as soon as you confirm." |
| **D77** | **Money's top card: every method, one basis, a total that is their sum.** "Money recorded today" — the server's `moneyToday` on `GET /closings/overview`: for the current business day, every configured method (the drawer, each active account, an inactive account or the unattributed bucket only when money moved) with its money in, money out and net (in − out), **no opening balance for the drawer or for any account**, and `total` = the exact sum of the rows returned. The phone shows the total on a line of its own (so large text does not cut it), then each method beneath it with "{in} in · {out} out" and its net; it adds nothing up. Figures are whole units unless one of them carries cents, then every figure on the card shows two decimals so the rows visibly add up (`MoneyValue` takes `decimals`). `accountsToday` stays on the response for app builds older than this change. The hint says what it is: "Money in less money out, recorded in this app today ({date}) for each method. Not a drawer count, not an account balance." The drawer estimate (`cashNow`, opening + today's cash) is no longer on the card and is never added to account movement; it stays for the expense screens (and the Daily closing shows the drawer on its own terms). |
| **D78** | **Money opens on Today.** Every arrival at the Money tab — the first visit, or from another tab — selects Today. What the person then picks (7 days, This month) stays for the visit: a screen opened from the tab (Results, a day's sales) and its way back are not an arrival, and a background refetch changes no choice. The tab stays mounted behind the other tabs and its own route never changes, so the reset listens to the tab bar's state: leaving Money for another tab sets Today, and the first visit sets it before the first paint. The card reads today's range on its own query (the same cache as Today's sections), so choosing 7 days never blanks it. |
| **D79** | **Sales details: one amount column, the chevron beside the title.** The header is built on the page: the title with its chevron immediately beside it, the (?) at the end of the same line (a 48-pt target at any width); the rows below take the statement's full width, so every amount — Invoiced sales included — ends in the same right-hand column as the figures above (the (?) used to narrow the rows' column). |
| **D80** | **The Money owed card is removed** from the Daily closing — its counts, amount, explanation and Loans link (the user reversed D74's keeping of it). Its data hook and five catalogue keys go with it; the server's `/loans/closing-reminders` stays, unused by the app. *Debt settled for this day* stays in Money movements. |
| **D81** | **Closing history's header is purple**: one header across the card in the info intent's solid colour (the brand purple, `#5146D9`, in both themes; white on it, 6.5 : 1), the title and the event count (a white pill) centred and larger, and a 28-pt white chevron **fixed at the physical right edge in both directions** (`end` in left-to-right and `start` in right-to-left on the phone, where layout swaps left and right; `right` on the web, which does not). It turns; it never changes sides. The reveal/fold (240 ms, entries sliding out from beneath the header) and Reduce Motion are unchanged. |
| **D82** | **"Why is this sale different?" is removed.** It was the reason asked when a manager or the Owner changed one sale's return window. The form no longer shows it, validates it or blocks on it ("Say why before continuing"); the sale screens no longer send it. The server no longer requires it (`resolveWindowForSale` returns a null reason) and still stores one an older client sends. The return-policy safeguards stay: only `return.policy.override` may change the window, within 0–8 760 hours, and a positive default is never shortened to another positive value; the change is kept on the sale (who, the window, the deadline) and in the audit. Discounts (subtotal cap) and pricing approval (floor, below-cost reason) are untouched. |
| **D83** | **A split pays the whole amount due in at most four places.** The drawer, if used, is one place; each account one more. Each place once (two cash parts, or one account under two methods, are refused). With two or more parts they must add up to the amount due exactly; a sale paid only in part takes one method and names who owes the rest (0074, unchanged). The form offers a free place for each new part, keeps accounts another part uses out of its picker, says "A sale can be split across at most four payment methods." when a fifth is asked for, says "Every payment method already has a part." when every place is taken, and keeps Complete disabled with the reason while the parts do not add up or repeat a place. One part alone — the split just opened, or all but one removed — is a one-method payment again and may leave a named debtor the rest. An account is the same place in any letter case of its id. The server enforces the same (`assertPaymentParts`, before reconciling): 400 `too_many_payment_methods`, `duplicate_payment_destination`, `split_must_equal_total`; the two sale screens translate each. |
| **D84** | **Choose from stock, easier to scan.** Each item is a card set in 16 pt from both edges (like the search above it), 8 pt between cards, a hairline border, 12 × 16 pt inside; name, variant and the masked identifier each on their own line with space between; price and the selection circle at the far edge; the whole card the target (64 pt at least); selected cards tinted with a primary border. A long list stays fast: one stable selection callback and one stable render function, so the memoised row re-renders only when its own selection changes; batched rendering windows. Search, the filter sheet, single selection and Continue are unchanged. |

**One judgement recorded:** "keep the parts' sum equal to the amount due" is read as *a split pays the whole sale*; a
partial payment keeps the single-method path with a named debtor. The earlier split-and-owe combination is therefore
refused by the form and the server.

## 2. Files

Backend: `src/closing/channels.ts` (`moneyByMethod`), `src/closing/closing.service.ts` (`moneyToday` on the overview),
`src/sales/return-policy.ts` (reason optional), `src/sales/sale-payment-rules.ts` (`MAX_PAYMENT_METHODS`,
`assertPaymentParts`), `src/sales/sales.service.ts` (the call), `src/sales/dto/create-sale.dto.ts` (its doc); specs
`channels.spec.ts`, `return-policy.spec.ts`, `sale-payment-rules.spec.ts`.

Mobile: `app/(tabs)/index.tsx` (the order, the lock, Open store now), `lib/day-gate.ts` (new), `components/day/
OpenStoreNow.tsx` and `DayGate.tsx` (new), `lib/closing.ts` (`useOpenClosing` takes `enabled`), the six Sell and
Receive routes (guarded), `app/(tabs)/money-hub.tsx` (the card, the period), `lib/money-overview.ts`, `lib/contract.ts`,
`app/closing/index.tsx` (Sales details, no Money owed), `components/closing/HistoryPanel.tsx` (purple header),
`lib/loans.ts` and `lib/query-keys.ts` (the reminders hook gone), `components/sell/PaymentSheet.tsx`,
`components/sell/ReturnPolicyControl.tsx`, `app/quick-sell.tsx` and `app/(tabs)/sell.tsx` (no reason; the refusals),
`lib/sale-payment-rules.ts` (`splitProblem`, `nextFreeSource`), `lib/discount-approval-state.ts` (three refusals),
`components/sell/PhonePicker.tsx` (the shelf), `components/ui/SegmentedControl.tsx` (two lines under large text, shared), `components/ui/MoneyValue.tsx` (`decimals`, shared), `lib/home.ts` (`useBusinessDay` takes `enabled` and `fresh`), `lib/navigation/registry.ts` (a note); i18n: 10 keys added, 11 removed, `reopen.note` reworded (EN/FR/AR, 3 191 each);
tests `day-gate.test.ts`, `stock-picker-layout.test.ts` (new) and the pins that follow.

## 3. Verification

**Gates.** Backend: `tsc` clean; 160 suites, 2 854 tests; `nest build`. Mobile: `tsc` clean; 76 of 76 pure suites;
lint 0 errors, 31 warnings (the baseline); translation parity 3 191 keys in EN, FR and AR, same order, no duplicates.
Each mobile commit was also checked alone from a clean export of it: the same result as the final commit (the export
lacks the generated `global.css` and three suites that read untracked files, identically at every commit).

**The web harness** — headless Chrome on the exported web build, the new backend on an isolated port with a fixed
clock, a fresh copy of the live dump of 2026-09-27 06:34 (`prisma_verify_home`, dropped afterwards): **42 of 42 checks
clean**.

| Area | Checked |
|---|---|
| Home, open | Receive then Sell, both enabled; English at 393 pt: Receive on the left; Arabic: Receive on the right (mirrored); at 320 pt the two stack, Receive on top. |
| Home, closed | Test Store's 27th closed on the owner's word: Sell and Receive disabled, *Open store now* enabled beneath — EN, FR, AR at 320 pt, EN at 320 × 568 with text × 1.3. `/quick-sell`, `/quick-receive`, `/sell`, `/receive` show "The store is closed" and do not mount. |
| Open store now | One confirmation; the server says the 27th is *reopened*, history intact; Sell and Receive enabled; `/quick-sell` open again. |
| No permission | A store employee at Demo's closed 27th: the lock and "Only the Owner or a named delegate can open the store.", no button; `/quick-sell` guarded for them too. |
| Before 06:00 | At 03:00 on the 28th the business day is still the closed 27th; *Open store now* opened the choice sheet (*Continue 27 Sep 2026* / *Start 28 Sep 2026 early*); *Start early* → business day 2026-09-28, `startedEarly`, the 27th stays closed. |
| Money figures | Three sales on the 29th: 3 400 cash, 2 000 Bankily – Main Counter, 1 600 Masrvi. The server's `moneyToday`: Cash 3 400, Masrvi 1 600, Bankily – Main Counter 2 000, Bankily – Second Shop 0, Sedad Counter 0; **total 7 000 = the sum of the rows** (in 7 000, out 0). The drawer estimate (`cashNow` 3 400) is its own figure, not in the total. The card shows all five and 7 000 in EN, FR and AR at 320 pt; nothing cut at 320 × 568 × 1.3 (the first run cut "7 000 MRU" beside the icon — the total now has its own line). |
| Money period | Today on arrival; 7 days chosen; still 7 days after 3 s of refetching and after Results and the in-app back; Today again after Home and back to Money; no page reload. (The first fix followed the route and did not reset: a mounted tab's route never changes — found here, fixed with the tab bar's state.) |
| Daily closing | EN and AR at 320 pt: 9 Sales details amounts, right edges within 0 px; the chevron 4 px from the title; the (?) on the same line; history header `rgb(81,70,217)`, title centred, chevron 16 px from the right edge at the same x closed and open, in both directions; Money owed absent; *Debt settled for this day* present. |
| Sale, return window | 3 days chosen; no reason field, no "Say why" blocker; Complete enabled. |
| Split, form | Four parts 400 + 300 + 200 + 100 of 1 000, each place once; a fifth refused with "A sale can be split across at most four payment methods."; Complete enabled. French at 320 pt: 500 + 200 of 1 000 → Complete disabled, "Les parts font 700 MRU sur 1 000 MRU…". |
| Split, server | 5 methods → 400 `too_many_payment_methods`; cash twice and one account under two methods → 400 `duplicate_payment_destination`; 1 000 + 200 of 1 500 → 400 `split_must_equal_total`; four places adding to 1 500 → 201; one method 500 of 1 500 with a named debtor → 201; a 3-day window with no reason → 201. |
| Choose from stock | 68 more phones on the shelf: cards 16 px from both edges, 8 px apart, 110 px tall at 320 pt; rows keep arriving as the list scrolls (17 → 29 rendered); the second-to-last chosen, Continue enabled, the item picked. Arabic at 320 × 640 × 1.3 clean. |

**Live records unchanged:** 17 sales, 7 expenses, 11 closing events, 3 closing rows, before and after. The API on
port 3010 runs the new build.

## 4. What the web checks establish, and what needs the phone

**The web establishes** layout geometry at 320 and 393 pt, order and alignment, English, French and Arabic
right-to-left, large text as scaled font sizes, the lock, the guards and both opening paths against the real server,
the server's contract and figures, the Money period on the web tab bar, the split form's rules and long-list
selection.

**It does not establish, and the phone must check** (`docs/24` §46): the phone's own large text (Android and iOS
font scale) on Home, the Money card, Sales details and the purple header; the history chevron in Arabic on the phone
(`start`, where the web used `right`); Reduce Motion with the history reveal; the Money reset on the phone's tab bar;
the split amounts with the keyboard open; the long stock list's scrolling on a mid-range phone; the lock after a
close made on another device and the app brought back to the foreground; touch targets under a thumb.

## 5. Owed

- **The user's call — Arabic Home order.** Receive is on the start side, so on the right in Arabic, as every row
  mirrors. If "Receive on the left" is meant in Arabic too, it is one line.
- **Rollout:** the backend goes first (done locally). An app build older than this change still works — the server
  keeps `accountsToday` and still accepts a reason — but a split it sends with more than four places, a repeated
  place or parts short of the total is now refused, and that build shows a generic error.
- **Kept on purpose:** the server's automatic reopen on a sale or a paid receipt reaching a closed day (rule 25);
  a split can no longer leave a debt (the judgement above).
- **Unused:** `/loans/closing-reminders` on the server; removing it is a separate change.
- **Shared components changed:** `SegmentedControl` (grows to two lines rather than cutting a label) and
  `MoneyValue` (`decimals`); every other use keeps its look at normal text sizes.
- **Still open from before:** counting by a store employee; the wording "+0 MRU cash" and "1 balances" elsewhere.
