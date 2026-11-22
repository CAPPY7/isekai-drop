// D2 (0.12.0): Android 13+ asks before an app may show notifications. We
// explain why first (our own dialog), then let Android ask, once.
import 'package:flutter/material.dart';

import 'theme/design_tokens.dart';
import '../l10n/l10n.dart';

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
      title: Text(tr(context).notifTitle),
      content: Text(tr(context).notifBody),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(0, IdLayout.minTouchTarget),
          ),
          onPressed: () => Navigator.pop(c, false),
          child: Text(tr(context).notNow),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, IdLayout.minTouchTarget),
          ),
          onPressed: () => Navigator.pop(c, true),
          child: Text(tr(context).continueLabel),
        ),
      ],
    ),
  );
  if (ok == true) await askSystem();
}
