import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/app_profile.dart';
import 'client.dart';

abstract final class TripMemberService {
  /// Looks up a profile by email. Returns null if no account exists.
  /// RLS allows any authenticated user to read all profiles.
  static Future<AppProfile?> findProfileByEmail(String email) async {
    final data = await supabase
        .from('profiles')
        .select()
        .eq('email', email.trim().toLowerCase())
        .maybeSingle();
    if (data == null) return null;
    return AppProfile.fromMap(data);
  }

  /// Adds an existing user to a trip as a member.
  /// RLS enforces that only the trip owner can do this.
  /// Throws [PostgrestException] with code '23505' if already a member.
  static Future<void> addMember({
    required String tripId,
    required String userId,
  }) async {
    await supabase.from('trip_members').insert({
      'trip_id': tripId,
      'user_id': userId,
      'role':    'member',
    });
  }
}
