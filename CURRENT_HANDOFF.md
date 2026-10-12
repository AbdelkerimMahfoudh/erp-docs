# CURRENT_HANDOFF

Status: READY_FOR_HANDOFF
Owner: NONE
last_session: CLAUDE-B (local, the owner's Windows PC), 2026-10-12T06:00Z → 2026-10-12T09:30Z — complete
previous_handoff: this account's own interrupted IN_PROGRESS of 2026-10-10 (device run) — its record completed in docs `7addccd`
scope_done: the owner's brief of 2026-10-12 — TSX-MR's official website with Dukan ERP as its product, deployable but **not deployed** (`docs/74`, D163)

## HEAD of every repository — all four trees clean and level with their remotes

| Repository | Branch | HEAD | This session |
| --- | --- | --- | --- |
| `erp-backend` | `reports-export` | `c7034c8` | none (the 2026-10-10 session's `b75b637`, `c7034c8` already pushed) |
| `erp-mobile` | `reports-export` | `0c814be` | none (`3984bdf`, `10369b6`, `6a4afc8`, `0c814be` from 2026-10-10, pushed) |
| `erp-control-web` | **`tsx-public-site`** (new, from `money-agent-3` `36f04b2`) | `98c9107` | `372acc5` … `98c9107`, pushed. `main` still `0417bfe`, `money-agent-3` still `36f04b2` — untouched |
| `erp-docs` | `master` | the commit carrying this file | `7addccd`, `d39925f`, this commit — pushed |

Also on GitHub: `erp-control-web` branch **`ci-evidence`** (written by CI only: logs, screenshots, contact sheets, the
built preview, per commit). The website repository is **public**.

## What this session delivered (`docs/74`)

- Public routes in EN/FR/AR (`/`, `/fr…`, `/ar…`): home, about, products, Dukan ERP, contact, support, privacy, terms,
  account deletion, apply, application status, sign in, 404 — prerendered with per-page head, hreflang, Open Graph,
  verified-only JSON-LD; robots, sitemap, Cloudflare Pages `_headers` (strict CSP, no `unsafe-inline`) and `_redirects`.
- `/account` and `/admin` unchanged and regression-tested; never indexed; `/admin` no longer linked publicly.
- Production inputs (`VITE_*`, `.env.example`) and a **release guard**: `npm run build` refuses while inputs are blank /
  test / non-HTTPS, while no tested deletion channel is declared, or while any `[[blocker:id]]` remains in a published
  text. `npm run build:preview` = marked test values + banner + noindex.
- Privacy policy, terms and deletion page written from a code audit; one canonical content structure with EN/FR/AR
  parity tests.
- Deployment preparation documented (Cloudflare Pages / DNS / Access, Railway with private networking and spending
  limits, Resend + SPF/DKIM/DMARC, WhatsApp prerequisites, R2 encrypted backups + restore drill, staging, promotion,
  rollback), Apple URL mapping, cost estimate (≈ $10–15/month + domain + $99/year Apple + WhatsApp per message).

## Verification (CI only — the PC cannot run Vite 8)

GitHub Actions run 38216501116 on `98c9107` (evidence `ci-evidence:evidence/98c9107…/`): typecheck; vitest 12 files /
**115** (baseline 8 / 48); production build refused as designed; preview 36 pages; links 1 659 / 0 broken; bundle audit
PASS; npm audit 0; gitleaks full history + dist clean; Playwright **58/58** (all pages × 3 languages at 375 and 320 px,
axe WCAG 2.1 AA, desktop and 200% text, keyboard, no-JS, anchors, headers, protected pages); 68 screenshots, 8 contact
sheets. Visual review on the PC of the CI-built preview. NOT VERIFIED: any real deployment (headers on a host, TLS),
Safari/iOS, Firefox, screen readers, protected flows against the real API in this session.

## Publication blockers (`docs/74` §7)

B-1 legal identity and contact inputs · B-2 legal review · B-3 retention period · B-4 processors named · B-5 where data is
processed · B-6 governing law and liability · B-7 backend de-identification gaps in deletion · B-8 WhatsApp deletion
channel configured and tested · B-9 registration delivery channel (no email provider in the backend) · B-10 admin MFA
(or Cloudflare Access) before `/admin` faces the internet · B-11 the app and templates still named "Retail ERP" · B-12 live
migrations `0084`–`0091` and the API · B-13 review and merge `tsx-public-site` into the production branch.

## Carried state (unchanged)

- Live database untouched at `0083`; PC database at `0091` (backup `~/erp-backups/phonestore-before-0088-20261010-043816.sql`).
- No real provider configured or enabled; enabling one needs the owner's explicit approval.
- Owed on the phone (`docs/24` §63): the two fixed FAILED rows and every NOT VERIFIED row, against mobile `0c814be`+.
- Owed decisions: archive a store in the app; D138b; D110/D116; legal retention; `docs/45` D1–D10.

## Next exact action

1. Owner: review the site — clone/fetch `erp-control-web`, `git checkout tsx-public-site`; look at the evidence
   (`ci-evidence` branch, `evidence/98c9107…/contact-sheet-*.jpg`, `SCREENSHOT_INDEX.md`) or serve its `dist/` with
   `node scripts/serve-dist.mjs 4180 <path-to-evidence>/dist` and open `http://127.0.0.1:4180/`.
2. Owner: supply the §3 inputs and decide B-2…B-6 (with a legal adviser) and B-10/B-11; then a session resolves the
   blocker tokens in all three languages and fixes B-7 in the backend.
3. Only with explicit approval: domain, Cloudflare/Railway accounts, deployment per `docs/74` §8.
