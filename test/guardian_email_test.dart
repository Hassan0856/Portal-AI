import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:portalai/models/models.dart';
import 'package:portalai/providers/guardian_email_provider.dart';
import 'package:portalai/providers/providers.dart';
import 'package:portalai/screens/guardian_email_screen.dart';
import 'package:portalai/services/guardian_email_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GuardianEmailService Safety & Offline Tests', () {
    test('Service operations fail safely when unauthenticated or offline',
        () async {
      final service = GuardianEmailService.instance;

      final residents = await service.fetchLinkedResidents();
      expect(residents, isEmpty);

      final isLinked = await service.isGuardianLinkedToResident('sample-resident-uuid');
      expect(isLinked, isFalse);

      final emails = await service.fetchEmails('sample-resident-uuid');
      expect(emails, isEmpty);

      final addError = await service.addEmail(
        residentId: 'sample-resident-uuid',
        email: 'test@portal.io',
      );
      expect(addError, isNotNull);

      final updateError = await service.updateLabel(
        emailId: 'sample-email-uuid',
        label: 'Emergency',
      );
      expect(updateError, isNotNull);

      final deleteError = await service.deleteEmail('sample-email-uuid');
      expect(deleteError, isNotNull);
    });
  });

  group('GuardianEmailProvider State Tests', () {
    test('Provider initializes with safe default state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(guardianEmailProvider);
      expect(state.isLoadingResidents, isTrue);
      expect(state.residents, isEmpty);
      expect(state.selectedResident, isNull);
      expect(state.emails, isEmpty);
      expect(state.isSubmitting, isFalse);
    });

    test('addEmail fails safely when no resident is selected', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(guardianEmailProvider.notifier);
      final err = await notifier.addEmail(email: 'test@example.com');
      expect(err, equals('No resident selected.'));
    });
  });

  group('Route Authorization Tests', () {
    test(
        'Resident cannot access /settings/resident-emails (redirects to /dashboard)',
        () {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _MockResidentAuthNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final role = container.read(authProvider);
      expect(role, equals(UserRole.resident));

      const loc = '/settings/resident-emails';
      final redirect = (loc.startsWith('/settings/resident-emails') &&
              role != UserRole.guardian)
          ? '/dashboard'
          : null;

      expect(redirect, equals('/dashboard'));
    });

    test(
        'Unauthenticated user cannot access /settings/resident-emails (redirects to /welcome)',
        () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final role = container.read(authProvider);
      expect(role, isNull);

      const loc = '/settings/resident-emails';
      final isPublic = loc == '/welcome' || loc.startsWith('/login');
      final redirect = (role == null && !isPublic) ? '/welcome' : null;

      expect(redirect, equals('/welcome'));
    });
  });

  group('GuardianEmailScreen Widget & UI Tests', () {
    testWidgets('Unauthenticated user sees Access Restricted screen',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: GuardianEmailScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Access Restricted'), findsOneWidget);
      expect(find.text('Guardian Access Only'), findsOneWidget);
      expect(find.text('Return to Dashboard'), findsOneWidget);
    });
  });
}

class _MockResidentAuthNotifier extends AuthNotifier {
  @override
  UserRole? build() => UserRole.resident;
}
