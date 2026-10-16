# 22 — Backup & Rollback Procedure

> **Mandatory before every Prisma schema migration.** Code rollback does not undo a migration: reverting `schema.prisma` leaves the database already altered, and a partially-applied migration can leave it in a state no commit describes.
>
> Two independent protections are needed, because they fail differently:
> **code** (git) and **data** (a dump).

---

## 1. Code rollback

| Repository | Remote (private) | State |
|---|---|---|
| repo root | `AbdelkerimMahfoudh/erp-docs` | `docs/` + `CLAUDE.md`, 19 files |
| `backend/` | `AbdelkerimMahfoudh/erp-backend` | baseline `f941a21`, 180 files |
| `mobile/` | `AbdelkerimMahfoudh/erp-mobile` | 3 commits, 119 files |

All three are **private** and pushed, so code and documentation now have an
off-machine copy. Default branch is `master` on all three.

⚠️ **Code on GitHub is not a database backup.** These repositories hold code and
documentation only. Pushing every commit protects nothing about the business:
sales, units, costs and the audit trail exist solely in local MySQL until a dump
is taken (§2). A green GitHub page and a lost database are entirely compatible
states.

To return the backend to the verified baseline:

```bash
git -C backend stash            # keep uncommitted work
git -C backend checkout f941a21 # inspect the baseline
```

Never use `reset --hard` to recover: it discards uncommitted work irreversibly.

---

## 2. Database backup — before any migration

### Credential handling

**Credentials must never appear in a command, a script, a shell history or a log.** A password passed as `-pSECRET` is visible to every user on the machine via the process list, and lands in shell history.

Use a **MySQL option file** instead. Create it once, outside the repository:

```ini
# ~/.my.cnf   (chmod 600 — readable only by you)
[client]
user=root
password=<your password>
```

`mysqldump` and `mysql` read it automatically. No credential ever reaches the command line.

Confirm the file is not world-readable, and that it is outside any git working tree.

### Taking the dump

```bash
mysqldump --defaults-extra-file="$HOME/.my.cnf" --single-transaction --routines --triggers --events --no-tablespaces --hex-blob phonestore > "$HOME/erp-backups/phonestore-$(date +%Y%m%d-%H%M%S).sql"
```

**This is the canonical command. `--hex-blob` is not optional.**

Why each flag matters:

| Flag | Reason |
|---|---|
| `--single-transaction` | Consistent snapshot on InnoDB **without locking tables** — the app keeps working during the dump |
| `--routines` | Stored procedures and functions |
| `--triggers` | **Essential here** — append-only protection for `audit_logs` **and `price_change_events`** is enforced by triggers, created by migrations `0028_audit_append_only_triggers` and `0027_pricing_foundation`. A dump without them silently loses both guarantees. Expect **4 triggers** in any current dump |
| `--events` | Scheduled events, if any |
| `--no-tablespaces` | The migrator has no global `PROCESS` privilege. Without this flag `mysqldump` prints `Access denied … PROCESS privilege … when trying to dump tablespaces`. The dump is still complete, but a real error in a backup log is one nobody should have to learn to ignore |
| `--hex-blob` | Writes every binary column as `0x…` instead of raw bytes. **This is what makes the file safe to handle with ordinary text tools** — see below |

### Why `--hex-blob` matters more than it sounds

Every id in this database is a `BINARY(16)` UUIDv7. Without `--hex-blob`,
`mysqldump` writes them as raw bytes inside `_binary '…'`, and the resulting
file is **not valid UTF-8**. Anything that decodes it as text and re-encodes it
— `sed` under some locales, PowerShell `-replace`, `Get-Content`/`Set-Content`,
a default Node `readFileSync(…, 'utf8')`, some editors, some file-transfer and
cloud-sync tools — replaces each invalid sequence with `U+FFFD`. The restore
then *succeeds*, and the corruption only surfaces later as rows that no longer
join.

With `--hex-blob` the same row becomes:

```sql
INSERT INTO `companies` VALUES (0x018F0000000070008000000000000001,'Demo Phone Store',…);
```

Pure ASCII for the ids, real UTF-8 for the text. Measured on the
2026-08-05 dump: **0 raw `_binary` literals, 1430 hex literals, and the whole
file round-trips through a UTF-8 decode unchanged.**

The file is larger — 178 854 bytes against 164 295 for the same data without
the flag, about 9% — which is a trivial price for a backup that survives being
copied by ordinary tools.

