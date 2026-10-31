# 111 — Post-TestFlight feedback phase (D225)

The owner's brief of 2026-10-29, after the first TestFlight build (b1308200, 1.0.0 (1), mobile `2bf0a57`): ten feedback
areas from physical-iPhone testing, implemented as one coordinated phase on feature branches.

**Nothing was deployed.** No production or protected test site was touched. No migration was applied to any
persistent database. Nothing changed in DNS, server configuration, secrets, EAS variables or Apple settings. There was
no `eas build`, no iOS archive, no TestFlight upload, no build-number increment, no merge into a release branch, and
no rebase or force-push. The next TestFlight build waits for the owner's explicit, consolidated release.

## 1. Lineage

| Repository | Started from (the reviewed TestFlight lineage) | Branch | Head at the end of this session |
|---|---|---|---|
| erp-backend | `ce23e99` (`deferred-verification` = `superadmin-provisioning`, production, 0109) | `post-testflight-feedback` | `a13031d` |
| erp-mobile | `2bf0a57` (the TestFlight build b1308200) | `post-testflight-feedback` | `8d83b23` |
| erp-control-web | `7ddeea7` (`deferred-verification`, the deployed console) | `post-testflight-feedback` | `638f1d6` |
| erp-docs | `96cf01d` | `master` | this commit |

Commits, oldest first:
- **Backend:**
  - `420dc9d` calendar weeks;
  - `5fdc07d`, `28db96d`, `c414baf`, `2c85b2d` category pictures (0110);
  - `1bc51c3` bilingual names (0111);
  - `4e41aef` Employee ↔ Manager;
  - `76c4e4a` Acting Owner (0112);
  - `a13031d` notifications (0113).
- **Mobile:**
  - `74862f5` dialogs;
  - `f0a5dc1` calendar weeks;
  - `8895b21` category pictures;
  - `821bdec` names, and the export period label;
  - `b7697c0` sign-up names;
  - `5745875` RTL and Arabic;
  - `153e71c` camera explainer;
  - `9a45059` roles and Acting Owner screens;
  - `8d83b23` notification centre.
- **Console:** `638f1d6` bilingual names.

## 2. What changed, by area

### 2.1 Decision dialogs never truncate (mobile `74862f5`)
- The shared choice dialog draws each answer as a title and a description, with no line limit.
- The body scrolls inside `min(window − keyboard − margins)`, and Cancel and Confirm stay outside the scrolled body.
- The identification question uses the agreed copy in EN/FR and natural Arabic:
  - هذه القطعة بعينها / لها رقم IMEI أو رقم تسلسلي خاص بها;
  - طراز هذا المنتج / جميع القطع من هذا الطراز تحمل الرمز الشريطي نفسه.
- BottomSheet subtitles are no longer cut, and titles get two lines.

