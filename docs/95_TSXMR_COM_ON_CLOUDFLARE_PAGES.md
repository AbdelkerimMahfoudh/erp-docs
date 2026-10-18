# 95 — Publishing tsxmr.com on Cloudflare Pages

> 2026-10-17, CLAUDE-B (local). The owner's brief of 2026-10-17: publish the existing public website at
> `https://tsxmr.com`. The domain is registered with Cloudflare Registrar. **Nothing was deployed, merged, published or
> changed in Cloudflare.** This is the audit, the repository preparation and the exact steps for the owner.

## 1. The audit's answers

1. **Latest complete public site:** `erp-control-web` branch **`tsx-public-site`**, now at `fe38bbc`. That is
   `8bf6f65` (the legal pages, 2026-10-16) plus this phase's `3c08c3f` and `fe38bbc`.
2. **`tsx-public-site` against `main`:** `main` is still `0417bfe` (2026-10-05). `tsx-public-site` is **ahead by 80
   commits and behind by none**, so `main` can be fast-forwarded, but only on the owner's approval.
3. **Production-build blockers:** 32 reasons for the public build (§5), 33 for the full build. Every one is deliberate.
4. **Owner facts vs. counsel vs. obsolete:** see §5. Factual answers alone **do not** unblock the build: the legal
   decisions and approvals of §5.3–§5.4 still refuse it, as designed.
5. **Can the website ship without the backend and the admin portal?** As built (`8bf6f65`): **no**. `/apply`, `/login`
   and `/application-status` call the API, the Dukan ERP page loads its prices from it, and the Owner account
   (`/account`) and Super Admin console (`/admin`) ship in the same bundle on the same origin. **Now: yes**, with
   `VITE_SITE_SURFACE=public` (§2).

## 2. What changed: the public surface (`3c08c3f`, `fe38bbc`)

`VITE_SITE_SURFACE=public` builds the public pages only. The default is `full`; without the variable nothing
changes, and the tests run the full surface.

- **Not built, linked, prerendered or listed in the sitemap:** `/apply`, `/login` and `/application-status`.
- **`/account` and `/admin`:** not rewritten, so they are 404 here. A build alias replaces their routes with a stub
  (`src/protected-areas.public.tsx`), so **none of their code is in the bundle**. The `--public` bundle audit checks
  this on every CI run.
- **No API:** `VITE_API_BASE` is neither asked for nor used. The CSP allows `connect-src 'self'` only, and no page makes
  a request.
- **Links into the business account:** "Sign in" and "Apply" link to **`VITE_PORTAL_ORIGIN`** (for example
  `https://dukan.tsxmr.com`) once it is set. Until then they are absent.
- **Prices:** the Dukan ERP page shows none and says to contact TSX-MR (EN/FR/AR).
- **Kept as they are:**
  - the seven legal and support pages and their `/in-app/…` variants (EN/FR/AR, RTL);
  - the security headers, sitemap, robots, canonical and hreflang tags, Open Graph and `security.txt`;
  - **every production refusal** (blank facts, test values, placeholders, legal blockers, drafts).
- **`.node-version`** pins Node 22.

**Verification, CI run 38991137218 on `fe38bbc` (all green):**

| Check | Result |
| --- | --- |
| Typecheck | passed |
| Vitest | 21 files, 401 / 401 |
| Full build | production refusal as designed; preview built; links 68 pages, 3 258 links, 0 broken; bundle audit PASS |
| Public build | production refusal (32 reasons, none for the API); preview 57 pages; links 58 pages, 2 733 links, 0 broken; bundle audit `--public` PASS |
| gitleaks | history (103 commits) and the built site clean |
| Playwright | 126 / 126: every public page in EN/FR/AR at 375 and 320 px, desktop, 200 % text, axe, keyboard and headers |

Screenshots are on `ci-evidence` under `evidence/fe38bbc…/`.

**Not done:** Playwright ran on the full preview, not on the public one. The public pages are the same components; the
three missing pages and the link changes are covered by Vitest. **Final screenshots need the real values** (§5.1),
because a preview shows marked test values and a banner.

## 3. Cloudflare Pages settings (Git integration)

| Setting | Value |
| --- | --- |
| Repository | `AbdelkerimMahfoudh/erp-control-web` |
| Production branch | **`main`**, after the owner approves fast-forwarding it to `tsx-public-site`. Alternative: `tsx-public-site` itself. Either way, only that branch deploys. |
| Framework preset | None |
| Root directory | `/` (repository root) |
| Install | `SKIP_DEPENDENCY_INSTALL=1` (Production and Preview), so the build command installs from the lockfile exactly |
| Build command | `npm ci && npm run build` |
| Build output directory | `dist` |
| Node | 22 (`.node-version`; also set `NODE_VERSION=22`). Do not set `NODE_ENV=production`: the build needs the dev dependencies. |
| Build system | v3 |
| Preview deployments | **None** (Settings → Builds → Branch control: "Preview branches: None"). Previews on `*.pages.dev` would be public. |

