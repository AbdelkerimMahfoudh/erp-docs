# 91 — App Store Connect metadata, prepared and not entered

> **DRAFT — REQUIRES TSX-MR APPROVAL.** 2026-10-16, CLAUDE-B. Nothing below has been entered in App Store Connect, no
> build has been uploaded and nothing has been submitted. Values in `<angle brackets>` are owner inputs (docs/93); they
> are never to be guessed. The account and TestFlight steps are `docs/81` §2.

## 1. App record

| Field | Prepared value | Status |
| --- | --- | --- |
| Name | Dukan ERP | from `app.json`; check availability in App Store Connect |
| Subtitle (≤ 30 characters) | EN "Stock, sales and cash" · FR "Stock, ventes et caisse" · AR "المخزون والمبيعات والصندوق" | proposal |
| Bundle ID | `mr.tsxmr.dukanerp` | in `app.json` |
| SKU | `<chosen by TSX-MR>` | owner input |
| Seller / provider | `<TSX-MR legal name>` | owner input (O-L1) |
| Primary language | `<English or French>` | owner choice; EN, FR and AR localisations prepared |
| Category | Business (primary), Productivity (secondary) | proposal |
| Copyright | `© 2026 <TSX-MR legal name>` | owner input |
| Price | Free, no in-app purchase | the app sells nothing; business access is arranged outside the app (D118) |
| Availability | `<territories>` | owner choice |
| Devices | iPhone; iPad only if O-A2 keeps `supportsTablet: true` | **O-A2** |

## 2. URLs

| Field | Value | Status |
| --- | --- | --- |
| Privacy Policy URL | `https://<domain>/privacy` | page built, **draft**; domain unknown |
| Support URL | `https://<domain>/support` | page built; its contact details, hours and languages are owner inputs |
| Marketing URL (optional) | `https://<domain>/products/dukan-erp` | exists |
| User Privacy Choices URL (optional) | `https://<domain>/privacy-choices` | page built, draft |
| Account deletion information | `https://<domain>/account-deletion` | page built, draft |

The same origin is `EXPO_PUBLIC_LEGAL_ORIGIN` in the app build and `VITE_PUBLIC_SITE_ORIGIN` on the website.

## 3. Description (proposal, EN — FR and AR to be translated from the approved text)

> Dukan ERP is the shop system for electronics stores and their staff. Scan an IMEI, a serial number or a barcode
> instead of typing; record sales, returns, expenses and the day's closing; follow stock across stores; and, for a
> money-services counter, record each exchange. Every role sees only what it is allowed to. Dukan ERP is used by
> businesses with an account set up by TSX-MR; it is not an app for shoppers.

No price, trial, payment or website call to action appears in the description or the screenshots (the owner's brief).

Keywords (≤ 100 characters, proposal): `stock,inventory,IMEI,shop,POS,sales,cash,closing,electronics,phones,store`

## 4. Age rating questionnaire (proposed answers)

All content categories: **None**. Unrestricted web access: **No** (the app opens four fixed legal pages in Safari and
nothing else). Gambling, contests, user-generated content shared publicly: **No**. Proposed result: 4+.

## 5. App Review information

| Field | Value | Status |
| --- | --- | --- |
| Contact name, phone, email | `<TSX-MR reviewer contact>` | owner input |
| Demo account | a **fictitious** QA business on the **staging** API: an Owner login (and, ideally, an Employee login) with sample stock | to be created on staging (O-A6); never live data |
| Notes | `docs/92` | draft |
| Attachment | optional screen recording of sign-in, a scan and Delete account | not made |

## 6. Screenshots

| Size | Needed | Status |
| --- | --- | --- |
| iPhone 6.9" (1320 × 2868 or 1290 × 2796) | yes | not made: needs the release icon (O-A1) and a device or simulator build |
| iPhone 6.5" (1284 × 2778 or 1242 × 2688) | if 6.9" is not supplied | — |
| iPad 13" | only if O-A2 keeps iPad | — |

Per language submitted (EN, FR, AR). No price, trial or payment screen in them.

## 7. Before the first upload

`ios.config.usesNonExemptEncryption` (O-A3); `EXPO_PUBLIC_API_ORIGIN` and `EXPO_PUBLIC_LEGAL_ORIGIN` as EAS
variables (the build refuses without either); the EAS project link (O-A4); the icon and splash (O-A1); the app's
privacy manifest (L-8).
