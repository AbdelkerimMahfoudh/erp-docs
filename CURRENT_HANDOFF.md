# CURRENT_HANDOFF

Status: IN_PROGRESS
Owner: CLAUDE (cloud), https://claude.ai/code/session_01PLhoUhSVGTwofTQRXsJNof
started_at_utc: 2026-10-19T05:40Z
takeover: from READY_FOR_HANDOFF (owner NONE), released by this same session at `b39123e`; that handoff was complete.
heads_at_takeover: erp-backend `whatsapp-consent` `c3c8e9e`; erp-mobile `whatsapp-consent` `452ce08`; erp-control-web
`whatsapp-consent` `4764afd` (production `tsx-public-site` `bf62a72`, untouched); erp-docs `master` `b39123e`. All
clean and level with their remotes.
migration_chain (verified): production `production-deploy` `644f4f5` (0098) ⊂ `dukan-portal-lifecycle` `17ea84b`
(0099) ⊂ `whatsapp-consent` `c3c8e9e` (0100). No other branch defines 0099–0101. `0101_staff_invitations` goes on
`whatsapp-consent` only.
active_phase: the owner's approved employee-invitation activation (2026-10-19):
- Owner-only creation, cancellation and reinvitation;
- creation sends nothing, by WhatsApp or email: it issues a 72-hour, one-use invitation reference, shown once, with a
  purpose-keyed hash stored;
- the employee opens it (manual entry, or `dukanerp://join?ref=`), types the matching number, accepts the consent
  and requests the code;
- confirmation is atomic: consent, invitation and account;
- cancellation and reinvitation end the pending consent;
- migration `0101` (plus the `cancelled` event in amended `0100`), rehearsed on disposable databases only.
Nothing merged, deployed, enabled or sent.
next_action: backend migration 0101 and the invitation service.

Previous state (unchanged below): READY_FOR_HANDOFF, owner NONE.

## WhatsApp consent corrections: pending until verified, employee self-consent, email only for informational notices — on branches, verified, not deployed (2026-10-19, CLAUDE, cloud)

| Repository | Branch | HEAD (pushed) | Base (unmoved) | This session |
| --- | --- | --- | --- | --- |
| `erp-backend` | `whatsapp-consent` | `c3c8e9e` | `dukan-portal-lifecycle` `17ea84b` | `c6ea3b7` lifecycle, with 0100 amended in place; `c21af86` routing; `82a0c58` employee consent; `e1e4f8e`, `c3c8e9e` specs |
| `erp-mobile` | `whatsapp-consent` | `452ce08` | `dukan-portal-lifecycle` `de40f72` | the *Join your team* screen; team "waiting for them"; the lifecycle states; the withdrawal wording |
| `erp-control-web` | `whatsapp-consent` (new) | `4764afd` | `dukan-portal` `0fd418a` | the fallback reasons `consent_missing` and `consent_withdrawn`, named in EN/FR/AR in the portal and console |
| `erp-control-web` | `tsx-public-site` | `bf62a72` | — | **production** (tsxmr.com), untouched |
| `erp-docs` | `master` | the commit carrying this file | `4aa4ef1` | D213 corrected; `docs/98` §12; `docs/101` §17; `docs/24` §67 (C13–C18); session log |

All four trees are clean and level with their remotes. The production API (`644f4f5`), the databases, DNS and
Cloudflare were not touched.

**What changed** (record: `docs/101` §17; decision: D213):
1. **Lifecycle.**
   - `pending_unverified` is written at the tick and code request.
   - `active` is written only when that number is verified: in the same transaction, naming the exact pending row
     (`pending_id`, UNIQUE).
   - Later events are `withdrawn`, `superseded` (number replaced) and `expired` (24 h, hourly sweep).
   - Pending consent authorises only its own verification code.
   - Concurrency and retries are idempotent, with a row lock and one conclusion per pending row.
   - No full number is stored or logged.
2. **Routing.**
   - WhatsApp is used only when the number is verified, consent is active, the number is deliverable, the template is
     approved and the provider is ready.
   - Email fallback applies only to informational notices: portal instructions, trial and subscription status, 3/2/1
     reminders, grace and read-only notices. It is one email, to a verified address, only when email is ready;
     otherwise the notice is honestly recorded not sent. Never both channels.
   - A missing or withdrawn consent now falls back for these notices (`consent_missing`, `consent_withdrawn`).
   - Never by email: number verification, sign-in codes, recovery, deletion confirmation, employee verification,
     changed-number verification, and anything granting access or authorising deletion. Financial reports stay
     WhatsApp-only; none is sent today.
   - Withdrawing WhatsApp is not withdrawing email.
3. **Employees.**
   - The employee agrees on their own phone (sign-in → *I was added to a team*), as actor, with source
     `employee_activation`.
   - The Owner cannot agree for them or send their WhatsApp code (`awaiting_consent`, `employee_consent_required`).
   - Existing employees are not migrated.

**Migration `0100`, amended in place** (it never reached production): it adds `pending_id` with a UNIQUE index and
`ck_whatsapp_consent_conclusion`.
- Applied only to disposable databases on a throwaway MySQL 8.4.11 in the scratch directory: the CI gate's
  `phonestore`, `addon_ci` and `grace_ci`, and the rehearsal's `consent_rehearsal`, `consent_restore` and
  `consent_reverse`.
- All of them are dropped, and the server is stopped and deleted.
- Rehearsal backups (deleted): before `2239317664cfd8c4…`, after `0d06f30257630004…`.
- The exact reverse, now including `pending_id`, the index and the CHECK, is in `docs/101` §17.7.

**Verification at the final HEADs**

| Area | Result |
| --- | --- |
| backend | `tsc` clean; Prisma schema valid; Jest 266 suites, 4 839 passed, 0 failed (3 env-gated real-MySQL suites skipped, run below) |
| CI database gate (fresh MySQL 8.4.11) | identities and triggers 25/0; permission catalogue 73/73; `trial-addons.mysql` 21/21; `lifecycle.mysql` 10/10; `consent.mysql` 9/9 (concurrent activation, expiry race, UNIQUE, CHECKs, triggers) |
| 0100 rehearsal | upgrade from 0099 with 561 D181-era events unchanged; 0 of 400 numbers consented; on the upgraded data, one activation from two concurrent verifications and one expiry from two racing sweeps; restore and reverse matched the backup |
| mobile | `tsc`; lint 0 errors (28 pre-existing warnings); 117 pure files; Jest 36 suites, 340 tests |
| exports | web and iOS exports; bundle audit PASS; release build refused without its inputs; secret scan clean |
| Expo Doctor | **not passed:** 10 Expo packages a patch behind SDK 57; no dependency changed (unchanged since the last phase) |
| website `whatsapp-consent` | typecheck; Vitest 33 files, 535 tests; preview builds of the full, portal and public surfaces with link and bundle audits PASS (the production build refuses by design: legal drafts) |
| EN/FR/AR | key parity: mobile 3 926, website 730 |
| messages | test and recording channels only; no provider called; nothing sent |

**Known risks and limits:**
- Nothing ran on a device (`docs/24` §67, C1–C18), on Meta's API or SMTP, or on the production stack.
- An employee's pending agreement that expires is silent: the Owner keeps seeing "waiting for them" until the employee
  asks again (an open question in D213).
- The old failure reasons `no_consent` and `opted_out` stay readable for earlier rows; new rows use the fallback
  reasons.
- `scripts/qa-boutiques.ts` still registers without a WhatsApp number (broken since 0099, before this work).

**Not done (by instruction):**
- merging, or any deployment;
- applying `0099` or `0100` to any persistent database;
- touching Cloudflare;
- activating WhatsApp, email or onboarding;
- approving or submitting templates;
- sending any real message.

**Waiting on the owner and providers:**
1. Counsel's review of the EN/FR/AR wording (`docs/101` §17.2).
2. Meta: business verification, the display name, the opt-in policy check, the template categories, the real number,
   the webhook and the permanent token.
3. The device checks of `docs/24` §67.
4. The remaining D212 questions (`docs/101` §14: 2–10, 12).
5. Explicit approval, or not, to merge the three `whatsapp-consent` branches and for each rollout step of `docs/101`
   §12. `0100` goes immediately after `0099`, after a verified backup.
6. Expo Doctor's patch drift: approve a dependency update as its own change, or leave it.

**Next exact action:** none until the owner answers. On an explicit approval, the next session:
1. claims this file;
2. re-runs the gates at these HEADs (backend `c3c8e9e`, mobile `452ce08`, web `4764afd`);
3. takes and checks the production backup (`docs/22`);
4. follows `docs/101` §12.

The previous records follow. The consent record of 02:41Z below is superseded on routing, the lifecycle and employees
by this one.

---

Previous session: CLAUDE (cloud, website session), https://claude.ai/code/session_01WqJ1WH6TJWfctbXGjyqFZt — claim
`ff0a4de` at 03:58Z, complete at 04:12Z.

## The website in production at `bf62a72`; CI evidence masks idempotency keys (2026-10-19, CLAUDE, cloud)

| Repository | Branch | HEAD (pushed) | State |
| --- | --- | --- | --- |
| `erp-control-web` | `tsx-public-site` | `bf62a72` | **production** (tsxmr.com): `1b9c448`, the approved Balanced motion release, plus `.gitleaksignore` only; CI green |
| `erp-control-web` | `dukan-portal` | `0fd418a` | `ed6c583` the same `.gitleaksignore`; `0fd418a` the portal test's evidence masks `idempotencyKey`; CI green (run `39197649573`) |
| `erp-control-web` | `ops/verify-preview` | `451218b` | tooling only (a commit locally, as a preview, or on tsxmr.com after a promotion) |
| `erp-backend` | `whatsapp-consent` | `35eacf8` | untouched (the consent phase below) |
| `erp-mobile` | `whatsapp-consent` | `dff57dc` | untouched (the consent phase below) |
| `erp-docs` | `master` | the commit carrying this file | D201 in production (`docs/21`), `docs/96` §2, `docs/95` (promotion; preview correction), session log |

The production API (`644f4f5`), the databases, DNS and Cloudflare settings were not touched by this session.

**Verified:**
- tsxmr.com against the build of `bf62a72`: 23/23 production checks (every file byte-for-byte), WebKit 27/27, public
  suite 160/160, no retries (run `39193861703`).
- CI green on `bf62a72` (run `39193773528`) and on `0fd418a`. The full-history gitleaks scan finds no leaks, and the
  evidence `0fd418a` committed shows `"idempotencyKey": "[masked: 36 characters]"`.

**Owner settings still open (Cloudflare, `docs/95` last section):**
- Preview branch back to None.
- The Preview variables: empty them, or keep them.
- The `site-redesign` and `website-balanced-motion` preview deployments still answer (noindex) until deleted.

