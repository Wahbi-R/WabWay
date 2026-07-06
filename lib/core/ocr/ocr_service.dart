import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'pdf_reader.dart';

abstract final class OcrService {
  static Future<String?> extractText(String imagePath) async {
    if (kIsWeb) return null;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFile(File(imagePath));
      final result = await recognizer.processImage(input);
      return result.text;
    } catch (_) {
      return null;
    } finally {
      await recognizer.close();
    }
  }

  static Future<String?> extractTextFromBytes(Uint8List bytes, String ext) async {
    if (kIsWeb) return null;
    // PDFs: use Syncfusion text extraction (ML Kit is image-only)
    if (ext == 'pdf') return PdfReader.extractText(bytes);

    final tmp = File(
      '${Directory.systemTemp.path}/ocr_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    await tmp.writeAsBytes(bytes);
    try {
      return await extractText(tmp.path);
    } finally {
      await tmp.delete().catchError((_) => tmp);
    }
  }
}
