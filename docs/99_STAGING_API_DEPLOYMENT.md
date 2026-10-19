# 99 — Deploying the staging API (staging-api.tsxmr.com)

**Status (2026-10-17, CLAUDE, cloud): prepared and rehearsed locally. Nothing is deployed.**

- No host has been chosen or bought, no DNS record exists, and no real database has been migrated.
- The owner is provisioning the host. Everything below runs on that host once the inputs in §10 exist.

**Targets:**
- **staging** `https://staging-api.tsxmr.com`;
- **production** later `https://api.tsxmr.com`.

The two never share:
- a database or a database server;
- secrets;
- an env file;
- a host directory.

TestFlight builds use staging.

**What this supersedes:**
- The *operational* parts of `docs/79` §A ("Staging"): the host, database, API and checks there assumed a bare host with
  a process manager.
- The file table in `docs/39` §2 ("Provider-neutral artifacts"). It named a `deploy/docker-compose.staging.yml`, a
  `deploy/nginx-site.conf` and a `backend/Dockerfile` that do not exist in `erp-backend`'s history: they were never
  committed there.

The *principles* of both stay: fictitious data only, strict SQL mode, separate identities, a guard on every staging-only
command.

Code (backend `erp-backend` `reports-export`):

| Commit | What |
| --- | --- |
| `f8761c3` | Secret scan: the `EAAG-real-token` test fixture allowlisted (the full-history scan had been red since `d0a7495`) |
| `0c12bf2` | Readiness counts carried vs applied migrations; masked outbox log; the keyed staging code lookup |
| `33723da` | `Dockerfile`, `.dockerignore`, `deploy/docker-compose.staging.yml`, `deploy/staging/*`, env templates, CI job |
| `d3c11a8` | Smoke test: the CORS check needs an answer before it can pass |

---

## 1. The backend as it is (audit, `d3c11a8`)

