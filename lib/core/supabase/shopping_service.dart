import '../../data/shopping_data.dart';
import 'client.dart';

abstract final class ShoppingService {
  // ─── Row → model ────────────────────────────────────────────────────────────

  static ShoppingItem _fromRow(Map<String, dynamic> row) {
    final spot = row['spots'] as Map<String, dynamic>?;
    return ShoppingItem(
      id:           row['id']         as String,
      tripId:       row['trip_id']    as String,
      name:         row['name']       as String,
      quantity:     row['quantity']   as String?,
      notes:        row['notes']      as String?,
      spotId:       row['spot_id']    as String?,
      spotName:     spot?['name']     as String?,
      spotCategory: spot?['category'] as String?,
      checked:      row['checked']    as bool? ?? false,
      checkedBy:    row['checked_by'] as String?,
      checkedAt:    row['checked_at'] != null
          ? DateTime.tryParse(row['checked_at'] as String)
          : null,
      createdBy:    row['created_by'] as String? ?? '',
      createdAt:    DateTime.parse(row['created_at'] as String),
      sortOrder:    row['sort_order'] as int? ?? 0,
    );
  }

  // ─── Queries ────────────────────────────────────────────────────────────────

  static Future<List<ShoppingItem>> loadAll(String tripId) async {
    final data = await supabase
        .from('shopping_items')
        .select('*, spots(id, name, category)')
        .eq('trip_id', tripId)
        .order('checked',    ascending: true)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);
    return data.map((r) => _fromRow(r)).toList();
  }

  static Future<ShoppingItem> create({
    required String tripId,
    required String userId,
    required String name,
    String? quantity,
    String? notes,
    String? spotId,
    int     sortOrder = 0,
  }) async {
    final inserted = await supabase.from('shopping_items').insert({
      'trip_id':    tripId,
      'name':       name.trim(),
      'created_by': userId,
      'sort_order': sortOrder,
      if (quantity != null && quantity.trim().isNotEmpty) 'quantity': quantity.trim(),
      if (notes    != null && notes.trim().isNotEmpty)    'notes':    notes.trim(),
      if (spotId   != null)                               'spot_id':  spotId,
    }).select('*, spots(id, name, category)').single();
    return _fromRow(inserted);
  }

  static Future<ShoppingItem> update(ShoppingItem item) async {
    final updated = await supabase
        .from('shopping_items')
        .update({
          'name':      item.name.trim(),
          'quantity':  item.quantity?.trim(),
          'notes':     item.notes?.trim(),
          'spot_id':   item.spotId,
        })
        .eq('id', item.id)
        .select('*, spots(id, name, category)')
        .single();
    return _fromRow(updated);
  }

  static Future<ShoppingItem> setChecked(
      String id, bool checked, String userId) async {
    final updated = await supabase
        .from('shopping_items')
        .update({
          'checked':    checked,
          'checked_by': checked ? userId : null,
          'checked_at': checked ? DateTime.now().toIso8601String() : null,
        })
        .eq('id', id)
        .select('*, spots(id, name, category)')
        .single();
    return _fromRow(updated);
  }

  static Future<void> delete(String id) async {
    await supabase.from('shopping_items').delete().eq('id', id);
  }

  static Future<void> deleteChecked(String tripId) async {
    await supabase
        .from('shopping_items')
        .delete()
        .eq('trip_id', tripId)
        .eq('checked', true);
  }
}
