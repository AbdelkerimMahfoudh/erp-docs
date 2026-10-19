# 69 — Seats per store, staff activation, the control website, and four app defects (2026-10-05)

> The phase that followed the subscription separation (`docs/68`). Decisions are in `docs/21` (D135–D144); this
> is the detail: the seat arithmetic with worked examples, the transition and its live runbook, the staff activation
> flow and its routes, what the website genuinely does and what still waits for a provider, the four app defects
> with their root causes, and what was verified where.

## 1. The seat rule, as code computes it

Every store includes **one** employee seat; the Owner never takes one. Each additional seat at a store is a
`seat_allocations` row for that store: **paid** (100 MRU per month, confirmed by an administrator with a reference),
or **granted** (0 MRU: the transition, or a platform decision). A person working at two stores is counted at each
store; within one store a person is counted once. Stores cost 500 MRU per month each, as before.

| Business | People per store (non-Owner) | Seats held | Monthly total | Why |
| --- | --- | --- | --- | --- |
| one store, Owner alone | 0 | — | **500** | the store |
| one store, one employee | 1 | — | **500** | the included seat |
| one store, two employees | 2 | 1 paid | **600** | the second needs a paid seat |
| one store, one employee, one seat bought ahead | 1 | 1 paid | **600** | a held seat is charged whether or not it is filled |
| two stores, one employee each | 1 + 1 | — | **1 000** | each store's included seat |
| two stores, two at one and none at the other | 2 + 0 | 1 paid | **1 100** | seats do **not** pool across stores |
| two stores, the same person at both | 1 + 1 | — | **1 000** | a seat at each store; both included |
| the same, plus one more person at each store | 2 + 2 | 2 paid | **1 200** | one paid seat per store |
| legacy: one store, three employees on 2026-10-05 | 3 | 2 granted | **500** | the transition; nothing charged, nobody out |

What is **charged** is the seats a shop holds; what decides whether one more person may be **activated** is the
head-count against included + held seats at that store (`entitlement-rules.ts` `mayConsumeSeatIn`). The two agree for
every business activated under this rule, because nobody can be activated into a seat the shop does not hold. A
period already open keeps its assessed high-water mark (`assessPeriod`), so the rule change raised no invoice in
flight (tested: `pricing-rules.spec.ts`).

Where it lives: `backend/src/billing/pricing-rules.ts` (pure: `quoteFor`, `estimateFor`, `assessPeriod`),
`backend/src/entitlement/entitlement-rules.ts` (pure: `seatMath`, `mayConsumeSeatIn`),
`backend/src/entitlement/seat-census.ts` (the one query set both read), `backend/src/billing/billing.service.ts`.

## 2. The transition, and the live runbook for `0086`

**Nothing live was touched in this session** (live is unreachable from the container and is still at `0083`; `0084`
and `0085` are themselves still owed through `docs/67` §7). This is the runbook, rehearsed on a disposable copy only.

1. **Backup** per `docs/22` §2 (`--hex-blob`, verified); record the dump identifier in `CURRENT_HANDOFF.md`.
2. **Stop the old API.** `0086` adds two nullable columns and a table and widens one enum; the old API keeps working
   against it, but the new rule is enforced only by the new API, and the transition script must run between the two.
3. **Apply** `0084`, `0085` (owed) and `0086` with `npx prisma migrate deploy` as the migrator identity. `0086`
   backfills `users.activated_at = created_at` for every existing account (nobody reads as pending) and inserts plan
   **version 2** in force from that moment.
4. **Dry-run the transition** with the application's database identity: `npx ts-node prisma/transition-seats.ts`.
   It prints one line per store: people, seats, and what it would grant or convert. **Read it.** This is the audit of
   existing businesses the brief asks for; keep the printout with the handoff.
5. **Apply it**: `npx ts-node prisma/transition-seats.ts --apply`. Granted seats cost nothing; pooled purchases become
   paid seats at the stores that need them; the pooled counter goes to zero. Re-running changes nothing.
