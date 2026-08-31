# 24 — Physical-device QA checklist

Everything below needs a **real phone**. It is here because an emulator-free,
headless environment cannot honestly test a camera, a haptic motor, a keyboard,
or how Arabic actually lays out on a screen.

**How to use this:** work top to bottom on one device, record pass/fail in the
right-hand column, and note anything that felt wrong even if it technically
worked. "It works but I hesitated" is a real finding in a shop.

```
Device model: ____________________   OS version: ____________
App build:    ____________________   Date: ________________
Tester:       ____________________
```

---

## Already verified by Claude — do not re-test unless something looks wrong

These were driven against the running app and the real database. Listed so you
know what is *already* covered and can spend your device time on the rest.

| Area | Evidence |
|---|---|
| Branch price: set → update → remove → fallback restored | Driven in the app; source label changed at each step |
| Same variant priced differently per branch | Main Store 1 200, Warehouse 1 000, side by side |
| Exact-phone override: set, update, remove | Driven by manual IMEI entry |
| Sold phone cannot be priced | Action hidden, message shown, API refuses |
| Unknown identifier | "No item with that number", no retry offered |
| Quantity price edit | Version incremented, no second price row created |
| Owner below-cost | Reason dialog; blank reason blocked; reason stored in history |
| Manager below-cost | Refused, no bypass, no cost figure in the message |
| Stale edit (409) | Real race: "You tried 888 MRU. It is now 1 234 MRU." |
| Permission gating | Manager edits only the granted branch; Employee has no controls and is 403 on the API |
| Owner notification | Manager change → Owner notified, no cost/margin, action link lands on pricing |
| Price history | previous → new, actor, scope, reason, "Price removed" |
| Arabic strings | Full pricing section renders in Arabic |

---

## 1. Cold start and session

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 1.1 | Force-quit, reopen | Lands where you left off, no long blank splash | |
| 1.2 | Reopen with no network | Explains the problem; no infinite spinner | |
| 1.3 | Sign out, sign in | Store ID → login → branch picker → home | |
| 1.4 | Ask an Owner to remove you from your saved branch, then reopen | You land on the **branch picker**, not a dead error screen | |

## 2. Branch selection

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 2.1 | Switch branch from More | Home figures change to that branch | |
| 2.2 | Open a product after switching | Price and source match the new branch | |
| 2.3 | Switch to a branch where you are not a manager | Pricing actions **disappear** | |

## 3. Pricing visibility by role

Run as each role. The Employee case matters most — that is the person at the
counter.

| # | Role | Expected | Pass/Fail |
|---|---|---|---|
| 3.1 | Owner | Sees price, source, and all pricing actions | |
| 3.2 | Manager (granted branch) | Sees pricing actions | |
| 3.3 | Manager (other branch) | **No** pricing actions at all | |
| 3.4 | Employee | Sees the price and why; **no** edit controls, no history | |

## 4. Changing a price

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 4.1 | Change this model's price | Sheet explains it affects every one of that model *in this branch* | |
| 4.2 | Type a price, then close the sheet without saving | Asks before discarding | |
| 4.3 | Save | Toast, price updates, **success haptic** | |
| 4.4 | Remove the price | Confirmation says what the price becomes | |
| 4.5 | Type letters, or leave it blank | Save stays disabled | |
| 4.6 | Type `17000.555` | Rejected — two decimals only | |

## 5. Camera and IMEI — the part only a device can prove

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 5.1 | On the phone being priced, dial `*#06#` | IMEI appears on its screen | |
| 5.2 | Scan that IMEI from the screen with the app | Resolves to the right phone, first try | |
| 5.3 | Scan in poor light / at an angle | Either resolves or fails clearly — never the wrong phone | |
| 5.4 | Scan the same IMEI twice quickly | No duplicate handling glitch | |
| 5.5 | Torch on/off | Works, and does not stay on after closing | |
| 5.6 | Deny camera permission, then open the scanner | Explains, and manual entry still works | |
| 5.7 | Type the IMEI by hand | Same result as scanning | |
| 5.8 | Scan a **box** instead of the phone screen | Note what happens — the box is deliberately not the documented route | |

## 6. Keyboard, sheets, haptics

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 6.1 | Open the price sheet | Keyboard does not cover the Save button | |
| 6.2 | Drag the sheet down | Closes; asks first if you typed something | |
| 6.3 | Rotate / use a large font size | Nothing clipped or unreachable | |
| 6.4 | Save a price | Success haptic | |
| 6.5 | Trigger a refusal (below cost as a Manager) | Error haptic, plain-language refusal | |

## 7. Arabic and RTL — **not verified by Claude**

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 7.1 | Switch to Arabic | Whole app flips; nothing stays left-aligned | |
| 7.2 | Product Details pricing section | Long source explanation **wraps**, not truncated | |
| 7.3 | Price input | Cursor and digits behave; number stays readable | |
| 7.4 | Buttons in the price sheet | Order reads correctly right-to-left | |
| 7.5 | Scanner instruction | `*#06#` reads correctly, not reversed | |
| 7.6 | Price history rows | previous → new arrow points sensibly | |
| 7.7 | Any screen | No English text left untranslated | |

## 8. Notifications

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 8.1 | Have a Manager change a price; open Notifications as Owner | The change is listed, marked New | |
| 8.2 | Read it | Manager name, product, branch, old and new price | |
| 8.3 | Check carefully | **No cost, no profit/margin anywhere** | |
| 8.4 | Tap it | Opens that product's pricing section | |
| 8.5 | Reopen the list | It is no longer marked New | |
| 8.6 | Owner changes a price themselves | Owner is **not** notified about their own change | |
| 8.7 | Scroll to the bottom of a long list | More loads; it does not fetch everything at once | |

## 9. Sell, Inventory, Receive

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 9.1 | Sell a phone that has its own price | That price is offered | |
| 9.2 | Sell another of the same model | The branch price is offered, not the other phone's | |
| 9.3 | Add to cart, then have someone change the price | Cart price does **not** move under you | |
| 9.4 | Sell below cost as Employee/Manager | Refused | |
| 9.5 | Sell below cost as Owner | Reason required and recorded | |
| 9.6 | Open an old receipt after changing prices | Totals and profit unchanged | |
| 9.7 | Inventory list | Selling price shown; cost only if you may see cost | |
| 9.8 | Receive quantity stock for the first time | Price behaviour matches what the Owner expects — **flag anything surprising**, this is the open G2B question | |
| 9.9 | Receive more of the same | The existing price is **not** overwritten | |

## 9b. Transfers (H1.3) — **the workflow was never touched on a device**

The backend behaviour is proven (76/76 live, five real sessions, real MySQL) and
the screens compile, export and pass their pure tests. **Nothing below was
exercised by a finger on glass.** Two people at two branches make this much
faster to check than one.

### Requesting

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 9b.1 | More → Transfers | The row is there, showing waiting/to send/on the way counts | |
| 9b.2 | New transfer | Source is the branch you are in, stated not chosen | |
| 9b.3 | Pick a destination | Only other branches offered | |
| 9b.4 | **Scan a phone's IMEI off its screen** (`*#06#`) | Added, with the right product named | |
| 9b.5 | Scan the same phone again | "Already on the list" — count does **not** go to 2 | |
| 9b.6 | Scan an accessory / barcode item | Explains accessories are coming next; the scan is **not** silently ignored | |
| 9b.7 | Type an IMEI by hand | Same result as scanning | |
| 9b.8 | As an Employee, read the button | Says it will wait for approval | |
| 9b.9 | As a Manager, read the button | Says it will be created already approved | |
| 9b.10 | Press back with items added | Asks before losing them | |
| 9b.11 | Turn airplane mode on and Send | Clear failure, no false success | |
| 9b.12 | Turn it off and Send again | **One** transfer exists, not two — check the list | |

### Approving and moving

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 9b.13 | Manager opens Notifications | "needs approval", naming both branches | |
| 9b.14 | Tap it | Opens that exact transfer, not a list | |
| 9b.15 | Approve | Confirms first; succeeds only after the server agrees | |
| 9b.16 | Employee's Notifications | Told it was approved | |
| 9b.17 | Ship, then Receive at the other branch | Each asks about the physical goods before committing | |
| 9b.18 | After receiving, find the phone in Inventory | At the destination, in stock, sellable | |
| 9b.19 | Try to sell it at the source | Not there any more | |
| 9b.20 | Reject a request with no reason | Cannot proceed until a reason is given | |
| 9b.21 | Two devices approve the same request at once | One wins; the other says someone acted first and refreshes | |
| 9b.22 | Double-tap Approve fast | Fires once | |

### Branch awareness

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 9b.23 | Open a transfer notification while in the **wrong** branch | Explains where the action belongs, offers "Switch to X" | |
| 9b.24 | Do **not** press it | Branch never changes on its own | |
| 9b.25 | Press it, then act | Works from the right branch | |

