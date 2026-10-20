import 'dart:convert';
import 'package:http/http.dart' as http;

abstract final class ExchangeRateService {
  static final Map<String, Future<double?>> _today = {};

  /// Today's [from] → [to] rate, fetched once per app session (for ≈
  /// amounts on lists). A failed fetch is retried next time.
  static Future<double?> latestCached(String from, String to) {
    final key = '$from>$to';
    return _today[key] ??= fetch(from, to).then((r) {
      if (r == null) _today.remove(key);
      return r;
    });
  }

  /// Fetches the exchange rate for [from] → [to] on [date] from Frankfurter
  /// (ECB-backed, free, no API key). Returns null on any error or timeout.
  ///
  /// When [from] == [to] returns 1.0 immediately.
  /// Weekends and public holidays return the nearest prior ECB rate.
  /// Fetches the rate for [from] → [to].
  /// Pass [date] for historical lookups (editing old receipts); omit or pass
  /// today to get the latest published ECB rate via the /latest endpoint.
  static Future<double?> fetch(
    String from,
    String to, {
    DateTime? date,
  }) async {
    if (from == to) return 1.0;
    final now   = DateTime.now();
    final isToday = date == null ||
        (date.year == now.year && date.month == now.month && date.day == now.day);
    final segment = isToday
        ? 'latest'
        : '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}';
    try {
      // api.frankfurter.app now 301-redirects here; the redirect has no CORS
      // headers, so on web the old URL failed every time (rate stayed empty).
      final uri = Uri.parse('https://api.frankfurter.dev/v1/$segment?from=$from&to=$to');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final rates = j['rates'] as Map<String, dynamic>?;
      final rate = rates?[to];
      if (rate == null) return null;
      return (rate as num).toDouble();
    } catch (_) {
      return null;
    }
  }
}
