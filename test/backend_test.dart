import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:portalai/core/app_config.dart';
import 'package:portalai/models/models.dart';
import 'package:portalai/providers/providers.dart';
import 'package:portalai/services/firebase_service.dart';
import 'package:portalai/services/n8n_api.dart';
import 'package:portalai/services/supabase_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppConfig Tests', () {
    test('AppConfig handles uninitialized/placeholder state correctly', () {
      // No --dart-define-from-file in tests: nothing is configured
      expect(AppConfig.isSupabaseConfigured, isFalse);
      expect(AppConfig.isN8nConfigured, isFalse);
    });
  });

  group('SupabaseService Offline & Fallback Tests', () {
    test('SupabaseService handles unconfigured state without throwing',
        () async {
      final service = SupabaseService.instance;
      expect(service.isAvailable, isFalse);

      // In unconfigured/demo mode, signIn completes gracefully
      final err = await service.signIn(
        role: UserRole.resident,
        email: 'resident@example.com',
        password: 'password123',
      );
      expect(err, isNull);
      expect(service.cachedRole, UserRole.resident);
      await service.signOut();
      expect(service.cachedRole, isNull);

      // Falls back to mock events and messages
      final events = await service.fetchEvents();
      expect(events, isNotEmpty);
      expect(events.first.score, inInclusiveRange(1, 10));

      final messages = await service.fetchMessages();
      expect(messages, isNotEmpty);
    });
  });

  group('FirebaseService Safety Tests', () {
    test('Push is off without Firebase and topic calls are harmless', () async {
      final fb = FirebaseService.instance;
      expect(fb.isAvailable, isFalse);
      await fb.syncTopics({'portal_x_guardian'}, role: UserRole.guardian);
      await fb.syncTopics(const {});
    });

    test('Topics belong to one household only', () {
      expect(
          FirebaseService.topicsFor(
              role: UserRole.resident, userId: 'r1', status: true, digest: false),
          {'portal_r1_resident', 'portal_r1_status'});
      expect(
          FirebaseService.topicsFor(
              role: UserRole.guardian,
              userId: 'g1',
              linkedResidentIds: ['r1', 'r2'],
              status: false,
              digest: false),
          {'portal_r1_guardian', 'portal_r2_guardian'});
      // A guardian with no linked resident gets no pushes at all
      expect(
          FirebaseService.topicsFor(role: UserRole.guardian, userId: 'g1'),
          isEmpty);
      expect(FirebaseService.topicsFor(role: null, userId: 'r1'), isEmpty);
    });
  });

  group('Readable push text', () {
    test('Unfilled n8n expressions and raw JSON are cleaned', () {
      expect(cleanPushText(' {{ \$("Decide").first().json.push_title }}'), '');
      expect(cleanPushText('{"body":"Someone at the door"}'),
          'Someone at the door');
      expect(cleanPushText('🚨 Amma\'s home · 2:14 AM'), '🚨 Amma\'s home · 2:14 AM');
      final m = SupabaseService.mapMessage({
        'id': 1,
        'category': 'alert',
        'title': ' {{ \$("Decide").first().json.push_title }}',
        'body': ' {{ \$("Decide").first().json.push_body }}',
        'created_at': '2026-10-21T10:00:00+05:30',
      }, const {});
      expect(m.title, 'Unusual activity');
      expect(m.description, isNot(contains('{{')));
    });
  });

  group('n8n API Tests', () {
    test('App actions fail clearly when N8N_BASE / APP_KEY are missing',
        () async {
      final res = await N8nApi.appAction('confirm', {'event_id': '1'});
      expect(res.ok, isFalse);
      expect(res.message, contains('N8N_BASE'));
    });
  });

  group('v4 row mapping Tests', () {
    test('events and messages rows map to the app models', () {
      final e = SupabaseService.mapEvent({
        'id': 42,
        'device_id': 'front_door',
        'event_type': 'motion',
        'occurred_at': '2026-10-14T10:00:00+05:30',
        'description': 'A person in a red shirt at the door',
        'has_visitor': true,
        'rule_flags': 'loitering,unusual_hour',
        'anomaly_score': 6,
        'snapshot_kind': 'flagged',
        'snapshot_url': 'https://example.com/a.jpg',
        'owner_response': 'pending',
      }, {'front_door': 'Main door'});
      expect(e.id, '42');
      expect(e.type, 'Visitor');
      expect(e.location, 'Main door');
      expect(e.isPending, isTrue);
      expect(e.tags, containsAll(['Visitor', 'loitering', 'unusual hour']));

      final m = SupabaseService.mapMessage({
        'id': 7,
        'category': 'alert',
        'title': 'Door alert',
        'body': 'Someone at 2 am',
        'event_id': 42,
        'created_at': '2026-10-14T10:00:05+05:30',
      }, {'42': e});
      expect(m.kind, MessageKind.highRisk);
      expect(m.eventId, '42');
      expect(m.score, 6);
    });
  });

  group('Riverpod Providers Tests', () {
    test('Providers supply initial data without errors', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final auth = container.read(authProvider);
      expect(auth, isNull);

      final events = container.read(eventsProvider);
      expect(events, isNotEmpty);

      final messages = container.read(messagesProvider);
      expect(messages, isNotEmpty);

    });
  });
}
