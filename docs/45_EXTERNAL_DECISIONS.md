# 45 — External decision register

Ten decisions only the owner can make. **No vendor was selected, no account
created, nothing purchased, no DNS changed, nothing deployed.**

"Latest safe date" is relative to the intended launch, written as **L**. They
are ordered by how much work follows the decision, not by how urgent they feel —
a domain is one form to fill in and everything else waits on it.

---

## Summary

| # | Decision | Blocks staging | Blocks production | Latest safe date |
|---|---|---|---|---|
| D1 | **Domain** | ⚠️ partly | 🔴 **yes** | **L − 4 weeks** |
| D2 | **DNS hosting** | ❌ | 🔴 yes | L − 3 weeks |
| D3 | **TLS certificates** | ⚠️ partly | 🔴 yes | L − 3 weeks |
| D4 | **Application hosting / runtime** | 🔴 **yes** | 🔴 yes | **L − 4 weeks** |
| D5 | **Database hosting** | 🔴 **yes** | 🔴 yes | **L − 4 weeks** |
| D6 | **Backups** | 🔴 **yes** | 🔴 yes | **L − 4 weeks** |
| D7 | **Contact-delivery provider** | ⚠️ partly | 🔴 **yes** | **L − 3 weeks** |
| D8 | **Administrator MFA** | ❌ | 🔴 **yes** | **L − 3 weeks** |
| D9 | **Payment provider** | ❌ | ⚠️ **or a written decision not to** | L − 2 weeks |
| D10 | **Monitoring and alerting** | ❌ | 🔴 yes | L − 2 weeks |

Four block staging. **D4, D5 and D6 are the critical path** — they are one
decision in practice, and everything else can be arranged around them.

---

## D1 — Domain

**Why.** Every other decision embeds it. `CORS_ORIGINS`, the portal and signup
URLs baked into the mobile bundle, the TLS certificate, the DNS records, the
sender identity a delivery provider verifies. Choosing it late means redoing all
of them.

**Owner must provide.** The domain name, and who holds the registrar account.

**Then.** Set `CORS_ORIGINS`, `EXPO_PUBLIC_PORTAL_URL`, `EXPO_PUBLIC_SIGNUP_URL`,
`EXPO_PUBLIC_API_ORIGIN`; rebuild the mobile bundle, because those are compiled
in, not read at runtime.

**Blocks:** production. Staging can run on an IP or a temporary hostname, but
anything built against it must be rebuilt afterwards.

---

## D2 — DNS hosting

**Why.** Records for the API, the portal, and whatever a delivery provider asks
for to prove the domain is yours.

**Owner must provide.** Which DNS provider, and account access.

**Then.** Create the records; wait out propagation before TLS issuance.

---

## D3 — TLS certificates

**Why.** `COOKIE_SECURE` and HSTS are already written to assume HTTPS. A
`Secure` cookie on plain HTTP is **silently discarded by the browser** — this
project has already lost an afternoon to exactly that, on a LAN address.

