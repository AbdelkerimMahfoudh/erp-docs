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
| 5.9 | Scan an IMEI **already in your stock** | "This phone is already in inventory", with the product and branch. **Use this IMEI is disabled**; Scan again, manual entry and Cancel still work | |
| 5.10 | Scan an IMEI of a phone your shop has **sold before** (not in stock) | **No warning.** Recognising the model is not the same as holding the handset | |
| 5.11 | Check the warning carefully | **No cost, no margin, no other company or branch you cannot see** | |

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

## 9o. The first physical-device test — what it found

**A phone was finally used, and it found seven defects.** Every one survived
TypeScript, the linter, Expo Doctor, a 68-route web export and a 20/20 HTTP
recognition run. That is the finding worth keeping: the automated gates were
all green and the feature did not work.

### Reproduced on the device

| # | What happened |
| --- | --- |
| 1 | A result appeared |
| 2 | …and the camera carried on scanning behind it |
| 3 | Tapping `Use this IMEI` put the scanner back to scanning |
| 4 | The accepted result appeared only after closing the sheet by hand |
| 5 | `Saisir manuellement` sat inside the scanner, under a live viewfinder |
| 6 | With the keyboard open on the intake form, the footer was unreachable |
| 7 | Tapping outside an input did not close the keyboard |

### Corrected — and **not** device-verified

The fixes are in `erp-mobile` `b0b4a9f` with twenty tests. **Only a phone can
confirm them.** Retest sequence:

1. Scan the raw valid IMEI (case 1 on the scan sheet).
2. **Confirm the camera pauses** — the preview should stop, not merely stop
   reacting.
3. Tap `Use this IMEI`.
4. **Confirm the scanner closes by itself.**
5. **Confirm the full result is on the intake page** — identifiers, and the
   brand/model suggestion — without closing anything by hand.
6. Open the keyboard on the form and **scroll to the footer**.
7. **Tap a blank area** and confirm the keyboard closes, then tap the submit
   button once and confirm it fires on the first tap.

