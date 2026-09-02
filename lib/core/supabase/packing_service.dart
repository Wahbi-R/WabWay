import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/offline_cache.dart';
import '../../data/packing_data.dart';
import 'client.dart';

abstract final class PackingService {
  static PackingItem _fromRow(Map<String, dynamic> r) {
    final checksJson = r['packing_checks'] as List? ?? [];
    final checks = checksJson
        .map((c) => PackingCheck(
              userId: c['user_id'] as String,
              checkedAt: DateTime.parse(c['checked_at'] as String),
            ))
        .toList();
    return PackingItem(
      id: r['id'] as String,
      tripId: r['trip_id'] as String,
      title: r['title'] as String,
      checks: checks,
      createdBy: r['created_by'] as String,
      sortOrder: r['sort_order'] as int? ?? 0,
    );
  }

  static Future<List<PackingItem>> fetchAll(String tripId) async {
    final rows = await supabase
        .from('packing_items')
        .select('*, packing_checks(*)')
        .eq('trip_id', tripId)
        .order('sort_order')
        .order('created_at');
    await OfflineCache.write(OfflineCache.packingKey(tripId), rows);
    return rows.map(_fromRow).toList();
  }

  static Future<List<PackingItem>?> loadFromCache(String tripId) =>
      OfflineCache.read(
        OfflineCache.packingKey(tripId),
        (json) => (json as List)
            .map((r) => _fromRow(Map<String, dynamic>.from(r as Map)))
            .toList(),
      );

  static Future<PackingItem> addItem(
      String tripId, String title, String userId) async {
    final row = await supabase
        .from('packing_items')
        .insert({'trip_id': tripId, 'title': title, 'created_by': userId})
        .select('*, packing_checks(*)')
        .single();
    return _fromRow(row);
  }

  static Future<void> toggleCheck(
      String itemId, String tripId, String userId, bool currentlyChecked) async {
    if (currentlyChecked) {
      await supabase
          .from('packing_checks')
          .delete()
          .eq('item_id', itemId)
          .eq('user_id', userId);
    } else {
      await supabase.from('packing_checks').insert({
        'item_id': itemId,
        'trip_id': tripId,
        'user_id': userId,
      });
    }
  }

  static Future<void> checkAll(String tripId, String userId) async {
    final rows = await supabase
        .from('packing_items')
        .select('id')
        .eq('trip_id', tripId);
    if (rows.isEmpty) return;
    await supabase.from('packing_checks').upsert(
      rows
          .map((r) => {
                'item_id': r['id'] as String,
                'trip_id': tripId,
                'user_id': userId,
              })
          .toList(),
      onConflict: 'item_id,user_id',
      ignoreDuplicates: true,
    );
  }

  static Future<void> clearMyChecks(String tripId, String userId) async {
    await supabase
        .from('packing_checks')
        .delete()
        .eq('trip_id', tripId)
        .eq('user_id', userId);
  }

  static Future<void> renameItem(String itemId, String title) async {
    await supabase
        .from('packing_items')
        .update({'title': title.trim()})
        .eq('id', itemId);
  }

  static Future<void> deleteItem(String itemId) async {
    await supabase.from('packing_items').delete().eq('id', itemId);
  }

  static Future<void> reorderItems(List<PackingItem> ordered) async {
    if (ordered.isEmpty) return;
    await supabase.from('packing_items').upsert(
      ordered
          .asMap()
          .entries
          .map((e) => {'id': e.value.id, 'sort_order': e.key})
          .toList(),
      onConflict: 'id',
    );
  }

  static RealtimeChannel subscribe(
    String tripId,
    void Function() onChanged,
  ) {
    return supabase
        .channel('packing:$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'packing_items',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId,
          ),
          callback: (_) => onChanged(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'packing_checks',
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
