import 'dart:io';

import 'package:flutter/material.dart';

import 'engine/transfer_engine.dart';
import 'settings/settings_controller.dart';
import 'ui/app_scope.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/shell.dart';
import 'ui/theme/app_theme.dart';

class IsekaiDropApp extends StatelessWidget {
  const IsekaiDropApp({
    super.key,
    required this.engine,
    required this.settings,
    this.showOnboarding,
  });

  final TransferEngine engine;
  final SettingsController settings;

  /// Show the first-run intro (spec A8) until it was seen once. Off in
  /// widget tests unless a test asks for it.
  final bool? showOnboarding;

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
          home:
              (showOnboarding ??
                      !Platform.environment.containsKey('FLUTTER_TEST')) &&
                  !settings.onboardingDone
              ? OnboardingScreen(onDone: settings.markOnboardingDone)
              : const AppShell(),
        ),
      ),
    );
  }
}

/// Shown only if the engine cannot start at all.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    darkTheme: AppTheme.dark(),
    themeMode: ThemeMode.dark,
    home: const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Isekai Drop could not start its secure engine on this device. '
            'Please close and reopen the app. If it keeps happening, reinstall it.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
