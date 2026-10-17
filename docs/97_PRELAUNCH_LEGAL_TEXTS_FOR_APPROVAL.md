# 97 — The six pre-launch legal texts of tsxmr.com, for TSX-MR's approval

> **Version 0.3, 2026-10-17, CLAUDE (cloud).** Website `erp-control-web` `tsx-public-site` `b5c0328`,
> `src/content/legal-prelaunch.ts`, with the configured values filled in. It replaces version 0.2 (`0516a9c`).
>
> - **All six texts are still DRAFT.** Their approval flags were not touched, and no session approves them on TSX-MR's
>   behalf.
> - This is not legal advice, and no lawyer has reviewed these texts. Counsel review is recommended (§4) but is not a
>   condition of the PUBLIC_WEBSITE gate.

## 1. How to approve

1. Read §5 (EN/FR/AR), with §2–§4.
2. Approve the texts as they are, or send the changes you want.
3. On your explicit approval, a session changes, in `src/content/legal-prelaunch.ts`:
   - each approved document's `status: 'draft'` to `'approved'`;
   - its `version` to `'1.0'`;
   - in all three languages.

   It commits that change on its own.
4. The effective date is set at deployment in `VITE_LEGAL_EFFECTIVE_DATE` (`YYYY-MM-DD`). It is the actual publication
   date, not a commit date, and every text shows it at the top. **None is set today.** Nothing will be invented to let
   the build pass.

## 2. What changed from version 0.2

| Text | Change |
| --- | --- |
| All six | Version 0.3. In Arabic, verbs whose subject is TSX-MR are now masculine, agreeing with "مشروع" (project), as the operator sentence already did. The feminine had implied "شركة" (company). |
| Privacy | **Who:** adds the correspondence address. **Scope:** says the service's own policy will name its providers, and names the planned ones as plans: Brevo for transactional email, and Meta's WhatsApp Business Platform (Cloud API) for verification messages. It says neither is used by this website. **Contact:** covers telephone calls and WhatsApp messages, says Meta processes a WhatsApp message under its own terms, and adds "kept only for as long as that takes" (§3). **Requests:** may be sent to the postal address; adds an identity check before acting, and "we answer as soon as we can". **New "Security" section:** HTTPS only, no account or password, and a link to the security page. |
| Terms | **Information:** "not an offer, a price or a promise of availability". **Contact:** `contact@tsxmr.com` or the postal address (it was `support@`). |
| Account deletion | Information given by WhatsApp is covered. An identity check may be asked for. The information is deleted unless the law requires keeping it, and the person is told when it is done (§3). |
| Privacy choices | Explains Cloudflare's technical security cookie: it protects against automated traffic, is not used for tracking, and has no setting here. |
| Legal notice | The host now has its address: Cloudflare, Inc., 101 Townsend Street, San Francisco, CA 94107, United States (§4, item 10). The operator's details now show the correspondence address. |
| Security | TSX-MR says when a reported problem is fixed (§3). The text names the `security.txt` file. |

Unchanged:
- the operator sentence;
- the person responsible for publication;
- "Dukan ERP is coming soon";
- no account, no form, no cookie of the site's own, no analytics.

## 3. Commitments the texts now make, for TSX-MR to confirm

These are not legal provisions. They are promises about how TSX-MR will act, so only TSX-MR can confirm them:

1. Messages sent to TSX-MR are kept **only for as long as needed** to handle the request and its follow-up.
2. Identity may be checked before a request is acted on.
3. A deletion request is carried out, unless the law requires keeping the information, and **the person is told when
   it is done**.
4. A security reporter is **told when the problem is fixed**.
5. **"We answer as soon as we can"**: no fixed deadline is promised.

If any of these is not how TSX-MR will work, the sentence changes before approval.

## 4. Legal questions still open (for owner or counsel review; none answered here)

Nothing below is claimed in the texts, and no text says the website or TSX-MR complies with any law.

1. **Which data-protection law applies, and what it requires.** Mauritania's law on personal data (believed to be
   Law No. 2017-020 of 22 July 2017) is the likely frame, but counsel must confirm it. Counsel must also say:
   - whether a declaration or authorisation is needed for this website or for the service;
   - which legal bases must be stated;
   - which rights must be listed (access, correction, deletion, objection…), and with what deadline;
   - which authority a person may complain to, and whether it must be named.

   The texts list only "ask to see, correct or delete", with no legal basis, deadline or authority.
2. **Foreign data-protection laws.** Visitors from the EU or elsewhere may trigger obligations such as the GDPR.
   The site does not target them. Counsel decides whether anything must be added.
3. **International transfer.** Cloudflare may process visit data outside Mauritania, and the privacy text says so.
   Counsel must say whether Mauritanian law requires more, such as safeguards or authorisation.
4. **The operator's legal status.** TSX-MR is an unregistered individual operator. Counsel must say:
   - whether a natural person operating a public website under a trading name must register, for example as an
     individual trader at the RCCM;
   - whether the website must then show a registration or tax number.

   For the paid portal, this is the `operator_registration` blocker (`docs/96` §8).
