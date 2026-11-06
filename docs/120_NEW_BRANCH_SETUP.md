# 120 — Adding a store from the app (0130)

The owner's brief of 2026-11-05. Implemented 2026-11-06 by CLAUDE (local session, the owner's PC).

| Repository | Commit(s) |
|---|---|
| erp-backend (`post-build4`) | `0ee252a`, `c255c3e`, `f839c55` |
| erp-mobile (`post-build4`) | `d067dd7` |
| erp-control-web (`post-build4`) | `540bcbcf` |

Nothing is deployed. No iOS build has been made or submitted.

## 1. State model

A store added in the app is a **store request** (`seat_allocations`, kind `store`), not a `branches` row. The real
branch is created only when a payment is approved. So no sale, stock, money, staff or selection can reach it before then.
The backend enforces this, not the app.

| What the Owner sees | Stored as |
|---|---|
| Pending activation | `pending_payment` |
| Being reviewed | `pending_payment` while a payment proof is `submitted` or `under_review` |
| Activation scheduled | `scheduled` (paid during the business's free trial; opens at the trial's end, D176) |
| Active | `paid` / `granted`, with `branch_id` set |
| Cancelled | `released` |
| Not activated | `refused` |

**Migration 0130 (additive):**
- `seat_allocations.location` VARCHAR(160) NULL;
- `seat_allocations.request_key` VARCHAR(80) NULL, unique per company (`ux_seat_allocations_request_key`);
- the notice kind gains `branch_activation`.

## 2. Rules

- **Who:** the Owner only (`owner_only` for anyone else). The list is empty for non-Owners, and the app
  does not ask.
- **Name:** trimmed and spaces collapsed; at most 160 characters. A name already used by a store or a waiting request is
  refused (`branch_name_in_use`), compared without case or accents.
- **Address:** optional, at most 160 characters. The API field is `address`; the column is `location`.
- **Retries:** `requestKey` is required (8–80 safe characters). A repeated key returns the same request
  (`created: false`). The app keeps one key per asking.
- **What creating one does not do:** it does not change the active store or the subscription, gives no free trial, and
  uses no staff seat.
- **Activity:** electronics by default. The form has no activity field, per the brief.
- **Replacement credit:** an archived store's free replacement credit is **not** used by an app request. It stays
  usable through the portal.

## 3. Activation

- **Pricing:** the portal quote prices each waiting store like any other store (`pending: true` on its line).
- **Approval:** when a payment proof is approved, `activatePendingBranchesTx` runs in the same transaction as the paid
  period. Each waiting request becomes `paid`, and its branch is created with its address, every Owner assigned and the
  subscribed count raised. During a trial it becomes `scheduled` instead and opens at the trial's end.
- **Records:** Owners get an in-app notification (`branch.activated` / `branch.scheduled`), and the audit records
  `branch.activate`.
- **What does not activate it:** a proof alone does not. A refused proof leaves the store waiting. A repeated approval
  changes nothing.
- **Listing:** stores activated in the last 30 days stay in `GET branches/requests` as `active` with their `branchId`.
  The app uses this to offer the setup checklist once.

## 4. The WhatsApp notice: `dukan_branch_activation_ready`

- **Outbox:** `subscription_notices`, kind `branch_activation`, period key `branch:<request id>`. There is one per
  request, created after the request commits.
- **While the template is not configured:** the notice is held (`held_template`) without spending an attempt.
- **When the template is configured:**
  - it is sent once;
  - temporary failures retry up to `MAX_WHATSAPP_ATTEMPTS`, then fail with the reason recorded;
  - it is cancelled (`branch_not_pending`) once the store is no longer waiting.
- **Resend:** `POST platform/admin/branch-requests/:id/resend-notice` with a reason. The same notice waits again, and the
  resend is audited as `branch.notice_resend`. It never creates a second notice or a second branch.
