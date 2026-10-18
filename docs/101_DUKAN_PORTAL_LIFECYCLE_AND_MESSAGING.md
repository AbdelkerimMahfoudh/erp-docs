# 101 — The Dukan ERP portal, web-only trial claiming, limited grace and prioritized messaging (2026-10-18)

> **As built (2026-10-18).** Implemented on three branches, verified, and pushed. **Nothing is deployed or merged.**
> Migration `0099` was rehearsed only on disposable MySQL databases inside the cloud container, all dropped afterwards.
> No message reached a real person: every send went to the development-log channels. The decisions are **D202–D212**
> (`21_PRODUCT_DECISIONS.md`). What waits for the owner or a provider is in §12 and §14.

This record covers the owner's brief of 2026-10-18, carried out by CLAUDE in one cloud session under the single-session
convention. It replaces the token setup links of D169/D173/D175 with one generic portal address, makes the WhatsApp
number mandatory at sign-up, limits grace to three uses per company in any rolling 12 months, and adds WhatsApp-first
subscription messages with a recorded email fallback.

## 1. Branches and commits

| Repository | Branch (base) | Final commit | Commits of this phase |
| --- | --- | --- | --- |
| `erp-backend` | `dukan-portal-lifecycle` (from `production-deploy` `644f4f5`) | `17ea84b` | `0d6f27d` migration `0099` · `256f1e4` lifecycle and messaging · `9efe584` portal session · `ff619dd` console oversight · `479cf8e` claim/resend need the portal session · `bbca6c3` Owner-facing mask · `3b8d144` real-MySQL gate in CI · `17ea84b` a comment corrected |
| `erp-control-web` | `dukan-portal` (from `tsx-public-site` `e953c58`) | `e020215` | `feca99a` portal surface · `99f612d` console pages · `e020215` grace in the history, paid-end message names |
| `erp-mobile` | `dukan-portal-lifecycle` (from `reports-export` `e6773aa`) | `de40f72` | `de40f72` display-only status |
| `erp-docs` | `master` | the commit carrying this file | this file, D202–D212, `docs/22` drill record, notes in 68/76/96/98/99/100 |

`production-deploy`, `reports-export`, `tsx-public-site` and `main` were not moved.

## 2. Topology (D202)

| Host | What | Notes |
| --- | --- | --- |
| `https://tsxmr.com` | the public company site | unchanged; carries no portal route |
| `https://dukan.tsxmr.com` | the authenticated Dukan ERP portal; canonical page **`/subscription`** | `/` answers `302 /subscription`; `/account/*` (retired) answers `301 /subscription`; the console lives at `/admin` on the same build |
| `https://api.tsxmr.com` | the API | the portal calls it with `credentials: 'include'` |

- **Not indexed.** Every portal response carries `X-Robots-Tag: noindex, nofollow`; `robots.txt` is `Disallow: /`;
  pages carry the robots meta.
- **Never `portal.tsxmr.com`.** The bundle audit refuses that host in any build.
- **The release gate PORTAL** refuses a production build unless all of these hold:
  - `VITE_SITE_SURFACE=portal`;
  - `VITE_PORTAL_ORIGIN=https://dukan.tsxmr.com` exactly;
  - `VITE_PUBLIC_SITE_ORIGIN=https://tsxmr.com`;
  - `VITE_API_BASE` on `https://api.tsxmr.com`.
- **The API side.** `PORTAL_ORIGIN` is used only to write `<PORTAL_ORIGIN>/subscription` into the messages. Production
  refuses anything but `https://dukan.tsxmr.com`; the staging preflight refuses that value. It replaces
  `PUBLIC_SITE_ORIGIN`, which built the retired setup links.

## 3. The journey (D203–D205)

1. **Registration in the app.** The WhatsApp number is **mandatory**: without one the API answers 400 and saves
   nothing. An email address is **optional**. The one code goes to the number.
   - In production, a server that cannot send that code refuses before anything is saved (503
     `registration_unavailable`).
   - In development, codes go to the in-memory dev outbox, which takes every channel.
2. **The number is verified** → a self-registered business is eligible for one 7-day trial.
   - The server sends **one** portal-instructions message (§6), WhatsApp first.
   - It names the business and, in the approved text, the generic address `https://dukan.tsxmr.com/subscription`:
     no token, no query, no identifier.
3. **The claim, on the portal only.** The Owner signs in with the same identity (WhatsApp number or email, and the
   password) and reads the card.
   - Pressing **Start my 7-day free trial** asks first: "starts immediately, lasts exactly 7 days (168 hours), cannot be
     paused or restarted".
   - Only **Yes, start it now** sends `POST platform/my-subscription/trial/claim` (`{ idempotencyKey, termsVersion }`,
     `x-csrf-token`).
   - The server decides eligibility and the instant, and refuses an app session (D211).
