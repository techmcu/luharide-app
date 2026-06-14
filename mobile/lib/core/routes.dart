import 'package:flutter/material.dart';
import '../features/landing/presentation/screens/landing_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/auth/presentation/screens/simple_login_screen.dart';
import '../features/auth/presentation/screens/simple_signup_screen.dart';
import '../features/auth/presentation/screens/forgot_password_screen.dart';
import '../features/trips/presentation/screens/search_trips_screen.dart';
import '../features/trips/presentation/screens/trip_details_screen.dart';
import '../features/trips/presentation/screens/create_trip_screen.dart';
import '../features/trips/presentation/screens/my_rides_screen.dart';
import '../features/trips/presentation/screens/passenger_my_rides_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/profile/presentation/screens/edit_profile_screen.dart';
import '../features/profile/presentation/screens/help_screen.dart';
import '../features/notifications/presentation/screens/notifications_screen.dart';

abstract class AppRoutes {
  static const landing = '/';
  static const home = '/home';
  static const login = '/login';
  static const signup = '/signup';
  static const forgotPassword = '/forgot-password';
  static const searchTrips = '/search';
  static const tripDetails = '/trip'; // /trip/:id
  static const createTrip = '/create-trip';
  static const myRides = '/my-rides';
  static const passengerRides = '/my-bookings';
  static const profile = '/profile';
  static const editProfile = '/profile/edit';
  static const help = '/help';
  static const notifications = '/notifications';
}

Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  final uri = Uri.tryParse(settings.name ?? '');
  final path = uri?.path ?? settings.name ?? '';

  switch (path) {
    case AppRoutes.landing:
      return _page(const LandingScreen(), settings);
    case AppRoutes.home:
      return _page(const HomeScreen(), settings);
    case AppRoutes.login:
      return _page(const SimpleLoginScreen(), settings);
    case AppRoutes.signup:
      final userType = (settings.arguments is Map)
          ? (settings.arguments as Map)['userType']?.toString() ?? 'passenger'
          : 'passenger';
      return _page(SimpleSignupScreen(userType: userType), settings);
    case AppRoutes.forgotPassword:
      return _page(const ForgotPasswordScreen(), settings);
    case AppRoutes.searchTrips:
      return _page(const SearchTripsScreen(), settings);
    case AppRoutes.createTrip:
      return _page(const CreateTripScreen(), settings);
    case AppRoutes.myRides:
      return _page(const MyRidesScreen(), settings);
    case AppRoutes.passengerRides:
      return _page(const PassengerMyRidesScreen(), settings);
    case AppRoutes.profile:
      return _page(const ProfileScreen(), settings);
    case AppRoutes.editProfile:
      return _page(const EditProfileScreen(), settings);
    case AppRoutes.help:
      return _page(const HelpScreen(), settings);
    case AppRoutes.notifications:
      return _page(const NotificationsScreen(), settings);
    default:
      if (path.startsWith(AppRoutes.tripDetails) && path.length > AppRoutes.tripDetails.length + 1) {
        final tripId = path.substring(AppRoutes.tripDetails.length + 1);
        return _page(TripDetailsScreen(tripId: tripId), settings);
      }
      return null;
  }
}

MaterialPageRoute<T> _page<T>(Widget child, RouteSettings settings) {
  return MaterialPageRoute<T>(builder: (_) => child, settings: settings);
}
