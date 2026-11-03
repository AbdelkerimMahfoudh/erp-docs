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

## 8. Multi-item sales: audit (2026-11-01, code read only; no behaviour tested)

**Already there, to reuse:** `POST /sales` takes `lines[]` (serialized or quantity) and `payments[]` in one transaction with a client key and
replay; `sale_items` holds per-line price, cost and discount; sold-once is a unique generated column; Sell has a multi-line cart in a saved draft
(`sell.cart`), scanner duplicate refusal, and `lib/sale-recovery`; the sales list already counts lines and items; returns name a `saleItemId`.
So build 3's request needs no mapping: it is already a one-line `lines[]`.

**Missing:**
- One basket shared beyond Sell: the cart is local state in `app/(tabs)/sell.tsx`. Stock has no Select, no sticky action, no Add to basket.
- Line-level conflicts: a failed line answers a plain 404 or 409 sentence, and 404 echoes the identifier.
- Approvals bound to a basket: `discount_approvals` is one row per unit (`unit_id` required), with no cart hash and no quantity-product case. Needs a
  migration.
- Draft isolation: the `sell.cart` key has not been shown to be per user and store, or cleared on logout, and must be proven or changed.
- Partial quantity return: to verify; the return path has per-unit claim logic and `quantityOnly`.
- Receipt, reports, corrections: to verify with several lines and split payments.

## 9. The CI failure on `93cb24a` (log read with the owner's permission, credential not printed, log deleted)

Gate 9b, not the renewal spec: two businesses opening their day at the same moment got Prisma P2034 from `/closings/open`, a deadlock, answered as a
generic 400. Intermittent, not reproduced in 6 local runs, and older than D227. Backend `5ac1df6`: the open transaction uses `withLockRetry`; P2034 answers
409 "try again" everywhere. Other transactions (sales among them) are not retried yet; the multi-item work must decide that for the sale path.

## 10. Owner's safeguards (backend `ceb81b9`)

- Retries: `P2034`, or `P2010` with whole-number 1213/1205 only; 3 attempts with jitter; `onRetry` logs the attempt number only. Exhausted: 409 `write_conflict`, localized in the app. A duplicate opening still refuses at once.
- **Production check, 2026-11-02, read only: no occurrence; the fix stays in D227.** MySQL up about 14 days, so its counters span the 2026-10-31 deployment: `lock_deadlocks` 0, and no latest-deadlock section in InnoDB status. API log (only since the 2026-11-01 20:57Z container): 0 write-conflict, lock or "Database request error" lines. `closing_events`: at most 2 openings a day, so the collision has had little chance to happen. Older API logs are gone.
- Multi-item: no blind sale retry until the basket-wide key and return-existing-sale are in place; injected write-conflict tests plus repeated real-MySQL runs.
- Store exemption: `free_until_at` is recorded at the grant. `setPeriodEnd` does not move it. `POST platform/businesses/:id/stores/:requestId/extend-grant` is the one way: password step-up, reason, audited, forward, inside the same period.

## 11. Multi-item backend, part 1 (backend `916728c`, not deployed)

- `sale_line_conflict`: every refused line at once, by position and reason, never the identifier. All-or-nothing; a fully unknown basket stays 404. Reaches clients through the filter's allowlist, which also now passes the add-store `amount` and `pendingRequestId` (renamed: `requestId` is every response's own).
- Retry: only with a key, only recognised conflicts, 3 attempts; out of retries looks for a committed twin before answering. No key, no retry.
- Real MySQL: `sale-basket.mysql.spec.ts`, gate 9b0, races repeated 5 times. Injected conflicts: `sales-idempotency.spec.ts`.
- **Next:** basket approval with a cart hash (migration); partial returns; receipt and reports with several lines; split-payment and receivable cases in the basket spec; then the app.

## 12. Accounts with no name (backend `dc60c494`, not deployed; migration 0118)

