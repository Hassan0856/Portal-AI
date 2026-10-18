import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:portalai/models/models.dart';
import 'package:portalai/screens/auth_screens.dart';

void main() {
  Widget app(Widget child) => ProviderScope(child: MaterialApp(home: child));

  testWidgets('Log in asks only for email and password', (tester) async {
    await tester.pumpWidget(app(const LoginScreen(role: UserRole.resident)));
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
    expect(find.text('your@email.com'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Your name'), findsNothing);
    expect(find.text('Confirm password'), findsNothing);
  });

  testWidgets('Sign up asks for name, email, password and confirm',
      (tester) async {
    await tester.pumpWidget(app(const LoginScreen(role: UserRole.guardian)));
    await tester.tap(find.text('Sign up'));
    await tester.pumpAndSettle();
    expect(find.text('Your name'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(0), 'Sam');
    await tester.enterText(find.byType(TextFormField).at(1), 'sam@example.com');
    await tester.enterText(find.byType(TextFormField).at(2), 'secret1');
    await tester.enterText(find.byType(TextFormField).at(3), 'secret2');
    await tester.ensureVisible(find.text('SIGN UP'));
    await tester.tap(find.text('SIGN UP'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match'), findsOneWidget);
  });
}
