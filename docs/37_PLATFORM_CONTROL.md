# 37 — Platform control: registration, subscriptions, administration

> The backend contract for the platform-control product.
>
> **Phase 1 (this document) built the contract; Phase 2 built the website and
> the pricing on top of it** — see "Phase 2 — what changed" at the end, and
> [`docs/38`](38_CONTROL_WEBSITE.md). Where the two disagree, Phase 2 is
> current; the Phase 1 text is kept because it records WHY each decision was
> taken.

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

---

## Phase 2 — what changed

The "not built yet" list above is now largely built. See
[`docs/38`](38_CONTROL_WEBSITE.md) for the website itself.

### Pricing exists, and it is the server's

`docs/37` said "no money, deliberately", because no plan or price existed
anywhere. The approved Standard plan now does: **500 MRU per active branch, two
staff included per branch pooled company-wide, 100 MRU per additional active
non-Owner account**, integer MRU, no prorating, no trial, 72-hour grace.

Two models carry it, both additive (`0058`):

- **`plan_versions`** — the plan's price over time, effective-dated. A version
  may never start in the past.
- **`billing_periods`** — an immutable snapshot per period. It **copies** the
  unit prices rather than joining to the plan, so a new price scheduled tomorrow
  cannot rewrite what a shop was told last March. It keeps a high-water mark
  **per component**, which is what stops a branch added mid-period from
  refunding an extra-staff charge already assessed.

The dashboard still shows **no revenue figure**. Payment history is still
incomplete by construction.

### Contact verification exists

`contact_verifications` was created in `0056`; the service and the routes are
now real. Codes are purpose-bound to a destination, single-use, short-lived,
attempt-limited, rate-limited, and stored only as a hash folded with the
destination — so a code stolen for one contact cannot be replayed against
another.

**No provider is configured.** The development outbox handles delivery, the
registration screen says plainly that nothing was sent, and production gets a
provider that throws rather than one that lies.

One bug worth recording: the outbox was provided with `useClass`, which made
Nest build a **second instance** — so the outbox that stored a code and the one
that was later read were different objects, and the code was silently never
found. `useExisting` aliases the single registered instance. The browser found
this; no test did.

### The website exists

Public registration, the customer portal and the administration portal, in one
React + TypeScript application with three separately guarded route areas. Setup,
security and operations are in [`docs/38`](38_CONTROL_WEBSITE.md).

### Mobile integration exists

A configured `Create account` action on the login screen, and pending,
suspended and expired screens driven by the server's state with no date
arithmetic on the device.

### Still outstanding

Administrator **MFA** · a real **contact-delivery provider** · a **payment
provider** · **domain, DNS and TLS** · a deployment and security review. None is
faked, and no toggle pretends otherwise.

---

## Deploying: the permission catalogue

**A tenant's authority is only ever as complete as the catalogue behind it.**
`AccessService` resolves permissions solely from `role_permissions`, and those
rows can only reference `permissions` rows that exist. A short catalogue does
not error — it silently narrows what every role can do.

Until migration `0059` **no migration created the catalogue**. The base keys
lived only in `prisma/seed.ts`, which also seeds the demo company and so never
ran against staging or a real deployment; a deploy-only database held 44 of the
61 keys. The seed concealed it by doing both jobs at once — every environment
anybody looked at had run it.

### The deployment sequence

```bash
npx prisma migrate deploy                              # schema + reference data
npx ts-node scripts/verify-permission-catalogue.ts     # gate: non-zero on failure
```

**Do not run `prisma db seed` to fix a deployment.** The seed creates the demo
company. It is a development convenience, not a repair mechanism, and
deployment no longer depends on it for anything.

The gate never deletes. An unknown key fails it and is reported for a person to
decide about, because removing one automatically could revoke authority a
deliberate change granted.

### Adding a permission later

1. Add it to `src/rbac/role-permissions.ts` — the one canonical source.
2. Decide, explicitly, which roles receive it.
3. Create a **new** reference-data migration with
   `scripts/generate-catalogue-migration.ts`.
4. Never edit `0059`, or any applied migration. Every database that already ran
   it would silently stop matching the file that claims to describe it.

`permission-catalogue.spec.ts` fails the build if the canonical source and the
migration drift apart, and if a second whole-catalogue migration ever appears.

---

## Phase 3 — registration moved into the app, and what a live run found