- **Configuration:** `WHATSAPP_TEMPLATE_BRANCH_ACTIVATION` stays **empty** until Meta approves all three languages
  **and** a controlled send to the Test business passes.

### Submission to Meta (not submitted yet; the owner's approval comes first)

Category Utility. Body variables: {{1}} the branch, {{2}} the business. One static URL button to
`https://dukan.tsxmr.com/subscription`. Sample values (fictional): {{1}} = `Ksar Centre`, {{2}} = `Boutique Exemple`.

- **EN:** "Your new branch {{1}} for {{2}} is ready for activation. Open your secure subscription page to review and
  activate it."
  Button: View subscription
- **FR:** « Votre nouvelle succursale {{1}} pour {{2}} est prête à être activée. Ouvrez votre page d’abonnement
  sécurisée pour la consulter et l’activer. »
  Button: Voir l’abonnement
- **AR:** « فرعك الجديد {{1}} الخاص بـ {{2}} جاهز للتفعيل. افتح صفحة اشتراكك الآمنة لمراجعته وتفعيله. »
  Button: عرض الاشتراك

## 5. The app

- **Store list:**
  - Owner: "Add a store", and the waiting stores with a "Pending activation" badge. A waiting store's row opens its
    read-only status page and is never chosen.
  - Manager or Employee: neither.
- **Add a store:** the name (required) and the place (optional). Before sending, the screen explains that the store is
  created pending activation, gets no free period, cannot be used or chosen until activated, and that the instructions
  go to the verified WhatsApp number.
- **Status page:** the state in words. No price, plan, payment, link or call to action.
- **Setup checklist:** offered once, on the first explicit opening of a store activated from a request. It has five
  rows, each opening its own screen, which reads its own rules from the server:
  - assign a Manager or Employee, and add staff (both open Team);
  - money places;
  - receive opening stock;
  - transfer stock.
- **Languages:** EN, FR and AR, with right-to-left layout through the design system.

## 6. Note for App Review (Guideline 3.1.1 / 3.1.3)

> Dukan ERP is a business management tool for phone and electronics shops. A business owner can add another store
> (branch) to their account from the store list. Adding one only records the store's name and optional location; the
> store is created as "Pending activation" and cannot be used until the business activates it.
>
> 1. The app contains no price, plan selector, payment instruction, payment link, or external purchase button for
>    the new store, or for anything else.
> 2. Activation is part of the business's existing subscription, which is arranged directly between the business and
>    us, outside the app (Guideline 3.1.3(c), multiplatform/enterprise services sold to businesses).
> 3. After the owner adds a store, we send them a WhatsApp business message on their verified number, with a link to
>    their account page on our website.
> 4. The app never directs users to that page. The status page only says that the instructions were sent to the
>    verified WhatsApp number.
> 5. Nothing in a pending store is usable: sales, stock, money and staff open only once it is active, and it cannot be
>    selected.
> 6. The store gets no free period; the business's subscription is unchanged by adding it.
> 7. Demo account: Owner of "Boutique 1", which has one store pending activation (to be provided in the review
>    notes, not here).

### Question for an App Review appointment (Guideline 3.1.3(c))

> Our app is used by businesses (phone shops) to run their stores. A business owner can add another store to their
> account in the app; the new store is created as "pending activation" and is unusable until the business's
> subscription covers it. The subscription is sold to businesses outside the app, and after the owner adds a store we
> send the activation instructions only to the owner's verified WhatsApp number, never through the app. The app shows
> no price, no payment method and no link. Is this flow acceptable under Guideline 3.1.3(c), or does Apple require
> any change to how the pending store is presented in the app?

### Screenshots to attach

1. The store list as the Owner: the current store, a store with the "Pending activation" badge, and "Add a store".
2. The Add a store form with its "Before you add it" notice.
3. A pending store's status page.
4. The same store list as a Manager, with no Add and no pending store.
5. The setup checklist after activation.
6. The WhatsApp message, once Meta approves the template. This is outside the app, for the reviewer's context only.