Also worth a look while you are there: one haptic per scan, not two; and
`Scan again` is the only thing that should restart the camera after a result
(`Add second IMEI` restarts it too, deliberately — it means "now scan the other
SIM").

### What could not be moved

The keyboard fallback inside the scanner stays for the **no-camera** case. If
the permission is denied there is nothing else on that screen, and removing it
would strand the user.

## 9p. The second physical-device test — the fix broke two other things

`b0b4a9f` corrected the seven defects in §9o and introduced two more. Both were
the same kind of error: **right about the symptom, wrong about the mechanism.**

### Reproduced on the device

| # | What happened |
| --- | --- |
| 1 | Detection froze the last camera frame — it looked like a screenshot |
| 2 | The IMEI was often not visible in that frame at all |
| 3 | After accepting and continuing, the recognised product disappeared |
| 4 | The product was not preserved into the intake workflow |

**Why the frozen frame.** `active={false}` stops the camera and leaves its last
frame on screen. That frame is whatever the sensor held when the decoder fired,
so the "result" was a photograph of a barcode usually half out of shot. The
camera is now **unmounted**, and the panel shows the decoder's payload as
selectable text — what is on screen no longer depends on where the lens pointed.

**Why the product vanished.** The accepted IMEI went down `/scan` through a
`silent` hook that had **no `onResult`**, so the recognised product came back
and was discarded. *Silent* was meant to mean "no second buzz"; it also meant
"no product". The lookup now runs when the result appears, and the complete
result reaches the parent on accept.

### It is not OCR, and this was audited

The accepted identifier comes from `BarcodeScanningResult.data` → `classifyScan`
→ payload. No `takePictureAsync`, no frame capture, no image OCR anywhere in the
scan path. No camera frame is persisted or displayed.

### Corrected — and **not** device-verified

`erp-mobile` `ae53d3a`, twenty-nine tests. Retest:

1. Scan the raw valid fixture.
2. **Confirm the live camera disappears** and no frozen frame is shown.
3. **Confirm the IMEI appears clearly as text** (and is selectable).
4. **Confirm the existing product is shown** in the result panel.
5. Tap `Use this IMEI`.
6. **Confirm the scanner closes.**
7. Tap `Next`.
8. **Confirm the same product and IMEI are still visible.**
9. **Confirm duplicate inventory creation is blocked** — the fixture phone is
   already a unit.

The §9o checks (one haptic, footer reachable with the keyboard open, blank-area
tap dismissing it) still stand and are still unverified.

---

## 9q. The third physical-device test — sessions, and the count

The §9p fix made the **first** scan work. The device then found that reopening
the scanner brought back the previous session — often in under a second, which
reads as a frozen photograph of the last barcode.

### What was actually wrong

Not the camera. `ScannerSheet` is permanently mounted by its parents (`open`
only gates `if (!open) return null`), so **every piece of its state survived a
close**: the machine, the lookup, both guards, and the `CameraView` instance
itself. The reset lived in an effect, and an effect runs one paint too late —
the reopened sheet had already painted the old result.

Three corrections, all needed:

1. the reset happens **during render**, comparing `open` against its previous
   value, so nothing from the last session can reach the screen;
2. `key={sessionId}` on `CameraView`, so React constructs a **new native view**
   instead of reconciling onto the one holding the last frame;
3. a `lookupSession` token, so a `/scan` response from a closed session cannot
   write into the session that replaced it.

**No delay was added anywhere.** Fast detection was correct; the frame was the
fault, and slowing the decoder would have hidden the symptom while breaking the
feature. `lib/scanner-behaviour.test.ts` asserts the absence of `setTimeout`,
`setInterval`, `await new Promise` and `requestAnimationFrame` in the sheet.

### 🔴 The retest — three openings, then the count

Print the sheet first:

```bash
cd backend
APP_ENV=staging npx ts-node scripts/staging-scan-sheet.ts > ../scan-sheet.html
```

| # | Step | What must happen |
| --- | --- | --- |
| 1 | Open the scanner. Scan **case 1**. | A result appears. **No camera frame anywhere** — the identifier is selectable text. |
| 2 | Tap **Use this IMEI**. | The sheet closes on its own. The product is visible on the intake page. |
| 3 | **Open the scanner a second time.** | It opens **scanning**, with a live camera and **nothing from the first session on screen** — no result, no old identifier, no still frame. |
| 4 | Scan **case 4** (the dual-SIM pair). | A fresh result. Not the first session's phone. |
| 5 | Accept, then **open a third time.** | Scanning again, clean again. This is the opening that used to fail. |
| 6 | Scan, accept, and tap **Next**. | The accepted product **and** IMEI survive the step. |
| 7 | Close the scanner **while a result is loading**, then reopen and scan something else. | The first phone must **never** appear under the second scan. |

Then the count, which is the part no test can settle:

| # | Step | What must happen |
| --- | --- | --- |
| 8 | Open **Stock**. Note the number beside the model on **case 12**'s card. | A model line reading e.g. `Apple iPhone 11 — 2 in stock`. |
| 9 | Scan **case 12** and complete the intake. | Recognised as that model. Accepted — it is not yet in stock. |
| 10 | Return to **Stock**. | The **same model line now reads one higher**. No new line appeared. |
| 11 | Scan **case 12 again** and try to save. | **Refused as a duplicate.** |
| 12 | Return to **Stock**. | The count is **unchanged** by the refusal. |
| 13 | Open that model, then open one phone. | Its own IMEI is shown, and searching either IMEI finds that one handset. |
| 14 | Open a phone product in the catalogue. | **"How is it counted?" offers no Quantity option**, and says it is tracked individually by IMEI and shown by model. |
| 15 | Open an accessory. | Quantity **is** offered. Nothing was taken away from bulk stock. |

> Step 9 permanently adds a unit to Test Store. That is deliberate — it is the
> only way to see the number move — and it takes the fixture to 21. Restore it
> with `scripts/staging-verify-model-count.ts`, which reports the shelf before
> and after, or delete that one unit by its IMEI.

### What HTTP already settled, and what it did not

`scripts/staging-verify-model-count.ts` proved against MySQL that the count is
derived: 20 units across 19 models, iPhone 11 went 2 → 3 on one added unit, no
other model moved, the duplicate was refused by the database itself, and the
fixture returned to 20. **That proves the rule and not the screen** — whether
the number a shopkeeper sees changes after a save on a real phone is still
open, which is what steps 8–12 are for.

---

## 9r. The third physical-device test — **3/3 failed**

`da93d56` fixed the session-reuse fault of §9q. The scanner was then tested on a
phone and **all three attempts failed**, for a reason none of the previous
rounds had reached.

### What the device did

| # | What happened |
| --- | --- |
| 1 | Recognition landed in **well under a second**, before the barcode could be centred |
| 2 | A **neighbouring** card on the sheet was accepted instead of the intended one |
| 3 | A **partially visible** code was accepted |
| 4 | The camera was removed immediately, leaving no chance to correct it |

### The mistake, stated plainly

The decoder was not wrong. A barcode half in frame is still a barcode, and
`expo-camera` reports it the instant it resolves. **We treated the first thing
seen as the thing meant**, and those are the same only when the camera is
already still.

There is a second admission here. §9p ended with a test asserting that
"detection is never delayed", banning every delay mechanism outright. It was
written when the fault was a frozen frame, and read the note that fast detection
was acceptable as *acceptance must never take time*. That assertion has been
**replaced**: the rule is that no delay may be **blind**, not that acceptance
may never take time.

### The rule now

A payload is accepted only when the **same normalized bytes** have been decoded

  - at least **3 times**,
  - spanning at least **1 000 ms**,
  - with **no gap over 400 ms** between consecutive sightings.

The gap clause is what makes this *held on one code* rather than *seen
occasionally over a second*: a barcode that drifts out of frame and returns was
passed over twice, not aimed at.

**It is not a timer.** A `setTimeout` that accepts whatever is current after a
second accepts the *last* thing seen rather than the first, and fires when the
camera may be pointing anywhere. Every decision is made from an observation that
actually arrived, on a monotonic clock.

Until the rule passes: **camera live, no result, no lookup, no haptic, nothing
committed.** The window resets on a different payload, a gap, a cancel, "Scan
again", "Add second IMEI", and every new session. An invalid IMEI never becomes
a candidate — holding still on a mistyped code must not make it a good one.

### The frame guides; it does not gate

`expo-camera` documents `bounds` as sometimes an empty rectangle and sometimes
"the area used by the scanner" rather than the code, and `cornerPoints` as often
absent, with **corner order differing per platform** and no documented
coordinate space. Guessing wrong would silently reject every scan on whichever
platform was guessed wrong.

So the frame is honest guidance and the copy never claims otherwise.
`withinGuide` is written and tested, ready to enable when somebody can verify
the coordinate space on both platforms.

### 🔴 The retest — use the individual fixture view

**Do not test against the page of thirty-two cards.** Several are in frame at
once, and a wrong result could then be the scanner's fault or the sheet's.

```bash
cd backend
APP_ENV=staging npx ts-node scripts/staging-scan-sheet.ts > ../scan-sheet.html
```

Open it, find **Case 1**, and tap **"Open this one alone →"**.

| # | Step | What must happen |
| --- | --- | --- |
| 1 | Case 1 is open alone, full screen. | One barcode, white to the edges, nothing else in shot. |
| 2 | Open the scanner. | A live camera, a frame in the middle, and **"Position the barcode inside the frame"**. |
| 3 | **Sweep the camera briefly across the barcode** without settling. | **Nothing is accepted.** No buzz, no result, camera still live. This is the failure being fixed. |
| 4 | Centre the barcode and hold. | **"Hold steady…"** appears and the frame changes. |
| 5 | Keep holding. | Acceptance comes **after about a second — never before**. Exactly one haptic. |
| 6 | Read the result. | The **exact printed IMEI**, as selectable text. No camera frame anywhere. |
| 7 | Move off the barcode while holding, before it accepts. | The guidance returns to "Position the barcode…" and the window starts over. |
| 8 | Repeat steps 2–6 through a **second and third** scanner opening. | Identical behaviour each time. No state from an earlier session. |
| 9 | Accept, then tap **Next**. | The recognised **Product and IMEI survive** the step. |

Then, on a neighbour test that the grid is now good for:

| # | Step | What must happen |
| --- | --- | --- |
| 10 | On the full sheet, hold the camera steady over **one** card among many. | The card actually aimed at is the one accepted. |

### What is proven, and what is not

`lib/scan/stabilizer.test.ts` proves the rule exactly — 999 ms rejected, 1 000 ms
accepted, resets on payload change and on gaps, invalid IMEIs never candidates,
no haptic or lookup during stabilization — with a clock the tests advance by
hand. **That is arithmetic, not a camera.** Whether a real decoder on a real
phone produces callbacks often enough to satisfy the rule comfortably, and
whether one second feels right in the hand, are open until step 5 is done.

---

## 9s. The multi-barcode defect — measured, not reported

`a82666f` fixed the "accepts in under a second" fault of §9r. It also made the
scanner **unable to scan a real phone label at all**, and that was found by
measurement here rather than by a phone.

### The measurement

Stationary camera, a label carrying IMEI 1, IMEI 2, a serial and a model
number, five seconds:

```
before:  4,950 ms held still  →  0 accepted
after:   1,617 ms             →  1 accepted (the IMEI)
```

### Why

`expo-camera` fires `onBarcodeScanned` **once per barcode, not once per frame**.
Four barcodes produce four interleaved callbacks. The stabilizer tracked ONE
candidate and reset whenever the payload changed, so seeing B erased A and
seeing A erased B — forever. A stationary camera on a crowded label was the
worst case, and it is the normal case.

Candidates are now tracked concurrently, each earning its own window.

### Two more defects the tests forced out

Neither was in the brief; both were found while writing the tests for it.

1. **Whichever code crossed the one-second line first won uncontested**, because
   no rival was yet "ready" to compare against. That is "accept whatever arrived
   first" rebuilt one level up. Dominance is now judged against every *live*
   candidate, not only eligible ones.
2. **A serial number could out-rank the IMEI beside it** — by sitting nearer the
   reticle, or simply by decoding more often — and the scan then failed with
   "that is not an IMEI" while the IMEI was in frame throughout. Usable
   candidates are considered first and separately, and IMEIs outrank stray
   barcodes when the caller is booking a phone in.

### The reticle ranks; it does not gate

Confirmed from the native source in `node_modules/expo-camera`, not the doc
comments:

| Path | Coordinates |
|---|---|
| iOS AVFoundation | `previewLayer.transformedMetadataObject` → preview points, usable against the measured preview size |
| iOS Vision | `VNBarcodeObservation.bounds` → already normalised 0–1 |
| Android ML Kit | image pixels ÷ display density, **image dimensions never forwarded to JS** — no denominator exists |

So Android ranks by stability alone, and **no scan is ever refused for want of a
coordinate.** Inferring Android's extent would be a speculative normalisation on
hardware nobody here can test, whose failure mode is a scanner that rejects
everything.

### 🔴 The retest — a crowded label, three scans

Use the **individual fixture view** for the single-code steps, and a real phone
label (or the full sheet) for the crowded ones.

```bash
cd backend
APP_ENV=staging npx ts-node scripts/staging-scan-sheet.ts > ../scan-sheet.html
```

**Scan 1 — the crowded label (the measurement that failed)**

| # | Step | What must happen |
| --- | --- | --- |
| 1 | Hold the camera **still** over a label with 4–5 barcodes for ~5 s. | A code **is** accepted, in roughly 1–2 s. The old build accepted nothing, ever. |
| 2 | Watch what was accepted. | An **IMEI** — not the serial, not the model number. |
| 3 | Watch the frame during that second. | It fills as the acquisition builds. It must never look frozen. |

**Scan 2 — aiming**

| # | Step | What must happen |
| --- | --- | --- |
| 4 | Sweep the camera across several codes without settling. | **Nothing is accepted.** No buzz. |
| 5 | Pause briefly over the wrong barcode, then move on. | Nothing commits. |
| 6 | Centre the intended IMEI and hold. | **"Hold steady…"**, then acceptance after ~1 s. Exactly one haptic. |
| 7 | Begin acquiring, then deliberately move away before it completes. | The abandoned candidate is **not** committed. |
| 8 | Read the result. | The **exact printed IMEI**, as selectable text. No camera frame. |

**Scan 3 — repetition and duplicates**

| # | Step | What must happen |
| --- | --- | --- |
| 9 | After acceptance, keep the camera on the same barcode. | **Exactly one** submission. No second stock operation. |
| 10 | Repeat steps 4–8 through a second and third scanner opening. | Identical behaviour. No state from an earlier session. |
| 11 | Accept, then tap **Next**. | Product and IMEI survive the step. |
| 12 | Aim at a damaged or non-IMEI barcode and hold. | One brief note, camera **still live**, sheet still open, nothing committed — and it does not repeat every frame. |
| 13 | Type an IMEI by hand instead. | Manual entry works exactly as before. |

### What is proven, and what is not

38 stabilizer assertions and 44 scanner-behaviour assertions, with a clock the
tests advance by hand — including the A B C D interleaving regression in the
exact shape it was measured.

**That is arithmetic, not a camera.** Whether a real decoder produces callbacks
often enough to satisfy `MAX_GAP_MS` on a busy label, whether the reticle
ranking helps on iOS, and whether ~1 s feels right in the hand are all open. The
constants are exported and documented so they can be tuned after step 1.

---

## 9t. Three visible IMEIs — the scanner now asks

### What the device did

With three IMEI barcodes in frame, the scanner:

- alternated between whatever the decoder happened to report;
- sometimes waited indefinitely;
- sometimes chose an IMEI nobody meant;
- sometimes reported "nothing found" while holding a valid IMEI;
- did not reliably respect the barcode being aimed at.

### Why timing could not fix it

The previous rule waited for one candidate to *dominate*. Two IMEIs held side
by side accumulate at the same rate and never separate — so it waited, and when
`AMBIGUITY_GRACE_MS` expired it picked one arbitrarily. **The hang and the wrong
pick came from the same line.**

Stability says a barcode is being held still. It never says it is the one
somebody wanted. No constant can bridge that.

### The policy

| Valid IMEIs found | What happens |
| --- | --- |
| **one** | continues automatically after the usual window — one answer is not ambiguous |
| **two** | camera stops, both shown, choose one or *"Use both — one phone"* |
| **three or more** | camera stops, all shown, **never** auto-selected, at most two selectable |

While the question is open: **camera off, no haptic, no recognition request,
nothing committed.** `/scan` is driven by a confirmed identifier and a question
has none — which is also what stops a response for an unintended candidate
arriving later and overwriting the visible result.

A candidate must have been seen `MIN_OBSERVATIONS` times to be offered, so one
stray decode from a neighbouring label cannot turn a clean scan into a question.

### The reticle still only ranks

Where coordinates are trustworthy the panel lists the best-aimed candidate
first. That is presentation. On Android — ML Kit image pixels over display
density, image dimensions never forwarded to JS — the order carries no
positional information and the person simply chooses. **That is the required
fallback, not a stability-only guess.**

### 🔴 The retest — one, two and three barcodes, on BOTH platforms

Run every block on **Android and iOS separately**. They take different code
paths: iOS can rank by position, Android cannot, and a pass on one says nothing
about the other.

```bash
cd backend
APP_ENV=staging npx ts-node scripts/staging-scan-sheet.ts > ../scan-sheet.html
```

**A — one IMEI visible** (use the individual fixture view)

| # | Step | What must happen |
| --- | --- | --- |
| 1 | Open one IMEI alone, aim, hold. | Accepted after ~1 s. **No selection panel.** One haptic. |
| 2 | Read the result. | The exact printed IMEI, selectable, left-to-right in Arabic too. |

**B — two IMEIs visible** (a real dual-SIM label, or two fixtures side by side)

| # | Step | What must happen |
| --- | --- | --- |
| 3 | Hold both in frame. | The camera **stops** and both are listed. Nothing is pre-ticked. No haptic yet. |
| 4 | Tick one, tap **Use selected IMEI**. | That one is used. One haptic, at this moment. |
| 5 | Repeat, ticking the *other*. | The other is used — either can be chosen alone. |
| 6 | Repeat, tick both. | **"Both IMEIs belong to one phone."** appears *before* the button is pressed, and the button reads **Use both — one phone**. |
| 7 | Accept after choosing both. | **One** unit with two identifiers. Never two units. |

**C — three or more IMEIs visible**

| # | Step | What must happen |
| --- | --- | --- |
| 8 | Hold three in frame for ~5 s. | The panel appears with **all three**. Nothing is ever chosen automatically, however long you wait. |
| 9 | Try to tick a third. | Refused at two. |
| 10 | Tap **Scan again**. | Camera returns, collection starts over. |
| 11 | Tap **Cancel**. | The sheet closes and nothing is committed. |

**D — result meanings**

| # | Step | What must happen |
| --- | --- | --- |
| 12 | Scan a valid IMEI whose TAC is not in the catalogue (fixture case for an unknown TAC). | **"IMEI detected"** and **"Product not recognized"** — never "No IMEI found". |
| 13 | Aim at a 15-digit code with a broken checksum. | The invalid-IMEI explanation. Camera stays live, nothing committed. |
| 14 | Aim at an ordinary product barcode while booking a phone in. | **"No IMEI found"** — a different fact from step 12. |

**E — IMEI 2, repetition and fallback**

| # | Step | What must happen |
| --- | --- | --- |
| 15 | Accept IMEI 1, tap **Add second IMEI**, point at the same label. | IMEI 1 is still shown, and is **not** offered as a candidate. |
| 16 | Try to scan IMEI 1 again as the second. | Refused. It never appears in the list. |
| 17 | Choose a genuine second IMEI. | Both shown as one phone. IMEI 1 never discarded. |
| 18 | After acceptance, keep the camera on the label. | **Exactly one** submission. |
| 19 | Close and reopen the scanner twice. | Clean each time — no candidates, no ticks, no result carried over. |
| 20 | Type an IMEI on the intake page instead. | Manual entry unchanged and still on the intake page, not inside the scanner. |

### What is proven, and what is not

49 stabilizer, 28 machine and 58 scanner-behaviour assertions, all with a clock
the tests advance by hand — including alternating A/B/C callbacks reaching a
question instead of hanging, and IMEI 1 being excluded on the second pass.

**That is arithmetic and source reading, not a camera.** Whether the panel
appears at the right moment on a real label, whether three barcodes are actually
all collected before it opens, and whether the wording is clear enough at a
counter are open until this section is run on both platforms.

---

## 9u. The scan region — strict on iOS, guidance on Android

### What the frame now means

Only a barcode **completely** inside the rectangle may be considered. Every
corner must be inside; a callback that fails is dropped before classification,
stabilization, haptics, recognition or any message. It never happened.

**The centre is not the test.** A barcode straddling an edge has its centre
inside while half of it is out of shot — the read that produces a wrong digit.
Two barcodes each crossing the frame is therefore *no detection at all*, not a
guess at whichever is more covered.

### One frame

There were two overlapping shapes: large white corner brackets and a smaller
rounded rectangle. Two frames on a scanner is worse than none — it promises a
boundary and leaves you to guess which one it is.

One wide, shallow rectangle now, sized for **one horizontal barcode** (84% of
the preview width, 0.34 of that as height), with the corner accents drawn on it
so they cannot drift. A taller region comfortably holds two stacked codes, which
is the situation the frame exists to prevent. The surround is four scrim panels;
inside stays clear glass, because a barcode read through a tint is read worse.

> No blur. `expo-blur` is not installed, and no dependency was added for it.

### 🔴 The platform limitation — read this before testing

Audited from the native source shipped in `node_modules/expo-camera@17.0.10`.

| Platform | Can full containment be enforced? |
| --- | --- |
| **iOS** | **Yes.** `MetaDataDelegate.swift` passes every metadata object through `previewLayer.transformedMetadataObject`, so corners arrive in **preview points** with aspect-fill, rotation and mirroring already applied — the same space `onLayout` reports. It loops **all** `metadataObjects`, so every barcode in frame is judged on its own geometry. |
| **Android** | **No.** `BarcodeAnalyzer.kt` forwards ML Kit `cornerPoints` in *rotated image pixels*. `BarcodeScannerResultSerializer.kt` divides them by display density and builds a bundle of `data · raw · type · extra · cornerPoints · bounds`. The image dimensions **are captured in Kotlin and never put into that bundle** — verified, zero occurrences. No denominator, no rotation, no mapping. It also reports `barcodes.first()` only, so it cannot see the neighbours it would need to reject. |

Nothing is inferred on Android. The failure mode of guessing an extent is a
scanner that silently rejects **every** scan, on hardware that cannot be tested
from here. `no-geometry` is never treated as `inside`.

`bounds` is not consulted on either platform: Expo documents it as sometimes an
empty rectangle and as not necessarily bounding the whole barcode, which is
exactly this use.

**On Android the mask is guidance and the copy claims nothing more.** The
existing stability and explicit-selection rules still protect the scan there.

#### The smallest native fix for Android, proposed and NOT implemented

CameraX can constrain analysis directly — an `ImageAnalysis` viewport, or an ML
Kit input cropped to a rect. Both live in `ExpoCameraView.kt` / `BarcodeAnalyzer
.kt`, so the smallest honest options are, in order of cost:

1. **Forward the image dimensions.** Add `width`/`height` to the JS bundle in
   `BarCodeScannerResultSerializer.toBundle` — a few lines, upstreamable, and it
   would let this gate work unchanged on Android. Needs the rotation too.
2. A config plugin patching the analyzer to accept a crop rect.
3. A different scanner dependency — **only** if 1 and 2 are proven insufficient.

No dependency was added or replaced, per the brief.

### 🔴 The retest — Android and iOS separately

```bash
cd backend
APP_ENV=staging npx ts-node scripts/staging-scan-sheet.ts > ../scan-sheet.html
```

Turn on the development build to see the geometry overlay: it shows the measured
rectangle, the received corner points, and whether the gate accepted or rejected
each callback. Use it to check camera scaling, aspect-fill cropping and rotation
on the actual device — those are exactly the things that look right in a
simulator and are wrong in a hand.

| # | Step | iOS | Android |
| --- | --- | --- | --- |
| 1 | Three barcodes in view, only one completely inside. | **Only the inside one** is considered. | The frame does not restrict; note what happens. |
| 2 | Move that barcode part-way across the **left** edge. | Ignored. | — |
| 3 | Repeat for the **right**, **top** and **bottom** edges. | Ignored each time. | — |
| 4 | Centre it completely. | Becomes eligible, then follows the usual ~1 s acquisition. | Same acquisition rules. |
| 5 | Place **two complete** barcodes inside. | Both eligible → the selection panel appears. | Selection panel via the existing rules. |
| 6 | Repeat on several screen sizes and camera aspect ratios. | The frame stays wide and shallow and centred; the overlay's rectangle matches what is drawn. | Same. |
| 7 | Poor focus, glare, small hand movements. | Borderline barcodes must not flicker between accepted and rejected — that is what `ROI_TOLERANCE_PT` is for. Tune it from what you see. | — |
| 8 | **Does the dark mask align with the real detection boundary?** | It must, exactly. If it does not, the coordinate conversion is wrong and the overlay will show it. | It cannot, and must not be presented as if it does. |
| 9 | A dual-IMEI QR completely inside. | Still parsed as one phone, two identifiers. | Same. |
| 10 | Type an IMEI on the intake page. | Manual entry unchanged. | Unchanged. |

### What is proven, and what is not

22 ROI assertions covering complete containment, every edge, a centre-inside
corner-outside barcode, the two-crossed-barcodes case, missing geometry never
masquerading as success, and five viewport sizes — plus 58 scanner-behaviour
assertions.

**All of it is arithmetic and source reading.** Whether the reported corners
actually land where the frame is drawn on a real iOS device — through aspect-fill
cropping, at each rotation, on each aspect ratio — is unverified, and step 8 is
what settles it. **A source test cannot prove a coordinate transform.**

> The two device screenshots referenced when this work was commissioned were not
> received. The frame geometry follows the written description and has not been
> compared against what the device actually displayed.

---

## 9v. Android strict scan region — patched, and **not compiled**

### A correction to §9u

§9u recorded that Android sends nothing usable for a containment test. **That
was wrong**, and the mistake was reading the wrong file. The path actually in
use is `ExpoCameraView.kt`, which *does* map corner points. It maps them badly:

| Fault | Effect |
| --- | --- |
| Scale applied with **no translation** | an aspect-fill crop is off by the crop offset |
| **Rotation ignored** | the spaces disagree whenever the device is not in the analyzer's orientation |
| Corners read back **transposed** — written `[x, y, …]`, read as `y = points[i]` | every point arrives swapped |
| `barcodes.first()` | only one barcode per frame ever reaches JS, so neighbours cannot be rejected |

That combination is exactly why the visible frame never matched the acceptance
boundary. It was invisible while nothing compared the coordinates to anything.

### The patch

`patches/expo-camera+17.0.10.patch`, committed, applied by `postinstall`.

It replaces the arithmetic with **CameraX's own** `CoordinateTransform`, built
from `ImageProxyTransformFactory().getOutputTransform(imageProxy)` and
`PreviewView.outputTransform`, which handle crop, rotation and scale together.
`isUsingRotationDegrees` is **on**: ML Kit is handed a rotated `InputImage`, so
without it the two spaces disagree by 90° in a way that looks plausible rather
than broken.

The APIs were verified by downloading `camera-view-1.5.0-rc01.aar` from
`maven.google.com` and running `javap` on it — not from documentation.
`getOutputTransform()` **does** still exist in 1.5.0-rc01, contrary to what §9u
assumed.

`.first()` is gone. Every barcode is emitted as its own event with
`frameId` / `indexInFrame` / `countInFrame`, so *three at once* and *one, three
times* are distinguishable. All new fields have defaults, so existing consumers
are unaffected.

### Enforcement is decided per callback

From a `coordinateSpace` marker the patch emits — **never** from a version
number, because a patch that failed to apply must not be mistaken for one that
did.

| Situation | Enforced? |
| --- | --- |
| iOS | always — mapped natively before the payload leaves |
| Android, patched, preview laid out | **yes** (`coordinateSpace: "view"`) |
| Android, patched, first frames | no — `outputTransform` is null until layout |
| Android, unpatched binary, or Expo Go | no — the marker never arrives |

An unpatched build falls back to the existing stability and chooser rules. It
does **not** reject everything: a scanner that silently refused every barcode
because it could not verify geometry would be worse than the defect, and one
that trusted unverified coordinates would be worse still.

### The patch cannot fail silently

`postinstall` = `patch-package && node scripts/verify-native-patch.js`. The
verifier checks the installed version and **six anchors inside `node_modules`**,
and exits non-zero with an explicit message if any is missing.

This matters more than it looks. A quietly unapplied patch leaves the scanner
working, every JavaScript test passing, and the frame no longer the boundary —
visible only to somebody holding a phone against a label.

Verified both directions: passes after `rm -rf node_modules/expo-camera && npm
install`; fails with a clear message when an anchor is broken.

### 🔴 NOT COMPILED — the blocker

**There is no `eas.json` in this repository and no EAS login.** The Kotlin has
never been through a compiler and the transform has never run. No credentials
were invented and no build was claimed.

To compile and test it:

```bash
cd mobile
npm install                     # applies the patch, then verifies it
npx eas-cli login
npx eas-cli build:configure     # creates eas.json (first time only)
```

Add an internal profile with the overlay flag, then:

```bash
npx eas-cli build --platform android --profile preview
```

The profile needs `"distribution": "internal"`, `"android": { "buildType":
"apk" }` and `"env": { "EXPO_PUBLIC_SCAN_GEOMETRY_OVERLAY": "1" }`.

> A modified native module **requires a custom native build**. It cannot be
> validated by a JavaScript refresh, by Metro, or in Expo Go — those run the
> unpatched native binary, where the marker never arrives and the strict path
> stays off by design.

**First thing to check is that it compiles at all.** If Gradle fails, the likely
suspects in order: the `@TransformExperimental` opt-in, the
`ImageProxyTransformFactory` property syntax (`isUsingRotationDegrees` vs
`setUsingRotationDegrees`), and the `BarcodeAnalyzer` constructor arity where
`ExpoCameraView` calls it.

### 🔴 The device retest — Android

With the internal build installed and the overlay visible:

| # | Step | What must happen |
| --- | --- | --- |
| 1 | Open the scanner and read the overlay. | It shows `view`, not `analysis`. If it says `analysis`, the patch is not in the binary and nothing below is meaningful. |
| 2 | Three barcodes in view, **one** completely inside the frame. | Only that one is considered. |
| 3 | Move it part-way across the **left** edge. | Rejected. |
| 4 | Repeat for **right**, **top**, **bottom**. | Rejected each time. |
| 5 | Centre it completely. | Eligible, then the usual ~1 s acquisition. |
| 6 | Place **two complete** barcodes inside. | The chooser appears with both. |
| 7 | **Compare the overlay's corner numbers with the drawn frame.** | They must agree. This is the check the whole patch exists for — if the corners are offset or transposed, the mapping is still wrong. |
| 8 | Rotate the device; repeat 2–5. | Same behaviour. Rotation is the most likely thing to be wrong. |
| 9 | Try several screen sizes and camera aspect ratios. | The mask must stay on the real boundary. |
| 10 | Close and reopen the scanner, then repeat 2–5. | Identical; the frame is remeasured. |
| 11 | A dual-IMEI QR completely inside. | Still one phone, two identifiers. |
| 12 | Type an IMEI on the intake page. | Manual entry unchanged. |

### 🔴 Re-run the iOS checklist too

§9u, unchanged. The iOS path was not touched, but the shared JavaScript gate
was, so it needs re-confirming rather than assuming.

### What is proven, and what is not

35 ROI assertions and 58 scanner-behaviour assertions pass, including the patch
content, the anchors, the additive event fields, and the absence of payloads
from native logs. The patch applies cleanly and survives a clean install.

**None of that is a compiler, and none of it is a camera.** Step 1 tells you
whether the patch is in the binary; step 7 tells you whether the mapping is
right. Until both pass on a physical Android device, **Android strict ROI is
not complete.**

---

## 9w. Build `6a141e15` — a splash defect, before Kotlin

The first EAS Android build failed at `:app:processReleaseResources`:

```
resource drawable/splashscreen_logo
(aka mr.retailerp.app:drawable/splashscreen_logo) not found
```

**Resource linking runs before Kotlin compilation, so the CameraX patch was
never reached.** It remains uncompiled.

### The cause, from the plugin source

| File | What it does |
| --- | --- |
| `withAndroidSplashStyles.js` | writes `@drawable/splashscreen_logo` into the theme **unconditionally** — `windowSplashScreenAnimatedIcon`, and again in `setSplashStylesForTheme` |
| `withAndroidSplashImages.js` | produces that drawable **only when an image is configured** — its own comment: *"If path isn't provided then no new image is placed in drawable directories."* |
| `getAndroidSplashConfig.js` | reads `image: splash.image` with **no default and no fallback** |

The `expo-splash-screen` entry in `app.json` had `imageWidth`, `resizeMode` and
`backgroundColor` — and no `image`. So the theme referenced a drawable that
nothing generated. Adding the image is the entire fix.

### Proven, not assumed

A disposable clean prebuild, both ways:

| Config | Drawables generated | Files still referencing it |
| --- | --- | --- |
| **without** `image` | **0** | 1 |
| **with** `image` | **5** (mdpi → xxxhdpi) | 2, all resolving |

Every `@drawable/…` reference in the generated resources was then swept for
dangling targets. The only two are `abc_textfield_activated_mtrl_alpha` and
`abc_textfield_default_mtrl_alpha`, referenced by `rn_edit_text_material.xml` —
AndroidX AppCompat supplies both at link time. They are in every React Native
app and linked fine in the failing build.

### The other five checks

| Check | Result |
| --- | --- |
| Path in `app.json` / `app.config.*` / plugin | `app.json` is the only config; the plugin entry was the defect |
| Image exists | `assets/images/splash-icon.png`, present |
| Git-tracked and uploaded | tracked since the initial commit |
| Excluded by ignore rules | no — and there is no `.easignore` |
| Filename / extension / case | all correct |

### ⚠️ There is no branded splash asset

`splash-icon.png` is **byte-identical to `expo-logo.png`** — the stock Expo
template mark. So are `icon.png` and `android-icon-foreground.png` (the Expo
chevron, inspected directly).

The intended tracked asset was referenced rather than a placeholder invented.
**Real artwork can be dropped in at `assets/images/splash-icon.png` with no
config change** — 200 pt wide, `contain`, on the `#4f46e5` brand background.

### Rerun

```bash
cd mobile
npm install
npx eas-cli build --platform android --profile preview
```

`eas.json` and the project link are committed, so there is no configure step.

**This is the first build that can actually test the CameraX patch.** If Gradle
fails now, it will be at Kotlin compilation, and the likely suspects are in
§9v: the `@TransformExperimental` opt-in, `isUsingRotationDegrees` property
syntax, and the `BarcodeAnalyzer` constructor arity at its call site.

---

## 9x. ✅ iPhone strict ROI — PHYSICALLY VERIFIED

**The first green result in this component.** On a physical iPhone, a barcode is
accepted **only when it is fully inside the visible frame**. The drawn rectangle
and the real acceptance boundary agree.

That closes §9u for iOS, and with it the question §9v step 7 was written to
answer — on iOS. `previewLayer.transformedMetadataObject` returns corners in
preview points, and comparing them against a rectangle measured by `onLayout`
works in the hand as well as on paper.

**Android is a separate answer.** Its patch has still never been compiled, and
nothing here transfers: the two platforms reach the same predicate down
completely different paths.

### Still open

- 🔴 §9v — the Android build, then its device retest. Step 1 (does the overlay
  say `view`?), then step 7 (do the corners match the frame?).
- 🔴 §9t — one, two and three visible IMEIs.
- 🔴 §9s, §9r, §9q steps 8–15, §9n, §9o.

---

## 9y. Two UI corrections — one shared cause each

### The gap under the navigation header

"Ventes et retours" is a hub (`app/hub/[id].tsx`), and **every** route reachable
from More renders through the same `Screen`. The cause was shared:

> The native header already sits under the status bar and consumes that inset.
> `Screen` then applied `edges: ['top']` and reserved it **again**.

On a notched phone that is roughly fifty points of nothing between the title and
the first line of content. `Screen` now drops the top edge when a header is
shown, read from React Navigation's `HeaderShownContext` — the native stack sets
it to `headerShown !== false`.

Read as context rather than through `useHeaderHeight()`, which throws when there
is no header; a hook that throws cannot be called unconditionally.

**46 routes fixed by one change.** Tab pages are untouched — the root stack and
the tab navigator both set `headerShown: false`, so the context is false there
and they keep the inset they need. Spacing *inside* pages is unchanged.

### The keyboard on scan-entry pages

Also shared. `ScanTarget` took an `autoFocus` prop and two pages passed it, so
Sell and Receive raised the keyboard over most of the screen before anybody had
asked to type. On a scan-first page that is backwards.

The prop is **removed**, not defaulted to false: a prop that still exists is one
a future page can pass, and this arrived as one word on two pages.

Two more places the rules reach that the screenshot did not:

- the **post-scan price field** on Sell — a scan result must not raise the
  keyboard over the confirmation somebody needs to read;
- the scanner's **manual fallback**, which is also reached by a *denied camera
  permission*, where the keyboard would cover the explanation.

Opening the camera now dismisses the keyboard first. Blank-space dismissal was
extended to the header and footer, which sit outside the scroll view — and on a
scan-first page the input lives in the header, so the area right around it was
the one place tapping did nothing. `Pressable`, not an overlay: a real control
inside wins the touch.

### 🔴 The device checks

Run in **English, French and Arabic RTL**.

| # | Step | What must happen |
| --- | --- | --- |
| 1 | Open More → **Ventes et retours**. | The description sits close under the header. No empty band. |
| 2 | Open several other More routes — Catalogue, Dépenses, Objectifs, Consignations. | All the same. The fix is shared; none should differ. |
| 3 | Switch to **Arabic**. Repeat 1–2. | Identical spacing; RTL layout intact. |
| 4 | Check the tab pages — Stock, Vendre, Argent. | **Unchanged.** They keep their top inset. |
| 5 | Small screen / large font. | No clipping under the header. |
| 6 | Open **Vendre**. | **No keyboard.** The list and scan field are visible. |
| 7 | Open **Recevoir**. | Same. |
| 8 | Tap the scan field. | Keyboard opens, and only then. |
| 9 | Type a few digits, then tap blank space, the header, or a result. | Keyboard closes; **the typed value is still there**. |
| 10 | Tap the camera icon with the keyboard open. | Keyboard dismisses, camera opens full height. |
| 11 | Scan something on Vendre that needs a price. | The confirmation is readable; **no keyboard until the price field is tapped**. |
| 12 | Deny the camera permission, open the scanner. | The explanation is readable; no keyboard over it. |
| 13 | Leave Vendre and come back; restore a draft. | **No keyboard** on return. |
| 14 | With the keyboard open, tap a footer button. | It presses on the **first** tap. |
| 15 | Scroll a long form with the keyboard open. | Scrolling works; nothing blocks it. |

### What is proven, and what is not

14 new assertions in `lib/screen-chrome.test.ts` covering the shared causes, all
46 header routes not re-adding the inset themselves, the tab pages staying out
of it, `autoFocus` being gone from the whole scan path, dismissal ordering, the
value surviving dismissal, and the scanner internals being untouched.

**These are source assertions.** Whether fifty points of space actually
disappeared, and whether the keyboard behaves in a hand, are steps 1–15.

---

## 9z. ✅ The Android native build COMPILED

EAS build `251f8b41-5b1d-4c9f-85a1-a0e59a95351a` **completed successfully**.

That answers §9v's first open question: the committed `expo-camera` patch
**compiles**. The Kotlin is valid against CameraX 1.5.0-rc01 — the
`@TransformExperimental` opt-in, `ImageProxyTransformFactory`,
`CoordinateTransform`, `isUsingRotationDegrees` and the widened
`BarcodeAnalyzer` constructor are all accepted by the compiler.

The earlier build `6a141e15` failed at `processReleaseResources` on the splash
drawable (§9w) and never reached Kotlin. That is fixed and this one got through.

### 🔴 What compiling does NOT prove

**Android ROI behaviour is still unverified on a device.** A compiler checks
that the transform is *called correctly*; it says nothing about whether the
mapped corners land where the frame is drawn. Rotation is the specific risk —
ML Kit is handed a rotated `InputImage`, and `isUsingRotationDegrees = true` is
a choice that only a phone can confirm.

§9v's device retest stands, unchanged. **Step 1** (does the overlay say `view`?)
now has a binary to run in; **step 7** (do the corners agree with the frame?) is
the one that decides.

---

## 9aa. The keyboard dismissal that was wired to the wrong branch

### What the device found

Entering a scan page with the keyboard closed: working. Tapping the input to
open it: working. **Tapping outside to dismiss it: not working.** The only way
to close the keyboard was to leave the page and come back.

### Why, and why the test had passed

`Screen` renders its body two ways:

```
scroll={true}   → ScrollView  → Pressable → children      ← had a dismissal
scroll={false}  → View        → children                  ← had NOTHING
```

**Every scan-entry page passes `scroll={false}`.** The previous correction added
three dismissals and a test counted three: header strip, footer strip, and the
scrolling body those pages never render. The middle of the screen — the empty
cart, the empty state, the list — was a plain `View` with no handler.

The count was correct. Counting was never the problem; counting the wrong three
was, and a source-text assertion cannot tell the difference.

### The fix

| | |
| --- | --- |
| The non-scrolling body | is now a dismissal surface — **the actual defect** |
| Both body surfaces | use `flexGrow` so they reach the bottom of a short page. A `Pressable` sizes to its children, so with an empty cart — exactly when somebody is typing — it covered a strip at the top and left the obvious place to tap outside itself |
| Receive's list | gained `keyboardDismissMode="on-drag"`, the one scrollable on a scan page where a drag left the keyboard over the content being scrolled |

The behaviour moved into `lib/keyboard-dismiss.ts` as two plain functions, so a
test can **call** the handler the UI calls. 18 assertions now invoke them and
observe the result rather than searching for a string.

Still no overlay. The surfaces are `Pressable`s wrapped around real content, so
the deepest responder wins: buttons press, the camera icon opens the camera, and
the field keeps focus when tapped.

### 🔴 The device checks

Run in **English, French and Arabic RTL**, on Sell **and** stock intake.

| # | Step | What must happen |
| --- | --- | --- |
| 1 | Open Sell. | No keyboard. |
| 2 | Tap the scan field, type three digits. | Keyboard opens; digits appear. |
| 3 | Tap the **empty cart area** in the middle of the screen. | **Keyboard closes.** This is the exact tap that did nothing before. |
| 4 | Tap the field again, then tap the **header** beside the title. | Closes. |
| 5 | Tap the field again, then tap the **footer**. | Closes; if a button was hit, it also ran, on the first tap. |
| 6 | Tap the field again, then tap **inside the field**. | Stays open. |
| 7 | Type, dismiss, then look at the field. | **The typed value is still there.** |
| 8 | Type, then tap the **camera icon**. | Keyboard closes and the scanner opens full height. |
| 9 | Add items to the cart, type, then **drag the list**. | Keyboard closes. |
| 10 | Repeat 1–9 on **stock intake** (Receive). | Identical. |
| 11 | Leave the page and come back. | No keyboard, and no field focused. |
| 12 | Scan something; let a result appear. | No keyboard. |
| 13 | Repeat 1–9 in **Arabic**. | Identical; RTL intact. |
| 14 | With VoiceOver on, swipe through the page. | The dismissal surfaces are **not** announced as buttons. |

### What is proven, and what is not

18 behavioural assertions calling the handlers, plus wiring checks that the
handler is attached to **every** body branch — including the one that was
missed.

**None of that is a finger on glass.** Step 3 is the one that decides.

---

## 9ab. Storage and Colour showed no options — a stale server, and four states collapsed into one

### Root cause: the running backend predated the endpoint

The decisive evidence is one digit:

```
GET /api/v1/device-catalogue/brands      → 401   (route exists, needs auth)
GET /api/v1/device-catalogue/version     → 401   (route exists)
GET /api/v1/device-catalogue/attributes  → 404   Cannot GET
```

The auth guard runs **after** routing, so `401` means the route exists and
`404` means it does not. A backend started from current source maps all four
routes and answers `attributes` with `401` like the others:

```
Mapped {/api/device-catalogue/attributes, GET} (version: 1) route
```

**The code was always correct. The running process was stale** — started before
the commit that added the endpoint, and never restarted. Confirmed against
`127.0.0.1:3011` directly, so the nginx-substitute proxy on `:8088` is not
involved.

**Data source unchanged.** `/device-catalogue/attributes` is the established
source, it works, and nothing was duplicated locally. No backend change, no
migration; the backend catalog suite (84 tests) still passes untouched.

### The client defect the outage exposed

A stale server will happen again. What must not happen again is the app being
unable to say which of four things went wrong.

The options were fetched into an array and **nothing recorded why the array
might be empty**. An empty array from a failed request was indistinguishable
from an empty array from a search matching nothing — so a failure rendered
"Nothing matches" **and** "The list could not be loaded" together, with no
Retry, which is exactly the contradiction the brief forbids.

Four states now, mutually exclusive, in the order somebody needs them:

| State | Shows |
| --- | --- |
| `loading` | "Loading the list…" — the initial state, because an empty chooser during a request is the same lie in a smaller font |
| `error` | "The list could not be loaded" **+ Retry**. Manual entry stays available underneath |
| loaded, genuinely empty | a true empty state + "Something else" |
| loaded, filter excluded all | "No matches for *X*" — naming the query, so it cannot be mistaken for a failure |

The failure branch **returns before the filter is consulted**, so the two
messages are now structurally incapable of appearing together. The bottom notice
reports only the *cached* case; the failure lives in the chooser beside its
Retry.

Both choosers share one body, so Storage and Colour cannot drift apart.

### 🔴 Device checks

**First: restart the backend.** Nothing below is meaningful against a stale
process — verify with `curl .../device-catalogue/attributes` returning **401**,
not 404.

| # | Step | What must happen |
| --- | --- | --- |
| 1 | Receive Stock → new product → select `iPhone 17`. | Brand and Model behave as before. |
| 2 | Tap **Storage**. | Options appear **immediately**, with no typing. No keyboard forced open. |
| 3 | Type `256`. | The list filters. |
| 4 | Clear the search. | The full list returns. |
| 5 | Type `zzz`. | "No matches for zzz" — **not** "could not be loaded". |
| 6 | Pick `256 GB`. | The chooser closes and the row shows `256 GB`. |
| 7 | Tap **Colour**. Repeat 2–6 with a colour. | Identical behaviour. |
| 8 | Check Storage still reads `256 GB`. | The two are independent. |
| 9 | Reopen **Storage**. | The current selection is ticked, and can be changed. |
| 10 | Choose **Something else**, type `384 GB`. | Kept verbatim; the row shows it. |
| 11 | Change Model. | Existing dependent-reset rules apply; no invalid hidden selection. |
| 12 | Turn the server off, then reopen a chooser. | Cached options still appear, labelled as stored. |
| 13 | Clear the app cache with the server off. | "Could not be loaded" **+ Retry**, and "Something else" still works. **"Nothing matches" must not appear.** |
| 14 | Turn the server on, tap **Retry**. | The list loads. |
| 15 | Repeat in **French** and **Arabic RTL**. | Natural wording; RTL intact. |
| 16 | Scan an IMEI first, then do 1–10. | The pending IMEI survives throughout. |

### What is proven, and what is not

14 assertions on the state machine, the shared chooser body, retry wiring,
independence, and the client/server contract — plus the live probe above that
identified the stale process.

**Step 13 is the one that matters**, because it is the exact state the device
was in, and the one that used to show two contradictory messages at once.

---

## 10. Expo SDK 54 → 57: restoring iPhone testing

### Why this happened

Expo Go is one App Store binary supporting one SDK at a time. It moved to SDK
57 and stopped opening the SDK 54 project, which ended physical iPhone testing.
On Windows with no paid Apple Developer membership, Expo Go **is** the iPhone
route — an EAS device build does not substitute for it here.

The path was `54 → 55 → 56 → 57.0.20`, with full gates at each stop. `57.0.20`
rather than `57.0.0`: a Hermes V1 memory regression present at SDK 56 is fixed
in `expo@57.0.9` and later.

### 🔵 First: sign in, both sides, same account

Expo Go now requires the CLI and the phone to be signed into the **same** Expo
account. An Expo account is free.

```bash
cd mobile
npx eas-cli@latest whoami        # already signed in? it prints the account
npx eas-cli@latest login         # if not
```

On the iPhone: open **Expo Go → Profile tab → Log in**, with the same account.

Then start the server and scan:

```bash
cd mobile
npx expo start --lan
```

Scan the QR with the **Camera app** and let it hand off to Expo Go.

**If the project does not appear:** the two sides are on different accounts, or
the phone is on a different Wi-Fi. Both are silent failures.

### 🔴 The device checks

Nothing below may be marked green from an export, a type-check or Doctor. The
upgrade replaced the navigation layer, the safe-area handling and the camera
package; every one of these is a behaviour that has previously broken.

**Reaching the app**

1. The project opens in Expo Go and reaches the first screen.
2. Sign in works.
3. Tab navigation works; each tab renders.

**The header and safe-area work (SDK 56 replaced the context this depends on)**

4. A More route shows the native header with the *reduced* gap to the first
   line of content — no reappearance of the ~50pt band.
5. A headerless tab route still reserves the status-bar inset correctly.
6. Neither is double-spaced.

**Keyboard (verified before the upgrade; re-verify)**

7. Opening a scan-entry page leaves the keyboard **closed**.
8. Tapping an input opens it.
9. Tapping outside dismisses it.
10. Opening the scanner dismisses it first.
11. Drag-dismiss still works on applicable lists.

**Storage and Colour**

12. Both open with choices visible *before* typing, keyboard closed.
13. With the phone in airplane mode, both still list the bundled options, with
    the amber "standard list" note and a working **Retry**.
14. Back online, Retry replaces them with server values.

**The scanner — the highest-risk area of this upgrade**

15. The camera opens; the permission prompt behaves.
16. A raw IMEI barcode scans.
17. Strict iOS ROI: a code **outside** the drawn frame is **not** accepted.
18. A code inside is accepted, and the scan pauses immediately on a result.
19. Rescan works after the pause.
20. Manual IMEI entry still works, with IMEI 2 optional.

**Languages**

21. English, French, and Arabic with RTL layout.

### What is proven, and what is not

| | |
|---|---|
| ✅ Automated | tsc clean · Doctor 21/21 · lint 0 errors · 32 suites / 640 assertions / 0 failing · i18n 1840 × 3 · web export 23 routes · patch verified 6 anchors after a clean `npm ci` |
| 🟡 Compilation only | The Android EAS build proves the rebased Kotlin **compiles**. It proves nothing about where ROI coordinates land. |
| 🔴 Unverified | Everything in the list above. And **Android strict-ROI placement on a handset**, which was already open before this upgrade and remains so. |

The rebased patch changed the mapping's source (upstream fixed two of three
defects; rotation and the `coordinateSpace` marker are still ours). A compile is
not evidence that a rectangle lands where the drawn frame is.

