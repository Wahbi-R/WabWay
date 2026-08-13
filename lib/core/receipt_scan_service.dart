import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ScannedItem {
  const ScannedItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
  });
  final String name;
  final int quantity;
  final double unitPrice;
  final double totalPrice;

  factory ScannedItem.fromJson(Map<String, dynamic> j) => ScannedItem(
        name:       (j['name'] as String?) ?? 'Item',
        quantity:   (j['quantity'] as num?)?.toInt() ?? 1,
        unitPrice:  (j['unit_price'] as num?)?.toDouble() ?? 0,
        totalPrice: (j['total_price'] as num?)?.toDouble() ?? 0,
      );
}

class ReceiptScanResult {
  const ReceiptScanResult({
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.tip,
    required this.total,
  });
  final List<ScannedItem> items;
  final double subtotal;
  final double discount;
  final double tax;
  final double tip;
  /// The scan total (subtotal - discount + tax + tip).
  final double total;

  double get itemsTotal => items.fold(0.0, (a, i) => a + i.totalPrice);

  factory ReceiptScanResult.fromJson(Map<String, dynamic> j) =>
      ReceiptScanResult(
        items:    (j['items'] as List<dynamic>? ?? [])
            .map((e) => ScannedItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        subtotal: (j['subtotal'] as num?)?.toDouble() ?? 0,
        discount: (j['discount'] as num?)?.toDouble() ?? 0,
        tax:      (j['tax'] as num?)?.toDouble() ?? 0,
        tip:      (j['tip'] as num?)?.toDouble() ?? 0,
        total:    (j['total'] as num?)?.toDouble() ?? 0,
      );
}

class ReceiptScanService {
  static const _scanUrl = 'https://audio.wabble.ca/receipt/scan';

  /// Sends [imageBytes] to the scan endpoint and returns the parsed result.
  /// Returns null on any failure (server unreachable, timeout, bad response).
  static Future<ReceiptScanResult?> scan(
      Uint8List imageBytes, String mediaType) async {
    try {
      final b64 = base64Encode(imageBytes);
      final response = await http
          .post(
            Uri.parse(_scanUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'image': b64, 'media_type': mediaType}),
          )
          .timeout(const Duration(seconds: 35));
      if (response.statusCode != 200) return null;
      return ReceiptScanResult.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
