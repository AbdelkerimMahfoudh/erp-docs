# 55 — Home/Money follow-up, and the imported-stock review on the 100-phone workbook

> The user's brief of 2026-09-26 (no pictures; physical-phone checks left for the user's final test): fix the 320-point
> "Partenaires" tab clipping; compare Money's today-only expenses and account movements against the recorded product
> decisions and implement period totals only if they were agreed, keeping the labels explicit; verify the Home and Money
> links and error states; and finish the imported-stock review reached from Home → Receive — reproduce the 100-phone file
> on the current build, fix clipped names, counts and amounts, make the horizontal filters clearly usable, tidy the pinned
> payment footer, measure where the lag occurs (parsing, first render, filtering, expanding a group, editing an item,
> scrolling, saving the draft) and fix the measured bottleneck, keeping all 100 items and their corrections, never hiding
> unresolved rows or enabling payment while items need review; report timings before and after.

## 1. Money's today-only figures against the recorded decisions

| Figure on Money | The decision | Found | Done |
|---|---|---|---|
| **Accounts today** (the "Cash & accounts" disclosure) | `docs/21`, the 0074 Money redesign: "*Accounts today* — what was recorded into and out of each active account **today**; recorded movement, never called a balance." The visual-fidelity pass (2026-09-21) drew the same. | Today-only, as decided; the hint said "today" without saying which day. | Kept today-only. The hint names the business day: "Recorded into and out of each account today (26 Sep 2026). Not the account's balance…" |
| **Daily expenses** (the card) | The same pass: "*Daily expenses* with *Add expense*, today's paid expenses and *View all expenses*"; `docs/53` D33 fixed the day rule (a variable expense on its confirmation date, a fixed one on its due date) and the reversal rows. | Today-only, as decided; the hint said "Today only — the period above changes sales, not this." | Kept today-only. The hint names the day: "Today only (26 Sep 2026) — the period above changes sales, not this." |
| **Period totals** for expenses or account movements | **No recorded decision agrees them.** The 0074 table keeps the period for sales, collected and owed only, and states why accounts carry no balance. | — | **Not implemented**, per the brief. |

**D42.** Money's account movements and expenses stay today's, by the 0074 decision; their hints carry the business day
(`overview.today`, the server's), so "today" can never be read as the period above or the phone's date. The app's
reply check now requires `today`, since a hint is built from it.

## 2. The tab label at 320 points

The navigator's own button keeps a 5-point inset on each side; with five tabs on a 320-point screen a label had 54 points
and French "Partenaires" needs 56 at 11 points. Two fixes were measured and rejected on the page: padding on the outer
item (recorded in `docs/54`: it made the label narrower) and a negative margin on the label to borrow the inset — the
margins were applied, but on the web a one-line label is capped at its button's width, so it stayed at 54 (it would have
worked on the phone alone). **D43:** below 360 points the tab label is the compact 10-point token
(`type.tabLabelCompact`; 11 points everywhere wider) — the size the platforms' own tab bars use; "Partenaires" then needs
51 points. The bar's height and the label's line height are unchanged.

## 3. The imported-stock review (Home → Receive → the file icon → Check the delivery)

### 3.1 Reproduction

The real 100-phone workbook (`demo-receiving-100-phones.xlsx`, 12 047 bytes) through the real parse endpoint of the API
built from `9a1155a`, on the isolated copy as the Test Store owner: **100 entries, 10 groups of 10; 70 "no product
match", 30 "several products match" (30 candidates offered); 0 ready, 100 need review** — the same mix the earlier
measurement recorded. Everything below was measured on the current app (mobile `056bb6e`) exported for the web with a
temporary dev hook and render counters (never committed), in headless Chrome at 393 points with the **CPU throttled
4×** to stand in for a mid-range phone, the same method before and after.

### 3.2 Where the time went (before)