---

## 11. Category-aware intake — UNVERIFIED ON ANY DEVICE

Runs on the same `sdk-57-upgrade` build as §10, so do §10 first: a failure there
explains a failure here, and the reverse is not true.

The rule being checked: **a phone is registered one handset at a time, and
nothing else is.** The category decides, and the app should never ask.

### On the product form

| # | Do this | Expect |
|---|---|---|
| 11.1 | New product → pick a **phone** category | The "how it is received" card reads *registered one by one, each with its own IMEI*, and names the category |
| 11.2 | Switch the category to **Accessories** | The card changes to *received by quantity — no IMEI needed*, immediately, with no save |
| 11.3 | Look for a tracking picker | **There is none.** If a segmented control appears, this work has regressed |
| 11.4 | Leave the category empty | The card says to choose a category |
| 11.5 | Look for a free-form **Details** section | **Gone.** Storage and Colour must still be there, still as pickers |
| 11.6 | Open an existing product that has old Details values | Its specifications still show on the detail screen and still match in search |
| 11.7 | Edit that product's brand and save | The old specification values are **still there** afterwards |

### Receiving

| # | Do this | Expect |
|---|---|---|
| 11.8 | Receive a **phone**: scan an IMEI | One unit staged. The quantity field is absent |
| 11.9 | Scan the same IMEI again | Refused as already in the delivery — not a second unit |
| 11.10 | Receive an **accessory**: scan its barcode | Asks cost **and quantity, once**. Type 40 |
| 11.11 | Confirm | 40 in stock — **not 40 scans**. This is the whole point |
| 11.12 | Receive the same accessory again at a different cost | Stock increases; the shelf **price does not change** |
| 11.13 | Scan a box barcode while receiving a phone | Refused with the "scan the IMEI" guidance, not staged |

