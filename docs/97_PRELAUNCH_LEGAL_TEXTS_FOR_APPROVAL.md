# 97 — The six pre-launch legal texts of tsxmr.com, for TSX-MR's approval

> 2026-10-17, CLAUDE (cloud). Generated from `erp-control-web` `tsx-public-site` `0516a9c`,
> `src/content/legal-prelaunch.ts`, with the configured values filled in. **Version 0.2, every one a DRAFT.** Not legal
> advice: counsel review is recommended (`docs/96` §2) but is not a condition of the PUBLIC_WEBSITE gate.

## How to approve

Each text is approved, or edited, by TSX-MR. No session approves one on TSX-MR's behalf. In
`src/content/legal-prelaunch.ts`, each document's `status: 'draft'` becomes `'approved'` and its version `1.0`, in all
three languages. The effective date is set at deployment in `VITE_LEGAL_EFFECTIVE_DATE` (`YYYY-MM-DD`); every text shows
it at the top.

## What the tables marked `> [ … ]` show

The pages render these from the configuration rather than from the text. The values below are today's (screenshots:
`ci-evidence/evidence/0516a9c…/public/`).

**The operator's details** (legal notice, contact, about):

| Row | Value |
| --- | --- |
| Trading and project name | TSX-MR |
| Operated by | Abdel Kerim Taleb Ould Sidi |
| Status | An individual operator. TSX-MR is not incorporated as a separate company, so it has no legal form and no trade-register (RCCM) number. |
| Responsible for publication | Abdel Kerim Taleb Ould Sidi |
| Correspondence address | **blank until TSX-MR gives it** (then: the address, Nouakchott, Mauritania) |
| Telephone | +222 36 96 38 39 · +222 37 67 68 27 (from `VITE_ORGANIZATION_PHONE`; tap to call; not labelled WhatsApp) |

**The contact list:**

- General enquiries: contact@tsxmr.com
- Support: support@tsxmr.com
- Privacy: privacy@tsxmr.com
- Security: security@tsxmr.com
- The two numbers above.

No commercial address and no WhatsApp line are shown, because none is configured.

**The policy links:** the other five texts, in the same language.

Nothing else about the operator is published: no passport or identity-card number, no private number, no date of birth.

---


## Privacy policy

### English — Privacy policy

*How TSX-MR handles personal information on this website before Dukan ERP opens.*

Version 0.2 (pre-launch draft) · status **draft**

#### Who is responsible

TSX-MR is a project and trading name. It is not a separately incorporated company: it is operated by Abdel Kerim Taleb Ould Sidi, an individual. This website is published under that name, and Abdel Kerim Taleb Ould Sidi is responsible for the personal information it processes. For any question about personal information, write to privacy@tsxmr.com.

#### What this policy covers

This policy covers this website only. Dukan ERP, a business-management product operated under the TSX-MR name, is not yet open for public registration and collects no information through this website. A privacy policy for the Dukan ERP service will be published here before the service opens.

#### What this website processes

- The website has no account, no sign-in and no form. It does not ask you for personal information.
- Your browser keeps your choice of language and of light or dark display on your own device. This choice is not sent to TSX-MR, and you can clear it in your browser’s settings.
- The website’s own code sets no cookies and uses no analytics, advertising or tracking.
- Like any website, each visit sends technical information to the servers that deliver the pages: your IP address, the page requested, the time and your browser’s description.

#### Hosting

This website is delivered by Cloudflare, Inc., which processes the technical information of each visit to deliver the pages and to protect them from attacks. Cloudflare operates servers in many countries, so this information may be processed outside Mauritania. When Cloudflare’s security features are on, Cloudflare may set a strictly technical cookie to tell people from automated traffic.

#### When you contact us

If you write to one of our addresses or call one of our numbers, we receive what you choose to share: for example your name, your email address or telephone number, and your message. We use it only to answer you and to follow up on your request. Messages are kept in the mailboxes of the email provider TSX-MR uses. You can ask us to delete them.

#### No sale of personal information

TSX-MR does not sell personal information and does not use it for advertising.

#### Your requests

You can ask TSX-MR what personal information it holds about you, and ask for it to be corrected or deleted, by writing to privacy@tsxmr.com.

#### Children

This website is about business software and is not directed to children.

