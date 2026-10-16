# 90 — Permissions, purpose strings, SDKs, privacy manifest, clipboard, local network and cleartext

> Status: audit of erp-mobile `b23badb`, with the changes of `b6adc48` (2026-10-16, CLAUDE-B). Method: `app.json`, the
> resolved `npx expo config --type introspect`, and `expo prebuild --no-install` on a copy outside the repository
> (Info.plist, AndroidManifest). **No built archive was inspected**: an EAS build has not been made in this session.

## 1. Permissions and purpose strings

### iOS

| Key | Before | After `b6adc48` | Used by |
| --- | --- | --- | --- |
| `NSCameraUsageDescription` | EN only | **EN, FR, AR** (`locales/fr.json`, `locales/ar.json`) | the scanner (`components/scanner/ScannerSheet.tsx`) |
| `NSPhotoLibraryUsageDescription` | EN only | **EN, FR, AR** | the receipt picker (`app/expenses/new.tsx`). Probably not needed on iOS 16.4+ (PHPicker needs no permission) — **L-7**: drop with `photosPermission: false` after a device check |
| `NSMicrophoneUsageDescription` | "Dukan ERP does not record sound." | **removed** (`microphonePermission: false` on expo-camera and expo-image-picker) | nothing |
| `NSFaceIDUsageDescription` | "Dukan ERP does not use Face ID." | **removed** (`faceIDPermission: false`) | nothing (SecureStore without `requireAuthentication`) |
| Location, contacts, tracking, local network, Bonjour, photo-library add, push entitlement | absent | absent | — |
| `NSAppTransportSecurity` | `NSAllowsArbitraryLoads=false`, `NSAllowsLocalNetworking=true` (Expo default) | unchanged | release traffic is https by the origin guard. **L-9:** remove `NSAllowsLocalNetworking` from the store build |
| `ITSAppUsesNonExemptEncryption` | not set | not set | **O-A3** (a legal export-compliance statement; the app uses only the OS's TLS and Keychain) |

Verified after the change: introspect lists only the camera and photo-library usage strings, in three languages.

### Android

| Permission | After `b6adc48` | Why |
| --- | --- | --- |
| `CAMERA` | kept | scanner |
| `INTERNET`, `VIBRATE` | kept | API, haptics |
| `RECORD_AUDIO` | **blocked** (`android.blockedPermissions`) | added by expo-image-picker's microphone option; unused |
| `SYSTEM_ALERT_WINDOW` | **blocked** | template default; unused |
| `WRITE_EXTERNAL_STORAGE` (≤ SDK 32) | **blocked** | nothing writes to shared storage |
| `READ_EXTERNAL_STORAGE` (≤ SDK 32) | kept | picking a file on Android ≤ 12 |
| cleartext | not allowed in the release manifest (`usesCleartextTraffic` only in debug manifests) | |
| backup | `allowBackup=true` with rules that include shared preferences only and exclude SecureStore; Documents and cache are not backed up | |

## 2. SDKs and the privacy manifest

| Item | Finding |
| --- | --- |
| Analytics, crash reporting, advertising, attribution | **none** |
| Push notifications | none (no expo-notifications; empty entitlements) |
| OTA updates | none (expo-updates not a dependency; `EXUpdatesEnabled=false`) |
| Web views, in-app browsers | none (`expo-web-browser`, `react-native-webview` and others are refused by the bundle audit) |
| Required-reason APIs, declared by the bundled pod manifests | UserDefaults `CA92.1`; FileTimestamp `C617.1`, `0A2A.1`, `3B52.1`; SystemBootTime `35F9.1`; DiskSpace `E174.1`, `85F4.1` |
| The app's own privacy manifest | **not declared** in `app.json` (`ios.privacyManifests`). Expo aggregates the pods' manifests at `pod install`; the result is **NOT ARCHIVE VERIFIED**. **L-8:** declare `ios.privacyManifests` with `NSPrivacyTracking=false`, the collected types of docs/89 and the four API categories |
| Native code not read | the Swift/ObjC of reanimated, gesture-handler, screens, svg, secure-store, camera and image-picker was not audited line by line |

## 3. Network

A release build contacts **one host**: the https API origin (`EXPO_PUBLIC_API_ORIGIN`), refused at build time and at
run time if missing, clear text or a development host. It **opens** — in the phone's browser, never inside the app —
four pages on the https legal origin (`EXPO_PUBLIC_LEGAL_ORIGIN`, held to the same rule, `b6adc48`). No telemetry,
remote fonts, maps, remote images or third-party lookups. The release config check, the CI exports and the bundle
audit now carry the legal origin; the audit allows that exact origin and refuses any other website address (proved on
a real iOS export with a realistic origin: PASS with it, FAIL without it).

## 4. Clipboard

Write only (`expo-clipboard` `setStringAsync`): the Personal ID and the Store ID in Settings and a partner code in
Partners, on request. The pasteboard is never read, so iOS shows no paste prompt.

## 5. Local network

None at run time. No Bonjour, no `NSLocalNetworkUsageDescription`; the release origin guard refuses private addresses.

## 6. Legal links in the app (the owner's brief of 2026-10-16)

| Surface | Pages | Opened by |
| --- | --- | --- |
| Sign in | privacy, terms, support, how deletion works | `openLegalPage` → the phone's browser (Safari / the default browser), never a web view |
| More → Your account | the four, as rows | same |
| Delete account | how deletion works, privacy, support | same |
| Access closed (pending, suspended, refused…) | the four, below the actions, outside the display-only trial card | same |
| No branch assigned | the four, and a new **Your account** button (deletion reachable without a branch) | same |

`lib/navigation/no-browser.ts` keeps the phone's opener before refusing every `openURL`, and reaches it only for an
exact address built from (page, language) on the configured origin. Pinned by `lib/access-boundary.test.ts`, tested
by `lib/legal-links.test.ts`, `__tests__/no-browser.test.tsx` and `__tests__/legal-pages.test.tsx`. The pages are the
website's `/in-app/…` variants: the same text, no sign-in, application, price or navigation to the rest of the site,
and never indexed.