### Category management

| # | Do this | Expect |
|---|---|---|
| 11.14 | Create a category | Only **IMEI** and **Quantity** offered — no "Serial number" |
| 11.15 | Open **Televisions** (already `serial`) | Its serial option is visible so renaming does not retype it, and its stock is intact |
| 11.16 | Try to change a category that has products | Refused, saying how many products are affected |

### The retry (do this one deliberately)

| # | Do this | Expect |
|---|---|---|
| 11.17 | Start receiving accessories, then turn Wi-Fi and data **off** mid-submit | An error, not a crash |
| 11.18 | Turn the network back on and retry the same submission | Stock increases **once**. If it doubles, stop and report it — this is the defect `stock_receipts` exists to prevent |

> 11.18 is the only one of these that cannot be checked by reading the screen
> afterwards alone: check the stock figure **before** starting, so "once" is a
> number you can compare against rather than an impression.

| | |
|---|---|
| 🔴 Unverified | **Every row above.** Nothing here has run on a handset. |

---

## 12. The indigo refresh and motion — UNVERIFIED ON ANY DEVICE

Runs on `sdk-57-upgrade`, so §10 first, then §11, then this.

**Nothing in this section can be checked by TypeScript, tests, Expo Doctor or
the web export.** Every one of them passed while this list was written; none of
them can see a frame land, a keyboard appear, or a colour under shop lighting.

