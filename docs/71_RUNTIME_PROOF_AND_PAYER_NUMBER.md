# 71 — The runtime proven, Arabic in Expo Go, and the payer number (2026-10-07)

The owner's brief of 2026-10-07 had two priorities: find out why the latest pushed changes still did not appear on the
iPhone and make the phone load the correct code — "do not assume another source-code change will solve it; prove the
entire runtime chain first" — and add an optional payer number to non-cash sale payments. This session ran **on the
owner's Windows PC** (CLAUDE-B, Claude Code, local), with the owner's iPhone in Expo Go on the same Wi-Fi, so — unlike
`docs/70` — the device lines below were seen on the phone. Decisions **D150–D151** in `docs/21`; device results in
`docs/24` §57 and §58.

---

## 1. Why the pushed changes did not appear (Phase A)

**Proven, not assumed** — from the PC checkout, the running servers, and the phone's own traffic:

| Link of the chain | What it was | Evidence |
|---|---|---|
| The checkout Metro served | `C:\wamp64\www\ERP\erp-mobile` at **`3023bd3`**, clean, `reports-export`, **0 ahead / 5 behind** `origin/reports-export` (`2347523`); `81cb599` and `2347523` not in the branch; no `app.config.js` | `git` in that directory after `git fetch` |
| The servers | exactly **one** Metro (port 8081, started 00:39 from that checkout) and **one** API (port 3010, `erp-backend` `1434aa7`, built 00:40); nothing on 19000–19002 or any other port | process command lines and listening ports |
| What that Metro served | a manifest with **no `extra.build`**; an 18.5 MB iOS bundle with **no** build-line code; `EXPO_PUBLIC_API_HOST` inlined as `192.168.100.7` → API `http://192.168.100.7:3010` | the manifest and bundle fetched as Expo Go fetches them |
| What the phone ran | **Expo Go** (`Expo/1017880 … Darwin/24.6.0`), 36 requests to that API after the 00:40 "cleared cache" restart, loading bundles from that Metro — and its own console printed *VirtualizedLists should never be nested…* | API request log, Metro log |

**Conclusion:** the phone faithfully ran the PC checkout, and the checkout had never been pulled after 4 October.
Clearing Metro's cache could not help: the code on disk was old.

**The cure** (`docs/70` §3, done on the PC): `git pull --ff-only` in both checkouts; `npm ci` — **refused** by npm
10.9.9 and 11.21.0 because `2347523`'s `package-lock.json` lacked nine packages of the D149 test tooling, so the lockfile
was regenerated with npm 11 `--package-lock-only` (nine added, none removed, no version changed, every `libc` field
kept) and committed (`728a0d8`); a clean `npm ci`; the PC's local database backed up and brought to `0086` (§7); the API
rebuilt from `1bf65b5`; Metro started from the verified checkout with `-c` on a **new port (8082)** and a new QR code, so
an old Expo Go recent could not reopen the old project.

**The proof on the phone:** Devices → *This device* read **`728a0d8 · reports-export · Expo Go`** (later `fa5c6a5`,
then `0b525b3`), and Metro's only debugger target was `host.exp.Exponent (iPhone) — React Native Bridgeless`. The phone
runs **Expo Go** — not a development build, not an installed standalone app.

## 2. The 6 October reports on the correct bundle (A4)

| Report | Classification | Evidence |
|---|---|---|
| Notifications' nested-list LogBox | **fixed, confirmed on the correct bundle** | the owner saw none; the phone's console sent 0 errors/warnings to Metro |
| *Import stock* under More | **fixed, confirmed** | the owner: not in More, in the Stock header |
| Blank toast | **none seen** | the owner |
| Home header card width | **fixed, confirmed** | the owner: equal margins |
| Money / unknown opening cash | **fixed, confirmed** | the owner set Boutique 2's open day's drawer from Money: `POST /closings/opening/review` 201, `set` 1 000, no Keep offered |
| Arabic restart warning | **still broken on the correct bundle → fixed (D150), device-verified in Expo Go**; the layout direction **needs a native rebuild** | §3 |

## 3. Arabic, measured (A5)

A temporary development-only log (removed before commit) read the phone's real values:

- at the relaunch: `{lang: ar, actualRtl: false, sessionId: 40051898…, requested: {lang: ar, session: E08CF7C4…}, isExpoGo: true}` —
  Expo Go **does** start a new process with a new `Constants.sessionId`, the request had been persisted, and the layout
  was **still left-to-right**: **Expo Go does not apply a project's direction**;
