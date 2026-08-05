# CURRENT_HANDOFF

**Status:** `READY_FOR_HANDOFF`
**Owner of last session:** Claude Opus 5 (agent session)
**Date:** 2026-08-05
**Next phase:** F1 — Users, invitations and device security. Plan in
[`docs/23`](docs/23_USERS_AUTH_AUDIT_AND_PLAN.md). **Not started.**

> ℹ️ **This file did not exist before this session.** `CLAUDE.md` contains no
> handoff protocol and no `CURRENT_HANDOFF.md` / `SESSION_LOG.md` were present
> in any of the three repositories, so there was nothing to reconcile against.
> This is the first entry, and the format below is a proposal — change it freely.

---

## 1. Repository state

| Repo | Remote | Head | Tree |
|---|---|---|---|
| root (`docs/`, `CLAUDE.md`) | `erp-docs` | see §6 | clean, pushed |
| `backend/` | `erp-backend` | see §6 | clean, pushed |
| `mobile/` | `erp-mobile` | see §6 | clean, pushed |

All three are private, on `master`, and pushed.

## 2. Verified state

- Backend **28 suites / 235 tests** green.
- Backend `tsc --noEmit` clean · mobile `tsc --noEmit` clean · `expo lint` clean.
- Migrations through **`0019_settings_foundation`** applied to `phonestore`,
  and verified separately on a clean throwaway database.
- Live API verified for Settings: Owner read/write, employee read, 403 on
  employee writes, 409 on stale save, audit rows with old/new values.

## 3. Backup

- **Canonical dump command now includes `--hex-blob`** — see
  [`docs/22`](docs/22_BACKUP_AND_ROLLBACK.md) §2. It is not optional.
- Latest verified backup: `~/erp-backups/phonestore-20260805-203646.sql`
  (178 854 bytes, trailer present, 0 raw `_binary` literals, 1430 hex literals).
- Restore drill re-run end to end: 48/48 tables, 2/2 triggers byte-identical,
  `CHECKSUM TABLE` identical on all 48, audit triggers proven to still fire.
- ⚠️ Dumps remain **local only**. Code on GitHub is not a database backup.

## 4. Running the system

```bash
cd backend && npm run start:dev
```

API listens on **http://localhost:3010/api**, URI-versioned: real routes are
`/api/v1/...`; `/api/health` is version-neutral.

```bash
cd mobile && npm run web
```

Demo owner login is `owner`; the password is `OWNER_SEED_PASSWORD` in
`backend/.env`. Employee/manager test accounts are made with
`npx ts-node prisma/create-user.ts <login> <password> <role>`.

## 5. Open items the next session should know

1. **Animation behaviour cannot be verified in the automated browser pane.**
   `document.visibilityState === 'hidden'` there, so `requestAnimationFrame`
   delivers **zero frames** and every Reanimated animation sits frozen at its
   initial value. A previous session mistook this for a `BottomSheet` defect;
   the claim is withdrawn in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).
   **Verify sheets, toasts and dialogs on a device or in a visible browser.**
2. **Real-device RTL verification is still outstanding** for the Settings screen.
3. **Two approval gaps stay open by decision, not oversight:** `unit.transfer`
   guards all five transfer endpoints including completion, and
   `purchase.manage` creates a final purchase immediately. Address them when
   those workflows are built — not by widening permissions.
4. `import.run` still guards no endpoint.
5. `settings.discount_limits_by_role` still names retired roles. Nothing reads
   it; it belongs with discount monitoring.
6. `mobile` has **no test runner**. Adding one is a new dependency and needs
   approval per `CLAUDE.md`.
7. `User.pinHash` exists and is unused. [`docs/23`](docs/23_USERS_AUTH_AUDIT_AND_PLAN.md)
   §4.6 recommends **not** reusing it for the app passcode.

## 6. Commit identifiers at handoff

Run `git -C <repo> log --oneline -1` in each repo; the last entries of
[`SESSION_LOG.md`](SESSION_LOG.md) record the hashes for this session.

## 7. What must not happen without a fresh decision

- No schema change without a written reason and a migration (`CLAUDE.md`).
- No new dependency without approval.
- No WhatsApp/OTP provider integration guessed at — the provider is unchosen.
- No subscription or seat rules invented while building Users.
