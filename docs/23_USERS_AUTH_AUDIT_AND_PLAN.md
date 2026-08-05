# 23 — Users, Invitations & Device Security: F0 Audit and F1 Plan

> **Status:** F0 is a **read-only audit**. No schema, API or screen was created
> or modified while producing it.
> **Audited at:** backend 28 suites / 236 tests green · migration `0019` applied.
> **Purpose:** establish exactly what exists before anyone designs the Users
> system, so F1 extends what is there instead of rebuilding it.

---

## 1. What was inspected

`src/auth/` (controller, service, tokens, sessions, JWT strategy, guards, DTOs) ·
`src/users/` · `src/rbac/` · `src/common/security/hashing.service.ts` ·
`src/common/config/env.validation.ts` · `prisma/schema.prisma` (User, Role,
Permission, RolePermission, UserBranch, AuthSession, SyncDevice, Company,
Branch, CompanySettings) · `prisma/create-user.ts` · `prisma/seed*` ·
`mobile/app/(auth)/login.tsx` · `mobile/hooks/useAuth.tsx` ·
`mobile/lib/{storage,permissions,api-client}.ts` · both `package.json` files ·
`docs/15_SECURITY_ARCHITECTURE.md`.

---

## 2. Findings by area

### 2.1 Models

| Model | State |
|---|---|
| `User` | `id, companyId, name, login, passwordHash, pinHash?, isActive, lastLoginAt?, createdAt, updatedAt, deletedAt?`. **No phone. No email. No WhatsApp. No verification state.** Unique on `(companyId, login)` |
| `Role` | `(companyId, key)` unique; `key` is the `RoleKey` enum (owner, store_manager, store_employee + 4 legacy) |
| `Permission` | Global, 17 rows, keyed by string |
| `RolePermission` | `@@id([roleId, permissionId])` — **role-level only. There is no per-user grant anywhere in the schema** |
| `UserBranch` | `@@unique([userId, branchId])` with a `roleId` per row — **multi-branch membership already works, and the role is per branch** |
| `AuthSession` | Per-device row: `deviceId?, deviceName?, platform?, appVersion?, userAgent?, ip?, refreshTokenHash, lastUsedAt?, expiresAt, revokedAt?` |
| `SyncDevice` | `@@unique([userId, deviceId])` — offline-sync bookkeeping, **unused**, and a separate concern from auth |
| `CompanySettings.autoLockMaxSeconds` | Exists (0019). The company maximum is already stored and validated |

`phone` exists on `Branch`, `Supplier` and `Customer` — **never on `User`.**

### 2.2 Authentication

- `POST /auth/login` → Argon2id verify, create session, return access + refresh.
  Failure is a single generic `Invalid credentials`, so accounts cannot be
  enumerated. Inactive users are rejected by the same path.
- `POST /auth/refresh` → **rotating** refresh tokens. The token is opaque,
  shaped `<sessionId>.<secret>`; only an Argon2 hash of the secret is stored.
  **A secret mismatch on an otherwise-valid session revokes that session** —
  reuse detection is already implemented.
- `POST /auth/logout` (one session) and `POST /auth/logout-all`.
- `GET /auth/me`, `GET /auth/branches`, `GET /auth/permissions`.
- **Access token payload is `{sub, companyId, type}` — no roles, no
  permissions.** Authorization resolves from the database on every request, so
  a role change takes effect on the next request with no token revocation.

### 2.3 Sessions, devices and revocation

- One `auth_sessions` row per login; `revokedAt` supports targeted revocation.
- `deviceId` is **client-supplied, optional, and never verified or enforced** —
  nothing binds a session to a device, and nothing detects a *new* device.
- **There is no endpoint to list or revoke another user's devices.** `logout-all`
  only acts on the caller. An Owner cannot revoke an employee's device today.
- The mobile client **never sends `device`** on login: `signIn` posts
  `{login, password}` only, so every session row has null device columns.

### 2.4 Mobile

- One screen: `app/(auth)/login.tsx` — login + password, pre-filled `owner`,
  hard-coded English, built before the design system (uses `lib/theme`, not
  `lib/design`).
- Tokens are held in `expo-secure-store`, **with a `localStorage` fallback on
  web** (`lib/storage.ts`).
- Permissions are resolved per branch and refreshed on app resume.
- **No passcode screen, no biometric prompt, no auto-lock, no OTP screen, no
  onboarding, no invitation flow, no device list.**
- `expo-local-authentication` is **not installed**. No QR *generator* is
  installed either — `expo-camera` can only read.

### 2.5 Password handling and recovery

- Argon2id everywhere (`HashingService`), used for passwords, PINs and refresh
  secrets. Verification never throws.
- `User.pinHash` exists and **nothing reads or writes it** outside
  `UsersService.createUser`. `docs/15` describes it as a device-convenience
  factor.
- **There is no account recovery of any kind** — no reset token, no recovery
  contact, no email. A forgotten password today is fixed by running
  `prisma/create-user.ts`, a developer utility on the server.

### 2.6 Rate limiting

- Global throttle 120 req / 60 s; auth routes 10 req / 60 s, applied per IP by
  `@nestjs/throttler` in memory.
