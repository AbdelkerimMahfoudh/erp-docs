# 103 — Browser input, focus ring and the Owner's setup code (2026-10-24, CLAUDE, cloud)

The owner tested the protected browser app (`https://erp-test.tsxmr.com`) on a physical iPhone in Safari. Two defects,
and one product clarification (D219), are corrected here in code, tests and a deployment runbook. **This session had no
server access and deployed nothing**: §5 is for the PC-linked session.

## 1. What was wrong, and why

**Defect 1 — two focus indicators.** Tapping the sign-in's Email/WhatsApp field showed the browser's own rectangular
outline on the `<input>` inside the app's rounded purple border — two nested boxes. The app's border also grew from a
hairline to 1.5 px on focus, which moved the layout by a fraction of a pixel.

**Defect 2 — sheet fields could not be typed into.** Root cause, reproduced in Chromium with touch emulation before any
fix, with the event sequence recorded (`pointerdown › touchstart › touchend › mousedown › focusin INPUT › click INPUT ›
focusout INPUT`) and the blur's stack captured (`Keyboard.dismiss › blurTextInput`, called from an `onClick`):

- react-native-web draws a `Modal` through a **React portal**;
- React delivers an event to every ancestor in the **component** tree, so a tap inside a sheet also reached the screen
  the sheet was opened from;
- that screen's blank-space handler (`Screen`, `lib/keyboard-dismiss.ts`) dismissed the keyboard, which on the web
  **blurs the focused input** — the one the tap had just focused.

So every field in every sheet was focused and blurred in one click: Add an account, New team member, and the others. On
a phone a `Modal` is its own native root, which is why the native apps were never affected. The drag gesture was
innocent: it already covered the handle and header only.

**Clarification — "waiting for approval".** The app named the `pending` entitlement state "Pending approval", and fell
back to it when the state was missing. After an Owner redeems a setup code nothing is waiting for an approval: what is
missing is an entitlement.

## 2. What changed

**erp-mobile `browser-input-setup-code` `c8c5c0d`** (from `superadmin-provisioning` `da5c73c`; two commits — `7d199a9`
the corrections, `c8c5c0d` the legal links wrapping at 320 px):

- **One focus treatment** (`components/ui/field-chrome.tsx`, used by `TextField` and `SearchInput`):
  - a single rounded ring drawn as an overlay, so nothing moves;
  - the theme's focus colour (`border.focus`, a brighter step in dark mode);
  - the danger colour when invalid, drawn thicker when invalid and focused; none on a field that cannot be edited;
  - the browser outline removed **inline, on these inputs only** (no global `outline: none`);
  - the autofill tint held off by a rule scoped to `input[data-app-field]` in `global.css`, which keeps the field's own
    text colour (`--app-field-ink`).
- **The modal's edge** (`components/overlay/ModalBoundary.tsx`): on the web a click stops at the modal's edge, after
  every handler inside it, exactly as a native root does. It wraps the content of all three modals the app draws:
  `BottomSheet`, `DialogHost` and `ScannerSheet`. Only the click is stopped: key events keep travelling, because
  react-native-web closes a modal on Escape at the document.
- **Sheets with the keyboard up:**
  - `BottomSheet` gains `scroll` (a `ScrollView` with `keyboardShouldPersistTaps="handled"`), set on all 15 form
    sheets that had no scrolling container of their own;
  - on the web the keyboard is measured from the visual viewport (`lib/web-keyboard.ts`), so a sheet lifts above it;
  - the receiving-account sheet resets its form only when a different account is opened, not when a refetch hands in
    the same account.
