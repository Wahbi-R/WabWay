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

  /// Remove a connection between two specific entities (order-insensitive).
  static Future<void> removeForEntityPair(String idA, String idB) async {
    await supabase
        .from('trip_connections')
        .delete()
        .eq('entity_a_id', idA)
        .eq('entity_b_id', idB);
    await supabase
        .from('trip_connections')
        .delete()
        .eq('entity_a_id', idB)
        .eq('entity_b_id', idA);
  }

  /// Load the spot id linked to a plan item via trip_connections, or null.
  static Future<String?> fetchSpotForPlanItem(String itemId) async {
    final rows = await supabase
        .from('trip_connections')
        .select('entity_a_id, entity_a_type, entity_b_id, entity_b_type')
        .or('entity_a_id.eq.$itemId,entity_b_id.eq.$itemId');
    for (final r in rows) {
      if (r['entity_a_type'] == 'plan_item' && r['entity_b_type'] == 'spot') {
        return r['entity_b_id'] as String;
      }
      if (r['entity_b_type'] == 'plan_item' && r['entity_a_type'] == 'spot') {
        return r['entity_a_id'] as String;
      }
    }
    return null;
  }

  /// Batch-load spot and stay connections for a list of plan item ids.
  /// Returns ({itemId → spotId}, {itemId → stayId}) in a single query.
  static Future<(Map<String, String>, Map<String, String>)>
      fetchSpotAndStayMapsForItems(List<String> itemIds) async {
    if (itemIds.isEmpty) return (<String, String>{}, <String, String>{});
    final idSet = itemIds.toSet();
    final rows = await supabase
        .from('trip_connections')
        .select('entity_a_id, entity_a_type, entity_b_id, entity_b_type')
        .or('entity_a_id.in.(${itemIds.join(',')}),entity_b_id.in.(${itemIds.join(',')})');
    final spotMap = <String, String>{};
    final stayMap = <String, String>{};
    for (final r in rows) {
      final aType = r['entity_a_type'] as String;
      final bType = r['entity_b_type'] as String;
      final aId   = r['entity_a_id'] as String;
      final bId   = r['entity_b_id'] as String;
      if (aType == 'plan_item' && idSet.contains(aId)) {
        if (bType == 'spot') spotMap[aId] = bId;
        if (bType == 'stay') stayMap[aId] = bId;
      } else if (bType == 'plan_item' && idSet.contains(bId)) {
        if (aType == 'spot') spotMap[bId] = aId;
        if (aType == 'stay') stayMap[bId] = aId;
      }
    }
    return (spotMap, stayMap);
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