### Motion

| # | Do this | Expect |
|---|---|---|
| 12.1 | Press and hold a primary button | It settles slightly smaller (~2%), and returns cleanly on release |
| 12.2 | Press, then slide your thumb off before releasing | It returns to full size — no button left stuck small |
| 12.3 | Press a **destructive** button (delete, refund) | **No scale.** If it springs, the high-friction control has been made to feel casual |
| 12.4 | Press a button mid-save (while it shows a spinner) | Nothing happens — no scale, no second submission |
| 12.5 | Open and close a bottom sheet | Rises and falls in ~¼ second, no wobble or overshoot |
| 12.6 | Scroll a long list hard, then flick back | Smooth; no stutter introduced by row changes |

### Reduce Motion  *(iOS: Settings → Accessibility → Motion)*

| # | Do this | Expect |
|---|---|---|
| 12.7 | Turn Reduce Motion on, open a sheet | It **fades in place** — it must not travel up the screen |
| 12.8 | Press a button | **No scale at all**; the colour change and haptic still report the press |
| 12.9 | Scan a code | The result still appears, still fades, still no movement |
| 12.10 | Turn Reduce Motion back off | Movement returns without restarting the app |

### The scanner  *(the highest-risk area on this list)*

| # | Do this | Expect |
|---|---|---|
| 12.11 | Aim at a barcode | The reticle is **indigo** and clearly visible |
| 12.12 | Aim at a glossy white box under bright light | The reticle is still visible. **Report it if it washes out** — this colour could not be contrast-tested against a photograph |
| 12.13 | Aim at a dark shelf | Still visible |
| 12.14 | Scan a valid IMEI | The camera stops **immediately**, one haptic, result fades in |
| 12.15 | Sweep across a label carrying several barcodes | **One** accepted result, **one** haptic. Not one per code |
| 12.16 | Keep the phone over the label during the fade | No second result, no second buzz, no flicker |
| 12.17 | Look at the accepted mark | **Indigo, not green.** Green means a completed business outcome; a detection is only a reading |
| 12.18 | Background the app mid-fade, return | The result is intact; the camera has not resumed behind it |
| 12.19 | Tap "Scan again" | The camera restarts cleanly |
| 12.20 | Check the ROI frame still rejects a barcode half outside it | Unchanged from §10 |

