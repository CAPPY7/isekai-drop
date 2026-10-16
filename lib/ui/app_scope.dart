import 'package:flutter/widgets.dart';

import '../engine/transfer_engine.dart';
import '../settings/settings_controller.dart';

/// Gives every screen access to the engine, and settings.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.engine,
    required this.settings,
    required super.child,
  });

  final TransferEngine engine;
  final SettingsController settings;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      engine != oldWidget.engine || settings != oldWidget.settings;
}
