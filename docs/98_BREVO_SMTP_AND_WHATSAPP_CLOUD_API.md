# 98 — Brevo SMTP and the WhatsApp Cloud API: what exists, how to deploy it

> 2026-10-17, CLAUDE (local). The owner's brief of 2026-10-17 (Brevo SMTP + WhatsApp Cloud API) and the approval with
> binding corrections, recorded as **D181** in `docs/21`. Backend `reports-export`: `2d575ed` (dependency), `d7869a0`
> (migration 0098), `60832f2` (code and tests), `d0a7495` (references). **Nothing was deployed. No live switch was
> turned on. No real email or WhatsApp message was sent. No template was submitted. Migration 0098 was applied to
> disposable databases only, which were dropped.**

## 1. What exists now

| Area | What it does | Where |
| --- | --- | --- |
| SMTP channel | `EMAIL_CHANNEL=smtp`: Brevo relay, port 587, STARTTLS **required**, TLS 1.2 minimum, verified certificate, connection/greeting/socket timeouts, debug off. Failures classified from the transport code and SMTP reply code only — never the reply text, which can echo a login or an address. | `src/messaging/smtp-email-channel.ts` |
| Senders | Per class: codes and security → `EMAIL_FROM_VERIFICATION`; operational (trial setup) → `EMAIL_FROM_NOTIFICATIONS`; empty class → `EMAIL_FROM`. `EMAIL_FROM_REPORTS` / `_RECEIPTS` exist in configuration only (D111: no report or receipt email). Reply-To: `EMAIL_REPLY_TO`. | `email-channel.ts` (`senderFor`) |
| Email copy | Every email has a text and an HTML alternative from the same reviewed EN/FR/AR text. Variables HTML-escaped; Arabic `dir="rtl"` (codes and links kept left-to-right); no image, pixel, stylesheet or remote resource; only an `https://` setup link becomes a link. | `email-channel.ts` (`renderEmailHtml`) |
| Email records and limits | One `email_messages` row per logical message (no body, code, link or full address). Internal daily safety limit (`EMAIL_DAILY_SAFETY_LIMIT`, 300, per UTC day) with a reserve only codes may use (`EMAIL_DAILY_RESERVE`, 50), and a per-recipient daily limit (`EMAIL_RECIPIENT_DAILY_LIMIT`, 20). If the records cannot be read, nothing is sent. | `email-log.ts` |
| Email retries | A temporary failure (timeout, 4xx, connection) is retried once by the caller **with the same code and the same idempotency key** — no new code. The retry carries the same Message-ID, so a recipient whose first copy did arrive sees one message, or two identical valid ones. A key already accepted is answered as accepted without a second send. | `platform/contact-delivery.ts` (`sendWithOneRetry`), `email-log.ts` |
| Resend | Unchanged and dormant (D181 §2). If ever enabled it is recorded and limited the same way. | `email-channel.ts` |
| WhatsApp controls | `WHATSAPP_CHANNEL=disabled\|cloud` (`cloud-api` still accepted), `WHATSAPP_MODE=test\|live`, `WHATSAPP_TEST_RECIPIENTS`, `WHATSAPP_LIVE_SENDS=disabled\|enabled`. Graph API `v26.0` by default. | `env.validation.ts`, `messaging.module.ts` |
| Send policy | Around the Cloud API adapter: test mode reaches **only** the exact allowlist; live mode sends nothing until `WHATSAPP_LIVE_SENDS=enabled`; the delivery check (`delivery.check`) only in test mode; a withdrawn channel stops everything; an opt-out stops optional notices; in live mode an optional notice needs a recorded consent; pacing per sending number and per recipient. Every decision is a `whatsapp_messages` row — no variable, code, token or full number. Never a fallback to email or to a log. | `whatsapp-policy.ts`, `whatsapp-records.ts` |
| Provider errors | 190 (expired 463 / invalid 460, 467) and permission codes → `not_authorized`; 131047 (outside the 24-hour window) → refused, never retried; 131026 → refused and the number marked undeliverable; 131056, 130429, 80007, 4 → temporary. Detail text is ours, never the provider's. | `cloud-api-channel.ts` |
| Live-mode credential check | Production refuses to boot in live mode unless Meta confirms, at start-up, that the token is valid, issued for `WHATSAPP_APP_ID`, **never expires** (a permanent system-user token), carries `whatsapp_business_messaging`, and can see `WHATSAPP_PHONE_NUMBER_ID`. Fails closed if Meta cannot be reached. | `whatsapp-live-check.ts` |
| Webhook | `GET` subscription check (constant-time token compare). `POST`: HMAC-SHA256 over the raw body with the app secret, constant-time compare, **before** anything is read; the delivery's items are stored in one statement **before 200**; if they cannot be stored the answer is **503** so Meta retries; provider retries collapse on each item's key. | `whatsapp-webhook.controller.ts` |
| Webhook worker | Leased, idempotent, with backoff (parked after 10 attempts, still visible). Statuses forward only (accepted → sent → delivered → read; a late `failed` never overwrites delivered or read). The code's delivery state and the **D166 delivery proofs** follow the record exactly as before; a proof is bound to the sending number. Inbound text is examined in memory for EN/FR/AR STOP/START keywords and discarded; the window's last-inbound time is kept. Processed items lose their sender fields; retention purge hourly. | `whatsapp-webhook.worker.ts` |
| Delivery proof | `npm run whatsapp:prove -- --to <number>` works **only** in test mode and only to a number in `WHATSAPP_TEST_RECIPIENTS`, so readiness is established without live sends. Proofs count only for the configured `WHATSAPP_PHONE_NUMBER_ID`. | `scripts/whatsapp-prove.ts`, `delivery-readiness.ts` |
| Consent | Versioned copy (`wa-consent-2026-10-17`, EN/FR/AR) served at `GET /api/v1/messaging/whatsapp/consent`: WhatsApp is the mandatory verified account contact, for sign-in, recovery, employee invitations, security alerts and deletion confirmation; operational notices with agreement, stoppable by STOP; never marketing. Taken with `whatsappConsentVersion` at Owner registration and number verification; required while WhatsApp runs live; a stale version is always refused. Recorded with version, time, purposes, masked number, keyed hash, actor and an audit event. | `whatsapp-consent.ts`, `registration-flow.service.ts`, `account.service.ts` |
| Opt-out | `POST /api/v1/account/whatsapp/opt-out` `{scope: optional\|all}`; `GET`/`POST /api/v1/account/whatsapp/consent`. A withdrawal (`all`) answers with the functions that become unavailable (sign-in steps needing a code, recovery, employee invitation verification, security verification, account deletion). Inbound STOP stops optional notices; START restores them; a withdrawal returns only through a new consent. | `account.controller.ts` |

