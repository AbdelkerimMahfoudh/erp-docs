# ERP Current Handoff

> This file is a **snapshot**, not a history. Stale detail is replaced, not
> appended. The narrative record lives in `SESSION_LOG.md` (append-only) and the
> approved decisions in [`docs/21`](docs/21_PRODUCT_DECISIONS.md).

## Session control

- Status: **READY_FOR_HANDOFF** — all four trees clean and pushed.
- Active account / Owner: **NONE** (last worked by CLAUDE-B)
- **The frame is now the scan region** — every corner of a barcode must be
  inside it, and a failing callback is dropped before anything else happens.
- 🔴 **Enforceable on iOS only.** Android never forwards the image dimensions
  needed to map barcode coordinates; nothing is inferred. Details below.
- One frame now, wide and shallow, sized for a single horizontal barcode. The
  two overlapping shapes are gone.
- ⚠️ The two device screenshots that prompted this were **not received**. The
  geometry follows the written brief and has not been compared with the device.
- 🔴 **Not device-verified.** Retest: `docs/24` §9u, Android and iOS
  separately. **Step 8 is the one that matters.**

| Repository | HEAD |
|---|---|
| `erp-mobile` | `fe7829e` |
| `erp-backend` | `b5b9461` (untouched) |
| `retail-erp-control-web` | `c764d63` (untouched) |
| `erp-docs` | *this commit* |

## 🔑 The retained staging shop

`store@test.com` at **Test Store** — 20 iPhones, each with its own synthetic
TAC, restored exactly as found after every verification run. The password is
the one you chose and is deliberately not written down here or anywhere in
these repositories.

```bash
cd backend
APP_ENV=staging npx ts-node scripts/staging-scan-sheet.ts > ../scan-sheet.html
```

Run `docs/24` **§9u first**, on **Android and iOS separately** — the scan
region, with the `__DEV__` geometry overlay on. Then **§9t** (one, two and
three IMEIs in frame, using a real dual-SIM label or fixtures side by side) and
**§9s** for the crowded-label acquisition steps.

**No camera has read anything yet.**

---





### The frame became the scan region

Only a barcode **completely** inside the rectangle may be considered. Every
corner, not the centre: a barcode straddling an edge has its centre inside while
half of it is out of shot, and that is the read that produces a wrong digit. Two
barcodes each crossing the frame is **no detection**, not a guess at whichever
is more covered.

A rejected callback is dropped before classification, stabilization, haptics,
recognition or any message. It never happened.

#### One frame

There were two overlapping shapes — corner brackets and a rounded rectangle — so
the active area was whichever one you read. **Two frames on a scanner is worse
than none**: it promises a boundary and leaves you to guess which.

One wide, shallow rectangle now: 84% of the preview width, 0.34 of that as
height, accents drawn on it so they cannot drift, and derived from the same
rectangle the gate tests. Height is tied to WIDTH rather than to the preview, so
a long phone does not get a frame that comfortably holds two stacked codes.

Surround is four scrim panels — a cutout needs a mask layer and this needs none,
and inside stays clear glass. **No blur**: `expo-blur` is not installed and
none was added.

#### 🔴 The limitation, audited from the native source

| Platform | Enforceable? |
|---|---|
| **iOS** | **Yes.** `MetaDataDelegate.swift` passes metadata through `previewLayer.transformedMetadataObject` — preview points, aspect-fill and rotation already applied, the same space `onLayout` reports. It loops **all** `metadataObjects`. |
| **Android** | **No.** ML Kit corners are rotated image pixels; the serializer divides by density and sends `data · raw · type · extra · cornerPoints · bounds`. The image dimensions are captured in Kotlin and **never put into that bundle** — verified zero occurrences. Also `barcodes.first()` only. |

**Nothing was inferred.** Guessing an extent fails by silently rejecting every
scan, on hardware nobody here can test. `no-geometry` is never treated as
`inside`. `bounds` is not consulted: Expo documents it as sometimes empty and
as not necessarily bounding the whole barcode — precisely this use.

On Android the frame guides and the copy claims nothing more; the existing
stability and explicit-selection rules still protect the scan there.

**Proposed, not implemented** — smallest first: forward `width`/`height` and
rotation in `toBundle` (a few lines, upstreamable, and this gate would work
unchanged); then a config plugin cropping the analyzer input; a different
scanner dependency only if both are proven insufficient.

#### A development overlay with no identifiers in it

Behind `__DEV__`: the measured rectangle, the received corners, and the
verdict. Coordinates and the **last four digits** only — an overlay printing
payloads would put complete IMEIs on screen and into whatever captured it.
Nothing logged, nothing persisted.

#### Gates

Mobile **27 pure suites** — 22 ROI, 49 stabilizer, 28 machine, 58 scanner
behaviour · `tsc` clean · lint **0** · Doctor **18/18** · EN/AR/FR **1 837
identical** · export **68 routes**. Backend, website and databases untouched.
**No migration, no schema change, no API change.** Manual entry, the ambiguity
workflow, dual-IMEI QR parsing, IMEI 1 locking and the no-OCR rule all preserved.

---

### Three visible IMEIs: the scanner asks now

The device found it alternating between them, sometimes waiting indefinitely,
sometimes choosing one nobody meant, and sometimes reporting "nothing found"
while holding a valid IMEI.

**Timing could not fix this.** The old rule waited for one candidate to
dominate; two IMEIs held side by side accumulate at the same rate and never
separate, so it waited — and when `AMBIGUITY_GRACE_MS` expired it picked one
arbitrarily. The hang and the wrong pick came from the same line.

The principle: **stability says a barcode is being held still, never that it is
the one somebody wanted.**

| Valid IMEIs | Behaviour |
|---|---|
| one | continues automatically after its window |
| two | camera stops; one, or "Use both — one phone" |
| three or more | all listed, **never** auto-selected, at most two |

While the question is open: **camera off, no haptic, no recognition request,
nothing committed.** `/scan` hangs off a confirmed identifier and a question
has none — which is also what stops a response for an unintended candidate
arriving later and overwriting the visible result.

#### Details worth keeping

- A candidate needs `MIN_OBSERVATIONS` sightings to be offered, so one stray
  decode from a neighbouring label cannot turn a clean scan into a question.
- Invalid identifiers are never offered and never displace a valid one.
- **"Both IMEIs belong to one phone."** appears *with* the choice, not after.
  Two IMEIs on a bench are not evidence of one handset, and filing two phones as
  one is not correctable later.
- `rankCandidates` orders the panel best-aimed first where coordinates are
  trustworthy. **Presentation only.** On Android nothing can be normalised, so
  the person simply chooses — the required fallback, not a stability guess.
- Adding IMEI 2: IMEI 1 is excluded from collection entirely, so it cannot be
  offered, counted as a rival, or re-picked. "Scan again" keeps it.

#### Four result meanings, kept apart

A valid IMEI with an unknown TAC now reads **IMEI detected** + **Product not
recognized**. It used to read as "nothing found" — telling somebody the scan had
failed when it had worked, and sending them back to rescan a correct code.
**No IMEI found** is reserved for nothing having been an IMEI at all.

#### A test that was passing for the wrong reason

The session-reset test sliced on an anchor that swallowed the whole component,
so it asserted that `setSelected([])` appears *somewhere in 25 000
characters*. Fixed, and it now bounds the block it claims to inspect — the
tightened version failed until the reset actually cleared the selection.

#### Gates

Mobile **26 pure suites** — 49 stabilizer, 28 machine, 58 scanner behaviour ·
`tsc` clean · lint **0** · Doctor **18/18** · EN/AR/FR **1 837 identical** ·
export **68 routes**. Backend, website and databases untouched. **No migration**,
no API change, no change to IMEI validation, duplicates or permissions.

---

### The scanner could not scan a phone label

`a82666f` fixed "accepts in under a second" and introduced something worse,
which measurement here caught rather than a phone:

```
before:  4 950 ms held still over 4 barcodes  →  0 accepted
after:   1 617 ms                             →  1 accepted (the IMEI)
```

`onBarcodeScanned` fires **once per barcode, not once per frame**. A label
carrying IMEI 1, IMEI 2, a serial and a model number produces four interleaved
callbacks, and a single-candidate tracker that resets on every payload change
means they erase each other forever. A stationary camera on a crowded label was
the worst case, and it is the ordinary case.

Candidates are tracked concurrently now, each earning its own window: same
normalised payload 3+ times, spanning 1 000 ms, no gap over `MAX_GAP_MS`.

#### Two more defects, both found by writing the tests

