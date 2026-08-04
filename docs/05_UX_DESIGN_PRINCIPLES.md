# 05 — UX Design Principles

The UX is the product. A phone shop's staff won't read a manual. The interface has to teach itself, defend against mistakes, and feel alive.

---

## The six laws (every screen obeys these)
1. **Reduce typing.** Scan, pick, or auto-fill before you ever ask someone to type.
2. **Prevent mistakes.** Make the wrong action hard and the right action obvious.
3. **Fewer taps.** The common path is the shortest path.
4. **Immediate value.** Every screen shows something useful the moment it opens.
5. **Simple for non-technical staff.** If a first-week employee can't use it unaided, it's too complex.
6. **Feel alive.** Speak like a helpful colleague, not a database.

---

## Camera-first interaction
- The **scan button is a primary, always-reachable action** in Add Stock, Sell, and Search.
- Scanning is the default; manual entry is the fallback, tucked behind "type it instead."
- After a scan, the app **confirms what it understood** ("iPhone 16 Pro · 256GB · IMEI ✓") so the user glances, not reads.

## Smart defaults & memory
- Pre-fill everything the app can reasonably guess: current branch, today's date, last supplier, usual selling price, logged-in employee.
- Learn per shop: the products it actually sells rise to the top of suggestions.
- The user's job is to **confirm or adjust**, rarely to originate.

## The "alive" voice
- Numbers always carry **context** (a trend, a comparison, a consequence). Never a bare figure.
- Messages are **plain language**, short, and human.
- Tone: calm, encouraging, occasionally warm ("Strong morning!"). Never alarming, never robotic.
- Warnings help, they don't scold: "That price is below cost — sure?" not "ERROR 0x12: INVALID_MARGIN."

## Progressive disclosure
- Show the **one number that matters**, with detail one tap away.
- The dashboard is a headline; drilling down reveals the story.
- Advanced controls (thresholds, overrides, reports) are reachable but never in the daily path.

## Mistake prevention as UX
- **Block** the truly wrong (duplicate IMEI sale) — no way through.
- **Warn + confirm** the suspicious (below cost, huge discount) — a soft speed bump with a plain reason.
- **Undo** over confirm-dialogs wherever the action is reversible — let people move fast and fix later.
- Every guard explains *why* in one sentence.

## Speed & flow
- The **sell flow is the fastest thing in the app**: scan → confirm price → done, ideally two taps for a standard sale.
- Bulk everything repetitive (add 10 units of one model in one motion).
- No long forms. Break anything long into scannable, mostly-prefilled steps — or eliminate it.
- Target: any core action completes in **under 10 seconds**.

## Visual & structural principles
- **Big touch targets, thumb-reachable primary actions** — this is used one-handed, at a counter, in a hurry.
- **Glanceable hierarchy:** one clear focal point per screen.
- **Status by color + words** (never color alone — accessibility, and shops have colorblind staff).
- **Consistency:** the same action looks and lives in the same place everywhere.
- **Legible in bad light** — shops have glare and cheap screens; high contrast, large type.
- Minimal chrome; the content (stock, sale, the day's story) is the interface.

## Onboarding by doing
- No tutorial walls. The first real task teaches the pattern.
- Empty states coach ("No stock yet — scan your first phone to add it").
- The app reveals capability as the user needs it.

## Accessibility & context of use
- Works one-handed; works with a case on the phone; works with imperfect lighting.
- Tolerant of flaky shop internet (see architecture: offline-first where feasible).
- Language: plain, translatable; assume some staff read slowly. Icons + words together.

## Anti-patterns (never do this)
- ❌ A bare number with no meaning.
- ❌ A 12-field form to add one phone.
- ❌ Cryptic errors or codes.
- ❌ Making staff re-enter data the app already knows.
- ❌ Burying the primary action in a menu.
- ❌ Color-only status.
- ❌ Anything that reads like accounting software.

## The north-star test for any screen
> *Could a brand-new employee, holding a customer's phone, complete this in seconds without asking anyone — and would the shop owner trust the result?*
