# 100 — Deploying the production API (api.tsxmr.com) on tsxmr-app-01

**Status (2026-10-18, CLAUDE, local): implemented and rehearsed once on the host. The clean production deployment has
NOT been made.** It waits for the owner's explicit approval after the rehearsal report (§12).

- **Host:** Hetzner Cloud CX23 `tsxmr-app-01` (project TSX-MR, `nbg1`), hardened per `docs/99` §13.
  - Role: **production-preparation → production**. It is never a persistent staging host.
  - Its address and host key are in the owner's private provisioning file only.
- **Code:** `erp-backend` branch `production-deploy` (from `reports-export` `d3c11a8`), final commit `644f4f5`.
  - Rehearsed: `53ff5a6`. `644f4f5` adds only the teardown's `rmdir` (applied by hand in the rehearsal) and npm's
    update notifier switched off in the one-off containers.
  - CI green on every commit the server ran. Decision D200.
- **Supersedes nothing in `docs/99`.**
  - The staging package stays as it was.
  - Production reuses its reviewed parts and adds its own stack, scripts and policy (§1).
  - Staging and production never share a host, a database server, secrets, an env file or a directory, and the scripts
    enforce it (§9).

---

## 1. What is reused, and what is production's own

**Reused unchanged:**
- the `Dockerfile`, with its `runtime` and `tools` targets;
- `deploy/mysql-identities.sql`, whose grants already name `phonestore`, production's schema;
- `deploy/verify-mysql-identities.sh`;
- the shape of the Caddy edge.

**Reused, extended without changing staging's behaviour:**
- `deploy/restore-drill.sh` gains `BACKUP=-`: a decrypted stream on standard input. It also compares more:
  - BINARY(16)-key digests of `companies` and `users`;
  - the money sums of `sales.total` and `payments.amount`.
- `deploy/staging/smoke.mjs` gains `--environment` and `--expect-hsts`. Its default is still `staging`.

**Production's own (`deploy/docker-compose.production.yml`, `deploy/production/`):**

| File | Role |
| --- | --- |
| `docker-compose.production.yml` | project `erp-production`. Services: `db` (MySQL 8.4.11, pinned by digest), `api`, `edge` (Caddy 2.11.7, pinned by digest), `migrate` and `tools` (profile `tools`), `email-proof` (profile `proof`). |
| `lib.sh` | the profile rules (production or rehearsal); refusal beside any other stack; `--confirm <host>`; one command at a time (`flock`) |
| `setup-secrets.sh` | generates every database password and API key into files: never printed, never replaced |
| `setup-database.sh` + `schema.sql` | MySQL, the `phonestore` schema, and the four identities from the CI-gated identity file |
| `preflight.sh` / `preflight.mjs` | the production policy (§5) |
| `check-stack.mjs` | the stack contract, checked on the resolved configuration (§8) |
| `migrate.sh` | preflight → backup → migrate as the migrator → catalogue → identities → audit chain |
| `deploy.sh` | the whole deployment: build, secrets, contract, database, migrate, API, edge, record, smoke |
| `backup.sh` / `restore-drill.sh` | age-encrypted backups, and the restore drill with an off-server key (§5) |
| `rollback.sh` | previous image, readiness, smoke |
| `smoke.sh` | the smoke matrix, in production mode |
| `email-proof.sh` | the operator's one-message SMTP delivery proof (§7) |
| `teardown-rehearsal.sh` | removes the disposable rehearsal and proves nothing remains |
| `.env.production.example` | every setting of the API, with **no secret line at all** |

---

## 2. Architecture

```
phone ──https──▶ api.tsxmr.com : 443   (DNS only, A → the host; created by the owner at the clean deployment)
          ┌──────────────── tsxmr-app-01 (Hetzner firewall: 22 from the owner's /32, 80/443, ICMP) ────────────────┐
          │ edge   Caddy 2.11.7   :80 → 301, :443 automatic certificate, HTTP/1.1 + HTTP/2 (no UDP)               │
          │   │ network "edge" (outbound allowed: the relay, the providers, Let's Encrypt)                         │
          │ api    erp-api:<commit>  :3010 unpublished · non-root · no capability · secrets read-only /run/secrets │
          │   │ network "internal" (internal: true — no route in or out)                                         │
          │ db     mysql:8.4.11  :3306 unpublished · root@localhost only · db-data volume                        │
          └─────────────────────────────────────────────────────────────────────────────────────────────────────┘
            one-off: migrate (phonestore_migrator) · tools (phonestore_app) · email-proof (outbound only)
```

