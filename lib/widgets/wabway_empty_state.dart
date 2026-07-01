import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

class WabwayEmptyState extends StatelessWidget {
  const WabwayEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kSpace6, vertical: kSpace12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: kColorPrimarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 26, color: kColorPrimaryDark),
          ),
          const SizedBox(height: kSpace4),
          Text(
            title,
            style: kStyleTitle,
            textAlign: TextAlign.center,
          ),
          if (description != null) ...[
            const SizedBox(height: kSpace2),
            Text(
              description!,
              style: kStyleCaption,
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: kSpace5),
            action!,
          ],
        ],
      ),
    );
  }
}
