# 06 — Technical Architecture (Complete · 🔒 FROZEN 2026-07-29 · DB amended → MySQL 2026-07-29)

> This is the **canonical architecture document**. It was validated against the product vision and **frozen on 2026-07-29** — all decisions D1–D11 are resolved (see the Decisions section). **Amended the same day: the database engine changed from PostgreSQL to MySQL 8 (InnoDB)** — see the amendment note and MySQL-specific decisions (M1–M6) in the Decisions section. Changes from here require an explicit unfreeze + version note.
> It must serve every project principle: reduce typing, reduce mistakes, faster than a notebook, easy to learn, feel alive, **internal-only** (never customer-facing / never e-commerce).
> Designed for scale: **multiple branches · thousands of phones · millions of IMEI records · large inventory history · future AI analytics · high security · offline capability.**
>
> **What this is NOT:** not a customer app, not e-commerce, not a simple inventory list. It is an **internal operating system for phone businesses**.

---

## 0. Architectural principles
- **Server is the source of truth for integrity.** IMEI uniqueness, "sold once," permissions, and money are decided on the server, never trusted from a device. → *safe at scale.*
- **The device is fast and optimistic.** Works offline, feels instant; the server confirms or corrects on sync. → *faster than a notebook.*
- **Scanning and rules do the typing.** Camera + OCR + catalog matching + smart defaults; the user confirms, rarely enters. → *reduce typing / reduce mistakes.*
- **The dashboard analyzes, it doesn't just display.** Every metric carries a trend/insight. → *feel alive.*
- **Detail lives in the app; WhatsApp only gets a short summary.** → owner-focused, privacy-safe.
- **Multi-tenant, single-branch-first.** A **Company** is the top tenant; the model is branch-ready from day one, but a business launches with one branch and adds more later.

---

## 1. Technology Stack (confirmed preferred stack)

| Layer | Choice | Why (tied to goals + scale) |
|---|---|---|
| **Mobile framework** | **Flutter + Dart** | One compiled codebase for Android (primary — cheap shop phones) + iOS; excellent camera/ML-Kit support; smooth 60fps "alive" UI; strong offline story with Drift. |
| **Camera / scanning** | **Flutter camera** + **Google ML Kit** (barcode scanning + text recognition/OCR) | On-device, offline, instant IMEI barcode + OCR. No network round-trip. |
| **Backend framework** | **NestJS + TypeScript** | Structured, modular ERP backend; DI + guards for RBAC; strong validation; end-to-end typing reduces mistakes. |
| **Data layer / ORM (server)** | **Prisma** | Typed schema, safe migrations. (Server-side only — pairs fine with a Flutter client.) |
| **Database** | **MySQL 8.0+ (InnoDB)** | DB-enforced unique IMEI, FK integrity, FULLTEXT search, JSON, CHECK constraints, generated columns, roles; already in the WAMP dev stack. **Tenant isolation is app-layer** (MySQL has no RLS — see §3/§9). |
| **Offline (device)** | **SQLite + Drift** | Reactive local DB for Flutter; powers offline-first optimistic writes + local queries; pairs with an outbox sync layer. |
| **Cloud** | **AWS** | RDS/Aurora **MySQL** (backups + PITR), ECS/Fargate (API), S3 (object storage), ElastiCache (Redis), CloudWatch (monitoring), KMS (encryption keys). |
| **Cache / queues / jobs** | **Redis (ElastiCache) + BullMQ** | Dashboard caching, background jobs (WhatsApp send, BI aggregation, dead-stock scans, CSV imports). |
| **Object storage** | **AWS S3** | Product photos, scanned IMEI images, receipts, report/CSV exports. |
| **Authentication** | **JWT access + refresh tokens**, **Argon2id** hashing, **RBAC** server-side | Offline-tolerant (device holds short-lived token), refresh on reconnect, per-device revocable sessions. |
| **Push notifications** | **Firebase Cloud Messaging (FCM)** | Real-time in-app + device notifications for the notification center and "alive" alerts. |
| **WhatsApp** | **WhatsApp Business API** | **Short closing summary only** (see §7). Keys server-side only. |
| **AI / intelligence** | **Rules-based first, ML later** | Deterministic engine delivers the "alive" feel now; ML/LLM added on the same metrics store later. |
| **Monitoring** | Sentry + CloudWatch + structured logs | Production-quality operations. |

