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

**Preview deployments were limited to `site-redesign`, not off** (corrected 2026-10-19). This session inferred "off"
because no other branch had produced a "Cloudflare Pages" check run since 02:17Z. The Chrome-extension session found the
setting at "Custom branches: `site-redesign`" and removed that entry.

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

## The Balanced motion release: preview, review, promotion (2026-10-19, CLAUDE, cloud)

**The preview.** The Chrome-extension session set Preview branch to "Custom branches: `website-balanced-motion`" only.
- It removed the obsolete `site-redesign` entry and created no deploy hook.
- It retried the skipped deployment of the exact commit: `1b9c448`, deployment `8e3b3803`, at
  `https://8e3b3803.tsxmr-public.pages.dev` and `https://website-balanced-motion.tsxmr-public.pages.dev`.
- The Preview environment already held the same six public variables as Production. That differs from §3's "leave
  Preview empty"; whether to empty it again is an owner setting.

**The preview, verified** (`ops/verify-preview`, run `39187728547`, at both addresses):
- every built file was served byte-for-byte as `1b9c448` builds;
- 60/60 pages carried `X-Robots-Tag: noindex`, and every canonical was on `https://tsxmr.com`;
- headers equalled `_headers`, and production was unchanged;
- WebKit (iPhone 17, iPhone SE, desktop Safari) 27/27, public suite 160/160.

The owner and the team lead reviewed it on an iPhone and approved it.

**The promotion.** `tsx-public-site` was fast-forwarded with no force:
- `e953c58` → `1b9c448` at 02:41:16Z (Cloudflare production deployment `c9369247`);
- then `1b9c448` → `bf62a72` at 03:14:50Z (deployment `5ac08a5e`). `bf62a72` adds only `.gitleaksignore`; no site
  file changed.

**Production, verified** (`ops/verify-preview` in production mode, which runs `ops/verify-production`'s
`scripts/verify-production.mjs` against the commit's build; runs `39192467357` on `1b9c448` and `39193861703` on
`bf62a72`):
- 23/23 checks: TLS, redirects, headers, every file byte-for-byte, canonicals, no tracker, 404s, sitemap (39 URLs) and
  email DNS;
- WebKit 27/27, public suite 160/160, no retries;
- Email Address Obfuscation is now off. The last check of `e953c58` still found it on.

**CI.** The push to `tsx-public-site` turned the `checks` job red, though not because of the release:
- **Cause.** The full-history gitleaks scan reads every branch. On 2026-10-18 the `dukan-portal` CI committed browser
  evidence (`portal-claim-{en,fr,ar}.json`) carrying the test's generated `idempotencyKey`. Gitleaks'
  `generic-api-key` rule matched 9 of them. They are not credentials, and every branch's CI had failed on them since
  11:52Z.
- **Fix.** `.gitleaksignore` lists exactly those 9 fingerprints. It was reproduced first with CI's image
  (`sha256:c00b6bd0…`) on a full clone: 9 findings without the file, none with it. CI is green on `bf62a72` (run
  `39193773528`).
- **Prevention.** On `dukan-portal`, `ed6c583` carries the same `.gitleaksignore`. In `0fd418a`, the portal browser
  test's `record()` writes any `idempotencyKey` as `[masked: N characters]`. Gitleaks with CI's image finds nothing in
  that evidence, and flags an unmasked control copy.

**Still open (owner settings):**
- Preview branch back to **None**.
- Empty the Preview variables, or keep them.
- The `site-redesign` and `website-balanced-motion` preview deployments still answer at their addresses (noindex)
  until deleted.
- The production alias `tsxmr-public.pages.dev` answers 200 without noindex; its canonicals point to tsxmr.com.

## Account deletion as a Dukan ERP documentation entry: deployed (2026-10-19, CLAUDE, cloud; D216)

