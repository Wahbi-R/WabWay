import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wabway/core/update_checker.dart';
import 'package:wabway/core/updater/apk_installer.dart';
import 'package:wabway/widgets/update_checker_banner.dart';

Map<String, dynamic> _release(int build, {int? minBuild}) => {
      'tag_name': 'v1.1.0+$build',
      'html_url': 'https://github.com/Wahbi-R/WabWay/releases/tag/v1.1.0+$build',
      'body': 'Install on Android: download the APK below.\n'
          '${minBuild == null ? '' : '<!-- min-build: $minBuild -->'}',
      'assets': [
        {'name': 'wabway-v1.1.0.$build.apk',
         'browser_download_url': 'https://github.com/x/wabway-v1.1.0.$build.apk'},
      ],
    };

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('reads the release: build, APK, notes without the marker', () {
    final info = UpdateInfo.fromRelease(_release(190, minBuild: 185), currentBuild: 188);
    expect(info.latestBuild, 190);
    expect(info.hasUpdate, isTrue);
    expect(info.downloadUrl, endsWith('wabway-v1.1.0.190.apk'));
    expect(info.releaseNotes, 'Install on Android: download the APK below.');
    expect(info.minBuild, 185);
  });

  test('an update is only required below the minimum build', () {
    expect(UpdateInfo.fromRelease(_release(190), currentBuild: 188).isRequired, isFalse,
        reason: 'normal release: optional');
    expect(UpdateInfo.fromRelease(_release(190, minBuild: 0), currentBuild: 188).isRequired, isFalse);
    expect(UpdateInfo.fromRelease(_release(190, minBuild: 189), currentBuild: 188).isRequired, isTrue,
        reason: 'forced at 189, this is 188');
    expect(UpdateInfo.fromRelease(_release(190, minBuild: 188), currentBuild: 188).isRequired, isFalse,
        reason: 'already at the minimum: just a normal update');
    expect(UpdateInfo.fromRelease(_release(190, minBuild: 190), currentBuild: 190).isRequired, isFalse,
        reason: 'up to date');
  });

  test('old and unfinished update downloads are cleaned up, newer ones kept', () {
    expect(ApkInstaller.isStale('wabway-v1.1.0.187.apk', 188), isTrue, reason: 'older');
    expect(ApkInstaller.isStale('wabway-v1.1.0+188.apk', 188), isTrue, reason: 'the one now installed');
    expect(ApkInstaller.isStale('wabway-v1.1.0.190.apk', 188), isFalse, reason: 'ready to install');
    expect(ApkInstaller.isStale('wabway-v1.1.0.190.apk.part', 188), isTrue, reason: 'unfinished');
    expect(ApkInstaller.isStale('image_cache.db', 188), isFalse, reason: 'not ours');
  });

  testWidgets('a required update covers the app until it is installed', (tester) async {
    addTearDown(() => UpdateChecker.latest.value = null);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => UpdateGate(child: child!),
      home: const Scaffold(body: Text('Trips')),
    ));
    expect(find.text('Update required'), findsNothing);

    UpdateChecker.latest.value = UpdateInfo.fromRelease(_release(190), currentBuild: 188);
    await tester.pump();
    expect(find.text('Update required'), findsNothing, reason: 'optional updates only get the banner');

    UpdateChecker.latest.value = UpdateInfo.fromRelease(_release(190, minBuild: 190), currentBuild: 188);
    await tester.pump();
    expect(find.text('Update required'), findsOneWidget);
    expect(find.text('Download & install →'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing, reason: "can't be dismissed");
  });

  testWidgets('the banner appears when a check finds an update, without a restart', (tester) async {
    addTearDown(() => UpdateChecker.latest.value = null);
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: UpdateCheckerBanner())));
    expect(find.textContaining('Update available'), findsNothing);

    UpdateChecker.latest.value = UpdateInfo.fromRelease(_release(191), currentBuild: 188);
    await tester.pump();
    expect(find.text('Update available — v1.1.0+191'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(find.textContaining('Update available'), findsNothing);
  });
}