4. **The app is display-only.** No claim, renew or pay button, no website link, QR code or web view, no price, no token.
   - The closed screen of an eligible business shows a card:
     - eligible, not started, 7 days, starts only after a claim;
     - the verified contacts, masked;
     - one delivery line, e.g. "sent by WhatsApp to +222••••0304 on 18 Oct 2026 · 12:56 (Greenwich Mean Time)".
   - The access screen shows the grace deadline on the business's clock, and the allowance exactly as the server
     counts it (`Grace periods left: 2 of 3 in any 12 months`, or that none followed, or that none would follow).
   - The tabs' notice shows the same deadline on the same clock.

## 4. Trial and grace rules (D205, D206)

**The trial.**
- One per self-registered business: 168 hours from the server's instant of the confirmed claim.
- Cannot be paused, restarted or claimed twice: a different key is refused `trial_already_claimed`, the same key
  replays.
- Read-only after its end. **A trial never gets grace.**

**Grace.** 72 hours after a **paid** period ends, and at most **three granted activations per company in any rolling
12 months**. Each paid period end is decided **once** and recorded in `grace_episodes`:
- **Granted:** starts at the period end and ends exactly 72 hours later.
- **Refused:** starts and ends at the period end. It is refused when three granted activations already started inside
  the 12 calendar months before that end. The window start is `period_end − 12 MONTH`, MySQL's own arithmetic. The
  application computes the same instant, pinned on leap days and month ends by the real-MySQL spec.

**Who writes the decision**, whichever comes first, under the subscription lock:
- the **lifecycle**, inside the transaction that moves an end, which records a passed end before moving it;
- the **first evaluation** after the end (NOWAIT, once a minute per company);
- the **minute sweeper**, for ends of about the last 10 days (72 hours, plus the 7-day announcement window, plus an
  hour). An older end is decided when first needed and never announced.

**It is final.**
- `UNIQUE (company_id, period_end)`.
- Triggers refuse the application account's UPDATE and DELETE ("grace_episodes is immutable").
- CHECKs bind the span, the allowance, the window and the recording instant.
- Consumed the moment it starts; never given back by a renewal.
- **An edited expiry is a new end, decided on its own**: it can never replay a used grace.

**Ends that passed before 0099** are decided by the same rules when first needed. One within the lookback at deployment
is granted and counted: the derived rule gave it its 72 hours ("pre-rollout ends count", §14).

**No grace, and no lifecycle message**, for a platform grant (complimentary access) or a trial.

## 5. Renewal timing (D207)

| When the renewal is confirmed | The new period counts from |
| --- | --- |
| before the paid period ends | the current end |
| during grace | **the original paid end**, not the confirmation |
| after the end (grace over, or none) | the confirmation |

The rehearsal proved all three over HTTP (§10.3, checks L1/L3/L4) and on real MySQL with a renewal racing the sweeper.

## 6. Subscription messages (D208, D209)

| Kind | Thresholds | Notes |
| --- | --- | --- |
| `portal_instructions` | `auto` (once, after the number is verified); `resend:<uuid>` (the portal) | eligibility period key |
| `trial_reminder` | `h72`, `h48`, `h24` | trial key; says there is no grace |
| `trial_expired` | `end` | read-only, no grace |
| `paid_reminder` | `h72`, `h48`, `h24` | paid key |
| `paid_expired` | `end`, variant `grace_started` (its end and uses left) or `no_grace` | |
| `grace_reminder` | `h48`, `h24` | grace key |
| `grace_ended` | `end` | read-only |

**Identity and dedupe.** `UNIQUE (company_id, period_key, kind, threshold)`, with period keys `trial:<claimId>`,
`paid:<epoch ms>`, `grace:<epoch ms>` and `eligibility:<id>`. A retry, a restart or a second worker reuses the row; a
lease (`claim_token`, `claimed_until`) keeps two workers off one message. Proven on real MySQL: two processes refreshing
ten times make one row; two delivering at once send each message exactly once.

**No backlog burst.**
- Only the slot that applies now is created. A waiting earlier slot is `superseded`, never sent late.
- An end is announced only within 7 days.
- At the rehearsal's first boot on legacy data, each business got at most one message: a 72-hour reminder with 60 hours
  left; a 48-hour grace reminder rather than "grace started" plus reminders.

**Retired, never sent late.** A renewal, a suspension, a cancellation, a closed account or a claim that made a message
obsolete marks it `cancelled` with its reason (`period_changed`, `suspended`, `cancelled`, `closed`, `refused`,
`no_subscription`, `trial_not_available`, `deleted`). A reinstatement revives what a suspension stopped.

