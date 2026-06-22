import '../config/env_config.dart';

class ApiConstants {
  /// REST base including `/api` — always [EnvConfig.apiBaseUrl] (dart-define / debug / default).
  static String get baseUrl => EnvConfig.apiBaseUrl;
  
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
  static const String routeEstimate = '/trips/estimate';
  static const String reverseGeocode = '/trips/reverse-geocode';
  static const String tripDetails = '/trips';
  static const String tripSeats = '/trips/{id}/seats';
  
  // Bookings Endpoints
  static const String createBooking = '/bookings';
  static const String bookingDetails = '/bookings';
  static const String cancelBooking = '/bookings/{id}/cancel';
  static const String userBookings = '/bookings/user/{userId}';
  
  // Driver Verification
  static const String driverVerification = '/driver-verification';
  /// Watermarked / processed doc URLs the user submitted (driver + union), JSON only — cheap for CI/clients.
  static const String submittedDocuments = '/kyc/submitted-documents';
  static const String adminDriverRequests = '/admin/driver-requests';
  static const String adminUnionRequests = '/admin/union-requests';
  /// Approved unions with documents_status = pending (re-upload submitted).
  static const String adminUnionDocRequests = '/admin/union-doc-requests';
  static const String adminDirectoryIndependentDrivers = '/admin/directory/independent-drivers';
  static const String adminDirectoryUnions = '/admin/directory/unions';
  static String adminKycDriverReverify(String userId) => '/admin/kyc/drivers/$userId/reverify';
  static String adminKycUnionReverify(String unionId) => '/admin/kyc/unions/$unionId/reverify';

  // Platform Admin
  static const String platformDashboard = '/platform-admin/dashboard';
  static const String platformUsers = '/platform-admin/users';
  static String platformUserDetail(String id) => '/platform-admin/users/$id';
  static String platformUserToggleActive(String id) => '/platform-admin/users/$id/active';
  static const String platformTrips = '/platform-admin/trips';
  static String platformTripDetail(String id) => '/platform-admin/trips/$id';
  static String platformTripCancel(String id) => '/platform-admin/trips/$id/cancel';
  static const String platformRevenue = '/platform-admin/revenue';
  static const String platformDailyStats = '/platform-admin/daily-stats';
  static const String platformExportCsv = '/platform-admin/export-csv';

  // Platform Admin — Phase 2
  static const String platformBulkNotification = '/platform-admin/notifications/bulk';
  static const String platformBroadcastHistory = '/platform-admin/notifications/history';
  static const String platformComplaints = '/platform-admin/complaints';
  static String platformComplaintDetail(String id) => '/platform-admin/complaints/$id';
  static String platformComplaintResolve(String id) => '/platform-admin/complaints/$id/resolve';
  static const String platformConfig = '/platform-admin/config';
  static const String platformUnionFcm = '/platform-admin/union-fcm';
  static const String platformUnionFcmGlobal = '/platform-admin/union-fcm/global';
  static String platformUnionFcmToggle(String unionId) => '/platform-admin/union-fcm/$unionId';
  static const String platformComplaintSubmit = '/platform-admin/complaints/submit';
  static const String platformComplaintsMine = '/platform-admin/complaints/mine';

  // Uploads
  static const String uploadDriverDoc = '/uploads/driver-doc';
  static const String uploadUnionDoc = '/uploads/union-doc';

  // Notifications
  // Use leading slash so final URL is: {baseUrl}/notifications
  static const String notifications = '/notifications';

  // Union Admin
  static const String unionDashboard = '/union/dashboard';
  static const String unionContactLog = '/union/contact-log';
  static const String unionContactStats = '/union/contact-stats';

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
  static String userReviewBundle(String userId) => '/reviews/user/$userId/bundle';
  static String userReviews(String userId, {int page = 1, int limit = 20}) =>
      '/reviews/user/$userId/reviews?page=$page&limit=$limit';
  static String rateBooking(String bookingId) => '/bookings/$bookingId/rate';
  static String ratingContext(String bookingId) => '/bookings/$bookingId/rating-context';
}
