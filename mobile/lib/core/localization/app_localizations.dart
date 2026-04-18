import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../brand_config.dart';
import '../../providers/app_language_provider.dart';

/// Very lightweight key-based localization for English & Hindi.
class AppLocalizations {
  final AppLanguageCode code;

  AppLocalizations(this.code);

  /// Small footer credit — spelling always from [BrandConfig.parentBrand] (TECHMCU).
  String get brandFooterParentLine {
    if (code == AppLanguageCode.hi) {
      return '${BrandConfig.parentBrand} द्वारा संचालित';
    }
    return 'Powered by ${BrandConfig.parentBrand}';
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
      'en': 'Safe · Friendly · Reliable rides',
      'hi': 'सुरक्षित · सहज · भरोसेमंद सवारी',
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
          'Your union registration has been received. Our team usually reviews within 24–48 hours. Use “Check status” after some time.\n\nIf it takes longer, email us at {supportEmail} with your union name and phone in the subject line.',
      'hi':
          'आपका यूनियन पंजीकरण प्राप्त हो गया है। हमारी टीम आमतौर पर 24–48 घंटे में जाँच करती है। कुछ समय बाद “स्थिति देखें” दबाएँ।\n\nअगर और देर हो, तो {supportEmail} पर यूनियन नाम और फ़ोन विषय में लिखकर ईमेल करें।',
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
          'Your driver verification is pending. We usually review within 24–48 hours.\n\nIf it takes longer, email {supportEmail} with your name and phone in the subject line.',
      'hi':
          'आपका ड्राइवर सत्यापन लंबित है। हम आमतौर पर 24–48 घंटे में जाँच करते हैं।\n\nअगर देर हो, तो {supportEmail} पर नाम और फ़ोन विषय में लिखकर ईमेल करें।',
    },
    'profile.verify.need_docs': {
      'en': 'Please complete document verification before creating rides.',
      'hi': 'राइड बनाने से पहले कृपया दस्तावेज़ सत्यापन पूरा करें।',
    },
    'profile.verify.reverify_locked': {
      'en':
          'Your documents need re-verification. Please wait for the admin to reopen upload in your profile.\n\nIf you have any issue, email {supportEmail}.',
      'hi':
          'आपके दस्तावेज़ों का पुनः सत्यापन आवश्यक है। कृपया एडमिन द्वारा प्रोफ़ाइल में अपलोड विकल्प खुलने का इंतज़ार करें।\n\nकिसी भी समस्या के लिए {supportEmail} पर ईमेल करें।',
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
      'en': 'Email support',
      'hi': 'ईमेल सहायता',
    },
    'help.email.display_hint': {
      'en': 'For support, open your email app and write to this address (not a link). Long-press to copy if needed.',
      'hi': 'सहायता के लिए अपने ईमेल ऐप में यह पता लिखें (लिंक नहीं)। कॉपी करने हेतु लंबा दबाएँ।',
    },
    'help.about.title': {
      'en': 'About this app',
      'hi': 'ऐप के बारे में',
    },
    'help.about.version': {
      'en': 'Version',
      'hi': 'संस्करण',
    },
    'help.about.privacy': {
      'en': 'Privacy policy',
      'hi': 'गोपनीयता नीति',
    },
    'help.about.privacy_hint': {
      'en': 'Tap to open the full privacy policy on luharide.cloud. For privacy questions, use Help → email support.',
      'hi': 'पूरी गोपनीयता नीति खोलने के लिए टैप करें (luharide.cloud पर)। गोपनीयता प्रश्नों के लिए सहायता → ईमेल से संपर्क करें।',
    },
    'help.about.privacy_updating': {
      'en': 'This page will be updated soon with the full policy.',
      'hi': 'पूर्ण नीति के साथ यह पृष्ठ जल्द अपडेट किया जाएगा।',
    },
    'signup.privacy_coming_soon': {
      'en': 'Privacy policy page — coming soon. A link will be added when it is live.',
      'hi': 'गोपनीयता नीति पृष्ठ — जल्द आ रहा है। लाइव होने पर लिंक जोड़ा जाएगा।',
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
    'app.retry': {
      'en': 'Retry',
      'hi': 'पुनः कोशिश',
    },
    'app.refresh': {
      'en': 'Refresh',
      'hi': 'रीफ़्रेश',
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
    'trip.self_book.title': {
      'en': 'Cannot book your own ride',
      'hi': 'अपनी ही राइड बुक नहीं कर सकते',
    },
    'trip.self_book.body': {
      'en':
          'This ride was posted from your account. You cannot book seats on it with the same account. This avoids misuse and payment issues. Ask a passenger to book, or use a different account if you need a test booking.',
      'hi':
          'यह राइड आपके खाते से पोस्ट की गई है। उसी खाते से इस पर सीट बुक नहीं कर सकते। दुरुपयोग और भुगतान समस्याओं से बचने के लिए ऐसा है। यात्री को बुक करवाएँ, या टेस्ट के लिए अलग खाता उपयोग करें।',
    },
    'trip.details.own_ride_hint': {
      'en': 'You posted this ride — booking your own seats is not allowed on this account.',
      'hi': 'आपने यह राइड पोस्ट की है — इसी खाते से अपनी सीटें बुक करना अनुमत नहीं है।',
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
    'driver.trips.badge.ongoing': {
      'en': 'ONGOING',
      'hi': 'चालू',
    },
    'driver.trips.badge.completed': {
      'en': 'COMPLETED',
      'hi': 'पूर्ण',
    },
    'driver.trips.badge.pending_row': {
      'en': '{n} PENDING',
      'hi': '{n} लंबित',
    },
    'driver.trips.card.booked': {
      'en': '{b}/{t} booked',
      'hi': '{b}/{t} बुक',
    },
    // Landing (guest search)
    'landing.both_locations': {
      'en': 'Please enter both locations',
      'hi': 'दोनों स्थान दर्ज करें',
    },
    'landing.search_failed': {
      'en': 'Search failed',
      'hi': 'खोज असफल',
    },
    'landing.contact.login_title': {
      'en': 'Login required',
      'hi': 'लॉग इन आवश्यक',
    },
    'landing.contact.login_body': {
      'en': 'Please log in to contact the driver.',
      'hi': 'ड्राइवर से संपर्क करने के लिए लॉग इन करें।',
    },
    'landing.header.signup': {
      'en': 'Sign up',
      'hi': 'साइन अप',
    },
    'landing.search.cta': {
      'en': 'Find rides',
      'hi': 'राइड खोजें',
    },
    'landing.tagline': {
      'en': 'Find rides at low prices',
      'hi': 'कम किराए पर राइड खोजें',
    },
    'landing.results.title': {
      'en': 'Rides found',
      'hi': 'मिली राइडें',
    },
    'landing.results.count': {
      'en': '{n} trips',
      'hi': '{n} यात्राएँ',
    },
    'landing.results.empty': {
      'en': 'No rides found',
      'hi': 'कोई राइड नहीं मिली',
    },
    'landing.section.independent': {
      'en': 'Independent driver rides',
      'hi': 'स्वतंत्र ड्राइवर की राइडें',
    },
    'landing.section.union': {
      'en': 'Union scheduled rides',
      'hi': 'यूनियन निर्धारित राइडें',
    },
    'landing.card.independent_tag': {
      'en': 'Independent driver • Book on app',
      'hi': 'स्वतंत्र ड्राइवर • ऐप पर बुक करें',
    },
    'landing.card.seats': {
      'en': '{a} / {t} seats',
      'hi': '{a} / {t} सीटें',
    },
    'landing.card.book': {
      'en': 'Book',
      'hi': 'बुक करें',
    },
    'landing.union.tag': {
      'en': 'Union ride',
      'hi': 'यूनियन राइड',
    },
    'landing.union.time_na': {
      'en': 'Time N/A',
      'hi': 'समय अज्ञात',
    },
    'landing.contact.call': {
      'en': 'Call',
      'hi': 'कॉल',
    },
    'landing.contact.whatsapp': {
      'en': 'WhatsApp',
      'hi': 'WhatsApp',
    },
    'landing.date.today': {
      'en': 'Today',
      'hi': 'आज',
    },
    // Home shell — union admin / driver can switch to same find-rides UI as passengers
    // KYC — driver verification (no Hinglish; EN or HI only)
    'kyc.driver.title': {
      'en': 'Become a driver',
      'hi': 'ड्राइवर बनें',
    },
    'kyc.driver.already_pending_title': {
      'en': 'Application in review',
      'hi': 'आवेदन समीक्षा में',
    },
    'kyc.driver.self': {
      'en': 'Driver',
      'hi': 'ड्राइवर',
    },
    'kyc.driver.already_pending_body': {
      'en':
          'Your verification is already submitted. Please wait for the team to review it. You cannot send another request until it is approved or rejected.',
      'hi':
          'आपका सत्यापन पहले ही भेजा जा चुका है। कृपया टीम की समीक्षा की प्रतीक्षा करें। स्वीकृति या अस्वीकृति तक दोबारा आवेदन नहीं भेज सकते।',
    },
    'kyc.driver.verified_title': {
      'en': 'Verified driver',
      'hi': 'सत्यापित ड्राइवर',
    },
    'kyc.driver.verified_body': {
      'en': 'Your documents are verified. If you need to update documents, the admin will reopen upload in your profile.',
      'hi': 'आपके दस्तावेज़ सत्यापित हैं। अगर दस्तावेज़ अपडेट करने की जरूरत हो, तो एडमिन आपके प्रोफ़ाइल में अपलोड विकल्प खोलेंगे।',
    },
    'kyc.driver.reverify_required_title': {
      'en': 'Re-verification required',
      'hi': 'पुनः सत्यापन आवश्यक',
    },
    'kyc.driver.reverify_required_body': {
      'en': 'The admin has requested re-verification. Please wait for upload access to be opened in your profile.',
      'hi': 'एडमिन ने पुनः सत्यापन के लिए कहा है। कृपया प्रोफ़ाइल में अपलोड विकल्प खुलने की प्रतीक्षा करें।',
    },
    'kyc.driver.back': {
      'en': 'Back',
      'hi': 'वापस',
    },
    'kyc.driver.check_status': {
      'en': 'Check status',
      'hi': 'स्थिति देखें',
    },
    'kyc.driver.contact_phone': {
      'en': 'Contact phone',
      'hi': 'संपर्क फ़ोन',
    },
    'kyc.driver.contact_email': {
      'en': 'Contact email',
      'hi': 'संपर्क ईमेल',
    },
    'kyc.driver.info_card': {
      'en':
          'This form is for genuine taxi operators only. False details may lead to account restrictions.\n\nDocuments are reviewed within about 24–48 hours.',
      'hi':
          'यह फॉर्म केवल वास्तविक टैक्सी संचालकों के लिए है। गलत जानकारी पर खाते पर प्रतिबंध लग सकता है।\n\nदस्तावेज़ लगभग 24–48 घंटे में देखे जाते हैं।',
    },
    'kyc.driver.upload_heading': {
      'en': 'Upload documents',
      'hi': 'दस्तावेज़ अपलोड करें',
    },
    'kyc.driver.upload_note': {
      'en':
          'JPEG or PNG photos only — PDF and Word files are not accepted. 50 KB–20 MB per file (from gallery or camera).',
      'hi':
          'केवल JPEG या PNG फ़ोटो — PDF और Word फ़ाइल स्वीकार नहीं। प्रति फ़ाइल 50 KB–20 MB (गैलरी या कैमरा से)।',
    },
    'kyc.driver.snack.missing_docs': {
      'en': 'Please upload Aadhaar (front and back) and driving licence (front and back).',
      'hi': 'कृपया आधार (आगे-पीछे) और ड्राइविंग लाइसेंस (आगे-पीछे) अपलोड करें।',
    },
    'kyc.driver.snack.select_vehicle': {
      'en': 'Please select your vehicle type.',
      'hi': 'कृपया वाहन प्रकार चुनें।',
    },
    'kyc.driver.val.phone': {
      'en': 'Enter a valid phone number (at least 10 digits).',
      'hi': 'मान्य फ़ोन नंबर दर्ज करें (कम से कम 10 अंक)।',
    },
    'kyc.driver.val.email_required': {
      'en': 'Email is required.',
      'hi': 'ईमेल आवश्यक है।',
    },
    'kyc.driver.val.email_invalid': {
      'en': 'Enter a valid email address.',
      'hi': 'मान्य ईमेल पता दर्ज करें।',
    },
    'kyc.driver.vehicle_reg': {
      'en': 'Vehicle registration number',
      'hi': 'वाहन पंजीकरण संख्या',
    },
    'kyc.driver.vehicle_reg.hint': {
      'en': 'As on RC, e.g. UK07AB1234',
      'hi': 'आरसी जैसा, उदਾ. UK07AB1234',
    },
    'kyc.driver.vehicle_reg.required': {
      'en': 'Vehicle registration is required.',
      'hi': 'वाहन पंजीकरण आवश्यक है।',
    },
    'kyc.driver.vehicle_type.title': {
      'en': 'Vehicle type',
      'hi': 'वाहन प्रकार',
    },
    'kyc.driver.vehicle_type.hint': {
      'en': 'Select vehicle (capacity as per RTO)',
      'hi': 'वाहन चुनें (आरटीओ के अनुसार क्षमता)',
    },
    'kyc.driver.vehicle_type.required': {
      'en': 'Please select a vehicle.',
      'hi': 'कृपया वाहन चुनें।',
    },
    'kyc.driver.seats_note': {
      'en': '{n} seats — passengers see this layout when booking.',
      'hi': '{n} सीटें — बुकिंग पर यात्री यही लेआउट देखेंगे।',
    },
    'kyc.driver.chip.aadhaar_front': {
      'en': 'Aadhaar front',
      'hi': 'आधार अगला',
    },
    'kyc.driver.chip.aadhaar_back': {
      'en': 'Aadhaar back',
      'hi': 'आधार पिछला',
    },
    'kyc.driver.chip.dl_front': {
      'en': 'Driving licence front',
      'hi': 'डीएल अगला',
    },
    'kyc.driver.chip.dl_back': {
      'en': 'Driving licence back',
      'hi': 'डीएल पिछला',
    },
    'kyc.driver.submit': {
      'en': 'Submit for verification',
      'hi': 'सत्यापन हेतु जमा करें',
    },
    'kyc.driver.snack.submitted': {
      'en': 'Submitted. The team will review your request.',
      'hi': 'जमा हो गया। टीम आपका आवेदन देखेगी।',
    },
    'kyc.trip.vehicle_locked_hint': {
      'en': 'This number is from your driver verification and will be used on rides.',
      'hi': 'यह नंबर आपके ड्राइवर सत्यापन से है और राइड में यही उपयोग होगा।',
    },
    'kyc.trip.vehicle_required': {
      'en': 'Enter the vehicle registration number.',
      'hi': 'वाहन पंजीकरण संख्या दर्ज करें।',
    },
    'kyc.union.snack.missing_docs': {
      'en': 'Please upload union leader Aadhaar (front and back) and a clear union photo.',
      'hi': 'कृपया यूनियन प्रमुख का आधार (आगे-पीछे) और स्पष्ट यूनियन फोटो अपलोड करें।',
    },
    'kyc.union.upload_note': {
      'en':
          'JPEG or PNG photos only — PDF and Word files are not accepted. 50 KB–20 MB per file (from gallery or camera).',
      'hi':
          'केवल JPEG या PNG फ़ोटो — PDF और Word फ़ाइल स्वीकार नहीं। प्रति फ़ाइल 50 KB–20 MB (गैलरी या कैमरा से)।',
    },
    'kyc.union.val.phone': {
      'en': 'Leader phone is required.',
      'hi': 'प्रमुख का फ़ोन आवश्यक है।',
    },
    'kyc.union.val.phone_len': {
      'en': 'Phone must be at least 10 digits.',
      'hi': 'फ़ोन कम से कम 10 अंक का हो।',
    },
    'kyc.union.val.email': {
      'en': 'Leader email is required.',
      'hi': 'प्रमुख का ईमेल आवश्यक है।',
    },
    'kyc.union.val.email_invalid': {
      'en': 'Enter a valid email.',
      'hi': 'मान्य ईमेल दर्ज करें।',
    },
    'kyc.union.label.leader_phone': {
      'en': 'Union leader phone',
      'hi': 'यूनियन प्रमुख फ़ोन',
    },
    'kyc.union.label.leader_email': {
      'en': 'Union leader email',
      'hi': 'यूनियन प्रमुख ईमेल',
    },
    'kyc.union.chip.aadhaar_front': {
      'en': 'Leader Aadhaar front',
      'hi': 'प्रमुख आधार अगला',
    },
    'kyc.union.chip.aadhaar_back': {
      'en': 'Leader Aadhaar back',
      'hi': 'प्रमुख आधार पिछला',
    },
    'kyc.union.chip.photo': {
      'en': 'Union photo',
      'hi': 'यूनियन फोटो',
    },
    'kyc.union.leader_name': {
      'en': 'Union leader name',
      'hi': 'यूनियन प्रमुख का नाम',
    },
    'kyc.union.name_required': {
      'en': 'Enter the leader name.',
      'hi': 'प्रमुख का नाम दर्ज करें।',
    },
    'kyc.union.name_short': {
      'en': 'Name must be at least 2 characters.',
      'hi': 'नाम कम से कम 2 अक्षर का हो।',
    },
    'kyc.union.union_name': {
      'en': 'Union name',
      'hi': 'यूनियन नाम',
    },
    'kyc.union.union_name_required': {
      'en': 'Enter the union name.',
      'hi': 'यूनियन नाम दर्ज करें।',
    },
    'kyc.union.union_name_short': {
      'en': 'Union name must be at least 3 characters.',
      'hi': 'यूनियन नाम कम से कम 3 अक्षर का हो।',
    },
    'kyc.union.location': {
      'en': 'Union location',
      'hi': 'यूनियन स्थान',
    },
    'kyc.union.location_required': {
      'en': 'Enter the location.',
      'hi': 'स्थान दर्ज करें।',
    },
    'kyc.union.details_section': {
      'en': 'Union details',
      'hi': 'यूनियन विवरण',
    },
    'kyc.union.submit': {
      'en': 'Submit for approval',
      'hi': 'अनुमोदन हेतु जमा करें',
    },
    'kyc.union.approved_nav': {
      'en': 'Approved. Opening dashboard…',
      'hi': 'स्वीकृत। डैशबोर्ड खुल रहा है…',
    },
    'kyc.union.upload_heading': {
      'en': 'Upload documents',
      'hi': 'दस्तावेज़ अपलोड करें',
    },
    'kyc.union.preview_label': {
      'en': 'Selected photos',
      'hi': 'चुनी गई तस्वीरें',
    },
    // Admin — platform KYC review (follows app language)
    'admin.stat.trips': {
      'en': 'Trips',
      'hi': 'यात्राएँ',
    },
    'admin.stat.bookings': {
      'en': 'Bookings',
      'hi': 'बुकिंग',
    },
    'admin.stat.drivers': {
      'en': 'Drivers',
      'hi': 'ड्राइवर',
    },
    'admin.stat.pending_drivers': {
      'en': 'Pending drivers',
      'hi': 'लंबित ड्राइवर',
    },
    'admin.stat.pending_unions': {
      'en': 'Pending unions',
      'hi': 'लंबित संघ',
    },
    'admin.stat.pending_total': {
      'en': 'Total pending',
      'hi': 'कुल लंबित',
    },
    'admin.stat.pending_union_docs': {
      'en': 'Union doc reviews',
      'hi': 'संघ दस्तावेज़ समीक्षा',
    },
    'admin.action.reject': {
      'en': 'Reject',
      'hi': 'अस्वीकार',
    },
    'admin.action.approve': {
      'en': 'Approve',
      'hi': 'स्वीकृत करें',
    },
    'admin.reject.driver_title': {
      'en': 'Reject driver',
      'hi': 'ड्राइवर अस्वीकार करें',
    },
    'admin.reject.reason_hint': {
      'en': 'Reason (optional)',
      'hi': 'कारण (वैकल्पिक)',
    },
    'admin.logout.title': {
      'en': 'Log out',
      'hi': 'लॉग आउट',
    },
    'admin.logout.body': {
      'en': 'Do you want to log out?',
      'hi': 'क्या आप लॉग आउट करना चाहते हैं?',
    },
    'admin.snack.cannot_open': {
      'en': 'Could not open the link.',
      'hi': 'लिंक नहीं खुल सका।',
    },
    'admin.kyc.phone': {
      'en': 'Phone',
      'hi': 'फ़ोन',
    },
    'admin.kyc.email': {
      'en': 'Email',
      'hi': 'ईमेल',
    },
    'admin.kyc.aadhaar_legacy': {
      'en': 'Aadhaar (single file)',
      'hi': 'आधार (एक फ़ाइल)',
    },
    'admin.kyc.union_leader_dl_front': {
      'en': 'Leader driving licence (front)',
      'hi': 'प्रमुख ड्राइविंग लाइसेंस (अगला)',
    },
    'admin.kyc.union_leader_dl_back': {
      'en': 'Leader driving licence (back)',
      'hi': 'प्रमुख ड्राइविंग लाइसेंस (पिछला)',
    },
    'admin.kyc.union_rc_front': {
      'en': 'Leader vehicle RC (front)',
      'hi': 'प्रमुख वाहन आरसी (अगला)',
    },
    'admin.kyc.union_rc_back': {
      'en': 'Leader vehicle RC (back)',
      'hi': 'प्रमुख वाहन आरसी (पिछला)',
    },
    'admin.kyc.union_driver_list_photo': {
      'en': 'Driver list photo',
      'hi': 'ड्राइवर सूची फोटो',
    },
    'admin.panel.title': {
      'en': 'Admin panel',
      'hi': 'एडमिन पैनल',
    },
    'admin.reverify.tooltip': {
      'en': 'Request document re-verification',
      'hi': 'दस्तावेज़ पुनः सत्यापन माँगें',
    },
    'admin.reverify.dialog_title': {
      'en': 'Reset verification & allow upload',
      'hi': 'वेरिफिकेशन रीसेट और अपलोड खोलें',
    },
    'admin.reverify.dialog_body': {
      'en':
          'The user loses the verified badge until documents are approved again. They receive an in-app notification with next steps.',
      'hi':
          'दस्तावेज़ दोबारा मंज़ूर होने तक वेरिफाइड बैज नहीं दिखेगा। उन्हें ऐप में नोटिफिकेशन से अगले कदम मिलेंगे।',
    },
    'admin.reverify.mode_driver': {
      'en': 'Independent driver',
      'hi': 'स्वतंत्र ड्राइवर',
    },
    'admin.reverify.mode_union': {
      'en': 'Union',
      'hi': 'यूनियन',
    },
    'admin.reverify.id_driver': {
      'en': 'Driver user ID (UUID)',
      'hi': 'ड्राइवर यूज़र ID (UUID)',
    },
    'admin.reverify.id_union': {
      'en': 'Union ID (UUID)',
      'hi': 'यूनियन ID (UUID)',
    },
    'admin.reverify.optional_message': {
      'en': 'Custom message (optional)',
      'hi': 'कस्टम संदेश (वैकल्पिक)',
    },
    'admin.reverify.days': {
      'en': 'Upload window (days, 1–30)',
      'hi': 'अपलोड विंडो (दिन, 1–30)',
    },
    'admin.reverify.send': {
      'en': 'Send request',
      'hi': 'भेजें',
    },
    'admin.reverify.invalid_uuid': {
      'en': 'Enter a valid UUID',
      'hi': 'सही UUID दर्ज करें',
    },
    'admin.kyc.user_id': {
      'en': 'User ID',
      'hi': 'यूज़र ID',
    },
    'admin.kyc.union_id': {
      'en': 'Union ID',
      'hi': 'यूनियन ID',
    },
    'admin.directory.drivers_tile': {
      'en': 'Independent drivers',
      'hi': 'स्वतंत्र ड्राइवर',
    },
    'admin.directory.unions_tile': {
      'en': 'Unions',
      'hi': 'यूनियन',
    },
    'admin.directory.tap_to_expand': {
      'en': 'Tap to open — scroll inside',
      'hi': 'खोलने के लिए टैप करें — अंदर स्क्रॉल करें',
    },
    'admin.directory.count_known': {
      'en': '{n} in directory',
      'hi': 'डायरेक्टरी में {n}',
    },
    'admin.directory.pending_tile': {
      'en': 'Pending registrations',
      'hi': 'लंबित पंजीकरण',
    },
    'admin.directory.pending_sub': {
      'en': '{unions} new unions · {drivers} drivers · {udocs} union doc updates',
      'hi': '{unions} नए यूनियन · {drivers} ड्राइवर · {udocs} दस्तावेज़ अपडेट',
    },
    'admin.directory.no_pending': {
      'en': 'Nothing pending right now.',
      'hi': 'अभी कुछ लंबित नहीं।',
    },
    'admin.directory.empty': {
      'en': 'No records',
      'hi': 'कोई रिकॉर्ड नहीं',
    },
    'admin.empty': {
      'en': 'No pending requests',
      'hi': 'कोई लंबित अनुरोध नहीं',
    },
    'admin.empty.hint': {
      'en': 'Union registrations and driver requests will appear here.',
      'hi': 'यूनियन पंजीयन और ड्राइवर अनुरोध यहाँ दिखेंगे।',
    },
    'admin.section.union': {
      'en': 'Pending union registrations',
      'hi': 'लंबित यूनियन पंजीयन',
    },
    'admin.section.driver': {
      'en': 'Pending driver requests',
      'hi': 'लंबित ड्राइवर अनुरोध',
    },
    'admin.section.union_doc_updates': {
      'en': 'Union document updates (re-upload)',
      'hi': 'यूनियन दस्तावेज़ अपडेट (पुनः अपलोड)',
    },
    'admin.union_doc.badge': {
      'en': 'Awaiting your review',
      'hi': 'समीक्षा लंबित',
    },
    'admin.action.approve_docs': {
      'en': 'Approve documents',
      'hi': 'दस्तावेज़ अनुमोदित करें',
    },
    'admin.action.reject_docs': {
      'en': 'Send back',
      'hi': 'वापस भेजें',
    },
    'admin.reject.union_doc_title': {
      'en': 'Reject document update',
      'hi': 'दस्तावेज़ अपडेट अस्वीकार',
    },
    'admin.kyc.documents': {
      'en': 'Documents',
      'hi': 'दस्तावेज़',
    },
    'admin.kyc.contact': {
      'en': 'Applicant contact (form)',
      'hi': 'आवेदक संपर्क (फ़ॉर्म)',
    },
    'admin.kyc.vehicle': {
      'en': 'Vehicle',
      'hi': 'वाहन',
    },
    'admin.kyc.view_prefix': {
      'en': 'View',
      'hi': 'देखें',
    },
    'admin.kyc.viewer_title': {
      'en': 'Document',
      'hi': 'दस्तावेज़',
    },
    'admin.kyc.viewer_open_browser': {
      'en': 'Open in browser',
      'hi': 'ब्राउज़र में खोलें',
    },
    'admin.kyc.viewer_web_hint': {
      'en': 'Open this document in your browser.',
      'hi': 'यह दस्तावेज़ ब्राउज़र में खोलें।',
    },
    'admin.kyc.viewer_image_error': {
      'en': 'Could not load this image. Pull down or use refresh to try again.',
      'hi': 'छवि लोड नहीं हो सकी। रिफ़्रेश करके फिर कोशिश करें।',
    },
    'admin.kyc.viewer_load_error': {
      'en': 'Could not load this document. Check your connection and try again.',
      'hi': 'दस्तावेज़ लोड नहीं हो सका। कनेक्शन जाँचकर फिर कोशिश करें।',
    },
    'kyc.submitted_list.hint_image': {
      'en': 'Image · tap to view',
      'hi': 'फ़ोटो · देखने के लिए टैप करें',
    },
    'kyc.submitted_list.hint_file': {
      'en': 'File · tap to view in app',
      'hi': 'फ़ाइल · ऐप में देखने के लिए टैप करें',
    },
    'admin.kyc.no_document_links': {
      'en':
          'No document links in this request. If uploads exist, check server/DB or ask the applicant to re-submit KYC.',
      'hi': 'इस अनुरोध में कोई दस्तावेज़ लिंक नहीं है।',
    },
    'admin.kyc.aadhaar_front': {
      'en': 'Aadhaar (front)',
      'hi': 'आधार (अगला)',
    },
    'admin.kyc.aadhaar_back': {
      'en': 'Aadhaar (back)',
      'hi': 'आधार (पिछला)',
    },
    'admin.kyc.aadhaar_combined': {
      'en': 'Aadhaar (PDF — front & back)',
      'hi': 'आधार (PDF — आगे व पीछे)',
    },
    'admin.kyc.dl_front': {
      'en': 'Driving licence (front)',
      'hi': 'डीएल (अगला)',
    },
    'admin.kyc.dl_back': {
      'en': 'Driving licence (back)',
      'hi': 'डीएल (पिछला)',
    },
    'admin.kyc.dl_legacy': {
      'en': 'Driving licence (file)',
      'hi': 'डीएल फ़ाइल',
    },
    'admin.kyc.dl_combined': {
      'en': 'Driving licence (PDF — front & back)',
      'hi': 'डीएल (PDF — आगे व पीछे)',
    },
    'admin.kyc.rc': {
      'en': 'RC / registration file',
      'hi': 'आरसी / पंजीकरण फ़ाइल',
    },
    'admin.kyc.rc_front': {
      'en': 'RC (front)',
      'hi': 'आरसी अगला',
    },
    'admin.kyc.rc_back': {
      'en': 'RC (back)',
      'hi': 'आरसी पिछला',
    },
    'admin.kyc.permit': {
      'en': 'Permit',
      'hi': 'परमिट',
    },
    'admin.kyc.insurance': {
      'en': 'Insurance',
      'hi': 'बीमा',
    },
    'admin.kyc.union_leader_aadhaar': {
      'en': 'Leader Aadhaar (legacy)',
      'hi': 'प्रमुख आधार (पुराना)',
    },
    'admin.kyc.union_aadhaar_front': {
      'en': 'Leader Aadhaar (front)',
      'hi': 'प्रमुख आधार अगला',
    },
    'admin.kyc.union_aadhaar_back': {
      'en': 'Leader Aadhaar (back)',
      'hi': 'प्रमुख आधार पिछला',
    },
    'admin.kyc.union_aadhaar_combined': {
      'en': 'Leader Aadhaar (PDF — front & back)',
      'hi': 'प्रमुख आधार (PDF — आगे व पीछे)',
    },
    'admin.kyc.union_leader_dl_combined': {
      'en': 'Leader driving licence (PDF — front & back)',
      'hi': 'प्रमुख डीएल (PDF — आगे व पीछे)',
    },
    'admin.kyc.office_photo': {
      'en': 'Office / union photo',
      'hi': 'कार्यालय / यूनियन फोटो',
    },
    'admin.kyc.union_photo': {
      'en': 'Union photo (alternate)',
      'hi': 'यूनियन फोटो (वैकल्पिक)',
    },
    'admin.kyc.union_rc': {
      'en': 'Leader vehicle RC',
      'hi': 'प्रमुख वाहन आरसी',
    },
    'admin.kyc.union.section_leader': {
      'en': 'Union leader',
      'hi': 'यूनियन प्रमुख',
    },
    'admin.kyc.union.section_applicant': {
      'en': 'Applicant (account)',
      'hi': 'आवेदक (खाता)',
    },
    'admin.kyc.union.contact_lead': {
      'en': 'Union contact',
      'hi': 'यूनियन संपर्क',
    },
    'admin.kyc.fallback_union_name': {
      'en': 'Taxi union',
      'hi': 'टैक्सी यूनियन',
    },
    'home.shell.tab.find_rides': {
      'en': 'Find rides',
      'hi': 'राइड खोजें',
    },
    'home.shell.tab.union': {
      'en': 'Union',
      'hi': 'यूनियन',
    },
    'home.shell.tab.driver': {
      'en': 'Driver',
      'hi': 'ड्राइवर',
    },
    'home.shell.tab.approvals': {
      'en': 'Approvals',
      'hi': 'मंज़ूरी',
    },
    // Profile screen sections and menu items
    'profile.section.trips_passenger': {
      'en': 'Your trips (passenger)',
      'hi': 'आपकी यात्राएँ (यात्री)',
    },
    'profile.section.settings': {
      'en': 'Settings',
      'hi': 'सेटिंग',
    },
    'profile.section.account': {
      'en': 'Account',
      'hi': 'खाता',
    },
    'profile.union_hub.title': {
      'en': 'Union hub',
      'hi': 'यूनियन हब',
    },
    'profile.union_hub.subtitle': {
      'en': 'Schedules, drivers, posters',
      'hi': 'समय सारणी, ड्राइवर, पोस्टर',
    },
    'profile.my_bookings.title': {
      'en': 'My bookings',
      'hi': 'मेरी बुकिंग',
    },
    'profile.my_bookings.subtitle': {
      'en': 'Trips I booked',
      'hi': 'मैंने बुक की यात्राएँ',
    },
    'profile.ratings.title': {
      'en': 'Ratings',
      'hi': 'रेटिंग',
    },
    'profile.ratings.subtitle': {
      'en': 'What passengers said',
      'hi': 'यात्रियों ने क्या कहा',
    },
    'profile.create_ride.title': {
      'en': 'Create ride',
      'hi': 'राइड बनाएँ',
    },
    'profile.create_ride.subtitle': {
      'en': 'Post a taxi ride for passengers',
      'hi': 'यात्रियों के लिए राइड पोस्ट करें',
    },
    'profile.my_rides_driver.title': {
      'en': 'My rides',
      'hi': 'मेरी राइडें',
    },
    'profile.my_rides_driver.subtitle': {
      'en': 'Rides I created as driver',
      'hi': 'ड्राइवर के रूप में बनाई राइडें',
    },
    'profile.submitted_docs.title': {
      'en': 'Submitted documents',
      'hi': 'जमा किए दस्तावेज़',
    },
    'profile.submitted_docs.subtitle': {
      'en': 'Watermarked copies LuhaRide keeps for verification',
      'hi': 'सत्यापन के लिए LuhaRide द्वारा रखी वॉटरमार्क प्रतियाँ',
    },
    'profile.edit_profile.title': {
      'en': 'Edit profile',
      'hi': 'प्रोफ़ाइल संपादित करें',
    },
    'profile.edit_profile.subtitle': {
      'en': 'Name, email, photo',
      'hi': 'नाम, ईमेल, फोटो',
    },
    'profile.change_password.title': {
      'en': 'Change password',
      'hi': 'पासवर्ड बदलें',
    },
    'profile.change_password.subtitle': {
      'en': 'Update password',
      'hi': 'पासवर्ड अपडेट करें',
    },
    'profile.help.title': {
      'en': 'Help',
      'hi': 'सहायता',
    },
    'profile.help.subtitle': {
      'en': 'FAQs and contact',
      'hi': 'प्रश्न और संपर्क',
    },
    'profile.terms.title': {
      'en': 'Terms',
      'hi': 'नियम',
    },
    'profile.terms.subtitle': {
      'en': 'Terms of use',
      'hi': 'उपयोग की शर्तें',
    },
    'profile.logout.dialog_title': {
      'en': 'Logout',
      'hi': 'लॉग आउट',
    },
    'profile.logout.dialog_body': {
      'en': 'Do you want to logout?',
      'hi': 'क्या आप लॉग आउट करना चाहते हैं?',
    },
    'profile.rating_chip.no_ratings': {
      'en': 'No ratings yet',
      'hi': 'अभी कोई रेटिंग नहीं',
    },
    'profile.rating_chip.reviews': {
      'en': 'reviews',
      'hi': 'समीक्षाएँ',
    },
    'profile.hello_user': {
      'en': 'Hello, {name}!',
      'hi': 'नमस्ते, {name}!',
    },
    'profile.hello_fallback': {
      'en': 'Hello, User!',
      'hi': 'नमस्ते!',
    },
    // Account deletion
    'profile.delete_account.title': {
      'en': 'Delete account',
      'hi': 'खाता हटाएँ',
    },
    'profile.delete_account.subtitle': {
      'en': 'Permanently delete your account and data',
      'hi': 'अपना खाता और डेटा स्थायी रूप से हटाएँ',
    },
    'delete_account.dialog_title': {
      'en': 'Delete account?',
      'hi': 'खाता हटाएँ?',
    },
    'delete_account.warning': {
      'en': 'This action cannot be undone. All your data will be permanently deleted:',
      'hi': 'यह क्रिया वापस नहीं ली जा सकती। आपका सारा डेटा स्थायी रूप से हटा दिया जाएगा:',
    },
    'delete_account.data_list': {
      'en': '• Profile and personal information\n• Trips you created\n• Your bookings\n• Reviews you gave\n• Submitted documents\n• All account history',
      'hi': '• प्रोफ़ाइल और व्यक्तिगत जानकारी\n• आपके द्वारा बनाई गई राइडें\n• आपकी बुकिंग\n• आपकी दी गई समीक्षाएँ\n• जमा किए दस्तावेज़\n• सभी खाता इतिहास',
    },
    'delete_account.password_label': {
      'en': 'Enter your password to confirm',
      'hi': 'पुष्टि के लिए अपना पासवर्ड दर्ज करें',
    },
    'delete_account.password_hint': {
      'en': 'Your password',
      'hi': 'आपका पासवर्ड',
    },
    'delete_account.password_required': {
      'en': 'Password is required',
      'hi': 'पासवर्ड आवश्यक है',
    },
    'delete_account.confirm_button': {
      'en': 'Delete my account',
      'hi': 'मेरा खाता हटाएँ',
    },
    'delete_account.deleting': {
      'en': 'Deleting account...',
      'hi': 'खाता हटाया जा रहा है...',
    },
    'delete_account.success': {
      'en': 'Your account has been deleted',
      'hi': 'आपका खाता हटा दिया गया है',
    },
    'delete_account.incorrect_password': {
      'en': 'Incorrect password. Please try again.',
      'hi': 'गलत पासवर्ड। कृपया पुनः प्रयास करें।',
    },
    'delete_account.failed': {
      'en': 'Failed to delete account. Please try again.',
      'hi': 'खाता हटाने में विफल। कृपया पुनः प्रयास करें।',
    },
    'delete_account.no_password_error': {
      'en': 'This account was created via OTP and has no password. Please contact support to delete your account.',
      'hi': 'यह खाता OTP से बनाया गया था और इसका कोई पासवर्ड नहीं है। अपना खाता हटाने के लिए कृपया सहायता से संपर्क करें।',
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

