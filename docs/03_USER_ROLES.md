# 03 — User Roles & Permissions

The app is used **only by shop staff**. There is no customer role. **Five roles**, ordered by authority. Role keys used in code: `owner · administrator · branch_manager · sales_employee · warehouse_employee`.

---

## Role summary

| Role | Sees money/profit? | Manages staff? | Manages branches? | Sells | Adds stock | Edits prices/cost | System settings |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **Owner** | Full | Yes | Yes (all) | Yes | Yes | Yes | Business settings |
| **Administrator** | Per grant | Yes (accounts) | Config | If granted | If granted | No (unless granted) | **Technical setup** |
| **Branch Manager** | Branch-level | Limited | Own branch | Yes | Yes | Yes (bounded) | No |
| **Sales Employee** | No profit/cost | No | No | Yes | Assist only | No | No |
| **Warehouse Employee** | No | No | No | No (sales) | Yes | No | No |

> **Owner vs Administrator:** the **Owner** is the business decision-maker (sees all money, sets prices/limits, receives WhatsApp). The **Administrator** is a *technical* admin who sets up the system — creates users/branches, manages integrations (WhatsApp, FCM), and configures settings — but is **not** automatically granted profit/cost visibility. In a small single-owner shop, one person may hold both; the roles are kept separate so a hired IT/admin person can run setup without seeing the books.

---

## 1. Owner
The business brain. Usually one person; may be off-site.

**Can:**
- See everything: all branches, all profit, cost, margin, health score, expenses.
- Add/remove/manage managers and employees, set permissions.
- Create and manage branches.
- Set prices, costs, discount limits, thresholds (low-stock, dead-stock, alerts).
- Receive WhatsApp summaries.
- View all reports and analytics.
- Override anything a manager can do.

**Primary need:** trust the shop without being in it. The dashboard, health score, and daily summaries are built for this person.

## 1b. Administrator (`administrator`)
The technical setup role — often the Owner in a small shop, or a trusted admin/IT person in a larger one.

**Can:**
- Create/manage users, roles, and branches.
- Configure integrations (WhatsApp Business API, FCM), thresholds, and system settings.
- Manage the product catalog and import/onboard bulk inventory (CSV/Excel).

**Cannot (unless the Owner explicitly grants):**
- See cost/profit/margin (money visibility is a separate grant, not implied by admin).
- Change prices or override money limits.

**Why separate from Owner:** lets a business hand off *setup and maintenance* without exposing the books. One person may hold both roles in a small shop.

## 2. Branch Manager (`branch_manager`)
Runs one branch (or a few) day to day.

**Can:**
- Everything an employee can, plus:
- See branch-level profit, cost, margin, expenses.
- Manage that branch's stock, purchases, suppliers.
- Approve discounts / overrides above employee limits.
- Perform and lock daily closing.
- View branch employee analytics.
- Approve incoming/outgoing stock transfers.

**Cannot (unless owner grants):**
- See other branches' data.
- Manage other managers or change global settings.
- Change cost prices beyond a configured bound (owner-controlled).

## 3. Employee (Salesperson)
The person at the counter. The largest group, often the least technical.

**Can:**
- Make sales (scan IMEI → sell), apply discounts up to a set limit.
- Look up products, stock, prices (selling price only), and availability.
- Register customers, take partial payments.
- See their own performance ("You've sold 6 today").
- Use universal search.

**Cannot:**
- See cost, margin, or shop profit.
- See other employees' figures.
- Change prices, edit stock costs, delete records, or close the day.
- Manage staff or branches.

**Design mandate:** an employee must become productive **on day one**, with almost no training. Their screens are the simplest in the app.

## 4. Warehouse Staff
Handles physical stock, not selling.

**Can:**
- Receive and add stock (bulk scan units in).
- Confirm and dispatch stock transfers between branches.
- Do stock counts / audits, flag faulty units.
- Look up where a unit is.

**Cannot:**
- Sell, see prices/profit, or manage people.

---

## Permission principles
1. **Least privilege by default.** New staff start as Employee.
2. **Money is need-to-know.** Cost and profit are hidden from anyone who doesn't need them; this is a theft/leak safeguard, not distrust.
3. **Limits, not just yes/no.** Employees can discount — up to a bound. Managers can adjust cost — within a bound. The owner sets the bounds.
4. **Every override is logged** (who, what, when, why) for the mistake-prevention/audit trail.
5. **Roles are per-branch where relevant.** A manager of Branch A is an employee-level viewer (or nothing) in Branch B unless the owner says otherwise.

## Open questions for the owner
- Should there be a distinct **Cashier** vs **Salesperson** split, or is one Employee role enough? *(Assumption: one Employee role for v1.)*
- Can a single person hold roles in multiple branches? *(Assumption: yes, role assigned per branch.)*
- Is an **Accountant / read-only reports** role needed? *(Assumption: not for v1; owner covers it.)*
