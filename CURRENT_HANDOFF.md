# CURRENT_HANDOFF

Status: READY_FOR_HANDOFF
Owner: NONE
last_session: CLAUDE-B — 2026-10-06T01:16Z → 2026-10-06T02:01Z (the iPhone ran an older bundle: reconciliation, the build identifier, the opening-cash invariant, RTL that follows the app, the Home header, rendered tests)
previous_handoff: complete (this file replaces the IN_PROGRESS snapshot of 2026-10-06T01:16Z)

## HEAD of every repository — all working trees clean, level with their remotes

| Repository | Branch | HEAD | Remote |
| --- | --- | --- | --- |
| `erp-backend` | `reports-export` | `1bf65b5` | pushed (`d670401..1bf65b5`) |
| `erp-mobile` | `reports-export` | `2347523` | pushed (`81cb599..2347523`) |
| `erp-control-web` | `main` | `0417bfe` | unchanged — `https://github.com/AbdelkerimMahfoudh/erp-control-web` |
| `erp-docs` | `master` | the commit carrying this file | pushed |

The four draft PRs (backend #1/#2, mobile #1/#2) are unchanged by this session.

## Repository state versus runtime state — read this first

**Repository state (verified here):** the commits above pass every gate — backend `tsc` and 184 suites / 3 318 tests;
mobile `tsc`, `expo lint` (0 errors), 91 node suites, parity, 15 rendered tests under jest-expo, the web export; a real
browser against the real API proved the header layout, the navigation by role, Notifications' console and the
opening-cash journey (93 passed, 0 failed; `docs/70` §6).

**Runtime state (NOT verified here):** the iPhone screenshots of 6 October were of a bundle **older than `81cb599`**
(`docs/70` §1 — the LogBox line numbers and the *Import stock* row prove it). Nothing in this phase ran on a device.
Until the Devices screen on the phone shows the build line with the commit `2347523` (or later) and a *Configuration
read* time after a fresh `npx expo start -c`, no claim about the phone can be made. The Arabic direction additionally
needs a **new native build** (`app.json` changed): neither Expo Go nor a reload applies it.

## What this session delivered (detail in `docs/70`; decisions in `docs/21` D145–D149)

1. **The reconciliation** — what the screenshots prove, what cannot be read from here and how the owner reads it on
   the PC, the exact safe synchronisation steps (`docs/70` §1–§3). No destructive git command anywhere in them.
2. **The build identifier (D145)** — `app.config.js` → `extra.build`; Devices → *This device*, development only.
3. **The opening-cash invariant (D146)** — keep refused while the drawer is unknown (`opening_cash_unknown`), 0 set
   explicitly; the Owner sets an open day's unknown drawer from Money; carried openings unchanged; no migration.
4. **RTL follows the app (D147)** — `supportsRTL` removed (it forced the device locale's direction at every launch on
   iOS); `allowRTL`/`forceRTL` follow the language; relaunch recognised by the session id; honest Expo Go verdict.
5. **The Home header (D148)** — the tint's parent unpadded; measured symmetrical at 320/393, 1×/1.3×, EN/FR/AR.
6. **Rendered tests (D149)** — `npm run test:render`; React Native's own nesting warning (with a control), More/Stock/
   `/imports` for the three roles, the header's structure. The blank toast's real callers fixed at the source.

## Live state

- The live database was **not touched** and is still at `0083`; **no migration in this phase**. Owed on live, in order
  and only with the owner's approval and a verified backup: `0084`, `0085` (`docs/67` §7), then `0086` with the
  transition script (`docs/69` §2). The opening rule needs no data change: days already open on an unknown drawer stay
  as they are, and the Owner sets them from Money.
- Nothing deployed or submitted; no message sent; no provider configured; no iOS build.

## Blockers and owed decisions

1. **The device run — `docs/24` §57**, on the pushed commit from a restarted Metro (A first: the Devices build line
   as proof), then B, D, E, F; **C (Arabic) only on a new native build.** The result decides whether the five
   reports are closed; nothing here closes them.
2. **The Windows checkout** must be brought level per `docs/70` §3 (`git pull --ff-only`; stop on anything unexpected).
3. **D138b** — the date from which granted (transition) seats become paid seats (unchanged).
4. **No email delivery provider exists in the backend**; the website is **not production-ready** (`docs/69` §4) —
   unchanged.
5. `expo-doctor`'s schema and React Native Directory checks cannot run from this container (proxy); run them on the PC.

## Next exact action

1. Owner: `docs/70` §3 on the PC, then `docs/24` §57 A — send the Devices screenshot with the build line.
2. Owner: a new native build (`npx expo run:ios` on a Mac, or EAS) for §57 C; the rest of §57 on Expo Go or the build.
3. Next session: act on what §57 reports; otherwise the owed items of earlier phases (D138b, the live runbooks when
   approved, the website's providers).

## Verification of this session (summary; `docs/70` §6)

- Backend: `tsc` clean; 184 suites / 3 318 tests (3 skipped, as before); the closing suites extended (keep refused,
  set 0, carried unknown, the widened review, a decision-less open day).
- Mobile: `tsc` clean; `expo lint` 0 errors / 29 warnings (baseline); 91 node suites; catalogue parity; 15 rendered
  tests; `expo export --platform web`; `expo config` carries `extra.build`.
- Browser: 93 passed, 0 failed — 23 screenshots in scratchpad `ph3/shots/` with `RESULTS.txt`.
- Disposable MySQL `prisma_qa_ph3` migrated `0001 → 0086` from empty and seeded through the API; dropped at the end.
