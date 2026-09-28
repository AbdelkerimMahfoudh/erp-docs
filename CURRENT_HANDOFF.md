# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Owner: **NONE**
- Last session: **CLAUDE-A**, `2026-09-28T00:07Z` → `03:50Z`, complete — the user's correction brief of 2026-09-28
  (00:0xZ), worked inline (no workflows or subagents). Takeover HEADs were docs `be2038f`, backend `eea15e3`, mobile
  `6edad6b`, all clean and level; no discrepancy.
- **Scope done** (`docs/61` §8–§11; `docs/21` D95–D97): (1) no monetary amount is ever cut — fitted, moved below
  its label, or `MRU` on the next line, never "…"; (2) a debt payment in the same displayed minute as its sale is
  accepted server-side, stored at the sale's instant, earlier minutes still refused; (3) the four routes without an
  arrow named and resolved — `/platform` given the arrow, `/stores` an invisible redirect, `/select-branch` and
  `/subscription-blocked` authentication roots — and every route in exactly one class; (4) the matrix **192 of 192**.

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed in this phase beyond what the user asked for; the equal-total split rule of `docs/59` D83 was
reversed at the user's request (D92).

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`f66c1ff`** | level | 0 |
| `erp-mobile` | `reports-export` | **`2476430`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

This pass: backend `f66c1ff` (a payment in its sale's minute); mobile `61f0f56` (money never cut: `MoneyValue`'s fit,
the half-row rule, wrapping buttons, seventeen plain-text amounts to `MoneyValue`), `2476430` (every route one class;
`/platform`'s arrow; the guard's decision pure and tested). Docs: `docs/61` §6 annotated and §8–§12, `docs/21`
(D95–D97), `docs/04` rule 19a, `docs/24` §48 Y4 and §49, the session log, this file. **No migration.**

## What changed

| Where | Now |
|---|---|
| **Money figures** | `MoneyValue` never limits its lines: one line full size → a little smaller (floor 0.7, never below body size) → `MRU` on the next line → the number broken between digit groups (`lib/money-fit.ts`), measured on the device by an invisible full-size copy. Every standalone amount goes through it (17 plain-text ones converted). A `Button` may wrap (Sell's charge button does); a picker's value may be a `MoneyValue` |
| **Label and amount rows** | `lib/design/amount-row.ts`: side by side while the amount needs at most half the row, below the label with the full width after that — `ListRow`, the statement lines of Results, the Daily closing, its popup, a sale, the returns breakdown |
| **Later payments** | a payment in the sale's own displayed minute is valid: stored at the sale's instant, same minute and business day, the chosen minute audited (`paidAtRequested`); an earlier minute refused as before; the closed store still decided first |
| **Routes** | 76 route files: 5 parent tabs, 64 children with the shared back arrow (`/platform` → `/login` now among them), 1 invisible redirect (`/stores`), 1 splash, 5 authentication roots (sign-in, register, verify, `/select-branch`, `/subscription-blocked`); no modal routes. The sign-in guard's decision is `lib/navigation/entry.ts` |
| **Earlier (27 Sep, still true)** | the back arrow on every child screen with its no-history fallback; `store_closed` for sales, receipts and later payments; Money held and `money_anchors` (0082); Today first; partial splits |

## Verification

| Kind | Result |
|---|---|
| **Gates** | backend `tsc`, **166 suites / 2 975 tests** (focused 140/140), `prisma validate`, `nest build`; mobile `tsc`, **83 suites / 1 270 cases**, lint 0 errors (31 warnings), parity **3 222 × 3**, the web export (76/76 route files), the Android bundle through Metro; **Expo Doctor 20/21** (six SDK patch versions, documented, no dependency changed); every commit alone from a clean export (same as the pre-pass baseline plus its new suite) |
| **Web matrix** (fresh copy of live at 22:01Z, fixed clock, final build) | **192 of 192 — 53/53 facts, 139/139 page checks**: the existing 90 all green with a money scan on every page; 91 boundary checks (0, −9 500, 27 648, 999 999, 12 345 678 on Home, Money, Results, Expenses, the Daily closing, a sale, Record payment; EN/FR/AR; 320/393 pt; 1×/1.3×; light/dark; scrolled through); 5 same-minute facts; 6 route checks. **699 money figures scanned, none cut** |
| **Same minute (real HTTP)** | sale 12:07:22.035, payment for 12:07 → stored 12:07:22.035 (= the sale), same business day, minute audited, cash +1 500 once; the minute before refused; the closed store first, nothing written; replay same, changed payload 409 |
| **Found, not money** | at 320 pt with 1.3× text the French tab label "Partenaires" and the Arabic Home header's branch name end in "…" — reported in the matrix, not failed; outside this pass |
| **Phone** | §49 Z1–Z8 and §48 **not run**; §47 user-reported complete |

## Data and process safety

- **This pass wrote nothing to live.** **Live moved by the user's hand** during it (the API's log): between 00:53Z and
  01:05Z two iPhones on Expo Go (…100.251, …100.246) scanned, created two products, a receipt, sale 00011 (3 500: 2 500
  cash + 1 000 mobile) and a loan, created and decided. Live now: 18 sales, 7 expenses, 13 closing events, 3 closing
  rows, 19 payments, 2 anchors, 919 audit rows.
