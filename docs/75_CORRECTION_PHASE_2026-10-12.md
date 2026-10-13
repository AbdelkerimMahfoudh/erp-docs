# 75 — Correction phase (2026-10-12): typed commission, Dukan ERP, deletion, delivery, administrator MFA

The owner's correction brief of 2026-10-12, carried out by CLAUDE-B. Nothing here was deployed, merged to production,
applied to a live database, purchased, or submitted to Apple. Decisions: **D164–D168** (`21_PRODUCT_DECISIONS.md`).

## 1. Branches and commits

| Repository | Branch | Commits (in order) |
| --- | --- | --- |
| `erp-backend` | `reports-export` | `9c9005a` commission + 0092 · `2bb5130` naming · `4cc2533` deletion/privacy · `e345680` delivery boundaries + 0093 · `1d8321b` administrator MFA + 0094 · `aad5862` secret-scan fixtures |
| `erp-mobile` | `reports-export` | `8bb9201` typed commission UI · `02f2e4e` deletion device credential + copy (`db67298` naming, earlier in the phase) |
| `erp-control-web` | `tsx-public-site` (**not merged**) | `83d2e1a` D164 copy · `fa3c3fe` naming · `9b079c2` deletion/privacy copy · `e2384c0` console MFA · `e892a27` MFA test fixtures |
| `erp-docs` | `master` | `6502a65` claim · `f614926` checkpoint · this record |

## 2. The commission (D164) — semantics

- **Typed by the employee for every exchange**, in whole MRU, `0` typed when the customer paid none. An empty field is
  never zero: the counter will not review it, the server refuses it (`commission_required`). Negative, fractional or
  text → `commission_invalid`; when cash is handed over, more than the amount → `commission_exceeds_amount` (the customer
  would be handed a negative sum). No ceiling when cash is received: the customer pays it on top.
- **Paid by the customer to the business.** The provider neither pays nor checks it, and it never touches the provider's
  credit. There is no rate, no destination, no "deducted" mode, no commission held by a provider.
- **The employee is the person signed in.** The body cannot name a recorder (`forbidNonWhitelisted`); the server derives
  the employee, company, branch and business day.
- **Immutable after confirmation**: the update trigger refuses any change to the commission or its source (only the
  de-identification redactions of D165 are allowed).
