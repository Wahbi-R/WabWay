import 'package:flutter/material.dart';
import '../widgets/wabway_badge.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum SpotStatus {
  idea,
  wantToGo,
  mustDo,
  confirmed,
  planned,
  booked,
  skipped;

  String get label => switch (this) {
    SpotStatus.idea      => 'Idea',
    SpotStatus.wantToGo  => 'Want to go',
    SpotStatus.mustDo    => 'Must-do',
    SpotStatus.confirmed => 'Confirmed',
    SpotStatus.planned   => 'Planned',
    SpotStatus.booked    => 'Booked',
    SpotStatus.skipped   => 'Skipped',
  };

  WabwayBadgeTone get tone => switch (this) {
    SpotStatus.idea      => WabwayBadgeTone.neutral,
    SpotStatus.wantToGo  => WabwayBadgeTone.primary,
    SpotStatus.mustDo    => WabwayBadgeTone.accent,
    SpotStatus.confirmed => WabwayBadgeTone.success,
    SpotStatus.planned   => WabwayBadgeTone.secondary,
    SpotStatus.booked    => WabwayBadgeTone.success,
    SpotStatus.skipped   => WabwayBadgeTone.danger,
  };
}

enum SpotCategory {
  food,
  landmark,
  nature,
  experience,
  shopping,
  nightlife;

  String get label => switch (this) {
    SpotCategory.food       => 'Food',
    SpotCategory.landmark   => 'Landmark',
    SpotCategory.nature     => 'Nature',
    SpotCategory.experience => 'Experience',
    SpotCategory.shopping   => 'Shopping',
    SpotCategory.nightlife  => 'Nightlife',
  };

  IconData get icon => switch (this) {
    SpotCategory.food       => Icons.restaurant_rounded,
    SpotCategory.landmark   => Icons.account_balance_rounded,
    SpotCategory.nature     => Icons.park_rounded,
    SpotCategory.experience => Icons.local_activity_rounded,
    SpotCategory.shopping   => Icons.shopping_bag_rounded,
    SpotCategory.nightlife  => Icons.local_bar_rounded,
  };
}

enum VoteType {
  mustDo,
  want,
  maybe,
  skip;

  String get label => switch (this) {
    VoteType.mustDo => 'Must-do',
    VoteType.want   => 'Want',
    VoteType.maybe  => 'Maybe',
    VoteType.skip   => 'Skip',
  };

  Color get color => switch (this) {
    VoteType.mustDo => const Color(0xFFC96F4A),
    VoteType.want   => const Color(0xFF7D9A75),
    VoteType.maybe  => const Color(0xFFD6A84F),
    VoteType.skip   => const Color(0xFF6F665D),
  };

  Color get softColor => switch (this) {
    VoteType.mustDo => const Color(0xFFF7EDE7),
    VoteType.want   => const Color(0xFFEEF4EC),
    VoteType.maybe  => const Color(0xFFF8F0E2),
    VoteType.skip   => const Color(0xFFEEEAE3),
  };
}

// ─── Data classes ─────────────────────────────────────────────────────────────

class SpotVotes {
  const SpotVotes({
    this.mustDo = const [],
    this.want   = const [],
    this.maybe  = const [],
    this.skip   = const [],
  });

  final List<String> mustDo;
  final List<String> want;
  final List<String> maybe;
  final List<String> skip;

  int count(VoteType type) => switch (type) {
    VoteType.mustDo => mustDo.length,
    VoteType.want   => want.length,
    VoteType.maybe  => maybe.length,
    VoteType.skip   => skip.length,
  };

  List<String> voters(VoteType type) => switch (type) {
    VoteType.mustDo => mustDo,
    VoteType.want   => want,
    VoteType.maybe  => maybe,
    VoteType.skip   => skip,
  };

  int get total => mustDo.length + want.length + maybe.length + skip.length;

  List<VoteType> get activeTypes =>
      VoteType.values.where((t) => count(t) > 0).toList();

  SpotVotes copyWithVote(String userId, VoteType? type) {
    final mu = List<String>.from(mustDo)..remove(userId);
    final wa = List<String>.from(want)..remove(userId);
    final ma = List<String>.from(maybe)..remove(userId);
    final sk = List<String>.from(skip)..remove(userId);
    switch (type) {
      case VoteType.mustDo: mu.add(userId);
      case VoteType.want:   wa.add(userId);
      case VoteType.maybe:  ma.add(userId);
      case VoteType.skip:   sk.add(userId);
      case null: break;
    }
    return SpotVotes(mustDo: mu, want: wa, maybe: ma, skip: sk);
  }
}