⚠️ **Legacy dumps taken before 2026-08-05 do not have this.** Everything in
`~/erp-backups/` dated `20260804` and the `20260805-154240` file contain raw
binary. They are still restorable, but they must be moved and processed only
with byte-exact tools. `scripts/sanitize-dump.js` is byte-exact by design
(§3), so it remains safe for them.

On Windows, `mysql` and `mysqldump` do **not** read `~/.my.cnf` automatically —
pass `--defaults-extra-file` explicitly, as above.

### Verify the dump before migrating

A dump you have not checked is not a backup.

```bash
ls -lh "$HOME/erp-backups/" | tail -1     # non-trivial size
tail -1 "$HOME/erp-backups/<file>.sql"    # must end: -- Dump completed
```

A truncated dump often ends mid-statement — the size and trailer check catches it in seconds.

---

## 3. Restore

> **Restoring is not `mysql phonestore < dump.sql`.** That command fails
> part-way through with this database, and the way it fails is dangerous.

### The DEFINER problem

`mysqldump --triggers` records the *owner* of every trigger:

```sql
/*!50003 CREATE*/ /*!50017 DEFINER=`root`@`localhost`*/ /*!50003 TRIGGER `audit_logs_block_update` …
```

Recreating an object owned by another account requires `SUPER` or
`SET_ANY_DEFINER`. `phonestore_migrator` deliberately has neither — it holds
`ALL PRIVILEGES` on two schemas and nothing global. Restoring as the migrator
therefore stops dead:

```
ERROR 1227 (42000) at line 94: Access denied; you need (at least one of)
the SUPER or SET_ANY_DEFINER privilege(s) for this operation
```

**Why this matters more than it looks.** The dump writes triggers *before* the
data. When the restore aborts at line 94, it has already created a couple of
tables and has loaded **no rows at all**. Measured during the drill below: an
aborted restore left `2` of `46` tables and zero business data, while the shell
had reported nothing but that one line. A restore that stops early looks, from
the outside, a lot like a restore that worked.

### Path 1 — restore with an authorised DBA account

Preferred when a DBA account is available: it recreates the original definers
exactly as dumped, so the restored database is identical to the backup down to
trigger ownership.

```bash
mysql --defaults-extra-file="<dba option file>" --comments phonestore < "$HOME/erp-backups/<file>.sql"
```

The account needs `SUPER` or `SET_ANY_DEFINER`, plus the ability to create the
accounts named in the `DEFINER=` clauses if they no longer exist. On a machine
rebuilt from scratch, `root@localhost` may not be the same account it was — if
it is missing, Path 1 fails too and Path 2 is the answer.

### Path 2 — sanitise a separate copy, restore as the migrator

Removes the `DEFINER=` clauses so the restoring account becomes the definer.
The trigger *logic* is unchanged, which is all the append-only guarantee
depends on — it tests `USER()` at run time, not who owns it.

```bash
node backend/scripts/sanitize-dump.js "$HOME/erp-backups/<file>.sql"
```

This writes a **new** file, `<file>.no-definer.sql`, alongside the original.
It never modifies the input, refuses to overwrite an existing output, and
refuses outright to process a dump with no `-- Dump completed` trailer.

Then restore normally:

```bash
mysql --defaults-extra-file="$HOME/.my.cnf" --comments phonestore < "$HOME/erp-backups/<file>.no-definer.sql"
```

**`--comments` matters.** The `mysql` client strips comments from the statements it sends unless told not to, and
several triggers carry comments inside their bodies (0042's identifier triggers; 0085's chain trigger). Without the
flag the restored triggers behave identically but their bodies differ from the source, so the byte-comparison below
reports differences that are not damage (measured 2026-10-03: 2 of 30 trigger bodies; 0 with the flag).

**The copy takes the source's defaults.** Create a restore or drill database with the source database's character
set and collation (read them from `information_schema.SCHEMATA`), not fixed ones: a trigger's or a routine's variables
take the database's collation.

Delete the sanitised copy afterwards. The original dump is the backup; a second
near-identical file only creates doubt about which one is authoritative.

### Why a script and not a `sed` one-liner

Two independent reasons, and `--hex-blob` only removes the first one.