| Stage | Measured | Note |
|---|---|---|
| File parsing | **82 ms** round trip, 44 KB reply | Server-side; not the lag. |
| First render (batch handed to the screen → every group header on the page) | **593 ms** of long tasks (two, the longest 314) | |
| Filtering (Needs review) | **114 ms** | |
| **Expanding a group** (10 rows) | **754 ms in one long task** | The largest single stall. |
| Editing an item (open the sheet, type, save, row updated) | **778 ms** over six tasks (longest 384) | |
| Excluding a row | 108 ms | |
| Scrolling the open list to the end and back | 78 ms; 0 row re-renders | Already virtualised. |
| Saving the draft (on every batch change) | JavaScript side **negligible**: 43 KB envelope, `JSON.stringify` 0.08 ms, the write guard 0.7 ms; every derived value (`batchCounts`, `groupEntries`, `groupSummaries`, `reviewRows`, `purchaseItems` + fingerprint) under 0.2 ms | Measured under node with the real parse. The native file write is the only part not measurable off the phone; it is 43 KB. |

**The bottleneck.** A CPU profile of the heavy stages put the time in the browser's own layout and paint, not in
JavaScript: first render 2 291 ms of layout against 246 ms of script; expanding a group 1 009 against 554; opening the
sheet 651 against 317. The cost is the **number and weight of the views a row mounts**. Each of an open group's ten
rows carried three design-system Buttons — an animated pressable with a shared value, an animated style and an SVG icon
— thirty per group, plus four separate Texts on its first line. On a phone the same work is view creation, Yoga layout
and the animation library's mounting; the profile's proportion, not its milliseconds, is what carries over.

### 3.3 What changed (D44–D48)

| # | Decision |
|---|---|
| **D44** | **A row's actions are light words.** Accept, Edit, Exclude (and Include again) are a plain `Pressable` around one `Text` (`RowAction`): 48 points tall, the press shown by opacity, no icon and no animation library. The names — which the design asked for — stay; Accept is still disabled while a blocking issue remains; Exclude reads as danger. The design-system Button stays for the actions that stand alone (Continue to payment, Match product, the sheet's own). The row's first line is one caption ("Row 12 · IMEI 1 · 2 IMEIs") and the identifier. |
| **D45** | **Every filter in view, each a full target.** The four filter chips wrap onto a second line at 320 points instead of scrolling sideways, where the fourth sat off-screen and unknown; each is 48 points tall in this row — a chip inside a scrolling list cannot lean on hit slop, which competes with the scroll. Supersedes the "one sideways filter row" of `ef2c795`. |
| **D46** | **The pinned footer** says, on one line, what is ready and what it costs and — beside it — what still stands in the way ("100 remain", in warning colour) or, once nothing does, what was left out; then the one action. Continue to payment is disabled exactly as before (`!ready || counts.ready === 0`), the payment step is reached only through it, and the list's tail keeps Exclude all and Leave it away from it. |
| **D47** | **Native text may shrink.** A text in a row now has `flexShrink: 1, minWidth: 0` where it did not (the cost, the caption, the identifier), and the group header's count and subtotal keep at most 48 % of the row so the name keeps at least half. Native text does not shrink on its own the way the web's does, which is how a name, a count or an amount runs past a row's edge on a phone and not in a browser. |
| **D48** | **Stage timings in the development build.** `lib/dev-timing.ts` marks a tap and logs the commit that answers it — "review: file parsed (round trip)", "review: first list shown", "review: filter applied", "review: group opened", "review: change applied", "draft written (receive.file)" — to the console, which Expo Go forwards to the Metro terminal. That is how the handset's own numbers are read back in the final test. In a production build every call returns at once. |

Nothing about the rules moved: the list is still exactly what `reviewRows` gives it (unresolved rows included, under
their own filter), the counts and the purchase payload come from the same pure rules, and the draft is written on every
change as before.

### 3.4 Measured after — the same harness, workbook, throttle and steps on the changed build

