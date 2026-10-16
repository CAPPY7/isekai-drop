import 'package:flutter/material.dart';

import '../../engine/transfer_engine.dart';
import '../app_scope.dart';
import '../pairing_flow.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';
import '../widgets/device_widgets.dart';
import 'transfer_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onSend,
    required this.onConnect,
    required this.onTrusted,
  });

  final VoidCallback onSend;
  final VoidCallback onConnect;
  final VoidCallback onTrusted;

  @override
  Widget build(BuildContext context) {
    final engine = AppScope.of(context).engine;
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final ready = engine.startError == null && engine.listeningPort != null;
        return PageBody(
          children: [
            Container(
              padding: const EdgeInsets.all(IdSpacing.lg),
              decoration: BoxDecoration(
                gradient: IdColors.brandGradient,
                borderRadius: BorderRadius.circular(IdRadii.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ready ? 'Ready' : 'Not ready',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: IdTypeSizes.headline,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    ready
                        ? 'Keep Isekai Drop open to receive. You will always be asked first.'
                        : (engine.startError ?? 'Starting...'),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: IdSpacing.md),
                  Wrap(
                    spacing: IdSpacing.sm,
                    runSpacing: IdSpacing.sm,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: IdColors.accentBlue,
                          minimumSize: const Size(140, IdLayout.minTouchTarget),
                        ),
                        onPressed: onSend,
                        icon: const Icon(Icons.upload_rounded),
                        label: const Text('Send'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          minimumSize: const Size(140, IdLayout.minTouchTarget),
                        ),
                        onPressed: onConnect,
                        icon: const Icon(Icons.link),
                        label: const Text('Connect a device'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: IdSpacing.md),
            if (engine.jobs.isNotEmpty)
              SectionCard(
                title: 'Transfers this session',
                child: Column(
                  children: [
                    for (final j in engine.jobs.take(5))
                      ListenableBuilder(
                        listenable: j,
                        builder: (context, _) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          minTileHeight: IdLayout.minTouchTarget,
                          leading: Icon(
                            j.direction == JobDirection.sending
                                ? Icons.north_east
                                : Icons.south_west,
                          ),
                          title: Text(
                            '${j.direction == JobDirection.sending ? 'To' : 'From'} ${j.peerName}',
                          ),
                          subtitle: Text(
                            '${j.state.name} - ${(j.progress * 100).round()}% of ${formatBytes(j.totalBytes)}',
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => TransferScreen(job: j),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            SectionCard(
              title: 'Nearby devices',
              child: engine.nearby.isEmpty
                  ? StateMessage(
                      icon: Icons.wifi_find,
                      title: 'Looking for devices...',
                      message:
                          engine.discoveryError ??
                          'Open Isekai Drop on your other device, on the same Wi-Fi. '
                              'If it does not appear, use "Connect a device" and type its address.',
                    )
                  : Column(
                      children: [
                        for (final d in engine.nearby)
                          NearbyTile(
                            device: d,
                            onTap: () => d.trusted != null
                                ? onSend()
                                : startPairingFlow(context, d.host, d.port),
                          ),
                      ],
                    ),
            ),
            SectionCard(
              title: 'Saved trusted devices',
              trailing: TextButton(
                onPressed: onTrusted,
                child: const Text('Manage'),
              ),
              child: engine.trustedDevices.isEmpty
                  ? StateMessage(
                      icon: Icons.shield_outlined,
                      title: 'No trusted devices yet',
                      message: 'Pair a device to trust it.',
                      action: TextButton(
                        onPressed: onConnect,
                        child: const Text('Connect a device'),
                      ),
                    )
                  : Column(
                      children: [
                        for (final d in engine.trustedDevices)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            minTileHeight: IdLayout.minTouchTarget,
                            leading: Icon(platformIcon(d.platform)),
                            title: Text(d.name),
                            subtitle: TrustBadge(trust: trustOf(d)),
                          ),
                      ],
                    ),
            ),
            Text(
              'Files go directly between your devices, encrypted. Nothing is uploaded.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}
