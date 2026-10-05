# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Owner: **NONE**
- Last session: **CLAUDE-B** (a claude.ai cloud session), `2026-10-05T01:39Z` → `2026-10-05T02:40Z`, taken from
  `READY_FOR_HANDOFF` (the previous handoff was complete); its work is complete, verified and pushed.
- **The phase just finished (the user's brief of 2026-10-05): the external subscription management separation** —
  subscriptions are acquired, paid, renewed and administered on a separate website; the customer app only reads the
  server's business-access state and shows it in neutral words. The Super Admin console and self-registration are out of
  the app; the server refuses a registration it cannot finish; the public price route is gone; payment instructions
  serve no stand-in; an expired shop sees one coherent read-only app; the website is a **contract** (`docs/68`), not a
  product. Record: `docs/21` (2026-10-05), `docs/68`, `docs/48` §14, `docs/67` §9, `docs/24` §55. **Nothing was
  deployed, migrated on live, submitted or published; no website was built; Bankily and WhatsApp stay non-operational.**
- **GO / NO-GO (`docs/67` §8–§9): unchanged** — internal TestFlight GO once the owner's three inputs exist; external
  TestFlight and the public App Store NO-GO (RC-01 deletion needs D116; RC-04, RC-06, RC-07, RC-08, RC-09). RC-02 and
  RC-03 are closed by D117 and D118.
- **The gate (`docs/48` §14) is NOT PASS** (external prerequisites and the independent assessment).

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