### History and Arabic

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 9b.26 | Transfer list tabs | Waiting / approved / on the way / received / refused / cancelled all reachable | |
| 9b.27 | Search a full IMEI of an old transfer | Found, even if it is far down the history | |
| 9b.28 | Search a branch or product name | Found | |
| 9b.29 | Scroll to the bottom | Loads more, then says the history has ended | |
| 9b.30 | Switch to Arabic | Every transfer screen reads naturally, **right-to-left, correctly mirrored** | |
| 9b.31 | Arabic notifications | Transfer messages are in Arabic, with branch names and the reference | |

## 10. Everyday robustness

| # | Step | Expected | Pass/Fail |
|---|---|---|---|
| 10.1 | Background the app mid-edit, return | Nothing lost or silently saved | |
| 10.2 | Airplane mode mid-save | Clear failure, retry offered, no false "saved" | |
| 10.3 | Two devices editing the same price | Second gets "someone else changed this", never a silent overwrite | |
| 10.4 | Share a receipt | Sheet opens, file/text correct | |
| 10.5 | Paste into a text field | Works (clipboard was never device-verified) | |

---

## Notes and anything that felt wrong

```
```

## 9c. Accessory transfers (H1.4) — **also never touched on a device**

Everything in §9b still applies and is still unverified. These are the checks
H1.4 adds. Nothing below has been performed: the whole phase was verified by a
type checker, a test runner, a web export and API-level scripts.

### Scanning and choosing an accessory

| # | Check | Expected |
|---|---|---|
| 1 | Scan the **barcode on an accessory box** in Transfers → New | The exact product and variant appear, added to the draft with quantity 1 |
| 2 | Scan the same box again | The existing line counts up to 2 — **not** a second line, and a toast says so |
| 3 | Scan a barcode shared by more than one variant | The picker opens with the choices. **Nothing is guessed** |
| 4 | Scan an accessory the branch has none of | Refused, naming the product, with nothing added |
| 5 | Search by name instead of scanning | Matching accessories list with physical, reserved and available |
| 6 | Search for something the branch does not stock | "Nothing here matches that." |

### Quantity entry

| # | Check | Expected |
|---|---|---|
| 7 | Tap `+` past the available amount | Stops at available; the `+` becomes unusable |
| 8 | Type a number larger than available | Clamps to available rather than accepting it |
| 9 | Type letters into the quantity field | Ignored; no `NaN`, no crash |
| 10 | Take a line down to 0 | The line is removed |
| 11 | Read the three numbers on a line | Physical, reserved and available are each **named**, not a bare figure |
| 12 | Request an amount when another transfer already holds some | Available is lower than physical, and the wording explains why |

### Mixed transfer, end to end

| # | Check | Expected |
|---|---|---|
| 13 | Add 2 phones and 10 chargers to one draft | Summary reads "2 phones · 10 accessories" |
| 14 | Submit as an **employee** | "Awaiting approval" said **before** the button is pressed |
| 15 | Submit as a **manager** | "Created as approved" said before the button is pressed |
| 16 | Approve → Ship → Receive at the destination | Each step succeeds from the branch it belongs to |
| 17 | Receive with the phones scanned | Phones arrive `in_stock`; the chargers arrive without needing a scan |
| 18 | Check the destination's accessory count afterwards | Increased by exactly the amount sent |
| 19 | Try an action from the **wrong branch** | Refused with an offer to switch to the named branch |
| 20 | Open a transfer notification from the other branch | Lands on the exact transfer, offering the switch |

### Arabic

| # | Check | Expected |
|---|---|---|
| 21 | The draft in Arabic | Labels, counts and the summary read naturally; numerals are legible |
| 22 | **The quantity stepper in RTL** | `−` and `+` keep their positions; pressing `+` still increases. *(Deliberately not mirrored — the layout is a spatial habit people carry across languages)* |
| 23 | The three-number line in Arabic | Wraps without truncation on a small screen |
| 24 | The transfer list in Arabic | "2 هاتف · 10 إكسسوار" reads correctly, not as English grammar transliterated |

### What only a device can answer

Camera focus on a small barcode on a crumpled box · haptics on add, merge and
refusal · the stepper under a thumb rather than a mouse · keyboard avoidance
with the quantity field near the bottom · sheet gestures · Arabic **visual**
mirroring of the whole screen.

## 9d. Sale history and the return policy (I1) — **never touched on a device**

Verified by a type checker, a test runner and a web export only. Nothing below
has been seen on a real phone, in a real shop, by a real employee.

The two questions worth most here: does an employee at the counter understand
what the policy control is telling them, and can a customer read the policy on
the receipt they are actually handed.

### Sale history

1. Open **More → Sales**. The list appears with the branch name in the title.
2. Pull to refresh. Nothing duplicates, nothing disappears.
3. Scroll to the end. More pages load; the last page says the history ended.
4. Scroll a long list, then have someone complete a sale on another device.
   Scroll further: **no row repeats and none is skipped** (the keyset promise).
5. Search an **invoice number**. The right sale appears.
6. Search an **IMEI** of something sold. The sale appears — including if it is
   far down the history, which is the whole point of searching on the server.
7. Search a **product name**, a **customer name**, and the **employee's name**.
8. Search something that exists at **another branch only**. Nothing is found,
   and the empty state suggests what to try rather than implying it is gone.
9. Filter **On credit**. Only credit sales. Combine it with a search.
10. Every row states its return status **in words**, not colour alone.
11. A paid sale shows **no** "Paid" badge; a part-paid one does.
12. A sale of 1 phone and 10 cables says **11 items in 2 lines**, not "2 items".

### Sale detail

13. Tap a row. The total is the focal number; the return status is near the top.
14. Identifiers are readable and **left-to-right even in Arabic**, and long-press
    copies one.
15. As an **employee** (no `cost.view`): no cost, no profit anywhere on the
    screen — not greyed out, simply absent.
16. As the **Owner**: cost and profit are present.
17. Open a sale, then switch to a branch that does not own it. The screen says
    the sale was not found and suggests switching branch — **not** "forbidden",
    and not a technical error.

### The policy at the till

18. As an **employee**: the payment sheet shows the shop policy, read-only, with
    a sentence saying only a manager can change it. It does not look broken or
    disabled-without-reason.
19. As a **manager**: the choices include removing the window and lengthening
    it, and **do not** include a shorter positive window.
20. Change it. A reason field appears and **Complete is blocked** until it has
    text. The blocked reason is stated, not silent.
21. Complete the sale. Open it in the history: the policy shows the changed
    window, who changed it and why.
22. Start another sale immediately. The policy is back to the shop default —
    nothing carried over.
23. Set the phone's clock forward two days, then complete a sale. **The deadline
    on the receipt must still be correct** — it is the server's, not the
    device's. (Set the clock back afterwards.)

### The receipt

24. Share a receipt on a sale with a window. The policy line names the window in
    words *and* the exact deadline.
25. Share one with no window. It says the sale is final, not "0 hours".
26. Read the Arabic receipt: the policy line reads naturally, the deadline is
    legible, and the layout does not break right-to-left.
27. Send a receipt over WhatsApp, as a customer would receive it. The policy line
    survives the PDF and is readable on a small screen.

### What only a device can answer

- Is the policy control noticed at all in the payment sheet, or does the eye go
  straight to Complete?
- Does a first-week employee read "Returnable · until Sunday 14:20" and say it
  to the customer, or ignore it?
- Is the reason field a help or an obstacle when a manager is in a hurry with a
  queue waiting?
- On a small screen, does the payment sheet still fit with the policy control in
  it, or does Complete get pushed below the fold?


## 9e. The Returns workflow (I2) — **never touched on a device**

Verified by a type checker, a linter and a web export only. The two questions
worth most: can an employee complete a return with a customer waiting, and does
an approved return read as "we owe this" rather than "we paid it".

### Raising one

1. **More → Returns → Request a return.** Tap **Scan the phone**. Dial `*#06#`
   on the customer's phone and scan the IMEI **from its screen**, not the box.
2. Scan a box barcode instead. It must not silently match a different phone.
3. Type an IMEI by hand. The whole flow must complete with the camera never
   opened — permission denied included.
4. Type an IMEI that was never sold. The message must say what to try next.
5. Start from **Sales → a sale → Request return** on a phone line. An accessory
   line must offer no such button.
6. Fill the form, press back. It must ask before discarding.
7. Submit with a dead connection, then retry when it returns. **Exactly one**
   return must exist afterwards.

### Custody

8. Raise one with "Customer still has it". The phone stays sellable; the screen
   says approval cannot happen yet.
9. Record intake with the wrong IMEI — refused, and nothing changes.
10. Record it with the right IMEI. Try to sell that phone: it must be refused.
11. Record intake twice. The second must not look like a failure.