1. **Whichever code crossed the one-second line first won uncontested**, because
   no rival was yet eligible to compare against — decided by decoder emission
   order, which is "accept whatever arrived first" one level up. Dominance is
   now judged against every LIVE candidate.
2. **A serial number could out-rank the IMEI beside it** and the scan then
   failed with "that is not an IMEI" while the IMEI was in frame throughout.
   Usable candidates are considered first and separately; `prefer: 'imei'`
   ranks IMEIs above stray barcodes when a phone is being booked in.

#### The reticle ranks; it never gates

From the native source, not the doc comments: iOS passes barcodes through
`previewLayer.transformedMetadataObject` (preview points) or Vision (already
0–1); **Android reports image pixels ÷ display density and never forwards the
image dimensions**, so no denominator exists. Android ranks by stability alone.
No speculative normalisation was attempted — its failure mode is a scanner that
rejects everything, on hardware nobody here can test.

#### Bounded, and never silent

Two indistinguishable candidates keep acquiring rather than tossing a coin,
capped by `AMBIGUITY_GRACE_MS` so it cannot hang. Tracking is capped at
`MAX_CANDIDATES`. An unusable code gets one brief note over a still-live
camera, then a cooldown. The reticle fills as the window builds, because a
silent second reads as a frozen app.

#### Gates

Mobile **26 pure suites** — 38 stabilizer assertions, 44 scanner behaviour ·
`tsc` clean · lint **0** · Doctor **18/18** · EN/AR/FR **1 828 identical** ·
export **68 routes**. Backend, website and databases untouched. No migration.

Schema, API contracts, IMEI validation, duplicate rules, permissions, manual
entry and the success lock are all unchanged.

---

### The scanner accepted what it saw first, not what was meant

Three attempts, three failures, and a fault none of the earlier rounds reached.

The decoder was never wrong. A barcode half in frame is still a barcode, and
`expo-camera` reports it the instant it resolves. **We treated the first thing
seen as the thing meant**, and those are the same only when the camera is
already still.

#### The rule

`lib/scan/stabilizer.ts`. A payload is accepted when the same normalized bytes
have been decoded **3+ times**, spanning **1 000 ms**, with no gap over
`MAX_GAP_MS`. The gap clause is the one carrying the meaning: a code that drifts
out and back was passed over twice, not aimed at. *(Superseded above: this
tracked ONE candidate, which could not scan a phone label. 400 ms became
600 ms with concurrent tracking.)*

**Not a timer.** A `setTimeout` that accepts whatever is current after a second
takes the LAST thing seen rather than the first, and fires when the camera may
point anywhere. Every decision comes from an observation that actually arrived,
on a monotonic clock — and the clock is injected, so the window is tested at the
millisecond without a device.

Until it passes: camera live, no result, no lookup, no haptic, nothing
committed. Resets on a different payload, a gap, cancel, "Scan again", "Add
second IMEI", and every new session.

#### An assertion of mine that was wrong

§9p left a test banning **every** delay mechanism. I wrote it when the fault was
a frozen frame, reading "fast detection is acceptable" as "acceptance must never
take time". **3/3 device failures is what that cost.**

Replaced with the narrower rule that is actually right: nothing that fires on
its own may accept anything. The one interval left in the sheet drives a label,
and a test asserts it cannot accept or advance the machine.

#### The frame guides; it does not gate

`expo-camera` documents `bounds` as sometimes an empty rectangle and sometimes
"the area used by the scanner"; `cornerPoints` as often absent, **corner order
differing per platform**, and no documented coordinate space. Guessing wrong
would silently reject every scan on one platform, on hardware nobody here can
test — so the frame is honest guidance and the copy never claims otherwise.
*(Superseded above: coordinates now RANK candidates where they are trustworthy,
read from the native source rather than the doc comments.)*

#### The QA page was part of the problem

Thirty-two cards, several in frame at once, the decoder reporting whichever
resolves first — a wrong result could be the scanner's fault or the page's.
Every code now opens **alone, full screen**: one barcode at twice the height,
white to the edges, a wide quiet margin, expected result underneath, a way back.
One code per view, dual-SIM included. 32 cards → **39 solo views**, no
identifier regenerated, CSS `:target` only.

#### Gates

Backend **109 suites / 1 901 tests** · `tsc -p` clean.
Mobile **26 pure suites** — 21 new stabilizer assertions, 44 in scanner
behaviour · `tsc` clean · lint **0 errors** · Doctor **18/18** · EN/AR/FR
**1 828 identical** · export **68 routes**.

Model counting, the storage/colour selectors, the keyboard fixes, TAC
recognition and every backend inventory semantic are untouched. No migration.

### What remains

**Consolidated.** Every earlier session left its own "What remains" list in this
file, and thirteen of them had accumulated — each naming a next action that had
already been done. They are merged here and the duplicates removed; the
narrative each came from is kept, and the full history is in `SESSION_LOG.md`.

*On a device — nothing below has been confirmed by a camera:*

1. 🔴 **`docs/24` §9u** — the scan region, Android and iOS separately.
   **Step 8 is the one that matters**: does the dark mask align with the real
   detection boundary? A source test cannot prove a coordinate transform, and
   aspect-fill cropping and rotation are exactly what looks right in a simulator
   and is wrong in a hand. The `__DEV__` overlay is there to show it.
2. 🔴 **§9t** — one, two and three visible IMEIs, both platforms.
3. 🔴 **§9s** — the crowded-label acquisition steps.
4. 🔴 **§9r** — the aiming steps, superseded in part but never confirmed.
5. 🔴 **§9q steps 8–15** — the model count moving after a save, using
   scan-sheet case 12. Step 9 leaves Test Store at 21 units by design; restore
   with `staging-verify-model-count.ts`.
6. 🔴 **§9n and §9o** — the ten original scanner checks and the §9o items.
7. `ROI_TOLERANCE_PT` and the acquisition constants are exported and
   documented **because they have not met a phone**. Do not tune from simulation.
8. ⚠️ The two screenshots behind §9u were never received; the frame geometry is
   unverified against what the device displayed.

*Known and deliberately not done:*

5. `withinGuide` stays unused until somebody verifies the platform coordinate
   space on both iOS and Android — see the bounds audit in `ScannerSheet.tsx`.
6. A licensed GSMA feed remains the dependency for broad generic recognition.
   19 of 323 models recognisable is the honest number.
7. **Dead code**: `lib/signup.ts` (nothing imports it) and `lib/imei.ts` apart
   from `tacOf` — the OCR reading path it was written for is gone.
8. `lib/portal.ts`'s `isTrusted()` comment overstates what it checks, and
   `accountPortalUrl()`'s fallback still names `:5173`, the old Vite port.
9. The 38 retained acceptance tenants still cannot be removed by any command —
   only a database change would clear them.

### Next exact action

Run `docs/24` **§9u** on a phone, on **both** platforms — then §9t. Step 8 of
§9u decides everything else: if the mask does not sit exactly on the real
detection boundary on iOS, the coordinate conversion is wrong and the
`__DEV__` overlay will show where.

---

### The scanner: the state outlived the sheet

The first scan worked; reopening showed the previous session's result before the
camera existed, which reads as a frozen photograph.

**The camera was not the cause.** `ScannerSheet` is permanently mounted by its
parents — `open` only gates `if (!open) return null` — so the machine, the
lookup, both guards and the `CameraView` instance all survived a close. The
reset lived in an effect, and an effect runs one paint too late.

  1. Reset **during render**, comparing `open` against its previous value.
  2. `key={sessionId}` on `CameraView` — a new native view, not a reconcile
     onto the one holding the last frame.
  3. A `lookupSession` token, so a `/scan` response from a closed session
     cannot write into the session that replaced it.

**No delay was added.** Fast detection was correct; the test asserts the absence
of `setTimeout`, `setInterval`, `await new Promise` and
`requestAnimationFrame` in the sheet.

### Counting by model, without stopping counting by IMEI

`GET /inventory/by-model` groups `in_stock` units, company-scoped by the
tenant client and branch-scoped by the same `assertAssignedToBranch` check
`listStock` makes.

**Folded by brand and model, not by product id.** Storage and colour live in
`products.variant`, which is in the `(company, brand, model, variant)` unique
key — so four 17 Pro Max in four colours are four product rows, and grouping by
id reports `1, 1, 1, 1`. True, and useless. The colours sit one level down and
always add up to the headline.

Derived on every request. No stored total, no client counter: a maintained
number drifts the first time a sale or a transfer takes a path nobody updated,
and the drift is silent.

