import 'dart:async';

import 'package:flutter/material.dart';

import '../../engine/transfer_engine.dart';
import '../qr_pairing.dart';
import '../theme/design_tokens.dart';
import 'common.dart';
import 'radar.dart';

/// 0.11.0 (spec B9): while no device is found, a pulsing radar line; after
/// [hintAfter] a short hint card with 3 steps and "Scan QR" / "Search
/// again" buttons.
class DiscoveryHint extends StatefulWidget {
  const DiscoveryHint({
    super.key,
    required this.engine,
    this.hintAfter = const Duration(seconds: 8),
  });

  final TransferEngine engine;
  final Duration hintAfter;

  @override
  State<DiscoveryHint> createState() => _DiscoveryHintState();
}

class _DiscoveryHintState extends State<DiscoveryHint> {
  Timer? _t;
  bool _showHint = false;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  void _arm() {
    _t?.cancel();
    _t = Timer(widget.hintAfter, () {
      if (mounted) setState(() => _showHint = true);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _searchAgain() {
    setState(() => _showHint = false);
    _arm();
    unawaited(widget.engine.scanNetwork());
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.engine;
    final line = EmptyLine(
      leading: const SearchingRadar(),
      text: e.scanning
          ? 'Searching this network...'
          : (e.discoveryError ?? 'Looking for devices...'),
    );
    if (!_showHint || e.scanning) return line;
    final theme = Theme.of(context);
    Widget step(int n, String t) => Padding(
      padding: const EdgeInsets.only(top: IdSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text('$n.', style: theme.textTheme.bodyMedium),
          ),
          Expanded(child: Text(t, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
    return Column(
      key: const ValueKey('discovery-hint'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        line,
        Container(
          margin: const EdgeInsets.only(top: IdSpacing.xs),
          padding: const EdgeInsets.all(IdSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(IdRadii.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Not showing up?', style: theme.textTheme.titleSmall),
              step(1, 'Both devices are on the same Wi-Fi (or hotspot).'),
              step(2, 'Isekai Drop is open on the other device.'),
              step(3, 'Still nothing? Use its QR code.'),
              const SizedBox(height: IdSpacing.sm),
              Wrap(
                spacing: IdSpacing.sm,
                runSpacing: IdSpacing.sm,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, IdLayout.minTouchTarget),
                    ),
                    onPressed: () =>
                        canScanQr ? scanQrAndPair(context) : showMyQr(context),
                    icon: Icon(
                      canScanQr ? Icons.qr_code_scanner : Icons.qr_code_2,
                    ),
                    label: Text(canScanQr ? 'Scan QR' : 'Show my QR'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, IdLayout.minTouchTarget),
                    ),
                    onPressed: _searchAgain,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Search again'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
