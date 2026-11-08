# 114 — App Store submission draft (build 1.0.0 (6))

> **DRAFT — NEEDS THE OWNER'S APPROVAL.** 2026-11-08, CLAUDE. Nothing below has been entered in App Store Connect.
> Supersedes the placeholders of docs/89 and docs/92 with today's facts (backend `5419fda`, mobile `5dcfb74`).

## 0. What App Store Connect still needs (checked 2026-11-08)

| Section | State today | Needed |
| --- | --- | --- |
| Version 1.0: description, keywords, support URL, promotional text, copyright | empty | §1, §2 |
| Screenshots (6.9" and 6.5" iPhone) | none | owner's choice: from your iPhone, or I capture them from the app (§6) |
| Build | none attached | attach build 6 |
| App Information: subtitle, category, age rating, content rights | name "Dukan ERP" only | §1, §3 |
| App Privacy: policy URL + questionnaire | not started | §4 |
| Pricing and Availability | not set | Free; all countries, or Mauritania first (owner's choice) |
| App Review: contact, demo sign-in, notes | empty | §5 — **the owner types the demo password** |
| Release | automatic | **propose manual release**, so you choose the day |

## 1. Listing (EN · FR · AR)

**Name:** Dukan ERP · **Category:** Business (primary), Productivity (secondary) · **Price:** Free

| | English | Français | العربية |
| --- | --- | --- | --- |
| Subtitle (≤30) | Stock, sales and cash, scanned | Stock, ventes et caisse | المخزون والمبيعات والصندوق |
| Promotional text | Scan IMEIs and barcodes, sell in seconds, and close the day with every amount counted. | Scannez IMEI et codes-barres, vendez en quelques secondes et clôturez la journée, caisse comptée. | امسح أرقام IMEI والباركود، وبِع في ثوانٍ، وأقفل اليوم بعد عدّ الصندوق. |
| Keywords (≤100) | stock,inventory,IMEI,barcode,sales,cash,shop,electronics,phones,closing,receipt,ERP | stock,inventaire,IMEI,code-barres,ventes,caisse,boutique,téléphones,clôture,reçu | مخزون,جرد,IMEI,باركود,مبيعات,صندوق,متجر,هواتف,إقفال,إيصال |

**Description (EN)**

Dukan ERP replaces the shop notebook for electronics stores. It is used by the shop's Owner, managers and staff — never
by the shop's customers.

- Scan instead of typing: IMEI, serial number or barcode, straight from the camera.
- Sell in seconds, with receipts, returns and what each customer still owes.
- Close the day: the app counts what should be in the drawer and records any difference.
- Several stores: each store has its own stock, staff and day.
- Roles: an Employee sees only what the Owner allows.
- English, French and Arabic.

A business needs an active Dukan ERP account; the app shows its status.

**Description (FR)** — Dukan ERP remplace le cahier des boutiques d’électronique. Il est utilisé par le propriétaire,
les responsables et le personnel — jamais par les clients de la boutique. Scannez au lieu de taper (IMEI, numéro de
série, code-barres) ; vendez en quelques secondes, avec reçus, retours et restes dus ; clôturez la journée, caisse
comptée et écarts enregistrés ; plusieurs boutiques, chacune avec son stock, son personnel et sa journée ; des rôles :
un employé ne voit que ce que le propriétaire autorise ; en français, anglais et arabe. Une entreprise a besoin d’un
compte Dukan ERP actif ; l’application en affiche l’état.

**Description (AR)** — يحلّ Dukan ERP محلّ دفتر متاجر الإلكترونيات. يستخدمه مالك المتجر والمديرون والموظفون، ولا
يستخدمه زبائن المتجر أبدًا. امسح بدل الكتابة (IMEI، الرقم التسلسلي، الباركود)؛ بِع في ثوانٍ مع الإيصالات والمرتجعات
والمبالغ المتبقية؛ أقفل اليوم بعد عدّ الصندوق وتسجيل الفروق؛ عدة متاجر لكلٍّ منها مخزونه وموظفوه ويومه؛ أدوار: لا يرى
الموظف إلا ما يسمح به المالك؛ بالعربية والفرنسية والإنجليزية. يحتاج النشاط التجاري إلى حساب Dukan ERP نشط، ويعرض
التطبيق حالته.

**URLs:** Support `https://dukan.tsxmr.com/in-app/support` · Marketing (optional) `https://tsxmr.com` ·
Privacy `https://dukan.tsxmr.com/in-app/privacy` (all 12 in-app pages answer 200 in EN/FR/AR, checked 2026-11-08).
**Copyright:** `2026 <TSX-MR legal name>` — owner input.

## 2. Wording rules applied

No price, no "subscribe", no trial offer, no link or instruction to pay anywhere in the listing (the bundle audit's
rules, applied to the store text too). "A business needs an active account; the app shows its status" is the only
mention of access.

## 3. Age rating (proposed answers)

Every content question **None / No** (no violence, sexual content, profanity, drugs, gambling, horror, medical
information); unrestricted web access **No** (the app opens only its four legal pages); user-generated content shared
publicly **No**; messaging between users **No**. Expected rating: **4+**.

## 4. App Privacy (docs/89, updated)

- **Tracking: No.** No advertising/analytics SDK, no IDFA.
- **Collected, linked to the user, App Functionality only:** Name; Email; Phone Number; Physical Address (store);
  Other Financial Info; Photos (receipt pictures); Other User Content (notes, reasons); User ID; Device ID
  (server-issued id, not IDFA/IDFV).
- **Not collected:** Payment Info, Purchase History, Usage Data, Diagnostics, Contacts, Browsing/Search History, Health.
- **Push notifications** now exist (asked only after the app's explanation, from "Enable notifications"); the device's
  push token is covered by Device ID.
- **Decisions still open for the owner:**
  - **L-2 Location:** receipt photos are uploaded with their EXIF data, which can include where the photo was taken; the
    server does not strip it. Either declare **Location → Precise, App Functionality**, or strip EXIF first (a backend
    change and a deploy). Recommended: declare it now, strip later.
  - **L-11 Diagnostics:** server request logs keep IP and user agent for security. Recommended: declare
    **Other Diagnostic Data, App Functionality**.

## 5. App Review notes (to paste; ≤4000 characters)

> Dukan ERP is a business tool for electronics shops in Mauritania. A shop's Owner, managers and staff use it to record
> stock (IMEI, serial number or barcode), sales, returns, expenses and the day's cash closing. The shop's customers never
> use it.
>
> **Sign-in.** Use the demo business "Dukan-test" (fictitious data): the user name and password are in the Sign-In
> Information fields. It is an Owner account, so every screen is visible.
>
> **No purchase in the app.** The app sells nothing and shows no price. A business's access — including each additional
> store — is arranged between the business and TSX-MR outside the app. The app only shows whether the business or a store
> is active, read-only or waiting; it contains no purchase button, price, link or instruction to pay.
>
> **Permissions.** Camera: to scan IMEI labels and barcodes (nothing is recorded). Photos: only when the person attaches a
> receipt picture to an expense. Notifications: only after the person taps "Enable notifications".
>
> **Account deletion.** More → Your account → Delete account: the person confirms with their password and a one-time
> code sent to the account's verified WhatsApp number. The steps are also at
> https://dukan.tsxmr.com/in-app/account-deletion.
>
> **Privacy policy, terms and support** open in Safari from the sign-in screen and from More → Your account.

**Contact for App Review:** owner's name, email, phone (owner input).
**Demo account:** the Dukan-test Owner, or a dedicated review Owner on Dukan-test (recommended, so your own sign-in is
never shared). The owner enters the password in App Store Connect; Claude never types it.
**Check before sending:** account deletion must complete for the reviewer — the WhatsApp code template
(`dukan_account_action_code`) is Active, so it should; tested on the demo account first.

## 6. Screenshots

Required: iPhone 6.9" (1320×2868) and 6.5" (1284×2778 or 1242×2688), up to 10 each, per language (EN at least).
Proposed 5: Home · Scan a product · Sale · Day closing · Stores. Fictitious data only (Dukan-test). Either the owner takes
them on an iPhone (6.9" = Pro Max), or Claude captures them from the app at those sizes in the browser and frames
nothing — plain screenshots.
