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

- **Required:** legal name, legal form, registration number, city, registered address; the support, privacy and
  security emails; the effective date; the origin, **exactly `https://tsxmr.com`**.
- **Defaults:** display name `TSX-MR`, country `Mauritania`.
- **Forbidden** (the pre-launch site links to none of them): `VITE_PORTAL_ORIGIN`, `VITE_API_BASE`,
  `VITE_ADMIN_SITE_ORIGIN`, `VITE_APPLE_APP_STORE_URL`, `VITE_GOOGLE_PLAY_URL`.
- **Not asked for:** the deletion channel and the support commitments (hours, languages, response time). These belong
  to the PORTAL and APP_STORE gates.
- **Still refused:** test values, placeholders, legal blockers and drafts.

The PORTAL rule is the one already in force; nothing in it was loosened. A full build's refusal now names its gate.

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
- The legal notice names no "person responsible for publication". Counsel may require one: a non-blocking
  recommendation.
- Cloudflare's own security features may set a technical cookie, and the privacy text says so conditionally.
- **Counsel review of the pre-launch texts is recommended but is not a gate condition**, as the brief defines the gate.

## 3. What TSX-MR still has to give (PUBLIC_WEBSITE)

The production public build was run (CI run on `0288d8a`) and refused for exactly these 16 reasons.

**The facts:**

- **Origin:** `VITE_PUBLIC_SITE_ORIGIN=https://tsxmr.com` (known; set it in Cloudflare).
- **Identity:** legal name, legal form, registration number, city, registered address.
- **Mailboxes:** support, privacy and security email addresses, which must exist.
- **Effective date:** the date the approved texts take effect.

**The approval:** the six pre-launch legal texts — privacy, terms, account deletion, privacy choices, legal notice and
security. TSX-MR changes each `status: 'draft'` to `'approved'` (and its version to `1.0`) in `legal-prelaunch.ts`.
No session does that on TSX-MR's behalf.

**Cloudflare Pages:** as `docs/95` §3–§4, with the build command **`npm ci && npm run build:public-release`** and
`VITE_SITE_SURFACE=public`.

## 4. Verification (CI run on `0288d8a`, see `docs/95` for the earlier runs)

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