### Lists and sheets

| # | Do this | Expect |
|---|---|---|
| 12.21 | Open the catalog | Flat rows, hairline separators, product name strongest. No stack of cards |
| 12.22 | Open the stock list | Rows abut with hairlines; quantities aligned down the column |
| 12.23 | Open the Storage selector | **Options visible immediately and the keyboard closed.** If the keyboard covers the list, the sheet has regressed |
| 12.24 | Open the Colour selector | Same, plus swatches and localised names |
| 12.25 | Select an option | Pale indigo row, indigo checkmark, and it reads as selected without relying on colour |
| 12.26 | Drag a sheet down | Dismisses; the list inside still scrolls independently |

### Dark mode, RTL, and contrast

| # | Do this | Expect |
|---|---|---|
| 12.27 | Switch to dark mode, revisit catalog, stock, form, scanner | Nothing washed out; the selected row is a **deep** indigo, not a pale one |
| 12.28 | Switch to Arabic | Sheets, rows, icons, spacing and the sheet transition all mirror correctly |
| 12.29 | Arabic, dark mode, Reduce Motion together | Still coherent — these interact and are usually tested apart |
| 12.30 | Check low stock, pending, confirmed and error surfaces in both themes | Readable, and each carries a word or icon as well as its colour |
| 12.31 | French: check the longest labels do not truncate | Especially buttons and the derived-tracking line |

### VoiceOver

| # | Do this | Expect |
|---|---|---|
| 12.32 | Focus a selected option | Announced as **selected** |
| 12.33 | Focus a disabled or loading button | Announced as disabled/busy |
| 12.34 | Open then dismiss a sheet | Focus returns sensibly to the screen behind |
| 12.35 | Scan a code with VoiceOver on | Status change announced **once**, not repeatedly |

| | |
|---|---|
| 🔴 Unverified | **Every row above.** |
| ⚠️ Highest risk | 12.12 (reticle on a bright surface) and 12.15–12.16 (one result, one haptic, through the reveal). |

---

## 13. The consolidated redesign run — UNVERIFIED

**Do this one in order.** It replaces §11 and §12 as the single session to work
through: they were written before the sign-in crash was found, and running them
separately means signing in three times.

Sign in with **`devtest@example.com`**. The password is deliberately not written
here or anywhere in Git — ask whoever set it up.

> Everything in this section is 🔴 **unverified** until you tick it. TypeScript,
> lint, 706 assertions, Expo Doctor and a web export all passed while it was
> written, and **none of them can see a frame land, a keyboard appear, or a
> colour under shop lighting.** The sign-in crash proved that precisely: it was
> a worklet dying on the UI thread, which no gate in this project can execute.

| # | Do this | Expect |
|---|---|---|
| 1 | **Sign in** | Lands in the app. No crash on pressing the button — that is the specific regression `2b58d4b` fixed |
| 2 | Sign in with a wrong password | Stays in the app, shows "Incorrect email, number or password" in your language |
| 3 | **Home** | Waiting-work, stock and destinations each read as ONE grouped list, not as stacked bordered boxes |
| 4 | Home as an employee account | No cost, margin or restricted metric visible |
| 5 | **Catalog**, scroll | Flat rows, hairlines between them, product name strongest. No gaps making rows look like broken cards |
| 6 | Catalog search | Filters as you type; the shared search field, not a bespoke one |
| 7 | Catalog filters | Selected chip is indigo; tapping another switches cleanly |
| 8 | **Product detail** | Identity and specs grouped; per-branch stock is one surface with internal rules |
| 9 | **Create a Phone product** | Category first; the mode is *stated*, not chosen; no quantity field |
| 10 | **Create a quantity product** | Same form, no IMEI language anywhere |
| 11 | **Storage selector** | Opens with options visible and **the keyboard closed** |
| 12 | **Colour selector** | Same, plus swatch and localised name |
| 13 | Select an option | Pale indigo row + checkmark; reads as selected without relying on colour |
| 14 | **Receive quantity stock** | Cost and quantity asked once. 40 arrives as 40, not 40 scans |
| 15 | **Scan one IMEI** | Indigo reticle; camera stops immediately; one haptic; result fades in |
| 16 | Sweep across several barcodes | **One** accepted result, **one** haptic |
| 17 | **Add IMEI 2** | Optional and clearly marked as optional |
| 18 | **Manual IMEI entry** | Reachable without the camera |
| 19 | **Scan a product barcode** | Fills the barcode field. An IMEI must NOT |
| 20 | **A sale** | Financial summary still stands out from the item rows |
| 21 | **A return / refund state** | Pending payout reads **amber**, never green |
| 22 | **Notifications** | Unread shown by wash *and* an explicit indicator |
| 23 | **More / settings** | Grouped destinations; sign-out visually separate |
| 24 | **Dark mode** everywhere above | Selected rows are a DEEP indigo, not a pale wash. Nothing washed out |
| 25 | **Arabic RTL** | Rows, sheets, icons mirror. **Separator indents from the correct side** |
| 26 | **Reduce Motion** on | Sheets fade in place; buttons do not scale; dialog does not zoom; toast does not slide |
| 27 | Reduce Motion + a scan | Result still appears, still no movement |
| 28 | **Offline** — turn the network off mid-action | Clear offline state, safe retry, no raw backend error |
| 29 | Rotate / large text | Nothing clipped; primary actions still reachable |
| 30 | VoiceOver on a selected row | Announced as selected |

### Highest risk, in order

1. **#15–16, #27** — the scanner through the reveal animation. Logic is covered
   by tests; frames are not.
2. **#25** — RTL separator indentation. It is a start-margin, so it *should*
   follow direction, but that is an assertion about a layout engine.
3. **#24** — dark mode across newly grouped surfaces.
4. **#1** — regression check on the crash that blocked the last run.

---

## 14. The completed redesign, and the approval workflow — UNVERIFIED

*35 checks: the 30 redesign rows, #31–32 for the scan duplicate contract, and #33–35 for native CSV sharing.*

Supersedes §13. Same account (`devtest@example.com`, password not written here),
same order, extended to the screens finished in this pass.

> 🔴 Every row is unverified. tsc, lint, 713 assertions, Expo Doctor and a web
> export all passed while this was written, and **none of them can see a frame
> land or a colour under shop lighting.** The sign-in crash remains the proof:
> a worklet dying on the UI thread, invisible to every gate in this project.

