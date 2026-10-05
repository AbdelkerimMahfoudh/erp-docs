# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Owner: **CLAUDE-B** (a claude.ai cloud session)
- started_at_utc: **2026-10-05T03:22Z**
- Taken from `READY_FOR_HANDOFF`, owner NONE — the previous handoff (CLAUDE-B, 2026-10-05 02:40Z, the subscription
  separation) was **complete**: all three working trees clean and level with their remotes at the HEADs below, verified
  against `git fetch` before this line was written.
- **Active phase and scope (the user's brief of 2026-10-05, 03:21Z):** (A) the external business and subscription
  website built from scratch in its own repository (no website existed anywhere this session can reach); (B) employee
  accounts created from Team in the app, contact verification of every selected channel enforced on the server, and the
  new seat rule — one free employee seat per store, the Owner excluded, 100 MRU per additional seat per store, paid and
  verified before activation; (C) the file-based stock intake creates and links a missing product in place, and Import
  stock moves from More to the Stock tab; (D) the Arabic restart notice reflects the real direction; (E) Notifications'
  nested list and its empty error toast; (F) every gate, browser screenshots of the website, docs, session log, handoff.
  **Out of scope, by instruction:** live data or migrations, publishing the website to a production domain, an iOS
  build, any claim that Bankily, WhatsApp or email delivery works without real configuration.
- Next intended action: report the takeover discrepancies, then backend → mobile → website → docs, committing on the
  release branches only after verification.

## HEAD now

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | *this commit* | level | 0 |
| `erp-backend` | `reports-export` | **`7283844`** | level | 0 |
| `erp-mobile` | `reports-export` | **`6f6ef47`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` — on the owner's PC only, **no remote**, not touched (as last recorded) | — | — |

Backend this session: `7283844` (the quote route removed; payment instructions unavailable until a real code, the boot
assertion wired; registration refused up front without a channel; device revocation allowed after expiry). Mobile:
`7fdbd36` (`*.css` declared — `tsc` clean), `d761926` (the console and self-registration out), `6f6ef47` (business access
screens, the read-only state, the boundary tests). Docs: `94e599e` (takeover), this commit. **No migration was written;
live is still at 0083** (0084 and 0085 owed — runbook `docs/67` §7). Draft PRs unchanged: backend #2 and mobile #2
**superseded** (close them); backend #1 (the QA seed) and mobile #1 (*Catalog leaves More*, D126) unchanged. In this
cloud container only: `/home/user/erp-backend-seed` is a git worktree at `d88893a`; every database, server and secret of
this phase is gone.

## What changed

| Where | Now |
|---|---|
| **The customer app's boundary** | no platform console, no self-registration, no price, seat price, payment method or instruction, no purchase / renewal / extension action, no website or payment link, no plan, no billing control, no in-app purchase — pinned by `lib/access-boundary.test.ts` and the exported-bundle audit |
| **Business access** | `/access` (status: state, date or grace deadline, *Managed by your organisation*, the mistake line) and `/access-closed` (pending / suspended / not approved / ended, with Check again, Sign out, Delete account); EN/FR/AR |
| **Read-only shop** | one `AccessNotice` on Home, Partners, Money, Stock and More; Sell, Receive, Open store, Add expense, money positions, Lend, Consign and the Daily closing's writes withheld; 17 write-only screens redirected to `/access`; a slipped-through write named as ended access |
| **Grace** | the app as usual, one restrained notice with the server's exact deadline |
| **Sign-in** | *Accounts are set up by your organisation's administrator.* — no Create account, no console link |
| **Backend** | `GET platform/quote/:id` removed; `platform/payment-instructions` → `available: false`, no provider, no code; production boot refuses a stand-in; `POST platform/register` → `503 registration_unavailable`, nothing saved, when no code can be delivered; `DELETE devices/*` allowed after expiry, `adopt` still blocked |
| **Unchanged, by design** | every entitlement check on the server (`ENTITLEMENT_*`), the administrator realm, step-up, versioning and audit; `platform/my-subscription` and the portal handoff for the website; a shop's own Cash / Bankily / accounts |

## Verification

| Kind | Result |
|---|---|
| **Gates** | backend `tsc`, 181 suites / 3 264 tests (3 skipped), `prisma validate`, `migrate status` up to date (disposable, 84 migrations), permission catalogue complete; mobile `tsc` **clean (no known error)**, 87 / 87 suites, lint 0 errors / 29 pre-existing warnings, Expo Doctor 19 / 21 (two network checks blocked), parity 3 255 × 3, web export 79 pages / 71 routes all present, bundle audit 15 / 15 |
| **Real HTTP (disposable, dev- and production-mode APIs)** | **87 / 87** — `docs/68` §10 (pending, approval, roles, grace, the ±20 s boundary, read-only, suspension, reinstatement, concurrent and contradictory decisions, refusal, isolation, realm separation, production refusals) |
| **Not run** | any iPhone (`docs/24` §55), anything on live, the website |

## 🔴 Release blockers (`docs/67` §2, §9)

RC-01 deletion cannot complete in production (D116) · RC-04 no HTTPS host · RC-05 live at 0083 · RC-06 nothing on an
iPhone · RC-07 the security gate · RC-08 no privacy policy · RC-09 demo business for review, export compliance, privacy
manifest, iPad. **Closed this phase:** RC-02 (no registration in the app; refused on the server) · RC-03 (D118 decided).

## 🟡 The owner's decisions

**New:** **D133** — confirm the commercial reading: one subscription per company, priced per branch (every active branch
500 MRU; two staff per branch pooled; 100 MRU per additional account, a whole month; no trial; 72 h grace). A separately
dated subscription **per branch** would be a schema change to plan, not a wording fix. **Also owed:** the website
repository (push `retail-erp-control-web` to a remote, or a fresh one) and the inputs of `docs/68` §7 (domain, DNS, TLS,
hosting, an email provider, the Bankily agreement, MFA, legal texts). **Still open from before:** D116 (deletion without
WhatsApp), D120–D128, D115. **Resolved this phase:** D117, D118; D119 implemented.

## 📋 Known, not fixed

`platform/my-subscription` answers any tenant session, a Manager's included — the website must show the account page to
the Owner only (`docs/68` §2). Create a business, invite its Owner, approve, refuse and correct a period have **no UI**
until the website carries them (`docs/68` §8 gives the API calls). Everything in `docs/67` §2 RC-10 … RC-27 and the
older backlog is unchanged.

## The next exact action

1. **Take ownership** (`IN_PROGRESS`, the account, the UTC instant, the three HEADs above).
2. **With the owner:** D133 (confirm the commercial reading), the website repository and `docs/68` §7's inputs, then
   D116 and the other open decisions; close draft PRs #2 (superseded).
3. **The website**, when its repository and inputs exist: implement `docs/68` v1.0 (approve / refuse / create / invite
   first — they have no UI today), with the Owner-only account page and no client-side price.
4. **Live, only with the owner's written approval and someone at the PC:** `docs/67` §7 — 0084 and 0085, then the API on
   backend `7283844`; the phone reloads mobile `6f6ef47`.
5. **A build and the device run:** `docs/24` §55 (business access) with §54 on an iPhone SE and a large iPhone, in EN, FR
   and AR.
