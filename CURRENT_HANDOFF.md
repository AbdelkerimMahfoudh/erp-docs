# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Active account / Owner: **CLAUDE-B**
- `started_at_utc:` `2026-08-25T00:00Z`
- **Authorised task — two approved changes.**
  **CP1** finalize login around **email or WhatsApp number** + password. No Store
  ID, no personal ID in the normal login experience.
  **CP2** record the two-step-verification direction — **build no fake toggle**.
  **CP3** complete app-wide **dark mode** from Settings, and move the language
  selector into the same preferences area.
  **Do not begin the IMEI scanner milestone.**
- HEADs at takeover — `erp-backend` `29f052d` · `erp-mobile` `ae712e9` ·
  `erp-docs` `f142d36`. All three clean and level with their remotes.

### Takeover verification — every claim checked

| Claim | Found |
|---|---|
| Store ID absent from the login screen | ✅ 2 `<Field>`s, no `storeId`/`storeAccountId` |
| Login accepts phone or personal ID | ✅ `classifyIdentifier` in `src/auth/identifier.ts` |
| Migration `0054` exists | ✅ `0054_personal_login_id`, 54 migration folders, 53 applied |
| Money is a bottom tab | ✅ `app/(tabs)/_layout.tsx` line 112 |
| Backend ≈91 suites / 1585 tests | ✅ **exactly** 91 / 1585, green |
| Mobile tsc + lint clean | ✅ tsc clean; lint clean but for the generated `.expo` warning |
| Expo Doctor 18/18 | ✅ |
| 18 pure suites | ✅ |
| 62 routes | ⏳ re-checked at close (export takes minutes) |
| EN/AR/FR ≈1731 keys | ✅ **exactly** 1731/1731/1731, identical order |
| `READY_FOR_HANDOFF`, owner `NONE` | ✅ |
| Trees clean and level | ✅ all three, 0 dirty, 0/0 vs remote |

**No discrepancy between the handoff and reality.** Two findings the handoff did
not contain, because nobody had asked the question yet:

1. 🔴 **Every active user would be locked out by CP1 as written.** All **5**
   active users (`owner`, `seller`, `Test`, `sales`, `warehouse`) have
   **neither an email nor a phone**. 0 of 5. Login restricted to email-or-phone
   locks out 100% of them. The four remaining accounts are inactive.
2. ⚠️ **`users.email` has no uniqueness constraint.** `phone` has
   `@@unique([companyId, phone])`; email has nothing. It cannot become a login
   identifier until it does — that is a migration.

### Next intended action

Present the plan, the files, and the risks for approval, per the rulebook's
"BEFORE EVERY MAJOR IMPLEMENTATION". Nothing is modified until then.

## Verification at close

| Check | Result |
|---|---|
| Backend suites | **91 suites / 1585 tests**, green |
| Backend `tsc -p tsconfig.build.json` | clean |
| Prisma validate / migrate status | valid · **53 migrations**, up to date |
| Database triggers | **21** |
| Mobile `tsc` | clean |
| Mobile lint | clean *(one warning in Expo's generated `.expo/types/router.d.ts` — pre-existing)* |
| Mobile pure suites | **18/18** — run with `node lib/<name>.test.ts`, **not jest** |
| **Expo Doctor** | **18/18, no issues** |
| Web export | **62 routes**, including `/money-hub`, `/money`, `/login`, `/sync` |
| EN/AR/FR parity | **1731 / 1731 / 1731**, identical order, nothing missing either way |
| Live CP3 (HTTP + MySQL) | **35/35** — see [`docs/35`](docs/35_AUTHENTICATION_IDENTITY_AUDIT.md) |
| Browser (EN/AR/FR, 1280×720 and 375×812) | Money tab and sign-in verified as Owner, Manager, Employee |

A tab route emits both a group and a bare route, so CP2's one new file added
two: 60 → 62 is expected, not drift.

### Demo integrity

Sales **7 / 10 051.00** — unchanged from the recorded baseline · **1** company ·
**9** users · **0** orphaned rows · audit **559** rows, grown and never deleted.

Every probe user and the probe company this session created were removed. The
scratch database `prisma_restore_cp3` was dropped; **no `prisma_*` database
remains**. `settingsprobe` and three `i2p9b1b04_*_spent` accounts survive from
earlier sessions — inactive, pre-existing, and left alone rather than deleted
without authorisation.

**Backup:** `phonestore-cp3-20260822-052409.sql` (in `~/erp-backups`), taken before migration `0054` and
restore-proven into `prisma_restore_cp3` per
[`docs/22`](docs/22_BACKUP_AND_ROLLBACK.md). The restore target had to be a
`prisma_*` name: the migrator account holds `ALL` on `phonestore` and
`prisma\_%` only.

**Ports:** the API on 3010 and the web preview on 8090 were started by this
session and have been stopped. The user's own Expo dev server on **8081** was
never touched.

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

**The IMEI scanner patch**, which this brief deliberately deferred, followed by
a physical-device QA and release-candidate pass. A–L is complete and the two
approved corrections have landed; what the product needs next is somebody
holding a cheap Android phone in a real shop, working through
[`docs/24`](docs/24_DEVICE_QA_CHECKLIST.md) from the top — the scanner rows and
the new sign-in rows especially.

Two things a next session should know before touching authentication:

1. **No user in the demo database has a phone number.** The account chooser is
   therefore unreachable in normal use and has only ever been exercised by
   probes. If it matters, give two users the same phone in different companies
   before testing it.
2. **`login` is still on the `users` table** and still used by the legacy
   lookups. Removing it is a separate migration and was deliberately not folded
   into a login change.

To run the app:

```bash
cd backend && npm run start:dev
```

```bash
cd mobile && npx expo start
```
