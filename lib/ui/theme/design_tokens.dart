import 'package:flutter/material.dart';

/// Design tokens: the single source of colours, spacing, radii and type
/// sizes for Isekai Drop. Screens must use these instead of raw numbers.
class IdColors {
  IdColors._();

  // Brand accents (original Isekai Drop palette).
  static const Color accentBlue = Color(0xFF3B5BDB);
  static const Color accentPurple = Color(0xFF7C3AED);
  static const Color accentGlow = Color(0xFF8EA2FF);

  // Dark surfaces.
  static const Color darkBackground = Color(0xFF0B0D17);
  static const Color darkSurface = Color(0xFF141726);
  static const Color darkSurfaceRaised = Color(0xFF1C2033);
  static const Color darkOnSurface = Color(0xFFE8EAF6);
  static const Color darkOnSurfaceMuted = Color(0xFF9AA0BC);

  // Light surfaces.
  static const Color lightBackground = Color(0xFFF5F6FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightOnSurface = Color(0xFF141726);
  static const Color lightOnSurfaceMuted = Color(0xFF5B6178);

  // Status colours.
  static const Color success = Color(0xFF2FBF71);
  static const Color warning = Color(0xFFF5A524);
  static const Color danger = Color(0xFFE5484D);

  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentBlue, accentPurple],
  );
}

class IdSpacing {
  IdSpacing._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class IdRadii {
  IdRadii._();
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double pill = 999;
}

class IdTypeSizes {
  IdTypeSizes._();
  static const double caption = 12;
  static const double body = 15;
  static const double title = 20;
  static const double headline = 28;
  static const double display = 36;
}

class IdLayout {
  IdLayout._();

  /// Widths at or above this use the desktop layout, below it phone/tablet.
  static const double desktopBreakpoint = 900;

  /// Minimum size of anything the user taps (accessibility).
  static const double minTouchTarget = 48;
}

class IdMotion {
  IdMotion._();
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 280);
  static const Curve curve = Curves.easeOutCubic;
}
