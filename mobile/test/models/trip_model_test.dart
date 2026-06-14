import 'package:flutter_test/flutter_test.dart';
import 'package:luharide/models/trip_model.dart';

void main() {
  group('TripModel.fromJson', () {
    test('parses complete valid JSON', () {
      final json = {
        'id': 'abc-123',
        'from_location': 'Dehradun',
        'to_location': 'Mussoorie',
        'departure_time': '2026-06-15T04:30:00Z',
        'arrival_time': '2026-06-15T06:30:00Z',
        'fare_per_seat': '250',
        'available_seats': '3',
        'total_seats': '7',
        'vehicle_number': 'UK07-1234',
        'vehicle_model_id': 'model-1',
        'stops': ['Rajpur', 'Kulhan'],
        'status': 'scheduled',
        'created_source': 'independent_driver',
        'driver': {
          'id': 'drv-1',
          'name': 'Test Driver',
          'email': 'drv@test.com',
          'phone': '+911234567890',
          'whatsapp_number': '+919876543210',
          'isVerified': true,
        },
        'pending_requests_count': '2',
      };

      final trip = TripModel.fromJson(json);
      expect(trip.id, 'abc-123');
      expect(trip.fromLocation, 'Dehradun');
      expect(trip.toLocation, 'Mussoorie');
      expect(trip.farePerSeat, 250.0);
      expect(trip.availableSeats, 3);
      expect(trip.totalSeats, 7);
      expect(trip.vehicleNumber, 'UK07-1234');
      expect(trip.stops, ['Rajpur', 'Kulhan']);
      expect(trip.status, 'scheduled');
      expect(trip.isIndependentDriver, true);
      expect(trip.driver, isNotNull);
      expect(trip.driver!.name, 'Test Driver');
      expect(trip.driver!.isVerified, true);
      expect(trip.pendingRequestsCount, 2);
    });

    test('handles null/missing fields with safe defaults', () {
      final trip = TripModel.fromJson({});
      expect(trip.id, '');
      expect(trip.fromLocation, '');
      expect(trip.toLocation, '');
      expect(trip.farePerSeat, 0.0);
      expect(trip.availableSeats, 0);
      expect(trip.totalSeats, 0);
      expect(trip.stops, isEmpty);
      expect(trip.status, 'scheduled');
      expect(trip.driver, isNull);
      expect(trip.pendingRequestsCount, 0);
    });

    test('handles malformed departure_time without crashing', () {
      final trip = TripModel.fromJson({
        'departure_time': 'not-a-date',
      });
      expect(trip.departureTime, isA<DateTime>());
    });

    test('handles departure_time without Z suffix (UTC from backend)', () {
      final trip = TripModel.fromJson({
        'departure_time': '2026-06-15T04:30:00',
      });
      expect(trip.departureTime.isUtc, false);
    });

    test('handles stops with non-string elements', () {
      final trip = TripModel.fromJson({
        'stops': [123, null, 'Rajpur', true, ''],
      });
      expect(trip.stops, ['123', 'Rajpur', 'true']);
    });

    test('handles stops as non-list', () {
      final trip = TripModel.fromJson({'stops': 'not-a-list'});
      expect(trip.stops, isEmpty);
    });

    test('handles driver as non-Map gracefully', () {
      final trip = TripModel.fromJson({'driver': 'not-a-map'});
      expect(trip.driver, isNull);
    });

    test('handles driver as plain Map (not Map<String, dynamic>)', () {
      final Map plainMap = {'id': 'drv-1', 'name': 'Driver', 'isVerified': false};
      final trip = TripModel.fromJson({'driver': plainMap});
      expect(trip.driver, isNotNull);
      expect(trip.driver!.id, 'drv-1');
    });

    test('fare_per_seat handles non-numeric string', () {
      final trip = TripModel.fromJson({'fare_per_seat': 'abc'});
      expect(trip.farePerSeat, 0.0);
    });
  });

  group('TripModel computed properties', () {
    test('formattedDepartureTime returns 12-hour format', () {
      final trip = TripModel.fromJson({
        'departure_time': '2026-06-15T00:00:00Z',
      });
      expect(trip.formattedDepartureTime, contains('AM'));
    });

    test('formattedDate returns day month year', () {
      final trip = TripModel.fromJson({
        'departure_time': '2026-06-15T04:30:00Z',
      });
      expect(trip.formattedDate, contains('Jun'));
      expect(trip.formattedDate, contains('2026'));
    });

    test('estimatedDuration returns difference when arrival exists', () {
      final trip = TripModel.fromJson({
        'departure_time': '2026-06-15T04:30:00Z',
        'arrival_time': '2026-06-15T06:30:00Z',
      });
      expect(trip.estimatedDuration, const Duration(hours: 2));
    });

    test('estimatedDuration returns null without arrival', () {
      final trip = TripModel.fromJson({
        'departure_time': '2026-06-15T04:30:00Z',
      });
      expect(trip.estimatedDuration, isNull);
    });

    test('formattedDuration shows hours and minutes', () {
      final trip = TripModel.fromJson({
        'departure_time': '2026-06-15T04:30:00Z',
        'arrival_time': '2026-06-15T06:45:00Z',
      });
      expect(trip.formattedDuration, '2h 15m');
    });

    test('formattedDuration returns N/A without arrival', () {
      final trip = TripModel.fromJson({
        'departure_time': '2026-06-15T04:30:00Z',
      });
      expect(trip.formattedDuration, 'N/A');
    });

    test('isCreatedByUserId matches driver id', () {
      final trip = TripModel.fromJson({
        'driver': {'id': 'drv-1', 'name': 'D'},
      });
      expect(trip.isCreatedByUserId('drv-1'), true);
      expect(trip.isCreatedByUserId('drv-2'), false);
      expect(trip.isCreatedByUserId(null), false);
      expect(trip.isCreatedByUserId(''), false);
    });
  });

  group('DriverInfo', () {
    test('fromJson parses all fields', () {
      final driver = DriverInfo.fromJson({
        'id': 'd1',
        'name': 'Test',
        'email': 'e@t.com',
        'phone': '+91111',
        'whatsapp_number': '+91222',
        'isVerified': true,
      });
      expect(driver.id, 'd1');
      expect(driver.name, 'Test');
      expect(driver.phone, '+91111');
      expect(driver.whatsappNumber, '+91222');
      expect(driver.isVerified, true);
    });

    test('contactNumber prefers whatsapp over phone', () {
      final driver = DriverInfo.fromJson({
        'id': 'd1',
        'name': 'D',
        'phone': '+91111',
        'whatsapp_number': '+91222',
      });
      expect(driver.contactNumber, '+91222');
    });

    test('contactNumber falls back to phone when whatsapp empty', () {
      final driver = DriverInfo.fromJson({
        'id': 'd1',
        'name': 'D',
        'phone': '+91111',
        'whatsapp_number': '  ',
      });
      expect(driver.contactNumber, '+91111');
    });

    test('handles null fields gracefully', () {
      final driver = DriverInfo.fromJson({});
      expect(driver.id, '');
      expect(driver.name, 'Unknown Driver');
      expect(driver.isVerified, false);
      expect(driver.contactNumber, isNull);
    });

    test('toJson roundtrip preserves data', () {
      final original = DriverInfo.fromJson({
        'id': 'd1',
        'name': 'Test',
        'email': 'e@t.com',
        'phone': '+91111',
        'whatsapp_number': '+91222',
        'isVerified': true,
      });
      final roundtrip = DriverInfo.fromJson(original.toJson());
      expect(roundtrip.id, original.id);
      expect(roundtrip.name, original.name);
      expect(roundtrip.email, original.email);
      expect(roundtrip.phone, original.phone);
      expect(roundtrip.whatsappNumber, original.whatsappNumber);
      expect(roundtrip.isVerified, original.isVerified);
    });
  });

  group('TripModel.toJson', () {
    test('roundtrip preserves core fields', () {
      final original = TripModel.fromJson({
        'id': 'abc-123',
        'from_location': 'Dehradun',
        'to_location': 'Mussoorie',
        'departure_time': '2026-06-15T04:30:00Z',
        'fare_per_seat': '250',
        'available_seats': '3',
        'total_seats': '7',
        'stops': ['Rajpur'],
        'status': 'scheduled',
      });
      final json = original.toJson();
      expect(json['id'], 'abc-123');
      expect(json['from_location'], 'Dehradun');
      expect(json['to_location'], 'Mussoorie');
      expect(json['fare_per_seat'], 250.0);
      expect(json['stops'], ['Rajpur']);
    });
  });
}
