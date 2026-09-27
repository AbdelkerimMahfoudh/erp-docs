# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Owner: **CLAUDE-A**
- `started_at_utc: 2026-09-27T05:50Z` — takeover HEADs (all clean, level with their remotes): docs `fa1ef2d` · backend
  `b4e4342` · mobile `de1ae74`; `prisma migrate status` on live: 80 migrations, up to date. Set before any edit.
- **Active phase and scope (the user's brief of 2026-09-27):** Home, Money, the Daily closing and the sale flow reached
  from Home; the approved simple design; no scanner or refund work, no pictures, no change to live records.
  *Home:* Receive left, Sell right; no "Sell several items" on Home; when the current business day is closed, Sell and
  Receive locked with **Open store now** beneath them, through the existing opening flow (the before-06:00 choice
  included), permissions respected, the server's business-day state used, Sell and Receive guarded on direct
  navigation too. *Money:* the top card lists Cash, Bankily, Masrivi and every configured method with a total equal to
  the sum of the rows shown, on one audited server basis, labelled accurately; Today selected on every visit to the
  tab, a choice kept during the visit. *Daily closing:* Sales details amounts in one right-hand column, the chevron
  beside the title with the (?) on the same line, the Money owed card removed, Closing history as one purple header
  with the title and count centred and a larger chevron fixed at the right edge in LTR and RTL. *Sale flow:* "Why is
  this sale different?" removed with its validation and any server requirement; a split payment limited to four
  distinct methods (form and server), duplicates refused, parts summing to the amount due; Choose from stock given
  margins, spacing and touch targets without losing speed, search, filters, selection or Continue.
- Next intended action: read the Home, opening, Money, sale-payment and stock-picker code (mobile and backend), then
  implement area by area; verify on copies of live only.
- **Live moved by the user's hand since the last session** (read-only, 05:45Z): the 26th closed on the word at 05:05,
  auto-reopened by a sale at 05:08, reclosed at 05:11; the 27th started early at 05:11, closed at 05:20, reopened at
  05:21; a sale at 05:32. Live: 17 sales, 7 expenses, 11 closing events, 3 closing rows (15 Sep *counted*, 26 Sep
  *locked*, 27 Sep *reopened*). The machine rebooted at 04:44Z; MySQL (pid 18824), the API on 3010 (pid 24352, `dist`
  of `b4e4342`) and Metro on 8081 (pid 23768) were restarted at 04:45–04:52, not by this session.
- Last session: **CLAUDE-A**, `started_at_utc: 2026-09-26T08:15Z`, ended 2026-09-27T01:55Z — the Daily closing
  follow-up (`docs/58` D71–D74); the user's review on the phone and the decision on counting by a store employee were
  then pending.

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed by this phase beyond what the user asked for (the balance cards and the counting page); the
closing-time loan reminders the counting page carried were kept, on the Daily closing page.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`b4e4342`** | level | 0 |
| `erp-mobile` | `reports-export` | **`de1ae74`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

This pass: backend `b4e4342` (the attestation and the close's guards); mobile `50eec16` (the shared money field:
Arabic-Indic digits, signed amounts where allowed), `de1ae74` (the popup, the history rectangle, no balance cards, the
review fixes, 52 orphaned keys removed). Docs: `docs/58` §1.4 D71–D74, §3.5, §3.3, §4; `docs/21` D71–D74; `docs/24` §45
V1–V15 (and its title line restored — an earlier edit of this phase had written over it); `docs/04` rule 26; the session
log; this file.

## What changed

| Where | Now |
|---|---|
| **Close the business day** | a popup: the question as the step's own text; *Enter the amounts* (only when the live view has channels) — the drawer and each account, each saved through `POST /closings/count`, scrolling under the keyboard with nothing pinned; a typed amount saved or cleared before Continue; only a valid amount saves (Arabic-Indic digits, a minus on an account only, two decimals at most); *Change* / *Cancel* — or *I've checked*; the confirmation re-reads the day as it opens and **Close spins and waits while the figures are re-read** (after a count, after a 409); `clientUuid` replay and `report_changed` as before |
| **The contract** | `POST /closings` `attestChecked` → channels without an amount closed *attested* (`ATTESTED_AT_CLOSE`, the person and the time, no amount, no difference); `reserved_reason` for a count carrying a machine key; `conflicting_statements` for attest + acknowledge together; a person's skip and the stored close agree; the snapshot's warnings say what the close recorded; a skip's reason kept in the event and audit |
| **The page** | no Check balances section; *Unsettled differences* beside *Correct a transaction*; *Money owed* (loan reminders) on today's page when something waits; Closing history as one rectangle (count, chevron at the end edge, slide-out reveal following Reduce Motion as the phone has it now) |
| **Shared** | `MoneyField` turns Arabic-Indic digits into the amount in every money field; `allowNegative` (signed keyboard, left to right); `BottomSheet` `titleLines`; `lib/design/use-reduce-motion.ts` |
| **Unchanged** | the statement, Sales details and its (?), Money movements, the accounting, reopening and the before-06:00 choice |

## Verification

| Kind | Result |
|---|---|
| **The close contract** (copy of live, built API, fake clock) | **16 of 16** |
| **The review's findings** (reproduced on the unfixed build, then fixed) | **9 of 9** (the unfixed build failed 6) |
| **The page** (web export of `de1ae74`; the 06:06Z copy and a fresh read-only copy of live of 2026-09-27 00:42Z) | **31 of 31 views, 7 of 7 server facts** — EN/FR/AR 320 pt; 320 × 568 with text 1.3×; a keyboard-sized 320 × 262 sheet in EN and AR; Reduce Motion at start and switched on while open; unsaved, invalid, Arabic digits (1 234 saved), a −300 account movement saved, Change/Cancel; Close waiting after a count and after a 409; the popup without the live view; the real 26th closed on the word (Bankily 5 700 kept, the drawer attested) |
| **Gates** | backend `tsc` clean, **160 suites / 2 844 tests**, `nest build` clean; mobile `tsc` clean, **76 suites / 1 083 cases / 0 failed**, parity **3 192 / 3 192 / 3 192**, `expo lint` 0 errors (31 pre-existing warnings) |
| **Large text, correction** | react-native-web writes px: the earlier "130 %" web views (`docs/58` §3.2, §3.4, the first D71 run) changed the root font size and proved nothing; this pass multiplies each text element's size |
| **Phone** | **Not run** — the user's review first, then `docs/24` §45 V1–V15 |

## Data and process safety

- This session wrote nothing to live: read-only queries and one read-only dump
  (`~/erp-backups/phonestore-now-20260927-004240.sql`, outside every repository). Live holds **15 sales, 7 expenses,
  5 closing events, 2 closing rows** (15 Sep *counted*; 26 Sep *counting*, Bankily 5 700) — **no closed day**, no
  skipped or machine-marked channel row. The user's own activity of 06:57–07:12 on the 26th is unchanged.
- The copy `prisma_verify_home` was rebuilt per run and **dropped**; 3012, 19012 and 9334 are free. The API on 3010 and
  Metro were restarted on the final code for the phone. Scratch tooling in OS temp only; the three trees are clean.

## 🔴 Blockers and pending approvals

- **Awaiting the user's visual review** of the Daily closing and its popup on the phone.
- **Awaiting the user's decision:** counting by a store employee without the closing delegation (above).
- **Pending the user's decision:** the `spent_on` tidy-up of three expenses (`docs/57` §1.5, `docs/58` §2); the
  "Money in the shop — recorded movement" label and "Debt settled for this day".
- **Native build blocker (pre-existing):** `npm install`'s postinstall fails — `expo-camera` 57.0.5 is installed but the
  Android scan-region patch was cut against 57.0.4. Expo Go is unaffected.
- `GET /closings/overview` under MySQL's default `sql_mode` (`ONLY_FULL_GROUP_BY`): not re-checked; live runs with
  `sql_mode=""`.
- **WhatsApp:** no provider adapter exists and none is faked; the closing templates await approved copy.
- **Deferred by instruction:** the control website (`docs/38`) is unchanged.

## 📋 Known, not fixed

- **Older wording seen on the real data:** a sale paid through an account reads "+0 MRU cash" in the closing history;
  counts of one read "1 balances", "1 payments".
- **A snapshot stored before `b4e4342`** keeps what it stored (a person's acknowledged skip as *not verified*); live has
  no closed day, so nothing reads "changed since close" there.
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

1. **The user's visual review** on the phone (reload Expo Go, `exp://192.168.100.3:8081`, Home → the Daily closing
   entry): the page without balance cards, *Money owed* when loans wait, Closing history's rectangle (tap, tap again,
   then with Reduce Motion on), and *Close the business day* — the question, *Enter the amounts* with the keyboard up
   (every field reachable, Save, Change / Cancel, an account's "-300", Arabic digits), *I've checked* → the
   confirmation → close. The page is called complete only on the user's word.
2. **The user's decision** on counting by a store employee; build only what they choose.
3. Then `docs/24` §45 V1–V15, §44 U1–U13, §43 T1–T13 and the older backlog. No sample record on the live store unless
   the user asks — a close made on the phone during the review is the user's own act on live.
4. **If the user approves it:** the `spent_on` tidy-up of `docs/57` §1.5 (three rows, audited, after a backup per
   `docs/22`).
5. When the WAMP service is wanted back: stop the session MySQL (`mysqladmin -uroot --protocol=tcp -P3306 shutdown`),
   then start `wampmysqld64` from an elevated prompt or the WAMP tray.
6. Fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy.