- Every copy was restored from `~/erp-backups/phonestore-now-20260927-220111.sql` (read-only, before the user's new
  records) as `prisma_verify_home`, rebuilt per run and **dropped**; a throwaway platform administrator existed on a
  copy only. 3012, 19012 and 9334 free.
- **The API on 3010 runs `f66c1ff`** (pid 6596, `node dist/src/main.js`, log `%TEMP%/claude/api-3010.out.log`; the
  previous log kept as `api-3010.out-20260928-eea15e3.log`). **Metro on 8081** (pid 1684, launcher 26164,
  `expo start --clear --port 8081`) serves `2476430` at `exp://192.168.100.3:8081`; the Android bundle builds.
- Scratch tooling in OS temp only; the three trees clean and pushed.

## 🔴 Blockers and pending approvals

- **Awaiting the phone:** `docs/24` §49 Z1–Z8 (money at the phone's own largest text in EN/FR/AR, a list row stacking,
  the charge button, a payment in its sale's minute, the minute before refused, the closed store first, the platform
  overview's arrow) and §48 Y1–Y10.
- **The user's calls:** the French tab label "Partenaires" and the Arabic Home header's branch name cut at 320 pt with
  1.3× text (not money; tab bar and header outside this pass); the Arabic Home order (`docs/59`); counting by a store
  employee without the closing delegation.
- **Live has no complete tracked total** until every account has an amount and a close counts the drawer.
- **Pending the user's decision:** the `spent_on` tidy-up of three expenses (`docs/57` §1.5).
- **Native build blocker (pre-existing):** `npm install`'s postinstall fails — `expo-camera` 57.0.5 vs the Android
  scan-region patch cut against 57.0.4. Expo Go is unaffected. Expo Doctor lists six packages a patch behind.
- `GET /closings/overview` under MySQL's default `sql_mode` (`ONLY_FULL_GROUP_BY`): the account query was proven under
  it on a copy; the older parts were not re-checked; live runs with `sql_mode=""`.
- **WhatsApp:** no provider adapter exists and none is faked.
- **Deferred by instruction:** the control website (`docs/38`), scanner and refund work.

## 📋 Known, not fixed

- **The access refusal's *Check again*** opens the app only when writing is allowed too (`canRead` and `canWrite`),
  while the guard needs only `canRead`: a shop allowed to read but not write stays on the refusal until it signs out
  and in (seen in the route review, not changed).
- **Money held counts only what the app records** — not loans, consignment, owner drawings, transfers or provider fees;
  re-anchoring absorbs the drift and keeps the difference. The account query scans company-wide from each anchor.
- **A count saved and then a sale before the close** still leaves that sale out of the next opening (the closing's
  existing carry, unchanged).
- **`/loans/closing-reminders`** is served and no longer read by the app.
- **Older wording seen on the real data:** a sale paid through an account reads "+0 MRU cash" in the closing history;
  counts of one read "1 balances", "1 payments".
- **A snapshot stored before `b4e4342`** keeps what it stored (a person's acknowledged skip as *not verified*); live's
  closes (the 26th and 27th, from 05:05Z on the 27th) were all made on `b4e4342`, so none is affected.
- **Skipping a channel with a reason** no longer has a screen (the counting page is gone); the popup's two ways are the
  amount or the attestation (D71). The server still accepts a skip.
- **The keyboard and the system's own large text** are the handset's to prove; the web checks emulate both.
- On the iPhone's **web** browser the signed amount field offers a digits-only pad (the native app uses the signed pads).
- Reanimated's own Reduce Motion (the sheets, the buttons) is read at launch; only the history's reveal follows a change
  made while the app is open.
- **The day's expenses by category no longer appear on the Daily closing** (removed from Money movements at the
  user's request); the Expenses figure stays on the statement and in Sales details; the list itself is on Money →
  Expenses.
- **"Debt settled for this day" is `totals.olderDebts`** — older debts collected on the day; if the user meant this
  day's sales paid later the same day, the line should read `sales.collected.laterSameDay` instead.
- **A stored business date cannot be corrected from any screen** (`docs/56` §1.3 would be a scripted, approved change).
- **Only D−1 is checked for *Needs review*** (docs/51 limit): the 22nd's unclosed day is not announced.
- **A past *Needs review* day cannot be closed from the phone** (docs/51 limit, unchanged).
- `GET /expenses?date=` filters on `spent_on`, the memo date — no screen calls it.
- **Resuming a half-checked delivery** after the app was killed means picking the same file again on Receive.
- The review's **draft** is still the whole batch (43 KB) on every change — measured negligible in JavaScript.
- Home's failed-server body still reads "Everything else on this screen still works" although the cards that need the
  same reply are absent.
- **`product_velocity`** is no longer read or written — drop it in a later migration.
- **The Catalogue's "Last sold"** finds quantity lines only, so a phone never shows one.
- `closingHistory.title` is unused; the exports keep their movement headers.
- The Analytics **snapshot** (`today`/`month`, API only, on no screen) reads "today" as the UTC date.
- A count or a goal whose period holds only a cancellation or return reads below zero (intended); the goal's bar is empty.
- **Rollup recovery time:** up to ~90 s after a restart; `done` requests kept; a failing request visible only in
  `rollup_requests.last_error` and the log.
- `scripts/rollup-audit.js` is superseded by `rollup-drift.js`.
- **Corrections not available, by name:** reversing a purchase payment as "not paid"; editing a sale line or cancelling
  part of a sale; a sale with a return; a purchase whose goods have moved.
- The approval audit's `before` is the full preview since 0079.
- Loans, consignment and employee-debt cash are outside the report, as they are outside the closing.
- Expense and refund confirmations check the day's lock without taking the closing row's lock.
- Selling a phone outright to another store is still the documented contract gap in the partner ranking.
- The Stock tab's own list shows full identifiers (rule 19d); the list reached from Home masks.
- Filter chips are 36 pt tall by design-system decision (hit slop to 48) — except the review's, which are 48 pt (D45).
- Two scripts logging in the same user concurrently deadlock on `users.last_login`; harmless for one phone.
- On web the tab navigator keeps inactive tabs mounted.
- Prisma drift report: `units.identifier` is a stored generated column from 0008 that Prisma cannot model.
- `npx eslint .` reports one pre-existing error in `scripts/verify-native-patch.js`; the backend has no ESLint
  configuration.

## The next exact action

1. **The user's review on the phone** (reload Expo Go, `exp://192.168.100.3:8081`; the API on 3010 already runs
   `f66c1ff`): `docs/24` §49 Z1–Z8 — the phone's largest text on Results, Expenses, Home, Money, the Daily closing, a
   sale and Record payment (every amount whole, a long one smaller or with `MRU` below); Arabic; a list row with its
   amount below the description; Sell's charge button; a debt paid in the sale's own minute; the minute before
   refused; the platform overview's arrow to sign-in. Then §48 Y1–Y10. The pass is complete only on the user's word.
2. **The user's calls** listed above; build only what they choose.
3. Then `docs/24` §45–§47 as amended and the older backlog.
4. **If the user approves it:** the `spent_on` tidy-up of `docs/57` §1.5 (three rows, audited, after a backup per `docs/22`).
5. Fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy; deploy the backend before the app.