**The channel.** The recipient is the first active Owner. WhatsApp goes first, to the verified number.

Email is used **only** on a recorded fallback reason, and only to a **verified** address. The reasons:
- `whatsapp_disabled`;
- `template_unavailable`;
- `number_unverified`;
- `number_undeliverable`;
- `provider_refused`;
- `retries_exhausted`;
- `async_failed`.

**Never after an opt-out or a missing live-mode consent.** These end as `failed` with `opted_out` / `no_consent`, and
email does not stand in. The other failure reasons:
- `no_email`;
- `email_unavailable`;
- `email_failed`;
- `no_recipient`;
- `internal_error`.

Up to 5 attempts per channel; an accepted WhatsApp message is watched 3 days for an asynchronous failure.

**Privacy.**
- The outbox stores a masked destination, in the Owner-facing mask `+222••••0304` / `j•••@example.com` (`bbca6c3`),
  and a keyed hash (`MESSAGING_HASH_KEY`).
- It never stores the number, the address, a body or a code.
- The development email log names only the template, the language and the masked address.

**The portal resend.**
- Throttled: a minute after the newest request, 3 per 15 minutes, 10 per 24 hours. Every request counts, the automatic
  one included.
- Refused up front (503 `setup_delivery_unavailable`, the card saying *unavailable*) when nothing may carry it, e.g.
  after an opt-out.

## 7. The portal (D210, D211)

| Route | What |
| --- | --- |
| `POST platform/portal/sign-in` · `choose-account` | the app's identity; sets `erp_portal_session` (path `/`) and `erp_portal_refresh` (path `/api/v1/platform/portal`), both `HttpOnly; SameSite=Strict`, `Secure` in production (`COOKIE_SECURE` overrides); answers the session's CSRF token, never a token |
| `POST platform/portal/refresh` · `GET …/session` · `POST …/sign-out` | rotation from the refresh cookie alone (a spent one is refused); who is signed in; sign-out clears both cookies and revokes the session |
| `GET platform/my-subscription` · `…/status` | the account; the server-calculated panel: access, state, period, grace and allowance, the next and newest message, the actions allowed, the zone |
| `GET platform/my-subscription/trial` · `POST …/trial/claim` · `POST …/trial/setup/resend` | the card; the claim; the resend |
| `POST platform/my-subscription/contacts/email/verify/start` · `…/confirm` | the Owner's optional email address, verified: the code goes to the address already on the account, never one a request names |
| `GET platform/payment-instructions` | **unavailable**: no provider code and no price is configured (blocked, §12) |

**Security.**
- **Cookies are accepted only on the portal routes** (`/api/v\d+/platform/(my-subscription|portal|payment-instructions)`).
- **Unsafe requests** need the session-bound CSRF token in `x-csrf-token`, an HMAC of the session id. Missing, forged,
  another session's, or a genuine `Origin` alone: all refused `csrf_failed`.
- **Only the Owner.** A non-Owner's session is revoked at sign-in (403 `owner_only`).
- **No enumeration.** A wrong password and an unknown number get the same answer.
- **Rate limits.**
  - Sign-in: 10 a minute.
  - The claim, the resend and the email verification: 5 a minute.
- **Responses are `no-store`.**
- **Tenant isolation.** The company comes only from the session. The portal cookie opens no app route and nothing of
  the platform administration.
- **No decision rests on `Origin` or `Referer`.**

**D211.** The claim and the resend require the **portal's own session**. A bearer-authenticated request (the app's
session) is refused 403 `portal_session_required`. The guard reads which server-issued credential authenticated the
request, never where the request says it comes from. Found by the rehearsal: an app session could start the trial.

**Language.** EN/FR/AR, Arabic right to left. Dates use the business's zone, with the zone's name.

## 8. The console (platform administration)

All read-only. The existing administrator MFA and step-up guard every action.

| Page | Route | What |
| --- | --- | --- |
| Messages | `GET platform/notices` | every subscription message: business, which message (a paid end named by outcome), channel and masked destination, state, reason; counts by state; filters by state and kind (unknown values 400) |
| Grace | `GET platform/grace` | each decision with its period end and grace end in the business's zone, uses before, how things stand; summary: running, at the allowance, with a use |
| Free trials | `GET platform/trial-claims` | claims, running or ended, and eligible businesses that have not claimed |
| A business | `GET platform/businesses/:id/notices` + the grace card | its grace and allowance ("Used in the last 12 months: 3 of 3. Another becomes available on …"), next and newest messages, its message log; the history tells grace decisions in its own words |