### Deciding

12. As an **employee**: no Investigate, Approve or Reject buttons.
13. As a **manager**: investigate, set responsibility, add a withheld charge.
    Totals must come back from the server and match what approval later records.
14. Add a charge larger than the refund — refused, in words.
15. Set **customer-caused damage**. The warning that only the Owner can approve
    must appear *before* trying.
16. As a **manager** on an out-of-policy return: Approve must refuse.
17. As the **Owner**: approve it with a reason. The reason must be required.
18. Two devices approve and reject the same return at once. Exactly one wins;
    the loser refreshes and shows what actually happened.
19. After approval the screen must say **refund due, payment not confirmed**,
    and that the phone is held and not for sale.

### Arabic and layout

20. Switch to Arabic. Every Returns screen: no English leaks, IMEI still reads
    left-to-right, the money column does not collide with labels.
21. Bottom action buttons must not cover the last field with the keyboard open.
22. Tap targets on the adjustment rows are reachable one-handed.

### What only a device can answer

- Does scanning a phone's own screen actually focus, or does the glare beat it?
- Is "Refund due — payment has not yet been confirmed" understood as *not paid*?
- Can a manager finish an investigation with a customer standing there?


## 9f. Refund payout and receipt (I3) — **never touched on a device**

Everything in §9b–§9e still applies and is still unverified. Nothing below has
been performed: I3 was verified by a type checker, a test runner, a web export
and API-level scripts.

### Reporting

| # | Check | Expected |
|---|---|---|
| 1 | Open an approved return as an **Employee** | "Refund due — payment has not yet been confirmed", in warning tone, **not** green |
| 2 | Look for a confirm button as an Employee | There is none — not a disabled one |
| 3 | Tap "Report refund handed to customer" | The amount is shown and **cannot be edited** |
| 4 | Choose Account with no active account configured | Says so plainly and offers cash instead |
| 5 | Choose Account with accounts configured | Only **active** accounts are listed |
| 6 | Submit | A dialog says a manager or owner must still confirm |
| 7 | Turn airplane mode on mid-submit, then retry | **One** payout, not two — the same request id is reused |

### Waiting and correcting

| # | Check | Expected |
|---|---|---|
| 8 | The pending state as an Employee | Read-only: amount, method, reporter, server time. No correct or confirm |
| 9 | The same screen as a Manager | Review/Correct and Confirm both offered |
| 10 | Correct the method to an account | The amount does not change |
| 11 | Have two people correct at once | The second is told someone acted first, and the screen refreshes |
| 12 | Deactivate the account, then reopen | The payout keeps its original label and is still confirmable |

### Confirming

| # | Check | Expected |
|---|---|---|
| 13 | Tap Confirm | A dialog lists invoice, phone, amount, method, reporter and report time, and says it cannot be treated as pending afterwards |
| 14 | Cancel that dialog | Nothing changes |
| 15 | Confirm with the connection dropped | It does **not** show as confirmed; the error says nothing changed |
| 16 | Confirm a refund somebody already confirmed | Told it was already confirmed; nothing recorded twice |
| 17 | Confirm on a day that has been closed | Refused, explaining the day is closed |
| 18 | After confirming | Success tone, confirmation time, amount, method, reporter, confirmer — and the phone still shown as held |

### The receipt

| # | Check | Expected |
|---|---|---|
| 19 | The receipt button before confirmation | Not offered |
| 20 | Share the receipt after confirming | **The PDF renders and the share sheet opens** — the appearance is the part only a device can judge |
| 21 | Read the PDF | Store, Refund Receipt, reference, original invoice, confirmation time, product and variant, masked identifier, gross, each adjustment, total, net, method/account, status |
| 22 | Look for cost or margin on it | Neither appears |
| 23 | Cancel the share sheet | The refund is still confirmed |
| 24 | Rename the account, share the receipt again | The **old** label, unchanged |
| 25 | The receipt in Arabic | Right-to-left, numerals legible, nothing clipped |

### Arabic and layout

| # | Check | Expected |
|---|---|---|
| 26 | The report sheet in Arabic | Labels, method control and amount read naturally |
| 27 | The keyboard over the reference field | The submit button is not hidden behind it |
| 28 | The confirmation dialog in Arabic | Fits without truncation on a small screen |

### What only a device can answer

Native share sheet behaviour · the PDF's real appearance and page breaks ·
haptics on report and confirm · bottom-sheet gestures · keyboard avoidance ·
Arabic **visual** mirroring · behaviour on a genuinely flaky connection.


## 9g. Suppliers and payables (J1) — **never touched on a device**

Nothing below has been performed. J1 was verified by a type checker, a test
runner, a web export and API-level scripts.

| # | Check | Expected |
|---|---|---|
| 1 | Open Suppliers as an **Employee** | Names and phones; **no** money column anywhere |
| 2 | Open a supplier as an Employee | "not shown to your role", not a zero balance |
| 3 | Open the same supplier as an Owner | Total bought, paid, still owed, and every delivery |
| 4 | Search by part of a name, then by phone | Both find it |
| 5 | Switch to Inactive, then All | Filters behave; an inactive supplier is labelled in words |
| 6 | Add a supplier that already exists | Explains it in place and suggests searching |
| 7 | Tap "Record a payment" | Outstanding shown; amount empty |
| 8 | Type more than is owed | Blocked with the amount owed named |
| 9 | Type a partial amount | The allocation appears, oldest delivery first, **before** sending |
| 10 | Submit | A dialog says a manager or owner must still confirm |
| 11 | Turn airplane mode on mid-submit, then retry | **One** payment, not two |
| 12 | The pending state as an Employee | Read-only, with a note that a manager must confirm |
| 13 | The same as a Manager | Confirm offered |
| 14 | Confirm | Dialog lists supplier, amount, method, reporter and report time |
| 15 | Confirm with the connection dropped | Does **not** show as confirmed |
| 16 | Confirm one somebody already confirmed | Told it was already done |
| 17 | Confirm on a closed day | Refused, explaining the day is closed |
| 18 | After confirming | Still-owed falls by exactly that amount; the delivery reads partly or fully paid |
| 19 | Deactivate a supplier, then open Receive | It is not in the picker |
| 20 | Open an old delivery from that supplier | Still shows the supplier it was bought from |
| 21 | Reactivate | It returns to the picker |
| 22 | The whole flow in Arabic | Labels, amounts and the allocation read naturally |
| 23 | The keyboard over the amount field | The submit button is not hidden behind it |

### What only a device can answer

Haptics on record and confirm · bottom-sheet gestures with a keyboard open ·
Arabic **visual** mirroring · behaviour on a genuinely flaky connection · the
allocation list on a small screen.

---

## 9h. The redesigned interface (UX pilot) — **never touched on a device**

The UX pilot changed the design system's foundations and rebuilt the role
landing screen. Everything below was verified by `tsc`, `expo lint`, a web
export and code inspection. **None of it has been seen on a physical phone**,
and several items below are things a web export structurally cannot answer.

**Setup:** an Android phone, portrait, one run in English and one in Arabic.
Sign in as each of Owner, Manager and Employee.

### The landing screen, per role

| # | Do this | Expect |
|---|---|---|
| 1 | Sign in as an **Employee** | A Home tab exists and opens — it used to be hidden entirely |
| 2 | Look at the Employee's Home | Sell / Receive / Inventory, and no money figures anywhere |
| 3 | Sign in as a **Manager** with work waiting | "Waiting on you" is the first thing below the title |
| 4 | Tap each waiting row | Lands on the right list, not a 403 |
| 5 | As **Owner**, read the health card | A sentence, not "92 · GREEN" |
| 6 | An Owner without `cost.view` (if one exists) | Profit tiles read as restricted, **never** as 0 |
| 7 | Tap Suppliers on Home | Opens the supplier list — this was unreachable before the pilot |
| 8 | Pull to refresh | Every section refreshes together |

### Money and figures

| # | Do this | Expect |
|---|---|---|
| 9 | Compare a column of prices (Home → stock, then a list) | Digits line up vertically; no ragged column |
| 10 | A very large total (millions) | Not truncated, not shrunk to unreadable |
| 11 | A screen where cost is hidden | An em dash, never `0.00` |

### Offline — **the most important thing on this list**

| # | Do this | Expect |
|---|---|---|
| 12 | Turn airplane mode on with the app open, then act | A red strip appears at the top and **stays** |
| 13 | Read the strip | Says nothing you confirm will be saved |
| 14 | Check it does not hide the header | It pushes content down, not over it |
| 15 | Check the top inset on a notched phone | Text clear of the status bar and the clock |
| 16 | Turn airplane mode off, make any request | The strip disappears by itself |
| 17 | Connect to wifi with **no internet** (a captive portal) | The strip still appears — this is the case a radio-based indicator gets wrong, and the whole reason it is not used |

