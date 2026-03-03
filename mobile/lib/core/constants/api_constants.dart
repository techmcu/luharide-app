class ApiConstants {
  // Production API (Hostinger VPS) – same as EnvConfig.apiBaseUrl
  static const String baseUrl = 'http://76.13.243.157:3000/api';
  
  // Authentication Endpoints
  static const String sendOTP = '/auth/send-otp';
  static const String verifyOTP = '/auth/verify-otp';
  static const String refreshToken = '/auth/refresh-token';
  static const String logout = '/auth/logout';
  static const String currentUser = '/auth/me';
  static const String updateProfile = '/auth/profile';
  
  // User Endpoints (legacy - to be updated)
  static const String userProfile = '/users/profile';
  static const String uploadDocument = '/users/upload-document';
  
  // Routes Endpoints
  static const String searchRoutes = '/routes/search';
  static const String popularRoutes = '/routes/popular';
  
  // Trips Endpoints
  static const String trips = '/trips';
  static const String searchTrips = '/trips/search';
  static const String myTrips = '/trips/my-trips';
  static const String locationSuggestions = '/trips/locations';
  static const String tripDetails = '/trips';
  static const String tripSeats = '/trips/{id}/seats';
  
  // Bookings Endpoints
  static const String createBooking = '/bookings';
  static const String bookingDetails = '/bookings';
  static const String cancelBooking = '/bookings/{id}/cancel';
  static const String userBookings = '/bookings/user/{userId}';
  
  // Driver Verification
  static const String driverVerification = '/driver-verification';
  static const String adminDriverRequests = '/admin/driver-requests';
  static const String adminUnionRequests = '/admin/union-requests';

  // Notifications
  // Use leading slash so final URL is: {baseUrl}/notifications
  static const String notifications = '/notifications';

  // Union Admin
  static const String unionDashboard = '/union/dashboard';

  // Driver Endpoints
  static const String driverTrips = '/drivers/trips';
  static const String updateLocation = '/drivers/location';
  static const String startTrip = '/trips/{id}/start';
  static const String completeTrip = '/trips/{id}/complete';
  // Payments Endpoints
  static const String createPayment = '/payments/create';
  static const String verifyPayment = '/payments/verify';
  static const String paymentHistory = '/payments/history';
  
  // Reviews / Ratings Endpoints
  static const String submitReview = '/reviews';
  static const String driverReviews = '/reviews/driver/{id}';
  static const String myReviews = '/reviews/my-reviews';
  static String userRatingSummary(String userId) => '/reviews/summary/$userId';
  static String userReviews(String userId, {int page = 1, int limit = 20}) =>
      '/reviews/user/$userId/reviews?page=$page&limit=$limit';
  static String rateBooking(String bookingId) => '/bookings/$bookingId/rate';
}