#### Changes to this policy

This policy will change when Dukan ERP opens. The version and the effective date are shown at the top of this page.

#### Contact

Write to the privacy address below.

> [The contact list]

### Français — Politique de confidentialité

*Comment TSX-MR traite les informations personnelles sur ce site avant l’ouverture de Dukan ERP.*

Version 0.2 (projet de pré-lancement) · status **draft**

#### Qui est responsable

TSX-MR est un nom de projet et un nom commercial. Ce n’est pas une société distincte : il est exploité par Abdel Kerim Taleb Ould Sidi, personne physique. Ce site est publié sous ce nom, et Abdel Kerim Taleb Ould Sidi est responsable des informations personnelles qu’il traite. Pour toute question sur les informations personnelles, écrivez à privacy@tsxmr.com.

#### Ce que couvre cette politique

Cette politique couvre uniquement ce site. Dukan ERP, un produit de gestion d’entreprise exploité sous le nom TSX-MR, n’est pas encore ouvert aux inscriptions et ne collecte aucune information par ce site. Une politique de confidentialité du service Dukan ERP sera publiée ici avant son ouverture.

#### Ce que traite ce site

- Ce site n’a ni compte, ni connexion, ni formulaire. Il ne vous demande aucune information personnelle.
- Votre navigateur conserve sur votre propre appareil votre choix de langue et d’affichage clair ou sombre. Ce choix n’est pas envoyé à TSX-MR, et vous pouvez l’effacer dans les réglages de votre navigateur.
- Le code du site ne dépose aucun cookie et n’utilise ni mesure d’audience, ni publicité, ni pistage.
- Comme pour tout site, chaque visite envoie des informations techniques aux serveurs qui livrent les pages : votre adresse IP, la page demandée, l’heure et la description de votre navigateur.

#### Hébergement

Ce site est livré par Cloudflare, Inc., qui traite les informations techniques de chaque visite pour livrer les pages et les protéger contre les attaques. Cloudflare exploite des serveurs dans de nombreux pays : ces informations peuvent donc être traitées hors de Mauritanie. Lorsque les fonctions de sécurité de Cloudflare sont actives, Cloudflare peut déposer un cookie strictement technique pour distinguer les personnes du trafic automatisé.

#### Quand vous nous contactez

Si vous écrivez à l’une de nos adresses ou appelez l’un de nos numéros, nous recevons ce que vous choisissez de partager : par exemple votre nom, votre adresse e-mail ou votre numéro de téléphone, et votre message. Nous l’utilisons uniquement pour vous répondre et donner suite à votre demande. Les messages sont conservés dans les boîtes de messagerie du fournisseur d’e-mail utilisé par TSX-MR. Vous pouvez nous demander de les supprimer.

#### Aucune vente d’informations personnelles

TSX-MR ne vend pas d’informations personnelles et ne les utilise pas à des fins publicitaires.

#### Vos demandes

Vous pouvez demander à TSX-MR quelles informations personnelles il détient sur vous, et en demander la correction ou la suppression, en écrivant à privacy@tsxmr.com.

#### Enfants

Ce site porte sur un logiciel d’entreprise et ne s’adresse pas aux enfants.

#### Modifications de cette politique

Cette politique changera à l’ouverture de Dukan ERP. La version et la date d’entrée en vigueur figurent en haut de cette page.

#### Contact

Écrivez à l’adresse de confidentialité ci-dessous.

> [The contact list]

<div dir="rtl" lang="ar">
### العربية — سياسة الخصوصية

*كيف تتعامل TSX-MR مع المعلومات الشخصية على هذا الموقع قبل افتتاح Dukan ERP.*

Version 0.2 (مسودة ما قبل الإطلاق) · status **draft**

#### من المسؤول

TSX-MR اسم مشروع واسم تجاري، وليس شركة مستقلة مسجَّلة؛ ويتولى تشغيلَه شخصٌ طبيعي هو Abdel Kerim Taleb Ould Sidi. ويُنشر هذا الموقع بهذا الاسم، وتقع المسؤولية عن المعلومات الشخصية التي يعالجها على Abdel Kerim Taleb Ould Sidi. لأي سؤال عن المعلومات الشخصية، راسلوا privacy@tsxmr.com.

#### ما تشمله هذه السياسة

