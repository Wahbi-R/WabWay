import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

abstract final class OcrService {
  static Future<String?> extractText(String imagePath) async {
    if (kIsWeb) return null;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFile(File(imagePath));
      final result = await recognizer.processImage(input);
      return result.text;
    } catch (e) {
      return null;
    } finally {
      await recognizer.close();
    }
  }
}
