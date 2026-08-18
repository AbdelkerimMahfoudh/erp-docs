# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Active account / Owner: **CLAUDE-B**
- started_at_utc: `2026-08-18T05:20Z`
- Authorised task: **J.1 offline-draft coverage, then Milestones K and L, then
  the final A–L verification gate.** Do not begin another feature milestone.
- Takeover verified against the previous handoff, **no discrepancies**: 87
  suites / 1495 tests · 50 migrations · 19 triggers · Prisma valid and current ·
  mobile tsc clean · 10 pure suites · EN/AR 1616 · all three trees clean and
  level at backend `53bf545`, mobile `e73dff9`, docs `7847e82`.
- **Expo Doctor, precisely:** the failing check is *packages match versions
  required by installed Expo SDK*. Three **patch** shortfalls, each installed
  BELOW the floor: `expo` 54.0.36 vs ~54.0.37, `expo-constants` 18.0.13 vs
  ~18.0.14, `expo-file-system` 19.0.23 vs ~19.0.24. Not a new dependency, so a
  patch bump will be attempted at the final gate and reported either way.
- **K0 note:** no subscription, billing, plan or entitlement remnant exists.
  The only greps that hit are doc comments saying a Store Account ID is *not* a
  subscription id. K starts from nothing.
- Previously completed: **Milestones A–J**.
- **J.1 COMPLETE** (mobile `3efb063`): six more forms now survive a process
  kill — receiving, consignment proposal, expense, return request, loan
  proposal, goal. Scope is the filename (user/company/branch/form/record);
  binary and credential fields refused before any write; restores are visible
  and offer to start fresh; drafts clear only on confirmed acceptance. A
  restored consignment re-asks the server about every phone before proposing.
  Import preparation deliberately NOT drafted — nothing local to lose, and the
  spreadsheet bytes are exactly what must never persist. 19 new tests,
  11 pure suites, EN/AR 1622.
- **K COMPLETE and live-verified.** K0 audit in docs/33. Migration **0052**
  (`subscriptions` + append-only `subscription_events`); **51 migrations**,
  **21 triggers**. Every existing company backfilled with a year so no tenant
  locks on deploy. Grace is 72h, derived from the period. Writes continue
  through grace; reads and exports are never blocked. Seats pool across the
  company, the Owner consumes none, and nobody is ever auto-deactivated.
  Provisioning is platform-key only and unreachable by any tenant token.
  Mobile: /subscription screen with no price or payment control, stale-cache
  honesty, and ENTITLEMENT_WRITE_BLOCKED as its own non-looping queue kind.
- **The live run found a real defect unit tests could not:** entitlement was a
  global guard and ran BEFORE the JWT guard, so no company was resolved and
  every write hit the fail-closed branch. Moved to an interceptor, which the
  request lifecycle guarantees runs after every guard. Fixed in backend
  `516ab35`. **Live K: 59/59.**
- Backend **88 suites / 1530 tests**; mobile tsc+lint clean, 11 pure suites,
  EN/AR **1645**, /subscription exports.
- Commits: backend `516ab35`, mobile `b0bd672`.

### Next action, exactly

- **L in progress.** L0 audit in `docs/34` (accounting dictionary + timing
  table + recorded gaps). **L-CP1** `accounting-rules.ts`, 25 tests pinning the
  identities. **L-CP2** `GET /analytics/summary?from&to`, reading
  `daily_rollups` and the ledgers rather than recomputing. Backend now
  **89 suites / 1555 tests**. Commits: backend `8b5c180`, mobile `b0bd672`.

**L-CP3 — the mobile analytics screen.** Rework `mobile/app/analytics.tsx` to
the hierarchy the brief sets: today/period first, then profit, cash movement,
amounts owed and owing, inventory position, discrepancies and attention items,
then goals/trend. Consume `/analytics/summary`; render nothing the server did
not send, and show anything in its `unavailable` array as genuinely
unavailable rather than as zero. Tabular money values, EN/AR parity, RTL-safe,
proper loading/empty/error/offline/permission states, no colour-only meaning,
no chart library. A shareable summary may build text/HTML locally but must not
send WhatsApp messages or claim delivery.

**L-CP4 — live analytics checks** against real MySQL with fixtures across
several dates and channels: return counted once, refund payout affecting cash
once and profit zero times, supplier settlement moving cash but not profit,
expense timing, correction replacement, per-channel attribution, branch and
company isolation, cost/margin gating, equal-period comparison boundaries,
timezone boundaries, empty and zero-denominator periods, and agreement between
the summary and the closing/rollup sources. Clean deletable fixtures; preserve
audit rows.

**Then the final A–L gate** exactly as the brief lists it — including
attempting the Expo Doctor patch bump (three patch shortfalls recorded above)
and reporting the outcome either way, plus docs/21, docs/24, session log, and
`A_L_COMPLETE` in the final handoff.

**The API is RUNNING on 3010** (watch mode), started by this session for live
verification. Metro is not running. Stop the API at the final gate.

### Repository state — all three clean and pushed

