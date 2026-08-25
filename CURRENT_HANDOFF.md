# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Active account / Owner: **CLAUDE-B**
- `started_at_utc:` `2026-08-26T00:00Z`
- **Authorised task — the first testable platform-control website.** A public
  registration site, a customer subscription portal, and a private
  platform-administration portal, over the existing backend as the source of
  truth. Preserve contact login, dark mode, the Money tab and all A–L work.
  **Do not begin the IMEI scanner milestone.**
- HEADs at takeover — `erp-backend` `6347f96` · `erp-mobile` `4728d5a` ·
  `erp-docs` `0cb99da`. All three clean and level with their remotes.

### Baseline verified — every expectation matched exactly

| Expected | Found |
|---|---|
| Backend 91 suites / 1604 tests | ✅ exactly |
| Mobile tsc + lint clean | ✅ |
| 19 pure suites | ✅ |
| EN/AR/FR 1738 keys each | ✅ identical order |
| Expo Doctor 18/18 | ✅ |
| 63 routes | ✅ (re-checked at close) |
| Schema through `0055` | ✅ 55 migration folders, up to date |
| Clean, pushed, level | ✅ all three |
| `READY_FOR_HANDOFF`, owner `NONE` | ✅ |

### 🔴 The brief assumes a subscription contract that does not exist

The task describes extending a subscription engine that has plans, prices,
payments and a lifecycle. **Milestone K deliberately built almost none of that.**
Audited in the schema and `entitlement-rules.ts`, not inferred:

1. **There is no `pending_activation` state.** The states are
   `active | grace | expired | complimentary`. A company with
   `currentPeriodEnd = NULL` computes as **`expired`** — reads allowed, writes
   blocked. Functionally that is close to "pending", but a brand-new business
   would be told its subscription had *expired*, which is a lie about a shop
   that never had one.
2. **There is no `suspended` or `cancelled` state.** `Company.isActive` is the
   only thing resembling suspension, and it is checked at login.
3. **There is no Plan model and no pricing anywhere on the server.** The
   canonical decision (`docs/21`, Milestone K) is *"there is one functional
   plan… nothing here is a feature tier"*. So a **"server-calculated price
   breakdown" has nothing to calculate from** — no plan price, no per-seat
   charge, no currency amount exists in the subscription domain at all.
4. **`Payment` is a SALE payment**, not a subscription payment — it carries
   `sale_id` and belongs to the till. There is no subscription-payment model.
5. **Platform administration is a shared KEY, not accounts.**
   `provisioning.controller.ts` is `@Public()` plus a `PLATFORM_ADMIN_KEY`
   check. There are no administrator accounts, sessions, revocation or step-up
   confirmation — and the `administrator` `RoleKey` that does exist is
   **tenant-scoped**, which is precisely what the brief forbids.
6. **There is no registration endpoint** and **no contact-verification delivery
   adapter** of any kind.
7. **No web project exists.** Package manager is **npm** (`package-lock.json` in
   both repos). A new repository will have **no configured remote**.

**Per the brief, current server behaviour stays canonical** until a separate
product decision changes it. The gap is real and is a contract gap, not a
missing screen — so it needs a written decision, not an invented price list.

### Next intended action

Present the plan, the files, and the risks for approval, per the rulebook's
"BEFORE EVERY MAJOR IMPLEMENTATION". Nothing is modified until then.

## Verification at close

| Check | Result |
|---|---|
| Backend suites | **91 suites / 1604 tests**, green |
| Backend `tsc -p tsconfig.build.json` | clean |
| Prisma validate / migrate status | valid · **54 migrations**, up to date |
| Database triggers | **21** |
| Mobile `tsc` | clean |
| Mobile lint | clean *(one warning in Expo's generated `.expo/types/router.d.ts` — pre-existing)* |
| Mobile pure suites | **19/19** — run with `node lib/<name>.test.ts`, **not jest** |
| **Expo Doctor** | **18/18, no issues** |
| Web export | **63 routes** — 62 plus `/appearance` |
| EN/AR/FR parity | **1738 / 1738 / 1738**, identical order |
| Live CP1 (HTTP + MySQL) | **22/22** — see [`docs/36`](docs/36_LOGIN_CONTACT_TRANSITION.md) |
| Browser, dark | **19 routes** swept: no light surface, no text under 3:1 |
| Browser, light | swept clean |
| Browser, languages | AR→FR with the theme surviving; theme toggled with the language surviving |

### Demo integrity

Sales **7 / 10 051.00** — unchanged · **1** company · **9** users · audit **559**
rows, grown and never deleted. Every probe user and probe company this session
created was removed; **no `prisma_*` database remains**.

**Backup:** `phonestore-cp1-20260825-035922.sql` in `~/erp-backups` — 514 KB,
verified, taken before migration `0055` per
[`docs/22`](docs/22_BACKUP_AND_ROLLBACK.md).

**Ports:** 3010 and 8090 were mine and are stopped. No command was issued
against 8081.

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

**The IMEI scanner milestone**, which this brief deliberately deferred, then a
physical-device QA and release-candidate pass through
[`docs/24`](docs/24_DEVICE_QA_CHECKLIST.md).

Three things a next session should know:

1. **Five active users still have no contact.** The legacy personal-ID sign-in
   cannot be removed until that count reaches zero — the query is in
   [`docs/36`](docs/36_LOGIN_CONTACT_TRANSITION.md). Enrol real contacts through
   `PATCH /v1/users/:id`; **never invent an address for a real user**, because
   one nobody owns is worse than none.
2. **The theme audit is a source audit.** `node lib/design/theme.test.ts`
   refuses a module-scope colour sheet, a static palette import, a raw hex or
   `rgba`, a ramp step used as a surface, a colour utility class, and an
   `isDark ?` branch in a screen. If it fails, the screen is stuck in one theme
   — that is the point, not pedantry.
3. **The web build cannot evidence RTL or a cold-start flash.** Direction needs
   a relaunch there, and there is no native splash. Both need a device.

To run the app:

```bash
cd backend && npm run start:dev
```

```bash
cd mobile && npx expo start
```
