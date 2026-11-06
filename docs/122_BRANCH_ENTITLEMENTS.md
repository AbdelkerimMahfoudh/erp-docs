# 122 — Per-branch entitlements (0132)

From the owner's brief of 2026-11-06 ("Branch only, own dates, each branch is separate; 1/3/12 months"). Design written
by CLAUDE before implementation. The owner allowed implementation without a pause, unless the work reveals one of:
- a destructive migration;
- an unavoidable access regression;
- a materially different billing rule.

## 1. The rule

**Each store branch is its own subscription.** It has its own:
- state;
- start;
- end;
- grace;
- payment history.

**The business keeps account-level facts only:**
- the Owner and the people;
- suspension or refusal by the Super Admin;
- the payment proofs it submits;
- its registration and trial eligibility.

**The free trial.** The automatic seven-day trial (docs/121) applies to the business's **first branch** only. Every
additional branch starts **locked**. It opens only when a payment that names it is approved, and it opens **at that
approval**, never at the trial's end. This supersedes the `scheduled` behaviour of docs/120 §3 and D176 for new
branches.

**Prices.** Prices come only from `billing/period-offers.ts`. The choices stay 1, 3 or 12 months. A quote names each
branch it covers. Nothing duplicates a figure.

## 2. Data (migration 0132 — additive only)

| Table | Purpose |
|---|---|
| `branch_entitlements` | One row per store branch that has ever been opened. Fields: `kind` (`trial`, `paid`, `complimentary`), `starts_at`, `ends_at` (NULL only for an open-ended complimentary branch), `version`. Unique on `branch_id`. |
| `branch_periods` | The branch's history. One row per trial, paid period, grant or grandfathered start. Fields: `source`, `months`, `starts_at`, `ends_at`, `amount` (that branch's line of the quote), `payment_id`, `payment_proof_id`, `recorded_by`. Unique on `(payment_proof_id, branch_id)` and on `(payment_id, branch_id)`, so a retried approval cannot extend a branch twice. |
| `branch_grace_episodes` | The same rule as `grace_episodes` (72 hours; three granted in any rolling 12 months), but per branch. Unique on `(branch_id, period_end)`. |
| `payment_proofs.lines` (JSON, nullable) | The quote's lines at submission: one per branch or waiting request, with its months and amount. The approval applies exactly these lines. |

Nothing is dropped or rewritten. `subscriptions.current_period_end` stays, maintained as the **latest end among the
business's paid branches**, for the readers that only need a date (console sorting, exports).

## 3. A branch's state (pure rules, clock-injected)

The order matters: the first rule that matches decides the state.

| State | When | Writes | Reads |
|---|---|---|---|
| `suspended` | the business is suspended, refused or closed | no | account surface only (unchanged) |
| `locked` | no `branch_entitlements` row: a waiting branch request | no (it has no branch yet) | — |
| `complimentary` | kind `complimentary`, and `ends_at` is NULL or in the future | yes | yes |
| `trial_active` | kind `trial` and now < `ends_at` | yes | yes |
| `active` | kind `paid` and now < `ends_at` | yes | yes |
| `grace` | kind `paid`, the end has passed, and the branch's grace for that end was granted and is still running | yes | yes |
| `trial_expired` / `expired` | otherwise | no | yes (expiry never blocks reads; unchanged) |

## 4. Enforcement

**`EntitlementInterceptor`, branch-scoped operations.** These are requests carrying `X-Branch-Id`. Only that branch's
state is checked. The branch must belong to the caller's business, and `AccessService` already refuses a branch the
user is not assigned to.

**Manually changed branch IDs.** A mutation that names another branch is checked against that branch too, and refused
if the branch cannot write. This covers:
- a `branchId` in the URL (`:branchId`);
- a branch named in the body (`branchId`, `toBranchId`, `fromBranchId`, `destinationBranchId`).

So editing the ID cannot reach a locked or expired branch.

**Business-wide operations.** These are requests without `X-Branch-Id`. A mutation is allowed when **at least one**
branch of the business can write.

**Always available, every branch locked or not:**
- sign-in;
- the account surface;
- `/entitlement`;
- the branch list;
- branch requests;
- subscription management;
- the portal and payment-proof submission.

This is the existing allow-list, extended with the branch routes.

**Who sees what:**
- **Owners** see locked branches, as their waiting requests, together with how to activate them.
- **Managers and Employees** cannot reach a locked branch: it has no branch row until approval, and no assignment.

## 5. Payment and approval

