# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Owner: **CLAUDE-B** (a claude.ai cloud session)
- `started_at_utc: 2026-10-01T20:04Z` — taken from `READY_FOR_HANDOFF`, owner NONE (the previous handoff was complete).
  Takeover HEADs, all clean and level with their remotes: docs `6d312e1` · backend `da0d340` (`reports-export`) ·
  mobile `1de5226` (`reports-export`). Migrations in the repository through **0085** (84 directories; there is no
  0005); live is through 0083 — 0084 and 0085 are still not on live and this phase does not apply them.
- **Active phase and scope (the user's brief of 2026-10-01):** (A) the existing daily and monthly Owner reports
  prepared as **in-app PDFs** — generate, preview, optional manual native share — from the server's report contract,
  EN/FR/AR with RTL; (B) a **complete visual review** of every accessible page, nested tab and state of the web app
  (Owner/Manager/Employee, Super Admin for platform pages; EN full set, FR and AR every distinct layout at 393 pt; the
  320 pt × 1.3× matrix), with an INDEX, contact sheets and sample PDFs delivered. **Automatic WhatsApp report
  delivery, recipients, templates, jobs and report APIs for WhatsApp are postponed — not built in this phase.**
  Disposable databases only; live untouched.
- **Next intended action:** audit the report APIs and screens and the receipt PDF code, then the PDF builder; then the
  disposable fixture, the capture harness and the review package; gates; docs; `READY_FOR_HANDOFF`, owner NONE.
- **The gate (`docs/48`) is NOT PASS.** Its ten release blockers are listed below and in `docs/48` §12; none of them
  can be produced by a session alone.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`da0d340`** | level | 0 |
| `erp-mobile` | `reports-export` | **`1de5226`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — untouched | level | 0 |

Backend this session: `ae64de8` (the WhatsApp Cloud API channel), `1925a0d` (account deletion, 0084, provisioning
closed in production, seed opt-in), `bde6bc4` (0085 audit chain, identities, encrypted backups + drill, uploads by
content, secret scanner, CI), `da0d340` (the 0085 lock-order fix). Mobile: `d6eea9d` (Your account, the deletion
screens, EN/FR/AR), `1de5226` (release-config check, scanner, CI). Docs: `81b24cc` (the takeover), this commit.
Migrations: **85 in the repository; live is at 83** (0084, 0085 applied only to disposable databases). The draft PRs
of the morning audit (backend #1, #2; mobile #1, #2) are unchanged and unmerged.

## What changed (`docs/64`, `docs/65`, `docs/48`)

| Where | Now |
|---|---|
| **WhatsApp** | `WHATSAPP_CHANNEL=cloud-api` sends approved templates by name from configuration (EN/FR/AR), credentials server-side, failures visible and classified, a signed delivery webhook; production refuses to start with `cloud-api` unless the phone id, token, the sign-in and deletion template names and `OTP_PEPPER` are set |
| **Deleting an account** | More → Your account → Delete account (and from the refusal screen): password → a deletion code to the **verified WhatsApp number** → the code → deleted. The last Owner closes the business; anybody else deletes their login. Records the law requires are kept, de-identified. Enforced by the server's executor; no administrator deletion route; admin suspend/cancel and Owner deactivation stay separate and named. Reachable in every subscription state |
| **Verifying a number** | Your account → Verify a WhatsApp number: password + number → code → verified (login identifier changes; other sessions end) |
| **Audit trail** | a per-company hash chain written by the database on every insert (0085); `scripts/verify-audit-chain.ts` detects modification, deletion, reordering and trigger bypass |
| **Operations** | `deploy/mysql-identities.sql` (migrator / app / backup / admin) + `verify-mysql-identities.sh`; `deploy/backup-encrypted.sh` + `restore-drill.sh`; `scripts/scan-secrets.js`; `.github/workflows/security.yml` in both repositories; `scripts/verify-release-config.js` (mobile) |
| **Closed risks** | R5 (static-key provisioning: 404 in production, the guard refuses the key), R6 (a real provider exists in code), R7 (demo seed opt-in, refused in production); uploads typed by content |
| **Data** | 0084 `account_deletion` purpose on both enum columns, `account_deletion_requests`, `companies.closed_at`; 0085 `audit_logs.prev_hash/entry_hash`, `audit_chain_heads`, the chaining trigger, the seal of existing rows |

## Verification

| Kind | Result |
|---|---|
| **Real HTTP** on a fresh disposable database (all 85 migrations, the development-log channel, its own admin) | **117 of 117** per run: the approval timeline end to end (pending → approve with dates → active → grace → expired → extended → suspended → reinstated; refusal and approval after refusal; step-up, stale version, forged ids, duplicates, the Owner cannot approve), deletion end to end (login and business; wrong/other/spent/malformed codes; number verification; cancel; the administrator cannot confirm or delete), the webhook closed while unconfigured. **429** on the deletion routes at the default 5/min (run 3). Audit chain verified after each run and after 3 × 30 parallel audited writes |
| **Tamper proofs** | a modified row, a deleted middle row and an insert with the trigger dropped each broke the chain for the verifier |
| **Identities / backup** | 20 of 20 probes (the append-only triggers refused as `phonestore_app`); encrypted backup verified; restore drill passed (`docs/22` E.2) |
| **Gates** | backend `tsc` clean, **175 suites / 3 166 tests**; mobile **85 pure suites**, lint 0 errors / 30 known warnings, `tsc` the one known `global.css` error, web export secret-free, release-config check refused/sound/refused; secret scan of all three histories clean; `.env*` in no commit |
| **Not run** | the phone (`docs/24` §51), a real WhatsApp send, a store build, GitHub Actions |

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

## 📋 Known, not fixed (carried; still true)

- The access refusal's *Check again* opens the app only when writing is allowed too; a read-only shop stays on the
  refusal until it signs out and in.
- Native build blocker: `npm install`'s postinstall fails (`expo-camera` 57.0.5 vs the Android patch cut against 57.0.4).
- `GET /closings/overview` under MySQL's default `sql_mode` is not proven; live runs with `sql_mode=""`.
- The 0085 trigger serialises concurrent audit inserts **per company** on its head row (inside the inserting
  transaction) — expected cost, documented in the migration; watch `deadlock` in the logs after the live rollout.
- The morning audit's D4 (`companies.is_discoverable` never set → Partners unreachable) is reported, not fixed — a
  product decision.
- Inherited from CLAUDE-A, unchanged: scope (1) the scroll investigation waits on the phone (its dev trace uncommitted
  on the user's PC only); `docs/24` §48–§50 on the phone; the user's calls on the Arabic Home order and on counting
  without the closing delegation; the `spent_on` tidy-up; the older backlog (`SESSION_LOG.md`, 2026-09-28/29 entries).
- The rest of the previous handoff's backlog stands (Money's figures, rollup recovery, corrections not available by
  name, the Stock tab's identifiers, the Catalogue's "Last sold", `product_velocity` to drop, …).

## The next exact action

1. **Take ownership** (`IN_PROGRESS`, the account, the UTC instant, the three HEADs above).
2. **Live, before anything else the shop uses:** WAMP's MySQL up; a **verified backup** per `docs/22` (now
   `deploy/backup-encrypted.sh` with the backup identity, or the documented `mysqldump --hex-blob`); then
   `npx prisma migrate deploy` on live for **0084 and 0085** off-hours (0085 seals every audit row in one procedure —
   ~1 000 rows today, seconds); then `npx prisma generate`, the API restarted on `da0d340`, and
   `DATABASE_URL=<backup identity> npx ts-node scripts/verify-audit-chain.ts` → every company OK. Create the backup
   and admin identities on live from `deploy/mysql-identities.sql` and run `deploy/verify-mysql-identities.sh` on a
   copy. Record the backup id and the migration in this file at once.
3. **With the owner:** obtain the WhatsApp Business account and template approvals (`docs/64` §4, §8); decide D110;
   set `WHATSAPP_*` and `OTP_PEPPER` on the API host; a real send in EN/FR/AR; then `docs/24` §51 on the iPhone (the
   phone reloads the new bundle: `1de5226`).
4. **The gate's remaining work** (`docs/48` §12, items 3–10), in that order; the dependency triage and the adversarial
   tenant suite are the next code work. Re-run the gate on the release candidate; only an independent assessment can
   close it.
5. **Then** the inherited scope (1) on the phone, and the older backlog.
