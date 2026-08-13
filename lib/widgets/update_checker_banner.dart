import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/update_checker.dart';
import '../core/updater/apk_installer.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

/// Self-contained banner that checks for an Android APK update and shows a
/// dismissible card. Renders nothing on web or non-Android platforms and
/// renders nothing if the app is already up to date.
class UpdateCheckerBanner extends StatefulWidget {
  const UpdateCheckerBanner({super.key});

  @override
  State<UpdateCheckerBanner> createState() => _UpdateCheckerBannerState();
}

class _UpdateCheckerBannerState extends State<UpdateCheckerBanner> {
  UpdateInfo? _info;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _check();
  }

  Future<void> _check() async {
    if (kDebugMode) return;
    final info = await UpdateChecker.check();
    if (mounted && info != null && info.hasUpdate) {
      setState(() => _info = info);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_info == null || _dismissed) return const SizedBox.shrink();
    return _UpdateBannerContent(
      info: _info!,
      onDismiss: () => setState(() => _dismissed = true),
    );
  }
}

// ─── Banner UI ────────────────────────────────────────────────────────────────

class _UpdateBannerContent extends StatefulWidget {
  const _UpdateBannerContent({required this.info, required this.onDismiss});
  final UpdateInfo info;
  final VoidCallback onDismiss;

  @override
  State<_UpdateBannerContent> createState() => _UpdateBannerContentState();
}

class _UpdateBannerContentState extends State<_UpdateBannerContent> {
  double? _progress;
  String? _error;

  void _startDownload() {
    if (_progress != null) return;
    if (widget.info.downloadUrl.isEmpty) return;
    setState(() { _progress = 0; _error = null; });

    ApkInstaller.install(
      url: widget.info.downloadUrl,
      onProgress: (p) { if (mounted) setState(() => _progress = p); },
      onComplete: (err) {
        if (!mounted) return;
        if (err != null) setState(() { _progress = null; _error = err; });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final downloading = _progress != null;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: kColorPrimarySoft,
        borderRadius: kRadiusMd,
        border: Border.all(color: kColorPrimary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.system_update_rounded, size: 20, color: kColorPrimary),
            const SizedBox(width: kSpace2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update available — ${widget.info.latestTag}',
                    style: kStyleBodyMedium.copyWith(color: kColorPrimaryDark),
                  ),
                  if (widget.info.releaseNotes.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      widget.info.releaseNotes.length > 120
                          ? '${widget.info.releaseNotes.substring(0, 120)}…'
                          : widget.info.releaseNotes,
                      style: kStyleCaption.copyWith(color: kColorPrimaryDark),
                    ),
                  ],
                  const SizedBox(height: kSpace2),
                  if (downloading) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: kColorPrimary.withValues(alpha: 0.15),
                        color: kColorPrimary,
                        minHeight: 4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _progress! >= 1.0
                          ? 'Installing…'
                          : 'Downloading ${(_progress! * 100).toStringAsFixed(0)}%',
                      style: kStyleCaption.copyWith(color: kColorPrimaryDark),
                    ),
                  ] else ...[
                    GestureDetector(
                      onTap: _startDownload,
                      child: Text(
                        'Download & install →',
                        style: kStyleCaptionMedium.copyWith(
                          color: kColorPrimary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Failed — tap to retry',
                        style: kStyleCaption.copyWith(color: Colors.red),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            GestureDetector(
              onTap: widget.onDismiss,
              child: const Icon(Icons.close_rounded, size: 16, color: kColorInkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
