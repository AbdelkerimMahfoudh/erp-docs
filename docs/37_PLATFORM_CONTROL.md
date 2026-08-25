# 37 — Platform control: registration, subscriptions, administration

> The backend contract for the platform-control product. The three web surfaces
> — public registration, the customer portal and the administration portal —
> are built on top of this and are **not** part of this checkpoint. See
> "What is not built yet".

## The shape of it

Three areas, one backend, strict separation:

| Area | Who | Credential |
|---|---|---|
| Public registration | anybody | none |
| Customer portal | a shop's Owner | the tenant login they already have |
| Platform administration | us | a **separate** identity realm |

The existing backend is the source of truth. There is no second subscription
engine: entitlement is still calculated by `entitlement-rules.ts`, and the
administration API drives that model rather than reimplementing it.

## What the audit found before anything was built

The brief assumed a subscription engine with plans, prices, payments and a
lifecycle. Milestone K deliberately built almost none of it, and that shaped
every decision below:

- no `pending_activation`, `suspended` or `cancelled` state — only
  `active | grace | expired | complimentary`, all derived from dates;
- **no Plan model and no price anywhere on the server**;
- `Payment` is a *till* payment carrying a `sale_id`, not a subscription one;
- platform administration was a shared `PLATFORM_ADMIN_KEY` env var on a
  `@Public()` controller — no accounts, no sessions, no revocation;
- no registration endpoint, and no contact-delivery adapter of any kind.

## No money, deliberately

**Nothing on the server computes a price, and no screen may either.**

Milestone K's canonical decision is that there is one functional plan and
entitlement is about *access*, not invoicing. There is no plan price, no
per-seat charge, no currency amount in the subscription domain at all. So the
customer portal shows what the server actually knows — status, period end,
grace, branch count, included and used seats — and no money.

The only figure in the system is the amount a human typed onto a recorded
payment. The dashboard returns `revenue: null` on purpose: payment history is
incomplete by construction, and a total would look authoritative without being
so.

Pricing is a separate product decision with a Plan model behind it. Inventing
one here would have meant inventing numbers.

## The lifecycle

`subscriptions.status` records where an administrator has **put** a
subscription. It is distinct from the derived entitlement state, because no
arithmetic over dates can reproduce a decision.

| Status | Meaning |
|---|---|
| `pending_activation` | Registered, never activated. No free trial |
| `activated` | Normal — **the dates decide** |
| `suspended` | Deliberately stopped, with a recorded reason |
| `cancelled` | Ended. History kept |

`activated` is the default, and it means exactly what every subscription did
before the column existed, so no existing row changed behaviour.

Precedence in `stateOf`: an administrator's decision, then a complimentary
grant, then the paid period. Suspension outranks a grant — otherwise
suspending a shop that happens to hold one would silently do nothing, and a
shop being tested is precisely the shop that holds a grant.

### Reads and writes

| State | Write | Read |
|---|---|---|
| `active`, `grace`, `complimentary` | ✅ | ✅ |
| `expired` | ❌ | ✅ |
| `pending`, `suspended`, `cancelled` | ❌ | ❌ |

**Expiry still hides nothing.** That rule has not moved: a shop locked out of
yesterday's sales reaches for the notebook immediately, and would be right to.

The two new states are different, and the difference is worth saying out loud
because it looks like an inconsistency until you do. A `pending` business has
no operational history to withhold — it has never sold anything — and opening
the till to it would be a free trial by accident. A `suspended` one was stopped
deliberately, with a reason; treating that like administrative drift would make
suspension useless in the one case anybody reaches for it.

In every blocked state the account surface stays readable — `entitlement`,
`auth/me`, `auth/logout`, `auth/refresh`, `health`. Blocking `/entitlement`
would be self-defeating: it is how the app learns it is pending, so refusing it
leaves the client unable to render the screen explaining the refusal.

### A status nobody recognises

Reads as `expired`: writes refused, nothing hidden.

Not hypothetical. **This MySQL server runs with an empty `sql_mode`**, so a bad
ENUM written outside Prisma is silently coerced to `''` rather than refused.
Falling through to the date logic would have made a corrupted row behave as
`activated` — the most permissive state there is, reached by accident.

## Registration

One transaction creates the company, its first branch, the Owner, a
`pending_activation` subscription and a `registered` event.

**The shopkeeper types no identifier we invented.** No Store ID, company id,
branch id, personal ID or tenant code. Every internal reference is generated
server-side. Asking somebody to remember our identifiers is how the old sign-in
became unusable; registration is not the place to reintroduce it.