- then, in the same process, French then Arabic were tapped: French matched the layout and deleted the request; Arabic
  wrote a new one for this process — and the notice went back to *Restart needed*. Every re-selection re-armed it.

So in Expo Go the first *Restart needed* promised what Expo Go cannot do, and the loop never ended. **D150**: inside Expo
Go a mismatch says at once *Expo Go can't switch the layout* (no restart claimed or promised); our own builds keep the
restart flow of D147. Verified on the phone: after FR → AR the notice stays *Expo Go can't switch the layout*.

**Not verified, and not verifiable here:** the Arabic **layout direction** in a native build. It needs `npx expo run:ios`
on a Mac or an EAS build installed on the phone (`docs/24` §57 C). A JavaScript reload is not a native rebuild, and
Expo Go cannot prove a native configuration change.

## 4. The payer number (Phase B, D151)

**Audit first.** `payments` had `reference` (later payments only), `note`, the receiving account and its frozen
label/provider — nothing for the sender's number. `POST /sales`'s replay compared only `method:amount` per payment;
later payments hash their payload; money corrections never rewrite a payment row; `GET /sales/:id` returns payment
fields one by one under `sale.view`; receipts, reports, CSVs, notifications and WhatsApp map fields explicitly; request
bodies are never logged.

**Built** (backend `df1f2b4`, mobile `0b525b3`): migration `0087` (nullable `payer_number` VARCHAR(40) +
`ck_payments_cash_no_payer`); one normalisation rule on each side; the field in the payment sheet (one method, split
parts by key), Record payment and *Correct payer number*; per-part replay binding; fingerprint binding only when present;
the correction route; read under `sale.view`; cleared by account deletion; audited. See D151 for the rules.

**Tests:** backend `payer-number.spec.ts` (32) + the deletion spec (1); mobile pure (`payer-number`, `receipt-privacy`,
`money` pins moved deliberately) and rendered (`payment-sheet` 11, `sale-detail-payer` 2).