| Area | Fact |
| --- | --- |
| Runtime | Node 22 (CI and image; `engines` says ≥ 20), NestJS 10.4, Prisma 5.22, `nestjs-pino` 4 |
| Schema | **97 migrations, `0001` … `0098_messaging_records`** (`0028` was never created). The staging database starts empty and receives all 97. |
| Database | MySQL 8. Needs the strict default `sql_mode` (CI's) and `log_bin_trust_function_creators=1` (append-only triggers, ERROR 1419 otherwise). utf8mb4. UTC. |
| Identities | `deploy/mysql-identities.sql`, CI-gated: `phonestore_migrator` (DDL), `phonestore_app` (DML only; **the audit triggers check this exact name**), `phonestore_backup` (read-only), `phonestore_admin` (operator) |
| Routes | `/api/v1/...`; health is `/api/health`, `/api/health/ready`, `/api/health/version` (unversioned) |
| Proxy | `API_INGRESS` selects `trust proxy`. The stack uses `network`: exactly one trusted hop, the edge. Rate limits and audit IPs depend on it being right. |
| CORS | An exact allowlist from `CORS_ORIGINS`. Empty means `origin: false`: no browser origin is granted. There is no wildcard path. |
| Guards | The production guard (`src/common/config/production-guard.ts`) runs whenever `NODE_ENV=production`. Staging sets `NODE_ENV=production` + `APP_ENV=staging` so it runs the production code paths. |
| Workers | No switch. Every API process runs four workers: the WhatsApp webhook queue, the rollup outbox, the recognition outbox and the trial-end sweeper. Each is lease- or row-lock-guarded, so two processes are safe. Staging runs one. |
| Webhook | `POST /api/v1/messaging/whatsapp/webhook` with the raw body (`rawBody: true`) and HMAC (`X-Hub-Signature-256`). It answers **404 until both `WHATSAPP_APP_SECRET` and `WHATSAPP_WEBHOOK_VERIFY_TOKEN` are set**. |
| Storage | Expense-receipt photos under `UPLOAD_DIR`: a persistent volume. Nothing else is written to disk. |
| PDF | Rendered on the phone (`expo-print`); the API serves JSON only. Nothing to install on the host. |
| SMTP / WhatsApp | `EMAIL_CHANNEL` = `disabled` or `smtp` (Brevo). `WHATSAPP_CHANNEL` = `disabled` or `cloud`, with `WHATSAPP_MODE=test` and `WHATSAPP_LIVE_SENDS=disabled` (D181). |
| Staging codes | With no channel, `STAGING_CONTACT_OUTBOX=enabled` keeps each code in memory. `scripts/staging-verification-code.ts` re-derives it from the database for one named contact (§6.4). |
| Logging | JSON (`pino`), per-request id. The redaction of authorization, cookies, tokens, codes and setup tickets was proven in an earlier phase (T10). The outbox line now masks the contact (`0c12bf2`). |
| Backups | `deploy/backup-encrypted.sh` (gzip + AES-256 + sha256), `deploy/restore-drill.sh` (into a throw-away schema, compared table by table), `docs/22` |

**Found and fixed while preparing** (all in `0c12bf2`/`f8761c3`, with tests):
1. `/health/ready` only checked for an *unfinished* migration. An image whose migrations had **not been run at all**
   reported ready. It now compares the migration names the image carries with the finished ones; the contract test
   pins that only names are read, never SQL.
2. The staging outbox logged the full email/phone of every code request. It is now masked.
3. The staging code lookup could not read a keyed (`hashVersion` 2, `OTP_PEPPER`) code: every staging API runs with a
   pepper. It now uses the server's own hash function.
4. CI's secret scan was red on `d0a7495` (a test fixture). It is allowlisted, like its sibling.

---

## 2. Architecture and DNS

```
phone (TestFlight) ──https──▶ staging-api.tsxmr.com : 443
                                  │  DNS only (grey cloud), A/AAAA → the host
                     ┌────────────▼────────────── one Linux host ──────────────────────────┐
                     │ edge   Caddy 2.8   :80 → 301 https, :443 automatic certificate        │
                     │   │ network "edge"                                                    │
                     │ api    erp-api:<commit>   :3010 (not published)   uploads volume      │
                     │   │ network "internal" (internal: true — no route out, none in)      │
                     │ db     mysql:8.4   :3306 (not published)   db-data volume             │
                     └──────────────────────────────────────────────────────────────────────┘
                       one-off: migrate (as phonestore_migrator) · tools (as phonestore_app)
```

**Why Caddy, DNS-only** (D190):
- Caddy obtains and renews the certificate itself, so there is no certbot cron. It forwards the client address as
  exactly one hop, which `API_INGRESS=network` trusts.
- A Cloudflare-proxied record would add a second hop. The API would then rate-limit Cloudflare's address instead of
  the phone's.
- Proxying through Cloudflare later is possible, but it is a change: `API_INGRESS`, the real-IP header, and the edge's
  trusted range. It is not a toggle.

**DNS: the owner adds this after the host exists.** Nothing has been added.

| Name | Type | Value | Proxy |
| --- | --- | --- | --- |
| `staging-api` | A (and AAAA if the host has IPv6) | the host's address | **DNS only** |

This does not touch the email records (MX, SPF, DKIM, DMARC, Brevo CNAMEs), which stay as `docs/95` records them.

Ports open on the host's firewall: **22 (SSH, restricted to the owner's address if possible), 80, 443.** Nothing else.

---

## 3. Files and the host layout

In the repository (`erp-backend`):

| Path | Role |
| --- | --- |
| `Dockerfile` | `runtime` target: non-root `node`, no curl, readiness healthcheck, `APP_COMMIT` stamp, `/app/uploads`. `tools` target: the Prisma CLI and operator scripts. |
| `.dockerignore` | Keeps env files, secrets, backups, `node_modules`, `.git` out of every image |
| `deploy/docker-compose.staging.yml` | Project `erp-staging`: `db`, `api`, `edge`, plus `migrate` and `tools` (profile `tools`). Log rotation 10 MB × 5 on every service. |
| `deploy/staging/Caddyfile` | The edge. 16 MB body cap, no `Server` header, one forwarded hop, no access log (the API logs each request already). |
| `deploy/staging/grants-staging.sql` | Creates `phonestore_staging` and grants the four identities on it (§4.2) |
| `deploy/staging/{setup-database,preflight,migrate,deploy,rollback,backup,restore-drill,smoke}.sh` | The operator commands; `lib.sh` is shared |
| `deploy/staging/stack.env.example` | The stack's settings (hostname, ACME email, three host paths) |
| `.env.staging.example` | Every variable the staging API reads, with rules and safe defaults; **no secret value** |

On the host (outside the checkout; owner-only):