| Repository | HEAD |
|---|---|
| `erp-backend` | `53bf545` |
| `erp-mobile` | `e73dff9` |
| `erp-docs` | *this commit* |

Milestones **A–J** are complete.

---

## Milestone J — COMPLETE

| Step | State |
|---|---|
| **J0** audit of cache, auth, storage, AppState, errors, idempotency and every mutation | ✅ [`docs/32`](docs/32_OFFLINE_AUDIT.md) |
| **J-CP1** the classification as an enforced module, 34 tests | ✅ |
| **J-CP2** server hardening, migration `0051` | ✅ |
| **J-CP3** durable queue, request timeout, replay engine | ✅ |
| **J-CP4** Sync centre, session wiring, per-screen states | ✅ |
| **J-CP5** live replay verification, **35/35** | ✅ |
| **J-CP6** Sell cart survives an app kill; docs | ✅ |

### The binding decision

**There is no server-issued inventory lease.** Nothing can promise a
disconnected device that an IMEI is still unsold. A sale may be *prepared*
offline and may never be *finalized* offline — **Charge is online-only**, and
the same reasoning governs every authoritative stock and money operation.

### Only four operations may be queued

`expense.submit` · `loan.payment.report` · `consignment.payment.report` ·
`notification.read`. All are claims or flags; none moves stock, settles money or
grants authority. Everything else is online-only, and `classify()` returns
`online_only` for anything it does not recognise — a future milestone that adds
a mutation and forgets the file fails closed.

### The gap the audit found, and closed

`loan_ledger` and `consignment_ledger` replayed on the client UUID alone. Behind
a queue, an edited report would have been answered with the *original* amount
while the phone showed **synced**. Migration `0051` adds `client_request_hash`
to both; all three queueable endpoints now refuse a changed payload with 409,
**proven live on each**.

---

## Verification at close

| Check | Result |
|---|---|
| Backend suites | **87 suites / 1495 tests**, green |
| Backend `tsc` | clean |
| Prisma validate / migrate status | valid · **50 migrations**, up to date |
| Database triggers | **19** |
| Mobile `tsc` | clean |
| Mobile lint | clean *(one warning in Expo's generated, git-ignored `.expo/types/router.d.ts`)* |
| Mobile pure suites | **10/10** — run with `node lib/<name>.test.ts`, **not jest** |
| Expo web export | every route bundles, including `/sync` |
| Expo Doctor | 17/18 · three **patch** drifts (`expo`, `expo-constants`, `expo-file-system`), pre-existing |
| EN/AR parity | **1616 / 1616**, nothing missing either way, no duplicates |
| Live J replay | **35/35** over real HTTP and MySQL |

### Demo data, after cleanup

Sales **7 / 10 051.00** · unit checksum **`2a1dc9bf284afde32b402ad108d38a76`**
(unchanged) · **1** company · zero rows left in `loans`, `loan_ledger`,
`consignments`, `consignment_lines` or `store_connections`. Audit rows were
**preserved, not deleted**.

Both temporary companies were removed. **No permanent company or identity was
left behind.** No scratch database was created; all live testing used temporary
companies inside the shared database, created and removed within each run.

### Backup

`phonestore-20260818-033659.sql` — 496 KB, 19 triggers captured, taken before
migration `0051` per [`docs/22`](docs/22_BACKUP_AND_ROLLBACK.md).

---

## What is NOT done, stated plainly

- **Every device check in [`docs/24`](docs/24_DEVICE_QA_CHECKLIST.md) under
  Milestone J is unrun.** Airplane mode, Wi-Fi without internet, a real Android
  low-memory kill, background/foreground, the shared counter phone, Arabic RTL,
  and whether a first-week employee reads "waiting to send" as anything other
  than "sent". **No claim is made about any of them.** They need hardware.
- **React Query caches are still memory-only.** A cold start offline shows empty
  lists rather than stale ones. A persister is a real improvement *and* a real
  risk — stale prices and stale stock shown confidently are their own kind of
  lie — so it was deliberately left to a milestone that can think about
  staleness properly rather than bolted on here.
- **No attachment bytes are ever queued.** The evidence reference on a payment
  is a short string, not a file, so there is no attachment lifecycle to clean
  up. If images are ever queued, that needs its own audit.

## Ports and processes

**Nothing is left running.** The API on 3010 was started by this session purely
for live verification and stopped again; Metro was never started. Note that the
*previous* handoff claimed 3010 and 8081 were running for the user's device
testing — both were already down at takeover, which was the one discrepancy
found.

To run the app for device testing:

```bash
cd backend && npm run start:dev
```

```bash
cd mobile && npx expo start
```

## Next action

**Milestone K — subscription entitlement.** Not started, and not to be started
without the user's go-ahead.

Before K begins, the question worth settling: whether entitlement gates at the
**company** level or the **feature** level, and what a shop whose subscription
lapses can still do. The honest default — reads keep working, writes stop — is
worth confirming rather than assuming, because a shop locked out of its own
sales history mid-day would reach for the notebook immediately.

**L** (analytics polish) also remains untouched.
