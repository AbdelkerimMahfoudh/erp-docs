# 96 — Three release gates: PUBLIC_WEBSITE, PORTAL, APP_STORE

> 2026-10-17, CLAUDE-B (local). The owner's brief of 2026-10-17 (second): the TSX-MR corporate website must be
> publishable before the Dukan ERP backend, portal, registration, payments, trial claiming and account deletion work.
> The app-production and App Store gates stay strict, the working WhatsApp deletion channel included. **Nothing was
> deployed, merged or published, and nothing changed in Cloudflare.** `VITE_PORTAL_ORIGIN` stays unset.

## 1. The gates

| Gate | What it covers | How it is enforced | Opens when |
| --- | --- | --- | --- |
| **PUBLIC_WEBSITE** | The pre-launch corporate website at `https://tsxmr.com` (`VITE_SITE_SURFACE=public`) | The production build refuses (`vite.config.ts` → `schema.ts`). `npm run build:public-release` also fails on a broken link or any portal or API code. `scripts/release-verdicts.mjs --dist --links --browser` checks the built site. | The TSX-MR facts of §3 are given; TSX-MR approves the six pre-launch texts; the build, link audit, bundle audit and browser checks pass |
| **PORTAL** | The business account and the console (a full build), and the backend behind them | The full build's refusal, unchanged. The verdict adds the backend and its channels as **not provable here**. | Every input, the API and the service's approved texts with no legal blocker; then the running backend with email and WhatsApp proven (outside this repository) |
| **APP_STORE** | The Dukan ERP app in the App Store | The verdict (`gates.ts`): the service texts approved with no blocker and `VITE_ACCOUNT_DELETION_CHANNEL=whatsapp`; plus the WhatsApp deletion proof, the mobile release check and `docs/94` as **not provable here**. The mobile release check itself is unchanged. | WhatsApp deletion works end to end in production, the service texts are approved, and every App Store gate passes |

Rules of the PUBLIC_WEBSITE gate (`schema.ts`):

- **Required:** the operator type, the legal operator's name, the person responsible for publication, city,
  correspondence address; the contact, support, privacy and security emails; the effective date; the origin,
  **exactly `https://tsxmr.com`**.
- **The operator type** (`VITE_OPERATOR_TYPE`, §6): `individual` (the default, and TSX-MR today) or `company`.
  - An individual has **no legal form and no RCCM**, so the gate does not ask for them, and it **refuses** them if
    they are given: a value there would claim a company that does not exist.
  - Only `company` requires them, once a company is formed.
  - An unknown type fails closed: it is malformed, and the company facts are then required.
- **Defaults** (facts TSX-MR gave, 2026-10-17, so nothing is typed in Cloudflare):
  - display name `TSX-MR`; operator type `individual`;
  - operator and person responsible for publication `Abdel Kerim Taleb Ould Sidi`;
  - city `Nouakchott`, country `Mauritania`;
  - the correspondence address `Tevragh Zeina, Nouakchott-Ouest` (Arabic `تفرغ زينة، نواكشوط الغربية`; §6). This
    applies to an individual only: a company gives its own registered name and address;
  - `contact@`, `support@`, `privacy@` and `security@tsxmr.com`.
- **Never defaulted:** the effective date and the telephone numbers.
- **Forbidden** (the pre-launch site links to none of them): `VITE_PORTAL_ORIGIN`, `VITE_API_BASE`,
  `VITE_ADMIN_SITE_ORIGIN`, `VITE_APPLE_APP_STORE_URL`, `VITE_GOOGLE_PLAY_URL`.
- **Not asked for:** the deletion channel and the support commitments (hours, languages, response time). These belong
  to the PORTAL and APP_STORE gates.
- **Still refused:** test values, placeholders, legal blockers and drafts.

The PORTAL rule now has an individual mode (§8, `ad41e4c`): no legal form or RCCM, plus a registration question that
keeps the portal closed until counsel answers it. Company mode is unchanged. A full build's refusal names its gate.

