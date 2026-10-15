# 76 — The website-only seven-day free trial (2026-10-13)

> **Draft, in progress (2026-10-15).** Sections marked _Filled at the end of the phase_ are not written yet, and the
> review's fixes (§12) and the add-on scheduling (§6.1) are being made now. `CURRENT_HANDOFF.md` is the live state.

This record covers the owner's brief of 2026-10-13 and its customer-discovery addendum, carried out by CLAUDE-B in a
cloud session. The owner made three decisions on the plan, then issued a correction and a clarification the same day.

**Nothing here was deployed, merged to production or applied to a live or shared database.** No message was sent to a
real customer. Migrations `0095` and `0096` were rehearsed only on disposable MySQL databases inside the cloud
container, and every one of them was dropped.

The decisions are **D169–D177** (`21_PRODUCT_DECISIONS.md`). Two review findings await the owner (§16). This file is the
contract as built.

<!-- §1 is filled at the end of the phase with the final commits -->
## 1. Branches and commits

_Filled at the end of the phase._

## 2. What the owner decided

**The brief.** A newly self-registered business may claim **one** free trial. It lasts exactly **seven consecutive
24-hour periods (168 hours)**, measured from the server's instant of the Owner's explicit confirmation **on the
website**.

Claiming it:

- creates no payment, no billing record, no grace period and no renewal;
- needs no Super Admin approval.

When the trial ends, the business becomes **read-only** until paid access starts. Existing businesses get no trial
retroactively.

The customer-discovery addendum shapes how an Owner finds out:

1. The app says, display-only, that the business is eligible.
2. Setup instructions go to the verified contact automatically.
3. The trial itself is started on the website.

| Owner decision (2026-10-13) | Rule |
| --- | --- |
| **Q1** | Business sign-up returns to the mobile app. This **reverses D117**. Creating an account never starts a trial. |
| **Q2** | Businesses created by the Super Admin in the console are **not** trial-eligible. |
| **Q3** | Paid or granted access given while a trial is running starts **when the trial ends**. The trial is never shortened, extended or rewritten. |
| Plan defaults (approved) | No backfill. Required contacts = the contacts given at registration (both given → both verified). No grace after the trial. Fraud is handled by the Super Admin (suspend or refuse). Setup links last 24 h, and a new send revokes older ones. Website resend limits: 60 s, 3 per 15 min, 10 per 24 h. The console's pending queue keeps refuse / suspend / approve. |

### 2.1 The owner's correction (binding)

1. **The mobile app has no trial-related action of any kind.** That excludes:
   - a claim button, a *Resend instructions* or *Send instructions* button, or a button to verification;
   - a website link, a QR code or a WebView;
   - a claim token or a claim API call;
   - a price or a payment instruction.
2. **The app only displays:**
   - that the business is eligible;
   - that the trial has not started;
   - its seven-day duration;
   - whether the instructions were sent;
   - the masked verified destination;
   - an honest status when no provider can deliver.
3. Setup instructions are sent **automatically** after contact verification. Resending happens only after the Owner
   signs in on the **website**, or through support.
4. **No Origin, Referer or "came from the website" check is a security boundary, and none is implemented.**
   "Website-only" means only the website exposes the workflow. The claim is protected by:
   - the authenticated Owner's authority;
   - the verified contacts;
   - eligibility;
   - the one-time token, where one is presented;
   - idempotency;
   - the subscription row lock;
   - the audit.
5. **Trial instants are stored in UTC and shown in the business's configured time zone,** with the zone's name. No zone
   is ever hardcoded, even though Mauritania uses GMT.
6. The exported mobile bundle test must prove every forbidden trial action absent.

### 2.2 The owner's clarification (binding)

**Website sign-in works without the message link.** An eligible Owner who opens the website independently, signs in
normally and has verified the required contacts sees the **same trial card**. That Owner can start the trial after
explicit confirmation, whether the message was lost, the delivery failed, the link expired or was consumed, or the
device changed.

What the token does and does not do:

- It only continues to the right page **after** authentication.
- It never activates anything by being opened.
- Link previews consume nothing.
- An expired or invalid token never removes eligibility.
- Delivery is never a second eligibility requirement.

Every approved block still applies: unverified contacts, Managers, Employees, and suspended, refused, closed, paid or
already-claimed businesses.

**The concurrent identity phase was integrated deliberately** (§13).