`companies.name` and `name_ar` are the one optional trading name; existing values untouched. Without one (`common/account-label.ts`):
- **A record with a store** names that store: a consignment its source store, a loan its recorded store. A loan with no recorded store says nothing rather than guess.
- **An invitation** returns `stores`, exactly those assigned. `business` stays for builds up to 1.0.0 (3), as those stores written out.
- **Sign-in chooser** returns each person's `stores`; `companyName` is the same written-out list for old builds, not an invented parent.
- **Account-wide messages:** neutral words, EN/FR/AR (`your Dukan account`). No store stands in.
- **Portal session:** `business.name` is null without a trading name, with `stores` beside it.
- **Receipts:** a sale since 0111 keeps its recorded answer; none is `null`, which build 3 replaces with the store name.
- **Admin list:** `accountLabel` parts (Owner by role, active stores in explicit order); the console words `Owner — Store`, `+ n more`, `No stores`.
- **Legacy, documented:** a connection records no participating store and the app has no primary store, so connections alone use the oldest active store, `createdAt` then `id` (`LEGACY_OLDEST_STORE`). The spec's source scan pins that. Recording a participating store on a connection would be new work, not done.
- With a trading name set, that name is shown for loans, consignments and connections, as existing accounts expect.
- **Still to do:** mobile and console read `stores`, `accountLabel` and null names; the console's `business.name` headings.

**Display rules, owner, 2026-11-02 (backend `168a378f`, supersedes the matching lines above).** Loans and consignments always name the exact store, with `otherPartyTradingName` as context. A connection joins whole accounts and is shown as one: `name` is the trading name or a compact `Store A + 2 more` (build 3 reads this), and an accepted connection adds `tradingName` and the full ordered `stores`. The oldest-active ordering decides only the first displayed name, a presentation label, never a "participating store". A stranger's search preview keeps the compact label only. Store-specific connections would be a later schema and consent change. Not deployed until mobile and console handle null names and store lists.

## 13. Security and sign-in: design and privacy review (2026-11-03; backend `999daa0`)

**What it does.** More → Your account → Security and sign-in. Each change is one `credential_changes` row: who, what,
which stage, and the code that stage is waiting for. A code is checked only against that row's own challenge, purpose
`credential_change`, so no code from another flow can answer it. Nothing about the account moves until the final step,
which commits in one transaction.
- **Password:** current password, then a code on the verified channel, then the new password (8 to 128 characters, not the same as the current one). On commit every other session is revoked and this session's refresh token is rotated: this phone stays signed in on the new token.
- **WhatsApp number:** current password, then a code on the existing verified channel, then a code on the new number, then the swap. The old number's consent is superseded and the new one's pending consent is activated, in the same transaction. Other sessions end.
- **Email:** refused up front (`email_unavailable`) while no email channel is enabled. No address is ever marked verified without a message that really went.
- **Legacy route:** the old app's phone-verification route can still verify a first number but can no longer move a verified one (`use_security_screen`).

**Privacy review.**
| Question | Finding |
|---|---|
| Passwords and codes in logs or audit | None. Only Argon hashes are stored. Audit rows carry `security:<event>`, and the only detail written is a masked destination (`whatsapp_changed`, `{to: masked}`). Logger lines are fixed sentences. |
| Account enumeration | A new contact held by somebody else in the same business looks identical until the end: no code is sent to it, and the final step answers the generic `change_refused`. A platform-wide Owner clash rolls back with the same answer. A wrong password gives one sentence whether or not the account exists. |
| What the screen sees | Masked destinations only (`+222••••1234`, `a***@domain`). The history lists event names and times; nothing else was ever written. |
| Consent | A pending WhatsApp consent is recorded at the start, with version, locale and IP (as at registration). It becomes active only on the final step; an abandoned change leaves it pending. |
| Retention (**fixed in `999daa0`**) | A cancelled, superseded, expired or completed change kept the contact it would have moved to, which may be somebody else's, in `new_contact` indefinitely, and account deletion did not clear it. It is now cleared when a change ends, swept at the person's next change (expired rows), and cleared, with open changes cancelled, by account and business deletion. Real MySQL spec added. **Residual:** an expired change of a person who never changes again keeps its contact until their deletion; the TTL is 15 minutes. A periodic sweep would close it. Not added, because a new scheduled job is a release change. |
| Notices | A security notice goes by verified email only, best effort, in English (`language: 'en'` is hard-coded, a wording gap, not a leak). With email disabled in production, nobody is told; the in-app history is the record. |

