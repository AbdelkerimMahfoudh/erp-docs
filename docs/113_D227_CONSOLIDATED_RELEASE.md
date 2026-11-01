# 113 — D227, the consolidated release: design and progress

Decisions: `docs/21` D227. This file holds the design, the evidence as it arrives, and the physical-iPhone checklist.

## 1. Status at this writing

**Done and pushed (not deployed):**
- Optional Arabic names, backend only: backend `0a05063`. The console and mobile still validate and warn the old way.
- Goals dormant: backend `8f1dcec`; removed from the app: mobile `cd3f4d9`, `bd191f4`.
  - Mobile jest 59 suites / 507 tests passed before the last pure-test patches; those patched files passed alone.
  - The full pure suite and backend suite have not been rerun on these heads.

**Nothing else in D227 has started in code.** No migration, deployment or build.

## 2. Design settled from reading the code

**Owner identity (migration 0116).**
- `users` is unique only per company. New table `owner_identities`: kind (phone/email), canonical value, company, user;
  UNIQUE(kind, value). Claimed inside the registration transaction, so the database decides a race.
- Production today has one phone on 3 businesses and one on 2 (test and owner businesses). Backfill claims each value for
  its oldest Owner; the others keep working. Nothing is rejected retroactively.
- Rows must be released on account deletion and moved on a contact change. Staff are never in the table.

**Public registration, non-enumerating.**
- Duplicate phone: same response shape, same code sent to that phone. Only after the correct code does the answer say to
  sign in and add a store. Someone without the phone learns nothing. Needs a small hold record, because no company or user
  exists to attach a verification intent to.
- Duplicate email: phone is the proven contact and email is optional, so the email is dropped silently. Limitation: an
  Owner using a new phone and their old email gets a second business, because nothing proves the email at that moment.

**Admin.** Authenticated, so it may see an existing Owner: `existing_owner` refusal plus the explicit audited add-store
route. `CreateBusinessDto` gains a required access basis (payment / grant), reusing `SubscriptionLifecycleService`
`recordPayment` + `approve`, and the grant path. `grantStore` is test-only today; add-store generalises it to "covered by
access in force", else the same basis.

**Sign-in.** `auth.service` `choose_account` already names businesses only after the password. Business → stores comes
after it; never before.

**Security and sign-in.** `OtpService` is reusable: hashed, single use, attempt lock, send limits, conditional update.
- New purposes in both enums (as 0114 did): password change, contact-change authorisation, new-contact proof.
- A `contact_changes` row binds the pending value to both challenges; the final swap is one transaction, including
  `owner_identities`, consent `supersede`/`activatePending`, and session revocation.
- Email channel: `disabled` in production. Provider code exists (`smtp`, Brevo, D181). Flow stays guarded until configured
  and proven; to be identified precisely at the release gate.

**Maintenance.**
- `maintenance.record` uses `user_branch_permissions` with `isDelegatable`, so no new role. Add to the role matrix and its
  drift specs.
- New table with `client_uuid` + request hash, as `expenses` does (unique key, replay, 409 on another payload).
- Money enters one equation: add `maintenanceIn` (+) and `maintenanceOut` (−) to `COMPONENT_SIGN` in `closing/channels.ts`,
  then `INFLOW` in `money-positions.ts`, the closing's expected cash, the rollup (new columns, requested in the same
  transaction per 0081), `period-figures`, reports and exports. Sale columns stay untouched.
- The owner decided (2026-11-01): the form asks where the repair cost left from, required when the cost is above zero;
  it may differ from where the customer's payment went.
- Corrections: a new target in `corrections/correction-targets.ts`, posting reversing legs.

**Money tracking.** `money_anchors` and accounts are per business, the switch is per store. New per-store setting table,
default OFF, with its opening snapshot. `trackedMoney` must hide positions for OFF methods. The drawer stays counted at
closing either way. Goal: no history rewritten.

## 3. Exact next steps

1. Migration 0116 and the owner-identity service; registration hold; tests first; real MySQL.
2. Access basis and add-store. 3. Security and sign-in. 4. Maintenance. 5. Money tracking. 6. Transfer auto-send.
7. Correlation IDs. 8. Rehearse from the production schema. 9. Mobile. 10. Console. 11. Gates. 12. Release.

`goal.manage` stays in the backend catalogue, inert, because its rows and drift specs come from migration 0047. Mobile
no longer lists it.
