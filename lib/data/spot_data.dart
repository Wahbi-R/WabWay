import 'package:flutter/material.dart';
import '../widgets/wabway_badge.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum SpotStatus {
  idea,
  wantToGo,
  mustDo,
  planned,
  booked,
  skipped;

  String get label => switch (this) {
    SpotStatus.idea     => 'Idea',
    SpotStatus.wantToGo => 'Want to go',
    SpotStatus.mustDo   => 'Must-do',
    SpotStatus.planned  => 'Planned',
    SpotStatus.booked   => 'Booked',
    SpotStatus.skipped  => 'Skipped',
  };

  WabwayBadgeTone get tone => switch (this) {
    SpotStatus.idea     => WabwayBadgeTone.neutral,
    SpotStatus.wantToGo => WabwayBadgeTone.primary,
    SpotStatus.mustDo   => WabwayBadgeTone.accent,
    SpotStatus.planned  => WabwayBadgeTone.secondary,
    SpotStatus.booked   => WabwayBadgeTone.success,
    SpotStatus.skipped  => WabwayBadgeTone.danger,
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
}

class SpotComment {
  const SpotComment({
    required this.author,
    this.vote,
    required this.text,
    required this.time,
  });

  final String author;
  final VoteType? vote;
  final String text;
  final String time;
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
    this.votes = const SpotVotes(),
    this.comments = const [],
    required this.addedBy,
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
  final SpotVotes votes;
  final List<SpotComment> comments;
  final String addedBy;
}

// ─── Mock data ────────────────────────────────────────────────────────────────

const kMockSpots = <Spot>[
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
    votes: SpotVotes(mustDo: ['Alex', 'Jordan'], want: ['Sam']),
    comments: [
      SpotComment(
        author: 'Alex',
        vote: VoteType.mustDo,
        text: 'Non-negotiable. The atmosphere at dawn is something else.',
        time: '2d ago',
      ),
      SpotComment(
        author: 'Jordan',
        vote: VoteType.mustDo,
        text: "Agreed. The incense smoke from the giant cauldron in front is a whole experience.",
        time: '1d ago',
      ),
    ],
    addedBy: 'Alex',
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
    votes: SpotVotes(mustDo: ['Sam'], want: ['Alex', 'Jordan']),
    comments: [
      SpotComment(
        author: 'Sam',
        vote: VoteType.mustDo,
        text: 'Best sushi breakfast of my life last time. We have to go.',
        time: '3d ago',
      ),
    ],
    addedBy: 'Sam',
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
    votes: SpotVotes(mustDo: ['Alex', 'Sam', 'Jordan']),
    comments: [
      SpotComment(
        author: 'Jordan',
        vote: VoteType.mustDo,
        text: 'I have seen this in literally every video about Japan. We are going.',
        time: '4d ago',
      ),
      SpotComment(
        author: 'Alex',
        vote: VoteType.mustDo,
        text: 'Combine it with Tenryu-ji for a full half-day.',
        time: '3d ago',
      ),
    ],
    addedBy: 'Jordan',
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
    votes: SpotVotes(mustDo: ['Alex'], want: ['Jordan', 'Sam']),
    comments: [
      SpotComment(
        author: 'Sam',
        vote: VoteType.want,
        text: 'The giant running crab sign is so good.',
        time: '5d ago',
      ),
    ],
    addedBy: 'Alex',
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
    votes: SpotVotes(mustDo: ['Jordan'], want: ['Alex'], maybe: ['Sam']),
    comments: [
      SpotComment(
        author: 'Jordan',
        vote: VoteType.mustDo,
        text: 'I want to do the full hike to the top. Worth waking up early for.',
        time: '2d ago',
      ),
      SpotComment(
        author: 'Sam',
        vote: VoteType.maybe,
        text: 'How far is the full hike? My knees might not cooperate.',
        time: '1d ago',
      ),
    ],
    addedBy: 'Jordan',
  ),
  Spot(
    id: '6',
    name: 'Shibuya Crossing',
    city: 'Tokyo',
    area: 'Shibuya',
    category: SpotCategory.experience,
    status: SpotStatus.wantToGo,
    mapsUrl: 'https://maps.google.com/?q=Shibuya+Crossing',
    notes:
        "World's busiest pedestrian crossing. Watch from above at Mag's Park or the Shibuya Sky observation deck for the full effect. Also walk through at rush hour.",
    votes: SpotVotes(want: ['Alex', 'Jordan'], maybe: ['Sam']),
    comments: [],
    addedBy: 'Alex',
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
    votes: SpotVotes(want: ['Sam'], maybe: ['Jordan']),
    comments: [
      SpotComment(
        author: 'Sam',
        vote: VoteType.want,
        text: 'Saw this on a food vlog. The egg-on-a-stick thing alone is worth it.',
        time: '1d ago',
      ),
    ],
    addedBy: 'Sam',
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
    votes: SpotVotes(mustDo: ['Alex', 'Jordan', 'Sam']),
    comments: [
      SpotComment(
        author: 'Alex',
        vote: VoteType.mustDo,
        text: 'Already booked. Nov 14, 10am. Do not be late.',
        time: '6d ago',
      ),
      SpotComment(
        author: 'Sam',
        vote: VoteType.mustDo,
        text: 'Excited! Wear something you do not mind getting slightly wet.',
        time: '5d ago',
      ),
    ],
    addedBy: 'Alex',
  ),
  Spot(
    id: '9',
    name: 'Gion District',
    city: 'Kyoto',
    area: 'Gion',
    category: SpotCategory.experience,
    status: SpotStatus.wantToGo,
    mapsUrl: 'https://maps.google.com/?q=Gion+Kyoto',
    notes:
        "Historic geisha district. Walk Hanamikoji Street in the early evening — you might spot a geiko or maiko heading to an appointment. Respect the no-photo zones.",
    votes: SpotVotes(mustDo: ['Jordan'], want: ['Alex'], maybe: ['Sam']),
    comments: [],
    addedBy: 'Jordan',
  ),
];
