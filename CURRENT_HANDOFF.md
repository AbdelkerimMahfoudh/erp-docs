# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Owner: **CLAUDE-B** (a claude.ai cloud session)
- started_at_utc: **2026-10-05T01:39Z**
- Taken from `READY_FOR_HANDOFF`, owner NONE — the previous handoff (CLAUDE-B, 2026-10-03, the release-candidate
  stabilization, `docs/67`) was **complete**: all three working trees clean and level with their remotes at the HEADs
  recorded below, which were verified against `git fetch` before this line was written.
- **Active phase and scope (the user's brief of 2026-10-05): the external subscription management separation.**
  Restore the approved model — subscriptions are acquired, paid, renewed and administered on a separate website; the
  mobile app only consumes the server-controlled entitlement state and shows neutral access status. In scope: the
  takeover audit; the mobile boundary (no price, seat price, purchase/renew action, payment form, Bankily
  instruction, external purchase link, plan selection, billing control or in-app purchase); a coherent read-only
  client in the expired state; the Super Admin console out of the customer app; the backend as the sole entitlement
  authority (verified, no enforcement removed); hiding self-registration that cannot complete; a versioned API/UX
  contract for the future website (no website is built); the App Store boundary audit; every gate; docs, session
  log, handoff. **Out of scope, by instruction:** deploying, live migrations, TestFlight, an App Store build, the
  production website, Bankily, WhatsApp, any other feature.
- Next intended action: report the takeover discrepancies, then implement backend → mobile → docs, committing on the
  release branches (`reports-export`) only after verification.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | `d3694ad` (takeover; this commit follows it) | level | 0 |
| `erp-backend` | `reports-export` | **`1434aa7`** | level | 0 |
| `erp-mobile` | `reports-export` | **`3023bd3`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — not in this container, not touched (as last recorded) | — | — |

Backend this session: `4370240` (the business date reads the timezone through the caller's transaction — the pool
deadlock), `56bddbe` (deletion and number verification refused up front with no channel), `867133e` (the identity
script and the restore drill), `c4ad802` D1, `28c1bd6` D2, `ede48c0` D3, `0e5f189` D5 (cherry-picked with `-x` from
draft PR #2), `084f738` (the Daily closing under MySQL's default `sql_mode`), `c0a00a1` (no cost in the stock-received
notice), `1434aa7` (the identity verifier's trigger probes). Mobile: `1e4567e` (the expo-camera patch for 57.0.5 — a
clean `npm ci`), `f200a52` M1 (cherry-picked), `3023bd3` (the patch tests follow the lockfile). Docs: `a72a08d`
(takeover), `f26e4d5` (checkpoint), this commit. **No migration was written; live is still at 0083** (0084 and 0085
owed — runbook `docs/67` §7). Draft PRs: backend #2 and mobile #2 are **superseded** by the cherry-picks (close them);
backend #1 (the QA seed) and mobile #1 (*Catalog leaves More*, D126) are unchanged. In this cloud container only:
`/home/user/erp-backend-seed` is a git worktree at `d88893a`; every database and server of this phase is gone.

## What changed

| Where | Now |
|---|---|
| **Sales under load** | simultaneous sales no longer wait on each other's database connections (16 at once on 5 connections: all accepted in 3 of 3 trials; before: 12 to 16 of 16 lost) |
| **Account deletion, WhatsApp postponed** | refused at once with *Codes cannot be sent right now. Nothing was changed* — no request, no code field; the same for verifying a number (before: a 200 and a code field no code would fill) |
| **The Daily closing on a standard MySQL** | works under the default `sql_mode` (it failed for every role off live's empty `sql_mode`) |
| **Notifications** | *Received N item(s)* no longer carries the purchase cost |
| **Deploy scripts** | `mysql-identities.sql` runs (passwords on standard input); `restore-drill.sh` compares every table and every trigger body and never passes a probe for want of a grant |
| **The audit's fixes** | D1 recognition learning, D2 dead stock, D3 malformed ids → 404, D5 a same-key sale race answers one sale, M1 the picker keeps the scan |
| **Native install** | `npm ci` exits 0 again (the patch re-cut for expo-camera 57.0.5) |

## Verification

| Kind | Result |
|---|---|
| **Gates** | backend 181 suites / 3 254 tests (3 skipped — the demo-file receiving tests), `tsc`, `prisma validate`, permission catalogue 64/64; mobile 89/89 suites, `tsc` (the known `global.css` error), lint 0 errors / 29 warnings, Expo Doctor 19/21 (two network checks blocked), web export 88 pages, clean `npm ci` |
| **Real HTTP (disposable)** | deletion in production mode 7/7; D5 6/6; D3 6/6; tenant isolation + permissions 20/20; every GET route under the default `sql_mode` 0/85 failing; concurrency 16 and 30 at once accepted |
| **Rehearsal 0084 → 0085** | on a restored live-like copy: 0084 1.08 s, 0085 1.62 s, 1 195 audit rows sealed, chains 10/10, schema = a fresh build, old and new API both work on it, failure recovered, identities 20/20, backup/restore by CHECKSUM (`docs/67` §6, `docs/22` E.3) |
| **The current app** | web export of `3023bd3` on the migrated copy: 19 screens, 0 errors (a browser, not the phone) |
| **Not run** | any iPhone, a real WhatsApp send, a store build, GitHub Actions, anything on live |

## 🔴 Release blockers (`docs/67` §2; `docs/48` §12–§13)

RC-01 deletion cannot complete in production (D116) · RC-02 registration cannot finish (D117) · RC-03 the payment model
(D118) · RC-04 no HTTPS host · RC-05 live at 0083 (runbook) · RC-06 nothing on an iPhone (`docs/24` §54) · RC-07 the
security gate (dependency triage, the module tenant suite, bot protection, incident response and retention, the
independent assessment, the first CI run) · RC-08 no privacy policy · RC-09 demo account, export compliance, privacy
manifest, iPad.

## 🟡 The owner's decisions (`docs/67` §4)

D116 deletion without WhatsApp (recommended: password + 7-day window + in-app confirmation) · D117 hide self-registration
on iOS · D118 business accounts only, no purchase in the app · D119 an expired shop's Home and Money · D120 the IMEI rule
· D121 notifications in the reader's language (bounded plan) · D122 *Phone sales* → *Sales* · D123 a Manager's personal
targets · D115 a past month's PDF · D124 Partners discoverability · D125 the plural pass · D126 mobile PR #1 · D127 the
iOS configuration · D128 verified contact before approval. Also: CLAUDE-A's uncommitted trace on the PC — keep or discard.

## 📋 Known, not fixed

`docs/67` §2 RC-10 … RC-27: the expired shop's write actions (FAILED on the web, AE29), notifications in English, full
IMEIs beyond 19d and in logs, plurals, cross-company and cross-branch notices, uploads typed by name, refresh rotation
untested, duplicate unverified registrations, the invoice-counter deadlock at 30 sales at once, audit rows outside the
transaction (64 sites), 401 during a database outage, and `docs/66` §8's low items. Carried: CLAUDE-A's scope (1) on the
phone (`docs/24` §48–§50); the older backlog (`SESSION_LOG.md`, 2026-09-28/29).

## The next exact action

1. **Take ownership** (`IN_PROGRESS`, the account, the UTC instant, the three HEADs above).
2. **With the owner:** D116, D117 and D118 first (they decide whether the App Store is reachable), then D119–D128; close
   draft PRs #2 (superseded).
3. **Live, only with the owner's written approval and someone at the PC:** `docs/67` §7 — pre-checks, stop the API, the
   verified dump, the restore check, `npx prisma migrate deploy` (0084, 0085), the post-checks, `npx prisma generate`,
   the API on backend `1434aa7`, the read-only smoke; record the dump and the result here at once. The phone then
   reloads mobile `3023bd3`.
4. **A build:** the owner's Apple account and an HTTPS staging host → an internal TestFlight (or ad-hoc) build →
   `docs/24` §54 on an iPhone SE and a large iPhone, in EN, FR and AR.
5. **Then** the gate's code work (dependency triage, the module tenant suite), the decided items, CLAUDE-A's scope (1).
   Automatic WhatsApp report delivery stays postponed (D111).
