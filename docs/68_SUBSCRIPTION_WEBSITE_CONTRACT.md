# 68 — The subscription website: API and UX contract (v1.0, 2026-10-05)

> **Status: a contract, not a product.** No website is built in this phase, no repository was created, nothing is
> deployed. The website described here is where a business acquires, pays for, renews and administers its access to
> the ERP, and where the platform's own people (the Super Admin) approve, extend, suspend, refuse and audit. The
> customer mobile app only **reads** the server's business-access state and shows it in neutral words — see §9 and
> [`docs/21`](21_PRODUCT_DECISIONS.md) (2026-10-05). The backend is the single source of truth for every figure and
> every decision; the website computes nothing and decides nothing.
>
> **Supersedes** the commercial behaviour of the Phase-2 website described in [`docs/37`](37_PLATFORM_CONTROL.md) and
> [`docs/38`](38_CONTROL_WEBSITE.md) where the two differ; those documents stay as the record of why the backend is
> shaped as it is. The schemas below are those of backend `reports-export` at the commit recorded in
> `CURRENT_HANDOFF.md`; the DTOs in `src/platform/platform.controller.ts` are authoritative if this page ever drifts.

## 0. The decision this contract serves

The ERP is a business-to-business service for shops. The mobile app must not contain a price, an employee-seat price, a
purchase or renewal action, a payment form, a Bankily instruction, an external payment link, a website link whose
purpose is purchasing or renewing, a call to action such as *Subscribe*, *Buy* or *Pay now*, a plan selection, branch
billing controls, paid-seat management or an App Store in-app purchase. Subscription acquisition, payment, renewal and
billing management happen on the website; the app consumes the resulting server-controlled entitlement.

## 1. The commercial rules the website implements (approved; unchanged)

| Rule | Value | Where it lives today |
|---|---|---|
| Scope | One subscription **per company**, priced **per subscribed branch** — every active branch is a subscribed branch. (The brief of 2026-10-05 says "one subscription per branch"; the approved record of Phase 2 says "one subscription per company, 500 MRU per active branch". They describe the same thing from two sides: the company holds one subscription row carrying the branch count. **The owner is asked to confirm this reading — `docs/21`, 2026-10-05.**) | `subscriptions` (one row per company, `subscribed_branch_count`) |
| Base price | **500 MRU per branch per month** | `plan_versions` (Standard v1), `src/billing/pricing-rules.ts` |
| Included staff | **2 non-Owner accounts per branch, pooled company-wide**; the Owner is never counted | `entitlement-rules.ts` (`SEATS_PER_BRANCH`), `pricing-rules.ts` |
| Additional staff | **100 MRU per month each** | `plan_versions`, `pricing-rules.ts` |
| Mid-month changes | An account or a branch added during the month is charged for the **whole month**; a removal reduces only the next renewal (no prorating, high-water mark per component) | `billing_periods`, `assessPeriod()` |
| Free trial | **None** | registration creates `pending_activation`; nothing is granted |
| Grace | **72 hours** after the period end, derived from the period, never stored | `entitlement-rules.ts` (`GRACE_HOURS`) |
| Approval | **Every new business is approved by the Super Admin**, who assigns the initial access period and may extend, correct, suspend, reinstate, refuse or end it | `SubscriptionLifecycleService` |
| Bankily | May later be integrated **on the website**; **not operational** in this phase — no provider is called, no instruction is served | `payment-instructions.ts` (`available: false`) |
| WhatsApp | May later deliver codes and notices; **not operational** in this phase | `WHATSAPP_CHANNEL=disabled` |
| Prices | Belong to the website, the backend's commercial contract and the Super Admin tools — **never** to customer-facing mobile responses or UI | `GET /entitlement` carries no figure; the mobile app never calls a commercial route |

Integer MRU throughout; no float touches an amount. A period's unit prices are **copied** into `billing_periods` when it
opens, so a price scheduled later never rewrites what a shop was told.

## 2. Actors, realms, sessions

