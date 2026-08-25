# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Active account / Owner: **NONE**
- `closed_at_utc:` `2026-08-25T12:00Z`
- **Authorised task — two approved changes. COMPLETE.**
  **CP1** login finalised around email or WhatsApp number · **CP2** the
  two-step-verification direction recorded with **no fake toggle** · **CP3**
  complete app-wide dark mode with the language selector moved beside it.
  **The IMEI scanner milestone was not begun**, per the brief.
- HEADs at close — `erp-backend` `6347f96` · `erp-mobile` `4728d5a` ·
  `erp-docs` the commit carrying this snapshot. All three clean and pushed.
- HEADs at takeover were `29f052d` / `ae712e9` / `f142d36`.

### The finding that shaped CP1

🔴 **All five active users had neither an email nor a phone.** Audited before
any code changed. Login restricted to contacts would have locked out 100% of
the people using this system.

So the generated personal ID is **still accepted by the server and offered by
nothing** — not a field, hint, placeholder or documented way in, and a drift
test fails the build if it reappears on the login screen. It is a ramp, not a
feature. [`docs/36`](docs/36_LOGIN_CONTACT_TRANSITION.md) records the exact
condition for removing it:

```sql
SELECT COUNT(*) FROM users WHERE is_active = 1 AND deleted_at IS NULL AND email IS NULL AND phone IS NULL;
```

**Still 5 at close.** While it is above zero, removing the `personal_id` branch
from `classifyIdentifier` locks somebody out.

### What shipped

- **CP1** (backend `6347f96`, mobile `f86f61f`) — one field, "Email or WhatsApp
  number", plus a password. Migration `0055` gives email the **per-company**
  uniqueness phone already had, so one address at two shops still reaches the
  password-first chooser. Email case is the database's rule (`ai_ci`), not an
  invention. Enrolment and sign-in share one phone parser. Changing a login
  contact now asks the **actor** for their own password, ends the target's
  sessions, cannot strip a last contact, and is audited. New users need at least
  one contact — enforced in the service, so the seed and CLI cannot bypass it.
- **CP2** — nothing shipped, deliberately. A switch that saved a preference and
  protected nothing would be worse than its absence. A test refuses any 2FA UI.
- **CP3** (mobile `9a0b22a`, `1a12e5b`, `4728d5a`) — the palette was frozen and
  read inside module-scope `StyleSheet.create` in 46 files, so a runtime swap
  would have changed nothing, silently. Colour now resolves during render via
  `makeStyles`/`makeTokens`. Dark is not an inversion: success stays green,
  danger red, warning amber. Appearance & language is one screen under Account &
  security; the language selector **moved**, and a test asserts exactly one
  screen may render it.

### Nine defects found — six pre-existing in light mode

A warning button at 4.23:1 · a placeholder at 1.8:1, invisible in sunlight ·
hint text at 2.9:1 that the contrast test missed by only checking the card, not
the canvas · React Navigation's own `rgb(242,242,242)` behind every screen, the
largest surface in the app and invisible to a token audit because it is not in
the token layer · colour utility classes chosen at runtime, marking **selected**
state · a Tailwind class map interpolated into a template, putting
`text-slate-700` on the analytics figure at 1.7:1 on dark · React Native Web's
Material teal on an unstyled `Switch` · and one this change would have
introduced: `text.inverse` redefined for dark as "on a light fill" when all five
callers mean "on a brand button" — dark text on indigo would have shipped.

### Verification

- **Backend** 91 suites / **1604 tests** (up from 1585) · `tsc` clean · Prisma
  valid · **54 migrations**, up to date.
- **Mobile** tsc clean · lint clean but for the pre-existing generated
  `.expo/types/router.d.ts` warning · **19 pure suites** · **1738 keys** in
  EN/AR/FR with identical order · **Doctor 18/18** · web export **63 routes**.
- **22 live CP1 checks** against the running API and MySQL, all passing —
  sign-in by email and by number, non-enumeration across four failure kinds,
  ignored spoofed tenant headers, the shared-email chooser, the legacy path,
  per-company email uniqueness enforced by the database, and rate limiting.
- **Browser** — **19 routes swept in dark** with no light surface and no text
  under 3:1; light mode swept clean; AR→FR with the theme surviving, and the
  theme toggled with the language surviving; French at 375px with no overflow.
- ⚠️ **None of it is physical-device verified.** `docs/24` lists 22 new rows,
  and what still needs real hardware: cold-start flash, OLED legibility,
  sunlight, the camera overlay, keyboard appearance, and native RTL — which the
  web build cannot evidence, since it needs a relaunch to flip direction.

### Temporary changes — all undone

- `backend/.env` `CORS_ORIGINS`: the `:8090` entries removed; byte-identical to
  the pre-session backup.
- Probe users `cp1p*`, `cp3*` and the probe companies: deleted. **No `prisma_*`
  database remains.**
- Demo integrity unchanged: sales **7 / 10 051.00** · 1 company · 9 users ·
  audit **559** rows, grown and never deleted.
- ℹ️ `settingsprobe` and three `i2p9b1b04_*_spent` accounts still pre-date these
  sessions; inactive, left alone rather than deleted without authorisation.

### Ports

The API on **3010** and the web preview on **8090** were mine and are stopped.
I issued no command against **8081**: it was listening at takeover and is not
now, and I cannot account for that.

### Backup

`phonestore-cp1-20260825-035922.sql` in `~/erp-backups` — 514 KB, verified
("Dump completed"), taken before migration `0055` per
[`docs/22`](docs/22_BACKUP_AND_ROLLBACK.md).

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
