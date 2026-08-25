# 38 — The control website: setup, security, operations

> The companion to [`docs/37`](37_PLATFORM_CONTROL.md), which describes the
> backend contract. This one is about the website that sits on it.

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
