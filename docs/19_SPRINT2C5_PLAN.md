# 19 — Sub-phase 2C.5 Plan: Generalization to Electronics Retail

> **Status:** PLAN for approval. **No code until approved.** Implements the pivot in [`18`](18_ELECTRONICS_RETAIL_PIVOT.md).
> Approved decisions: **D1** `product_categories` + `default_tracking_type` · **D2** typed identifiers (`imei_primary`, `serial_no`) + a generated universal `identifier`, IMEI intelligence kept separate · **D3** rename `imei → identifier` on new/changed APIs · **D4** all three tracking types in v1 · **D5** rebrand to *Electronics Retail Management System*.
> Adds: **Smart Product Scanner** + **adaptive (category-specific) product attributes** with no schema redesign to add attributes.

---

## 1. Goals
Make tracking type (`imei | serial | quantity`) drive every workflow; support IMEI, serial, and quantity products; category-defined attributes as data (not schema); a unified scanner. Preserve all existing guarantees (sold-once, exact costing, audit, tenancy). Keep 2D untouched.

**Analytics-ready (Universal Analytics Requirement):** the generalized model must let the 2D financial system work **identically across all tracking types**. This is satisfied because profit is computed at the `sale_item` level (captured `price`/`cost`/`quantity` per line) — the same for IMEI units, serial units, and quantity lines — and every product carries a `category_id`. 2C.5 therefore ensures: (a) `sale_items` capture cost/price/qty for *all* line types (already true), (b) `products.category_id` is set so profit rolls up by product **and** category, and (c) inventory value spans **both** `units` (in_stock) and `stock_items`. No analytics query references an IMEI/serial. Full rollup design in [`17` §5.2–5.3](17_SPRINT2_IMPLEMENTATION_PLAN.md).

---

## 2. Database changes

### 2.1 New table `product_categories` (D1)
```
id BINARY(16) PK · company_id BINARY(16) FK · name VARCHAR(80)
default_tracking_type ENUM('imei','serial','quantity') NOT NULL
attribute_schema JSON NULL          -- adaptive attributes (see §6)
created_at/updated_at DATETIME(6)
UNIQUE(company_id, name) · INDEX(company_id)
```

### 2.2 `products` — generalized
| Add | Change/Drop |
|---|---|
| `tracking_type ENUM('imei','serial','quantity') NOT NULL DEFAULT 'imei'` | **Drop** old `category` ENUM (`phone/accessory/other`) after backfill |
| `category_id BINARY(16) NULL` FK → product_categories `ON DELETE SET NULL` | **Drop** `is_serialized` (derivable from tracking_type) |
| `specifications JSON NULL` (adaptive attribute values) | — |
| `barcode VARCHAR(64) NULL` + `UNIQUE(company_id, barcode)` (multi-NULL ok) | — |

### 2.3 `units` — identifier generalized (D2; the core edit)
| Change | Detail |
|---|---|
| `imei_primary` → **NULLABLE** | serial units have no IMEI |
| CHECK relaxed | `imei_primary IS NULL OR imei_primary REGEXP '^[0-9]{15}$'` |
| **Add generated `identifier VARCHAR(64) STORED = COALESCE(imei_primary, serial_no)`** | one canonical id for any serialized unit |
| Replace `UNIQUE(imei_primary)` with **`UNIQUE(identifier)`** | enforces IMEI **and** serial global uniqueness (+ cross-collision) in one index |
| `imei_secondary` (dual-SIM), `serial_no` | kept; IMEI intelligence stays isolated to the IMEI path |
| `active_unit_id` sold-once, `cost`, `status` | **unchanged** |

### 2.4 `stock_items` — minor
- Add `barcode VARCHAR(64) NULL` (optional; product-level barcode is primary). Quantity flow otherwise unchanged.

