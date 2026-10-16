import 'package:flutter/material.dart';

import '../../engine/transfer_engine.dart';
import '../theme/design_tokens.dart';
import 'common.dart';

DisplayTrust trustOfNearby(NearbyDevice d) {
  final t = d.trusted;
  if (t == null) return DisplayTrust.unknown;
  if (!t.isTrusted || d.fingerprintMismatch) {
    return DisplayTrust.identityChanged;
  }
  return DisplayTrust.trusted;
}

DisplayTrust trustOf(TrustedDevice d) =>
    d.isTrusted ? DisplayTrust.trusted : DisplayTrust.identityChanged;

/// This device's address and key, so the other device can connect by hand.
class ThisDeviceCard extends StatefulWidget {
  const ThisDeviceCard({super.key, required this.engine});

  final TransferEngine engine;

  @override
  State<ThisDeviceCard> createState() => _ThisDeviceCardState();
}

class _ThisDeviceCardState extends State<ThisDeviceCard> {
  late Future<List<String>> _addrs = widget.engine.localAddresses();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final engine = widget.engine;
    return SectionCard(
      title: 'This device: ${engine.myName}',
      trailing: IconButton(
        tooltip: 'Refresh address',
        onPressed: () => setState(() {
          _addrs = engine.localAddresses();
        }),
        icon: const Icon(Icons.refresh),
      ),
      child: FutureBuilder<List<String>>(
        future: _addrs,
        builder: (context, snap) {
          final port = engine.listeningPort;
          final addrs = snap.data ?? const <String>[];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (engine.startError != null)
                Text(
                  engine.startError!,
                  style: const TextStyle(color: IdColors.danger),
                )
              else if (port == null)
                const Text('Starting...')
              else if (snap.connectionState != ConnectionState.done)
                const Text('Finding this device\'s address...')
              else if (addrs.isEmpty)
                const Text(
                  'No network found. Connect to Wi-Fi or a hotspot.',
                  style: TextStyle(color: IdColors.warning),
                )
              else ...[
                const Text('Address the other device can type:'),
                for (final a in addrs)
                  SelectableText(
                    '$a   port $port',
                    style: const TextStyle(
                      fontSize: IdTypeSizes.title,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
              const SizedBox(height: IdSpacing.xs),
              Text(
                'Key fingerprint: ${shortFingerprint(engine.myFingerprint)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
          );
        },
      ),
    );
  }
}

class NearbyTile extends StatelessWidget {
  const NearbyTile({super.key, required this.device, required this.onTap});

  final NearbyDevice device;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final trust = trustOfNearby(device);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: IdLayout.minTouchTarget,
      leading: Icon(platformIcon(device.platform)),
      title: Text(device.name),
      subtitle: TrustBadge(trust: trust),
      trailing: Text(switch (trust) {
        DisplayTrust.trusted => 'Send',
        DisplayTrust.unknown => 'Pair',
        DisplayTrust.identityChanged => 'Blocked',
      }, style: const TextStyle(fontWeight: FontWeight.w700)),
      onTap: trust == DisplayTrust.identityChanged ? null : onTap,
    );
  }
}