| Actor | Credential | Realm | What it may touch |
|---|---|---|---|
| Anybody | none | public | the product explanation, sign-in, the business-request flow (§3.2), the invitation acceptance |
| A business's **Owner** | the tenant sign-in they already have (email or WhatsApp number + password); on the website either a bearer token held in memory for the visit, or the `portal_session` HttpOnly cookie minted from the app's one-time ticket (`docs/38`) | tenant (`/api/v1/...` with the tenant JWT) | **their own** business only: status, period, grace, quote, history; later payment initiation and status |
| A **Manager** or **Employee** | the same kind of sign-in | tenant | nothing on the website: the account surface is the Owner's (`portal-handoff` is gated on `settings.manage`; the website's `/account` should refuse non-Owner sessions rather than show them a price) — **a tightening the website must apply; `my-subscription` itself answers any tenant session today** |
| The **Super Admin** (platform administrator) | `platform_admins` row, created only by CLI (`prisma/create-platform-admin.ts`); an **HttpOnly, SameSite=Lax, Secure-in-production** cookie session; every high-impact action re-asks the password | platform (`/api/v1/platform/admin/*`, `/platform/businesses/*`, `/platform/plans`, `/platform/audit`) | every business, never a shop's takings (the queries cannot return sales, IMEIs, costs or margins) |

The two authenticated realms are structural: a tenant JWT is refused by every administrator route (401) and the
administrator cookie is refused by every tenant route (401) — proven over HTTP on 2026-10-05 (the matrix, §10).

## 3. The public and business side

### 3.1 Pages

| Page | Purpose | Reads | Writes |
|---|---|---|---|
| Product explanation | what the ERP does, who it is for, that access is arranged with us; **no self-serve purchase** until §3.2 is live | static | — |
| Sign in (`/account`) | an Owner signs in with their existing login | `POST /api/v1/auth/login` | — |
| Business access status (`/account`) | state in a word, the period end or the grace deadline, branches and staff counted, the **server-calculated monthly quote**, the decision history | `GET /api/v1/platform/my-subscription` | — |
| Request access (`/request`) — **future** | a new business asks to be approved: legal/display name, city, Owner identity, **a verified contact**, branch count and staff count (for the quote), terms and privacy acknowledgement, submission for Super Admin review | `POST /api/v1/platform/quote` (stateless, **proposed**, §3.3) | `POST /api/v1/platform/register` + `register/verify/*` |
| Application status (`/request/status`) — future | pending / approved / refused, as the server says | `GET /api/v1/platform/my-subscription` (after sign-in) | — |
| Payment (`/account/pay`) — **future, Bankily** | initiate a payment for the current quote; see its status | `GET /api/v1/platform/payment-instructions` (answers `available: false` today) | a signed, idempotent provider callback (§5) |
| Renewal history (`/account/history`) — future | billing periods and recorded payments, read-only | `my-subscription` (`periods`, `payments`) | — |
| Owner invitation (`/invite/:token`) | the Owner of a business created by the Super Admin sets a password | — | `POST /api/v1/platform/owner-invitation/accept` |

### 3.2 The business-request flow, and why it is not live yet

`POST /api/v1/platform/register` creates the company, its first branch, the Owner and a `pending_activation`
subscription in one transaction, then expects the contact to be proved by a code (`register/verify/start` →
`register/verify/confirm`, which issues the first session). **Since 2026-10-05 it refuses up front — `503
registration_unavailable`, "nothing was saved" — whenever no verification code can leave the server** (no WhatsApp
channel, no email provider). So the website's request flow needs a contact-delivery provider first (`docs/45` D7).
Until then a business is created by the Super Admin (§4.2) and its Owner invited.

### 3.3 Request/response schemas (business side)

`POST /api/v1/platform/register` — public, throttled (10/min)

```json
{ "idempotencyKey": "client-uuid", "ownerName": "…", "businessName": "…", "branchName": "…", "city": "…",
  "email": "owner@example.com", "phone": "+2224…", "password": "≥ 8 chars", "language": "en|fr|ar" }
```
→ `201 { status: "pending_activation", created, publicStoreId, verification: { destination, channel } | null,
continuation: { token, expiresAt, expiresInSeconds } | null, next: "verify_contact" | "sign_in" }`
→ `503 { code: "registration_unavailable" }` when no code can be delivered (nothing is created)
→ `400` validation.

`POST /api/v1/platform/register/verify/start { continuation, language }` → `{ delivery: "sent" | "outbox" }`;
`POST …/verify/confirm { continuation, code }` → `{ accessToken, refreshToken, expiresIn }`.

`POST /api/v1/platform/owner-invitation/accept { token, password }` → `200 { …, next: "sign_in" }` (no session).

`GET /api/v1/platform/my-subscription` — tenant JWT; reachable in **every** state

