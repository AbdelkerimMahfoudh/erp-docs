# CURRENT_HANDOFF

Status: IN_PROGRESS
Owner: CLAUDE-B (cloud session)
started_at_utc: 2026-10-16T12:36Z
previous_handoff: READY_FOR_HANDOFF / NONE from CLAUDE-B (cloud), the production-readiness phase, 2026-10-16T04:32Z →
12:20Z — complete; all four trees clean and level with their remotes at takeover (fetched 12:36Z)
active_phase: legal pages, privacy disclosure and Apple-submission readiness (the owner's brief of 2026-10-16), with a
line-by-line production-readiness check of the code. Authorised: source, website content, tests, documentation. Not
authorised: publishing, DNS, deployment, production credentials, providers, live data, TestFlight or App Store
upload, accepting legal wording on behalf of TSX-MR.
next_intended_action: build the factual data inventory from the code, then the public legal/support routes on the
website, the app links, the release guard, the Apple worksheets and the deliverables.

## Baseline at takeover (2026-10-16T12:36Z)

| Repository | Branch | HEAD | Upstream |
| --- | --- | --- | --- |
| `erp-backend` | `reports-export` | `06a0db7` | level, clean |
| `erp-mobile` | `reports-export` | `b23badb` | level, clean |
| `erp-control-web` | `tsx-public-site` (not merged; `main` `0417bfe`) | `0eedfaa` | level, clean |
| `erp-docs` | `master` | `6e2a462` | level, clean |

---

The previous phase's final snapshot follows, unchanged.

## HEAD of every repository

| Repository | Branch | HEAD | Notes |
| --- | --- | --- | --- |
| `erp-backend` | `reports-export` | `06a0db7` | CI run 38898384642 green (secret scan, dependency audit, type-check/tests, real-MySQL database gates) |
| `erp-mobile` | `reports-export` | `b23badb` | CI run 38896028221 green |
| `erp-control-web` | `tsx-public-site` (**not merged**) | `0eedfaa` | CI run 38897130217 green (incl. Playwright); `main` is `0417bfe`, untouched |
| `erp-docs` | `master` | the commit carrying this file | |

Baseline at takeover: backend `6a4cfc0`, mobile `a8b48c4`, website `8efa902`, docs `fd86e24`. The clean detached
worktree `/home/user/erp-backend-seed` (`d88893a`, an earlier phase's QA seed work) is left as it was.

Open draft PRs (none touched): backend #1 `claude/qa-boutique-seed`, #2 `claude/audit-fixes`; mobile #1
`claude/stock-finds-products`, #2 `claude/audit-fixes` (the two `audit-fixes` are superseded — O-C7).

## What the phase delivered

The production-readiness audit for TestFlight under TSX-MR. Read first: **`docs/77`** (the readiness report, the
GO/NO-GO for internal TestFlight, external TestFlight and the App Store, and the owner's decisions). Then `docs/83`
(every finding with its status, commit and test), `docs/82` (every tracked file's review row), `docs/78` (environment
and secrets, names only), `docs/79` (staging, live deployment and rollback), `docs/80` (migration, backup and restore
rehearsal), `docs/81` (App Store Connect checklist and the physical-iPhone script), `docs/84` (screenshot matrix),
`docs/48` (dependency triage and the controls changed), `docs/21` (the fixes a user can notice; the new owner
questions). The session's narrative is the last entry of `SESSION_LOG.md`.

- 243 review findings: the 1 blocker and 20 highs all verified — 17 fixed with regression tests, 4 owner decisions.
- No schema change was written. No migration was applied to anything shared.
- **GO / NO-GO:** internal TestFlight NO-GO today, code ready (O-A0, O-A4, O-A6 stand between it and GO); external
  TestFlight NO-GO; App Store NO-GO. **An external penetration test has not been done.**

## Verification at the final heads

| Repository | Result |
| --- | --- |
| backend `06a0db7` | `tsc` 0 · Jest 249 suites passed, 1 skipped · 4 508 tests passed, 24 skipped, **0 failed** |
| mobile `b23badb` | `tsc` 0 · lint 0 errors, 29 warnings · 114 pure test files · Jest 28 suites / 279 tests, 0 failed |
| website `0eedfaa` | typecheck · Vitest 18 files / 296 tests · `build:preview` · CI Playwright browser checks |
| real HTTP (final backend build) | isolation 14 778 requests, 0 leaks, 0 × 5xx · money idempotency 18/18 |

Browser- and API-verified only. **NOT DEVICE VERIFIED:** camera, haptics, native sharing, the native PDF preview,
safe areas, cold-launch RTL, Keychain, push, the EAS build itself.

## Databases

- No live or production database exists, and none was touched. The PC's `phonestore` is still at `0091`; this cloud
  session cannot reach it and did not inspect it.
- `0092`–`0097` exist in `reports-export` and are applied to no shared database. **`0097` needs the owner's approval
  before any shared database sees it** (D176, O-B12).
- Every disposable database of this phase (on the session's own scratch MySQL) is dropped with its `phonestore_*`
  identities; no API or server process is running; scratch keys, backups and env files are deleted.

## Known risks and blockers

- The owner's decisions in `docs/77` §6 (O-A0…O-A8, O-B1…O-B16, O-C1…O-C8). The product rules among them are also in
  `docs/21` ("Awaiting the owner — questions the production-readiness phase found").
- 42 medium and 113 low findings read from code only (`docs/83`, status "open").
- R1 (`docs/84`): the money-services Transactions header breaks mid-word at 320 pt with 1.3× text — a layout choice for
  the shared `TabHeader`.
- PR-F18 / O-B13: inter-store notifications are written to the proposing store.
- The backend has no linter (PR-F09); the website header offers "Sign in" while signed in (R4).

## Next exact action

Nothing is in progress. The next session should:

1. Read `docs/77` §6 with the owner and record each decision in `docs/21`. O-A0, O-A4 and O-A6 unblock internal
   TestFlight; no build is to be made or uploaded before the owner says so.
2. Once a staging host exists, follow `docs/79` §A with a fresh backup, then run `docs/81` §3 on a physical iPhone and
   record each row's result there.
3. Work the open mediums of `docs/83` by severity, each reproduced before it is fixed.
