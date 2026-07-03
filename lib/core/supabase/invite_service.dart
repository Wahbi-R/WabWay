import 'client.dart';

abstract final class InviteService {
  /// Creates a new invite code for [tripId]. Caller must be the trip owner.
  /// Returns the 8-character uppercase code (e.g. "A1B2C3D4").
  static Future<String> createInvite(String tripId) async {
    final result = await supabase.rpc(
      'create_trip_invite',
      params: {'p_trip_id': tripId},
    );
    return result as String;
  }

  /// Redeems [code], adds the current user to the trip, and returns the
  /// trip_id so the caller can navigate into the trip.
  static Future<String> redeemInvite(String code) async {
    final result = await supabase.rpc(
      'redeem_trip_invite',
      params: {'p_code': code},
    );
    return result as String;
  }
}
