class PackingCheck {
  const PackingCheck({required this.userId, required this.checkedAt});
  final String userId;
  final DateTime checkedAt;
}

class PackingItem {
  const PackingItem({
    required this.id,
    required this.tripId,
    required this.title,
    this.checks = const [],
    required this.createdBy,
    this.sortOrder = 0,
  });

  final String id;
  final String tripId;
  final String title;
  final List<PackingCheck> checks;
  final String createdBy;
  final int sortOrder;

  bool isPackedBy(String userId) => checks.any((c) => c.userId == userId);

  PackingItem copyWith({String? title, List<PackingCheck>? checks}) => PackingItem(
        id: id,
        tripId: tripId,
        title: title ?? this.title,
        checks: checks ?? this.checks,
        createdBy: createdBy,
        sortOrder: sortOrder,
      );
}
