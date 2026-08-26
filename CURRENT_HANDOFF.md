# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF**
- Active account / Owner: **NONE**
- Last account: **CLAUDE-B**
- Completed task — **migration `0059`**, which publishes the 61-key permission
  catalogue as reference data, so a database built by `prisma migrate deploy`
  alone no longer needs the demo seed to be usable.
- **Do not begin** hosting, production deployment, CI/CD, administrator MFA,
  Bankily integration, real contact delivery, or the IMEI scanner milestone.

### HEADs — all four repositories clean and level with their remotes

| Repository | HEAD |
|---|---|
| `erp-backend` | `dd9d4d0` |
| `erp-mobile` | `b973f64` (unchanged — no mobile change was needed) |
| `retail-erp-control-web` | `ad923df` (unchanged — no website change was needed) |
| `erp-docs` | *this commit* |

Nothing was force-pushed and no shared history was rewritten.

---

## The defect this closed

**A tenant's authority is only ever as complete as the catalogue behind it.**
`AccessService` resolves permissions solely from `role_permissions`, and those
rows can only reference `permissions` rows that exist.

Until now **no migration created the catalogue.** The base keys — `sale.create`,
`report.view`, `user.manage` and 14 others — were inserted only by
`prisma/seed.ts`. Later feature migrations each added the handful of keys they
introduced, which is how a deploy-only database reached exactly **44 of 61**.

**The demo seed concealed it** by doing two jobs at once: it seeds the reference
catalogue *and* the demo company. Every environment anybody had looked at ran
it, so the catalogue was always complete there. Staging — the first environment
built deliberately without the demo company — was the first to show the gap, and
did so loudly, because the role repair refused to provision a partial Owner.

---

## Migration `0059_permission_catalogue_reference_data`

**Reference data only.** It inserts catalogue rows and grants nothing:

- no schema change — no `ALTER`, no `CREATE TABLE`, no Prisma schema edit;
- no `role_permissions`, so no role's authority moves;
- no tenant, user, branch, subscription, sale or demo record;
- **no existing row modified.**

`NOT EXISTS`, never `INSERT IGNORE` or `REPLACE`. `IGNORE` would also swallow a
genuine error — a truncated label under strict mode, a broken constraint — and
leave the catalogue quietly short, the exact class of silent failure this ends.
`REPLACE` would delete and reinsert, discarding ids `role_permissions` points at.

Generated from `src/rbac/role-permissions.ts` by
`scripts/generate-catalogue-migration.ts`, so nobody hand-maintains a second
list of keys. The SQL is an **immutable historical snapshot, not a second
runtime source** — nothing under `src/` reads a migration file, and a test
enforces it.

> **A future permission needs a FUTURE migration. Never edit `0059`.**

### Hashes — unchanged by all of this

| | |
|---|---|
| Canonical key-set SHA-256 | `52b7200d09710a251d424a97fe24900e9dbff01e250195ba73e6e83ab388b4ec` |
| **Role-matrix SHA-256** | `fc577f63451ec8c0792b8dc034f33f5dabbf402f2190a6cb75647c51933cf687` |
| Full-canon SHA-256 | `0ddb8c04314656dc98f4c293726dedc2dcefbdc414fc1d78fd0ae967af9d668e` |

Owner 61 / Manager 43 / Employee 20, unchanged. No permission key was added,
removed, renamed or reinterpreted.

---

## Proof, on real disposable MySQL databases

Both were dropped afterwards; no `%proof%` database remains.

### Clean installation — `prisma_staging_cleaninstall_proof`

Migrations only, **no demo seed**: 58 applied, highest `0059`, **61 keys**, and
`companies=0 users=0 roles=0 role_permissions=0 sales=0`. Then, live against a
backend on port 3012: **25 of 25 checks passed** — self-registration succeeded on
a seedless database, its roles received exactly **61/43/20**, entitlement was
`pending` and business actions gated, activation worked, the Owner reached a
`report.view` route with `x-branch-id`, Manager was allowed `report.view` and
denied `user.manage`, Employee was denied both and allowed the sales surface,
all three tenant roles were refused by the platform administration API, and a
branch the tenant does not own was refused.

### Upgrade path — `prisma_staging_upgrade_proof`

Built to the pre-`0059` state (57 migrations, **44 keys**), per-row checksums
captured, then `0059` applied:

- **exactly 17 rows added** (44 → 61);
- **all 44 pre-existing rows byte-identical** in id, key and label;
- replaying `migrate deploy` — "No pending migrations to apply" — changed nothing;
- re-executing the statement under `STRICT_ALL_TABLES` left the catalogue
  fingerprint identical, ids included.

