# 88 — Retention and deletion matrix

> Status: factual, 2026-10-16, CLAUDE-B. What the code keeps, for how long, and what deletion does to it, per category
> of docs/86. **No time-based retention exists anywhere (finding F12): nothing is purged on a schedule.** The legal
> retention period for business records is undecided (blocker `retention_period`); backup retention is undecided
> (blocker `backup_retention`). Account deletion is immediate once confirmed, and cannot complete in production today
> because its only channel, WhatsApp, is not enabled (blocker O-A7 / F01).

Changes made in this phase (backend `dc53129`): closure now clears payer numbers and request hashes on payments and
redacts money-service request hashes (F03); a business closure de-identifies its earlier deleted logins (F11); a
login's deletion no longer reaches another business's registration attempts (F04); a completed request forgets its IP
(F07); the closing notice goes only to a verified number (F17). The mobile app no longer reports a deletion as done on
a lost answer (mobile `b6adc48`).

| Category | Retention and deletion (from the code) | In backups |
| --- | --- | --- |
| Staff, Manager and Owner names and sign-in handles | Staff-login deletion: name -> 'Deleted user', login -> 'deleted-<hex id>', personalId regenerated (account-deletion.service.ts:661-676). Business closure: same for every user with deletedAt NULL; users already soft-deleted (cancelled invitations) keep their name. Copies NOT removed: audit_logs JSON (names recorded by customers/staff/user-management audits), subscription_events.note ('Additional seat ... for <name>'), seat_allocations.reason ('Requested when <name> was added'), platform_audit_events.after_state.owner, append-only agent_positions/agent_rebalancings/agent_provider_configs.recorded_by_name, notifications addressed to OTHER users whose body/payload names the actor (personal-login only; closure deletes all notifications). No time-based purge. | yes (full mysqldump of the database) |
| Email addresses (users, applicants, contact-verification destinations) | Staff deletion: users.email nulled; contact_verifications rows whose destination equals the email deleted (globally, not company-scoped); registration_attempts with that email de-identified (globally, all companies); seat_allocations requested/confirmed/closed_by equal to the email replaced in this company. Closure: same for all active users + registration_attempts of the company. Kept: subscription_events.actor if the Owner cancelled a staff invitation (staff-invitation.service.ts:337 -> seat-allocation.service.ts:1578), contact_verifications for contacts no longer on the user row (old/changed address, cancelled invitees). No purge. | yes |
| WhatsApp / phone numbers of users and applicants | Staff deletion: users.phone nulled; every otp_challenges.destination of the person -> '[deleted]', candidate_phone nulled; contact_verifications for the number deleted; registration_attempts de-identified (global). Closure: every otp_challenge of the company redacted. Kept: account_deletion_requests.destination_masked ('+222***NN'), masked numbers inside append-only audit_logs. No purge. | yes |
| Contact-verification and activation state | Deletion nulls emailVerifiedAt/phoneVerifiedAt, sets isActive=false, deletedAt=now. contact_verifications rows for the person's current contacts are deleted; others stay. No purge. | yes |
| Password, PIN and credential hashes | Deletion: passwordHash -> '$deleted$' (unverifiable), pinHash nulled, sessions/devices revoked (hashes kept on revoked rows), verification intents deleted, owner invitations revoked. No purge of expired sessions or intents (purgeExpired never called). | yes (hashes only) |
| Verification challenges (OTP, contact codes, continuations, deletion challenges) | Codes: HMAC-SHA256 with OTP_PEPPER (+challenge id or destination); OTP TTL 300 s default, 5 attempts, 60 s resend cooldown; contact codes 10 min, 6 attempts, 5/hour. Deletion: person's pending challenges cancelled, all destinations '[deleted]', intents deleted, contact_verifications for current contacts deleted. Closure: every challenge of the company redacted. Rows otherwise kept forever (expireOverdue/purgeExpired never scheduled). | yes (hashes; full destinations until redacted) |
| Sessions, refresh tokens and devices | Deletion: all sessions revoked and ip/userAgent/deviceName/deviceId nulled; devices revoked and label/model nulled (platform/appVersion kept); sync_devices deleted with their outbox rows. Closure: same for every session/device of the company. Platform admin sessions never deleted. No purge of expired sessions. | yes |
| IP addresses, user agents and security/technical logs | Deletion nulls auth_sessions ip/UA, but account_deletion_requests.request_ip is kept on the completed request forever; platform audit IPs append-only. Logs: never edited by the app; retention not set in code. | DB fields yes; logs no |
| Company and store information | Staff deletion: nothing. Closure: branches deactivated and address/phone nulled; company is_active=false, closed_at set, public_phone/logo_ref/city nulled, is_discoverable=false; company name, branch names and registration_attempts.business_name KEPT. No code path writes publicPhone/isDiscoverable/logoRef today (only reads). No purge. | yes |
| Staff invitations, role assignments and delegations | Deletion: assignments kept (user row de-identified); unaccepted owner invitations revoked; seat_allocations requested/confirmed/closed_by matching the person's contacts replaced with 'Deleted user' (reason text naming the person kept). Cancelled invitations: user soft-deleted, contacts nulled, name kept. No purge. | yes |
| Customers (names, phones, notes, balances) | Staff deletion: nothing. Closure: name, phone and notes nulled for every customer (balance and sales kept). Kept: customer names in audit_logs (create audit stores name; phone only as 'set'). No purge. | yes |
| Payer / sender phone or account numbers on non-cash payments | Staff deletion: nothing. Closure: payer_number nulled for every payment. NOT removed: payments.client_request_hash (unsalted SHA-256 over saleId, amount, method, account, paidAt minute, reference, note and the payer number) - the number is recoverable by brute force from the retained row. No purge. | yes |
| Suppliers | Closure: phone and notes nulled; name KEPT (may be a natural person). No purge. | yes |
| Counterparties (people and stores lent to, consigned to, or employed) | Staff deletion: the counterparty that IS the person -> 'Deleted user', phone/city/note nulled. Closure: manual_person/employee -> 'Deleted user' + phone/city/note nulled; manual_store/connected_store keep name, lose phone/note. Kept: counterparty names in audit_logs (connections.service.ts:700, loans.service.ts:131); store_connections notes. No purge. | yes |
| Products, serial numbers, IMEI1, IMEI2, TAC | Never removed by staff deletion or closure (IMEIs of devices sold to customers remain). No purge. | yes |
| Sales and payment channels | Retained in full on staff deletion and closure (legal retention); payments.note/reference free text kept. No purge. | yes |
| Expenses (incl. salaries) | Closure: note and receipt_key nulled; everything else kept. Staff deletion: nothing. Expenses cannot be deleted (trigger). | yes |
| Receipt photos | Replaced file deleted on re-upload. Closure: keys nulled in the transaction, files deleted after commit (failure logged by count only). Staff deletion: kept. Not in deploy/backup-encrypted.sh (database only). No purge. | no (backup script dumps MySQL only) |
| Returns and refunds | Kept in full on deletion/closure, free-text notes included; reversals append-only. No purge. | yes |
| Opening/closing amounts, discrepancies and employee debts | Kept on deletion and closure (employee debt entries naming the person kept and counted in retained summary). No purge. | yes |
| Receiving accounts (Bankily, Sedad, BIM Bank, other) | Kept. No account number, PIN, password, token or balance column exists (free-text label could contain one). | yes |
| Money-services exchanges and customer numbers | Staff deletion: recordedByName/reversedByName on exchanges and mistake reports -> 'Deleted user'. Closure: customer_number and last4 set to '' on every exchange; mistake-report notes nulled. NOT removed: client_request_hash (number brute-forceable from the retained amount/provider/reference/deviceRecordedAt), provider_reference, rebalancing notes, names on append-only positions/rebalancings/config versions. No purge. | yes |
| Manually entered commissions | Kept (immutable by trigger). | yes |
| Employee attribution and performance | Foreign keys kept; they resolve to the de-identified 'Deleted user' row. No purge. | yes |
| Loans, consignments and stock transfers | Kept in full on deletion and closure, free text included (ledger triggers block updates). No purge. | yes |
| Uploaded stock/import files and receiving files | Never removed: not touched by staff deletion or closure; raw rows may contain any column the shop's spreadsheet had (e.g. supplier or customer names/numbers). No purge. | yes (rows; files never stored) |
| Audit events (hash-chained, append-only) | Never edited or deleted (listed in notRemoved). New rows store contacts only as 'set' and masked OTP destinations, but still store customer names, staff names, counterparty names, branch names; rows from before 2026-10-12 may hold full contacts. No purge. | yes |
| In-app notifications | Staff deletion: only notifications TARGETED at the person deleted; broadcasts and others' notifications naming the person kept. Closure: all of the company's notifications deleted. No purge. | yes |
| Support requests | n/a | n/a |
| Account-deletion requests and records | Kept forever, including request_ip and masked destination; retained_summary holds counts only. No purge. | yes |
| Trial, subscription, seat and store requests, subscription payments | Closure: subscription cancelled with an event, trial eligibility closed, setup links revoked; all history kept. subscription_events never edited (notes may name staff; actor may hold an Owner email on the staff-cancel path). No purge. | yes |
| Registrations / applications | Staff deletion: every registration row (any company) whose email/phone matches the person -> ownerName 'Deleted user', email/phone null. Closure: the company's rows -> ownerName 'Deleted user', email/phone/city null; businessName kept. No purge. | yes |
| Platform administrators | TOTP secret sealed AES-256-GCM under PLATFORM_MFA_KEY; recovery codes HMAC digests; no admin deletion flow; audit kept forever. No purge. | yes |
| Owner messaging preferences and outbound message metadata | Kept; provider message ids are not removed by deletion. No purge. | yes |
| Offline sync outbox | Staff deletion: rows of the person's sync devices deleted. Closure: all deleted. No purge otherwise. | yes |
| Diagnostics / crash information | Not controlled by code. | no |

## Not removed by any deletion (open findings, docs/85 §5)

| Finding | What stays |
| --- | --- |
| F05, F06 | Owner contact and staff names written into append-only subscription events, seat reasons and audit JSON |
| F08 | On a closure: notes and reasons on payments, refunds, returns, closings, loans, consignments, ledgers, discounts, goals, transfers and corrections; supplier, company and branch names. The website and the app now say so |
| F09 | Imported spreadsheet rows, cell by cell, never de-identified |
| F10 | A deleted employee's name in notifications sent to others. The website now says so |
| F12 | Expired codes, ended sessions, anomalies, logs: no purge |
| F13 | EXIF metadata (possibly GPS) inside receipt photos, until the business closes |
| F14 | Receipt files are not in the database backup at all (an operations gap, not a retention) |
| F15 | Request logs: IP, user agent and IMEIs or serials in URL paths — retention is the hosting log's |
| M-DEL-3 | On the phone after deletion: the offline queue file, drafts, sealed customer numbers, cached receipt PDFs and picked files (docs/86 §2) |
