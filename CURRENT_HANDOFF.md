# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Owner: **CLAUDE-A** · `started_at_utc: 2026-09-18` — Sell a phone: Scan IMEI / Enter IMEI manually /
  Choose from stock, one shared selection into the existing payment flow. Takeover HEADs:
  docs `91bd5f6` · backend `c7e1900` · mobile `8db73e0`, clean and level. Metro runs on the PC
  hotspot (192.168.137.1); the git-ignored mobile `.env.local` points the API there.
- Last owner: **CLAUDE-A** · 2026-09-18
- Last phase: **the Money redesign, partial payments and outstanding balances** —
  complete in code and on the live schema; **handset checks owed**.
- Takeover HEADs were docs `20fb84f` · backend `2e34ce1` · mobile `2530b22`, all
  clean and level, READY_FOR_HANDOFF, owner NONE — no discrepancy.

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. Goals, Analytics, anomalies, WhatsApp summary
settings, Partners, loans, consignments and every other feature stay. No removal
without the user's explicit approval. Nothing was removed this phase.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`c7e1900`** | level | 0 |
| `erp-mobile` | `reports-export` | **`8db73e0`** | level | 0 |

## What changed this phase

Full contract in `docs/21` (the Money redesign entry) and `docs/04` §D 18–19b, §F 26a.

