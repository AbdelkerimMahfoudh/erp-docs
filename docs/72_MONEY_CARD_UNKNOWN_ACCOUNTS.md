# 72 — The Money card's configured accounts: an unknown balance shows what moved (2026-10-07)

The owner's brief of 2026-10-07, with a screenshot of Boutique 2's Money page: cash set at 1 000, **Bankily and Sedad
both *Unknown***, a completed 20 000 sale paid through Sedad, the *Today* report right (1 item, 20 000 collected,
0 owed) — and the top card still saying nothing of the 20 000. "Do not assume this is a failed sale. First determine
whether Sedad lacked an opening/account anchor." This session ran in the cloud container (CLAUDE-B); the live database
and the owner's PC database are not reachable from it, so the diagnosis was made on the code and reproduced on a
**disposable copy** (`prisma_qa_ph4`, migrations `0001`–`0087`, the QA boutiques), never on live data. Decision
**D152** in `docs/21`; the phone's checks are `docs/24` §59.

---

## 1. Diagnosis — read-only, reported before any change

### 1.1 What the position API did

`GET /closings/overview` → `trackedMoney` is built by `money-positions.ts` (D89, D98–D102): each method is its
**latest anchor plus every movement recorded after it**. An account with no `money_anchors` row has no anchor, so
`accountMethod` answers `known: false, position: null, unknownReason: 'no_anchor', anchor: null, sinceAnchorNet: null`
— and the movement window (`movementsSince`) is run **only for anchored accounts**. The 20 000 therefore existed in the
day's figures (`period.collected`, `moneyToday.channels` for the branch) and nowhere in `trackedMoney`. The card reads
`trackedMoney` alone (D98: "the phone adds nothing up"), so it could only say *Unknown*.

### 1.2 Reproduced on the disposable copy, on the unchanged build (`be024dd`)

