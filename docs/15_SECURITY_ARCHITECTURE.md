# 15 — Security Architecture

> Scope: the backend security model for the Phone Store ERP (NestJS + Prisma + **MySQL 8**). Complements [`06_TECHNICAL_ARCHITECTURE.md`](06_TECHNICAL_ARCHITECTURE.md) and [`10_DATABASE_SCHEMA.md`](10_DATABASE_SCHEMA.md). Reflects Sprint 1 decisions: JWT + rotating refresh tokens, Argon2id, `auth_sessions` persistence, and **fail-closed app-layer tenant isolation** (MySQL has no RLS).

---

## 1. Principles
- **Server is the source of truth.** All authz, tenant scoping, and money rules are enforced server-side; the client is never trusted.
- **Fail closed.** Missing tenant context, missing permission, or missing/invalid token → **deny** (throw), never a silent or unscoped fallback.
- **Least privilege.** The runtime DB user (`phonestore_app`) has DML only and is blocked from mutating `audit_logs`. Roles grant the minimum permissions needed.
- **Defense in depth.** App-layer tenant filter **and** DB-user restrictions **and** append-only audit triggers.
- **No secrets in the client or logs.** Tokens, passwords, and keys are redacted in logs and never returned except the tokens the caller must receive.

---

## 2. Authentication flow
```
Client → POST /auth/login { login, password, device? }
  1. Look up user by (company scope resolved from login policy) + login.  [system/unscoped client]
  2. Verify password with Argon2id (constant-time). Generic error on failure.
  3. Check user.is_active; reject if disabled.
  4. Issue access token (JWT, ~15m) + refresh token (~30d, rotating).
  5. Persist an auth_sessions row (hashed refresh token + device metadata).
  6. Return { accessToken, refreshToken, expiresIn, user summary }.
```
- Login is **rate-limited** (stricter than global) to blunt brute force.
- Failure messages are **generic** ("invalid credentials") — no user-enumeration.
- Login runs on the **unscoped system client** (tenant context does not yet exist).

## 3. Authorization flow
Every protected request:
```
JwtAuthGuard        → validate access token, load user → RequestContext (ALS)
CompanyContextGuard → set companyId in ALS (from token) — REQUIRED
BranchContextGuard  → resolve X-Branch-Id, verify user_branches membership → ALS
PermissionsGuard    → @RequirePermissions('x') vs the user's effective permissions
Handler             → uses the tenant-scoped Prisma client (auto company_id filter)
```
- **Permissions are resolved per branch** from `user_branches → role → role_permissions`.
- **Cost/profit** fields are stripped in the serialization layer for roles lacking `cost.view`.
- Any guard failure → `401`/`403` with a clean `problem+json` body.

## 4. JWT lifecycle
- **Access token**: JWT, HS256 (secret `JWT_ACCESS_SECRET`), TTL ~15 min. Payload: `{ sub: userId, companyId, type: 'access', iat, exp, jti }` (ids as strings).
- **Verification**: signature + expiry on every request (`JwtAuthGuard`); no DB hit on the hot path (user existence/active re-checked on refresh).
- **Rotation of signing keys**: secrets come from env/secrets-manager; support two active secrets during rotation windows.
- **Revocation**: access tokens are short-lived and *not* individually revocable — revocation is achieved by refresh-token invalidation + short TTL.

## 5. Refresh-token lifecycle
- **Refresh token**: opaque, high-entropy random (not a JWT), TTL ~30 days, delivered once at login.
- **At rest**: only the **Argon2id hash** is stored (`auth_sessions.refresh_token_hash`); the raw token is never persisted.
- **Rotation (one-time-use):** `POST /auth/refresh` validates the presented token against the session hash, then **issues a new refresh token and invalidates the old** (`revoked_at` set / row replaced). A replayed old token → **reuse detected** → the session (and optionally all sessions for that user) is revoked.
- **Logout**: `POST /auth/logout` revokes the current session; `logout-all` revokes every session for the user.
- **Expiry & cleanup**: expired/revoked sessions are ignored on use and periodically pruned by a job.