**1. Legacy dumps are not valid UTF-8.** Before `--hex-blob` became the
canonical command, `BINARY(16)` keys were emitted as `_binary '<raw bytes>'`,
and any tool that decoded the file as text destroyed every primary key (see §2).
New dumps no longer have this problem — but the sanitiser must keep working on
the older files sitting in `~/erp-backups/`, so it stays byte-exact.

**2. `DEFINER=` can appear in row data.** A product named
``Bankily DEFINER=`x`@`y` cable`` is a legitimate string. A blind substitution
would rewrite it and silently corrupt the record. The script only rewrites DDL
lines; `INSERT`/`REPLACE` lines are copied untouched.

`scripts/sanitize-dump.js` therefore reads and writes `latin1` — a byte-for-byte
round trip regardless of what the file contains — and refuses to touch the
input, to overwrite an existing output, or to process a dump with no
`-- Dump completed` trailer. Covered by `src/prisma/sanitize-dump.spec.ts`,
including both the raw-binary and the hex-blob shapes.

**New dumps do not depend on the sanitiser for binary preservation.** They
depend on it only for the DEFINER problem, which `--hex-blob` does not address.

### Verify the restore

Counting tables is not enough; check structure, data and the audit protection.

```bash
# 1. tables and triggers, restored vs live
mysql --defaults-extra-file="$HOME/.my.cnf" -N -e "SELECT (SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA='phonestore'), (SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA='phonestore');"

# 2. data actually arrived — not just the schema
mysql --defaults-extra-file="$HOME/.my.cnf" -N -e "SELECT COUNT(*) FROM phonestore.sales;"

# 3. binary keys survived intact
mysql --defaults-extra-file="$HOME/.my.cnf" -N -e "SELECT MD5(GROUP_CONCAT(HEX(id) ORDER BY id)) FROM phonestore.units;"
```

Expect **46 tables and 2 triggers**. A restore reporting fewer tables than the
dump contains stopped early — see the DEFINER problem above.

**Then verify the audit triggers actually execute.** Their presence in
`information_schema` proves only that a row exists. Run the write they are
supposed to block, as the *application* account, inside a transaction:

```bash
mysql --defaults-extra-file="<app option file>" phonestore -e "START TRANSACTION; UPDATE audit_logs SET action = action LIMIT 1; ROLLBACK;"
```

This must fail with:

```
ERROR 1644 (45000): audit_logs is append-only for the application user
```

**Success here is the failure.** If that `UPDATE` succeeds, the append-only
guarantee is gone and the restore is not finished, however healthy the row
counts look.

### Practising the restore

Practise into a scratch database, never over live data. The migrator's grants
cover `phonestore` and `prisma\_%`, so **a scratch database must be named
`prisma_…`** or the migrator cannot create it.

One limitation to know before you rely on the drill: `phonestore_app` has
privileges on `phonestore` only, so the trigger-execution probe above **cannot
be run inside a `prisma_*` scratch database** — the app account cannot reach it,
and the migrator lacks `GRANT OPTION` to give it access. In a scratch drill,
verify instead that the restored trigger bodies are byte-identical to the live
ones:

```bash
mysql --defaults-extra-file="$HOME/.my.cnf" -N -e "SELECT l.TRIGGER_NAME, (l.ACTION_STATEMENT = r.ACTION_STATEMENT) FROM information_schema.TRIGGERS l JOIN information_schema.TRIGGERS r ON r.TRIGGER_NAME = l.TRIGGER_NAME AND r.TRIGGER_SCHEMA='<scratch db>' WHERE l.TRIGGER_SCHEMA='phonestore';"
```

Drop the scratch database as soon as the drill is done.

### The scripted, encrypted path (2026-09-30, backend `bde6bc4`)

Two scripts now carry the whole procedure, so it is run the same way every time and by a schedule rather than by
memory (`docs/48` §8):

- **`deploy/backup-encrypted.sh`** — `mysqldump --single-transaction --routines --triggers --events --no-tablespaces
  --hex-blob` as the **read-only backup identity** (`phonestore_backup`, `deploy/mysql-identities.sql`), piped through
  gzip and `openssl enc -aes-256-cbc -pbkdf2` with a passphrase read from a file (mode 600), never an argument. The
  plaintext never touches the disk. Before it exits 0 it decrypts and decompresses the file in memory and demands
  mysqldump's own `-- Dump completed` trailer, writes a `.sha256` beside the file and prunes to the newest 14.
