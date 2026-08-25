# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Active account / Owner: **CLAUDE-B**
- `started_at_utc:` `2026-08-28T00:00Z`
- **Authorised task — a private staging environment** for the control website,
  the API and the mobile account-creation integration, so the Owner can test the
  whole workflow from a real browser and phone without exposing the
  administration system or touching the demo database.
  **Do not begin the IMEI scanner milestone.**
- HEADs at takeover — `erp-backend` `7f12a08` · `erp-mobile` `d9d912d` ·
  `erp-docs` `d375847` · `retail-erp-control-web` `593b0b8` (no remote).

### Baseline verified — every expectation matched

| Expected | Found |
|---|---|
| Backend 94 suites / 1650 tests | ✅ exactly |
| 57 migrations, highest `0058` | ✅ |
| Mobile 19 pure suites, 30 drift assertions | ✅ |
| EN/AR/FR 1752 keys each | ✅ identical order |
| Website 14 contract tests, build green | ✅ |
| Website at `593b0b8`, no remote | ✅ |
| Three repos clean, pushed, level | ✅ |
| `READY_FOR_HANDOFF`, owner `NONE` | ✅ |

One small thing fixed on the way in: the website's `vitest` config still used
`poolOptions`, **removed in Vitest 4**. It was silently deprecated and the
runner intermittently reported "no tests" instead of running them. Moved to the
top-level `maxWorkers`/`minWorkers`; three consecutive runs now report 14/14.

### Read-only discovery — what already exists

| Thing | Found |
|---|---|
| Git hosting | GitHub, authenticated as **AbdelkerimMahfoudh**, scopes include `repo` and `workflow`. The three existing repositories are already under it |
| Hosting provider | **Railway CLI authenticated**, but as **abdelkerimtalebouldsidi@gmail.com** — a different identity from the GitHub account. One project exists: "Academie Navale", unrelated |
| Domains / DNS | **None.** No DNS tooling, and no domain configured anywhere in any repository |
| Containers | **No Docker, no Podman, no kubectl** |
| Reverse proxy | **None installed** |
| Secrets management | None beyond local `.env` files, which are git-ignored |
| CI | **No workflows** in any repository |

### 🛑 Two external decisions are ambiguous — stopping before those mutations

1. **Hosting.** Railway is authenticated, but under a different identity from
   the GitHub account, and its billing state cannot be read without risking a
   mutation. A staging stack there is an API service, a website service and a
   **MySQL database** — enough that "no new unknown charge" cannot be promised.
2. **`/admin` private access.** No identity-aware proxy, VPN or IP-allowlist
   mechanism exists. The brief is explicit that an obscure URL is not
   protection, and that administrator MFA does not exist — so `/admin` must not
   be exposed to the internet in this state.

Per the brief: every provider-neutral artifact is being completed regardless,
and a **local isolated staging environment** is being stood up so the workflow
is genuinely testable now.

### Next intended action

Create the private GitHub repository for the website (unambiguous), build the
provider-neutral staging artifacts, stand up isolated local staging, then report
the hosting decision.

## Entitlement and grace semantics (K)

States are derived from a **server clock**, never the device:

| State | Meaning | Writes |
|---|---|---|
| `active` | Paid period running | ✅ |
| `grace` | Exactly **72 hours** past the period end, **derived** from it so the two cannot drift | ✅ |
| `expired` | Grace over | ❌ |
| `complimentary` | Platform grant, audited, never self-grantable | ✅ |

**Writes continue through grace** — a shop three hours past renewal is still
open, and refusing its sales over an administrative boundary would cost it real
money.

### What expiry does and does not do

Authentication works · history reads · exports work · branch selection and
sign-out work · the subscription screen explains itself. **Nothing is deleted or
hidden.** Only new business truth stops, refused with the stable code
**`ENTITLEMENT_WRITE_BLOCKED`** — the app never parses English.

### Queue behaviour after expiry

The entitlement refusal is **non-transient**. A queued report that hits it moves
straight to `needs_attention` and **stops**. It cannot loop, because retrying
cannot resolve the condition, and a phone quietly retrying forever is both a
battery problem and a lie about progress.

### Seats

500 MRU per subscribed branch · **2 included non-Owner seats per branch, pooled
company-wide** · Owner consumes none · extra seats 100 MRU, not prorated · no
trial · annual deferred.