5. **Publication-responsibility rules.** Whether Mauritanian law (press or electronic communications) requires more
   about the person responsible for publication, such as a postal address or a status.
6. **Governing law and jurisdiction** for the website's terms of use. None is stated.
7. **Liability:** whether the terms need a disclaimer for the information shown (none is written), and how it may be
   worded under Mauritanian law.
8. **Correspondence address.** The address is "Tevragh Zeina, Nouakchott-Ouest", with no street or postal code.
   Counsel must say whether that is a sufficient postal address for the legal notice and for privacy requests.
9. **Cookies.** Whether Cloudflare's strictly technical security cookie needs any notice or consent beyond the
   explanation given.
10. **Host details.** The legal notice gives Cloudflare, Inc.'s address as 101 Townsend Street, San Francisco,
    CA 94107, United States. Check it against Cloudflare's current legal notice before approval.
11. **The service's providers.** Brevo and Meta's WhatsApp Cloud API are named only as planned (D181, `docs/21`).
    The Dukan ERP privacy policy, not these texts, must later describe:
    - the processing;
    - the data-processing agreements;
    - the transfers;
    - for WhatsApp, the consent and opt-out rules of D181 §5.

## 5. The six texts (EN, FR, AR)

### What the tables marked `> [ … ]` show

The pages build these from the configuration, not from the text. These are today's values.

**The operator's details** (legal notice, contact, about):

| Row | Value |
| --- | --- |
| Trading and project name | TSX-MR |
| Operated by | Abdel Kerim Taleb Ould Sidi |
| Status | An individual operator. TSX-MR is not incorporated as a separate company, so it has no legal form and no trade-register (RCCM) number. |
| Responsible for publication | Abdel Kerim Taleb Ould Sidi |
| Correspondence address | EN Tevragh Zeina, Nouakchott-Ouest, Mauritania · FR Tevragh Zeina, Nouakchott-Ouest, Mauritanie · AR تفرغ زينة، نواكشوط الغربية، موريتانيا |
| Telephone | +222 36 96 38 39 · +222 37 67 68 27 (from `VITE_ORGANIZATION_PHONE`; tap to call; not labelled WhatsApp) |

**The contact list:**
- general enquiries: contact@tsxmr.com;
- support: support@tsxmr.com;
- privacy: privacy@tsxmr.com;
- security: security@tsxmr.com;
- the two numbers above.

No commercial address and no WhatsApp line are shown, because none is configured.

**The policy links:** the other five texts, in the same language.

**Not published:** passport, identity-card or tax numbers, any private number, a date of birth, a street number or a
postal code.

---


### Privacy policy

#### English — Privacy policy

*How TSX-MR handles personal information on this website before Dukan ERP opens.*

Version 0.3 (pre-launch draft) · status **draft**

##### Who is responsible

TSX-MR is a project and trading name. It is not a separately incorporated company: it is operated by Abdel Kerim Taleb Ould Sidi, an individual. This website is published under that name, and Abdel Kerim Taleb Ould Sidi is responsible for the personal information it processes. Correspondence address: Tevragh Zeina, Nouakchott-Ouest, Mauritania. For any question about personal information, write to privacy@tsxmr.com.

##### What this policy covers

This policy covers this website only. Dukan ERP, a business-management product operated under the TSX-MR name, is not yet open for public registration and collects no information through this website. A privacy policy for the Dukan ERP service will be published here before the service opens. It will describe what the service collects and name the providers it relies on, which are planned to include Brevo for transactional email and Meta’s WhatsApp Business Platform (Cloud API) for verification messages. Neither is used by this website.

##### What this website processes

- The website has no account, no sign-in and no form. It does not ask you for personal information.
- Your browser keeps your choice of language and of light or dark display on your own device. This choice is not sent to TSX-MR, and you can clear it in your browser’s settings.
- The website’s own code sets no cookies and uses no analytics, advertising or tracking.
- Like any website, each visit sends technical information to the servers that deliver the pages: your IP address, the page requested, the time and your browser’s description.

##### Hosting

This website is delivered by Cloudflare, Inc., which processes the technical information of each visit to deliver the pages and to protect them from attacks. Cloudflare operates servers in many countries, so this information may be processed outside Mauritania. When Cloudflare’s security features are on, Cloudflare may set a strictly technical cookie to tell people from automated traffic.

##### When you contact us

If you write to one of our addresses, call one of our numbers or send them a WhatsApp message, we receive what you choose to share: for example your name, your email address or telephone number, and your message. We use it only to answer you and to follow up on your request, and we keep it only for as long as that takes. Emails are kept in the mailboxes of the email provider TSX-MR uses. A WhatsApp message is also processed by WhatsApp (Meta), under its own terms. You can ask us to delete what you sent.

##### No sale of personal information

TSX-MR does not sell personal information and does not use it for advertising.

##### Your requests