**Dev environment:** local **MySQL 8** (the running WAMP instance, or Docker) + NestJS API on the LAN + **Flutter app on a real test device** (needed for camera/ML Kit) + MinIO or S3 dev bucket. *(Note: unlike the other Expo/React-Native apps on this machine, this project is Flutter — intentional, per the chosen stack; less cross-project code reuse is the accepted trade-off.)*

---

## 2. Complete System Architecture

```
┌───────────────────────────────────────────────────────────────────────┐
│                          MOBILE APP (Flutter)                            │
│  UI (alive, minimal-tap)     Scanning (camera + ML Kit barcode/OCR)      │
│  Local DB (SQLite + Drift) ← offline-first, optimistic writes            │
│  Sync engine (outbox + pull)   Auth (JWT in secure storage)   FCM client │
└───────────────┬──────────────────────────────────────────────────────────┘
                │  HTTPS / REST (JSON)   — sync when online
                ▼
┌───────────────────────────────────────────────────────────────────────┐
│                    BACKEND API (NestJS · on AWS ECS/Fargate)             │
│  Auth & RBAC guards    Business-rule engine (IMEI, margin, closing)      │
│  Sync service (conflict resolution, server = source of truth)           │
│  BI engine (health score, attention, dead-stock, recommendations)       │
│  Import service (Excel/CSV → validated stock)                           │
│  Background workers (BullMQ): WhatsApp, BI aggregation, imports, exports │
│  Audit logger (append-only)                                             │
└───┬───────────────┬───────────────┬───────────────┬─────────────────────┘
    │               │               │               │
    ▼               ▼               ▼               ▼
┌────────┐    ┌──────────┐    ┌───────────┐   ┌──────────────────────────┐
│MySQL 8 │    │  Redis   │    │   S3      │   │   External services       │
│(InnoDB,│    │(Elasti-  │    │ (images,  │   │  • WhatsApp Business API   │
│RDS/    │    │ Cache;   │    │ receipts, │   │    (short summary only)     │
│Aurora, │    │ cache +  │    │ CSV, exp- │   │  • Firebase Cloud Messaging │
│replicas)    │ queues)  │    │ orts)     │   │  • (future) ML services     │
└────────┘    └──────────┘    └───────────┘   └──────────────────────────┘
```

**Responsibilities**
- **Mobile (Flutter)** — capture (scan), present (alive dashboard), operate offline, sync. No authority over integrity rules.
- **Backend (NestJS)** — enforce every rule/permission, resolve sync conflicts, run BI + jobs (incl. CSV import), write the audit log.
- **Database (MySQL 8 / InnoDB on RDS/Aurora)** — durable source of truth with DB-level constraints. **Tenant isolation is enforced by the backend, not the DB** (no RLS in MySQL).
- **External services** — delivery + heavy storage behind the backend (keys never on device).

---

## 3. Database Architecture

Field-level detail: [`07_DATABASE_REQUIREMENTS.md`](07_DATABASE_REQUIREMENTS.md). This section defines **entities, the multi-tenant shape, and the scale strategy**.

### Multi-tenant hierarchy (single-branch-first)
```
Company (tenant)
  └── Branch (store / warehouse) — one at launch, many later
        └── Users (assigned per branch, with roles)
        └── Stock (Units / StockItems), Sales, Purchases, Expenses, Closings
```
Every table carries `company_id` (usually `branch_id` too). **Because MySQL has no Row-Level Security, tenant isolation is enforced entirely in the backend** — a mandatory Prisma middleware/extension injects the `company_id` filter into every read and write, backed by RBAC guards and the audit log. This is the deliberate MySQL replacement for the earlier Postgres RLS plan (see §9).

