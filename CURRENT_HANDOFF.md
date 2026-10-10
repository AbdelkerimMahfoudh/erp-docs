# CURRENT_HANDOFF

Status: IN_PROGRESS
Owner: CLAUDE-B
started_at_utc: 2026-10-10T00:30Z
previous_handoff: complete — READY_FOR_HANDOFF / owner NONE (CLAUDE-B cloud, 2026-10-09T14:20Z, docs `01e6d2a`);
takeover authorised by the owner's brief of 2026-10-10 ("stabilize, merge and prepare the Money Services Agent
feature for physical-device testing")

## Active phase (2026-10-10, cloud) — money-agent stabilization, branch integration, device-test preparation

HEAD at takeover, all four trees clean and level with their remotes (fetched 2026-10-10): `erp-backend`
`reports-export` `35b5836` · `erp-mobile` `money-agent-4` `45b0e2a` (`reports-export` `bf30299`) ·
`erp-control-web` `money-agent-3` `2c49795` (`main` `0417bfe`) · `erp-docs` `master` `01e6d2a`. Schema in the code
`0090`; live `0083` and the PC `0087` are unreachable from this cloud container and are not touched.

**The merge contradiction, resolved with Git (2026-10-10):** the previous report's "merged" applied to the
**backend worktrees only** — the reflog shows `merge money-agent-2b: Fast-forward` (`6414c55`), the merge commit
`c35384d` (money-agent-2c) and `merge money-agent-2c: Fast-forward` (`3b26e95`), all on `erp-backend`
`reports-export`, which contains every backend agent commit (`git branch -a --contains` `258b04d` … `35b5836` →
`reports-export` only; `origin/master` ⊂ `reports-export`). **Mobile and website were not merged:** `erp-mobile`
`merge-base(money-agent-4, reports-export)` = `bf30299`, `reports-export..money-agent-4` = 14 commits
(`9d74cf7`…`45b0e2a`), the reverse 0; `9d74cf7` and `45b0e2a` are contained in `money-agent-4` only, and
`reports-export` has no `app/agent/`. `erp-control-web` `merge-base(main, money-agent-3)` = `0417bfe`,
`main..money-agent-3` = 7 commits (`e950840`…`2c49795`), the reverse 0. **The PC's mobile checkout
(`reports-export`) therefore does not carry the agent feature**, and the website's `main` does not either.

Scope (the brief): record the binding billing decisions (downgrade keeps the activity to the period end; an archived
branch's replacement in the same paid period free when same or cheaper, the activity difference when dearer, a
simultaneous extra branch at full price; an immutable link; race- and retry-safe) and implement them with tests; the
closing refuses a stale confirmation when money moved after the count was loaded; provider creation and financial
settings idempotent; a clear outcome for a refused offline exchange (server codes, a status lookup, the queue's six
states); the website's complimentary date; then merge mobile `money-agent-4` → `reports-export` and website
`money-agent-3` → `main` (stopping before any push that would deploy); full gates, real HTTP/MySQL journeys on
disposable data, a backup/restore rehearsal of the migrations; docs and this file. No live, no PC database, no deploy,
no real provider, rate or customer number.

Next intended action: discovery of the billing, closing, provider, offline-queue and complimentary code; the design
recorded in `docs/73`; then the backend.

## HEAD of every repository — all four trees clean and level with their remotes

