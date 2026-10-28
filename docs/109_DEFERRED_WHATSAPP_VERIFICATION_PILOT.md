# 109 — Admin-provisioned accounts with deferred WhatsApp verification, and the TestFlight store pilot

Status: **PLAN, approved for implementation by the owner (2026-10-28). Not deployed.** Decision D224 in `docs/21`.

## 0. Why

A real electronics store will run on Dukan ERP for 3–7 days through TestFlight. Several staff will work at the same time
on their own iPhones, each with:

- their own account;
- the right role;
- their own audit identity.

Today every staff account becomes usable only when its WhatsApp number is verified (`staff-activation-rules.ts`:
`phone_verification`), and the WhatsApp Business API is not live. Sharing the Owner's account is refused. The owner
approved a narrow, audited exception, which must never be mistaken for verification.

## 1. The owner's decision on the Test flag (2026-10-28)

Deferred verification is allowed **only for a Test business**, as the brief requires. A Test business today:

- shows "Test business — for testing only, not a real shop" on every screen;
- is excluded from the platform's commercial dashboard;
- can never pay;
- connects only to other Test businesses;
- can never be un-marked once in use.

None of this touches receiving, stock, sales, in-store payments, receipts, returns or closing: no such code path reads
the flag.

The banner would be inaccurate for a real store. The owner chose **"Test + pilot banner"**:

- a **pilot sub-mark** on a Test business (`companies.is_pilot`, allowed only while `is_test`) changes the banner to
  "Pilot business — controlled test of Dukan ERP";
- every other Test rule is unchanged;
- after the pilot, the store's normal use is a new customer business, and the pilot data stays, audited, in the Test
  business.

## 2. Design

### 2.1 Account state (migration 0109)

`users.phone_verification`, VARCHAR(24) NOT NULL, takes one of three values:

- `required` — the default;
- `deferred_by_platform`;
- `verified`.

**The database enforces it:**

- A CHECK: `(phone_verification = 'verified') = (phone_verified_at IS NOT NULL)`.
- BEFORE INSERT/UPDATE triggers derive the value from `phone_verified_at`, so every existing write path stays correct
  without being edited:
  - a set timestamp makes the state `verified`;
  - a cleared timestamp turns `verified` back to `required`;
  - a deferred account stays deferred while its timestamp is null.
- The backfill sets `verified` exactly where `phone_verified_at` is set. Nobody else changes.

A deferred account therefore **cannot** be stored as verified, and `phone_verified_at` stays null. Nothing writes a
WhatsApp consent row for it.

**`phone_verification_deferrals`** is the exception's own record. Each row holds:

- who: the user and the company;
- the granting administrator, by id and email;
- the reason, up to 500 characters;
- an optional review date;
- when it was granted;
- when it ended, by whom and why: `required`, `verified` or `cancelled`.

At most one deferral is live per user, enforced by a UNIQUE generated column, the pattern `staff_invitations` already
uses.

**`companies.is_pilot`**, BOOLEAN with a CHECK `is_pilot = 0 OR is_test = 1`.

### 2.2 Setup references

**`account_setup_codes`** is a one-time reference with which a platform-provisioned person chooses their own password:

- stored only as an HMAC-SHA256 under `STAFF_INVITATION_KEY`, in its own purpose domain, so no new production secret
  is needed;
- valid for 72 hours, single use, claimed atomically by its own unspent state;
- one live code per person; reissuing revokes the previous one;
- refused with one generic error for every failure;
- audited at issue, reissue, use, expiry and revocation.

The administrator never sets or sees the password.

**Redemption** goes through the existing doors, so the app needs no new screen:

- `auth/owner-setup` in the app, and the website's accept route;
- each tries an Owner invitation, then an account setup code;
- both share the same throttle and the same refusal.

**Activation.** Redeeming the code sets the password and revokes earlier sessions. For staff it then runs the existing
activation (`activateIfReady`) behind the subscription lock, so seat rules still apply.

### 2.3 Who may defer: every condition enforced on the server

`DeferralPolicy.assertMayDefer` refuses, and audits the refusal, unless **all** of these hold:

1. **A superadmin with MFA:** a `PlatformAdminGuard` session with its second factor verified, and the administrator's
   MFA enabled.
2. **A fresh step-up:** password plus code (`confirmPassword` / `stepUpAt` ≤ 5 min), the existing mechanism.
3. **The protected portal routes:** under `platform/`, which the app's boundary test bans and tenant guards never reach.
4. **A Test business:** the target business has `is_test`.
5. **The kill switch is on:** the server flag `PHONE_VERIFICATION_DEFERRAL_ENABLED` is true. It defaults to false, so
   production stays off until the pilot.

**Request fields:**

- `verification` is accepted only on those platform DTOs.
- Public registration and every tenant (Owner, Manager or Employee) DTO have no such field, and the global
  `whitelist` + `forbidNonWhitelisted` pipe rejects one if sent.
- A deferral also requires:
  - a written reason;
  - `confirmControlledTest: true`;
  - an optional review date (future, at most 90 days ahead);
  - for staff, a role (`store_manager` or `store_employee`) and branch assignments.

### 2.4 Portal (erp-control-web)

**Creating a business:** the "Create a business" form, for a Test business, gains a **WhatsApp verification** field:

- **Required before activation**, selected by default;
- **Deferred for testing**.

Choosing Deferred reveals:

