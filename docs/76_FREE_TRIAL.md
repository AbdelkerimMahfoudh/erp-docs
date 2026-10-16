# 76 — The website-only seven-day free trial (2026-10-13)

> **As built (2026-10-16).** The phase is finished: implemented, reviewed by five adversarial reviewers, fixed, verified
> by independent verifiers, and pushed. Migration `0097` and seventeen product questions await the owner (§16).

This record covers the owner's brief of 2026-10-13 and its customer-discovery addendum, carried out by CLAUDE-B in a
cloud session. The owner made three decisions on the plan, then issued a correction and a clarification the same day.

**Nothing here was deployed, merged to production or applied to a live or shared database.** No message was sent to a
real customer. Migrations `0095` and `0096` were rehearsed only on disposable MySQL databases inside the cloud
container, and every one of them was dropped.

The decisions are **D169–D177** (`21_PRODUCT_DECISIONS.md`). Two review findings and seventeen product questions await the
owner (§16). This file is the contract as built.

## 1. Branches and commits

| Repository | Branch | Final commit | Range of this phase |
| --- | --- | --- | --- |
| `erp-backend` | `reports-export` | `6a4cfc0` (`80c9133` plus a comment-only commit) | from `aad5862` (before the trial): the trial, the identity merge `c3aa803`, the review fixes, the add-on round and its fix-ups |
| `erp-mobile` | `reports-export` | `a8b48c4` | from the identity merge `7b64918` on |
| `erp-control-web` | `tsx-public-site` (**not merged**) | `8efa902` | `main` (`0417bfe`) is untouched |
| `erp-docs` | `master` | this commit | |

Nothing is deployed, merged to a production branch, or applied to a live or shared database.

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
  `null`; `startsAt` is the trial's `endsAt` (review round, C6).
  - A suspended business keeps what was arranged; a cancelled one reads `null`.
  - After the end, it is shown only when the eligibility's closure proves the decision was taken during the trial.

`GET platform/my-subscription` also carries the business's zone at its top level, `timeZone` (C18), so the website
tells a paid period's or a grant's dates in the same zone as the trial's.

Clients render this view and never compute it.

**One read per evaluation (R1-F4).** Every tenant request is evaluated, with no cache. The subscription, the company's
name and zone, the eligibility and the claim are read in **one** joined statement, where they took four. A warm write
gate now issues 1 statement instead of 4, proven with Prisma's query log on a disposable database.

**The end is exact; what is written after it is lazy, and swept.** Access changes at `endsAt` exactly, because the
state is computed from the stored instants. Two things are written down after it, each in its own transaction
(`TrialEndRoll`, `src/platform/trial/trial-end-roll.ts`):

1. **The expiry record (Tx A):** `expiry_recorded_at` is set once, with one `trial_expired` event and one audit row.
2. **The activation (Tx B, D176):** what was paid for during the trial is put in force (§6.1). A failure here never
   undoes or re-queues Tx A.

**Neither ever holds up a request (R1-F2, N1).** Both take the subscription row with `FOR UPDATE NOWAIT`, then, before
any write, every other row they lock, one statement per primary key, also `NOWAIT`:

- **Tx A:** the business (shared) and the claim;
- **Tx B:** the business (shared), the period it raises, each seat's store (shared), each request, each person it may
  activate, and, when a store opens, each Owner and their role (shared).

When another writer holds any of them, the attempt returns at once as *busy* with nothing written, and a later
evaluation, an administrator's action or the sweeper finishes the work. Both read their instant after the lock. The
transactions' timeout (2 s to connect, 10 s in all) is only a backstop.

**When they run:**

- **The lazy path:** the first evaluation after the end. It asks "is anything due?" at most once a minute per company.
- **The sweeper** (`TrialEndSweeper`): a pass at start-up, then one a minute, at most 200 companies a pass. It visits
  the claims whose end is not recorded yet and the businesses that can be put in force now: an open company with a
  paid period in force. A business still waiting for paid access is not visited for its requests, so 200 waiting
  businesses never hide one that is due. This was found and fixed while writing required test 12.
- **A business found busy** is looked at again every second within the same pass, for up to 30 s after the pass
  began (N2). One held longer waits for the next pass.

