# Continuation prompt — Dukan ERP real-store pilot release (written 2026-10-29 by CLAUDE before its usage ran out)

Paste this to the next Claude session. Read `CURRENT_HANDOFF.md` (top block), then continue. **Do not redo finished work.**

## The owner's brief in force (2026-10-29)

Prepare a **real-store pilot** on TestFlight.
- The pilot store is an **ordinary customer business**, not Test or pilot:
  - no banner, no exclusion, no isolation, no free seats.
- **iPhone-only**.
- **Expo** owner `salah_rim`; **Apple** Team ID `5B9T8L263K`, individual membership.
- **Feedback email:** `abdelkerim@tsxmr.com`.
- **Exactly one platform superadmin.** Production already has one, active, with MFA: do **not** create another.
- **The user** creates the real business and its staff in the portal.
- **Never handle secrets:**
  - never type the user's Expo or Apple passwords or 2FA codes;
  - never put credentials in Git, docs or chat;
  - tester emails are asked for only once the TestFlight group is ready.
- **Owner decisions taken this session:**
  - open customer activation (`CUSTOMER_ACTIVATION=open`) for this release;
  - a new EAS project `@salah_rim/dukan-erp`, because Expo cannot rename the old `phonestore-erp` slug.

## Release heads (all on branch `deferred-verification`, pushed)

| Repo | HEAD | State |
| --- | --- | --- |
| erp-backend | `ca5c099` | clean. Security CI **green** (run 40865900480) |
| erp-control-web | `7ddeea79` | clean. CI **green** (run 40870764729) |
| erp-mobile | `d26da94` + **UNCOMMITTED** edits (below) | CI **red** (render-tests and security) |
| erp-docs | this commit | |

The lineage is linear on top of production's `f5da650`, through `promoter-attribution` and `inventory-general`. The mobile `promoter-attribution` commits were merged in at `6dd3213`. The September `claude/audit-fixes`, `qa-boutique-seed` and `stock-finds-products` branches are unapproved drafts; the two `audit-fixes` are superseded (O-C7). They are deliberately excluded.

## Done and verified this session

**Deferred verification (D224), reworked per account in an ordinary business:**
- `AccountProvisioningService` and its controller, at the route `platform/businesses/:id/provisioned-staff`.
- Normal seats only. A full business or store is refused with `seat_unavailable`; no seat is granted or priced.
- The pilot mark and the Test-only rules are removed. The confirmation field is `confirmUnverified`.
- Migration **0109** was amended before it ever reached a persistent database; `is_pilot` is removed.
- Verification:
  - real-MySQL spec 11/11;
  - boundary spec 10/10;
  - HTTP journeys 43/43 with the switch on and 4/4 off (`scripts/d224-deferral-journeys.mjs`).
- The production preflight and `test-sites.sh` accept `CUSTOMER_ACTIVATION=open` (the reviewed change).

**Logo** (the asset pack is in `C:\Users\multi media\Downloads\dukan-brand-asset-pack`), coloured from the tokens:
- **Mobile `927fc11`:**
  - icon 1024, RGB with no alpha;
  - Android layers;
  - a static splash in light `#F1F3F8` and dark `#0B0F17`;
  - `BrandIntro`, a one-time 1060 ms animation that respects Reduce Motion;
  - the auth header mark;
  - `Palette.mark` tokens (`d26da94`);
  - `scripts/brand/` regenerates the assets.
- **Portal `bc112bda` / `7ddeea79`:** `ProductMark` uses the ledger mark (no inline style, because of the CSP); the portal has its own favicon and manifest.

**App config:** `supportsTablet` false, `userInterfaceStyle` automatic, `usesNonExemptEncryption` false. The EAS project is linked: `86a08e0d-578d-479f-986d-51706ea99522`, with `owner` `salah_rim` (`c369e5d`). EAS **production** environment variables have been created:
- `EXPO_PUBLIC_API_ORIGIN=https://api.tsxmr.com`;
- `EXPO_PUBLIC_LEGAL_ORIGIN=https://tsxmr.com`.

The `/in-app/*` legal pages are live in EN/FR/AR.

**Production, read-only inspection** (`ssh tsxmr-app-01`; the user loaded the key into ssh-agent):
- **API:** `erp-api:f5da650`, healthy; the rollback image `erp-api:644f4f5` is in `deployments.log`.
- **Database:** MySQL 8.4.11 at **0102** (101 migrations, none unfinished).
- **Data:** 2 Test companies, 2 users, 0 sales. One superadmin, with MFA.
- **Config:** `EMAIL_CHANNEL=disabled`; no WhatsApp channel (disabled); `CUSTOMER_ACTIVATION=closed`.
- **CORS:** dukan, erp-test and dukan-test. Disk 28 % used; 2.2 GB memory available.
- **Missing secret `api/referral_key`**, required by 0103. Create it with `deploy/production/setup-secrets.sh` before the deploy (docs/100 §17).

