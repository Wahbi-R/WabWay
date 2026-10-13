import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/connection_data.dart';
import 'client.dart';

abstract final class ConnectionService {
  /// Null when the row uses an entity type this build doesn't know (skipped).
  static TripConnection? _fromRow(Map<String, dynamic> r) {
    final a = EntityType.tryFromDb(r['entity_a_type'] as String);
    final b = EntityType.tryFromDb(r['entity_b_type'] as String);
    if (a == null || b == null) return null;
    return TripConnection(
      id:          r['id'] as String,
      tripId:      r['trip_id'] as String,
      entityAType: a,
      entityAId:   r['entity_a_id'] as String,
      entityBType: b,
      entityBId:   r['entity_b_id'] as String,
      createdAt:   DateTime.parse(r['created_at'] as String),
    );
  }

  /// Legacy document_links rows are surfaced as connections so ONE "Connected"
  /// list shows every link (doc ↔ spot/travel/receipt/cash/plan item).
  /// Their ids are prefixed so [remove] knows which table to delete from.
  static const _legacyPrefix = 'dl:';

  static EntityType? _fromDocLinkedType(String t) => switch (t) {
        'spot'            => EntityType.spot,
        'travel_item'     => EntityType.travel,
        'receipt'         => EntityType.receipt,
        'cash_withdrawal' => EntityType.cash,
        'itinerary_item'  => EntityType.planItem,
        _                 => null, // itinerary_day / trip: not shown as connections
      };

  static TripConnection? _fromDocLinkRow(Map<String, dynamic> r, String tripId) {
    final peer = _fromDocLinkedType(r['linked_type'] as String);
    if (peer == null) return null;
    return TripConnection(
      id:          '$_legacyPrefix${r['id']}',
      tripId:      tripId,
      entityAType: EntityType.doc,
      entityAId:   r['document_id'] as String,
      entityBType: peer,
      entityBId:   r['linked_id'] as String,
      createdAt:   DateTime.parse(r['created_at'] as String),
    );
  }

  /// All connections that involve [entityId] (on either side), merged with
  /// legacy document_links for the same entity and de-duplicated by peer.
  static Future<List<TripConnection>> fetchForEntity(String entityId, {String tripId = ''}) async {
    final results = await Future.wait([
      supabase.from('trip_connections').select().eq('entity_a_id', entityId),
      supabase.from('trip_connections').select().eq('entity_b_id', entityId),
      supabase.from('document_links').select().eq('document_id', entityId),
      supabase.from('document_links').select().eq('linked_id', entityId),
    ]);
    final out = <TripConnection>[];
    final seenPeers = <String>{};
    void add(TripConnection? c) {
      if (c == null) return;
      final peerKey = '${c.peerType(entityId).name}:${c.peerId(entityId)}';
      if (seenPeers.add(peerKey)) out.add(c);
    }
    for (final r in [...results[0], ...results[1]]) {
      add(_fromRow(r));
    }
    for (final r in [...results[2], ...results[3]]) {
      add(_fromDocLinkRow(r, tripId));
    }
    return out..sort((x, y) => x.createdAt.compareTo(y.createdAt));
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
    return _fromRow(row)!;
  }

  /// Removes the link between the two entities of [c] — from trip_connections
  /// (either direction) AND legacy document_links, since migration 047 copied
  /// rows rather than moving them (deleting one copy would let the other
  /// reappear).
  static Future<void> remove(TripConnection c) async {
    await Future.wait([
      removeForEntityPair(c.entityAId, c.entityBId),
      supabase.from('document_links').delete()
          .eq('document_id', c.entityAId).eq('linked_id', c.entityBId),
      supabase.from('document_links').delete()
          .eq('document_id', c.entityBId).eq('linked_id', c.entityAId),
    ]);
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
    const chunkSize = 50;
    final idSet = itemIds.toSet();
    final futures = <Future<List<Map<String, dynamic>>>>[];
    for (var i = 0; i < itemIds.length; i += chunkSize) {
      final chunk = itemIds.sublist(i, i + chunkSize > itemIds.length ? itemIds.length : i + chunkSize);
      futures.add(supabase
          .from('trip_connections')
          .select('entity_a_id, entity_a_type, entity_b_id, entity_b_type')
          .or('entity_a_id.in.(${chunk.join(',')}),entity_b_id.in.(${chunk.join(',')})'));
    }
    final allRows = (await Future.wait(futures)).expand((r) => r).toList();
    final spotMap = <String, String>{};
    final stayMap = <String, String>{};
    for (final r in allRows) {
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
