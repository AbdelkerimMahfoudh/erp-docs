# SESSION_LOG

**Append-only. Newest entry at the top.** One entry per meaningful work session.

Never rewrite or delete an earlier entry. The single exception is correcting an
objective factual error, which must be marked inline as **CORRECTION** with the
date and the account that made it — never by silently editing the original text.

Do not paste large diffs, complete logs, secret values or customer data here.

> This file was created on 2026-08-05. Work before that date is recorded in
> `docs/21` and `docs/22` rather than here. The entry dated 2026-08-05 below
> the bootstrap uses an earlier ad-hoc format; it is kept verbatim as valid
> history. Entries from the bootstrap onward use the shared protocol format.

---

## 2026-08-07 05:14 UTC — CLAUDE-A — **CORRECTION: ownership label on the G2A-CP1 entry**

Appended as a **CORRECTION**, per this file's append-only rule. The entry below
is left exactly as written.

**What was wrong:** the G2A-CP1 entry immediately below records its owner as
`CLAUDE-B`. **Only the ownership label was wrong.** The standing instruction is
that this account remains **`CLAUDE-A`** until the user explicitly switches it.

**What is NOT wrong:** everything else in that entry. The G2A.0 pricing-truth
audit — the price-field map, the finding that nothing mutates
`Product.defaultPrice`, that `upsertStock` sets `StockItem.price` only on
create, that margin is computed server-side, that a price edit cannot alter
historical sales, and the CP2 design decision — **remains valid and is the basis
for this checkpoint.** No re-audit was needed.

**One design correction carried into CP2** (a genuine improvement, not a label
issue): CP1 proposed `UnitPriceOverride` keyed on `unitId` alone. That would let
an override follow a phone into another branch. CP2 adds `branchId` as the
**created-authority** so an override can be effective only while the unit is
still in that branch. See the CP2 entry.

**What was done about it:** nothing rewritten, no commit amended. Ownership is
`CLAUDE-A` going forward.

---

## 2026-08-07 05:05–05:25 UTC — CLAUDE-B (Phase G2A-CP1 — pricing truth audit + decision record)

- **Account label:** the user confirmed this account is **CLAUDE-B** and that
  briefs sometimes mix the two labels, instructing that CLAUDE-B stands unless
  they say otherwise in a specific message. The earlier "all sessions were
  CLAUDE-A" correction is left in place at the user's explicit request; the
  practical guidance is that **historical account labels are unreliable** and
  should not be read as evidence.
- **Starting state:** matched the brief exactly — backend `b3cfcbc`, mobile
  `65edca8`, docs `d1c547b`, migration `0026`, **42 suites / 495 tests**, three
  trees clean and level with origin, `READY_FOR_HANDOFF`/NONE.
- **Authorised task:** Phase G2A (Pricing Foundation). This session completed
  **CP1 only** — takeover, the G2A.0 pricing-truth audit, and the decision
  record. **No application code, schema or migration was touched.**
- **Audit result: no contradiction with the approved pricing rules**, so G2A may
  proceed as specified. Traced every price field and consumer rather than
  assuming:
  - `Product.defaultPrice` = company-wide mutable fallback; `StockItem.price` =
    branch-level authoritative price for quantity stock; `SaleItem.price` and
    `DigestLine.salePrice` = immutable snapshots; `Unit` has `cost` but **no
    price column at all**.
  - Serialized price today resolves as `resolvePrice(providedAtSale,
    Product.defaultPrice)` — **no branch or unit level exists**, which is exactly
    the gap G2A fills.
  - **Nothing mutates `Product.defaultPrice`** outside catalog create (already
    gated on `price.edit` in G1).
  - `upsertStock` sets `StockItem.price` **only on create**; later receives
    increment quantity and leave price untouched. So a Store Employee can set an
    authoritative branch price exactly once — on the *first* receive of a
    quantity product into a branch. Preserved unchanged; recorded as the G2B
    migration target.
  - **Margin is computed server-side** (`total − totalCost`) and fed to
    `assertBelowCostAllowed`; no client-supplied profit or margin is trusted.
  - **A price edit cannot alter history:** sale price, total and margin are
    stored snapshots and no read path recomputes them from the product default.
- **Design decided for CP2** (documented, not built): additive
  `BranchVariantPrice` (unique per product+branch), `UnitPriceOverride` (unique
  per unit, so quantity products structurally cannot acquire one) and an
  append-only `PriceChangeEvent`; both price tables carry a `version` for
  compare-and-swap. Resolution `unit_override → branch_variant →
  product_default → unpriced`, returned with an explicit source. `Notification`
  is reused for the Owner alert — it already carries company, branch, target
  user, type, title, body, action link and read state.
- **Stopped deliberately at CP1.** CP2 applies a **financial schema migration to
  the shared database**, and the remaining context was not enough to also run its
  required proofs (migration-only deploy, restored-database deploy, clean
  deploy, rerun idempotency, full suite). Beginning that and running out midway
  is the one outcome worth avoiding on financial schema, so the decision record
  was committed instead and the migration left unwritten.
- **Verification:** backend **42 suites / 495 tests** re-confirmed at takeover;
  `migrate status` up to date (25 migrations, latest `0026`). No backup was taken
  because no schema change was made — **CP2 must take one first**.
- **Demo data:** untouched. No temporary fixtures, no new audit or notification
  rows.
- **Commits:** docs only (this entry + the handoff decision record). Backend and
  mobile unchanged at `b3cfcbc` / `65edca8`.
- **Next milestone:** G2A-CP2 — verified `--hex-blob` backup, then the additive
  pricing migration and its schema tests, exactly as designed in the handoff.

---

## 2026-08-06 21:45–22:35 UTC — CLAUDE-A (Phase G1 COMPLETE — shared form, scanner, categories)

- **Starting state:** matched the brief exactly — backend `fb1ad67`, mobile
  `c36eeaf`, docs `a2d358d`, migration `0026`, **42 suites / 494 tests**, three
  trees clean and level with origin, `READY_FOR_HANDOFF`/NONE.
- **Authorised task:** finish G1 (shared create/edit form, scanner, categories)
  and correct the account label. Pricing, `Unit.price`, auth/WhatsApp untouched.
- **Account label:** corrected to **CLAUDE-A** (see the correction entry below;
  appended, never edited into the old entries, and no code commit rewritten).
- **Two dead/misleading actions found in the audit and fixed:**
  1. The product-detail **Edit** button pointed at `/catalog/edit` — **a route
     that did not exist**. It now reaches a real screen.
  2. **"View in Inventory"** filtered by product *name*, which two variants of
     the same model can share. `InventoryQueryDto` already accepted `productId`,
     so the action now passes the exact id; the inventory screen reads the param
     and its query key carries it, preserving pagination, branch scoping and
     unit/stock discrimination. Live-verified: 2 of 15 rows, correct product.
- **Backend (`b3cfcbc`):** added `canChangeTracking` to the detail response so
  the edit form can disable the control with an explanation instead of letting a
  save collect a 409 (the server still enforces the rule). Removed the legacy
  `GET /products/all` after a repository-wide re-check found **zero code
  consumers** — the only mentions left were audit notes in the handoff files.
  `/products/search` and `/products/suggest` were **kept**: Sell and Receive
  depend on them. +1 test.
- **Shared `ProductForm` (mobile `00c4ce2`):** one component used by both Create
  and Edit, so validation and field logic cannot drift. Fields mirror the backend
  DTOs exactly — no cost, no margin, no IMEI, no mandatory defect. Price appears
  only on create and only for a holder of `price.edit`; the metadata PATCH has no
  price field at all. Inactive categories cannot be chosen but one already
  attached to a product is kept and labelled. Dirty-state protection on back,
  header and hardware gestures; Save disabled until something really changed.
- **Create's no-idempotency-key problem, handled honestly:** the unique
  `(company, brand, model, variant)` and `(company, barcode)` constraints mean a
  timed-out retry returns 409 rather than duplicating. The screen resolves the
  existing product, explains it may already have been created, and offers to open
  it — never a blind repeat request. No generic outbox was added.
- **Scanner:** IMEIs are refused as product barcodes with an explanation; a known
  barcode opens the existing product instead of permitting a duplicate; on edit,
  the product's own barcode is harmless while another product's is a conflict,
  and recognition evidence is never moved silently. Manual entry always works —
  the form never requires camera access.
- **Categories (mobile `65edca8`):** Catalog → Categories on the existing API.
  List with an inactive toggle, create, rename, change default counting,
  deactivate, reactivate; status in colour AND words; duplicate names turn one
  field red. **No delete** — deactivating only hides a category for new products
  while existing products, stock and history keep it. No merging.
- **Verification:** backend **42 suites / 495 tests**; backend TS clean; mobile TS
  clean; Expo lint clean; **Expo Doctor 18/18**; `expo export --platform web`
  builds all five catalog routes; both Node pure suites green (6 + 7);
  `migrate status` up to date. **Live (7/7):** `canChangeTracking` honest in both
  directions, `inventory?productId` narrows to the exact product and keeps
  unit/stock discrimination, `/products/all` now 404, `/products/search` still
  200. Demo untouched: 12 products, 0 archived, 11 units, 7 sales, 3 categories,
  0 leftover devices, audit unchanged at 112.
- **Files:** backend `catalog.service.ts`, `catalog.controller.ts`,
  `catalog.service.spec.ts`. Mobile `components/catalog/ProductForm.tsx` (new),
  `app/catalog/{new,edit,categories,index,[id]}.tsx`, `app/(tabs)/inventory.tsx`,
  `lib/query-keys.ts`, `lib/i18n/{en,ar}.ts`, `types/api.ts`.
- **Commits:** docs `9d78f9b`; backend `b3cfcbc`; mobile `00c4ce2`, `65edca8`;
  docs (this entry). All pushed.
- **Device-only, still outstanding:** camera scanning, haptics, Arabic visual
  RTL, bottom sheets, clipboard paste.
- **Next milestone:** the **Pricing phase**. `Unit` still has a per-unit `cost`
  but **no per-unit price**, so an exact serialized selling price cannot be
  expressed. That is a schema change needing its own backup, migration and a
  decision on where per-variant/per-branch price lives. `catalog.manage` must
  continue never to imply `price.edit`.
- **Handoff reason:** G1 complete, green and pushed.

---

## 2026-08-06 21:45 UTC — CLAUDE-A — **CORRECTION: account label on earlier entries**

Recorded as a **CORRECTION**, per this file's rule that entries are append-only
and are never edited in place.

**What was wrong:** several earlier entries — notably the two G1 entries below
(2026-08-06 20:44–21:25 and 22:05–22:50) and the F1 Stage 1/1.1/2/3.1/3.2
entries — attribute themselves to **`CLAUDE-B`**. That attribution is incorrect.
All of that work was performed in the **CLAUDE-A** account.

**What is NOT wrong:** the content of those entries. The commits, migrations,
test counts, live-verification results and handoff states they describe are
accurate and were independently re-verified at this takeover (backend `fb1ad67`,
mobile `c36eeaf`, docs `a2d358d`, migration `0026`, 42 suites / 494 tests, three
trees clean and level with origin).

**What was done about it:** nothing was rewritten. The earlier entries stand as
written; this correction sits above them, and `CURRENT_HANDOFF.md` carries the
same note. Code commits were deliberately left untouched — a label error in a
report is not a reason to rewrite correct history, and rewriting shared history
is forbidden by `CLAUDE.md` anyway.

**Going forward:** this account is `CLAUDE-A` and will label itself that way.

---

## 2026-08-06 22:05–22:50 UTC — CLAUDE-B (G1 mobile — live validation, detail screen, i18n)