- **Per-account lockout does not exist.** Ten attempts per minute per IP does
  not stop a slow distributed guess against one login, and the in-memory store
  resets on restart and is not shared across instances.
- **No cooldown, no failed-attempt counter, no OTP escalation.**

### 2.7 Auditing

`AuditAction` already includes `login` and `logout`, and **nothing ever writes
them.** No authentication event is audited: not a successful login, not a
failure, not a session revocation, not a password change.

### 2.8 Subscription / seats

Nothing exists. No plan, entitlement, seat or subscription model, column or
enum anywhere in the schema.

---

## 3. Reconciliation against the approved rules

| Approved rule | Status |
|---|---|
| Owner creates Store Manager / Store Employee invitations | ❌ Nothing exists. `create-user.ts` is a dev CLI, not an invitation |
| No fake email accounts | ✅ By construction — `login` is a username and there is no email field to abuse |
| Employee verifies WhatsApp/phone; email optional recovery | ❌ No phone, no email, no verification state on `User` |
| Technician postponed | ✅ Not in `RoleKey`, correctly absent |
| Invitation by Employee ID / one-time code / QR | ❌ None. Camera can read a QR; nothing can generate one |
| Employee creates a private app passcode | 🟡 `pinHash` column exists and is unused. **The column is the wrong home for this** — see §4.3 |
| Face ID optional | ❌ `expo-local-authentication` not installed |
| OTP for new device / explicit logout / revoked / expired session — not every reopen | ❌ No OTP at all. "New device" is not even detectable: `deviceId` is unverified and the client never sends it |
| Returning users unlock with passcode or biometrics | ❌ Not implemented; the app restores a session silently |
| Auto-lock: immediate/30s/1m/5m/15m, no Never | 🟡 **Company maximum is done** (`CompanySettings.autoLockMaxSeconds`, 0019, validated, "never" unrepresentable). Per-user choice and the actual lock behaviour do not exist |
| Owner may impose a shorter company maximum | ✅ Implemented and audited (0019) |
| Owner cannot see or reset another user's passcode | 🟡 Trivially true today (no passcode exists). Must be *designed in*, not inherited |
| 5 failed attempts → cooldown; 10 → WhatsApp OTP | ❌ No counter, no cooldown, no OTP |
| Owner may revoke devices | ❌ Only self-revocation (`logout-all`) exists |
| One user, multiple branches | ✅ **Already works** — `UserBranch` is per (user, branch) with its own role |
| Only Owner has `user.manage` | ✅ Correct in the matrix; **the permission guards no endpoint yet** |
| Store-facing roles: Owner, Store Manager, Store Employee | ✅ Migrated in 0016–0018, drift-tested |
| Per-user normal-price editing Owner-delegated; below-cost Owner-only | 🟡 Below-cost is enforced on `discount.override` (Owner-only). **Per-user delegation is impossible today** — no per-user grant table |
| Seat enforcement is future work | ✅ Nothing invented |

---

## 4. F1 implementation plan (dependency-ordered)

Each stage is independently shippable and leaves the system working.

### Stage 1 — Contactable users *(no dependencies)*

**Schema:** add to `User`: `phone VARCHAR(24)?` (E.164), `phoneVerifiedAt?`,
`email VARCHAR(160)?`, `emailVerifiedAt?`, `@@unique([companyId, phone])`.
Backfill is trivially null.

**Risk:** phone becomes the recovery and OTP channel, so uniqueness must be
enforced at the database level, not in application code, or two accounts can
race onto one number.

### Stage 2 — Per-user permission grants *(depends on nothing; unblocks pricing)*

**Schema:** `UserPermission { companyId, userId, permissionId, grantedBy,
grantedAt, reason }`, `@@id([userId, permissionId])`.
`AccessService.getEffectivePermissions` becomes *role grants ∪ user grants*.

This is the smallest change that unblocks "per-user normal-price editing is
Owner-delegated" and the `return.request` / `import.prepare` gaps recorded in
[`21`](21_PRODUCT_DECISIONS.md). **Deny-overrides are deliberately excluded** —
union-only keeps the model something an Owner can reason about.

**Security note:** a user grant must never confer `discount.override`,
`user.manage` or `settings.manage`. Enforce with an explicit
**delegatable-permission allowlist**, checked server-side.

### Stage 3 — Device identity and session hardening *(depends on 1)*

- Make `deviceId` **required** on login; generate it once on the client and keep
  it in SecureStore.
- Add `AuthSession.deviceFingerprintHash`, `trustedAt?`, `lastSeenIp`.
- A session whose `(userId, deviceId)` pair has never been seen before is a
  **new device** → OTP required before tokens are issued.
- New endpoints: `GET /users/:id/sessions`, `POST /users/:id/sessions/:sid/revoke`
  (Owner, `user.manage`), plus `GET /auth/sessions` for self.

**Compatibility risk:** existing sessions have null `deviceId`. Treat null as
"legacy, trusted until expiry" rather than forcing every current user through
OTP on deploy — and say so in the migration.

### Stage 4 — OTP provider abstraction *(depends on 1; blocked on provider choice)*

