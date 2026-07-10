import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/pins_data.dart';
import 'client.dart';

abstract final class PinsService {
  static Future<List<TripPin>> fetchPinned(String tripId) async {
    final rows = await supabase
        .from('trip_pins')
        .select()
        .eq('trip_id', tripId)
        .eq('is_pinned', true)
        .order('created_at', ascending: false);
    return rows.map(TripPin.fromMap).toList();
  }

  static Future<List<TripPin>> fetchAll(String tripId) async {
    final rows = await supabase
        .from('trip_pins')
        .select()
        .eq('trip_id', tripId)
        .order('created_at', ascending: false);
    return rows.map(TripPin.fromMap).toList();
  }

  static Future<TripPin> post({
    required String tripId,
    required String authorId,
    required String body,
  }) async {
    final row = await supabase
        .from('trip_pins')
        .insert({'trip_id': tripId, 'author_id': authorId, 'body': body.trim()})
        .select()
        .single();
    return TripPin.fromMap(row);
  }

  static Future<void> unpin(String pinId) async {
    await supabase.from('trip_pins').update({'is_pinned': false}).eq('id', pinId);
  }

  static Future<void> delete(String pinId) async {
    await supabase.from('trip_pins').delete().eq('id', pinId);
  }

  static RealtimeChannel subscribe(String tripId, void Function() onChanged) {
    return supabase
        .channel('pins:$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trip_pins',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (_) => onChanged(),
        )
        .subscribe();
  }
}