تشمل هذه السياسة هذا الموقع وحده. أما Dukan ERP، منتج إدارة الأعمال الذي يُشغَّل تحت اسم TSX-MR، فالتسجيل فيه غير مفتوح للعموم بعد، ولا يجمع أي معلومات عبر هذا الموقع. وستُنشر هنا سياسة خصوصية خاصة بخدمة Dukan ERP قبل افتتاحها.

#### ما يعالجه هذا الموقع

- لا يحتوي هذا الموقع على حساب ولا تسجيل دخول ولا استمارة، ولا يطلب منكم أي معلومات شخصية.
- يحتفظ متصفحكم على جهازكم أنتم باختياركم للغة والعرض الفاتح أو الداكن. لا يُرسل هذا الاختيار إلى TSX-MR، ويمكنكم مسحه من إعدادات المتصفح.
- لا تضع شيفرة الموقع نفسها أي ملفات تعريف ارتباط، ولا تستخدم أي قياس للزيارات أو إعلانات أو تتبع.
- كما في أي موقع، ترسل كل زيارة معلومات تقنية إلى الخوادم التي تقدّم الصفحات: عنوان IP الخاص بكم، والصفحة المطلوبة، والوقت، ووصف متصفحكم.

#### الاستضافة

تقدّم هذا الموقعَ شركة Cloudflare, Inc.، التي تعالج المعلومات التقنية لكل زيارة لتقديم الصفحات وحمايتها من الهجمات. وتشغّل Cloudflare خوادم في بلدان كثيرة، لذلك قد تُعالج هذه المعلومات خارج موريتانيا. وعندما تكون ميزات الأمان لدى Cloudflare مفعّلة، قد تضع Cloudflare ملف تعريف ارتباط تقنيًا بحتًا للتمييز بين الأشخاص والزيارات الآلية.

#### عندما تتواصلون معنا

إذا راسلتم أحد عناويننا أو اتصلتم بأحد أرقامنا، نتلقى ما تختارون مشاركته: كاسمكم أو عنوان بريدكم الإلكتروني أو رقم هاتفكم، ورسالتكم. ولا نستخدم ذلك إلا للرد عليكم ومتابعة طلبكم. وتُحفظ الرسائل في صناديق البريد لدى مزوّد البريد الإلكتروني الذي تعتمده TSX-MR. ويمكنكم أن تطلبوا منا حذفها.

#### لا بيع للمعلومات الشخصية

لا تبيع TSX-MR المعلومات الشخصية ولا تستخدمها لأغراض إعلانية.

#### طلباتكم

يمكنكم أن تسألوا TSX-MR عن المعلومات الشخصية التي تحتفظ بها عنكم، وأن تطلبوا تصحيحها أو حذفها، بمراسلة privacy@tsxmr.com.

#### الأطفال

يتناول هذا الموقع برمجيات للأعمال، وهو غير موجّه إلى الأطفال.

#### تغييرات هذه السياسة

ستتغير هذه السياسة عند افتتاح Dukan ERP. ويظهر رقم الإصدار وتاريخ السريان في أعلى هذه الصفحة.

#### التواصل

راسلوا عنوان الخصوصية أدناه.

> [The contact list]

</div>

## Terms of use of this website

### English — Terms of use of this website

*The terms for using this website before Dukan ERP opens.*

Version 0.2 (pre-launch draft) · status **draft**

#### Who publishes this website

TSX-MR is a project and trading name. It is not a separately incorporated company: it is operated by Abdel Kerim Taleb Ould Sidi, an individual. This website is published under that name. By using it, you accept these terms.

#### Dukan ERP is not yet available

Dukan ERP is being prepared for launch. This website does not sell it, take registrations for it or form any contract for it. The terms of service of Dukan ERP will be published here before the service opens.

#### Information on this website

The descriptions of Dukan ERP show the product as it is being built. They may change before launch and are not an offer.

#### Intellectual property

The texts, design and software of this website belong to Abdel Kerim Taleb Ould Sidi, unless a notice says otherwise. They may not be copied or reused without written permission.

#### Using this website

- Do not try to disrupt this website or to reach parts of it that are not public.
- To report a security weakness, follow the security page.

#### Changes to these terms

These terms may change. The version and the effective date are shown at the top of this page.

