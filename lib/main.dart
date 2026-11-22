import 'dart:io';

import 'package:flutter/material.dart';

import 'app.dart';
import 'engine/core/identity_loader.dart';
import 'engine/platform_engine.dart';
import 'settings/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsController.load();
  await _start(settings);
}

Future<void> _start(SettingsController settings) async {
  try {
    final engine = await createPlatformEngine(
      () => settings.deviceName,
      acceptingFiles: () => settings.acceptFiles,
      autoAccept: (_) => settings.autoReceiveVerified,
      saveFileNames: () => settings.historyFileNames,
      visible: () => settings.visibleOnNetwork,
      fastDirect: () => settings.fastDirect,
      routeMode: () => settings.routeMode,
    );
    var visible = settings.visibleOnNetwork;
    settings.addListener(() {
      if (settings.visibleOnNetwork != visible) {
        visible = settings.visibleOnNetwork;
        setPlatformVisible(visible);
      }
    });
    runApp(IsekaiDropApp(engine: engine, settings: settings));
  } on IdentityUnreadable catch (e) {
    // A1: never make a new key by itself; the user decides.
    runApp(
      StartupErrorApp(
        error: e,
        onRetry: () => _start(settings),
        onNewKey: () async {
          await resetIdentity();
          await _start(settings);
        },
      ),
    );
  } catch (e, st) {
    // Local console only (never sent anywhere), to diagnose startup issues.
    stderr.writeln('Isekai Drop startup failed: $e\n$st');
    runApp(StartupErrorApp(error: e, onRetry: () => _start(settings)));
  }
}
