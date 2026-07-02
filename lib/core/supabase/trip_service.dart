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
}