You can ask TSX-MR what personal information it holds about you, and ask for it to be corrected or deleted, by writing to privacy@tsxmr.com or to the correspondence address. We may ask you to confirm who you are before acting on a request, so that information is never given to the wrong person. We answer as soon as we can.

##### Security

This website is served over HTTPS only and holds no account or password. To report a weakness, follow the security page.

##### Children

This website is about business software and is not directed to children.

##### Changes to this policy

This policy will change when Dukan ERP opens. The version and the effective date are shown at the top of this page.

##### Contact

Write to the privacy address below.

> [The contact list]

#### Français — Politique de confidentialité

*Comment TSX-MR traite les informations personnelles sur ce site avant l’ouverture de Dukan ERP.*

Version 0.3 (projet de pré-lancement) · status **draft**

##### Qui est responsable

TSX-MR est un nom de projet et un nom commercial. Ce n’est pas une société distincte : il est exploité par Abdel Kerim Taleb Ould Sidi, personne physique. Ce site est publié sous ce nom, et Abdel Kerim Taleb Ould Sidi est responsable des informations personnelles qu’il traite. Adresse de correspondance : Tevragh Zeina, Nouakchott-Ouest, Mauritanie. Pour toute question sur les informations personnelles, écrivez à privacy@tsxmr.com.

##### Ce que couvre cette politique

Cette politique couvre uniquement ce site. Dukan ERP, un produit de gestion d’entreprise exploité sous le nom TSX-MR, n’est pas encore ouvert aux inscriptions et ne collecte aucune information par ce site. Une politique de confidentialité du service Dukan ERP sera publiée ici avant son ouverture. Elle décrira ce que collecte le service et nommera les prestataires sur lesquels il s’appuie, dont il est prévu qu’ils comprennent Brevo pour les e-mails transactionnels et la plateforme WhatsApp Business de Meta (Cloud API) pour les messages de vérification. Aucun des deux n’est utilisé par ce site.

##### Ce que traite ce site

- Ce site n’a ni compte, ni connexion, ni formulaire. Il ne vous demande aucune information personnelle.
- Votre navigateur conserve sur votre propre appareil votre choix de langue et d’affichage clair ou sombre. Ce choix n’est pas envoyé à TSX-MR, et vous pouvez l’effacer dans les réglages de votre navigateur.
- Le code du site ne dépose aucun cookie et n’utilise ni mesure d’audience, ni publicité, ni pistage.
- Comme pour tout site, chaque visite envoie des informations techniques aux serveurs qui livrent les pages : votre adresse IP, la page demandée, l’heure et la description de votre navigateur.

##### Hébergement

Ce site est livré par Cloudflare, Inc., qui traite les informations techniques de chaque visite pour livrer les pages et les protéger contre les attaques. Cloudflare exploite des serveurs dans de nombreux pays : ces informations peuvent donc être traitées hors de Mauritanie. Lorsque les fonctions de sécurité de Cloudflare sont actives, Cloudflare peut déposer un cookie strictement technique pour distinguer les personnes du trafic automatisé.

##### Quand vous nous contactez

Si vous écrivez à l’une de nos adresses, appelez l’un de nos numéros ou leur envoyez un message WhatsApp, nous recevons ce que vous choisissez de partager : par exemple votre nom, votre adresse e-mail ou votre numéro de téléphone, et votre message. Nous l’utilisons uniquement pour vous répondre et donner suite à votre demande, et nous ne le conservons que le temps nécessaire. Les e-mails sont conservés dans les boîtes de messagerie du fournisseur d’e-mail utilisé par TSX-MR. Un message WhatsApp est aussi traité par WhatsApp (Meta), selon ses propres conditions. Vous pouvez nous demander de supprimer ce que vous avez envoyé.

##### Aucune vente d’informations personnelles

TSX-MR ne vend pas d’informations personnelles et ne les utilise pas à des fins publicitaires.

##### Vos demandes

Vous pouvez demander à TSX-MR quelles informations personnelles il détient sur vous, et en demander la correction ou la suppression, en écrivant à privacy@tsxmr.com ou à l’adresse de correspondance. Nous pouvons vous demander de confirmer votre identité avant de donner suite, afin qu’aucune information ne soit remise à la mauvaise personne. Nous répondons dès que possible.

##### Sécurité

Ce site est servi uniquement en HTTPS et ne détient ni compte ni mot de passe. Pour signaler une faille, suivez la page sécurité.

##### Enfants

Ce site porte sur un logiciel d’entreprise et ne s’adresse pas aux enfants.

##### Modifications de cette politique

Cette politique changera à l’ouverture de Dukan ERP. La version et la date d’entrée en vigueur figurent en haut de cette page.

##### Contact

Écrivez à l’adresse de confidentialité ci-dessous.

> [The contact list]

<div dir="rtl" lang="ar">
#### العربية — سياسة الخصوصية

*كيف يتعامل TSX-MR مع المعلومات الشخصية على هذا الموقع قبل افتتاح Dukan ERP.*

Version 0.3 (مسودة ما قبل الإطلاق) · status **draft**

##### من المسؤول

