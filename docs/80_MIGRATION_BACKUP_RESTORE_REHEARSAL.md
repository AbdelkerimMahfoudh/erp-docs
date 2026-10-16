# Migration, backup and restore rehearsal — 2026-10-16 (disposable only)

Every database below was created for this rehearsal on a throwaway MySQL in the session's scratch directory and
dropped at the end. **No live, shared or developer database was used or touched.** The owner's PC database
(`phonestore`, at `0091`) was not reachable and was not involved; "the developer schema" below is a copy *shaped* like
it, built by that era's own code.

## The server

| Fact | Value | Live (WAMP) for comparison |
| --- | --- | --- |
| Version | MySQL 8.0.46 (Ubuntu) | not recorded anywhere — check first (`docs/67` §7 step 0) |
| Binary log | ON | WAMP default: OFF |
| `sql_mode` | `''` (empty, as live) for the data paths; MySQL 8's strict default for the CI path | `''` |
| Database collation | `utf8mb4_unicode_ci` (as live) | `utf8mb4_unicode_ci` |
| `lower_case_table_names` | 0 | 1 on Windows — **not reproducible here** |

## Identities

`deploy/mysql-identities.sql`, with four passwords made by `openssl rand -hex 24` into mode-600 files, sent on standard
input. Migrations ran as `phonestore_migrator`, the API as `phonestore_app`, backups as `phonestore_backup`, restores as
`phonestore_admin`. `deploy/verify-mysql-identities.sh` on the migrated copy: **21 passed, 0 failed** (including UPDATE
and DELETE refused by the triggers on `audit_logs` and on `subscription_events`).

## Path 1 — from empty

| Run | Result |
| --- | --- |
| Strict `sql_mode` (`deploy/ci-database-gates.sh`, the CI job) | 96 migrations, then `migrate status` up to date; catalogue and grants complete; identities 21/21; `trial-addons.mysql.spec` 21/21; 1 min 46 s in all |
| Empty `sql_mode`, as the migrator | 96 migrations in 16.6 s; `prisma migrate diff` against the strict-built schema: **no difference**; catalogue and grants complete |

## Path 2 — a copy shaped like live at `0083`

**Built by the pre-0084 code itself** (`ae64de8`, 82 migrations, extracted with `git archive` into scratch):

- `prisma migrate deploy` (15.5 s);
- its own `scripts/qa-boutiques.ts --apply` through its own API: ten fictitious boutiques, each registered, verified
  and activated, with 32 products, 80 phones and 20 accessories received (1 210 identifiers);
- then, through the same old API, per boutique: three paid sales, one part-paid sale to an Arabic-named customer, a
  later payment, and two expenses — one with an Arabic note, one whose note contains ``DEFINER=`x`@`y` `` (the text a
  careless restore filter corrupts).

Result: **94 tables, 30 triggers, 1 290 audit rows, 40 sales, 50 payments, 800 units, 10 companies**.

**Encrypted backup** (`deploy/backup-encrypted.sh`, as `phonestore_backup`):
`phonestore-20261016T052318Z.sql.gz.enc`, 210 352 bytes, SHA-256
`86f436832e300505eaedcba9db2c8d586ba55598d33f5b324e2cf9c3bb198fa8`. Its decrypt, gunzip and trailer were verified by the
script before it exited 0.

**Restore drill** (`deploy/restore-drill.sh`, as `phonestore_admin`, into a new database): PASSED.

- tables 94, triggers 30;
- the row counts of companies, users, sales, sale_items, payments, units, audit_logs, subscription_events and
  otp_challenges;
- binary keys intact, the last audit id;
- trigger bodies identical (one hash);
- **every table's `CHECKSUM TABLE` identical (94 of 94)**;
- drill database dropped.

**`0083` → `0097` with the current code** (`d2ad456`), as the migrator: 14 migrations in **5.2 s**, then
`migrate status` up to date.

- **Schema:** `prisma migrate diff` against a database built fresh from all 96 migrations: **no difference**. Tables
  113 = 113, columns 1 595 = 1 595, index entries 821 = 821, foreign keys 363 = 363, CHECK constraints 121 = 121, and
  the 53 trigger bodies hash-identical.
- **Data, row by row:** the backup was restored beside the migrated copy, and every original column of every row was
  fingerprinted (hex of each value, ordered by primary key):
  - **90 of 94 tables are identical**;
  - the other four only gained rows the migrations insert — `_prisma_migrations` (82 kept, 14 added), `permissions`
    (64 kept, 9 added), `plan_versions` (1 kept, 2 added) and `role_permissions` (1 260 kept, 190 added). Nothing was
    changed or removed.
