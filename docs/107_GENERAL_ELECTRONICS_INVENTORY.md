# 107 — General electronics inventory (D223)

Session: CLAUDE (local session, the owner's PC), 2026-10-27. The owner approved the brief and answered its four
questions the same day (§1). **Nothing deployed.** Nothing merged. No production data, server, DNS, firewall or
registration setting was touched; every migration ran only on disposable local databases.

## 1. The owner's decisions

| Question | Decision |
| --- | --- |
| Base branches | Finish SDK 58 first (D222, `docs/106`). Mobile builds from `sdk-58`; backend from `promoter-attribution` (its migration 0103 is the newest) |
| Price floor | **None.** The configured price is a suggestion the seller may change |
| Below cost | The Owner and Store Managers after a high-friction warning, with a reason; a Store Employee needs the approval of a Manager or the Owner |
| Brands | The 12 existing, plus HMD/Nokia, OnePlus, Motorola and Google Pixel, and the iPhone 18 family and iPhone Duo — each **only if the manufacturer lists it**; otherwise recorded as checked and not added |

## 2. What changed

Branches **erp-backend `inventory-general`** (from `promoter-attribution` `002e7f8`) and **erp-mobile
`inventory-general`** (from `sdk-58` `fca75c5`).

### 2.1 Categories (migration 0104)

- Every business has **61 built-in categories**: 16 top-level and 45 subcategories, one level deep (Phones ›
  Smartphones, Cables › USB-C, Networking › MiFi devices, …). Each has a stable `key`, a recommended tracking mode, the
  modes it allows, and its attributes. Registration seeds them in the same transaction; 0104 seeds them for every
  existing business.
- A shop's own category has no key. Its name is unique among the shop's own (a generated column); it may share a
  built-in's name. It may sit under a top-level category, and under a built-in it keeps that parent's allowed modes.
- A built-in can only be hidden or shown again (409 `builtin_category_fixed`); nothing is deleted. The app shows
  built-ins by key in English, French or Arabic, and a shop's own by its name.

### 2.2 Tracking modes

The category **recommends** the mode and the Owner chooses among the modes it **allows** (`resolveTrackingType`). A
built-in Phones category still cannot be counted, and Cables still cannot ask for IMEIs. A product re-filed under
another category keeps its mode when allowed, otherwise it takes the new recommendation, and is still refused while
stock or history exists.

### 2.3 Scanner-led intake, one transaction

- A receiving line names an existing product **or** a `newProduct` (no price, no cost). The catalogue's own rules
  validate it before the transaction, and it is written **inside the purchase transaction**: the product, its units
  or counted stock, the cost, the payment and the audit commit together, or none do.
- Only products whose lines are received are created. When every line is refused, nothing is written: there is never
  a product-only success.
- An existing brand, model and variant is refused with 409 `product_exists` and its id. Creating needs
  `catalog.manage`, asked again here.
- The result and a replay carry `createdProducts`. A request without a new product hashes exactly as before, so a
  retry pending across the change still replays.
- **App:** opened from a scan, the product form saves nothing. It hands a draft back (or the existing product, when
  one matches exactly), and **"Create product and add to stock"** sends both. "Created and added to stock" appears only
  after the server commits. A line left for correction is re-filed under the product the server created. Quick
  receive asks the buying cost only. Opened on its own, the form says that creating a product adds no stock.

### 2.4 The scanner

- **"Scan an item"**, pointing at an IMEI, serial number or barcode. The lock/state machine is unchanged and OCR
  stays retired.
- Before a product is drafted, the app **asks rather than guesses**:
  - a non-IMEI code is "this one item (its serial number)" or "the product model (a barcode on the box)", which
    decides the field it travels in;
  - an IMEI asks which kind of cellular device it is from (smartphone, feature phone, cellular tablet, smartwatch,
    MiFi), and opens the form in that category.

  Closing a question is never an answer.
- Fifteen digits failing the IMEI checksum are a mistyped IMEI at intake too, even as a serial (`isMistypedImei`):
  Sale already refused them, so such a unit could be received and never sold.

### 2.5 Selling (migration 0105)

- **No price floor.** A sale below the suggested price at a profit needs nobody.
- **Below cost:**
  - `sale.below_cost` (new; the Owner and Store Managers, by role) — a `loss.below_cost` caution acknowledged through
    the existing warning gate before anything is written, and a reason;
  - everyone else — an approval for that exact unit and price, decided by a `sale.below_cost` holder, and a reason.
    A counted line has no unit to approve, so an Employee asks a Manager to make that sale.
- Approvals are now only about cost; a moved set price no longer voids one. `discount.override` stays Owner-only for
  setting a price below cost (its label is unchanged; renaming it needs a migration of its own).
- The approvals queue, its wording ("a Manager or the Owner", "below cost") and the reason retry
  (`reason_required`) follow, in three languages.

### 2.6 Stock

`GET /inventory?categoryId=` lists a category with its subcategories, for units and counted stock alike; an id the
tenant cannot see matches nothing. The Stock tab's unit list has a Category chip.

### 2.7 The catalogue refresh (migration 0106)

Every added row was read from the manufacturer's own site and dated by a page of the manufacturer's.
`src/catalog/catalogue-refresh.ts` records both URLs for each row and every name checked and not added.

| Brand | Added |
| --- | --- |
| Apple | iPhone Duo, iPhone 18 Pro Max, iPhone 18 Pro (2026; Apple Newsroom, September 2026) |
| Google Pixel (new) | Pixel 6 to Pixel 11, including the a and Fold models — 24, each dated by its heading on Google's Pixel specifications page |
| OnePlus (new) | OnePlus 15, 13, 13R, 12, 12R, Nord 5, Nord CE5 (OnePlus press releases and launch pages) |
| Motorola (new) | razr ultra 2026, razr+ 2026, razr 2026, edge 2026/2025/2024, moto g stylus 2026, moto g power 2026, moto g 2026 (the year is Motorola's own model name) |
| HMD (new) | HMD Terra M, Fuse, Fusion X1, Barça Fusion, Touch 4G (HMD press releases) |

**Checked and not added:**
- Apple: iPhone 18, iPhone 18e and iPhone Air 2 — Apple does not list them.
- OnePlus 15R, Open and Nord N30 5G, and Motorola razr fold — no dated official page found.
- Fifteen HMD models listed without a year.
- Nokia-branded phones — HMD lists none.

No TAC, IMEI, storage, colour or specification was added. Rows stay `curated`, since `official` is reserved for a
licensed feed. The future weekly agent is **not** begun; it may only propose rows in this shape, never publish
unverified ones.

### 2.8 Found and fixed on the way

- **`product_exists` lost its `productId`.** The exception filter's allowlist dropped it; the end-to-end run found it.
- **Two new high advisories**, both through `@nestjs/platform-express`, whose own fix is a major version:
  - body-parser below 1.20.9 (GHSA-27r3-jxmh-p828);
  - multer below 2.5.0 (GHSA-q7qp-rjg7-q26m).

  The existing overrides moved to the patched releases. **`promoter-attribution` needs the same change.**
- The mobile security workflow on this branch reads the backend's `inventory-general`, where the built-in categories
  live. `ops/render-tests` gained `BACKEND_BRANCH`.

## 3. Verification

| Gate | Result |
| --- | --- |
| Backend TypeScript | clean |
| Backend unit suite (Windows) | 4,970 passed; the 5 failures are Windows-only (path separators, CRLF, one timeout) in files this branch does not touch |
| Backend security CI | success, run 40553387761 on `12fcaad` (includes the dependency audit) |
| Migrations 0104, 0105, 0106 | Rehearsed on disposable databases. 0104: a clean install, and an upgrade with existing data byte-identical. 0105: owner and manager granted in each company, the employee not. 0106: 13 → 17 brands, 323 → 371 models. **Each re-run changed nothing** |
| End-to-end journeys | **25/25** over HTTP. Disposable API on port 3999, database `erp_inv_e2e`, one fictional business; `scripts/d223-journeys.mjs` |
| Mobile TypeScript | clean |
| Mobile pure and rendered tests (Linux) | run 40553738099 on `985f995`: pure 124/124, rendered 364/364, both exports and bundle audits, web smoke |
| Mobile security CI | success, run 40552841468 on `985f995` |
| visual-check (Chromium, WebKit) | success, run 40553430599 on `985f995` with backend `12fcaad` |

What the journeys cover:
- categories: 61 built-ins, a subcategory, refusals of a counted Phones subcategory, a third level, a built-in rename
  and a duplicate name;
- intake: two new products, three phones and ten cables in one request; replay; a conflicting replay;
  `product_exists` with its id; a fully refused delivery leaving no product; the Employee refused; the mistyped-IMEI
  serial;
- stock by category;
- selling: at a profit without a set price; the Employee refused below cost, asking, a Store Manager approving, then
  selling; a Manager warned, nothing written, then selling after acknowledging.

## 4. Device QA (the owner's iPhone, Expo Go)

1. **Receive › scan a new phone's IMEI › Create product.** The question asks the kind of device; choose
   Smartphones. The form opens under Phones › Smartphones and says nothing is saved yet.
2. Fill brand and model › **Next: add to stock** › enter the buying cost › **Create product and add to stock**. Only
   now: "… created and added to stock". Stock shows the phone; Catalog shows the product.
3. Scan an accessory's barcode › Create product. The question appears; choose **The product model**. The barcode is
   prefilled on the product, never on a unit.
4. Scan a laptop's serial › choose **This one item**. The product is serial-tracked and the serial is on the unit.
5. **More › Catalog › Categories:** built-ins in the app's language (switch to French and Arabic); a built-in only
   hides or shows; add "Refurbished" under Phones.
6. **Stock › Category › Phones:** the phone from step 2 is listed.
7. **As an Employee,** sell a phone below its cost: the app asks a Manager or the Owner. **As the Manager,** approve
   in Approvals; the Employee sells at that price.
8. **As the Owner or a Manager,** sell below cost: a loss warning, then the reason, then the sale.
9. Sell below the suggested price but above cost: no question at all.
10. Turn the network off mid "Create product and add to stock", then on: retrying sends the same request and creates
    nothing twice.

## 5. Decision

D223 (`docs/21`).

## 6. Open

- **Merge** is not done. Order: `promoter-attribution` (with the dependency fix), then backend `inventory-general`;
  `sdk-58`, then mobile `inventory-general`.
- **Production migration** of 0104–0106 is a separate, owner-approved step, with a fresh backup (`docs/22`).
- The product detail screen shows a built-in category by the server's English name. It needs `categoryKey` in the
  product payload.
- The Stock summary's chips (Phones, Accessories, Other) are by tracking mode, not category.
- The `discount.override` label still says "below the set price".
- The weekly catalogue agent is deferred by the owner.
