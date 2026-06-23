import 'package:flutter_test/flutter_test.dart';
import 'package:luharide/models/picked_location.dart';

void main() {
  group('PickedLocation serialization (recent-search coords)', () {
    test('toJson → fromJson round-trip preserves name + coords', () {
      const p = PickedLocation(
        name: 'Barkot',
        secondary: 'Uttarkashi, Uttarakhand',
        lat: 30.8089,
        lng: 78.2069,
      );
      final round = PickedLocation.fromJson(p.toJson());

      expect(round.name, 'Barkot');
      expect(round.secondary, 'Uttarkashi, Uttarakhand');
      expect(round.lat, 30.8089);
      expect(round.lng, 78.2069);
      expect(round.hasCoords, true);
    });

    test('name-only round-trips with no coords (hasCoords false)', () {
      final p = PickedLocation.nameOnly('Barkot');
      final round = PickedLocation.fromJson(p.toJson());

      expect(round.name, 'Barkot');
      expect(round.hasCoords, false);
      expect(round.lat, isNull);
      expect(round.lng, isNull);
    });

    test('fromJson reads backend "description" key for the name', () {
      final p = PickedLocation.fromJson({
        'description': 'Dehradun Clock Tower',
        'secondary': 'Dehradun',
        'lat': 30.3256,
        'lng': 78.0437,
      });
      expect(p.name, 'Dehradun Clock Tower');
      expect(p.hasCoords, true);
    });

    test('fromJson tolerates string-typed coordinates', () {
      final p = PickedLocation.fromJson({
        'name': 'Purola',
        'lat': '30.8833',
        'lng': '78.0889',
      });
      expect(p.lat, 30.8833);
      expect(p.lng, 78.0889);
      expect(p.hasCoords, true);
    });

    test('hasCoords is false when only one coordinate is present', () {
      const p = PickedLocation(name: 'X', lat: 30.0);
      expect(p.hasCoords, false);
    });
  });
}
