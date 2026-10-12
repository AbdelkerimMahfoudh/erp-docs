# 64 — Account deletion, WhatsApp delivery, and the privacy and retention policy

> Implemented 2026-09-30 (backend `ae64de8` messaging, `1925a0d` deletion, `bde6bc4` + `da0d340` hardening; mobile:
> the account screens and the release check, two commits on `reports-export` — ids in `CURRENT_HANDOFF.md`). The product decisions are D104–D110 in [`docs/21`](21_PRODUCT_DECISIONS.md).
> The gate evidence is in [`docs/48`](48_PRE_RELEASE_SECURITY_GATE.md). **Nothing here is published.**

## 1. The rule

**No account is deleted through any route — mobile, web, API, administrator tool or background job — unless a
single-use deletion code was sent to that account's verified WhatsApp number and then correctly entered by the
account holder.** Deactivation does not satisfy it. No other channel is substituted: a login with no verified WhatsApp
number is told so (`whatsapp_number_required`) and offered the way to verify one; nothing is sent by email or SMS.

An administrator may **suspend** or **cancel** a business (their own, clearly named, audited actions in the platform
realm — `docs/15` §4) and an Owner may **deactivate** a staff login (`PATCH users/:id`, sessions revoked). Neither is
called deletion, neither removes personal data, and there is no administrator deletion route (a `DELETE
platform/businesses/:id` answers 404).

## 2. What is deleted, what is kept, and why

| | **A personal login** (anybody who is not the last active Owner) | **Closing the business** (the last active Owner) |
|---|---|---|
| Deleted / de-identified | the person's name, login, WhatsApp number and email, password and PIN hashes; every session and device credential revoked; live codes cancelled; sync cursors and notifications removed; unaccepted invitations revoked | the same for **every** login in the business; customers' names, numbers and notes; suppliers' numbers and notes; the registration record's owner name and contacts; the company's public number, logo and discoverability; every branch made inactive; the subscription **cancelled** with an event |
| Kept | sales, purchases, payments, returns, closings, ledgers (including employee-debt entries that name the login), the audit trail, subscription events | the same, for the whole business; the **company name** (it is on every retained invoice) |
| Why kept | the law requires business, accounting and tax records to be retained (see §6: the exact periods are a legal question the owner must answer) | same |
| How the person is protected in what is kept | the retained rows reference the same `users` row, which now reads **"Deleted user"** with every contact null and an unusable password hash; nothing in a retained record carries the person's number or email | customers and suppliers are reduced to their transactions |

The request stores **counts** of what was kept (`retained_summary`), never a name, a number or an amount.

## 3. The flow, and what the server enforces

```
Your account → Delete account
  1. the confirmation screen (below), the password again          POST account/deletion/request  {password, language}
  2. a code to the VERIFIED WhatsApp number (masked on screen)      ← account.deletion template, 6 digits, 5 minutes
  3. the code                                                        POST account/deletion/confirm  {code}
  4. deleted → every session ends, including this one → Done signs out; a completion message on WhatsApp
```

Server-side, every one of these holds whatever the client does:

- **Recent reauthentication**: the password again at the request; a request older than 30 minutes needs it again.
- **One live code per person and purpose** (the OTP `active_key` UNIQUE index); a resend replaces the code.
- **Hashed server-side** (HMAC-SHA256 with `OTP_PEPPER`, never the code, never reversible); **five attempts**, then the
  request fails; **five-minute expiry**; **60 s resend cooldown**; **3 codes per 15 minutes and 10 per day** per person
  and per number; **5 requests per minute per client** on every code-issuing route (`ACCOUNT_THROTTLE_LIMIT`).
- **Replay**: a code is consumed exactly once; the second confirmation of a spent code answers with the request as it
  stands, never with a second deletion. **Concurrent confirmations** are settled by a conditional update on the
  request's status and version: one carries the deletion out.
- **Purpose**: a code issued to verify a phone or a device never confirms a deletion — the executor refuses any
  challenge whose purpose is not `account_deletion`.
- **The number**: the code went to a snapshot of the verified number; if the number changed under the request, the
  request fails (`number_changed`).
- **The executor insists on proof** (`deletion-rules.ts`, `proofProblem`): inside the transaction it re-reads the
  request and its challenge and refuses unless the request is `confirmed` and the challenge is *its own*, *for the same
  person and company*, *of the deletion purpose*, *verified*, and *verified within 15 minutes*. A status edited by hand,
  another person's challenge, another company's, or a stale proof all fail closed with the account intact. There is no
  other code path to the de-identification.
- **Failure is visible and reversible**: a provider that does not accept the message leaves the request open with
  `delivered: false` and the failure class; a deletion that fails mid-way rolls back, marks the request `failed`, and
  says so (`deletion_failed`). Nothing is ever reported as sent or deleted unless it was.