**Nobody is ever deactivated automatically.** A company over its limit keeps
every employee, is told, is blocked from adding more, and decides for itself who
stays. Seats are checked at the moment of activation, so two Owners filling the
last place at once cannot both succeed. Deactivating is never blocked, or a
company would be trapped over its limit.

**A tenant Owner cannot self-grant.** Provisioning skips the tenant JWT guard
and is gated on a platform key no tenant holds; an unset key **closes** the
surface rather than opening it.

---

## Analytics accounting dictionary (L)

Seven categories, kept visibly apart: **profit · cash · liability · receivable ·
inventory · discrepancy · workflow**.

| Event | Profit | Cash |
|---|---|---|
| Sale | ✔ | ✔ |
| **Return approved** | ✔ revenue out **and** COGS credited | — |
| Refund reported | — | — |
| **Refund confirmed** | **✗ already counted at approval** | ✔ |
| Purchase received | ✗ | — (creates a payable) |
| Supplier payment confirmed | ✗ | ✔ |
| Expense confirmed | ✔ | ✔ |
| Consignment disposition | ✔ | — |
| **Loan / consignment principal** | **✗ never revenue or expense** | ✔ |
| **Closing discrepancy** | **✗ a question, not a loss** | ✗ |

**Never manufacture a figure.** A metric with no canonical source is *named as
unavailable*, not defaulted to zero — a shop cannot tell a measured zero from a
number nobody calculated. Reported this way: refund liability, supplier
liability, commissions and fees, per-channel expected movement, unattributed
legacy payments.

**Comparison** is against the immediately preceding period of equal length,
sharing no day with it. A zero base returns **unavailable**, never infinity and
never a percentage.

---

## Unresolved — device-only, and unrun

**Every device check in [`docs/24`](docs/24_DEVICE_QA_CHECKLIST.md) under
Milestones H, I, J, J.1, K and L is unrun.** They need real hardware:

- airplane mode, Wi-Fi with no internet, a stopped API
- a real Android low-memory kill with drafts pending, and process eviction
- reconnect, background/foreground, and that neither triggers OTP
- two accounts on two devices for consignment, loans and privacy
- the shared counter phone: sign out, sign in as somebody else, sign back
- Arabic RTL across every new screen
- whether a first-week employee reads "waiting to send" as anything but *sent*

**No claim is made about any of them.**

## Remaining product and release risks

1. **React Query caches are memory-only.** A cold start offline shows empty
   lists rather than stale ones. Deliberate: a persister showing stale prices
   and stale stock confidently is its own kind of lie, and it belongs in a
   milestone that can think about staleness properly.
2. **No user-creation route exists** — only `PATCH /users/:id`. Seat enforcement
   therefore binds on reactivation, which is the only seat-consuming path there
   is. When invitations arrive, they must call the same check.
3. **Refund and supplier liabilities have no single canonical total.** They are
   reported as unavailable rather than computed a second way. If a shop needs
   them as figures, they need a canonical owner first.
4. **`npm audit` reports 24 vulnerabilities (10 moderate, 14 high)** in the
   mobile dependency tree, pre-existing and untouched by this session. Not
   assessed. Worth a look before a release candidate.
5. **Commissions and fees have no model at all.** Nothing about them is
   reported, and adding them is a schema decision, not a reporting one.

## Next action

**A remote for the website**, then a physical-device pass.

```bash
git -C retail-erp-control-web remote add origin <url>
git -C retail-erp-control-web push -u origin master
```

Then work [`docs/24`](docs/24_DEVICE_QA_CHECKLIST.md) from the top on a real
phone — the Create-account handoff, the three subscription-state screens, and
the website in a phone browser have all been verified in a desktop browser and
**none of it on a device**.

Four things to know before touching this:

1. **The website computes no price.** Every figure is the server's, and a test
   refuses any component that multiplies a unit price.
2. **No credential may reach browser storage.** Exactly two keys are allowed,
   both preferences; a test enforces it.
3. **Plan versions are never retroactive**, and billing periods copy their unit
   prices. Editing a past price is not possible by design, not by convention.
4. **The five contactless legacy users still exist** and still rely on the
   hidden personal-ID sign-in. `docs/36` has the query that says when it can go.

To run everything:

```bash
cd backend && npm run start:dev
```

```bash
cd retail-erp-control-web && npm run dev
```

```bash
cd mobile && npx expo start
```

To create a platform administrator (never paste a real password anywhere):

```bash
cd backend && PLATFORM_ADMIN_PASSWORD='…' npx ts-node prisma/create-platform-admin.ts you@example.com "Your Name"
```
