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
  });

  final String id;
  final String tripId;
  final String authorId;
  final String body;
  final MessageType type;
  final double? lat;
  final double? lng;
  final DateTime createdAt;

  factory TripMessage.fromMap(Map<String, dynamic> m) => TripMessage(
        id: m['id'] as String,
        tripId: m['trip_id'] as String,
        authorId: m['author_id'] as String,
        body: m['body'] as String,
        type: switch (m['message_type'] as String?) {
          'location_ping' => MessageType.locationPing,
          'find_me'       => MessageType.findMe,
          'meetup_point'  => MessageType.meetupPoint,
          _               => MessageType.text,
        },
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