- **Audit chain** (`scripts/verify-audit-chain.ts`, read-only as `phonestore_backup`): 10 companies, 0 broken.
- **Catalogue and grants** (as `phonestore_app`): complete.
- **The current API** started with **`npm run start:prod`** (fixed in `d2ad456`; before it, that command could not
  start the API), as `phonestore_app`:
  - health `200`;
  - an Owner created by the old code signed in, and the same activity ran with nothing refused: 30 sales, 10 part-paid,
    10 payments, 20 expenses;
  - no error in the log, and no password in it;
  - chain intact afterwards.
- **The old API (`ae64de8`) on the migrated `0097` schema:** health `200`, and the same activity again with nothing
  refused. The chain was intact afterwards, across rows written by the old code, then the new, then the old again. So
  **for these flows a code-only rollback works without a database restore**.
  - Caveat already recorded in `docs/67`: the old API's money-agent *exchange* insert is refused by 0092's CHECK. That
    flow did not exist before 0088 and was not exercised.

## Path 3 — a copy shaped like the developer schema at `0091`

- The `0083` backup was restored and migrated to `0091` by the **0091-era code** (`c7034c8`, the parent of the commit
  that added 0092).
- The same activity then ran through the **0091-era API** (nothing refused, no error): 107 tables, 47 triggers.
- **Encrypted backup** `phonestore-20261016T052904Z.sql.gz.enc`: 317 296 bytes, SHA-256
  `42fe65095cc57b7a776e5aee7f9e39d296109e946ba40ee36e27b84af5484c3c`.
- **Restore drill:** PASSED — 107 tables, 47 triggers, every CHECKSUM identical.
- **`0091` → `0097` with the current code:** 6 migrations in **1.5 s**. The schema diff against a fresh build shows no
  difference. **106 of 107 tables are identical in every original column of every row**; only `_prisma_migrations`
  gained its six rows.

## Path 4 — an interrupted migration, and its recovery

**The fault is the one a hosted MySQL produces.** With the binary log on and `log_bin_trust_function_creators=0`, an
account without SUPER cannot create a trigger (ERROR 1419; `deploy/mysql-identities.sql` header).

1. The `0083` backup was restored and migrated to `0094` (a scratch copy of `prisma/` holding migrations 0001–0094
   only).
2. `SET GLOBAL log_bin_trust_function_creators = 0`.
3. `prisma migrate deploy` → **`P3018`, database error 1419, in `0095_free_trial`**.

**State left behind:**

- `0095` is recorded as failed, `applied_steps_count` 0;
- its **four tables exist, empty** (`trial_eligibilities`, `trial_setup_links`, `trial_claims`,
  `trial_setup_messages`);
- **none of its six triggers exists**;
- `subscription_events.kind` is **not** widened;
- `0096`/`0097` are not applied;
- a second `deploy` is refused with **`P3009`**.

MySQL DDL is not transactional, so a failed migration is half-applied. Never start the new API on it.

**Recovery, rehearsed:**

1. Remove the cause: `SET GLOBAL log_bin_trust_function_creators = 1`.
2. Run `npx prisma migrate resolve --rolled-back 0095_free_trial`.
3. Run `npx prisma migrate deploy`.

It applied 0095, 0096 and 0097 in **1.2 s**. Then:

- 0095 re-runs safely over its own empty leftovers (`CREATE TABLE IF NOT EXISTS`, `DROP TRIGGER IF EXISTS`);
- `migrate status` is up to date;
- the schema diff against a fresh build shows **no difference**, and the 53 trigger bodies are identical;
- against the `0083` backup, 90 of 94 tables are identical in every original column of every row; the other four kept
  every original row and only gained the migrations' reference rows.

`_prisma_migrations` keeps both 0095 records (rolled back, then finished), which is how Prisma records a recovery.

Had any of the four tables held rows, the safe path would differ:

- **Do not re-run.** Restore the pre-migration backup into a new database and verify it (`docs/22` §3).
- Otherwise drop exactly what the migration created, following its *Reverse* note, then resolve and deploy.

## Cleanup

At the end, all of the following was removed from the scratch server:

- every rehearsal database: `prisma_qa_rh83`, `phonestore`, `phonestore_pre0083`, `phonestore_pre0091`, every
  `phonestore_drill_*`, and the CI path's `phonestore`/`addon_ci`;
- the four identities;
- the API processes;
- the encrypted backups, their keys and every password file.

`log_bin_trust_function_creators` was returned to 1 and `sql_mode` to `''`.