`API_INGRESS=network`: exactly one trusted proxy hop, the edge. Rate limits and audit addresses depend on it.

---

## 3. The host layout

```
/srv/erp-production/            owned by tsxmr-admin, mode 700
  erp-backend/                  a clone of the reviewed commit (deploy.sh refuses an uncommitted tree)
    deploy/production/stack.env DEPLOY_PROFILE=production, API_HOST=api.tsxmr.com, ACME_EMAIL, EDGE_* , the three paths
  api.env                       from .env.production.example, mode 600 — settings only, no secret
  secrets/                      mode 700 — NEVER in a backup, never in Git, never printed
    db/   mysql_root.pw migrator.pw app.pw backup.pw admin.pw            (the database container only)
    api/  app_database_url jwt_access_secret otp_pepper messaging_hash_key platform_mfa_key
          smtp_username smtp_password                                    (the owner's, hidden prompt)
    database.env  migrator.env                                           (the one-off containers)
    backup.age-recipients                                                (PUBLIC key(s) only)
  backups/                      phonestore-<UTC>.sql.gz.age + .sha256, deployments.log, current-images.env
```

**Owner decisions in the files:**
- `PUBLIC_SITE_ORIGIN=https://tsxmr.com`;
- `ACME_EMAIL=developer@tsxmr.com`;
- `CORS_ORIGINS` empty (the app is native).