**Production variables.** All of them are public by nature: Vite puts every `VITE_*` value into the page. None is a
secret, and a secret must never be given one.

| Variable | Value |
| --- | --- |
| `VITE_SITE_SURFACE` | `public` |
| `VITE_PUBLIC_SITE_ORIGIN` | `https://tsxmr.com` |
| `VITE_PORTAL_ORIGIN` | unset until the business account has its origin (then e.g. `https://dukan.tsxmr.com`) |
| `VITE_API_BASE` | unset (a public build does not use it) |
| `VITE_ORGANIZATION_DISPLAY_NAME`, `VITE_ORGANIZATION_COUNTRY` | unset: they default to `TSX-MR` and `Mauritania` |
| The facts of §5.1 | as TSX-MR supplies them |
| `VITE_ACCOUNT_DELETION_CHANNEL`, `VITE_LEGAL_EFFECTIVE_DATE` | §5.2 |

Leave the Preview environment's facts empty: a preview build of the production command is then refused, never published.

**Safety.** Connecting the repository starts a production build at once. While §5 is open, that build is **refused**
and nothing is published. That is the guard working, not a failure to fix by setting values that are not true.

## 4. Custom domain and the www redirect (owner, after approval)

1. Workers & Pages → the project → **Custom domains → Set up a domain → `tsxmr.com`**. The zone is on Cloudflare, so
   Pages creates the record and the certificate.
2. Add **`www.tsxmr.com`** as a second custom domain, so it has a record and a certificate.
3. **Permanent www → apex redirect** (a zone rule on the free plan; nothing to buy). Rules → Redirect Rules → create a
   rule:
   - when **Hostname equals `www.tsxmr.com`**;
   - Dynamic redirect to `concat("https://tsxmr.com", http.request.uri.path)`;
   - status **301**, **preserve query string**.

   Pages' `_redirects` cannot match a hostname, so this rule cannot live in the repository.
4. SSL/TLS → Edge Certificates → **Always Use HTTPS: on**. HSTS comes from `_headers` (`max-age=31536000`). Add
   `includeSubDomains` / preload only once every subdomain is HTTPS (owner decision, docs/45).
5. **Check before announcing anything:**
   - `curl -I https://tsxmr.com/` → 200, with the CSP and `X-Frame-Options: DENY`;
   - `curl -I https://www.tsxmr.com/privacy?x=1` → 301 to `https://tsxmr.com/privacy?x=1`;
   - `/fr/privacy`, `/ar/terms` (with `dir="rtl"`) and `/ar/in-app/privacy` → 200;
   - `/account`, `/admin` and `/apply` → 404;
   - `/sitemap.xml`, `/robots.txt` and `/.well-known/security.txt` → 200;
   - refreshing any deep link → the same page.
6. **The project's `*.pages.dev` address** also serves the site. Every page's canonical names `https://tsxmr.com`.
7. **The mobile app:** `EXPO_PUBLIC_LEGAL_ORIGIN=https://tsxmr.com`. The app opens `/in-app/…`; those pages are public
   and never indexed.

## 5. What stops the production build today (32 reasons, public build)

### 5.1 Facts only TSX-MR can give

The table in the owner report lists, for each fact:

- **Organisation:** legal name, legal form, registration number, city, registered address.
- **Contact:** support, privacy and security emails.
- **Support:** hours, languages and response time.
- **Optional:** public phone, commercial email, support WhatsApp, store links.

The three mailboxes must exist and be read. The values go in Cloudflare's Production variables, never in the repository.

### 5.2 Not a fact to type today

- **`VITE_ACCOUNT_DELETION_CHANNEL`** must be a channel **configured and tested in production**. None is: WhatsApp is
  off, and email never carries a deletion code (F01 / O-A7). The guard is right to refuse.
- **`VITE_LEGAL_EFFECTIVE_DATE`** is the date of the **approved** texts, so it follows §5.3–§5.4.

### 5.3 Legal decisions (counsel, `docs/93` §2)

The 12 blockers:

- `legal_review`, `privacy_law`, `retention_period`, `backup_retention`, `sealed_history`;
- `processors`, `international_transfer`;
- `governing_law`, `liability`, `indemnity`, `refund_policy`, `publisher`.