### Roles (five)
`owner · administrator · branch_manager · sales_employee · warehouse_employee` — see [`03_USER_ROLES.md`](03_USER_ROLES.md). **Administrator** is a technical/setup admin (users, settings, integrations) distinct from the business **Owner**.

### Entity list (required set)

| Entity | Purpose | Key integrity |
|---|---|---|
| **Company** | Top tenant | Root of all scoping |
| **User** | Staff account | Belongs to a Company; unique login |
| **Role / Permission / RolePermission** | RBAC (5 roles → fine-grained perms) | Checked server-side; drives field stripping |
| **UserBranch** | Branch access + per-branch role | Scopes visibility |
| **Branch** | Store or warehouse | Belongs to Company |
| **Product** | Catalog model/variant | `is_serialized` flag |
| **Unit (IMEI record)** | One physical phone | **`imei_primary` UNIQUE globally**; sold once |
| **StockItem** | Non-serialized stock (accessories) | Quantity ≥ 0 |
| **Supplier / Purchase / PurchaseItem** | Buying stock → creates Units | Feeds payables |
| **Sale / SaleItem / Payment** | Selling; exact per-unit cost → exact profit | Reconciles; unit sold once |
| **Return** | Reverses a sale | Never a hard delete |
| **StockTransfer / TransferItem** | Move Units between branches | `in_transit` until received |
| **Customer** | Lightweight (name, phone, balance) | Receivable balance |
| **Expense (+ recurring templates in Settings)** | Rent, salary, utilities, misc | Feeds monthly/yearly net profit |
| **DailyClosing** | Locked end-of-day + cash reconciliation | One per branch/day |
| **DailyDigest** | **Stored rich daily snapshot** for the notification center (full sold-item detail) | Immutable snapshot linked to a closing |
| **Notification** | In-app feed / attention items | Targeted, read-state |
| **ImportBatch (+ ImportRow)** | Excel/CSV inventory import staging + results | Validated before commit |
| **Report (definition + snapshot)** | Saved report configs + exports | References source, not a copy |
| **AuditLog** | Append-only trail of every mutation/override/login | Immutable from app flows |
| **SyncState / Outbox** | Per-device cursor + change queue | Offline sync + idempotency |
| **Setting** | Per-company/branch config (thresholds, recurring expenses, **discount-monitoring toggle**, health-score weights, WhatsApp schedule) | Owner-controlled |

### Scale strategy (millions of IMEIs)
- **InnoDB + UUIDv7 (BINARY(16)) primary keys.** InnoDB clusters rows on the PK; time-ordered UUIDv7 keeps inserts sequential (few page splits) and BINARY(16) keeps every secondary index compact — the right choice for large IMEI/sales history.
- **Indexes:** unique `imei_primary`; composite `(company_id, branch_id, status)`, `(company_id, date)`; all FK columns indexed (InnoDB requires it).
- **Read replicas** (RDS/Aurora MySQL) for reports/BI so analytics never slow selling.
- **Summary/rollup tables** for dashboards (daily/monthly/yearly profit, inventory value, velocity, dead stock), refreshed by BullMQ jobs + cached in Redis. *(MySQL has no materialized views — we use maintained rollup tables instead.)*
- **Partition-ready, not partitioned at v1.** MySQL partitioning requires the partition key to be part of every unique key; at ~500k units it is unnecessary, so we rely on indexing now and revisit later. Old data is archived by time range; money records are reversed, never hard-deleted.

---

## 4. API Architecture

REST/JSON over HTTPS, versioned (`/api/v1`), every request authenticated + tenant-scoped.