### What `variant` actually means — audited, not assumed

`schema.prisma` says it outright: *"`products.variant` already carries storage
and colour"*. So:

- **No market/region selector was built.** It would be a fact nothing has ever
  recorded, and a fourth term in the unique key — a product row per market for a
  distinction no shop has made. This is a **deliberate deviation** from the
  checkpoint's conditional wording, and the audit is why.
- `Pro`/`Plus`/`Ultra` are not variant values; they are model names.

Storage and colour are now two lists from `/device-catalogue/attributes` — from
the server, so the app holds none of its own. `Other` is an ordinary row and
the no-signal fallback. Every legacy value opens, shows and saves.

### A phone is never a quantity

"How is it counted?" no longer offers Quantity for a phone — removed, not
greyed out. The signal is the brand being in the device catalogue (server-owned,
a catalogue of phones); a category's `defaultTrackingType` answers a different
question. When it cannot tell it says "not a phone", so **accessories keep
quantity tracking**.

### Live verification, and the fixture put back

`staging-verify-model-count.ts`: 20 units across 19 models → iPhone 11 **2 → 3**
on one added unit → no other model moved → duplicate refused by the database
itself → **back to 20**. The delete is in a `finally`.

`audit-duplicate-products.ts` is permanently read-only: 13 products, 0
duplicate groups. Merging moves cost and margin between products and is a
human decision.

Scan sheet is now **32 cards** — case 12 is a valid, recognised IMEI that is
**not** in stock, so a device can finally watch a count go up. Its serial is
checked against the database, not assumed free.

### Gates

Backend **109 suites / 1894 tests** · `tsc -p` clean.
Mobile **25 pure suites** · `tsc` clean · lint **0 errors** · Doctor **18/18** ·
EN/AR/FR **1826 identical** · export **68 routes**.
Website, databases and migrations untouched — **no migration was needed**; the
schema preserves every canonical and custom value as strings.

---

### The second device test: my fix broke two other things

Both regressions were the same kind of error — **right about the symptom, wrong
about the mechanism.**

#### The frozen frame

I stopped the camera with `active={false}`. That does stop it, and leaves the
last frame on screen, so the scanner looked like it had taken a photograph. The
frame is whatever the sensor held when the decoder fired, which very often does
not show the digits at all — so the "result" was a picture of a barcode half out
of shot.

The camera is now **unmounted**: no session, nothing to freeze. The panel shows
the decoder's payload as selectable text through the `Identifier` primitive, so
what is on screen no longer depends on where the lens was pointing.

> The assertion pinning this has now been wrong **twice** — first "detach the
> handler", then "deactivate" — and a phone said so both times. The test carries
> that history so the third guess is not a repeat of the first.

#### The disappearing product

I sent the accepted IMEI down `/scan` through a `silent` `useScan` that had
**no `onResult`**. The recognised product came back and was thrown away.
"Silent" was meant to mean *no second buzz*; it also meant *no product*.

The lookup now runs when the result APPEARS — keyed on the identifier, guarded
by a ref so a render cannot fire it twice. Early enough to show the phone in the
panel ("In your stock" when recognition is authoritative, "Might be" when it is
a guess), and the complete result reaches the parent on accept: in the
structured `AcceptedImei` **and** through `onResult`, the channel every
embedding screen already listens on.

#### Audited: it is not OCR

The accepted identifier comes from `BarcodeScanningResult.data` → `classifyScan`
→ payload, and nothing else. No `takePictureAsync`, no frame capture, no image
OCR anywhere in the scan path — checked across the sheet, the target, the hook
and both `lib/scan` modules. No camera frame is persisted or displayed. The OCR
confusion table left from the retired milestone lives in `lib/imei.ts` and is
unreachable from here; only `tacOf` is imported from it.

#### Gates

Mobile **24 pure suites** (scanner behaviour now **29 assertions**) · `tsc`
clean · lint **0** · Doctor **18/18** · EN/AR/FR **1810** identical · export
**68 routes**. Backend, website, databases and Test Store fixtures untouched.

---

### The first physical-device test

**Every one of the seven defects survived TypeScript, the linter, Expo Doctor, a
68-route web export and a 20/20 HTTP recognition run.** The gates were green and
the feature did not work. That is the finding; the individual bugs are almost
secondary.

#### The camera never stopped

Detaching `onBarcodeScanned` stops us REACTING; it does not stop the camera. The
preview stayed live behind the result, still decoding — which a person reads as
"it is still scanning". `active={live}` deactivates the capture session itself.
Both are needed and only one was there.

#### "Use this IMEI" did three wrong things at once

It waited for `/scan` before closing, so the accepted result appeared only after
the sheet was closed by hand. `useScan` fired a SECOND haptic on top of the
detection's. And `accepted` had no render branch, so the sheet fell through to
the camera view and **looked like it had gone back to scanning**.

It now transitions once, hands the parent the complete result — identifiers,
classified payload, TAC suggestion, conflict flag — and closes itself. The
`/scan` call still happens so recognition keeps learning, through a new
`silent` mode. A synchronous `accepting` ref guards it: a double tap lands
before React re-renders, and two accepts meant two `onClose` calls.

#### Manual entry was in the wrong place

Under a live viewfinder, in every state. Somebody who opened the camera has
already chosen to scan. It moves to the field on the intake page beside the
camera icon — which is where the choice actually happens. **The no-camera
fallback stays**; without it a denied permission strands the user.

#### The form was unfinishable with the keyboard open

A pinned footer and a soft keyboard are natural enemies. Three fixes, all
required:

  1. `KeyboardAvoidingView` lifts the frame on iOS. Android resizes its own
     window and must NOT be given a behaviour, or the two corrections fight.
  2. The scroll area reserves the footer's **measured** height — a constant is
     wrong on every screen whose footer has two buttons instead of one.
  3. Blank space dismisses the keyboard, with
     `keyboardShouldPersistTaps="handled"` so the wrapper does not eat the
     first tap on a button.

#### Twenty tests, and one that taught me something

`lib/scanner-behaviour.test.ts`. One failed honestly: I asserted "Add second
IMEI" must not resume the camera, and it must — it means "now scan the other
SIM". The real contract is that only an **explicit human decision** resumes the
camera, never a render and never a completed lookup.

#### Gates

Mobile **24 pure suites** · `tsc` clean · lint **0** · Doctor **18/18** ·
EN/AR/FR **1808** identical · export **68 routes**. Backend, website, databases
and staging fixtures untouched.

---

### The QR fixtures, and where the dependency is allowed to live

#### Cases 2 and 3

```
2 · IMEI: <synthetic-imei>
3 · IMEI1: <synthetic-primary>
    IMEI2: <synthetic-secondary>
```

Black modules on white, medium error correction, **four-module quiet zone** —
checked by arithmetic rather than trusted, because a missing quiet zone is the
classic reason a perfectly valid QR will not decode. Both payloads are built
from the fixture's own synthetic identifiers; no real IMEI is involved.

The sheet is now **31 cards · 29 Code 128 · 2 QR**, all ten types.

#### Why a dependency rather than hand-rolling

Code 128 stays hand-rolled: it is small and entirely mechanical. QR is not —
Reed–Solomon, masking and format information are exactly what a hand-written
encoder gets subtly wrong, producing a symbol that looks right and does not
decode. That is the worst possible fixture, because it fails a test the scanner
actually passed.

#### `@types/qrcode` WAS required, contrary to first appearances

`tsc -p` compiled the script without it. That was misleading: `scripts/` is not
in tsconfig's `include`, so the project build never reads the file. `ts-node`
does, and raised **TS7016** the moment the script actually ran. Added, pinned.

#### Confined

Not in `dependencies` · `npm ls qrcode --omit=dev` empty · absent from compiled
`dist/` · absent from the mobile package and its web bundle. Production
advisories measured **before and after: 17 both times**, and `qrcode` is
implicated in none of them.

#### The spec caught a real mistake

Fifteen tests on the sheet, and one failed honestly: I had invented a secondary
IMEI for the fixture constants and got the check digit wrong. It now uses the
real synthetic pair from staging and asserts both are Luhn-valid.

#### Gates

Backend **107 suites / 1852 tests** · `tsc -p` clean · production advisories
**17, unchanged** · **demo byte-identical** (1/9/7, 10 051.00, `bcc38d96…`) ·
staging fixture untouched (20 units, 20 TACs, 0 recognition rows).

Mobile and website untouched this checkpoint.

---

### The coverage contradiction, and the scan sheet

#### What the contradiction turned out to be

