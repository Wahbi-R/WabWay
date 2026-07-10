class PackingItem {
  const PackingItem({
    required this.id,
    required this.tripId,
    required this.title,
    required this.isPacked,
    required this.createdBy,
    this.assignedTo,
    this.packedBy,
    this.sortOrder = 0,
  });

  final String id;
  final String tripId;
  final String title;
  final bool isPacked;
  final String createdBy;
  final String? assignedTo;  // userId
  final String? packedBy;    // userId
  final int sortOrder;

  PackingItem copyWith({bool? isPacked, String? packedBy}) => PackingItem(
        id: id,
        tripId: tripId,
        title: title,
        isPacked: isPacked ?? this.isPacked,
        createdBy: createdBy,
        assignedTo: assignedTo,
        packedBy: packedBy ?? this.packedBy,
        sortOrder: sortOrder,
      );
}
