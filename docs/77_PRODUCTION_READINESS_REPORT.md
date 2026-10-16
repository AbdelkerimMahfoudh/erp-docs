# Production readiness — Dukan ERP for TestFlight (TSX-MR), 2026-10-16

**What this phase was:** an audit and defect-fixing phase. **What it was not:** authority to deploy, publish, upload a
build, change DNS, buy a service, create production credentials, contact a customer, or touch the live database or
real data. **None of those happened.** Every database used was disposable, on a throwaway MySQL in the session's
scratch directory; every API ran on `127.0.0.1`. No EAS build was made and nothing was sent to App Store Connect.

Companion documents: `docs/78` environment and secrets inventory · `docs/79` staging, live deployment and rollback ·
`docs/80` migration, backup and restore rehearsal · `docs/81` App Store Connect checklist and the physical-iPhone
script · `docs/82` per-file review manifest (CSV) · `docs/83` defect register · `docs/84` screenshot matrix ·
`docs/48` §7.3 dependency triage.

## 1. The code this report is about

| Repository | Branch | Head at takeover | Final head | Pushed |
| --- | --- | --- | --- | --- |
| erp-backend | `reports-export` | `6a4cfc0` | `06a0db7` | yes |
| erp-mobile | `reports-export` | `a8b48c4` | `b23badb` | yes |
| erp-control-web | `tsx-public-site` | `8efa902` | `0eedfaa` | yes — `main` (`0417bfe`) untouched |
| erp-docs | `master` | `fd86e24` | the commit carrying this file | yes |

No schema migration was written or applied this phase. `0097` is still applied to no shared database (D176, O-B12).

## 2. How it was checked

| Area | What was done | Result |
| --- | --- | --- |
| Every tracked file | 13 reviewers read every file of the four repositories (1 565 at the start), each recording a disposition; two further reviewers read every file the fixes changed. Reconciled against `git ls-files` (`docs/82`) | 1 592 tracked files at the end (backend 824, mobile 574, website 108, docs 86): every one has a row in `docs/82` with its reviewer and disposition; 243 findings — 1 blocker, 20 high, 61 medium, 116 low, 45 notes |
| Blocker / high findings | each one verified adversarially by an independent verifier — refute first, then reproduce over real HTTP on a private copy of the fixture, or in a rendered test — before any fix | 1 blocker + 20 high, every one verified: **17 fixed** (1 blocker, 16 high — 5 of them with an owner question left: BE4-01, BE4-03, BE6-06, BE6-08, MO4-01), **4 owner decisions** (BE4-02 refund on a credit sale, BE6-05 partial transfer receipt, MO1-07 deletion channel, MO1-01 the app icon); 19 mediums verified and fixed or decided; the other 42 mediums and 113 lows read from code only (`docs/83`) |
| Tenant isolation | real HTTP, Owner of company A against company B's real identifiers on every one of 284 routes (`iso/isolation.cjs`), B enriched through the API with transfers, returns, consignments, loans, goals, corrections, imports, discount approvals, discrepancies, receipts, money-agent providers and exchanges | 14 778 requests, **0 leaks, 0 × 5xx**, B and 8 bystanders byte-identical after; 27 of 32 GET-by-id routes proven against a live B object (the other 5 are branch- or date-scoped and were proven on the right branch). **Re-run on the final build** (r3, backend `b6521a9`, which differs from `06a0db7` only by the reverted read rule, unused by these active companies): the same 14 778 requests, 0 leaks, 0 × 5xx, the same 52 rows proven by B's control; the one row class that changed is `POST /transfers/:id/receive/confirm`, now 400 on its empty body (the `ca94087` validation) where it was 404. The 115 `POST /notifications/:id/read` answers of `200 {updated: 0}` (no effect, the same answer as a random id) are flagged by the harness in both runs. B's `discount_approvals` changed in r3 by B's own control read expiring a stale approval, not by A |
| Branch scope inside a company | a Store Manager of one of two branches, real HTTP | 6 defects found and fixed (§4) |
| Money idempotency | sale, later payment, expense: replay, 10-way concurrency, same key with another payload, one unit raced by two keys; consignment and loan confirm / reverse / write-off 10-way | all pass after the fixes (§4); before them: one payment confirmed 10 ×, a loan written off 8 ×. Re-run on the final build: **18 / 18** |
| Free trial | the trial harness on its own disposable copy, 168-hour boundary by clock offset, roles, isolation, concurrency, expiry | 189 / 189 |
| Strict MySQL | the API on MySQL 8's strict `sql_mode`, every GET route with own ids; every id route with a malformed id | 0 × 5xx, no SQL error, after the malformed-id fix (9 × 500 before) |
| Query-string parser upgrade | old and new `qs` side by side, 936 requests incl. hostile strings | identical but for a timestamp |
| Migrations, backup, restore | from empty (strict and loose), a copy shaped like live at `0083`, the developer-schema shape at `0091`, and an interrupted `0095`; encrypted backups and two restore drills (`docs/80`) | all paths identical to a fresh build; data fingerprints unchanged; restores verified table by table |
| CI | made honest (it had not reached tsc since 2026-09-30) and green in all three code repositories, with a real-MySQL database job for the backend | green on every final head |
| Website | Vitest, build, link and bundle audits, 114 Playwright browser checks in CI | all pass |
| App bundle | fresh production web and iOS exports; bundle audit (no trial action, link, QR, web view, price or payment), shipped-dependency audit, release-config check, the EAS build hook run with EAS's variables | pass |
| Screens | 561 checked entries, 380 images: app (web export) and website, EN/FR/AR, 393 pt and 320 pt × 1.3 text, three roles, three activities, nine access states (`docs/84`) | 4 findings: R2 fixed on the website (its server half is PQ17, awaiting the owner); R1 (medium, a 320 × 1.3 header), R3, R4 (low) open. Browser only — NOT DEVICE VERIFIED |