Plans and versions, the audit log, suspension and the rest are the existing pages.

## 9. WhatsApp templates to approve (proposed copy)

Eight utility templates, configured by name with `WHATSAPP_TEMPLATE_PORTAL_INSTRUCTIONS`, `…_TRIAL_REMINDER`,
`…_TRIAL_EXPIRED`, `…_PAID_REMINDER`, `…_GRACE_STARTED`, `…_NO_GRACE`, `…_GRACE_REMINDER` and `…_GRACE_ENDED`.

**None is submitted to Meta.** Without an approved name, WhatsApp cannot carry that message: the email fallback is tried
(`template_unavailable`) and the status says so.

Each approved body carries the address **as fixed text**. Variables, in order, are the business's display name, the
time left in words, and exact instants in the business's zone with the zone's name, written by the server. The email
fallback has the same facts (`email-channel.ts`).

**`portal.instructions`** — `{{1}}` business
- EN: {{1}} can start one 7-day free trial of Dukan ERP. It has not started yet. To start it, sign in at https://dukan.tsxmr.com/subscription with the same details you use in the Dukan ERP app, and confirm. The trial starts as soon as you confirm and lasts exactly 7 days (168 hours); it cannot be paused or restarted. No payment is required.
- FR: {{1}} peut démarrer un essai gratuit de 7 jours de Dukan ERP. Il n’a pas encore commencé. Pour le démarrer, connectez-vous sur https://dukan.tsxmr.com/subscription avec les mêmes identifiants que dans l’application Dukan ERP, puis confirmez. L’essai commence dès votre confirmation et dure exactement 7 jours (168 heures) ; il ne peut être ni mis en pause ni redémarré. Aucun paiement n’est demandé.
- AR: {{1}} مؤهل لفترة تجريبية مجانية واحدة من Dukan ERP مدتها 7 أيام، ولم تبدأ بعد. لبدئها، سجّل الدخول على https://dukan.tsxmr.com/subscription بالبيانات نفسها التي تستخدمها في تطبيق Dukan ERP، ثم أكّد. تبدأ الفترة التجريبية فور تأكيدك وتستمر 7 أيام بالضبط (168 ساعة)، ولا يمكن إيقافها مؤقتًا أو إعادة بدئها. لا يلزم أي دفع.

**`subscription.trial_reminder`** — `{{1}}` business, `{{2}}` remaining, `{{3}}` ends
- EN: The free trial of {{1}} on Dukan ERP ends in {{2}}, on {{3}}. Free trials have no grace period: when it ends, the app becomes read-only until a subscription starts. To choose one, sign in at https://dukan.tsxmr.com/subscription.
- FR: L’essai gratuit de {{1}} sur Dukan ERP se termine dans {{2}}, le {{3}}. Les essais gratuits n’ont pas de période de grâce : à la fin de l’essai, l’application passe en lecture seule jusqu’au début d’un abonnement. Pour en choisir un, connectez-vous sur https://dukan.tsxmr.com/subscription.
- AR: تنتهي الفترة التجريبية المجانية لـ{{1}} في Dukan ERP خلال {{2}}، في {{3}}. لا توجد فترة سماح للفترات التجريبية: عند انتهائها يصبح التطبيق للقراءة فقط إلى أن يبدأ اشتراك. لاختيار اشتراك، سجّل الدخول على https://dukan.tsxmr.com/subscription.

**`subscription.trial_expired`** — `{{1}}` business, `{{2}}` ended
- EN: The free trial of {{1}} on Dukan ERP ended on {{2}}. The app is now read-only: your records stay readable, but new sales and changes are paused until a subscription starts. Free trials have no grace period. To start a subscription, sign in at https://dukan.tsxmr.com/subscription.
- FR: L’essai gratuit de {{1}} sur Dukan ERP s’est terminé le {{2}}. L’application est désormais en lecture seule : vos données restent consultables, mais les nouvelles ventes et modifications sont suspendues jusqu’au début d’un abonnement. Les essais gratuits n’ont pas de période de grâce. Pour démarrer un abonnement, connectez-vous sur https://dukan.tsxmr.com/subscription.
- AR: انتهت الفترة التجريبية المجانية لـ{{1}} في Dukan ERP في {{2}}. أصبح التطبيق الآن للقراءة فقط: تبقى سجلاتك متاحة للاطلاع، لكن المبيعات الجديدة والتعديلات متوقفة إلى أن يبدأ اشتراك. لا توجد فترة سماح للفترات التجريبية. لبدء اشتراك، سجّل الدخول على https://dukan.tsxmr.com/subscription.

