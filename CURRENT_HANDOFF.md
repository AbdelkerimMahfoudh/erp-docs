# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Owner: **CLAUDE-B** (a claude.ai cloud session)
- `started_at_utc: 2026-10-02T23:31Z` — taken from `READY_FOR_HANDOFF`, owner NONE (the previous handoff was complete).
  Takeover HEADs, all clean and level with their remotes: docs `d8775d1` (`master`) · backend `1a4bd6f`
  (`reports-export`) · mobile `e484b58` (`reports-export`). Migrations in the repository through **0085** (84
  directories; there is no 0005); live is at 0083 — this phase rehearses 0084 and 0085 on a disposable copy only.
- **Active phase and scope (the user's brief of 2026-10-02): release-candidate stabilization** — a trustworthy release
  decision, not a feature wave. Classify every open finding (blocker / before wider testing / owner decision / defer);
  fix only objectively demonstrable defects, with focused tests; decision papers for the expired shop, full IMEIs,
  notifications in the reader's language, *Phone sales*, a Manager's personal targets and a past month's PDF;
  reconcile the security gate and the account-deletion journey; assess Apple's guidelines; rehearse 0084 and 0085 on a
  disposable restored copy and write the production runbook; an iPhone test script; GO / NO-GO for TestFlight and for
  the App Store. **No publishing, no TestFlight submission, no live migration and no live data change without the
  user's separate approval.**
- **Discrepancies found at takeover** (reported to the user before any code change):
  1. The 30 Sep audit's fixes are **not in the release branch** — backend D1 recognition learning, D2 dead stock, D3
     malformed ids → 500, D5 the same-key sale race (draft PR #2) and mobile M1 Receive → *Choose product* loses the
     scan (draft PR #2). `docs/48` controls 8 and 9.1 cite D5 as evidence.
  2. **No native build can install**: `postinstall` runs `scripts/verify-native-patch.js`, which fails because
     `expo-camera` is 57.0.5 and the patch was cut for 57.0.4 (`npm ci` exits 1).
  3. `master` in backend and mobile is stale (10 and 8 Sep); the release candidate lives on `reports-export`.
  4. The audit's D4 (`companies.is_discoverable` never set, so Partners is unreachable on a real install) is still open.
- **Checkpoint 2026-10-03 00:35Z — code pushed, verified; docs being written.** Backend `reports-export`
  `1a4bd6f` → **`0e5f189`**: `4370240` (a transaction reads the company's timezone through itself — concurrent sales no
  longer exhaust the pool), `56bddbe` (deletion and number verification refused up front when no channel can send),
  `867133e` (the identities script runs; the restore drill fails a restore that changed data), and the 30 Sep audit's
  fixes cherry-picked with `-x`: `c4ad802` D1, `28c1bd6` D2, `ede48c0` D3, `0e5f189` D5. Mobile `e484b58` →
  **`3023bd3`**: `1e4567e` (the expo-camera patch re-cut for 57.0.5 — a clean `npm ci` exits 0), `f200a52` M1
  (cherry-picked), `3023bd3` (the patch tests follow the lockfile). Gates: backend 181 suites / 3 251 tests (3 skipped),
  `tsc`, `prisma validate`, permission catalogue 64/64; mobile 89/89 suites, lint 0 errors, doctor 19/21 (network),
  web export 88 pages, clean `npm ci` OK. The rehearsal of 0084 → 0085 ran on a live-like disposable MySQL (empty
  `sql_mode`, `utf8mb4_unicode_ci`, no binary log) — passed, recorded next in `docs/67`. Draft PRs #2 (both repos) are
  superseded by the cherry-picks, left open for the owner to close.
- **Next intended action:** `docs/67` (the release gate, decision papers, the rehearsal, the runbook), `docs/24` §54
  (the iPhone script), `docs/48`, `docs/22`, `docs/21`, `SESSION_LOG`, this file; then stop.
- **The gate (`docs/48`) is NOT PASS.**

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`0e5f189`** | level | 0 |
| `erp-mobile` | `reports-export` | **`3023bd3`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — not in this container, not touched (as last recorded) | — | — |

Backend this session: `86ef9a0` (the report documents: `GET /reports/daily`, `GET /reports/monthly`, version 1),
`1a4bd6f` (`ownOffer` on loans). Mobile: `420c83d`, `64595fe` (the PDFs), `3055799` (requests wait for the restored
branch), `c7c6265`, `aec0d95`, `3e819d4`, `248288f`, `ec5eac6`, `220994b`, `e484b58` (the review's fixes). Docs: `70cbb81` (the takeover), this
commit. **No migration:** the repository holds migrations through 0085 (84 directories; there is no 0005); live is at
0083 (0084 and 0085 still owed on live — unchanged by this phase). The draft PRs of the 2026-09-30 morning audit (backend #1, #2; mobile #1, #2) are unchanged and unmerged. In this
cloud container only: `/home/user/erp-backend-seed` is a git worktree of the backend at `d88893a`
(`claude/qa-boutique-seed`, pushed) holding nothing but its installed dependencies; the disposable MySQL databases of
this and earlier cloud phases are dropped.

## What changed (`docs/66`, `docs/21` D111–D115)

| Where | Now |
|---|---|
| **Daily closing** (holders of `report.view` who may count) | *Generate PDF* for the business date shown → *PDF ready*: **Open** (the system preview; on the web a new tab) and, on a phone, **Share or save** through the system's own sheet. `RetailERP_<Branch>_Daily_<date>_<LANG>.pdf` |
| **Results → This month** | the same for the month shown, marked *in progress* until it ends (D115: a past month is the owner's call) |
| **Server** | `GET /reports/daily?date=` (`report.view` + `closing.count`), `GET /reports/monthly?month=` (`report.view`): version-1 documents copied from the calculations the server already owns; cost / margin / profit only with `cost.view` (*hidden*, never zero), refunds only with `return.view`; names only; one audit row per document served |
| **Loans** | the summary says whose offer is on the table (`ownOffer`); a screen never offers an answer the server refuses |
| **The review's fixes** | `docs/66` §7: the restored branch before the first read, *Custom* returns, pinned buttons, the difference's decisions, debts, plurals, refusals by link, Analytics without `report.view`, the 320 pt status chips and rows, a Manager's *Set a target* |

## Verification

| Kind | Result |
|---|---|
| **Report tests** | backend **39** (`report-documents*.spec.ts`), mobile **34 + 11** (`report-pdf-html`, `report-pdf-flow`) |
| **Real HTTP** on the disposable `prisma_qa_pdf` | **43 of 43** — every figure of the daily and monthly documents against the fixture, every role (Owner, Manager, a role without cost, a legacy role without refunds, Employee 403, another company 403, no session 401); 21 business tables checksummed before and after every read, unchanged; one audit row per document |
| **Sample PDFs** | 18, rendered from the server's documents through the app's builder, every page inspected |
| **Visual review** | Every page of the committed web export of `e484b58`: 78 routes, 90 page states; the Owner's full set 121 images per language (EN, FR, AR), the Manager and Employee imaged where they differ, 51 states per language with the platform administration signed in; **0 issues at 393 pt**, **645 of 645** at 320 pt × 1.3×, **246 of 246** permission checks; 20 findings fixed, 15 left for the owner, 7 subjective notes (`docs/66` §6–§8). The package (six zip parts) and a private page of the contact sheets went to the user; nothing of it is committed |
| **Gates** | backend 177 suites / 3 206 tests (3 demo-file tests skipped, no demo file in the container), `tsc` clean, `prisma validate`, migrate status up to date (84), permission catalogue 64/64; mobile 89 pure suites, `tsc` (the one known `global.css` error), lint 0 errors / 29 known warnings, Expo Doctor 19/21 (two network checks blocked by the container's allowlist), web export 78 routes, no hard-coded copy or colour, 3 410 keys × 3; the reporting journey re-run on `1a4bd6f`: 43 of 43 |
| **Not run** | the phone (`docs/24` §52, §53), a real WhatsApp send, a store build, GitHub Actions |

## 🔴 Release blockers (`docs/48` §12) — none clearable by a session

1. **The WhatsApp Business account**: templates `auth.otp`, `account.deletion`, `account.deleted` approved in EN/FR/AR
   (copy in `docs/64` §4), a sending number, a system-user token, then a real send per language. Without it
   registration cannot finish and no account can be deleted.
2. **D110 — the owner's decision** (`docs/64` §7): an email-only login cannot delete in-app without first verifying a
   WhatsApp number; Apple may read that as an obstacle. (a) require a number at registration, (b) approve an explicit
   second confirmation for logins without WhatsApp, or (c) accept the risk.
3. **Production secrets and hosting**: `OTP_PEPPER`, `JWT_ACCESS_SECRET`, four database passwords, TLS at the edge,
   `API_INGRESS`, disk encryption, the off-host backup location and passphrase custody.
4. **Dependency triage** (control 20): backend 6 high / mobile 3 high in production dependencies, none bumped.
5. **The per-module adversarial tenant suite** (control 4, rated high).
6. **The legal retention period** (`docs/64` §6) and a written incident-response procedure (8.4).
7. **Apple**: the archive's privacy manifest and `ITSAppUsesNonExemptEncryption`, the review demo journey, `docs/24` §51.
8. **The first CI run** on GitHub Actions (github.com is unreachable from the container).
9. **Bot protection** (control 12, medium).
10. **The independent assessment** (10.4) — a self-review cannot be it.

## 📋 Known, not fixed

- **From this phase, for the owner** (`docs/66` §8): D115 (a past month's PDF); a Manager's personal targets (a
  names-only people list for `goal.manage` is a new server read — approve or not); an expired shop told only on More
  while Home still offers *Sell* (refused by the server); notifications stored as English
  sentences for most types; *Phone sales* wording in an all-electronics product; lazy plurals *(s)* and Arabic plural
  classes; two list subtitles cut at 393 pt; full identifiers on detail pages rule 19d does not name; four-way choices
  break words at 320 pt with large text; copy nits; the subjective notes.
- Carried, still true: the access refusal's *Check again* opens the app only when writing is allowed too; the native
  build's `npm install` postinstall (`expo-camera` 57.0.5 vs the Android patch for 57.0.4); `GET /closings/overview`
  under MySQL's default `sql_mode` is unproven (live runs `sql_mode=""`); the 0085 trigger serialises audit inserts per
  company (watch `deadlock` after the live rollout); the morning audit's D4 (`companies.is_discoverable` never set);
  CLAUDE-A's scope (1), the scroll investigation, waits on the phone (its dev trace uncommitted on the user's PC only),
  with `docs/24` §48–§50 and the user's open calls; the older backlog (`SESSION_LOG.md`, 2026-09-28/29).

## The next exact action

1. **Take ownership** (`IN_PROGRESS`, the account, the UTC instant, the three HEADs above).
2. **Live, before anything else the shop uses** (unchanged from the previous handoff): WAMP's MySQL up; a **verified
   backup** per `docs/22` (`deploy/backup-encrypted.sh` with the backup identity, or the documented
   `mysqldump --hex-blob`); `npx prisma migrate deploy` on live for **0084 and 0085** off-hours; `npx prisma generate`;
   the API restarted on backend `1a4bd6f` (`reports-export`); `scripts/verify-audit-chain.ts` → every company OK.
   Record the backup id and the migration here at once. The phone then reloads mobile `e484b58`.
3. **On the iPhone:** `docs/24` §52 (the PDFs: preview, the file name in the share sheet, Save to Files, a dismissed
   share) and §53 AD1–AD15 (the review's fixes, the largest text on an iPhone SE, an expired shop), in EN, FR and AR.
4. **With the owner:** the open decisions of `docs/66` §8 (D115, a Manager's personal targets, notifications in the
   reader's language, the terminology) and the release blockers above (WhatsApp Business, D110 first).
5. **Then** the gate's remaining code work (`docs/48` §12: dependency triage, the adversarial tenant suite), CLAUDE-A's
   scope (1) on the phone, and the older backlog. Automatic WhatsApp report delivery stays postponed until the owner
   reopens it (D111); it would reuse the version-1 report document.