1. **Quote.** The portal quote lists every branch:
   - its state and its end;
   - each waiting request, as its own line.

   The Owner chooses 1, 3 or 12 months. The same months apply to every line the Owner keeps. The server prices the
   lines and stores them in `payment_proofs.lines`.
2. **Approval.** One transaction, audited as `payment_proof.approve` and `branch.period.apply`, per line:
   - **A waiting request:** the branch is created (`openStoreTx`), the Owners are assigned, the entitlement is created
     as `paid` from now for the months, and its period is recorded. The branch is **open immediately**.
   - **An existing branch:** if it is active or in grace, the new period starts at its current end. Otherwise it starts
     at approval.
   - **Retries:** the approval is guarded by the proof's `period_applied_at` mark and by the unique keys on
     `branch_periods`. A retry finds the work done and changes nothing.
3. **Trial branch.** A first branch paid during its trial goes on from the trial's end. Nothing is lost, and its trial
   is not shortened.

## 6. Messages and screens

Each of these names its branch:

| Where | What |
|---|---|
| Reminders (3/2/1 days) | One per branch period end. The notice key holds the branch id. |
| WhatsApp text | Variables carry the branch's name. Templates that need a branch variable go through Meta review before their sender is turned on. Until then, senders stay off as they are now. |
| Portal quote | One line per branch. |
| Payment proof | Its lines, each with its branch. |
| Approval | What was applied, per branch. |
| Console | The status of each branch. |
| App status (`/entitlement`) | A `branches[]` list: id, name, state, end, grace end. |

## 7. Grandfathering (migration backfill) — nobody loses access

For each existing store branch that is not deleted, its business's current timeline is copied onto it at migration
time:

| The business today | Each of its store branches gets |
|---|---|
| Complimentary (until X, or open-ended) | `complimentary`, ending at X (or open-ended) |
| A paid period with end E | `paid`, ending at E, plus the business's grace decision recorded for E |
| Running trial (claim C) | the **first** branch: `trial`, from C's start to C's end. Any other existing branch: the same dates, as `grandfathered` (an existing branch is never locked by the change). |
| Trial ended, nothing paid | the first branch: `trial`, ended |
| Never activated or refused, no period | no row: locked, exactly as inaccessible as today |

**Branches paid during a trial** (request status `scheduled`) are opened when 0132 is applied. Each gets a `paid`
entitlement from that moment, for the months its payment covered.

**Production census, 2026-11-06 (counts only):**
- 8 businesses: 5 with a running paid period, 1 with an ended one, 1 never activated, 1 refused with an ended trial;
- each business has exactly one store branch;
- no waiting or scheduled branch requests;
- no payments recorded.

So production gets exactly 6 grandfathered `paid` rows and 1 ended `trial` row. Nothing that writes today will stop
writing.

## 8. Rollout and rollback

**A switch:** `BRANCH_ENTITLEMENTS=off|shadow|enforce`.
- **`shadow`** computes every branch decision, logs where it differs from the business-wide decision, and blocks
  nothing.
- **Production deploys in `shadow` first.** It moves to `enforce` only after the shadow log is clean.
- **`off`** returns to the business-wide gate immediately, without a deploy.

**Migration safety.** 0132 is additive: three new tables and one nullable column. Rolling it back means:
1. set `off`;
2. the new tables can stay, since nothing old reads them;
3. drop them only after taking a backup.

**Rehearsal.** The migration and its backfill are rehearsed on the production schema dumped on 2026-11-06 (last
migration 0129), with 0130 and 0131 applied first, as the deployment will.

## 9. Grace, which follows from "independent"

The rules are the same as today: 72 hours, and at most three granted in any rolling 12 months. Both apply **per
branch** instead of per business. A business with two branches can therefore receive grace on each branch separately.

## 10. As built (2026-11-06)

- **A store with no row follows the business.** Any store opened outside the per-branch flows (a fixture, an older path)
  reads its business's state, as before 0132, so the change cannot lock it. The trial is the exception: an additional
  store never inherits it.
- **Reminders:** a business whose stores have rows gets one 3/2/1-day timeline per store, keyed `s:<store hex>:<period
  key>`, re-validated per store at delivery. When the business has more than one store, the message's existing
  `business` variable reads "Business · Store": no template change, so no new Meta review.
- **Console decisions** (approve, extend, grant) still decide for the whole business and every store follows them; a
  payment proof applies its own lines store by store and does not.
- **Before deployment:** the owner requires the 0130–0132 backfill rehearsed on a restored production backup with real
  rows, verifying that each of the 8 stores keeps exactly its current access; then `shadow`, then `enforce`.
