import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class ApkInstaller {
  ApkInstaller._();

  static const _channel = MethodChannel('ca.wabble.wabway/installer');
  static CancelToken? _cancelToken;

  static Future<void> install({
    required String url,
    required void Function(double progress) onProgress,
    required void Function(String? error) onComplete,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return;

    try {
      final dir = await getTemporaryDirectory();
      final name = Uri.parse(url).pathSegments.last;
      final path = '${dir.path}/$name';

      _cancelToken = CancelToken();

      await Dio().download(
        url,
        path,
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

      await _channel.invokeMethod<void>('installApk', {'path': path});
      onComplete(null);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) return;
      onComplete(e.message ?? 'Download failed');
    } on PlatformException catch (e) {
      onComplete(e.message ?? 'Install failed');
    } catch (e) {
      onComplete(e.toString());
    }
  }

  static void cancel() => _cancelToken?.cancel();
}
