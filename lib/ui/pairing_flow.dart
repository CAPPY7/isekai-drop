import 'package:flutter/material.dart';

import '../engine/transfer_engine.dart';
import 'app_scope.dart';
import 'theme/design_tokens.dart';

/// One-tap pairing from THIS device: connect, then the other device shows
/// one "Accept?" question. No code to type or confirm here (optional).
///
/// From a scanned QR code, [alsoTry] holds more addresses of the same device
/// and [expectFingerprint] its key: the connection must match it exactly.
Future<void> startPairingFlow(
  BuildContext context,
  String host,
  int port, {
  List<String> alsoTry = const [],
  String? expectFingerprint,
  String? peerName,
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
    if (!context.mounted) return;
    await showPairingProblem(
      context,
      'Could not connect',
      e is PairingException
          ? e.message
          : 'Could not connect to $host:$port. ${explainErrorClass(classifyError(e))}\n\n'
                'Check: both devices on the same Wi-Fi or hotspot, Isekai Drop open '
                'on the other device, and the address and port exactly as shown '
                'there. A Windows PC must allow Isekai Drop in its firewall '
                '(Private networks).',
    );
    return;
  }
  nav.pop();
  if (!context.mounted) {
    session.cancel();
    return;
  }
  // 0.9.1 one-tap: no code to confirm here. The other device shows ONE
  // question ("Accept NAME?"). The code is shown small, for whoever wants
  // to check it (optional, also later under Trusted devices).
  var cancelled = false;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => _WaitingForAccept(
      who: peerName ?? 'the other device',
      code: session.code,
      verifiedByQr: session.verifiedByQr,
      onCancel: () {
        cancelled = true;
        session.cancel();
        Navigator.pop(c);
      },
    ),
  );
  try {
    final dev = await session.confirm();
    if (!cancelled) nav.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Paired with ${dev.name}. Both devices remember each other.',
        ),
      ),
    );
  } catch (e) {
    if (cancelled) return;
    nav.pop();
    if (!context.mounted) return;
    await showPairingProblem(
      context,
      'Pairing did not finish',
      e is PairingException
          ? e.message
          : 'Pairing failed: ${explainErrorClass(classifyError(e))}',
    );
  }
}

/// One tap on a nearby device with files to send. Paired already: starts
/// the send. Not paired (C2, 0.11.4): this device shows the 16-digit code
/// and asks "Does the other screen show the same code?"; only "Same code,
/// send" lets the files go (the other device also taps Accept). Returns the
/// job, or null if it did not start (the reason was already shown).
Future<TransferJob?> sendToNearbyFlow(
  BuildContext context,
  NearbyDevice n,
  List<SendSource> files,
) async {
  final engine = AppScope.of(context).engine;
  final t = n.trusted;
  if (t != null && t.isTrusted && !n.fingerprintMismatch) {
    return engine.send(t, files, host: n.host, port: n.port);
  }
  return runCodeCheckedSend(
    context,
    who: n.name,
    problemTitle: 'Not sent',
    unreachable: 'Could not connect to ${n.name}.',
    start: (confirmCode) =>
        engine.sendToNearby(n, files, confirmCode: confirmCode),
  );
}

/// C2: runs [start] (a send to a device that is not paired) with the
/// "same code?" question in between. Shared by "send to nearby" and
/// "pair again and send".
Future<TransferJob?> runCodeCheckedSend(
  BuildContext context, {
  required String who,
  required String problemTitle,
  required String unreachable,
  required Future<TransferJob> Function(
    Future<bool> Function(String code) confirmCode,
  )
  start,
}) async {
  final nav = Navigator.of(context);
  var cancelled = false;
  var waitingOpen = false;
  void showWaiting() {
    waitingOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => _WaitingForAccept(
        who: who,
        onCancel: () {
          cancelled = true;
          waitingOpen = false;
          Navigator.pop(c);
        },
      ),
    );
  }

  void closeWaiting() {
    if (waitingOpen) {
      waitingOpen = false;
      nav.pop();
    }
  }

  Future<bool> confirmCode(String code) async {
    if (cancelled || !context.mounted) return false;
    closeWaiting();
    final same = await showCodeCheckDialog(context, who, code);
    if (!same) {
      cancelled = true;
      return false;
    }
    if (context.mounted) showWaiting();
    return true;
  }

  showWaiting();
  try {
    final job = await start(confirmCode);
    if (cancelled) {
      job.cancel();
      return null;
    }
    closeWaiting();
    return job;
  } catch (e) {
    if (cancelled || e is PairingCancelled) {
      closeWaiting();
      return null;
    }
    closeWaiting();
    if (!context.mounted) return null;
    await showPairingProblem(
      context,
      problemTitle,
      e is PairingException
          ? e.message
          : '$unreachable ${explainErrorClass(classifyError(e))}',
    );
    return null;
  }
}

/// C2: "Does the other screen show the same code?" True only for
/// "Same code, send".
Future<bool> showCodeCheckDialog(
  BuildContext context,
  String who,
  String code,
) async {
  final r = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: const Text('Does the other screen show the same code?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$who is a new device. Check that $who shows this code:'),
          const SizedBox(height: IdSpacing.md),
          SelectableText(
            code,
            style: const TextStyle(
              fontSize: IdTypeSizes.title,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: IdSpacing.md),
          const Text(
            'Different code? Tap Cancel. Nothing is sent until you tap '
            '"Same code, send".',
          ),
        ],
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            minimumSize: const Size(48, IdLayout.minTouchTarget),
          ),
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, IdLayout.minTouchTarget),
          ),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Same code, send'),
        ),
      ],
    ),
  );
  return r ?? false;
}

class _WaitingForAccept extends StatelessWidget {
  const _WaitingForAccept({
    required this.who,
    required this.onCancel,
    this.code,
    this.verifiedByQr = false,
  });
  final String who;
  final String? code;
  final bool verifiedByQr;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall;
    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircularProgressIndicator(semanticsLabel: 'Waiting'),
              const SizedBox(width: IdSpacing.md),
              Expanded(child: Text('Tap Accept on $who.')),
            ],
          ),
          if (verifiedByQr) ...[
            const SizedBox(height: IdSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.verified,
                  color: idStatus(context).success,
                  size: 18,
                ),
                SizedBox(width: IdSpacing.sm),
                Expanded(child: Text('Key matches the scanned QR code.')),
              ],
            ),
          ],
          if (code != null && !verifiedByQr) ...[
            const SizedBox(height: IdSpacing.md),
            Text('Optional check: $who shows the same code', style: muted),
            SelectableText(
              code!,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ],
        ],
      ),
      actions: [TextButton(onPressed: onCancel, child: const Text('Cancel'))],
    );
  }
}

/// Errors stay on screen until the user closes them (a snack bar is too
/// easy to miss).
Future<void> showPairingProblem(
  BuildContext context,
  String title,
  String message,
) => showDialog<void>(
  context: context,
  builder: (c) => AlertDialog(
    icon: Icon(Icons.error_outline, color: idStatus(context).danger),
    title: Text(title),
    content: SingleChildScrollView(child: Text(message)),
    actions: [
      FilledButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
    ],
  ),
);

class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}