#### Contact

Questions about these terms can be sent to support@tsxmr.com.

### Français — Conditions d’utilisation de ce site

*Les conditions d’utilisation de ce site avant l’ouverture de Dukan ERP.*

Version 0.2 (projet de pré-lancement) · status **draft**

#### Qui publie ce site

TSX-MR est un nom de projet et un nom commercial. Ce n’est pas une société distincte : il est exploité par Abdel Kerim Taleb Ould Sidi, personne physique. Ce site est publié sous ce nom. En l’utilisant, vous acceptez ces conditions.

#### Dukan ERP n’est pas encore disponible

Dukan ERP est en préparation pour son lancement. Ce site ne le vend pas, n’enregistre pas d’inscriptions et ne conclut aucun contrat à son sujet. Les conditions de service de Dukan ERP seront publiées ici avant son ouverture.

#### Les informations de ce site

Les descriptions de Dukan ERP présentent le produit tel qu’il est en cours de construction. Elles peuvent changer avant le lancement et ne constituent pas une offre.

#### Propriété intellectuelle

Les textes, la présentation et le logiciel de ce site appartiennent à Abdel Kerim Taleb Ould Sidi, sauf mention contraire. Ils ne peuvent être copiés ou réutilisés sans autorisation écrite.

#### Utilisation de ce site

- N’essayez pas de perturber ce site ni d’accéder à ses parties non publiques.
- Pour signaler une faille de sécurité, suivez la page sécurité.

#### Modifications de ces conditions

Ces conditions peuvent changer. La version et la date d’entrée en vigueur figurent en haut de cette page.

#### Contact

Les questions sur ces conditions peuvent être envoyées à support@tsxmr.com.

<div dir="rtl" lang="ar">
### العربية — شروط استخدام هذا الموقع

*شروط استخدام هذا الموقع قبل افتتاح Dukan ERP.*

Version 0.2 (مسودة ما قبل الإطلاق) · status **draft**

#### من ينشر هذا الموقع

TSX-MR اسم مشروع واسم تجاري، وليس شركة مستقلة مسجَّلة؛ ويتولى تشغيلَه شخصٌ طبيعي هو Abdel Kerim Taleb Ould Sidi. ويُنشر هذا الموقع بهذا الاسم. وباستخدامكم له، فإنكم تقبلون هذه الشروط.

#### Dukan ERP غير متاح بعد

Dukan ERP قيد التحضير للإطلاق. ولا يبيعه هذا الموقع ولا يقبل التسجيل فيه ولا يُبرم أي عقد بشأنه. وستُنشر هنا شروط خدمة Dukan ERP قبل افتتاحها.

#### المعلومات على هذا الموقع

تعرض أوصاف Dukan ERP المنتج كما يُبنى الآن. وقد تتغير قبل الإطلاق، وليست عرضًا تعاقديًا.

#### الملكية الفكرية

نصوص هذا الموقع وتصميمه وبرمجياته ملك لـAbdel Kerim Taleb Ould Sidi، ما لم يُذكر خلاف ذلك. ولا يجوز نسخها أو إعادة استخدامها دون إذن كتابي.

#### استخدام هذا الموقع

- لا تحاولوا تعطيل هذا الموقع أو الوصول إلى أجزائه غير العامة.
- للإبلاغ عن ثغرة أمنية، اتبعوا صفحة الأمان.

#### تغييرات هذه الشروط

قد تتغير هذه الشروط. ويظهر رقم الإصدار وتاريخ السريان في أعلى هذه الصفحة.

#### التواصل

يمكن إرسال الأسئلة عن هذه الشروط إلى support@tsxmr.com.

</div>

## Account deletion

### English — Account deletion

*Dukan ERP is not yet open, so there are no public accounts to delete. How deletion will work will be explained here before it opens.*

Version 0.2 (pre-launch draft) · status **draft**

#### Before Dukan ERP opens

Dukan ERP is not yet open for public registration, and this website has no accounts. There is nothing to delete here today.

#### When Dukan ERP opens

Accounts will be deleted from inside the Dukan ERP mobile app. Before the service opens, this page will explain each step: how identity is confirmed, what is deleted and what has to be kept.

#### Information given in another way

If you have given TSX-MR personal information in another way, for example by email or by telephone, write to privacy@tsxmr.com to ask for it to be deleted.