```json
{ "business": { "name", "city", "createdAt", "branches": [{ "name", "type" }] },
  "owner": { "name", "email", "phone", "emailVerified", "phoneVerified" } | null,
  "entitlement": { "state", "periodEnd", "graceEnd", "daysRemaining", "graceHoursRemaining", "subscribedBranchCount",
                   "activeBranchCount", "includedSeats", "additionalSeats", "seatLimit", "seatsUsed", "overLimit",
                   "canRead", "canWrite", "isComplimentary", "status", "calculatedAt" },
  "pricing": { "plan": { "id", "planKey", "version", "branchMonthly", "includedStaffPerBranch", "extraStaffMonthly", "effectiveFrom" },
               "upcoming": … | null, "current": { "available", … assessed period … }, "nextRenewal": { quote } },
  "events": [ … ], "payments": [ … ], "periods": [ … ] }
```

`GET /api/v1/platform/payment-instructions` — tenant JWT → `{ available: false, providers: [], defaultProvider: null,
placeholder: false, amount: { …pricing } }` until a provider is offered with a real code. A provider, when offered:
`{ key: "bankily"|"masrivi"|"sedad"|"bimbank"|"click", label, order, enabled: true, code, placeholder: false }`.

**Proposed, not built:** `POST /api/v1/platform/quote { branches: n, staff: n }` → the Standard quote for a size, public
and throttled, with no company id — the replacement for the removed `GET platform/quote/:id`, which returned a
company's size and price to anyone holding its id.

### 3.4 Error states the business side must render

| Status | Code | Shown as |
|---|---|---|
| 401 | — | sign in again |
| 403 | `ENTITLEMENT_PENDING` / `ENTITLEMENT_SUSPENDED` / `ENTITLEMENT_REJECTED` | the state screen; the account page itself never answers these |
| 403 | `ENTITLEMENT_WRITE_BLOCKED` | not applicable to the website's reads |
| 429 | — | "try again in a minute" |
| 503 | `registration_unavailable`, `delivery_unavailable` | "requests cannot be completed right now" — honest, no retry loop |

## 4. The Super Admin side

### 4.1 Pages

| Page | Reads | Writes |
|---|---|---|
| Sign in | — | `POST platform/admin/sign-in { email, password }` → cookie + `{ admin, expiresAt }` |
| Dashboard | `GET platform/dashboard` (counts by state, businesses, branches, active users; `revenue: null` by design) | — |
| Pending approvals | `GET platform/pending` | approve / refuse (§4.2) |
| Businesses | `GET platform/businesses?q=&state=&page=` | create (§4.2) |
| One business | `GET platform/businesses/:id` — identity, branches (names and types), the Owner's contact and verification state, the subscription and its version, the computed price breakdown, events, recorded payments | every lifecycle action below |
| Pricing | `GET platform/plans` | `POST platform/plans` (schedule a version; never in the past) |
| Audit | `GET platform/audit?page=` | — |

### 4.2 Actions, request bodies and answers

Every mutation carries `confirmPassword` (the acting administrator's own password; `403 password_confirmation_required`
without it), may carry `expectedVersion` (the subscription's version as last read; `409 subscription_changed` if it
moved), is **idempotent for a same-state retry** (`applied: false`, nothing written twice), writes a subscription event
**and** an immutable audit row with before/after, and deletes nothing.

| Action | Route | Body | Answer |
|---|---|---|---|
| Create a business | `POST platform/businesses` | `{ idempotencyKey, ownerName, businessName, branchName?, city?, email?, phone?, language, reason, confirmPassword }` | `201 { companyId, publicStoreId, branchId, ownerUserId, status: "pending_activation", created, invitation: { token, expiresAt, delivery: "manual", owner } }` — the invitation is shown **once**; delivery is manual until a provider exists |
| Re-issue the Owner invitation | `POST platform/businesses/:id/owner-invitation` | `{ reason?, confirmPassword }` | the new token; every unspent one revoked |
| Approve | `POST platform/businesses/:id/approve` | `{ months (1–60) | periodEnd (ISO), reason?, expectedVersion?, confirmPassword }` | `{ applied, version, status: "activated", periodEnd }`; opens the billing period |
| Refuse | `POST platform/businesses/:id/reject` | `{ reason, expectedVersion?, confirmPassword }` | `{ applied, version, status: "rejected" }` |
| Set / correct the period end | `POST platform/businesses/:id/period` | `{ periodEnd, reason (required when shortening), expectedVersion?, confirmPassword }` | `{ applied, version, status, periodEnd }` |
| Extend | `POST platform/businesses/:id/extend` | `{ months, reason?, expectedVersion?, confirmPassword }` | `{ applied, version, status, periodEnd }` |
| Administrative grant | `POST platform/businesses/:id/activate-grant` | `{ days, reason, expectedVersion?, confirmPassword }` | a complimentary period; **never** a payment row |
| Suspend / reinstate / end | `POST platform/businesses/:id/suspend` · `reinstate` · `cancel` | `{ reason, expectedVersion?, confirmPassword }` | `{ applied, version, status }` |
| Record a payment | `POST platform/businesses/:id/payments` | `{ amount (decimal string), paidAt, channel?: "manual"|"bank_transfer"|"mobile_money", reference?, note?, confirm?, confirmPassword }` | the row, `providerVerified: false` — recording a payment **never** extends anything |
| Schedule a price | `POST platform/plans` | `{ branchMonthly, includedStaffPerBranch, extraStaffMonthly, effectiveFrom (never past), reason, confirmPassword }` | the version |

