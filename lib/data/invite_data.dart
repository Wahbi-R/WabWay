class InviteCode {
  const InviteCode({
    required this.id,
    required this.tripId,
    required this.code,
    required this.createdAt,
    this.expiresAt,
    this.usedAt,
  });

  final String id;
  final String tripId;
  final String code;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? usedAt;

  bool get isUsed => usedAt != null;

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isActive => !isUsed && !isExpired;

  String get displayCode => code.length == 8
      ? '${code.substring(0, 4)} ${code.substring(4)}'
      : code;
}
