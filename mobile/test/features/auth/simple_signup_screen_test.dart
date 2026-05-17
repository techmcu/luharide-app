import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:luharide/features/auth/presentation/screens/simple_signup_screen.dart';
import '../../helpers/test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SimpleSignupScreen', () {
    testWidgets('renders step 1 with email field and Send OTP button', (tester) async {
      await tester.pumpWidget(makeTestable(const SimpleSignupScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Step 1 of 2'), findsOneWidget);
      expect(find.text('Send OTP'), findsOneWidget);
      expect(find.byIcon(Icons.email), findsOneWidget);
    });

    testWidgets('has terms and privacy checkbox', (tester) async {
      await tester.pumpWidget(makeTestable(const SimpleSignupScreen()));
      await tester.pumpAndSettle();

      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.text('Terms'), findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
    });

    testWidgets('has Google sign-in button', (tester) async {
      await tester.pumpWidget(makeTestable(const SimpleSignupScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('has login link', (tester) async {
      await tester.pumpWidget(makeTestable(const SimpleSignupScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Already have an account? Login'), findsOneWidget);
    });

    testWidgets('checkbox toggles on tap', (tester) async {
      await tester.pumpWidget(makeTestable(const SimpleSignupScreen()));
      await tester.pumpAndSettle();

      final checkbox = find.byType(Checkbox);
      Checkbox widget = tester.widget(checkbox);
      expect(widget.value, false);

      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      widget = tester.widget(checkbox);
      expect(widget.value, true);
    });
  });
}