- **Legs** (the drawer's equations unchanged — the commission is one more cash inflow):

  | Route | Cash | Provider credit | Commission |
  | --- | --- | --- | --- |
  | Receive cash, send credit (`cash_in_credit_out`) | in A + C | out A | C, on the drawer |
  | Give cash, receive credit (`cash_out_credit_in`) | out A, in C → **A − C handed over** | in A | C, on the drawer |

- **The review before Confirm** shows the amount, the commission paid by the customer, the cash the customer hands over
  or is handed, and the credit sent or received (always the amount), with the sentence that the provider neither pays
  nor checks the commission.
- **Idempotency**: the fingerprint of a typed exchange includes the commission (`v:2`). Same key and body → the same
  record; same key with another commission → `idempotency_conflict`; concurrent identical sends → one record.
- **Offline**: the queued payload carries `commissionAmount` through every retry; provisional figures put it in the
  drawer; the status lookup matches on it. An exchange an earlier build queued (with a configuration version, no
  commission) still reads, is refused `commission_required` and is fixed by *Edit and send* under a new key — never
  dropped, never sent unchanged.
- **Providers**: name, kind, switched on or off, and the reference rule (required / optional / none). Nothing to configure
  before use; a rate sent to the API is refused by the validation pipe. Screens are label-above-value (320 px, large
  text, right to left).
- **No commission dashboard.** History (exchange detail) and reports are the only views (the owner's instruction).

## 3. Migrations — details

| Migration | What | Existing rows |
| --- | --- | --- |
| `0092_manual_commission` | `commission_source ENUM('manual','legacy_rate')` (every existing row `legacy_rate`, default `manual` afterwards); rate, version and snapshot nullable; CHECKs per source (manual ⇒ whole MRU, no rate, give-cash commission ≤ amount; legacy ⇒ rate and version present); update trigger recreated: commission and source immutable, only redactions allowed (customer number → `''`, recorder/reverser name → `Deleted user`) | byte-identical (projection MD5 before/after) |
| `0093_delivery_boundaries` | `messaging_delivery_proofs`; `contact_verifications`: delivery state, provider, message id, detail, `hash_version` (1 = earlier unkeyed SHA-256, 2 = HMAC under `OTP_PEPPER`) | unchanged; all stay version 1 |
| `0094_admin_mfa` | `platform_admins`: sealed TOTP secret, enabled at, last step, pending secret, enrolment-token digest and expiry, failure count, lock; `platform_admin_sessions`: `mfa_verified_at`, `step_up_at`; `platform_admin_recovery_codes` | unchanged; every administrator must enrol; every open session becomes pending |

All three are additive; each file's header carries its reverse SQL. **Not applied to `phonestore` (still at 0091) or any
live database.**

### 3.1 Rehearsal (disposable MySQL 8.4.7 on 3308, root; `erp_rh_*` only, all dropped afterwards)

- **Structure path 0083 → 0094.** No pre-0084 database existed, so `erp_rh_0083` was built from migrations 0001–0083
  (70 s). Backup (312 KB) → restored into a second database: structure and 30 triggers identical. `prisma migrate deploy`
  applied 0084–0094: **11 migrations, 8.5 s**, 47 triggers; drift against the schema: none beyond the known 562-line
  baseline (the same set `phonestore` at 0091 shows against its own schema). Rollback = restore: identical to 0083.
- **Data path 0091 → 0094 on the PC's data** (`erp_rh_0091d` from the PC dump): backup (1.29 MB) → **3 migrations,
  4.1 s**. Whole-row checksums changed only for the six tables given columns or created; the pre-existing columns of those
  tables are identical; 8 exchanges, all `legacy_rate`; 10 contact verifications, all version 1; 1 administrator without
  MFA. Drift: none beyond the baseline. Rollback = restore the backup: **all 106 tables identical** to before, back at 0091.
- **The previous API on the migrated schema**: its reads work (all 8 legacy exchanges still join their configuration
  version); **its exchange insert is refused** by `ck_agent_transactions_commission_manual` — it fails closed, nothing
  wrong is written. **Deploy the API and 0092–0094 together**, in one maintenance window (measured: seconds).
- **Downtime**: the three migrations took 4.1 s on the PC data; table copies (CHECK, FK changes in 0092) scale with
  `agent_transactions`. The administrators must enrol (CLI token) before the console is usable.
- **Not run on live**: the staff-seat transition, the Money Services Agent transition, and every migration.

## 4. Historical (rate-derived) commissions

Never recalculated, never reinterpreted. Every exchange recorded before 0092 keeps its stored `commission_amount`, rate,
configuration version, snapshot and legs, and is marked `legacy_rate`. Its legs stay as written — a commission once
credited to a provider's float stays on that float in every report (reports read each exchange's stored legs). The
detail screen says *Commission at the earlier rate (n %)*, how it was settled, and *Recorded under the provider's
earlier rate, before commissions were typed. Kept exactly as it was recorded.* Configuration versions written before
D164 keep their rates as history under `legacy`; a new version carries the reference rule only. Rate columns are kept
(nullable), not dropped: dropping them needs its own backup and restore rehearsal.

## 5. Reports

Day, week, month and year (`GET agent/reports`) sum stored amounts only: count, volume (principal), commission, cash
received and paid, credit sent and received — computed from each exchange's own principal and commission legs — by
provider, by employee, by month for the year, **by route** (receive cash / give cash: count, volume, commission), and
reversals on the day they were made. Commission revenue is not yet in the profit analytics
(`commissions_and_fees` stays unavailable there).

## 6. Dukan ERP naming

Product **Dukan ERP**, organisation **TSX-MR**, relationship *Dukan ERP is developed and operated by TSX-MR*. Changed:
the app's display name and login title with the byline, camera permission text, report PDF footer and file names
(`DukanERP_…`), the API's Swagger title and description, the backend and website package descriptions, email texts.
**Unchanged, as instructed — publication inputs needing explicit approval before any change:** Expo slug
`phonestore-erp`, deep-link scheme `retailerp`, iOS bundle identifier / Android application id `mr.retailerp.app`,
EAS project id `834d8b25-…`, push identifiers, the npm package names, database name and users (`phonestore_app` is named
by every append-only trigger), tables, permissions and API fields. Changing the bundle id or package means a new App
Store / Play listing (existing installs do not update to it); changing the scheme breaks existing links; changing the
slug or project id detaches the existing EAS builds and push credentials. No logo was made. The WhatsApp template texts in
`docs/64` still say "Retail ERP" and need re-approval at Meta as Dukan ERP.

## 7. Deletion and privacy (D165)

**Removed now, for a deleted login:** name → *Deleted user*, email, phone, password, PIN, the sign-in identifier
(replaced), every session's IP, user agent, device name and install id, device labels and models, the destination of
every code ever sent to it (`[deleted]`, rows kept), its verification intents, the contact verifications, sign-up records
and seat requests naming its email or number, its sync devices and outbox, pending invitations and notifications, its
name on the counter's exchanges and mistake reports, its counterparty; the phone forgets the device credential.
**For a closed business, also:** customers' names, phones and notes; suppliers' phones and notes; the people it lent to
or employed (name → *Deleted user*, phone, city, note); another store keeps its name, loses phone and note; payer numbers;
the counter's customer numbers (`''`); mistake-report and expense notes; receipt photos (rows cleared in the transaction,
files deleted from storage after the commit, a failure logged by count only); branch addresses and phones; the company
city, public phone and logo; every session and code of the company; the outbox.
**New audit events no longer hold contacts** (customers, users, staff invitations, payer numbers say `set`; seat
requests and activations name the account id). **Search terms are scrubbed from request logs.**
**Not removed — said so in the app and on the website, and listed in every deletion summary (`notRemoved`):** the
hash-chained audit trail (`audit_logs`), subscription events and platform audit events — append-only, editing them would
break the chain, and rows written before this phase may hold a name or contact; the names on append-only money-agent
records (positions, rebalancings, configuration versions); **backups, until they expire — the backup retention period
is not set: TSX-MR must supply it, production stays blocked**. Active-storage deletion is immediate; backup expiry is a
separate schedule. Personal-login deletion over HTTP was not exercised (no second login in the test company); it is
covered by the service tests.