- the reason;
- the controlled-test confirmation;
- the review date;
- the warning, in the brief's own words.

**The business detail page, for a Test business:**

- **Add test staff:**
  - name, unique WhatsApp number, optional email;
  - Manager or Employee;
  - stores;
  - the verification policy, reason and review date.
- **Deferred accounts:**
  - who granted the deferral, when and why;
  - change it to Required;
  - edit the reason or review date;
  - reissue or revoke the setup code;
  - cancel the account.

There is never a "mark verified" control.

**Elsewhere in the portal:**

- the businesses list filters "has deferred verification";
- the field is absent when the kill switch is off. The server answers this through
  `platform/capabilities.phoneVerificationDeferral`.

### 2.5 Lifecycle

**Changing deferred to required:**

- the deferral row ends with `required`;
- the state becomes `required`;
- nothing is sent.

The person verifies later through the normal app flow, and that flow sets `phone_verified_at`. The trigger then makes
the state `verified`, and the live deferral ends with `verified`, an audited outcome.

**Cancelling an account** uses the existing cancellation. It revokes setup codes and ends the deferral with `cancelled`.

**Switching the kill switch off:**

- the option disappears from the portal;
- the API refuses new deferrals;
- existing deferred accounts stay `deferred_by_platform`, listed and identifiable;
- nobody is verified or deleted.

### 2.6 What a deferred account can and cannot do

**It can:** sign in after redeeming its code, and do all the work its role and stores allow.

**It cannot** do anything that already requires `phone && phone_verified_at`, because the value is null:

- WhatsApp notices;
- closing notices;
- account deletion by WhatsApp;
- WhatsApp recovery;
- trial WhatsApp channels.

**How it is shown:**

- `/auth/me` and the account API say `phoneVerification: "deferred_by_platform"`;
- the app's Account screen says "WhatsApp verification deferred for testing";
- portal lists, exports and audit records say "Deferred", never "Verified".

### 2.7 Audit (`platform_audit_events`; `audit_logs` for tenant-side transitions)

**Outcomes recorded:**

- `account.create` with `verification: required | deferred_by_platform`;
- `phone_verification.defer.refused`, with the failed condition;
- `account_setup_code.issue`, `.reissue`, `.use`, `.expire` (seen at redemption) and `.revoke`;
- `phone_verification.require`;
- `phone_verification.deferral_update`, for the reason or the date;
- `account.cancel`;
- `phone_verification.verified`, from the user's own flow.

**Each record carries:**

- the actor and the target person;
- the business, the role and the stores;
- the reason and the outcome;
- the time.

**Never recorded:** a password, a code, an MFA value or a full secret. The existing `redact()` strips them as well.

## 3. Files

**erp-backend:**

- `prisma/migrations/0109_deferred_phone_verification/` and `schema.prisma`;
- `src/platform/`:
  - `deferral-policy.ts`, new;
  - `account-setup-code.service.ts`, new;
  - `test-provisioning.service.ts`, new: staff creation and the deferral lifecycle;
  - `platform.controller.ts`, for the routes, the DTOs, the capability and the filter;
  - `provisioning.service.ts`, for the status;
  - `registration.service.ts`, for the Owner's verification policy;
  - `staff-activation-rules.ts`, which treats a deferral as satisfying `phone_verification`;
  - `app-owner-setup.controller.ts` and the web accept route;
- `src/common/config/`, for the kill switch;
- `src/auth/`, for `isPilotBusiness` and `phoneVerification` on `/auth/me`;
- `src/account/account.service.ts`, for `phoneVerification`;
- specs, a real-MySQL spec and the deploy preflight (the variable).

**erp-control-web:**

- `src/pages/admin/Business.tsx`, `Businesses.tsx` and the create form;
- the API types;
- i18n;
- unit and e2e tests.

**erp-mobile:**

- `TestBusinessBanner` (pilot wording);
- the Account row;
- EN/FR/AR;
- tests.

## 4. Risks

| Risk | Mitigation |
| --- | --- |
| A deferred account passes as verified | DB CHECK + triggers; `phone_verified_at` untouched; a test for every API and list |
| The option leaks to tenants or registration | the field exists only on platform DTOs; whitelist pipe; tests that post it to every public and tenant route |
| Weakened seats or roles | activation still runs `activateIfReady` under the subscription lock; deferral replaces only `phone_verification` |
| Double-spend of a setup code | atomic `updateMany` claim; real-MySQL concurrency test |
| Triggers on `users` | `DEFINER` stripped as for 0088's triggers; rehearsed on a copy of production's schema |
| Pilot data in a Test business | the owner's decision (§1), recorded in D224 |
| Kill switch left on | defaults off; enabled for the pilot only; the end-of-pilot checklist turns it off |

## 5. Migration rehearsal (before production)

1. Restore production's latest encrypted backup into a disposable database.
2. Apply 0103 → 0109 in order.
3. Verify the schema, triggers, CHECKs and the backfill (`verified` count = `phone_verified_at` count).
4. Run the real-MySQL specs and journeys there.
5. Record the outcome in §8.

## 6. Verification required before deployment

- the brief's test list, as backend unit and real-MySQL specs;
- portal unit and e2e tests;
- mobile tests;
- CI green on the exact final commits.

## 7. Pilot operation

The daily checklist, the stop conditions and the rollback procedure are in §9, written before the pilot starts.

## 8. Record

(filled in as the work proceeds)