**Not verified interactively:** see the handoff: the local channel is `development-log`, which reports codes as
undelivered. The flows are proven by the real-MySQL spec, not on a screen.

## 14. Migration rehearsal 0116-0127 (`deploy/rehearse-migrations.sh`, backend `6f1a321`)

**Dry run, 2026-11-03T08:10Z, disposable MySQL 8.4.7 (port 3399), base built from the repository at `0115`:**
- 0116 to 0127 applied with `prisma migrate deploy`; a second deploy reported `No pending migrations to apply`.
- `mysqldump --no-data` of the upgraded database equals a fresh install from every migration: 139 tables, triggers and indexes included, AUTO_INCREMENT counters and DEFINERs aside.
- The base dump restored into a new database: row counts and `CHECKSUM TABLE` identical on all 133 tables.
- All rehearsal databases dropped.

**What it does not prove yet:**
- production's *exact* schema: the dry base is the repository's 0115, not a dump of the live database;
- an upgrade over real tenant rows: the dry base holds only the seed rows the migrations themselves insert (catalogues, permissions).

The release rehearsal runs the same script with `PROD_SCHEMA=` (a `mysqldump --no-data --routines --triggers` of
production) and, ideally, `PROD_DATA=` (a sanitised dump, `scripts/sanitize-dump.js`). Producing both needs the server,
so it waits for the SSH session. The restore proof against the real pre-deploy backup stays `deploy/production/restore-drill.sh`.

## 15. Release matrix (2026-11-03; nothing deployed; production backend `fbe4778`, migrations to 0115)

| Repository | Head | Evidence on exactly that commit |
|---|---|---|
| backend `post-testflight-feedback` | `6f1a321` (adds the rehearsal script only to `999daa0`) | CI 41602180151 success; `999daa0` CI 41600107710 success. `999daa0`: tsc clean, Security spec on real MySQL and deletion spec 50/50 locally. `469c36b` (before the privacy fix): CI 41582449844 success. |
| mobile `post-testflight-feedback` | `8cf3d36` | security 41586428626 success; intake 21/21, tsc clean, lint 37. **Render and visual cover `0589431`, not `8cf3d36`:** render-tests 41585324124 and visual-check 41585336786, both with backend `469c36b`. `bb75232` and `8cf3d36` change only test files. `0589431`: Jest 529/529 locally. |
| console D227 `d227/console-phone-errors` | `97a99ccb` (on `92a8c4c5`) | CI 41598292778 success. Local, whole suite: 673/680. The 7 failures were 2 `source-rules` tests (Windows paths; they also fail on the clean baseline) and 5 timeouts under full-suite load; `activity-public` and `trial-account` alone: 68/68. |
| console reviewed hosting `ops/admin-console-host` | `b09f5a90` | CI 41557833862 success. Not merged into the D227 line: the admin-console merge awaits the owner. |
| console integration candidate `d227/console-integration-candidate` | `907963e1` = `--no-ff` merge of `b09f5a90` into `97a99ccb`, no conflicts (no shared files, confirmed by both sessions) | CI 41599301712 success; tsc clean. Local, whole suite run alongside backend tests: 661/680. The 19 failures were 2 `source-rules` (Windows) and 17 under load; the 9 affected files rerun: 182/184, the remaining 2 then 82/82 alone. No failure is reproducible outside load. |
| docs `master` | this commit | — |

**Final heads paired:** mobile `8cf3d36` with backend `6f1a321`: render-tests 41602347950 success (ops `43f54de`),
visual-check 41602356671 success (ops `c4d0f98`). Every head in this matrix is green in CI. Release still waits on §16.

## 16. Remaining release blockers (2026-11-03)

1. **Owner decisions:** the admin-console merge (candidate `907963e1` is ready for review); the Manager money card (options A, B and C in the handoff); the periodic sweep of expired sign-in changes (§13 residual), or acceptance of the residual.
2. **Interactive passes not done:**
   - Security and sign-in on a build with a working test channel;
   - the basket on an iPhone or equivalent interactive build (Add from stock, price review, approval, split payment, receipt, repeated counted returns);
   - the opening and day-choice sheets, seen on screen;
   - no physical small iPhone used for any D227 screen yet.
