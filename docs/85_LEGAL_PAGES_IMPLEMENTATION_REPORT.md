# 85 — Legal pages, privacy disclosure and Apple-submission readiness: implementation report

> Phase of 2026-10-16 (CLAUDE-B, 12:36Z →), the owner's brief "legal pages, privacy disclosure and Apple submission
> readiness" with "check the code line per line and verify everything is ready for prod". Authorised: source code,
> website content, tests and documentation. **Not done, by instruction:** publishing, DNS, deployment, production
> credentials, providers, live data, TestFlight or App Store upload, accepting legal wording for TSX-MR.

Read with: docs/86 (data inventory), 87 (processors), 88 (retention and deletion), 89 (App Privacy worksheet),
90 (permissions, SDKs, network), 91 (App Store Connect metadata), 92 (App Review notes), 93 (owner inputs and legal
decisions), 94 (release gate).

## 1. Commits

| Repository | Branch | Commits | From → to |
| --- | --- | --- | --- |
| erp-backend | `reports-export` | `6ed5fc8` payment audit inside the transaction, replay reported (R-1, R-2) · `dc53129` deletion de-identification fixes (F03, F04, F07, F11, F17) | `06a0db7` → `dc53129` |
| erp-mobile | `reports-export` | `b6adc48` legal pages in the phone's browser, deletion reachable without a branch, poll fix, permissions and FR/AR purpose strings · `6609574` closure copy no longer claims every note goes | `b23badb` → `6609574` |
| erp-control-web | `tsx-public-site` (not merged; `main` `0417bfe` untouched) | `8bf6f65` legal, privacy-choice, security and support pages, in-app variants, release guard | `0eedfaa` → `8bf6f65` |
| erp-docs | `master` | this report and docs/86–94, docs/21, docs/81, session log, handoff | `6e2a462` → the commit carrying this file |

No schema change, no migration, no database touched, nothing deployed.

## 2. Pages (website)

| Route | Content | Status |
| --- | --- | --- |
| `/privacy` | privacy policy v1.0, reconciled with the code inventory | DRAFT |
| `/terms` | terms v1.2, rewritten from the enforced rules | DRAFT |
| `/account-deletion` | how deletion works, what is removed and kept | DRAFT |
| `/privacy-choices` | what a person or a business can do themselves, and what needs a request | DRAFT, new |
| `/legal` | legal notice: operator, publisher, hosting, contact, intellectual property | DRAFT, new |
| `/security` | vulnerability reporting, rules, what happens next; no bounty | DRAFT, new |
| `/support` | support answers, incl. access, trial, lost phone, imports, scanner, reports, security, service status | inputs required |
| `/fr/…`, `/ar/…` | every page in French and Arabic (Arabic right-to-left) | |
| `/in-app/…` (×3 languages) | the seven pages for the mobile app: same text, language links only, no sign-in/application/price/site navigation, never indexed, out of the sitemap | |

No `/cookies` page and no consent banner: the site sets no non-essential cookie. Pages print cleanly (print stylesheet).

## 3. Links

- Website: the footer's legal column (privacy, privacy choices, terms, security, legal notice, support, deletion) on
  public and signed-in pages; a "related pages" block at the foot of every legal page; security.txt from
  `VITE_SECURITY_EMAIL`. Link audit: 68 pages, 3 255 links, 0 broken.
