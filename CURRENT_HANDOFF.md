# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Owner: **CLAUDE-A**
- `started_at_utc: 2026-09-27T21:20Z` — takeover HEADs (all clean, level with their remotes): docs `7b78caf` · backend
  `69346fc` · mobile `6b6b651`; `prisma migrate status` on live: 81 migrations (0082 included), up to date; the
  `money_anchors` triggers present. Previous session: CLAUDE-A, handed off complete (`READY_FOR_HANDOFF`).
- **Active phase and scope (the user's brief of 2026-09-27, 21:1xZ), inline — no workflows or subagents:** (1) a visible
  back arrow on every authenticated child screen, with a logical no-history fallback and the native swipe kept, and a
  structural test; (2) a later debt payment refused with 409 `store_closed` while the day is closed — no automatic
  reopen left; the phone keeps the form; (3) name and resolve the one failed page check of the last matrix; (4)
  authenticated verification of 0082 — read-only on live, the full write lifecycle on a copy; (5) record the user-
  reported phone review. No redesign of Home, Money, the Daily closing, Sell, Receive, stock selection or the tab bar.
- **Live moved by the user's hand since the last handoff** (read-only, 21:18Z): the Test Store's 27th reclosed on the
  word at 21:10:37Z and reopened at 21:10:49Z (13 closing events); two anchors recorded by Test Owner — Bankily 2 000
  (21:11:12Z) and Owner1 (inactive) 10 000 (21:11:21Z), each with its audit row. Records otherwise as before: 17 sales,
  7 expenses, 3 closing rows, 17 payments.
- Next intended action: the route audit.

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed in this phase beyond what the user asked for; the equal-total split rule of `docs/59` D83 was
reversed at the user's request (D92).

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`69346fc`** | level | 0 |
| `erp-mobile` | `reports-export` | **`6b6b651`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

This pass: backend `7db4be1` (money held, 0082, `POST /money/anchors`), `ada05f9` (`store_closed` for sales and
receipts), `69346fc` (partial splits, `overpayment`); mobile `eaf1a6a` (no function-form Pressable style; both headers
on `Expandable`), `59f9746` (partial splits on the sheet), `1cdab39` (the refusal covers the screen; the words),
`6b6b651` (Today first; Money held; Set amount). Docs: `docs/60` (new), `docs/21`, `docs/04` rules 19, 25, 26a,
`docs/59` D76–D78/D81/D83 annotated, `docs/24` §47, the session log, this file.

## What changed

| Where | Now |
|---|---|
| **Home / Money periods** | Today at launch, on the first visit and after another tab; a choice kept through refreshes and screens opened from the tab (one hook, `lib/use-tab-arrival.ts`); the store starts on Today; Expenses' *Back to Money* uses `dismissTo` |
| **Daily closing headers** | one `Expandable`: Sales details underlined on a violet wash, chevron after the words, (?) at the end; Closing history purple, "Closing history" / "N events", chevron at the right; turn and slide from beneath, none under Reduce Motion |
| **Native styles** | no Pressable styled by a function (13 converted; `lib/design/pressable-style.test.ts` refuses new ones) |
| **Money held** | `overview.trackedMoney`: each method's anchor + movements after it; drawer anchored by a counted locked close, accounts by `money_anchors` (0082); unknown → no total; accounts for the Owner only (`accountsVisible`); Set amount → `POST /money/anchors` (`money.anchor.record`) |
| **Closed store** | `POST /sales` and `POST /purchases` → 409 `store_closed` while the day is locked; replays answered; the phone covers the screen and keeps the work; a later payment still reopens today's closed day ("Reopened by a payment") |
| **Splits** | up to four places, each once, all or part of the sale, the rest owed by the named debtor; `overpayment` coded |

## Verification

| Kind | Result |
|---|---|
| **Gates** | backend `tsc`, **164 suites / 2 957 tests**, `nest build`; mobile `tsc`, **80 suites / 1 123 cases**, lint 0 errors (31 warnings), parity **3 220 × 3**; every commit alone from a clean export |
| **Review** | six reviewers + sceptic verification: 16 confirmed, 2 refuted, all 16 fixed before commit |
| **DB proof** (rolled back, copy) | account windows 15 of 15 |
| **Web harness** (fresh copy of the 08:28Z dump, fixed clock) | **51 of 52 page checks, 33 of 33 server facts** — the numbers in `docs/60` §3: **7 000 at 23:00 and still 7 000 at 07:00**; `store_closed` for an older client; 1 200 paid + 300 owed = 1 500 on four places; the headers in EN/AR |
| **Live** | 0082 applied after a verified backup; records unchanged; the API and Metro run the new code |
| **Phone** | **Not run** — `docs/24` §47 X1–X15 |

## Data and process safety

- Backups: `~/erp-backups/phonestore-now-20260927-082820.sql` (the base of every copy) and
  **`~/erp-backups/phonestore-before-0082-20260927-195629.sql`** (verified, before 0082). **To roll 0082 back**: its
  reverse SQL is in the migration's comments; a Git rollback alone does not roll back the database.
- `prisma_verify_home` rebuilt per run and **dropped**; 3012, 19012 and 9334 are free.
- **The API on 3010 runs `69346fc`** (pid 23240); **Metro on 8081** (pid 21232, launcher 2640) serves `6b6b651` at
  `exp://192.168.100.3:8081`; the Android bundle builds. MySQL runs as the WAMP service (the machine rebooted at 18:23Z).
- Scratch tooling in OS temp only; the three trees are clean.

## 🔴 Blockers and pending approvals

- **Awaiting the user's phone review** of this phase (`docs/24` §47) and of §45–§46 as amended.
- **The user's calls:** whether a later payment on a sale should also be refused on a closed day (today it reopens it);
  the Arabic Home order (`docs/59`); counting by a store employee without the closing delegation.
- **Live has no tracked position** until the Owner sets each account (Money → Set amount) and a close counts the drawer.
- **Pending the user's decision:** the `spent_on` tidy-up of three expenses (`docs/57` §1.5).
- **Native build blocker (pre-existing):** `npm install`'s postinstall fails — `expo-camera` 57.0.5 vs the Android
  scan-region patch cut against 57.0.4. Expo Go is unaffected.
- `GET /closings/overview` under MySQL's default `sql_mode` (`ONLY_FULL_GROUP_BY`): the new account query was proven under
  it on a copy; the older parts were not re-checked; live runs with `sql_mode=""`.
- **WhatsApp:** no provider adapter exists and none is faked.
- **Deferred by instruction:** the control website (`docs/38`), scanner and refund work.

## 📋 Known, not fixed

- **A later payment on an existing sale still reopens today's closed day** (rule 25, 0076) — the one automatic reopen
  left; sales and receipts are refused with `store_closed`.
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
- On web, a screen pushed from a tab announces its back button as "(tabs), back"; the tab navigator keeps inactive
  tabs mounted.
- Prisma drift report: `units.identifier` is a stored generated column from 0008 that Prisma cannot model.
- `npx eslint .` reports one pre-existing error in `scripts/verify-native-patch.js`; the backend has no ESLint
  configuration.

## The next exact action

1. **The user's review on the phone** (reload Expo Go, `exp://192.168.100.3:8081`; the API on 3010 already runs the
   new backend with 0082): `docs/24` §47 X1–X15 — Today at a cold start and after another tab; Sales details and
   Closing history (purple, "Closing history" / "N events", chevron right, Arabic after a relaunch, Reduce Motion);
   the converted rows; Money held (Unknown until set; Set amount per account as the Owner; the drawer counted at a
   close); a sale on a closed day from a second phone; a split of part of a sale with a named debtor. The phase is
   complete only on the user's word; anything set or closed during the review is the user's own act on live.
2. **The user's calls** listed above; build only what they choose.
3. Then `docs/24` §45–§46 as amended, §44, §43 and the older backlog.
4. **If the user approves it:** the `spent_on` tidy-up of `docs/57` §1.5 (three rows, audited, after a backup per `docs/22`).
5. Fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy; deploy the backend before the app.
