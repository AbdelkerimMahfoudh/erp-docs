# CURRENT_HANDOFF

Two phases ran in parallel on 2026-10-17, authorised by the owner, in repositories that do not overlap. Each has its
own status:

| Phase | Repositories | Status | Owner |
| --- | --- | --- | --- |
| Website production preparation: address, legal texts, portal individual mode (cloud session) | `erp-control-web` (+ its erp-docs entries) | **IN_PROGRESS** | CLAUDE (cloud) |
| Brevo SMTP + WhatsApp Cloud API (local session, the owner's PC) | `erp-backend` (+ its erp-docs entries) | IN_PROGRESS (see its section below) | CLAUDE (local) |

**Do not take `erp-backend` while the local phase is IN_PROGRESS, or `erp-control-web` while the cloud phase is.**
`erp-mobile` is free.

**Cloud phase, claimed 2026-10-17T04:56Z** (the owner's brief "Final Legal, Identity, Portal and Website Production
Preparation"):

- **Status:** IN_PROGRESS. **Owner:** CLAUDE (cloud session). **started_at_utc:** 2026-10-17T04:56Z.
- **Previous:** the public website phase, READY_FOR_HANDOFF / NONE, complete.
- **HEADs at takeover:** backend `1ed6b00`, mobile `e6773aa`, website `tsx-public-site` `0516a9c`, docs `2fb3b91`.
- **Scope:**
  - `erp-control-web`: the correspondence address; the six legal texts revised (approval flags stay draft); an
    individual-operator mode for the PORTAL gate and the portal copy; verification.
  - erp-docs: `docs/95`, `docs/96`, `docs/97`, this file, the session log and the decisions.
  - **`erp-backend` is not touched** (the local phase owns it); it is read only, for contracts.
  - No merge, deploy, Cloudflare, SMTP or WhatsApp change.
- **Next intended action:** read the portal's identity and billing assumptions, then the address configuration.

Public website phase: previous_owner CLAUDE (cloud session), 2026-10-17T03:55Z → 2026-10-17T04:55Z, complete. The
owner asked for a single `CLAUDE` identity from now on (no CLAUDE-A / CLAUDE-B).

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


## Second active phase, in parallel (owner-authorised, 2026-10-17T04:30Z)

Status: IN_PROGRESS
Owner: CLAUDE (local session, the owner's Windows PC)
started_at_utc: 2026-10-17T04:23Z
authorisation: the owner chose to run this phase in parallel with the cloud session above. Repositories do not
overlap: this phase changes **erp-backend** only (plus its own erp-docs entries); the cloud session changes
erp-control-web. Each pulls erp-docs before every push and leaves the other's entries intact.
active_phase: Brevo SMTP + WhatsApp Cloud API backend integration, Phases 2–5 (docs/21 D181).
scope: erp-backend (messaging, OTP delivery, consent, migration 0098 on a disposable database only). No deployment,
no live switch, no real message, no migration on the PC or live database.
baseline: backend `reports-export` `1ed6b00`, mobile `e6773aa` (untouched), website `0288d8a` (not touched here).
next_action: the SMTP channel (nodemailer), then the WhatsApp controls, queue and consent.

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
