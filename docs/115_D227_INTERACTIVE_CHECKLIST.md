# D227 interactive checklist (basket, Security and code delivery, opening and day-choice sheets, small iPhone)

Decisions: `docs/21` D227. Evidence: `docs/113`. This is the one list for what only a person with a phone can prove.
Nothing here enables production messaging, deploys, or uses the owner's real business.

## 1. What you need, and why there are two passes

| | Pass 1: before any deployment | Pass 2: release acceptance |
|---|---|---|
| **Build** | Expo Go (SDK 58) on your iPhone, on the laptop's Wi-Fi, from Metro on port 8082. Mobile `8cf3d36` or later: the phone shows it at More → Devices → This device. | TestFlight **internal** Build 4 candidate (`1.0.0 (4)`), built from the release commit with EAS. No external testers. |
| **API** | The laptop's local D227 API (backend `987eea7` or later) on a disposable database, seeded with a fictitious test shop. Never production. | Production API after the approved D227 deployment, using the **Test business** only. |
| **Codes** | Not delivered: the local channel is `development-log`, by design. Security can only be checked up to "the code could not be delivered". | Real WhatsApp, through the already-approved authentication template, to **your own verified number**. No template, limit or credential changes. |
| **Covers** | Basket, returns, opening and day-choice sheets, Balances, Maintenance, More. Left-to-right languages only. | Arabic right-to-left layout and Security end to end with real code delivery. Also anything Pass 1 could not cover. |
| **What I need from you** | The iPhone, on the same Wi-Fi, with Expo Go signed in as before. About 45 minutes. You press; I watch the API log. | The release approval, the SSH session at deployment, the EAS build started by you (EAS credentials stay yours), and your phone for about 30 minutes. |

**Why two passes:** Expo Go cannot apply a right-to-left layout (measured 2026-10-07), and nothing local delivers a
code. A TestFlight build cannot reach the laptop's plain-HTTP API, and D227's backend is not deployed. So Arabic layout
and real delivery can only be proven by Pass 2.

**Small iPhone:** an iPhone SE (2nd or 3rd generation, 375×667 points) or a 12/13 mini (375×812). If you have none,
say so: the web check at 375×667 in the visual gate is the only substitute. It is not equivalent: no safe area, no
keyboard, no native sheet. That would stay recorded as a gap.

## 2. Basket (Pass 1; repeat the starred items on the small iPhone)

1. ☐★ Sale → **Add from stock**: add a phone by IMEI, an accessory by quantity (3) and a serialized accessory. The basket shows three lines with their totals.
2. ☐ Change the accessory to 2, then remove the serialized one. The total follows. Back out and come back: the basket is the same.
3. ☐★ **Price review:** set one line below its cost. It asks for approval and names the line. As an Employee, the sale cannot finish without it.
4. ☐ **Approval:** a Manager approves from the approval sheet. Change the basket after the approval: the approval no longer applies (the cart changed) and is asked again.
5. ☐★ **Split payment:** part cash and part mobile money. The two must add up to the total; one that does not is refused in place.
6. ☐ **Receipt:** the receipt shows every line, the payments and the store name. No Owner's personal name appears unless one is set as the trading name.
7. ☐ **Repeated counted return:** return 1 of the 2 accessories as *resellable*, then the other as *damaged*. Each refund is that unit's share. A third return of the same line is refused. The damaged unit does not go back to stock.
8. ☐ The day's report shows the sale, the two returns and the net.

## 3. Opening and day-choice sheets (Pass 1, then on the small iPhone)

1. ☐★ First open of the day, with **cash tracking ON**: the opening sheet asks for the opening amount. The figure and its label are visible above the keyboard, the button is reachable, and nothing is clipped at 375×667.
2. ☐ With **all tracking OFF**: the day opens with no amount asked. Store balances shows nothing claimed.
3. ☐★ **Day choice:** with yesterday not closed, the day-choice sheet offers to close yesterday or continue. Each option says what it does. Back dismisses it with nothing changed.
4. ☐ The closing shows the drawer equation, with cash repairs on their own line. An untracked location says "not countable" and makes no drawer claim.

## 4. Security and sign-in

**Pass 1 (local):**
1. ☐ A wrong current password is refused in one sentence.
2. ☐ The right password, then "send code": "The code could not be delivered. Nothing changed." The old password still works.
3. ☐ The email row says it is unavailable.

**Pass 2 (production, Test business, your own number):**
1. ☐ **Password change:** a code arrives on WhatsApp; enter it with a new password. This phone stays signed in. Another signed-in session (the web portal or a second device) is signed out. The old password is refused at the next sign-in.
2. ☐ **WhatsApp change:** the code goes to the old number first, then to the new one; after the second code the number has changed. A number already used by another person in the business ends with the generic refusal, and nothing is sent to that number.
3. ☐ **Code reuse and expiry:** a used code is refused. A code older than 15 minutes is refused. Five wrong codes lock it, and it says to ask for a new one.
4. ☐ **History** lists the events, with masked numbers only.
5. ☐ **Rate limit:** many codes in a row end in "Too many codes. Try again in a little while." No logout-all is used in any step.

## 5. Small-iPhone checks (all screens above, plus)

1. ☐ More: Business access is the first row and fits on one line, or wraps without clipping.
2. ☐ The basket's total and the main action stay visible with the keyboard open.
3. ☐ Every sheet can be scrolled to its last action, and every button is reachable with one thumb.
4. ☐ Devices list: names wrap; nothing overlaps the status.
5. ☐ Text set to the largest standard size: nothing clipped on the sale, closing or Security screens.

## 6. Recording

Each item gets ✅ or ❌, with the phone model, the build line from More → Devices, and a screenshot for every ❌. I record
the results in `docs/113` against the exact mobile and backend commits.