class SpotComment {
  SpotComment({
    required this.id,
    required this.authorId,
    this.vote,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final VoteType? vote;
  final String text;
  final DateTime createdAt;
}

class Spot {
  const Spot({
    required this.id,
    required this.name,
    required this.city,
    required this.area,
    required this.category,
    required this.status,
    this.sourceUrl,
    this.mapsUrl,
    this.notes,
    this.address,
    this.latitude,
    this.longitude,
    this.placeSource,
    this.votes = const SpotVotes(),
    this.comments = const [],
    required this.addedById,
  });

  final String id;
  final String name;
  final String city;
  final String area;
  final SpotCategory category;
  final SpotStatus status;
  final String? sourceUrl;
  final String? mapsUrl;
  final String? notes;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String? placeSource;
  final SpotVotes votes;
  final List<SpotComment> comments;
  final String addedById;

  bool get isMapReady => latitude != null && longitude != null;

  Spot copyWith({
    SpotStatus? status,
    SpotVotes? votes,
    List<SpotComment>? comments,
    String? notes,
    String? mapsUrl,
    double? latitude,
    double? longitude,
    String? address,
    String? placeSource,
  }) => Spot(
        id:          id,
        name:        name,
        city:        city,
        area:        area,
        category:    category,
        status:      status ?? this.status,
        sourceUrl:   sourceUrl,
        mapsUrl:     mapsUrl ?? this.mapsUrl,
        notes:       notes ?? this.notes,
        address:     address ?? this.address,
        latitude:    latitude ?? this.latitude,
        longitude:   longitude ?? this.longitude,
        placeSource: placeSource ?? this.placeSource,
        votes:       votes ?? this.votes,
        comments:    comments ?? this.comments,
        addedById:   addedById,
      );
}

// ─── Mock data ────────────────────────────────────────────────────────────────

final kMockSpots = <Spot>[
  Spot(
    id: '1',
    name: 'Senso-ji Temple',
    city: 'Tokyo',
    area: 'Asakusa',
    category: SpotCategory.landmark,
    status: SpotStatus.mustDo,
    mapsUrl: 'https://maps.google.com/?q=Senso-ji+Temple',
    sourceUrl: 'https://www.timeout.com/tokyo/attractions/senso-ji',
    notes:
        'Most famous temple in Tokyo. Go before 8am to beat the crowds — the Nakamise shopping street leading up to it is also great for snacks and souvenirs.',
    votes: const SpotVotes(mustDo: ['alex', 'jordan'], want: ['sam']),
    comments: [
      SpotComment(
        id: 'c1_1',
        authorId: 'alex',
        vote: VoteType.mustDo,
        text: 'Non-negotiable. The atmosphere at dawn is something else.',
        createdAt: DateTime(2024, 11, 9, 10, 14),
      ),
      SpotComment(
        id: 'c1_2',
        authorId: 'jordan',
        vote: VoteType.mustDo,
        text: "Agreed. The incense smoke from the giant cauldron in front is a whole experience.",
        createdAt: DateTime(2024, 11, 10, 18, 42),
      ),
    ],
    addedById: 'alex',
  ),
  Spot(
    id: '2',
    name: 'Tsukiji Outer Market',
    city: 'Tokyo',
    area: 'Tsukiji',
    category: SpotCategory.food,
    status: SpotStatus.planned,
    mapsUrl: 'https://maps.google.com/?q=Tsukiji+Outer+Market',
    notes:
        'The inner wholesale market moved to Toyosu, but the outer market is still open with incredible street food — fresh sushi, tamagoyaki, grilled seafood skewers.',
    votes: const SpotVotes(mustDo: ['sam'], want: ['alex', 'jordan']),
    comments: [
      SpotComment(
        id: 'c2_1',
        authorId: 'sam',
        vote: VoteType.mustDo,
        text: 'Best sushi breakfast of my life last time. We have to go.',
        createdAt: DateTime(2024, 11, 8, 9, 5),
      ),
    ],
    addedById: 'sam',
  ),
  Spot(
    id: '3',
    name: 'Arashiyama Bamboo Grove',
    city: 'Kyoto',
    area: 'Arashiyama',
    category: SpotCategory.nature,
    status: SpotStatus.mustDo,
    mapsUrl: 'https://maps.google.com/?q=Arashiyama+Bamboo+Grove',
    sourceUrl: 'https://www.japan-guide.com/e/e3951.html',
    notes: 'Iconic bamboo path. Also worth doing: Tenryu-ji garden nearby, and the monkey park up the hill for city views.',
    votes: const SpotVotes(mustDo: ['alex', 'sam', 'jordan']),
    comments: [
      SpotComment(
        id: 'c3_1',
        authorId: 'jordan',
        vote: VoteType.mustDo,
        text: 'I have seen this in literally every video about Japan. We are going.',
        createdAt: DateTime(2024, 11, 7, 20, 31),
      ),
      SpotComment(
        id: 'c3_2',
        authorId: 'alex',
        vote: VoteType.mustDo,
        text: 'Combine it with Tenryu-ji for a full half-day.',
        createdAt: DateTime(2024, 11, 8, 11, 17),
      ),
    ],
    addedById: 'jordan',
  ),
  Spot(
    id: '4',
    name: 'Dotonbori',
    city: 'Osaka',
    area: 'Namba',
    category: SpotCategory.food,
    status: SpotStatus.booked,
    mapsUrl: 'https://maps.google.com/?q=Dotonbori+Osaka',
    notes:
        'The main food and entertainment strip of Osaka. Try takoyaki from Aizuya, kushikatsu at Daruma, and walk the canal at night for the neon reflection.',
    votes: const SpotVotes(mustDo: ['alex'], want: ['jordan', 'sam']),
    comments: [
      SpotComment(
        id: 'c4_1',
        authorId: 'sam',
        vote: VoteType.want,
        text: 'The giant running crab sign is so good.',
        createdAt: DateTime(2024, 11, 6, 16, 55),
      ),
    ],
    addedById: 'alex',
  ),
  Spot(
    id: '5',
    name: 'Fushimi Inari Taisha',
    city: 'Kyoto',
    area: 'Fushimi',
    category: SpotCategory.landmark,
    status: SpotStatus.planned,
    mapsUrl: 'https://maps.google.com/?q=Fushimi+Inari+Taisha',
    sourceUrl: 'https://www.insidekyoto.com/fushimi-inari-taisha',
    notes:
        'Thousands of torii gates winding up the mountain. The full hike takes about 2–3 hours. Just the lower section is already stunning and takes 30–45 min.',
    votes: const SpotVotes(mustDo: ['jordan'], want: ['alex'], maybe: ['sam']),
    comments: [
      SpotComment(
        id: 'c5_1',
        authorId: 'jordan',
        vote: VoteType.mustDo,
        text: 'I want to do the full hike to the top. Worth waking up early for.',
        createdAt: DateTime(2024, 11, 9, 14, 8),
      ),
      SpotComment(
        id: 'c5_2',
        authorId: 'sam',
        vote: VoteType.maybe,
        text: 'How far is the full hike? My knees might not cooperate.',
        createdAt: DateTime(2024, 11, 10, 21, 3),
      ),
    ],
    addedById: 'jordan',
  ),
  const Spot(
    id: '6',
    name: 'Shibuya Crossing',
    city: 'Tokyo',
    area: 'Shibuya',
    category: SpotCategory.experience,
    status: SpotStatus.wantToGo,
    mapsUrl: 'https://maps.google.com/?q=Shibuya+Crossing',
    notes:
        "World's busiest pedestrian crossing. Watch from above at Mag's Park or the Shibuya Sky observation deck for the full effect. Also walk through at rush hour.",
    votes: SpotVotes(want: ['alex', 'jordan'], maybe: ['sam']),
    addedById: 'alex',
  ),
  Spot(
    id: '7',
    name: 'Nishiki Market',
    city: 'Kyoto',
    area: 'Downtown',
    category: SpotCategory.food,
    status: SpotStatus.idea,
    mapsUrl: 'https://maps.google.com/?q=Nishiki+Market+Kyoto',
    sourceUrl: 'https://www.timeout.com/kyoto/restaurants/nishiki-market',
    notes: "Kyoto's Kitchen — a narrow 5-block covered market. Try dashimaki tamago, pickles, and fresh yuba (tofu skin). Very crowded on weekends.",
    votes: const SpotVotes(want: ['sam'], maybe: ['jordan']),
    comments: [
      SpotComment(
        id: 'c7_1',
        authorId: 'sam',
        vote: VoteType.want,
        text: 'Saw this on a food vlog. The egg-on-a-stick thing alone is worth it.',
        createdAt: DateTime(2024, 11, 10, 12, 47),
      ),
    ],
    addedById: 'sam',
  ),
  Spot(
    id: '8',
    name: 'teamLab Borderless',
    city: 'Tokyo',
    area: 'Azabudai Hills',
    category: SpotCategory.experience,
    status: SpotStatus.booked,
    mapsUrl: 'https://maps.google.com/?q=teamLab+Borderless+Tokyo',
    sourceUrl: 'https://www.teamlab.art/e/borderless-azabudaihills/',
    notes: 'Digital art museum — the reopened Azabudai Hills location. Tickets book up weeks ahead. We are booked for Nov 14 at 10am.',
    votes: const SpotVotes(mustDo: ['alex', 'jordan', 'sam']),
    comments: [
      SpotComment(
        id: 'c8_1',
        authorId: 'alex',
        vote: VoteType.mustDo,
        text: 'Already booked. Nov 14, 10am. Do not be late.',
        createdAt: DateTime(2024, 11, 5, 8, 22),
      ),
      SpotComment(
        id: 'c8_2',
        authorId: 'sam',
        vote: VoteType.mustDo,
        text: 'Excited! Wear something you do not mind getting slightly wet.',
        createdAt: DateTime(2024, 11, 6, 19, 11),
      ),
    ],
    addedById: 'alex',
  ),
  const Spot(
    id: '9',
    name: 'Gion District',
    city: 'Kyoto',
    area: 'Gion',
    category: SpotCategory.experience,
    status: SpotStatus.wantToGo,
    mapsUrl: 'https://maps.google.com/?q=Gion+Kyoto',
    notes:
        "Historic geisha district. Walk Hanamikoji Street in the early evening — you might spot a geiko or maiko heading to an appointment. Respect the no-photo zones.",
    votes: SpotVotes(mustDo: ['jordan'], want: ['alex'], maybe: ['sam']),
    addedById: 'jordan',
  ),
];

// ─── Helpers ──────────────────────────────────────────────────────────────────

String fmtCommentTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}wk ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}yr ago';
}
