# 93 — Owner inputs and legal decisions (the one list TSX-MR fills in)

> 2026-10-16, CLAUDE-B. **Every item here is a production blocker until TSX-MR answers it.** Nothing below was guessed:
> a blank stays blank, and the website's production build refuses while any item in §1–§3 is open
> (`src/config/schema.ts` `releaseProblems`, run by `vite.config.ts`). The preview build shows marked test values.
> Where to put each answer is in the "Goes into" column. No answer here is a secret: secrets go to the hosts'
> secret stores (docs/78), never into this repository.

## 1. Facts about TSX-MR (website build inputs)

| # | Fact | Goes into | Required for production |
| --- | --- | --- | --- |
| O-L1 | Public website origin (the domain) | `VITE_PUBLIC_SITE_ORIGIN`; the app's `EXPO_PUBLIC_LEGAL_ORIGIN` (same origin) | yes |
| O-L2 | API base URL | `VITE_API_BASE`; the app's `EXPO_PUBLIC_API_ORIGIN` | yes |
| O-L3 | Separate Super Admin origin, if any | `VITE_ADMIN_SITE_ORIGIN` | no |
| O-L4 | Public organisation name (today "TSX-MR") | `VITE_ORGANIZATION_DISPLAY_NAME` | yes (has a default) |
| O-L5 | Full registered legal name | `VITE_ORGANIZATION_LEGAL_NAME` | yes |
| O-L6 | Legal form | `VITE_ORGANIZATION_LEGAL_FORM` | yes |
| O-L7 | Trade-register number | `VITE_ORGANIZATION_REGISTRATION_NUMBER` | yes |
| O-L8 | Country, city, registered street address | `VITE_ORGANIZATION_COUNTRY`, `_CITY`, `_ADDRESS` | yes (country has a default) |
| O-L9 | Public telephone | `VITE_ORGANIZATION_PHONE` | no |
| O-L10 | Support, privacy, security and commercial email addresses | `VITE_SUPPORT_EMAIL`, `VITE_PRIVACY_EMAIL`, `VITE_SECURITY_EMAIL`, `VITE_COMMERCIAL_EMAIL` | support, privacy, security: yes |
| O-L11 | Support hours (days, hours, time zone), languages, response time — as TSX-MR commits to them | `VITE_SUPPORT_HOURS`, `VITE_SUPPORT_LANGUAGES`, `VITE_SUPPORT_RESPONSE_TIME` | yes |
| O-L12 | Support WhatsApp number | `VITE_SUPPORT_WHATSAPP` | no |
| O-L13 | The account-deletion channel, once configured **and tested** in production (today only `whatsapp` exists) | `VITE_ACCOUNT_DELETION_CHANNEL` | yes |
| O-L14 | The effective date of the approved texts | `VITE_LEGAL_EFFECTIVE_DATE` | yes |
| O-L15 | App Store / Google Play listing addresses, once published | `VITE_APPLE_APP_STORE_URL`, `VITE_GOOGLE_PLAY_URL` | no |
| O-L16 | Tax identifier and legal representative | not yet an input; add one if counsel says the legal notice must show them | ask counsel |

## 2. Legal decisions (blockers in the texts)

Each is a `[[blocker:id]]` token in a published text; a production build lists it until the sentence is rewritten.

| Blocker | The question | Where it appears |
| --- | --- | --- |
| `legal_review` | A legal adviser reviews and approves the privacy policy, terms, deletion page, privacy choices, legal notice and security page | all |
| `privacy_law` | Which data-protection law applies; the legal bases; the rights it gives; the response time; the authority to complain to | privacy choices, privacy |
| `retention_period` | The legal retention period for business and accounting records; a retention schedule for codes, sessions, logs and imports (none exists, F12) | privacy, deletion |
| `backup_retention` | How long backups are kept, and where (the script keeps 14 local dumps) | privacy, deletion |
| `sealed_history` | Whether the sealed audit trail and append-only records may keep names written into them | privacy, deletion |
| `processors` | The hosting, database, backup, log and email providers, once contracted | privacy, legal notice |
| `international_transfer` | Whether any processing happens outside Mauritania | privacy |
| `governing_law` | Governing law, courts, dispute resolution | terms |
| `liability` | Limitation of liability, service levels | terms |
| `indemnity` | Whether a business indemnifies TSX-MR, and for what — or remove the clause | terms |
| `refund_policy` | The refund policy for access paid outside the app (the system refunds nothing today) | terms |
| `publisher` | Whether the website must name a person responsible for publication, and who | legal notice |

