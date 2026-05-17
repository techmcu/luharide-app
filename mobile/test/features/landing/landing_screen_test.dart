import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luharide/features/landing/presentation/screens/landing_screen.dart';
import '../../helpers/test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('LandingScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(makeTestable(const LandingScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsAtLeast(1));
    });

    testWidgets('has from and to text fields', (tester) async {
      await tester.pumpWidget(makeTestable(const LandingScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsAtLeast(2));
    });

    testWidgets('has login and signup buttons', (tester) async {
      await tester.pumpWidget(makeTestable(const LandingScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(ElevatedButton), findsAtLeast(1));
    });
  });
}
