import 'dart:io';

import 'package:flutter/material.dart';

import 'app.dart';
import 'engine/platform_engine.dart';
import 'settings/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsController.load();
  try {
    final engine = await createPlatformEngine(
      () => settings.deviceName,
      acceptingFiles: () => settings.acceptFiles,
      autoAccept: (_) => settings.autoReceiveVerified,
      saveFileNames: () => settings.historyFileNames,
      visible: () => settings.visibleOnNetwork,
    );
    var visible = settings.visibleOnNetwork;
    settings.addListener(() {
      if (settings.visibleOnNetwork != visible) {
        visible = settings.visibleOnNetwork;
        setPlatformVisible(visible);
      }
    });
    runApp(IsekaiDropApp(engine: engine, settings: settings));
  } catch (e, st) {
    // Local console only (never sent anywhere), to diagnose startup issues.
    stderr.writeln('Isekai Drop startup failed: $e\n$st');
    runApp(const StartupErrorApp());
  }
}