**Real-HTTP lifecycle** on a disposable copy (`prisma_qa_payer`, the PC's database at `0086` + `0087`), the built API,
Boutique 9's Owner — **17 of 17**:

| # | Check | Result |
|---|---|---|
| 1 | a cash sale | payer number `NULL` |
| 2 | a Bankily sale with `' +222 36 12-34-56 '` | `+22236123456` stored and returned |
| 3 | a four-way split (Bankily `36 11 11 11`, Masrvi `+222-36-22-22-22`, Sedad none, Cash) | `36111111`, `+22236222222`, `NULL`, `NULL` on the right parts |
| 3b/3c | a fifth place; a number on cash | 400 `too_many_payment_methods`; 400 `payer_number_cash`; nothing written |
| 4 | details / list | details return it; the sale list does not |
| 5 | same key, same body (parts reordered, numbers respaced) | the same sale, no new row |
| 6 | same key, one payer number changed | 409 `idempotency_conflict`, nothing written |
| 6b | a later Bankily payment with a number; its retry; a changed number | stored `36333333`; replay 201; 409 `idempotency_key_reused` |
| 7 | correction; the same value again; on cash | 200 → `36111119`, audit +1; 200, audit +0; 400 `payer_number_cash` |
| 7b | another boutique reads / corrects | 404 / 404 |
| 7c | the correction's effect on money | the day's overview and the sale's paid/owed/status identical (only `trackedMoney.asOf`, a timestamp, ever differs) |
| 8 | audit | the sale's entry holds each part's number; the correction `"36111111" → "36111119"`, reason `payer_number_corrected` |
| 8b | totals | cash rose by exactly the cash taken (46 000 + 14 200 + 1 000), Bankily by exactly 12 500 + 1 000 + 500 |
| — | outputs | no number in notifications, six report CSVs, or the 207 KB API log; no other company's payment carries one |

The audit hash chain verified intact for all 11 companies afterwards; the disposable database was dropped and its
grants revoked.

**On the owner's iPhone** (Expo Go, `0b525b3`, the API on the disposable copy) — `docs/24` §58: the build line; a Sedad
sale with `22325165` (invoice `00002`); a split Sedad `32648261` + Bankily `22431529` (`00003`); *Correct payer number*
`32648261 → 32648262` (audited); a cash sale with no field and `NULL` (`00005`); the keyboard leaving the field
reachable; typed values kept through Airplane mode with exactly one sale; the numbers on the saved sale. Seen once: a
cashier typed the **amount** `10000` into the payer field of an account payment (`00004`) — the app recorded exactly
what was typed; noted as a UX observation, not a defect (no format is imposed, by decision).

## 5. Discoveries on this PC

- **Line endings and layout.** Git for Windows checks out CRLF (`core.autocrlf=true`) and the PC keeps the repositories
  side by side; three mobile suites and three backend suites assumed LF or the nested layout. Fixed in the tests only
  (`fa5c6a5`, `be024dd`); the repositories store LF (verified with `git cat-file`).
- **Argon2 under load.** Two hashing suites can exceed jest's 5 s default when the full suite runs beside Metro and the
  API; they pass alone and with `--testTimeout=30000`. No change made.
- **Web export blocked.** Windows Smart App Control (Application Control policy) refuses the unsigned `lightningcss`
  1.33.0 native module that `@expo/metro-config`'s web CSS pipeline loads (`ERR_DLOPEN_FAILED`); the 1.27.0 copy used for
  native bundles loads. The web export and its route audit therefore cannot run on this PC; the security setting was
  not changed. They last passed for `2347523` in the cloud container (`docs/70` §6).
- **Expo Doctor** 20/21 on the PC (both network checks run here); the failure is eight Expo packages a few patch
  releases behind — owed, with `expo-camera`'s native patch re-cut.
- **Metro's debugger proxy** accepts a local-origin client but Expo Go's Fusebox target does not answer a bare CDP client;
  runtime values were read with a temporary log instead.

## 6. `0087` on live — the runbook, for the owner's approval (NOT applied)

Live is at `0083`. **Order is fixed:** `0084`, `0085` (`docs/67` §7), `0086` with its transition (`docs/69` §2), then
`0087`. `0087` is additive (a nullable column and a CHECK every existing row satisfies); the old API ignores the column,
but the **new API reads it**, so the migration must precede the new API, and the **new app must not reach phones
before the new API** — the old API refuses an unknown `payerNumber` with 400 on any non-cash sale that carries one.

1. **Backup** per `docs/22` §2 (`--single-transaction --routines --triggers --events --no-tablespaces --hex-blob`);
   verify size, the `-- Dump completed` trailer, the table count and the trigger count; record the dump in the handoff.
2. **Apply** with the migrator identity: `npx prisma migrate deploy` (takes every pending migration, in order).
3. **Verify the schema:** `SHOW COLUMNS FROM payments LIKE 'payer_number'` → `varchar(40)`, NULL;
   `information_schema.check_constraints` has `ck_payments_cash_no_payer`;
   `SELECT COUNT(*) FROM payments WHERE payer_number IS NOT NULL` → 0; `prisma migrate status` up to date.
4. **Deploy the API** at `be024dd` or later. Smoke: a cash sale returns `payerNumber: null`; a non-cash sale with a
   number returns it normalised from `GET /sales/:id`; `POST /sales/:id/payments/:paymentId/payer-number` answers the
   Owner; `npx ts-node scripts/verify-audit-chain.ts` reports no broken chain.
5. **Then the app** at `0b525b3` or later.
6. **Rollback:** stop the API; restore the dump (`docs/22` §3) — or, for a database you would rather not restore,
   `ALTER TABLE payments DROP CHECK ck_payments_cash_no_payer, DROP COLUMN payer_number;` — and redeploy the previous
   API and app. A Git rollback does not roll back the database.

**Rehearsal:** the disposable copy of §4 — `0087` applied cleanly; the CHECK refused a cash row with a number (`ERROR
3819`) and accepted the control; the lifecycle 17/17; the chain intact; dropped.

## 7. The PC's local development database (not live, not shared)

WAMP's MySQL 8.4 data directory served by a hand-started `mysqld` on `127.0.0.1:3308`, database `phonestore` (the demo
company and ten local test boutiques). This session: backup `phonestore-local-20261007-015025.sql` → `0086` → the seat
transition (dry run and apply: 0 granted, 0 converted); then, **with the owner's approval**, backup
`phonestore-local-20261007-054448.sql` → `0087`. Backups live in `~/erp-backups/` on the PC, outside every repository.

## 8. Commits

- **erp-mobile:** `728a0d8` (the lockfile), `c756030` (D150), `fa5c6a5` (Windows test robustness), `0b525b3` (D151).
- **erp-backend:** `df1f2b4` (D151, `0087`), `be024dd` (Windows test robustness).
- **erp-docs:** `fcf54ca` (takeover), `f087781` (Phase A checkpoint), and the commit carrying this page.
