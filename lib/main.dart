import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_colors.dart';
import 'core/app_router.dart';
import 'services/firebase_service.dart';
import 'services/supabase_service.dart';

// Configuration comes from --dart-define-from-file=env.json at build time
// (see lib/core/app_config.dart and codemagic.yaml).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseService.instance.initialize();
  // Push and the SOS alarm (Android only; skipped on web)
  await FirebaseService.instance.initialize();

  // A saved login: read its role again and re-apply the alert topic, which
  // repairs a phone whose topic subscription was lost.
  await SupabaseService.instance.restoreSession();
  final role = SupabaseService.instance.cachedRole;
  if (role != null) {
    final prefs = await SharedPreferences.getInstance();
    unawaited(FirebaseService.instance.applyRoleTopics(role,
        status: prefs.getBool('systemUpdates') ?? true,
        digest: prefs.getBool('activityAlerts') ?? true));
  }

  runApp(const ProviderScope(child: PortalApp()));
}

class PortalApp extends ConsumerStatefulWidget {
  const PortalApp({super.key});

  @override
  ConsumerState<PortalApp> createState() => _PortalAppState();
}

class _PortalAppState extends ConsumerState<PortalApp> {
  @override
  void initState() {
    super.initState();
    // Opened by tapping a notification, or by the SOS alarm, while closed
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => FirebaseService.instance.handleLaunch());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PortalAI',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      scaffoldMessengerKey: FirebaseService.messengerKey,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