**`subscription.paid_reminder`** — `{{1}}` business, `{{2}}` remaining, `{{3}}` ends
- EN: The Dukan ERP subscription of {{1}} ends in {{2}}, on {{3}}. To renew, sign in at https://dukan.tsxmr.com/subscription.
- FR: L’abonnement Dukan ERP de {{1}} se termine dans {{2}}, le {{3}}. Pour renouveler, connectez-vous sur https://dukan.tsxmr.com/subscription.
- AR: ينتهي اشتراك {{1}} في Dukan ERP خلال {{2}}، في {{3}}. للتجديد، سجّل الدخول على https://dukan.tsxmr.com/subscription.

**`subscription.grace_started`** — `{{1}}` business, `{{2}}` ended, `{{3}}` grace ends, `{{4}}` uses left
- EN: The Dukan ERP subscription of {{1}} ended on {{2}}. A 72-hour grace period has started: the app keeps working until {{3}}, then becomes read-only until the subscription is renewed. A business can receive 3 grace periods in any 12 months; left after this one: {{4}}. To renew, sign in at https://dukan.tsxmr.com/subscription.
- FR: L’abonnement Dukan ERP de {{1}} s’est terminé le {{2}}. Une période de grâce de 72 heures a commencé : l’application continue de fonctionner jusqu’au {{3}}, puis passera en lecture seule jusqu’au renouvellement. Un commerce peut bénéficier de 3 périodes de grâce sur 12 mois glissants ; restantes après celle-ci : {{4}}. Pour renouveler, connectez-vous sur https://dukan.tsxmr.com/subscription.
- AR: انتهى اشتراك {{1}} في Dukan ERP في {{2}}. بدأت فترة سماح مدتها 72 ساعة: يستمر التطبيق في العمل حتى {{3}}، ثم يصبح للقراءة فقط إلى أن يُجدَّد الاشتراك. يحق لكل متجر 3 فترات سماح خلال أي 12 شهرًا؛ المتبقية بعد هذه الفترة: {{4}}. للتجديد، سجّل الدخول على https://dukan.tsxmr.com/subscription.

**`subscription.no_grace`** — `{{1}}` business, `{{2}}` ended
- EN: The Dukan ERP subscription of {{1}} ended on {{2}}. There is no grace period this time: this business has already used its 3 grace periods of the last 12 months. The app is now read-only until the subscription is renewed. To renew, sign in at https://dukan.tsxmr.com/subscription.
- FR: L’abonnement Dukan ERP de {{1}} s’est terminé le {{2}}. Il n’y a pas de période de grâce cette fois : ce commerce a déjà utilisé ses 3 périodes de grâce des 12 derniers mois. L’application est désormais en lecture seule jusqu’au renouvellement. Pour renouveler, connectez-vous sur https://dukan.tsxmr.com/subscription.
- AR: انتهى اشتراك {{1}} في Dukan ERP في {{2}}. لا توجد فترة سماح هذه المرة: استخدم هذا المتجر فترات السماح الثلاث المتاحة له خلال آخر 12 شهرًا. أصبح التطبيق للقراءة فقط إلى أن يُجدَّد الاشتراك. للتجديد، سجّل الدخول على https://dukan.tsxmr.com/subscription.

**`subscription.grace_reminder`** — `{{1}}` business, `{{2}}` remaining, `{{3}}` grace ends
- EN: The grace period of {{1}} on Dukan ERP ends in {{2}}, on {{3}}. After that the app becomes read-only until the subscription is renewed. To renew, sign in at https://dukan.tsxmr.com/subscription.
- FR: La période de grâce de {{1}} sur Dukan ERP se termine dans {{2}}, le {{3}}. Ensuite, l’application passera en lecture seule jusqu’au renouvellement. Pour renouveler, connectez-vous sur https://dukan.tsxmr.com/subscription.
- AR: تنتهي فترة السماح لـ{{1}} في Dukan ERP خلال {{2}}، في {{3}}، ثم يصبح التطبيق للقراءة فقط إلى أن يُجدَّد الاشتراك. للتجديد، سجّل الدخول على https://dukan.tsxmr.com/subscription.

**`subscription.grace_ended`** — `{{1}}` business, `{{2}}` ended
- EN: The grace period of {{1}} on Dukan ERP ended on {{2}}. The app is now read-only: your records stay readable, but new sales and changes are paused until the subscription is renewed. To renew, sign in at https://dukan.tsxmr.com/subscription.
- FR: La période de grâce de {{1}} sur Dukan ERP s’est terminée le {{2}}. L’application est désormais en lecture seule : vos données restent consultables, mais les nouvelles ventes et modifications sont suspendues jusqu’au renouvellement. Pour renouveler, connectez-vous sur https://dukan.tsxmr.com/subscription.
- AR: انتهت فترة السماح لـ{{1}} في Dukan ERP في {{2}}. أصبح التطبيق الآن للقراءة فقط: تبقى سجلاتك متاحة للاطلاع، لكن المبيعات الجديدة والتعديلات متوقفة إلى أن يُجدَّد الاشتراك. للتجديد، سجّل الدخول على https://dukan.tsxmr.com/subscription.