## 2. The pre-launch website

**Content.** These live in `src/content/prelaunch.ts` and `legal-prelaunch.ts`, in EN, FR and AR; RTL is unchanged.

- **"Coming soon":** Dukan ERP is presented as "Coming soon — not yet open for public registration" on the home and
  Dukan ERP pages.
- **Nothing on sale:** no subscription section, no prices, no trial, no registration or sign-in link. The "Launch"
  section says terms will be published before launch and points to the contact page.
  - **Exception (D201, 2026-10-18):** the Dukan ERP interactive illustration may show its labelled fictional MRU
    amounts, and Bankily and Sedad as plain-text examples. Nowhere else; no subscription price anywhere. (In
    production since 2026-10-19: `tsx-public-site` `1b9c448`, then `bf62a72`; `docs/95`, the promotion section.)
- **Pre-launch versions** of privacy, terms (now "terms of use of this website"), account deletion, privacy choices,
  legal notice, security, support, about and contact.
  - They describe what **this website** does, from its code: no account, no form, no request to any service, no
    cookie of its own, no analytics, the language and display choice in the browser, delivery by Cloudflare.
  - The processes that do not work yet are pre-launch information. For example, account deletion: "there are no
    public accounts to delete; deletion will be from inside the app, explained here before it opens."
- **Approval:** all six legal texts are **DRAFT — REQUIRES TSX-MR APPROVAL**, with their own pre-launch label.
- **The service's texts are unchanged:** `legal-*.ts` and `pages.ts` stay as they were for the portal and the app.

**Pages.** The legal and support pages, the `/in-app/…` pages, and the home, about, products, Dukan ERP and contact
pages; 57 prerendered in all. `/apply`, `/login`, `/application-status`, `/account` and `/admin` are 404, and none of
their code is in the bundle.

**Decided here, for the owner to confirm with the approval:**

- The pre-launch privacy policy states no legal basis or statutory period, and no right beyond asking to see, correct
  or delete.
- **Settled 2026-10-17:** the legal notice names the person responsible for publication, Abdel Kerim Taleb Ould Sidi,
  as TSX-MR gave it (§6).
- Cloudflare's own security features may set a technical cookie, and the privacy text says so conditionally.
- **Counsel review of the pre-launch texts is recommended but is not a gate condition**, as the brief defines the gate.

## 3. What TSX-MR still has to give (PUBLIC_WEBSITE)

*Rewritten 2026-10-17 (CLAUDE, `ad41e4c`). It was 8 reasons on `0516a9c`, and 16 on `0288d8a`.*

The correspondence address is now given (D184). `npm ci && npm run build:public-release` was run on `ad41e4c` with
the Cloudflare values of §6. It **refused for exactly 7 reasons**. These are the only two blockers left, and both are
TSX-MR's:

1. **The effective date:** `VITE_LEGAL_EFFECTIVE_DATE`, the **actual publication date**, set in Cloudflare on the day
   of deployment. It is never a commit date. None is confirmed, so none is set.
2. **The approval of the six texts:** privacy, terms, account deletion, privacy choices, legal notice and security.
   - They are in `docs/97`, in EN/FR/AR, at version 0.3, with the changes, the commitments to confirm and the open legal
     questions.
   - On TSX-MR's explicit approval, each `status: 'draft'` becomes `'approved'` and its version `1.0`, in
     `legal-prelaunch.ts`.
   - No session does that on its own.

Nothing else in this repository stops the public website. A production dry run with both blockers simulated
(scratch copy only; §9) builds, prerenders and passes every audit.

**Cloudflare Pages:** as `docs/95` §3–§4, with the build command **`npm ci && npm run build:public-release`** and the
variables of §6.

## 4. Verification (CI run on `0288d8a`; superseded by §7 for `0516a9c`)

The figures are recorded in the session log and the handoff:

- Vitest; Playwright for the full site and **the public site:** every page in EN/FR/AR at 375 px and desktop, 320 px
  overflow, axe WCAG 2.1 AA, no request to another origin, no form, no account link, headers, and 404 on every portal
  address.
- Links for both builds; bundle audits (`--public`: no portal or API code); gitleaks.
- The three verdicts recorded in `release-verdicts.txt`.
- Screenshots: `ci-evidence/evidence/<sha>/public/` (72 pages, 6 contact sheets).

## 5. Not done

Deployment, merging, Cloudflare, DNS, the approval of any text, counsel review, and any change to the app's or the
backend's checks.

## 6. Who operates the website, and how to reach TSX-MR (2026-10-17, CLAUDE, `0516a9c`)

**The facts TSX-MR gave:**

- **TSX-MR** is the trading and project name. It is **not incorporated** as a separate company and has no legal form
  and no RCCM.
- It is operated by **Abdel Kerim Taleb Ould Sidi**, an individual (natural person). The same person is responsible
  for publication.
- Nouakchott, Mauritania.
- **Dukan ERP** is a product operated under the TSX-MR name. It is coming soon: no public registration, sign-in,
  subscription, price or trial.

**What the site says, in EN/FR/AR:**

- One `{operatorStatus}` sentence per language, for example "TSX-MR is a project and trading name. It is not a
  separately incorporated company: it is operated by Abdel Kerim Taleb Ould Sidi, an individual."
- It appears in the legal notice, privacy policy, terms, about page and footer. It uses no gendered pronoun or
  agreement.
- The operator's details on the legal notice, contact and about pages show:
  - name, operator, status ("no legal form, no RCCM");
  - the person responsible for publication;
  - the correspondence address;
  - the telephone numbers.

  No legal-form or RCCM row is shown.
- **Structured data:** the Organization has no `legalName`. The `WebSite` publisher is a `Person`.
- **Not published:** passport or identity-card numbers, any private number, or any other personal detail.

**Contacts:**

| What | Where it comes from |
| --- | --- |
| General enquiries `contact@tsxmr.com` | `VITE_CONTACT_EMAIL` (defaults to it) |
| Support `support@`, privacy `privacy@`, security `security@tsxmr.com` | `VITE_SUPPORT_EMAIL`, `VITE_PRIVACY_EMAIL`, `VITE_SECURITY_EMAIL` (default to them) |
| Public telephone **+222 36 96 38 39** and **+222 37 67 68 27** | `VITE_ORGANIZATION_PHONE`, a comma-separated list. **Never hardcoded:** they are temporary and may change, so the variable is changed and the site rebuilt. Shown as tap-to-call links, left to right inside Arabic. |
| WhatsApp | **Neither number is labelled WhatsApp** until TSX-MR confirms which one is. `VITE_SUPPORT_WHATSAPP` stays unset, and the site then shows no WhatsApp line. |

The three mailboxes, and `contact@`, must exist and be read before publication.

**Cloudflare Production variables, PUBLIC_WEBSITE** (all public by nature; none is a secret):

| Variable | Value |
| --- | --- |
| `VITE_SITE_SURFACE` | `public` |
| `VITE_PUBLIC_SITE_ORIGIN` | `https://tsxmr.com` |
| `VITE_ORGANIZATION_PHONE` | `+222 36 96 38 39, +222 37 67 68 27` |
| `VITE_ORGANIZATION_ADDRESS`, `VITE_ORGANIZATION_ADDRESS_AR` | **unset**: they default to the owner's address (§1). Set both to change it without a code change. A new Latin address with no Arabic line is shown in Latin script in Arabic. |
| `VITE_LEGAL_EFFECTIVE_DATE` | the actual deployment date, `YYYY-MM-DD` |
| `VITE_PORTAL_ORIGIN`, `VITE_API_BASE`, `VITE_ADMIN_SITE_ORIGIN`, store URLs | **unset**; the gate refuses them |
| `VITE_ORGANIZATION_LEGAL_FORM`, `VITE_ORGANIZATION_REGISTRATION_NUMBER` | **unset**; the gate refuses them for an individual |
| Everything else | unset (the defaults above) |