## 8. Delivery channels (D166)

- **Email**: a provider boundary like WhatsApp's — `disabled` (default), `development-log` (refused in production),
  `resend` (inert without `RESEND_API_KEY` and `EMAIL_FROM`; https only). Approved EN/FR/AR text for contact
  verification; password recovery and security alerts have text but **no flow exists** to send them; invitations go out
  as a verification code; **deletion codes stay WhatsApp-only** (email deletion codes are not approved). Failures are
  classified, a temporary one retried once under the same idempotency key, the result recorded on the code's row, and a
  code that could not be sent is dead at once and never shown. Contact-verification codes are HMAC-SHA256 under
  `OTP_PEPPER`. **No provider is connected.** SPF, DKIM and DMARC for the sending domain are prerequisites (`docs/64`).
- **WhatsApp**: in production a real channel stays **closed until delivery is proven on the deployment** — one delivered
  message per language (en, fr, ar), sent with `npm run whatsapp:prove -- --to <operator number>` using the approved
  `delivery.check` template, and completed only by a **signed** delivery report on the webhook. Until then the channel
  reports itself unavailable: no code, no deletion code, no deletion completion, no invitation marked delivered. The
  production guard requires the webhook secrets and the delivery-check and completion templates with `cloud-api`.

## 9. Super Admin MFA (D167) — design and verification

A password opens a **pending** session that reaches only `mfa/verify`, the two enrolment routes and sign-out; everything
else answers `401 mfa_required`. TOTP is RFC 6238 (HMAC-SHA1, 30 s, 6 digits, ±1 step), the last used step refuses a
replay, five failures lock the factor for fifteen minutes behind a 10/min route throttle. **Enrolment and every reset
need a one-time token from the server CLI** (`npx ts-node prisma/platform-admin-mfa.ts enrolment-token <email>`; 30
minutes; keyed digest), so a stolen password cannot bind an authenticator; the secret stays pending until its first code
verifies, then is sealed with AES-256-GCM under `PLATFORM_MFA_KEY` (32 bytes; production refuses to start without it).
Ten recovery codes, shown once, keyed digests, spent atomically; regeneration (after a step-up) revokes the old set.
**Step-up** for every high-impact action = the password **and** a fresh code (`POST platform/admin/step-up`), recorded on
that session and honoured five minutes, checked server-side by every existing `confirmPassword` call — the password
check and version checks stay. Audited: reset (CLI), enrolment started/refused/enrolled, verified, failed, locked,
recovery used/regenerated, step-up; secrets, codes, recovery codes and tokens are never logged or audited (pino redaction
and the audit's never-log list). The console asks for the code, enrols (token → key to type or open as an `otpauth`
link → first code → recovery codes once) and asks password + code at each decision. **QR rendering is not built** (manual
key and link only). Cloudflare Access in front of `/admin` stays optional, documented in `docs/74` §8.

## 10. Test totals (final)

