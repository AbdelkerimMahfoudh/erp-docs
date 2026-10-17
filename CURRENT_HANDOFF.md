# CURRENT_HANDOFF

Status: IN_PROGRESS
Owner: CLAUDE-B (local, the owner's Windows PC)
started_at_utc: 2026-10-17T01:18Z
previous_handoff: READY_FOR_HANDOFF / NONE from CLAUDE-B (cloud session), 2026-10-16T13:35Z — complete; all four trees
clean and level with their remotes at takeover
active_phase: publishing the existing public website at https://tsxmr.com on Cloudflare Pages (the owner's brief of
2026-10-17). Audit and repository preparation only: no deploy, no merge, no DNS change, nothing public until the owner
approves the verified build and the final screenshots. Mobile, scanner, refund and backend feature work stopped (none
was in progress).

Baseline at this takeover: backend  , mobile  , website
  ( , 78 behind), docs  .

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