> **When `dukan-portal-lifecycle` is merged (2026-10-18, D202; not yet, and only on the owner's approval).**
> - `PUBLIC_SITE_ORIGIN` gives way to `PORTAL_ORIGIN=https://dukan.tsxmr.com`, which the preflight requires.
> - `CORS_ORIGINS` names `https://dukan.tsxmr.com`.
> - The eight `WHATSAPP_TEMPLATE_*` subscription templates are configured as Meta approves them.
> - Migration `0099` is applied after the encrypted backup and its check (`docs/22`, `docs/101` §13).
> - Every API process runs the minute worker; the outbox lease makes that safe.

---

## 4. Secrets (D200)

- **Files, not values.** Every secret reaches the API as a read-only file under `/run/secrets`, named by `NAME_FILE`.
  - `src/common/config/secret-files.ts` reads them **before** the configuration is imported and validated.
  - So `docker inspect`, `docker compose config` and the env file hold no secret.
  - The plain variable still works for local development.
  - The loader refuses:
    - a secret given both ways;
    - a missing, unreadable, empty or multi-line file.
  - Its errors name the setting, never the content.
  - Files: the API's database URL, `JWT_ACCESS_SECRET`, `OTP_PEPPER`, `MESSAGING_HASH_KEY`, `PLATFORM_MFA_KEY`, the
    SMTP login and key, and (for later) the three WhatsApp secrets.
- **The production guard** (`APP_ENV=production`) refuses:
  - SMTP whose key is not a file (`SMTP_PASSWORD_FILE`);
  - the staging outbox flag in any value;
  - a CORS wildcard;
  - `NODE_DEBUG` (Node's tracing bypasses the log redaction).
- **Generation.** `setup-secrets.sh` writes each value from `openssl rand` straight into its file (mode 600).
  - Values are never printed and never on a command line. An existing file is never replaced.
  - The API container's `node` user has uid 1000, the same as `tsxmr-admin`. It reads its own files through the
    read-only mount, and nothing else can.
- **The owner's SMTP login and key** are typed into a hidden prompt on the server (`read -rs`, over SSH).
  - They are written to `secrets/api/smtp_username` and `secrets/api/smtp_password`, mode 600.
  - They are never in chat, history, an argument, a log or a document.
  - The key exposed in chat on 2026-10-17 was **deleted in Brevo by the owner on 2026-10-18** (the owner's statement),
    and the replacement was entered directly on the server.
  - No safe non-secret identifier of a Brevo key exists, so nothing can detect the old key mechanically, and nothing
    stores it to compare. Its revocation in Brevo is the control.
- **Deletion.** Removing a file on an SSD or a copy-on-write filesystem does not guarantee its blocks are erased. What
  the teardown proves is that nothing reachable on the host still holds the secret (§9.3).

---

## 5. Backups, restore, and the customer-data gate

- **Encryption: age** (X25519 + ChaCha20-Poly1305, authenticated). The earlier AES-CBC + checksum
  (`deploy/backup-encrypted.sh`, kept for the PC procedures) is not used here.
  - A modified or truncated backup **fails to decrypt**; it never restores silently wrong. CI proves it on every push:
    the round trip passes, the wrong key is refused, and a changed byte is refused.
- **Keys.** The server holds only the **public** recipient (`secrets/backup.age-recipients`).
  - The identity that decrypts lives **off the server**: in the owner's password manager, and in the private folder
    `.tsxmr` on the owner's laptop.
  - The server writes backups it cannot read. Losing the server does not lose the means of restoring.
- **`backup.sh`.**
  1. mysqldump runs inside the database container as `phonestore_backup` (read-only, socket).
  2. The stream is gzipped and encrypted on the host; the plaintext never touches the disk.
  3. Before encryption, the stream must carry mysqldump's completion line.
  4. Output: `phonestore-<UTC>.sql.gz.age` and its `.sha256`, mode 600. The newest 14 are kept.
- **`restore-drill.sh --identity /dev/shm/… [--offsite storage-box|laptop] [file]`.**
  1. The operator brings the identity in for the drill, to memory only, on the **same SSH session** that runs it
     (`ssh … 'cat > /dev/shm/…/identity; …drill…; rm …' < identity`), and removes it after. `systemd-logind` deletes a
     user's `/dev/shm` files once their last session ends, so the key cannot outlive the drill.
  2. The checksum is checked first.
  3. The backup is decrypted on the host and restored into `phonestore_drill_<stamp>`, never over the live schema.
  4. The copy is compared, then dropped. The comparison covers:
     - tables, triggers and key row counts;
     - BINARY(16)-key digests, money sums and trigger bodies;
     - every table's `CHECKSUM`.
  5. With `--offsite`, a pass writes `backups/offsite-restore-proof` (kind, file, sha256, time).
- **Production off-site copy: an encrypted Hetzner Storage Box.** Not bought yet: the owner's purchase.
  - A dedicated sub-account restricted to one directory, with its own SSH key held by `tsxmr-admin`.
  - Only the already-encrypted files and their `.sha256` are pushed.
  - Each copy is verified after the push, by checksum on a copy fetched back.
  - Retention: 14 days on the host, 30 on the box.
  - A daily systemd timer runs: backup, then push, then verify.
  - The push and the timer are written when the box exists. They need its real address and key, and are rehearsed then.
- **The customer-data gate (mechanical).** A messaging channel is what lets a business verify a contact and sign up, so
  it is what lets customer data in. The production preflight therefore refuses `EMAIL_CHANNEL=smtp` (or any WhatsApp
  channel) unless `offsite-restore-proof` says `kind=storage-box`.
  - The clean production deployment starts with email **disabled**.
  - It opens only after a backup has been copied to the Storage Box **and restored from it**.
- **The rehearsal** used the laptop as its off-host copy, which the owner allowed for the rehearsal only (§9). That proof
  is `kind=laptop` and never opens production.

---

## 6. Deploying

**First deployment**, once approved (§12):
1. **DNS (the owner, Cloudflare).** Add `api` → A → the server's IPv4, **DNS only** (grey cloud), TTL Auto. Add AAAA
   only if the IPv6 address is added too.
   - Nothing else changes in the zone: MX, SPF, DKIM, DMARC, Brevo, Email Routing and the website records stay as they
     are.
   - Check from the laptop: `nslookup api.tsxmr.com` answers the server.
2. `sudo install -d -o tsxmr-admin -m 700 /srv/erp-production`. Bring in the reviewed commit as a git bundle (the
   server has no repository credential), then `git clone` it and `git checkout <commit>`.
3. `cp deploy/production/stack.env.example deploy/production/stack.env`. Its values are the production ones already.
4. `install -m 600 .env.production.example /srv/erp-production/api.env`. Keep email and WhatsApp disabled.
5. The backup recipient. The owner's age identity is generated on the server into `/dev/shm`. It is copied off over SSH
   to the laptop's `.tsxmr` folder **and** the owner's password manager, then removed from the server. Only its public
   key stays, in `secrets/backup.age-recipients`.
6. `deploy/production/deploy.sh --confirm api.tsxmr.com`. Caddy obtains the certificate on start. The smoke test then
   checks TLS, the redirect, readiness (`0 missing, 0 unfinished`), `environment=production`, HSTS, and the rest of §9.1.
7. The first backup, then the cron or timer once the Storage Box exists.
8. The first platform administrator, from the shell with the owner's private details. The password and enrolment
   token go through hidden prompts:
   `docker compose … --profile tools run --rm -e PLATFORM_ADMIN_PASSWORD tools npx ts-node --transpile-only prisma/create-platform-admin.ts …`

**Later deployments:**
- Bring in a new bundle, `git checkout` the reviewed commit, then `deploy.sh --confirm api.tsxmr.com`.
- The previous image stays as the rollback target (`deployments.log`). Keep three image pairs: each is about 2.2 GB.

**An interrupted or failed deployment** leaves `backups/deploy.inprogress` (the commit and the step) and a line in
`deployments.log`.
- The next run stops until the operator has read them, and says so with `--after-interrupted`.
- Everything it repeats is idempotent: secrets, identities and `migrate deploy`.
- A migration that failed half-way (`P3018`) is `docs/79` §C2, never "run it again".

---

## 7. The SMTP delivery proof

`deploy/production/email-proof.sh --plain-text-approved [--language en|fr|ar]` sends **one** `delivery.check` email per
run, **as plain text only**.

**Why plain text (the owner's decision, 2026-10-18).** Brevo's transactional open and click tracking cannot be turned off
on the account's plan; the owner reports it as Enterprise-only, on request.
- A relay can add an open-tracking pixel only to an HTML part, and click tracking only rewrites links.
- The proof has neither: `SmtpConfig.textOnly` hands over the text part alone, and the message has no link.
- The owner checks the received message's source ("Show original") for anything the relay added.
- Every other email of the API keeps both parts. Whether production's transactional email should also go out as plain
  text, or Brevo's tracking be switched off on request, is an open owner decision (§12) **before customer onboarding**:
  a verification code's open would otherwise be tracked by the provider.

- **The message.**
  - No code, no link, no image, no variable, no customer or business data.
  - It says it is a Dukan ERP delivery test and that no action is required.
  - It goes through the reviewed SMTP channel: port 587, STARTTLS required, certificate verified, no transport debug.
- **Sender:** `Dukan ERP <verification@tsxmr.com>`. **Reply-To:** `support@tsxmr.com`. Both are fixed in code.
- **Recipient:** the owner's test address, read from `secrets/proof/recipient`.
  - Never an argument, and printed masked only (`a***@domain`).
  - The personal address is a **test recipient only**; production senders are the `@tsxmr.com` addresses.
- **Isolation.** The proof container has outbound network only and no database. It gets the SMTP login and key as
  read-only files.
  - The API never sends the proof, and its `EMAIL_CHANNEL` is not touched. In the rehearsal it stayed `disabled`.
- **Log.** Each run appends one line to `backups/email-proofs.log`: the masked recipient, the status, and the provider's
  message id as a one-way reference (`sha256:` + 16 hex).
- **Precondition.** The script refuses without `--plain-text-approved`, which records the owner's decision on each run.

---

## 8. Capacity and monitoring (CX23: 2 vCPU, 3.7 GiB, 38 GB, 2 GB swap)

| Service | Memory limit | CPU | Notes |
| --- | --- | --- | --- |
| db | 1536 MB | 1.5 | InnoDB buffer pool 768 MB, 60 connections, binary log kept 7 days |
| api | 1 GB | 1.5 | Node heap capped at 640 MB (`NODE_OPTIONS`); one process runs the four guarded workers |
| edge | 256 MB | 0.5 | |
| migrate / tools | 1 GB | — | one-off |

**Logs:**
- each container: 10 MB × 5 (compose), 10 MB × 3 (daemon default);
- the journal: 500 MB, keeping 2 GB free, one month.

**Thresholds to act on.** Checked by hand today; a timer-driven check once production runs is a follow-up.

| Signal | Act when |
| --- | --- |
| root disk used | above 75 % (about 28 GB): prune old image pairs (keep 3), check `backups/` and the journal |
| memory available | under 400 MB for more than 10 minutes, or the OOM killer in `journalctl -k` |
| swap used | above 512 MB sustained: the buffer pool or the API heap is too large for the load |
| the newest backup | older than 26 hours |
| the certificate | under 14 days left (Caddy renews about 30 days before expiry) |
| `/api/health/ready` | `ready=false`, or any missing or unfinished migration |
| `restart` counts | any container restarting in a loop |

---

## 9. Separation, the rehearsal and its teardown

### 9.1 The smoke matrix (`smoke.sh`, run by `deploy.sh` and `rollback.sh`)

Read-only and unauthenticated. It checks:
- TLS: in production only; in the rehearsal, Caddy's local authority is skipped with `--insecure-local`;
- the redirect;
- liveness;
- readiness: ready, 0 unfinished, 0 missing;
- `environment=production`;
- the deployed commit;
- `/docs` 404;
- an anonymous `auth/me` 401;
- no stack trace in an error;
- `nosniff`, frame denial, no `X-Powered-By`;
- HSTS of at least 180 days;
- rate-limit headers;
- CORS granting nothing to an unknown origin;
- the webhook refusing a wrong token and an unsigned body.

### 9.2 Profiles and isolation

`DEPLOY_PROFILE` in `stack.env` decides which stack a command acts on, and `lib.sh` enforces its rules.

| | production | rehearsal |
| --- | --- | --- |
| project | `erp-production` | `erp-rehearsal` |
| paths | `/srv/erp-production/…` only | `/srv/erp-rehearsal/…` only |
| host | `api.tsxmr.com` only | a `*.localhost` name only (Caddy's local authority; nothing asked of Let's Encrypt) |
| edge | 80 and 443, every address | `127.0.0.1:8080` and `127.0.0.1:8443` only: never public |
| beside | refuses if any `erp-staging` or `erp-rehearsal` container, volume or network exists | refuses if any `erp-production` or `erp-staging` one exists |

Both run `APP_ENV=production`, so the rehearsal exercises the production code paths.

### 9.3 The rehearsal of 2026-10-18

See §13.

---

## 10. WhatsApp

**Disabled.** The production preflight refuses any `WHATSAPP_CHANNEL` but `disabled`.

Opening it takes a reviewed change to that rule, after:
- the Meta configuration;
- the approved templates;
- the delivery proofs for each language (`docs/98`, `scripts/whatsapp-prove.ts`);
- the production webhook;
- the owner's approval.

Nothing in this phase sent a WhatsApp message or configured a webhook.

---

## 11. Rollback

- **Code:** `rollback.sh erp-api:<previous> --confirm api.tsxmr.com`. It puts the previous image back, waits for
  readiness, records the change and runs the smoke test. The database is not rolled back.
  - That is safe while migrations stay additive.
  - It is **not** safe across `docs/79` §C1's floors: below 0092 once money-agent exchanges exist, or below 0097 while
    a seat allocation is "scheduled".
- **Database:** restore the pre-migration backup into a **new** schema (`KEEP_DRILL=1 restore-drill.sh …`), point the
  API's database URL file at it, and redeploy. Never drop `phonestore` before the restored copy is verified.
- **Rollback floor:** images older than D200 (`0f0ff9b`) cannot read secrets from files: with this stack they refuse to
  start (the configuration validation fails). Production starts at or after `644f4f5`, so every production image can
  read them.
- **Before the clean deployment:** nothing to roll back. The host serves nothing, and the website is untouched.
  - The website's own rollback is Cloudflare Pages deployment `8a828f1b` (= `397ec6b`, before `e953c58`), per its
    handoff.

---

## 12. Before the clean production deployment (owner and operator)

1. **The owner's explicit approval** of the clean deployment, after reading the rehearsal report.
2. **DNS:** `api` → A → the server, DNS only (§6).
3. **The production age identity:**
   - generated on the server into memory;
   - its copy put in the owner's password manager and the laptop's `.tsxmr` folder;
   - removed from the server, leaving only the public key.
4. **The first platform administrator:** the owner's private name, email and WhatsApp number, through hidden prompts
   only.
5. **Then, before any external test, trial or customer:**
   - the **Storage Box**: bought, a sub-account set up, the push and verify timer, and **a restore from it**
     (`offsite-restore-proof kind=storage-box`);
   - only then `EMAIL_CHANNEL=smtp`.
6. **Email tracking:** decide before onboarding how production email avoids Brevo's provider-side tracking. Options:
   - plain text for every transactional email (the proof's mechanism);
   - Brevo switching tracking off on request;
   - disclosing it in the privacy texts.
7. **WhatsApp:** stays disabled (§10).
8. **After the deployment session**, on the owner's laptop: `ssh-add -D`, and stop the `ssh-agent` service (as
   administrator).

---

## 13. Rehearsal record (2026-10-18)

Disposable project `erp-rehearsal` on tsxmr-app-01, 2026-10-18 06:55–07:50 UTC, commits `411f17b` → `8fcac7b` →
`4eed21d` → `53ff5a6`. Each was CI-green before the server ran it, and each arrived as a git bundle, its checksum
equal on both ends.

**Data:** fictitious only. No real customer data, DNS record, public exposure or WhatsApp message was involved.

**Every check:**

| # | Check | Result |
| --- | --- | --- |
| R0 | host key, OS, resources, nothing running, only :22 public | as expected (Ubuntu 24.04.5, 32 GB free, 3.4 GB available) |
| R1 | `age` 1.1.1 from Ubuntu noble-updates | installed (kept: production backups need it) |
| R3 | the rehearsal's backup key | generated in `/dev/shm`, the private half copied to the laptop's `.tsxmr` (compared, never shown), removed from the server; only the public half stayed |
| R4 | `deploy.sh` from empty | build, 13 secret files generated (never printed), contract PASS, MySQL 8.4.11 (strict, UTC, 768 MB pool), schema and identities, preflight PASS, **97/97 migrations**, catalogue, identities 16/0, audit chain, API healthy, edge, smoke |
| R4 | interrupted runs | a failed smoke (`411f17b`) and a failed backup (`8fcac7b`) each left `deploy.inprogress` and a FAILED line; the next plain run was **refused** until `--after-interrupted` |
| R4 | later deployment | encrypted backup before migrating (60 KB), "No pending migrations", identities, audit chain, smoke **13/13**; rollback target recorded |
| R5 | the running stack | 118 tables, 97 finished migrations; root@localhost only; the API's environment holds **0 secret values and 0 database URLs** (only `*_FILE` names); user `node`, capabilities dropped, no-new-privileges, 1 GiB limit |
| R6 | public sign-up with no channel | HTTP 503 `registration_unavailable`, **nothing saved** (0 rows before and after) |
| R6 | fictitious businesses | 3 created through `RegistrationService` (electronics, money services, both); idempotent on a second run |
| R7 | migrate on data | backup taken, nothing to apply, identities **21/21** (append-only trigger probes included), audit chain of 3 companies, 0 broken |
| R8 | a schema missing its migrations | a probe API on an unmigrated schema answers `ready:false` and never becomes healthy, so a deployment would never switch to it; probe, schema and grant removed (0/0/0) |
| R9 | restart recovery | API restart, then a Docker daemon restart: database, API and edge back by themselves; smoke 13/13 |
| R10 | isolation | database: no route out, no DNS. API: reaches the relay :587 and the database. Host: nothing on :3010/:3306; edge only on 127.0.0.1. App: DDL refused (1142). Backup: read-only (1142), refused over the network (1045). From outside: only :22 open |
| R11 | rollback | images of `8fcac7b` built; rollback → smoke 13/13, serving `8fcac7b`; forward → smoke 13/13, serving `4eed21d`; both in `deployments.log` |
| R12 | backup → laptop → back → restore | age file checksum OK on the laptop and on return. Restored into a throw-away copy, all equal: 118 tables, 53 triggers, row counts, binary-key digests, money sums, trigger bodies, every table's CHECKSUM. PASSED, `offsite-restore-proof kind=laptop` |
| R12 | tamper (one byte, checksum recomputed) | **refused by age** ("nothing restored"); the incomplete copy dropped automatically (`53ff5a6`); 0 drill copies left |
| R13 | SMTP proof (plain text) | one message, accepted by Brevo for `a***@gmail.com`, ref `sha256:e9270c18497a807f`. The owner confirmed: inbox, plain text only, SPF/DKIM/DMARC pass, nothing added |
| R14 | WhatsApp | `WHATSAPP_CHANNEL=disabled`, test mode, live sends disabled; webhook 404. The API's `EMAIL_CHANNEL` stayed `disabled` throughout |
| R15 | teardown | containers, volumes (database and identities), networks, images and build cache removed; `/srv/erp-rehearsal` gone |
| R15 | after it | Docker 0/0/0/0/0B; `/srv` = only `erp-production/secrets/api/smtp_{username,password}`. Secret-shaped strings: 0 in the journal and history, 0 identity files, 0 stray files. Only :22 public; root refused; 4.2 GB disk, 3.2 GB memory free. Laptop rehearsal copies deleted |

**Resources measured:**
- images: runtime 788 MB, tools 1.38 GB, MySQL 1.12 GB, Caddy 93 MB;
- running: API 95 MiB, MySQL 595–675 MiB, Caddy 11–19 MiB; host 2.35 GB available, no swap used;
- a full first deployment took 5 m 23 s; a later one about 1 m 40 s.

**Found by the rehearsal and fixed, each with a test:**

| Commit | Defect | Fix |
| --- | --- | --- |
| `d5be850` | scripts stored 100644 (written on Windows), so `deploy.sh` was refused | made executable; test |
| `8fcac7b` | the smoke HSTS regex had lost its backslash | restored; test |
| `4eed21d` | `backup.sh`'s `wait $!` aborted under `set -u` | awk passthrough, per-stage status; test |
| `53ff5a6` | a refused restore left its half-filled drill copy | EXIT trap drops it, and a failed copy is never kept; test |
| `644f4f5` | the teardown could not remove root's `/srv` entry | `rmdir`; test |

**Two observations for the runbook:**
- Ubuntu's `systemd-logind` removes a user's `/dev/shm` files after their last session. Bring the backup key in **on
  the same SSH session** that runs the drill (standard input into `/dev/shm`). It then cannot outlive the session.
- `docker compose run/exec` forward standard input. Run operator scripts as files on the host, never piped into
  `ssh … bash -s`.

---

## 14. Production deployment record (2026-10-19, CLAUDE, local)

**Approval and target**
- The owner approved the clean deployment on 2026-10-18 and 2026-10-19.
- Commit `644f4f5` (CI run 39109070367, 6/6), deployed exactly. The cloud portal branch `dukan-portal-lifecycle` is
  **not** part of it.

**DNS**
- `api.tsxmr.com` is an A record, DNS-only, TTL Auto, with no AAAA.
- Both Cloudflare authoritative servers and 1.1.1.1, 8.8.8.8 and 9.9.9.9 return exactly the server's IPv4, which also
  proves the record is not proxied.
- The first request on 2026-10-18 found no record. The deployment stopped there, before anything was started, until
  the owner created it.

**Steps, in order (`/srv/erp-production`, project `erp-production`)**
1. The commit arrived as a git bundle, its checksum equal on both ends, and was checked out clean.
2. `stack.env` (production profile).
3. `api.env`: email and WhatsApp `disabled`; `CORS_ORIGINS=https://dukan.tsxmr.com` (the owner's approved portal
   origin, exact; the smoke test checks it is granted exactly, and an unknown origin nothing).
4. The production **age backup key**: generated in memory and streamed over SSH into the owner's laptop file
   `.tsxmr\production-backup-identity.txt` (user-only, matched without being shown). Only its public half is on the
   server. **The owner stores it in the password manager.**
5. `setup-secrets.sh`: **9 fresh secrets** (5 database passwords and 4 API keys), never printed. The owner's SMTP login
   and key were left untouched.
6. `setup-database.sh`: MySQL 8.4.11 (strict, UTC, 768 MB pool), the `phonestore` schema and the four identities
   (root@localhost only).
7. An explicit **encrypted pre-migration backup**: `phonestore-20261019T010809Z.sql.gz.age`, of the empty schema.
   `migrate.sh` skips a backup on an empty schema by design.
8. `deploy.sh --confirm api.tsxmr.com`:
   - build, contract PASS, preflight PASS;
   - **97/97 migrations as `phonestore_migrator`**, catalogue, identities 16/0, audit chain;
   - API healthy, edge started.
   - The first smoke failed: it ran seconds before Caddy finished its first Let's Encrypt order, which then succeeded
     ("certificate obtained successfully", HTTP-01).
   - The marker held the next run. `--after-interrupted` re-ran: a backup before the no-op migration
     (`phonestore-20261019T011419Z`, 118 tables), then smoke **15/15**.

**Deployed**
- API image `erp-api:644f4f5…`, id `sha256:7a0e9a08f94f5d251858f38ba9db13b7134aa6b59c2a23a3b5a4909c0d76280b` (751 MB).
- Tools image id `sha256:873ef57c479b…` (1.3 GB).
- `mysql:8.4.11@sha256:24989179…`, `caddy:2.11.7@sha256:685ae3d7…`.

**Verified**
- **TLS from outside:** trusted, TLS 1.3, Let's Encrypt YE2, `DNS:api.tsxmr.com`, valid 2026-10-19 → 2027-01-17.
  `http://` answers 308 to `https://`.
- **Readiness:** `ready:true`, 97 applied, 0 pending, 0 missing, `environment=production`.
- **Headers:** HSTS `max-age=15552000; includeSubDomains`, nosniff, `X-Frame-Options`, CSP, COOP/CORP,
  `Referrer-Policy: no-referrer`, no `Server` or `X-Powered-By`.
- **Smoke:** 16/16, including CORS for `https://dukan.tsxmr.com` exactly.
- **Ports from outside:** 22, 80 and 443 open; 3306, 3010, 2019, 8080, 8443 and 33060 closed. MySQL and the API
  publish nothing; the edge publishes TCP 80/443 only.
- **The API container:** 0 secret values and 0 database URLs in its environment.
- **Restart survival:** an API restart, a Docker daemon restart and a full host reboot (back in about 35 s). Database,
  API and edge returned on their own; smoke 16/16 after each, the certificate kept.
- **Restore proof:** the pre-migration backup decrypts and is complete. The post-migration backup was restored into a
  throw-away copy: 118 tables, 53 triggers, every table's CHECKSUM, then dropped. **PASSED.** The key was brought in
  on the drill's session and removed with it. No off-site proof is recorded: the laptop counts for the rehearsal only,
  and the Storage Box is the production one.
- **Gates closed:**
  - `EMAIL_CHANNEL=disabled`, `WHATSAPP_CHANNEL=disabled`, `WHATSAPP_LIVE_SENDS=disabled`, no templates;
  - a fictitious sign-up attempt answered **503 `registration_unavailable`**, with 0 companies before and after. No
    record was created, so there was nothing to delete and no audit effect;
  - no real account and no real data.
- **Logs:** secret-shaped strings 0 in the journal and the API log; no private age key on the server.
- **Resources:** API 179 MiB, MySQL 650 MiB, Caddy 53 MiB; 2.6 GB of host memory available; 8.6 GB disk of 38 GB.

**Rollback**
- There is no previous release. `deployments.log` names the same image only because the second run re-deployed it.
- To take the API offline: `cd /srv/erp-production/erp-backend && docker compose -p erp-production --env-file
  deploy/production/stack.env -f deploy/docker-compose.production.yml stop edge api`. Volumes and data are kept.
- To roll back a later release: `deploy/production/rollback.sh erp-api:644f4f5984873e2b8c1253998985f1e79b4f3fd9
  --confirm api.tsxmr.com`.

**Deviations from this runbook, and follow-ups**
1. `deploy.sh` runs its smoke test immediately after starting the edge. On a **first** certificate issuance that
   races Let's Encrypt. Follow-up: wait for the certificate (or retry the TLS check briefly) before the smoke.
2. The pre-migration backup was taken by hand, because `migrate.sh` skips an empty schema. A first deployment has
   nothing to protect, but the owner asked for the backup; documented here.
3. `deployments.log` and `current-images.env` were written with the account's umask (0664) inside the 0700 backups
   directory. No secret is in them. Follow-up: `umask 077` in `lib.sh`.
