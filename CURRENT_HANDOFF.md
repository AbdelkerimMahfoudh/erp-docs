# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Active account / Owner: **NONE**
- `closed_at_utc:` `2026-08-24T00:00Z` (session ran 2026-08-22 → 2026-08-24)
- **Authorised task — two approved product corrections. COMPLETE.**
  **CP1** the web sign-in crash · **CP2** the Money hub into bottom navigation ·
  **CP3** Store-ID login replaced by one identifier field. Every completed
  workflow, milestone N's More reorganisation, and the pending IMEI scanner
  requirements were preserved. **The scanner patch was not begun**, per the brief.
- HEADs at close — `erp-backend` `29f052d` · `erp-mobile` `ae712e9` ·
  `erp-docs` the commit carrying this snapshot. All three clean and pushed.
- HEADs at takeover were `03a73e9` / `283b5d7` / `3e876a4`.

### What shipped

- **CP1** (mobile `9e665c7`) — every filesystem entry point asks the platform
  before constructing anything native, and a source-shape test enforces that
  ordering rather than trusting a guard to stay in front. Web is **explicitly
  online-only**: `enqueue` refuses rather than accepting work a closed tab would
  erase, and Sync Center says so in words. No fallback store was invented (a
  test refuses one), and no dependency was added.
- **CP2** (mobile `f488829`) — the bar is Home · Sell · **Money** · Inventory ·
  More. The complete hub moved (Cash & accounts, Expenses, Daily closing,
  Loans) via one registry field, so the More card disappears in the same edit
  that creates the tab. Permission-driven, **not** Owner-only. No header, so no
  `(tabs)` back label. `/hub/money` redirects; Cash & accounts keeps `/money`.
- **CP3** (backend `751730c`, `29f052d`; mobile `82dbda4`, `ae712e9`) — sign-in
  is one identifier (phone **or** generated personal ID) and a password. Tenant
  resolution moved from the client to the credential. Migration `0054` adds
  `users.personal_id CHAR(10) NOT NULL UNIQUE` and backfills every user. One
  phone at two shops returns a 120s purpose-bound continuation token and a
  picker — **only after the password matches**.
- **Two defects found by looking, not by testing.** The login screen shipped a
  real store code (`F62B8-D1EEB`) and the login `owner` as placeholders, both
  readable in the bundle; and Settings told Owners "your staff type this when
  they sign in" about the Store ID, caught in the browser. Both fixed, the
  first now pinned by a drift test.

### Verification

- **Backend** 184/184 in the auth and users suites; `tsc -p tsconfig.build.json`
  clean.
- **Mobile** tsc clean · eslint clean apart from the pre-existing generated
  `.expo/types/router.d.ts` warning · **18 pure suites** · **1731 i18n keys** in
  EN/AR/FR with identical order · web export **62 routes**.
- **35 live checks** against the running API and MySQL, all passing — sign-in by
  both identifier kinds, non-enumeration, ignored spoofed headers, the chooser
  ordering, session/logout, identifier uniqueness under 40 concurrent creations,
  and rate limiting. Detailed in [`docs/35`](docs/35_AUTHENTICATION_IDENTITY_AUDIT.md).
- **Browser** — Money tab and login screen in EN, AR and FR, at 1280×720 and
  375×812, as Owner (4 children), Manager (4) and Employee (2, and still gets
  the tab). Five labels survive 130% text with no sideways scroll.
- ⚠️ **None of this is physical-device verified.** `docs/24` lists 19 new rows
  and what still needs real hardware.

### Temporary changes — all undone

- `backend/.env` `CORS_ORIGINS`: the `:8090` entries removed; the line is now
  byte-identical to the pre-session backup.
- Probe users `cp1probe`, `cp3own`, `cp3emp`, `cp3off`, `cp3twin`, `cp3mgr`,
  `cp3emp2` and the probe company `CP3 Probe Shop`: deleted.
- Scratch database `prisma_restore_cp3`: dropped. No `prisma_*` database remains.
- ℹ️ `settingsprobe` and three `i2p9b1b04_*_spent` accounts remain in the demo
  database. They **pre-date this session**, are inactive, and were left alone
  rather than deleted without authorisation.
- ⚠️ The user's own Expo dev server on **8081** was never touched. The API on
  3010 and the web preview on 8090 were mine.

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
