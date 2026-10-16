# CURRENT_HANDOFF

Status: READY_FOR_HANDOFF
Owner: NONE
last_owner: CLAUDE-B (cloud session), 2026-10-13T03:13Z → 2026-10-16T05:10Z — complete
last_phase: the website-only seven-day free trial, its review round and the add-on rule of 2026-10-15 (`docs/76`,
D169–D177)

## HEAD of every repository

All four are pushed, clean and level with their remotes. These are the final commits of the free-trial phase.

| Repository | Branch | HEAD | Notes |
| --- | --- | --- | --- |
| `erp-backend` | `reports-export` | `6a4cfc0` | `80c9133` plus one comment-only commit; the real-HTTP run and the gates ran on `80c9133` |
| `erp-mobile` | `reports-export` | `a8b48c4` | |
| `erp-control-web` | `tsx-public-site` (**not merged**) | `8efa902` | `main` is `0417bfe`, untouched |
| `erp-docs` | `master` | the commit carrying this file | |

Another ref: the clean, detached worktree `/home/user/erp-backend-seed` (`d88893a`, an earlier phase's QA seed work)
is left as it was.

## What the phase delivered

- **The trial (D169–D175):** one seven-day trial per self-registered business, claimed only by the Owner signed in on
  the website, with or without the message's link; setup instructions sent automatically after verification; resend
  only on the website; the app display-only; instants in UTC shown in the business's zone; app sign-up restored (D170);
  console-made businesses ineligible (D171); paid or granted access approved during a trial starts at its end (D172).
- **The review round:** 35 findings from five adversarial reviewers (3 blockers, 10 majors, 21 minors, 1 nit). 31
  fixed; R5-5 fixed in code but not verified on a phone; R1-F3 fixed in its records, its timing awaiting the owner
  (PQ7); R4-04 and R5-4 awaiting the owner, unchanged. Every fix was checked by independent verifiers, whose own
  findings were fixed. The table with commits and tests is in `docs/76` §12.
- **Stores and seats paid for during a trial (D176):** scheduled to the trial's end, charged once, put in force at the
  end in one transaction that never waits on a lock, with a sweeper within a minute. The owner's 14 required tests
  pass.
- **Every contact given at registration must be verified (D177).**

## Databases

- `phonestore` (the PC's development database) is still at `0091_stabilization`. It was not touched.
- No live or production database exists, and none was touched.
- Migrations `0092`–`0097` exist in `reports-export` and are applied nowhere shared. `0095`, `0096` and `0097` were
  rehearsed with a backup and a restore check on disposable copies only (`docs/22`).
- **`0097_scheduled_addons` needs the owner's approval before any shared database sees it.**
- Every disposable database of this phase is dropped, the `phonestore_app` grants on them are revoked, and no API or
  server process is running.

## Verification (final commits)

- **Backend `80c9133`:** `prisma validate` and `tsc` 0; Jest 234 suites passed, 1 skipped (the env-gated MySQL spec),
  4 416 tests passed, 24 skipped; the MySQL add-on spec 21/21, three runs; secret scan clean.
- **Mobile `a8b48c4`:** `tsc` 0; lint 0 errors, 29 warnings; pure tests 113 files passed; rendered tests 253 / 253;
  release configuration sound; fresh web and iOS exports pass the bundle audit, and every reviewer's and verifier's
  injection is caught.
- **Website `8efa902`:** typecheck 0; Vitest 295 / 295; `build:preview` 36 pages; links 1 659, 0 broken; bundle audit
  PASS; Playwright 114 / 114.
- **Real HTTP, from a fresh disposable database at `0097`:** 188 product checks passed, 0 failed, 0 skipped, plus 1
  harness precondition. No secret in the API log across the run (123 secrets handled), on successful and failing
  requests.
- **Screenshots against the real API:** 108 (EN, FR, AR; 375 and 1 280 px; before and after the trials' end), no
  sideways scroll.
- **Not verified on any physical phone:** the whole app side (`docs/24` §66).

## Awaiting the owner (`docs/21`, `docs/76` §16)

1. Approval of migration `0097` before any shared database, and one release window for the API (`0092`–`0097`) and
   the website.
2. R4-04 (the terms sentence) and R5-4 (the both-contacts Owner's path to the WhatsApp verification).
3. PQ1–PQ17, the defaults D176 is built on.
4. A business closed by its Owner around a payment confirmed during its trial.
5. The setup status after an earlier send went out and the latest attempt failed.
6. Wording to review, server English on the website, and small presentation questions.
7. Payment rows the application account may update (a pre-existing schema question).
8. The logo: four concepts delivered, no choice yet.

## Blockers carried over

- **Credentials:** WhatsApp (WABA, number, token, app secret, approved EN/FR/AR templates under Dukan ERP); an email
  provider and a sending domain; `PLATFORM_MFA_KEY` per environment.
- **The owner's operations:** link an EAS project `dukan-erp` (`docs/44`); the Apple Developer membership and the App
  Store Connect record `mr.tsxmr.dukanerp`; the Google Play app; `RECORD_AUDIO` on Android.
- **Decisions and reviews:** the backup retention period; legal review (privacy, terms, deletion, TSX-MR's identity);
  the logo.
- **Device verification:** `docs/24` §65 (identity) and §66 (the trial).

## Next exact action

The owner's next brief (2026-10-16) is a **production-readiness audit and defect-fixing phase** for TestFlight under
TSX-MR. It may start now: claim this file (`IN_PROGRESS`, the account, the start time, the HEADs above) before changing
anything. It authorises no deployment, publication, App Store or TestFlight upload, DNS change, purchase, provider
activation, live-database operation or real customer data.

Independently of it, when the owner is ready: answer the questions above, first `0097` and the release window; then run
`docs/24` §65 and §66 on a physical Android phone and an iPhone against a test API.
