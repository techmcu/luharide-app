class EnvConfig {
  // Production API (Hostinger VPS). Set _useLocalApi true only when running backend locally for debug.
  static const bool _useLocalApi = false;
  static const String apiBaseUrl = _useLocalApi ? 'http://10.0.2.2:3000/api' : 'http://76.13.243.157:3000/api';
  static const String socketUrl = _useLocalApi ? 'http://10.0.2.2:3000' : 'http://76.13.243.157:3000';
  
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
