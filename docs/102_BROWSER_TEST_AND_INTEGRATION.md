# 102 — Integration and the phone-browser test (2026-10-19, CLAUDE, cloud)

**Status: integration branches built, tested and pushed. Nothing is merged, deployed, migrated, activated, bought or
opened to the public.** The protected browser-test site is prepared and rehearsed locally. Deploying it is blocked on
the owner's inputs (§8), first of all a staging host: production now occupies the only server.

The owner's brief: resolve the Expo patch drift; integrate the website and the portal; prepare the ERP's browser build
and a protected test deployment; prove the user journeys against a disposable API; prepare the deployment handoff.

## 1. Branches

| Repository | Branch | HEAD | Built on | What it adds |
| --- | --- | --- | --- | --- |
| `erp-backend` | `integration/browser-test` | `b0758c2` | `whatsapp-consent` `608e25a` | `7445d2b` the QA fixture registers with the mandatory number and the Owner's consent; `b0758c2` the staging edge's protected browser-test site (§4) |
| `erp-mobile` | `integration/browser-test` | `d7a28fe` | `whatsapp-consent` `23ec6fd` | `5fe0287` Expo patches (§2); `0e008d6`, `bacf3c8` browser fixes (§4); `6b69432` the web routes and the release script (§4); `74d6685` a test count and references; `d7a28fe` the bundle audit's pin (a native bundle carries no `window.open`) |
| `erp-control-web` | `integration/browser-test` | `cd512c2d` | `whatsapp-consent` `4764afd` | a no-ff merge of `tsx-public-site` `bf62a72` (production tsxmr.com), no conflict |

Production is untouched: backend `production-deploy` `644f4f5` (api.tsxmr.com, migrations to `0098`) and web
`tsx-public-site` `bf62a72` (tsxmr.com).

## 2. The Expo patch drift (mobile `5fe0287`)

- **To the SDK 57 patches `expo install --check` named, nothing else:**
  - expo 57.0.30, expo-camera 57.0.6, expo-document-picker 57.0.3, expo-image-picker 57.0.20, expo-linking 57.0.13,
    expo-router 57.0.28, expo-sharing 57.0.23, expo-splash-screen 57.0.10;
  - jest-expo `~57.0.6`; expo-constants 57.0.22 within its existing range;
  - in the lockfile, the Expo family's own patches and `@radix-ui/react-focus-guards` 1.1.6 → 1.2.0 (pulled by
    expo-router).
