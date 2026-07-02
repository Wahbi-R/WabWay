// ─── Member identity ──────────────────────────────────────────────────────────

class TripMember {
  const TripMember({required this.id, required this.name});
  final String id;
  final String name;
  bool get isYou => id == kYouId;
}

// Updated at runtime with real auth/member data in MoneyScreen.didChangeDependencies.
// Fallback values ensure the money UI doesn't crash before MoneyScreen initialises.
String kYouId = 'you';

List<TripMember> kMockMembers = const [
  TripMember(id: 'you', name: 'You'),
];

TripMember memberById(String id) =>
    kMockMembers.firstWhere((m) => m.id == id,
        orElse: () => TripMember(id: id, name: id));