### Français — Suppression de compte

*Dukan ERP n’est pas encore ouvert : il n’existe donc aucun compte public à supprimer. Le fonctionnement de la suppression sera expliqué ici avant l’ouverture.*

Version 0.2 (projet de pré-lancement) · status **draft**

#### Avant l’ouverture de Dukan ERP

Dukan ERP n’est pas encore ouvert aux inscriptions, et ce site n’a pas de comptes. Il n’y a aujourd’hui rien à supprimer ici.

#### À l’ouverture de Dukan ERP

Les comptes se supprimeront depuis l’application mobile Dukan ERP. Avant l’ouverture du service, cette page en expliquera chaque étape : comment l’identité est confirmée, ce qui est supprimé et ce qui doit être conservé.

#### Informations données autrement

Si vous avez donné des informations personnelles à TSX-MR par un autre moyen, par exemple par e-mail ou par téléphone, écrivez à privacy@tsxmr.com pour en demander la suppression.

<div dir="rtl" lang="ar">
### العربية — حذف الحساب

*لم يُفتح Dukan ERP بعد، ولذلك لا توجد حسابات عامة لحذفها. وستُشرح هنا طريقة الحذف قبل الافتتاح.*

Version 0.2 (مسودة ما قبل الإطلاق) · status **draft**

#### قبل افتتاح Dukan ERP

التسجيل في Dukan ERP غير مفتوح للعموم بعد، ولا توجد حسابات على هذا الموقع. فلا شيء لحذفه هنا اليوم.

#### عند افتتاح Dukan ERP

ستُحذف الحسابات من داخل تطبيق Dukan ERP على الهاتف. وقبل افتتاح الخدمة، ستشرح هذه الصفحة كل خطوة: كيف تُؤكَّد الهوية، وما الذي يُحذف، وما الذي يجب الاحتفاظ به.

#### معلومات قُدّمت بطريقة أخرى

إذا قدّمتم معلومات شخصية إلى TSX-MR بطريقة أخرى، كالبريد الإلكتروني أو الهاتف مثلًا، فراسلوا privacy@tsxmr.com لطلب حذفها.

</div>

## Privacy choices

### English — Privacy choices

*The choices you have about personal information on this website.*

Version 0.2 (pre-launch draft) · status **draft**

#### Language and display

Your choice of language and of light or dark display is kept in your browser. You can change it on any page, or clear it in your browser’s settings.

#### No tracking to refuse

This website uses no analytics, advertising or tracking, so there is nothing to opt out of.

#### Asking about your information

To ask what TSX-MR holds about you, or to have it corrected or deleted, write to privacy@tsxmr.com.

#### Dukan ERP

Dukan ERP is not yet open. The choices it will offer will be described here before it opens.

#### Contact

Write to the privacy address below.

> [The contact list]

### Français — Choix de confidentialité

*Les choix dont vous disposez sur les informations personnelles de ce site.*

Version 0.2 (projet de pré-lancement) · status **draft**

#### Langue et affichage

Votre choix de langue et d’affichage clair ou sombre est conservé dans votre navigateur. Vous pouvez le changer sur chaque page, ou l’effacer dans les réglages de votre navigateur.

#### Aucun pistage à refuser

Ce site n’utilise ni mesure d’audience, ni publicité, ni pistage : il n’y a donc rien à refuser.

#### Vous renseigner sur vos informations

Pour savoir ce que TSX-MR détient sur vous, ou le faire corriger ou supprimer, écrivez à privacy@tsxmr.com.

#### Dukan ERP

Dukan ERP n’est pas encore ouvert. Les choix qu’il proposera seront décrits ici avant son ouverture.

#### Contact

Écrivez à l’adresse de confidentialité ci-dessous.

> [The contact list]

<div dir="rtl" lang="ar">
### العربية — خيارات الخصوصية

*الخيارات المتاحة لكم بشأن المعلومات الشخصية على هذا الموقع.*

Version 0.2 (مسودة ما قبل الإطلاق) · status **draft**

#### اللغة والعرض

يُحفظ اختياركم للغة والعرض الفاتح أو الداكن في متصفحكم. ويمكنكم تغييره من أي صفحة، أو مسحه من إعدادات المتصفح.