### Arabic and RTL

| # | Do this | Expect |
|---|---|---|
| 18 | The whole landing screen in Arabic | Every string translated — no English left |
| 19 | The row layout in Arabic | Mirrored |
| 20 | Money in Arabic | Latin digits, and the figure itself does **not** mirror |
| 21 | The longest Arabic labels | Wrap onto a second line rather than truncating |
| 22 | The offline strip in Arabic | Wraps rather than pushing the icon off-screen |

### The component gallery (`/dev/gallery`)

| # | Do this | Expect |
|---|---|---|
| 23 | Money section | Three sample figures line up exactly |
| 24 | Inline notices | Each tone has a **different icon**, not one shape in five colours |
| 25 | The long-Arabic notice | Wraps cleanly |
| 26 | Workflow timeline | Done / current / pending differ in **shape** — squint and they should still be distinguishable |
| 27 | Timeline in Arabic | The rail mirrors; markers stay aligned with wrapped text |
| 28 | A disabled segmented control | The label is **readable**, not a ghost — this was the 1.3:1 defect |
| 29 | Every tappable thing | Nothing smaller than a thumb |

### What only a device can answer

Arabic font rendering, line-height and numeral shaping under Hermes ICU ·
whether `tabular-nums` is actually honoured by the platform font (the web export
proves nothing here) · the safe-area inset of the offline strip on a notched
phone · haptics · scroll performance of the landing screen on a low-end device ·
whether the strip's red is legible in direct sunlight.

---

## 9i. Reading an IMEI off a phone screen (Milestone C) — **never run on a device**

This section is the most device-dependent in the whole checklist. The parser is
pure and has 21 passing checks; **the camera and the native recogniser have
never been executed.** Expo Doctor passing is a compatibility check, not a
working camera.

**A development build is required.** This will not run in Expo Go — the native
ML Kit module is not in that binary. If the mode switch is absent on a device,
that is the guard working, not a bug.

**Setup:** an Android phone, a development build, portrait, one pass in English
and one in Arabic. A second phone to read from — ideally one dual-SIM and one
single-SIM.

### The three modes

| # | Do this | Expect |
|---|---|---|
| 1 | Open the scanner | It starts in barcode mode, exactly as before |
| 2 | Look for the mode switch | Present on a dev build; **absent in Expo Go** |
| 3 | Switch to read-from-screen | Hint says to dial `*#06#` |
| 4 | Point at a `*#06#` screen, tap Read | The IMEI appears within a second or two |
| 5 | Tap "Type instead" from **either** mode | The keypad opens — this must never be unavailable |
| 6 | Deny the camera, then reopen | Typing is still offered, and works |

### The reading itself — the part that matters

| # | Do this | Expect |
|---|---|---|
| 7 | Read a **dual-SIM** phone | Two IMEIs, and the words "one dual-SIM phone, not two phones" |
| 8 | Confirm it creates **one** unit | Not two. This is the phantom-device failure |
| 9 | Read a **single-SIM** phone | One IMEI, no invented second |
| 10 | Deliberately blur the shot | Either nothing found, or a valid IMEI — **never a wrong one** |
| 11 | If any substitution is shown | The changed characters are listed, e.g. `O→0` |
| 12 | Cross-check every digit against the screen | They match exactly. **Any mismatch is a stop-ship** |
| 13 | Read the same phone twice | The same IMEI; nothing duplicates |

### Conditions that break OCR in a real shop

| # | Condition | Expect |
|---|---|---|
| 14 | Direct sunlight / glare on the screen | Fails cleanly with "type it in", never a wrong read |
| 15 | Moiré (camera against an LCD at the wrong angle) | Same |
| 16 | A **cracked** screen across the digits | Same — this is common on returned phones |
| 17 | Low light | Torch helps; a failed read still says so |
| 18 | A phone set to **Arabic**, showing Arabic-Indic digits | Read correctly — the parser normalises them |
| 19 | A very dim or power-saving display | Fails cleanly |

### Privacy — verify, do not assume

| # | Do this | Expect |
|---|---|---|
| 20 | Read several IMEIs, then browse the phone's gallery and cache | **No photographs left behind** |
| 21 | Turn airplane mode on, then read a screen | OCR still works — recognition is on-device |
| 22 | Watch the network while reading (proxy or dev tools) | **No request carries an image**; only the resulting `/scan` lookup goes out |

### What only a device can answer

Whether ML Kit's accuracy is good enough on the screens this shop actually
sees · camera focus distance on a phone held 10–15 cm away · whether the torch
helps or worsens glare on a glossy display · how long a read takes on a low-end
Android · whether the capture button is reachable one-handed · haptics.

---

## 9j. Counting the day, one channel at a time (Milestone E) — **never run on a device**

The server behaviour is proven by 72 live checks over real HTTP. What follows
is only what a device can answer: whether the counting flow survives the way a
shift actually ends.

### The flow, as an Employee

| # | Do this | Expect |
|---|---|---|
| 1 | Open the closing screen as a **Store Employee** | The day, every channel, and how many are still outstanding |
| 2 | Enter the cash count and save it | Saved. **The day is not closed** and no lock appears anywhere |
| 3 | Force-quit the app, reopen, return to the screen | The cash count is still there — counting must survive an interruption |
| 4 | Enter **0** for an account | Recorded as a count, not as "not counted yet" |
| 5 | Tap "Cannot check now" on an account, leave the reason blank | The confirm button stays disabled |
| 6 | Give a reason and confirm | Recorded as skipped, with the reason visible |
| 7 | Look for a "close the day" button | **Absent**, and a line explains who finishes it |

### The flow, as a Manager or Owner

| # | Do this | Expect |
|---|---|---|
| 8 | Open the same day | Counts already entered by the Employee are shown, not blank fields |
| 9 | Close the day | Locks. The counted cash is **the Employee's figure**, not one you retyped |
| 10 | Reopen the screen | The signed-off view, with each channel's difference |
| 11 | Try to close again | Refused, in plain language |

### The parts most likely to be wrong on a real phone

| # | Check | Why it matters |
|---|---|---|
| 12 | The money keypad on each channel card | Several inputs on one scrolling screen is where keyboards fight layout |
| 13 | Scroll position after saving a count | Being thrown back to the top after every channel makes a five-account shop miserable |
| 14 | The same screen in **Arabic** | Amounts, signs and the skip reason must all read right-to-left correctly |
| 15 | A **negative** difference in Arabic | The minus sign must sit on the correct side of the figure |
| 16 | Go offline mid-count | Saving says so plainly; nothing silently discards a typed figure |
| 17 | A shop with **one** active account vs **four** | The single-account case should not feel like a form |

### Deciding a difference (Owner)

| # | Do this | Expect |
|---|---|---|
| 18 | Open a pending difference | Nothing preselected — no resolution, no person |
| 19 | Choose "Someone owes it" without picking a person | Submit stays disabled |
| 20 | Pick a person, write a two-character reason | Still disabled — the reason has to say something |
| 21 | Resolve it | The record shows the decision, the person and the reason |
| 22 | Open a **surplus** | Only "the shop covers it" and "a record was wrong" are offered |
| 23 | As the charged Employee, open your own record | You can see what you owe and why, with no special permission |

### What only a device can answer

Whether a five-channel count is genuinely faster than the notebook it replaces ·
whether the keypad obscures the save button on a small screen · whether the
skip reason field is reachable one-handed · whether an Employee understands
from the screen alone that they have not closed anything · whether the Arabic
layout of a signed difference is unambiguous at a glance.

---

## 9k. Targets (Milestone F) — **never run on a device**

Server behaviour is proven by 34 live checks. What follows is only what a device
can answer.

| # | Do this | Expect |
|---|---|---|
| 1 | Open **More** as a Store Employee | **Targets** is there — reading a goal is ungated |
| 2 | Open it | The shop's targets, plus any personal one set for you |
| 3 | Look for somebody else's personal target | Absent, and nothing hints it exists |
| 4 | Look for **Set a target** | Absent — that is `goal.manage` |
| 5 | Open the same screen as Owner or Manager | Every personal target, and the set button |
| 6 | Set one: leave the amount blank | Submit stays disabled |
| 7 | Choose **One person**, pick nobody | Still disabled |
| 8 | Set a target for this shop, this month | Appears immediately with progress already computed |
| 9 | Switch to **Including finished** | Archived targets appear; the reason is readable |

### The parts most likely to be wrong on a real phone

| # | Check | Why it matters |
|---|---|---|
| 10 | The state word next to the bar, at arm's length | The whole screen is worthless if the word is not the first thing read |
| 11 | A goal at **over 100%** | The bar must stop at full while the figure still says 103% |
| 12 | A goal with a very long person name | The name must not push the state chip off the card |
| 13 | The same screen in **Arabic** | The bar must fill from the right, and the percentage must sit correctly |
| 14 | A `sales_count` goal | Formatted as a plain number, never as money |
| 15 | Six or more active targets | Still scannable, or the screen becomes the dense grid the rules forbid |

