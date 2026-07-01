import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

// ─── Font families ────────────────────────────────────────────────────────────
//
// Plus Jakarta Sans  — all UI text (body, labels, buttons, nav)
// Lora               — editorial/display only (trip names, empty-state headlines)
// IBM Plex Mono      — codes, invite codes, currency ledger columns

// ─── Type scale (matches token file exactly) ──────────────────────────────────

const double kTextXs   = 12;
const double kTextSm   = 13;
const double kTextBase = 15;
const double kTextMd   = 17;
const double kTextLg   = 19;
const double kTextXl   = 23;
const double kText2xl  = 28;
const double kText3xl  = 34;
const double kText4xl  = 42;

// ─── Line height multipliers ──────────────────────────────────────────────────

const double kLeadingTight  = 1.15;
const double kLeadingSnug   = 1.30;
const double kLeadingNormal = 1.50;
const double kLeadingLoose  = 1.70;

// ─── Letter spacing ───────────────────────────────────────────────────────────

const double kTrackingTight  = -0.01;  // em — apply as fontSize * factor
const double kTrackingNormal = 0.0;
const double kTrackingWide   = 0.04;

// ─── Named text styles ────────────────────────────────────────────────────────
// Use these directly in widgets for semantic clarity.

// Display — Lora, used for trip names / hero headings
TextStyle get kStyleDisplay => GoogleFonts.lora(
  fontSize: kText4xl,
  fontWeight: FontWeight.w700,
  height: kLeadingTight,
  letterSpacing: kText4xl * kTrackingTight,
  color: kColorInk,
);

TextStyle get kStyleHeadingLg => GoogleFonts.lora(
  fontSize: kText3xl,
  fontWeight: FontWeight.w600,
  height: kLeadingSnug,
  color: kColorInk,
);

TextStyle get kStyleHeadingMd => GoogleFonts.lora(
  fontSize: kText2xl,
  fontWeight: FontWeight.w600,
  height: kLeadingSnug,
  color: kColorInk,
);

// Section headings — Plus Jakarta Sans
TextStyle get kStyleHeadingSm => GoogleFonts.plusJakartaSans(
  fontSize: kTextXl,
  fontWeight: FontWeight.w700,
  height: kLeadingSnug,
  color: kColorInk,
);

TextStyle get kStyleTitle => GoogleFonts.plusJakartaSans(
  fontSize: kTextLg,
  fontWeight: FontWeight.w600,
  height: kLeadingSnug,
  color: kColorInk,
);

TextStyle get kStyleBody => GoogleFonts.plusJakartaSans(
  fontSize: kTextBase,
  fontWeight: FontWeight.w400,
  height: kLeadingNormal,
  color: kColorInk,
);

TextStyle get kStyleBodyMedium => GoogleFonts.plusJakartaSans(
  fontSize: kTextBase,
  fontWeight: FontWeight.w500,
  height: kLeadingNormal,
  color: kColorInk,
);

TextStyle get kStyleBodySemibold => GoogleFonts.plusJakartaSans(
  fontSize: kTextBase,
  fontWeight: FontWeight.w600,
  height: kLeadingNormal,
  color: kColorInk,
);

TextStyle get kStyleBodyBold => GoogleFonts.plusJakartaSans(
  fontSize: kTextBase,
  fontWeight: FontWeight.w700,
  height: kLeadingNormal,
  color: kColorInk,
);

TextStyle get kStyleCaption => GoogleFonts.plusJakartaSans(
  fontSize: kTextSm,
  fontWeight: FontWeight.w400,
  height: kLeadingNormal,
  color: kColorInkSoft,
);

TextStyle get kStyleCaptionMedium => GoogleFonts.plusJakartaSans(
  fontSize: kTextSm,
  fontWeight: FontWeight.w500,
  height: kLeadingNormal,
  color: kColorInkSoft,
);

TextStyle get kStyleOverline => GoogleFonts.plusJakartaSans(
  fontSize: kTextXs,
  fontWeight: FontWeight.w600,
  height: kLeadingNormal,
  letterSpacing: kTextXs * kTrackingWide,
  color: kColorInkSoft,
);

// Button labels
TextStyle get kStyleButtonSm => GoogleFonts.plusJakartaSans(
  fontSize: kTextSm,
  fontWeight: FontWeight.w600,
  height: 1.0,
  color: kColorTextOnPrimary,
);

TextStyle get kStyleButtonMd => GoogleFonts.plusJakartaSans(
  fontSize: kTextBase,
  fontWeight: FontWeight.w600,
  height: 1.0,
  color: kColorTextOnPrimary,
);

TextStyle get kStyleButtonLg => GoogleFonts.plusJakartaSans(
  fontSize: kTextMd,
  fontWeight: FontWeight.w600,
  height: 1.0,
  color: kColorTextOnPrimary,
);

// Nav label (bottom bar)
TextStyle get kStyleNavLabel => GoogleFonts.plusJakartaSans(
  fontSize: 11,
  fontWeight: FontWeight.w500,
  height: 1.0,
);

TextStyle get kStyleNavLabelActive => GoogleFonts.plusJakartaSans(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  height: 1.0,
);

// Monospaced — amounts in tables, invite codes, confirmation numbers
TextStyle get kStyleMono => GoogleFonts.ibmPlexMono(
  fontSize: kTextBase,
  fontWeight: FontWeight.w400,
  height: kLeadingNormal,
  color: kColorInk,
);

TextStyle get kStyleMonoSm => GoogleFonts.ibmPlexMono(
  fontSize: kTextSm,
  fontWeight: FontWeight.w400,
  height: kLeadingNormal,
  color: kColorInk,
);

// ─── MaterialApp textTheme factory ───────────────────────────────────────────

TextTheme buildWabwayTextTheme() {
  return GoogleFonts.plusJakartaSansTextTheme().copyWith(
    // Map Material slots to Wabway semantic styles
    displayLarge:   kStyleDisplay,
    displayMedium:  kStyleHeadingLg,
    displaySmall:   kStyleHeadingMd,
    headlineLarge:  kStyleHeadingSm,
    headlineMedium: kStyleTitle,
    bodyLarge:      kStyleBody,
    bodyMedium:     kStyleCaption,
    bodySmall:      kStyleOverline,
    labelLarge:     kStyleButtonMd,
    labelMedium:    kStyleButtonSm,
    labelSmall:     kStyleNavLabel,
  );
}