**WhatsApp operational consent:** *(stale: superseded by the corrections record above; employees now agree on their own
phone.)* The phase is complete (record below). Its one code follow-up for backend and mobile, asking employees for the
consent in their own account (D213), is put to the owner as a plan. Nothing was built.

**Next exact action:** none until the owner answers. The consent phase's own next action (below) still holds.

The previous records follow, unchanged except the two stale website lines, now marked.

---

last_session: CLAUDE (cloud), https://claude.ai/code/session_01PLhoUhSVGTwofTQRXsJNof — started 2026-10-19T02:41Z (claim
`65cbcfc`), complete.

## WhatsApp operational consent capture — on branches, verified, not deployed (2026-10-19, CLAUDE, cloud)

| Repository | Branch | HEAD (pushed) | Base (unmoved) | This phase |
| --- | --- | --- | --- | --- |
| `erp-backend` | `whatsapp-consent` | `35eacf8` | `dukan-portal-lifecycle` `17ea84b` | `49a61fc` migration 0100; `8188146` consent, enforcement, routing; `35eacf8` real-MySQL spec in the CI gate |
| `erp-mobile` | `whatsapp-consent` | `dff57dc` | `dukan-portal-lifecycle` `de40f72` | the registration checkbox, Communication preferences, the account's request, the new number's consent |
| `erp-control-web` | `dukan-portal` | `e020215` | — | untouched (since: `0fd418a`, CI evidence masking only; record above) |
| `erp-docs` | `master` | the commit carrying this file | `1da1a71` | D213 (+ D212 Q1/Q11 answered) in `docs/21`; `docs/98` §12; `docs/101` §17; `docs/24` §67; session log |

All four trees are clean and level with their remotes. The production API (`644f4f5`) was not touched.

**The record:** `docs/101` §17 (wording, behaviour, routing table, migration, verification); decision D213 in `docs/21`.

**Consent `wa-operational-2026-10-19`:**
- One purpose, `operational_whatsapp`; never marketing.
- Required at registration in every mode, before anything is saved.
- Recorded with version, locale shown, source, time, actor and an audit event carrying the address.
- A replay writes nothing. A new number needs its own consent; the replaced number's ends.
- No backfill: earlier grants are outdated and count for nothing.
- Withdrawal (app or STOP) stops every message, codes included. It needs the support-recovery acknowledgement when
  WhatsApp is the only verified contact. Re-consent is a new event; the history is append-only.

**Routing (every sender):** verified recipient → consent in force → opt-out/undeliverable → template and provider
readiness → switches → idempotency and pacing. WhatsApp only when it can; one verified-email fallback only for a
WhatsApp-side reason; never both; a missing consent or a withdrawal is an honest `no_consent` / `opted_out`, never
emailed round.

**Migration `0100_whatsapp_operational_consent`** (additive, branch head):
- Applied only to disposable databases on a throwaway MySQL 8.4.11 in the session's scratch directory: the CI gate's
  `phonestore`, `addon_ci`, `grace_ci`, and the rehearsal's `consent_rehearsal`, `consent_restore`, `consent_reverse`.
- All dropped; the server stopped and deleted.
- Rehearsal backups (deleted): before `38e279e26c741982…`, after `cf35f2e4c189f9b7…`. The exact reverse is in
  `docs/101` §17.6.
- Never on staging or production. A Git rollback does not undo it on a database; code at `17ea84b` runs with it
  applied.

**Verification at the final commits**

| Area | Result |
| --- | --- |
| backend | `tsc` clean; Prisma schema valid; Jest 266 suites, 4 817 passed, 0 failed (3 env-gated real-MySQL suites skipped, run below) |
| CI database gate (fresh MySQL 8.4.11) | identities and triggers 25/0; permission catalogue 73/73, no drift; `trial-addons.mysql` 21/21; `lifecycle.mysql` 10/10; `consent.mysql` 6/6 |
| 0100 rehearsal | 561 D181-era events unchanged; 0 of 400 numbers consented after it; restore and reverse matched the backup |
| mobile | `tsc`; lint 0 errors (28 warnings, none in a touched file); 116 pure files; Jest 34 suites, 333 tests |
| exports | web and iOS exports; bundle audit PASS; release build refused without inputs; secret scan clean |
| Expo Doctor | **20/21 — not passed:** 10 Expo packages a patch behind SDK 57's current releases; no dependency changed here |
| messages | test and recording channels only; no provider called; nothing sent |

**Known risks and limits:**
- Nothing ran on a device (`docs/24` §67), on Meta's API or SMTP, or on the production stack.
- The registration grant is recorded at the registration request (the explicit act), not at verification. An
  abandoned registration leaves a grant for a number nobody verified; nothing proactive is ever sent to an unverified
  number.
- Employees never see this consent; they receive only their own verification code (D213 follow-up).
- The portal shows no consent state yet.
- `scripts/qa-boutiques.ts` registers without a WhatsApp number (broken since 0099, before this phase) and so without
  a consent.

**Not done (by instruction):** merge; deployment; `0099` or `0100` on any persistent database; Cloudflare; WhatsApp,
email or onboarding activation; template approval or submission; any real message.

**Waiting on the owner and providers:**
1. Counsel's review of the EN/FR/AR wording (`docs/101` §17.2). Any change is a new version.
2. Meta: business verification, the display name, the opt-in policy check, the template categories, the real number,
   the webhook, the permanent token.
3. The device checks of `docs/24` §67.
4. The remaining D212 questions (`docs/101` §14: 2–10, 12). Q1 and Q11 are answered (D213).
5. Explicit approval, or not, for each rollout step of `docs/101` §12; `0100` goes with `0099`, after a verified backup.
6. Expo Doctor's patch drift: approve an `npx expo install --check` dependency update as its own change, or leave it.

**Next exact action:** none until the owner answers. On an explicit rollout approval, the next session:
1. claims this file;
2. re-runs the four repositories' gates at these HEADs;
3. takes the production backup and checks it (`docs/22`);
4. follows `docs/101` §12, with `0100` immediately after `0099`.

The previous records follow, unchanged.

---

