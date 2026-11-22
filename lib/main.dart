import 'dart:io';

import 'package:flutter/material.dart';

import 'app.dart';
import 'engine/core/diag_log.dart';
import 'engine/core/identity_loader.dart';
import 'engine/platform_engine.dart';
import 'settings/settings_controller.dart';
import 'startup_guard.dart';

/// A6: app-wide Diagnostics log; the engine writes to the same one.
final _appLog = DiagLog();

void main() {
  runGuardedStartup(_appLog, () async {
    WidgetsFlutterBinding.ensureInitialized();
    installErrorHandlers(_appLog);
    final settings = await SettingsController.load();
    await _start(settings);
  });
}

Future<void> _start(SettingsController settings) async {
  try {
    final engine = await createPlatformEngine(
      () => settings.deviceName,
      diagLog: _appLog,
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
    recordUncaught(_appLog, e);
    runApp(StartupErrorApp(error: e, onRetry: () => _start(settings)));
  }
}
