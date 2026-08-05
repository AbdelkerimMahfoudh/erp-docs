# SESSION_LOG

**Append-only. Newest entry at the top.** One entry per meaningful work session.

Never rewrite or delete an earlier entry. The single exception is correcting an
objective factual error, which must be marked inline as **CORRECTION** with the
date and the account that made it — never by silently editing the original text.

Do not paste large diffs, complete logs, secret values or customer data here.

> This file was created on 2026-08-05. Work before that date is recorded in
> `docs/21` and `docs/22` rather than here. The entry dated 2026-08-05 below
> the bootstrap uses an earlier ad-hoc format; it is kept verbatim as valid
> history. Entries from the bootstrap onward use the shared protocol format.

---

## 2026-08-05 21:05 — CLAUDE-A

- **Starting state:** All three repositories clean, on `master`, level with
  their remotes: backend `0940b41`, mobile `d9edbed`, documentation `641b787`.
  No uncommitted or untracked files anywhere. No temporary databases.
- **Authorised task:** Bootstrap a durable two-account handoff protocol.
  Coordination files and Git commits only — explicitly **no product feature
  work**.
- **Work completed:**
  - Discovered the three repositories and their remotes; identified the
    documentation repository as the **workspace root** (`erp-docs`), with
    `backend/` and `mobile/` nested inside its working tree but excluded by its
    `.gitignore` and tracked as separate repositories.
  - Verified the baseline from evidence rather than from the prior report:
    tests, both typechecks, lint, migration status, role and permission counts,
    demo-data counts, temporary databases, backups.
  - Rewrote `CURRENT_HANDOFF.md` into the shared protocol structure, preserving
    the valid content of the previous version.
  - Added the marker-enclosed shared protocol section to `CLAUDE.md` in all
    three repositories. `backend/CLAUDE.md` and `mobile/CLAUDE.md` did not
    exist and were created; the root `CLAUDE.md` was extended, not overwritten.
  - Recorded six corrections where reported state differed from actual state
    (appendix of `CURRENT_HANDOFF.md`).
- **Decisions made by the user:** Account label for this workspace is
  `CLAUDE-A`. The other account may continue at the five-hour usage limit.
  Bootstrap authorises coordination files and commits only.
- **Files changed:** `CURRENT_HANDOFF.md`, `SESSION_LOG.md`, `CLAUDE.md`
  (documentation repo); `CLAUDE.md` (backend, new); `CLAUDE.md` (mobile, new).
  No source file, schema file or migration was touched.
- **Database migrations:** None applied. Status inspected only:
  `prisma migrate status` → *"Database schema is up to date!"*, 18 migrations,
  latest `0019_settings_foundation`.
- **Tests and results:** Backend `npx jest` → **28 suites / 235 tests passing**.
  Backend `tsc --noEmit` clean. Mobile `tsc --noEmit` clean. `expo lint` clean.
- **Live verification:** None performed in this session — no behaviour changed.
  The Settings API and screen verification from earlier on 2026-08-05 still
  stands and is recorded in `CURRENT_HANDOFF.md`.
- **Commits:** backend **`ea22df1`** · mobile **`2d6f49b`** · documentation:
  *current HEAD contains this handoff* (see the note below).
- **Push status:** All three pushed to `origin/master`; all three level with
  their remotes afterwards.
- **Remaining work:** None for this task. No feature work was started, by
  instruction.
- **Handoff reason:** Bootstrap complete. Status set to `READY_FOR_HANDOFF`,
  active account `NONE`, awaiting an explicit user instruction.

*Note on the documentation commit hash: a file cannot contain the id of the
commit that introduces it, and adding a follow-up commit merely to record the
previous one creates an endless self-referential chain. The documentation
repository therefore records **"current HEAD contains this handoff"**; the
authoritative value is always `git -C <docs repo> log --oneline -1`. Backend
and mobile hashes are recorded exactly because they are committed first.*

---

## 2026-08-05 — E.1 backup hardening · E.2 withdrawn · F0 audit
**Owner:** Claude Opus 5 (agent session)
**Heads:** docs `307c453`, `125b798`, `fcb6e93`, + this entry · backend `0940b41` · mobile `d9edbed` (unchanged — E.2 shipped no code)

