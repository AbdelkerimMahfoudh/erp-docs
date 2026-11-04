# 117 — Post-Build-4 candidate (owner's brief and clarifications, 2026-11-03)

Status: **candidate, not deployed, no TestFlight build.** Production stays backend `b945098`, admin console `bb620d03`,
Build 4 1.0.0 (4) internal. Branch `post-build4` in each code repository, from those released heads.

## 1. Commits

| Repository | Commits (oldest first) | Head |
|---|---|---|
| erp-backend | `c6701ee` step-up window · `3a1157c` business deletion (0128) · `4785adf` account-ready link (0129) · `6d96513` audit pins | `6d96513` — security CI 41731065469 success |
| erp-control-web | `9e229a23` window reuse, deletion panel, `/claim` page · `268f8b24` test type | `268f8b24` — ci 41731077576 |
| erp-mobile | `02c4645` unlock wording, countries, phone row, sign-in numbers · `948894d` package allowlist | `948894d` — security 41731086956 success, render-tests 41731109381 success, visual-check 41731127831 |
| gates | ops/render-tests `7b3fae3`, ops/visual-check `36abbd9` (mobile `948894d`, backend `6d96513`). First runs failed on pins the new code needed (bilingual audit, seat readers, package allowlist, a test type): fixed, not weakened. | |

## 2. Migrations and rollback

- **0128 `business_deletion`** — additive: `companies.deleted_at`; `business_deletions` (one row per business, `prepared`
  then `completed` once; triggers refuse a delete and any change to who prepared it, or to a completed row, for
  `phonestore_app`). **New rollback floor:** code built before 0128 is a rollback target only while
  `business_deletions` is empty (`rollback.sh`, pinned by `deploy-production.spec`).
- **0129 `portal_claim_links`** — additive table; code before it ignores it. No floor.
- Rehearsed on the disposable 8.4.7 database (`grace_ci`, 0127 → 0129). The production-schema rehearsal
  (`deploy/rehearse-migrations.sh` with `PROD_SCHEMA`) is still to run before deployment.

## 3. Admin step-up window (item 5)

Not rebuilt: the existing five-minute step-up (0094) is now the whole proof. `requireStepUp` replaces the per-action
password on all 40 admin mutations (the boundary specs pin every one). Absolute: five minutes from verification; use
never extends it. Same session only. Ends on sign-out, revocation (every session ends on a password or authenticator
reset), a disabled or deleted administrator; administrators have no roles. Audited: `admin.step_up` (opened),
`admin.step_up.used` with the route, `admin.step_up.expired` / `.revoked` once. `GET platform/admin/step-up` returns only
the expiry. The console reuses the window, shows "Verified for m:ss", and no longer sends the password with a decision.

## 4. Business deletion — exact retention behaviour (items 6, clarifications 2-4)

**Prepare** (one transaction under the subscription lock; needs the window): subscription → `cancelled` (outranks a
grant or a running trial) with a `subscription_events` row; trial eligibility closed; business `is_active = false`;
every `auth_sessions` row of the business revoked (app and portal); open claim links revoked; queued messages cancelled;
two platform audit records, `business.deletion.subscription_cancelled` (with `refund: none`) and
`business.deletion.deactivated`; the `business_deletions` row. Refused while a payment proof is submitted or under
review, a seat awaits payment, or an Owner's own deletion is in progress. Repeated: nothing new.

**Delete** (needs the window, the exact business name, and the backend's own checks: prepared, inactive, no usable
subscription, nothing pending). Applies the Owner-closure de-identification (`AccountDeletionService.closeCompany`):

- removed or anonymised: every person's name ("Deleted user"), login, personal ID (replaced), phone, email, password
  and PIN (unusable), sessions' IP/device/agent, devices' labels, OTP destinations, verification intents, credential-change
  contacts, invitations, owner identities; customers' names, phones and notes; suppliers' phones and notes; people
  counterparties; payer numbers and their fingerprints; money-agent customer numbers; free-text notes; expense receipt
  files (removed from storage after commit); branch phones and addresses; registration contacts; payment-proof images
  (`file` null, `purged_at` set); the business's names; notifications and sync outbox;
