# CURRENT_HANDOFF

Status: IN_PROGRESS
Owner: CLAUDE (local session, the owner's PC)
takeover_2026-10-30T19:33Z: **authorised by the owner in chat.** The owner's brief "Continue Dukan ERP from the
current handoff … finish the outstanding verification, then implement the agreed feedback" (§§2–11) applies.
- The previous holder was CLAUDE (cloud), session_01WqJ1WH6TJWfctbXGjyqFZt. Its last commit is `f78f9b3`, at
  18:49Z. Its block is complete up to its own next_action (read runs 41110129486 and 41110132839), which this session
  continues; the owner was asked to stop it.
- Heads verified at takeover, all clean and level with origin, branch `post-testflight-feedback`:
  - backend `4cf32b3`, mobile `c006f71`, portal `638f1d63`;
  - docs `master` `f78f9b3`.
- `wip/d225-names-illustrations`: backend `cc42c8d`, mobile `8985fe8`. Kept, not deleted.
- **WhatsApp, recorded here:**
  - the production token and app secret are stored on the server as secret files (owner's hidden prompts), unused
    by the API;
  - read-only checks of 2026-10-30: the number is PENDING (not registered) and all 12 template languages PENDING;
  - one registration attempt was refused by Meta (permissions) and changed nothing.
  - Under §10, the registration waits for the restore gate and the owner's authorisation.
phase_feedback2_2026-10-31 (owner brief in chat, claimed by CLAUDE local at the start of the phase; still IN_PROGRESS):
- Heads at claim, all clean and level with origin: backend `4cf32b3` (production, migrations to 0114), mobile `10a260e` (TestFlight 1.0.0 (3)), portal `638f1d63` (dukan-test still serves `7ddeea79`, which has no Arabic name inputs), docs `35b4c2d`.
- Scope: (1) portal bilingual business/store/person forms, field errors, no raw validator text, tests, test-portal deploy via the reviewed workflow; (2) the shared "Discard changes" freeze; (3) localized discard confirmation; (4) remove More → names and More → return policy, names in Business settings / store details, fix the names route's bad query; (5) the mouse-intake anomaly, diagnosed separately; (6) a second platform administrator for medmahmoud@tsxmr.com, only after the mailbox is confirmed; (7) verification.
- Not in scope: any EAS/TestFlight build, App Store upload, enabling push/WhatsApp/email, unrelated production configuration.
- **Checkpoint 2026-10-31 ~22:10Z** (detail and evidence: docs/111 §9; decisions: docs/21 D226):
  - **Mobile** (all pushed, `post-testflight-feedback`):
    - `0d06a14`: the shared unsaved-changes guard; the Discard freeze fixed; one EN/FR/AR wording;
    - `ace5ff7`: names and the return policy in Business settings, More entries removed, `/names` redirects, localized
      server errors;
    - `208b835`: intake trail on Devices;
    - `37fb5d6`: two Linux-only pure-test fixes.
    - Local verification:
      - jest: 58 suites / 502 tests on `ace5ff7`, plus the intake-trail suite (5 tests);
      - pure tests: all pass except the 4 Windows-only;
      - tsc 0, lint 0 errors.
  - **Backend** (pushed):
    - `c178ec6`: business names through the unscoped client;
    - `5131909`: joi 17.13.9 (audit gate).
    - **Production still runs `4cf32b3`.** `c178ec6` is NOT deployed (needs the owner's authorisation).
  - **Console** `cd987227` (pushed): bilingual forms with field messages.
    - Deployed to **dukan-test**: release `20261031T220359Z`, previous `releases/20261029T152528Z`; smoke 16/16; still
      401 without the password.
    - Rollback: `test-sites.sh rollback console 20261029T152528Z --confirm api.tsxmr.com`.
    - Live form not exercised by Claude: it needs the site password, the admin password and MFA.
  - **CI:**
    - console `build-test-sites` 41245654675 success;
    - mobile security on `ace5ff7` failed (fixed in `37fb5d6`); backend security on `c178ec6` failed on the joi audit
      (fixed in `5131909`);
    - **final, all green:**
      - mobile security 41246254928 (`37fb5d6`);
      - render-tests 41246285242 and visual-check 41246294427 (both on `37fb5d6`);
      - backend security 41246194027 (`5131909`);
      - console ci 41245606882 (`cd987227`).
  - **Finding 6, second administrator: NOT STARTED.**
    - The mailbox was not confirmed in this session.
    - `create-platform-admin.ts` has no first-use password flow, and it resets an existing email's password: never run
      it with the current admin's email.
    - Owner to choose (a) a hidden prompt typed by the new admin, or (b) a new setup-code feature (docs/111 §9.5).
  - **Not run here:** small-iPhone and largest-text device checks; the device run of the Discard flows (TestFlight
    later, in one consolidated build).
- **Owner's signed-in end-to-end check, recorded 2026-11-01:**
  - business creation on dukan-test (console `cd987227`): the Arabic inputs appeared and the business saved;
  - production's fifth company, created 2026-10-31 22:33Z.
- **Infrastructure added by the other local session** ("Dukan ERP backup and WhatsApp infrastructure", 2026-10-31
  21:47–22:50Z), recorded here at the owner's request. That session is to write its own detail in docs/112.
  - Hetzner Storage Box with Borg: `erp-offsite-backup.timer`, daily at 02:30Z with up to 10 minutes of random delay.
    It runs `/srv/erp-production/ops/offsite-backup.sh`, root-only and installed outside the repository (docs/112
    §10.3).
  - Retention 7 daily / 4 weekly / 6 monthly.
  - Restore proof `kind=storage-box` at 22:31Z.
  - A healthchecks.io check, `erp-offsite-backup`.
- **Backend `5131909` DEPLOYED to production, 2026-11-01 02:53Z** (owner-authorised; documented backup, deploy, smoke,
  rollback):
  - **Backup before:** `phonestore-20261101T004845Z.sql.gz.age`, 105 543 bytes, sha256 `9c76e9589facbf32…`. Checksum
    OK on the host and in the laptop's `.tsxmr\production-backups\`.
  - **First run, 00:52Z: FAILED at step=secrets.**
    - `setup-secrets.sh` ran `find … -exec chmod 600` over the whole directory and met two root-owned backup files
      (`borg_passphrase`, `healthchecks_ping_url`).
    - The API was untouched (still `4cf32b3`). The FAILED entry is kept in `deployments.log`.
  - **Owner's instruction:** no chown; let the 02:34Z off-site backup run; relocate the two backup-only secrets.
  - **Scheduled off-site run, 02:34:51Z: success in 11 s.**
    - Archive `erp-production-20261101T023454Z`, dump `phonestore-20261101T023452Z`.
    - `borg check --archives-only` OK; the dump inside the archive equals the disk copy and its recorded sha256
      (`4eda099d8c6138f5…`).
    - healthchecks.io: exactly "Started" 02:34 and "OK" 02:35; the check is up.
  - **Relocation:**
    - Both files copied (hash-compared, values never shown) to `/srv/erp-production/ops/secrets/`: directory root:root
      700, files root:root 600.
    - `offsite-backup.sh`: only those two paths changed. The previous copy is kept as
      `offsite-backup.sh.pre-20261101`.
    - **Proof with the new paths:** borg check OK, dump MATCH; one healthchecks `/log` event at 02:51 ("relocation
      proof"), which changes no status.
    - Then the old copies were shredded (`shred -u -z`). No secret was recreated or rotated. The Borg repository,
      schedule and retention are unchanged.
    - The relocated files are no longer inside the Borg archive's `$SECRETS_DIR` path. The Borg key and SSH key were
      never in it either.
  - **Recovery:** `deploy.sh --confirm api.tsxmr.com --after-interrupted` on the clean checkout `5131909`.
    - Identities 23/23; audit chain 5 companies, 0 broken; smoke 15/15.
    - api.env + stack.env unchanged, secret names unchanged; no deploy.inprogress.
    - Rollback target `erp-api:4cf32b3…`.
  - **After:**
    - images `erp-api:5131909…` healthy;
    - 113/113 migrations, 133 tables, 72 triggers;
    - data unchanged (5 companies, 5 users, 5 stores, 1 sale);
    - every protected route 401 without a session, `GET`/`PATCH /business/names` included;
    - channels: PUSH_CHANNEL unset (default disabled), EMAIL/WHATSAPP/WHATSAPP_LIVE_SENDS disabled;
    - off-site timer enabled, next 2026-11-02 02:30Z.
  - **Not proven by Claude:** an Owner-session read and save of business names, since that needs the Owner's sign-in.
    TestFlight 1.0.0 (3)'s More → "Business and store names" calls exactly these routes.
- **Tooling fix, separate branch `ops/setup-secrets-scope`:** `7ef1a07` (spec corrected in `58829cc`).
  - `setup-secrets.sh` manages only its named application secrets.
  - Regression spec: an unrelated mode-000 file is neither read nor changed.
  - Not merged into `post-testflight-feedback` and not on the host. The host deploys `5131909` unchanged; the
    relocation removed the foreign files the old tool tripped on.
- **Platform-administrator invitation, owner-approved 2026-11-01** (0115, a 24-hour code, private handover through a
  server file; detail in docs/111 §10):
  - **Built:** backend `02b40e5` (security CI 41268764282 green, real-MySQL gates through 0115); console `9b56870d`.
  - **Rehearsed** on a disposable copy of the production schema:
    - the existing admin stays active and its row and session are identical;
    - every CHECK refuses what it must;
    - the upgraded table equals the fresh one;
    - the reverse is clean;
    - everything was dropped and deleted afterwards.
  - **NOT deployed, no account created, no code issued.**
  - **Gates still open:**
    - `medmahmoud@tsxmr.com` forwarding exclusively to `behlibade@gmail.com`;
    - the destination verified;
    - a harmless test message delivered;
    - then the 0115 deployment (with its backup) and the console release.
  - Operator steps: docs/111 §10.3.
  - **RELEASED 2026-11-01** (owner-authorised after confirming the forwarding check):
    - **Owner check:** medmahmoud@tsxmr.com forwards only to the verified behlibade@gmail.com; a harmless test message
      was delivered.
    - **Backup:** `phonestore-20261101T035302Z.sql.gz.age`, 105 700 bytes, sha256 `542c02540c4d8acf…`, OK on the host
      and the laptop.
    - **Backend `02b40e5` deployed 03:55Z:**
      - 0115 applied 03:55:38Z (114/114), both CHECKs live;
      - identities 23/23; audit chain 5 companies, 0 broken; smoke 15/15;
      - api.env + stack.env unchanged, secret names unchanged;
      - data unchanged; channels unchanged (PUSH unset, EMAIL/WHATSAPP/LIVE_SENDS disabled);
      - `POST /platform/admin/setup` answers an unknown address with the generic `admin_setup_refused`;
      - rollback target `erp-api:5131909…`.
    - **Existing administrator:** row, 10 sessions (1 live) and recovery-code fingerprints identical before and after
      (`fa4ba085…`, `f5fd6cab…`, `c29094ce…`); state `active`.
    - **Console `9b56870d`:**
      - build-test-sites run 41271122708; 28 files verified; 27 identical on both ends;
      - installed on dukan-test as release `20261101T040124Z` (previous `20261031T220359Z`); smoke 16/16; 401
        without the password.
    - **`/admin/setup` checked** on the byte-identical built files, served locally (dukan-test is behind the owner's
      password):
      - EN, FR and AR (rtl, with the email and code fields ltr) correct;
      - the form's own checks shown in AR, and no request sent.
    - **Invitation issued 04:03:21Z** for medmahmoud@tsxmr.com by `admin-invitation.sh invite`:
      - admin id `01a19546b507733c9212e83c99090208`, state `invited`, code valid until 2026-11-02T04:03:21Z;
      - handover file `/srv/erp-production/admin-invitations/01a19546b507733c9212e83c99090208.code` (600; directory
        700), never read or shown by Claude;
      - sweep timer `erp-admin-invitation-sweep` running.
    - **Next (owner):**
      1. read the file in their own SSH session;
      2. pass the code privately;
      3. run `deploy/production/admin-invitation.sh delete`;
      4. Mahmoud completes `/admin/setup` on the console origin, then enrols his authenticator.
    - **Gap found:** in the dark theme the console's field-error text (`.field-error`, from `cd987227`) is nearly
      invisible, dark red on dark. Cosmetic and accessibility; fix in a later console release.
- **Production backup secrets:** `borg_passphrase` and `healthchecks_ping_url` are in `/srv/erp-production/ops/secrets`
  (root:root 700/600), separated from the application secrets. `5131909` was deployed without the
  `ops/setup-secrets-scope` tooling branch, which stays unmerged until reviewed (CI green on `58829cc`).
checkpoint_2026-10-30T21Z (CLAUDE local; usage limit reached, work paused, still IN_PROGRESS):
- The cloud session was stopped by the owner after it pushed mobile 9b018c6. Mobile 9ff6fe8: dark is the default (D226), pushed.
- Docs: docs/111 §8.1–8.4 (visual-check 41114111688 findings, crash evidence, the auto-approve and balance-tracking proposals awaiting the owner); docs/112 off-site backups approved (VM restore, healthchecks.io), nothing run yet.
- **UNCOMMITTED in erp-mobile** (not yet tested; npm ci was running): the intake crash fix — app/receive.tsx opens the product form with intake=quick and no longer takes a draft back; app/catalog/new.tsx without handBack/forDelivery; __tests__/single-item-intake.test.tsx (the delivery case now expects one purchase with cost). lib/scan/pending-intake(.test).ts show only as line-ending changes: restore them with git checkout before committing.
- Next: run npx jest __tests__/single-item-intake.test.tsx and tsc; commit; retarget ops/render-tests and ops/visual-check; then section 4 (monitoring research), section 5 (transfers), and the owner answers for docs/111 §8.3, §8.4 and the docs/112 steps.
mobile_release_build3_2026-10-31 (owner-authorised in chat: sign, build and upload 1.0.0 (3) to the existing private TestFlight; free, reversible, limited to this app/team/project): **UPLOADED, PROCESSED, IN INTERNAL TESTFLIGHT.**
- Signing changes (Apple Developer, Team 5B9T8L263K): Push Notifications enabled on App ID mr.tsxmr.dukanerp (W5Q7DCW6AJ); no other capability changed (In-App Purchase was already on). App Store profile 39U253369F regenerated in place with the SAME distribution certificate (serial 60064D07EC327251ABC3642D89A0D898, to 2027-10-29): new UUID b43004f1-dbf3-4a2d-b77d-a3336e9f5d49, aps-environment production, created 2026-10-31T04:53:53Z. Uploaded to EAS's iOS credentials (replaces UUID 2566ffc9…); status Valid. **No APNs key created** (not needed to sign; server push stays disabled). No certificate revoked or created.
- EAS build **`3d049bfb-75b9-4dc1-9056-dc862128c2e6`**: commit `10a260e`, production, eas-cli 27.2.0, SDK 58, **1.0.0 (3)** (remote buildNumber 2→3), FINISHED 05:06:19Z.
- Archive audit: IPA 24 444 744 bytes, sha256 `6a8c8279d9a432d1ea450ce4416cae3bd62279f45808f78e3b554eedd29a1216`. Info.plist: mr.tsxmr.dukanerp, 1.0.0 / 3, "Dukan ERP", UIDeviceFamily [1] (iPhone only), ITSAppUsesNonExemptEncryption false, ATS arbitrary loads false, schemes dukanerp + mr.tsxmr.dukanerp, iOS 16.4. Entitlements: application-identifier 5B9T8L263K.mr.tsxmr.dukanerp, aps-environment production, beta-reports-active, team 5B9T8L263K, get-task-allow false (vs build 1: only aps-environment added). Embedded profile b43004f1…, cert serial 60064D07…D898. No source maps, no key/env files. Hermes bundle origins: https://api.tsxmr.com ×1, https://tsxmr.com ×1, nothing else ours; remaining hosts are library defaults/docs (localhost:8081 expo bundle origin, localhost:3000 expo-router head fallback, exp.host), plus `api-origin-refused.invalid` (constants/config.ts refusal sentinel); "EAA…" hit is base64 padding. No EXPO_PUBLIC names, no dev-client. App icons byte-identical to build 1.
- Encryption: build 1 declared "App Uses Non-Exempt Encryption: No" (from app.json `usesNonExemptEncryption: false`); since 2bf0a57 only expo-notifications was added — answer unchanged, applied by the same Info.plist key (no question asked).
- Upload: `eas submit` (stored ASC API key JX8F93PNAL) submission `294c3c94-adb2-4ba9-8894-c8f13b21d7e8`, uploaded 05:13Z. eas.json has no ascAppId: it was set to 6828500958 in the working tree for this one command and restored (`git checkout -- eas.json`; tree clean). Follow-up: commit `submit.production.ios.ascAppId` in a later change.
- App Store Connect: 1.0.0 (3) Binary State **Validated**, TestFlight "Ready to Submit" (external-review state only), in existing internal group **Team (Expo)** (1 tester) automatically. Internal only → no Beta App Review needed; none submitted. No public link, no external group, no testers added, no App Store submission. No agreement prompt appeared.
- Production at the end: backend `4cf32b3` (built 01:22:25Z), ready, 113/113 migrations. Nothing on the server touched; PUSH_CHANNEL unset (disabled), email and WhatsApp disabled.
- Deferred: APNs key + server push enablement (owner decision); ascAppId in eas.json; audit-bundle origin follow-up; owner to run `Stop-Service ssh-agent` (elevated).

mobile_release_attempt_2026-10-31 (superseded by build 3 above): **STOPPED at a signing-credential decision. Nothing uploaded to App Store Connect.**
- Gate 7, physical-device evidence (owner, iPhone, TestFlight 1.0.0 (1) against production 4cf32b3): session kept; Home, Stock, Money, More, Team load; a stock item opens; a Sale search found an item (cancelled); Receive search/scan opens (cancelled); notifications and a linked record open; no 400/404, no endless loading, no forced logout, no crash.
- Production before the build: /api/health/version commit 4cf32b3 (built 01:22:25Z), ready, 113/113 migrations.
- Release candidate **`10a260e`** = `f9356ff` + one type-only fix (`app/notification-open.tsx`: `router.replace(route as Href)`). tsc had passed on a stale generated `.expo/types/router.d.ts`; regenerated, it failed only there. No runtime change.
- Gates on `10a260e`: render-tests 41157946897 (exit 0, pure 139/139, jest 55/55 · 470/470, web+iOS export, audit-bundle, shipped-deps, web smoke 0); visual-check 41157955778 (821/821 chromium and webkit, brand 44/44 ×2, access-journey 21/21, ui-input 245/245); security 41157924372 success; local tsc 0, lint 0 errors (38 warnings), verify-release-config sound (https://api.tsxmr.com). EAS production env: only EXPO_PUBLIC_API_ORIGIN=https://api.tsxmr.com, EXPO_PUBLIC_LEGAL_ORIGIN=https://tsxmr.com. Production-origin iOS export: no source map, no sourceMappingURL; real origins only api.tsxmr.com and tsxmr.com; the rest library docs/defaults (localhost:8081/3000, dead fallback localhost:3010, exp.host = expo-notifications token endpoint); one "EAA…" heuristic hit is base64 table data. Note: audit-bundle.js with the REAL API origin reports "website address" (api.tsxmr.com matches its tsxmr.com rule; it strips only the legal origin) — the documented/CI usage is a placeholder API origin, which passes. Tooling follow-up: let the audit also strip the configured API origin.
- Identity unchanged vs 2bf0a57: Dukan ERP 1.0.0, mr.tsxmr.dukanerp, iPhone only, owner salah_rim, project 86a08e0d-…, icon/splash/eas.json identical.
- **EAS build `736d9813-36c8-454a-957d-e57df16c5855`** (eas-cli 27.2.0, production, store, SDK 58, commit 10a260e, 1.0.0 (2)): **ERRORED** at Xcode signing: the profile "*[expo] mr.tsxmr.dukanerp AppStore 2026-10-29T16:06:59Z" (Developer Portal ID 39U253369F, Team 5B9T8L263K, cert serial 60064D07…D898, both to 2027-10-29) lacks the Push Notifications capability and `aps-environment`, which app.json's expo-notifications plugin (`enableRemoteNotifications: true`, added in D225) requires. No artefact; nothing submitted.
- The remote build number is now **2** (consumed by the failed build). The next build becomes 3 unless reset with `eas build:version:set` (owner's choice; App Store Connect has only build 1).
- **Owner decision needed:** (a) enable Push Notifications on App ID mr.tsxmr.dukanerp and let EAS regenerate the App Store profile (interactive `eas build`/`eas credentials`; it may also offer an APNs key — creating one is not required to sign; PUSH_CHANNEL stays disabled server-side), then rebuild 10a260e; or (b) a build without the remote-notification entitlement (`enableRemoteNotifications: false`), which is a code change and leaves push unusable until a later build.

backend_release_2026-10-31 (owner-authorised in chat: "Yes, deploy backend 4cf32b3", with gates 1–9): **DEPLOYED. Mobile build NOT started (gate 7 needs the owner).**
- Gate 1, before: production at `ce23e99`, 108 migrations, last 0109, 0 unfinished, 0 rolled back, none above 0109; no deploy.inprogress.
- Gate 2, backups: `phonestore-20261031T011226Z.sql.gz.age` (96 619 bytes, sha256 `cfd2512cd900d94a…`), checksum OK on the host AND in the laptop's `.tsxmr\production-backups\` (copied by scp, verified with Get-FileHash). deploy.sh's own pre-migration backup: `phonestore-20261031T012449Z.sql.gz.age` (host only).
- Gate 3, released app 1.0.0 (1) vs 4cf32b3: the backend suite on 4cf32b3 locally 5 238 passed, 4 failed only from the Windows checkout (CRLF shebang / `\n` regexes / backslash paths; 5 242 green on Linux before), including "keeps accepting the one name build 1.0.0 (1) sends"; CI security success on 4cf32b3; schema rehearsal 0109→0114 additive (docs/111 §7.7); source audit: no response key removed, the one changed link `/closing?date=…` passes 2bf0a57's internalRoute. After deployment, a registration shaped exactly as 1.0.0 (1) sends it was refused only for its deliberately short password (no unknown-field error), nothing created.
- Gate 4–5, deployment: bundle sha256 `991ffbdfd83ee689…`, checkout detached at `4cf32b3`; deploy.sh: contract PASS, preflight PASS, migrations 0110–0114 applied (01:24:54–01:24:56Z), identities 23/23, audit hash chain 4 companies / 0 broken. Deployed image `erp-api:4cf32b3…`, tools `erp-api-tools:4cf32b3…`. **Rollback image: `erp-api:ce23e99b287e6ceb2a252cbe66df1aa743721580`** (code rollback is safe: 0110–0114 are additive; a data rollback is restoring `phonestore-20261031T011226Z`). api.env + stack.env fingerprint unchanged; secret names unchanged.
- Gate 6, after: smoke 15/15 (commit 4cf32b3644c2); readiness 113/113, 0 pending; tables 133, triggers 72; companies 4 (test 1,1,1,0), users 4, stores 4, sales 1, subscriptions unchanged; Arabic names written 0; new tables empty; audit_logs/platform audit triggers present (no update/delete); PUSH_CHANNEL unset (default disabled), EMAIL/WHATSAPP/WHATSAPP_LIVE_SENDS disabled; the D225 routes now 401 (were 404). Tenant isolation at the API with signed-in sessions was NOT exercised (needs tenant credentials, which Claude does not handle); covered by the identity checks, audit chain and the suite's isolation specs.
- Gate 7, **owner, tomorrow:** use TestFlight 1.0.0 (1) against production (sign in, sale/receive screens, team, a notification). Only then the mobile build.
- Gate 8, mobile `f9356ff` ready: render-tests 41148347149 green; visual-check 41150964457 (tooling `d55c3fa`) 821/821 chromium and webkit, brand 44/44 ×2, access-journey 21/21, ui-input 245/245; CI security success. Still to run at build time: release-config check, bundle origin check (https://api.tsxmr.com, legal https://tsxmr.com), archive audit; then EAS build (iOS build number auto-increment, version unchanged).
- Gate 9: `ssh-add -D` done (agent holds no identities). Stopping the ssh-agent service needs the owner's elevated PowerShell: `Stop-Service ssh-agent`.

release_attempt_2026-10-31 (owner-authorised TestFlight build, gated on compatibility with the DEPLOYED API): **STOPPED before any build. No EAS build, no upload, no build-number change.**
- Candidate: mobile `f9356ff` (post-testflight-feedback head, nothing newer). render-tests run 41148347149 on it: exit 0, pure 139/139, jest 55/55 suites (470/470), web and iOS exports, bundle and shipped-deps audits, web smoke all 0.
- visual-check on be32092 (41145507038): 818/821 per engine; the 3 theme failures and 4 New-team-member failures were stale tooling (D226 dark default; D225 Arabic-name field shifted the field indexes). Fixed on ops/visual-check `d55c3fa`, which reruns on `f9356ff`; its result was not yet in at this checkpoint. expo-doctor's SDK patch mismatch is unchanged since the released `2bf0a57`.
- **Blocker, proven:** production runs backend `ce23e99` (migrations to 0109) with `forbidNonWhitelisted: true`. Unauthenticated probes of https://api.tsxmr.com/api/v1: `/auth/branches` and `/notifications` 401 (exist); `/acting-owner`, `/business/names`, `/notifications/preferences`, `/notifications/devices`, `/notifications/:id/open`, `/users/:id/role` **404** (absent). The mobile head needs them:
  1. registration always sends `ownerNameAr`, `businessNameAr`, `branchNameAr` (`lib/registration.ts` buildRegistrationBody); ce23e99's register DTO has none, so every new registration would be refused 400;
  2. team: creating or editing a person sends `nameAr` (`app/team.tsx`), refused 400 by ce23e99;
  3. Names screen (`/business/names`, `/branches/:id/names`), Acting Owner (`/acting-owner*`), notification preferences and read-all, notification open (`/notifications/:id/open`), push device registration (`/notifications/devices`), role change (`PUT /users/:id/role`): all 404;
  4. these need backend 4cf32b3 and migrations 0110–0114, which were not authorised.
- Options for the owner tomorrow: (a) authorise the backend 4cf32b3 deployment with 0110–0114 (backup, rehearsal already green), then build `f9356ff`; (b) a compatibility layer in the app (send `*Ar` only when the server advertises it, hide the D225 screens on 404) — new work, not done; (c) no build until (a).
- Open product item: an authorised user's transfer is created *approved*, then sent from the next screen; no auto-send. The destination is never marked received by the source's approval or send.

checkpoint_2026-10-31 (CLAUDE local, still IN_PROGRESS; supersedes the UNCOMMITTED note above, which was committed as mobile `be32092`):
- Mobile heads, all pushed on `post-testflight-feedback`:
  - `be32092`: the intake crash fix (one purchase with its cost from both Receive screens; no hand-back);
  - `7d88f02`: §5 transfer page (route card, one add control by name/IMEI/serial/barcode plus scan, selected list with illustration and masked number, sticky "Review transfer (n)", review step; FR "boutique"; no *#06#; approval wording never claims receipt). The server still creates an authorised user's transfer as *approved*, not sent: the copy says "send it from the next screen". Auto-send on create is a backend follow-up, not done;
  - `f9356ff`: `lib/receive-outcome.test.ts` now guards the absence of the hand-back.
- render-tests 41145498717 on `be32092` failed: field-focus-ring (it assumed the light palette; now reads `DEFAULT_THEME`, fixed in `7d88f02`) and receive-outcome (fixed in `f9356ff`). Exports, audits and web smoke passed. Local: jest 55/55 suites; pure tests all pass except 4 that fail on Windows path handling only (access-boundary, sheet-input, web-accessibility, zoned-time), all green in CI.
- Tooling retargeted to mobile `f9356ff`: ops/render-tests `2c78f10`, ops/visual-check `39858a6`. The visual-check run on `6e91e98` left no evidence commit; read the new run.
- Not done: §4 monitoring research (web search was rate-limited), §6/§8 (await the owner's choices in docs/111 §8.3–8.4), §9 (awaits the owner's sub-account and fingerprint), D226 entry in docs/21, physical-device check of the transfer page (small screen, large text, RTL).
previous_holder_claim: CLAUDE (cloud), started_at_utc 2026-10-29T18:50Z (that claim written before any change)
takeover: **authorised by the owner's brief of 2026-10-29** ("continuing Dukan ERP after its first successful TestFlight
release … claim the shared handoff"). The previous holder, CLAUDE (local session, the owner's PC, new account), still
showed IN_PROGRESS for the pilot release. Its last recorded step was the build's submission to App Store Connect
(`96cf01d`, `docs/110` §2). The release work it describes is complete, but the block was never formally released.
That session's working tree is on the owner's PC and cannot be inspected from here. Every remote head below was
checked, and none moved after `96cf01d`.
heads_at_takeover (the reviewed TestFlight lineage):
- erp-mobile `browser-input-setup-code` = `deferred-verification` **`2bf0a57`**: the TestFlight build b1308200, 1.0.0 (1);
- erp-backend `superadmin-provisioning` = `deferred-verification` **`ce23e99`**: production api.tsxmr.com, 0109;
- erp-control-web `browser-input-setup-code` = `deferred-verification` **`7ddeea79`**: the deployed console;
- erp-docs `master` **`96cf01d`**.
active_phase (the owner's brief of 2026-10-29, decision **D225**): the post-TestFlight feedback phase, on new branches
`post-testflight-feedback` cut from the heads above. Scope:
- untruncated decision dialogs;
- an Arabic quality and RTL pass, with تطبيق دكان;
- bilingual names for businesses, stores and people;
- calendar weeks (Monday to Sunday, `Africa/Nouakchott`);
- category illustrations;
- permission explanations;
- the notification system (three levels, a localized centre, push, deep links);
- Employee/Manager promotion and demotion;
- the temporary Acting Owner.

**Not in this phase:** a deployment, a persistent-database migration, a DNS/server/secret/EAS/Apple change, `eas
build`, a TestFlight build, a merge into release branches, a rebase or force-push.
continuation (the owner's brief of 2026-10-30, still D225, same branches, written before any change):
- **Owner decisions:**
  1. The week keeps the 06:00 business-day cutoff: "This week" runs Monday 06:00 to the next Monday 05:59:59.999,
     `Africa/Nouakchott`.
  2. Native push is required in the eventual consolidated release.
  3. No TestFlight build in this phase.
- Remote heads confirmed at 2026-10-30, unchanged since the previous refresh: erp-backend **`a13031d`**, erp-mobile
  **`8d83b23`**, erp-control-web **`638f1d6`** (console CI run 40981629622: **success**), erp-docs **`c80f1e7`**.
- Scope of the continuation:
  - native push (expo-notifications, the iOS entitlement through the Expo config, registration, rotation,
    unregister), a pre-permission after sign-in and one approved Settings helper;
  - typed, re-authorised deep links;
  - localized titles **and** bodies in EN/FR/AR;
  - bilingual names on every remaining surface, plus a `.name` audit;
  - illustrations on every remaining surface;
  - Acting Owner step-up through the existing secure mechanism, with a permission-to-test matrix;
  - Employee/Manager re-confirmation;
  - the 06:00 week tests;
  - a full 0109 → 0113 rehearsal;
  - every gate; docs.
- Still forbidden: deploy, persistent migration, merge into release branches, rebase/force-push, `eas build`, a build
  number, TestFlight, App Store Connect, Meta/WhatsApp configuration, enabling `PUSH_CHANNEL`.
state (2026-10-30 ~18:50Z; every working tree clean and pushed):
- **erp-backend `post-testflight-feedback` `4cf32b3`**:
  - everything before, plus bilingual names on every remaining API surface and the `.name` audit spec;
  - full unit suite 5 242 passed; secret scan clean.
- **erp-mobile `post-testflight-feedback` `c006f71`**:
  - everything before, plus illustrations on every product surface (`e4e666a`);
  - names in the reader's script on every screen, with the app audit (`0569bc3`);
  - Arabic report headers (`c006f71`);
  - tsc, lint (38/40 warnings), the pure suite and 462 rendered tests pass.
- **erp-control-web `638f1d6`**: unchanged, CI success.
- **`wip/d225-names-illustrations`** (backend `cc42c8d`, mobile `8985fe8`): superseded. Its work is finished on the
  feature branch; delete it once the owner agrees.
- **Visual workflows**, retargeted to these heads and running at writing:
  - `ops/visual-check` `ccd91dd` (run 41110129486, Chromium and WebKit; the seed now sends the Arabic names);
  - `ops/render-tests` `f9df297` (run 41110132839).
migrations: 0110–0114, none applied to any persistent database; rehearsal 0109 → 0114 green (docs/111 §7.7).
not deployed: no deploy, persistent migration, merge, EAS build, build number, TestFlight, App Store Connect,
Meta/WhatsApp or `PUSH_CHANNEL` change.
next_action, exactly:
1. Read runs 41110129486 (visual-check) and 41110132839 (render-tests).
   - If red, fix on `post-testflight-feedback` (or the seed or checks on the ops branch), then retarget and re-run.
   - Expect registration and team steps may need the Arabic name fields, which D225 made required.
2. When both are green, record them in docs/111 §7.9 and set READY_FOR_HANDOFF. The trees are already clean.
3. Release-time gate (owner authorisation): APNs key on the EAS iOS credentials with the first entitlement build,
   `PUSH_CHANNEL=expo`, then the physical-iPhone checklist (docs/111 §5 and §7.9).
Stays IN_PROGRESS until every implementable gap is closed and every gate passes.

Previous state (the pilot release; unchanged below):
Status: IN_PROGRESS
Owner: CLAUDE (local session, the owner's PC), new account
takeover_2026-10-29: **authorised by the owner** (brief "Dukan ERP real-store pilot and TestFlight continuation"). The
previous holder, CLAUDE on another account, stopped when its usage ran out. Its handoff was a deliberate pause: complete,
with `NEXT_SESSION_PROMPT.md` and one known uncommitted mobile change.
- **Verified at takeover against Git and CI:**
  - backend `deferred-verification` `ca5c099`: 19 linear commits on `f5da650`, containing `promoter-attribution`
    `002e7f8` and `inventory-general` `5370460`; migrations 0103–0109; security run 40865900480 success on that exact
    SHA;
  - console `deferred-verification` `7ddeea79`: contains `bc112bda`; CI run 40870764729 success on that exact SHA;
  - mobile `deferred-verification` `d26da94`: contains `6dd3213`, `927fc11` and `c369e5d`;
  - `claude/audit-fixes`, `claude/qa-boutique-seed` and `claude/stock-finds-products` are in no release line. The
    four backend and one mobile `audit-fixes` commits whose patches appear were already in production (`f5da650`,
    `9e0b38b`);
  - erp-docs `master` `21d3d057`.
- **The uncommitted mobile work was exactly as described:**
  - `eas.json` staged and byte-identical to its form before `c369e5d`;
  - the awaited `fireEvent`s, with `fillFields` already async;
  - six mechanical `await await fillForm()` were reduced to `await`.
- Committed as mobile **`2bf0a57`** (pushed). Locally: tsc clean; promo-code + invite 15/15; lint 0 errors (34
  warnings); release config sound with the EAS production origins; pure tests 375/382, the 7 failures in the 4
  Windows-only files.
- This takeover record was written right after that commit, not before it.
- **Incident:** a retarget push with an empty commit ID briefly **deleted** the remote tooling branches
  `ops/render-tests` and `ops/visual-check`. Both were restored within a minute at their exact commits (`c1955bf`,
  `925bf24`). The resulting red render-tests run 40880126198 is that restore's stale re-run.

progress_2026-10-29 (this account; production still untouched at 0102):
- **Mobile `2bf0a57`:**
  - security CI 40879962980 success;
  - render-tests 40880200841: pure 128/128 files, rendered 43/43 suites and **408/408** tests, iOS and web exports,
    bundle audits, web smoke.
- **§5 customer activation:** backend `2db5a8d` adds `scripts/d224-activation-journeys.mjs`. Seed **10/10**, open
  **32/32**:
  - public registration 503 with nothing saved;
  - pending customers and every existing subscription unchanged;
  - 401, `step_up_required` and the password-confirmation refusals;
  - create, Owner invitation, payment, approval and period for an ordinary customer;
  - all audited.
- **§4 deferral** re-run on the release code: **43/43** with the switch on, **4/4** off.
- **§10 rollback:** tested against `f5da650` and `644f4f5` on a 0109 database holding every post-migration row
  (`docs/100` §18). Each fails 4 of the requests, all on unknown (NULL) cost. Backend **`ce23e99`**: `rollback.sh`
  refuses a pre-0107 target while any cost is unknown, and a spec pins it. Backend security CI success on
  `2db5a8d` (40882617151) and `ce23e99` (40888573059).
- **§6 brand gate:** `verify/brand.mjs` on `ops/visual-check`, **44/44** locally in Chromium and WebKit.
- **Visual check on `2bf0a57`: 812/818.** The 6 failures were the verifier's stale input count, since the D221 promo
  boxes; reproduced, the app is correct. Corrected in `c57f166`, re-running.
- `ops/verify-provisioning` was retargeted to the release heads (`c15d364d`) for the backend + console + app run.

deployed_2026-10-29 (`docs/100` §18.1):
- **Production API:** backend `ce23e99`, 0103→0109 (108). `CUSTOMER_ACTIVATION=open`,
  `PHONE_VERIFICATION_DEFERRAL=on`; email and WhatsApp disabled.
- **Console:** dukan-test release `20261029T152528Z` (`7ddeea79`).
- **Rollback points:**
  - database `phonestore-20261029T151837Z` (laptop copy restored, PASSED) and `phonestore-20261029T152338Z`;
  - code `f5da650`, only while no cost is unknown (`rollback.sh` enforces it);
  - console `20261025T084934Z`.
- **Integration (fast-forward):** backend `superadmin-provisioning` = `ce23e99`; console and app
  `browser-input-setup-code` = `7ddeea79` / `2bf0a57`.
- **Every gate green** (§18.1). tsxmr.com is unchanged; verify-production 23/25, only the sitemap's `<lastmod>`
  differs, as documented.
next_action: **the owner** creates the real business, Owner, Manager and Employee (and later the App Review account)
in the portal, checks the deferral option there, and reports back. Then the EAS iPhone build and internal TestFlight
(`docs/110`).
started_at_utc (previous holder): 2026-10-27T19:11Z (this claim written before any change)
claimed_from: READY_FOR_HANDOFF (owner NONE) at `222edc1`; that handoff was complete.
heads_at_claim: erp-backend `inventory-general` `12fcaad`; erp-mobile `inventory-general` `985f995` (checkout on
`sdk-58` `fca75c5`); erp-docs `master` `222edc1`.
active_phase (the owner's request, 2026-10-27): **D223 physical-phone QA on a disposable environment.** Backend `12fcaad`
as a LAN API on port 3999 against a disposable MySQL database `erp_inv_e2e` (3308, migrations through 0106), seeded
with one fictional business and fictional inventory; Metro on port 8082 serving erp-mobile `985f995` to the owner's
Expo Go, pointed at that API. **No production, no erp-test, no merge, no deploy.** The owner's observations are
recorded here; nothing is merged on them without approval. When the owner says testing is finished: drop
`erp_inv_e2e`, delete the generated credentials, stop the API and Metro.
environment_ready_2026-10-27T19:23Z: `erp_inv_e2e` migrated through 0106 (none pending); one fictional business
(Owner, Store Manager, Employee; generated passwords in the session scratchpad, never in a repository); the day opened
with a fictional drawer; 4 fictional products (a phone with 2 test IMEIs, a laptop with 2 serials, a charger x15,
earbuds x8). API `12fcaad` on 0.0.0.0:3999. Metro on 8082 serving `985f995` (`EXPO_PUBLIC_API_ORIGIN` =
the PC's LAN address, port 3999; `EXPO_PUBLIC_APP_ENV=staging`); the iOS bundle was fetched and holds the D223-only
keys and no production origin.
device_qa_2026-10-28 (the owner's iPhone, `985f995` on `12fcaad`): **blocking defects**, now being corrected on the same
feature branches (the owner's brief of 2026-10-28; the claim stays IN_PROGRESS):
- **Freeze, root cause PROVEN by a temporary trace build (Metro only, reverted, never committed):** JS stayed alive and
  every tap reached the JS root. New product's hand-back cleared its own `submitting` flag in `finally` BEFORE
  `router.back()`, so `ProductForm`'s `usePreventRemove(dirty && !submitting)` intercepted the screen's own successful
  exit. On iOS the native stack popped visually while navigation stayed on `/catalog/new`; the "discard changes?"
  confirm was presented as a transparent full-screen Modal that never drew, and swallowed every touch
  (`dialogs: 1` for ever, route never returned to `/quick-receive`).
- **Restored-draft card:** Quick receive's draft always holds a request key and a payment method, so every visit writes a
  draft and the next visit says "Restored" even when nothing was typed. Unrelated to the hand-back.
- Also: no category required; the phone catalogue offered under any category (all 371 catalogue models are phones);
  Storage/Colour shown for every category; Selling price in the intake form; "Receive a phone".
- **Owner decision 2026-10-28: full unknown cost** (migration 0107, nullable cost; profit/margin incomplete, never
  zero; audited Owner/Manager cost entry later, never rewriting a sale).
corrections_2026-10-28 (same branches; nothing merged, deployed or migrated outside disposable databases):
- erp-backend `inventory-general` **`0e11165`** (`4a8fc6d` + journeys): migration **0107_unknown_cost** (cost nullable on
  units/stock_items/purchase_items/stock_receipts/sale_items/return_reversals; `stock_items.missing_cost_quantity`;
  `daily_rollups.missing_cost_lines`; `cost.complete` to owner + store_manager). Purchases take an optional cost
  (absent = unknown, nothing paid); sales sell it at NULL cost, below-cost checks only where cost is known,
  `knownMargin`; closing report counts NULL as missing; rollups, period figures, dashboard, product/category profit and
  valuation over known costs with disclosure; `POST units/:id/cost` and `POST purchase-items/:id/cost` (audited, no
  money moved, open-day sale completed with its price untouched, closed day left as frozen); transfers and purchase
  cancellations refuse unknown-cost stock (`cost_missing`); categories carry `allowedTrackingTypes`; the device
  catalogue answers only for the Phones family (`catalogueCovers`).
- erp-mobile `inventory-general` **`48e0d9b`** (app code as `cef66aa`; later commits are tests): New product from Quick
  receive is the single-item intake — category first, product, stock details, optional buying cost, payment, ONE
  "Create product and add to stock" purchase; `allowLeaveRef` lets deliberate exits through the unsaved-changes guard
  (the freeze), one confirm at a time; the category decides the form (allowed modes, phone catalogue only under
  Phones, category attributes only, change clears); no selling price in any intake; the missing-cost dialog (Add
  buying cost / Continue without cost / Cancel, EN/FR/AR as agreed); Quick receive drafts only typed work (no false
  "Restored"); "Buying cost missing" in Stock with Add buying cost for cost.complete holders; analytics says when
  profit is incomplete; "Receive an item"; a malformed attributes answer falls back instead of crashing the form.
- Verification:
  - backend: TypeScript clean; Jest 5,000 passed with 4 Windows-only failures in untouched files;
    `unknown-cost.spec.ts` 19/19;
  - security CI: success on `4a8fc6d` (40696617411) and `0e11165` (40697591157);
  - real MySQL (`erp_inv_e2e` at 0107): the 25 D223 journeys pass, and **26/26** unknown-cost journeys
    (`scripts/d223-unknown-cost-journeys.mjs`);
  - mobile: TypeScript clean; pure tests pass apart from the 4 that fail identically at `985f995` on Windows;
  - render-tests run 40705453294 on `48e0d9b`: pure 125/125, rendered **381/381** (17 new intake cases), both
    exports, both bundle audits, web smoke;
  - mobile security CI on `48e0d9b`: success, run 40705435919;
  - visual-check on `374e9ef` (app code identical to `48e0d9b`): run 40704115462: 818/818 Chromium and WebKit, access journey 21/21, input 245/245.
- Disposable environment for the retest (running):
  - **database:** `erp_inv_e2e` reset at `0e11165`, migrations through 0107, nothing pending;
  - **seed:** four fictional businesses (D223 Fictional Electronics and QA Stores 1–3, each with an Owner, a
    Manager and an Employee and fictional stock), with new generated passwords in the session scratchpad, never in a
    repository;
  - **API:** `0e11165` on 0.0.0.0:3999;
  - **Metro:** on 8082 serving `48e0d9b`. Its iOS bundle was fetched: it holds only the LAN test API, no
    `api.tsxmr.com`, the corrected intake code, and no selling-price strings.
- Not rehearsed separately: 0107 on a database already holding data at 0106 (statements are `MODIFY … NULL`,
  `ADD COLUMN … DEFAULT 0` and guarded inserts).
device_qa_2_2026-10-28 (the owner's second iPhone pass, `48e0d9b` on `0e11165`): the unknown cost, category filtering,
single-item intake and navigation fix were kept. Four defects:
- the Sale scanner said "already in inventory" for the phone being sold;
- a staff-allowance banner on More;
- a policy card on Review sale;
- a receipt with no customer and only a generic final-sale line.
corrections_2_2026-10-28 (same branches; nothing merged, deployed or migrated outside disposable databases):
- erp-backend `inventory-general` **`5370460`**: migration **0108_branch_return_policy**.
  - New table `branch_return_policies`.
  - Sale snapshot columns: the three policy texts, language, version, customer name and phone.
  - Permission `return.policy.edit` for the Owner, store_manager and store_employee (76 keys).
  - `GET`/`PUT /return-policy`: branch-assigned only; plain text, normalised, at most 1000 characters, markup
    refused; version compare-and-set; audited.
  - Sales resolve the policy on the server (`effectivePolicy`) and IGNORE the legacy client window.
  - Receipts and reprints read the sale's snapshot (`receiptCustomer`, `returnPolicy.texts`).
  - Sale selection reports `returned` and `in_transit`.
- erp-mobile `inventory-general` **`a4377d2`**:
  - ScannerSheet `purpose`: receive / sell / lookup. Sell looks up `/sales/selection`, offers Add to sale (one line),
    gives the real refusal reasons and has no receiving actions.
  - ReturnPolicyCard deleted, and no window is sent.
  - More → Return policy screen (EN/FR/AR, confirmation).
  - Receipt customer and written conditions from the snapshot.
  - The `over_limit` banner is removed; seat enforcement is untouched and Team explains `SEAT_LIMIT_REACHED`.
    `app/access.tsx`, the Business access screen itself, still states the count.
- Verification:
  - backend: TypeScript clean; Jest 5,008 passed, with the same 4 Windows-only failures; `return-policy.spec` 10/10;
  - real MySQL at 0108: D223 25/25, unknown cost 26/26, **policy 23/23** (`scripts/d223-policy-journeys.mjs`);
  - mobile: TypeScript clean; pure tests pass apart from the same 4 Windows-only files; `receipt-policy.test` 14/14;
  - render-tests run 40744958524 on `a4377d2`: pure 126/126, rendered **389/389**, exports, audits, web smoke;
  - security: backend `5370460` 40744610302, mobile `a4377d2` 40744653285;
  - visual-check run 40744976213 on `a4377d2` with backend `5370460`: 818/818 Chromium and WebKit, access journey 21/21, input 245/245.
- Disposable environment for the second retest (running):
  - **database:** `erp_inv_e2e` reset at `5370460`, through 0108, nothing pending;
  - **seed:** the same four fictional businesses with new generated passwords (scratchpad only);
  - **API:** `5370460` on 0.0.0.0:3999;
  - **Metro:** on 8082 serving `a4377d2`. Its iOS bundle holds only the LAN API, 0 `api.tsxmr.com`, the
    scanner-sell, return-policy and conditions code, and no ReturnPolicyCard.
- Not rehearsed separately: 0108 on a database already holding sales at 0107 (a `CREATE TABLE`, nullable `ADD COLUMN`s
  and a guarded permission insert).
device_qa_3_2026-10-28: **the owner completed the physical-iPhone testing on `a4377d2` / `5370460` and approved the
current functionality for a controlled TestFlight pilot** (the owner's message, 2026-10-28). This approves the
pilot, not a public App Store release.
active_phase_2026-10-28 (the owner's pilot brief): implement admin-provisioned accounts with **deferred WhatsApp
verification**, then:
1. close the disposable environment;
2. reconcile the release and merge it through the integration branches;
3. production preflight and backup;
4. deploy the backend and portal;
5. provision the pilot accounts;
6. the TestFlight build and groups;
7. multi-phone checks;
8. the pilot safeguards.
The plan, files, risks and rehearsal are in `docs/109`, and the decision is **D224**. The owner chose
"Test + pilot banner": a Test business only, with a pilot sub-mark changing the banner wording.
**No deployment until every gate passes; no public App Store release.**
progress_2026-10-28 (D224, branches `deferred-verification`; nothing merged or deployed; production untouched):
- erp-backend **`af107f6`**:
  - migration 0109;
  - test provisioning and the deferral lifecycle;
  - setup codes;
  - granted seats for a test business's provisioned staff (the owner's decision);
  - security CI green on `c919354`.
- Backend verification:
  - Jest 5,018 passed, with the 4 known Windows-only failures;
  - real-MySQL spec 10/10;
  - boundary spec 10/10;
  - HTTP journeys 46/46 with the switch on and 4/4 with it off (`scripts/d224-deferral-journeys.mjs`).
- Rehearsal: production's set (`f5da650`, through 0102) plus seeded rows, then 0103→0109. The backfill is correct and
  the schema is identical to a fresh build (0 diff lines).
- erp-mobile **`8067d74`**: the pilot strip, the deferred number, neutral setup copy. Security CI and render-tests green.
- erp-control-web **`812e4a3`**: the verification field, test staff, deferred accounts, the pilot mark, the filter.
  CI green; vitest 12 new tests.
- The D223 environment is closed: Metro, the API on 3999 and the codes page stopped; `erp_inv_e2e` dropped (local
  fictional data only); its credentials deleted.
- The D224 disposable environment remains: `erp_dv_e2e`, `provisioning_dv`, `rehearsal_d224`, and the API on 3998.
- Apple Team ID **5B9T8L263K**. The membership is an **individual** enrolment, not the TSX-MR organisation.
- Rollback floor: a code rollback below 0107 is unsafe once a sale or stock row of unknown (NULL) cost exists. 0109
  itself is additive.
handoff_2026-10-29: CLAUDE stops; its usage ran out. **The next account continues from `NEXT_SESSION_PROMPT.md`**, which
holds the full state, the exact stopping point and the remaining steps. Status stays IN_PROGRESS for the release.
- **Heads:** backend `ca5c099` (security green), portal `7ddeea79` (CI green), mobile `d26da94` plus uncommitted test
  fixes (CI red).
- **Production:** untouched; at 0102.
- **Backup:** `phonestore-20261029T122234Z`; its restore drill PASSED.
- **Rehearsal:** 0103→0109 from the live schema, identical to a fresh build.
- **Decisions by the owner, 2026-10-29:**
  - the pilot store is an ordinary customer;
  - deferral per account;
  - customer activation open;
  - EAS project @salah_rim/dukan-erp;
  - iPhone-only;
  - the Dukan ledger logo.
next_action: finish the mobile test fix (NEXT_SESSION_PROMPT.md "Exactly where it stopped"), then gates, merge, deploy and
TestFlight.
Previous state:
Status: READY_FOR_HANDOFF
Owner: NONE
released_at_utc: 2026-10-27T18:52Z by CLAUDE (local session, the owner's PC), which held it from 2026-10-26T14:31Z (claimed
from READY_FOR_HANDOFF, owner NONE, at `57fd97f`; that handoff was complete).

## Expo SDK 58 (D222) and general electronics inventory (D223) — implemented and verified on feature branches; nothing merged, deployed or migrated (2026-10-26 → 2026-10-27, CLAUDE, local)

The records are `docs/106` (D222) and `docs/107` (D223). **Production is untouched:**
- backend `superadmin-provisioning` `f5da650` and rollback `production-deploy` `644f4f5`;
- the test sites as recorded below (app `9e0b38b`, console `2ebe9c5`);
- tsxmr.com `5aa8322`.

No DNS, server, firewall, registration, messaging or purchase change was made by this session's code. Separately, at
the owner's request and through the owner's Chrome, Hetzner firewall rule 4 now allows `41.188.0.0/16` (the ISP's
range), recorded in the session log.

**HEADs — every tree clean and level with its remote:**

| Repository | Branch | HEAD | Built on |
| --- | --- | --- | --- |
| `erp-mobile` | `sdk-58` | **`fca75c5`** | `browser-input-setup-code` `9e0b38b` (D222) |
| `erp-mobile` | `inventory-general` | **`985f995`** | `sdk-58` `fca75c5` (D223) |
| `erp-backend` | `inventory-general` | **`12fcaad`** | `promoter-attribution` `002e7f8` (D223; migrations 0104, 0105, 0106) |
| `erp-mobile` | `ops/render-tests` | `8f21355` | orphan tooling branch, never merged (evidence under `evidence/`) |
| `erp-mobile` | `ops/visual-check` | `b2e250f` | tooling branch, never merged (evidence under `evidence/runs/`) |
| `erp-docs` | `master` | the commit carrying this file | — |

The local `erp-mobile` checkout is on **`sdk-58`**: Metro (port 8082, LAN, against the production test API) serves it
to the owner's Expo Go. `inventory-general` needs a D223 backend, so it is not served there.

**Verification:**

| Gate | Result |
| --- | --- |
| D222 security CI | success, run 40516759707 on `fca75c5` |
| D222 render-tests | run 40516796050 on `fca75c5`: pure 123/123, rendered 364/364, both exports and bundle audits, web smoke |
| D222 visual-check | success, run 40544916619 |
| D223 backend TypeScript | clean |
| D223 backend unit suite (Windows) | 4,970 passed; 5 Windows-only failures in files this branch does not touch |
| D223 backend security CI | success, run 40553387761 on `12fcaad` (includes the dependency audit) |
| D223 migrations | rehearsed on disposable databases (§ below), each re-run changing nothing |
| D223 end-to-end journeys | **25/25**: disposable API on port 3999, `erp_inv_e2e`, one fictional business (`scripts/d223-journeys.mjs`) |
| D223 mobile TypeScript | clean |
| D223 mobile pure and rendered tests (Linux) | run 40553738099 on `985f995`: pure 124/124, rendered 364/364, both exports and bundle audits, web smoke |
| D223 mobile security CI | success, run 40552841468 on `985f995` |
| D223 visual-check (Chromium, WebKit) | success, run 40553430599 on `985f995` with backend `12fcaad` |

**Migrations, applied only to disposable databases, all now dropped** (`erp_inv_clean`, `erp_inv_upgrade`,
`erp_inv_e2e`):
- **`0104_general_electronics_categories`:**
  - adds `key` and `parent_id`, and a generated `custom_name` that keeps a shop's own names unique;
  - seeds 61 built-ins per business;
  - existing categories and products stay byte-identical.
- **`0105_sale_below_cost_permission`:** the `sale.below_cost` key, granted to `owner` and `store_manager`.
- **`0106_device_catalogue_refresh`:**
  - 4 brands and 48 models from manufacturers' own pages, with provenance in `src/catalog/catalogue-refresh.ts`;
  - Apple re-ranked.

**Not applied to the shared local `phonestore` database, or anywhere real.** Before any real migration: a fresh
backup (`docs/22`) and the owner's approval.

**Found and fixed on the way:**
- **D222:**
  - blank web build (`asyncRoutes`, `+html.tsx`);
  - bottom sheets under Gesture Handler 3;
  - `.xlsx` imports;
  - bundle audits on indexed source maps.
- **D223:**
  - `product_exists` lost its `productId` in the exception filter;
  - body-parser 1.20.9 and multer 2.5.0 for two new high advisories.

**Open — the next exact actions:**
1. **The owner's review of D222 and D223**, and the device-QA checklist (`docs/107` §4). It needs a D223 backend that
   the phone can reach, which is not running anywhere.
2. **`promoter-attribution` needs the same dependency fix** (`12fcaad`'s `package.json` overrides and lockfile): its
   security run fails on the same two advisories.
3. **Merge order, when approved:**
   - backend: `promoter-attribution` (with the fix), then `inventory-general`;
   - mobile: `sdk-58`, then `inventory-general`.
4. **Android:** compile and run the re-cut expo-camera patch on a native build (D222).
5. **Smaller follow-ups** (`docs/107` §6):
   - `categoryKey` in the product detail payload;
   - Stock summary chips by category;
   - the `discount.override` label;
   - the weekly catalogue agent, deferred by the owner.
6. **SSH:** the owner runs `ssh-add -D` and stops `ssh-agent` from an **elevated** PowerShell. `Stop-Service` refused
   in a normal window: "cannot open the service".

Previous state: READY_FOR_HANDOFF, owner NONE.
released_at_utc: 2026-10-25T16:13Z by CLAUDE (cloud; https://claude.ai/code/session_01H7TfZHzwCoXvkvJ7ZuSzA9), which held it
from 2026-10-25T09:56Z (claimed from READY_FOR_HANDOFF, owner NONE, at `3a71aa4`; that handoff was complete).

## Promoter codes, QR cards and user invitations (D221) — implemented and verified on feature branches; nothing merged, deployed or migrated (2026-10-25, CLAUDE, cloud)

The full record is `docs/105`, and the decision is D221. **Production is untouched:** backend `superadmin-provisioning`
`f5da650` and rollback `production-deploy` `644f4f5`; the test sites as recorded below (app `9e0b38b`, console
`2ebe9c5`); tsxmr.com `5aa8322`. No DNS, server, registration, messaging or purchase change was made.

**HEADs — every tree clean and level with its remote:**

| Repository | Branch | HEAD | Built on |
| --- | --- | --- | --- |
| `erp-backend` | `promoter-attribution` | **`002e7f8`** | `superadmin-provisioning` `f5da650` (commits `5c2cd88`, `44bf0c4`, `002e7f8`) |
| `erp-control-web` | `promoter-attribution` | **`b652181`** | `browser-input-setup-code` `2ebe9c5` (`012abcd`, `b35c6e8`, `b652181`) |
| `erp-mobile` | `promoter-attribution` | **`02a30ad`** | `browser-input-setup-code` `9e0b38b` (`a6c2921`, `02a30ad`) |
| `erp-control-web` | `ops/verify-promoter-attribution` | `0c17404` | orphan tooling branch, never merged |
| `erp-docs` | `master` | the commit carrying this file | — |

**What changed:**
- **Migration `0103_promoter_attribution`** (additive): `promoters`, `promoter_codes`, `referral_invitations`,
  `business_acquisitions`, with triggers and CHECKs (`docs/105` §2). It is **not applied anywhere but disposable
  databases.**
- **A new required production secret, `REFERRAL_KEY`**, wired through the guard, secret files, compose, both
  preflights and `setup-secrets.sh` (`docs/105` §10, `docs/100` §17).
- **New optional website input `VITE_APP_WEB_ORIGIN`.** `/join` is added to the portal and full builds' shell
  rewrites.
- **APIs:**
  - public `platform|auth/acquisition/{code,link}` (POST);
  - registration `promoCode` / `referralToken`;
  - console `platform/promoters*`, `platform/acquisitions*`;
  - user `referral-invitations*` (`docs/68` §12).

**Verification:**
- **Backend:**
  - Jest 4,928 passed (80 env-gated skipped); the acquisition spec 34/34.
  - Real-MySQL 0103 spec 22/22 locally and in CI's database gates, which also probe the attribution triggers.
  - Migration rehearsal from production's schema (`f5da650`, 101 migrations): forward, the documented reverse and
    restore all give identical schemas, and 22/22 on the rehearsed schema.
  - CI `40202868432` on `002e7f8`: 5/6 jobs green. The **dependency audit is red** on new `body-parser` and
    `multer` (high) advisories against the unchanged lockfile — see Open.
- **Web:**
  - typecheck clean; Vitest 39 files, 631 tests;
  - Chromium e2e 169/169 locally, the new promoter pages included (EN/FR/AR × light/dark × 375/320/desktop, axe);
  - CI `40203102363` on `b652181` **green**: full, public and portal browser checks, link and bundle audits, the
    full-history secret scan.
- **Mobile:**
  - tsc clean; every pure test passes; Jest 379/379; lint 0 errors and 28 warnings (the baseline);
  - release config, web and iOS exports and the bundle audit pass;
  - CI `40202577957` on `02a30ad` **green**.
- **End to end:**
  - real API and MySQL 8.4, an administrator with MFA, the console build and the app's web export, in both browsers:
    run `40209004760` on `0c17404` — **Chromium 42/42; WebKit 42/42** on the job's one re-run (its first attempt timed out on a plain navigation to the local static server, at a step that passed in every earlier WebKit run). The 42nd check names every refused style: WebKit refuses 15, each traced to its source — WebKit styling its own `<select>` where React creates one (the website form's existing select does the same) or the script Playwright injects for a screenshot; any other refusal fails the run. Chromium refuses none;
  - locally in Chromium: 41/41 (before the 42nd check was added);
  - evidence (statuses and screenshots, no secret) in `ci-evidence` under `evidence/promoter-attribution/`.
  **WebKit on Linux is not an iPhone.**
- **Defects found and fixed by these checks:**
  - the six boxes overflowed at 320 px;
  - the card's text took dark-mode paragraph colour (contrast 1.88);
  - the app's lookup cancelled itself;
  - the app kept the token in the address on a first browser load;
  - the public build's protected-areas alias let the console's module graph in (pre-existing);
  - a token-shaped fixture flagged by gitleaks (built from bytes now, and recorded in `.gitleaksignore`).

**Open / blockers for any merge (none is this session's to decide):**
1. **Backend dependency audit:** the `body-parser` and `multer` high advisories. `multer`'s fix is
   `@nestjs/platform-express` 12 (breaking). They need resolving, or an accepted exception in `docs/48` §7.3.
2. **App links:** the Apple Team ID and the Android release SHA-256 are needed. Then publish the two association files
   and add `associatedDomains` / `intentFilters` (`docs/105` §10). Until then a QR address opens the browser page.
3. **The website's application form** (full build only) sends no WhatsApp consent version, so the server refuses its
   registrations. This predates this phase; the app is where a business registers.
4. **A promoter's own data-deletion request** is handled by hand. It is a gap for counsel (`docs/86` §4).
5. **Physical checks** (`docs/24` §69): camera QR, iOS/Android app links, the native share sheet and WhatsApp through
   it, real-device RTL, printing the card.

**Next exact action:** the owner reviews D221 and `docs/105`, then decides:
1. the dependency-audit resolution (item 1);
2. the merge of the three `promoter-attribution` branches into the integration line;
3. the deployment, per `docs/100` §17: `REFERRAL_KEY`, then a backup, then 0103, then the portal rebuild;
4. the app-link identifiers.
Nothing should be merged, migrated or deployed before that decision.

Previous state (the D219 + D220 deployment, kept below for reference).

## D219 + D220 on the protected test sites — deployed and checked live; the iPhone review is the owner's (2026-10-25, CLAUDE, local)

The full record is `docs/103` §5.10.

**HEADs — clean and level with their remotes:**

| Repository | Branch | HEAD | Note |
| --- | --- | --- | --- |
| `erp-mobile` | `browser-input-setup-code` | **`9e0b38b`** | fast-forwarded from `c8c5c0d` (`--ff-only`, no force); = `visual/light-auth-spacing`; **deployed on erp-test** |
| `erp-control-web` | `browser-input-setup-code` | **`2ebe9c5`** | unchanged; **deployed on dukan-test** |
| `erp-control-web` | `ops/build-test-console` | `26b62d2` | build target console `2ebe9c5` + app `9e0b38b`; run `40174230768` green |
| `erp-backend` | all | unchanged | production `f5da650`, rollback `644f4f5` |
| `erp-docs` | `master` | the commit carrying this file | — |

The PC's checkouts: erp-mobile is on `browser-input-setup-code` (before: `reports-export`); the others are unchanged.

**Releases (`deployments.log` 08:49:26Z and 08:49:38Z):**

| Site | New release | Previous (rollback) | Files | SHA-256 of the sorted checksum list |
| --- | --- | --- | --- | --- |
| erp-test.tsxmr.com | `20261025T084923Z` (app `9e0b38b`) | `20261020T110732Z` | 124 | `37176d11360f2584…` |
| dukan-test.tsxmr.com | `20261025T084934Z` (console `2ebe9c5`) | `20261020T110759Z` | 23 | `40625f32b551588a…` |

**Verification:**
- **Local:** tsc clean; lint 0 errors, 28 warnings; Jest 364/364; release config PASS; secret scan clean; Expo Doctor
  20/21, the documented patch-version finding only.
  - Pure tests: 123/123 on Linux CI (`40175357685`), 119/123 on Windows (path and CRLF artifacts, `docs/103` §5.10).
- **CI on `9e0b38b`:**
  - security `40175357685`, on the pushed integration branch, and `40116896564`;
  - visual-check `40116908073`: WebKit and Chromium each 818/818; journey 21/21 and input 245/245.
- **Server:**
  - smoke 16/16 with each test origin; readiness 101 applied, 0 pending, 0 missing; image `f5da650`, the API not
    restarted;
  - 401 without the password on both sites; TLS valid; CORS exact;
  - the §5.1 counts are identical before and after.
- **Live checks**, the 17 points of the owner's brief: all passed, except as noted in `docs/103` §5.10:
  - the final registration POST was proven by CI and the server's refusal, not sent live;
  - the signed-in screens at 320 px rest on CI, because the Chrome window was minimised.
  - dukan-test: D219 wording present in EN/FR/AR.

**Not changed:** the API, the database (no migration, no backup needed), accounts and credentials, `api.env`, DNS,
Cloudflare, tsxmr.com (Cloudflare pages verified), email, WhatsApp, `CUSTOMER_ACTIVATION=closed`, and the test
business and its data.
- **Firewall:** the owner replaced the Hetzner firewall's SSH source with the PC's new IPv4, with Claude in Chrome
  doing it on the owner's approval. Only that rule changed.

**Known, open:**
- **Test access:** the test business is entitled by the owner's own `subscription.approve` (2026-10-24, period to
  2026-12-11, 0 payments), not by a grant. The owner confirmed it as theirs. Left as is.
- **`X-Robots-Tag`:** the unauthenticated 401 still carries none (`docs/103` §6; a separate approval). Authenticated
  responses do carry it.
- **CSP:** a strict policy at the edge is required before any **public** browser deployment, with Expo's hydration
  hash (`docs/104` §3.1). It was deliberately not added now.
- **`/_sitemap`:** it is served by the app release (behind the password). Exclude it before a public deployment.
- **Expo Doctor:** the patch-version finding stands (docs/75 §15.6). No package was updated and no native build was
  made.
- **Server leftovers** (no secret): `/tmp/s16-platform-admin.sh`, `/tmp/erp-admin-status.txt`, `~/erp-app-release`
  and `~/erp-console-release`. Delete them with the owner's approval.
- **The Storage Box and an off-site restore proof** are still mandatory before outside testers. WEB-F01 is still open.

**Next exact action: the owner's physical-iPhone review** of erp-test and dukan-test, `docs/103` §5.9 plus `docs/104` §7.
No other work was started. Rollback, if the review fails:
`test-sites.sh rollback app 20261020T110732Z --confirm api.tsxmr.com` and
`rollback console 20261020T110759Z --confirm api.tsxmr.com`.

---

Previous claim (this session), superseded by the record above:
started_at_utc: 2026-10-25T07:47Z; claimed_from READY_FOR_HANDOFF (owner NONE) at `63b5175`.
heads_at_claim (all trees clean): erp-mobile `browser-input-setup-code` `c8c5c0d`, `visual/light-auth-spacing`
`9e0b38b`, `ops/visual-check` `761ded3`, `superadmin-provisioning` `da5c73c`; erp-control-web `browser-input-setup-code`
`2ebe9c5`, `ops/build-test-console` `67a3331`, `tsx-public-site` `5aa8322`; erp-backend `superadmin-provisioning`
`f5da650`, `production-deploy` `644f4f5`; erp-docs `master` `63b5175`.
checkpoint_2026-10-25T08:20Z:
- erp-mobile `browser-input-setup-code` fast-forwarded `c8c5c0d..9e0b38b` and pushed (no force); local gates green
  (details at release).
- erp-control-web `ops/build-test-console` `26b62d2` (target app `9e0b38b`, console `2ebe9c5`); build run
  `40174230768` green; evidence `2ebe9c5-9e0b38b-40174230768` checksums verified; both releases packaged on the PC.
- **Blocker for the server steps:** SSH to tsxmr-app-01 times out. The PC's public IPv4 is no longer the firewall's
  trusted address; the owner must update the Hetzner firewall rule. Nothing on the server has been touched.
checkpoint_2026-10-25T08:55Z:
- The owner updated the Hetzner firewall's SSH source (rule 4 only, one /32 for another). SSH works.
- §5.1 reconciliation (08:40Z) matched, except: the test business is entitled by the owner's own `subscription.approve`
  (2026-10-24 11:58Z; period to 2026-12-11; 0 payments; not complimentary), not by a grant. **The owner confirmed it as
  theirs**, and it was left unchanged.
- **Installed:** app `20261025T084923Z` (from `9e0b38b`; previous `20261020T110732Z`) and console `20261025T084934Z`
  (from `2ebe9c5`; previous `20261020T110759Z`).
  - The first app attempt was refused at validation (Windows scp had made the upload mode 700). Nothing was served;
    its stray copy `20261025T084828Z` was removed.
- Smoke 16/16 with each origin; readiness 101/0/0. §5.1 re-run identical apart from the new releases and the edge
  restart.
(The live checks followed; see the record above.)

Previous state: READY_FOR_HANDOFF, owner NONE.
released_by: CLAUDE (cloud; https://claude.ai/code/session_01H7TfZHzwCoXvkvJ7ZuSzA9)
released_at_utc: 2026-10-24T18:27Z
this_claim: 17:38Z–18:27Z from READY_FOR_HANDOFF (owner NONE) at `24ae78d`, documentation only: it recorded the
visual-quality pass (D220, `docs/104`), built in parallel and code-only. **Complete**: every tree touched is clean and
level with its remote.
decision_numbers: this claim used **D220**. The next free number is **D221**.

## Visual-quality pass (D220) — code complete, verified, NOT deployed (2026-10-24, CLAUDE, cloud)

The record, integration steps, CSP note and physical-iPhone checks are `docs/104`. **Nothing was deployed; no server,
database, DNS, tsxmr.com, email, WhatsApp, payment or activation setting was touched.**

**HEADs — clean and level with their remotes:**

| Repository | Branch | HEAD | Note |
| --- | --- | --- | --- |
| `erp-mobile` | `visual/light-auth-spacing` | **`9e0b38b`** | **the app to deploy**; contains `browser-input-setup-code` `c8c5c0d` (merge `800b949`) |
| `erp-mobile` | `browser-input-setup-code` | `c8c5c0d` | unchanged; fast-forwards to `9e0b38b` |
| `erp-mobile` | `ops/visual-check` | `761ded3` | tooling + evidence (`evidence/visual-pass/`) |
| `erp-control-web`, `erp-backend` | all | unchanged | console `2ebe9c5`; backend `f5da650` |

**Verified on `9e0b38b`:**
- security CI `40116896564`: green;
- visual-check `40116908073`: green —
  - WebKit 818/818, Chromium 818/818;
  - D219's own verifier copied in unchanged: journey 21/21 and input 245/245 in each browser;
  - Expo Doctor 20/21, with only the documented patch-version finding (docs/75 §15.6);
  - businesses 3 → 3;
- local: tsc, lint 28 warnings, pure 123 files, Jest 364/364, Chromium 818/818.

**Changes to the next action below:**
- The app to deploy is **`9e0b38b`**, not `c8c5c0d`.
- Its release build does not exist yet. Retarget erp-control-web `ops/build-test-console` to console `2ebe9c5` + app
  `9e0b38b` (or build locally), then package as `docs/103` §5 says. The export now also carries
  `theme-boot.js` and `theme-boot.css`; `web-test-release.mjs` copies them with the pages.
- Add the D220 items of `docs/104` §7 to the owner's physical-iPhone checklist.

**Open, not blocking the test deployment:**
- a strict CSP at the edge before any **public** browser deployment (`docs/104` §3.1 gives the policy and Expo's hash);
- the Expo patch versions (docs/75 §15.6).

---

## Browser input, focus ring and the Owner's setup code (D219) — code complete, verified, NOT deployed (2026-10-24, CLAUDE, cloud)

The record and the deployment runbook are `docs/103`. **This session had no server access and deployed nothing.**

**HEADs — clean and level with their remotes:**

| Repository | Branch | HEAD | Note |
| --- | --- | --- | --- |
| `erp-mobile` | `browser-input-setup-code` | **`c8c5c0d`** | from `superadmin-provisioning` `da5c73c`; CI `40104214743` green |
| `erp-control-web` | `browser-input-setup-code` | **`2ebe9c5`** | from `superadmin-provisioning` `d1016d8`; CI `40100086065` green (unit 612, three e2e surfaces) |
| `erp-control-web` | `ops/verify-browser-input` | `657ced4` | new tooling branch: run `40104216381` green |
| `erp-control-web` | `ops/build-test-console` | (target: console `2ebe9c5`, app `c8c5c0d`) | release build run `40104218531` green |
| `erp-backend` | all | unchanged | production `f5da650`, rollback `644f4f5` |
| `erp-docs` | `master` | the commit carrying this file | — |

**Verification:**
- **Local:**
  - app: tsc 0 errors; lint 28 warnings, the same as before; 121 pure test files; 360/360 rendered;
  - web export OK; Expo Doctor 19/21 (network-only checks);
  - console: typecheck, 612/612, preview build.
- **`ops/verify-browser-input` run `40104216381`:**
  - the backend's unit suite and real-MySQL gates;
  - Chromium and WebKit each: access journey 21/21 and input matrix 245/245 (18 combinations of width × language ×
    theme, validation saved for real).
- The same input matrix fails on the app before the fix (`da5c73c`) and passes after it.
- WebKit is automation on Linux, not a physical iPhone.

**Production state (last verified read-only 2026-10-24T09:37Z, below):**
- unchanged by this phase;
- the owner reports a platform administrator with MFA, a test business with its Owner, store, grant and data created
  after that inspection. **Not yet re-verified; never delete, reset or recreate them.**

**Next exact action — the PC-linked session, in order (`docs/103` §5):**
1. pull `erp-docs`, and claim the handoff;
2. run `deploy/reconcile-readonly.sh` and compare it with §5.1 — stop on any difference;
3. **(D220: the app is now `9e0b38b`.)** Build the release for console `2ebe9c5` + app `9e0b38b`
   (`ops/build-test-console`), fetch it from `ci-evidence`, check the checksums, and package from checkouts at `2ebe9c5`
   and `9e0b38b`. The earlier build `2ebe9c5-c8c5c0d-40104218531` lacks the visual pass;
4. `test-sites.sh install app` and `install console`;
5. smoke 16/16 with each origin, 401 without the password, readiness, image `f5da650`, `ops/verify-production`, and
   §5.1 again with the same counts;
6. the owner's physical-iPhone checklist (§5.9, and `docs/104` §7);
7. record in `docs/103` §5, the handoff and the session log.

No backend deployment and no backup gate apply: the API and database are unchanged. Rollback: `test-sites.sh rollback
app 20261020T110732Z` and `rollback console 20261020T110759Z`.

**Open, not blocking this deployment:**
- `X-Robots-Tag` on the unauthenticated 401: root cause and fix in `docs/103` §6, needing a separate approval;
- the Storage Box and an off-site restore proof, mandatory before outside testers or real data;
- the physical-iPhone retest;
- WEB-F01;
- ~~the Arabic store switch showing "On"~~: fixed by D220 (`9e0b38b`).

**Not changed:**
- public tsxmr.com, DNS, the API, migrations and secrets;
- `CUSTOMER_ACTIVATION=closed`; email and WhatsApp disabled; nothing purchased;
- `+22231229945` neither used nor configured.

**Owner's PC, `C:\wamp64\www\ERP\local-scripts`:** `erp-inspect.sh`, `erp-admin-create.sh` and `erp-admin-mfa.sh`
from this morning's administrator work, and `inspect-report.txt`. None holds a secret; delete them when no longer
useful. The administrator was created this morning (audit `admin.created` written by `erp-admin-mfa.sh` if it ran).

---

## Takeover and production inspection (2026-10-24 morning, CLAUDE, cloud)

taken_over_from: CLAUDE (local session, the owner's PC), IN_PROGRESS since 2026-10-20T08:11Z. **Its handoff was
interrupted**: the last record stops at §16.6, although the server shows §16.7 done (below). The rulebook's
CLAUDE-A/CLAUDE-B labels are retired by the owner: the single active session is `CLAUDE`.
heads_at_takeover (remote = local, all clean per the local refs): erp-backend `superadmin-provisioning` `f5da650`,
`production-deploy` `644f4f5`; erp-mobile `superadmin-provisioning` `da5c73c`; erp-control-web
`superadmin-provisioning` `d1016d8`, `tsx-public-site` `5aa8322`; erp-docs `master` `d7c6ce5`.
read_only_inspection_2026-10-24T09:37Z:
- checkout `f5da650` clean; readiness ready, 101 applied, 0 pending, 0 missing; api/db healthy, edge up, 0 restarts.
- images: `erp-api:f5da650…` (current), `erp-api:644f4f5…` (rollback); backups on host `…015638Z`, `…085555Z`,
  `…110554Z`.
- gates: `CUSTOMER_ACTIVATION=closed`, email/WhatsApp disabled, CORS = dukan, erp-test, dukan-test exactly.
- **§16.7 was done but never recorded:** `deployments.log` 11:07:35Z app release `20261020T110732Z`, 11:08:03Z console
  release `20261020T110759Z`; both enabled; Let's Encrypt certificates to 2027-01-18; both answer 401 without the
  password, **without `X-Robots-Tag`** (open follow-up).
- tsxmr.com `/` 200, `/admin` 404.
- **Platform administrators: 0; companies 0; users 0** at 09:37Z. The console login never existed: the owner's
  "forgotten" password was a never-created administrator. Done afterwards with the owner at the terminal: created with
  `prisma/create-platform-admin.ts` (hidden prompt, twice), then `erp-admin-mfa.sh` for the audit `admin.created` and
  the MFA enrolment token (owner's terminal only). The owner reports MFA enrolled and the test business made since —
  re-verify with `deploy/reconcile-readonly.sh`.
- PHP audit (first pass): no PHP/Apache/LiteSpeed/FrankenPHP package, binary, process, container or Caddy route.

Previous claim, superseded by the takeover above — **history only: its next_action below was completed on the server
(§16.7) and is not an instruction**:
Owner: CLAUDE (local session, the owner's PC)
started_at_utc: 2026-10-20T08:11Z (this claim written before any change)
claimed_from: READY_FOR_HANDOFF (owner NONE) at `95dbf90`; that handoff was complete.
active_phase: `docs/100` §16 on tsxmr-app-01, in order, as the owner authorised on 2026-10-20. Inspect; a backup copied
to the laptop and restored with the v2 identity (PASSED before any migration); backend `f5da650` (0099→0102) with
`CUSTOMER_ACTIVATION=closed` and email/WhatsApp disabled; the test sites erp-test (app `da5c73c`) and dukan-test
(console `d1016d8`) behind one password; a fictional test business by hand; restart survival; verify tsxmr.com
(`5aa8322`); D219.
heads_at_claim: erp-backend `production-deploy` `644f4f5` (deployed) and `superadmin-provisioning` `f5da650`;
erp-mobile `superadmin-provisioning` `da5c73c`; erp-control-web `superadmin-provisioning` `d1016d8`, `tsx-public-site`
`5aa8322`; erp-docs `master` `95dbf90`.
checkpoints:
- §16.2 (08:54Z), read-only:
  - checkout `644f4f5`, clean;
  - api, db and edge healthy;
  - readiness ready, 97 applied, 0 pending, 0 missing;
  - companies 0, users 0, stores 0, sales 0; 118 tables, 53 triggers;
  - 2.5 GB memory available, disk 24 %.
  - **Platform administrators: 0** (§16.2 assumed one; §14 never created it).
- §16.3:
  - **the database rollback point is `phonestore-20261020T085555Z.sql.gz.age`** (53 747 bytes). It was copied to the
    laptop's `.tsxmr\production-backups\` (checksum OK), and that copy was returned to the host;
  - the drill restored it with the v2 identity (`/dev/shm`, shredded after): tables 118, triggers 53, every CHECKSUM.
    **PASSED** (`kind=laptop`).
- Builds: the laptop cannot run either build (Smart App Control blocks Rolldown and lightningcss 1.33). By the owner's
  choice, both are built on GitHub Actions: erp-control-web `ops/build-test-console` (new, tooling only), output on
  `ci-evidence`. They are packaged and checked on the laptop.
- §16.5:
  - `f5da650` came as a bundle (sha256 equal on both ends) and is checked out clean;
  - `api.env`: the three CORS origins, `CUSTOMER_ACTIVATION=closed`, `PORTAL_ORIGIN`. `PUBLIC_SITE_ORIGIN` is kept
    because the rollback target `644f4f5` requires it. The previous file is `api.env.pre-f5da650` (mode 600);
  - `staff_invitation_key` was created, and nothing else was replaced;
  - `stack.env`: `WEB_DIR`, the two hosts, and the testers' login (from hidden prompts; bcrypt only, mode 600).
- §16.6:
  - **The first `deploy.sh` stopped at `step=contract`**, before the backup and the migrations. My `git checkout` had
    run under `umask 077`, so 165 changed files were mode 600 and unreadable in the image.
  - The tracked files' read bits were restored, then the deploy was re-run with `--after-interrupted`.
  - Then: contract PASS; preflight PASS; pre-migration backup **`phonestore-20261020T110554Z.sql.gz.age`**;
    **0099→0102 applied**, schema up to date (101 migrations); catalogue 73/73; identities 16/0; audit chain OK.
  - API and edge recreated: image `erp-api:f5da650945ba…`; rollback target `erp-api:644f4f5984873e2b…`.
  - Smoke 15/15, and 16/16 with each of `--allowed-origin` erp-test and dukan-test.
next_action: §16.7, install the app and console releases (built on GitHub run `39396765340`, packaged on the laptop)
with `test-sites.sh`, after re-checking DNS.

Previous state (unchanged below): READY_FOR_HANDOFF, owner NONE.
released_by: CLAUDE (cloud), https://claude.ai/code/session_01QVaHmhvXSCrmndjXnKST77
released_at_utc: 2026-10-20T07:03Z
previous_claim: CLAUDE (cloud), started 2026-10-20T07:02Z (`163dac8`) from READY_FOR_HANDOFF (owner NONE) at `d52bf7a`;
that handoff was complete.
decision_numbers: D217 is the provisioning phase's; this phase used **D218 only** (the Riyade release, coordinated with
that session's release note). The next free number is **D219**.

## Riyade, coming soon — deployed to tsxmr.com and verified live; recorded (D218) (2026-10-20, CLAUDE, cloud)

The owner approved this production change on 2026-10-20 (D218). The deployment record is `docs/95`, last section; the
follow-up defect is `docs/83` WEB-F01.

**HEADs — every tree this phase touched is clean and level with its remote:**

| Repository | Branch | HEAD | Note |
| --- | --- | --- | --- |
| `erp-control-web` | `tsx-public-site` | **`5aa8322`** | **production tsxmr.com**; fast-forwarded from `5f666ea` at 05:47:39Z, no force |
| `erp-control-web` | `site-riyade-coming-soon` | `5aa8322` | the candidate branch (CI `39363371901` green) |
| `erp-control-web` | `ops/verify-production` | `5a01050` | the verifier now expects the three Riyade pages and 42 sitemap URLs |
| `erp-control-web` | `ops/verify-preview` | `57010fb` | tooling: target `5aa8322` on tsxmr.com (run `39377118688` green) |
| `erp-control-web` | `superadmin-provisioning`, `integration/browser-test` | `d1016d8`, `0ee0b35` | unchanged by this phase; both contain `5aa8322` (checked) |
| `erp-backend`, `erp-mobile` | all | unchanged | as in the record below |
| `erp-docs` | `master` | the commit carrying this file | — |

**Changed on tsxmr.com:**
- Riyade's page in EN/FR/AR at `/products/riyade`, `/fr/…` and `/ar/…`: name, line, who makes it and "coming soon";
  nothing to do;
- a lighter Products card after Dukan ERP, a row under the featured Dukan ERP card on Home, and a footer entry under
  the heading "Products";
- "Today there is one: Dukan ERP." removed from the Products summary;
- Dukan ERP's pages, wording, documentation link and routes are unchanged.

**Verification:**
- **Before:** Vitest 552, e2e full 134 and public 172 locally; the real production build PASS; CI green on the exact
  commit.
- **After, live via GitHub runners:**
  - verify-production run `39377112842`: 25/25 checks, public suite 172/172;
  - verify-preview run `39377118688` on the exact commit: 25/25, WebKit 27/27, public suite 172/172;
  - verify-not-found green; CI on `tsx-public-site` `39376798802` green.
- No regression found; no rollback.

**Rollback target:** commit `5f666ea` and its Cloudflare production deployment (dashboard → `tsxmr-public` →
Deployments), or revert `cfd207b` and `5aa8322` and push the revert, never with force.

**Open, not blocking:**
- WEB-F01, the wrong language or direction for about two frames while a page starts (`docs/83`). A separate fix with
  the owner's approval.
- The verifier compares the sitemap's build-date `<lastmod>`; a re-run on a later UTC day fails that one file
  (`docs/95`).

**Next exact action: none for this change.** Any deployment that affects tsxmr.com must keep the three Riyade routes
and the Dukan ERP pages; `ops/verify-production` checks both. The provisioning record below is unchanged and still
holds for its runbook.

---

## Platform-superadmin provisioning and persistent test businesses (D217) — branches pushed and verified, nothing deployed (2026-10-20, CLAUDE, cloud)

The decision is D217 (`docs/21`). The deployment runbook is `docs/100` §16, to be run by the owner's local session.

**Final HEADs — every tree clean and level with its remote:**

| Repository | Branch | HEAD | Base | CI on that commit |
| --- | --- | --- | --- | --- |
| `erp-backend` | `superadmin-provisioning` | **`f5da650`** | `integration/browser-test` `b0758c2` | `39379592884` green, 6/6 |
| `erp-mobile` | `superadmin-provisioning` | **`da5c73c`** | `integration/browser-test` `d7a28fe` | `39379598714` green, 3/3 |
| `erp-control-web` | `superadmin-provisioning` | **`d1016d8`** | `integration/browser-test` `cd512c2d`; + `tsx-public-site` `5f666ea` (at `b0597ab`) and `5aa8322` (at `d1016d8`) | `39380223602` green |
| `erp-control-web` | `integration/browser-test` | **`0ee0b35`** | `cd512c2d` + `tsx-public-site` `5aa8322` | `39380702740` green |
| `erp-control-web` | `ops/verify-provisioning` | `6c0e971` | new orphan tooling branch | `39380843386` (WebKit) green: journeys 41/41, console 103/103, app 57/57 |
| `erp-docs` | `master` | the commit carrying this file | — | — |

The WebKit evidence is on `ci-evidence` under `evidence/provisioning/f5da650-d1016d8-da5c73c-39380843386`: 122
screenshots, none showing a setup code.

**Unchanged by this phase:**
- the production API: backend `production-deploy` `644f4f5` (api.tsxmr.com, migrations to 0098);
- tsxmr.com: `tsx-public-site` `5aa8322`, the Riyade session's release, and its `site-riyade-coming-soon`;
- the `whatsapp-consent` branches `608e25a`, `23ec6fd` and `4764afd`.

**Riyade carried into every branch that serves the public site.** `tsx-public-site` `5aa8322` is merged into web
`superadmin-provisioning` and `integration/browser-test`. On both:
- Riyade's five files are byte-identical to `5aa8322`: its page, component, content, test and notes;
- every line Riyade added that names it or "coming soon" (231 lines in all) is present. That includes the shared files:
  routes, i18n, Home, Products and the footer;
- `test/riyade.test.tsx` passes in their CI.

Neither branch is deployed to tsxmr.com.

**Permanent functionality** (backend + console):
- **Who.** A platform administrator with MFA, a step-up and a server-side permission.
- **What they can do:**
  - create a business with its Owner (idempotent by key);
  - add stores to that business;
  - see provisioning and activation as separate statuses;
  - issue or reissue the Owner's setup code.
- **Rules:**
  - the existing duplicate-contact and multi-company rules apply;
  - each action is audited with actor, target and outcome;
  - no visible password, no impersonation, no consent or phone verification, no payment, no trial spent.

**Test mechanism** (migration 0102, additive):
- **Status.** Only the administrator sets or clears test status.
- **Indicator.** A Test badge and banner in the console; an app strip from the first sign-in.
- **Accounting.**
  - Excluded from commercial figures.
  - No payment can be recorded.
  - Access only by an audited grant, under which a store opens free.
- **Isolation.** Connections to test businesses only; nothing wiped automatically.
- **Activation.** `CUSTOMER_ACTIVATION=closed` in production. The setup code works only for a test business, and the
  owner chooses the password.

**Verification:**
- **Locally** (real API, MySQL, built frontends, Chromium):
  - 12 journeys 41/41;
  - the console in EN/FR/AR, light and dark, 320/393/1280: 103/103;
  - the app: 57/57.
- **The edge,** rehearsed through the real `test-sites.sh`.
- **The migration,** 0098 → 0102, with the backup, the verification and the restore into a new schema: PASSED.
- **The code rollback:** `644f4f5` runs on the 0102 schema.
- **WebKit on a runner:** as in the table. It is not a physical iPhone.
  - The console log lists one refused stylesheet per combination (`style-src`). The console injects no
    stylesheet, and every screenshot is styled; it is the style Playwright adds for its screenshots.

**Not done:**
- **Nothing is deployed.** SSH to `tsxmr-app-01` is limited to the owner's address.
- **No DNS change.** Instructions are in `docs/100` §16.9.
- **No purchase, Meta, SMTP, billing or public-site change.**
- **The company sender.** +22231229945 is neither used nor configured.

**Blockers (owner):**
1. Two DNS-only A records, `erp-test` and `dukan-test`, with no AAAA (`docs/100` §16.9).
2. The testers' login name and password; only the bcrypt hash goes on the server.
3. The backup identity, for the restore drill (§16.3).
4. The Storage Box or another off-site backup decision (§16.11). It is a purchase, outside this phase.

**WhatsApp-dependent tests still outstanding:**
- real verification codes and phone verification;
- WhatsApp consent;
- deletion by WhatsApp code;
- informational notices;
- employee invitations sent by WhatsApp.

They wait for the company's replacement sender. A physical iPhone check is also outstanding (`docs/24` §68).

**Next exact action:** in the owner's local session, run `docs/100` §16 in order:
1. §16.1, the owner's inputs;
2. §16.2, inspect the server (read-only);
3. §16.3, an encrypted backup, copied off the host, and the restore drill PASSED;
4. §16.5, bring `f5da650`, then `api.env` and `stack.env`;
5. §16.6, `deploy.sh`, then smoke with both origins;
6. §16.7, build both sites on the laptop from `da5c73c` and `d1016d8`, then install them;
7. §16.8, the manual checks with persistent test accounts, ending with `ops/verify-production` against tsxmr.com.

Record the backup file name, the migration and the release names here as each step is done.

**Clean-up:**
- the scratch MySQL databases were dropped and the server stopped;
- the local API, the static servers and the rehearsal stack were stopped and removed;
- the scratch secret files were deleted;
- the scratch worktrees were removed.

---

Previous state (unchanged below): READY_FOR_HANDOFF, owner NONE, released 2026-10-19T12:56Z by CLAUDE (cloud),
https://claude.ai/code/session_01PLhoUhSVGTwofTQRXsJNof.

## Account deletion as a Dukan ERP documentation entry — deployed to tsxmr.com and verified live (2026-10-19, CLAUDE, cloud)

The owner approved this production change and its direct deployment (D216). The record is `docs/95`, last section.

**HEADs — every tree clean and level with its remote:**

| Repository | Branch | HEAD | Note |
| --- | --- | --- | --- |
| `erp-control-web` | `tsx-public-site` | **`5f666ea`** | **production tsxmr.com**; fast-forwarded from `bf62a72` at 12:42:41Z, no force |
| `erp-control-web` | `site-deletion-docs` | `5f666ea` | the candidate branch (CI `39253330577` green) |
| `erp-control-web` | `ops/verify-preview` | `8c87ec8` | tooling: target set to `5f666ea` on tsxmr.com (run `39254553775` green) |
| `erp-control-web` | `integration/browser-test` | `cd512c2d` | unchanged; merge `tsx-public-site` `5f666ea` into it before its next build |
| `erp-backend`, `erp-mobile` | all | unchanged | `production-deploy` `644f4f5`; `integration/browser-test` `b0758c2` / `d7a28fe` |
| `erp-docs` | `master` | the commit carrying this file | — |

**Changed on tsxmr.com:**
- the Dukan ERP page ends with a Documentation section, whose entry "Account deletion" opens the localized page;
- the deletion link is gone from the footer's Help column and from the company pages' "Related pages";
- Support's Dukan ERP section and the `/in-app/` footer keep theirs;
- the deletion page is 1.1, "Delete a Dukan ERP account" in EN/FR/AR, with its scope and the separate email request
  stated. The policy is unchanged and Dukan ERP is still said to be not open;
- all deletion URLs, `/in-app/` included, are unchanged.

**Verification:**
- **Local:** typecheck; Vitest 519/519; refusals; link and bundle audits; e2e full 130, public 163; the real
  production build PASS; a page-by-page diff against `bf62a72` showing only the intended changes.
- **CI:** green on the exact commit, on both branches.
- **Live, from this environment:**
  - 79/80 files byte-identical; the 80th, `security.txt`, differs only by its build time;
  - a Chromium check 33/33 in EN/FR/AR;
  - portal and admin routes 404.
- **Live, via the GitHub verification** (`39254553775`): production checks 23/23, WebKit 27/27, public suite 163/163.
- No regression found; no rollback.

**Rollback target:** commit `bf62a72`, Cloudflare deployment `5ac08a5e`. The new deployment's ID was not read: there
is no dashboard access in this session.

**Not done (by instruction or scope):**
- no preview;
- no DNS, Cloudflare-settings, email, SMTP, WhatsApp, backend, app or database change;
- the portal and service deletion text (`legal-deletion.ts`) is untouched.

**Next exact action: none for this change.** The previous record below still holds for the integration line (D215
awaits the owner; `docs/102` §9 is the shortest path to the browser-test URL).

---

## Integration and the phone-browser test — branches tested and pushed, nothing deployed (2026-10-19, CLAUDE, cloud)

**The full record is `docs/102`.** Decision D215 is proposed and awaits the owner's approval.

**Final HEADs — every tree clean and level with its remote:**

| Repository | Branch | HEAD | Base | Role |
| --- | --- | --- | --- | --- |
| `erp-backend` | `integration/browser-test` | **`b0758c2`** | `whatsapp-consent` `608e25a` | + QA fixture (`7445d2b`); + the staging edge's protected browser-test site (`b0758c2`) |
| `erp-mobile` | `integration/browser-test` | **`d7a28fe`** | `whatsapp-consent` `23ec6fd` | Expo patches; browser fixes; web routes and the release script |
| `erp-control-web` | `integration/browser-test` | **`cd512c2d`** | `whatsapp-consent` `4764afd` | + `tsx-public-site` `bf62a72` merged (no conflict) |
| `erp-docs` | `master` | the commit carrying this file | — | — |

Unchanged:
- production backend `production-deploy` `644f4f5` (api.tsxmr.com, migrations to `0098`);
- production web `tsx-public-site` `bf62a72`;
- the `whatsapp-consent` branches `608e25a`, `23ec6fd` and `4764afd`.

**Done:**
1. **Expo patch drift.** Ten SDK 57 patches; the camera patch re-cut for 57.0.6 (byte-identical hunks); Expo Doctor
   21/21. Remaining: the Android camera on a physical phone (`docs/24` §68 A1).
2. **Website and portal.** One commit, two surfaces.
   - The public production build matches production page for page.
   - The portal surface serves `/subscription` and `/admin`; the public surface 404s them.
   - typecheck; Vitest 548; link and bundle audits; Chromium e2e full 138, public 160 and portal 34, all passing.
   - The production portal build is refused by the PORTAL gate (12 legal blockers and 6 drafts).
3. **The ERP in a browser.** The web export was audited and fixed (`docs/102` §4):
   - the unticked consent no longer throws (`sendAccessibilityEvent` is absent on web);
   - `aria-*` states reach browser screen readers;
   - the receipt opens in a tab; the refund receipt and the scanner say what the phone app does;
   - *Share* is offered only with a share sheet;
   - dynamic routes are served by the right page.

   The protected test site: Caddy basic auth on its own DNS-only hostname, on the staging edge (`docs/99` §14),
   rehearsed locally.
4. **Journeys** (Chromium at phone size, against a disposable API and database, codes read from hashes, nothing
   sent):
   - sign-in and sign-out;
   - Owner registration and consent, then the portal trial claim (8/8);
   - employee invitation and activation (10/10, the reference absent from a full database dump and the API log);
   - stock intake by typed IMEI and the sale, with the receipt tab and sell-once (5/5);
   - read-only after expiry (5/5);
   - 72 static screens.

   Layouts: 81 screens, EN/FR/AR × light/dark/320 pt; no overflow, direction right, no script error.
5. **Handoff.** Build commands, variables, hosting and access, backend image and migration order, rollback, and the
   owner inputs: `docs/102` §8.

**Verification at the final HEADs:**
- mobile `d7a28fe`: tsc; lint 0 errors (28 warnings, baseline); pure 119 files; Jest 36 suites / 349; web and iOS exports; bundle audit PASS; release refused without inputs; secret scan clean; Expo Doctor 21/21 (dependencies unchanged since `5fe0287`, whose shipped-dependency audit passed);
- backend `b0758c2`: deploy-only change. `bash -n`; Caddy 2.8.4 validates the edge with the site off and on;
  `compose config`; the production-guard spec 97/97 and the deploy-scripts spec 17/17. `whatsapp-consent`'s full gate
  at `608e25a` stands (Jest 4 871/0, CI database gate);
- web `cd512c2d`: as in item 2 above.

**Not done:**
- **By instruction:** no merge, no deployment or promotion, no DNS or Cloudflare change, no production migration or
  secret, no provider, no real message, no purchase.
- **Could not be done here:**
  - **WebKit automation.** No WebKit in this environment, and browsers cannot be installed. Adding Playwright to the
    mobile repository is a new dependency that needs approval;
  - **a physical iPhone**: `docs/24` §68, NOT DEVICE VERIFIED.

**Risks:**
- Production now occupies `tsxmr-app-01`. Staging, and with it the test site, needs **its own host** (`docs/99` §11).
- The web branch push may trigger a Cloudflare Pages preview if preview branches are enabled. It would be noindexed
  but public; check the project setting.
- Staging codes reach testers only through the operator: the outbox and the keyed lookup.

**Clean-up:**
- the scratch MySQL and its data, the API, the static servers and Caddy were stopped and deleted, with their secrets
  and builds;
- the scratch web worktree was removed;
- scratch files stay in the session's temporary directory only.

**Next exact action: none until the owner decides.** On approval of the test site, follow `docs/102` §9:
1. the owner provides a staging host and confirms `staging-api.tsxmr.com` and `erp-test.tsxmr.com` (both DNS only),
   then adds the two records;
2. the operator deploys the staging API from backend `b0758c2` (`docs/99` §6 plus `docs/102` §8.1 step 3);
3. the operator builds and packages the release from mobile `d7a28fe` and runs `deploy/staging/web-test.sh install`;
4. the operator creates a fictional Owner with an outbox code and opens it;
5. the owner gives testers the URL, the login and the password, separately.

On approval of the production rollout: `docs/102` §8.2, then `docs/101` §17.7.

## Pre-merge reconciliation: the routing matrix confirmed and closed; every branch HEAD stated (2026-10-19, CLAUDE, cloud)

**Final HEADs — every tree clean and level with its remote; full history fetched to check ancestry:**

| Repository | Branch | HEAD | Contains | Role |
| --- | --- | --- | --- | --- |
| `erp-backend` | `whatsapp-consent` | **`608e25a`** | `dukan-portal-lifecycle` `17ea84b` ⊃ `production-deploy` `644f4f5` (⊃ `master` `67352af`) | the backend to merge: 0099, 0100, 0101, portal, consent, invitations |
| `erp-backend` | `production-deploy` | `644f4f5` | — | **production API** (api.tsxmr.com), untouched |
| `erp-mobile` | `whatsapp-consent` | **`23ec6fd`** | `dukan-portal-lifecycle` `de40f72` ⊃ `reports-export` `e6773aa`; also `master` `f47a155` | the app to merge |
| `erp-control-web` | `tsx-public-site` | **`bf62a72`** | `main` `0417bfe` | **production tsxmr.com**, untouched |
| `erp-control-web` | `dukan-portal` | **`0fd418a`** | split from `tsx-public-site` at `e953c58` | the portal line before D213; not to be deployed alone |
| `erp-control-web` | `whatsapp-consent` | **`4764afd`** | `dukan-portal` `0fd418a` | the portal to deploy (D213 labels) |
| `erp-docs` | `master` | the commit carrying this file | — | — |

- There is **no** `dukan-portal-lifecycle` branch in the website repository; `4764afd` is web `whatsapp-consent`.
- `tsx-public-site` and the portal line have diverged: production has 4 commits the portal line lacks (the Balanced
  motion release and `.gitleaksignore`), and the portal line has 6 that production lacks.
- A dry-run merge (`git merge-tree`, no ref written) of `tsx-public-site` into web `whatsapp-consent` has **no
  conflict**.
- **`dukan.tsxmr.com/subscription`** is the portal surface (`VITE_SITE_SURFACE=portal`) of web `whatsapp-consent`.
  On approval, merge `tsx-public-site` into it first and re-run the website gates, so one commit serves tsxmr.com and
  the portal; the portal's own Pages project then builds it (`docs/101` §1 note, §17.7).
- The backend and mobile `dukan-portal-lifecycle` branches must not be merged on their own: their notice rules still
  stop a message for a missing or withdrawn consent. `whatsapp-consent` replaces that.

**Routing matrix — confirmed in code and tests:** every category, with files and test names, is in `docs/101` §17.6.
- **Never by email:** OTP, deletion, closing reports, the employee invitation, the number change, registration and
  the portal sign-in hold no email channel. A phone's code goes by WhatsApp or fails, and no recovery route exists.
- **Informational** (portal instructions, trial and subscription status, the 72/48/24 h reminders, grace notices,
  read-only ends): WhatsApp when ready and actively consented; otherwise one email to a verified address when email is
  ready; otherwise an honest not-sent. Never both.

**Corrected** (backend `608e25a`):
- the unreachable `stop` paths left in the notice plan are removed;
- new tests cover grace started, the grace reminders and grace ended falling back on a withdrawal, the read-only end on
  a missing consent, no verified email and email not ready (honest not-sent), and WhatsApp alone when ready;
- the never-by-email source rule now also covers the invitation, number-change, registration and portal-sign-in
  services, and pins the notice kinds to the seven informational ones;
- the withdrawal route no longer says "Nothing moves to email";
- `docs/101` §1 now shows `dukan-portal` at `0fd418a`, not the stale `e020215`.

**Verification:**
- backend `tsc` clean, Prisma valid, Jest 267 suites 4 871/0;
- CI database gate re-run on a fresh scratch MySQL 8.4.11: identities 27/0; MySQL specs 21/21, 10/10, 9/9 and 8/8;
- the scratch server was deleted afterwards;
- mobile and website: no change, so last session's gates stand at `23ec6fd` and `4764afd`.

**Not done (by instruction):** no merge, no deployment, no production migration, no production secret, no provider,
no real message.

**Next exact action:** none until the owner approves the rollout. Then the next session:
1. claims this file;
2. merges `tsx-public-site` into web `whatsapp-consent` and re-runs the website gates;
3. re-runs the backend and mobile gates at `608e25a` and `23ec6fd`;
4. follows the D214 rollout steps below: the secret, the backup, then `0099` → `0100` → `0101`.

The previous records follow; the D214 record below holds the rest (risks, waiting items).

---

Previous session: CLAUDE (cloud), https://claude.ai/code/session_01PLhoUhSVGTwofTQRXsJNof — 05:40Z–07:05Z, complete.

## Employee invitations: creating an employee sends nothing; the employee activates from a reference — on branches, verified, not deployed (2026-10-19, CLAUDE, cloud)

| Repository | Branch | HEAD (pushed) | Base (unmoved) | This session |
| --- | --- | --- | --- | --- |
| `erp-backend` | `whatsapp-consent` | `42d2bcd` | `dukan-portal-lifecycle` `17ea84b` | `b6a0dc7` migration 0101, `STAFF_INVITATION_KEY`, the `cancelled` conclusion in amended 0100; `a1f82ae` the invitation flow; `42d2bcd` probe spec |
| `erp-mobile` | `whatsapp-consent` | `23ec6fd` | `dukan-portal-lifecycle` `de40f72` | the join screen by reference; the Owner's reference-once sheet; the pending panel's status and new invitation |
| `erp-control-web` | `whatsapp-consent` | `4764afd` | `dukan-portal` `0fd418a` | unchanged (D214 needs nothing there) |
| `erp-control-web` | `tsx-public-site` | `bf62a72` | — | **production** (tsxmr.com), untouched |
| `erp-docs` | `master` | the commit carrying this file | `bcf1a28` | D214 (+ D213 pointer) in `docs/21`; `docs/69` §3; `docs/98` §12; `docs/101` §17; `docs/24` §67 (C13–C21); session log |

All four trees are clean and level with their remotes. The production API (`644f4f5`), its database, DNS and
Cloudflare were not touched.

**Migration order** (verified from the branches): production `production-deploy` `644f4f5` stops at `0098`;
`dukan-portal-lifecycle` `17ea84b` adds `0099`; `whatsapp-consent` adds `0100` (amended in place) and `0101`. Each
branch contains the one before it; no other branch defines `0099`–`0101`.

**What D214 does** (record: `docs/101` §17; decision: `docs/21` D214; routes: `docs/69` §3):
- **Owner-only** creation, new invitation and cancellation (`user.manage`); no Manager authority; no permission change.
- Creating an employee needs a **WhatsApp number** (email optional) and **sends nothing** — no WhatsApp, no email.
- The server issues a **72-hour, one-use** invitation. Its reference (12 characters, `K7QM-9XRT-2CHD`) is shown
  **once**, with Copy and the phone's Share; only its HMAC under the new **`STAFF_INVITATION_KEY`** is stored, never
  the reference or a number. The pending panel shows status and expiry, never the reference.
- *New invitation* revokes the old one and ends its pending consent (`cancelled`, by the Owner); cancellation does the
  same and withdraws the account; both re-check under lock that the account is still pending.
- The employee (Sign in → *I was added to a team*; or `dukanerp://join?ref=…`, which only fills the form) types the
  reference, then their matching number, sees the server's consent unticked, ticks it and asks for the code. Only then
  is the `pending_unverified` consent recorded (the employee as actor) and the code sent. Resend reuses the same
  pending consent while both are valid; an expired consent (24 h) is accepted again inside the 72 h.
- Confirmation is **one transaction**: code consumed, number verified, password set, exactly the bound consent active,
  invitation used, account activated when a seat is held.
- Unknown, expired, revoked and used references all answer `invitation_unavailable`; every public route is throttled;
  one number invited by two businesses activates only the invitation's own account.
- Activation now waits for the verified number and a seat; email never holds it back. A pending employee's number
  cannot be edited (`pending_number_locked`). The number-based `staff/verify/*` routes and the Owner's resend are gone.
- No existing pending employee was migrated: the Owner issues their invitation.

**Databases.** Only disposable ones, on a throwaway MySQL 8.4.11 in the session's scratch directory: the CI gate's
`phonestore`, `addon_ci`, `grace_ci`, and the rehearsal's `consent_rehearsal`, `consent_restore`, `consent_reverse`.
All are dropped, and the server is stopped and deleted. Rehearsal backups (deleted): before `dc4031f2f1090488…` (0098),
after `2ceed2cc93688886…` (0101). No staging or production database was touched.

**Verification at the final HEADs**

| Area | Result |
| --- | --- |
| backend | `tsc` clean; Prisma valid; Jest 267 suites, 4 864 passed, 0 failed (4 env-gated MySQL suites skipped, run below) |
| CI database gate (fresh MySQL 8.4.11) | identities and triggers 27/0; catalogue 73/73; `trial-addons.mysql` 21/21; `lifecycle.mysql` 10/10; `consent.mysql` 9/9; `staff-invitation.mysql` 8/8 |
| production-upgrade rehearsal | 0098 (identical to `644f4f5`'s migrations) with 80 pre-invitation pending employees → 0099 → 0100 → 0101: 0 invitations created, nothing pre-existing changed, 0 numbers consented; both MySQL specs green **on the upgraded schema** as the application account; the reverse of all three gives data and schema identical to the 0098 backup |
| mobile | `tsc`; lint 0 errors (28 pre-existing warnings); 117 pure files; Jest 36 suites, 349 tests; web and iOS exports; bundle audit PASS; release refused without inputs; secret scan clean |
| Expo Doctor | **not passed:** 10 Expo packages a patch behind SDK 57; no dependency changed (unchanged since the earlier phases) |
| EN/FR/AR | key parity: mobile 3 942, website 730 |
| messages | test and recording channels only; nothing sent |

**Found and fixed on the way:**
- A confirmation racing the Owner's cancellation could have withdrawn a just-activated account: cancellation and
  reinvitation now re-check under the person's row lock, and the lock helpers read the row's state from the locking read
  itself. A real-MySQL test pins it.
- `consent.mysql.spec` still filtered for the pre-D213 `granted` event: it passed only when the race went one way.
  Corrected to `active`.
- `0099`'s migration header gives its reverse without the column's `CHARACTER SET … COLLATE`; `docs/101` §13 already
  has the full form, and the rehearsal proved it restores the schema exactly. The applied migration file is left as is.

**Known risks and limits:**
- Nothing ran on a device (`docs/24` §67, C1–C21), on Meta or SMTP, or on the production stack.
- Rollout needs a **new production secret** (`staff_invitation_key`, via `deploy/production/setup-secrets.sh`) before
  the API starts; without it the API refuses to start.
- After rollout, every employee still pending in production needs their Owner's *New invitation*. A pending employee
  created without a number (before 0099) must be cancelled and added again with one.
- The app link is a custom scheme: WhatsApp does not make it tappable, so manual entry is the main path, as decided.

**Not done (by instruction):**
- merging, or any deployment;
- migrating production, or applying `0099`–`0101` to any persistent database;
- creating the production secret;
- activating a provider;
- sending any real message;
- touching Cloudflare.

**Waiting on the owner and providers:**
1. Approval to merge the three `whatsapp-consent` branches, and for each rollout step (`docs/101` §12 with the §17.7
   additions).
2. Counsel's review of the consent wording.
3. Meta: verification, display name, opt-in policy, templates, the number, the webhook and the token.
4. The device checks of `docs/24` §67.
5. The remaining D212 questions (`docs/101` §14).
6. Expo Doctor's patch drift: approve a dependency update as its own change, or leave it.
7. An HTTPS join link, if wanted: a website deployment and its own approval.

**Next exact action:** none until the owner answers. On an explicit rollout approval, the next session:
1. claims this file;
2. re-runs the gates at backend `42d2bcd`, mobile `23ec6fd`, web `4764afd`;
3. creates `staff_invitation_key` with `setup-secrets.sh`;
4. takes and checks the production backup (`docs/22`);
5. applies `0099` → `0100` → `0101` per `docs/101` §12 and §17.7.

The previous records follow. The consent-corrections record below is superseded on employee activation by this one.

---

Previous session: CLAUDE (cloud), https://claude.ai/code/session_01PLhoUhSVGTwofTQRXsJNof — 04:30Z–05:25Z, complete.

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