## 3. The model — migrations `0095_free_trial` and `0096_trial_link_claimed`

The migrations are additive, with no backfill and reverse SQL in the header. Every instant is written by the
application from the server clock as a UTC value, `created_at` included. None is ever computed by MySQL in a session
time zone.

| Table | Purpose | Guarantees |
| --- | --- | --- |
| `trial_eligibilities` | One row per company, ever. Created only inside the **public self-registration** transaction. Records `registration_method` (`email` / `phone` / `both`). | `UNIQUE(company_id)`. `closed_at` and `closed_reason` are set together, once (`approved`, `granted`, `paid_period`, `refused`, `cancelled`). Triggers refuse a delete and any other change. |
| `trial_claims` | The claim: immutable, one per company, ever. | `UNIQUE(company_id)`. CHECK `started_at = claimed_at` and `ends_at = started_at + INTERVAL 168 HOUR`. The only mutable column is `expiry_recorded_at`, which goes NULL → value once. Triggers refuse a delete and any other update. |
| `trial_setup_links` | Website links, single-purpose and hash only. | SHA-256 of a 256-bit token (`UNIQUE`), plus a binding digest of the Owner's credentials and contacts. Lifetime 24 h. `consumed_at` is set only by the claim. `revoked_reason`: `reissued`, `claimed` (added by 0096), `signed_out_everywhere`, `contact_changed`, `password_changed`, `deleted`, `closed`. |
| `trial_setup_messages` | Append-only log of every send attempt; also the durable throttle. | Per-channel outcome: `accepted`, `failed`, `unavailable` or `not_applicable`. No destination, token or code is stored. Triggers refuse an update and a delete. |

`subscription_events.kind` gains `trial_eligible`, `trial_claimed` and `trial_expired`. Subscriptions keep their
columns and statuses: a claim leaves `status = pending_activation`.

The triggers refuse only the application's database identity, `phonestore_app`, which is the house convention. The
CHECKs bind every account.

## 4. States

`stateOf` gains three computed states. A trial is **facts, not a status**: an eligibility and perhaps a claim.

| Order | Condition | State |
| --- | --- | --- |
| 1 | cancelled, suspended or rejected | that decision (it outranks everything) |
| 2 | a claim with `now < endsAt` | **`trial_active`**: any paid period or grant given during the trial starts at `endsAt` |
| 3 | an open eligibility, no claim, and status pending (or `activated` with no period or grant, which only *reinstate* produces) | **`trial_available`** |
| 4 | pending with a claim | **`trial_expired`** |
| 5 | otherwise | as before (pending, active, grace, expired, complimentary) |

Read and write access per state:

| State | Read | Write | Grace |
| --- | --- | --- | --- |
| `trial_active` | yes | yes | — |
| `trial_available` | no — the closed screen, like pending | no | — |
| `trial_expired` | yes | no | none |

**Boundaries are exact:** at `endsAt − 1 ms` the trial is active; at `endsAt` it has ended.

**The client view** (`TrialView`, inside `GET entitlement`) carries:

- `status` (`available`, `active` or `expired`);
- `durationHours`: 168, and `durationDays`: 7;
- the UTC instants;
- `timeZone`: the business's configured IANA zone. An invalid stored zone is reported as `UTC` and logged; it is never
  replaced by a Mauritanian zone.
- `accessAfterTrial`: `{ kind: 'paid' | 'granted', startsAt }` when access approved during the trial follows it, else
  `null`. This was added in the review round (§12).

Clients render this view and never compute it.

**Expiry is lazy and exact.** At the first evaluation after `endsAt`, `expiry_recorded_at` is set once, and one
`trial_expired` event and one audit row are written. The record never blocks a request: a locked subscription row
means "retry at the next evaluation" (review round).

## 5. The claim — `POST platform/my-subscription/trial/claim`

This is a tenant route with a JWT and no public access. The body is
`{ idempotencyKey, termsVersion, token? }`:

- `idempotencyKey` must match `^[A-Za-z0-9._:-]{1,80}$`;
- `token` is optional and never required.

One transaction:

1. Lock the subscription, then read `now`.
2. **Owner only.** This is checked first, so a Manager or Employee learns nothing beyond `owner_only`.
3. **An existing claim:**
   - same key and same request hash → the stored result is replayed (200, `replayed: true`);
   - same key with another hash → `idempotency_conflict`;
   - another key → `trial_already_claimed`.
