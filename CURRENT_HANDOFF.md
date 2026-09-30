# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Owner: **CLAUDE-B** (a claude.ai cloud session; the previous owner CLAUDE-A works on the user's PC)
- `started_at_utc: 2026-09-30T13:44Z` — **explicit takeover, authorised by the user's brief of 2026-09-30** ("continue as
  the next authorized Claude session"). The previous session (CLAUDE-A, started 2026-09-28T03:51Z) was left
  `IN_PROGRESS`: its scope (1) — the scroll investigation — is **open, waiting on the phone**, and its dev-only touch
  trace is uncommitted **on the user's PC only** (nothing dirty on any remote; the cloud checkouts are clean). Nothing of
  it is touched here: its scanner, returns, navigation and closing work on `reports-export` is preserved as pushed.
  Takeover HEADs (all clean, level with their remotes): docs `850dc52` · backend `1d6caa0` (`reports-export`) · mobile
  `3d24222` (`reports-export`); 83 migrations, up to date. Two unmerged draft PRs from this account's own earlier
  audit (backend #2 `claude/audit-fixes`, mobile #2 `claude/audit-fixes`, mobile #1 `claude/stock-finds-products`)
  stay as they are.
- **Active phase and scope (the user's brief of 2026-09-30): pre-production security and App Store readiness.**
  (A) account deletion with a WhatsApp-delivered single-use code, server-enforced, EN/FR/AR; (B) Super Admin approval
  and the subscription timeline, verified over real HTTP; (C) the 20 pre-release security controls of `docs/48` with
  evidence, plus the gate's additional blockers. Disposable databases only; nothing published; the live database, the
  user's PC and the iPhone are out of reach of this session.
- **Next intended action:** WhatsApp Cloud API channel → account deletion (schema 0084, routes, mobile) → approval
  journey → the 20 controls → gates → docs → `READY_FOR_HANDOFF`, owner NONE.

### Inherited from the CLAUDE-A session (unchanged, for the record)

- **Scope (the user's briefs of 2026-09-28), inline — no workflows or subagents:**
  - **(0) Names never cut — DONE** (mobile `8d101f6`, `docs/61` §13).
  - **(1) The scroll / touch investigation — OPEN, waiting on the phone.** A dev-only touch trace is **uncommitted in the
    mobile tree** (`lib/dev/touch-trace.ts`; hooks in `app/_layout.tsx`, `components/ui/Screen.tsx`,
    `app/sales/index.tsx`, `app/receive/file.tsx`, all behind `__DEV__`) — to be removed (or kept behind the dev guard)
    before the phase's final commit. The user reports failed swipes on **Vérifier la livraison** (`/receive/file`: the
    blank area around the chips and above *Modification groupée*; the expanded item rows) and across **More → Sales**
    (`/sales`, rows included). **Traces received 29 Sep for the sale detail (`/sales/{id}`, #32–#36):** every lost
    swipe started on content inside the page's `ScrollView` (a `MoneyValue`, a `Fact`, in a `Card`), the ScrollView
    never scrolled (`scroll=[]`, `content=0`), the blank-space `Pressable` of `Screen scroll={false}` — an **ancestor** of
    that ScrollView — took the touch (`screen-blank(ABOVE-list)`) and ran its press on release (`Keyboard.dismiss@779`).
    The layer is named for that screen; `/receive/file` has no trace yet (same structure: its whole page is a
    `FlatList` inside `Screen scroll={false}`, the chips in the list's header). **Fix pushed — mobile `3d24222`:**
    outside the scroll view, `Screen`'s body, header and footer are plain Views with the dismissal `Pressable` as a layer
    BEHIND the content (34 screens render that branch; Stock's chip rows sit in a header). **The phone must prove it;**
    the dev trace stays (uncommitted) with the sale detail's ScrollView now hooked (`listTrace('sale')`), the
    blank-space layer labelled `screen-blank(behind)`.
  - **(2) Money and the opening — DONE** (`docs/63`, D98–D102; backend `b0f9bd0`, `90ef14a`, `55c1a3b`; mobile `c3eb47e`,
    `9d54803`, `812ba09`). **Migration 0083 applied to live at 21:50Z** (backup `~/erp-backups/phonestore-before-0083-20260928-215031.sql`).
  - **(3) The iPhone opening failure (the user's brief of 29 Sep, prioritized over (1)) — FIXED, the iPhone owed**
    (`docs/63` §10, D103; backend `285ba78`, mobile `3bd2937`): the amounts only after the day sheet's native modal is
    gone; the early start inside the opening's transaction; a failure keeps the chosen day, the amounts and the key.
    HTTP 10/10, web 14/14. **Live read only:** the 28th was never closed — started early at 05:25:40Z on the 28th under
    the old build, never opened, nothing recorded since.
  - **(4) QA data setup (the user's brief of 29 Sep) — DONE** (backend `1d6caa0`, `scripts/qa-boutiques.ts`). Opening
    blocker resolved on the phone first (live, 02:12:21Z: the Owner started the 29th early and opened it, keep, once).
    **The QA environment** (all outside the repositories, `~/erp-qa/` with a README; nothing on live):
    - database **`prisma_qa`** (82 migrations through 0083) — retained on purpose, not a verification copy;
    - **QA API `http://192.168.100.3:3020/api/v1`** — `node C:UsersHPerp-qaqa-api.cjs` (start; running now, pid
      7476) / `… qa-api.cjs stop`; built from backend `285ba78` into `~/erp-qa/dist`; its own token secret; messaging
      disabled; connects as the migrator (the app user has no rights on `prisma_qa`, so the append-only triggers do not
      restrain QA data);
    - **Expo Go:** `~/erp-qa/qa-metro.ps1` — a second Metro on 8082 with `EXPO_PUBLIC_API_ORIGIN=…:3020` and its own
      cache folder (proven: its bundle holds only `:3020`; the live Metro's still only `:3010`), then
      `exp://192.168.100.3:8082`.
    **The data:** ten boutiques (`boutique1…10@test.com`, one company, one branch, one Owner each; registered,
    verified and activated through the platform's routes) and `admin@test.com` (platform administrator; the QA password
    is below `create-platform-admin.ts`'s 12-character rule — QA only). Each boutique: 2 categories, 32 products, **80
    phones** (26 variants of 12 brands; 800 distinct synthetic Luhn-valid IMEIs overall, 350 with a distinct second IMEI)
    and **20 accessories** (6 quantity products, 60 distinct EAN-13 barcodes, none an IMEI); the 29th opened (started
    early, keep) and one cash receipt each. **`--verify`: 64 of 64** (eleven sign-ins; 100 available per Owner; own
    product and phone readable, the next boutique's refused 404/404/403; no platform access for Owners; the
    administrator on the platform, 401 on any shop route and at the shop sign-in). A second `--apply` changed nothing.
    Passwords only from `QA_PASSWORD`, hashed by the app (argon2id), never printed or committed. **Not modelled:**
    a phone's condition (the schema keeps it out of the variant by design) — the user's call.
- **Next intended action:** scope (1) on the phone — swipes on the sale detail, More → Sales and *Vérifier la livraison*
  (the `LOG  [touch]` lines should read `SCROLLED`; the live Metro serves the fix and the trace); then the scroll doc,
  `docs/24` checks, the trace removed, `READY_FOR_HANDOFF`. QA testing (scope 4) can run meanwhile on
  `exp://192.168.100.3:8082` (`~/erp-qa/qa-metro.ps1`); after a reboot, start the QA API again (`~/erp-qa/qa-api.cjs`).
  Opening (scope 3): proven on the iPhone at 02:12Z (start early, keep); `docs/24` §50 AA12a–c remain for the other choice
  and the failure path; the user's API should run `285ba78` (the atomic early start).

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed in this session beyond what the user asked for (the Daily closing's row on Money, moved to Home).

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`1d6caa0`** | level | 0 |
| `erp-mobile` | `reports-export` | **`3d24222`** | level | **6 — the dev touch trace (scope 1), uncommitted on purpose** |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

This session: mobile `8d101f6` (names never cut); backend `b0f9bd0` (0083), `90ef14a` (`closedReason` through the
filter), `55c1a3b` (the opening and its money); mobile `c3eb47e` (the Daily closing off Money), `9d54803` (the opening
step, Money's card, the review, the company action), `812ba09` (a sheet's late close; names that wrap whole). Docs:
`docs/63` (new), `docs/21` (D98–D102), `docs/04` rules 25/25a/26a, `docs/24` §50, `docs/61` §12–§13, the session log,
this file.

## What changed (`docs/63`)

| Where | Now |
|---|---|
| **The counter** | A sale, a receipt or a later payment on a current day **nobody opened** is refused (409 `store_closed`, `closedReason: 'not_opened'`) — every client; the phone's gates cover Sell and Receive and offer the opening to whoever counts |
| **Opening** | `POST /closings/open` and `/reopen` carry `openingMoney`: the Owner **keeps** (unknown stays unknown) or **sets** the cash; anybody else opens **carried**, *awaiting the Owner's review*; the opening event and the decision are one transaction; keyed retries |
| **Review** | `POST /closings/opening/review` (Owner): keep or set, a new row, true from its own instant |
| **The drawer** | anchored at the confirmation instant (the day's net at that instant stored): only later movement counts; later days carry from it; the close's cross-check carries the same adjustment |
| **Company accounts** | never set by a shop's opening; the Owner's **Company account amounts** row on Money (the existing `money/anchors`) |
| **Money** | one card, *Expected money in store today*: the server's total, Cash and each method on short lines, *Unknown* never 0, no total while anything is unknown; the old explanations, *Set amount* buttons and *Money recorded today* gone from the top |
| **The Daily closing** | off the Money list; Home's card has **Review closing**; `/closing` unchanged |
| **Before 06:00** | the day choice first (its button now **Next**), then the amounts |
| **Data** | 0083 `opening_decisions` (additive, append-only), **on live since 21:50Z on the 28th** |

## Verification

| Kind | Result |
|---|---|
| **HTTP proof** (copy of live, dump 19:19Z; built API, fake clock) | **58 of 58**: 3 400 + 3 600 = 7 000; carry with no movement; all zero; partial; movement after the opening; retries; the 06:00 choice; Owner, Employee, Store Manager, closing delegate; older phones; the rollout day. Live compared before and after |
| **Web renders** | **55 of 56 — 48 of 48 page checks, 7 of 8 facts** (the eighth expected a total of 250 where the app rightly recorded 3 850: 250 in cash plus the accounts’ 2 600 and 1 000): the opening step (Owner EN/FR/AR × 320/393 × 1×/1.3×, staff), Money’s card (known, unknown, awaiting review, a manager, dark), the company sheet and setting an account from it, the review, Home’s *Review closing*, the before-06:00 choice then the amounts; 284 money figures scanned, none cut; no label cut |
| **Gates** | backend `tsc`, **168 suites / 3 049 tests**; mobile `tsc`, **83 suites**, lint 0 errors (31 warnings: the 30 known + one in the uncommitted trace), parity **3 250 × 3**; each mobile commit alone = the clean-export baseline (`global.css` and three suites need untracked files, as on `8d101f6`) |
| **Phone** | `docs/24` §50 AA1–AA13 **not run**; §49, §48 still open |

## Data and process safety

- **Migration 0083 applied to live at 21:50Z (28 Sep)**, after a verified backup
  `~/erp-backups/phonestore-before-0083-20260928-215031.sql` (953 KB, `-- Dump completed`). Table empty, both triggers
  present; business rows unchanged: 18 sales, 19 payments, 7 expenses, 17 closing events, 3 closings, 3 anchors, 926
  audit rows. **Nothing else was written to live.**
- **The API rules change on the next API start**: the user's `nest start` builds the committed code; from then a day
  must be opened before it takes money (today's live day was started early at 05:25Z on the 28th with no opening).
- **The machine rebooted at 23:49Z (28 Sep).** The WAMP MySQL service was found **STOPPED** and is left so; this session
  ran MySQL as a **session process** from the service's own settings (`sql_mode` empty, `utf8mb4_unicode_ci`, no
  binary log) from 00:1xZ on the 29th, and shut it down cleanly at 00:25Z — **the service is left STOPPED, as found**; the user starts WAMP as usual. The user's API (3010) and Metro (8081) were already stopped.
- The backend's generated Prisma client carries the new model (the proof ran on it); its copied `schema.prisma` file
  is stale from an EPERM while the API held the engine — `npx prisma generate` with the API stopped refreshes it.
- Copies: `prisma_verify_home`, restored per run from `~/erp-backups/phonestore-now-20260928-191949.sql`,
  **dropped** (no `prisma_verify_*` schema left). 3012, 19012, 9334 free. Scratch tooling in OS temp only.

## 🔴 Blockers and pending approvals

- **Scope (1) waits on the phone:** Metro running, the phone attached, the user's swipes on **Vérifier la livraison**
  and **More → Sales**; the `LOG  [touch]` lines in the user's VS Code terminal (or the read-only tap) name the layer.
  No fix before that. The trace is `__DEV__`-only and must not be committed as is.
- **Awaiting the phone:** `docs/24` §50 AA1–AA13 (after the API restart on the new build), then §49 Z1–Z8 and §48.
- **The rollout's first morning:** with the new build, Sell and Receive wait until somebody opens the boutique; an
  Owner phone on an older build cannot open (it sends no decision) — the phone must reload the new bundle.
- **The user's calls:** the Arabic Home order (`docs/59`); counting by a store employee without the closing delegation.
- **Live has no complete tracked total** until every account has an amount and the drawer is counted or set.
- **Pending the user's decision:** the `spent_on` tidy-up of three expenses (`docs/57` §1.5).
- **Native build blocker (pre-existing):** `npm install`'s postinstall fails — `expo-camera` 57.0.5 vs the Android
  scan-region patch cut against 57.0.4. Expo Go is unaffected.
- `GET /closings/overview` under MySQL's default `sql_mode` (`ONLY_FULL_GROUP_BY`) is not proven; live runs with
  `sql_mode=""`.
- **WhatsApp:** no provider adapter exists and none is faked. **Deferred by instruction:** the control website
  (`docs/38`), scanner and refund work.

## 📋 Known, not fixed

- **The access refusal's *Check again*** opens the app only when writing is allowed too (`canRead` and `canWrite`),
  while the guard needs only `canRead`: a shop allowed to read but not write stays on the refusal until it signs out
  and in (seen in the route review, not changed).
- **An Owner phone on an older build cannot open the boutique** (it sends no decision; 400 `opening_amounts_required`) — the phone must run the new bundle. A staff member's older phone opens as carried.
- **Money's figures count only what the app records** — not loans, consignment, owner drawings, transfers or provider fees;
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

1. **The user starts WAMP's MySQL, then the API** (its `nest start` builds backend `55c1a3b`; 0083 is already on live).
   From then on a day is opened before it takes money: the first *Open the boutique* asks the Owner to keep or set the
   cash. (If the API complains about the Prisma client, stop it, run `npx prisma generate` in `backend/`, start again.)
2. **Scope (1), the scroll investigation:** Metro running, the phone reloaded; the user swipes on **Vérifier la
   livraison** (the blank area around the chips and above *Modification groupée*; the expanded rows) and on **More →
   Sales**, and copies the `LOG  [touch]` lines containing `/receive/file` or `/sales` from the VS Code terminal (or the
   read-only tap, scratch `rn-console-tap.mjs`, attaches while Metro runs). Name the layer that received each failed
   swipe, then fix both screens without disabling the native swipe-back, verify on the iPhone, remove the trace (or keep
   it behind the explicit dev guard with no production output), write the scroll doc and the `docs/24` checks, commit,
   and only then `READY_FOR_HANDOFF` with owner NONE.
3. **The phone:** `docs/24` §50 AA1–AA13 (the opening, Money's card, the review, the company action, Home's *Review
   closing*, before 06:00, Arabic), then §49 Z1–Z8 and §48.
4. The user's calls listed above; the older backlog.
5. Fix `ONLY_FULL_GROUP_BY` in `closing.service.ts` before any staging deploy; deploy the backend before the app.
