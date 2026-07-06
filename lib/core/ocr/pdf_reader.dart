import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;

/// Extracts text from PDF bytes using Syncfusion's on-device PDF engine.
/// Works entirely offline, no AI required.
abstract final class PdfReader {
  static Future<String?> extractText(Uint8List bytes) async {
    sf.PdfDocument? doc;
    try {
      doc = sf.PdfDocument(inputBytes: bytes);
      final extractor = sf.PdfTextExtractor(doc);
      final sb = StringBuffer();
      for (var i = 0; i < doc.pages.count; i++) {
        final page = extractor.extractText(startPageIndex: i, endPageIndex: i);
        if (page.isNotEmpty) sb.writeln(page);
      }
      final text = sb.toString().trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    } finally {
      doc?.dispose();
    }
  }
}
