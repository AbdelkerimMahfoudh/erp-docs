# 29 — UX Audit and Redesign Foundation

**Audited:** 2026-08-15 · **Account:** CLAUDE-B · **Scope:** the mobile
application at `a5e7316`, all 34 routes (40 exported paths).

This is an evidence-based audit. Every claim below was measured against the
source or a build output, not inferred from a screenshot. Where something could
only be judged on a physical device, it is listed as such and **not** claimed as
verified.

---

## 0. The headline

**The design system is not the problem. Adoption is.**

`lib/design/` and `components/ui/` are genuinely good: one accent, semantic
intents, a status registry that makes "colour *and* words" structural rather
than remembered, a 4pt grid, a 48pt minimum touch target, and a deliberate
refusal to use shadows where a hairline reads as more professional. Measured
across `app/` and `components/`, there are exactly **two** raw hex literals in
the entire tree, and both are inside primitives.

The problem is that **a migration onto that system was started, stalled, and was
never finished** — and the unmigrated remainder is not a random tail. It
contains the role landing screen, the More menu, the branch picker, daily
closing, analytics, and the screen you land on after scanning a phone.

Two temporary shims say so in their own words. `components/ui/compat.tsx`:
"Bridges the pre-design-system component names used by the twelve screens built
before Phase 1 … the file is deleted once the last screen has moved over."
`lib/theme.ts`: "This file is deleted with the last legacy screen." Both are
still here. Twelve became eight; the last eight stopped.

---

## 1. Screen inventory

34 routes, classified. "Legacy" means the screen predates the design system and
still uses NativeWind `className` strings plus the deprecated `lib/theme` flat
palette, rather than tokens and primitives.

### Production-ready — on the design system, translated, coherent

| Route | Note |
|---|---|
| `(tabs)/sell` | Fastest path in the app; the scan-first hierarchy works |
| `(tabs)/inventory` | Server-side search and pagination, correct empty/end states |
| `sales/index`, `sales/[id]` | I1; policy snapshot disclosed on the receipt |
| `returns/index`, `returns/new`, `returns/[id]` | I2/I3; the most complex lifecycle in the app |
| `suppliers/index`, `suppliers/[id]`, `suppliers/new` | J1; **but see §2 S2 — unreachable** |
| `transfers/index`, `transfers/[id]`, `transfers/new` | H1 approval lifecycle |
| `catalog/[id]`, `catalog/new`, `catalog/edit`, `catalog/categories` | |
| `pricing/unit`, `pricing/history` | |
| `receive` | Still imports three compat shims |
| `team`, `settings`, `notifications`, `devices` | |
| `(auth)/login` | Translated, but legacy-styled |

### Legacy — unmigrated, and six of them are untranslated

| Route | Styling | `t()` calls | Consequence |
|---|---|---|---|
| `(tabs)/index` — **Home** | NativeWind + `lib/theme` | **0** | Role landing is hardcoded English |
| `(tabs)/more` — **More** | NativeWind + `lib/theme` | **0** | The whole menu is hardcoded English |
| `select-branch` | NativeWind + `lib/theme` | **0** | Shown at sign-in, before anything else |
| `closing` | NativeWind + `lib/theme` | **0** | Cash reconciliation, in English only |
| `analytics` | NativeWind + `lib/theme` | **0** | |
| `unit/[identifier]` | NativeWind + `lib/theme` | **0** | The screen you reach by scanning |
| `catalog/index` | NativeWind + `lib/theme` | translated | Styling only |
| `(auth)/login` | NativeWind + `lib/theme` | translated | Styling only |

### Prototype / non-visual

`app/index.tsx`, `app/_layout.tsx`, `(auth)/_layout.tsx` — routers, no UI.
`dev/gallery` — the component gallery; developer-facing, 809 lines.

### Permission-sensitive

`(tabs)/index` (`report.view`), `(tabs)/sell` (`sale.create`), `analytics`,
`closing`, `settings`, `team`, `pricing/*` (`cost.view` gating on money),
`suppliers/*` (`supplier.view`, `supplier.pay`, `supplier.confirm`),
`returns/[id]` (`return.approve`, `refund.report`, `refund.confirm`).

### Counter-critical (used with a customer waiting)

`(tabs)/sell` · `(tabs)/inventory` · `unit/[identifier]` · `receive` ·
`returns/new` · `closing`.

### Device-only verification needed

Camera permission states · scanner from `*#06#` · haptics · bottom-sheet drag ·
keyboard avoidance · safe areas on a notched device · offline indicator ·
share-sheet for the refund receipt PDF · low-end scroll performance.

---

## 2. Severity-ranked problems

### S1 — Six user-facing screens are hardcoded English

**Evidence:** zero imports of `lib/i18n` in `(tabs)/index`, `(tabs)/more`,
`select-branch`, `closing`, `analytics`, `unit/[identifier]`.