- **The Android camera patch** was re-cut for expo-camera 57.0.6: `patches/expo-camera+57.0.6.patch`, hunks
  byte-identical (the package's `android/src` is identical between the two versions), and `verify-native-patch.js`
  names the new version.
- **Gates:** `tsc`; lint 0 errors (28 warnings, the baseline); pure tests; Jest; web and iOS exports; the bundle audit;
  the release refusal; the secret scan; the shipped-dependency audit; **Expo Doctor 21/21**.
- **Remaining:** the camera patch on a physical Android phone (`docs/24` §68 A1). Nothing else is blocked.

## 3. The website and the portal (web `cd512c2d`)

- **Two build surfaces, from the one commit:**
  - **tsxmr.com** is the public surface (`VITE_SITE_SURFACE=public`). It holds no protected route: `/subscription`,
    `/account` and `/admin` answer 404.
  - **dukan.tsxmr.com** is the portal surface (`VITE_SITE_SURFACE=portal`). `/` answers 302 to `/subscription`,
    `/account*` answers 301 to `/subscription`, and `/subscription*` and `/admin*` serve the application shell.
- **The public production build is the production site.** It was built with the same four values as production
  (`npm run build:public-release`). After normalising hashes, every page matches production's `bf62a72`. The
  stylesheet only adds the portal's classes. `robots.txt` drops its `Disallow: /account, /admin` lines, as intended
  since `feca99a`: that surface has no protected prefix.
- **Gates:**
  - typecheck clean;
  - Vitest 34 files, 548 tests;
  - link and bundle audits PASS on the portal (3 pages), full (76) and public (66) preview builds;
  - Chromium e2e: full 138/138, public 160/160, portal 34/34.
- **The production portal build is refused by design.** The PORTAL gate lists 12 `legal_blocker` and 6
  `legal_draft` items. They are owner and counsel inputs (§8).
- **WebKit e2e not run.** This environment cannot install browsers, and the web CI installs Chromium only.
- **A risk to check before pushing more web branches:** whether the Cloudflare Pages project builds preview branches
  (the owner's setting). This branch carries only reviewed code; a preview of it would be noindexed but public.

## 4. The ERP in a browser

Expo's static web export of `erp-mobile`. The audit:
- drove every static screen (72 at the time, signed in as an Owner);
- read every native-module import for its web branch;
- then ran the journeys of §6.

**Already sound** (no change needed):
- sessions in `localStorage` (no secure store on the web);
- the API origin from `EXPO_PUBLIC_API_ORIGIN`;
- the web explicitly online-only, with no offline queue or drafts, and the Sync centre says so;
- reports open in a tab, and CSV downloads as a file;
- file and photo uploads use `FormData`;
- the browser guard opens a new tab only for a `blob:` page;
- no `Alert` dialogs.

**Fixed:**

| Found | Fix | Commit |
| --- | --- | --- |
| Pressing Continue with the WhatsApp consent unticked threw `sendAccessibilityEvent is not a function` (registration, joining a team, communication preferences) | `lib/accessibility-focus.ts`: on the web the element takes focus and the screen reader follows; phones keep the native event | `bacf3c8` |
| No browser screen reader heard a checkbox, switch, tab or disclosure state. react-native-web 0.21 reads only the flat `aria-*` props; the consent box had no `aria-checked` | every `checked`, `selected`, `expanded` and `busy` state is also given as its `aria-*` prop (React Native maps them natively); `lib/web-accessibility.test.ts` keeps it | `bacf3c8` |
| The customer's receipt was hidden on the web | it opens in a new tab, where the browser prints it or saves a PDF (`lib/browser-tab.ts`, shared with the report preview) | `0e008d6` |
| The refund receipt (it needs a fetch, so a browser would block the tab) showed nothing | "The refund receipt is shared from the phone app." | `0e008d6` |
| The scanner's web notice said "This device has no camera", which is wrong on a phone | "Scanning is in the phone app" — type the IMEI, serial or barcode instead, checked the same way (EN/FR/AR) | `0e008d6` |
| The invitation's *Share* did nothing in a browser without a share sheet | there *Copy* is offered alone | `0e008d6` |
| A file server finds `sales/period.html` but not `sales/[id].html`: a reload or a link to `/sales/<id>` answered "not found" | `lib/web-routes.ts` reads the export: a file that exists first, then each dynamic page most specific first, then the not-found page with a 404 — written as a Caddy fragment by `scripts/web-test-release.mjs` | `6b69432` |

**Unsupported in a browser, and labelled as such:**
- the camera scanner (typing is permanent and equal);
- the native share sheet (the receipt opens in a tab instead; the refund receipt is shared from the phone app);
- offline work (online only, said in the Sync centre);
- push notifications (none on the web);
- the `dukanerp://join` link opens the app, not a browser — an employee types the reference, which is the primary,
  permanent way (D214).

**Kept by decision:** no staging banner. It was taken off in `277fb7e`; `lib/identifier.test.ts` keeps it off. The
test site's separation is its password, its own database and its own hostname.

## 5. The protected test deployment

**Design** (D215; the runbook is `docs/99` §14):
- the export is served by the **staging Caddy edge**, beside the staging API, on **its own hostname**;
- the record is **DNS only**, so Caddy's certificate is for exactly that name;
- **one alias**: no platform domain and no preview address that could skip the lock;
- **basic authentication on every path**, the bundles included. Without a password every page and script answers 401.
  `noindex` is sent as well, but it is not the protection.

**Hostname and TLS (the owner confirms before any record exists):**
- Proposed: **`erp-test.tsxmr.com`**, one level under `tsxmr.com`, beside `staging-api.tsxmr.com`.
- With a DNS-only record, Caddy obtains a Let's Encrypt certificate for that exact name over HTTP-01. Ports 80 and 443
  must reach the host.
- **Do not assume another name is covered.** Cloudflare's Universal certificate covers `tsxmr.com` and one level of
  `*.tsxmr.com`, and only for proxied records. A nested name (`erp.test.tsxmr.com`, `x.dukan.tsxmr.com`) would need
  Advanced Certificate Manager if it were ever proxied. A first-level, DNS-only name avoids both questions.

**Security:**
- **No credential in the build:**
  - the export carries only the API origin;
  - the password is given to testers out of band;
  - `stack.env` holds only its bcrypt hash.
- **Exact CORS:** `web-test.sh` refuses to enable the site unless the API's `CORS_ORIGINS` names
  `https://erp-test.tsxmr.com` exactly. The staging preflight refuses a wildcard, a path or `http`.
- **Normal enforcement:** the API is the staging API, with tenancy and roles as in production. The browser holds an
  ordinary session.
- **Fictional data only:** staging's own database (`docs/99` §4.2) and the reserved numbers `+1 202 555 01xx`.

**Rehearsed locally** with the real export, the committed `web-test.caddy` and `routes.caddy`, and Caddy 2.8.4
(checksum-verified; the stack pins `caddy:2.8`):
- without a password, `/`, `/login` and the bundles answer 401;
- with it, each path is served by the right file, byte for byte:
  - `/`, `/sales`, `/sales/period` and `/agent/providers` by their own pages;
  - `/sales/<id>`, `/sales/pay/<id>`, `/agent/<id>` and `/agent/providers/<id>` by their dynamic pages;
  - `/nope` and `/sales/1/2` by the not-found page, with a 404;
- headers: `X-Robots-Tag`, `X-Frame-Options: DENY`, HSTS, nosniff, no `Server`. Bundles are immutable and pages are
  `no-cache`;
- the API through the same edge answers `/api/health/ready` 200;
- `web-test.sh` refuses, before touching anything:
  - an unset, malformed or production hostname, or the API's own;
  - an unset user or a non-bcrypt hash;
  - CORS that does not name the site;
  - an incomplete release.
- `web-test-release.mjs` refuses an origin that is not exact https, production's API, or not the one the bundle was
  built for.
- Compose keeps the bcrypt hash literal: single-quoted in `stack.env`.
- **CI** (backend `security.yml`) validates the staging edge with the site off, and on with a release.

## 6. The journeys, proven against a disposable API and database

**Setup:**
- a scratch MySQL 8.4.11 with schema `prisma_qa_browser`, migrated to `0101` by `phonestore_migrator`;
- the API of backend `integration/browser-test` as `phonestore_app`, with WhatsApp and email on the
  development-log channels;
- the web export served the way the edge serves it;
- the portal's preview build (`VITE_SITE_SURFACE=portal`) against the same API;
- the QA fixture's ten fictional boutiques (`--verify` 64/64, including cross-tenant refusals);
- codes read back from their hashes in that database — no message left the machine;
- headless **Chromium** at 390 × 844, touch and mobile emulation.

| Journey | Checks | Result |
| --- | --- | --- |
| Sign-in and sign-out | sign-in to the branch choice and home; sign-out returns to sign-in and leaves no token in `localStorage` | PASS |
| Owner registration and consent | unticked: nothing sent, no script error; the box announced unticked (`aria-checked=false`); the code screen shows only `***0120`; after the code the Owner's consent is `active`; the business waits closed | 8/8 PASS |
| Portal and trial claim | portal sign-in with the app's details; *Start my 7-day free trial* → *Yes, start it now*; one claim recorded; the app opens on *check again* | in the same 8/8 |
| Employee invitation and activation | the only store preselected and announced; creating sends nothing (0 verifications); the reference shown once; *Share* only where the browser has a share sheet; the clear reference **nowhere in a full database dump or the API log**; on the employee's phone: the reference typed in lowercase with spaces, no code before the box is ticked, the code and a first password activate, sign-in works; the server refuses the employee the Owner's team route (403) | 10/10 PASS |
| Stock intake and sale | a phone received by **typing** its IMEI (no camera), the cost pre-filled, then in stock; sold with *Charge* → *Confirm payment*; the receipt opens in a `blob:` tab with the IMEI and no cost or margin; the same IMEI again is shown *Sold* and nothing is added | 5/5 PASS |
| Read-only after expiry | a business 10 days past its period end: home says "Business access has ended — reading and exports only"; stock readable; the sell screen says nothing new can be saved; the server refuses a new expense (403) | 5/5 PASS |
| Every static screen | 72 screens as an Owner, each loaded from a full reload | no script error |

**What stays blocked on real WhatsApp delivery.** The test site runs with WhatsApp and email `disabled` and
`STAGING_CONTACT_OUTBOX=enabled`.
- **Works, with an operator in the loop.** Owner registration and employee activation work end to end. Each code is
  held in the staging outbox, the operator reads it with the keyed lookup on the host (`docs/99` §6.4) and passes it to
  the tester. Staging never returns a code in a response.
- **Blocked until real delivery:**
  - a tester receiving their own code on their own WhatsApp;
  - the portal instructions message after registration (the trial can still be claimed: the Owner signs in to the
    portal directly);
  - the 72/48/24 h reminders and grace notices;
  - STOP and START replies;
  - the daily and monthly WhatsApp reports.
- Real delivery needs `docs/98`: the Meta proofs, test mode, the allowlisted numbers and approved templates.

## 7. Phone layouts

**Chromium, 81 screens:**
- 3 languages × (light and dark at 390 pt, light at 320 pt);
- 9 screens each: sign-in, join, home, sell, stock, team, communication preferences, business access, more;
- dark is the in-app Appearance choice (light is the documented default), set as a person would.

**Results:**
- **no horizontal overflow**;
- `dir=rtl` on every Arabic screen and `ltr` on the others;
- dark surfaces `rgb(11, 15, 23)`;
- **no script error**;
- read by eye: numbers and masked numbers stay left to right inside Arabic, and the agreement text wraps.

**Not done, and not claimed:**
- **WebKit automation.** No WebKit build exists in this environment, and browsers cannot be installed here. Adding
  Playwright to the mobile repository would be a new dependency, which needs approval.
- **No physical iPhone check.** Safari on a real iPhone is `docs/24` §68 (NOT DEVICE VERIFIED). Browser automation
  emulates a phone's viewport and touch, not iOS Safari's engine, keyboard or safe areas.

## 8. The deployment handoff

### 8.1 The browser-test site (staging; approval needed for the host and DNS)

1. **The host (owner).** A second small Linux host meeting `docs/99` §11, hardened as `docs/99` §13. It must **not**
   be `tsxmr-app-01`: production runs there (`docs/100` §14), and staging never shares a host with production.
2. **DNS (owner, Cloudflare, after confirming the names):**

   | Name | Type | Value | Proxy |
   | --- | --- | --- | --- |
   | `staging-api` | A | the staging host | DNS only |
   | `erp-test` | A | the staging host | DNS only |

3. **The staging API** from backend `integration/browser-test` `b0758c2`, per `docs/99` §6. In `api.env`, beyond
   §4.1:
   - `STAFF_INVITATION_KEY`: 48 random bytes, staging's own;
   - `CORS_ORIGINS=https://erp-test.tsxmr.com`, adding the portal-test origin if one is made (step 6);
   - `PORTAL_ORIGIN`: an https origin that is not `https://dukan.tsxmr.com` (e.g. `https://dukan-test.tsxmr.com`).
     The preflight requires it even before a staging portal exists;
   - `STAGING_CONTACT_OUTBOX=enabled`, `EMAIL_CHANNEL=disabled`, `WHATSAPP_CHANNEL=disabled`.

   `deploy.sh` applies every migration to `0101` on staging's own empty database; it takes its backup first.
4. **The release (any machine with the mobile checkout):**

   ```bash
   cd erp-mobile   # integration/browser-test d7a28fe
   EXPO_PUBLIC_API_ORIGIN=https://staging-api.tsxmr.com EXPO_PUBLIC_APP_ENV=staging \
   EXPO_PUBLIC_LEGAL_ORIGIN=https://tsxmr.com npx expo export --platform web --output-dir /tmp/erp-web-export --clear
   node scripts/web-test-release.mjs /tmp/erp-web-export /tmp/erp-web-release https://staging-api.tsxmr.com
   ```

   Copy `/tmp/erp-web-release` to the host (e.g. `scp -r` into the deploy user's home).
5. **Enable the site (host, as the deploy user).**
   - In `deploy/staging/stack.env`:
     - `STAGING_WEB_HOST=erp-test.tsxmr.com`;
     - `STAGING_WEB_DIR=/srv/erp-staging/web`;
     - `STAGING_WEB_USER=<tester login>`;
     - `STAGING_WEB_PASSWORD_HASH='<bcrypt>'` (from `docker run --rm -it caddy:2.8 caddy hash-password`, typed at its
       prompt).
   - Then `deploy/staging/web-test.sh install ~/erp-web-release`. It validates the edge before restarting it, and ends
     by checking 401 without a password.
6. **Optional: a staging portal**, for the trial-claim journey on the test URL. This is the portal surface built in
   preview mode with `VITE_API_BASE=https://staging-api.tsxmr.com/api/v1`, on its own protected name (for example
   `dukan-test.tsxmr.com`). Its hosting and protection are a separate owner decision. Without it, a test business is
   opened by the platform administrator's grant.
7. **Test accounts.** Fictional only, made through the site's own sign-up, with codes from the outbox (step 3).
8. **Rollback and teardown:**
   - `ln -sfn releases/<previous> /srv/erp-staging/web/current && deploy/staging/web-test.sh restart-edge` puts back
     the previous release;
   - `web-test.sh off` removes the site (the releases stay on disk);
   - the API's own rollback is `docs/99` §8.

### 8.2 Production, when the owner approves the rollout (not in this phase)

- **Backend.** The commit to deploy is the merged `whatsapp-consent` line. Backend `integration/browser-test` adds
  only the QA fixture and staging files, neither of which affects production. The steps (`docs/100` §6, `docs/101`
  §17.7):
  1. bring the reviewed commit to the host as a bundle;
  2. `deploy/production/setup-secrets.sh` creates `staff_invitation_key` and replaces nothing. The API refuses to
     start without it;
  3. a verified backup per `docs/22`;
  4. `deploy/production/deploy.sh --confirm api.tsxmr.com` builds the image, then migrates `0099` → `0100` → `0101`
     in one run as `phonestore_migrator`, then smoke tests;
  5. existing pending employees need their Owner's *New invitation*.
- **Rollback.**
  - Code: `deploy/production/rollback.sh erp-api:644f4f5… --confirm api.tsxmr.com`. The migrations are additive, so
    the older image ignores the new tables.
  - Database: only by the owner's decision, after a fresh backup: the reverse SQL in `docs/101` §17.7 (0101, 0100)
    and §13 (0099).
  - **A Git rollback does not roll back the database.**
- **tsxmr.com** (its existing Pages project).
  - Build web `integration/browser-test` with `npm ci && npm run build:public-release` and the four production values
    (`VITE_SITE_SURFACE=public`, `VITE_PUBLIC_SITE_ORIGIN=https://tsxmr.com`, `VITE_ORGANIZATION_PHONE`,
    `VITE_LEGAL_EFFECTIVE_DATE`).
  - The output matches today's site page for page.
  - Rollback: the previous Pages deployment.
- **dukan.tsxmr.com** (a new Pages project; owner: the project and its DNS record).
  - The same commit with `npm ci && npm run build`, `VITE_SITE_SURFACE=portal`,
    `VITE_PORTAL_ORIGIN=https://dukan.tsxmr.com`, `VITE_PUBLIC_SITE_ORIGIN=https://tsxmr.com`,
    `VITE_API_BASE=https://api.tsxmr.com/api/v1` and the legal facts.
  - Refused today by the PORTAL gate until its legal texts are approved.
  - Production's `CORS_ORIGINS` already names it.
- **The backup and onboarding gates stay as they are:**
  - the customer-data gate of `docs/100` §5;
  - registration closed (`registration_unavailable`) while email and WhatsApp are disabled;
  - no public onboarding.

### 8.3 Owner and provider inputs

1. Approval of the test deployment, and separately of the Cloudflare and DNS changes.
2. **A staging host** (step 1), and its `ACME_EMAIL`.
3. **Confirmation of the names:** `staging-api.tsxmr.com` and `erp-test.tsxmr.com`, both DNS only (§5), and
   `PORTAL_ORIGIN` for staging.
4. The testers' login name. The password is chosen by the owner or the operator and given to testers out of band.
5. Whether a staging portal is wanted (step 6), and where it is hosted and protected.
6. For real WhatsApp in the test: `docs/98` (the Meta proofs, test numbers, templates).
7. For production later: the rollout approval; the portal's legal texts (the PORTAL gate); the Pages project and DNS
   for `dukan.tsxmr.com`; the Cloudflare Pages preview-branch setting (§3).

## 9. The shortest path to a working browser-test URL

1. The owner provides the staging host and confirms the two names.
2. The owner adds the two DNS-only records.
3. The operator deploys the staging API from `b0758c2`, as §8.1 step 3 describes: about an hour on a prepared host,
   per the rehearsal.
4. The operator builds and packages the release (two commands), copies it, sets the four `STAGING_WEB_*` values and
   runs `web-test.sh install`.
5. The operator creates a first fictional Owner through the site, with the code from the outbox, and opens it with a
   grant (or with a staging portal, step 6).
6. The owner gives the testers `https://erp-test.tsxmr.com`, the login and the password, separately.

**Everything in steps 3–5 exists and has been rehearsed. Only steps 1–2 and the approvals are missing.**