```
/srv/erp-staging/
  erp-backend/            the checkout (git clone; deploy.sh refuses uncommitted changes)
    deploy/staging/stack.env      copied from stack.env.example (git-ignored)
  api.env                 copied from .env.staging.example and filled in — mode 600
  secrets/                mode 700 — written by setup-database.sh
    mysql_root.pw migrator.pw app.pw backup.pw admin.pw backup-passphrase   (mode 600)
    database.env          APP_DATABASE_URL + DATABASE_URL as phonestore_app (the API and tools read it)
    migrator.env          DATABASE_URL as phonestore_migrator (only the migrate service reads it)
  backups/                encrypted dumps, deployments.log, current-images.env
```

**Where secrets live, and where they never do:**
- They never live in source, Git history, an image, a build argument, a committed compose file, a frontend variable
  or a document example.
- Database passwords are generated on the host and live only in `secrets/`.
- Application secrets live only in `api.env`. If the chosen host has a secret manager, it may provide `api.env`'s
  values instead.
- CI proves the image carries no `.env*` file (job "staging image and stack files").

---

## 4. Configuration

### 4.1 The API's environment (`api.env`)

Start from `.env.staging.example`; every line there states its rule. The template deliberately does **not** pass:
- the secrets are empty;
- `PUBLIC_SITE_ORIGIN` is empty.

CI requires the preflight to refuse it. Explicit values are required for these:

| Variable | Staging value |
| --- | --- |
| `JWT_ACCESS_SECRET`, `OTP_PEPPER`, `MESSAGING_HASH_KEY` | 48 random bytes each (`node -e "console.log(require('crypto').randomBytes(48).toString('base64url'))"`), all different, never reused in production |
| `PLATFORM_MFA_KEY` | 32 bytes as 64 hex (`…randomBytes(32).toString('hex')`); custody is an owner decision (`docs/77` O-C3) |
| `PUBLIC_API_ORIGIN` | `https://staging-api.tsxmr.com` |
| `PUBLIC_SITE_ORIGIN` | an https origin; owner decision §10 (today `https://tsxmr.com` is the only site) |
| `CORS_ORIGINS` | **empty** (stated). The app is native and needs no CORS. A future staging portal adds its exact origin, never `*`. |
| `COOKIE_SECURE=true`, `SWAGGER_ENABLED=false`, `SEED_DEMO=false`, `LOG_LEVEL=info`, `PLATFORM_ADMIN_KEY=` (empty) | as written |
| `THROTTLE_*`, `AUTH_THROTTLE_LIMIT`, `ACCOUNT_THROTTLE_LIMIT` | the template's values, stated |

> **When `dukan-portal-lifecycle` is merged (2026-10-18, D202; not yet).**
> - `PUBLIC_SITE_ORIGIN` is replaced by `PORTAL_ORIGIN`: staging's own HTTPS portal origin. The staging preflight
>   refuses the production portal `https://dukan.tsxmr.com`: staging messages would send Owners there.
> - `CORS_ORIGINS` must then name that portal's exact origin.
> - Migration `0099` is applied after a verified backup (`docs/22`, `docs/101` §13).
| `STAGING_CONTACT_OUTBOX` | `enabled` (codes retrievable from the shell) — must be stated either way |
| `EMAIL_CHANNEL` | **`disabled`** until §4.3 |
| `WHATSAPP_CHANNEL` | **`disabled`**, or `cloud` with `WHATSAPP_MODE=test`, `WHATSAPP_LIVE_SENDS=disabled` and the approved test numbers |

The compose file **forces**, whatever `api.env` says:
- `APP_ENV=staging`, `NODE_ENV=production`, `PORT=3010`;
- `API_INGRESS=network`, `UPLOAD_DIR=/app/uploads`.

`APP_COMMIT` and `APP_BUILT_AT` come from the image.

### 4.2 The database: a dedicated server, schema `phonestore_staging` (D191)

- The staging MySQL is its own server in the stack, on its own volume. **It is never the owner's PC database, and
  never production's server.**
- The schema is `phonestore_staging`. `setup-database.sh` runs the CI-gated `deploy/mysql-identities.sql` unchanged,
  then `grants-staging.sql`, which grants the same four identities the same privileges on `phonestore_staging`.
  - The identity file's own grants name `phonestore`, a schema that is never created here, so they grant nothing.
- The account **names stay** (`phonestore_app` is what the audit triggers check).
- Isolation comes from the server, the passwords and the network. It does not come from the names.
- `docs/79` §A4's `scripts/qa-boutiques.ts` refuses any schema not named `prisma_qa*`, so it cannot seed
  `phonestore_staging` directly. Staging accounts come from:
  - the app's own sign-up flow, with codes from the outbox (§6.4), proven in the rehearsal;
  - or a `prisma_qa*` copy seeded on a disposable server and restored into `phonestore_staging`.

  Do **not** relax the guard.