And the approval itself: six documents are marked `status: 'draft'` and labelled **DRAFT — REQUIRES TSX-MR APPROVAL**
(privacy, terms, account deletion, privacy choices, legal notice, security). TSX-MR's approval of each final text is
what turns it to `approved`; no session may do that on TSX-MR's behalf.

## 3. Product and engineering decisions found by this phase

| # | Decision | Options | What it blocks |
| --- | --- | --- | --- |
| O-A7 / F01 | **Account deletion cannot complete in production**: codes go only by WhatsApp, which is off; email never carries a deletion code, so an email-only login cannot delete at all (D110) | (a) enable and prove WhatsApp; (b) also allow an email deletion code (backend + app change); (c) both | external TestFlight review risk; App Store (5.1.1(v)) |
| F02 | A person who can no longer sign in (deactivated staff, cancelled invitee, a business the platform cancelled) has no erasure path | (a) a support-handled, verified request procedure; (b) a platform-side erasure tool; (c) state the limit in the policy | App Store; privacy law |
| L-1 | The in-app **Terms** page (opened from the app) describes how access is priced and paid outside the app, with no link or button | (a) keep — a legal text, not a call to action; (b) an in-app terms variant without the access-and-payment section | App Review risk (3.1.1) |
| L-2 / F13 | Receipt photos keep their EXIF metadata (possibly GPS) | (a) strip metadata on upload (recommended; a backend change); (b) declare it in the policy and App Privacy | the App Privacy "Location" answer |
| L-3 / M-DEL-3 | After a completed deletion the phone keeps the deleted person's unsent queue, drafts, sealed customer numbers, cached receipt PDFs and picked files | (a) clear them on completion, and warn before deleting when unsent work exists; (b) disclose it | privacy accuracy |
| L-4 / F09 | Imported spreadsheet rows are kept for ever and never de-identified | (a) keep with the import as evidence; (b) de-identify on closure; (c) purge after a period | retention schedule |
| L-5 / F15 | Request logs hold the IP, user agent and IMEIs or serials in URL paths | (a) scrub identifiers from logged paths; (b) disclose and set a log retention | privacy accuracy |
| L-6 | App Privacy: declare data a shop records about **its own customers** | declare (proposed) or not | docs/89 |
| L-7 | Drop the photo-library permission (PHPicker needs none on iOS 16.4+) | after a device check | — |
| L-8 | Declare the app's own privacy manifest (`ios.privacyManifests`) | recommended | App Store |
| L-9 | Remove `NSAllowsLocalNetworking` from the store build | recommended | — |
| L-10 | Security page: a safe-harbour sentence for good-faith research | write with counsel, or leave out | security page (`legal_review`) |
| L-11 | Declare server request logs as "Other Diagnostic Data" in App Privacy | counsel | docs/89 |
| F05, F06, F10 | Names in sealed subscription events, seat reasons, audit JSON and others' notifications | accept and disclose (the texts now say so), or de-identify where not sealed | privacy accuracy |
| O-A2, O-A3 | iPad; export compliance (`usesNonExemptEncryption`) | unchanged from docs/77 | App Store / every upload |

## 4. Decided by the owner's brief of 2026-10-16 (recorded in docs/21)

- **O-A5 — settled for the legal pages only.** The app may open, in the phone's own browser, exactly four pages
  (privacy policy, terms, support, how account deletion works) at their in-app addresses on the configured https
  website origin. Every other address stays refused; nothing in the app becomes a path to a price, an application or
  a sign-in. The trial card stays display-only.
- No non-essential cookie, so no consent banner and no `/cookies` page.