Should a company be formed, `VITE_OPERATOR_TYPE=company` with its legal name, legal form, RCCM and registered address
switches every text to "TSX-MR is a trading name of …".

## 7. Verification on `0516a9c` (2026-10-17, CLAUDE)

| Check | Result |
| --- | --- |
| Typecheck | clean |
| Vitest | 23 files, 423 / 423, including the new `operator-identity` and gate tests: an individual forbids legal form and RCCM; TSX-MR's facts today leave exactly the address, the date and the 6 approvals |
| Public preview build | 57 pages |
| Link audit | 58 pages, 2 703 links, 0 broken |
| Bundle audit `--public` | PASS: no portal, API or admin code |
| Playwright, public site | 82 / 82. Every page in EN/FR/AR at 375 px and desktop; 320 px overflow; axe WCAG 2.1 AA; RTL; no foreign request; security headers; 404s for the portal addresses; the new identity check in each language |
| gitleaks | history, `src` and the built site: no leaks |
| `npm ci && npm run build:public-release` | **refused**, exactly the 8 reasons of §3 |
| `release-verdicts.mjs --dist --links --browser` | PUBLIC_WEBSITE **NO-GO, 8** (the address, the date, 6 approvals; nothing in the built site). PORTAL NO-GO, 29. APP_STORE NO-GO. |
| CI run 39003461533 | green, every step; evidence on `ci-evidence` |
| Screenshots | 72 (12 pages × EN/FR/AR × 375 px and desktop) and 6 contact sheets, from a marked preview |

In the cloud container, Playwright ran on its installed Chromium through a scratch configuration outside the
repository. CI runs the repository's own configuration.

## 8. The portal under an individual operator (2026-10-17, CLAUDE, `ad41e4c`; D185)

**What the portal assumed:**
- The PORTAL gate required a legal form and an RCCM.
- The service's privacy policy said "{legalName}, {legalForm}, registered under number {registrationNumber}".
- Its legal notice said "published and operated by {legalName}, trading as {displayName}". Its Arabic made the
  operator feminine, implying a company.
- The about page was headed "Company details".
- **No payment provider is integrated.** Payments are confirmed by a platform administrator against a reference, and
  every payment row carries `providerVerified: false`. There is no tax, invoice or merchant field anywhere in the
  website.
- The backend names the operator only as "TSX-MR" (Swagger, email footers). Nothing there assumes a company, so the
  backend needs no change. It was read, not modified: the local phase holds it.

**What changed:**

| | Individual (`VITE_OPERATOR_TYPE=individual`, the default) | Company |
| --- | --- | --- |
| Legal form, RCCM | not asked for; **refused** if given | required (unchanged) |
| Legal name, registered address | default to the person and the correspondence address | required; never inherited from the person |
| Person responsible for publication | required; defaults to the operator | required |
| Extra blocker | **`operator_registration`** (below) | none |
| Texts | `{operatorStatus}`: "… operated by Abdel Kerim Taleb Ould Sidi, an individual" | "TSX-MR is a trading name of …" |

- The service's legal notice, privacy policy, terms and about page say who operates the name, in EN/FR/AR, with the
  correspondence address.
- The service's **`publisher` blocker is settled** by the owner's designation and removed from the catalogue.
- Tests cover both modes: `test/portal-operator.test.tsx` (gate rules, address, rendered pages EN/FR/AR) and
  `test/portal-operator-company.test.tsx` (company pages).

**Kept closed: `operator_registration`.** The portal sells paid access, paid to TSX-MR. Removing the company fields
does not answer whether that may be done before the operator registers (for example as an individual trader at the
RCCM, with a tax number), or what invoices and receipts must show. Mauritanian counsel answers it; a registration can
also settle it. **Paid subscriptions, payment collection and the portal stay disabled** until then. Nothing was
enabled.

