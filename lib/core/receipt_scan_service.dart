import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/receipt_items.dart';
import 'supabase/client.dart';

/// One photo to scan.
class ScanImage {
  const ScanImage(this.bytes, this.ext);
  final Uint8List bytes;
  /// File extension, e.g. 'jpg', 'png'.
  final String ext;

  String get mediaType => switch (ext.toLowerCase()) {
        'png'          => 'image/png',
        'webp'         => 'image/webp',
        'gif'          => 'image/gif',
        'heic' || 'heif' => 'image/heic',
        _              => 'image/jpeg',
      };

  bool get isScannable => mediaType != 'image/heic';
}

/// The scan result, or why there isn't one — so the form can say what
/// actually went wrong instead of a generic "scan unavailable".
class ReceiptScanOutcome {
  const ReceiptScanOutcome._(this.itemization, this.error);
  const ReceiptScanOutcome.ok(ReceiptItemization items) : this._(items, null);
  const ReceiptScanOutcome.failed(String message) : this._(null, message);

  final ReceiptItemization? itemization;
  final String? error;
  bool get ok => itemization != null;
}

class ReceiptScanService {
  static const _scanUrl = 'https://audio.wabble.ca/receipt/scan';
  static const _translateUrl = 'https://audio.wabble.ca/receipt/translate';
  static const _kPrefEnglishNames = 'receipt_items_english';

  /// Show item names in English (translations) rather than as printed.
  /// Per device; on by default.
  static final showEnglish = ValueNotifier<bool>(true);
  static bool _prefLoaded = false;

  static Future<void> loadEnglishPref() async {
    if (_prefLoaded) return;
    _prefLoaded = true;
    try {
      final v = (await SharedPreferences.getInstance()).getBool(_kPrefEnglishNames);
      if (v != null) showEnglish.value = v;
    } catch (_) {}
  }

  static Future<void> setShowEnglish(bool v) async {
    showEnglish.value = v;
    try {
      await (await SharedPreferences.getInstance()).setBool(_kPrefEnglishNames, v);
    } catch (_) {}
  }

  /// [items] with English names for those not in English, or an error
  /// message. Never throws.
  static Future<(ReceiptItemization?, String?)> translate(ReceiptItemization items) async {
    final token = supabase.auth.currentSession?.accessToken;
    if (token == null) return (null, 'Sign in to translate.');
    try {
      final response = await http
          .post(
            Uri.parse(_translateUrl),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode({'names': [for (final i in items.items) i.name]}),
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode != 200) {
        String detail = '';
        try {
          detail = ((jsonDecode(response.body) as Map)['detail'] as String?) ?? '';
        } catch (_) {}
        return (null, detail.isNotEmpty ? "Couldn't translate: $detail" : "Couldn't translate — try again.");
      }
      final names = [
        for (final n in ((jsonDecode(response.body) as Map)['names_en'] as List?) ?? const [])
          '${n ?? ''}',
      ];
      return (items.withTranslations(names), null);
    } on TimeoutException {
      return (null, 'Translating took too long — try again.');
    } catch (_) {
      return (null, "Can't reach the translator (offline?).");
    }
  }

  /// Just under Cloudflare's ~100 s tunnel limit: the server may spend up to
  /// ~85 s on a long receipt (plus a self-check retry inside 40 s). A shorter
  /// client timeout gave up on scans the server went on to finish.
  static const timeout = Duration(seconds: 95);

  /// Sends [images] (overlapping photos of ONE receipt, top to bottom) to the
  /// scan endpoint. Never throws.
  static Future<ReceiptScanOutcome> scan(List<ScanImage> images) async {
    if (images.isEmpty) return const ReceiptScanOutcome.failed('Add a photo of the receipt first.');
    if (images.any((i) => !i.isScannable)) {
      return const ReceiptScanOutcome.failed(
          "HEIC photos can't be scanned — retake the photo in the app or pick a JPEG.");
    }
    try {
      final response = await http
          .post(
            Uri.parse(_scanUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'images': [
                for (final img in images)
                  {'data': base64Encode(img.bytes), 'media_type': img.mediaType},
              ],
            }),
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        return ReceiptScanOutcome.failed(_messageFor(response));
      }
      final items = ReceiptItemization.fromScan(
          jsonDecode(response.body) as Map<String, dynamic>);
      if (items.isEmpty) {
        return const ReceiptScanOutcome.failed(
            "Couldn't find any items on that photo — try a sharper, straighter shot or add items by hand.");
      }
      return ReceiptScanOutcome.ok(items);
    } on TimeoutException {
      return const ReceiptScanOutcome.failed(
          'The scan took too long — try fewer photos, or add items by hand.');
    } catch (_) {
      return const ReceiptScanOutcome.failed(
          "Can't reach the scanner (offline?) — you can add items by hand.");
    }
  }

  static String _messageFor(http.Response r) {
    String detail = '';
    try {
      detail = ((jsonDecode(r.body) as Map)['detail'] as String?) ?? '';
    } catch (_) {}
    if (r.statusCode == 415 || detail.contains('HEIC')) {
      return "That photo format can't be scanned — use a JPEG or PNG.";
    }
    if (detail.contains('too long')) {
      return 'Receipt too long for one scan — try fewer photos per scan.';
    }
    if (detail.contains('declined')) return "The scanner couldn't read that image.";
    if (r.statusCode == 503) return 'The scanner is switched off right now — add items by hand.';
    if (r.statusCode == 413) return 'Photos are too large — try fewer at once.';
    return 'Scan failed (${r.statusCode}) — you can add items by hand.';
  }
}