| Suite | Result |
| --- | --- |
| Backend `tsc` | 0 errors |
| Backend Jest | **212 suites, 3 861 passed, 3 skipped** |
| Backend full-history secret scan | clean (2 047 blobs, 319 commits) after `aad5862` |
| Mobile `tsc` | 0 errors |
| Mobile lint | 0 errors, 29 warnings (all in files this phase did not touch) |
| Mobile pure tests | **268 / 268** |
| Mobile render (Jest) | **156 / 156** with two workers (§10.1) |
| Mobile secret scan | 1 historical finding: the session tokens in `public/cp45-session.json`, commit `7049ea4` — the G2A-CP4.5 incident, already revoked and verified dead (`CLAUDE.md`, Git rules); file not in the tree; history not rewritten, as the rules require |
| Mobile web export | not run: blocked by Smart App Control on the PC (as before) |
| Website (CI run 38249387941 on `e892a27`) | typecheck; Vitest **119 / 119**; production build refused as designed; preview built; links; bundle audit; npm audit recorded; gitleaks history + dist clean; Playwright **58 / 58** (every public page × EN/FR/AR at 375 and 320 px, desktop, 200 % text, axe, keyboard, headers) |

### 10.1 Mobile render suite

**156 / 156** (14 suites) after `02f2e4e`, with two workers. With the default workers, `agent-money` hits Jest's 5 s
timeout in "the Owner sets a float" under load and the rest of that file cascades; it passes alone (23/23 with
`agent-closing`) — the same load sensitivity an earlier session recorded. No test timeout was changed.

## 11. Real HTTP (disposable `erp_rh_0091d` at 0094, API built from this phase on 127.0.0.1:3011)

**51 checks, 50 passed on the final run; the one failure was cumulative across runs (two reversals from two runs, one
audit row each — verified by SQL).** Covered: the 15-step agent lifecycle — a provider with no rate usable at once, a
rate refused; commission required / empty / negative / fractional / above the amount refused; another employee in the
body refused; recorded with the signed-in Owner; legs; duplicate once; changed-commission conflict; give cash 14 850
handed over; zero commission; day/week/month/year reports and by route and employee; rename and switch-off preserving
history; cross-company branch and provider refused; offline replay, lookup, a race producing one record, an earlier
build's queued exchange refused `commission_required`; reversal countering the commission leg, audited; the commission
not updatable by the application user (trigger). MFA: pending session blocked, wrong token refused, enrolment, sealed
secret, verified console, replay refused, recovery code once, step-up required then accepted, password still checked,
audit without secrets. Deletion: closing a business with the WhatsApp code (development channel, local only) — no name,
contact, session detail, code destination, counter number or address left; records kept; the login refused afterwards.
Fixtures on the copy only (a test WhatsApp number, address and city for Boutique 6; the day opened through the API).
Teardown: API stopped, port released, the temporary grant revoked (`phonestore_app` back to `phonestore.*` only), all
`erp_rh_*` databases dropped, `phonestore` still at 0091.

## 12. Screenshots affected

Website: the Dukan ERP page (money services copy), the account deletion page, and the privacy page — in CI evidence
`ci-evidence:evidence/e892a27…/` (and `9b079c2…`). The console's MFA screens are behind sign-in and are not screenshotted
(covered by component tests). Mobile: the counter, review, providers, provider detail, exchange detail, reports and
deletion screens changed — **not device-verified** (`docs/24` §64).

## 13. Unresolved inputs and blockers

- **Credentials not supplied**: WhatsApp (WABA, number, token, app secret, approved templates in EN/FR/AR including
  `delivery.check`), email (Resend account, sending domain with SPF/DKIM/DMARC, key), `PLATFORM_MFA_KEY` per environment.
- **Legal**: retention period of business records; **backup retention period**; legal approval of the sealed-history
  disclosure; processors and where data is processed; governing law and liability; review of privacy, terms and
  deletion texts; TSX-MR's legal identity and contact details.
- **Publication inputs**: app identifiers (§6) — keep or change, with the consequences stated; Dukan ERP WhatsApp
  template texts re-approval; logo.
- **Device-only checks**: the counter's commission field with the Arabic keyboard, the review at 320 px and large text,
  the provider screens in RTL, a queued exchange from the earlier build fixed by *Edit and send*, deletion forgetting
  the device credential.
- **Not built**: QR rendering for enrolment; email flows for password recovery and security alerts; commission revenue
  in profit analytics; personal-login deletion over HTTP (service-tested only).
- `local-scripts/boutiques-local.ts` (outside the repositories) still signs in to the console with a password only; use
  `erp-backend/scripts/qa-boutiques.ts`, which now completes the second factor.

## 14. Next safe step

The owner reviews this phase and decides the app identifiers and the legal/retention inputs. Then, on a **staging**
database restored from a fresh backup: apply 0092–0094 with the API from `reports-export` in one window, enrol each
administrator with a CLI token, and run the device checklist `docs/24` §64. `tsx-public-site` stays unmerged until those
inputs exist; no live migration until the owner approves the runbook.

