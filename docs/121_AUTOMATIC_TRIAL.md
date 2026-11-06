# 121 — Automatic 7-day trial (0131)

From the owner's brief of 2026-11-06. Implemented the same day by CLAUDE (local session, the owner's PC).

The automatic trial **replaces the claim flow** for self-registered businesses. A business no longer has to claim its
trial through a link: it starts when registration completes.

| Repository | Commit(s) on `post-build4` |
|---|---|
| erp-backend | `6a9891b` (feature), `d978ad2` (census query) |
| erp-mobile | `ef9831a` |
| erp-control-web | `fe4999a0` |

Nothing is deployed. No iOS build was made. Production is unchanged.

## 1. When the trial starts

**At registration completion.** This is the moment the Owner proves the registration code. The trial starts in
the same transaction that:
- marks the contact as verified;
- turns the WhatsApp consent on;
- creates the Owner's session.

**What is created.** The same transaction writes:
- a `trial_claims` row (one per business) with idempotency key `auto:<company>`;
- an event `trial_claimed`, whose note says the trial started automatically;
- an audit entry `trial.start_automatic`;
- one `trial_started` notice.

**Length.** Exactly 168 hours from the commit, on the server clock (`trialEndFor`).

**What does not start it:**
- registering (the business is created, but its contact is not yet proved);
- asking for the code;
- verifying a contact anywhere else;
- a draft;
- a rolled-back transaction;
- a business created in the console (it has no eligibility);
- adding a branch.

**Eligibility.** The rules are the same as the old claim's:
- the business has an open eligibility;
- nothing has been claimed or given yet;
- the business is not closed, suspended or refused;
- the caller is the Owner;
- every contact the business registered with is verified.

On top of that, a verified number or email that already had a trial in another business never gets a second one
(`contact_used_trial`).

**Retries.** A retry or a timed-out request answers with the existing trial. The dates never move.

**Legacy businesses.** A business that was eligible but never claimed gets its trial at the Owner's next successful
sign-in, in the app or on the portal. The 168 hours count from that sign-in, not from the account's creation. If
anything goes wrong, the sign-in still succeeds.

## 2. The switch

`AUTOMATIC_TRIAL=enabled|disabled`. The default is `enabled`.
- **`disabled`** brings back the claim flow, the setup message and the resend, with no code change.
- **`enabled`** stops all of these:
  - no new setup link is issued;
  - no new `portal_instructions` notice is created;
  - pending `portal_instructions` notices are cancelled (`automatic_trial`) and never sent;
  - the resend answers `trial_not_available`.

## 3. Old links and Build 5

**A link that is still valid:**
- before any automatic start, it can still claim the trial, once;
- after an automatic start, the claim answers `{ claimed: true, replayed: true, alreadyActive: true, state, trial,
  subscriptionVersion }`. This is the claim's existing shape plus one optional field, and the dates do not change. The
  portal shows "Your free trial is already active. It ends on …".

**A link that is expired, revoked or already used** is refused exactly as before.

**How long to keep this.** Keep the compatibility path until every 72-hour link issued before the switch has expired and
no client in use still needs it. Its removal is a separate change.

**The legacy account-ready notices.** Waiting or failed `portal_instructions` notices are marked `superseded`
(`automatic_trial`), in the same audited transaction as the business's automatic start. They are never sent again. The
four legacy failed notices follow this rule, and none of them is requeued.

## 4. The `dukan_trial_started` message

- **Template.** Category Utility. Variables: {{1}} is the business name; {{2}} is the trial's end in the business's time
  zone (Africa/Nouakchott), for example "13 November 2026, 14:00 (Greenwich Mean Time)". There is one static URL button
  to `https://dukan.tsxmr.com/subscription`.
- **Samples sent to Meta.** Fake names only ("Boutique Exemple", "متجر المثال").
- **Status.** Submitted on 2026-11-06 in EN, FR and AR. All three are **In review**.
- **Delivery.** The notice is held as `held_template`, without spending an attempt, until `WHATSAPP_TEMPLATE_TRIAL_STARTED`
  is set.
  - Once set, it is sent once.
  - It is cancelled if the trial is no longer running.
  - Temporary failures retry, with a bounded number of attempts.
  - The trial never depends on the message.
- **What must happen before setting that key:** all three languages approved, then a controlled send to the Test
  business that succeeds.

**`dukan_account_ready`.** All three languages are now **Active** (approved). It was not edited. Its sender stays off:
`WHATSAPP_TEMPLATE_PORTAL_INSTRUCTIONS` must stay empty. Once `dukan_trial_started` is approved and tested, mark
`dukan_account_ready` as retired and unused in the template procedure. Do not delete it.

## 5. App and portal

- **App.** The owner's disclosure appears, word for word, on the last registration step and again above the code
  confirmation. After the code is confirmed, the app opens as it did before. There is no claim page and no wait for
  WhatsApp. The app's boundary tests allow exactly this sentence and nothing else about the trial.
- **Portal.** The trial card shows the exact start, the exact end and the time left, all computed from the server's end
  date. Plans come from the server's own catalogue. The claim button appears only through an old valid link, before any
  automatic start.
- **Dates.** The app and the portal read the same `endsAt` from the server and show it in the business's time zone.

## 6. Additional branches

The trial covers the first branch of an eligible business only.
- A branch added from the app (docs/120) stays pending until its own payment is approved.
- If that payment is approved during the trial, the branch is scheduled to open when the trial ends.
- A new branch never starts, extends or replaces the trial.

## 7. Migration and rollback

**Migration 0131** is additive. `subscription_notices.kind` gains `trial_started`, and nothing else changes in the
schema. It has been applied to the local database (backup `phonestore-local-0130-20261106T054603Z.sql`). It has not
been applied to production.

**To roll back:**
1. Set `AUTOMATIC_TRIAL=disabled`. This is immediate and needs no deploy of older code.
2. Trials already started stay as they are. They are ordinary claims.
3. Only after no `trial_started` row remains, the enum value can be dropped:
   `ALTER TABLE subscription_notices MODIFY kind ENUM(... without 'trial_started') NOT NULL`.

**Rolling back the code** without the switch leaves `trial_started` rows that older code does not know how to send.
Cancel those rows first.

## 8. Before enabling in production

Run `deploy/automatic-trial-census.sql`, read-only. It returns counts by category and never a contact.
- **Local database:** 11 businesses, all `console_created_no_eligibility`. None would receive a trial.
- **Production:** not counted yet. It needs a server session.
