import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../engine/core/qr_payload.dart';
import 'app_scope.dart';
import 'pairing_flow.dart';
import 'theme/design_tokens.dart';
import 'widgets/common.dart';

/// Scanning needs a camera: Android, iPhone/iPad and Mac.
bool get canScanQr => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

/// Shows THIS device's pairing QR code (addresses, port, key fingerprint,
/// name - nothing secret).
Future<void> showMyQr(BuildContext context) async {
  final engine = AppScope.of(context).engine;
  final hosts = await engine.localAddresses();
  if (!context.mounted) return;
  final port = engine.listeningPort;
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('My pairing QR code'),
      content: SizedBox(
        width: 300,
        child: hosts.isEmpty || port == null
            ? const Text(
                'Not connected to any network yet. Join a Wi-Fi or hotspot first.',
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(IdSpacing.sm),
                    child: QrImageView(
                      data: PairingQr(
                        hosts: hosts,
                        port: port,
                        fingerprint: engine.myFingerprint,
                        name: engine.myName,
                      ).encode(),
                      size: 240,
                      semanticsLabel: 'Pairing QR code for this device',
                    ),
                  ),
                  const SizedBox(height: IdSpacing.sm),
                  const Text(
                    'On the other device open Connect > Scan QR code. '
                    'You will still be asked to approve here.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// Explains the camera use first, then opens the scanner.
Future<void> scanQrAndPair(BuildContext context) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: const Text('Use the camera to scan?'),
      content: Text(
        'Isekai Drop uses the camera only to read the pairing QR code on the '
        'other device. Nothing is recorded or saved, and the picture never '
        'leaves this device. Your system will ask for camera permission.'
        '${Platform.isAndroid ? '\n\nThe Android scanner is Google ML Kit. Google says it sends its own usage metrics and device info (not images) to Google when online.' : ''}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  if (go != true || !context.mounted) return;
  final qr = await Navigator.of(context)
      .push<PairingQr>(MaterialPageRoute(builder: (_) => const _ScanScreen()));
  if (qr == null || !context.mounted) return;
  await startPairingFlow(
    context,
    qr.hosts.first,
    qr.port,
    alsoTry: qr.hosts.skip(1).toList(),
    expectFingerprint: qr.fingerprint,
  );
}

class _ScanScreen extends StatefulWidget {
  const _ScanScreen();

  @override
  State<_ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<_ScanScreen> {
  final _controller = MobileScannerController(formats: [BarcodeFormat.qrCode]);
  bool _done = false;
  String? _hint;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final qr = PairingQr.tryParse(raw);
      if (qr != null) {
        _done = true;
        Navigator.of(context).pop(qr);
        return;
      }
      setState(() => _hint = 'That is not an Isekai Drop pairing code.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Scan pairing QR code')),
    body: Column(
      children: [
        Expanded(
          child: MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => const StateMessage(
              icon: Icons.no_photography_outlined,
              title: 'Camera not available',
              message: 'Allow camera access in system settings, or pair by typing the address instead.',
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(IdSpacing.md),
          child: Text(
            _hint ??
                'Point the camera at the QR code shown on the other device '
                    '(Connect > Show my QR code).',
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );
}