**The latest period** is chosen by its start, then its end (an open end first), then its id. A period closed at its
own start always ranks below the one that replaced it, whatever their ids. New ids are monotonic within a process
(UUIDv7, RFC 9562 method 1).

Any two instances are safe: the row guards and the lock make every step happen once.

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
- **The deferred first period** is sized as the business is at the approval and priced by the plan in force at the
  trial's end. Its `renewed` note says so in words: "First billing period opens when the free trial ends, at today's
  size and the prices in force then." Stores and seats paid for during the trial join it at the end (§6.1).

**Server notes carry no instant (C7).** The dates travel as data, and every client tells them in the business's zone.

**Activity changes scheduled "at the next renewal" (R1-F3).** A deferred approval or grant still applies them at the
approval, mid-trial, as it always did. The review round fixed only what was recorded: the branch's change instant, the
allocation's confirmation and the `activity_changed` event now carry the instant the change took effect, never the
trial's future end. Moving the change itself to the trial's end is an open question for the owner (PQ7, §16).

### 6.1 Stores and paid seats requested during the trial (the owner's rule of 2026-10-15)

The trial covers the business's first store and its included employee allowance. During the trial, the Owner may still
request an additional store or a paid employee seat through the website's established flow.

- It is quoted, and its payment may be confirmed, during the trial.
- It stays **scheduled**, and its activation and first paid billing period begin exactly at the trial's expiry.
- It is charged once: never at once and again in the first period, never two payment obligations.
- Unpaid at expiry, it stays pending and inactive.
- Repeated approval, payment confirmation or expiry processing never activates or bills twice.

**As built: the model, migration `0097_scheduled_addons`.** It was rehearsed on disposable copies only (`docs/22`) and
**needs the owner's approval before any shared database sees it.**

