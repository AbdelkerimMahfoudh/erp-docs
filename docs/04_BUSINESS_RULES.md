# 04 — Business Rules

The non-negotiable logic of the phone business. These rules are what keep the data honest and the shop safe. They drive both the backend and the Mistake Prevention System.

---

## A. IMEI & Unit Integrity (the sacred rules)
1. **An IMEI is unique across the entire system.** The same IMEI can never exist twice as "in stock."
2. **An IMEI can be sold exactly once.** Selling an already-sold IMEI is **blocked**, not warned. (A returned unit must first be marked Returned/back-in-stock.)
3. Every IMEI must be **valid**: 15 digits, passes Luhn checksum. Invalid IMEIs are rejected at entry with a clear reason.
4. Dual-SIM devices may carry **two IMEIs**; both are recorded and both are unique.
5. Every IMEI-tracked unit always has exactly one **status**: `In stock · Reserved · Sold · Returned · Faulty · In transit · Transferred out`.
6. Every status change is **logged** with who/when. A unit's full history is always reconstructable.

## B. Stock Rules
7. You cannot sell what you do not have. Selling requires an in-stock unit at the selling branch.
8. Non-serialized items (accessories) are tracked by **quantity**; quantity cannot go negative.
9. **Stock lives at a branch.** Moving stock between branches requires a **transfer**, and stock is "in transit" until the receiving branch confirms.
10. **Cost price is recorded per unit at purchase.** Profit uses the actual cost of the specific unit sold (not an average), so margins are exact.
11. A unit unsold beyond the owner-set threshold (default suggestion: 60 days) is **dead stock** and surfaced for action.
12. "Days of stock left" per product = current quantity ÷ recent daily sales velocity.

## C. Pricing & Margin Rules
13. Every product has a **cost** and a **selling price**; **margin = price − cost**.
14. Selling **below cost** is possible only with an explicit override, is flagged, and is logged.
15. Discounts are bounded by role (employee limit < manager limit < owner unlimited). Exceeding the limit requires a higher-role approval.
16. Prices are never silently overwritten — price history is kept.

## D. Sales & Payment Rules
17. A sale records: unit(s)/product(s), price, cost (for margin), discount, employee, branch, timestamp, payment method(s), customer (optional).
18. **Partial payment / credit** is allowed (0074), including nothing paid at all: the unpaid balance is a **receivable owed by exactly one debtor** — a customer (selected, or typed with a name and optional phone) **or** a partner store with an accepted connection. A sale leaving money owing without a debtor is refused. The receivable is the sale's own `balance_due`; there is no second ledger.
19. Mixed payments (e.g. part cash, part card) may total **less** than the sale, never more. Status comes only from money received: **Unpaid** (nothing), **Partially paid**, **Paid in full** (nothing left) — never from a request having succeeded.
19a. **A later payment is not a second sale** (0074). The phone is sold once, on the original sale, with its revenue and profit on that sale's day. Money received later is a payment dated **the day it arrived**: it raises cash (cash only) or the chosen account (that account only), lowers the balance by the same amount, and never raises sales count, sales value or profit. Zero, negative and overpayments are refused, as are inactive accounts, future or pre-sale dates and signed-off days. Each collection carries one idempotency key bound to its payload.
19b. A payment keeps the account label and provider **as they were** when the money arrived; renaming or deactivating the account later rewrites no history.
19c. **Finding the phone to sell** (scan, typed IMEI or stock) reads one existing unit and never creates stock. A phone in **another branch** is disclosed only to `branch.manage` (status and branch name); everyone else gets "This phone is not available in this branch.", identical to a number that exists nowhere. The server decides.
19d. **IMEI visibility.** Full: the typing field, the scanner result, the completed Sale detail (authorised staff) and the customer receipt (warranty proof; no cost, margin or internal ids). Masked to the last four: stock lists, the pre-payment preview, Money previews, notifications and compact summaries. Lookup and uniqueness always use the full IMEI.
20. A **return** reverses the sale: unit goes back to stock (or Faulty), receivable/refund adjusted, and the event is logged. Returns are never a silent delete.
21. Nothing financial is **hard-deleted**. Corrections are reversals/adjustments, preserving the audit trail.

## E. Supplier & Payables Rules
22. A purchase creates stock **and** (if unpaid) a **supplier payable** with a due date.
23. Supplier balances are tracked continuously; overdue payables surface in "Needs Your Attention."
24. Paying a supplier reduces the payable and is logged.

## F. Daily Closing Rules
25. A day can be **closed once**; closing locks that day's transactions against casual edits.
26. Closing reconciles **expected cash vs. counted cash**; any difference is recorded and flagged (possible shortage/theft/error).
26a. Sale money is counted on the day it **arrived** (`payments.paid_at`), in the closing, in per-channel movements and in "collected" — never on the sale's day (0074). Every movement appears in exactly one day. The Money screen's "cash in the drawer" is the same expected figure the closing uses; each day is reconciled on its own, with no opening float carried over. Account figures are recorded movement, never a balance: the app does not see the account itself.
27. The app **warns if a prior day was never closed** before starting a new one.
28. Post-close corrections require a higher role and are logged as adjustments.

## G. Expense & Profit Rules
29. **Net profit = gross margin − expenses** for the period. Margin alone is never presented as profit.
30. Recurring expenses (rent, salaries) auto-generate each period from templates.

## H. Branch & Access Rules
31. Data is scoped by branch; users see only branches they're assigned to (owner sees all).
32. Cost/profit visibility follows role (see roles doc), enforced on the **server**, never just hidden in the UI.

## I. Mistake-Prevention Triggers (plain-language warnings)
The system actively watches for and flags:
- Duplicate IMEI (block).
- **Inventory mismatch** — expected stock vs. counted stock differs (flag for review).
- Sell below cost / abnormally low price / **wrong-cost** (warn + override + log).
- Price off by an order of magnitude (likely a typo — "Did you mean 45,000, not 4,500?").
- Storage/variant mismatch vs. recognized product.
- Selling a Reserved/Faulty/Transferred unit (block or warn per status).
- **Unauthorized actions** — blocked by server-side RBAC and logged.
- Cash reconciliation mismatch at closing.

**35. Discount monitoring is opt-in.** Discount-limit enforcement and "unusual discount / employee pattern" flagging are **OFF by default** and only active when the **Owner enables them** in Settings. Without it enabled, discounts are allowed within normal sale flow; with it enabled, discounts above the configured role limit require approval and deep-discount patterns are surfaced. This keeps small trusting shops simple while giving larger ones control.

**36. WhatsApp sends the short closing summary only** — date, time, revenue, cost of goods sold, gross profit. **No per-sale detail, IMEIs, or customer data** ever leave via WhatsApp; full detail stays in the in-app notification center (DailyDigest).

## J. Audit & Trust
33. **Every** create/edit/delete/override/status-change is attributable to a user and timestamped.
34. The audit trail is append-only and cannot be erased from within normal app flows.

---

## Assumptions to confirm with the owner
- **Currency & tax:** single currency assumed; VAT/tax handling is **out of scope for v1** unless required. *(Confirm.)*
- **Costing method:** exact per-unit cost (recommended for IMEI goods) rather than FIFO/average. *(Confirm.)*
- **Dead-stock threshold** default 60 days, **low-stock/days-left** thresholds owner-configurable. *(Confirm defaults.)*
- **Returns window:** is there a max return period? *(Assumption: configurable, default none.)*
- Can a sale be **fully deleted** by an owner, or only reversed? *(Recommendation: reverse only.)*