**The 24-hour customer-service window.** The last inbound time is recorded per number and `serviceWindowOpen()`
answers it. Because the system is template-only (D181 §3), the window gates nothing today: an approved template may
be sent outside it. It matters only to a free-form message, which does not exist.

## 2. Environment variables (no secret values)

Secrets come from the production secret manager, never from a file in a repository. **The SMTP key shared in chat on
2026-10-17 must be rotated in Brevo before any deployment** and the new one set only in the secret manager.

| Variable | Test mode (first deployment) | Live mode (later) | Secret? |
| --- | --- | --- | --- |
| `EMAIL_CHANNEL` | `smtp` | `smtp` | |
| `SMTP_HOST` / `SMTP_PORT` | `smtp-relay.brevo.com` / `587` | same | |
| `SMTP_USERNAME` | the Brevo SMTP login | same | treat as secret |
| `SMTP_PASSWORD` | the **rotated** Brevo SMTP key | same | **secret** |
| `EMAIL_FROM` | `Dukan ERP <no-reply@tsxmr.com>` | same | |
| `EMAIL_FROM_VERIFICATION` | `Dukan ERP <verification@tsxmr.com>` | same | |
| `EMAIL_FROM_NOTIFICATIONS` | `Dukan ERP <notifications@tsxmr.com>` | same | |
| `EMAIL_FROM_REPORTS` / `EMAIL_FROM_RECEIPTS` | `reports@tsxmr.com` / `receipts@tsxmr.com` (unused, D111) | same | |
| `EMAIL_REPLY_TO` | `support@tsxmr.com` | same | |
| `EMAIL_DAILY_SAFETY_LIMIT` / `_RESERVE` / `EMAIL_RECIPIENT_DAILY_LIMIT` | `300` / `50` / `20` | per the Brevo plan | |
| `WHATSAPP_CHANNEL` | `cloud` | `cloud` | |
| `WHATSAPP_MODE` | `test` | `live` | |
| `WHATSAPP_TEST_RECIPIENTS` | the verified test recipient(s), E.164, comma-separated | (ignored) | personal data |
| `WHATSAPP_LIVE_SENDS` | `disabled` | `enabled` | |
| `WHATSAPP_API_BASE_URL` / `WHATSAPP_API_VERSION` | `https://graph.facebook.com` / `v26.0` | same | |
| `WHATSAPP_PHONE_NUMBER_ID` | the **test** number's id (`1297799316760335`) | the **real** number's id | |
| `WHATSAPP_APP_ID` | `1103715978699774` (optional in test mode) | required | |
| `WHATSAPP_ACCESS_TOKEN` | a system-user token | a **permanent** system-user token | **secret** |
| `WHATSAPP_APP_SECRET` | the Meta app secret | same | **secret** |
| `WHATSAPP_WEBHOOK_VERIFY_TOKEN` | a random value you generate | same | **secret** |
| `WHATSAPP_TEMPLATE_*` | the approved template names (AUTH_OTP, ACCOUNT_DELETION, ACCOUNT_DELETED, DELIVERY_CHECK required) | same | |
| `WHATSAPP_MAX_SENDS_PER_SECOND` / `WHATSAPP_RECIPIENT_MIN_INTERVAL_MS` | `20` / `1000` | same | |
| `WHATSAPP_WEBHOOK_RETENTION_DAYS` / `MESSAGE_LOG_RETENTION_DAYS` | `30` / `180` | same | |
| `MESSAGING_HASH_KEY` | 32+ random characters | same, never rotated casually (see §6) | **secret** |
| `OTP_PEPPER` | already required | same | **secret** |