### Main endpoint groups
```
Auth        POST /auth/login   POST /auth/refresh   POST /auth/logout
Sync        POST /sync/push    GET  /sync/pull?since=<cursor>
Catalog     GET/POST/PATCH /products      GET /products/search?q=
Inventory   POST /units (scan/add)   POST /units/bulk   GET /units/:imei (history/timeline)
            POST /imports (Excel/CSV upload)   GET /imports/:id (validation + commit)
            GET  /inventory?branch=&status=
Sales       POST /sales   POST /sales/:id/return   GET /sales
Purchases   POST /purchases   GET /suppliers   POST /suppliers/:id/payments
Transfers   POST /transfers   POST /transfers/:id/receive
Expenses    GET/POST /expenses   (recurring templates via /settings)
Closing     POST /closings   GET /closings/:date   → generates DailyDigest + queues WhatsApp
Dashboard   GET /dashboard   (revenue, COGS, gross profit, inventory value, health, attention)
BI          GET /bi/attention  GET /bi/dead-stock  GET /bi/recommendations
Digests     GET /digests   GET /digests/:date  (full stored daily detail)
Reports     GET /reports/...   POST /reports/export
Notifications GET /notifications   POST /notifications/:id/read
Admin       /companies /branches /users /roles /permissions /settings
```

### Authentication flow
1. **Login** → Argon2id verify → **short-lived access JWT** + **long-lived refresh token**; role + permissions + accessible branches loaded.
2. Tokens in device **secure storage** (Keychain/Keystore), never plaintext.
3. Each request: a **guard** validates the token, loads the user, enforces RBAC + tenant scope + field stripping.
4. Silent **refresh** on expiry; refresh tokens per-device and **revocable** (lost phone).
5. Offline: last valid token keeps the app usable; longer offline grace for queue-writes with a hard cap.

### Data synchronization
- **Push** `POST /sync/push`: device outbox → server validates each change → per-item result (accepted / conflict / rejected-with-reason).
- **Pull** `GET /sync/pull?since=<cursor>`: everything changed since last cursor, incl. **tombstones**.
- **Idempotency:** every change carries a client UUID → retries never double-apply (critical for sales).
- **Real-time:** FCM pushes lightweight "something changed / new insight" signals so the UI feels live between syncs.

---

## 5. Offline-First Strategy (SQLite + Drift)

**Goal:** keep selling and adding stock with no internet; lose nothing and double-count nothing on reconnect.

1. **Local Drift/SQLite DB** mirrors what the branch needs: catalog, in-stock units, recent sales, customers, prices.
2. **Optimistic writes:** a sale/stock-add is written locally and shown instantly. No waiting on the network.
3. **Outbox pattern:** each change appended with UUID + timestamp + device id.
4. **Sync when online:** background engine pushes outbox + pulls server changes; runs on reconnect and periodically.
5. **Conflict resolution (server-authoritative):**
   - **IMEI already sold elsewhere** (two branches offline): server accepts the first, **rejects the second**, flags the manager, app shows "This unit was already sold at Branch X — please resolve."
   - **Catalog/price edits:** server wins for shared catalog; a completed sale keeps the price captured at sale time.
   - **Non-critical fields:** last-writer-wins by `updated_at`; **integrity is never last-writer-wins** — it's rule-based.
6. **Tombstones + soft deletes** propagate deletions safely.
7. **Guardrails:** clear online/offline indicator, "N changes pending sync," and a stale-catalog warning after a long offline period.

**Guaranteed offline in v1 (⚠️ D7):** scan+add stock, scan+sell (cash/credit), manual add, local search, today's numbers. CSV import, cross-branch views, and BI refresh need connectivity.

---

## 6. IMEI-First Inventory & Scanning

On-device, offline pipeline — the signature "reduce typing" feature. **Three ways to add inventory**, in priority order.

### Add method 1 — Scan (primary)
```
Camera frame (Flutter camera)
   ├─▶ ML Kit barcode scanner → IMEI barcode/QR on box or device
   └─▶ ML Kit text recognition (OCR) → printed "IMEI: …" fallback
        ▼
   Extract 15-digit IMEI(s)  (dual-SIM = two IMEIs)
        ▼
   Validate: length 15 + Luhn checksum → reject invalid instantly, in plain words
        ▼
   Duplicate check: local DB (instant) + server on sync (authoritative global)
        ▼
   Automatic product recognition: IMEI TAC (first 8 digits) + catalog + learned history
        → pre-fills brand · model · storage · default price → user confirms with one tap
        ▼
   Feed into Add-Stock or Sell flow (prefilled)
```

