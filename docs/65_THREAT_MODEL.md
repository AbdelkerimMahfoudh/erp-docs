# 65 — Threat model

> Written 2026-09-30 for the pre-release security gate (`docs/48`). It names what is worth protecting, who would want
> it, how they would try, and which controls answer each attempt — so the field-level encryption question (§5) and the
> gate's ratings rest on something written down rather than on instinct. Revisit after any change to authentication,
> authorisation, money handling or exposure.

## 1. What is protected

| Asset | Why it matters | Where it lives |
|---|---|---|
| **A shop's money and stock truth** — sales, payments, purchases, units (IMEI/serial), closings, corrections | The business runs on it; a wrong or forged record is money lost or a phone that vanishes | MySQL, tenant-scoped tables |
| **Cost prices and margins** | The shop's private economics; staff must not see them (`docs/04`) | `units`, `purchases`; withheld by the cost-gating interceptor |
| **People's identities and contacts** — staff names, WhatsApp numbers, emails; customers' names and numbers | Personal data under any privacy regime; a harvested number list is a phishing list | `users`, `customers`, `suppliers`, `registration_attempts` |
| **Credentials** — password/PIN hashes, refresh-token and device-secret hashes, OTP hashes, admin session hashes, the server secrets | The keys to everything above | database (hashes only), the host's environment (secrets) |
| **The audit trail** | What happened, provable after the fact | `audit_logs` (append-only, chained since 0085), `subscription_events`, `platform_audit_events` |
| **The platform's control** — who is activated, for how long | The business model; a forged activation is revenue lost | `subscriptions`, `platform_admins` |

## 2. Who, and how

| Actor | Motivation | Capability |
|---|---|---|
| **A1 — an anonymous internet user** | Harvest accounts, spam codes, find a way in | The public routes: registration, sign-in, admin sign-in, the webhook |
| **A2 — a staff member of a shop** (employee, manager) | See costs, edit their own sales/debts, keep access after leaving | A valid session with a role; a phone in hand; knows how the shop works |
| **A3 — an Owner of another shop** | Read a competitor's stock or people; abuse the consignment/connection links | A valid Owner session in *their* company |
| **A4 — a person with a lost or stolen staff phone** | Use a signed-in app | The device, possibly unlocked, holding a refresh token and a device secret |
| **A5 — a platform administrator gone rogue** (or their captured session) | Activate shops for free, read businesses | The admin realm: every business's status and people |
| **A6 — the hosting operator / a database administrator / a leaked backup** | Read or rewrite anything at the storage layer | Direct MySQL access; the backup files |
| **A7 — a supply-chain compromise** (a dependency, a build) | Exfiltrate secrets or data from the server or the app | Code execution in the server process or the app bundle |

## 3. Attack paths and the control that answers each

