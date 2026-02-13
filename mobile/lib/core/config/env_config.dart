class EnvConfig {
  // API Configuration (Use computer IP for phone access)
  static const String apiBaseUrl = 'http://10.135.178.9:3000/api';
  static const String socketUrl = 'http://10.135.178.9:3000';
  
  // Google Maps API Key
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';
  
  // Razorpay Keys
  static const String razorpayKeyId = 'YOUR_RAZORPAY_KEY_ID';
  static const String razorpayKeySecret = 'YOUR_RAZORPAY_KEY_SECRET';
  
  // Firebase Configuration
  // Add Firebase config after Firebase setup
  
  // Auth Token (managed by AuthService)
  static String? authToken;
  
  static Future<void> init() async {
    // Initialize any async configurations here
    // e.g., Firebase, Hive, SharedPreferences, etc.
  }
}
