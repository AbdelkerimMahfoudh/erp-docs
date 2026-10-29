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
    `.tsxmr` on the owner's laptop (`production-backup-identity-v2.txt` since the rotation of §15).
  - The server writes backups it cannot read. Losing the server does not lose the means of restoring.
  - **The identity never goes through an online service.** That includes converters, pastebins and chat. An import file
    for a password manager is built locally (PowerShell), or the entry is added by hand.
  - **If it is exposed, rotate (§15):**
    1. a new identity;
    2. the recipient file holding only its public key;
    3. a fresh backup and a restore proof with the new identity;
    4. then remove the backups made for the old key, once they hold no unique data.
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
4. The production **age backup key**: generated in memory and streamed over SSH into a user-only file in the owner's
   laptop folder `.tsxmr` (matched without being shown). Only its public half was on the server. **This first key was
   exposed the same day and replaced: §15.**
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

---

## 15. Backup-key rotation (2026-10-19, CLAUDE, local)

**Why**
- To import the §14 backup identity into Google Password Manager, the owner converted it to CSV with an online
  converter. The private key left the owner's machines, so it is treated as **compromised**.
- Only two backups had been encrypted for it: the deployment's (`…010809Z`, `…011419Z`). They held an empty
  platform: 0 companies and 0 users.
- Both existed only on the server. No Storage Box exists, and the §14 restore ran on the host.

**Done, in order**
1. **A new age identity.**
   - Generated on the server in `/dev/shm` (memory).
   - Streamed over SSH into the owner's laptop file `.tsxmr\production-backup-identity-v2.txt` (user-only ACL; the
     checksum matched on both ends without being shown).
   - Removed from the server. It is a different key pair from the old one.
2. **The recipient.** `secrets/backup.age-recipients` now holds the new public key alone (mode 600). No private key is
   on the server.
3. **A fresh backup**, to the new recipient only: `phonestore-20261019T015638Z.sql.gz.age` (53 747 bytes) and its
   `.sha256`.
