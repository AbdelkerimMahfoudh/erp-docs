# 30 — IMEI OCR and TAC recognition: audit and decisions

**Audited:** 2026-08-15 · **Account:** CLAUDE-B · **Milestone C**

The brief is explicit: *audit and reuse the existing recognition-learning
architecture; do not create a competing evidence system.* This is that audit,
done before any recognition code was written.

---

## 1. What already exists

**A TAC recognition path is already built and is already almost exactly right.**

`CatalogService.recognize(imei)` — `GET /v1/products/recognition/:imei`:

1. validates the IMEI (15 digits **and** Luhn),
2. takes the TAC (first eight digits),
3. looks it up in the global `tac_catalog`,
4. matches the brand/model against **this company's** catalog,
5. returns a suggestion the client confirms. It never blocks.

Measured against the brief's TAC rules, it already satisfies most of them:

| Rule | Status |
|---|---|
| TAC suggests manufacturer/model only | ✅ returns `brand`, `model`, `defaultVariant` and nothing else |
| Never infers storage, colour, condition, cost or price | ✅ those fields are not in the response |
| One model may have several TACs | ✅ `tac` is the primary key; many rows may share a brand/model |
| Unknown TAC asks a human to choose or create | ✅ `known: false`, `suggestion: null`, `matches: []` |
| No third-party IMEI lookup API | ✅ one local table, no outbound call anywhere |
| Exact evidence not weakened by a weaker score | ✅ there is no score — a TAC either matches or does not |

`productId` is returned **only when exactly one** catalog product matches. With
two or more it is `null` and a human picks. That is the right instinct and it is
already there.

**Conclusion: reuse it. Nothing about recognition needs rebuilding.**

---

## 2. What is missing

### 2.1 There is no teaching path

The brief allows an Owner or Manager confirming a product to *teach* the
mapping. Nothing writes to `tac_catalog` today — it is read-only reference data.

### 2.2 `tac_catalog` is EMPTY, and that is the practical blocker

```
SELECT COUNT(*) FROM tac_catalog;  →  0
```

So recognition currently answers `known: false` for every IMEI ever scanned. The
code path is correct and completely inert. **OCR will read an IMEI perfectly and
still suggest nothing**, until either the catalogue is populated or the teaching
path exists.

This is worth saying plainly because it changes what "Milestone C works" means:
the reading half can be finished and verified, and the suggesting half cannot
demonstrate anything until there is data.

### 2.3 Teaching a GLOBAL table is a tenancy problem — flagged, not solved

`tac_catalog` is one of only two global models (`GLOBAL_MODELS` in
`prisma/tenant.extension.ts`, alongside `Permission`). It is deliberately shared
by every company, and the tenant extension does not scope it.

**So "an Owner confirmation teaches the mapping" cannot write to it directly.**
One shop naming a TAC "iPhone 15 Pro Max" would rename it for every other
company on the installation, including their existing suggestions. That is
cross-tenant contamination through a feature that looks purely helpful.

Two workable shapes, neither implemented:

- **A per-company overlay** — a tenant-scoped `company_tac_mapping` that is
  consulted before the global table. A shop teaches its own naming; nobody
  else's changes. This is the safe default and matches how every other tenant
  model in this system behaves.
- **A proposal queue** — confirmations accumulate as evidence and only a
  privileged operator promotes one into the global catalogue. Heavier, and
  requires an operator role this product does not have.

**Recommendation: the overlay.** It is additive, needs no new role, and cannot
affect another company by construction — which is the property that matters.

### 2.4 Employee-versus-Manager evidence

The brief requires that an Employee may propose but never globally approve. With
the overlay above, "approve" means writing the company mapping, which
`catalog.manage` already expresses — a permission the Store Employee does not
hold. No new permission key is needed.

---

## 3. Dual-SIM persistence needs no migration

`units.imei_secondary VARCHAR(15)` **already exists** in the schema, and
`InventoryUnitRow` already carries `imeiSecondary` through to the client. The
return workflow already matches a presented identifier against
`imeiPrimary`, `imeiSecondary` *or* `serialNo`.

So "one physical Unit, two identifiers" is already representable end to end.
**Do not write a migration for it** — verify first, as the handoff says.

One gap to confirm before relying on it: migration `0008` created a generated
`identifier` column, `COALESCE(imei_primary, serial_no)`, with a UNIQUE index.
That protects the primary identifier globally. **Whether `imei_secondary` is
protected against duplicates has not been verified**, and the brief requires
both to be. That check belongs in C-CP4.

---

## 4. What the OCR layer adds, and where its safety lives

`mobile/lib/imei.ts` (C-CP1) is pure and fully tested — 21 checks, no camera, no
device, no build required.

The rule the whole feature rests on: **never silently accept a guessed digit.**
OCR confusions are systematic rather than random — 0/O, 1/I, 5/S, 8/B — so a
misread produces a plausible number, not obvious junk. A failed read costs
seconds. A wrong IMEI is a phone that cannot be found, sold, returned or
warranty-matched for the rest of its life.

Two mechanisms enforce it:

- **Luhn**, which catches roughly nine in ten single-digit misreads before
  anyone sees them; and
- a substitution is offered **only** when the corrected reading still satisfies
  Luhn, carries `source: 'ambiguity_resolved'`, and lists every character it
  changed. A human agrees to the reading rather than being told about it.

---

## 5. The dependency, and the limit of what was verified

`@infinitered/react-native-mlkit-text-recognition` **5.0.1** — MIT, an Expo
module, on-device Google ML Kit. No cloud service, no image or IMEI leaves the
device.

Verified here: **Expo Doctor 18/18**, web export 40 routes, `tsc` and lint clean
with it installed.

**Not verified, and not claimable:** the native module has never been executed.
It cannot run in Expo Go, and no development build can be produced in this
environment. Expo Doctor passing is a compatibility check, not a working camera.
A custom development build on a physical device is the only thing that can
settle it.

---

## 6. Remaining work

| Step | Scope |
|---|---|
| **C-CP3** | Three scanner modes — barcode, read-from-screen, manual. **Manual must always work**, including when OCR is unavailable, the camera is denied, or the build has no native module. |
| **C-CP3** | Receiving prefill: IMEI1, optional IMEI2, suggested product. The human still confirms variant, storage, colour, supplier, cost and price — every existing approval rule is preserved. |
| **C-CP4** | The per-company TAC overlay (§2.3), or an explicit decision to defer it. |
| **C-CP4** | Verify `imei_secondary` duplicate protection (§3). |
| **C-CP4** | `docs/24` device script: glare, moiré, cracked screens, low light, Arabic device labels, dual-SIM screens, camera focus, and that no image is persisted or transmitted. |

**Nothing in C-CP3 or C-CP4 requires a schema change**, on current evidence —
except the overlay in §2.3, which is additive if it is built.
