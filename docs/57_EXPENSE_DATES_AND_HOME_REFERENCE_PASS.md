# 57 — The expense's two dates, the Home reference pass, and the check rerun

> **Scope (the user's brief of 2026-09-26, later):** Home, Money and the Daily closing; no pictures; live transactions
> untouched. Home compared with the approved simple reference and corrected; the two expenses of 03:46 investigated
> — what each of their dates drives, why the form kept 18 September, the stale default fixed for future entries, the
> records and any correction reported for the user's decision; the page check's last discrepancy resolved and the
> whole check rerun; full gate totals.

Companion to [`docs/56`](56_PRE_0600_OPENING_AND_SIMPLE_HOME.md). Decisions in [`docs/21`](21_PRODUCT_DECISIONS.md);
the phone's checks in [`docs/24`](24_DEVICE_QA_CHECKLIST.md) §44.

---

## 1. The two expenses of 03:46 on 26 September

### 1.1 The records, exactly (live `phonestore`, read-only; Test Store · Main Store unless noted)

| Created (UTC) | Category | Amount | Class · method | Status | `spent_on` | `confirmation_date` | `due_date` |
|---|---|---|---|---|---|---|---|
| 2026-07-30 18:31 (Demo · Main Store) | Rent | 500 | variable · cash | confirmed | 2026-07-30 | 2026-07-30 | — |
| 2026-09-14 20:01 | Lunch | 100 | variable · cash | confirmed | 2026-09-14 | 2026-09-14 | — |
| 2026-09-18 19:46 | Etay | 100 | variable · cash | **rejected** | **2026-09-18** | — | — |
| 2026-09-22 04:45 | Le9de | 100 | **fixed** · account | confirmed | 2026-09-21 | 2026-09-22 | 2026-09-22 |
| 2026-09-25 09:30 | Le9de | 240 | variable · cash | confirmed | **2026-09-18** | 2026-09-25 | — |
| **2026-09-26 03:46:21** | **Sbou7** | **100** | variable · cash | confirmed | **2026-09-18** | **2026-09-25** | — |
| **2026-09-26 03:46:39** | **Courent** | **500** | variable · account (Bankily) | confirmed | **2026-09-18** | **2026-09-25** | — |

Audit rows 1607–1610: each created as `reported` and confirmed within a quarter of a second, `confirmationDate
2026-09-25`, `reason_omitted 1` (the Owner's own record, no note). Every expense entered since the 18th — the rejected
one included — carries `spent_on 2026-09-18`.

### 1.2 What each date is, and what it drives

`spent_on` is "the day it was spent", typed in the form (today by default) and kept "for continuity with the
pre-workflow column"; the server uses it for nothing that counts money. **The accounting day is `confirmation_date`
(a variable expense) or `due_date` (a fixed one)** — the branch's business date at the moment of confirmation, so the
03:46 entries landed on 25 September under rule 24a exactly as the sales did.

| Where | The date that decides | For the two 03:46 expenses |
|---|---|---|
| **Home** — Expenses figure for the period, the "After {amount} reversed" line | `IF(fixed, due_date, confirmation_date)` (`period-figures.ts`) | counted on **25 Sep** |
| **Money** — the Daily expenses card, View all expenses' totals | confirmation today / due today (`expenses-today.ts`) | 25 Sep |
| **Daily closing** — expense lines, result after expenses, expected cash and account movement | `confirmation_date` / `due_date` (`closing-report.queries.ts`) | 25 Sep's report |
| Rollups, results, goals | the same accounting day | 25 Sep |
| **Expense history on the phone** | the list is newest first by id and shows no `spent_on`; the detail shows none either | the 18th is invisible after submission — it appears only in the form's review step ("Date") before sending |
| `GET /expenses?date=` (API) | filters on `spent_on` — **no screen uses it** | — |
| **Warnings** — "unusual amount for this category" | the sample is confirmed expenses with `spent_on` in the last 180 days | the 18th is inside the window; no warning depends on the day |

So the two expenses are counted, closed and reported on **25 September everywhere money is counted**; the stray
`spent_on` changes no figure anywhere. It is wrong on the record, and it would mislead anybody reading the table or
the API.

### 1.3 Why the form kept 18 September

Two defects in the expense form's draft, together:

1. **The draft was written back the moment it was cleared.** `useDraft` saves on every change, and a screen passes a
   fresh object literal every render, so it saved on every render. After a submission `draft.clear()` set state, the
   screen re-rendered once more before leaving, and the save effect wrote the just-submitted form — category, amount,
   method and date — straight back. Next time the form opened it was "restored", the person overwrote the category
   and the amount, and the date rode along.
2. **Discarding the restored draft reset category, amount, note and reference — not the date.**

The default of the first entry after the workflow arrived (18 Sep 19:46, the rejected "Etay") therefore became the
date of every expense since, whichever day it was typed: the 25th's 09:30 entry and both 03:46 entries.

### 1.4 The fix (mobile, for future entries)

- `lib/offline/use-draft.ts`: a draft is written **only when its content changed** (compared as JSON), and `clear()`
  marks what is on screen as already written, so nothing goes back until the person types again. Every draft screen
  gains this; it also removes a write per render.
- `app/expenses/new.tsx`: the date is restored from a draft **only if the person set it** (`dateTouched`, saved with the
  draft); a default is today's, whatever day the draft was born — which also retires the stale drafts already on the
  phone (they carry no `dateTouched`). Discard puts the date back to today. The field's example is today's date, not
  a fixed one.
- Pinned in `lib/expense-form.test.ts`.

### 1.5 Proposed correction of the records — **not applied**; for the user's decision

`spent_on` is a continuity column with no financial effect, so this is a tidy-up, not a money correction. If wanted:

```sql
UPDATE expenses SET spent_on = confirmation_date
 WHERE id IN (UNHEX('01A0D7E69E037E5A9A7B1E4500E08395'),   -- 25 Sep 09:30 · Le9de · 240
              UNHEX('01A0DBD233C47DD1ADCBB9A641D630BF'),   -- 26 Sep 03:46 · Sbou7 · 100
              UNHEX('01A0DBD279E776E8B94356CA7706EF43'));  -- 26 Sep 03:46 · Courent · 500
```

with one `audit_logs` row per expense (`Expense` / `update`, before `{spentOn: '2026-09-18'}`, after the new value,
reason `spent_on_corrected`), after a backup per `docs/22`. No rollup, closing or Home figure changes. The rejected
18 September "Etay" is genuinely the 18th; the 22 September fixed "Le9de" (`spent_on` 21 Sep, due 22 Sep) is left
as typed.

---

## 2. Home against the approved reference (D61–D62)

| # | Decision |
|---|---|
| **D61** | **The greeting keeps its own line.** "Ready when you are." (or "Getting your shop ready…") is back under the greeting on every day. Before 06:00 the business-date line — *Sales still count for {yesterday} until 06:00* — is a further line under the header, on the same tint, separated by a hairline: it explains, it does not replace. |
| **D62** | **Collected, Expenses and Still owed are three distinct, quiet, text-first cards**: the word, the amount, the unit, its scope; no icon; the colour is only a soft tint that follows the amount's meaning (received green, owed red when above zero, expenses neutral). Three abreast where they fit (≥ 360 pt), two and one at 320 pt (a wrapping row), one under another when the system text is 1.2× or larger. Labels and scope unchanged. |

Kept: the one compact chart under the sales value, the restrained header tint, the calendar date beside the bell, every
link, the pending rows, the accounting lines (D41, D58). No decorative icon, no sample figure.

---

## 3. Verification

### 3.1 The screens, read from the page (web export, isolated API, fake clock) — **33 of 33, every view passed**

The same `open-ui.mjs` as `docs/56` §4.2, re-exported on this build, with the greeting line expected back:

- **Home at 03:41** — EN 320/360/393/430, FR 320/393/430, AR 320/393/430 (mirrored), EN and AR dark at 393, text at
  130 % EN 320 / AR 320 / FR 393 — **15 of 15 clean**: "Ready when you are." under the greeting *and* "Sales still
  count for 5 Oct 2026 until 06:00" under the header, "Tue 6 Oct", the entry "5 Oct 2026 · Not closed", the three
  cards (word, amount, MRU, scope) — no leaked key, no sideways overflow, nothing cut.
- **Navigation from Home** — the closing entry → the Daily closing on the 5th; the bell → Notifications; See more →
  Boutique ranking; See more → Stock (**the last discrepancy resolved**: Stock is a tab, and on the web the tab
  navigator keeps Home mounted behind it, so Home's words stay in the page text after the switch — the check now
  reads the route the page reached, `ROUTE:/inventory`, which is the proof of the link; the app was right all three
  times).
- **The seller's notice** and its Cancel; **the Owner's sheet** in EN 393, FR 320, AR 393 and EN 320 at 130 % with
  *Continue* selected (`aria-checked ["true","false"]` on every one); Continue and Start early confirmed through the
  sheet; 06:00:30 with no prompt, Home with "Today · Not closed", "Ready when you are." and *Yesterday needs review*;
  the closed 6th's reopen sheet unchanged at 03:30; Home on the 7th before 06:00 with the note for the 6th and
  "6 Oct 2026 · Closed".

Nothing was posted to live; the copy was rebuilt before the run and dropped after it.

### 3.2 Gates, in full

**Backend** (`npm test -- --ci`, the whole suite): **159 suites, 2 835 tests, all passed** (107 s; Jest's usual
note that one worker had to be force-exited — a pre-existing teardown leak, not a failure). `tsc --noEmit` clean.
Unchanged since `4bc2d72`.

**Mobile**: `tsc --noEmit` clean; **76 pure suites, 1 073 cases, 0 failed** (`node lib/**/*.test.ts` and
`components/**/*.test.ts`; new `expense-form.test`, `home-screen.test` extended); i18n parity **3 202 / 3 202 / 3 202**
keys in one order, no duplicate; `expo lint` **0 errors**, 31 pre-existing warnings.

---

## 4. Owed

- The phone: `docs/24` §44 U1–U13 (the greeting line and the note together before 06:00; the three cards at 320 pt
  and with the system text at its largest; an expense entered after an earlier one — the date is today's).
- The three `spent_on` rows (§1.5), on the user's decision only.
