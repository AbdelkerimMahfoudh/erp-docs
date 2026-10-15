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

**Owner correction (2026-10-15), binding — add-ons during the trial.**

**What the trial covers.** The trial covers the first store and its included free employee allowance. During the
trial, the Owner may request an additional store or a paid employee seat through the website's established flow. The
server may quote it and record payment or approval during the trial. Such a request must **not** be blocked merely
because a trial is running.

**Its timing.** The add-on stays `scheduled` (or equivalent) until the trial ends. Its activation and its first paid
billing period begin exactly at the trial's expiry.

**Money and safety.**

- Exactly one charge: never charged at once and again in the first paid period, never two payment obligations.
- The trial is never shortened, replaced or extended.
- A scheduled add-on consumes no paid entitlement before its effective date.
- At expiry, activation and the first period happen atomically, or fail safely.
- If the add-on is unpaid at expiry, it stays pending and is not activated.
- Repeated approval, payment confirmation or expiry processing never activates or bills twice.

**Display.** The website shows the scheduled activation date clearly. The app shows no pricing, payment, purchase or
activation control.

**Tests required:**

- a store, and a paid seat, requested during the trial;
- payment confirmed during the trial;
- no immediate billing period, and no immediate activation;
- exact activation at expiry;
- one charge only;
- duplicate payment confirmation;
- concurrent expiry and payment confirmation;
- an unpaid request at expiry;
- a cancelled or refused request;
- a suspended business at the activation time;
- a claim racing an add-on request;
- company and store isolation.

**Fallback.** If the data model cannot schedule this safely without a substantial redesign: leave the add-on pending
until expiry and document the limitation. Never double-charge.

**Decisions.** Of the four review findings reported as needing confirmation:

