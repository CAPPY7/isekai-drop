import 'package:flutter/widgets.dart';

/// C6 (0.11.4): app-wide switches that used to be guessed from an
/// environment variable set by the test runner. The app uses the defaults (all on);
/// widget tests pass them off through [IsekaiDropApp] or this widget.
class UiEnv extends InheritedWidget {
  const UiEnv({
    super.key,
    required super.child,
    this.animations = true,
    this.readPlatform = true,
  });

  /// Endless animations (the searching radar).
  final bool animations;

  /// Read live platform facts (network status line).
  final bool readPlatform;

  static const UiEnv _app = UiEnv(child: SizedBox.shrink());

  static UiEnv of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<UiEnv>() ?? _app;

  @override
  bool updateShouldNotify(UiEnv old) =>
      animations != old.animations || readPlatform != old.readPlatform;
}