TSX-MR اسم مشروع واسم تجاري، وليس شركة مستقلة مسجَّلة؛ ويتولى تشغيلَه شخصٌ طبيعي هو Abdel Kerim Taleb Ould Sidi. ويُنشر هذا الموقع بهذا الاسم، وتقع المسؤولية عن المعلومات الشخصية التي يعالجها على Abdel Kerim Taleb Ould Sidi. عنوان المراسلة: تفرغ زينة، نواكشوط الغربية، موريتانيا. لأي سؤال عن المعلومات الشخصية، راسلوا privacy@tsxmr.com.

##### ما تشمله هذه السياسة

تشمل هذه السياسة هذا الموقع وحده. أما Dukan ERP، منتج إدارة الأعمال الذي يُشغَّل تحت اسم TSX-MR، فالتسجيل فيه غير مفتوح للعموم بعد، ولا يجمع أي معلومات عبر هذا الموقع. وستُنشر هنا سياسة خصوصية خاصة بخدمة Dukan ERP قبل افتتاحها، تصف ما تجمعه الخدمة وتسمّي المزوّدين الذين تعتمد عليهم، ومن المقرر أن يكون بينهم Brevo للرسائل الإلكترونية التشغيلية ومنصة WhatsApp Business التابعة لـMeta (Cloud API) لرسائل التحقق. ولا يستخدم هذا الموقع أيًّا منهما.

##### ما يعالجه هذا الموقع

- لا يحتوي هذا الموقع على حساب ولا تسجيل دخول ولا استمارة، ولا يطلب منكم أي معلومات شخصية.
- يحتفظ متصفحكم على جهازكم أنتم باختياركم للغة والعرض الفاتح أو الداكن. لا يُرسل هذا الاختيار إلى TSX-MR، ويمكنكم مسحه من إعدادات المتصفح.
- لا تضع شيفرة الموقع نفسها أي ملفات تعريف ارتباط، ولا تستخدم أي قياس للزيارات أو إعلانات أو تتبع.
- كما في أي موقع، ترسل كل زيارة معلومات تقنية إلى الخوادم التي تقدّم الصفحات: عنوان IP الخاص بكم، والصفحة المطلوبة، والوقت، ووصف متصفحكم.

##### الاستضافة

تقدّم هذا الموقعَ شركة Cloudflare, Inc.، التي تعالج المعلومات التقنية لكل زيارة لتقديم الصفحات وحمايتها من الهجمات. وتشغّل Cloudflare خوادم في بلدان كثيرة، لذلك قد تُعالج هذه المعلومات خارج موريتانيا. وعندما تكون ميزات الأمان لدى Cloudflare مفعّلة، قد تضع Cloudflare ملف تعريف ارتباط تقنيًا بحتًا للتمييز بين الأشخاص والزيارات الآلية.

##### عندما تتواصلون معنا

إذا راسلتم أحد عناويننا أو اتصلتم بأحد أرقامنا أو أرسلتم إليه رسالة واتساب، نتلقى ما تختارون مشاركته: كاسمكم أو عنوان بريدكم الإلكتروني أو رقم هاتفكم، ورسالتكم. ولا نستخدم ذلك إلا للرد عليكم ومتابعة طلبكم، ولا نحتفظ به إلا المدة اللازمة لذلك. وتُحفظ الرسائل الإلكترونية في صناديق البريد لدى مزوّد البريد الإلكتروني الذي يعتمده TSX-MR. وتعالج واتساب (Meta) رسالة واتساب أيضًا وفق شروطها الخاصة. ويمكنكم أن تطلبوا منا حذف ما أرسلتموه.

##### لا بيع للمعلومات الشخصية

لا يبيع TSX-MR المعلومات الشخصية ولا يستخدمها لأغراض إعلانية.

##### طلباتكم

يمكنكم أن تسألوا TSX-MR عن المعلومات الشخصية التي يحتفظ بها عنكم، وأن تطلبوا تصحيحها أو حذفها، بمراسلة privacy@tsxmr.com أو عنوان المراسلة. وقد نطلب منكم تأكيد هويتكم قبل تنفيذ الطلب، حتى لا تُسلَّم أي معلومات إلى غير صاحبها. ونرد في أقرب وقت ممكن.

##### الأمان

لا يُقدَّم هذا الموقع إلا عبر HTTPS، ولا يحتفظ بأي حساب أو كلمة مرور. وللإبلاغ عن ثغرة، اتبعوا صفحة الأمان.

##### الأطفال

يتناول هذا الموقع برمجيات للأعمال، وهو غير موجّه إلى الأطفال.

##### تغييرات هذه السياسة

ستتغير هذه السياسة عند افتتاح Dukan ERP. ويظهر رقم الإصدار وتاريخ السريان في أعلى هذه الصفحة.

##### التواصل

راسلوا عنوان الخصوصية أدناه.

> [The contact list]

</div>

### Terms of use of this website

#### English — Terms of use of this website

*The terms for using this website before Dukan ERP opens.*

Version 0.3 (pre-launch draft) · status **draft**

