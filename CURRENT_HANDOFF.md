# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Active account / Owner: **NONE**
- Last account: **CLAUDE-B** · closed `2026-08-17T21:58Z`
- Completed this session: **Milestones H and I**, both shipped and verified.
- **Milestone J was not begun**, as instructed.

### Repository state — all three clean and pushed

| Repository | HEAD |
|---|---|
| `erp-backend` | `2effbf3` |
| `erp-mobile` | `ad5a185` |
| `erp-docs` | *this commit* |

---

## Milestone H — inter-store consignment: COMPLETE

| Step | State | Commit |
|---|---|---|
| **H0** truth audit — what may cross a tenant boundary | ✅ | docs `31` |
| **H-CP1** migration `0049`, 11 permissions, scope helper | ✅ | backend |
| **H-CP2** discovery and connections | ✅ | backend |
| **H-CP3** lifecycle, reservation, custody | ✅ | backend |
| **H-CP4** money, disposition and the return | ✅ | backend |
| **H-CP5** mobile: stores, consignments, detail | ✅ | mobile `8db05d5` |
| **H-CP6** live **71/71** across two temporary companies | ✅ | — |

**The architectural decision the brief made binding:** consignment does **not**
extend `StockTransfer` — not the model, routes, permissions or lifecycle. The
previous session's log had recommended the opposite; that recommendation was
overruled, correctly. A transfer moves stock between two branches of one
company. A consignment moves it between two companies that must never see each
other's books, and reusing a structure whose every query assumes a single tenant
is the kind of economy that leaks.

**Privacy is structural.** `consignment_lines` has no cost column at all, so the
receiving company's API cannot select what does not exist. A screen cannot leak
what it never receives.

**Discovery cannot be used as a directory.** Every reason a store is absent from
search — not discoverable, inactive, blocked you, does not exist, is you —
produces the identical empty answer.

---

## Milestone I — money loans: COMPLETE

| Step | State | Commit |
|---|---|---|
| **I0** audit of reusable primitives | ✅ | docs `31` |
| **I-CP1** migration `0050`, `loan-rules.ts` (31 tests) | ✅ | backend |
| **I-CP2** service, DTOs, controller, module | ✅ | backend `b35dce3` |
| **I-CP3** mobile loan screens + the closing reminder | ✅ | mobile `ad5a185` |
| **I-CP4** live **53/53** across two temporary companies | ✅ | — |

**Loans are a separate module**, not a consignment with the unit left out.

**Direction is explicit data, never a sign.** One row reads `they_owe_us` to one
shop and `we_owe_them` to the other, and who may act follows the direction
rather than authorship — so the debtor cannot confirm their own repayment even
holding every permission. Verified live from two authenticated sessions.

**A report moves nothing.** `payment_reported` has a balance effect of zero.

---

## Verification at close

| Check | Result |
|---|---|
| Backend suites | **87 suites / 1485 tests**, green |
| Backend `tsc` | clean |
| Prisma validate / migrate status | valid · **49 migrations**, up to date |
| Database triggers | **19** |
| Mobile `tsc` | clean |
| Mobile lint | clean *(one warning remains in Expo's generated, git-ignored `.expo/types/router.d.ts`)* |
| Mobile pure suites | **8/8** — run with `node lib/<name>.test.ts`, **not jest** |
| Expo web export | all routes bundle, including `/loans`, `/loans/new`, `/loans/[id]`, `/consignments/new` |
| Expo Doctor | 17/18 · three **patch** version drifts (`expo`, `expo-constants`, `expo-file-system`), pre-existing, not introduced here |
| EN/AR parity | **1575 / 1575**, no key missing either way, no duplicates |
| Live H | **71/71** |
| Live I | **53/53** |

### Demo data, after full cleanup

Sales **7 / 10 051.00** · unit checksum **`2a1dc9bf284afde32b402ad108d38a76`**
(unchanged) · **1** company · zero rows left in `loans`, `loan_ledger`,
`consignments`, `consignment_lines` or `store_connections`. Audit rows were
**preserved, not deleted** — the count only grows.

Both temporary companies were removed. **No permanent company or identity was
left behind.**

### Loan permissions as actually granted in the database

| Role | Keys |
|---|---|
| Owner | view, manage, payment.report, payment.confirm, forgive |
| Store manager | view, payment.report |
| Employee | **none** |

No role below Owner holds `loan.forgive`. Verified against the database, not the
migration file.

---

## Two defects found during this session, both fixed

1. **`consignments.service.create()` wrote lines before the parent row**, so the
   foreign key failed on every real request. The entire unit suite passed,
   because none of it touches a database. Fixed by creating the parent first
   inside the same transaction.
2. **`awaitingConfirmation` counted reports that had already been confirmed**, so
   a settled payment showed as still in the air forever and the shop would chase
   money it already had. Found while checking a response shape, not by a test.
   Answered-ness now comes from the explicit `refersToId` link; three tests pin
   it. Backend `2effbf3`.

**One gap closed on the way past:** `consignments/new` was linked from the H list
screen but never built — the button reached an unmatched route. It exists now,
camera-first, resolving every scanned code against the server before it joins
the list. Two stale lint warnings from G and G2A were also cleared.

---

## Known state and risks

- **Device testing is outstanding.** Everything in
  [`docs/24`](docs/24_DEVICE_QA_CHECKLIST.md) under Milestones H and I needs two
  accounts on two devices, and none of it can be answered from a simulator. The
  properties most worth a human eye: whether "they owe us" / "we owe them" are
  unambiguous at a glance in Arabic RTL, and whether a first-week employee
  understands that reporting a payment is not the same as being paid.
- **Servers were left running for the user's own testing** — backend on `3010`
  (watch mode), Metro on `8081` (`exp://192.168.100.3:8081`). These are the
  user's processes and were deliberately **not** stopped. Stop them yourself if
  you need the ports.
- No scratch database was created this session. All live testing ran against the
  shared database using temporary companies, created and removed within each run.
- Test scripts live outside every repository working tree, in the OS temporary
  directory, per the G2A-CP4.5 rule.

## Next action

**Milestone J — the offline foundation.** Not started, and not to be started
without the user's go-ahead. It is comparable in size to E or H and touches
architecture rather than a single feature, so it wants a session with room to
finish it.

Before J begins, the open question worth settling: whether offline write queuing
covers only the sell path or every mutation. The idempotency keys (`clientUuid`)
that H and I both use were built with queuing in mind, so the primitive exists —
what is undecided is the scope.

K (subscription entitlement) and L (analytics polish) remain untouched.