## 6. Password policy
- **Hashing**: Argon2id (memory-hard) with sane cost params; per-hash salt handled by the library. No plaintext, ever.
- **Strength**: minimum length (≥ 8, configurable), server-side validation; reject known-weak values. (Business may tighten later.)
- **Change/reset**: password change requires the current password; a reset invalidates **all** sessions.
- **PIN** (optional device unlock): `pin_hash` also Argon2id; the PIN is a device-convenience factor, not a substitute for the password.
- **Transport**: passwords only over TLS; a dedicated credential tool/manager is preferred over manual entry where available.

## 7. Session management
- Backed by the **`auth_sessions`** table (per device):
  `id, company_id, user_id, device_id?, device_name?, platform?, app_version?, user_agent?, ip?, refresh_token_hash, last_used_at?, expires_at, revoked_at?, created_at`.
- One row per active login/device; `last_used_at` updated on each refresh.
- Users (and admins) can **list active sessions and revoke** any of them.
- Sessions are tenant-scoped (`company_id`) like every other table.

## 8. Device management
- A device is identified by a client-supplied `device_id` plus descriptive `device_name`, `platform` (android/ios/web), and `app_version` for support/telemetry.
- Enables: "signed-in devices" views, targeted revocation (lost phone), and per-device push routing (FCM, later).
- Offline sync devices (`sync_devices`) are a **separate** concern from auth sessions.

## 9. Tenant isolation (app-layer, fail-closed)
- **No MySQL RLS** → isolation is enforced in the backend on **every** query.
- **Mechanism**: `AsyncLocalStorage` (via `nestjs-cls`) holds the request's `companyId`; a **Prisma Client Extension** injects `company_id` into `where` (reads) and `data` (writes) for all **tenant models**.
- **Fail-closed rule (approved):** if a tenant-scoped model is queried and **no `companyId` is in context, the extension throws** — a tenant query is **never** executed unscoped or silently.
- **Global models** (`permissions`, `tac_catalog`) and explicit **system operations** (login, migrations, cross-tenant admin jobs) use a separate **unscoped client** by deliberate choice, never by accident.
- **Branch scoping** layers on top for branch-owned data, validated against `user_branches`.
- Covered by unit tests asserting cross-tenant reads return nothing and context-less tenant queries throw.

## 10. Permission model
- **RBAC**: `Role` (5: owner, administrator, branch_manager, sales_employee, warehouse_employee) → `role_permissions` → `Permission` (17 keys). Roles are assigned **per branch** via `user_branches`.
- **Enforcement**: `@RequirePermissions('sale.create', …)` + `PermissionsGuard`; a user's effective permission set is the union for their role at the active branch.
- **Money visibility**: `cost.view` gates cost/profit exposure; **Administrator ≠ Owner** — technical admin does not imply money visibility.
- **Elevation & overrides** (e.g. discount over limit) require a higher role and are **audited**.

## 11. Audit strategy
- **Append-only `audit_logs`** capturing create/update/delete/status-change/override/login/logout with `who / when / before→after / reason / ip`.
- **Immutability**: enforced by `BEFORE UPDATE`/`BEFORE DELETE` triggers that block the **application DB user** (`phonestore_app`) from modifying rows; an admin/DBA can still archive.
- **What's audited**: authentication events, permission overrides, money-affecting mutations, and administrative changes (users, roles, settings).
- **Retention (R5)**: ~2 years hot, then archived (never deleted) for compliance/investigation.
- **Integrity**: audit writes happen in the same transaction as the audited change where feasible.

## 12. Encryption
- **In transit**: TLS everywhere (client↔API, API↔DB, API↔external services). No plaintext endpoints.
- **At rest**: DB and object storage encrypted (RDS/Aurora + S3 via AWS KMS, or InnoDB tablespace encryption on self-managed MySQL). Device holds tokens in secure storage (Keychain/Keystore).
- **Secrets**: JWT secrets, DB creds, WhatsApp/FCM keys in a secrets manager (AWS Secrets Manager) / env — never in the client bundle, repo, or logs.
- **Hashing vs encryption**: passwords/refresh tokens are **hashed** (Argon2id), not encrypted (one-way).