last_session: CLAUDE (local session, the owner's PC), 2026-10-19, started 01:53Z (claim `20d1b53`), complete.

## The production backup key rotated; the API live at https://api.tsxmr.com, closed to customers (2026-10-19, CLAUDE, local)

| Repository | Branch | HEAD | This phase |
| --- | --- | --- | --- |
| `erp-backend` | `production-deploy` | `644f4f5` | deployed to tsxmr-app-01 (image id `sha256:7a0e9a08f94f…`); untouched by the rotation |
| `erp-backend` | `dukan-portal-lifecycle` | `17ea84b` | the cloud portal phase: NOT deployed (needs its own approval: `docs/100` note, `docs/101`) |
| `erp-mobile` | `reports-export` | `e6773aa` | untouched |
| `erp-control-web` | `tsx-public-site` | `e953c58` | untouched (stale: `bf62a72` in production since 2026-10-19 03:14Z; record above) |
| `erp-docs` | `master` | the commit carrying this file | `docs/100` §5, §14 step 4, §15; session log |

**The rotation (`docs/100` §15).** The first production backup identity went through an online CSV converter, so it is
treated as compromised. The steps:
- A **new age identity**: its private half is only in `.tsxmr\production-backup-identity-v2.txt` and the owner's Google
  Password Manager (`api.tsxmr.com` / `age-backup-identity`, added by hand).
- The server's recipient file holds only the new public key.
- A fresh backup, `phonestore-20261019T015638Z`, went off-host to the laptop and back. Restored with the new identity:
  118 tables, 53 triggers, every `CHECKSUM` matched. **PASSED** (`kind=laptop`).
- The old key's two backups (empty platform: 0 companies, 0 users) were deleted from the server.
- References to the old key, all **0**: on the server (config, scripts, units, cron, Docker volumes) and in the four
  repositories with their full history. Private age keys on the server: 0.
- The only timer named "backup" is Ubuntu's own `dpkg-db-backup`.
- Smoke **15/15** afterwards.

**Live (unchanged):**
- api.tsxmr.com is DNS-only; Let's Encrypt TLS valid to 2027-01-17.
- 97/97 migrations; only 22/80/443 open.
- Email, WhatsApp and onboarding **disabled** (sign-up answers 503); no real data.

**Owner actions:**
1. **Empty the three key files from the Windows Recycle Bin** (right-click each, then Delete):
   - `production-backup-identity.csv` (from `Downloads`, the converter's output);
   - `production-backup-identity` (from `.tsxmr`, the old key);
   - `google-password-import.csv` (from `.tsxmr`).
2. Never send the identity through an online service: converters, pastebins or chat (`docs/100` §5).
3. Before any external test, trial or customer:
   - the Storage Box, with a restore from it;
   - the email-tracking decision;
   - then `EMAIL_CHANNEL=smtp`.

**Done by the owner (2026-10-19):** `ssh-add -D` and the `ssh-agent` service stopped (startup Manual, checked). The
next SSH session to tsxmr-app-01 asks for the key's passphrase, or the agent is started again for that session.

**Next possible phases (each on the owner's approval):**
- merge and deploy the portal phase (`dukan-portal-lifecycle`, migration 0099, `PORTAL_ORIGIN`);
- the `deploy.sh` certificate-wait follow-up;
- the Storage Box.

---

last_session: CLAUDE (cloud), https://claude.ai/code/session_01PLhoUhSVGTwofTQRXsJNof — started 2026-10-18T08:54Z (claim
`a7260b9` at 09:26Z), complete at 13:49Z.

## The Dukan ERP portal, web-only trial claiming, limited grace and prioritized messaging — on branches, verified, not deployed (2026-10-18, CLAUDE, cloud)

| Repository | Branch | HEAD (pushed) | Base (unmoved) | This phase |
| --- | --- | --- | --- | --- |
| `erp-backend` | `dukan-portal-lifecycle` | `17ea84b` | `production-deploy` `644f4f5` | migration `0099`, the lifecycle and messages, the portal session, console oversight, D211, the Owner-facing mask, the real-MySQL gate in CI (`docs/101` §1) |
| `erp-control-web` | `dukan-portal` | `e020215` | `tsx-public-site` `e953c58` (`main` `0417bfe`) | the portal surface for `dukan.tsxmr.com/subscription`, the console pages, grace in the history |
| `erp-mobile` | `dukan-portal-lifecycle` | `de40f72` | `reports-export` `e6773aa` | the display-only status, WhatsApp required at sign-up |
| `erp-docs` | `master` | the commit carrying this file | `910c732` | `docs/101`, D202–D212, `docs/22` drill E.6, notes in 68/76/96/98/99/100, the session log |

All four trees are clean and level with their remotes. The concurrent website session's branches
(`website-balanced-motion`, `ops/verify-preview`, `ci-evidence`) were not touched.

**The record:** `docs/101`, the contract as built. The decisions are D202–D212 in `docs/21`. The superseded parts of
D169, D170, D173, D175, D177, D181 and Milestone K are marked in place.

**Migration:**
- `0099_grace_and_notices` (additive) is the branch's head.
- It was applied only to disposable databases on throwaway MySQL 8.4.11 servers in the session's scratch directory:
  - `prisma_qa_dk`, its restore and reverse copies;
  - `grace_rehearsal`;
  - the CI gate's `phonestore`, `addon_ci` and `grace_ci`.
- Every one was dropped; both servers were stopped and deleted.
- Never applied to staging or production. A Git rollback would not undo it on a database. The exact reverse is in
  `docs/101` §13.
- Rehearsal backups (deleted with the scratch directory): before `f475ed3acf9c1932…`, after `efa2e68c6cfd25ee…`.

**Verification at the final commits**

| Area | Result |
| --- | --- |
| backend | `tsc` clean; Jest 266 suites, 4 793 passed, 0 failed (2 env-gated skipped) |
| CI database gate (fresh server) | identities 23/0; `trial-addons.mysql` 21/21; `lifecycle.mysql` 10/10 |
| website | Vitest 534/534; three production builds refused without their inputs; previews 0 broken links, audits passing; Playwright full 138, public 148, portal 34 |
| mobile | `tsc`; lint 0 errors; 115 pure files; Jest 313/313; bundle audits PASS |
| real-HTTP journey | 48 checks passing in their final runs (`docs/101` §10.3) |
| screenshots | 36 against the real API (23 portal, 4 console, 9 app); not committed |

**Known risks and limits:**
- Nothing ran on a device, on the real WhatsApp Cloud API or SMTP, or on the production stack.
- B1 (registration refused when the code cannot go) is unit-proven only: a development server's dev outbox takes every
  channel.
- Live WhatsApp needs consent capture in the app first. Live mode refuses a registration without it.
- The socket form of `deploy/ci-database-gates.sh` fails at step 2 here; the TCP form passes.

**Not done (by instruction):**
- deployment and the merge;
- DNS and Cloudflare: no Pages project or record for `dukan.tsxmr.com`;
- production data;
- SMTP or WhatsApp activation;
- template submission;
- `0099` on any persistent database;
- any message to a real person.

**Waiting on the owner:**
1. The twelve questions of D212 (`docs/101` §14). The first, read-only after a trial's end, is the one that would change
   behaviour.
2. Explicit approval, or not, to deploy:
   - the Pages project and DNS for `dukan.tsxmr.com`;
   - the merge of the three branches;
   - `0099` on production after a verified backup (`docs/22`);
   - `CORS_ORIGINS` and `PORTAL_ORIGIN`;
   - template submission;
   - live messaging.
3. Provider work, in Meta and Brevo: the eight templates; the notifications sender.
4. The app's WhatsApp consent capture: approve the work before any live WhatsApp.

**Next exact action:** none until the owner answers. On an explicit rollout approval, the next session:
1. claims this file;
2. re-runs the four repositories' gates at these HEADs;
3. takes the production backup and checks it (`docs/22`);
4. follows `docs/101` §12 in order.

The previous records follow, unchanged.

---

last_session: CLAUDE (cloud session, website preview), started 2026-10-18T09:25Z (claim `bae81af`), complete (docs
only).

## D201 recorded; a branch-only website preview pending (2026-10-18, CLAUDE, cloud)

| Repository | Branch | HEAD | This phase |
| --- | --- | --- | --- |
| `erp-backend` | `production-deploy` / `reports-export` | `644f4f5` / `d3c11a8` | untouched |
| `erp-mobile` | `reports-export` | `e6773aa` | untouched |
| `erp-control-web` | `tsx-public-site` (production) | `e953c58` | untouched |
| `erp-control-web` | `website-balanced-motion` | `1b9c448` | CI green; not in production |
| `erp-docs` | `master` | the commit carrying this file | D201, `docs/95` and `docs/96` notes, session log |

**D201:**
- the website's Dukan ERP illustration may show its labelled fictional MRU amounts, and Bankily and Sedad as plain-text
  examples;
- nowhere else; no subscription price anywhere;
- legal and `/in-app/` pages unchanged.

**Still in progress outside this file (not a claim):** CLAUDE (cloud, website) continues on `erp-control-web` only:
- branch `website-balanced-motion`, at most a notes-only commit;
- a new tooling branch `ops/verify-preview` (verification workflow; no site code);
- workflow evidence commits on `ci-evidence`.

**Waiting on the owner:**
1. **The Chrome-extension session:** Pages `tsxmr-public` → Settings → Builds → Branch control → Preview branch: Custom
   branches. Include exactly `website-balanced-motion` (no wildcard, nothing else). Then deploy it (`docs/95`, last
   section).
2. **The owner's iPhone review** of the preview. Promotion to tsxmr.com only on the owner's explicit approval.
3. **After the review:** Preview branch back to **None**.

---

last_session: CLAUDE (local session, the owner's PC), started 2026-10-18T05:53Z (claim `23f93f6`), complete.

## The production API package, rehearsed once on tsxmr-app-01 and torn down (2026-10-18, CLAUDE, local)

| Repository | Branch | HEAD | This phase |
| --- | --- | --- | --- |
| `erp-backend` | `production-deploy` (new, pushed) | `644f4f5` | 13 commits from `reports-export` `d3c11a8`; CI run 39109070367 green (6/6) |
| `erp-backend` | `reports-export` | `d3c11a8` | untouched (merging `production-deploy` is a later decision) |
| `erp-mobile` | `reports-export` | `e6773aa` | untouched |
| `erp-control-web` | `tsx-public-site` | `e953c58` | untouched (local `site-redesign` fast-forwarded to it) |
| `erp-docs` | `master` | the commit carrying this file | `docs/100` (new), D200, session log |

**The package (`docs/100`, D200):**
- `deploy/docker-compose.production.yml` and `deploy/production/`: profiles `production` and `rehearsal`, strict
  separation, `--confirm <host>`, interruption marker.
- Secrets as read-only files (`NAME_FILE`): the API's `docker inspect` shows no secret.
- age backups to off-server keys.
- The customer-data gate: email and WhatsApp stay closed until a Storage Box restore is proven.
- Pinned MySQL 8.4.11 and Caddy 2.11.7; CX23 sizing.
- A plain-text SMTP delivery proof.

**Rehearsal (`docs/100` §13):**
- 97/97 migrations; smoke 13/13; identities 21/21; sign-up refused with nothing saved;
- backup → laptop → back → restore PASSED; a tampered copy refused;
- rollback and forward; restart recovery; isolation;
- plain-text SMTP proof delivered and owner-confirmed;
- WhatsApp disabled throughout.
- Five defects the rehearsal found were fixed, each with a test.
- **Torn down and verified:** only :22 public, root refused, Docker empty, structural secret checks 0. `/srv` holds only
  `erp-production/secrets/api/smtp_{username,password}` (the owner's, mode 600). Laptop rehearsal copies deleted.

**Production is NOT deployed.** The next phase starts only on the owner's explicit approval of the clean deployment.

**Then, in order (`docs/100` §6, §12):**
1. DNS `api` → A → the host, DNS only.
2. The production age identity: generated in memory, copied to the owner's password manager and `.tsxmr`, removed from
   the server.
3. Clone `644f4f5` (or later, CI-green) to `/srv/erp-production`; `stack.env`; `api.env` with email and WhatsApp
   disabled.
4. `deploy.sh --confirm api.tsxmr.com`.
5. The first platform administrator, through hidden prompts.

**Before any external test, trial or customer:**
- the Storage Box: bought, a sub-account, push and verify, **a restore from it**;
- the email-tracking decision (Brevo tracking cannot be turned off on the plan);
- only then `EMAIL_CHANNEL=smtp`.

**Owner reminder:** after the server setup and backend deployment, run `ssh-add -D` and stop the `ssh-agent` service
(administrator).

---

last_session: CLAUDE (local session, the owner's PC), started 2026-10-18T05:05Z (claim `a3afeeb`), complete.

## The Hetzner server tsxmr-app-01 hardened (2026-10-18, CLAUDE, local) — no ERP on it

| Repository | Branch | HEAD | This phase |
| --- | --- | --- | --- |
| `erp-backend` | `reports-export` | `d3c11a8` | untouched |
| `erp-mobile` | `reports-export` | `e6773aa` | untouched |
| `erp-control-web` | `tsx-public-site` | `e953c58` | untouched |
| `erp-docs` | `master` | the commit carrying this file | claim `a3afeeb`; `docs/99` §13; session log |

**Server** (address and host-key fingerprint only in the owner's private `.tsxmr/provisioning.txt`):
- CX23, nbg1, role **production-preparation**: Ubuntu 24.04.4, kernel 6.8.0-147;
- 2 vCPU, 3.7 GiB RAM, 38 GB disk (12 % used), 2 GB swap at swappiness 10.

**State:**
- SSH is key-only with root login off. Admin `tsxmr-admin` has `sudo` (no password) and `docker`
  (root-equivalent).
- Every update is installed and the server was rebooted once; unattended security upgrades are on.
- Persistent journal capped at 500 MB; NTP synced.
- Docker 29.9.1 and Compose v5.6.0 (Unix socket only, no container).
- Only :22 listens publicly. Full record: `docs/99` §13.

**Not done (by instruction):** no ERP checkout, `/srv` layout, env file, database, migration, DNS, SMTP or WhatsApp.

**Open for the owner:**
1. Decide whether this host receives the staging stack (`docs/99` as written) or production. Never both (`docs/99` §11).
2. The `docs/99` §10 inputs.
3. After the deployment session, clear the local SSH agent (`ssh-add -D`) and stop the `ssh-agent` service (an
   administrator step).

**Next phase:** backend deployment, once the role and the §10 inputs exist.

---

The previous records follow, unchanged.
last_session: CLAUDE (cloud), started 2026-10-18T02:06Z (claim `abd18d2`), complete.

## The repositioned website in production (2026-10-18, CLAUDE, cloud)

| Repository | Branch | HEAD | This phase |
| --- | --- | --- | --- |
| `erp-control-web` | `tsx-public-site` (production) | `e953c58` | fast-forwarded from `397ec6b` (`a3c2a4b`, `e953c58`) at 02:17Z |
| `erp-control-web` | `site-redesign` | `e953c58` | fast-forwarded, equal to production |
| `erp-control-web` | `site-positioning` | `e953c58` | `e953c58`: Blemhader attribution, per-document effective dates |
| `erp-control-web` | `ops/verify-production` | `86e5576` | merge of `e953c58` into the verifier |
| `erp-control-web` | `main` | `0417bfe` | untouched |
| `erp-backend` | `reports-export` | `d3c11a8` | untouched |
| `erp-mobile` | `reports-export` | `e6773aa` | untouched |
| `erp-docs` | `master` | the commit carrying this file | claim `abd18d2`; D199, `docs/74`, `docs/97`, session log |

All working trees are clean and level with their remotes. The website checkout is on `site-positioning`.

**Live on https://tsxmr.com:**
- the TSX-MR brand home page and Services page;
- Dukan ERP as the own product;
- Blemhader.com as client work (name and sentence only);
- the operator's name only in the legal texts;
- the navigation fixes;
- legal v1.1 (privacy, terms, legal notice), effective 2026-10-18.

**Verified from GitHub:**
- `verify-production` run 39089584510, attempt 2:
  - 60 pages; every built file is served as built, apart from Email Address Obfuscation;
  - TLS, redirects, headers, 404s, sitemap (39 URLs) and email DNS pass;
  - browser 148/148 live.
- `verify-not-found` passed.

**Rollback:** Pages deployment `8a828f1b` (= `397ec6b`). The new deployment's ID was not readable from this environment.

**Owner actions still open:**
1. Turn off Email Address Obfuscation (the two remaining verify-production failures).
2. Set preview deployments to None.
3. Optional, for Blemhader: supply a link and a one-line description of the business.
4. Optional: counsel on the publication director.
5. Decide the scope of the terms' "Information on this website".

**Next phase:** hosting and backend deployment.

---

The previous records follow, unchanged.

## Website repositioning and navigation fixes (2026-10-17, CLAUDE, cloud) — ready for the owner's visual approval

| Repository | Branch | HEAD | This phase |
| --- | --- | --- | --- |
| `erp-control-web` | `site-positioning` (non-production) | `a3c2a4b` | **new**: the repositioning and fixes, one commit on `397ec6b`; CI green (run 39080501681) |
| `erp-control-web` | `tsx-public-site` (production) | `397ec6b` | **untouched**; Pages `8a828f1b` still serves tsxmr.com |
| `erp-control-web` | `site-redesign` | `397ec6b` | untouched |
| `erp-control-web` | `ops/verify-production` | `bff3143` | untouched |
| `erp-control-web` | `main` | `0417bfe` | untouched |
| `erp-backend` | `reports-export` | `d3c11a8` | untouched |
| `erp-mobile` | `reports-export` | `e6773aa` | untouched |
| `erp-docs` | `master` | the commit carrying this file | claim `7eefc09`; D195–D198, `docs/74`, `docs/97`, session log |

All working trees are clean and level with their remotes. The website checkout is on `site-positioning`.

**What changed** (D195–D198; `docs/74` "Repositioning and navigation"):

- TSX-MR is presented as an independent development brand. The home page is the brand; there is a new Services page;
  Dukan ERP is the one own product, and its detail sits on its own page.
- The operator's name was removed from the footer, the marketing pages and the structured data. Each legal text names the
  operator once and then says "the operator"; the legal notice keeps the person responsible for publication. Privacy,
  terms and legal notice are now v1.1.
- Pages open at their top with focus on the heading. Sections, Back and Forward work.
- The language control has equal segments, and each page has one related-pages group.

**Verification (local, production build):**

- vitest 489/489;
- public Playwright 148/148;
- full-surface Playwright 130/130;
- links and bundle PASS; PUBLIC_WEBSITE GO.

**Not verified live:** the Cloudflare preview; the container cannot reach `*.pages.dev`.

**Risks:**

- The legal v1.1 texts carry the effective date set in Cloudflare (`VITE_LEGAL_EFFECTIVE_DATE`). It must be set to the
  promotion day at promotion.
- The `/services` page is new, so production verification must include it.

**Next exact action:**

1. The owner reviews the screenshots and, if preview builds are on, `https://site-positioning.tsxmr-public.pages.dev`.
   Otherwise they build locally:
   `VITE_SITE_SURFACE=public VITE_PUBLIC_SITE_ORIGIN=https://tsxmr.com VITE_ORGANIZATION_PHONE="+222 36 96 38 39, +222 37 67 68 27" npm run build:public-release && node scripts/serve-dist.mjs`
2. On approval:
   - fast-forward `tsx-public-site` to `a3c2a4b`;
   - set `VITE_LEGAL_EFFECTIVE_DATE` to that day;
   - verify tsxmr.com with `verify-production`, adding `/services` to its page list;
   - rollback target: `8a828f1b`.
3. Then the next phase: hosting and backend deployment.

**Owner actions still open** (D198):

- Blemhader attribution permission;
- counsel on the publication director (optional);
- the terms' "Information on this website" scope;
- Email Address Obfuscation off;
- preview deployments set to None.

---

The previous records follow, unchanged.

## The custom 404 page in production (2026-10-17, CLAUDE, cloud)

| Repository | Branch | HEAD | This phase |
| --- | --- | --- | --- |
| `erp-control-web` | `tsx-public-site` (production) | `397ec6b` | fast-forwarded from `de6e6ba` (`918b0b5`, `397ec6b`) |
| `erp-control-web` | `site-redesign` | `397ec6b` | unchanged (equal to production) |
| `erp-control-web` | `ops/verify-production` | `bff3143` | merge `de48f94`, `a452273` (verify-not-found → production), `bff3143` (verifier skips 404.html) |
| `erp-control-web` | `main` | `0417bfe` | untouched |
| `erp-backend` | `reports-export` | `d3c11a8` | untouched |
| `erp-mobile` | `reports-export` | `e6773aa` | untouched |
| `erp-docs` | `master` | the commit carrying this file | claim `aff4afd`; `docs/74`, `docs/95`, `docs/21` D194, session log |

All working trees are clean and level with their remotes. The website checkout is on `site-redesign`.

- **Cloudflare production deployment:** `8a828f1b-65d5-4ea4-8644-dfdaebad09d2`.
- **Rollback target:** `ccf9d282-a314-4868-88ec-a31f3c25a6f8` (the redesign without the page). It was not needed.
- **Verified on https://tsxmr.com from GitHub:**
  - `verify-not-found` 25/25: every unknown address, root, deep, FR, AR, `/account`, `/admin` and `/in-app/`, gives a
    404 in its language and frame; files load at depth; known pages give 200;
  - browser suite 127/127, with the 404 checks;
  - `verify-production` 20 passes. Its 2 failures are the known Email Address Obfuscation (owner action 1).
- Gates on the promoted head: vitest 483/483, public Playwright 127/127, links 2,982/0, bundle PASS, PUBLIC_WEBSITE GO;
  CI green.

---

The previous records follow, unchanged.

## The public site's custom "Page not found" (2026-10-17, CLAUDE, cloud): a preview awaiting the owner's approval

| Repository | Branch | HEAD | This phase |
| --- | --- | --- | --- |
| `erp-control-web` | `site-redesign` (preview only; **not promoted**) | `397ec6b` | the page, one commit on `918b0b5` |
| `erp-control-web` | `tsx-public-site` (production) | `de6e6ba` | **untouched**; Pages `ccf9d282` still serves tsxmr.com |
| `erp-control-web` | `ops/verify-production` | `a86b26e` | the `verify-not-found` workflow and script |
| `erp-control-web` | `main` | `0417bfe` | untouched |
| `erp-backend` | `reports-export` | `d3c11a8` | untouched |
| `erp-mobile` | `reports-export` | `e6773aa` | untouched |
| `erp-docs` | `master` | the commit carrying this file | claim `58d315d`; `docs/74`, `docs/21` D194, session log |

All working trees are clean and level with their remotes. The website checkout is on `site-redesign`.

**Implementation** (detail in `docs/74` "Page not found", D194).
- `src/pages/public/NotFound.tsx` (new):
  - the navy band with "Error 404", one heading, one sentence, "Back to home" and "Contact us";
  - a typographic 404 in inline SVG (purple ring, amber point, aria-hidden);
  - a row of the most-asked pages.
- Under `/in-app/` it keeps the app's frame: help and legal pages only.
- Six prerendered `404.html` files: `/`, `/fr/`, `/ar/`, plus `in-app/` in each. Each has its own lang/dir, title,
  noindex, no canonical, and is not in the sitemap.
- Cloudflare serves the nearest one with a **404** status. There is no rewrite and no redirect.
- The router shows the same page after a link inside the site, and the head is reset to noindex.
- On a 404, the language links lead to each language's home page. A stored language never redirects a 404.
- Theme preference is kept. Nothing from the address is shown back.
- Changed:
  - `src/app.tsx`, `src/components/Chrome.tsx`, `src/site/{routes,head}.ts`;
  - `src/i18n/{en,fr,ar}.ts`, `src/theme/public.css`, `src/pages/public/Legal.tsx` (old NotFound removed);
  - `scripts/{prerender,serve-dist}.mjs`;
  - `e2e/public-site.spec.ts`, `test/not-found.test.tsx` (new), `test/public-pages.test.tsx`.

**Verified.**
- Local, production-variable `build:public-release`:
  - vitest 483/483; public Playwright 127/127 (24 new); full-site suite 126/126;
  - links 2,982/0 broken; bundle PASS; PUBLIC_WEBSITE GO.
- HTTP status matrix on the local Cloudflare emulation:
  - every unknown root, deep, FR, AR, `/account`, `/admin` → 404 in its language;
  - `/in-app/*` → 404 in the app's frame;
  - known pages → 200.
- A 36-case browser probe found no overflow at 320 px, no failed file and no hydration error.
- **On Cloudflare itself:**
  - preview deployment `d5a0d716-5bf0-497c-acc2-4cdb52017435`, checked from GitHub (`verify-not-found` run
    39047362786): **25/25**, the same as locally;
  - evidence on `ci-evidence` `evidence/not-found/`.
- CI on `397ec6b` (run 39047253429): **green** (unit, builds, audits, full-site and public browser suites).
- Production re-check `verify-production` (run 39047362671, triggered by the ops push): 20 checks pass and the
  browser suite against tsxmr.com passes 103/103. The same two checks fail as before: Cloudflare Email Address
  Obfuscation is still on (owner action 3). Production is unchanged.

**Known, by the host's design.** `/404`, the error page's own address, answers 200 (the file exists). It is noindex and
linked from nowhere.

**Not done, by the brief:** no promotion to production; no change to Cloudflare settings, DNS, email, backend, mobile
or legal text.

---

The previous records follow, unchanged.

## Website promotion + staging API preparation (2026-10-17, CLAUDE, cloud)

| Repository | Branch | HEAD | This phase |
| --- | --- | --- | --- |
| `erp-control-web` | `tsx-public-site` (production) | `de6e6ba` | fast-forwarded from `6016b8a` (5 commits, normal push) |
| `erp-control-web` | `site-redesign` | `918b0b5` | `918b0b5`: test race fix only, not deployed |
| `erp-control-web` | `ops/verify-production` | `afc2dad` | the live verification workflow (`175e9df`, `2ef9b34`, merge `afc2dad`) |
| `erp-control-web` | `ci-evidence` | — | production evidence under `evidence/production/` |
| `erp-control-web` | `main` | `0417bfe` | untouched |
| `erp-backend` | `reports-export` | `d3c11a8` | `f8761c3`, `0c12bf2`, `33723da`, `d3c11a8`; CI green on all 5 jobs |
| `erp-mobile` | `reports-export` | `e6773aa` | untouched |
| `erp-docs` | `master` | the commit carrying this file | claim `65ef976`; `docs/99` new; `docs/95`, `39`, `79`, `21` (D190–D193) |

All working trees are clean and level with their remotes. The website checkout is back on `site-redesign`.

### 1. Website production

- **Deployment:** Cloudflare production `ccf9d282-a314-4868-88ec-a31f3c25a6f8` serves tsxmr.com from `de6e6ba`.
- **Rollback target:** `b4737b88-3cc8-473f-9957-7374ce768e8f` (the previous production, `6016b8a`). Not used: there
  was no material defect.
- **Verified live** from a GitHub runner (runs 39040829534 and 39041151582; evidence on `ci-evidence`):
  - TLS on apex and www;
  - http→https and www→apex 301 with path and query, no loop;
  - headers equal to the build, HSTS without preload;
  - canonicals; no tracker, RUM, preview host or plain-http resource; in-app pages noindex;
  - 404s for `/account`, `/admin` and the rest; robots, sitemap (36 URLs) and security.txt;
  - **email DNS unchanged** (MX, SPF, DKIM, DMARC, Brevo);
  - **browser suite 103/103 against production.**
- **Failed:** 2 checks, byte identity (45 pages) and "no edge rewriting". The cause is Cloudflare's zone-level
  **Email Address Obfuscation** rewriting `mailto:` links and injecting `email-decode.min.js`.
  - Every difference decodes back to the build: the files are the audited build.
  - It was not caused by the deployment, and a rollback would not change it.
  - Owner action 1.
- **Preview deployments are still ON**: no Cloudflare access from here (owner action 1). `docs/95` records the
  discrepancy.
- **CI:** `tsx-public-site` `de6e6ba` run 39040460157 failed 1/103 on a test race. It was fixed in `918b0b5` on
  `site-redesign` (CI green) and the failed job on `de6e6ba` was re-run once; the result is in the GitHub run.
  `918b0b5` changes no shipped file and goes to production with the next approved promotion.
- Legal text, identity, contact values and product claims were **not** changed.

### 2. Backend audit

The facts are in `docs/99` §1: Node 22, NestJS 10.4, Prisma 5.22, **97 migrations up to `0098_messaging_records`**,
MySQL strict mode with `log_bin_trust_function_creators`, four guarded workers with no switch, the raw-body HMAC
webhook, receipts in `UPLOAD_DIR`, PDFs rendered on the phone, `API_INGRESS`, the exact CORS allowlist, the production
guard, and the email and WhatsApp switches.

Found and fixed, with tests:
- readiness ignored migrations that were never applied;
- the outbox log carried full contacts;
- the staging code lookup could not read keyed codes;
- CI's secret scan was red on a fixture.

### 3. Staging deployment preparation (`33723da`, `d3c11a8`)

- **Image:** the `Dockerfile` has runtime and tools targets. `.dockerignore` keeps secrets out.
- **Stack:** `deploy/docker-compose.staging.yml`:
  - MySQL 8.4 strict/UTC on an internal network, with no published port;
  - the API, non-root, restarted on failure;
  - Caddy, the only service publishing 80/443;
  - one-off `migrate` (migrator identity) and `tools` (app identity) services;
  - log rotation on every service.
- **Scripts:** `deploy/staging/` holds the setup, preflight, migrate, deploy, rollback, backup, restore drill and
  smoke commands.
- **Templates:** `.env.staging.example` is complete and holds no secret; the preflight refuses it as it stands (CI
  proves this). `.env.example` is extended. `stack.env.example` holds the stack settings.
- **Runbook:** `docs/99`:
  - architecture and DNS (`staging-api` A/AAAA, **DNS only** — not added);
  - configuration and the first-deployment checklist;
  - backup, restore and rollback;
  - the verification plan, automated vs device/provider;
  - owner inputs and the **host requirements sheet** (§11).
- **Rehearsed end to end** on a local Docker host (`docs/99` §12):
  - setup; 97 migrations; catalogue 73/73; identities 21/21 on data;
  - smoke 12/12;
  - sign-up with the keyed code retrieval;
  - backup and restore drill, empty and with data;
  - daemon restart; rollback; `deploy.sh` on the committed tree;
  - torn down afterwards.
- The real Dockerfile cannot be built in this container (Debian mirrors are blocked). It is built and checked by CI,
  in the job "staging image and stack files" (green).

### 4. Not done, by the brief

- No host was chosen or bought, no DNS record was added, and the API is deployed nowhere.
- No real database was migrated: not the owner's PC database, and no live one.
- SMTP and WhatsApp were not enabled. The mobile app was not built or submitted.
- `main` was not moved.

### 5. Blockers and inputs (owner) — `docs/99` §10

- The host, the DNS record, `ACME_EMAIL` and the staging `PUBLIC_SITE_ORIGIN`.
- Custody of the MFA key and the backup passphrase, and an off-host backup location.
- The first platform administrator.
- **Brevo:** rotate the SMTP key exposed on 2026-10-17 and never reuse it. Supply the new key through the host's
  secret store; email stays `disabled` until then.
- **WhatsApp:** the Meta proofs and test numbers; `disabled` until then.

### 6. Risks

- Host sizing (`docs/99` §11) is an estimate, not a measurement under load.
- A Cloudflare-proxied staging record would break the one-hop trust: keep it DNS only.
- Rolling the code back below `0092` or `0097` is unsafe (`docs/79` §C1).
- The staging trial's setup links have no portal to land on until one exists.

---

The previous records follow, unchanged.

## The public-site consistency pass (2026-10-17, CLAUDE, cloud): a preview awaiting the owner's review

| Repository | Branch | HEAD |
| --- | --- | --- |
| `erp-control-web` | `site-redesign` (preview only; **not merged**) | `de6e6ba` (from `0b7fb52`). CI run 39039040447 green; evidence `bb8f668` |
| `erp-control-web` | `tsx-public-site` (production) | `6016b8a`, **untouched** (Pages `b4737b88` still serves tsxmr.com) |
| `erp-backend` | `reports-export` | `d0a7495` (untouched) |
| `erp-mobile` | `reports-export` | `e6773aa` (untouched) |
| `erp-docs` | `master` | the commit carrying this file (claim `bc79796`) |

**Changed (website `de6e6ba`, one commit).** Detail is in `docs/74` "Consistency pass" and D189.
- Files: `src/components/Chrome.tsx`, `src/components/public/{blocks,icons}.tsx`, `src/pages/public/Legal.tsx`,
  `src/i18n/{languages.ts,index.tsx,en.ts,fr.ts,ar.ts}`, `src/theme/{public,tokens}.css`, `e2e/{public-site,site}.spec.ts`,
  and the new `test/site-navigation.test.tsx`.
- **Links:** one system by context — running text, contents rows, related-page pills, operator telephone rows, a text
  action, footer columns.
- **Phone menu:** a hamburger/close icon button. It is still a native disclosure before the script runs.
- **Languages:** EN/FR/AR with the full names as accessible names.
- No dependency, CSP, route, SEO or content change.

**Verified.**
- vitest 468/468. Full preview: Playwright 126/126. Public preview: 103/103, also with both numbers.
- Production-variable `build:public-release`: PASS, 2 831 links, 0 broken, 0 test values; Playwright 103/103 on it;
  PUBLIC_WEBSITE GO.
- gitleaks clean; headers, robots, sitemap and canonical unchanged; `/account` and `/admin` 404.
- CI green on `de6e6ba`.

**Deployment.**
- Cloudflare preview deployment `33188307-02ee-4ba0-a006-55624372c3be`.
- URLs: https://33188307.tsxmr-public.pages.dev and https://site-redesign.tsxmr-public.pages.dev. The source is
  Cloudflare's GitHub check run on `de6e6ba`.
- This container cannot reach `*.pages.dev` or tsxmr.com, so the deployed preview was not opened here.

**Known discrepancy, still open.** `docs/95` and D187 still say "preview deployments: None" while `site-redesign`
previews are on. This is to be recorded once the owner decides whether previews stay on.

**Next exact action (the owner).**
1. Review https://site-redesign.tsxmr-public.pages.dev: the legal pages' contents and links, the phone menu at 320–375
   px, EN/FR/AR, light and dark.
2. Approve or reject promotion.
   - On approval, the next session fast-forwards `tsx-public-site` to `site-redesign`, normal push, no force. Before
     that, run the full gates on that head and confirm CI.
   - Then verify tsxmr.com.
   Do **not** promote without that approval.

---

The previous records follow, unchanged.

## The public-site redesign refinement (2026-10-17, CLAUDE, cloud): a preview awaiting the owner's decision

| Repository | Branch | HEAD |
| --- | --- | --- |
| `erp-control-web` | `site-redesign` (preview only; **not merged**) | `0b7fb52` (from `f719617`). CI run 39033394872 green; evidence `fe7d674` |
| `erp-control-web` | `tsx-public-site` (production) | `6016b8a`, **untouched** (Pages `b4737b88` still serves tsxmr.com) |
| `erp-backend` | `reports-export` | `d0a7495` (untouched) |
| `erp-mobile` | `reports-export` | `e6773aa` (untouched) |
| `erp-docs` | `master` | the commit carrying this file (claim `0563c8c`) |

**Changed (website `0b7fb52`, one commit).** Detail is in `docs/74` "Refinement" and D188.
- Files: `src/theme/{tokens,global,public}.css`, `src/theme/theme.tsx`, `public/theme-boot.js`,
  `src/components/Chrome.tsx`, `src/components/public/{blocks,icons}.tsx`,
  `src/pages/public/{Home,DukanErp,Legal}.tsx`, `src/i18n/{en,fr,ar}.ts`, `e2e/public-site.spec.ts`, and the new
  `test/site-refinement.test.tsx`.
- Contact methods are cards that are the real `mailto:`/`tel:` links. Addresses and numbers are unchanged; no
  telephone purpose or WhatsApp label was added.
- One `.elevated` card elevation and motion system covers every principal card family, the Launch cards included.
  Reduced motion keeps the shadow and drops the movement.
- A header sun/moon toggle replaces the footer select. It follows the device until the visitor chooses, and only an
  explicit choice is stored (D188).
- No migration, no database, no dependency, no CSP change.

**Verified.** Detail is in the session log.
- vitest 452/452. Full preview: Playwright 126/126, links 3 400/0. Public preview: Playwright 91/91, links 2 753/0.
- Production-variable `build:public-release` PASS: 2 831 links, 0 broken, 0 test values. Playwright 91/91 on it;
  PUBLIC_WEBSITE GO.
- gitleaks clean. Headers, robots, sitemap and canonical unchanged; `/account` and `/admin` 404; no third-party request.
- CI green on `0b7fb52`.

**Deployment.**
- Cloudflare built the preview from the push: deployment `533f4ef1-0432-4cdc-9d6d-228a6e40ea88`.
- URLs: https://533f4ef1.tsxmr-public.pages.dev and https://site-redesign.tsxmr-public.pages.dev. The source is
  Cloudflare's GitHub check run on `0b7fb52`. This container cannot reach `*.pages.dev`, so the deployed pages were
  not opened from here.
- Production, the Cloudflare settings, DNS, email routing and RUM (still off) were not touched.

**Known discrepancy, open.** `docs/95` and D187 record "preview deployments: None". Cloudflare now builds previews for
`site-redesign` (the owner's setting; the brief says only that branch). This is to be recorded in `docs/95` once the
owner decides whether previews stay on.

**Next exact action (the owner).**
1. Review https://site-redesign.tsxmr-public.pages.dev in EN/FR/AR, light and dark.
2. Approve or reject promotion.
   - On approval, the next session fast-forwards `tsx-public-site` to `site-redesign`, normal push, no force. Before
     that, run the full gates on the merged head and confirm CI.
   - Then verify the production deployment on tsxmr.com.
3. Then decide whether preview deployments are switched off again.
   Do **not** promote without that explicit approval.

---

The previous records follow, unchanged.

**The public website is LIVE at https://tsxmr.com (2026-10-17).** Every repository is clean and level with its remote.

Website deployment phase: previous_owner CLAUDE (cloud session), 2026-10-17T06:00Z → 2026-10-17T07:15Z, complete.
Backend phase (Brevo SMTP + WhatsApp): previous_owner CLAUDE (local session), complete earlier the same day; untouched here.

## The tsxmr.com production deployment (2026-10-17, CLAUDE, cloud) — the website is LIVE

| Repository | Branch | HEAD |
| --- | --- | --- |
| `erp-control-web` | `tsx-public-site` (the Cloudflare Pages production branch; `main` `0417bfe`, not moved) | `6016b8a` (this phase: `8cb3ff2` approval, `6016b8a` tests) |
| `erp-backend` | `reports-export` | `d0a7495` (untouched) |
| `erp-mobile` | `reports-export` | `e6773aa` (untouched) |
| `erp-docs` | `master` | the commit carrying this file |

**What happened.**

- The owner explicitly approved the six pre-launch texts of `docs/97` v0.3 as they are (in chat, 2026-10-17), confirmed the §3 commitments, and confirmed contact@, support@, privacy@ and security@tsxmr.com are live and read.
- `8cb3ff2`: each document `status: 'approved'`, `version: '1.0'` (EN/FR/AR), exactly as `docs/97` §1 instructs. `6016b8a`: the three prelaunch-gate test expectations follow. Committed through the GitHub web UI (the cloud session has no push credential); both files byte-identical (SHA-256) to the locally verified tree. CI on `6016b8a` green (evidence `11929c9` on `ci-evidence`).
- Cloudflare Pages project **`tsxmr-public`** created (none existed): repository `AbdelkerimMahfoudh/erp-control-web`, production branch `tsx-public-site`, build `npm ci && npm run build:public-release`, output `dist`, `SKIP_DEPENDENCY_INSTALL=1`, `NODE_VERSION=22`, preview deployments **None**. Production variables per `docs/96` §6: `VITE_SITE_SURFACE=public`, `VITE_PUBLIC_SITE_ORIGIN=https://tsxmr.com`, `VITE_ORGANIZATION_PHONE` (the two public numbers), `VITE_LEGAL_EFFECTIVE_DATE=2026-10-17` (the deployment day). No secret of any kind is in the frontend environment.
- First production deployment `b4737b88-3cc8-473f-9957-7374ce768e8f` built and passed; smoke-tested on `tsxmr-public.pages.dev`; then `tsxmr.com` and `www.tsxmr.com` attached (both Active, TLS issued), the zone redirect rule "www to apex (tsxmr.com)" deployed exactly as `docs/95` §4 (http.host eq "www.tsxmr.com" → concat("https://tsxmr.com", path), 301, preserve query string), and Always Use HTTPS turned on. HSTS stays from `_headers` only; no preload, no zone HSTS.
- DNS: only the two proxied CNAMEs (`tsxmr.com` and `www` → `tsxmr-public.pages.dev`) were added, by Pages itself. The email records are untouched: the 3 Cloudflare Email Routing MX, the CF DKIM TXT, DMARC, the 2 Brevo DKIM CNAMEs, the brevo-code TXT, and exactly one SPF at the root. Email Routing stays enabled with its 15 address rules; the catch-all stays disabled.
- **Cloudflare's free-zone RUM beacon was found auto-injected** into navigation responses (static.cloudflareinsights.com) — contradicting the published privacy text. RUM was **disabled completely** for the zone (Speed → Real user monitoring) and the beacon verified gone. No analytics run on the site.

**Verified in production (https://tsxmr.com).** Every public, legal and `/in-app/` page answers 200 in EN, FR and AR; `/account`, `/admin`, `/apply`, `/login`, `/application-status`, `/app-shell.html` and unknown paths answer 404. http→https; www (http and https) → apex 301 with path and query preserved; no loop. Headers: the repository CSP (connect-src 'self'), HSTS max-age≈1y without preload, X-Frame-Options DENY, nosniff, Referrer-Policy, Permissions-Policy. robots.txt, sitemap.xml (36 URLs, all https://tsxmr.com, no in-app or portal page), security.txt, canonical and hreflang correct; OG image, icons, manifest and JSON-LD present; Arabic is genuinely RTL; the language choice survives navigation; keyboard focus is visible; no console error; no request to any other origin after the RUM fix. The deployed JS and CSS are **byte-identical (SHA-256)** to the locally audited production build, so its audits apply to what is deployed: vitest 440/440, `npm ci && npm run build:public-release` PASS (57 pages, 2 709 links, 0 broken, bundle audit `--public` PASS, 0 test values), Playwright public 82/82 against that dist, `release-verdicts --require public` **PUBLIC_WEBSITE GO**. PORTAL NO-GO (25) and APP_STORE NO-GO (21) are unchanged and stay closed.

**Stable URLs for Apple and Meta:** https://tsxmr.com/privacy · https://tsxmr.com/terms · https://tsxmr.com/account-deletion · https://tsxmr.com/privacy-choices · https://tsxmr.com/legal · https://tsxmr.com/security · https://tsxmr.com/support (each with /fr and /ar variants, and /in-app/… variants for the app).

**Rollback.** Cloudflare Pages → tsxmr-public → Deployments → promote a previous deployment (instant); or detach the custom domains (this is the first deployment, `b4737b88` is the known-good). A text correction is a new commit on `tsx-public-site` and an automatic redeploy; the effective date and version change with it. No database or backend is involved.

**Not done, by the brief.** No backend, portal, app, SMTP, WhatsApp, migration, analytics (RUM was switched OFF, not on), purchase, nameserver or email-routing change. `main` was not fast-forwarded: the cloud session cannot push, so the Pages production branch is `tsx-public-site`, the documented alternative (`docs/95` §3); only that branch deploys. **The Brevo SMTP key once shared in chat still needs rotation before any SMTP production use.**

**Next exact action.** (a) Optional: fast-forward `main` to `tsx-public-site` from the owner's PC and, if preferred, switch the Pages production branch to `main`. (b) Hand Meta / App Store Connect the stable URLs above — they answer 200 without authentication. (c) Rotate the Brevo SMTP key. (d) The open owner-or-counsel items stand: `docs/97` §4, `operator_registration`, D180, and the sale-workflow iPhone check.

---

The previous records follow, unchanged.

## Website production preparation (2026-10-17) — read `docs/96` §3, §8–§11, then `docs/97`

| Repository | Branch | HEAD |
| --- | --- | --- |
| `erp-backend` | `reports-export` | `1ed6b00` (read only here; the local phase works there) |
| `erp-mobile` | `reports-export` | `e6773aa` (unchanged) |
| `erp-control-web` | `tsx-public-site` (**not merged**; `main` `0417bfe`) | `b5c0328` (`b7b8fc2`, `ad41e4c`, `b5c0328` this phase) |
| `erp-docs` | `master` | the commit carrying this file |

**Deployed / merged / Cloudflare / SMTP / WhatsApp:** nothing. **Database:** none touched; no migration.

**What changed:**
- **D184, the address.** The correspondence address is Tevragh Zeina, Nouakchott-Ouest (configurable in EN and AR). It
  appears on the legal notice, contact and about pages, in the footer, in the texts and in the structured data.
- **D185, the portal.** Individual mode needs no legal form or RCCM. The new `operator_registration` blocker keeps the
  portal and paid access closed until counsel answers. Company mode is unchanged.
- **The six texts, v0.3 and still DRAFT** (`docs/97`): the change summary, the 5 commitments for TSX-MR to confirm and
  11 open legal questions.
- **A pre-existing release defect, fixed (`b7b8fc2`).** An approved production build would have failed its own audit:
  API code and preview values were in the public bundle. The audit is now strict in previews too.

**Verified:**
- Vitest 440; Playwright full 126 / 126 and public 82 / 82.
- Links 0 broken; bundle audits PASS; gitleaks clean.
- A production dry run with approval simulated in scratch: PASS.
- CI 39006226561 on `ad41e4c` green; on `b5c0328` (run 39006514696) green.

**Verdicts:**
- PUBLIC_WEBSITE **NO-GO, 7**: the effective date and the 6 approvals. Nothing else.
- PORTAL NO-GO, 26. APP_STORE NO-GO, 21.

**The only blockers for PUBLIC_WEBSITE, both the owner's:**
1. explicit approval of the six texts in `docs/97`, as they are or with changes, including §3's commitments;
2. the publication date, set as `VITE_LEGAL_EFFECTIVE_DATE` in Cloudflare on that day.

**Next exact action:**
1. The owner approves the texts, or sends edits.
2. A session then sets `status: 'approved'` and `version: '1.0'` in `erp-control-web/src/content/legal-prelaunch.ts`
   (EN/FR/AR), commits that alone, and re-runs `docs/96` §10.
3. Only on the owner's explicit go-ahead: fast-forward `main`, then create the Pages project with the `docs/96` §6
   variables, the date of that day, the domain and the www rule. The steps are `docs/96` §11, including rollback.
4. Before any production backend: **rotate the Brevo SMTP credential once shared in chat.**

**Open owner or counsel questions:**
- `docs/97` §4;
- `operator_registration`;
- D180;
- the earlier records below.

The sale-workflow device check (below) is still owed on the iPhone.

---

The previous website record follows, unchanged.

## The public website: an individual operator (2026-10-17) — read `docs/96` §3, §6, §7, then `docs/97`

| Repository | Branch | HEAD |
| --- | --- | --- |
| `erp-backend` | `reports-export` | `1ed6b00` (not touched by this phase; the local phase works there) |
| `erp-mobile` | `reports-export` | `e6773aa` (unchanged) |
| `erp-control-web` | `tsx-public-site` (**not merged**; `main` `0417bfe`) | `0516a9c` |
| `erp-docs` | `master` | the commit carrying this file |

**Deployed / merged / Cloudflare / SMTP / WhatsApp:** nothing. **Database:** none touched; no migration.

**What changed (D182–D183).**

- TSX-MR is an unincorporated trading name operated by Abdel Kerim Taleb Ould Sidi, an individual, who is also the
  person responsible for publication. The site says so in EN/FR/AR.
- The PUBLIC_WEBSITE gate no longer needs a legal form or RCCM for an individual (`VITE_OPERATOR_TYPE`, default
  `individual`), and refuses them if they are given. PORTAL is unchanged: it still needs a company (an open owner
  decision).
- Contacts: `contact@`, `support@`, `privacy@`, `security@tsxmr.com`. The two temporary public numbers come only from
  `VITE_ORGANIZATION_PHONE` and are not labelled WhatsApp.
- Still in place: coming soon, no registration, sign-in, price or trial; no portal or API code in the bundle;
  `VITE_PORTAL_ORIGIN` unset.

**Verified.**

- Typecheck; Vitest 423 / 423; Playwright public 82 / 82 (EN/FR/AR, 375 px and desktop, 320 px, axe AA, RTL,
  headers, 404s).
- Links 2 703, 0 broken; bundle audit `--public` PASS; gitleaks clean.
- CI run 39003461533 on `0516a9c`: **green**, every step (typecheck, tests, both builds and refusals, links, bundle audits, gitleaks, Playwright full and public, verdicts); evidence on `ci-evidence`.
- `npm ci && npm run build:public-release` was **refused, as designed, for exactly 8 reasons**. PUBLIC_WEBSITE
  NO-GO 8; PORTAL NO-GO 29; APP_STORE NO-GO.

**The only three blockers for PUBLIC_WEBSITE:**

1. the correspondence address (`VITE_ORGANIZATION_ADDRESS`);
2. the effective date, which is the deployment date (`VITE_LEGAL_EFFECTIVE_DATE`);
3. TSX-MR's approval of the six texts in `docs/97`.

**Next exact action.**

1. The owner gives the correspondence address, and approves or edits the six texts of `docs/97`.
2. A session then, in `erp-control-web/src/content/legal-prelaunch.ts`, changes each approved document's `status` to
   `'approved'` and its `version` to `'1.0'` (EN/FR/AR), and re-runs the verification of `docs/96` §7.
3. Only on the owner's explicit go-ahead:
   - fast-forward `main` to `tsx-public-site`;
   - create the Pages project per `docs/95` §3–§4, with build `npm ci && npm run build:public-release` and the
     variables of `docs/96` §6 (address, and the deployment date as `VITE_LEGAL_EFFECTIVE_DATE`);
   - add the domain and the www rule.

The sale-workflow device check (below) is still owed on the iPhone.


## Brevo SMTP + WhatsApp Cloud API (2026-10-17, CLAUDE local) — read `docs/98`, then `docs/21` D181

| Repository | Branch | HEAD |
| --- | --- | --- |
| `erp-backend` | `reports-export` | `d0a7495` (from `1ed6b00`: `2d575ed`, `d7869a0`, `60832f2`, `d0a7495`) |
| `erp-mobile` | `reports-export` | `e6773aa` (untouched) |
| `erp-control-web` | `tsx-public-site` | `b5c0328` (the cloud phase; untouched here) |
| `erp-docs` | `master` | the commit carrying this file |

**Migration 0098** (additive; five tables, one column, one index): verified on disposable databases only, dropped.
**Not applied** to the PC database (still 0091) or any live database. **Deployed:** nothing. **Live switches:** none.
**Messages sent:** none. **Templates submitted:** none.

**What changed.** Brevo SMTP channel (587, STARTTLS required, TLS 1.2), sender classes, Reply-To, text+HTML, email
records with an internal daily safety limit and a reserve for codes; WhatsApp test/live controls with an exact
allowlist and an explicit live-send switch, a send policy (opt-out, withdrawal, consent, pacing, records), Graph
v26.0, provider codes 131026/131047/190, a start-up token check for live mode; an asynchronous signed webhook with a
leased, forward-only worker that keeps D166's proofs (now per sending number); the proof script in test mode only;
versioned WhatsApp consent at registration and number verification; account consent and opt-out routes.

**Verified.** tsc; full suite 4 660 pass (1 pre-existing Windows-only failure, also on `1ed6b00`); 0098 on MySQL 8.4
from empty with no drift on the new tables, an 11-check smoke, rollback and re-apply; an API boot over HTTP (webhook
verify/sign/dedupe, STOP, consent copy). Not run: ESLint (absent from the backend), gitleaks (absent here).

**Awaiting the owner** (`docs/98` §8): rotate the Brevo SMTP key shared in chat; Brevo domain authentication and
tracking off; Meta app publication (privacy policy URL), real number, permanent token, templates, webhook; the API
host; approval of the consent copy.

**Next exact action.** Either (a) the client phase: the app and the website show `GET /api/v1/messaging/whatsapp/consent`
and send `whatsappConsentVersion` with registration and number verification, plus the opt-out screen; or (b) after the
owner's actions, a test-mode deployment per `docs/98` §2–§5 (back up, migrate, set the secrets, `whatsapp:prove`).
The sale-workflow iPhone check (below) is still owed.

---

## The sale workflow (2026-10-17) — read `docs/21` D178–D180 and the session log entry

| Repository | Branch | HEAD |
| --- | --- | --- |
| `erp-backend` | `reports-export` | `1ed6b00` |
| `erp-mobile` | `reports-export` | `e6773aa` |
| `erp-control-web` | `tsx-public-site` (not merged; `main` `0417bfe`) | `0288d8a` (untouched) |
| `erp-docs` | `master` | the commit carrying this file |

**Migration:** none required (`sales.due_date` already existed). **Deployed:** nothing.

**What changed.** Review sale: Return policy card, Discount card (Optional), one Continue to payment. Payment sheet:
Confirm payment, Split across methods as its own control. Less than the total → "The customer still owes … Record this
sale with an outstanding balance?" → customer debt card (name, phone, days until due). Server: `dueInDays` → due date
from the sale's business day; a customer who owes needs a phone (supersedes 0074's optional phone); the debt is the
sale's receivable; the Owner is reminded by the existing overdue-debt notice from the day after.

**Verified.** Backend tsc + 4 522 tests; mobile tsc, lint, 115 pure files, 302 jest tests; real HTTP 50/50 on a
disposable MySQL (dropped); browser screenshots EN/FR/AR, RTL, light/dark, 320 pt, 1.3× text.
**Not verified:** a physical iPhone (`docs/81` T4.7–T4.11).

**Awaiting the owner.** D180 — should the server enforce `discount.apply`? Plus everything the previous record lists.

**Next exact action.** On the owner's iPhone: pull backend `1ed6b00` and mobile `e6773aa`, restart the API and Metro,
and run `docs/81` T4.7–T4.11 (keyboard over the debt card included). Then the release-gate work below continues.

---

The previous phase's record follows, unchanged.

## Release gates and the pre-launch website (2026-10-17) — read `docs/96`, then `docs/95`

| Repository | Branch | HEAD |
| --- | --- | --- |
| `erp-backend` | `reports-export` | `dc53129` (unchanged) |
| `erp-mobile` | `reports-export` | `6609574` (unchanged; its release check untouched) |
| `erp-control-web` | `tsx-public-site` (**not merged**; `main` `0417bfe`) | `0288d8a` |
| `erp-docs` | `master` | the commit carrying this file |

**The gates.**

- **PUBLIC_WEBSITE** (public build, pre-launch): needs the TSX-MR facts, the six pre-launch texts approved by TSX-MR,
  and the origin `https://tsxmr.com` exactly; refuses any portal, API, console or app-store address.
- **PORTAL:** unchanged and strict.
- **APP_STORE:** strict, including WhatsApp deletion end to end.

**Verdicts in CI run 38995650063:** PUBLIC_WEBSITE NO-GO (16: 10 facts, 6 approvals), PORTAL NO-GO (35), APP_STORE
NO-GO (22).

**CI, all green:**

- Vitest 414 / 414.
- Playwright: full site 126 / 126, public site 79 / 79.
- Links: 2 619, 0 broken; bundle audits PASS; gitleaks clean.

**Next exact action.** The owner gives the facts of `docs/96` §3 and approves, or edits, the six pre-launch texts in
`erp-control-web/src/content/legal-prelaunch.ts`. Then:

1. a preview with the real values is screenshotted;
2. on the owner's explicit approval: fast-forward `main`, create the Pages project (build `npm ci && npm run
   build:public-release`, `VITE_SITE_SURFACE=public`), then the custom domain and the www rule (`docs/95` §3–§4).

The API (3010) and Metro (8082) on the PC were left running for the owner's phone; the PC database is still at 0091.

---

Earlier records follow, unchanged.

## The tsxmr.com publication (2026-10-17) — read `docs/95` first

| Repository | Branch | HEAD |
| --- | --- | --- |
| `erp-backend` | `reports-export` | `dc53129` (unchanged) |
| `erp-mobile` | `reports-export` | `6609574` (unchanged) |
| `erp-control-web` | `tsx-public-site` (**not merged**; 80 ahead of `main` `0417bfe`, 0 behind) | `fe38bbc` |
| `erp-docs` | `master` | the commit carrying this file |

**Website `3c08c3f`, `fe38bbc`: `VITE_SITE_SURFACE=public`.**

- The public pages only: no API page, no `/account` or `/admin`, and none of their code in the bundle.
- No API base is needed.
- "Sign in" and "Apply" go to `VITE_PORTAL_ORIGIN` once given.

**CI run 38991137218, all green:**

- Vitest 401 / 401; Playwright 126 / 126.
- Links: full 3 258, public 2 733, 0 broken; bundle audits PASS; gitleaks clean.
- The production refusal stands: 32 reasons for the public build.

**Next exact action.** The owner supplies the facts of `docs/95` §5.1. Then:

1. counsel settles `docs/93` §2;
2. TSX-MR approves the six drafts;
3. a deletion channel is configured and tested;
4. a preview with the real values is screenshotted for the owner;
5. on the owner's explicit approval: fast-forward `main`, create the Pages project, then the domain and the www rule
   (`docs/95` §3–§4).

The API (3010) and Metro (8082) started on the PC for the owner's phone were left running; the PC database is still at 0091.

---

The previous phase's record (legal pages, 2026-10-16) follows, unchanged.

## HEAD of every repository

| Repository | Branch | HEAD | Baseline of the phase | Notes |
| --- | --- | --- | --- | --- |
| `erp-backend` | `reports-export` | `dc53129` | `06a0db7` | `6ed5fc8`, `dc53129`; no schema change, no migration |
| `erp-mobile` | `reports-export` | `6609574` | `b23badb` | `b6adc48`, `6609574` |
| `erp-control-web` | `tsx-public-site` (**not merged**) | `8bf6f65` | `0eedfaa` | `main` is `0417bfe`, untouched |
| `erp-docs` | `master` | the commit carrying this file | `6e2a462` (+ `4204ea4`, the takeover) | |

CI is green on every new head: backend `dc53129` security, mobile `b6adc48` and `6609574` security (with the legal origin in the release check, exports and bundle audit), website `8bf6f65` ci (incl. Playwright). Open draft PRs (none touched): backend
#1, #2; mobile #1, #2 (the two `audit-fixes` are superseded — O-C7). The clean detached worktree
`/home/user/erp-backend-seed` (`d88893a`) is an earlier phase's and was left as it was.

## What the phase delivered

Read first **`docs/85`** (the implementation report: commits, pages, links, tests, findings fixed and open, the scope
of the line-by-line check). Then `docs/94` (the release gate: separate GO/NO-GO), `docs/93` (**the one list TSX-MR
fills in** — facts, legal blockers, decisions), `docs/86`–`docs/88` (data, processors, retention and deletion, from the
code), `docs/89` (App Privacy worksheet), `docs/90` (permissions, SDKs, network), `docs/91` (App Store Connect
metadata, not entered), `docs/92` (App Review notes draft), `docs/21` (O-A5 settled for the legal pages; the fixes).

- Website: `/privacy`, `/terms`, `/support`, `/account-deletion`, `/privacy-choices`, `/legal`, `/security` in EN/FR/AR,
  each **DRAFT — REQUIRES TSX-MR APPROVAL**; `/in-app/…` variants for the app; a production build refuses blank
  inputs, placeholders, legal blockers and drafts (33 reasons today).
- App: the four legal pages open in the phone's browser from sign-in, Your account, Delete account, the closed screen
  and the no-branch screen; every other address stays refused. `EXPO_PUBLIC_LEGAL_ORIGIN` is now **required** by the
  release check, like `EXPO_PUBLIC_API_ORIGIN`.
- **GO / NO-GO:** internal TestFlight NO-GO today, code ready (O-A0, O-A4, O-A6, and the legal origin as an EAS
  variable); external TestFlight NO-GO; App Store NO-GO. Never described as "Apple compliant".

## Verification at the final heads

| Repository | Result |
| --- | --- |
| backend `dc53129` | `tsc` 0 · Jest 249 suites passed, 1 skipped · 4 512 tests passed, 24 skipped, 0 failed |
| mobile `6609574` | `tsc` 0 · lint 0 errors, 29 warnings · 115 pure test files · Jest 30 suites / 285 tests · fresh web + iOS exports pass the bundle audit · Expo Doctor 19/21 (2 need the network) |
| website `8bf6f65` | typecheck · Vitest 19 files / 376 tests · `build:preview` 66 pages · link audit 0 broken / 3 255 · bundle audit PASS · production build refused (33) |

**NOT DEVICE VERIFIED:** everything in docs/81 T6.2–T6.5 (Safari opening the pages, FR/AR prompts, no microphone or
Face ID prompt). No EAS build or archive was made. No legal review. No provider exercised.

## Databases

None touched. No live or production database exists. `0092`–`0097` remain applied to no shared database; `0097`
needs the owner's approval first (D176, O-B12). No disposable database was created in this phase.

## Known risks and blockers

- **F01 / O-A7: account deletion cannot complete in production** (WhatsApp only, off; email never carries a deletion
  code). Blocks external review and the App Store.
- F02 (no erasure path for people who cannot sign in), L-1 (the in-app terms describe access paid outside the app),
  L-2 (receipt EXIF), L-3 (the phone keeps the deleted person's local files) and the rest of `docs/93` §3.
- All earlier risks of `docs/77` §6 and `docs/83` stand.
- The website header still offers "Sign in" while signed in (R4); the backend has no linter (PR-F09).

## Next exact action

1. Go through `docs/93` with the owner: the TSX-MR facts of §1 go into the website's build environment and the EAS
   variables (never into this repository); the legal blockers of §2 go to counsel; record each §3 decision in
   `docs/21`. Nothing is to be published, built for the store or submitted before the owner says so.
2. Then, if approved, the first engineering items in this order: O-A7 (an email deletion code, or WhatsApp proven),
   L-2 (strip EXIF on upload), L-3 (clear the deleted person's local data, with a warning when work is unsent) — each
   reproduced first and tested.
3. On a physical iPhone, run `docs/81` §3 including T6.2–T6.5 and record each row there.

## Checkpoint 2026-10-17 — redesign implementation, paused mid-way (CLAUDE, local session; usage limit)

Status stays IN_PROGRESS, owner CLAUDE. Nothing committed yet: all work is uncommitted on erp-control-web branch site-redesign
(from tsx-public-site 6016b8a). Production untouched: tsx-public-site 6016b8a, Pages deployment b4737b88 (rollback point).

Done on disk (erp-control-web):
- Fonts: public/fonts (Bricolage Grotesque variable, IBM Plex Sans 400/500/600, IBM Plex Sans Arabic 400/500/700, OFL
  LICENSE.txt), src/theme/fonts.css, index.html preloads, /fonts/* immutable cache rule in src/site/generated.ts.
- Tokens: ink/amber/mint/phone tokens appended to both theme blocks of src/theme/tokens.css.
- src/theme/global.css: font/radius/motion variables, type scale, .btn transitions, .btn-ghost, main.site-main.
- New: src/components/public/icons.tsx, src/lib/reveal.ts (data-reveal, html.js, 700 ms fallback), src/components/public/ProductVisual.tsx.
- Content: src/content/home.ts rewritten to the new HomeContent shape (hero, proofs, problems, capabilities, activities,
  how, previews, local, trust, cta, visual) in EN/FR/AR; src/content/prelaunch.ts (homePrelaunch = capabilitiesLead,
  howLead, cta; homeAsPrelaunch updated; aboutPrelaunch gains the 'roles' publisher-vs-product section); page.home.title in
  src/i18n/{en,fr,ar}.ts.
- Components/pages: blocks.tsx (Band, SectionHead, PageIntro as a navy band), Chrome.tsx (useReveal, main.site-main for
  public, main.site-main.in-app), Home.tsx, DukanErp.tsx, Products in Legal.tsx rewritten.
- npx tsc --noEmit FAILS on this state (1 errors; run it first).

Not done, in order:
1. src/theme/public.css rewrite — every new class is still unstyled: band/band-light/band-tint/band-dark, hero-grid,
   hero-copy, hero-stage, hero-actions, hero-title .hl, proofs, pv-* (phone + two cards + pv-demo), icon-badge, card-lift,
   problem-grid, bento/tile-*, art-*, activities, how-steps(+ -light), step-num, previews/preview-art/ui-row/ui-total/chip,
   lang-cards/lang-tag, local-grid, trust-grid/trust-links/trust-list, cta-grid/band-cta, section-head, feature-list,
   products-grid, either, providers, app-split, .num (ltr + tabular), .btn-lg, .stagger + [data-reveal] (html.js only,
   opacity .4 -> 1), dark header/footer, segmented language pill, .in-app .page-intro light, prefers-reduced-motion off
   switch, overflow hidden on bands. Rules: tokens only (no raw hex/rgba outside tokens.css), logical properties, keep the
   selectors the tests use (.chrome-header, details.menu, .nav-narrow a, .skip-link, .toc a, .org-details, .contact-label,
   .chrome-footer, .legal-draft, .legal-related, .notice).
2. Fix the scratchpad checker's import paths (file:///C:/... or relative) and run it; run tsc; adjust tests pinned to old
   content names if any (none found by grep so far).
3. Commit (git -c user.name=CLAUDE -c user.email=abdelkerim.mahfoudh@gmail.com, trailer Co-Authored-By: Claude Fable 5.1
   <noreply@anthropic.com>), push site-redesign, read ci-evidence, serve dist-public locally, headless screenshots at
   320/375/393/768/1280/1600 x EN/FR/AR x light/dark x reduced motion, fix, repeat.
4. Owner decision: enable a Pages preview for site-redesign (plus Preview env vars) or approve promotion by fast-forwarding
   tsx-public-site; verify production; keep b4737b88 as rollback. Then docs/21, session log, READY_FOR_HANDOFF / NONE.

Update (same session, minutes later): the one tsc error (ProductVisual.tsx, row.imei on a union) is fixed; npx tsc --noEmit now passes on the uncommitted site-redesign state. public.css and everything after it remain to do.

## Checkpoint 2026-10-17 — redesign implemented and green in CI (CLAUDE)

erp-control-web `site-redesign` = f719617 (c45de29, 8df952d, f719617), pushed; fast-forward of tsx-public-site 6016b8a.
CI run 39027574766 success: typecheck; Vitest 25 files / 440 tests; Playwright 126 (full) + 82 (public surface);
links 58 pages / 2753 checked / 0 broken; bundle audit PASS; gitleaks history + dist no leaks. Local review of the CI
dist-public: 28 captures (320/375/393/768/1280/1600, EN/FR/AR, light/dark, reduced motion), no overflow, one h1, no
console error, no foreign request, axe 0 violations at load (light/dark, 375/1280). Production untouched: still
6016b8a / Pages deployment b4737b88 (rollback point). Next: owner's choice of Cloudflare preview vs direct promotion.
