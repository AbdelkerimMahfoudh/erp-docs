# CURRENT_HANDOFF

Status: IN_PROGRESS
Owner: CLAUDE-B
started_at_utc: 2026-10-10T04:30Z
session: CLAUDE-B (local, the owner's Windows PC) — takeover from READY_FOR_HANDOFF / NONE (previous handoff complete)
scope: the owner's brief of 2026-10-10 on the PC — fix the access screen's grant date (Known gaps); back up and restore-check phonestore; apply 0088–0091 to the PC database; restart API and Metro (-c); prove 2fc01a1 or a descendant on the phone; run docs/24 §62 then §59–§61 with invented rates and fake numbers. PC checkouts at takeover: backend be024dd (32 behind bea454c), mobile 0b525b3 (21 behind 2fc01a1), clean.
next: fast-forward both checkouts, install, then the access-screen fix.
last_session: CLAUDE-B (cloud), 2026-10-10T00:30Z → 2026-10-10T04:20Z — complete
previous_handoff: complete — READY_FOR_HANDOFF / owner NONE (docs `01e6d2a`); taken over on the owner's brief of
2026-10-10 ("stabilize, merge and prepare the Money Services Agent feature for physical-device testing")

## HEAD of every repository — all four trees clean and level with their remotes

| Repository | Canonical branch | HEAD | This session |
| --- | --- | --- | --- |
| `erp-backend` | `reports-export` | `bea454c` | `2a8151e`, `93ae8ac`, `897dda6`, `86a492e`, `e3571b8`, `1bcf250`, `e8f254b`, `800860b`, `4f9a63d`, `e688d26`, `0636b78`, `69e39ca`, `bea454c` — pushed |
| `erp-mobile` | `reports-export` **=** `money-agent-4` | `2fc01a1` | `a90a0b8`, `2ef9ecd`, `aeecf71`, `bbffdd4`, `2fc01a1`; both branches fast-forwarded and pushed (`reports-export` now carries the whole agent feature) |
| `erp-control-web` | `money-agent-3` | `36f04b2` | `8161014`, `36f04b2` — pushed. **`main` still `0417bfe`**: its fast-forward to `36f04b2` is verified but not pushed (blocker 1) |
| `erp-docs` | `master` | the commit carrying this file | `1c97f27` (takeover), this commit — pushed |

Containment proven with `git merge-base --is-ancestor` for every feature commit: mobile `9d74cf7`…`45b0e2a` and
`a90a0b8`…`2fc01a1` in both `money-agent-4` and `reports-export`; website `e950840`…`36f04b2` in `money-agent-3`.
The merges were fast-forwards (the destinations had nothing newer). The four earlier draft PRs (backend #1/#2, mobile
#1/#2) are unchanged; no PR was opened.

## What this session delivered (`docs/73` §11; D158–D161 in `docs/21`; session log 2026-10-10T00:30Z)

1. **D158 — billing decisions**, recorded verbatim and built: a store replacing one archived in the same paid period
   pays nothing more when the same or cheaper (it opens at once), the difference when dearer, the full price beside a
   store still running; an append-only link (`branch_replacements`); race- and retry-safe; a stale difference refused
   at confirmation (`replacement_no_longer_applies`). D154 (f) confirmed, (g) superseded.
2. **D159 — the closing refuses a confirmation made on money that moved**: `money_version` on the day row, bumped by
   every money writer under the day's lock; `report_changed` / `money_moved_after_count` with the current report; the
   phone says *Money changed after counting began* and recounts exactly what moved; a reopened day's recount keeps the
   difference its close recorded.
3. **D160 — provider settings retry-safe** (`clientRequestId`, `agent_request_keys`).
4. **D161 — a refused offline exchange has a clear outcome**: stable codes, the status lookup, six queue states, the
   customer number under a scoped key.
5. **The website's complimentary date**: the grant with its own dates (`complimentary` on the entitlement and the
   console list), never a paid-period date in its place.
6. An adversarial review (17 agents): 12 findings confirmed, all fixed except one pre-existing phone display (below).

## Verification (exact totals, disposable data only)

- Backend `bea454c`: `tsc` clean; jest **207 suites / 3 803 passed / 3 skipped**; `prisma validate` clean. Real HTTP +
  real MySQL at `0091`: **66/66**. Backend lint not run (no ESLint 9 configuration).
- Website `36f04b2`: `tsc`; **8 files / 48 tests**; production build; Chromium against the real API **12/12** (EN, FR,
  AR at 360; RTL; no sideways scroll; the console list).
- Mobile `2fc01a1`: `tsc` clean; **103/103** pure suites; jest **14 suites / 150 tests**; `expo lint` 0 errors / 29
  warnings (baseline); parity **3 754 × 3**; web export clean (64/64 static routes; 16 dynamic); expo-doctor 19/21 (two
  network checks); the web export against the real API **7/7**.
- Migration rehearsal `0088` → `0091` with backup and path-2 restore (`docs/22` E.5): demo data unchanged, the restore
  identical to the pre-0088 fingerprint.
- **Phone: NOT DEVICE VERIFIED** — cloud session; `docs/24` §62 (new) and §59–§61 are all owed on a device.

## Migrations and data

- Code schema: **`0091`**. **Live untouched at `0083`.** **The PC database (`127.0.0.1:3308` `phonestore`) untouched at
  `0087`.** `0088`–`0091` are rehearsed only, never applied anywhere shared.
- Owed on live, in order, each only with the owner's approval and a fresh verified backup: `0084`, `0085`
  (`docs/67` §7), `0086` + transition (`docs/69` §2), `0087` (`docs/71` §6), then `0088`–`0091` in one deploy
  (`docs/73` §8.2 and §8.3). Order: migrations → API (`bea454c` needs `0091`) → website → app (`2fc01a1` needs that API).
- Disposable infrastructure all removed: MySQL `:3310` stopped and its data directory deleted, `prisma_qa_st` and
  `_shadow` dropped, the API on `:3080` and previews on `:4173`/`:4180` stopped, env/password files and dumps
  shredded, the scratch worktree removed. `erp-backend-seed` (an older worktree) left as it was.
- Nothing deployed, published or submitted; no message sent; **no provider configured or enabled**; invented rates and
  fake numbers (`0000xxxx`) only.

## Remaining blockers

1. **Website `main` not pushed.** `git push origin main` (a verified fast-forward `0417bfe` → `36f04b2`) was refused by
   this session's permission check as a possible production deploy and was not retried. Evidence that `main` deploys
   nothing: no GitHub deployments, no commit statuses or check runs on any `main` commit, no Actions workflows, Pages
   off, no hosting configuration in the repository, and `docs/68` §7 records that nothing is hosted. Repository
   webhooks are not readable from the cloud container. **Owner:** confirm no host deploys `main` (Settings → Webhooks;
   any hosting provider), then `git fetch && git checkout main && git merge --ff-only origin/money-agent-3 && git push`.
2. **Physical device testing**: `docs/24` §62 (offline states, the uncertain lookup, the closing after money moved,
   provider retries) and §59–§61 — run on the PC with invented test configuration only.
3. **The seven provider configuration blanks** (`docs/73` §1.2): until the Owner enters the real schedules each provider
   answers `provider_not_configured`. Enabling a real provider needs the owner's explicit approval.
4. **Live migrations** `0084`–`0091` with approval and backups.

## Owed decisions (the owner's)

1. **Archive a store in the app** — no in-product archive action exists, so D158's replacement rule only applies to a
   branch deactivated outside the app (`docs/73` §11.6). Offering *Archive this store* (its stock, drawer, floats,
   staff and debts) is a product decision.
2. Unchanged: D138b (when transition seats become paid); no email delivery provider; the website is not
   production-ready (`docs/69` §4).

## Known gaps (recorded, not hidden)

- The phone's access screen reads the paid period's end while a platform grant runs (`app/access.tsx`; pre-existing,
  outside this phase's website scope) — should show the later of the grant's and the paid end.
- The pre-existing lock-order inversion between an exchange (provider, then day) and the close / rebalancing / reversal
  (day, then provider through a foreign key) remains; a deadlock there rolls the loser back whole (no wrong money) and
  answers a generic 400. This phase removed the new inversions it had introduced.
- Carried over: Arabic on a native build (`docs/24` §57 C); the web export and route audit on the PC (`lightningcss`);
  eight Expo patch updates; an Expo web export inlines `EXPO_PUBLIC_*` only with `--clear`.

## Next exact action

1. Owner: settle blocker 1 (the website `main` push) after checking for a deploy hook.
2. Owner, on the PC, with a verified backup of `phonestore` first (`docs/22`): `git fetch`; check out `erp-backend`
   `reports-export` (`bea454c`) and `erp-mobile` `reports-export` (`2fc01a1`); `npx prisma migrate deploy` (`0088`–`0091`;
   check per `docs/73` §8.2–§8.3); rebuild and restart the API; `npx expo start -c`; confirm Devices → *This device*
   reads `2fc01a1`; run `docs/24` §62, then §59–§61, with invented rates and fake numbers only; record each item as
   DEVICE VERIFIED / FAILED / NOT VERIFIED.
3. Next session: whatever the owner asks; nothing is in progress.
