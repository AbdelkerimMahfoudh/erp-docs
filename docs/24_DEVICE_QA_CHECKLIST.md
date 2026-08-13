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
