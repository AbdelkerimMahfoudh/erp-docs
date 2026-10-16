# Staging, live deployment and rollback runbooks (2026-10-16)

Supersedes the operational parts of `docs/44` (written at 63 migrations, before MFA, the trial and the CI database
gates) and `docs/67` §7 (written for 0084/0085 only). **Nothing below has been executed against any real host, DNS
name or database.** Every step is the owner's or an operator's, done with the owner's written approval of the window.

Code to deploy (at the time of writing — always re-read `CURRENT_HANDOFF.md`):

| Part | Repository / branch | Commit |
| --- | --- | --- |
| API | `erp-backend` `reports-export` | the final commit recorded in `CURRENT_HANDOFF.md` |
| Website | `erp-control-web` `tsx-public-site` (not merged to `main`) | idem |
| App | `erp-mobile` `reports-export` | idem |

Schema: 96 migrations, `0001` … `0097_scheduled_addons`. **`0097` needs the owner's approval before any shared
database sees it** (`docs/21`, D176).

---

## A. Staging — HTTPS, fictitious data only

Purpose: the first internet-reachable copy, so that an internal TestFlight build has an HTTPS API to talk to. **No
real shop's data, ever.** Staging holds the QA boutiques (`scripts/qa-boutiques.ts`) and nothing else.

### A0. Owner decisions that must exist first

- A host (`docs/45` D4) and a database (D5), not a developer's PC.
- A staging hostname under a domain the owner controls (D1–D3), with a TLS certificate.
- Who holds the staging secrets.

### A1. Host

1. Node 22 LTS (CI uses 22.x; the container used 22.22). Record `node -v`.
2. MySQL 8.0, **binary log on**: set `log_bin_trust_function_creators=1` in the server configuration *before* any
   migration or restore (ERROR 1419 otherwise — rehearsed, `docs/80` path 4).
3. A reverse proxy terminating TLS. It is the only route to `/api/*`. The API binds `127.0.0.1`.
4. A process manager that restarts the API, with a restart cap, and sends `SIGTERM` on stop.
5. `UPLOAD_DIR` on a persistent volume (receipt photos are stored).

### A2. Database and identities

1. `CREATE DATABASE phonestore CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;` (the identity script grants on the
   schema named `phonestore`).
2. Make four passwords: `openssl rand -hex 24` each, into mode-600 files.
3. Pipe them, with `deploy/mysql-identities.sql`, into `mysql` as root, exactly as that file's header shows (standard
   input, never arguments).
4. `DATABASE_URL=<migrator URL> npx prisma migrate deploy` → 96 applied. Then `npx prisma migrate status` → up to date.
5. `DATABASE_URL=<app URL> npx ts-node --transpile-only scripts/verify-permission-catalogue.ts` → "catalogue and grants
   complete".
6. `deploy/verify-mysql-identities.sh` with the three passwords → 0 failed. (On an empty schema the trigger probes say
   SKIP: run it again after step A4.)

### A3. API

1. `npm ci && npm run build`, then start with **`npm run start:prod`** (runs `dist/src/main.js` — fixed in `d2ad456`;
   before it, that command could not start the API).
2. Environment: `docs/78`. For staging:
   - `NODE_ENV=production`, `APP_ENV=staging` (drops HSTS);
   - `API_BIND=127.0.0.1`, `API_INGRESS` set;
   - **`SWAGGER_ENABLED=false`** (it defaults to true);
   - `COOKIE_SECURE=true`;
   - `CORS_ORIGINS` and `PUBLIC_SITE_ORIGIN` set to the staging website's https origin;
   - fresh `JWT_ACCESS_SECRET`, `OTP_PEPPER`, `PLATFORM_MFA_KEY` and `PLATFORM_ADMIN_KEY`;
   - `WHATSAPP_CHANNEL=disabled` (WhatsApp is postponed); `EMAIL_CHANNEL=disabled` until a provider exists;
   - `SEED_DEMO=false`;
   - `APP_COMMIT`/`APP_BUILT_AT` from the deploy.
3. The production guard refuses to start on an unsafe value: read its message, fix the value, never bypass it.
4. **With both channels disabled, registration and contact verification cannot complete.** Accounts for staging are
   provisioned by the QA script and the platform administrator (`prisma/create-platform-admin.ts`, then the MFA
   enrolment of `docs/75` §9).

### A4. Fictitious data

`QA_PASSWORD=… QA_DB=<a prisma_qa* schema> QA_API=… npx ts-node scripts/qa-boutiques.ts --apply`

The script refuses any schema whose name does not start with `prisma_qa`. For staging, either name the staging schema
`prisma_qa_staging`, or run the script against a `prisma_qa*` copy and restore that into `phonestore`. Never relax the
guard.

### A5. Website (staging)

`npm ci && VITE_API_BASE=https://<staging API> npm run build:preview`. The preview mode stamps "PREVIEW: test values,
noindex". Serve `dist/` statically, with the headers the build's checks expect (CSP, `Referrer-Policy: no-referrer` on
`/account/trial/`). See `docs/74`.

### A6. Checks on the host (all must pass; record each in `CURRENT_HANDOFF.md`)

