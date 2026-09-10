# 08 — Development Roadmap

Sequenced so the app is **useful as early as possible**, then progressively smarter. Each phase ends with something a real shop could actually use. No dates — phases gate on "done and usable," not calendar.

Guiding order: **first replace the notebook, then prevent mistakes, then make it feel alive, then scale to many branches, then get smart.**

---

## Phase 0 — Foundation (this phase is documentation + setup)
**Goal:** agree on the plan and stand up the skeleton.
- ✅ Product docs (this `/docs` set).
- Confirm open questions (stack, DB, costing, tax, WhatsApp provider) with the owner.
- Initialize repo, backend skeleton (API + DB + migrations), and Expo app shell.
- Auth + Users + Branches + Roles (server-enforced).
**Done when:** a user can log in on the phone and see an empty, role-appropriate home.

## Phase 1 — Replace the Notebook (MVP core) — P0
**Goal:** a shop can stop using paper.
- **Product catalog** + product recognition/auto-fill (basic).
- **Inventory**: add stock, including **IMEI camera scanning** + validation + duplicate detection.
- **Sales**: scan-to-sell, price/margin, payment (cash + partial/credit), receipt.
- **Purchases & Suppliers**: record purchases, bulk add units, supplier balances.
- **Universal search** (IMEI/product/sale).
- **Mistake prevention (core)**: duplicate-IMEI block, below-cost warning, sane-price check.
**Done when:** a shop runs a full day of real buying and selling in the app instead of the notebook.

## Phase 2 — Control & Trust — P0
**Goal:** the owner trusts the numbers and can step back.
- **Daily Closing** with cash reconciliation + day lock.
- **Monthly Expenses** (incl. recurring) → real net profit.
- **Basic Dashboard**: today's sales, profit, key comparisons.
- **Employee attribution** on every sale; basic per-employee totals.
- Complete **audit log**.
**Done when:** the owner can close the day, see true profit, and know who did what.

## Phase 3 — Make It Alive — P1
**Goal:** the app stops reporting and starts advising.
- **Business Health Score** (with one-tap explanation).
- **Needs Your Attention Today** (low stock w/ days-left, overdue debts, anomalies, dead stock).
- **AI-style recommendations** (rules/stats engine).
- Plain-language, comparison-driven dashboard copy ("18% ahead of yesterday").
- **Internal Notification Center**.
**Done when:** opening the app feels like a briefing from an assistant, not a ledger.

## Phase 4 — Owner Away & Multi-Branch — P1
**Goal:** run several branches and manage remotely.
- **Multiple branches**: per-branch scoping, consolidated owner view, comparisons.
- **Stock transfers** between branches (in-transit → confirm on receipt).
- **WhatsApp owner summaries** (scheduled).
- **Employee analytics** + risky-pattern flags.
**Done when:** an owner with 2+ branches manages everything from their phone, off-site.

## Phase 5 — Insight & Polish — P1/P2
**Goal:** decisions get easier; edges get smoother.
- ✅ **Reports** (profit by product/employee/branch, movers, dead stock, debtors/creditors) — the figures were already on screen; the **CSV export** is done and documented in [`docs/40`](40_REPORT_EXPORT.md). PDF was deliberately deferred. Native sharing and spreadsheet compatibility are unverified — see `docs/24` §14 #33–35.
- **Full mistake-prevention suite** (order-of-magnitude typo catch, discount-limit approvals, anomaly detection).
- **Offline-first hardening** + sync conflict resolution.
- Bulk actions, templates, onboarding/empty-state polish.
**Done when:** the shop is faster and safer than any notebook or spreadsheet could ever be.

## Phase 6 — Future / Optional — P2
- Trade-ins & repair tickets.
- Barcode/label printing.
- Deeper customer CRM & loyalty.
- Tax/accounting export.
- Natural-language assistant (LLM layer) over the existing stats engine — ask the shop questions in plain words.
- Deeper analytics / forecasting.

---

## Sequencing principles
1. **Usable every phase.** Never a long build with nothing to show.
2. **Core before clever.** Selling and stock integrity before health scores and WhatsApp.
3. **Trust before scale.** Get one branch honest and closable before adding many.
4. **Rules before AI.** The deterministic engine delivers the "alive" feel; LLMs are a later flourish.
5. **Prevent mistakes throughout**, not as a bolt-on at the end.

## Immediate next step (recommended)
Start **Phase 0 setup**: initialize the backend + **MySQL** database schema for the core entities (with the tenant-scoping middleware), and scaffold the **Flutter** app with login and role-based home. Build the **IMEI scan → add stock → scan → sell** loop first — it is the spine of the whole product.

## Stack & decisions — resolved
All the original open questions are decided; see the frozen decisions table in [`06_TECHNICAL_ARCHITECTURE.md`](06_TECHNICAL_ARCHITECTURE.md) (D1–D11 + MySQL amendments M1–M6) and the schema in [`10_DATABASE_SCHEMA.md`](10_DATABASE_SCHEMA.md).
- Backend **NestJS + TypeScript** · Database **MySQL 8 (InnoDB) + Prisma** · Frontend **Flutter** · Offline **SQLite + Drift**.
- Costing **exact per-unit** · **Tax/VAT deferred to v2** (schema tax-ready) · WhatsApp **Meta Business Cloud API** · Cloud **AWS**.
- Offline scope: scan · add stock · sell · manual entry · local search · today's numbers · auto-sync + conflict resolution.
- Multi-tenant **Company→Branch, single-branch-first**; **single currency v1** (multi-currency seam reserved).
