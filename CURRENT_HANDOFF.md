# CURRENT_HANDOFF

Status: IN_PROGRESS
Owner: CLAUDE (local session, the owner's PC)
started_at_utc: 2026-10-17T08:32Z
active_phase: the tsxmr.com redesign — the owner's brief of 2026-10-17: implement the approved dark Dukan ERP direction in
erp-control-web on every public page (EN/FR/AR, RTL), verify through the repository's gates, preview, then promote.
scope: erp-control-web only, on a new branch from tsx-public-site 6016b8a; production stays on 6016b8a (Pages deployment
b4737b88, the rollback point) until the promotion step. erp-docs for the record. Backend, mobile, DNS, email, SMTP,
WhatsApp, Meta, App Store: untouched.
baseline: web tsx-public-site 6016b8a · backend reports-export d0a7495 · mobile reports-export e6773aa · docs deef5d5.
next_action: read the site's chrome, styles, routes and gates; build the design tokens and components; then the pages.

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
