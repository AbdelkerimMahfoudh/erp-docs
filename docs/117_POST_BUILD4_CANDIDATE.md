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
