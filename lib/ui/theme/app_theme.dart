import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'design_tokens.dart';

/// Builds the dark and light themes from the design tokens.
class AppTheme {
  AppTheme._();

  static ThemeData dark() => _build(
    brightness: Brightness.dark,
    background: IdColors.darkBackground,
    surface: IdColors.darkSurface,
    onSurface: IdColors.darkOnSurface,
    muted: IdColors.darkOnSurfaceMuted,
  );

  static ThemeData light() => _build(
    brightness: Brightness.light,
    background: IdColors.lightBackground,
    surface: IdColors.lightSurface,
    onSurface: IdColors.lightOnSurface,
    muted: IdColors.lightOnSurfaceMuted,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color onSurface,
    required Color muted,
  }) {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: IdColors.accentBlue,
          brightness: brightness,
        ).copyWith(
          // 0.11.0: on dark, blue text (text buttons, links) used
          // accentBlue at 3.1:1. The lighter glow blue is 7.4:1, with dark
          // text on filled buttons (8:1).
          primary: brightness == Brightness.dark
              ? IdColors.accentGlow
              : IdColors.accentBlue,
          onPrimary: brightness == Brightness.dark
              ? IdColors.darkBackground
              : Colors.white,
          secondary: IdColors.accentPurple,
          surface: surface,
          onSurface: onSurface,
          onSurfaceVariant: muted,
          error: brightness == Brightness.dark
              ? IdColors.danger
              : IdColors.lightDanger,
          onError: brightness == Brightness.dark
              ? IdColors.darkBackground
              : Colors.white,
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      // 0.11.0 (spec E24/D20): one subtle fade transition between screens
      // everywhere; none when the system asks to reduce motion.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: IdPageTransitions(),
          TargetPlatform.windows: IdPageTransitions(),
          TargetPlatform.linux: IdPageTransitions(),
          TargetPlatform.macOS: IdPageTransitions(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      extensions: [
        brightness == Brightness.dark
            ? IdStatusColors.dark
            : IdStatusColors.light,
      ],
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(IdRadii.lg),
        ),
      ),
      textTheme: TextTheme(
        displaySmall: TextStyle(
          fontSize: IdTypeSizes.display,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        headlineSmall: TextStyle(
          fontSize: IdTypeSizes.headline,
          fontWeight: FontWeight.w700,
          color: onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: IdTypeSizes.title,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
        bodyMedium: TextStyle(fontSize: IdTypeSizes.body, color: onSurface),
        bodySmall: TextStyle(fontSize: IdTypeSizes.caption, color: muted),
        bodyLarge: TextStyle(fontSize: IdTypeSizes.body, color: onSurface),
      ),
    );
  }
}

/// Fade-forwards page transition, or none when animations are disabled.
class IdPageTransitions extends PageTransitionsBuilder {
  const IdPageTransitions();

  static const _fade = FadeForwardsPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    return _fade.buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
