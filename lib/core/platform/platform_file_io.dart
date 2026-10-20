import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Future<Uint8List> readFileAsBytes(String path) => File(path).readAsBytes();

/// Saves [bytes] under the app's documents folder (survives restarts).
/// Returns the file path, or null if it couldn't be written.
Future<String?> writeAppFile(String name, Uint8List bytes) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$name');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}

Future<void> deleteAppFile(String path) async {
  try {
    await File(path).delete();
  } catch (_) {}
}