### 4.3 Audit events (immutable, `platform_audit_events`)

`admin.sign_in` · `business.create` · `owner_invitation.issue` · `owner_invitation.accept` · `subscription.approve` ·
`subscription.reject` · `subscription.set_period` · `subscription.extend` · `subscription.activate_grant` ·
`subscription.suspend` · `subscription.reinstate` · `subscription.cancel` · `payment.record` ·
`payment.record_and_confirm` · `plan.schedule`. Each row: actor (text, so it reads after the admin row is gone),
action, target, label, reason, before/after state, IP, instant. Subscription events (`subscription_events`):
`registered`, `approved`, `rejected`, `extended`, `period_corrected`, `administrative_grant`, `suspended`,
`reinstated`, `cancelled`, `branches_changed`, `seats_changed`, `complimentary_granted`, `complimentary_revoked`.

### 4.4 Concurrency and idempotency, as proven

Two approvals at once: exactly one applies; the other is a `409 subscription_changed` or a truthful no-op (`applied:
false`), and **one** billing period exists. Approve against refuse at once: exactly one wins, the loser is `409`, the
timeline holds one decision (the 2026-10-05 matrix). A retry of the same decision is a no-op.

## 5. Security requirements

- **No subscription mutation from a public, unauthenticated request.** The only public writes are the business request,
  its code verification, the invitation acceptance and the administrator sign-in — all throttled (10/min), all
  non-enumerating.
- **CSRF**: cookie-authenticated mutations carry `x-requested-with`; cookies are `SameSite=Lax`; the API's CORS grant
  names only the website's HTTPS origin, with credentials.
  > **Corrected (2026-10-18, D210).** The API never checked `x-requested-with`. The Owner's area is now the Dukan ERP
  > portal at `https://dukan.tsxmr.com/subscription` (`docs/101`). It is held by:
  > - its own cookie session, `HttpOnly` and `SameSite=Strict`, accepted only on the portal's routes;
  > - a session-bound CSRF token in `x-csrf-token` on every unsafe request;
  > - for the trial's claim and resend, the portal session itself (D211).
  >
  > `SameSite` alone is no boundary: `tsxmr.com`'s subdomains are one site. The administrator console's session is
  > unchanged.
- **Strict rate limiting** on sign-in, request, verification and invitation routes (server-side; a 429 is rendered, not
  retried in a loop).
- **Recent re-authentication for sensitive actions**: every administrator mutation re-asks the password
  (`confirmPassword`); the website must not cache it.
- **No secrets in the browser**: no token in `localStorage`/`sessionStorage` (the Phase-2 website enforces exactly two
  preference keys); the administrator session is an HttpOnly cookie; the Owner's bearer token lives in memory for the
  visit.
- **Payment callbacks (future)**: signed by the provider, verified server-side, **idempotent** on the provider's
  reference, recorded as `subscription_payments` rows that never move a period by themselves — a person (or a later,
  explicitly approved rule) extends.
- **Tenant isolation**: the website reads a business only through the Owner's own session; administrator reads never
  return operational data.
- **Immutable audit**: every decision is a `platform_audit_events` row and a `subscription_events` row; nothing is
  deleted (append-only triggers).
- **No trust in client-calculated totals**: every figure shown is the server's (`pricing`), and the website never
  multiplies a unit price (the Phase-2 site has a test for exactly this).
- **Administrator MFA** is still owed (`docs/45` D8); until it exists the website must say so plainly rather than show a
  toggle.

## 6. Versioning

The API is `/api/v1`; this contract is **v1.0**. Compatibility rules: fields are only added, never renamed or
re-typed within v1; codes (`ENTITLEMENT_*`, `subscription_changed`, `registration_unavailable`, …) are stable and
machine-matched; a removed route (the public quote) is a v1 change recorded in `docs/21` and here. A website build
names the contract version it was tested against.

## 7. Inputs needed before the website is implemented (none can be produced by a session)