##### Who publishes this website

TSX-MR is a project and trading name. It is not a separately incorporated company: it is operated by Abdel Kerim Taleb Ould Sidi, an individual. This website is published under that name. By using it, you accept these terms.

##### Dukan ERP is not yet available

Dukan ERP is being prepared for launch. This website does not sell it, take registrations for it or form any contract for it. The terms of service of Dukan ERP will be published here before the service opens.

##### Information on this website

The descriptions of Dukan ERP show the product as it is being built. They may change before launch. They are not an offer, a price or a promise of availability.

##### Intellectual property

The texts, design and software of this website belong to Abdel Kerim Taleb Ould Sidi, unless a notice says otherwise. They may not be copied or reused without written permission.

##### Using this website

- Do not try to disrupt this website or to reach parts of it that are not public.
- To report a security weakness, follow the security page.

##### Changes to these terms

These terms may change. The version and the effective date are shown at the top of this page.

##### Contact

Questions about these terms can be sent to contact@tsxmr.com, or by post to Tevragh Zeina, Nouakchott-Ouest, Mauritania.

#### Français — Conditions d’utilisation de ce site

*Les conditions d’utilisation de ce site avant l’ouverture de Dukan ERP.*

Version 0.3 (projet de pré-lancement) · status **draft**

##### Qui publie ce site

TSX-MR est un nom de projet et un nom commercial. Ce n’est pas une société distincte : il est exploité par Abdel Kerim Taleb Ould Sidi, personne physique. Ce site est publié sous ce nom. En l’utilisant, vous acceptez ces conditions.

##### Dukan ERP n’est pas encore disponible

Dukan ERP est en préparation pour son lancement. Ce site ne le vend pas, n’enregistre pas d’inscriptions et ne conclut aucun contrat à son sujet. Les conditions de service de Dukan ERP seront publiées ici avant son ouverture.

##### Les informations de ce site

Les descriptions de Dukan ERP présentent le produit tel qu’il est en cours de construction. Elles peuvent changer avant le lancement. Elles ne constituent ni une offre, ni un prix, ni une promesse de disponibilité.

##### Propriété intellectuelle

Les textes, la présentation et le logiciel de ce site appartiennent à Abdel Kerim Taleb Ould Sidi, sauf mention contraire. Ils ne peuvent être copiés ou réutilisés sans autorisation écrite.

##### Utilisation de ce site

- N’essayez pas de perturber ce site ni d’accéder à ses parties non publiques.
- Pour signaler une faille de sécurité, suivez la page sécurité.

##### Modifications de ces conditions

Ces conditions peuvent changer. La version et la date d’entrée en vigueur figurent en haut de cette page.

##### Contact

Les questions sur ces conditions peuvent être envoyées à contact@tsxmr.com, ou par courrier à Tevragh Zeina, Nouakchott-Ouest, Mauritanie.

<div dir="rtl" lang="ar">
#### العربية — شروط استخدام هذا الموقع

*شروط استخدام هذا الموقع قبل افتتاح Dukan ERP.*

Version 0.3 (مسودة ما قبل الإطلاق) · status **draft**

##### من ينشر هذا الموقع

TSX-MR اسم مشروع واسم تجاري، وليس شركة مستقلة مسجَّلة؛ ويتولى تشغيلَه شخصٌ طبيعي هو Abdel Kerim Taleb Ould Sidi. ويُنشر هذا الموقع بهذا الاسم. وباستخدامكم له، فإنكم تقبلون هذه الشروط.

##### Dukan ERP غير متاح بعد

Dukan ERP قيد التحضير للإطلاق. ولا يبيعه هذا الموقع ولا يقبل التسجيل فيه ولا يُبرم أي عقد بشأنه. وستُنشر هنا شروط خدمة Dukan ERP قبل افتتاحها.

##### المعلومات على هذا الموقع

تعرض أوصاف Dukan ERP المنتج كما يُبنى الآن. وقد تتغير قبل الإطلاق. وهي ليست عرضًا تعاقديًا ولا سعرًا ولا وعدًا بالإتاحة.

##### الملكية الفكرية

نصوص هذا الموقع وتصميمه وبرمجياته ملك لـAbdel Kerim Taleb Ould Sidi، ما لم يُذكر خلاف ذلك. ولا يجوز نسخها أو إعادة استخدامها دون إذن كتابي.

##### استخدام هذا الموقع

- لا تحاولوا تعطيل هذا الموقع أو الوصول إلى أجزائه غير العامة.
- للإبلاغ عن ثغرة أمنية، اتبعوا صفحة الأمان.

##### تغييرات هذه الشروط

قد تتغير هذه الشروط. ويظهر رقم الإصدار وتاريخ السريان في أعلى هذه الصفحة.

##### التواصل

يمكن إرسال الأسئلة عن هذه الشروط إلى contact@tsxmr.com، أو بالبريد إلى تفرغ زينة، نواكشوط الغربية، موريتانيا.

</div>

### Account deletion

#### English — Account deletion