## 15. The final technical identity (2026-10-13)

The owner's brief of 2026-10-13 fixed the identity before any store publication (`docs/21` D168, as amended). CLAUDE-B
(local) did it beside the free-trial phase (cloud), touching none of its files.

| Field | Before | Now |
| --- | --- | --- |
| Product | Dukan ERP (D168) | **Dukan ERP** |
| Operator | TSX-MR | **TSX-MR**, for operator and legal attribution only |
| Expo slug | `phonestore-erp` | **`dukan-erp`** |
| URL scheme | `retailerp` | **`dukanerp`**, with no alias |
| iOS bundle identifier | `mr.retailerp.app` | **`mr.tsxmr.dukanerp`** |
| Android application ID / package | `mr.retailerp.app` | **`mr.tsxmr.dukanerp`** |
| npm packages | `phonestore-erp-mobile`, `phonestore-erp-backend` | `dukan-erp-mobile`, `dukan-erp-backend` |
| EAS project | `834d8b25-2737-46e8-b911-3eac6d85c2fb`, slug `phonestore-erp`, account `salah_rim` | **unchanged** (§15.3) |

### 15.1 No store or production identity existed

- **App Store Connect:** no record exists, because there is no Apple Developer membership (`docs/67` §8). There has never
  been an iOS, TestFlight or App Store build.
- **Google Play:** no app. No document, script or credential refers to one.
- **EAS** (`eas build:list`, read-only): three builds, all Android `preview` with internal distribution for
  `mr.retailerp.app`. One errored on 2026-09-01; the others finished on 2026-09-01 and 2026-09-08. There is no
  production or store build.
- **Push and updates:** `expo-notifications` and `expo-updates` are not installed. So there are no push credentials
  and no update channel. The generated iOS entitlements are empty, and `Expo.plist` has updates disabled.
- **`retailerp://`:** nothing outside `app.json` produced or received it. The backend's messages carry codes, not app
  links. The website has no app link and no store link.

**Consequence:** the new identifiers are used, no second store identity exists, and `retailerp://` was removed with no
alias.

### 15.2 What changed, and what deliberately did not

- **Mobile `0a94e13`:**
  - `app.json`: slug, scheme, `ios.bundleIdentifier`, `android.package`.
  - Every iOS system prompt now names Dukan ERP. The plugin defaults read "Allow $(PRODUCT_NAME)…", which shows as
    "DukanERP". Now:
    - photos (expense receipts): *Dukan ERP opens your photos only when you choose a receipt picture for an expense.*
    - microphone: *Dukan ERP does not record sound.*
    - Face ID: *Dukan ERP does not use Face ID.*

    The microphone and Face ID strings stay because their modules link those APIs. Removing the string risks Apple's
    upload check for missing purpose strings. Neither prompt is ever shown.
  - `expo-image-picker` is now listed with its texts.
  - The npm name, the lockfile name, and the Tailwind comment.
  - New tests: `lib/app-identity.test.ts` and `__tests__/deep-links.test.tsx`.
  - `9af0401` corrects a section reference.
- **Backend `33b671c`:** the README, the `.env.example` and `docker-compose.yml` comments, and the package name.
- **Website `72b1be8`:** one README line. The site already said Dukan ERP everywhere.
- **Unchanged, on purpose:**
  - Database, user and folder names (`phonestore`, `phonestore_app`, `phonestore_migrator`, …). They are technical
    identifiers, not the product's name.
  - The audit history.
  - The `PATCHED (PhoneStoreERP)` comments inside `patches/expo-camera+57.0.5.patch`. They are native source comments
    and are not shipped.
  - No migration was made for naming.

### 15.3 EAS: the project keeps its ID, and builds wait for the owner

Expo documents that *"A project ID is associated with a single slug, which cannot be changed"*
(expo.fyi/eas-project-id). Every EAS command that resolves the project therefore refuses with:
`Project config: Slug for project identified by "extra.eas.projectId" (phonestore-erp) does not match the "slug"
field (dukan-erp)`.

As the brief requires, the ID was neither deleted nor replaced, and no project was created. This is **blocked on the
owner**; the exact steps are in `docs/44`, "Store identity — the operator's steps".

`expo start` is not affected. With Metro started online as usual, the Expo Go scope key comes from the server by project
ID, so Expo Go's storage (session, device credential, queued offline items) is unchanged.

- **Offline starts:** an offline start derives the key from the local slug, so it now opens a fresh scope. Keep starting
  Metro online.
- **Linking a new project:** this means a new scope. Drain every phone's queued exchanges first; the phones will sign in
  again and verify their device again.