### 2.5 New table `product_recognition` (the learning map)
Company-scoped learned mappings from a scanned code to a product template — the heart of the learning system. Every successful recognition / manual create writes here, so the **next** scan of the same TAC/barcode is instant with **no typing**.
```
product_recognition(
  id BINARY(16) PK, company_id BINARY(16) FK,
  code_type ENUM('tac','barcode','serial_prefix') NOT NULL,
  code VARCHAR(64) NOT NULL,
  product_id BINARY(16) FK → products ON DELETE CASCADE,
  times_seen INT NOT NULL DEFAULT 1, last_seen_at DATETIME(6), created_at DATETIME(6),
  UNIQUE(company_id, code_type, code), INDEX(company_id, product_id)
)
```
(`products.barcode` remains the product's own primary/printable barcode; the map also handles TACs, alias barcodes, and optional serial prefixes.)

### 2.6 Unaffected
`sales`, `sale_items`, `payments`, `returns`, `stock_transfers`, `transfer_items`, `daily_closings`, `daily_digests`, `audit_logs`, `branch_counters`, `auth_sessions`, RBAC/tenancy — no change.

---

## 3. Migration design (each reviewed at implementation)

### `0007_products_categories`
1. `CREATE TABLE product_categories (…)` + FK.
2. `ALTER products ADD tracking_type, category_id, specifications, barcode`.
3. **Backfill (data transform on existing rows):** `UPDATE products SET tracking_type = IF(category='accessory','quantity','imei')`.
4. `CREATE UNIQUE INDEX ux_products_company_barcode ON products(company_id, barcode)`.
5. `ALTER products DROP COLUMN category, DROP COLUMN is_serialized`, then add FK `category_id → product_categories`.
6. `CREATE TABLE product_recognition (…)` (the learning map, §2.5) + FKs.

*Reference data (baseline categories with attribute schemas) is seeded by the updated `seed.ts`, not the migration — keeps the migration data-agnostic.*

### `0008_units_generalize`
```
ALTER TABLE units MODIFY imei_primary VARCHAR(15) NULL;
ALTER TABLE units DROP CHECK units_imei_primary_format_chk;
ALTER TABLE units ADD CONSTRAINT units_imei_primary_format_chk
  CHECK (imei_primary IS NULL OR imei_primary REGEXP '^[0-9]{15}$');
ALTER TABLE units ADD COLUMN identifier VARCHAR(64)
  GENERATED ALWAYS AS (COALESCE(imei_primary, serial_no)) STORED AFTER serial_no;
DROP INDEX units_imei_primary_key ON units;
CREATE UNIQUE INDEX ux_units_identifier ON units(identifier);
```
Prisma `schema.prisma`: `imeiPrimary String?` (drop `@@unique`), `serialNo String?`; the generated `identifier` is **not** modelled (raw SQL, like `active_unit_id`) — it will show in `migrate diff` as an expected extra (documented).

**Dev backfill:** existing demo units already have IMEIs → `identifier` auto-computes; existing products → `tracking_type='imei'`, `category_id` set by the re-seed. The dev DB can also simply be `migrate reset` + reseed.

---

## 4. Module changes

| Module | Change |
|---|---|
| **`tracking/` (new)** | `TrackingStrategy` registry (one per type): `validateIdentifier`, `describe`, `recognize`. Keeps IMEI (Luhn/TAC) isolated from serial/barcode (D2). |
| **`catalog/` + categories** | New `CategoriesModule` (CRUD + `attribute_schema`); `CatalogService.create` takes `categoryId` (default `tracking_type` from category), `specifications` (validated), `barcode`; drop `isSerialized`/enum. `ProductAttributesService` validates specs vs schema. |
| **`scanner/` (new)** | `ScannerService` (priority resolver, §5) + `RecognitionService` (read/write `product_recognition` learning map) + `POST /scan`. Catalog create/intake call `RecognitionService.learn(...)`. |
| **`inventory/`** | `createUnit`/quick-add accept identifier by `tracking_type` (imei **or** serial); `findByIdentifier` + **`GET /units/:identifier`**; dup-check across `identifier`. `imei.util` stays for IMEI only. |
| **`purchasing/`** | `PurchaseLineDto` identifier resolved per product `tracking_type`; quantity lines unchanged. |
| **`sales/`** | `SaleLineDto`: `identifier` (imei/serial) or `productId+quantity`; `assertSellable` via `findByIdentifier`. |
| **`transfers/`** | `imeis[] → identifiers[]`; `computeDiscrepancy` already generic. |
| **`prisma/seed.ts`** | Seed baseline categories (Phones→imei {storage,ram,color}; TVs→serial {screen_size,resolution,panel}; Accessories→quantity {}) + set demo product. |
| **branding (D5)** | Rename to *Electronics Retail Management System* in `CLAUDE.md`, `docs/01`, README (cosmetic). |

---

## 5. Smart Product Scanner architecture (a learning system)

**`POST /api/v1/scan { code, hint? }` → `ScanResult`** (auth). One entry point that resolves the code by a fixed **recognition priority** and **learns** every result. The heart is the `product_recognition` map (§2.5) plus the global `tac_catalog` seed.

### 5.1 Recognition priority (as specified)
```
code ─▶ 1. IMEI      15 digits & Luhn valid?
        │            a. product_recognition(tac, TAC) → product   [learned, instant]
        │            b. else tac_catalog[TAC] → brand/model       [global seed]
        │            c. else company history: units WHERE imei LIKE 'TAC%' → prior product
        │            ⇒ { kind:imei, trackingType:imei, suggestedProduct?, autofill }
        ├─▶ 2. BARCODE  product_recognition(barcode, code) OR products.barcode=code → product
        │            ⇒ { kind:barcode, trackingType: product.tracking_type, suggestedProduct, known:true }
        ├─▶ 3. SERIAL   a. existing unit WHERE serial_no=code → DUPLICATE (block/inform)
        │            b. else product_recognition(serial_prefix, prefix) → product (when learned)
        │            ⇒ { kind:serial, known?, duplicate? }
        └─▶ 4. UNKNOWN  ⇒ { kind:unknown, needsManualCreate:true }
```
- **1. IMEI (priority 1):** Luhn → learned TAC map → global TAC catalog → company history. Auto-fills brand/model/variant/specs from the resolved product **template** whenever possible.
- **2. Barcode (priority 2):** **search the company catalog first** (`product_recognition` + `products.barcode`) → previously-created products recognized **instantly**.
- **3. Serial (priority 3):** duplicate detection against existing `serial_no`; match a product when a learned `serial_prefix` exists; otherwise the box **barcode** (path 2) identifies the product and the serial is captured as the unit identifier.
- **4. Unknown (priority 4):** return `needsManualCreate`. When the employee creates the product, the system **automatically saves the recognition mapping** — `product_recognition(tac|barcode, code → product)` (and `products.barcode`) — so **future scans are recognized with no manual work**. Each subsequent hit bumps `times_seen`/`last_seen_at`.

### 5.2 Products as reusable templates
A `Product` **is** the reusable template (brand, model, variant, category, `specifications`, default cost/price, tracking type). Once created (e.g. *"Samsung 55" Crystal UHD TV"*):
- **Future shipments never re-enter specs.** Intake resolves the product via `/scan` → the client submits only `productId` + the scanned **identifier** (IMEI/serial) or **quantity**, plus `cost`. All product info is auto-filled from the template.
- **Smart cost default:** the last purchase cost for that product (most recent `purchase_item`) pre-fills `cost` (still editable) — reducing typing further.
- **Employee action reduces to:** *scan → confirm → (enter cost/qty)* — 2–3 taps, per the philosophy.

### 5.3 `ScanResult` shape
`{ code, kind: imei|barcode|serial|unknown, trackingType?, identifier?, known, duplicate?, needsManualCreate, suggestedProduct?: { id, brand, model, variant, category, specifications, defaultCost, defaultPrice }, matches[] }`

### 5.4 Learning write-paths
- On **manual create** after an unknown scan → upsert `product_recognition` (tac for IMEI, barcode for barcode) + set `products.barcode`.
- On **product create with a barcode** → upsert `product_recognition(barcode)`.
- On a **confirmed IMEI intake** for a product → upsert `product_recognition(tac, product)` so the whole company benefits next time.
All writes are tenant-scoped (company learns its own catalog), audited implicitly via the product/unit actions.

---

## 6. Adaptive product attributes architecture

- **Definition** lives on the category: `product_categories.attribute_schema` = a JSON array of
  `{ key, label, type: 'text'|'number'|'enum'|'boolean', unit?, options?, required? }`.
- **Values** live on the product: `products.specifications` (JSON object `key → value`).
- **Validation:** `ProductAttributesService.validate(schema, specifications)` enforces required/type/options in the **application layer** on product create/update — so **adding attributes = editing a category's `attribute_schema` (data), never a migration.**
- **Examples** (seeded):
  - Phone → `[{storage,number,GB},{ram,number,GB},{color,text}]`
  - TV → `[{screen_size,number,in},{resolution,enum,[HD,FHD,4K,8K]},{panel,enum,[LED,OLED,QLED]}]`
  - Power station → `[{capacity,number,Wh},{output_power,number,W}]`
- **Category management API:** `POST/GET /categories`, `PUT /categories/:id` (`settings.manage`) to edit `attribute_schema` + `default_tracking_type`.

---

## 7. API changes (D3)
- **Renamed:** `GET /units/:imei → /units/:identifier`; `POST /units` body `imeiPrimary → identifier` (+ optional `imeiSecondary` for IMEI type); purchasing/sales lines `imei → identifier`; transfers `imeis → identifiers`.
- **Replaced:** `GET /products/recognition/:imei` → **`POST /scan`**.
- **New:** `POST/GET/PUT /categories` (+ attribute schema); `POST /scan`.
- All ids remain canonical UUID strings at the boundary.

---

## 8. Risks
- **Destructive migration** (drop `category` enum + `is_serialized`): backfill `tracking_type` first; dev DB is resettable. Low risk (dev-only data).
- **Generated `identifier` + unique**: STORED generated column over two columns is MySQL-supported; verify at first apply. Excluded from Prisma (expected `migrate diff` extra, like `active_unit_id`).
- **Dropping `units_imei_primary_key`** in favor of `ux_units_identifier`: safe (no duplicate identifiers in dev).
- **Broad de-`imei` refactor** touches 5 modules → breaking for existing test scripts only (no mobile client yet).
- **Scanner learning** via IMEI-TAC prefix lookup is heuristic; a future per-company `tac_map` table can strengthen it (noted, not now — no new table this sub-phase beyond 0007/0008).
- **Attribute validation scope**: keep types to text/number/enum/boolean in v1.

---

## 9. Testing strategy
- **Unit:** `TrackingStrategy` identifier validation per type; `ProductAttributesService` (required/type/enum); scanner kind-detection (imei/barcode/serial/unknown); IMEI TAC recognition.
- **Integration (WAMP MySQL):** create categories with schemas → create products of each type with specs (invalid spec rejected) → intake IMEI unit / serial unit / quantity stock → `POST /scan` returns correct kind + suggestion → **learning: scan unknown code → 404/needsManualCreate → create product → re-scan SAME code → now recognized instantly (times_seen increments)** → **template reuse: second shipment of the same product needs only identifier+cost (no specs)** → sell IMEI, serial, and quantity lines → transfer serial units (discrepancy) → dup detection across IMEI+serial → `GET /units/:identifier` works for both.
- Extend the existing Jest suite; keep the live smoke harness.

---

## 10. Build order (checkpoints) & next step
- **2C.5a** — migrations `0007`/`0008` + `schema.prisma` + seed baseline categories + branding rename. *(build + verify migrate/reseed)*
- **2C.5b** — `TrackingStrategy` + `CategoriesModule` + `ProductAttributesService` + generalized `CatalogService`.
- **2C.5c** — Smart Product Scanner (`POST /scan`) + recognition/learning.
- **2C.5d** — generalize inventory/purchasing/sales/transfers (`identifier`) + full tests.
Each ends with build + test + report; stop only for a new architectural decision or an unplanned migration.

**On approval of this plan, I implement 2C.5a first**, explaining each major piece before writing it, then continue through 2C.5d and resume Sprint 2D.