The report said development had zero `tac_catalog` rows, seven confirmed
`ProductRecognition` records, and that no IMEI resolved there. **Two of those
three statements were wrong.**

**Four of the seven were BARCODE mappings.** Only three are `codeType: 'tac'`,
and only that kind answers "what phone is this IMEI".

**Those three resolve with no global row at all.** `resolveTac()` returns
`company_confirmed` with the shop's exact `productId`; the global entry supplies
only the generic brand and model LABELS. A missing global row costs the labels,
not the resolution — and naming a product is the stronger answer anyway.

**So there is no dependency to document.** Confirmed mappings stand alone, and
development recognises three TACs and always did.

#### Proved, not asserted

Seven unit tests on the resolver, and **9/9 over real HTTP** against real MySQL.
Run in staging, because the demo owner's password is env-supplied and the demo
must stay byte-identical.

The run confirms a mapping for a TAC the catalogue has never heard of, then
shows: the owning company resolves it with zero global rows in existence · it
loses only the labels · an **entitled** other company gets `none` · a generic
row added afterwards cannot displace it · an unmapped TAC stays unknown · an
Employee's submission is a proposal that selects nothing.

> The other company had to be an ACTIVATED one. A pending tenant is refused by
> the entitlement guard before the resolver runs, which would have proved the
> guard rather than the isolation. Worth remembering.

Everything the run created was removed; the fixture is exactly as it was found.

#### Coverage, in four parts

| | Development | Staging |
|---|---|---|
| Selector catalogue | 13 / **323** | 13 / **323** |
| Global TAC catalogue | **0** | **20** TACs / 19 models, `synthetic_staging`, Apple |
| Company-confirmed | **3** (one company) | **0** |
| Effective for that company | **3** | 20 |

**`5.9%` keeps its label or it does not get used**: it is *staging's generic
synthetic catalogue coverage*, not system and not production coverage.
Development's equivalent is **0% while still resolving three codes** — which is
the clearest proof the number does not mean what it looks like.

#### The scan sheet

**30 cards, 29 barcodes.** Nine fixture types with the expected result printed
beside each, plus the twenty stock phones:

    1  raw IMEI            6  valid IMEI, unknown TAC   9  ICCID
    4  both SIMs           7  invalid checksum         10  EID
    5  disagreeing TACs    8  wrong length             11  EAN-13

The ICCID and EID are the ones worth having — both are printed beside the IMEI
and both are long runs of digits, which is why they get scanned by mistake.

Every negative fixture is generated in the script and **never written to a
database**. Verified after the run: zero units with a non-15-digit identifier,
Test Store still exactly twenty.

#### Gates

Backend **106 suites / 1837 tests** · `tsc` and `prisma validate` clean · both
databases at `0063` · **demo byte-identical** (1/9/7, 10 051.00, `bcc38d96…`,
7 recognition rows) · staging 42 companies / 20 units / 20 TACs / 0 mappings.

Mobile and website untouched this checkpoint.

---

### Model order, TAC coverage, and a sheet to scan

#### The ordering defect, proved before it was touched

`release_rank` was the release YEAR and was also ordering the list. Both
symptoms were reproduced first:

    1. iPhone 17e        (2026)   <- alone at the top, split from its family
    2. iPhone 16e        (2025)   <- above a newer flagship, alphabetically
    3. iPhone 17         (2025)

Family order and date order genuinely conflict — `iPhone 17e` shipped later
than `iPhone 17 Pro Max` and belongs below it — so one integer cannot hold
both. **Two facts, two columns.** `release_rank` keeps the year and stays
separately queryable; `display_rank` is the position.

Now:

    1. iPhone 17 Pro Max   2. iPhone 17 Pro   3. iPhone Air
    4. iPhone 17           5. iPhone 17e      6. iPhone 16 Pro Max …

`display_rank` is derived from the model's POSITION in the source list, so
correcting the order means moving a line. Spaced by ten, every rank distinct —
so there is **no tie-break**, which is what stops the order changing with the
language. Two `mini` entries were also simply above their standard model and
were moved.

#### Migration 0063

Backed up and restore-proven, both databases, into `prisma_restore_proof`.
Applied first to a restored copy of staging in `prisma_migrate_probe`: 42
companies, 20 units, 323 models, 20 TAC rows, years still 2017–2026, **0**
models unranked, rerun a no-op. Both probes dropped.

> The trailer check in `docs/22` earned its keep — the first demo dump ended at
> `-- Dumping routines` with no completion line. Re-dumped and restore-proven.

#### TAC coverage, counted honestly

Three things that keep being confused, never added together:

| | Staging | Development |
|---|---|---|
| Selector catalogue | 13 brands / **323 models** | 13 / 323 |
| TAC rows (recognisable) | **20** — all `synthetic_staging`, all Apple | **0** |
| Company `ProductRecognition` | 0 | 7 confirmed |

**19 of 323 models — 5.9% — can be recognised from an IMEI.** The rest are
chosen or typed. `scripts/tac-coverage.ts` prints all three and refuses to
total them.

#### Live: 18/18

Brand order with `Other` last · Redmi and POCO independent · **the canonical
Apple order, exact** · both ordering defects gone with the release year intact ·
Samsung reads Ultra/Plus/standard/FE · `reno 13` finds `Reno13` · unknown brand
is an empty list · `complete: false` · **20/20** synthetic IMEIs resolve to
Apple and the intended model · no storage/colour/cost inferred · suggestion not
selection · unknown TAC guesses nothing · seven digits refused · dual-SIM
consistent from both identifiers and one unit · disagreeing TACs give different
answers · synthetic mappings in staging only · cross-company isolation.

#### The scan sheet

`scripts/staging-scan-sheet.ts` — 20 phones, 25 Code 128 barcodes, primary and
secondary. Two things it gets right: the guard checks the **database name**, not
`APP_ENV` (the script loads `.env.staging` itself, so an `APP_ENV` check could
never fail), and the page is pinned to a light colour scheme (a dark-mode
browser renders black bars on a dark card, and that does not scan).

#### Gates

- Backend **106 suites / 1830 tests** · `tsc`, `prisma validate` clean · both
  databases at `0063` · catalogue 61/61.
- Mobile **23 pure suites** · `tsc` clean · lint **0** · Doctor **18/18** ·
  parity **1808** · export **68 routes**.
- Website **37**, untouched.
- **Demo byte-identical**: 1/9/7, 10 051.00, `bcc38d96…`, 559 audit, 0 payments.
  Staging 42/57/20, 20 TACs.

---

### Device catalogue, dependent selectors, TAC recognition

#### The audit came first, and most of it was already built

`ProductRecognition` already was the company-scoped authority — proposed /
confirmed / superseded — and `resolveTac()` already ran the ladder: a confirmed
company mapping wins, a proposal is shown but never auto-selected, otherwise
generic identity, otherwise unknown. Storage, colour, condition, cost and price
were already never inferred. **No competing recognition system was built.**
`products.brand/model/variant` were reused as they stand.

#### Why a migration was genuinely required

Nothing could represent a BRAND. `tac_catalog` is keyed by TAC and answers only
"what is this code" — not "what brands are there", which is what a selector asks
before anybody has scanned anything. Aliases, display order, release ordering
and the Redmi/POCO relationship had nowhere to live.

`0062` adds `device_brands` and `device_models` and gives `tac_catalog`
provenance: source, active flag, review date, optional links to catalogue rows.

**Backed up and restore-proven before it ran anywhere real.** Both databases
dumped, both restored into `prisma_restore_proof` and checked row for row
(42/57/20/20, 83 tables, 24 triggers — identical), then dropped. Clean install
and upgrade both tested on `prisma_migrate_probe` against a restored copy of
staging: 42 companies, 20 products, 20 units untouched, and a legacy free-text
`tac_catalog` row kept its brand and model while gaining a source. Both probe
databases dropped.

#### What is honest about the catalogue

**13 brands, 323 models**, `source = 'curated'` — not `official`, which is
reserved for a licensed feed. `/device-catalogue/version` returns
`complete: false` **in the payload**, because a client that believed it held
every phone would stop offering the manual field.

| Brand | Models | | Brand | Models |
|---|---|---|---|---|
| Apple | 35 | | Tecno | 28 |
| Samsung | 67 | | realme | 28 |
| Redmi | 26 | | Infinix | 22 |
| OPPO | 27 | | Huawei | 19 |
| POCO | 19 | | itel | 18 |
| Xiaomi | 17 | | Honor | 17 |

**Broad production coverage needs licensed GSMA data.** Said in the code, the
migration, the docs and the API payload.

