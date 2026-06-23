import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/api_constants.dart';
import '../core/utils/api_error_messages.dart';
import '../models/trip_model.dart';
import '../models/picked_location.dart';
import 'api_service.dart';

/// Safely parse a JSON seat list into `List<int>`. Never throws regardless of
/// shape (null, non-list, or elements that are num / String / null). Keeps
/// seats >= 1. Uses an explicit List + typed loop to avoid the dynamic-receiver
/// `.where` type error (`'(dynamic) => dynamic' is not a subtype of ... bool`).
List<int> _parseSeatList(dynamic raw) {
  if (raw is! List) return const <int>[];
  final seats = <int>[];
  for (final e in raw) {
    final n = e is num ? e.toInt() : int.tryParse(e?.toString() ?? '');
    if (n != null && n >= 1) seats.add(n);
  }
  return seats;
}

/// Safely parse a co-passenger list into typed maps. Never throws — non-map
/// entries are skipped so one malformed row can't break the whole list.
List<Map<String, dynamic>> _parseCoPassengers(dynamic raw) {
  if (raw is! List) return const <Map<String, dynamic>>[];
  final out = <Map<String, dynamic>>[];
  for (final e in raw) {
    if (e is Map) out.add(Map<String, dynamic>.from(e));
  }
  return out;
}

class TripService {
  final ApiService _apiService = ApiService();

  /// Create a new trip (Driver only)
  Future<Map<String, dynamic>> createTrip({
    required String fromLocation,
    required String toLocation,
    required DateTime departureTime,
    required double farePerSeat,
    required String vehicleNumber,
    required double estimatedDurationHours,
    int totalSeats = 7,
    List<String> stops = const [],
    bool requireApproval = true,
    String? luggageAllowancePerPassenger,
    // Optional pickup/drop coordinates (from location autocomplete). When given,
    // backend computes distance and enforces the distance-based max fare.
    double? fromLat,
    double? fromLng,
    double? toLat,
    double? toLng,
  }) async {
    try {
      final data = <String, dynamic>{
        'from_location': fromLocation,
        'to_location': toLocation,
        'departure_time': departureTime.toUtc().toIso8601String(),
        'fare_per_seat': farePerSeat,
        'total_seats': totalSeats,
        'vehicle_number': vehicleNumber,
        'stops': stops,
        'require_approval': requireApproval,
        'estimated_duration_hours': estimatedDurationHours,
      };
      if (fromLat != null && fromLng != null) {
        data['from_lat'] = fromLat;
        data['from_lng'] = fromLng;
      }
      if (toLat != null && toLng != null) {
        data['to_lat'] = toLat;
        data['to_lng'] = toLng;
      }
      final lug = luggageAllowancePerPassenger?.trim();
      if (lug != null && lug.isNotEmpty) {
        data['luggage_allowance_per_passenger'] = lug;
      }
      final response = await _apiService.post(
        ApiConstants.trips,
        data: data,
      );

      final respData = response.data['data'] ?? {};
      return {
        'success': true,
        'trip': TripModel.fromJson(respData['trip'] ?? {}),
        'message': response.data['message'] ?? 'Trip created successfully',
      };
    } on DioException catch (e) {
      final msg = dioResponseMessage(e) ?? 'Failed to create trip';
      // Log server response to find 400 cause (remove after fix confirmed)
      if (kDebugMode && e.response != null) {
        debugPrint('Create trip error: status=${e.response!.statusCode} message=$msg');
      }
      return {
        'success': false,
        'message': msg,
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'An unexpected error occurred',
      };
    }
  }

