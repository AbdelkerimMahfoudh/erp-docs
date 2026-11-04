# 118 — Portal legal and operational decision pack (for the owner's approval, 2026-11-04)

Status: **portal launch on hold** (owner, 2026-11-04). Nothing is published, deployed or changed in DNS; `PORTAL_LIVE`
is off; no Meta action. The console's `PORTAL` gate stays as it is: it opens only when every item below is decided.
Sections A, B, C and E are **generated from the published content, unchanged**. Section D's proposals are
**proposals, not approved facts**. Nothing in this pack decides a legal point.

## 0. Decided
- Account-deletion channel: **WhatsApp** (configured and proven in production, 2026-11-01). `VITE_ACCOUNT_DELETION_CHANNEL=whatsapp`.
- Onboarding channel for this launch: **WhatsApp only**; email stays disabled and is not presented as a channel.

## A0. The twelfth blocker: operator registration (src/config/schema.ts)
- **operator_registration** — TSX-MR is operated by an individual with no trade registration. Mauritanian counsel must
  confirm whether the paid Dukan ERP service may be sold before the operator registers (for example as an individual
  trader at the RCCM, with a tax identification number), and what invoices and receipts must then show. The portal
  stays closed until then.

## A. The 12 unresolved legal blockers (exact text from src/content/blockers.ts)

- **backup_retention** — How long backups are kept is not supplied by TSX-MR: deletion removes data from active storage at once, and backups expire on that schedule. Production stays blocked until TSX-MR fixes it.
- **governing_law** — Governing law, jurisdiction and dispute resolution for the terms of service are not decided.
- **indemnity** — Whether a business indemnifies TSX-MR, and for what, is a legal clause TSX-MR and its adviser must write or remove.
- **international_transfer** — Whether personal data is processed outside Mauritania depends on the hosting choice; the policy must say where.
- **legal_review** — The privacy policy, terms and deletion page are drafts written from the code; a legal adviser must review and approve them.
- **liability** — Limitation of liability and service-level wording for the terms of service are not decided.
- **privacy_law** — Which data-protection law applies, the legal bases it requires, the rights it grants and the authority a person may complain to are not confirmed by Mauritanian counsel.
- **processors** — Hosting, database, backup and email providers are not selected (docs/45 D4–D7); the policy must name them once contracted.
- **refund_policy** — The refund policy for business access paid outside the app is not decided by TSX-MR (today nothing is refunded by the system).
- **retention_period** — The legal retention period for business and accounting records (Mauritanian commercial and tax law) is not decided (docs/64 §6).
- **sealed_history** — Deletion cannot edit the hash-chained audit trail, subscription and platform audit events, or append-only money-agent records, which may hold names or contacts written before 2026-10-12 (docs/24); a legal adviser must approve this disclosure.

## B. Texts still marked DRAFT

- accountDeletion
- legalNotice
- privacy
- privacyChoices
- security
- terms

## C. Placeholder statements awaiting a decision

- none reported by the gate


## D. The five missing operational commitments — proposals only
| Input | What it is | Proposal (not decided) |
|---|---|---|
| `VITE_SUPPORT_HOURS` | When support answers | PROPOSAL: "Sunday to Thursday, 9:00–17:00, Nouakchott time (GMT)" |
| `VITE_SUPPORT_LANGUAGES` | Languages support answers in | PROPOSAL: "Arabic, French and English" |
| `VITE_SUPPORT_RESPONSE_TIME` | How soon support replies | PROPOSAL: "Within one working day" |
| `VITE_LEGAL_EFFECTIVE_DATE` | Effective date of the approved texts | the day TSX-MR approves the final texts (no proposal: it follows the approval) |
| `VITE_ACCOUNT_DELETION_CHANNEL` | Deletion verification channel | **decided: whatsapp** |

The twelve legal items (A0, A) are not given proposals: operator registration, governing law, jurisdiction, liability,
indemnity, applicable data-protection law, processors, international transfers, retention periods and refund rights
are TSX-MR's and counsel's to decide.