**Backup gate PASSED:**
- **Backup:** `phonestore-20261029T122234Z.sql.gz.age` (on the server, and copied to `C:\Users\multi media\.tsxmr\production-backups\`, with its checksum verified).
- **Restore drill** (`--offsite laptop`): every check passed — 121 tables, 59 triggers, checksums. The proof is recorded; the identity was removed from `/dev/shm`.

**Migration rehearsal PASSED:**
- The live schema dump at 0102 is identical to the local 0102 build.
- Representative rows, then 0103→0109: correct backfill, data preserved.
- The rehearsed schema equals a fresh build (0 diff lines out of 5,054).
- No destructive DDL; the only DROP lines are comments.

## Exactly where it stopped (mobile, uncommitted)

- **`eas.json`:** reverted to its pre-`c369e5d` form, with no `env` in the production profile; the origins now come from EAS environment variables. This makes `lib/release-origin.test.ts` pass again. It is staged.
- **`__tests__/promo-code.test.tsx` and `__tests__/invite.test.tsx`:** `fireEvent` calls are now awaited (testing-library 14 under SDK 58), and `toLastStep` and `fillLastStep` are async. **Unfinished:** `fillFields()` (around line 131) must become `async`, and its callers must `await fillFields()` / `await fillForm()`. `tsc` currently reports TS1308 at lines 132–133.
- Then:
  1. `npx tsc --noEmit`;
  2. commit;
  3. push;
  4. retarget render-tests: edit `MOBILE=` in `<scratchpad>/render-tools/target.env` on branch `ops/render-tests` (the visual-tools equivalent is `verify/target.env` on `ops/visual-check`);
  5. wait for render-tests, mobile security and visual-check to be green. Read evidence with `git fetch` in those worktrees; the GitHub API is limited to 60 requests per hour.

  The render-tests failures on `d26da94` were 9 cases, all in `promo-code` and `invite`.

## Remaining steps (in order)

1. **Finish the mobile CI fix above** and get every gate green on exact commits: backend security, portal CI, mobile render-tests, mobile security, and visual-check (Chromium/WebKit) with BACKEND `ca5c099` and MOBILE the new head.
   - Rerun the backend real-MySQL specs in CI (`deploy/ci-database-gates.sh` includes `deferred-verification.mysql.spec.ts`).
   - **Not yet done:** dedicated brand visual tests at 320/375/390 px, light/dark, EN/FR/AR and RTL, plus a check for no theme-boot flash. Add them or record them as an open gap.
2. **Merge the release** through the documented integration line, without rebasing or force-pushing. The backend production branch is `superadmin-provisioning` (`f5da650`), with rollback `production-deploy` (`644f4f5`). Record the final graph.
3. **Deploy** (docs/100 §6 and §17):
   1. `setup-secrets.sh`, which writes `referral_key`;
   2. a fresh backup (or reuse today's if nothing changed);
   3. bring in the bundle and `git checkout` the reviewed commit;
   4. set `CUSTOMER_ACTIVATION=open` in `/srv/erp-production/api.env`, and leave `PHONE_VERIFICATION_DEFERRAL` unset (off) until the checks pass;
   5. `deploy.sh --confirm api.tsxmr.com`, which runs the migrations 0103→0109;
   6. `verify-mysql-identities.sh` and the smoke test;
   7. rebuild and install the console with `test-sites.sh` (dukan-test.tsxmr.com).

   Then verify API, CORS, TLS, auth, audit and reporting. Enable deferral only after the checks pass, and only if the owner wants it for the pilot.
4. **Portal handoff:** the user creates the business, Owner, Manager and Employee in the portal and reports back. Claude does not create them.
5. **EAS build** (`eas build -p ios --profile production`). Apple signing needs the **user** to authenticate interactively, or an App Store Connect API key the Account Holder creates. Then:
   - check the archive for LAN/localhost addresses, secrets and source maps;
   - `eas submit`;
   - record the build ID, Apple build number, SHA and checksum.
6. **TestFlight:**
   - internal group: App Store Connect users only;
   - external private group "Dukan ERP Store Pilot" after Beta App Review (no public link);
   - review notes;
   - a fictional review account, whose credentials go only in App Store Connect's fields;
   - ask the user for tester emails at that point.
7. **Physical multi-iPhone tests** (a separate gate). The docs must record backup and rollback IDs. Release the handoff only after durable docs are committed and the temporary services are removed.

## Temporary things to clean up when finished

- **Local MySQL 3308** (hand-started) databases: `erp_dv_e2e`, `provisioning_dv`, `rehearsal_d224`, `fresh_d224`. All are disposable.
- **The local API** on port 3998 (`d224-dv-api` / `-off` in `.claude/launch.json`), plus its scratchpad `dv/secrets.json` (throwaway admin and keys). Stop the API, delete those files, and remove the launch entries.
- **Remind the user** to run `ssh-add -D` and `Stop-Service ssh-agent` from an elevated PowerShell when the server work ends.
