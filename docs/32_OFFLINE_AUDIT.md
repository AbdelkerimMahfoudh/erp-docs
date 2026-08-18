# 32 — Offline audit and capability matrix (Milestone J)

> **J0.** What the app already does without a server, what it may safely be
> allowed to do, and — the part that matters — what it must keep refusing.
>
> The matrix in this document is not the authority. `mobile/lib/offline/policy.ts`
> is, and `policy.test.ts` fails the build when the two disagree. Prose cannot
> fail a build.

---

## The binding decision

**There is no server-issued inventory lease.**

Nothing in the system can promise a disconnected device that an IMEI is still
unsold. Another phone, another browser, another branch may sell it while this
device is dark, and neither party would know until the wifi came back.

So:

- an offline cart **may** be preserved;
- a sale **may** be prepared offline;
- the customer **must not** be charged, and the sale **must not** be shown as
  completed, until the server accepts it;
- **Charge is online-only.**

The same reasoning governs every authoritative stock and money operation. This
is not a limitation waiting to be lifted by better engineering — it is what the
absence of a lease actually means.

---

## What already existed

The audit found more than expected, and one important gap.

| Area | State before J |
|---|---|
| Connectivity | **Good.** `lib/connectivity.ts` derives online/offline from real request outcomes, not the radio. A completed 4xx proves reachability; only a `fetch` rejection means unreachable. This principle is preserved. |
| Error classification | Partial. `lib/errors.ts` separates permission, not-found, 4xx-with-a-reason and 5xx, and treats a `TypeError` as offline. It could not distinguish a **timeout** from anything else. |
| Idempotency keys | Present on expenses, loans, consignments, imports, sales, transfers, returns and supplier payments — `client_uuid` with a `(company, client_uuid)` unique index. Built during earlier milestones with queuing in mind. |
| Payload fingerprint | **Only on some.** `expenses` compares a `client_request_hash` and refuses a changed payload with 409. The loan and consignment **ledgers did not** — see the gap below. |
| Local storage | `expo-secure-store` only, via `lib/storage.ts`. Suitable for tokens; **not** for a queue — Android warns above roughly 2 KB per value. |
| React Query | In-memory only. No persister, `staleTime` 30 s, `retry: 1`. Cached reads do not survive a cold start. |
| AppState | Used once, to refresh permissions on resume. A sound place to also drive replay. |
| Request timeout | **None at all.** `fetch` was called with no `AbortController`, so a request could hang indefinitely and "timed out with an uncertain outcome" was not a state the app could even represent. |

### The gap that had to be closed before queueing anything

`loan_ledger` and `consignment_ledger` carried `client_uuid` but **no
`client_request_hash`**. Their replay logic returned the existing record for any
request bearing that key, whatever the payload said.

That is harmless while every request is made online and immediately. It is not
harmless behind a queue: edit a queued 5,000 payment report to 8,000, reuse the
key, and the server would silently return the original 5,000 record while the
client displayed **synced**. The shop would believe it had reported 8,000.

Per the milestone brief — *"if a chosen report endpoint lacks these properties,
harden it before enabling queueing"* — this was fixed before either report was
allowed into the queue.

---

## The capability matrix

Three classes. The full, per-operation list with its reasoning lives in
`mobile/lib/offline/policy.ts`; this is the shape of it.

### 1. Local drafts — the shop's own unfinished work

Persisted on the device, never sent by themselves, and **never** described as
sent, reserved, paid, approved, confirmed or completed. A draft is not a
submitted server record, and the words the UI is forbidden from using about one
are listed in `FORBIDDEN_DRAFT_WORDS` so a screen can be checked against them.

| Draft | Becomes | Which is |
|---|---|---|
| Sell cart | `sale.create` | online-only |
| Receive preparation | `purchase.create` | online-only |
| Import preparation | `import.commit` | online-only |
| Expense form | `expense.submit` | **queueable** |
| Return preparation | `return.create` | online-only |
| Consignment proposal | `consignment.create` | online-only |
| Loan proposal | `loan.create` | online-only |
| Closing counts | `closing.count` | online-only |
| Goal form | `goal.create` | online-only |