| Stage | Before | After | |
|---|---|---|---|
| File parsing (round trip) | 82 ms | 71 ms | unchanged path |
| First render | 593 ms (longest task 314) | **402 ms** (259) | −32 % |
| Filtering | 114 ms | **56 ms** | −51 % |
| **Expanding a group** | 754 ms, one task | **308 ms**, one task | **−59 %** |
| Editing an item (sheet, type, save, row updated) | 778 ms over 6 tasks (longest 384) | **461 ms** over 3 (250) | −41 % |
| Excluding a row | 108 ms | **no long task** | |
| Scrolling to the end and back | 78 ms, 0 row re-renders | 70 ms, 0 row re-renders | already virtualised |
| DOM nodes, one group open | 499 | **333** | ~17 per row instead of ~24 |
| Renders per edit (row / header / screen) | 1 / 1 / 2 | 1 / 1 / 2 | unchanged |
| After the run: entries · corrections · exclusions · footer · Continue | 100 · 1 · 1 · "0 ready · 0 MRU" · disabled | 100 · 1 · 1 · "0 ready · 0 MRU" · disabled | nothing hidden, nothing enabled |

The profile moved the same way: layout and paint fell from 2 291 to 1 627 ms on first render, from **1 009 to 650 ms**
on expanding a group and from 651 to 596 on opening the sheet, with script time flat (246 → 245, 554 → 408, 317 → 345).
What remains in a row is the identifier (selectable, by policy), the words, and the light actions; what remains in the
sheet is the design-system sheet itself.

## 4. Verification (2026-09-26)

Everything below ran on the isolated copy (`prisma_verify_home` from `phonestore-after-rollup-repair-20260925-075339.sql`,
throwaway credentials on the copy only, rebuilt for each run and dropped at the end) through the API built into OS temp
from backend `9a1155a`, against web exports of the app, read from the page in headless Chrome — no pictures.

| Check | Result |
|---|---|
| **The 100-phone workbook on the current build** (`review-perf`, `review-profile`, CPU throttled 4×) | Reproduced: 100 entries, 10 groups, 70 unknown / 30 ambiguous, 0 ready. Stage timings before and after in §3.2 and §3.4; integrity after every run: 100 entries, 1 correction, 1 exclusion, "0 ready · 0 MRU", Continue disabled |
| **The review, read from the page** (`review-checks`, before and after) | 21 views: EN/FR/AR × 320 and 393 pt collapsed; open group, Needs-review filter, the item sheet and an excluded row at 320 in each language; Arabic dark; EN and FR at 130 % text. Before: 21 clean, but the filter chips 36 pt and one off-screen. After: **21 clean** (the excluded view re-pinned to the new footer: "99 remain" beside "0 ready · 0 MRU", the exclusion counted on the Excluded tile and chip); the diagnosis pass lists **no clipped element and no control under 48 points** on the review at 320 in EN/FR/AR — collapsed, open and with the sheet — except the design-system sheet's own 36-point Close |
| **Money and Home** (`money-checks`, the final build) | **29 of 29 views clean**: Money at 320 and 393 in EN/FR/AR with an account paid today, a transport expense today and rent due tomorrow — the accounts hint and the expenses hint name the day, the account's label and the transport row are shown, tomorrow's rent is not; View all sales → Item sales; View all expenses → Expenses with the row; Add expense; Results, Daily closing and Outstanding payments from the registry rows; **an older server** on the overview (a figure missing → "This screen needs an updated server", no cash figure, the actions still listed) and on sales by day (7 days); **a failed server** (500) on the overview ("Money for this period did not load · Your actions below still work") and on Home ("These figures did not load", Sell still offered, no card that needs the reply); "Partenaires" whole on the tab bar at 320 in French |
| **Gates** | mobile tsc clean · **74 pure suites** (new `review-screen.test` 7; `file-receiving.test`'s filter and handler pins and `money.test`'s hint pin updated to D42/D45/D48) · i18n parity **3 187** · `expo lint` 0 errors (33 pre-existing warnings). Backend untouched (`9a1155a`); no migration |
| **Live** | Nothing written. The phone had still not called the API since the restart when this was written |

## 5. Not changed, and still owed

- **The phone.** Every figure above is the web export under a throttled CPU; the handset's own numbers come from the
  `[timing]` lines in the Metro terminal during the final test (`docs/24` §43).
- The draft is still the whole batch (43 KB) on every change; measured negligible in JavaScript, its native write is
  small, so it was left as designed.
- The sheet's Close control is the design-system sheet's own 36-point icon button (all sheets).
