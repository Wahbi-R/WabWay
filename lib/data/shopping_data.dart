// ─── Shopping item model ──────────────────────────────────────────────────────

class ShoppingItem {
  const ShoppingItem({
    required this.id,
    required this.tripId,
    required this.name,
    this.quantity,
    this.notes,
    this.spotId,
    this.spotName,
    this.spotCategory,
    this.checked = false,
    this.checkedBy,
    this.checkedAt,
    required this.createdBy,
    required this.createdAt,
    this.sortOrder = 0,
  });

  final String     id;
  final String     tripId;
  final String     name;
  final String?    quantity;
  final String?    notes;
  final String?    spotId;
  final String?    spotName;
  final String?    spotCategory;
  final bool       checked;
  final String?    checkedBy;
  final DateTime?  checkedAt;
  final String     createdBy;
  final DateTime   createdAt;
  final int        sortOrder;

  ShoppingItem copyWith({
    String?   name,
    String?   quantity,
    String?   notes,
    Object?   spotId      = _sentinel,
    Object?   spotName    = _sentinel,
    Object?   spotCategory = _sentinel,
    bool?     checked,
    Object?   checkedBy   = _sentinel,
    Object?   checkedAt   = _sentinel,
    int?      sortOrder,
  }) => ShoppingItem(
    id:           id,
    tripId:       tripId,
    name:         name         ?? this.name,
    quantity:     quantity     ?? this.quantity,
    notes:        notes        ?? this.notes,
    spotId:       identical(spotId,       _sentinel) ? this.spotId       : spotId       as String?,
    spotName:     identical(spotName,     _sentinel) ? this.spotName     : spotName     as String?,
    spotCategory: identical(spotCategory, _sentinel) ? this.spotCategory : spotCategory as String?,
    checked:      checked      ?? this.checked,
    checkedBy:    identical(checkedBy,    _sentinel) ? this.checkedBy    : checkedBy    as String?,
    checkedAt:    identical(checkedAt,    _sentinel) ? this.checkedAt    : checkedAt    as DateTime?,
    createdBy:    createdBy,
    createdAt:    createdAt,
    sortOrder:    sortOrder    ?? this.sortOrder,
  );
}

const _sentinel = Object();
