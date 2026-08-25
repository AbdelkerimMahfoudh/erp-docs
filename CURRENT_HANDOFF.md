# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Active account / Owner: **NONE**
- `closed_at_utc:` `2026-08-26T12:00Z`
- **Authorised task — the first testable platform-control platform.**
  Scoped, with the user's agreement, to the **backend contract first**; the three
  web surfaces are built next session on a proven contract. Contact login, dark
  mode, the Money tab and all A–L work are untouched. **The IMEI scanner
  milestone was not begun.**
- HEADs at close — `erp-backend` `cb69e0d` · `erp-mobile` `4728d5a`
  (unchanged) · `erp-docs` the commit carrying this snapshot.
- HEADs at takeover were `6347f96` / `4728d5a` / `0cb99da`.

### 🔴 The brief assumed a subscription engine that did not exist

Audited in the schema and `entitlement-rules.ts` before any code changed.
Milestone K deliberately built almost none of it:

- no `pending_activation`, `suspended` or `cancelled` — only
  `active | grace | expired | complimentary`, all derived from dates;
- **no Plan model and no price anywhere on the server**;
- `Payment` is a **till** payment carrying `sale_id`, not a subscription one;
- platform administration was a shared `PLATFORM_ADMIN_KEY` on a `@Public()`
  controller — no accounts, sessions or revocation;
- no registration endpoint, and no contact-delivery adapter of any kind;
- no web project, and npm as the package manager.

**Two decisions were taken by the user before building:** show no money at all
this checkpoint, and do the backend contract first.

### What shipped

- **Lifecycle** — `subscriptions.status` records where an administrator has
  *put* a subscription. Default `activated` means "the dates decide", exactly
  how every existing row behaved, so nothing changed for the demo tenant.
  `pending` and `suspended` close the operational app; **expiry still hides
  nothing**, and the account surface stays readable in every state.
- **Registration** — company, branch, Owner and a pending subscription in one
  transaction, idempotent on a client key, every identifier server-generated.
  At least one contact required. No free trial.
- **Administrators** — their own table with no `company_id`, HttpOnly-cookie
  sessions, step-up password confirmation, revocation, CLI-only creation with
  the password from the environment. No default credential in the repository.
- **Grants vs payments** — separate tables, separate acts. A grant creates no
  payment row; every payment response carries `providerVerified: false`.
- **No money computed anywhere.** The dashboard returns `revenue: null`
  deliberately.

Full architecture, and why each deferred piece waits, in
[`docs/37`](docs/37_PLATFORM_CONTROL.md).

### The live check found four bugs no unit test could

1. `recordFor` omitted `status`, so a **pending business read as EXPIRED**.
2. **Every administrator route 401'd a valid session** — the global tenant guard
   runs first and looks for a shop's JWT.
3. **`/entitlement` blocked itself** — the endpoint that tells the app it is
   pending.
4. **`subscription_events.kind` is an ENUM** carrying only Milestone K's
   vocabulary, while `schema.prisma` called it a `String`. With this server's
   **empty `sql_mode`** every new kind was accepted by Prisma and silently
   coerced to `''`. The row was created, the request succeeded, and only reading
   it back showed the kind was gone.

### Verification

- **Backend** 93 suites / **1625 tests** (up from 1604) · tsc clean · Prisma
  valid · **57 migrations**, up to date.
- **Mobile** untouched this session; last verified at 19 pure suites, 1738 keys,
  Doctor 18/18, 63 routes.
- **36/36 live HTTP/MySQL checks** — the full lifecycle, isolation, the audit
  timeline, redaction and revocation.
- ⚠️ **Nothing is physical-device verified**, and there is **no browser
  verification** this checkpoint because no web surface was built.

### Migrations and backups

| | |
|---|---|
| `0056_platform_control` | after `phonestore-platform-20260825-070312.sql` |
| `0057_subscription_event_kinds` | after `phonestore-0057-20260825-083428.sql` |

