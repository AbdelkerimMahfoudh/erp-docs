# 23 — Users, Invitations & Device Security: F0 Audit and F1 Plan

> **Status:** F0 is a **read-only audit**. No schema, API or screen was created
> or modified while producing it.
> **Audited at:** backend 28 suites / 235 tests green · migration `0019` applied.
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

### Stage 1 — Contactable users *(no dependencies)* — ✅ IMPLEMENTED (CLAUDE-B, 2026-08-05)

**Schema:** add to `User`: `phone VARCHAR(24)?` (E.164), `phoneVerifiedAt?`,
`email VARCHAR(160)?`, `emailVerifiedAt?`, `@@unique([companyId, phone])`.
Backfill is trivially null.

**Risk:** phone becomes the recovery and OTP channel, so uniqueness must be
enforced at the database level, not in application code, or two accounts can
race onto one number.

**What shipped** (migration `0020_user_contact_fields`; backend `1991a01`/`564b3b9`,
mobile `2e63aa8`):

- The four columns and the per-company `UNIQUE(company_id, phone)` index.
  Additive only; the six existing users kept authenticating unchanged, and NULL
  phones coexist under the index (MySQL treats NULLs as distinct).
- **Owner-only Users API** (`user.manage`): `GET /v1/users`, `GET /v1/users/:id`,
  `PATCH /v1/users/:id` (name, phone, email, active). Tenant-scoped; never
  selects `passwordHash`/`pinHash`; status derived (`active`/`inactive`/
  `pending_contact`), not stored. Editing a contact resets its `*VerifiedAt`.
  Users are deactivated, never hard-deleted; you cannot deactivate yourself.
- **Mobile Team screen** (Owner-only, EN/AR, RTL): list with colour+word status,
  branch/role, and a contact-edit sheet. No invite / OTP / passcode buttons.
- Verified live: owner 200, employee 403, E.164 normalization, 409 on duplicate,
  400 on invalid, self-deactivation blocked. 31 new tests (suite 30/266).

**Decisions taken here (were unspecified in the original plan):**

- **Email is NOT unique** in Stage 1 (only phone is, per this plan). Email is
  optional recovery; its uniqueness is deferred.
- **`pending_contact` is derived, not a stored lifecycle column** — deliberately,
  so the pre-existing users are never written into an "incomplete onboarding"
  state.
- **Phone normalization uses strict E.164 validation, not `libphonenumber`** — a
  new dependency needs approval, and full local→international conversion needs a
  default region that arrives with the OTP provider (Stage 4). Numbers must be
  entered in international form for now.

**Remaining after Stage 1:** Stages 2–8 below are unstarted.

### Stage 2 — Per-user permission grants ✅ **IMPLEMENTED** (0021 + 0022)

**The plan changed during implementation, for a reason worth recording.** The
original design was `UserPermission { userId, permissionId }` — per *user*.
A mandatory branch-authorization audit run before the migration found that
`getEffectivePermissions` **unioned permissions across every branch** when no
`X-Branch-Id` was present. A per-user grant added to that union would have made
authority given for one branch apply in all of them. The audit gate fired and
the migration was stopped.

**What shipped instead:**

- **`cfa2dc8` — branch-safety boundary.** The no-branch path now returns only
  explicitly **company-scoped** permissions (`user.manage`, `settings.manage`,
  `branch.manage`, `integrations.manage`, `supplier.manage`). Everything else,
  **including any permission nobody has classified**, is branch-scoped and
  cannot resolve without a branch. Fail-closed by default.
- **`a7ff563` + migration `0021` — `UserBranchPermission`**, keyed
  `@@id([userBranchId, permissionId])`. The grant attaches to an **assignment**,
  not a user, which is what makes it branch-specific. `ON DELETE CASCADE` from
  `UserBranch`, so removing an assignment removes its grants.
- **`0b6cbd9` + migration `0022` — deployment safety.** `0021` created the table,
  but the `price.edit` **row** is reference data, and `migrate deploy` never runs
  the seed. `0022` creates the permission and maps it to every company's Owner,
  idempotently, guarded on the stable key. This is the D2.1 lesson repeated one
  level down; a drift test now fails the build if SQL and TypeScript disagree.
- **`7047c93` — grant/revoke API.**
  `PUT|DELETE /v1/users/:userId/branches/:branchId/delegations/price-edit`,
  Owner-only via `user.manage`, both idempotent.
