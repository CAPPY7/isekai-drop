import 'package:flutter/material.dart';

import '../../engine/transfer_engine.dart';
import '../app_scope.dart';
import '../diag_report.dart' show kAppVersion;
import '../pairing_flow.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';
import '../widgets/device_widgets.dart';
import '../widgets/discovery_hint.dart';
import '../widgets/wifi_band.dart';
import '../../engine/platform_engine.dart' show ConnectionInfo;
import 'transfer_screen.dart';
import '../../l10n/l10n.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onSend,
    required this.onConnect,
    required this.onTrusted,
    this.networkLoad,
  });

  /// For tests (see [NetworkStatusLine]).
  final Future<ConnectionInfo> Function()? networkLoad;

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
            // 0.11.0 (spec B10): network status first.
            NetworkStatusLine(load: networkLoad),
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
                    ready ? tr(context).ready : tr(context).notReady,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: IdTypeSizes.headline,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    ready
                        ? tr(context).homeReadyHelp
                        : (engine.startError ?? tr(context).starting),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: IdSpacing.md),
                  // 0.11.0 (spec A3): one primary action (Send) and one
                  // secondary (Connect a device). No other "Connect a
                  // device" links elsewhere.
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
                        label: Text(tr(context).navSend),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                          minimumSize: const Size(140, IdLayout.minTouchTarget),
                        ),
                        onPressed: onConnect,
                        icon: const Icon(Icons.link),
                        label: Text(tr(context).connectDevice),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: IdSpacing.md),
            if (engine.interruptedSends.isNotEmpty)
              SectionCard(
                title: tr(context).interruptedSends,
                child: Column(
                  children: [
                    for (final s in engine.interruptedSends)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        minTileHeight: IdLayout.minTouchTarget,
                        leading: const Icon(Icons.restore),
                        title: Text(tr(context).toName(s.peerName)),
                        subtitle: Text(
                          tr(context).didNotFinish(
                            '${s.fileCount}',
                            formatBytes(s.totalBytes),
                          ),
                        ),
                        trailing: Wrap(
                          children: [
                            TextButton(
                              onPressed: () async {
                                final messenger = ScaffoldMessenger.of(context);
                                final failText = tr(context).cannotRetry;
                                final j = await engine.retrySaved(s.id);
                                if (j == null) {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(failText)),
                                  );
                                }
                              },
                              child: Text(tr(context).retry),
                            ),
                            TextButton(
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: Text(tr(context).removeSendTitle),
                                    content: Text(tr(context).removeSendBody),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(c, false),
                                        child: Text(tr(context).cancel),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(c, true),
                                        child: Text(tr(context).remove),
                                      ),
                                    ],
                                  ),
                                );
                                if (ok == true) await engine.removeSaved(s.id);
                              },
                              child: Text(tr(context).remove),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            if (engine.jobs.isNotEmpty)
              SectionCard(
                title: tr(context).transfersThisSession,
                trailing: engine.jobs.any((j) => !j.isActive)
                    ? TextButton(
                        onPressed: engine.clearFinishedJobs,
                        child: Text(tr(context).clearFinished),
                      )
                    : null,
                child: Column(
                  children: [
                    for (final j in engine.jobs.take(8))
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
                            j.direction == JobDirection.sending
                                ? tr(context).toName(j.peerName)
                                : tr(context).fromName(j.peerName),
                          ),
                          subtitle: Text(
                            '${tr(context).jobProgress(jobStatusLabel(j), '${(j.progress * 100).round()}', formatBytes(j.totalBytes))}'
                            '${j.state == JobState.failed && j.message != null ? '\n${j.message}' : ''}',
                          ),
                          trailing: j.canRetry
                              ? TextButton(
                                  onPressed: () => engine.retry(j),
                                  child: Text(tr(context).retry),
                                )
                              : null,
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
            if (engine.secureStorageNote?.contains('NEW key') ?? false)
              SectionCard(
                key: const ValueKey('own-key-new'),
                title: tr(context).newKeyTitle,
                child: Text(engine.secureStorageNote!),
              ),
            if (engine.rejectedPeer case final r?)
              SectionCard(
                key: const ValueKey('rejected-peer'),
                title: tr(context).needsPairingAgain,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(context).rejectedPeerBody(r.name, r.pairedName)),
                    const SizedBox(height: IdSpacing.sm),
                    Wrap(
                      spacing: IdSpacing.sm,
                      children: [
                        FilledButton(
                          key: const ValueKey('rejected-peer-pair'),
                          onPressed: () {
                            final n = engine.nearby
                                .where((d) => d.deviceId == r.nearbyId)
                                .firstOrNull;
                            engine.dismissRejectedPeer();
                            if (n != null) {
                              startPairingFlow(
                                context,
                                n.host,
                                n.port,
                                peerName: n.name,
                              );
                            }
                          },
                          child: Text(tr(context).pairAgain),
                        ),
                        TextButton(
                          onPressed: engine.dismissRejectedPeer,
                          child: Text(tr(context).notNow),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            SectionCard(
              title: tr(context).nearbyDevices,
              child: engine.nearby.isEmpty
                  ? DiscoveryHint(engine: engine)
                  : Column(
                      children: [
                        for (final d in engine.nearby)
                          NearbyTile(
                            device: d,
                            onTap: () => trustOfNearby(d).canSend
                                ? onSend()
                                : startPairingFlow(
                                    context,
                                    d.host,
                                    d.port,
                                    peerName: d.name,
                                  ),
                          ),
                      ],
                    ),
            ),
            // 0.11.0: hidden while empty (pairing lives in the Connect tab).
            if (engine.trustedDevices.isNotEmpty)
              SectionCard(
                title: tr(context).savedTrusted,
                trailing: TextButton(
                  onPressed: onTrusted,
                  child: Text(tr(context).manage),
                ),
                child: Column(
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
              tr(context).homeFooter,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            // 0.11.2: the version, so a report or photo shows which build runs.
            Text(
              tr(context).appVersion(kAppVersion),
              key: const Key('home-version'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}