- **Android signing:** the old project's Android keystore belongs to `mr.retailerp.app` and is not reused. EAS generates
  an upload key for `mr.tsxmr.dukanerp` on the first build.
- **iOS credentials:** these need the Apple membership. No team ID, key or ownership was invented.

### 15.4 Deep links

The only scheme is `dukanerp://`. Expo Router opens it; there is no hand-written parser and no `+native-intent`.

- **Codes, not links.** Verification, password reset, invitations and deletion all use codes typed in the app, so no
  message carries an app link.
- **Notifications.** In-app notifications carry paths (`actionLink`); push notifications are not built.

`__tests__/deep-links.test.tsx` (32 tests) opens links through Expo Router's own iOS cold-start path
(`Linking.getLinkingURL()` → `extractExpoPathFromURL` → `getStateFromPath`). It runs over the app's real route files,
with stub screens. It covers:

- **Screens:** sign-in, branch choice, stores, access, the closed-business screen, the account and its deletion,
  notifications, a sale, a sale period with its query, a unit by IMEI, an exchange, and the legacy `hub/money`.
- **Edge cases:** the bare scheme, and an unknown address (the not-found screen).
- **Server notification targets:** every destination a server notification carries (`/analytics`, `/closing`,
  approvals, a catalogue item with and without `?unit=`, returns, transfers).
- **The sign-in guard** (`entryRoute`):
  - signed out → sign-in;
  - no branch → branch choice;
  - signed in with a branch → the record;
  - a closed business → the refusal, while the person's own account and deletion stay open;
  - restoring → nothing moves.
- **No secret in a link:** no route segment, and no screen parameter, is named after a code, token, password or secret.

### 15.5 Proven from what a build generates

- **Configuration.** `lib/app-identity.test.ts` (9 tests) resolves the configuration with `@expo/config` under each
  EAS profile's environment (development, preview, production) and gets the same identity each time. It also reads the
  native files through Expo's introspection: the home-screen name, the URL schemes, the package, and the system
  prompts.
- **Native projects.** `expo prebuild` ran on a scratch copy of `0a94e13`. On Windows, Expo CLI drops `ios`; the
  scratch run bypassed only that filter.
  - Android: `applicationId` and `namespace` are `mr.tsxmr.dukanerp`; `rootProject.name` and `app_name` are
    "Dukan ERP"; the Kotlin package is `mr/tsxmr/dukanerp`; the only VIEW scheme is `dukanerp`.
  - iOS: `PRODUCT_BUNDLE_IDENTIFIER` is `mr.tsxmr.dukanerp` in Debug and Release; `CFBundleDisplayName` is "Dukan ERP";
    the URL schemes are `dukanerp` and `mr.tsxmr.dukanerp`; every purpose string names Dukan ERP; the entitlements are
    empty.
  - No old identifier appears anywhere in either tree.
- **Release bundles.** `expo export:embed` was run for Android and iOS, as Gradle and Xcode run it, together with the
  embedded `app.config` from `expo-constants`.
  - Each JS bundle contains "Dukan ERP" 6 times.
  - The embedded config contains `dukan-erp`, `dukanerp` and `mr.tsxmr.dukanerp`.
  - None of the artifacts contains `Retail ERP`, `retailerp`, `retailerp://`, `phonestore-erp` or `mr.retailerp.app`.
- **Mutation check.** Putting the old scheme back as an alias fails 6 of the 9 identity tests.

### 15.6 Visible names, the logo, and observations

- **Branding.** D168 had already renamed every visible surface. This phase adds the iOS prompts (§15.2) and the WhatsApp
  template drafts in `docs/64`, which now say Dukan ERP and must be registered at Meta under that name.
- **Website.** CI run 38344708273 shows no old name in the 52 built files. Titles read "TSX-MR — …" for the
  organisation's pages and "Dukan ERP — TSX-MR" for the product page. Arabic pages render `dir="rtl"`.
- **Logo: release blocker.** No approved logo is in the repository. `app.json` has no `icon`, so a build shows the Expo
  template's icon, and the splash shows the template's plain mark. Nothing was drawn or rendered from text. The owner
  chooses among the four concepts.
- **Observation, not changed: Android `RECORD_AUDIO`.** It is declared because `expo-image-picker` adds it; the app
  never records. Decide before the Play listing: `"microphonePermission": false` on that plugin, or
  `android.blockedPermissions`.
- **Observation, not changed: iOS prompts are English only**, as the camera's was before.
- **Observation, not changed: Expo Doctor** reports 10 Expo patch versions behind the SDK. This was already recorded as
  owed; `expo-camera` is pinned by our native patch.

### 15.7 Upgrading from the current builds

