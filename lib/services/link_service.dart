import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import 'supabase_service.dart';

/// Someone the signed-in user is linked to: a guardian sees residents,
/// a resident sees guardians.
class LinkedPerson {
  const LinkedPerson(
      {required this.userId, required this.role, required this.displayName});
  final String userId;
  final UserRole role;
  final String displayName;
}

/// Resident <-> guardian linking (supabase/migrations/
/// 20261022_resident_guardian_linking.sql). The resident shares a 6-digit
/// code, the guardian enters it. The database then only shows a guardian
/// the events and messages of the residents they are linked to, and the
/// app only subscribes to those residents' push topics.
class LinkService {
  LinkService._();
  static final LinkService instance = LinkService._();

  SupabaseService get _svc => SupabaseService.instance;

  Future<List<LinkedPerson>> myLinks() async {
    if (!_svc.isAvailable || _svc.currentUser == null) return const [];
    final rows = await _svc.client.rpc('my_links');
    if (rows is! List) return const [];
    return [
      for (final r in rows)
        if (r is Map)
          LinkedPerson(
            userId: '${r['user_id']}',
            role: r['role'] == 'guardian' ? UserRole.guardian : UserRole.resident,
            displayName: (r['display_name'] as String?)?.trim().isNotEmpty == true
                ? (r['display_name'] as String).trim()
                : (r['role'] == 'guardian' ? 'Guardian' : 'Resident'),
          ),
    ];
  }

  /// Resident: a new code, valid for 24 hours.
  Future<({String? code, String? error})> createCode() async {
    if (!_svc.isAvailable) {
      return (code: null, error: 'Linking needs Supabase (env.json).');
    }
    try {
      final r = await _svc.client.rpc('create_link_code');
      final code = r is Map ? r['code'] as String? : null;
      return code == null
          ? (code: null, error: 'Could not make a code. Try again.')
          : (code: code, error: null);
    } catch (e) {
      return (code: null, error: _message(e));
    }
  }

  /// Guardian: link to the resident who shared [code]. Null on success.
  Future<String?> redeemCode(String code) async {
    if (!_svc.isAvailable) return 'Linking needs Supabase (env.json).';
    final c = code.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{6}$').hasMatch(c)) return 'Enter the 6-digit code.';
    try {
      await _svc.client.rpc('redeem_link_code', params: {'p_code': c});
      return null;
    } catch (e) {
      return _message(e);
    }
  }

  /// Either side: remove the link to [userId]. Null on success.
  Future<String?> remove(String userId) async {
    if (!_svc.isAvailable) return 'Linking needs Supabase (env.json).';
    try {
      await _svc.client.rpc('remove_link', params: {'p_other': userId});
      return null;
    } catch (e) {
      return _message(e);
    }
  }

  static String _message(Object e) {
    debugPrint('[LinkService] $e');
    if (e is PostgrestException) {
      if (e.code == 'PGRST202' || e.message.contains('Could not find')) {
        return 'Linking is not set up in Supabase yet. Run the SQL file '
            '20261022_resident_guardian_linking.sql.';
      }
      return e.message;
    }
    return 'Could not reach the server. Check your internet connection.';
  }
}
