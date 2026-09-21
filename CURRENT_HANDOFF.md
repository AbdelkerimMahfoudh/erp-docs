# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Owner: **CLAUDE-A** · `started_at_utc: 2026-09-21T10:45Z` — visual fidelity of Money, sales, expenses, partial/later payments and phone selection against the approved screenshots. Takeover HEADs docs `4598a00` · backend `c4d4534` · mobile `ca7b2d5`, clean and level, READY_FOR_HANDOFF / NONE — no discrepancy.
- Last owner: **CLAUDE-A** · 2026-09-18
- Last phase: **Sell a phone — Scan IMEI / Enter IMEI manually / Choose from stock**,
  Follow-up: cross-branch disclosure gated on `branch.manage` (server-decided); IMEI visibility rules confirmed and documented.
  one shared selection into the existing payment flow. Complete in code; **handset checks owed**.
- Takeover HEADs were docs `91bd5f6` · backend `c7e1900` · mobile `8db73e0`, clean and level.

### ⚠️ The scope rule, unchanged

Only **two** features are absent from the first release: **Suppliers** and
**low stock / reordering**. No removal without the user's explicit approval.
Nothing was removed this phase.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`c4d4534`** | level | 0 |
| `erp-mobile` | `reports-export` | **`ca7b2d5`** | level | 0 |

## What changed this phase

Contract in `docs/21` ("Sell a phone: three ways in, one selection"). No schema change, no migration.

| Part | Commits | Summary |
|---|---|---|
| **Selection endpoint** | backend `f26f677` | `GET /sales/selection/:identifier` (`sale.create`), read-only: either IMEI or serial, branch availability, storage/colour, masked identifier, ladder price when sellable; 20 tests |
| **Mobile** | `57c5a00` … `3c10c37` (5 commits) | selection lookup + pure rules; 42 `pick.*` keys × EN/FR/AR; PhoneChooser, ManualImeiPanel, StockPicker, SelectedPhoneCard; Quick Sell starts with the three choices and feeds one `choose()` into the existing PaymentSheet; 9 new tests |

| **Cross-branch fix** | backend `c4d4534`, mobile `ca7b2d5` | without `branch.manage` a phone elsewhere (any status) or nowhere gets one answer, `not_available_here`; with it, `other_branch` + branch name; 12 new backend tests (both permission states, company isolation, malformed/unknown IMEIs) |

**Privacy rules (confirmed by the user):** docs/21 "Who may see which phone" and docs/04 §D 19c–19d. Full IMEI on Sale detail and the customer receipt is intentional.

**Resolved, formerly open:** the brief was truncated at "Do not expose" and no
mockups arrived. Interpretation used: no internal ids, full IMEI, staff history,
other-branch or other-company data; cost only via the existing cost.view gate.

## Verification

| Kind | Result |
|---|---|
| **Backend** | tsc clean · **136 suites / 2 498 tests, 0 failed** |
| **Mobile** | tsc clean · lint **0 errors / 32 warnings** (baseline) · all pure suites **0 failed** (+`phone-selection`) · EN/FR/AR parity · web export |
| **Live** | route answers 401 unauthenticated on 192.168.137.1 and 192.168.22.10 |
| **Physical device** | 🔴 **none**. `docs/24` **§32 P1–P14 (incl. P7b–d, P10b)**, plus §31 M1–M21 and §30 |

## Services

- **Live API `:3010`** — PID 6532, built from backend `c4d4534`; `/api/v1/sales/selection/:id` answers 401 unauthenticated.
- **Metro `:8081`** — running (PID 27384) with `REACT_NATIVE_PACKAGER_HOSTNAME=192.168.137.1`
  on the PC hotspot (the Ainina router isolates clients). The git-ignored mobile
  `.env.local` points the API at `http://192.168.137.1:3010`; switch it back if the phone returns to the LAN.
- **MySQL `:3306`** — the user's WAMP.

## 🔴 Blockers and pending approvals

- **Native build blocker (pre-existing):** `npm install`'s postinstall fails —
  `expo-camera` 57.0.5 is installed but the Android scan-region patch was cut
  against 57.0.4 (alignment `e960ef6`). Expo Go is unaffected. A native build must
  re-cut the patch and re-verify scanning on Android.
- **Live rollup repair — still awaiting approval (NOT applied).** Audit shows
  `Sale create` ×28 on 2026-09-10 and ×4 on 2026-08-08 with no surviving sales
  (fixtures hard-deleted outside the app); rollups for those days overstate
  revenue by **388 340.00** (Home shows 328 300 profit). Procedure: backup per
  `docs/22` → `DB=phonestore node scripts/rollup-audit.js` (confirm exactly 2
  rows) → `… --repair`.

## 📋 Known, not fixed

- On web, a screen pushed from a tab announces its back button as "(tabs), back".
- A bottom sheet's Close button is 36 pt with no hit slop (app-wide, pre-existing).
- Dynamic type cannot be exercised in a web render; handset only.
- No catalogue images (`docs/47`). The pre-release security gate (`docs/48`) is
  not started. Owner decisions D4–D6 (hosting, database hosting, backups) block
  staging (`docs/45`); release risks in `docs/41` §6.

## The next exact action

1. On the iPhone (hotspot, Expo Go), run **`docs/24` §32 P1–P14** — the three ways to find a phone.
2. Then §31 M1–M21 and §30 / §30b–d.
3. Decide the live rollup repair.
