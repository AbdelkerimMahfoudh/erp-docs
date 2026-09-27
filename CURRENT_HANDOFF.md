# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Owner: **NONE**
- Last session: **CLAUDE-A**, `2026-09-27T21:20Z` → `23:50Z`, complete — the user's navigation and verification brief of
  2026-09-27 (21:1xZ), worked inline as the brief asked (no workflows or subagents). Takeover HEADs were docs `7b78caf`,
  backend `69346fc`, mobile `6b6b651`, all clean and level.
- **Scope done** (`docs/61`; `docs/21` D93–D94): (1) a back arrow on every authenticated child screen with a logical
  no-history fallback, the native swipe kept, structural tests; (2) a later payment on a debt refused with 409
  `store_closed` while the day is closed — no automatic reopen left; the phone keeps the form; (3) the 51/52 check of
  `docs/60` named (a harness defect) and green; (4) 0082 verified — read-only on live, the whole lifecycle through
  authenticated HTTP on a copy, append-only as the app's own database user; (5) the Owner's phone review of `docs/24`
  §47 recorded as **user-reported**.
- **The machine restarted at 22:30Z** during a matrix run: the run, the API on 3010 and Metro on 8081 stopped; the run
  was repeated from a fresh copy and both servers were restarted on the new build (below).

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed in this phase beyond what the user asked for; the equal-total split rule of `docs/59` D83 was
reversed at the user's request (D92).

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`eea15e3`** | level | 0 |
| `erp-mobile` | `reports-export` | **`6edad6b`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

This pass: backend `eea15e3` (a later payment refused with `store_closed`; `autoReopenTx` removed; `businessDate` in
the body); mobile `fd57d26` (back navigation: the map, the shared arrow, the root header, every way out through
`useLeave`, `lib/navigation/back.test.ts`), `6edad6b` (the refused payment keeps its form, *Open store now*, the
words). Docs: `docs/61` (new), `docs/21` (D93–D94), `docs/04` rule 25, `docs/24` §47 status and §48, `docs/60`
annotated where `docs/61` corrects it, the session log, this file. **No migration.**

## What changed

| Where | Now |
|---|---|
| **Back navigation** | `lib/navigation/back.ts` maps every authenticated child route to its logical parent (`BACK_PARENTS`) and names every route without an arrow (`NO_BACK`: the five tabs, `/platform`, `/select-branch`, `/subscription-blocked`, `/stores`). The root stack shows the header on every child in every state; with history the native arrow and swipe (same pop), without history `HeaderBack` replaces the screen with its parent. Left in EN/FR, right in AR, 48 pt, "Back". Quick sell, Quick receive, Receive and New expense's review keep their own arrow; Sell's title row carries the shared one. Every in-page Back, Cancel, Discard and after-save step goes through `useLeave`. 72 screens: 63 with an arrow, 9 without |
| **Closed store** | `POST /sales`, `POST /purchases` **and `POST /sales/{id}/payments`** answer 409 `store_closed` (with `businessDate`) while the current business day is closed; nothing is written and **nothing reopens a day by itself**. A refused key stores nothing |
| **Record payment** | a refusal keeps the form, says nothing was recorded, offers *Open store now* to the Owner or a delegate (who then sends it again) and says who can open to anyone else; the close popup names payments on debts |
| **The harness** (OS temp, not a repository) | split fields found by their row and typed with `Input.insertText`; a warned sale (201 `warnings_pending`) acknowledged and a sale counted only by its row; the page given the server's clock for date-defaulting forms; SQL through stdin as UTF-8 |

## Verification