6. **Start the new API.** Smoke: `GET platform/plan` answers version 2; an Owner's `GET platform/my-subscription`
   shows `pricing.quote.lines` with one line per store and no store `overLimit` that the printout did not predict.
7. **Rollback** = stop the API, restore the dump (`docs/22` §3), redeploy the previous build. The reverse SQL is in
   the migration header for a database you would rather not restore; a Git rollback does not roll back the database.

Rehearsal record (disposable `prisma_ph2`, MySQL 8.0.46): `0001`–`0086` applied from empty; `prisma migrate diff`
against the schema reports no drift on the new tables (the pre-existing foreign-key naming drift of the hand-written
migrations is unchanged); the transition dry-run listed five fixture businesses, granted one seat where the HTTP
matrix had seated two people on one included seat, and reported nothing to do on a second run.

## 3. Staff activation: the flow and its routes

> **Superseded in part (2026-10-19) by D214** (`docs/21`; branch `whatsapp-consent`, not deployed): creating an
> employee sends nothing; every employee activates from an invitation and accepts the operational WhatsApp consent
> themselves. The routes below are the branch's. Production (`644f4f5`) still runs the earlier routes until the
> owner approves the rollout.

```
Owner (Team) ──POST /users──▶ account PENDING + invitation (reference shown ONCE; only its keyed hash stored)
                               │  invited_at set, is_active 0, placeholder password; NOTHING sent (no WhatsApp, no email)
                               │  seat per store: included / held / request priced (pending_payment)
Owner ──reads out / copies / shares the reference from their own phone──▶ employee
employee ──POST staff/join/open {reference}──▶ business, name, the number's last two digits
employee ──POST staff/join/request-code {reference, number, consent}──▶ pending_unverified consent (employee as actor)
                               │  + the WhatsApp code, only now
employee ──POST staff/join/confirm {reference, code, password}──▶ ONE transaction: code consumed, number verified,
                               │  password set, the bound consent active, the invitation used, the account activated
                               │  when a seat is held (otherwise it waits, as before, for the seat)
administrator ──confirm-payment {reference}──▶ seat paid   (only for a seat beyond the included one)
```

| Route | Realm | Does |
| --- | --- | --- |
| `POST /users` `{name, phone, email?, branchIds[], role}` | Owner (`user.manage`) | creates the pending account and its invitation; `whatsapp_required` without a number; answers `invitation {reference, link, expiresAt}` (shown once), `seats[].state`, `activation.pending[]`; sends nothing |
| `POST /users/:id/invitation` | Owner | a new invitation: the live one revoked and its pending consent concluded `cancelled`; the new reference shown once |
| `POST /users/:id/cancel-invitation` | Owner | withdraws a pending account (soft-deleted, contact released, its seat request withdrawn), revokes its invitation and concludes its pending consent |
| `POST staff/join/open` `{reference}` | public, throttled | the business, the person's name, the number's last two digits; `invitation_unavailable` for every unusable reference |
| `POST staff/join/request-code` `{reference, number, language?, whatsappConsentVersion, whatsappConsentLocale?}` | public, throttled | the typed number must match (`number_mismatch`); records the employee's pending consent and sends the code; again, a new code under the same pending consent while both are valid |
| `POST staff/join/confirm` `{reference, code, password?}` | public, throttled | the atomic confirmation above; `password_required` the first time (the code is not spent by asking); `consent_expired` when the agreement lapsed (24 h) |
| `PATCH /users/:id` on a pending account | Owner | `{isActive: true}` refused (`activation_pending`); a changed number refused (`pending_number_locked`): cancel and add again |
| `GET /users` | Owner | each pending row carries `pending.{phone, email, invitation {state, expiresAt}, seats[]}` — never the reference |

**Removed by D214:** `POST /users/:id/resend-verification`, `POST staff/verify/confirm`, `POST staff/verify/resend`.
**Activation** waits for the verified WhatsApp number and a seat; an email address is optional and never a condition.

