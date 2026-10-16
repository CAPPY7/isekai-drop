import 'package:flutter/material.dart';

import 'app.dart';
import 'engine/demo_engine.dart';
import 'engine/platform_engine.dart';
import 'settings/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsController.load();
  try {
    final engine = await createPlatformEngine(() => settings.deviceName);
    runApp(
      IsekaiDropApp(
        engine: engine,
        settings: settings,
        demoHistory: DemoHistory(),
      ),
    );
  } catch (_) {
    runApp(const StartupErrorApp());
  }
}
