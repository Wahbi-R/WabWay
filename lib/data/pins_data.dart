// Trip pin — a short group note posted on the shared pinboard.
// Members see all active pins on the home screen.

class TripPin {
  TripPin({
    required this.id,
    required this.tripId,
    required this.authorId,
    required this.body,
    required this.isPinned,
    required this.createdAt,
  });

  final String id;
  final String tripId;
  final String authorId;
  final String body;
  final bool isPinned;
  final DateTime createdAt;

  factory TripPin.fromMap(Map<String, dynamic> m) => TripPin(
        id:        m['id'] as String,
        tripId:    m['trip_id'] as String,
        authorId:  m['author_id'] as String,
        body:      m['body'] as String,
        isPinned:  (m['is_pinned'] as bool?) ?? true,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}
