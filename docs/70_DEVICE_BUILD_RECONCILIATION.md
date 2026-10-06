# 70 — The iPhone was running an older bundle: reconciliation, the build identifier, and five corrections (2026-10-06)

The user's brief of 2026-10-06 ("Continue as CLAUDE-B with a focused device-build reconciliation and
visible-regression correction"): four iPhone screenshots taken at 12:23 (phone time) on 6 October contradicted the
completion report of 5 October. This page records what the screenshots prove about the code the phone was running,
what cannot be known from this container, the development-only build identifier added so the next screenshot settles
it, the exact safe way to bring the Windows checkout level, and the five corrections — two of which were genuine
defects at the pushed commit. Decisions **D145–D149** in `docs/21`; the device run is `docs/24` §57.

**Repository state is not runtime state.** Everything in §4–§6 is verified in this container (tests, a real browser
against the committed web export, the real API on a disposable database). Nothing in this phase ran on an iPhone:
every device line is marked **NOT DEVICE VERIFIED** with the steps that verify it.

---

## 1. What the screenshots prove

| Fact | Evidence |
|---|---|
| The remote mobile HEAD at the time of the screenshots was `81cb599` (`reports-export`, pushed 2026-10-05 05:08Z); `master` was `f47a155`. | `git ls-remote` at takeover (handoff of 01:16Z). |
| The LogBox frame names `C:\wamp64\www\ERP\erp-mobile\app\notifications.tsx (69:9)`, with `<ErrorState …>` on 67, `) : (` on 68, `<FlatList` on 69, `data={rows}` 70, `keyExtractor` 71, `contentContainerStyle={styles.list}` 72. | Those line numbers hold for every commit from `e484b58` (2 Oct) through `81cb599`; on `master` the FlatList is on line 62. **The phone is on the `reports-export` line, not `master`.** |
| *Import stock* was still a row of More. | At `81cb599` the registry's `MORE_GROUPS` has no `imports` destination and More renders `visibleGroups()` alone: that commit **cannot** show the row. The rendered test of §4 proves it for every role. |
| The Arabic notice still read the old *Restart needed / Close and reopen* words after a close-and-reopen. | At `81cb599` the first-time verdict uses the same words, so this line alone proves nothing about the commit; the two lines above do. |
| The bundle came from a Metro on the Windows PC, in development mode. | The absolute Windows path in the stack and LogBox itself (development only). The blue gear is `expo-dev-menu`'s floating **Tools** button, present in Expo Go and in development builds alike — it does not say which. |

**Conclusion.** The JavaScript the phone showed predates `81cb599`: the checkout at `C:\wamp64\www\ERP\erp-mobile`
had not been pulled to `81cb599`, or Metro was still serving a bundle built before the pull. Three of the five
reported regressions (Notifications' warning, *Import stock* in More, the stale Arabic notice logic) are therefore
**not reproducible at the pushed commit** and were not "fixed again" — the code was re-verified instead (§4).

**What this container cannot determine** — and how the owner reads each one on the PC:

| Question | How to read it |
|---|---|
| The commit checked out in `C:\wamp64\www\ERP\erp-mobile` | `git -C C:\wamp64\www\ERP\erp-mobile rev-parse --short HEAD` |
| The branch Metro is serving | `git -C C:\wamp64\www\ERP\erp-mobile branch --show-current` (expected `reports-export`) |
| Whether `81cb599` is present locally | `git -C C:\wamp64\www\ERP\erp-mobile cat-file -t 81cb599` → `commit`, or `fatal` when it was never fetched |
| Whether Metro was restarted after the pull | the Devices screen's build line (§2): `readAt` is the moment Metro read the configuration |
| Expo Go, development build or installed app | the same line: *Expo Go*, *bare* (`npx expo run:ios`) or *standalone* |
| Whether the phone is on the intended Metro | the commit on that line equals the PC's `HEAD`; a different commit means another Metro, or a stale one |

## 2. The build identifier (D145)

`app.config.js` (new) extends `app.json` with `extra.build = { commit, branch, dirty, readAt }`, read with `git` when
Expo reads the configuration — at `expo start`, at `expo export` and at a native build. The **Devices** screen shows it
under *This device* **only in development** (`__DEV__`): *Development build (shown only in development)* — then
`81cb599 · reports-export · Expo Go` (a `+` after the commit means uncommitted changes), and *Configuration read
2026-10-06 01:24Z — restart Metro after pulling to refresh it*. A release build renders nothing there; the catalogue
keys exist in the three languages. Verified: `npx expo config --type public` carries the stamp; the rendered web export
(a release bundle) shows no build line (Playwright, §6).

The identifier is by design the checkout's truth, not the remote's: a screenshot of it is the proof the 6 October
screenshots lacked.

## 3. Bringing the Windows checkout level — safely

On the PC, in a terminal (PowerShell or cmd), **in this order**; stop at the first step whose answer you do not expect.
Nothing below resets, cleans, discards or overwrites your files.

```
cd C:\wamp64\www\ERP\erp-mobile
git status
```
Read it. Files you changed deliberately stay yours. If you see changes you do not recognise, stop and send the output.

```
git fetch origin
git branch --show-current
git log --oneline -1 HEAD
git log --oneline -1 origin/reports-export
```
The branch must be `reports-export`. If it is another branch, switch **only** when `git status` was clean:
`git switch reports-export`. (With your own uncommitted work: `git stash push -m "my work"` first, and `git stash pop`
after the pull — never `git stash drop`.)

```
git pull --ff-only origin reports-export
```
`--ff-only` moves your checkout forward to the pushed commit and **refuses** to do anything if your branch has commits
the remote does not have (it says "Not possible to fast-forward"). Then stop and send the output; do not merge, rebase
or reset.

```
npm install
```
`package.json` changed (the test tooling of D149); `app.config.js` needs nothing new.

Close every Metro window, then:
```
npx expo start -c
```
`-c` clears Metro's cache. Open the project on the phone **from this Metro** (the QR code of this window; close any
older one). Then **Devices → This device**: the commit shown must equal `git rev-parse --short HEAD` on the PC and
`readAt` must be after the moment you started Metro. If the commit is right and `readAt` is old, the phone is talking to
another Metro.

