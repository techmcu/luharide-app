import 'package:dio/dio.dart';
import '../core/constants/api_constants.dart';
import '../models/trip_model.dart';
import 'api_service.dart';

class TripService {
  final ApiService _apiService = ApiService();

  /// Create a new trip (Driver only)
  Future<Map<String, dynamic>> createTrip({
    required String fromLocation,
    required String toLocation,
    required DateTime departureTime,
    required double farePerSeat,
    required String vehicleNumber,
    int totalSeats = 7,
    List<String> stops = const [],
    bool requireApproval = true,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.trips,
        data: {
          'from_location': fromLocation,
          'to_location': toLocation,
          'departure_time': departureTime.toIso8601String(),
          'fare_per_seat': farePerSeat,
          'total_seats': totalSeats,
          'vehicle_number': vehicleNumber,
          'stops': stops,
          'require_approval': requireApproval,
        },
      );

      return {
        'success': true,
        'trip': TripModel.fromJson(response.data['data']['trip']),
        'message': response.data['message'] ?? 'Trip created successfully',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to create trip',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }

  /// Search trips
  Future<Map<String, dynamic>> searchTrips({
    required String from,
    required String to,
    required DateTime date,
  }) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      final response = await _apiService.get(
        ApiConstants.searchTrips,
        queryParameters: {
          'from': from,
          'to': to,
          'date': dateStr,
        },
      );

      final List<dynamic> tripsJson = response.data['data']['trips'] ?? [];
      final List<TripModel> trips = tripsJson
          .map((json) => TripModel.fromJson(json))
          .toList();

      return {
        'success': true,
        'trips': trips,
        'count': response.data['data']['count'] ?? 0,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to search trips',
        'trips': <TripModel>[],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred',
        'trips': <TripModel>[],
      };
    }
  }

  /// Get booked/pending seats for a trip (for seat selection - prevents double booking)
  Future<Map<String, dynamic>> getTripBookedSeats(String tripId) async {
    try {
      final response = await _apiService.get(
        '${ApiConstants.tripDetails}/$tripId/booked-seats',
      );

      final data = response.data['data'] ?? {};
      final List<dynamic> bookedJson = data['booked'] ?? [];
      final List<dynamic> pendingJson = data['pending'] ?? [];

      // Robust parsing - JSON may return num (int/double)
      int toInt(dynamic e) => (e is num) ? e.toInt() : int.tryParse(e.toString()) ?? 0;
      final bookedList = bookedJson.map(toInt).where((n) => n > 0).toList();
      final pendingList = pendingJson.map(toInt).where((n) => n > 0).toList();

      return {
        'success': true,
        'booked': bookedList,
        'pending': pendingList,
        'total_seats': (data['total_seats'] is num) ? (data['total_seats'] as num).toInt() : 7,
        'available_seats': (data['available_seats'] is num) ? (data['available_seats'] as num).toInt() : null,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to load seats',
        'booked': <int>[],
        'pending': <int>[],
      };
    } catch (e) {
      return {
        'success': false,
        'booked': <int>[],
        'pending': <int>[],
      };
    }
  }

  /// Get trip details (includes booked_seats, pending_seats for seat selection)
  Future<Map<String, dynamic>> getTripDetails(String tripId) async {
    try {
      final response = await _apiService.get('${ApiConstants.tripDetails}/$tripId');
      final data = response.data['data'] ?? {};
      final tripJson = data['trip'] ?? data;

      final bookedList = (data['booked_seats'] ?? []).map((e) => (e is num) ? e.toInt() : int.tryParse(e.toString()) ?? 0).where((n) => n > 0).toList();
      final pendingList = (data['pending_seats'] ?? []).map((e) => (e is num) ? e.toInt() : int.tryParse(e.toString()) ?? 0).where((n) => n > 0).toList();

      return {
        'success': true,
        'trip': TripModel.fromJson(tripJson is Map ? Map<String, dynamic>.from(tripJson) : {}),
        'booked_seats': bookedList,
        'pending_seats': pendingList,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to get trip details',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }

  /// Get my trips (Driver only)
  Future<Map<String, dynamic>> getMyTrips({String? status}) async {
    try {
      final response = await _apiService.get(
        ApiConstants.myTrips,
        queryParameters: status != null ? {'status': status} : null,
      );

      final List<dynamic> tripsJson = response.data['data']['trips'] ?? [];
      final List<TripModel> trips = tripsJson
          .map((json) => TripModel.fromJson(json))
          .toList();

      return {
        'success': true,
        'trips': trips,
        'count': response.data['data']['count'] ?? 0,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to get trips',
        'trips': <TripModel>[],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred',
        'trips': <TripModel>[],
      };
    }
  }

  /// Create booking (Passenger)
  Future<Map<String, dynamic>> createBooking({
    required String tripId,
    required List<int> seatNumbers,
  }) async {
    try {
      final response = await _apiService.post(
        ApiConstants.createBooking,
        data: {
          'trip_id': tripId,
          'seat_numbers': seatNumbers,
        },
      );

      return {
        'success': true,
        'message': response.data['message'] ?? 'Booking confirmed',
        'booking': response.data['data']?['booking'],
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to create booking',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }

  /// Get my bookings (Passenger)
  Future<Map<String, dynamic>> getMyBookings() async {
    try {
      final response = await _apiService.get('${ApiConstants.createBooking}/my-bookings');
      final List<dynamic> bookingsJson = response.data['data']['bookings'] ?? [];
      return {
        'success': true,
        'bookings': bookingsJson,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to get bookings',
        'bookings': <dynamic>[],
      };
    } catch (e) {
      return {
        'success': false,
        'bookings': <dynamic>[],
      };
    }
  }

  /// Driver respond to booking (accept/reject)
  Future<Map<String, dynamic>> respondToBooking(String bookingId, String action) async {
    try {
      final response = await _apiService.put(
        '${ApiConstants.createBooking}/$bookingId/respond',
        data: {'action': action},
      );
      return {
        'success': true,
        'message': response.data['message'],
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed',
      };
    } catch (e) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  /// Delete trip (Driver only) - only when no bookings
  Future<Map<String, dynamic>> deleteTrip(String tripId) async {
    try {
      final response = await _apiService.delete(
        '${ApiConstants.tripDetails}/$tripId',
      );
      return {
        'success': true,
        'message': response.data['message'] ?? 'Ride deleted',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Cannot delete ride',
      };
    } catch (e) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  /// Get trip bookings (Driver only - for their own trips)
  Future<Map<String, dynamic>> getTripBookings(String tripId) async {
    try {
      final response = await _apiService.get(
        '${ApiConstants.tripDetails}/$tripId/bookings',
      );

      final List<dynamic> bookingsJson = response.data['data']['bookings'] ?? [];
      return {
        'success': true,
        'bookings': bookingsJson,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': e.response?.data['message'] ?? 'Failed to get bookings',
        'bookings': <dynamic>[],
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred',
        'bookings': <dynamic>[],
      };
    }
  }

  /// Get location suggestions
  Future<List<String>> getLocationSuggestions(String query) async {
    try {
      if (query.length < 2) {
        return [];
      }

      final response = await _apiService.get(
        ApiConstants.locationSuggestions,
        queryParameters: {'q': query},
      );

      final List<dynamic> suggestionsJson = response.data['data']['suggestions'] ?? [];
      return suggestionsJson.map((s) => s.toString()).toList();
    } catch (e) {
      return [];
    }
  }
}