## F. What happens after approval (owner's order, 2026-11-04)
1. The approved decisions written into the texts and inputs; the `PORTAL` gate then opens with no rule weakened.
2. Final CI, render and visual gates. 3. Backup, deploy backend `4699efa` (0128-0129). 4. Production portal.
5. Cloudflare `A dukan.tsxmr.com`. 6. HTTPS, legal pages, `/admin` 404, subscription pages, a Test-business claim.
7. `PORTAL_LIVE=enabled`. 8. Submit `dukan_account_ready` (EN/FR/AR, owner's wording below). 9. Meta approval.
10. Test with the Test business and an authorised number. 11. Enable the account-ready sender.

Owner's template wording: EN "Your Dukan ERP account for {{1}} is ready. Open the secure page to complete your setup and
view your subscription." · FR "Votre compte Dukan ERP pour {{1}} est prêt. Ouvrez la page sécurisée pour terminer la
configuration et consulter votre abonnement." · AR "حساب Dukan ERP الخاص بـ {{1}} جاهز. افتح الصفحة الآمنة لإكمال الإعداد
والاطلاع على اشتراكك." · URL button `https://dukan.tsxmr.com/claim/{{1}}`.

Waiting behaviour, already so in the code (`notice.service.ts`): an eligible message stays **pending** while the portal
or the template is missing (`held_portal`, `held_template`), is never marked sent or failed for it, spends no attempt,
creates **no claim link** while it waits; the 72-hour link is issued only at the moment of delivery; after approval the
hourly pass sends each one once (one notice per eligibility, unique key).

## E. Exact current wording (generated from the published content, unchanged)


### privacy — en

> 1.0 (draft)
>
> draft
>
> Dukan ERP privacy policy
>
> How {displayName} collects, uses, shares and keeps personal information in Dukan ERP and on this website.
>
> who
>
> Who is responsible
>
> p
>
> Dukan ERP is developed and operated under the {displayName} name. {operatorStatus} The operator is responsible for the personal information Dukan ERP processes. Correspondence address: {postalAddress}.
>
> p
>
> A business that uses Dukan ERP decides what it records about its own customers, suppliers and staff; {displayName} processes that information to provide the service. [[blocker:legal_review]]
>
> p
>
> Questions about this policy or about your personal information: {privacyEmail}.
>
> scope
>
> What this policy covers
>
> p
>
> This policy covers the Dukan ERP mobile app, the business account and administration areas of this website, and its public pages. Dukan ERP is used by businesses and their staff: the customers of a business never sign in to it.
>
> collected
>
> Information we collect
>
> h3
>
> Accounts
>
> list
>
> Name, the identifier used to sign in, and an identifier generated by the service.
>
> Email address and telephone (WhatsApp) number, and whether and when each was verified.
>
> The password and the optional PIN, stored only as one-way hashes.
>
> h3
>
> Applications for a business account
>
> list
>
> The owner’s name, the business and first store names, the activity, the city, the contact details and the preferred language.
>
> h3
>
> Businesses, stores and staff
>
> list
>
> Business name and city; store names, addresses and telephone numbers; settings, subscription and seat information.
>
> Staff roles, store assignments and permissions, and the debts or shortages a business records for an employee.
>
> h3
>
> Business records
>
> list
>
> Products, models, specifications, barcodes, IMEI and serial numbers, costs, prices and stock movements; suppliers’ names, telephone numbers and notes.
>
> Sales, payments and balances, including — when a business enters it — the number a customer paid from; the customers and other counterparties a business records, with their names, telephone numbers and notes.
>
> Money-services exchanges: direction, amount, commission, provider, the customer’s telephone number, the provider’s reference when there is one, and the name of the employee who recorded it.
>
> Expenses with an optional receipt photo, returns, refunds, daily closings and cash counts.
>
> h3
>
> Imported files
>
> list
>
> When a business imports a spreadsheet — of stock, for example — each row of the file is kept with the import, so that what was imported can be checked later.
>
> h3
>
> Security and audit
>
> list
>
> For each signed-in session: the IP address, the browser or app identifier (user agent) and sign-in times.
>
> For each device added to an account: a label, the platform, the model and the app version. No IMEI or hardware fingerprint of your own phone is collected.
>
> For each verification message: the destination number or address, a one-way hash of the code, the attempts and the delivery status.
>
> An audit trail of changes: who changed what, when, and the values before and after the change.
>
> The service’s request logs: the IP address, the app or browser identifier and the address of each request, which can include an IMEI or serial number being looked up.
>
> not_collected
>
> What we do not collect
>
> list
>
> No location: the app does not ask for it or record it. A receipt photo is kept as the file you choose, so if your phone saved in the file where the photo was taken, that stays in it.
>
> No access to the contacts on your phone.
>
> The camera is used only to scan barcodes and IMEI numbers; no image is kept. A photo is stored only when you attach a receipt to an expense.
>
> No advertising, analytics or crash-reporting services, and no advertising or tracking cookies.
>
> use
>
> How we use information
>
> list
>
> To provide the service: signing in, keeping the business’s records, and producing its reports.
>
> To verify contact details and confirm sensitive actions, such as deleting an account.
>
> To review applications and manage subscriptions.
>
> To keep the service secure: permissions, rate limits, the audit trail and the investigation of misuse.
>
> To send service messages, such as verification codes and notices to a business’s owners about its daily closing.
>
> p
>
> We do not sell personal information and do not use it for advertising.
>
> sharing
>
> Who can see information
>
> p
>
> Inside a business, each person sees what their role and the owner’s permission choices allow.
>
> p
>
> The {displayName} platform team sees businesses, their stores, the names and contact details of their accounts, their subscriptions and the payments recorded for those subscriptions.
>
> p
>
> When WhatsApp delivery is turned on, verification codes and service messages are sent through Meta’s WhatsApp Business Platform, which receives the destination number and the message.
>
> p
>
> When email delivery is turned on, verification codes and service messages are sent through an email delivery provider, which receives the destination address and the message. [[blocker:processors]]
>
> p
>
> Hosting and other service providers: [[blocker:processors]]
>
> location
>
> Where information is stored
>
> p
>
> Information is stored in a database operated for {displayName}. [[blocker:international_transfer]]
>
> security
>
> How information is protected
>
> list
>
> Connections between the app, this website and the service use HTTPS.
>
> Passwords, PINs and session secrets are stored only as one-way hashes.
>
> Permissions are checked by the server on every request.
>
> The audit trail cannot be edited or deleted by the application.
>
> The administration area has its own sign-in and asks again for the administrator’s password before every decision.
>
> Customer numbers of money-services exchanges are masked in lists.
>
> retention
>
> How long information is kept
>
> p
>
> Business and accounting records — sales, purchases, payments, returns, daily closings, the audit trail and subscription records — are kept for [[blocker:retention_period]].
>
> p
>
> Verification codes expire after a few minutes. Signed-in sessions expire, and can be ended at any time.
>
> p
>
> Nothing is yet removed automatically after a set time: expired codes, ended sessions, request logs and imported files are kept until a retention schedule is decided. [[blocker:retention_period]]
>
> deletion
>
> Deleting an account
>
> p
>
> You can delete your account in the app; the deletion is confirmed with a code sent to your verified {deletionChannelName} number. The account deletion page explains how, and what is removed and kept.
>
> p
>
> Deletion removes the person’s identity and contact details from the records in use, and every copy the app made of them that can be edited. The sealed audit trail and subscription history, and backups until they expire, are not edited, nor are notifications already shown to other people of the business. [[blocker:sealed_history]] [[blocker:backup_retention]]
>
> rights
>
> Your choices and requests
>
> p
>
> You can see your account details in the app, end your sessions and delete your account. For a copy of your personal information, a correction or any other request, write to {privacyEmail}; requests are answered by the {displayName} team. [[blocker:legal_review]]
>
> children
>
> Children
>
> p
>
> Dukan ERP is made for businesses and their staff. It is not directed to children.
>
> website
>
> This website
>
> p
>
> The public pages set no cookies. Signing in to a business account or to the administration area sets a session cookie that the sign-in needs; it lasts at most twelve hours. Your choice of language and appearance is remembered in your browser. No analytics or advertising trackers are used.
>
> changes
>
> Changes to this policy
>
> p
>
> The version and the effective date of this policy are shown at the top of the page. A new version is published here with its own date.
>

### privacy — fr

> 1.0 (projet)
>
> draft
>
> Politique de confidentialité de Dukan ERP
>
> Comment {displayName} collecte, utilise, partage et conserve les informations personnelles dans Dukan ERP et sur ce site.
>
> who
>
> Qui est responsable
>
> p
>
> Dukan ERP est développé et exploité sous le nom {displayName}. {operatorStatus} L’exploitant est responsable des informations personnelles traitées par Dukan ERP. Adresse de correspondance : {postalAddress}.
>
> p
>
> Une entreprise qui utilise Dukan ERP décide de ce qu’elle enregistre sur ses propres clients, fournisseurs et employés ; {displayName} traite ces informations pour fournir le service. [[blocker:legal_review]]
>
> p
>
> Questions sur cette politique ou sur vos informations personnelles : {privacyEmail}.
>
> scope
>
> Ce que couvre cette politique
>
> p
>
> Cette politique couvre l’application mobile Dukan ERP, l’espace du compte entreprise et l’espace d’administration de ce site, ainsi que ses pages publiques. Dukan ERP est utilisé par des entreprises et leur personnel : les clients d’une entreprise ne s’y connectent jamais.
>
> collected
>
> Les informations que nous collectons
>
> h3
>
> Comptes
>
> list
>
> Le nom, l’identifiant de connexion et un identifiant généré par le service.
>
> L’adresse e-mail et le numéro de téléphone (WhatsApp), et si et quand chacun a été vérifié.
>
> Le mot de passe et le code PIN facultatif, conservés uniquement sous forme d’empreintes à sens unique.
>
> h3
>
> Demandes de compte entreprise
>
> list
>
> Le nom du propriétaire, les noms de l’entreprise et de son premier magasin, l’activité, la ville, les coordonnées et la langue préférée.
>
> h3
>
> Entreprises, magasins et personnel
>
> list
>
> Le nom et la ville de l’entreprise ; les noms, adresses et numéros de téléphone des magasins ; les réglages, l’abonnement et les postes.
>
> Les rôles, les affectations aux magasins et les autorisations du personnel, ainsi que les dettes ou manquants qu’une entreprise enregistre pour un employé.
>
> h3
>
> Données de l’entreprise
>
> list
>
> Les produits, modèles, caractéristiques, codes-barres, numéros IMEI et de série, coûts, prix et mouvements de stock ; les noms, numéros de téléphone et notes des fournisseurs.
>
> Les ventes, paiements et soldes, y compris — lorsque l’entreprise le saisit — le numéro depuis lequel un client a payé ; les clients et autres contreparties qu’une entreprise enregistre, avec leurs noms, numéros de téléphone et notes.
>
> Les échanges de services monétaires : sens, montant, commission, opérateur, numéro de téléphone du client, référence de l’opérateur lorsqu’il y en a une, et nom de l’employé qui l’a enregistré.
>
> Les dépenses avec une photo de reçu facultative, les retours, les remboursements, les clôtures quotidiennes et les comptages de caisse.
>
> h3
>
> Fichiers importés
>
> list
>
> Lorsqu’une entreprise importe un tableur — de stock, par exemple —, chaque ligne du fichier est conservée avec l’importation, afin que ce qui a été importé puisse être vérifié plus tard.
>
> h3
>
> Sécurité et audit
>
> list
>
> Pour chaque session ouverte : l’adresse IP, l’identifiant du navigateur ou de l’application (user agent) et les heures de connexion.
>
> Pour chaque appareil ajouté à un compte : un libellé, la plateforme, le modèle et la version de l’application. Aucun IMEI ni empreinte matérielle de votre propre téléphone n’est collecté.
>
> Pour chaque message de vérification : le numéro ou l’adresse de destination, une empreinte à sens unique du code, les tentatives et l’état de l’envoi.
>
> Un journal d’audit des modifications : qui a modifié quoi, quand, et les valeurs avant et après la modification.
>
> Les journaux de requêtes du service : l’adresse IP, l’identifiant de l’application ou du navigateur et l’adresse de chaque requête, qui peut contenir un IMEI ou un numéro de série recherché.
>
> not_collected
>
> Ce que nous ne collectons pas
>
> list
>
> Aucune localisation : l’application ne la demande pas et ne l’enregistre pas. Une photo de reçu est conservée telle que le fichier choisi ; si votre téléphone a enregistré dans le fichier l’endroit où la photo a été prise, cette information y reste.
>
> Aucun accès aux contacts de votre téléphone.
>
> L’appareil photo sert uniquement à scanner des codes-barres et des numéros IMEI ; aucune image n’est conservée. Une photo n’est enregistrée que lorsque vous joignez un reçu à une dépense.
>
> Aucun service de publicité, de mesure d’audience ou de rapport de plantage, et aucun cookie publicitaire ou de traçage.
>
> use
>
> Comment nous utilisons les informations
>
> list
>
> Pour fournir le service : la connexion, la tenue des données de l’entreprise et la production de ses rapports.
>
> Pour vérifier les coordonnées et confirmer les actions sensibles, comme la suppression d’un compte.
>
> Pour examiner les demandes et gérer les abonnements.
>
> Pour assurer la sécurité du service : autorisations, limites de fréquence, journal d’audit et examen des abus.
>
> Pour envoyer des messages de service, comme les codes de vérification et des avis aux propriétaires d’une entreprise sur la clôture de sa journée.
>
> p
>
> Nous ne vendons pas les informations personnelles et ne les utilisons pas à des fins publicitaires.
>
> sharing
>
> Qui peut voir les informations
>
> p
>
> Au sein d’une entreprise, chacun voit ce que permettent son rôle et les autorisations choisies par le propriétaire.
>
> p
>
> L’équipe de la plateforme {displayName} voit les entreprises, leurs magasins, les noms et coordonnées de leurs comptes, leurs abonnements et les paiements enregistrés pour ces abonnements.
>
> p
>
> Lorsque l’envoi par WhatsApp est activé, les codes de vérification et les messages de service passent par la plateforme WhatsApp Business de Meta, qui reçoit le numéro de destination et le message.
>
> p
>
> Lorsque l’envoi par e-mail est activé, les codes de vérification et les messages de service passent par un prestataire d’envoi d’e-mails, qui reçoit l’adresse de destination et le message. [[blocker:processors]]
>
> p
>
> Hébergement et autres prestataires : [[blocker:processors]]
>
> location
>
> Où les informations sont conservées
>
> p
>
> Les informations sont conservées dans une base de données exploitée pour le compte de {displayName}. [[blocker:international_transfer]]
>
> security
>
> Comment les informations sont protégées
>
> list
>
> Les connexions entre l’application, ce site et le service utilisent HTTPS.
>
> Les mots de passe, codes PIN et secrets de session ne sont conservés que sous forme d’empreintes à sens unique.
>
> Les autorisations sont vérifiées par le serveur à chaque requête.
>
> Le journal d’audit ne peut être ni modifié ni supprimé par l’application.
>
> L’espace d’administration a sa propre connexion et redemande le mot de passe de l’administrateur avant chaque décision.
>
> Les numéros des clients des échanges de services monétaires sont masqués dans les listes.
>
> retention
>
> Durée de conservation
>
> p
>
> Les données de l’entreprise et les données comptables — ventes, achats, paiements, retours, clôtures quotidiennes, journal d’audit et données d’abonnement — sont conservées pendant [[blocker:retention_period]].
>
> p
>
> Les codes de vérification expirent au bout de quelques minutes. Les sessions ouvertes expirent et peuvent être fermées à tout moment.
>
> p
>
> Rien n’est encore supprimé automatiquement après un délai fixé : les codes expirés, les sessions fermées, les journaux de requêtes et les fichiers importés sont conservés jusqu’à ce qu’une durée de conservation soit décidée. [[blocker:retention_period]]
>
> deletion
>
> Supprimer un compte
>
> p
>
> Vous pouvez supprimer votre compte dans l’application ; la suppression est confirmée par un code envoyé à votre numéro {deletionChannelName} vérifié. La page sur la suppression de compte explique comment, et ce qui est supprimé ou conservé.
>
> p
>
> La suppression retire l’identité et les coordonnées de la personne des données en service, et de toutes les copies modifiables que l’application en a faites. Le journal d’audit et l’historique de l’abonnement scellés, ainsi que les sauvegardes jusqu’à leur expiration, ne sont pas modifiés, pas plus que les notifications déjà affichées à d’autres personnes de l’entreprise. [[blocker:sealed_history]] [[blocker:backup_retention]]
>
> rights
>
> Vos choix et vos demandes
>
> p
>
> Vous pouvez consulter les informations de votre compte dans l’application, fermer vos sessions et supprimer votre compte. Pour obtenir une copie de vos informations personnelles, une correction ou toute autre demande, écrivez à {privacyEmail} ; l’équipe de {displayName} répond aux demandes. [[blocker:legal_review]]
>
> children
>
> Enfants
>
> p
>
> Dukan ERP est conçu pour les entreprises et leur personnel. Il ne s’adresse pas aux enfants.
>
> website
>
> Ce site
>
> p
>
> Les pages publiques ne déposent aucun cookie. La connexion à un compte entreprise ou à l’espace d’administration dépose un cookie de session nécessaire à cette connexion ; il dure au plus douze heures. Votre choix de langue et d’apparence est mémorisé dans votre navigateur. Aucun outil de mesure d’audience ou de publicité n’est utilisé.
>
> changes
>
> Modifications de cette politique
>
> p
>
> La version et la date d’effet de cette politique figurent en haut de la page. Une nouvelle version est publiée ici avec sa propre date.
>

### privacy — ar

> 1.0 (مسودة)
>
> draft
>
> سياسة الخصوصية في Dukan ERP
>
> كيف تجمع {displayName} المعلومات الشخصية وتستخدمها وتشاركها وتحتفظ بها في Dukan ERP وعلى هذا الموقع.
>
> who
>
> الجهة المسؤولة
>
> p
>
> يُطوَّر Dukan ERP ويُشغَّل تحت اسم {displayName}. {operatorStatus} وتقع المسؤولية عن المعلومات الشخصية التي يعالجها Dukan ERP على المشغّل. عنوان المراسلة: {postalAddress}.
>
> p
>
> تقرّر الشركة التي تستخدم Dukan ERP ما تسجّله عن عملائها ومورّديها وموظفيها، وتعالج {displayName} هذه المعلومات لتقديم الخدمة. [[blocker:legal_review]]
>
> p
>
> للأسئلة عن هذه السياسة أو عن معلوماتك الشخصية: {privacyEmail}.
>
> scope
>
> نطاق هذه السياسة
>
> p
>
> تشمل هذه السياسة تطبيق Dukan ERP على الهاتف، ومساحتَي حساب الشركة والإدارة في هذا الموقع، وصفحاته العامة. ويستخدم Dukan ERP الشركاتُ وموظفوها، أما عملاء الشركة فلا يسجّلون الدخول إليه أبدًا.
>
> collected
>
> المعلومات التي نجمعها
>
> h3
>
> الحسابات
>
> list
>
> الاسم، والمعرّف المستخدم لتسجيل الدخول، ومعرّف تولّده الخدمة.
>
> البريد الإلكتروني ورقم الهاتف (واتساب)، وما إذا كان كل منهما قد تحقَّق ومتى.
>
> كلمة المرور والرمز السري الاختياري، ولا يُحفظان إلا في صورة بصمات أحادية الاتجاه.
>
> h3
>
> طلبات حساب الشركة
>
> list
>
> اسم المالك، واسما الشركة ومتجرها الأول، والنشاط، والمدينة، وبيانات الاتصال، واللغة المفضّلة.
>
> h3
>
> الشركات والمتاجر والموظفون
>
> list
>
> اسم الشركة ومدينتها؛ وأسماء المتاجر وعناوينها وأرقام هواتفها؛ والإعدادات والاشتراك والمقاعد.
>
> أدوار الموظفين وتعيينهم في المتاجر وصلاحياتهم، والديون أو العجز الذي تسجّله الشركة على أحد الموظفين.
>
> h3
>
> سجلات الشركة
>
> list
>
> المنتجات والطُرز والمواصفات والرموز الشريطية وأرقام IMEI والأرقام التسلسلية والتكاليف والأسعار وحركات المخزون؛ وأسماء المورّدين وأرقام هواتفهم وملاحظاتهم.
>
> المبيعات والمدفوعات والأرصدة، بما في ذلك — حين تُدخله الشركة — الرقم الذي دفع منه العميل؛ والعملاء والأطراف الأخرى التي تسجّلها الشركة، بأسمائهم وأرقام هواتفهم وملاحظاتهم.
>
> عمليات الخدمات المالية: الاتجاه والمبلغ والعمولة والمزوّد ورقم هاتف العميل ومرجع المزوّد عند وجوده واسم الموظف الذي سجّلها.
>
> المصروفات مع صورة إيصال اختيارية، والمرتجعات، والمبالغ المستردّة، والإغلاقات اليومية، وعدّ الصندوق.
>
> h3
>
> الملفات المستوردة
>
> list
>
> عندما تستورد مؤسسة جدول بيانات — للمخزون مثلًا — يُحتفَظ بكل صف من الملف مع عملية الاستيراد، حتى يمكن التحقق لاحقًا مما استُورد.
>
> h3
>
> الأمان والتدقيق
>
> list
>
> لكل جلسة مفتوحة: عنوان IP، ومعرّف المتصفح أو التطبيق (user agent)، وأوقات تسجيل الدخول.
>
> لكل جهاز يُضاف إلى الحساب: تسمية، والمنصة، والطراز، وإصدار التطبيق. ولا يُجمع رقم IMEI أو أي بصمة عتادية لهاتفك أنت.
>
> لكل رسالة تحقق: الرقم أو العنوان المرسَل إليه، وبصمة أحادية الاتجاه للرمز، والمحاولات، وحالة الإرسال.
>
> سجل تدقيق للتعديلات: من عدّل ماذا ومتى، والقيم قبل التعديل وبعده.
>
> سجلات طلبات الخدمة: عنوان IP، ومعرّف التطبيق أو المتصفح، وعنوان كل طلب، وقد يتضمن رقم IMEI أو رقمًا تسلسليًا يجري البحث عنه.
>
> not_collected
>
> ما لا نجمعه
>
> list
>
> لا نجمع موقعك: فالتطبيق لا يطلبه ولا يسجّله. وتُحفَظ صورة الإيصال كما هو الملف الذي تختاره، فإذا سجّل هاتفك داخل الملف مكان التقاط الصورة، بقيت هذه المعلومة فيه.
>
> لا نصل إلى جهات الاتصال في هاتفك.
>
> تُستخدم الكاميرا فقط لمسح الرموز الشريطية وأرقام IMEI، ولا تُحفظ أي صورة. ولا تُحفظ صورة إلا حين ترفق إيصالًا بأحد المصروفات.
>
> لا خدمات إعلانية أو تحليلية أو لتقارير الأعطال، ولا ملفات تعريف ارتباط إعلانية أو للتتبع.
>
> use
>
> كيف نستخدم المعلومات
>
> list
>
> لتقديم الخدمة: تسجيل الدخول، وحفظ سجلات الشركة، وإعداد تقاريرها.
>
> للتحقق من بيانات الاتصال وتأكيد الإجراءات الحساسة، مثل حذف الحساب.
>
> لمراجعة الطلبات وإدارة الاشتراكات.
>
> لحماية الخدمة: الصلاحيات، وحدود عدد الطلبات، وسجل التدقيق، والتحقيق في سوء الاستخدام.
>
> لإرسال رسائل الخدمة، مثل رموز التحقق، وإشعارات إلى مالكي الشركة بشأن إغلاقها اليومي.
>
> p
>
> لا نبيع المعلومات الشخصية ولا نستخدمها لأغراض إعلانية.
>
> sharing
>
> من يمكنه رؤية المعلومات
>
> p
>
> داخل الشركة، يرى كل شخص ما يسمح به دوره وخيارات الصلاحيات التي يحدّدها المالك.
>
> p
>
> يرى فريق منصة {displayName} الشركاتِ ومتاجرها، وأسماء حساباتها وبيانات الاتصال بها، واشتراكاتها، والمدفوعات المسجّلة لتلك الاشتراكات.
>
> p
>
> عند تفعيل الإرسال عبر واتساب، تُرسَل رموز التحقق ورسائل الخدمة عبر منصة WhatsApp Business التابعة لشركة Meta، التي تتلقّى الرقم المرسَل إليه والرسالة.
>
> p
>
> عند تفعيل الإرسال عبر البريد الإلكتروني، تُرسَل رموز التحقق ورسائل الخدمة عبر مقدّم خدمة لإرسال البريد الإلكتروني، يتلقّى العنوان المرسَل إليه والرسالة. [[blocker:processors]]
>
> p
>
> الاستضافة ومقدّمو الخدمات الآخرون: [[blocker:processors]]
>
> location
>
> أين تُحفظ المعلومات
>
> p
>
> تُحفظ المعلومات في قاعدة بيانات تُشغَّل لحساب {displayName}. [[blocker:international_transfer]]
>
> security
>
> كيف تُحمى المعلومات
>
> list
>
> تستخدم الاتصالات بين التطبيق وهذا الموقع والخدمة بروتوكول HTTPS.
>
> لا تُحفظ كلمات المرور والرموز السرية وأسرار الجلسات إلا في صورة بصمات أحادية الاتجاه.
>
> يتحقق الخادم من الصلاحيات في كل طلب.
>
> لا يستطيع التطبيق تعديل سجل التدقيق أو حذفه.
>
> لمساحة الإدارة تسجيل دخول خاص بها، وتطلب كلمة مرور المسؤول مجددًا قبل كل قرار.
>
> تُخفى أرقام العملاء في عمليات الخدمات المالية داخل القوائم.
>
> retention
>
> مدة الاحتفاظ بالمعلومات
>
> p
>
> يُحتفَظ بسجلات الشركة والسجلات المحاسبية — المبيعات والمشتريات والمدفوعات والمرتجعات والإغلاقات اليومية وسجل التدقيق وسجلات الاشتراك — لمدة [[blocker:retention_period]].
>
> p
>
> تنتهي صلاحية رموز التحقق بعد بضع دقائق. وتنتهي الجلسات المفتوحة، ويمكن إنهاؤها في أي وقت.
>
> p
>
> لا يُحذف شيء تلقائيًا بعد مدة محددة حتى الآن: تُحفَظ الرموز المنتهية والجلسات المنتهية وسجلات الطلبات والملفات المستوردة إلى أن تُحدَّد مدة الاحتفاظ. [[blocker:retention_period]]
>
> deletion
>
> حذف الحساب
>
> p
>
> يمكنك حذف حسابك من التطبيق؛ ويُؤكَّد الحذف برمز يُرسَل إلى رقم {deletionChannelName} المتحقَّق منه. وتشرح صفحة حذف الحساب الطريقة، وما يُحذف وما يُحتفَظ به.
>
> p
>
> يزيل الحذف هوية الشخص وبيانات الاتصال به من السجلات المستعملة، ومن كل نسخة قابلة للتعديل صنعها التطبيق منها. ولا يُعدَّل سجل التدقيق وسجل الاشتراك المختومان، ولا النسخ الاحتياطية حتى تنتهي صلاحيتها، ولا الإشعارات التي عُرضت بالفعل على أشخاص آخرين في المؤسسة. [[blocker:sealed_history]] [[blocker:backup_retention]]
>
> rights
>
> خياراتك وطلباتك
>
> p
>
> يمكنك الاطلاع على بيانات حسابك في التطبيق، وإنهاء جلساتك، وحذف حسابك. وللحصول على نسخة من معلوماتك الشخصية أو تصحيحها أو لأي طلب آخر، راسل {privacyEmail}، ويتولّى فريق {displayName} الرد على الطلبات. [[blocker:legal_review]]
>
> children
>
> الأطفال
>
> p
>
> صُمّم Dukan ERP للشركات وموظفيها، وهو غير موجّه إلى الأطفال.
>
> website
>
> هذا الموقع
>
> p
>
> لا تضع الصفحات العامة أي ملفات تعريف ارتباط. ويضع تسجيل الدخول إلى حساب شركة أو إلى مساحة الإدارة ملف تعريف ارتباط للجلسة يحتاجه تسجيل الدخول، ولا تتجاوز مدته اثنتي عشرة ساعة. ويُحفظ اختيارك للغة والمظهر في متصفحك. ولا تُستخدم أي أدوات تحليل أو تتبّع إعلاني.
>
> changes
>
> التغييرات على هذه السياسة
>
> p
>
> يظهر إصدار هذه السياسة وتاريخ سريانها في أعلى الصفحة. ويُنشر أي إصدار جديد هنا بتاريخه الخاص.
>

### legalNotice — en

> 1.0 (draft)
>
> draft
>
> Legal notice
>
> Who publishes this website and operates Dukan ERP, and how to reach them.
>
> entity
>
> Publisher and operator
>
> p
>
> {operatorStatus} This website and the Dukan ERP service are published and operated under that name.
>
> p
>
> Dukan ERP is the name of the product; {displayName} is the name under which it is developed and operated.
>
> responsible
>
> Person responsible for publication
>
> p
>
> The person responsible for publication is {publicationDirector}.
>
> hosting
>
> Hosting
>
> p
>
> The providers that host this website and the Dukan ERP service are named here once {displayName} has contracted them. [[blocker:processors]]
>
> contact
>
> Contact
>
> p
>
> Write to the address that matches your question:
>
> ip
>
> Copyright and trademarks
>
> p
>
> The texts, design and software of this website and of Dukan ERP belong to the operator, unless a notice says otherwise. They may not be copied or reused without written permission.
>
> p
>
> The names of the mobile-money and payment services a shop records in Dukan ERP belong to their owners. Showing them does not mean those services endorse Dukan ERP or are connected with it.
>

### legalNotice — fr

> 1.0 (projet)
>
> draft
>
> Mentions légales
>
> Qui publie ce site et exploite Dukan ERP, et comment les joindre.
>
> entity
>
> Éditeur et exploitant
>
> p
>
> {operatorStatus} Ce site et le service Dukan ERP sont édités et exploités sous ce nom.
>
> p
>
> Dukan ERP est le nom du produit ; {displayName} est le nom sous lequel il est développé et exploité.
>
> responsible
>
> Responsable de la publication
>
> p
>
> La personne responsable de la publication est {publicationDirector}.
>
> hosting
>
> Hébergement
>
> p
>
> Les prestataires qui hébergent ce site et le service Dukan ERP seront indiqués ici dès que {displayName} aura conclu un contrat avec eux. [[blocker:processors]]
>
> contact
>
> Contact
>
> p
>
> Écrivez à l’adresse qui correspond à votre question :
>
> ip
>
> Droits d’auteur et marques
>
> p
>
> Les textes, la conception et les logiciels de ce site et de Dukan ERP appartiennent à l’exploitant, sauf mention contraire. Ils ne peuvent être copiés ni réutilisés sans autorisation écrite.
>
> p
>
> Les noms des services de paiement mobile et de paiement qu’une boutique enregistre dans Dukan ERP appartiennent à leurs propriétaires. Les afficher ne signifie pas que ces services approuvent Dukan ERP ou y sont liés.
>

### legalNotice — ar

> 1.0 (مسودة)
>
> draft
>
> البيانات القانونية
>
> من ينشر هذا الموقع ويشغّل Dukan ERP، وكيفية التواصل معه.
>
> entity
>
> الناشر والمشغّل
>
> p
>
> {operatorStatus} ويُنشر هذا الموقع وتُشغَّل خدمة Dukan ERP بهذا الاسم.
>
> p
>
> Dukan ERP هو اسم المنتج؛ و{displayName} هو الاسم الذي يُطوَّر ويُشغَّل تحته.
>
> responsible
>
> المسؤول عن النشر
>
> p
>
> المسؤول عن النشر: {publicationDirector}.
>
> hosting
>
> الاستضافة
>
> p
>
> ستُذكر هنا الجهات التي تستضيف هذا الموقع وخدمة Dukan ERP بمجرد أن تتعاقد معها {displayName}. [[blocker:processors]]
>
> contact
>
> التواصل
>
> p
>
> راسل العنوان المناسب لسؤالك:
>
> ip
>
> حقوق المؤلف والعلامات التجارية
>
> p
>
> نصوص هذا الموقع وتصميمه وبرامجه وبرامج Dukan ERP مملوكة للمشغّل، ما لم يُذكر خلاف ذلك. ولا يجوز نسخها أو إعادة استخدامها دون إذن كتابي.
>
> p
>
> أسماء خدمات الدفع عبر الهاتف وخدمات الدفع التي يسجلها المتجر في Dukan ERP مملوكة لأصحابها. وعرضها لا يعني أن هذه الخدمات تؤيد Dukan ERP أو ترتبط به.
>

### accountDeletion — en

> 1.0 (draft)
>
> draft
>
> Deleting a Dukan ERP account
>
> How to delete a Dukan ERP account, what is removed, what is kept, and why.
>
> where
>
> Delete your account in the app
>
> p
>
> Open the Dukan ERP app and go to More, then Your account, then Delete account. The same option is offered on the screen shown when access to the business is closed.
>
> steps
>
> What happens
>
> list
>
> The app explains what will be deleted and what will be kept, and warns that deletion cannot be undone.
>
> You enter your password again.
>
> A one-time code is sent to your account’s verified {deletionChannelName} number, and you enter it in the app. If your account has no verified number, the app asks you to verify one first.
>
> When the code is confirmed, the deletion is carried out at once.
>
> Every session and every device of the account is signed out.
>
> who
>
> Employees, managers and owners
>
> p
>
> Deleting your account removes your own sign-in only.
>
> p
>
> If you are the last owner of the business, deleting your account closes the business: every account of the business is closed and signed out; the contact details of its customers, its suppliers and the people it lent to are removed, with the numbers its payments came from and the numbers its money services counter served; the notes on its customers, suppliers and expenses, its receipt photos, store addresses and city are removed; its stores are deactivated, and its subscription is cancelled.
>
> kept
>
> What is kept
>
> p
>
> Sales, purchases, payments, returns, daily closings, the audit trail and subscription records are kept, because the business’s accounts depend on them. [[blocker:retention_period]]
>
> p
>
> On the deleted account, the name becomes “Deleted user”; the email address, the telephone number, the sign-in identifier, the password and the PIN are removed, and so are the places and devices it signed in from and the numbers its codes went to. Where its name was copied onto the records it made at the money services counter, it is replaced by “Deleted user” too.
>
> p
>
> Notes and reasons written on other records — payments, refunds, returns, closings, loans, transfers and corrections — stay with those records, with whatever was typed into them. Notifications already shown to other people of the business keep the name they were sent with.
>
> p
>
> Some copies cannot be edited. The audit trail and the subscription history are sealed: they may still hold a name or contact detail written into them at the time. Backups keep their copy until they expire. [[blocker:sealed_history]] [[blocker:backup_retention]]
>
> final
>
> Deletion cannot be undone
>
> p
>
> Once completed, a deleted account cannot be restored and can no longer be used to sign in.
>
> help
>
> If you cannot use the app
>
> p
>
> Deletion is completed in the app, which confirms that the request comes from you. If you cannot open the app, write to {supportEmail} with the business name and the contact you sign in with; {displayName} will help you regain access so that you can delete the account. [[blocker:legal_review]]
>

### accountDeletion — fr

> 1.0 (projet)
>
> draft
>
> Supprimer un compte Dukan ERP
>
> Comment supprimer un compte Dukan ERP, ce qui est supprimé, ce qui est conservé, et pourquoi.
>
> where
>
> Supprimez votre compte dans l’application
>
> p
>
> Ouvrez l’application Dukan ERP et allez dans Plus, puis Votre compte, puis Supprimer le compte. La même option est proposée sur l’écran affiché lorsque l’accès à l’entreprise est fermé.
>
> steps
>
> Ce qui se passe
>
> list
>
> L’application explique ce qui sera supprimé et ce qui sera conservé, et avertit que la suppression est irréversible.
>
> Vous saisissez à nouveau votre mot de passe.
>
> Un code à usage unique est envoyé au numéro {deletionChannelName} vérifié de votre compte, et vous le saisissez dans l’application. Si votre compte n’a pas de numéro vérifié, l’application vous demande d’abord d’en vérifier un.
>
> Une fois le code confirmé, la suppression est effectuée immédiatement.
>
> Toutes les sessions et tous les appareils du compte sont déconnectés.
>
> who
>
> Employés, responsables et propriétaires
>
> p
>
> Supprimer votre compte ne supprime que votre propre accès.
>
> p
>
> Si vous êtes le dernier propriétaire de l’entreprise, supprimer votre compte clôture l’entreprise : tous ses comptes sont fermés et déconnectés ; les coordonnées de ses clients, de ses fournisseurs et des personnes à qui elle a prêté sont supprimées, avec les numéros d’où venaient ses paiements et ceux servis à son comptoir de services d’argent ; les notes sur ses clients, ses fournisseurs et ses dépenses, ses photos de reçus, ses adresses de magasins et sa ville sont supprimées ; ses magasins sont désactivés et son abonnement est annulé.
>
> kept
>
> Ce qui est conservé
>
> p
>
> Les ventes, achats, paiements, retours, clôtures quotidiennes, le journal d’audit et les données d’abonnement sont conservés, car la comptabilité de l’entreprise en dépend. [[blocker:retention_period]]
>
> p
>
> Sur le compte supprimé, le nom devient « Utilisateur supprimé » ; l’adresse e-mail, le numéro de téléphone, l’identifiant de connexion, le mot de passe et le code PIN sont effacés, ainsi que les lieux et appareils depuis lesquels il s’est connecté et les numéros auxquels ses codes ont été envoyés. Là où son nom était recopié sur ce qu’il a enregistré au comptoir de services d’argent, il est aussi remplacé par « Utilisateur supprimé ».
>
> p
>
> Les notes et les motifs écrits sur les autres enregistrements — paiements, remboursements, retours, clôtures, prêts, transferts et corrections — restent avec ces enregistrements, avec ce qui y a été saisi. Les notifications déjà affichées à d’autres personnes de l’entreprise gardent le nom avec lequel elles ont été envoyées.
>
> p
>
> Certaines copies ne peuvent pas être modifiées. Le journal d’audit et l’historique de l’abonnement sont scellés : ils peuvent encore contenir un nom ou une coordonnée inscrits à l’époque. Les sauvegardes gardent leur copie jusqu’à leur expiration. [[blocker:sealed_history]] [[blocker:backup_retention]]
>
> final
>
> La suppression est irréversible
>
> p
>
> Une fois effectuée, la suppression d’un compte ne peut pas être annulée, et le compte ne permet plus de se connecter.
>
> help
>
> Si vous ne pouvez pas utiliser l’application
>
> p
>
> La suppression se fait dans l’application, qui confirme que la demande vient bien de vous. Si vous ne pouvez pas ouvrir l’application, écrivez à {supportEmail} en indiquant le nom de l’entreprise et le contact avec lequel vous vous connectez ; {displayName} vous aidera à retrouver l’accès afin que vous puissiez supprimer le compte. [[blocker:legal_review]]
>

### accountDeletion — ar

> 1.0 (مسودة)
>
> draft
>
> حذف حساب Dukan ERP
>
> كيف تحذف حساب Dukan ERP، وما الذي يُحذف، وما الذي يُحتفَظ به، ولماذا.
>
> where
>
> احذف حسابك من التطبيق
>
> p
>
> افتح تطبيق Dukan ERP وانتقل إلى «المزيد» ثم «حسابك» ثم «حذف الحساب». ويظهر الخيار نفسه في الشاشة التي تُعرض عند إغلاق الوصول إلى الشركة.
>
> steps
>
> ماذا يحدث
>
> list
>
> يشرح التطبيق ما سيُحذف وما سيُحتفَظ به، وينبّه إلى أن الحذف لا يمكن التراجع عنه.
>
> تُدخل كلمة مرورك مرة أخرى.
>
> يُرسَل رمز يُستخدم مرة واحدة إلى رقم {deletionChannelName} الموثَّق في حسابك، وتُدخله في التطبيق. وإن لم يكن في حسابك رقم موثَّق، يطلب منك التطبيق توثيق رقم أولًا.
>
> بعد تأكيد الرمز، يُنفَّذ الحذف فورًا.
>
> تُنهى كل جلسات الحساب ويُسجَّل الخروج من كل أجهزته.
>
> who
>
> الموظفون والمسؤولون والمالكون
>
> p
>
> حذف حسابك لا يزيل إلا تسجيل دخولك أنت.
>
> p
>
> إن كنت آخر مالك للشركة، فإن حذف حسابك يُغلق الشركة: تُغلق كل حساباتها ويُسجَّل خروجها؛ وتُحذف بيانات الاتصال بعملائها ومورّديها والأشخاص الذين أقرضتهم، مع الأرقام التي جاءت منها مدفوعاتها والأرقام التي خدمها شباك الخدمات المالية؛ وتُحذف الملاحظات المسجّلة على عملائها ومورّديها ومصروفاتها، وصور إيصالاتها وعناوين متاجرها ومدينتها؛ وتُعطَّل متاجرها، ويُلغى اشتراكها.
>
> kept
>
> ما الذي يُحتفَظ به
>
> p
>
> يُحتفَظ بالمبيعات والمشتريات والمدفوعات والمرتجعات والإغلاقات اليومية وسجل التدقيق وسجلات الاشتراك، لأن حسابات الشركة تعتمد عليها. [[blocker:retention_period]]
>
> p
>
> في الحساب المحذوف، يصبح الاسم «مستخدم محذوف»؛ ويُزال البريد الإلكتروني ورقم الهاتف ومعرّف الدخول وكلمة المرور والرمز السري، وكذلك الأماكن والأجهزة التي سُجّل الدخول منها والأرقام التي أُرسلت إليها رموزه. وحيث نُسخ اسمه على ما سجّله عند شباك الخدمات المالية، يُستبدل أيضًا بـ«مستخدم محذوف».
>
> p
>
> تبقى الملاحظات والأسباب المكتوبة على السجلات الأخرى — المدفوعات والمبالغ المستردة والمرتجعات والإغلاقات والقروض والتحويلات والتصحيحات — مع تلك السجلات، بكل ما كُتب فيها. وتحتفظ الإشعارات التي عُرضت بالفعل على أشخاص آخرين في المؤسسة بالاسم الذي أُرسلت به.
>
> p
>
> بعض النسخ لا يمكن تعديلها. سجل التدقيق وسجل الاشتراك مختومان: قد يحتويان على اسم أو بيان اتصال كُتب فيهما في حينه. وتحتفظ النسخ الاحتياطية بنسختها حتى تنتهي صلاحيتها. [[blocker:sealed_history]] [[blocker:backup_retention]]
>
> final
>
> لا يمكن التراجع عن الحذف
>
> p
>
> بعد إتمام الحذف، لا يمكن استعادة الحساب، ولا يمكن استخدامه لتسجيل الدخول.
>
> help
>
> إن تعذّر عليك استخدام التطبيق
>
> p
>
> يتم الحذف من التطبيق، الذي يتأكّد من أن الطلب صادر عنك. وإن تعذّر عليك فتح التطبيق، فراسل {supportEmail} ذاكرًا اسم الشركة وجهة الاتصال التي تسجّل الدخول بها، وستساعدك {displayName} على استعادة الوصول لتتمكّن من حذف الحساب. [[blocker:legal_review]]
>
