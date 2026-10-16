# 92 — App Review notes (draft)

> **DRAFT — REQUIRES TSX-MR APPROVAL.** 2026-10-16, CLAUDE-B. To paste into App Store Connect → App Review Information →
> Notes once the bracketed facts exist. Not submitted. It states what the app does; it does not claim guideline
> compliance.

---

Dukan ERP is a business tool for electronics shops in Mauritania, operated by `<TSX-MR legal name>`. It is used by a
shop's Owner, managers and staff to record stock (by IMEI, serial number or barcode), sales, returns, expenses, the
day's cash closing and, for money-services counters, exchanges. The shop's customers never use it.

**Signing in.** Use the demo business on our staging service:
- Owner: `<identifier>` / `<password>`
- Employee: `<identifier>` / `<password>`

The data is fictitious. An Owner sees every screen; an Employee sees only what the Owner allows.

**No purchase in the app.** The app sells nothing and shows no price. A business's access is arranged between the
business and TSX-MR outside the app. The app shows only whether the business's access is active, read-only or not
started. A business may have a free trial; its Owner starts it on our website, and the app only shows its status, with
no button. The app contains no link, button or instruction to buy.

**Permissions.**
- Camera: reads IMEI labels and barcodes so staff do not type them. Nothing is recorded.
- Photos: opened only when the person attaches a receipt picture to an expense.
- There is no location, microphone, contacts, tracking or push permission.

**Account deletion.** More → Your account → Delete account. The person confirms with their password, then with a
one-time code sent to the account's verified WhatsApp number. Deleting the last Owner's account closes the business.
The steps, and what is kept for accounting, are shown before confirming and on `https://<domain>/account-deletion`.
`<Before submission: the WhatsApp channel must be live, so the reviewer can complete it. Without a live channel the app
says that codes cannot be sent right now, and nothing is changed.>`

**Privacy policy, terms and support.** On the sign-in screen and under More → Your account, they open in Safari:
`https://<domain>/privacy`, `/terms`, `/support`, `/account-deletion`.

**Contact.** `<name>`, `<email>`, `<phone>`.

---

Risks to settle before this is sent (docs/93): the deletion channel (O-A7); the in-app Terms page describes how access is
priced and paid outside the app (L-1); the demo business on staging (O-A6).