#### The selectors

Brand first, then that brand's models, newest first, searchable — in the
SHARED `ProductForm`, so create, edit and every intake path got it at once.

`Other brand` and `Other model` are ordinary options. Legacy free-text products
open in manual mode ready to edit; a lower-case `samsung` still matches Samsung.
Changing the brand clears the model **and nothing else** — proved live with a
typed variant that survived.

Manual entry is a MODE somebody chose, not a state inferred from an empty field.
Inferring it opened a brand-new form already showing "type the brand".

#### Live: 16/16, and 20/20 recognition

Brand order with `Other` last · Redmi and POCO independent with Xiaomi recorded
· 35 Apple models newest-first · `reno 13` finds `Reno13` · unknown brand is an
empty list not an error · `complete: false` · **all 20 synthetic IMEIs resolve
to Apple and the intended model** · no storage/colour/cost inferred · suggestion
not selection · unknown TAC guesses nothing · a seven-digit TAC is refused ·
dual-SIM resolves consistently from both identifiers and is one unit ·
disagreeing TACs give different answers so the app can ask · synthetic mappings
in staging (20) and not in development (0) · another company sees nothing.

Browser: the selectors in Arabic at 375 px, right-aligned, no overflow.

#### Gates

- Backend **106 suites / 1822 tests** · `tsc` clean · `prisma validate` clean ·
  both databases at `0062` · catalogue **61/61**.
- Mobile **23 pure suites** · `tsc` clean · `expo lint` **0 problems** · Doctor
  **18/18** · EN/AR/FR **1808** identical · export **68 routes**.
- Website **37 tests**, unchanged and untouched.
- **Demo byte-identical**: 1/9/7, 10 051.00, checksum `bcc38d96…`, 559 audit,
  **0 payments**. Staging **42 / 57**, unchanged by this checkpoint.

---

### Usability and the retained fixture

#### The banner came off, the environment did not

`STAGING — test data only` sat across the top of every screen. It is gone:
component deleted, mount removed, and the drift test that used to REQUIRE it now
forbids the phrase in every casing and dash, across the layout, all three
authentication screens, the subscription screen and all three catalogues. A scan
of all **68 exported routes** and the website build finds it nowhere.

`APP_ENV`, the separate database and its guards, the staging-only scripts,
loopback-bound administration, separate secrets and log classification are all
untouched. **This is still staging.**

#### Language, before you can sign in

The setting lived behind the sign-in screen — so somebody handed a phone in a
language they cannot read could not sign in to change it, and could not change
it without signing in.

English · Français · العربية in their own words, **no flags**, on sign-in,
account creation and (compact) verification. Same store, same `erp.language`
preference, no second catalogue. Live in a browser: the copy changes instantly,
the preference persists, and **switching mid-form left every typed field in
place**.

One thing the browser caught: the restart notice was showing on load, before
anybody had switched anything, because `restartRequired` is also raised during
hydration. It now appears only after a switch made *there*.

#### One way into the portal

`subscription-blocked` opened the account URL with no ticket, so the one screen
where somebody taps "manage my subscription" landed an authenticated Owner on a
password form. It now uses `useAccountPortal()` — one hook, one copy of the
reasoning, a **ref** for the duplicate-tap guard because `if (busy) return`
reads state React has not updated yet.

#### Test Store

Provisioned through the real services: `RegistrationService` for the company,
branch, Owner, canonical roles and mappings; the real continuation and challenge
for the contact (and its session revoked immediately);
`SubscriptionLifecycleService` for an audited, **complimentary** grant with no
payment invented. `currentPeriodEnd` stays null on purpose — that is what stops
a grant reading like money that arrived.

20 variants, 20 units, **5 dual-SIM — five units with two identifiers, not ten**.
IMEIs generated locally from a non-allocated test range with the app's own Luhn
helper, validated before insertion, unique across **both** identifier columns.

The command refuses outside staging, writes nothing without `--apply`, is a
proven no-op on a rerun, and **refuses to adopt a `store@test.com` it did not
create**.

#### Live: 19/19, plus 3 browser checks

Sign-in as the Owner · Owner of Test Store · contact verified · active by grant ·
**0 payments** · quote **500 MRU** · one branch `Main Store` · 20 variants ·
20 units all in stock · every primary IMEI Luhn-valid · unique across both
columns platform-wide · 15 primary-only and 5 dual · either identifier finds the
same unit · the Owner reads inventory over HTTP · no sales, expenses, customers
or extra staff · another company sees nothing · Owner mints a handoff (201) and
a Manager of the same shop is refused (403) · the probe Manager left no trace.

Browser: language switching in all three languages, Arabic reading right-aligned
at 375 px, and the banner phrase absent from every exported route.

#### Counts

Staging **41 → 42 companies**, **56 → 57 users** — exactly one company and one
Owner, as predicted. The **38 retained acceptance tenants are still there** and
are not reported as deleted. 20 products, 20 units, 1 administrator,
**0 subscription payments**.

**Demo byte-identical**: 1 company, 9 users, 7 sales, 10 051.00, checksum
`7336ef18…`, mappings 61/15/13/4/3/43/20, audit 559, 0 payments.
**Development received nothing**: no `Test Store`, no `store@test.com`, no CP rows.

#### Gates

- Backend **105 suites / 1803 tests** · `tsc` clean · `prisma validate` clean ·
  both databases up to date at `0061` · catalogue **61/61**.
- Mobile **22 pure suites** · `tsc` clean · `expo lint` clean · Doctor **18/18**
  · EN/AR/FR **1796** identical · export **68 routes** · raw-colour,
  hardcoded-copy, secure-storage and trusted-URL audits clean.
- Website **37 tests** · `tsc -b` clean · production build clean ·
  **0 advisories** · `ar` → `dir="rtl"`, `fr`/`en` → `ltr`.
- `@@GLOBAL.sql_mode` still empty. **Not touched.** Still deployment work.

---

### CP4 complete. CP8 run live: **66/67**.

The environment: the documented single origin, reproduced without Docker (it is
not installed here) as a Node transcription of `deploy/nginx-site.conf` — same
headers, same SPA fallback, same `/admin` loopback rule. API on :3011 bound to
loopback, edge on :8088. `docs/39`'s measured boundary table reproduced exactly:
API direct from the LAN refused, `/admin` 404 from the LAN and 200 from
loopback, `/account` and `/api/health` 200 from the LAN.

#### Six defects, found by running it

| # | What | Where |
|---|---|---|
| 1 | Manager and Employee could each mint an Owner portal ticket (**201**) | `platform.controller.ts` |
| 2 | The one-time ticket was written to the log in full, twice per request | `app.module.ts` |
| 3 | A **pending** shop was refused the payment instructions, so the dialog silently never opened | `route-classification.ts` |
| 4 | `Secure` cookies on plain-HTTP staging — discarded by the browser, hidden by localhost | `cookies.ts` |
| 5 | The portal gated on a bearer token, so arriving from the app showed a password form | `Portal.tsx` |
| 6 | Cleanup proposed deleting the staging baseline, and promised tenant deletions it can never make | `staging-cleanup.ts` |

Every one had a green suite around it at the time. Each fix carries a
regression test naming the live run.

#### CP4 — both missing halves proved

**Role refusals**, over real HTTP with real users of a real company: Manager
403, Employee 403, platform administrator 401 (an admin session is not a tenant
JWT), tenant Owner refused all four administrator routes and refused
`suspend` outright. Another Owner's ticket lands in **their** company. The
handoff is Owner-gated on `settings.manage` — company-scoped, undelegatable,
held by the Owner and the company administrator alone.

