import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_theme.dart';
import 'app_decorations.dart';

// ─── WabwayColors ThemeExtension ─────────────────────────────────────────────
// Gives widgets access to brand-specific colors via Theme.of(context).extension.

@immutable
class WabwayColors extends ThemeExtension<WabwayColors> {
  const WabwayColors({
    required this.bg,
    required this.surface,
    required this.bgRaised,
    required this.surfaceSunken,
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.primarySoftBorder,
    required this.secondary,
    required this.secondarySoft,
    required this.accent,
    required this.accentSoft,
    required this.ink,
    required this.inkSoft,
    required this.border,
    required this.borderStrong,
    required this.overlay,
    required this.focusRing,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.danger,
    required this.dangerSoft,
  });

  final Color bg;
  final Color surface;
  final Color bgRaised;
  final Color surfaceSunken;
  final Color primary;
  final Color primaryDark;
  final Color primarySoft;
  final Color primarySoftBorder;
  final Color secondary;
  final Color secondarySoft;
  final Color accent;
  final Color accentSoft;
  final Color ink;
  final Color inkSoft;
  final Color border;
  final Color borderStrong;
  final Color overlay;
  final Color focusRing;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color danger;
  final Color dangerSoft;

  static const WabwayColors instance = WabwayColors(
    bg:                 kColorCream,
    surface:            kColorPaper,
    bgRaised:           kColorBgRaised,
    surfaceSunken:      kColorSurfaceSunken,
    primary:            kColorPrimary,
    primaryDark:        kColorPrimaryDark,
    primarySoft:        kColorPrimarySoft,
    primarySoftBorder:  kColorPrimarySoftBorder,
    secondary:          kColorSecondary,
    secondarySoft:      kColorSecondarySoft,
    accent:             kColorAccent,
    accentSoft:         kColorAccentSoft,
    ink:                kColorInk,
    inkSoft:            kColorInkSoft,
    border:             kColorBorder,
    borderStrong:       kColorBorderStrong,
    overlay:            kColorOverlay,
    focusRing:          kColorFocusRing,
    success:            kColorSuccess,
    successSoft:        kColorSuccessSoft,
    warning:            kColorWarning,
    warningSoft:        kColorWarningSoft,
    danger:             kColorDanger,
    dangerSoft:         kColorDangerSoft,
  );

  @override
  WabwayColors copyWith({
    Color? bg,
    Color? surface,
    Color? bgRaised,
    Color? surfaceSunken,
    Color? primary,
    Color? primaryDark,
    Color? primarySoft,
    Color? primarySoftBorder,
    Color? secondary,
    Color? secondarySoft,
    Color? accent,
    Color? accentSoft,
    Color? ink,
    Color? inkSoft,
    Color? border,
    Color? borderStrong,
    Color? overlay,
    Color? focusRing,
    Color? success,
    Color? successSoft,
    Color? warning,
    Color? warningSoft,
    Color? danger,
    Color? dangerSoft,
  }) {
    return WabwayColors(
      bg:                bg ?? this.bg,
      surface:           surface ?? this.surface,
      bgRaised:          bgRaised ?? this.bgRaised,
      surfaceSunken:     surfaceSunken ?? this.surfaceSunken,
      primary:           primary ?? this.primary,
      primaryDark:       primaryDark ?? this.primaryDark,
      primarySoft:       primarySoft ?? this.primarySoft,
      primarySoftBorder: primarySoftBorder ?? this.primarySoftBorder,
      secondary:         secondary ?? this.secondary,
      secondarySoft:     secondarySoft ?? this.secondarySoft,
      accent:            accent ?? this.accent,
      accentSoft:        accentSoft ?? this.accentSoft,
      ink:               ink ?? this.ink,
      inkSoft:           inkSoft ?? this.inkSoft,
      border:            border ?? this.border,
      borderStrong:      borderStrong ?? this.borderStrong,
      overlay:           overlay ?? this.overlay,
      focusRing:         focusRing ?? this.focusRing,
      success:           success ?? this.success,
      successSoft:       successSoft ?? this.successSoft,
      warning:           warning ?? this.warning,
      warningSoft:       warningSoft ?? this.warningSoft,
      danger:            danger ?? this.danger,
      dangerSoft:        dangerSoft ?? this.dangerSoft,
    );
  }

  @override
  WabwayColors lerp(WabwayColors? other, double t) {
    if (other is! WabwayColors) return this;
    return WabwayColors(
      bg:                Color.lerp(bg, other.bg, t)!,
      surface:           Color.lerp(surface, other.surface, t)!,
      bgRaised:          Color.lerp(bgRaised, other.bgRaised, t)!,
      surfaceSunken:     Color.lerp(surfaceSunken, other.surfaceSunken, t)!,
      primary:           Color.lerp(primary, other.primary, t)!,
      primaryDark:       Color.lerp(primaryDark, other.primaryDark, t)!,
      primarySoft:       Color.lerp(primarySoft, other.primarySoft, t)!,
      primarySoftBorder: Color.lerp(primarySoftBorder, other.primarySoftBorder, t)!,
      secondary:         Color.lerp(secondary, other.secondary, t)!,
      secondarySoft:     Color.lerp(secondarySoft, other.secondarySoft, t)!,
      accent:            Color.lerp(accent, other.accent, t)!,
      accentSoft:        Color.lerp(accentSoft, other.accentSoft, t)!,
      ink:               Color.lerp(ink, other.ink, t)!,
      inkSoft:           Color.lerp(inkSoft, other.inkSoft, t)!,
      border:            Color.lerp(border, other.border, t)!,
      borderStrong:      Color.lerp(borderStrong, other.borderStrong, t)!,
      overlay:           Color.lerp(overlay, other.overlay, t)!,
      focusRing:         Color.lerp(focusRing, other.focusRing, t)!,
      success:           Color.lerp(success, other.success, t)!,
      successSoft:       Color.lerp(successSoft, other.successSoft, t)!,
      warning:           Color.lerp(warning, other.warning, t)!,
      warningSoft:       Color.lerp(warningSoft, other.warningSoft, t)!,
      danger:            Color.lerp(danger, other.danger, t)!,
      dangerSoft:        Color.lerp(dangerSoft, other.dangerSoft, t)!,
    );
  }
}