### 4.3 Messaging stays off until its proofs exist

- **Email (Brevo SMTP): `disabled`.**
  - The Brevo SMTP key shared in chat on 2026-10-17 is compromised and **must never be used**. The owner rotates it in
    Brevo and supplies the new key through the host's secret store (`SMTP_PASSWORD` in `api.env`).
  - The preflight refuses `EMAIL_CHANNEL=smtp` without `SMTP_KEY_ROTATED_ON` later than 2026-10-17.
  - `docs/98` §2 is the procedure.
- **WhatsApp (Meta Cloud API): `disabled`.**
  - When the owner supplies the app and number proofs, use `cloud` in **test** mode only, to the allowlisted numbers
    (preflight-enforced).
  - Webhook URL for Meta: `https://staging-api.tsxmr.com/api/v1/messaging/whatsapp/webhook`, field `messages`.
  - `docs/98` is the procedure.

---

## 5. The preflight

`deploy/staging/preflight.sh` reads exactly what the API will read (`api.env` + `secrets/database.env`, in the tools
image). It prints names and lengths, never a value. It fails on:
- the wrong identity (`APP_ENV`, `NODE_ENV`, `API_INGRESS`, `API_BIND`, `PUBLIC_API_ORIGIN`);
- a database URL that is not `phonestore_app` on `phonestore_staging`, or any shadow URL;
- a secret that is short, a placeholder, or equal to another; an MFA key that is not 32 bytes;
- Swagger on, cookies not secure, the demo seed on, debug logging, or a static admin key;
- `CORS_ORIGINS` unstated, or an entry that is not an exact https origin (no `*`, path or slash);
- `PUBLIC_SITE_ORIGIN` not an exact https origin; throttles unstated; `UPLOAD_DIR` not the volume;
- `STAGING_CONTACT_OUTBOX` unstated;
- email: SMTP without a post-2026-10-17 rotation date;
- WhatsApp: not test mode, live sends not disabled, or no E.164 allowlist.

`migrate.sh` and `deploy.sh` run it first; nothing is replaced when it fails. The API's own production guard is a
second, independent check at start-up.

---

## 6. First deployment checklist

Every command runs from `/srv/erp-staging/erp-backend`, as a user in the `docker` group, after the inputs of §10 exist.

1. **Host.**
   - [ ] Docker Engine with the Compose plugin (`docker compose version` ≥ 2.20).
   - [ ] Firewall allows 22, 80 and 443 only.
   - [ ] The clock is synced (NTP).
   - [ ] Automatic security updates are on.
2. **DNS.** [ ] `staging-api` A/AAAA → the host, DNS only. Check: `dig +short staging-api.tsxmr.com` returns the host.
3. **Checkout.** [ ] `git clone` of `erp-backend`, then `git checkout reports-export` (or the commit the handoff names).
4. **Stack settings.**
   - [ ] `cp deploy/staging/stack.env.example deploy/staging/stack.env`.
   - [ ] Set `ACME_EMAIL` (an address that is read).
   - [ ] Check the three paths.
5. **API environment.**
   - [ ] `install -m 600 .env.staging.example /srv/erp-staging/api.env`, then fill it in per §4.1.
   - [ ] Generate every secret on the host; never paste one into chat.
6. **Deploy.** [ ] `deploy/staging/deploy.sh`. It:
   1. refuses a dirty tree;
   2. builds `erp-api:<commit>` and `erp-api-tools:<commit>`;
   3. on the first run, `setup-database.sh` generates the five passwords and the backup passphrase, starts MySQL, and
      creates the identities and the schema;
   4. `migrate.sh`: preflight, then a backup (skipped on an empty schema), then `prisma migrate deploy` as the
      migrator (**97 applied**), `migrate status`, the permission catalogue (73/73) and the identity checks;
   5. starts the API and waits until `/api/health/ready` is true;
   6. starts the edge (the certificate is issued on the first request);
   7. records the deployment in `backups/deployments.log` and the images in `backups/current-images.env`;
   8. runs the smoke test (§9.1).
7. **Off-host copy of the backup passphrase.** [ ] Copy `secrets/backup-passphrase` to the owner's password manager.
   Without it no backup can be read.