**Owner must provide.** Automatic issuance (Let's Encrypt at the edge) or a
purchased certificate, and who renews it.

**Then.** Terminate TLS at the proxy; confirm HSTS is present in production and
**absent** in staging.

⚠️ Staging must not send `includeSubDomains` — it would pin the parent domain to
HTTPS in every browser that saw it, for six months, long after staging is gone.
`main.ts` already drops HSTS when `APP_ENV=staging`.

---

## D4 — Application hosting and runtime

**Why.** There is nowhere to run the API. Today it runs on a laptop through
WAMP.

**Owner must provide.** Where it runs (VPS, container platform, managed Node),
the budget, and who has access.

**Then.** Process manager with restart, `SIGTERM` reaching the process,
`API_BIND=127.0.0.1` behind a proxy, a mounted volume for `UPLOAD_DIR`, and
`APP_COMMIT` / `APP_BUILT_AT` injected at build time.

**Blocks staging.** Nothing can be rehearsed without a host.

---

## D5 — Database hosting

**Why.** MySQL 8.4 currently runs inside a developer's WAMP install. That is not
a place customer data can live.

**Owner must provide.** Managed MySQL or self-hosted, the version, the region,
and who holds the credentials.

**Then.** Create the two accounts the design already assumes — a migrator and a
least-privilege runtime user, so the application cannot run DDL. Run
`prisma migrate deploy`. Confirm 63 applied, 0 pending.

**Blocks staging.**

---

## D6 — Backups

**Why.** Risk **R3**, and the sharpest one on the register. `docs/22` §5 has said
for weeks that dumps are local-only: *"A disk failure still loses every sale,
unit and audit record."*

**Owner must provide.** Where backups are stored off-machine, the retention
period, whether encryption at rest is required, and — the two nobody has
answered — the **RPO** (how much data may be lost) and the **RTO** (how long a
restore may take).

**Then.** Schedule dumps per `docs/22` §2 including `--hex-blob`, encrypt, ship
off-machine, and run a **restore drill against the current schema**. The last
drill was 2026-08-05 and the schema has moved.

**Blocks staging** — E4 exists precisely so the first real migration is not the
first time anyone finds out.

---

## D7 — Contact-delivery provider

**Why.** Registration issues a session only after a verification code is
delivered. There is **no provider**: `WHATSAPP_CHANNEL` accepts `disabled` or
`development-log`, the module refuses `development-log` in production, and codes
are currently read by shell access to the host. So in production today,
**nobody can register**.

**Owner must provide.** WhatsApp Business API, SMS, or email; the account; the
sender identity; the budget; and — for WhatsApp — the approved template, which
takes provider review time that must be started early.

**Then.** Implement the channel behind the existing `messaging/` seam, set
`WHATSAPP_CHANNEL` and `WHATSAPP_TEMPLATE_AUTH_OTP`, and verify a real code
reaches a real device. The OTP abuse controls (TTL, attempts, cooldown, per-window
and per-day send caps) are already built and bounded.

**Blocks production.** Staging can continue with `development-log`.

---

## D8 — Administrator MFA

**Why.** Risk **R2**. `/admin` is a password plus an edge proxy. There is no MFA
anywhere in the backend, and `main.ts` names the gap in its own comment: bound
wrongly, "the guard would then be a password alone, which is exactly the single
layer the deployment is supposed to avoid while administrator MFA does not
exist." A platform administrator can see and act across **every tenant**.

**Owner must provide.** TOTP (authenticator app) or a hardware key, and whether
it is required for every administrator from day one.

**Then.** Enrolment, a step-up challenge on the administration surface, recovery
codes, and a route for a lost device. Recovery is the part that is usually got
wrong — a bypass that skips MFA is not MFA.

**Blocks production.** No fake toggle exists today and none should be added.

---

## D9 — Payment provider

**Why.** The pricing is approved and modelled — 500 MRU per active branch, two
staff per branch pooled, 100 MRU per extra non-Owner — and `plan_versions` /
`billing_periods` already snapshot it immutably. All five payment providers show
the placeholder `00000`. **No money can move.**

**Owner must provide.** The provider, the merchant account, the settlement
account, and the reconciliation process.

**The alternative, and it is real.** The subscription lifecycle already supports
an **audited administrative grant**: complimentary, marked as such, with
`currentPeriodEnd` left null so a grant can never be mistaken for money that
arrived. Launching on grants while a provider is chosen is a legitimate path.

**Blocks production only if the decision is "take payments at launch".** Either
way it must be written down — production must refuse or replace the `00000`
placeholders before launch.

---

## D10 — Monitoring and alerting

**Why.** Risk **R10**. Structured JSON logs with request correlation exist and
go to stdout, where nothing watches them. `/api/health/ready` reports database
reachability and pending migrations, and nothing polls it.

**Owner must provide.** Where logs go, how long they are kept, and **who
receives an alert at 2am**.

**Then.** Ship logs off the host; alert on readiness failing, error rate,
database unreachable and disk; write the runbook for each.

---

## What was deliberately not decided here

No vendor was chosen and no default recommended, because each of these is a cost
and a commitment. The technical consequences of each option are described so the
decision can be made quickly — but the decision is the owner's, and making it by
implementing one would be making it silently.