**PORTAL verdict:** NO-GO, 26 reasons (it was 29):
- removed: the legal form, the RCCM, the address and `publisher`;
- added: `operator_registration`.

The other reasons stand: the API, the support commitments, the deletion channel, the date, the 11 service legal
blockers, the 6 service drafts and the 2 external conditions.

## 9. A defect found by a production dry run, and fixed (`b7b8fc2`)

No production build had ever passed, so no one had run its audit. A dry run in a scratch copy, outside the repository,
simulated both blockers: all six texts approved, and the date 2026-11-01. `build:public-release` then **failed its own
bundle audit**:

1. **The API client was in the public bundle**, with its development address `127.0.0.1:3010`. The full Dukan ERP
   page (its price table calls `platform/plan`) and the Apply form came with it. The router picked them at runtime, so
   the bundler kept them. The preview audit allowed `127.0.0.1:3010`, so CI never saw it.
2. **14 test values in production:** the page read its inputs through `readInputs`, so the whole input table shipped,
   preview values included.

**The fix:**
- A public build aliases the API client, the price table and the Apply page to stubs. It already did this for the
  protected areas.
- The inputs are computed at build time and inlined (`__SITE_INPUTS__`).
- `audit-bundle --public` now refuses any API route or private address, in a preview too. It reports both findings on
  the old build and passes on the new one.
- Source rules pin both points.

**The dry run after the fix:**
- the release build passes: 57 pages, 2 709 links with 0 broken, 0 test values, bundle audit PASS;
- served locally, `/`, `/privacy`, `/terms`, `/contact`, `/legal`, `/security`, `/account-deletion`, `/privacy-choices`,
  `/fr/…`, `/ar/…`, `/sitemap.xml`, `/robots.txt` and `/.well-known/security.txt` answer 200;
- `/apply`, `/login`, `/account` and `/admin` answer 404;
- canonical URLs are `https://tsxmr.com/…`, with `index, follow` (`noindex` only on `/in-app/…` and 404);
- no preview banner, draft label, test value, price, "Sign in" or apply link appears on any of the 58 pages;
- CSP, HSTS, `X-Frame-Options: DENY` and Permissions-Policy are sent;
- the structured data names the Organization with its address, and the publisher as a `Person`.

That dry run is evidence only. Nothing from it was committed.

## 10. Verification on `ad41e4c` and `b5c0328` (2026-10-17, CLAUDE)