- **`80bc285` — Owner Team control**, one switch per managed branch, EN/AR.

**Deliberate narrowings, all enforced server-side:**

| Rule | Where |
|---|---|
| Only `price.edit` is delegatable | `DELEGATABLE_PERMISSIONS` allow-list; resolution honours nothing else |
| The client cannot name a permission | The authority is in the **route path**; there is no body field to widen |
| Only a **Store Manager** assignment may hold it | `DELEGATION_ELIGIBLE_ROLE`, checked on grant *and* on every resolution — a downgrade neutralizes the grant without any cleanup job |
| `discount.override` stays Owner-only | Not on the allow-list; a grant row for it is ignored even on a manager |
| Never resolves without a branch | Branch-safety boundary above |

**Still open from the original Stage 2 idea:** delegation for `return.request`
and `import.prepare` / `import.approve`. Those permissions do not exist yet and
belong to the Returns and Import workflows. Adding one means adding an explicit
route, which is the friction that keeps this API narrow.

**Not built, deliberately:** the actual price-editing workflow. Stage 2 decides
**who may**; the Pricing phase builds **what they do**. The Team screen says so
in as many words rather than implying the feature is live.

### Stage 3 — Device identity and session hardening ✅ **IMPLEMENTED** (0023)

**Shipped:** backend `91bbb44` · mobile `e5b7db6` · migration
`0023_device_identity`.

The plan said "make `deviceId` required on login; generate it once on the
client". That was **rejected during implementation** for a good reason: a
client-generated identifier is a claim, not a credential — anyone who learns it
can assert it. What shipped instead:

| Property | How |
|---|---|
| Server-issued identity | `UserDevice` row with a UUIDv7 public id |
| High-entropy credential | 32 random bytes, base64url, returned **once** at enrollment |
| One-way storage | Only the Argon2id hash is stored (`secret_hash`) |
| Public id alone proves nothing | `recognise()` requires id **and** secret; a leaked device list is not a credential |
| Local storage | Existing `expo-secure-store`. **No new dependency** — the client never generates a secret, it only keeps what it was given |
| No invasive identifiers | No IMEI, serial, advertising id or fingerprinting. `label`/`platform`/`model`/`appVersion` are untrusted display metadata |
| Scoped identity | One row per (company, user); nothing correlates a device across users or companies |
| Session linkage | `auth_sessions.device_record_id`, nullable, `ON DELETE RESTRICT` |
| Atomic revocation | Revoking a device revokes every session it owns, in one transaction |
| Survives reactivation | The device row stays revoked; re-enabling a user does not restore a lost phone |
| Revoked ≠ forgotten | Revoked rows are kept as history, never deleted |
| Throttled writes | `lastSeenAt` at most once per device per 15 minutes — recognition stays a read path |

**Trust is recorded honestly.** `trust_method` is `legacy` (adopted from a
pre-Stage-3 session), `password` (a password was verified; a phone was not) or
`otp` — and **nothing in Stage 3 writes `otp`**. `otp_verified_at` stays null
for the same reason. No OTP is sent and nothing is marked verified.

**Approved rules, as implemented:**

- Closing/reopening the app, backgrounding it and losing the network never touch
  device trust — none of those paths reach the code that changes it.
- An **explicit logout** sets `reverify_required`, recording that the next
  sign-in here should re-verify by OTP. Stage 3 records; Stage 4 enforces.
  Recognition deliberately still succeeds today, because refusing now would lock
  people out with no OTP to recover with.
- Reinstall, cleared storage or a different installation lose the local
  credential and are therefore a **new device** — by design, not by failure.
- Owner may list and revoke a member's devices (`user.manage` + company check);
  passcodes do not exist yet, so there is nothing for an Owner to see or reset.

### Stage 3.1 — recognition contract (security hardening)

The Stage 3 login treated **any** unrecognised credential the same as no
credential: it enrolled a new `password`-trusted device. That conflated four
different situations and let a failed credential claim mint trust — and let
repeated claims grow the device table without bound. The corrected contract keeps
five cases **structurally distinct**, and the decision is made **before a session
exists**, so a rejected claim creates nothing (no session, device, token, or
`lastLogin` bump):

