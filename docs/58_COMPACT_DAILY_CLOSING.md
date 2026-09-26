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

### 3.3 Gates, in full

**Mobile** (final code, `ad78607`): `tsc --noEmit` clean; **77 pure suites, 1 079 cases, 0 failed** (new
`daily-closing-screen.test`, 6 pins); i18n parity **3 213 / 3 213 / 3 213** keys in one order, no duplicate;
`expo lint` **0 errors**, 31 pre-existing warnings.

**Backend** unchanged this phase (`4bc2d72`): its last full run stands — **159 suites / 2 835 tests passed**, `tsc`
clean.

---

## 4. Owed

- The phone: `docs/24` §45.
- Offline on the Daily closing was read in the source (the offline notice, Review and close disabled, the counting
  screen's offline line), not driven: the web check cannot cut the connection. On the handset it is one flight-mode
  toggle.
- The three `spent_on` rows (§2), on the user's decision only.
