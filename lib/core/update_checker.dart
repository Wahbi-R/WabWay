import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'updater/apk_installer.dart';

const _repoOwner = 'Wahbi-R';
const _repoName  = 'WabWay';

/// Release body marker for a forced update: `<!-- min-build: 188 -->`.
/// The build workflow writes it (carried forward from release to release)
/// when a push says "[force update]" — see build-and-deploy.yml.
final _minBuildRe = RegExp(r'<!--\s*min-build:\s*(\d+)\s*-->');

class UpdateInfo {
  const UpdateInfo({
    required this.latestTag,
    required this.currentBuild,
    required this.latestBuild,
    required this.downloadUrl,
    required this.releasePageUrl,
    required this.releaseNotes,
    this.minBuild = 0,
  });

  final String latestTag;
  final int    currentBuild;
  final int    latestBuild;
  final String downloadUrl;
  final String releasePageUrl;
  final String releaseNotes;

  /// Builds older than this must update before using the app.
  final int    minBuild;

  bool get hasUpdate => latestBuild > currentBuild;

  /// A forced update: this build is below the minimum and there's an APK.
  bool get isRequired => hasUpdate && currentBuild < minBuild && downloadUrl.isNotEmpty;

  /// Reads a GitHub "latest release" response. Public for tests.
  static UpdateInfo fromRelease(Map<String, dynamic> json, {required int currentBuild}) {
    final tag    = json['tag_name'] as String? ?? '';
    final body   = json['body'] as String? ?? '';
    final assets = (json['assets'] as List? ?? []).cast<Map<String, dynamic>>();
    // tag format: v1.0.0+3 → build number is after '+'
    final latestBuild = int.tryParse(tag.contains('+') ? tag.split('+').last : '') ?? 0;
    final apk = assets.firstWhere(
      (a) => (a['name'] as String? ?? '').endsWith('.apk'),
      orElse: () => <String, dynamic>{},
    );
    return UpdateInfo(
      latestTag:      tag,
      currentBuild:   currentBuild,
      latestBuild:    latestBuild,
      downloadUrl:    apk['browser_download_url'] as String? ?? '',
      releasePageUrl: json['html_url'] as String? ?? '',
      releaseNotes:   body.replaceAll(_minBuildRe, '').trim(),
      minBuild:       int.tryParse(_minBuildRe.firstMatch(body)?.group(1) ?? '') ?? 0,
    );
  }
}

/// Android APK updates from GitHub Releases. Checked at launch and whenever
/// the app comes back to the foreground (at most every [_interval]), or on
/// demand from Settings → Check for updates. Screens watch [latest].
abstract final class UpdateChecker {
  static const _interval = Duration(minutes: 30);
  static DateTime? _lastCheck;
  static Future<UpdateInfo?>? _inFlight;

  /// The newest result (null until checked, on web, or when offline).
  static final ValueNotifier<UpdateInfo?> latest = ValueNotifier(null);

  /// Android release builds only — debug and web builds never update.
  static bool get supported => !kIsWeb && Platform.isAndroid && !kDebugMode;

  static Future<UpdateInfo?> check({bool force = false}) {
    if (!supported) return Future.value(null);
    final last = _lastCheck;
    if (!force && last != null && DateTime.now().difference(last) < _interval) {
      return Future.value(latest.value);
    }
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  static Future<UpdateInfo?> _fetch() async {
    try {
      final package = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(package.buildNumber) ?? 0;
      // Installed (or abandoned) downloads of this build or older.
      unawaited(ApkInstaller.cleanup(currentBuild));

      final response = await http
          .get(
            Uri.parse('https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest'),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return latest.value;

      _lastCheck = DateTime.now();
      return latest.value = UpdateInfo.fromRelease(
        jsonDecode(response.body) as Map<String, dynamic>,
        currentBuild: currentBuild,
      );
    } catch (_) {
      return latest.value;
    }
  }
}