8. **First platform administrator** (shell only; there is no HTTP route and no default credential):
   ```bash
   read -rs PLATFORM_ADMIN_PASSWORD && export PLATFORM_ADMIN_PASSWORD
   docker compose --env-file deploy/staging/stack.env -f deploy/docker-compose.staging.yml --profile tools \
     run --rm -e PLATFORM_ADMIN_PASSWORD tools npx ts-node --transpile-only prisma/create-platform-admin.ts <email> "<name>"
   … run --rm tools npx ts-node --transpile-only prisma/platform-admin-mfa.ts enrolment-token <email>
   unset PLATFORM_ADMIN_PASSWORD
   ```
   Then enrol the second factor (`docs/75` §9).
9. **Staging codes** (while no channel is live):
   ```bash
   … run --rm tools npx ts-node --transpile-only scripts/staging-verification-code.ts <the email or number>
   ```
   It answers for **one named contact**. It refuses outside `APP_ENV=staging`, never lists contacts, and prints the
   code to the operator's terminal only.
10. **Restore drill.** [ ] `deploy/staging/restore-drill.sh` once there is data (§7). Record it in the handoff.
11. **Record.**
    - [ ] Add the commit, image tags, migration count and smoke result to `CURRENT_HANDOFF.md`.
    - [ ] Record the backup file name and the drill result there too.

### 6.1 Later deployments

`git pull` (fast-forward only), then `deploy/staging/deploy.sh`. The previous image stays on the host as the
rollback target, and `deployments.log` names it.

Images built elsewhere: `SKIP_BUILD=1 API_IMAGE=… TOOLS_IMAGE=… deploy/staging/deploy.sh`.

Keep the last three image pairs. Prune older ones: each pair is about 2.2 GB.

---

## 7. Backups and restore

| Command | What it does |
| --- | --- |
| `deploy/staging/backup.sh` | Runs as `phonestore_backup` inside the database container. Writes `backups/phonestore_staging-<UTC>.sql.gz.enc` plus `.sha256`. |
| `deploy/staging/restore-drill.sh [file]` | Runs as `phonestore_admin`. Decrypts and checks the sha256, restores into `phonestore_staging_drill_<stamp>`, then compares it with the live schema: tables, triggers, key row counts, binary keys, trigger bodies and every table's `CHECKSUM`. It then **drops the copy**. The live schema is never touched. |

- **Schedule:** a daily `backup.sh` from the host's cron. Copy `backups/` **off the host** (owner decision §10:
  where to).
- **Retention:** 14 days on the host.
- `migrate.sh` always takes a backup before migrating a non-empty schema.

**Restoring for real:**
- Restore into a **new** schema; never drop the live one. Use `KEEP_DRILL=1` with the restore drill, then point
  `APP_DATABASE_URL` at it and redeploy.
- Production is the same procedure with production's own files.
- `docs/22` holds the rules.

---

## 8. Rollback

**Code only:** `deploy/staging/rollback.sh erp-api:<previous commit>`.
- It puts the previous image back, waits for readiness, re-records the images and runs the smoke test.
- The database is not rolled back.

The older code then runs on the newer schema. That is safe while the newer migrations are additive (the project's
rule), but **not across the floors in `docs/79` §C1**:
- never below `0092` once money-agent exchanges exist;
- never below `0097` while a seat allocation is "scheduled".

Readiness does not block a rollback, and that is intended. The older image carries fewer migration names than the
database has finished, so nothing is missing and it reports ready. Readiness only blocks the opposite case: an image
whose migrations have not been applied.

**Database rollback** means restoring the pre-migration backup into a new schema (§7). That is a separate, deliberate
step, and a Git rollback never does it.

**Website rollback** (for comparison): Cloudflare Pages deployment `b4737b88` is the previous production (§11 of the
handoff).

---

## 9. Verification

### 9.1 Automated: the smoke test (`deploy/staging/smoke.sh`, run by `deploy.sh`)

Read-only, unauthenticated, no secret. **Rehearsal: 12/12** (the TLS and redirect checks are skipped against Caddy's
local certificate).

1. TLS certificate valid for the host, more than 7 days left.
2. `http://` → `https://` (301/308).
3. `/api/health` 200 with the database up.
4. `/api/health/ready`: ready, 0 unfinished, **0 missing** migrations.
5. Environment is `staging`.
6. `/api/health/version`: the deployed commit.
7. `/docs` is 404.
8. `/api/v1/auth/me` returns 401 anonymously.
9. Errors carry no stack trace.
10. `nosniff`, frame denial, no `X-Powered-By`.
11. Rate-limit headers are present.
12. CORS grants nothing to an unknown origin.
13. The webhook refuses a wrong verify token.
14. The webhook refuses an unsigned body.