## 13. Backup strategy
- **Database**: automated **daily backups + point-in-time recovery (PITR)** (RDS/Aurora MySQL binlog-based); backups encrypted and stored off-site/cross-region.
- **Object storage**: S3 versioning + lifecycle; critical buckets replicated.
- **Testing**: periodic **restore drills** to validate backups are usable (a backup is only real if a restore has been proven).
- **Config/secrets**: infrastructure-as-code + secrets manager versioning so environments are reproducible.

## 14. Disaster recovery overview
- **Objectives (targets to confirm)**: RPO ≤ 15 min (PITR), RTO ≤ a few hours for a full region restore.
- **Failure modes & response**:
  - *DB instance failure* → restore from automated backup / promote replica.
  - *Region outage* → restore from cross-region backups / (future) multi-AZ or cross-region replica.
  - *Data corruption / bad deploy* → PITR to just before the event; migrations are forward-only + reversible-by-compensation.
  - *Credential compromise* → rotate secrets, revoke all sessions (`auth_sessions`), force re-auth.
- **Runbooks**: documented restore + secret-rotation + session-revocation procedures; contact/escalation path.
- **Offline resilience**: the mobile app keeps selling offline (Drift) and reconciles on reconnect, buffering business continuity during backend incidents.

---


## 15. The platform boundary (2026-09-22)

- **Two identity realms, structurally apart.** Platform administrators live in
  `platform_admins` (no `company_id`) with their own sessions
  (`platform_admin_sessions`, HttpOnly cookie; a bearer header only outside
  production). `PlatformAdminGuard` reads no tenant token, no `X-Company-Id`, no
  `X-Branch-Id`: an Owner's, Manager's or Employee's JWT is looked up as a
  platform session and matches nothing. No store role — `administrator`
  included — grants anything on a platform route, and no platform route reads the
  tenant context.
- **What the platform may see.** Business identity, subscription state and dates,
  Owner contact and verification, branch and user counts, subscription events,
  recorded payments, the audit trail. Never sales, units, IMEIs, costs, margins
  or expenses — the queries cannot select them. There is no impersonation.
- **Every platform mutation**: the administrator's password re-asked, a
  `version` for concurrency (409 `subscription_changed` for the loser), a reason
  where access is taken away (reject, suspend, cancel, shorten a period), and an
  append-only audit row with actor, action, target, reason, before/after and IP,
  redacted of anything credential-shaped.
- **Owner invitations** (`owner_invitations`): SHA-256 hash only, 72 hours,
  single-use, claimed atomically, revoked as a set when reissued; accepting sets a
  password and cuts earlier sessions, and issues no session of its own. Delivery
  is manual; nothing pretends to send.
- **The tenant lock is the server's.** `stateOf` reads the subscription row and
  the injected server clock — never a request, a header or the device — so an old
  build, a changed phone date or a different branch header cannot open a closed
  shop. Pending, suspended, cancelled and rejected shops keep only `entitlement`,
  `auth/me`, `auth/logout`, `auth/refresh`, `health`, `platform/my-subscription`
  and `platform/payment-instructions`.
- **No default administrator credential** anywhere; bootstrap is
  `prisma/create-platform-admin.ts` with `PLATFORM_ADMIN_PASSWORD` from the
  environment. MFA is still outstanding production work, and nothing fakes it.
- Pinned by `platform-boundary.spec.ts`, `subscription-lifecycle.spec.ts`,
  `owner-invitation.spec.ts`, `lifecycle-states.spec.ts`, and proved live in the
  42-step run recorded in `docs/37` Phase 5.

## Quick reference
| Concern | Mechanism |
|---|---|
| Password/refresh hashing | Argon2id |
| Access token | JWT HS256, ~15 min |
| Refresh token | opaque, ~30 d, rotating, hashed, per-device (`auth_sessions`) |
| Tenant isolation | ALS + Prisma extension, **fail-closed** (throws without context) |
| Authorization | RBAC, 17 permissions, per-branch, `PermissionsGuard` |
| Audit | append-only `audit_logs` + triggers |
| Transport / rest | TLS / KMS |
| Rate limiting | global + strict on auth endpoints |
