import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_decorations.dart';
import '../theme/app_text_theme.dart';

// A compact, styled search bar used consistently across list screens
// (Links, Travel, Plan, Stays, Spots, Docs). Includes a search prefix icon
// and a clear button that appears while the query is non-empty.
class WabwaySearchBar extends StatelessWidget {
  const WabwaySearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.hint = 'Search…',
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 0),
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  // Outer padding; default matches the standard screen-edge spacing.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: TextField(
        controller: controller,
        style: kStyleBody,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: kStyleBody.copyWith(color: kColorInkSoft),
          prefixIcon: const Icon(Icons.search_rounded, size: 18, color: kColorInkSoft),
          suffixIcon: controller.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    controller.clear();
                    onChanged('');
                  },
                  child: const Icon(Icons.close_rounded, size: 16, color: kColorInkSoft),
                )
              : null,
          filled: true,
          fillColor: kColorBgRaised,
          border: const OutlineInputBorder(
            borderRadius: kRadiusMd,
            borderSide: BorderSide(color: kColorBorder),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: kRadiusMd,
            borderSide: BorderSide(color: kColorBorder),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: kRadiusMd,
            borderSide: BorderSide(color: kColorPrimary),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          isDense: true,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