### What only a device can answer

Whether the state word actually reads before the number at a glance · whether
the progress bar's fill is distinguishable from its track in bright sunlight ·
whether "128 a day over the 21 days left" is understood without explanation by
somebody in their first week · whether the Arabic bar direction reads as
progress rather than as depletion.

---

## 9l. Bringing in a stock list (Milestone G) — **never run on a device**

Server behaviour is proven by 41 live checks including a real `.xlsx` with
Arabic headers. What follows is only what a device can answer, and the file
picker is the part most likely to disappoint.

### The picker

| # | Do this | Expect |
|---|---|---|
| 1 | Open **More → Bring in stock** as a Store Employee | **Absent** — this is `import.run` |
| 2 | As Owner or Manager, tap **Choose a file** | The system picker opens |
| 3 | Pick a `.xlsx` from Google Drive / OneDrive | It uploads — cloud providers are where shop files actually live |
| 4 | Pick a `.xlsx` from WhatsApp downloads | Same. This is the single most common real path |
| 5 | Pick a file the picker reports as `application/octet-stream` | Still accepted — some Android providers report spreadsheets this way |
| 6 | Cancel the picker | Nothing happens, no error appears |
| 7 | Pick a large file on a slow connection | The button disables while it uploads and does not double-submit |

### The preview

| # | Check | Why it matters |
|---|---|---|
| 8 | The summary sentence is read before the numbers | The whole screen is worthless if "197 will be added" is not the first thing seen |
| 9 | A file with 200 rows | Still scrollable and responsive; the problem rows are at the top |
| 10 | The line numbers match the shop's own spreadsheet | Off by one here and every fix goes to the wrong row |
| 11 | The same screen in **Arabic** | Reasons, line numbers and counts all read right-to-left correctly |
| 12 | An Arabic product name from a `.xlsx` | Renders correctly — this is the reason `.xlsx` is recommended over CSV |
| 13 | The same list exported as **CSV from an Arabic Excel** | Likely mangled. Confirm the app does not pretend otherwise |

### Committing

| # | Do this | Expect |
|---|---|---|
| 14 | Tap **Add N to stock** | The phones appear in Inventory immediately afterwards |
| 15 | Go back and tap it again | Refused, in plain language |
| 16 | Import the same file a second time | Every row refused as already in stock |
| 17 | Import an accessory sheet twice | The quantity adds up on one row, not two rows |

### What only a device can answer

Whether the picker can actually reach the file a shop keeps in WhatsApp ·
whether a 200-row preview scrolls acceptably on a low-end Android · whether the
summary sentence is understood without explanation by somebody in their first
week · whether an Arabic `.xlsx` from a real shop's real Excel round-trips
intact.

---

## Milestone H — stock with another shop

Needs **two accounts on two devices**, or two shops' Store Account IDs. Most of
this cannot be answered from a simulator, because the whole point is what two
different people see.

### Finding each other

| # | Do this | Expect |
|---|---|---|
| 1 | Search a shop by its **Store Account ID** | Name, city, logo, and a badge that openly says it is coming |
| 2 | Search two characters | Nothing, and a line telling you three are needed |
| 3 | Search a shop that does not exist | The same empty answer as one that blocked you — no difference at all |
| 4 | Look hard at the preview | No branches, staff, stock, prices or phone number anywhere |

### Sending stock

| # | Do this | Expect |
|---|---|---|
| 5 | **Scan** a phone into a consignment | Added with its model, from the camera, without typing |
| 6 | Scan a phone that is already sold | Refused while you are still holding it |
| 7 | Scan the same phone twice | Refused as already on the list |
| 8 | Send it, then check Inventory | Shown as out with another shop, not as gone |
| 9 | On the **other** device, open the request | The phones and the asking price. **No cost, no margin** |

### The money

| # | Do this | Expect |
|---|---|---|
| 10 | Sell a consigned phone on device 2 | Device 1 is told it sold, and never sees the price it went for |
| 11 | Report a payment on device 2 | Device 1 sees it as reported, and the balance has **not** moved |
| 12 | Confirm it on device 1 | Now the balance drops |
| 13 | Return a phone as **damaged** | It goes to faulty for inspection, never straight back on the shelf |
| 14 | Block the other shop, then look at what is owed | Still owed. Blocking stopped new business and erased nothing |

### What only a device can answer

Whether scanning into a consignment is fast enough to do with a customer
waiting · whether "Waiting / Agreed / Settled" reads correctly to somebody who
has never used the app · whether the sender genuinely cannot find a resale price
anywhere on their screen · whether the Arabic RTL layout of the two-party
timeline is followable.

---

## Milestone I — money owed

Again **two accounts**, and the second half needs both.

| # | Do this | Expect |
|---|---|---|
| 1 | Record "they owe us 20,000" | Proposed. Not yet a debt |
| 2 | Open it on the other device | Reads as **we owe them**, same amount |
| 3 | Try to accept your own proposal | Refused |
| 4 | Counter with 18,000, then accept on the first device | Agreed at 18,000, and the amount can no longer be edited |
| 5 | On the debtor's device, say you paid 5,000 | Reported. The balance still says 18,000 |
| 6 | Look for a confirm button on the debtor's device | There isn't one |
| 7 | Confirm on the creditor's device | 13,000 remaining |
| 8 | Reverse that payment with a reason | Back to 18,000, and both entries still in the history |
| 9 | Write off 8,000 | 10,000 remaining, and no money moved |
| 10 | Add a loan to somebody **not** on the app | Recorded by name. No account is created for them |
| 11 | Open the daily closing | The loan reminder appears, and says plainly it changes no figure |
| 12 | Count the drawer | The expected cash is unchanged by any of the above |

### What only a device can answer

Whether "they owe us" and "we owe them" are unambiguous at a glance in both
languages · whether the RTL rendering keeps the direction chip beside the right
number · whether somebody in their first week understands that reporting a
payment is not the same as being paid · whether the closing reminder is read as
a nudge rather than as something they failed to count.

---

## Milestone J — working without a connection

**None of this can be answered from a simulator or a web export.** It needs a
real phone, real airplane mode, and Android's real willingness to kill a
backgrounded app.

### The sale, which is the point

| # | Do this | Expect |
|---|---|---|
| 1 | Build a cart of three phones, then turn on **airplane mode** | The cart is still there. The banner says there is no connection |
| 2 | Look at **Charge** | Disabled, and the line above says why — the cart is safe but nothing can promise the phone is still unsold |
| 3 | **Kill the app** from the recents list, reopen it | The cart is still there |
| 4 | Turn the connection back on | Charge becomes available. Nothing was sent while you were dark |
| 5 | Complete the sale, then kill and reopen | The cart is **empty** — a finished sale must not come back |

### Counting the day

| # | Do this | Expect |
|---|---|---|
| 6 | Enter counts for two channels, then go offline | The counts stay |
| 7 | Try to close the day | Refused, in plain language |
| 8 | Reconnect | The day can be closed, and the figures are the ones you typed |

### The four things that may wait

| # | Do this | Expect |
|---|---|---|
| 9 | Offline, report an expense | "Waiting to send". Never "sent" |
| 10 | Open **Waiting to send** from the More menu | It is listed, with a count |
| 11 | Reconnect and watch | It goes on its own. Only then does it read as sent |
| 12 | Offline, report a loan payment | "Waiting to report to the server", and explicitly not confirmed |
| 13 | Reconnect, then check the loan | The balance is **unchanged** until the other side confirms |

### Wi-Fi that lies

| # | Do this | Expect |
|---|---|---|
| 14 | Join a Wi-Fi network with **no internet** | The app still says there is no connection — it tests the server, not the radio |
| 15 | Stop the API server while the phone is on good Wi-Fi | Same answer. Reaching the router is not reaching the shop's data |
| 16 | Leave a request hanging (throttle the server) | It gives up after 20 seconds and says the server did not answer in time — **not** that it failed |

### The shared counter phone

| # | Do this | Expect |
|---|---|---|
| 17 | Offline, start an expense as user A. Sign out | The draft is not lost |
| 18 | Sign in as user B on the same phone | B sees **none** of A's work |
| 19 | Sign back in as A | A's work is there again |
| 20 | Switch branch as the same user | The queue changes with the branch |

### Losing the connection is not a security event

| # | Do this | Expect |
|---|---|---|
| 21 | Go offline for ten minutes, then come back | No OTP, no re-login, and the trusted device is still trusted |
| 22 | Background the app for an hour, then foreground it | Anything waiting is sent. Still no OTP |

### Arabic

| # | Do this | Expect |
|---|---|---|
| 23 | Switch to Arabic and repeat 9–13 | The state chips read correctly right-to-left, and "waiting" is never mistakable for "sent" |