Everything under "What is not built yet" above is now stale in the ways that
matter, and is kept for the record rather than corrected in place.

- **The web project exists** (`retail-erp-control-web`) — the retired public
  registration page, the customer portal and the administration portal. See
  [`38_CONTROL_WEBSITE.md`](38_CONTROL_WEBSITE.md).
- **Mobile integration exists**, and is no longer a link to a website.
  Registration happens in the app: `app/(auth)/register.tsx` and
  `app/(auth)/verify.tsx`.
- **Contact verification is end to end**, and it is what issues the session.
- **The subscription lifecycle is exercised**: quote, administrative grant,
  suspend, reinstate, and an entitlement the app re-reads without reinstalling.

### The chain that issues a session

```
registration attempt
  + a 15-minute, hash-only, single-use continuation
  + the exact verification challenge bound to that continuation
  + atomic consumption of both
  = one ordinary Owner session from SessionsService
```

A destination-wide `isVerified()` never issues a session. The registration
password is never replayed. Registration and portal handoff hold **distinct**
purposes in `verification_intents`, so neither ticket can be spent as the other.

### Who may mint a portal handoff

**The Owner, and the company administrator.** Gated on `settings.manage`, which
is company-scoped, never delegatable to a branch, and held by nobody else.

This was found by acceptance, not by design review: the route carried no
permission at all, and a real Store Manager and a real Store Employee each
minted a ticket over HTTP and got `201`. The portal is the account surface —
what the shop is charged, what it owes, how to pay. A manager runs a branch; an
employee sells. Neither settles the bill.

A **pending** Owner may still mint one, and must: every newly registered shop is
pending by definition, and this is the route to the page that ends that state.
It is the only `platform/` route in the entitlement allow-list, pinned by name.

### Two things a live run found that no test had

1. **The one-time ticket was written to the log in full.** `redact.paths` covers
   headers and body fields but cannot see inside a URL, and `autoLogging` wrote
   `portal-session?t=<ticket>` twice per request — twelve times in one run.
   Fixed in `common/http/log-scrub.ts`; the path is kept and the value replaced,
   so a request is still followable.
2. **A pending shop could not read the payment instructions.**
   `platform/payment-instructions` sat outside `ALWAYS_READABLE`, so the
   entitlement guard answered `ENTITLEMENT_PENDING` — and because the portal
   treats an instructions failure as non-fatal, the payment dialog silently
   never opened, for the only kind of shop that needs it.

## Production security still outstanding

Unchanged from above, with one item now settled and one sharpened:

1. **Administrator MFA.** Still password plus step-up. Still no fake toggle.
2. **A real contact-delivery provider.** Verification codes are retrieved with
   `scripts/staging-verification-code.ts`, which requires shell access to the
   staging host and answers about one contact you already named.
3. **A payment provider.** All five providers show the placeholder `00000`.
   Production must refuse or replace those before launch.
4. **Cookie `secure` is now an explicit setting**, not a guess from `NODE_ENV`.
   See `cookieSecure()` in `common/http/cookies.ts` and `COOKIE_SECURE` in
   [`39_STAGING_ENVIRONMENT.md`](39_STAGING_ENVIRONMENT.md). **Production must
   leave it unset or `true`** — turning it off puts session cookies in clear
   text. TLS termination in front of the edge is still deployment work.

---

## Phase 4 — a shop to look at

### The retained fixture

Staging now holds one deliberate shop, `Test Store`, alongside the retained
acceptance tenants. It exists because a platform-control surface with nothing
real behind it is hard to judge: the pending queue, the grant, the quote and the
audit trail all read differently when there is a shop with stock in it.

It is provisioned through the same services as a real signup, activated by the
same audited administrative grant, and carries **no fabricated payment**. The
grant is complimentary and says so; `currentPeriodEnd` stays null so a grant can
never be mistaken for money that arrived. Details and guards in
[`39_STAGING_ENVIRONMENT.md`](39_STAGING_ENVIRONMENT.md).

### Who may still mint a portal handoff

Unchanged from Phase 3 — the Owner and the company administrator, gated on
`settings.manage` — and re-proved live against this fixture: the Owner mints a
ticket (`201`) and a Store Manager of the same shop is refused (`403`).

The mobile app now reaches the portal through **one** helper from every entry
point. The subscription-blocked screen used to open the account URL with no
ticket at all, which meant the one screen where somebody taps "manage my
subscription" put an authenticated Owner in front of a password form.
