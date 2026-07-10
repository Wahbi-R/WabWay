import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/packing_data.dart';
import 'client.dart';

abstract final class PackingService {
  static PackingItem _fromRow(Map<String, dynamic> r) => PackingItem(
        id: r['id'] as String,
        tripId: r['trip_id'] as String,
        title: r['title'] as String,
        isPacked: r['is_packed'] as bool? ?? false,
        createdBy: r['created_by'] as String,
        assignedTo: r['assigned_to'] as String?,
        packedBy: r['packed_by'] as String?,
        sortOrder: r['sort_order'] as int? ?? 0,
      );

  static Future<List<PackingItem>> fetchAll(String tripId) async {
    final rows = await supabase
        .from('packing_items')
        .select()
        .eq('trip_id', tripId)
        .order('sort_order')
        .order('created_at');
    return rows.map(_fromRow).toList();
  }

  static Future<PackingItem> addItem(String tripId, String title, String userId) async {
    final row = await supabase
        .from('packing_items')
        .insert({
          'trip_id': tripId,
          'title': title,
          'created_by': userId,
        })
        .select()
        .single();
    return _fromRow(row);
  }

  static Future<void> setPackedState(String itemId, bool packed, String userId) async {
    await supabase.from('packing_items').update({
      'is_packed': packed,
      'packed_by': packed ? userId : null,
    }).eq('id', itemId);
  }

  static Future<void> renameItem(String itemId, String title) async {
    await supabase
        .from('packing_items')
        .update({'title': title.trim()})
        .eq('id', itemId);
  }

  static Future<void> assignItem(String itemId, String? userId) async {
    await supabase
        .from('packing_items')
        .update({'assigned_to': userId})
        .eq('id', itemId);
  }

  static Future<void> deleteItem(String itemId) async {
    await supabase.from('packing_items').delete().eq('id', itemId);
  }

  static Future<void> reorderItems(List<PackingItem> ordered) async {
    if (ordered.isEmpty) return;
    await supabase.from('packing_items').upsert(
      ordered.asMap().entries.map((e) => {
        'id': e.value.id,
        'sort_order': e.key,
      }).toList(),
      onConflict: 'id',
    );
  }

  static RealtimeChannel subscribe(
    String tripId,
    void Function() onChanged,
  ) {
    return supabase
        .channel('packing_items:$tripId')
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
        .subscribe();
  }
}
