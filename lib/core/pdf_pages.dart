import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'receipt_scan_service.dart';

/// Pages of a PDF as images, for places that only show pictures — the
/// receipts.wabble.ca link shows a receipt's photos, so a PDF ticket or
/// confirmation goes there as one image per page.
///
/// [pages] are 1-based (as the booking reader reports them); null means from
/// the first page. At most [maxPages]. Never throws: returns what it managed.
Future<List<ScanImage>> pdfPageImages(
  Uint8List pdf, {
  List<int>? pages,
  int maxPages = 5,
  double dpi = 110,
}) async {
  final wanted = (pages == null || pages.isEmpty)
      ? [for (var i = 0; i < maxPages; i++) i]
      : [for (final p in pages.take(maxPages)) p - 1];
  final out = <ScanImage>[];
  try {
    await for (final page in Printing.raster(pdf, pages: wanted, dpi: dpi)) {
      out.add(ScanImage(await page.toPng(), 'png'));
      if (out.length >= maxPages) break;
    }
  } catch (_) {
    // Unreadable PDF or a page past the end: keep the pages we have.
  }
  return out;
}
