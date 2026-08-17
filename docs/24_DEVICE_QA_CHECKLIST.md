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