| Case | Presented | Result |
|---|---|---|
| **A** | No credential (metadata only, or nothing) | Enroll — password-era path, `trust_method = password`, honestly distinct from `otp`. A genuinely new or reset install |
| **B** | A valid, complete pair for this user | Recognise and attach; no secret returned |
| **C** | Known id, **wrong** secret | **Fail closed** — controlled `401 { code: device_unrecognized }`. No new device, no rotation, no secret, no auth |
| **D** | **Unknown** id with a secret | **Fail closed** — an invalid/stale claim, not the absence of one. No device created |
| **E** | **Revoked** id with its credential | **Fail closed** — stays revoked; requires the future OTP/recovery flow |

A half-supplied pair (id without secret, or secret without id) is a claim too and
fails closed. Because OTP does not exist yet, C/D/E **fail closed rather than
falling back to enrollment** — that failure is exactly where Stage 4 will issue a
verification challenge instead of a hard refusal. Recovery today is the honest
"cleared storage = new device" path: the client forgets a rejected credential and
the next sign-in enrolls fresh (case A). Proven by `auth.service.spec.ts`
(including 20 repeated claims → 0 device rows) and live against all five cases.

**Secret exposure** was re-verified end to end: the raw secret is returned only by
a genuine enrollment/adoption, never by a list, an already-bound idempotent
adopt, an audit row, or an error; only its Argon2id hash is stored; and the pino
redaction now covers `req.body.deviceCredential.deviceSecret` for parity with the
password.

### Mobile credential-storage key — company-ambiguous (auth-contract change required)

The client stores the device credential under a key derived from **login alone**
(`erp.device.<login>`). Login is unique only within a company
(`@@unique([companyId, login])`), so this key collides across companies — two
`owner`s, one installation used for multiple companies, or future account
switching. Before Stage 3.1 a collision mis-enrolled silently; now it **fails
closed**, and the client recovers by forgetting the stale entry and re-enrolling
(no lock-out, but device records thrash for colliding logins).

**A collision-free key cannot be built on the client today**, because **no
company/store identifier is known before login** — `signIn(login, password)`
learns `companyId` only in the response. This is the precise auth-contract change
required (not yet authorised — it is an interface change, not a bug fix):

- **Option 1:** the login request carries a stable, public **company/store
  identifier** (a short code the user selects or types, or a scanned/deep-linked
  store id). The key becomes `apiEnv + companyKey + normalizedLogin`.
- **Option 2:** the server issues an opaque **account namespace** the client can
  recover before the next login (e.g. remembered per entered login *and* a
  disambiguating store code) — which still needs a pre-login selector, so it
  reduces to Option 1 in practice.

Until one is chosen, the login-only key is left **as-is** (not swapped for another
ambiguous scheme), the fail-closed recovery prevents lock-out, and a login rename
must re-key the stored credential (`get(old) → set(new) → delete(old)`).

### Stage 3.2 — Store Account ID login + scoped credential (✅ RESOLVES the above)

The auth-contract change flagged above is now **Option 1, implemented**. The
already-approved public **Store Account ID** (docs/21 — "permanent Store ID")
becomes the pre-login tenant selector, and the client-side fail-closed **bypass**
is removed.

**Store Account ID** (`companies.public_store_id`, migration `0024`): a 10-char
uppercase-hex, human-typable, NON-secret code (no `O`/`0`, `I`/`1`, `L`/`1`
confusion). Generated on create (random, unique-index backstop) or backfilled
collision-free from `SHA2(id)`; NOT NULL + UNIQUE; immutable through store-facing
APIs. It is **not** the binary company id, a branch id, a device id or a
subscription id. The Owner sees it (returned by `/auth/me` and the login
response); branch selection still happens after authentication.

**Login contract** — `{ storeAccountId, login, password, deviceCredential? }`:

1. Normalize the Store ID and resolve the company by `public_store_id` — never a
   client-supplied binary company id.
2. Find the user **within that company** (`findByLoginForAuth` is company-scoped),
   so the same `login` in two companies is disambiguated, and Store-ID-A +
   login-from-B fails.
3. Verify the password. A bad Store ID, login or password all fail **identically**
   (`401 Invalid credentials`, no machine code), and every path spends one Argon2
   verify (`verifyDummy`) so timing cannot enumerate.
4. Only **after** primary auth passes is the device credential evaluated (the
   Stage 3.1 fail-closed tree). JWT company identity still comes from the resolved
   server-side company. Existing sessions are unaffected (refresh does not use the
   login), so a deployment logs no one out.

