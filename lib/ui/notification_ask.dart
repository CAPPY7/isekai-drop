// D2 (0.12.0): Android 13+ asks before an app may show notifications. We
// explain why first (our own dialog), then let Android ask, once.
import 'package:flutter/material.dart';

import 'theme/design_tokens.dart';

Future<void> maybeAskNotifications(
  BuildContext context, {
  required bool Function() alreadyAsked,
  required Future<void> Function() markAsked,
  required Future<bool> Function() askSystem,
}) async {
  if (alreadyAsked()) return;
  await markAsked();
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Show transfer notifications?'),
      content: const Text(
        'Isekai Drop shows how far a transfer is, and asks you about '
        'incoming files, in a notification. Then transfers keep going when '
        'you switch to another app. No file names or device names are shown.',
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, IdLayout.minTouchTarget),
          ),
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, IdLayout.minTouchTarget),
          ),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  if (ok == true) await askSystem();
}
