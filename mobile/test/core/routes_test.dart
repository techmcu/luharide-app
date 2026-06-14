import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:luharide/core/routes.dart';

void main() {
  group('AppRoutes constants', () {
    test('all routes start with /', () {
      final routes = [
        AppRoutes.landing,
        AppRoutes.home,
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.forgotPassword,
        AppRoutes.searchTrips,
        AppRoutes.tripDetails,
        AppRoutes.createTrip,
        AppRoutes.myRides,
        AppRoutes.passengerRides,
        AppRoutes.profile,
        AppRoutes.editProfile,
        AppRoutes.help,
        AppRoutes.notifications,
      ];
      for (final r in routes) {
        expect(r.startsWith('/'), true, reason: '$r should start with /');
      }
    });

    test('no duplicate route values', () {
      final routes = [
        AppRoutes.landing,
        AppRoutes.home,
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.forgotPassword,
        AppRoutes.searchTrips,
        AppRoutes.tripDetails,
        AppRoutes.createTrip,
        AppRoutes.myRides,
        AppRoutes.passengerRides,
        AppRoutes.profile,
        AppRoutes.editProfile,
        AppRoutes.help,
        AppRoutes.notifications,
      ];
      expect(routes.toSet().length, routes.length);
    });
  });

  group('onGenerateRoute', () {
    test('returns route for known paths', () {
      final knownPaths = [
        AppRoutes.landing,
        AppRoutes.home,
        AppRoutes.login,
        AppRoutes.signup,
        AppRoutes.forgotPassword,
        AppRoutes.searchTrips,
        AppRoutes.createTrip,
        AppRoutes.myRides,
        AppRoutes.passengerRides,
        AppRoutes.profile,
        AppRoutes.editProfile,
        AppRoutes.help,
        AppRoutes.notifications,
      ];
      for (final path in knownPaths) {
        final route = onGenerateRoute(RouteSettings(name: path));
        expect(route, isNotNull, reason: 'Route for $path should not be null');
        expect(route, isA<MaterialPageRoute>());
      }
    });

    test('returns route for trip detail with ID', () {
      final route = onGenerateRoute(
        const RouteSettings(name: '/trip/abc-123-def'),
      );
      expect(route, isNotNull);
      expect(route, isA<MaterialPageRoute>());
    });

    test('returns null for unknown route', () {
      final route = onGenerateRoute(
        const RouteSettings(name: '/unknown-page'),
      );
      expect(route, isNull);
    });
  });
}
