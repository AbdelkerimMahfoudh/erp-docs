# 87 — Processor and recipient inventory

> Status: factual, from the code, 2026-10-16, CLAUDE-B (backend `06a0db7`; nothing outbound changed since). A processor
> here is a service the code can send personal data to. **None is contracted or enabled in production today.** The
> hosting, database, log and backup providers are not chosen (blocker `processors`); the website names none until
> TSX-MR contracts them.

## 1. Services the code can send personal data to

### Meta WhatsApp Business Cloud API (Graph API)

| Aspect | Fact |
| --- | --- |
| Endpoint | WHATSAPP_API_BASE_URL (default https://graph.facebook.com) + /{WHATSAPP_API_VERSION}/{WHATSAPP_PHONE_NUMBER_ID}/messages |
| Direction | outbound HTTPS POST, plus an inbound signed status webhook (GET/POST /api/v1/messaging/whatsapp/webhook) |
| Enabled by default | False |
| How it is enabled | WHATSAPP_CHANNEL=cloud-api with WHATSAPP_PHONE_NUMBER_ID and WHATSAPP_ACCESS_TOKEN (module refuses to build otherwise). In NODE_ENV=production the channel additionally stays closed (isEnabled=false, every send 'channel_unavailable') until messaging_delivery_proofs holds a webhook-confirmed delivered row for each of en, fr, ar (npm run whatsapp:prove + signed webhook). |
| Configuration (names only) | WHATSAPP_CHANNEL; WHATSAPP_API_BASE_URL; WHATSAPP_API_VERSION; WHATSAPP_PHONE_NUMBER_ID; WHATSAPP_ACCESS_TOKEN (secret); WHATSAPP_APP_SECRET (secret, webhook HMAC); WHATSAPP_WEBHOOK_VERIFY_TOKEN (secret); WHATSAPP_SEND_TIMEOUT_MS; WHATSAPP_TEMPLATE_LANGUAGE_EN / _FR / _AR; WHATSAPP_TEMPLATE_AUTH_OTP; WHATSAPP_TEMPLATE_ACCOUNT_DELETION; WHATSAPP_TEMPLATE_ACCOUNT_DELETED; WHATSAPP_TEMPLATE_CLOSING_REOPENED; WHATSAPP_TEMPLATE_CLOSING_SALE; WHATSAPP_TEMPLATE_CLOSING_RECLOSED; WHATSAPP_TEMPLATE_DELIVERY_CHECK; WHATSAPP_TEMPLATE_TRIAL_SETUP; OTP_PEPPER (secret; required for any code-bearing message) |
| Data sent | Recipient WhatsApp number in E.164 without '+' (staff/Owner number, or the operator's own number for delivery proofs); Approved template name + language code; auth.otp: 6-digit code (body + copy-code button) - used for account phone verification, registration/staff contact verification (contact-delivery.ts:246-255); account.deletion: 6-digit deletion code + TTL minutes; account.deleted: localised phrase 'your login' / 'your business and every login in it'; closing.reopened / closing.sale / closing.reclosed (Owner notices): branch name, time, business date, item label (product name, never a full identifier/cost), money totals only when the Owner enabled whatsappIncludeAmounts; trial.setup: business (company) name + one-time 256-bit setup token as the URL-button suffix; delivery.check: an operator reference string |
| Data received | Provider message id (stored in otp_challenges.provider_message_id / contact_verifications.provider_message_id / messaging_delivery_proofs.provider_message_id); webhook statuses (id, status, error code) only. |
| Stored about each send | otp_challenges (destination, provider, provider_message_id, delivery_state, delivery_detail), contact_verifications (delivery_* columns), messaging_delivery_proofs (destination_masked), trial_setup_messages (outcome only) |
| Evidence | src/common/config/env.validation.ts:41-56,77-86; src/messaging/messaging.module.ts:38-81,84-100,117-127; src/messaging/cloud-api-channel.ts:104-197; src/messaging/delivery-readiness.ts:19-86; src/messaging/whatsapp-webhook.controller.ts:108-175; src/messaging/templates.ts:73-176; src/auth/otp/otp.service.ts:247-268; src/account/account-deletion.service.ts:695-717; src/closing/closing-notice.service.ts:71-115; src/closing/closing-notices.ts:143-169; src/platform/contact-delivery.ts:242-255; src/platform/trial/trial-setup.service.ts:418-422; src/common/config/production-guard.ts:195-237; scripts/whatsapp-prove.ts:75-82 |

### Resend (transactional email HTTP API)

| Aspect | Fact |
| --- | --- |
| Endpoint | RESEND_API_BASE_URL (default https://api.resend.com) + /emails |
| Direction | outbound HTTPS POST only |
| Enabled by default | False |
| How it is enabled | EMAIL_CHANNEL=resend with RESEND_API_KEY and EMAIL_FROM (refuses to build otherwise; production guard also requires a real sender domain, https base URL and OTP_PEPPER). docs state no provider is connected/contracted yet. |
| Configuration (names only) | EMAIL_CHANNEL; EMAIL_FROM; EMAIL_REPLY_TO; RESEND_API_KEY (secret); RESEND_API_BASE_URL; EMAIL_SEND_TIMEOUT_MS; OTP_PEPPER (secret); PUBLIC_SITE_ORIGIN (used to build the trial.setup link) |
| Data sent | Recipient email address (lowercased), from/reply-to, subject and plain-text body, Idempotency-Key header; contact.verification: 6-digit code + TTL (registration continuation, staff invitation verification, staff resend); trial.setup: business (company) name + link PUBLIC_SITE_ORIGIN/account/trial#t=<one-time token>; Templates staff.invitation, password.recovery, security.alert exist but are wired:false and cannot be sent; deletion codes are never sent by email |
| Data received | Provider message id (contact_verifications.provider_message_id). |
| Evidence | src/common/config/env.validation.ts:88-97; src/messaging/email-channel.ts:21-131,166-213,228-244; src/messaging/messaging.module.ts:128-146; src/platform/contact-delivery.ts:236-264; src/platform/trial/trial-setup.service.ts:407-411; src/common/config/production-guard.ts:239-256 |

## 2. Recipients that are not processors

| Recipient | What it sees | Evidence |
| --- | --- | --- |
| Platform administrators (TSX-MR operators) | Every business's people (name, email, phone, verification flags, active state, last login), registration applications (owner name, business name, city, email, phone, language), subscription/seat/payment records, platform audit trail. Never sales, IMEIs, costs. | src/platform/platform.controller.ts:463-547,549-669,671-712 |
| Other businesses on the platform (inter-store connections, consignments, loans) | Company name, Store Account ID, city, logo ref (search results), public phone after a connection is accepted; consignment line snapshots (brand/model/variant/full identifier/condition/defect notes, agreed amount) and loan/consignment ledgers are shared with the counterparty company. | src/consignment/connections.service.ts:108-158,184-185,408; prisma/schema.prisma:3969-4103,4211-4340 |

## 3. Verified absent

| Kind | Finding |
| --- | --- |
| crash reporting or apm | none (no Sentry/Datadog/New Relic; errors go to the process log only) |
| analytics or ads | none |
| push notifications | none (in-app notifications table only; 'FCM' appears only as a permission label) |
| sms | none |
| payment provider | none (subscription payments recorded by hand; receiving accounts store no credentials) |
| object storage | none (receipts on local disk UPLOAD_DIR; S3 only mentioned in comments) |

Evidence: src/notifications/notifications.module.ts; src/rbac/role-permissions.ts:171; prisma/schema.prisma:114-121,2491-2499; src/storage/storage.module.ts:1-15

## 4. Hosting and backups

Hosting, database host, log destination and off-host backup storage are deployment decisions not present in code (docs/74 §8 proposes Railway + Cloudflare + R2; not executed). deploy/backup-encrypted.sh produces encrypted full mysqldumps locally and keeps the newest 14; any off-host copy is 'a separate job'.

## 5. The mobile app

A release build talks to exactly one host, the https API origin (`EXPO_PUBLIC_API_ORIGIN`). It also opens four
legal pages in the phone's browser on `EXPO_PUBLIC_LEGAL_ORIGIN`; no data is sent there but the page address. No
analytics, crash reporting, advertising, push, OTA updates, remote fonts, maps or third-party lookups (docs/90 §3).

## 6. What TSX-MR must supply before any of this is published

The name, role, location and contract of each provider it chooses (hosting, database, backups, logs, email, WhatsApp),
and whether any of them processes data outside Mauritania (blocker `international_transfer`). docs/93 lists them.