**JavaScript changes and native changes are not the same.** Notifications, More, Money, the Home header and the words
of the Arabic notice are JavaScript: a reload from the new Metro shows them. The Arabic **layout direction** is native
configuration (`app.json`: `expo-localization` without `supportsRTL`, §4.2): Expo Go cannot apply it, and an existing
development build does not have it — a **new native build** is required (`npx expo run:ios` on a Mac, or an EAS build),
installed on the phone, before the direction can be verified. Reloading Expo Go never applies native configuration.

## 4. The five reports, one by one

### 4.1 Notifications — "VirtualizedLists should never be nested inside plain ScrollViews"

*At `81cb599`:* `app/notifications.tsx` renders `<Screen padded={false} scroll={false}>`, and `Screen` with
`scroll={false}` mounts its body in a plain `View` (`components/ui/Screen.tsx`, the non-scrolling branch); the root
layout is a native `Stack` with no ScrollView; the loading, error and empty states are siblings of the list, not
wrappers. There is no same-direction ScrollView above the `FlatList`, so React Native's check (in
`@react-native/virtualized-lists`, raised through `ScrollView.Context`) cannot fire. The phone's warning came from the
older `<Screen padded={false}>`, whose default body is a ScrollView.

*Proved, not asserted:* `__tests__/notifications.test.tsx` mounts the real screen under jest-expo in its loaded, empty
and error states, walks every ancestor of the rendered `FlatList` and finds no ScrollView, and asserts React Native
raised no nesting warning — with a **control test** that renders a FlatList inside a ScrollView and requires the
warning, so a silent pass cannot be a mock that swallowed it. (The preset's ScrollView mock does not provide the scroll
context; `__tests__/mocks/ScrollView.tsx` adds exactly that.) The browser render of `/notifications` against the real
API logs no such console error either (§6). Nothing is filtered through LogBox.

*The blank toast:* the Notifications screen has **no toast call of its own**, and `toFriendlyError(…).body` is never
empty. A toast seen there was raised by an earlier action and survived navigation (toasts sit above the navigator and
an error stays 5.2 s), or came from one of the callers that could pass an empty string: the three catalogue screens
toasted `error.message` of an `ApiError` directly (`catalog/edit.tsx`, `catalog/new.tsx`, `catalog/categories.tsx`),
and `ApiError`'s message was built as `payload.message.join(', ')`, which is `''` when a server validation payload
carries `message: []`. Both are fixed at the source: the catalogue screens toast the friendly body, and the API client
never constructs an empty message (the status is the last resort). The 5 October guard (`safeToastMessage`) stays as
the backstop and still names any remaining caller in the development console.

*Device:* NOT DEVICE VERIFIED — `docs/24` §57 B.

### 4.2 Arabic — the restart notice that stayed