| # | Input | Why |
|---|---|---|
| 1 | **The repository.** `retail-erp-control-web` exists on the owner's PC at `c764d63` with **no remote** (`docs/38`): push it to a repository of the owner's choosing (for example `erp-website`) or decide on a fresh one. No unreviewed production repository was created here | the Phase-2 site already has the three guarded areas, the Owner account page and the administrator portal (without approve/refuse/create/invite) |
| 2 | **Domain, DNS, TLS** (`docs/45` D1–D3) | cookies are `Secure` in production; CORS names the origin |
| 3 | **Hosting** for the API and the website (`docs/45` D4–D6) | nothing runs outside the owner's PC today |
| 4 | **An email provider** (and/or the WhatsApp Business account) (`docs/45` D7) | the request flow and the Owner invitation cannot deliver a code or a link today |
| 5 | **The Bankily merchant agreement** and its API terms (`docs/45` D9; `docs/21`: "no confirmed public API — do not implement a guessed integration") | payment initiation and callbacks |
| 6 | **Administrator MFA** decision (`docs/45` D8) | before `/admin` is reachable from the internet |
| 7 | **Legal texts**: terms of service and the privacy policy (`docs/64` §6) | the request flow's acknowledgement; the App Store privacy URL |
| 8 | **The owner's confirmation** of the commercial reading in §1 (one subscription per company, priced per branch) | the quote's wording on the website |

## 8. Interim operations, until the website carries the new actions

The customer app no longer carries the platform console (`docs/21`, 2026-10-05). The Phase-2 website's administrator
portal covers grant, extend, suspend, reinstate, cancel and payment; **create a business, invite its Owner, approve,
refuse and correct the period** are API-only until the website gains them. With shell access to the API host:

```bash
API=https://<api-host>/api/v1
# sign in once; the cookie file is a working credential — keep it in a mode-600 scratch file and delete it after
curl -sS -c /tmp/admin.cookie -H 'Content-Type: application/json' -X POST "$API/platform/admin/sign-in" \
  -d '{"email":"<admin email>","password":"<prompted, never in a script>"}'
# create a business; the response carries the Owner's one-time invitation token — hand it over by a channel you trust
curl -sS -b /tmp/admin.cookie -H 'Content-Type: application/json' -H 'x-requested-with: ops' -X POST "$API/platform/businesses" \
  -d '{"idempotencyKey":"<uuid>","ownerName":"…","businessName":"…","branchName":"…","city":"…","email":"…","language":"fr","reason":"…","confirmPassword":"<prompted>"}'
# approve for N months (read the version first from GET /platform/businesses/:id)
curl -sS -b /tmp/admin.cookie -H 'Content-Type: application/json' -H 'x-requested-with: ops' -X POST "$API/platform/businesses/<id>/approve" \
  -d '{"months":1,"expectedVersion":<v>,"reason":"…","confirmPassword":"<prompted>"}'
# refuse · correct the period · extend · suspend · reinstate · end: the routes and bodies of §4.2
```

The Owner then signs in to the app: a pending business sees *Pending approval*; an approved one enters.

## 9. What the mobile app does — and never does (reference)

Reads `GET /entitlement` only and renders the server's `state`, `canRead`, `canWrite`, `periodEnd` and `graceEnd`:
*Pending approval*, *Active* (until a date), *Grace period* (changes accepted until the server's deadline, one
restrained notice), *Access ended* (reading and exports only; nothing new is offered), *Suspended*, *Not approved* —
always "Managed by your organisation" and "Contact your organisation administrator if you believe this is a mistake".
It never calls `my-subscription`, `payment-instructions`, a quote or a platform route; it carries no price, no
payment method, no purchase, renewal or website call to action, no plan, no billing control and no in-app purchase
(pinned by `lib/access-boundary.test.ts` and the exported-bundle audit). Account deletion, device security and sign-out
stay reachable in every state. A shop's own customer-payment channels (Cash, Bankily, the accounts it configures) are
untouched: they are the shop's money, not ours.

## 10. Verified on 2026-10-05 (the real-HTTP matrix, disposable MySQL, development- and production-mode APIs)

87 of 87: pending, approval, active (Owner, Manager, Employee), grace (70–72 h), the exact grace boundary (±20 s),
read-only (writes refused with `ENTITLEMENT_WRITE_BLOCKED`, every read and the monthly report answer, deletion and
device revocation pass the gate, `logout-all` accepted), suspension and reinstatement (idempotent; the password
step-up enforced), two concurrent approvals and approve-against-refuse, refusal, cross-business isolation, the
administrator realm refused on customer routes and vice versa, a phone clock sent in headers ignored, no price in any
customer response; in production mode: registration refused up front with nothing saved, payment instructions
unavailable with no provider and no code, no public quote, no static-key provisioning, the administrator cookie
admitted and a bearer refused.

