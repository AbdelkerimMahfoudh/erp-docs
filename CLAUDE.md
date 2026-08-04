# CLAUDE.md — Development Rulebook

This is the **permanent rulebook** for this project. Every contribution — human or AI — must obey it. When in doubt, this file wins over habit, convention, or convenience. If a request appears to break these rules, raise it before acting.

> Companion docs live in [`/docs`](docs). This file is the law; `/docs` is the detail.

---

## PROJECT IDENTITY
- This is an **Electronics Retail Management System** — a retail operating system for any electronics store that replaces the shopkeeper's notebook. *(Formerly scoped as a phone-store ERP; generalized to all electronics — see [`docs/18`](docs/18_ELECTRONICS_RETAIL_PIVOT.md).)*
- It handles **every product category and tracking type**: IMEI (phones/cellular), serial number (TVs, laptops, consoles, cameras, power stations, …), and barcode/quantity (accessories/bulk). Workflows adapt automatically to the tracking type.
- It is **not** a customer application. Customers never log in, install, or see it.
- It is **only** for internal staff:
  - **Owner**
  - **Managers**
  - **Employees**
  - **Warehouse staff**
- Its job: make running an electronics business faster than notebooks, easier than spreadsheets, with fewer mistakes.
- *(The repo folder is still named `PhoneStoreERP` for path stability — the product name is Electronics Retail Management System.)*

## CORE PRINCIPLES
Every feature, screen, and line of code is measured against these:
1. **Reduce typing.**
2. **Reduce mistakes** (prevent them, don't just record them).
3. **Be faster than a notebook.**
4. **Employees should learn it quickly** — productive on day one, no manual.
5. **Every action must provide value** — no feature or step ships without a stated reason.
6. **The app must feel alive and intelligent** — an assistant, not a ledger.

## DEVELOPMENT RULES
- **Prioritize automation** — the app should do the work, not the user.
- **Prefer scanning over typing.**
- **Prefer auto-fill over manual entry.**
- **Prefer simple workflows over complicated systems.**
- **Prefer smart defaults over forms.**
- **Do not add unnecessary features.** No speculative or "nice to have" code; every feature is justified.
- **Do not sacrifice simplicity for complexity.** The simplest solution that works, wins.
- **Never add features without explaining their value.**
- **Always consider non-technical employees** — they are the primary users.
- Do not invent requirements. If something is unspecified, ask or document the assumption.
- Reuse before rebuilding; match the style of surrounding code.

## UX RULES
- **Minimum taps** — the common path is the shortest path.
- **Modern, futuristic, but simple design** — glanceable and confident, never busy.
- **Clean interface** — generous space, one focal point per screen.
- **No traditional, complicated ERP feeling** — no dense grids of raw numbers, no accounting-software look.
- **Show advanced information only when requested** — progressive disclosure; detail is one tap away, never in the daily path.
- **Use clear information hierarchy** — numbers carry context (trends, comparisons), never bare figures.
- Camera-first, type-last. Big, thumb-reachable touch targets. Plain language, never codes or jargon.
- Status shown by color **and** words (never color alone).

## TECHNICAL RULES
- **Follow the documented architecture** in [`/docs/06_TECHNICAL_ARCHITECTURE.md`](docs/06_TECHNICAL_ARCHITECTURE.md).
- **Do not change the database structure without explaining why** — schema changes require a written reason and a migration. See [`/docs/07_DATABASE_REQUIREMENTS.md`](docs/07_DATABASE_REQUIREMENTS.md).
- **Write clean, production-quality code** — readable, consistent, no dead code, no commented-out blocks left behind.
- **Add tests for important functionality** — especially the sacred rules: IMEI uniqueness, sell-once, margin/cost, cash reconciliation, permissions.
- **Document major decisions** — significant choices get a short note (in the relevant doc or a decision log), so the "why" survives.
- **Enforce business rules and permissions on the server**, never trust the client. See [`/docs/04_BUSINESS_RULES.md`](docs/04_BUSINESS_RULES.md) and [`/docs/03_USER_ROLES.md`](docs/03_USER_ROLES.md).
- Nothing financial is hard-deleted — corrections are reversals with an audit trail.

## BEFORE EVERY MAJOR IMPLEMENTATION
Do all four, in order, and stop:
1. **Explain the plan.**
2. **Explain the files that will change.**
3. **Explain possible risks.**
4. **Wait for approval before large changes.**

"Major" = new feature, schema change, new dependency, architectural change, or anything touching the sacred rules. Small, obvious fixes within an approved plan don't need re-approval — but if unsure, treat it as major and ask.

---

## The single test for any change
> *"Does this make the shop faster, safer, or smarter — with less typing — while staying simple enough for a first-week employee?"*
> If not, it does not ship.