### Add method 2 — Import Excel/CSV
```
Upload file → ImportBatch created → server parses rows
   → validate each row (IMEI valid? duplicate? product known? cost present?)
   → show a preview: valid rows, warnings, errors (per row, plain language)
   → user confirms → commit valid rows to stock; export a results file of rejects
```
Runs as a background job (BullMQ); large files don't block the UI. Ideal for bulk onboarding of existing stock.

### Add method 3 — Manual entry (fallback)
Minimal form, smart-defaulted (last supplier, current branch, catalog autocomplete). Only when scanning/import isn't possible.

### IMEI history timeline
Every Unit exposes a full timeline (`GET /units/:imei`): added → transferred → reserved → sold → returned, each event with who/when — reconstructable from the audit log. Every scan may store the captured image in S3 for disputes.

**Duplicate prevention:** two layers — instant local check + authoritative server check. Selling an already-sold IMEI is **blocked**, not warned.

---

## 7. Notifications: Internal Center (full detail) + WhatsApp (short only)

**Core rule from the vision:** *the detailed business information stays inside the app; WhatsApp gets only a short closing summary.*

### 7a. Internal Notification Center (rich, in-app)
On daily closing, the backend generates and **stores a DailyDigest** — an immutable snapshot:
```
28 July 2026
Revenue: $18,650   Cost: $16,100   Gross Profit: $2,550
```
Opening it shows **every sold product**: IMEI · employee · sale price · purchase cost · profit · payment method · time. Plus low-stock and attention items. This lives in the app forever, searchable, per branch. Real-time in-app notifications (via FCM) keep it feeling alive ("big sale just recorded", "stock hit reorder point").

### 7b. WhatsApp — closing summary ONLY
```
Daily closing → event queued (BullMQ) → summary composer → WhatsApp Business API → Owner
```
The message is intentionally minimal — **no per-sale detail, no IMEIs, no customer data**:
```
✅ Store Closed Successfully
Date:  28 Jul 2026
Time:  21:04
Revenue:              $18,650
Cost of Goods Sold:   $16,100
Gross Profit:         $2,550
```
- **Trigger:** on closing (and/or owner-set time), per-company configurable.
- **Compliance:** pre-approved WhatsApp template; keys server-side only.
- **Reliability:** background job + retry; delivery logged; FCM/in-app is the fallback and the place for full detail.
- **Privacy:** goes to owner/managers only — never customers (there are none).

---

## 8. Business Intelligence Architecture

**The dashboard analyzes the business — it does not just display data.** Deterministic rules + statistics first; ML/LLM later on the same metrics store.

```
Source tables (sales, units, purchases, expenses, suppliers)
   │  scheduled aggregation jobs (BullMQ) → maintained rollup tables
   ▼
Derived metrics (Redis cache / MySQL rollup tables)
   • revenue, COGS, gross profit (day/month/year)   • inventory value (sum of in-stock cost)
   • sales velocity per product   • days-of-stock-left   • margin trends
   • dead-stock age   • debt aging (payable/receivable)
   ▼
Smart Dashboard + BI outputs
   ├─ Revenue · COGS · Gross Profit · Inventory Value (with trend vs prior period)
   ├─ Business Health Score
   ├─ Needs Your Attention Today
   ├─ Slow-moving / dead-stock detection
   └─ Recommendations & friendly insights
```

- **Business Health Score (0–100 / R-A-G):** weighted over profit trend, cash flow, stock coverage, overdue debts, dead-stock ratio, velocity. **Always explainable** (one tap → top factors). Weights configurable per company.
- **Needs Your Attention Today:** generated action feed (stock about to run out with days-left, overdue debts, abnormal sales, dead stock, unclosed day). One line + one-tap action.
- **Slow-moving/dead-stock:** `days_since_last_sale` / `days_in_stock` vs thresholds → flagged with suggested action.
- **Friendly insights (alive):** phrased like an assistant — *"Only 3 iPhone 16 Pro left. At your current pace, stock may finish in ~5 days."* / *"Today's profit is 18% above yesterday."* Never a bare "Low stock."
- **Profit periods:** daily, monthly, **and yearly** net profit (gross margin − expenses).
- **Future AI:** same metrics store feeds ML demand forecasting, anomaly/fraud detection, and an optional LLM for natural-language phrasing/Q&A — additive, no core rewrite.

