# 74 — The TSX-MR public website and the Dukan ERP product site (2026-10-12)

The control website (`erp-control-web`) becomes the official website of **TSX-MR**, with **Dukan ERP** presented as a
product developed and operated by TSX-MR, beside the preserved application / Owner / Super Admin portal. Owner's brief
of 2026-10-12 (CLAUDE-B). **Nothing was deployed, purchased, created or published**; no DNS, no live data, no App Store
step. Website branch `tsx-public-site` (from `money-agent-3` `36f04b2`).

Verification runs only in GitHub Actions on Linux: the owner's PC cannot run Vite 8 (Smart App Control blocks Rolldown's
native binary; its WebAssembly fallback cannot resolve Windows paths; WSL is absent). The owner chose this route and
confirmed the repository is connected to no hosting. Every run commits its evidence to the website repository's
`ci-evidence` branch under `evidence/<commit>/` (job logs need admin rights to read, even on a public repository).

---

## 1. Identity (the brief)

| | |
| --- | --- |
| Public organization name | TSX-MR (input `VITE_ORGANIZATION_DISPLAY_NAME`, default `TSX-MR`) |
| Product | Dukan ERP |
| Relationship | "Dukan ERP is developed and operated by TSX-MR" (footer of every page) |
| Logo | none approved — `OrgMark` (navy square "T" + name) and `ProductMark` (indigo gradient "D" + name) are replaceable text treatments in `src/components/public/blocks.tsx`; the social image and icons are the same text rendered in CI (`scripts/brand-assets.mjs`) |

Not invented anywhere: legal name, legal form, registration number, tax number, address, telephone, domain, any email,
social accounts, founding date, founders, certifications, clients, partners, awards, payment-provider relationships.
They are production inputs (§3). **Discrepancy recorded:** the app is still named "Retail ERP" (`app.json`, bundle
`mr.retailerp.app`), the API "Phone Store ERP API", the WhatsApp templates "Retail ERP" (`docs/64`) — the App Store name
and the templates must say Dukan ERP before submission (§7, B-11).

## 2. Architecture and routes

One Vite + React SPA with **build-time prerendering** of the public pages:

- `npm run build` = typecheck → `vite build` (page) → `vite build --ssr src/entry-server.tsx` (renderer) →
  `node scripts/prerender.mjs`. Every public page in every language becomes its own HTML file with its own `lang`,
  `dir` and head; the protected areas get `app-shell.html` (empty, `noindex`); `404.html`; the generated host files.
- Languages are in the address: English unprefixed, French `/fr…`, Arabic `/ar…` (`src/site/routes.ts`). A visitor who
  chose French or Arabic before, landing on an English address, is moved once to the same page in their language; a
  crawler always reads the address it asked for.
- `src/site/routes.ts` is the one table read by the router, the prerenderer, the sitemap, robots and the heads.

| Route | Page | Indexed | Notes |
| --- | --- | --- | --- |
| `/` | TSX-MR home | yes | hero, Dukan ERP feature, problems, capabilities, security, languages, CTAs |
| `/about` | About TSX-MR | yes | factual; company-details block from the inputs |
| `/products` | Products | yes | Dukan ERP card |
| `/products/dukan-erp` | Dukan ERP | yes | the two activities, provider disclaimer, how a business starts, app, **server-derived pricing and estimate** (moved unchanged from the old home) |
| `/contact` | Contact | yes | `mailto:` to the configured addresses only — no server form |
| `/support` | Support | yes | sign-in, verification, stores, staff, stock, sales, returns, subscriptions, deletion |
| `/privacy`, `/terms`, `/account-deletion` | legal | yes | version + effective date + contents; drafts with blockers |
| `/apply` | Business application | yes | the existing application flow, unchanged |
| `/application-status` | Application status | **no** | there is no public status endpoint; the status shows after the Owner signs in (honest page + sign-in link) |
| `/login` | Sign in | **no** | Owners → `/account`; staff use the app |
| `/account/*` | Owner area | **no** | unchanged; `X-Robots-Tag` + `noindex` meta; not prerendered |
| `/admin/*` | Super Admin | **no** | unchanged; no longer linked from any public page; robots `Disallow` |
| anything else | 404 | no | prerendered `404.html`, real 404 status |

