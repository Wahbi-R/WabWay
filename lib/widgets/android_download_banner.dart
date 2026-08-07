import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/platform/browser_detect.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';

/// Thin banner recommending the Android app to users on an Android browser.
/// Shown only on web + Android user-agent; dismissed state is persisted.
class AndroidDownloadBanner extends StatefulWidget {
  const AndroidDownloadBanner({super.key});

  @override
  State<AndroidDownloadBanner> createState() => _AndroidDownloadBannerState();
}

class _AndroidDownloadBannerState extends State<AndroidDownloadBanner> {
  static const _prefKey = 'android_banner_dismissed';

  bool _dismissed = true; // start hidden until we check prefs
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!kIsWeb || !isAndroidBrowser) return;
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getBool(_prefKey) ?? false;
    if (mounted) setState(() { _dismissed = dismissed; _ready = true; });
  }

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _dismissed) return const SizedBox.shrink();

    return Material(
      color: const Color(0xFF1A1A1A),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: kColorPrimary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text(
                    'W',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Get the WabWay app',
                      style: kStyleBodySemibold.copyWith(color: Colors.white, fontSize: 13),
                    ),
                    Text(
                      'Better experience on Android',
                      style: kStyleCaption.copyWith(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => launchUrl(
                  Uri.parse('https://github.com/Wahbi-R/WabWay/releases/latest'),
                  mode: LaunchMode.externalApplication,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: kColorPrimary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Install',
                    style: kStyleCaption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _dismiss,
                child: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
