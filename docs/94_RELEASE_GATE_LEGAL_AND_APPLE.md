# 94 — Release gate: internal TestFlight, external TestFlight, App Store (legal and privacy view)

> 2026-10-16, CLAUDE-B, at backend `dc53129`, mobile `6609574`, website `8bf6f65`. This adds the legal, privacy and
> Apple-submission conditions to `docs/77` §7; it does not replace it. **These are not compliance statements**: a GO
> means "nothing found by this phase blocks it", never "Apple compliant". Nothing has been deployed, published,
> uploaded or submitted.

## Verdicts

| Release | Verdict | What stands between it and GO |
| --- | --- | --- |
| **Internal TestFlight** (the team's own testers, no Apple review) | **NO-GO today; code ready** | the docs/77 items O-A0 (Apple Developer membership for TSX-MR), O-A4 (EAS project link and credentials), O-A6 (an https staging API); plus `EXPO_PUBLIC_LEGAL_ORIGIN` as an EAS variable — a release build is now refused without it (any https origin serving the website's preview build is enough for internal testing). O-A3 is asked on every upload. No legal text needs to be approved for internal testing |
| **External TestFlight** (Beta App Review) | **NO-GO** | everything above; the website published on its domain with the six texts **approved by TSX-MR** (§2 of docs/93 resolved, at least `legal_review`, `processors`, `privacy_law`, `retention_period`) — preview values are not acceptable for outside testers; O-A7: a deletion channel live, so a reviewer can complete deletion; the demo business on staging (docs/91 §5); O-A1 icon and splash; docs/81 T6.2–T6.5 on a device |
| **App Store** | **NO-GO** | everything above; a production website build that passes its release guard (today it lists **33 reasons**: 15 missing inputs, 12 legal blockers, 6 drafts); the App Privacy answers (docs/89) approved and checked against the built archive's privacy manifest (L-8); L-1 (in-app terms and the access/payment section); L-2 (EXIF) before answering "no location"; F02 (erasure for people who cannot sign in); O-A2 iPad; the docs/77 App Store items (penetration test O-C4, incident response, backup retention and custody, the deployment window) |

## 1. Checks this phase proved without a device

| Check | Evidence |
| --- | --- |
| Every required public page exists at a stable address in EN/FR/AR, needs no sign-in, asks the API nothing, has one heading, the right language and direction | `test/legal-pages.test.tsx`; 126 screenshots (§3) |
| Every legal page shows its version, effective date, a draft label and links to all the others; the footer lists them on public and signed-in pages | same |
| TSX-MR is named as operator on privacy, terms and the legal notice; no email address or phone number is written into any text (they come from inputs) | same |
| A production build refuses placeholders, localhost and non-https origins, missing inputs, legal blockers and drafts; preview and development are unaffected | `test/site-config.test.ts`; the production build run (33 reasons) |
| The app opens only the four approved https pages, in the phone's browser, at exact addresses; every other address stays refused | `lib/legal-links.test.ts`, `__tests__/no-browser.test.tsx`, `lib/access-boundary.test.ts` |
| Deletion stays reachable — also for a login with no branch; no button near it is a price, payment, subscription or trial | `__tests__/legal-pages.test.tsx`, `lib/navigation/entry.test.ts` |
| A lost answer during deletion is never shown as "deleted" | `__tests__/account-delete-poll.test.tsx` |
| No trial-claim or resend action, price, payment or subscription call to action in the mobile app; the trial card is display-only | the boundary test and the bundle audit on fresh web and iOS exports (PASS) |
| URLs are production-configurable, never hard-coded | `EXPO_PUBLIC_LEGAL_ORIGIN`, `VITE_PUBLIC_SITE_ORIGIN`; the audit allows only the configured origin |
| No secret in the website bundle; no personal data in static pages | `scripts/audit-bundle.mjs` PASS; the text test |
| Unused permissions removed; purpose strings in three languages | introspect (docs/90 §1) |

## 2. Not verified

- **No device test of anything in this phase** (docs/81 T6.2–T6.5 all NOT DEVICE VERIFIED). Safari opening the pages,
  the FR/AR permission prompts and the absence of microphone/Face ID prompts are proved by configuration only.
- **No built iOS archive** (no EAS build): the merged privacy manifest and the final Info.plist are not inspected.
- The Swift/ObjC of native modules was not audited line by line.
- Playwright: the screenshot script here (status, heading, language, direction, overflow) and the website CI's
  `e2e/site.spec.ts` over every public route (green on `8bf6f65`). Accessibility was checked by the rendered
  tests (one h1, semantic sections, 44 px touch targets, keyboard-reachable links); no automated axe/contrast tool ran.
- No legal review of any text. No provider is enabled; email and WhatsApp delivery were not exercised.
- Expo Doctor: 19/21; the two failing checks need `exp.host`, which this container cannot reach.

## 3. Screenshots

126 PNGs: the seven public pages × EN/FR/AR × phone (390) and desktop (1280) × light and dark (84), and the seven
`/in-app/` pages × EN/FR/AR × phone × light and dark (42). Taken from the preview build (test values shown, marked).
Delivered to the owner with the session's report; kept outside the repositories by rule.