Pass `--allowed-origin https://…` once `CORS_ORIGINS` names one; the smoke test then checks it gets exactly itself.

### 9.2 Automated on the host, after the first deployment (operator, read-only)

| Check | Command / expectation |
| --- | --- |
| MySQL is not reachable from outside | from another machine: `nc -vz staging-api.tsxmr.com 3306` fails; `docker compose … ps` shows no published port but 80/443 |
| Identities | `migrate.sh` step 5: 21 passed, 0 failed (audit-trigger probes run once a company exists) |
| Strict mode and UTC | `SELECT @@sql_mode, @@time_zone, @@log_bin_trust_function_creators` |
| Throttle | 11 quick `POST /api/v1/auth/login` → the 11th is 429 (`AUTH_THROTTLE_LIMIT=10`) |
| Log hygiene | `docker compose … logs api` after a sign-in and a code request: request ids present; no authorization, cookie, password, token, `?t=` or code; contacts masked |
| Restart | `docker compose … restart api` → ready again; a host reboot brings all three back (`restart: unless-stopped`) |
| Backup and restore | `backup.sh`, then `restore-drill.sh` → PASSED |
| Rollback | `rollback.sh erp-api:<previous>` → smoke shows the previous commit; then deploy forward again |

### 9.3 Needs a device or a provider (cannot be automated here)

| Check | Needs |
| --- | --- |
| A TestFlight build with `EXPO_PUBLIC_API_ORIGIN=https://staging-api.tsxmr.com` and `EXPO_PUBLIC_APP_ENV=staging` signs up (code from §6 step 9), signs in, sells, closes a day | an iPhone, an EAS/TestFlight build |
| Expense receipt upload from the phone, and it survives a restart | an iPhone |
| Email delivery of a code (Brevo) | the rotated key, `EMAIL_CHANNEL=smtp`, a test inbox |
| WhatsApp test-mode delivery + webhook status callbacks | Meta app proofs, test numbers, `WHATSAPP_CHANNEL=cloud` |
| Certificate renewal | time (Caddy renews about 30 days before expiry) |
| Off-host backup copy and a restore on another machine | the owner's off-host location |

The mobile app needs nothing else from the API.
- `EXPO_PUBLIC_API_ORIGIN` is an **origin**; the app appends `/api/v1`.
- A native app sends no `Origin` header, so CORS does not apply to it.

---

## 10. Inputs only the owner can give (blockers for the first deployment)

1. **The host**, meeting §11. Chosen and paid for by the owner; this document recommends no provider.
2. **DNS:** `staging-api` A/AAAA, DNS only.
3. **`ACME_EMAIL`:** where certificate notices go.
4. **`PUBLIC_SITE_ORIGIN`** for staging: `https://tsxmr.com`, or a staging portal's origin once one exists. Until a
   portal exists the trial's setup links have nowhere to land in staging.
5. **Custody of `PLATFORM_MFA_KEY` and the backup passphrase** (`docs/77` O-C3), and the off-host backup location.
6. **The first platform administrator's** email and name (§6 step 8).
7. **Brevo:** rotate the SMTP key exposed on 2026-10-17 and supply the new one through the host's secret store. Until
   then email stays `disabled`.
8. **WhatsApp:** the Meta proofs and the approved test numbers (`docs/98`). Until then WhatsApp stays `disabled`.

---

## 11. Host requirements sheet

