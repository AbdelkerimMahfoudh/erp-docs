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

⚠️ **The database is not covered by this.** These repositories hold code and
documentation only. All business data — sales, units, costs, audit trail —
exists solely in local MySQL until a dump is taken (§2).

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
# Adjust the database name to match DATABASE_URL in backend/.env
mysqldump --single-transaction --routines --triggers --events \
  phonestore > "$HOME/erp-backups/phonestore-$(date +%Y%m%d-%H%M%S).sql"
```

Why each flag matters:

| Flag | Reason |
|---|---|
| `--single-transaction` | Consistent snapshot on InnoDB **without locking tables** — the app keeps working during the dump |
| `--routines` | Stored procedures and functions |
| `--triggers` | **Essential here** — the append-only `audit_logs` protection is enforced by triggers (`prisma/sql/init/10_audit_append_only.sql`). A dump without them silently loses the audit guarantee |
| `--events` | Scheduled events, if any |

### Verify the dump before migrating

A dump you have not checked is not a backup.

```bash
ls -lh "$HOME/erp-backups/" | tail -1     # non-trivial size
tail -1 "$HOME/erp-backups/<file>.sql"    # must end: -- Dump completed
```

A truncated dump often ends mid-statement — the size and trailer check catches it in seconds.

### Restore

```bash
mysql phonestore < "$HOME/erp-backups/<file>.sql"
```

Restore into a **scratch database first** when practising, never straight over live data.

---

## 3. Migration sequence

1. Backup and **verify** the dump (§2).
2. Confirm the backend working tree is committed — `git -C backend status`.
3. Apply the migration.
4. Run the full test suite and typecheck.
5. Smoke-test the live app.
6. If anything fails: restore the dump **and** check out the previous commit. Both, in that order.

---

## 4. Known gaps

- **Database dumps are still local-only.** Code is now off-machine; data is not. A disk failure still loses every sale, unit and audit record. Dumps should be copied somewhere off this machine — but **never into these repositories**, which is why `*.sql.gz`, `*.dump` and `backups/` are ignored.
- **No dump has been taken yet.** The procedure in §2 is documented but unexercised.

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