- **`deploy/restore-drill.sh`** — checks the checksum, restores into a **new** database `<db>_drill_<stamp>` (never over
  live) with DEFINER clauses stripped, compares table and trigger counts, representative row counts, the first binary
  key and the last audit id with the source, proves the append-only guard came back (an `UPDATE` as the application
  account refused), and drops the drill database unless `KEEP_DRILL=1`.

Credentials for both come from files; the passphrase must be kept **off the database host** (a backup on the same
disk as its key is not a backup). The off-host copy of the encrypted files (`docs/48` §8.2) is a separate job.

Since 2026-10-03 (`867133e`) the drill creates its copy with the source's character set and collation, strips
`DEFINER` on schema lines only (a row whose text holds ``DEFINER=`x`@`y` `` is data), restores with `--comments`,
compares every trigger body and every table's `CHECKSUM`, and passes the append-only probe only when the trigger refused
it (SKIP when the application account has no grant on the copy — its grants name the live schema). Compare against a
source that has not moved since the backup: run it in the quiet window right after the backup, as the runbook does
(`docs/67` §7). On a server with the binary log on, creating the dump's triggers needs
`log_bin_trust_function_creators=1` (ERROR 1419 otherwise).

### Drill record — 2026-10-10 (E.5, the rehearsal of 0088 → 0091, `docs/73` §8.3)

Run in a throwaway MySQL 8.0.46 on `127.0.0.1:3310` in the OS temporary directory, on synthetic QA data (`prisma_qa_st`:
the ten QA boutiques, two annex stores and their staff, built through the `0087` API) — **not live, not the PC's
database**.

| Check | Result |
|---|---|
| Source | `prisma_qa_st` at 0087: 97 tables, 31 triggers, 10 companies, 12 branches, 16 users, 800 units, 320 products, 1 240 audit rows |
| Dump before (migrator, `--hex-blob`) | `prisma_qa_st-before-0088-20261010-023255.sql`, 1 663 086 bytes, trailer present, 97 `CREATE TABLE`, 31 triggers, 0 raw `_binary`, sha256 `91f2932ec88c94d5…` |
| Fingerprint before | every table's row count and `CHECKSUM TABLE`, every trigger body's MD5 |
| `prisma migrate deploy` | 0088, 0089, 0090, 0091 applied in order; status up to date (90 migrations) |
| After | 107 tables (`agent_*` 9, `branch_replacements`), 47 triggers (+16, every new one append-only for the application identity), plan v3 500/300/700, 9 agent permissions (Owner 9 grants in each company), all 12 branches `electronics`, `daily_closings.money_version`, `seat_allocations.replaces_branch_id`/`replacement_credit`/`replacement_period_id`, request-key operations `provider_create`/`provider_update`/`provider_config` |
| `prisma migrate diff` (migrations → schema) | the only new lines re-create the nine 0091 foreign keys with Prisma's default referential actions — the pattern every hand-written migration already shows (0089's agent keys included); no table, column or index differs |
| Demo data, before → after | every pre-existing table identical by row count except the catalogue rows the migrations add (`_prisma_migrations` 86 → 90, `permissions` 64 → 73, `plan_versions` 2 → 3, `role_permissions` 1 260 → 1 450); every `CHECKSUM` identical except `branches` and `billing_periods`, which gained columns — their original columns are identical (MD5 over every original column, 12 and 10 rows); no trigger body changed |
| Path 2 (31 definers stripped, `--comments`) into `prisma_qa_st_restore` | **every table's row count and CHECKSUM and every trigger body identical to the pre-0088 fingerprint**; `HEX(id)` MD5 identical for `units`, `audit_logs`, `products`; then dropped, the sanitised copy deleted |
| Dump after | `prisma_qa_st-after-0091-20261010-031026.sql`, 1 729 146 bytes, trailer, 107 tables, 47 triggers, sha256 `c0a5d41dac7c1e9e…` — restored before each real-HTTP run |
| Cleanup | the rehearsal databases dropped and the throwaway server stopped at the end of the session (`CURRENT_HANDOFF.md` records it) |

### Drill record — 2026-10-08 (E.4, the rehearsal of 0088 → 0090, `docs/73` §8)

Run in a throwaway MySQL 8.0.46 on `127.0.0.1:3310` in the OS temporary directory, on synthetic QA data
(`prisma_qa_ma`: the ten QA boutiques at `0001`–`0087`) — **not live, not the PC's database**.