**None is obsolete.** Two can now be partly answered:

- the **website** host is Cloudflare (Pages, DNS, Registrar);
- Cloudflare serves from a global network, so visitor requests are processed outside Mauritania.

The backend's hosts are still unchosen, and counsel writes the sentences.

### 5.4 Approval

Six documents are marked **DRAFT — REQUIRES TSX-MR APPROVAL**: privacy, terms, account deletion, privacy choices, legal
notice and security. Only TSX-MR turns them to approved, after counsel.

### 5.5 Obsolete for this publication

- **`VITE_PUBLIC_SITE_ORIGIN`:** now known, `https://tsxmr.com`.
- **`VITE_API_BASE`:** not needed by the public build.
- **`VITE_ORGANIZATION_DISPLAY_NAME` / `_COUNTRY`:** have defaults.

### 5.6 Wording to settle (not caught by the guard)

Several texts say the business account is "on this website". On a public-only `tsxmr.com` that is inaccurate until the
account is reachable there, or at a TSX-MR subdomain the sentence names. In EN, FR and AR:

- `content/dukan-erp.ts` (intro; the trial sentence);
- `content/pages.ts` (support: stores, access, trial; application status);
- `i18n/*` `home` (the trial sentence);
- legal: `legal-terms.ts` (scope; trial), `legal-privacy.ts` (scope).

The legal ones go to counsel with §5.3. The others need the owner's choice of wording once the portal's address is known.

## 6. Not done, by the brief

- Nothing was deployed or published.
- No branch was merged.
- No Cloudflare project, DNS record, rule or variable was created.
- Nothing was bought, and no secret was created.

## Superseded in part by `docs/96` (2026-10-17, later)

The public build is now the **pre-launch** website, with its own gate (PUBLIC_WEBSITE):

- **Required:** the TSX-MR facts and TSX-MR's approval of six pre-launch texts.
- **Not required:** the deletion channel, the support commitments and counsel's service blockers. Those stay with the
  PORTAL and APP_STORE gates.
- **Cloudflare build command:** `npm ci && npm run build:public-release`.
- **The origin:** must be `https://tsxmr.com` exactly.
- **`VITE_PORTAL_ORIGIN` must stay unset:** the gate refuses it.

## Superseded in part by `docs/96` §6 (2026-10-17, CLAUDE, `0516a9c`)

TSX-MR is operated by an individual (D182), so the §5.1 "legal form, registration number" and "registered address"
no longer apply to the public website. What remains for PUBLIC_WEBSITE is:

- the correspondence address;
- the effective date;
- the approval of the six texts (`docs/97`).

The Cloudflare variables are in `docs/96` §6. The phones go in `VITE_ORGANIZATION_PHONE`.

## Superseded in part by `docs/96` §3, §9 and §11 (2026-10-17, CLAUDE, `ad41e4c`)

- The address is given (D184), so only two things remain for PUBLIC_WEBSITE: the effective date (the publication day)
  and the approval of the six texts (`docs/97`).
- A production dry run found that an approved release would have failed its own bundle audit, because API code and
  preview values were in the public bundle. That is fixed in `b7b8fc2`.
- The deployment and rollback plan is `docs/96` §11.

## Production promotion of the redesign (2026-10-17, CLAUDE, cloud)

The owner approved the redesign (`site-redesign` `de6e6ba`) for production.

**Promotion:**
- `tsx-public-site` was fast-forwarded `6016b8a → de6e6ba` by a normal push. It took 5 commits, `c45de29` …
  `de6e6ba`, with no force, squash or recreation, and nothing after `de6e6ba`.
- Cloudflare built production deployment **`ccf9d282-a314-4868-88ec-a31f3c25a6f8`**.
- **Rollback target:** the previous production deployment, **`b4737b88-3cc8-473f-9957-7374ce768e8f`** (Cloudflare
  dashboard → `tsxmr-public` → Deployments → that deployment → "Rollback to this deployment").

**Live verification.**
- It runs from a GitHub runner, because this container cannot reach tsxmr.com.
- The workflow is `.github/workflows/verify-production.yml` on the `ops/verify-production` branch: the script
  `scripts/verify-production.mjs` plus the Playwright public suite pointed at `https://tsxmr.com`.
- Evidence is on the `ci-evidence` branch under `evidence/production/`. Runs: 39040829534, then 39041151582
  (`afc2dad`).

