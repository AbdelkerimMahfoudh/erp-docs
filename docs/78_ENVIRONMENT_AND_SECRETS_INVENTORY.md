# Environment variables and secrets — inventory (names and purposes only)

Source of truth: `erp-backend/src/common/config/env.validation.ts` (validated at boot),
`erp-backend/src/common/config/production-guard.ts` (refuses to start in production on an unsafe value),
the website's `import.meta.env`, and the app's `EXPO_PUBLIC_*`. Read at backend `d2ad456` (configuration unchanged through `1cd3cfb`), mobile `cfdb756` (unchanged through `1167f52`), website
`35ca6d1`. **No value appears here.**

**Secret** means it must come from the host's secret store, never from a committed file, and must be different in every
environment. **Prod** means the production guard checks it when `NODE_ENV=production`.

## Backend — runtime (API process)

| Name | Secret | Purpose | Production requirement |
| --- | --- | --- | --- |
| `NODE_ENV` | | `production` turns on the production guard, secure cookies and HSTS | `production` |
| `APP_ENV` | | `staging` marks a staging host (no HSTS, staging banner); shown by `/health/version` | `production` or empty; `staging` on staging |
| `PORT` | | Listening port (default 3000) | behind the edge |
| `API_BIND` | | Bind address, `127.0.0.1` to keep the port off the network | Prod: with `API_INGRESS`, how the port is shielded |
| `API_INGRESS` | | Declares how the API is exposed (edge/proxy mode) | Prod: required |
| `REFERRAL_KEY` | **yes** | Signs promoter QR addresses and user invitations (0103, `docs/105` §4); rotating it voids every printed card and shared invitation | required, ≥32 characters, distinct from every other key (`REFERRAL_KEY_FILE`) |
| `APP_DATABASE_URL` | **yes** | Runtime connection as `phonestore_app` (DML only) | required; https-only edge; add `connection_limit` (10–20) |
| `JWT_ACCESS_SECRET` | **yes** | Signs access tokens (≥ 32 chars) | Prod: refused if it looks like a placeholder |
| `JWT_ACCESS_TTL` | | Access-token lifetime (default 15m) | |
| `JWT_REFRESH_TTL_DAYS` | | Refresh-token lifetime (default 30) | |
| `COOKIE_SECURE` | | Secure flag on the administrator and portal cookies | Prod: refused if false |
| `CORS_ORIGINS` | | Browser origins allowed (the website) | Prod: https only; no localhost |
| `PUBLIC_SITE_ORIGIN` | | The website's origin, used in links the server sends (trial setup) | Prod: https |
| `SWAGGER_ENABLED` | | API documentation at `/docs` — **defaults to true** | Prod: **must be set false** (refused if true) |
| `THROTTLE_TTL_SECONDS`, `THROTTLE_LIMIT` | | Global rate limit | defaults |
| `AUTH_THROTTLE_LIMIT` | | Sign-in rate limit per client (default 10/min) | default |
| `ACCOUNT_THROTTLE_LIMIT` | | Code-issuing routes per client (default 5/min) | default |
| `LOG_LEVEL` | | pino level | `info` |
| `OTP_PEPPER` | **yes** | Keys contact-verification codes (HMAC, ≥ 32 chars) | required when a channel is on |
| `OTP_TTL_SECONDS`, `OTP_MAX_ATTEMPTS`, `OTP_RESEND_COOLDOWN_SECONDS`, `OTP_MAX_SENDS_PER_WINDOW`, `OTP_SEND_WINDOW_SECONDS`, `OTP_MAX_SENDS_PER_DAY` | | Code lifetime, attempts and send windows | defaults |
| `PLATFORM_MFA_KEY` | **yes** | Seals the Super Admins' TOTP secrets (per environment; custody is an owner decision) | Prod: refused if empty |
| `PLATFORM_ADMIN_KEY` | **yes** | Provisioning endpoint key (`POST platform/provisioning`), ≥ 16 chars | Prod: checked by the guard |
| `SEED_DEMO` | | Seeds the demo shop | Prod: must be off |
| `WHATSAPP_CHANNEL` | | `disabled` / `development-log` / `cloud-api` | Prod: `development-log` refused; **postponed — keep `disabled`** |
| `WHATSAPP_API_BASE_URL`, `WHATSAPP_API_VERSION`, `WHATSAPP_SEND_TIMEOUT_MS` | | Meta Graph endpoint and timeout | https |
| `WHATSAPP_PHONE_NUMBER_ID` | | Sending number id | **none until the provider exists** |
| `WHATSAPP_ACCESS_TOKEN` | **yes** | System-user token | **none until the provider exists** |
| `WHATSAPP_APP_SECRET` | **yes** | Verifies the delivery webhook's signature | **none until the provider exists** |
| `WHATSAPP_WEBHOOK_VERIFY_TOKEN` | **yes** | Webhook subscription handshake | **none until the provider exists** |
| `WHATSAPP_TEMPLATE_*` (AUTH_OTP, ACCOUNT_DELETION, ACCOUNT_DELETED, CLOSING_REOPENED, CLOSING_SALE, CLOSING_RECLOSED, DELIVERY_CHECK, TRIAL_SETUP), `WHATSAPP_TEMPLATE_LANGUAGE_EN/FR/AR` | | Approved template names and languages | **none until approved** |
| `EMAIL_CHANNEL` | | `disabled` / `development-log` / `resend` | Prod: development-log refused |
| `EMAIL_FROM`, `EMAIL_REPLY_TO` | | Sender addresses (a verified sending domain) | owner decision |
| `RESEND_API_KEY` | **yes** | Email provider key | owner decision (provider not chosen) |
| `RESEND_API_BASE_URL`, `EMAIL_SEND_TIMEOUT_MS` | | Provider endpoint and timeout | https |
| `UPLOAD_MAX_BYTES`, `UPLOAD_DIR` | | Receipt photo storage (stored and served — see docs/48 control 16) | private directory, backed up |
| `APP_COMMIT`, `APP_BUILT_AT` | | Shown by `/health/version` | set by the deploy |

