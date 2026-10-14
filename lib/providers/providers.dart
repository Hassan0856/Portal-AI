import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../services/supabase_service.dart';

/// Current signed-in role, or null when signed out.
final authProvider =
    NotifierProvider<AuthNotifier, UserRole?>(AuthNotifier.new);

class AuthNotifier extends Notifier<UserRole?> {
  /// main() restores a saved session (and its role from profiles) before
  /// the app starts, so a guardian stays a guardian after a restart.
  @override
  UserRole? build() => SupabaseService.instance.cachedRole;

  /// Signs in through Supabase Auth and checks profiles.role (9.2).
  Future<String?> signIn(
      UserRole role, String id, String email, String password) async {
    final err = await SupabaseService.instance.signIn(
      role: role,
      identifier: id,
      email: email,
      password: password,
    );
    if (err == null) {
      state = role;
      final s = ref.read(settingsProvider);
      unawaited(FirebaseService.instance.applyRoleTopics(role,
          status: s.systemUpdates, digest: s.activityAlerts));
    }
    return err;
  }

  /// A signed-out phone receives no alerts.
  Future<void> logout() async {
    state = null;
    await FirebaseService.instance.applyRoleTopics(null);
    await SupabaseService.instance.signOut();
  }

  /// Creates a Supabase Auth user. Returns an info or error message; the
  /// role row is added by hand in Supabase, so this never signs in.
  Future<String?> signUp(
      UserRole role, String id, String email, String password) {
    return SupabaseService.instance.signUp(
      role: role,
      identifier: id,
      email: email,
      password: password,
    );
  }
}

/// Settings -> Notifications. Each switch is an optional FCM topic,
/// remembered on the phone (Build Guide 9.4):
///   systemUpdates  -> portal_status (sensor offline alerts)
///   activityAlerts -> portal_digest (daily digest of routine activity)
/// Door alerts and the guardian SOS alarm are always on.
final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = AppSettings(
      systemUpdates: p.getBool('systemUpdates') ?? true,
      activityAlerts: p.getBool('activityAlerts') ?? true,
    );
  }

  Future<void> setSystemUpdates(bool v) async {
    state = state.copyWith(systemUpdates: v);
    final p = await SharedPreferences.getInstance();
    await p.setBool('systemUpdates', v);
    if (ref.read(authProvider) != null) {
      await FirebaseService.instance.setTopic(kTopicStatus, v);
    }
  }

  Future<void> setActivityAlerts(bool v) async {
    state = state.copyWith(activityAlerts: v);
    final p = await SharedPreferences.getInstance();
    await p.setBool('activityAlerts', v);
    if (ref.read(authProvider) != null) {
      await FirebaseService.instance.setTopic(kTopicDigest, v);
    }
  }
}

/// Events from Supabase Realtime, newest first. Restarts on sign-in and
/// sign-out, because the app's key only reads with a signed-in session.
final eventsProvider =
    NotifierProvider<EventsNotifier, List<SecurityEvent>>(EventsNotifier.new);

class EventsNotifier extends Notifier<List<SecurityEvent>> {
  StreamSubscription<List<SecurityEvent>>? _sub;

  @override
  List<SecurityEvent> build() {
    final role = ref.watch(authProvider);
    _sub?.cancel();
    ref.onDispose(() => _sub?.cancel());
    final svc = SupabaseService.instance;
    if (!svc.isAvailable) return mockEvents; // demo mode only
    if (role == null) return const [];
    _sub = svc.streamEvents().listen(
          (events) => state = events,
          onError: (Object e) {}, // keep the last list when offline
        );
    return const [];
  }
}

/// messages rows from Realtime (last 30 days are kept by WF-07).
final _messageRowsProvider =
    NotifierProvider<_MessageRowsNotifier, List<Map<String, dynamic>>>(
        _MessageRowsNotifier.new);

class _MessageRowsNotifier extends Notifier<List<Map<String, dynamic>>> {
  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  @override
  List<Map<String, dynamic>> build() {
    final role = ref.watch(authProvider);
    _sub?.cancel();
    ref.onDispose(() => _sub?.cancel());
    final svc = SupabaseService.instance;
    if (!svc.isAvailable || role == null) return const [];
    _sub = svc.streamMessageRows().listen(
          (rows) => state = rows,
          onError: (Object e) {},
        );
    return const [];
  }
}

/// Every notification from the last 30 days, newest first, with the score
/// and location of the event it is about.
final messagesProvider = Provider<List<AppMessage>>((ref) {
  if (!SupabaseService.instance.isAvailable) return mockMessages;
  final rows = ref.watch(_messageRowsProvider);
  final byId = {for (final e in ref.watch(eventsProvider)) e.id: e};
  final cutoff = DateTime.now().subtract(const Duration(days: 30));
  return [
    for (final r in rows) SupabaseService.mapMessage(r, byId),
  ].where((m) => m.timestamp.isAfter(cutoff)).toList();
});

/// Routine heatmap: the learned baseline (WF-05), or the events themselves
/// until a baseline exists.
final _baselineHeatmapProvider = FutureProvider<List<List<int>>?>((ref) {
  ref.watch(authProvider);
  return SupabaseService.instance.fetchBaselineHeatmap();
});

final heatmapProvider = Provider<List<List<int>>>((ref) {
  if (!SupabaseService.instance.isAvailable) return mockHeatmap;
  final baseline = ref.watch(_baselineHeatmapProvider).valueOrNull;
  return baseline ??
      SupabaseService.heatmapFromEvents(ref.watch(eventsProvider));
});

/// Stats derived from the events: last 7 days against the week before.
final statsProvider = Provider<List<StatItem>>((ref) {
  final events = ref.watch(eventsProvider);
  return SupabaseService.instance.calculateStats(events);
});

/// Setup gate: false until a reference photo with the role "resident"
/// exists (null = unknown, nothing is gated).
final residentFaceProvider = FutureProvider<bool?>((ref) {
  final role = ref.watch(authProvider);
  if (role == null) return Future.value(null);
  return SupabaseService.instance.hasResidentFace();
});
