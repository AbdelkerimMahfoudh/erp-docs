# 44 — Staging and production launch checklists

Two gates, in order. **Neither has been entered.** Staging cannot begin until
physical-device acceptance passes; production cannot begin until the external
decisions in [`docs/45`](45_EXTERNAL_DECISIONS.md) are made.

Every box is unticked. Nothing here is a claim about what has been done.

---

## Gate 4 — staging deployment

### Entry criteria — all four required

| # | Criterion | State |
|---|---|---|
| E1 | **`docs/24` §14 passes on the physical iPhone** — 35 checks | 🔴 not started |
| E2 | Gate 1 (automated) green on the exact commit being deployed | ✅ green at `6bb0d53` / `ed7d614` |
| E3 | A **host** exists that is not a developer's laptop | 🔴 owner decision — `docs/45` |
| E4 | An **off-machine database backup** is possible from that host | 🔴 risk R3 |

E1 is not negotiable. Staging exists to rehearse a build that has been shown to
work on a phone; rehearsing an unverified one only moves the discovery later.

### Host and runtime

- [ ] Node version pinned to match local (`node -v` recorded in the deploy log)
- [ ] Process manager restarts the API on exit, with a restart cap
- [ ] `SIGTERM` reaches the process — `app.enableShutdownHooks()` is already
      wired, so a clean stop drains in-flight requests
- [ ] `UPLOAD_DIR` on a **mounted volume**. Local disk in a container loses every
      upload on restart
- [ ] Reverse proxy terminates TLS and is the only route to `/api/*`
- [ ] `APP_COMMIT` and `APP_BUILT_AT` set at build time, so
      `/api/health/version` can say what is running

### Configuration

- [ ] `NODE_ENV=production`, `APP_ENV=staging` — the second drops HSTS so a
      staging host cannot pin a parent domain to HTTPS for six months
- [ ] `API_BIND=127.0.0.1`
- [ ] `SWAGGER_ENABLED=false`
- [ ] `CORS_ORIGINS` names only the staging origins
- [ ] `COOKIE_SECURE` — `true` if staging is HTTPS. **If a plain-HTTP LAN path is
      kept for phone testing, `NODE_ENV` must not be `production`**, or the
      startup guard will refuse (correctly)
- [ ] `JWT_ACCESS_SECRET`, `OTP_PEPPER`, `PLATFORM_ADMIN_KEY` freshly generated
      **for staging**, never copied from anywhere
- [ ] `LOG_LEVEL=info`
- [ ] Full matrix walked: [`docs/42`](42_ENVIRONMENT_MATRIX.md)

### Database

- [ ] A **separate** database from any production one, on a separate credential
- [ ] Two accounts: migrator (`DATABASE_URL`) and least-privilege runtime
      (`APP_DATABASE_URL`). The app must not be able to run DDL
- [ ] `prisma migrate deploy` — **never `migrate dev`**, never `migrate reset`
- [ ] `prisma migrate status` reports 63 applied, 0 pending
- [ ] **`SEED_DEMO=false`** unless demo data is deliberately wanted. It is
      **opt-out**: forgetting writes a demo company, branch and owner (risk R7)
- [ ] `OWNER_SEED_PASSWORD` supplied out of band if seeding at all
- [ ] A dump taken and **verified** per `docs/22` §2 *before* the first migration

### Verification on the host

- [ ] `GET /api/health` → 200
- [ ] `GET /api/health/ready` → ready, `pendingMigrations: 0`
- [ ] `GET /api/health/version` reports the intended commit
- [ ] `GET /api/docs` → **404**. If it answers, `SWAGGER_ENABLED` is wrong
- [ ] `curl` the API port directly from outside the host → **refused**
- [ ] Security headers present (helmet), and **no HSTS** on staging
- [ ] `Access-Control-Allow-Origin` absent for an unlisted origin
- [ ] Rate limiting observed: `X-RateLimit-*` on an ordinary response, and a
      401 storm on `/auth/login` throttles at `AUTH_THROTTLE_LIMIT`
- [ ] Log lines carry a request id, and **no** `authorization`, `cookie`,
      `password`, `refreshToken`, `deviceSecret`, or `?t=` ticket value
- [ ] A real sign-in from the mobile build against the staging origin
- [ ] One report exported end to end, and the **file opened in a spreadsheet**
      (risk R9 — this is the check nobody has done)

### Restore drill — required, not optional

- [ ] Restore the verified dump into a **disposable** database, per `docs/22` §3
- [ ] Row counts match the source for `units`, `sales`, `audit_logs`
- [ ] The temporary database is **dropped**, and the drill recorded in `docs/22`
      with its date and the schema version it ran against

The last drill was **2026-08-05** and the schema has moved since. A drill is only
true for the schema it ran against.

---

## Gate 5 — production launch

**Do not start until every row of [`docs/45`](45_EXTERNAL_DECISIONS.md) is
decided.** Several are purchases or account creations that only the owner can
make.

### Entry criteria

| # | Criterion | State |
|---|---|---|
| P1 | Staging (gate 4) passed and stable | 🔴 |
| P2 | **Administrator MFA exists** (risk R2) | 🔴 not implemented |
| P3 | A **real contact-delivery provider** (risk R6) | 🔴 no provider |
| P4 | **Domain, DNS, TLS** owned and configured | 🔴 owner decision |
| P5 | **Off-machine, scheduled, verified backups** (risk R3) | 🔴 |
| P6 | **Error reporting and alerting** (risk R10) | 🔴 |
| P7 | Dependency advisories triaged (risk R4) | 🟠 recorded, untriaged |
| P8 | A payment provider, **or** a written decision to launch on administrative grants only | 🔴 owner decision |

