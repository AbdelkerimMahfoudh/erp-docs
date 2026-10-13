# CURRENT_HANDOFF

Status: IN_PROGRESS
Owner: CLAUDE-B (cloud session)
started_at_utc: 2026-10-13T03:13Z
previous_handoff: READY_FOR_HANDOFF / NONE from CLAUDE-B (local, the owner's Windows PC), 2026-10-12T10:00Z → 15:30Z —
complete; all four trees were clean and level with their remotes at takeover
active_phase: the website-only seven-day free trial (the owner's brief of 2026-10-13, with its customer-discovery
addendum)

## HEAD of every repository at takeover

| Repository | Branch | HEAD at takeover |
| --- | --- | --- |
| `erp-backend` | `reports-export` | `aad5862` |
| `erp-mobile` | `reports-export` | `02f2e4e` |
| `erp-control-web` | `tsx-public-site` (**not merged**; `main` still `0417bfe`) | `e892a27` |
| `erp-docs` | `master` | `db3f94a` |

## Scope approved by the owner (2026-10-13)

The plan was explained (findings, design, files, risks) and approved with three decisions:

1. **Business sign-up returns to the app** — reverses D117. Creating the account in the app never starts a trial.
2. **Businesses created by the Super Admin are not trial-eligible**; only self-registered new businesses are.
3. **Paid access approved during a running trial starts when the trial ends** (the trial is never shortened,
   extended or rewritten).

Binding from the brief: the trial is claimed and activated **only on the website**, by the Owner, once per business,
starting at the server's claim instant and ending exactly 168 hours later; no payment, no billing record, no grace, no
renewal, no Super Admin approval; existing businesses get no trial; disposable data only.

**Owner correction (2026-10-13, later the same day), binding:** the mobile app is **display-only** for the trial — no
trial-related action button of any kind (no claim, no *Resend instructions*), no website link, QR code, WebView, claim
token, claim API call, price or payment instruction; it shows only eligibility, "not started", the seven-day duration,
whether the instructions were sent, the masked verified destination and an honest unavailable status. Setup
instructions are sent **automatically** after contact verification; resending happens only after the Owner signs in on
the **website** (or through the existing support process). **No Origin/Referer check** is used as a security boundary
(none is implemented): the claim is protected by Owner authority, verified contacts, eligibility, the one-time token,
idempotency, locking and audit. Trial instants are stored in **UTC** and shown in the **business's configured time zone**
(never hardcoded). The exported mobile bundle test must prove every forbidden trial action absent. Working contract:
the session's `SPEC.md` (scratch); its content goes into `docs/76` at the end.

**Owner clarification (2026-10-13), binding:** website sign-in works **without** the message link. An eligible Owner who
opens the website independently, signs in normally and has verified the required contacts sees the same trial card and
can start the trial after explicit confirmation — whether the message was lost, failed, expired or consumed, or the
device changed. The token only continues to the right page after authentication; it never activates anything; previews
consume nothing; an expired or invalid token never removes eligibility; delivery is never a second eligibility
requirement. **Integration with the concurrent identity phase:** no blind merge — inspect the exact diffs and HEADs,
keep both changes, resolve overlaps deliberately, rerun the complete combined gates, never force-push, and record the
final combined commit ancestry here.

## Databases

- `phonestore` (the PC's development database, 3308): still at `0091_stabilization` — not touched by this session.
- No live/production database exists or will be touched. Migration `0095` (planned) is rehearsed only on a disposable
  MySQL inside this cloud container, with a backup and a restore check first (`docs/22`).
- Migrations 0092–0094 exist in `reports-export` and are not applied to the PC database; deploy the API and 0092–0094+
  together.

## Next intended action

In progress (nothing committed yet in any code repository): backend — migration `0095_free_trial`, the computed trial
states, the claim, setup links and automatic delivery, the website-only resend, the restored app registration routes,
the deferred paid start; website — the Owner's trial card, `/account/trial`, console facts; mobile — restored sign-up and
the display-only eligibility card with a committed bundle audit. Then review, migration rehearsal with backup/restore
on a disposable MySQL in this cloud container, real HTTP (incl. the 168-hour boundary), screenshots, docs.

## Blockers carried over (`docs/75` §13)

Credentials (WhatsApp WABA/number/token/app secret/approved EN-FR-AR templates; email provider and a sending domain;
`PLATFORM_MFA_KEY` per environment) · the backup retention period · legal review (privacy, terms, deletion, TSX-MR's
identity) · the owner's decision on the app identifiers · Dukan ERP WhatsApp template texts · logo (four concepts
delivered; awaiting the owner's choice).

## Concurrent phase — CLAUDE-B (local, the owner's Windows PC): the final technical identity — COMPLETE

**Status of this phase: COMPLETE.** It is ready for handoff on its own scope, with no owner (finished 2026-10-13T05:25Z).

**Why the status at the top stays IN_PROGRESS.** The brief asked to restore `READY_FOR_HANDOFF` / `NONE`, but the
status at the top belongs to the free-trial phase, which is still working in the cloud with no code pushed. Setting the
whole file to `READY_FOR_HANDOFF` / `NONE` would invite another session onto that unfinished work, so it was not done;
the discrepancy is reported to the owner. The free-trial phase's checkpoint already plans the deliberate integration:
exact diffs, both changes kept, the combined gates, its final ancestry recorded here.

### HEADs at the end of this phase

All are pushed and every tree is clean.

| Repository | Branch | HEAD |
| --- | --- | --- |
| `erp-backend` | `reports-export` | `5bdba80` |
| `erp-mobile` | `reports-export` | `9af0401` |
| `erp-control-web` | `tsx-public-site` (**not merged**; `main` `0417bfe`) | `72b1be8` |
| `erp-docs` | `master` | the commit carrying this section |

### Commits

- **Docs claim:** `9dff495`.
- **Mobile:**
  - `0a94e13`: identity, iOS prompt texts, `lib/app-identity.test.ts`, `__tests__/deep-links.test.tsx`;
  - `9af0401`: a reference fix.
- **Backend:**
  - `33b671c`: names;
  - `8e4a372`: QA script recovery code, a person's enrolment left alone, closed-socket resend;
  - `5bdba80`: QA script closes only its own sessions.
- **Website:** `72b1be8`, the README.
- **Docs (this commit):** D168 amended; `docs/24` §65; `docs/44` (the operator's steps); `docs/64` (template drafts
  say Dukan ERP); `docs/67`; `docs/74`; `docs/75` §15–§19; `docs/patches/boutiques-local-0094.patch`; `SESSION_LOG.md`.

### Identity

The product is Dukan ERP, operated by TSX-MR:

- slug `dukan-erp`;
- scheme `dukanerp`, with no alias;
- iOS bundle identifier and Android package `mr.tsxmr.dukanerp`.

**No earlier store identity existed:**

- no App Store Connect record;
- no Google Play app;
- no production or iOS build;
- no push credentials;
- no update channel;
- only three internal Android preview builds.

**The EAS project `834d8b25` is kept as it was, and blocked.** Its slug cannot change, so every EAS command waits for the
owner to link a `dukan-erp` project (`docs/44`). `expo start` is unaffected.

**The logo is not in the repository**, so a build shows the template icon. It is a release blocker.

This resolves the "owner's decision on the app identifiers" listed among the blockers above.

### Database and migrations

- No migration was added.
- `phonestore` is still at `0091_stabilization`.
- 0092–0094 were applied only on disposable copies, every one dropped. Deploy the API and 0092–0094 together: the
  previous API's exchange insert is still refused by the 0092 CHECK.

### Verification

- **Real HTTP:** **51 / 51 (HTTP 43 / 43, database integrity 8 / 8)** on a fresh copy, run `1e4bbd` (`docs/75` §16).
- **Mobile:**
  - `tsc` 0; lint 0 errors;
  - pure tests 279 / 279; render 188 / 188;
  - parity 3 742 × 3;
  - the release bundles' identity audit passes, as does the prebuild inspection;
  - Expo Doctor 20 / 21: patch versions behind, pre-existing;
  - web export blocked by Smart App Control.
- **Backend:**
  - `tsc` 0;
  - Jest 212 suites, 3 861 passed, 3 skipped;
  - permission catalogue 73 / 73;
  - secret scan clean.
- **Website (CI run 38344708273):**
  - all green: Vitest 119; Playwright 58; links 0 broken; gitleaks clean;
  - no old name in the build.
- **Device: not verified** (`docs/24` §65 needs a new native build).

### Points of contact with the free-trial phase

These are the files this phase changed that the free-trial phase may also change:

- **`erp-mobile/app.json`:** identity fields, the `expo-secure-store`, `expo-camera` and `expo-image-picker` plugin
  options.
- **`package.json` / `package-lock.json`:** the `name` field only, in mobile and backend.
- **The mobile tests:**
  - `__tests__/deep-links.test.tsx` reads the real route tree, so restored registration routes are included
    automatically;
  - its "no secret in a link" checks scan every route's parameters;
  - its signed-out cases do not name a registration route.
- **`erp-backend/scripts/qa-boutiques.ts`:** the registration calls are unchanged.
- **Backend `.env.example`:** line 2, a comment only.
- **The docs:** every addition is an appended section. The D168 amendment sits under its own heading, not at the end
  of `docs/21`, and `SESSION_LOG.md` was appended to.

### Blockers (the owner's)

- link an EAS project `dukan-erp`;
- the Apple Developer membership and the App Store Connect record `mr.tsxmr.dukanerp`;
- the Google Play app `mr.tsxmr.dukanerp`;
- the logo;
- WhatsApp templates at Meta under Dukan ERP;
- `RECORD_AUDIO` on Android;
- the email provider;
- `PLATFORM_MFA_KEY` per environment;
- the backup retention period;
- legal review;
- device verification (`docs/24` §65).

### Next exact actions for the identity

1. The owner links the EAS project (`docs/44`, step 2), then runs the first Android preview build of `mr.tsxmr.dukanerp`
   and `docs/24` §65 on a physical phone.
2. After the PC database receives 0092–0094 with the matching API, apply `docs/patches/boutiques-local-0094.patch` to
   `local-scripts/boutiques-local.ts` (`docs/75` §17). That copy is operator work and was not edited.