Preserved and regression-tested (existing suites + `e2e/`): the application with contact verification, Owner sign-in
and account chooser, the account page (status, period, per-store quote, seat/store/activity requests, payments,
history, grant dates), Super Admin sign-in and step-up, the console (applications, businesses, lifecycle decisions,
payments with mandatory reference, seat queue, audit, price schedule, `expectedVersion` conflicts). No Super Admin
function was brought into the app. The one inline style (a console checkbox) became a class so the CSP needs no
`unsafe-inline`.

## 3. Production inputs and the release refusal

`src/config/schema.ts` (pure; read by the page, the build guard, the prerenderer and the tests). The project's
convention is kept: `VITE_*` build variables (Vite exposes only that prefix; they are public values, never secrets).
Set them in the Cloudflare Pages project's **Production** environment.

| Variable | Required | What TSX-MR must supply |
| --- | --- | --- |
| `VITE_PUBLIC_SITE_ORIGIN` | yes | `https://<domain>` (no trailing slash) |
| `VITE_ADMIN_SITE_ORIGIN` | no | `https://admin.<domain>` if the console gets its own origin (§8.7) |
| `VITE_API_BASE` | yes | `https://api.<domain>/api/v1` (the brief's `API_ORIGIN`; existing variable kept) |
| `VITE_ORGANIZATION_DISPLAY_NAME` | yes (default `TSX-MR`) | |
| `VITE_ORGANIZATION_LEGAL_NAME` | yes | full registered legal name |
| `VITE_ORGANIZATION_LEGAL_FORM` | yes | e.g. the registered form |
| `VITE_ORGANIZATION_REGISTRATION_NUMBER` | yes | trade-register number |
| `VITE_ORGANIZATION_COUNTRY` | yes (default `Mauritania`) | |
| `VITE_ORGANIZATION_CITY` | yes | |
| `VITE_ORGANIZATION_ADDRESS` | yes | registered street address |
| `VITE_ORGANIZATION_PHONE` | no | public number, shown only if set |
| `VITE_SUPPORT_EMAIL` | yes | |
| `VITE_PRIVACY_EMAIL` | yes | |
| `VITE_COMMERCIAL_EMAIL` | no | |
| `VITE_SECURITY_EMAIL` | no | publishes `/.well-known/security.txt` when set |
| `VITE_SUPPORT_WHATSAPP` | no | existing variable |
| `VITE_APPLE_APP_STORE_URL`, `VITE_GOOGLE_PLAY_URL` | no | only once the app is published; text links, no badges |
| `VITE_ACCOUNT_DELETION_CHANNEL` | yes | `whatsapp` — **set only once WhatsApp Cloud API delivery is configured and tested in production** (the only channel the backend implements for deletion) |
| `VITE_LEGAL_EFFECTIVE_DATE` | yes | `YYYY-MM-DD` of the approved legal texts |

`npm run build` (mode `production`) **refuses before writing anything** (`vite.config.ts` `releaseGuard`) when a
required value is blank, malformed, not HTTPS, carries a test marker (`[TEST]`, `.invalid`, `example.com`,
`localhost`, `127.0.0.1`, `lorem`), names an unsupported deletion channel, or **any `[[blocker:id]]` remains in a
published text** (§7). Measured in CI: the refusal names all 11 missing inputs and the 7 open legal blockers, and leaves
no `dist/`. `npm run build:preview` fills blanks with visibly marked test values, shows a banner on every page, and is
`noindex` everywhere (meta, `X-Robots-Tag`, `robots.txt: Disallow: /`). Test values are used only outside production
(unit-tested).

## 4. Content, languages, RTL

- **One canonical structure** (`src/content/`): every long text is a typed document (sections → blocks) or a typed page
  object holding EN, FR and AR side by side. `test/content-parity.test.ts` refuses a section, block, list item,
  placeholder or blocker present in one language and not another, an unknown input name, an unregistered blocker, a
  French or Arabic text left in English, a provider name, a store-availability claim, or filler text.
- Short interface strings stay in the existing catalogues (exact key parity tested since 2026-10-05).
- `{input}` placeholders are filled at render; emails become `mailto:` links; values that read left to right are
  `<bdi>`-isolated inside Arabic; a blank value or a blocker renders as a visible "pending" mark in a preview.
- Arabic: `dir="rtl"` on the document from the prerendered file onward; logical CSS properties only; verified at 375 px
  and 320 px for every page (§9).
- Legal pages show "Version 1.0 (draft)" and the effective date (or "Effective date not set").
- Visual system: the app's palette (`#5146D9` indigo, `#172033` navy text, `#F7F8FB` background), light and dark (the
  site already supported both cleanly); a same-origin `theme-boot.js` sets the stored theme before paint without an
  inline script; reduced motion honoured.

