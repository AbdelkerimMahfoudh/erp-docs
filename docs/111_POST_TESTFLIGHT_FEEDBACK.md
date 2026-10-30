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
- **Step-up.** Store accounts have no MFA today, so the step-up is the Owner's password. The platform's MFA is the
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
