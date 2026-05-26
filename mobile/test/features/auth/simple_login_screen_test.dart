import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luharide/features/auth/presentation/screens/simple_login_screen.dart';
import '../../helpers/test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setupMockSecureStorage();
  });

  group('SimpleLoginScreen', () {
    testWidgets('renders email and password fields', (tester) async {
      await tester.pumpWidget(makeTestable(const SimpleLoginScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(TextFormField), findsAtLeast(2));
      expect(find.byIcon(Icons.email_outlined), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
    });

    testWidgets('renders login button and Google sign-in', (tester) async {
      await tester.pumpWidget(makeTestable(const SimpleLoginScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('shows validation error for empty email', (tester) async {
      await tester.pumpWidget(makeTestable(const SimpleLoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('required'), findsAtLeast(1));
    });

    testWidgets('shows validation error for invalid email', (tester) async {
      await tester.pumpWidget(makeTestable(const SimpleLoginScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'notanemail',
      );
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.textContaining('valid'), findsAtLeast(1));
    });

    testWidgets('password visibility toggle works', (tester) async {
      await tester.pumpWidget(makeTestable(const SimpleLoginScreen()));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('has signup and forgot password links', (tester) async {
      await tester.pumpWidget(makeTestable(const SimpleLoginScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(TextButton), findsAtLeast(2));
    });
  });
}