4. **Re-checked under the lock,** in this order:
   - the business's own blocks: `business_closed`, `business_suspended`, `business_refused`;
   - `trial_not_available`;
   - `terms_changed`, with the current version;
   - `contact_unverified`, with `missingContacts`;
   - a presented token: `link_invalid` (400), `link_expired` (410), `link_used`, `link_revoked`, `link_other_account`
     (403).
5. Insert the claim: claimed = started = now, and ends = now + 168 h. The subscription's version goes up by one.
6. Consume the presented link. Every other open link is retired as `claimed`.
7. Write the `trial_claimed` event and the `trial.claim` audit row. The audit never holds a token, a contact or a code.

A refusal is audited as `trial.claim_refused`, outside the rolled-back transaction.

**No payment row, billing period, seat allocation or status change is ever created by a claim.** This is asserted in
specs and over real HTTP.

**Terms version.** The terms version is `2026-10-13`, and the website states the same version. The terms sentence "Paid
access after the trial is arranged on this website." is under review: R4-04 awaits the owner (§16), so neither the
wording nor the version changed.

## 6. The Super Admin lifecycle — the fence and the deferred paid start (Q3)

**The fence.** Every decision that gives or ends access closes the eligibility under the subscription lock, which
serialises it with claims. The decisions are approve, grant, extend, refuse, cancel and company closure; the matching
closure reasons are `approved`, `granted`, `paid_period`, `refused` and `cancelled`. Once a business is fenced, no claim
can start. Suspend and reinstate do not touch the eligibility: suspension blocks, it never closes.

**Q3: access approved during a trial starts at its end.**

- `accessFrom` is the trial's end when a claim is running, else now.
- A paid period opens at `accessFrom` (`rollNow(…, at)`). An end date must fall after the trial's end, otherwise the
  approval is refused with `period_ends_before_trial_end`, which carries `trialEndsAt`.
- A grant starts at `accessFrom`.
- The business stays `trial_active` until `endsAt`, then becomes `active` with no read-only gap.

The review round also changed two things here:

- Activity changes scheduled "at the next renewal" take effect at the trial's end, not at the approval.
- The deferred period is priced as the shops will be at that instant.

### 6.1 Stores and paid seats requested during the trial (the owner's rule of 2026-10-15)

The trial covers the business's first store and its included employee allowance. During the trial, the Owner may still
request an additional store or a paid employee seat through the website's established flow.

- It is quoted, and its payment may be confirmed, during the trial.
- It stays **scheduled**, and its activation and first paid billing period begin exactly at the trial's expiry.
- It is charged once: never at once and again in the first period, never two payment obligations.
- Unpaid at expiry, it stays pending and inactive.
- Repeated approval, payment confirmation or expiry processing never activates or bills twice.

_As built: filled at the end of the phase._

**The trial rows are never written by any lifecycle action.**

## 7. Registration — both doors

- **One shared flow, two doors.** `POST platform/register`, `…/verify/start` and `…/verify/confirm` are the website's
  door; `POST auth/register`, `…/verify/start` and `…/verify/confirm` are the app's, restored by Q1 (D170). Both doors
  share the same DTOs, refusals and responses. `verify/confirm` returns a normal Owner session; the business stays
  pending, and its trial is `trial_available`.
- **Eligibility at creation.** Only the public doors pass `trialEligible`. The console's `createBusiness` and the
  staging fixture do not (Q2). The register response says `trialEligible`.
