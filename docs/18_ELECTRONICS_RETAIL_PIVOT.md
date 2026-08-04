# 18 — Electronics Retail Pivot: Impact Analysis

> **Status:** Analysis only (no code changes). Requested before continuing Sub-phase 2D.
> **Vision change:** the product is no longer a *phone-store ERP* — it is an **Electronics Retail Management System**. Every product has a **Product Model** + one or more **Inventory Units**, and a unit is tracked one of three ways: **IMEI**, **Serial Number**, or **Barcode/Quantity**. The system must **auto-adapt the workflow by tracking type**. Goals unchanged: reduce typing, reduce mistakes, faster than a notebook, easy to learn.

---

## 0. The generalized core model

```
Product (the model)                         Inventory (the physical stock)
  brand, model, category, variant           ┌─ tracking_type = imei     → Unit (imei_primary [+imei_secondary])
  specifications (JSON)              ───────▶├─ tracking_type = serial   → Unit (serial_no)
  tracking_type  ◀── drives workflow         └─ tracking_type = quantity → StockItem (barcode + quantity)
  barcode / sku
```

**Key insight:** the current build already has the two storage shapes we need — **`Unit`** (one row per physical serialized item) and **`StockItem`** (quantity by product/branch). The pivot is mostly about (a) making the *identifier* on `Unit` generic (IMEI **or** serial), and (b) letting **`Product.tracking_type`** select the workflow — not a structural rebuild.

---

## 1. Architecture impact analysis

### 1.1 Tracking-type becomes the workflow selector
Today the code implicitly assumes "serialized ⇒ IMEI phone". It must become: **`Product.tracking_type ∈ {imei, serial, quantity}`** decides intake, recognition, sale, and transfer behavior:

| Type | Identifier | Recognition | Storage | Validation |
|---|---|---|---|---|
| **imei** | IMEI (15-digit, dual-SIM) | TAC → make/model (`tac_catalog`) | `Unit` | 15 digits + Luhn |
| **serial** | Serial number (free-form) | Barcode/SKU → product, else manual | `Unit` | non-empty, ≤64 chars |
| **quantity** | Barcode/SKU | Barcode → product | `StockItem.quantity` | qty ≥ 0 |

A small **`TrackingStrategy`** abstraction (one per type) cleanly encapsulates "validate identifier / recognize / how to stock", keeping controllers/services generic and honoring SOLID (open for new types like weight-based later).

### 1.2 Phone-specific assumptions found (module by module)

| Module / file | Phone-specific assumption | Generalize to |
|---|---|---|
| **catalog** `CreateProductDto`, `CatalogService` | `category` enum = `phone/accessory/other`; `isSerialized` boolean (binary); no `specifications`, no `barcode` | `tracking_type` enum; richer **category** (taxonomy); add `specifications`, `barcode/sku` |
| **catalog** `recognize(imei)` + `GET /products/recognition/:imei` | Recognition is **TAC/IMEI only** | Strategy: IMEI→TAC, serial/quantity→barcode/SKU lookup |
| **inventory** `imei.util` (Luhn/TAC) | IMEI-only validation | Keep for IMEI; add serial + barcode validators behind the strategy |
| **inventory** `QuickAddUnitDto` (`imeiPrimary`/`imeiSecondary`, `@Matches(15 digits)`) | Every unit has an IMEI | A `unit intake` DTO whose identifier fields depend on `tracking_type` (`imei` / `serial`) |
| **inventory** `findByImei`, `findExistingImeis`, `GET /units/:imei` | Lookup keyed on IMEI | Generic **`GET /units/:identifier`** (imei **or** serial); dup-check across both |
| **purchasing** `PurchaseLineDto.imeiPrimary` (15 digits), `isValidImei` | Serialized receiving = IMEI | Line identifier resolved by the product's `tracking_type` |
| **sales** `SaleLineDto.imei` (15 digits) | Serialized sale = IMEI | Line = `identifier` (imei/serial) or `productId+quantity` |
| **transfers** `imeis[]`, DTOs | Transfer = IMEIs | `identifiers[]` (imei/serial); `computeDiscrepancy` is already generic (string sets) |
| **naming** endpoints/DTOs say `imei` | — | Prefer neutral **`identifier`**; keep `imei`/`imeiSecondary` as the IMEI-type specifics |
| **branding** `PhoneStoreERP`, CLAUDE.md, docs/01 "Phone Business OS" | — | Rename to **Electronics Retail Management System** (cosmetic, non-urgent) |

### 1.3 What is ALREADY generic (no change)
- **`StockItem`** quantity flow = the Barcode/Quantity type (just needs a `barcode`).
- **Sold-once** (`active_unit_id` generated from `unit_id`) — identifier-agnostic. ✅
- **Exact per-unit costing, Sale/SaleItem/Payment, invoice numbering, audit, notifications, tenant isolation, RBAC, rollups (2D)** — all **tracking-type-agnostic** (they deal in units/money, not identifiers). ✅ This is why 2D itself needs almost no pivoting.
- **Transfer discrepancy** logic (set comparison) — generic. ✅

### 1.4 Net architectural verdict
This is a **generalization, not a redesign**. The domain already separates "model" (`Product`) from "physical stock" (`Unit`/`StockItem`). The work is: introduce `tracking_type`, make the `Unit` identifier generic (IMEI *or* serial), add a `TrackingStrategy` seam, broaden categories, and de-`imei` the DTOs/endpoints. Analytics/closing (2D) are unaffected.

---

## 2. Database impact analysis

