# 38 — The control website: setup, security, operations

> The companion to [`docs/37`](37_PLATFORM_CONTROL.md), which describes the
> backend contract. This one is about the website that sits on it.
>
> **2026-10-05.** This website is now the designated commercial and Super Admin surface of the product; the customer
> app carries neither (`docs/21`, D129–D134). What it must become — pages, actions, schemas, security, the inputs
> needed, and the interim API operations until it has approve / refuse / create / invite — is the contract
> [`docs/68`](68_SUBSCRIPTION_WEBSITE_CONTRACT.md). The repository still has **no remote** and was not touched.

## 2026-10-05 — rebuilt from scratch as `erp-control-web` (`docs/69` §4, §7)

The website described below as `retail-erp-control-web` on the owner's PC is **abandoned**: it was never pushed and the
PC is broken. The replacement is **`erp-control-web`**, built from scratch in the 2026-10-05 phase beside `backend/`
and `mobile/` (excluded from this repository's tree like them), Vite + React + TypeScript with the same rules this
page sets out — nothing in storage but two preference keys, no price computed, no provider named, labelled cards
below 720 px, three languages with tested parity. Run it with `VITE_API_BASE=<api>/api/v1 npm run dev`; verify with
`npm run typecheck && npm test && npm run build`. It has **no remote yet**: creating one was refused by the session's
GitHub integration; `docs/69` §7 is the publishing step. The sections below describe the old site and are kept as
history and as the rules the new one was built to.

## Where it lives

```
C:\wamp64\www\PhoneStoreERP\retail-erp-control-web
```

Its own Git repository, beside `backend/` and `mobile/`, and excluded from the
documentation repository's working tree the same way they are.

**It has no configured remote.** Every commit is local. A remote was not
invented: pushing product source to a repository nobody chose would be worse
than the inconvenience of it waiting. Create one and add it when you are ready:

```bash
git -C retail-erp-control-web remote add origin <url>
```

## Running it

```bash
cd backend && npm run start:dev
```

```bash
cd retail-erp-control-web && npm run dev
```

The API defaults to port 3010 and the website to 5173.

**The website's API base follows its own hostname.** That is not cosmetic: the
administrator session cookie is `SameSite=Lax`, so a page served from
`localhost` talking to an API at `127.0.0.1` is *cross-site* and the browser
correctly withholds the cookie — every request comes back 401 while the sign-in
that set it looked perfectly fine. Point a build elsewhere with `VITE_API_BASE`.

The backend's `CORS_ORIGINS` must include the website's origin, with
credentials allowed.

## Creating the first administrator

There is **no default credential anywhere in any repository**, and no HTTP route
that creates an administrator. The only way is shell access to the server:

```bash
cd backend && PLATFORM_ADMIN_PASSWORD='…' npx ts-node prisma/create-platform-admin.ts you@example.com "Your Name"
```

The password comes from the environment rather than an argument, because
arguments land in shell history and the process list where anybody on the box
can read them. Re-running for an existing address resets the password **and
revokes that administrator's sessions** — a reset that left old sessions alive
would not be a reset.

Never paste a real password into a document, a commit message or a ticket.

## The three areas

| Route | Who | Credential |
|---|---|---|
| `/public/*` | anybody | none |
| `/account/*` | a shop's Owner | their tenant session |
| `/admin/*` | a platform administrator | a separate realm entirely |

The separation is structural rather than a check somebody could forget. The two
authenticated areas read different credentials from different backend realms, so
an Owner arriving at `/admin` carries nothing the guard will even look at — the
API refuses before the page decides anything.

## Where credentials live, and where they do not

**Nothing is ever written to `localStorage` or `sessionStorage`.** A test
enforces it and allows exactly two keys, both preferences: `erp.web.language`
and `erp.web.theme`.

- **The administrator session** is an **HttpOnly cookie** the browser attaches
  itself. No script can read it — verified in the browser: `document.cookie` is
  empty on a signed-in administrator page. This portal reaches every business on
  the platform, and a token in storage would put all of that behind any script
  that manages to run on the page.
- **The Owner's tenant token** is a module variable, for the length of a visit.
  The tenant API is a bearer API with no cookie session, so the portal genuinely
  holds one. A refresh signs them out again, which is the right trade for a page
  somebody opens to check a subscription rather than lives in.

CSRF: cookie-authenticated mutations carry an `x-requested-with` header a
browser will not attach cross-origin without a CORS grant the API does not give,
and the cookie is `SameSite=Lax`.

## What the website never does

- **It never computes a price.** Every figure is rendered from the server's
  response; a test refuses any component that multiplies a unit price. A client
  that computes its own price can be made to compute it wrongly, and the
  shopkeeper is the one who finds out.
- **It never asks for an internal identifier** — no Store ID, company id, branch
  id, personal ID or tenant code. All are generated server-side.
- **It never promises a free trial**, and a test checks all three catalogues.
- **It never offers a payment button** or names a payment provider. Every
  payment it displays carries "recorded by us — not confirmed by a payment
  provider".
- **It never shows operational shop data.** Not by filtering: the endpoints it
  calls do not return sales, IMEIs, costs, margins or customers.

## Language, theme and layout

English, Arabic and French, with **exact key parity** enforced by a test that
also refuses an Arabic or French string that is merely copied from English.

Arabic mirrors by setting `dir` on the document, so every row, margin and
scrollbar flips at once rather than component by component — the browser does
this properly and without a relaunch, unlike React Native.

Language and theme are stored under separate keys, so changing one cannot reset
the other. Light is the default; nobody's screen changes appearance on its own.

Every colour is a CSS custom property. A test refuses a raw hex or `rgba`
anywhere outside `theme/tokens.css`, and checks that every colour role defined
in light has a dark counterpart.

Wide administration tables **become labelled cards below 720px**. A table is
unusable at 375px however carefully it is styled, and squeezing or
side-scrolling both make somebody hunt for a value they can already see on a
laptop.

## Dependencies

| Package | Why |
|---|---|
| `react`, `react-dom` | the framework |
| `react-router-dom` | a real router, as required |
| `vitest`, `@testing-library/react`, `@testing-library/user-event`, `jsdom` | tests |
| `vite`, `@vitejs/plugin-react`, `typescript`, `oxlint`, `@types/*` | build and tooling |

**`npm audit` reports 0 vulnerabilities**, with and without dev dependencies.

Deliberately *not* added: a query library, a form library, and any admin
template. The application is small enough that hand-written fetch and form state
are clearer than the abstraction, and a large template dependency was explicitly
ruled out.

`vitest` runs with `pool: 'threads'` and a single thread — the default forks
pool times out starting a worker on this Windows machine, which is a platform
issue rather than a problem with the tests.

## Still outstanding before this is public

1. **Administrator MFA.** Password plus step-up confirmation is what exists. No
   fake toggle is shown, and none should be added until it is real.
2. **A real email/WhatsApp provider.** Until one exists, verification codes go
   to a development outbox, production refuses rather than claiming a message
   was sent, and the registration screen says so plainly.
3. **Bankily or another payment provider.** Deferred. Nothing contacts one, and
   every payment response carries `providerVerified: false`.
4. **A domain, DNS and TLS**, cookie `secure` in production, and a decision
   about where `/admin` is reachable from at all.
5. **A deployment and security review** of the whole arrangement.

---

## Arriving from the app

The mobile app hands the browser a one-time ticket. The API spends it, sets an
`HttpOnly` cookie and redirects to `/account?welcome=1` — a clean URL with no
ticket, no token, no password and no code in it.

**Two sessions reach this site, and they are not the same thing.**

| | How it arrives | Survives a refresh |
| --- | --- | --- |
| Signed in on `/account` | A bearer token in a module variable | No |
| Arrived from the app | An `HttpOnly` cookie the browser sends itself | **Yes** |

The page cannot tell which it has, because a script cannot read an `HttpOnly`
cookie. So it does not try: it asks the API and believes the answer, and falls
back to the sign-in form only on a real `401`.

That is a correction, not a design note. The portal used to gate on the
in-memory bearer token alone, which only its own sign-in form ever set. Walking
the real handoff in a browser during the CP8 acceptance produced this: the
exchange succeeded, the cookie was set, the API answered `200` to the very same
page — and the Owner was shown a password form. `/account` now forwards an
already-authenticated visitor to `/account/subscription` instead of asking again,
carrying the marker across so the payment dialog still opens.

### The marker

The dialog opens by itself for somebody arriving from the app, once. It watches
for **`welcome=1`**, which is what the API actually sends. It also still accepts
`from=app`, which was written here first and never matched anything — so the
dialog stayed shut for every real arrival until a browser run noticed.

## Where credentials live, and where they do not

The section above still holds, with one line corrected: **an Owner who arrived
from the app does survive a refresh**, because their session is the cookie, not
the module variable. Verified in the browser: after a full reload of
`/account/subscription`, the correct company still renders, `document.cookie` is
empty, and `localStorage` and `sessionStorage` are both empty.

## The payment dialog, measured

Verified in a browser against staging, on a genuinely **pending** shop:

- opens by itself after the handoff, Bankily selected, showing `00000`;
- Masrivi, Sedad, Bimbank and Click each switch and each show `00000`;
- selecting a provider issues **no network request at all** — measured with a
  `fetch` spy, not assumed;
- copying a code issues none either, and a **refused** clipboard is harmless:
  the dialog survives, nothing is thrown at the reader, the page stays usable;
- focus moves into the dialog on open, `Tab` and `Shift+Tab` cycle inside it,
  `Escape` closes it, and focus returns to the exact control that opened it;
- it closes and reopens from a control that is always present;
- the code renders `dir="ltr"` in English, Arabic and French — it is a sequence
  to type into a banking app, and mirroring it would have somebody enter it
  backwards;
- the words *paid*, *confirmed*, *verified* and *activated* appear nowhere;
- **no payment row, grant or activation was created** by any of it.

## Language, theme and layout, measured

Verified in the browser, not inferred: `lang`/`dir` become `en`/`ltr`,
`ar`/`rtl` and `fr`/`ltr`; no untranslated key leaks into the page; light and
dark swap the whole token set (`#f7f8fa` / `#0b0f17`); and at both 375 px and
1280 px there is no horizontal overflow and nothing is clipped.

---

## Language on the sign-in pages

Both sign-in pages — the customer portal at `/account` and the administrator
portal at `/admin` — already carry the established control, because `Chrome`
wraps every route and the language `<select>` lives there. Nothing needed
adding; the audit is recorded so the next reader does not repeat it.

Measured again in the browser: `ar` gives `lang="ar"` and `dir="rtl"`, `fr` and
`en` both give `ltr`, each switch changes the visible copy immediately, and no
untranslated key leaks. Each language is written in its own words and there are
no flags anywhere in the catalogues.

The website has never carried the mobile app's staging banner, and a scan of the
production build confirms the phrase appears nowhere in it.

---

## The app no longer links here (2026-09-22)

The mobile app used to mint a handoff ticket and open this site's account page —
after registration and from the blocked screen — and to offer this site's
registration page as "Create account". **All of that is withdrawn from the app**
(`docs/21`, 2026-09-22): activation and extension are the platform
administrators' decisions, taken in the app's own administration surface or here,
and the app shows the server's state and says whom to contact.

Nothing on the server changed for this site: `POST platform/portal-handoff`,
`GET platform/portal-session`, the portal session cookie and every record stay,
and the site's own sign-in works as before. `EXPO_PUBLIC_PORTAL_URL` and
`EXPO_PUBLIC_SIGNUP_URL` are no longer read by the app.

**Deferred, and recorded rather than done:** this site does not know the new
`rejected` status (0075). Its dashboard and business list receive `rejected`
rows from the API (the dashboard's `byState.rejected` and the list's `state`) but
have no label or filter for them, and it has no approve / reject /
period-correction / create-business / invitation actions of its own. This
repository was not modified or redeployed by that scope, by instruction.