| Check | Result |
|---|---|
| Source | `prisma_qa_ma` at 0087: 97 tables, 10 companies, 12 branches, 16 users, 800 units |
| Dump before (migrator, the live path, `--hex-blob`) | `prisma_qa_ma-before-0088-20261008-173135.sql`, 1 657 866 bytes, trailer present, sha256 `ccb838f39abf6b46…` |
| `prisma migrate diff` | silent on every object of 0088–0090 (only the pre-existing drift of older hand-written migrations) |
| `prisma migrate deploy` | 0088, 0089, 0090 applied in order; 89 migrations applied in all; status clean |
| After the three | 105 tables (8 `agent_*`), 12 `agent_*` triggers, plan version 3 = 500/300/700, every branch `electronics`, 9 agent permissions, grants 90/70/30 rows for Owner/Store Manager/Store Employee, Administrator 0 |
| Path 2 (sanitised, 31 definers stripped) into `prisma_qa_ma_restore` | every table identical by row count, 97 tables, no `activity` column — the 0087 state exactly; then dropped |
| Dump after | `prisma_qa_ma-after-0090-20261008-174132.sql`, sha256 `636e4c452c425e79…` |
| Cleanup | the rehearsal databases dropped and the throwaway server stopped at the end of the session (`CURRENT_HANDOFF.md` records it) |

### Drill record — 2026-10-03 (E.3, the rehearsal of 0084 → 0085, `docs/67` §6)

Run in a throwaway MySQL 8.0.46 configured like live (empty `sql_mode`, `utf8mb4_unicode_ci`, binary log off,
`lower_case_table_names=1`) on synthetic QA data — **not live**. Identities created by the fixed
`deploy/mysql-identities.sql` (passwords on standard input).

| Check | Result |
|---|---|
| Source | `prisma_qa_rc` at 0083, filled through the pre-0084 API: 94 tables, 30 triggers, 1 195 audit rows |
| Encrypted backup (backup identity) | 192 KB, 94 tables, trailer verified, `.sha256` written |
| Canonical dump (migrator, the live path) | 1 500 586 bytes, 94 `CREATE TABLE`, 0 raw `_binary`, 20 957 hex keys, trailer |
| Path 2 + `--comments` into a new database | **every table identical by row count and `CHECKSUM TABLE`**, 30 of 30 trigger bodies identical, `HEX(id)` checksums identical for `units`, `sales`, `audit_logs`, the product named ``DEFINER=`x`@`y` cable`` intact |
| The fixed `restore-drill.sh` | PASSED: 94 tables, 30 triggers, rows, ids, trigger bodies, every table's CHECKSUM; append-only probe SKIP (no grant on the copy) |
| The previous `restore-drill.sh` on the same backup | reported PASSED on a copy whose product name had become ` cable a`; its `products` CHECKSUM differs from the source — the new check fails that restore |
| After 0084 and 0085 on the restored copy | `verify-mysql-identities.sh` **20 of 20**; `verify-audit-chain.ts` **10 of 10 companies OK** |
| Cleanup | every rehearsal database dropped, the throwaway server stopped and its files removed |

**Correction to E.2 (recorded 2026-10-03).** E.2 says the identities were "created by `deploy/mysql-identities.sql`";
the committed script could not run then (`IDENTIFIED BY @var`), so they cannot have been created by it as committed,
and the drill script of that day passed its append-only probe on a missing grant. E.3 is the first record made with
the working scripts.

### Drill record — 2026-09-30 (E.2, encrypted, on a disposable copy)

Run in the session's disposable MySQL 8.0.46 against `prisma_sec` (a fresh database built from all 85 migrations and
the security journey's data — **not live**, which this session cannot reach), with the four identities created by
`deploy/mysql-identities.sql`:

| Check | Result |
|---|---|
| Identities (`deploy/verify-mysql-identities.sh`) | **20 of 20**: the application account reads, cannot `ALTER`/`CREATE`/`DROP`/create a trigger/`GRANT`/read `mysql.*`; it appends an audit row and its `UPDATE`/`DELETE` on `audit_logs` and `UPDATE` on `subscription_events` are refused by the triggers (**§2.5 of the gate, exercised as the application account**); the backup account reads and dumps schema objects, cannot insert/update/delete/alter; the migrator alters its schema, cannot touch `mysql.*` or grant server-wide |
| Backup | `prisma_sec-20260930T144525Z.sql.gz.enc`, 52 KB, **95 tables**, trailer verified after decrypt + gunzip, `.sha256` written |
| Restore | into `prisma_sec_drill_20260930T144527Z`: checksum ok; **95 / 95 tables, 30 / 30 triggers**; rows identical for `companies` (2), `users` (4), `sales`, `sale_items`, `payments`, `units`, `audit_logs` (32), `subscription_events` (12), `otp_challenges` (5); first company id `01A0F2B93EF47D9CA581FF2C8AA5FEFC` intact; last audit id 32; the restored append-only trigger refused an `UPDATE` as the application account |
| Cleanup | the drill database dropped by the script; no `*_drill_*` database left |

**Owed on production:** the same two scripts run on the production host with its own passphrase, the encrypted file
copied off-host, and this table repeated with production's numbers.

### Drill record — 2026-08-05 (E.1, `--hex-blob`)

The canonical command was re-run and the whole path exercised again against
**`phonestore-20260805-203646.sql`** (178 854 bytes, trailer present, **0 raw
`_binary` literals / 1430 hex literals**, valid UTF-8), restoring into the
scratch database `prisma_e1_restore`:

| Check | Result |
|---|---|
| Binary values are hexadecimal | 0 `_binary '` occurrences, 1430 `0x…` literals |
| Whole file survives a UTF-8 decode/encode round trip | **yes** (the pre-`--hex-blob` dump did not) |
| Original dump restored by the migrator | **Failed** — `ERROR 1227` at line 94, as designed |
| Sanitiser | 2 definers stripped on 2 lines; original still had its 2 afterwards |
| Sanitised dump restored by the migrator | Succeeded, exit 0 |
| Tables | 48 live / 48 restored |
| Triggers | 2 / 2, bodies and timing byte-identical |
| Representative row counts | Identical across `companies`, `branches`, `users`, `units`, `sales`, `sale_items`, `purchases`, `audit_logs`, `stock_items`, `products`, `company_settings`, `receiving_accounts` |
| `HEX(id)` checksums | `MD5(GROUP_CONCAT(HEX(id) ORDER BY id))` identical for `units`, `sales`, `audit_logs`, `receiving_accounts` |
| Every table | `CHECKSUM TABLE` identical across all 48 — 0 mismatches |
| UTF-8 text | Arabic label `مصرفي – الصندوق` and the en-dash restored intact |
| Restored trigger executes | An `UPDATE` that genuinely changed a row succeeded as the migrator (1 row, rolled back) — the trigger ran and took its non-blocking branch |
| Audit protection still fires | `UPDATE` and `DELETE` on `audit_logs` as `phonestore_app` both rejected with `ERROR 1644 (45000)`; 77 rows before and after |
| Cleanup | `prisma_e1_restore` dropped, sanitised copy deleted, no `prisma_*` database left |

### Drill record — 2026-08-05 (E0, pre-`--hex-blob`)

The first drill, kept because it is what established the DEFINER failure mode.
Run against `phonestore-20260805-154240.sql` (164 295 bytes) into
`prisma_e0_restore`:

| Check | Result |
|---|---|
| Original dump restored by the migrator | **Failed** — `ERROR 1227` at line 94, leaving 2 of 46 tables and no data |
| Sanitiser output | 2 definers stripped on 2 lines, original byte-identical afterwards |
| Sanitised dump restored by the migrator | Succeeded, exit 0 |
| Tables | 46 live / 46 restored |
| Triggers | 2 live / 2 restored, bodies and timing byte-identical; definer became `phonestore_migrator@localhost` as intended |
| Row counts | Identical across `companies`, `branches`, `users`, `units`, `sales`, `sale_items`, `purchases`, `audit_logs`, `stock_items`, `products` |
| `BINARY(16)` keys | `MD5(GROUP_CONCAT(HEX(id)))` identical for `units`, `sales`, `audit_logs` |
| Every table | `CHECKSUM TABLE` identical for all 46 — 0 mismatches |
| Restored trigger executes | An `UPDATE` that genuinely changed a row succeeded as the migrator (1 row changed, rolled back) — the trigger ran and correctly took its non-blocking branch |
| Trigger blocks the app account | `UPDATE` and `DELETE` on `audit_logs` as `phonestore_app` both rejected with `ERROR 1644 (45000)`; 65 rows before and after |
| Cleanup | `prisma_e0_restore` dropped, sanitised copy deleted, no `prisma_*` database left |