| # | Do this | Expect |
|---|---|---|
| 1 | Sign in | No crash on the button. Wrong password stays in-app with a localized message |
| 2 | Home | Waiting-work, stock and destinations each ONE grouped list |
| 3 | Catalog, scroll, search, filter | Flat rows, hairlines, shared search field and chips |
| 4 | Product detail | Per-branch stock grouped; identity and specs still readable blocks |
| 5 | Create a Phone product | Category first, mode stated not chosen, no quantity field |
| 6 | Create a quantity product | No IMEI language anywhere |
| 7 | Storage + Colour selectors | Options visible, **keyboard closed**, swatch and localized name |
| 8 | Receive quantity stock | Cost and quantity once; 40 arrives as 40 |
| 9 | Scan an IMEI | Indigo reticle → **indigo** glyph, "IMEI detected", **"Scanner paused"** |
| 10 | Sweep several barcodes | ONE result, ONE haptic |
| 11 | Add IMEI 2 | "Add second IMEI — optional"; "Both IMEIs belong to one phone" appears |
| 12 | Manual IMEI entry | Reachable from the field beside the camera button |
| 13 | Scan a product barcode | Fills barcode. An IMEI must NOT |
| 14 | **Sales detail** | Items and payments grouped; the totals card still stands out |
| 15 | **Returns detail** | Item and sale grouped; refund summary still a card |
| 16 | A refund reported but not confirmed | **Amber**, with the waiting-for-confirmation wording. Never green |
| 17 | A confirmed refund | Green — the only place it is allowed |
| 18 | **Supplier detail** | Deliveries and payments in SEPARATE grouped lists |
| 19 | **Transfer creation** | Form steps keep their surfaces; the review list is one group |
| 20 | Transfer to the same branch | Not offered |
| 21 | **Notifications** | Flat rows; unread has the wash AND the word |
| 22 | Notifications with VoiceOver | Announces "unread" before the title |
| 23 | **More** | Grouped destinations; **sign-out separate, below, in danger tone** |
| 24 | Any index list (expenses, loans, suppliers…) | Adjoining rows, hairline between, **no rule under the last row** |
| 25 | Dark mode, all of the above | Selected/unread wash is a DEEP indigo, not pale |
| 26 | **Arabic RTL** | Rows mirror; **separator indents from the correct side** |
| 27 | Reduce Motion | Sheets fade in place; buttons do not scale; dialog does not zoom |
| 28 | Offline mid-action | Clear offline state, safe retry, no raw error |
| 29 | Large text | Nothing clipped; primary actions still reachable |
| 30 | Scroll a long list hard | No stutter from the new grouping |
| 31 | **Scan an IMEI already in your stock** | "This phone is already in inventory", product and branch shown, **Use this IMEI disabled**. Scan again / manual / Cancel still work |
| 32 | Scan an IMEI of a model you stock but a handset you do NOT hold | **No warning.** Recognising the model is not holding the phone. And no cost or margin anywhere in the warning |
| 33 | **Analytics → Export → Profit by product** | The iOS share sheet opens. Save to Files, then open it: the columns are readable and the name says the report, the period and the branch |
| 34 | Export in Arabic, then open the file | Arabic headers read correctly, **not as mojibake**. This is what the byte-order mark is for and only a real spreadsheet can prove it |
| 35 | Start an export, then switch branch before it finishes | Nothing is saved. The app says the report was discarded, rather than handing over the other branch figures |
| 36 | **Sell at ten times the set price** | "Does this look right?" with what you typed AND what similar items cost. **Nothing is sold until you answer.** "Let me check" leaves the sale exactly as it was |
| 37 | Confirm past that warning | The sale completes at the price you confirmed. Selling at just under ten times raises nothing at all |
| 38 | **Sell below the set price, still profitable** | Refused, and the sheet opens on **the right phone** with the set price, your price, the discount and the percentage |
| 39 | Ask the Owner, as an employee | "Asked. The Owner has been told." Then **Waiting for the Owner**, and it keeps saying nothing has been sold |
| 40 | **Owner: the notification** | Opens **that request**, not a list. Shows the item, the branch, who asked, the reason and the minutes left |
| 41 | Owner: approve | The confirmation says ONE sale, THIS item, THAT price, THOSE minutes. Not a bare "Approve?" |
| 42 | Back on the seller's phone | Turns to **Approved**, and completing the sale uses the approved price |
| 43 | Try the same approval a second time | Refused. An approval is spent |
| 44 | Owner: refuse one instead | The requester sees **Not approved** with the note, and the sale still will not go through |
| 45 | Below cost, as somebody who may see cost | The loss is shown as an amount |
| 46 | Below cost, as somebody who may NOT | "This price needs a stronger approval." **No amount, no hint of the cost** |
| 47 | **Owner approving their own request** | Same friction, and the screen says the request is yours |
| 48 | Withdraw your own pending request | It goes; somebody else's Withdraw is not offered |
| 49 | Turn the Wi-Fi off on the approval screen | "An approval is a decision, and it cannot wait in a queue." No cached queue is shown |
| 50 | **Analytics → Needs your attention** | Sentences with numbers in them, worst first, and a line saying when they were worked out |
| 51 | Dismiss one | Confirms it hides for a week for the whole shop, then it goes and the others stay |
| 52 | The same panel as a Store Manager | **No seller-margin row and no below-cost row.** Those are the Owner's |
| 53 | Turn the Wi-Fi off on Analytics | The panel says these are worked out on the server, rather than showing yesterday's |
| 54 | **Arabic: the whole approval flow** | Reads naturally, not word-for-word English. Prices stay left-to-right; the sheet mirrors |
| 55 | **Arabic: an anomaly sentence** | Numbers sit correctly inside an RTL sentence |
| 56 | Dark mode, approvals and the attention panel | The warning tone is legible, not a dark-on-dark chip |
| 57 | Reduce Motion, the approval sheet | Fades in place. No slide, no scale |
| 58 | The approval screen with VoiceOver | The state is announced as a word, never by colour alone |

### Highest risk

1. **#26** — the RTL separator inset. It is a `marginStart`, so it *should*
   follow direction, but that is an assertion about a layout engine, and it is
   invisible to anyone testing in English.
2. **#9–11** — the scanner through the reveal.
3. **#24** — first/last row treatment across eight converted lists.
4. **#25** — dark mode over many newly grouped surfaces.

## 15. The Indigo Stock screen — UNVERIFIED ON ANY DEVICE

Mobile `reports-export` after `20619e4`, backend `63ce639` (`GET /inventory/summary`).
Rendered in a web build during implementation; **none of the rows below has been
run on a handset.** Sign in as `devtest@example.com`, branch **Main Store**.

| # | Do this | Expect |
|---|---|---|
| S1 | Open the **Stock** tab | Compact "Stock" title with the branch name, one search field, All / Phones / Accessories chips, and a **Receive stock** button pinned above the tab bar |
| S2 | Look at a phone row | Brand and model, the exact variant (storage · colour), "Price … MRU" or "From … MRU", the number available, and a neutral category tile — **no photo of another model or colour** |
| S3 | Find a variant whose units have different prices (set a unit override on one) | The row says **From** the lower price, never one price for all |
| S4 | A variant with no price | "No price set", never 0 MRU |
| S5 | A variant at or below the shop's low-stock threshold | A **Low stock** chip with the word, not colour alone; an empty accessory line says **Out of stock** |
| S6 | Tap **Phones**, then **Accessories**, then **All** | Rows narrow and return; counts on the chips match the rows |
| S7 | Tap a phone row | The unit list for that exact variant, with "Showing …" and a close button; status chips (In stock / Sold / Faulty / All) appear here, not beside the categories |
| S8 | Tap a unit, then back | Unit detail opens; back returns to the same filtered list |
| S9 | Tap an accessory row | Product detail opens |
| S10 | Type a phone's **first** IMEI, then its **second** IMEI | Both find the same handset |
| S11 | Tap the camera in the search field and scan an IMEI barcode | Result shows with scanning paused; the unit opens; no OCR |
| S12 | Switch branch from More, return to Stock | The new branch's shelf; no row, search or "Showing …" from the old branch flashes |
| S13 | Scroll to the last row | It scrolls fully clear of Receive stock and the tab bar |
| S14 | Tap **Receive stock** with a half-finished delivery saved earlier | Receive opens with the draft notice and the staged items restored, for this branch only |
| S15 | Sign in as an employee without `purchase.manage` | No Receive stock button; the list is otherwise the same |
| S16 | Airplane mode after the list loaded, pull to refresh | "You are offline…" notice above the last loaded rows; nothing reads as zero |
| S17 | More → Language → Arabic, **fully close and reopen the app**, open Stock | Arabic mirrors — tile on the right, counts on the left, chips read right to left; IMEIs, model names and amounts keep their order. Before the relaunch the restart notice shows and the layout is still LTR |
| S18 | Largest system text size | Names wrap rather than truncate essential words; Receive stock stays readable and reachable |
| S19 | Dark mode | Rows, chips and the tile remain legible; low/out-of-stock chips keep their words |
| S20 | VoiceOver on a row | One sentence: name, variant, available, price, status |
| S21 | Look at the tab bar on a phone with a home indicator, and on one without | Every label fully visible, above the home indicator |
| S22 | A branch holding a TV, laptop or console | An **Other devices** chip with its count; the device is also under All |
| S23 | An accessory line with stock reserved for a transfer | "Reserved: n · On hand: m" on the row; the Low stock chip, if shown, agrees with On hand |
| S24 | Receive stock → scan a registered IMEI → cost → Finish | Nothing received; "Not received — already registered" with the IMEI; the delivery stays on screen |
| S25 | Receive stock → stage an item → kill the app → reopen Receive | The draft notice and the staged item return (drafts are not kept on web, so only a handset proves this) |

> **Web evidence, correction pass.** Arabic now mirrors in the web build too
> (document `dir="rtl"`; row geometry measured: tile right, count left) — the
> earlier note that this was native-only was wrong. That does **not** settle
> S17: native direction comes from `I18nManager.forceRTL` and a relaunch, which
> only a handset exercises.

## 16. Receiving correction — UNVERIFIED ON ANY DEVICE

Backend with `units[].imeiSecondary` and scan `hintCode`; mobile Receive
correction (commits in the handoff). Proved in code, over HTTP on an isolated
MySQL copy, and nowhere else. **R9 is the only proof of native draft
restoration; a web render cannot close it** (drafts are not kept on web).