A native build of `mr.tsxmr.dukanerp` installs **beside** an internal preview APK of `mr.retailerp.app`; it does not
replace it. Nothing carries over between them. Drain the old app's queue, then uninstall it. Expo Go development is
unchanged (§15.3).

## 16. Clean real-HTTP rerun (2026-10-13)

**Harness.** These are the correction phase's 51 checks, now on a **fresh** disposable database per run. Every check is
classified:

- **[HTTP]:** asserts on HTTP responses only.
- **[DB]:** an integrity check by SQL on the copy. These are counted separately and never as an HTTP pass.

None was weakened. The changes:

- The raced key's row count moved into the database row check.
- The reversal now also retries under its own key (the same reversal is returned) and tries another key (`409
  already_reversed`). Its audit is then counted **by the transaction's id**: exactly one.
- "Another company's provider" is chosen outside Boutique 5.
- The MFA audit is scoped to this run's administrator.
- "Records kept" compares counts before and after the closure.
- The by-route check covers both directions.
- The TOTP issuer must read Dukan ERP.

**Run `1e4bbd`:**

- **The copy.** A new `mysqldump --single-transaction` of `phonestore` at 0091, read once, was loaded into
  `erp_rh_1e4bbd`. `migrate status` listed 3 pending migrations; `migrate deploy` applied 0092–0094 in 4.2 s; status
  was then up to date. Drift matches the 2026-10-12 baseline (562 known lines), and `prisma validate` passes.
