import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../../data/share_data.dart';

/// Singleton that bridges Android ACTION_SEND intents to an [IncomingShare].
///
/// Call [init] once in main() on Android. Widgets listen via [addListener] /
/// [removeListener] and consume the pending share via [consume].
class ShareHandler extends ChangeNotifier {
  ShareHandler._();
  static final instance = ShareHandler._();

  IncomingShare? _pending;
  IncomingShare? get pending => _pending;

  StreamSubscription<List<SharedMediaFile>>? _sub;
  int _counter = 0;

  Future<void> init() async {
    if (!Platform.isAndroid) return;

    // Cold-start: app was launched by a share intent.
    final initial = await ReceiveSharingIntent.instance.getInitialMedia();
    if (initial.isNotEmpty && !_isAuthCallback(initial.first)) {
      _pending = _convert(initial.first);
      notifyListeners();
    }

    // While-running: app receives a share while already open.
    _sub = ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      if (files.isNotEmpty && !_isAuthCallback(files.first)) {
        _pending = _convert(files.first);
        notifyListeners();
      }
    });
  }

  /// Mark the pending share as consumed. Call after the share screen completes.
  void consume() {
    _pending = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  IncomingShare _convert(SharedMediaFile f) {
    final id = 'share_${++_counter}';
    final isFile =
        f.type == SharedMediaType.image || f.type == SharedMediaType.file;
    final rawContent = f.path;
    final contentType = isFile ? _fileContentType(f) : detectContentType(rawContent);

    final String title;
    if (isFile) {
      title = rawContent.split('/').last;
    } else {
      final trimmed = rawContent.trim();
      title = trimmed.length > 80 ? '${trimmed.substring(0, 80)}…' : trimmed;
    }

    return IncomingShare(
      id: id,
      contentType: contentType,
      rawContent: rawContent,
      detectedTitle: _niceTitle(rawContent, contentType, title),
      filePath: isFile ? f.path : null,
      sharedAt: DateTime.now(),
    );
  }

  static String _niceTitle(
      String raw, ShareContentType type, String fallback) {
    if (type == ShareContentType.googleMapsLink) {
      final placeMatch = RegExp(r'/maps/place/([^/@]+)').firstMatch(raw);
      if (placeMatch != null) {
        return Uri.decodeComponent(
                placeMatch.group(1)!.replaceAll('+', ' '))
            .trim();
      }
      final qMatch = RegExp(r'[?&]q=([^&]+)').firstMatch(raw);
      if (qMatch != null) {
        return Uri.decodeComponent(qMatch.group(1)!.replaceAll('+', ' '))
            .trim();
      }
      return 'Shared location';
    }
    return fallback;
  }

  static bool _isAuthCallback(SharedMediaFile f) =>
      f.path.startsWith('com.example.wabway://');

  static ShareContentType _fileContentType(SharedMediaFile f) {
    if (f.type == SharedMediaType.image) return ShareContentType.screenshot;
    final lower = f.path.toLowerCase();
    if (lower.endsWith('.pdf')) return ShareContentType.pdfFile;
    if (lower.endsWith('.csv')) return ShareContentType.csvFile;
    return ShareContentType.screenshot;
  }
}
