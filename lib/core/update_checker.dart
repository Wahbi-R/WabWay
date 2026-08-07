import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

const _repoOwner = 'Wahbi-R';
const _repoName  = 'WabWay';

class UpdateInfo {
  const UpdateInfo({
    required this.latestTag,
    required this.currentBuild,
    required this.latestBuild,
    required this.downloadUrl,
    required this.releasePageUrl,
    required this.releaseNotes,
  });

  final String latestTag;
  final int    currentBuild;
  final int    latestBuild;
  final String downloadUrl;
  final String releasePageUrl;
  final String releaseNotes;

  bool get hasUpdate => latestBuild > currentBuild;
}

abstract final class UpdateChecker {
  static bool _checked = false;
  static UpdateInfo? _cached;

  static Future<UpdateInfo?> check() async {
    if (_checked) return _cached;
    if (kIsWeb || !Platform.isAndroid) { _checked = true; return null; }
    try {
      final info = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(info.buildNumber) ?? 0;

      final uri = Uri.parse(
        'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
      );
      final response = await http
          .get(uri, headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) return null;

      final json    = jsonDecode(response.body) as Map<String, dynamic>;
      final tag     = json['tag_name'] as String? ?? '';
      final body    = json['body'] as String? ?? '';
      final assets  = (json['assets'] as List? ?? []).cast<Map<String, dynamic>>();
      final pageUrl = json['html_url'] as String? ?? '';

      // tag format: v1.0.0+3 → build number is after '+'
      final buildStr = tag.contains('+') ? tag.split('+').last : '0';
      final latestBuild = int.tryParse(buildStr) ?? 0;

      // Find APK asset
      final apk = assets.firstWhere(
        (a) => (a['name'] as String? ?? '').endsWith('.apk'),
        orElse: () => <String, dynamic>{},
      );
      final downloadUrl = apk['browser_download_url'] as String? ?? '';

      _checked = true;
      _cached = UpdateInfo(
        latestTag:      tag,
        currentBuild:   currentBuild,
        latestBuild:    latestBuild,
        downloadUrl:    downloadUrl,
        releasePageUrl: pageUrl,
        releaseNotes:   body.trim(),
      );
      return _cached;
    } catch (_) {
      return null;
    }
  }
}
