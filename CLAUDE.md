# CLAUDE.md — Development Rulebook

This is the **permanent rulebook** for this project. Every contribution — human or AI — must obey it. When in doubt, this file wins over habit, convention, or convenience. If a request appears to break these rules, raise it before acting.

> Companion docs live in [`/docs`](docs). This file is the law; `/docs` is the detail.

---

## PROJECT IDENTITY
- This is an **Electronics Retail Management System** — a retail operating system for any electronics store that replaces the shopkeeper's notebook. *(Formerly scoped as a phone-store ERP; generalized to all electronics — see [`docs/18`](docs/18_ELECTRONICS_RETAIL_PIVOT.md).)*
- It handles **every product category and tracking type**: IMEI (phones/cellular), serial number (TVs, laptops, consoles, cameras, power stations, …), and barcode/quantity (accessories/bulk). Workflows adapt automatically to the tracking type.
- It is **not** a customer application. Customers never log in, install, or see it.
- It is **only** for internal staff:
  - **Owner**
  - **Managers**
  - **Employees**
  - **Warehouse staff**
- Its job: make running an electronics business faster than notebooks, easier than spreadsheets, with fewer mistakes.
- *(The repo folder is still named `PhoneStoreERP` for path stability — the product name is Electronics Retail Management System.)*