3. **Rehearsal on production's exact schema** and, ideally, its sanitised data (§14): needs an SSH session to the server.
4. **Sentry:** the owner sets up the account. The token goes only into the protected EAS environment, entered by the owner. Monitoring stays disabled until the configuration is verified.
5. **Portal hosting and template:** on hold. `dukan.tsxmr.com` is not live (§5).
6. **Release mechanics, all after approval:**
   - merge `refs/heads/hotfix/sale-name-snapshot` into D227;
   - the verified off-host backup before migrating;
   - deploy;
   - Build 4 (scope fixed).
7. **Kept open:** the `agent-money` render suite timing out under full-suite load; the intermittent theme-boot-flash sample.

## 17. Update 2026-11-03 afternoon (supersedes the matching lines of §13-§16)

**The expired-contact residual of §13 is closed (backend `987eea7`).** An hourly sweep, started at boot like the
WhatsApp webhook worker's (unref'd timer, cleared on shutdown), sets every change past its 15 minutes to `expired` and
drops its contact. Ended changes still holding a contact from before `999daa0` are cleared on the same pass. Real MySQL
spec: an expired change is swept, an open one is left alone, and a swept change cannot be confirmed. `src/account`:
67/67 locally.

**The sale-name hotfix is in the D227 line.** `fbe4778` (`hotfix/sale-name-snapshot`) is an ancestor of backend
`987eea7` and every later head; `sale-http.mysql.spec.ts` runs in the database gates. No merge was needed.

**Hosting reconciled, as reviewable candidates only.** The admin-console merge into the D227 line waits for the owner.
- **Backend:** `d227/backend-integration-candidate` `3aa7ccd` (CI 41617737800 success). It holds D227 `eb96f5a` plus `ops/admin-console-host` `145c56c` (origin rule, `ADMIN_ORIGINS` production guard). The merge was clean (14 files). tsc clean. The origin specs and `src/platform` pass locally, except the two suites on the Windows-only list (`trial.service`, `subscription-lifecycle`).
- **Console:** `d227/console-integration-candidate` `907963e1`. CI 41599301712 success (§15).

**Rehearsal tooling (backend `d142d4c`; CI 41613196102 failed, see the final heads below).**
- `rehearse-migrations.sh` now compares the schemas through `information_schema`: columns with type, charset, collation, nullability and default; indexes; foreign keys; CHECKs; triggers. Comparing dump text was wrong: after a reload, `SHOW CREATE TABLE` printed identical columns with and without `CHARACTER SET`.
- Both paths PASS locally: from a production-format dump of 0115 (structure plus `_prisma_migrations` rows), and from the repository's 0115. Result: 139 tables, 1957 columns, 72 triggers.
- `deploy/production/schema-for-rehearsal.sh` fetches production's schema read-only (§18).

## 18. Production's schema for the rehearsal: the exact read-only commands

The established access: the owner's key `~/.ssh/tsxmr-production-admin` and host alias `tsxmr-app-01` (user
`tsxmr-admin`). The passphrase is typed by the owner into the Windows ssh-agent, never into chat. If SSH times out,
compare the laptop's public IP with firewall rule 4 first.

In an **administrator** PowerShell, by the owner:
```
Start-Service ssh-agent
ssh-add $env:USERPROFILE\.ssh\tsxmr-production-admin
```
Then, by me from Git Bash in `erp-backend`, read-only on the server:
```
mkdir -p "$HOME/d227-rehearsal"
SSH_BIN=/c/Windows/System32/OpenSSH/ssh.exe deploy/production/schema-for-rehearsal.sh tsxmr-app-01 "$HOME/d227-rehearsal"
MYSQL_BIN=/c/wamp64/bin/mysql/mysql8.4.7/bin ROOT_URL=mysql://root@127.0.0.1:3399 \
  PROD_SCHEMA="$(ls -1t "$HOME"/d227-rehearsal/prod-schema-*.sql | head -n 1)" deploy/rehearse-migrations.sh
```
- **What runs on the host:** `cd /srv/erp-production/erp-backend && sudo -n bash -c 'source deploy/production/lib.sh && compose exec -T db sh -c "… mysqldump … -u phonestore_backup …"'`, twice. The first reads the structure (`--no-data --routines --triggers --events`), the second the `_prisma_migrations` rows only.
- **What it does not do:** take a lock, write a file on the host, stop a container, or read a business row. It also refuses to finish if a `users`, `companies`, `sales` or `customers` INSERT ever appears.
- **Expected result:** production's last migration reads `0115_platform_admin_invitation`.