**Session fixation**, with actual cookies and actual session rows. An attacker
cookie planted before the exchange acquires nothing (401), the exchange issues a
**new** cookie, the new `auth_sessions` row is bound to the correct Owner and
company (sessions n → n+1, joined back to the Owner's email), the planted cookie
is still worth nothing afterwards, the ticket is consumed exactly once, replay
fails to the same neutral destination, the landing URL is `/account?welcome=1`
and clean, the cookie is HttpOnly + SameSite=Lax + path-scoped, nothing reaches
the log or the audit detail, and **no payment, grant or entitlement transition**
happened.

#### CP8 — 66/67 live, 1 device-pending

52 API/database checks and 22 browser checks, on real MySQL over real HTTP.
Highlights that are easy to under-claim:

- The **real app** was driven in a browser (its web export, served from the edge
  so the origin matches): `Create account` navigated `/login` → `/register`
  with **zero** `window.open` calls, the form asks for no Store ID and no
  personal ID, and the whole registration → verification → session → portal
  chain ran end to end.
- **Item 20 is proved, not asserted.** The app's own request order was
  `register` → `verify/start` → `verify/confirm` (session issued) →
  `portal-handoff` → `portal-session`. The handoff is authenticated, so it
  cannot precede the session.
- The payment dialog was measured with a `fetch` spy: selecting a provider and
  copying a code issue **no network request at all**, a refused clipboard is
  harmless, focus is contained and restored, `Escape` closes, the code stays
  `dir="ltr"` in Arabic, and no payment row exists.
- EN/AR/FR with correct `lang`/`dir`, light and dark, 375 px and 1280 px, no
  overflow, nothing clipped, and **empty** `localStorage`/`sessionStorage`.

**Device-pending: item 25** — browser-opening failure preserving the session. On
a web export a browser cannot be refused the way a phone refuses one. It stays
pinned by unit test and by the ordering above. `docs/24` §9j records what the
browser did and did not cover.

#### Cleanup, and one thing it cannot do

Dry run → `--apply --since --remove-admin` → dry run, all recorded. The scoped
run targeted **38** companies — exactly the 38 created in the window, value-
deduplicated — and left the 3 baseline companies alone. Administrator sessions,
intents, continuations and the temporary administrator are gone; the deliberate
staging administrator is kept; **71 audit events preserved**, 29 with their
`admin_id` released and **all 29 still naming their actor, action, target and
reason**. The replay is a no-op.

🔴 **Staging did NOT return to 3 companies / 7 users.** It is **41 / 56**, and
cannot be otherwise: every table referencing `companies` restricts deletion,
including ones registration itself creates, so `company.delete()` can never
succeed for a registered shop. Deleting children in dependency order is not the
fix — nothing financial is hard-deleted here. Reclaiming them means restoring
the database (`docs/22`).

#### Integrity

**The demo is byte-identical.** 60 migrations through `0061`, permissions 61,
role_permissions 159, checksum `41df5104…`, mappings
`owner=61 administrator=15 branch_manager=13 sales_employee=4 warehouse_employee=3 store_manager=43 store_employee=20`,
1 company, 9 users, 7 sales, **10 051.00**, units checksum `7336ef18…`, audit
559, **0 subscription payments**. Zero CP4/CP8 rows in development.

#### Verification

- Backend **104 suites / 1787 tests** · `tsc` clean · `prisma validate` clean ·
  both databases up to date · catalogue **61/61**.
- Website **37 tests** (32 + 5 new) · `tsc -b` clean · production build clean ·
  oxlint clean.
- Mobile **20 pure suites** · `tsc` clean · `expo lint` clean · **Doctor 18/18**
  · EN/AR/FR **1796** identical · export **68 routes** · raw-colour audit clean
  (its one hit is a comment saying not to) · secure-storage audit clean · every
  `openURL` builds from configuration.
- `sql_mode` on this server is still empty. **Not touched.** Still deployment
  work.

---

### CP3, CP5 and CP6 complete. CP4 partly proven. CP8 not started.

| Repository | HEAD |
|---|---|
| `erp-backend` | `7e2f356` |
| `erp-mobile` | `a710d64` |
| `retail-erp-control-web` | `ea80b47` |
| `erp-docs` | *this commit* |

#### CP3 — registration is in the app

`Create account` pushes a screen; nothing opens a browser to register.
`app/(auth)/register.tsx` and `app/(auth)/verify.tsx` run against the exact
CP2-proven contract.

- One idempotency key per attempt, generated on mount, reused on every retry.
- The duplicate guard is a **ref**, because two taps land before React renders.
- The password is cleared the moment registration returns and **never replayed**.
- The continuation lives in SecureStore through the existing wrapper and is
  deleted on success, restart and cancellation.
- **Order is pinned by test:** the session is adopted BEFORE the browser is
  tried, so a refused browser leaves the account and session alone. No failure
  path deletes a valid session, and every portal attempt asks for a **fresh**
  ticket — a spent or uncertain one is treated as spent.
- The URL carries the one-time ticket and nothing else.

The navigation drift test caught both new routes unclassified, exactly as
designed.

#### CP5 — the payment dialog is mounted

Opens once automatically for somebody arriving from the app, closable,
reopenable from a control that is always present. Instructions are fetched
alongside the subscription; **their failure is not the page's failure**.

18 rendering tests, mostly about what must not happen: selecting any provider
sends nothing (asserted against a `fetch` spy), copying sends nothing and
copies the selected provider, a blocked clipboard is harmless, and the dialog
never contains *paid*, *confirmed*, *verified* or *activated*. All five
providers show `00000`; Bankily is default and always returnable to; the code
stays `dir="ltr"`.

#### CP6 — staging cleanup repaired

It **failed outright** before. `platform_audit_events.admin_id` is a nullable
FK with no delete action, so it RESTRICTS; the repair **releases the reference
and keeps the audit event**, which is what the schema always intended.

A second defect surfaced while fixing the first: the synthetic-company `Set`
held `Buffer`s, which dedupe by identity — it reported **7** companies where
staging has **3**. Now dry-run by default (`--apply` to delete), the staging
administrator is preserved unless `--remove-admin`, and unspent continuations
and handoff tickets are expired. 9 focused safety tests.

**No migration.** The schema was right; the script was wrong.

#### CP4 — partly proven

The pre-existing `portal-handoff.spec.ts` already covers **17** of the audit
points: company/user/purpose binding, 90-second TTL, hash-only storage,
single-use, replay refusal, concurrency, expiry, wrong purpose, cross-company,
disabled and deleted users, no payment/grant/subscription change, the ticket
absent from logs, and the HttpOnly cookie. CP2 additionally proved live that a
portal ticket cannot complete a registration.

**Added here:** the `ALWAYS_ALLOWED` list is now pinned **by name**, with tests
that no operational route (sales, units, inventory, purchases, transfers,
returns, refunds, expenses, closing, suppliers, loans, consignments, products,
pricing, goals, imports) survives a lapsed subscription, and that the handoff is
the only `platform/` route allowed through.

**Still unproven:** Manager / Employee / platform-administrator handoff refusal
over real HTTP, and session fixation.

#### Verification

- Backend **102 suites / 1760 tests** · `tsc` clean · `prisma validate` clean ·
  schema up to date · both databases 60 applied through `0061`.
- Mobile **20 pure suites** (identifier drift now 37 assertions) · `tsc` clean ·
  `expo lint` clean · **Expo Doctor 18/18** · EN/AR/FR **1796** identical ·
  web export **68 routes** including both new ones.
- Website **32 tests** (14 + 18 new) · `tsc -b` clean · production build clean ·
  oxlint clean · `npm audit` **0 vulnerabilities**.
- **Demo byte-identical**: 1 company, 9 users, 7 sales, **10 051.00**, units
  checksum `7336ef1871b1216954e2921b1c0e05fa`, role mappings
  `owner=61 store_manager=43 store_employee=20`, **0 subscription payments**.
- Staging intact at 3 companies / 7 users. Verification port released.

---

### CP1 — migrations aligned. CP2 — authentication proven over real HTTP.

`erp-backend` `eed3219`. **101 suites / 1748 tests**, `tsc` clean.

#### CP1 · both environments now at `0061`

| | before | after |
|---|---|---|
| development (`phonestore`) | 57 applied, highest `0058` | **60 applied, highest `0061`, zero pending** |
| staging (`prisma_staging`) | 59 applied, highest `0060` | **60 applied, highest `0061`, zero pending** |

Development: target name validated before anything ran, full state recorded,
backup taken (`phonestore-pre0059-20260829-013551.sql`, 555 232 bytes, 83
tables, **0 raw `_binary`**, valid UTF-8), and **restore-proved** into a
disposable database whose every checksum matched the live record exactly.

Staging went through `scripts/staging-apply-migrations.ts`, which owns the
load-bearing `override: true` env-order safeguard, refuses a non-staging name,
and restore-proves its own dump. Catalogue gate after: **61/61**.

Both diffs show **only three lines changed**: the migration count, the highest
migration name, and the `purpose` enum. Permission catalogue, role mappings
(`owner=61 store_manager=43 store_employee=20`), tenant data, subscriptions,
payments and unit checksums all byte-identical.

**Clean replay** on a disposable strict-mode database: full history through
`0061`, schema valid, **61/61 catalogue from migrations alone**, the two
purposes distinct, and **zero tenant or demo rows created**. All three
disposable databases dropped.

> ⚠️ **Finding:** this MySQL runs with an **empty `sql_mode`** — not strict at
> all. The first replay was therefore not a strict-mode replay. It was redone
> with `STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION`
> set globally, and the original empty value restored afterwards. Worth deciding
> whether the server should run strict permanently.

#### CP2 · 29/29 over real HTTP and real MySQL

Backend on port **3012** against staging. Successful path: continuation issued
and **no session**; stored **hash-only**; challenge **bound to that exact
continuation**; code retrieved the staging-only way; completion issues **exactly
one** session; contact marked verified; **both credentials consumed**;
subscription still **pending**; portal handoff available; **protected ERP data
blocked**.

Every adversarial refusal passed: a historical consumed verification, another
registration's challenge, cross-company, a **portal ticket used for
registration**, an expired continuation, a rotated challenge, a wrong code, a
replayed continuation, an unknown continuation, a disabled Owner.

**Concurrency was measured by SESSION ROWS, not HTTP status**: three
simultaneous completions → one session, one 200.

#### Two defects real HTTP found that unit tests could not

1. **Completion died with "Database request error".** `SessionsService.create`
   used its own connection while completion held an exclusive lock on the
   Owner's row; `auth_sessions` has an FK to `users`, so the insert waited on a
   lock its own request held. `create` now takes an optional transaction
   client — which also makes the rollback honest. **The pre-existing portal
   handoff does not have this bug**: it never locks the user row first.
2. **A pending Owner could not create a portal handoff (403).**
   `ALWAYS_ALLOWED` blocks by default so a new route is refused "until somebody
   decides otherwise". Every new shop is pending by definition and this is the
   route to the page that ends that state, so it is now allowed, with the
   reasoning recorded in the rule.

#### Fixtures and integrity

21 synthetic tenants created and **all removed**; staging back to its original
3 companies / 7 users. Both environment snapshots are **identical to their
post-migration records apart from the label line**. Development was never
touched by CP2. Port 3012 released.

> ⚠️ `scripts/staging-cleanup.ts` **fails** with a foreign-key violation on
> `platformAdmin.deleteMany()`. Pre-existing, unrelated to this work, and it is
> why the fixtures were removed with a scoped script instead.

---

### Registration authentication — the security correction is DONE

`erp-backend` `93b13c7`. **101 suites / 1748 tests** green, `tsc` clean,
`prisma validate` clean.

#### Why `isVerified(destination)` is not authentication

It answers for the **most recent consumed verification of an address, ever** —
no bound on when, by whom, or in which attempt. An endpoint issuing a session
on it would hand an Owner session to anyone who could name an address somebody
had once verified, with no password in the story. It keeps its existing callers
but now carries a warning saying exactly what it is not.

#### The chain that replaced it

    one registration attempt
  + one short-lived continuation credential      (15 min, hash-only, single-use)
  + one verification challenge BOUND to it       (verification_intents.challenge_id)
  + successful consumption of that exact challenge
  = one normal Owner session from SessionsService

Every link is re-checked at spend time. The challenge and the continuation are
consumed **in one transaction**, so neither can be spent without the other, and
two concurrent completions yield exactly one session.

Other properties: the destination comes from the **Owner record, never the
request**, so a stolen continuation cannot redirect a code. Completion marks the
contact proved, which is what stops a public idempotency key minting a second
continuation for an account that now has a working password. A resend rebinds,
so an older code stops working.

#### `0061` — needed, and one enum value

`verification_intents` already carries every link of the chain and already
implements and tests single-use consumption under concurrency, so `0061` adds
only `registration_continuation` to `OtpPurpose` — the same shape as `0060`.

The purpose is **distinct from `portal_handoff` on security grounds**:
`resolve()` matches on purpose, so one shared value would make a ticket minted
to open a subscription page spendable to complete somebody's registration. A
test pins this.

`confirmChallenge()` is new because `confirm()` does a destination lookup,
which is precisely the hole.

#### 🔴 Migrations are NOT applied

| Environment | 0059 | 0060 | 0061 |
|---|---|---|---|
| development (`phonestore`) | ✗ | ✗ | ✗ |
| staging (`prisma_staging`) | ✓ | ✓ | ✗ |

`0060` **pre-existed this takeover** (commit `3a43ca8`) — it was not created
here. Applying anything needs the backup and restore-proof ritual in
`docs/22`, and that was not rushed at the end of a long session.

---

### Registration pivot — PARTIAL. Read this before continuing.

All four trees are clean, pushed and green, so the workspace is safe to pick
up. **The milestone itself is unfinished.** What follows is exact.

| Repository | HEAD |
|---|---|
| `erp-backend` | `3a43ca8` (unchanged this session) |
| `erp-mobile` | `14b9d33` |
| `retail-erp-control-web` | `3d0e277` |
| `erp-docs` | *this commit* |

### Done

- **CP2 — website registration retired.** `Register.tsx` is a 58-line stub: the
  old address resolves, renders no form and submits nothing. The landing page no
  longer offers `Create account`. Committed `3d0e277`.
- **CP4 component — the payment modal exists and is green.** Server-driven
  provider list, `dir="ltr"` code, and it states on its face that it takes no
  money. **It is NOT mounted** — no route imports it.
- **CP1 rules — `mobile/lib/registration.ts`** with 20 pure assertions, and the
  full EN/AR/FR vocabulary (**1796 keys each**, identical order). Committed
  `14b9d33`.
- **CP3 backend was already built** by the interrupted session (`3a43ca8`):
  `POST portal-handoff`, an exchange that 302-redirects to a clean URL,
  `PortalHandoffService`, `GET payment-instructions`, and migration
  `0060_portal_handoff_intent`.

### Two defects found in the interrupted session's uncommitted work

Both were in `PaymentModal.tsx`, and both were found by **running the gates**
rather than reading the file:

1. A raw `rgba(0,0,0,.55)` scrim. The project's own colour contract test
   refuses it, so the website suite was **red at baseline** — and it would have
   been wrong in dark mode too. There is a `--surface-scrim` token for this.
2. A `ref` passed to the shared `Button`, which does not forward one. `tsc -b`
   **and the production build** both failed, while `vitest` passed — because
   vitest does not typecheck. A green test run was not a green repository.

### What remained at the time — since shipped, except the design question

> **Stale as written.** `mobile/app/(auth)/register.tsx` exists and
> registration lands in the app; the CP1/CP3/CP4 items below were completed in
> later sessions. Kept for the **open design question**, which is not resolved
> and is security-relevant. The live list is under *What remains* at the top.

- **CP1 screen.** `mobile/app/(auth)/register.tsx` does not exist. `login.tsx`
  still calls `openSignup()`, which opens a browser — the superseded behaviour.
  The rules and every translation key are in place and unused.
- **CP1 verification UI**, against the existing
  `verify-contact/start` ` / confirm` endpoints.
- **🔴 OPEN DESIGN QUESTION — the post-verification session.**
  `POST /platform/register` returns `{companyId, publicStoreId, branchId,
  ownerUserId, status, created}` and **no tokens**. The brief forbids replaying
  the registration password to simulate login, so the Owner session must be
  issued another way.
  `ContactVerificationService.isVerified(destination)` exists and looks like the
  obvious binding — **it is not sufficient on its own.** As written it answers
  for the most recent consumed verification of that destination, so an endpoint
  trusting it alone would let anyone who ever verified a contact mint an Owner
  session with no password. Any design must bind to the specific registration
  attempt, be single-use and short-lived. **This was deliberately not
  improvised at the end of a long session.**
- **CP3 mobile half** — open the portal via the handoff. `.env.local` already
  exports `EXPO_PUBLIC_PORTAL_URL`.
- **CP4 wiring** — mount the modal in `Portal.tsx`, auto-open once after a
  handoff, reopenable.
- **CP5 / CP6**, the backend / mobile / website test lists, the 40-step
  real-MySQL and browser acceptance, and `docs/21`, `24`, `37`, `38`, `39`.

### Verification at this checkpoint

- Backend **100 suites / 1731 tests** green (untouched this session).
- Mobile `tsc` clean · `expo lint` clean · **20 pure suites** · EN/AR/FR
  **1796 keys**, identical order.
- Website **14/14** · `tsc -b` clean · **production build clean** · oxlint clean.
- No migration was added this session; `0060` already existed.
- **Nothing was run against a device, and no acceptance flow was executed.**
  No synthetic company was created, so there are no fixtures to clean and the
  demo tenant is untouched.

---

### HEADs — all four repositories clean and level with their remotes

| Repository | HEAD |
|---|---|
| `erp-backend` | `c05d04c` |
| `erp-mobile` | `b973f64` (unchanged — no mobile change was needed) |
| `retail-erp-control-web` | `ad923df` (unchanged — no website change was needed) |
| `erp-docs` | *this commit* |

Nothing was force-pushed and no shared history was rewritten.

---

## The defect this closed

**A tenant's authority is only ever as complete as the catalogue behind it.**
`AccessService` resolves permissions solely from `role_permissions`, and those
rows can only reference `permissions` rows that exist.

Until now **no migration created the catalogue.** The base keys — `sale.create`,
`report.view`, `user.manage` and 14 others — were inserted only by
`prisma/seed.ts`. Later feature migrations each added the handful of keys they
introduced, which is how a deploy-only database reached exactly **44 of 61**.

**The demo seed concealed it** by doing two jobs at once: it seeds the reference
catalogue *and* the demo company. Every environment anybody had looked at ran
it, so the catalogue was always complete there. Staging — the first environment
built deliberately without the demo company — was the first to show the gap, and
did so loudly, because the role repair refused to provision a partial Owner.

---

## Migration `0059_permission_catalogue_reference_data`

**Reference data only.** It inserts catalogue rows and grants nothing:

- no schema change — no `ALTER`, no `CREATE TABLE`, no Prisma schema edit;
- no `role_permissions`, so no role's authority moves;
- no tenant, user, branch, subscription, sale or demo record;
- **no existing row modified.**

`NOT EXISTS`, never `INSERT IGNORE` or `REPLACE`. `IGNORE` would also swallow a
genuine error — a truncated label under strict mode, a broken constraint — and
leave the catalogue quietly short, the exact class of silent failure this ends.
`REPLACE` would delete and reinsert, discarding ids `role_permissions` points at.

Generated from `src/rbac/role-permissions.ts` by
`scripts/generate-catalogue-migration.ts`, so nobody hand-maintains a second
list of keys. The SQL is an **immutable historical snapshot, not a second
runtime source** — nothing under `src/` reads a migration file, and a test
enforces it.

> **A future permission needs a FUTURE migration. Never edit `0059`.**

### Hashes — unchanged by all of this

| | |
|---|---|
| Canonical key-set SHA-256 | `52b7200d09710a251d424a97fe24900e9dbff01e250195ba73e6e83ab388b4ec` |
| **Role-matrix SHA-256** | `fc577f63451ec8c0792b8dc034f33f5dabbf402f2190a6cb75647c51933cf687` |
| Full-canon SHA-256 | `0ddb8c04314656dc98f4c293726dedc2dcefbdc414fc1d78fd0ae967af9d668e` |

Owner 61 / Manager 43 / Employee 20, unchanged. No permission key was added,
removed, renamed or reinterpreted.

---

## Proof, on real disposable MySQL databases

Both were dropped afterwards; no `%proof%` database remains.

### Clean installation — `prisma_staging_cleaninstall_proof`

Migrations only, **no demo seed**: 58 applied, highest `0059`, **61 keys**, and
`companies=0 users=0 roles=0 role_permissions=0 sales=0`. Then, live against a
backend on port 3012: **25 of 25 checks passed** — self-registration succeeded on
a seedless database, its roles received exactly **61/43/20**, entitlement was
`pending` and business actions gated, activation worked, the Owner reached a
`report.view` route with `x-branch-id`, Manager was allowed `report.view` and
denied `user.manage`, Employee was denied both and allowed the sales surface,
all three tenant roles were refused by the platform administration API, and a
branch the tenant does not own was refused.

### Upgrade path — `prisma_staging_upgrade_proof`

Built to the pre-`0059` state (57 migrations, **44 keys**), per-row checksums
captured, then `0059` applied:

- **exactly 17 rows added** (44 → 61);
- **all 44 pre-existing rows byte-identical** in id, key and label;
- replaying `migrate deploy` — "No pending migrations to apply" — changed nothing;
- re-executing the statement under `STRICT_ALL_TABLES` left the catalogue
  fingerprint identical, ids included.

**The 17 keys:** `branch.manage`, `closing.perform`, `cost.view`,
`discount.apply`, `discount.override`, `expense.manage`, `import.run`,
`integrations.manage`, `purchase.manage`, `report.view`, `sale.create`,
`sale.return`, `settings.manage`, `supplier.manage`, `unit.add`,
`unit.transfer`, `user.manage`.

---

## Applied to staging

Behind `scripts/staging-apply-migrations.ts`: `.env.staging` with
`override: true`, `APP_ENV=staging`, a database name that is unmistakably
staging, a `mysqldump`, and a **restore-proof** of that dump into a disposable
database (83 tables, 61 permission rows) which was then dropped.

Staging already held all 61 keys from the earlier repair, so as predicted the
migration **recorded itself and changed no data**:

| | Before | After |
|---|---|---|
| Catalogue | 61 | **61** |
| Roles / mappings | 6 / 248 | **6 / 248** |
| Role-mapping checksum | `c2cf1e55732161f7` | **`c2cf1e55732161f7`** |
| Repaired companies | 124 mappings each | **124 each** |

No manual catalogue bootstrap was needed afterwards. The gate reports
`61/61 canonical keys present`.

---

## Verification

| Gate | Result |
|---|---|
| Backend suite | **99 suites / 1714 tests, all pass** (was 98 / 1698) |
| Backend `tsc --noEmit` | clean |
| `prisma validate` | valid |
| Migrations | **58 in the tree, highest `0059`** (`0005` has never existed) |
| Staging migration status | 58 applied, **0 pending** |
| Catalogue gate vs staging | `61/61 present`, exit 0 |
| Generator drift check | in step with the canonical source |
| Website `tsc` · tests · build · audit · oxlint | clean · **14/14** · clean · **0 vulnerabilities** · 0 errors, 4 pre-existing warnings |
| Mobile `tsc` · pure suites · i18n parity | clean · 9 files, 0 failures · **en/ar/fr 1752 each** |

**Staging acceptance after the migration: 33/33 original, 44/44 expanded.**

### Demo integrity — unchanged

1 company · 9 users · 7 sales · **10 051.00 MRU** · 7 roles · 159 mappings ·
catalogue 61 · 0 subscription payments · 0 administrative grants ·
role-mapping checksum **`ee023046b819dbfd`** before and after.

---

## ⚠ The one thing deliberately left undone

**The development database was not migrated**, because the task's binding
boundaries forbid touching it. `npx prisma migrate status` against `phonestore`
therefore reports `0059` as pending. That is expected, not a defect:

- it is a **data-only** migration, and dev already holds all 61 keys from the seed;
- applying it there is a one-command no-op whenever someone chooses —
  `npx prisma migrate deploy`.

### Takeover discrepancies

**None.** Every stated expectation matched: HEADs `44ceddd` / `b973f64` /
`ad923df` / `849fca7`, 98 suites / 1698 tests, 57 actual migrations with `0058`
highest and `0005` genuinely absent, no pending migration, 61/43/20, full-canon
SHA-256 `0ddb8c04…`, staging healthy on 8088, four repositories clean and level,
`READY_FOR_HANDOFF` under owner `NONE`.

*(Carried forward from the previous session, still unresolved and still out of
scope: the website suite once reported "no tests" and exited 0 — a false-green
risk for any CI eventually configured. It did not recur in any run this session.)*

---

## State of staging

**Retained and healthy on port 8088.** Single origin preserved; `/admin` is
loopback plus administrator authentication; the API binds loopback only.

- Two fixtures kept: `Staging Test Shop` and `CP4 Shop …`, both with 124
  mappings.
- Acceptance-run tenants removed; administrator sessions revoked; unexpired
  verification codes consumed; **44 audit events preserved**.
- The temporary staging administrator is **deliberately kept** — removing it
  would make the control portal inaccessible.
- All identities synthetic (`@example.invalid`, RFC 2606). No real customer,
  employee or business information exists in staging.
- Temporary ports released: the clean-install backend on 3012 is stopped, and
  both disposable databases are dropped. Only `3011` (loopback), `8088` and
  MySQL `3306` listen.

---

## Next exact action

Nothing is in flight. The permission catalogue is now complete on any database
built by `migrate deploy` alone, and the gate refuses a deployment that is not.

The remaining open decisions are unchanged from the staging checkpoint and are
the Owner's to make: **where staging should be hosted**, and **the private-access
layer for `/admin`** — see [`docs/39`](docs/39_STAGING_ENVIRONMENT.md).

**This is not a production readiness statement.**
