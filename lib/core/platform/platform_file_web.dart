import 'dart:typed_data';

Future<Uint8List> readFileAsBytes(String path) async => Uint8List(0);

/// No persistent file storage on web — queued photos are dropped.
Future<String?> writeAppFile(String name, Uint8List bytes) async => null;

Future<void> deleteAppFile(String path) async {}