## 10. Verification

### 10.1 Gates at the final commits

| Repository | Result |
| --- | --- |
| backend `3b8d144` (`17ea84b` changes one comment) | `prisma validate` (with CI's host-only `DATABASE_URL`); `tsc` clean; Jest 266 suites passed, 2 env-gated skipped; 4 793 tests passed, 34 skipped, **0 failed** |
| backend CI database gate (`deploy/ci-database-gates.sh`, a fresh disposable MySQL 8.4.11, TCP) | identities from the committed script; 98 migrations from empty, strict mode; permission catalogue; identity probes **23/0** (the two new `grace_episodes` trigger probes included); `trial-addons.mysql` **21/21**; `lifecycle.mysql` **10/10** |
| website `e020215` | typecheck; Vitest 33 files, **534/534**; the full, public and portal production builds each refused without their inputs; previews: 0 broken links, bundle audits pass (`--portal` for the portal); Playwright (Chromium) full **138/138**, public **148/148**, portal **34/34** (EN/FR/AR at 375 px and desktop, axe WCAG 2.1 AA, host headers, the confirmed claim with its CSRF token) |
| mobile `de40f72` | `tsc` clean; `expo lint` 0 errors (28 pre-existing warnings, cap 40); 115 pure test files; Jest 33 suites, **313/313**; release configuration sound; web export carries no server secret names; web and iOS bundle audit **PASS** |

The socket form of the CI gate (`MYSQL_SOCKET=…`) failed at step 2 here: Prisma could not authenticate the migrator
over the Unix socket. The TCP form, which CI uses, passed.

### 10.2 Migration 0099 on realistic data

The full drill record is in `docs/22` (2026-10-18).

**The data.** Built at `0098` by the `0098` code itself (backend `644f4f5`), through its own API:
- the ten QA boutiques: 800 IMEI units, 320 products, 1 243 audit rows;
- six administrator-created paid businesses: a month, ending in 60 hours, ended 30 hours ago, ended 5 days ago, ended
  40 days ago, suspended;
- four app registrations: two waiting, two claimed. One claim was aged by 8 days with direct SQL as root — the API
  cannot move time.

**Before.** A verified `--hex-blob` backup and a fingerprint (every table's rows and `CHECKSUM`, every trigger body, the
`HEX(id)` of eight tables).

**`prisma migrate deploy`.**
- Every pre-existing table is identical. The only extra row is `_prisma_migrations` (97 → 98).
- Plus 2 tables and 2 triggers, the index and the two event kinds.
- `prisma migrate diff` is byte-identical to the same diff at `0098`: 0099 adds no drift.

**Restore.** The Path-2 restore of the pre-0099 backup is identical to its fingerprint.

**Reverse.** The migration header's reverse SQL, run on a restored post-0099 copy, gives data identical to `0098`.
- One column's DDL text differs: `subscription_events.kind`, by a redundant `CHARACTER SET` token.
- `information_schema` is identical.
- With the explicit `CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci` (§13) the DDL is byte-identical.

### 10.3 The real-HTTP journey

The branch API runs on the migrated database with the development-log channels. A scratch script makes 48 distinct
checks; all pass in their final runs:

| Group | Checks |
| --- | --- |
| Registration | R1 no number → 400, nothing saved · R2 201 with a continuation, the number masked · R3 the code to the number opens a session · R4 number verified, email not, eligible · R5 **one** portal-instructions message, WhatsApp, masked · R6 template `portal.instructions`, its only variable the business's name · R7 the app's status: sent by WhatsApp, masked, dated, no link or action · R8 the entitlement `trial_available` |
| The app cannot act | A1 claim with the app session → 403 `portal_session_required` · A2 resend likewise, nothing queued |
| The portal | P1 wrong password and unknown number answer alike · P2 HttpOnly SameSite=Strict cookies, refresh path-scoped, `no-store`, no token in the body · P3 the session and its CSRF token · P4 the panel: `trial_available`, claim offered, allowance 3 in 12 months · P5 168 hours · P6 CSRF missing, forged, another session's, or Origin-only: refused · P7 stale terms refused with the current version · P8 the claim: now, exactly 168 hours · P9 replay 200, a new attempt refused, one claim · P10–P11 portal and app show it · P12 the cookie opens no app or admin route · P13 refresh rotates, the spent cookie is refused · P14 sign-out ends the session · E0 the optional email verified on the portal (a wrong code refused) |
| Lifecycle, in real time, through the administrator's routes | L1 renewal during grace from the original expiry · L2 the used grace stays used · L3 before expiry from the current end · L4 after expiry from the confirmation · L5 a 40-day-old end decided when first needed · L6 granted, granted, granted, **refused** · L7 the timeline's events · L8 its messages by WhatsApp · L9 the portal: read-only, none of three left · G1 a grace started for the app's screenshots |
| Console | O1 every message, counts, masked · O2 an unknown filter 400 · O3 decisions and summary · O4 trials claimed · O5 a business's messages; unknown 404 · O6 a customer Owner reaches none of it (cookie or app token) |
| Fallback and opt-out | B2 with WhatsApp disabled, the portal resend goes by email to the verified address, reason `whatsapp_disabled` · B3 the app says so · B4 the email in the Owner's language, only the masked address logged · C1 after an opt-out, nothing may carry it: 503 up front, nothing queued, no email · D1 the destination masked as the verified contact is listed |
| Rate limits (defaults) | C2 the 11th portal sign-in in a minute → 429 · C3 the 6th claim → 429 |

**Failures on the way, none a product defect except the one fixed by D211:**
- **Phase A ran 40 checks: 29 passed.** Eleven failed for two script errors, and all eleven passed when rerun:
  - R2 and R6 expected `channel: 'whatsapp'` and a URL variable. The API names the contact `phone`, and the address is
    fixed text in the approved template.
  - L1 and L3–L9 failed, and O3 depended on them: the script skipped the administrator's step-up.
  - L2 passed vacuously and was rerun.
- **B1** (registration refused when WhatsApp cannot carry the code) cannot be shown on a development server, whose dev
  outbox takes every channel. It is `registration-flow.spec`'s.
- **B3** first failed on the script's expired app token; **C1** first expected a failed message rather than the
  up-front refusal; **D1** first failed on the script's `mysql` client charset. All three passed when rerun.
- **First boot on the legacy data:** the sweeper decided the two recent ends and sent four messages, at most one per
  business. Five minutes of passes added nothing.

### 10.4 Screenshots

Taken against the real API: desktop Chromium, not a device. They are session evidence, not committed (this repository
holds no images).

- **The portal:** 23 images:
  - sign-in EN/FR/AR at 375 px and desktop;
  - eligible, not started (EN/FR/AR) and the confirmation step;
  - trial running (FR);
  - no grace left (AR, EN);
  - renewed (EN).
- **The console:** 4 images: messages, grace, trials, a business. None of the 27 has sideways scroll, a console error,
  or more or fewer than one `h1`.
- **The app** (web export): 9 images:
  - registration (EN, AR);
  - the trial card (EN/FR/AR);
  - trial running;
  - grace with 2 of 3 left (EN, FR);
  - no grace left (AR).
  None has a raw key, `undefined`, sideways scroll, an uncaught error or a website link.

**Seen and left as it was.** On the portal, a business that has not started shows the requests section's refusal ("This
business has not started yet") in a red notice. This is pre-existing (`0eedfaa` chose to show it); hiding the section
until the business starts is a candidate improvement.

**Not verified:**
- a physical device;
- the real WhatsApp Cloud API or SMTP;
- Meta template approval;
- the production stack, DNS and Cloudflare.

## 11. Configuration

**API**
- `PORTAL_ORIGIN`: `https://dukan.tsxmr.com` in production; staging needs its own HTTPS origin.
- `MESSAGING_HASH_KEY`, required with a real channel.
- The eight `WHATSAPP_TEMPLATE_*` names: optional, each unset → `template_unavailable`.
- `CORS_ORIGINS` must include `https://dukan.tsxmr.com`.
- The minute worker runs in every API process; the outbox lease makes that safe.

**Website**
- The PORTAL gate's inputs (§2).
- A Cloudflare Pages project for `dukan.tsxmr.com`. Its `_headers` and `_redirects` are generated by the build.

**App**
- `EXPO_PUBLIC_LEGAL_ORIGIN` only. `EXPO_PUBLIC_SIGNUP_URL` and `EXPO_PUBLIC_PORTAL_URL` are gone, and the boundary
  rules refuse them.

## 12. Before rollout (blocked; owner or provider)

1. **Deploy approval.** The owner's explicit approval to deploy the portal, merge the branches, apply `0099` to
   production (with `docs/22`'s backup first) and enable live messaging. None was given.
2. **The site and DNS.** A Pages project and a DNS record for `dukan.tsxmr.com`. Not created.
3. **Templates.** The eight templates submitted, approved, and configured by name (§9).
4. **WhatsApp consent in the app.** The app does not capture it yet, and live mode refuses a registration without it.
   It must be added before WhatsApp goes live (D212).
5. **Payment instructions.** Unavailable until real provider codes and prices are decided. Nothing invented.
6. **Email.** The SMTP notifications sender configured for the fallback (`docs/98`).
7. **Legal texts.** The terms already describe read-only after the end; the grace allowance and the portal may need a
   line once approved (`docs/97`).

## 13. Rollback

- **Code.** Nothing is merged. Rolling back is not merging: the production branches never moved.
- **Database.** `0099` is additive, so a deployed API at `0098` code ignores the new tables. To remove them, follow
  this procedure, which was proven in the drill:
  1. Stop the API that writes the tables.
  2. Take a backup.
  3. Delete the `subscription_events` rows of kinds `grace_started` and `grace_unavailable`, or MySQL blanks them.
  4. Run the reverse below.
- **A Git rollback does not roll back the database.**

```sql
DROP TABLE `subscription_notices`;
DROP TABLE `grace_episodes`;
DROP INDEX `ix_subscriptions_period_end` ON `subscriptions`;
ALTER TABLE `subscription_events` MODIFY `kind` ENUM('created','extended','branches_changed','seats_changed','complimentary_granted','complimentary_revoked','backfilled','registered','administrative_grant','suspended','reinstated','cancelled','approved','rejected','period_corrected','seat_requested','seat_paid','staff_activated','seat_closed','store_requested','activity_requested','activity_changed','activity_scheduled','renewed','trial_eligible','trial_claimed','trial_expired') CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL;
DELETE FROM `_prisma_migrations` WHERE `migration_name` = '0099_grace_and_notices';
```

## 14. Questions for the owner (D212)

1. **Read-only after expiry.** The brief says a trial's end stops "operational access", keeping only sign-in,
   subscription, support, legal pages and deletion. The recorded rule, the terms and the public pages say read-only
   (records readable and exportable). Read-only is kept. Confirm, or ask for the stricter mode.
2. **Opt-out.** An Owner who opted out of optional WhatsApp messages, or a live-mode number without consent, gets
   **no** email fallback. Confirm.
3. **Unverified number.** An unverified or missing number falls back to a verified email. Confirm.
4. **Grants.** Platform grants send no lifecycle messages and have no grace. Confirm.
5. **Recipient.** The first active Owner receives every message. Confirm.
6. **Announcement window.** An end is announced within 7 days, no later. Confirm.
7. **Ends before 0099.** They are decided lazily (the sweeper covers about 10 days), and a decided pre-rollout end
   counts against the allowance. Confirm.
8. **Changing the email address.** The portal verifies the address already on the account; changing it is not in this
   phase.
9. **Retired routes.** The old portal handoff routes remain unused on the API. Remove them in a later phase?
10. **At deployment,** at most one message per business: the current slot. Confirm.
11. **WhatsApp consent capture** in the app is needed before live WhatsApp (§12.4). Approve the work.
12. **D211.** Claims and resends refused to the app's session. Confirm this reading of "web-only".

## 15. Next safe step

The owner reviews this record and the screenshots and answers §14. Only on explicit approval: the Pages project and DNS
for `dukan.tsxmr.com`; the merge; `0099` on production after a verified backup; template submission; live messaging.

## 16. Discrepancies reported at takeover, and what became of them

| # | Found | Now |
| --- | --- | --- |
| 1 | A concurrent cloud session (website preview) claimed and released this repository while the claim was being written; its branch `website-balanced-motion` was not in the handoff | the claim was rebased on its `910c732`, nothing forced; none of its branches was touched |
| 2 | The handoff counted `production-deploy` 13 commits ahead of `reports-export`; Git showed 12 | recorded |
| 3 | `docs/68` §5 described an `x-requested-with` CSRF check the API never made | the portal has a session-bound CSRF token and `SameSite=Strict` cookies limited to its routes (D210); `docs/68` carries the correction |
| 4 | `GET platform/my-subscription` answered any tenant session | the Owner's alone (D132's deferred rule), as every portal route |
| 5 | The brief supersedes recorded decisions | marked in place in `docs/21` (D169, D170, D173, D175, D177, D181, Milestone K) |
| 6 | "Stops operational access" after a trial against the recorded read-only rule | read-only kept; question 1 of §14 |
| 7 | No route to verify an email address after sign-up | the Owner verifies it on the portal (§7) |