**Client credential namespacing** (mobile): the SecureStore key is now
`erp.device.<apiEnv>.<storeId>.<login>` (pure logic in `lib/device-key.ts`), so
Company A and B never share a key and dev/staging/prod cannot collide. Both paths
key by the server's **canonical** Store ID (from the login response and
`/auth/me`), so login-save and restore-load always agree. Contact changes never
affect the key.

**Legacy credential migration** (one-time, idempotent): a restored session moves
its pre-3.2 `erp.device.<login>` credential into the scoped key using the Store ID
from its **own** `/auth/me` (never another company's namespace); the new key is
written and confirmed **before** the old one is deleted, so a failed secure write
loses nothing. A logged-out legacy user presents the old credential at login — the
server either recognises it (then it migrates) or **fails it closed** (blocking
"device needs verification" state, old key kept); it is never silently enrolled.

**Bypass removed:** the Stage 3.1 client "forget the credential and retry without
it" path is gone — that silently re-enrolled a trusted device from a claim the
server had failed closed. `device_unrecognized` now maps to a blocking, translated
verification state with no fake actions; only a network error is retryable.

**Login-rename (future):** renaming a login changes the key; a rename endpoint
must re-key the credential (`get(old) → set(new) → delete(old)`) or accept a fresh
enrollment.

### Legacy-session adoption, and how Stage 4 takes over

Existing sessions have a null device and **must keep working** — invalidating
them would push every signed-in user through an OTP flow that does not exist.

`POST /v1/devices/adopt` binds one already-valid session to a **legacy-trusted**
device. It is idempotent and single-shot: a session that already has a device
gets that id back rather than a second enrollment, so a retry or two racing app
launches cannot duplicate or rebind it, and one session can never be moved
between devices. A stolen public id is useless without the secret.

**Stage 4 transition.** `legacy` and `password` are deliberately distinguishable
from `otp`. When the provider exists, Stage 4:

1. gates the *enroll* branch of login behind a verified code, instead of
   enrolling immediately;
2. honours `reverify_required` by demanding a code before issuing tokens;
3. optionally expires `legacy` trust on a date, since those devices were never
   verified at all.

**Migration expectation — CORRECTED (F1 Stage 3.1).** An earlier draft claimed
"none of that needs another schema change — the enum carries `otp` and the
timestamp column exists now." **That was wrong, and is retracted.** `trust_method
= 'otp'` and `otp_verified_at` record a *result* — "this device ended up
OTP-verified" — but they are not an OTP *implementation*. A secure OTP system
needs durable **challenge** state that none of the Stage 3 columns can hold:

- challenge purpose (new-device, re-verify, recovery, …);
- the target user, device and session;
- a snapshot of the destination the code was sent to (the phone at send time);
- the **hashed** code (never the code) or the provider's verification reference;
- created-at and expires-at;
- an attempt counter, and consumed / cancelled / failed states;
- resend timing, and an idempotency / provider message reference;
- audit-safe failure information (never the code).

So **Stage 4 requires a fresh `--hex-blob` backup and an additive OTP-challenge
migration** (the `OtpChallenge` model sketched below), not merely writing the
existing enum value. The enum member and timestamp remain useful — they are the
*outcome* Stage 4 sets once a challenge in that new table is verified.

### Stage 4A — Provider-neutral messaging + OTP infrastructure ✅ **IMPLEMENTED** (0025)

**Shipped:** backend `7337b10` (boundary + config), `f987380` (schema + services),
`6192fd8` (tests) · mobile `e936e4e` (Store Account ID visibility) · migration
`0025_otp_challenge_and_intent`.

**No provider is integrated. No message is sent. OTP is not active in
production. New-device login still blocks on `device_unrecognized`, unchanged.**

#### Correction to the Stage 3 report

The Stage 3 report claimed Stage 4 would need **no migration**, because
`user_devices` already carried an `otp` trust method and `otpVerifiedAt`. That
was **wrong**, and Stage 4A corrects it.

Those two fields record an *outcome*. A working OTP flow needs durable
*challenge* state, and none of it existed: code hash, attempt counter, maximum
attempts, last attempt, send count, last send, resend-not-before, expiry,
consumed/cancelled/locked timestamps, delivery outcome, provider message
reference and a client idempotency key. An enum value and a timestamp are not
an OTP system. Hence two new tables, additive, after `0024`.

#### The messaging boundary

`WhatsAppChannel` is the only messaging type authentication code may see. Two
deliberate absences:

- **No raw-message call.** A caller names a registry template and supplies
  variables the registry validates. A generic `sendText(body)` would let any
  later feature put arbitrary content — including a code — into a message path
  nobody reviewed.
- **No provider error escapes.** Adapters classify failures as
  `channel_unavailable` / `rejected` / `temporary` / `not_authorized`, so no
  vendor payload can reach a log, an audit row or a caller's branch.

| Adapter | Where | Behaviour |
|---|---|---|
| `DisabledWhatsAppChannel` | **default, production-safe** | No network call. Returns a controlled "delivery unavailable" |
| `TestWhatsAppChannel` | tests only | Captures the message so tests can assert the real code. **Not selectable by configuration** — asking for it throws |
| `DevelopmentLogWhatsAppChannel` | local only | Masked destination in the app log; the code only to an explicitly marked `console` dev sink, never the application logger. **Production startup fails if selected** |

There is no HTTP client anywhere in this project, so "performs no network call"
is true by construction rather than by review.

#### OTP secret handling

Six digits carries ~20 bits of entropy: an unkeyed digest of a code is a lookup
table, not a one-way function, and a stolen `otp_challenges` table would hand
over every live code. Argon2 (used for passwords here) would slow that down but
still permits an offline attack and is far too slow to run per attempt.

So: **HMAC-SHA256 keyed by `OTP_PEPPER`**, which lives in configuration and
never in the database, with the challenge id mixed in so the same code in two
challenges does not produce the same hash. Comparison is constant-time over
fixed-width digests. All from `node:crypto` — **no new dependency**.

`OTP_PEPPER` has **no default and no fallback**. Unset means OTP challenge
creation refuses; the rest of the application still starts. A missing pepper
degrades to "no OTP", never to "OTP with a guessable hash".

#### Concurrency, delivery and the outbox boundary

`active_key` is non-NULL only while a challenge is pending and is NULLed on
every terminal transition. MySQL lets NULLs repeat under a UNIQUE index, so
"**at most one live challenge per user, purpose and device**" is a database
guarantee, not an application promise. Verification wins through a conditional
`updateMany` on `status: pending`, so concurrent correct submissions produce
exactly one success.

**Delivery is synchronous and its true outcome is recorded.** The
recognition-outbox pattern is deliberately **not** reused: a durable delivery
queue would mean persisting a deliverable secret and retrying it blind. On
temporary failure the caller must make a new controlled attempt. Nothing ever
claims a send that did not happen — with no provider, the honest recorded state
is `channel_unavailable`.

#### Pre-auth verification intent

`VerificationIntent` is the foundation for continuing a new-device sign-in
**without issuing an access token first** — an access token is authority, and
"your password was right, now prove the device" is not. 256-bit opaque token,
SHA-256 stored (no pepper needed at that entropy), single-use, bound to
company + user + purpose + device, consumed atomically inside the transaction
that performs the authorised work.

**Built and tested; nothing issues one in the production login flow yet.**

#### Purposes supported

`phone_verification` · `device_verification` · `logout_reauth`.

**Revoked-device recovery is deliberately absent.** Neither `docs/21` nor this
document defines who may restore a revoked device, on what evidence, or whether
an Owner can do it on an employee's behalf. That is a **product decision needed
before implementation** — adding a purpose for it now would be inventing the
rule.

### Stage 4B — Provider integration *(NOT started; blocked on a provider decision)*

Everything below waits on choosing a WhatsApp Business provider. The
application layer should not need to change:

1. Write one adapter implementing `WhatsAppChannel`; register it in
   `MessagingModule`; set `WHATSAPP_CHANNEL` and `WHATSAPP_TEMPLATE_AUTH_OTP`.
2. Get the `auth.otp` template approved and fill `providerTemplateName`.
3. Gate the login *enroll* branch: an unrecognised device issues a
   `VerificationIntent` + challenge instead of the current hard block.
4. Honour `reverifyRequired` after an explicit logout.
5. Set `User.phoneVerifiedAt` **only** on a verified `phone_verification`
   challenge whose `candidatePhone` still matches the user's current phone.
6. Decide revoked-device recovery (above) before wiring it.

⚠️ `docs/21` §16 records that Bankily has no confirmed public API; the same
discipline applies here. **Do not implement a guessed WhatsApp integration.**

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
~~New-device detection~~ — **done in Stage 3**: identity is server-issued and
credential-backed, so "is this a device we know?" is now a question with a
trustworthy answer · the local-passcode boundary (§4.6) · per-account lockout ·
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