- kept, de-identified and marked by `companies.deleted_at`: sales, purchases, closings, ledgers, stock and catalogue
  rows they reference, subscriptions, `subscription_events` and payments, `audit_logs`, `platform_audit_events`
  (its older rows may still name the business: append-only), money-agent append-only snapshots, backups until rotation
  (up to 6 months for the monthly copies);
- **none of the 37 delete-protected tables is touched by a delete**; the spec runs as `phonestore_app`, so a bypass
  would have failed;
- recorded: `business_deletions` `completed` (who, when, `retention_policy = deleted-business-v1`, counts only),
  an `audit_logs` row in the business's chain, `business.deletion.completed` in the platform audit. Retried or raced:
  the same result, recorded once.

## 5. Portal (item 7) — not yet published

- `dukan.tsxmr.com` has **no DNS record** and no edge site: never published.
- The production portal build already holds no console code (`protected-areas.owner.tsx`; CI's `customer-audit` job
  checks the artefact for console code). Added: `/claim/:token`.
- **Held**, for two reasons: the claim page needs backend `4785adf` deployed (owner's release boundary: review first),
  and the production install script for the portal is not written yet (`admin-site.sh` is the model: refuse a wrong
  host or an artefact holding `/admin`, validate the edge, check live HTTPS). The edge site must also turn off access
  logging under `/claim/`. Then the Cloudflare `A dukan.tsxmr.com` record, HTTPS checks, and `PORTAL_LIVE=enabled`.

## 6. Account-ready message (item 8) and the template

- Queued after the verification commits (existing outbox, unique per eligibility); sent by the worker with bounded
  retries; consent and number checks unchanged; "not sent" recorded with its reason; never rolls the account back.
- **Held** (pending, rechecked hourly, attempts not spent) until `PORTAL_LIVE=enabled` **and** an approved template name
  is configured. Its link is issued only when it can go: SHA-256 stored, 72 h, single use, spent in the transaction
  that opens the portal session; a resend's message revokes earlier links; closure, prepare and deletion revoke all.
  Reissue: the portal's resend, and the console's `POST platform/businesses/:id/account-ready/resend`.
- Template mapping the backend expects: `WHATSAPP_TEMPLATE_PORTAL_INSTRUCTIONS=dukan_account_ready`, category UTILITY,
  languages `en`, `fr`, `ar`; body `{{1}}` = the business's display name; one URL button,
  `https://dukan.tsxmr.com/claim/{{1}}`, `{{1}}` = the link. Neutral copy: the account is ready; the button opens Dukan
  to complete the setup and manage the subscription. No trial promise.
- **Meta status: not submitted.** Needs the owner's Meta Business session and go-ahead at submission.
- Scope note: as before, the message goes to businesses that may claim the free trial (public registrations).
  Administrator-provisioned accounts keep their Owner invitation.

## 7. Mobile (items 1-4)

- "Require unlock after" / "Redemander le déverrouillage après" / "طلب فتح التطبيق مجددًا بعد", with the explanation
  that Dukan stays open and access is locked; same five choices and the same Owner-maximum rule.
- Countries: `libphonenumber-js` 1.13.15 (runtime; metadata derived from Google's libphonenumber project) and
  `i18n-iso-countries` 7.14.0 (dev only: names generated into `lib/phone-country-names.ts`, EN/FR/AR). 245 regions, Mauritania first, then alphabetical in the reading language (owner, 2026-11-03). The console phone field uses the same module, with a search box above its list (console `9366b085`, mobile `e3df1ef`).
  Bundle: about 84 KB of calling-code metadata plus 15 KB of names before minification; the render gate's export
  measures the real figure.
- Sign-in: `identifierKind` — `U-XXXXXXXX` staff IDs and emails are sent as typed; a number gets the sign-up's country
  chooser and is normalised only when sent. Personal IDs always carry `U-`, so no number is ever read as one.

## 8. Not done or not verified

- RTL, large-text and 320/375-point
  checks of the new country sheet are not run on a device; the render/visual gates cover the web export only.
- Portal publication, the portal install script, the Meta template, the production-schema rehearsal of 0128-0129.
- Pass 2 tests 3-8 on Build 4 (postponed by the owner).

## 9. Owner's pre-approval items (2026-11-04)

### 9.1 Step-up invalidation, proven
`src/platform/step-up-invalidation.spec.ts` with `platform-mfa.service.spec.ts`: an administrator's password is written
only by the CLI reset (revokes every session and window) and by an invited administrator's setup (before `active`; a
window needs `active`); a new authenticator only through the server's enrolment token (revokes every session); platform
administrators have no role or permission to change, and their state is read on every check. Backend `861da3e`.

### 9.2 Deletion retention matrix (backend `552d508`)
| Area | Removed or anonymised | Kept, de-identified, marked by `companies.deleted_at` |
|---|---|---|
| Staff | names → "Deleted user", logins, personal IDs replaced, phones, emails, passwords, PINs, sessions, devices, codes, invitations | the rows their records point at |
| Customers | names, phones, notes | the rows (sales point at them) |
| Stock (units) | IMEIs, serials, photos (files removed) | units, costs, prices, statuses |
| Catalogue / products | — (business data, no person) | as they are |
| Repairs | description → "Repair", notes | amounts, dates, statuses |
| Transfers | decision reasons | the transfers and their lines |
| Consignments | the business's own unshared ones: notes, dispute reasons | shared ones stay the other business's record; `consignment_ledger` (protected) untouched |
| Closings | notes | figures and lines |
| Expenses | notes, receipt files removed | amounts, categories, dates |
| Uploaded documents | expense receipts, payment-proof images, unit photos, the logo, report exports | — |
| Money agent | customer numbers and fingerprints, people's names where allowed | amounts and legs; append-only snapshots (protected) |
| Subscription, payments | proof images | subscription, events, payments |
| Audit | — | `audit_logs`, `platform_audit_events` (protected; older platform rows may name the business) |
No delete statement touches any of the 37 protected tables; the real-MySQL spec runs as `phonestore_app`. Backups keep
data until rotation (monthly copies up to 6 months).

### 9.3 Two separate gates
`PORTAL_LIVE=enabled` means only: the portal is deployed and a real claim flow was verified (§9.5). It does not depend on
Meta. The sender holds independently on each: `held_portal` until `PORTAL_LIVE`, `held_template` until an approved
template name is configured (`notice.service.ts`). The portal works while Meta reviews.

### 9.4 Production-schema rehearsal, 2026-11-04 00:13Z — PASS
Read-only fetch `prod-schema-20261104T001238Z.sql` (sha256 `3413927b…`; 139 tables, 72 triggers, last 0127). 0128 and
0129 applied; a second deploy applied nothing; identical to a fresh install (141 tables, 1979 columns, 74 triggers);
restore of the base dump: row counts and CHECKSUMs identical. Not deployed. The production backup and its restore drill
are part of the deployment itself (docs/116 §2), as for D227.

### 9.5 Portal verification plan, before `PORTAL_LIVE=enabled`
The production portal build is closed by the console's own `PORTAL` gate (`src/config/gates.ts`: backend in production,
email and WhatsApp proven). Opening it is the owner's decision; until then CI builds and checks the package in audit
mode (console `889bb1e2`), and `portal-site.sh` refuses an audit package. `portal-site.sh` is executed on Linux in
backend CI (`src/prisma/portal-site.spec.ts`).
1. Backup and off-host copy; deploy backend (0128-0129); `PORTAL_HOST`, `CORS_ORIGINS` and `PORTAL_ORIGIN` set.
2. Build, package, `portal-site.sh install`; Cloudflare `A dukan.tsxmr.com` (DNS only).
3. HTTPS and certificate; `/subscription` and the status page in EN/FR/AR; `/admin` 404; noindex; no referrer.
4. On the Test business: issue a link from the console, open it once (session opens, trial not started), open it again
   (refused: used), an expired link (refused: expired), reissue (earlier refused), claim on the page and check the trial
   starts then, for seven days.
