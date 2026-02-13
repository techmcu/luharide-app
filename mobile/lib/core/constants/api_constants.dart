class ApiConstants {
  // Base URLs (Use computer IP for phone access)
  static const String baseUrl = 'http://10.135.178.9:3000/api';
  
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

  // Notifications
  // Use leading slash so final URL is: {baseUrl}/notifications
  static const String notifications = '/notifications';

  // Driver Endpoints
  static const String driverTrips = '/drivers/trips';
  static const String updateLocation = '/drivers/location';
  static const String startTrip = '/trips/{id}/start';
  static const String completeTrip = '/trips/{id}/complete';
  // Payments Endpoints
  static const String createPayment = '/payments/create';
  static const String verifyPayment = '/payments/verify';
  static const String paymentHistory = '/payments/history';
  
  // Reviews Endpoints
  static const String submitReview = '/reviews';
  static const String driverReviews = '/reviews/driver/{id}';
}