**Accuracy notes from the code audit (2026-10-12):**
- The brief describes the money-services commission as "manually entered per transaction"; **the code computes it from
  the rate the Owner configures per provider** (`docs/73` §4.2). The site states what the code does.
- No provider is named or claimed as integrated, approved or endorsed; Dukan ERP records operator-entered exchanges.
- Security claims are limited to implemented facts: Argon2id hashes, append-only audit trail (DB triggers), per-store
  permissions checked server-side, the separate admin realm with password re-confirmation, masked customer numbers,
  revocable sessions and devices. Not claimed: encryption at rest (none exists), MFA (none), deletion timeframes.

## 5. Metadata, generated files, headers

- Per page: title, description, canonical (from `VITE_PUBLIC_SITE_ORIGIN`), `hreflang` en/fr/ar/x-default, Open Graph
  (`og:image` = `/social/og-default.png`, 1200×630), Twitter card; `noindex, nofollow` on non-indexable pages and on
  every preview page.
- JSON-LD only on indexable production pages and only from supplied inputs: `Organization` (name, legal name, URL,
  support email, postal address) and on the Dukan ERP page `SoftwareApplication` (name, category, URL, publisher). No
  rating, review, offer, price, operating system or availability (tested).
- `robots.txt` (`Disallow: /account`, `/admin`; sitemap), `sitemap.xml` (every indexable page × 3 languages with
  alternates), `_redirects` (`/account*` and `/admin*` → `app-shell.html` 200; everything else unknown → 404),
  `_headers`, `/.well-known/security.txt` (only with a security email), `site.webmanifest`, SVG + PNG icons.
- `_headers` (every response): `Content-Security-Policy: default-src 'self'; script-src 'self'; style-src 'self';
  img-src 'self' data:; font-src 'self'; connect-src 'self' <API origin>; manifest-src 'self'; object-src 'none';
  base-uri 'self'; form-action 'self'; frame-ancestors 'none'; upgrade-insecure-requests`; `Strict-Transport-Security:
  max-age=31536000` (no `includeSubDomains` until every subdomain is HTTPS — owner decision); `X-Content-Type-Options:
  nosniff`; `X-Frame-Options: DENY`; `Referrer-Policy: strict-origin-when-cross-origin`; `Permissions-Policy: camera=(),
  microphone=(), geolocation=(), payment=(), usb=(), interest-cohort=()`; `Cross-Origin-Opener-Policy: same-origin`;
  protected areas `X-Robots-Tag: noindex, nofollow` + `Cache-Control: no-store`; hashed assets immutable.
- No source maps (`build.sourcemap: false`; the bundle audit refuses `.map` files and `sourceMappingURL`).

## 6. Privacy and deletion — what the code actually does (audit 2026-10-12)

> **Superseded in part (2026-10-16).** The current, line-referenced inventory is `docs/86` (data), `docs/87`
> (processors) and `docs/88` (retention and deletion). Out of date below: an email provider **does** exist in code
> (Resend, `EMAIL_CHANNEL=resend`, off by default; it never carries deletion codes); "no location" is not certain
> while receipt photos keep EXIF (F13); much of B-7 was fixed in the 0084/0085 rounds and in backend `dc53129`, and what
> remains is listed in docs/88. The legal pages added on 2026-10-16 are `docs/85`.

The privacy policy and the deletion page were written from a read-only audit of backend and app code (agent report in
this session; key facts):

- **Collected:** accounts (name, login, generated personal id, email, WhatsApp number, verification timestamps, Argon2id
  password/PIN hashes); applications (owner name, business/store names, activity, city, contacts, language); businesses,
  stores (incl. addresses, phones), staff roles/permissions, employee debts; products, barcodes, IMEI/serials, costs,
  suppliers; sales, payments, payer numbers (D151), customers/counterparties (names, phones, notes); money-agent
  exchanges incl. the **customer number stored in plaintext** (masked in lists; full number to `agent.customer.reveal`);
  expenses with optional receipt photos (local disk `UPLOAD_DIR`); sessions (IP, user agent), devices (label, platform,
  model, app version — no hardware id); OTP/verification rows (full destination, hashed code); audit trail (before/after
  JSON, append-only, hash-chained).