### 2.2 Arabic quality and RTL (mobile `5745875`, `153e71c`)
- **The iPhone row gap, the root cause.** React Native on iOS already resolves `textAlign: 'left' | 'right'` against
  the layout direction (`RCTResolveTextAlignment` in RN's iOS text layout), and the shared `textAlign()` helper flipped
  them a second time. So every start-aligned Arabic title was pushed to the far side of its row, a wide gap from its
  icon.
  - The browser does not flip, so the Chromium/WebKit checks never saw it.
  - The helper now returns `'left'` for start on native and computes the physical side only on the web.
  - `physicalTextAlign()` serves the few fixed sides: Arabic and Latin name fields, and the return-policy text.
  - `__tests__/rtl-alignment.test.tsx` pins both platforms.
- **تطبيق دكان** in every Arabic string (20 catalogue strings), the sign-in title and the brand lockup (one Arabic
  line, no letter-spacing).
- **Time filters:** هذا اليوم / هذا الأسبوع / هذا الشهر, and Today / This week / This month in EN, Aujourd'hui /
  Cette semaine / Ce mois-ci in FR. Pinned on every filter (`lib/calendar.test.ts`).
- **Translation parity** (`lib/i18n/translation-parity.test.ts`):
  - every Arabic value carries Arabic letters unless it is only placeholders, figures or listed technical terms;
  - no English sentence is copied into French outside an explicit list of shared words;
  - placeholders match in every language;
  - Arabic never says "Dukan".
- **Directional icons:** chevrons and back arrows already mirror. The collapsed chevron in file receiving now does
  too. Non-directional icons are not mirrored.

### 2.3 Bilingual names (backend `1bc51c3`, mobile `821bdec`, `b7697c0`, console `638f1d6`; migration 0111)
- **Two columns.**
  - `name` is the Latin-alphabet name, read by FR/EN. `name_ar` is the Arabic name, read by AR.
  - They exist on companies, branches and users.
  - NULL `name_ar` shows `name` and marks the record `nameIncomplete`. It is never blocked.
  - There is no backfill and no transliteration.
- **Rules** (`src/common/bilingual-name.ts`, mirrored as hints in `lib/display-name.ts`):
  - the Latin name has no Arabic letter;
  - the Arabic name has at least one;
  - neither has control or bidi-override characters;
  - "PS5 Center" and "مركز PS5" pass.
- **Compatibility with 1.0.0 (1).** Routes the released build calls accept its single name field under the old rule.
  A request that sends both names is held to both rules. The console, which ships with the API, requires both names.
- **Editing.**
  - In the app: Team edits a person's two names; More → Business and store names covers the business and its
    stores. These are Owner-only (`user.manage`, `settings.manage`, `branch.manage`).
  - In the console: a Names card, password-confirmed and platform-audited.
  - Each language is edited on its own, and the other is never touched.
- **Snapshots.**
  - Sales store the business, store and seller names in both scripts at confirmation (`sales.*_name_snapshot`).
  - The receipt prints the snapshot, or the live names for a sale before 0111.
  - A requested store keeps its Arabic name until it opens (`seat_allocations.label_ar`).
- **Search:** Team searches both names, and the console's business search matches either name of the business and
  of its people.
- **Shown in the reader's language:** headers, the store picker and all 22 screens that name the active store, the
  Home greeting, the sign-in account chooser, Team, receipts and the console.
- **Limitation:** approvals, transfers, unit timelines and reports still show the Latin name (§6).

### 2.4 Calendar weeks (backend `420dc9d`, mobile `f0a5dc1`)
- "This week" is Monday through Sunday in business dates, and the current week runs Monday to today, never a rolling
  seven days.
- There is one calculation on each side, `calendarWeekOf` / `weekToDate`.
- The dashboard compares a week with the same weekdays of the week before.
- The Results export names the period instead of "last N days" (mobile `821bdec`).
- **Decision for the owner:** a "day" keeps the established 06:00 business-day cut in Africa/Nouakchott (docs/50
  §3.1). So the week is Monday 06:00 to the next Monday 06:00, and a week equals the sum of its daily closings. The
  brief's literal "Monday 00:00" would split the night shift between two weeks. **The owner may choose 00:00 instead;
  it is a one-line change in each helper.**

### 2.5 Category pictures (backend `5fdc07d`…`2c85b2d`, mobile `8895b21`; migration 0110)
- **24 pictures,** with consoles, earbuds, screen protectors and cases drawn on the app's grid. Built-in keys map to
  them.
- **Custom pictures:** a shop's own category may be given one (`product_categories.icon`, `catalog.manage`).
- **Resolution order:** custom icon → built-in key → parent → neutral generic (accessory for counted stock,
  electronics otherwise, never a phone).
- **PS5 under Gaming consoles** is a console.
- **Where they show:** Stock rows, the unit detail, the sale detail, the quick-sell payment sheet, the category list
  and the picker.
- **Limitation:** the Receive screens, reports and catalogue lists keep their current tiles (§6).

### 2.6 Permission requests (mobile `153e71c`)
- A shared explainer comes before iOS's own prompt:
  - a picture;
  - three short benefits;
  - one primary action, which alone opens the prompt;
  - "Type it instead", which needs no permission.
- After a refusal it gives the Settings path in words and never asks again. There is no "Open Settings" button: the
  app's boundary test forbids opening any other app or address.
- **Not built (owner action):** the notification permission. The build carries no notification module and no push
  entitlement. Adding them is a native dependency plus an Apple/EAS change, out of scope. The explainer is ready to
  reuse, and the rule is to ask after sign-in, never at launch.

### 2.7 Notifications (backend `a13031d`, mobile `8d83b23`; migration 0113)
- **One catalogue** (`src/notifications/notification-catalog.ts`) classifies every type. A spec fails when a new
  literal type is written without a classification.
- **Levels** per account, synced across devices. They change only what is pushed: the centre keeps every authorized
  event.
- **Read state** is per person (`notification_reads`). One member reading a store broadcast leaves it unread for the
  others.
- **Push.**
  - Devices register with their locale.
  - Copy is composed per device language: the kind of event and the store, no figures, ids for the deep link.
  - Each delivery is a UNIQUE (notification, device) row claimed before sending, so a retry never pushes twice.
  - Delivery status and error codes are observable, with no message text.
  - **Off by default** (`PUSH_CHANNEL=disabled`). `expo` is ready for when the build carries the entitlement.
- **The self-action rule:** `notifications.actor_user_id` is set where the actor is known (sales, returns, transfers,
  price approvals, role changes, Acting Owner).
- **The centre** shows every title in the reader's language, with English bodies only for English readers. It has
  filters (All · Approvals · Sales · Stock · Money), mark-all-read, and the level screen.

**Notification matrix** (push decision; the centre always lists every event the person may see):

| Event | Filter | All activity | Important | Approvals only |
|---|---|---|---|---|
| Sale recorded, stock received, transfer received, price changed, day closed | Sales / Stock / Money | ✅ | — | — |
| Return approved/rejected, refund confirmed/corrected, cash difference, cash shortfall, overdue debt, below-cost cluster, day reopened/reclosed, sale on a closed day | Sales / Money | ✅ | ✅ | — |
| Transfer approved/shipped/rejected/cancelled/created approved | Stock | ✅ | ✅ | — |
| Price approval requested, return to review, refund to confirm, transfer to approve, loan to accept, consignment to accept | Approvals | ✅ | ✅ | ✅ |
| Price approval decided | Approvals | ✅ | ✅ | — |
| Staff role changed | (All) | ✅ | ✅ | — |
| Acting Owner appointed / removed (critical) | (All) | ✅ | ✅ | ✅ |
| Your own action | — | never pushed | never pushed | never pushed |
| Unknown new type | (All) | ✅ | — | — |

- **Defaults:** Important for Owners and Managers, Approvals only for Employees.
- **Audience:** exactly who may see the event in the centre. That is the person addressed, or the members of the
  store the event concerns (business-wide events reach the business). A preference never widens it.

### 2.8 Employee ↔ Manager (backend `4e41aef`, mobile `9a45059`)
- `PUT /users/:id/role` (`user.manage`).
  - **Promotion** chooses the stores the new Manager manages.
  - **Demotion** keeps the chosen stores as an Employee and leaves the other stores they managed.
- **Refused:** the Owner's role, one's own role, a store of another business, a change that changes nothing, and a
  new store without a free seat.
- **In force on the next request in every session.** Authority is resolved from `user_branches` on each request, and
  the token holds no role.
- **In the same transaction:** delegated grants the role cannot hold are pruned, the audit holds before and after, and
  the person is notified. A row lock serialises two changes to the same person.
- **Pending approvals** are never assigned to one person, so they stay in the queue, and a demoted Manager can no
  longer decide them.

### 2.9 The temporary Acting Owner (backend `76c4e4a`, mobile `9a45059`; migration 0112)

**Capability matrix:**

| | Acting Owner | Real Owner only |
|---|---|---|
| Price and below-cost approvals, expenses, cash movements, returns and exceptions, loans and consignments, stock adjustments and transfers, closing and reconciliation | ✅ | |
| Staff creation, activation, store assignment, Employee ↔ Manager | ✅ (never on the Owner's own record: `owner_protected`) | |
| Store settings, return policy, payment methods, reports, buying costs, profit, seat/store requests | ✅ | |
| Integration credentials (`integrations.manage`) | | ✅ |
| Appoint, extend, change or revoke an Acting Owner (checks the Owner ROLE) | | ✅ |
| The real Owner's name, contacts, password, MFA, role | | ✅ |
| Close the business, delete accounts, cancel the subscription, the Owner's portal | | ✅ (role-checked) |
| Ownership transfer, recovery codes, audit records | no route exists for anyone | |

- **Appointment.**
  - One active at a time: the business row's lock plus an overlap check.
  - It starts now or tomorrow at 08:00, and runs until a chosen day or until revoked.
  - The Owner's password is the step-up, after a confirmation showing who, from when, until when and what.
  - It is audited in the same transaction, and both people are notified.
- **Enforcement.** AccessService adds the delegated permissions in the stores the delegate works in, while
  `starts_at <= now < ends_at`, read on every request. So it starts and ends on time with both phones off, and a
  revocation applies on the next request.
- **History.** Triggers mean an appointment is never deleted, and the only change ever made is one revocation.
- **Routing.** Approval requests reach an active Acting Owner (`actingOwnersHolding`: price approvals, returns,
  transfers).
- **Visible state.** The delegate sees "Acting as Owner until …" on every screen (`/auth/me` `actingOwner`).
- **Step-up.** *(Superseded 2026-10-30, §7.5: the password and a WhatsApp one-time code.)* Store accounts have no MFA today, so the step-up is the Owner's password. The platform's MFA is the
  console's, not the shop's.

## 3. Schema and migration rehearsal

- **0110** adds `product_categories.icon` (nullable).
- **0111** adds `name_ar` on companies, branches and users; six name-snapshot columns on sales; and
  `seat_allocations.label_ar`. All are nullable.
- **0112** adds the table `acting_owner_delegations`, with CHECKs and two history triggers.
- **0113** adds `notifications.actor_user_id` and the tables `notification_preferences`, `notification_reads`,
  `push_devices` and `push_deliveries`.

All four are additive. A code rollback to the TestFlight lineage never reads them. To reverse them, drop the columns
and tables after a dump (docs/22). The names, pictures, appointments, read marks and preferences made since are then
lost.

**Rehearsed only on a disposable MySQL 8.0.46** (`/var/tmp/d225-mysql`, 127.0.0.1:3399, never a persistent database):
1. **`deploy/ci-database-gates.sh` from empty, through 0113:**
   - the identities, strict sql_mode and the permission catalogue;
   - what each identity cannot do;
   - every real-MySQL spec, including the three new D225 specs.
2. **0109 → 0111 with data:**
   - rows in every altered table, then a mysqldump backup, then `prisma migrate deploy`;
   - the 0109 columns compared byte-identical, and every new column NULL;
   - an Arabic name round-tripped as `D985D8B1D983D8B2…` (utf8mb4);
   - the backup restored into a fresh schema, equal to the 0109 state.
3. **0112 and 0113** were applied to the disposable `grace_ci` and exercised by their real-MySQL specs.

## 4. Tests and CI evidence

- **Backend:**
  - full suite 5126 passed (104 env-gated skipped); tsc, `prisma validate` and the secret scan clean;
  - real-MySQL specs on the disposable server: `role-change.mysql` 4/4, `acting-owner.mysql` 5/5,
    `notifications.mysql` 4/4, plus the existing 88 in the gates;
  - CI (security) green on every pushed commit, latest run 40980536174 on `a13031d`.
- **Mobile:**
  - tsc clean; lint 0 errors;
  - every pure test file passes (CI's `lib`/`components` loop);
  - jest 49 suites, 435 tests;
  - CI (security) green on `8d83b23` (run 40980979163). The two earlier red runs, on `b7697c0` and `153e71c`, were
    pinned-test updates fixed in the next push.
- **Console:** typecheck clean; vitest 647/647; `build:preview`, `audit-links` and `audit-bundle` pass. CI run
  40981629622 on `638f1d6` was in progress when this was written.
- **Not run this session:** the Chromium/WebKit visual workflows (`ops/visual-check`, `ops/render-tests`). Run them on
  the final heads before the consolidated release. Automated WebKit does not replace the physical iPhone (§5): §2.2 is
  exactly a defect only the phone shows.

## 5. Physical-iPhone retest checklist (after the owner authorises a consolidated build)

1. **Arabic rows:** Home, More, Stock and Team rows. The title sits next to its icon, and the value and chevron at
   the far end. The same in EN and FR, and in light and dark.
2. **تطبيق دكان:** on the sign-in header and the brand lockup in Arabic; Dukan ERP in EN/FR.
3. **Unknown code:** scan a code that is not an IMEI and read both answers in FR in full at 320 pt and at the largest
   text size. Cancel must stay reachable.
4. **Time filters:** Money, Results and agent reports read Today / This week / This month (AR هذا اليوم / هذا الأسبوع /
   هذا الشهر). On a Sunday "This week" starts the previous Monday; on a Monday it is that day only.
5. **Pictures:** a PS5 under Gaming consoles shows a console in Stock, its unit page, the sale detail and Quick sell.
   Give a custom category a picture.
6. **Camera:** deny the camera, see the explainer and the Settings path, and type the code instead. Allow it from
   Settings and scan.
7. **Names:**
   - complete the business's and a store's Arabic names in More → Business and store names;
   - in Arabic, the header, store picker and greeting show them;
   - in FR the Latin names;
   - an old receipt keeps its old names after a rename;
   - Team search finds a person by either name;
   - sign up a new business with both names.
8. **Roles:** make an Employee a Manager of one store. On their phone, Manager actions work at once without signing
   out. Make them an Employee again and confirm Manager actions are refused at once.
9. **Acting Owner:**
   - appoint a Manager until the end of today, with the password; they see "Acting as Owner until …" and can approve a
     below-cost price;
   - they cannot open Acting Owner appointment or edit the Owner;
   - remove the appointment and confirm their power ends at once;
   - leave a timed appointment to expire with the phones off.
10. **Notification centre:**
    - in AR every row is Arabic;
    - filters narrow the list;
    - "Mark all as read" clears the badge on a second phone signed in as the same person, but not for another member;
    - choose a push level and see it on the other phone.
11. **Push:** not testable until the build carries the notification module and the APNs entitlement (owner decision).

## 6. Known limitations and not done

- **Push on the phone:** no notification module or entitlement is in the build. No device registers until then, the
  server sender stays disabled, and deep links from a push in foreground, background and cold launch remain untested.
  The centre's tap already lands on the exact record, and a removed or unauthorized record answers on its own screen.
- **Names** in approvals, transfers, unit timelines, closing reports and the notification payloads still use the
  Latin name. The fields reach the app where listed in §2.3.
- **Pictures** are not yet on the Receive screens, reports or catalogue product lists.
- **The week starts at 06:00** (§2.4), awaiting the owner's choice.
- **The Arabic review** covered the brand, the filter labels, every new string of this phase and the parity test. A
  line-by-line native review of all 4,300 Arabic strings is still worth an Arabic-speaking reviewer's pass.
- **The visual workflows** were not run (§4).

## 7. Continuation, 2026-10-30 (the owner's brief: the 06:00 week kept, native push required, no TestFlight)

Heads at the start: backend `a13031d`, mobile `8d83b23`, console `638f1d6` (its CI run 40981629622 succeeded), docs
`c80f1e7`. Heads at the end are recorded in `CURRENT_HANDOFF.md`.

### 7.1 Native push (mobile `2d34f87`, backend `8325246`)

- **Module and entitlement.**
  - expo-notifications `~58.1.6` (the version SDK 58 pins).
  - Its config plugin in `app.json`, with `mode: production`: the iOS `aps-environment` entitlement and no background
    mode.
  - iPhone only, on the existing EAS project. **No build was made.**
- **Registration.** `lib/push.ts` is the only module that speaks to the library.
  - It registers after sign-in, again when the token rotates (naming the replaced token, which the server revokes in
    the same call), and when the language changes.
  - Registration is idempotent.
  - Each phone carries its own language.
  - A person may have several phones.
- **Unregistering.** Signing out unregisters the phone while the session still works.
- **Server: `PushDevicesService`.**
  - The token is unique across businesses and is read with the system client.
  - A counter phone that changes hands — even to another business — moves to the newcomer.
  - Concurrent first registrations end as one row.
  - A person who is deactivated or deleted is never pushed: the dispatcher's audience requires active users.
- **No push on the web.** The web build has none (`lib/push.web.ts`), so the library stays out of the web bundle.
- **Delivery.** Sending stays off: `PUSH_CHANNEL=disabled` until the release explicitly enables it.

### 7.2 The pre-permission

- **When the app asks.**
  - Only right after a sign-in (password or completed registration).
  - Never at a cold launch with a restored session.
  - Never again after "Not now", which is remembered on the phone.
- **What it shows.** The app's own explanation, then iOS's prompt from "Enable notifications".
- **Turning it on later.** Notifications → This phone: on / Enable / after a refusal, the steps and **Open Settings**.
- **The one approved way out.** `openAppSettings()` in the browser guard (`lib/navigation/no-browser.ts`).
  - It calls `Linking.openSettings()`: no address in, none built.
  - It is reached only by `PermissionExplainer`, so the camera explanation has it again.
  - `lib/access-boundary.test.ts` pins its body and its single caller.

### 7.3 Opening a notification (backend `ba958f7`, mobile `2d34f87`)

- **Typed destinations.** Every emitter writes a typed destination (`src/notifications/notification-target.ts`):

  | Event | Opens |
  |---|---|
  | sale | the sale |
  | return / refund | the return |
  | stock received | stock, for the store that received it (it was a business-wide broadcast) |
  | price change | the product (and unit) |
  | expense | the expense |
  | cash difference | the discrepancy |
  | closing | that day |
  | loan / consignment | the record |
  | price approval | the approval |
  | transfer | the transfer |
  | anomaly | analytics |
  | role change | the person (their own account) |
  | Acting Owner | its screen |

  There is no receiving-record screen in the app, so a stock receipt opens stock. A receiving-record screen would be
  a new feature, not built here.
- **`GET /notifications/:id/open` decides at the moment of opening.** In order:
  - is the notification still the person's;
  - does the record exist;
  - does the person hold **today** the permission its screen requires, in the record's own store.
  It answers `ok` (kind, id, store), `unavailable`, `unauthorized` or `no_destination`.
- **The app.** `/notification-open` switches to the record's store, then gives way to the screen mapped from the
  kind (`lib/navigation/notification-route.ts`). Otherwise it says "No longer available" or "Not available to you",
  showing nothing of the record. The stored link is never followed.
- **Foreground, background and cold start.** All go the same way. A tap before sign-in waits for the sign-in. The
  same tap reported twice navigates once.
- **Fixed on the way.** A proposed loan or consignment was written into the **proposer's** business, so the business
  asked to accept it never saw it. It is now written into the other business.
- **Proven by Jest, not on a device.** APNs delivery, a real background tap and a real cold start need the physical
  build (§5).

### 7.4 Every event worded (mobile `2d34f87`, backend `596e434`, `33f7f6d`)

- **Coverage.** All 34 catalogued events have a title and a body in EN, FR and AR (`lib/notification-copy.ts`).
- **Composed from stored fields.** Reference, amount, count, date, the store, and the actor in the reader's script.
  The server now stores these on sales, stock, prices, closings, cash differences, loans, consignments and transfers
  (with the Arabic store and actor names).
- **Isolation.** Values are isolated (FSI…PDI) so an Arabic sentence keeps their order.
- **The stored English is never shown.** An old row without fields reads "Open it to see the details" in the
  reader's language.
- **Tests.** `lib/notification-copy.test.ts` checks every event × language:
  - no placeholder;
  - no Latin word outside an isolated value in Arabic;
  - the store's name in the reader's script.

### 7.5 Acting Owner step-up (backend `c32cf88`, migration **0114**)

- **What is asked.** Appointing, removing and an "until revoked" appointment ask for the Owner's password **and** a
  one-time code sent to the Owner's verified WhatsApp number.
- **The existing second factor.** That code is store accounts' existing second factor: `OtpService`, as account
  deletion uses it, with its hashing, single use, expiry, attempt lock, send limits and throttle. Store accounts have
  no TOTP; it is the platform administrators'. No WhatsApp configuration was touched.
- **Bound to one change.** A code asked for "Mohamed until Friday" cannot confirm "Aminetou until revoked". A change
  is a removal and an appointment, each confirmed.
- **0114 `acting_owner_step_up`.** Additive: one value appended to the two OTP purpose enums, so no other code can
  confirm an appointment and this code confirms nothing else.
- **Portal handoff.** Issuing a portal ticket now requires the Owner **role**. An Acting Owner holds `settings.manage`
  and could mint one before.
- **Renewal and cancel.** Renewal-side store routes stay allowed. Permanent cancellation exists only behind the
  platform administrator's guard.

### Acting Owner permission matrix (D225)

Paths are repository-relative (erp-backend unless stated).
Abbreviations: **powers** = `src/acting-owner/acting-owner-powers.spec.ts`, **svc** = `src/acting-owner/acting-owner.service.spec.ts`, **stepup** = `src/acting-owner/acting-owner-step-up.spec.ts`, **rules** = `src/acting-owner/acting-owner-rules.spec.ts`, **mysql** = `src/acting-owner/acting-owner.mysql.spec.ts` (needs a database: skipped unless `ACTING_ROOT_URL`/`ACTING_APP_URL` are set).

#### Forbidden to the Acting Owner

| Operation | Acting Owner | Refusal | Proven by (file › test) |
|---|---|---|---|
| Appoint an Acting Owner (and ask for its code) | Forbidden | 403 `owner_only` | powers › "cannot appoint, change or remove an Acting Owner, nor even ask for the code: 403 owner_only"; mysql › "the delegate cannot appoint anyone nor remove their own appointment…" |
| Change or extend an appointment (no change route exists: it is revoke + appoint) | Forbidden | 403 `owner_only` on both halves | powers › same test (revoke + appoint, both refused) |
| Revoke an Acting Owner, including their own appointment | Forbidden | 403 `owner_only` | powers › same test; mysql › same test |
| Edit the real Owner's name, phone, email or credentials | Forbidden | 403 `owner_protected` | powers › "cannot change the real Owner's name, contacts or credentials, nor deactivate them: 403 owner_protected"; `src/users/user-management.service.spec.ts` › "is edited only by somebody who holds the Owner role — never by an Acting Owner" |
| Deactivate (remove) the real Owner | Forbidden | 403 `owner_protected` | powers › same test (`isActive: false`) |
| Demote or change the real Owner's role | Forbidden | 403 `owner_role_fixed` | powers › "cannot change or demote the real Owner's role: 403 owner_role_fixed"; `src/users/role-change.service.spec.ts` › "never changes the Owner, and never one's own role" |
| `integrations.manage` (WhatsApp/push credentials) | Forbidden (never delegated) | 403 `permission_denied` (`missing: ['integrations.manage']`) | powers › "does not hold integrations.manage: a route requiring it answers 403 permission_denied"; rules › "are the Owner's, less what is never delegated"; svc › "a scheduled start: …" (asserts it is absent while in force) |
| Close the business (account deletion of the company) | Forbidden | Not a 403: the deletion route is the caller's own. For a delegate `kindFor` is `personal_login`, so only their own login can ever be deleted | powers › "cannot close the business: their deletion request only ever deletes their own login" |
| Open the Owner's subscription portal session | Forbidden | 403 `owner_only` | powers › "cannot open the Owner's subscription portal session: 403 owner_only" |
| Permanently cancel the subscription | Forbidden | 401: only `POST platform/businesses/:id/cancel` exists, behind `PlatformAdminGuard`. No store route cancels | powers › "cannot cancel the subscription or read the audit log: platform-administrator routes refuse a store session (401)"; powers › "cancel a subscription and read the audit log only behind the platform administrator's guard" |
| Read the audit log | Forbidden | 401: only `GET platform/audit`, behind `PlatformAdminGuard` | powers › same two tests |
| Change or delete audit rows | Forbidden to everyone | Database trigger | mysql › "audits the appointment in the same transaction, and the database will not let the audit be edited" |
| Transfer ownership | Forbidden (no route) | — | powers › "offer no ownership transfer at all" (route census) |
| Owner MFA / recovery codes | No store route exists. TOTP MFA is for platform administrators only | — | powers › route census (no such store route) |

#### Allowed to the Acting Owner (while in force)

| Operation | Acting Owner | Proven by |
|---|---|---|
| All of `ROLE_PERMISSIONS.owner` except `integrations.manage` (approvals, below-cost sales, expenses, returns, loans, stock, closing, `user.manage`, `settings.manage`, reports and costs) | Allowed | rules › "are the Owner's, less what is never delegated"; svc › "a scheduled start: nothing until then; from then, the Owner's permissions; …"; powers › "holds the delegated Owner permissions…"; `src/rbac/access.service.spec.ts` › "a temporary Acting Owner (D225)" |
| Subscription renewal-side requests: `platform/my-subscription` (view), seat/store/activity requests, `payment-instructions` (all `settings.manage`) | Allowed | powers › "does not hold integrations.manage…" (the `settings.manage` guard passes) |

#### Lifecycle guarantees

| Guarantee | Proven by |
|---|---|
| Appoint needs password **and** the WhatsApp code for that exact appointment, including "until revoked" | svc › "an appointment until revoked is refused without the code, and with a code sent for another change"; svc › "password and the right code: appointed until revoked…" |
| Wrong password: no code sent, nothing changed | svc › "the password comes first: a wrong one sends no code and changes nothing" |
| Revoke needs its own code; change = revoke + appoint, each confirmed | svc › "a removal needs its own code too; changing an appointment is a removal and an appointment, each confirmed" |
| Code goes only to the verified WhatsApp number, uses the existing OTP service and its send limits; bound to one change; single use; attempt lock | stepup › all 8 tests |
| Only one active delegation, no overlap (an open end blocks later ones; back-to-back is allowed) | svc › "only one active delegation…"; svc › "an appointment until revoked blocks any later one…"; rules › "overlapping windows clash; back-to-back ones do not"; mysql › "two appointments at once…" |
| Scheduled start | svc › "a scheduled start…"; rules › "a scheduled appointment is live but not yet in force" |
| Expiry checked on every request by the clock, with no job; afterwards the delegate holds exactly their own role again | svc › "a scheduled start: … at the end, back to their own role — no job runs"; mysql › "starts at its time and ends at its end, with nothing running…" |
| Revocation takes effect immediately | svc › "a revocation ends it on the very next request"; mysql › same |
| Audit rows are written, including the step-up method and challenge | svc › "password and the right code…", "a removal needs its own code too…"; mysql › "audits the appointment…" |
| The person who acted is never pushed their own action (`actorUserId`); the delegate is pushed the appointment | svc › "both are told, with a link to the Acting Owner page; …"; svc › "what the Acting Owner does themselves is never pushed back to them (actorUserId)" |

#### Mobile

| Behaviour | Proven by |
|---|---|
| Banner "Acting as Owner until …" in EN/FR/AR, with an end and without | `__tests__/roles-acting-owner-step-up.test.tsx` › "English", "French", "Arabic", "shows nothing when no appointment is in force"; `__tests__/roles-acting-owner.test.tsx` (EN) |
| Appoint sheet: password, then code; sends the change the code is bound to | `__tests__/roles-acting-owner-step-up.test.tsx` › "naming someone until revoked: …"; "no verified WhatsApp number: …" |
| Remove sheet: password, then code | `__tests__/roles-acting-owner-step-up.test.tsx` › "removing: the code is asked for that removal, then confirmed with it" |


### 7.6 Week, Employee ↔ Manager (backend `fce43e3`, mobile `2430b31`)

- **The week.** A "Monday–Sunday business week, using the existing 06:00 business-day cutoff", `Africa/Nouakchott`.
- **The shared table.** One table of instants is shared verbatim by both suites: Monday 05:59 vs 06:00, Sunday night
  into Monday, 1 November / 1 December / 1 January at 05:59 vs 06:00, a week spanning a month and a year. It holds
  under several process time zones.
- **Seven days make the week.** They meet end to end; the agent report's week equals the sum of its seven days.
- **Bug fixed.** Before the server answered, "This week" used the UTC date, so Monday 00:00–05:59 showed the new week
  for a moment. It now applies the 06:00 rule.
- **Employee ↔ Manager.** Re-confirmed:
  - who may change roles, and that the Owner is untouchable;
  - next-request effect;
  - grant pruning;
  - audit before/after;
  - the person notified and the actor not pushed;
  - a repeat refused unchanged;
  - the row lock.

### 7.7 Rehearsal 0109 → 0114 (disposable MySQL 8.0.46 only)

- **Seed.** Built from 0109 and seeded: 3 businesses, 3 stores, Owner / Manager / two Employees with their roles and
  store assignments, sales, receipts (purchases), seat allocations, categories, notifications, OTP challenges and
  intents.
- **Backup.** mysqldump, 459 221 bytes.
- **Upgrade.** `prisma migrate deploy` applied 0110–0114.
- **Results:**
  - Every 0109 column byte-identical.
  - Every new column NULL; every new table empty.
  - Name fallback: no Arabic name → the Latin one.
  - An Arabic name round-trips in utf8mb4 (`D985D8B1D983D8B2…`).
  - Refused, as they must be:
    - deleting a delegation;
    - changing a delegation other than revoking it;
    - an end before the start;
    - a duplicate push token;
    - a second delivery of one notification to one device;
    - a second read mark by one person.
  - A revocation is accepted.
  - The upgraded schema equals a fresh-from-migrations schema: 3 449 lines of columns, indexes, CHECKs, triggers and
    foreign keys.
  - The backup restored into another schema equals the 0109 state.
  - All three databases dropped afterwards.
- **Rollback boundary.** Every migration is additive. Before the release writes anything, rolling back is restoring
  the pre-migration dump (docs/22). After it has written — Arabic names, delegations, device tokens, read marks,
  deliveries, step-up codes — a dump restore loses those rows. The strategy is then **forward-fix**: new code over the
  same columns. Nothing in 0110–0114 needs reversing for old code to run: an older build ignores the new columns and
  tables. The one exception is 0112's triggers, which still forbid deleting a delegation, as intended.

### 7.8 Bilingual names and illustrations everywhere (backend `4cf32b3`, mobile `e4e666a`, `0569bc3`, `c006f71`)

Two parallel workers started this and stopped at the account's usage limit. Their partial work was parked on
`wip/d225-names-illustrations`, then finished, verified and committed on `post-testflight-feedback`. The WIP branches
are superseded.

**Names — server.**
- An additive `…Ar` field sits next to every Latin name a screen reads:
  - approvals; transfers (every person in the timeline); loans and consignments (the other business);
  - unit history; sales, payments, policy override and cancellation; returns, refunds and corrections; expenses;
  - money positions and anchors; closing; the debt ledger; analytics (stores and sellers); goals;
  - catalogue stock by store; scanner proposals; team seats; the account.
- Report documents carry `companyAr` and `branchAr`; an export's store label uses the export's language.
- The Owner's WhatsApp closing notice names the store in the Owner's language.
- The below-cost anomaly carries the seller's Arabic name.
- No schema change. Immutable records keep their snapshots.

**Names — the server audit.** `src/common/bilingual-name-audit.spec.ts` scans every Company/Branch/User name select
and read: 207 carry the Arabic twin. 141 are classified, each with its reason:
- platform console, provisioning, invitation and billing text;
- WhatsApp templates;
- the stored English fallback text of notifications;
- immutable snapshots that would need a new column — the agent records' `recordedByName` and the counted-float anchor.
  These are listed, not migrated;
- English API errors;
- internal lookups;
- a counterparty's single name.

A new unclassified occurrence fails the spec.

**Names — the app.**
- Every one of those screens reads the reader's script: `nameIn(latin, arabic, language)` or `displayName`.
- `lib/bilingual-names-audit.test.ts` fails on a screen that reads such a name without its Arabic twin. Agent screens
  stay Latin; they show the same immutable snapshots.
- An Arabic report PDF prints the business and store in Arabic; the file name stays Latin.

**Illustrations.** The category's picture appears on:
- receive, quick receive and receiving from a file;
- the catalogue list and product details;
- stock;
- sell: results, the stock picker's units, the chosen item and the cart;
- sale details and payment, and sales history rows.

`lib/category-illustration-surfaces.test.ts` pins each surface. The sell picker's older "no pictures" pin is scoped to
its three ways, as its title says.

### 7.9 Still open at writing

- **The Chromium/WebKit visual workflows** were retargeted to the final heads: `ops/visual-check` `ccd91dd` (seed now
  sends the Arabic names) and `ops/render-tests` `f9df297`. Results are recorded in CURRENT_HANDOFF.md.
- **The D219/D223/D224 journeys and the full layout matrix** are covered only as far as those workflows cover them.
  Automated WebKit on Linux is not a physical iPhone.
- **Release-time gate** (needs the build, the owner's authorisation and Apple):
  - confirm the APNs key is attached to the EAS project's iOS credentials (EAS manages it on the first build that has
    the entitlement);
  - set `PUSH_CHANNEL=expo` on the release backend;
  - then the physical checklist in §5, plus foreground, background and cold-start taps.

## 8. Second continuation, 2026-10-30 evening (CLAUDE, local; the owner's brief §§2–11)

### 8.1 Visual workflows on the D225 heads (backend `4cf32b3`, mobile `c006f71`)

- **render-tests 41110132839: passed** (the owner's report, on the final heads).
- **visual-check 41110129486: failed on tooling, not the app.** Its fixtures predated D225's required Arabic
  business and person names. The brand checks passed 44/44 in Chromium and WebKit.
- **The replacement visual-check 41114111688** (tooling `0b8a878`): failure in the steps D219 regression, WebKit,
  Chromium and the business count. Brand passed 44/44 in both engines; the access journey 21/21 (WebKit).
  - **Every remaining failure matches a check that D225 made stale. Each still needs proof by reproduction**, so
    none is waived:
    - `register …: Continue on an empty step focuses its first field` and `Back twice … still filled` (EN/FR/AR): the
      first step now carries names in both scripts;
    - `setup|join|verify ar: the shared header (Dukan ERP …)`: the Arabic product name is now تطبيق دكان;
    - `New team member: the fields are the same elements … — true,true,true`: every value is true, but a second-script
      name field was added.
  - **Not yet explained:** both engines' logs end without a summary (after "team sheet fr light 390"); the D219 input
    matrix ended on a `TimeoutError`; the business count "before" is empty.
  - A CI build of console `638f1d63` + app `c006f71` (`ops/build-test-console` `74b9b26d`) was started to reproduce
    them locally.

### 8.2 The mouse intake crash in TestFlight build 1.0.0 (1): evidence first

**Production, read only:** structure, counts and times only; no names, identifiers, prices or costs.
- Since 2026-10-29 there are **3 products, 3 purchases (one line each) and 3 `POST /purchases`, all 201.** No 4xx or
  5xx on purchases. No purchase shares a client key with another.
- **No partial product** (none without a unit or stock), **no orphan unit**, **no duplicate serial**.
- The mouse is `pcaccessories.mice`, tracking `serial`, created **10-30 09:38:22**: 1 unit, 1 purchase line, cost known
  on both.

**The request timeline (API log, 10-30, UTC):**

| Time | Request | Reading |
| --- | --- | --- |
| 09:32:14 | `POST /scan` 201 | the typed serial classified, opening the product form |
| 09:32:19 | `GET /categories` | the form loads its categories |
| 09:32:58 | `GET /products?active=…&q=…` 200 | Save: the exact-product lookup both save paths run first |
| — | *no write request* | no `POST /products`, no `POST /purchases`, no `POST /scan` |
| 09:33:01 | `POST /devices/adopt` | the app starting again: the crash fell between 09:32:58 and 09:33:01 |
| 09:33:33 | `POST /scan` 201 | the restored details classified again |
| 09:38:22 | `GET /products?q=…`, then `POST /purchases` 201 in the same second | the retry, in one purchase: the only one |

**Conclusions (evidence):**
- **The first save never reached the server as a write.** Nothing was committed, so there is nothing to clean up and no
  duplicate.
- **The crash was on the device,** after the lookup on Save and before any further request.

**Hypothesis (strong, not yet proven):** the first form was opened from the **multi-item Receive** screen.
- `newProductParams` in `app/receive.tsx` passes no `intake=quick`. The product form then runs "for the delivery": it
  shows **no buying cost** (by design, cost is entered per line back in Receive). On Save it runs the lookup, writes a
  draft into memory and calls `router.back()` — **no write request**. That matches the timeline exactly.
- Receive's focus handler would first `lookUp` the serial (a `POST /scan`), and none was sent. So the failure is in the
  navigation back from `catalog/new` to Receive, before Receive's focus handler ran. That is the seam of the 2026-10-28
  freeze.
- The retry showed the cost field and saved in one purchase: the **Quick receive** path (`intake=quick`).
- An unhandled JavaScript exception closes a release app, which TestFlight reports as a crash.

**Still needed:**
- Apple's crash report for build 1 (TestFlight → Crashes). App Store Connect was signed out in the session's Chrome;
  the owner is to sign in.
- A reproduction on disposable data.

The fix is specified by the owner's brief §3 whatever the exact exception: one intake with the cost always shown, the
recoverable states, and idempotent retries.

### 8.3 Auto-approving businesses the console creates (brief §8): the state map, and a proposal awaiting the owner

**The states as built** (backend `4cf32b3`):
- Console "New business" and public registration go through the same `RegistrationService`. The subscription starts
  `pending_activation`; the console's note says "Awaiting approval".
- **Approve** (`subscription.approve`) moves `pending_activation` or `rejected` to **`activated` with a paid period end**
  (`currentPeriodEnd`, from N months or a date). **Approval and access are one act: there is no "approved but not
  paid" state.**
- **The grant** (`subscription.activate_grant`) is the separate, audited no-payment path: `isComplimentary`, a reason
  and a duration.
- A payment (`payment.record_and_confirm`) is recorded on its own and activates nothing.
- Stores beyond the first follow the store-allocation requests. They are out of scope here and stay as they are.

**So "approve at creation" cannot simply be added.** It would either grant a period that no payment covers (forbidden),
or need a new state.

**Options:**
1. **Create with access in one step** (recommended; no schema change):
   - the console's New business form gains a required **Access** choice, enforced on the server;
   - **Payment received** records the confirmed payment, then activates for the paid period, in one audited request;
   - **No-payment grant** follows the existing grant rules: reason, duration, step-up;
   - **Awaiting payment** creates the business `pending_activation`. Its label and next action become "Awaiting
     payment — record payment to activate", never "Approve": the platform created it, so there is nothing left to
     approve, only to pay;
   - public self-registration and an Owner's extra stores keep their own approval and payment rules.
2. **A new `approved` state** before `activated` (a migration):
   - keeps the words "approved" and "paid" apart in the data;
   - more work, and every reader of the status must be revisited.

**Existing records:** no bulk change. Any console-created business still `pending_activation` is listed for the owner
to act on one by one. Production has one ordinary customer and three test businesses, all activated.

### 8.4 Balance tracking per payment method (brief §6): the live state, and a migration policy awaiting the owner

**The model as built:**
- **Receiving accounts** (`receiving_accounts`: Bankily, Sedad, BIM, …) are configured per **business**, not per store.
- A **money anchor** (`money_anchors`) records a known balance at a moment, and later movements are tracked from it.
- **Cash** is the drawer, counted at the day's opening and closing (`daily_closings`, `closing_channel_counts`).

**Production, read only, 2026-10-30** (counts only, no amounts):

| Business | Receiving accounts | Stores | Anchors | Closings |
| --- | --- | --- | --- | --- |
| Test (2026-10-24) | none | 1 | 0 | 0 |
| Test (2026-10-29) | Bankily (active) | 1 | **1** | 0 |
| Test (2026-10-29) | none | 1 | 0 | 0 |
| Ordinary (2026-10-30) | none | 1 | 0 | 0 |

**Proposed migration policy** (needs the owner's choice before the code changes behaviour):
- A new per-store setting, "Dedicated to this store", on each method, **OFF by default**.
- For existing configurations:
  - **(A, recommended)** a method that has an anchor starts **ON** at that store, from its latest anchor as the
    effective starting point; everything else is **OFF**. No recorded balance is erased or reinterpreted.
  - **(B)** everything starts **OFF**. The single anchor stays in history, and re-enabling it asks for a new starting
    point.
- Either way, past closings and anchors keep the meaning they were recorded with.
- **Cash:** the drawer stays counted at opening and closing whatever the switch says. The switch only decides whether
  cash is shown as a store's own tracked balance.

## 9. Third continuation, 2026-10-31 (CLAUDE, local; the owner's physical-test findings 1–7)

Heads at the start: backend `4cf32b3` (production, migrations to 0114), mobile `10a260e` (TestFlight 1.0.0 (3)),
console `638f1d63` (dukan-test served `7ddeea79`). No EAS/TestFlight build, App Store upload, push, WhatsApp or email
change in this phase.

### 9.1 The console's business creation (finding 1)

**Cause:** dukan-test served `7ddeea79`, from before D225's Arabic fields; the API (`4cf32b3`) requires
`ownerNameAr` and `businessNameAr`, and the first store's Arabic name with its Latin one. `638f1d63` already had the
fields but had not been deployed, and the forms still leaned on the browser's `required` and showed the API's English.

**Console `cd987227`:**
- `src/lib/names.ts` mirrors `erp-backend/src/common/bilingual-name.ts` exactly (script, blank, ≤ 160, hidden
  characters).
- New business: every Latin field labelled "(Latin letters)", every Arabic field `dir="rtl" lang="ar"`. The required set
  matches `CreateBusinessDto`: business and Owner both names; the first store's two together or neither.
- Checked before the step-up: the message under the field (`aria-describedby`), a summary above the buttons, nothing
  sent, nothing typed lost (`noValidate`).
- The same rules in the names editor (business, store, person) and in the Owner portal's store request, whose Arabic
  name is optional as the API has it.
- `ErrorNotice` never shows the API's validation wording ("… must be a string"); other server sentences only on an
  English screen; a refusal the page words itself is shown in every language.

**Audit of forms that create or edit a business, store or person:**
- Console: new business, names editor.
- Owner portal: store request.
- Not admin-portal, so unchanged: the public Apply page, where the API keeps Arabic optional
  (`RegistrationDto`).

**Tests:**
- 9 new in `test/bilingual-names-console.test.tsx`; the existing console tests use the new labels.
- Full suite: 651/656 passed. Of the 5 failures:
  - 2 in `source-rules` fail identically on the unchanged tree;
  - 3 are 5-second timeouts under load, and those files pass alone (68/68).
- Typecheck clean. The build runs only in CI: `build-test-sites` run 41245654675 succeeded.

**Deployed to dukan-test (the reviewed workflow, `docs/103` §5.3–5.6):**
- **Packaging:** evidence `cd98722-ace5ff7-41245654675`, 28 files checked against `dist.sha256`, packaged by
  `caddy-release.mjs`, 27 files identical on both ends.
- **First install refused before touching the edge:** Windows `scp` creates directories as 700, which the edge
  container cannot read. The release was re-sent and set to `u=rwX,go=rX`. The refused copy `20261031T220317Z` stays,
  unused, in `releases/`.
- **Installed:** release `20261031T220359Z`, previous `releases/20261029T152528Z`. 401 without the password on every
  path, CORS exact.
- **After:**
  - smoke 16/16 with `--allowed-origin https://dukan-test.tsxmr.com`;
  - API ready, 113/113;
  - the served bundle holds the new labels and all six field messages.
- **Rollback:** `test-sites.sh rollback console 20261029T152528Z --confirm api.tsxmr.com`.
- **Not done by Claude:** creating a business through the live form. It needs the site password, the administrator's
  password and MFA, which are the owner's.

### 9.2 "Discard changes" froze the app (findings 2 and 3), mobile `0d06a14`, `37fb5d6`

**Cause, proven in rendered tests with Expo Router's real stack:** each form hand-rolled its guard, in two faulty ways.
- `navigation.dispatch(data.action)` with the screen still marked dirty is blocked **again** by this router.
  - On Business settings the guard then asked a second time while the first dialog's modal was being dismissed. iOS
    cannot present it, so an invisible modal took every touch.
  - On the product form it did nothing; after a save it re-entered itself.
  - The router's own `repeat()` is blocked the same way: it lifts prevention through React state not yet committed when
    it replays, and the blocked event is then dropped silently.
- The exit also ran in the same tick the dialog's modal unmounted, popping the screen the modal was presented from.

**Fix: one guard, `lib/navigation/unsaved-changes.ts`:**
1. It asks once.
2. It waits for the dialog's modal to be fully gone. `DialogHost` keeps the modal mounted until iOS reports `onDismiss`
   (fallback 500 ms), and `dialog.afterClose()` waits for that.
3. It resets the draft (`onDiscard`) and keeps the blocked action, which lifts the prevention.
4. It dispatches the action only once the router no longer lists the route as prevented
   (`useRoutesWithRemovalPrevented`). The action goes through once.

Wiring and wording:
- Business settings and the product form (new and edit) use the guard.
- Registration replays with `repeat()` after the modal closes; Receive leaves after `afterClose()`.
- One wording in EN/FR/AR (`unsaved.*`: *Keep editing* / *Discard changes*); the per-screen copies are gone.

**English in Arabic:**
- Not reproducible from source: every confirmation goes through `t()` with an Arabic entry, and there is no native
  `Alert`.
- Tests now prove no English word of the question appears in French or Arabic.

**Tests (rendered):**
- **Harness** (`__tests__/unsaved-changes.test.tsx`), in EN/FR/AR:
  - *Keep editing* keeps the draft and asks again on the next Back;
  - *Discard* leaves once and leaves no visible modal;
  - the dialog store is empty, and a button on the screen underneath answers a press;
  - rapid Back asks once; a save leaves without asking; a clean form leaves without a question.
- **Real screens** (`unsaved-changes-screens.test.tsx`), in EN/FR/AR:
  - Business settings (summary language) and New product (category and brand): Discard leaves cleanly and nothing is
    sent (`put`, `post`, `patch` none);
  - *Keep editing* on settings.
- Hardware Back and the swipe are the same navigation action as the header arrow. Small-iPhone and largest-text checks
  were not run here.

### 9.3 Settings entries (finding 4), mobile `ace5ff7`, backend `c178ec6`

- **"Invalid query parameters":**
  - Cause: `names.service` read and renamed the business through the tenant Prisma client, which adds `company_id` to
    every `where`, and `companies` has no such column. Prisma refused, and the filter reported its validation error.
    `GET` and `PATCH /business/names` failed for every Owner.
  - Fixed in backend `c178ec6` (the unscoped client, always by the tenant's own id; the spec's tenant client now
    refuses `company` as Prisma does).
  - **Not deployed:** a production backend deployment is outside this phase's authorisation.
- **Names now in Business settings:**
  - More no longer lists "Business and store names". The business and each store have their rows in a Names section
    of Business settings.
  - The app has no per-store settings screen (`/stores` redirects to Partners), so each store's names are its own row
    there.
  - A failure of that section stays in it.
  - `/names` (bookmarks, deep links) redirects to Business settings.
- **Return policy:**
  - More no longer lists "Return policy"; it opens from Business settings → Returns.
  - Because Store Managers and Employees edit the policy (`return.policy.edit`), the Business settings entry shows for
    `settings.manage` **or** `return.policy.edit`. Someone without `settings.manage` sees only the Returns section.
  - The policy, its screen and its permission are unchanged.
- **Server text:** shown only on an English screen, and never the API's validation wording. French and Arabic show the
  app's words.
- **Tests:**
  - rendered (`settings-names.test.tsx`): each name reaches `/business/names` or `/branches/:id/names` with only what
    changed; a refused read is localized in FR and AR; `/names` lands on settings; a returns editor reaches the policy
    and sees nothing of the Owner's;
  - registry: both entries gone, settings visible to either permission.

### 9.4 The mouse intake (finding 5), diagnosed on its own

- **§8.2:**
  - The 2026-10-30 crash was the delivery Receive hand-back in build 1.0.0 (1): no cost field by design, then a crash on
    the way back, with no write.
  - The retry was Quick receive, which saved in one purchase.
  - That path is gone (`be32092`, in build 3).
- **The cost field:**
  - In the single-item intake it shows once a category is chosen (category first, D226).
  - Opened from the catalogue there is no cost at all, by design.
- **Partial saves:** none possible on the server.
  - The product is created inside the purchase's one transaction (`catalog.insertProductTx` within
    `purchasing.service`).
  - A retry replays by `clientUuid`, which the screen keeps across uncertain retries.
  - The app says "saved" only on a server-confirmed purchase.
- **Freeze on save:** the save-and-leave exit ran into the guard replay of §9.2. That exit is now the guard's bypass,
  covered by "a deliberate exit after saving passes without asking".
- **Observability, mobile `208b835`:**
  - `lib/intake-trail.ts` keeps the last 12 intake steps across a restart: opened, category chosen, sent, saved (the
    last safe point), refused, no answer, left.
  - A step name from a fixed list and a time only. Anything else is dropped before it is kept; a test proves no
    product, code or text is stored.
  - Shown on Devices in every build.
- **Gap:** a freeze still produces no crash report. The trail says where it stopped, not why.

### 9.5 A second platform administrator (finding 6): stopped before any change

- **Not started:** the mailbox `medmahmoud@tsxmr.com` was not confirmed in this session.
- **No one-administrator invariant in code:**
  - "exactly one superadmin" in `docs/100` §18.1 is an inspection record, not a rule;
  - `platform_admins` has a unique email and nothing else.
- **The documented mechanism does not meet the brief as written:**
  - `prisma/create-platform-admin.ts` takes the new administrator's password from whoever runs it
    (`PLATFORM_ADMIN_PASSWORD`, hidden prompt) — there is no invitation or first-use password flow for administrators;
  - **run against an existing email it resets that administrator's password and revokes its sessions**: it must never
    be run with the current administrator's email.
  - MFA is independent: `prisma/platform-admin-mfa.ts enrolment-token <email>` issues a one-time token. The new
    administrator enrols with it and reaches nothing before.
- **Options for the owner:**
  - **(a)** the new administrator types their own password into the hidden prompt, in a server session the owner
    opens; the enrolment token is then handed to them privately;
  - **(b)** build a one-time setup code for administrators like the Owner's (D217): a new feature, needing approval.

### 9.6 CI on these heads

- **ace5ff7:** the mobile security workflow failed on two pure tests that cannot run on Windows. Both failures came from
  this phase's code:
  - `access-boundary` lists the expo-router internals allowed; the guard's two were not listed yet;
  - `sheet-input` reads a `<Modal>` tag up to its first `>`, and an inline `onDismiss` arrow ended it early.
  - Fixed in `37fb5d6`; render-tests and visual-check retargeted to `37fb5d6`.
- **c178ec6:** the backend security workflow's audit failed on a new advisory in `joi`, a direct dependency used only to
  validate the environment at start (GHSA-4528-x5fx-h6hg). Fixed by the lockfile-only bump to 17.13.9 in `5131909`.