**Approval.** The owner approved this specific production change on 2026-10-19 and asked for a direct deployment after
verification, with no preview and no further approval. No preview was created: the branch name matches no preview
rule.

**The change** (web `5f666ea`, one commit on `tsx-public-site` `bf62a72`; nothing from the portal or browser-test
lines):
- the Dukan ERP page ends with a modest Documentation section; its entry "Account deletion" opens the localized
  deletion page;
- the deletion link is gone from the general footer and the company pages' "Related pages". The `/in-app/` footer and
  Support's Dukan ERP section keep theirs;
- the deletion page 1.1 is "Delete a Dukan ERP account", with its scope stated in EN/FR/AR. The policy is unchanged.

Full scope: `docs/21` D216.

**Verified before the promotion:**
- **Locally**, the CI workflow's steps:
  - typecheck;
  - Vitest 30 files, 519 tests (the new `test/deletion-docs.test.tsx` among them);
  - the full and public production builds both refused without their inputs;
  - preview builds with link and bundle audits;
  - Chromium e2e: full 130/130, public 163/163. The new test checks that the entry opens the page at its top and that
    the heading wraps at 320 and 375 px in light and dark;
  - the **real production build** (`npm run build:public-release` with the four production values): links and bundle
    PASS.
- **Against production's own build** (`bf62a72`): the same 88 files. Every changed page differs only by the removed
  deletion links, the new Documentation band, the new deletion text, and in-app Support's link label.
  `security.txt` differs only in its build-time `Expires`. Sitemap, `_headers`, `_redirects` and `robots.txt` are
  identical.
- **CI** on the exact candidate: run `39253330577` (`site-deletion-docs`, `5f666ea`), success.