---

## 9. Additions of 2026-10-05 — seats per store, requests, staff activation (v1.1)

**§1 table superseded** (D135, `docs/21`): one included employee seat per store, 100 MRU per additional seat **per
store**, no pooling; the subscription stays one per company. Plan version 2 carries it. The website shows the figures
the server sends and never multiplies anything.

### 9.1 Public

| Route | Body | Answers |
| --- | --- | --- |
| `GET platform/plan` | — | `{version, branchMonthly, includedSeatsPerStore, extraSeatMonthly, currency, effectiveFrom, upcoming}` |
| `POST platform/quote` | `{stores: number[]}` — non-Owner employees per store, 1–50 stores, 0–500 each | a `Quote`: `branchFee, staffFee, monthlyTotal, paidSeatCount, lines[{name, staffCount, includedSeats, paidSeats, seatFee}]` |

### 9.2 Owner (tenant session; `settings.manage`)

`GET platform/my-subscription` is unchanged in shape; `pricing.quote.lines` now itemises every store (`branchId,
name, staffCount, includedSeats, paidSeats, grantedSeats, seatLimit, seatsAvailable, overLimit, seatFee`) and
`entitlement.seatsByStore` carries the same census.

| Route | Body | Answers |
| --- | --- | --- |
| `GET platform/my-subscription/seat-requests` | — | `SeatRequest[]` (below) |
| `POST platform/my-subscription/seat-requests` | `{branchId}` | 201 `{allocation, created}` — priced by the server, `pending_payment` |
| `POST platform/my-subscription/store-requests` | `{name}` | 201 `{allocation, created}`; 409 `store_name_in_use` |
| `POST platform/my-subscription/seat-requests/:rid/withdraw` | — | `{allocation, applied}`; only while `pending_payment` |

All three writes are allowed however the subscription stands (asking to pay is not a business write).

`SeatRequest`: `{id, kind: seat|store, status: pending_payment|paid|granted|released|refused, store: {id,name}|null,
person: {id,name}|null, label, monthlyAmount, currency, requestedBy, requestedAt, confirmedBy, confirmedAt, closedAt,
closedBy, reason, payment: {id, amount, reference, paidAt, channel}|null, version, providerVerified: false}`.

### 9.3 Administrators (cookie realm; `confirmPassword` on every mutation)

| Route | Body | Answers |
| --- | --- | --- |
| `GET platform/seat-requests?status=` | — | the queue, oldest first when `pending_payment`; each row carries `business: {id, name, publicStoreId}` |
| `GET platform/businesses/:id/seat-requests` | — | `SeatRequest[]` |
| `POST platform/businesses/:id/seat-requests/:rid/confirm-payment` | `{amount, paidAt, channel?, reference, note?, expectedVersion?, confirmPassword}` | `{allocation, applied, paymentId, activation: {activated, pending[]}|null}`; 400 `reference_required`; 409 `seat_request_changed`; a repeat is `applied: false` |
| `POST …/refuse` | `{reason, expectedVersion?, confirmPassword}` | `{allocation, applied}` |
| `POST …/release` | `{reason, expectedVersion?, confirmPassword}` | a paid or granted **seat** given back; nobody deactivated |

`GET platform/businesses/:id` now carries `pricing` (the same `SubscriptionPricing` the Owner sees),
`entitlement.seatsByStore`, and each person's `status: active|pending|inactive`. `GET platform/dashboard` adds
`pendingSeatRequests` and `pendingStaff`.

### 9.4 Staff (not called by the website; recorded for completeness — `docs/69` §3)

`POST /users`, `POST /users/:id/resend-verification`, `POST /users/:id/cancel-invitation` (Owner);
`POST staff/verify/confirm`, `POST staff/verify/resend` (public, throttled).

### 9.5 Audit actions added

`seat.payment_confirm`, `store.payment_confirm`, `seat.refuse`, `seat.release`; timeline kinds `seat_requested`,
`seat_paid`, `staff_activated`, `seat_closed`, `store_requested`.

## 10. Additions of 2026-10-10 — the grant's own dates, a store that replaces one closed this month (v1.2)

The contract for both lives in `docs/73` §11.1 and §11.5; what the website reads:

- **`entitlement.complimentary`** on `GET platform/my-subscription` and `GET entitlement`, and **`complimentary`** on
  each row of `GET platform/businesses` and on the console's business page: `{ status, until, paidUntil }` —
  `active` (a grant running to `until`), `ended` (it ran out on `until`; access follows the paid period), `superseded`
  (it ran out and a paid period runs past it, to `paidUntil`), `indefinite` (defensive: the database refuses a grant
  with no end), `none`. The page says the grant with its own dates, never a paid-period date in its place; with no
  grant view (an older API) it makes no claim about a date. The console's list shows, for a business on a grant, the
  later of the grant's end and the paid end.
- **`activity-options.newStore[]`** carries `dueNow` and `replaces: { branchId, name, credit } | null` for each activity:
  the form says *replaces X, closed during this paid month: no additional charge this month* (it opens at once) or
  *… {dueNow} now, the difference*. A **store request** row carries the same `replaces`; its `monthlyAmount` is then
  this period's difference (0 when nothing is due), shown as *{amount} now, replacing X; the full monthly price from
  the renewal* — never *per month*.
- A confirmation of a request priced against a replacement slot or credit that no longer holds (the period renewed,
  the archived store is active again, another store took its place) is **409 `replacement_no_longer_applies`**,
  nothing written: the Super Admin refuses it, or the Owner withdraws it and asks again.

## 11. Additions of 2026-10-13 → 2026-10-16 — the free trial, and a store or seat bought during it (v1.3)

The trial's whole contract lives in `docs/76`. This section lists what the website, the console and the app read and
send, field by field, as built (backend `reports-export`; website `tsx-public-site`; app `reports-export`). Every
addition is optional for an older client, and every client keeps today's rendering when a field is absent.

### 11.1 The Owner (tenant session)

| Route | Body | Answer |
| --- | --- | --- |
| `GET platform/my-subscription` | — | `entitlement.trial`: the trial view (`docs/76` §4), with `accessAfterTrial` (C6). Top-level `timeZone`: the business's IANA zone, or `UTC` for an invalid stored zone (C18). |
| `GET platform/my-subscription/trial` | — | `{ state, trial, offer, setup }`. `setup` may be `null` when its read failed: the offer and the claim still stand (C3). |
| `POST platform/my-subscription/trial/claim` | `{ idempotencyKey, termsVersion }` | 201 the trial; the same key and body replays (200, `replayed: true`). The key must match `^[A-Za-z0-9._:-]{1,80}$`, otherwise 400 (C11). |
| `POST platform/my-subscription/trial/setup/resend` | — | the new `setup`. 429 carries `resendAvailableAt`; 503 `setup_delivery_unavailable` when nothing can carry it. |
| `POST platform/my-subscription/store-requests`, `…/seat-requests` | as §9.2 | **Accepted while a trial runs** (D176). |
| `GET platform/my-subscription/seat-requests` | — | each `SeatRequest` gains `effectiveAt` and `activation`; `status` may be `scheduled` (§11.4). |
| `POST platform/my-subscription/seat-requests/:rid/withdraw` | — | 400 for a `scheduled` row: it is paid for. |