- **Up-front refusal (review round, C10).** The server refuses before saving anything, with 503
  `registration_unavailable`, when **any** given contact's channel cannot deliver a verification code. The body names
  each such contact in `unavailableContacts`. This applies two rules together: every contact given at registration must
  be verified (confirmed by the owner on 2026-10-15), and registration refuses up front when a code cannot leave the
  server (D117's rule). No Owner is left with a contact that can never be verified.
- **One throttle budget (review round, C15).** The two doors share one per-IP budget per step.
- **Idempotency.** The idempotency key follows the same pattern as the claim's.

## 8. Setup instructions

**The automatic send.** Once every required contact is verified, while the business is `trial_available`, the server
sends the setup instructions **once**. The trigger is the registration's confirmation, or the app's WhatsApp
confirmation for a both-contacts Owner.

**Verification is never held by delivery (review round, C14).** Verification answers within a short bound whatever the
providers do:

1. The link is issued in a first transaction.
2. The provider calls and the attempt row continue in the background.
3. The status meanwhile reads **`sending`**.

The website's resend uses the same bound.

**Channels.** Instructions go to verified contacts only. A channel is operational if:

- **email:** a real provider, or the development log where the outbox is allowed;
- **WhatsApp:** a real, proven channel **and** `WHATSAPP_TEMPLATE_TRIAL_SETUP`, or the development log.

This is checked at send time. With no `PUBLIC_SITE_ORIGIN`, no link can be built, so nothing is operational.

**Links.** `PUBLIC_SITE_ORIGIN/account/trial#t=<token>` (email). WhatsApp uses a URL button with the token as the
dynamic suffix; the button's URL is `PUBLIC_SITE_ORIGIN/account/trial?t={{1}}`.

- The token is 256 random bits. It is never stored, logged, audited or returned by an API.
- A link is valid for 24 h.
- A new send revokes older links.
- A claim retires them.
- Signing out everywhere, a contact change or a password change revokes it, both explicitly and through the binding
  digest.

**Honest status.** The delivery values are `waiting_for_contact`, `sending`, `not_sent`, `sent`, `failed` and
`unavailable`.

- `sent` is reported only while the link that went out still binds to the Owner's current contacts. After the Owner
  changes the verified number, the status is `not_sent`, because nothing went to the new one (review round, C2).
- `waiting_for_contact` is reported only before any automatic attempt.

**Website resend.** `POST platform/my-subscription/trial/setup/resend` is Owner-only, signed in on the website, and
allowed while the business is closed.

- **Limits:** 60 s, 3 per 15 min, 10 per 24 h. Every attempt counts, and a link issued in the last 60 s counts as an
  attempt in flight.
- **Responses:**
  - 429 `too_many_requests` with `resendAvailableAt`;
  - 503 `setup_delivery_unavailable`, with the attempt recorded;
  - 200 with the website's setup object.
- **`resendBlockedBy`** says why a resend is not possible now: `throttle`, `unavailable` or `contact_unverified`. Only
  `throttle` shows a countdown (review round, C4).
- **The attempt's instant** is the instant its link was issued, so the 60 s are measured from one time (review round,
  C5).

**Templates.** Email `trial.setup` and WhatsApp `trial.setup` exist in EN, FR and AR (`docs/64`). WhatsApp uses a
utility template with a URL button. No price, payment instruction or amount appears in any message.

## 9. The website (`erp-control-web`, branch `tsx-public-site`, not merged)

**`/account`, the Owner-only trial card.**

- **Offer available:**
  - the terms, with the end the trial would have if started now, in the business's zone with its name;
  - the single **Start my 7-day free trial**;
  - the setup status and a short **delivery history** (date, automatic or resend, the outcome per channel);
  - a secondary **Send the setup instructions again**, honest about why it is unavailable.
- **The other variants:**
  - unavailable while a contact is unverified (the WhatsApp number is verified in the app, under *Your account*);
  - active, with the recorded start and exact end;
  - expired.
- When paid or granted access follows the trial, the card says so instead of "becomes read-only" (review round).

**`/account/trial`, the link landing.**

- The token is read from `#t=` or `?t=` into memory only, and removed from the address bar.
- The page is served with `Referrer-Policy: no-referrer`; the trailing-slash path got the header too in the review round.
- Signed out, the page asks for sign-in and sends nothing.
- After sign-in it checks the link. The check never consumes it.
- The claim needs the click: it never runs on page load.
- Every link outcome other than *valid* still leaves the ordinary claim, after a fresh click.
- `other_account` offers *Sign out and use the other account*, keeping the token in memory.

**The terms.**

- No payment is required.
- It starts when claimed and lasts exactly 7 days (168 hours).
- Once per business.
- Read-only afterwards until paid access starts.
- "Paid access after the trial is arranged on this website." This sentence is **under review: R4-04 awaits the owner**
  (§16). It is not true today, and the public pages say "arranged with the Dukan ERP team". It is kept unchanged until
  the owner decides.

**The console.**

- The trial facts: eligibility, method, the claim and its end, and whether the expiry is recorded.
- The computed state in the lists and in the pending queue.
- That paid access approved during a trial starts at its end.
- No console action creates, extends or shortens a trial.
- Timeline events are rendered in words, in the business's zone, never as raw instants or codes.