## 3. Gates at the final heads

| Repository | Head | Local gates | CI on that head |
| --- | --- | --- | --- |
| backend | `06a0db7` | `prisma validate` · `tsc` 0 errors · Jest **249 suites passed, 1 skipped; 4 508 tests passed, 24 skipped, 0 failed** | run 38898384642 **green**: secret scan (full history), dependency audit, type-check/schema/tests, migrations + catalogue + identities + real-MySQL spec |
| mobile | `b23badb` | `tsc` 0 · `expo lint` **0 errors, 29 warnings** (limit 40) · 114 pure test files pass · Jest **28 suites / 279 tests, 0 failed** | run 38896028221 **green**: type-check, lint, tests, release config; secret scan; dependency audit |
| website | `0eedfaa` | typecheck · Vitest **18 files / 296 tests** · `build:preview` | run 38897130217 **green**: unit tests, the production-build refusal, preview build, link and bundle audits, dependency audit, secret scan, the Playwright browser checks (every public page, three languages, 375/320 px, desktop, 200 % text, axe, keyboard, headers) |

The 24 skipped backend tests are the env-gated real-MySQL specs (run in CI's database job and on disposable copies) and
one suite skipped on CI by name (`staging-scan-sheet.spec`, it reads this private repository). Commit `a1fedda`'s
message says "280" mobile tests; the true count was 279 (recorded in `SESSION_LOG.md`, not amended).

## 4. What was fixed

Every fix was reproduced first, has a regression test that fails on the old code (or, for two new modules, does not
compile against it), and is in `docs/83` with its commit. The behaviour a user can notice is listed in `docs/21`
("Implemented as fixes of existing rules", 2026-10-16). In short:

- **Blocker** — a multi-phone consignment raised its agreed total once per phone (BE6-01, `bbe7c4f`).
- **Money under concurrency** — consignment and loan confirm / reverse / write-off applied up to 10 × (`bbe7c4f`,
  `2f01f7a`); racing identical sales and expenses answered 409 (`18c00ce`, `98fc73a`); a payment recorded twice by
  the console (`b6521a9`); a discount took a line below cost with no approval (`bd43cf1`).
- **Branch scope** — a one-branch manager read or changed other branches' stock, units, notifications, comparison and
  anomalies (`f49e371`, `d92012b`, `75f1ca8`, `d7359fb`, `65be480`).
- **Authentication** — public routes that sent codes to anyone (`f6dd5b5`); code attempts, MFA lockout and TOTP
  replay raced past their limits — ten parallel guesses set an invited employee's password (`42c8b4f`); refresh
  rotation without compare-and-swap (`0784e83`); the app signed people out on any launch error (`0e384a3`, `a1fedda`).
- **Input and availability** — malformed ids answered 500 (`cf2cb23`); small workbooks could exhaust memory
  (`3df8080`, `ce30374`); qs and other shipped-dependency advisories (`9400480`, `1cd3cfb`); uploads bounded beyond
  size (`f6d0b44`); production refuses to start with Swagger on (`f350031`).
- **Release integrity** — CI had not reached tsc since 2026-09-30 in the backend and was red in mobile and website
  (`506568f`, `0eeb309`, `f94fc61`, `114fe00`, `cfdb756`, website `35ca6d1`); `start:prod` named a file the build
  does not write (`d2ad456`); the design gallery shipped in release (`1167f52`); a release build could be made without
  its https API origin (`7c127b3`).
- **App flows** — the scanner refused ordinary barcodes (`fa8e09b`); approval and partner-payment keys reused or lost
  (`0cb381c`, `b9cb4ff`, `e00a480`); a queued report left "sending" (`79851eb`); a 502/504 after a sale shown as a
  failure (`b5f8b81`).

**A correction made during the phase.** Backend `2251c06` let a closed business read its own request list and
request prices. That is `docs/21` PQ17's alternative (a), which awaits the owner; it was reverted in `06a0db7` the same
hour. The website fix it accompanied (`0eedfaa`) decides nothing and stays.

The full register — every finding, with its status, commit and test — is `docs/83`.

## 5. What is not fixed, and why

- **Owner decisions** (§6): the code is right, or the rule is undecided; deciding would be inventing a business rule.
- **Medium and low findings not verified in this phase** (`docs/83`, status "open"): reviewers' reports read from code
  only, not reproduced and not fixed. None is a blocker or high. They are the next phase's work list.
- **Needs a schema change** (not allowed this phase): none of the fixes needed one.

## 6. Decisions only the owner can make

Grouped by what they block. "Blocks" names the first gate that cannot pass without the decision (§7).

### A. Apple, the build and the store (block internal TestFlight unless marked)

| # | Decision | Why it is the owner's | Blocks |
| --- | --- | --- | --- |
| O-A0 | Apple Developer Program membership for **TSX-MR** (organisation, D-U-N-S), and who holds the Apple and EAS accounts | purchase and legal identity | internal TestFlight |
| O-A4 | Link the EAS project `dukan-erp` (the app still names the old project `834d8b25…`) and let EAS create the iOS credentials | production credentials | internal TestFlight |
| O-A6 | The https **staging** API host and domain (`docs/45` D1–D5) and who holds its secrets; `EXPO_PUBLIC_API_ORIGIN` set as an EAS variable of the `production` profile — the build now refuses to start without it | purchase, DNS, credentials | internal TestFlight |
| O-A1 | The logo → the 1024 px icon and the splash (the app has Expo's placeholders) | brand | external TestFlight |
| O-A3 | Export compliance: the app uses only the OS's HTTPS and Keychain → `usesNonExemptEncryption: false` | a legal declaration | every upload asks until set |
| O-A2 | iPhone only, or iPad too (`supportsTablet: true` today; iPad never reviewed) | product scope | the App Store (iPad screenshots and review) |
| O-A5 | In-app access to the privacy policy (guideline 5.1.1(i)) against the rule "no link to any website in the app" | product rule vs Apple | the App Store |
| O-A7 | Account deletion needs a delivery channel (D110): WhatsApp is postponed and no email provider is chosen, so deletion cannot complete (5.1.1(v)) | provider purchase | the App Store; external TestFlight review risk |
| O-A8 | The privacy texts, terms and the App Privacy answers — legal review | legal | external TestFlight (test information) and the App Store |

### B. Business rules the review found undecided (none blocks internal TestFlight)

| # | Decision | Today |
| --- | --- | --- |
| O-B1 | A return on a credit or part-paid sale (BE4-02): refund at most what was paid and write the rest off, or refuse the return while a balance is open | refunds the full line; the sale and the customer stay owed; recorded as a report warning (`docs/51` §4) |
| O-B2 | A transfer received with phones missing (BE6-05, `docs/25` §8 Q6): allow partial receipt (and how missing phones are found or written off), or refuse | the transfer finishes; missing phones stay "in transit" and drop out of stock value; the app always sends every phone |
| O-B3 | Partial consignment sales (some phones sold, some returned) | refused now (400) — all or none |
| O-B4 | A discount below the set price but above cost (docs/04 rule 35 vs docs/21 A2) | allowed; below cost is now refused |
| O-B5 | Multi-phone consignments already reported sold carry an inflated receivable: a compensating entry, case by case | untouched (append-only ledger) |
| O-B6 | The branch comparison for a one-branch manager: drop the report for managers, or a one-branch file with its own label | shows only their branch; the CSV still says "All branches" |
| O-B7 | Whether an employee sees their own branch's sale totals and shortages; per-person read state of a notification | branch-scoped now; one read marks it read for the branch |
| O-B8 | Anomaly dismissals per branch (keys are branch-blind) | a dismissal at one branch hides it at all |
| O-B9 | Receive / Quick receive accepting an accessory or serial barcode by camera | they accept IMEIs only |
| O-B10 | Correcting another branch's phone: today an Owner must switch to that branch first | by design of the fix (BE5-03) |
| O-B11 | The trial defaults PQ1–PQ17 and the residuals R4-04, R5-4 (`docs/76` §16) | unchanged from the trial phase |
| O-B12 | Schema `0097` on any shared database (D176) | not applied anywhere shared |
| O-B13 | Inter-store notifications ("A store proposed a debt", "A store wants to send you stock") are written under the proposing company: it is told to accept its own offer and the other store is never told (PR-F18). A fix needs a deliberate cross-tenant notification write | unchanged; no data crosses tenants |
| O-B14 | PQ17 in every closed state: a suspended, pending, refused or not-started business may ask for a seat, store or activity change but cannot list its requests or read their prices (SCR-R2) | the reads stay refused; the website shows the refusal once (`0eedfaa`) |
| O-B15 | A closed business's app tries `POST /devices/adopt` on every launch and is refused (adopting grants authority; SCR-R3) | unchanged; nothing shown to the person |
| O-B16 | Recording a subscription payment: a console idempotency key, refusing a reused reference for another amount, refusing a future payment date (BE1-05 follow-ups) | the same payment recorded twice is now recorded once; nothing else changed |

### C. Operations, security and the outside world

| # | Decision | Blocks |
| --- | --- | --- |
| O-C1 | Backup retention and where encrypted backups live; who holds the passphrase | the live deployment |
| O-C2 | Incident response: who is called, who can revoke sessions and rotate keys, where the runbook lives | the App Store (a real customer's data) |
| O-C3 | Custody of `PLATFORM_MFA_KEY` and the Super Admins' recovery codes per environment | staging |
| O-C4 | **An external penetration test — not done.** Commission one before real customers | the App Store |
| O-C5 | The repositories `erp-backend` and `erp-mobile` are **public** on GitHub (source, migrations, deploy scripts, the revoked G2A-CP4.5 tokens in history). No live secret was found in either full history | owner's call; recommended private before launch |
| O-C6 | The Nest 10 → 11.1.18+/12 upgrade for the remaining moderate advisories (`docs/48` §7.3) | next dependency window |
| O-C7 | The open draft PRs: backend #1 `qa-boutique-seed` (dev tooling), mobile #1 `stock-finds-products` (a navigation change); backend #2 and mobile #2 `audit-fixes` are superseded and can be closed | none |
| O-C8 | The live deployment window and approval (`docs/79` §B), and the website's merge of `tsx-public-site` into `main` | the live deployment |

## 7. GO / NO-GO

Three separate answers. "Code" means: no open blocker or high defect in the code; "the rest" is what only the owner
or a device can supply.

| Gate | Answer | Code | What stands between it and GO |
| --- | --- | --- | --- |
| **Internal TestFlight** (the team's own testers, no Apple review) | **NO-GO today** | ready | O-A0 Apple Developer membership for TSX-MR · O-A4 link the EAS project `dukan-erp` and let EAS create the credentials · O-A6 an https staging API, deployed per `docs/79` §A, with `EXPO_PUBLIC_API_ORIGIN` as an EAS variable (the build now refuses without it) · then `docs/81` §3 T1–T2 on a physical iPhone. O-A3 (export compliance) is asked at each upload until set. |
| **External TestFlight** (outside testers, Beta App Review) | **NO-GO** | ready, with the open mediums of `docs/83` accepted or fixed | all of the above, plus O-A1 the icon and splash (Expo's placeholders today) · O-A8 legal review of the privacy texts and terms · O-A7 a delivery channel so account deletion can complete · the whole `docs/81` §3 script on a device, every row of it today NOT DEVICE VERIFIED |
| **App Store** | **NO-GO** | not yet: 42 medium findings unverified, and the business rules of §6 B undecided (BE4-02 is a high: refunds on a credit sale) | all of the above, plus O-C4 **an external penetration test — not done** · O-A2 iPad or iPhone only · O-A5 the in-app privacy-policy access · O-C2 incident response · O-C1 backup retention and custody · O-C5 the public repositories · the live deployment window O-C8 |

No deployment, upload, submission, DNS change, purchase, provider activation or live-database operation was made, and
none is authorised by this report.

## 8. Verified where, and not verified

- **Real HTTP against a disposable API:** isolation, branch scope, money races, the trial, malformed ids, strict SQL,
  the query parser, the website's own Playwright journeys (with its mocked API), the screenshot matrix.
- **Rendered tests (jsdom/React Native test renderer), not a device:** the session restore, the scanner sheet, the
  approval sheet, the partner-payment screens, the release-origin screen.
- **NOT DEVICE VERIFIED — none of this was seen on a phone:** camera scanning, haptics, native sharing, the native PDF
  preview, safe areas and the home indicator, cold-launch right-to-left, Keychain persistence, push of any kind,
  behaviour on a real cellular network, the EAS build itself, the privacy-manifest aggregation in an archive. The
  physical-iPhone script (`docs/81` §3) lists each check as NOT DEVICE VERIFIED.
- **Not done at all:** an external penetration test (not done, not claimed), a legal review of the terms and privacy
  texts, a live staging host.
