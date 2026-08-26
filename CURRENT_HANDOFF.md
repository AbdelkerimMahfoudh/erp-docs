# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **IN_PROGRESS**
- Active account / Owner: **CLAUDE-B**
- `started_at_utc:` `2026-08-26T21:50Z`
- **Authorised task — close the permission-catalogue deployment defect** with
  reference-data migration `0059`, so a database built by `prisma migrate
  deploy` alone holds all 61 catalogue keys without the demo seed.
- Authorisation is limited to publishing the EXISTING 61-key catalogue. It does
  not permit a new permission, changed role authority, a schema change, or
  migration `0060`.
- HEADs at takeover — `erp-backend` `44ceddd` · `erp-mobile` `b973f64` ·
  `retail-erp-control-web` `ad923df` · `erp-docs` `849fca7`.
- Baseline verified with no discrepancies: 98 suites / 1698 tests · 57 actual
  migrations, highest `0058`, `0005` genuinely absent · 61/43/20 · full-canon
  SHA-256 `0ddb8c04…` · staging healthy on 8088.
- Next intended action: prove the 44-key pre-fix state on a disposable MySQL
  database before writing anything.
- **Do not begin** hosting, CI/CD, administrator MFA, payment-provider
  integration, or the IMEI scanner milestone.

### HEADs — all four repositories clean and level with their remotes

| Repository | HEAD |
|---|---|
| `erp-backend` | `44ceddd` |
| `erp-mobile` | `b973f64` (unchanged — no mobile change was needed) |
| `retail-erp-control-web` | `ad923df` (unchanged) |
| `erp-docs` | *this commit* |

Nothing was force-pushed and no shared history was rewritten.

---

## The defect, and what fixed it

**Root cause — two facts that were only fatal together:**

1. `AccessService.getEffectivePermissions` resolves authority **only** from
   `role_permissions`.
2. `RegistrationService` created three `roles` rows — a key and a name — and
   **no `role_permissions` at all**.

Every shop that signed up through the website got an Owner who could sign in and
then do nothing: `403 Missing permission(s): report.view`.

The demo company worked because `prisma/seed.ts` carried its **own separate copy**
of the provisioning loop. That second implementation is what hid the bug — the
only tenant anybody looked at was provisioned by different code from the one real
shops used.

**Underneath it, a structural cause:** the canonical matrix lived in
`prisma/seed-data/permissions.ts`, and `tsconfig.build.json` **excludes**
`prisma/seed-data` from the production build. The seed could read the matrix; the
server could not. Registration was not careless so much as unable.

### The single canonical source

`src/rbac/role-permissions.ts` — moved there so runtime code can reach it, with
`prisma/seed-data/permissions.ts` left as a **pure re-export** so the seed and
every existing import keep working against exactly one definition.

**Proof the matrix is unchanged:** 61 permissions; `owner` 61 / `store_manager`
43 / `store_employee` 20; SHA-256 over the catalogue, matrix, labels and
store-facing list identical before and after the move —
`0ddb8c04314656dc98f4c293726dedc2dcefbdc414fc1d78fd0ae967af9d668e`. **No
permission key was added, removed, renamed or moved between roles.**

`src/rbac/role-provisioning.ts` is now the **only** place that creates a role or
a `role_permissions` row. Audit confirms it: exactly two company-creation paths
(registration, seed), one `role.upsert` site, one `rolePermission.createMany`
site. No custom-role creation path exists anywhere, so none was disturbed.

Registration provisions **inside its existing transaction**, so roles,
permissions, Owner and subscription succeed or roll back together.

---

## The restricted backfill

`backend/scripts/staging-repair-role-permissions.ts` — **dry run by default**;
writing requires `--apply`.

Before any write: forces `.env.staging` with `override: true`, demands
`APP_ENV=staging`, rejects any database name that is not unmistakably staging
(and anything matching `phonestore`, `prod`, `production`, `live`, `demo`), takes
a `mysqldump`, and **restore-proves it into a disposable database** which is then
dropped.

Eligibility — every condition required, and **re-proven inside the write
transaction**: registration provenance · exactly the three default role keys ·
**all three** with zero mappings · not the demo tenant. Anything partial or
customised is **skipped whole** and reported for manual review; nothing is
completed, normalised or replaced.

Audited as `adminId: null`, `actor: 'system:role-permission-repair'` — no
fabricated human, no misused administrator.

### Result in staging

