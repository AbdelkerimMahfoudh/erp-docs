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
  - `contact@`, `support@`, `privacy@` and `security@tsxmr.com`.
- **Never defaulted:** the correspondence address, the effective date and the telephone numbers.
- **Forbidden** (the pre-launch site links to none of them): `VITE_PORTAL_ORIGIN`, `VITE_API_BASE`,
  `VITE_ADMIN_SITE_ORIGIN`, `VITE_APPLE_APP_STORE_URL`, `VITE_GOOGLE_PLAY_URL`.
- **Not asked for:** the deletion channel and the support commitments (hours, languages, response time). These belong
  to the PORTAL and APP_STORE gates.
- **Still refused:** test values, placeholders, legal blockers and drafts.

The PORTAL rule is the one already in force; nothing in it was loosened. It still requires a legal form and an RCCM
(**owner decision, open:** whether the portal may launch under an individual operator; until then, it cannot). A full
build's refusal now names its gate.

## 2. The pre-launch website

**Content.** These live in `src/content/prelaunch.ts` and `legal-prelaunch.ts`, in EN, FR and AR; RTL is unchanged.

- **"Coming soon":** Dukan ERP is presented as "Coming soon — not yet open for public registration" on the home and
  Dukan ERP pages.
- **Nothing on sale:** no subscription section, no prices, no trial, no registration or sign-in link. The "Launch"
  section says terms will be published before launch and points to the contact page.
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

*Rewritten 2026-10-17 (CLAUDE, `0516a9c`). Before, it was 16 reasons on `0288d8a`, with legal form and RCCM among them.*

`npm ci && npm run build:public-release` was run on `0516a9c` with the Cloudflare values of §6. It **refused for exactly
8 reasons**, and these are the only three blockers left:

1. **The correspondence address:** `VITE_ORGANIZATION_ADDRESS`, which TSX-MR has not given yet. Nothing is invented in
   its place.
2. **The effective date:** `VITE_LEGAL_EFFECTIVE_DATE`, set to the actual deployment date.
3. **The approval of the six texts:** privacy, terms, account deletion, privacy choices, legal notice and security.
   They are in `docs/97`, in EN/FR/AR, at version 0.2. TSX-MR changes each `status: 'draft'` to `'approved'` (and its
   version to `1.0`) in `legal-prelaunch.ts`. No session does that on TSX-MR's behalf.

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
| `VITE_ORGANIZATION_ADDRESS` | the correspondence address, **once TSX-MR gives it** |
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
