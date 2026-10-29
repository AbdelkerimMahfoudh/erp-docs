# 110 — The iPhone store pilot on TestFlight (D224)

**Status:** prepared on 2026-10-29. Build identifiers are filled in when they exist; nothing here is invented.
**Not in this phase:** an App Store release, a public TestFlight link, Android.

## 1. The app

| Item | Value |
| --- | --- |
| Name | Dukan ERP |
| Bundle identifier | `mr.tsxmr.dukanerp` |
| Devices | iPhone only (`ios.supportsTablet: false`) |
| Appearance | light and dark (`userInterfaceStyle: automatic`) |
| Encryption | `usesNonExemptEncryption: false`: HTTPS and the iOS Keychain only (exempt) |
| EAS | owner `salah_rim`, project `@salah_rim/dukan-erp` (`86a08e0d-578d-479f-986d-51706ea99522`) |
| Apple | Team ID `5B9T8L263K`, an individual membership (no organisation conversion) |
| Backend | `https://api.tsxmr.com` (production), from the EAS production environment |
| Legal pages | `https://tsxmr.com/in-app/*` in EN/FR/AR |
| Feedback | `abdelkerim@tsxmr.com` |

**Permissions, and only these:**
- **Camera** (`NSCameraUsageDescription`): "Dukan ERP uses the camera to scan IMEIs, serial numbers and barcodes so you
  do not have to type them."
- **Photos** (`NSPhotoLibraryUsageDescription`): "Dukan ERP opens your photos only when you choose a receipt picture for
  an expense." It is used by `app/expenses/new.tsx`.
- **Not requested:** microphone (`microphonePermission: false`), Face ID (`faceIDPermission: false`), location,
  contacts, notifications and tracking.

## 2. The build (filled in after `eas build -p ios --profile production`)

| Item | Value |
| --- | --- |
| Commit | `2bf0a5715ed7e60791299ba436e523ea526421b7` (= `browser-input-setup-code`, every gate green) |
| EAS build ID | `b1308200-00ac-4029-b6ec-3ac9c6bc4e55` (production profile, store distribution, SDK 58), finished 2026-10-29T16:13Z |
| Version / Apple build number | 1.0.0 / 1 (`appVersionSource: remote`, auto-increment) |
| Artifact | IPA, 24 088 782 bytes, SHA-256 `aa57d76ac62a217fbf4a3013e411d236a53c3a313b0f17b68ee1b09c5ed84467` |
| Signing | App Store profile for Team `5B9T8L263K`, app ID `5B9T8L263K.mr.tsxmr.dukanerp`, valid to 2027-10-29; `get-task-allow` false; no push and no associated domains |

**Archive checks (2026-10-29, the downloaded IPA):**
- **`Info.plist`:**
  - `mr.tsxmr.dukanerp` 1.0.0 (1), "Dukan ERP";
  - **`UIDeviceFamily [1]`**, iPhone only, with no iPad orientations;
  - minimum iOS 16.4; appearance Automatic; launch storyboard `SplashScreen`;
  - `ITSAppUsesNonExemptEncryption` false;
  - only the camera and photos usage descriptions, as worded in §1;
  - ATS: no arbitrary loads.
- **The bundle (Hermes):**
  - the only real origins are `https://api.tsxmr.com` and `https://tsxmr.com`;
  - no source map and no `sourceMappingURL`;
  - no secret-shaped string, and not the company sender's number.
- **The local literals found are library defaults, not app settings:**
  - `localhost:8081` is React Native's development-server default, unused in a release;
  - `localhost:3000` is expo-router's web head fallback;
  - `127.0.0.1`/`10.`/`192.168.`/`172.` are the app's own list of origins it refuses;
  - `10.5.0.8` is a fragment of SVG path data.
- **Icon and splash:** `AppIcon60x60@2x` (plus Xcode's standard 76 pt variant), `Assets.car`, and the
  `SplashScreen` storyboard. Seeing them is the physical check.
- **To note:** `NSAllowsLocalNetworking` is true, which is Expo's default. No local address is used, so it is
  harmless. Removing it is a later, separate change.

## 3. Groups

1. **Internal group first.**
   - Members are App Store Connect users only. The owner, or the Account Holder, adds them and handles their Apple
     Account access.
   - No Beta App Review is needed.
2. **External private group `Dukan ERP Store Pilot`.**
   - Created after the internal check passes. The build goes to TestFlight Beta App Review first.
   - Testers join by **email invitation only**. **No public link** is created.
   - Each tester uses **their own Apple Account** and **their own Dukan staff account** (Owner, Manager or Employee,
     made by the owner in the portal). No Dukan login is ever shared.
   - The testers' Apple Account emails are asked for only when the group and the build are ready.

## 4. Texts for App Store Connect (English)

**Beta App Description**
> Dukan ERP is a point-of-sale and stock tool for electronics shops, used by the shop's own staff. This private pilot
> is run in one real store. Each person has their own account, created by the shop's administrator. Phones are tracked
> by IMEI, other devices by serial number, and accessories by barcode and quantity.

**What to Test**
> Please use the app as you do your normal work in the shop, each with your own account:
> - sign in, and stay signed in after closing and reopening the app;
> - receive stock: scan IMEIs, serial numbers and barcodes, or type them; counted items too;
> - sell: scan or search, add the customer's name, take the payment, and show or share the receipt;
> - the return policy printed on the receipt, and a return;
> - a sale below the buying cost (you will be warned);
> - the day's opening and closing, and the cash reconciliation;
> - two phones at the same time, and what happens with no network and when it comes back.
>
> Tell us what was slow, unclear or wrong. Send a screenshot from TestFlight, or write to abdelkerim@tsxmr.com.

**Feedback email:** `abdelkerim@tsxmr.com`

**Review notes (Beta App Review)**
> Dukan ERP is a staff tool for one electronics shop. Accounts are created by the shop's administrator; there is no
> public sign-up and nothing is sold inside the app (no in-app purchase, no prices for the app itself).
> The sign-in details in the "Sign-in information" fields belong to a fictional review shop on our production server
> (https://api.tsxmr.com).
> The camera is used only to scan IMEIs, serial numbers and barcodes when receiving or selling stock; every scan can
> also be typed. To try receiving without real devices, type these test IMEIs (each passes the check digit):
> 001010032400010, 001010032400028, 001010032400036, 001010032400044, 001010032400051, 001010032400069,
> and these in-store barcodes for counted items: 2000000090016, 2000000090023, 2000000090030.
> Photos are opened only to attach a receipt picture to an expense.

**The review account.** The owner creates a stable, fictional review shop and its account through the portal. The
owner types its credentials directly into App Store Connect's "Sign-in information". Claude neither creates it nor
sees, asks for or records its password.

## 5. The physical pilot gate (3 to 7 days in the store; automated WebKit is not an iPhone)

Several iPhones, with separate roles and accounts: the Owner, a Manager and an Employee. To check:
- simultaneous sessions;
- receiving, and IMEI, serial and barcode scanning;
- counted stock;
- sales, below-cost warnings and customer names;
- receipts and their return-policy snapshot, returns, and payments;
- the daily reconciliation;
- offline use and reconnection, and conflicting edits;
- restart and session persistence;
- that stock and reports agree.

The brand's native splash handing over to the animation can only be seen on a device. It is part of this gate.

## 6. Record

(filled in as the work proceeds)