Afterwards, by the owner: `ssh-add -D`, then `Stop-Service ssh-agent`. The schema file holds no personal data but
stays outside every repository. It is deleted after the rehearsal is recorded.

**Optional, stronger:** the same rehearsal over sanitised production rows (`scripts/sanitize-dump.js` on a decrypted
backup, done on the laptop) proves the data-bearing upgrade. It needs the backup identity, so it happens only if the
owner asks for it.

## 19. Manager money card: the options (unchanged, no code changed)

- **Before D227 (build 3, production):** anyone with `report.view` (Owner, Manager; not Employee) sees "Expected money in store". The Owner sees the total, the Manager only the drawer's figure, carried from the last count.
- **Now in code:** the Owner sees Store balances, which shows tracked locations only. The Manager still sees the old card, so it claims a drawer figure even when cash is untracked. That contradicts "OFF: no balance claimed".

| Option | The Manager sees | Effect |
|---|---|---|
| **A (proposed)** | Tracked cash only, read-only, the same figure and label as the Owner's. Never accounts, never the settings. Nothing when cash is untracked. | Consistent with OFF; the Manager loses the untracked drawer figure. Reading needs `report.view`; changing stays Owner-only (`money.anchor.record`). |
| B | The old card, unchanged. | No change for Managers; the untracked contradiction remains. |
| C | No card. | Simplest; Managers lose a figure they had in build 3. |

Employees are unchanged under all three. Implementing A is a small mobile change, plus a backend read scope for the
tracked cash figure. The gates are rerun after it.

## 20. Portal hosting and Sentry in this release

- **Sentry is required by D227's scope, and it is not implemented.**
  - D227 decides: integration, privacy protections, error boundary, release tags and tests ship with monitoring disabled until the DSN and EAS token exist. It blocks nothing else.
  - The mobile app has no Sentry code or dependency at all.
  - Adding `@sentry/react-native` is a new native dependency in Build 4, which the rulebook treats as major. It needs the owner's go-ahead on the dependency, or an explicit decision that this release ships without it and Sentry moves to a later build.
  - The account, DSN and token stay the owner's either way.