- App (opened in the phone's browser, only these four, docs/90 §6): sign in · More → Your account · Delete account ·
  the closed-access screen (outside the display-only trial card) · the no-branch screen (with a new "Your account"
  button).

## 4. Tests and gates (final heads)

| Repository | Result |
| --- | --- |
| erp-backend | tsc clean; full suite 249 suites passed (1 skipped), **4 512 tests passed**, 24 skipped |
| erp-mobile | tsc clean; lint 0 errors (29 warnings, all pre-existing, cap 40); **115 pure test files** pass; **285 rendered tests** (30 suites) pass; release-config check refuses without the legal origin and passes with it; fresh web and iOS exports pass the bundle audit (also with a realistic origin); Expo Doctor 19/21 (2 need the network) |
| erp-control-web | typecheck clean; **vitest 376/376** (19 files); build:preview 66 pages; link audit 0 broken; bundle audit PASS; production build refused with 33 reasons, as intended. No lint script exists in this repository |

New tests: website `test/legal-pages.test.tsx` and release-guard cases; mobile `lib/legal-links.test.ts`,
`__tests__/legal-pages.test.tsx`, `__tests__/account-delete-poll.test.tsx`, cases in `__tests__/no-browser.test.tsx`,
`lib/navigation/entry.test.ts`, `lib/audit-bundle.test.ts`, `lib/release-origin.test.ts`,
`lib/access-boundary.test.ts`; backend closure, notice and payment specs.

## 5. Findings

### Fixed in this phase

| Id | What was wrong | Fix |
| --- | --- | --- |
| R-1 | the subscription payment's audit row was written after commit, and not at all on a retry | written in the same transaction (`6ed5fc8`) |
| R-2 | a replayed payment looked new to the console | `applied: false` returned (`6ed5fc8`) |
| F03 | closure left payer numbers and request hashes | cleared (`dc53129`) |
| F04 | a login's deletion de-identified another business's registration attempts | scoped to its company or none (`dc53129`) |
| F07 | a completed deletion kept the request IP | forgotten (`dc53129`) |
| F11 | a closure left earlier-deleted logins' email and phone | de-identified (`dc53129`) |
| F17 | the closing notice could go to an unverified number | verified numbers only (`dc53129`) |
| M-DEL-1 | the deletion screen reported "deleted" on any error while following a deletion | only a 401 means done (`b6adc48`) |
| M-DEL-2 | a login with no branch could not reach its account, so could not delete | guard exemption and a button (`b6adc48`) |
| M-PERM | unused microphone and Face ID purpose strings; RECORD_AUDIO, SYSTEM_ALERT_WINDOW, WRITE_EXTERNAL_STORAGE on Android; English-only purpose strings | removed / blocked / translated (`b6adc48`) |
| F08 (text) | the app and the website said a closed business loses "its notes" | both now say which notes go and that the others stay (`6609574`, `8bf6f65`) |
| F13, F15, F09, F10, F12 (text) | the privacy draft said "no location", omitted request logs, imports, notifications and the absence of purge | stated as they are (`8bf6f65`) |

### Open (decisions in docs/93 §3)

F01 / O-A7 deletion channel (**blocker**); F02 erasure without sign-in (high); F05, F06, F08, F09, F10, F12 (medium);
F13, F14, F15, F16, F18–F23 (low); M-DEL-3 local data after deletion; L-1…L-11; the line-by-line review's lows R-3…R-17
(R-3 the payment dedupe also matches seat/store payments; R-4 amounts with more than two decimals; R-5 "same day" is an
exact instant; R-6 the concurrency test cannot fail; R-7 a lost refresh race revokes the winner too; R-9…R-13 MFA
try-claim and lock ordering under concurrency; R-14 an unconditional decrement; R-16 test fake fidelity — none
reproduced as a user-visible failure, all with suggested fixes in the session's review notes).

## 6. Placeholders and blockers

The production website build lists 15 missing inputs (docs/93 §1), 12 legal blockers (docs/93 §2) and 6 drafts.
No owner fact was invented anywhere: the texts read `{legalName}`, `{privacyEmail}`… from the inputs, and the preview
build shows them as marked test values.

## 7. Scope of the "line by line" check

The full per-file review of every tracked file was the previous phase (docs/82, 1 592 files, 243 findings, docs/83).
This phase re-read, line by line, every file that touches personal data, deletion, contact delivery, logs and the
app's browser boundary, plus the three commits made after that review (R-1…R-17), and every file it changed. It did
not re-review the other files.

## 8. Live data and deployment

No live data was read or changed; no shared database was touched; nothing was deployed, published, uploaded or
submitted; no DNS, credential or provider was created or changed.