### E.1 — `--hex-blob` is now mandatory

The canonical `mysqldump` command gained `--hex-blob`, keeping
`--single-transaction --routines --triggers --events --no-tablespaces`.

Every id in this database is a `BINARY(16)` UUIDv7. Without the flag those are
written as raw bytes and **the dump file is not valid UTF-8**, so any ordinary
text tool that touches it silently replaces every primary key with `U+FFFD` —
the restore then succeeds and the damage only appears later as rows that no
longer join.

Proven on `phonestore-20260805-203646.sql` (178 854 bytes):

- 0 raw `_binary` literals, 1430 `0x…` literals, whole file survives a UTF-8
  round trip (the previous dump did not).
- Original still fails for the migrator with `ERROR 1227` — the DEFINER problem
  is untouched by `--hex-blob`, which is why the sanitiser still runs.
- Sanitised copy restored as the least-privileged migrator: **48/48 tables,
  2/2 triggers byte-identical, 12 representative row counts equal, `HEX(id)`
  checksums equal, `CHECKSUM TABLE` equal across all 48 tables**, Arabic text
  and en-dashes intact.
- Audit protection still executes: `UPDATE`/`DELETE` on `audit_logs` as
  `phonestore_app` both rejected with `ERROR 1644 (45000)`; 77 rows before and
  after.
- Temp database dropped, sanitised copy deleted, original never modified.

Sanitiser kept on `latin1` deliberately: legacy dumps still need byte-exact
handling, and `DEFINER=` can legitimately appear inside row data. Four new
tests cover the hex shape; 13 total, all green.

### E.2 — withdrawn: there was no BottomSheet bug

The previous session reported that `BottomSheet` never animates in on Expo web,
sitting at `translateY(720)` with the backdrop at `opacity: 0`.

**That was a measurement artifact.** In the automated browser pane
`document.visibilityState === 'hidden'` and a `requestAnimationFrame` loop
delivers **0 frames**. Reanimated drives web animations from rAF, so every
animation in the app is frozen at its initial value there — and those initial
values are exactly `screenHeight` and `0`, the two numbers reported as the bug.

An intermediate reading that appeared to show a fix was also unsound: the DOM
selector was matching an unrelated element.

**No change was shipped.** Speculative edits were reverted: the sheet is the
surface every picker, scanner and confirmation sits on, nothing was proven
broken, and there is no device or emulator here to check native behaviour
against. The false claim was removed from `docs/21`.

*Lesson worth keeping: before diagnosing an animation, confirm the page is
animating at all.*

### F0 — Users / auth / device-security audit (read-only)

No schema, API or screen touched. Written up in
[`docs/23`](docs/23_USERS_AUTH_AUDIT_AND_PLAN.md) with a dependency-ordered F1
plan in eight stages.

Headline findings:

- **Reusable and better than expected:** Argon2id throughout, rotating refresh
  tokens *with reuse detection that revokes the session*, per-device
  `auth_sessions`, permissions resolved from the database on every request (no
  roles in the JWT), and multi-branch membership with a role per branch.
- **`User` has no phone, no email and no verification state** — the OTP and
  recovery rules have nothing to attach to yet.
- **No per-user permission grant exists**, so "per-user price editing is
  Owner-delegated" is currently impossible to express.
- **`deviceId` is client-supplied, optional and never verified**, and the mobile
  client never sends it — so "new device" is not detectable today.
- **No OTP, invitation, passcode, biometric or recovery code exists at all.**
- **`login`/`logout` audit actions exist in the enum and are never written.**
- Rate limiting is per-IP only; there is no per-account lockout.
- The company auto-lock maximum **is** done (0019) and needs no rework.

### Documentation

- `docs/22` — `--hex-blob` section, revised sanitiser rationale, new drill record.
- `docs/21` — BottomSheet claim withdrawn with the evidence.
- `docs/23` — new: F0 audit + F1 plan.
- `CURRENT_HANDOFF.md`, `SESSION_LOG.md` — new; neither existed, and `CLAUDE.md`
  defines no handoff protocol.
