import 'package:flutter_test/flutter_test.dart';
import 'package:luharide/core/utils/compact_number.dart';

void main() {
  group('compactCount', () {
    test('numbers under 1000 are shown as-is', () {
      expect(compactCount(0), '0');
      expect(compactCount(8), '8');
      expect(compactCount(11), '11');
      expect(compactCount(999), '999');
    });

    test('thousands use k, with one decimal trimmed', () {
      expect(compactCount(1000), '1k');
      expect(compactCount(1100), '1.1k');
      expect(compactCount(4400), '4.4k');
      expect(compactCount(44000), '44k');
    });

    test('lakhs use L', () {
      expect(compactCount(100000), '1L');
      expect(compactCount(120000), '1.2L');
      expect(compactCount(9900000), '99L');
    });

    test('crores use Cr', () {
      expect(compactCount(10000000), '1Cr');
      expect(compactCount(12000000), '1.2Cr');
    });

    test('null is treated as 0', () {
      expect(compactCount(null), '0');
    });
  });

  group('compactCurrency', () {
    test('prefixes rupee and stays exact for small values', () {
      expect(compactCurrency(450), '₹450');
    });

    test('compacts large amounts', () {
      expect(compactCurrency(1250000), '₹12.5L');
    });
  });
}
