# 113 — D227, the consolidated release: design and progress

Decisions: `docs/21` D227. This file holds the design, the evidence as it arrives, and the physical-iPhone checklist.

## 1. Status at this writing

**Done and pushed (not deployed):**
- Optional Arabic names, backend only: backend `0a05063`. The console and mobile still validate and warn the old way.
- Goals dormant: backend `8f1dcec`; removed from the app: mobile `cd3f4d9`, `bd191f4`.
  - Mobile jest 59 suites / 507 tests passed before the last pure-test patches; those patched files passed alone.
  - The full pure suite and backend suite have not been rerun on these heads.

**Nothing else in D227 has started in code.** No migration, deployment or build.

## 2. Design settled from reading the code

**Owner identity (migration 0116).**
- `users` is unique only per company. New table `owner_identities`: kind (phone/email), canonical value, company, user;
  UNIQUE(kind, value). Claimed inside the registration transaction, so the database decides a race.
- Production today has one phone on 3 businesses and one on 2 (test and owner businesses). Backfill claims each value for
  its oldest Owner; the others keep working. Nothing is rejected retroactively.
- Rows must be released on account deletion and moved on a contact change. Staff are never in the table.

**Public registration, non-enumerating.**
- Duplicate phone: same response shape, same code sent to that phone. Only after the correct code does the answer say to
  sign in and add a store. Someone without the phone learns nothing. Needs a small hold record, because no company or user
  exists to attach a verification intent to.
- Duplicate email: phone is the proven contact and email is optional, so the email is dropped silently. Limitation: an
  Owner using a new phone and their old email gets a second business, because nothing proves the email at that moment.

**Admin.** Authenticated, so it may see an existing Owner: `existing_owner` refusal plus the explicit audited add-store
route. `CreateBusinessDto` gains a required access basis (payment / grant), reusing `SubscriptionLifecycleService`
`recordPayment` + `approve`, and the grant path. `grantStore` is test-only today; add-store generalises it to "covered by
access in force", else the same basis.

**Sign-in.** `auth.service` `choose_account` already names businesses only after the password. Business → stores comes
after it; never before.

**Security and sign-in.** `OtpService` is reusable: hashed, single use, attempt lock, send limits, conditional update.
- New purposes in both enums (as 0114 did): password change, contact-change authorisation, new-contact proof.
- A `contact_changes` row binds the pending value to both challenges; the final swap is one transaction, including
  `owner_identities`, consent `supersede`/`activatePending`, and session revocation.
- Email channel: `disabled` in production. Provider code exists (`smtp`, Brevo, D181). Flow stays guarded until configured
  and proven; to be identified precisely at the release gate.

**Maintenance.**
- `maintenance.record` uses `user_branch_permissions` with `isDelegatable`, so no new role. Add to the role matrix and its
  drift specs.
- New table with `client_uuid` + request hash, as `expenses` does (unique key, replay, 409 on another payload).
- Money enters one equation: add `maintenanceIn` (+) and `maintenanceOut` (−) to `COMPONENT_SIGN` in `closing/channels.ts`,
  then `INFLOW` in `money-positions.ts`, the closing's expected cash, the rollup (new columns, requested in the same
  transaction per 0081), `period-figures`, reports and exports. Sale columns stay untouched.
- The owner decided (2026-11-01): the form asks where the repair cost left from, required when the cost is above zero;
  it may differ from where the customer's payment went.
- Corrections: a new target in `corrections/correction-targets.ts`, posting reversing legs.

**Money tracking.** `money_anchors` and accounts are per business, the switch is per store. New per-store setting table,
default OFF, with its opening snapshot. `trackedMoney` must hide positions for OFF methods. The drawer stays counted at
closing either way. Goal: no history rewritten.

## 3. Exact next steps

1. Migration 0116 and the owner-identity service; registration hold; tests first; real MySQL.
2. Access basis and add-store. 3. Security and sign-in. 4. Maintenance. 5. Money tracking. 6. Transfer auto-send.
7. Correlation IDs. 8. Rehearse from the production schema. 9. Mobile. 10. Console. 11. Gates. 12. Release.

