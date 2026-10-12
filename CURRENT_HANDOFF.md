# CURRENT_HANDOFF

Status: READY_FOR_HANDOFF
Owner: NONE
last_session: CLAUDE-B (local, the owner's Windows PC), 2026-10-12T10:00Z → 2026-10-12T15:30Z — complete
previous_handoff: READY_FOR_HANDOFF / NONE (the TSX-MR website phase), complete
scope_done: the owner's correction brief of 2026-10-12 — typed commission, Dukan ERP naming, deletion privacy, delivery
boundaries, Super Admin MFA, migration rehearsal, real HTTP, docs (`docs/75`, D164–D168)

## HEAD of every repository — all four trees clean and level with their remotes

| Repository | Branch | HEAD | This session |
| --- | --- | --- | --- |
| `erp-backend` | `reports-export` | `aad5862` | `9c9005a` · `2bb5130` · `4cc2533` · `e345680` · `1d8321b` · `aad5862` |
| `erp-mobile` | `reports-export` | `02f2e4e` | `db67298` · `8bb9201` · `02f2e4e` |
| `erp-control-web` | `tsx-public-site` (**not merged**; `main` still `0417bfe`) | `e892a27` | `83d2e1a` · `fa3c3fe` · `9b079c2` · `e2384c0` · `e892a27` |
| `erp-docs` | `master` | the commit carrying this file | `6502a65` · `f614926` · this commit |

## Databases

- `phonestore` (the PC's development database, 3308): **still at `0091_stabilization`** — nothing applied this session.
- No live/production database exists or was touched.
- Migrations **0092, 0093, 0094** exist in `reports-export`, rehearsed on disposable copies only (`docs/75` §3.1). All
  `erp_rh_*` databases were dropped; `phonestore_app` grants are back to `phonestore.*` only.
- **Deploy the API and 0092–0094 together**: the previous API's exchange insert is refused by the 0092 CHECK.

## What changed (detail in `docs/75`)

- D164 — commission typed per exchange, paid by the customer, employee from the session, immutable, credit moves by the
  principal only; providers without rate; legacy exchanges kept as recorded (`legacy_rate`); reports by stored legs and
  by route; no commission dashboard.
- D165 — deletion removes identity wherever copied; no contacts in new audit events; search terms out of logs; sealed
  history and backups are not edited, and every surface says so.
- D166 — email boundary (no provider connected); WhatsApp closed in production until a signed per-language proof
  (`npm run whatsapp:prove`); keyed contact-verification hashes.
- D167 — mandatory TOTP for platform administrators; enrolment only with a server CLI token
  (`npx ts-node prisma/platform-admin-mfa.ts enrolment-token <email>`); step-up = password + code; production refuses
  to start without `PLATFORM_MFA_KEY`.
- D168 — the product is Dukan ERP, developed and operated by TSX-MR; technical identifiers unchanged.

## Verification

Backend: tsc 0; Jest 212 suites, 3 861 passed, 3 skipped; full-history secret scan clean. Mobile: tsc 0; lint 0 errors
(29 old warnings); pure 268/268; render 156/156 with two workers (with default workers `agent-money` times out under
load and cascades — passes alone). Website: CI run 38249387941 on `e892a27` — Vitest 119/119, Playwright 58/58, gitleaks
clean. Rehearsal 0083→0094 and 0091→0094: clean, restores identical. Real HTTP: 50/51 on the final run, the one failure
cumulative across runs and verified harmless by SQL. NOT VERIFIED: anything on a device (`docs/24` §64), any deployment.

## Blockers (`docs/75` §13)

Credentials (WhatsApp WABA/number/token/app secret/approved EN-FR-AR templates incl. `delivery.check`; email provider and
a sending domain with SPF/DKIM/DMARC; `PLATFORM_MFA_KEY` per environment) · the **backup retention period** · legal:
retention of business records, approval of the sealed-history disclosure, processors and data location, governing law and
liability, review of privacy/terms/deletion, TSX-MR's legal identity and contacts · the owner's decision on the app
identifiers (slug, scheme, bundle id/package, EAS project) · Dukan ERP WhatsApp template texts (Meta re-approval) · logo.

## Known risks

- Phones on the previous build: queued exchanges without a commission are refused `commission_required` and must be
  fixed by *Edit and send* (they stay visible). Existing administrator sessions become pending at 0094.
- `local-scripts/boutiques-local.ts` (outside the repositories) signs in to the console with a password only and will
  fail after 0094; `erp-backend/scripts/qa-boutiques.ts` completes the second factor.
- Not built: QR rendering for enrolment; email flows for recovery and alerts; commission revenue in profit analytics.

## Next exact action

The owner reviews `docs/75` and decides the app identifiers and the legal/retention inputs. Then, on a **staging**
database restored from a fresh backup (`docs/22`): apply 0092–0094 with the API from `reports-export` in one window, enrol
each administrator with a CLI token, run `docs/24` §64 on a device. Do not merge `tsx-public-site`, deploy, or migrate
live before then.
