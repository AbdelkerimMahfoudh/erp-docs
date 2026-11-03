# D227: Devices screen, bounded handoff

Owner's item 6, for one parallel session. Return a reviewable branch with test results. **No merge, no deployment, no change
to production, DNS or any server.**

## Base
- Repository: `erp-mobile`. Base: commit `bd5c708` (branch `post-testflight-feedback`).
- Work in your own git worktree. Do not touch the shared checkout at `C:\wamp64\www\ERP\erp-mobile`: it holds uncommitted work.
- Your branch: `d227/devices-layout`. Push it; do not open or merge into `post-testflight-feedback`.

## The requirements (owner's words)
Fix device rows where a long warning badge compresses the device name into individual letters.
- Protect the device-name text area.
- Use a compact localized status label such as "Code required."
- Put longer explanation below or on the detail screen.
- Support small iPhones, large text, French expansion and Arabic RTL.
- Do not rely on truncation that hides the device identity.
- Add rendered/layout regression tests.

## Files
**May change**
- `app/devices.tsx`
- `lib/i18n/en.ts`, `fr.ts`, `ar.ts`: **additive only**, new `devices.*` keys. Change no other key.
- New: `__tests__/devices-layout.test.tsx`, and a new `components/devices/*` if a row component helps.

**Reserved by the main D227 session: do not change**
- `components/ui/*`, including `ListRow` and `Chip`. If the fix needs a shared component changed, stop and report it.
- Everything for balances, closing, transfers, Maintenance, Security and the basket: `app/(tabs)/*`, `app/closing/*`, `app/maintenance/*`, `app/account/*`, `app/money-balances.tsx`, `app/transfers/*`, `components/closing/*`, `components/money/*`, `components/sell/*`, `lib/navigation/*`, `lib/report*`, `lib/closing*`, `types/api.ts`.
- The `ops/render-tests` and `ops/visual-check` branches: the main session runs those gates. Ask it to.
- `erp-backend`, `erp-control-web`, and `erp-docs` (except reporting back in your final message).

## Backend dependencies
None. Use the existing `/devices` response and `UserDeviceView` unchanged. If you find one is needed, stop and report it.

## Don't change
What each status means, the device actions (revoke, sign out), the `intake-trail` diagnostics on this screen, or any
permission. Only the row's layout and wording change. Existing strings stay unless a key is being replaced for this fix.

## Acceptance checks
Environment: Node at `C:\Users\multi media\AppData\Local\Programs\node-v22.23.3-win-x64`; `npm ci` needs the flags in project memory.
1. `npx tsc --noEmit` clean; `npm run -s lint` at 37 warnings or fewer once the main session has removed its leftover, and never above the cap of 40. Do not raise the cap.
2. Every pure test passes: `for t in $(find lib components -name '*.test.ts'); do node "$t"; done`. These all run on Windows now, so no failure is "platform only".
3. `npx jest --ci --maxWorkers=2`, full suite, passes.
4. The new test renders a row with the longest status and a long device name in EN, FR and AR, at 320 points and large text, and asserts: the name is not line-limited to truncation and its area cannot shrink to nothing; the status uses the short label; the longer explanation is present below the row or on the detail; Arabic follows RTL with no `left`/`right` styles.
5. All new strings in all three languages, passing `lib/i18n/translation-parity.test.ts`. Arabic calls the product تطبيق دكان.
6. Report which of these were not run, and that a real small iPhone was not used if it was not. Rendered tests do not prove the layout on a device.

## Return
Branch and commit, files changed, the exact output counts for checks 1 to 3, the new test's cases, and anything left undone.
