# UI screenshot matrix — production-readiness phase (2026-10-16)

**What this is:** every first screen of the app (as a web export) and the website, in English, French and Arabic, at
two sizes, for each role, activity and access state — 561 checked entries, 380 images — with automated checks on each,
then read by eye. **What it is not:** a device test. Everything here ran in desktop Chromium. See §5.

## 1. Builds and world

| Item | Value |
| --- | --- |
| Backend | `d7359fb`, `npm run build`, API on `127.0.0.1:3040` |
| Mobile | `7c127b3`, `npx expo export --platform web` (isolated Metro cache) served locally |
| Website | `35ca6d1`, `vite build --mode preview` + prerender, served by its own `scripts/serve-dist.mjs` so the `_headers` CSP is live |
| Database | disposable `prisma_qa_shots` on the session's scratch MySQL 8 — 96 migrations to `0097`, `scripts/qa-boutiques.ts --apply` (ten boutiques, 80 IMEI phones + 20 accessories each); **dropped afterwards** |
| Roles | Owner, plus a Store Manager and an Employee made through the Owner's real team API, each email proven with the real code |
| Access states | each its own self-registered business, put in its state through the platform API (approve, period moved, suspend, reject, trial claim, platform-created pending) and read back from `GET /entitlement` before capture |
| Activities | money services / both set by SQL on two boutiques (no unpriced API path), recorded and confirmed through `GET /entitlement` |

The fixes made after these builds (backend `65be480`…`06a0db7`, mobile `a1fedda`, `b23badb`, website `0eedfaa`) were
not re-captured. Of them only `0eedfaa` changes a captured screen (R2 below); its regression test covers it.

## 2. Coverage

| Surface | Who / what | Sizes | Languages | Result |
| --- | --- | --- | --- | --- |
| App | signed out (sign-in) | 393 pt; 320 pt × 1.3 text | EN FR AR | pass |
| App | Owner, Manager, Employee — electronics, five tabs | both | EN FR AR | pass |
| App | Owner — money services only; both activities — five tabs | both | EN FR AR | **R1** at 320 × 1.3 (Transactions) |
| App | Owner in active, trial running, grace | both | EN FR AR | pass |
| App | Owner in expired, trial eligible, suspended, pending, refused | both | EN FR AR | the closed screen or read-only tabs as designed; **R3** (403 on `POST /devices/adopt`) |
| Website | public home | 1280, 1440, 390 | EN FR AR | pass |
| Website | eleven other public pages; Owner sign-in form | 1280, 1440 | EN FR AR | pass |
| Website | Owner area signed in, ten Owner/state views | 1280, 1440 | EN FR AR | **R2** in four closed states; **R4** everywhere |

Checks on every entry: page wider than the viewport, text clipped off-screen, text over text (website overlaps
re-checked line box by line box), raw i18n keys, `undefined` / `NaN` / `[object Object]` / `null` in text, the error
boundary, uncaught errors, console errors (website), every API answer ≥ 400. 320 pt × 1.3 sets every text element to
1.3 × its computed size after load — a CSS approximation of Dynamic Type, not the OS setting.

Automated result: 176 failing rows in 4 distinct failures (F1–F4), 96 warning rows (ellipsized or squeezed text, read
and judged intended: long product names, the FR greeting, the website's product cards). By-design answers not counted:
`403 GET /auth/branches` for a closed business (the app shows its closed screen) and the website's signed-out
`401 GET /platform/my-subscription`.

## 3. Findings, read against the images

| ID | Sev | Where | What | Status |
| --- | --- | --- | --- | --- |
| R1 | medium | app, money services and both, Transactions tab, 320 pt × 1.3, EN FR AR | the header gives "New exchange" its full width, so the title breaks mid-word ("Tran/sact/ions", AR "المعاملا/ت") and so does the branch name; FR "Référence" chip cut at the edge. Fine at 393 × 1 | open — `components/ui/TabHeader.tsx` is shared by every tab with an action; the fix (let actions wrap under the title, or an icon-only button at large text) is a layout choice for every tab, and native layout cannot be confirmed from a browser |
| R2 | medium | website account page of a trial-eligible, suspended, pending or refused business, every language and width | the requests card says "Loading…" for ever beside a red "not allowed", and an activity change cannot be priced, while the request forms work | **website fixed, server awaits the owner** — website `0eedfaa`: a list that cannot be read shows the refusal once and is not left loading (its regression test fails on the old page). Letting a closed business read its own requests and their prices is `docs/21` **PQ17** alternative (a), awaiting the owner: it was implemented in backend `2251c06` by mistake and reverted in `06a0db7` |
| R3 | low | app, every closed state | each load sends `POST /devices/adopt`, answered 403 (adopting grants authority and is deliberately blocked, `route-classification.ts`); the app swallows it and tries again next launch; nothing is shown | open — owner policy; seen on the web export, where no device credential is stored — native NOT DEVICE VERIFIED |
| R4 | low | website, every signed-in Owner view | the header still offers "Sign in" beside the page's own "Sign out" | open — the header holds no session state (`components/Chrome.tsx`) |

Dismissed after looking: every website "overlap" hit (wrapped inline text; the line boxes do not overlap) and the
390 px header hits (links inside the closed menu, not painted).

## 4. Where the images are

380 JPEG images and `results.json` (one row per entry, with every check's outcome) were written to the session's
scratch directory and are **not committed** (53 MB of demo-data screenshots). They do not outlive the session's
container. To reproduce: rebuild the world in §1 on a disposable database and run the same capture.

## 5. Not covered

- **NOT DEVICE VERIFIED — none of this was seen on a phone:** the camera and barcode scanner, haptics, native sharing,
  the native PDF preview, safe areas and the home indicator, cold-launch right-to-left (`I18nManager.forceRTL` needs a
  native restart; here RTL comes from the web `dir`), the OS text-size setting, iPad and landscape, dark mode, push,
  native fonts. This is react-native-web in desktop Chromium.
- Only the first screen of each tab (with its full scroll height at 393). Sub-pages, sheets and forms were not opened.
- Access-state shops are empty (the stocked boutiques run on a platform grant, which no API ends); `trial_expired` and
  `cancelled` were not built; Manager and Employee were not run in the access states.
- Money services shops carry no transactions: their Transactions and Reports tabs show empty states.
- The website's Super Admin console (`/admin`) was not captured, and the website was not run at 1.3 × text.
