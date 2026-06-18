import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/brand_config.dart';
import '../../../../core/legal_document_info.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../providers/app_language_provider.dart';

/// Bilingual terms — beta disclaimer + TECHMCU / LuhaRide roles. Not a substitute for legal counsel.
List<({String title, String body})> _termsSections(AppLanguageCode lang) {
  if (lang == AppLanguageCode.hi) return _termsHi;
  return _termsEn;
}

final List<({String title, String body})> _termsEn = [
  (
    title: '0. Beta software',
    body:
        'The app may be provided as a beta or pre-release version. Features may change, be incomplete, or '
        'temporarily unavailable. You use the Service at your own risk during beta. Please report problems '
        'via Help / support channels. Continued use means you accept this.',
  ),
  (
    title: '1. Who we are',
    body:
        'The "${BrandConfig.appName}" mobile application and related online services ("Service") are offered '
        'under the ${BrandConfig.parentBrand} brand. ${BrandConfig.appName} is a technology platform that '
        'helps passengers find and connect with drivers for shared or scheduled rides in Uttarakhand and '
        'nearby areas. We do not own or operate vehicles and are not a transport undertaking or taxi '
        'operator unless expressly stated otherwise.',
  ),
  (
    title: '2. Platform role & liability',
    body:
        'Drivers and unions are independent third parties. They alone are responsible for licences, permits, '
        'insurance, vehicle condition, and compliance with traffic and transport laws. To the fullest extent '
        'permitted by applicable law, ${BrandConfig.parentBrand}, ${BrandConfig.appName}, and their '
        'representatives are not liable for accidents, delays, loss, theft, injury, or disputes between '
        'users during or after trips, except where liability cannot be excluded by law.',
  ),
  (
    title: '3. Your responsibilities',
    body:
        'Provide accurate profile information. Do not harass, abuse, or use the Service for unlawful activity. '
        'Do not misrepresent identity or vehicle details. Respect bookings you make; repeated no-shows or '
        'misuse may lead to restrictions.',
  ),
  (
    title: '4. Driver & union responsibilities',
    body:
        'Maintain valid driving licence, RC, insurance, and permits as required by law. Do not exceed legal '
        'seating capacity. Drive safely. Do not misrepresent routes, fares, or vehicle data shown in the app.',
  ),
  (
    title: '5. Bookings, cancellations & no-shows',
    body:
        'Either party may cancel a trip in genuine situations. A driver may also fail to start, arrive, or '
        'complete a ride after creating or accepting it, and a passenger may not show up. ${BrandConfig.appName} '
        'is only a connection layer: it does not operate rides and does not guarantee that any trip will take '
        'place, start or run on time, or be completed. To the fullest extent permitted by law, we are not '
        'responsible for losses, missed connections, extra costs, waiting, or inconvenience caused by a '
        'cancellation, no-show, late arrival, or a driver not taking you, and we do not pay any compensation or '
        'refund. Resolve such matters directly with the other party. We may send in-app notifications where '
        'technically possible, and we may warn, restrict, or suspend accounts for repeated cancellations, '
        'no-shows, misuse, fraud, or safety concerns.',
  ),
  (
    title: '6. Payments — no money handled by the platform',
    body:
        '${BrandConfig.parentBrand} and ${BrandConfig.appName} do not collect, hold, or transfer fare money '
        'between passengers and drivers. The Service is only a connection layer: it helps users find each '
        'other and coordinate rides. How you pay (cash, UPI, or otherwise), how much you pay, and any '
        'agreement on fare are strictly between you and the other user, after you communicate directly. '
        'We do not guarantee payments, refunds, or settlement timing. If a dispute, loss, fraud, or '
        'wrong payment arises between users—including non-payment, overpayment, or scam—the platform '
        'bears no responsibility and accepts no liability, to the fullest extent permitted by law. Report '
        'safety or abuse issues via Help; payment disagreements must be resolved between the parties or '
        'through appropriate legal channels.',
  ),
  (
    title: '7. Intellectual property & software',
    body:
        'The original source code, overall system architecture, back-end and application logic, data models, '
        'business rules, booking and operational workflows, integrations, visual design, branding, and '
        'user experience of the ${BrandConfig.appName} Service—as designed, implemented, and operated by '
        '${BrandConfig.parentBrand}—are proprietary to ${BrandConfig.parentBrand} or its licensors. '
        'Deciding how these pieces fit together, how the platform behaves, and how rides are coordinated '
        'from a product and business perspective is our responsibility; the Service is not a white-label or '
        'off-the-shelf package we merely resell from another vendor. '
        'Our implementation relies on widely used tools and platforms, which may include (for example) '
        'mobile application frameworks such as Flutter, server runtimes such as Node.js, databases such as '
        'PostgreSQL, reverse proxies or web servers such as nginx, process supervisors such as PM2, and '
        'other third-party and open-source libraries—the exact stack may evolve. The authors and licensors '
        'of those tools retain rights in their own materials under their respective licences; we comply with '
        'applicable licence requirements for the components we use, and where a licence applies to something '
        'we distribute to you, you must respect that licence for that item. '
        'That does not change that the ${BrandConfig.appName} implementation as a whole, as we offer it, is '
        'our proprietary product. You may not copy, reverse engineer, scrape, or misuse our software or '
        'branding except as the law allows or we agree in writing.',
  ),
  (
    title: '8. Data & privacy',
    body:
        'We process limited personal data to run the Service (e.g. name, phone, ride history). We do not sell '
        'your personal data. A separate privacy notice may apply; use the Service only if you agree to '
        'reasonable processing for operations and support. '
        'Support & grievances: write to ${BrandConfig.grievContactEmail}. '
        'KYC and verification documents are stored on access-controlled servers with standard safeguards; we '
        'retain them only as long as needed for verification, fraud prevention, and legal compliance while '
        'your account is active. After account closure we delete or anonymise them within a reasonable period '
        'unless applicable law requires longer retention. We do not sell your document images.',
  ),
  (
    title: '9. Account suspension',
    body:
        'We may suspend or terminate access for breach of these terms, fraud, safety risk, or legal '
        'requirements, subject to applicable law.',
  ),
  (
    title: '10. Changes',
    body:
        'We may update these terms. Material changes will be reflected in the app when practical. Continued '
        'use after update constitutes acceptance unless applicable law requires otherwise.',
  ),
  (
    title: '11. Governing law & disputes',
    body:
        'These terms are governed by the laws of India. Courts at Dehradun, Uttarakhand (or as required by '
        'law) shall have exclusive jurisdiction, subject to mandatory consumer protections.',
  ),
  (
    title: '12. Ratings & reviews',
    body:
        'Ratings and reviews shown in the app are generated from feedback submitted by users (passengers and '
        'drivers) after rides. They reflect user opinions only and are not an endorsement, certification, or '
        'guarantee by ${BrandConfig.parentBrand} or ${BrandConfig.appName} of any driver, passenger, vehicle, '
        'or ride. A driver is rated on the basis of these user reviews and ratings. We may use this feedback to '
        'rank, display, limit, suspend, or remove accounts, but we do not guarantee its accuracy and accept no '
        'liability for decisions you make based on it.',
  ),
  (
    title: '13. Assumption of risk — accidents, injury, illness or death',
    body:
        'Road travel carries inherent risks. By using the Service to find or share a ride, you knowingly and '
        'voluntarily assume all such risks. To the fullest extent permitted by law, ${BrandConfig.parentBrand} '
        'and ${BrandConfig.appName} are NOT liable for any accident, collision, injury, disability, illness, '
        'death, medical emergency, or loss of or damage to property suffered by any person before, during, or '
        'after a ride arranged through the Service — whether a passenger, driver, co-passenger, or third party. '
        'The driver and/or vehicle owner is solely responsible for the vehicle, its road-worthiness, valid '
        'insurance, safe driving, and the consequences of the journey. We do not provide ride, accident, or '
        'life insurance, and arranging adequate insurance is the driver\'s responsibility. In an emergency, '
        'contact local emergency services (e.g. 112) directly.',
  ),
  (
    title: '14. Crime, fraud and safety',
    body:
        'We are not responsible for, and accept no liability for, any fraud, theft, cheating, harassment, '
        'assault, misconduct, impersonation, or other unlawful or criminal act committed by any user against '
        'another. Such matters are between the persons involved and the authorities. Report crimes to the '
        'police and serious safety or abuse issues to us via Help. We may, in good faith and as permitted by '
        'law, cooperate with and share information with law-enforcement or other authorities. Always use your '
        'own judgement, verify the person and vehicle, and prioritise your safety.',
  ),
  (
    title: '15. Verification limits & service "as is"',
    body:
        'We verify drivers and unions on a best-effort basis (for example through submitted documents and KYC) '
        'before listing them, and we genuinely try our best. However, no verification can be perfect or '
        'guaranteed, identities and documents can be misused, and circumstances can change after verification '
        '— so we do NOT and cannot guarantee the identity, conduct, credentials, or safety of any driver, '
        'union, or vehicle 100%. Passengers are not subject to the same document verification, and full '
        'verification of every user may never be 100% achievable. The Service is provided on an "as is" and '
        '"as available" basis without warranties of any kind, to the fullest extent permitted by law. You are '
        'responsible for exercising reasonable caution before and during any ride.',
  ),
  (
    title: '16. Limitation of liability & indemnity',
    body:
        'To the fullest extent permitted by applicable law, ${BrandConfig.parentBrand}, ${BrandConfig.appName} '
        'and their team shall not be liable for any indirect, incidental, special, consequential, or punitive '
        'loss, or any loss of profit, data, or goodwill, arising from the Service or any ride; and our total '
        'aggregate liability, where liability cannot be excluded, shall be limited to the maximum extent the '
        'law allows. You agree to indemnify and hold us harmless from claims, damages, losses, or expenses '
        'arising out of your use of the Service, your rides, or your breach of these terms — subject to the '
        'mandatory rights you have under applicable law that cannot be waived.',
  ),
  (
    title: '17. Periodic rating review & action',
    body:
        'To keep the community safe and reliable, we may review user ratings and conduct on a periodic basis '
        '(for example monthly or every six months). Users — including drivers, unions, and passengers — with '
        'persistently low ratings, repeated complaints, no-shows, or policy breaches may be warned, '
        'temporarily restricted, suspended, de-listed, or removed from the Service, at our reasonable '
        'discretion and subject to applicable law. We aim to act fairly but do not guarantee any particular '
        'outcome.',
  ),
  (
    title: '18. Force majeure',
    body:
        'We are not responsible for any failure or delay caused by events beyond our reasonable control, '
        'including natural disasters, weather, landslides, strikes, network or power outages, government '
        'action, or other force-majeure events.',
  ),
  (
    title: '19. Intermediary status & not legal advice',
    body:
        '${BrandConfig.appName} acts only as an intermediary / technology marketplace that connects users; it '
        'is not the provider of the transport service and is not a party to the agreement between passenger '
        'and driver. These terms are a plain-language summary for users and are not legal advice; where they '
        'conflict with mandatory Indian law (including consumer-protection and intermediary rules), the law '
        'prevails. For grievances, contact us via Help / ${BrandConfig.grievContactEmail}.',
  ),
  (
    title: '20. Eligibility & capacity',
    body:
        'You must be at least 18 years old and legally competent to enter into a contract under the Indian '
        'Contract Act, 1872 to use the Service. By using it you confirm that you meet these requirements and '
        'that the information you provide is true. Accounts found to belong to minors or created with false '
        'information may be suspended or removed.',
  ),
  (
    title: '21. No employment or agency relationship',
    body:
        'Drivers, vehicle owners, and unions are independent third parties. Nothing in these terms creates any '
        'employment, agency, partnership, joint venture, or principal–agent relationship between them and '
        '${BrandConfig.parentBrand} or ${BrandConfig.appName}. They are not our employees or agents, they act '
        'on their own account, and we do not control how they provide rides. We are therefore not vicariously '
        'liable for their acts or omissions, to the fullest extent permitted by law.',
  ),
  (
    title: '22. Prohibited use & conduct',
    body:
        'You must not use the Service to: carry or transport illegal goods, weapons, drugs, or anything banned '
        'by law; transport persons against their will or for trafficking; harass, threaten, stalk, or abuse '
        'anyone; impersonate others or use fake identity, documents, or vehicle details; overload beyond legal '
        'seating capacity; or break any traffic, transport, or other law. Violation may lead to immediate '
        'suspension or removal and may be reported to the authorities.',
  ),
  (
    title: '23. Taxes & legal compliance',
    body:
        'Each user is responsible for their own taxes, levies, permits, and legal compliance arising from '
        'their use of the Service or any ride (for example a driver\'s own income tax, GST if applicable, and '
        'transport permits). ${BrandConfig.parentBrand} and ${BrandConfig.appName} do not collect or remit '
        'taxes on behalf of users and give no tax advice.',
  ),
  (
    title: '24. Your data rights (DPDP Act 2023)',
    body:
        'We process your personal data in line with the Digital Personal Data Protection Act, 2023 and other '
        'applicable Indian law. We use your data only for operating and supporting the Service, on the basis '
        'of your consent or as the law permits. Subject to law, you may request access, correction, or '
        'erasure of your personal data, and you may withdraw consent, by contacting us via Help / '
        '${BrandConfig.grievContactEmail}. We apply reasonable security safeguards and a separate privacy '
        'notice may give further detail.',
  ),
  (
    title: '25. Severability & entire agreement',
    body:
        'If any part of these terms is held invalid or unenforceable, the rest continues in full force. A '
        'delay in enforcing any right is not a waiver of it. These terms (with any privacy notice and in-app '
        'policies referenced here) are the entire agreement between you and us regarding the Service and '
        'replace earlier understandings, except for rights that mandatory law gives you.',
  ),
  (
    title: '26. Grievance officer',
    body:
        'In line with applicable Indian law, our Grievance Officer is Rahul Panwar. You can raise any '
        'grievance, complaint, or concern about the Service, content, or your data through Help in the app or '
        'by writing to ${BrandConfig.grievContactEmail}. We will acknowledge your grievance and aim to resolve '
        'it within 10 to 20 days at most; urgent safety matters are prioritised. Please include enough detail '
        '(your contact, the issue, and any ride or booking reference) so we can assist you quickly.',
  ),
];