Generate the random values: `node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"`.

**What production refuses** (`production-guard.ts`): `cloud` without credentials, templates, the webhook pair,
`OTP_PEPPER` or `MESSAGING_HASH_KEY`; test mode without an E.164 allowlist, or with `WHATSAPP_LIVE_SENDS=enabled`;
live mode without `WHATSAPP_LIVE_SENDS=enabled` or `WHATSAPP_APP_ID` (and then the start-up token check); `smtp`
without credentials, on any port but 587, with example senders, without a Reply-To, pepper or records key.

## 3. Migration 0098

Purely additive: five tables (`email_messages`, `whatsapp_messages`, `whatsapp_webhook_events`, `whatsapp_contacts`,
`whatsapp_consents`), one column and one index on `messaging_delivery_proofs`.

1. Back up per `docs/22` (and record the backup in the handoff).
2. Note: the PC database is at 0091 and the live database at 0083; **0084–0098 all apply together** and each needs its
   own review (`docs/22`). This phase applied none of them anywhere persistent.
3. `npx prisma migrate deploy`, then `npx prisma migrate status` → up to date.
4. Check: `SHOW TABLES LIKE 'whatsapp%'` lists four tables; `SHOW COLUMNS FROM messaging_delivery_proofs LIKE
   'phone_number_id'` returns one row.

Verified here: 0001 → 0098 from empty on MySQL 8.4 (twice), no schema drift on the new tables, an 11-check smoke of
the records, worker, consent, email limit and purge on the real tables, the rollback of §6, a re-apply, and a boot of
the API on it (§7).

## 4. Webhook URL, HTTPS and Meta configuration

- **URL:** `https://<API host>/api/v1/messaging/whatsapp/webhook` — the API host is not chosen yet (`docs/95` §5.3).
  It must be HTTPS with a valid certificate; Meta refuses anything else.