## Backend — operator-only (CLI, migrations, scripts; never the API process)

| Name | Secret | Purpose |
| --- | --- | --- |
| `DATABASE_URL` | **yes** | Prisma CLI: `migrate deploy` as `phonestore_migrator`; read-only scripts as `phonestore_backup` |
| `PLATFORM_ADMIN_PASSWORD` | **yes** | `prisma/create-platform-admin.ts` — first Super Admin (one-off) |
| `OWNER_SEED_PASSWORD`, `FIXTURE_OWNER_PASSWORD`, `QA_PASSWORD`, `QA_DB`, `QA_API`, `QA_ADMIN_RECOVERY_CODE` | **yes** (passwords) | Development, staging and QA fixtures only — never production |
| `BACKUP_PASSPHRASE_FILE`, `MYSQL_PWD_FILE`, `MYSQL_USER`, `DB`, `OUT_DIR`, `BACKUP`, `SOURCE_DB`, `KEEP_DRILL`, `MYSQL_SOCKET`/`MYSQL_HOST`/`MYSQL_PORT` | files are secret | `deploy/backup-encrypted.sh`, `deploy/restore-drill.sh` — credentials only as mode-600 files |
| `APP_PW`, `BACKUP_PW`, `MIGRATOR_PW` | **yes** | `deploy/verify-mysql-identities.sh` (on a copy) |
| `ADDON_ROOT_URL`, `ADDON_APP_URL`, `CI_DATABASE_GATES`, `ROOT_PW` | disposable | CI database gates and the env-gated MySQL spec — disposable servers only |
| `MYSQL_BIN_DIR` | | Windows (WAMP) path to the MySQL client |

The four database identities' passwords (`migrator`, `app`, `backup`, `admin`) are made with `openssl rand -hex 24`. They
reach MySQL on standard input (`deploy/mysql-identities.sql`). The backup passphrase is a separate secret held off the
database host: without it the encrypted backups are unreadable.

## Website (`erp-control-web`, Vite)

| Name | Secret | Purpose |
| --- | --- | --- |
| `VITE_API_BASE` | | The API's https origin, compiled into the static build. Not a secret: everything `VITE_*` is public. |

## Mobile app (`erp-mobile`, Expo)

| Name | Secret | Purpose | Production requirement |
| --- | --- | --- | --- |
| `EXPO_PUBLIC_API_ORIGIN` | | The API's origin, compiled into the bundle | **https** (`scripts/verify-release-config.js` refuses http for production/preview). Not set in `eas.json`: it must be an EAS environment variable of the `production` profile |
| `EXPO_PUBLIC_SCAN_GEOMETRY_OVERLAY` | | Draws the scanner's geometry for testing — set **only** in the `preview` profile | never in production |

Anything `EXPO_PUBLIC_*` is public and ends up in the bundle; the release script refuses a server secret's name there.
The EAS credentials (Apple distribution certificate, provisioning profile, App Store Connect API key) live in EAS and
Apple. **None exists yet**: the owner links the `dukan-erp` EAS project and the Apple account (`docs/44`).

## Committed files

Only `.env.example` files are committed (placeholders). `scripts/scan-secrets.js` (backend, mobile) and gitleaks scan
every blob of every ref on each push. The one real credential ever committed — G2A-CP4.5's development session tokens,
revoked and proven dead — is named by blob in `erp-mobile/.secret-scan-revoked`.

`VITE_APP_WEB_ORIGIN` (website, optional, 0103): where the portal's `/join` continues to the app's browser registration;
blank, `/join` asks for the phone app.
