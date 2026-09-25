# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Owner: **NONE** (released by CLAUDE-A at `2026-09-25T09:10Z`)
- Last session: **CLAUDE-A**, `started_at_utc: 2026-09-25T08:21Z` — **reporting consistency**: Money, Home, Analytics
  and goals now follow the Daily closing's and Results' dated rules (`docs/53`, `docs/21` "Reporting consistency").
  Takeover HEADs were docs `7ddf674` · backend `68c21e9` · mobile `40a9b2f` (all clean, level with `origin`). No
  migration; live untouched.
- **The WAMP MySQL service is RUNNING**, the **user's API is running on 3010** (started by the user at 07:45:14Z from
  `backend/dist`, built from `68c21e9` — it does **not** carry this session's backend commits until the user rebuilds
  and restarts it) and **Metro (8081) is running**. None was restarted or touched.
- Next intended action: **the handset runs** — `docs/24` §41 N1–N8 (after the user's API is rebuilt from `5acab28`),
  then §40 L1–L6, §39 K1–K14, §38 R1–R14, §37, §36, §35 and the older backlog, against the live API in Expo Go.

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed by this phase.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`5acab28`** | level | 0 |
| `erp-mobile` | `reports-export` | **`73fee6d`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

This phase: backend `1a5105e` (the dated definition), `60fe7e3` (Results: net refund due), `c9be28e` (cost keys),
`b17be0c` (Home, branches, sellers), `c7bd82c` (Money), `0a694a8` (closing report count), `bf525b2` (products and
categories), `f380747` (goals), `5acab28` (spec); mobile `dd309fc` (i18n), `11f3d8d` (Home), `2c22628` (Money),
`4cea1c8` (Analytics), `5c1cb91` (goals), `7ba2449` (Daily closing), `73fee6d` (test); docs `docs/53` (new),
`docs/21`, `docs/24` §41, the session log and this file. Earlier: backend `97695a8`, `68c21e9` (0081, the drift
audit); the completed three-day repair (`docs/52` §5).

## What changed (no schema change, no data change)

| Screen | Now |
|---|---|
| **Home** | Sales value on the sale dates; cancellations and **returns** (net refund due) on their approval dates, each its own line; count and phones = invoices less whole-sale cancellations; expenses = recorded − reversed, "After N reversed" |
| **Money** | **Items sold** = units sold (it counted phones only); cancellations, returns, net sales and the rule under the figures; day rows at their net, adjustment-only days listed; today's expenses on the accounting day (fixed = due date) with each reversal a negative row |
| **Analytics** | Products and categories net of cancelled lines and returns, returned units apart; sellers by business date, net, returns apart; branches net; the rule stated |
| **Goals** | Returns come off revenue and profit (branch and personal) on their approval dates; each goal states what it counts; gross-profit goals hidden and 404 without `cost.view` |
| **Daily closing** | The defined count and units, with the rule; the report version and every stored close unchanged |
| **Results** | Approved returns = net refund due (it took the gross); cost-side comparison keys stripped without `cost.view` |

Contract details: `docs/53` §5.

## Verification

| Kind | Result |
|---|---|
| **Scenarios on an isolated copy** (`prisma_verify_home` from `phonestore-after-rollup-repair-20260925-075339.sql`; API built into OS temp, 3012, fake clock) | `reporting-lifecycle` **59/59 steps, 53/53 screen checks expected = actual**: same-day cancellation; later-day cancellation over a closed day (the closed day byte-identical; the cancellation day −10 000 / −1 sale / −1 unit everywhere); partial return with a 500 fee kept, refund two days later (three days: net 10 500, profit 4 500; the refund day money only); full return, refund later; expense reversal on a day holding only it (−300 on Money, Home, Daily closing, Results). Figures per screen: `docs/53` §6 |
| **Cost gating** (manager without `cost.view`, day with rows) | 5/5 — no cost, profit or margin on products, categories, sellers, branches; no profit block or profit comparison in Results; no gross-profit goal; the Owner still sees them |
| **Regression on the new build** (fresh copy each) | Daily closing 45/45 · corrections 40/40 · cancellation 31/31, 106/106 figures (three Home counts updated to the sales-count rule, by the brief) |
| **Backend** | tsc clean · **156 suites / 2 806 tests** |
| **Mobile** | tsc clean · **71 pure suites** · i18n parity 3 180 · `expo lint` 0 errors (33 pre-existing warnings) |
| **Render / device** | **Not run** — no render check this phase; `docs/24` §41 |

## Data and process safety

- Live received **nothing**: no migration, no write, never signed into. No backup was needed (no schema change).
- Every write went to the copy `prisma_verify_home` (throwaway credentials on the copy only), rebuilt for each run and
  **dropped at close-out**. The isolated API on 3012 stopped; 3012 free.
- Scratch tooling lives in the OS temp directory only. The user's API, Metro and the MySQL service were left running.

## 🟡 Needs a product decision (`docs/53` §4)

1. Should a **return reduce units sold** and the units-sold goal? Today it does not; returned units are apart.
2. A **whole-sale discount** would split line-based readers (Results, goals, branches, products) from invoice-based ones
   (Daily closing, Home, Money, sellers) by the discount; live has none today.
3. The revenue goal's **"Money taken"** label now means net sales, not cash collected.
4. Analytics' **movement labels** ("sold in 30 days", "last sold", dead stock) still count a cancelled sale as movement.

## 🔴 Blockers and pending approvals

- **The user's API runs the previous build** (`68c21e9`). The new figures reach the phone only after the user rebuilds
  `backend/dist` from `5acab28` and restarts it — not done here, by instruction not to touch it.
- **Native build blocker (pre-existing):** `npm install`'s postinstall fails — `expo-camera` 57.0.5 is installed but the
  Android scan-region patch was cut against 57.0.4. Expo Go is unaffected.
- `GET /closings/overview` under MySQL's default `sql_mode` (`ONLY_FULL_GROUP_BY`): not re-checked; live runs with
  `sql_mode=""`.
- **WhatsApp:** no provider adapter exists and none is faked; the closing templates await approved copy.
- **Deferred by instruction:** the control website (`docs/38`) is unchanged.

## 📋 Known, not fixed

- The Analytics **snapshot** (`today`/`month`, API only, on no screen) reads "today" as the UTC date (its figures are
  now net). The exports carry the net figures but no returned-units or returns-count column and no rule statement.
- A count or a goal whose period holds only a cancellation reads below zero (intended); the goal's bar is empty.
- **Rollup recovery time:** a request whose recompute died mid-way waits for its lease (60 s) and the next sweep (30 s)
  — up to ~90 s after a restart. `done` requests are kept and not pruned; a request that keeps failing is visible only
  in `rollup_requests.last_error` and the log. One API process assumed (a second is safe by lease and retry).
- `scripts/rollup-audit.js` (revenue-only, `DATE(sold_at)`, existing rows only) is superseded by `rollup-drift.js`.
- **Corrections not available, by name:** reversing a purchase payment as "not paid" (cancel the purchase instead);
  editing a sale line or cancelling part of a sale (cancel and sell again); a sale with a return (correct it on the
  return); a purchase whose goods have moved (correct the later record first). Reassigning a stored business date is
  still an Owner correction that does not exist.
- The approval audit's `before` is the full preview (`$.payment.method`, `$.move`, …) since 0079.
- Loans, consignment and employee-debt cash are outside the report, as they are outside the closing.
- Expense and refund confirmations check the day's lock without taking the closing row's lock.
- Selling a phone outright to another store is still the documented contract gap in the partner ranking.
- The Stock tab's own list shows full identifiers (rule 19d); the list reached from Home masks.
- Filter chips are 36 pt tall by design-system decision, with hit slop restoring a 48 pt target.
- Two scripts logging in the same user concurrently deadlock on `users.last_login`; harmless for one phone.
- On web, a screen pushed from a tab announces its back button as "(tabs), back". Dynamic type is handset-only.
- Prisma drift report: `units.identifier` is a stored generated column from 0008 that Prisma cannot model.
- `npx eslint .` over the whole app reports one pre-existing error in `scripts/verify-native-patch.js` (`__dirname`),
  outside `expo lint`'s scope. The backend has a `lint` script but no ESLint configuration.

## The next exact action

1. **The user rebuilds and restarts their API** from backend `5acab28` (`npm run build`, then start it as before), so
   the phone reads the new figures.
2. **Handset:** `docs/24` §41 N1–N8, then §40 L1–L6, §39 K1–K14, §38 R1–R14, §37 H1–H10, C1–C16, §36, §35 and the older
   backlog — on the physical phone against the live API (Expo Go). No sample record on the live store unless the user
   asks.
3. The four product decisions above, when the user chooses.
4. Fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy.
