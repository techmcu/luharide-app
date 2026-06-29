/**
 * Single source of truth for user-facing notification copy (in-app + FCM push).
 *
 * Notifications are composed server-side, so the server must render ONE language
 * per recipient — never English + Hindi jammed into the same title/body. Each key
 * holds short, professional `en` and `hi` variants. Pick with `notifText(key, lang)`.
 *
 * `lang` is the user's stored `preferred_language` (see migration 068). Anything
 * other than 'hi' falls back to English (the app's own default), so a missing or
 * unknown value can never crash a notification.
 */

const DEFAULT_LANG = 'en';

function normLang(lang) {
  return lang === 'hi' ? 'hi' : DEFAULT_LANG;
}

const TEXT = {
  // Independent driver's ride auto-started by the lifecycle job (sent to driver).
  trip_auto_started: {
    en: {
      title: 'Your ride has started',
      body: 'Your ride started automatically at its scheduled time. Drive safe and stay in touch with your passengers.',
    },
    hi: {
      title: 'आपकी राइड शुरू हो गई',
      body: 'आपकी राइड तय समय पर अपने-आप शुरू हो गई है। सुरक्षित यात्रा करें और यात्रियों से संपर्क में रहें।',
    },
  },

  // A pending booking auto-cancelled because the ride started without confirmation.
  booking_auto_cancelled: {
    en: {
      title: 'Booking not confirmed',
      body: 'The driver did not confirm your booking before the ride started. Please book another ride.',
    },
    hi: {
      title: 'बुकिंग कन्फर्म नहीं हुई',
      body: 'राइड शुरू होने से पहले ड्राइवर ने आपकी बुकिंग कन्फर्म नहीं की। कृपया दूसरी राइड बुक करें।',
    },
  },

  // Booking auto-cancelled because the driver manually started the ride.
  booking_cancelled_ride_started: {
    en: {
      title: 'Booking cancelled',
      body: 'Your booking was cancelled because the driver started the ride without confirming your request.',
    },
    hi: {
      title: 'बुकिंग रद्द हो गई',
      body: 'ड्राइवर ने आपकी रिक्वेस्ट कन्फर्म किए बिना राइड शुरू कर दी, इसलिए आपकी बुकिंग रद्द हो गई।',
    },
  },

  // Trip completed (sent to each passenger).
  trip_completed: {
    en: {
      title: 'Happy journey!',
      body: 'We hope you had a great trip with LuhaRide.',
    },
    hi: {
      title: 'शुभ यात्रा!',
      body: 'आशा है आपका सफ़र LuhaRide के साथ अच्छा रहा।',
    },
  },
};

/**
 * Resolve a notification's {title, body} for a recipient's language.
 * Returns null for an unknown key so callers fail loudly in tests, not in prod.
 */
function notifText(key, lang) {
  const entry = TEXT[key];
  if (!entry) return null;
  return entry[normLang(lang)] || entry[DEFAULT_LANG];
}

/**
 * Day-rotating union "new rides published" broadcast copy (sent to passengers).
 * 7 upbeat variants keyed by JS getDay() (0=Sun..6=Sat) in each language, so the
 * message feels fresh and matches the reader's language. `unionName` is injected.
 */
const UNION_RIDE_MESSAGES = {
  en: [
    { title: '🚖 {union} — new rides are live!', body: 'Sunday travel never stops! Lock your seat now, don’t wait. 😄' },
    { title: '🚖 {union} — first rides of the week!', body: 'New week, new rides! Book now before seats fill up. 💪' },
    { title: '🚖 {union} — your ride is ready!', body: 'Mountain journeys, your own ride! Book quickly. 🏔️' },
    { title: '🚖 {union} — rides are live!', body: 'Midweek already — the journey awaits! Book now. 🎯' },
    { title: '🚖 {union} — cars are ready!', body: 'Grab your seat now, don’t say we didn’t tell you! 😎' },
    { title: '🚖 {union} — weekend rides!', body: 'Get in the holiday mood, lock your trip! Check now. 🚀' },
    { title: '🚖 {union} — weekend special rides!', body: 'It’s Saturday, hit the road! Few seats left, hurry. 💺' },
  ],
  hi: [
    { title: '🚖 {union} — नई राइडें आ गईं!', body: 'इतवार को भी सफ़र रुकता नहीं! सीट पक्की करो, देर मत करो 😄' },
    { title: '🚖 {union} — हफ्ते की पहली सवारी!', body: 'नया हफ्ता, नई राइड! अभी बुक करो, सीटें उड़ जाएँगी 💪' },
    { title: '🚖 {union} — अपणी सवारी तैयार भई!', body: 'पहाड़ों का सफ़र, अपणी गाड़ी! जल्दी बुक करो 🏔️' },
    { title: '🚖 {union} — राइडें लाइव!', body: 'आधा हफ्ता निकल गया, सफ़र अभी बाकी है! बुक करो 🎯' },
    { title: '🚖 {union} — गाड़ियाँ तैयार!', body: 'भाई सीट पक्की कर लो, बाद में मत बोलना बताया नहीं! 😎' },
    { title: '🚖 {union} — वीकेंड की सवारी!', body: 'छुट्टी का मूड बनाओ, सफ़र पक्का करो! अभी देखो 🚀' },
    { title: '🚖 {union} — छुट्टी स्पेशल राइडें!', body: 'शनिवार है, निकल पड़ो! सीटें कम हैं, जल्दी करो 💺' },
  ],
};

function unionRideText(lang, dayIndex, unionName) {
  const list = UNION_RIDE_MESSAGES[normLang(lang)];
  const idx = ((dayIndex % 7) + 7) % 7; // safe wrap for any integer
  const { title, body } = list[idx];
  return { title: title.replace('{union}', unionName), body };
}

module.exports = { notifText, unionRideText, DEFAULT_LANG, normLang };