The blocked-write probe ran against the live schema because of the privilege
limitation described above. It is the same statement, against triggers whose
bodies were proven byte-identical to the restored ones, and it was wrapped in a
transaction that was rolled back.

---

## 4. Migration sequence

0. Rehearse the migration on a restored copy first, the way `docs/67` §6 did, and follow the runbook (`docs/67` §7).
1. Backup and **verify** the dump (§2).
2. Confirm the backend working tree is committed — `git -C backend status`.
3. Apply the migration.
4. Run the full test suite and typecheck.
5. Smoke-test the live app.
6. If anything fails: restore the dump (§3) **and** check out the previous commit. Both, in that order.

---

## 5. Known gaps

- **Database dumps are still local-only.** Code is off-machine; data is not. A disk failure still loses every sale, unit and audit record. Dumps should be copied somewhere off this machine — but **never into these repositories**, which is why `*.sql.gz`, `*.dump` and `backups/` are ignored.
- **No DBA option file is set up on this machine.** Only the migrator's credentials are configured, so Path 1 has not been exercised here. Path 2 has (§3).
- **Restores are unscheduled.** The procedure is now tested, but nothing re-tests it after future migrations. A drill is only true for the schema it was run against.

### Resolved

- ~~No off-machine copy~~ — three private GitHub repositories, verified private via the API, with remote file counts matching local exactly.
- ~~`docs/` unversioned~~ — now `erp-docs`.
- ~~`.env.example` holds real credentials~~ — sanitised to placeholders (commit `71637b2`) and now tracked.

### Exposure audit — no rotation required

Before and after publishing, every commit of all three repositories was checked:

- No `.env`, `.env.example`, `node_modules/`, `*.pem` or key file ever appeared in any commit, locally or on GitHub.
- The actual secret **values** were searched for across every blob in all history: absent from all of them.

The values that `.env` and `.env.example` shared were development defaults
(`migrator_dev_pw`, `ChangeMe_Dev_Only!`, a self-describing placeholder JWT
secret) on a local MySQL, never production credentials. **No exposure
occurred, so no rotation was performed.** They must still be replaced with
real, distinct secrets before any deployment.

## Rehearsal record — 0084 → 0094 (2026-10-12, disposable only)

Backups by `mysqldump --single-transaction --routines --triggers` and restores proven before applying: 0083 (built from
the migrations; structure and 30 triggers identical after restore) and the PC data at 0091 (all 106 tables identical
after restore). Applied with `prisma migrate deploy`: 0084–0094 in 8.5 s on the empty base; 0092–0094 in 4.1 s on the
PC data; drift none beyond the known baseline. Rollback = restore the pre-migration backup (proven). Details: `docs/75`
§3.1. Nothing applied to `phonestore` or any live database.

## Rehearsal record — 0095 and 0096, the free trial (2026-10-13, disposable only)

