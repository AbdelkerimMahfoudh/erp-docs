# D227 deployment plan, for review (deployment ON HOLD)

Nothing in this file has run. Each numbered step needs the owner's go at the time. Production today: API `fbe4778`,
migrations to `0115`, no admin hostname, the customers' portal not live. Detail of the admin hostname: console
`notes/admin-console-activation.md`. Release evidence: `docs/113` §15-§23. Device checks: `docs/115`.

## 0. What is released

| Part | Commit | Notes |
|---|---|---|
| API | backend `post-testflight-feedback` head at release (`docs/113` §23) | Migrations 0116-0127. Includes the sale-name hotfix `fbe4778` and the admin origin rule (`145c56c`). |
| Admin console | console `post-testflight-feedback` head, built on CI as the `admin` surface | Served at `https://admin.tsxmr.com` (new). |
| Preview `dukan-test` | the same console commit, `preview` surface | Its `/admin` stops working at step 9. Its portal pages stay. |
| iOS | Build 4 (`1.0.0 (4)`), from the mobile release head | TestFlight internal first (`docs/115` Pass 2). No external testers. |
| **Not released** | Sentry (deferred to the next build, owner 2026-11-03); the customers' portal at `dukan.tsxmr.com` (deferred) | — |

## 1. Preconditions, all recorded before step 1

1. Every head green on CI, render and visual (`docs/113` §23).
2. **The production-schema rehearsal:** `docs/113` §18, a real `schema-for-rehearsal.sh` fetch, then `rehearse-migrations.sh` with `PROD_SCHEMA`, PASS. A production-format dump made locally does not count.
3. `docs/115` Pass 1 done and recorded, with every ❌ fixed or accepted by the owner.
4. The owner's go for the deployment window: a quiet hour, with no sale expected.
5. The owner at the laptop: ssh-agent started and the key added by the owner (`docs/113` §18). Laptop public IP inside firewall rule 4.

## 2. Backup, off-host copy and restore proof (before anything changes)

1. `deploy/production/backup-offhost.sh tsxmr-app-01 <laptop folder>`. It makes a fresh age-encrypted backup on the host, copies it to the laptop and compares both SHA-256 sums. Its receipt is what `deploy.sh` requires.
2. **Restore proof from that copy:** `deploy/production/restore-drill.sh --offsite laptop <file>`.
   - The owner supplies the backup identity v2 (`production-backup-identity-v2.txt`) to memory only, on the same SSH session, by the established clipboard pipe. The identity is never in chat.
   - The drill restores into `phonestore_drill_<stamp>` and compares tables, triggers, row counts, key digests, money sums and every `CHECKSUM`. It then drops the copy.
3. Record in the handoff: the backup's name, size and sha256 (host and laptop), and the drill's verdict line.

**Stop here if any of it is not exact.**

## 3. The API (migrations 0116-0127)

1. On the host, check out the release commit. Then `deploy/production/deploy.sh --confirm api.tsxmr.com`. It:
   - refuses an uncommitted tree;
   - builds images tagged with the commit;
   - runs preflight, then its own pre-migration backup, then `migrate deploy` as the migrator;
   - runs the catalogue, the identities and the audit chain;
   - replaces the API and waits for readiness;
   - runs the smoke test.
2. **Configuration in the same step** (fingerprints of `api.env` and `stack.env` recorded before and after):
   - `CORS_ORIGINS` gains `https://admin.tsxmr.com`;
   - `ADMIN_ORIGINS=https://admin.tsxmr.com,https://dukan-test.tsxmr.com` (**transition only**);
   - `stack.env`: `ADMIN_CONSOLE_HOST=admin.tsxmr.com`.

   The production guard refuses an `ADMIN_ORIGINS` entry that CORS does not allow, and the customers' portal.
3. **Checks:**
   - 127/127 migrations;
   - the audit chain unbroken;
   - smoke all green;
   - WhatsApp still cloud/live/enabled with limit 200, email disabled, push unset, the off-site timer active;
   - a sale on the Test business only.

## 4. Origin rule rollout and the admin hostname

Each step is the owner's go. They follow the activation note, steps 3-10.

