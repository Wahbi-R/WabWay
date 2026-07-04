import '../../data/activity_data.dart';
import 'client.dart';

abstract final class ActivityService {
  static ActivityEvent _fromRow(Map<String, dynamic> r) {
    final profiles = r['profiles'] as Map<String, dynamic>?;
    final actorName = (profiles?['display_name'] as String?) ?? 'Someone';

    return ActivityEvent(
      id:          r['id'] as String,
      tripId:      r['trip_id'] as String,
      actorId:     r['actor_id'] as String,
      actorName:   actorName,
      type:        ActivityEventType.fromDb(r['event_type'] as String),
      entityId:    r['entity_id'] as String,
      entityTitle: r['entity_title'] as String?,
      meta:        r['meta'] as Map<String, dynamic>?,
      createdAt:   DateTime.parse(r['created_at'] as String),
    );
  }

  static Future<List<ActivityEvent>> loadEvents(
    String tripId, {
    int limit = 30,
  }) async {
    final data = await supabase
        .from('activity_events')
        .select('*, profiles(display_name)')
        .eq('trip_id', tripId)
        .order('created_at', ascending: false)
        .limit(limit);
    return data.map(_fromRow).toList();
  }
}