P8 has a real alternative: the subscription lifecycle already supports an
**audited administrative grant**, and `docs/37` records that a grant carries no
fabricated payment and leaves `currentPeriodEnd` null. Launching on grants while
a provider is chosen is a legitimate path — it just has to be a decision, not an
oversight.

### Configuration

- [ ] `NODE_ENV=production`, **`APP_ENV` unset** so HSTS applies
- [ ] `COOKIE_SECURE` unset or `true` — never `false`
- [ ] `API_BIND=127.0.0.1`
- [ ] `SWAGGER_ENABLED=false`
- [ ] `CORS_ORIGINS` names only production origins — the startup guard now
      refuses a list containing `localhost` or a private range
- [ ] `WHATSAPP_CHANNEL` is a real provider. `development-log` is already
      refused at startup, and `disabled` means **registration cannot issue a
      session**
- [ ] Every secret generated fresh for production, stored in a secret manager
      and not in a file next to the code
- [ ] `SHADOW_DATABASE_URL` **absent**
- [ ] `SEED_DEMO=false`, and ideally the seed never runs against production

### Data and recovery

- [ ] Backups scheduled, off-machine, **encrypted at rest**
- [ ] Retention decided in writing (how many daily, weekly, monthly)
- [ ] **RPO and RTO decided in writing** — nobody has stated either
- [ ] A restore drill completed against the production schema
- [ ] Audit-row retention decided. Nothing financial is hard-deleted, so this
      table only grows

### Observability

- [ ] Logs shipped off the host, with a retention period
- [ ] Alerts on: readiness failing, error rate, database unreachable, disk
- [ ] Someone receives the alerts, and it is written down who
- [ ] A runbook for a degraded dependency: database down, provider down, disk
      full — see `docs/41` R10

### Launch verification

- [ ] `/api/docs` → 404
- [ ] API port unreachable except through the proxy
- [ ] HSTS present
- [ ] TLS certificate valid and auto-renewing
- [ ] A real registration end to end, with a code delivered by the **real**
      provider
- [ ] A real sign-in from a **store build** of the app
- [ ] Cost and margin invisible to an account without `cost.view`
- [ ] One export downloaded and opened
- [ ] A rollback rehearsed to `pre-reports` on a copy — see
      [`docs/43`](43_MERGE_AND_ROLLBACK.md)

---

## What neither checklist authorises

Merging, deploying, buying, registering a domain, changing DNS, or taking a
production backup. Every one of those is the owner's, and none was done.

## Store identity — the operator's steps (2026-10-13)

The app's identity is final (`docs/21` D168, as amended; `docs/75` §15):

- Dukan ERP, operated by TSX-MR;
- slug `dukan-erp`;
- scheme `dukanerp`;
- iOS bundle identifier and Android package `mr.tsxmr.dukanerp`.

Nothing was published under the old identifiers. Each step below is the owner's: none was done, and no value here is
invented.

1. **Choose the Expo account that will own Dukan ERP.** Today's project, `834d8b25…`, belongs to `salah_rim`.
2. **Link an EAS project named `dukan-erp`.** Expo will not rename the old project's slug.
   - Create the project on expo.dev under that account and copy its ID. Then, in `erp-mobile`:
     ```
     npx eas-cli@latest init --id <the new project ID> --force
     ```
     `--force` replaces `extra.eas.projectId` in `app.json`.
   - In the same commit, set `EAS_PROJECT_ID` in `lib/app-identity.test.ts` to that ID, and run
     `node --test lib/app-identity.test.ts`.
   - Do not delete the old project: it holds the build history. `npx eas-cli@latest project:info` (read-only) then
     shows the link.
3. **Before the first build of the new identity, drain every test phone.**
   - Send each phone's queued exchanges.
   - Linking a new project gives Expo Go a new storage scope: phones sign in again and verify their device again.
   - An internal preview APK of `mr.retailerp.app` is a different app. Drain it, then uninstall it after the new build
     is installed.
4. **Android.** Run `npx eas-cli@latest build --platform android --profile preview`.
   - Accept "Generate a new Android Keystore?": the old keystore belongs to `mr.retailerp.app`.
   - Keep EAS's copy of the new key. It signs every future upload of `mr.tsxmr.dukanerp`.
   - The Google Play app is created by the owner with package `mr.tsxmr.dukanerp`.
5. **iOS.** This needs the Apple Developer membership. The team ID comes from Apple, never from here.
   - The App Store Connect app record uses bundle identifier `mr.tsxmr.dukanerp`, name Dukan ERP and seller TSX-MR.
   - Then run `npx eas-cli@latest build --platform ios --profile production`.
   - Then run `npx eas-cli@latest submit --platform ios` for TestFlight. The remaining conditions are in `docs/67` §8 and
     its later sections.
6. **Do not use the `development` profile** unless `expo-dev-client` is installed deliberately (a dependency change).
   The profile asks for a development client the project does not have.
7. **Check the build itself, on a physical phone, against `docs/24` §65:** the name, the package, the scheme, the prompts
   and the upgrade.
