# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Active account / Owner: **NONE**
- `closed_at_utc:` `2026-08-27T12:00Z`
- **Authorised task — platform control, Phase 2. COMPLETE.** Approved pricing,
  the real public/customer/administration website, and mobile account creation
  and subscription-state handling. **The IMEI scanner milestone was not begun.**
- HEADs at close — `erp-backend` `7f12a08` · `erp-mobile` `d9d912d` ·
  `erp-docs` this commit · **`retail-erp-control-web` `ef71085` — local only.**
- HEADs at takeover were `cb69e0d` / `4728d5a` / `2004912`.

### 🔴 The one discrepancy, and it was mine

The prompt and my previous handoff both say **57 migrations**. There are **56**,
numbered `0001`..`0057` — **`0005` does not exist** and has not for a long
time. I wrote "57" last session by reading the highest number rather than
counting. With `0058` applied this session the count is now **57**, numbered to
`0058`. Nothing was ever missing.

### The website

```
C:\wamp64\www\PhoneStoreERP\retail-erp-control-web
```

**No remote is configured.** Every commit is local. A remote was not invented —
pushing product source to a repository nobody chose would be worse than waiting.
Add one when ready:

```bash
git -C retail-erp-control-web remote add origin <url>
```

Running it, and creating the first administrator, are in
[`docs/38`](docs/38_CONTROL_WEBSITE.md).

### The approved pricing, verbatim

One subscription per company · **500 MRU** per month per active branch · **two**
active staff accounts included per branch, **pooled company-wide** · **100 MRU**
per additional active non-Owner account · a multi-branch user counts **once** ·
the Owner is **never** charged · **no prorating** — an addition costs the whole
month immediately, a removal reduces only the next renewal · **no free trial** ·
**72-hour grace** · **integer MRU** throughout.

All five approved examples verified against the live server: 500 / 500 / 600 /
1 000 / 1 100 MRU.

### Three bugs the browser found that no test did

1. **Two outbox instances.** `useClass` made Nest build a second one, so the
   outbox that stored a verification code and the one later read were different
   objects — the code was silently never found. `useExisting` fixes it.
2. **`localhost` vs `127.0.0.1`.** The site's API base defaulted to
   `127.0.0.1` while the page was served from `localhost`, making the session
   cookie cross-site; `SameSite=Lax` correctly withheld it and every request
   came back 401 while the sign-in that set it looked fine. The base now follows
   the page's own hostname.
3. **A false claim in the copy.** "We sent a code to…" was shown while nothing
   had been sent. Corrected in all three languages.

### Verification

| Check | Result |
|---|---|
| Backend | **94 suites / 1650 tests** · tsc clean · Prisma valid · **57 migrations** |
| Enum audit | **69** MySQL enum columns, all declared Prisma enums; `STRICT_ALL_TABLES` refuses a bad value with 1265 |
| Mobile | tsc clean · lint clean *(pre-existing `.expo` warning)* · **19 pure suites** · **30 drift assertions** · Doctor **18/18** · **1752 keys** identical EN/AR/FR |
| Website | tsc clean (app and tests separately) · lint clean · **14 contract tests** · production build green · `npm audit` **0 vulnerabilities** |
| Live pricing | **16/16** against the real quote endpoint |
| Browser | registration end to end · admin sign-in · pending queue · activation by grant with **no payment row** · dark · Arabic RTL · French · 375px |

⚠️ **Browser verification is not device verification**, and nothing here was run
on a phone.

### Migration and backup

`0058_billing_plans` — additive. Backup
`phonestore-0058-20260825-091717.sql`, verified and restore-proven (81 tables,
9 users). Scratch database dropped.

### Dependencies added

Website only: `react-router-dom` (a real router) and `vitest`,
`@testing-library/react`, `@testing-library/user-event`, `jsdom` (tests).
**`npm audit`: 0 vulnerabilities.** No query library, no form library, no admin
template. Backend and mobile added **nothing** — `expo-linking` was already
present.

### Demo integrity

**1** company · **9** users · sales **7 / 10 051.00** · subscription still
`activated` · **0 billing periods and 0 subscription payments** — no history was
fabricated for it. The five contactless legacy users keep their hidden
personal-ID path.

### Cleanup

Probe companies, the probe administrator and verification rows removed; **audit
rows kept deliberately** (24). CORS reverted. Ports **3010, 5173, 8090, 8081 all
free**. No `prisma_*` database remains.

### Unresolved production work

Administrator **MFA** · a real **email/WhatsApp provider** · **Bankily** or
another payment provider · **domain, DNS and TLS**, cookie `secure` in
production · a deployment and security review. None is faked, and no toggle
pretends otherwise.

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

**A remote for the website**, then a physical-device pass.

```bash
git -C retail-erp-control-web remote add origin <url>
git -C retail-erp-control-web push -u origin master
```

Then work [`docs/24`](docs/24_DEVICE_QA_CHECKLIST.md) from the top on a real
phone — the Create-account handoff, the three subscription-state screens, and
the website in a phone browser have all been verified in a desktop browser and
**none of it on a device**.

Four things to know before touching this:

1. **The website computes no price.** Every figure is the server's, and a test
   refuses any component that multiplies a unit price.
2. **No credential may reach browser storage.** Exactly two keys are allowed,
   both preferences; a test enforces it.
3. **Plan versions are never retroactive**, and billing periods copy their unit
   prices. Editing a past price is not possible by design, not by convention.
4. **The five contactless legacy users still exist** and still rely on the
   hidden personal-ID sign-in. `docs/36` has the query that says when it can go.

To run everything:

```bash
cd backend && npm run start:dev
```

```bash
cd retail-erp-control-web && npm run dev
```

```bash
cd mobile && npx expo start
```

To create a platform administrator (never paste a real password anywhere):

```bash
cd backend && PLATFORM_ADMIN_PASSWORD='…' npx ts-node prisma/create-platform-admin.ts you@example.com "Your Name"
```
