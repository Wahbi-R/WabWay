import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'client.dart';
import '../trip/app_trip.dart';
import '../trip/app_trip_member.dart';

abstract final class TripService {
  static Future<List<AppTrip>> loadUserTrips() async {
    final data = await supabase
        .from('trips')
        .select()
        .order('created_at', ascending: false);
    return (data as List)
        .map((m) => AppTrip.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  static Future<String> createTrip({
    required String name,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    String defaultCurrency = 'JPY',
  }) async {
    final tripId = await supabase.rpc('create_trip_with_owner', params: {
      'p_name': name.trim(),
      if (destination != null && destination.trim().isNotEmpty)
        'p_destination': destination.trim(),
      if (startDate != null)
        'p_start_date': '${startDate.year.toString().padLeft(4, '0')}-'
            '${startDate.month.toString().padLeft(2, '0')}-'
            '${startDate.day.toString().padLeft(2, '0')}',
      if (endDate != null)
        'p_end_date': '${endDate.year.toString().padLeft(4, '0')}-'
            '${endDate.month.toString().padLeft(2, '0')}-'
            '${endDate.day.toString().padLeft(2, '0')}',
      'p_default_currency': defaultCurrency.toUpperCase(),
    });
    return tripId as String;
  }

  static Future<List<AppTripMember>> loadTripMembers(String tripId) async {
    final data = await supabase
        .from('trip_members')
        .select('user_id, role, profiles(*)')
        .eq('trip_id', tripId);
    return (data as List)
        .map((m) => AppTripMember.fromMap(m as Map<String, dynamic>))
        .toList();
  }

  static Future<void> leaveTrip(String tripId) async {
    final userId = supabase.auth.currentUser!.id;
    await supabase
        .from('trip_members')
        .delete()
        .eq('trip_id', tripId)
        .eq('user_id', userId);
  }

  static Future<void> removeMember(String tripId, String userId) async {
    await supabase
        .from('trip_members')
        .delete()
        .eq('trip_id', tripId)
        .eq('user_id', userId);
  }

  static Future<void> updateTripName(String tripId, String name) async {
    final rows = await supabase
        .from('trips')
        .update({'name': name.trim()})
        .eq('id', tripId)
        .select();
    if (rows.isEmpty) throw Exception('Could not update trip name');
  }

  static Future<void> transferOwnership(
      String tripId, String newOwnerId) async {
    await supabase.rpc('transfer_trip_ownership', params: {
      'p_trip_id':      tripId,
      'p_new_owner_id': newOwnerId,
    });
  }

  static Future<void> deleteTrip(String tripId) async {
    await supabase.from('trips').delete().eq('id', tripId);
  }

  static Future<void> updateTrip(
    String tripId, {
    String? name,
    String? destination,
    DateTime? startDate,
    DateTime? endDate,
    String? defaultCurrency,
    String? coverImageUrl,
    bool clearDestination  = false,
    bool clearStartDate    = false,
    bool clearEndDate      = false,
    bool clearCoverImage   = false,
  }) async {
    String _pad(int n, int w) => n.toString().padLeft(w, '0');
    String _fmtDate(DateTime d) =>
        '${_pad(d.year, 4)}-${_pad(d.month, 2)}-${_pad(d.day, 2)}';

    final updates = <String, dynamic>{
      if (name != null) 'name': name.trim(),
      if (clearDestination) 'destination': null
      else if (destination != null && destination.trim().isNotEmpty)
        'destination': destination.trim(),
      if (clearStartDate) 'start_date': null
      else if (startDate != null) 'start_date': _fmtDate(startDate),
      if (clearEndDate) 'end_date': null
      else if (endDate != null) 'end_date': _fmtDate(endDate),
      if (defaultCurrency != null) 'default_currency': defaultCurrency.toUpperCase(),
      if (clearCoverImage) 'cover_image_url': null
      else if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
    };
    if (updates.isEmpty) return;
    await supabase.from('trips').update(updates).eq('id', tripId);
  }

  static Future<String> uploadCoverImage(
    String tripId,
    String mimeType,
    List<int> bytes,
  ) async {
    final ext = mimeType.contains('png') ? 'png' : 'jpg';
    final path = 'trips/$tripId/cover.$ext';
    await supabase.storage
        .from('trip-covers')
        .uploadBinary(
          path,
          bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
          fileOptions: FileOptions(contentType: mimeType, upsert: true),
        );
    return supabase.storage.from('trip-covers').getPublicUrl(path);
  }
}