Eight of the nine become something the app will not do offline. That asymmetry
is the point: preparing work is safe, deciding is not.

### 2. Queueable — append-only reports

An operation may be queued only if it is a *report* of something that already
happened, carries a stable client UUID, is idempotent server-side, moves no
stock, settles no money, grants no authority, and can fail later without
corrupting business truth.

Four qualify:

| Operation | Why it is safe to send late |
|---|---|
| `expense.submit` | A report of money already spent. Grants nothing — somebody still has to confirm it |
| `loan.payment.report` | Says "I paid you". Balance effect is **zero** until the creditor confirms |
| `consignment.payment.report` | The same claim about consigned stock, with the same zero balance effect |
| `notification.read` | Sets a flag on the reader's own notification. Touches no business record |

**A queued payment report means one thing: waiting to tell the server.** It
never means the payment was confirmed. That distinction is carried in the
wording of the queue states, the screen labels and the translations.

### 3. Online-only — anything that decides something

Everything else, which is the large majority: sale finalization, inventory
activation, import commit, receiving, catalogue writes, cost and price changes,
below-cost overrides, every transfer step, every consignment step including
reservation, acceptance, custody, resale and return confirmation, return custody
and investigation and approval and rejection, refund confirmation and correction,
supplier settlement, expense confirmation and rejection, financial corrections,
closing submission and finalization, shortage responsibility, loan acceptance
and confirmation and correction and forgiveness, goal writes, user and permission
and branch and settings changes, and every authentication or device-trust action.

Forms for these may be **drafted** offline. Authority happens only after a
successful online response.

### Failing closed

`classify()` returns `online_only` for any operation not in the list. A future
milestone that adds a mutation and forgets this file gets the safe answer, not
the convenient one — and a test asserts the queueable set is exactly the four
above, so widening it is a deliberate act with a diff.

---

## Queue state machine

`draft` · `waiting_for_connection` · `sending` · `synced` · `needs_attention` ·
`cancelled`

**There is deliberately no `failed`.** A conflict is not a failure — it is a
question for a person: the amount changed, the permission went away, the branch
moved. Calling it "failed" invites the app to retry it and invites an employee
to ignore it.

Each item stores its operation type, client UUID, company, branch, user, payload
version, creation time, last attempt, attempt count, a plain-language summary
safe to show in a list, and its last classified error. **Access tokens are never
persisted inside a queued payload.**

---

## Replay rules

On reconnect, foreground, or manual retry: verify the authenticated user, the
company and the branch; refresh effective permissions; then process FIFO within
a dependency group, reusing the original client UUID.

- A server's idempotent replay is **success**, not a duplicate.
- Validation, authorization and conflict failures **stop**, and the item becomes
  `needs_attention`. They are never retried, and the payload is never quietly
  edited to make one pass.
- Only transient network and server failures back off, exponentially, capped at
  five minutes, bounded at eight attempts.
- A timeout is retried **with the same client UUID** before anybody is told to
  create another record — the retry either creates it or finds the record the
  lost response was about.

Items in different dependency groups are independent: one stuck expense must
never freeze every notification. Items in the *same* group hold each other back,
so two reports against one loan reach the server in the order the shop made them.

Session identity is re-checked at replay, not merely at enqueue. A shared
counter phone changes hands; branches switch; roles are revoked. Replaying under
the wrong one of those attributes a shop's money to the wrong person.

---

## Storage and privacy

No new dependency was added. `expo-file-system` was already installed and is
first-party Expo, which the audit preferred over introducing a queue library.

- The queue is keyed by **user, company and branch**; one user cannot see
  another's drafts.
- Nothing replays under a different company or branch.
- Passwords, OTPs, refresh tokens and image bytes are never written to the
  general queue.
- Corrupted queue data **fails closed** — an unreadable file is quarantined
  rather than guessed at.
- The queue schema is versioned, so a payload written by an older build is
  recognised rather than misread.

Whether unsynced drafts survive logout, and how the same authenticated user
recovers them, is documented alongside the implementation.