| Item | Requirement |
| --- | --- |
| OS | A current 64-bit Linux with long-term support (e.g. Ubuntu 24.04 LTS or Debian 12), x86-64 or arm64 (all three images exist for both) |
| CPU / memory | **2 vCPU, 4 GB RAM** recommended. 2 GB is the floor: MySQL 8.4 plus the API plus a build. *Estimate, not measured under load.* |
| Disk | **40 GB SSD**: images (runtime about 0.8 GB, tools about 1.4 GB, MySQL about 1.1 GB, three pairs kept), the database, 14 days of encrypted dumps, uploads, logs (capped at 50 MB per service) |
| Software | Docker Engine with the Compose v2 plugin; `git`; nothing else (Node, MySQL and Caddy run in containers) |
| Network | A public IPv4 (IPv6 optional); inbound 22/80/443 only; outbound HTTPS (image pulls, npm during builds, Let's Encrypt; later Brevo 587 and graph.facebook.com 443) |
| Access | SSH keys only, no password login; one non-root deploy user in the `docker` group |
| Backups | A place off the host for the encrypted dumps (any object store or another machine). The passphrase is stored separately. |
| Isolation | Not shared with production: production gets its own host or at least its own stack, database server and secrets |
| Must not | Expose MySQL; run the API as root; hold the owner's live/PC database; carry production secrets |

Container runtimes on a platform-as-a-service can work too, provided they give the stack:
- persistent volumes for MySQL and uploads;
- a private network between the containers;
- a way to run one-off migrate and tools containers.

Cloudflare Pages cannot host the API.

---

## 12. Rehearsal (2026-10-17, this container)

The stack was stood up locally with the committed scripts, under three substitutions:
- Caddy's internal certificate for `staging-api.localhost`;
- generated throwaway secrets;
- a rehearsal-only copy of the Dockerfile whose base already carried OpenSSL, because this container's network blocks
  Debian mirrors. The real Dockerfile is built by CI (job "staging image and stack files", green on `d3c11a8`).

| Step | Result |
| --- | --- |
| `setup-database.sh` | MySQL 8.4.11; sql_mode `ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION`; `+00:00`; `log_bin_trust_function_creators=1`; four identities |
| `migrate.sh` | preflight PASS; 97 applied; up to date; catalogue 73/73; identities 16 passed (empty schema) |
| API + edge | healthy; smoke 12/12; readiness 97 of 97 carried |
| Sign-up through the edge | register 201, then code start 200 (outbox; log shows `r***@example.test`), then retrieval with the pepper, then confirm 200 with a session |
| `backup.sh` + `restore-drill.sh` | empty: PASSED. With 2 companies: PASSED (118 tables, 53 triggers, binary keys, 118 CHECKSUMs). |
| `migrate.sh` again, on data | backup taken; nothing to apply; identities **21 passed**, including the five audit-trigger probes |
| Docker daemon restart (reboot) | all three back, healthy; data kept; smoke 12/12 |
| `rollback.sh` | the previous image is serving (`--commit` checked); logged |
| `deploy.sh` on the committed tree | `SKIP_BUILD=1`: preflight, backup, migrate, identities, API, edge; images recorded; manual smoke 12/12 with `--commit` |
| Teardown | `compose down -v`; scratch secrets deleted |

The rehearsal found and fixed three things:
- the CORS smoke check passed against an unreachable host (`d3c11a8`);
- commands after a deploy or rollback would have rebuilt from the checkout instead of using the deployed images
  (`current-images.env`, `33723da`);
- the readiness gap (§1).

---

## 13. The host as prepared (2026-10-18, CLAUDE, local)

The owner provisioned a Hetzner Cloud **CX23** `tsxmr-app-01` (project TSX-MR, `nbg1`, role
**production-preparation**) and asked for hardening only. **Nothing of the ERP is on it**: no checkout, no
`/srv/erp-*`, no `api.env`, no database, no container, no DNS record.

The address and the host-key fingerprint are kept only in the owner's private provisioning file, never in Git.
**Role note:** this document describes a *staging* stack, and §11 says staging and production never share a host. The
server's role is recorded as `production-preparation`, so the owner decides which stack it receives before the first
deployment. It must not receive both.

| Item | State |
| --- | --- |
| OS | Ubuntu 24.04.4 LTS, x86-64, kernel 6.8.0-147 after updates (6.8.0-138 kept as a fallback) |
| Resources | 2 vCPU, 3.7 GiB RAM, 38 GB ext4 root (12 % used after setup), 2 GB swap file, `vm.swappiness=10` |
| Network boundary | the Hetzner Cloud firewall: 22 from the owner's /32 only, 80/443 public, ICMP; nothing else. **No host firewall** (`ufw` inactive): Docker publishes ports around `ufw`, so it would protect nothing the cloud firewall does not, and could mislead. |
| SSH | host key ED25519 accepted trust-on-first-use with the owner's approval and matched on the host. Drop-in `/etc/ssh/sshd_config.d/00-tsxmr-hardening.conf`: no passwords, no keyboard-interactive, no empty passwords, **no root login**, public keys only, port 22. Only `publickey` is offered. |
| Administrator | `tsxmr-admin` (uid 1000), key `tsxmr-production-admin` only, password locked. Groups `sudo` and `docker`. Sudo without a password (`/etc/sudoers.d/90-tsxmr-admin`, validated), because there is no password to type and **`docker` membership is root-equivalent anyway**. This is also §11's deploy user. |
| Updates | every update installed (98 security) and rebooted. `unattended-upgrades` on for the security origin, with no automatic reboot: a reboot stays an operator decision. |
| Time | `systemd-timesyncd` against ntp.hetzner.com, UTC |
| Logs | persistent journal capped at 500 MB, 2 GB kept free, one month (`/etc/systemd/journald.conf.d/50-tsxmr.conf`); `logrotate.timer` active |
| Docker | Engine 29.9.1 and Compose v5.6.0 from Docker's apt repository (signing key fingerprint `9DC8 5822 9FC7 DD38 854A E2D8 8D81 803C 0EBF CD88` checked before use). Enabled at boot. **Unix socket only, no TCP**. Default log rotation 10 MB × 3 (`/etc/docker/daemon.json`); the compose file's own 10 MB × 5 applies to the stack. No container and no image. |
| Listening after reboot | `sshd` :22 only, plus the local resolver and DHCP client. From outside: 22 open; 80, 443, 2375, 3306 and 3010 closed (nothing serves 80/443 yet). |

**Before the first deployment** (§6):
- the owner's role decision above;
- the §10 inputs;
- the `staging-api` or `api` DNS record (DNS only);
- `ACME_EMAIL`;
- then §6 step 3 onward as `tsxmr-admin`.

Re-check the owner's address if SSH stops connecting: a home address can change, and the firewall's /32 must then be
updated in Hetzner.

---

## 14. The browser-test site (2026-10-19, CLAUDE, cloud; D215) — prepared, not deployed

The app's Expo web export is served by this stack's edge on its own hostname, behind basic authentication. The
design, the rehearsal and the journeys are in `docs/102`.

**Before anything:** the owner confirms the hostname (proposed `erp-test.tsxmr.com`, one level under `tsxmr.com`) and
adds its A record **DNS only**, like `staging-api`. Caddy then obtains a certificate for exactly that name. Do not
assume any other name, nested or proxied, is covered by an existing certificate (`docs/102` §5).

**This host only.** Production now runs on `tsxmr-app-01` (`docs/100` §14). §11 holds: the staging stack, and
therefore this site, need their own host.

**Files (backend `b0758c2`):**
- `deploy/staging/web-test.caddy`: the site block, with basic auth on every path, noindex, no framing, HSTS, immutable
  bundles and `no-cache` pages.
- `deploy/staging/Caddyfile`: `import /srv/erp-web/enabled/*.caddy`, which matches nothing until the site is enabled.
- Compose mounts `STAGING_WEB_DIR` at `/srv/erp-web`, or `deploy/staging/web-off` when it is unset.
- `deploy/staging/web-test.sh install <release> | off | restart-edge`.

**Settings:**
- `stack.env`: `STAGING_WEB_HOST`, `STAGING_WEB_DIR`, `STAGING_WEB_USER`, and `STAGING_WEB_PASSWORD_HASH` (bcrypt,
  single-quoted; `docker run --rm -it caddy:2.8 caddy hash-password`).
- `api.env`: `CORS_ORIGINS` must name `https://<STAGING_WEB_HOST>` exactly (the API is redeployed after the change).

**Install:**
1. Build the release on any machine with the mobile checkout (`docs/102` §8.1 step 4). It is a `site/` directory plus
   a `routes.caddy` generated from it.
2. Copy it to the host.
3. Run `deploy/staging/web-test.sh install <dir>`. Before touching the edge, it refuses:
   - an unset, malformed or production hostname, or the API's own;
   - a missing user or a non-bcrypt hash;
   - CORS that does not name the site;
   - an incomplete release.

   It then copies the release under `releases/<UTC time>`, points `current` at it and enables the site. It validates
   the whole edge configuration, putting the previous state back if that fails, and restarts the edge (the API
   pauses for seconds). Finally it checks that `/`, `/login` and the bundles answer **401** without a password, and
   logs the change in `deployments.log`.

**Rollback:** `ln -sfn releases/<previous> $STAGING_WEB_DIR/current && deploy/staging/web-test.sh restart-edge`.
**Off:** `web-test.sh off`.

**Verification on the host after install** (the operator holds the password):
- `curl -sI https://erp-test.tsxmr.com/` answers 401;
- with `-u <user>`: 200, `X-Robots-Tag: noindex, nofollow, noarchive`, and no `Server` header;
- `https://erp-test.tsxmr.com/sales/x` (authenticated) answers 200 with the sale page's HTML;
- `/nope` answers 404.