- **Not collected:** location, contacts; camera only scans (no images kept); no analytics, crash reporting or ad SDKs;
  no third-party cookies. **Outbound:** only Meta WhatsApp Cloud API, disabled by default; **no email provider exists**.
- **Deletion as implemented:** in the app (More → Your account → Delete account; also on the access-closed screen);
  irreversible warning; password again; a one-time code to the **verified WhatsApp number only**; executed immediately in
  one transaction; the last active Owner closes the business (all logins de-identified and revoked, customer/supplier
  contacts nulled, payer numbers nulled, branches deactivated, subscription cancelled). With WhatsApp disabled the
  server answers `503 deletion_unavailable` — **deletion cannot complete in production today**. No admin deletion
  route; support can only help a person regain access.
- **De-identification gaps (backend, release blocker B-7):** after deletion the code still keeps names/phones/emails and
  payer numbers inside append-only `audit_logs` JSON; `agent_transactions.customer_number` (not cleared even on business
  closure); full destinations in `otp_challenges` / `contact_verifications`; session IPs and user agents; receipt photos
  on disk; `branches.address`; `seat_allocations.requested_by`. The in-app warning "contact details are removed"
  overstates this. Fix in the backend (or approve an explicit disclosure) before publication.
- **Retention:** no scheduler; expired codes/sessions are not purged; audit and subscription records kept indefinitely;
  backups (when the script runs) keep 14. The legal retention period is undecided (`docs/64` §6).

## 7. Release blockers (publication is refused until each is resolved)

| # | Blocker | Who | Mechanism |
| --- | --- | --- | --- |
| B-1 | Legal identity and contact inputs (§3) | TSX-MR | build refusal |
| B-2 | `legal_review` — privacy, terms, deletion are drafts written from the code | legal adviser | blocker token |
| B-3 | `retention_period` — legal retention for accounting records | owner + adviser | blocker token |
| B-4 | `processors` — hosting, database, backup, email providers to be named once contracted | owner | blocker token |
| B-5 | `international_transfer` — where data is processed (Railway region) | owner | blocker token |
| B-6 | `governing_law`, `liability` — terms of service | owner + adviser | blocker tokens |
| B-7 | `deidentification_gaps` — backend deletion keeps contact data (§6) | development, owner approval | blocker token |
| B-8 | Deletion channel: WhatsApp Cloud API configured, templates approved, tested; then `VITE_ACCOUNT_DELETION_CHANNEL=whatsapp` | owner (Meta account) | build refusal |
| B-9 | Registration needs a delivery channel (503 `registration_unavailable` today); email has no provider class in the backend | development + owner | not a build check — documented |
| B-10 | Administrator MFA (`docs/45` D8): `/admin` must not face the internet without it — put it behind Cloudflare Access or keep it unreachable (§8.7) | owner | documented |
| B-11 | Names: app display name, bundle, WhatsApp templates and API title still "Retail ERP"/"Phone Store" — must match "Dukan ERP" before the App Store | owner decision + app change | documented |
| B-12 | Live migrations `0084`–`0091` and the API at `c7034c8`+ before this site talks to production | owner approval + backups | documented |
| B-13 | Website `main` is `0417bfe`; this work is on `tsx-public-site` — review, then merge to the production branch | owner | documented |

## 8. Deployment preparation (nothing below was executed)

Cheapest safe initial arrangement: **Cloudflare Pages** (website) + **Railway** (API + MySQL) + **Cloudflare DNS/TLS** +
**Resend** later for email + **Meta WhatsApp Cloud API** later + **Cloudflare R2** for encrypted off-site backups.
Placeholders: `<domain>` = the domain TSX-MR registers; `<gh>` = `AbdelkerimMahfoudh`.

### 8.1 Repository and production branch
1. The repository exists: `https://github.com/<gh>/erp-control-web` (public). No new repository is needed.
2. Review `tsx-public-site`; merge it into `main` with a pull request (fast-forward or merge commit — never force).
   Before that, confirm nothing deploys `main` today (handoff blocker 1; the owner confirmed no hosting is connected).
