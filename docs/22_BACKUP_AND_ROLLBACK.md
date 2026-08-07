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
mysql --defaults-extra-file="<dba option file>" phonestore < "$HOME/erp-backups/<file>.sql"
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
mysql --defaults-extra-file="$HOME/.my.cnf" phonestore < "$HOME/erp-backups/<file>.no-definer.sql"
```

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