5. Edge and API logs: no `/claim/` token, no full claim URL.
6. Only then `PORTAL_LIVE=enabled`. Messages stay held until the template is approved.

### 9.6 Meta template — prepared, not submitted
Name `dukan_account_ready`; category UTILITY; languages `en`, `fr`, `ar`; body variable `{{1}}` = business name;
one URL button, dynamic, base `https://dukan.tsxmr.com/claim/{{1}}`. Proposed text, EN: "Your Dukan account for {{1}}
is ready. Open Dukan to complete the setup and manage your subscription." Button: "Open Dukan". FR: "Votre compte Dukan
pour {{1}} est prêt. Ouvrez Dukan pour terminer la configuration et gérer votre abonnement." Button: "Ouvrir Dukan". AR:
"حسابك على دكان لـ {{1}} جاهز. افتح دكان لإكمال الإعداد وإدارة اشتراكك." Button: "افتح دكان". Review status: not
submitted; sending stays disabled until approved.

### 9.7 Device checks
The country list in Arabic, the largest text size and the 320/375-point layouts are **not passed**: pre-external-TestFlight
blockers, with Pass 2 tests 3-8.

## 10. Two defects added to the candidate (owner, 2026-11-04)

### 10.1 Signup with a contact that already has an account — backend `4698712`, mobile `d3e996d`
- **Root cause.** D227 kept a known number in a "hold": the same answer as a new signup, a real code sent, and
  "already has an account" only after the code. That path answered "That code did not match" for an expired hold and
  for a superseded or expired challenge too. **The screenshot's message could therefore hide the duplicate**: the
  backend did not convert a conflict into an OTP error directly, but its hold path gave the OTP wording to non-OTP
  failures. Which applied to that attempt cannot be read back: holds and challenges keep no per-attempt outcome.
