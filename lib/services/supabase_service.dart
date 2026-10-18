import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/app_colors.dart';
import '../core/app_config.dart';
import '../data/mock_data.dart';
import '../models/models.dart';
import 'n8n_api.dart';

/// Result of [SupabaseService.signUp].
enum SignUpOutcome { signedIn, checkEmail, error }

/// Reads the v4 Supabase backend (Build Guide 3.1 to 3.5) with the signed-in
/// user's session. The app only reads: every change goes through n8n WF-02
/// (see [N8nApi]). Tables: events, messages, devices, site_config, baseline,
/// profiles, and the view known_faces_public.
///
/// When SUPABASE_URL / SUPABASE_ANON_KEY are not in the build, the app runs
/// in demo mode on the sample data in mock_data.dart.
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  bool _initialized = false;
  bool get isAvailable => _initialized && AppConfig.isSupabaseConfigured;

  SupabaseClient get client => Supabase.instance.client;

  /// Role of the signed-in user, read from profiles (null when signed out).
  UserRole? cachedRole;
  String? displayName;

  Future<void> initialize() async {
    if (!AppConfig.isSupabaseConfigured) {
      debugPrint('[SupabaseService] SUPABASE_URL / SUPABASE_ANON_KEY not in '
          'this build (--dart-define-from-file=env.json). Demo mode.');
      return;
    }
    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // ignore: deprecated_member_use
        anonKey: AppConfig.supabaseAnonKey,
        debug: kDebugMode,
        // PKCE (the default) with detectSessionInUri on: supabase_flutter
        // catches the email link (app_links) and signs the user in.
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          detectSessionInUri: true,
        ),
      );
      _initialized = true;
    } catch (e) {
      _initialized = false;
      debugPrint('[SupabaseService] Initialization failed: $e');
    }
  }

  // ───────────────────────── Authentication (9.2) ─────────────────────────

  /// Deep link the confirmation email opens on the phone. It must also be in
  /// Supabase -> Authentication -> URL Configuration -> Redirect URLs, and it
  /// matches the intent-filter in AndroidManifest.xml.
  static const String mobileAuthRedirect =
      'com.portalai.portal_ai://login-callback';

  /// Where email links send the user: the app on a phone, this page on web.
  static String? get emailRedirectTo =>
      kIsWeb ? Uri.base.origin : mobileAuthRedirect;

  /// Shown when Supabase refuses a login because the email isn't confirmed;
  /// the login screen offers "Resend email" next to it.
  static const String emailNotConfirmedMessage =
      'Email not confirmed. Open the email from PortalAI on this phone and '
      'tap the link, or resend it.';

  User? get currentUser => isAvailable ? client.auth.currentUser : null;

  /// Auth changes from Supabase, e.g. signedIn after the email link.
  Stream<AuthState>? get authChanges =>
      isAvailable ? client.auth.onAuthStateChange : null;

  /// True while signIn / signUp run, so the email-link handler doesn't also
  /// act on the signedIn event they cause.
  bool signingIn = false;

  /// Reads the role of a session saved on the phone, so a guardian who
  /// reopens the app is still a guardian. Signs out if the role is gone.
  Future<void> restoreSession() async {
    final user = currentUser;
    if (user == null) return;
    try {
      final role = await _loadProfile(user);
      if (role == null) {
        await signOut();
        return;
      }
    } catch (e) {
      // Offline at start-up: keep the session, assume nothing about the role.
      debugPrint('[SupabaseService] restoreSession: $e');
    }
  }

  /// Reads profiles.role / display_name for [user] into the cache. The name
  /// falls back to the one given at sign up (user metadata).
  Future<UserRole?> _loadProfile(User user) async {
    final profile = await client
        .from('profiles')
        .select('role, display_name')
        .eq('user_id', user.id)
        .maybeSingle();
    final role = _roleFrom(profile?['role']);
    if (role == null) return null;
    cachedRole = role;
    final name = (profile?['display_name'] as String?)?.trim();
    displayName = name?.isNotEmpty == true
        ? name
        : user.userMetadata?['display_name'] as String?;
    return role;
  }

  UserRole? _roleFrom(Object? v) => switch (v) {
        'resident' => UserRole.resident,
        'guardian' => UserRole.guardian,
        _ => null,
      };

  static String _noRoleMessage(UserRole? role) =>
      'Your email is confirmed, but this account has no role yet. Ask the '
      'admin to add it to the profiles table as ${role?.name ?? 'resident or '
          'guardian'} (Build Guide 3.5), then log in.';

  /// Signed in through the email link (or a restored session): reads the
  /// role from profiles. Returns the role, or null with [error] set and the
  /// session signed out.
  Future<({UserRole? role, String? error})> completeLinkSignIn() async {
    final user = currentUser;
    if (user == null) return (role: null, error: null);
    try {
      final role = await _loadProfile(user);
      if (role != null) return (role: role, error: null);
      final wanted = _roleFrom(user.userMetadata?['role']);
      await signOut();
      return (role: null, error: _noRoleMessage(wanted));
    } catch (e) {
      debugPrint('[SupabaseService] completeLinkSignIn: $e');
      await signOut();
      return (
        role: null,
        error: 'Could not read your role. Check your internet connection '
            'and log in again.'
      );
    }
  }

  /// Signs in with email + password and checks profiles.role against the
  /// button the user chose. Returns null on success or a message to show.
  Future<String?> signIn({
    required UserRole role,
    required String email,
    required String password,
  }) async {
    if (!isAvailable) {
      // Demo mode: no backend in this build
      await Future<void>.delayed(const Duration(milliseconds: 400));
      cachedRole = role;
      return null;
    }

    signingIn = true;
    try {
      final res = await client.auth
          .signInWithPassword(email: email, password: password);
      final user = res.user;
      if (user == null) return 'Sign-in failed. Please try again.';
      return await _checkRole(user, role);
    } on AuthException catch (e) {
      return authErrorMessage(e);
    } on PostgrestException catch (e) {
      await client.auth.signOut();
      return 'Could not read your role from profiles: ${e.message}';
    } catch (e) {
      return 'Sign-in failed. Check your internet connection and try again.';
    } finally {
      signingIn = false;
    }
  }

  /// Null when the profile's role matches [chosen]; otherwise signs out and
  /// returns the message to show.
  Future<String?> _checkRole(User user, UserRole chosen) async {
    final registered = await _loadProfile(user);
    if (registered == null) {
      await signOut();
      return 'This account has no role yet. Ask the admin to add it to the '
          'profiles table as ${chosen.name} (Build Guide 3.5).';
    }
    if (registered != chosen) {
      await signOut();
      final name = registered == UserRole.guardian ? 'GUARDIAN' : 'RESIDENT';
      return 'This is a ${registered.name} account. Go back and choose '
          '"$name" to log in.';
    }
    return null;
  }

  /// Readable text for a Supabase Auth error.
  static String authErrorMessage(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid email or password') ||
        msg.contains('user not found')) {
      return 'Wrong email or password.';
    }
    if (msg.contains('email not confirmed') || e.code == 'email_not_confirmed') {
      return emailNotConfirmedMessage;
    }
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'An account with this email already exists. Log in instead.';
    }
    if (msg.contains('password should be') || msg.contains('weak password')) {
      return 'Password is too weak. Use at least 6 characters.';
    }
    if (msg.contains('too many requests') ||
        msg.contains('rate limit') ||
        msg.contains('security purposes')) {
      return 'Too many attempts. Please wait a minute and try again.';
    }
    if (msg.contains('redirect')) {
      return 'Supabase refused the app link. Add $mobileAuthRedirect to '
          'Authentication -> URL Configuration -> Redirect URLs.';
    }
    return e.message;
  }

  /// Creates a Supabase Auth user. The name and chosen role go into the
  /// user metadata; the profiles row is added by the admin (Build Guide 3.5),
  /// since the app's key cannot write to any table.
  ///
  /// When "Confirm email" is on, Supabase sends the email with a link back
  /// into the app ([emailRedirectTo]) and [SignUpOutcome.checkEmail] is
  /// returned. When it's off, a session comes back at once and the user is
  /// signed in ([SignUpOutcome.signedIn]) if the role is in profiles.
  Future<({SignUpOutcome outcome, String? message})> signUp({
    required UserRole role,
    required String displayName,
    required String email,
    required String password,
  }) async {
    if (!isAvailable) {
      return (
        outcome: SignUpOutcome.error,
        message: 'Sign up needs Supabase, which is not in this build '
            '(env.json). Use Log in for the demo.'
      );
    }
    signingIn = true;
    try {
      final res = await client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: emailRedirectTo,
        data: {'display_name': displayName, 'role': role.name},
      );
      final user = res.user;
      if (user == null) {
        return (
          outcome: SignUpOutcome.error,
          message: 'Sign up failed. Please try again.'
        );
      }
      // Supabase hides "already registered" behind a user with no
      // identities (when Confirm email is on).
      if (user.identities != null && user.identities!.isEmpty) {
        return (
          outcome: SignUpOutcome.error,
          message: 'An account with this email already exists. Log in instead.'
        );
      }
      if (res.session == null) {
        return (outcome: SignUpOutcome.checkEmail, message: null);
      }
      final err = await _checkRole(user, role);
      return err == null
          ? (outcome: SignUpOutcome.signedIn, message: null)
          : (outcome: SignUpOutcome.error, message: err);
    } on AuthException catch (e) {
      return (outcome: SignUpOutcome.error, message: authErrorMessage(e));
    } on PostgrestException catch (e) {
      await client.auth.signOut();
      return (
        outcome: SignUpOutcome.error,
        message: 'Could not read your role from profiles: ${e.message}'
      );
    } catch (e) {
      return (
        outcome: SignUpOutcome.error,
        message: 'Sign up failed. Check your internet connection and try again.'
      );
    } finally {
      signingIn = false;
    }
  }

  /// Sends the confirmation email again. Returns null on success.
  Future<String?> resendConfirmation(String email) async {
    if (!isAvailable) return 'Supabase is not configured in this build.';
    try {
      await client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: emailRedirectTo,
      );
      return null;
    } on AuthException catch (e) {
      return authErrorMessage(e);
    } catch (e) {
      return 'Could not send the email. Check your internet connection.';
    }
  }

  Future<void> signOut() async {
    cachedRole = null;
    displayName = null;
    if (!isAvailable) return;
    try {
      await client.auth.signOut();
    } catch (e) {
      debugPrint('[SupabaseService] Sign out error: $e');
    }
  }

  // ───────────────────────── Events (feed, gallery) ─────────────────────────

  Future<Map<String, String>> _deviceLocations() async {
    try {
      final rows = await client.from('devices').select('id, location');
      return {
        for (final r in rows)
          '${r['id']}': (r['location'] as String?)?.trim().isNotEmpty == true
              ? r['location'] as String
              : 'Front door',
      };
    } catch (_) {
      return {};
    }
  }

  Future<List<SecurityEvent>> fetchEvents() async {
    if (!isAvailable) return mockEvents;
    try {
      final locations = await _deviceLocations();
      final rows = await client
          .from('events')
          .select()
          .order('occurred_at', ascending: false)
          .limit(500);
      return [for (final r in rows) mapEvent(r, locations)];
    } catch (e) {
      debugPrint('[SupabaseService] fetchEvents: $e');
      return [];
    }
  }

  /// One event, for a notification that points at an event older than the
  /// live list.
  Future<SecurityEvent?> fetchEvent(String id) async {
    final n = int.tryParse(id);
    if (!isAvailable || n == null) return null;
    try {
      final row =
          await client.from('events').select().eq('id', n).maybeSingle();
      if (row == null) return null;
      return mapEvent(row, await _deviceLocations());
    } catch (e) {
      debugPrint('[SupabaseService] fetchEvent: $e');
      return null;
    }
  }

  /// Live events through Supabase Realtime (enabled on events in 3.3).
  Stream<List<SecurityEvent>> streamEvents() async* {
    if (!isAvailable) {
      yield mockEvents;
      return;
    }
    final locations = await _deviceLocations();
    yield* client
        .from('events')
        .stream(primaryKey: ['id'])
        .order('occurred_at', ascending: false)
        .limit(500)
        .map((rows) => [for (final r in rows) mapEvent(r, locations)]);
  }

  static String eventTypeLabel(String eventType, bool? hasVisitor) =>
      switch (eventType) {
        'inactivity' => 'Inactivity',
        'device_offline' => 'Sensor offline',
        _ => hasVisitor == true ? 'Visitor' : 'Motion',
      };

  static DateTime? _time(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toLocal() : null;

  static SecurityEvent mapEvent(
      Map<String, dynamic> r, Map<String, String> locations) {
    final eventType = '${r['event_type'] ?? 'motion'}';
    final hasVisitor = r['has_visitor'] as bool?;
    final score = ((r['anomaly_score'] as num?)?.toInt() ?? 1).clamp(1, 10);
    return SecurityEvent(
      id: '${r['id']}',
      score: score,
      location: locations['${r['device_id']}'] ?? 'Front door',
      timestamp: _time(r['occurred_at']) ?? DateTime.now(),
      type: eventTypeLabel(eventType, hasVisitor),
      description: (r['description'] as String?)?.trim().isNotEmpty == true
          ? r['description'] as String
          : (r['reason'] as String? ?? ''),
      eventType: eventType,
      reason: r['reason'] as String?,
      recommendedAction: r['recommended_action'] as String?,
      knownLabels: r['known_labels'] as String?,
      ruleFlags: r['rule_flags'] as String?,
      residentPresent: r['resident_present'] as bool?,
      hasVisitor: hasVisitor,
      snapshotKind: r['snapshot_kind'] as String?,
      snapshotUrl: r['snapshot_url'] as String?,
      snapshotExpiresAt: _time(r['snapshot_expires_at']),
      ownerResponse: '${r['owner_response'] ?? 'none'}',
      isSimulated: r['is_simulated'] == true,
    );
  }

  // ───────────────────────── Messages (9.4) ─────────────────────────

  Future<List<AppMessage>> fetchMessages() async {
    if (!isAvailable) return mockMessages;
    try {
      final rows = await client
          .from('messages')
          .select()
          .order('created_at', ascending: false)
          .limit(200);
      return [for (final r in rows) mapMessage(r, const {})];
    } catch (e) {
      debugPrint('[SupabaseService] fetchMessages: $e');
      return [];
    }
  }

  /// Raw messages rows through Realtime; mapped with [mapMessage].
  Stream<List<Map<String, dynamic>>> streamMessageRows() {
    if (!isAvailable) return Stream.value(const []);
    return client
        .from('messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(200);
  }

  /// messages.category: alert_stage1 | alert | inactivity | offline | digest
  static AppMessage mapMessage(
      Map<String, dynamic> r, Map<String, SecurityEvent> eventsById) {
    final category = '${r['category'] ?? ''}';
    final eventId = r['event_id'] == null ? null : '${r['event_id']}';
    final event = eventId == null ? null : eventsById[eventId];
    return AppMessage(
      id: '${r['id']}',
      kind: switch (category) {
        'alert' || 'inactivity' => MessageKind.highRisk,
        'alert_stage1' => MessageKind.activity,
        'offline' => MessageKind.system,
        _ => MessageKind.general,
      },
      title: (r['title'] as String?) ?? 'Notification',
      timestamp: _time(r['created_at']) ?? DateTime.now(),
      description: (r['body'] as String?) ?? '',
      score: event?.score,
      location: event?.location,
      eventId: eventId,
    );
  }

  // ───────────────────────── Settings data ─────────────────────────

  Future<Map<String, dynamic>?> fetchSiteConfig() async {
    if (!isAvailable) return null;
    try {
      return await client.from('site_config').select().eq('id', 1).maybeSingle();
    } catch (e) {
      debugPrint('[SupabaseService] fetchSiteConfig: $e');
      return null;
    }
  }

  /// Setup gate (9.7 screen 2): true when a reference photo with the role
  /// "resident" exists. Null when it can't be checked (then nothing is gated).
  Future<bool?> hasResidentFace() async {
    if (!isAvailable || currentUser == null) return null;
    try {
      final rows = await client
          .from('known_faces_public')
          .select('id')
          .eq('role', 'resident')
          .limit(1);
      return rows.isNotEmpty;
    } catch (e) {
      debugPrint('[SupabaseService] hasResidentFace: $e');
      return null;
    }
  }

  /// Adds the resident's reference photo through WF-02 add_face. The photo
  /// goes to known_faces in the database, never to Storage, and never comes
  /// back to the app (the app only sees known_faces_public).
  Future<AppActionResult> addReferencePhoto(Uint8List jpegBytes) async {
    if (!isAvailable) {
      return const AppActionResult(
          false, 'Supabase is not configured in this build.');
    }
    final config = await fetchSiteConfig();
    final residentName = (config?['resident_name'] as String?)?.trim();
    final label = residentName?.isNotEmpty == true
        ? residentName!
        : (displayName ?? 'Resident');
    final consentBy = displayName?.trim().isNotEmpty == true
        ? displayName!
        : (currentUser?.email ?? 'Resident');
    return N8nApi.appAction('add_face', {
      'label': label,
      'role': 'resident',
      'consent_by': consentBy,
      'image_b64': base64Encode(jpegBytes),
    });
  }

  // ───────────────────────── Heatmap and statistics ─────────────────────────

  /// Routine heatmap from the learned baseline (WF-05): 7 days (Sun first)
  /// by 8 three-hour slots, levels 0-3. Null when there is no baseline yet.
  Future<List<List<int>>?> fetchBaselineHeatmap() async {
    if (!isAvailable) return null;
    try {
      final rows =
          await client.from('baseline').select('day_of_week, hour, avg_count');
      if (rows.isEmpty) return null;
      final sums = List.generate(7, (_) => List<double>.filled(8, 0));
      for (final r in rows) {
        final d = (r['day_of_week'] as num?)?.toInt();
        final h = (r['hour'] as num?)?.toInt();
        if (d == null || h == null || d < 0 || d > 6 || h < 0 || h > 23) {
          continue;
        }
        sums[d][h ~/ 3] += (r['avg_count'] as num?)?.toDouble() ?? 0;
      }
      return levelsFrom(sums);
    } catch (e) {
      debugPrint('[SupabaseService] fetchBaselineHeatmap: $e');
      return null;
    }
  }

  /// Heatmap from the events themselves, used until a baseline exists.
  static List<List<int>> heatmapFromEvents(List<SecurityEvent> events) {
    final sums = List.generate(7, (_) => List<double>.filled(8, 0));
    for (final e in events.where((e) => e.eventType == 'motion')) {
      sums[e.timestamp.weekday % 7][e.timestamp.hour ~/ 3] += 1;
    }
    return levelsFrom(sums);
  }

  static List<List<int>> levelsFrom(List<List<double>> sums) {
    final max = sums.expand((r) => r).fold<double>(0, (a, b) => b > a ? b : a);
    return [
      for (final row in sums)
        [
          for (final v in row)
            max <= 0
                ? 0
                : v / max < .15
                    ? 0
                    : v / max < .4
                        ? 1
                        : v / max < .7
                            ? 2
                            : 3
        ]
    ];
  }

  /// Last 7 days against the 7 days before.
  List<StatItem> calculateStats(List<SecurityEvent> events) {
    if (events.isEmpty) return isAvailable ? _emptyStats() : mockStats;

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final twoWeeksAgo = now.subtract(const Duration(days: 14));
    final thisWeek =
        events.where((e) => e.timestamp.isAfter(weekAgo)).toList();
    final lastWeek = events
        .where((e) =>
            e.timestamp.isAfter(twoWeeksAgo) && !e.timestamp.isAfter(weekAgo))
        .toList();

    double avg(List<SecurityEvent> l) =>
        l.isEmpty ? 0 : l.map((e) => e.score).reduce((a, b) => a + b) / l.length;
    String trend(num cur, num prev) {
      if (prev == 0) return cur == 0 ? '→ 0%' : '↑ new';
      final pct = ((cur - prev) / prev * 100).round();
      return pct == 0 ? '→ 0%' : (pct > 0 ? '↑ $pct%' : '↓ ${pct.abs()}%');
    }

    final high = thisWeek.where((e) => e.score >= 7).length;
    final highPrev = lastWeek.where((e) => e.score >= 7).length;
    final a = avg(thisWeek), aPrev = avg(lastWeek);

    return [
      StatItem(
        label: 'Total Events',
        value: thisWeek.length.toString(),
        trend: trend(thisWeek.length, lastWeek.length),
        positive: true,
        icon: Icons.shield_outlined,
        badgeColor: AppColors.paleLavender,
        iconColor: AppColors.iconBlue,
      ),
      StatItem(
        label: 'High Risk Events',
        value: high.toString(),
        trend: trend(high, highPrev),
        positive: high <= highPrev,
        icon: Icons.warning_amber_rounded,
        badgeColor: const Color(0xFFF3BBD0),
        iconColor: AppColors.high,
      ),
      StatItem(
        label: 'Avg. Risk Score',
        value: a.toStringAsFixed(1),
        trend: trend(a, aPrev),
        positive: a <= aPrev,
        icon: Icons.notifications_none_rounded,
        badgeColor: const Color(0xFFC8D9FF),
        iconColor: AppColors.iconBlue,
      ),
    ];
  }

  List<StatItem> _emptyStats() => const [
        StatItem(
          label: 'Total Events',
          value: '0',
          trend: '→ 0%',
          positive: true,
          icon: Icons.shield_outlined,
          badgeColor: AppColors.paleLavender,
          iconColor: AppColors.iconBlue,
        ),
        StatItem(
          label: 'High Risk Events',
          value: '0',
          trend: '→ 0%',
          positive: true,
          icon: Icons.warning_amber_rounded,
          badgeColor: Color(0xFFF3BBD0),
          iconColor: AppColors.high,
        ),
        StatItem(
          label: 'Avg. Risk Score',
          value: '0.0',
          trend: '→ 0%',
          positive: true,
          icon: Icons.notifications_none_rounded,
          badgeColor: Color(0xFFC8D9FF),
          iconColor: AppColors.iconBlue,
        ),
      ];
}
