import 'package:flutter/material.dart';

// ─── Base hues (source-of-truth from the design token file) ──────────────────

const Color kColorCream         = Color(0xFFF8F3EA); // background
const Color kColorPaper         = Color(0xFFFFFDF8); // surface / card
const Color kColorBgRaised      = Color(0xFFFBF8F2); // sidebar background
const Color kColorSurfaceSunken = Color(0xFFF1EAE0); // photo placeholder, input bg

const Color kColorPrimary       = Color(0xFFC96F4A); // terracotta
const Color kColorPrimaryDark   = Color(0xFF9F4F34);
const Color kColorSecondary     = Color(0xFF7D9A75); // sage green
const Color kColorAccent        = Color(0xFFD6A84F); // muted gold

const Color kColorInk           = Color(0xFF2F2A25); // text primary
const Color kColorInkSoft       = Color(0xFF6F665D); // text secondary
const Color kColorBorder        = Color(0xFFE6DCCF); // sand
const Color kColorBorderStrong  = Color(0xFFB8A898); // emphasis border

const Color kColorSuccess       = Color(0xFF4F8A5B); // mossy green
const Color kColorWarning       = Color(0xFFC98A2E); // ochre
const Color kColorDanger        = Color(0xFFB94A48); // brick red

const Color kColorTextOnPrimary = Color(0xFFFFFDF8);

// ─── Derived tints (replaces CSS color-mix() in oklch) ───────────────────────
// These are pre-computed rather than runtime lerps so they are const-safe.

// Primary soft tint — ~14% primary on paper
const Color kColorPrimarySoft       = Color(0xFFF7EDE7);
const Color kColorPrimarySoftBorder = Color(0xFFEDD8CE);

// Secondary soft tint
const Color kColorSecondarySoft       = Color(0xFFEEF4EC);
const Color kColorSecondarySoftBorder = Color(0xFFD8E9D5);

// Accent soft tint
const Color kColorAccentSoft       = Color(0xFFF8F0E2);
const Color kColorAccentSoftBorder = Color(0xFFEEDDBA);

// Semantic soft tints
const Color kColorSuccessSoft       = Color(0xFFEBF4EE);
const Color kColorSuccessBorder     = Color(0xFFCAE4CF);
const Color kColorWarningSoft       = Color(0xFFF6EDDF);
const Color kColorWarningBorder     = Color(0xFFE8D0A3);
const Color kColorDangerSoft        = Color(0xFFF5E8E8);
const Color kColorDangerBorder      = Color(0xFFE4C2C2);

// Overlay / scrim — ink at ~55% opacity
const Color kColorOverlay = Color(0x8C2F2A25);

// Focus ring — terracotta at ~45% opacity
const Color kColorFocusRing = Color(0x72C96F4A);

// ─── Runtime derived helpers ──────────────────────────────────────────────────
// Use these for hover/active states where you need dynamic darkening.

Color kColorPrimaryHover()  => Color.lerp(kColorPrimary, Colors.black, 0.12)!;
Color kColorPrimaryActive() => Color.lerp(kColorPrimary, Colors.black, 0.24)!;

Color kColorSecondaryHover()  => Color.lerp(kColorSecondary, Colors.black, 0.15)!;
Color kColorSecondaryActive() => Color.lerp(kColorSecondary, Colors.black, 0.28)!;

Color kColorDangerHover()  => Color.lerp(kColorDanger, Colors.black, 0.15)!;
Color kColorDangerActive() => Color.lerp(kColorDanger, Colors.black, 0.24)!;

Color kColorTextTertiary() => kColorInkSoft.withValues(alpha: 0.65);

// ─── Shadow helpers ───────────────────────────────────────────────────────────

const kShadowXs = [
  BoxShadow(color: Color(0x0F241E16), blurRadius: 2, offset: Offset(0, 1)),
];

const kShadowSm = [
  BoxShadow(color: Color(0x12241E16), blurRadius: 6, offset: Offset(0, 2)),
  BoxShadow(color: Color(0x0D241E16), blurRadius: 2, offset: Offset(0, 1)),
];

const kShadowMd = [
  BoxShadow(color: Color(0x17241E16), blurRadius: 20, offset: Offset(0, 8)),
  BoxShadow(color: Color(0x0F241E16), blurRadius: 6,  offset: Offset(0, 2)),
];

const kShadowLg = [
  BoxShadow(color: Color(0x21241E16), blurRadius: 40, offset: Offset(0, 16)),
  BoxShadow(color: Color(0x12241E16), blurRadius: 12, offset: Offset(0, 4)),
];
