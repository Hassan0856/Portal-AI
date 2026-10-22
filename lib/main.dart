import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_colors.dart';
import 'core/app_router.dart';
import 'providers/providers.dart';
import 'services/firebase_service.dart';
import 'services/supabase_service.dart';

// Configuration comes from --dart-define-from-file=env.json at build time
// (see lib/core/app_config.dart and codemagic.yaml).
//
// Start-up never stops the app from opening: each step is guarded and timed,
// and any error is logged (adb logcat, tag "flutter") instead of closing the
// app. Without Supabase or Firebase the app still opens (demo data, no push).
void main() {
  runZonedGuarded(_start, (error, stack) {
    debugPrint('[PortalAI] Uncaught error: $error\n$stack');
  });
}

Future<void> _start() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('[PortalAI] Flutter error: ${details.exceptionAsString()}');
  };

  await _step('Supabase', SupabaseService.instance.initialize);
  // Push and the SOS alarm (Android only; skipped on web)
  await _step('Firebase', FirebaseService.instance.initialize);

  // A saved login: read its role again. The push topics are then set by
  // pushTopicsProvider (own household only).
  await _step('Session', SupabaseService.instance.restoreSession);
  runApp(const ProviderScope(child: PortalApp()));
}

/// Runs one start-up step. A failure or a step that hangs (for example a
/// permission prompt that never returns) is logged and skipped.
Future<void> _step(String name, Future<void> Function() run) async {
  try {
    await run().timeout(const Duration(seconds: 15));
  } catch (e, s) {
    debugPrint('[PortalAI] Start-up step "$name" failed: $e\n$s');
  }
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
    // Keeps push topics on this household only (never rebuilds the app).
    ref.watch(pushTopicsProvider);
    return MaterialApp.router(
      title: 'PortalAI',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      scaffoldMessengerKey: FirebaseService.messengerKey,
      routerConfig: ref.watch(routerProvider),

    );
  }
}