*What the screenshot shows:* a left-to-right layout with Arabic text (the chevrons at the end edge point right, the
list text is left-aligned), and the notice *يلزم إعادة التشغيل*. On the older bundle the notice was a persisted flag;
on `81cb599` it would have said the same words the first time, and *Expo Go cannot apply…* in Expo Go.

*The real finding of the audit:* `app.json` at `81cb599` configured `expo-localization` with `supportsRTL: true`, added
on 5 October in the belief that native builds need it. On iOS the option makes the module, at **every launch and before
React loads**, call `allowRTL(true)` and `forceRTL(<is the DEVICE locale right-to-left>)` (`LocalizationModule.swift`,
`setRTLPreferences`). On a phone whose system language is English or French that is `forceRTL(false)` — written over
the `forceRTL(true)` the app persisted when Arabic was chosen. **With that option a native build could never switch to
Arabic from the in-app setting, however often it was restarted.** It is removed (D147). Android needs no option:
Expo's manifest already carries `android:supportsRtl="true"`, and the module only forces a direction there when
`forcesRTL` is set.

*The runtime now (`lib/i18n/index.ts`, `lib/design/direction-restart.ts`):*
- `I18nManager.allowRTL(wantsRtl)` and `forceRTL(wantsRtl)` follow the **app's** language, both ways. (Always allowing
  RTL would let an Arabic-locale Android phone lay English out right-to-left.)
- The notice is `ok` when `I18nManager.isRTL` matches the language; `restart` while the request is pending; and only
  after a **genuine relaunch** that changed nothing, `expo_go` (in Expo Go: "Expo Go was restarted and keeps its own
  layout direction… restarting again will not help; the installed app switches") or `unsupported_build` (our build:
  "a newer build is needed… in a development session, reloading is not a restart").
- A relaunch is recognised by `Constants.sessionId`, new for every native process: the request is stored as
  `<language>@<session id>`, so a JavaScript reload (Metro, the developer menu) in the same process is **not** mistaken
  for the restart the OS needs — the false "this build cannot switch direction" a reload would otherwise produce.
- The words say what a restart is: *Close the app completely — swipe it away in the app switcher — then open it again.
  Reloading is not enough* (EN/FR/AR). Backgrounding the app is not a restart; `isRTL` cannot change without one.
- The language itself is written on change and read before the device default on every launch, independent of the
  session (unchanged).

*Device:* NOT DEVICE VERIFIED, and **impossible to verify without a new native build** — `docs/24` §57 C. Web
right-to-left (the document `dir`, verified in §6) is not native RTL and is not claimed as such.

### 4.3 Money — an open boutique with "Unknown until everything is known: Cash"

