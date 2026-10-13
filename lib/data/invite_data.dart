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

  /// Strips spaces/dashes and uppercases, so a code typed or pasted exactly as
  /// displayed ("1D70 D387") redeems the same as the raw code.
  static String normalize(String input) =>
      input.replaceAll(RegExp(r'[\s\-]'), '').toUpperCase();

  String get displayCode => code.length == 8
      ? '${code.substring(0, 4)} ${code.substring(4)}'
      : code;
}
