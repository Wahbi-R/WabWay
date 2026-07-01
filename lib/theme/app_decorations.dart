import 'package:flutter/material.dart';
import 'app_colors.dart';

// ─── Corner radii ─────────────────────────────────────────────────────────────

const BorderRadius kRadiusXs   = BorderRadius.all(Radius.circular(6));
const BorderRadius kRadiusSm   = BorderRadius.all(Radius.circular(10));
const BorderRadius kRadiusMd   = BorderRadius.all(Radius.circular(14));
const BorderRadius kRadiusLg   = BorderRadius.all(Radius.circular(20));
const BorderRadius kRadiusXl   = BorderRadius.all(Radius.circular(28));
const BorderRadius kRadiusPill = BorderRadius.all(Radius.circular(999));

// Bottom sheet — rounded top only
const BorderRadius kRadiusSheet = BorderRadius.only(
  topLeft:  Radius.circular(28),
  topRight: Radius.circular(28),
);

// ─── Touch target sizes ───────────────────────────────────────────────────────

const double kTapMin         = 44.0;
const double kTapComfortable = 52.0;

// ─── Layout constants ─────────────────────────────────────────────────────────

const double kSidebarWidth    = 248.0;
const double kBottomNavHeight = 72.0;
const double kTopBarHeight    = 64.0;
const double kDesktopBreakpoint = 720.0;

// ─── Spacing scale (4px base) ─────────────────────────────────────────────────

const double kSpace1  = 4.0;
const double kSpace2  = 8.0;
const double kSpace3  = 12.0;
const double kSpace4  = 16.0;
const double kSpace5  = 20.0;
const double kSpace6  = 24.0;
const double kSpace7  = 28.0;
const double kSpace8  = 32.0;
const double kSpace10 = 40.0;
const double kSpace12 = 48.0;
const double kSpace16 = 64.0;
const double kSpace20 = 80.0;

// ─── Motion durations ─────────────────────────────────────────────────────────

const Duration kDurationFast = Duration(milliseconds: 120);
const Duration kDurationBase = Duration(milliseconds: 200);
const Duration kDurationSlow = Duration(milliseconds: 320);

// Ease-out for entrances — closest Flutter approximation to cubic-bezier(0.16,1,0.3,1)
const Curve kEaseOut     = Curves.easeOutCubic;
const Curve kEaseStandard = Curves.easeInOut;
const Curve kEaseIn      = Curves.easeIn;

// ─── Card decoration ─────────────────────────────────────────────────────────

BoxDecoration kCardDecoration() => BoxDecoration(
  color: kColorPaper,
  borderRadius: kRadiusLg,
  border: Border.all(color: kColorBorder),
  boxShadow: kShadowSm,
);

// Card with hover elevation
BoxDecoration kCardDecorationRaised() => BoxDecoration(
  color: kColorPaper,
  borderRadius: kRadiusLg,
  border: Border.all(color: kColorBorder),
  boxShadow: kShadowMd,
);

// ─── Input decoration factory ─────────────────────────────────────────────────

InputDecoration kInputDecoration({
  String? label,
  String? hint,
  Widget? prefix,
  Widget? suffix,
}) {
  const border = OutlineInputBorder(
    borderRadius: kRadiusSm,
    borderSide: BorderSide(color: kColorBorder),
  );
  const focusBorder = OutlineInputBorder(
    borderRadius: kRadiusSm,
    borderSide: BorderSide(color: kColorPrimary, width: 1.5),
  );
  const errorBorder = OutlineInputBorder(
    borderRadius: kRadiusSm,
    borderSide: BorderSide(color: kColorDanger, width: 1.5),
  );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: prefix,
    suffixIcon: suffix,
    filled: true,
    fillColor: kColorPaper,
    border: border,
    enabledBorder: border,
    focusedBorder: focusBorder,
    errorBorder: errorBorder,
    focusedErrorBorder: errorBorder,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: kSpace4,
      vertical: kSpace3,
    ),
  );
}

// ─── Sidebar nav row decoration ───────────────────────────────────────────────

BoxDecoration kSidebarRowActive() => const BoxDecoration(
  color: kColorPrimarySoft,
  borderRadius: kRadiusSm,
);

// ─── Photo slot decoration (warm placeholder, never grey) ────────────────────

BoxDecoration kPhotoSlotDecoration() => const BoxDecoration(
  color: kColorSurfaceSunken,
  borderRadius: kRadiusMd,
);
