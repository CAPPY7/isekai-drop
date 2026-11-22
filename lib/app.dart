import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'engine/core/identity_loader.dart';
import 'engine/transfer_engine.dart';
import 'settings/settings_controller.dart';
import 'ui/app_scope.dart';
import 'ui/diag_report.dart' show kAppVersion;
import 'ui/screens/onboarding_screen.dart';
import 'ui/shell.dart';
import 'ui/theme/app_theme.dart';
import 'ui/ui_env.dart';

class IsekaiDropApp extends StatelessWidget {
  const IsekaiDropApp({
    super.key,
    required this.engine,
    required this.settings,
    this.showOnboarding = true,
    this.animations = true,
    this.readPlatform = true,
  });

  final TransferEngine engine;
  final SettingsController settings;

  /// Show the first-run intro (spec A8) until it was seen once. C6: a
  /// parameter (tests pass false), no environment check.
  final bool showOnboarding;

  /// C6: see [UiEnv].
  final bool animations;
  final bool readPlatform;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      engine: engine,
      settings: settings,
      child: UiEnv(
        animations: animations,
        readPlatform: readPlatform,
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) => MaterialApp(
            title: 'Isekai Drop',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            home: showOnboarding && !settings.onboardingDone
                ? OnboardingScreen(onDone: settings.markOnboardingDone)
                : const AppShell(),
          ),
        ),
      ),
    );
  }
}

/// A6: text for "Copy details" on the start error screen. Same rules as
/// the Diagnostics report: app version, platform and the plain error class
/// only - never the error message, file names, device names or paths.
String startupErrorDetails(Object? error) {
  final b = StringBuffer()
    ..writeln('Isekai Drop $kAppVersion - start problem')
    ..writeln('Platform: ${Platform.operatingSystem}')
    ..writeln('Problem: ${error == null ? 'unknown' : plainErrorClass(error)}');
  if (error is IdentityUnreadable) b.writeln('Reason: ${error.reason}');
  return b.toString();
}

class _CopyDetails extends StatelessWidget {
  const _CopyDetails({this.error});
  final Object? error;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: 16),
      Text(
        'Problem: ${error == null ? 'unknown' : plainErrorClass(error!)}',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: () async {
          await Clipboard.setData(
            ClipboardData(text: startupErrorDetails(error)),
          );
          if (context.mounted) {
            ScaffoldMessenger.maybeOf(context)
                ?.showSnackBar(const SnackBar(content: Text('Details copied')));
          }
        },
        icon: const Icon(Icons.copy),
        label: const Text('Copy details'),
      ),
    ],
  );
}

/// Shown only if the engine cannot start at all.
/// A1 (0.11.2): for [IdentityUnreadable] it explains that the device key
/// could not be read and offers Try again / Create a new key (asks first).
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, this.error, this.onRetry, this.onNewKey});

  final Object? error;
  final Future<void> Function()? onRetry;
  final Future<void> Function()? onNewKey;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    darkTheme: AppTheme.dark(),
    themeMode: ThemeMode.dark,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                error is IdentityUnreadable
                    ? _KeyError(onRetry: onRetry, onNewKey: onNewKey)
                    : _GeneralError(onRetry: onRetry),
                _CopyDetails(error: error),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _GeneralError extends StatelessWidget {
  const _GeneralError({this.onRetry});
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        'Isekai Drop could not start its secure engine on this device. '
        'Please close and reopen the app. If it keeps happening, reinstall it.',
        textAlign: TextAlign.center,
      ),
      if (onRetry != null) ...[
        const SizedBox(height: 16),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          onPressed: onRetry,
          child: const Text('Try again'),
        ),
      ],
    ],
  );
}

class _KeyError extends StatelessWidget {
  const _KeyError({this.onRetry, this.onNewKey});
  final Future<void> Function()? onRetry;
  final Future<void> Function()? onNewKey;

  Future<void> _askNewKey(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Create a new key?'),
        content: const Text(
          'This device gets a new key. Devices you paired with will '
          'block this one until you pair with each of them again.',
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Create new key'),
          ),
        ],
      ),
    );
    if (ok == true) await onNewKey?.call();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.key_off, size: 48),
      const SizedBox(height: 16),
      const Text(
        'Your device key could not be read. Your other devices may need to '
        'pair with this one again.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      FilledButton(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: onRetry,
        child: const Text('Try again'),
      ),
      const SizedBox(height: 8),
      OutlinedButton(
        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: onNewKey == null ? null : () => _askNewKey(context),
        child: const Text('Create a new key'),
      ),
    ],
  );
}
