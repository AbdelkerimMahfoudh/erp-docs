# 112 — Off-site backups to the Hetzner Storage Box: the plan, for the owner's approval

**Status:** proposed on 2026-10-30. **Nothing in this document has been run.** The production server was only
inspected, read-only. Implementation starts on the owner's explicit approval, step by step.

## 1. What exists

| Item | Fact (read-only audit, 2026-10-30) |
| --- | --- |
| Storage Box | `dukan-erp-backups`, ID 687676, BX11 (1 TB), Falkenstein. Host `u705821.your-storagebox.de`, main user `u705821`, SSH on port 23. SMB, WebDAV and external reachability off. Already purchased. |
| Its host key | ED25519 `SHA256:XqONwb1S0zuj5A1CDxpOSuD2hnAArV1A3wKY7Z3sdgM`. Compare it with the fingerprint Hetzner publishes before it is trusted. |
| Reachability | port 23 open from tsxmr-app-01 (TCP only, no login tried) |
| Server | Ubuntu 24.04.5; disk 37 % used; 2.3 GB memory available; ufw inactive (the Hetzner firewall filters inbound only) |
| Borg | not installed; Ubuntu's `borgbackup` 1.2.8 is available |
| Schedules | none: no cron entry, and no backup timer |
| Today's backups | `deploy/production/backup.sh` writes age-encrypted dumps (`phonestore-*.sql.gz.age`, 7 on the host, 508 KB) on deployments and on demand. They are copied by hand to the owner's laptop. |

**Persistent state to protect:**

| What | Where | Size | In the backup? |
| --- | --- | --- | --- |
| The database | volume `erp-production_db-data` | 241 MB | **as a consistent logical dump** (`backup.sh`, already age-encrypted), never the raw files |
| Uploads (receipt pictures) | volume `erp-production_uploads` | 4 KB today | yes |
| Configuration | `/srv/erp-production/api.env` (+ its `.pre-*` copies), `erp-backend/deploy/production/stack.env` | KB | yes |
| Secrets | `/srv/erp-production/secrets/` (21 files) | 92 KB | yes, encrypted twice (inside the Borg archive) — see §3 |
| Deployment record | `backups/deployments.log`, `current-images.env`, `offsite-restore-proof` | KB | yes |
| Test-site releases | `/srv/erp-production/web` | 23 MB | yes (they are reproducible from CI, but restoring is faster) |
| TLS certificates | volume `erp-production_caddy-data` | 144 KB | yes (they can be re-issued, but restoring avoids rate limits) |
| Code and images | the checkout, Docker images | — | **no**: rebuilt from the recorded commit (`current-images.env`, `deployments.log`) |

## 2. Accounts and keys (no reuse of the production administrator key)

1. **A Storage Box sub-account for the server**, e.g. `u705821-sub1`. **The owner creates it** in the Hetzner Console
   (Storage Box → Sub-accounts), or I do it through the owner's Chrome on approval:
   - base directory `/erp-production`, SSH on, everything else off;
   - its own random password, typed once by the owner to install the key, then unused.
2. **A dedicated backup SSH key on the server:** `/root/.ssh/storagebox-backup`, ed25519, no passphrase (a nightly
   job), readable by root only. It is installed on the sub-account with Hetzner's `install-ssh-key` command. It is
   never the `tsxmr-production-admin` key.
3. **The main user `u705821` stays the owner's.** It is used for pruning and maintenance from the owner's own laptop
   only (§5), never by the server.

## 3. Borg: encryption and independent recovery material

- **Repository:** `ssh://u705821-sub1@u705821.your-storagebox.de:23/./borg`. Storage Boxes run `borg serve`
  server-side.
- **Encryption:** `borg init --encryption=keyfile-blake2`. The key file lives on the server
  (`/root/.config/borg/keys/`), and the box never holds it. The passphrase is generated on the server and stored in
  `/srv/erp-production/secrets/borg_passphrase` (mode 600). Neither is ever printed.
- **The owner's independent recovery material:**
  - `borg key export --paper` goes to the owner's terminal through an `ssh -t` script, for the password manager;
  - the passphrase, through the same hidden channel.
  - Without both, an off-site copy is useless if the server is lost. The age identity (v2) stays separate and is
    still needed to open the database dumps inside the archive.
- **Authenticated:** Borg authenticates every chunk (BLAKE2b MAC). A changed byte fails `borg check` and extraction.

## 4. The nightly job

`deploy/production/offsite-backup.sh`, a new script that is reviewed, tested in CI and committed like the others:
1. `take_lock`: the same `flock` as deploy and backup, so it never overlaps a deployment.
2. `backup.sh`: a fresh consistent dump, age-encrypted, with its checksum.
3. `borg create --compression zstd,6 ::'{hostname}-{utcnow:%Y%m%dT%H%M%SZ}'` of the paths in §1, the newest dump among
   them.
