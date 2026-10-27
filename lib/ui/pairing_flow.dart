import 'package:flutter/material.dart';

import '../engine/transfer_engine.dart';
import 'app_scope.dart';
import 'theme/design_tokens.dart';

/// Pairing from THIS device: connect, show the code, user confirms it
/// matches the other screen, then wait for the other device to approve.
///
/// From a scanned QR code, [alsoTry] holds more addresses of the same device
/// and [expectFingerprint] its key: the connection must match it exactly.
Future<void> startPairingFlow(
  BuildContext context,
  String host,
  int port, {
  List<String> alsoTry = const [],
  String? expectFingerprint,
}) async {
  final engine = AppScope.of(context).engine;
  final messenger = ScaffoldMessenger.of(context);
  final nav = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(semanticsLabel: 'Connecting'),
          SizedBox(width: IdSpacing.md),
          Expanded(child: Text('Connecting securely...')),
        ],
      ),
    ),
  );
  PairingSession session;
  try {
    Object? lastError;
    PairingSession? found;
    for (final h in [host, ...alsoTry]) {
      try {
        found = await engine.beginPairing(
          h,
          port,
          expectFingerprint: expectFingerprint,
        );
        break;
      } on PairingException {
        rethrow;
      } catch (e) {
        lastError = e;
      }
    }
    if (found == null) throw lastError ?? const SocketExceptionLike();
    session = found;
  } catch (e) {
    nav.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          e is PairingException
              ? e.message
              : 'Could not connect to $host:$port. Check the address and that Isekai Drop is open there.',
        ),
      ),
    );
    return;
  }
  nav.pop();
  if (!context.mounted) {
    session.cancel();
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: const Text('Compare this code'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (session.verifiedByQr) ...[
            const Row(
              children: [
                Icon(Icons.verified, color: IdColors.success),
                SizedBox(width: IdSpacing.sm),
                Expanded(
                  child: Text('Key checked against the scanned QR code.'),
                ),
              ],
            ),
            const SizedBox(height: IdSpacing.sm),
            const Text(
              'Tap "Codes match - pair". The other device then asks to approve and shows this same code:',
            ),
          ] else
            const Text(
              'Tap "Codes match - pair" below. The other device then asks to '
              'approve and shows a code. Approve there only if it is EXACTLY this one:',
            ),
          const SizedBox(height: IdSpacing.md),
          SelectableText(
            session.code,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: IdSpacing.md),
          const Text(
            'If the codes differ, tap Cancel: someone may be in the middle.',
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Codes match - pair'),
        ),
      ],
    ),
  );
  if (ok != true) {
    session.cancel();
    return;
  }
  if (!context.mounted) return;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(
        children: [
          CircularProgressIndicator(semanticsLabel: 'Waiting'),
          SizedBox(width: IdSpacing.md),
          Expanded(child: Text('Waiting for the other device to approve...')),
        ],
      ),
    ),
  );
  try {
    final dev = await session.confirm();
    nav.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Paired with ${dev.name}. It is now trusted.')),
    );
  } catch (e) {
    nav.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(e is PairingException ? e.message : 'Pairing failed.'),
      ),
    );
  }
}

class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}
