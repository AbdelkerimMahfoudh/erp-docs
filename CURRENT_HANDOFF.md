# CURRENT_HANDOFF

Status: READY_FOR_HANDOFF
Owner: NONE
last_session: CLAUDE-B — 2026-10-05T03:22Z → 2026-10-05 (the seat rule, team accounts, the website from scratch, four app defects)
previous_handoff: complete (this file replaces the IN_PROGRESS snapshot of 2026-10-05T03:22Z)

## HEAD of every repository — all working trees clean

| Repository | Branch | HEAD | Remote |
| --- | --- | --- | --- |
| `erp-backend` | `reports-export` | `d670401` | pushed (`7283844..d670401`) |
| `erp-mobile` | `reports-export` | `81cb599` | pushed (`6f6ef47..81cb599`) |
| `erp-control-web` (new) | `main` | `0417bfe` | **no remote** — see blocker 1 |
| `erp-docs` | `master` | the commit carrying this file | pushed |

The four draft PRs (backend #1/#2, mobile #1/#2) are unchanged by this session.

## What this session delivered (detail in `docs/69`; decisions in `docs/21` D135–D144)

1. **One included seat per store, 100 MRU per further seat per store** (backend `0086`, plan version 2), with the
   transition that carries existing staff as granted seats and deactivates nobody (`prisma/transition-seats.ts`).
2. **Employee accounts that wait to be activated** — created from Team with email, WhatsApp number or both; every
   selected contact verified by the person; a seat held at each store; activated only by the server, under a lock;
   no bypass by older clients, direct sign-in or the Team switch; no code ever returned outside local development.
3. **Seat and store requests paid through the platform** — priced by the server, confirmed by an administrator with a
   reference, version-guarded (one payment, 409 on a stale colleague), audited; the store opens on payment.
4. **The website `erp-control-web`, from scratch** — public site with the server's price list and estimate, business
   application, Owner account with status / quote per store / requests / payments / history, administrator console with
   step-up, queue, every lifecycle decision; EN/FR/AR with RTL; tests and build; 71 screenshots
   (`scratchpad ph2/shots/INDEX.md`).
5. **The four app defects** — Create and link product from the file review (pure test of the screenshot scenario);
   the Arabic direction verdict that never lies (needs a new native build; `supportsRTL` set); Notifications and the
   price history own their scrolling; a toast is never blank; Import stock on the Stock tab.

## Live state

- The live database was **not touched** and is still at `0083`. Owed on live, in order and only with the owner's
  approval and a verified backup: `0084`, `0085` (`docs/67` §7), then `0086` with the transition script (`docs/69` §2).
- Nothing deployed, submitted or published; no message sent; no provider configured; no iOS build.

## Blockers and owed decisions

1. **The website has no remote.** Creating `erp-control-web` on GitHub from this session was refused twice
   (`403 Resource not accessible by integration`; the proxy serves repository-scoped endpoints only). The owner creates
   `AbdelkerimMahfoudh/erp-control-web` (private) and adds it to the session's repositories; then, in the website's
   directory: `git remote add origin <url> && git push -u origin main`. Until then the repository lives only on the
   machine where this session ran — the next session must **not** treat it as published.
2. **D138b** — the date from which granted (transition) seats become paid seats; until then they cost nothing.
3. **No email delivery provider exists in the backend** (`ContactDeliveryProvider` has WhatsApp and the development
   outbox). Applications and invitations by email are refused honestly until one is written and configured.
4. **Device checks** `docs/24` §56, on a NEW native build (Arabic direction, Team, intake, Notifications, website on a
   phone browser). Nothing in this phase was run on an iPhone.
5. The website is **not production-ready** until: an email provider, HTTPS with the cookie `secure`, a domain, the
   support and privacy addresses, and the written and rehearsed payment procedure (`docs/69` §4).

## Next exact action

1. Owner: create the GitHub repository and tell the next session; push `erp-control-web` (blocker 1).
2. Owner: decide D138b; confirm the website copy and the price list wording on the home page.
3. Next session: run `docs/24` §56 on a device with a new native build; record the blank toast's caller from the
   development warning if it reappears; then the live runbooks when approved.

## Verification of this session (summary; `docs/69` §6)

- Backend: `tsc` clean; 184 suites / 3 309 tests; `0086` applied from empty on MySQL 8.0.46; no drift on the new
  tables; real-HTTP matrix 76/76 (development and production mode).
- Mobile: `tsc` clean; `expo lint` 0 errors / 29 warnings (baseline); 88 node suites; parity 3 301 per catalogue;
  web export; bundle audit 15/15; the new copy carries no price, checkout, purchase or provider wording.
- Website: `tsc` clean; 16 tests; production build; 71 screenshots at 375 px and 1 280 px, EN and AR.
- Disposable data only; secrets generated and shredded; servers stopped; database files removed.