#### لا تتبع لرفضه

لا يستخدم هذا الموقع أي قياس للزيارات أو إعلانات أو تتبع، فلا شيء يستدعي الرفض.

#### السؤال عن معلوماتكم

لمعرفة ما تحتفظ به TSX-MR عنكم، أو لطلب تصحيحه أو حذفه، راسلوا privacy@tsxmr.com.

#### Dukan ERP

لم يُفتح Dukan ERP بعد. وستُوصف هنا الخيارات التي سيقدّمها قبل افتتاحه.

#### التواصل

راسلوا عنوان الخصوصية أدناه.

> [The contact list]

</div>

## Legal notice

### English — Legal notice

*Who publishes this website, and how to reach them.*

Version 0.2 (pre-launch draft) · status **draft**

#### Publisher

TSX-MR is a project and trading name. It is not a separately incorporated company: it is operated by Abdel Kerim Taleb Ould Sidi, an individual. This website is published under that name. The operator’s details are below.

> [The operator’s details table: trading and project name, operated by, status, responsible for publication, correspondence address, telephone numbers]

#### Responsible for publication

The person responsible for publication is Abdel Kerim Taleb Ould Sidi.

#### Dukan ERP

Dukan ERP is a product operated under the TSX-MR name. It is being prepared for launch and is not yet open for public registration.

#### Hosting

This website is hosted by Cloudflare, Inc.

#### Contact

Write to the address that matches your question:

> [The contact list: general enquiries, support, privacy and security addresses, and the configured telephone numbers]

#### Copyright and trademarks

The texts, design and software of this website belong to Abdel Kerim Taleb Ould Sidi, unless a notice says otherwise. They may not be copied or reused without written permission.

#### Policies

How this website handles information is set out in these pages:

> [Links to the other legal pages]

### Français — Mentions légales

*Qui publie ce site, et comment le joindre.*

Version 0.2 (projet de pré-lancement) · status **draft**

#### Éditeur

TSX-MR est un nom de projet et un nom commercial. Ce n’est pas une société distincte : il est exploité par Abdel Kerim Taleb Ould Sidi, personne physique. Ce site est publié sous ce nom. Les informations sur l’exploitant figurent ci-dessous.

> [The operator’s details table: trading and project name, operated by, status, responsible for publication, correspondence address, telephone numbers]

#### Responsable de la publication

La personne responsable de la publication est Abdel Kerim Taleb Ould Sidi.

#### Dukan ERP

Dukan ERP est un produit exploité sous le nom TSX-MR. Il est en préparation pour son lancement et n’est pas encore ouvert aux inscriptions.

#### Hébergement

Ce site est hébergé par Cloudflare, Inc.

#### Contact

Écrivez à l’adresse qui correspond à votre question :

> [The contact list: general enquiries, support, privacy and security addresses, and the configured telephone numbers]

#### Droits d’auteur et marques

Les textes, la présentation et le logiciel de ce site appartiennent à Abdel Kerim Taleb Ould Sidi, sauf mention contraire. Ils ne peuvent être copiés ou réutilisés sans autorisation écrite.

#### Politiques

La manière dont ce site traite les informations est exposée dans ces pages :

> [Links to the other legal pages]

<div dir="rtl" lang="ar">
### العربية — إشعار قانوني

*من ينشر هذا الموقع، وكيف يمكن التواصل معه.*

Version 0.2 (مسودة ما قبل الإطلاق) · status **draft**

#### الناشر

TSX-MR اسم مشروع واسم تجاري، وليس شركة مستقلة مسجَّلة؛ ويتولى تشغيلَه شخصٌ طبيعي هو Abdel Kerim Taleb Ould Sidi. ويُنشر هذا الموقع بهذا الاسم. وبيانات المشغّل مذكورة أدناه.

> [The operator’s details table: trading and project name, operated by, status, responsible for publication, correspondence address, telephone numbers]

#### المسؤول عن النشر

المسؤول عن النشر: Abdel Kerim Taleb Ould Sidi.

#### Dukan ERP

Dukan ERP منتج يُشغَّل تحت اسم TSX-MR. وهو قيد التحضير للإطلاق، والتسجيل فيه غير مفتوح للعموم بعد.

#### الاستضافة

تستضيف هذا الموقعَ شركة Cloudflare, Inc.