## 10. The app (`erp-mobile`, branch `reports-export`)

**Sign-up is restored.** The routes are `auth/register*` (never `/platform/`). The continuation is held in memory only
(review round). A refusal names a contact that cannot be verified. A request timeout on confirmation says the outcome
is unknown and offers sign-in; it never says "wrong code".

**The closed screen on `trial_available`.**

- **The Owner sees a display-only card**, with no button, pressable, link or navigation:
  - "Your business is eligible for a 7-day free trial";
  - "Your trial has not started yet";
  - the status, the duration and "Starts only after you claim it";
  - each masked verified contact;
  - one delivery line — sent, sending, waiting for the WhatsApp number, not sent, failed or unavailable — each with
    "Please contact Dukan ERP support" where nothing can be done in the app.
- **Staff see a neutral status:** "Access has not started yet".
- **The screen's general actions:** Check again, Sign out and Delete my account. None of them is trial-related.
- **An Owner who gave both contacts** is waiting for the WhatsApp verification. Today that verification is reachable
  from this screen only through *Delete my account* → *Verify a number*. R5-4 awaits the owner (§16). The screen is
  unchanged until the owner decides.

**Other states.**

- `trial_active`: "Free trial — ends {date and time (zone)}".
- `trial_expired`: a read-only notice with the end.
- Every date is in `trial.timeZone`, with the zone's full name, which is not derived through `formatToParts`. Hermes on
  iOS truncates the name there (review round).

**The boundary, proven twice:**

- `lib/access-boundary.test.ts` uses a third-party import allowlist. It bans `openURL` in any form, and its route
  patterns are case-insensitive and normalised. Wording is pinned per key family, with normalisation.
- `scripts/audit-bundle.js` runs on the exported web and iOS bundles in CI:
  - a module denylist from source maps (QR encoders, web views, browser openers);
  - token markers anywhere;
  - pinned library baselines for `openURL` and `window.open`;
  - every file of the export, including `www.bundle`.

## 11. Time

- Instants are stored and transmitted in UTC.
- Every client shows them in the business's configured zone with the zone's name.
- No client computes trial arithmetic.
- An invalid zone is reported as `UTC`, never replaced by a guessed one.

## 12. The review round

**35 findings:** 3 blockers, 12 majors, 19 minors and 1 nit, from five independent adversarial reviewers. Each was
fixed against a shared contract (C1–C15) and then checked by an adversarial verifier. The outcomes and the decisions
taken are recorded below.

_Filled at the end of the phase._

## 13. Integration with the concurrent identity phase

The identity phase (Dukan ERP identifiers) ran on the owner's PC at the same time. It was integrated deliberately, as
the clarification required:

- The exact diffs were compared file by file.
- The merges are `--no-ff` merge commits: backend `c3aa803`, mobile `7b64918`, website `4b61f79`. There was no rebase
  and no force-push.
- **Only two files are touched by both sides,** in disjoint hunks, and both sides are kept:
  - backend `.env.example`: the product name on line 2, plus the trial's two variables;
  - website `README.md`.
- **One behavioural contact, in mobile:** `__tests__/deep-links.test.tsx` reads the real route tree, so it now covers
  the restored sign-up routes. It passes.
- **The complete combined gates** ran on the merged trees before the review round, and again at the end (§14).

## 14. Verification

_Filled at the end of the phase._

## 15. Configuration and operations

| Variable | Required | Meaning |
| --- | --- | --- |
| `PUBLIC_SITE_ORIGIN` | in production and staging (an `https://` origin, no path, no trailing slash) | Used **only** to build the setup links; never to check a request. Empty means no link can be built and no setup message can be sent. |
| `WHATSAPP_TEMPLATE_TRIAL_SETUP` | optional | The approved WhatsApp template name (utility, URL button). While it is empty, WhatsApp does not carry the setup instructions, and the status says so honestly. |

**Deployment order.** Deploy the API together with `0092`–`0096`. The PC's `phonestore` is still at `0091`, and the
previous API's exchange insert is refused by the 0092 CHECK.

**Before any migration on a shared database,** take the backup and restore check of `docs/22`. The rehearsal of 0095
and 0096 on disposable copies is recorded there.

## 16. Owner decisions to confirm, and open items

_Filled at the end of the phase._

## 17. Next safe step

_Filled at the end of the phase._
