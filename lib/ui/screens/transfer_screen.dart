import 'package:flutter/material.dart';

import '../../engine/platform_engine.dart' show canShareFiles, shareFiles;
import '../../engine/transfer_engine.dart';
import '../app_scope.dart';
import 'benchmark_screen.dart' show saveJobAsBenchmark;
import '../theme/design_tokens.dart';
import '../widgets/common.dart';
import '../widgets/wifi_band.dart';

String _fmtDuration(Duration d) {
  if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
  if (d.inMinutes > 0) return '${d.inMinutes} min ${d.inSeconds % 60} s';
  return '${d.inSeconds} s';
}

/// Live view of a REAL transfer. Speed and time left come only from
/// measured bytes over time; nothing is estimated in advance.
class TransferScreen extends StatelessWidget {
  const TransferScreen({super.key, required this.job});

  final TransferJob job;

  Future<void> _cancel(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel this transfer?'),
        content: const Text(
          'Files not yet finished and verified will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Cancel transfer'),
          ),
        ],
      ),
    );
    if (ok == true) job.cancel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sending = job.direction == JobDirection.sending;
    return Scaffold(
      appBar: AppBar(title: Text(sending ? 'Sending' : 'Receiving')),
      body: ListenableBuilder(
        listenable: job,
        builder: (context, _) {
          final pct = (job.progress * 100).floor();
          final speed = job.state == JobState.running
              ? job.currentSpeed
              : job.averageSpeed;
          final left = job.timeLeft;
          final (statusText, color) = switch (job.state) {
            JobState.waiting => (
              job.queued
                  ? 'In the queue - waits for the current send to finish'
                  : sending
                  ? 'Waiting for the other device to accept...'
                  : 'Starting...',
              IdColors.accentGlow,
            ),
            JobState.running when job.paused => ('Paused', IdColors.warning),
            JobState.running when job.pausedByPeer => (
              'Paused by the other device',
              IdColors.warning,
            ),
            JobState.running when job.stalled => (
              'Waiting - no data for a few seconds (the other device may have paused)',
              IdColors.warning,
            ),
            JobState.running => (
              sending ? 'Sending...' : 'Receiving...',
              IdColors.accentGlow,
            ),
            JobState.completed => ('Done', IdColors.success),
            JobState.failed => ('Failed', IdColors.danger),
            JobState.cancelled => ('Cancelled', IdColors.warning),
          };
          return PageBody(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(IdSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${sending ? 'To' : 'From'}: ${job.peerName}',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: IdSpacing.xs),
                      Text(
                        statusText,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: color,
                        ),
                      ),
                      if (job.message != null) ...[
                        const SizedBox(height: IdSpacing.xs),
                        Text(job.message!),
                      ],
                      const SizedBox(height: IdSpacing.md),
                      Semantics(
                        label: 'Progress $pct percent',
                        excludeSemantics: true,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(IdRadii.pill),
                          child: LinearProgressIndicator(
                            value: job.state == JobState.waiting
                                ? null
                                : job.progress,
                            minHeight: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: IdSpacing.sm),
                      Text(
                        '$pct%   ${formatBytes(job.bytesDone)} of ${formatBytes(job.totalBytes)}',
                      ),
                      Text(
                        'Files: ${job.filesDone} of ${job.fileCount} verified',
                      ),
                      const SizedBox(height: IdSpacing.xs),
                      Text(
                        speed == null
                            ? 'Speed: measuring...'
                            : '${job.state == JobState.running ? 'Speed (measured)' : 'Average speed (measured)'}: ${formatSpeed(speed)}',
                      ),
                      if (left != null)
                        Text(
                          'Time left (from measured speed): ${_fmtDuration(left)}',
                        ),
                      // 0.9.2: band + link speed, hint on 2.4 GHz.
                      const WifiBandLine(),
                      if (!job.isActive)
                        Text('Time taken: ${_fmtDuration(job.elapsed)}'),
                      if (job.resumedBytes > 0)
                        Text(
                          'Continued an earlier attempt: ${formatBytes(job.resumedBytes)} were already on the receiver (not counted in speed).',
                        ),
                      if (job.savedTo.isNotEmpty) ...[
                        const SizedBox(height: IdSpacing.sm),
                        Text('Saved to:', style: theme.textTheme.bodySmall),
                        for (final s in job.savedTo.take(10))
                          Text(s, style: theme.textTheme.bodySmall),
                        if (canShareFiles && !job.isActive)
                          TextButton.icon(
                            onPressed: () => shareFiles(job.savedTo),
                            icon: const Icon(Icons.ios_share),
                            label: const Text('Share / Save to Files'),
                          ),
                      ],
                      const SizedBox(height: IdSpacing.lg),
                      Wrap(
                        spacing: IdSpacing.sm,
                        runSpacing: IdSpacing.sm,
                        children: [
                          if (job.isActive)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(
                                  140,
                                  IdLayout.minTouchTarget,
                                ),
                              ),
                              onPressed: !job.canPause
                                  ? null
                                  : job.paused
                                  ? job.resume
                                  : job.pause,
                              icon: Icon(
                                job.paused ? Icons.play_arrow : Icons.pause,
                              ),
                              label: Text(job.paused ? 'Resume' : 'Pause'),
                            ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(
                                140,
                                IdLayout.minTouchTarget,
                              ),
                              foregroundColor: IdColors.danger,
                            ),
                            onPressed: job.isActive
                                ? () => _cancel(context)
                                : null,
                            icon: const Icon(Icons.close),
                            label: const Text('Cancel'),
                          ),
                          if (!job.isActive && benchmarkBlocker(job) == null)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(
                                  140,
                                  IdLayout.minTouchTarget,
                                ),
                              ),
                              onPressed: () => saveJobAsBenchmark(context, job),
                              icon: const Icon(Icons.speed),
                              label: const Text('Save as benchmark run'),
                            ),
                          if (job.canRetry)
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(
                                  140,
                                  IdLayout.minTouchTarget,
                                ),
                              ),
                              onPressed: () async {
                                final nav = Navigator.of(context);
                                final next = await AppScope.of(context).engine
                                    .retry(job);
                                if (next != null) {
                                  nav.pushReplacement(
                                    MaterialPageRoute<void>(
                                      builder: (_) => TransferScreen(job: next),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          if (!job.isActive)
                            FilledButton(
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(
                                  140,
                                  IdLayout.minTouchTarget,
                                ),
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Done'),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (job.isActive)
                Text(
                  'Keep Isekai Drop open on both devices until it finishes. '
                  'Pause keeps the connection; closing the app stops the transfer.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
            ],
          );
        },
      ),
    );
  }
}
