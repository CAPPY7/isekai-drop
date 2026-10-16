import 'package:flutter/widgets.dart';

import '../engine/demo_engine.dart';
import '../engine/transfer_engine.dart';
import '../settings/settings_controller.dart';

/// Gives every screen access to the engine, settings and DEMO history.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.engine,
    required this.settings,
    required this.demoHistory,
    required super.child,
  });

  final TransferEngine engine;
  final SettingsController settings;
  final DemoHistory demoHistory;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      engine != oldWidget.engine ||
      settings != oldWidget.settings ||
      demoHistory != oldWidget.demoHistory;
}
