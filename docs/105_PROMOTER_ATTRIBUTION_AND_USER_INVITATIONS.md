# 105 — Promoter codes, QR cards and user invitations: where a self-registered business came from (D221)

**Status: implemented and verified on feature branches only.** Nothing is merged, deployed or migrated in production.
No association file is published, public registration stays closed, and email and WhatsApp stay disabled.

| Repository | Branch | Commits (oldest first) |
| --- | --- | --- |
| `erp-backend` | `promoter-attribution` (from `superadmin-provisioning` `f5da650`) | `5c2cd88` (0103, services, APIs, deploy wiring) · `44bf0c4` (console change by POST) |
| `erp-control-web` | `promoter-attribution` (from `browser-input-setup-code` `2ebe9c5`) | `012abcd` (console, card, `/join`, promo code) · `b35c6e8` (320 px, dark card, browser checks) |
| `erp-mobile` | `promoter-attribution` (from `browser-input-setup-code` `9e0b38b`) | `a6c2921` (promo code, invitation screen) · `02a30ad` (address cleared on a first load) |
| `erp-control-web` | `ops/verify-promoter-attribution` (orphan, tooling only, never merged) | `3d1f103` |

The decision is D221 (`docs/21`). This record holds the detail.

## 1. What it is, and what it is not

Two ways a self-registered business can say where it came from. Both are **attribution and factual counts only.**

- **A promoter**, managed by the platform administrator only. Each promoter has a six-digit promo code and a QR card
  whose address is `https://dukan.tsxmr.com/join?r=<opaque token>`.
- **A user invitation.** Any signed-in Owner, Manager or Employee may share "Invite someone to Dukan ERP". The person
  who registers through it is attributed to the **inviting business**. The person who shared it is kept for the audit
  only.

Neither is an employee invitation, an Owner's setup code or "Add team member". Nothing here computes or records
anything for a promoter or an inviter beyond who brought which registration. The inviter is shown none of it.

## 2. Schema — migration `0103_promoter_attribution` (additive)

