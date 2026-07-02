class AppTrip {
  const AppTrip({
    required this.id,
    required this.name,
    required this.defaultCurrency,
    this.destination,
    this.startDate,
    this.endDate,
    this.coverImageUrl,
  });

  final String id;
  final String name;
  final String defaultCurrency;
  final String? destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? coverImageUrl;

  factory AppTrip.fromMap(Map<String, dynamic> map) => AppTrip(
        id: map['id'] as String,
        name: map['name'] as String,
        defaultCurrency: map['default_currency'] as String? ?? 'JPY',
        destination: map['destination'] as String?,
        startDate: map['start_date'] != null
            ? DateTime.parse(map['start_date'] as String)
            : null,
        endDate: map['end_date'] != null
            ? DateTime.parse(map['end_date'] as String)
            : null,
        coverImageUrl: map['cover_image_url'] as String?,
      );

  String get subtitle => destination ?? '';
}