The app reports **EN and AR at 1025 keys each**, and that parity check is
completely blind to this: the strings were never keyed, so nothing is missing
from either file. An Arabic-speaking employee signs in and meets, in English:
the branch picker, the home screen, the entire More menu, the screen after
scanning a phone, and daily closing.

This is not an aesthetic weakness. It is the largest usability risk in the
application, and the existing parity check will never catch it. **A key-count
check must be joined by a "no untranslated user-facing literal" check**, or the
same thing recurs the next time a screen is built in a hurry.

### S2 — The Suppliers feature is unreachable

**Evidence:** `/suppliers`, `/suppliers/[id]` and `/suppliers/new` all export.
No navigation entry anywhere links to them; the only in-app reference to the
word is a `POST /suppliers` in `receive.tsx` that creates one inline.

Phase J shipped a complete supplier payables workflow — an Employee reports a
payment, a Manager or Owner confirms it, the liability settles. **None of it is
reachable by tapping.** It works only if someone types a deep link.

This is an information-architecture defect, not a visual one, and it is the
clearest possible argument for the brief's rule that pending work must be
surfaced rather than buried.

### S3 — The role landing screen fails three of the six laws

`(tabs)/index` measured against `docs/05`:

- **"Never a bare figure."** Store health renders
  `${score} · ${status.toUpperCase()}` — a naked number beside the word
  "GREEN", "AMBER" or "RED". That is colour used *as* the word, untranslated,
  and it tells a shopkeeper nothing about what to do.
- **"Immediate value."** Employees never see this screen at all — they are
  redirected to Sell or Inventory, because `/home` requires `report.view`. The
  redirect is correct and well-reasoned; the consequence is that **two of the
  three roles have no landing screen**, only a tab that happens to open first.
- **"Show the one number that matters."** Month profit is rendered as
  `text-center text-xs` muted grey — the "tiny grey text" anti-pattern named
  explicitly in this milestone's brief, applied to a profit figure.

There is also no skeleton and no error state: while loading, and *also* when
`/home` fails outright, every tile shows `—` with no explanation. The two states
are indistinguishable to the user.

### S4 — Managers have nowhere to see pending work

Nothing aggregates: transfers awaiting approval, returns awaiting review,
refunds awaiting confirmation, supplier payments awaiting confirmation, or
whether the day is closed. Each lives behind its own route, and three of those
routes are reachable only through a flat, untranslated More list. A manager's
outstanding decisions are invisible until they go looking, feature by feature.

### S5 — Duplicate action in More

`Branch` and `Switch branch` are two adjacent rows calling the same
`changeBranch` handler. One is dead weight; having both makes a user wonder what
the difference is.

### S6 — Three styling systems coexist

1. `lib/design/` tokens + `components/ui/` primitives — the intended system.
2. NativeWind `className` strings — 8 screens.
3. `lib/theme.ts` flat palette — 12 importers, marked `@deprecated`.

Plus `components/ui/compat.tsx`, whose header says "Do not add anything to this
file." Consistency between similar workflows is impossible while a screen's
appearance depends on the month it was written.

### S7 — No offline indicator exists

**Evidence:** no `NetInfo`, no connectivity state, no banner component. The word
"offline" appears in `lib/errors.ts`, in two screens' error copy, and in the
translation files — as *error text after a request has already failed*.

The brief requires a persistent, visible offline indicator. Today a user at a
counter with dead shop internet discovers it one failed action at a time. This
matters most on `closing`, the screen where reaching the server is least
optional — and which is also one of the untranslated six.

### S8 — Missing primitives force per-screen invention

Absent from `components/ui/`: `MoneyValue`, `InlineNotice`, `StickyActionBar`,
`PermissionNotice`, `OfflineBanner`, `WorkflowTimeline`, `ScreenHeader`.

(`Stepper` exists but is a *quantity* stepper — deliberately laid out LTR in
every language so nobody decrements when they meant to increment. It is not a
workflow timeline and must not be conflated with one.)

Money is formatted ad hoc through `formatMoney` at each call site, which is why
the same figure is `text-lg font-bold` in one card and `text-xs` muted in
another on the same screen.

### S9 — Aesthetic-only, low severity

Oversized quick-action tiles push real content below the fold on Home;
inconsistent section spacing between legacy and migrated screens; `StatTile`
tone used decoratively (Revenue "accent", Profit "success") where the tone
carries no meaning.

---

## 3. Repeated patterns

**The pattern behind almost everything above:** a screen built under time
pressure skips the system, and nothing structural stops it. There is no lint
rule against `className` on a native screen, no check for an untranslated
literal, and no test that a new route is reachable from navigation. S1, S2 and
S6 are the same omission wearing different clothes.

**The second pattern:** work that is *pending* has no home. Returns, transfers,
refunds and supplier payments each built a correct approval workflow, and each
left the "who needs to act, and on what" question to the user's memory.

---

## 4. Accessibility and RTL findings

- **Confirmed good:** `lib/design/direction.ts` exists and is used; `Stepper`
  documents *why* it stays LTR in Arabic; the status registry forces a word
  alongside every colour; `touch.min` is 48pt and primitives honour it.
