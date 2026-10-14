import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

// ─────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────

/// A resident profile summary for display in the guardian email screen.
class LinkedResident {
  const LinkedResident({required this.userId, required this.displayName});
  final String userId;
  final String displayName;
}

/// A single contact email entry stored in public.guardian_resident_emails.
class ContactEmail {
  const ContactEmail({
    required this.id,
    required this.email,
    this.label,
    required this.status,
    required this.createdAt,
  });
  final String id;
  final String email;
  final String? label;
  final String status;
  final DateTime createdAt;
}

// ─────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────

/// Supabase operations scoped exclusively to guardian email management.
///
/// Uses the actual database schema:
/// - public.guardian_resident_links (guardian_user_id, resident_user_id, created_at)
/// - public.guardian_resident_emails (id, guardian_user_id, resident_user_id, email, label, verification_status, created_at, updated_at)
/// - public.profiles (user_id, role, display_name, created_at)
///
/// Every public method:
///   1. Confirms Supabase is available.
///   2. Confirms an authenticated user session exists.
///   3. Verifies guardian-resident relationship before exposing or modifying resident data.
///   4. Relies on DB-level RLS to enforce security.
class GuardianEmailService {
  GuardianEmailService._();
  static final GuardianEmailService instance = GuardianEmailService._();

  SupabaseClient get _client => SupabaseService.instance.client;
  bool get _available => SupabaseService.instance.isAvailable;
  User? get _user => SupabaseService.instance.currentUser;

  // ─── Relationship Verification ─────────────────────────────────────

  /// Verifies whether the signed-in guardian has an authorized link
  /// to [residentId] in public.guardian_resident_links.
  Future<bool> isGuardianLinkedToResident(String residentId) async {
    if (!_available) return false;
    final uid = _user?.id;
    if (uid == null) return false;

    try {
      final rows = await _client
          .from('guardian_resident_links')
          .select('resident_user_id')
          .eq('guardian_user_id', uid)
          .eq('resident_user_id', residentId)
          .limit(1);

      return (rows as List).isNotEmpty;
    } catch (e) {
      debugPrint('[GuardianEmailService] isGuardianLinkedToResident error: $e');
      return false;
    }
  }

  // ─── Residents ────────────────────────────────────────────────────

  /// Returns all authorized residents linked to the signed-in guardian
  /// via public.guardian_resident_links.
  Future<List<LinkedResident>> fetchLinkedResidents() async {
    if (!_available) return [];
    final uid = _user?.id;
    if (uid == null) return [];

    try {
      final linkRows = await _client
          .from('guardian_resident_links')
          .select('resident_user_id')
          .eq('guardian_user_id', uid);

      if ((linkRows as List).isEmpty) return [];

      final residentIds = linkRows
          .map((r) => r['resident_user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      if (residentIds.isEmpty) return [];

      // Query display names from profiles
      final nameMap = <String, String>{};
      try {
        final profileRows = await _client
            .from('profiles')
            .select('user_id, display_name')
            .inFilter('user_id', residentIds);

        for (final p in (profileRows as List)) {
          final pid = p['user_id']?.toString();
          final raw = (p['display_name'] as String?)?.trim();
          if (pid != null && raw != null && raw.isNotEmpty) {
            nameMap[pid] = raw;
          }
        }
      } catch (e) {
        debugPrint('[GuardianEmailService] profiles lookup note: $e');
      }

      return residentIds.map((rid) {
        final name = nameMap[rid] ??
            (rid.length > 8 ? 'Resident ${rid.substring(0, 8)}…' : 'Resident $rid');
        return LinkedResident(
          userId: rid,
          displayName: name,
        );
      }).toList();
    } catch (e) {
      debugPrint('[GuardianEmailService] fetchLinkedResidents error: $e');
      rethrow;
    }
  }

  // ─── Emails ───────────────────────────────────────────────────────

  /// Returns all contact emails for [residentId] owned by this guardian.
  ///
  /// Verifies the guardian-resident relationship before querying.
  Future<List<ContactEmail>> fetchEmails(String residentId) async {
    if (!_available) return [];
    final uid = _user?.id;
    if (uid == null) return [];

    try {
      // Strict authorization check: must be linked in guardian_resident_links
      final isLinked = await isGuardianLinkedToResident(residentId);
      if (!isLinked) {
        debugPrint('[GuardianEmailService] Guardian $uid is not linked to resident $residentId');
        return [];
      }

      final rows = await _client
          .from('guardian_resident_emails')
          .select()
          .eq('resident_user_id', residentId)
          .eq('guardian_user_id', uid)
          .order('created_at', ascending: true);

      return (rows as List)
          .map((r) => _mapEmail(r as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[GuardianEmailService] fetchEmails error: $e');
      rethrow;
    }
  }

  /// Inserts a new contact email for [residentId] into guardian_resident_emails.
  ///
  /// Verifies guardian authorization before saving.
  Future<String?> addEmail({
    required String residentId,
    required String email,
    String? label,
  }) async {
    if (!_available) return 'Supabase is not available.';
    final uid = _user?.id;
    if (uid == null) return 'Not authenticated.';

    try {
      final isLinked = await isGuardianLinkedToResident(residentId);
      if (!isLinked) {
        return 'Access denied. You are not authorized to manage emails for this resident.';
      }

      await _client.from('guardian_resident_emails').insert({
        'resident_user_id': residentId,
        'guardian_user_id': uid,
        'email': email.trim().toLowerCase(),
        if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
        'verification_status': 'saved',
      });
      return null;
    } catch (e) {
      debugPrint('[GuardianEmailService] addEmail error: $e');
      final msg = e.toString().toLowerCase();
      if (msg.contains('unique') || msg.contains('duplicate')) {
        return 'This email address is already saved for this resident.';
      }
      if (msg.contains('violates row-level security') ||
          msg.contains('permission denied')) {
        return 'Access denied. Ensure you are an active guardian for this resident.';
      }
      return 'Could not save email. Check connection and try again.';
    }
  }

  /// Updates the label of an existing email entry.
  Future<String?> updateLabel({
    required String emailId,
    required String label,
  }) async {
    if (!_available) return 'Supabase is not available.';
    final uid = _user?.id;
    if (uid == null) return 'Not authenticated.';

    try {
      await _client
          .from('guardian_resident_emails')
          .update({
            'label': label.trim().isEmpty ? null : label.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', emailId)
          .eq('guardian_user_id', uid);
      return null;
    } catch (e) {
      debugPrint('[GuardianEmailService] updateLabel error: $e');
      return 'Could not update label: $e';
    }
  }

  /// Deletes an email entry.
  Future<String?> deleteEmail(String emailId) async {
    if (!_available) return 'Supabase is not available.';
    final uid = _user?.id;
    if (uid == null) return 'Not authenticated.';

    try {
      await _client
          .from('guardian_resident_emails')
          .delete()
          .eq('id', emailId)
          .eq('guardian_user_id', uid);
      return null;
    } catch (e) {
      debugPrint('[GuardianEmailService] deleteEmail error: $e');
      return 'Could not remove email: $e';
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  ContactEmail _mapEmail(Map<String, dynamic> row) {
    final raw = row['created_at'];
    final ts = raw is String
        ? (DateTime.tryParse(raw) ?? DateTime.now())
        : DateTime.now();
    return ContactEmail(
      id: row['id'].toString(),
      email: row['email'].toString(),
      label: row['label']?.toString(),
      status: (row['verification_status'] ?? row['status'] ?? 'saved').toString(),
      createdAt: ts,
    );
  }
}
