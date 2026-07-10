class AppTrip {
  const AppTrip({
    required this.id,
    required this.name,
    required this.defaultCurrency,
    required this.homeCurrency,
    this.destination,
    this.startDate,
    this.endDate,
    this.coverImageUrl,
    this.budget,
    this.groupChatUrl,
  });

  final String id;
  final String name;
  final String defaultCurrency;
  /// The currency all balances and settlements are expressed in.
  final String homeCurrency;
  final String? destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? coverImageUrl;
  /// Optional trip-wide spending budget in home currency; null = no budget set.
  final double? budget;
  /// Optional link to the group's WhatsApp / Telegram / Signal chat.
  final String? groupChatUrl;

  factory AppTrip.fromMap(Map<String, dynamic> map) => AppTrip(
        id:              map['id'] as String,
        name:            map['name'] as String,
        defaultCurrency: map['default_currency'] as String? ?? 'JPY',
        homeCurrency:    map['home_currency'] as String? ?? 'CAD',
        destination:     map['destination'] as String?,
        startDate:       map['start_date'] != null
            ? DateTime.parse(map['start_date'] as String)
            : null,
        endDate:         map['end_date'] != null
            ? DateTime.parse(map['end_date'] as String)
            : null,
        coverImageUrl:   map['cover_image_url'] as String?,
        budget:          (map['budget'] as num?)?.toDouble(),
        groupChatUrl:    map['group_chat_url'] as String?,
      );

  String get subtitle => destination ?? '';
}
