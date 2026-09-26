# 56 — The pre-06:00 opening choice and the simple Home

> **Scope (the user's brief of 2026-09-26):** Home, the Daily closing reached from Home, and their direct data and
> navigation dependencies. First the real opening at ~03:41 on 26 September investigated and reported; then the
> pre-06:00 *Open the boutique* flow fixed so the business day is chosen **before** the opening is recorded; then the
> approved simple Home design on Home's working behaviour. No pictures, no other page redesigned, live records
> untouched apart from an explicitly approved correction (none was needed — §1.3).

Companion to [`docs/50`](50_AUDIT_HOME_BUSINESS_DAY_CLOSING.md) (the business day), [`docs/54`](54_HOME_COMPLETION.md) (Home
as completed) and [`docs/55`](55_HOME_MONEY_FOLLOWUP_AND_FILE_REVIEW.md). Rules in [`docs/04`](04_BUSINESS_RULES.md)
§F (24a, 25a, 27); decisions in [`docs/21`](21_PRODUCT_DECISIONS.md).

---

## 1. What the app recorded at 03:41 on 26 September 2026

Read from live `phonestore`, read-only, before anything was changed. Test Store, branch **Main Store**
(`01a091c7-7f1e-…`), company timezone `UTC` (so boutique time is UTC). Actor: `test@test.com`, the Owner.

| Store time (26 Sep) | Request | What was written |
|---|---|---|
| **03:41:54** | `POST /closings/open {}` | `closing_events` **`opened`**, `business_date` **2026-09-25**, `nth 1`, payload `localTime "03:41"`; audit `BusinessDay create {businessDate 2026-09-25, nth 1}`. No `day_started_early` exists. |
| 03:44:14 | `POST /sales` | Invoice **00005**, 850 MRU (margin 300), `sold_at` 03:44:14, **`business_date` 2026-09-25** |
| 03:44:39 | `POST /sales` | Invoice **00006**, 3 600 MRU (margin 2 650), **`business_date` 2026-09-25** |
| 03:46:21 | `POST /expenses` + confirm | "Sbou7", 100 MRU, cash, `spent_on` 2026-09-18 (the date left in the form), **`confirmation_date` 2026-09-25** |
| 03:46:39 | `POST /expenses` + confirm | "Courent", 500 MRU, account Bankily, `spent_on` 2026-09-18, **`confirmation_date` 2026-09-25** |

Around them: the **25 September business day already held two sales from its own daytime** (2 298 MRU) and had **no
opening of its own** — the 03:41 tap was the first `opened` event the 25th ever received, which is why it reads
`nth 1`; the day has **no closing row** (the branch's only closing is 15 September, status *counted*), so it stands as
*Needs review* once 06:00 passed. The 22nd (two sales) is unclosed too.

### 1.1 Is this what the rules say?

Yes. Rule 24a: before 06:00 the business date is the previous calendar day, and at 03:41 nothing had started the 26th
early. Rule 25a: the opening is recorded for the current business date — the 25th — and it was. The sales took the
same date from `businessDay.assign`, the expenses their confirmation date from `today()`. Every record is consistent
with every other and with the app's own rule. Under the flow this phase introduces, **the default the Owner would have
been offered at 03:41 — *Continue 25 September* — is exactly what happened**; the only thing missing was that nobody
was asked, and the screen never said which day the opening was for.

### 1.2 What was not done

Nothing on live was reassigned, moved or corrected. No sale, expense, opening or closing changed.

### 1.3 If the Owner meant the 26th

There is no evidence of that and the rules do not require it, so **no correction is proposed**. Should the user say the
03:41 opening and what followed were meant for 26 September, the exact change would be — and only on written
approval, as an audited Owner correction, never silently:

1. `closing_events`: the `opened` row `01a0dbce-21cb-…` → `business_date 2026-09-26`, `dedupe_key
   closing:open:<branch>:2026-09-26:1`, plus a `day_started_early` row for 2026-09-26 at 03:41:54 (payload
   `previousDate 2026-09-25`).
2. `sales` 00005 and 00006 → `business_date 2026-09-26`; their at-sale `payments` rows likewise.
3. `expenses` "Sbou7" and "Courent" → `confirmation_date 2026-09-26`.
4. `audit_logs`: one `BusinessDay update` row per record, reason `business_date_corrected`, before/after.
5. `rollup_requests` for 2026-09-25 and 2026-09-26 so the day figures recompute.

The app has no screen for this ("reassigning a stored business date is an Owner correction that does not exist yet",
`docs/21`); it would be a scripted, backed-up, reviewed change.

---

## 2. The pre-06:00 opening chooses its business day (D52–D55)

### 2.1 What was wrong

At 03:41 *Open the boutique* recorded an opening immediately, for a business date the screen never named. The
two-day choice — *Continue yesterday* / *Start today early* — existed only on **Reopen**, i.e. only after the previous
day had been closed. A staff member opening at 03:41 had no way of knowing which day their sales would land on.

### 2.2 Decisions

| # | Decision |
|---|---|
| **D52** | **`POST /closings/open` takes `mode`** (`continue` \| `start_new`, default `continue`), under the same rule as a reopen's: `start_new` needs `closing.start_early` (the Owner alone) and the local clock between midnight and 06:00 (`not_before_day_start` otherwise). `start_new` first writes the **same `day_started_early` event a reopen writes** — one shared helper, still idempotent — then records the opening **of the new date**. `continue` records the opening of the running (previous) date. Nothing already recorded moves either way. |
| **D53** | **The choice is on record.** Whenever a choice existed — the calendar date ahead of the business date, or `start_new` asked for — the `opened` event's payload and its audit row carry `choice` and `calendarDate` beside the actor, the instant, the store time and the business date. A plain opening after 06:00 claims no choice. |
| **D54** | **The view says what may be chosen.** `GET /closings/open/view` returns `openChoices` (`['continue']`, or both for the Owner before 06:00) next to `reopenChoices`, plus the fields it already had (`localNow`, `localNowDate`, `businessDate`, `nextDate`, `canOpen`, `openRefusal`). The phone sends `mode` **only when a choice was made**, so an older server — which whitelists request bodies — is never sent a field it would refuse. |
| **D55** | **The phone asks before it records** (`openingPrompt`): with `start_new` offered, the **choice sheet** — *Continue {yesterday}* selected, *Start {today} early* the explicit second tap, the store's time in the title, both dates in full, which date receives new sales and expenses under each, "Nothing already recorded moves to another day"; without it but before 06:00, a **notice** — "Open the boutique for {yesterday}? It is {time} on {today}, before 06:00: the business day is still {yesterday}… Only the Owner can start {today} early" — with Cancel; after 06:00, nothing. One `DayChoiceSheet` serves the opening and the reopen (`intent`), so **the reopen keeps its choice exactly as it was**. |

The previous day left behind by an early start, if never closed, reads **Needs review** on Home's closing entry, on
`business-day`, on the report and on the open view — unchanged rule 27, now exercised by this path (§4.1 steps 11–12).

### 2.3 Files

- Backend `4f63ccd`: `src/closing/dto/open-day.dto.ts` (`mode`); `closing-lifecycle.ts` (`openChoices`);
  `closing.service.ts` (`requireEarlyStartAuthority`, `assertBeforeDayStart`, `startNextDayEarly` shared by `reopen`
  and `open`; `open` with the choice; `openView.openChoices`); specs `closing-lifecycle.spec.ts`, new
  `closing-open.spec.ts` (nine cases: refusals by name, the two events and two audit rows of a `start_new`, the
  `continue` payload, no choice after 06:00, no second start, repeat tap, closed day).
- Mobile: `lib/closing.ts` (`openChoices?`, `useOpenDay(mode?)`), `lib/home-day.ts` (`openingPrompt`),
  `components/closing/DayChoiceSheet.tsx` (replaces `ReopenSheet.tsx`), `app/closing/index.tsx` (`onOpen` →
  prompt → `recordOpening`), i18n `openChoice.*` (11 keys × 3 languages), pins in `home-day.test.ts` and
  `home-screen.test.ts`.

---

## 3. The simple Home (D56–D60)

The visual direction was the brief's description (no screenshot reached this session and no earlier decision
describes a gradient header); every figure remains the server's, and nothing from a design image was typed in.

| # | Decision |
|---|---|
| **D56** | **The header is the shared `TabHeader` on one small, restrained tint** — the accent's soft tone fading into the canvas, drawn with `react-native-svg` (already installed; no dependency added, no floating control, one accent as `docs/29` §6 asks). Store name, greeting, the bell, and **the store's calendar date** at the end edge: informational, never a range picker, the server's `businessDay.localDate` in the store's timezone (absent until the first reply rather than the phone's guess). **Before 06:00** the line under the greeting says *Sales still count for {yesterday} until 06:00*, because then the calendar and the business date differ. The idle "Ready when you are." line is gone. |
| **D57** | **Sales value first, one compact chart under it.** The period control stays (Today / 7 days / This month); the value, its exact range, and — only when the server supplied one — the comparison (D58); then the bars at 96 pt with their basis line; then the cancellation, return and net-sales lines exactly as before (docs/54 D41). |
| **D58** | **A comparison only from the server.** `GET /home` now carries `figures.comparison`: the invoiced sales value over the **preceding window of equal length** through the analytics `compare` rule (`accounting-rules.ts`) — `available: false` on a zero base, never "up 100 %". The phone prints "+12 % vs the 7 days before" / "vs yesterday" only when `available` is true, rounded to a whole percent, with a sign, in a colour that always travels with the words; an older server (no field) prints nothing, and the reply check refuses a comparison that claims to be available without its numbers. |
| **D59** | **Collected, Expenses, Still owed are three plain lines** in one card: the word, its scope under it ("Received in this period, older debts included", "After {amount} reversed", "Outstanding from these sales"), the amount at the end — no icon, colour only on the amount (received green, owed red when above zero). Labels and scope unchanged from docs/54. |
| **D60** | **One Daily closing entry**: a row that opens the report and closes nothing — "Daily closing · Today · Not closed", or, when the business day is not the calendar date, "**{date} · Not closed**" so the date the closing belongs to is never mistaken before 06:00; the *Yesterday needs review* chip under it when it applies. Top boutique with See more, Latest phones with the filtered Stock link, the pending-work rows, the five tabs, the permission gating, the older-server notice and the refresh/offline/failed states are as they were. The "{branch} · {period}" line is gone: the header names the branch and the range line the period. |

---

## 4. Verification (isolated copy, no picture, live untouched)

### 4.1 The business-date rules through the built API on a fake clock — 31 of 31

`open-choice.mjs` against `prisma_verify_home` (rebuilt from the dump), the API on 127.0.0.1:3012, timezone UTC.

| Step | Result |
|---|---|
| The 5th, 14:00: a sale, nobody opens | business date 05; `openChoices ['continue']`; door never opened |
| The 6th, 03:41, the Owner's view | business date **05**, store clock 03:41 on the **06**, `canOpen`, `openChoices ['continue','start_new']`, `nextDate 06` |
| The seller's view | the same day, `['continue']` only |
| The seller asks `start_new` | **403**, nothing written |
| Home before the choice | `businessDay 05`, `localDate 06`, closing card 05 — the header-note case |
| **The Owner opens with `start_new`** | reply: the **6th**, door open, opening 03:41 by the Owner; `day_started_early(06, previousDate 05)` and `opened(06, nth 1, choice start_new, calendarDate 06)`, actor on both; two `BusinessDay` audit rows |
| `business-day` after | 06, `startedEarly`, previous day **05 · needs_review** |
| Home after | business day = store date (no note), closing card 06, *yesterday needs review*; today's comparison against the 5th's 10 000 |
| A sale now; the 5th's sale | **06**; the 5th's still **05** — nothing moved |
| Repeat taps (Owner ×2, seller ×1); a second `start_new` through Reopen | 409 `open_already_open` ×3; one start, one opening, still |
| The 5th viewed now | `needs_review`, `past_day` |
| Test Store, 03:41, **`continue`** | the opening lands on the **05**, at 03:41 on the 06 by the store clock, `choice continue`; no early start; `business-day` and Home say 05 until 06:00, Home's closing card 05 |
| 05:59:30 | still the 05, the early start still offered on both paths |
| **06:00:30** | the 06 by itself, `['continue']`, openable; the 05 needs review; `start_new` → **409 `not_before_day_start`**; a plain opening records **no choice** |
| The 6th closed at 22:00; 03:30 on the 7th | the 6th `closed`, `open` refused **`open_day_closed`**, `canReopen`, `reopenChoices` both — **the reopen's choice preserved**; Reopen `start_new` → the 7th, the 6th stays locked; the 7th then opens; previous day closed, no review |

### 4.2 The screens, read from the page (web export, isolated API on a fake clock, no picture) — 32 of 33

`open-ui.mjs`: each view loaded in headless Chrome, its text read, leaked keys / sideways overflow / cut-off text /
right-to-left checked, the controls driven through the real elements.

| View | Result |
|---|---|
| **Home at 03:41, the Owner** — EN 320/360/393/430, FR 320/393/430, AR 320/393/430; EN and AR dark at 393; text at 130 % EN 320, AR 320, FR 393 | **all clean**: "Tue 6 Oct" in the header, "Sales still count for 5 Oct 2026 until 06:00" under the greeting, the entry "5 Oct 2026 · Not closed", the three money lines and the basis line; no leaked key, no overflow, nothing cut, Arabic mirrored; "Ready when you are" gone |
| Navigation from Home | the closing entry opens the Daily closing on the 5th with *Open the boutique* offered; the bell opens Notifications; Top boutique's See more → Boutique ranking; Latest phones' See more → Stock (the one finding: the check expected "Latest phones received" absent on the Stock page reached with the newest-received sort — the harness's expectation, not the app's fault) |
| **The seller at 03:41** | the notice: "Open the boutique for 5 Oct 2026?", "It is 03:4x on 6 Oct 2026, before 06:00: the business day is still 5 Oct 2026, and new sales and expenses count for it until 06:00. Only the Owner can start 6 Oct 2026 early."; Cancel keeps the button |
| **The Owner's sheet** — EN 393, FR 320, AR 393 (RTL), EN 320 at 130 % | the store's time in the title, the question naming 6 Oct 2026, **Continue 5 Oct 2026 selected** (`aria-checked` read from the radios: `["true","false"]`), Start 6 Oct 2026 early, both bodies, "Nothing already recorded moves to another day.", the confirm |
| Continue confirmed (Main Store) | "Opened today · 6 Oct 2026 · 03:43" (the clock had run on), the button gone, the report still the 5th's; Home: the note and "5 Oct 2026 · Not closed" |
| Start early confirmed (Test Store) | opened for the 6th, the 5th gone from the context; Home: "Today · Not closed", no note |
| **06:00:30** | Open records at once — "Opened today · 6 Oct 2026 · 06:00", no sheet, no notice; Home: "Today · Not closed" and *Yesterday needs review*, no note |
| The 6th closed; **03:30 on the 7th** | no Open button; *Reopen this day* → "Reopen at 03:30", Continue 6 Oct 2026, Start 7 Oct 2026 early, "Confirm and reopen" — unchanged; Home: "Wed 7 Oct", the note for the 6th, "6 Oct 2026 · Closed" |

**Found by the first run and fixed:** the radios' checked state was set through `accessibilityState`, which
react-native-web 0.21 no longer maps — the sheet now uses the `aria-checked` prop, which React Native maps on the phone
and the web reads (D55; the reopen sheet had the same gap); and the English "still needs its closing." tripped the
harness's untranslated-key detector, so the body now reads "is still to be closed". Two of the first run's findings
were the harness's own (screens that also say "Sales value"), corrected in the check.

### 4.3 Gates

Backend: `closing-open`, `closing-lifecycle`, `closing-routes`, `home-completion`, `reporting-consistency`,
`accounting-rules` — 95 specs green; `tsc` clean. Mobile: `tsc` clean; **75 pure suites** (new `home-screen.test`,
`home-day.test` +3); i18n parity **3 202 / 3 202 / 3 202** in one order; `expo lint` 0 errors (31 pre-existing
warnings, two fewer). The API on 3010 was rebuilt and restarted on the new backend (pid 14540) so the phone gets the
choice.

---

## 5. Owed

- **The phone:** `docs/24` §44 — the sheet at 03:41 by the store's clock, the notice as a staff member, repeat taps,
  the 06:00 boundary, a closed and an unclosed previous day, Home's header and its note in FR and AR on a handset.
- The correction path for a stored business date (§1.3) still does not exist as a screen.
- Only D−1 is checked for *Needs review* (docs/51 limit, unchanged): the 22nd's unclosed day is not announced.
- The expense form kept `spent_on 2026-09-18` across the 03:46 entries — outside this scope, noted for the expenses
  screen.