Refusals carry codes, never only English: `whatsapp_required`, `contact_in_use`, `activation_pending`,
`pending_number_locked`, `invitation_unavailable`, `invitations_unavailable`, `number_mismatch`, `number_invalid`,
`whatsapp_consent_required`, `whatsapp_consent_outdated`, `delivery_unavailable`, `code_mismatch`, `password_required`,
`consent_expired`, `not_pending`, `reference_required`, `seat_request_changed`, `store_name_in_use`.

Seat and store requests (`docs/68` §9 for bodies): the Owner asks (`platform/my-subscription/seat-requests`,
`store-requests`, `…/withdraw`, all allowed even when the subscription has lapsed — asking to pay is not a business
write); an administrator confirms (`platform/businesses/:id/seat-requests/:rid/confirm-payment`, reference required,
`expectedVersion`), refuses or releases; the queue is `platform/seat-requests?status=`.

## 4. The website

Repository `erp-control-web` (`https://github.com/AbdelkerimMahfoudh/erp-control-web`, published 2026-10-05 — see §7). Built from scratch;
`docs/38` says how to run it.

**Genuinely works, against the backend of this phase:** the public pages with the price list and the server
estimate; the application form with the honest refusal when no code can be sent (and the full verification flow when
the development outbox delivers); Owner sign-in (bearer in memory, or the app's portal cookie; account choice when a
contact is used at two businesses); the status page with its explanation, period, per-store quote, requests
(ask / withdraw), payments and history; the administrator realm with step-up on every decision: overview, applications,
businesses, business detail with every lifecycle decision and `expectedVersion` conflict handling, the seat-request
queue with confirm-with-reference / refuse / release, the audit log, the price schedule. Browser-verified in this
session: 71 screenshots at 375 px and 1 280 px in English and Arabic (`docs/24` §56 lists the file names), direction
`rtl` on the document for Arabic, no horizontal overflow at 375 px.

**Awaits a real provider or configuration — said plainly on the pages, never faked:**

| Need | Where it is configured | State |
| --- | --- | --- |
| Email delivery for codes and notices | the backend's `ContactDeliveryProvider`: today WhatsApp (`WHATSAPP_CHANNEL`, credentials in `docs/20`) and the development outbox; **no email provider class exists yet** | applications and staff invitations by email are refused honestly until one is written and its credentials configured |
| WhatsApp delivery | `WHATSAPP_CHANNEL=enabled` + the Cloud API credentials (`docs/20`) | postponed by the owner; `disabled` everywhere |
| Payment provider (Bankily or another) | `backend/src/platform/payment-instructions.ts` (all placeholders), `erp-control-web/src/providers/payment.ts` (`available: false`) | no destination number, no pay button, no "paid" badge the server did not send; payments are confirmed by hand against a reference |
| HTTPS, domain, cookie `secure` | the deployment; `CORS_ORIGINS` with the site's origin; the API on the site's own hostname (`SameSite=Lax`) | not done |
| Privacy and support addresses | `VITE_SUPPORT_EMAIL`, `VITE_SUPPORT_WHATSAPP` | empty; the Support page says so |
| The payment procedure (how a business pays, who confirms, with what evidence) | an operational decision, then `docs/68` | to be written and rehearsed |

**Do not describe the website as production-ready** until every row above is done and tested.

## 5. The four app defects

