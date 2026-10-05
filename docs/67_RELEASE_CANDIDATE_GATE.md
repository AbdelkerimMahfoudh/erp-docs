# 67 — The release-candidate gate (2026-10-03)

> The record of the release-candidate stabilization phase (the user's brief of 2026-10-02): every open finding
> classified, the defects fixed with their evidence, the decisions waiting for the owner, the App Review assessment,
> the rehearsal of migrations 0084 → 0085 on a disposable restored copy, the production runbook, and the GO / NO-GO.
> **Nothing here was run on live, published, submitted to TestFlight or sent to anybody.** The live database is on the
> owner's PC and unreachable from the cloud session that wrote this.

**Release candidate:** backend `reports-export` **`1434aa7`**, mobile `reports-export` **`3023bd3`**.
**Evidence words** used below, never stretched: **API VERIFIED** — over real HTTP against a disposable database;
**WEB VERIFIED** — in a browser on the app's web export; **DEVICE VERIFIED** — on a real iPhone (none in this phase);
**NOT VERIFIED**. A web screenshot proves nothing about the native app.

---

## 1. Takeover: what was found before anything changed

| # | Discrepancy | Now |
|---|---|---|
| 1 | The 30 Sep audit's verified fixes (backend D1, D2, D3, D5; mobile M1) sat only in draft PRs #2 — not in the release branch — while `docs/48` controls 8 and 9.1 cited D5 as evidence | cherry-picked with `-x`, re-verified (§3) |
| 2 | **No native build could install:** `postinstall` failed because `expo-camera` is 57.0.5 and the patch was cut for 57.0.4 (`npm ci` exit 1) | fixed (§3) |
| 3 | `master` (backend, mobile) is stale; the release candidate lives on `reports-export` | unchanged — recorded |
| 4 | D4: `companies.is_discoverable` is never set, so Partners cannot connect two shops — not even by store code | decision D124 (§4) |
| 5 | Mobile draft PR #1 (*Catalog leaves More*, the user's 30 Sep brief) is not in the release branch | decision D126 (§4) |
| 6 | CLAUDE-A's scroll-investigation trace is uncommitted on the owner's PC (recorded in the previous handoff) | the owner's call: keep or discard |

## 2. The release gate — every open finding, prioritised

Classes: **BLOCKER** (named release), **BEFORE WIDER TESTING**, **DECISION** (the owner's), **DEFER** (safe to defer).
*TF* = TestFlight with internal testers (no Apple review); *AS* = public App Store submission.

| ID | Finding | Class | Failure scenario | Recommended resolution |
|---|---|---|---|---|
| RC-01 | **Account deletion cannot complete in the production configuration**: WhatsApp sending is postponed and email has no provider, so no deletion code can reach anyone | BLOCKER AS (5.1.1(v)); external TF | A reviewer, or a shop owner, opens *Delete account* and is told codes cannot be sent — the account cannot be deleted in the app | D116 (§4.1): password-confirmed deletion with a 7-day safety window, built and proven before submission. The dishonest half is fixed (`56bddbe`): refused up front, nothing created |
| RC-02 | **In-app registration cannot finish in production**: the contact code has no channel; the unfinished owner can still sign in to *Waiting for activation* | BLOCKER AS (2.1) | A reviewer registering a shop is stuck at *Check your contact* | D117: hide self-registration on iOS; businesses created from the platform administration (*Create a business* + Owner invitation, built) |
| RC-03 | **The subscription model against Apple 3.1.1** | BLOCKER AS | Review reads "activated by the administrator after paying outside the app" as unlocking functionality without in-app purchase | D118 (§5.2) |
| RC-04 | **No HTTPS API a phone can reach**: a release build needs `EXPO_PUBLIC_API_ORIGIN=https://…`; live is an HTTP API on a PC on the shop's network | BLOCKER TF and AS | A signed build has no server to talk to: the release check (`scripts/verify-release-config.js`, control 19) refuses an `http://` origin, and the PC's API is not reachable from outside the shop's network | Hosting (`docs/48` §12 #3): a staging host with synthetic data for internal TestFlight; production only after the gate passes |
| RC-05 | **Live is at 0083**; the release candidate needs 0084 and 0085 | BLOCKER for running the candidate on live | The new API on an unmigrated database fails every audited write — and stores an expense without its audit row while telling the phone it failed (rehearsed, §6) | The runbook (§7), with the owner's approval |
| RC-06 | **Nothing verified on an iPhone** | BLOCKER AS | Native preview/share, the camera, safe areas, large system text and Arabic as the native engine lays it out are unknown | The script in `docs/24` §54 on a TestFlight or ad-hoc build |
| RC-07 | **The security gate is NOT PASS** (`docs/48` §12–§13): 6 high / 3 high production dependencies untriaged, no per-module adversarial tenant suite, no bot protection, no incident-response procedure or legal retention period, no independent assessment, CI never run (and as configured it fails on `npm audit`) | BLOCKER AS and for real customer data on an internet-facing host | An internet-exposed API with known-vulnerable dependencies and no brute-force friction beyond rate limits | Triage and the tenant suite are code work for a next phase; the rest are the owner's (§4) |
| RC-08 | **No privacy policy**: no hosted URL, no link in the app; App Privacy answers not prepared | BLOCKER AS (5.1.1(i)) | Submission refused at the metadata step or in review | Publish a policy (the draft in `docs/64` §6, after legal review), link it from *Your account* and the sign-in screen, fill App Privacy |
| RC-09 | **App Store prerequisites**: a demo account with data and a live back end during review (2.1); the export-compliance answer (`ITSAppUsesNonExemptEncryption` absent — App Store Connect asks on every build); the privacy manifest confirmed in the archive; `supportsTablet: true` (iPad screenshots and iPad review); the default microphone purpose string although the app never records sound | BLOCKER AS (export compliance also prompts on every TF build) | A build stuck in *Missing compliance*; a review on an iPad layout nobody designed | D127 (§4) |
| RC-10 | **An expired shop's Home and Money offer *Sell*, *Receive*, *Add expense*, *Open the boutique*** — the server refuses each at the end (`docs/66` §8) | BEFORE WIDER TESTING + DECISION | A shop whose period ended sells, and is refused only after building the sale | D119 (§4.4) |
| RC-11 | **Notifications in English for French and Arabic readers** (sales, closings, refunds, returns, debts, consignments, purchases) | BEFORE WIDER TESTING + DECISION | An Arabic reader gets *Sale 00014 — 22000* | D121 (§4.6) |
| RC-12 | **Full IMEIs beyond rule 19d** — before payment (the Sell cart line, the price-approval sheet), in the Stock list, the Returns list; `GET /inventory` and `GET /units/:identifier` gated by login only; request logs and the error handler keep full IMEIs | BEFORE WIDER TESTING + DECISION | A colleague, or anyone reading a server log, collects customers' handset numbers | D120 (§4.5) |
| RC-13 | **Plurals**: *1 phone(s)*, *1 cannot, and are listed below*, *Les 1 seront ajoutés*, Arabic plural classes (*10 دقيقة*) | BEFORE WIDER TESTING (FR/AR) | Arabic and French copy reads as machine text | D125: one plural helper and a copy pass |
| RC-14 | **A consignment request and a debt proposal are notified inside the proposing company**, so the other store never sees them | BEFORE PARTNERS SHIPS | Store B is never told Store A asked | With D124 and D121 |
| RC-15 | **Company-wide notifications are not filtered by branch** — every user sees every branch's sale totals | BEFORE WIDER TESTING (multi-branch) + DECISION | An Annexe employee reads the main store's takings | With D121: target by branch |
| RC-16 | Uploads: stock imports still typed by file name; expense receipt photos are stored and served (`docs/48` control 16 overstated) | BEFORE WIDER TESTING (gate) | A renamed file reaches the spreadsheet parser | Type imports by content as receipts already are; correct the control |
| RC-17 | Refresh-token rotation has no automated test and no compare-and-swap | BEFORE WIDER TESTING (gate) | Two refreshes racing both succeed | A spec and a conditional update |
| RC-18 | Two pending registrations with the same unverified email; an unverified registrant signs in to the pending screen | DECISION (D128) | Spam registrations land in the administrator's list | Require a verified contact before approval (or before sign-in) |
| RC-19 | D4: Partners unreachable | DECISION (D124) | — | §4 |
| RC-20 | A Manager's personal targets | DECISION (D123) | — | §4 |
| RC-21 | A past month's PDF | DECISION (D115) | — | §4 |
| RC-22 | *Phone sales* in an all-electronics product | DECISION (D122) | — | §4 |
| RC-23 | Mobile PR #1 (*Catalog leaves More*) unmerged | DECISION (D126) | — | merge after re-verification, or close |
| RC-24 | 60 writes at once (20 sales and 10 expenses in each of two shops): 5 of the 40 sales lost to an InnoDB deadlock on the invoice counter (`branch_counters`) | DEFER | Far beyond a shop's load; the refused sale carries its key, so a retry is safe | Pre-create the counter row and increment with `UPDATE … LAST_INSERT_ID()`, or retry P2034 once |
| RC-25 | 64 audited writes record their audit row in a second statement after the change commits | DEFER (runbook guard) | If the audit insert fails, the change stays and the phone sees an error (seen when the new API ran on an unmigrated database) | The runbook never starts the new API early; later, `recordTx` for money writes |
| RC-26 | A database outage during authentication answers 401 (seen only in 60-write bursts on the old pool) | DEFER (monitor) | A phone could be signed out during an outage | Map engine errors to 503 in the auth path |
| RC-27 | Two list subtitles cut at 393 pt; four-way choices at 320 pt × 1.3×; *Refreshed 0 seconds ago*; *Storage* on an accessory; a lower-case *no returns*; *Wednesday 09:00* for yesterday (`formatSmartDateTime` contradicts its own comment); two web-only items; the refund receipt's comment about masking; the seven subjective notes (`docs/66` §8) | DEFER | Cosmetic | The plural/copy pass; device checks in §54 |

**Closed in this phase (§3):** D1, D2, D3, D5, M1, the native install, the connection-pool deadlock, the dishonest
deletion and number-verification answers, the identity script, the restore drill and the identity verifier, the
Daily closing under MySQL's default `sql_mode`, the purchase cost in a notification.

## 3. Fixed in this phase — each with a focused test and its evidence

| Commit | What was wrong | Evidence |
|---|---|---|
| backend `4370240` | **Concurrent sales exhausted the connection pool.** `BusinessDayService.assign()` ran inside the sale, purchase-payment and money-anchor transactions but read the timezone through the global client — a second pooled connection while holding the first. With a 5-connection pool (Prisma's default on a 2-CPU host), 3 sales at once in each of two shops lost 5 or 6 of the 6 sales in every trial, and 16 writes at once lost 12 to 16 of 16 — on the old and the new schema alike; Prisma's engine panicked | 5 tests (fail before). After: 4, 8 and 16 at once on 5 connections, 3 of 3 trials each, every write accepted; 30 at once on 9, 30 of 30. Against MySQL: a Tokyo company's transaction assigns 2026-10-03, a Nouakchott one 2026-10-02 — the timezone is read, not defaulted |
| backend `56bddbe` | **Deletion and number verification answered as if codes could be sent.** "Can a code be sent?" asked the OTP pepper only. With WhatsApp disabled: a deletion request + challenge were created, the API answered 200, the app showed a code field no code would fill; verifying a number blamed *that number* | 4 tests (3 fail before). Production mode, WhatsApp disabled, real HTTP: **7 of 7** — email-only Owner → *codes cannot be sent, nothing changed*; verified-number Owner → the same; adding a number → the same; a wrong password still first; nothing created |
| backend `867133e` | **`deploy/mysql-identities.sql` could not run** (`IDENTIFIED BY @var` is a syntax error) and left `phonestore_migrator` with the password `placeholder`; the documented command put four passwords on a command line. **`deploy/restore-drill.sh` reported PASSED** on a copy where a product named ``DEFINER=`x`@`y` cable`` had lost its name, on a copy with a fixed collation, with trigger comments dropped, and with the append-only probe "passing" for want of a grant | 11 tests (10 fail on the old scripts). The guard refused a missing password (0 accounts); 4 identities; idempotent re-run; the fixed drill: 94 tables by CHECKSUM, trigger bodies identical, product name intact, probe honestly SKIPPED; the old drill's corrupted table shown to fail the new content check |
| backend `c4ad802` `28c1bd6` `ede48c0` `0e5f189` | The 30 Sep audit's D1 (recognition learning), D2 (dead stock), D3 (malformed ids → 500), D5 (same-key sale race → a phantom 409) | Their own tests; D5 over HTTP **6 of 6** rounds one sale with both answers agreeing (before: 6 of 6 phantom 409s); D3 **6 of 6** malformed ids → 404 |
| backend `084f738` | **The Daily closing failed on any MySQL not running live's empty `sql_mode`**: the older-corrections branch of the money-per-channel query broke `ONLY_FULL_GROUP_BY`, so `GET /closings/report`, `/open/view`, `/movements`, `/overview` and `/reports/daily` answered *Database request error* for every role | 1 test. Every GET route under the default `sql_mode`: 4 of 85 failing → **0 of 85**; the audit's write journeys raise no database error; 25 of 25 reads byte-identical before and after on the live-like copy |
| backend `c0a00a1` | **The purchase cost went to everybody**: `stock.received` (no target user) said *Purchase total <cost>* — readable by the Administrator role, denied `cost.view` by design (D11) | 1 test (fails before). Stored notices keep their text (live rows are the owner's call) |
| backend `1434aa7` | The identity verifier's trigger probes accepted "denied" — the same false pass as the drill | 1 test; 20 of 20 on the rehearsal copy, the triggers refusing |
| mobile `1e4567e` `3023bd3` | **`npm ci` exited 1** (the patch named 57.0.4). Re-cut for 57.0.5: byte-identical hunks — upstream changed no source file between the two (only versions and prebuilt binaries; "no user-facing changes"); the tests now follow the verifier and the lockfile | Clean `npm ci` in a scratch copy: 925 packages, the patch applied and verified (6 anchors), exit 0. The Android scan region still wants its device check |
| mobile `f200a52` | The audit's M1: choosing a product from the picker lost the scan | Its own tests; 89 of 89 suites |

## 4. Decisions waiting for the owner

Each is a choice only the owner can make; the recommendation is mine. Nothing below was built.

### 4.1 D116 — Deleting an account while WhatsApp is postponed (revisits D110)

Today: only a WhatsApp code to a verified number confirms a deletion (`docs/64` §1). In production, with WhatsApp
postponed and no email provider, **no account can be deleted** — now said honestly, up front (`56bddbe`).

| Option | How it works | Needs | Apple fit |
|---|---|---|---|
| **A. Password-confirmed, with a 7-day safety window** *(recommended)* | *Delete account* → the existing screen (what is deleted, what is kept and why) → the password again → type a confirmation (the business name for an Owner closing it, otherwise *DELETE* in the reader's language) → the request is **scheduled**: every other session signed out at once, the date shown ("Your account will be deleted on 10 Oct 2026"), **Cancel deletion** on this and any later sign-in. On the date the existing executor de-identifies exactly as now; a phone still holding the session is shown *Your account was deleted on …* | backend: a `scheduled` state, its date and a runner (a migration — `docs/22` backup first); mobile: two states and copy in EN/FR/AR; tests; a device run | Meets "inform the user how long it will take … and provide a confirmation"; no phone call, email or support flow. Weakness: a stolen unlocked phone with the password can start it — the 7 days and the sign-out of every other session are the answer |
| B. An emailed code | Apple's own example; for logins with an email | an email provider (domain, SPF/DKIM/DMARC), templates in three languages, `EmailContactDeliveryProvider` | Good — once the provider exists |
| C. WhatsApp, as designed | The current flow, plus D110 for email-only logins | the WhatsApp Business account and approved templates | Good for phone logins; an email-only login must first verify a number — Apple may read that as an obstacle |

**Before submission, whichever is chosen must complete in the production configuration, on a device, for: a staff
login, the only Owner (closing the business), an email-only Owner, and a pending or suspended shop's Owner.**

### 4.2 D117 — Registration in production

Registration needs a contact code (email or WhatsApp) that cannot be sent today. **Recommended:** hide self-registration
in the iOS build until a channel exists; a business is created from the platform administration (*Create a business* +
*Owner invitation*, both built). The sign-in screen then says only that accounts are created for businesses by our team —
no price, no link (consistent with D118). Alternatives: an email provider (B above) or WhatsApp (C).

### 4.3 D118 — The subscription and Apple's payment rules — see §5.2

### 4.4 D119 — An expired shop (proposal; the server already refuses every write)

Proposed, **without changing server policy** (expired = read-only; grace = everything still works):

- **Home**: the write actions (*Open the boutique*, *Sell*, *Receive*, *Add expense*) are not offered; in their place the
  red notice More already shows — *Your subscription has ended. You can still read and export everything, but nothing new
  can be saved.* + *Nothing has been deleted. Contact your administrator to extend it.* Figures stay. No new design element.
- **Money**: the same notice on top; *Add expense*, *Record a payment*, opening and counting are not offered; Results,
  reports and their PDFs stay.
- **A write screen opened by a link** shows the refusal instead of failing at the end (as a missing permission does).
- **Kept**: More, *Your account* and deletion, *Subscription*, every list and detail, the PDFs, *Sign out*, *Check again*.
- **Grace**: unchanged; optionally the grace notice on Home as well.

The business questions: should an expired shop still **record money arriving on an existing debt**, **pay an approved
refund**, or **close its last day**? Today all three are refused. Recommended: keep them refused (simplest, enforced
already) unless the owner names one.

### 4.5 D120 — Full IMEIs: a rule that matches the tasks (extends rule 19d)

Inventory (file references in the phase's record): full numbers appear in 19 places 19d does not name, four contradict
it (the Sell cart line and the price-approval sheet *before payment*, the Stock list, the Returns list), `GET /inventory`
and `GET /units/:identifier` need only a login, and request logs and the error handler keep full numbers. No
notification, report PDF or CSV carries one; the refund receipt is masked, the sale receipt full.

**Recommended rule:** *last four* wherever identifiers are **listed or previewed** — Stock, Returns, Transfers and
Consignments lists, the Sell cart line, the approval sheet and list, partner detail, logs (keep the last four and a
short hash to correlate). **Full** where a task needs the number: the scanner result and typing field, intake (receive,
file receive, import review), unit detail and correction, the completed sale and **the customer's receipt (warranty
proof)**, return detail and request (identifying the phone in hand), transfer and consignment detail (custody), pricing a
unit. Server: the inventory list returns the masked form (search still matches the full number); unit detail needs a
stock or sale permission; a unit timeline shows corrected identifiers masked to roles without `unit.add`. Medium work,
mostly mobile; after approval.

### 4.6 D121 — Notifications in the reader's language: a bounded plan (not built)

**No table change is needed**: `notifications.type` and the nullable `payload` (0033) already exist, and transfers and
price approvals already work this way. The plan:
1. Every producer (12: sales, purchases, closings, discrepancies, consignments, loans, pricing, returns ×8, anomalies)
   writes a typed `payload` (numbers as numbers, names as they were, never ids or cost — or cost as `totalCost`, which the
   cost interceptor strips) and **keeps** writing the English `title`/`body` as the fallback.
2. The app renders by `type` + `payload` in the reader's language (one renderer in `lib/` with a unit test), falling back
   to the stored text for old rows.
3. Fix while there: consignment and loan notices go to the **other** company (RC-14); sale notices target their branch
   (RC-15). Do not reuse `payload.event` names an older app would show as raw keys.
- Keys: about 37 per language (56 with price changes and the closing notices); plurals as one/other pairs.
- Size: about 16–22 files, no migration; an optional, re-runnable backfill of old rows.

### 4.7 D122 — *Phone sales*

The screen lists **every** sale (accessories and serial-tracked devices too); its count is IMEI-tracked units only.
Proposed: title **Sales** / **Ventes** / **المبيعات**; keep *{n} phones sold* (accurate) or, with a one-field server
addition (`itemsSold`, the quantity the server already sums), *{items} items sold · {n} phones*.

### 4.8 D123 — A Manager's personal targets

(A) Owner-only, and the server refuses a person target from a role without `user.manage` (aligns server and app);
(B) a names-only `GET /goals/people` for `goal.manage` (active staff of the Manager's branches) so a Manager can name a
person; (C) Managers see personal targets read-only. Recommended: B if Managers coach people, otherwise A.

### 4.9 D115 — A past month's PDF

The server already serves any month and marks it complete. (A) keep *This month* only; (B) a **Last month** button on
Results (recommended — the accountant's month); (C) a 12-month chooser. B and C are mobile-only.

### 4.10 D124 — Partners discoverability (D4)

Directory search **and** lookup by store code both require `is_discoverable`, which nothing sets. Recommended: lookup by
store code works without the directory flag (the code is shared on purpose), and an Owner switch *Other shops can find
this one* in Business settings governs the directory; fix RC-14 first. Alternative: hide Partners until decided.

### 4.11 Smaller calls

- **D125** — the plural helper and copy pass (RC-13, RC-27's copy items).
- **D126** — merge mobile PR #1 (re-verified on top of the release branch) or close it.
- **D127** — iOS configuration: `supportsTablet` false unless an iPad layout is wanted; the export-compliance
  declaration (the owner attests the app uses only standard TLS → `ITSAppUsesNonExemptEncryption = false`);
  `microphonePermission: false` for `expo-camera`; purpose strings in French and Arabic.
- **D128** — verified contact before approval (or before sign-in); one pending registration per email.
- Draft PRs #2 (backend, mobile) are superseded by the cherry-picks — close them. PR #1 (backend, the QA seed) is a QA
  tool, unchanged.

## 5. App Review: deletion and payment

Apple's text was read from apple.com on 2026-10-02 (the App Review Guidelines and *Offering account deletion in your
app*; neither page shows a revision date). Interpretation is mine; App Review decides.

### 5.1 Deletion

- 5.1.1(v): *"If your app supports account creation, you must also offer account deletion within the app."* The app
  creates accounts (an Owner adds staff logins; in-app registration exists), so deletion is required.
- *"You may add steps to verify the identity …"* (for example *"a code from an email or phone number already associated
  with the account"*), but *"apps that make it unnecessarily difficult for a user to delete their account will not pass
  review"*; apps outside highly regulated industries *"should not require people to make a phone call, send an email, or
  go through other support flows"*; *"If your process for account deletion is manual or otherwise takes time to
  complete, this is acceptable. Inform the user how long it will take … and provide a confirmation when the deletion has
  been completed"*; deactivation alone *"is insufficient"*. Legal retention of records is allowed.
- **Journey as it stands (API VERIFIED, production mode, WhatsApp disabled):** the screens and the executor exist and
  are proven with the development channel (`docs/64`, 117 of 117 earlier); in production every login is refused
  honestly — *codes cannot be sent right now, nothing was changed*. That is truthful and still a blocker (RC-01).
- **The refusal screen's** *"Activation and extension are handled by the administrator who set up your account. Contact
  them directly."* is not a deletion support flow (deletion stays reachable under *Sign out*), but read alongside an
  in-app registration it can look like steering to an outside purchase — another reason for D117.

### 5.2 D118 — The subscription

- **3.1.1:** *"If you want to unlock features or functionality within your app, (by way of example: subscriptions …),
  you must use in-app purchase."* The app's use is unlocked by a subscription the platform administrator activates after
  an out-of-band payment. **Selling physical phones does not exempt it**: 3.1.3(e) covers goods consumed outside the app;
  the ERP subscription is the app's own functionality.
- **3.1.3(c) Enterprise Services:** *"only sold directly by you to organizations or groups for their employees … Consumer,
  single user, or family sales must use in-app purchase."* A shop with staff fits; a one-person shop, or a shop that signs
  itself up in the app, fits less well — that is the uncertainty.
- **3.1.3(f)** (a free companion to a paid web tool) does not fit cleanly: the product *is* the app. **3.1.3(b)**
  (multiplatform) requires the same items to be purchasable as in-app purchases. The US-storefront exception for
  external links does not help a Mauritanian shop.
- What the app already does right: no price, no payment button, no link, no "buy" wording (`app/subscription.tsx`,
  `subscription-blocked.tsx`); the catalogue's unused `register.done.body` (*"open the subscription page to see what to
  pay"*) is never shown — remove it with D117.

| Option | Effect | Risk / cost |
|---|---|---|
| **1. Business accounts only** *(recommended for a first submission)* | Self-registration hidden on iOS (D117); accounts provisioned by our team under a business contract; no purchase, price or purchase call to action in the app; the Review Notes say so and supply a demo business | Medium uncertainty: a reviewer may still ask for in-app purchase for single-owner shops. Small code change |
| 2. In-app purchase | Auto-renewable subscriptions for shops that sign up on iOS; direct B2B sales continue (3.1.3(b)) | Large: StoreKit, server notifications, entitlement mapping, Apple's commission, price tiers; many local buyers may hold no card on their Apple ID |
| 3. Custom / unlisted distribution | Apple Business Manager custom apps or an unlisted link | Still reviewed under the same rules; Business Manager enrolment is heavy for small shops |

TestFlight with internal testers needs no App Review; external testers need Beta App Review, which applies the
guidelines.

## 6. Migration rehearsal — 0084 → 0085, on a restored disposable copy

**Where:** a second, throwaway MySQL 8.0.46 in the session's scratch directory, configured **like live** — empty
`sql_mode`, `utf8mb4_unicode_ci` server collation (the rehearsal database inherited it), binary log **off**,
`lower_case_table_names=1` (Windows). Synthetic QA boutiques only. Live's MySQL version is not recorded anywhere; check it
first (§7 step 0).

| Step | Result |
|---|---|
| Identities | the fixed `deploy/mysql-identities.sql`: a missing password refused before any account; 4 accounts; re-run idempotent |
| The 0083 source | migrated by the **pre-0084 code** (`ae64de8`, 82 migrations) as the migrator; filled **through the old API**: 10 boutiques (registered, verified, activated; 32 products, 80 phones + 20 accessories each), sales, a part-paid sale to an Arabic-named customer, expenses with Arabic notes, a product named ``DEFINER=`x`@`y` cable``: **94 tables, 30 triggers, 1 195 audit rows** |
| Backups | encrypted, as the backup identity (`deploy/backup-encrypted.sh`): 192 KB, 94 tables, trailer verified · the canonical `docs/22` dump as the migrator: 1.50 MB, 94 `CREATE TABLE`, 0 raw `_binary`, 20 957 hex keys, trailer |
| Restore → the disposable copy | `docs/22` Path 2 + `mysql --comments` into a new database: **every table identical by row count and `CHECKSUM TABLE`**, 30 trigger bodies byte-identical, ids intact. Without `--comments` two trigger bodies lose their comments (logic identical) — now in `docs/22` |
| **0084** (code of `1925a0d`) | **1.08 s.** Changed exactly: `_prisma_migrations` (+1), `companies` (+`closed_at`, 10 rows), the new empty `account_deletion_requests` (3 FKs); both `purpose` enums widened; **90 other tables byte-identical**; 30 triggers |
| **0085** (the release candidate) | **1.62 s.** 1 195 rows sealed, 10 chain heads (= companies) totalling 1 195; the `BEFORE INSERT` trigger present (database collation `utf8mb4_unicode_ci`); the index; the seal procedure dropped; `scripts/verify-audit-chain.ts` as the read-only backup identity: **10 of 10 companies OK** |
| Schema | identical to a database built fresh from all 84 migrations: `prisma migrate diff` none; 1 327 columns, 707 index entries, 31 triggers (bodies), 304 foreign keys, 96 tables |
| New API, application identity | activity 13 of 13; its 25 new audit rows chained; chain OK |
| **Old API on the migrated schema** | activity 13 of 13, its rows chained by the trigger, chain OK — **the minutes between migrating and restarting are safe, and a code rollback needs no database restore** |
| **New API on the unmigrated 0083** | sign-in and most reads work; *Your account* and every audited write fail; an expense was **stored without its audit row** while the phone was told it failed — the abort condition the runbook guards |
| Identities | `verify-mysql-identities.sh` **20 of 20** on the migrated copy (the application account appends through the chain trigger and is refused `UPDATE`/`DELETE` by the triggers) |
| Restore drill (fixed script) | PASSED, every table by CHECKSUM; the old script shown to pass a corrupted copy |
| **Failure recovery** | 0085 made to fail part-way (a stray `audit_chain_heads`): `P3018`; left behind — the two new columns, the index, **the seal procedure**, one row already sealed (the procedure is not atomic), no trigger; further deploys refused. **Recovered** by: `DROP TRIGGER IF EXISTS audit_logs_chain; DROP PROCEDURE IF EXISTS audit_chain_seal; DROP TABLE IF EXISTS audit_chain_heads; ALTER TABLE audit_logs DROP INDEX ix_audit_logs_company_id_id, DROP COLUMN entry_hash, DROP COLUMN prev_hash;` → `npx prisma migrate resolve --rolled-back 0085_audit_chain` → `npx prisma migrate deploy` → every row sealed, chain OK, status up to date. (The migration's own *Reverse* note misses the procedure.) The other path — restore the dump into a new database — is the restore above |
| Concurrency on the migrated schema | the pool deadlock found and fixed (§3, `4370240`) |
| Default `sql_mode` | the Daily closing failure found and fixed (§3, `084f738`) |
| The current app on the migrated copy | the web export of mobile `3023bd3` against the release-candidate API: 19 main screens, **0 error screens, 0 API 5xx, 0 page errors** (WEB VERIFIED — a browser, not the phone) |
| Cleanup | every rehearsal database, server, worktree and secret file removed at the end (SESSION_LOG) |

## 7. Production runbook — live (WAMP on the owner's PC)

**Approval and access needed before step 1 — none of it is available to a cloud session:**
1. The owner's written approval of the window (date, time, the API stopped for about 15 minutes).
2. Someone at the PC with its shell: WAMP's MySQL running, the migrator option file (`~/.my.cnf`, `docs/22` §2), Node,
   and the backend checkout. A cloud session cannot reach live.
3. Which process serves the shop's API (port 3010 so far) and its `.env` (`NODE_ENV`, `WHATSAPP_CHANNEL`, and that
   `APP_DATABASE_URL` uses `phonestore_app`).
4. Free disk for the dump (about 2 MB today).

| Step | Command / check | Abort if |
|---|---|---|
| 0. Pre-checks | `SELECT @@version, @@sql_mode, @@log_bin, @@collation_server;` `SELECT DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='phonestore';` · `git -C backend fetch && git -C backend checkout reports-export && git -C backend pull` → `git log -1` = **`1434aa7`** · `npx prisma migrate status` → only 0084 and 0085 pending · record `SELECT COUNT(*), MAX(id) FROM audit_logs` and the row counts of `sales`, `payments`, `expenses`, `units`, `daily_closings` | any other migration pending; the checkout is not `1434aa7`; MySQL is not 8.0 (re-rehearse on that version first) |
| 1. Stop | stop the API (and Metro); `SHOW PROCESSLIST` shows no application connection | a phone is mid-sale (wait) |
| 2. Backup | `mysqldump --defaults-extra-file="$HOME/.my.cnf" --single-transaction --routines --triggers --events --no-tablespaces --hex-blob phonestore > "$HOME/erp-backups/phonestore-before-0084-<stamp>.sql"` · non-trivial size · `tail -1` = `-- Dump completed` | the trailer is missing |
| 3. Restore check | Path 2 (`node backend/scripts/sanitize-dump.js <file>`) and `mysql --defaults-extra-file=… --comments` into a new `prisma_rc_restore`; compare table and trigger counts and the step-0 row counts; drop it | anything differs |
| 4. Migrate | `cd backend && npx prisma migrate deploy` → *Applying migration `0084_account_deletion`*, *`0085_audit_chain`*, *All migrations have been successfully applied* (seconds) | `P3018` → do **not** start the new API; recover (below) |
| 5. Post-checks | `npx prisma migrate status` → up to date · `SELECT COUNT(*) FROM audit_logs WHERE entry_hash IS NULL` → 0 · `SELECT COUNT(*), SUM(entries) FROM audit_chain_heads` → companies, audit rows · trigger count = before + 1 · no routine left · step-0 counts unchanged · `DATABASE_URL=<a read account> npx ts-node scripts/verify-audit-chain.ts` → every company OK | any of it fails → keep the API stopped; recover |
| 6. Start | `npx prisma generate` (with the API stopped — Windows holds the engine file open), then the API on `1434aa7` with the same `.env` | — |
| 7. Smoke (read-only) | the Owner signs in on the phone; Home, Money, the Daily closing, a sale's detail, *Your account* load; the server log shows no *Database request error*; after the shop's first real sale, `verify-audit-chain` again | errors on writes → stop the new API and start the previous one (it works on the migrated schema — rehearsed); investigate |
| 8. Record | the dump's name, size and trailer, the migration time, the post-check results → `CURRENT_HANDOFF.md` at once | — |

**Recovery.** A failed 0085: the reverse of §6 plus `migrate resolve --rolled-back 0085_audit_chain`, then `migrate
deploy` again once the cause is fixed; or restore the step-2 dump **into a new database**, verify it, and point the
previous API at it — never drop `phonestore` before the restored copy is verified. A code rollback alone (the previous
API) needs no database restore: 0084 and 0085 are additive and the old API runs on them.

**A future hosted production differs in four ways:** MySQL's default `sql_mode` (now handled, `084f738`); the binary log
on — set `log_bin_trust_function_creators=1` before any migration or restore that creates triggers (ERROR 1419 otherwise;
`deploy/mysql-identities.sql`); an explicit `connection_limit` on `APP_DATABASE_URL` (10–20) rather than Prisma's
CPU-based default; and the encrypted backup + restore drill, identities and secrets of `docs/48` §12.

## 8. GO / NO-GO

**TestFlight — NO-GO today; GO for internal testers as soon as three things exist that only the owner can provide.**
Nothing in the code blocks it any more: the native install is fixed, every gate passes, the API and the app work on the
migrated schema. Missing: (1) the Apple Developer membership, the App Store Connect record for `mr.retailerp.app` and
EAS credentials; (2) an **HTTPS API** for the build to point at — recommended a staging host with synthetic data until
the security gate passes, rather than the shop's real data on an internet-facing machine; (3) 0084/0085 applied to that
database, and the export-compliance answer. **External TestFlight testers: NO-GO** until RC-01 and RC-02 are resolved,
because Beta App Review applies the guidelines.

**Public App Store submission — NO-GO.** RC-01 (deletion cannot complete in production), RC-02 (registration cannot
finish), RC-03 (the payment model is undecided), RC-04 (no production host), RC-06 (nothing verified on an iPhone),
RC-07 (the security gate is NOT PASS), RC-08 (no privacy policy) and RC-09 (demo account, export compliance, privacy
manifest, iPad) each block it on their own.

---

## 9. Update of 2026-10-05 — the external subscription management separation (`docs/21`; `docs/68`)

Backend `reports-export` **`7283844`**, mobile `reports-export` **`6f6ef47`**.

| Item | Was | Now |
|---|---|---|
| **RC-02** registration cannot finish in production | a reviewer registering a shop was stuck at *Check your contact*; the unfinished Owner could sign in to *Waiting for activation* | **No registration in the app** (D117): the sign-in screen says accounts are set up by the organisation; the server refuses `POST platform/register` up front with nothing saved. What remains for review is **RC-09's demo business** and Review Notes that say accounts are provisioned under a business contract |
| **RC-03** the subscription model against 3.1.1 | undecided | **Decided — D118, option 1 (business accounts only)**: no price, payment, purchase, renewal or external-purchase call to action anywhere in the app or its bundle; the platform console is out of the app (D129); access is shown as neutral *Business access* status (D130). Residual uncertainty: 3.1.3(c) for a one-person shop — Review decides |
| **D119** an expired shop | proposed | **Implemented** on the client (read-only consistency on every tab, write-only screens redirected); server policy unchanged |
| **The App Store boundary** | — | source, catalogues and the exported bundle audited: no price of our own, no purchase/renewal wording, no Bankily instruction for us, no checkout or purchase URL, no website call to action; a shop's own Cash/Bankily/accounts untouched |

**GO / NO-GO: unchanged.** Internal TestFlight stays GO once the owner's three inputs exist (§8); external TestFlight
and the public App Store stay **NO-GO** on RC-01 (deletion needs D116), RC-04, RC-06, RC-07, RC-08 and RC-09. **The
website is not operational**: it is a contract (`docs/68`), and the Super Admin's approve / refuse / create / invite
have no UI until it is built (`docs/68` §8).
