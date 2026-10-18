import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent, AuthState;
import '../data/mock_data.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../services/supabase_service.dart';

/// Current signed-in role, or null when signed out.
final authProvider =
    NotifierProvider<AuthNotifier, UserRole?>(AuthNotifier.new);

class AuthNotifier extends Notifier<UserRole?> {
  StreamSubscription<AuthState>? _authSub;

  /// main() restores a saved session (and its role from profiles) before
  /// the app starts, so a guardian stays a guardian after a restart.
  @override
  UserRole? build() {
    // Opened from the confirmation email: supabase_flutter exchanges the
    // link for a session and reports signedIn; read the role and go in.
    _authSub = SupabaseService.instance.authChanges?.listen(_onAuthChange);
    ref.onDispose(() => _authSub?.cancel());
    return SupabaseService.instance.cachedRole;
  }

  Future<void> _onAuthChange(AuthState s) async {
    final service = SupabaseService.instance;
    if (s.event == AuthChangeEvent.signedOut) {
      if (state != null) state = null;
      return;
    }
    if (s.event != AuthChangeEvent.signedIn ||
        s.session == null ||
        state != null ||
        service.signingIn) {
      return;
    }
    final res = await service.completeLinkSignIn();
    if (res.role != null) {
      _signedIn(res.role!);
    } else if (res.error != null) {
      FirebaseService.messengerKey.currentState?.showSnackBar(SnackBar(
        content: Text(res.error!),
        backgroundColor: const Color(0xFFB04060),
        duration: const Duration(seconds: 8),
      ));
    }
  }

  void _signedIn(UserRole role) {
    state = role;
    final s = ref.read(settingsProvider);
    unawaited(FirebaseService.instance.applyRoleTopics(role,
        status: s.systemUpdates, digest: s.activityAlerts));
  }

  /// Signs in with email + password and checks profiles.role (9.2).
  Future<String?> signIn(UserRole role, String email, String password) async {
    final err = await SupabaseService.instance
        .signIn(role: role, email: email, password: password);
    if (err == null) _signedIn(role);
    return err;
  }

  /// A signed-out phone receives no alerts.
  Future<void> logout() async {
    state = null;
    await FirebaseService.instance.applyRoleTopics(null);
    await SupabaseService.instance.signOut();
  }

  /// Creates a Supabase Auth user with the name in its metadata. Signs in
  /// straight away when Supabase returns a session (Confirm email off).
  Future<({SignUpOutcome outcome, String? message})> signUp(
      UserRole role, String name, String email, String password) async {
    final res = await SupabaseService.instance.signUp(
      role: role,
      displayName: name,
      email: email,
      password: password,
    );
    if (res.outcome == SignUpOutcome.signedIn) _signedIn(role);
    return res;
  }

  Future<String?> resendConfirmation(String email) =>
      SupabaseService.instance.resendConfirmation(email);
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
