import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/brand_config.dart';
import '../../core/legal_document_info.dart';
import '../../core/localization/app_localizations.dart';
import '../../providers/app_language_provider.dart';

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
    title: '5. Bookings & cancellations',
    body:
        'Trips may be cancelled by either party in genuine situations. We may send in-app notifications where '
        'technically possible. Frequent misuse, fraud, or safety concerns may result in suspension.',
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
    title: '5. बुकिंग और रद्दीकरण',
    body:
        'वास्तविक स्थिति में कोई भी पक्ष यात्रा रद्द कर सकता है। जहाँ तक संभव हो सूचनाएँ ऐप के माध्यम से भेजी '
        'जा सकती हैं। बार-बार दुरुपयोग, धोखाधड़ी या सुरक्षा चिंता पर निलंबन हो सकता है।',
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
];

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<AppLanguageProvider>();
    final loc = AppLocalizations.of(context);
    final sections = _termsSections(context.read<AppLanguageProvider>().language);

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
          Text(
            loc.t('terms.disclaimer'),
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
