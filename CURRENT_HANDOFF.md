# ERP Current Handoff

## Session control

- Status: READY_FOR_HANDOFF
- Active account: NONE
- Session started: 2026-08-05 20:55 GST (bootstrap by CLAUDE-A)
- Last updated: 2026-08-05 21:05 GST
- Current authorised task: Awaiting explicit user instruction
- Last completed checkpoint: Shared handoff protocol bootstrapped; all three repositories synchronized with their remotes

## Repository state

Verified by `git fetch` + `rev-list --left-right --count` at 21:04 GST. All
clean, all `master`, all level with `origin`.

| Repository | Branch | Local HEAD | Remote HEAD | Working tree |
|---|---|---|---|---|
| Backend (`erp-backend`) | master | `ea22df1` | `ea22df1` | clean |
| Mobile (`erp-mobile`) | master | `2d6f49b` | `2d6f49b` | clean |
| Documentation (`erp-docs`) | master | *current HEAD contains this handoff* | same | clean |

**Note:** the documentation row is deliberately not a hash. A file cannot
contain the id of the commit that introduces it, and writing a follow-up commit
just to record the previous one produces an endless self-referential chain. To
read it: `git -C <docs repo> log --oneline -1`.

**Layout:** the documentation repository is the **workspace root**
(`C:\wamp64\www\PhoneStoreERP`). `backend/` and `mobile/` are nested inside its
working tree but are separate repositories, excluded via the root `.gitignore`.
From either code repository the documentation repository is the **parent
directory** (`../`), not a sibling.

## Verified baseline

Measured 2026-08-05 21:00–21:04 GST, not copied from a previous report.

- Backend tests: **28 suites / 235 tests passing** (`npx jest`)
- Backend TypeScript: clean (`npx tsc --noEmit`)
- Mobile TypeScript: clean (`npx tsc --noEmit`)
- Expo lint: clean (`npx expo lint`)
- Live verification: Settings API and Owner Settings screen exercised against
  the running backend on 2026-08-05 — Owner read/write, employee read, 403 on
  employee writes, 409 on stale save, audit rows with old/new values
- Latest Prisma migration: **`0019_settings_foundation`** (applied)
- Database migration status: `prisma migrate status` → *"Database schema is up
  to date!"*, 18 migrations found, no drift

## Completed milestones

- Design-system foundation: tokens, i18n (EN/AR + RTL), primitives, overlays,
  camera scanner, Product Confirmation Card, frontend permission awareness
- Screens: Sell (POS), Receive, Inventory, Catalog, Analytics, Daily closing
- Inventory: cursor pagination + server-side search; accessory/quantity stock fixed
- Scanner confidence correction; durable recognition outbox (transactional,
  lease-based, no Redis)
- Purchase idempotency (client request identity + payload fingerprint)
- Role migration to Owner / Store Manager / Store Employee (`0016`–`0018`),
  with a SQL-vs-TypeScript drift test
- **Phase E — Settings foundation (`0019`): complete.** `company_settings`
  (return window, WhatsApp summary preferences, auto-lock maximum) and
  `receiving_accounts`; `GET/PUT /settings`, receiving-account create/patch/
  reorder; Owner Settings screen in EN/AR
- Backup/restore hardened: `--hex-blob` mandatory, tested dump sanitiser,
  restore drill verified end to end
- F0 read-only audit of Users/auth/device security → [`docs/23`](docs/23_USERS_AUTH_AUDIT_AND_PLAN.md)

## Work currently in progress

- Exact objective: none — bootstrap only
- Files being changed: none
- Migrations being prepared/applied: none
- Commands already run: `git fetch`, `git status`, `npx jest`, `npx tsc --noEmit`
  (both repos), `npx expo lint`, `npx prisma migrate status`, read-only SQL counts
- Tests currently passing/failing: all passing, none failing
- Temporary data or databases created: none (`SHOW DATABASES LIKE 'prisma%'` → empty)
- Uncommitted work: none in any repository
- Last known safe point: current HEADs, all pushed

## Product and architecture decisions affecting the current task

No implementation task is authorised, so only the standing constraints apply.

- [`docs/21_PRODUCT_DECISIONS.md`](docs/21_PRODUCT_DECISIONS.md) — approved
  product decisions and their four-state reconciliation (Implemented /
  Approved-not-implemented / Blocked / Needs-decision). **Authoritative for
  intended behaviour.**
- [`docs/22_BACKUP_AND_ROLLBACK.md`](docs/22_BACKUP_AND_ROLLBACK.md) —
  mandatory before any schema migration.
- [`docs/23_USERS_AUTH_AUDIT_AND_PLAN.md`](docs/23_USERS_AUTH_AUDIT_AND_PLAN.md)
  — F0 audit and the dependency-ordered F1 plan, if Users work is authorised next.
- [`CLAUDE.md`](CLAUDE.md) — the development rulebook. Wins over habit and
  convenience.

Standing rules worth restating: authorization is **permission-based, never
role-name-based**; business rules and permissions are enforced **server-side**;
nothing financial is hard-deleted; schema changes need a written reason and a
migration.

## Known gaps and blockers