| Table | Holds | Never holds |
| --- | --- | --- |
| `promoters` | `id`; `public_ref` (random 16 bytes, the QR token's reference, never the id); `display_name` (≤80); `whatsapp_number` (normalised E.164, CHECK `^\+[0-9]{6,20}$`); `note` (≤500, optional); `is_active`; `current_code_id` (UNIQUE FK); `created_by`/`updated_by` (administrator address); timestamps | — |
| `promoter_codes` | `code` CHAR(6), CHECK six digits, **UNIQUE for ever** (a retired code is never issued again); `version` (UNIQUE per promoter, from 1; also the QR's version); `issued_by/at`; `retired_by/at` (both or neither); a virtual `live_promoter_id` that is UNIQUE (**one usable code per promoter**) | — |
| `referral_invitations` | `public_ref` (random, UNIQUE); `company_id`; `created_by_user_id`; `language` (en/fr/ar); `created_at`; `revoked_at` + `revoked_by_user_id` (both or neither); a virtual `live_user_id`, UNIQUE with `language` (one live link per person and language) | any recipient: no name, number or contact |
| `business_acquisitions` | `company_id` UNIQUE; `registration_attempt_id` UNIQUE (FK to the idempotency record); `source` promoter/user_invite; `mechanism` promo_code/promoter_qr/user_invite; promoter, code, `code_version`, `promoter_name` snapshot — **or** invitation, inviter business, inviter person; `attributed_at`. A CHECK enforces exactly one source shape; another refuses a business inviting itself | a phone number or note snapshot |

- **Triggers (application account only; the migrator is exempt):**
  - a code keeps its promoter, digits, version and issue, and is never un-retired or deleted;
  - a promoter keeps its reference and creation, and is never deleted;
  - an invitation keeps its business, person, language and reference, and is never changed after revocation or deleted;
  - an attribution is never updated or deleted.
- **Existing businesses get no row:** no source is invented for them.
- **Prisma models:**
  - `Promoter` and `PromoterCode` are platform-realm models (no company).
  - `ReferralInvitation` and `BusinessAcquisition` carry `companyId`.
  - `prisma migrate diff` against the migrated schema shows only the FK-default and generated-column noise every
    earlier migration shows.
- **Reverse:** the exact statements are in the migration's header. They are rehearsed in §9.

## 3. Lifecycle

- **Create:** a display name (required) and a WhatsApp number (required, normalised) are required, and a private note
  is optional. **No code exists yet.**
- **Generate code and QR:** an explicit console action.
  - The server draws the code with `crypto.randomInt`, padded to six digits, never chosen and never derived.
  - It is inserted under the UNIQUE key. A collision is retried with a fresh draw inside the same transaction, up to
    8 times, then refused with `promoter_code_unavailable`.
  - The transaction is serialised on the promoter row.
  - The server refuses to generate without `REFERRAL_KEY`, because a code without its QR would be half a card.
- **Regenerate:** the console confirms first, then asks for the step-up.
  - The current code is retired and the next version is issued.
  - The old code and every QR signed with the old version stop at once. History is kept, and nothing is deleted.
- **Deactivate / activate:** the code and QR stop opening and start again. Nothing is retired.
- **Every change is audited** (`promoter.create|update|code_issued|code_regenerated|activate|deactivate`).
  - Audit rows record that the number or note changed, never what they are.
  - They record the code's version, never its digits (`code` is also on the audit's `NEVER_LOG` list).

## 4. The registration link token

`base64url(kind ‖ public_ref ‖ version ‖ mac)` is 37 bytes, written as 50 characters.

- **kind:** 1 is a promoter's QR; 2 is a user invitation.
- **mac:** HMAC-SHA256 under `REFERRAL_KEY`, in a purpose domain per kind (`dukan-erp/promoter-qr/v1`,
  `dukan-erp/user-invite/v1`), truncated to 128 bits.
- **Properties:**
  - Deterministic: the console signs it again on every read, so nothing replayable is stored.
  - Tamper-evident: every single-character change is refused (unit test).
  - It carries no row id, name, number or code.
  - A version mismatch, a revoked invitation, an inactive promoter or a closed inviting business is unusable.
  - An invitation whose maker was deactivated or deleted is also unusable.
- **The address** is `PORTAL_ORIGIN + /join?r=<token>`.

## 5. Field boundaries (privacy)

| Datum | Who sees it | Where it never appears |
| --- | --- | --- |
| Promoter's display name | the administrator; a registrant who enters the code or opens the QR; the printed card | — |
| Promoter's WhatsApp number | the administrator, on the promoter's own page; **masked** (`+222***22`) in the list | public answers, QR, card, registration payloads, attribution rows, audit rows, logs, analytics, errors, screenshots of the card |
| Private note | the administrator, on the promoter's page | everywhere else |
| Code digits | the administrator; the card; the registrant who types them | audit rows (version only), logs |
| Token | the address itself | logs (lookups are POST bodies; the API logs no bodies), audit, the browser's address after landing (removed at once), referrers (`Referrer-Policy: no-referrer` on `/join`) |
| Inviter | the platform's report (business, and the person in the attribution row) | the invited registrant (told only "You were invited"); the inviter (shown no counts) |

- Telemetry is `acquisition.lookup` with `via`, `outcome` and `source`, and `acquisition.attributed` with `source` and
  `mechanism`. It carries no code, token, name, number or address.
- Nothing sends a WhatsApp message or records a consent for a promoter.
- The invitation is shared with the phone's own share sheet, the browser's Web Share or Copy. Dukan ERP sends
  nothing.

## 6. Public lookups, rate limits and enumeration

- **Routes:**
  - `POST platform/acquisition/code` and `POST auth/acquisition/code` take `{ code }`.
  - `POST platform/acquisition/link` and `POST auth/acquisition/link` take `{ token }`.
  - There is no list or search route.
- **Answers:**
  - `{ usable: false }` — one identical answer for unknown, malformed, retired, deactivated, replaced, revoked or
    tampered;
  - `{ usable: true, source: 'promoter', promoterName, code }`;
  - `{ usable: true, source: 'user_invite' }`.
- **Input:** six digits in ASCII, Arabic-Indic (U+0660–0669) or Eastern Arabic-Indic (U+06F0–06F9). Spaces, hyphens
  and direction marks between the digits are allowed. Anything else is refused before any lookup.
- **Request budget:** `PUBLIC_THROTTLE`, 10 per minute per address, shared by both doors and both routes
  (`acquisition-lookup` key; tested through the real `ThrottlerGuard`).
- **Wrong-guess limit (`LookupLimiter`, in memory like the throttle):**
  - 5 unusable answers per address in 15 minutes. After that, **every** lookup from that address is refused with
    `429 acquisition_lookup_limited`, real codes included, so a hit cannot be told from a miss.
  - 200 unusable answers in 15 minutes across all addresses stop lookups for everybody until the window clears.
  - A registration carrying a source spends the same budget, and a source refused at registration counts as a wrong
    guess.
  - Registration without a source never depends on it.
- **Bound:**
  - One address gets at most 480 wrong guesses a day. At 100 live codes in 10⁶, that is a probability below 5% a day
    of finding any one, and what it finds is a display name.
  - Everybody together gets at most 19,200 a day, which is below 2 expected hits a day at 100 live codes (unit test
    `bounds what an enumerator can learn`).

## 7. Registration

- **`RegisterDto` gains `promoCode?` and `referralToken?`.** At most one is accepted:
  - both are refused with `400 acquisition_conflict` and nothing is saved;
  - neither means the registration it always was.
- **Inside the registration's own transaction**, after the company and its registration attempt:
  - the source is resolved again, under `FOR SHARE` on its rows;
  - one `business_acquisitions` row is written.
- **A source that stopped being usable** refuses the whole registration with `409 acquisition_unavailable`
  (`source` promoter/user_invite, "Nothing was saved"). It is never silently dropped or attributed elsewhere.
- **A replay** returns the first business; the source is never attributed twice (real-MySQL: replay, race, refusal,
  QR, code, invitation).
- **Unchanged:** activation, the free trial, the subscription, the setup code, the WhatsApp consent and payment.
- **Both doors** (`platform/register`, `auth/register`) go through the one `RegistrationFlowService`. A flow without the
  acquisition service refuses a claimed source rather than dropping it.
- **The console's own `createBusiness`** never carries a source.

## 8. Surfaces

**Console (`erp-control-web`, `/admin/promoters`, `/admin/promoters/:id`, `/admin/sources`)**
- An MFA session is required, and every change asks for the password and step-up.
- The list shows name, masked number, code, state, creation date and finished registrations (the Owner proved the
  contact). It searches by name or by six-digit code.
- A promoter's page has:
  - copy code and copy registration address;
  - the card in EN/FR/AR, independent of the console's language, in RTL for Arabic;
  - download as a 1200×1700 PNG, print (only the card prints) and share the PNG where the browser can share files;
  - activate/deactivate, and regenerate (confirm, then step-up);
  - code history and attributed businesses.
- **The card** shows the brand, the display name, the QR (medium error correction, four-module quiet zone, black on
  white in both themes), the code and one instruction. It never shows a number, note, id or customer.
- **The QR** is encoded in the browser by `qrcode-generator` 2.0.4 (MIT, no dependencies). It is absent from the
  public build's bundle (see the alias fix below).
- **Registration sources** shows counts for the period (self-registered, promoter, invitation, none) and rows with the
  business, date, source, mechanism, the promoter's name snapshot and code version or the inviting business, the
  subscription's status and whether registration finished. It excludes businesses created in the console.

**`/join` (portal and full builds)**
- It is served by the app shell like the protected areas: never prerendered, `noindex`, `no-store`, and
  `Referrer-Policy: no-referrer`.
- It reads only `r`, removes it from the address at once and asks about it by POST.
- It says whose code it is, that it is an invitation, or that it is no longer valid. Opening it creates nothing.
- **Full build:** "Create my business" opens the application form with the source in router memory.
- **Portal build:** it continues to `VITE_APP_WEB_ORIGIN/register?r=…` (a new optional input; blank, it asks for the
  phone app).

**Registration form (app — native and web export — and the website's application form)**
- "Promo code — optional": six boxes, left to right in every language.
  - Typing advances; Backspace goes back; a paste fills them.
  - Arabic digits are read as digits.
  - Each box is labelled for a screen reader.
  - Six digits are checked at once, giving "Code from: {name}" or "This promo code is unavailable".
  - "Remove promo code" clears it.
- An invitation shows "You were invited to Dukan ERP" and "Continue without the invitation".
- With an invitation and a usable code at once, the registrant chooses; nothing is sent until they do.
- A refusal at submission returns to the first step: "The promo code or invitation is no longer available. Nothing was
  saved…".
- In the app, the source lives in the registration screen's memory across the three steps, the language and the
  theme. The address arrived with is read once and taken out of the route. The app's `/join?r=` (the path a universal
  link would open) hands it to registration; the team's own `?ref=` is unchanged.

**"Invite someone to Dukan ERP" (app, More → Manage, every member)**
- It says it is not Team, then offers:
  1. a choice of message language (EN/FR/AR);
  2. a preview in that language and direction;
  3. Share (the share sheet, or Web Share), Copy, and "Stop this invitation" after a confirmation.
- The messages:
  - EN: "Try Dukan ERP to manage stock, sales and daily store activity. Create your business here: {address}".
  - FR: "Essayez Dukan ERP pour gérer le stock, les ventes et l’activité quotidienne de votre boutique. Créez votre
    entreprise ici : {address}".
  - AR: "جرّب Dukan ERP لإدارة المخزون والمبيعات ونشاط متجرك اليومي. أنشئ نشاطك من هنا: {address}".
- **Entitlement:** `referral-invitations` writes are **not** in `ALWAYS_ALLOWED`, so a pending, expired or suspended
  business cannot make invitations (the safe default). While customer activation is closed, that means only active and
  test businesses can.

## 9. Migration rehearsal (disposable MySQL 8.0, strict `sql_mode`)

1. Build production's schema from `f5da650` (0001–0102: 101 migrations) and add a business with an Owner.
2. Back up with `mysqldump`.
3. **Forward:** `migrate deploy` applies 0103, status is up to date, and it creates 4 tables and 8 triggers. Existing
   rows are unchanged and no attribution row exists.
4. **Reverse:** the header's statements, plus removing the `_prisma_migrations` row, give a schema identical to before
   (schema dump diff). Forward again is identical.
5. **Restore** the backup into a new schema: identical to before. 101 migrations, data intact.
6. The 0103 real-MySQL spec passes on the rehearsed schema: 22/22.

The script is kept with the session's evidence; the backup was disposable and has been deleted.

## 10. Deployment inputs and runbook (not executed)

1. **A new secret, `REFERRAL_KEY`**, at least 32 characters and different from every other key:
   - `setup-secrets.sh` writes `api/referral_key`;
   - compose passes `REFERRAL_KEY_FILE`;
   - the production guard, both preflights and `check-stack` require it.
   **Production refuses to start without it.** Rotating it voids every printed card and every shared invitation.
2. `PORTAL_ORIGIN` (already required: `https://dukan.tsxmr.com`) builds the address.
3. Before 0103: take a fresh verified backup (`docs/22`), then `migrate deploy`, readiness, and the trigger probes
   (`verify-mysql-identities.sh` now probes `business_acquisitions`).
4. **Code rollback:** older code never reads the new tables. A schema rollback is the header's reverse, only after a
   restore point.
5. **The portal build:** `/join` is a new shell rewrite in `_redirects` and `_headers`. `VITE_APP_WEB_ORIGIN` is
   optional.
6. **Association files are prepared, not published, and no device verification is claimed.** They need:
   - `https://dukan.tsxmr.com/.well-known/apple-app-site-association`:
     `{"applinks":{"details":[{"appIDs":["<TEAM_ID>.mr.tsxmr.dukanerp"],"components":[{"/":"/join","?":{"r":"?*"}}]}]}}`
   - `https://dukan.tsxmr.com/.well-known/assetlinks.json`:
     `[{"relation":["delegate_permission/common.handle_all_urls"],"target":{"namespace":"android_app","package_name":"mr.tsxmr.dukanerp","sha256_cert_fingerprints":["<RELEASE_SHA256>"]}}]`
   - In `app.json`:
     - `ios.associatedDomains: ["applinks:dukan.tsxmr.com"]`;
     - `android.intentFilters` with `autoVerify: true` for `https://dukan.tsxmr.com/join`.
     They are deliberately **not** added yet: the next EAS build would sync the Apple capability, which is an
     outward-facing change.
   - **Missing identifiers:** the Apple Team ID and the Android release signing certificate's SHA-256.

## 11. Verification

| Gate | Result |
| --- | --- |
| Backend unit suite (Jest) | all green (CI `type-check, schema, tests`); the acquisition unit spec 34/34 |
| Backend real-MySQL 0103 spec | 22/22 locally (dev schema and the production-shaped rehearsal) and in CI's database gates, which also probe the attribution triggers |
| Backend CI | 5/6 jobs green; **dependency audit red on advisories (`body-parser`, `multer` high) against the unchanged lockfile** — see §12 |
| Web: typecheck, Vitest | clean; 39 files, 631 tests |
| Web: Chromium e2e, full build | 169/169 locally, including the promoter pages in EN/FR/AR × light/dark at 375, 320 px and desktop (axe, no sideways scroll, noindex, the token out of the address, no number or note on card or list) and the promo code typed in Arabic digits at 320 px |
| Web: public and portal e2e | 172/172 and 34/34 in CI on `012abcd` |
| Web: bundle and link audits | PASS for full, portal and public; the public bundle holds no QR encoder |
| Mobile | `tsc` clean; every pure test file passes (the acquisition rules included); Jest 40 suites, 379 tests (promo code 10, invitation 5); lint 0 errors and 28 warnings (the baseline); release configuration sound; web and iOS exports; bundle audit PASS |
| End to end, real API + MySQL, Chromium (local) | **40/40** — see the list below |
| End to end, WebKit (CI, `ops/verify-promoter-attribution`) | see the handoff for the run and result |

The end-to-end run covered:
- the console signing in with MFA and creating a promoter (no code until generated);
- generate, with the card's text checked and its PNG downloaded;
- the page and list in AR (dark, 375), FR (320) and EN (dark, 320), with the number masked;
- regenerate (old code and QR unusable, history kept);
- `/join` in EN and AR (token removed, noindex) and the prefilled application form;
- the app's registration from the QR (`promoter_qr`, v2, name snapshot);
- a code typed in Arabic digits at 320 px in dark Arabic (`promo_code`);
- deactivation between the check and the submission: refused, nothing saved, the person told; activated again;
- an invitation through the app's `/join` (`user_invite`, the inviting business);
- the report's counts, and the wrong-guess limit (identical answers, then 429 for a real code on both doors).

**Defects the checks found and fixed:**
- the six boxes overflowed `/apply` by 21 px at 320 px (the fieldset grid's auto track);
- the card's text took the dark theme's paragraph colour on white (contrast 1.88);
- the app's lookup cancelled itself (its "checking" mark changed its own effect's dependency);
- on a first browser load the app's `setParams` ran before the navigator held the screen, leaving the token in the
  address;
- a pre-existing one: the public build's stub alias matched only `./protected-areas`, so `RouteScroll`'s
  `../protected-areas` loaded the console's module graph into the public build, where a side-effectful library
  survived tree-shaking. The alias now matches any depth, and a test pins every import of it.

## 12. Known limits and blockers

- **Backend dependency audit:** `npm audit --omit=dev --audit-level=high` fails on advisories for `body-parser` and
  `multer`. They were published after the base branch's last green run, against a lockfile this branch does not
  change. Any merge needs them resolved or accepted in `docs/48` §7.3; `multer`'s fix is `@nestjs/platform-express`
  12, which is breaking.
- **The website's application form (full build only)** sends no WhatsApp consent version, so the server refuses its
  registrations. This predates this phase; the app and its web export are where a business registers (owner's brief of
  2026-10-18).
- **Physical devices only:**
  - iOS universal links and Android app links (association files unpublished; identifiers missing);
  - the OS camera opening the printed QR;
  - the native share sheet and WhatsApp through it;
  - RTL on real devices;
  - printing the card on a real printer.
  WebKit automation on Linux is not an iPhone.