---

## 9. Security Architecture

| Area | Design |
|---|---|
| **Encryption in transit** | TLS/HTTPS everywhere; no plaintext endpoints. |
| **Encryption at rest** | RDS/Aurora MySQL (InnoDB tablespace/KMS) + S3 encrypted; device secure storage for tokens; sensitive columns extra-protected. |
| **Authentication** | Argon2id hashing; short-lived JWT + revocable refresh; per-device sessions; optional PIN/biometric device unlock. |
| **Authorization & tenant isolation** | **RBAC enforced server-side** on every request. Cost/profit **stripped server-side** for roles without permission. **Tenant isolation is app-layer (no MySQL RLS):** a mandatory Prisma middleware injects `company_id` (+ branch) on every query so no request can read/write another tenant's rows; enforced by guards and covered by tests + code review. Two DB users (migrator for DDL, least-privilege app user for DML); the app user has **no UPDATE/DELETE on `audit_logs`** (append-only). Limits (discount caps, cost-edit bounds) enforced server-side; overrides require higher role and are logged. |
| **Mistake prevention** | Duplicate-IMEI block, inventory-mismatch detection (expected vs counted), wrong-cost/abnormal-price warnings, unauthorized-action blocks, cash-reconciliation checks. **Discount monitoring is OFF by default and only active if the owner enables it** in Settings. |
| **Audit logs** | **Append-only** (who/what/when/before→after/reason) for every mutation/override/login. Not editable/deletable via app flows. |
| **Backups** | Automated **daily backups + PITR** (RDS); tested restores; S3 versioning; encrypted, off-site. |
| **Secrets** | WhatsApp/FCM/DB/AWS keys in server-side secret management (AWS Secrets Manager) — never in the mobile bundle. |
| **Hardening** | Rate limiting, input validation (NestJS pipes), dependency scanning, Sentry, least-privilege IAM. |

---

## 10. Development Roadmap (architecture-phased)

Each phase ends usable. Aligned with [`08_DEVELOPMENT_ROADMAP.md`](08_DEVELOPMENT_ROADMAP.md).

- **Phase 0 — Foundation.** Stand up NestJS API, **MySQL + Prisma** schema (Company/Branch/User/Role/Permission + core inventory) with the **tenant-scoping Prisma middleware**, Flutter app shell, auth + RBAC, CI, AWS dev env. *Done: role-based login on a real device.*
- **Phase 1 — Replace the notebook (MVP).** Catalog + recognition; IMEI **scan→add stock** (+ validation + duplicate detection); **CSV/Excel import**; **manual add**; **scan→sell** (cash/credit, profit per item); purchases + suppliers; universal search; core mistake-prevention; offline for core actions. *Done: a full real day runs in the app.*
- **Phase 2 — Control & trust.** Daily closing + cash reconciliation + lock → **DailyDigest**; expenses (recurring templates) → monthly/yearly profit; basic Smart Dashboard (revenue/COGS/gross profit/inventory value); employee attribution; full audit log. *Done: owner sees true profit + who did what.*
- **Phase 3 — Make it alive.** BI engine: Health Score, Needs Your Attention, recommendations, friendly insights; notification center; real-time (FCM). *Done: opening the app feels like a briefing.*
- **Phase 4 — Multi-branch & owner-away.** Branch scoping + consolidated view; stock transfers; **WhatsApp short closing summaries**; employee analytics + (opt-in) discount monitoring. *Done: run 2+ branches from the phone.*
- **Phase 5 — Insight & hardening.** Reports + export; full mistake-prevention suite; offline sync hardening + conflict UX; performance (rollup tables, indexing, Redis caching; partitioning if needed). *Done: fast + safe at millions of records.*
- **Phase 6 — AI & future.** ML forecasting, anomaly/fraud detection, optional LLM insights/Q&A; trade-ins/repairs; label printing. *On the existing metrics store — no core rewrite.*