*Dukan ERP is not yet open, so there are no public accounts to delete. How deletion will work will be explained here before it opens.*

Version 0.3 (pre-launch draft) · status **draft**

##### Before Dukan ERP opens

Dukan ERP is not yet open for public registration, and this website has no accounts. There is nothing to delete here today.

##### When Dukan ERP opens

Accounts will be deleted from inside the Dukan ERP mobile app. Before the service opens, this page will explain each step: how identity is confirmed, what is deleted and what has to be kept.

##### Information given in another way

If you have given TSX-MR personal information in another way, for example by email, by telephone or through WhatsApp, write to privacy@tsxmr.com to ask for it to be deleted. We may ask you to confirm who you are. We then delete it, unless the law requires us to keep it, and tell you when it is done.

#### Français — Suppression de compte

*Dukan ERP n’est pas encore ouvert : il n’existe donc aucun compte public à supprimer. Le fonctionnement de la suppression sera expliqué ici avant l’ouverture.*

Version 0.3 (projet de pré-lancement) · status **draft**

##### Avant l’ouverture de Dukan ERP

Dukan ERP n’est pas encore ouvert aux inscriptions, et ce site n’a pas de comptes. Il n’y a aujourd’hui rien à supprimer ici.

##### À l’ouverture de Dukan ERP

Les comptes se supprimeront depuis l’application mobile Dukan ERP. Avant l’ouverture du service, cette page en expliquera chaque étape : comment l’identité est confirmée, ce qui est supprimé et ce qui doit être conservé.

##### Informations données autrement

Si vous avez donné des informations personnelles à TSX-MR par un autre moyen, par exemple par e-mail, par téléphone ou par WhatsApp, écrivez à privacy@tsxmr.com pour en demander la suppression. Nous pouvons vous demander de confirmer votre identité. Nous les supprimons ensuite, sauf si la loi nous oblige à les conserver, et vous prévenons une fois que c’est fait.

<div dir="rtl" lang="ar">
#### العربية — حذف الحساب

*لم يُفتح Dukan ERP بعد، ولذلك لا توجد حسابات عامة لحذفها. وستُشرح هنا طريقة الحذف قبل الافتتاح.*

Version 0.3 (مسودة ما قبل الإطلاق) · status **draft**

##### قبل افتتاح Dukan ERP

التسجيل في Dukan ERP غير مفتوح للعموم بعد، ولا توجد حسابات على هذا الموقع. فلا شيء لحذفه هنا اليوم.

##### عند افتتاح Dukan ERP

ستُحذف الحسابات من داخل تطبيق Dukan ERP على الهاتف. وقبل افتتاح الخدمة، ستشرح هذه الصفحة كل خطوة: كيف تُؤكَّد الهوية، وما الذي يُحذف، وما الذي يجب الاحتفاظ به.

##### معلومات قُدّمت بطريقة أخرى

إذا قدّمتم معلومات شخصية إلى TSX-MR بطريقة أخرى، كالبريد الإلكتروني أو الهاتف أو واتساب مثلًا، فراسلوا privacy@tsxmr.com لطلب حذفها. وقد نطلب منكم تأكيد هويتكم. ثم نحذفها، ما لم يُلزمنا القانون بالاحتفاظ بها، ونُعلمكم عند الانتهاء.

</div>

### Privacy choices

#### English — Privacy choices

*The choices you have about personal information on this website.*

Version 0.3 (pre-launch draft) · status **draft**

##### Language and display

Your choice of language and of light or dark display is kept in your browser. You can change it on any page, or clear it in your browser’s settings.

##### No tracking to refuse

This website uses no analytics, advertising or tracking, so there is nothing to opt out of. When Cloudflare’s security features set their technical cookie, it serves only to protect the website from automated traffic; it is not used for tracking, and this website offers no setting for it.

##### Asking about your information

To ask what TSX-MR holds about you, or to have it corrected or deleted, write to privacy@tsxmr.com.

##### Dukan ERP

Dukan ERP is not yet open. The choices it will offer will be described here before it opens.

##### Contact

Write to the privacy address below.

> [The contact list]

#### Français — Choix de confidentialité

*Les choix dont vous disposez sur les informations personnelles de ce site.*

Version 0.3 (projet de pré-lancement) · status **draft**

##### Langue et affichage

Votre choix de langue et d’affichage clair ou sombre est conservé dans votre navigateur. Vous pouvez le changer sur chaque page, ou l’effacer dans les réglages de votre navigateur.

##### Aucun pistage à refuser

Ce site n’utilise ni mesure d’audience, ni publicité, ni pistage : il n’y a donc rien à refuser. Lorsque les fonctions de sécurité de Cloudflare déposent leur cookie technique, il sert uniquement à protéger le site du trafic automatisé ; il n’est pas utilisé pour le pistage, et ce site ne propose aucun réglage à son sujet.

##### Vous renseigner sur vos informations

Pour savoir ce que TSX-MR détient sur vous, ou le faire corriger ou supprimer, écrivez à privacy@tsxmr.com.