- **Fixtures.** All are generated per run:
  - Boutiques 5 and 6: their owners get a run password (argon2id, by the backend's library), and Boutique 6 gets a test
    number, an address and a city.
  - The administrator `qa-admin-1e4bbd@test.local` is created by the backend's CLI, with a server enrolment token.
  - A random MFA key and pepper.
  - The API is built from backend `33b671c`.
- **Result.** **51 / 51: HTTP 43 / 43, database integrity 8 / 8.** No answer was 500 or above.
- **The 8 DB checks:**
  - one row under each idempotency key;
  - exactly one audit entry for the reversal;
  - the commission immutable for the application user;
  - the MFA secret sealed at rest;
  - this administrator's MFA events audited;
  - no secret or recovery code in the platform audit;
  - nothing personal left after the closure;
  - the closed business's records kept (8 exchanges, 0 sales, the same before and after).
- **Coverage:**
  - the agent lifecycle;
  - the commission typed and paid by the customer;
  - reversal and audit uniqueness;
  - tenant isolation;
  - administrator MFA and step-up;
  - business closure;
  - malformed requests;
  - idempotent retries and a race.

**An earlier attempt, honestly recorded.** Run `da6b3a` answered `500` to the fixture opening Boutique 5's day:
`TRIGGER command denied to user 'phonestore_migrator'`. The PC's triggers are defined by `phonestore_migrator`, whose
rights cover only `phonestore`, so they fail on a copy. The previous phase stripped the definer from its dump; my new
script had not. Nothing was written: the request rolled back and no journey ran. The copy was dropped, the script fixed,
and the complete run repeated from a new copy (`1e4bbd`).

**Also on the migrated copy:**

- The previous API's exchange insert is still refused: `ERROR 3819 … ck_agent_transactions_commission_manual`. Deploy
  the API and 0092–0094 together.
- Permission catalogue: on a further fresh copy (`2b28d6`), 73 / 73 canonical keys are present and the grants are
  complete.

**Teardown.**

- Every API was stopped and every temporary grant revoked; `phonestore_app` is back to `phonestore.*` only.
- Every disposable database was dropped.
- The run files holding test credentials or PC data were deleted.
- `phonestore` stayed at `0091_stabilization` throughout.
- No live database exists, and none was touched.

## 17. The QA scripts and the local copy (2026-10-13)

**Tracked: `erp-backend/scripts/qa-boutiques.ts`** (`8e4a372`, `5bdba80`). The administrator's flow:

- the password;
- the factor the script provisions (derived from the API's `PLATFORM_MFA_KEY`) when the administrator has none;
- its code, or, for an administrator a person enrolled with an authenticator app, one recovery code from
  `QA_ADMIN_RECOVERY_CODE`, spent once and never printed;
- a step-up before each grant.

A person's enrolment is never overwritten: `--apply` refuses and names the server reset. Two defects were found by
running the script end to end for the first time since 0094:

1. **ECONNRESET.** Reading a code back blocks the script for seconds, past the API's keep-alive, so the next request
   went out on a closed socket. This was reproduced with a blocked event loop. Such a request is now sent once more.
2. **`--verify` signed every Owner out everywhere.** It ended with `auth/logout-all` for every Owner, which also signs a
   phone out. It now closes only its own sessions, and so do registration and stocking.

**Results on disposable `prisma_qa_t*` schemas, built from all 93 migrations, empty:**

- `--apply`: 10 boutiques; `--verify` 64 / 64.
- App-enrolled administrator:
  - the dry run reports it;
  - `--verify` stops without a recovery code and passes with one;
  - `--apply` refuses.
- After `platform-admin-mfa.ts enrolment-token`: `--apply` re-provisions, and `--verify` passes 64 / 64.
- A separate "phone" session stays signed in after `--verify`.
- Repeated runs leave the number of open Owner sessions unchanged.
- No password, code or key appears in any output or the API log.

**Local: `local-scripts/boutiques-local.ts`** is outside every repository and was **not edited**: it is the same file
as on 2026-10-05, md5 `66fa0dce…`. The focused patch is `docs/patches/boutiques-local-0094.patch` (+126 / −32). It
brings the copy to the same flow and keyed codes (0093). Its `--verify` used `logout-all` and would have signed the
owner's phone out of every boutique.

The patched file was run through a scratch variant whose only difference is the database guard, against a disposable
copy of the PC data at 0094:

- the dry run says "would be reset";
- `--apply` provisioned the factor and signed in with password and code;
- `--verify` passed 69 checks, with 1 failure from the owner's own data (Boutique 2 sold a phone: 39 of 40);
- a phone session opened first stayed signed in.

**Operator step.** Apply it only once the PC database has 0092–0094 with the matching API:

```
cd C:\wamp64\www\ERP
git -c core.autocrlf=false apply -p1 erp-docs/docs/patches/boutiques-local-0094.patch
```

Then run the script from `erp-backend` as before, with `PLATFORM_MFA_KEY` in `erp-backend/.env`, the API's own key.

One remark, not patched: the copy opens a never-opened day with `decision: 'keep'`, which the server refuses for a
never-counted drawer (D146). This is reached only when a boutique is stocked for the first time.

## 18. Test totals (2026-10-13)

| Suite | Result |
| --- | --- |
| Mobile `tsc` | 0 errors |
| Mobile lint | 0 errors, 29 warnings (the baseline; none in this phase's files) |
| Mobile pure tests | **106 files, 279 / 279** (the identity test included) |
| Mobile render (Jest, two workers) | **15 suites, 188 / 188** (deep links 32 included) |
| EN / FR / AR parity | 3 742 keys × 3, the same order, no duplicates |
| Mobile release bundles and embedded config | identity audit **PASS** (§15.5) |
| Mobile native projects (prebuild, scratch) | package, bundle identifier, name and schemes as §15.5 |
| Expo Doctor | 20 / 21 (patch versions behind — §15.6) |
| Mobile web export and route export | **not run**: Smart App Control blocks `lightningcss` 1.33.0 (*"An Application Control policy has blocked this file"*); the setting was not changed |
| Backend `tsc` | 0 errors |
| Backend Jest | **212 suites, 3 861 passed, 3 skipped** |
| Backend `prisma validate`, `migrate status` (disposable) | valid; up to date after 0092–0094 |
| Permission catalogue (disposable at 0094) | 73 / 73 |
| Backend secret scan | full history clean (2 051 blobs, 321 commits); working tree clean |
| Real HTTP | **51 / 51 (HTTP 43 / 43, DB 8 / 8)** — §16 |
| Website (CI run 38344708273 on `72b1be8`) | typecheck; Vitest **119 / 119** (13 files); production build refused as designed (11 inputs and legal blockers); preview 52 files; links 38 pages, 1 659 links, 0 broken; bundle audit PASS; gitleaks history and dist clean; Playwright **58 / 58** (EN/FR/AR, RTL asserted) |

## 19. Blockers and the next safe step (2026-10-13)

**Blocked on the owner:**

1. **Link an EAS project named `dukan-erp`** (`docs/44`). This blocks every EAS build.
2. **The Apple Developer membership and an App Store Connect record** for `mr.tsxmr.dukanerp`, and a **Google Play app**
   `mr.tsxmr.dukanerp`.
3. **The logo:** choose among the four concepts.
4. **WhatsApp templates** registered at Meta as Dukan ERP (`docs/64`).
5. **`RECORD_AUDIO`** (§15.6).

**Unchanged from §13:** the email provider, `PLATFORM_MFA_KEY` per environment, the backup retention period, and legal
review.

**Not done:**

- **Device verification:** `docs/24` §65 needs a new native build on a physical phone. Nothing is claimed.
- **`tsx-public-site`:** not merged; no authorisation.