// ─── Theme builder ────────────────────────────────────────────────────────────

ThemeData buildWabwayTheme() {
  final colorScheme = ColorScheme.light(
    primary:          kColorPrimary,
    onPrimary:        kColorTextOnPrimary,
    secondary:        kColorSecondary,
    onSecondary:      kColorTextOnPrimary,
    tertiary:         kColorAccent,
    error:            kColorDanger,
    onError:          kColorTextOnPrimary,
    surface:          kColorPaper,
    onSurface:        kColorInk,
    surfaceContainerHighest: kColorBgRaised,
    outline:          kColorBorder,
    outlineVariant:   kColorBorderStrong,
    scrim:            kColorOverlay,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: kColorCream,
    textTheme: buildWabwayTextTheme(),
    extensions: const [WabwayColors.instance],

    // No ripple — custom press feedback via AnimatedContainer
    splashFactory: NoSplash.splashFactory,
    highlightColor: kColorPrimarySoft,

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: kColorPaper,
      foregroundColor: kColorInk,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: const Color(0x12241E16),
      titleSpacing: kSpace4,
      toolbarHeight: kTopBarHeight,
      titleTextStyle: kStyleBodyBold.copyWith(color: kColorInk),
      surfaceTintColor: Colors.transparent,
    ),

    // Bottom navigation bar
    navigationBarTheme: NavigationBarThemeData(
      height: kBottomNavHeight,
      backgroundColor: kColorPaper,
      surfaceTintColor: Colors.transparent,
      shadowColor: const Color(0x12241E16),
      elevation: 4,
      indicatorColor: kColorPrimarySoft,
      indicatorShape: RoundedRectangleBorder(borderRadius: kRadiusPill),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final active = states.contains(WidgetState.selected);
        return IconThemeData(
          size: 24,
          color: active ? kColorPrimary : kColorInkSoft,
        );
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final active = states.contains(WidgetState.selected);
        return active ? kStyleNavLabelActive.copyWith(color: kColorPrimary)
                      : kStyleNavLabel.copyWith(color: kColorInkSoft);
      }),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),

    // Cards
    cardTheme: CardThemeData(
      color: kColorPaper,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: kRadiusLg,
        side: const BorderSide(color: kColorBorder),
      ),
      margin: EdgeInsets.zero,
    ),

    // Dividers
    dividerTheme: const DividerThemeData(
      color: kColorBorder,
      thickness: 1,
      space: 0,
    ),

    // Input fields
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kColorPaper,
      border: OutlineInputBorder(
        borderRadius: kRadiusSm,
        borderSide: const BorderSide(color: kColorBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: kRadiusSm,
        borderSide: const BorderSide(color: kColorBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: kRadiusSm,
        borderSide: const BorderSide(color: kColorPrimary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: kRadiusSm,
        borderSide: const BorderSide(color: kColorDanger, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: kSpace4,
        vertical: kSpace3,
      ),
    ),

    // Checkbox
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected) ? kColorPrimary : Colors.transparent),
      checkColor: WidgetStateProperty.all(kColorTextOnPrimary),
      shape: RoundedRectangleBorder(borderRadius: kRadiusXs),
      side: const BorderSide(color: kColorBorder, width: 1.5),
    ),

    // Switch
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected) ? kColorTextOnPrimary : kColorInkSoft),
      trackColor: WidgetStateProperty.resolveWith((states) =>
        states.contains(WidgetState.selected) ? kColorPrimary : kColorBorder),
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: kColorPaper,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: kRadiusXl),
      elevation: 0,
      barrierColor: kColorOverlay,
    ),

    // Snackbar (Toast)
    snackBarTheme: SnackBarThemeData(
      backgroundColor: kColorInk,
      contentTextStyle: kStyleCaption.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: kRadiusMd),
      behavior: SnackBarBehavior.floating,
    ),

    // Floating action button
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: kColorPrimary,
      foregroundColor: kColorTextOnPrimary,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: kRadiusMd),
    ),

    // Chips (used for tags, vote chips, filter chips)
    chipTheme: ChipThemeData(
      backgroundColor: kColorPrimarySoft,
      selectedColor: kColorPrimary,
      labelStyle: kStyleCaptionMedium,
      padding: const EdgeInsets.symmetric(horizontal: kSpace3, vertical: kSpace1),
      shape: RoundedRectangleBorder(borderRadius: kRadiusPill),
      side: const BorderSide(color: kColorBorder),
    ),

    // Tab bar
    tabBarTheme: TabBarThemeData(
      labelColor: kColorPrimary,
      unselectedLabelColor: kColorInkSoft,
      labelStyle: kStyleBodySemibold,
      unselectedLabelStyle: kStyleBodyMedium,
      indicatorColor: kColorPrimary,
      indicatorSize: TabBarIndicatorSize.label,
      dividerColor: kColorBorder,
    ),

    // List tiles
    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      iconColor: kColorInkSoft,
      textColor: kColorInk,
      shape: RoundedRectangleBorder(borderRadius: kRadiusSm),
      minVerticalPadding: kSpace3,
    ),
  );
}
