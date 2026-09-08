# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF** — all four trees clean and pushed.
- Active account / Owner: **NONE** (last worked by CLAUDE-A)
- ✅ iPhone strict ROI verified · ✅ Android CameraX patch compiles ·
  🔴 **Android ROI behaviour still unverified on a device.**
- ✅ The More-page spacing correction is untouched.
- ✅ Storage and Colour now have a bundled floor under a failed request.

| Repository | HEAD |
|---|---|
| `erp-mobile` | `f47a155` |
| `erp-backend` | `b5b9461` (untouched — **no backend change was needed**) |
| `retail-erp-control-web` | `c764d63` (untouched) |
| `erp-docs` | *this commit* |

---

## The Storage / Colour defect: cause, proven

**There was no code defect.** The endpoint, the contract, the seed and the
mobile request were all correct.

| | |
|---|---|
| Hook | `fetchAttributes()` in `lib/device-catalogue.ts` — one call serves **both** selectors |
| Endpoint | `GET /api/v1/device-catalogue/attributes` |
| Query key | none — a `useEffect` keyed on a retry counter, not React Query |
| Status **then** | **404** from the running process |
| Status **now** | **200**, 11 storage + 16 colour options |
| Data source | Curated server constants. **It reads no database**, so no seed, tenant filter, branch context or Model-ID dependency can affect it |

**Why Brand and Model worked while Storage and Colour did not:** `attributes`
was added in `373341e`, **seven commits after** `brands`/`models` in `e7062fb`.
A process built between those two serves brands and models and 404s attributes —
exactly the asymmetry seen on the phone. The auth guard runs after routing, so
401 means the route exists and 404 means it does not.

### The stale process

**There was no stale process left to kill.** Ports 8088 and 8081 were empty and
nothing was listening on 3010/3011 at takeover — the offending process died with
an earlier session. Rather than kill an unrelated process, the phone-facing stack
was stood up fresh on the current build:

- API `0.0.0.0:3011` from `dist/` (PID resolved explicitly before any signal);
- edge on `:8088`, which is what `EXPO_PUBLIC_API_ORIGIN` points at.

**No unrelated process was touched.**

---

## What changed: a bundled floor, mobile only

The stale process is gone, but the failure mode it exposed outlives it: **any**
genuine network failure emptied both lists and pushed the shopkeeper into typing.

- `lib/device-attributes-fallback.ts` — **new.** Dependency-free, mirrors the
  server's curated baseline.
- `lib/device-catalogue.ts` — order is now server → cache → bundled floor.
  `CatalogueOrigin` gained `fallback` as a first-class value.
- `components/catalog/VariantSelect.tsx` — the `fallback` origin renders the
  options with a **non-blocking warning and Retry**, never the blocking error
  state.
- `lib/i18n/{en,ar,fr}.ts` — `catalog.select.fallback`, identical order.

**Company history was deliberately not added.** It would make an unscoped
reference endpoint tenant-scoped for values the curated list already covers.
**Model-specific variants were deliberately not added** — no reliable mapping
exists, and inventing one would put false facts in front of a shopkeeper.

### Ordering and normalisation

Server → cache → bundled floor, with `Other` always last and exactly once.
`128GB` / `128 gb` / `128 Go` / bare `128` normalise to one option; `grey`
normalises to `gray`.

---

## Verification

| Gate | Result |
|---|---|
| Mobile `tsc --noEmit` | clean |
| Expo lint | **0 errors**, 1 pre-existing warning (unused `View` in `Screen.tsx`) |
| Expo Doctor | **18/18 checks passed** |
| Pure suites | **19 suites, 311 assertions, 0 failing** (new: 16) |
| EN/AR/FR parity | **1840 keys each, identical order** |
| Web export | clean — **23 routes**, `login`/`register`/`verify`/`select-branch`/`subscription-blocked` all present |
| Raw-colour audit (changed files) | clean — all colour from tokens |
| Hardcoded-copy audit (changed files) | clean — all copy through `t()` |
| Backend | **not run — no backend change was made** |

### Live checks — 11/11, against the phone-facing URL

Run against `http://192.168.100.3:8088/api/v1`, the exact base
`EXPO_PUBLIC_API_ORIGIN` resolves to:

login 200 · attributes **200** · storage defaults present · colour defaults
present · one `Other` each · no duplicates after normalisation · Brand 200
(13 brands) · Model 200 (35 models) · **`iPhone 17` selectable** (the reported
scenario) · unauthenticated refused 401 · malformed brand id 400, not 500.

### Failure and recovery, reproduced

API stopped by explicitly resolved PID → the edge returned **502**, a genuine
upstream failure. API restarted → the same call returned **200** with 11 storage
and 16 colour options. That is the Retry path end to end.

---

## Still open

- 🔴 **Android strict-ROI behaviour on a physical device.** Unchanged by this
  session; `docs/24` §9v carries the build command and the retest.
- 🟡 **The fallback's on-device appearance was not seen on a phone.** The logic
  and the failure/recovery path are proven over HTTP and in tests, but nobody
  has watched the warning render on a handset. Classified as automated + HTTP
  verification, **not** physical-device verification.

## Running services (leave up for testing)

- API `:3011` from the current `dist/`
- edge `:8088` — the phone-facing origin

Restart the API with `.env.staging` loaded before `dist/src/main.js`; confirm
with `curl -o /dev/null -w "%{http_code}" http://127.0.0.1:3011/api/v1/device-catalogue/attributes`.
**401 = live. 404 = stale.**