### What only a device can answer

Whether a first-week employee understands that "waiting to send" is not "sent" ·
whether Android actually restores the cart after a real low-memory kill rather
than a manual swipe · whether the 20-second timeout feels right on a slow
Mauritanian mobile connection or merely feels broken · whether the Sync centre is
somewhere people think to look, or whether the count needs to appear on the tab
bar · whether an employee who sees "needs your attention" knows what to do next.

---

## Milestone J.1 — drafts on a real phone

Every one of these needs a real Android low-memory kill, not a simulator.

| # | Do this | Expect |
|---|---|---|
| 1 | Scan ten phones into a receiving session, kill the app, reopen | All ten still there, with the supplier still chosen |
| 2 | Look for the notice | It says when the work was saved and offers to start fresh |
| 3 | Start an expense, kill, reopen | Every field back as typed |
| 4 | Build a consignment proposal, wait a day, submit | Any phone sold in between is dropped by name; the rest still submit |
| 5 | Take a return at the counter, kill, reopen | Reason and condition notes back; the **sale** is looked up fresh |
| 6 | Submit successfully, then reopen the form | Empty — a finished job must not come back |
| 7 | Submit and get refused, then reopen | Still there. A failure must not destroy the work |
| 8 | Sign out, sign in as somebody else | None of the first person's drafts are visible |
| 9 | Sign back in as the first person | Their drafts are there again |
| 10 | Pick an import file, kill, reopen | Nothing restored, and nothing implies stock was added |

## Milestone K — subscription, on a device

Needs a platform operator to move the period; the app cannot do it.

| # | Do this | Expect |
|---|---|---|
| 11 | Open **Subscription** while active | Days remaining, and the website-via-WhatsApp wording. **No price, no button, no link** |
| 12 | Move the period to just past its end | Grace, with exact hours left. Everything still works |
| 13 | Sell something during grace | It goes through |
| 14 | Move past 72 hours | Read-only. The message says nothing was deleted |
| 15 | Try to sell | Refused, in plain language, naming the subscription rather than a permission |
| 16 | Open sales history, exports, closings | All still readable |
| 17 | Sign out and back in | Works — authentication is never blocked |
| 18 | Queue an expense offline, then let it send while expired | It becomes **needs attention** and stops. It must not retry forever |
| 19 | Fill every staff place, then re-enable somebody | Refused, naming seats. Nobody is switched off automatically |
| 20 | Go offline and open Subscription | Says it is showing what the phone last knew — never claims to be current |
| 21 | Repeat 11–20 in Arabic | Reads correctly right-to-left; urgency is not carried by colour alone |

## Milestone L — where the money is

| # | Do this | Expect |
|---|---|---|
| 22 | Open **Where the money is** for today, 7 and 30 days | Profit first, then cash, then owed, then differences |
| 23 | Read the cash block | It says outright that it is not profit |
| 24 | Approve a return, then pay the refund the next day | Profit moves once, on the approval day. The payout shows as cash only |
| 25 | Look at "owed and owing" | Labelled as standing right now, not for the period |
| 26 | Find a figure that is not tracked | Named as unavailable — never drawn as zero |
| 27 | Open a period with no trading before it | Says there is nothing to compare with, rather than a percentage |
| 28 | Switch branch | The figures change to that branch alone |
| 29 | Sign in as somebody without `report.view` | The screen says it is a role boundary, not an empty shop |
| 30 | Repeat in Arabic | Money aligns correctly in RTL; every trend has a sign and words, not just colour |

### What only a device can answer, across all three

Whether a first-week employee reads "saved on this phone" as *not sent* ·
whether the grace warning is urgent enough to act on without being alarming ·
whether "where the money is" answers the question a shopkeeper actually opens it
with · whether Arabic numerals and money alignment survive RTL on a small screen
· whether any of it is legible in daylight on a cheap handset.


## 9h. Language and the back gesture (M) — **never touched on a device**

Nothing below has been performed. M was verified by a type checker, a linter, a
key/placeholder parity script, a bundle grep and live HTTP calls. **The two
things this milestone is actually about — a gesture and how words look on a
screen — are exactly the two a device is required to judge.**

| # | Check | Expected |
|---|---|---|
| 1 | Push into any screen, swipe from the **left edge** | Goes back, and follows your finger rather than snapping |
| 2 | Swipe from the **middle** of the screen | Nothing. That is intended — see `docs/21` §6h |
| 3 | On `inventory`, `sales`, `returns`, `transfers`, drag the filter chips sideways | Chips scroll; the screen does **not** start going back |
| 4 | Swipe back mid-transition, then reverse | No stuck or blank screen |
| 5 | Open More as an **Employee** | Language row is present — it is never gated |
| 6 | The row's value | The current language, in its own words |
| 7 | Tap it, choose **Français** | Whole app is French immediately, no restart asked for |
| 8 | Read Sell, Closing and Suppliers in French | Nothing clipped, nothing overflowing a button |
| 9 | Choose **العربية** | Words change, and a restart notice appears |
| 10 | Force-close and reopen | Layout is now genuinely right-to-left |
| 11 | Swipe back in Arabic | The gesture follows the RTL direction |
| 12 | Switch back to English from Arabic | Restart notice again; layout returns after relaunch |
| 13 | Kill and reopen | The chosen language persisted |
| 14 | A phone whose system language is French, signed in fresh | App starts in French on its own |
| 15 | Share a receipt in French | Headings and totals read naturally |
| 16 | Settings → WhatsApp summary language as Owner | Three options; French saves and reloads |

### What only a device can answer

Whether the edge-swipe genuinely fights the horizontal filter rows · whether
French text overflows buttons sized for English · whether Arabic still mirrors
correctly now that a third language shares the picker · how the language row
reads to somebody who cannot read the rest of the menu.


## 9i. IMEI intake by barcode and QR (O) — **never touched on a device**

Nothing below has been performed. O was verified by a type checker, a linter,
pure tests, a web export and live HTTP calls. **A camera is exactly what none of
those exercise**, and this milestone is entirely about a camera.

| # | Check | Expected |
|---|---|---|
| 1 | A phone whose `*#06#` screen shows a scannable code | Reads it, result appears at once |
| 2 | A phone whose screen shows only digits | Manual entry is visible without hunting, and works |
| 3 | A raw IMEI barcode on a box label | One phone, IMEI 1 filled |
| 4 | A QR carrying both labelled IMEIs | **One** phone with two identifiers — never two units |
| 5 | Hold the camera steady on one code for 5 seconds | **One** result, one haptic; no repeats |
| 6 | Poor focus | Either nothing, or a refusal — never a wrong number accepted |
| 7 | Glare on the screen | Same |
| 8 | Deny camera permission | Explains, and offers typing |
| 9 | Background the app mid-scan, return | No stuck lock; scanning resumes or the result is still there |
| 10 | Scan, then tap **Add second IMEI** | IMEI 1 stays visible while the camera resumes |
| 11 | Scan the SAME number as IMEI 2 | Refused in words; IMEI 1 survives |
| 12 | Remove IMEI 2, then accept | Saves as a single-IMEI phone |
| 13 | Scan an unknown product, tap **Create product** | Product form opens; **Product barcode is EMPTY** for an IMEI scan |
| 14 | Scan a product barcode, tap **Create product** | Product barcode **is** prefilled |
| 15 | Complete product creation | Returns to intake automatically with the IMEI still held |
| 16 | Cancel product creation | Returns to intake with the scan still present |
| 17 | Scan a dual-SIM phone by its FIRST IMEI, later by its SECOND | Same phone both times |
| 18 | A phone already in inventory | Says so; no duplicate is created |
| 19 | The whole flow in Arabic | Result and confirmation read naturally and mirror correctly |
| 20 | Large text | Result panel does not clip |

### What only a device can answer

Whether the camera genuinely stops between the first detection and `Scan
again` · haptics firing once · whether `*#06#` on the shop's actual stock shows
a code at all · focus and glare in real shop lighting · whether the result panel
fits a small screen with two IMEIs and a TAC line.

---

## Signing in, and the Money tab (CP1–CP3)

Verified in a real browser at 1280×720 and at 375×812 (phone width), in
English, Arabic and French, signed in as an Owner, a Manager and an Employee.
**None of this was run on a physical device** — the rows below are what a
device still has to answer.

