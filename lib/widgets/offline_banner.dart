import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';
import '../theme/app_decorations.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.onRetry});
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
            horizontal: kSpace4, vertical: kSpace2),
        decoration: BoxDecoration(
          color: const Color(0xFF4B3F2A),
          boxShadow: kShadowSm,
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 16, color: Colors.white70),
              const SizedBox(width: kSpace2),
              Expanded(
                child: Text(
                  'Offline — showing last known data',
                  style: kStyleCaption.copyWith(color: Colors.white70),
                ),
              ),
              if (onRetry != null)
                TextButton(
                  onPressed: onRetry,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: kSpace2, vertical: 0),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Retry',
                      style: kStyleCaptionMedium.copyWith(color: kColorAccent)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