## CORE PRINCIPLES
Every feature, screen, and line of code is measured against these:
1. **Reduce typing.**
2. **Reduce mistakes** (prevent them, don't just record them).
3. **Be faster than a notebook.**
4. **Employees should learn it quickly** — productive on day one, no manual.
5. **Every action must provide value** — no feature or step ships without a stated reason.
6. **The app must feel alive and intelligent** — an assistant, not a ledger.

## DEVELOPMENT RULES
- **Prioritize automation** — the app should do the work, not the user.
- **Prefer scanning over typing.**
- **Prefer auto-fill over manual entry.**
- **Prefer simple workflows over complicated systems.**
- **Prefer smart defaults over forms.**
- **Do not add unnecessary features.** No speculative or "nice to have" code; every feature is justified.
- **Do not sacrifice simplicity for complexity.** The simplest solution that works, wins.
- **Never add features without explaining their value.**
- **Always consider non-technical employees** — they are the primary users.
- Do not invent requirements. If something is unspecified, ask or document the assumption.
- Reuse before rebuilding; match the style of surrounding code.

## UX RULES
- **Minimum taps** — the common path is the shortest path.
- **Modern, futuristic, but simple design** — glanceable and confident, never busy.
- **Clean interface** — generous space, one focal point per screen.
- **No traditional, complicated ERP feeling** — no dense grids of raw numbers, no accounting-software look.
- **Show advanced information only when requested** — progressive disclosure; detail is one tap away, never in the daily path.
- **Use clear information hierarchy** — numbers carry context (trends, comparisons), never bare figures.
- Camera-first, type-last. Big, thumb-reachable touch targets. Plain language, never codes or jargon.
- Status shown by color **and** words (never color alone).

## TECHNICAL RULES
- **Follow the documented architecture** in [`/docs/06_TECHNICAL_ARCHITECTURE.md`](docs/06_TECHNICAL_ARCHITECTURE.md).
- **Do not change the database structure without explaining why** — schema changes require a written reason and a migration. See [`/docs/07_DATABASE_REQUIREMENTS.md`](docs/07_DATABASE_REQUIREMENTS.md).
- **Write clean, production-quality code** — readable, consistent, no dead code, no commented-out blocks left behind.
- **Add tests for important functionality** — especially the sacred rules: IMEI uniqueness, sell-once, margin/cost, cash reconciliation, permissions.
- **Document major decisions** — significant choices get a short note (in the relevant doc or a decision log), so the "why" survives.
- **Enforce business rules and permissions on the server**, never trust the client. See [`/docs/04_BUSINESS_RULES.md`](docs/04_BUSINESS_RULES.md) and [`/docs/03_USER_ROLES.md`](docs/03_USER_ROLES.md).
- Nothing financial is hard-deleted — corrections are reversals with an audit trail.

## BEFORE EVERY MAJOR IMPLEMENTATION
Do all four, in order, and stop:
1. **Explain the plan.**
2. **Explain the files that will change.**
3. **Explain possible risks.**
4. **Wait for approval before large changes.**

"Major" = new feature, schema change, new dependency, architectural change, or anything touching the sacred rules. Small, obvious fixes within an approved plan don't need re-approval — but if unsure, treat it as major and ask.

---

## The single test for any change
> *"Does this make the shop faster, safer, or smarter — with less typing — while staying simple enough for a first-week employee?"*
> If not, it does not ship.

---

<!-- SHARED_HANDOFF_PROTOCOL_START -->

## Mandatory shared handoff protocol

Two Claude Code accounts (`CLAUDE-A` and `CLAUDE-B`) work **sequentially** on
this project. Only one may mutate the workspace at a time.

### Where the coordination files live

**This repository is the documentation repository** (`erp-docs`). The
coordination files are at its root, alongside this file:

```bash
cat CURRENT_HANDOFF.md
cat docs/21_PRODUCT_DECISIONS.md
```

The code repositories (`erp-backend`, `erp-mobile`) are nested here as
`backend/` and `mobile/`, excluded by this repository's `.gitignore`.

- `CURRENT_HANDOFF.md` — the current snapshot. Replace stale state; do not append.
- `SESSION_LOG.md` — append-only history. Never rewrite an earlier entry.
- `docs/21_PRODUCT_DECISIONS.md` — approved product decisions.
- `docs/22_BACKUP_AND_ROLLBACK.md` — mandatory before any schema migration.

If the directory layout ever differs, find the documentation repository by its
remote rather than by guessing a path:

```bash
git -C <candidate> remote get-url origin   # → .../erp-docs.git
```

### Before modifying code, schema, data, configuration or documentation

1. Locate and read the documentation repository's `CURRENT_HANDOFF.md` **and the
   most recent `SESSION_LOG.md` entries**.
2. Read the relevant sections of `21_PRODUCT_DECISIONS.md`.
3. Inspect Git status and recent commits in all affected repositories.
4. Compare the handoff's recorded commit IDs with actual local **and** remote state.
5. Check Prisma migration status before database-related work.
6. Resolve discrepancies before implementation.

**The latest explicit user instruction and the approved product decisions
control intended behaviour. Git, database state and test results control
factual implementation state.** If the handoff disagrees with the repository or
the database, stop, investigate, and correct the handoff rather than guessing.

### Session ownership

If `CURRENT_HANDOFF.md` says `IN_PROGRESS` under the other account, **do not
mutate anything** unless the user explicitly states that account reached its
limit or authorises takeover. On an authorised takeover, record the previous
account, the takeover time, and whether its last handoff was complete or
interrupted — then inspect every dirty file before continuing.

**Take ownership only when `Status` is `READY_FOR_HANDOFF`** (or on an explicit,
user-authorised takeover). Never run both accounts concurrently against the same
working tree or database.

### At the start of an authorised implementation session

Update `CURRENT_HANDOFF.md` **before** changing anything, recording all of:

- `Status: IN_PROGRESS`
- `Owner:` the active account label (`CLAUDE-A` or `CLAUDE-B`)
- `started_at_utc:` the takeover time in UTC
- the **exact HEAD commit of all three repositories** at takeover
- the **active phase and scope** of the authorised task
- the next intended action

Refresh it at every meaningful checkpoint — especially after a migration, a
commit or a completed subphase. Do not wait until context is nearly exhausted.

### Before yielding to the other account

1. Stop at the safest coherent point possible.
2. Run all relevant verification that time allows.
3. Commit and push only coherent changes.
4. Never hide failing or uncommitted work.
5. Update `CURRENT_HANDOFF.md`, recording: files and migrations changed; tests
   and live verification; commits pushed per repository; known risks and
   blockers; and the precise next task.
6. Append a session entry to `SESSION_LOG.md` (append-only — never rewrite an
   earlier entry). Update `21_PRODUCT_DECISIONS.md` and operational docs
   whenever behaviour changed.
7. Set `READY_FOR_HANDOFF` **only after all three working trees are clean and
   pushed**; otherwise set `BLOCKED` with the exact blocker.
8. Record the next exact action, precisely enough that the other account does
   not have to guess.

If work is incomplete when the limit approaches, **leave it uncommitted rather
than making a misleading "finished" commit** — and record every changed file
and the current failure.

### Git rules

- Focused commits. Backend, mobile and documentation are **separate
  repositories** and are committed independently.
- Record cross-repository commit IDs in `CURRENT_HANDOFF.md`.
- Update the documentation repository **last**, so its handoff records the
  final backend and mobile commit IDs.
- Push green checkpoints before switching accounts.
- Never force-push, rewrite shared history, or amend a commit the other account
  has already used.
- Never commit environment files, database dumps, dependencies or secrets.
- **Scratch and tooling files MUST live in an OS temporary directory, never
  inside any repository working tree** — not in `public/`, not in a `tmp/`
  folder, nowhere a `git add -A` can reach. This includes anything holding a
  token, a session, a credential or a database extract, however short-lived.
  *(G2A-CP4.5: a file of ephemeral session tokens was written to
  `mobile/public/` so a browser could pick it up, and `git add -A` committed it.
  The tokens were revoked and verified dead, but the only reliable defence is
  that the file never exists inside a repository.)*
- If a secret does reach a commit, **invalidate the credential first** — revoke
  the session, rotate the key — and record it in `SESSION_LOG.md`. Do **not**
  force-push to erase it: rewriting shared history is still forbidden, and a
  revoked credential is already worthless.

### Database rules

The database is **shared mutable state**. Before any Prisma schema migration:

1. Inspect migration status.
2. Take a fresh verified backup per `22_BACKUP_AND_ROLLBACK.md`.
3. Record the backup identifier in the handoff.
4. Record any temporary database, and drop it after verification.
5. Record the migration in the handoff immediately after applying it.

Never run `prisma migrate reset` on the shared database. Never delete demo
records without explicit authorisation. **A Git rollback does not roll back the
database** — restoring the dump is a separate, deliberate step.

### Never

Destructive Git commands · force-push · rewriting shared history · resetting
the database · deleting the other account's work · storing secrets in the
handoff files.

<!-- SHARED_HANDOFF_PROTOCOL_END -->