| # | Do this | Expect |
|---|---|---|
| 1 | Open sign-in | **Two** fields: the identifier and the password. No Store ID |
| 2 | Look at the fields before typing | Both **empty**. No store code, no `owner` |
| 3 | Sign in with a phone number | Works |
| 4 | Sign in with the personal ID from Settings | Works |
| 5 | Type the personal ID in lower case | Works |
| 6 | Type a phone number with spaces | Works |
| 7 | Type a Store Account ID as the identifier | Refused, in the same words as any wrong credential |
| 8 | A wrong password | Refused — same wording as an unknown identifier |
| 9 | A disabled account | Refused — same wording again |
| 10 | Settings → Your personal ID | Shown, copyable, described as **not** a password |
| 11 | Settings → Store Account ID | Described as a support reference, **not** something to type at sign-in |
| 12 | The bottom bar | Home · Sell · **Money** · Inventory · More |
| 13 | Open Money | Cash & accounts, Expenses, Daily closing, Loans — no back arrow, no `(tabs)` label |
| 14 | Open More | Money is **not** there |
| 15 | As an Employee | The Money tab is still present, showing only what they may open |
| 16 | Open an old `/hub/money` link | Lands on the Money tab |
| 17 | The whole bar in Arabic | Mirrors correctly; no label clipped |
| 18 | Large text, small screen | Five labels still readable; nothing scrolls sideways |
| 19 | Sign in on the web build | The page **renders** — Sync Center says queuing is unavailable there |

### What only a device can answer

Whether a password manager actually offers the saved credential into the single
identifier field · whether the phone keyboard makes an alphanumeric personal ID
awkward in practice · whether five tabs stay comfortably thumb-reachable on a
small phone · whether the Arabic tab bar mirrors correctly under the native
`I18nManager` (the web build cannot flip direction without a relaunch) · how
the shop picker reads to somebody who genuinely works at two shops.

---

## Signing in by contact, and dark mode (CP1–CP3)

Verified in a real browser at 1280×720 and 375×812, in English, Arabic and
French, signed in as Owner, Manager and Employee. **None of it was run on a
physical device** — the rows below are what a device still has to answer.

| # | Do this | Expect |
|---|---|---|
| 1 | Open sign-in | **Two** fields: "Email or WhatsApp number", and Password |
| 2 | Read the helper line | "Enter either your email or WhatsApp number." |
| 3 | Sign in with an email | Works, whatever the capitalisation |
| 4 | Sign in with a WhatsApp number typed as it is printed | Works — `43 21 09 87` and `+22243210987` are one number |
| 5 | Let the password manager fill it | Offers the saved credential into the single field |
| 6 | A wrong email, a wrong number, a wrong password, a disabled account | All four refused in **identical** words |
| 7 | Type a Store ID as the identifier | Refused like any wrong credential |
| 8 | Settings → your contact details | Shown, per existing permissions |
| 9 | Change somebody's email or number | Asks for **your** password, then signs that person out |
| 10 | Try to clear the only contact somebody has | Refused, in words |
| 11 | Look for a two-step-verification switch | There is **none** — deliberately |
| 12 | Account & security → Appearance & language | Dark-mode switch and Language, together |
| 13 | Look for a second language selector anywhere | There is **none** |
| 14 | Turn dark mode on | The whole app changes at once, no reload |
| 15 | Force-quit and reopen | Still dark — and **no white flash** before it appears |
| 16 | Look at the status bar in each theme | Light glyphs on dark, dark glyphs on light |
| 17 | Open Sell, Money, Inventory, More, the scanner and a sheet in dark | No light panel anywhere; no text you have to squint at |
| 18 | Switch language while dark | Language changes, **theme stays dark** |
| 19 | Switch theme while in Arabic | Theme changes, **language stays Arabic** |
| 20 | Arabic in dark | Mirrors correctly; nothing clipped |
| 21 | Large text on a small screen | Nothing clipped, nothing scrolls sideways |
| 22 | A shared counter phone: sign out, sign in as somebody else | The theme stays as the shop set it |

### What only a device can answer

Whether the splash-to-app handoff is genuinely flash-free on a **cold start**
on a cheap Android — the web build cannot show a native splash at all · whether
the dark palette is legible on a real **OLED** panel, and whether the near-black
canvas smears on scroll · whether either theme survives **direct sunlight** on a
shop counter · whether the **camera** overlay is still readable in dark mode
with a live preview behind it · whether the **keyboard** appears in the right
appearance for the theme · what happens to the theme across **background and
foreground** and a low-memory kill · whether Arabic **RTL** mirrors correctly
under the native `I18nManager` — the web build cannot flip direction without a
relaunch, so its RTL is not evidence · whether the language-change restart
notice is understood, and whether unsaved drafts survive it.

---

## Platform control — what a device still has to answer

The backend contract is verified by 36 live HTTP/MySQL checks. The three web
surfaces and the mobile integration are **not built yet** (see `docs/37`), so
most device rows arrive with them. What already needs a device:

| # | Do this | Expect |
|---|---|---|
| 1 | Sign in on a phone as the Owner of a **pending** business | Signs in; the operational app refuses; a status screen explains why |
| 2 | Same, for a **suspended** business | Distinct state and wording — never "expired" |
| 3 | Same, for **expired** | Everything still readable; writes refused |
| 4 | Activate the business from the admin API, then pull to refresh | The app enters without reinstalling |
| 5 | Watch the pending screen in Arabic and French | Reads naturally; RTL mirrors |

### Not yet testable, because it is not built

The `Create account` link and the registration, customer-portal and
administration websites. The link deliberately does not ship until there is a
signup URL to point it at — dead UI would be worse than waiting.

---

## Create account, and subscription states (Phase 2)

Browser-verified at 375×812 and desktop, in EN/AR/FR, light and dark.
**Browser verification is not device verification** — the rows below are what a
phone still has to answer.

| # | Do this | Expect |
|---|---|---|
| 1 | Open sign-in with no account | A clear **Create account** action under Sign in |
| 2 | Tap it twice, quickly | **One** browser opens, not two |
| 3 | Tap it with no signup URL configured | A plain message, not a dead tap |
| 4 | Tap it with no browser available | A different message — the two causes are distinct |
| 5 | Complete registration on the phone's browser, then return | The account exists; the app still says pending |
| 6 | Sign in as a **pending** Owner | "Waiting for activation", no till, a link to the account page |
| 7 | Sign in as a **suspended** Owner | "Access suspended" — never "expired" |
| 8 | Sign in as an **expired** Owner | Everything readable; new entries paused |
| 9 | Have the business activated, then tap **Check again** | Straight into the app — no reinstall, no clearing storage |
| 10 | The blocked screen in Arabic | Mirrors correctly; nothing clipped |
| 11 | The blocked screen at large text | Both buttons still reachable |
| 12 | Look anywhere for a Store ID or personal ID | There is none |

### The website on a real phone browser

| # | Do this | Expect |
|---|---|---|
| 13 | Register at 375px wide | Every field reachable; no sideways scrolling |
| 14 | Register in Arabic | Form mirrors; the price breakdown reads correctly |
| 15 | Open the administration portal on a phone | Tables become cards, not a squeezed grid |
| 16 | Switch theme and language on the phone | Both persist across a reload, independently |

### What only a device can answer

Whether the browser handoff actually works from Expo Go and from a standalone
build · whether the returning-from-browser path keeps the login screen's state ·
whether a real phone keyboard covers the code field during verification ·
whether the account page is readable on a cheap phone in sunlight · whether the
`Check again` round trip is fast enough on a slow connection that somebody
believes it worked.


## 9j. Mobile registration (CP3) — **never touched on a device**

Nothing below has been performed. CP3 was verified by a type checker, a linter,
Expo Doctor, pure and drift tests, and a web export — **none of which opens a
keyboard, a browser or an app switcher**, which is most of what this flow is.

| # | Check | Expected |
|---|---|---|
| 1 | Tap **Create account** on the sign-in screen | A screen opens **in the app**. No browser. |
| 2 | Read the form | No Store ID, no personal or national ID, nothing internal |
| 3 | Submit with neither contact | Refused, saying either one will do |
| 4 | Register with an email only | Accepted |
| 5 | Register with a WhatsApp number only | Accepted |
| 6 | Register with both | Accepted |
| 7 | Mismatched password confirmation | Refused, both password problems shown at once |
| 8 | Tap Continue twice, fast | **One** account, not two |
| 9 | Lose the connection mid-submit, retry | Still one account — same idempotency key |
| 10 | The verification screen | Shows the masked destination it actually sent to |
| 11 | Enter a wrong code | Refused; the screen stays usable |
| 12 | Wait out the resend countdown, resend | A new code arrives; the **older one stops working** |
| 13 | Enter the correct code | Signed in, and the browser opens at the portal |
| 14 | Turn off networking, then verify | Session survives; a retry action is offered |
| 15 | Deny the browser / no browser installed | **Still signed in and pending** — registration does NOT restart |
| 16 | Kill and reopen the app | Still signed in, still pending, no re-registration |
| 17 | Try to reach stock or sales while pending | Blocked |
| 18 | The whole flow in Arabic | RTL reads correctly; the keyboard does not cover the button |
| 19 | The whole flow in French | Reads naturally |
| 20 | Large text, 375 px | Nothing clipped, every field reachable |

