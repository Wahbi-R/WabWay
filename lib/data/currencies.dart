const kCurrencies = [
  ('USD', '\$ US Dollar'),
  ('EUR', '€ Euro'),
  ('GBP', '£ British Pound'),
  ('JPY', '¥ Japanese Yen'),
  ('AUD', 'A\$ Australian Dollar'),
  ('CAD', 'C\$ Canadian Dollar'),
  ('SGD', 'S\$ Singapore Dollar'),
  ('HKD', 'HK\$ Hong Kong Dollar'),
  ('KRW', '₩ Korean Won'),
  ('THB', '฿ Thai Baht'),
  ('TWD', 'NT\$ Taiwan Dollar'),
  ('MYR', 'RM Malaysian Ringgit'),
  ('IDR', 'Rp Indonesian Rupiah'),
  ('VND', '₫ Vietnamese Dong'),
  ('PHP', '₱ Philippine Peso'),
];

/// Local currency for a destination string like "Japan", "Kyoto, Japan",
/// "Tokyo" or "Paris, France". Null when unknown — callers fall back to the
/// trip's home currency (never a hard-coded JPY).
String? currencyForDestination(String? destination) {
  if (destination == null || destination.trim().isEmpty) return null;
  final parts = destination.toLowerCase().split(',').map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  // Try the most specific piece last-first: "Kyoto, Japan" → "japan" then "kyoto".
  for (final p in parts.reversed) {
    final hit = _kPlaceCurrency[p];
    if (hit != null) return hit;
  }
  return null;
}

const _kEuro = 'EUR';
const Map<String, String> _kPlaceCurrency = {
  // Countries / regions
  'japan': 'JPY', 'south korea': 'KRW', 'korea': 'KRW', 'china': 'CNY',
  'hong kong': 'HKD', 'taiwan': 'TWD', 'singapore': 'SGD', 'thailand': 'THB',
  'vietnam': 'VND', 'malaysia': 'MYR', 'indonesia': 'IDR', 'philippines': 'PHP',
  'cambodia': 'USD', 'laos': 'LAK', 'myanmar': 'MMK', 'india': 'INR', 'nepal': 'NPR',
  'sri lanka': 'LKR', 'australia': 'AUD', 'new zealand': 'NZD',
  'canada': 'CAD', 'united states': 'USD', 'usa': 'USD', 'us': 'USD', 'mexico': 'MXN',
  'brazil': 'BRL', 'argentina': 'ARS', 'chile': 'CLP', 'colombia': 'COP', 'peru': 'PEN',
  'united kingdom': 'GBP', 'uk': 'GBP', 'england': 'GBP', 'scotland': 'GBP',
  'ireland': _kEuro, 'france': _kEuro, 'germany': _kEuro, 'italy': _kEuro, 'spain': _kEuro,
  'portugal': _kEuro, 'netherlands': _kEuro, 'belgium': _kEuro, 'austria': _kEuro,
  'greece': _kEuro, 'finland': _kEuro, 'croatia': _kEuro,
  'switzerland': 'CHF', 'denmark': 'DKK', 'sweden': 'SEK', 'norway': 'NOK',
  'iceland': 'ISK', 'poland': 'PLN', 'czech republic': 'CZK', 'czechia': 'CZK',
  'hungary': 'HUF', 'romania': 'RON', 'turkey': 'TRY', 'israel': 'ILS',
  'jordan': 'JOD', 'egypt': 'EGP', 'morocco': 'MAD', 'kenya': 'KES',
  'south africa': 'ZAR', 'united arab emirates': 'AED', 'uae': 'AED',
  // Cities commonly typed without a country
  'tokyo': 'JPY', 'osaka': 'JPY', 'kyoto': 'JPY', 'sapporo': 'JPY', 'seoul': 'KRW',
  'bangkok': 'THB', 'bali': 'IDR', 'taipei': 'TWD', 'dubai': 'AED',
  'london': 'GBP', 'paris': _kEuro, 'rome': _kEuro, 'barcelona': _kEuro,
  'new york': 'USD', 'los angeles': 'USD', 'toronto': 'CAD', 'vancouver': 'CAD',
  'sydney': 'AUD', 'melbourne': 'AUD',
};

/// The one currency picker list: [kCurrencies] plus [include] (e.g. the
/// trip's or the record's current currency) when it isn't already listed, so
/// a dropdown never has a value missing from its items.
List<(String code, String label)> currencyOptions({String? include}) {
  final out = [
    for (final c in kCurrencies) (c.$1, '${c.$1} ${c.$2.split(' ').first}'),
  ];
  final extra = include?.trim().toUpperCase();
  if (extra != null && extra.isNotEmpty && !out.any((c) => c.$1 == extra)) {
    out.add((extra, extra));
  }
  return out;
}
