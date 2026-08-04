# 01 — Product Vision

> **Scope update (2026-07-30):** generalized from a phone-store ERP to an **Electronics Retail Management System** covering every product category and tracking type (IMEI / serial / quantity). See [`18_ELECTRONICS_RETAIL_PIVOT.md`](18_ELECTRONICS_RETAIL_PIVOT.md). The vision below applies to electronics retail broadly (phone-specific wording is historical).

## One-line vision
An **Electronics Retail Operating System** that replaces the shopkeeper's notebook — faster, safer, and smart enough to think alongside the owner.

## What this is
This is an **internal operations tool** for the people who run an electronics store. It is used by owners, managers, employees, and warehouse staff. It is **not** a customer-facing app — customers never see it, never log in, never install it.

Its single job: make running a phone business **faster than a notebook, easier than a spreadsheet, and harder to get wrong.**

## What problem we are solving
Phone shops today run on:
- Paper notebooks (lost, unreadable, un-searchable, no backups).
- WhatsApp messages to track stock and debts.
- Spreadsheets that only the owner understands.
- Memory — "I think we have two of those in the back."

The result is predictable: lost IMEIs, forgotten supplier debts, stock that silently runs out, theft that goes unnoticed, and an owner who cannot leave the shop without everything falling apart.

## The core promise
> Everything the notebook did, but instant, searchable, backed up — and it tells you what needs attention before you have to ask.

Three pillars:

1. **Less work.** Scan instead of type. Auto-fill instead of re-enter. Suggest instead of ask. Every screen should require fewer taps than the paper equivalent.
2. **Fewer mistakes.** The system refuses to let the same IMEI be sold twice, warns before selling below cost, and flags when a number "doesn't feel right." Errors are prevented, not just recorded.
3. **A business that thinks.** The app is a quiet assistant. It watches sales speed, cash flow, and stock, and surfaces what matters *today* — in plain language, not dashboards full of numbers.

## The "Alive" philosophy
This must **never feel like accounting software.** Accounting software reports the past. This app **talks about the present and the near future**, in the language a shop owner uses.

| Dead software says | Our app says |
| --- | --- |
| "Low stock: iPhone 16 Pro (3)" | "Only 3 iPhone 16 Pro left. At today's pace they'll be gone in ~5 days." |
| "Profit today: 4,200" | "Profit today is 18% above yesterday. Strong morning." |
| "Payment overdue" | "Karim's shop owes you 12,000 — 9 days late. Want to send a reminder?" |
| "New sale recorded" | "Nice — that's the 3rd Samsung A55 this week. It's your fastest mover." |

The feeling we are chasing: opening the app should feel like **a sharp assistant greeting you with 'here's what you need to know.'**

## Who wins
- **The owner** can step away and still trust the shop.
- **The manager** sees the whole floor at a glance.
- **The employee** learns the app in an afternoon and stops fearing mistakes.
- **The warehouse** always knows what is real stock vs. what is sold.

## What success looks like
- A new employee is productive on day one.
- No IMEI is ever sold twice.
- The owner knows the day's profit and health without asking anyone.
- Daily closing takes under two minutes.
- Nobody in the shop misses the notebook.

## Explicit non-goals (for v1)
- Not a customer marketplace or storefront.
- Not a full double-entry accounting/tax package.
- Not a repair-ticketing CRM (may come later).
- Not an e-commerce/online-order system.

## Guiding sentence for every decision
> *"Does this make the shop faster, safer, or smarter — with less typing?"*
> If not, it does not ship.
