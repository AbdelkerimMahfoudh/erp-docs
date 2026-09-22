# 42 — Environment matrix (redacted)

**No value appears in this file.** Names, ownership, validation and consequence
only. A variable's value lives in the environment it belongs to and nowhere
else — not here, not in a commit, not in a scratch file inside a repository.

Four environments: **local** (a developer's machine plus a phone on the same
Wi-Fi), **test** (the automated suites), **staging**, **production**.

Legend: **S** = secret · **P** = public/non-secret · **R** = required ·
**O** = optional.

---

## Backend — `erp-backend`

### Database

| Variable | S/P | local | test | staging | prod | Validated | Notes |
|---|---|---|---|---|---|---|---|
| `DATABASE_URL` | **S** | R | R | R | R | ❌ Prisma CLI only | The **migrator** account. Not read by the running app |
| `SHADOW_DATABASE_URL` | **S** | O | O | ❌ | ❌ | ❌ | Prisma dev only. Must not exist in production |
| `APP_DATABASE_URL` | **S** | R | R | R | R | ✅ Joi `required` | The least-privilege `phonestore_app` runtime account. **Flagged by the production guard if it names `localhost`** |

**Rotation.** Changing either password is a restart, not a migration. The two
accounts are deliberately different: the app cannot run DDL, so a compromised
app credential cannot drop a table.

### Identity and session

| Variable | S/P | local | test | staging | prod | Validated | Notes |
|---|---|---|---|---|---|---|---|
| `JWT_ACCESS_SECRET` | **S** | R | R | R | R | ✅ Joi `min(32)` | **Rotating invalidates every access token** — every user is signed out. The production guard rejects values that read like an example placeholder |
| `JWT_ACCESS_TTL` | P | O | O | O | O | ✅ default `15m` | |
| `JWT_REFRESH_TTL_DAYS` | P | O | O | O | O | ✅ default `30` | Refresh tokens **rotate on use**; both halves are persisted or the next refresh fails |
| `COOKIE_SECURE` | P | O | O | O | **R** | ⚠️ **not in Joi** — read from `process.env` | **`false` in production puts session cookies in clear text.** Now refused at startup. Staging over plain-HTTP LAN needs it `false` *and* `NODE_ENV != production` |
| `OTP_PEPPER` | **S** | O | O | R | R | ✅ Joi `min(32)`, optional | Unset degrades to **no OTP**, never to a guessable hash. **Rotating invalidates every outstanding challenge** |
| `PLATFORM_ADMIN_KEY` | **S** | O | O | R | R | ⚠️ **not in Joi** | Cross-tenant provisioning. Fail-closed when unset or under 16 chars. One static bearer secret — risk **R5** |

### Network and exposure

| Variable | S/P | local | test | staging | prod | Validated | Notes |
|---|---|---|---|---|---|---|---|
| `NODE_ENV` | P | O | R | R | **R** | ✅ enum, default `development` | Everything below keys off it |
| `APP_ENV` | P | O | O | **R** | O | ⚠️ **not in Joi** | `staging` drops HSTS so a test host cannot pin a parent domain to HTTPS for six months |
| `PORT` | P | O | O | O | O | ✅ default `3000` | The project uses `3010` locally |
| `API_BIND` | P | O | O | R | **R** | ⚠️ **not in Joi** | Defaults to every interface. **Production must be `127.0.0.1` behind the edge**, or the administration endpoints answer beside the proxy. Now refused at startup |
| `CORS_ORIGINS` | P | R | O | R | R | ✅ default `''` | Empty is **fail-closed** (`origin: false`). A production list naming `localhost`, `127.0.0.1`, `10.`, `192.168.` or `172.16–31.` is now refused |
| `SWAGGER_ENABLED` | P | O | O | O | **R** | ✅ default **`true`** | The default publishes the API surface. **`true` in production is now refused** |

### Rate limiting and logging

| Variable | S/P | local | test | staging | prod | Validated | Notes |
|---|---|---|---|---|---|---|---|
| `THROTTLE_TTL_SECONDS` | P | O | O | O | O | ✅ default `60` | Global |
| `THROTTLE_LIMIT` | P | O | O | O | O | ✅ default `120` | Global |
| `AUTH_THROTTLE_LIMIT` | P | O | O | O | R | ✅ default `10` | **Was dead until `6bb0d53`** — validated, exposed, consumed by nothing |
| `LOG_LEVEL` | P | O | O | O | R | ✅ enum, default `info` | `debug` in production is a privacy risk, not just noise |

### Messaging and OTP