4. `borg check --archives-only --last 1`.
5. On success: `backups/offsite-latest` (archive name, time, size). On any failure: a non-zero exit, the journal, and
   the alert (§6).

**Schedule:** a systemd timer `erp-offsite-backup.timer`, daily at **02:30 UTC** with `RandomizedDelaySec=10min` and
`Persistent=true` (a missed run catches up at the next boot).

## 5. Retention, and separating pruning from routine access

- **Proposed retention:** `--keep-daily 7 --keep-weekly 4 --keep-monthly 6`, then `borg compact`.
- **Routine access** (the server's key) creates archives.
- **Pruning** is meant for a separate credential: the main user, run from the owner's laptop, about monthly, by a
  script with `--dry-run` first.
- **Limit to verify before relying on it:** whether a Storage Box enforces an append-only or forced-command restriction
  on a key. If it does not, the server's key could technically delete archives. The mitigation is §5.1.

### 5.1 Storage Box snapshots: extra protection, not a backup

- Enable automatic snapshots on the box (Hetzner Console), e.g. daily, keeping 10.
- A snapshot protects against deletion or encryption of the repository by a compromised server. It does not replace
  the Borg archives or the restore test.

## 6. Alerts, and the latest success

- **On the server:** `systemctl status erp-offsite-backup` and `backups/offsite-latest`. The production smoke and
  inspection scripts warn when the latest success is more than 36 hours old.
- **Outside the server: one choice for the owner.**
  - **(a) A dead-man's switch:** healthchecks.io on its free tier, which alerts the owner's email when the nightly
    ping does not arrive. The job sends only a success or failure ping, no data.
  - **(b) Nothing external for now:** a stale backup is noticed only at the next manual inspection.
- Email from the API stays disabled. The alert does not use the product's messaging.

## 7. The isolated restore: the proof the WhatsApp gate requires

A successful upload proves nothing about recovery. The gate (`preflight.mjs`) opens only on
`offsite-restore-proof` `kind=storage-box`, which `restore-drill.sh --offsite storage-box` writes after an actual
restoration.

1. **Where:** the existing **rehearsal profile** on the same host (§9 of docs/100).
   - It is a separate project, `erp-rehearsal`, with its own volumes, secrets and loopback-only edge;
   - it uses no production database, volume or service;
   - it costs nothing.
   - **Alternative:** a temporary Hetzner VM (CX22, a few euro-cents for the hour). It is only created on the owner's
     approval.
2. **Pull from the box:** `borg extract` the latest archive into `/srv/erp-rehearsal/restore-in`, then
   `borg check --verify-data` of that archive.
3. **Database:** `restore-drill.sh --identity /dev/shm/… --offsite storage-box`, with the dump taken from the archive.
   - It is restored into a throw-away schema: tables, triggers and every CHECKSUM compared, then dropped.
   - The v2 identity is brought in for the session only.
4. **Application start, isolated:** the rehearsal stack on the restored data, with:
   - `EMAIL_CHANNEL=disabled`, `WHATSAPP_CHANNEL=disabled`, `PUSH_CHANNEL` unset;
   - the workers off and no outbound target configured;
   - `CORS_ORIGINS` local only, and the edge on 127.0.0.1.

   Then the read-only smoke checks.
5. **Evidence:**
   - archive name, size and duration;
   - extract time, `borg check` result, drill result;
   - smoke result, and the total time to recover.

   Recorded in docs/100 and the session log.
6. **Teardown:** `teardown-rehearsal.sh`, proven clean as on 2026-10-18.
7. **`RESTORE.md`** (secret-free): the exact recovery procedure for a new server. It lives in the repository and is
   also stored by the owner offline.

## 8. Costs

- The Storage Box BX11 is already paid: no new cost. Snapshots use its 1 TB.
- Option (a) healthchecks.io free tier: no cost.
- No VM unless approved.

## 9. Rollback

- Disable the timer (`systemctl disable --now erp-offsite-backup.timer`), and delete the backup key and the
  sub-account.
- Nothing in the production data path changes. `backup.sh` and the laptop copies keep working as now.

## 10. Order of work, each step on approval

1. The owner creates the sub-account (§2.1) and confirms the host-key fingerprint against Hetzner's published value.
2. On the server: install Borg; create the key and install it on the sub-account; `borg init`. The owner exports the
   recovery material (§3).
3. Commit `offsite-backup.sh`, the systemd units and their tests (CI). Bring them to the server; one manual run; then
   the timer.
4. The isolated restore (§7) and `RESTORE.md`. Only then may the WhatsApp gate open, and only on the owner's separate
   authorisation.