##### Dukan ERP

Dukan ERP n’est pas encore ouvert. Les choix qu’il proposera seront décrits ici avant son ouverture.

##### Contact

Écrivez à l’adresse de confidentialité ci-dessous.

> [The contact list]

<div dir="rtl" lang="ar">
#### العربية — خيارات الخصوصية

*الخيارات المتاحة لكم بشأن المعلومات الشخصية على هذا الموقع.*

Version 0.3 (مسودة ما قبل الإطلاق) · status **draft**

##### اللغة والعرض

يُحفظ اختياركم للغة والعرض الفاتح أو الداكن في متصفحكم. ويمكنكم تغييره من أي صفحة، أو مسحه من إعدادات المتصفح.

##### لا تتبع لرفضه

لا يستخدم هذا الموقع أي قياس للزيارات أو إعلانات أو تتبع، فلا شيء يستدعي الرفض. وعندما تضع ميزات الأمان لدى Cloudflare ملفها التقني، فإنه يقتصر على حماية الموقع من الزيارات الآلية، ولا يُستخدم للتتبع، ولا يوفّر هذا الموقع أي إعداد بشأنه.

##### السؤال عن معلوماتكم

لمعرفة ما يحتفظ به TSX-MR عنكم، أو لطلب تصحيحه أو حذفه، راسلوا privacy@tsxmr.com.

##### Dukan ERP

لم يُفتح Dukan ERP بعد. وستُوصف هنا الخيارات التي سيقدّمها قبل افتتاحه.

##### التواصل

راسلوا عنوان الخصوصية أدناه.

> [The contact list]

</div>

### Legal notice

#### English — Legal notice

*Who publishes this website, and how to reach them.*

Version 0.3 (pre-launch draft) · status **draft**

##### Publisher

TSX-MR is a project and trading name. It is not a separately incorporated company: it is operated by Abdel Kerim Taleb Ould Sidi, an individual. This website is published under that name. The operator’s details are below.

> [The operator’s details table: trading and project name, operated by, status, responsible for publication, correspondence address, telephone numbers]

##### Responsible for publication

The person responsible for publication is Abdel Kerim Taleb Ould Sidi.

##### Dukan ERP

Dukan ERP is a product operated under the TSX-MR name. It is being prepared for launch and is not yet open for public registration.

##### Hosting

This website is hosted by Cloudflare, Inc., 101 Townsend Street, San Francisco, CA 94107, United States.

##### Contact

Write to the address that matches your question:

> [The contact list: general enquiries, support, privacy and security addresses, and the configured telephone numbers]

##### Copyright and trademarks

The texts, design and software of this website belong to Abdel Kerim Taleb Ould Sidi, unless a notice says otherwise. They may not be copied or reused without written permission.

##### Policies

How this website handles information is set out in these pages:

> [Links to the other legal pages]

#### Français — Mentions légales

*Qui publie ce site, et comment le joindre.*

Version 0.3 (projet de pré-lancement) · status **draft**

##### Éditeur

TSX-MR est un nom de projet et un nom commercial. Ce n’est pas une société distincte : il est exploité par Abdel Kerim Taleb Ould Sidi, personne physique. Ce site est publié sous ce nom. Les informations sur l’exploitant figurent ci-dessous.

> [The operator’s details table: trading and project name, operated by, status, responsible for publication, correspondence address, telephone numbers]

##### Responsable de la publication

La personne responsable de la publication est Abdel Kerim Taleb Ould Sidi.

##### Dukan ERP

Dukan ERP est un produit exploité sous le nom TSX-MR. Il est en préparation pour son lancement et n’est pas encore ouvert aux inscriptions.

##### Hébergement

Ce site est hébergé par Cloudflare, Inc., 101 Townsend Street, San Francisco, CA 94107, États-Unis.

##### Contact

Écrivez à l’adresse qui correspond à votre question :

> [The contact list: general enquiries, support, privacy and security addresses, and the configured telephone numbers]

##### Droits d’auteur et marques

Les textes, la présentation et le logiciel de ce site appartiennent à Abdel Kerim Taleb Ould Sidi, sauf mention contraire. Ils ne peuvent être copiés ou réutilisés sans autorisation écrite.

##### Politiques

La manière dont ce site traite les informations est exposée dans ces pages :

> [Links to the other legal pages]

<div dir="rtl" lang="ar">
#### العربية — إشعار قانوني

*من ينشر هذا الموقع، وكيف يمكن التواصل معه.*

Version 0.3 (مسودة ما قبل الإطلاق) · status **draft**

##### الناشر

TSX-MR اسم مشروع واسم تجاري، وليس شركة مستقلة مسجَّلة؛ ويتولى تشغيلَه شخصٌ طبيعي هو Abdel Kerim Taleb Ould Sidi. ويُنشر هذا الموقع بهذا الاسم. وبيانات المشغّل مذكورة أدناه.

> [The operator’s details table: trading and project name, operated by, status, responsible for publication, correspondence address, telephone numbers]

##### المسؤول عن النشر