- **Idempotent retries**: a repeated request returns the open request (one code); a repeated confirmation after a lost
  response returns the final state.
- **Audit**: the request, its cancellation and its completion are audit rows (with masked destinations and counts,
  never the code); the completion is in the same transaction as the deletion.

Reachable **in every subscription state**: the routes are on the entitlement allow-lists (`route-classification.ts`),
the refusal screen links to *Delete my account*, and the sign-in guard leaves the account screens alone.

### The confirmation screen

> **Delete your account permanently?** This cannot be undone. We will send an account-deletion code to your verified
> WhatsApp number. Your account will be deleted only after you enter that code and confirm.
>
> *What will be deleted* — [the login, or the business and every login in it; see §2]
> *What is kept, and why* — sales, purchases, payments, closings and the audit trail are kept because the law requires
> business and tax records to be retained. Your name and contact details are removed from them: they refer to a
> "Deleted user".

French and Arabic carry the same content (`account.delete.*` in the three catalogues; Arabic lays out right-to-left,
codes are typed left-to-right).

## 4. WhatsApp delivery — the Cloud API channel

`WHATSAPP_CHANNEL=cloud-api` (backend `ae64de8`) sends **approved templates by name**, with validated variables, to the
Meta Graph API. The template *names* are configuration (`WHATSAPP_TEMPLATE_*`), one per message, because a name is an
approval the operator obtained and it differs per deployment; a template without a name cannot be sent and the server
says so rather than guessing. Credentials (`WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_ACCESS_TOKEN`, `WHATSAPP_APP_SECRET`,
`WHATSAPP_WEBHOOK_VERIFY_TOKEN`) are server-side only; the token is a request header and nothing else; logs carry a
masked number and never a code; audit rows carry the delivery class and never a payload. Production refuses to start
with `cloud-api` unless the credentials, the sign-in and deletion template names and `OTP_PEPPER` are all set, and
refuses `development-log` outright.

**The delivery-status webhook** (`GET/POST messaging/whatsapp/webhook`) exists only when both webhook settings are
configured; the subscription check answers only the verify token; a status report is read only when its
`X-Hub-Signature-256` is the HMAC-SHA256 of the exact bytes received, keyed by the app secret; it can only update the
delivery state of the challenge its message id belongs to.

### The approved copy to register (one template per row; `{{1}}` = code, `{{2}}` = minutes; category as stated)

| Template (config key) | Category | EN | FR | AR |
|---|---|---|---|---|
| `auth.otp` (`WHATSAPP_TEMPLATE_AUTH_OTP`) | AUTHENTICATION (Meta's fixed layout: code + copy button) | *{{1}} is your Retail ERP verification code. It expires in 5 minutes.* | *{{1}} est votre code de vérification Retail ERP. Il expire dans 5 minutes.* | *{{1}} هو رمز التحقق الخاص بك في Retail ERP. تنتهي صلاحيته خلال 5 دقائق.* |
| `account.deletion` (`WHATSAPP_TEMPLATE_ACCOUNT_DELETION`) | UTILITY | *Account-deletion code: {{1}}. Enter it in Retail ERP to delete your account. This cannot be undone. If you did not ask for this, do not share the code. The code expires in {{2}} minutes.* | *Code de suppression de compte : {{1}}. Saisissez-le dans Retail ERP pour supprimer votre compte. Cette action est irréversible. Si vous n'êtes pas à l'origine de cette demande, ne partagez pas ce code. Le code expire dans {{2}} minutes.* | *رمز حذف الحساب: {{1}}. أدخله في Retail ERP لحذف حسابك. لا يمكن التراجع عن هذا الإجراء. إذا لم تطلب ذلك، فلا تشارك الرمز. تنتهي صلاحية الرمز خلال {{2}} دقيقة.* |
| `account.deleted` (`WHATSAPP_TEMPLATE_ACCOUNT_DELETED`) | UTILITY | *Retail ERP: {{1}} has been deleted. Records required by law are kept without your personal details.* | *Retail ERP : {{1}} a été supprimé. Les documents exigés par la loi sont conservés sans vos données personnelles.* | *Retail ERP: تم حذف {{1}}. يُحتفظ بالسجلات التي يوجبها القانون من دون بياناتك الشخصية.* |

For `account.deleted`, `{{1}}` is the localised phrase *your login* / *your business and every login in it*.

**Not configurable here, by design:** the provider account, the approved templates, the phone number and the token
are the owner's to obtain — see §7. Nothing is faked: with the channel `disabled`, a deletion request answers
`deletion_unavailable` and the account stays intact.

## 5. Verifying a WhatsApp number from the app

`Your account → Verify a WhatsApp number`: the password again and the number, then a code to *that* number
(`phone_verification` purpose, bound to the candidate number), then the code. The number becomes the login's verified
number only when the code comes back; every other session of that login ends (a login identifier changed). A number
already used by another person in the same business is refused (`phone_in_use`). A registration that proved a WhatsApp
number already counts as verified (`phoneVerifiedAt` set by `register/verify/confirm`).

## 6. Privacy and retention policy (draft for the owner's legal review)

- **What we hold about a person:** name, sign-in identifiers (login, personal ID, WhatsApp number, email), password and
  PIN hashes, the devices they signed in from (labels only, no hardware identifiers), when they signed in, and the
  business records they made (sales, receipts, closings, corrections) with the audit trail of who did what.
- **Where:** the production MySQL database (hosting to be decided, `docs/42`); encrypted backups
  (`deploy/backup-encrypted.sh`); logs with tokens, passwords and codes redacted (`app.module.ts` `redact`), personal
  data in logs limited to request paths and masked numbers.
- **Who can see it:** the business's Owner and the roles it grants (`docs/03`); platform administrators see a
  business's people and contacts and its subscription, never its takings; the hosting operator with database access.
- **Deletion:** as in §1–§3. Personal data is removed at the account holder's request, confirmed by the WhatsApp code,
  immediately and synchronously (the state is shown until the server reports `completed`; a failure leaves everything
  as it was).
- **Retention of what is kept:** business, accounting and tax records are retained for **the period the law requires
  — to be stated by the owner's legal adviser** (Mauritanian commercial and tax law; the brief forbids inventing a
  period). Until that advice is recorded here, retained records are kept indefinitely and de-identified as above.
