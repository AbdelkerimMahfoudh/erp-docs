# CURRENT_HANDOFF

Status: READY_FOR_HANDOFF
Owner: NONE
last_session: CLAUDE-B (cloud), 2026-10-07T18:55Z → 2026-10-07T20:00Z — complete (`SESSION_LOG.md`, last entry; `docs/72`)
previous_handoff: complete — READY_FOR_HANDOFF / owner NONE (CLAUDE-B local on the owner's PC, 2026-10-07T05:55Z)

## HEAD of every repository — all working trees clean, level with their remotes

| Repository | Branch | HEAD | This session |
| --- | --- | --- | --- |
| `erp-backend` | `reports-export` | `55a5119` | `55a5119` (D152: `movement` on every tracked method) — pushed `be024dd..55a5119` |
| `erp-mobile` | `reports-export` | `b79d74c` | `b79d74c` (D152: the movement line, *Set account amounts*) — pushed `0b525b3..b79d74c` |
| `erp-control-web` | `main` | `0417bfe` | unchanged |
| `erp-docs` | `master` | the commit carrying this file | `0821041` (takeover), this commit — pushed |

The four draft PRs (backend #1/#2, mobile #1/#2) are unchanged. No migration this session: the schema is still `0087`.

## What this session delivered (decision D152 in `docs/21`; record `docs/72`; device steps `docs/24` §59)

1. **Diagnosis, read-only, before the fix** (`docs/72` §1): Boutique 2's Sedad was **never set** — no `money_anchors`
   row — and the position API surfaced an unanchored account's movement nowhere, so the card could only say *Unknown*.
   Reproduced on a disposable copy on the unchanged build (`be024dd`), line for line with the owner's screenshot. Not a
   failed sale, not a date error, not a scope error. The read-only SQL and HTTP read for the owner's PC database are
   in `docs/72` §1.4.
2. **D152** — every `trackedMoney` method carries `movement {businessDate, inflows, outflows, net}` (the drawer this
   branch's closing day figures; an account company-wide for the branch's business day, the closing's seven sources
   and filters). Unknown + 20 000 stays unknown; known 5 000 + 20 000 = 25 000, counted once; explicit 0 is known; no
   total while any included balance is unknown. The card says *Starting amount unknown · +20 000 MRU recorded today*
   beneath an unknown account (EN/FR/AR, RTL-safe) and offers the Owner **Set account amounts** → the existing
   company-wide sheet. No new ledger; the opening workflow untouched.
3. **Verified** (`docs/72` §5): backend 185 suites / 3 364 passed; a 27-check real-HTTP matrix and a 7-check
   business-day boundary on the disposable copy, all passed; mobile `tsc`, lint, 92 node suites, parity 3 323 × 3,
   6 rendered suites / 35 tests. **NOT DEVICE VERIFIED** — `docs/24` §59.

## Repository state versus runtime state

The owner's iPhone runs **Expo Go** from the PC's Metro (`docs/71` §1); the last line it showed was
`0b525b3 · reports-export · Expo Go`. **It has not run `b79d74c`**, and the PC's API (port 3010, built from `be024dd`)
does not carry `55a5119`. To see D152 on the phone: on the PC, `git pull --ff-only` in both checkouts, rebuild and
restart the API, `npx expo start -c` on the Metro port in use, then Devices → *This device* must read `b79d74c` (or
later) before any device claim (`docs/70` §3).

## Live state

- The live database was **not touched** and is still at `0083`. Owed on live, in order, each only with the owner's
  approval and a verified backup: `0084`, `0085` (`docs/67` §7), `0086` + transition (`docs/69` §2), then `0087`
  (`docs/71` §6). D152 needs no migration: the API at `55a5119` runs on `0087`.
- Nothing deployed or submitted; no message sent; no provider configured; no iOS build.

## The owner's PC (local development, not live, not shared)

Unchanged from the previous handoff: repositories side by side in `C:\wamp64\www\ERP\`; the local database
`127.0.0.1:3308` `phonestore` at `0087` with its two backups; Node 22 portable; Smart App Control blocks the web
export. The checkouts there are now **one commit behind** each code repository (`55a5119`, `b79d74c`).

## Blockers and owed decisions

1. **Live:** `0084` → `0087` with backups and approval (above). Nothing in the code blocks it.
2. **Arabic on a native build** — `docs/24` §57 C: no Mac or Apple developer account here.
3. **The web export and route audit** — run them where `lightningcss` 1.33 may load.
4. **Eight Expo patch updates** (Doctor 20/21) — `expo-camera`'s native patch re-cut first.
5. **Seen in passing (`docs/72` §5):** opening the next business day with **Keep** on a negative tracked drawer answers
   500 (`ck_opening_decisions_amount`) instead of a clear refusal — a small follow-up in the opening flow.
6. Unchanged: D138b (when transition seats become paid); no email delivery provider; the website is not
   production-ready (`docs/69` §4).

## Next exact action

1. Owner: on the PC, pull both checkouts, rebuild the API, restart Metro with `-c`, and run `docs/24` §59 on the
   phone (Boutique 2: Sedad's line, *Set account amounts*, then set Sedad and watch 5 000 + 20 000 = 25 000).
2. Owner: decide on the live runbook for `0084`–`0087` (`docs/67` §7, `docs/69` §2, `docs/71` §6).
3. Next session: the Keep-on-a-negative-drawer refusal (blocker 5), the web gate where `lightningcss` loads, the Expo
   patch updates — or whatever the owner asks next.

## Verification of this session (summary; `docs/72` §5)

- Backend: `tsc`; 185 suites / 3 364 passed / 3 skipped; `money-positions.spec.ts` 42; `money-anchors.service.spec.ts` 39.
- Real HTTP on the disposable `prisma_qa_ph4` (`0001`–`0087`): the 27-check matrix and the 7-check day boundary, all
  passed; the copy dropped, the throwaway MySQL stopped, the scratch env file shredded.
- Mobile: `tsc`; `expo lint` 0 errors / 29 warnings (baseline); 92 node suites; parity 3 323 × 3; 6 rendered suites /
  35 tests.
- Device: **NOT DEVICE VERIFIED** — `docs/24` §59.
