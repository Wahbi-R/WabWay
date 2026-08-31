import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/crew_data.dart';
import 'client.dart';

abstract final class CrewService {
  static Future<List<TripMessage>> fetchMessages(String tripId) async {
    final rows = await supabase
        .from('trip_messages')
        .select('*, message_reactions(*)')
        .eq('trip_id', tripId)
        .order('created_at', ascending: false)
        .limit(100);
    return rows.map(TripMessage.fromMap).toList().reversed.toList();
  }

  static Future<void> addReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    await supabase.from('message_reactions').upsert(
      {'message_id': messageId, 'user_id': userId, 'emoji': emoji},
      onConflict: 'message_id,user_id,emoji',
    );
  }

  static Future<void> removeReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) async {
    await supabase
        .from('message_reactions')
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', userId)
        .eq('emoji', emoji);
  }

  static Future<void> sendMessage({
    required String tripId,
    required String authorId,
    required String body,
  }) async {
    await supabase.from('trip_messages').insert({
      'trip_id': tripId,
      'author_id': authorId,
      'body': body.trim(),
      'message_type': 'text',
    });
  }

  static Future<void> sendLocationPing({
    required String tripId,
    required String authorId,
    required double lat,
    required double lng,
  }) async {
    await supabase.from('trip_messages').insert({
      'trip_id': tripId,
      'author_id': authorId,
      'body': 'Shared their location',
      'message_type': 'location_ping',
      'lat': lat,
      'lng': lng,
    });
  }

  static Future<void> sendFindMe({
    required String tripId,
    required String authorId,
    required double lat,
    required double lng,
  }) async {
    await supabase.from('trip_messages').insert({
      'trip_id': tripId,
      'author_id': authorId,
      'body': 'Find me!',
      'message_type': 'find_me',
      'lat': lat,
      'lng': lng,
    });
  }

  static Future<void> sendMeetupPoint({
    required String tripId,
    required String authorId,
    required double lat,
    required double lng,
  }) async {
    await supabase.from('trip_messages').insert({
      'trip_id': tripId,
      'author_id': authorId,
      'body': 'Set a meetup point',
      'message_type': 'meetup_point',
      'lat': lat,
      'lng': lng,
    });
  }

  static Future<String> uploadChatImage(String tripId, XFile file) async {
    final bytes = await file.readAsBytes();
    final ext = file.name.contains('.') ? file.name.split('.').last.toLowerCase() : 'jpg';
    final mime = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png'           => 'image/png',
      'gif'           => 'image/gif',
      'webp'          => 'image/webp',
      'heic'          => 'image/heic',
      _               => 'image/jpeg',
    };
    final path = '$tripId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await supabase.storage.from('trip-chat').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mime, upsert: false),
    );
    return supabase.storage.from('trip-chat').getPublicUrl(path);
  }

  static Future<void> sendImageMessage({
    required String tripId,
    required String authorId,
    required String imageUrl,
  }) async {
    await supabase.from('trip_messages').insert({
      'trip_id': tripId,
      'author_id': authorId,
      'body': '',
      'message_type': 'image',
      'image_url': imageUrl,
    });
  }

  static Future<void> upsertLocationShare({
    required String tripId,
    required String userId,
    required double lat,
    required double lng,
  }) async {
    await supabase.from('location_shares').upsert(
      {
        'trip_id': tripId,
        'user_id': userId,
        'lat': lat,
        'lng': lng,
        'is_active': true,
        'last_updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'trip_id,user_id',
    );
  }

  static Future<void> deactivateLocationShare({
    required String tripId,
    required String userId,
  }) async {
    await supabase
        .from('location_shares')
        .update({'is_active': false})
        .eq('trip_id', tripId)
        .eq('user_id', userId);
  }

  static Future<List<LocationShare>> fetchActiveLocations(String tripId) async {
    final rows = await supabase
        .from('location_shares')
        .select()
        .eq('trip_id', tripId)
        .eq('is_active', true);
    return rows.map(LocationShare.fromMap).toList();
  }

  static RealtimeChannel subscribeMessages(
    String tripId,
    void Function() onChanged,
  ) {
    return supabase
        .channel('crew_messages:$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'trip_messages',
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
          table: 'message_reactions',
          callback: (_) => onChanged(),
        )
        .subscribe();
  }

  static RealtimeChannel subscribeLocations(
    String tripId,
    void Function() onChanged,
  ) {
    return supabase
        .channel('crew_locations:$tripId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'location_shares',
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