`goal.manage` stays in the backend catalogue, inert, because its rows and drift specs come from migration 0047. Mobile
no longer lists it.

## 4. Incident A audit, 2026-11-01 (read-only; code and production)

| Question | Finding |
|---|---|
| Portal exists? | In code: console `/subscription` (`src/pages/portal`), sign-in with the store account. **Not live:** `PORTAL_ORIGIN` is `https://dukan.tsxmr.com`, which did not answer from the server or the laptop (no HTTP response, no address returned by DNS), and `/srv/erp-production/web` holds only `app` and `console`. |
| Trial claim | Exists: `POST platform/my-subscription/trial/claim`, with a card in the portal. |
| Receiving accounts | Exists: `GET platform/payment-instructions`, shown on the portal. |
| Amount owed | Stores and seats are priced on the server and shown on the portal; to confirm when the portal runs. |
| Proof upload | **Does not exist.** A payment holds only a reference; no file. |
| Admin approve/refuse of a proof | **Does not exist.** An administrator records a payment; there is no submission to review. |
| Mobile can open it? | **No, by design:** `lib/navigation/no-browser.ts` refuses every outside address. Apple's rules on linking out must be checked before this changes. |
| What was attempted | The `portal_instructions` notice, queued on verification. |
| Why it failed | `template_unavailable`, recorded 2026-11-01 19:36Z: `WHATSAPP_TEMPLATE_PORTAL_INSTRUCTIONS` is not set. With no email on file it ended `no_email`. |
| Template for this purpose? | None configured. docs/101 §240 planned it; a new template is needed. |

Incident B: being fixed by a separate session; not touched here.

Backend D227 work in progress is in `git stash` on erp-backend ("D227 owner identity WIP (0116)", 2aa8835), moved aside for
that fix. One test fake still needs `userBranch` (account-deletion spec); the real-MySQL spec has not been run.

## 5. The Owner portal, `https://dukan.tsxmr.com` (owner approved, 2026-11-01)

**Order, each a condition of the next:** sale hotfix deployed and reconciled → portal build and security tests pass →
virtual host reviewed → rollback prepared → DNS record → TLS → portal live → template approved and proven → first message.
No backend D227 work or stash restore until the hotfix is finished. This business's grant correctly closes its trial
eligibility; that rule stays.

**Found in review.**
- The portal surface included `/admin`. Fixed for production builds (console b3e6bc40; CI builds only preview, so the swap itself is proven at the first production portal build): the console's code is swapped
  out at build time and the bundle audit refuses it. `dukan-test` is a preview build and keeps it, behind its password.
- Existing and suitable: separate HttpOnly `SameSite=Strict` session cookies, a CSRF token, sign-in throttling, a CSP from
  the build's `_headers`, a release gate (`PORTAL`) that refuses a production build without its inputs.
- Still needed:
  - a production `dukan.tsxmr.com` virtual host, without basic auth, on the edge's import path; the Caddyfile has only the
    test sites today;
  - `dukan.tsxmr.com` in the API's `CORS_ORIGINS`, and a check that the session cookies work across it;
  - production `VITE_*` inputs and the legal blockers the `PORTAL` gate names;
  - private proof storage and the review workflow, backend, after the hotfix;
  - tenant-isolation tests for those routes.
- **Rollback:** remove the DNS record and the site file, reload the edge. `tsxmr.com`, `api.tsxmr.com` and the test sites are
  separate blocks and untouched.

**Apple (App Store Review Guidelines, read 2026-11-01; the page shows no date).**
- 3.1.1(a): outside the United States storefront, apps "may not include buttons, external links, or other calls to action
  that direct customers to purchasing mechanisms other than in-app purchase".
- 3.1.3: exempt categories still may not encourage another purchasing method in the app, except on the US storefront;
  developers may contact their users outside the app.
- 3.1.3(c) (organisations) covers access to what was already bought, and says nothing about a link.
- **Conclusion:** no payment link, button, price or call to pay in the iOS app for this release. WhatsApp and the website carry
  it. The app already blocks outside addresses, and that stays.