4. **Off-host copy and restore proof.**
   - The backup was copied to the laptop (`.tsxmr\production-backups\`; checksum OK).
   - That copy was returned to a fresh `restore-in` directory on the server. The new identity was brought in on the
     drill's own session.
   - `phonestore_drill_20261019T015651Z`: tables 118, triggers 53, every table's `CHECKSUM` matched; then dropped.
     **PASSED.**
   - The key left with the session (`/dev/shm` `erp-*`: 0), and `restore-in` was removed.
   - This is a laptop proof (`kind=laptop`). It does **not** open the customer-data gate (§5).
5. **The old key's backups removed.** After the unique-data check (companies 0, users 0), the two backups and their
   checksums were deleted from the server.
6. **The new key in the password manager.**
   - The owner imported a CSV built locally with PowerShell (UTF-8, no online converter).
   - The import reported success, but the entry could not be found. The owner then added it by hand: site
     `api.tsxmr.com`, username `age-backup-identity`.
   - Removed from `.tsxmr` and `Downloads`, now in the Recycle Bin for the owner to delete permanently:
     - the import CSV;
     - the old identity file;
     - the converter's CSV.
   - The converter's own copy is outside our control. The replacement makes it worthless: nothing that exists is
     encrypted to it.

**Verified after the rotation**
- **Recipient file:** one line, the new key; the old key is absent.
- **The old public key on the server: 0 files.** Searched in `/srv`, `/etc`, `/home`, `/root`, `/usr/local`, `/opt`,
  `/var/spool`, the Docker volumes, `/var/backups`, `/tmp`, `/var/tmp` and `/dev/shm`. Its value came in on standard
  input, never on a command line.
- **Private age keys on the server: 0 files**, in the same places and `/var/log`. Identity files in `/dev/shm` and
  `/tmp`: 0.
- **Scheduled jobs:**
  - no cron entry, and no unit naming `backup.sh`;
  - the only timer matching "backup" is Ubuntu's own `dpkg-db-backup`, which is unrelated;
  - production backups have no timer yet. It is written with the Storage Box (§5).
- **Backups on the host:** only `…015638Z`. It is the only `.age` file on the server.
- **The four repositories:** the old public key appears 0 times and private age keys 0 times, in the working trees
  and the whole history. All four trees are clean.
- **Documentation:** the old identity's file is no longer named (§14 step 4 amended).
- **The laptop:** the only file holding a private age key is `production-backup-identity-v2.txt`.
- **The API is unchanged** (`644f4f5`): smoke **15/15** after the rotation.
- **Gates still closed:**
  - `EMAIL_CHANNEL=disabled`, `WHATSAPP_CHANNEL=disabled`;
  - `CORS_ORIGINS=https://dukan.tsxmr.com`;
  - onboarding closed: sign-up answered 503 in §14, and neither the image nor `api.env` has changed since;
  - no real account and no real data.

**Not claimed**
- Deleting a file on an SSD does not guarantee its blocks are erased. That is why the old key was **replaced** and not
  just deleted.

---

## 16. Persistent test businesses on production (D217): the deployment runbook (2026-10-20, CLAUDE, cloud)

**What it deploys.** On `tsxmr-app-01`, beside the API and changing nothing on `tsxmr.com`:
- **the API** from erp-backend `superadmin-provisioning`: migrations 0099–0102, provisioning, test businesses, the
  Owner's setup code, and the edge's two test sites;
- **`https://erp-test.tsxmr.com`**: the app's web export (erp-mobile `superadmin-provisioning`), behind a password;
- **`https://dukan-test.tsxmr.com`**: the console (`/admin`) and the Owner's portal (`/subscription`), from
  erp-control-web `superadmin-provisioning` built in preview mode, behind the same password.

`dukan.tsxmr.com` stays reserved for the production portal, which the PORTAL gate still refuses.

**Who runs it.** The owner's local session only: SSH to the server is limited to the owner's address. This cloud
session prepared and rehearsed every step but **deployed nothing**.

**Commits:**

| Repository | Commit | CI |
| --- | --- | --- |
| erp-backend | `f5da650` (superadmin-provisioning) | green (`39379592884`, 6/6), including the edge validated with both sites on |
| erp-control-web | `d1016d8` (superadmin-provisioning, carrying `tsx-public-site` `5aa8322`) | green (`39380223602`) |
| erp-mobile | `da5c73c` (superadmin-provisioning) | green (`39379598714`, 3/3) |

If later commits land, take the heads the handoff names, never older ones.

### 16.1 Before anything (owner)

1. **DNS: two records, DNS only** (instructions for the Chrome extension follow in §16.9). Both must resolve to the
   server before step 9, or Caddy cannot obtain their certificates.
2. **The testers' login name and password.** Choose them yourself. Only the bcrypt hash goes on the server.
3. **The backup identity** (`production-backup-identity-v2`, in the password manager), for the restore proof. It is
   brought into memory for the drill and removed afterwards (§15).

### 16.2 Inspect the server as it is (read-only)

```bash
cd /srv/erp-production/erp-backend
git status --short && git log --oneline -1          # expect a clean checkout at 644f4f5
docker compose -p erp-production --env-file deploy/production/stack.env -f deploy/docker-compose.production.yml ps
curl -s https://api.tsxmr.com/api/health/ready      # ready:true, 97 applied, 0 pending, 0 missing
free -m; df -h /; docker system df                  # stop if available memory < 1.2 GB or root disk > 75 %
sudo docker compose -p erp-production --env-file deploy/production/stack.env \
  -f deploy/docker-compose.production.yml exec -T db sh -c \
  'MYSQL_PWD="$(cat /secrets/mysql_root.pw)" mysql -uroot -N -e "SELECT COUNT(*) FROM phonestore.companies; SELECT COUNT(*) FROM phonestore.users;"'
```

Record the counts. They were 0 and 0 on 2026-10-19 (§15), apart from the platform administrator.

### 16.3 A fresh encrypted backup, copied off the host, and its restore proof

```bash
deploy/production/backup.sh                                     # phonestore-<UTC>.sql.gz.age + .sha256
# On the laptop:  scp the two files into .tsxmr\production-backups\ and check the checksum.
# The restore drill, with the identity in memory only:
umask 077; cat > /dev/shm/age-identity                          # paste the identity, then Ctrl-D
deploy/production/restore-drill.sh --identity /dev/shm/age-identity --offsite laptop
shred -u /dev/shm/age-identity
```

The drill must end **PASSED** (tables, triggers, rows and every CHECKSUM equal). Keep the file name: it is the
**database rollback point**.

### 16.4 The migration, rehearsed (done here; optional again on the laptop)

- **This session.** A 0098-shaped database (production's 97 migrations, with rows) was backed up, migrated to 0102,
  verified, then rolled back by restoring the backup into a new schema. The details are in the handoff.
  - All four migrations applied, and status is up to date.
  - Earlier rows were kept, and the existing business stays a customer's (`is_test` = 0).
  - The restored copy is identical to the pre-migration snapshot.
  - The deployed code `644f4f5` runs on the 0102 schema: ready, 0 pending, 0 missing; sign-in answers normally.
- **Optionally, on the laptop, against the real backup.** Decrypt it into a throw-away MySQL 8.4 container, run
  `npx prisma migrate deploy` from a checkout of `f5da650`, read `migrate status`, then remove the container.

### 16.5 Bring the commit and update the configuration

1. Bring `f5da650` as a git bundle, the same way as §14, and check out the commit with a clean tree.
2. **`api.env`** (mode 600), no secret involved:
   - `CORS_ORIGINS=https://dukan.tsxmr.com,https://erp-test.tsxmr.com,https://dukan-test.tsxmr.com`
   - `CUSTOMER_ACTIVATION=closed`
   - `PORTAL_ORIGIN` stays `https://dukan.tsxmr.com`;
   - email and WhatsApp stay `disabled`.
3. `deploy/production/setup-secrets.sh` creates the one missing secret, `staff_invitation_key`. It replaces nothing.
4. **`stack.env`:**
   ```
   WEB_DIR=/srv/erp-production/web
   TEST_APP_HOST=erp-test.tsxmr.com
   TEST_CONSOLE_HOST=dukan-test.tsxmr.com
   TEST_WEB_USER=<the testers' login>
   TEST_WEB_PASSWORD_HASH='<bcrypt>'   # docker run --rm -it caddy:2.11.7 caddy hash-password  (typed at its prompt)
   ```

### 16.6 Deploy the API

```bash
deploy/production/deploy.sh --confirm api.tsxmr.com
```

- It runs, in order: build, secrets, contract, preflight, a backup before migrating, then **0099 → 0102 as the
  migrator**, the catalogue, the identities, the audit chain, the API, the edge, and the smoke test.
- On the CX23 the build ran on the host before (§14). If step 16.2 showed under 1.2 GB available, build the two
  images on the laptop, load them with `docker save | ssh … docker load`, and deploy with `SKIP_BUILD=1 API_IMAGE=…
  TOOLS_IMAGE=…`.
- Then the smoke test for each test origin:
  ```bash
  deploy/production/smoke.sh --allowed-origin https://erp-test.tsxmr.com
  deploy/production/smoke.sh --allowed-origin https://dukan-test.tsxmr.com
  ```

### 16.7 Build the two sites off the server (laptop), then install them

```bash
# The app (erp-mobile da5c73c):
npm ci
EXPO_PUBLIC_API_ORIGIN=https://api.tsxmr.com EXPO_PUBLIC_LEGAL_ORIGIN=https://tsxmr.com \
  npx expo export --platform web --clear --output-dir /tmp/erp-web-export
node scripts/web-test-release.mjs /tmp/erp-web-export /tmp/erp-app-release https://api.tsxmr.com --production-api
# The console and portal (erp-control-web d1016d8):
npm ci
VITE_SITE_SURFACE=portal VITE_API_BASE=https://api.tsxmr.com/api/v1 VITE_PORTAL_ORIGIN=https://dukan-test.tsxmr.com \
  npm run build:preview
node scripts/caddy-release.mjs dist /tmp/erp-console-release https://dukan-test.tsxmr.com https://api.tsxmr.com/api/v1
```

`--clear` matters. A cached Metro bundle kept an earlier API origin in this session's first export.

Copy both release directories to the deploy user's home and check them. Then:

```bash
deploy/production/test-sites.sh install app ~/erp-app-release --confirm api.tsxmr.com
deploy/production/test-sites.sh install console ~/erp-console-release --confirm api.tsxmr.com
```

Each refuses before touching the edge, in any of these cases:
- a production or missing name, or one name for both sites;
- a hash that is not bcrypt;
- an API whose `CORS_ORIGINS` does not name the site exactly;
- `CUSTOMER_ACTIVATION` not closed;
- a release built for another API.

Each validates the edge with the release before restarting it, which interrupts the API for a few seconds. It ends by
checking 401 without the password on every path, and the API's exact CORS grant.

### 16.8 After deployment: the persistent test accounts (by hand; no test suite or load against the live service)

1. **The console.** `https://dukan-test.tsxmr.com/admin`: the testers' password, then the administrator's password and
   code. The dashboard counts 0 customers.
2. **A test business.** *New business*, kept as a test, with a fictional Owner, business and store. The setup code is
   shown once: hand it over privately and press *I have handed it over*.
3. **The Owner's password.** On `https://erp-test.tsxmr.com`: *I have a setup code*, the code, a password the Owner
   chooses. Then sign in with the number and that password.
   - The test strip shows on every screen.
   - Before any grant, *Pending approval* shows.
4. **Access.** In the console: *Grant access (no payment)*, with a reason. Then *Add the store*: it opens at no charge
   under the grant. No payment can be recorded.
5. **A day's work in the app.** Open the day; receive five chargers; sell one for cash; four remain.
6. **Isolation.** Make a second test business. Neither Owner sees the other's stores or sales. A customer business
   cannot be created (closed).
7. **Refusals without a session** (from the laptop):
   - `curl -s -o /dev/null -w '%{http_code}' -X POST https://api.tsxmr.com/api/v1/platform/businesses` gives 401;
   - an Owner's bearer token on `GET /api/v1/platform/dashboard` gives 401.
8. **tsxmr.com is unchanged.** Run the `ops/verify-production` workflow (it checks the three Riyade routes and the
   42-URL sitemap). Nothing in this deployment touches Cloudflare Pages.

### 16.9 DNS instructions (for the Chrome extension, in the Cloudflare dashboard, owner-approved)

In Cloudflare → `tsxmr.com` → DNS → Records, add exactly two records. Change nothing else: not `api`, not the apex, not
`www`, not the Pages records.

| Type | Name | IPv4 address | Proxy status | TTL |
| --- | --- | --- | --- | --- |
| A | `erp-test` | the server's IPv4 (the same as `api`) | **DNS only** (grey cloud) | Auto |
| A | `dukan-test` | the server's IPv4 | **DNS only** (grey cloud) | Auto |

- No AAAA record.
- Check from a terminal: `dig +short erp-test.tsxmr.com @1.1.1.1` and `@8.8.8.8` each return exactly the server's
  IPv4. That also proves the record is not proxied.
- Only then run §16.7. Caddy obtains each certificate itself (HTTP-01).

### 16.10 Rollback, in three independent parts

- **The test sites:**
  - `deploy/production/test-sites.sh rollback app|console <release> --confirm api.tsxmr.com` puts back a previous
    release;
  - `off app|console|all` disables the sites;
  - the API and its data are untouched either way.
- **The API code:** `deploy/production/rollback.sh erp-api:644f4f5984873e2b8c1253998985f1e79b4f3fd9 --confirm
  api.tsxmr.com`.
  - Proven here: `644f4f5` runs on the 0102 schema (ready, 0 pending, 0 missing), because 0099–0102 are additive.
  - Turn the test sites off first: the old API has no setup-code route, and test businesses would read as customers'.
- **The database:** only by the owner's decision. Restore the pre-migration backup from §16.3 into a **new** schema
  (`KEEP_DRILL=1 restore-drill.sh …`), point the API at it, and redeploy the old image.
  - Test businesses made after the deployment are lost then.
  - Never drop `phonestore` before the restored copy is verified.
  - **A Git rollback does not roll back the database.**

### 16.11 Risks the owner should weigh

- **Off-site backups.** §12.5 asks for the Storage Box before any external test. The testers here are the owner's own
  and the data is fictional, but backups exist only on the host and the laptop. Buying the Storage Box is the owner's
  decision, and this phase is not authorised to make purchases.
- **The test sites share the production edge.** A Caddy restart from `test-sites.sh` interrupts the API for a few
  seconds.
- **The protection order.** One password protects both sites. Behind it, the console still asks for the
  administrator's password, code and step-up, and every API call is authorised by the server.
- **Timeline notes are English.** The console timeline shows notes the server recorded in English (as every timeline
  note already is) on FR/AR pages.

## 17. Promoter attribution (0103, D221) — the deployment inputs, when it is approved (2026-10-25, NOT EXECUTED)

Nothing here is to be run until the owner approves the merge and deployment. The steps:
1. `deploy/production/setup-secrets.sh` writes `api/referral_key` (48 random bytes, base64url). The preflights refuse a
   missing, short, placeholder or duplicated key, and the API refuses to start without it.
2. Take a fresh verified backup (`docs/22`), then `migrate deploy` (0103, additive: four tables, eight triggers). Check
   readiness, then `verify-mysql-identities.sh` (it now probes the attribution triggers).
3. Rebuild the portal. `/join` is served by the app shell with `noindex`, `no-store` and no referrer.
4. App links only after the Apple Team ID and the Android signing SHA-256 are known: publish the two association
   files, add `associatedDomains` / `intentFilters`, rebuild the app (`docs/105` §10).

Rehearsal: `docs/105` §9 (forward, reverse and restore, identical schemas).

---

## 18. The D224 pilot release (0103 → 0109): the rollback, tested before the deployment (2026-10-29, CLAUDE, local)

The owner's pilot brief (2026-10-29) forbids assuming that `erp-api:644f4f5` or `erp-api:f5da650` remains a valid
application rollback once 0103 → 0109 and real use exist. So both were run against the release's schema before
anything is deployed.

**The test.**
- **The database:** a disposable `erp_inv_e2e` (local MySQL 8.4) migrated to 0109 by the release itself, then
  filled **through the release's own API** with every kind of row that exists only after 0103 → 0109:
  - the D223 fixture business, its 25 inventory journeys and 26 unknown-cost journeys;
  - stock of unknown (NULL) buying cost left unsold: a serial unit and 10 counted pieces; two sale lines of
    unknown cost;
  - a branch return policy in EN/FR/AR, and sales that snapshot it, one with a customer's name;
  - a promoter, its code, and a business registered with it (`business_acquisitions`);
  - an ordinary customer business, paid and activated, with a deferred Owner and a deferred Manager in normal seats.
- **The requests:** the same 107 against each code, on a fresh restore of one dump:
  - every parameterless GET of the old code's controllers (tenant ones as the fixture's Owner, platform ones as a
    disposable administrator with MFA);
  - the post-migration rows read one by one;
  - the everyday writes: open the day, receive with a cost, sell a known-cost unit, sell the unknown-cost unit, sell
    an unknown-cost piece.

| Code | Answers as the release | Different |
| --- | --- | --- |
| the release (`2db5a8d`) | baseline: 107, no 5xx, every write accepted | — |
| `f5da650` (production today) | 103 of 107 | 4 |
| `644f4f5` | 98 of the 102 comparable | the same 4 |

**The four, identical on both old images.** Each is a 400 "Database request error". Behind it, Prisma's "Error
converting field "cost" of expected non-nullable type "Decimal", found incompatible value of "null"":
1. `GET /inventory`, the stock list, for any branch holding such a row;
2. `GET /sales/:id` of a sale with an unknown-cost line;
3. selling the unknown-cost serial unit;
4. selling an unknown-cost counted piece.

Everything else answered as the release does: sign-in, the catalogue, sales and purchases of known cost, and the
console's pages for the deferred and the attributed businesses. Readiness says ready: extra applied migrations are not
"missing".

**The rollback plan, in force for this release:**
1. **Code rollback to `erp-api:f5da650…`** only while the database holds **no** row of unknown cost.
   - `rollback.sh` (backend `ce23e99`) counts the six columns 0107 made nullable before switching the image, and
     refuses otherwise.
   - `644f4f5` is not a target at all: it also predates 0102, so test businesses would read as customers (§16.10).
2. **Once any row of unknown cost exists** — the first time the store receives something without its cost — the way
   back is a **forward fix**: a corrected commit, CI green, a backup, then `deploy.sh`. Never the old image.
3. **Restoring the pre-deployment backup** (into a NEW schema, §16.3) is allowed in two cases only. It may be done
   before real post-deployment data matters. After that, only on the owner's explicit, written authorisation that
   names the loss: every sale, payment, stock movement and account since the backup. **Once the real store
   transacts, it is never done silently.**
4. **Switches that need no rollback at all:**
   - `CUSTOMER_ACTIVATION=closed` stops new customer activations;
   - unsetting `PHONE_VERIFICATION_DEFERRAL` stops new deferrals, and deferred accounts stay deferred, never
     verified;
   - `test-sites.sh off` takes the console offline.
5. The earlier floors still hold: 0092 and 0097 (`docs/79` §C1). **A Git rollback does not roll back the database.**

### 18.1 The deployment record (2026-10-29, CLAUDE, local)

**Before.** The read-only inspection matched the brief:
- API `f5da650`, 0102 (101 migrations), 2 Test companies, 2 users, 0 sales;
- exactly one superadmin, active, with MFA;
- email and WhatsApp disabled, `CUSTOMER_ACTIVATION=closed`;
- `referral_key` missing; disk 28 %, memory 2.1 GB.

**Gates, every one green on the exact commits:**
- backend `ce23e99`: security run 40888573059, with the whole Jest suite, the real-MySQL gates including the 0109
  spec, the dependency audit and the secret scan;
- console `7ddeea79`: CI 40870764729;
- mobile `2bf0a57`: security 40879962980; render-tests 40880200841 (pure 128/128, rendered 408/408, exports, audits);
- visual check 40891575760: 821/821 in WebKit and in Chromium, the brand gate 44/44 in each, the access journey
  21/21, the input matrix 245/245;
- end to end (backend + console + app, WebKit) 40898149271: journeys 41/41, console 103/103, app 57/57.

**Integration**, by fast-forward with no force:
- backend `superadmin-provisioning` `f5da650` → `ce23e99`;
- console `browser-input-setup-code` `2ebe9c5a` → `7ddeea79`;
- app `browser-input-setup-code` `9e0b38b` → `2bf0a57`.

**Steps:**
1. The bundle of `ce23e99`, its sha256 equal on both ends; checked out under `umask 022` (0 unreadable files).
2. `setup-secrets.sh` created `referral_key` only, unprinted.
3. `api.env`: `CUSTOMER_ACTIVATION=open` and `PHONE_VERIFICATION_DEFERRAL=off`. The previous files are
   `api.env.pre-d224` and `api.env.pre-deferral-on`.
4. **The database rollback point: `phonestore-20261029T151837Z`.** It was copied to the laptop (checksum OK) and the
   laptop copy restored with the v2 identity: 121 tables, 59 triggers, every CHECKSUM. PASSED.
5. `deploy.sh`:
   - contract and preflight PASS;
   - its own backup `phonestore-20261029T152338Z`;
   - **0103 → 0109** applied by the migrator, 108 in all;
   - catalogue 76/76, identities and triggers 21/0, both audit chains intact;
   - smoke 15/15 on `ce23e99`, and 16/16 with each of the three origins.
6. Console release `20261029T152528Z` (`7ddeea79`, built on CI run 40883271467) at dukan-test.tsxmr.com. Its previous
   release is `20261025T084934Z`. It answers 401 without the password, and CORS is exact.
7. `PHONE_VERIFICATION_DEFERRAL=on`, applied by `deploy.sh` with `SKIP_BUILD=1` and the same images: smoke 15/15.
   - `deployments.log` now names `ce23e99` as the "previous" image, because the same image was redeployed.
   - **The code rollback target stays `f5da650`, under §18's rule.**

**After:**
- the Test data, the users and the one superadmin are preserved; the backfill gave both users `required`, with no
  verified timestamp invented;
- no row of unknown cost yet, so a code rollback is still allowed;
- public registration 503 `registration_unavailable` with nothing saved; the deferral field refused on public routes
  (400); every platform route 401 without a session;
- TLS valid on api, erp-test and dukan-test; Caddy renews it.

**tsxmr.com** is unchanged at `5aa8322`:
- `/account`, `/admin`, `/subscription` and `/join` are 404; the three Riyade pages are 200; the sitemap has 42 URLs;
- verify-production 40901534888: 23/25, the browser suite 172/172, verify-not-found green;
- the two failures are one file, `/sitemap.xml`, whose `<lastmod>` is the build day (2026-10-29) against the live
  2026-10-20. That is the documented limitation of a re-run on a later day; the other 82 files are byte-identical.

**Not done here, by the brief:**
- the business and its staff: the owner creates them in the portal;
- the checks that need the superadmin's own session: the deferral option shown, and refused when off;
- the app at erp-test is still release `20261025T084923Z` (`9e0b38b`).