| Variable | S/P | local | test | staging | prod | Validated | Notes |
|---|---|---|---|---|---|---|---|
| `WHATSAPP_CHANNEL` | P | O | O | R | **R** | ✅ enum + **module refuses `development-log` in production** | Only `disabled` and `development-log` exist. **There is no real provider** — risk R6 |
| `WHATSAPP_TEMPLATE_AUTH_OTP` | P | O | O | O | R | ✅ default `''` | Provider template id. Empty until a provider exists |
| `OTP_TTL_SECONDS` · `OTP_MAX_ATTEMPTS` · `OTP_RESEND_COOLDOWN_SECONDS` · `OTP_MAX_SENDS_PER_WINDOW` · `OTP_SEND_WINDOW_SECONDS` · `OTP_MAX_SENDS_PER_DAY` | P | O | O | O | O | ✅ bounded | Abuse controls. Every one has a validated min and max |

### Seeding and uploads

| Variable | S/P | local | test | staging | prod | Validated | Notes |
|---|---|---|---|---|---|---|---|
| `OWNER_SEED_PASSWORD` | **S** | R to seed | R to seed | R to seed | ❌ | ❌ seed script only | The seed **throws** without it rather than inventing one |
| `SEED_DEMO` | P | O | O | **R** | **R** | ❌ seed script only | **Opt-out**: demo data is written unless this is exactly `false`. Risk **R7** |
| `UPLOAD_MAX_BYTES` | P | O | O | O | O | ✅ default 10 MiB | |
| `UPLOAD_DIR` | P | O | O | R | R | ✅ default `./uploads` | Local disk today. A container without a mounted volume loses uploads on restart |
| `APP_COMMIT` · `APP_BUILT_AT` | P | O | O | R | R | ❌ | Surfaced by `/api/health/version`. Absent, a deployed build cannot say what it is |

---

## Mobile — `erp-mobile`

**Everything here is baked into the bundle at build time and is therefore
public.** A secret in an `EXPO_PUBLIC_*` variable is a published secret. None of
these is one, and none may become one.

| Variable | local | staging | prod | Notes |
|---|---|---|---|---|
| `EXPO_PUBLIC_API_ORIGIN` | R | R | R | **Changes with the network.** `.env.local` is gitignored, so every network change is a hand edit *and a Metro restart* — the value is compiled in |
| `EXPO_PUBLIC_API_HOST` | O | R | R | Used by the staging example |
| `EXPO_PUBLIC_APP_ENV` | O | R | R | |
| ~~`EXPO_PUBLIC_PORTAL_URL`~~ | — | — | — | Removed 2026-09-22: the app no longer opens the website |
| ~~`EXPO_PUBLIC_SIGNUP_URL`~~ | — | — | — | Removed 2026-09-22: registration happens in the app |
| `EXPO_PUBLIC_SCAN_GEOMETRY_OVERLAY` | O | O | ❌ | Debug overlay. Read at build time, so a production build has the branch **removed**, not merely skipped |
| `EXPO_PUBLIC_USE_RN_FETCH` | O | O | ❌ | Diagnostic transport switch |

---

## What is tracked, and what must never be

| Path | State |
|---|---|
| `backend/.env.example`, `backend/.env.staging.example` | **Tracked**, placeholders only, sanitised in `71637b2` |
| `mobile/.env.staging.example` | **Tracked**, placeholders only |
| `backend/.env`, `backend/.env.staging`, `mobile/.env.local` | **Ignored** — verified with `git check-ignore` |
| `backend/dist/`, `mobile/dist/`, `mobile/expo-env.d.ts` | **Ignored** — generated |
| `*.sql.gz`, `*.dump`, `backups/` | **Ignored** |
| Anything holding a token, session or extract | **Must not exist inside a repository at all** — the `CLAUDE.md` rule, from the incident where `git add -A` committed a token file |

Verified this session: **no `.env`, dump, key or credential file is tracked in
any of the four repositories.** The only `.sql` files under version control are
Prisma migrations, which is correct.

---

## The production decisions still missing

These are values nobody has chosen yet. Each blocks the production checklist in
[`docs/44`](44_STAGING_AND_LAUNCH_CHECKLISTS.md).

| Variable | Decision needed |
|---|---|
| `APP_DATABASE_URL`, `DATABASE_URL` | Where the production database lives, and who holds each credential |
| `JWT_ACCESS_SECRET`, `OTP_PEPPER`, `PLATFORM_ADMIN_KEY` | Generated, stored where, rotated how often, by whom |
| `CORS_ORIGINS`, `EXPO_PUBLIC_*` URLs | **The domain** — every one of these embeds it |
| `WHATSAPP_CHANNEL`, `WHATSAPP_TEMPLATE_AUTH_OTP` | A real provider, or registration cannot issue a session |
| `UPLOAD_DIR` | Local volume or object storage |
| `LOG_LEVEL`, log destination | Where logs go and how long they are kept |