| Check | Result |
| --- | --- |
| TLS (apex and www) | valid, Google Trust Services, 90 days |
| Redirects | http→https 301; www→apex 301 with path and query; no loop |
| Headers | equal to the build's `_headers` (CSP, HSTS without preload, nosniff, frame, referrer, permissions, COOP) |
| Pages | canonicals on `https://tsxmr.com`; no preview host, tracker, RUM or plain-http resource; in-app pages noindex |
| 404 | `/account`, `/account/trial`, `/admin`, `/admin/businesses`, `/apply`, `/login`, `/application-status`, `/app-shell.html`, unknown |
| robots, sitemap, security.txt | as built; the sitemap has 36 URLs, with no in-app or protected page |
| Email DNS | **unchanged**: MX route1/2/3.mx.cloudflare.net; one SPF `v=spf1 include:_spf.mx.cloudflare.net ~all`; DMARC `p=none`; DKIM `cf2024-1`; Brevo code TXT and `brevo1`/`brevo2` CNAMEs |
| Browser suite against production | **103/103** (hamburger, EN/FR/AR, toggle and persistence, cards, reduced motion, RTL, no overflow at 320/375) |
| Byte identity with the build | **failed on 45 pages**: see below |

**The finding: Cloudflare Email Address Obfuscation (zone setting, not the deployment).**
- Cloudflare rewrites every `mailto:` link into `/cdn-cgi/l/email-protection#…` and injects `email-decode.min.js`.
- The verifier decoded every rewrite back. Each difference from the build is that rewrite and nothing else, so the
  deployed files are the audited build.
- It is not material to the design or the content, and a rollback would not change it: the setting is zone-wide, so it rewrites
  every deployment. **The deployment was kept.**
- It still contradicts "no third-party script beyond the build" and breaks the links without JavaScript.
- **Owner action:** Cloudflare → tsxmr.com → Scrape Shield → **Email Address Obfuscation: Off**. Then re-run the
  workflow (push to `ops/verify-production` or run it manually); every check should pass.

**Preview deployments are still ON (open discrepancy).**
- This document and D187 say "preview deployments: None", but `site-redesign` previews exist:
  - one at `https://site-redesign.tsxmr-public.pages.dev`, marked noindex, with a canonical on tsxmr.com;
  - the production alias `tsxmr-public.pages.dev`, with no robots header and a canonical on tsxmr.com.
- The brief says to set them back to None after verification. This session has no Cloudflare access.
- **Owner action:** Pages → `tsxmr-public` → Settings → Builds → Preview branch deployments: **None**.

**Website CI:**
- `tsx-public-site` `de6e6ba` failed once (run 39040460157, 1/103) on a test race: the language was read before
  render.
- Fixed in the test only, `site-redesign` `918b0b5` (CI green). That commit is not deployed and changes no shipped
  file; it reaches production with the next approved promotion.
- The failed job on `de6e6ba` was re-run once, to confirm.

## Production promotion of the custom 404 page (2026-10-17, CLAUDE, cloud)

- `tsx-public-site` was fast-forwarded `de6e6ba → 397ec6b` with a normal push.
- Production deployment `8a828f1b-65d5-4ea4-8644-dfdaebad09d2`; rollback target `ccf9d282-a314-4868-88ec-a31f3c25a6f8`.
- Detail and evidence: `docs/74` "Page not found".
- The workflow `verify-not-found` (branch `ops/verify-production`) now checks production by default; run it by hand
  with a preview's origin to check a page before promotion.
- Still open: Email Address Obfuscation is on, and preview deployments are still on (both owner settings).

## A preview of one branch only, for the owner's iPhone review (2026-10-18, CLAUDE, cloud)

**Preview deployments are now off.** The "still on" discrepancy above no longer holds. Evidence: since 02:17Z, no push of
a non-production branch has produced a "Cloudflare Pages" check run on GitHub (`ops/verify-production`,
`website-balanced-motion`), while the production commit `e953c58` has one.

**The owner's instruction (2026-10-18).** Preview only `website-balanced-motion`, for visual review before promotion;
never all branches; do not promote. This session has no Cloudflare access, so the Chrome-extension session makes the
change.

**The setting:** Pages → `tsxmr-public` → Settings → Builds → Branch control → Preview branch: **Custom branches**.
- Include: `website-balanced-motion`, the exact name, no wildcard.
- Exclude: empty.
- Production branch and its settings: unchanged.

**Noindex.** Cloudflare adds `X-Robots-Tag: noindex` to every preview deployment. Production indexing does not change:
- `tsxmr.com` and its `robots.txt` are untouched;
- the build is the same production command, so every page's canonical stays `https://tsxmr.com`.

**Verification:** branch `ops/verify-preview`, which holds tooling only.

**After the review:** set Preview branch back to **None**, whether or not the branch is promoted.