The rehearsal ran in a cloud container on MySQL 8.0.46 with `sql_mode=''` (as on the owner's PC) and UTC. The
application identity was `phonestore_app`, the subject of the triggers. **Nothing was applied to `phonestore` or to any
live or shared database.**

**The dataset at 0094.**

- It was built from all 93 migrations, then populated **through the pre-trial API** (backend `aad5862`).
- It holds the QA fixture: an administrator and 10 boutiques registered on the public route, verified and granted 365
  days.
- It holds four more businesses: a self-registered one never approved, a refused one, a suspended one, and one created
  in the console.
- 14 companies in all.

**The backup.**

- File: `prisma_qa_rh0094-before-0095-20261013T042314Z.sql`.
- Size: 1 675 138 bytes.
- SHA-256: `573ddadafa1794d0cf711b2f0c3d773872a8f17a5e6e18eb5da3e749ae37293f`.
- The trailer "Dump completed" is present.
- **The restore was proven:** 108 tables identical (row counts and `CHECKSUM TABLE`), and 47 triggers.

**The migration.**

- `prisma migrate deploy` applied 0095 and 0096 in 1.5 s.
- The four new tables are empty: there is no backfill.
- 53 triggers now exist (47 + 6).
- Every pre-existing table is identical in rows and checksum, `subscription_events` included: its ENUM was widened and no
  row moved.

**Behaviour on the migrated copy.** Every pre-existing business keeps its state, with no trial view, no offer, no app
card, and a claim refused (20 / 20 checks).

**The rollback, two ways:**

- **Reverse SQL** (0096 then 0095, plus the two `_prisma_migrations` rows) returns the schema to the 0094 backup exactly.
  Only the behaviour check's own activity differs in rows.
- **Restoring the backup**, proven above.

Details are in `docs/76` §14.

## Rehearsal record — 0097, scheduled add-ons (2026-10-15, disposable only)

`0097_scheduled_addons` serves the owner's correction of 2026-10-15 (D176): a store or a paid seat paid for during a
free trial waits, *scheduled*, for the trial's end. **It is a schema change and needs the owner's approval before any
shared database sees it.** It was applied only to disposable copies in the cloud container (MySQL 8.0.46, `sql_mode=''`,
UTC), every one of them dropped.

**What it does — three statements on `seat_allocations`, nothing else:**

1. `status` gains the ENUM value `scheduled`, appended (INSTANT).
2. `effective_at DATETIME(6) NULL` is added (INSTANT).
3. `ck_seat_alloc_scheduled CHECK (status <> 'scheduled' OR (effective_at IS NOT NULL AND kind IN ('seat','store')))`
   is added. This one rebuilds the table (COPY) and blocks its writes while it copies: 0.06 s for 24 rows. Deploy with
   the API stopped, as always.

**A defect in the design, found by the rehearsal.** The design's CHECK also named `payment_id`. MySQL refuses it
(ERROR 3823): the column is written by `fk_seat_alloc_payment`'s `ON DELETE SET NULL`. The first apply stopped after
statements 1 and 2, because MySQL DDL is not transactional, and Prisma recorded 0097 as failed. The CHECK now holds
status, instant and kind. The payment link is held by the one code path that writes `scheduled`: one guarded UPDATE
with its read-back, in the payment's own transaction. A spec pins that path as the only writer. 0097 had been applied
nowhere else, so its file was amended rather than followed by a 0098.

**Recovering a half-applied 0097 (rehearsed).** With no row `scheduled`:

1. Drop `effective_at` and return `status` to its five values.
2. Run `npx prisma migrate resolve --rolled-back 0097_scheduled_addons`.

Every table and trigger then matched the 0096 backup, `seat_allocations`' definition included.

**The backup.**

- File: `addon_be_rh_src-before-0097-20261015T140353Z.sql` (`--single-transaction --routines --triggers --events
  --hex-blob`).
- Size: 402 685 bytes.
- SHA-256: `d832553cc8c532490b5a46258b5817b09963f42e6f5f0745bd769afdd3ec6002`.
- The trailer is present.
- **The restore was proven:** 113 tables (row counts and `CHECKSUM TABLE`) and 53 trigger bodies identical.

The dataset at 0096 held 24 `seat_allocations` rows, in every status and kind a row can hold today.

**The clean apply.**

- `prisma migrate deploy`, from the backup, took 1.44 s. The migration's checksum is `ee436397…8538052`.
- All 111 untouched tables are identical in rows and checksum, and so are the 53 triggers.
- `seat_allocations` holds the same 24 rows; a SHA-256 over its original columns is unchanged.

**The CHECK binds every account.** It refused the same three malformed writes as `root` and as `phonestore_app`
(ERROR 3819), and it accepted the well-formed one for both.

**The reverse SQL** is in the migration's header and is valid **only while no row is `scheduled`**.

- Proven on a throwaway copy: with a scheduled row present, returning the ENUM to five values silently empties that
  row's status (`Warning 1265`) under the server's empty `sql_mode`.
- With zero scheduled rows, the reverse returns every table and trigger to the 0096 backup.
- 0097 then re-applies identically.

**The API-rollback rule.** Roll the API back to a version before 0097 only while no row is `scheduled`. Otherwise roll
forward. An older API does not know the status.

**After the code was finished (2026-10-15/16)**, the env-gated `trial-addons.mysql.spec.ts` ran on fresh disposable
databases at 0097: 15/15 several times on `97b58ff`, then, after the verifiers' fix-ups added six cases, 21/21 three
times on `80c9133`. It covers the CHECK, the NOWAIT locks and the races. It is a manual pre-merge gate, skipped in CI by
design. An independent verifier re-ran the whole rehearsal on its own copies and found the same results.
