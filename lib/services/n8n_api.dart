import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';

/// Result of a WF-02 call: ok is true only when n8n answered {ok: true}.
class AppActionResult {
  const AppActionResult(this.ok, this.message, [this.result]);
  final bool ok;
  final String message;
  final Object? result;
}

/// Every change goes through n8n (Build Guide 9.3); the app's Supabase key
/// can only read.
///
/// POST {N8N_BASE}/app-action  {key: APP_KEY, action, ...}
/// Actions: confirm {event_id}, dismiss {event_id}, set_mode {mode},
/// set_demo_time {demo_time}, add_face {label, role, consent_by, image_b64},
/// remove_face {face_id}.
class N8nApi {
  N8nApi._();

  static const _headers = {
    'Content-Type': 'application/json',
    // Without this, ngrok's free tier may answer with a warning page.
    'ngrok-skip-browser-warning': 'true',
  };

  static Future<AppActionResult> appAction(String action,
      [Map<String, Object?> extra = const {}]) async {
    if (!AppConfig.isN8nConfigured) {
      return const AppActionResult(false,
          'N8N_BASE or APP_KEY is missing from this build (env.json).');
    }
    try {
      final res = await http
          .post(Uri.parse('${AppConfig.n8nBase}/app-action'),
              headers: _headers,
              body: jsonEncode({'key': AppConfig.appKey, 'action': action, ...extra}))
          .timeout(const Duration(seconds: 45));
      if (res.statusCode == 401 || res.statusCode == 403) {
        return const AppActionResult(
            false, 'n8n refused the app key. Check APP_KEY against WF-02.');
      }
      if (res.statusCode == 404) {
        return const AppActionResult(false,
            'n8n has no active /app-action webhook. Activate WF-02.');
      }
      if (res.statusCode != 200) {
        return AppActionResult(false, 'n8n answered ${res.statusCode}.');
      }
      final body = jsonDecode(res.body);
      if (body is Map && body['ok'] == true) {
        return AppActionResult(true, 'Done', body['result']);
      }
      return AppActionResult(false, _errorText(body) ?? 'n8n said no.');
    } catch (e) {
      debugPrint('[N8nApi] $action failed: $e');
      return const AppActionResult(false,
          'Could not reach n8n. Is the laptop on and ngrok running?');
    }
  }

  /// WF-02 answers {ok: false, error} for an unknown action, and
  /// {ok: false, result: {error: ...}} when the SQL function refused.
  static String? _errorText(Object? body) {
    if (body is! Map) return null;
    final result = body['result'];
    final e = body['error'] ?? (result is Map ? result['error'] : null);
    if (e == null) return null;
    if (e is Map) return '${e['message'] ?? e['description'] ?? e}';
    return '$e';
  }

  /// POST {N8N_BASE}/watchdog-demo (WF-04) simulates inactivity.
  static Future<AppActionResult> simulateInactivity() async {
    if (!AppConfig.isN8nConfigured) {
      return const AppActionResult(false, 'N8N_BASE is missing from this build.');
    }
    try {
      final res = await http
          .post(Uri.parse('${AppConfig.n8nBase}/watchdog-demo'),
              headers: _headers)
          .timeout(const Duration(seconds: 30));
      return AppActionResult(res.statusCode == 200,
          res.statusCode == 200 ? 'Done' : 'n8n answered ${res.statusCode}.');
    } catch (e) {
      return const AppActionResult(false, 'Could not reach n8n.');
    }
  }
}