- **R1-F1** is replaced by the add-on rule above.
- **R2-3** proceeds under the confirmed rule that every contact given at registration must be verified.
- **R4-04** (the terms sentence) and **R5-4** (the both-contacts Owner's path to the WhatsApp verification) are
  **awaiting the owner**. Current behaviour is preserved and the alternatives are presented.

No other unresolved product question may be turned into code.

**Final verification required:**

- the error-path token logging leak is fixed;
- setup tokens, portal tickets and other secrets are proved absent from successful and failing request logs;
- the whole real-HTTP journey is rerun from a fresh disposable database;
- only genuinely completed passes are reported, and harness failures are never counted as product passes;
- the complete combined gates are rerun;
- anything not verified on a physical phone is reported separately.

## Databases

- `phonestore` (the PC's development database, 3308): still at `0091_stabilization` — not touched by this session.
- No live/production database exists or will be touched.
- Migrations `0095_free_trial` and `0096_trial_link_claimed` are pushed. `0097_scheduled_addons` is in progress, not
  pushed. Each is rehearsed only on a disposable MySQL inside this cloud container, with a backup and a restore check
  first (`docs/22`).
- Migrations 0092–0096 exist in `reports-export` and are not applied to the PC database. Deploy the API and
  0092–0096 (0097 once approved) together.

## Checkpoint — 2026-10-13T07:55Z: the trial's first implementation, merged with the identity phase and pushed

This checkpoint is green, but it is **not finished**. An adversarial review found 35 issues, and their fixes are in
progress. The pushed commits hold the trial as first implemented.

| Repository | Branch | HEAD (pushed) | Combined ancestry |
| --- | --- | --- | --- |
| `erp-backend` | `reports-export` | `c3aa803` | merge of `2c9ffbb` (the trial, `aad5862..2c9ffbb`, migrations `0095_free_trial` and `0096_trial_link_claimed`) and `5bdba80` (identity) |
| `erp-mobile` | `reports-export` | `7b64918` | merge of `4620312` (the trial, `02f2e4e..4620312`) and `9af0401` (identity) |
| `erp-control-web` | `tsx-public-site` (**not merged**; `main` `0417bfe`) | `4b61f79` | merge of `a355ea2` (the trial, `e892a27..a355ea2`) and `72b1be8` (identity) |

### Integration with the identity phase (the owner's clarification)

- **No blind merge.** The two sides were compared file by file. The merges are `--no-ff` merge commits, with no rebase
  and no force-push.
- **Only two files are touched by both sides,** each in disjoint hunks, and both sides are kept:
  - backend `.env.example`: the product name on line 2, plus the trial's two new variables;
  - website `README.md`.
- **One behavioural point of contact, in mobile:** `__tests__/deep-links.test.tsx` now also covers the restored sign-up
  routes, and it passes.

Combined gates on the merged trees:

- **Backend:** `tsc` 0; Jest 224 suites, 4 156 passed, 3 skipped.
- **Mobile:**
  - `tsc` 0; lint 0 errors (29 warnings);
  - Jest 17 suites, 206 passed;
  - pure tests, 109 files passed;
  - release configuration sound.
- **Website:** typecheck 0; Vitest 15 files, 169 passed.

### Verification so far

**Migrations.** `0095` and `0096` were rehearsed on disposable MySQL only: a backup, a restore check and the reverse
SQL. Existing businesses got no trial (20 / 20). **No shared database was touched.** The PC's `phonestore` is still at
`0091_stabilization`, and `0092`–`0096` must arrive together with the matching API.

**Real HTTP, run r4, on a disposable copy:**

- 107 checks passed, through the 168-hour boundary and the expiry (sections A–O).
- **M3 failed on an existing leak, not a trial defect:** the global exception filter logs the raw request URL, so a
  `?t=` token reaches the API log. Fix in progress.
- The run then stalled on a harness defect: the administrator's TOTP waited after the clock moved back. The harness is
  fixed.

### Open: the review's findings, being fixed now (cloud session)

| Severity | Count | Findings |
| --- | --- | --- |
| Blocker | 3 | the mobile bundle audit and boundary test can be bypassed by other spellings and by letter case; the website timelines print raw UTC instants |
| Major | 12 | the automatic send can hold verification past the app's 20 s timeout; a store or seat bought during a trial is charged twice; the trial card says read-only although paid access is approved; the terms say paid access is "arranged on this website"; a both-contacts Owner has no app path to verify the WhatsApp number; the zone name is cut on iPhone; plus others |
| Minor | 19 | — |
| Nit | 1 | — |

## Checkpoint — 2026-10-15T13:55Z: review fixes round 2 in progress; backend pushed; add-on round started

**The work is not finished. Do not take over.** Agents of this cloud session are committing in the backend, mobile and
website trees right now.

| Repository | Branch | Pushed | Local | State |
| --- | --- | --- | --- | --- |
| `erp-backend` | `reports-export` | `7274fca` | `7274fca` + the add-on round's commits as they land | the review fixes (17 commits `c3aa803..7274fca`) are pushed; the add-on round (migration `0097_scheduled_addons`, the scheduled store/seat, the contract parts C6, C7, C8, R4-05, R1-F4) is being built on top, not pushed |
| `erp-mobile` | `reports-export` | `7b64918` | `d51b3ee` (11 commits) + a fix-up in progress (2 dirty files) | not pushed |
| `erp-control-web` | `tsx-public-site` (**not merged**; `main` `0417bfe`, untouched) | `4b61f79` | `10f9401` (18 commits) + a fix-up in progress | not pushed |
| `erp-docs` | `master` | the commit carrying this checkpoint | — | — |

**Backend gates at `7274fca`:**

- `tsc` 0;
- Jest 228 suites, 4 234 passed, 3 skipped;
- `prisma validate` passes;
- secret scan clean (1 903 blobs, 250 commits).

**Commit identity.** The backend's 17 commits carry author `CLAUDE-B`, committer `Claude <noreply@anthropic.com>`.
That identity was rewritten on the unpushed commits only, with an identical tree, before the first push.

**Migration `0097_scheduled_addons`** (the owner's correction of 2026-10-15) is additive:

- an ENUM value `scheduled`;
- `effective_at DATETIME(6) NULL`;
- a CHECK.

It is applied **only to disposable databases**, with a `docs/22` rehearsal. **It needs the owner's approval before any
shared database sees it.** `phonestore` (the PC's database) is still at `0091_stabilization`.

**The real-HTTP preview, run r6, on the fixed backend: 154 / 158.** The four failures are the contract parts the add-on
round now delivers:

- G4b and G4c: C6;
- M2b: C7;
- M2d: C8.

The final run from a fresh database comes after the add-on round.

## Next intended action

1. Finish fix round 2's mobile and website fix-ups. Then, in each repository: run the gates, rewrite the committer of
   its unpushed commits only, and push as a fast-forward.
2. The add-on round on the backend: build, three adversarial verifiers (money, concurrency, scope), fix-up. Then the
   website's display of scheduled add-ons.
3. The full combined gates.
4. The final real-HTTP journey from a fresh disposable database, reporting only genuine passes.
5. Website screenshots in EN, FR and AR at 375 and 1280 px.
6. Drop the disposable databases and stop every process.
7. `docs/76` as built, `docs/21`, `docs/68`, `docs/22`, `docs/24`, `SESSION_LOG.md`. Then `READY_FOR_HANDOFF`, once
   all four trees are clean and pushed.

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
