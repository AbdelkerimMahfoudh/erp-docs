# 02 — Feature Requirements

Each feature below is written as **what it must do** and **why it matters**, and is scored against the six core design principles (reduce typing, prevent mistakes, fewer taps, immediate value, simple for non-technical staff, feels alive).

Priority legend: **P0** = must exist for the app to be worth using · **P1** = strong differentiator, ship soon after · **P2** = later.

---

## 1. Smart Dashboard — P0
The home screen and the heart of the "alive" feeling.

Must show, in plain language:
- A greeting + today's headline ("Good morning. Profit is 18% ahead of yesterday.").
- **Business Health Score** (see below).
- **Needs Your Attention Today** (see below).
- Today's key numbers as *comparisons*, not raw figures (vs. yesterday / last week).
- 2–3 **AI-style recommendations**.

Rules:
- Never show a wall of numbers. Every number carries context or a trend.
- Everything on this screen is tappable → goes straight to the action.

## 2. Business Health Score — P0
A single 0–100 score (or Green/Amber/Red) summarizing shop health.

Inputs (weighted): profit trend, cash flow, stock coverage (days of stock left), overdue supplier/customer debts, dead stock, and sales velocity.

Must:
- Explain itself in one tap ("Why 72? — Two products are nearly out of stock and one supplier payment is overdue.").
- Never be a mystery number.

## 3. Needs Your Attention Today — P0
A prioritized action list, the "to-do the shop generates for itself":
- Stock about to run out (with predicted days left).
- Overdue debts (owed to you / by you).
- Unusual activity (a sale far below cost, a big discount, a returned unit).
- Dead stock sitting too long.
- Unclosed previous day.

Each item = one line + one-tap action.

## 4. IMEI Camera Scanning — P0
The signature "less typing" feature.

Must:
- Scan the IMEI barcode / QR on the phone box or device using the camera.
- Support scanning the **printed IMEI text (OCR)** as fallback.
- Support scanning **two IMEIs** (dual-SIM devices).
- Validate the IMEI (length + Luhn checksum) instantly.
- Auto-detect duplicates ("This IMEI is already in stock / already sold").
- Feed straight into Add Stock and Sell flows — no manual typing of 15 digits.

## 5. Automatic Product Recognition — P1
When an IMEI/model is scanned or a model is typed, auto-fill brand, model, storage, and typical specs from a **product catalog** so the user picks instead of types.

Must:
- Suggest the product from partial input ("ip 16 pr" → iPhone 16 Pro).
- Remember shop-specific products and default prices.
- Learn from what the shop actually sells.

## 6. Inventory Management — P0
The living record of stock.

Must support:
- **IMEI-tracked items** (each unit unique) and **non-serialized items** (accessories, chargers — tracked by quantity).
- Product, variant (storage/color), cost, price, supplier, branch location, date in.
- Status per unit: In stock · Reserved · Sold · Returned · Faulty · Transferred.
- Bulk add (scan many units of the same model quickly).
- Stock coverage / "days left" per product.
- Dead-stock flag (unsold beyond N days).

## 7. Sales Management — P0
Selling must be the fastest flow in the app.

Must:
- Sell by scanning the unit's IMEI (auto-pulls product + cost + suggested price).
- Show margin live as price is set; warn on below-cost or unusually low price.
- Support discount, trade-in, partial payment / credit (customer owes balance).
- Support multiple payment methods (cash, card, mobile money, mixed).
- Record which employee made the sale.
- Print / share a simple receipt.
- One tap to complete a normal sale.

## 8. Purchases & Suppliers — P0
Buying stock and tracking who you owe.

Must:
- Record a purchase (from supplier), bulk-add scanned units to stock in one go.
- Track supplier balances (what the shop owes, due dates).
- Show per-supplier history and reliability.
- Flag overdue payables in "Needs Your Attention."

## 9. Employee Management & Analytics — P1
Must:
- Per-employee sales, margin generated, discounts given, returns, hours/shifts.
- Flag risky patterns (excess discounts, many voids, below-cost sales) — mistake/theft prevention, framed constructively.
- Simple leaderboard ("Top seller this week").

## 10. Multiple Branch Management — P1
Must:
- Separate stock, sales, and staff per branch.
- Owner sees consolidated + per-branch view.
- **Stock transfers** between branches (with in-transit status and confirmation on receipt).
- Compare branch performance.

## 11. Daily Closing — P0
End-of-day ritual, under two minutes.

Must:
- Summarize the day: sales, profit, cash expected vs. counted, per-employee, per-payment-method.
- Cash reconciliation (expected vs. actual → flag shortfall/overage).
- Lock the day once closed; warn if a previous day is unclosed.
- Generate the owner's summary (see WhatsApp summaries).

## 12. Internal Notification Center — P1
In-app feed of what happened and what needs action: big sales, low stock hit, transfer received, debt overdue, day closed. Actionable, not noisy.

## 13. WhatsApp Owner Summaries — P1
Push a concise daily/period summary to the owner via WhatsApp:
- "Today: 14 sales, profit 21,400 (+18%). 2 products low. 1 supplier payment due tomorrow."
- Owner-configurable timing and content. (Delivery mechanism detailed in tech architecture.)

## 14. Monthly Expenses — P0
Track rent, salaries, electricity, misc. so **profit is real profit**, not just margin.

Must:
- Recurring expense templates (auto-appear each month).
- One-tap logging of common expenses.
- Feed net profit and the Health Score.

## 15. Reports — P1
Plain, useful, exportable:
- Profit (day / week / month), by branch, by product, by employee.
- Best & worst movers, dead stock, margin trends.
- Debtor / creditor lists.
- Export to PDF / share.

## 16. Universal Search — P0
One search box finds anything: IMEI, product, customer, supplier, sale, invoice, employee.
- Search as you type, ranked results, one tap to open.
- Scan an IMEI into search → full history of that unit.

## 17. Mistake Prevention System — P0
A cross-cutting safety layer, not a single screen:
- Block duplicate IMEI sale.
- Warn on below-cost / abnormal price / abnormal discount.
- Confirm destructive actions in plain language.
- Detect "this doesn't look right" (wrong storage, price off by 10×, duplicate entry).
- Every prevented mistake explained simply, never with a cryptic error.

---

## Cross-cutting requirements (apply to every feature)
- **Camera-first, type-last.** If it can be scanned or picked, don't make them type it.
- **Smart defaults** everywhere (last supplier, usual price, current branch, today's date).
- **Bulk actions** for anything repetitive.
- **Offline-tolerant** where feasible (the shop's internet is not reliable).
- **Undo** over confirm-dialogs where safe.
- **Plain language** in every message — no jargon, no codes.
