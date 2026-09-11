# 47 — Catalogue images: the gap, and the smallest feature that closes it

Status: **not implemented, not approved.** Written 2026-09-11 during the Stock
screen correction pass, because the "A · Indigo" direction shows product
photographs and the app cannot supply them honestly today.

## What exists (audited)

| Place | Image capability |
|---|---|
| `products` (the variant — brand, model, variant) | **None.** No image column, no relation. |
| `product_categories` | None. |
| `units.image_ref` (`VarChar(512)`) | A reference to a photo of **one physical handset** — condition evidence. Not a catalogue picture. |
| Backend | No upload endpoint for product media, no storage adapter for it, no image in any product, summary or inventory response. |
| Mobile | No `<Image>` on any stock, product or unit list. |

So **image-based Visual Stock is not complete**, and the Stock screen shows a
neutral category tile (phone, accessory, other device) on every row.

## What must never stand in

- **A unit's photo as the variant's picture.** It shows one specific device —
  its scratches, its case, possibly its IMEI sticker. Shown on the variant row,
  it presents a private record as the picture of every phone of that model, and
  leaks it to every role that can open Stock.
- **A stock photo of a similar model or another colour.** A "256 GB Black" row
  showing a blue phone is a wrong fact on the screen staff use to answer
  customers.

## The smallest feature that would close it

One image per **product** (variant), chosen deliberately by someone allowed to
edit the catalogue.

1. **Schema** — one nullable column, `products.image_key VARCHAR(255)`, plus a
   migration. No gallery, no per-branch image. (Needs the backup protocol in
   `22_BACKUP_AND_ROLLBACK.md`.)
2. **Storage** — a single adapter: local disk in development, one object bucket
   in staging/production. Resize on upload to one thumbnail size (~256 px) and
   strip EXIF. **New infrastructure decision** — bucket, retention and cost are
   external decisions (see `45_EXTERNAL_DECISIONS.md`).
3. **API** — `PUT /products/:id/image` (multipart, `product.manage`, size and
   type limits), `DELETE /products/:id/image`; `imageUrl` (short-lived signed or
   public-read thumbnail) added to the product detail and to
   `GET /inventory/summary` rows.
4. **Mobile** — on product detail, "Add photo" using the existing camera
   permission path; on Stock rows, the thumbnail when `imageUrl` is present and
   the current neutral tile otherwise.
5. **Tests** — upload refused without permission; wrong type/oversize refused;
   summary carries the product's image and never a unit's `image_ref`; the row
   falls back to the tile when absent.

Out of scope for that feature: automatic image lookup by model name, images
per colour when products are not split by colour, OCR, and any use of
`units.image_ref` outside the unit's own detail screen.