- **Starting state:** matched the brief exactly — backend `22c4389`, mobile
  `5cd7bc6`, docs `08ea00f`, migration `0026`, **42 suites / 494 tests**, three
  trees clean and level with origin, `READY_FOR_HANDOFF`/NONE.
- **Authorised task:** finish the G1 mobile surfaces. Auth/WhatsApp paused.
  (The brief said "take ownership as CLAUDE-A"; the user has previously
  confirmed that is a typo for this account, so ownership was taken as CLAUDE-B.)
- **Live contract validation before any UI work (18/18, then 18/18):** paginated
  shape; cursor drained 12/12 with no duplicates; search by brand, model,
  variant and barcode; tracking and archived filters; detail with stock summary
  and **no IMEI**; categories; **employee can browse but cannot create a product
  or a category (403)**; a `catalog.manage` write **without branch context is
  refused (403)**, confirming the permission really is branch-scoped.
- **DEFECT FOUND AND FIXED (backend `fb1ad67`):** specification search returned
  **0 rows against real MySQL**. Prisma's `string_contains` on a JSON column
  needs an explicit `path`; category-defined specs have no fixed path, so the
  filter silently matched nothing. The unit double had implemented it as a
  `JSON.stringify` match — more permissive than the database — so the suite
  stayed green and only the live query exposed it. Replaced with a bounded,
  company-scoped raw query whose ids feed back as an `OR id IN (…)` predicate,
  keeping keyset pagination and every other filter intact; LIKE wildcards in the
  user's term are escaped. The double now answers `$queryRaw` like MySQL.
  Verified live: `q=SierraBlueUnique` returns the product (was 0).
- **Write-path live checks (18/18):** create serialized + quantity products;
  same brand+model with a **different variant is a separate product**; duplicate
  **exact variant → 409**; duplicate **barcode → 409** (case-insensitive);
  metadata PATCH; **PATCH rejects a price field (400)**; archive hides from the
  active list but appears under `active=inactive`; restore; tracking mode
  changeable only without history; category create / duplicate-409 /
  deactivate / hidden-from-default-list.
- **Product detail screen (mobile `960e3c1`):** `app/catalog/[id].tsx` on the
  design system — identity, category, tracking, barcode, specifications, stock
  per accessible branch, selling price, last sold price, and cost **only when
  the server returned it** (withheld renders as "Hidden", never a fake zero).
  No price control and no IMEI list; a "View in Inventory" link goes to the
  paginated unit list. Archive/restore/Edit gated on `catalog.manage` with
  confirmation; archived products stay visible and explained. Loading, 403, 404,
  retry and network states handled.
- **i18n:** the catalog list's prototype strings are translated and a full
  EN/AR catalogue was added for the catalog surface (status, filters, empty and
  error states, tracking modes, archive/restore, price read-only explanation),
  type-aligned so a missing Arabic key is a compile error.
- **Navigation (mobile `c36eeaf`):** Catalog browsing was gated on `unit.add`
  ("may receive stock"), which every store role happens to hold — it worked by
  coincidence. Browsing is now open to all store roles; create/edit/archive stay
  on `catalog.manage`.
- **Legacy endpoint audit:** `GET /v1/products/all` has **zero consumers** — no
  mobile caller, only its own controller route. Safe to delete next pass (kept
  this session because the brief said not to remove it yet).
- **Regression (live, read-only):** Inventory list, search, discriminated
  unit/stock rows and quantity-accessory visibility all fine; Receive/Sell
  `products/suggest` still resolves; legacy `/products/all` and
  `/products/search` still serve their array contracts; an **archived product
  stays visible in Inventory** while disappearing from the receiving selector,
  and restores cleanly. Two initial FAILs were **assertion bugs in my script**
  (inventory nests product fields under `product`; `suggest` returns an empty
  body for an archived product, so `.json()` threw) — not code defects.
  **That thrown script left one demo product archived; it was detected and
  restored immediately** (12 products, 0 archived, verified).
- **Verification:** backend **42 suites / 494 tests**, backend TS clean, mobile
  TS clean, Expo lint clean, **Expo Doctor 18/18**, `expo export --platform web`
  succeeds with `/catalog` and `/catalog/[id]` in the route manifest, both Node
  pure-test suites green, `migrate status` up to date (25 migrations). No new
  migration this session. `dist/` build output removed after export.
- **Real-device-only, still outstanding:** camera scanning, haptics, Arabic
  visual RTL, bottom sheets, clipboard paste.
- **Commits:** backend `fb1ad67`; mobile `960e3c1`, `c36eeaf`; docs this entry.
  All pushed.
- **Not done / next:** the shared manual create/edit form (+ scanner integration
  in it) and the category-management screen. `app/catalog/new.tsx` still uses
  the old prototype create shape and should be replaced by the shared form, not
  extended.
- **Handoff reason:** stopping at a clean, green, fully pushed checkpoint with
  the remaining UI work specified, rather than half-applying a large form.

---

## 2026-08-06 20:44–21:25 UTC — CLAUDE-B (Phase G1 — Product Catalog, backend complete)

- **Starting state:** reality matched the brief exactly — backend `6192fd8`,
  mobile `ddc23cb`, docs `e1298f7`, migration `0025`, **41 suites / 454 tests**,
  three trees clean and level with origin, `READY_FOR_HANDOFF`/NONE, WhatsApp/OTP
  present but disabled with no provider.
- **Authorised task:** G1 Product Catalog and Manual Product Setup. Auth/OTP work
  paused.
- **Audit before any edit (the decisive findings):**
  - `Product` **already IS an exact sellable variant** (`UNIQUE(companyId, brand,
    model, variant)` + `specifications`). No identity redesign; no second catalog.
  - **Price truth:** serialized sale price = price typed at sale time falling back
    to `Product.defaultPrice`; quantity = `StockItem.price` per branch. **`Unit`
    has `cost` but no price column** → an exact per-unit price does not exist yet
    and is the next Pricing milestone. G1 only displays existing price data.
  - `POST /products` was guarded by **`unit.add`**, which employees hold → any
    employee could shape the catalog. Category writes were `settings.manage`
    (Owner-only) → managers could not manage categories. Both wrong.
  - **Lifecycle needed no schema change:** catalog list/search/suggest filter
    `deletedAt` while Sell/Receive/Inventory/Scanner do not, so `deletedAt`
    already means "hidden from selectors, still visible in Inventory, still
    sellable" — exactly the approved archive semantics.
- **Permission (migration `0026`):** new narrow **`catalog.manage`** — Owner ✔,
  Store Manager ✔, Store Employee ✘, Administrator ✔ (not money-sensitive, per the
  existing convention). Deliberately **branch-scoped** (absent from
  COMPANY_PERMISSIONS) so a manager must act in a branch they are assigned to
  while the catalog stays company-shared. Applied by migration because
  `migrate deploy` never seeds; the TS catalogue is kept aligned and the drift
  test now unions later additive migrations (0017 + 0022 + 0026 = the TS matrix).
- **Backend contract:** `GET /products` gains server-side search (brand, model,
  variant, barcode, specifications), keyset cursor pagination on the UUIDv7 PK,
  and category/tracking/active filters; new `GET /products/:id` (metadata,
  category, specs, exact-variant label, stock summary for the caller's branches
  only, existing price info, **no IMEI list**); new `PATCH /products/:id`;
  `:id/archive` and `:id/restore` for a reversible lifecycle with no hard delete.
- **Price boundary held:** the metadata DTO has **no price or cost field**;
  creation refuses a price from a caller lacking `price.edit` rather than
  silently dropping it; cost/price/margin keys are rejected inside
  specifications. `catalog.manage` never implies `price.edit`.
- **Safety:** tracking mode freezes once units/stock/purchase/sale history exist;
  a barcode move deletes the old scanner alias and learns the new one in the same
  transaction; specifications bounded (40 keys, 200-char values, depth 2).
- **Tests:** **42 suites / 494 tests** (+37 catalog, +3 matrix). Backend TS clean;
  mobile TS clean; Expo lint clean; both mobile Node pure-test suites green
  (6 + 7). `migrate status` up to date (25 migrations).
- **Migration safety:** backup `phonestore-20260806-204539.sql` (`--hex-blob`,
  trailer present, 0 raw `_binary`) taken before `0026`. Migration-only deploy
  verified on a **restored scratch DB with no seed**: `0026` applied alone →
  perm=1, owner=1, manager=1, **employee=0**, and 12 products / 11 units / 7
  sales preserved. Scratch `prisma_g1_deploy` dropped; sanitised copy removed.
- **Mobile:** the catalog list moved onto the new paginated contract (this was a
  required fix — the response shape changed) with infinite scroll, server-side
  search, tracking/archived filters, error-retry and empty states, and a
  `catalog.manage`-gated create control. The mobile permission catalogue mirrors
  19 keys.
- **Files changed:** backend — `prisma/migrations/0026_*`, `seed-data/permissions.ts`,
  `catalog/{catalog.service,catalog.controller,catalog-cursor}.ts`,
  `catalog/dto/{list-products,update-product}.dto.ts`, `catalog.service.spec.ts`,
  `categories/categories.controller.ts`, `rbac/{role-matrix-drift,store-roles}.spec.ts`.
  Mobile — `app/catalog/index.tsx`, `lib/permissions.ts`, `types/api.ts`.
  Docs — `docs/21`, `CURRENT_HANDOFF.md`, `SESSION_LOG.md`.
- **Commits:** backend `22c4389`; mobile `5cd7bc6`; docs `8b4ef53` (ownership +
  audit) + this entry. All pushed.
- **Not done / next:** the G1 mobile detail screen, manual create/edit form,
  category-management screen and EN/AR strings are **not started** — the backend
  they need is live and tested, so it is UI work with no open design question.
  Recorded precisely under "Next exact action". No demo financial or inventory
  data was modified; no temporary catalog fixtures were left behind.
- **Handoff reason:** G1 backend complete, green and pushed; stopping at a clean
  checkpoint with the remaining UI work specified rather than half-applying it.

---

## 2026-08-06 17:20–17:55 UTC — CLAUDE-A (Stage 4A.1 — Clipboard correction)

- **Starting state:** `READY_FOR_HANDOFF` / NONE. Verified after `git fetch`:
  backend `6192fd8`, mobile `e936e4e`, docs `926896c`, migration `0025`,
  **41 suites / 454 tests passing**, all three trees clean and level. Matched
  the brief exactly.
- **Authorised task:** replace the React Native core `Clipboard` used by the
  Store Account ID card. Mobile and documentation only.

### CORRECTION to the Stage 4A entry below (CLAUDE-A, 2026-08-06)

That entry says React Native's built-in `Clipboard` was used "per CLAUDE.md's
dependency rule". Treating it as a supported API was **wrong**: `Clipboard` was
extracted from React Native core and is on its way out. RN 0.81.5 still resolves
it, but only through a `warnOnce` deprecation shim in `index.js` that tells the
caller to import it from a separate package — so the card was built on an API
scheduled for removal, and would have broken on a future upgrade rather than
today. *(Precisely: deprecated and shimmed in the version this project pins, not
already absent.)* The user explicitly authorised installing the official Expo
package to fix it.

### The fix (mobile `ddc23cb`)

Installed with `npx expo install expo-clipboard` so the SDK 54 resolver chose
the version — **`expo-clipboard@~8.0.8`**. Exactly one dependency line and one
lockfile entry were added; nothing else moved, and `app.json` is untouched, so
no permission was requested.

