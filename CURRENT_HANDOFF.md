# CURRENT_HANDOFF

Status: IN_PROGRESS
Owner: CLAUDE-B
started_at_utc: 2026-10-12T08:00Z
session: CLAUDE-B (local, the owner's Windows PC) — continues its own session of 2026-10-10 (handoff then `IN_PROGRESS`, interrupted before its docs; those docs are now committed in `7addccd`), on the owner's new brief
scope: the owner's brief of 2026-10-12 — prepare `erp-control-web` for public production use as the official website of **TSX-MR**, with **Dukan ERP** presented as a product developed and operated by TSX-MR: a public corporate site (home, about, products, Dukan ERP, contact, support, privacy, terms, account deletion) beside the preserved application / Owner / Super Admin portal; configurable production inputs with a release check that refuses publication while legal values are blank; EN/FR/AR with RTL; SEO, security headers, accessibility; deployment preparation (Cloudflare Pages, Railway, Cloudflare DNS, Resend later, WhatsApp later, R2 backups) **documented only — nothing deployed, purchased, created or published**.
heads_at_takeover: backend `reports-export` `c7034c8`; mobile `reports-export` `0c814be`; docs `master` `7addccd`; website `money-agent-3` `36f04b2` (cloned to the PC today; `main` still `0417bfe`) — all clean and level with their remotes.
verification_route: the website cannot be built on this PC (Smart App Control blocks Vite 8's Rolldown binary; its WASM fallback fails on Windows paths; WSL absent). The owner chose GitHub Actions (Linux) for every website check; the owner confirmed the repository is connected to no hosting, so a pushed branch publishes nothing.
next: create the website branch `tsx-public-site` from `money-agent-3`; add the CI workflow; then the configuration/release check, the public routes and content, prerendering, metadata, headers, tests, evidence, docs.

## Takeover discrepancies (reported to the owner before editing)

1. The handoff was `IN_PROGRESS` (CLAUDE-B, 2026-10-10) — this account's own interrupted session; its record is now in docs `7addccd` (`docs/24` §63, D162, `docs/73` §11.8, session log).
2. The website was not on this PC; cloned. Its last recorded verification (cloud, 2026-10-10: 8 files / 48 tests, build, 12/12 in Chromium) cannot be re-run here.
3. "Dukan ERP" / "TSX-MR" appear nowhere in code or docs: the app is "Retail ERP" (`app.json`, `mr.retailerp.app`), the API "Phone Store ERP API", the WhatsApp template copy "Retail ERP" (`docs/64`). Recorded as a new decision and a pre-App-Store blocker (the app's display name and the templates must match).
4. No hosting / domain / email decision recorded (`docs/45` D1–D10 open); Cloudflare / Railway / Resend come from this brief.
5. No email provider exists in the backend; WhatsApp is `disabled`. In production registration answers 503 and account deletion cannot complete (`deletion_unavailable`).
6. Privacy: the in-app deletion warning says contact details are removed, but the code keeps names/phones/payer numbers inside append-only audit JSON, agent customer numbers (not cleared on business closure), full destinations in old verification rows, receipt photos on disk and branch addresses — a release blocker for the backend, stated truthfully on the site.
7. No administrator MFA (D8 open): `/admin` must not face the internet yet; the public navigation stops linking it.
8. Prices: public `GET platform/plan` / `POST platform/quote` are approved (D140) and server-derived; kept, off the corporate home page.

## Carried state (unchanged by this phase)

- Live database untouched at `0083` (owed in order, each with approval and a backup: `0084`, `0085`, `0086`, `0087`, `0088`–`0091`). The PC database is at `0091` (backup `~/erp-backups/phonestore-before-0088-20261010-043816.sql`).
- No real provider configured or enabled; enabling one needs the owner's explicit approval.
- Owed on the phone (`docs/24` §63): the fixed FAILED rows (offline counter, closing notice) and every NOT VERIFIED row, against mobile `0c814be` or later.
- Owed decisions: archive a store in the app; D138b; D110/D116 (deletion while WhatsApp is postponed); the legal retention period; `docs/45` D1–D10.
