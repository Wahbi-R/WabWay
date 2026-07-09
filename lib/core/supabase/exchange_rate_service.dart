import 'dart:convert';
import 'package:http/http.dart' as http;

abstract final class ExchangeRateService {
  /// Fetches the exchange rate for [from] → [to] on [date] from Frankfurter
  /// (ECB-backed, free, no API key). Returns null on any error or timeout.
  ///
  /// When [from] == [to] returns 1.0 immediately.
  /// Weekends and public holidays return the nearest prior ECB rate.
  static Future<double?> fetch(
    String from,
    String to,
    DateTime date,
  ) async {
    if (from == to) return 1.0;
    final d = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    try {
      final uri = Uri.parse('https://api.frankfurter.app/$d?from=$from&to=$to');
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