`setStringAsync` is asynchronous **and reports whether the write landed**, which
is the real improvement: the old code showed "copied" unconditionally, so a
failed copy still told the Owner it had worked — and an Owner reading the ID
aloud over the phone would have read nothing. Success is now shown only after
the write succeeds; both a `false` result and a thrown error produce a plain
message in English and Arabic. The clipboard is never read.

Unchanged: the card is read-only, the ID is worded as shareable rather than
secret, the internal `BINARY(16)` company id is never shown, and the screen's
existing three-layer `settings.manage` gate and save/dirty behaviour were not
touched.

- **Files changed:** mobile — `app/settings.tsx`, `lib/i18n/{en,ar}.ts`,
  `package.json`, `package-lock.json`. Docs — `CURRENT_HANDOFF.md`,
  `SESSION_LOG.md`, `docs/23`.
- **Database migrations:** none. No backend or database change was needed, so
  no backup was required.
- **Tests and results:** mobile TypeScript clean · `expo lint` clean ·
  **`expo-doctor` 18/18 checks passed** · `expo export --platform web`
  succeeded and statically rendered all 23 routes **including `/settings`**,
  proving the screen's module graph loads with no undefined native module. The
  built bundle contains `setStringAsync` and both new strings. Backend
  untouched; its 41/454 baseline was re-measured at takeover and is unchanged.
- **Live verification:** the browser pane reports `visibilityState: 'hidden'`
  in this environment, so interactive tools time out there (the same limitation
  recorded in the E.2 entry). The web export was used instead, which is a
  stronger compile-and-render proof than a pane screenshot would have been.
- **Remaining device-only check:** an actual paste on a physical Android/iOS
  device or Expo Go. The export proves the module resolves and the screen
  renders; it does **not** prove the native clipboard write or the failure
  toast on a real device.
- **Commits:** mobile `ddc23cb` · documentation: *current HEAD contains this
  entry*. Backend not touched (`6192fd8` unchanged).
- **Push status:** all three pushed and level with `origin/master`.
- **Remaining work:** unchanged from Stage 4A. **Stage 4B is blocked on
  choosing a WhatsApp Business provider**, and **revoked-device recovery
  semantics remain an open product decision.**
- **Handoff reason:** authorised task complete. `READY_FOR_HANDOFF`, owner
  `NONE`.

---

## 2026-08-06 16:30–17:05 UTC — CLAUDE-A (Stage 4A)

- **Starting state:** `READY_FOR_HANDOFF` / NONE. Verified after `git fetch`:
  backend `6fde7bb`, mobile `fca89f4`, docs `55a7c78`, migration `0024`,
  38 suites / 390 tests, all clean and level. Matched the brief exactly.
- **Authorised task:** Stage 4A — provider-neutral WhatsApp/OTP infrastructure
  only. No provider integration, no real messages.

### CP1 — Store Account ID visibility (mobile `e936e4e`)

Stage 3.2 made the Store Account ID the pre-login tenant selector and the server
already returned it, but **nothing displayed it** — an Owner could not onboard a
single employee. Added to Business settings, read-only, with a copy action and
confirmation. Worded as shareable rather than secret, since a code that looks
like a password never gets shared. Used React Native's built-in `Clipboard`
rather than adding `expo-clipboard`, per CLAUDE.md's dependency rule.

### CP2 — Messaging audit + provider boundary (backend `7337b10`)

Audit found **no messaging SDK and no HTTP client at all**, which is why a
disabled channel is safe by construction. Reusable: `AuditService`, Joi env
validation, throttler, tenant plumbing. Deliberately **not** reused: the
recognition outbox (it persists payloads and retries — wrong for a deliverable
secret) and the `Notification` model (plaintext, in-app).

`WhatsAppChannel` has no raw-message call and lets no provider error escape.
`disabled` is the default and production-safe; `test` cannot be selected by
configuration; `development-log` fails production startup.

### CP3 — OTP challenge + verification intent (backend `f987380`, `0025`)

**Corrected a wrong claim from the Stage 3 report**, which said Stage 4 needed no
migration because `user_devices` already had an `otp` trust method and
`otpVerifiedAt`. Those record an outcome, not a challenge: there was nowhere for
the code hash, attempts, sends, cooldowns, expiry, delivery outcome or
idempotency key. Two additive tables.

HMAC-SHA256 keyed by a configuration pepper, challenge id mixed in,
constant-time comparison, all from `node:crypto`. `OTP_PEPPER` has no default:
absent means OTP refuses, never OTP-with-a-guessable-hash. Delivery is
synchronous and honest — nothing claims a send that did not happen.

### CP4 — Tests (backend `6192fd8`)

64 new tests. Notably: 400 draws to prove leading-zero codes survive (a naive
implementation formats through a number and silently turns `000123` into `123`);
three concurrent correct submissions yielding exactly one success; and an
assertion that the code, hash, pepper and full phone number are all absent from
audit metadata.

- **Files changed:** backend — `prisma/schema.prisma`,
  `prisma/migrations/0025_otp_challenge_and_intent/`, `src/messaging/*` (new),
  `src/auth/otp/*` (new), `src/auth/auth.module.ts`, `src/app.module.ts`,
  `src/common/config/{env.validation,app-config.service}.ts`, `.env.example`.
  Mobile — `app/settings.tsx`, `lib/i18n/{en,ar}.ts`. Docs — `docs/23`,
  `CURRENT_HANDOFF.md`, `SESSION_LOG.md`.
- **Database migrations:** `0025`. Backup taken first:
  `~/erp-backups/phonestore-20260806-163400.sql` (196 144 bytes, `--hex-blob`,
  0 raw `_binary`, 1542 hex literals, valid UTF-8).
- **Tests and results:** **41 suites / 454 tests passing.** Backend and mobile
  `tsc` clean; `expo lint` clean; `migrate status` clean, 24 migrations.
  Migration-only deploy preserved 6 users / 76 sessions with no seed; reruns
  changed nothing; clean DB produced 52 tables; MySQL itself proved the
  `active_key` uniqueness semantics.
- **Live verification:** backend starts healthy with no pepper and no provider;
  `device_unrecognized` still blocks; nothing in the login flow references the
  OTP services. **No fixtures created, no audit rows added, no financial or
  inventory data touched.**
- **Commits:** mobile `e936e4e` · backend `7337b10`, `f987380`, `6192fd8` ·
  documentation: *current HEAD contains this handoff*.
- **Push status:** all three pushed and level with `origin/master`.
- **Remaining work / unresolved decision:** **Stage 4B is blocked on choosing a
  WhatsApp Business provider.** Separately, **revoked-device recovery semantics
  are an open product decision** — who may restore a revoked device, on what
  evidence, and whether an Owner may do it for an employee. That purpose was
  deliberately left out of the OTP enum rather than invented.
- **Handoff reason:** authorised task complete. `READY_FOR_HANDOFF`, owner `NONE`.

---

## 2026-08-06 15:20–16:05 UTC — CLAUDE-B (F1 Stage 3.2 — Store Account ID + bypass fix)

- **Starting state:** resumed after F1 Stage 3.1. Reconciliation matched the
  expected state exactly — backend `8a5ee5c`, mobile `2188a34`, docs `fba767e`,
  migration `0023`, 37/377, all clean/level with their remote-tracking refs.
  GitHub was briefly unreachable at the very start (`git fetch` failed) but
  recovered before the first commit; every checkpoint below pushed cleanly.
- **Authorised task:** F1 Stage 3.2 — close the mobile fail-closed bypass and
  introduce the approved public Store Account ID as the pre-login tenant
  identifier. No OTP work. Four focused checkpoints, committed in order.
- **CP1 — mobile bypass removed (mobile `da34e1f`).** Stage 3.1 had `signIn`
  catch `device_unrecognized`, delete the stored credential, and retry without
  it — silently re-enrolling a trusted device from a claim the server had failed
  closed. Removed entirely: the error now propagates untouched (credential
  KEPT), and the login screen shows a blocking, translated "device needs
  verification" state (EN/AR, RTL) with no fake actions; only a network error is
  retryable. The decision is a pure module (`sign-in-decision.ts`) guarded by a
  Node-run test (no test runner / no new dependency).
- **CP2 — Store Account ID + auth contract (backend `044234b`, migration
  `0024`).** `companies.public_store_id`: a 10-char uppercase-hex, human-typable,
  NON-secret, unique, immutable code (no O/0, I/1, L/1 confusion). Backfilled
  collision-free from `SHA2(id)`, then NOT NULL + UNIQUE; new companies get a
  random code (unique-index backstop); seed sets it on create only. Login is now
  `{ storeAccountId, login, password, device? }`: resolve the company from the
  public code (never a client binary id), find the user WITHIN it
  (`findByLoginForAuth` is company-scoped), verify the password. Bad Store ID /
  login / password fail identically (`401`, no code) and every path spends an
  Argon2 verify (`verifyDummy`) so timing cannot enumerate; the device credential
  is evaluated only after primary auth. Backup taken first
  (`phonestore-20260806-152840.sql`). Migration-only deploy proven on a restored
  scratch DB (no seed): 0024 applied alone, all rows preserved, guarded backfill
  rerun → 0 rows; empty-DB run created the column+index.
- **CP3 — mobile Store ID login + scoped key + legacy migration (backend
  `6fde7bb`, mobile `fca89f4`).** Backend adds `publicStoreId` to login/refresh/
  `me` responses so both login and cold-restore key by the SAME canonical value.
  Mobile: a Store ID field (EN/AR, RTL, remembered as a non-secret); the
  SecureStore key is `env + storeId + login` (pure `device-key.ts`, Node-tested);
  a one-time idempotent legacy migration moves `erp.device.<login>` into the
  scoped key using the Store ID from the user's OWN session, writing the new key
  before deleting the old so a failed write loses nothing, never crossing
  companies. A logged-out legacy user presents the old credential once — the
  server migrates it if recognised, or fails it closed (blocking state, old key
  kept), never a silent enroll.
