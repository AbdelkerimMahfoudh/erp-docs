# CURRENT_HANDOFF

Status: IN_PROGRESS
Owner: CLAUDE-B (cloud session)
started_at_utc: 2026-10-13T03:13Z
previous_handoff: READY_FOR_HANDOFF / NONE from CLAUDE-B (local, the owner's Windows PC), 2026-10-12T10:00Z → 15:30Z —
complete; all four trees were clean and level with their remotes at takeover
active_phase: the website-only seven-day free trial (the owner's brief of 2026-10-13, with its customer-discovery
addendum)

## HEAD of every repository at takeover

| Repository | Branch | HEAD at takeover |
| --- | --- | --- |
| `erp-backend` | `reports-export` | `aad5862` |
| `erp-mobile` | `reports-export` | `02f2e4e` |
| `erp-control-web` | `tsx-public-site` (**not merged**; `main` still `0417bfe`) | `e892a27` |
| `erp-docs` | `master` | `db3f94a` |

## Scope approved by the owner (2026-10-13)

The plan was explained (findings, design, files, risks) and approved with three decisions:

1. **Business sign-up returns to the app** — reverses D117. Creating the account in the app never starts a trial.
2. **Businesses created by the Super Admin are not trial-eligible**; only self-registered new businesses are.
3. **Paid access approved during a running trial starts when the trial ends** (the trial is never shortened,
   extended or rewritten).

Binding from the brief: the trial is claimed and activated **only on the website**, by the Owner, once per business,
starting at the server's claim instant and ending exactly 168 hours later; no payment, no Super Admin approval; the app
shows eligibility and sends setup instructions to verified contacts, with no claim, link, QR, WebView, price or
subscription action; existing businesses get no trial; disposable data only.

## Databases

- `phonestore` (the PC's development database, 3308): still at `0091_stabilization` — not touched by this session.
- No live/production database exists or will be touched. Migration `0095` (planned) is rehearsed only on a disposable
  MySQL inside this cloud container, with a backup and a restore check first (`docs/22`).
- Migrations 0092–0094 exist in `reports-export` and are not applied to the PC database; deploy the API and 0092–0094+
  together.

## Next intended action

Backend: the trial's facts (migration `0095_free_trial`), the computed states, the claim, setup links and delivery, the
restored registration routes, and the deferred paid start — then the website, then the mobile app, then the docs.

## Blockers carried over (`docs/75` §13)

Credentials (WhatsApp WABA/number/token/app secret/approved EN-FR-AR templates; email provider and a sending domain;
`PLATFORM_MFA_KEY` per environment) · the backup retention period · legal review (privacy, terms, deletion, TSX-MR's
identity) · the owner's decision on the app identifiers · Dukan ERP WhatsApp template texts · logo (four concepts
delivered; awaiting the owner's choice).

## Concurrent phase — CLAUDE-B (local, the owner's Windows PC): the final technical identity and a clean HTTP rerun

Status of this phase: **IN_PROGRESS** · Owner: **CLAUDE-B (local)** · started_at_utc: 2026-10-13T03:22Z (the owner's
brief; read-only takeover until this claim). The brief runs this phase beside the free-trial phase above and says to
work around it without overwriting it. **The free-trial phase is not finished**: its owner is the cloud session
(claimed 03:13Z); at 03:36Z no free-trial commit had reached any code repository. This phase therefore stays out of its
files, and the status above stays theirs.

HEADs at this claim (fetched 03:36Z; all four trees clean and level with their remotes): backend `reports-export`
`aad5862`, mobile `reports-export` `02f2e4e`, website `tsx-public-site` `e892a27` (`main` `0417bfe`), docs `master`
`bfa2e31`.

**Scope (the owner's binding identity):** product **Dukan ERP**, operator **TSX-MR**, Expo slug `dukan-erp`, scheme
`dukanerp`, iOS bundle identifier and Android package `mr.tsxmr.dukanerp`. Also the deep links, the visible-name audit,
the QA script's MFA flow, a clean 51-check HTTP rerun on a fresh disposable database, the test gates, and the docs.

**Kept clear of (the free-trial scope):** backend registration, platform and subscription, trial, template and messaging
code; migration `0095`; the website's trial pages; the mobile registration and eligibility screens. The shared docs
(this file, `SESSION_LOG.md`, `docs/21`, `24`, `67`, `74`, `75`) get additive sections only.

**Precondition — no published or production identity exists for the old identifiers** (so the new ones are used and no
second store identity is created):
- App Store Connect: no record. There is no Apple Developer membership (`docs/67` §8, `docs/21`), so there has never
  been a TestFlight or App Store build.
- Google Play: no app. No document, script or credential refers to one.
- EAS (`eas build:list`, read-only, account `salah_rim`, project `834d8b25-…`): three builds, all **Android preview,
  internal distribution** of `mr.retailerp.app` (2026-09-01 errored, 2026-09-01 and 2026-09-08 finished). There are no
  production, iOS or store builds.
- Push: `expo-notifications` is not installed, so there are no push credentials. EAS Update: `expo-updates` is not
  installed, so there are no channels.
- `retailerp://`: nothing outside `app.json` produces or receives it. The backend's messages carry codes, not app links,
  and the website has no app link.

**Discrepancies reported:**
1. The free-trial phase is still running (above).
2. `eas.json`'s `development` profile asks for a development client, but `expo-dev-client` is not installed. The owner
   works in Expo Go.
3. The internal preview APKs of `mr.retailerp.app` may be installed on test phones. A build under the new package
   installs **beside** them, not over them.
4. `local-scripts/boutiques-local.ts` (outside every repository) still signs in to the console without the second factor
   (already recorded on 2026-10-12).

**Next intended action:** the mobile identity (`app.json`, then the deep-link and config tests), the backend's
remaining old names in comments and package names, the website's metadata audit, then the clean HTTP rerun and the
gates. Docs are updated last.
