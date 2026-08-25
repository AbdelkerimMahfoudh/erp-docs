# 36 — Signing in with a contact, and the transition to it

> Companion to [`docs/35`](35_AUTHENTICATION_IDENTITY_AUDIT.md), which recorded
> why the generated personal ID exists. This one records why it is no longer
> offered, what replaced it, and the one narrow path that keeps five people able
> to reach their own shop.

## What the ordinary sign-in asks for

Exactly three things: **one identifier**, a **password**, and **Sign in**.

The identifier is an **email address or a WhatsApp number**. One or the other —
never both, and never anything else. In particular the screen does not ask for,
and the drift test refuses to let it ask for:

| Refused | Why |
|---|---|
| Store ID | A shopkeeper should not have to know their business's identifier to reach their own till |
| Branch ID | The server resolves it after the credential is verified |
| Company ID | Same, and an unauthenticated request must not name a tenant |
| Personal ID | Generated, so it must be *told* to somebody — the opposite of a contact they already know |
| Username / login alias | One more thing to invent, remember and forget |
| Email **and** phone together | Two fields to fill where one will do |

## "WhatsApp number" is a label, not a claim

The UI says WhatsApp because that is what a shop calls the number they are
reachable on. **Technically it is a normalised phone identifier and nothing
more.** Nothing in the product proves the number is registered with WhatsApp,
reachable on it, or verified in any way, because no verification service exists
yet. `phone_verified_at` stays `NULL` and is set only by a real verification
event.

This distinction is deliberate and must survive: the moment the product claims
a number is "verified WhatsApp" without a service behind it, the claim is a lie
that somebody will rely on.

## Normalisation

**Phone.** One canonical E.164 form. `43210987`, `43 21 09 87`, `43-21-09-87`,
`+222 43210987` and `+22243210987` all reach `+22243210987`. Enrolment and
sign-in share the same parser — two normalisers either side of one column would
mean a number enrolled one way could not be typed the other.

**Email.** Trimmed and lowercased. The case rule is **the database's, not an
invention**: `users.email` is `utf8mb4_0900_ai_ci`, case- and accent-insensitive,
exactly like `login` and `personal_id` before it. `Owner@Shop.mr` and
`owner@shop.mr` were already one row to MySQL for both the unique index and the
lookup; storing the lowered form only makes what is written match what is
compared.

RFC 5321 permits a case-sensitive local part. No provider anybody uses treats it
that way, and honouring it would let `Ali@shop.mr` and `ali@shop.mr` become two
accounts that cannot both sign in — a foot-gun bought with a technicality.

Validation is deliberately permissive. Refusing a legitimate but unusual address
is a support call; a typo is caught immediately by the sign-in simply failing.

## Uniqueness

Migration `0055` adds `@@unique([companyId, email])` — **per company, not
global**, exactly the rule `phone` already carried.

Global uniqueness would have been the wrong answer. One address genuinely
belongs to a person who works at two shops, and refusing that at enrolment
would break the password-first account chooser the previous checkpoint built.
With the per-company rule, that person types their email, the password is
verified, and only then are the two shops named.

Safe on existing data: every row had `email IS NULL`, and MySQL permits any
number of NULLs in a unique index.

## The transition — why the personal ID is still accepted

**Every active user had neither an email nor a phone.** Not most: **five of
five**, audited before any code changed. Restricting sign-in to email or
WhatsApp would have locked 100% of the people using this system out of it.

So the personal ID remains **accepted by the server and offered by nothing**:

- it is not a field, a label, a hint or a placeholder on the sign-in screen;
- it is not documented to users as a way in;
- it is not advertised in Settings as a login method — Settings shows it as the
  identifier it is, so somebody who has no other way in can find it;
- a drift test fails the build if it reappears in the login component.

It is a ramp, not a feature.

### Removing it

The path comes out when **no active user is without a contact**. Check with:

```sql
SELECT COUNT(*) FROM users WHERE is_active = 1 AND deleted_at IS NULL AND email IS NULL AND phone IS NULL;
```

While that count is above zero, removing `personal_id` from
`classifyIdentifier` locks somebody out. When it reaches zero, the classifier's
`personal_id` branch and its tests can go. **The column and its unique index
stay** until something proves nothing reads them — they cost nothing, and
`personal_id` is still a useful support reference.

## Enrolling a contact

`PATCH /v1/users/:id` accepts `email` and `phone`. Both may be stored; **one is
required** for any newly created user — `UsersService.createUser` refuses
otherwise, in the service rather than a DTO, so the seed and the CLI cannot
walk around it.

**Never invent a contact for a real user.** An address nobody owns is worse than
no address: it cannot receive a recovery message, and it looks like a working
one. Seed and demo accounts use clearly non-production values
(`*.invalid`), which by RFC 2606 can never resolve.

## Changing a login contact is a security event

Not an edit like a name. Four rules, all enforced server-side:

1. **The actor re-types their own password.** A session proves a device was
   authenticated once; it says nothing about who is holding it now, and an
   unlocked till on a shop counter is the ordinary case. The **actor's**
   password, not the target's — an Owner correcting an employee's number does
   not know theirs, and demanding it would push shops toward sharing passwords.
2. **The target's sessions end.** Their credential just changed. If the change
   was made because an account was compromised — the ordinary reason anybody
   edits a contact in a hurry — leaving the old sessions alive would leave the
   attacker signed in.
3. **The last contact cannot be removed.** Conditional on having one *now*, so
   the contactless legacy accounts can still be renamed or deactivated.
4. **The change is audited**, and any stale `*_verified_at` mark is cleared.

## What did not change

Every protection from the previous checkpoint is intact and re-verified live:
generic invalid-credentials responses, rate limiting (10/min per IP), no account
enumeration, ignored spoofed tenant and branch headers, password verified before
any shop is named, a purpose-bound 120-second chooser token, disabled users
refused, entitlement enforced after authentication, session and device
revocation, and the successful-login record.

The server, not the client, resolves the tenant.

## Two-step verification — the direction, not a toggle

2FA does **not** exist, and no switch pretends otherwise. A control that saved a
preference and protected nothing would be worse than its absence, because
somebody would trust it. A test refuses any 2FA UI until it is real.

When it is built:

- **optional per user**, not forced on a shop;
- lives under **Account & security**;
- delivered by **verified email or verified WhatsApp/phone** — which requires
  the verification service that does not exist yet, and is the actual blocker;
- needs real code delivery, expiry, retry limits, recovery when the device is
  lost, and trusted-device rules.

The settings architecture has room for it. Nothing is shipped until all of that
is.

---

## Registration now creates contacts from the start

Self-service registration (`docs/37`) requires **at least one** of email or
WhatsApp number, enforced in `RegistrationService` before anything is created.

So the contactless population is closed: it is exactly the five accounts that
pre-date contact login, and it can only shrink. No path creates another.

The query that says when the legacy personal-ID path can be removed is
unchanged, and **still returns 5**:

```sql
SELECT COUNT(*) FROM users WHERE is_active = 1 AND deleted_at IS NULL AND email IS NULL AND phone IS NULL;
```

Registration also generates a personal ID for every new Owner, as before. That
is a support reference, not a login method: it is not shown during registration,
not returned by the registration response as something to sign in with, and not
mentioned anywhere in the new surfaces.