| Repository | Branch | HEAD | This session |
| --- | --- | --- | --- |
| `erp-backend` | `reports-export` | `35b5836` | `258b04d` (D153), `229caaf`, `a3b18d1`…`35b5836` (checkpoint 2 and both reviews' fixes) — 18 commits, pushed |
| `erp-mobile` | `money-agent-4` (off `bf30299`) | `45b0e2a` | `bf30299` (D153, on `reports-export`), `9d74cf7`…`45b0e2a` (checkpoint 4 and its review fixes) — pushed as a branch |
| `erp-control-web` | `money-agent-3` (off `main` `0417bfe`) | `2c49795` | `e950840`…`2c49795` (checkpoint 3) — pushed as a branch; **`main` deliberately unchanged at `0417bfe`** |
| `erp-docs` | `master` | the commit carrying this file | `bd360a4`, `f94b82f`, `d204104`, `c743146`, `4252682`, `87ce55f`, this commit — pushed |

`erp-mobile`'s `reports-export` stays at `bf30299`; the agent work lives only on `money-agent-4`. The website's
`main` was not moved because a host could watch it and nothing is deployed without the owner's approval. The four
draft PRs (backend #1/#2, mobile #1/#2) are unchanged; no PR was opened this session.

## What this session delivered (`docs/73`; D153–D157 in `docs/21`; session log 2026-10-08T00:10Z)

1. **D153** — Keep on a drawer tracked below zero: a named 400 `opening_cash_negative` instead of the 500; the phone
   offers no Keep and says why (`docs/24` §60).
2. **Checkpoint 1 — contract and model** (`docs/73`): per-branch activity and its pricing (500 / 300 / 700, never
   500 + 300; an upgrade's difference now, a downgrade at the renewal), the append-only agent ledger, positions, one
   drawer and one closing with the floats beside it, offline rules, nine permission keys, worked examples, the seven
   configuration blanks.
3. **Checkpoint 2 — backend**: migrations `0088`–`0090` (additive, rehearsed only); activity requests, the renewal,
   the D156 activity gate; providers with versioned configuration gated while blank; exchanges, mistakes, one
   reversal, rebalancing, positions, reports; the closing integration. Two adversarial reviews, every finding fixed.
4. **Checkpoint 3 — website**: activity at application and for later stores; the Owner's change panel reads the
   server's own answer (`GET my-subscription/activity-options`); the Super Admin's requests and three plan prices.
5. **Checkpoint 4 — mobile**: tab bars per activity and role (agent-only Home · Transactions · Money · Reports · More;
   combined branches checked visually in EN/FR/AR at 393 and 320); the counter with one review; the offline queue
   with the customer number in SecureStore only; Money's floats, rebalancing, providers; reports; the floats in the
   Daily closing, and no closing while the phone holds exchanges. A review's three blockers and five more, all fixed.

## Verification (exact totals)

- Backend `35b5836`: `tsc` clean; **200 suites / 3 630 passed / 3 skipped**. Real HTTP on the disposable copy (after
  `0090`): agent matrix **141/141**, business-day rollover **8/8**, due renewal **8/8**, review fixes **14/14**.
  Backend lint **not run** — the repository has no ESLint 9 configuration.
- Website `2c49795`: **7 files / 36 tests**, `tsc`, build; Chromium journey against the real API **15/15** (EN, AR at
  360, RTL, no sideways scroll).
- Mobile `45b0e2a`: `tsc` clean; **101 node suite files**; `expo lint` 0 errors / 29 warnings (baseline); parity
  **3 723 × 3**; jest **12 suites / 130 tests**; web export clean; expo-doctor 19/21 (two network checks). Web export
  against the real API: the tab bars as designed, and one exchange end to end **7/7**.
- Device: **NOT DEVICE VERIFIED** — `docs/24` §61 (and §59, §60 still owed). Offline behaviour can only be proven on
  a phone.

## Live state, migrations and data

- **Live untouched at `0083`.** Owed on live, in order, each only with the owner's approval and a fresh verified
  backup: `0084`, `0085` (`docs/67` §7), `0086` + transition (`docs/69` §2), `0087` (`docs/71` §6), then `0088`–`0090`
  (`docs/73` §8.2 — rehearsed with backup and restore, **not applied anywhere shared**).
- The owner's PC database (`127.0.0.1:3308` `phonestore`) untouched at `0087`; its checkouts are behind (backend
  `55a5119`, mobile `b79d74c`) and would need `0088`–`0090` before running `35b5836` — a backup first (`docs/22`).
- Disposable infrastructure all removed: MySQL `:3310` stopped, `prisma_qa_ma` and `_shadow` dropped, APIs on
  `:3080`–`:3086` and previews on `:4173`/`:4180` stopped, scratch env files shredded, dumps deleted, worktrees
  `money-agent-2b`/`-2bfix`/`-2c` removed after merging.
- Nothing deployed, published or submitted; no message sent; **no provider configured or enabled**; fixtures used
  invented rates and numbers only.

## The money-agent feature is NOT production-ready

It stays gated until all of these are resolved:

1. **The seven configuration blanks** (`docs/73` §1.2) — Bankily's rate, Sedad's rate, other providers' rates, same
   rate both directions, where the commission lands, fee deducted or separate, which providers require references.
   Until the Owner fills them from the real schedules each provider answers 409 `provider_not_configured`. Enabling a
   provider for real transactions needs the owner's explicit approval.
2. **Physical device verification** — `docs/24` §61, offline (airplane mode, restart, two devices, day rollover)
   included.
3. **Live migrations** `0084`–`0090` with approval and backups (above).

## Owed decisions (the owner's)

1. **D154 (f)** — keeping `both` after scheduling a downgrade costs nothing; **(g)** the period remembers each
   branch's own fee, so a store replacing an archived one mid-period costs its whole month. Confirm or correct.
2. Whether and when to merge the website's `money-agent-3` into `main` (a host may deploy `main`).
3. Whether to merge `erp-mobile` `money-agent-4` into `reports-export` (the branch the PC's Metro runs).
4. Unchanged: D138b (when transition seats become paid); no email delivery provider; the website is not
   production-ready (`docs/69` §4).

## Known gaps (recorded, not hidden — session log 2026-10-08T00:10Z)

- The closing report's warning naming exchanges posted after the count started (`docs/73` §5.3) is not built; the
  phone's own refusal to close with queued exchanges is.
- Provider and configuration writes take no idempotency key (a lost answer retried is refused by name or appends an
  identical version — harmless).
- A queued replay refused by the entitlement or activity check after a change stays queued but cannot learn whether
  it was recorded.
- Website (not changed): a complimentary account reads "granted until {period start}" — the entitlement view carries
  no `complimentaryUntil`.
- Carried over: Arabic on a native build (`docs/24` §57 C, no Mac); the web export and route audit on the PC
  (`lightningcss`); eight Expo patch updates.
- Operational: an Expo web export inlines `EXPO_PUBLIC_*` only with `--clear` after the variable changes.

## Next exact action

1. Owner: decide D154 (f)/(g) and the two branch merges; supply the real provider schedules for the seven blanks
   only when ready to configure — never a sample.
2. Owner, on the PC (only with a verified backup per `docs/22`): `git fetch`, check out `erp-backend`
   `reports-export` (`35b5836`) and `erp-mobile` `money-agent-4` (`45b0e2a`), `npx prisma migrate deploy` on the PC
   database (`0088`–`0090`), rebuild and restart the API, `npx expo start -c`; confirm Devices → *This device* reads
   `45b0e2a`; then run `docs/24` §61 (and §59, §60) on the phone with the invented test configuration only.
3. Next session: whatever the owner asks — candidates are the known gaps above; nothing is in progress.
