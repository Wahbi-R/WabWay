enum MessageType { text, locationPing, findMe, meetupPoint }

class LocationShare {
  const LocationShare({
    required this.id,
    required this.tripId,
    required this.userId,
    required this.lat,
    required this.lng,
    required this.isActive,
    required this.lastUpdatedAt,
  });

  final String id;
  final String tripId;
  final String userId;
  final double lat;
  final double lng;
  final bool isActive;
  final DateTime lastUpdatedAt;

  factory LocationShare.fromMap(Map<String, dynamic> m) => LocationShare(
        id: m['id'] as String,
        tripId: m['trip_id'] as String,
        userId: m['user_id'] as String,
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        isActive: (m['is_active'] as bool?) ?? false,
        lastUpdatedAt: DateTime.parse(m['last_updated_at'] as String),
      );
}

class TripMessage {
  const TripMessage({
    required this.id,
    required this.tripId,
    required this.authorId,
    required this.body,
    required this.type,
    required this.createdAt,
    this.lat,
    this.lng,
    this.reactions = const {},
  });

  final String id;
  final String tripId;
  final String authorId;
  final String body;
  final MessageType type;
  final double? lat;
  final double? lng;
  final DateTime createdAt;
  // emoji → list of userIds who reacted with that emoji
  final Map<String, List<String>> reactions;

  factory TripMessage.fromMap(Map<String, dynamic> m) {
    final reactionRows = m['message_reactions'] as List? ?? [];
    final reactions = <String, List<String>>{};
    for (final r in reactionRows) {
      final emoji  = r['emoji'] as String;
      final userId = r['user_id'] as String;
      reactions.putIfAbsent(emoji, () => []).add(userId);
    }
    return TripMessage(
      id:        m['id'] as String,
      tripId:    m['trip_id'] as String,
      authorId:  m['author_id'] as String,
      body:      m['body'] as String,
      type: switch (m['message_type'] as String?) {
        'location_ping' => MessageType.locationPing,
        'find_me'       => MessageType.findMe,
        'meetup_point'  => MessageType.meetupPoint,
        _               => MessageType.text,
      },
      lat:       (m['lat'] as num?)?.toDouble(),
      lng:       (m['lng'] as num?)?.toDouble(),
      createdAt: DateTime.parse(m['created_at'] as String),
      reactions: reactions,
    );
  }

  TripMessage copyWithReactions(Map<String, List<String>> reactions) =>
      TripMessage(
        id: id, tripId: tripId, authorId: authorId, body: body,
        type: type, createdAt: createdAt, lat: lat, lng: lng,
        reactions: reactions,
      );
}
