import 'package:flutter/material.dart';

import 'engine/transfer_engine.dart';
import 'settings/settings_controller.dart';
import 'ui/app_scope.dart';
import 'ui/shell.dart';
import 'ui/theme/app_theme.dart';

class IsekaiDropApp extends StatelessWidget {
  const IsekaiDropApp({
    super.key,
    required this.engine,
    required this.settings,
  });

  final TransferEngine engine;
  final SettingsController settings;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      engine: engine,
      settings: settings,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          title: 'Isekai Drop',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          home: const AppShell(),
        ),
      ),
    );
  }
}
