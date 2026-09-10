# 43 — Merge order and rollback plan

**Nothing in this document has been executed.** It is the plan for when device
acceptance passes. No branch was merged, rebased, force-pushed or deleted.

Verified **2026-09-10** against the repositories.

---

## 1. Topology

Four repositories, three remotes under `AbdelkerimMahfoudh`, all clean and level
with their upstreams.

| Repository | Branch | HEAD | Upstream | Dirty |
|---|---|---|---|---|
| `erp-docs` | `master` | `37f381a`→ this commit | level | 0 |
| `erp-backend` | `master` | `67352af` | level | 0 |
| `erp-backend` | **`reports-export`** | **`6bb0d53`** | level | 0 |
| `erp-mobile` | `master` | `f47a155` | level | 0 |
| `erp-mobile` | `sdk-57-upgrade` | `c2422c6` | level | 0 |
| `erp-mobile` | **`reports-export`** | **`ed7d614`** | level | 0 |
| `retail-erp-control-web` | `master` | `c764d63` | level | 0 |

### Commits unique to each feature branch

**`erp-backend` `reports-export` — 3 ahead of `master`:**

```
6bb0d53  fix(config): refuse to start production with unsafe defaults
51c93ad  fix(cors): let a browser read the report filename
b0f3fc5  feat(reports): the six reports, as spreadsheets
```

**`erp-mobile` `sdk-57-upgrade` — 16 ahead of `master`.** The indigo redesign,
the scanner contract, and the Expo 57.0.21 bump.

**`erp-mobile` `reports-export` — 1 ahead of `sdk-57-upgrade`:**

```
ed7d614  feat(reports): export what you are looking at
```

**`reports-export` is stacked on `sdk-57-upgrade`, not on `master`.** That is the
single most important fact here: merging the export without the redesign
underneath is not possible, and not meaningful — the export's UI is built from
the redesign's components.

---

## 2. Dependency order

```
erp-mobile/master
      └── sdk-57-upgrade   (16 commits: redesign, scanner, SDK bump)
              └── reports-export  (1 commit: the Export action)

erp-backend/master
      └── reports-export   (3 commits: the endpoint, CORS, the prod guard)
```

**The backend must go first.** `ed7d614` calls `GET /reports/:kind.csv`; shipping
the app against a server that has never heard of it gives every user an error on
a button that looks like it should work.

Merge order:

1. `erp-backend` `reports-export` → `master`
2. `erp-mobile` `sdk-57-upgrade` → `master`
3. `erp-mobile` `reports-export` → `master`

Steps 2 and 3 can be one merge of `reports-export`, since it already contains
`sdk-57-upgrade`. Keeping them separate buys one thing: a rollback point between
"the redesign shipped" and "the export shipped".

---

## 3. Conflict assessment

Checked with `git merge-tree` against the real merge bases. **Zero conflict
markers in either repository.**

Overlapping files between the two mobile branches — the places a future change
would collide, worth knowing even though today they merge clean:

| File | Why both branches touch it |
|---|---|
| `app/analytics.tsx` | The redesign restyled it; the export added a header action |
| `lib/i18n/en.ts` · `fr.ts` · `ar.ts` | Both added keys. **Any i18n conflict must be resolved by keeping both sets and re-checking parity** — 1860 keys, identical order, in all three files |

The backend branch touches `main.ts`, `app.module.ts`, `auth.controller.ts` and
`analytics/`, none of which `master` has moved since the branch point.

**Merge, do not rebase.** These branches are pushed and another account may have
fetched them; the rulebook forbids rewriting shared history, and a rebase would
invalidate every commit id recorded in the handoff and the session log.

---

## 4. Rollback points

Tags are the recovery points. All are pushed.

| Tag | Repository | Commit | Rolls back to |
|---|---|---|---|
| `pre-reports` | `erp-backend` | `67352af` | Before the export endpoint |
| `pre-reports` | `erp-mobile` | `c2422c6` | Before the Export action |
| `pre-scan-contract` | `erp-backend` | `0ec9d4b` | Before the duplicate-scan contract |
| `pre-scan-contract` | `erp-mobile` | `337719f` | Before the scanner result changes |
| `pre-redesign-part2` | `erp-mobile` | `7d7a7ce` | Before the final redesign pass |
| `pre-redesign-completion` | `erp-mobile` | `ca8525d` | |
| `pre-indigo-refresh` | `erp-mobile` | `3622280` | Before any of the indigo work |

### What a code rollback does not undo

**A Git rollback does not roll back the database.** Restoring a dump is a
separate, deliberate step — `docs/22` §3.

For this particular set of branches that is unusually benign: **no migration is
involved.** The export added no table, column, index or enum value; migration
count is 63 before and after. So a rollback to `pre-reports` needs no database
action at all.

The audit rows the export wrote (`entityType: 'report_export'`) survive a
rollback and should. They are true statements about exports that happened, and
nothing financial is hard-deleted in this project.

### Rolling back the production-config guard

`6bb0d53` can be reverted on its own. It changes no data and no API. The only
consequence of reverting is the return of the four fail-open defaults — which is
a reason not to, not a difficulty.

---

## 5. What must not enter a merge

Verified this session across all four repositories.

- **No `.env`, dump, key, `.pem` or credential file is tracked anywhere.** The
  only `.sql` under version control is Prisma migrations.
- Ignored and confirmed ignored: `backend/.env`, `backend/.env.staging`,
  `mobile/.env.local`, `backend/dist/`, `mobile/dist/`, `mobile/expo-env.d.ts`,
  `node_modules/`, `*.sql.gz`, `*.dump`, `backups/`.
- `mobile/dist/` was **rebuilt and deleted** during this session's route-count
  check; it is ignored and did not reach a commit.
- The scratch static server used for the browser verification lived in the OS
  temporary directory, never inside a repository, and has been deleted.

---

## 6. Preconditions before any of this runs

Merging is **not** authorised by this document. Before step 1:

1. **`docs/24` §14 passes on the physical iPhone** — 35 checks. The stacked
   mobile branch carries four milestones no handset has seen.
2. The staging entry criteria in [`docs/44`](44_STAGING_AND_LAUNCH_CHECKLISTS.md).
3. The owner says so.

If device acceptance finds a defect, **fix it on the feature branch and re-run
the gates.** Do not merge a device-dependent fix speculatively and do not merge
"to make the branch easier to manage" — the branch is not the risk.