| Gap | Type |
|---|---|
| `unit.transfer` guards all five transfer endpoints — one permission both initiates and completes a transfer | Product decision required, then technical work |
| `purchase.manage` creates a **final** purchase immediately; the approved model wants employee-entered cost to await approval | Product decision required, then technical work |
| `import.run` guards **no endpoint at all** | Technical work required |
| Request/approval splits (`return.request`, `import.prepare` / `import.approve`) | Deferred — belong to Returns and Import workflows |
| Per-user permission overrides do not exist, so "per-user price editing is Owner-delegated" cannot be expressed | Technical work required (F1 stage 2) |
| WhatsApp/OTP provider unchosen — blocks real OTP delivery and end-to-end invitation/new-device verification | Product decision required |
| Camera, haptics, Arabic RTL end-to-end, receipt sharing, scroll-triggered pagination, and all bottom sheets | **Real-device verification required** |
| `settings.discount_limits_by_role` still names retired roles (`sales_employee`, `branch_manager`); nothing reads it | Deferred — belongs with discount monitoring |
| `mobile` has no test runner; adding one is a new dependency | Deferred — needs explicit approval |
| Subscription / seat enforcement | Deferred intentionally |

## Database safety

- Shared database: **`phonestore`** on local MySQL 8.4.7 (WAMP). Treat as shared
  mutable state — both accounts use the same instance.
- Latest verified backup: **`~/erp-backups/phonestore-20260805-203646.sql`**
  (178 854 bytes, trailer present, `--hex-blob`, 0 raw `_binary` literals).
  Restore verified: 48/48 tables, 2/2 triggers byte-identical, `CHECKSUM TABLE`
  identical on all 48, audit triggers proven to still fire.
- Backup taken before latest migration: yes — `phonestore-20260805-154240.sql`
  preceded `0019`.
- Temporary databases: **none.** Scratch databases must be named `prisma_*`
  (the migrator's grants cover `phonestore` and `prisma\_%` only) and dropped
  after verification.
- Demo records that must not be deleted: companies 1 · branches 2 · users 6 ·
  products 12 · units 11 · sales 7 · purchases 9 · audit_logs 77 ·
  company_settings 1 · receiving_accounts 3.
- `audit_logs` is append-only, enforced by database triggers for the
  application account. Never attempt to edit it.
- **Never** run `prisma migrate reset` against `phonestore`.

No credentials appear in this file. Database and app credentials live in
`backend/.env` and `~/.my.cnf`, neither of which is committed.

## Next exact action

None authorised. **Wait for an explicit user instruction.**

When one arrives, the receiving account must, in order:

1. Read this file and the relevant parts of `docs/21_PRODUCT_DECISIONS.md`.
2. Run `git fetch` and `git status` in all three repositories and confirm the
   HEADs above still match.
3. Run `npx prisma migrate status` before any database-related work.
4. Set `Status: IN_PROGRESS`, its account label and the authorised task here,
   **before** changing anything.

If Users/authentication is authorised next, the plan is already written:
`docs/23`, stage 1 (add `phone`/`email` + verification timestamps to `User`).
That is a schema change, so it requires a fresh backup first.

## Explicit boundaries

Not authorised in the current milestone:

- Implementing any product feature — this bootstrap authorises **coordination
  files and Git commits only**
- Returns, Transfers, Users, Goals, Money & reconciliation, Consignment,
  Subscription or Expenses workflows
- Any Prisma schema change or migration
- Widening any permission to close the two approval gaps above
- Adding dependencies to either code repository
- Guessing a WhatsApp, OTP or Bankily integration
- Deleting demo data, resetting the database, or force-pushing any repository

---

## Appendix — bootstrap corrections (2026-08-05, CLAUDE-A)

The bootstrap instruction listed prior state to *verify rather than copy*. Six
items differed from repository and database evidence:

| Reported | Verified | Explanation |
|---|---|---|
| 26 suites / 181 tests | **28 suites / 235 tests** | Settings, sanitiser and role-matrix suites were added after that report |
| Latest migrations `0017`/`0018` | **`0019_settings_foundation`** | Phase E landed and is applied |
| Phase E/Settings "treat as not started" | **Complete** | Evidence: migration `0019` applied, `backend/src/settings/`, `mobile/app/settings.tsx`, live-verified API and screen |
| Store Employee assignments: 5 | **7** | 2 belong to `settingsprobe`, a **deactivated** account created by CLAUDE-A on 2026-08-05 to prove employee 403s. `is_active = 0`; kept so its audit trail stays attributable |
| — | `0017_store_role_backfill` appears **twice** in `_prisma_migrations` | The first attempt failed on a wrong column and was resolved with `migrate resolve --rolled-back`; the second succeeded. Not drift — `migrate status` reports the schema up to date |
| A "web-only BottomSheet defect" recorded earlier | **Withdrawn** | A measurement artifact: the automated browser pane reports `visibilityState: hidden`, so `requestAnimationFrame` delivers zero frames and every animation sits frozen at its initial value. See `docs/21` |

Confirmed correct as reported: Owner assignments 4 · legacy Sales/Warehouse
assignments 0 · permission matrix Owner 17 / Store Manager 11 / Store Employee 6
· inventory pagination, scanner-confidence correction, recognition outbox and
role migration all complete · demo data intact · both approval gaps still open
· real-device verification still outstanding.