final List<({String title, String body})> _termsHi = [
  (
    title: '0. बीटा सॉफ़्टवेयर',
    body:
        'यह ऐप बीटा या पूर्व-रिलीज़ के रूप में हो सकता है। सुविधाएँ बदल या अस्थायी रूप से अनुपलब्ध हो सकती हैं। '
        'बीटा के दौरान आप अपने जोखिम पर सेवा का उपयोग करते हैं। समस्या हो तो सहायता के माध्यम से बताएँ। '
        'उपयोग जारी रखने का अर्थ है कि आप इसे स्वीकार करते हैं।',
  ),
  (
    title: '1. हम कौन हैं',
    body:
        '"${BrandConfig.appName}" मोबाइल ऐप और संबंधित ऑनलाइन सेवाएँ ("सेवा") ${BrandConfig.parentBrand} ब्रांड के '
        'तहत पेश की जाती हैं। ${BrandConfig.appName} एक तकनीकी मंच है जो यात्रियों और ड्राइवरों को उत्तराखंड '
        'और आसपास के क्षेत्रों में साझा या निर्धारित यात्राओं के लिए जोड़ने में मदद करता है। हम वाहन के '
        'मालिक या संचालक नहीं हैं और टैक्सी कंपनी नहीं हैं, जब तक स्पष्ट रूप से अन्यथा न कहा गया हो।',
  ),
  (
    title: '2. मंच की भूमिका और दायित्व',
    body:
        'ड्राइवर और यूनियन स्वतंत्र तृतीय पक्ष हैं। लाइसेंस, परमिट, बीमा, वाहन की स्थिति और यातायात कानूनों का '
        'पालन उनकी ज़िम्मेदारी है। लागू कानून द्वारा अनुमत पूर्ण सीमा तक, ${BrandConfig.parentBrand}, '
        '${BrandConfig.appName} और उनके प्रतिनिधि यात्रा के दौरान या बाद में दुर्घटना, देरी, हानि, चोट या '
        'उपयोगकर्ताओं के बीच विवादों के लिए उत्तरदायी नहीं हैं, सिवाय जहाँ कानून बहिष्करण की अनुमति नहीं देता।',
  ),
  (
    title: '3. आपकी ज़िम्मेदारियाँ',
    body:
        'सही प्रोफ़ाइल जानकारी दें। उत्पीड़न, दुरुपयोग या गैरकानूनी गतिविधि न करें। पहचान या वाहन विवरण गलत '
        'न बताएँ। बुकिंग का सम्मान करें; बार-बार न आने या दुरुपयोग पर प्रतिबंध लग सकता है।',
  ),
  (
    title: '4. ड्राइवर और यूनियन की ज़िम्मेदारियाँ',
    body:
        'वैध ड्राइविंग लाइसेंस, आरसी, बीमा और कानून अनुसार परमिट बनाए रखें। कानूनी बैठने की क्षमता से अधिक '
        'यात्री न लें। सुरक्षित चलाएँ। ऐप में दिखाए गए मार्ग, किराया या वाहन डेटा गलत न बताएँ।',
  ),
  (
    title: '5. बुकिंग, रद्दीकरण और न आना',
    body:
        'वास्तविक स्थिति में कोई भी पक्ष यात्रा रद्द कर सकता है। ड्राइवर यात्रा बनाने या स्वीकार करने के बाद उसे '
        'शुरू न करे, न पहुँचे या पूरा न करे, और यात्री भी न आए—ऐसा हो सकता है। ${BrandConfig.appName} केवल जोड़ने '
        'का माध्यम है: यह सवारी संचालित नहीं करता और गारंटी नहीं देता कि कोई यात्रा होगी, समय पर शुरू/चलेगी या '
        'पूरी होगी। कानून द्वारा अनुमत पूर्ण सीमा तक, रद्दीकरण, न आने, देरी, या ड्राइवर के न ले जाने से हुई हानि, '
        'छूटे संपर्क, अतिरिक्त खर्च, प्रतीक्षा या असुविधा के लिए हम ज़िम्मेदार नहीं हैं, और हम कोई मुआवज़ा या रिफ़ंड '
        'नहीं देते। ऐसे मामले सीधे दूसरे पक्ष से सुलझाएँ। जहाँ तक संभव हो ऐप में सूचनाएँ भेजी जा सकती हैं, और '
        'बार-बार रद्द करने, न आने, दुरुपयोग, धोखाधड़ी या सुरक्षा चिंता पर हम खाते को चेतावनी, सीमित या निलंबित कर सकते हैं।',
  ),
  (
    title: '6. भुगतान — प्लेटफ़ॉर्म पैसा नहीं रखता',
    body:
        '${BrandConfig.parentBrand} और ${BrandConfig.appName} यात्री और ड्राइवर के बीच किराये का पैसा एकत्र, '
        'रखते या ट्रांसफ़र नहीं करते। सेवा केवल जोड़ने का माध्यम है: उपयोगकर्ता एक दूसरे को ढूँढकर यात्रा '
        'तय कर सकें। कैसे भुगतान करें (कैश, UPI आदि), कितना दें, और किराए पर सहमति—यह पूरी तरह आप और दूसरे '
        'उपयोगकर्ता के बीच है, आपसी बातचीत के बाद। हम भुगतान, रिफ़ंड या समय की गारंटी नहीं देते। अगर भुगतान '
        'से जुड़ा विवाद, हानि, धोखाधड़ी या गलत लेन-देन हो—जैसे अदा न करना, ज़्यादा लेना या ठगी—तो प्लेटफ़ॉर्म '
        'किसी भी ज़िम्मेदारी को स्वीकार नहीं करता, जहाँ तक कानून अनुमति दे। सुरक्षा या दुरुपयोग की रिपोर्ट '
        'सहायता से करें; भुगतान विवाद उपयोगकर्ताओं के बीच या कानूनी मार्ग से सुलझाने होंगे।',
  ),
  (
    title: '7. बौद्धिक संपदा और सॉफ़्टवेयर',
    body:
        '${BrandConfig.appName} सेवा का मूल स्रोत कोड, समग्र तंत्र वास्तुकला (architecture), बैक-एंड और '
        'एप्लिकेशन लॉजिक, डेटा मॉडल, व्यावसायिक नियम, बुकिंग व संचालन वर्कफ़्लो, एकीकरण, दृश्य डिज़ाइन, '
        'ब्रांडिंग और उपयोगकर्ता अनुभव—जैसा ${BrandConfig.parentBrand} ने डिज़ाइन, कार्यान्वयन और संचालन किया '
        'है—${BrandConfig.parentBrand} या उसके लाइसेंसदाताओं का मालिकाना है। यह तय करना कि ये भाग कैसे जुड़ते हैं, '
        'प्लेटफ़ॉर्म कैसे चले और उत्पाद व व्यावसायिक दृष्टि से सवारी कैसे समन्वित हों, हमारी ज़िम्मेदारी है; '
        'यह सेवा किसी अन्य विक्रेता का व्हाइट-लेबल या तैयार-पैक उत्पाद नहीं है जिसे हम केवल पुनर्विक्रय करें। '
        'हमारा कार्यान्वयन व्यापक रूप से उपयोग किए जाने वाले औज़ारों और प्लेटफ़ॉर्म पर निर्भर हो सकता है, '
        'जिनमें उदाहरण के लिए Flutter जैसे मोबाइल फ़्रेमवर्क, Node.js जैसे सर्वर रनटाइम, PostgreSQL जैसा डेटाबेस, '
        'nginx जैसा रिवर्स प्रॉक्सी या वेब सर्वर, PM2 जैसा प्रोसेस सुपरवाइज़र और अन्य तृतीय-पक्ष व ओपन-सोर्स '
        'लाइब्रेरी शामिल हो सकती हैं; वास्तविक स्टैक समय के साथ बदल सकता है। उन औज़ारों के लेखक व लाइसेंसदाता '
        'अपनी सामग्री में अपनी लाइसेंसों के अधीन अपने अधिकार रखते हैं; हम जिन घटकों का उपयोग करते हैं, उन पर '
        'लागू लाइसेंस दायित्वों का पालन करते हैं, और जहाँ कोई लाइसेंस हमारे द्वारा आपको दी गई सामग्री पर लागू हो, '
        'उस वस्तु के लिए आपको वह लाइसेंस मानना होगा। '
        'इससे यह नहीं बदलता कि समग्र ${BrandConfig.appName} कार्यान्वयन, जैसा हम पेश करते हैं, हमारा मालिकाना '
        'उत्पाद है। कानून या हमारी लिखित सहमति के अलावा हमारे सॉफ़्टवेयर या ब्रांडिंग की नकल, रिवर्स '
        'इंजीनियरिंग, स्क्रैपिंग या दुरुपयोग न करें।',
  ),
  (
    title: '8. डेटा और गोपनीयता',
    body:
        'सेवा चलाने के लिए सीमित व्यक्तिगत डेटा (नाम, फ़ोन, यात्रा इतिहास आदि) संसाधित करते हैं। व्यक्तिगत '
        'डेटा बेचते नहीं। अलग गोपनीयता नोटिस लागू हो सकता है; संचालन और सहायता के लिए उचित प्रसंस्करण स्वीकार '
        'करके ही सेवा का उपयोग करें। '
        'सहायता / शिकायत: ${BrandConfig.grievContactEmail} पर लिखें। '
        'सत्यापन व केआईसी दस्तावेज़ सुरक्षित सर्वर पर रखे जाते हैं; जब तक खाता सक्रिय है और कानून/सत्यापन '
        'के लिए ज़रूरी है, तब तक ही रखते हैं। खाता बंद होने के बाद जहाँ तक कानून अनुमति दे, उचित समय में '
        'हटा देते या अनाम कर देते हैं। दस्तावेज़ बेचते नहीं।',
  ),
  (
    title: '9. खाता निलंबन',
    body:
        'इन नियमों का उल्लंघन, धोखाधड़ी, सुरक्षा जोखिम या कानूनी आवश्यकता पर हम पहुँच निलंबित या समाप्त कर '
        'सकते हैं, लागू कानून के अधीन।',
  ),
  (
    title: '10. परिवर्तन',
    body:
        'हम इन नियमों को अपडेट कर सकते हैं। महत्वपूर्ण बदलाव जहाँ व्यावहारिक हो ऐप में दिखाए जाएँगे। अपडेट के '
        'बाद उपयोग जारी रखने का अर्थ है स्वीकृति, जब तक कानून अन्यथा न कहे।',
  ),
  (
    title: '11. लागू कानून और विवाद',
    body:
        'ये नियम भारत के कानूनों के अधीन हैं। देहरादून, उत्तराखंड की अदालतों को विशेष अधिकार क्षेत्र प्राप्त है '
        '(कानून द्वारा आवश्यक उपभोक्ता सुरक्षा के अधीन)।',
  ),
  (
    title: '12. रेटिंग और समीक्षाएँ',
    body:
        'ऐप में दिखाई गई रेटिंग और समीक्षाएँ उपयोगकर्ताओं (यात्री व ड्राइवर) द्वारा यात्रा के बाद दिए गए फ़ीडबैक से '
        'बनती हैं। ये केवल उपयोगकर्ताओं की राय दर्शाती हैं और ${BrandConfig.parentBrand} या ${BrandConfig.appName} '
        'द्वारा किसी ड्राइवर, यात्री, वाहन या सवारी का समर्थन, प्रमाणन या गारंटी नहीं हैं। ड्राइवर को इन्हीं '
        'उपयोगकर्ता समीक्षाओं व रेटिंग के आधार पर रेट किया जाता है। हम इस फ़ीडबैक का उपयोग खातों को रैंक करने, '
        'दिखाने, सीमित करने, निलंबित या हटाने के लिए कर सकते हैं, पर इसकी सटीकता की गारंटी नहीं देते और इसके आधार '
        'पर आपके निर्णयों के लिए ज़िम्मेदार नहीं हैं।',
  ),
  (
    title: '13. जोखिम की स्वीकृति — दुर्घटना, चोट, बीमारी या मृत्यु',
    body:
        'सड़क यात्रा में स्वाभाविक जोखिम होते हैं। सेवा का उपयोग कर सवारी ढूँढने या साझा करने पर आप ये सभी जोखिम '
        'जानबूझकर और स्वेच्छा से स्वीकार करते हैं। कानून द्वारा अनुमत पूर्ण सीमा तक, ${BrandConfig.parentBrand} '
        'और ${BrandConfig.appName} सेवा के माध्यम से तय की गई किसी भी सवारी से पहले, दौरान या बाद में किसी भी '
        'व्यक्ति (यात्री, ड्राइवर, सह-यात्री या तृतीय पक्ष) को हुई दुर्घटना, टक्कर, चोट, विकलांगता, बीमारी, '
        'मृत्यु, चिकित्सा आपात या संपत्ति की हानि के लिए ज़िम्मेदार नहीं हैं। वाहन, उसकी स्थिति, वैध बीमा, '
        'सुरक्षित ड्राइविंग और यात्रा के परिणामों की पूरी ज़िम्मेदारी ड्राइवर और/या वाहन मालिक की है। हम सवारी, '
        'दुर्घटना या जीवन बीमा नहीं देते; पर्याप्त बीमा की व्यवस्था ड्राइवर की ज़िम्मेदारी है। आपात स्थिति में '
        'सीधे आपातकालीन सेवाओं (जैसे 112) से संपर्क करें।',
  ),
  (
    title: '14. अपराध, धोखाधड़ी और सुरक्षा',
    body:
        'किसी उपयोगकर्ता द्वारा दूसरे के साथ की गई धोखाधड़ी, चोरी, ठगी, उत्पीड़न, हमला, दुर्व्यवहार, पहचान का '
        'गलत इस्तेमाल या किसी अन्य गैरकानूनी/आपराधिक कृत्य के लिए हम ज़िम्मेदार नहीं हैं और कोई दायित्व स्वीकार '
        'नहीं करते। ऐसे मामले संबंधित व्यक्तियों और अधिकारियों के बीच हैं। अपराध की रिपोर्ट पुलिस को और गंभीर '
        'सुरक्षा/दुरुपयोग की रिपोर्ट हमें सहायता के ज़रिए करें। हम सद्भावपूर्वक और कानून के अनुसार कानून-प्रवर्तन '
        'या अन्य अधिकारियों के साथ सहयोग व जानकारी साझा कर सकते हैं। हमेशा अपनी समझ से काम लें, व्यक्ति व वाहन '
        'जाँचें और अपनी सुरक्षा को प्राथमिकता दें।',
  ),
  (
    title: '15. सत्यापन की सीमाएँ और सेवा "जैसी है"',
    body:
        'हम ड्राइवर और यूनियन को सूचीबद्ध करने से पहले यथासंभव (जैसे दस्तावेज़ और केवाईसी से) सत्यापित करते हैं '
        'और पूरी कोशिश करते हैं। पर कोई सत्यापन पूर्ण या गारंटीशुदा नहीं हो सकता, पहचान/दस्तावेज़ों का दुरुपयोग '
        'हो सकता है और सत्यापन के बाद परिस्थितियाँ बदल सकती हैं—इसलिए हम किसी ड्राइवर, यूनियन या वाहन की पहचान, '
        'आचरण या सुरक्षा की 100% गारंटी नहीं देते और न दे सकते हैं। यात्रियों का वैसा दस्तावेज़ सत्यापन नहीं होता, '
        'और हर उपयोगकर्ता का पूर्ण सत्यापन कभी भी 100% संभव नहीं हो सकता। सेवा कानून द्वारा अनुमत सीमा तक '
        '"जैसी है" और "जैसी उपलब्ध है" आधार पर, बिना किसी वारंटी के दी जाती है। किसी भी सवारी से पहले और दौरान '
        'उचित सावधानी रखना आपकी ज़िम्मेदारी है।',
  ),
  (
    title: '16. दायित्व की सीमा और क्षतिपूर्ति',
    body:
        'लागू कानून द्वारा अनुमत पूर्ण सीमा तक, ${BrandConfig.parentBrand}, ${BrandConfig.appName} और उनकी टीम '
        'किसी अप्रत्यक्ष, आकस्मिक, विशेष या परिणामी हानि, या लाभ/डेटा/साख की हानि के लिए ज़िम्मेदार नहीं होंगे; '
        'और जहाँ दायित्व बाहर नहीं किया जा सकता, हमारा कुल दायित्व कानून द्वारा अनुमत अधिकतम सीमा तक ही सीमित '
        'रहेगा। सेवा के उपयोग, आपकी सवारियों, या इन नियमों के उल्लंघन से उत्पन्न दावों/हानि/खर्च से आप हमें '
        'क्षतिपूर्ति देने और सुरक्षित रखने को सहमत हैं—उन अनिवार्य अधिकारों के अधीन जो कानूनन छोड़े नहीं जा सकते।',
  ),
  (
    title: '17. आवधिक रेटिंग समीक्षा और कार्रवाई',
    body:
        'समुदाय को सुरक्षित व भरोसेमंद रखने के लिए हम समय-समय पर (जैसे मासिक या हर छह माह) उपयोगकर्ताओं की '
        'रेटिंग और आचरण की समीक्षा कर सकते हैं। लगातार कम रेटिंग, बार-बार शिकायत, न आने या नियम-उल्लंघन वाले '
        'उपयोगकर्ता—ड्राइवर, यूनियन या यात्री—को हमारे उचित विवेक पर और कानून के अधीन चेतावनी, अस्थायी रोक, '
        'निलंबन, सूची से हटाना या सेवा से हटाया जा सकता है। हम निष्पक्ष रहने का प्रयास करते हैं पर किसी विशेष '
        'परिणाम की गारंटी नहीं देते।',
  ),
  (
    title: '18. अप्रत्याशित घटनाएँ (Force Majeure)',
    body:
        'हमारे उचित नियंत्रण से बाहर की घटनाओं—प्राकृतिक आपदा, मौसम, भूस्खलन, हड़ताल, नेटवर्क/बिजली बाधा, '
        'सरकारी कार्रवाई आदि—से हुई विफलता या देरी के लिए हम ज़िम्मेदार नहीं हैं।',
  ),
  (
    title: '19. मध्यस्थ भूमिका और कानूनी सलाह नहीं',
    body:
        '${BrandConfig.appName} केवल एक मध्यस्थ / तकनीकी मंच है जो उपयोगकर्ताओं को जोड़ता है; यह परिवहन सेवा का '
        'प्रदाता नहीं है और यात्री-ड्राइवर के बीच समझौते का पक्ष नहीं है। ये नियम उपयोगकर्ताओं के लिए सरल भाषा '
        'का सारांश हैं, कानूनी सलाह नहीं; जहाँ ये अनिवार्य भारतीय कानून (उपभोक्ता-संरक्षण व मध्यस्थ नियमों सहित) '
        'से टकराएँ, वहाँ कानून मान्य होगा। शिकायत के लिए सहायता / ${BrandConfig.grievContactEmail} पर संपर्क करें।',
  ),
  (
    title: '20. पात्रता और क्षमता',
    body:
        'सेवा का उपयोग करने के लिए आपकी आयु कम से कम 18 वर्ष होनी चाहिए और आप भारतीय अनुबंध अधिनियम, 1872 के '
        'तहत अनुबंध करने योग्य होने चाहिए। उपयोग करके आप पुष्टि करते हैं कि आप ये शर्तें पूरी करते हैं और दी गई '
        'जानकारी सही है। नाबालिग के या गलत जानकारी से बने खाते निलंबित या हटाए जा सकते हैं।',
  ),
  (
    title: '21. कोई नौकरी या एजेंसी संबंध नहीं',
    body:
        'ड्राइवर, वाहन मालिक और यूनियन स्वतंत्र तृतीय पक्ष हैं। इन नियमों से उनके और ${BrandConfig.parentBrand} '
        'या ${BrandConfig.appName} के बीच कोई नौकरी, एजेंसी, साझेदारी, संयुक्त उद्यम या प्रिंसिपल–एजेंट संबंध '
        'नहीं बनता। वे हमारे कर्मचारी या एजेंट नहीं हैं, अपने हिसाब से काम करते हैं, और हम यह नियंत्रित नहीं '
        'करते कि वे सवारी कैसे देते हैं। इसलिए कानून द्वारा अनुमत पूर्ण सीमा तक उनके कृत्यों/चूक के लिए हम '
        'परोक्ष रूप से (vicariously) ज़िम्मेदार नहीं हैं।',
  ),
  (
    title: '22. वर्जित उपयोग और आचरण',
    body:
        'आप सेवा का उपयोग इनके लिए नहीं करेंगे: अवैध सामान, हथियार, नशीले पदार्थ या कानून द्वारा प्रतिबंधित कुछ '
        'भी ले जाना; किसी को उसकी मर्ज़ी के विरुद्ध या तस्करी के लिए ले जाना; किसी को परेशान, धमकाना, पीछा करना '
        'या दुर्व्यवहार करना; किसी की झूठी पहचान/दस्तावेज़/वाहन विवरण का इस्तेमाल; कानूनी बैठक क्षमता से अधिक '
        'भरना; या किसी यातायात/परिवहन/अन्य कानून का उल्लंघन। उल्लंघन पर तुरंत निलंबन या हटाया जाना हो सकता है '
        'और अधिकारियों को सूचित किया जा सकता है।',
  ),
  (
    title: '23. कर और कानूनी अनुपालन',
    body:
        'सेवा या किसी सवारी से उत्पन्न अपने करों, शुल्कों, परमिट और कानूनी अनुपालन के लिए हर उपयोगकर्ता स्वयं '
        'ज़िम्मेदार है (जैसे ड्राइवर का अपना आयकर, लागू हो तो जीएसटी, और परिवहन परमिट)। ${BrandConfig.parentBrand} '
        'और ${BrandConfig.appName} उपयोगकर्ताओं की ओर से कर एकत्र या जमा नहीं करते और कोई कर-सलाह नहीं देते।',
  ),
  (
    title: '24. आपके डेटा अधिकार (DPDP अधिनियम 2023)',
    body:
        'हम आपके व्यक्तिगत डेटा को डिजिटल पर्सनल डेटा प्रोटेक्शन अधिनियम, 2023 और अन्य लागू भारतीय कानून के '
        'अनुसार संसाधित करते हैं। डेटा का उपयोग केवल सेवा चलाने व सहायता के लिए, आपकी सहमति या कानून की अनुमति '
        'के आधार पर करते हैं। कानून के अधीन, आप अपने डेटा तक पहुँच, सुधार या मिटाने का अनुरोध कर सकते हैं और '
        'सहमति वापस ले सकते हैं—सहायता / ${BrandConfig.grievContactEmail} पर संपर्क करके। हम उचित सुरक्षा उपाय '
        'अपनाते हैं और अलग गोपनीयता नोटिस में अधिक विवरण हो सकता है।',
  ),
  (
    title: '25. पृथक्करणीयता और सम्पूर्ण अनुबंध',
    body:
        'यदि इन नियमों का कोई भाग अमान्य या अप्रवर्तनीय पाया जाए, तो शेष पूरी तरह लागू रहेगा। किसी अधिकार को '
        'लागू करने में देरी उसका त्याग नहीं है। ये नियम (यहाँ संदर्भित गोपनीयता नोटिस व इन-ऐप नीतियों सहित) '
        'सेवा के संबंध में आपके और हमारे बीच सम्पूर्ण अनुबंध हैं और पूर्व समझ को प्रतिस्थापित करते हैं, सिवाय '
        'उन अधिकारों के जो अनिवार्य कानून आपको देता है।',
  ),
  (
    title: '26. शिकायत अधिकारी (Grievance Officer)',
    body:
        'लागू भारतीय कानून के अनुसार, हमारे शिकायत अधिकारी राहुल पंवार हैं। सेवा, सामग्री या अपने डेटा से जुड़ी '
        'कोई भी शिकायत या चिंता आप ऐप में सहायता के ज़रिए या ${BrandConfig.grievContactEmail} पर लिखकर दर्ज कर '
        'सकते हैं। हम आपकी शिकायत प्राप्ति की पुष्टि करेंगे और अधिकतम 10 से 20 दिनों में उसका समाधान करने का '
        'प्रयास करेंगे; आपात/सुरक्षा मामलों को प्राथमिकता दी जाती है। कृपया पर्याप्त विवरण दें (आपका संपर्क, '
        'समस्या, और कोई सवारी/बुकिंग संदर्भ) ताकि हम जल्दी मदद कर सकें।',
  ),
];

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<AppLanguageProvider>().language;
    final loc = AppLocalizations(lang);
    final sections = _termsSections(lang);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.t('terms.title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            LegalDocumentInfo.termsSummaryLine,
            style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          for (final s in sections) ...[
            Text(
              s.title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              s.body,
              style: TextStyle(fontSize: 14, height: 1.45, color: Colors.grey[900]),
            ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}