| # | Path | Controls (evidence in `docs/48`) | Residual |
|---|---|---|---|
| T1 | A1 guesses passwords or enumerates accounts at sign-in | argon2id, timing-even generic refusals, `AUTH_THROTTLE_LIMIT` per client, sessions bound to devices | Distributed guessing is only slowed, not detected (control 12 — medium) |
| T2 | A1 floods registration / codes | `PUBLIC_THROTTLE`, per-number and per-person OTP caps, a code needed to finish registration | Same |
| T3 | A1 forges the delivery webhook | HMAC over the raw body with the app secret; verify token; only a challenge's delivery state can change | — |
| T4 | A2 calls a route above their role or another branch | Global JWT guard, `PermissionsGuard` with company-wide/branch-scoped resolution, branch header validated against assignments, entitlement interceptor default-deny for unlisted writes | A route with no `@RequirePermissions` is open to any role — the route inventory (`docs/48` 3.1) is the check |
| T5 | A2 reads costs or margins | Cost-gating interceptor strips financial fields by role; DTO selects exclude hashes | — |
| T6 | A2 tampers a request body (price, status, company id) | `ValidationPipe` whitelist + `forbidNonWhitelisted`, server-computed financials, tenant extension injects `companyId` into every query and fails closed without one | — |
| T7 | A2 keeps access after deactivation or a lost phone | Deactivation revokes every session atomically; access tokens are bound to sessions and revalidated on every request; device revocation; account deletion revokes all | — |
| T8 | A3 reads another company through an id | Tenant extension scopes every model by `companyId`; cross-company ids answer 404, never 403; two-sided records (consignments, connections) check both sides explicitly (`tenant-models.spec.ts` pins the list) | A per-module adversarial HTTP suite is owed (control 4) |
| T9 | A4 uses a stolen phone | Refresh rotation with reuse detection (a replayed rotated token revokes the session), device secret hashed, SecureStore, Owner can revoke the device, explicit logout marks re-verification | The app has no in-app lock (PIN/biometric) — the handset's lock is the control (documented in `docs/15`) |
| T10 | A5 activates or deletes at will | Separate realm with its own table and cookie; step-up password on every mutation; append-only `platform_audit_events`; **no administrator deletion route**; the legacy static-key provisioning route closed in production (R5) | Two-person control on activation does not exist (single admin) |
| T11 | A6 rewrites the audit trail or reads people's data from a dump | Append-only triggers for the application account; **hash chain (0085)** detects any modified, removed or reordered row and any trigger bypass; encrypted backups with a drill; least-privilege identities so the *application* cannot be the path | A DBA can still *read* everything (§5); the chain detects rewriting, it does not prevent it |
| T12 | A6 restores a backup onto the wrong server or leaks it | AES-256 backups, passphrase off the host, checksum, drill | Off-host copy location is a hosting decision (control 8.2) |
| T13 | A7 ships a secret in the bundle or a malicious dependency | No server secret is `EXPO_PUBLIC_*`; release-config check; web-export grep; full-history secret scan; `npm audit` on the lockfile in CI | CI has not yet run on GitHub (first run owed); no SBOM |
| T14 | A2/A3 race the system (two sales of one unit, two confirmations) | Database uniqueness and conditional updates (`ux_saleitem_active_unit`, OTP `active_key`, request `version`), idempotency keys, deadlock retry | — |
| T15 | Anyone reads a code or token from a log | pino `redact` for headers, cookies, passwords, tokens; URLs scrubbed; codes never logged (the dev channel is refused in production) | Log *destination* and retention are hosting decisions |

## 4. Trust boundaries

```
phone / browser ──TLS (owed: hosting)──▶ edge ──loopback or private network──▶ API (Nest) ──phonestore_app──▶ MySQL
                                                                                    │
                                              WhatsApp Cloud API ◀──https, bearer──┘  (webhook back, HMAC)
platform admin browser ──TLS──▶ edge ──▶ API (admin realm, HttpOnly cookie)
operator shell ──phonestore_migrator──▶ MySQL (migrations only)     backup host ──phonestore_backup──▶ MySQL
```

The API trusts nothing from a client about *who* or *which company*: identity comes from the session, the company from
the token's session, the branch from a header checked against assignments. The database trusts the API only for DML.

## 5. Field-level encryption: the decision

**Not applied in this release, deliberately.** The fields at risk from A6 (a database reader) are people's names and
WhatsApp numbers. Encrypting them in the application would (a) break the per-company unique index on `phone` that
makes WhatsApp sign-in and one-number-one-person possible, (b) break the searches the Team and Customers screens
depend on, and (c) put the key on the same host as the data, which is where A6 already is — a key management service
would be required for the encryption to mean anything, and none exists in this deployment. What answers A6 instead:
least-privilege identities (the application cannot read other schemas, the backup account cannot write), encrypted
backups with the passphrase off the host, the hash chain that makes rewriting visible, de-identification on deletion,
and — owed to hosting — disk encryption at rest and access logging on the database host. **Revisit** if the deployment
gains a KMS or if a regulator requires encryption of contact data at the field level.

## 6. What this model does not cover

The control website (`retail-erp-control-web`, a separate repository) — its CSP, CSRF and session handling are its
own gate. The shop's physical security. Social engineering of the owner or of the platform administrator.