- `seat_allocations.status` gains `scheduled`: paid for, in force nowhere, waiting for its start.
- `effective_at` is when a scheduled row starts (the trial's end). Once the row is in force, it is when it took effect.
- A CHECK binds every database account: a scheduled row has an instant and is a store or a seat.
- The payment link is held by the one code path that writes `scheduled`: one guarded UPDATE, with its read-back, in
  the payment's own transaction. A spec pins it as the only writer, and another pins that every reader of a request's
  status names `scheduled`.

**Requesting during the trial.** The website's established flow is unchanged. The request is priced and waits for its
payment (`pending_payment`). Nothing opens, counts or is billed.

**Confirming the payment (the console):**

1. **During a trial:** the payment is recorded once, and the row becomes `scheduled` for the trial's end. Nothing opens,
   counts or is assessed now. A first paid period approved during the trial still assesses only the base until then.
2. **A paid period in force:** the row takes effect at once, as before.
3. **Trial facts, no paid period ever started and no trial running:** 409 `paid_period_not_started`. Nothing is written,
   and the request stays pending. The first paid period would otherwise charge it again (PQ2).
4. **A repeat:** `applied: false`. A stale `expectedVersion` gives 409 `seat_request_changed`.

**At the trial's end.** This is `TrialEndRoll`'s Tx B (§4), in one transaction per business. Every scheduled row whose
business has a paid period in force from that instant is put in force:

- the store is opened, or the seat counted, and the people it was for are activated;
- it is stamped at the trial's end;
- the period it joins is raised once, by that row's price.

It happens at the first evaluation after the end, at an administrator's action, or in the sweeper's next pass, within
60 s (PQ11).

- **No paid access yet:** the rows stay scheduled, paid and counted nowhere. They take effect with the first paid
  period, whenever it is approved (PQ1).
- **Suspended or cancelled by the Super Admin:** the rows take effect on schedule. **Closed by the Owner:** they never
  do (PQ3).
- **Closed by its Owner around a payment confirmed during the trial:** the payment is kept and the request stays
  scheduled, but it is never put in force and nothing flags it. Today's behaviour is pinned by tests and awaits the
  owner (§16).
- **A store whose name is already taken** cannot open. The request records why and the Super Admin settles it; nothing
  is half-done, and the next attempt succeeds once the name is free.

**A scheduled row cannot be refused, withdrawn or released** (400): it is paid for (PQ4).

**What each side shows:**

- **The website (the Owner):** *Paid · scheduled*, with its start in the business's zone. That is either "Opens when
  the free trial ends, on {date}" or "Starts with the first paid month, once paid access is approved". The request
  forms carry a note that nothing starts during the trial.
- **The console:** a *Paid · scheduled* queue, each row with its start and what it waits for. The business page notes
  that a store or seat paid for during the trial must not be collected again.
- **The app:** no price, payment, purchase or activation control. A seat waiting for its start reads to the staff side
  as held (PQ13).

**The owner's 14 required tests.** Each is a `describe` of the same number in `src/platform/trial-addons.spec.ts`
(59 tests, 3 of them for what the website and the console read). Numbers 3, 6, 7, 8, 9, 12, 13 and 14 also run on real
MySQL in the env-gated `trial-addons.mysql.spec.ts` (21 tests). The journey also runs over real HTTP (§14, sections
AO-A, AO-K and AO-END).

| # | Required test | Unit spec | Real MySQL |
| --- | --- | --- | --- |
| 1 | store requested during trial | 3 | — |
| 2 | paid seat requested during trial | 3 | — |
| 3 | payment confirmed during trial | 2 | the CHECK, as the app's account and as root |
| 4 | no immediate billing period | 2 | in 6 |
| 5 | no immediate activation | 1 | in 6 |
| 6 | exact activation at trial expiry | 3 | the whole journey |
| 7 | one charge only | 11 (R1 reproduced, every ordering) | 2, plus the latest period whatever the ids |
| 8 | duplicate payment confirmation | 3 | ten times, two connections |
| 9 | concurrent expiry and payment confirmation | 5 | four races, thirty times each |
| 10 | unpaid request at expiry | 2 | — |
| 11 | cancelled or refused request | 6 | — |
| 12 | suspended business at the scheduled activation time | 5 | through the sweeper's own SQL; closed by its Owner, both orders |
| 13 | trial claim racing an add-on request | 6 | twenty-four times each |
| 14 | correct company/store isolation | 4 | 2 |

The MySQL spec's other tests support numbers 6 and 9:

- the subscription row held for 8 s (R1-F2);
- every other row the end's work takes held, alone or together (N1);
- a business found busy by the sweeper (N2);
- two approvals at once.

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

**Sign-up is restored.** The routes are `auth/register*` (never `/platform/`). A refusal names a contact that cannot be
verified.

**A lost answer is never a wrong code.** When the code check's answer is lost, the app says the account may be ready and
offers sign-in; a retry with the same code is never called wrong. A lost answer is a timeout, a gateway's 502 or 504, a
success without its session, or a failure after a valid session arrived. An API answer's body must arrive within the
request's 20 s bound; a file download's body is not held to it.

**A refused code request is said in the person's words,** never the server's English: the code was not sent (wait,
then start again), too many tries, or "we could not tell whether the code was sent".

**The registration continuation (R5-8).** It stays in secure storage (`localStorage` on the web build): a reload of the
web build at the code check's address needs it. It is forgotten whenever the sign-in or sign-up screen is shown, so a
registration abandoned at the code check no longer leaves it behind. Holding it in memory only, which the review
proposed, would make that reload a dead end.

**The closed screen on `trial_available`.**

- **The Owner sees a display-only card**, with no button, pressable, link or navigation:
  - "Your business is eligible for a 7-day free trial";
  - "Your trial has not started yet";
  - the status, the duration and "Starts only after you claim it";
  - each masked verified contact;
  - one delivery line — sent, sending, waiting for the WhatsApp number, not sent, failed or unavailable — each with
    "Please contact Dukan ERP support" where nothing can be done in the app.
  - **"Not sent" has three variants (C17)**, read from `lastSentAt`, the newest attempt a provider accepted:
    - never sent;
    - sent on {date}, but no longer working because the account's details changed since;
    - sent on {date}, but the latest instructions have not gone.

    Instructions that went out are never called "not sent".
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
- **What the review round added (R5-1, R5-3):** the source test proves its destinations rather than recognising
  spellings. A router is used only through its own methods, a route registry only from its own module and never
  changed, and no page element, markup that leaves the page, or hand-made element exists. The audit counts the same
  ways out in what ships. The claim and resend words are matched in any order, in EN, FR and AR, and retry idioms such
  as "try again" stay allowed. Every injection and probe the reviewers wrote is caught (48 of 48, among others).

## 11. Time

- Instants are stored and transmitted in UTC.
- Every client shows them in the business's configured zone with the zone's name.
- No client computes trial arithmetic.
- An invalid zone is reported as `UTC`, never replaced by a guessed one.

## 12. The review round

**35 findings:** 3 blockers, 10 majors, 21 minors and 1 nit, from five independent adversarial reviewers. An earlier
version of this file and of the handoff said 12 majors and 19 minors; the review file says 10 and 21. Each finding was
fixed against a shared contract (C1–C18), and every fix was then checked by an independent adversarial verifier, whose
own findings were fixed in turn.

**Outcome:** 31 fixed; 1 fixed in code but not verified on a phone (R5-5); 1 fixed in its records with its timing
awaiting the owner (R1-F3, PQ7); 2 awaiting the owner, unchanged (R4-04, R5-4). R1-F1 was replaced by the owner's
add-on rule of 2026-10-15 (D176) and fixed under it. Nothing was deferred silently.

"HTTP §X" names a section of the real-HTTP journey (§14).

| ID | Severity | Failure scenario | Status | Commits · tests |
| --- | --- | --- | --- | --- |
| R2-1 | major | The Owner confirms the code in the app while a messaging provider hangs. The server spends the continuation and then waits ≥ 20 s on the automatic setup send; the app times out at 20 s, shows "wrong code", and the retry is refused as "That code did not match". | fixed | backend 93c4ded (verification answers within ~3 s; the send continues in the background, C14) · app 550fe96, d4b9dad, c8cf3da, a8b48c4 (a timeout, a gateway's 502/504, a success without its session or a spent code is never "wrong") · `registration-continuation.spec.ts`, `trial-setup.service.spec.ts`; app `__tests__/registration.test.tsx`; HTTP §W |
| R2-2 | minor | Alternating the website door and the app door gives one IP two throttle budgets per registration step, so it can send twice as many codes to arbitrary contacts. | fixed | backend bb59050 (one budget per step, C15) · `registration-throttle.spec.ts`; HTTP §Z1–Z2 |
| R2-3 | minor | An Owner registers with an email and a WhatsApp number while WhatsApp codes cannot be sent. Registration accepts (it checked only the first contact), but the claim needs both verified, so the business can never claim. | fixed (the owner's confirmed rule, D177) | backend 85876f0 (503 `registration_unavailable` + `unavailableContacts`, nothing saved, C10) · website 153c613 · app c355a41 · `registration-flow.spec.ts`, `platform-boundary.spec.ts`; website `test/apply.test.tsx`; app `__tests__/registration.test.tsx`; HTTP §Q3–Q4 |
| R2-4 | minor | The delivery-history read throws, so `GET platform/my-subscription/trial` fails and the website never shows the offer. | fixed | backend 9e94d9b (`setup: null`; the offer and claim stand, C3) · `trial.service.spec.ts` |
| R2-5 | nit | A key longer than the column is silently truncated by MySQL, so the client's own retry is refused as `trial_already_claimed` instead of replaying. | fixed | backend 8384924 (claim key ≤ 80, C11), 0496590 (console key ≤ 74, stored as `admin:<key>`) · `idempotency-key.spec.ts`, `trial.controller.spec.ts`, `registration-flow.spec.ts` |
| R1-F1 | major | A store or seat paid for during the trial, before any approval, opens at once and is charged again in full by the first paid period. | fixed under the owner's add-on rule (D176) | backend e751fb8 (0097), 5200d9c, 570553c, 564025e, 5daa6e0, 2318135; tests e926c74, a8ec1f9, 6f13f5b, e2939c0 · `trial-addons.spec.ts` 56/56 (required test 7 reproduces R1: 500 then 1000, never 1500); `trial-addons.mysql.spec.ts` 15/15; HTTP §AO-A, §AO-K, §AO-END |
| R1-F2 | minor | The lazy expiry record waits on the subscription row lock inside every request, with no back-off, and can starve the connection pool. | fixed | backend 5200d9c, 570553c (`FOR UPDATE NOWAIT`, back-off, sweeper) · `trial-end-roll.spec.ts`, `trial-expiry.spec.ts`, `entitlement.interceptor.spec.ts`; MySQL spec "row held for 8 s: twelve evaluations each answer at once" |
| R1-F3 | minor | A deferred approval or grant applies the renewal's scheduled activity changes at once, mid-trial, but records them as made at the trial's future end. | records fixed; timing **awaiting the owner** (PQ7) | backend 0bd9009 (every record carries the true instant) · `renewal.spec.ts`, `subscription-lifecycle.spec.ts` |
| R1-F4 | minor | The entitlement gate issues 4 SQL round trips per request instead of 1. | fixed | backend 97b58ff (one joined read; warm gate 4 → 1, proven with Prisma's query log) · `evaluation-facts.spec.ts`, `entitlement.interceptor.spec.ts` |
| R4-01 | blocker | The Owner's and the console's timelines print trial instants as raw UTC ISO strings inside English server notes, with raw event codes, in the browser's zone. | fixed | website 678f887, d1eafb8, 5a55902 (events in words, the business's zone) · backend fa3ac6c (notes carry no instant, C7) · website `test/trial-account.test.tsx`, `test/trial-console.test.tsx`, `test/source-rules.test.ts`; backend `trial-timeline-notes.spec.ts` |
| R4-02 | major | The website ignores `setup.history`: the Owner never sees the delivery history. | fixed | website ced07a5 · `test/trial-account.test.tsx` |
| R4-03 | major | With paid access or a grant approved during the trial, the trial card still says the business becomes read-only at the end, contradicting the period card. | fixed | website d8448b8 · backend c9928d3 (`accessAfterTrial`, C6) · app e01184d · `trial-access-after-trial.spec.ts`; website `test/trial-account.test.tsx`; app `__tests__/access-trial.test.tsx`, `lib/access.test.ts` |
| R4-04 | major | The terms the Owner confirms say "Paid access after the trial is arranged on this website", which is not true today and contradicts the public pages ("arranged with the Dukan ERP team"). | **awaiting the owner** (unchanged) | alternatives in `docs/21` |
| R4-05 | major | A Super Admin approval refused during a trial shows "Something went wrong. Please try again." plus the server's English sentence with a raw UTC instant. | fixed | website 1e8152d · backend 2af6a2e (`trialEndsAt` as data, a message without an instant) · website `test/trial-console.test.tsx`; backend `subscription-lifecycle.spec.ts`, `error-detail.spec.ts` |
| R4-06 | minor | "Send again" counts down and then enables itself although no channel can carry the message. | fixed | backend 592b072 (`resendBlockedBy`, C4) · website 3563bb8 · `trial-setup-rules.spec.ts`, `trial-setup.service.spec.ts`; website `test/trial-account.test.tsx` |
| R4-07 | minor | A failed link check (5xx, 429, network) on the landing hides the ordinary claim from a signed-in eligible Owner. | fixed | website 901a020 · `test/trial-account.test.tsx` |
| R4-08 | minor | Another account's link offers no "Sign out and use the other account", and no test covers the switch. | fixed | website 09dba23 · `test/trial-account.test.tsx` |
| R4-09 | minor | No test proves that a failed or unavailable delivery still shows the claim (the owner's clarification). | fixed | website ebb325d · `test/trial-account.test.tsx`; HTTP §V2 |
| R4-10 | minor | "Sent to {destinations}" names today's verified contacts, not where the message went: it can name the wrong address, or nobody. | fixed | backend 29049ce, e20ad1b (C2), 80cb666 (`lastSentAt`, C17) · website 10cb3d9 · app dfc19b5 (the app's twin) · `trial-setup.service.spec.ts`, `trial-setup.controller.spec.ts`; website `test/trial-account.test.tsx`; app `__tests__/access-trial.test.tsx`, `lib/trial-setup.test.ts`; HTTP §Y, §Y3b, §P1b |
| R4-11 | minor | A deferred paid start shown outside `trial_active` is formatted in the browser's zone, date only. | fixed | website d8448b8 · `test/trial-account.test.tsx` |
| R4-12 | minor | `/account/trial/` with a trailing slash is served without `Referrer-Policy: no-referrer`. | fixed | website 4058e85 · `test/site-routes.test.ts`, `e2e/site.spec.ts` |
| R4-13 | minor | The console's pending queue shows the raw "pending activation" for every self-registered business, even mid-trial. | fixed | website 3f4e254 · backend 3dfd3d3 (`state` + `trial` per row, C8) · website `test/trial-console.test.tsx`; backend `console-trial.spec.ts` |
| R3-1 | major | The Owner's WhatsApp confirmation in the app waits for the automatic setup send; a slow provider pushes it past the app's 20 s timeout, so a success looks failed. | fixed | backend 93c4ded (C14) · app 550fe96 · `trial-setup.service.spec.ts`, `account-deletion.service.spec.ts`; app `__tests__/account-whatsapp.test.tsx`; HTTP §W |
| R3-2 | minor | After the Owner changes a contact, the status still says "sent" and shows the new contact, though nothing went there and the only link sent no longer works. | fixed | backend 29049ce, e20ad1b (C2) · `trial-setup.service.spec.ts`; HTTP §Y |
| R3-3 | minor | The global exception filter logs the raw URL, so a `?t=` setup token reaches the API log (the M3 failure of the first HTTP run). | fixed | backend 7199499, 3ffaab3, 1bbe8fe, df30f08, 550bc18, 7274fca (C16) · `request-log.spec.ts`, `log-scrub.spec.ts`, `error-detail.spec.ts`, `portal-handoff.spec.ts`; HTTP §S1–§S9 |
| R3-4 | minor | While a resend is in flight, the 429's `resendAvailableAt` is too early, so the website gets a second 429 at that instant. | fixed | backend 54442e5 (C5) · `trial-setup.service.spec.ts` |
| R5-1 | blocker | A build containing a QR encoder, a browser-opening call, a `#t=` link and a claim POST passes both the bundle audit and the source boundary test. | fixed | app 74eb645, 4f8a6e4, d841148, d08a6bf, 691e24e, e49346d · `lib/access-boundary.test.ts` (75 must-find probes), `lib/audit-bundle.test.ts`, `__tests__/no-browser.test.tsx`; the reviewer's 48 injections, the verifiers' probes and Probe.tsx are all caught on fresh exports |
| R5-2 | blocker | The app's route checks are exact-case while the backend routed case-insensitively, so a differently cased claim or resend call passes undetected. | fixed | backend dc057b4 (case-sensitive routing, C13) · app 74eb645 · `http-adapter.spec.ts`; app `lib/access-boundary.test.ts` |
| R5-3 | major | Wording checks catch only exact spellings, so claim or resend wording in other EN/FR/AR phrasings passes both guards. | fixed | app 74eb645, 9013640, c5f8773, 195752a, 07e83cb · `lib/access-boundary.test.ts`, `lib/boundary-rules.test.ts`; 70 of 70 verifier placements and 42 wider wordings caught; bare "Resend" with no object stays allowed (the app's own code resend) |
| R5-4 | major | A both-contacts Owner is told the instructions wait for the WhatsApp number, but the only path in the app to verify it goes through "Delete my account". | **awaiting the owner** (unchanged) | alternatives in `docs/21` |
| R5-5 | major | On iPhone (Hermes), the trial dates' zone name is probably cut to its first word, e.g. "(Greenwich)". | **fixed in code, not verified on a phone** | app 9d87269 · `lib/zoned-time.test.ts`; `docs/24` §66 TR6 |
| R5-6 | minor | "Managed by your organisation" lines appear under the Owner's own card, contradicting its "contact Dukan ERP support". | fixed | app 5249225 · `__tests__/access-trial.test.tsx` |
| R5-7 | minor | A retry after a lost answer reuses the idempotency key even after a field was corrected, so the server replays the first registration. | fixed | app 842f1a0, 1599bc9 · website 09e285b, 1938ea3 · app `__tests__/registration.test.tsx`, `lib/registration.test.ts`, `lib/identifier.test.ts`; website `test/apply.test.tsx` |
| R5-8 | minor | The registration continuation is written to device storage and left behind when the flow is abandoned. | fixed (kept in secure storage, forgotten whenever sign-in or sign-up shows; memory-only would strand a web reload) | app 1a4e7c5 · `__tests__/registration.test.tsx` |
| R5-9 | minor | CI never runs the rendered tests that prove the trial card has nothing pressable. | fixed | app 098862b (CI runs the rendered tests on every change) |

**Found by the verifiers, beyond the 35, and fixed:**

- The sweeper's query let 200 businesses waiting for paid access hide one that was due (backend `2318135`).
- `0097`'s first CHECK named `payment_id`, which MySQL refuses (ERROR 3823); amended before it reached anything shared
  (`docs/22`).
- Tx A and Tx B could still wait on rows other than the subscription's: every row is now taken with `NOWAIT` (`52af364`,
  `80c9133`). The sweeper looks again at a busy business within its pass (`46a97ed`, `298a074`).
- Periods tied on their start were ordered by id, and ids were not monotonic: `443789e`, `202c104`.
- The status inventory could not see a query built in a variable: `d893a1e`.
- The website: a 502 or 504 at the code check was called a wrong code (`c3931a3`), a success without its body likewise
  (`3ad07d1`), the rate limit read "ThrottlerException" (`da9e2ee`), and the console's business page scrolled sideways
  at 375 px (`8efa902`).
- The app: the Team sheet called "no seat free" a phone already in use (`6ca5c50`); a refused code request showed the
  server's English (`f465f02`); the code check called a lost answer a wrong code after a 502, a 504 or an empty
  success (`c8cf3da`, `a8b48c4`); more ways out of the app and more claim wordings are caught (`e49346d`,
  `07e83cb`).

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

Every result below is from the final commits (§1), in the cloud container, on disposable databases. **Nothing was run on
a physical phone** (`docs/24` §66).

**The gates:**

| Repository | Gate | Result |
| --- | --- | --- |
| backend `80c9133` | `prisma validate`; `tsc --noEmit` | both exit 0 |
| | Jest (as CI, no MySQL variables) | 234 suites passed, 1 skipped (the env-gated MySQL spec); 4 416 tests passed, 24 skipped (21 of them the MySQL spec, 3 pre-existing) |
| | `trial-addons.mysql.spec.ts` on a fresh database at `0097` | 21/21, three runs |
| | secret scan of the tree | clean |
| mobile `a8b48c4` | `tsc`; `expo lint` | exit 0; 0 errors, 29 warnings (unchanged) |
| | pure tests | 113 files, all passed |
| | rendered tests (Jest) | 21 suites, 253 / 253 |
| | release configuration (`production`) | sound |
| | fresh web and iOS exports, bundle audit | PASS; the reviewers' 48 injections, the verifiers' probes and `Probe.tsx` all caught |
| website `8efa902` | typecheck; Vitest | exit 0; 18 files, 295 / 295 |
| | `build:preview`; links; bundle audit | 36 pages; 1 659 links, 0 broken; PASS |
| | Playwright | 114 / 114 |

**The real-HTTP journey** (`trial-http.cjs`), from a fresh disposable database migrated to `0097`, the QA fixture loaded
through the API, the API built from `80c9133`: **188 product checks passed, 0 failed, 0 skipped**, plus 1 harness
precondition (the server clock is past every trial end used). 27 sections cover registration through both doors, the
claim, setup delivery and resend, the website sign-in without the link, the Super Admin lifecycle, the 168-hour
boundary (still writable two minutes before the end, read-only at it), the add-ons (AO-A, AO-K, AO-END), log hygiene
and the shared throttle.

**No secret reaches a log (C16).** Section S spends a portal ticket (a success), replays it (a failure) and sends forged
tickets, refused claims, refused sign-ins and webhook checks with secrets in the query and the body. S9 then reads the
whole run's API log, across every restart: **123 secrets handled, none in the log** outside the development banners.
The unit proof is `src/common/http/request-log.spec.ts`, `log-scrub.spec.ts` and `error-detail.spec.ts`.

**Concurrency, by independent verifiers on real MySQL:** two confirmations at once, a confirmation at the end ±1 ms
beside evaluations and the sweeper, a claim racing requests and confirmations, two approvals or grants at once, two API
instances, a lock held for 8 s, a crash between Tx A and Tx B, a failure midway through Tx B. Every race ended with one
payment, one activation and one record.

**Screenshots against the real API:** the Owner's account page and the console, in EN, FR and AR at 375 and 1 280 px,
before and after the trials' end (§9). The console's business page scrolled sideways at 375 px; fixed (`8efa902`).

## 15. Configuration and operations

| Variable | Required | Meaning |
| --- | --- | --- |
| `PUBLIC_SITE_ORIGIN` | in production and staging (an `https://` origin, no path, no trailing slash) | Used **only** to build the setup links; never to check a request. Empty means no link can be built and no setup message can be sent. |
| `WHATSAPP_TEMPLATE_TRIAL_SETUP` | optional | The approved WhatsApp template name (utility, URL button). While it is empty, WhatsApp does not carry the setup instructions, and the status says so honestly. |

**Deployment order.** Deploy the API together with `0092`–`0097`, and the website in the same release window (awaiting
the owner, `docs/21`):

- The PC's `phonestore` is still at `0091`, and the previous API's exchange insert is refused by the 0092 CHECK.
- `0097`'s CHECK rebuilds `seat_allocations` and blocks its writes while it copies: apply it with the API stopped.
- A website without D176 would show a scheduled request with no words for it; an API without it would open and bill a
  store paid for during a trial at once.
- Roll the API back past `0097` only while no request is `scheduled` (`docs/22`).

**Before any migration on a shared database,** take the backup and restore check of `docs/22`. The rehearsals of
`0095`, `0096` and `0097` on disposable copies are recorded there. **`0097` needs the owner's approval first.**

**The sweeper** (`TrialEndSweeper`) starts with the API and needs no configuration. It runs one pass a minute in each
instance; any number of instances is safe.

## 16. Owner decisions to confirm, and open items

Each is recorded in `docs/21` with its alternatives. Today's behaviour is kept for every one of them.

1. **Migration `0097`:** approval before any shared database, and one release window for the API (`0092`–`0097`) and the
   website.
2. **R4-04:** the terms sentence "Paid access after the trial is arranged on this website."
3. **R5-4:** the both-contacts Owner's path to the WhatsApp verification in the app.
4. **PQ1–PQ17:** the defaults D176 is built on (`docs/21`).
5. **A business closed by its Owner around a payment confirmed during the trial:** the payment is kept and the request
   stays scheduled, never put in force, with nothing flagged. Alternatives: refuse the confirmation for a closed
   company; or accept it but flag the stranded request once for the Super Admin.
6. **The setup status after an earlier send went out and the latest attempt failed:** it reads *failed* or
   *unavailable*, from the last attempt alone. Alternatives: a "sent on {date}, but the latest could not be sent" line in
   the app and the website; or the server reporting *sent* while an earlier send still binds.
7. **Wording to review (EN, FR, AR):** *Paid · scheduled*; the trial note under the request forms; the console's
   paid-once note; "The person still waits for the seat to start."; the setup lines of C2 and C17; the app's three
   code-check lines (*not sent*, *too many tries*, *could not tell whether the code was sent*).
8. **Server English on the website.** A refused resend at `/apply`, and other refusals across the site (pre-existing),
   show the server's English sentence under a translated title on FR and AR pages. The app now says them in its own
   words. Alternatives: the same for the website; or distinct server codes for a spent registration and the hourly code
   limit (both are one 400 today), so that both clients can say "start again" or "wait" exactly.
9. **Smaller presentation questions:** the console's businesses list shows *Ends —* for a business in its trial; the
   co-Owner's "sent to"; the *sending* line names no destination when there are several contacts; the applications
   queue's *Email address* column shows a phone number (pre-existing).

10. **Payment rows the application may update** (pre-existing): only deletion is refused by a trigger (`docs/21`).

**Deferred nits, recorded:** a store whose name is already taken keeps its business in every sweeper pass (N3); with
200 such businesses a due one could wait for a visit. Reaching it needs a branch created outside the product, so it is
practically unreachable today. A future change would exclude such rows from the sweeper's query and rotate its
selection.

**Not verified on a physical phone:** everything in the app, in particular the zone's whole name on an iPhone (R5-5),
the code check's lost answers, the closed screen and the Team sheet (`docs/24` §66).

## 17. Next safe step

1. The owner answers §16, first the approval of `0097` and the release window.
2. Run `docs/24` §66 on a physical Android phone and an iPhone against a test API.
3. Only then: the backup and restore check of `docs/22`, the migrations `0092`–`0097` on a shared database with the API
   stopped, and the website merged and deployed in the same window.
