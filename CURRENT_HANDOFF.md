# CURRENT_HANDOFF

Status: IN_PROGRESS
Owner: CLAUDE-B
started_at_utc: 2026-10-07T18:55Z
previous_handoff: complete — READY_FOR_HANDOFF / owner NONE (CLAUDE-B local on the owner's PC, 2026-10-07T05:55Z); takeover authorised by the user's brief of 2026-10-07 ("investigate the Money card's configured-account calculations")

## Active phase (2026-10-07, cloud) — the Money card's configured accounts: an unknown balance must show its recorded movement

HEAD at takeover, all trees clean and level: `erp-backend` `be024dd` · `erp-mobile` `0b525b3` · `erp-control-web`
`0417bfe` · `erp-docs` `a0299fa`. Scope: diagnose why Sedad reads *Unknown* after a 20 000 MRU sale paid through it
(read-only; live and the PC database are not reachable from this container — the queries for the PC are recorded),
extend the Money-position response with each method's server-calculated day movement (inflows, confirmed outflows,
net, the business day), keep an unknown opening unknown, show the movement on the phone in EN/FR/AR, give the Owner a
clear path from the card to set a company account, tests (pure, service, real HTTP on disposable data, rendered),
decisions, session log, handoff. No live data touched; no migration expected.

Next intended action: the pure rule and the service query on the backend, then the phone, then the HTTP matrix.

## HEAD of every repository — all working trees clean, level with their remotes

| Repository | Branch | HEAD | This session |
| --- | --- | --- | --- |
| `erp-backend` | `reports-export` | `be024dd` | `df1f2b4` (D151, migration `0087`), `be024dd` (Windows test robustness) — pushed `1bf65b5..be024dd` |
| `erp-mobile` | `reports-export` | `0b525b3` | `728a0d8` (lockfile), `c756030` (D150), `fa5c6a5` (Windows tests), `0b525b3` (D151) — pushed `2347523..0b525b3` |
| `erp-control-web` | `main` | `0417bfe` | unchanged |
| `erp-docs` | `master` | the commit carrying this file | `fcf54ca` (takeover), `f087781` (checkpoint), this commit — pushed |

The four draft PRs (backend #1/#2, mobile #1/#2) are unchanged.

## Repository state versus runtime state

**Runtime, proven on the owner's iPhone (Expo Go):** the earlier fixes had not appeared because the PC checkout was five
commits behind and the only Metro served it (`docs/71` §1). After a fast-forward, a clean install and a Metro on port
8082, Devices showed `728a0d8 · reports-export · Expo Go`; later `0b525b3`. The phone runs **Expo Go**, not a
development build. Any future device claim needs that line again after `git pull --ff-only` + `npx expo start -c`.

## What this session delivered (decisions D150–D151 in `docs/21`; record `docs/71`; device `docs/24` §57 results, §58)

1. **Phase A** — the runtime chain proven and cured; the five reports re-checked on the correct bundle: four
   confirmed fixed; Arabic still wrong in Expo Go → **D150** (Expo Go says at once it cannot switch the layout),
   device-verified. Native RTL still needs a new build.
2. **The lockfile** — `2347523`'s `package-lock.json` lacked nine packages of the D149 tooling, so `npm ci` failed on
   npm 10 and 11; regenerated with npm 11, nothing else changed (`728a0d8`).
3. **D151 — the payer number** — optional, non-cash only, one per payment part; `payments.payer_number` +
   `ck_payments_cash_no_payer` (`0087`); sale, split, review, Record payment, sale detail, *Correct payer number*;
   replay and fingerprint binding; audited; never on receipts, reports, exports, notifications or logs; business
   rule `docs/04` 19f.

## Live state

- The live database was **not touched** and is still at `0083`. Owed on live, in order, each only with the owner's
  approval and a verified backup: `0084`, `0085` (`docs/67` §7), `0086` + transition (`docs/69` §2), then **`0087`**
  (`docs/71` §6 — migration first, then the API at `be024dd`+, then the app at `0b525b3`+; the old API refuses an
  unknown `payerNumber`).
- Nothing deployed or submitted; no message sent; no provider configured; no iOS build.

## The owner's PC (local development, not live, not shared)

- Repositories side by side in `C:\wamp64\www\ERP\` (`erp-backend`, `erp-mobile`, `erp-docs`) — not nested as in the
  documentation repository's layout. Git for Windows checks out CRLF; the repositories store LF.
- Database: WAMP's MySQL 8.4 served by a hand-started `mysqld` on `127.0.0.1:3308`, `phonestore` at **`0087`** (applied
  with the owner's approval); backups `~/erp-backups/phonestore-local-20261007-015025.sql` (before `0086`) and
  `…-20261007-054448.sql` (before `0087`). It holds the demo company and ten local test boutiques. WAMP's own MySQL
  service stays stopped; port 3306 is a separate MySQL 8.0 service, not used.
- Node 22 portable; installs need `npm ci --prefer-offline --maxsockets=4` on this connection. Windows Smart App Control
  blocks `lightningcss` 1.33.0 (`@expo/metro-config`), so the **web export cannot run on this PC**.
- The API (port 3010) and Metro (port 8082, signed for the owner's Expo account) were started from this session and
  stop when it ends.

## Blockers and owed decisions

1. **Live:** `0084` → `0087` with backups and approval (above). Nothing in the code blocks it.
2. **Arabic on a native build** — `docs/24` §57 C: `npx expo run:ios` on a Mac or an EAS build, installed; no Mac or
   Apple developer account is available here.
3. **The web export and route audit** — run them where `lightningcss` 1.33 may load (the cloud container, or after the
   owner decides about Smart App Control on the PC; not changed by us).
4. **Eight Expo patch updates** (Doctor 20/21) — a separate change; `expo-camera` needs its native patch re-cut first.
5. Unchanged: D138b (when transition seats become paid); no email delivery provider; the website is not
   production-ready (`docs/69` §4).

## Next exact action

1. Owner: decide on the live runbook for `0084`–`0087` (`docs/67` §7, `docs/69` §2, `docs/71` §6).
2. Owner: the open device lines — `docs/24` §57 (B–F remainder, C on a native build) and §58 (malformed number, Record
   payment, FR/AR wording, largest text).
3. Next session: if the web gate is needed, run `npx expo export --platform web` and the route audit where
   `lightningcss` 1.33 loads; then the Expo patch updates with the camera patch re-cut — or whatever the owner asks next.

## Verification of this session (summary; `docs/71`)

- Backend: `tsc`; Prisma valid; 185 suites / 3 351 tests (3 skipped) on Windows; `payer-number.spec.ts` 32.
- Mobile: `tsc`; `expo lint` 0 errors / 29 warnings (baseline); 92 pure files / 247 tests; 5 rendered suites / 28
  tests; EN/FR/AR parity 3 321 × 3; Expo Doctor 20/21; the web export not run (above).
- Real HTTP on the disposable `prisma_qa_payer` (`0001`–`0087`): 17/17; audit chain intact (11 companies); dropped.
- Device (owner's iPhone, Expo Go): the build line; §57 A–F as recorded; §58 cash, wallet, two-number split,
  correction, keyboard, Airplane-mode retention, saved detail.
