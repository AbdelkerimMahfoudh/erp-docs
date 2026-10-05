# 48 — Pre-release security gate

> **This is a release blocker, not an improvement.** No public application, no
> portal and no production API may be published while any item below is
> unresolved at **critical** or **high**. Passing functional tests is not
> evidence for this gate: green unit tests say the shop works, not that it is
> safe to expose to the internet.

**Status: RUN ONCE, 2026-09-30 — NOT PASSED.** The gate was worked as a checkpoint by the CLAUDE-B session
(backend `ae64de8` → `da0d340`, mobile's two commits on `reports-export` — ids in `CURRENT_HANDOFF.md`) on disposable
databases and the container's tooling. Every control below carries a verdict and its evidence. **It is not passed** because several
mandatory items can only be produced outside a session — the provider account, the production host, Apple access,
legal advice, an independent assessment — and one product conflict (D110) is the owner's decision. §12 lists the
blockers; §11 the run. The threat model is [`docs/65`](65_THREAT_MODEL.md); deletion and privacy are
[`docs/64`](64_ACCOUNT_DELETION_AND_PRIVACY.md).

---

## How this gate is passed

1. Every section below is worked as its own checkpoint, with its own evidence.
2. Each finding is rated **critical / high / medium / low**, with the rating
   written down *before* the fix, so nothing is quietly downgraded to pass.
3. A finding is closed by a **test or a recorded check**, never by an assertion
   that it was fixed.
4. The gate is re-run end to end on the release candidate. Fixing something in
   the middle of an audit invalidates the parts already checked; the final pass
   must be on one build.
5. Critical and high findings block publication. Medium and low are recorded
   with an owner and a date.

---

## The twenty controls — run of 2026-09-30

Verdicts: **PASS** (evidence produced), **PARTIAL** (implemented; part of the evidence can only come from production
or from outside), **FAIL** (not implemented; rated), **N/A** (does not apply here, with the reason). "Production
evidence owed" names what must still be captured on the release candidate.

| # | Control | Verdict | Evidence produced in this run | Production evidence owed |
|---|---|---|---|---|
| 1 | Secrets out of the mobile and web bundles | **PASS** | `EXPO_PUBLIC_*` only carries the API origin; web export (`expo export --platform web`) grepped for `WHATSAPP_ACCESS_TOKEN`, `OTP_PEPPER`, `JWT_ACCESS_SECRET`, `PLATFORM_ADMIN_KEY`: none; `scripts/verify-release-config.js` refuses a server secret named as `EXPO_PUBLIC_*`; the API answers no hash, token or code (§6.4) | the iOS archive inspected the same way |
| 2 | Secret scanning of the full history, automated | **PASS** | `scripts/scan-secrets.js` over **every blob of every ref**: backend 1 296 blobs / 154 commits, mobile 1 650 / 215, docs 195 / 51 — no secret; the six hits were unit-test fixtures, allow-listed by exact value in `.secret-scan-allow` and reviewed here; `.env*` appear in no commit of any repository; `.github/workflows/security.yml` in both repositories runs gitleaks + the scanner on every push and weekly | the first green run on GitHub Actions (github.com is unreachable from the container) |
| 3 | Database credentials never in a client; a least-privilege runtime identity | **PASS** | the app talks only to the API (no MySQL client in the mobile lockfile); `deploy/mysql-identities.sql` creates migrator / app / backup / admin; `deploy/verify-mysql-identities.sh` **20 of 20** as each account (`docs/22` E.2) — including the append-only triggers refusing `UPDATE`/`DELETE` as the application account (§2.5, exercised for the first time as that account) | the same script on the production server |
| 4 | Company, branch and user scoping with adversarial cross-tenant tests | **PARTIAL** | the tenant Prisma extension injects `companyId` into every query and fails closed without one (`tenant.extension.spec.ts`); `tenant-models.spec.ts` pins every model without a company column to a documented list; cross-company ids answer 404 (journey: forged company in a deletion confirmation, another shop's code, the administrator's session on a tenant route); the earlier audit's cross-store journeys (2026-09-30 morning, `AUDIT_REPORT.md`) and the QA verification (own product readable, the next boutique's refused 404/404/403) | **a per-module adversarial HTTP suite** (each write and read of every module attempted with company B's ids from company A) — rated **high**, owner: next session |
| 5 | TLS in transit, encryption at rest, a field-encryption decision from a threat model | **PARTIAL** | production refuses non-`https://` browser origins and provider addresses (`production-guard.spec.ts`); helmet HSTS on the production host only; backups AES-256 with a verified drill (`docs/22` E.2); **field-level encryption decided against, with reasons, in `docs/65` §5** | the edge's TLS certificate and redirect capture; disk encryption on the database host; the off-host backup location |
| 6 | Server-side authentication and authorisation | **PASS** | global `JwtAuthGuard` (every route unless `@Public()`), `PermissionsGuard`, the entitlement interceptor, the separate platform realm with step-up; the journey's 401s for the Owner on administrator routes and for the administrator on tenant routes; the permission-catalogue drift specs | — |
| 7 | Ownership, role, company and branch checks, default deny | **PASS** | an unclassified mutation is blocked for a lapsed shop (`entitlement-rules.spec.ts`); a route without a branch assignment is 403; cross-company records 404 never 403 (`devices.service.ts`, `user-management.service.ts`); the entitlement interceptor fails closed without a company | — |
| 8 | DTO allow-lists and server-computed financials | **PASS** | `ValidationPipe` `whitelist` + `forbidNonWhitelisted` globally (`main.ts`); a malformed code never reaches a hash (journey AB); financial fields stripped by role (`cost-gating.interceptor.spec.ts`, `financial-fields.spec.ts`); no client-supplied cost or margin is stored (the sale race fix D5 of the morning audit) | — |
| 9 | Secure cookies and CSRF; Expo secure storage; token rotation, expiry, revocation | **PASS** (API) / **N/A** (portal, other repository) | admin cookie `HttpOnly`, `SameSite=Lax`, `Secure` in production (the guard refuses `COOKIE_SECURE=false`); the portal cookie `SameSite`; SecureStore on native (`lib/storage.ts`, checked by the release script); refresh rotation with reuse → revocation (`sessions.service.ts`); access tokens bound to sessions and revalidated on every request; deactivation, contact change and deletion revoke every session (journey: 401 at once) | the control website's CSRF and cookie flags — its own gate |
| 10 | Slow salted hashing; secure reset; session invalidation | **PASS** | argon2id (`HashingService`), timing-even refusals with a dummy verify; **there is no self-service password reset** — recovery is an administrator-issued single-use hashed invitation (`owner-invitation.service.ts`); sessions invalidated as in 9 | — |
| 11 | Rate limits on login, reset, OTP and device enrolment; enumeration prevention | **PASS** | `AUTH_THROTTLE_LIMIT` (10/min/client), `PUBLIC_THROTTLE` on registration and admin sign-in, `ACCOUNT_THROTTLE_LIMIT` **5/min** on every code-issuing route (**429 recorded in run 3 of the journey at the default**), OTP per-person and per-number windows and daily caps, five attempts then locked; generic 401 for unknown / wrong / disabled; a wrong registration code answers 400 the same way | — |
| 12 | Risk-based bot protection that does not block shop use | **FAIL — medium** | throttles only; no device-risk signal, no proof-of-work or CAPTCHA on registration; the public surface is small (registration needs a WhatsApp code to finish; admin sign-in is throttled and cookie-bound) | owner: a decision on a challenge for registration bursts, after the first month's traffic is seen |
| 13 | Raw SQL audited; parameterised Prisma | **PASS** | inventory: **25 files** use tagged-template `$queryRaw`/`$executeRaw` (parameters bound); **one** `$queryRawUnsafe` (`health.controller.ts`, two constant strings, no input); the transfer test double is test code only | — |
| 14 | Validation and limits on bodies, params, ids, dates, amounts, pagination, sizes, nesting | **PASS** | class-validator with `MaxLength`/`Min`/`IsIn` on every DTO; ids validated (`isUuid` → 404); uploads 8 MB; Express's default 100 kB JSON body limit (no override); pagination capped (25 / 200) | — |
| 15 | Output escaping for HTML, PDF, CSV and URLs | **PASS** / **N/A** | CSV formula armouring with tests (`csv-writer.spec.ts`: `=`, `+`, `-`, `@`, tab, CR); the API renders no HTML and generates no PDF (it *reads* PDFs); URLs are scrubbed in logs (`log-scrub.ts`) | the portal's HTML — its own gate |
| 16 | Uploads typed by content, size and count limits, private storage, download headers, malware policy | **PASS** (after a fix) | **found failing** — type was decided by the file name only; **fixed in `bde6bc4`**: the first bytes must match (`file-kind.spec.ts`); 8 MB, one file, parsed in memory and **never stored or served** (so no download path and no malware residue); the policy: structured data is extracted, the file discarded | — |
| 17 | Minimal DTOs: no cost/margin to the wrong role, no hashes or tokens ever | **PASS** | `USER_SELECT`, `DEVICE_SELECT`, the account view and the platform business view exclude every hash and token; the journey asserts no code in any response and only a hash in the database; costs withheld by role (8) | — |
| 18 | Security headers, a portal CSP, HSTS only on the production host | **PARTIAL** | helmet's defaults on the API; HSTS dropped when `APP_ENV=staging` (`main.ts`) | the portal's CSP without `unsafe-inline` — the control website repository; a header capture on the production host |
| 19 | HTTPS required for the production API and portal, including the release build | **PASS** (in code) | the guard refuses plain-http origins and provider addresses in production; `verify-release-config.js` refuses a non-https `EXPO_PUBLIC_API_ORIGIN` for the production and preview profiles (**exercised: refused / sound / refused**); the CI job runs it | the certificate, the redirect, and a release build made with the production origin |
| 20 | Dependency and lockfile scanning in CI, with tracked exceptions | **PARTIAL** | `npm audit --omit=dev` today: backend **17** (6 high: `@nestjs/platform-express` via `@nestjs/core`, `brace-expansion`, `joi`, `js-yaml`, `lodash`, `multer`), mobile **18** (3 high: `@xmldom/xmldom`, `brace-expansion`, `js-yaml`); the CI job fails the build above `high`; **none of these is bumped** (the previous record of 17 / 18 stands) | the triage: each high advisory bumped or recorded as an accepted exception with an expiry (§7.3) — rated **high** until triaged |

## The additional blockers of the gate

| Blocker | State | Where |
|---|---|---|
| A threat model | **done** | `docs/65` |
| Module-wide tenant-isolation tests | **partial** (control 4) | owed: the per-module adversarial suite |
| Tamper-evident audit records | **done** — a per-company hash chain written by a `BEFORE INSERT` trigger for every inserter; the verifier detected a modified row, a deleted row and a trigger-bypass insert; 30 parallel audited writes for one company kept the chain intact after the trigger's lock order was fixed (5 deadlocks in 30 with the first version) | migration 0085, `scripts/verify-audit-chain.ts` |
| Separate production identities for app, migration, backup and admin | **done in code and proven on a copy** (20 of 20) | `deploy/mysql-identities.sql`, `verify-mysql-identities.sh`; production run owed |
| Encrypted backups and a restore drill | **done on a copy** (`docs/22` E.2) | production drill owed |
| Redacted logging and alerts | **partial** — pino `redact` for authorization, cookies, passwords, tokens, device secrets; URLs scrubbed; codes never logged; **no alerting exists** | owed: a log destination with retention and an alert on `deletion_failed`, chain verification failures and 5xx rates |
| Session and device lifecycle | **done** — rotation, reuse detection, revocation, deactivation, deletion; devices listed and revocable | — |
| Business-logic race and replay tests | **done** — the morning audit's D5 (two identical sales), OTP and request races in the deletion suite (one winner), 30 parallel audited writes, idempotent registration and requests | — |
| Mobile release hardening | **done in code** — `verify-release-config.js`, SecureStore, no debug overlay, secret-free bundle | the archive: `ITSAppUsesNonExemptEncryption=false` to declare, the SDK's privacy manifest to confirm |
| Privacy, retention and deletion policy | **drafted** (`docs/64` §6) | the legal retention period |
| Staging/production separation, rollback, incident response | **partial** — `docs/39` staging, `docs/22` rollback (a Git rollback does not roll the database back), the production guard | owed: a written incident-response procedure with names and an on-call phone |
| An independent pre-release security assessment | **not done — a self-review cannot be represented as it** | owed: an external assessor on the release candidate |

---

## 1. Secrets

| # | Check | Evidence required | 2026-09-30 |
|---|---|---|---|
| 1.1 | No secret in any source, mobile bundle or web bundle | Grep of built artefacts, not only of source | ✅ web export grepped; iOS archive owed |
| 1.2 | **Full Git history** scanned in all repositories | Scanner run over every ref, not just `HEAD` | ✅ every blob of every ref, three repositories |
| 1.3 | Every exposed credential rotated, old one proved dead | A refused request using the retired credential | ✅ none exposed in this run; G2A-CP4.5's tokens were revoked and proved dead earlier |
| 1.4 | No database credential reachable by any client | Bundle inspection; the app talks only to the API | ✅ |
| 1.5 | Server configuration loaded from environment, never committed | `.env` absent from every commit in history | ✅ `git log --all -- .env*` empty in all three |

One precedent is already recorded (`G2A-CP4.5`: session tokens written into
`mobile/public/` and committed). That is the failure mode this section exists
for, and it is why scratch files must never be created inside a repository.

## 2. Database accounts and least privilege

| # | Check | Evidence required | 2026-09-30 |
|---|---|---|---|
| 2.1 | The application account cannot `DROP`, `ALTER` or read other schemas | Refused statements, run as that account | ✅ `verify-mysql-identities.sh` |
| 2.2 | The migration account is separate and used only by migrations | Grant listing per account | ✅ `deploy/mysql-identities.sql` |
| 2.3 | The backup account is read-only | Refused write, run as that account | ✅ insert/update/delete/alter refused |
| 2.4 | Administrative access is not shared with the application | Named accounts, with an owner each | ✅ `phonestore_admin@localhost` template; the person's name is the owner's to record |
| 2.5 | Audit append-only triggers hold **as the application account** | An `UPDATE`/`DELETE` on `audit_logs` refused as that account | ✅ **closed** — refused as `phonestore_app` on a copy; also after a restore |

## 3. Authorisation and tenant isolation

| # | Check | Evidence required | 2026-09-30 |
|---|---|---|---|
| 3.1 | Every endpoint declares a permission, or documents why it is open | Route inventory with its guard | ◐ the route classification pins every always-allowed write and read by name; a full inventory table is owed |
| 3.2 | Adversarial cross-company tests: company A cannot read, write or reference company B | Failing-by-design tests, per module | ◐ see control 4 |
| 3.3 | Branch scoping cannot be widened by omitting or forging `X-Branch-Id` | Requests without, and with somebody else's, branch id | ✅ without: company-wide permissions only, branch reads 403; forged: `AccessService` throws (specs) |
| 3.4 | A retired role's grants are actually revoked | Precedent: `branch_manager` kept `discount.override` in the database after code removed it | ✅ `role-matrix-drift.spec.ts`, migration 0067 |
| 3.5 | Delegated grants cannot exceed the delegatable set | A grant of a non-delegatable key has no effect | ✅ `access.service.spec.ts` |

## 4. Input handling

| # | Check | Evidence required | 2026-09-30 |
|---|---|---|---|
| 4.1 | DTO allow-lists everywhere; unknown fields rejected, never absorbed | Mass-assignment attempt per write endpoint | ✅ global `forbidNonWhitelisted` |
| 4.2 | No client-supplied money, cost, margin or status is trusted | Field-tampering attempts on sale, return, transfer, consignment, loan | ✅ server-computed; morning audit |
| 4.3 | Server-side validation of every field, with size limits | Oversized body, oversized field, deep JSON | ✅ 100 kB body, `MaxLength` everywhere, 8 MB uploads |
| 4.4 | Parameterised database access; every raw query audited | Inventory of raw SQL with justification | ✅ control 13 |

## 5. Authentication

| # | Check | Evidence required | 2026-09-30 |
|---|---|---|---|
| 5.1 | Password hashing is current and correctly parameterised | Algorithm, cost factor, and a verification test | ✅ argon2id, library defaults (m=64 MiB, t=3, p=4); `deletion-rules.spec.ts` proves the unusable hash |
| 5.2 | Recovery cannot enumerate accounts or be replayed | Identical responses; single-use, expiring tokens | ✅ invitations single-use and hashed; codes single-use |
| 5.3 | Login, reset and OTP are throttled, with risk-based anti-automation | Rate-limit tests, including distributed attempts | ◐ throttled (control 11); distributed / risk-based owed (control 12) |
| 5.4 | Mobile tokens in secure device storage; refresh rotation is safe | Device inspection; replay of a rotated token refused | ✅ SecureStore; `sessions.service.spec.ts` |
| 5.5 | Web cookies are `HttpOnly`, `Secure`, `SameSite`; CSRF defended | Response headers and a cross-site attempt | ✅ API cookies; the portal owed |

## 6. Output and files

| # | Check | Evidence required | 2026-09-30 |
|---|---|---|---|
| 6.1 | Context-aware escaping for HTML, PDF and CSV | Injection strings rendered in each format | ✅ CSV; HTML/PDF N/A on the API |
| 6.2 | CSV formula armouring (`=`, `+`, `-`, `@`) without corrupting negatives | Spreadsheet opened, values intact | ✅ `csv-writer.spec.ts` |
| 6.3 | Uploads are private, type-checked and size-limited | Direct-URL access refused | ✅ typed by bytes since `bde6bc4`; never stored |
| 6.4 | API responses carry only what the caller may see | Response diff per role — cost, margin and other companies' data absent | ✅ control 17 |

## 7. Transport and platform

| # | Check | Evidence required | 2026-09-30 |
|---|---|---|---|
| 7.1 | Production API and portal are HTTPS-only, with HSTS | Redirect and header capture | ◐ enforced in configuration; capture owed |
| 7.2 | Security headers and a real CSP on the portal | Header capture; CSP without `unsafe-inline` | ◐ API headers; portal owed |
| 7.3 | Dependency and lockfile scanning, with a triage record | Scanner output; advisories recorded | ◐ 17 / 18 recorded, CI job written, triage owed |
| 7.4 | Error responses leak no stack trace, SQL or internal path | Production-mode error capture | ✅ `AllExceptionsFilter` allow-lists the detail keys; the journey's error bodies carry a code and a sentence |

## 8. Data protection and operations

| # | Check | Evidence required | 2026-09-30 |
|---|---|---|---|
| 8.1 | Backups encrypted at rest and **restore-tested** | A restore drill, dated | ✅ `docs/22` E.2 (a copy); production owed |
| 8.2 | Off-machine backup copies exist | Location recorded; today dumps are local-only | ❌ a hosting decision (`docs/42`) |
| 8.3 | Logs redact tokens, passwords and personal data | Log sample from a real request | ✅ redact paths; the journey's log carries masked numbers only |
| 8.4 | Monitoring and an incident-response procedure exist | Who is called, and what they do | ❌ owed |
| 8.5 | Privacy, retention, and company/account closure are defined and implemented | Deletion/export request walked end to end | ✅ deletion walked (journey); retention period and export owed (`docs/64` §6) |

## 9. Business logic under attack

| # | Check | Evidence required | 2026-09-30 |
|---|---|---|---|
| 9.1 | Race conditions on stock, transfers, consignments and payments | Concurrent attempts; one winner, no double movement | ✅ morning audit D5; database uniqueness |
| 9.2 | Replay and idempotency across every write with a client key | Same key twice; different payload under one key refused | ✅ registration and deletion requests; OTP `already_used` |
| 9.3 | Approval workflows cannot be self-approved or bypassed | Attempts as each side of the deal | ✅ the Owner cannot approve (401), the administrator needs step-up, stale version 409 |
| 9.4 | Financial corrections cannot create money | Reversal arithmetic proved, with audit | ✅ `docs/48` earlier record, corrections specs |

## 10. Release review

| # | Check | Evidence required | 2026-09-30 |
|---|---|---|---|
| 10.1 | OWASP **ASVS** review at the agreed level | Completed checklist with per-item evidence | ❌ owed |
| 10.2 | OWASP **API Security Top 10** review | Same | ❌ owed |
| 10.3 | OWASP **MASVS** review for the mobile app | Same | ❌ owed |
| 10.4 | Targeted penetration test of an isolated, production-like release candidate | Report, with findings rated and closed | ❌ owed — the independent assessment |

## 11. The run of 2026-09-30

- **Real HTTP** (`journey-security.cjs`, in the session's scratch, on a fresh disposable database per run): **117 of
  117** — see `docs/21` D104–D110 *Verification* for the list. Run 3 at the default account limit recorded **429** on
  the deletion routes after five calls in a minute from one client; runs 4–6 raised the limit to reach every case.
- **The audit chain:** sealed 32 existing rows; a modified row, a deleted middle row and an insert made with the
  trigger dropped each broke the chain for the verifier; 30 parallel customer creations (each an audited write) for one
  company: **25 of 30 with the first trigger** (five InnoDB deadlocks from `INSERT IGNORE`'s shared lock), **30 of 30
  without it, 30 of 30 with the fixed lock order** (the migration was corrected before it reached any real database).
- **Identities, backup, restore:** `docs/22` E.2.
- **Unit suites:** backend 175 suites / 3 166 tests, `tsc` clean; mobile 85 pure suites, lint 30 known warnings, `tsc`
  the one known `global.css` error, web export secret-free.
- **Not run:** anything on the phone, a real WhatsApp send, a store build, GitHub Actions.

## 12. Release blockers (in the order they should be cleared)

1. **The WhatsApp Business account**: templates `auth.otp`, `account.deletion`, `account.deleted` approved in EN/FR/AR,
   a sending number, a system-user token; then a real send in each language recorded in `docs/24` §51. Without it,
   registration cannot finish and **no account can be deleted** — the deletion flow is a release blocker until then.
2. **D110** — the owner's decision on logins without a WhatsApp number (`docs/64` §7).
3. **Production secrets and hosting**: `OTP_PEPPER`, `JWT_ACCESS_SECRET`, the four database passwords, TLS at the edge,
   the API bound behind it (`API_INGRESS`), disk encryption and an off-host backup location.
4. **Dependency triage** (control 20): each high advisory bumped or accepted with an expiry.
5. **The per-module adversarial tenant suite** (control 4).
6. **The legal retention period** (`docs/64` §6) and the incident-response procedure (8.4).
7. **Apple**: the archive's privacy manifest and encryption declaration, the demo journey for review, `docs/24` §51 on a
   real phone.
8. **The first CI run** on GitHub Actions for both repositories.
9. **Bot protection** decision (control 12, medium).
10. **The independent assessment** (10.4) on the release candidate — the gate cannot be marked PASS by this or any
    self-review.

---

## 13. Reconciliation on the release candidate (2026-10-03)

The run of §11 was made on backend `ae64de8`→`da0d340`. Twelve backend commits have landed since (the report documents, loans, sales, account
deletion, the business day, the deploy scripts, the closing, purchasing, the 30 Sep audit's D1–D5) — by this document's
own rule that **invalidates the previous pass** (money and authentication changed). This section re-checks every
control against the release candidate — backend **`1434aa7`**, mobile **`3023bd3`** — and says what kind of evidence
stands behind it now. Record of the work: `docs/67`.

Classes: **A** implemented and proven by automated tests in the repository · **B** implemented, proven by a manual or
rehearsal run recorded in the docs, no automated test · **C** coded or configured, unproven where it matters
(production) · **D** an external prerequisite (an account, a person, a service, a decision) · **E** not implemented or
the evidence is missing.

| # | Control | Class now | What changed or was found |
|---|---|---|---|
| 1 | Secrets out of client bundles | B | `scripts/verify-release-config.js` has no test of its own |
| 2 | Full-history secret scan | B | CI has never run. §1.5's "`git log --all -- .env*` is empty" is literally false: example files (`.env*.example`) appear in 7 commits; no real `.env` was ever committed |
| 3 | Database identities, least privilege | **B, re-proven** | The committed `deploy/mysql-identities.sql` **could not run** (`IDENTIFIED BY @var`) and left a `placeholder` password — so §11's "created by `deploy/mysql-identities.sql`" cannot have been the committed script. Fixed (`867133e`); the verifier's trigger probes passed on a missing grant — fixed (`1434aa7`). **Re-run 2026-10-03 on the rehearsal copy: 20 of 20**, the append-only triggers refusing the application account |
| 4 | Tenant scoping | E (module suite) / A (extension) | Unchanged: the per-module adversarial suite does not exist. Real HTTP this phase: another shop's sale, customer, expense, unit and branch refused, nothing disclosed (`docs/67`) |
| 5 | TLS, at rest, field encryption | C | Unchanged |
| 6 | Authentication / authorisation | A | Unchanged. The CI drift step ends in `|| true` and never fails |
| 7 | Default deny | A | The entitlement interceptor fails closed for writes only and has no spec |
| 8 | Allow-lists, server-side money | A | **D5 was cited before it was on the branch**; it is now (`0e5f189`, 6 of 6 over HTTP). New this phase: the purchase cost left `cost.view` through a notification (`c0a00a1`) |
| 9 | Cookies, secure storage, rotation | B | `sessions.service.spec.ts` does not exercise `rotate()`, which has no compare-and-swap; the web build keeps tokens in `localStorage` (web only) |
| 10 | Hashing, recovery | A | Unchanged |
| 11 | Rate limits | B | No automated test produces a 429 |
| 12 | Bot protection | E | Unchanged (FAIL, medium) |
| 13 | Raw SQL | B | One more tagged-template file (`business-day.service.ts`). **A raw query failed MySQL's default `ONLY_FULL_GROUP_BY`** (the Daily closing, Money's movements, the daily PDF) — fixed (`084f738`); every GET route clean under the default `sql_mode` |
| 14 | Input limits | B | Imports accept 10 MB, not 8; D3 (malformed ids) on the branch since `ede48c0` |
| 15 | Output escaping | A | The report PDFs' HTML escaping is tested in the app (`lib/report-pdf-html.test.ts`) |
| 16 | Uploads | **E (overstated)** | Stock imports are still typed by file name (`src/imports/sheet-reader.ts`); expense receipt photos are stored and served — "never stored or served" is false |
| 17 | Minimal DTOs | A | Unchanged |
| 18 | Security headers | C | Unchanged |
| 19 | HTTPS required | C | The `eas.json` production profile names no API origin; set it in EAS |
| 20 | Dependency scan | E | Unchanged; the first CI run will fail on `npm audit` until triage |
| 8.3 | Logs redact personal data | **B (overstated)** | Request paths and the error handler keep full IMEIs (`/units/<imei>`, `?search=<imei>`, the error's `identifier` field). `docs/64` accepts request paths; the error field goes beyond it — D120 (`docs/67` §4.5) |
| — | Audit chain | B | Re-proven on the rehearsal: 1 195 rows sealed, 10 of 10 companies OK, rows written by the old and the new API chained |
| — | Backups and restore drill | **B, re-proven** | The drill script passed a corrupted copy and a probe refused for want of a grant — fixed (`867133e`); re-run 2026-10-03: every table by CHECKSUM, trigger bodies identical (`docs/22` E.3) |
| — | Account deletion | A (code) / **D (production)** | In production no code can be sent: refused honestly up front since `56bddbe`; completing a deletion needs D116 (`docs/67` §4.1) |

**The ten blockers of §12, now** — still none clearable by a session: 1 WhatsApp (D) · 2 D110, superseded by D116 (D) ·
3 hosting and secrets (D; the code side C) — add for a hosted MySQL: `log_bin_trust_function_creators=1` before any
migration or restore that creates triggers, and an explicit `connection_limit` · 4 dependency triage (E) · 5 the module
tenant suite (E) · 6 retention and incident response (D) · 7 Apple (D) — plus a **privacy policy URL and in-app link**,
the **payment model** (D118) and **registration in production** (D117), `docs/67` RC-02, RC-03, RC-08, RC-09 · 8 the
first CI run (C) · 9 bot protection (D) · 10 the independent assessment (D).

**Verdict: NOT PASS.**

---

## What "done" looks like

- Every section above has evidence attached, produced on one release-candidate
  build.
- No critical or high finding remains open.
- The evidence, ratings and dates are recorded in this document and summarised in
  `CURRENT_HANDOFF.md`.
- The gate is re-run after any change to authentication, authorisation, money
  handling or public exposure — those four invalidate a previous pass.

---

## 14. Reconciliation after the subscription separation (2026-10-05)

Backend **`7283844`**, mobile **`6f6ef47`** (`docs/21`, 2026-10-05; `docs/68`). Authentication and public exposure
changed, so by this document's own rule the previous pass is invalidated for the controls below; the rest of §13 stands.

| # | Control | Class now | What changed |
|---|---|---|---|
| 6 / 7 | Authorisation, default deny | A | The entitlement allow-list gains `DELETE devices/:deviceId` and `DELETE devices/users/:userId/:deviceId` (revoking removes authority, like `logout-all`); `POST devices/adopt` stays blocked. Pinned by name in `entitlement-rules.spec.ts`; proven over HTTP (read-only shop: revoke passes the gate, adopt refused with `ENTITLEMENT_WRITE_BLOCKED`) |
| 11 | Rate limits, enumeration | B | `POST platform/register` refuses with `503 registration_unavailable` **before any row is written** when no code can leave the server (production mode: 3 companies → 3) |
| 17 | Minimal DTOs / exposure | A, **narrowed** | `GET platform/quote/:id` (public; a business's size and price for anyone holding its id) is removed; the boundary spec asserts no public handler reaches billing |
| — | Platform realm | A, re-proven | Over HTTP in production mode: the administrator cookie admitted, a bearer refused (401); the tenant JWT refused on every administrator route; the administrator session refused on every customer route (`account/*`, `entitlement`) |
| — | Payment instructions | **A (new)** | No stand-in is ever served (`available: false`, no provider, no code); `assertPaymentInstructionsSafeForProduction()` runs at boot and refuses to offer a placeholder; tested |
| — | Client bundle | B | The customer bundle carries no console, registration, price, purchase or renewal wording, commercial route or address of ours (the exported-bundle audit, 15 of 15; `lib/access-boundary.test.ts`) |

**The ten blockers of §12, now:** 7 (Apple) — the payment model is **decided** (D118: business accounts only) and
self-registration is **hidden and refused** (D117); the privacy policy URL, the demo business for review, export
compliance and the device run remain. Everything else unchanged. **Verdict: NOT PASS** (unchanged — the external
prerequisites and the independent assessment stand).