**Rollback target, recorded before the promotion:**
- commit `bf62a72`, Cloudflare production deployment `5ac08a5e` (this document's previous section);
- the live site was checked byte-identical to the `bf62a72` build first (7 pages and the main bundle).
- To roll back: Cloudflare dashboard → `tsxmr-public` → Deployments → `5ac08a5e` → "Rollback to this deployment".
  Or revert `5f666ea` and push the revert to `tsx-public-site`, never with force.

**The promotion.**
- `tsx-public-site` was re-checked at `bf62a72` and fast-forwarded with no force to `5f666ea` at **12:42:41Z**.
- Cloudflare Pages (`tsxmr-public`, Git integration) built it at 12:43:00Z: the `Expires` in the served
  `security.txt`. It was serving at 12:43:19Z.
- This session has no Cloudflare dashboard access, so the new deployment's ID is not recorded here. It is the
  production deployment of `5f666ea` in the dashboard.
- CI on `tsx-public-site` `5f666ea`: run `39254183135`, success.

**Live verification:**
- **From this environment** (tsxmr.com is reachable):
  - 79 of 80 built files are served byte-for-byte as built, plus the three 404 pages. The 80th, `security.txt`,
    differs only by its build-time `Expires`;
  - `/subscription`, `/admin` and `/account` (and their localized forms) answer 404;
  - a Chromium check of the live site passed **33/33**, in EN/FR/AR:
    - the one Documentation entry opens the new page at its top;
    - no deletion link in the header, the footer or the company pages' links;
    - Support and the `/in-app/` footer keep theirs;
    - `/account-deletion`, `/fr/…`, `/ar/…` and their `/in-app/` forms answer 200 with the new heading;
    - no overflow at 320 and 375 px, light and dark;
    - no script error.
- **The established GitHub verification**: `ops/verify-preview` in production mode, `verify/target.env` set to
  `5f666ea` (tooling commit `8c87ec8`), run `39254553775`, evidence under `evidence/preview/5f666ea-39254553775` on
  `ci-evidence`:
  - `verify-production.mjs` 23/23: TLS, redirects, security headers equal `_headers`, every one of the 80 files
    byte-for-byte, canonicals, no tracker, 404s, a 39-URL sitemap, email DNS;
  - WebKit (iPhone profiles and desktop Safari) 27/27. That suite is the site's general WebKit set; it does not
    contain the new deletion check;
  - the public suite against tsxmr.com 163/163, the new deletion test included (Chromium).

  This is browser automation, not a physical iPhone.

**Outcome:** no regression found; the deployment stands.

**Still open (owner settings, unchanged by this change):**
- preview branches back to None;
- the `site-redesign` preview still answering (noindex);
- `tsxmr-public.pages.dev` answers 200 without noindex. Its canonicals point to tsxmr.com.

**Note for the integration line:** web `integration/browser-test` (`cd512c2d`) merged production at `bf62a72`. Merge
`tsx-public-site` `5f666ea` into it before it is next built or deployed.

## Riyade, coming soon: deployed (2026-10-20, CLAUDE, cloud; D218)

**Approval.** The owner approved the presentation in the review page on 2026-10-20 and authorized this production
deployment: the home row, the Products card, the footer entry, the Arabic wording and punctuation, and the two wording
changes. No preview was created, because the branch name matches no preview rule.

**The change** (web `cfd207b`, plus the branch record `5aa8322` under `notes/`, both on `tsx-public-site` `5f666ea`):
- a page per language at `/products/riyade`, `/fr/…` and `/ar/…`;
- a lighter card after Dukan ERP on Products;
- a row under the featured Dukan ERP card on the home page;
- a footer entry, under the heading "Products";
- the Products summary without "Today there is one: Dukan ERP.".

Full scope: `docs/21` D218.

**Verified before the promotion:**
- **Locally**, the CI workflow's steps on the final tree:
  - typecheck;
  - Vitest 31 files, 552 tests (the new `test/riyade.test.tsx` among them);
  - both surfaces' production builds refused without their inputs;
  - preview builds with link and bundle audits;
  - Chromium e2e: full 134/134, public 172/172;
  - the **real production build** (`npm run build:public-release` with tsxmr.com's public inputs): 91 files, 3 114
    links, 0 broken; PUBLIC_WEBSITE GO; the public suite 172/172 on it.
- **Against production's own build** (`5f666ea`):
  - the three Riyade pages are new;
  - the home pages differ in the row and the footer;
  - the Products pages differ in their description, the card and the footer;
  - the 36 other pages, the three Dukan ERP pages among them, differ in the footer only;
  - the sitemap gains exactly the three Riyade entries (39 → 42);
  - `security.txt` differs only by its build-time `Expires`;
  - `robots.txt`, `_headers`, `_redirects` and the manifest are identical.
- **CI** on the exact candidate: run `39363371901` (`site-riyade-coming-soon`, `5aa8322`), success.
- **Production before the promotion** (`ops/verify-preview` in production mode on `5f666ea`, run `39375772883`):
  - WebKit and the public suite passed;
  - `verify-production.mjs` 21/23. Both failures are one file: `sitemap.xml`'s `<lastmod>`, the build date
    (2026-10-19 live, 2026-10-20 in the verifier's build, same length). This is an artifact of verifying on a later
    UTC day than the deployment, not a change in production. See "Known limitation" below.

**Rollback target, recorded before the promotion:**
- commit `5f666ea`, its Cloudflare production deployment (D216's; its ID is in the dashboard, not readable from this
  session);
- to roll back: Cloudflare dashboard → `tsxmr-public` → Deployments → the `5f666ea` deployment → "Rollback to this
  deployment". Or revert `cfd207b` and `5aa8322` and push the revert to `tsx-public-site`, never with force.

**The promotion.**
- `tsx-public-site` was re-checked at `5f666ea` and fast-forwarded with no force to `5aa8322` at **05:47:39Z**
  (`5f666ea7..5aa8322f`).
- Cloudflare Pages (`tsxmr-public`, Git integration) built and served it within four minutes. The first live check
  (05:51:32–43Z) found every built file byte-for-byte, including the sitemap dated 2026-10-20.
- This session has no Cloudflare dashboard access, so the new deployment's ID is not recorded here.
- CI on `tsx-public-site` `5aa8322`: run `39376798802`, success.

**The production verifier** (`ops/verify-production` `5a01050`, with `tsx-public-site` `5aa8322` merged in at
`fb59f76`). Two checks were added; every other check is unchanged:
- the sitemap has exactly 42 URLs, the same set as the build's `sitemap.xml`, the three Riyade addresses among them;
- Riyade in each language: 200, `<html lang dir>` (ar: rtl), its own canonical, "Riyade" as the one `h1`, and no
  `SoftwareApplication`, offer or price in its structured data.

Both were checked locally by pointing tsxmr.com at a local server: the release build passes them, and `5f666ea`'s
build fails them.

**Live verification** (GitHub runners; this container cannot reach tsxmr.com):
- `ops/verify-production` push, run `39377112842` (`verify-production.yml`; evidence on `ci-evidence` under
  `evidence/production/5a0105079eb600f585911228afc77a20f3787c26-39377112842`):
  - `verify-production.mjs` against the branch's build: **25/25**. TLS, redirects, security headers equal
    `_headers`, every one of the 83 files byte-for-byte, 63 pages' canonicals, no tracker or edge rewriting, the
    404s, the 42-URL sitemap equal to the build's, Riyade in three languages, email DNS;
  - the public suite against tsxmr.com: **172/172** (Chromium), no retry.
- `ops/verify-preview` in production mode, `verify/target.env` set to `5aa8322` (tooling commit `57010fb`), run
  `39377118688` (evidence `evidence/preview/5aa8322-39377118688` on `ci-evidence`):
  - `verify-production.mjs` against the exact commit's build: **25/25**. This is the deployed-commit proof: every
    built file, hashed bundles included, is served byte-for-byte;
  - WebKit (iPhone 17, iPhone SE 3rd gen, desktop Safari profiles): **27/27**;
  - the public suite against tsxmr.com (Chromium), with the Riyade tests in EN/FR/AR: **172/172**.
- `verify-not-found` (the 404 behaviour), run `39377113011`: success.

These cover:
- the three Riyade pages, language and direction, head, Products order and the home row's hover room;
- language switching between them;
- Home, Products and the footer;
- that Dukan ERP's pages, wording and documentation link are unchanged (byte identity with the build, whose Dukan ERP
  pages equal production's previous build except the footer);
- the 42-URL sitemap.

This is browser automation, not a physical iPhone.

**Outcome:** no regression found; the deployment stands.

**Known limitation of the verifier (recorded, not changed).**
- `verify-production.mjs` compares `sitemap.xml` byte-for-byte. Each `<lastmod>` is the build date, so a re-run on a
  later UTC day than the deployment fails that one file, as the baseline run above did.
- The fix is the one `security.txt`'s `Expires` already has: compare without the `<lastmod>` values. It is left for a
  separate change, because this release kept the existing checks as they were.

**Follow-up (separate):** the initial language and direction of a page whose language differs from the device's or the
saved language. See `docs/83` WEB-F01.

**Still open (owner settings, unchanged by this change):**
- preview branches back to None;
- the `site-redesign` preview still answering (noindex);
- `tsxmr-public.pages.dev` answers 200 without noindex. Its canonicals point to tsxmr.com.

**The integration lines carry it.** The provisioning session merged `tsx-public-site` `5aa8322` into web
`superadmin-provisioning` (`d1016d8`) and `integration/browser-test` (`0ee0b35`). This session confirmed at 07:01Z that
both contain `5aa8322`, and that Riyade's content, component, page and test files are byte-identical to it on both.
Any later deployment that affects tsxmr.com must still serve the three Riyade routes and the unchanged Dukan ERP pages;
`ops/verify-production` checks both.