  /// Search trips ([limit] default 40, [offset] for paging — server caps for small VPS)
  /// Pass [cancelToken] to abort in-flight requests (e.g., new search or screen dispose).
  Future<Map<String, dynamic>> searchTrips({
    required String from,
    required String to,
    required DateTime date,
    String? routeId,
    int limit = 40,
    int offset = 0,
    CancelToken? cancelToken,
    // When coordinates are provided, the backend switches to proximity + corridor
    // (along-route) matching with rating ranking. Otherwise plain text search.
    double? fromLat,
    double? fromLng,
    double? toLat,
    double? toLng,
  }) async {
    try {
      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final query = <String, dynamic>{
        'date': dateStr,
        // Always send from/to for union_schedules text search (case-insensitive LIKE),
        // even when we provide a canonical route_id for trips table.
        'from': from,
        'to': to,
        'limit': limit,
        'offset': offset,
      };
      if (fromLat != null && fromLng != null) {
        query['from_lat'] = fromLat;
        query['from_lng'] = fromLng;
      }
      if (toLat != null && toLng != null) {
        query['to_lat'] = toLat;
        query['to_lng'] = toLng;
      }
      if (routeId != null && routeId.isNotEmpty) {
        query['route_id'] = routeId;
      }

      final response = await _apiService.get(
        ApiConstants.searchTrips,
        queryParameters: query,
        cancelToken: cancelToken,
      );

      final data = response.data['data'] ?? {};
      final List<dynamic> tripsJson = data['trips'] ?? [];
      final List<TripModel> trips = tripsJson
          .map((json) => TripModel.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();

      // Union rides (union-managed schedules) are returned as simple JSON objects.
      // Older servers may not send this field, so default to empty list.
      final List<dynamic> unionRides = List<dynamic>.from(
        data['unionRides'] ??
            data['union_rides'] ?? // fallback if backend uses snake_case
            const [],
      );

      return {
        'success': true,
        'trips': trips,
        'unionRides': unionRides,
        'count': response.data['data']?['count'] ?? trips.length,
      };
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        return {'success': false, 'cancelled': true, 'trips': <TripModel>[]};
      }
      return {
        'success': false,
        'message': dioResponseMessage(e) ?? 'Failed to search trips',
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
      final List<dynamic> lockedJson = data['locked'] ?? [];

      // Robust parsing - JSON may return num (int/double)
      int toInt(dynamic e) => (e is num) ? e.toInt() : int.tryParse(e.toString()) ?? 0;
      final bookedList = bookedJson.map(toInt).where((n) => n > 0).toList();
      final pendingList = pendingJson.map(toInt).where((n) => n > 0).toList();
      final lockedList = lockedJson.map(toInt).where((n) => n > 0).toList();

      return {
        'success': true,
        'booked': bookedList,
        'pending': pendingList,
        'locked': lockedList,
        'total_seats': (data['total_seats'] is num) ? (data['total_seats'] as num).toInt() : 7,
        'available_seats': (data['available_seats'] is num) ? (data['available_seats'] as num).toInt() : null,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': dioResponseMessage(e) ?? 'Failed to load seats',
        'booked': <int>[],
        'pending': <int>[],
        'locked': <int>[],
      };
    } catch (e) {
      return {
        'success': false,
        'booked': <int>[],
        'pending': <int>[],
        'locked': <int>[],
      };
    }
  }

  /// Driver reserves (locks) their own unbooked seats so no passenger can book
  /// them — e.g. holding a seat for a relative. [note] is an optional label.
  /// Returns the full set of locked seats on success.
  Future<Map<String, dynamic>> lockSeats(
    String tripId,
    List<int> seatNumbers, {
    String? note,
  }) async {
    try {
      final response = await _apiService.post(
        '${ApiConstants.tripDetails}/$tripId/lock-seats',
        data: {
          'seat_numbers': seatNumbers,
          if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        },
      );
      return {
        'success': true,
        'message': response.data['message'] ?? 'Seat reserved',
        'locked': _parseSeatList(response.data['data']?['locked_seats']),
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': dioResponseMessage(e) ?? 'Could not reserve seat',
      };
    } catch (e) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  /// Driver releases previously-reserved seats so passengers can book them again.
  Future<Map<String, dynamic>> unlockSeats(String tripId, List<int> seatNumbers) async {
    try {
      final response = await _apiService.post(
        '${ApiConstants.tripDetails}/$tripId/unlock-seats',
        data: {'seat_numbers': seatNumbers},
      );
      return {
        'success': true,
        'message': response.data['message'] ?? 'Seat released',
        'locked': _parseSeatList(response.data['data']?['locked_seats']),
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': dioResponseMessage(e) ?? 'Could not release seat',
      };
    } catch (e) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  /// Get trip details (includes booked_seats, pending_seats for seat selection,
  /// and co_passengers for the Fellow Travelers section).
  ///
  /// Every field is parsed independently and defensively: a parse failure in
  /// one field (e.g. trip model) can never nuke the whole response, so
  /// co-passengers / seats always survive. This keeps the screen correct for
  /// any backend payload shape, at any scale.
  Future<Map<String, dynamic>> getTripDetails(String tripId) async {
    try {
      final response = await _apiService.get('${ApiConstants.tripDetails}/$tripId');
      final rawData = response.data is Map ? response.data['data'] : null;
      final data = rawData is Map ? Map<String, dynamic>.from(rawData) : <String, dynamic>{};
      final tripJson = data['trip'] is Map ? data['trip'] : data;

      // Trip model parse is isolated — if it ever throws, we still return the
      // rest (co-passengers, seats) instead of failing the whole call.
      TripModel trip;
      try {
        trip = TripModel.fromJson(
            tripJson is Map ? Map<String, dynamic>.from(tripJson) : <String, dynamic>{});
      } catch (_) {
        trip = TripModel.fromJson(<String, dynamic>{});
      }

      return {
        'success': true,
        'trip': trip,
        'booked_seats': _parseSeatList(data['booked_seats']),
        'pending_seats': _parseSeatList(data['pending_seats']),
        'locked_seats': _parseSeatList(data['locked_seats']),
        'user_booking_status': data['user_booking_status'],
        'co_passengers': _parseCoPassengers(data['co_passengers']),
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': dioResponseMessage(e) ?? 'Failed to get trip details',
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

      final data = response.data['data'] ?? {};
      final List<dynamic> tripsJson = data['trips'] ?? [];
      final List<TripModel> trips = tripsJson
          .map((json) => TripModel.fromJson(json))
          .toList();

      return {
        'success': true,
        'trips': trips,
        'count': data['count'] ?? 0,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': dioResponseMessage(e) ?? 'Failed to get trips',
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

  /// Create booking (Passenger). [idempotencyKey] avoids duplicate booking on double-submit / retry.
  Future<Map<String, dynamic>> createBooking({
    required String tripId,
    required List<int> seatNumbers,
    String? idempotencyKey,
  }) async {
    try {
      final key = idempotencyKey?.trim();
      final response = await _apiService.post(
        ApiConstants.createBooking,
        data: {
          'trip_id': tripId,
          'seat_numbers': seatNumbers,
          if (key != null && key.isNotEmpty) 'idempotency_key': key,
        },
        options: (key != null && key.isNotEmpty)
            ? Options(headers: {'Idempotency-Key': key})
            : null,
      );

      return {
        'success': true,
        'message': response.data['message'] ?? 'Booking confirmed',
        'booking': response.data['data']?['booking'],
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': dioResponseMessage(e) ?? 'Failed to create booking',
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
      final data = response.data['data'] ?? {};
      final List<dynamic> bookingsJson = data['bookings'] ?? [];
      return {
        'success': true,
        'bookings': bookingsJson,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': dioResponseMessage(e) ?? 'Failed to get bookings',
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
        'message': dioResponseMessage(e) ?? 'Failed',
      };
    } catch (e) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  /// Cancel booking (Passenger only). Pending: always; Confirmed: until 2 min before departure (testing).
  Future<Map<String, dynamic>> cancelBooking(String bookingId, {String? reason}) async {
    try {
      final response = await _apiService.post(
        '${ApiConstants.createBooking}/$bookingId/cancel',
        data: reason != null && reason.trim().isNotEmpty ? {'reason': reason.trim()} : {},
      );
      return {
        'success': true,
        'message': response.data['message'] ?? 'Booking cancelled',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': dioResponseMessage(e) ?? 'Could not cancel booking',
      };
    } catch (e) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  /// Start trip (Driver only) - scheduled → in_progress
  Future<Map<String, dynamic>> startTrip(String tripId) async {
    try {
      final response = await _apiService.put(
        '${ApiConstants.tripDetails}/$tripId/start',
      );
      return {
        'success': true,
        'message': response.data['message'] ?? 'Ride started',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': dioResponseMessage(e) ?? 'Could not start ride',
      };
    } catch (e) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  /// Complete trip (Driver only) — backend accepts scheduled or in_progress → completed.
  Future<Map<String, dynamic>> completeTrip(String tripId) async {
    try {
      final response = await _apiService.put(
        '${ApiConstants.tripDetails}/$tripId/complete',
      );
      return {
        'success': true,
        'message': response.data['message'] ?? 'Ride completed',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': dioResponseMessage(e) ?? 'Could not complete ride',
      };
    } catch (e) {
      return {'success': false, 'message': 'An error occurred'};
    }
  }

  /// Cancel trip (Driver only) - allowed anytime before departure
  Future<Map<String, dynamic>> cancelTrip(String tripId) async {
    try {
      final response = await _apiService.put(
        '${ApiConstants.tripDetails}/$tripId/cancel',
      );
      return {
        'success': true,
        'message': response.data['message'] ?? 'Trip cancelled',
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': dioResponseMessage(e) ?? 'Could not cancel trip',
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
        'message': dioResponseMessage(e) ?? 'Cannot delete ride',
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

      final data = response.data['data'] ?? {};
      final List<dynamic> bookingsJson = data['bookings'] ?? [];
      return {
        'success': true,
        'bookings': bookingsJson,
      };
    } on DioException catch (e) {
      return {
        'success': false,
        'message': dioResponseMessage(e) ?? 'Failed to get bookings',
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

  /// Get recent routes for quick search (authenticated)
  Future<Map<String, dynamic>> getRecentRoutes() async {
    try {
      final response = await _apiService.get('${ApiConstants.trips}/recent-routes');
      final routes = response.data['data']?['routes'] ?? [];
      return {'success': true, 'routes': routes};
    } on DioException catch (_) {
      return {'success': false, 'routes': <dynamic>[]};
    } catch (_) {
      return {'success': false, 'routes': <dynamic>[]};
    }
  }

  /// Save route as recent (call after search)
  Future<void> saveRecentRoute({required String from, required String to}) async {
    try {
      await _apiService.post(
        '${ApiConstants.trips}/recent-routes',
        data: {'from_location': from, 'to_location': to},
      );
    } catch (_) {}
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

      final data = response.data['data'] ?? {};
      final List<dynamic> suggestionsJson = data['suggestions'] ?? [];
      return suggestionsJson.map((s) => s.toString()).toList();
    } catch (e) {
      return [];
    }
  }

  /// Location suggestions WITH coordinates (Ola Maps `places`). Falls back to
  /// name-only entries when the backend can't resolve coordinates. Never throws.
  Future<List<PickedLocation>> getLocationPlaces(String query, {double? nearLat, double? nearLng}) async {
    try {
      if (query.length < 2) return [];
      final params = <String, dynamic>{'q': query};
      if (nearLat != null && nearLng != null) {
        params['near_lat'] = nearLat;
        params['near_lng'] = nearLng;
      }
      final response = await _apiService.get(
        ApiConstants.locationSuggestions,
        queryParameters: params,
      );
      final data = response.data['data'] ?? {};
      final List<dynamic> placesJson = data['places'] ?? [];
      if (placesJson.isNotEmpty) {
        return placesJson
            .whereType<Map>()
            .map((p) => PickedLocation.fromJson(Map<String, dynamic>.from(p)))
            .where((p) => p.name.isNotEmpty)
            .toList();
      }
      // Older backend without `places` → degrade to name-only suggestions.
      final List<dynamic> suggestionsJson = data['suggestions'] ?? [];
      return suggestionsJson
          .map((s) => PickedLocation.nameOnly(s.toString()))
          .where((p) => p.name.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Reverse geocode GPS coordinates → place name (for "use my current location").
  /// Returns a PickedLocation with coords always set; name may be a fallback.
  Future<PickedLocation> reverseGeocode(double lat, double lng) async {
    try {
      final response = await _apiService.get(
        ApiConstants.reverseGeocode,
        queryParameters: {'lat': lat, 'lng': lng},
      );
      final data = response.data['data'];
      final name = (data is Map ? data['name'] : null)?.toString();
      return PickedLocation(
        name: (name != null && name.trim().isNotEmpty) ? name : 'My location',
        lat: lat,
        lng: lng,
      );
    } catch (e) {
      return PickedLocation(name: 'My location', lat: lat, lng: lng);
    }
  }

  /// Road distance + duration estimate between two coordinates.
  /// Returns {distanceKm, durationMin} or null on failure. Fare is intentionally
  /// NOT returned (drivers shouldn't see a suggested price).
  Future<Map<String, dynamic>?> estimateRoute({
    required double fromLat,
    required double fromLng,
    required double toLat,
    required double toLng,
  }) async {
    try {
      final response = await _apiService.get(
        ApiConstants.routeEstimate,
        queryParameters: {
          'from_lat': fromLat,
          'from_lng': fromLng,
          'to_lat': toLat,
          'to_lng': toLng,
        },
      );
      final data = response.data['data'];
      if (data is Map) {
        return {
          'distanceKm': (data['distance_km'] as num?)?.toDouble(),
          'durationMin': (data['duration_min'] as num?)?.toInt(),
          'estimated': data['estimated'] == true,
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