- **Now.** Refused at the contact step for the number or the email, before any code is generated or sent and before
  anything is created: `409 CONTACT_UNAVAILABLE_FOR_SIGNUP`, generic, audited without the contact
  (`registration.contact_unavailable`), behind the registration throttle. A lost race for the unique index gets the
  same answer. Wrong, expired and superseded codes for new contacts keep their own errors. `normalisePhone` now reads a
  leading `00` as the international prefix (production stores no such number: 0 identities, 0 users).
- **App.** EN/FR/AR message, with Sign in, Recover access (the existing setup-code screen) and Use another number.

### 10.2 Partner stores: "the code does not exist" for every code — backend `ced13ce`, mobile `071bce1`
- **Root cause.** Exact-code lookup and the request required `is_discoverable = true`; nothing in the backend or the
  app ever sets it. Production, read-only: 10 businesses, every code valid (10 characters, uppercase), **0
  discoverable** — every lookup was a 404. Not an API base mismatch, a tenant filter, ID confusion or normalisation.
- **Now.** An exact code finds the store; name search keeps its opt-in. Distinct answers, localised in the app:
  invalid, unknown, own code, inactive/closed/deleted, pending (shown as the relationship), already partners.
  Only the public preview before acceptance. Lookup and request throttled (20 a minute). A store in the same
  business shares the business's code, so it is "own code".
- **Journey on real MySQL** (`connections.mysql.spec.ts`, two businesses, as `phonestore_app`): A's code found by B in
  lowercase with spaces, without search; B asks; A sees and accepts; both see it accepted; retries add nothing.
- **Production:** no migration and no backfill.

### 10.3 Recover access — not offered yet (mobile `275de9c`)
`/(auth)/setup` is a console-created Owner's first password from an administrator's one-time setup code: no fresh
verified challenge, so it is not an account recovery and is not reused. The refusal offers Sign in and Use another
number only. **Required work:** a recovery screen that proves the contact with a fresh code, refuses old invitation or
setup codes, and follows the password-change policy (rotate the password, end every other session).
