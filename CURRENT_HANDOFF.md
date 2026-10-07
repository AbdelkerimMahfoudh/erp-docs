# CURRENT_HANDOFF

Status: IN_PROGRESS
Owner: CLAUDE-B
started_at_utc: 2026-10-07T01:45Z
session: CLAUDE-B on the owner's Windows PC (Claude Code, local) — user-authorised takeover from `READY_FOR_HANDOFF` / `NONE`
previous_handoff: complete — CLAUDE-B (cloud), 2026-10-06T01:16Z → 02:01Z (`docs/70`)

## HEAD of every repository at takeover (fetched 2026-10-07T01:45Z)

| Repository | Branch | Remote HEAD | PC checkout before this session | PC tree |
| --- | --- | --- | --- | --- |
| `erp-backend` | `reports-export` | `1bf65b5` | `1434aa7` — 0 ahead / **3 behind** | clean |
| `erp-mobile` | `reports-export` | `2347523` → now `fa5c6a5` (this session) | `3023bd3` — 0 ahead / **5 behind** (older than `81cb599`) | clean |
| `erp-control-web` | `main` | `0417bfe` | not checked out on this PC | — |
| `erp-docs` | `master` | `8e9dffb` | `d3694ad` — fast-forwarded to `8e9dffb` to read this file | clean |

No local commits, stashes or extra worktrees in any repository.

## Active phase and scope (the owner's brief of 2026-10-07)

1. **Phase A — prove what the iPhone runs.** The PC checkout, every running ERP server, a fresh runtime from the
   verified checkout, the Devices build line (D145) as the proof; then `docs/24` §57 B/D/E/F on the correct bundle;
   Arabic classified honestly (§57 C needs a new native build — `docs/70` §3).
2. **Phase B — an optional payer number on non-cash sale payments**: single and split (≤ 4) payments, the correction
   flow, review and sale detail; an additive nullable backend field, migration verified on a disposable database only;
   focused tests and a real-HTTP lifecycle.

## Discrepancy found at takeover

- The PC checkouts had not been pulled since 2026-10-04: the Metro on this PC (port 8081, started 2026-10-07 00:40Z
  with `--clear`) served `erp-mobile` at `3023bd3`, and the API (port 3010) ran `erp-backend` `1434aa7`. To be proven
  in Phase A, not assumed.
- **The PC's local development database** (not live, not shared): WAMP's MySQL 8.4 data directory served by a
  hand-started `mysqld` on `127.0.0.1:3308`, database `phonestore`, migrated through `0085`; it holds the demo company
  and ten local test boutiques (`boutiques1..10@test.com`, created 2026-10-05 through the API). WAMP's own MySQL 8.4
  service stays stopped (port 3306 belongs to a separate MySQL 8.0 service).

## Checkpoint — Phase A complete (2026-10-07T02:40Z)

- **Why the phone ran old code:** the only Metro on the PC served the checkout at `3023bd3` (5 behind); its manifest had
  no `extra.build`, its bundle no build line; the phone (Expo Go, UA `Expo/1017880`, debugger target
  `host.exp.Exponent`) loaded it and logged the nested-VirtualizedList error itself. Clearing the cache could not help.
- **Brought level:** both checkouts `pull --ff-only`; mobile `npm ci` was refused by npm 10.9.9 and 11.21.0 (lockfile
  missing nine packages of the D149 tooling) → lockfile repaired with npm 11 `--package-lock-only` (`728a0d8`, pushed);
  backend deps unchanged. Local DB backup `~/erp-backups/phonestore-local-20261007-015025.sql` (verified: trailer, 96
  tables, 31 triggers) → `0086` applied → seat transition dry-run/apply: 0 granted / 0 converted. API rebuilt from
  `1bf65b5` (port 3010); Metro on **port 8082** from the verified checkout, cache cleared.
- **Device proof:** Devices → *This device* showed `728a0d8 · reports-export · Expo Go`, later `fa5c6a5`. §57 B, D, E, F
  confirmed by the owner on that bundle (no Import stock in More, the Stock action, Notifications without LogBox, no
  blank toast, equal header margins, the opening-cash flow without Keep → set 1 000).
- **Arabic (still broken on the correct bundle, fixed):** measured on the phone — Expo Go relaunched (new
  `Constants.sessionId`) and `isRTL` stayed false; re-selecting the language re-armed "Restart needed". `c756030`:
  Expo Go says at once that it cannot switch (D150); device-verified on `fa5c6a5`. Native RTL needs a new build — owed.
- **Tests on Windows:** `fa5c6a5` makes three source-reading suites independent of folder layout and CRLF.

## Next intended action

Phase B — the payer number: audit the payment schema/API/correction/idempotency, propose the plan for approval,
then implement backend → mobile → disposable-DB lifecycle → device checks.

## Live state (unchanged)

- The live database was not touched and is still at `0083`. Owed on live, in order and only with the owner's approval
  and a verified backup: `0084`, `0085` (`docs/67` §7), then `0086` with the transition script (`docs/69` §2).
- Nothing deployed or submitted; no message sent; no provider configured; no iOS build.

## Owed from earlier phases (unchanged)

D138b (when transition seats become paid); no email delivery provider in the backend; the website is not
production-ready (`docs/69` §4); `docs/24` §57 on a device.
