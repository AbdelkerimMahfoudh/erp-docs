# 48 — Pre-release security gate

> **This is a release blocker, not an improvement.** No public application, no
> portal and no production API may be published while any item below is
> unresolved at **critical** or **high**. Passing functional tests is not
> evidence for this gate: 2 370 green backend tests say the shop works, not that
> it is safe to expose to the internet.

**Status: NOT STARTED.** Recorded as a milestone so it cannot be forgotten, and
deliberately **not** implemented during the current UI checkpoints — a security
audit interleaved with interface work gets neither done properly.

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

## 1. Secrets

| # | Check | Evidence required |
|---|---|---|
| 1.1 | No secret in any source, mobile bundle or web bundle | Grep of built artefacts, not only of source |
| 1.2 | **Full Git history** scanned in all repositories | Scanner run over every ref, not just `HEAD` |
| 1.3 | Every exposed credential rotated, old one proved dead | A refused request using the retired credential |
| 1.4 | No database credential reachable by any client | Bundle inspection; the app talks only to the API |
| 1.5 | Server configuration loaded from environment, never committed | `.env` absent from every commit in history |

One precedent is already recorded (`G2A-CP4.5`: session tokens written into
`mobile/public/` and committed). That is the failure mode this section exists
for, and it is why scratch files must never be created inside a repository.

## 2. Database accounts and least privilege

| # | Check | Evidence required |
|---|---|---|
| 2.1 | The application account cannot `DROP`, `ALTER` or read other schemas | Refused statements, run as that account |
| 2.2 | The migration account is separate and used only by migrations | Grant listing per account |
| 2.3 | The backup account is read-only | Refused write, run as that account |
| 2.4 | Administrative access is not shared with the application | Named accounts, with an owner each |
| 2.5 | Audit append-only triggers hold **as the application account** | An `UPDATE`/`DELETE` on `audit_logs` refused as that account |

2.5 is explicitly open today: every isolated verification so far ran as the
migrator, so the trigger was present but never exercised as the application user.

## 3. Authorisation and tenant isolation

| # | Check | Evidence required |
|---|---|---|
| 3.1 | Every endpoint declares a permission, or documents why it is open | Route inventory with its guard |
| 3.2 | Adversarial cross-company tests: company A cannot read, write or reference company B | Failing-by-design tests, per module |
| 3.3 | Branch scoping cannot be widened by omitting or forging `X-Branch-Id` | Requests without, and with somebody else's, branch id |
| 3.4 | A retired role's grants are actually revoked | Precedent: `branch_manager` kept `discount.override` in the database after code removed it |
| 3.5 | Delegated grants cannot exceed the delegatable set | A grant of a non-delegatable key has no effect |

## 4. Input handling

| # | Check | Evidence required |
|---|---|---|
| 4.1 | DTO allow-lists everywhere; unknown fields rejected, never absorbed | Mass-assignment attempt per write endpoint |
| 4.2 | No client-supplied money, cost, margin or status is trusted | Field-tampering attempts on sale, return, transfer, consignment, loan |
| 4.3 | Server-side validation of every field, with size limits | Oversized body, oversized field, deep JSON |
| 4.4 | Parameterised database access; every raw query audited | Inventory of raw SQL with justification |

## 5. Authentication

| # | Check | Evidence required |
|---|---|---|
| 5.1 | Password hashing is current and correctly parameterised | Algorithm, cost factor, and a verification test |
| 5.2 | Recovery cannot enumerate accounts or be replayed | Identical responses; single-use, expiring tokens |
| 5.3 | Login, reset and OTP are throttled, with risk-based anti-automation | Rate-limit tests, including distributed attempts |
| 5.4 | Mobile tokens in secure device storage; refresh rotation is safe | Device inspection; replay of a rotated token refused |
| 5.5 | Web cookies are `HttpOnly`, `Secure`, `SameSite`; CSRF defended | Response headers and a cross-site attempt |

## 6. Output and files

| # | Check | Evidence required |
|---|---|---|
| 6.1 | Context-aware escaping for HTML, PDF and CSV | Injection strings rendered in each format |
| 6.2 | CSV formula armouring (`=`, `+`, `-`, `@`) without corrupting negatives | Spreadsheet opened, values intact |
| 6.3 | Uploads are private, type-checked and size-limited | Direct-URL access refused |
| 6.4 | API responses carry only what the caller may see | Response diff per role — cost, margin and other companies' data absent |

## 7. Transport and platform

| # | Check | Evidence required |
|---|---|---|
| 7.1 | Production API and portal are HTTPS-only, with HSTS | Redirect and header capture |
| 7.2 | Security headers and a real CSP on the portal | Header capture; CSP without `unsafe-inline` |
| 7.3 | Dependency and lockfile scanning, with a triage record | Scanner output; 17 backend / 18 mobile advisories are already recorded and unbumped |
| 7.4 | Error responses leak no stack trace, SQL or internal path | Production-mode error capture |

## 8. Data protection and operations

| # | Check | Evidence required |
|---|---|---|
| 8.1 | Backups encrypted at rest and **restore-tested** | A restore drill, dated |
| 8.2 | Off-machine backup copies exist | Location recorded; today dumps are local-only |
| 8.3 | Logs redact tokens, passwords and personal data | Log sample from a real request |
| 8.4 | Monitoring and an incident-response procedure exist | Who is called, and what they do |
| 8.5 | Privacy, retention, and company/account closure are defined and implemented | Deletion/export request walked end to end |

## 9. Business logic under attack

| # | Check | Evidence required |
|---|---|---|
| 9.1 | Race conditions on stock, transfers, consignments and payments | Concurrent attempts; one winner, no double movement |
| 9.2 | Replay and idempotency across every write with a client key | Same key twice; different payload under one key refused |
| 9.3 | Approval workflows cannot be self-approved or bypassed | Attempts as each side of the deal |
| 9.4 | Financial corrections cannot create money | Reversal arithmetic proved, with audit |

## 10. Release review

| # | Check | Evidence required |
|---|---|---|
| 10.1 | OWASP **ASVS** review at the agreed level | Completed checklist with per-item evidence |
| 10.2 | OWASP **API Security Top 10** review | Same |
| 10.3 | OWASP **MASVS** review for the mobile app | Same |
| 10.4 | Targeted penetration test of an isolated, production-like release candidate | Report, with findings rated and closed |

---

## What "done" looks like

- Every section above has evidence attached, produced on one release-candidate
  build.
- No critical or high finding remains open.
- The evidence, ratings and dates are recorded in this document and summarised in
  `CURRENT_HANDOFF.md`.
- The gate is re-run after any change to authentication, authorisation, money
  handling or public exposure — those four invalidate a previous pass.