- **Portal hosting is deferred and does not block D227.**
  - The portal code ships in the console build. `dukan.tsxmr.com` is not live (§5), and the iOS app links to no portal (D227's iOS payment rule).
  - Making it live needs DNS, a vhost and a template. Those are hosting changes, separate from this release and owner-decided.
  - The admin console hosting (`admin.tsxmr.com`) is likewise the owner's separate decision (candidates above).

## 21. Remaining release blockers (replaces §16)

1. **Owner decisions:**
   - the admin-console merge (backend `3aa7ccd`, console `907963e1`);
   - the Manager card (§19);
   - Sentry: implement it disabled, or defer it explicitly (§20).
2. **Interactive passes:** `docs/115`. Pass 1 needs the owner's iPhone on the laptop's Wi-Fi. Pass 2 needs the approved deployment and a TestFlight internal Build 4 candidate. A small iPhone is needed, or the gap stays recorded.
3. **Rehearsal on production's schema:** §18, the SSH session.
4. **After approval:**
   - the verified off-host backup (`backup-offhost.sh`);
   - deploy (backend, console);
   - Pass 2;
   - Build 4 (scope fixed).
5. **Kept open:** the `agent-money` render timeout under load; the intermittent theme-boot-flash sample.

## 22. Final heads (2026-11-03; nothing deployed)

**Backend `eb96f5a`: CI 41617725833 success.** It includes the sale-name hotfix `fbe4778`, the privacy fixes `999daa0` and `987eea7`, and the rehearsal tooling. `d142d4c` failed CI 41613196102 in `deploy-production.spec`: the new operator script was neither on the no-`stack.env` list nor committed `100755`. Fixed in `eb96f5a`. The failed job's log was read with the stored credential, read-only, and deleted.

**Mobile `8cf3d36`.**
- render-tests 41602347950, with backend `6f1a321`;
- visual-check 41602356671, with backend `6f1a321`;
- visual-check 41613319164 (ops `b4f5558`), with backend `d142d4c`;
- security 41586428626.

The backend commits after `d142d4c` change only a deploy script and its spec, which these gates do not exercise.

**Console `97a99ccb`: CI 41598292778.**

**Candidates for the owner's admin decision:** backend `3aa7ccd` (CI 41617737800) and console `907963e1` (CI 41599301712).

## 23. Production-schema rehearsal and the release heads (2026-11-03, 11:47Z)

**The rehearsal on production's exact schema: PASS.**
- **Fetched read-only:** `deploy/production/schema-for-rehearsal.sh tsxmr-app-01`, with the owner's key in the agent (fingerprint `SHA256:PBOHtt…`, as recorded). It used the read-only `phonestore_backup` account, structure and `_prisma_migrations` rows only. Nothing was written on the host.
- **Result:** 133 tables, last migration `0115_platform_admin_invitation`. `prod-schema-20261103T114715Z.sql`, sha256 `d736adf7…6d24a0`, kept on the laptop outside every repository, to be deleted after the release.
- **Rehearsal `20261103T114729Z`:**
  - 0116-0127 applied;
  - a second deploy applied nothing;
  - the upgraded production schema equals a fresh install (139 tables, 1957 columns, 72 triggers);
  - the base dump restored with identical counts and CHECKSUMs.
- **Not covered:** an upgrade over production's rows. The schema carries no data, by design.

**Release heads after the owner's decisions:**

| Repository | Head | What it adds | CI on that head |
|---|---|---|---|
| backend | **`b945098`** | `3aa7ccd` (admin hosting merged) → `5acde6b` (Manager option A) → `b945098` (rollback floors) | security 41625331832 **success** |
| mobile | **`a108e7c`** | Manager card | security 41626043305 **failed in setup**: "the backend beside this checkout" could not clone `erp-backend` |
| console | **`907963e1`** | admin hosting merged | ci 41622232435 **failed**: 2 of 172 browser checks (public `/fr` at 375 px and desktop; `/fr` and `/ar/products/dukan-erp` at 375 px). The same commit passed as the candidate (41599301712). Not reproduced; treated as intermittent until rerun. |

**Gates pointed at mobile `a108e7c` with backend `b945098`:** render-tests 41626063732 and visual-check 41626081018 both
failed before testing, on `repository 'https://github.com/AbdelkerimMahfoudh/erp-backend/' not found`.
- **Cause:** all four repositories are now **private** (read 11:5xZ); the mobile workflows clone the backend anonymously ("The repository is public").
- **Not a code failure, but the gates prove nothing until one of these is done:** the visibility is restored, or the workflows get read access to `erp-backend`. Either is a repository-settings change for the owner.

## 24. Pass 1 (docs/115), 2026-11-03 ~13:10Z: owner-reported, partial

- **Setup:** Expo Go on the owner's iPhone, LAN, Metro 8082. The build line read `2ca6f15`, whose app code equals `a108e7c`. The local D227 API ran on the disposable database with the fictitious "Pass One Shop".
- **Owner's report:** "I tested most of the changes and it is green". No ❌ reported.
- **Not recorded item by item:** which docs/115 items were covered. The owner deferred the rest (2026-11-03) and asked not to be asked again; this is the recorded gap.
- **Covered by neither pass:** Arabic right-to-left layout, real code delivery, and the small iPhone. Pass 2 (TestFlight internal) covers the first two.

## 25. The D227 deployment (owner-authorised 2026-11-03; docs/116)

**Gates before:** backend `b945098` security 41625331832; mobile `2ca6f15` security 41633917087, render 41633928647 and visual 41633937783 (app code `a108e7c`, backend `b945098`); console `bb620d03` CI 41640574120, the `/fr` language fix (§23); production-schema rehearsal PASS (§23). Pass 1: owner-reported, partial (§24).

| Step | Result |
|---|---|
| Release onto the host | Git bundle of backend `b945098`, sha256 `06a1b9366583d58b…` on both ends. Host checkout detached at `b945098`. The running API was untouched until deploy. |
| Off-host backup | `phonestore-20261103T135100Z.sql.gz.age` (128 KB), copied to the laptop (`.tsxmr/production-backups`), checksums equal, receipt recorded. A first attempt (`…135014Z`) made its copy but could not write the receipt: the old checkout had no `backup-receipt.sh`. |
| Restore proof of that backup | `restore-drill.sh --identity /dev/shm/…`, **without `--offsite`**, so `offsite-restore-proof` keeps `kind=storage-box` (checked before and after). The identity was piped from the laptop file into a `/dev/shm` directory of the same SSH session and shredded on exit. Drill `20261103T135152Z`: **PASSED**. 133 tables, 72 triggers, row counts, binary-key digests, money sums (sales and payments 96000.00), trigger bodies, every CHECKSUM. Copy dropped. |
| Configuration | `api.env` (copy `api.env.pre-d227`): `CORS_ORIGINS` gained `https://admin.tsxmr.com`; `ADMIN_ORIGINS=https://admin.tsxmr.com,https://dukan-test.tsxmr.com` (transition). Fingerprint `766e9e2f…` → `f3fe96c7…`. `stack.env` (copy `stack.env.pre-d227`): `ADMIN_CONSOLE_HOST=admin.tsxmr.com`, set at the admin step. |
| `deploy.sh` | Exit 0. Preflight PASS (email disabled, WhatsApp cloud, 4 CORS origins, 7 secrets as files). Its own pre-migration backup `phonestore-20261103T135506Z`. Migrations 0116-0127 applied, 126/126. Catalogue 77/77. Identities 25/25. Audit chain OK for all 8 companies. Smoke 15/15, commit `b94509847214`. Image `erp-api:b945098…`, previous (rollback target) `erp-api:fbe47784…`. |
| After | WhatsApp cloud with live sends enabled, recipient limit 200, email disabled, push unset; the off-site timer active; `offsite-restore-proof kind=storage-box`. |
| Origin rule over HTTP | `platform/admin/me`: 401 from `admin` and `dukan-test` (allowed, no session); 403 from `dukan`, `erp-test` and an unknown origin; CORS granted only to listed origins. |
| DNS (Cloudflare, by Claude in the owner's browser) | **Added exactly one record:** `A admin.tsxmr.com → 178.104.245.227`, DNS only, TTL Auto, no AAAA. The other 14 records were unchanged (15 of 200). Resolved from 1.1.1.1 and 8.8.8.8 at once. The laptop's router served a cached NXDOMAIN for up to 30 minutes (SOA TTL 1800). |
| Admin site | CI release `bb620d03` (`admin-release.txt`: commit `bb620d03…`, api `https://api.tsxmr.com`), 27 files. First `admin-site.sh install` refused: `/admin` answered 000 before the certificate existed. Caddy obtained it from Let's Encrypt seconds later. The second install: release `20261103T140051Z` installed, checks passed. `/admin` 200 with `X-Robots-Tag: noindex, nofollow, noarchive`, CSP, HSTS, nosniff, frame denial; `/subscription` 404. |
| Pending | The owner's sign-in, second factor, step-up and sign-out on `admin.tsxmr.com` in a real browser, with the cookie checked. Then the removal of `dukan-test` from `ADMIN_ORIGINS`. Then dukan-test's preview update. |

**Build 4:** EAS build `a6570f09-db87-4821-964d-faf49705ed50`, iOS production, **1.0.0 (4)**, from mobile `8570ff6` (D227 plus the Offset Spiral identity), `EXPO_PUBLIC_API_ORIGIN=https://api.tsxmr.com`. Free plan, 0 of 15 iOS builds used before it; resets 2026-12-01. Sentry deferred to the next build (owner).