| # | Do this | Expect |
|---|---|---|
| R1 | Receive stock → camera → a dual-SIM box showing IMEI 1 and IMEI 2 | The cost sheet shows both; after Add, the staged phone lists IMEI 1 and "IMEI 2 …" |
| R2 | Type a single-SIM IMEI in the scan field | Cost sheet; IMEI 2 field empty and optional; Add works without it |
| R3 | On a staged phone tap **Add IMEI 2**, type an invalid number, then IMEI 1, then a valid new one | "Not a valid IMEI", "This is IMEI 1 again", then saved under the phone |
| R4 | Scan a phone already in stock (by IMEI 1, then by IMEI 2) | Blocking card naming the phone and branch before any cost field; **Open this phone** opens it |
| R5 | Scan the same phone twice in one delivery, or use one phone's IMEI 2 as another's IMEI 1 | "This phone is already in this delivery" |
| R6 | Scan an unknown IMEI in French, then Arabic | Localized hint saying the IMEI is kept for this phone only; no English sentence |
| R7 | Unknown IMEI → **Choose product** → pick one | Card shows the chosen product; cost entry follows |
| R8 | Unknown IMEI with IMEI 2 typed → **Create new product** → save | Back on the same Receive screen, created product selected, both IMEIs kept; Stock shows no new unit yet |
| R8b | Same, but tap Back on the product form | Back on the same phone, both IMEIs kept |
| R9 | Stage two phones (one with IMEI 2) → kill the app → reopen Receive | Draft notice; both phones, IMEI 2 and supplier restored |
| R10 | Finish a delivery where one phone was registered meanwhile on another device | Partial: received items gone from the list, the refused phone listed with its reason; Finish again sends only it |
| R11 | Airplane mode at the moment of Finish, then back online → **Check again** | Locked list with "We could not confirm this delivery"; Check again receives it once — Stock count rises once |
| R12 | VoiceOver / TalkBack on the staged phone list and the IMEI 2 field | Labels read IMEI 1, IMEI 2 and "Add IMEI 2" |

## 17. Unit detail and History — UNVERIFIED ON ANY DEVICE

Web renders in French and Arabic only. Sign in as `devtest@example.com`, Main
Store.

| # | Do this | Expect |
|---|---|---|
| U1 | Stock → tap a phone variant → tap a unit | The back control is an arrow only — **never "(tabs)"** or any route name; VoiceOver says "Back" |
| U2 | Same from Sell, Transfers, a scan result and More | Arrow-only back everywhere |
| U3 | Unit `358888000000014`, French | Summary: product, *Statut actuel*, *Identifiants* (IMEI 1), *Emplacement*, *Achat*; history with *Envoyé par transfert*, *Reçu à Warehouse*, *Transfert annulé — de nouveau en stock*, *Transfert refusé — de nouveau en stock*; dates as *9 août 2026* |
| U4 | Same unit, Arabic, after relaunch | Mirrored: icon on the right, time on the left; IMEI, times and dates read correctly; *السجل* grouped by date |
| U5 | Unit `358888000000022` | *Rapporté par le client* and *Retour accepté — mis de côté comme défectueux*, with the actor and role; *Voir 17 événements de plus* reveals the rest |
| U6 | A folded row showing *2 fois* | Tapping lists each time; tapping again hides them |
| U7 | A dual-SIM unit | IMEI 1 and IMEI 2 on separate rows |
| U8 | A serial-tracked unit (a TV) | *Numéro de série*, no IMEI rows |
| U9 | Sign in as an employee without `cost.view` | No purchase-price row; nothing reads 0 |
| U10 | Create a new transfer for a unit, then open that unit | *Réservé pour un transfert vers …* appears (new audit entry) |
| U11 | Largest text size; dark mode | Titles wrap; tones keep their meaning; no raw code anywhere |

## 18. Sell (checkpoint 3a) — UNVERIFIED ON ANY DEVICE

Web renders in French, Arabic and French dark only; refusal and success were
rendered against an isolated copy of the database. Sign in as
`devtest@example.com`, Main Store.

| # | Do this | Expect |
|---|---|---|
| SL1 | Open Sell with an empty cart | Title, branch name under it, scan field; no charge bar |
| SL2 | Scan a phone with the camera, then an accessory barcode twice | Phone line with IMEI chip and number; accessory line with quantity 2 and *Prix unitaire* |
| SL3 | Type a price below cost on the phone | Line turns red **and** says *Vendre à perte ?*; total updates |
| SL4 | Keyboard open on the price field | The field and the charge bar stay visible; the last line is not hidden behind the bar |
| SL5 | *Encaisser* → payment sheet | Payment methods and return policy wrap onto a second row, nothing truncated; *Terminer la vente* fixed above the home indicator |
| SL6 | *Répartir entre plusieurs moyens* | Each entry: method chips, then amount and remove |
| SL7 | Price between cost and set price, *Terminer la vente* | *Ce prix nécessite le propriétaire* sheet with set price, your price, discount and a reason field |
| SL8 | Restore the set price and finish | *Vente terminée*, invoice number, amount; profit only for a role with `cost.view` |
| SL9 | Arabic | Mirrored; charge button, profit and dialog amounts read *1 500 MRU* in order |
| SL10 | Airplane mode, then *Terminer la vente* | The app says the sale is not confirmed and does not show success |
| SL11 | Employee without `cost.view` | No profit line, no below-cost flag; the server still refuses a price below the floor |
| SL12 | Largest text size; dark mode | Totals and prices wrap rather than clip; red/amber lines still carry words |

## 19. Receive (checkpoint 3b) — UNVERIFIED ON ANY DEVICE

Web renders in French, Arabic and French dark only; nothing was received.

| # | Do this | Expect |
|---|---|---|
| RC1 | Open Stock → Receive stock | Arrow-only back (VoiceOver: *Retour*); tapping it with items staged asks first |
| RC2 | Arabic | Arrow on the right pointing right; supplier button and scan field mirrored |
| RC3 | Scan a TV serial that is not in the catalogue → *Créer un nouveau produit* → back without saving | The same serial sheet reopens with the serial shown |
| RC4 | Same, but create the product (TV category) | Returns to Receive with the new product selected and the serial ready for its cost |
| RC5 | Stage an accessory at 8.5 MRU | Line shows *9 MRU l’unité* under the name and the total on the right |
| RC6 | Keyboard open in the cost sheet | Cost, quantity and price fields stay reachable; *Ajouter à la livraison* visible after scrolling |
| RC7 | Staged items, no supplier | *Terminer la réception* disabled **and** *Choisissez un fournisseur pour terminer* in words |
| RC8 | Largest text size; dark mode | Count tile, name and totals wrap rather than clip |

## 20. Transfers and consignments (checkpoint 3c) — UNVERIFIED ON ANY DEVICE

Web renders in French, Arabic and French dark against an isolated copy of the
database only.

| # | Do this | Expect |
|---|---|---|
| TC1 | Open an approved transfer | *Les articles — Toujours à {origine}*; *Prochaine étape — Expédition depuis {origine}* |
| TC2 | Ship it, then open it | *En route vers {destination}*; *Réception à {destination}*; wrong-branch card offers the switch |
| TC3 | Receive it at the destination | *À {destination}*; *Rien — terminé* |
| TC4 | Cancelled or refused transfer | *Toujours à {origine}*, reason shown; history has no *Envoyé* line (currently shows *Envoyé par quelqu’un* — reported) |
| TC5 | Consignment you proposed, not yet answered | *En attente de réponse*; *Chez vous*; *En attente de {boutique}*; *Rien n’est dû avant la vente*; **no Accepter / Proposer un autre montant** |
| TC6 | Same consignment on the receiving store's phone | *Accepter* and counter are offered; *Prochaine étape — À vous* |
| TC7 | Tap a transfer notification with the app closed | The transfer opens — not *Ce transfert n’existe plus* |
| TC8 | Sold consignment with a reported payment | *Vendus*; *Paiement en attente* (amber); *{montant} déclarés mais pas encore confirmés*; *Reste dû* unchanged |
| TC9 | Settled consignment | *Payé — confirmé* (green); write-off reads *Passé en perte*, never paid |
| TC10 | Arabic; long store name; largest text | Mirrored; long names wrap in the detail and are not squeezed in the list; amounts read *1 200 MRU* |

## 21. Money (checkpoint 3d) — UNVERIFIED ON ANY DEVICE

Web renders in French, Arabic and French dark on the live API, read-only.

| # | Do this | Expect |
|---|---|---|
| M1 | Money tab → *Espèces et comptes*, tap *30 jours* | Chip selected; *Ce que vous avez gagné* and *Ce qui a réellement bougé* both subtitled *30 jours* |
| M2 | Same, comparisons | *141 531 % de plus…* — grouped, no decimals; Arabic reads the number in order |
| M3 | Scroll to *Créances et dettes* | *Tel qu’à cet instant, pas sur la période ci-dessus*; untracked figures named as chips, not zeros |
| M4 | Expenses | *En attente / Confirmées / Toutes* chips; reported amber, confirmed green, both with words |
| M5 | A loan with a reported payment | Status in words (*Paiement déclaré — non confirmé*); the amount formatted; *Reste dû* not reduced |
| M6 | Try an action the server refuses | A translated sentence, never the server's English |
| M7 | Daily closing, after sign-off | *{date localisée} est clôturée* — not *2026-09-11* |
| M8 | Largest text; dark mode; keyboard open on a count | Amounts wrap rather than clip; the count button stays reachable |

## 22. More (checkpoint 3e) — UNVERIFIED ON ANY DEVICE

Web renders in French, Arabic and French dark on the live API, read-only.

| # | Do this | Expect |
|---|---|---|
| MR1 | Open More as the Owner | Sections *Boutique, Équipe, Produits et réglages, Rapports, Sécurité, Langue et apparence, Compte*, then *Se déconnecter* on its own |
| MR2 | Tap *Retours* | Returns opens in one tap; back is an arrow only |
| MR3 | Sign in as a Manager, then an Employee | Only permitted rows; *Rapports* absent for the Employee; *Équipe* shows only *Objectifs* for the Manager; no empty section |
| MR4 | Arabic | Mirrored; row chevrons point left; the branch card's chevron is visible and points left |
| MR5 | Open an old `/hub/stock` link | The Stock hub still opens |
| MR6 | Largest text; dark mode | Section labels and rows wrap; sign-out stays separate |

## 23. The reported-gap fixes — UNVERIFIED ON ANY DEVICE

Web renders and request traces only. The deep-link case is the one that most
needs a handset, because a cold start there is a real cold start.

| # | Do this | Expect |
|---|---|---|
| G1 | Force-quit the app, then tap a transfer notification | The transfer opens — never *Ce transfert n’existe plus* |
| G2 | Same, for a consignment and a loan notification | Each opens; no permission error on the first paint |
| G3 | Approve a transfer, cancel it, open its history | *Demandé*, *Approuvé*, *Annulé* — and **no** *Envoyé* line |
| G4 | Ship a transfer, then open its history | The *Envoyé* line is there, naming whoever shipped it |
| G5 | Arabic, More | The branch card's chevron is visible and points **left**, like the row chevrons |
| G6 | Arabic, largest text size | The chevron stays inside the card and does not clip |
| G7 | Sell a phone over 1 000 MRU and read the charge button | Decide whether *1015 MRU* is clear enough, or whether the group space should be widened everywhere (owner's call — see `docs/21`) |
