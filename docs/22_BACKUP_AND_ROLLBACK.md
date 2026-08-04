# 22 — Backup & Rollback Procedure

> **Mandatory before every Prisma schema migration.** Code rollback does not undo a migration: reverting `schema.prisma` leaves the database already altered, and a partially-applied migration can leave it in a state no commit describes.
>
> Two independent protections are needed, because they fail differently:
> **code** (git) and **data** (a dump).

---

## 1. Code rollback

| Repository | State |
|---|---|
| `backend/` | Local git, baseline commit `f941a21` (179 files) |
| `mobile/` | Local git, 3 commits, 119 tracked files |
| repo root | Not a repository — `docs/` is currently **unprotected** |

Neither has a remote. Both are local-only, so a disk failure loses everything — see §4.

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

- **No off-machine copy.** Both repositories and all dumps are local. A disk failure loses the project. A remote (even a private one) is the obvious next step — deliberately not created, since remotes are not authorised.
- **`docs/` is unversioned.** The repo root is not a git repository, so `docs/21` and this file have no history.
- **`backend/.env.example` currently holds the real credentials** from `.env` and is therefore excluded from git. It must be sanitised to placeholders before it can be tracked. See §1 of `docs/21`.
