# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Active account / Owner: **NONE**
- Last account: **CLAUDE-B** · closed `2026-08-19T00:15Z`
- **`A_L_COMPLETE`** — Milestones **A through L** are done.
- Completed this session: **J.1** (offline drafts), **K** (subscription
  entitlement), **L** (analytics), and the full A–L verification gate.

### Repository state — all three clean and pushed

| Repository | HEAD |
|---|---|
| `erp-backend` | `61d7e14` |
| `erp-mobile` | `308685a` |
| `erp-docs` | *this commit* |

---

## Verification at close

| Check | Result |
|---|---|
| Backend suites | **89 suites / 1560 tests**, green |
| Backend `tsc` | clean |
| Prisma validate / migrate status | valid · **51 migrations**, up to date |
| Database triggers | **21** |
| Mobile `tsc` | clean |
| Mobile lint | clean *(one warning in Expo's generated, git-ignored `.expo/types/router.d.ts`)* |
| Mobile pure suites | **11/11** — run with `node lib/<name>.test.ts`, **not jest** |
| **Expo Doctor** | **18/18, no issues** — the three patch shortfalls are fixed |
| Web export | every route bundles, including `/money`, `/sync`, `/subscription`, `/loans`, `/consignments/new` |
| EN/AR parity | **1690 / 1690**, nothing missing either way, no duplicates |
| Live J · K · L | **35/35** · **59/59** · **41/41** |

### Demo integrity

Sales **7 / 10 051.00** · unit checksum **`2a1dc9bf284afde32b402ad108d38a76`**
(unchanged) · **1** company · **0** orphaned rows in any table · audit **554**
rows, preserved and grown, never deleted. Every temporary company from every
live run was removed; **no permanent company or identity was left behind**.

No scratch database was created. All live testing used temporary companies
inside the shared database, created and removed within each run.

**Backup:** `phonestore-k-20260818-061410.sql` — 496 KB, 19 triggers captured,
taken before migration `0052` per [`docs/22`](docs/22_BACKUP_AND_ROLLBACK.md).

**Ports:** nothing is running. The API on 3010 was started by this session for
live verification and has been stopped; Metro was never started.

---

## Entitlement and grace semantics (K)

States are derived from a **server clock**, never the device:

| State | Meaning | Writes |
|---|---|---|
| `active` | Paid period running | ✅ |
| `grace` | Exactly **72 hours** past the period end, **derived** from it so the two cannot drift | ✅ |
| `expired` | Grace over | ❌ |
| `complimentary` | Platform grant, audited, never self-grantable | ✅ |

**Writes continue through grace** — a shop three hours past renewal is still
open, and refusing its sales over an administrative boundary would cost it real
money.

### What expiry does and does not do

Authentication works · history reads · exports work · branch selection and
sign-out work · the subscription screen explains itself. **Nothing is deleted or
hidden.** Only new business truth stops, refused with the stable code
**`ENTITLEMENT_WRITE_BLOCKED`** — the app never parses English.

### Queue behaviour after expiry

The entitlement refusal is **non-transient**. A queued report that hits it moves
straight to `needs_attention` and **stops**. It cannot loop, because retrying
cannot resolve the condition, and a phone quietly retrying forever is both a
battery problem and a lie about progress.

### Seats

500 MRU per subscribed branch · **2 included non-Owner seats per branch, pooled
company-wide** · Owner consumes none · extra seats 100 MRU, not prorated · no
trial · annual deferred.

**Nobody is ever deactivated automatically.** A company over its limit keeps
every employee, is told, is blocked from adding more, and decides for itself who
stays. Seats are checked at the moment of activation, so two Owners filling the
last place at once cannot both succeed. Deactivating is never blocked, or a
company would be trapped over its limit.

**A tenant Owner cannot self-grant.** Provisioning skips the tenant JWT guard
and is gated on a platform key no tenant holds; an unset key **closes** the
surface rather than opening it.

---

## Analytics accounting dictionary (L)

Seven categories, kept visibly apart: **profit · cash · liability · receivable ·
inventory · discrepancy · workflow**.

| Event | Profit | Cash |
|---|---|---|
| Sale | ✔ | ✔ |
| **Return approved** | ✔ revenue out **and** COGS credited | — |
| Refund reported | — | — |
| **Refund confirmed** | **✗ already counted at approval** | ✔ |
| Purchase received | ✗ | — (creates a payable) |
| Supplier payment confirmed | ✗ | ✔ |
| Expense confirmed | ✔ | ✔ |
| Consignment disposition | ✔ | — |
| **Loan / consignment principal** | **✗ never revenue or expense** | ✔ |
| **Closing discrepancy** | **✗ a question, not a loss** | ✗ |

**Never manufacture a figure.** A metric with no canonical source is *named as
unavailable*, not defaulted to zero — a shop cannot tell a measured zero from a
number nobody calculated. Reported this way: refund liability, supplier
liability, commissions and fees, per-channel expected movement, unattributed
legacy payments.

**Comparison** is against the immediately preceding period of equal length,
sharing no day with it. A zero base returns **unavailable**, never infinity and
never a percentage.

---

## Unresolved — device-only, and unrun

**Every device check in [`docs/24`](docs/24_DEVICE_QA_CHECKLIST.md) under
Milestones H, I, J, J.1, K and L is unrun.** They need real hardware:

- airplane mode, Wi-Fi with no internet, a stopped API
- a real Android low-memory kill with drafts pending, and process eviction
- reconnect, background/foreground, and that neither triggers OTP
- two accounts on two devices for consignment, loans and privacy
- the shared counter phone: sign out, sign in as somebody else, sign back
- Arabic RTL across every new screen
- whether a first-week employee reads "waiting to send" as anything but *sent*

**No claim is made about any of them.**

## Remaining product and release risks

1. **React Query caches are memory-only.** A cold start offline shows empty
   lists rather than stale ones. Deliberate: a persister showing stale prices
   and stale stock confidently is its own kind of lie, and it belongs in a
   milestone that can think about staleness properly.
2. **No user-creation route exists** — only `PATCH /users/:id`. Seat enforcement
   therefore binds on reactivation, which is the only seat-consuming path there
   is. When invitations arrive, they must call the same check.
3. **Refund and supplier liabilities have no single canonical total.** They are
   reported as unavailable rather than computed a second way. If a shop needs
   them as figures, they need a canonical owner first.
4. **`npm audit` reports 24 vulnerabilities (10 moderate, 14 high)** in the
   mobile dependency tree, pre-existing and untouched by this session. Not
   assessed. Worth a look before a release candidate.
5. **Commissions and fees have no model at all.** Nothing about them is
   reported, and adding them is a schema decision, not a reporting one.

## Next action

**A physical-device QA and release-candidate pass.** Not more feature
development — A–L is complete, and what the product now needs is somebody
holding a cheap Android phone in a real shop, working through
[`docs/24`](docs/24_DEVICE_QA_CHECKLIST.md) from the top.

To run the app:

```bash
cd backend && npm run start:dev
```

```bash
cd mobile && npx expo start
```