```
interface OtpChannel {
  send(to: E164, code: string, locale: 'en'|'ar'): Promise<void>;
}
```

- `OtpChallenge { id, companyId, userId?, phone, codeHash, purpose, attempts,
  expiresAt, consumedAt?, createdAt }` — **Argon2 hash of the code, never the
  code**; 6 digits, 5-minute expiry, max 5 attempts, single use.
- Ship a `LogOtpChannel` (writes to the server log) so Stages 5–7 can be built
  and tested with **no provider contract signed**.
- ⚠️ **Blocked:** the real channel. `docs/21` §16 records that Bankily has no
  confirmed public API; the same discipline applies here — do not implement a
  guessed WhatsApp Business integration.

### Stage 5 — Invitations *(depends on 1, 4)*

`Invitation { id, companyId, branchId, roleKey, phone, employeeCode,
codeHash, invitedBy, expiresAt, acceptedAt?, acceptedUserId?, revokedAt? }`.

Lifecycle: **created** (Owner, `user.manage`) → **delivered** (short code, or a
QR encoding an opaque token — QR is a *transport*, not a second mechanism) →
**accepted** (phone OTP verified, user creates their own password + passcode) →
**consumed** or **expired/revoked**. Acceptance is the only path that creates a
`User` + `UserBranch`; nothing else may.

Endpoints: `POST/GET/DELETE /invitations`, plus **public**
`POST /invitations/:token/accept`.

**Abuse cases to test:** replayed acceptance, expired token, revoked token,
token from another company, brute-forcing the short code (rate-limit per token
*and* per IP), and accepting with a phone that already belongs to a user.

### Stage 6 — Local passcode and biometrics *(client-only; depends on 3)*

**The boundary matters more than the feature.** The app passcode is a *local*
unlock for a session the device already holds. It is:

- stored **only** on the device, in SecureStore, as a hash the server never sees;
- **never** sent to the server, so an Owner cannot see or reset it — which is
  the approved rule, satisfied structurally rather than by policy;
- distinct from `User.passwordHash`, which authenticates to the server.

**Recommendation: do not reuse `User.pinHash` for this.** A server-side column
invites a future "reset their PIN" endpoint and quietly breaks the rule. Leave
the column unused and plan its removal.

Failure handling is local: **5 failures → timed cooldown; 10 → the local
passcode is disabled and a WhatsApp OTP is required** to re-establish the
session (Stage 4). Auto-lock reads `CompanySettings.autoLockMaxSeconds` and
clamps the user's own choice to it — already available from `GET /settings`.

Adds `expo-local-authentication`. **New dependency → needs approval per
`CLAUDE.md`.**

### Stage 7 — Users API and screens *(depends on 2, 3, 5)*

`GET /users`, `GET /users/:id`, `PATCH /users/:id` (name, active, branch
assignments, delegated permissions) — all `user.manage`, all Owner-only.
**No password-set endpoint for other users**, ever: recovery goes through
phone OTP, never through an Owner-typed password.

Screens: Team list · Invite (role, branch, phone, code/QR) · User detail
(branches, delegated permissions, devices, revoke) · Accept-invitation ·
Set passcode · Unlock · OTP entry. All on the design system, EN/AR, RTL-safe.

### Stage 8 — Auditing and rate limits *(cross-cutting, ship with 3–7)*

Write the `login`/`logout` audit actions that already exist in the enum, plus
invitation created/accepted/revoked, session revoked, permission granted/revoked,
OTP sent/verified/failed. **Never log the code or the token.**

Replace per-IP-only throttling with **per-account** counters for login, OTP
verification and invitation acceptance. The in-memory store must move to a
shared one before a second instance exists — note it, do not build it now.

---

## 5. Classification

**Already implemented and reusable — do not rebuild**
Argon2id hashing · rotating refresh tokens with reuse detection · per-device
`auth_sessions` with revocation · permission-based authorization resolved per
request · multi-branch membership with per-branch roles · the company auto-lock
maximum · CLS tenant isolation · the 17-permission catalogue and its drift test.

**Missing but straightforward**
Phone/email columns · `UserPermission` · Users CRUD · session list/revoke
endpoints · writing the audit actions that already exist · a redesigned login
screen on the design system.

**Security-sensitive redesign — do not treat as routine**
New-device detection (requires trustworthy device identity, which does not
exist today) · the local-passcode boundary (§4.6) · per-account lockout ·
invitation-token handling · the delegatable-permission allowlist.

**Blocked on WhatsApp provider selection**
Real OTP delivery, and therefore *end-to-end* verification of invitation
acceptance, new-device login and passcode recovery. Everything else can be
built and tested behind `LogOtpChannel`.

**Deferred to subscription work**
Seat counting, seat limits, grace-period behaviour, and any coupling between
invitation acceptance and seat availability. F1 must not encode seat rules.

---

## 6. Recommended order

`1 → 2 → 3 → 4(stub) → 5 → 6 → 7`, with 8 folded into each.

Stages 1–3 are useful on their own: they make users contactable, make
delegation possible, and let an Owner see and revoke devices — none of which
needs a WhatsApp provider.