Both dumps verified. `0056` was restore-proven (75 tables, 9 users, 7 sales) and
all 56 migrations were replayed from empty into a disposable database — 81
tables, 24 triggers — with constraints exercised directly in MySQL. Every
scratch database dropped.

### Dependencies

**None added.** `cookie-parser` was considered and refused: reading one cookie
is eight lines, and a dependency plus its types, advisories and global
middleware is a worse trade.

### Cleanup and demo integrity

Probe companies and the probe administrator removed. **Audit rows kept
deliberately** — actor text survives the admin row. Ports 3010, 8090 and 8081
all free. No `prisma_*` database remains.

Demo unchanged: **1 company · 9 users · sales 7 / 10 051.00 · audit 559** ·
demo subscription still `activated`. The five contactless legacy users keep
their hidden personal-ID path; the count is still **5**.

### Unresolved production-security work

Administrator **MFA** · a real **contact-delivery provider** · a **payment
provider** · a deployment review (TLS, cookie `secure`, where the portal is
reachable from). None is faked, and no toggle pretends otherwise.

## Verification at close

| Check | Result |
|---|---|
| Backend suites | **93 suites / 1625 tests**, green |
| Backend `tsc -p tsconfig.build.json` | clean |
| Prisma validate / migrate status | valid · **57 migrations**, up to date |
| Database tables / triggers | **81** / **24** |
| Live platform lifecycle (HTTP + MySQL) | **36/36** — see [`docs/37`](docs/37_PLATFORM_CONTROL.md) |
| Mobile | **untouched this session** — last verified 19 pure suites, 1738 keys, Doctor 18/18, 63 routes |
| Control website | **not built** — scoped to the next session by agreement |
| Browser verification | **none this checkpoint**, because no web surface exists yet |

### Demo integrity

**1** company · **9** users · sales **7 / 10 051.00** · audit **559** rows ·
demo subscription still `activated`. Every probe company and the probe
administrator were removed; **platform audit rows were kept deliberately**.

The five contactless legacy users keep their hidden personal-ID path. The count
is still **5**, and registration can no longer create a sixth — it requires a
contact.

**Ports:** 3010, 8090 and 8081 are all free. No `prisma_*` database remains.

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

**Build the web project**, on the contract this checkpoint proved.

One React + TypeScript application (Vite, npm — the workspace's package
manager), three strictly separated areas: public registration, the customer
portal, and platform administration. It will need its **own repository**, and
will have **no configured remote** until one is created — record that rather
than pushing anywhere else.

The endpoints it consumes all exist and are live-verified:

```
POST /api/v1/platform/register            public, idempotent
POST /api/v1/platform/admin/sign-in       public, rate-limited, sets HttpOnly cookie
GET  /api/v1/platform/dashboard           admin
GET  /api/v1/platform/businesses[/:id]    admin
GET  /api/v1/platform/pending             admin
POST /api/v1/platform/businesses/:id/{activate-grant,extend,suspend,reinstate,cancel,payments}
GET  /api/v1/platform/audit               admin
GET  /api/v1/entitlement                  tenant — readable in EVERY state
```

Four things the next session should know before starting:

1. **Show no money.** The server computes none, and the dashboard returns
   `revenue: null` on purpose. Any figure on a screen would be invented.
2. **High-impact actions need `confirmPassword`** in the body, and send
   `expectedVersion` — a stale version returns **409** and the UI must refresh
   to the winning state rather than retrying blindly.
3. **Never put the admin session in `localStorage`.** It is an HttpOnly cookie;
   the browser sends it. The bearer fallback exists only outside production.
4. **Mobile integration waits for a signup URL.** The `Create account` link and
   the pending/suspended status screens land once there is a site to point at —
   shipping dead UI would be worse than waiting.

To run the app:

```bash
cd backend && npm run start:dev
```

To create an administrator to sign in with:

```bash
cd backend && PLATFORM_ADMIN_PASSWORD='…' npx ts-node prisma/create-platform-admin.ts you@example.com "Your Name"
```
