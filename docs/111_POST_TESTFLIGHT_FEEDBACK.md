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

### 7.8 Not finished in this continuation

- **Bilingual names on the remaining surfaces and the `.name` audit;**
- **illustrations on the remaining surfaces.**

Both were started by parallel workers that stopped at the account's usage limit. Their partial, **not green** work is
parked on `wip/d225-names-illustrations` in erp-backend (`cc42c8d`) and erp-mobile (`8985fe8`). It is not on
`post-testflight-feedback`. At park time it failed:
- backend: `bilingual-name-audit.spec`, `money-anchors.service.spec`, `money-positions.spec`;
- mobile: `lib/phone-selection.test.ts`.

**Also not run:**
- the Chromium/WebKit visual workflows;
- the layout matrix;
- the D219/D223/D224 journeys.

Automated WebKit on Linux is not a physical iPhone.

**Release-time gate (needs the build, the owner's authorisation and Apple):**
- confirm the APNs key is attached to the EAS project's iOS credentials (EAS manages it on the first build that has
  the entitlement);
- set `PUSH_CHANNEL=expo` on the release backend;
- then the physical checklist in §5, plus foreground, background and cold-start taps.