- **CP4 — docs + verification (this entry).** docs/23 gains the Stage 3.2 auth
  contract and marks the earlier company-ambiguous-key finding RESOLVED; docs/21
  connects the approved Store ID to login. A `backend` entry was added to
  `.claude/launch.json` (the other session's dev server was down).
- **Files changed:** backend — `prisma/schema.prisma`, migration `0024`,
  `prisma/seed.ts`, `src/common/utils/store-code.util.ts`(+spec),
  `src/common/security/hashing.service.ts`, `src/users/users.service.ts`,
  `src/auth/{auth.service,auth.controller,dto/login.dto}.ts`, `auth.service.spec`.
  Mobile — `lib/{sign-in-decision,device-key,device}.ts`(+ two Node tests),
  `hooks/useAuth.tsx`, `app/(auth)/login.tsx`, `lib/i18n/{en,ar}.ts`,
  `types/api.ts`, `tsconfig.json`. Docs — `docs/21`, `docs/23`,
  `CURRENT_HANDOFF.md`, `SESSION_LOG.md`, `.claude/launch.json`.
- **Tests:** backend **38 suites / 390 tests**; backend + mobile TS clean; expo
  lint clean; migrate status up to date. Mobile pure guards 6 + 7 (Node).
- **Live verification** (own backend on :3010, temp company B, then clean): same
  login `owner` @ Store A vs Store B → own company each; wrong password / Store ID
  / foreign login → 401 no code; valid returning device recognised; wrong secret,
  cross-company credential, and revoked device → 401 `device_unrecognized`; no
  device-row growth; `/auth/me` returns `publicStoreId`. 12/12. Temp company B +
  users deleted, A-owner test devices/sessions deleted; companies 1, users 6,
  `user_devices` 0, demo store `F62B8D1EEB`. **+1 append-only `audit_logs` row.**
- **Commits:** mobile `da34e1f`, `fca89f4`; backend `044234b`, `6fde7bb`; docs
  `916f50b` (ownership) + this entry. All pushed; trees clean and level with origin.
- **Remaining / next decision:** Stage 4 OTP — now blocked ONLY on the WhatsApp/
  OTP provider choice (the device-key auth-contract change is done). Stage 4 needs
  a fresh backup + an additive OTP-challenge migration.
- **Handoff reason:** Stage 3.2 complete and verified; `READY_FOR_HANDOFF` / `NONE`.

---

## 2026-08-06 03:55–04:23 UTC — CLAUDE-B (F1 Stage 3.1 — device-security hardening)

- **Starting state:** resumed after CLAUDE-A's F1 Stage 3. Reconciliation matched
  the expected state exactly — backend `91bbb44`, mobile `e5b7db6`, docs
  `647beea`, migration `0023_device_identity`, 36 suites / 367 tests, all trees
  clean and level with origin, `READY_FOR_HANDOFF`/`NONE`.
- **Authorised task:** F1 Stage 3.1 hardening — no OTP work.
- **Incorrect-secret root cause + fix:** `auth.service.login` treated
  `recognise() == null` (wrong secret / unknown id / revoked / wrong user)
  identically to "no credential" and **enrolled a new trusted device**, so a
  failed claim minted trust and repeated claims grew the device table without
  bound. Rewrote the decision tree, evaluated **before a session exists**: A (no
  credential) → enroll; B (valid pair) → recognise+attach; **C/D/E and any
  partial pair → fail CLOSED** with a controlled `401 { code: device_unrecognized }`
  — no session, device, secret, rotation or `lastLogin`. The global exception
  filter now passes a machine `code`; pino redaction gained
  `req.body.deviceCredential.deviceSecret`.
- **Multi-company key:** the mobile stores the device credential under
  `erp.device.<login>`, and login is unique only within a company. **No company
  identifier is known before login**, so a collision-free key needs an
  auth-contract change — reported precisely in docs/23 (a pre-login company/store
  id, then `env+companyKey+login`), and the ambiguous key was left as-is rather
  than swapped for another. To stop the new fail-closed path from locking out a
  stale/foreign credential, `signIn` now forgets a rejected credential and
  re-enrolls once; ApiError carries the `code`. Logout now **keeps** the device
  credential (clears only session material), so `reverifyRequired` governs the
  same device.
- **Secret exposure:** re-verified end to end — raw secret only on a genuine
  enroll/adopt; never in lists, idempotent adopts, audit rows or errors; only the
  Argon2id hash in the DB; owner routes never expose employee secrets; the
  exception body cannot serialize the submitted credential.
- **Stage 4 correction:** retracted the docs claim that Stage 4 needs no schema
  change. A secure OTP system needs a durable **OTP-challenge** table (purpose,
  target, destination snapshot, hashed code, expiry, attempts, states, resend,
  idempotency); the `otp` enum value + `otpVerifiedAt` are only the outcome.
  docs/23 and CURRENT_HANDOFF now say Stage 4 requires a fresh backup + an
  additive migration.
- **Files changed:** backend `src/auth/auth.service.ts` (+spec),
  `src/common/filters/all-exceptions.filter.ts`, `src/app.module.ts`; mobile
  `lib/api-client.ts`, `hooks/useAuth.tsx`, `lib/device.ts`; docs `docs/23`,
  `CURRENT_HANDOFF.md`, `SESSION_LOG.md`. **No migration.** docs/21 unchanged (no
  product decision changed — the fail-closed behaviour implements the existing
  OTP-for-new-device decision).
- **Tests:** backend **37 suites / 377 tests** (+`auth.service.spec.ts`, 10,
  incl. 20 repeated claims → 0 device rows). Backend TS clean, mobile TS clean,
  expo lint clean, `migrate status` up to date.
- **Live verification** (:3010, three throttle-aware runs, DB restored clean):
  A/B/C/D/E, repeated-claims-no-growth, own + Owner + employee device lists (no
  secrets), employee 403, cross-user (faithful cross-company) fail-closed, and
  logout keeping recognition without lock-out — all pass. Fixtures removed;
  `settingsprobe` restored from backup to `is_active = 0`; **+1 append-only
  `audit_logs` row** (the E revoke).
- **Commits:** backend `8a5ee5c`; mobile `2188a34`; docs `42f82e2` (ownership) +
  this entry. All pushed.
- **Remaining / blockers:** Stage 4 OTP — blocked on a provider choice AND the
  auth-contract decision for the device key; both recorded. No mobile test runner
  (deferred, needs approval) → mobile verified by tsc + expo lint + the backend
  live cross-user check.
- **Handoff reason:** Stage 3.1 complete, verified and pushed; `READY_FOR_HANDOFF`
  / `NONE`. Next (Stage 4) is not authorised.

---

## 2026-08-06 02:00–03:10 UTC — CLAUDE-A (F1 Stage 3)

- **Starting state:** `READY_FOR_HANDOFF` / NONE. Verified after `git fetch`:
  backend `7047c93`, mobile `80bc285`, docs `8999d36`, all clean and level;
  migration `0022`; 34 suites / 327 tests; 0 delegated grants. Matched the
  expected state exactly.
- **Authorised task:** close the remaining Stage 2 lifecycle risk, then F1
  Stage 3 (device identity). Explicitly excluded: OTP/WhatsApp, invitations,
  recovery, passcode, biometrics, seats, price editing.

### Stage 2 lifecycle risk — closed (backend `0db0fc4`)

Audited every path that can change a role, remove an assignment or deactivate a
user. **No role-management API exists**: only `prisma/create-user.ts` (whose
upsert doubles as a role changer) and the seed's legacy remap touch
`user_branches`, and nothing anywhere deletes an assignment.

The CLI did not prune delegated grants, so downgrade → re-promotion would have
silently restored `price.edit`. The rule now lives in
`src/rbac/delegation-lifecycle.ts`, is used by the CLI inside the same
transaction as the role change, and is required of any future role API. Tests
demonstrate **both** halves, including the failure itself: a stale row genuinely
does revive on re-promotion when pruning is skipped, which is why resolution
alone is not enough. Cascade re-verified on the live database.

### Stage 3 audit gate — passed

Audited `AuthSession`, every create/rotate/revoke path, token binding, the old
`deviceId`, mobile storage, dependencies, and all auth consumers.

The gate question was whether safe device identity needs OTP first. It does not:
enrollment happens on an **already-authenticated** session, and the trust method
is recorded honestly rather than claimed as verification. **No blocker.**

One finding shaped the whole design: because the credential is **server-issued**,
the client only stores what it is given — so **no new mobile dependency was
needed**. `expo-secure-store` was already installed.

### Stage 3 implemented (backend `91bbb44`, mobile `e5b7db6`, migration `0023`)

Rejected the original plan's "client-generated deviceId": a client-generated
identifier is a claim, not a credential. Shipped instead: server-issued public
id + 32-byte secret returned **once**, stored only as an Argon2id hash. The id
alone recognises nothing. Scoped per (company, user). No IMEI, serial,
advertising id or fingerprinting.

Trust is `legacy` / `password` / `otp`, and **nothing in Stage 3 writes `otp`**;
`otp_verified_at` stays null. Explicit logout sets `reverify_required`; app
close, backgrounding and offline restore never reach that path. Revoking a
device revokes its sessions atomically, survives user reactivation, and keeps
the row as history.

Legacy sessions keep working — `device_record_id` is nullable and all 65 were
preserved — and adopt a legacy-trusted device once, idempotently.

- **Files changed:** backend — `prisma/schema.prisma`,
  `prisma/migrations/0023_device_identity/`, `prisma/create-user.ts`,
  `src/auth/{devices.service,devices.controller,auth.service,sessions.service,auth.module}.ts`,
  `src/auth/dto/{device,login}.dto.ts`, `src/auth/strategies/jwt.strategy.ts`,
  `src/common/types/auth-user.ts`, `src/rbac/delegation-lifecycle.ts`, + specs.
  Mobile — `lib/device.ts` (new), `hooks/useAuth.tsx`, `app/devices.tsx` (new),
  `app/(tabs)/more.tsx`, `types/api.ts`, `lib/i18n/{en,ar}.ts`,
  `lib/query-keys.ts`. Docs — `docs/23`, `CURRENT_HANDOFF.md`, `SESSION_LOG.md`.
- **Database migrations:** `0023_device_identity`. Backup taken first:
  `~/erp-backups/phonestore-20260806-022141.sql` (187 935 bytes, `--hex-blob`,
  0 raw `_binary`, 1494 hex literals, valid UTF-8).
- **Tests and results:** **36 suites / 367 tests passing.** Backend and mobile
  `tsc` clean; `expo lint` clean; `migrate status` clean, 22 migrations.
  Migration-only deploy proven on a temp database restored from the pre-`0023`
  backup: no seed, table created, column added, **65 sessions preserved**,
  reruns changed nothing.
- **Live verification:** enrollment, recognition, wrong-secret handling, list
  without secrets, revoke other / current / idempotent, revoked-credential
  re-enrollment, logout marking, lifecycle neutrality, employee isolation,
  Owner list/revoke, cross-user 404. Fixtures removed; demo data untouched;
  3 append-only audit rows remain (total 91).
- **Commits:** backend `0db0fc4`, `91bbb44` · mobile `e5b7db6` ·
  documentation: *current HEAD contains this handoff*.
- **Push status:** all three pushed and level with `origin/master`.
- **Remaining work:** Stage 4 (OTP) is blocked on provider choice. Real-device
  checks still outstanding.
- **Handoff reason:** authorised task complete. `READY_FOR_HANDOFF`, owner
  `NONE`.

**CORRECTION (2026-08-06, CLAUDE-A):** the commit message of backend
`91bbb44` is missing three words. Backticked `password`, `legacy` and `otp`
were consumed as shell command substitution when the message was composed, so
one paragraph reads "Trust is recorded honestly.  means a password was
verified…". The commit content is correct and unaffected. It was **not**
amended, because it was already pushed and the protocol forbids force-pushing;
the enum values it should have named are `password`, `legacy` and `otp`.

---

## 2026-08-06 00:05–01:40 UTC — CLAUDE-A (emergency takeover)

- **Starting state:** Authorised takeover from CLAUDE-B, which hit its five-hour
  limit mid-implementation. Verified after `git fetch`: backend `a7ff563`,
  mobile `2e63aa8`, docs `8115067`, all level with `origin`; migration `0021`
  applied; `prisma migrate status` clean; 18 permissions with `price.edit`
  mapped to Owner only; **0** rows in `user_branch_permissions`; the pre-`0021`
  backup on disk. CLAUDE-B's handoff was **interrupted** — still
  `IN_PROGRESS / CLAUDE-B`, and its "in progress" section was stale (it called
  Stage 2 blocked at the audit gate, while `cfa2dc8` and `a7ff563` show the gate
  resolved and the core landed).
  **Discrepancy against the takeover brief:** it listed two uncommitted files;
  there were **three**. Mobile `lib/permissions.ts` was also modified (adding
  `price.edit` to the client catalogue). Coherent with the backend, so it was
  preserved, not reverted. Every other stated fact verified exactly.
  The backend tree **did not compile** at takeover: `user-management.service.ts`
  imported `./dto/grant.dto`, which did not exist.
- **Authorised task:** finish F1 Stage 2 — deployment-only `price.edit`
  correction, grant/revoke API, regression tests, Owner Team control.
- **Work completed:**
  - Took ownership in the handoff before touching anything else.
  - **Deployment gap (`0022`).** `0021` created the delegation table, but the
    `price.edit` **row** is reference data and `migrate deploy` never runs the
    seed — the same hole D2.1 fixed for store roles. New migration, guarded on
    the stable KEY (the dev database already held a hand-generated id), Owner
    only. `0021` was **not** edited. Drift tests extended so SQL and TypeScript
    cannot diverge.
  - **Grant/revoke API.** Finished CLAUDE-B's edit rather than rewriting it; its
    direction was right. Dropped only the speculative `GrantDto` import — the
    shipped contract names the authority in the route path, so there is no body
    field a client could put `discount.override` into.
  - **Regression tests**: a new delegation spec, plus the Owner/fail-closed/
    next-request cases the resolver spec was missing.
  - **Mobile**: one switch per managed branch, EN/AR, RTL-safe, confirmation,
    409/403/offline handling, prefix query invalidation.
  - Verified the mobile cold-start path still works after the no-branch
    hardening: permissions are only requested once a branch exists, and the
    Owner keeps company-scoped permissions without one.
- **Decisions made by the user:** authorised the takeover; authorised finishing
  Stage 2; forbade starting Stage 3, OTP/WhatsApp, invitations, passcodes,
  actual price editing, below-cost delegation, seats, technician, Returns/Loans/
  Consignment.
- **Files changed:** backend — `prisma/migrations/0022_price_edit_permission_backfill/`,
  `src/rbac/role-matrix-drift.spec.ts`, `src/rbac/access.service.spec.ts`,
  `src/users/user-management.service.ts`, `src/users/users.controller.ts`,
  `src/users/user-management.service.spec.ts`, `src/users/price-edit-delegation.spec.ts` (new),
  `src/common/tenant/tenant-context.service.ts`. Mobile — `app/team.tsx`,
  `types/api.ts`, `lib/i18n/{en,ar}.ts`, `lib/permissions.ts`. Docs — `docs/23`,
  `CURRENT_HANDOFF.md`, `SESSION_LOG.md`.
- **Database migrations:** `0022_price_edit_permission_backfill` applied to the
  shared database (a no-op there by design — `price.edit` already existed).
  Backup taken first: `~/erp-backups/phonestore-20260806-005021.sql`
  (186 087 bytes, `--hex-blob`, 0 raw `_binary`, 1479 hex literals, valid UTF-8,
  trailer present).
- **Tests and results:** **34 suites / 327 tests passing.** Backend and mobile
  `tsc` clean; `expo lint` clean; `prisma migrate status` clean, 21 migrations.
  Migration-only deploy proven on a temp database restored from the pre-`0021`
  backup via the DEFINER-safe path: no seed, `0021` table with `CASCADE`,
  `0022` `price.edit` on every Owner and nobody else, per-role counts identical
  to the seeded database, rerunning the SQL twice changed nothing.
- **Live verification:** Owner grant/revoke 200 and idempotent; the manager's
  branch-A permission set changed by **exactly one key** on the next request
  with the same token; branch B and the no-branch path unaffected; non-Owner and
  Store-Employee calls 403; granting to an employee assignment 409; forged
  branch, non-uuid branch and unknown user all 404; `discount.override` still
  Owner-only. Temporary `f1probe` fixture and `prisma_f1_deploy` database both
  removed; users back to 6, assignments to 11, grants to 0; no financial or
  inventory record touched. **3 append-only `audit_logs` rows** remain from the
  grant/revoke tests (total 88) — legitimate records of real operations.
- **Commits:** backend `0b6cbd9` (0022 + drift tests), `7047c93` (API + tests) ·
  mobile `80bc285` (Team control) · documentation: *current HEAD contains this
  handoff*.
- **Push status:** all three pushed to `origin/master` and level with their
  remotes.
- **Remaining work:** none for this task. Real-device checks (camera, haptics,
  Arabic RTL end-to-end, receipt sharing, scroll pagination, bottom sheets) are
  still outstanding, as is everything from Stage 3 onward.
- **Handoff reason:** authorised task complete. `READY_FOR_HANDOFF`, owner
  `NONE`.

---

## 2026-08-05 23:04–23:40 UTC — CLAUDE-B (session 3)

- **Starting state:** resumed own work. All three repos clean, `master`, level
  with remote: backend `564b3b9`, mobile `2e63aa8`, docs `5ba0e01`. Migration
  `0020` applied, up to date. Handoff `READY_FOR_HANDOFF` / NONE. Matched the
  expected takeover state exactly. (The prompt's "take ownership as CLAUDE-A" was
  a user typo, confirmed in chat — this account is CLAUDE-B.)
- **Authorised task:** F1.1 deactivation/session hardening; then the Stage 2
  branch-authorization audit (hard gate) and Stage 2 only if the gate passes.
- **F1.1 — completed.** Audit found two gaps: the JWT strategy never checked
  `is_active` (a deactivated user's access token worked until expiry), and
  deactivation did not revoke `auth_sessions` (so a deactivate→reactivate cycle
  revived the refresh token). Fix: access tokens now carry `sid` and every
  request revalidates the session (not revoked/expired) + user (active, not
  deleted); deactivation atomically sets `is_active=false` AND revokes all the
  user's active sessions. Reactivation does not un-revoke → fresh login required.
  Tenant-safe, self-deactivation still blocked, no hard delete, audit records the
  revoked-session count but no secret. Contact normalization confirmed (email
  trim+lowercase at the DTO; phone/email change resets only its own timestamp).
  Restored `settingsprobe`'s original password hash from the pre-test backup.
- **Files changed (F1.1):** `src/common/types/auth-user.ts`,
  `src/auth/{tokens,sessions,auth}.service.ts`, `src/auth/strategies/jwt.strategy.ts`,
  `src/users/user-management.service.ts`, + specs `jwt.strategy.spec.ts`,
  `sessions.service.spec.ts`, extended `user-management.service.spec.ts`.
- **Tests:** backend **32 suites / 286 tests** (was 30/266; +20). `tsc` clean.
  Live-verified the full 6-step lifecycle on :3010 (11/11): session-bound token,
  deactivation→access 401 + refresh 401, reactivation keeps old tokens 401,
  fresh login works, self-deactivation 400. Demo left clean.
- **Commits:** backend `318ea81` (pushed). Docs: this entry + handoff update.
- **Stage 2 — NOT started. The branch-authorization gate FIRED.**
  `getEffectivePermissions` unions permissions across all `UserBranch`
  assignments when no `X-Branch-Id` is present (the branch-scoped path is sound
  and validates assignment). Building delegated grants on the union would leak a
  branch-A grant company-wide. Per instruction, stopped before the migration and
  reported, with a recommended safe design (grants resolved only branch-scoped,
  excluded from the union; price endpoints must require `X-Branch-Id`).
- **Handoff reason:** F1.1 shipped green; Stage 2 blocked at the mandatory audit
  gate awaiting a user decision on the resolution approach. No schema change made.

---

## 2026-08-05 21:31–22:05 UTC — CLAUDE-B

- **Starting state:** Took over from CLAUDE-A. All three repos clean, `master`,
  level with remote: backend `ea22df1`, mobile `2d6f49b`, docs `63b4657`.
  Migration `0019` applied, `migrate status` up to date, no `prisma_*` temp DBs.
  Live data reconciled against the handoff with **zero discrepancies** (6 users,
  5 active / 1 inactive `settingsprobe`; assignments owner 4, store_employee 7;
  sole login identifier `login`, unique `(company_id, login)`; no phone/email).
- **Authorised task:** (1) Make the shared handoff protocol enforceable in every
  `CLAUDE.md`. (2) Execute **F1 Stage 1 only** — contactable user foundation.
- **Work completed:**
  - Added the enforceable-protocol fields (read recent SESSION_LOG; take
    ownership only when `READY_FOR_HANDOFF`; record Owner/`started_at_utc`/all
    three HEADs/phase-scope at start; `READY_FOR_HANDOFF` only when clean+pushed)
    to all three `CLAUDE.md` within the existing markers — no duplicated section,
    canonical files still only in erp-docs.
  - Schema `0020_user_contact_fields`: nullable `phone` (E.164), `email`,
    `phoneVerifiedAt`, `emailVerifiedAt` + `@@unique([companyId, phone])`.
    Generated with `migrate diff` (schema-to-schema, no shadow DB — the migrator
    is denied on `phonestore_shadow`) and applied with `migrate deploy`.
  - Owner-only Users API (`GET/GET:id/PATCH /v1/users`, `user.manage`,
    tenant-scoped, no hash exposure, derived status, contact-change resets
    verification, no hard delete, no self-deactivation, no role field).
  - Mobile Team screen (EN/AR, RTL, permission-gated; status colour+words; edit
    sheet; no invite/OTP/passcode buttons) + `user` status registry entry.
- **Decisions made by the user:** account label CLAUDE-B; execute Stage 1 only,
  then stop. **Decisions taken by CLAUDE-B (unspecified in docs/23):** email not
  unique in Stage 1; `pending_contact` derived not stored; E.164 without
  `libphonenumber`. Recorded in `docs/23` Stage 1 and the handoff.
- **Files changed:** docs — `CLAUDE.md`, `CURRENT_HANDOFF.md`, `SESSION_LOG.md`,
  `docs/23`. Backend — `prisma/schema.prisma`, `prisma/migrations/0020_*`,
  `src/users/{users.controller,user-management.service,contact.util}.ts`,
  `src/users/dto/update-user.dto.ts`, two specs, `users.module.ts`. Mobile —
  `app/team.tsx`, `app/(tabs)/more.tsx`, `types/api.ts`, `lib/query-keys.ts`,
  `lib/design/status.ts`, `lib/i18n/{en,ar}.ts`.
- **Database migrations:** `0020_user_contact_fields` applied via `migrate deploy`.
  Fresh `--hex-blob` backup taken and verified first:
  `~/erp-backups/phonestore-20260805-213342.sql` (178 854 bytes, trailer present,
  0 raw `_binary`). Post-migration: 6/6 users preserved, assignments intact,
  index NON_UNIQUE=0. No `prisma migrate reset`; no temp DB created.
- **Tests and results:** backend `npx jest` **30 suites / 266 tests** (was 28/235;
  +31). Backend `tsc` clean, mobile `tsc` clean, `expo lint` clean.
- **Live verification:** against the running backend on :3010 (shared DB,
  reversible). No-token 401; owner 200 with 6 users and no hashes; phone
  normalized to E.164 with `phoneVerifiedAt` null; duplicate 409; invalid 400;
  self-deactivation 400; revert to null; employee `store_employee` GET/PATCH 403.
  Demo left clean (0 phones; `settingsprobe` restored to `is_active=0`). Net demo
  change: +6 append-only `audit_logs` rows and `settingsprobe`'s password reset.
- **Commits:** backend `5638a52`, `1991a01`, `564b3b9`; mobile `89466ed`,
  `2e63aa8`; docs `60f718c` + the commit carrying this entry.
- **Push status:** all pushed; all three level with `origin/master`.
- **Remaining work:** F1 Stages 2–8 unstarted (per-user grants, device identity,
  OTP/WhatsApp, invitations, passcode/biometrics, Users CRUD incl. role
  assignment, auditing/rate-limits). Real-device verification of the Team screen
  (camera not involved; RTL/haptics/scroll) still outstanding, as for all screens.
- **Handoff reason:** Stage 1 complete and verified; Stage 2 was explicitly out
  of scope. Status set `READY_FOR_HANDOFF`, active account `NONE`.

---

## 2026-08-05 21:05 — CLAUDE-A

- **Starting state:** All three repositories clean, on `master`, level with
  their remotes: backend `0940b41`, mobile `d9edbed`, documentation `641b787`.
  No uncommitted or untracked files anywhere. No temporary databases.
- **Authorised task:** Bootstrap a durable two-account handoff protocol.
  Coordination files and Git commits only — explicitly **no product feature
  work**.
- **Work completed:**
  - Discovered the three repositories and their remotes; identified the
    documentation repository as the **workspace root** (`erp-docs`), with
    `backend/` and `mobile/` nested inside its working tree but excluded by its
    `.gitignore` and tracked as separate repositories.
  - Verified the baseline from evidence rather than from the prior report:
    tests, both typechecks, lint, migration status, role and permission counts,
    demo-data counts, temporary databases, backups.
  - Rewrote `CURRENT_HANDOFF.md` into the shared protocol structure, preserving
    the valid content of the previous version.
  - Added the marker-enclosed shared protocol section to `CLAUDE.md` in all
    three repositories. `backend/CLAUDE.md` and `mobile/CLAUDE.md` did not
    exist and were created; the root `CLAUDE.md` was extended, not overwritten.
  - Recorded six corrections where reported state differed from actual state
    (appendix of `CURRENT_HANDOFF.md`).
- **Decisions made by the user:** Account label for this workspace is
  `CLAUDE-A`. The other account may continue at the five-hour usage limit.
  Bootstrap authorises coordination files and commits only.
- **Files changed:** `CURRENT_HANDOFF.md`, `SESSION_LOG.md`, `CLAUDE.md`
  (documentation repo); `CLAUDE.md` (backend, new); `CLAUDE.md` (mobile, new).
  No source file, schema file or migration was touched.
- **Database migrations:** None applied. Status inspected only:
  `prisma migrate status` → *"Database schema is up to date!"*, 18 migrations,
  latest `0019_settings_foundation`.
- **Tests and results:** Backend `npx jest` → **28 suites / 235 tests passing**.
  Backend `tsc --noEmit` clean. Mobile `tsc --noEmit` clean. `expo lint` clean.
- **Live verification:** None performed in this session — no behaviour changed.
  The Settings API and screen verification from earlier on 2026-08-05 still
  stands and is recorded in `CURRENT_HANDOFF.md`.
- **Commits:** backend **`ea22df1`** · mobile **`2d6f49b`** · documentation:
  *current HEAD contains this handoff* (see the note below).
- **Push status:** All three pushed to `origin/master`; all three level with
  their remotes afterwards.
- **Remaining work:** None for this task. No feature work was started, by
  instruction.
- **Handoff reason:** Bootstrap complete. Status set to `READY_FOR_HANDOFF`,
  active account `NONE`, awaiting an explicit user instruction.

*Note on the documentation commit hash: a file cannot contain the id of the
commit that introduces it, and adding a follow-up commit merely to record the
previous one creates an endless self-referential chain. The documentation
repository therefore records **"current HEAD contains this handoff"**; the
authoritative value is always `git -C <docs repo> log --oneline -1`. Backend
and mobile hashes are recorded exactly because they are committed first.*

---

## 2026-08-05 — E.1 backup hardening · E.2 withdrawn · F0 audit
**Owner:** Claude Opus 5 (agent session)
**Heads:** docs `307c453`, `125b798`, `fcb6e93`, + this entry · backend `0940b41` · mobile `d9edbed` (unchanged — E.2 shipped no code)

### E.1 — `--hex-blob` is now mandatory

The canonical `mysqldump` command gained `--hex-blob`, keeping
`--single-transaction --routines --triggers --events --no-tablespaces`.

Every id in this database is a `BINARY(16)` UUIDv7. Without the flag those are
written as raw bytes and **the dump file is not valid UTF-8**, so any ordinary
text tool that touches it silently replaces every primary key with `U+FFFD` —
the restore then succeeds and the damage only appears later as rows that no
longer join.

Proven on `phonestore-20260805-203646.sql` (178 854 bytes):

- 0 raw `_binary` literals, 1430 `0x…` literals, whole file survives a UTF-8
  round trip (the previous dump did not).
- Original still fails for the migrator with `ERROR 1227` — the DEFINER problem
  is untouched by `--hex-blob`, which is why the sanitiser still runs.
- Sanitised copy restored as the least-privileged migrator: **48/48 tables,
  2/2 triggers byte-identical, 12 representative row counts equal, `HEX(id)`
  checksums equal, `CHECKSUM TABLE` equal across all 48 tables**, Arabic text
  and en-dashes intact.
- Audit protection still executes: `UPDATE`/`DELETE` on `audit_logs` as
  `phonestore_app` both rejected with `ERROR 1644 (45000)`; 77 rows before and
  after.
- Temp database dropped, sanitised copy deleted, original never modified.

Sanitiser kept on `latin1` deliberately: legacy dumps still need byte-exact
handling, and `DEFINER=` can legitimately appear inside row data. Four new
tests cover the hex shape; 13 total, all green.

### E.2 — withdrawn: there was no BottomSheet bug

The previous session reported that `BottomSheet` never animates in on Expo web,
sitting at `translateY(720)` with the backdrop at `opacity: 0`.

**That was a measurement artifact.** In the automated browser pane
`document.visibilityState === 'hidden'` and a `requestAnimationFrame` loop
delivers **0 frames**. Reanimated drives web animations from rAF, so every
animation in the app is frozen at its initial value there — and those initial
values are exactly `screenHeight` and `0`, the two numbers reported as the bug.

An intermediate reading that appeared to show a fix was also unsound: the DOM
selector was matching an unrelated element.

**No change was shipped.** Speculative edits were reverted: the sheet is the
surface every picker, scanner and confirmation sits on, nothing was proven
broken, and there is no device or emulator here to check native behaviour
against. The false claim was removed from `docs/21`.

*Lesson worth keeping: before diagnosing an animation, confirm the page is
animating at all.*

### F0 — Users / auth / device-security audit (read-only)

No schema, API or screen touched. Written up in
[`docs/23`](docs/23_USERS_AUTH_AUDIT_AND_PLAN.md) with a dependency-ordered F1
plan in eight stages.

Headline findings:

- **Reusable and better than expected:** Argon2id throughout, rotating refresh
  tokens *with reuse detection that revokes the session*, per-device
  `auth_sessions`, permissions resolved from the database on every request (no
  roles in the JWT), and multi-branch membership with a role per branch.
- **`User` has no phone, no email and no verification state** — the OTP and
  recovery rules have nothing to attach to yet.
- **No per-user permission grant exists**, so "per-user price editing is
  Owner-delegated" is currently impossible to express.
- **`deviceId` is client-supplied, optional and never verified**, and the mobile
  client never sends it — so "new device" is not detectable today.
- **No OTP, invitation, passcode, biometric or recovery code exists at all.**
- **`login`/`logout` audit actions exist in the enum and are never written.**
- Rate limiting is per-IP only; there is no per-account lockout.
- The company auto-lock maximum **is** done (0019) and needs no rework.

### Documentation

- `docs/22` — `--hex-blob` section, revised sanitiser rationale, new drill record.
- `docs/21` — BottomSheet claim withdrawn with the evidence.
- `docs/23` — new: F0 audit + F1 plan.
- `CURRENT_HANDOFF.md`, `SESSION_LOG.md` — new; neither existed, and `CLAUDE.md`
  defines no handoff protocol.

---

## 2026-08-07 — CLAUDE-A — **Phase G2A-CP2: pricing schema and migration `0027`**

**Scope: schema only.** No API, no resolution service, no notifications, no
mobile UI, no CP3. Nothing reads the new tables yet, so there is no
half-enforced state.

**Backup first.** `~/erp-backups/phonestore-20260807-051508.sql` — `--hex-blob`,
`--single-transaction`, routines/triggers/events, no tablespaces; credentials
never printed or placed on a command line. Verified: 207 450 bytes, 0 raw
`_binary` literals against 1 622 hex literals, valid UTF-8, 52 tables, 2
triggers. The documented DEFINER-safe restore path was **proven before** the
migration was applied: restored into `prisma_g2a_pre` as 52/52 tables and 2/2
triggers, with the `units` `HEX(id)` MD5 `2a1dc9bf284afde32b402ad108d38a76`
byte-identical to live.

**Migration `0027_pricing_foundation`** (additive, after `0026`; no earlier
migration modified, squashed or regenerated). Three tables:
`branch_variant_prices` `UNIQUE (product_id, branch_id)` ·
`unit_price_overrides` `UNIQUE (unit_id)` **plus `branch_id`** ·
`price_change_events` append-only. `DECIMAL(14,2)` money, `BINARY(16)` UUIDv7
keys, `version INT DEFAULT 0` for compare-and-swap.

**The design correction.** CP1 proposed keying the unit override on `unit_id`
alone. That would let a price set by a Manager in Branch A follow the phone into
Branch B and take effect there under authority nobody granted. `branch_id` now
records the branch whose authority created the price — deliberately not an FK to
the unit's current location, because CP3 acts on exactly that divergence.

**What it does not do:** does not replace or mutate `Product.defaultPrice` ·
does not copy `defaultPrice` into any branch (an absent row must keep meaning
"fall back"; backfilling would invent prices nobody set and destroy the fallback
permanently) · adds no parallel quantity-price source, `StockItem.price` stays
authoritative · touches no existing table.

**Append-only is enforced by the database, not by service convention.**
`BEFORE UPDATE` and `BEFORE DELETE` triggers `SIGNAL SQLSTATE '45000'` when
`USER()` is the application account — the `audit_logs` pattern, except these
live inside the migration, so a fresh deployment gets them automatically instead
of depending on someone running an init script. Confirmed the migrator holds
`ALL PRIVILEGES`, so this is deployment-safe. Four CHECK constraints reject
negative money.

**Deployment proofs, all four passed.** Clean database: 55 tables, 3 pricing
tables, 2 pricing triggers, 4 CHECKs, 13 FKs, 26 migrations. Restored
pre-migration database: `0027` applied alone with the **seed never running**, 12
products / 11 units / 7 sales / 14 sale_items / 4 stock preserved, `bvp=0 upo=0
pce=0` proving no backfill, and `sum_total=10051.00` / `sum_item_price=9615.00`
identical to live. Dev database: applied, status up to date. Rerun: idempotent.
Append-only exercised as `phonestore_app` — **7/7**: read, insert, UPDATE
blocked, DELETE blocked, negative price rejected, history intact. Both temporary
databases **dropped**, probe rows removed, sanitized copy deleted.

**Tests.** Added `src/pricing/pricing-migration.spec.ts` — 20 tests asserting the
migration's contract (uniqueness, the override's `branch_id`, the FK to `units`,
CHECKs, both triggers, and that it never touches `products.default_price`,
`stock_items` or `sale_items`, never `INSERT`s and never `DROP`s). Deliberately
**not** Prisma-mock tests for database constraints — those were exercised against
real MySQL above, because a mocked constraint only tests the mock.

**Verification: backend 43 suites / 515 tests passing** (up from 42/495) · TS
clean · `prisma validate` valid · `prisma generate` regenerated (the
`EPERM query_engine-windows.dll` rename is the known WAMP lock from another
running dev server; the client was written and both tsc and the suite compile
against it) · migration status up to date, 26 migrations · mobile TS clean and
`expo lint` clean, confirming shared/generated types are unbroken.

**Recorded as unresolved, not approved:** the first quantity-stock receive lets a
**Store Employee** establish `StockItem.price` without holding `price.edit`.
Discovered in the CP1 audit, deliberately unchanged here — changing intake
behaviour is outside a schema phase. Three candidate resolutions are written into
`docs/21` §6 for the user to decide in **G2B**.

**Commits:** backend `167bbcf`; docs `b3409ac` (ownership correction + verified
backup) and the commit carrying this entry. Mobile unchanged (`65edca8`). All
three trees clean and level with `origin`. Status set to `READY_FOR_HANDOFF`,
owner `NONE`.

**Debugging note worth keeping.** Several migration-generation failures traced to
a single cause: piping `prisma migrate diff --script` through `tee … | head`
gives `tee` a SIGPIPE and silently truncates the file mid-statement, producing a
confusing "check query number N" error that looks like a SQL syntax problem.
Redirect to the file directly.

---

## 2026-08-07 — CLAUDE-A — **Phase G2A-CP3: pricing resolution and secure backend operations**

**Scope: backend only.** No mobile pricing UI, no G2B employee proposals.

### The CP2 trigger ambiguity was worth chasing — it hid a real gap

CP2 reported "2 triggers" on a clean database. That figure was truthful for what
it measured, and it concealed a genuine pre-existing defect. Live dev had 4
triggers; a clean database built from all 27 migrations had **2** — the pricing
pair only. The `audit_logs` guard lived solely in
`prisma/sql/init/10_audit_append_only.sql`, run by hand as root, in no migration.
Dev had it because someone ran that script once. **A fresh production deployment
would have shipped a fully mutable audit log**, and grants cannot substitute
because `partial_revokes` is schema-level only.

Repaired by `0028_audit_append_only_triggers` — additive, idempotent
(`DROP IF EXISTS` then `CREATE`), `0027` untouched. Verified 2→4 on a clean
database, 4→4 on a restored one, idempotent on rerun, and functionally as
`phonestore_app`: all four of `audit_logs` UPDATE/DELETE and
`price_change_events` UPDATE/DELETE rejected. The init script is kept but marked
superseded.

*(An earlier functional attempt reported false negatives: `SET col=col` is a
no-op MySQL skips, and `price_change_events` was empty so the subquery matched no
rows. Re-run with a real value change and a real row, all four blocked.)*

### Tenant recheck

FKs on the pricing tables are single-column, so the database alone permits a
mismatched `company_id`/`branch_id` pair. Closure is application-side and
complete: every query runs on the tenant-scoped client, writes state `companyId`
explicitly, ids from another company resolve to nothing and 404, and the branch
is verified against the caller's assignments. No corrective migration was needed
for this.

### Implementation

One `PricingService`. Resolution: `unit_override` → `branch_variant` →
`stock_item` (quantity only) → `product_default` → `unpriced`, always with an
explicit source. An override applies only when its branch, the unit's current
branch and the active branch all agree; otherwise it is reported as
`staleOverrideIgnored` and ignored. Product-level resolution structurally cannot
see an override.

Narrow API, no generic endpoint taking a model, field, permission or branch from
the body. Reads of the effective price open to any signed-in user; writes and
history require branch-scoped `price.edit`. Compare-and-swap on `version` with
409 on stale, and a lost create race translated from the unique key into
`refresh_required`. Below cost requires `discount.override` plus a reason,
expressed purely in permissions. Price change, history event, audit row and Owner
notification are one transaction. Notifications exclude the actor, which covers
both the manager and owner rules at once, and deduplicate multi-branch Owners.
Transfer invalidation runs inside the receive transaction and deletes the
override so a returning phone cannot resurrect it.

`transfers.receiveConfirm` is the only production path that changes
`Unit.branchId`; `cancel` writes the origin branch back to where the unit already
was, and that no-op is skipped.

`0029_stock_item_version` adds `version` to `stock_items`. `updatedAt` could not
serve: MySQL keeps microseconds, a JavaScript `Date` only milliseconds, so a CAS
on it would round-trip lossily and two writes in one millisecond are
indistinguishable. Faking it in application memory was the alternative and is
worse — it cannot see a concurrent writer.

`initiator` is recorded as `user` | `system` rather than CP2's sketched
`owner` | `manager`: `actorId` already says who acted, and a copied role drifts
from the real one. A third scope, `stock_item`, covers quantity changes.

### Two defects found by live verification, not by the suite

1. The active branch was parsed inside `PermissionsGuard`, which returns early on
   routes requiring no permission — so open reads had no branch and returned 400
   for a header the client had sent. Moved to the CLS middleware, which runs for
   every request.
2. That alone would have left open reads unchecked, since no permission means no
   guard means nothing verifies the branch. `PricingService.activeBranch()` now
   confirms the caller is assigned to the branch, for reads as well as writes.

### Verification

Backend **45 suites / 579 tests**, 0 failing (CP2 baseline 43/515; CP3 added 18
resolution tests, 42 service tests, and grew the migration contract to 24).
TypeScript clean, `prisma validate` valid, migration status up to date with **28
migrations**, latest `0029`. Mobile TypeScript and `expo lint` clean — no mobile
file changed; this only confirms shared/generated types still hold.

**Live: 55 checks, 0 failures** (30 + 25) against the running API and real MySQL,
covering per-branch and per-unit pricing, fallback reveals, 409s, delegated
authorization in one branch only, employee read-but-not-write, forged tenant
identifiers, below-cost refusal without revealing a cost, quantity pricing,
transfer invalidation including the shipped-but-not-received case and the
returning phone, append-only rejection from the application account, and
**completed sale totals, cost and margin unchanged after every price scope
change**.

Backups: `phonestore-20260807-140256.sql` before `0028`,
`phonestore-20260807-141018.sql` before `0029`; both verified and the DEFINER-safe
restore proven before migrating (55/55 tables, 4/4 triggers, identical `units`
checksum).

### Cleanup

Temporary users `cp3mgr` and `cp3emp` with their assignments, grants and
sessions; two stock transfers and items; all pricing rows — removed. The
accessory price touched by the quantity check restored to 19.00/version 0. Temp
databases `prisma_cp3_trig` and `prisma_cp3_pre` dropped. Demo data afterwards:
products 12, units 11 all back in Main Store, sales 7, `sum_total = 10051.00`,
stock 4, pricing tables empty — identical to the CP2 baseline.

**Deliberately retained:** `audit_logs` rows written by the verification
transfers. **Deliberately removed by the migrator:** the pricing
`price_change_events`, the `BranchVariantPrice`/`UnitPriceOverride` audit rows and
the `price.changed` notifications — permitted for a DBA account, recorded here
rather than left implicit. The transfer invoice sequence advanced by two and was
not rewound.

**Commits:** backend `159c4f3`, `72b8861`, `103588f`; docs the commit carrying
this entry. Mobile unchanged (`65edca8`). All three trees clean and level with
`origin`. `READY_FOR_HANDOFF`, owner `NONE`.

---

## 2026-08-07 — CLAUDE-B — **Phase G2A-CP4: mobile pricing experience**

**Scope: mobile only, plus one narrow backend fix the preflight forced.** No G2B
proposals. **No migration was needed and none was taken.**

### Takeover

Every check matched the brief exactly: backend `103588f`, mobile `65edca8`, docs
`82e74a6`, all clean and level with `origin`; latest migration `0029` (28 total);
backend 45 suites / 579 tests; four append-only triggers; `READY_FOR_HANDOFF`,
owner `NONE`.

### The preflight found a lock-out

CP3 moved active-branch resolution into CLS middleware, so the brief required
proving the no-branch auth routes still worked. They did — but the check
uncovered a different, pre-existing defect.

`CostGatingInterceptor` resolved permissions for the active branch and let
`AccessService`'s 403 escape. A restored session holding a branch the user had
since been removed from therefore failed **every** request, including
`GET /auth/branches` — the one screen needed to pick a different branch. The tab
bar's only control was Retry, which could only 403 again. No way back.

Cost gating decides what to *strip*, not who may call; guards run first and have
already rejected anything genuinely branch-scoped. It now degrades to the
strictest gating (no `cost.view`, strip everything) and deliberately does not
cache that set. It also no longer parses `X-Branch-Id` itself — the middleware
owns it, and two readers of one header is how they drift.

`/auth/permissions` still answers **403**, which is the honest answer to a
question about a branch the user cannot use. The client recovers instead: a 403
drops the branch and routing sends the user to the picker. That decision is a
pure `classifyPermissionFailure()` so it is testable without a store or network
— a 500, a 404 or being offline still keep the branch rather than discarding one
that is probably fine.

**Preflight: 24 checks, 0 failures.** Two early "failures" were my own test being
wrong, not the product: replaying an old refresh token correctly revoked the
session (reuse detection), and `/auth/permissions` returning 403 is intended.
Both were corrected rather than papered over.

### Mobile pricing

Contract audited from live responses before any UI was written — no guessed
shapes. `types/api.ts` now carries `EffectivePrice`, `UnitEffectivePrice`, the
three write bodies and the history page, with `PriceSource` documented as
server-owned.

The app renders the server's decision and never re-derives precedence. Sources
are translated into shop language in EN and AR with an explanation each, shown as
a labelled chip — words plus tone, never colour alone.

Product Details gained a Selling price section visible to every role; cost moved
to its own section, still "Hidden" rather than `0` when withheld. Edit controls
require branch-scoped `price.edit`: a delegated Manager sees them only in the
granted branch, an Employee sees none at all rather than disabled ones.

Two separate serialized actions — the model's branch price, and one phone's price
via `*#06#` and scanning the IMEI off the phone rather than the box, with manual
entry always available. Quantity products edit `stock_items.price` through the
`0029` version and never touch overrides.

One shared `PriceEditor` for all three scopes. `parsePrice` is a separate
dependency-free module with 11 Node tests, so blank, `NaN`, negative and
over-precise values cannot reach the API — `DECIMAL(14,2)` would silently
truncate the last of those. 409 explains what was tried versus what it now is and
stops; below cost stays the server's call and an Owner's authorisation resends
the same price and version. Invalidation is scoped to pricing, the product and
the branch's inventory, not the whole app.

### Verification

Backend **45 suites / 582 tests** (CP4 added 3 cost-gating regression tests),
TypeScript clean, migration status up to date at 28 migrations, **4 triggers**
still present. Mobile TypeScript clean, `expo lint` clean, **expo-doctor 18/18**,
`expo export --platform web` built **28 routes** including `/pricing/unit` and
`/pricing/history`. Node pure suites 11 + 5 + 6 + 7.

### What was NOT verified — stated plainly

No mobile UI was driven by a human or a device: no tapping through screens, no
camera scanning, no Arabic RTL rendering check, no per-role walk-through of the
client-side gating, and no re-run of Sell, Receive, Inventory or Notifications
through the app. Role behaviour and Sell's server-side resolution were proven at
the API level in CP3 and CP4 changed no authorization code, so that evidence
stands — but it is not the same as watching the app behave. A device pass is the
first item in the next action.

The **Notifications screen was not upgraded**; `price.changed` rows are created
correctly by the backend but render through whatever the existing prototype
provides. That milestone is recorded as still incomplete.

### Cleanup

The contract audit created 2 `price_change_events`, 2 `price.changed`
notifications and 2 pricing `audit_logs` rows, plus one branch price which was
removed through the API during the audit. The append-only rows were **removed by
the migrator account** — permitted for a DBA and recorded here rather than left
implicit. No temporary users, delegations or databases were created this session.
Demo data afterwards: products 12 · units 11 (all in Main Store) · sales 7 ·
`sum_total = 10051.00` · stock 4 · pricing tables empty · 4 triggers — identical
to the CP3 baseline.

**Commits:** backend `63cae31`; mobile `c2fc0a0` and `0d0d9a0`; docs the commit
carrying this entry. All three trees clean and level with `origin`.
`READY_FOR_HANDOFF`, owner `NONE`.

---

## 2026-08-07 — CLAUDE-B — **Phase G2A-CP4.5: pricing UI completion and verification**

**Scope: verify CP4 by running it, finish the Notifications minimum, write a
device checklist.** No G2B, no Transfers. No migration was needed or taken.

### Takeover

Matched the brief exactly: backend `63cae31`, mobile `0d0d9a0`, docs `d13de04`,
migration `0029` (28), backend 45 suites / 582 tests, four triggers, all clean
and level, `READY_FOR_HANDOFF` / `NONE`.

### The app was actually run

Expo web via the preview server, against the live API and the real database.
The browser pane stayed `visibilityState: hidden`, so synthetic clicks timed out
— the UI was driven with real DOM pointer events instead. That is strong
evidence for logic, text and state, and **none** for layout, which is stated
plainly rather than glossed.

Authenticating without typing a password into a form: a script logged in
server-side using the value already in `.env` and handed the page ephemeral
tokens. See the incident below for how that went wrong.

### Three defects that compilation could not find

**1. A sold phone could be priced.** The exact-phone screen offered "Change one
phone's price" for a sold unit, and the API accepted it with 200. CP4 required
refusing ineligible units; nothing enforced it. `setUnitOverride` now requires
`in_stock`, mirroring `SalesPolicyService.assertSellable` so that what you can
price and what you can sell cannot drift apart. Removal stays allowed so a stale
override can still be cleared after a sale. `getUnitPricing` returns `status` and
`canPrice`, and the screen explains instead of offering a doomed control.

**2. The stale-edit dialog quoted its own stale number.** A real race — a second
session moved a price to 1234 while an editor sat open on version 1 — produced a
correct 409 and a correct refusal to overwrite, but the message read "It is now
500 MRU", the snapshot the editor had opened with. That is the one number
guaranteed wrong in that sentence. It now re-reads the server first; re-verified
as "You tried 888 MRU. It is now 1 234 MRU."

**3. Notifications did not exist.** CP4 recorded the screen as "still a
prototype". There was no screen — only an unused query key — so the Owner
notification CP3 writes had nowhere to appear. That correction matters: the CP4
report understated it.

### What was driven through the UI

Branch price default → set → immediate re-render → update → remove → default
restored, with Warehouse visibly on 1 000 while Main Store showed 1 200 · Save
disabled until the value parses and differs · removal confirmation showing
"Without it: 1 000 MRU" · exact-phone override by manual IMEI · sold and unknown
identifiers refused clearly · quantity price edited with the version incrementing
and zero parallel rows · Owner below-cost reason dialog with blank reason blocked
and the reason landing in history · price history rendering · notifications list,
read state and action link · Arabic strings across the pricing section.

At the API with three real sessions, 28/28: Manager edits only the granted branch
while holding `catalog.manage` in both, is refused below cost with a count and
never a cost, and never holds `discount.override`; Employee reads prices, is 403
on writes and history, sees no cost field, and never receives the Owner's
notification.

### Notifications minimum

Backend: `listForUser` is now keyset-paginated returning `{ rows, nextCursor,
unreadCount }`, default 25 and clamped to 50. The old fixed `take: 100` was
bounded but could never reach anything older. 8 tests, no schema change.

Mobile: a bounded infinite list, unread shown in words plus tone, mark-as-read
through the existing endpoint, an action that follows the server's link, and
loading/empty/error/retry states. Reachable from More → Notifications. No push,
no provider, no preferences, no second model.

### ⚠️ Incident — session tokens briefly committed

The token file written for the browser lived at `mobile/public/cp45-session.json`
inside the repo, and a `git add -A` swept it into commit `7049ea4`; it was
removed in `55f52b0`. Both are pushed.

Mitigation: all sessions for `owner`, `cp45mgr` and `cp45emp` were revoked and
the committed tokens re-tested — **access 401, refresh 401**. They are dead.
History was deliberately **not** rewritten: the protocol forbids force-pushing
shared history, and invalidating the credential is the fix that matters. No
password, `.env` value or dump was ever committed.

The lesson, recorded so it is not repeated: work files belong in the scratchpad,
never inside a repository working tree.

### Verification

Backend **46 suites / 597 tests**, TypeScript clean, migration status up to date
at 28 migrations, **4 triggers**. Mobile TypeScript clean, `expo lint` clean,
**expo-doctor 18/18**, web export **29 routes** including `/pricing/unit`,
`/pricing/history` and `/notifications`. Node pure suites 11 + 5 + 6 + 7. EN and
AR both 556 keys with no gaps, extras or duplicates; every literal `t()` key
resolves; no `text-start`; no dead routes.

*Correction: commit `88e25bd`'s message claims "9 added / 591 tests". The true
figures at that point were 7 added and 589. Not worth rewriting pushed history.*

### Not verified, and not claimed

No physical device: camera scanning, haptics, keyboard avoidance, sheet gestures,
torch and clipboard are untested. Arabic **strings** render; Arabic **layout**
was not verified — no screenshot or animation evidence exists because the pane
was hidden throughout. Sell, Receive and Inventory were not re-driven through the
UI; their server-side behaviour was proven in CP3 and CP4.5 changed none of it.
`docs/24_DEVICE_QA_CHECKLIST.md` hands the rest to the user's own device.

### Cleanup

Temporary users `cp45mgr` and `cp45emp` with assignments, grants and sessions
removed; all pricing rows removed; the quantity price restored to 19.00/v0. The
append-only rows produced by verification (11 price events, 12 `price.changed`
notifications, 12 pricing audit rows) were **removed via the migrator account** —
permitted for a DBA and recorded here rather than left implicit. No temporary
databases were created. Demo data afterwards: products 12 · units 11 · sales 7 ·
`sum_total = 10051.00` · sale_items 14 · stock 4 at 19/20/20/15 all v0 · pricing
tables empty · 4 triggers — identical to the CP4 baseline.

**Commits:** backend `88e25bd`, `7adf598`; mobile `7049ea4`, `55f52b0`; docs the
commit carrying this entry. All three trees clean and level with `origin`.
`READY_FOR_HANDOFF`, owner `NONE`.

---

## 2026-08-07 — CLAUDE-B — **Phase H0: transfers truth and workflow audit (read-only)**

**No application code, schema, permission or transfer behaviour was changed.**
Documentation only, plus one rulebook addition. Ends blocked on the user's
workflow decisions, by design.

### Takeover

Matched the brief exactly: backend `7adf598`, mobile `55f52b0`, docs `c321550`,
migration `0029` (28), 46 suites / 597 tests, four triggers, clean and level,
`READY_FOR_HANDOFF` / `NONE`.

### Session-token incident — re-verified closed

The file is absent from every working tree and every current HEAD and is not
staged. `owner` sessions: 84 total, **0 live**. The tokens committed in `7049ea4`
were re-tested against the running API — **access 401, refresh 401, both dead**.
A value-free scan (searching history for the actual secret values without
printing them) found **no** JWT secret, seed password, or migrator/app database
password in any commit of any repository; the only `.sql` files ever added are
Prisma migrations. History was not rewritten, and the JWT secret was not rotated
— revoked session-bound tokens do not warrant it.

The requirement had been recorded only in narrative, which gets replaced. It is
now in `CLAUDE.md` as a rule: scratch and tooling files must live in an OS
temporary directory outside every repository, and a leaked credential is fixed by
invalidating it, never by force-pushing.

### Transfers as they actually are

Serialized units moving between branches of one company. `ready_to_ship →
in_transit → received | cancelled`. `draft`, `pending_approval` and `rejected`
appear in the enum as "future (design-only)" and were never built, so **there is
no approval step at all**.

**One permission guards the whole feature.** All five mutating routes use
`unit.transfer`, and all three roles hold it — Store Employee included. Proven
twice: from the role matrix in the database, and live by aiming each mutating
endpoint at a non-existent transfer id so the guard's 403-vs-404 answer was
unambiguous and nothing moved. An employee can create, ship, receive, confirm and
cancel. Branch assignment is the only real control, and it is enforced correctly
— ship and cancel require the source branch, receive requires the destination —
so an employee assigned to **both** branches can run a transfer end to end alone.

Reads (`GET /transfers`, `GET /transfers/:id`) carry no permission at all; they
are tenant-scoped, so no cross-company leak, but any signed-in user can browse
them.

### Three defects found by probing, not by reading

1. **Creating a transfer reserves nothing.** The unit stays `in_stock` and fully
   sellable — confirmed live, a unit inside an open transfer resolved with
   `status=in_stock, canPrice=true`. A promised phone can be sold underneath the
   transfer; the clash only appears later at `ship`.
2. **Two open transfers can claim the same unit** — the second create returned
   **201**. Nothing is reserved, so nothing objects.
3. **No idempotency anywhere.** A retried `POST /transfers` creates a second
   transfer. Sales solved this with a client `clientUuid` plus a company-scoped
   unique key; transfers has no equivalent. Duplicate identifiers inside one
   request are silently deduplicated and accepted rather than reported.

One probe (duplicate identifiers) returned 201 and created a real transfer, and a
second was created deliberately to test double-claiming. Both were removed along
with their items and audit rows; the invoice sequence was **not** rewound, per the
brief.

### Quantity stock

**Cannot be transferred at all.** The DTO accepts only IMEI/serial identifiers,
and no transfer path reads or writes `StockItem`. `TransferItem.productId` and
`quantity` exist in the schema and are dead columns. Recorded as a product gap,
so none of the quantity questions have an implementation to audit — they are
design decisions for the user.

### Verified intact

The CP3 pricing invariant: request and ship do not touch the override; receipt
invalidates it atomically with the branch move; the row is deleted so a returning
phone cannot resurrect it; history records `initiator='system'`,
`reason='branch_transfer'`. Cross-company destination fails closed with 404, same
branch 400, sold/unknown/wrong-branch units 400, deactivated user 401.

### Mobile

**No transfer UI exists** — no screens, no `/transfers` calls, only an unused
`qk.transfers` key plus transfer status labels and tones in EN/AR. Nothing to
classify as prototype or dead route; it is simply absent. The backend does emit
transfer notifications, which the CP4.5 Notifications screen now renders, and
tapping one currently has nowhere to go.

### Verification

Backend **46 suites / 597 tests**, TypeScript clean, migration status up to date
at 28 migrations. Transfers' own coverage is **6 tests in 2 files** — the
state-machine table and the discrepancy helper; there is no service,
authorization or lifecycle test. Mobile TypeScript clean, `expo lint` clean, Node
pure suites 11 + 5 + 6 + 7.

### Fixtures and cleanup

Three temporary **accounts** (`h0emp`, `h0mgr`, `h0dead`) were created for the
authorization probe — accounts only, no inventory or financial data — and
removed with their assignments and sessions. The two probe transfers and their
items and audit rows were removed. Demo data afterwards: products 12 · units 11 ·
sales 7 · `sum_total = 10051.00` · sale_items 14 · stock 4 at 19/20/20/15 all v0
· transfers 0 · pricing tables empty — identical to the CP4.5 baseline.

### Deliverable and stop

`docs/25_TRANSFERS_AUDIT_AND_DECISIONS.md`: real lifecycle and transition table,
permission matrix, atomicity and idempotency risks, serialized and quantity
behaviour, pricing interaction, mobile state, security findings, three workflow
options with Option A recommended, ten decisions needed, and a proposed H1 order
starting with reservation and idempotency — the one piece needed whichever
workflow is chosen.

**Stopped, waiting on the user.** H1 not started. Consignment explicitly out of
scope and must not reuse the transfer model.

**Commits:** backend and mobile **unchanged**; docs the commit carrying this
entry. `READY_FOR_HANDOFF`, owner `NONE`.
