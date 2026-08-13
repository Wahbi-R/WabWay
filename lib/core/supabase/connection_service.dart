import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/connection_data.dart';
import 'client.dart';

abstract final class ConnectionService {
  static TripConnection _fromRow(Map<String, dynamic> r) => TripConnection(
        id:          r['id'] as String,
        tripId:      r['trip_id'] as String,
        entityAType: EntityType.fromDb(r['entity_a_type'] as String),
        entityAId:   r['entity_a_id'] as String,
        entityBType: EntityType.fromDb(r['entity_b_type'] as String),
        entityBId:   r['entity_b_id'] as String,
        createdAt:   DateTime.parse(r['created_at'] as String),
      );

  /// All connections that involve [entityId] (on either side).
  static Future<List<TripConnection>> fetchForEntity(String entityId) async {
    final a = await supabase
        .from('trip_connections')
        .select()
        .eq('entity_a_id', entityId);
    final b = await supabase
        .from('trip_connections')
        .select()
        .eq('entity_b_id', entityId);
    final all = {...a.map(_fromRow), ...b.map(_fromRow)};
    return all.toList()..sort((x, y) => x.createdAt.compareTo(y.createdAt));
  }

  static Future<TripConnection> add({
    required String     tripId,
    required String     userId,
    required EntityType typeA,
    required String     idA,
    required EntityType typeB,
    required String     idB,
  }) async {
    final row = await supabase
        .from('trip_connections')
        .insert({
          'trip_id':       tripId,
          'created_by':    userId,
          'entity_a_type': typeA.dbValue,
          'entity_a_id':   idA,
          'entity_b_type': typeB.dbValue,
          'entity_b_id':   idB,
        })
        .select()
        .single();
    return _fromRow(row);
  }

  static Future<void> remove(String connectionId) async {
    await supabase.from('trip_connections').delete().eq('id', connectionId);
  }

  static RealtimeChannel subscribe(
    String tripId,
    void Function() onChanged,
  ) {
    return supabase
        .channel('trip_connections:$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'trip_connections',
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