### What only a device can answer

Whether the keyboard covers the submit button · whether the browser hand-off
actually lands signed in on a real phone · whether returning from the browser
restores the pending screen · haptics and focus order · Arabic **visual**
mirroring of the form.

### 9j — what a browser has since covered, and what it has not

The web export of the app was served from the staging edge and driven in a
browser, so some of §9j is no longer untouched. **A browser is not a phone**, and
the split is recorded honestly rather than counted as done.

**Covered in a browser** (rows 1, 2, 3–7 by API, 10, 13):

- `Create account` opens a screen **in the app** — measured: the route went from
  `/login` to `/register` with **zero** `window.open` calls;
- the form asks for business name, branch, city, name, email, WhatsApp number
  and a password twice — **no Store ID and no personal ID**;
- the verification screen shows the **masked** destination it actually sent to,
  and says no real message was sent;
- the correct code signed the Owner in and the portal opened, landing on the
  account page as that shop.

The app's own request order settles row 13's ordering question:

```
POST /platform/register
POST /platform/register/verify/start
POST /platform/register/verify/confirm   ← the session is issued here
POST /platform/portal-handoff            ← authenticated; needs that session
GET  /platform/portal-session?t=…        ← only now does a browser open
```

The handoff **cannot** precede the session, because it is an authenticated
route. Row 13 is therefore proved rather than asserted.

**Still device-only.** Rows 8, 9, 11, 12, 14–20 remain untouched, and row 15 is
the one that matters most: *deny the browser, or have none installed — the Owner
must stay signed in and pending, and registration must NOT restart.* On the web
export a browser cannot be refused the way a phone refuses one, so this was not
exercised. It stays pinned by unit test and by the ordering above, and it is the
first thing to try on real hardware.

Also untouched, and only a device can answer: whether the keyboard covers the
submit button, whether returning from the browser restores the pending screen,
haptics and focus order, and Arabic **visual** mirroring of the form.

## 9k. The language switcher and the blocked-subscription portal

Verified in a browser against the exported app, on the same origin as the
staging API. **A browser is not a phone**, and the split is recorded rather than
counted as done.

**Covered in a browser:**

| Check | Result |
| --- | --- |
| Sign-in screen carries a language switcher | English · Français · العربية, no flags |
| Account-creation screen carries one | yes |
| Copy changes immediately | *Connectez-vous à votre boutique* · *سجّل الدخول إلى متجرك* |
| The preference persists | `erp.language` = `fr` / `ar` / `en` |
| Switching mid-form keeps typed fields | yes — values still in place afterwards |
| Arabic reads naturally and aligns right | yes, at 375 px |
| No restart notice before anybody switches | yes (it used to show on load) |
| The staging banner is absent | on every one of the 68 exported routes |

**Still device-only.** Layout **mirroring** for Arabic is native: React Native
applies `I18nManager.forceRTL` at startup, which the web export cannot exercise
at all — on web the document direction never flips. The logic is pinned by test
(direction follows the language *both* ways), and the notice tells the reader a
relaunch is needed, but **only a device shows whether the mirrored layout is
actually right**. That is the first thing to check on real hardware, together
with §9j row 15 — deny the browser and confirm registration does not restart.

The blocked-subscription screen's portal handoff was proved over HTTP, not on a
phone: an Owner mints a ticket (`201`) and a Manager of the same shop is refused
(`403`). What a device still owes is the tap itself — that the browser opens,
lands signed in, and that returning to the app leaves the session intact.

## 9l. Brand and model selectors

Verified in a browser against the exported app on the staging origin. **A
browser is not a phone.**

| Check | Result |
| --- | --- |
| Brand list, in order, `Other brand` last | 13 brands ✓ |
| Redmi and POCO listed independently | ✓ |
| Model disabled until a brand is chosen | "Choose a brand first" ✓ |
| Samsung's models, newest first | 67, `Galaxy S26` family first ✓ |
| Family shown under each model | ✓ |
| `Other model — enter manually` always last | ✓ |
| Picking a model fills the row | `Galaxy A56` ✓ |
| `Other brand` reveals the manual field | ✓ |
| Changing the brand clears the model **only** | a typed variant survived ✓ |
| Arabic, right-aligned, 375 px, no overflow | ✓ |

**Still device-only.** Whether the expanding list is comfortable to scroll with
a thumb while holding a phone in the other hand; whether the keyboard covers
the search box on a short screen; whether Arabic layout **mirroring** (native,
applied at startup) puts the check mark on the correct side. The web export
never flips direction, so none of those can be judged here.

Recognition itself was proved over HTTP rather than by scanning: **20/20**
synthetic IMEIs resolved to Apple and the intended model. What a device still
owes is the camera — that scanning a real barcode produces the same result the
API already gives.

## 9m. The scanner — still unverified, and now easier to verify

A printable sheet of the fixture's synthetic identifiers now exists:

```bash
APP_ENV=staging npx ts-node scripts/staging-scan-sheet.ts > sheet.html
```

20 phones · 25 codes (20 primary, 5 secondary) · Code 128 · Luhn-valid by
construction · not one of them a real device.

### 🔴 What is still pending, stated without hedging

**No camera has read anything.** The web export, the HTTP tests and Expo Doctor
are none of them a camera, and none of them may be described as one.

| # | Check | Status |
| --- | --- | --- |
| 1 | Point the camera at a primary IMEI barcode | **pending** |
| 2 | The scanned value matches the printed digits exactly | **pending** |
| 3 | Recognition suggests Apple and the right model | proved over HTTP; **not scanned** |
| 4 | The suggestion is a suggestion — nothing is selected for you | proved over HTTP; **not scanned** |
| 5 | Scan a secondary IMEI: the same one phone is found | proved over HTTP; **not scanned** |
| 6 | Scan two codes that disagree: it asks rather than choosing | proved over HTTP; **not scanned** |
| 7 | Scan in poor light / at an angle | **pending** |
| 8 | A damaged or partial code fails safely | **pending** |
| 9 | The camera permission prompt reads correctly in AR and FR | **pending** |
| 10 | Nothing is written before somebody confirms | proved over HTTP; **not scanned** |

Rows 3–6 and 10 have been proved against a real server over real HTTP. That
proves the RULES. It does not prove the camera, the decoder, or what happens
when a shopkeeper is holding a phone in one hand and a handset in the other.

## 9n. The scan sheet, and the ten checks only a phone can settle

### Regenerate and open it

```bash
cd backend
APP_ENV=staging npx ts-node scripts/staging-scan-sheet.ts > ../scan-sheet.html
```

Output: `C:\wamp64\www\PhoneStoreERP\scan-sheet.html` — open it in a browser and
print it, or leave it on a second screen and scan from there. White, dashed
borders on the refuse cases, expected result printed beside every fixture, and
no internal database ids anywhere on it.

**31 cards · 29 Code 128 barcodes · 2 QR codes.** All ten fixture types, plus
the twenty stock phones.

The two QR payloads are labelled, which is how they are met in the wild:

    2 · IMEI: <synthetic-imei>
    3 · IMEI1: <synthetic-primary>
        IMEI2: <synthetic-secondary>

Black modules on white, medium error correction, four-module quiet zone.
Generated with `qrcode`, a backend **devDependency** — it is not in the app,
not in production, and not in the mobile bundle.

> **Generating a fixture correctly is not decoding it.** The generator proves
> the symbol is right. Whether a camera reads it through glass, at an angle, in
> a shop's lighting is a question only a phone answers.

### 🔴 The user-run checklist — none of this has happened

| # | Check | Expected |
| --- | --- | --- |
| 1 | Scan a stock IMEI | A result appears **immediately** on the first callback |
| 2 | Keep the code in frame | The camera **pauses** while the result is showing |
| 3 | Hold it there several seconds | **One** result and **one** haptic, not a stream |
| 4 | Tap rescan | The lock releases and it reads again |
| 5 | Scan case 3 — the dual-IMEI QR | Both identifiers shown as **one** phone |
| 6 | Scan case 6 — unknown TAC | Accepted, **no** brand and **no** model guessed |
| 7 | Scan cases 7, 8, 9, 10 | Each **refused**; nothing is stored |
| 8 | Scan case 11 — EAN-13 | Treated as a product barcode, never as an IMEI |
| 9 | Scan case 4's IMEI 1, then IMEI 2 | Both find the **same existing unit** |
| 10 | Repeat in Arabic | Reads correctly right-to-left; the result panel is not clipped |

Rows 6–9 have been proved over real HTTP. **That proves the rules, not the
camera** — not the decoder, not the focus, and not what happens with a phone in
one hand and a handset in the other. Row 5 additionally needs the QR fixtures.

Web export, HTTP tests and Expo Doctor are none of them a camera and are not to
be described as one.