- **Meta → the app → WhatsApp → Configuration:** callback URL as above; verify token = `WHATSAPP_WEBHOOK_VERIFY_TOKEN`;
  subscribe the **`messages`** field (statuses and inbound messages both arrive there).
- The `GET` check answers 404 until both `WHATSAPP_APP_SECRET` and `WHATSAPP_WEBHOOK_VERIFY_TOKEN` are set.
- **Privacy policy URL dependency:** production webhooks and a live number need the Meta app **published**, which needs
  a public privacy policy URL. The pre-launch site's policy (`https://tsxmr.com/privacy`) is not published yet and is
  still a draft awaiting TSX-MR's approval (`docs/96`, `docs/97`); the app's own policy is separate. Publishing the
  Meta app is the owner's act.
- The edge must pass the raw request body unchanged (the HMAC is over the exact bytes) and must not rate-limit Meta
  below 120 requests a minute per IP (the route's own throttle).

## 5. Test number → real number

1. Owner: register the real number in the WhatsApp Business Account (two-step PIN, display name approval). Not done
   by any session.
2. Owner: generate a **permanent** system-user token with `whatsapp_business_messaging` and
   `whatsapp_business_management` for the WABA, store it in the secret manager.
3. Set `WHATSAPP_PHONE_NUMBER_ID` to the real number's id, keep `WHATSAPP_MODE=test`, and set
   `WHATSAPP_TEST_RECIPIENTS` to the operator's own number(s). Restart.
4. `npm run whatsapp:prove -- --to <operator's number>` → three sends (EN/FR/AR); the signed webhook completes each
   proof. `npm run whatsapp:prove -- --status` → PROVEN. Proofs made with the test number do not count for the real
   one (0098).
5. When TSX-MR decides to go live (and the clients send the consent version, §8): `WHATSAPP_MODE=live`,
   `WHATSAPP_LIVE_SENDS=enabled`, `WHATSAPP_APP_ID` set. Restart: the boot refuses unless the token check passes.

## 6. Rollback

- **Stop sending, instantly:** `WHATSAPP_LIVE_SENDS=disabled` (live) or `WHATSAPP_CHANNEL=disabled`;
  `EMAIL_CHANNEL=disabled`. Restart. Callers refuse honestly; nothing is faked.
- **Code:** redeploy the previous build. The new tables are simply unused by older code.
- **Database (only if required — a Git rollback does not roll back the database):**

  ```sql
  DROP TABLE IF EXISTS `whatsapp_consents`;
  DROP TABLE IF EXISTS `whatsapp_contacts`;
  DROP TABLE IF EXISTS `whatsapp_webhook_events`;
  DROP TABLE IF EXISTS `whatsapp_messages`;
  DROP TABLE IF EXISTS `email_messages`;
  DROP INDEX `ix_delivery_proof_number` ON `messaging_delivery_proofs`;
  ALTER TABLE `messaging_delivery_proofs` DROP COLUMN `phone_number_id`;
  DELETE FROM `_prisma_migrations` WHERE `migration_name` = '0098_messaging_records';
  ```

  This deletes the consent history and opt-outs: export `whatsapp_consents` and `whatsapp_contacts` first.
- **`MESSAGING_HASH_KEY`:** changing it makes every stored hash unmatchable — opt-outs and consents would no longer be
  found. Rotate only with a re-keying step (not built).

## 7. Verification

| Check | Result |
| --- | --- |
| `tsc --noEmit` | pass |
| Full backend suite | 255 suites; **4 660 passed**, 24 skipped, 1 failed — `trial.service.spec` "only a claim writes a trial claim", a Windows path-separator assertion that fails identically on the untouched baseline `1ed6b00` |
| New and changed messaging tests | 299 pass, among them: SMTP options and sender selection; text+HTML, escaping, RTL, no remote content; failure classes with no credential, login, address or code in any result; ambiguous timeout retried with the same code and Message-ID; internal limit, reserve, per-recipient limit, records unavailable; signature missing/invalid/valid; store-before-200 and 503 on a failed store; duplicate deliveries; forward-only statuses and a late failure; D166 proofs, including a retry after a failed effect; unknown-message grace; leases, backoff, parking; STOP/START in EN/FR/AR and whole-message matching; consent at registration and verification, stale/missing versions, withdrawal state; test-mode allowlist (never an application number), live sends disabled, delivery check test-only; 131026, 131047, expired/invalid tokens; live-mode token check (permanent, app, scope, number, unreachable); production guard rules |
| Disposable-database smoke (MySQL 8.4) | 11/11 on the real tables |
| API boot on a disposable database (`WHATSAPP_CHANNEL=cloud`, test mode, a fake token, Graph base URL pointed at a closed local port so nothing could leave) | every route mapped; consent copy 200; verify 200 / wrong token 403; unsigned POST 401; signed POST 200 and the same delivery again stored once; the inbound STOP became an opt-out with the sender cleared; a status for an unknown message waited for its grace period. The log held no token, secret, number or message text. Server stopped, database dropped. |
| Dependency audit | `nodemailer` 10.0.13 and `@types/nodemailer` 8.0.2 pinned; no finding for them; 9 moderate findings pre-existing |
| Not run | ESLint (the backend declares a lint script but has no ESLint installed or configured); gitleaks (not installed on this PC); any real send |

## 8. Owner and follow-up actions

1. **Rotate the Brevo SMTP key** that was shared in chat; put the new one in the secret manager only.
2. In Brevo: authenticate `tsxmr.com` (SPF, DKIM, DMARC — DNS records are the owner's to add); create the senders
   `verification@`, `notifications@`, `no-reply@` (and `reports@`, `receipts@` if wanted); make `support@` a read
   mailbox; **check open and click tracking for transactional email and turn them off** — click tracking would rewrite
   the trial setup link, which carries a one-time token.
3. Meta: publish the app (needs the privacy policy URL, §4); register the real number; permanent system-user token;
   approve the templates (no session submits them); set the webhook (§4).
4. Choose the API host and its HTTPS certificate (§4).
5. **Clients (next phase, not this one):** the app and the website must show the consent copy from
   `GET /api/v1/messaging/whatsapp/consent` and send `whatsappConsentVersion` with registration and number
   verification, and offer the opt-out and consent routes. Until then, live mode refuses a registration with a
   WhatsApp number (`whatsapp_consent_required`) — by design, not a bug.
6. Approve the consent copy's wording (EN/FR/AR) with counsel; a change means a new version.
7. Later work: Brevo transactional webhooks to reconcile deliveries, bounces and complaints
   (`https://developers.brevo.com/reference/create-webhook`); a re-keying tool for `MESSAGING_HASH_KEY`; pacing shared
   across instances if more than one API instance ever runs.

## 9. Retention

| Data | Kept | Then |
| --- | --- | --- |
| `email_messages`, `whatsapp_messages` (metadata, provider ids) | `MESSAGE_LOG_RETENTION_DAYS` (180) | deleted by the hourly sweep |
| `whatsapp_webhook_events` | sender fields cleared once processed; rows `WHATSAPP_WEBHOOK_RETENTION_DAYS` (30, longer than Meta's retry period) | processed or parked rows deleted; pending rows never |
| `whatsapp_contacts` (opt-out, last inbound, undeliverable) | while relevant to sending | not purged automatically: an opt-out must outlive message logs |
| `whatsapp_consents` | append-only proof of consent | not purged automatically; deletion policy for a deleted account is counsel's (`docs/93`) |
| Inbound message text | never stored | — |

## 10. Readiness

**Ready for a test-mode deployment** once the owner actions 1–4 are done: email by Brevo with records and limits;
WhatsApp to the allowlist only, with the signed webhook, the proof, consent and opt-out in place.

**Not ready for live WhatsApp**: the clients do not yet send the consent (§8.5), the Meta app is unpublished, the real
number is not registered, no template is approved, and no delivery is proven. Every one of these is refused by the
code, not merely documented.