| Part | Commits | Summary |
|---|---|---|
| **Migration `0074_sale_receivables`** | backend `7f43883` | payments gain `kind` (at_sale / collection), `recorded_by_id` (backfilled from the seller, 7/7), `client_uuid` + `client_request_hash` (unique per company), `reference`, `note`, CHECK amount > 0; sales gain `counterparty_id` (partner-store debtor) and CHECK paid/balance ≥ 0; expenses gain `receipt_key` |
| **Dating by arrival** | backend `98ffe3b` | closing expected cash, per-channel movements and "collected" read `payments.paid_at`, not the sale's day. No past day moved |
| **Partial payments and collections** | backend `38cd97a` | sales may leave money owing (even all of it) with exactly one debtor — customer (selected or typed) or a store with an accepted connection; `POST /sales/:id/payments` records later money, locked, idempotent, never touching revenue/profit; sale detail carries debtor and full payment history; `/sales/outstanding`, `/sales/by-day` |
| **Money overview** | backend `0441e03` | `GET /closings/overview`: drawer now (the closing's own figure), accounts today (recorded movement, not a balance), period phones / value / collected / owed, today's expenses |
| **Receipts** | backend `c7e1900`, `72edbc2` | optional receipt photo, type read from bytes, branch- and reporter-scoped; `/uploads/` ignored |
| **Mobile** | `64cc090` … `8db73e0` (8 commits) | data layer and pure rules; ~110 keys × EN/FR/AR and one status vocabulary; Outstanding under Money in the registry; redesigned Money tab, sales by day, Outstanding; sale history and Record payment; the payment sheet takes less than the total and asks who owes; expense date + photo (`expo-image-picker`); 37 new tests |

### Decisions a reviewer should know

- **No account balance and no "total available"** are shown: the model never
  learns an account's opening balance or private withdrawals, and reconciles each
  drawer day with no opening float. The brief allowed this condition.
- **A store as debtor is narrow on purpose**: our sale, our receivable; nothing
  written into the other company, and not added to the Partners shared summary
  (its privacy spec forbids reading sales there). The bilateral inter-store sale
  remains undecided.
- **Permissions reuse existing keys**: `report.view` for figures and Outstanding,
  `sale.create` for selling with a balance and recording a collection. No
  permission was added.

## Verification

| Kind | Result |
|---|---|
| **Backend** | `tsc` clean · **134 suites / 2 466 tests, 0 failed** (+`sale-payment-rules` 34, +`receipt-rules` 4, updated closing/collected specs) · `prisma validate` · catalogue and grants complete · **0 new schema drift** from 0074 (the 1 148-line baseline is pre-existing index naming) |
| **Real HTTP + real MySQL** (isolated restore of live, API on 3011) | **61 / 61**: the 25 000 sale with 15 000 cash, 10 000 owed by a customer; counted once; only 15 000 into cash; a later 4 000 into Bankily leaves 6 000, cash unmoved, account +4 000, profit/count/value unmoved; replay answers the same, reused key 409, overpay/zero/negative/inactive/future/pre-sale refused; two racing 6 000 payments settle to one; three identical retries record one; unpaid sale; debtor refusals; accepted store owes 15 000 with no consignment/loan written and nothing in the other company; a person and a removed connection refused; cross-company and cross-branch 404; employee 403 on figures but 201 on a collection; label survives rename and deactivation; cash expense lowers cash only, account expense that account only; receipt round-trips byte for byte; day/week/month boundaries; collected = every payment once; closing expected = overview drawer; day closes with **difference 0**; a payment into the closed day refused |
| **Live** | backup `~/erp-backups/phonestore-20260918-132538-pre-0074-receivables.sql` (845 704 B, restored with an identical fingerprint) and `…-140210-pre-0074-apply.sql` (taken immediately before); **0074 applied at 14:02 UTC**; afterwards every business fingerprint identical — only migrations 72 → 73 |
| **Mobile** | `tsc` clean · `expo lint` **0 errors / 32 warnings** (baseline) · **56 pure suites, 0 failed** (+`money` 37) · EN/FR/AR parity at compile time and per key · web export (all new routes) · iOS bundle · Expo Doctor **20/21** (pre-existing drift: `expo` 57.0.22 vs ~57.0.24, `expo-sharing` 57.0.19 vs ~57.0.21) |
| **Renders** | 80 captures — overview (today, 7 days), sales by day, outstanding, paid and partial sale, record payment, expense form × EN/FR/AR × light/dark × 320/360 pt: no overlap, clipping, sideways scroll, leaked key or small target |
| **Physical device** | 🔴 **none**. `docs/24` **§31 M1–M21** is the outstanding proof, plus §30, §30b–d |

## Services

- **Live API `:3010`** — PID 4816, rebuilt and started by the user at 14:48 from
  backend `c7e1900`; serves every new route (401 unauthenticated) on
  `192.168.22.10`, which the mobile `.env.local` targets. The machine rebooted
  earlier today; the LAN address changed from 192.168.100.3 to 192.168.22.10.
- **Metro `:8081`** — **not running**; not started by this session.
- **MySQL `:3306`** — the user's WAMP.
- Isolated API, static server and headless Chrome stopped; `prisma_verify_money`
  dropped; only the pre-existing `prisma_staging*` schemas remain.

## 🔴 Blockers and pending approvals

- **Native build blocker (pre-existing):** `npm install`'s postinstall fails —
  `expo-camera` 57.0.5 is installed but the Android scan-region patch was cut
  against 57.0.4 (alignment `e960ef6`). Expo Go is unaffected. A native build must
  re-cut the patch and re-verify scanning on Android.
- **Live rollup repair — still awaiting approval (NOT applied).** Audit shows
  `Sale create` ×28 on 2026-09-10 and ×4 on 2026-08-08 with no surviving sales
  (fixtures hard-deleted outside the app); rollups for those days overstate
  revenue by **388 340.00** (Home shows 328 300 profit). Procedure: backup per
  `docs/22` → `DB=phonestore node scripts/rollup-audit.js` (confirm exactly 2
  rows) → `… --repair`.

## 📋 Known, not fixed

- On web, a screen pushed from a tab announces its back button as "(tabs), back".
- A bottom sheet's Close button is 36 pt with no hit slop (app-wide, pre-existing).
- Dynamic type cannot be exercised in a web render; handset only.
- No catalogue images (`docs/47`). The pre-release security gate (`docs/48`) is
  not started. Owner decisions D4–D6 (hosting, database hosting, backups) block
  staging (`docs/45`); release risks in `docs/41` §6.

## The next exact action

1. Start Metro, reload the app on the iPhone, and run **`docs/24` §31 M1–M21**
   with a test customer — the Money redesign and partial payments on the handset.
2. Then §30 / §30b–d (file receiving) on the handset.
3. Decide the live rollup repair.