3. Production branch: `main`. All other branches build previews only if enabled (recommended: disable preview
   deployments, or protect them with Cloudflare Access, since a preview is public by URL).

### 8.2 Cloudflare Pages project
1. Cloudflare dashboard → Workers & Pages → Create → Pages → Connect to Git → `erp-control-web`.
2. Production branch `main`; framework preset **None**; build command `npm run build`; output directory `dist`;
   root `/`; environment variable `NODE_VERSION=22`.
3. Environment variables (Production): every `VITE_*` of §3. Preview environment (if kept): build command
   `npm run build:preview` and no real values needed.
4. The first production build will **fail by design** until §7 B-1…B-8 are resolved — that failure is the release check.
5. The generated `_headers`, `_redirects`, `404.html` are Cloudflare Pages-native; nothing to configure.

### 8.3 Custom domain, `www`, subdomains
1. Register `<domain>` (Cloudflare Registrar sells at cost; a `.mr` domain is registered through the `.mr` registry, not
   Cloudflare) and add it to Cloudflare (Free plan) — nameservers at the registrar.
2. Pages project → Custom domains → add `www.<domain>` and `<domain>`; choose the canonical one (recommended
   `https://<domain>`, i.e. `VITE_PUBLIC_SITE_ORIGIN=https://<domain>`), and add a Bulk Redirect (or a Redirect Rule)
   `www.<domain>/*` → `https://<domain>/$1` 301.
3. SSL/TLS → Full (strict); Always Use HTTPS on; minimum TLS 1.2. HSTS stays in `_headers` (no `includeSubDomains`
   until every subdomain is HTTPS-only).
4. `api.<domain>` → CNAME to the Railway service's domain (§8.6), proxied or DNS-only per Railway's custom-domain
   instructions; `admin.<domain>` only if §8.7 option A is chosen.

### 8.4 Email DNS (SPF, DKIM, DMARC) and transactional email
1. Choose the sending subdomain, e.g. `mail.<domain>` or `send.<domain>`, so the root's reputation is separate.
2. Resend → Domains → add it; Resend gives the exact records: an SPF `TXT` (`v=spf1 include:<resend value> ~all` on the
   sending domain, or its `MX`/`TXT` pair) and the DKIM `TXT`/`CNAME` records — add them in Cloudflare DNS (DNS-only).
3. DMARC on `_dmarc.<domain>`: start `v=DMARC1; p=none; rua=mailto:<dmarc-reports address>`, move to `p=quarantine`
   then `p=reject` after reports are clean.
4. The mailboxes `SUPPORT_EMAIL`, `PRIVACY_EMAIL`… need a receiving service (e.g. Cloudflare Email Routing → an
   existing inbox, free) — Resend only sends.
5. **Backend work owed:** no email provider class exists (`docs/69` §4); registration/verification by email needs one
   (Resend API key as a Railway secret, never in the website).

### 8.5 WhatsApp Cloud API prerequisites (later, with approval)
Meta Business account verified; a WhatsApp Business Account and phone number; templates in EN/FR/AR approved
(`WHATSAPP_TEMPLATE_AUTH_OTP`, `_ACCOUNT_DELETION`, `_ACCOUNT_DELETED`, closing notices) **with the Dukan ERP name**;
a permanent access token; the app secret and webhook verify token; `OTP_PEPPER`; `WHATSAPP_CHANNEL=cloud-api` on the
API (the production guard refuses a missing piece). Test a deletion end to end on staging, then set
`VITE_ACCOUNT_DELETION_CHANNEL=whatsapp` and rebuild the site. Cost is per message from Meta's country rate card (§12).

### 8.6 Railway: API and MySQL
1. Railway project (Hobby) with two services: **MySQL** (Railway template; persistent volume) and **API** (deploy from
   `erp-backend`, production branch, Dockerfile or Nixpacks `npm ci && npx prisma generate && npm run build`, start
   `node dist/src/main.js`).
2. **Private networking:** the API connects to MySQL over Railway's private network (`<mysql-service>.railway.internal`)
   — set `DATABASE_URL`/`APP_DATABASE_URL` from the MySQL service's private variables; **remove the MySQL public TCP
   proxy** (no public database port).
