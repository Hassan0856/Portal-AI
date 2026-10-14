import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../screens/auth_screens.dart';
import '../screens/dashboard_screen.dart';
import '../screens/gallery_screens.dart';
import '../screens/help_screen.dart';
import '../screens/guardian_email_screen.dart';
import '../screens/messages_screens.dart';
import '../screens/settings_screens.dart';
import '../screens/sos_screen.dart';

/// The app's router, for opening screens from a notification tap.
GoRouter? appRouter;

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authProvider, (_, __) => refresh.value++);
  ref.listen(residentFaceProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: '/welcome',
    refreshListenable: refresh,
    redirect: (context, state) {
      final role = ref.read(authProvider);
      final loc = state.matchedLocation;
      final isPublic = loc == '/welcome' || loc.startsWith('/login');
      if (role == null && !isPublic) return '/welcome';
      if (role != null && isPublic) return '/dashboard';
      if (loc.startsWith('/settings/resident-emails') &&
          role != UserRole.guardian) {
        return '/dashboard';
      }
      // Setup gate (Build Guide 9.1 / 9.7): until a reference photo of the
      // resident exists, open Picture Recognition instead of the dashboard.
      if (loc == '/dashboard' &&
          ref.read(residentFaceProvider).valueOrNull == false) {
        return '/settings/picture-recognition';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
      GoRoute(
        path: '/login/resident',
        builder: (_, __) => const LoginScreen(role: UserRole.resident),
      ),
      GoRoute(
        path: '/login/guardian',
        builder: (_, __) => const LoginScreen(role: UserRole.guardian),
      ),
      GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
      GoRoute(
        path: '/settings',
        builder: (_, __) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'resident-emails',
            builder: (_, __) => const GuardianEmailScreen(),
          ),
          GoRoute(
            path: 'picture-recognition',
            builder: (_, __) => const PictureRecognitionScreen(),
          ),
          GoRoute(
            path: 'privacy',
            builder: (_, __) => const PrivacyStorageScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/messages',
        builder: (_, __) => const MessageHistoryScreen(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (_, s) => MessageDetailScreen(id: s.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(path: '/gallery', builder: (_, __) => const EventGalleryScreen()),
      GoRoute(
        path: '/events/:id',
        builder: (_, s) => EventDetailScreen(id: s.pathParameters['id']!),
      ),
      GoRoute(path: '/help', builder: (_, __) => const HelpAboutScreen()),
      GoRoute(
        path: '/sos',
        builder: (_, s) => SosScreen(
            data: s.extra is Map ? Map<String, dynamic>.from(s.extra as Map) : const {}),
      ),
    ],
  );
  appRouter = router;
  return router;
});