1. `GET /api/health` → 200.
2. `GET /api/health/ready` → `pendingMigrations: 0`.
3. `GET /api/health/version` → the deployed commit.
4. `GET /api/docs` → 404.
5. The API port refused from outside the host; only the proxy answers.
6. Helmet headers present and **no HSTS** (staging).
7. CORS: no `Access-Control-Allow-Origin` for an unlisted origin.
8. A burst on `/api/v1/auth/login` throttles at `AUTH_THROTTLE_LIMIT`.
9. The API log: request ids present, and no `authorization`, cookie, password, token, code or `?t=` value.
10. The app (a build with `EXPO_PUBLIC_API_ORIGIN=https://<staging API>`) signs in as a QA Owner.
11. The real-HTTP harnesses of this phase, pointed at staging: `isolation.cjs`, `money-idem.cjs` and the trial harness.
    Only against `prisma_qa*` data.

### A7. Backups on staging

Schedule `deploy/backup-encrypted.sh` as `phonestore_backup`. Keep the passphrase off the host. Run
`deploy/restore-drill.sh` as `phonestore_admin` once and record it in `docs/22`.

---

## B. Live deployment (the shop's real database)

The live database is the shop's **WAMP MySQL on the owner's PC**, at `0083` per the brief (the PC's development schema
is at `0091`; `CURRENT_HANDOFF.md`). A cloud session cannot reach it. **This phase changed nothing on it.**

### B0. Approval and preconditions

- The owner's written approval of the window, naming the date, the time and an API stop of about 20 minutes, **and
  approval of `0097`**.
- Someone at the PC with its shell, the migrator's option file (`docs/22` §2), Node, and the backend checkout at the
  commit named in `CURRENT_HANDOFF.md`.
- Re-rehearse first if MySQL is not 8.0.x or `lower_case_table_names=1` matters. The rehearsal ran on 8.0.46 with
  `lower_case_table_names=0`.

### B1. Steps

| # | Do | Abort if |
| --- | --- | --- |
| 0 | `SELECT @@version, @@sql_mode, @@log_bin, @@log_bin_trust_function_creators, @@collation_server;` · `git log -1` = the recorded commit · `npx prisma migrate status` → pending exactly the expected list (from 0083: 0084–0097) · record `COUNT(*)`, `MAX(id)` of `audit_logs` and the counts of `sales`, `payments`, `expenses`, `units`, `daily_closings` | anything else pending; wrong commit; binary log on and the trust setting 0 |
| 1 | Stop the API (and Metro). `SHOW PROCESSLIST` shows no application connection | a phone is mid-sale: wait |
| 2 | Backup: `deploy/backup-encrypted.sh` as the backup identity (or `docs/22` §2's canonical dump) · the script's verification passes · keep the `.sha256` | no trailer, or the verification fails |
| 3 | Restore check: `deploy/restore-drill.sh` as the admin identity, into a new database → every table's CHECKSUM, trigger bodies and keys identical → drill database dropped | anything differs |
| 4 | `npx prisma migrate deploy` (migrator) → 0084 … 0097 applied (rehearsed: 5.2 s from 0083, 1.5 s from 0091) | `P3018` → do **not** start the API; go to C2 |
| 5 | Checks: `migrate status` up to date · `verify-permission-catalogue` complete · `verify-audit-chain` (backup identity) every company OK · `verify-mysql-identities.sh` 0 failed · step-0 counts unchanged · `prisma migrate diff` against a schema built fresh from all migrations → no difference | any failure: keep the API stopped; C2 |
| 6 | `npx prisma generate` with the API stopped (Windows holds the engine open), `npm run build`, `npm run start:prod` with the same `.env` plus the new variables (`docs/78`) | the guard refuses: fix the value |
| 7 | Smoke, read-only: the Owner signs in on the phone; Home, Money, Daily closing, a sale's detail, Your account load; no *Database request error* in the log. After the shop's first real sale, `verify-audit-chain` again | errors on writes: C1 |
| 8 | Record the dump's name, size and SHA-256, the migration time and every check → `CURRENT_HANDOFF.md` at once | — |

---

## C. Rollback

**A Git rollback does not roll back the database.** Choose by what failed.

### C1. Code-only rollback (the API misbehaves; the migrations succeeded)

Start the previous API on the migrated schema.

- **Rehearsed** on 2026-10-16: the pre-0084 API (`ae64de8`) ran sales, part payments, later payments and expenses on
  the `0097` schema with nothing refused, and the audit chain stayed intact (`docs/80`).
- **Known limit:** an API older than 0092 has its money-agent exchange insert refused by 0092's CHECK, and an API older
  than 0097 does not know the `scheduled` seat status. Roll back below 0097 only while no `seat_allocations` row is
  `scheduled`. Otherwise roll forward.

### C2. A migration failed part-way (`P3018`)

MySQL DDL is not transactional: the migration is half-applied and later deploys are refused (`P3009`). **Never start
the new API on it.**

1. Read what was created.
2. **Remove the cause** — for ERROR 1419, `SET GLOBAL log_bin_trust_function_creators = 1`.
3. **If the half-applied objects hold no rows**, choose one:
   - when the migration is safe to re-run (`IF NOT EXISTS` / `DROP … IF EXISTS`, as 0095 is): run
     `npx prisma migrate resolve --rolled-back <name>`, then `npx prisma migrate deploy`. **Rehearsed for 0095**:
     recovered in 1.2 s, schema identical to a fresh build, every original row intact;
   - otherwise drop exactly what it created, following its header's *Reverse* note, then resolve and deploy.
4. **If they hold rows, or anything is unclear:** C3.

### C3. Restore

1. Restore the step-B2 backup **into a new database** (`docs/22` §3, or `deploy/restore-drill.sh` with
   `KEEP_DRILL=1`).
2. Verify it.
3. Point the previous API at it.
4. **Never drop `phonestore` before the restored copy is verified.**

Rows written between the backup and the failure are lost by a restore, so the API stays stopped from step B1 until
step B7.