المسؤول عن النشر: Abdel Kerim Taleb Ould Sidi.

##### Dukan ERP

Dukan ERP منتج يُشغَّل تحت اسم TSX-MR. وهو قيد التحضير للإطلاق، والتسجيل فيه غير مفتوح للعموم بعد.

##### الاستضافة

تستضيف هذا الموقعَ شركة ⁦Cloudflare, Inc., 101 Townsend Street, San Francisco, CA 94107⁩، الولايات المتحدة.

##### التواصل

راسلوا العنوان الذي يناسب سؤالكم:

> [The contact list: general enquiries, support, privacy and security addresses, and the configured telephone numbers]

##### حقوق النشر والعلامات التجارية

نصوص هذا الموقع وتصميمه وبرمجياته ملك لـAbdel Kerim Taleb Ould Sidi، ما لم يُذكر خلاف ذلك. ولا يجوز نسخها أو إعادة استخدامها دون إذن كتابي.

##### السياسات

تشرح هذه الصفحات كيف يتعامل هذا الموقع مع المعلومات:

> [Links to the other legal pages]

</div>

### Security

#### English — Reporting a security problem

*How to tell TSX-MR about a weakness in this website or in Dukan ERP, and what we ask of you.*

Version 0.3 (pre-launch draft) · status **draft**

##### How to report

Write to security@tsxmr.com. Please include what you found, where, the steps that reproduce it, and what someone could do with it. One problem per message helps.

##### What we ask of you

- Do not read, copy, change or delete anyone’s information. If a test reaches such information, stop and report it.
- Do not slow down, overload or interrupt this website.
- Do not try to trick people, and do not test physical premises.
- Give us a reasonable time to fix a problem before you tell anyone else about it.
- Never ask for payment in exchange for not publishing or not exploiting what you found.

##### What happens next

TSX-MR reads every report sent to security@tsxmr.com, replies to the address it came from, and says when the problem is fixed. The same address is published in this website’s security.txt file. TSX-MR does not offer payment or rewards for reports.

#### Français — Signaler un problème de sécurité

*Comment signaler à TSX-MR une faille dans ce site ou dans Dukan ERP, et ce que nous vous demandons.*

Version 0.3 (projet de pré-lancement) · status **draft**

##### Comment signaler

Écrivez à security@tsxmr.com. Indiquez ce que vous avez trouvé, où, les étapes pour le reproduire et ce qu’une personne pourrait en faire. Un problème par message, c’est plus simple.

##### Ce que nous vous demandons

- Ne lisez, ne copiez, ne modifiez et ne supprimez les informations de personne. Si un test atteint de telles informations, arrêtez-vous et signalez-le.
- Ne ralentissez pas, ne surchargez pas et n’interrompez pas ce site.
- N’essayez pas de tromper des personnes et ne testez pas de locaux physiques.
- Laissez-nous un délai raisonnable pour corriger un problème avant d’en parler à qui que ce soit.
- Ne demandez jamais de paiement en échange de ne pas publier ou de ne pas exploiter ce que vous avez trouvé.

##### La suite

TSX-MR lit chaque signalement envoyé à security@tsxmr.com, répond à l’adresse d’où il vient et indique quand le problème est corrigé. La même adresse figure dans le fichier security.txt de ce site. TSX-MR n’offre ni paiement ni récompense pour les signalements.

<div dir="rtl" lang="ar">
#### العربية — الإبلاغ عن مشكلة أمنية

*كيف تُبلغون TSX-MR عن ثغرة في هذا الموقع أو في Dukan ERP، وما نطلبه منكم.*

Version 0.3 (مسودة ما قبل الإطلاق) · status **draft**

##### طريقة الإبلاغ

راسلوا security@tsxmr.com. واذكروا ما وجدتموه وأين، وخطوات إعادة إظهاره، وما يمكن لأي شخص أن يفعله به. ويُفضَّل إرسال مشكلة واحدة في كل رسالة.

##### ما نطلبه منكم

- لا تقرؤوا معلومات أي شخص ولا تنسخوها ولا تغيّروها ولا تحذفوها. وإذا وصل اختبار إلى معلومات كهذه، فتوقفوا وأبلغوا عنه.
- لا تبطّئوا هذا الموقع ولا تُثقلوه ولا توقفوه.
- لا تحاولوا خداع أي شخص، ولا تختبروا أي مقار مادية.
- امنحونا وقتًا معقولًا لإصلاح المشكلة قبل إخبار أي أحد بها.
- لا تطلبوا أبدًا مقابلًا ماليًا لعدم نشر ما وجدتموه أو عدم استغلاله.

##### ماذا يحدث بعد ذلك

يقرأ TSX-MR كل بلاغ يُرسل إلى security@tsxmr.com، ويرد على العنوان الذي جاء منه، ويُعلم صاحبه عند إصلاح المشكلة. والعنوان نفسه منشور في ملف security.txt لهذا الموقع. ولا يقدّم TSX-MR أي مقابل أو مكافأة على البلاغات.

</div>

