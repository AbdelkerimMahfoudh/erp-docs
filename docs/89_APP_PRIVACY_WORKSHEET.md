# 89 — App Privacy worksheet (App Store Connect "App Privacy")

> **DRAFT — REQUIRES TSX-MR APPROVAL.** Prepared 2026-10-16 by CLAUDE-B from the code (docs/86, docs/87, docs/90).
> Nothing here has been entered in App Store Connect. The answers are a proposal, not a declaration: TSX-MR answers
> the questionnaire, ideally with its legal adviser (O-A8). It does not claim that the app meets Apple's rules.

## 1. Tracking

| Question | Proposed answer | Evidence |
| --- | --- | --- |
| Does the app or a third party track users (link data with other companies' data for advertising, or share with data brokers)? | **No** | No advertising, analytics, attribution or data-broker SDK; no IDFA; no `NSUserTrackingUsageDescription`; every bundled privacy manifest declares `NSPrivacyTracking = false` (docs/90 §2) |
| App Tracking Transparency prompt | Not needed | as above |

## 2. Data collected

"Collected" means it leaves the phone and is kept by the service for longer than a request. Every type below is
**linked to the user's identity** (it sits in the business account) and **none is used for tracking**. The only purpose
is **App Functionality**: the service itself, including security, fraud prevention and support. There is no
Analytics, Product Personalisation, Developer Advertising or Third-Party Advertising purpose.

| Apple data type | Collected? | What it is in Dukan ERP | Optional? | Note |
| --- | --- | --- | --- | --- |
| Contact Info → Name | Yes | the names of staff and Owners; the names of the shop's customers, suppliers and counterparties | staff name required; customer name optional | **Decision L-6:** Apple's questionnaire covers data about the user; a shop also records data about *other* people (its customers). Proposed: declare it, since it is collected through the app |
| Contact Info → Email Address | Yes | sign-in identifier and verified contact | optional (email or WhatsApp number) | |
| Contact Info → Phone Number | Yes | WhatsApp number of staff; customers', suppliers' and payers' numbers; money-service customer numbers | optional, but a verified number is required to delete an account | |
| Contact Info → Physical Address | Yes | store addresses | optional | business, not personal, in most cases |
| Contact Info → Other User Contact Info | No | — | | |
| Financial Info → Payment Info | **No** | the app holds no card, bank-account or wallet credential; receiving accounts are labels only | | |
| Financial Info → Other Financial Info | Yes | the shop's sales, payments, debts, loans, consignments, cash counts, money-service exchanges and commissions, and an employee's recorded shortages | required for the service | |
| Purchases → Purchase History | **No** | no purchase is made in the app; business access is arranged outside the app | | |
| Location (Precise or Coarse) | **Proposed: No — see L-2** | the app asks for no location permission and reads none. **But** a receipt photo is uploaded as the file chosen, with its EXIF metadata, which may hold where the photo was taken (finding F13) | | Strip EXIF on upload (recommended, L-2) before answering "No" with confidence |
| User Content → Photos or Videos | Yes | an optional receipt photo on an expense | optional | |
| User Content → Other User Content | Yes | notes, return reasons, imported stock spreadsheets (rows kept) | optional | |
| User Content → Emails or Text Messages, Audio, Gameplay, Customer Support | No | no in-app support form exists | | |
| Identifiers → User ID | Yes | account id, personal id, sign-in identifier | required | |
| Identifiers → Device ID | Yes (proposed) | a server-issued random device id and secret, bound to the session; label, platform and app version. Not the IDFA, the IDFV, the IMEI or the serial number | required | conservative answer; TSX-MR may argue it is not a "device identifier" in Apple's sense |
| Usage Data (product interaction, advertising data, other) | No | no analytics | | |
| Diagnostics (crash data, performance data, other) | **No** | no crash-reporting or APM SDK. The *server* request logs hold IP address, user agent and request paths (which can include an IMEI looked up, F15) for security — **decision L-11** whether to declare them as "Other Diagnostic Data" | | |
| Health, Fitness, Sensitive Info, Contacts (address book), Browsing History, Search History, Other Data | No | the app never reads the phone's contacts, browsing or searches | | |

## 3. Data used on the phone and not collected

Camera frames (to read barcodes and IMEIs; nothing is stored); the photo picker (opened only when the person picks a
receipt; the photo is collected only once attached); the clipboard (written on request for a Personal ID, Store ID or
partner code, never read).

## 4. Privacy links App Store Connect asks for

| Field | Value to enter | Today |
| --- | --- | --- |
| Privacy Policy URL | `https://<public domain>/privacy` | **blocked**: the domain is an owner input (O-L1) and the page is a draft |
| User Privacy Choices URL (optional) | `https://<public domain>/privacy-choices` | page built, draft |
| Account deletion | in the app: More → Your account → Delete account; on the web: `/account-deletion` explains it | **cannot complete in production** (O-A7) |

## 5. What must be true before these answers are submitted

1. TSX-MR approves this worksheet and the privacy policy says the same (both are drafts).
2. L-2 decided (strip EXIF, or declare that location may be in photos).
3. L-6 and L-11 decided.
4. The answers are checked against the built archive's privacy manifest (docs/90 §2: NOT ARCHIVE VERIFIED).