---

## Summary
A **Flutter** app, **offline-first (SQLite + Drift)** and **camera-driven (ML Kit)**, over a versioned REST API to a **NestJS + Prisma** backend on **MySQL 8 (InnoDB)**, hosted on **AWS** (RDS/Aurora MySQL, ECS/Fargate, S3, ElastiCache), with **FCM** for real-time notifications and **WhatsApp Business API** for a **short closing summary only**. The **server is the single source of truth** for IMEI uniqueness, permissions, and money; the device is optimistic and syncs via **outbox + pull** with rule-based conflict resolution. Inventory is **IMEI-first with three add paths (scan / CSV import / manual)**. Detail lives in the **in-app notification center (DailyDigest)**; the dashboard **analyzes** (revenue, COGS, gross profit, inventory value, Health Score, Attention, recommendations, daily/monthly/yearly profit). **Multi-tenant (Company→Branch), single-branch-first** with **app-layer tenant isolation** (MySQL has no RLS), scaling to **millions of IMEIs** via UUIDv7 BINARY(16) clustered keys, indexing, and rollup tables. Security is defense-in-depth with an **append-only audit log**; **discount monitoring is owner-opt-in**.

---

## 🔒 Decisions (all frozen 2026-07-29)

**Stack:** Frontend **Flutter** · Backend **NestJS** · DB **MySQL 8 (InnoDB)** · Offline **SQLite+Drift** · Cloud **AWS** · Auth **JWT+refresh/Argon2id** · Push **FCM** · WhatsApp **Business API** · AI **rules-first**.

> **Amendment 2026-07-29 — database engine changed PostgreSQL → MySQL 8** (developer familiarity + already in WAMP). Consequent MySQL-specific decisions: **M1** tenant isolation is **app-layer** (no RLS); **M2** UUIDv7 stored as **BINARY(16)** (app-side generation); **M3** sold-once / company-wide-settings uniqueness via **generated columns** (no partial indexes); **M4** timestamps as **DATETIME(6) UTC**; **M5** dashboards use **rollup tables** (no materialized views); **M6** product search via **FULLTEXT**. See [`10_DATABASE_SCHEMA.md`](10_DATABASE_SCHEMA.md).

| # | Decision | Resolution |
|---|---|---|
| D1 | Database | ✅ **MySQL 8.0+ (InnoDB)** — *changed from PostgreSQL 2026-07-29* |
| D2 | Backend | ✅ **NestJS + TypeScript** |
| D3 | Offline engine | ✅ **SQLite + Drift** |
| D4 | Costing method | ✅ **Exact per-unit cost** — each Unit stores its own purchase cost; profit uses the specific unit's cost. |
| D5 | WhatsApp | ✅ **Official Meta WhatsApp Business Cloud API** (direct). |
| D6 | Hosting | ✅ **AWS** (RDS/Aurora MySQL, ECS/Fargate, S3, ElastiCache, KMS). |
| D7 | Offline scope v1 | ✅ Scan IMEI · add inventory · sell · manual entry · local search · view today's numbers · auto-sync when online · conflict detection + resolution. |
| D8 | Multi-tenancy | ✅ **Company→Branch from day one, single-branch-first.** |
| D9 | Tax/VAT | ✅ **Deferred to v2.** Schema is **tax-ready** now (reserved `tax_total`/line `tax_amount` default 0, prices stored as explicit net) so v2 adds no structural change. |
| D10 | v1 scale target | ✅ **~500,000 IMEI records · ~100,000 sales/year · up to 100 branches**, designed to expand beyond. |
| D11 | Administrator vs Owner | ✅ **Separate.** Administrator = technical/setup role; money visibility is a separate grant, never implied. |

**Status: architecture FROZEN → proceeding to detailed database schema design ([`10_DATABASE_SCHEMA.md`](10_DATABASE_SCHEMA.md)).**