3. API variables (secrets in Railway, never in a repository): `NODE_ENV=production`, `APP_ENV` unset, `PORT`,
   `JWT_ACCESS_SECRET`, `OTP_PEPPER`, `COOKIE_SECURE=true`, `CORS_ORIGINS=https://<domain>` (plus the admin origin if any),
   `SWAGGER_ENABLED=false`, `PLATFORM_ADMIN_KEY` unset, `SEED_DEMO` unset, `UPLOAD_DIR` on a volume, the WhatsApp set when
   approved (`docs/42`). The backend's production guard refuses an unsafe combination at start.
4. Hosted MySQL notes (`docs/67`): `log_bin_trust_function_creators=1` before migrations that create triggers; Prisma
   `connection_limit` 10–20. Migrations: `npx prisma migrate deploy` with the migrator identity, after a backup.
5. Public domain only for the API (`api.<domain>`); the site and the API are same-site, so the `SameSite=Lax` session
   cookies work with credentialed CORS.
6. **Spending limits:** Workspace → Usage → set an email alert (e.g. $10) and a **hard limit** (minimum $10; e.g. $20)
   — at the hard limit Railway takes workloads offline, so choose it knowingly. Size: API 0.5 GB RAM cap, MySQL 1 GB.

### 8.7 The console (`/admin`) until MFA exists
Option A (recommended): serve the same Pages build on `admin.<domain>` too and put **Cloudflare Access** (Zero Trust,
free up to 50 users) in front of `admin.<domain>/*` and `<domain>/admin*` with one-time PIN to named administrator
emails; set `VITE_ADMIN_SITE_ORIGIN`. Option B: keep `/admin` reachable only through an SSH tunnel to a non-public
deployment (`docs/39`). Either way B-10 stays open until real MFA.

### 8.8 Backups and the restore drill
1. Railway volume snapshots/backups for MySQL where the plan offers them, **and** an off-site copy: a scheduled job
   (Railway cron service or GitHub Actions with a Railway token) runs `deploy/backup-encrypted.sh`
   (`mysqldump --single-transaction --routines --triggers --events --no-tablespaces --hex-blob`, AES-256 with
   `BACKUP_PASSPHRASE_FILE`) and uploads to an **R2** bucket (private; access key scoped to that bucket; object lifecycle
   e.g. 30 daily + 12 monthly).
2. Restore drill before launch and quarterly: download a backup, restore with path 2 of `docs/22` §3 into a scratch
   database, compare row counts, checksums and trigger bodies, prove the audit trigger fires as the app identity, drop
   the scratch database — exactly as drill E.5 and the 2026-10-10 PC drill.

### 8.9 Staging, promotion, rollback
- **Staging:** a second Railway environment (`staging`, `APP_ENV=staging`, its own database restored from a sanitised
  dump) and a Pages preview (or a second Pages project) on `staging.<domain>` behind Cloudflare Access, built with
  `npm run build:preview` plus staging origins.
- **Promotion:** merge to `main` → Pages builds production (the release check must pass) → smoke: home, `/ar`, privacy,
  a sign-in, `GET /api/v1/platform/plan` from the site, response headers (`curl -I`), `robots.txt`, `sitemap.xml`.
  Order for the system: migrations → API → website → app (`docs/73` §8.3).
- **Rollback (website):** Cloudflare Pages → Deployments → choose the previous production deployment → "Rollback to this
  deployment" (instant; no rebuild). **Rollback (API):** Railway → redeploy the previous deployment; a database rollback
  is a deliberate restore (`docs/22`), never a Git revert.

## 9. Tests and evidence

Evidence: `https://github.com/<gh>/erp-control-web/tree/ci-evidence/evidence/<commit>/` — `SCREENSHOT_INDEX.md`,
`screenshots/{en-desktop,en-375,fr-375,ar-375,en-desktop-200pct,keyboard,no-js,protected}/`, `contact-sheet-*.jpg`,
`browser/*.json` (per page: layout, overflow at 375/320, console/CSP errors, axe violations), `dist/` (the built
preview), and every log. **Final run: website commit `98c9107`, GitHub Actions run 38216501116, evidence
`ci-evidence:evidence/98c9107ca7dfc7266ad3f05d070321233686fcda/`** — 68 screenshots (12 pages × EN desktop, EN/FR/AR
375 px = 48; 12 at 200% text; keyboard; no-JS; 6 protected) and 8 contact sheets.

