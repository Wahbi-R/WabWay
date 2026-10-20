import 'package:flutter/material.dart';
import '../core/update_checker.dart';
import '../core/updater/apk_installer.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

/// Dismissible "Update available" card for Home / sign-in / trip picker.
/// Follows [UpdateChecker.latest], so it appears whenever a check finds a
/// new build (launch, coming back to the app, Settings → Check for
/// updates) — no restart needed. Renders nothing when up to date, on web,
/// and in debug builds.
class UpdateCheckerBanner extends StatefulWidget {
  const UpdateCheckerBanner({super.key});

  /// Versions dismissed this session (the banner sits on several screens).
  static final Set<String> _dismissed = {};

  @override
  State<UpdateCheckerBanner> createState() => _UpdateCheckerBannerState();
}

class _UpdateCheckerBannerState extends State<UpdateCheckerBanner> {
  @override
  void initState() {
    super.initState();
    UpdateChecker.check();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UpdateInfo?>(
      valueListenable: UpdateChecker.latest,
      builder: (context, info, _) {
        if (info == null || !info.hasUpdate || UpdateCheckerBanner._dismissed.contains(info.latestTag)) {
          return const SizedBox.shrink();
        }
        return UpdateCard(
          info: info,
          onDismiss: () => setState(() => UpdateCheckerBanner._dismissed.add(info.latestTag)),
        );
      },
    );
  }
}

/// Keeps the app on a supported build: checks for updates on launch and
/// whenever the app comes back to the foreground, and when a release says
/// this build must update ([UpdateInfo.isRequired]), covers the app with
/// [_UpdateRequiredScreen] until it's updated. Wraps the whole app
/// (MaterialApp.builder).
class UpdateGate extends StatefulWidget {
  const UpdateGate({super.key, required this.child});
  final Widget child;

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    UpdateChecker.check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) UpdateChecker.check();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UpdateInfo?>(
      valueListenable: UpdateChecker.latest,
      builder: (context, info, child) => Stack(
        children: [
          child!,
          if (info != null && info.isRequired) Positioned.fill(child: _UpdateRequiredScreen(info: info)),
        ],
      ),
      child: widget.child,
    );
  }
}

class _UpdateRequiredScreen extends StatelessWidget {
  const _UpdateRequiredScreen({required this.info});
  final UpdateInfo info;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kColorCream,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(kSpace6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.system_update_rounded, size: 48, color: kColorPrimary),
                  const SizedBox(height: kSpace4),
                  Text('Update required', style: kStyleTitle, textAlign: TextAlign.center),
                  const SizedBox(height: kSpace2),
                  Text(
                    'This version of WabWay is too old to keep using — install the update to carry on. '
                    'Your trips are safe.',
                    style: kStyleBody.copyWith(color: kColorInkSoft),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: kSpace5),
                  UpdateCard(info: info),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Update card ──────────────────────────────────────────────────────────────

/// "Update available — v1.1.0+188" with Download & install, progress and
/// retry. [onDismiss] shows an ✕ (omit it where the update can't be skipped).
class UpdateCard extends StatefulWidget {
  const UpdateCard({super.key, required this.info, this.onDismiss});
  final UpdateInfo info;
  final VoidCallback? onDismiss;

  @override
  State<UpdateCard> createState() => _UpdateCardState();
}

class _UpdateCardState extends State<UpdateCard> {
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
        // Installer opened (or failed): let them tap again if they backed out.
        setState(() { _progress = null; _error = err; });
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
            if (widget.onDismiss != null)
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