Boutique 2 (owner `boutique2@test.com`), Bankily and Sedad created, the day open with the cash set, one sale paid in
full through Sedad (17 500, the unit's price; payer number recorded), then the overview for the business day:

| Read | Answer |
|---|---|
| the sale's payment row | `method: mobile · 17 500 · account: Sedad · business_date 2026-10-07 · payer 32648261` — attached to Sedad, once |
| `period` (the Today report) | `unitsSold 1 · salesValue 17 500 · collected 17 500 · outstanding 0` — right |
| `moneyToday.channels` | `CASH in 0 · Bankily in 0 · Sedad in 17 500` — the branch's day movement knows it |
| `trackedMoney.methods` | cash known; **Bankily and Sedad `known:false, position:null, unknownReason:'no_anchor', anchor:null, sinceAnchorNet:null`**; `total: null`, both named in `unknownKeys` |
| `money_anchors` for the company | none |

That is the owner's screenshot, line for line.

### 1.3 Which of the five causes

| Possibility | What it would look like | Verdict |
|---|---|---|
| **never set** — no Owner-recorded amount for Sedad | no `money_anchors` row; `unknownReason: 'no_anchor'`; the day's figures right | **the case on the copy, and the only state that produces the screenshot** (every configured account is listed from the moment it exists — D98 — and reads Unknown until the Owner records it) |
| explicitly set to zero | a row with `amount 0`; `known: true, position: 0 + what moved after` | not this: the card would show a figure |
| set but not returned | a row for Sedad and still `position: null` | would be a backend defect; the latest row by `at` then `created_at` is read (`latestAnchor`) and 39 service tests pin it; not reproduced |
| attached to another account | `moneyToday` carries the 20 000 under another label; Sedad's channel 0 | not this: the Today card and the sale's payment say Sedad |
| excluded by a business-day error | `payments.business_date` ≠ the day; absent from *Today* too | not this: the Today report counts it |

**Not a failed sale, not a date error, not a scope error.** The accounts are company-wide (D98, D102) and were left so.

### 1.4 The read-only queries for the owner's PC database (and live, when it is reachable)

As the migrator on `127.0.0.1:3308` `phonestore` (the PC's local database, `0087`), for the company of Boutique 2:

```sql
-- the accounts the card lists
SELECT HEX(id) id, label, provider, is_active FROM receiving_accounts WHERE company_id = @company;
-- what the Owner ever recorded for them (expect: nothing for Sedad)
SELECT HEX(receiving_account_id) account, amount, at, business_date FROM money_anchors WHERE company_id = @company ORDER BY at;
-- the sale's payment: attached to Sedad once, on the business day
SELECT p.method, p.amount, p.business_date, p.paid_at, ra.label, p.payer_number
FROM payments p LEFT JOIN receiving_accounts ra ON ra.id = p.receiving_account_id
WHERE p.company_id = @company AND p.business_date = '2026-10-07' AND p.method <> 'cash';
```

and over HTTP, as the Owner with Boutique 2 in context: `GET /api/v1/closings/overview?from=2026-10-07&to=2026-10-07`
→ `trackedMoney.methods[]`: a row with `label: "Sedad"` and `unknownReason: "no_anchor"` confirms *never set*; after
this change the same row carries `movement.net: 20000` beside it.

## 2. The rule (D152)

- **Unknown + 20 000 is still unknown.** A movement never establishes a balance: Sedad reads *Unknown* until the Owner
  records what it holds (and then from that instant, as before). Known 5 000 + 20 000 = 25 000. An explicit 0 is known.
- **An unknown balance hides nothing.** Beside an unknown method the card says what moved through it on the business
  day: *Starting amount unknown · +20 000 MRU recorded today*. Two figures, never merged: the **position** (anchor +
  movements after it) and the **day's net movement** (inflows − confirmed outflows on the business day).
- **No total while any included balance is unknown**, and the card names the accounts that prevent it (unchanged).
- **Owner action from the card:** *Set account amounts* opens the existing company-wide sheet, which says that every
  shop will see the amount. The shop's cash-opening workflow still never sets a company account (D98/D102 unchanged).

## 3. The API — `movement` on every method, no new ledger

Each `trackedMoney.methods[]` row gains one field, beside the existing position fields:

```json
{ "key": "account:…", "label": "Sedad", "scope": "company", "known": false, "position": null,
  "unknownReason": "no_anchor", "anchor": null, "sinceAnchorNet": null,
  "movement": { "businessDate": "2026-10-07", "inflows": 20000, "outflows": 0, "net": 20000 } }
```

| | |
|---|---|
| `businessDate` | the requesting branch's business day (the 06:00 rule), the same day *Today* reports |
| `inflows` | received payments + corrections in (`salesIn`, `correctionsIn`) |
| `outflows` | **confirmed** refunds, supplier settlements and payments, confirmed expenses, corrections out — the closing's own filters; a refund only reported counts nothing |
| `net` | inflows − outflows, two decimals |
| the drawer | this branch's day, from the closing's own cash channel (`cashDayRows`) — the same figures as `moneyToday` |
| an account | **company-wide** for that business day (`accountDayMovements`): the closing's seven sources with no `branch_id`, exactly as the positions are company-wide |

The **position** is unchanged: `movementsSince` still windows every anchored account from its own anchor's instant with
its eleven sources (D89 timing: a refund from its report, a fixed expense on its due day, a record fix at the
record's own moment), so the day's movement and the position are computed by different, documented rules and are
**never added to each other**. An older server simply has no `movement` field; the phone treats it as absent.
No migration, no table, no second reconciliation: one additional read per overview, run only when the accounts are
visible (the Owner).

## 4. The phone

`components/money/ExpectedMoneyCard.tsx`: under a method that is unknown **and** moved on the day, a caption from the
server's `movement.net` — EN *Starting amount unknown · +20 000 MRU recorded today*, FR *Montant de départ inconnu ·
+20 000 MRU enregistré aujourd’hui*, AR *المبلغ الابتدائي غير معروف · +20 000 MRU مسجَّل اليوم* — the signed amount
isolated left-to-right (`isolateLtr`) when the layout is right-to-left, a minus for money out. Nothing under a known
method, nothing under an unknown one that did not move, never a figure in the position column. For the Owner, while
any account is unknown, **Set account amounts** (FR *Fixer les montants des comptes*, AR *تحديد مبالغ الحسابات*) opens
the existing *Company account amounts* sheet (its warning *Shared by every shop …* unchanged). `lib/money-overview.ts`
types the optional `movement`.

## 5. Verification

- **Backend** — `money-positions.spec.ts` 42 (6 new: unknown Sedad + 20 000 stays unknown with its movement; 5 000 +
  20 000 = 25 000; explicit 0 known; in and out 20 000 → net 0, still unknown; the drawer's day rows; rounding and
  per-method separation); `money-anchors.service.spec.ts` 39 (7 new: through the service — Sedad unknown with the
  20 000 beside it, no total, one company-wide day read with no `branch_id`; Bankily 5 000 + 20 000 = 25 000 counted
  once; explicit 0; no day read for a caller without the accounts; the day query's seven sources keyed by the day the
  closing books them on, confirmed/approved filters, accounts only, never windowed by an instant); `tsc`; the full
  suite (185 suites / 3 364 passed / 3 skipped).
- **Real HTTP on the disposable copy** (`scratch/ph4/matrix.cjs`, every expectation a delta between two reads of the
  overview): **27 / 27** — (1) Sedad never set + a 20 000 sale: still `no_anchor`, `movement.net` +20 000, no total, the Today
  report +20 000; (4) Bankily never set and never moved: Unknown with a zero movement; (2) the Owner records Sedad at
  5 000 (a retry under the same key is the same anchor), then a 20 000 sale: **25 000**, `sinceAnchorNet` 20 000, the
  day movement +40 000 over the two sales, the anchor's own response carrying the method with its movement; (3)
  Bankily recorded at 0: known, 0; a custom account (Masrvi) never set: Unknown with +27 500, then set at 12 000: known
  and the total the sum of the positions; (5) two accounts, two sales: nothing crosses; (6) a split 10 000 cash +
  10 000 Sedad: the drawer +10 000, Sedad +10 000; (7) the same sale retried under its key: counted once; (8) a
  payer-number-only correction: recorded, nothing moves; (9) a reclassify to Bankily, approved: Sedad −26 000, Bankily
  +26 000, once, in position and in the day's movement; (11) a refund reported through Sedad, unconfirmed: nothing
  moves; (10) confirmed: −20 000 once, a second confirm nothing more; (13) the annex of the same company reads the
  same account positions and movements but its own drawer, Boutique 1 (another company) unchanged throughout, a
  Manager reads the drawer alone with no total; (14) every method's `movement` well-formed, the drawer's equal to the
  day's cash channel. The business-day boundary (`matrix-day.cjs`, three API instances on one database, two with a
  shifted clock): **7 / 7** — at 03:00 local on the next calendar date the business day is still the running one, and a 21 000 Sedad
  sale sold then lands on it (+21 000 in that day's movement and in the position, on every instance); at 07:00 the
  next business day begins with a **0** movement for Sedad and for the drawer while Sedad's position carries
  everything since its anchor; a sale before the opening is 409 `store_closed`; after the Owner opens the day (set), a
  22 000 sale is that day's movement alone, the previous day's unchanged, the position +22 000. The serialized `trackedMoney` the phone reads was printed and checked field by field.
- **Mobile** — `tsc`; `expo lint` 0 errors / 29 warnings (baseline, none in the changed files); 92 node suites;
  parity EN/FR/AR (3 323 × 3); rendered `__tests__/money-card.test.tsx` 7 (EN/FR/AR; RTL with the isolates; the
  Owner's button and nobody else's; a known account and an explicit zero) — 6 rendered suites / 35 tests in all.
- **Device:** NOT DEVICE VERIFIED — `docs/24` §59 has the exact steps.
- **Seen in passing, outside this brief:** opening the next business day with **Keep** while the tracked drawer is
  negative (this fixture's supplier payments exceed its cash) answers **500** — `ck_opening_decisions_amount` refuses
  a negative kept amount at the database — where a clear 400 should say the drawer cannot be kept; the Owner's **Set**
  works. Recorded for a follow-up; not changed here.

## 6. Commits

`erp-backend` `55a5119` · `erp-mobile` `b79d74c` · `erp-docs` the commit carrying this page.
