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

---

## 2026-08-07 — CLAUDE-B — **H0 follow-up: transfer decisions recorded (documentation only)**

**No implementation.** H0's blocker is resolved; H1 is designed but not started,
because it changes schema and permissions and `CLAUDE.md` requires approval first.

### The four answers

| Decision | Answer |
|---|---|
| Who does what | **Option A** — Employee requests · Manager/Owner approves or rejects · source ships · destination receives · Manager/Owner cancels after shipment |
| No Manager present | **Owner approves remotely** |
| Quantity accessories | **Transferable — in H1** |
| Stock stops being sellable | **At request** |

Recorded in `docs/21` §6b (approved product decisions) and `docs/25` §8/§10/§11
(audit and plan). `docs/25`'s header no longer says "waiting"; Option A is marked
chosen and B and C marked not chosen.

### Making "Owner approves remotely" precise

It does **not** mean weakening branch scoping. Approval requires
`transfer.approve` **in the source branch**, and an Owner is assigned to every
branch, so they can approve by selecting that branch from anywhere. No
cross-branch escape hatch is needed and the branch rules that already work stay
untouched. Worth stating, because the loose reading of "remotely" would have been
a security regression.

### Two findings that change H1's size

**Serialized reservation is nearly free.** `UnitStatus.reserved` already exists
and is unused; `unit-state-machine.ts` already permits `in_stock → reserved` and
`reserved → in_stock`; and `SalesPolicyService.assertSellable` already requires
`in_stock`. So "stock stops being sellable at request" is enforced the moment
transfers start setting the status — no enum migration, no change to Sell.

*Caveat recorded for H1:* the state machine also allows `reserved → sold`, which
Sell refuses. Harmless today because nothing sets `reserved`, but the two should
be made to agree rather than left contradicting each other. And if
hold-for-customer is built later it must be distinguishable from a transfer
reservation — a reason column or a separate status.

**Quantity reservation has no primitive at all.** `StockItem` carries only
`quantity`. Decision 3 + decision 4 together require a `reservedQuantity` column,
and sellable quantity becomes `quantity − reservedQuantity` **everywhere stock is
checked, including Sell**. This is the largest single piece of H1 and the reason
H1.1 must come first.

### Two questions the answers surfaced, still open

- **Destination cost for quantity stock.** Moving 10 cables at 4.10 into a branch
  holding 5 at 5.00 needs a rule — weighted average, or carry the source cost. It
  changes margin, so it is a product decision, not an implementation detail.
- **Destination price for quantity stock.** Recommend the CP3 rule: the
  destination keeps its own price, else the company default, and never inherits
  the source's.

Neither blocks the schema, so both are listed for H1 design rather than asked now.

### Verification

Nothing was executed beyond documentation edits. Repository state unchanged from
H0: backend `7adf598`, mobile `55f52b0`, both clean and level with `origin`;
backend 46 suites / 597 tests; 28 migrations; four triggers; demo data at the
CP4.5 baseline.

**Commits:** backend and mobile **unchanged**; docs the commit carrying this
entry. `READY_FOR_HANDOFF`, owner `NONE`. **H1 not started.**

---

## 2026-08-08 — CLAUDE-B — **Phase H1.1: transfer reservation and idempotency**

Migration **`0030_transfer_reservation_and_idempotency`**. Closes both
stock-integrity defects the H0 audit proved live. **H1.2 not started.**

### Takeover

Matched the brief exactly: backend `7adf598`, mobile `55f52b0`, docs `8efff8e`,
migration `0029` (28), 46 suites / 597 tests, four triggers, clean and level,
`READY_FOR_HANDOFF` / `NONE`.

### Availability-consumer audit, before designing anything

Classified every production reader of `StockItem.quantity` and `Unit.status`
rather than replacing `quantity` globally:

- **Available-to-sell** (must subtract reserved): Sell's quantity check — the
  only one.
- **Physical** (must NOT subtract): receiving and purchase increments, the
  inventory `quantity > 0` filter, the analytics valuation SQL, the low-stock
  threshold. Reserved goods are still company-owned, so financial inventory
  value is deliberately unchanged by reservation — proven at the end.
- **Serialized eligibility:** `assertSellable` already required `in_stock`, so
  reserved units became unsellable with no change to Sell at all.

### Backup and legacy audit

`phonestore-20260808-035107.sql` — 55 tables, 4 triggers, 0 raw `_binary`, valid
UTF-8, financial tables present. DEFINER-safe restore proven **before** migrating:
55/55 tables, 4/4 triggers, `sum_total = 10051.00`, and units, sales and
stock_items ID checksums byte-identical to live.

Legacy audit found **nothing to reconcile**: zero transfers, zero items, zero
duplicate active claims, zero reserved or in-transit units. So `0030` could not
retroactively reserve a conflicting historical claim. Recorded because a
production database needs this rerun before deployment.

### What shipped

Reservation at request: `in_stock → reserved` inside the transfer's transaction.
One active claim, arbitrated by a compare-and-swap on the status — MySQL row-locks
the UPDATE until commit, so a concurrent request blocks, re-reads a `reserved`
row and matches nothing. Exactly one transaction can see the unit free; an
application-level "is it free?" read could never promise that.

Idempotency mirroring Purchase: mandatory `clientUuid` plus a payload fingerprint
under `UNIQUE (company_id, client_uuid)`. Identifier order normalised; duplicates
inside one request now **reported** rather than silently deduplicated, which had
made a miscount look like success.

`StockItem.reservedQuantity` with two CHECK constraints. `quantity` stays PHYSICAL
and is never reduced to express unavailability. Ship, receive and cancel all
compare-and-swap on the status they expect, so retries cannot move stock twice
and a cancel cannot release a unit claimed elsewhere.

State machine corrected: `reserved → sold` is now illegal, matching
`assertSellable`, which had always refused it.

### Two defects the live races found that reading the code had not

**Sell and a transfer request both returned 201.** Sell's unit status write was a
blind update, so a transfer reserved the phone between `assertSellable` reading it
and the write, and the sale stamped it `sold` anyway. The shop would have had a
phone simultaneously sold and promised to another branch, with both operations
reporting success. Sell now CLAIMS the unit with a compare-and-swap; re-verified
as sell 409 / transfer 201, unit ending `reserved`.

**A lost identical race reported a conflict for work that had succeeded.** The
loser of two concurrent identical requests can fail in two ways — the unique key,
or the reservation swap finding the unit already claimed by the winner running the
same request. Only `P2002` was handled. Both paths now return the winner's
transfer; re-verified as both callers receiving the same id.

Neither was visible in review. Only a real concurrent race showed them.

### Verification

Backend **47 suites / 607 tests** (H0 baseline 46/597; +10). TypeScript clean,
`prisma validate` valid, **29 migrations**, four triggers.

**Race suite 32/32** against the running API and real MySQL: request reserves ·
Sell refuses reserved · Pricing refuses reserved · a second transfer refuses ·
sequential replay · replay creates no second transfer · identifier reordering ·
cross-payload 409 · missing key 400 · cancel releases · **two concurrent claims,
one winner** · concurrent identical requests produce one transfer with one id ·
**Sell vs transfer, one winner** · ship retry 409 · receive retry 409 · unit
arrives once at the destination · quantity availability refuses over-selling and
allows within · physical falls while reservation holds · DB rejects negative
reservation, reserved above physical, and physical below reserved · valuation
unchanged by reservation.

Mobile: TypeScript clean, `expo lint` clean, EN/AR parity 557 = 557, Node suites
11 + 5 + 6 + 7. No Transfers UI built.

### Cleanup

All probe transfers, items and units restored; the race suite's `StockTransfer`
and `Unit` audit rows from 2026-08-08 removed via the migrator and reported here
rather than left implicit; earlier demo audit history untouched. Temporary
databases `prisma_h11_pre` and `prisma_h11_clean` dropped. Demo data afterwards:
products 12 · units 11 (3 in_stock, 8 sold) · sales 7 · `sum_total = 10051.00` ·
sale_items 14 · stock 4 at 52/90/90/15 all reserved 0 · transfers 0 · pricing
tables empty · 4 triggers. `units` and `sales` ID checksums identical to the
pre-migration backup.

### 🔴 Unresolved, recorded not approved

`unit.transfer` still guards request, ship, receive and cancel alike and all
three roles still hold it, so a Store Employee assigned to both branches can
still run a transfer alone. That is H1.2. Cancellation after shipment still
rewrites the unit's branch to source without proof it physically returned (H1.3).

**Commits:** backend `e40af13`, `b63e5c6`, `d3ea0c6`; mobile `84b5b84`; docs the
commit carrying this entry. `READY_FOR_HANDOFF`, owner `NONE`.

---

## 2026-08-08/09 — CLAUDE-B — **Phase H1.2: transfer permissions and serialized approval lifecycle**

Migrations **`0031`** and **`0032`**. Serialized only — quantity transfer
execution, partial receipt, proof photos and mobile UI remain future work.

### Takeover and H1.1 re-proof

Everything matched the brief: backend `d3ea0c6`, mobile `84b5b84`, docs
`01cfb1e`, migration `0030` (29), 47 suites / 607 tests, four triggers, clean and
level, `READY_FOR_HANDOFF` / `NONE`.

Before touching lifecycle behaviour I re-ran the H1.1 race suite against the
running API: **32/32**. No H1.1 invariant had regressed, so nothing needed
repair first.

### Why the split and the lifecycle had to ship together

Renaming permissions alone would either let employees ship unapproved requests,
or strand every employee request with nobody able to act on it. The brief was
right to combine them, and the point was proved twice during the work — see the
two defects below.

### The permission split

Six stable keys replaced the blanket `unit.transfer`, which guarded request,
ship, receive and cancel alike while all three roles held it. It now guards
**nothing** — zero production call sites, verified by grep — and is revoked from
both store roles. The permission record is kept because historical audit rows
reference it; the migration documents when deleting it becomes safe.

Owner holds all seven keys. Manager holds view/request/approve/ship/receive plus
both cancel keys. Employee holds view/request/ship/receive/cancel_own and
deliberately neither `approve` nor general `cancel`.

### The lifecycle

`pending_approval → approved → in_transit → received`, with `rejected` and
`cancelled` as terminal exits. Both pre-shipment states hold their units
**reserved**, so H1.1's guarantee still runs from the moment stock is promised
rather than from shipment.

Nothing leaves `in_transit` except `received`. Cancelling a shipment would mean
deciding where the goods physically are, and rewriting the unit back to source
would be a guess — return-to-source is future work, so the machine refuses rather
than inventing an answer.

A requester who already holds `transfer.approve` in the source branch creates an
**approved** transfer directly, flagged `auto_approved`. Making a manager approve
their own request would be ceremony, not control, and the flag stops the audit
trail showing an approved transfer with no approver.

Every transition carries `expectedVersion` through one compare-and-swap helper.
Reject and cancel release reservations in the same transaction as the status
change, scoped to the status they expect, so a retry cannot free a unit that has
since been claimed elsewhere. Both demand a non-blank reason.

`GET /transfers` and `/transfers/:id` now require `transfer.view` — they had **no
permission at all**, so any signed-in user could browse every transfer in the
company — and the list is scoped to the active branch's two ends.

### Two defects found by verification, not by the unit suite

**1. A manager could not cancel at all.** The cancel route is guarded on
`transfer.cancel_own`; `PermissionsGuard` requires ALL listed permissions; and
`0031` gave managers `transfer.cancel` but deliberately not `cancel_own`, on the
reasoning that the broad key supersedes the narrow one. Live verification proved
otherwise — the guard refused before the service could decide anything. Managers
could approve and ship but never cancel: precisely the "strand the workflow"
failure this phase exists to prevent.

