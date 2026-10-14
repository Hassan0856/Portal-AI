/// Build-time configuration (Build Guide v4, 4.4 and 9.7).
///
/// Values come from `--dart-define-from-file=env.json` at build time:
///   SUPABASE_URL, SUPABASE_ANON_KEY, N8N_BASE, APP_KEY
/// In Codemagic, env.json is written by the pre-build script from the
/// workflow's environment variables (see codemagic.yaml). env.json is never
/// committed. Never put the Supabase service_role key or the camera's
/// DEVICE_KEY in the app.
class AppConfig {
  AppConfig._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// n8n webhook base, e.g. https://YOUR-DOMAIN.ngrok-free.app/webhook
  static const String _n8nBaseRaw = String.fromEnvironment('N8N_BASE');

  /// Must equal the value in WF-02's "Key ok?" IF node.
  static const String appKey = String.fromEnvironment('APP_KEY');

  static String get n8nBase => _n8nBaseRaw.trim().endsWith('/')
      ? _n8nBaseRaw.trim().substring(0, _n8nBaseRaw.trim().length - 1)
      : _n8nBaseRaw.trim();

  static bool get isSupabaseConfigured =>
      supabaseUrl.startsWith('http') &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR-PROJECT') &&
      !supabaseAnonKey.contains('your-anon-key');

  static bool get isN8nConfigured =>
      n8nBase.startsWith('http') && appKey.isNotEmpty;

  /// Host of N8N_BASE, safe to show on screen (never show the keys).
  static String get n8nHost => Uri.tryParse(n8nBase)?.host ?? '';
}