| Check | Result |
| --- | --- |
| Typecheck (src, tests, e2e) | PASS |
| Unit/component tests (vitest, 12 files) | PASS 115/115 (baseline before: 8 files / 48) |
| Production build refused without inputs/decisions | PASS (11 inputs + 7 blockers named; no `dist/`) |
| Preview build + prerender | PASS — 36 pages (12 × 3) + shell + 404 |
| Broken-link audit (all prerendered pages) | PASS — 1 659 links, 0 broken; external links listed |
| Exported-bundle audit | PASS — no secret, source map, credential or stray private address |
| `npm audit` | PASS — 0 vulnerabilities |
| Secret scan, full history (gitleaks) + built site | PASS — no leaks |
| Every public page × EN/FR/AR at 375 px and 320 px | PASS — no sideways scroll, one `h1`, `lang`/`dir`, `noindex` in preview, no console/CSP error |
| axe WCAG 2.0/2.1 A/AA on every public page × 3 languages | PASS — no serious or critical violation |
| Desktop 1280 px and 200% text, every page (EN) | PASS — no sideways scroll (one fix: the estimate row now wraps) |
| Keyboard: skip link first, lands on `main`; menu opens by keyboard; focus outline | PASS |
| Without JavaScript: prerendered Arabic page whole, phone menu opens | PASS |
| Anchors land below the sticky header | PASS |
| Host files: robots, CSP without `unsafe-inline`, frame/nosniff, protected `noindex`, 404 status | PASS |
| Protected pages (Owner signed out/in, admin sign-in/dashboard; fixture data) | PASS — `noindex`, no overflow, no console error |
| Visual review in a browser (owner's PC, the CI-built preview served locally) | PASS — Arabic home and menu at 375 px, French privacy policy, English desktop home |
| Contact form | N/A — `mailto:` only by design (nothing can be silently dropped) |
| Real production headers on a real host, TLS, HSTS | NOT VERIFIED — nothing deployed |
| Safari / iOS, Firefox; real screen readers (VoiceOver, TalkBack, NVDA) | NOT VERIFIED — Chromium only in CI; axe is automated, not a screen-reader test |
| Protected flows against the real API | NOT VERIFIED here — existing component tests with fixtures; last real-API run was the cloud session of 2026-10-10 |

## 10. Apple and store URL mapping

| Store field | URL |
| --- | --- |
| App Store Connect → Marketing URL | `https://<domain>/products/dukan-erp` |
| App Store Connect → Support URL | `https://<domain>/support` |
| App Store Connect → Privacy Policy URL | `https://<domain>/privacy` (and `/fr/privacy`, `/ar/privacy` per localisation) |
| App Store Connect → License Agreement (custom EULA, optional) | `https://<domain>/terms` |
| App Review notes → account deletion (Guideline 5.1.1(v): deletion is in the app) | `https://<domain>/account-deletion` |
| Google Play → Data safety → Delete account URL | `https://<domain>/account-deletion` |
| Apple organization enrollment → Website | `https://<domain>` (the About page carries the legal details once supplied) |
| Copyright line | `© <year> <legal name>` |

The site must not show store badges or availability before the app is published (it does not; text links appear only
when `VITE_APPLE_APP_STORE_URL` / `VITE_GOOGLE_PLAY_URL` are set).

## 11. Security findings

- Website: no secrets possible in the bundle (only public `VITE_*`); Owner bearer token in memory only, admin session
  HttpOnly cookie, two preference keys in storage (tested); strict CSP exercised in the browser checks; no source maps;
  no third-party script, font or tracker; no form that sends anything except the existing API flows.
- Findings for the backend (outside this phase): the de-identification gaps (§6, B-7); `contact_verifications` codes
  hashed with **unkeyed SHA-256** (6-digit codes are brute-forceable from a database copy — use the HMAC pepper as OTP
  does); expired verification/session rows never purged; customer numbers and payer numbers in plaintext (no
  column encryption); closing notices go to an Owner phone without checking it was verified; no admin MFA.
- Dependency audit: website 0; backend/mobile triage owed (`docs/48` control 20).

## 12. Estimated recurring cost (prices read 2026-10-12)

| Item | Cost |
| --- | --- |
| Cloudflare Pages (Free: 500 builds/month, 20 000 files) + DNS + TLS | $0 |
| Cloudflare Access (Zero Trust Free, ≤ 50 users) | $0 |
| Railway Hobby | $5/month including $5 usage; estimated usage API ~0.5 GB + MySQL ~1 GB RAM, low CPU, 1–2 GB volume ≈ $10–15 usage → **≈ $10–15/month** billed |
| Resend (Free: 3 000 emails/month, 100/day, 3 domains) | $0 (Pro $20/month if exceeded) |
| R2 (Free: 10 GB-month, 1 M Class A, 10 M Class B) | $0 for the expected backup volume |
| Domain `.com` at Cloudflare Registrar (third-party figures $9.77–$10.46/year; confirm on Cloudflare) | ≈ $10/year (≈ $0.85/month); `.mr` price not verified |
| WhatsApp Cloud API | per authentication/utility message at Meta's rate card for +222 — **not verified** (no official Mauritania figure found) |
| Apple Developer Program (individual or organization) | $99/year (≈ $8.25/month) |
| **Total** | **≈ $10–15/month + ≈ $10/year domain + $99/year Apple + WhatsApp per message** |

Sources: railway.com/pricing; docs.railway.com/reference/usage-limits; developers.cloudflare.com/pages/platform/limits;
developers.cloudflare.com/r2/pricing; resend.com/pricing; third-party registrar listings; developers.facebook.com
WhatsApp pricing (rate card not shown publicly per country in the fetched pages).

## 13. Limitations

- The owner's PC cannot build or test the website; every website check ran in CI on Linux (Chromium). The visual review
  on the PC used the CI-built files served locally.
- No device, no Safari/iOS, no Firefox, no screen reader was used.
- Nothing was deployed: the production headers, TLS, the custom domain, Cloudflare Access, Railway and every provider are
  documented, not exercised.

## Correction phase (2026-10-12)

- Dukan ERP page: the money-services commission is typed per exchange and paid by the customer; the provider neither
  pays nor checks it; the employee comes from the sign-in (D164; `83d2e1a`, parity guard against rate wording).
- Deletion and privacy pages state what is removed and that the sealed audit history and backups are not edited; blocker
  `deidentification_gaps` replaced by `sealed_history` (legal approval of the disclosure) and `backup_retention`
  (TSX-MR to supply) — `9b079c2`.
- Console: the second factor at sign-in, enrolment with the server's token, step-up with password and code (D167;
  `e2384c0`, `e892a27`) — **B-10 is built**; QR rendering is not.
