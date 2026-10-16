import 'package:flutter/material.dart';

import '../../engine/transfer_engine.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';

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
              sending
                  ? 'Waiting for the other device to accept...'
                  : 'Starting...',
              IdColors.accentGlow,
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
                      if (!job.isActive)
                        Text('Time taken: ${_fmtDuration(job.elapsed)}'),
                      if (job.savedTo.isNotEmpty) ...[
                        const SizedBox(height: IdSpacing.sm),
                        Text('Saved to:', style: theme.textTheme.bodySmall),
                        for (final s in job.savedTo.take(10))
                          Text(s, style: theme.textTheme.bodySmall),
                      ],
                      const SizedBox(height: IdSpacing.lg),
                      Wrap(
                        spacing: IdSpacing.sm,
                        runSpacing: IdSpacing.sm,
                        children: [
                          Semantics(
                            label: 'Pause. Disabled. Pause and resume arrive in a later phase.',
                            excludeSemantics: true,
                            child: const OutlinedButton(
                              onPressed: null,
                              child: Text('Pause (later phase)'),
                            ),
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
                  'Keep Isekai Drop open and the screen on until it finishes.',
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