| Kind | Result |
|---|---|
| **Gates** | backend `tsc`, **165 suites / 2 961 tests** (closed-day and permission specs 84/84), `prisma validate`, `nest build`; mobile `tsc`, **81 suites / 1 249 cases**, lint 0 errors (31 warnings), parity **3 222 × 3**, the web export (72 of 72 screens), the Android bundle through Metro; **Expo Doctor 20/21** (six Expo packages a patch behind SDK 57's latest — no dependency changed); every commit alone from a clean export (same as the pre-pass baseline) |
| **Web matrix** (fresh copy of live at 22:01Z, fixed clock, final build) | **88 of 90 — 40/42 page checks, 48/48 server facts.** The two misses: Results' and Expenses' large figures cut at 320 pt with text 1.3× (a pre-existing finding, `docs/61` §6); every header assertion there passed |
| **The 51/52 of `docs/60`** | harness defect (fields picked by position while the debtor's name and phone joined the page); fixed, `OVER:yes` green. Also: `docs/60`'s "the same sale goes through (201)" was a price warning, nothing sold — now proven recorded (invoice 00011) |
| **0082** | live read-only: up to date, both triggers, `money.anchor.record` on the two Owner roles only, the phone's two anchors (Bankily 2 000, Owner1 10 000) with audit rows and the API log's two 201s; copy: the 12-step lifecycle through authenticated HTTP (`docs/61` §4.2); as `phonestore_app`: UPDATE and DELETE refused (45000), INSERT accepted; the body equal to the phone's contract |
| **Phone** | §47 **user-reported complete, no new defect** (not automated); §48 **not run** |

## Data and process safety

- **Live unchanged by this pass**: 17 sales, 7 expenses, 13 closing events, 3 closing rows, 17 payments, 2 anchors, 910
  audit rows — read at 22:01Z and again at 23:3xZ. No authenticated request was made to live; no anchor written there.
- Dump used for every copy this pass: `~/erp-backups/phonestore-now-20260927-220111.sql` (read-only, 954 KB). The 0082
  backup stays `~/erp-backups/phonestore-before-0082-20260927-195629.sql`; its reverse SQL is in the migration.
- Temporary databases: `prisma_verify_home` (rebuilt per run) and `prisma_staging_cleaninstall_proof` (the app-user
  proof; a name the app user was already granted, no grant changed) — **both dropped**. 3012, 19012 and 9334 free.
- **The API on 3010 runs `eea15e3`** (pid 13032, `node dist/src/main.js`, logs `%TEMP%/claude/api-3010.out.log`; the log
  from before the restart kept as `api-3010.out-before-reboot-20260927.log`). **Metro on 8081** (pid 1684, launcher
  26164, `expo start --clear --port 8081`) serves `6edad6b` at `exp://192.168.100.3:8081`; the Android bundle builds.
- Scratch tooling in OS temp only; the three trees clean and pushed.

## 🔴 Blockers and pending approvals

- **Awaiting the phone** for this pass: `docs/24` §48 Y1–Y10 (the arrow and the swipe on the same screen, the
  no-history fallback through a deep link, the Arabic arrow, the largest text, the refused payment kept and sent).
- **The user's calls:** Results' and Expenses' large figures ending in "…" at 320 pt with large text (the shared
  `MoneyValue` never shrinks, by an earlier choice); the Arabic Home order (`docs/59`); counting by a store employee
  without the closing delegation.
- **Live has no complete tracked total** until every account has an amount and a close counts the drawer (the Test
  Store has Bankily and Owner1 set).
- **Pending the user's decision:** the `spent_on` tidy-up of three expenses (`docs/57` §1.5).
- **Native build blocker (pre-existing):** `npm install`'s postinstall fails — `expo-camera` 57.0.5 vs the Android
  scan-region patch cut against 57.0.4. Expo Go is unaffected. Expo Doctor also lists six packages a patch behind.
- `GET /closings/overview` under MySQL's default `sql_mode` (`ONLY_FULL_GROUP_BY`): the account query was proven under
  it on a copy; the older parts were not re-checked; live runs with `sql_mode=""`.
- **WhatsApp:** no provider adapter exists and none is faked.
- **Deferred by instruction:** the control website (`docs/38`), scanner and refund work.

## 📋 Known, not fixed

- **A later payment recorded in the same minute as its sale** is refused as "earlier than the sale" (the form's time
  is to the minute) until the next minute; nothing is written and the form stays (`docs/61` §6).
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
   `eea15e3`): `docs/24` §48 Y1–Y10 — the back arrow on each child screen and the swipe landing on the same screen;
   a deep link (`exp://192.168.100.3:8081/--/closing`) with no history, the arrow going to the parent; Arabic after a
   relaunch; the largest text; a closed day with a debt payment typed, refused, kept, *Open store now*, sent once; a
   manager seeing who can open. The pass is complete only on the user's word; anything closed, opened or paid during
   the review is the user's own act on live.
2. **The user's calls** listed above; build only what they choose.
3. Then `docs/24` §45–§46 as amended, §44, §43 and the older backlog.
4. **If the user approves it:** the `spent_on` tidy-up of `docs/57` §1.5 (three rows, audited, after a backup per `docs/22`).
5. Fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy; deploy the backend before the app.