*How the state is reached:* D100 (28 September, the user's own correction then) let the Owner **keep** an unknown
drawer: "Keep preserves unknown amounts as unknown". A boutique that never counted a locked close and never set an
opening amount has an unknown drawer; keeping it opened the day on a figure nobody had, for the whole day. The card
then said exactly that. Either that, or an older phone opened the day with no decision at all.

*The invariant now (D146, supersedes that sentence of D100):*
- **Keep needs something to keep.** `withDrawerKnown` (`src/closing/opening-money.ts`) refuses `keep` while the
  drawer is unknown — 400 `opening_cash_unknown` — on the opening, the reopen and the Owner's review; nothing is
  written. `set` with **0** is the explicit answer for an empty drawer. A staff member's carried opening still carries an
  unknown drawer (D100 unchanged for them) and the day reads *awaiting the Owner's review*, where the same rule applies.
- **An open day whose drawer is unknown is the Owner's to set now.** `reviewableOpening` widens the review to an
  opening that left the drawer unknown (the Owner's own keep from before the rule, or a carried unknown drawer) and to
  an open day with no decision recorded (an older phone's opening); the review stands on its own then
  (`review_of_id` null). The amount is true from the review's instant; nothing is backdated.
- **The phone:** the sheet offers no *Keep* while nothing is known — it says *No previous amount to keep* and asks for
  the cash, *Set to 0* for an empty drawer; the Money card says *The drawer's opening amount has not been set for today*
  and, for the Owner while the day is open, offers **Set today's opening cash** (the same sheet). The card gained one
  short explanation line and nothing else; the *Money recorded today* card does not return. Opening still finishes only
  on the server's answer, in one transaction; a refusal keeps the entered values and the store stays closed (unchanged).
- Money and the Daily closing read the same server figure (`expected.cash`, unchanged).

*Verified:* backend specs (open, reopen, review: keep refused, set 0, carried unknown, a decision-less open day, keep on
a known carried drawer); pure tests of the sheet's rules; the real journey in a browser against the real API — a
manager opens the annex with carried amounts, the Owner's keep is refused by name, the card offers the action, the
sheet has no Keep, *Set to 0*, confirm, the card reads known and the view reads `reviewed` / `set` / `0` (§6).

*Device:* NOT DEVICE VERIFIED — `docs/24` §57 D.

### 4.4 Import stock in More

*At `81cb599`:* not in any More group and not a hub child; the Stock tab header shows it for `import.run` (the
Owner) while the business may write. The phone showed the older registry.

*Proved:* `__tests__/navigation.test.tsx` renders the real More screen with the server's own permission sets for the
Owner, the Store Manager and the Store Employee (copied from `erp-backend/src/rbac/role-permissions.ts`): no *Import
stock* row for any of them, and every section shown has at least one row (an empty section is not shown); renders the
real Stock tab and finds the header action for the Owner alone; renders `/imports` directly as an Employee and finds the
server's refusal in the app's words. The same in a browser against the real API for the three roles (§6).

*Device:* NOT DEVICE VERIFIED — `docs/24` §57 E.

### 4.5 The Home header card stopped before the screen margin

*Genuine at `81cb599`.* The tint is an absolutely positioned `Svg` with `width="100%"` inside the card, and the card
carried `padding: 16`. React Native's default layout conformance resolves an absolute child's percentage against the
parent's **content box** — inside the padding — so the tint was 32 pt short of the end edge: the card's right edge at
370 pt on a 414 pt screen instead of 402. CSS resolves against the padded box, which is why no web render ever showed
it. The card is now two views: the outer one owns the shape and the tint and carries no padding; the inner one carries
the padding and the content, symmetrically (`components/home/HomeHeader.tsx`, D148). The bell keeps its 48 pt target
inside the content; nothing else moved.

*Verified:* `__tests__/home-header.test.tsx` pins the structure (no padding on the tint's parent, the padding on the
content, the bell inside it); the browser matrix measures the card at 12 px from both screen edges, the bell inside it
with a ≥ 44 px target, and no overlap between greeting, date and bell at 320 and 393 px, 1× and 1.3× text, EN, FR and
AR (§6). The web cannot reproduce the native content-box resolution; the structural test is what guards it.

*Device:* NOT DEVICE VERIFIED — `docs/24` §57 F.

## 5. What changed where

- **erp-backend** `src/closing/opening-money.ts` (`withDrawerKnown`, `reviewableOpening`), `closing.service.ts`
  (the three call sites, the widened review), `dto/opening-money.dto.ts`, the three specs, `scripts/qa-boutiques.ts`
  (the seed sets 0). No migration: nothing in the schema changed.
- **erp-mobile** `app.config.js` (new), `app/devices.tsx` (the build line), `app.json` (`expo-localization` without
  `supportsRTL`), `lib/i18n/index.ts`, `lib/design/direction-restart.ts`, `lib/opening-money.ts`,
  `components/day/OpeningMoneySheet.tsx`, `components/day/useOpeningFlow.tsx`, `components/money/ExpectedMoneyCard.tsx`,
  `app/(tabs)/money-hub.tsx`, `components/home/HomeHeader.tsx`, `lib/api-client.ts`, the three catalogue screens, the
  catalogues (EN/FR/AR), the pure tests; `jest.config.js`, `__tests__/` (D149) and the test tooling in `package.json`.
- **erp-docs** this page, `docs/21` D145–D149 (and D143 amended), `docs/24` §57, `docs/63`, `docs/04` rule 25a, the
  session log, the handoff.

## 6. Verification in this container

See the handoff for the exact counts of the final run. The gates: backend `tsc` and every suite; mobile `tsc`,
`expo lint`, every node suite, the catalogue parity (three catalogues, identical keys), the rendered Jest suites
(`npm run test:render`), the web export, `expo-doctor` (the two checks that need the React Native Directory and the
schema endpoint are refused by this container's proxy — not a project failure).

**Browser evidence** (Playwright, the committed web export served from `127.0.0.1:8090`, the built API on a disposable
MySQL with the QA boutiques): the Home header matrix (6 configurations × checks), More and Stock for the three roles,
`/imports` opened directly, Notifications' console, the opening-cash journey, the Devices screen without a build line.
Files: scratchpad `ph3/shots/*.png` and `RESULTS.txt`. These are web renders; the phone's LogBox, native RTL and the
Yoga layout are not among what they can show.