- **Legal links at 320 px** (`c8c5c0d`): in French, WebKit kept "Comment fonctionne la suppression du compte" on
  one 340 px line, so the sign-in page scrolled sideways by 22 px. This was already so before this phase (`da5c73c`,
  measured by the suite's diagnostic). The labels now wrap within the row.
- **Access wording** (EN/FR/AR): `pending` reads "No active access yet". The body says the account is ready but the
  business has no active access yet. A state this build does not know, or none, reads "Access could not be read"
  (`closedReason` → `unknown`), never `pending`. App Store rule kept: the app names no subscription, price or way to buy.

**erp-control-web `browser-input-setup-code` `2ebe9c5`** (from `superadmin-provisioning` `d1016d8`):

- Portal: `pending` reads "No access yet". The explanation says the business has no active subscription or access grant
  yet (EN/FR/AR).
- Console: the `pending_activation` status reads "No access yet" (EN/FR/AR).
- The public sign-up confirmation (`apply.done.body`) is untouched: registration is closed, and tsxmr.com is out of
  scope.

**erp-backend: unchanged.** Production's `f5da650` already behaves as D219 requires:

- redeeming a code sets the Owner's password and spends the code once;
- no subscription, period or payment is created;
- an audited grant sets `activated` + complimentary, which opens the ERP at once.

So **no API deployment, no migration and no backup gate** in this phase.

**Not in this phase:** `X-Robots-Tag` on the unauthenticated 401 (see §6).

## 3. Verification

**Local (cloud workspace):**
- app: `tsc` 0 errors; lint 0 errors, 28 warnings (the same 28 as before the change); pure tests 121 files, all pass;
  rendered tests 38 suites, 360/360 tests;
- web export OK; Expo Doctor 19/21 (the two checks that need `exp.host` and the React Native Directory could not reach
  them; no dependency changed);
- console: typecheck OK, Vitest 38 files 612/612, the portal preview build OK;
- browser (Chromium, iPhone-sized touch, a mocked API): the input matrix **fails on `da5c73c`** — the browser's own
  outline, no ring, every sheet field empty after typing — and **passes on `7d199a9`**.

**New tests:**
- `lib/sheet-input.test.ts`: every modal is wrapped by `ModalBoundary`; every sheet with a field scrolls; the drag
  covers the header only; the web keyboard calculation;
- `lib/access-pending-wording.test.ts`: no approval word in the pending or unknown wording, EN/FR/AR;
- `lib/access.test.ts`: `unknown` for a missing or unrecognised state;
- `__tests__/field-focus-ring.test.tsx`: normal, focused, invalid, focused-invalid and disabled states, and a well
  border that never changes width.

**CI on the exact commits:**
- erp-mobile `40099913947` (`7d199a9`) and `40104214743` (`c8c5c0d`) green: type-check, lint, pure and rendered tests,
  release configuration, web and iOS exports, bundle audits;
- erp-control-web `40100086065` green: unit tests and the three Playwright surfaces.

**End to end, Chromium and WebKit** (`ops/verify-browser-input` `657ced4`, run `40104216381`, green; evidence on
`ci-evidence` under `evidence/browser-input/f5da650-c8c5c0d-40104216381/`):

| Job | Result |
| --- | --- |
| backend (`f5da650`) | unit suite green; real-MySQL database gates green — identities, every migration from empty, 0101 employee invitations, 0102 provisioning (the setup code's claim under concurrency) |
| Chromium | administrator MFA 3/3 · access journey **21/21** · input matrix **245/245** |
| WebKit | administrator MFA 3/3 · access journey **21/21** · input matrix **245/245** |

- **The access journey, over the real API:**
  - a test business with its Owner and store;
  - the code typed by touch and redeemed; a replay refused (400); the code kept nowhere in the browser;
  - the Owner signed in at once, landing on "No active access yet" with no approval word;
  - the entitlement `pending` / `pending_activation`, with no period, no grant and no read;
  - the audited no-payment grant, then "Check again", and the ERP opens (the store picked once): `complimentary`,
    writes, still no paid period;
  - EN/FR/AR wording, Arabic right to left; an answer without a state reads "Access could not be read".
- **The input matrix, at each of 18 combinations** (320/375/390 × EN/FR/AR × light/dark):
  - sign-in: one ring and no browser outline on touch, 0 px movement; keyboard (Tab) focus shows the ring; layout
    without overflow, RTL in Arabic; the scoped autofill marker present;
  - Add an account: one tap focuses "Name staff will see" and it types; switching Sedad, BIM Bank, Bankily and Other
    keeps it; Other's service name types; select, delete and retype work;
  - New team member: Name, Phone and Email each take a tap and typing; changing role and store keeps every value; the
    same elements are still mounted;
  - New category: types and keeps.
- **Validation, then correction, saved for real** (EN 375 light, AR 320 dark):
  - the empty name is refused in words, and the ring turns to the error colour, also while focused; typing goes on;
    corrected, it saves (201) and is listed;
  - a wrong phone is refused in words and corrected in place; Tab moves to Email;
  - saved as a pending employee with an invitation reference (201): employee invitations behave as before.
- **Diagnostic** (sign-in at 320 px): 0 px overflow in every language in both engines. The build before this phase
  (`da5c73c`) overflows 22 px in French in WebKit, which `c8c5c0d` fixes.

WebKit there is automation on Linux, not a physical iPhone: the owner's iPhone retest (§5.9) stays open.

**Release builds:** `ops/build-test-console`, run 40104218531 (console `2ebe9c5`, app `c8c5c0d`). The console `dist` and
the app export, each with its SHA-256 list, are on `ci-evidence` under `evidence/test-console/2ebe9c5-c8c5c0d-40104218531/`.
The earlier build of `7d199a9` (run 40101050899) is superseded: do not install it.

## 4. Decision

D219 (`docs/21`): redeeming a platform-issued setup code activates the Owner. Approval and entitlement are separate, and
no business is told it is waiting for approval.

## 5. Deployment runbook — for the PC-linked session

What changes on the server: **the two protected test sites only.**
- Unchanged: the API (`erp-api:f5da650…`), the database, `api.env`, the secrets, DNS and tsxmr.com.
- `test-sites.sh` validates the edge and restarts it, which interrupts the API for a few seconds.

### 5.0 Before anything
1. Pull `erp-docs` on the PC: it is behind GitHub since 2026-10-24.
2. Claim the handoff (`CURRENT_HANDOFF.md`) as `CLAUDE`, writing the claim before any change.
3. Confirm no other session holds it.

### 5.1 Read-only reconciliation (must come first)

Run `deploy/reconcile-readonly.sh` from this repository, exactly as its header says.

- It prints counts, states, commits and file names only.
- Sudo is asked once, on the terminal, for the journal.
- Continue only if every point matches what the owner expects:
  - the image is `erp-api:f5da650…`, with 101 applied, 0 pending and 0 missing;
  - the app and console releases are `20261020T110732Z` and `20261020T110759Z` (or later ones recorded in the handoff);
  - platform administrators is exactly 1, with MFA enrolled;
  - the test business: `test`, with its Owner, its store(s), `setup_code_redeemed` ≥ 1, an active grant and 0
    subscription payments;
  - `CUSTOMER_ACTIVATION=closed`, email and WhatsApp `disabled`, CORS exactly the three origins;
  - public sign-up refused: 503 `registration_unavailable`, or 400 for the empty body. Neither creates anything;
  - no WhatsApp or email message queued or sent;
  - no leftover scripts or secret files in `/dev/shm`, `/tmp` or the home folder, apart from the release directories.
- If anything differs, **stop**, record it, and ask the owner. **Never delete, reset or recreate the administrator, the
  test business, its Owner, store, grant or data.**

### 5.2 Backup

**Not required:** no backend, schema or data change. The existing rollback point stays `phonestore-20261020T110554Z`
(pre-0099), with `phonestore-20261020T085555Z` restore-proven. If the owner wants a fresh point anyway, follow `docs/100`
§16.3 (backup, laptop copy, restore drill), which changes nothing else.

### 5.3 The two releases (built on Linux; the PC cannot build them)

1. Fetch `evidence/test-console/2ebe9c5-c8c5c0d-40104218531/` from `ci-evidence`.
2. Check every file against `dist.sha256` and `app-export.sha256`.
3. Package them on the PC, from checkouts at exactly these commits:
   ```powershell
   # erp-control-web at 2ebe9c5 (git fetch; git checkout 2ebe9c5a85f860636170874a4b3bba2df8a36ad3)
   node scripts/caddy-release.mjs <evidence>\dist <tmp>\erp-console-release https://dukan-test.tsxmr.com https://api.tsxmr.com/api/v1
   # erp-mobile at c8c5c0d (git fetch; git checkout c8c5c0d0898aa1f06b160c46378869f012662d6d)
   node scripts/web-test-release.mjs <evidence>\app-export <tmp>\erp-app-release https://api.tsxmr.com --production-api
   ```
4. Copy both release directories to `tsxmr-admin`'s home with `scp -r -q`. Compare a checksum list on both ends.

### 5.4 Install (on the server)
```bash
cd /srv/erp-production/erp-backend
deploy/production/test-sites.sh install app ~/erp-app-release --confirm api.tsxmr.com
deploy/production/test-sites.sh install console ~/erp-console-release --confirm api.tsxmr.com
```
- Each command refuses before touching the edge if the release targets another API, or the hostnames, hash, CORS or
  activation are wrong.
- Each ends by checking 401 without the password on every path, and the API's exact CORS grant.
- `deployments.log` records the new and previous release.
- Then delete `~/erp-app-release` and `~/erp-console-release`; the copies under `WEB_DIR` stay.

### 5.5 After installing
1. `deploy/production/smoke.sh --allowed-origin https://erp-test.tsxmr.com`.
2. The same with `https://dukan-test.tsxmr.com`.
3. `curl -s https://api.tsxmr.com/api/health/ready`: ready, 101 applied, 0 pending.
4. The image is still `erp-api:f5da650…`.
5. Without the password, both sites answer 401.
6. Certificates: unchanged.
7. tsxmr.com unchanged: run `ops/verify-production`.
8. Re-run §5.1. The counts must equal those before: same administrator, business, Owner, store, grant and data.

### 5.6 Rollback (test sites only; the API and its data are never touched)
```bash
deploy/production/test-sites.sh rollback app 20261020T110732Z --confirm api.tsxmr.com
deploy/production/test-sites.sh rollback console 20261020T110759Z --confirm api.tsxmr.com
```
`off app|console|all` disables them instead.

### 5.7 Live test steps (owner, on the PC first)
1. On `https://erp-test.tsxmr.com/login`, tap each field: one rounded ring, no inner rectangle, nothing moves.
2. Sign in as the test Owner. The ERP opens, because the grant is active.
3. Business settings → Where money arrives → Add an account:
   - try each service, and type the name;
   - switch services: the name stays;
   - Save empty: the message appears; type the name, then Save.
4. Team → New team member:
   - type Name, Phone, Email;
   - change the role and the store: everything stays;
   - a wrong phone shows its message; correct it, then submit. The invitation reference is shown and nothing is sent.

### 5.8 Record
- Update `docs/103` §5 with the release names, the checks and the counts.
- Update the handoff and the session log.
- Commit and push `erp-docs` only.

### 5.9 Physical-iPhone checklist (owner, Safari, after §5.4)
1. **Sign-in:** tap Email or WhatsApp number, then Password. Each shows **one** rounded purple ring, with no inner blue
   rectangle and no jump. If Safari offers to fill the fields, the filled fields stay in the app's colours.
2. **Add an account:** one tap on "Name staff will see" opens the keyboard.
   - Type, delete, select and paste.
   - Switch Bankily/Sedad/BIM Bank/Other: the text stays.
   - The field stays visible above the keyboard, the sheet scrolls, and Save is reachable.
3. **New team member:** one tap each on Name, Phone and Email.
   - Type in each; use the keyboard's ‹ › to move between them.
   - Change the role and the store: nothing is erased. The sheet scrolls, and "Add to the team" is reachable.
4. **Setup code** (only with a fresh test business and code from the console; never re-use the existing Owner's):
   - Sign-in → "I have a setup code": paste the code and choose a password;
   - signing in works at once;
   - before any grant the screen says "No active access yet", never "waiting for approval";
   - after "Grant access (no payment)", "Check again" opens the ERP.
5. **Arabic:** repeat 2 in Arabic. The layout is right to left, and typing is unaffected.

## 6. Open items
- **`X-Robots-Tag` on the unauthenticated 401.** Root cause: Caddy's `basic_auth` returns its 401 as an error, and the
  error path writes a fresh response without the site's `header` block. Fix: a `handle_errors` block with the same
  header in `test-app.caddy` and `test-console.caddy` (erp-backend). Required before outside testers, with the owner's
  approval as a separate change.
- **The Storage Box and an off-site restore proof.** Mandatory before outside testers, real data, live email, WhatsApp
  or payments.
- **The physical-iPhone retest** (§5.9).
- **WEB-F01** (`docs/83`).
- **Seen, not changed:** in Arabic, the store switch in New team member shows the English word "On", partly under the
  switch's knob (screenshot `new-member-ar-*.png`). It predates this phase; it is a separate, small fix.
