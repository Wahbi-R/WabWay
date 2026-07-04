import '../../data/invite_data.dart';
import 'client.dart';

abstract final class InviteService {
  static InviteCode _fromRow(Map<String, dynamic> r) => InviteCode(
        id:        r['id'] as String,
        tripId:    r['trip_id'] as String,
        code:      r['code'] as String,
        createdAt: DateTime.parse(r['created_at'] as String),
        expiresAt: r['expires_at'] != null
            ? DateTime.parse(r['expires_at'] as String)
            : null,
        usedAt: r['used_at'] != null
            ? DateTime.parse(r['used_at'] as String)
            : null,
      );

  /// Load all non-revoked invite codes for [tripId].
  static Future<List<InviteCode>> loadInvites(String tripId) async {
    final data = await supabase
        .from('trip_invites')
        .select('id, trip_id, code, created_at, expires_at, used_at')
        .eq('trip_id', tripId)
        .isFilter('revoked_at', null)
        .order('created_at', ascending: false);
    return data.map(_fromRow).toList();
  }

  /// Creates a new invite code for [tripId]. Caller must be the trip owner.
  static Future<InviteCode> createInvite(String tripId) async {
    final code = await supabase.rpc(
      'create_trip_invite',
      params: {'p_trip_id': tripId},
    ) as String;
    // Reload to get the full row including id and expires_at
    final rows = await supabase
        .from('trip_invites')
        .select('id, trip_id, code, created_at, expires_at, used_at')
        .eq('trip_id', tripId)
        .eq('code', code)
        .limit(1);
    if (rows.isEmpty) {
      return InviteCode(
        id: '', tripId: tripId, code: code,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );
    }
    return _fromRow(rows.first);
  }

  /// Revokes (soft-deletes) an invite code by setting revoked_at.
  static Future<void> revokeInvite(String inviteId) async {
    await supabase
        .from('trip_invites')
        .update({'revoked_at': DateTime.now().toIso8601String()})
        .eq('id', inviteId);
  }

  /// Redeems [code], adds the current user to the trip, and returns the trip_id.
  static Future<String> redeemInvite(String code) async {
    final result = await supabase.rpc(
      'redeem_trip_invite',
      params: {'p_code': code},
    );
    return result as String;
  }
}
