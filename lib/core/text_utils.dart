// Shared text helpers. Before adding string logic to a screen, check here.

/// Initials for an avatar: first letter of the first and last word
/// ("Test User" → "TU", "Wahbi" → "W", "" → "?"). The ONE initials rule —
/// always pass the person's real display name, never "You".
String initialsFor(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters1.toUpperCase();
  return '${parts.first.characters1}${parts.last.characters1}'.toUpperCase();
}

extension on String {
  /// First user-perceived character, safe for surrogate pairs (emoji names).
  String get characters1 => String.fromCharCodes(runes.take(1));
}

/// "1 day", "3 days", "1 spot". Pass [plural] for irregular words.
String pluralize(int count, String singular, {String? plural}) =>
    '$count ${pluralWord(count, singular, plural: plural)}';

/// Just the word: pluralWord(1, 'Day') → "Day", pluralWord(3, 'Day') → "Days".
String pluralWord(int count, String singular, {String? plural}) =>
    count == 1 ? singular : (plural ?? '${singular}s');

/// Lowercases and strips diacritics so "senso" matches "Sensō-ji",
/// "cafe" matches "Café", "munchen" matches "München".
String foldForSearch(String input) {
  final lower = input.toLowerCase();
  final buf = StringBuffer();
  for (final rune in lower.runes) {
    final ch = String.fromCharCode(rune);
    buf.write(_kFold[ch] ?? ch);
  }
  return buf.toString();
}

/// True when [haystack] contains [query] after folding both.
/// [query] should already be folded when matching many fields in a loop.
bool searchMatches(String? haystack, String foldedQuery) =>
    haystack != null && foldForSearch(haystack).contains(foldedQuery);

const Map<String, String> _kFold = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', 'ă': 'a', 'ą': 'a',
  'æ': 'ae',
  'ç': 'c', 'ć': 'c', 'č': 'c', 'ĉ': 'c',
  'ď': 'd', 'đ': 'd', 'ð': 'd',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e', 'ě': 'e',
  'ğ': 'g', 'ĝ': 'g',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'į': 'i', 'ı': 'i',
  'ł': 'l', 'ľ': 'l',
  'ñ': 'n', 'ń': 'n', 'ň': 'n',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', 'ő': 'o',
  'œ': 'oe',
  'ŕ': 'r', 'ř': 'r',
  'ś': 's', 'š': 's', 'ş': 's', 'ș': 's', 'ß': 'ss',
  'ť': 't', 'ţ': 't', 'ț': 't',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u', 'ų': 'u',
  'ý': 'y', 'ÿ': 'y',
  'ź': 'z', 'ż': 'z', 'ž': 'z',
  // Common punctuation variants so "senso ji" / "senso-ji" / "sensō‐ji" agree.
  '‐': '-', '‑': '-', '–': '-', '—': '-',
  '’': "'", '‘': "'",
};