**The 17 keys:** `branch.manage`, `closing.perform`, `cost.view`,
`discount.apply`, `discount.override`, `expense.manage`, `import.run`,
`integrations.manage`, `purchase.manage`, `report.view`, `sale.create`,
`sale.return`, `settings.manage`, `supplier.manage`, `unit.add`,
`unit.transfer`, `user.manage`.

---

## Applied to staging

Behind `scripts/staging-apply-migrations.ts`: `.env.staging` with
`override: true`, `APP_ENV=staging`, a database name that is unmistakably
staging, a `mysqldump`, and a **restore-proof** of that dump into a disposable
database (83 tables, 61 permission rows) which was then dropped.

Staging already held all 61 keys from the earlier repair, so as predicted the
migration **recorded itself and changed no data**:

| | Before | After |
|---|---|---|
| Catalogue | 61 | **61** |
| Roles / mappings | 6 / 248 | **6 / 248** |
| Role-mapping checksum | `c2cf1e55732161f7` | **`c2cf1e55732161f7`** |
| Repaired companies | 124 mappings each | **124 each** |

No manual catalogue bootstrap was needed afterwards. The gate reports
`61/61 canonical keys present`.

---

## Verification

| Gate | Result |
|---|---|
| Backend suite | **99 suites / 1714 tests, all pass** (was 98 / 1698) |
| Backend `tsc --noEmit` | clean |
| `prisma validate` | valid |
| Migrations | **58 in the tree, highest `0059`** (`0005` has never existed) |
| Staging migration status | 58 applied, **0 pending** |
| Catalogue gate vs staging | `61/61 present`, exit 0 |
| Generator drift check | in step with the canonical source |
| Website `tsc` · tests · build · audit · oxlint | clean · **14/14** · clean · **0 vulnerabilities** · 0 errors, 4 pre-existing warnings |
| Mobile `tsc` · pure suites · i18n parity | clean · 9 files, 0 failures · **en/ar/fr 1752 each** |

**Staging acceptance after the migration: 33/33 original, 44/44 expanded.**

### Demo integrity — unchanged

1 company · 9 users · 7 sales · **10 051.00 MRU** · 7 roles · 159 mappings ·
catalogue 61 · 0 subscription payments · 0 administrative grants ·
role-mapping checksum **`ee023046b819dbfd`** before and after.

---

## ⚠ The one thing deliberately left undone

**The development database was not migrated**, because the task's binding
boundaries forbid touching it. `npx prisma migrate status` against `phonestore`
therefore reports `0059` as pending. That is expected, not a defect:

- it is a **data-only** migration, and dev already holds all 61 keys from the seed;
- applying it there is a one-command no-op whenever someone chooses —
  `npx prisma migrate deploy`.

### Takeover discrepancies

**None.** Every stated expectation matched: HEADs `44ceddd` / `b973f64` /
`ad923df` / `849fca7`, 98 suites / 1698 tests, 57 actual migrations with `0058`
highest and `0005` genuinely absent, no pending migration, 61/43/20, full-canon
SHA-256 `0ddb8c04…`, staging healthy on 8088, four repositories clean and level,
`READY_FOR_HANDOFF` under owner `NONE`.

*(Carried forward from the previous session, still unresolved and still out of
scope: the website suite once reported "no tests" and exited 0 — a false-green
risk for any CI eventually configured. It did not recur in any run this session.)*

---

## State of staging

**Retained and healthy on port 8088.** Single origin preserved; `/admin` is
loopback plus administrator authentication; the API binds loopback only.

- Two fixtures kept: `Staging Test Shop` and `CP4 Shop …`, both with 124
  mappings.
- Acceptance-run tenants removed; administrator sessions revoked; unexpired
  verification codes consumed; **44 audit events preserved**.
- The temporary staging administrator is **deliberately kept** — removing it
  would make the control portal inaccessible.
- All identities synthetic (`@example.invalid`, RFC 2606). No real customer,
  employee or business information exists in staging.
- Temporary ports released: the clean-install backend on 3012 is stopped, and
  both disposable databases are dropped. Only `3011` (loopback), `8088` and
  MySQL `3306` listen.

---

## Next exact action

Nothing is in flight. The permission catalogue is now complete on any database
built by `migrate deploy` alone, and the gate refuses a deployment that is not.

The remaining open decisions are unchanged from the staging checkpoint and are
the Owner's to make: **where staging should be hosted**, and **the private-access
layer for `/admin`** — see [`docs/39`](docs/39_STAGING_ENVIRONMENT.md).

**This is not a production readiness statement.**