| Check | Result |
| --- | --- |
| Typecheck | clean |
| Vitest | 26 files, 440 / 440 (both operator modes, the address in three languages, the stub rules, the Arabic host isolate) |
| Full preview (CI's `VITE_API_BASE`) | links 68 pages / 3 258, 0 broken; bundle audit PASS; Playwright **126 / 126** |
| Public preview (the §6 values) | links 58 pages / 2 709, 0 broken; bundle audit `--public` PASS (tightened); Playwright **82 / 82**: every page EN/FR/AR at 375 px and desktop, 320 px, axe WCAG 2.1 AA, RTL, no foreign request, headers, portal 404s, the identity and address check |
| `npm ci && npm run build:public-release` | **refused**, 7 reasons (§3) |
| Full production build | **refused** (gate PORTAL) |
| Verdicts (`--dist --links --browser`) | PUBLIC_WEBSITE NO-GO 7 · PORTAL NO-GO 26 · APP_STORE NO-GO 21 |
| gitleaks | history, `src` and the built site: no leaks |
| Production dry run (scratch; §9) | PASS |
| CI | run 39006226561 on `ad41e4c` green; run 39006514696 on `b5c0328` green (every step, evidence on `ci-evidence`) |

`b5c0328` fixes one thing the Arabic screenshot showed: in Arabic, the host's Latin address moved its "101". The
address is now a left-to-right isolate.

A first local full-site run failed 70 tests because I had left out CI's `VITE_API_BASE` (CSP refusals). It was not a
code fault: with CI's value, 126 / 126.

## 11. Deployment and rollback plan (for the owner; nothing done)

**Before:**
1. TSX-MR approves the six texts (`docs/97`). A session commits the approval flags; CI must be green.
2. TSX-MR confirms that `contact@`, `support@`, `privacy@` and `security@tsxmr.com` exist and are read.
3. TSX-MR fixes the publication day.

**Deploy, only on the owner's explicit go-ahead:**
1. Fast-forward `main` to `tsx-public-site`. It is ahead with no divergence, so no merge commit is needed.
2. Create the Cloudflare Pages project (`docs/95` §3):
   - build `npm ci && npm run build:public-release`, output `dist`, Node 22;
   - preview deployments off;
   - the variables of §6, with `VITE_LEGAL_EFFECTIVE_DATE` set to that day.
3. The first build must pass. If it is refused, read the reasons it prints; nothing is published.
4. Add the custom domain `tsxmr.com`, then `www.tsxmr.com` with the 301 rule (`docs/95` §4).
5. Run the checks of `docs/95` §4.5:
   - `/`, `/privacy`, `/terms`, `/contact`, `/fr/privacy`, `/ar/terms` → 200;
   - `/account`, `/admin`, `/apply` → 404;
   - security headers present;
   - www → apex.
6. Give Meta (WhatsApp Business) `https://tsxmr.com/privacy`, `https://tsxmr.com/terms` and
   `https://tsxmr.com/account-deletion` only once they answer 200.

**Rollback:**
- In Cloudflare Pages → Deployments, promote the previous deployment ("Rollback"); this is instant.
- Or remove the custom domain.
- A wrong text is corrected by a new commit and a redeploy. The effective date and the version change with it.
- No database or backend is involved, so a rollback touches nothing else.

## 12. Not done, by the brief

- No merge, deployment, Cloudflare, DNS, SMTP or WhatsApp change.
- No text approved; no effective date invented.
- Nothing in `erp-backend`, which the local phase holds. Nothing in `erp-mobile`.
- No payment or subscription enabled.
- **The Brevo SMTP credential once shared in chat must be replaced before production.** This session never saw or
  stored it, and gitleaks finds no credential in the website repository.

## 9. The PORTAL gate for `dukan.tsxmr.com` (2026-10-18, CLAUDE, `erp-control-web` `dukan-portal`; D202)

The portal now builds on its own: `VITE_SITE_SURFACE=portal` serves only the Owner's `/subscription` and the console
`/admin`.

**What the build makes:**
- `/` answers `302 /subscription`, and the retired `/account/*` answers `301 /subscription`;
- every response is `noindex`, and `robots.txt` is `Disallow: /`;
- no public page is prerendered (the not-found page only).

**What its production build refuses** (gate PORTAL), beside the existing inputs:
- anything but `VITE_PORTAL_ORIGIN=https://dukan.tsxmr.com`;
- anything but `VITE_PUBLIC_SITE_ORIGIN=https://tsxmr.com`;
- a `VITE_API_BASE` outside `https://api.tsxmr.com`.

The bundle audit's `--portal` mode refuses `portal.tsxmr.com`, a setup link or token, and any public page's code.

CI builds and audits it beside the full and public builds, and runs `e2e/portal.spec.ts`: EN/FR/AR at 375 px and
desktop, axe, host headers, and the confirmed claim with its CSRF token.

**Verified 2026-10-18 at `e020215`:**
- every production build refused without its inputs;
- previews with 0 broken links and the audits passing;
- Playwright full 138/138, public 148/148, portal 34/34.

`VITE_PORTAL_ORIGIN` stays unset everywhere real: no Pages project or DNS record exists for `dukan.tsxmr.com`
(`docs/101` §12).