- Package description names Dukan ERP (`fa3c3fe`).
- CI: run 38249387941 on `e892a27` green — Vitest 119/119, Playwright 58/58, gitleaks clean. `tsx-public-site` stays
  **unmerged**.

## Final technical identity (2026-10-13)

- **B-11 (names): done in the code.**
  - The app's name, login, permission texts and PDFs, and the API title, were renamed by D168.
  - The app's identifiers are now final (D168, as amended): slug `dukan-erp`, scheme `dukanerp`, iOS bundle identifier
    and Android package `mr.tsxmr.dukanerp`.
  - **Still open:** the WhatsApp templates. Their drafts in `docs/64` now say Dukan ERP and must be registered at Meta
    under that name, by the owner.
- **The site needed no change for the new identifiers.** It opens no app link and links to no store. Only the README's
  last "Electronics Retail Management System" was replaced (`72b1be8`).
  - **When the store records exist:** the Play link is `https://play.google.com/store/apps/details?id=mr.tsxmr.dukanerp`.
    The App Store link uses the numeric ID that App Store Connect assigns; it is not known yet and not invented.
- **Branding audit (CI run 38344708273 on `72b1be8`, all green):**
  - no "Retail ERP", "phonestore" or old identifier in any of the 52 built files;
  - "TSX-MR — …" titles the organisation's pages, and "Dukan ERP — TSX-MR" the product page, in EN, FR and AR;
  - Arabic pages render `lang="ar" dir="rtl"`, asserted by Playwright;
  - the web manifest and `og:site_name` are TSX-MR, the organisation (D163).
- **Gates in that run:**
  - typecheck;
  - Vitest 119 / 119;
  - the production build refused as designed (11 inputs and the legal blockers);
  - the preview built;
  - links: 38 pages, 1 659 links, 0 broken;
  - bundle audit PASS;
  - gitleaks history and dist clean;
  - Playwright 58 / 58.
- **`tsx-public-site` stays unmerged.** Nothing authorises the merge.