**`setup`** (the website's trial card):

- `delivery`: `waiting_for_contact`, `sending`, `not_sent`, `sent`, `failed` or `unavailable`.
  - `sending` (C1) means a link was issued less than 60 s ago and its attempt is not recorded yet.
  - `sent` holds only while the link still binds to the link's Owner as they are now (C2): a contact, password or
    verification change makes it `not_sent`, with `sentTo: []`.
- `sentTo`: the channels that took the last current message.
- `destinations`: the Owner's verified contacts, masked.
- `canResendNow`.
- `resendBlockedBy`: `null`, `throttle`, `unavailable` or `contact_unverified` (C4). It is `null` exactly when
  `canResendNow` is true, and only `throttle` counts down to `resendAvailableAt`.
- `history`: `[{ at, trigger, email, whatsapp }]`. An attempt is dated at its link's issue instant (C5).

**`accessAfterTrial`** (C6): `{ kind: 'paid' | 'granted', startsAt }`, where `startsAt` equals the trial's `endsAt`. It
is the paid period or grant approved during the trial, which begins when the trial ends; otherwise `null`.

- A suspended business keeps what was arranged.
- A cancelled one reads `null`.
- After the end, it is shown only when the eligibility's closure proves the decision was taken during the trial.

### 11.2 Registration (both doors, the website's and the app's)

- **One throttle budget per step** across `platform/register*` and `auth/register*` (C15).
- **Refused up front, nothing saved,** with 503 `registration_unavailable` when any given contact's channel cannot
  carry a code now. The body names `unavailableContacts: ('email' | 'phone')[]` (C10).
- **`verify/confirm` answers within about 3 s** (`SETUP_DELIVERY_WAIT_MS`) whatever the providers do. The setup message
  goes on in the background (C14).
- **A lost answer is never called a wrong code.** The server refuses a finished registration exactly as it refuses a
  wrong code: one shape for every refusal of a continuation. So when a code's answer is lost — no answer, a 502 or 504
  from a gateway, or a success without its body — the clients say the account may be ready and offer to sign in.
- **The idempotency key** follows the pattern above.

### 11.3 The Super Admin (cookie realm; `confirmPassword` on every mutation)

| Route | Change |
| --- | --- |
| `GET platform/pending` | each row gains `state` (the computed entitlement state; `null` only for an application with no business) and `trial: { status: 'available' \| 'active' \| 'expired', endsAt, timeZone } \| null` (C8) |
| `GET platform/businesses` | each row gains `trial`, in the same shape (C18) |
| `POST platform/businesses` | `idempotencyKey` must match `^[A-Za-z0-9._:-]{1,74}$`: the server stores it as `admin:<key>` in 80 characters (C11) |
| approve, set the period's end | an end inside a running trial: 400 `period_ends_before_trial_end`, which carries `trialEndsAt` (UTC ISO). The message holds no instant (R4-05). |
| `GET platform/seat-requests?status=scheduled` | the scheduled queue (§11.4) |
| `POST platform/businesses/:id/seat-requests/:rid/confirm-payment` | §11.4 |
| refuse, release a request | 400 for a `scheduled` row |

**Server notes carry no instant** (C7). The dates travel as data, and every client says them in the business's zone:

- `approved`: "Paid access starts when the free trial ends."
- `renewed`: "First billing period opens when the free trial ends, at today's size and the prices in force then."
- `trial_expired`: "The 7-day free trial ended. Nothing was charged."
- the claim: "Free trial claimed on the website by the Owner: 7 days from the claim. Nothing was charged."
- `seat_paid`, when scheduled: "It opens when the free trial ends; its first paid month starts then."

### 11.4 A store or a paid seat bought during a trial (D176)

**`SeatRequest` gains three things:**

- `status: 'scheduled'`: paid for, in force nowhere, waiting for the trial's end.
- `effectiveAt: string | null`: for a scheduled row, when it starts (the trial's end). Once in force, when it took
  effect. Otherwise `null`.
- `activation: { startsAt, timeZone, waitsFor: 'trial_end' | 'paid_access' } | null`: only for a scheduled row.
  - `trial_end`: paid access is arranged from the trial's end, so the row starts then.
  - `paid_access`: none is arranged yet, so the row starts with the first paid period (PQ1).

**What a confirmation does:**

1. **During a trial:** the payment is recorded once and the row becomes `scheduled` at the trial's end. Nothing opens,
   counts or is assessed now. The answer carries the scheduled row.
2. **A paid period in force:** at once, as before.
3. **A business with trial facts, no paid period ever started and no trial running:** 409 `paid_period_not_started`,
   and nothing is written. The first paid period would charge the add-on again, so the request waits (PQ2).
4. **A repeat:** `applied: false`. A stale `expectedVersion` gives 409 `seat_request_changed`.

**At the trial's end,** in one transaction:

- every scheduled row whose business has a paid period in force from that instant is put in force, stamped at the end;
- the first paid period is raised once by its price.

This happens on the first evaluation after the end, and the sweeper puts it in force within 60 s if nobody looks. A
suspended or cancelled business activates on schedule; a closed one never does (PQ3).

**A seat waiting for its start** reads to the staff side as held. Its activation's pending reason is `seat_scheduled`.

### 11.5 The app (display only)

`GET account/trial-setup`, eligible branch:

- `delivery` includes `sending` (C1).
- `lastSentAt: string | null` (C17): the newest attempt a provider accepted, whatever happened since. With
  `delivery: 'not_sent'`, the app tells "never sent" from "sent, then the account changed" (`sentTo: []`) and from
  "sent, but the latest has not gone".

The app shows no price, payment, purchase or activation control for a store or a seat.

### 11.6 Routing and logs

- **Routing is case-sensitive** (C13). Only the canonical lower-case path reaches a handler; any other casing answers
  404.
- **No secret reaches a log**, on a request that succeeds or fails (C16). This covers setup tokens, portal tickets,
  bearer and refresh tokens, cookies, codes, continuations, passwords and the webhook verify token, wherever they
  travel. The proof is `src/common/http/request-log.spec.ts`, plus the real-HTTP run's log scan (`docs/76` §14).