| | |
|---|---|
| Examined | 6 companies |
| **Repaired** | **4** — each `owner 0→61`, `store_manager 0→43`, `store_employee 0→20` (**+124 mappings** each) |
| **Skipped** | 0 on the first run; **4 on the replay**, reported as "already provisioned with the canonical matrix" |
| Backup | `prisma_staging-before-role-repair-2026-08-26T20-48-46-745Z.sql`, **restore-proved** — 83 tables into a disposable database, then dropped |
| Partial/custom roles | **none existed**; the rules that would skip them are unit-tested |

**Demo tenant: zero changes.** 7 roles, 159 mappings, checksum
`ee023046b819dbfd`, 1 company / 9 users / 7 sales / 10 051.00 — identical before
and after. The development database was never targeted.

---

## A second gap the repair exposed

The repair **refused its first run**: `Permission "sale.create" is not in the
database catalogue.` **Staging held 44 of the 61 permission keys.**

The catalogue is reference data every environment needs, and **no migration
creates it** — the base keys are inserted only by `prisma/seed.ts`, which also
seeds the demo company and so never runs against staging. `seed-staging.ts` now
seeds it through the same `PERMISSIONS` constant; 17 keys were added.

That refusal is the guard working. Silently granting 60 of 61 permissions would
have been far worse than stopping.

> ### ⚠ Still open — reported, not fixed
>
> **A database built by `prisma migrate deploy` alone has an incomplete
> permission catalogue**, because the base keys exist only in the demo seed.
> Closing it needs either a reference-data migration or a deploy step that runs
> `seedPermissions()` — the second is the safer design. Both are outside this
> repair's authorised scope, and this task did not authorise migration 0059.

---

## Verification

| Gate | Result |
|---|---|
| Backend suite | **98 suites / 1698 tests, all pass** (was 95 / 1657) |
| Backend `tsc --noEmit` | clean |
| `prisma validate` | valid |
| Migration status | **57 applied, 0 pending** — unchanged, no 0059 |
| Website `tsc` · tests · build · audit | clean · **14/14** · clean · **0 vulnerabilities** |
| Website lint (**oxlint**) | 0 errors, 4 pre-existing warnings |
| Mobile `tsc` · pure suites · i18n parity | clean · 9 files, 0 failures · **en/ar/fr 1752 each** |

**Staging acceptance: 44 of 44.** The 16-step CP4 flow plus 11 further live
checks. Highlights: a company registered **after** the fix received exactly
61/43/20 with no repair involved · while pending, the portal reads and business
actions are gated · after activation the Owner reaches a `report.view` route ·
Manager allowed `report.view` and denied `user.manage` · Employee denied
`report.view` and `user.manage`, allowed the sales surface · cross-company read
refused · Owner, Manager and Employee each refused by the platform administration
API · `/admin` 404 from the LAN, 200 from loopback · the API port unreachable
from the LAN · registration and repair replays both no-ops.

> **`report.view` is branch-scoped.** Without an `x-branch-id` header only
> company-wide permissions resolve. An earlier acceptance run mistook that
> boundary for the defect; it is the branch-safety design working.

---

## Baseline discrepancy found at takeover

Reported, not fixed, and outside this repair's scope: the **website test suite
reported "no tests" once** on the first invocation, then 14/14 on ten consecutive
runs including a cold Vite cache. Not reproducible. It matters because that state
**exits 0** — a false-green risk in any CI that is eventually configured.

Everything else matched the recorded handoff exactly.

---

## State of staging

**Retained and healthy on port 8088**, single-origin preserved, `/admin`
loopback-plus-authentication.

- Two tenants kept as fixtures: `Staging Test Shop`, and `CP4 Shop …` (fully
  exercised — Owner, Manager and Employee, activated).
- Four disposable harness tenants removed; **12 administrator sessions revoked**;
  7 unexpired verification codes consumed; **32 audit events preserved**.
- The temporary staging administrator is **deliberately kept** — removing it
  would make the control portal inaccessible. Its password lives only in a file
  outside every repository, and appears in no commit and no log.
- All identities are synthetic (`@example.invalid` — RFC 2606, never a real
  domain). No real customer, employee or business information exists in staging.

---

## Next exact action

Decide how the **permission catalogue** should be applied to a database built by
`migrate deploy` alone (see the open item above). Recommended: a deploy step that
runs `seedPermissions()`, rather than a reference-data migration — it keeps the
catalogue defined in exactly one place, which is the property whose absence
caused this whole defect.

Nothing else is in flight. **This is not a production readiness statement.**