### 2.1 `products` — needs changes (migration)
| Change | Why |
|---|---|
| **Add `tracking_type` ENUM(`imei`,`serial`,`quantity`)** | Drives the workflow. Replaces the binary `is_serialized` (which becomes derivable: `imei/serial ⇒ serialized`). Keep `is_serialized` as a generated/derived column or drop it. |
| **Broaden `category`** | Current enum `phone/accessory/other` is far too narrow. Two options — see Decision D1. |
| **Add `specifications` JSON** | Explicitly in the new vision (per-model specs). |
| **Add `barcode`/`sku` VARCHAR + index** | Serial + quantity recognition (scan barcode → product). |

### 2.2 `units` — needs changes (migration; this is the core edit)
| Change | Why |
|---|---|
| **`imei_primary` → NULLABLE** | Serial-tracked units have no IMEI. (Currently `NOT NULL` — the central phone assumption.) |
| **Add UNIQUE on `serial_no`** (partial, `WHERE serial_no IS NOT NULL`) | A serial identifies exactly one physical unit — same global-uniqueness guarantee IMEI has. |
| **Relax the IMEI CHECK** to `imei_primary IS NULL OR imei_primary REGEXP '^[0-9]{15}$'` | Allow NULL for serial units; keep format check when present. (App layer already enforces Luhn.) |
| **(Recommended) generated `identifier` = `COALESCE(imei_primary, serial_no)`** + UNIQUE | One canonical, unique lookup key for generic `GET /units/:identifier`, dedupe, and timeline — without changing callers per type. |
| `imei_secondary` | Keep (dual-SIM); IMEI-type only. No change. |

*Note:* MySQL `CHECK` can't reference `products.tracking_type`, so "the right identifier is present for the type" is enforced in the **application layer** (the `TrackingStrategy`), consistent with our existing app-layer rules.

### 2.3 `stock_items` — minor
- Add `barcode`/`sku` (or rely on `products.barcode`). Quantity flow otherwise unchanged.

### 2.4 `tac_catalog` — unchanged, IMEI-only
- Stays the IMEI recognition source. Serial/quantity recognition uses `products.barcode`/`sku` (no new table required).

### 2.5 Unaffected tables
`sales`, `sale_items`, `payments`, `returns`, `stock_transfers`, `transfer_items`, `daily_closings`, `daily_digests`, `audit_logs`, `branch_counters`, `auth_sessions`, RBAC/tenancy — **no change** (identifier-agnostic).

### 2.6 Migrations required (new — beyond approved scope → need approval)
- **`0007_products_generalize`** — `tracking_type`, `specifications`, `barcode`, category change.
- **`0008_units_generalize`** — `imei_primary` nullable, `serial_no` unique (partial), CHECK relax, optional generated `identifier`.
- **Data backfill:** existing seeded/demo products → `tracking_type='imei'`; existing units already have IMEIs (fine). Low volume (dev only).

---

## 3. Recommended changes before continuing Sprint 2D

### 3.1 Sequencing — do a **Generalization sub-phase (2C.5) BEFORE 2D** ✅ recommended
- **Why:** every unit-facing module (catalog, inventory, purchasing, sales, transfers) currently bakes in IMEI. Generalizing *now* prevents piling 2D and later features on phone-specific assumptions and delivers the new vision cleanly. 2D (analytics/closing) then builds on the correct model.
- **Why not 2D-first:** 2D *is* tracking-type-agnostic, so it wouldn't add coupling — but it also doesn't reduce the eventual refactor, and the vision has already changed, so aligning the core first is lower-risk.
- **Scope of 2C.5:** migrations `0007`/`0008`; a `TrackingStrategy` seam; de-`imei` DTOs/endpoints → `identifier`; add serial + quantity intake/sale/transfer paths; barcode recognition; broaden categories; update tests. Mostly mechanical + additive. Estimated a similar size to 2B.

### 3.2 Decisions needing approval (before 2C.5)
- **⚠️ D1 — Category modeling:** (a) a **`product_categories` table** (company-scoped, with a `default_tracking_type` so scanning auto-adapts by category) — most flexible, vision-aligned; **(recommended)** vs (b) a simple `category VARCHAR` + `tracking_type` set per product. (a) enables "pick TV → serial workflow by default".
- **⚠️ D2 — Unit identifier modeling:** (a) **typed columns** `imei_primary?`/`serial_no?` + a **generated `identifier`** unique column for generic lookups **(recommended)** vs (b) a single generic `identifier` + `identifier_kind` column (bigger change, loses IMEI-specific typing).
- **⚠️ D3 — API/DTO naming:** rename `imei` → `identifier` across new/changed endpoints **(recommended)**; keep IMEI-specific fields where the type is `imei`. (Breaking for the not-yet-built mobile client, so cheap now.)
- **⚠️ D4 — v1 tracking types:** confirm all three (imei/serial/quantity) ship in v1 (recommended), or phase serial/quantity.
- **⚠️ D5 — Branding:** update name to "Electronics Retail Management System" in CLAUDE.md/docs/01 now, or defer (cosmetic).

### 3.3 What does NOT need to change
- Sprint 1 foundation, tenancy/RBAC/audit, sold-once, costing/profit, invoice numbering, transfers discrepancy logic, and the **entire 2D analytics/closing plan** — all remain valid on the generalized model.

---

## 4. Recommended next step
Approve **D1–D5**, then run a focused **Sub-phase 2C.5 — Generalization to Electronics** (migrations `0007`/`0008` + `TrackingStrategy` + de-`imei` refactor + serial/quantity workflows + tests), and **resume 2D afterward** on the generalized model. I'll present the 2C.5 implementation plan for approval before writing code (per CLAUDE.md), including the exact migration DDL.
