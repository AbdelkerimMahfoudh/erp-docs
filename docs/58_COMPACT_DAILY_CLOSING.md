# 58 — The compact Daily closing

> **Scope (the user's brief of 2026-09-26, later):** Home → Daily closing and its direct Money / correction / history
> paths. The approved compact, bill-like Daily closing on the existing server report and closing system — the
> presentation reorganised, the accounting rules, the close contract, reopening and the before-06:00 choice
> unchanged. No pictures; live historical expenses untouched; no other page.

Companion to [`docs/51`](51_AUDIT_DAILY_CLOSING_REPORT.md) (the report and its contract), [`docs/56`](56_PRE_0600_OPENING_AND_SIMPLE_HOME.md)
(the opening choice) and [`docs/57`](57_EXPENSE_DATES_AND_HOME_REFERENCE_PASS.md) (the expense's two dates). Rules
24b, 24c, 25, 25a, 26, 26a, 27 in [`docs/04`](04_BUSINESS_RULES.md); decisions in [`docs/21`](21_PRODUCT_DECISIONS.md);
the phone's checks in [`docs/24`](24_DEVICE_QA_CHECKLIST.md) §45.

---

## 1. What changed on the screen (D63–D68)

The server report (`GET /closings/report`), the live view (`GET /closings/open/view`), the count (`POST
/closings/count`), the close (`POST /closings` with `clientUuid`, `reportVersion`, the acknowledgement and reason),
the reopen and the opening are exactly what they were. What moved is where things sit and how much is on screen at
once. The phone still sums nothing.

| # | Decision |
|---|---|
| **D63** | **The first view is a statement.** After the boutique, the date, the recorded opening ("Opened today · date · time" / "No opening time recorded") and the standing, one card: the sales value with "{n} sales · {m} items", then — each only where the server sent it — **Gross profit**, **Expenses** and **Result after expenses** (never "net profit"). A result that cannot be calculated says so in one line ("Result: cannot calculate yet ({n} items without a recorded cost)"); a person without the sales section sees the value of money received and the line saying who sees sales and expenses. |
| **D64** | **Sales details is the statement's one expandable, with the way to the records.** Invoiced sales; sales cancelled today (whatever day they were sold); returns approved today; net sales — then, where the person may see it, how the result follows: cost of items sold, gross profit, expenses, result after expenses (before fixed costs when there are any), the scope and the rule in words, or "Cannot calculate yet" with the count of items without a cost; then collected for these sales — at the till, paid later the same day, taken back by corrections — and still owed; the counting rule; and *See the transactions*, which opens the day's sales (`/sales/period?day=`). The approved references show one expandable under the statement, so the earlier separate *How this is calculated* was folded in here. |
| **D65** | **Check balances is per channel, each with its own action.** The **Cash drawer**: its opening (from the last counted close, carried over N days, or "no counted opening yet — starts from 0"), received, paid out, *Should be in the drawer*, then — once counted — Counted and Difference, and **Count cash**. **Each configured account**: its **Recorded movement** (received, paid out), then — once checked — *Movement in the account app* and Difference, and **Check balance**. The section says "Optional. An unchecked balance is closed as not verified — never as matched." and, under the accounts, that these are what staff recorded, not balances confirmed with the provider. Both actions open the counting screen **on that channel** (`/closing/count?focus=cash` or `?focus=<accountId>`): its field takes focus, and a saved count reopens for counting again. The verification chip keeps its words and colours: *Counted* green only when the difference is nil, a difference amber, *Not checked* / *Not verified* / *Counted before reopening* never green. |
| **D66** | **Money movements holds the calculation detail**, closed by default with the day's net beside its title: every channel's money in, then Received / Older debts collected / Paid out / Net, *Details by channel* (for this day's sales, older debts, corrections in, refunds, stock purchases, expenses, corrections out), and the **Expenses** — by category, reversals, total, fixed, every expense. Unattributed money stays a line here and is never countable. |
| **D67** | **Review and close, Correct a transaction and Closing history stay where they were found**: the primary button (secondary while Open the boutique is offered; disabled offline), the row, the section — with the same conditions. The generic "Check physical cash or account balance" row is gone: every channel carries its own check. The review sheet, `report_changed`, `already_closed`, the idempotent `clientUuid`, the acknowledgement and reason, the delegate rule and a repeat tap all go through the same contract. |
| **D68** | **A past day reads the same statement, read-only**: its standing (*Needs review*, *Closed*, *No activity recorded*), its snapshot line when it was closed, no Count / Check / Review actions (`canCheck` and `canClose` need the current business date), its history intact. |

### 1.1 Files

Mobile: `app/closing/index.tsx` (the screen), `app/closing/count.tsx` (`focus` param, `focused` row), i18n
`dailyReport.salesDetails*`, `checkBalances*`, `countCash`, `checkBalance`, `account.counted`, `movements*`,
`result.cannot.short` (EN/FR/AR), `lib/daily-closing-screen.test.ts` (pins). Backend untouched.

### 1.2 The words, checked (the copy pass, D69)

A pass over the Daily closing and its counting screen in EN/FR/AR, copy only — calculations, optional checks, the
close contract and live data unchanged. Two rules: **the drawer's figure is called "should be in the drawer" only
when a counted close anchors it**; with no counted opening it is the day's recorded cash movement from a 0 start and
says so. **An account is never counted and never has a balance here**: its figure is the *recorded movement*, its
check is the *movement shown by the account app*, and its states say *checked*, not *counted*.

| Where | EN | FR | AR |
|---|---|---|---|
| Report, drawer line, **no counted opening** (`dailyReport.expected.movementFromZero`; also the review sheet) | Recorded cash movement, from a 0 start | Mouvement de caisse enregistré, à partir de 0 | حركة النقد المسجَّلة، بدءًا من 0 |
| Report, drawer line, anchored (unchanged) | Should be in the drawer | Devrait être en caisse | يجب أن يكون في الدرج |
| Report, account line (unchanged) | Recorded movement | Mouvement enregistré | الحركة المسجلة |
| Report, account once checked (unchanged) | Movement in the account app | Mouvement dans l’application du compte | الحركة في تطبيق الحساب |
| Report, account chip once checked (`dailyReport.verify.account.counted`) | Checked against the app | Vérifié dans l’application | تم التحقق في التطبيق |
| Report, account chip checked before a reopen (`…account.stale`) | Checked before reopening | Vérifié avant réouverture | تم التحقق قبل إعادة الفتح |
| Report, the account's action (`dailyReport.checkBalance`, value changed) | Check movement | Vérifier le mouvement | التحقق من الحركة |
| Report, history row for an account's check (`closing.history.checked`) | {amount} shown by the account app | {amount} affichés par l’application du compte | {amount} كما يظهر في تطبيق الحساب |
| Counting screen, title (`closingCheck.title`, value changed) | Check the drawer and accounts | Vérifier la caisse et les comptes | التحقق من الصندوق والحسابات |
| Counting screen, drawer row, anchored (`closing.expected.drawer`) | Expected in the drawer | Attendu en caisse | المتوقّع في الدرج |
| Counting screen, drawer row, no counted opening | Recorded cash movement, from a 0 start | Mouvement de caisse enregistré, à partir de 0 | حركة النقد المسجَّلة، بدءًا من 0 |
| Counting screen, drawer row while the report is not yet known (`closing.expected`, unchanged) | Expected | Attendu | المتوقّع |
| Counting screen, account row | Recorded movement | Mouvement enregistré | الحركة المسجلة |
| Counting screen, account field (unchanged) | Movement shown by the account app | Mouvement affiché par l’application | الحركة الظاهرة في تطبيق الحساب |
| Counting screen, account chips (`closing.channel.checked` / `unchecked`) | Checked · Not checked yet | Vérifié · Pas encore vérifié | تم التحقق · لم يُتحقَّق بعد |
| Counting screen, account settled line | Movement in the account app · Difference · Less/More than the recorded movement. | … · Écart · Moins/Plus que le mouvement enregistré. | … · الفرق · أقل/أكثر من الحركة المسجَّلة. |
| Counting screen, account after a reopen (`closingCheck.stale.account`, `recheck`) | Checked before the day was reopened — check again · Check again | Vérifié avant la réouverture de la journée — vérifiez à nouveau · Vérifier à nouveau | تم التحقق قبل إعادة فتح اليوم — تحقق مرة أخرى · التحقق مرة أخرى |

The drawer keeps its own words (Counted, Count again, "The drawer is short…"). The counting screen learns whether the
drawer is anchored from the report the person just left (a cached read); until it knows, the neutral "Expected".
`verificationKey(v, channel)` picks the account's words; the accounting and the `verification` states themselves
are untouched.

### 1.3 The UI correction against the five phone screenshots (D70)

The user's before-state screenshots (in another conversation; none reached this one) showed Sales details carrying
paragraphs and a second block of collected / owed lines with a link, and Money movements folded behind a disclosure
with a repeated Received / Paid out / Net block, details by channel and the expenses. Corrected, presentation only:

| # | Decision |
|---|---|
| **D70a** | **Sales details is figure rows only**: Invoiced sales · (Sales cancelled, Returns approved — each only when its value is not zero) · Net sales · Cost of items sold · Gross profit · Expenses · Result after expenses. No paragraph inside. The words — the counting rule, how the result is calculated, the fixed-cost scope, or "Cannot calculate yet" with its count — sit behind a small accessible **(?)** beside the title ("What these figures mean"), shown in a dialog only when asked. |
| **D70b** | **The collected / owed block is gone from Sales details** — no "Collected for these sales", "At the till", "Paid later the same day", "Still owed", no explanatory line, no "See the transactions". The sales themselves stay one tab away on Money. |
| **D70c** | **Money movements is always in view, with no expand/collapse**, as a short list: the day's recorded movement of **each configured channel** (Cash, Bankily, Masrivi, … — money in less money out through it; the unattributed bucket only when it holds something), a line, **"Debt settled for this day (included above)"** (`totals.olderDebts` — already inside the channel it arrived through, never added again), and **"Money in the shop — recorded movement"** (`totals.net`, the net of the channels). The repeated Received / Paid out / Net block, "Details by channel" and the expenses subsection are gone; the server's figures throughout. |
| **D70d** | **"Money in the shop" alone would read as a balance**, which the accounts cannot claim (rule 26a); so the label carries "— recorded movement" and the card ends with one line: "The net of what was recorded through these channels this day — not counted cash, not provider balances." Flagged to the user as the honest form of the label they asked for. |

Keys: `dailyReport.salesDetails.help`, `movements.debtSettled`, `movements.total`, `movements.total.note` (EN/FR/AR);
`movements.hint`, `salesDetails.transactions` and `money.details` no longer appear on the screen.

### 1.4 The closing popup, the history rectangle, no balance cards (D71–D73)

| # | Decision |
|---|---|
| **D71** | **"Close the business day" is a short popup, and the contract gained one honest state.** The button (was "Review and close") opens: *Have you checked today's cash and account movements?* — **Enter the amounts** (a compact count of the drawer and each account inside the popup, each figure saved on its own through the same `POST /closings/count`, the report re-read, then back to closing — no separate page) or **I've checked** (an attestation). The confirmation shows the day in a few lines and, per channel, either its count or **"Checked; amounts not recorded"**; the button is *Close the business day*. The close sends `clientUuid` and `reportVersion` as before and, when anything has no amount, **`attestChecked: true`** — a new optional flag on `POST /closings`. The server closes such channels as **attested**: the row keeps the person and the time under the machine key `ATTESTED_AT_CLOSE`, `counted` stays null, no difference is computed, nothing reads as matched; the close event carries `attested[]` beside `verified[]` and `unverified[]` and `attestedCount`; the audit reason is `closed_attested`; the report answers `verification: 'attested'`, an info warning *"{n} balances checked; amounts not recorded."*, and never `channels_not_verified` for them; a reopen makes the attestation stale like any earlier count. The history never lists the rows a close froze — attested or not verified — as saved counts: the close event carries their numbers. (The timeline's fallback, meant for days closed before the timeline existed, also ran on any closed day where nobody had saved a count, and listed those frozen rows as "Count saved" without an amount.) The older way — `acknowledgeUnverified` with a reason — still works for older clients. Duplicate taps replay by `clientUuid`; figures that moved are refused (`report_changed`) and re-read. The popup never asks for a reason and never shows a toggle. |
| **D72** | **Closing history is one rectangle**: a header with the title, the count and the chevron at the end edge; a tap slides the entries out from beneath the header (height and a short upward slide, 240 ms, eased) and folds them back the same way; the chevron turns; with the phone's reduced-motion setting there is no motion at all. Every entry stays — openings, counts (including counts after a reopen), closes, reopens. The second "Closing history" heading is gone. |
| **D73** | **No balance cards on the page.** The Check balances section, the drawer and account cards and their Count cash / Check movement buttons are removed; the counting happens inside the popup. The separate counting page (`/closing/count`) is removed — nothing else routed to it; the *Unsettled differences* link it carried now sits beside *Correct a transaction*. Counts already recorded stay in the history and on the server; the accounting data is untouched. |
| **D74** | **The popup and the close, hardened after an independent review** (two read-only reviewers, one per repository; every finding reproduced on a copy of live before it was fixed). *The popup:* the question is the first step's own text and the title may take two lines (a new optional `titleLines` on the shared sheet), so neither is cut at large text; the amount step and the confirmation scroll, so no channel hides under the buttons when the keyboard is up; a typed amount is saved or cleared, never dropped — Continue waits with "Save the amount you typed, or clear it.", Back clears, a Change can be Cancelled with the saved figure kept; a figure is saved only if the strict amount parser accepts it — Arabic-Indic digits and ٫ are the amount, a leading minus only on an account's movement (with a keyboard that has one: Android's signed pad, iOS numbers-and-punctuation), two decimals at most, else "Enter a valid amount, with at most two decimals."; **Close the business day spins and waits while the report or the live view is read again** — after a count, after a 409 — so it never signs figures the person has not seen; a duplicate reads "This day was already closed."; each opening starts on the question. *The page:* the closing-time loan reminders the counting page carried (*Money owed*, Milestone I) sit on today's Daily closing, only when something waits; the history's reveal follows Reduce Motion as the phone has it now, not as it was at launch; its header's announced name carries the count; a close with the drawer counted still names the balances it took on the person's word. *The server:* a count may not carry the close's machine keys (`reserved_reason` — `ATTESTED_AT_CLOSE` stored by a count lifted the acknowledgement without anyone attesting); a close may not both attest and acknowledge (`conflicting_statements`); a person's own skip and the stored close now agree on both paths (they disagreed, and the day read "changed since close" for ever — on the older acknowledgement path too, since before this phase). This holds for closes made from now on: a snapshot already stored keeps what it stored, and live has no closed day at all (read-only, 2026-09-27: two closing rows, *counted* and *counting*, no skipped or machine-marked row); a reclose freezes no stale warning; a close stored before the attestation reads back with an empty `attested`; a skip's reason is kept in its count's event and audit, not only on the row a later close may replace. *The shared money field* now turns Arabic-Indic digits into the amount instead of dropping them — in every money field of the app, the one change outside the closing flow. *A second review round, on the fixes themselves,* added: the confirmation reads the day again as it opens (so figures that went stale while the page sat open never block or mislead the close); *Enter the amounts* only when the live view has channels to show; the invalid-amount sentence only once typing on cannot fix it ("-" or "." alone are an amount on its way), under the field as its error; each field and its Save / Change / Cancel named with its channel for a screen reader; a signed figure written left to right in Arabic ("-300", as every figure is shown); the Reduce Motion reader shared once for the app (react-native-web keys its listeners by the handler's text). 52 catalogue keys the removed page and sheet left behind are deleted in EN/FR/AR. |

Files: backend `create-closing.dto.ts` (`attestChecked`), `closing-lifecycle.ts` (`ATTESTED_AT_CLOSE`, `Verification` +
`attested`, `closeVerification` returns `attested`), `closing.service.ts` (the split, the rows, the payload, the audit,
the notice, the snapshot), `closing-report.ts` (`close.attested`, `channels_attested`), specs. Mobile
`components/closing/CloseDaySheet.tsx` (new; `CloseReviewSheet.tsx` removed), `components/closing/HistoryPanel.tsx`
(new), `app/closing/index.tsx`, `app/closing/count.tsx` removed with its suite, `lib/closing-report{,-view}.ts`,
`lib/navigation/registry.ts`, i18n `dailyReport.closeDay`, `closeDay.*`, `dailyReport.verify.attested`,
`dailyReport.warning.channels_attested`, `closing.history.attested` (EN/FR/AR), pins.
D74 adds: backend `closing-lifecycle.ts` (`isMachineSkipReason`), `closing.service.ts` (the two refusals, the
skip on both paths, the stale warning, the snapshot's `attested`, the reason in the event and audit), `close-statements.spec.ts`
(new), `correction-readers.spec.ts` (its pin). Mobile `lib/price-input.ts` (`toAsciiDigits`, `maskAmount`, `parseAmount`;
`parsePrice` unchanged in behaviour), `components/ui/Field.tsx` (`MoneyField`: the mask, `allowNegative`),
`components/overlay/BottomSheet.tsx` (`titleLines`), `lib/design/use-reduce-motion.ts` (new), `CloseDaySheet.tsx`,
`HistoryPanel.tsx`, `app/closing/index.tsx` (the refresh state, the reminders, the mixed caption), i18n
`closeDay.count.unsaved`, `closeDay.count.invalid`, `closeDay.alreadyClosed` and 52 keys removed (EN/FR/AR), pins.

---

## 2. `spent_on`, said apart from the business date

Rule **24c** (`docs/04`) now states it on its own: an expense's `spent_on` is the day the person *says* the money went
out — typed in the form, today by default, a memo kept for continuity — shown in the form's review step, used by the
API's list filter when asked and by the "unusual amount" sample window, and **moving no figure**. The accounting day
is the `confirmation_date` (a variable expense; the branch's business date when an Owner confirmed it) or the
`due_date` (a fixed one). Home, Money, the Daily closing, the rollups, the results and the goals read only the
accounting day.

The three rows whose memo date disagrees with their accounting day (25 Sep "Le9de" 240; 26 Sep "Sbou7" 100 and
"Courent" 500 — all `spent_on 2026-09-18`, confirmed on 2026-09-25) are described exactly in `docs/57` §1.1. **They
are not authorised for editing in this phase and were not touched.** Any repair is the audited tidy-up written in
`docs/57` §1.5, on explicit approval only; it would change no figure.

---

## 3. Verification

### 3.1 The real 03:41 scenario, on a copy of live (built API, fake clock) — **17 of 17**

`report-0341.mjs` against `prisma_verify_home` rebuilt from a read-only dump of live taken at 06:06Z on the 26th, the
API on 127.0.0.1:3012, Test Store's Owner.

| Step | Result |
|---|---|
| The copy is live as dumped | invoices 00005 and 00006 on business date 2026-09-25; Sbou7 and Courent confirmed on 2026-09-25; four rows still `spent_on 2026-09-18` |
| **03:41 on the 26th** | business day **2026-09-25**, store date 2026-09-26, not started early |
| The report | the 25th, today, *open*: **4 sales worth 6 748** (two by day, 00005 and 00006 at 03:44), 4 items, **3 confirmed expenses worth 840**, closable by the Owner (`kind first`, acknowledgement required for cash and Bankily) |
| The 03:46 expenses | Sbou7 100 (cash) and Courent 500 (Bankily), beside Le9de 240 — all the 25th's |
| The statement's arithmetic | net sales 6 748 = value − returns − cancellations; cost of items 3 050; gross profit 3 698; result after expenses 2 858 = gross − 840 — the server's, consistent |
| Check balances | drawer expected 5 558 from an opening of 0 ("no counted opening yet") plus 5 898 in and 340 out; Bankily a **recorded movement** of 350, `basis recorded_movement_not_balance`; nothing counted |
| The open view | the 25th, open since 03:41 (recorded on the 26th), already open; the timeline: the day's first activity at 09:28, the opening at 03:41 |
| A cash count saved (+50) | the drawer: expected 5 558, counted 5 608, difference +50, *counted*; Bankily still not counted; **closing still needs the acknowledgement** for the unchecked account — never matched |
| Home at 03:41 | business day 25, store date 26; the closing entry names the 25th (*counting*, after the count); today's sales value 6 748 |
| **06:00:30** | the 26th; the 25th, never closed, **needs review** |
| The 26th's report | nothing sold yet, open, warning *previous day not closed* |
| The 25th, viewed from the 26th | still 4 sales and 3 expenses, *Needs review*, its cash count kept, **not closable from the phone** |
| The 25th's history | its opening at 03:41 and its count kept |
| Home at 06:00 | the 26th's entry, *yesterday needs review* |
| Nothing moved | 00005 and 00006 still on the 25th; Sbou7 and Courent still confirmed on the 25th; `spent_on` untouched; live itself never addressed |

### 3.2 The screens, read from the page (web export of `ad78607`, isolated API, the same copy) — **23 of 23, every view passed**

`closing-ui.mjs`: each view loaded in headless Chrome, its text read, leaked keys / sideways overflow / cut-off text /
right-to-left checked, the controls driven through the real elements.

| View | Result |
|---|---|
| **The 25th at 03:41 on the 26th, the Owner** — EN 320/393/430, FR 320/393, AR 320/393 (mirrored), EN dark 393, text at 130 % EN 320 and AR 320 | **10 of 10 clean**: "25 Sep 2026 · Main Store", "Opened today · 26 Sep 2026 · 03:41", *Not closed*; the statement with "4 sales", Gross profit, Expenses, Result after expenses; Sales details closed; Check balances with "Optional…", Cash drawer / "Should be in the drawer" / **Count cash**, Bankily / "Recorded movement" / **Check balance**, the note that these are what staff recorded; Money movements closed; Review and close, Correct a transaction, Closing history — no leaked key, no overflow, nothing cut |
| **Sales details** opened (EN 393, FR 320) | Invoiced sales, Net sales, the result's lines, Collected for these sales, Still owed, the counting rule, *See the transactions* → the route `/sales/period?day=2026-09-25` |
| **Money movements** opened (EN 393, AR 393) | Details by channel, Received, Paid out, the Expenses with Courent, Sbou7 and Le9de |
| **Count cash** / **Check balance** | the counting screen on the route `/closing/count?focus=cash` / `?focus=<accountId>` |
| **Review and close** opened, not confirmed | "Close 25 Sep 2026", *Not physically checked*, the acknowledgement, "Close the business day" |
| **A cash count saved (+50)** | the drawer shows Counted, Difference "+50", *Counted*; the account unchanged |
| **A store employee** (counts, no report, Demo store) | money received as the headline, the line saying who sees sales and expenses, Check balances with Count cash, Money movements, "Only the Owner or a named delegate can close the day."; no Review and close, no Sales details, no Gross profit |
| **06:00:30** | the 26th's report: "26 Sep 2026 · Main Store", "The previous day (25 Sep 2026) was not closed.", no "4 sales"; **Yesterday** → the 25th read-only: *Needs review*, "4 sales", its history with "Boutique opened" at 03:41, no Review and close, no Count cash; Home: "Today · Not closed", *Yesterday needs review*, "Sat 26 Sep" |

Offline was not driven (the web check cannot cut the connection): the offline notice, the disabled close and the
counting screen's offline line are pinned in the source and left to the phone (§45 V12). The first matrix run found
one harness fault — the history *section* and the history *disclosure* share the words "Closing history", and the tap
hit the heading — corrected in the check, not the app.

### 3.4 The UI correction (D70), read from the page — **14 of 14** (web export of `fe55588`, a copy of live at 03:41 on the 26th)

EN/FR/AR at 320 and 393 pt, EN dark, EN 320 at 130 % text: the statement, **Sales details** closed (no "Invoiced
sales", no collected / owed line, no link, no paragraph on the page) and opened (Invoiced sales · Net sales · Cost of
items sold · Gross profit · Expenses · Result after expenses, nothing else), the **(?)** opening the words in a dialog,
**Money movements** in view with no expand control — "Cash drawer +5 558 · Bankily +350 · Debt settled for this day
(included above) 0 · Money in the shop — recorded movement +5 908" and its line — and no "Details by channel". The
channel lines add up to the last one (5 558 + 350 = 5 908; the debt line is inside them, not added). The page's own
text per language was written out for the user's review. The first two runs' misses were the check's (a page-wide
ban on the word "Received", which rightly still labels the money-in line inside each Check balances card) and a cash
word that differed between the card and the list — aligned in `fe55588`.

### 3.5 The closing popup, the attestation, the history rectangle and the review fixes (D71–D74), verified

**How it was checked.** Two read-only reviewers read each repository's change; every finding was reproduced on a copy of
live before it was fixed, then a second pair of reviewers read the fixes. Copies of live: the read-only dump of
2026-09-26 06:06Z, and a fresh read-only dump taken for this pass (2026-09-27 00:42Z, 15 sales, 7 expenses, 5 closing
events — live as it stands, including the phone's 06:57 opening, sales 00007 and 00008 and the 07:12 Bankily check).
Each run rebuilt its copy; the built API ran on 127.0.0.1:3012 on a fake clock; the web export ran in headless Chrome.
**Large text on the web is emulated by multiplying each text element's size and line height by 1.3** — react-native-web
writes px, so the root font size used by the earlier checks (§3.2, §3.4 and the first D71 run) moved nothing and those
"130 %" views proved nothing about large text. **The keyboard is emulated by a short sheet**: 320 × 262 leaves the room a
320 × 568 phone keeps above its keyboard (0.85 × 262 ≈ 0.85 × 568 − 260).

**The close contract — 16 of 16** (`close-attest.mjs`, OS temp), on the final build: the 25th at 03:41 asks for an
acknowledgement or an attestation for the drawer and Bankily; neither → 400 `acknowledgement_required`; `attestChecked`
closes it — both *attested*, `counted` and `difference` null, the info warning `channels_attested`, no
`channels_not_verified`, rows `ATTESTED_AT_CLOSE` with the person and the time and no amount, the timeline's close
"attested 2, unverified 0", audit `closed_attested`; the same `clientUuid` replays; another key → 409 `already_closed`;
a reopen makes the attestation stale; Demo at 09:00: figures that moved → 409 `report_changed`; a cash amount 100 short
with the accounts attested (cash −100 counted, both accounts attested); the older acknowledgement with a reason still
closes as *not verified*.

**The review's findings, reproduced then fixed — 9 of 9** (`close-guards.mjs`; the unfixed build failed 6 of them):
a person could store `ATTESTED_AT_CLOSE` or ` not_verified_at_close ` as a skip reason (201 → now 400
`reserved_reason`); a skip's reason was nowhere but the row (now also in the count's event and audit); a close on the
word over a person's skip read "changed since close" for ever (row, snapshot and read-back now agree: attested); a
reclose froze a stale warning (gone); the older acknowledgement over a person's skip also read "changed since close"
(now *skipped*, with its reason); both statements in one close were accepted (now 400 `conflicting_statements`, nothing
closed).

**The page — 31 of 31 views clean, and 7 of 7 facts read back from the server** (web export of the final mobile code). *The 06:06 copy at 03:41, Test Store:* the page in
EN/FR/AR at 320 pt and in EN at 320 pt with text 1.3× — no Check balances, Count cash, Check movement or Review and
close; the button whole. The history rectangle closed (`aria-expanded` false, height 0, hidden from readers), open after
one tap, open at once under reduced motion — **also when Reduce Motion is switched on while the page stays open** (full
height 60 ms after the tap). The question at 320 × 568 with text 1.3× in EN, FR and AR: the question, the title and
*I've checked* whole. The confirmation in the three languages; the close on the word: *Closed*, "Checked; amounts not
recorded.", "2 balances checked; amounts not recorded.", no "Difference". *Demo at 09:00, the drawer and two
accounts:* at 320 × 262 with text 1.3× in EN and AR every field and then Continue come wholly into view (a 111-pt scroll
area; the amount step pins nothing); "12" typed and not saved → Continue disabled with "Save the amount you typed, or
clear it."; "12.345" → Save disabled and "Enter a valid amount, with at most two decimals."; "." → Save disabled, no
error yet; cleared → Continue enabled; in Arabic "١٢٫٥" becomes 12.5, "-٣٠٠" becomes −300 in a field written left to
right (the drawer's stays right to left), "١٢٣٤" saves as **1 234 on the server**; an account's "-300" saves as
**−300**, the drawer never takes a minus (the server still refuses one, 400); Change then Cancel keeps 1 234; with the
report's reply held 2.5 s, **Close spins and stays disabled after a save, then enables**; a sale made under the open
popup → "The figures changed…", Close disabled while the new figures come, then enabled, then closed — the history
reads "1 500 MRU counted · difference −8 500 MRU · Checked; amounts not recorded (1)"; with the live view failing, the
popup offers *I've checked* alone. *The fresh copy of live at 00:45 on the 27th, Test Store:* the real 26th in EN/FR/AR
(opened 06:57, 2 sales · 5 700, Bankily +5 700, *Money owed* with its real lines), the page at text 1.3×, the French
question at 320 × 568 × 1.3 whole, the confirmation (drawer "Checked; amounts not recorded", Bankily "Checked against the
app"), and the close on the word: Bankily's real count **5 700 kept**, the drawer **attested, no amount** — "Day closed ·
Checked; amounts not recorded (1)" after the three real Bankily entries.

A browser preflight (OPTIONS) to the same address is held too by a naive interception; the check lets it through, or
the hold doubles (the first timing miss was the check's, not the app's).

### 3.3 Gates, in full

**Mobile** (final code): `tsc --noEmit` clean; **76 pure suites, 1 083 cases, 0 failed**; i18n parity **3 192 / 3 192 / 3 192** keys in one
order, no duplicate (52 keys removed, `closeDay.count.unsaved`, `closeDay.count.invalid` and `closeDay.alreadyClosed`
added); `expo lint` **0 errors**, 31 pre-existing warnings.

**Backend** (final code): `tsc` clean; **160 suites / 2 844 tests passed** (`npm test -- --ci`, with the new
`close-statements.spec`); `nest build` clean.

---

## 4. Owed

- **The user's review** of the revised screen and popup on the phone, then `docs/24` §45 V1–V15 — the keyboard, the
  system's largest text and Reduce Motion are the handset's to prove.
- **The user's decision — counting by a store employee.** With the balance cards and the counting page gone, the only
  place to enter an amount is the closing popup, which only a person who may close can open: an employee without the
  closing delegation can no longer record a count (the server still accepts one from them). Options: leave it; or give
  such a person the popup's amount step alone. Nothing was built either way.
- Seen on the real data, older than this phase and left as they were: a sale paid through an account reads "+0 MRU
  cash" in the history; counts of one read "1 balances", "1 payments".
- A snapshot stored before this phase keeps what it stored (a person's acknowledged skip as *not verified*); live has no
  closed day, so nothing reads "changed since close" there.
- On the iPhone's **web** browser the signed field offers a digits-only pad (the native app uses the signed pads).
- Offline on the Daily closing was read in the source (the offline notice, Close disabled), not driven.
- The three `spent_on` rows (§2), on the user's decision only.