- **S1 is the dominant RTL finding** — direction handling is worth little on a
  screen whose text never translates.
- `colors.text.placeholder` is documented as deliberately failing contrast, for
  placeholders only. Verified it is not used for real content.
- **Long-Arabic behaviour is untested.** No screen has been checked with the
  longest Arabic strings; truncation and wrapping in `ListRow`, `StatTile` and
  `Chip` are unknown until measured.
- **Device-only:** Arabic font rendering, line-height and numeral shaping under
  Hermes ICU cannot be confirmed from a web export.

---

## 5. Information-architecture findings

- The tab bar is well-judged: four tabs, `href: null` rather than a tab that
  403s, and it renders only after permissions resolve so tabs never visibly
  disappear. **Keep this.**
- More is a flat list of eleven rows mixing daily work (Sales, Returns,
  Transfers), administration (Team, Settings) and account concerns (Devices,
  Branch). It needs grouping, not reordering.
- Suppliers is missing from it entirely (S2).
- No route surfaces pending work (S4).

---

## 6. Suggested visual direction

Confirming the existing direction rather than replacing it — it already matches
the brief, and the brand accent, splash and app icon are settled:

- Neutral, slightly cool surfaces; **one** indigo accent; semantic intents for
  success/warning/danger/info only when something needs to *say* a state.
- Hairline borders over drop shadows. Elevation is reserved for genuinely
  floating things — sheets, toasts.
- Money gets a dedicated treatment: tabular figures, consistent weight per role
  (focal / supporting / metadata), and one component, so a figure cannot be
  styled three ways on one screen.
- Pending / approved / confirmed must be **visually unmistakable**, and never by
  colour alone. `approved_refund_due` is already deliberately `info`, not
  `success`, because the shop *owes* money — that reasoning extends to supplier
  payments and to every "reported but not confirmed" state.
- Dense enough to work, spacious enough to tap: 48pt minimum, 4pt grid.

**Adding no font and no UI dependency.** The system needs adoption and seven
small components, not new machinery.

---

## 7. Before / after acceptance criteria

| # | Before | After (acceptance) |
|---|---|---|
| A1 | 6 screens with 0 `t()` calls | Every pilot screen renders fully in Arabic; EN/AR key counts stay equal |
| A2 | Suppliers unreachable | Reachable in ≤ 2 taps from a role landing screen |
| A3 | `lib/theme` has 12 importers | 0 importers among pilot screens; file deleted when the last one goes |
| A4 | `className` on 8 native screens | 0 on pilot screens |
| A5 | Health as `92 · GREEN` | A stated condition in words, with what to do about it |
| A6 | Loading and failure both show `—` | Distinct skeleton and error states |
| A7 | No offline indication | Persistent banner whenever connectivity is lost |
| A8 | Manager pending work invisible | Surfaced on the landing screen, with counts that are real or absent — never fake zeroes |
| A9 | Money styled per call site | One `MoneyValue`; no pilot screen formats money inline |
| A10 | Due / reported / confirmed similar | Distinguishable at a glance, by shape and word, not colour alone |

---

## 8. Pilot selection

The brief fixes five, and the audit supports each:

1. **Home / role landing** — the largest rebuild. Legacy-styled, untranslated,
   and absent for two of three roles (S1, S3, S4).
2. **Sell** — counter-critical and the most used screen in the app. Already on
   the system, so this is hierarchy refinement, not re-plumbing.
3. **Inventory** — the density, search and cost-gating testbed.
4. **Supplier list/detail** — newest feature, and currently unreachable (S2).
5. **Return detail** — the hardest lifecycle, and the one place where "due",
   "reported" and "confirmed" must never be confused.

Usefully, **only Home is a legacy rebuild**; the other four are already on the
design system. That is what makes a five-screen pilot achievable without
touching the backend.

---

## 9. Full migration order (after the user approves the direction)

Not part of this milestone. Recorded so the sequence is not re-derived:

1. `closing` — untranslated, counter-critical, and where offline hurts most.
2. `unit/[identifier]` — untranslated, and the destination of every scan.
3. `(tabs)/more` — untranslated; grouping and the duplicate-row fix.
4. `select-branch` — untranslated, shown at sign-in.
5. `analytics` — untranslated; largest surface, lowest counter urgency.
6. `catalog/index` and `(auth)/login` — legacy styling only.
7. `receive`, `transfers/new` — drop the remaining compat shims.
8. Delete `components/ui/compat.tsx` and `lib/theme.ts`, and add the lint rules
   that stop all of this from returning.

---

## 10. Out of scope, recorded

**Production blocker (not this milestone):** there is no correction workflow for
a *confirmed* refund payout or a *confirmed* supplier payment. Both are
immutable once confirmed, by design, and nothing financial is hard-deleted — but
no reversal path exists either. A confirmation made in error has no in-app
remedy today. This must be solved before real money runs through the system; it
is deliberately **not** mixed into a UX milestone.
