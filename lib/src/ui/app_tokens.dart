import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Shared design tokens for app surfaces.
///
/// Auth still uses the stronger brand presentation below, while product
/// screens should prefer the semantic tokens so chat, wallet, moments and
/// settings resolve to the same visual system.
class AppTokens {
  AppTokens._();

  // ── Color: Brand (deep business blue) ────────────────────────────────────
  static const Color brand500 = Color(0xFF1E90FF);
  static const Color brand600 = Color(0xFF1E90FF);
  static const Color brand700 = Color(0xFF1E90FF);
  static const Color brand400 = Color(0xFF1E90FF);
  static const Color brand300 = Color(0xFF1E90FF);
  static const Color brand50 = Color(0xFFEAF4FF);
  static const Color brand100 = Color(0xFFD7EBFF);

  // Chat light surfaces (conversation page chrome + bubbles).
  static const Color chatBgLight = Color(0xFFF5F5F5);
  static const Color chatChromeDivider = Color(0xFFEAEAEA);
  static const Color chatBubbleSelfLight = Color(0xFFDCEEFF);
  static const Color chatBubbleOtherLight = Color(0xFFFFFFFF);
  static const Color chatBubbleOtherBorder = Color(0xFFE6E6E6);
  static const Color chatBubbleTextLight = Color(0xFF181818);
  static const double chatChromeDividerWidth = 0.5;
  static const double chatBubbleVerticalGap = 12;

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E90FF), Color(0xFF1E90FF), Color(0xFF1E90FF)],
    stops: [0.0, 0.55, 1.0],
  );

  // ── Color: Neutral (slate-ish grays for elegant text hierarchy) ──────────
  static const Color ink900 = Color(0xFF0B1220);
  static const Color ink800 = Color(0xFF111827);
  static const Color ink700 = Color(0xFF1F2937);
  static const Color ink600 = Color(0xFF374151);
  static const Color ink500 = Color(0xFF4B5563);
  static const Color ink400 = Color(0xFF6B7280);
  static const Color ink300 = Color(0xFF9CA3AF);
  static const Color ink200 = Color(0xFFD1D5DB);
  static const Color ink150 = Color(0xFFE6E6E9);
  static const Color ink100 = Color(0xFFE5E7EB);
  static const Color ink50 = Color(0xFFF3F4F6);
  static const Color ink25 = Color(0xFFF9FAFB);

  static const Color surface = Colors.white;
  static const Color surfaceAlt = Color(0xFFFAFBFC);
  static const Color divider = Color(0xFFEEF0F4);
  static const Color fieldFill = Color(0xFFF1F2F4);

  // Semantic color tokens.
  static const Color backgroundLight = Color(0xFFF5F6F8);
  static const Color surfaceLight = Colors.white;
  static const Color surfaceAltLight = Color(0xFFF1F3F5);
  static const Color textPrimaryLight = Color(0xFF111827);
  static const Color textSecondaryLight = Color(0xFF7A828D);
  static const Color borderLight = Color(0xFFE6E8EC);
  static const Color shadowLight = Color(0x080B1220);

  static const Color backgroundDark = Color(0xFF101114);
  static const Color surfaceDark = Color(0xFF1B1D22);
  static const Color surfaceAltDark = Color(0xFF23262D);
  static const Color textPrimaryDark = Color(0xFFF4F4F4);
  static const Color textSecondaryDark = Color(0xFF9A9CA3);
  static const Color borderDark = Color(0xFF2A2D33);
  static const Color shadowDark = Color(0x2D000000);

  static const Color accent = brand500;
  static const Color accentSoft = brand50;
  static const Color danger = Color(0xFFDC2626);
  static const Color walletDanger = Color(0xFFE60022);
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color warningSurfaceLight = Color(0xFFFFF7E8);
  static const Color warningSurfaceDark = Color(0xFF332716);

  static Color appBackground(bool dark) =>
      dark ? backgroundDark : backgroundLight;
  static Color appSurface(bool dark) => dark ? surfaceDark : surfaceLight;
  static Color appSurfaceAlt(bool dark) =>
      dark ? surfaceAltDark : surfaceAltLight;
  static Color appTextPrimary(bool dark) =>
      dark ? textPrimaryDark : textPrimaryLight;
  static Color appTextSecondary(bool dark) =>
      dark ? textSecondaryDark : textSecondaryLight;
  static Color appBorder(bool dark) => dark ? borderDark : borderLight;
  static Color appShadow(bool dark) => dark ? shadowDark : shadowLight;

  // ── Spacing scale (4pt base) ─────────────────────────────────────────────
  static const double s2 = 4;
  static const double s3 = 8;
  static const double s4 = 12;
  static const double s5 = 16;
  static const double s6 = 20;
  static const double s7 = 24;
  static const double s8 = 32;
  static const double s9 = 40;
  static const double s10 = 56;

  // ── Radius ───────────────────────────────────────────────────────────────
  static const double rSm = 8;
  static const double rMd = 12;
  static const double rLg = 14;
  static const double rCard = 18;
  static const double rXl = 20;
  static const double rPill = 999;

  static const double buttonHeight = 48;
  static const double listItemHeight = 56;

  // ── Elevation / shadows ──────────────────────────────────────────────────
  static List<BoxShadow> get shadowSm => [
        BoxShadow(
          color: const Color(0xFF0B1220).withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];
  static List<BoxShadow> get shadowMd => [
        BoxShadow(
          color: const Color(0xFF0B1220).withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: const Color(0xFF0B1220).withValues(alpha: 0.03),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];
  static List<BoxShadow> get shadowBrand => [];

  // ── Typography ───────────────────────────────────────────────────────────
  /// Web 用内置 NotoSansSC 简中子集；原生端沿用系统字体。
  static String? get fontFamily => kIsWeb ? 'NotoSansSC' : null;

  static TextStyle get display => TextStyle(
        fontFamily: fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: ink900,
        height: 1.2,
      );
  static TextStyle get title => TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: ink900,
        height: 1.25,
      );
  static TextStyle get subtitle => TextStyle(
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: ink400,
        height: 1.45,
        letterSpacing: 0,
      );
  static TextStyle get label => TextStyle(
        fontFamily: fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: ink700,
        letterSpacing: 0,
      );
  static TextStyle get body => TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: ink800,
        height: 1.5,
      );
  static TextStyle get bodyStrong => TextStyle(
        fontFamily: fontFamily,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: ink900,
      );
  static TextStyle get caption => TextStyle(
        fontFamily: fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: ink400,
        letterSpacing: 0,
      );
  static TextStyle get button => TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: Colors.white,
      );
  static TextStyle get link => TextStyle(
        fontFamily: fontFamily,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: brand500,
      );
  static TextStyle get authHeroTitle => TextStyle(
        fontFamily: fontFamily,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
        color: Colors.white,
        height: 1.18,
      );
  static TextStyle get authTabActive => TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 0,
      );
  static TextStyle get authTabInactive => TextStyle(
        fontFamily: fontFamily,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: Color(0xCCFFFFFF),
        letterSpacing: 0,
      );
}