1. **DNS (Cloudflare, the owner):** `A admin` → the API's IPv4, DNS only, no AAAA. Confirmed from 1.1.1.1 and 8.8.8.8.
2. **Build on CI's Linux runner** from the released console commit, `VITE_SITE_SURFACE=admin`, then `audit-bundle.mjs --admin`. `admin-release.txt` must name the released commit.
3. **Install:** `deploy/production/admin-site.sh install <release> --confirm api.tsxmr.com`. It requires:
   - `/admin` 200 and noindex;
   - `/subscription` 404;
   - CORS granted to the admin origin;
   - 401 with no session;
   - 403 from the customers' portal's origin.
4. **By hand, the owner's browser, the existing administrator only:**
   - sign-in, second factor, step-up and sign-out, in EN, FR and AR;
   - the cookie is host-only on `api.tsxmr.com`, HttpOnly, Secure, SameSite=Lax;
   - a payment proof's file opens.
5. **Remove the temporary dukan-test origin**, only after step 4 passed:
   - set `ADMIN_ORIGINS=https://admin.tsxmr.com` and recreate the API;
   - check `platform/admin/me`: 403 from `https://dukan-test.tsxmr.com`, 401 from `https://admin.tsxmr.com`;
   - check the preview's `/subscription` still works;
   - `dukan-test` stays in `CORS_ORIGINS`, for its portal pages.
6. Update the preview `dukan-test` to the released console commit (`test-sites.sh`, as before).

## 5. The phone

1. The owner starts the EAS build of Build 4 from the mobile release head. EAS credentials stay the owner's.
2. TestFlight internal only. Then `docs/115` Pass 2 on the Test business: Arabic layout, Security with real codes to the owner's own number, the basket and the small iPhone.
3. External testers and App Store submission are separate decisions, not part of this plan.

## 6. Rollback, narrowest first

**The database is never rolled back by a code rollback.** The D227 schema is additive, but two migrations set floors
for the old code (`fbe4778`):
- **0118:** `companies.name` becomes nullable. `fbe4778` reads it as never null, so any business created without a name after the release makes the old code fail on it.
- **0125:** `otp_challenges.purpose` gains `credential_change`. `fbe4778` cannot read such a row, so once anyone has started a Security change, the old code fails on that person's code lookups.

So `rollback.sh erp-api:fbe4778…` is safe only while both checks read 0:
```
SELECT COUNT(*) FROM companies WHERE name IS NULL;
SELECT COUNT(*) FROM otp_challenges WHERE purpose = 'credential_change';
```
Run them read-only on the host before choosing. The script gains these two refusals, as it has for 0107, before the
release (a small backend change, listed in §8).

| What went wrong | Do | Data |
|---|---|---|
| The admin console release is bad | `admin-site.sh rollback <previous> --confirm api.tsxmr.com`, or `off` | none |
| The origin rule locks the console out | correct `ADMIN_ORIGINS` and recreate the API; emptying it stops enforcement | none |
| DNS | delete the `admin` record | none |
| The API is bad and both floor checks read 0 | `rollback.sh erp-api:fbe4778… --confirm api.tsxmr.com`; schema stays at 0127 | none lost |
| The API is bad after a floor was crossed | **roll a fix forward** (preferred); or restore the step-2 backup into a NEW schema (`restore-drill.sh` with `KEEP_DRILL=1`, docs/100 §11), point `fbe4778` at it, and accept losing every write since the backup | writes since the backup |
| A migration failed half-way | `deploy.inprogress` stops the next run. docs/79 §C2. The pre-migration backup from `migrate.sh` is the restore point | per docs/79 |

## 7. Afterwards

- Record in the handoff: commits, image tags, release names, fingerprints, results.
- The owner runs `ssh-add -D` and `Stop-Service ssh-agent`.
- Before the App Store release: SSH moves to a private network (Tailscale) and port 22 closes to the internet (owner's plan of 2026-10-27).
- The next build: Sentry, disabled until the DSN and EAS token are verified.

## 8. Still to do before this plan can run

1. `rollback.sh`: refuse `fbe4778` and older once either D227 floor is crossed (§6), with a spec, as for 0107.
2. The production-schema rehearsal (§1.2).
3. `docs/115` Pass 1 (§1.3).
4. The owner's go on this plan.