#### التواصل

راسلوا العنوان الذي يناسب سؤالكم:

> [The contact list: general enquiries, support, privacy and security addresses, and the configured telephone numbers]

#### حقوق النشر والعلامات التجارية

نصوص هذا الموقع وتصميمه وبرمجياته ملك لـAbdel Kerim Taleb Ould Sidi، ما لم يُذكر خلاف ذلك. ولا يجوز نسخها أو إعادة استخدامها دون إذن كتابي.

#### السياسات

تشرح هذه الصفحات كيف يتعامل هذا الموقع مع المعلومات:

> [Links to the other legal pages]

</div>

## Security

### English — Reporting a security problem

*How to tell TSX-MR about a weakness in this website or in Dukan ERP, and what we ask of you.*

Version 0.2 (pre-launch draft) · status **draft**

#### How to report

Write to security@tsxmr.com. Please include what you found, where, the steps that reproduce it, and what someone could do with it. One problem per message helps.

#### What we ask of you

- Do not read, copy, change or delete anyone’s information. If a test reaches such information, stop and report it.
- Do not slow down, overload or interrupt this website.
- Do not try to trick people, and do not test physical premises.
- Give us a reasonable time to fix a problem before you tell anyone else about it.
- Never ask for payment in exchange for not publishing or not exploiting what you found.

#### What happens next

TSX-MR reads every report sent to security@tsxmr.com and replies to the address it came from. TSX-MR does not offer payment or rewards for reports.

### Français — Signaler un problème de sécurité

*Comment signaler à TSX-MR une faille dans ce site ou dans Dukan ERP, et ce que nous vous demandons.*

Version 0.2 (projet de pré-lancement) · status **draft**

#### Comment signaler

Écrivez à security@tsxmr.com. Indiquez ce que vous avez trouvé, où, les étapes pour le reproduire et ce qu’une personne pourrait en faire. Un problème par message, c’est plus simple.

#### Ce que nous vous demandons

- Ne lisez, ne copiez, ne modifiez et ne supprimez les informations de personne. Si un test atteint de telles informations, arrêtez-vous et signalez-le.
- Ne ralentissez pas, ne surchargez pas et n’interrompez pas ce site.
- N’essayez pas de tromper des personnes et ne testez pas de locaux physiques.
- Laissez-nous un délai raisonnable pour corriger un problème avant d’en parler à qui que ce soit.
- Ne demandez jamais de paiement en échange de ne pas publier ou de ne pas exploiter ce que vous avez trouvé.

#### La suite

TSX-MR lit chaque signalement envoyé à security@tsxmr.com et répond à l’adresse d’où il vient. TSX-MR n’offre ni paiement ni récompense pour les signalements.

<div dir="rtl" lang="ar">
### العربية — الإبلاغ عن مشكلة أمنية

*كيف تُبلغون TSX-MR عن ثغرة في هذا الموقع أو في Dukan ERP، وما نطلبه منكم.*

Version 0.2 (مسودة ما قبل الإطلاق) · status **draft**

#### طريقة الإبلاغ

راسلوا security@tsxmr.com. واذكروا ما وجدتموه وأين، وخطوات إعادة إظهاره، وما يمكن لأي شخص أن يفعله به. ويُفضَّل إرسال مشكلة واحدة في كل رسالة.

#### ما نطلبه منكم

- لا تقرؤوا معلومات أي شخص ولا تنسخوها ولا تغيّروها ولا تحذفوها. وإذا وصل اختبار إلى معلومات كهذه، فتوقفوا وأبلغوا عنه.
- لا تبطّئوا هذا الموقع ولا تُثقلوه ولا توقفوه.
- لا تحاولوا خداع أي شخص، ولا تختبروا أي مقار مادية.
- امنحونا وقتًا معقولًا لإصلاح المشكلة قبل إخبار أي أحد بها.
- لا تطلبوا أبدًا مقابلًا ماليًا لعدم نشر ما وجدتموه أو عدم استغلاله.

#### ماذا يحدث بعد ذلك

تقرأ TSX-MR كل بلاغ يُرسل إلى security@tsxmr.com وترد على العنوان الذي جاء منه. ولا تقدّم TSX-MR أي مقابل أو مكافأة على البلاغات.

</div>