They give: their name, the business name, a first branch (defaulting to "Main
Store", editable), a city, **an email or a WhatsApp number — at least one**, a
password and a language.

### Idempotency

The client sends its own key, unique-indexed. A dropped response on a bad
connection is the ordinary case in a Nouakchott shop, and two companies with
the same name and no way to tell which is yours is a mess the shopkeeper cannot
fix themselves. A concurrent duplicate loses on the unique index *before*
either has created a company, and is handed the winner's result.

A contact collision never says so. Confirming that an address is already
registered would let anybody test addresses against the platform.

## Administrative grant vs. payment

Kept scrupulously apart, because collapsing them would let a test activation
look — months later — exactly like a shop that paid.

**An administrative grant**: we gave this shop access, for a reason, for a
period. It sets the complimentary fields, writes an `administrative_grant`
event with the actor and reason, and **creates no payment row**. Proven live:
after a grant, `subscription_payments` for that company is empty.

**A payment**: a named person says they saw money arrive. Its own append-only
table with amount, MRU, date, channel, reference, note, who recorded it and who
confirmed it. Recording one does **not** extend anything — an administrator
records what they saw, then extends as a separate, separately audited act.
Bundling them would mean a mistyped amount silently moved an expiry date.

**No payment provider is integrated.** `confirmedBy` means "this named
administrator says the money is real", never "Bankily confirmed it". Every
payment response carries `providerVerified: false` explicitly. Corrections are
compensating rows; the table refuses deletion from the application account.

## Platform administrators are not Owners

Their own table, with no `company_id` at all.

A `RoleKey` on `users` was rejected because a tenant role lives *inside* a
company — a shop able to create roles would have a path, however indirect, to
minting a platform administrator. There is nothing here for a tenant to attach
to. Sessions are a separate table too: a shared one would mean a single bug in
tenant session lookup could return a platform session.

- Created **only** by `prisma/create-platform-admin.ts`. No HTTP route, and no
  default credential anywhere in the repository.
- The password comes from `PLATFORM_ADMIN_PASSWORD`, never an argument —
  arguments land in shell history and the process list.
- Sessions ride an **HttpOnly cookie**. This portal reaches every business on
  the platform; a token in `localStorage` would put that behind any injected
  script. A bearer header is accepted **outside production only**, so tests and
  the live harness can drive the API.
- Sign-in is rate-limited and non-enumerating, and spends one Argon2 verify on
  every path.
- High-impact actions — grant, extend, suspend, reinstate, cancel, payment —
  require the administrator's password again. A laptop left open is the
  ordinary case.
- Sign-out revokes the session that authenticated *that request*.

### `@Public()` on an administrator route

It does **not** mean "anyone may call this". It tells the global *tenant* auth
guard to stand down — that guard looks for a shop's JWT, which an administrator
does not have. Without it, every administrator request is rejected before
`PlatformAdminGuard` runs. It was, and the live check caught it: thirteen
routes returning 401 to a perfectly good session.

## Tenant privacy

The platform view returns business identity, Owner contact and verification
state, subscription status, entitlement, branch and user counts, and payment
and grant history.

It returns **no operational business data** — no sales, no IMEIs, no cost
prices, no margins, no expenses. Not by filtering: the query cannot return
them. Being able to see a shop's takings is not part of administering a
platform. There is no impersonation.

Every mutation writes an immutable audit event with actor, action, target,
reason, timestamp and before/after state. The table is append-only by trigger,
and a redaction pass strips anything credential-shaped before it is written —
an audit log is exactly where a careless spread of a request body goes
unnoticed, because the record looks fine and the password is three levels down.

## Contact verification is not 2FA

Proving somebody holds a contact, once, at registration. Optional login 2FA is
a different feature and **does not exist**.

**No delivery provider is configured**, so what exists is the boundary a real
one slots into, plus a development outbox. The rule: never claim a message was
sent when nothing sent it. A "code sent" screen in front of a provider that
does not exist is worse than an honest refusal — the shopkeeper waits for a
message that is never coming. Production with nothing configured therefore gets
a provider that **throws**, never the outbox, and codes are never returned from
any endpoint in production.

## What is not built yet

Scoped deliberately, and agreed before starting: the backend contract first, so
the web surfaces are built on something proven rather than in parallel with it.

- **The web project.** Public registration, customer portal and administration
  portal. No web project exists; it will need its own repository, and will have
  **no configured remote** until one is created.
- **Mobile integration** — the `Create account` link and the pending/suspended
  status screens. The link needs a signup URL, and there is nothing to point it
  at yet; shipping dead UI would be worse than waiting.
- **Contact verification end to end** — the tables, the provider boundary and
  the outbox exist; the registration flow does not yet require a verified
  contact.
- **Plans and pricing** — see "No money, deliberately".
- **Administrator MFA**, and a real contact/payment provider. Both are named in
  the handoff as unresolved production-security work.

## Production security still outstanding

Public deployment of the administration portal needs, at minimum:

1. **Administrator MFA.** Password plus step-up is what exists. No fake toggle
   is shown, and none should be added until it is real.
2. **A real contact-delivery provider**, so verification means something.
3. **A payment provider** if payment confirmation is ever to be more than a
   named person's word.
4. A physical and security review of the deployment itself — TLS termination,
   cookie `secure` in production, IP allow-listing, and where the portal is
   reachable from.
