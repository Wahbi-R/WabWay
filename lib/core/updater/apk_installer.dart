import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads an update APK into the app's private cache
/// (`<cache>/updates/`, not visible to the user or other apps) and hands it
/// to Android's installer. Old downloads are deleted by [cleanup]; a
/// finished download of the same version is reused instead of fetched again.
class ApkInstaller {
  ApkInstaller._();

  static const _channel = MethodChannel('ca.wabble.wabway/installer');
  static CancelToken? _cancelToken;
  static bool _downloading = false;

  static Future<Directory> _dir() async {
    final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<void> install({
    required String url,
    required void Function(double progress) onProgress,
    required void Function(String? error) onComplete,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      final dir = await _dir();
      final name = Uri.parse(url).pathSegments.last;
      final path = '${dir.path}/$name';

      // Already downloaded (e.g. the install prompt was cancelled): reuse it.
      if (!await File(path).exists()) {
        _cancelToken = CancelToken();
        _downloading = true;
        final part = '$path.part';
        await Dio().download(
          url,
          part,
          cancelToken: _cancelToken,
          onReceiveProgress: (received, total) {
            if (total > 0) onProgress(received / total);
          },
          options: Options(
            followRedirects: true,
            maxRedirects: 5,
            receiveTimeout: const Duration(minutes: 5),
          ),
        );
        // Only a complete download gets the real name.
        await File(part).rename(path);
        _downloading = false;
      }
      onProgress(1);

      await _channel.invokeMethod<void>('installApk', {'path': path});
      onComplete(null);
    } on DioException catch (e) {
      _downloading = false;
      if (e.type == DioExceptionType.cancel) return;
      onComplete(e.message ?? 'Download failed');
    } on PlatformException catch (e) {
      onComplete(e.message ?? 'Install failed');
    } catch (e) {
      _downloading = false;
      onComplete(e.toString());
    }
  }

  static void cancel() => _cancelToken?.cancel();

  /// Deletes update APKs for [currentBuild] or older (already installed, or
  /// superseded) and unfinished downloads. Also clears APKs left directly in
  /// the cache folder by builds before this one. Never throws.
  static Future<void> cleanup(int currentBuild) async {
    if (kIsWeb || !Platform.isAndroid || _downloading) return;
    try {
      final cache = await getTemporaryDirectory();
      final files = [
        ...cache.listSync().whereType<File>(),
        ...(await _dir()).listSync().whereType<File>(),
      ];
      for (final f in files) {
        if (isStale(f.uri.pathSegments.last, currentBuild)) {
          try { await f.delete(); } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Whether a downloaded file can go: an unfinished `.part`, or an APK whose
  /// build (`wabway-v1.1.0+188.apk`, or `wabway-v1.1.0.188.apk` as GitHub
  /// renames it → 188) isn't newer than what's installed. Public for tests.
  static bool isStale(String fileName, int currentBuild) {
    if (fileName.endsWith('.apk.part')) return true;
    if (!fileName.endsWith('.apk')) return false;
    final build = int.tryParse(RegExp(r'[+.](\d+)\.apk$').firstMatch(fileName)?.group(1) ?? '');
    return build == null || build <= currentBuild;
  }
}
