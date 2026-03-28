import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../brand_config.dart';
import '../../providers/app_language_provider.dart';

/// Very lightweight key-based localization for English & Hindi.
class AppLocalizations {
  final AppLanguageCode code;

  AppLocalizations(this.code);

  /// Landing footer line for parent company — spelling always from [BrandConfig.parentBrand] (TECHMCU).
  String get brandFooterParentLine {
    if (code == AppLanguageCode.hi) {
      return '${BrandConfig.parentBrand} द्वारा प्रस्तुत';
    }
    return 'A ${BrandConfig.parentBrand} product';
  }

  static AppLocalizations of(BuildContext context) {
    // Use listen: false so we can safely call from event handlers (onTap, etc.).
    // MaterialApp already rebuilds on language change via AppLanguageProvider.
    final lang = Provider.of<AppLanguageProvider>(context, listen: false).language;
    return AppLocalizations(lang);
  }

  String get _lang => code == AppLanguageCode.hi ? 'hi' : 'en';

  static const Map<String, Map<String, String>> _values = {
    'input.email.label': {
      'en': 'Email',
      'hi': 'ईमेल',
    },
    'input.email.placeholder': {
      'en': 'Enter your email',
      'hi': 'अपना ईमेल दर्ज करें',
    },
    'ride.from.label': {
      'en': 'From',
      'hi': 'कहाँ से',
    },
    'ride.to.label': {
      'en': 'To',
      'hi': 'कहाँ तक',
    },
    'ride.from.placeholder': {
      'en': 'Enter starting location',
      'hi': 'कहाँ से चलना है',
    },
    'ride.to.placeholder': {
      'en': 'Enter destination',
      'hi': 'कहाँ तक जाना है',
    },
    'app.profile.title': {
      'en': 'Profile',
      'hi': 'प्रोफ़ाइल',
    },
    'app.menu.language': {
      'en': 'Language',
      'hi': 'भाषा',
    },
    'app.menu.language.subtitle': {
      'en': 'Choose app language',
      'hi': 'ऐप की भाषा चुनें',
    },
    'app.language.english': {
      'en': 'English',
      'hi': 'अंग्रेज़ी',
    },
    'app.language.hindi': {
      'en': 'Hindi',
      'hi': 'हिन्दी',
    },
    'app.language.saved': {
      'en': 'Language updated',
      'hi': 'भाषा अपडेट हो गई',
    },
    'profile.section.union': {
      'en': 'For taxi union (admins)',
      'hi': 'टैक्सी यूनियन (एडमिन) के लिए',
    },
    'profile.section.driver': {
      'en': 'For independent taxi driver',
      'hi': 'स्वतंत्र टैक्सी ड्राइवर के लिए',
    },
    'union.register.title': {
      'en': 'Add your union',
      'hi': 'अपनी यूनियन जोड़ें',
    },
    'union.warning.title': {
      'en': 'Important',
      'hi': 'महत्वपूर्ण',
    },
    'exclusivity.union_blocked.title': {
      'en': 'Not available',
      'hi': 'उपलब्ध नहीं',
    },
    'exclusivity.union_blocked.body': {
      'en':
          'You already use the independent driver path (pending or approved). Union registration is not available on this account.',
      'hi':
          'आप पहले से स्वतंत्र ड्राइवर मार्ग का उपयोग कर रहे हैं (लंबित या स्वीकृत)। इस खाते पर यूनियन पंजीकरण उपलब्ध नहीं है।',
    },
    'exclusivity.driver_blocked.title': {
      'en': 'Not available',
      'hi': 'उपलब्ध नहीं',
    },
    'exclusivity.driver_blocked.body': {
      'en':
          'You already use the union path (pending or approved). Independent driver verification is not available on this account.',
      'hi':
          'आप पहले से यूनियन मार्ग का उपयोग कर रहे हैं (लंबित या स्वीकृत)। इस खाते पर स्वतंत्र ड्राइवर सत्यापन उपलब्ध नहीं है।',
    },
    'exclusivity.union_blocked.subtitle': {
      'en': 'Tap for details — driver path is active on this account.',
      'hi': 'जानकारी के लिए टैप करें — इस खाते पर ड्राइवर मार्ग सक्रिय है।',
    },
    'exclusivity.driver_blocked.subtitle': {
      'en': 'Tap for details — union path is active on this account.',
      'hi': 'जानकारी के लिए टैप करें — इस खाते पर यूनियन मार्ग सक्रिय है।',
    },
    'brand.footer.app_line': {
      'en': 'LuhaRide',
      'hi': 'LuhaRide',
    },
    'brand.footer.tagline': {
      'en': 'Safe • Legal • Reliable',
      'hi': 'सुरक्षित • वैध • विश्वसनीय',
    },
    'profile.beta.banner': {
      'en':
          'Beta: We are still improving the app. If something breaks, please tell us via Help — thank you for your patience.',
      'hi':
          'बीटा: हम ऐप को अभी भी बेहतर बना रहे हैं। अगर कोई समस्या हो तो सहायता से बताएँ — धैर्य के लिए धन्यवाद।',
    },
    'union.list.subtitle': {
      'en': 'Register your taxi union on LuhaRide',
      'hi': 'LuhaRide पर अपनी टैक्सी यूनियन पंजीकृत करें',
    },
    'driver.promo.title_new': {
      'en': 'Drive with LuhaRide',
      'hi': 'LuhaRide के साथ ड्राइव करें',
    },
    'union.warning.body': {
      'en':
          'Only authorised union representatives should apply. False or misleading information may lead to account restrictions. By continuing you confirm you are eligible.',
      'hi':
          'केवल अधिकृत यूनियन प्रतिनिधि ही आवेदन करें। गलत या भ्रामक जानकारी पर खाते पर प्रतिबंध लग सकता है। आगे बढ़कर आप पुष्टि करते हैं कि आप योग्य हैं।',
    },
    'union.pending.title': {
      'en': 'Application under review',
      'hi': 'आवेदन समीक्षा में',
    },
    'union.pending.body': {
      'en':
          'Your union registration has been received. Our team usually reviews within 24–48 hours. Use “Check status” after some time.\n\nIf it takes longer, email us at supportluharide@gmail.com with your union name and phone in the subject line.',
      'hi':
          'आपका यूनियन पंजीकरण प्राप्त हो गया है। हमारी टीम आमतौर पर 24–48 घंटे में जाँच करती है। कुछ समय बाद “स्थिति देखें” दबाएँ।\n\nअगर और देर हो, तो supportluharide@gmail.com पर यूनियन नाम और फ़ोन विषय में लिखकर ईमेल करें।',
    },
    'union.pending.check': {
      'en': 'Check status',
      'hi': 'स्थिति देखें',
    },
    'union.pending.checking': {
      'en': 'Checking…',
      'hi': 'जाँच हो रही है…',
    },
    'union.pending.name_placeholder': {
      'en': 'Your taxi union',
      'hi': 'आपकी टैक्सी यूनियन',
    },
    'profile.verify.dialog_title': {
      'en': 'Verification required',
      'hi': 'सत्यापन आवश्यक',
    },
    'profile.verify.pending_body': {
      'en':
          'Your driver verification is pending. We usually review within 24–48 hours.\n\nIf it takes longer, email supportluharide@gmail.com with your name and phone in the subject line.',
      'hi':
          'आपका ड्राइवर सत्यापन लंबित है। हम आमतौर पर 24–48 घंटे में जाँच करते हैं।\n\nअगर देर हो, तो supportluharide@gmail.com पर नाम और फ़ोन विषय में लिखकर ईमेल करें।',
    },
    'profile.verify.need_docs': {
      'en': 'Please complete document verification before creating rides.',
      'hi': 'राइड बनाने से पहले कृपया दस्तावेज़ सत्यापन पूरा करें।',
    },
    'profile.prereq.title': {
      'en': 'Complete your profile first',
      'hi': 'पहले प्रोफ़ाइल पूरी करें',
    },
    'profile.prereq.body': {
      'en':
          'Independent driver verification is for genuine taxi operators.\n\nPlease add your profile photo, email and a correct phone number before submitting documents. Misuse may lead to account suspension.',
      'hi':
          'स्वतंत्र ड्राइवर सत्यापन वास्तविक टैक्सी संचालकों के लिए है।\n\nदस्तावेज़ जमा करने से पहले प्रोफ़ाइल फोटो, ईमेल और सही फ़ोन नंबर जोड़ें। दुरुपयोग पर खाता निलंबित हो सकता है।',
    },
    'profile.share.create_title': {
      'en': 'Create a ride',
      'hi': 'राइड बनाएँ',
    },
    'profile.share.sub.approved': {
      'en': 'Post a new trip',
      'hi': 'नई यात्रा पोस्ट करें',
    },
    'profile.share.sub.pending': {
      'en': 'Verification pending',
      'hi': 'सत्यापन लंबित',
    },
    'profile.share.sub.need_verify': {
      'en': 'Verify to create rides',
      'hi': 'राइड के लिए सत्यापन करें',
    },
    'help.title': {
      'en': 'Help & FAQs',
      'hi': 'सहायता व प्रश्न',
    },
    'help.faq.title': {
      'en': 'Frequently asked questions',
      'hi': 'अक्सर पूछे जाने वाले प्रश्न',
    },
    'help.faq.book.q': {
      'en': 'How do I book a ride?',
      'hi': 'राइड कैसे बुक करूँ?',
    },
    'help.faq.book.a': {
      'en':
          'Enter From and To, pick a date, then choose a ride from the list and tap to select seats and confirm.',
      'hi':
          'कहाँ से / कहाँ तक और तारीख चुनें, सूची से राइड चुनें, सीट चुनकर पुष्टि करें।',
    },
    'help.faq.pay.q': {
      'en': 'How does payment work?',
      'hi': 'भुगतान कैसे होता है?',
    },
    'help.faq.pay.a': {
      'en':
          'Payment is usually settled directly between passenger and driver (cash or UPI). LuhaRide connects users; it is not the payment collector unless stated otherwise in the app.',
      'hi':
          'भुगतान आमतौर पर यात्री और ड्राइवर के बीच सीधे (कैश / UPI) होता है। LuhaRide उपयोगकर्ताओं को जोड़ता है; जब तक ऐप में अलग से न कहा गया हो, भुगतान एकत्र नहीं करता।',
    },
    'help.faq.driver.q': {
      'en': 'How does driver verification work?',
      'hi': 'ड्राइवर सत्यापन कैसे काम करता है?',
    },
    'help.faq.driver.a': {
      'en':
          'From Profile, submit documents under the driver section. After admin approval you can create rides.',
      'hi':
          'प्रोफ़ाइल में ड्राइवर खंड से दस्तावेज़ जमा करें। एडमिन की मंज़ूरी के बाद आप राइड बना सकते हैं।',
    },
    'help.safety.title': {
      'en': 'Safety tips',
      'hi': 'सुरक्षा सुझाव',
    },
    'help.safety.1.title': {
      'en': 'Verify driver and vehicle before the trip',
      'hi': 'यात्रा से पहले ड्राइवर और गाड़ी जाँचें',
    },
    'help.safety.1.sub': {
      'en': 'Match the name, photo and vehicle number shown in the app with what you see on the ground.',
      'hi': 'ऐप में दिख रहे नाम, फोटो और नंबर को वास्तविकता से मिलाएँ।',
    },
    'help.safety.2.title': {
      'en': 'Keep emergency numbers handy',
      'hi': 'आपातकालीन नंबर तैयार रखें',
    },
    'help.safety.2.sub': {
      'en': 'In an emergency, contact 112 or your local police immediately.',
      'hi': 'आपात स्थिति में तुरंत 112 या स्थानीय पुलिस से संपर्क करें।',
    },
    'help.contact.title': {
      'en': 'Contact & support',
      'hi': 'संपर्क व सहायता',
    },
    'help.email.label': {
      'en': 'Email',
      'hi': 'ईमेल',
    },
    'help.whatsapp.label': {
      'en': 'WhatsApp support',
      'hi': 'WhatsApp सहायता',
    },
    'help.whatsapp.tap': {
      'en': 'Tap to open WhatsApp chat',
      'hi': 'WhatsApp चैट खोलने के लिए टैप करें',
    },
    'profile.logout': {
      'en': 'Sign out',
      'hi': 'साइन आउट',
    },
    'profile.logout.subtitle': {
      'en': 'Log out of your account',
      'hi': 'अपने खाते से बाहर निकलें',
    },
    'app.ok': {
      'en': 'OK',
      'hi': 'ठीक',
    },
    'app.cancel': {
      'en': 'Cancel',
      'hi': 'रद्द',
    },
    'app.close': {
      'en': 'Close',
      'hi': 'बंद करें',
    },
    'profile.complete_profile_btn': {
      'en': 'Complete profile',
      'hi': 'प्रोफ़ाइल पूरी करें',
    },
    'profile.verify_docs_btn': {
      'en': 'Verify documents',
      'hi': 'दस्तावेज़ सत्यापित करें',
    },
    'driver.tile.pending.title': {
      'en': 'Verification pending',
      'hi': 'सत्यापन लंबित',
    },
    'driver.tile.pending.sub': {
      'en': 'We are reviewing your documents',
      'hi': 'हम आपके दस्तावेज़ जाँच रहे हैं',
    },
    'driver.tile.rejected.title': {
      'en': 'Verification needs update',
      'hi': 'सत्यापन अपडेट चाहिए',
    },
    'driver.tile.rejected.sub': {
      'en': 'Please update details and resubmit documents.',
      'hi': 'कृपया विवरण अपडेट कर पुनः दस्तावेज़ जमा करें।',
    },
    'union.checking_snackbar': {
      'en': 'Checking union status…',
      'hi': 'यूनियन स्थिति जाँची जा रही है…',
    },
    'terms.title': {
      'en': 'Terms & conditions',
      'hi': 'नियम व शर्तें',
    },
    'terms.disclaimer': {
      'en':
          'This text is for general information only and is not legal advice. Have your Terms, Privacy Policy, '
          'and data practices reviewed by a qualified lawyer before large-scale or commercial use.',
      'hi':
          'यह पाठ सामान्य जानकारी के लिए है, कानूनी सलाह नहीं। व्यापक या वाणिज्यिक उपयोग से पहले योग्य वकील से '
          'नियम, गोपनीयता नीति और डेटा प्रथाओं की समीक्षा करवाएँ।',
    },
    // Passenger — My bookings / rides list
    'my_rides.title': {
      'en': 'My rides',
      'hi': 'मेरी सवारी',
    },
    'my_rides.retry': {
      'en': 'Retry',
      'hi': 'पुनः कोशिश',
    },
    'my_rides.load_failed': {
      'en': 'Could not load bookings',
      'hi': 'बुकिंग लोड नहीं हो सकी',
    },
    'my_rides.empty.title': {
      'en': 'No rides yet',
      'hi': 'अभी कोई सवारी नहीं',
    },
    'my_rides.empty.subtitle': {
      'en': 'Book a ride to see it here',
      'hi': 'यहाँ देखने के लिए राइड बुक करें',
    },
    'my_rides.status.confirmed': {
      'en': 'Approved',
      'hi': 'मंज़ूर',
    },
    'my_rides.status.pending': {
      'en': 'Pending',
      'hi': 'लंबित',
    },
    'my_rides.status.cancelled': {
      'en': 'Cancelled',
      'hi': 'रद्द',
    },
    'my_rides.whatsapp_hint': {
      'en': 'Tap to chat on WhatsApp',
      'hi': 'WhatsApp पर बात करने के लिए टैप करें',
    },
    'my_rides.driver_default': {
      'en': 'Driver',
      'hi': 'ड्राइवर',
    },
    'my_rides.pending_message': {
      'en':
          'Waiting for the driver to approve. You will see driver details here once the booking is approved.',
      'hi':
          'ड्राइवर की मंज़ूरी का इंतज़ार है। बुकिंग मंज़ूर होने के बाद यहाँ ड्राइवर का विवरण दिखेगा।',
    },
    'my_rides.pull_refresh': {
      'en': 'Pull down to refresh for the latest status',
      'hi': 'नवीनतम स्थिति के लिए नीचे खींचकर रीफ़्रेश करें',
    },
    'my_rides.ask_question': {
      'en': 'Ask a question',
      'hi': 'सवाल पूछें',
    },
    'my_rides.cancel_booking': {
      'en': 'Cancel booking',
      'hi': 'बुकिंग रद्द करें',
    },
    'my_rides.cancel_blocked': {
      'en':
          'Cancellation is not available within 2 minutes of departure, or after the ride has started.',
      'hi':
          'प्रस्थान के 2 मिनट के अंदर या यात्रा शुरू होने के बाद रद्दीकरण उपलब्ध नहीं है।',
    },
    'my_rides.contact_unavailable': {
      'en':
          'Driver contact is not available. Ask the driver to add a phone number or WhatsApp in their profile.',
      'hi':
          'ड्राइवर का संपर्क उपलब्ध नहीं है। ड्राइवर से प्रोफ़ाइल में फ़ोन या WhatsApp जोड़ने कहें।',
    },
    'my_rides.open_chat_failed': {
      'en': 'Could not open chat or dial',
      'hi': 'चैट या कॉल नहीं खुल सका',
    },
    'my_rides.cancel_confirm_title': {
      'en': 'Cancel this booking?',
      'hi': 'यह बुकिंग रद्द करें?',
    },
    'my_rides.cancel_policy': {
      'en':
          'You can cancel until 2 minutes before the scheduled departure time (same rules as the server).',
      'hi':
          'निर्धारित प्रस्थान से 2 मिनट पहले तक आप रद्द कर सकते हैं (सर्वर के नियमों के अनुसार)।',
    },
    'my_rides.reason_label': {
      'en': 'Reason (optional)',
      'hi': 'कारण (वैकल्पिक)',
    },
    'my_rides.reason_hint': {
      'en': 'E.g. plan changed',
      'hi': 'जैसे: योजना बदल गई',
    },
    'my_rides.keep_booking': {
      'en': 'Keep booking',
      'hi': 'बुकिंग रखें',
    },
    'my_rides.booking_cancelled_fallback': {
      'en': 'Booking cancelled',
      'hi': 'बुकिंग रद्द हो गई',
    },
    'my_rides.cancel_failed_fallback': {
      'en': 'Could not cancel booking',
      'hi': 'बुकिंग रद्द नहीं हो सकी',
    },
    'my_rides.question_title': {
      'en': 'Message to driver',
      'hi': 'ड्राइवर को संदेश',
    },
    'my_rides.question_body': {
      'en':
          'The app does not send in-app messages to drivers yet. After your booking is approved, use WhatsApp from the driver card to contact them.',
      'hi':
          'ऐप अभी ड्राइवर को इन-ऐप संदेश नहीं भेजता। बुकिंग मंज़ूर होने के बाद ड्राइवर कार्ड से WhatsApp से संपर्क करें।',
    },
    'my_rides.question_field_hint': {
      'en': 'E.g. pickup point, luggage…',
      'hi': 'जैसे: पिकअप पॉइंट, सामान…',
    },
    'my_rides.question_send': {
      'en': 'OK',
      'hi': 'ठीक',
    },
    'my_rides.question_snackbar_empty': {
      'en':
          'Add a note for yourself if you like. To reach the driver, wait for approval and use WhatsApp on the driver card.',
      'hi':
          'चाहें तो अपने लिए नोट लिखें। ड्राइवर तक पहुँचने के लिए मंज़ूरी का इंतज़ार करें और ड्राइवर कार्ड से WhatsApp इस्तेमाल करें।',
    },
    'my_rides.question_snackbar_note': {
      'en':
          'Nothing was sent to the driver in the app. After approval, use WhatsApp from the driver card.',
      'hi':
          'ऐप में ड्राइवर को कुछ नहीं भेजा गया। मंज़ूर होने के बाद ड्राइवर कार्ड से WhatsApp इस्तेमाल करें।',
    },
    'notifications.mark_all_read': {
      'en': 'All notifications marked as read',
      'hi': 'सभी सूचनाएँ पढ़ी हुई चिह्नित',
    },
    'notifications.title': {
      'en': 'Notifications',
      'hi': 'सूचनाएँ',
    },
    'notifications.mark_all_tooltip': {
      'en': 'Mark all as read',
      'hi': 'सभी पढ़ा हुआ चिह्नित करें',
    },
    'notifications.load_failed': {
      'en': 'Failed to load notifications',
      'hi': 'सूचनाएँ लोड नहीं हो सकीं',
    },
    'notifications.empty.title': {
      'en': 'No notifications yet',
      'hi': 'अभी कोई सूचना नहीं',
    },
    'notifications.empty.subtitle': {
      'en': 'Verification, bookings and other updates will appear here.',
      'hi': 'सत्यापन, बुकिंग और अन्य अपडेट यहाँ दिखेंगे।',
    },
    'notifications.time.just_now': {
      'en': 'Just now',
      'hi': 'अभी',
    },
    'notifications.time.minutes_ago': {
      'en': '{n} min ago',
      'hi': '{n} मिनट पहले',
    },
    'notifications.time.hours_ago': {
      'en': '{n} h ago',
      'hi': '{n} घंटे पहले',
    },
    'notifications.time.days_ago': {
      'en': '{n} d ago',
      'hi': '{n} दिन पहले',
    },
    // Driver home (UI only; same /api/* via gateway)
    'driver.home.title': {
      'en': 'Driver dashboard',
      'hi': 'ड्राइवर डैशबोर्ड',
    },
    'driver.home.hello': {
      'en': 'Hello, {name}!',
      'hi': 'नमस्ते, {name}!',
    },
    'driver.home.fallback_driver': {
      'en': 'Driver',
      'hi': 'ड्राइवर',
    },
    'driver.home.fallback_passenger': {
      'en': 'Passenger',
      'hi': 'यात्री',
    },
    'driver.home.get_rated': {
      'en': 'Get rated',
      'hi': 'रेटिंग पाएँ',
    },
    'driver.home.online': {
      'en': 'Online',
      'hi': 'ऑनलाइन',
    },
    'driver.home.create_trip': {
      'en': 'Create new trip',
      'hi': 'नई यात्रा बनाएँ',
    },
    'driver.footer.create': {
      'en': 'Create',
      'hi': 'बनाएँ',
    },
    'driver.footer.profile': {
      'en': 'Profile',
      'hi': 'प्रोफ़ाइल',
    },
    // Auth — simple login (UI only)
    'auth.login.title': {
      'en': 'Login',
      'hi': 'लॉग इन',
    },
    'auth.login.password_label': {
      'en': 'Password',
      'hi': 'पासवर्ड',
    },
    'auth.login.password_hint': {
      'en': 'Your password',
      'hi': 'आपका पासवर्ड',
    },
    'auth.login.email_required': {
      'en': 'Email is required',
      'hi': 'ईमेल आवश्यक है',
    },
    'auth.login.email_invalid': {
      'en': 'Enter a valid email',
      'hi': 'वैध ईमेल दर्ज करें',
    },
    'auth.login.password_required': {
      'en': 'Password is required',
      'hi': 'पासवर्ड आवश्यक है',
    },
    'auth.login.forgot_password': {
      'en': 'Forgot password?',
      'hi': 'पासवर्ड भूल गए?',
    },
    'auth.login.signup_prompt': {
      'en': "Don't have an account? Sign up",
      'hi': 'खाता नहीं है? साइन अप करें',
    },
    'auth.login.back': {
      'en': 'Back',
      'hi': 'पीछे',
    },
    'auth.login.invalid_credentials': {
      'en': 'Invalid email or password.',
      'hi': 'गलत ईमेल या पासवर्ड।',
    },
    'auth.login.failed_fallback': {
      'en': 'Login failed',
      'hi': 'लॉग इन असफल',
    },
    // Trip details (passenger)
    'trip.details.title': {
      'en': 'Trip details',
      'hi': 'यात्रा विवरण',
    },
    'trip.details.share_tooltip': {
      'en': 'Share trip',
      'hi': 'यात्रा साझा करें',
    },
    'trip.details.share_link': {
      'en': 'Share trip link',
      'hi': 'यात्रा लिंक साझा करें',
    },
    'trip.details.copy_link': {
      'en': 'Copy link',
      'hi': 'लिंक कॉपी करें',
    },
    'trip.details.link_copied': {
      'en': 'Link copied to clipboard',
      'hi': 'लिंक कॉपी हो गया',
    },
    'trip.details.not_found': {
      'en': 'Trip not found',
      'hi': 'यात्रा नहीं मिली',
    },
    'trip.details.schedule': {
      'en': 'Schedule',
      'hi': 'समय सारणी',
    },
    'trip.details.vehicle_details': {
      'en': 'Vehicle details',
      'hi': 'वाहन विवरण',
    },
    'trip.details.seats_available': {
      'en': '{a} / {t} seats available',
      'hi': '{a} / {t} सीटें उपलब्ध',
    },
    'trip.details.driver_section': {
      'en': 'Driver',
      'hi': 'ड्राइवर',
    },
    'trip.details.tap_reviews': {
      'en': 'Tap to see ratings & reviews',
      'hi': 'रेटिंग व समीक्षा देखने के लिए टैप करें',
    },
    'trip.details.whatsapp': {
      'en': 'Message on WhatsApp',
      'hi': 'WhatsApp पर संदेश',
    },
    'trip.details.pending_contact': {
      'en':
          'Booking pending — driver contact will be shared once confirmed.',
      'hi':
          'बुकिंग लंबित है — मंज़ूरी के बाद ड्राइवर का संपर्क दिखेगा।',
    },
    'trip.details.fare_per_seat': {
      'en': 'Fare per seat',
      'hi': 'प्रति सीट किराया',
    },
    'trip.details.book_ride': {
      'en': 'Book ride',
      'hi': 'राइड बुक करें',
    },
    'trip.details.login_required_title': {
      'en': 'Login required',
      'hi': 'लॉग इन आवश्यक',
    },
    'trip.details.login_required_body': {
      'en': 'Please log in to book a seat on this ride.',
      'hi': 'इस राइड पर सीट बुक करने के लिए लॉग इन करें।',
    },
    'trip.details.login_cta': {
      'en': 'Log in',
      'hi': 'लॉग इन',
    },
    'trip.details.no_ratings': {
      'en': 'No ratings yet',
      'hi': 'अभी कोई रेटिंग नहीं',
    },
    'trip.details.see_reviews': {
      'en': 'See reviews',
      'hi': 'समीक्षाएँ देखें',
    },
    // Seat selection
    'seat.select.title': {
      'en': 'Select seats',
      'hi': 'सीट चुनें',
    },
    'seat.select.driver_reserved': {
      'en': 'Driver seat is reserved and cannot be booked',
      'hi': 'ड्राइवर की सीट आरक्षित है, बुक नहीं हो सकती',
    },
    'seat.select.seat_pending_other': {
      'en': 'Seat {n} is pending (requested by another passenger)',
      'hi': 'सीट {n} लंबित है (दूसरे यात्री ने माँगी है)',
    },
    'seat.select.seat_booked': {
      'en': 'Seat {n} is already booked',
      'hi': 'सीट {n} पहले से बुक है',
    },
    'seat.select.booking_confirmed_fallback': {
      'en': 'Booking confirmed!',
      'hi': 'बुकिंग पुष्टि हो गई!',
    },
    'seat.select.already_booking': {
      'en': 'You already have a booking for this trip.',
      'hi': 'आपकी इस यात्रा के लिए पहले से बुकिंग है।',
    },
    'seat.select.pick_one': {
      'en': 'Please select at least one seat',
      'hi': 'कम से कम एक सीट चुनें',
    },
    'seat.select.confirm_title': {
      'en': 'Confirm booking',
      'hi': 'बुकिंग पुष्टि करें',
    },
    'seat.select.selected_seats': {
      'en': 'Selected seats: {s}',
      'hi': 'चुनी सीटें: {s}',
    },
    'seat.select.number_of_seats': {
      'en': 'Number of seats: {n}',
      'hi': 'सीटों की संख्या: {n}',
    },
    'seat.select.total_pay': {
      'en': 'Total (pay after ride): ₹{amt}',
      'hi': 'कुल (सवारी के बाद भुगतान): ₹{amt}',
    },
    'seat.select.confirm_booking': {
      'en': 'Confirm booking',
      'hi': 'बुकिंग पुष्टि करें',
    },
    'seat.select.booking_failed_fallback': {
      'en': 'Booking failed',
      'hi': 'बुकिंग असफल',
    },
    'seat.select.available_count': {
      'en': '{n} available',
      'hi': '{n} उपलब्ध',
    },
    'seat.select.tap_refresh': {
      'en': 'Tap ↓ to refresh',
      'hi': 'रीफ़्रेश के लिए नीचे खींचें',
    },
    'seat.select.summary.confirmed': {
      'en': 'Confirmed',
      'hi': 'पुष्टि',
    },
    'seat.select.summary.pending': {
      'en': 'Pending',
      'hi': 'लंबित',
    },
    'seat.select.summary.available': {
      'en': 'Available',
      'hi': 'उपलब्ध',
    },
    'seat.select.legend.driver': {
      'en': 'Driver',
      'hi': 'ड्राइवर',
    },
    'seat.select.legend.available': {
      'en': 'Available',
      'hi': 'खाली',
    },
    'seat.select.legend.selected': {
      'en': 'Selected',
      'hi': 'चुनी',
    },
    'seat.select.legend.booked': {
      'en': 'Booked',
      'hi': 'बुक',
    },
    'seat.select.legend.pending': {
      'en': 'Pending',
      'hi': 'लंबित',
    },
    'seat.select.per_seat': {
      'en': '₹{amt} per seat',
      'hi': 'प्रति सीट ₹{amt}',
    },
    'seat.select.prompt_select': {
      'en': 'Select seats',
      'hi': 'सीट चुनें',
    },
    'seat.select.seats_selected': {
      'en': '{n} seat(s) selected',
      'hi': '{n} सीट चुनी',
    },
    'seat.select.total': {
      'en': 'Total: ₹{amt}',
      'hi': 'कुल: ₹{amt}',
    },
    'seat.select.book_now': {
      'en': 'Book now',
      'hi': 'अब बुक करें',
    },
    // Driver — my trips list
    'driver.trips.chip.all': {
      'en': 'All',
      'hi': 'सभी',
    },
    'driver.trips.chip.ongoing': {
      'en': 'Ongoing',
      'hi': 'चालू',
    },
    'driver.trips.chip.pending': {
      'en': 'Pending',
      'hi': 'लंबित',
    },
    'driver.trips.chip.completed': {
      'en': 'Completed',
      'hi': 'पूर्ण',
    },
    'driver.trips.empty.title': {
      'en': 'No rides yet',
      'hi': 'अभी कोई सवारी नहीं',
    },
    'driver.trips.empty.all': {
      'en': 'Create your first ride',
      'hi': 'अपनी पहली यात्रा बनाएँ',
    },
    'driver.trips.empty.ongoing': {
      'en': 'Create a new ride to get started',
      'hi': 'शुरू करने के लिए नई यात्रा बनाएँ',
    },
    'driver.trips.empty.completed': {
      'en': 'No completed rides yet',
      'hi': 'अभी कोई पूर्ण यात्रा नहीं',
    },
    'driver.trips.empty.pending': {
      'en': 'No pending requests',
      'hi': 'कोई लंबित अनुरोध नहीं',
    },
  };

  String t(String key) {
    final byKey = _values[key];
    if (byKey == null) return key;
    return byKey[_lang] ?? byKey['en'] ?? key;
  }

  /// Replace `{key}` placeholders in a localized template (UI-only; no API impact).
  String tReplace(String templateKey, Map<String, String> vars) {
    var s = t(templateKey);
    for (final e in vars.entries) {
      s = s.replaceAll('{${e.key}}', e.value);
    }
    return s;
  }

  /// Relative time for notification list rows (client display only).
  String notificationRelativeTime(DateTime created) {
    final diff = DateTime.now().difference(created);
    if (diff.inMinutes < 1) return t('notifications.time.just_now');
    if (diff.inMinutes < 60) {
      return tReplace('notifications.time.minutes_ago', {'n': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return tReplace('notifications.time.hours_ago', {'n': '${diff.inHours}'});
    }
    return tReplace('notifications.time.days_ago', {'n': '${diff.inDays}'});
  }
}

