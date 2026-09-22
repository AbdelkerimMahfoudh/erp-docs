# 49 — Audit: invoice PDF, Daily Closing, alerts preview, platform administration

*CP1 of the 2026-09-22 brief. Facts first, then the decisions the following
checkpoints rest on. Written before any of them was implemented.*

## Takeover facts and discrepancies

- HEADs at takeover: docs `df5f37d`, backend `59381f3`, mobile `c26f42b`. The brief
  named backend `e9f8e7e` and docs `d0eeb74`; both had moved forward by clean, pushed
  commits (`59381f3` "keep serial numbers whole in lookup; refuse a changed replay",
  `df5f37d` the correction phase's claim). They are the baseline.
- **The mobile tree is not clean.** Twenty-two uncommitted files belong to the other
  CLAUDE-A conversation (the selling/review/restyle correction, running concurrently
  by the user's instruction): `app/(tabs)/sell.tsx`, `app/quick-sell.tsx`,
  `app/receive/file.tsx`, `components/overlay/BottomSheet.tsx`, `DialogHost.tsx`,
  `components/sell/PhonePicker.tsx`, the file-receiving, file-review, phone-selection,
  sale-recovery, sale-submission and sheet-stack modules and tests, `lib/day-range.test.ts`,
  `lib/expense-rules.test.ts`, and **all three i18n catalogues**. None of them is in this
  scope. This conversation never stages those files; copy it adds to a catalogue is staged
  as its own hunk, never as the file.
- **Three of the seven reference attachments did not arrive**: the current generated
  invoice PDF, the handset screenshot of the laggy Daily Closing, and the handset
  screenshot of the oversized "À examiner" section. The four mock-ups did. What the
  missing screenshots showed is taken from the brief's words only.
- The other conversation's isolated API holds 3011; this one uses 3012, static 19010+,
  Chrome 9334 and the schema `prisma_verify_platform`.

## Invoice / receipt

- **One generator**, `mobile/lib/receipt.ts`: HTML → `expo-print` → OS share sheet.
  The body is fixed at `width: 80mm; margin: 0 auto` — a thermal-receipt layout — which
  is exactly why a Letter page comes out as a narrow strip. `lib/refund-receipt.ts` is
  a sibling for refunds (returns scope; untouched).
- **Payload.** `ReceiptData` is built on the phone: at sale time from the sale response
  plus what the cashier typed (both selling screens), and on the sale detail from
  `GET /sales/:id` (`receiptOf`). The server sale carries everything the brief asks for
  except two things: a store identity beyond the **branch name** (the company name is
  not in the sale; the app knows `branchName` and the signed-in user) and a
  **configured logo** (`Company.logoRef` exists in the schema and is not exposed to
  the app by any endpoint). Available: invoice number, sale instant, customer or debtor
  (`kind`, `name`, `phone`), lines with product label, identifier (`imei`/`serialNo`/
  `barcode`), quantity, price, discount, subtotal, discount, total, payments with
  `method`, `accountLabel` snapshot, `kind` (at sale / later), `paidAt`, `amountPaid`,
  `balanceDue`, `payStatus`, `soldBy`, and the return-policy snapshot.
- **Privacy.** `docs/04` §D 19d and `docs/21`: the customer receipt shows the **full**
  IMEI or serial (warranty proof). No cost, margin, ids or staff history; `ReceiptData`
  has no field for cost or margin, and `receipt-privacy.test.ts` pins it.
- **Return wording.** The receipt prints `receiptPolicyLine` from the sale's own
  snapshot: a window and deadline when the shop offers returns, "definitive — no
  return" only when the window is zero. Nothing is hardcoded; kept.

## Daily Closing

- `app/closing.tsx` (453 lines): `Screen scroll={false}` → one `ScrollView` → an
  `InlineNotice` → one `Card` per channel (`ChannelCard`: heading, chip, expected row,
  `MoneyField`, Skip/Save buttons; a settled card shows counted/difference) →
  `LoanReminders` (`Section` + `Card`) → sign-off `Button` → a ghost "discrepancies"
  button. No `Pressable`/`Touchable` wraps a card. No nested vertical `ScrollView`
  inside the file. **The shared `Screen` primitive wraps the whole body in an
  `accessible={false}` `Pressable`** (keyboard dismissal) — a full-screen JS responder
  above the list.
- Rendering: `useOpenClosing` has `staleTime: 0`, so every mount refetches;
  `useRecordCount` writes the response into the cache (no refetch). A keystroke updates
  the card's own `useState` only. One save re-renders every card (new `view.data`),
  each with a fresh inline `onSubmit` closure. The `ScrollView` has no
  `keyboardShouldPersistTaps`, so with the keyboard open the first tap on Save is spent
  closing the keyboard. Nothing is virtualised.
- **Root-cause statement, honestly bounded:** no handset was available to this
  conversation. From the code: (a) the drag dead zone is consistent with the
  full-screen `Pressable` ancestor plus `keyboardShouldPersistTaps` unset — a touch
  that starts on a `Text`/`View` inside the body becomes a JS responder before the
  native scroll can claim it; (b) the oversized repeated cards are the per-channel
  `Card` with a nested field surface; (c) the clipped purple text at the left edge is
  the `ghost` "Discrepancies" button rendered `fullWidth` under the sign-off block.
  Confirmation on a device is recorded as owed in `docs/24`.

## Analyses "À examiner"

- `GET /anomalies` (`report.view`) computes six rules on read, filters the company's
  dismissals, orders by **severity only**, returns every row. `POST /anomalies/:key/dismiss`
  inserts a new dismissal row on every call (a replay adds a second row; the seven-day
  suppression window is measured from the latest). No `limit`, no total, no creation
  time on a row: nothing is stored, so "newest" has to be **derived from the rule's own
  reference instant** (an overdue due date, a closing date, the last sale before a stock
  line went quiet, the window's end).
- `AttentionList` renders every anomaly as an `InlineNotice` with a button — the
  oversized repeated cards — with a confirm dialog before each dismissal.

## Platform administration and subscriptions

Far more exists than the brief assumes; the checkpoint is to complete and harden it,
not to build a second system.

- **Identity boundary already separate.** `platform_admins` is its own table with no
  `company_id`; sessions in `platform_admin_sessions`; `PlatformAdminGuard` reads an
  HttpOnly cookie (a bearer header only outside production). Tenant JWTs are not
  looked at. `administrator` exists as a `RoleKey` enum value but is "internal SaaS —
  never offered in onboarding" and grants nothing on platform routes. Bootstrap is
  `prisma/create-platform-admin.ts` with the password from the environment; no default
  credential exists anywhere. No MFA infrastructure exists (documented as outstanding
  production work); none is invented.
- **States.** `SubscriptionStatus`: `pending_activation`, `activated`, `suspended`,
  `cancelled`; the derived `EntitlementState` adds `active`, `grace` (period end +72 h,
  never stored), `expired`, `complimentary`. Mapping to the brief: PENDING_APPROVAL =
  `pending_activation`; ACTIVE / GRACE / EXPIRED = derived from `currentPeriodEnd`;
  SUSPENDED = `suspended`; **REJECTED has no equivalent** — a refused registration can
  only be `cancelled`, which reads as an ended subscription. Timestamps live in the
  append-only `subscription_events` trail (created, extended, suspended, reinstated,
  cancelled, administrative_grant …) and in `platform_audit_events` (actor, action,
  target, reason, before/after JSON, ip).
- **Actions that exist:** dashboard counts by state, business list (search, state
  filter, paging), business detail, pending registrations, activate by grant, extend
  by months, suspend, reinstate, cancel, record a manual payment, timeline. Every
  mutation is version-checked (`ConflictException` for a loser), idempotent by outcome
  for a same-state retry, reason-required for grant/suspend/cancel, step-up password
  for high impact, audited with before/after.
- **Missing against the brief:** approve/reject a pending business as first-class
  actions; set or correct a subscription end date directly; admin-created business with
  an Owner and a secure activation invitation; a mobile administration surface
  (only the control website consumes the API); tests of the boundary against
  Employee/Manager/Owner tokens and forged headers as one suite.
- **Enforcement** is central: `EntitlementInterceptor` (runs after guards) refuses
  every mutation unless the route is on `ALWAYS_ALLOWED`, and refuses all reads
  outside `ALWAYS_READABLE` while pending or suspended. The company comes from the
  tenant JWT, never from a header; the device clock plays no part. The locked surface
  is exactly: `entitlement`, `auth/me`, `auth/logout`, `auth/refresh`, `health`,
  `platform/my-subscription`, `platform/payment-instructions`, and the always-allowed
  writes (`auth/login`, `auth/refresh`, `auth/logout`, `auth/logout-all`,
  `platform/portal-handoff`, `notifications/:id/read`).

## Website inclusion in the app

- `lib/portal.ts` mints a one-time handoff ticket and opens
  `${API}/platform/portal-session?t=…` in the browser; `hooks/useAccountPortal.ts`
  wraps it; `app/subscription-blocked.tsx` offers it as the way forward for pending /
  expired / suspended shops; `app/(auth)/verify.tsx` opens it automatically after a
  new registration is verified; `constants/config.ts` reads `EXPO_PUBLIC_PORTAL_URL`;
  `lib/account-portal.test.ts` pins all of it. `app/subscription.tsx` (the in-app
  status page, no link) and the More/Settings rows stay.

## Decisions for the checkpoints

1. **Invoice**: one generator, split into a pure HTML builder (`receipt-html.ts`,
   testable in bare node, labels passed in) and the share wrapper. Full-width page
   layout with margins, a repeating table header, no gradients, no photos. The store
   line is the branch name plus the company name when the app has it; the logo slot is
   built and stays empty until the server exposes one. Full IMEI/serial per the
   confirmed policy.
2. **Daily Closing**: one virtualised list, flat memoised rows, explicit Save per row,
   a summary surface, the close action pinned with its reason, keyboard-safe. The
   shared `Screen` is left alone; the closing screen composes its own safe area,
   keyboard avoidance and list so no full-screen gesture layer sits above the rows.
3. **Alerts**: `GET /anomalies?limit=&page=` returns rows ordered by each rule's
   reference instant, newest first, then severity, then key — deterministic without
   storing anything — plus `total`. Dismissal becomes idempotent (an unexpired
   dismissal is returned, not duplicated). The overview shows three; a full list route
   pages through the rest.
4. **Platform**: keep the existing identity, states and audit; add `rejected` to the
   status and event enums (a refused registration is not an ended subscription), an
   `approved` event, approve/reject/period-correction/create-business/owner-invitation
   endpoints on the same guard, and a mobile administration area under its own
   session store and routes, never in tenant navigation. Grace stays derived (+72 h):
   an administrator ends a grace period by suspending and lengthens one by extending,
   and the decision that made it derived stands.
5. **Website**: remove the app's inclusion of the portal (ticket, hook, buttons, the
   automatic open after registration, the configuration key) and say instead that the
   administrator activates the account. The server's handoff route and every record
   stay.
