import 'package:flutter_test/flutter_test.dart';
import 'package:luharide/core/kyc/kyc_user_preview_policy.dart';

void main() {
  test('null submittedAt allows preview (legacy clients)', () {
    expect(kycUserInAppPreviewIsOpen(null), isTrue);
  });

  test('within 4 days allows preview', () {
    final t = DateTime.now().subtract(const Duration(days: 2));
    expect(kycUserInAppPreviewIsOpen(t), isTrue);
  });

  test('after 4 days blocks preview', () {
    final t = DateTime.now().subtract(const Duration(days: 5));
    expect(kycUserInAppPreviewIsOpen(t), isFalse);
  });

  test('parses submitted_at from API map', () {
    final d = {'submitted_at': '2020-01-02T03:04:05.000Z'};
    expect(kycSubmittedAtFromDocMap(d)?.toUtc().year, 2020);
  });
}