The two keys do different jobs, and `0031` conflated them. `transfer.cancel_own`
is the **route** key (may reach the endpoint); `transfer.cancel` is the
**breadth** key (may cancel somebody else's). Guarding the route on the broad key
would lock employees out of withdrawing their own request; guarding on both locks
managers out. `0032` grants the route key to managers, so the route takes the
narrow key and breadth stays a service decision — which is what keeps the route
permission alone from widening into general cancellation.

**2. A broken build was pushed.** Commit `0026790` changed the `TransferStatus`
enum but left `transfer-state-machine.ts` and its spec on `ready_to_ship`, so
`tsc` failed on a pushed commit. Repaired in the very next commit (`04e1463`) and
recorded here rather than quietly amended — the push happened, and hiding it
would be worse than reporting it.

### Drift test, strengthened

The matrix comparison had to start subtracting revocations, or the revoked
`unit.transfer` read as drift. Fixing that exposed two reader bugs that had been
silently narrowing the test: the key regex rejected underscores (so
`transfer.cancel_own` was invisible), and the final INSERT block swallowed the
trailing DELETE, so a revoked key read as a grant — which would have hidden
exactly the revocation H1.2 depends on. Four new assertions now pin the
separation of duties in the SQL a deploy actually applies.

### Legacy remap rule

`ready_to_ship` → `approved`. The only reading that invents no history: such a
row was created and could ship, which is what `approved` now means. Nothing is
marked received, and `approved_by` stays NULL with `auto_approved` false, so the
trail never claims a decision nobody made. Development held zero transfers, so
the remap was a no-op here — **the H1.1 legacy audit must be rerun before `0031`
is deployed anywhere holding real transfer history.**

### Verification

Backend **47 suites / 617 tests**, TypeScript clean, `prisma validate` valid,
migration status up to date at **31 migrations**, **4 triggers** intact.

Migrations proved on the database restored from the pre-migration backup (11
units, 7 sales, `sum_total = 10051.00` preserved, `unit.transfer` gone from both
store roles), on a clean database from zero, on dev, and on rerun. No seed
involved at any point.

**Live: 40/40** with five real sessions — Owner, Manager, Employee assigned to
both branches, source-only and destination-only. Employee request starts pending
and reserved; employee cannot approve, reject, or ship it unapproved; manager
approves without re-reserving; a stale approval is 409; employee ships;
source-only cannot receive; destination receives and the phone lands `in_stock`
at the destination; manager-created transfers start approved and auto-approved;
an employee in **both** branches still cannot self-approve; requester cancels
their own pending request but not another's; reject and cancel both demand a
reason and release the reservation; Owner approves remotely only with the source
branch selected; approve-vs-reject and ship-vs-cancel each have exactly one
winner; a shipped transfer cannot be cancelled; Sell and Pricing still refuse
reserved stock.

Mobile: TypeScript clean, `expo lint` clean, Node pure suites 11 + 5 + 6 + 7,
EN/AR both 559 keys with no gaps. Transfer status labels and tones aligned with
the new enum — no transfer screens were built.

### Backup, fixtures and cleanup

Backup `phonestore-20260808-043818.sql` (55 tables, 4 triggers, 0 raw `_binary`,
valid UTF-8), restore proven through the DEFINER-safe path before migrating:
55/55 tables, 4/4 triggers, `sum_total = 10051.00`, `units` checksum identical.

Four temporary users (`h12mgr`, `h12emp`, `h12src`, `h12dst`) and their branch
assignments and sessions were created for the authority matrix and removed
afterwards. Test transfers, transfer items and their `StockTransfer` audit rows
were removed via the migrator account — recorded here rather than left implicit.
Temporary databases `prisma_h12_pre` and `prisma_h12_clean` dropped.

Demo baseline afterwards: products 12 · units 11 · sales 7 ·
`sum_total = 10051.00` · sale_items 14 · stock 4 at 19/20/20/15 all v0 ·
transfers 0 · reserved 0 · no unit in an odd status · 4 triggers · 0 temporary
databases. Identical to the H1.1 baseline.

### 🔴 Deferred, and worth stating plainly

**No notifications were added.** Nobody is told that a request awaits their
approval, that theirs was approved or refused, or that a transfer has shipped.
The workflow is correct and enforced, but a pending request sits unseen until
someone opens the list. Deferred to H1.5 rather than half-built here — it is the
most user-visible gap left in transfers.

**Commits:** backend `0026790`, `04e1463`, `d7f4653`; mobile `30440df`; docs the
commit carrying this entry. All three trees clean and level with `origin`.
`READY_FOR_HANDOFF`, owner `NONE`. **H1.3 not started.**

---

## 2026-08-09 — CLAUDE-B — **Phase H1.3: serialized transfer notifications and the complete mobile workflow**

Migration **`0033`**. Serialized only — quantity lines, partial shipment and
receipt, proof photos, consignment and WhatsApp remain future work.

### Takeover

Everything matched the brief exactly: backend `d7f4653`, mobile `30440df`, docs
`1a15041`, all clean and level; 47 suites / 617 tests, 31 migrations, latest
`0032`, schema up to date. Nothing needed correcting before starting.

### CP1 — the seven H1.2 requirements, reconciled

H1.2 proved its behaviour live but left **no standing test**, so nothing would
catch a regression, and the report never clearly evidenced Manager/Owner
auto-approval on create. All seven were re-checked; **every one already held**,
so no production behaviour changed. They are now pinned by 25 tests against the
real service.

Two things worth recording because they are easy to get wrong later.
Auto-approval follows the permission held in the **active branch**, never a role
name — the same manager requesting stock out of a branch where they lack
`transfer.approve` produces a pending request. And a terminal transfer is
refused by two different rules depending on who asks: the requester is stopped
by ownership ("already been acted on"), a manager by the state machine ("cannot
become 'cancelled'").

The cancel-key compromise is now written down rather than rediscovered: managers
hold `transfer.cancel_own` **only to pass the route guard**, because
`PermissionsGuard` requires ALL listed permissions. Guarding the route on the
broad key would lock employees out of withdrawing their own request; guarding on
both locks managers out entirely, which is exactly what `0031` did until `0032`.
A cleaner fix is ANY-of route semantics, but that would alter authorization on
every route in the system — far outside a transfers phase.

### CP2 — the notification audit, and what it found

The existing system was reused: same model, same service, same API, same mobile
screen. No second subsystem, and the recognition outbox was left alone.

Auditing first turned up **a defect that predates this phase**. `listForUser`
scopes on `targetUserId = me OR targetUserId IS NULL` and **never reads
`branch_id`**, so a notification with no target user is a **company-wide
broadcast** whatever branch it names. The old `transfer.incoming` and
`transfer.received` emits were exactly that, and were sent *after* the
transaction — so every user of every branch saw them, and a failed emit meant
stock moved with nobody told. Both now target named people inside the
transaction. **The general defect remains** for `closing.completed` and any
future untargeted type, and is recorded rather than quietly half-fixed.

`0033` adds two nullable columns and one unique index. `dedupe_key` with
`UNIQUE (company_id, target_user_id, dedupe_key)` makes a duplicate an INSERT the
database **rejects**, because an application-level "already sent?" read is true
when checked and false when acted on. `payload JSON` stores the fields behind
the message so the app can compose it in Arabic, with the stored English as the
fallback — and carries no cost, price or margin, because a notification is read
outside the request that authorized it.

Seven events notify. Recipients come from **permissions in the relevant
branch** — the same question the guard asks — then deduplicated, with the actor
removed. A refusal goes only to the requester: broadcasting it helps nobody and
embarrasses somebody.

### CP3 — the list, counts and detail contract

`GET /transfers` was `take: 100`, no filter, no search, raw Prisma rows, so a
busy shop lost its older history and the app would have had to filter locally —
which answers "not found" for something that exists. It now takes a status
filter, an SQL search across the reference, both branch names, the product and
the IMEI/serial, and a keyset cursor on the UUIDv7 key.

`GET /transfers/counts` returns the three badge numbers in one grouped query,
declared **before** `:id` or Nest routes it as a transfer whose id is "counts".

`GET /transfers/:id` reports, per action, whether it is allowed, **why not**, and
the branch it must be performed from. Reason order is status → permission →
branch: a finished transfer must not send anyone to another branch, and someone
lacking authority must not be invited to switch branches to find that out.
Detail is readable from any branch the caller is assigned to, deliberately, so a
notification can open the transfer it is about from the other end.

`requestedAt` comes from the UUIDv7 key. There is no `created_at`, and `sent_at`
carries `DEFAULT now()` **and** is rewritten on shipment — a pending transfer's
`sent_at` is a creation time wearing a shipping label. It now reads null until
the transfer actually ships.

### CP4/5/6 — the phone

Shipped as one commit rather than three, on purpose: splitting it would have
pushed a list screen whose rows link to routes that do not exist yet, and a dead
link is not a green checkpoint.

The mobile permission catalogue still listed the retired `unit.transfer` and knew
**none** of the six replacements, so every transfer permission was an unknown
key. Fixed, and the Transfers entry is gated on `transfer.view`.

Actions come from the server's per-action answer rather than the client
re-deriving them — two sources of truth is how a button appears that will 403.
An action refused for status is not rendered at all; permission and ownership
refusals appear as a sentence, so nobody wonders where the button went. The
wrong-branch case is explained once, with an explicit "Switch to X"; the app
never switches branches on its own.

Create is scan-first with manual entry always available. Duplicates are reported
rather than silently collapsed, and a scanned accessory is refused with an
explanation that quantity stock is coming next — never dropped on the floor. The
`clientUuid` is minted once per attempt and held in a ref, and deliberately not
regenerated on failure, so a retry after a timeout resolves to the original
transfer instead of moving stock twice.

`ApiError` gained an optional `body`: the per-identifier `problems` list was
parsed and thrown away, which is the difference between "some units cannot be
transferred" and knowing which phone to go and look at.

### Three defects found by running it

**1. Recipient resolution never worked at all.** `holdersOf` filtered on
`role: { permissions: … }`, but `Role` declares **`rolePermissions`**. Real
Prisma rejected the query outright, so `POST /transfers` answered **400 for
every request** — the whole feature was dead on arrival. The unit suite was
green throughout, because the test double had been written to the same wrong
assumption: it agreed with my code instead of with the schema. This is the G1
specification-search lesson one level up. The double now **throws** on any
`role` filter key other than `key`/`rolePermissions`.

**2. `?limit=` was a 400 for every client.** A query parameter arrives as a
string and the global pipe runs with `enableImplicitConversion: false`, so
`@IsInt()` alone rejected every value a client could send. Service-level tests
pass a real number and never touch the pipe. Fixed with the same explicit
transform the catalog uses, and pinned by DTO tests that go *through* validation.

**3. The pre-existing broadcast defect** described under CP2.

A fourth thing cost time and is worth recording: the API left listening on port
3010 from the previous session was running **old code**, and `/transfers/counts`
returned 401 rather than 404 because the old `@Get(':id')` matched "counts" and
its guard answered first. A 401 is not proof that a route exists.

### Verification

Backend **50 suites / 688 tests**, TypeScript clean, **32 migrations**, schema up
to date, **4 triggers** intact.

Migration proofs: restore verified DEFINER-safe **before** migrating (55/55
tables, 4/4 triggers, `sum_total = 10051.00`, `units` checksum identical to
live); `0033` applied to the restored database with **no seed**, to a clean
database from zero, to dev, and on rerun; the documented reverse SQL was
**executed** and left all 41 notifications and every business row intact.
Temporary databases `prisma_h13_pre` and `prisma_h13_clean` dropped.

**Live: 76/76** against the running API and real MySQL with five real sessions —
Owner, source Manager, source Employee, destination Manager, and an Employee
assigned to **both** branches. Recipients per event were computed **from the
database** rather than hardcoded, after a first run showed my fixed list was
asserting the fixture instead of the rule: the demo company's own users
legitimately hold those permissions too.

It covers: reservation at request; exactly the source approvers told and the
requester not; the action opening the exact transfer; no cost anywhere in a
message; reserved stock refused by both Sell and Pricing; employee cannot
approve, cannot ship unapproved, and an employee in **both** branches still
cannot self-approve from either; Owner refused from the destination; approval
not re-reserving; a stale approval 409; shipment and receipt with the unit
landing in stock at the destination; receipt removing the source price override;
refusal and cancellation releasing the stock and demanding a reason; manager
auto-approval recording its approver; replay returning the original transfer and
creating no further notifications; **the database itself refusing a duplicate
notification**; approve-vs-reject, ship-vs-cancel and Sell-vs-Transfer each
having exactly one winner; paging with no repeat, status filters, search by
IMEI, product and branch; counts; detail actions per role, status and branch;
and the wrong-branch case naming the branch to switch to.

Mobile: TypeScript clean, `expo lint` clean, **expo-doctor 18/18**, web export
**32 routes** including all three transfer routes, EN/AR both **676 keys** with
no gaps or duplicates, pure Node suites 11 + 5 + 7 + 6 + 11.

### Fixtures and cleanup

The live script created its own temporary product, ten units and four users
(`h13mgr`, `h13emp`, `h13dst`, `h13both`) so demo stock was never involved, and
removed all of them. Three `price.changed` notifications produced by the
verification's temporary product were removed afterwards as well, via the
migrator — recorded here rather than left implicit, since they pointed at a
product that no longer exists.

Demo baseline afterwards: products 12 · units 11 · sales 7 ·
`sum_total = 10051.00` · sale_items 14 · stock 4 · reserved 0 · transfers 0 ·
notifications 41 · `units` checksum `2a1dc9bf284afde32b402ad108d38a76` · no odd
unit statuses · 4 triggers · 0 temporary databases. Identical to before.

Backup `phonestore-20260809-192629.sql` — 55 tables, 4 triggers, 0 raw
`_binary`, 1 960 hex literals, valid UTF-8, correct trailer.

### 🔴 Not verified, and not claimed

**The transfer workflow was never touched on a device.** Camera scanning,
haptics, sheet gestures, Arabic **visual** RTL and the whole action flow are
unverified by anything but a browser and a test runner. `docs/24` §9b adds 31
transfer checks for the user's own pass.

**Untargeted notifications remain company-wide**, and a broadcast's read state is
still shared between users. Transfers no longer depend on that path;
`closing.completed` still does.

**Commits:** backend `82e9393`, `9013d26`, `fea136b`, `45e9b55`; mobile
`112e035`; docs the commit carrying this entry. All three trees clean and level
with `origin`. `READY_FOR_HANDOFF`, owner `NONE`. **H1.4 not started, and
blocked on the destination cost/price decisions in `docs/21` §6b.**

---

## 2026-08-13 — CLAUDE-A — **Explicit account switch, then Phase H1.4 (quantity-tracked accessory transfers)**

**Account switch.** The user explicitly moved ownership from `NONE` to
**`CLAUDE-A`**. Nothing recorded by CLAUDE-B was relabelled or reinterpreted:
H1.1, H1.2 and H1.3 remain CLAUDE-B's work, exactly as their entries state. This
entry records only that the next session runs as CLAUDE-A.

**Takeover verification — checked against reality, not assumed.** Backend
`45e9b55` · mobile `112e035` · docs `f8fee9b` · latest migration `0033` · all
three working trees clean and level with `origin/master` · `READY_FOR_HANDOFF`
with owner `NONE`. Every value in the H1.4 brief matched.

**One layout note, not a discrepancy.** The brief refers to
`docs/CURRENT_HANDOFF.md` and `docs/SESSION_LOG.md`; both files actually live at
the **repository root** beside `CLAUDE.md`, which is where `CLAUDE.md` itself
says they are. Same files, different path.

**Authorised scope:** partial quantities chosen when the request is created.
Shipment and receipt stay all-or-nothing per transfer. Not started: partial
shipment, partial receipt, discrepancies, return-to-source, proof photos,
consignment, loan book, WhatsApp, technician features, notification-broadcast
redesign.

---

## 2026-08-13 — CLAUDE-A — **Phase H1.4: quantity-tracked accessory transfers (`0034`)**

*(Continues the account-switch entry above. Same session.)*

### What shipped

Accessories move between branches alongside phones, in the same request.
Partial quantities are chosen when the request is made; **shipment and receipt
stay all-or-nothing per transfer.** Partial shipment, partial receipt,
discrepancy handling, return-to-source, proof photos, consignment, WhatsApp,
returns, customer credit and technician work were **not started**.

### CP1 — the audit, before any SQL (docs `254c16e`)

The serialized baseline was re-proved **29/29** against a freshly started
backend on port 3010 — not a server left running by an earlier session. Four
checks failed on the first run and **none was a regression**: the script called
a pricing route that does not exist and reused units it had already reserved. A
verification script is as capable of lying as the code it checks.

The audit answered all five questions from real schema and live data, and found
three things worth saying out loud:

- **Purchase intake never averages cost.** Both intake paths increment quantity
  and leave `cost` at whatever the first receipt set, so buying the same
  accessory again at a different price overstates margin on everything sold
  afterwards. Pre-existing, out of scope, recorded rather than quietly fixed.
- **`stock_items.price` is `NOT NULL`**, so an unpriced quantity row could not
  be represented at all — which the approved destination-price rule needs.
- **Shipped goods already vanished from valuation.** A serialized unit in
  transit is not `in_stock` and its `branch_id` does not change until receipt,
  so H1.3 had already opened that hole.

### CP2 — migration `0034` (backend `3ae972b`, docs `17ca780`)

Backup `~/erp-backups/phonestore-20260813-173135.sql` taken first — 262 269
bytes, 0 raw `_binary`, 2 104 hex literals, 55 tables, 4 triggers, valid UTF-8 —
with the DEFINER-safe restore **proven before migrating**: 55/55 tables, 4/4
triggers with byte-identical bodies, and three binary-key checksums matching
live exactly.

A transfer line is now structurally one kind or the other. **Two changes were
not planned.** MySQL error 3823 refuses a CHECK on a column whose foreign key
carries a referential action, so both optional FKs had to leave Prisma's default
`ON DELETE SET NULL` — which this session had already watched orphan a transfer
line during cleanup, so `RESTRICT` was independently right. And
`stock_items.price` became nullable, because the alternatives were to invent a
price or refuse goods that had physically arrived.

Four deployment proofs passed (restored pre-migration database with **no seed**,
clean database, dev, rerun), the reverse SQL was executed and its two
destructive steps named, and the constraints were exercised **13/13 against real
MySQL** — one of which had to be re-run because the first attempt was blocked by
a *different* foreign key and therefore proved nothing. Both scratch databases
dropped.

### CP3 — atomic reservation (backend `46cbbe6`)

`lines`, discriminated on `kind`. Reservation is one conditional UPDATE per line
with the rule in the WHERE clause; a read followed by an update cannot promise
anything, because the row is free when you look and taken when you write.
Duplicates are refused before availability is consulted, which closes a real
hole: two lines of 6 against 10 available each pass alone and together promise
12.

*Correction: that commit's message says "51 → 53 suites"; the real figures are
51 → 52. History was not rewritten for a count error, matching how the
equivalent slip was handled at H1.2.*

### CP4 — shipment, in-transit value, receipt (backend `754e5e3`)

Cost is read at shipment, not at request, and written onto the line. Receipt
averages it in **inside the UPDATE**, against the row's own committed values —
reading it into the application and writing it back would lose one of two
concurrent receipts. Selling price does not travel: an existing destination row
keeps its price, a new one resolves from the destination's own sources, and
otherwise arrives unpriced.

### CP5 — contracts, and two defects only running it could find (backend `9c0ee24`, `c6e1930`)

The list said "1 item" for ten chargers because it counted rows. It now reports
unit count, quantity-line count and total quantity, and search reaches
accessories by product, variant and barcode.

Then the live run found two things, **both older than this phase**:

1. **The global exception filter discarded every structured detail**, keeping
   only `message` and `code`. Transfers have attached `problems` since H1.1 and
   `mobile/lib/transfers.ts` has read `body.problems` since H1.3 — it always got
   `undefined`, so the user only ever saw the generic sentence. **No test
   noticed, because every one of them asserted the status code.**
2. **Nothing refreshed inventory valuation after a transfer.** Only
   `sale.recorded` ever did, so since H1.3 the source branch went on reporting
   stock it no longer had. H1.4's in-transit figure made it visible rather than
   causing it.

A **flaky pre-existing catalog test** was fixed on the way: it searched
`JSON.stringify(entry)` for bare numbers, which also searched the `entityId`
buffer of a random UUIDv7 — `"160"` contains `"60"` — failing about one run in
three for reasons unrelated to what it tested.

The transfers test double now **throws** on raw SQL instead of pretending.
Re-implementing a conditional UPDATE in JavaScript would test the
re-implementation, which is exactly how H1.3's recipient query stayed green
while real Prisma rejected it.

### CP6 — the mobile draft (mobile `3c016e3`)

Phones and accessories in one draft, behaving differently on purpose: a phone
scanned twice is a reported mistake, an accessory scanned twice counts up — which
is also the only shape the database accepts. Accessories are found by barcode or
search, reusing the inventory contract that already reports physical, reserved
and available. A barcode matching more than one variant opens the picker rather
than guessing. Quantity is a stepper **and** a number field, because typing beats
tapping plus forty times. No cost, margin or price appears anywhere in the flow.

### CP7 — concurrency, against real MySQL

**18/18, every check genuinely simultaneous.** Two requests for the last stock ·
Sell versus Transfer · two mixed requests competing for one scarce line, where
the loser reserved nothing at all · duplicate ship · ship versus cancel ·
duplicate receive · concurrent replay of one request id · and the database
invariants intact throughout.

**The essential one passed:** two *different* transfers of the same product,
received into the same destination row at the same instant, produced quantity
**30** and cost exactly **8.00** — `(10 × 4 + 20 × 10) ÷ 30` — with no lost
update.

- **Files changed:** backend — `prisma/schema.prisma`,
  `prisma/migrations/0034_quantity_transfer_lines/`, `src/transfers/*`
  (`transfer-lines.ts`, `quantity-reservation.ts` new), `src/analytics/*`
  (`in-transit-value.ts` new, `rollup.service.ts`, `rollup.listener.ts`,
  `analytics.service.ts`), `src/common/filters/all-exceptions.filter.ts`,
  `src/common/events/spine-event-bus.ts`,
  `src/common/interceptors/financial-fields.ts`, `src/sales/sales.service.ts`,
  `src/pricing/pricing.service.ts`, `src/inventory/inventory.service.ts`.
  Mobile — `lib/transfer-draft.ts`, `lib/transfer-summary.ts` (new),
  `lib/transfers.ts`, `app/transfers/{new,index,[id]}.tsx`, `types/api.ts`,
  `lib/i18n/{en,ar}.ts`. Docs — `21`, `24`, `25`, handoff, this log.
- **Database migrations:** `0034_quantity_transfer_lines`.
- **Tests:** **54 suites / 748 tests** (from 50/688). Backend `tsc` clean,
  `prisma validate` valid, 33 migrations, 4 triggers. Mobile `tsc` clean, `expo
  lint` clean, expo-doctor 18/18, web export 32 routes, EN/AR both **695 keys**,
  24 pure Node tests.
- **Live verification:** serialized baseline **29/29** re-proved on the final
  build · quantity **44/44** · concurrency **18/18**.
- **Fixtures and cleanup:** every script created and removed its own products,
  stock, users and transfers. The Sell-versus-Transfer race records a **real
  sale**, removed with its lines and payments rather than left to inflate the
  baseline. Notifications created today were removed via the migrator; the 41
  older rows are the recorded baseline and were untouched. **The transfer
  invoice-number sequence advanced and was not rewound.**
  Demo data afterwards: products 12 · units 11 · sales 7 · `sum_total =
  10051.00` · sale_items 14 · stock 4 · reserved 0 · transfers 0 ·
  notifications 41 · `units` checksum `2a1dc9bf284afde32b402ad108d38a76` ·
  0 temporary databases.

### 🔴 Not verified, and not claimed

**Nothing was touched on a physical device.** Camera scanning of an accessory
barcode, haptics, the stepper under a thumb, keyboard avoidance, sheet gestures
and Arabic **visual** RTL are unverified. `docs/24` §9c adds 24 checks.

**The valuation invariant is eventual, not instantaneous.** The rollup refreshes
after commit — as it always has for sales — so held + in-transit reconciles once
the refresh lands. Making it synchronous is the materially larger redesign the
brief says to stop and report before attempting.

**`BranchVariantPrice` for quantity products is implemented but unreachable**:
nothing writes such a row, and the table holds zero.

**Purchase intake still does not average cost.** After H1.4 cost is averaged on
transfer receipt and not on purchase receipt.

**Commits:** backend `3ae972b`, `46cbbe6`, `754e5e3`, `9c0ee24`, `c6e1930` ·
mobile `3c016e3` · docs `254c16e`, `17ca780`, and the commit carrying this
entry. All three trees clean and level with `origin`. `READY_FOR_HANDOFF`, owner
`NONE`.

---

## 2026-08-13 — **Explicit account switch: CLAUDE-A → CLAUDE-B**

The user requested an explicit account switch. The project was
`READY_FOR_HANDOFF` / owner `NONE` at the end of **H1.4** (quantity-tracked
accessory transfers); ownership now passes to **`CLAUDE-B`**.

**No earlier attribution was relabelled or reinterpreted.** H1.4 was CLAUDE-A's
work and remains recorded as CLAUDE-A's. Every previous CLAUDE-A and CLAUDE-B
entry stands exactly as written, including the 2026-08-05/06 correction note
already appended to this log.

Takeover verified rather than assumed: backend `c6e1930` · mobile `3c016e3` ·
docs `6426841` · latest migration `0034` (33 total) · **54 suites / 748 tests**
passing · mobile TypeScript and `expo lint` clean · all three trees clean and
level with `origin/master` · `READY_FOR_HANDOFF` / owner `NONE`. Every expected
value in the H1.4.1 brief matched reality, so nothing needed correcting before
work began.

Authorised task: **Phase H1.4.1 — purchase-cost and inventory-valuation
hardening.**

---

## 2026-08-13 — CLAUDE-B — **Phase H1.4.1: purchase-cost and inventory-valuation hardening**

**No migration.** The schema was never the problem.

### The defect, measured before touching anything

H1.4 averaged cost correctly on transfer receipt and recorded, in its own
handoff, that purchase intake did not. Tracing every path that creates or
increases a `StockItem` found **two** production paths with the same omission —
purchase receiving and the quick "Add Stock" endpoint — both writing
`update: { quantity: { increment } }` and never touching `cost`.

Neither is a concurrency bug; `upsert` with an increment is atomic. The defect
is purely financial, and it always errs in the direction that makes the shop
look more profitable than it is.

The database showed it plainly. Two of four quantity products had drifted, and
both were exactly the ones re-ordered at a different price: the Apple cable
bought 50 @ 4.10 then 10 @ 5.00 still cost 4.10 instead of 4.25, and the Anker
power bank bought 10 @ 8.50 then 5 @ 9.00 still cost 8.50 instead of 8.6667.
The two single-price products were correct — which is what the defect predicts.

The historical stop condition did **not** fire: `stock_items.cost` is `NOT NULL`
at the database level, so positive quantity with a null cost is structurally
impossible. Zero invalid quantities, zero over-reserved rows, three CHECKs
intact.

### An error in my own audit, corrected rather than left

The CP1 commit claimed a purchase "emits no event, so it never refreshes
valuation at all". That was wrong — I grepped the event bus and missed the
direct `enqueueBranchRefresh` call. All three inflows do enqueue a refresh. The
correction is written into `docs/26` §7 rather than force-pushed away, matching
how earlier count errors were handled.

### What shipped

One rule for every inflow, in `inventory/stock-cost.ts`: a single
`INSERT … ON DUPLICATE KEY UPDATE` where the average is computed inside the
statement. That closes two races at once — a second receipt averages against the
first's committed result, and the absent-row case is arbitrated by the unique key
instead of by an earlier read that both callers could pass. `cost` is assigned
before `quantity` because MySQL evaluates left to right; averaging after the
increment would under-weight the incoming goods.

Physical quantity weights the average — stock promised to a transfer is still
owned and was still bought at a price. Reservations and the selling price are
absent from the UPDATE entirely. A missing price now leaves the row **unpriced**
rather than `0`, which read as "sells for free".

Transfer receipt was already correct and now expresses itself through the same
function, so the rule exists once instead of three times. Its
`receiveIntoExisting` was deleted rather than left as a second way to do it.

### Three defects only running it could find

**1. My own fix introduced a deadlock, and lost a purchase.**
`INSERT … ON DUPLICATE KEY UPDATE` takes insert-intention gap locks the old
read-then-write did not. Two simultaneous purchases of the same product
deadlocked; MySQL rolled one back entirely, leaving 150 units where 200 had been
bought. Fixed with deterministic lock ordering plus a discriminating retry — a
lock conflict is re-run because the rollback was total, while unique violations
and domain conflicts rethrow untouched so a clear refusal never becomes a slow
one. Transfer receipt got the same protection, since this phase changed its lock
profile too.

**2. A simultaneous identical replay returned a misleading 409**, telling the
caller "a duplicate identifier was detected" for a delivery that had in fact
succeeded. It now resolves to the winning purchase, as transfers have since H1.1.

**3. `GET /inventory` exposed every branch's stock and average cost.** The route
carries no `@RequirePermissions`, so `PermissionsGuard` exits early and never
validates branch assignment — while the active branch comes from the
`X-Branch-Id` header. Changing one header returned another branch's costs. This
is precisely the G2A-CP3 defect recurring on a route nobody re-examined, and it
is what the brief meant by preserving branch isolation. The check is now one
shared helper used by inventory and pricing alike.

### Valuation: the redesign the brief allowed me to stop for was not needed

H1.4 flagged the invariant as eventual and warned that fixing it might be a
materially larger redesign. Tracing it showed the problem was narrower.

**No finalized financial record depends on the eventual rollup.** Daily closing
awaits its own recompute and reads `sale_items` — immutable per-line cost
snapshots — and never reads `InventoryValuation`. Only one endpoint was wrong:
`/analytics/inventory-value` added a **stale** held figure to a **live**
in-transit figure while calling the sum "the number that must not move when
stock is merely travelling". Both halves now come from source, through the same
query that rebuilds the rollup, so the two cannot drift apart.

Dead-stock listings and the health score deliberately still read the rollup:
they rank per product, where a moment's lag changes an ordering rather than a
reported total. Making the refresh durable is recorded as a background-jobs
phase, not silently expanded into.

### Verification

Backend **56 suites / 778 tests** (from 54/748), TypeScript clean,
`prisma validate` valid, **33 migrations** with none added, 4 triggers intact.

**Live 42/42** against real MySQL, on an API this session started itself — never
one left behind. Three earlier runs had to be discarded because a stale server
survived a kill and served old code; the final run confirms "API listening" in
its own fresh log before a single check runs.

Several of my first assertions were wrong and were corrected rather than
accommodated: three chained the expected average from the wrong base (the engine
was right every time), one used non-Luhn IMEIs so no unit was ever created, one
used the pre-H1.4 transfer line shape, and one asserted an employee lacks
`cost.view` when the role matrix grants it.

Races, genuinely simultaneous: purchase vs purchase into an existing row
producing the exact combined average; two purchases into a row that did not
exist yet creating exactly one row with both quantities; purchase vs transfer
receipt into one destination; purchase vs selling the last available quantity;
and a simultaneous replay applying once with both callers told about the same
purchase.

Mobile needed no change — no API type moved, and Receive already asks for the
incoming unit cost. Showing the resulting average was considered and rejected:
the response does not carry it, and adding a field for decoration is not what
this phase is for.

### Fixtures and cleanup

The live script created its own supplier, eight products, stock and two users,
and removed all of them. The 174 `stock.received` broadcasts and transfer
notifications it produced were removed afterwards, returning the table to
exactly 41. Demo baseline afterwards: products 12 · units 11 · sales 7 ·
`sum_total = 10051.00` · sale_items 14 · stock 4 · reserved 0 · transfers 0 ·
`units` checksum `2a1dc9bf284afde32b402ad108d38a76` · 4 triggers · 0 temporary
databases.

### 🔴 Left for the user, deliberately

**The two drifted rows were not corrected.** From now on they re-average
correctly on the next receipt, but the existing drift does not heal itself. The
correction is deterministic; the stored values are stale rather than provably
invalid, so under the phase rule a backfill needs explicit approval.

**Commits:** backend `236fc9b`, `8d5f996`, `e964c71` · mobile none · docs
`11f1540` and the commit carrying this entry. All three trees clean and level
with `origin`. `READY_FOR_HANDOFF`, owner `NONE`.

---

## 2026-08-13 — CLAUDE-B — **Phase H1.4.2: verified historical cost repair**

Account unchanged: still **CLAUDE-B**, no switch, no relabelling.

**Database-only.** No code changed, no migration was created, no generic
backfill utility was built, and neither code repository has a new commit.

### First, a correction to my own H1.4.1 claim

H1.4.1 said in three places that the drifted rows "will re-average correctly on
the next receipt". **That was wrong**, and the formula says so plainly: the new
weighted average takes the **stored** cost as its opening value, so a stale
number is an *input* to every future receipt. The error is carried forward,
scaled by `quantity_before / (quantity_before + received)`. It dilutes; it never
clears. Starting from the cable's −0.15: +50 @ 5.00 leaves −0.0765, another +50
leaves −0.0513, +100 @ 6.00 leaves −0.0310. Only physical quantity reaching zero
— or an explicit repair — ends it, and every margin computed meanwhile is
overstated. Corrected in `docs/26` §9, `docs/21` §6c and the handoff.

### The lineage changed one of the answers

This is why the brief insisted on a chronological ledger rather than an average
of purchase prices, and it was right.

```
 2026-07-30 17:08  purchase   +50 @ 4.10   → 50   avg 4.1000  (opening)
 2026-07-30 17:09  sale        −5          → 45   avg 4.1000
 2026-07-30 19:31  sale        −1          → 44   avg 4.1000
 2026-07-30 19:32  sale        −1          → 43   avg 4.1000
 2026-07-30 21:42  sale        −1          → 42   avg 4.1000
 2026-07-30 22:13  purchase   +10 @ 5.00   → 52   avg 4.2731
```

Eight cables were sold **between** the two deliveries, so only 42 were on hand
to average against — not 50. The true cost is **4.27**, not the **4.25** I
reported in H1.4.1 from averaging purchase prices. The Anker power bank had no
intervening sales, so its ledger agrees with the simple average at **8.67**.

### Proving the lineage was complete

Every event class was checked rather than assumed: purchases, sales (8 units,
none voided), returns (0), transfer lines for these products (**0**), import
batches ever run (**0** company-wide), audit rows indicating quick "Add Stock",
adjustment, recount or import (**none**), `price_change_events` (**none**), and
`stock_items.version = 0` on both rows — so no pricing-service edit had ever
touched them either.

Reconstruction then had to reproduce reality exactly, and did: Apple
50 − 8 + 10 = **52** actual 52; Anker 6+2+2+3+2 = **15** actual 15; reserved 0
on both with no open transfer anywhere; same company and branch.

### The repair

Backup `~/erp-backups/phonestore-20260813-205223.sql` (296 223 bytes, 55 tables,
4 triggers, 0 raw `_binary`, valid UTF-8), with the DEFINER-safe restore proven
into `prisma_h142_pre` **before** anything was mutated — 55/55 tables, 4/4
triggers, `sum_total = 10051.00`, `units` checksum identical. Temporary database
dropped afterwards.

| Product | Physical / reserved | Old → new | Valuation |
|---|---|---|---|
| Apple USB-C Cable | 52 / 0 | 4.10 → **4.27** | +8.84 |
| Anker PowerCore 10000 | 15 / 0 | 8.50 → **8.67** | +2.55 |

Company held value 4 140.70 → **4 152.09 (+11.39)**.

The new value was computed **twice independently** — arbitrary-precision
`Decimal` and a MySQL `CAST(... AS DECIMAL(14,2))` — and both had to agree
before the write. The update was a compare-and-swap on row id **and** old cost
**and** physical quantity **and** reserved quantity, changing only `cost`, with
the audit insert in the same transaction.

That atomicity was not theoretical. The first attempt failed because `before`
and `after` are reserved words in MySQL 8 and my audit INSERT did not quote
them; the transaction rolled back and whole-table checksums confirmed **every
table byte-identical** afterwards. Only after fixing the quoting did anything
commit.

Checksums before and after the successful run: **only `stock_items` and
`audit_logs` changed.** The other 23 tables — sales, sale items, payments,
purchases, purchase lines, suppliers, branch prices, products, units, transfer
items, every rollup, closings, digests and notifications — are byte-identical.

### ⚠️ An incident I caused, recorded rather than hidden

One verification check attempted an `UPDATE` on `audit_logs` to prove the
append-only trigger refuses it. The trigger deliberately **exempts the
`phonestore_migrator` (DBA) account** so maintenance is possible — and that is
the account my script uses. The update therefore succeeded and overwrote the
`reason` on both correction rows with the literal text `tampered`.

No cost, quantity, reservation or any other column was affected. I restored the
exact original text and inserted **audit row 849** recording the incident and
its cause, rather than repairing it quietly. The probe was rewritten to *read*
the trigger definition instead of firing it.

**The lesson, plainly: a probe must never be the damage it is looking for.**

### Verification after the repair — 26/26

Corrected costs present; quantities, reservations, selling prices and pricing
`version` unchanged; `/analytics/inventory-value` equal to the live
source-of-truth sum; `totalStockValue = held + in-transit`; dashboard and
health-score responding; the persisted rollup refreshed through `RollupService`
to exactly the live figure; inventory showing the corrected averages.

The check that matters most for the shop: **a price of 4.20 — which the stale
4.10 would have permitted — is now refused as below cost**, and the refusal
reveals no cost figure.

History untouched: the four historic sale lines still carry **4.10**, which was
genuinely the true average when they were sold; sales 7 / `10051.00` unchanged;
daily rollup COGS and gross profit unchanged; notifications **41 before and
after**, because this is demo-data maintenance and not shop news.

Backend **56 suites / 778 tests**, TypeScript clean, 33 migrations, schema up to
date. The H1.4.1 purchasing/valuation/transfer live regression re-run at
**42/42**. Its temporary users, supplier, products and the 25 notifications that
run produced were removed; the notification table is back to 41.

### Housekeeping

No diagnostic utility was built: §7 permits one but says not to if it enlarges
the phase, and two verified corrections did not need a tool. No schema migration
was created to record the repair — the `AuditAction` enum has no bespoke member,
so the explicit action `stock.cost_corrected` travels in the reason and payload.

Demo baseline afterwards: products 12 · units 11 · sales 7 ·
`sum_total = 10051.00` · sale_items 14 · stock 4 (now 4.27 / 8.67 / 5 / 5) ·
reserved 0 · transfers 0 · notifications 41 · 0 temporary databases.

**Commits:** backend none · mobile none · docs the commit carrying this entry.
All three trees clean and level with `origin`. `READY_FOR_HANDOFF`, owner
`NONE`.

---

## 2026-08-14 — CLAUDE-B — **Phase I0: Returns truth audit and implementation plan**

Account unchanged: still **CLAUDE-B**, no switch, no relabelling.

**READ-ONLY.** No schema migrated, no return behaviour changed, no permission
granted or revoked, no sale created or returned, no mobile screen added, no
financial fixture created. Backend and mobile have no new commit; the only
changes are documentation.

Deliverable: `docs/27_RETURNS_AUDIT_AND_DECISIONS.md`.

### Takeover

Every value in the brief matched: backend `e964c71`, mobile `3c016e3`, docs
`bef8719`, 33 migrations, 56 suites / 778 tests, stock costs 4.27 / 5.00 / 5.00
/ 8.67, notifications 41, sales 7 / 10 051.00, all three trees clean and level,
`READY_FOR_HANDOFF` / `NONE`. Nothing needed correcting.

### The headline: Returns already exist, and contradict the approved rules

`POST /sales/:id/returns` finalises a return in **one call**. It voids the sale
line, rewrites the original sale's `total`, `totalCost` and `margin`, restocks
the phone as ordinary sellable stock **by default**, and accepts **any
`refundAmount` the client sends**. There is no request, review, approval,
responsibility, evidence, return-window check, idempotency, versioning or
concurrency protection. Of the eighteen approved rules, one is satisfied
(automatic refund timestamp), two partially, and the rest not at all.

The reported concern was accurate and also understated. Three findings matter
most:

**1. History is rewritten in place.** The original sale row is mutated. Rollups
exclude voided lines (`AND si.voided = 0`) while `DailyClosing` is written
`isLocked: true` and never recomputed — so a return dated today retroactively
lowers the revenue and COGS of the day the sale happened, but only at the next
recompute of that branch-day. `returnUnit` emits no event and refreshes nothing,
so the drift surfaces later, at an unrelated moment, and the locked closing then
disagrees with the rollup it came from with nothing recording why. This breaks
approved rule 18 directly.

**2. The refund amount is client-supplied.** `refundAmount` is optional with
only `@Min(0)` and is never compared to what the customer paid — a caller may
refund more than the line was sold for.

**3. A defective phone becomes sellable immediately.** `restock` defaults to
`true`, so the default path puts the returned phone straight back to `in_stock`.
Marking it faulty requires opting in.

### The return window is decorative

`company_settings.return_window_hours` exists, is Owner-editable with version
CAS, is bounded to one year, and is **enforced nowhere** — zero references in
`src/sales/`. The schema comment says so outright. The demo shop is configured
`0` ("no returns") and the endpoint works anyway. No per-sale deadline, no
per-sale override, no deadline on the receipt.

Recommended: an immutable, server-calculated `return_deadline_at` snapshotted
onto the sale at completion, so changing company settings later cannot alter an
earlier customer's rights, and the client never computes eligibility.

### Permissions

`sale.return` today means *finalise a return*. `store_employee` was already
correctly audited out of it in `0018`, and `prisma/seed-data/permissions.ts`
even records the reason and names the missing piece — "needs a future
`return.request`". This audit confirms that reasoning rather than revisiting it.

The legacy `sales_employee` role still grants `sale.return` in both the
TypeScript matrix and the live database. **No live user is assigned to a legacy
role** — every assignment is `owner` or `store_employee` — so it is dormant
rather than exposed, but it should be revoked with the split.

An eight-permission split is proposed, all branch-scoped, with the H1.2
guard lesson carried forward verbatim: `PermissionsGuard` requires ALL listed
permissions, so a route needing "review OR approve" must be guarded on the
narrow key and decide breadth in the service.

### Two dependencies the milestone did not anticipate

**There is no sale-history screen, no sale-detail screen and no sale search.**
`GET /sales` is `take: 100`, newest first, with no filters or pagination, and
mobile has no sales list at all. An employee cannot find the original sale in
the app — which every return flow starts from. That work must be sequenced
before the return workflow, not discovered during it.

**`GET /sales` and `GET /sales/:id` carry no `@RequirePermissions` and no branch
validation.** The guard exits early, so the branch in the header is never
checked — the same defect class fixed for `/inventory` in H1.4.1 with
`assertAssignedToBranch`. Pre-existing and not caused by Returns, but Returns
reads sales heavily, so it is raised as an in-scope question.

### Two approved rules found in `docs/21` §9 that change the plan

Re-reading the approved decisions after the code audit surfaced two rules worth
separating out.

*"Returned phone becomes Faulty awaiting inspection, not sellable"* is already
approved — so the custody recommendation is the existing decision being
honoured, not a new one. The only open question is whether to add a distinct
`return_hold` status or overload `faulty`.

*"Profit stays provisional during the return window"* is the largest unexamined
consequence in the milestone, and the approved decision itself flagged it:
"this affects the existing rollup design". Today profit is final the moment a
sale commits and days close locked, so a day can be closed before its sales are
final. Three options are laid out; reversal-on-return-date is recommended for
the first release with a "net of later returns" report as follow-up — but this
is a product decision about what profit *means* to the Owner and must be
answered explicitly rather than settled by implementation convenience.

### Recommended lifecycle and sequence

`requested → under_review → approved → refunded`, with `rejected` and
`cancelled` as exits; customer-caused damage reachable only with an Owner
exception; an expired deadline overridable only by an Owner initially. Approval
settles the money; a separate confirmation records that money actually moved.
The phone rests in an unsellable hold until explicitly cleared for resale.

Thirteen-step sequence proposed, with deadline snapshot, schema and the
permission split landing before any workflow, and sale search inserted as step
4 where the dependency bites.

### Open decisions

Six questions carried to the user, each with operational and accounting
consequences: custody during investigation · returned-phone custody state ·
refund-due versus refund-confirmed · **screen-protector and accessory
accounting (deliberately left open — netting it silently would misstate the
refund)** · expired-window authority · quantity-accessory scope. Plus the
provisional-profit question and whether the sales-read defect is in scope.

### Verification

Backend **56 suites / 778 tests**, TypeScript clean, `prisma validate` valid,
33 migrations, "Database schema is up to date". Mobile TypeScript clean,
`expo lint` clean. Database untouched and re-verified after the audit: stock
costs 4.27 / 5.00 / 5.00 / 8.67, notifications 41, sales 7 / 10 051.00.

No API server was needed — every finding came from the code, the schema and
read-only queries, so none of the authorization probes the brief permits were
required.

**Commits:** backend none · mobile none · docs the commit carrying this entry.
All three trees clean and level with `origin`. `READY_FOR_HANDOFF`, owner
`NONE`. **Returns implementation is blocked on the decisions above.**

---

## 2026-08-14 — CLAUDE-B — Phase I1: secure sales history and the return-policy foundation

Migration **`0035`**. Backend `1dfccb5`, `cf6d5fb`, `a6c3a25`, `a446d4c`,
`fe3f13b`, `7203cbd` · mobile `bd96c03`, `0d20b4f`, `d4ee658` · docs `7a6822e`,
`029ecd4`, and the commit carrying this entry.

The phase the ReturnRequest lifecycle depends on. **No return can be created,
approved or refunded yet** — that is I2, and nothing here pretends otherwise.

### The unsafe endpoint is deleted, not merely closed

`POST /sales/:id/returns` answers **410 `legacy_return_disabled`** and performs
no database write of any kind. The five dangers I0 catalogued are unreachable
because the code that did them no longer exists: `returnUnit` and
`ReturnSaleDto` are deleted. Leaving it behind a permission would have left it
reachable by anyone holding that permission.

The test proves "writes nothing" by construction rather than by counting mock
calls: the controller is built with `{}` as its service, so any contact with the
service would throw a TypeError instead of the expected GoneException.

### Every sale now carries the policy it was sold under

Four columns, two CHECK constraints, and a rule stated once: `company_settings`
is what the shop offers **today**, so computing eligibility from it would let an
Owner shortening the window tomorrow cancel a right already promised, and
lengthening it grant one nobody offered. The sale carries its own window and its
own server-computed deadline, written once and never updated. `NULL` deadline
means "no returns" — a past date standing in for it would make an expired sale
and a no-returns sale indistinguishable, and a screen has to say different
things about them.

Existing rows got 0/NULL because that was audited to be the literal truth: the
company window is 0 and the newest of the seven sales was 263 hours old, so no
customer was inside a promised period. The migration header requires any other
environment to rerun that audit before deploying.

### The rules, as pure functions

`return-policy.ts` holds snapshotting, sale-time authority and eligibility, so
I2's endpoint reuses them rather than restating them. The one worth recording:
**a positive window may be removed entirely or extended, but not shortened to
another positive value.** Trimming 48 hours to 2 sells a worse promise under the
same banner; 0 is an explicit decision the customer is told about at the till.
Re-stating the shop default is *not* an override, so an ordinary sale needs
neither permission nor reason — but asking for something different without
`return.policy.override` is **refused, not quietly downgraded**, because an
employee must never be told a sale succeeded under a policy it does not have.

The 0..8760 bounds now come from `settings.constants` instead of a second copy.
That file's own header says why: a rule enforced in several places drifts, and a
maximum that drifts is not enforced.

### The sales-read defect is closed

`GET /sales` and `GET /sales/:id` required **no permission at all**, and the list
fell back to `{}` with no branch header — so any signed-in user could read every
sale in the company, cost and margin included, by sending no header. `take: 100`
with no paging silently amputated the history of any shop past its first weeks.

Both routes now require `sale.view` (branch-scoped, so a wrong or missing branch
header is a 403 before the service runs), page by keyset on the UUIDv7 primary
key, and apply **every** filter in SQL. An unknown status or method is a 400
rather than an ignored filter: dropping it silently widens the query and shows
everything under a heading claiming otherwise. The detail read fails closed three
ways that answer identically — another company, another branch, unknown id —
because a different message would confirm that an invoice exists elsewhere.

### What the customer is told

The receipt states the window in words and the exact deadline, and stopped
dating itself from the phone's clock. Mobile gained `/sales` and `/sales/[id]`
with the return status on every row. The Sell screen shows the policy in the
payment sheet above Complete — read-only for an employee, changeable by a
manager with a reason, and Complete is blocked until that reason exists.

### Three defects found while building, and what they taught

1. **A source-reading assertion matched its own documentation.** The test for
   "nothing restocks a returned unit" searched the service text for `restock`
   and found the comment explaining what had been removed. Fixed by stripping
   comments before asserting — an assertion about code must read code.
2. **The same test then matched a Prisma `select`.** `voided: true` in a *read*
   tripped an assertion written for a *write*. Restated as "no sale line is
   ever updated or deleted", which is both true and stronger — an assertion that
   fails on a read is one somebody eventually weakens to make it pass.
3. **The receipt was timestamped by the phone.** Found while wiring the policy
   through: the deadline is measured from the sale, so both must come from the
   same clock, and it must not be the one in the customer's hand.

### An audit-action decision, recorded deliberately

The sale-time policy override writes its own audit row, separate from the
below-cost override — different decisions, possibly different people, and one
row could answer "why was this sale different?" in only one of the two senses.
It reuses the existing `override` action with `field: 'returnPolicy'` rather
than adding an `AuditAction` enum member, which would have been a schema change
for a label and outside what this phase was authorised to migrate. If I2 adds
enough distinct return events to justify it, that is the point to reconsider.

### A pre-existing break, found and flagged rather than folded in

`mobile/lib/transfer-draft.test.ts` cannot run: commit `3c016e3` (H1.4-CP6)
renamed `addToDraft` into `addUnitToDraft` / `addStockToDraft` and never updated
its own test, so that regression guard has been importing a non-existent export
since then. **Not fixed here** — it belongs to the transfer work, not to I1 —
but it is real, and it means those transfer-draft assertions have been running
nowhere for the whole of H1.4.

### Verification

Backend **62 suites / 869 tests**, TypeScript clean, `prisma validate` valid,
**34 migrations**, "Database schema is up to date". Mobile TypeScript clean,
`expo lint` clean, `expo export --platform web` succeeds with both `/sales` and
`/sales/[id]` present. Mobile pure-function tests pass (13 new assertions for
the policy wording), except the pre-existing `transfer-draft` break above.

Migration `0035` was proven four ways before it touched dev: on a DEFINER-safe
restore of a fresh verified backup (`prisma_i1_pre`), on a clean database
(`prisma_i1_clean`), on dev, and on a rerun. Its reverse SQL was **executed**,
not merely written down — the first draft failed with error 3959 because MySQL
will not drop a column a CHECK still references, which is exactly why reverse
SQL has to be run. Both temporary databases were dropped and the sanitized dump
copy removed. Backup: `~/erp-backups/phonestore-20260814-032153.sql`, 303 955
bytes, 55 tables, 4 triggers, 0 raw `_binary`.

### Live HTTP verification — done, and it found a defect

**78 checks over real HTTP, all passing**, against a verification backend this
session started on port 3099. The user's own backend (3010) and Expo server were
left running and untouched.

**The defect the suite missed.** `GET /sales/:id` with a malformed id returned
**500**. `uuidToBin` throws a plain Error on anything that is not a UUID, and
Nest turned that into a server error. That broke the thing the detail read is
built around: another company's sale, another branch's sale and an unknown id
all answer ONE indistinguishable 404, and a 500 announced "that id was
structurally invalid" — precisely the distinction the identical-404 rule exists
to withhold. Fixed with the `isUuid` guard `devices.service` already uses, plus
a regression test over five shapes asserting the message is byte-identical to
the unknown-id case. Backend `309a399`.

That is the **third** time this project has shipped something the entire suite
approved and one live request rejected, after `role: { permissions }` and
`?limit=`. The suite proves the logic; only real HTTP proves the edges.

**How the probes were authenticated, and why.** The demo Owner's password is
unknown and was deliberately **not changed**. Instead the run created five
temporary users — Owner, Store Manager, Store Employee, a warehouse-only
Manager, and a cross-company Owner — on **existing role rows**, plus one
temporary company, branch and role so cross-company isolation could be proven
from the other side of the fence. One random 32-byte password was generated in
memory, hashed with the application's own Argon2id configuration, never printed,
never written to any file, and never passed between processes: setup, checks and
cleanup were one process for exactly that reason. The script lived in the OS
temp directory, outside every repository.

**A store code has to be canonical.** The first cross-company login failed 401
because the probe company's `public_store_id` was derived from the probe tag.
`normalizeStoreCode` accepts exactly ten uppercase hex characters and returns
null otherwise, which resolves to "no company" — deliberately indistinguishable
from a wrong password. Generated it the way `generateStoreCode` does. Nothing
was wrong with the application; the probe was.

**What was proven live:** the list and detail endpoints · `?limit=` conversion
(3 accepted, 99 and `abc` refused) · keyset paging across three pages with zero
overlap and every sale exactly once · invoice, IMEI, serial and partial-identifier
search · whole-day date ranges, with backwards and unparseable ranges refused ·
unknown status and method refused · a warehouse manager seeing zero sales rather
than the company · a forged branch header refused 403 · no branch header refused
rather than defaulting to the company · no token 401 · another company seeing
nothing and getting an identical 404 · the policy snapshot matching the stored
row, reporting `no_return_policy` rather than "expired" for these legacy sales ·
and `sale.view` across all three store roles.

**Cost gating, against the real matrix.** Every store role — including
`store_employee` — currently holds `cost.view` in this database, so all three
correctly received cost and margin. The assertions were written against the
matrix as queried rather than as assumed, which is the only reason they are
meaningful. **This means the strip has no live negative case**: no role that can
read sales lacks `cost.view`, so the gating interceptor never actually removes a
field on these endpoints today. It is covered by unit tests only. Whether an
employee should see profit is a product question for `docs/03`, not something to
settle by editing a role matrix during verification.

**The legacy return endpoint, re-proven live.** POST with
`{refundAmount: 999999, restock: true}` answered **410** with
`legacy_return_disabled`, and full before/after fingerprints showed **no**
change to sales, sale items, units, stock, payments, returns, closings,
notifications, or the audit log. An employee received the same 410, not a
permission error.

**Cleanup and integrity.** All five probe users, their assignments and their five
sessions were removed, along with the temporary company, branch and role. **Zero
audit rows were created** by the entire run — login writes none, only the device
endpoints do — so nothing append-only had to be preserved or, worse, edited.
Verified afterwards: 0 probe users, 0 probe companies, 0 orphaned assignments or
sessions, 6 users and 1 company as before, audit still 281 rows, sales 7 /
10 051.00, stock costs 4.27 / 5.00 / 5.00 / 8.67, notifications 41 — every
figure identical to the pre-I1 baseline.

**Authentication data, stated plainly.** The real demo Owner's password was
**not** changed; its row shows `updated_at` of 2026-08-13, before this session.
The only authentication failure was the abandoned attempt to reset it, which was
stopped on the user's instruction before any write. `OWNER_SEED_PASSWORD` in
`.env` remains stale — the seed upserts with `update: {}`, so it has diverged
from the stored hash. That is a real trap for the next session and is recorded
as open work, not fixed here. No temporary credential entered any repository, any
commit, or any transcript.

**The verification server was stopped.** Port 3099 is released; the user's 3010
backend and Expo server were never touched.

**Commits:** backend `309a399` · mobile `d4ee658` · docs the commit carrying
this entry. All three trees clean and level with `origin`.

---

## 2026-08-15 — CLAUDE-B — Phase I2 (CP1–CP4): the reviewed return workflow

Migration **`0036`**. Backend `e65d243`, `6b75ee0`, `bc5071d` · docs `403fd61`,
`d81f86a`, `47bea21`, and the commit carrying this entry. **Mobile untouched
(`d4ee658`).**

**I2 is NOT complete.** CP1–CP4 are done, verified and pushed. **CP5 (mobile
Returns workflow) and CP6 (full verification matrix) were not started.** The API
is complete and live-verified; no screen consumes it yet.

### What was built

An employee raises a return against one serialized sale line and may take the
phone in; a manager investigates, assigns responsibility and drafts what will be
withheld; a manager or owner approves or rejects. Approval writes one immutable
dated reversal, moves the phone to `faulty`, and reports the money on the day it
was approved.

Approval creates an **obligation**, never a payment. There is deliberately no
`refunded` state in the lifecycle — confirming money moved is I3, and a state
that does not exist cannot be set by accident.

### The audit that made it safe (CP1)

The stop condition worth checking hardest was whether an immutable dated
reversal could exist without rewriting history. It can, and the reason is that
`DailyRollup` is **derived** — recomputed per branch-day from source — while
`DailyClosing` is a locked snapshot nothing recomputes. Keying the returns
component on the approval date is therefore additive.

That also diagnosed the deleted legacy endpoint precisely: it set
`voided = true`, and because the rollup filters `si.voided = 0`, **every legacy
return silently rewrote a past day's revenue and profit — including closed
days.** The mirror of that defect is the one rule I2 must not get wrong, so
approving on an already-closed day is a 409 that names the day.

Three more findings shaped the design: the unit states `returned` and `faulty`
already existed (no enum migration needed); the legacy `returns` table holds
zero rows and encodes the exact defect being fixed, so it is deprecated in place
rather than reused or dropped; and accessory linkage **cannot** be inferred —
three demo sales carry two phones and one accessory line, so a guess would be
wrong half the time.

### Schema (CP2), and a correction to my own claim

One active claim per sale line is enforced by the database through a VIRTUAL
generated column (`NULL` when rejected, else 1) plus `UNIQUE (sale_item_id,
claim_key)` — the same duplicate-NULL trick `sale_items.active_unit_id` has used
since 0002. A CHECK tying status to the key was deliberately not added: the
column is generated FROM status, so a CHECK could only ever be tautologically
true, and a constraint that cannot fail misleads whoever reads it next.

**My first draft claimed rerun safety it did not have.** Bare `CREATE TABLE`
failed a replay with error 1050 while the header asserted a rerun changed
nothing. Tables now use `IF NOT EXISTS`, and since MySQL has no
`ADD COLUMN IF NOT EXISTS`, each `ALTER` is guarded by an `information_schema`
probe through a prepared statement. Re-proved by applying twice: identical
counts afterwards.

Proven on four databases — restored pre-I2, a rerun of it, a clean build of all
36 migrations, and dev. The documented reverse SQL was **executed**, not merely
written. The clean run also caught a real gap: with no seed there are no roles,
so the migration's grants insert nothing — the seed catalogue therefore carries
the same matrix, and the drift test gained a fourth reader rather than an
exemption.

### CP2.1 — the 58-versus-57 reconciliation

Both schemas were rebuilt and their table-name **sets** compared. Exactly one
table differs: `_prisma_migrations`, Prisma's own bookkeeping, absent from the
clean copy only because that copy was built with the `mysql` client. Every
business table is identical, and both match the schema's 57 mapped models
exactly. A real clean deployment runs `prisma migrate deploy`, which creates it,
so a genuine clean deployment has 58 like dev. No corrective migration was
written — adding a schema change to fix a difference that does not exist in a
real deployment would be a change made to satisfy a miscount.

### Accounting, stated precisely

Gross refund is `price × quantity − discount` from the immutable line — the
**same expression the rollup uses for revenue**, so a reversal cancels exactly
what the sale created. Revenue falls by the NET refund, because anything
withheld as an adjustment is money the shop kept.

**COGS is deliberately not credited back.** The returned phone is held as
`faulty` and `held-value` counts only `in_stock`, so crediting the cost while
the asset is absent from inventory would book the same benefit twice and flatter
the month. `returns_cogs` exists and stays 0 until the inspection milestone.

### Two defects live verification found

1. **The notifier wrote a `data` field that does not exist on `Notification`.**
   Prisma rejected it and the global filter reported **"Invalid query
   parameters"** — that message is emitted for any `PrismaClientValidationError`
   regardless of cause, which cost real debugging time and is worth revisiting.
2. **The existing deduplication mechanism was being ignored.** Fixing (1)
   revealed that `Notification` already carries `payload`, `actionLink` and a
   `dedupeKey` with a UNIQUE index, built in H1.3 precisely so a duplicate is an
   insert the database refuses rather than one the application tries to avoid.
   Retried delivery now uses it.

### Verification

Backend **65 suites / 935 tests**, `tsc` clean, `prisma validate` valid, **36
migrations**, schema up to date.

**62 of 63 live HTTP checks passed** against real MySQL on the first clean run,
including: idempotent replay, changed-payload 409, a second active claim
refused, identifier mismatch refused, employee cannot review/approve/adjust,
custody intake moving the exact unit to `returned`, repeat intake idempotent, a
returned phone refused for sale, stale version 409, server-calculated adjustment
totals, adjustments over gross refused, manager refused an out-of-policy
approval, owner refused without a reason then approving with one, exactly one
reversal, a second approval refused, an approved return not then rejectable,
sales/items/payments/closings unchanged by checksum, the rollup reporting the
return on its approval day, and the legacy endpoint still 410 and mutation-free.

The single failure was **the harness's own assertion** — it compared a MySQL
`DATE` through `String()` against an ISO slice. The recorded approval date was
already correct (`2026-08-15`, confirmed independently from audit row 900). The
assertion is fixed for future runs.

### Demo-data integrity, and what the run legitimately left behind

Sales, sale items, payments and closings fingerprinted identical before and
after. 0 return requests and 0 reversals remain; the legacy `returns` table is
still empty.

**Reported, as required:** the run created **8 append-only audit rows** (281 →
289), preserved. Because `audit_logs.user_id` references them, **3 probe users
could not be deleted** and were deactivated and renamed
`i2p9b1b04_{own,mgr,emp}_spent`. Deleting them would have required editing audit
history. A future phase may want probe identities that never touch audited
paths, or an agreed retention rule for spent probes.

The demo Owner password was **not** changed. Temporary credentials were
generated in memory, never printed, written, committed or sent.

### Not done, and the exact next action

**CP5 — the mobile Returns workflow** has not been started: no navigation entry,
list, detail, request form, custody confirmation, investigation UI, adjustment
lines, approve/reject actions or EN/AR strings. **CP6** — the full verification
matrix (mobile typecheck, lint, Expo Doctor, web export, mobile suites) — has
not been run, because there are no mobile changes to verify.

The next session should build CP5 against the live API, then run CP6.

**Commits:** backend `bc5071d` · mobile `d4ee658` (unchanged) · docs the commit
carrying this entry. All three trees clean and level with `origin`.

---

## 2026-08-15 — CLAUDE-B — I2-CP4.1: the returned-inventory and COGS correction

Migration **`0037`**. Backend `404bee9` · docs the commit carrying this entry.
Mobile untouched (`d4ee658`).

### What was wrong, and it was mine

CP4 shipped `returns_cogs = 0` while a returned phone, held as `faulty`, was
excluded from every inventory figure. Together those are a **full write-off of
an asset the shop still owns**, decided before anyone has inspected the phone.
I had reasoned in `docs/27` §16.5 that crediting the cost while the asset was
absent from inventory would double-count — the reasoning was sound but the
conclusion was backwards. The fix was to stop the asset being absent, not to
withhold the credit.

### The corrected treatment

Approval reverses the line's revenue, credits its immutable COGS snapshot back,
and reinstates that same cost as faulty/return-held inventory value — owned,
never sellable.

    profit effect = − gross refund + adjustments + COGS credit

Cumulative profit across a sale and its return is therefore the adjustment
income alone, which is the honest position until an inspection decides whether
the phone is repaired, partially impaired or scrapped.

The credit and the asset are the same money, counted once: `returns_cogs` is the
unit's own cost and `faultyHeldValue` sums that same figure. A test asserts the
difference between the old and corrected profit effects is exactly the cost, so
neither can drift into double-counting.

### Reporting

`inventoryValue` has always meant sellable stock and still does. Added
`sellableInventoryValue`, `faultyHeldValue` / `faultyHeldUnits`, and
`totalOwnedInventoryValue`. `totalStockValue` keeps its documented meaning and
its guarantee that it does not move when stock is merely travelling. One number
cannot answer both "what can I sell?" and "what do I own?".

`DailyRollup` gained `returns_adjustments`; `DailyClosing` gained
`total_return_adjustments` and `total_returns_cogs_credited`. All positive
magnitudes, applied with an explicit sign.

### Migration and proofs

`0037` is additive and rerun-safe, guarded by `information_schema` probes
through prepared statements as `0036` is. Backup
`~/erp-backups/phonestore-i2cp41-20260815-030708.sql` (330 019 bytes, 58 tables,
6 triggers, 0 raw `_binary`) taken and restore-proven first. Applied to a
restored copy, rerun on it (645 columns before and after — unchanged), a clean
build of all 36 migrations (0001–0037, 0005 unused), and dev. Reverse SQL executed. `prisma_p41` and
`prisma_c41` dropped; sanitised copy removed. Dev unchanged: sales 7 /
10 051.00, units checksum `2a1dc9bf284afde32b402ad108d38a76`.

### Four failing assertions, and what each was

Two belonged to the CP4 spec and pinned the behaviour this replaces; they were
**updated rather than deleted**, so the file now records why the treatment
changed. Two were mine and simply wrong: one regex ignored the `COALESCE`
wrapper around the aggregate, and one claimed the rollup never joins products
when it legitimately does for its per-product facts — that assertion was
scoped to the returns query, because a file-wide version was asserting something
that had never been true.

### Verification

Backend **66 suites / 956 tests**, `tsc` clean, `prisma validate` valid, **37
migrations**, schema up to date. No live HTTP run was repeated for CP4.1; the
CP4 run remains the last live evidence, and CP6 must rerun the full lifecycle
with the corrected date assertion.

### Not done

**CP5 (mobile Returns workflow) and CP6 (full verification matrix) remain
unstarted.** The backend is complete and correct; no screen consumes it.

**Commits:** backend `404bee9` · mobile `d4ee658` (unchanged) · docs the commit
carrying this entry.

---

## 2026-08-15 — CLAUDE-B — I2-CP5 and CP6: Phase I2 complete

Mobile `c7dfadc` · docs the commit carrying this entry. Backend unchanged
(`404bee9`).

### The takeover found one discrepancy, and it was mine

The previous handoff said 37 migrations. There are **36**, numbered 0001–0037
with **`0005` unused** — a pre-existing gap, not a missing migration. Prisma
reports 36 found and the database records 36 applied. I introduced the wrong
figure in CP4.1 by misreading my own clean-build loop message, and it had spread
into `docs/27` and this log. Corrected in all three, because the alternative is
the next reader hunting for a migration that never existed.

### CP5 — the mobile workflow

Three routes (`/returns`, `/returns/new`, `/returns/[id]`) plus a custody sheet
and an investigation sheet, built on the existing design system, scanner,
dialog, toast, status registry and permission catalogue. No new infrastructure.

The wording is the substance. Every figure is provisional until approval and
agreed after it; an approved return says **"refund due — payment has not yet
been confirmed"** beside "the phone is held and is not for sale". **The word
"refunded" appears nowhere in I2**, because nothing has been.

`approved_refund_due` is toned `info`, not `success`: the shop now owes money it
has not paid, and green reads as "settled".

Status comes from the shared registry, so colour without words is not
expressible — adding the three return domains was a type error until their EN
and AR strings existed. 871 keys each side, verified equal.

Actions are gated by permission **and** lifecycle, so a reachable route never
implies an available decision. Approve is disabled until the phone is held;
customer-damage warns that only the Owner can approve *before* a manager tries;
the exception path demands a reason and never falls back to normal approval. A
409 is never retried — the server already decided, so the screen refreshes and
shows what won. One `clientUuid` per logical request, reused across retries.

Cost renders **"Hidden"** when gated, never `0`. "Request return" appears only
on serialized sale lines.

### CP6 — a genuinely green run

**74 live checks, 0 failed** against real MySQL. The earlier 62/63 run predated
CP4.1 and was replaced rather than explained away. Two obsolete assertions in the
harness were corrected as part of getting there: one expected `returns_revenue`
to be the net refund, which CP4.1 deliberately changed to the gross, and one
compared a MySQL `DATE` through `String()` against an ISO slice.

Accounting proved against the database: gross = immutable line revenue, COGS
credit = immutable line cost, net = gross − adjustments, profit effect =
− gross + adjustments + COGS credit, adjustments counted once, the unit `faulty`
with its cost preserved, excluded from sellable stock and carried in
faulty-held. Sale, sale items, payments and closings byte-identical.

### Verification identities, reused rather than multiplied

The three probes CP4 could not delete — `audit_logs.user_id` references them and
audit history is append-only — were reactivated for the run with a password that
existed only in the process, then returned to deactivated spent state. **No new
permanent identity was created.** Total users remains 9.

### Integrity after the run

Sales 7 / 10 051.00, units checksum `2a1dc9bf284afde32b402ad108d38a76`, unit
statuses back to `in_stock=3, sold=8`, 0 return requests / reversals /
adjustments. Notifications returned to **41**: the 39 the runs created pointed at
returns that no longer exist and are not append-only, so they were removed. Audit
grew **289 → 305** and every row was preserved — 16 append-only records of what
the verification legitimately did.

The demo Owner password was not touched. The verification server on 3099 was
started by this session and stopped; no process belonging to the user was
affected.

### Verification totals

Backend **66 suites / 956 tests**, `tsc` clean, `prisma validate` valid, 36
migrations, schema up to date. Mobile `tsc` and `expo lint` clean, web export
lists all three new routes, EN/AR parity exact.

### Next

**I3 — refund payout confirmation**, the receiving-account/payment record,
refund receipt and PDF sharing, and any remaining accessory settlement. Not
started. Also open: cost recovery for phones held `faulty` (`returns_cogs`
exists for it), supplier reimbursement, customer-credit settlement, technician
inspection, independent quantity returns, and the device pass in `docs/24` §9e.

**Commits:** backend `404bee9` · mobile `c7dfadc` · docs the commit carrying
this entry.

---

## 2026-08-15 — CLAUDE-B — Phase I3 (CP1–CP3): refund settlement, backend only

Migration **`0038`**. Backend `79e1e0e`, `1687322` · docs `1e8ba6f` and the
commit carrying this entry. **Mobile untouched (`c7dfadc`).**

**I3 is NOT complete.** CP1–CP3 are done, verified and pushed. **CP4 is partial,
and CP5 (mobile), CP6 (PDF) and CP7 (live verification) were not started.**

### Takeover

Every claim verified and matched: backend `404bee9`, mobile `c7dfadc`, docs
`f45bfa1`, 66 suites / 956 tests, 36 migrations through `0037` with `0005`
unused, schema up to date, mobile CP5 routes present, I2 live 74/74, three clean
trees, `READY_FOR_HANDOFF` under owner `NONE`. **No discrepancies** — the first
takeover this session where nothing needed correcting.

### The audit decided the shape (CP1)

**An outgoing refund cannot reuse `Payment`, and must not.** Two independent
reasons: `payments.sale_id` is required, so a refund would attach itself to a
sale it merely reverses and make that sale's payment history untrue; and its
only consumer computes `expectedCash` as the sum of cash payments, so a refund
row would be counted as money the shop **received**. A negative amount would be
worse — silently flipping the sign of a column every other reader assumes is
positive.

**`ReceivingAccount` is safely reusable.** It holds a provider, a label and an
active flag — no balance, no credentials, no direction — and answers "through
which channel?", which is the same question either way. Its own comment already
anticipated money movement being recorded against it. A second account system
would duplicate the Owner's configuration, and two lists of the same accounts
drift the moment one is edited.

### Schema (CP2)

`RefundPayout`, one per approved return, with UNIQUE on both the request and the
reversal, `clientUuid` idempotency, a CHECK that the reported amount equals the
amount due, and a CHECK tying the confirmation fields to the confirmed status in
both directions.

Only DELETE is blocked by trigger, not UPDATE. A payout is legitimately
corrected while it awaits confirmation; deleting a settlement is never a
correction, it is the disappearance of a record that money left the till.

Proven on a restored copy, a rerun, a clean build of all 37 migrations and dev,
with the reverse SQL executed and demo checksums unchanged. Both temporary
databases dropped.

### Report, correct, confirm (CP3)

The report is a **claim**; the confirmation is the **record**. Employees report,
Owner and Store Manager confirm — the separation is the control, because if the
person who says money left the till could also certify it, the second step would
be decoration.

The amount is never the client's: it must equal the immutable net refund due,
compared in cents, with no partial payout. A refund of **zero** is refused
outright — adjustments can legitimately consume the whole refund, but then
nothing is handed over and a payment record would assert something that never
happened.

**Confirmation creates no second profit effect.** Profit was reversed at
approval; confirmation moves cash only, and the confirmation-day rollup query
has no profit column at all. Taking it twice is the double-count this phase
exists to avoid.

`expectedCash` now subtracts confirmed cash refunds. Before this, a day with a
confirmed cash refund would have reported a shortage that was not one — the
money was handed back on purpose.

A replay of a successful confirmation returns the confirmed result rather than
refusing: somebody who lost the response must not be told they failed.

### Two assertions of mine that were wrong

One sliced the service file to end-of-file and caught `moveUnitForCustody`'s own
**definition** in the internals section — an assertion that fails on a
declaration is one somebody eventually weakens rather than reads. Scoped to the
refund methods. The other referenced `refundedCash` above its declaration in
`closing.service`; it now reads the figure from the rollup directly.

### Verification

Backend **67 suites / 992 tests**, `tsc` clean, `prisma validate` valid, **37
migrations**, schema up to date. Demo data untouched: sales 7 / 10 051.00, units
checksum `2a1dc9bf284afde32b402ad108d38a76`.

**No live HTTP verification was run for I3.** The backend is proven by unit
tests only — and this project's history is that the suite passes while the first
real request fails (`role: { permissions }`, `?limit=`, the 500 on a malformed
sale id, the notifier's non-existent `data` field). **CP7 must not be skipped.**

### Not done, and the exact next action

CP4 has its rollup components, closing snapshot and corrected `expectedCash`,
but no reconciliation view exposing approved / due / reported / confirmed, and
no outstanding-liability reporting. CP5, CP6 and CP7 are untouched.

Next session: build the mobile report/confirm UI on the existing Return detail
screen, then the PDF receipt, then the live lifecycle. Reuse the three
`i2p9b1b04_*_spent` probes rather than creating more.

**Commits:** backend `1687322` · mobile `c7dfadc` (unchanged) · docs the commit
carrying this entry.

---

## 2026-08-15 — CLAUDE-B — I3 CP4 and CP4.5 (refund reconciliation, then live proof)

**Repositories:** backend `886d71d` → `71dcbeb`; docs `ef7d906` → this entry.
Mobile untouched at `c7dfadc`.

**CP4 — reconciliation reporting.** Added `refundSummary()` and
`GET /v1/returns/refunds/summary`, declared before `:id` or Nest reads "refunds"
as a return id. Outstanding liability is **derived** — immutable approved
reversals minus confirmed payouts, over all time, because a debt does not expire
when a reporting period ends and nothing mutable in between should be able to
move the figure. Moved the receiving-account label snapshot from confirmation
back to **report** time, with confirmation freezing what is already there: a
rename between the two must not retitle a movement that already happened, and a
deactivated account must not strand a refund already owed. Added
`refund-reconciliation.spec.ts`. 68 suites / 1012 tests.

**CP4.5 — live API smoke test, run before any mobile work.** 51 checks over real
HTTP using the three spent probes. First run: **45 passed, 6 failed.**

One failure was mine (a `@Post` replay returns 201, not the 200 I asserted). The
other was a genuine defect: the receipt endpoint **400'd**. `refundReceipt`
called `this.db.company.findFirst()`, but the tenant extension injects
`companyId` into every tenant model's `where` and `companies` has no such
column, so Prisma rejected the query — and the global filter reported it as
"Invalid query parameters", the same misleading message already recorded as
technical debt. It has now hidden a real bug twice. Fixed by reading the company
*through* the branch relation, which is a tenant model: same data, one query
instead of two. Rerun: **51/51.**

That makes five occasions in this project where the full suite passed while the
first real HTTP request failed. The smoke-before-UI ordering in the brief was
correct, and no mobile screen was ever built against the broken endpoint.

**Data safety.** Smoke fixtures removed (`refund_payouts` 0, `return_requests`
0); audit rows deliberately kept — 325 audit logs, 41 notifications. Demo data
unchanged: sales 7 / 10 051.00, units checksum
`2a1dc9bf284afde32b402ad108d38a76`, `in_stock=3 sold=8`. The three probes were
returned to deactivated spent state by the harness's `finally` block on every
run, including the failed ones; no new user was created. The verification server
was stopped and port 3099 released. All scripts lived outside every repository.

**Not done: CP5, CP6, CP7** — the mobile report/confirm UI, the PDF receipt, and
full adversarial verification. Left cleanly unstarted rather than half-built.


---

## 2026-08-15 — CLAUDE-A — **I3 CP5, CP6, CP7: paying a refund from the phone**

**Takeover.** Clean, from `READY_FOR_HANDOFF`/NONE returned by CLAUDE-B. Verified
before touching anything: backend `71dcbeb`, mobile `c7dfadc`, docs `838d800`,
**68 suites / 1012 tests**, 37 migrations through `0038`, schema up to date, all
three trees clean and level. Every expected value matched. **CP1–CP4.5 were not
redone and CLAUDE-B's attribution stands.**

### CP5 + CP6 — the mobile workflow and the receipt (mobile `90517c7`)

**The contract was read over real HTTP before any screen was written**, because
the handoff's own standing lesson is that a green suite has hidden a broken
first request five times in this project. That probe corrected three things a
code reading had got wrong: the `responsibility` enum values, that approval
outside the policy needs an `exceptionReason`, and that confirm takes the
**payout's** version rather than the return's.

Three states, worded so they cannot be confused: money owed, money somebody
*says* they handed over, and money a manager has vouched for. Only the last is
green. The phone stays held and unsellable in all three.

The amount is displayed and locked. Method is `cash` or `account` only —
the DTO accepts nothing else, so no "Other" was invented. An account must be
active to be *chosen*, but an already-recorded one stays confirmable after
deactivation. The label shown is always the stored snapshot.

One `clientUuid` per report, held in a ref. Confirmation is high-friction and
lists everything being vouched for; nothing is marked confirmed locally.

The receipt reuses the sale receipt's `expo-print`/`expo-sharing` path — no new
dependency — and is generated **only** from the confirmed-refund endpoint. It
masks the IMEI, escapes everything dynamic, and claims no provider verified
anything.

### CP7 — 55 live checks, 0 failures

Two runs against a **separate backend on port 3111** and real MySQL, reusing the
three `i2p9b1b04_*_spent` probes with a password that existed only in the
running process.

**Lifecycle 47/47** covering all 28 points of the brief, and **expected cash +
locked day 8/8** — including confirming into a closed day, refused with 409 and
the payout left pending.

**One real defect, found by running it:** `money.provisional` was hardcoded
`true`, so an approved return described its own immutable, already-reversed
figures as provisional. The I2 screen derived its wording from `status` and so
was never wrong to a user, which is exactly why nothing noticed — but I3's
refund screens read the money block directly. Fixed in backend `74c6757`,
extracted into `isProvisionalMoney()` and given tests.

**Four first-run failures were my verification script's errors, not defects** —
a guessed enum, a missing exception reason, the wrong reversal cost column and
the wrong legacy route. Recorded, because a verification script lies as readily
as the code it checks. A fifth apparent failure was a stray `daily_digests` row
my own earlier cleanup had missed, which blocked closing the day.

- **Files changed:** mobile — `lib/{returns,refund-receipt,permissions,query-keys}.ts`,
  `components/returns/{RefundPayoutSheet,RefundSections,RefundReconciliation}.tsx`,
  `app/returns/[id].tsx`, `app/closing.tsx`, `types/api.ts`, `lib/i18n/{en,ar}.ts`.
  Backend — `src/returns/{returns.service,return-workflow,return-workflow.spec}.ts`.
  Docs — `21`, `24`, `27`, handoff, this log.
- **Migrations:** none. CP5–CP7 needed no schema change.
- **Tests:** backend **68 suites / 1017 tests**; mobile `tsc` and `expo lint`
  clean, EN/AR both **943 keys**, web export **37 routes**, 15 pure Node tests.
- **Fixtures and cleanup:** every return, payout, reversal, adjustment, closing
  and digest created by this session was removed; notifications are back to
  **41**; the probes are deactivated and spent; total users remains **9**.
  **Audit grew 325 → 459 — 134 append-only rows, preserved and reported.**
  Demo data identical: sales 7 / 10 051.00, units checksum
  `2a1dc9bf284afde32b402ad108d38a76`, `in_stock=3 sold=8`.
- **Ports:** 3111 started by this session and released. The user's processes on
  8081, 3010 and 80 were never touched.

### 🔴 Not verified, and not claimed

**Nothing was exercised on a physical device or in a visible browser.** Camera,
haptics, native share, the PDF's appearance, bottom-sheet gestures and Arabic
**visual** RTL are unverified. `docs/24` §9f lists 28 checks for a device pass.

**Commits:** mobile `90517c7` · backend `74c6757` · docs, the commit carrying
this entry. All three trees clean and level with `origin`. `READY_FOR_HANDOFF`,
owner `NONE`.


---

## 2026-08-15 — CLAUDE-A — **Phase J: supplier operations and payables (`0039`)**

**Takeover.** Clean, from `READY_FOR_HANDOFF`/NONE. Verified before touching
anything: backend `74c6757`, mobile `90517c7`, docs `0b2a496`, **68 suites /
1017 tests**, 37 migrations through `0038`, schema up to date, all three trees
clean and level. Every expected value matched.

### J0 — the audit, before any SQL (docs `e0ea5cf`)

`SupplierPayment` already existed and was almost unused: one code path writes
it, for the down payment taken at receiving, with the method hardcoded to cash.
No lifecycle, no version, no client uuid, no account, no confirmer. **A supplier
paid after the goods arrived could not be recorded at all.**

`Supplier.balance` was a stored counter incremented in one place and never
recomputed; `Purchase.status` was decided once at creation and never updated.
Both were authoritative only until something happened to them.

`GET /suppliers` was unguarded and returned every supplier's balance to anyone
signed in — against the rule that the ledger belongs to Owner and Manager.

Reusing Sale `Payment` would make a supplier payment look like sales income,
the same trap I3 documented. The I3 report/confirm **shape** generalises and was
copied deliberately; the **table** does not, because a refund is one per return
with a locked amount while a supplier payment is many, partial and allocated.

Live data was consistent — 3 suppliers, 9 purchases all unpaid, 11 185
outstanding, every stored balance matching the derived figure — so J1 started
from a clean state.

### J1-A — migration `0039` (backend `f459a76`)

Two tables and two permissions. The money rules are database rules, exercised
**11/11** against real MySQL, including two that had to be redone because the
first attempt was blocked by a different foreign key and therefore proved
nothing.

Two things the plan did not anticipate: MySQL error 3823 forced the
receiving-account foreign key to `RESTRICT` on both actions (without it the
method/account CHECK cannot exist at all), and the `permissions` table has a
`label` column rather than `description` — the first deploy failed on it.

### J1-B — the ledger and the payment workflow (backend `3cbe846`, `393f6fb`)

Outstanding is derived every time. Purchase totals are never rewritten;
`amountPaid` and `status` are projections of the allocations. The list stops
handing every supplier's debt to everyone — it stays open, because receiving has
to pick a supplier, but the money is **absent** for anyone without permission.

Allocation is always explicit; oldest-first is a suggestion that is returned and
shown. Overpayment is refused three ways, the last inside the confirmation
transaction against committed rows, which is what stops two managers overpaying
the same debt.

The closing gained the other thing that leaves the till: before this, a day the
shop paid a supplier in cash reported a shortage that was not one.

**Two existing assertions needed correcting, both reading prose as code** — one
flagged a comment saying "not an expense" as treating a refund as an expense,
and one of my own caught the legitimate persistence of the new columns.

### J1-C — the mobile screens (mobile `a5e7316`)

`/suppliers`, `/suppliers/[id]`, `/suppliers/new`. Same wording discipline as
refunds: owed is a warning, reported is still not paid, only confirmed is a
success. The payment sheet shows **which deliveries** the money settles before
anything is sent.

**A breaking change TypeScript could not catch:** the list became paged and
`app/receive.tsx` still typed it as a bare array. `api.get<T>` is an assertion,
so the build stayed green while the picker would have shown nothing. Found by
reading the call site.

### J1-D — live verification

**52/52** against a separate backend on **port 3112** and real MySQL, reusing
the three spent probes.

**One real defect, found by running it:** `GET /suppliers/not-a-uuid` returned
**500**. `uuidToBin` throws a plain Error and the global filter maps it to a
server error; the returns module already guards with `isUuid` and suppliers did
not. Fixed in `393f6fb`.

- **Files changed:** backend — `prisma/schema.prisma`,
  `prisma/migrations/0039_supplier_settlement/`, `src/suppliers/*`
  (`payable.ts`, `payable.spec.ts`, `settlement-migration.spec.ts`,
  `dto/supplier.dto.ts` new), `src/closing/{closing.service,closing.module}.ts`,
  `src/returns/refund-reconciliation.spec.ts`. Mobile — `lib/suppliers.ts` (new),
  `components/suppliers/SupplierPaymentSheet.tsx` (new), `app/suppliers/*` (new),
  `app/receive.tsx`, `types/api.ts`, `lib/{permissions,query-keys}.ts`,
  `lib/i18n/{en,ar}.ts`. Docs — `21`, `24`, `28` (new), handoff, this log.
- **Migrations:** `0039_supplier_settlement`.
- **Tests:** backend **70 suites / 1070 tests**; mobile `tsc` and `expo lint`
  clean, EN/AR both **1025 keys**, web export **40 routes**, pure suites 15 + 24.
- **Fixtures and cleanup:** every settlement, allocation and probe supplier
  removed; purchase projections and cached balances restored; probes deactivated
  and spent; users remains **9**; both scratch databases dropped; port 3112
  released. **Audit grew 459 → 483 — 24 append-only rows, preserved and
  reported.** Demo data identical: sales 7 / 10 051.00, units checksum
  `2a1dc9bf284afde32b402ad108d38a76`, `in_stock=3 sold=8`, notifications 41.

### 🔴 Not verified, and not claimed

**Nothing was exercised on a device or in a visible browser.** `docs/24` §9g
lists 23 checks.

**No post-confirmation correction exists** for a supplier payment or an I3
refund. Deliberate, but a genuine mistake has no route back — now the most
significant open gap in the financial workflows.

Also open: stock can still enter without a payable through `upsertStock`; a
payable is tax-inclusive while inventory cost is not (agreeing only because tax
is always zero); and supplier liability is company-wide with no per-branch
total.

**Commits:** backend `f459a76`, `3cbe846`, `393f6fb` · mobile `a5e7316` ·
docs `e0ea5cf` and the commit carrying this entry. All three trees clean and
level with `origin`. `READY_FOR_HANDOFF`, owner `NONE`. **Analytics polish not
started.**

---

## 2026-08-15 — CLAUDE-B — UX redesign foundation, checkpoints 1–4 of 9

**Repositories:** mobile `a5e7316` → `3bfc7fb`; docs `750fb27` → this entry.
Backend untouched at `393f6fb`.

**Takeover.** Every expected value matched with no discrepancies: backend
`393f6fb`, mobile `a5e7316`, docs `750fb27`, 70 suites / 1070 tests, migration
`0039` applied, schema up to date, 40 exported routes, EN/AR 1025 keys, all
three trees clean and level, `READY_FOR_HANDOFF`/NONE.

**The audit (`docs/29`) changed what this milestone was.** The brief anticipated
a design problem. There wasn't one: `lib/design/` and `components/ui/` are
sound, and the whole tree contained exactly two raw hex literals, both inside
primitives. What had happened was that a migration onto that system started,
stalled, and was never finished — and the unmigrated remainder was not a random
tail. It held the role landing screen, the More menu, the branch picker, daily
closing, analytics, and the screen you reach by scanning a phone. Two shims say
so in their own words; both were still present.

Two findings outranked everything aesthetic, and neither was visual.

**Six user-facing screens had zero i18n imports.** An Arabic-speaking employee
met English at the branch picker, the home screen, the entire More menu, daily
closing, and after every scan. The project's "EN and AR both 1025 keys" check
is *structurally blind* to this — the strings were never keyed, so nothing was
missing from either file. A key-count check is not an i18n check, and this one
would never have caught it.

**The entire Phase J supplier payables workflow was unreachable by tapping.**
Three routes exported; nothing linked to them. The report/confirm payment
workflow shipped complete and worked only if someone typed a deep link.

Both were found by measuring the source, not by looking at screenshots.

**What shipped.** Tokens gained money variants with tabular figures, icon and
density scales, and an accent focus ring. Refining them surfaced a real
accessibility defect: `SegmentedControl` dimmed its track to 0.4 *and* drew its
label in `text.disabled`, compounding to roughly 1.3:1 — not low-contrast but
absent. `disabledOpacity` is now 0.55 and the rule is written where it will be
read: dim the container or use the disabled colour, never both.

Five primitives were added — `MoneyValue`, `InlineNotice`, `PermissionNotice`,
`OfflineBanner`, `WorkflowTimeline` — and no second Button, Card or action-bar
system: `Screen` already owned the sticky footer. `MoneyValue` fixes something
worse than inconsistency: a withheld cost and a genuine zero were rendered by
whatever each call site felt like, and showing `0.00` to someone without
`cost.view` is a lie about the shop's money.

The offline banner deliberately avoids a connectivity library. A shop's problem
is almost never a missing radio; it is wifi that is up while the internet is
dead. A radio indicator reports "online" in exactly that case — worse than
showing nothing, because staff would trust it. The signal is a real `fetch`
rejection, which `lib/errors.ts` already classified as offline, and any
response including a 4xx proves the server was reached.

Home was rebuilt. It used to require `report.view` and redirect everyone else,
which meant two of three roles had no landing screen at all. It is now gated
section by section, pending work leads, store health reads as a sentence rather
than `92 · GREEN`, and Suppliers is reachable by tapping for the first time.
Also removed the duplicate More row where "Branch" and "Switch branch" called
the same handler.

**Not done, and not started rather than half-built: four of the five pilots** —
Sell, Inventory, Supplier and Return detail. `WorkflowTimeline` exists and is
demonstrated in the gallery, so the due/reported/confirmed distinction is proven
in the component but **not yet in a screen**. Five screens remain hardcoded
English.

**Verification.** Mobile `tsc` and `expo lint` clean, 40 routes still export,
EN/AR both 1059 keys, zero raw hex in `app/` and `components/`. Pure suites 5 of
6 — `transfer-draft.test.ts` still fails on the renamed `addToDraft` export,
pre-existing since `112e035` and already a carried-forward open item.

**No device pass was run, and nothing visual is claimed as device-verified.**
`docs/24` §9h is the script, and it states plainly which items a web export
structurally cannot answer: Hermes ICU numeral shaping, whether `tabular-nums`
is honoured by the platform font, safe-area insets on a notched phone, haptics,
and legibility in sunlight.

No backend change, no migration, no fixtures, no probes, no ports, no user
process touched.

---

## 2026-08-15 — CLAUDE-B — Milestone A checkpoints 5–8 (intermediate)

**Repositories:** mobile `3bfc7fb` → `b0b3e08`; docs `347a2e4` → this entry.
Backend untouched at `393f6fb`.

**Resumption.** Every expected value matched: three repos clean and level,
migration `0039` applied, mobile `tsc` clean, EN/AR 1059, UX1–UX4 committed,
`READY_FOR_HANDOFF`/NONE. Ownership reclaimed; nothing from UX1–UX4 redone.

**The transfer-draft suite was repaired rather than carried forward again.** It
had been failing since H1.4 and had survived several sessions as a "known
pre-existing" item. The cause was not a regression: H1.4 split the draft into
serialized and quantity lines, and the test was never moved across — it imported
names that no longer existed, so the file died at import and every rule it
guarded was silently unguarded. One assertion could not be carried over as
written, because the rule it proved is gone by design: a quantity product used
to be refused, and now merges, since scanning the same box of cables twice means
two of them. The test proves the merge instead, plus the availability ceiling
and the nothing-free case. 14 checks pass.

**Sell.** Below-cost was only ever said in the dialog after Charge was pressed —
by which time the cashier has quoted the customer a price, and learning the sale
needs a manager makes the shop look disorganised in front of them. The warning
now sits in the cart beside the money. It appears only when every line's cost
came back: without `cost.view` the server strips it and `cartCost` returns
undefined rather than guessing, so that cashier gets no warning and the server
still refuses the sale. Charge is also shut while offline, since a sale taken
then fails at the server *after* the customer has paid.

**Return detail.** The screen rendered the server's append-only event log as a
flat column of identical rows — faithful, and the wrong answer to "where has
this got to and what has not happened yet", because an event log structurally
cannot show a stage that has not occurred. `lib/return-timeline.ts` maps the
lifecycle instead and `WorkflowTimeline` gives each stage a shape before a
colour.

The rule now pinned by eight assertions: **a reported payout is never done.** It
renders `current`, warning-toned, because a green tick reads as "someone paid
this" before an owner or manager has agreed the money left. Only confirmation is
allowed to look settled. A rejected return drops the money stages entirely
rather than greying them out — greyed-out stages would imply something is still
owed, and nothing is.

**Supplier (partial).** The ledger column is now tabular, and a withheld figure
renders as an em dash rather than as something resembling "you owe nothing". The
list screen and settlement rows are still on `formatMoney`.

**Verification.** `tsc` and `expo lint` clean, 40 routes export, EN/AR both
1068, zero raw hex in `app/` and `components/`, **all seven pure suites green**.
No device pass; nothing visual claimed as device-verified.

**Not done: A6 (Inventory), A9 (localise five screens), and the rest of A7.**
No backend change, no migration, no fixtures, no probes, no ports.

---

## 2026-08-15 — CLAUDE-B — Milestone A complete, Milestone B CP1

**Repositories:** mobile `3bfc7fb` → `9789856`; backend `393f6fb` → `eb0278c`;
docs `6afc479` → this entry.

**Milestone A finished.** A7 completed the supplier money conversion, A6 gave
Inventory the cost it already received from the server but never displayed, and
A9 translated the last six hardcoded-English screens.

A9 was the one that mattered. Branch selection is the first screen after
signing in — an Arabic-speaking employee met English before they had done
anything at all — and the unit screen is where every camera scan lands. Three
things there were not merely untranslated but wrong: unit status was rendered by
`replace('_', ' ')`, which produced English in both languages; the More menu
showed the signed-in role the same way; and branch selection showed the branch
type as a raw enum. All three now go through the status registry or a key, so a
word always accompanies the colour.

Gate: `tsc`, `expo lint`, Expo Doctor 18/18, 40 routes, EN/AR both 1140, seven
pure suites green, zero raw hex outside the token layer.

**Milestone B CP1.** The correction design turns on something the codebase
already does: both liabilities are *derived* from rows whose status is
`confirmed`. So a correction writes nothing back to the row it corrects and
decrements no counter — it restores the liability by existing, once the
derivation queries exclude any target carrying an approved correction. That
makes "restored exactly once" and "no double correction" properties of the
schema rather than things the application must remember.

At most one approved correction can exist per target, enforced by the
partial-unique trick from `0002`: a VIRTUAL column holding the target id only
while approved. Proven against real MySQL — a second approved correction on the
same target is refused as a duplicate key, while further requested and rejected
ones are still allowed.

**A real drift from Phase J was found and fixed.** Migration `0039` grants
`supplier.payment.*` to the store roles and the seed matrix never did, so a
migrated company could report a supplier payment and a freshly seeded one could
not. The drift test did not catch it because `0039` was missing from its own
hand-maintained list of later grants — the list that exists precisely to catch
this. Both are fixed, and the Owner permission count assertion now records that
it moved late rather than silently.

**Verification.** Backend 70 suites / 1070 tests, `tsc` clean, `prisma
validate` valid, 39 migrations, schema up to date. Migration `0040` proven on a
restored copy, a rerun and dev; seven constraints exercised against real MySQL;
both scratch databases dropped. Backup `phonestore-b0-20260815-174119.sql` —
404 752 bytes, 61 tables, 7 triggers, 0 raw `_binary`, restore proven *before*
migrating with the units checksum identical.

**Not done: B-CP2 to B-CP4, and Milestone C.** The next action is the one that
actually restores liability — excluding corrected targets from the two
derivation queries. Without that edit the correction record exists and changes
nothing, which is exactly the kind of half-built financial change that must not
be mistaken for a finished one.

---

## 2026-08-15 — CLAUDE-B — Milestone B CP2

**Repositories:** backend `eb0278c` → `3044a09`; docs `c3b61ec` → this entry.
Mobile untouched at `9789856`.

**The migration alone changed nothing.** CP2 is the part that makes a
correction real: four derivation queries now exclude any payment carrying an
approved correction — the supplier list balance, per-delivery outstanding, the
paid-status recompute at confirmation, and the refund liability.

The refund exclusion goes in the JOIN rather than the WHERE. In the WHERE it
would filter the whole row out and the liability would *vanish* instead of
returning — the opposite of the intent, and something that would have looked
perfectly healthy in a smoke test that only counted rows.

Equally deliberate is what is **not** filtered. The per-day rollup and the
confirmed-refund period totals stay exactly as they were. The original payment
really did happen on its day, that day's figures stand, and its closing may
already be locked; the compensating movement lands on the correction day
instead. Filtering both sides would remove the money twice, and getting that
split wrong in either direction is the easiest way to double-count in this
design.

Expected cash *adds* corrected cash rather than subtracting it — a correction is
the opposite movement, so on the correction day the drawer holds more than the
day's sales alone would explain. Cash only; an account correction never touched
the till.

The service writes to `financial_corrections` and nothing else. No sale, no
expense, no second return effect, and no profit component anywhere: profit was
reversed at return approval and a supplier payment never had one. Approval
refuses a locked day with the same conflict code the refund and settlement
confirmations already use, so the mobile handler needs no second branch.

The amount has no DTO field. It is copied from the target, so a wrong figure
has no route in — and the compensating movement posts to the branch that
*paid*, not the caller's active branch, since an owner may be standing in a
different shop when they approve.

**Verification.** 72 suites / 1115 tests (+45 correction checks), `tsc` clean,
`prisma validate` valid, 39 migrations, schema up to date. Both raw SQL
fragments were executed against real MySQL — they are `Prisma.raw`, so a syntax
error would surface only at runtime, never at compile time.

**Not done: B-CP3 (mobile) and B-CP4 (live lifecycle, receipt disclosure), then
Milestone C.** No live HTTP run for B yet, no fixtures on dev, no probe used.

---

## 2026-08-15 — CLAUDE-B — Milestone B complete, Milestone C CP1

**Repositories:** backend `3044a09` → `fe11142`; mobile `9789856` → `4b37d12`;
docs `129aa97` → this entry.

**Milestone B is done. The production blocker is closed:** a confirmed refund
payout and a confirmed supplier settlement can be corrected, through an
append-only compensating record and never by editing the original.

**The live lifecycle test found two defects that 1115 passing tests did not**,
which is the entire argument for running it.

The first: the rollup was never recomputed after an approval. The correction row
was written perfectly and every unit assertion about it held — but the
compensating movement reached nothing, so the liability came back while the till
still reported a shortage for money that had already returned.

The second was more interesting. A replacement payout was impossible, because
`0038` had made `return_request_id` unique on the reasoning that a return is
settled once or not at all. That was right when written and is still right in
spirit; what changed is that a corrected payout is no longer *live*. Migration
`0041` moves the constraint onto a generated column holding the return id only
while the payout stands, so any number of corrected payouts may exist while at
most one live one can. The invariant stays a database guarantee instead of being
demoted to an application check.

That needed one new column, `corrected_by_id` — a back-reference and nothing
more. No financial field is rewritten, and the accounting spec now pins exactly
that: the write must contain `correctedById` and none of seven named financial
fields, so "a link, not an edit" cannot quietly erode into a general licence to
update the payout.

The migration itself had to add plain foreign-key indexes *before* dropping the
uniques they sat on; MySQL refuses otherwise, and the first attempt failed
halfway — on a restored copy, which is where it should fail.

Two cleanup refusals were worth noting because both were the design working: the
append-only trigger refused the application user's delete, and the partial unique
refused to let a supersession marker be cleared while a replacement payout was
still live.

**Milestone C CP1.** The dependency gate passes as far as this environment can
verify: `@infinitered/react-native-mlkit-text-recognition` 5.0.1 — MIT, an Expo
module, on-device ML Kit with no cloud and no image leaving the phone, Android
and iOS. Expo Doctor 18/18, web export and `tsc` clean with it installed.

**It has never been executed, and the handoff says so.** It cannot run in Expo
Go and no development build can be produced here. Doctor passing is a
compatibility check, not a working camera.

The parser carries the safety argument and is pure, so every rule is testable
without a camera. One rule outranks the rest: never silently accept a guessed
digit. OCR confusions are systematic, and a plausible wrong IMEI is far worse
than a failed read — a failed read costs seconds, a wrong IMEI is a phone that
cannot be found, sold, returned or warranty-matched for the rest of its life. So
a substitution is offered only when the result still satisfies Luhn, and even
then every character change is listed for a human to agree to.

Dual-SIM: two IMEIs on one screen are one phone with two identifiers. Three or
more is reported ambiguous rather than resolved, because guessing which two
matter would invent data.

Writing the tests found a bug in the parser: the label lookup scanned backwards
from the first digit-like character and found the "I" in "IMEI" itself, since I
is one of the characters OCR confuses for a digit.

**Verification.** Backend 72 suites / 1119 tests, 41 migrations, schema up to
date. Mobile 8 pure suites, Doctor 18/18, 40 routes, EN/AR 1183, zero raw hex.
Live 41/41. Demo returned to baseline exactly — sales 7 / 10 051.00, units
checksum `2a1dc9bf284afde32b402ad108d38a76`, `in_stock=3 sold=8`. Audit grew
485 → 506 and was preserved. All scratch databases dropped, port 3099 released,
probes back to deactivated spent state.

**Not done: Milestone C CP2 to CP4** — the TAC audit and reuse, the three
scanner modes, and dual-SIM persistence.