- This conflicts with the brief's "always reachable from More → Business access". Proposed wording is for the owner's approval.

**Owner's decision on iOS (2026-11-01): the conservative behaviour; see docs/21.** Inactive wording:
- EN: "Your business access is not active. Account information has been sent to your verified WhatsApp number. If you need help, contact Dukan support."
- FR: « L’accès de votre commerce n’est pas actif. Les informations relatives à votre compte ont été envoyées sur votre numéro WhatsApp vérifié. Si vous avez besoin d’aide, contactez l’assistance Dukan. »
- AR: « وصول نشاطك التجاري غير مفعّل. أُرسلت معلومات حسابك إلى رقم واتساب الموثّق لديك. إذا احتجت إلى المساعدة، فتواصل مع دعم دكان. »

**Implemented in mobile `59457e4 f`.** Removed the trial card, its route read and all `trialSetup.*`/`access.trial.*` wording; states read
Not active / Active / Access ended; stores and seats covered and the server's days left are shown; the bundle audit no longer requires
trial text. Who sees the neutral message: `settings.manage` holders; staff keep the state's own words, because the message speaks of
"your verified WhatsApp number". API state values such as `trial_active` remain as protocol values, never displayed.

**App Review (for the release):** honest note as the owner worded it, plus a test account with active access. Not yet created.
**Open:** the message says information "has been sent", which is untrue until the access template is approved and sending.

## 6. Deployment tooling (backend `b0bc4ec`)

Hotfix `fbe4778` is in the D227 history (the owner confirmed it with a real build-3 sale). `deploy.sh` in production now refuses to start
without a receipt from `backup-receipt.sh`, written by `backup-offhost.sh` from the operator's machine: a real 64-hex checksum on both
sides, equal, a non-empty file, at most 4 hours old. Regression spec: `deploy-backup-receipt.spec.ts`. The receipt script is proven by
spec; `backup-offhost.sh` itself has not yet run against the host. Run it first at the next deployment, with the key reloaded.

**Status of the safeguard: NOT complete until Linux CI is green on `e416b38` (owner, 2026-11-01).**
**Supervised gate at the next deployment:** the first real `backup-offhost.sh` run must show remote and local files both non-empty,
with the exact same filename, size and 64-character checksum, and the fresh receipt must validate, before `deploy.sh` starts. Stop if
any value is empty or ambiguous. The multi-item cart is still being designed: not an implementation instruction.

## 7. Access basis and add-store (backend `c964cd1`, not deployed)

- `POST platform/businesses` requires `access`: payment (amount, date, reference, months; recorded, confirmed, then activated) or grant
  (days, reason). A test business takes a grant only. Refused before anything is created. A later failure answers `accessFailed`, and
  retrying the same key finishes it.
- `POST platform/businesses/:id/stores`, customer: covered opens at once, with no Owner request; otherwise `access_basis_required` with
  the amount, and sending it again with a payment opens the store. The priced row stays `pending_payment` meanwhile and opens nothing.
- **Owner's decision (2026-11-01): free until renewal** (backend `93cb24a`, migration 0117). Covers the store's own fee and its included seats for the rest of the current period. Seats beyond the included quota stay chargeable (payment, or a separate audited grant). `seat_allocations.free_until_period_id` names that one period, and `assessPeriod` skips only the store's fee. A renewal's new period does not match, so store and paid seats are billed.
- **Pending requests act by exact id only.** A request found by name answers `pending_request_exists` with its id, untouched, until the administrator sends that id. Scoped to the company.
- **Proof:** `store-grant-renewal.mysql.spec.ts`, real MySQL and the real `extend` + `rollIfDue`: no charge in the period; included seat free; extra seat charged; renewal charges once under concurrent rolls; a grant racing a renewal does not double-charge or leak.
- **Known limit:** `setPeriodEnd` re-dates a running period, so an administrator's correction also lengthens the free time. Pending the owner's call.
- **Lessons:** full suites before pushing; targeted runs missed real failures. CI: backend red from `8f1dcec` to `e416b38`, green at `3b29cab`.
