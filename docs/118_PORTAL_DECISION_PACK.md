# 118 — Portal decision checklist (2026-11-04)

The public portal stays closed until its legal pages are approved: no draft page is published and no real customer
payment is taken. That gate does **not** block Build 4/TestFlight work, a backend deployment with `PORTAL_LIVE` off,
Test-business portal testing behind restricted access, or preparing DNS, packaging and verification tooling. The page
texts live in `erp-control-web/src/content/legal-*.ts`; this checklist does not copy them.

## 1. Owner questionnaire

Facts given by the owner, 2026-11-04 (as stated; nothing inferred):

| Fact | Answer |
|---|---|
| Operator's full legal name | Abdel Kerim Taleb Ould Sidi |
| Legal status | individual developer (no trade registration: counsel item 1) |
| Residence | Tevragh Zeina, Nouakchott (the owner asks that no personal address be published; counsel item 10) |
| Correspondence address | as already published on tsxmr.com/contact: Tevragh Zeina, Nouakchott-Ouest, Mauritania (district only; no street address published, at the owner's request) |
| Publication director | Abdel Kerim Taleb Ould Sidi |
| Emails (published at tsxmr.com/contact, read 2026-11-04) | general contact@tsxmr.com · support support@tsxmr.com · privacy privacy@tsxmr.com · security security@tsxmr.com · **no billing address published**: contact@ unless the owner names another |
| Telephone (published) | +222 36 96 38 39 · +222 37 67 68 27 |

Operational proposals — **recommended, not approved until the owner confirms**:

| Decision | Proposal |
|---|---|
| Support hours | Sunday–Thursday, 09:00–17:00, Nouakchott time |
| Support languages | Arabic, French, English |
| Support response target | within two working days |
| Backup schedule (as production runs it) | 7 daily off-site, 4 weekly, 6 monthly (Borg, Storage Box), plus 14 rotating server copies |
| Indemnity | omit it, unless Mauritanian counsel recommends and drafts one |
| Refunds | no automatic or prorated refund after a paid subscription is activated, except duplicate or incorrect payments, or a paid period Dukan cannot provide; cancellation prevents renewal; mandatory legal rights prevail (for owner and counsel) |
| Account-deletion channel | **decided: WhatsApp** |
| Onboarding channel | **decided: WhatsApp only; email disabled** |

## 2. For Mauritanian counsel

1. May the paid service be sold before the operator registers (e.g. individual trader at the RCCM, tax number), and what must invoices and receipts show?
2. Which data-protection law applies, its legal bases, the rights it grants, and the authority to name.
3. The basis for processing outside Mauritania (servers in Germany; Meta).
4. The statutory retention period for business and accounting records (it bounds what deletion may remove).
5. Governing law, jurisdiction and dispute resolution for the terms.
6. Limitation of liability and service-level wording.
7. Indemnity: only if counsel advises one; otherwise none.
8. Approval of the sealed-history disclosure (audit and subscription history cannot be edited by a deletion).
9. Review and approval of the six DRAFT pages: privacy, legal notice, account deletion, terms, security, privacy choices.
10. Whether the legal notice must publish the operator's address, or whether an email and WhatsApp contact satisfy it for an individual operator.

## 3. Known infrastructure and processors (production, read 2026-11-04)

| Provider | Role | Personal data | Location |
|---|---|---|---|
| Hetzner Cloud | application server `tsxmr-app-01` (API, database, edge) | all account data | Nuremberg, Germany (`nbg1-dc3`) |
| Hetzner Storage Box BX11 | encrypted off-site backups (Borg) | all account data, encrypted | Falkenstein, Germany |
| Meta WhatsApp Business Platform | verification codes and account messages | phone numbers, message content | Meta |
| Cloudflare | DNS for `tsxmr.com`; **DNS only** for `api`, `admin`, `dukan-test` (they resolve to the server); proxies the company site `tsxmr.com` only | none from the app | — |
| healthchecks.io | backup job heartbeat | none | — |
| Email | **disabled** | — | — |
| Sentry | **not installed** | — | — |

## 4. Inconsistencies and privacy issues to fix

| Issue | Status |
|---|---|
| Privacy page said the admin "asks again for the password before every decision" | fixed in the draft (EN/FR/AR), console `a9cf1a9a`: five-minute step-up |
| Request logs kept IMEIs and serials in URLs: `units/:identifier`, `selection/:identifier`, `recognition/:imei`, and `code`/`imei`/`serial` queries | fixed in backend `37856b3` (redacted, tested); the draft says so; **production unchanged until deployed** |
| Log retention: no log is kept by Caddy; API container logs rotate by size (5 × 10 MB per container), not by time. The old, unredacted lines leave either as 50 MB of newer lines push them out, or when the release recreates the API container (its log files go with the old container). No manual deletion without a reviewed procedure | the privacy draft ("kept until a retention period is set") must state the real rotation |
| Backup retention in the deletion and privacy drafts is a blocker | the real schedule is above (§1): once you approve it, the drafts can state it |
| Processors were "not selected" in the privacy draft | they are in production (§3): the drafts must name them |
| Deletion wording across self-deletion, last-Owner closure, admin prepare/delete (`deleted-business-v1`) | one consistency table to be added to the deletion draft before legal review; backups keep a copy until they expire in every case |

## 5. Then (unchanged order)

1. Your answers and counsel's. 2. Final CI, render and visual gates. 3. Backup, then the backend release and its migrations.
4. Production portal. 5. Cloudflare `A dukan.tsxmr.com`. 6. HTTPS, legal pages, `/admin` 404, subscription pages and a
Test-business claim. 7. `PORTAL_LIVE=enabled`. 8. Submit `dukan_account_ready` (EN/FR/AR). 9. Meta's approval.
10. A test with the Test business and an authorised number. 11. The account-ready sender enabled.
