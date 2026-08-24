# 35 — Sign-in identity audit and decisions (CP3)

> Audited **before** any schema was designed, because the shape of the data
> decides whether a second identity model is needed at all.

---

## What the audit found

| Question | Answer |
|---|---|
| Does a personal login ID already exist? | **No.** Nothing resembling one, in any table |
| Does a global identity model exist? | **No.** `User` is company-scoped and that is the only user table |
| Is `login` globally unique? | **No** — `@@unique([companyId, login])`. Two companies may both have an `owner` |
| Is `phone` globally unique? | **No** — `@@unique([companyId, phone])`. The model permits one phone in two companies |
| Duplicate phones in the data today? | **None** — see below |
| **Users with a phone number** | **0 of 10** |

### The finding that decides the design

**Not one existing user has a phone number.** All ten are `NULL`.

A phone-only sign-in would lock every existing account out of the product on
the day it shipped. The generated personal ID is therefore not a convenience
for people who dislike typing a number — for this installation it is currently
the **only** way anybody can sign in, and the backfill that creates one for
every user is the migration's whole point.

### Ambiguity is possible in the model, absent from the data

There is one company, so no phone is shared across companies today. But
`@@unique([companyId, phone])` means the model **permits** it, and a second
company created tomorrow could reuse a number. The login contract therefore has
to handle the ambiguous case even though no row exhibits it — proving it from
the data is not possible, so it is proven from a fixture instead.

### Two identifiers, already distinct

`companies.public_store_id` already exists and is already generated — the Store
ID the brief describes is not new. What is new is a **personal** login ID, and
the audit confirms the two concepts do not currently overlap anywhere.

---

## Decisions

### One User table, extended

No second model. The audit shows no global identity to reuse and no reason to
split one out; a parallel user table would duplicate every foreign key and
every audit reference for no gain. `users` gains one column.

**Password hashes stay exactly where they are.** Nothing is moved into a
globally searchable table — a lookup table of every credential in the
installation is precisely what an identity refactor must not create.

### Personal ID format

A prefixed random code: **`U-` followed by 8 characters** from an alphabet with
the ambiguous glyphs removed (`I`, `L`, `O`, `U`, `0`, `1` are all absent).

- **Not the binary id.** A `BINARY(16)` UUIDv7 is not readable, not dictatable
  over a phone, and leaks creation time.
- **Not sequential.** Random, so one ID never suggests another.
- **Cannot be mistaken for a phone number**: it starts with a letter, and no
  phone normalisation produces a leading `U-`.
- **Case-insensitive**: stored and compared uppercase, so a shopkeeper reading
  it off a note need not care.
- Globally unique, enforced by the database rather than by application code.

### Backfill

Every existing user receives one, generated with cryptographic randomness and
retried on collision. Nobody is left unable to sign in — which, given that no
user has a phone, is the difference between the change working and locking the
shop out of its own product.

---

## Left as they are

- **`login`** is untouched. It is still how the legacy endpoint resolves a user,
  and removing it would be a second migration inside a login change.
- **Phone verification** is not claimed. `phone_verified_at` exists and stays
  `NULL`; nothing in this change asserts a number was verified, because no
  verification process runs.

---

## What was verified, live

Against a running API and MySQL, on **2026-08-24**: 35 checks, all passing.
The harness created its own probe users and a second company, then removed
every one of them; nothing it made survives.

**Signing in** — by phone; by personal ID; a personal ID in lower case; a phone
typed with spaces. All resolve.

**Nothing is enumerable** — an unknown identifier, a real identifier with the
wrong password, and a disabled account produce a byte-identical failure. No
response names a shop or a person. A Store Account ID offered as an identifier
is refused like anything else. Rate limiting still bites (10/minute per IP), and
the successful-login record (`last_login_at`, plus the session row carrying IP
and user agent) survived the rewrite.

**Headers are not trusted** — a login carrying a forged `x-company-id` for a
different company resolves to the credential's own company, not the header's.

**One phone, two shops** — returns a chooser and no tokens; offers exactly the
two real memberships; names no user or company id; and a **wrong** password on
the same number reveals no shop names at all. The continuation token expires in
120s, is refused when tampered with, is refused for an account outside the
offered list, and is rejected outright as an access token.

**The resulting session is real** — `/auth/me` identifies the right person and
returns the personal ID; entitlement resolves; logout revokes the refresh token.
No password hash appears in any response.

**Identifiers** — all users well-formed and distinct; no ambiguous glyph in any
of them; the unique index exists in the database; 40 concurrent creations
produced 40 distinct IDs.

## Known gaps

- **No physical-device run.** Everything above is HTTP, MySQL, and a browser.
- **The chooser has never been exercised by a real person**, only by probes —
  no user in this database has a phone number yet, so the path is unreachable
  in practice today.
- **`settingsprobe` and three `i2p9b1b04_*_spent` accounts** remain in the demo
  database from earlier sessions. All are inactive. They pre-date this work and
  were left alone rather than deleted without authorisation.