| Defect (screenshot) | Root cause | Fix | Verified |
| --- | --- | --- | --- |
| File intake: Samsung rows "No matching product", Accept disabled, no way forward | the review had no path to create a product; the only intake route was `POST purchases/file/parse` | **Create and link product** on the Match sheet (`catalog.manage`): the product form opens filled in from the file, saving links it to exactly the waiting rows and returns; an existing product is used instead of duplicated; no permission → whom to ask, review kept | pure test of the exact scenario (`lib/file-link.test.ts`: two groups, an invalid-IMEI row, cancellation, idempotence, restore); `tsc`, lint; **not on a device** |
| Arabic "Restart required" persists after close/reopen | the notice was "language direction ≠ native direction" at every launch; a build without native RTL support (or Expo Go) never flips, so the notice could never clear and never said why | the verdict `ok / restart / expo_go / unsupported_build` from the actual direction, a remembered request, and the execution environment (`lib/design/direction-restart.ts`); `supportsRTL: true` in `app.json` for native builds | pure test (7 cases); **needs a new native build and a device**: unverified |
| Notifications: "VirtualizedLists should never be nested…" | `Screen` wraps its body in a ScrollView by default; the screen rendered a `FlatList` inside it | `scroll={false}` on Notifications and the price history (the other nested list found by audit); no LogBox suppression | `tsc`; the audit found no other nested list; **not on a device** |
| Notifications: an empty red error toast | every toast caller passes `toErrorMessage(...)` or a catalogue string, which cannot be empty; the caller that produced the blank box was **not identified** without the device | `toast.*` never shows a blank: an error or warning without words shows the app's generic error sentence; a wordless success is dropped; in development the caller is logged with its stack so the source is named on the next reproduction | pure test; **the source is owed** (`docs/24` §56) |

Also: Import stock moved from More and the hubs to the Stock tab header (D141), with the registry and back tests
updated and the legacy deep-link audit still passing.

## 6. Verification record

- **Backend**: `tsc` clean; 184 suites, 3 309 tests; migration `0086` applied from empty on MySQL 8.0.46; the
  real-HTTP matrix `ph2/matrix2.mjs`: **76 checks, 0 failures** — the public plan and estimate; an employee on the
  included seat (pending → wrong code → password required → verified and activated → signs in); a second employee
  whose seat waits for payment (verified but not activated; sign-in refused; confirmation without a reference refused;
  the Owner cannot confirm; confirmed with a reference → activated; repeat = no-op; stale version = 409; one payment
  row; audit carries the reference); a store request opened on payment; both contacts required; duplicate invitations
  (same account), a contact in use (409), cancellation and re-invitation; an expired code and both resends; a person at
  two stores holding a seat at each with the Owner in no head-count; a refused request; a Manager cannot create
  accounts; an expired subscription refuses staff creation but accepts a seat request; production mode: no session
  token in the body, delivery unavailable on both channels with no code anywhere and no verification row written,
  registration refused before saving.
- **Website**: `tsc` clean; 16 tests (parity, no copied strings, no price arithmetic, storage keys, tokens, provider
  boundary, rendered journeys with a mocked API); production build; 71 screenshots against the live preview and the
  disposable API.
- **Mobile**: `tsc` clean; `expo lint` (see the handoff for the count); every node suite; parity 3 301 keys in each
  catalogue; web export; the bundle audit (no subscription price, checkout, purchase link or provider instruction in
  the bundle; shop payment methods present). **Nothing on an iPhone**: `docs/24` §56.

## 7. Publishing the website — the blocker and its resolution

Creating a GitHub repository from this session was refused twice: the GitHub App integration answered
`403 Resource not accessible by integration` to `POST /user/repos`, and the session's GitHub proxy serves only
repository-scoped endpoints. The repository is complete and committed locally (`erp-control-web`, one commit,
trailers included). To publish: create `AbdelkerimMahfoudh/erp-control-web` on GitHub (private), add it to the
session's allowed repositories, then `git -C erp-control-web remote add origin <url> && git push -u origin main`.

**Resolved the same day, 06:05Z.** The owner created `AbdelkerimMahfoudh/erp-control-web`; attaching it to the session
worked at once, but the first push was still refused with `403` — the proxy signs pushes only for repositories the
Claude GitHub App is installed on, and a new repository is not in the App's selection until the owner adds it. Once
added, `git push -u origin main` published `0417bfe`, the single commit, unchanged; `main` tracks `origin/main`:
`https://github.com/AbdelkerimMahfoudh/erp-control-web`. A published repository is not a deployment: nothing in §4's production-readiness list is met by it.
