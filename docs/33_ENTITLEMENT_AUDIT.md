# 33 — Subscription entitlement audit (Milestone K)

> **K0.** What exists, where enforcement can safely go, and which mutations must
> stop when a shop's subscription lapses.
>
> The classification in this document is not the authority.
> `backend/src/entitlement/route-classification.ts` is, and a drift test fails
> the build when a mutation exists that nobody has classified.
>
> **2026-10-05 (`docs/21`, D130–D132; `docs/68`).** Two statements below are superseded: revoking a device
> (`DELETE devices/:id`, and a member's as the Owner) now **survives** expiry like `logout-all` — adopting one still
> does not; and the mobile app no longer shows seats or branches at all — it shows the server's state and dates as
> *Business access*, with no figure of any kind. Prices live on the website and in the platform's tools only.
>
> **2026-10-05, later (`docs/21` D135–D138; `docs/69`).** The economics table and the seats section below are
> superseded: every store includes **one** seat, further seats are **per store** (100 MRU each, paid and confirmed by
> an administrator, or granted by the transition), nothing pools, and an employee account is created pending and
> activated by the server once its contacts are verified and a seat is held. `POST /users` now exists.

---

## What already existed

**Nothing.** No subscription, billing, plan, feature-flag or entitlement code,
schema or remnant. The only greps that hit "subscription" are doc comments
explaining that a Store Account ID is *not* a subscription id. K starts clean,
which is the easier case and also the one where a bad boundary is easiest to
bake in.

## The guard chain, as it actually runs

| Order | What | Where |
|---|---|---|
| 1 | `ThrottlerGuard` | global, `app.module.ts` |
| 2 | `JwtAuthGuard` — every route needs a token unless `@Public()` | global, `auth.module.ts` |
| 3 | `PermissionsGuard` — per route, via `@RequirePermissions` | `rbac/` |
| 4 | Interceptors: `CostGatingInterceptor`, `BinaryUuidInterceptor` | global |
| 5 | `AllExceptionsFilter` | global |

`TenantContext` reads company, branch and user from `nestjs-cls`, populated by
the JWT strategy. There are exactly **three** `@Public()` surfaces: login,
refresh and health.

### Where entitlement goes, and why it fails closed

Entitlement needs a resolved company, so it must run **after** authentication.
Nest runs global guards in registration order, and `AuthModule` is imported
before `app.module`'s own providers — so a guard registered there runs after the
JWT guard today.

Relying on that ordering silently would be a mistake: if it ever changed, an
entitlement guard that runs first would see no company and wave everything
through. So the guard **requires** a company for any route it is asked to
protect and throws when there is none. Wrong ordering produces a loud failure
rather than a silent bypass.

---

## Mutation classification

Three outcomes, and an unclassified mutation is the fourth thing the drift test
exists to prevent.

### Blocked once entitlement lapses

Everything that changes inventory, sales, money, liabilities, workflow
decisions, settings or staff. That is the large majority of `POST`/`PATCH`/
`PUT`/`DELETE` routes: sales, units, purchases, imports, catalogue, pricing,
transfers, consignments, loans, returns, refunds, suppliers, expenses,
corrections, closings, discrepancies, goals, users, roles, branches, settings
and receiving accounts.

### Never blocked

| Route | Why |
|---|---|
| `POST /auth/login`, `/auth/refresh`, `/auth/logout` | A shop must be able to sign in and out to reach its own history. Blocking authentication would lock somebody out of data they still own |
| `GET` everything | Historical reads and exports remain available. No data is deleted or hidden |
| `POST /notifications/:id/read` | Sets a flag on the reader's own notification. Audited as changing no business truth — the same reasoning that made it queueable in J |
| `GET /entitlement` | The screen that explains the lapse cannot itself be blocked by the lapse |

### Device trust

`POST /devices/adopt` and `DELETE /devices/:id` are **blocked**. They grant and
revoke authority, and a lapsed shop adopting new devices is exactly the case
where a stale subscription should stop mattering to the platform.

---

## The economics, as data

| Rule | Value |
|---|---|
| Base | **500 MRU** per subscribed branch per month |
| Included seats | **2 non-Owner staff** per subscribed branch |
| Pooling | Included seats are pooled freely **across the company's branches** |
| Owner | Consumes **no** seat |
| Every active non-Owner role | Consumes **one** seat |
| Additional seats | **100 MRU** each per month, **not prorated** |
| Free trial | **None** |
| Annual billing | Deferred |
| Complimentary | Supported, and audited |

**Prices live in the billing and provisioning domain, not in the app.** The
mobile client never shows an amount, a checkout control, a Bankily call or a
payment link. It shows how long is left and where to ask — nothing that would
have to be kept in sync with a price change, and nothing that implies the app
took money.

---

## Entitlement states

Derived from a server clock, never from the device.

| State | Meaning |
|---|---|
| `active` | Paid period has not ended |
| `grace` | Ended within the last **72 hours**. Everything still works, with a persistent warning |
| `expired` | Grace is over. Reads and exports continue; business writes are refused |
| `complimentary` | Granted by the platform, audited, and never self-grantable by a tenant |

Grace is exactly 72 hours, computed as `periodEnd + 72h`. It is derived rather
than stored, so it cannot drift from the period it belongs to.

### What "expired" does not mean

It does not mean deleted, hidden or locked out. Authentication works, history is
readable, exports work, branch selection works, sign-out works, and the
subscription screen explains itself. A shop that cannot see yesterday's sales
reaches for the notebook immediately, and would be right to.

---

## Seats

Enforced on the server when creating, inviting, reactivating, or changing a user
**into** a seat-consuming role.

Nobody is ever deactivated automatically. If a plan change leaves a company over
its limit, the server exposes `seatsUsed`, `seatLimit` and `overLimit`, blocks
further seat-consuming activations, and leaves the Owner to decide who stays.
Silently deactivating an employee to make the arithmetic work would be the app
firing somebody.

Seats are **not** permissions. A seat is a headcount the shop pays for; a
permission is what that person may do. Conflating them would make a role change
a billing event.

---

## Response contract

The server returns one calculated object. The client renders it and computes
none of it — not the state, not the remaining grace, not seat availability, not
whether writes are allowed. A client that decides its own entitlement is a
client that can be made to decide wrongly.

The error code is stable and machine-readable: **`ENTITLEMENT_WRITE_BLOCKED`**.
The mobile app never parses English.

### Offline honesty

A cached entitlement that cannot be re-verified is shown as **stale**, never as
current. J's offline restrictions continue to apply on top: a lapsed-but-unknown
subscription does not become permission to finalize a sale.

### Queue interaction

An entitlement refusal is **not transient**. A queued report that hits it moves
straight to `needs_attention` and stops — it must never loop, because the
condition will not resolve by retrying and a phone quietly retrying forever is
both a battery problem and a lie about progress.