- **Export:** not offered as a self-service feature; a business's reports (CSV) are its own; a personal-data export on
  request is an operator task (owed — see §7).
- **Children:** not a consumer application; staff accounts only.

## 7. Apple App Review 5.1.1(v) — account deletion

The guideline requires that an app supporting account creation also let the user **initiate deletion of their account
from within the app**, and that the deletion be a real deletion (not a deactivation), while allowing legally required
retention. This implementation: in-app, easy to find (More → Your account → Delete account; also on the access-refusal
screen), real de-identification with retention limited to legally required records and explained on the screen, state
shown until completion, confirmation on completion.

**One conflict is identified explicitly, as the brief requires, rather than claiming readiness:** the product rule
(§1) makes a **verified WhatsApp number a precondition** of deletion, and registration accepts an **email** as the only
contact. A person who registered with an email and has no WhatsApp (or no longer has that number) cannot delete their
account in the app without first verifying a WhatsApp number. Apple may read that as an obstacle to deletion. The
options are the owner's decision (recorded as D110, *open*): (a) require a WhatsApp number at registration for every
login, so every account can always be deleted; (b) allow a second, equally strong confirmation for accounts that
provably hold no WhatsApp number (for example a code to the verified email) — which the brief forbids as a *silent*
substitute but the owner may approve as an explicit rule; (c) accept the review risk and handle such deletions as an
operator task with the same code sent by hand. Until decided, **this is a release blocker**.

## 8. External prerequisites (none of these can be produced by a session)

1. A **WhatsApp Business** account with the three templates above approved in EN, FR and AR, a sending number, a
   system-user token, and the webhook's app secret — then `WHATSAPP_*` set on the production host.
2. **`OTP_PEPPER`** generated for production (no codes can be issued without it).
3. The owner's **legal advice on retention periods** (§6), recorded in this document.
4. The owner's decision on **D110** (§7).
5. A real send to a real number, in each language, recorded in `docs/24` §51.

## Correction phase (2026-10-12) — what deletion removes now, what it cannot, and delivery

- **Removed** (D165, backend `4cc2533`, mobile `02f2e4e`): the full list is in `docs/75` §7 — sign-in identifier,
  session and device details, code destinations, verification intents and rows naming the person's contacts, sync queue,
  names on the counter's records; for a closed business also customers', suppliers' and lent-to people's contacts, payer
  and counter numbers, notes, receipt photos (files deleted after the commit), branch addresses, the city. The phone
  forgets the deleted login's device credential.
- **Not removed, and said so** (app, website, `notRemoved` in every summary): the hash-chained audit trail, subscription
  and platform audit events, append-only agent snapshots, and backups until they expire. **Backup retention: not set —
  TSX-MR must supply it; production stays blocked.** Active-storage deletion is immediate.
- **New audit events hold no contact**; request logs drop search terms.
- **WhatsApp** (D166): production sends nothing until `npm run whatsapp:prove` has a signed "delivered" report per
  language (en, fr, ar) — a new approved template `delivery.check` (WHATSAPP_TEMPLATE_DELIVERY_CHECK). Until then no
  deletion code goes out, so no deletion can complete. The template texts in this document still say "Retail ERP": they
  must be resubmitted to Meta as **Dukan ERP** (D168).
- **Email** (D166): a provider boundary exists (Resend, inert); SPF, DKIM and DMARC on the sending domain are required
  before `EMAIL_CHANNEL=resend`; deletion codes stay WhatsApp-only.
