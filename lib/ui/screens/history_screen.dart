import 'package:flutter/material.dart';

import '../../engine/transfer_engine.dart';
import '../app_scope.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';

/// Real, saved transfer history (this device only). No file contents.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  Future<bool> _ask(BuildContext context, String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final history = scope.engine.history;
    if (history == null) {
      return const PageBody(
        children: [
          StateMessage(
            icon: Icons.history,
            title: 'History is not available',
            message: 'This device could not open its history file.',
          ),
        ],
      );
    }
    return ListenableBuilder(
      listenable: Listenable.merge([history, scope.settings]),
      builder: (context, _) {
        final list = history.entries;
        final showNames = scope.settings.historyFileNames;
        return PageBody(
          children: [
            Text(
              'Saved on this device only. File contents are never stored'
              '${showNames ? '; file names are (turn off in Settings)' : '; file names are not saved'}.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: IdSpacing.md),
            if (list.isEmpty)
              // 0.11.0 (spec A1): one line, not a whole card.
              const EmptyLine(
                icon: Icons.history,
                text: 'No transfers yet',
                info: 'Finished transfers will be listed here.',
              ),
            for (final t in list)
              Card(
                child: ExpansionTile(
                  minTileHeight: IdLayout.minTouchTarget,
                  leading: Icon(
                    t.direction == HistoryDirection.sent
                        ? Icons.north_east
                        : Icons.south_west,
                  ),
                  title: Text(
                    '${t.direction == HistoryDirection.sent ? 'Sent to' : 'Received from'} ${t.peerName}',
                  ),
                  subtitle: Text(
                    '${_outcome(t.outcome)} - ${t.fileCount} file(s), ${formatBytes(t.totalBytes)}\n'
                    '${formatTime(t.createdAt.toLocal())}',
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(
                    IdSpacing.md,
                    0,
                    IdSpacing.md,
                    IdSpacing.md,
                  ),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (t.message != null) Text(t.message!),
                    Text('Moved: ${formatBytes(t.bytesDone)}'),
                    if (t.resumedBytes > 0)
                      Text(
                        'Continued an earlier attempt: ${formatBytes(t.resumedBytes)} were already there.',
                      ),
                    if (t.destination != null)
                      Text('Saved to: ${t.destination}'),
                    if (showNames && t.fileNames.isNotEmpty) ...[
                      const SizedBox(height: IdSpacing.xs),
                      for (final n in t.fileNames.take(20))
                        Text('- $n', overflow: TextOverflow.ellipsis),
                      if (t.fileNames.length > 20)
                        Text('...and ${t.fileNames.length - 20} more'),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: idStatus(context).danger,
                        ),
                        onPressed: () async {
                          if (await _ask(
                            context,
                            'Delete this entry?',
                            'Only the history entry is removed. Your files are not deleted.',
                          )) {
                            await history.remove(t.id);
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete entry'),
                      ),
                    ),
                  ],
                ),
              ),
            if (list.isNotEmpty) ...[
              const SizedBox(height: IdSpacing.sm),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: idStatus(context).danger,
                  minimumSize: const Size.fromHeight(IdLayout.minTouchTarget),
                ),
                onPressed: () async {
                  if (await _ask(
                    context,
                    'Clear history?',
                    'All entries will be removed. Your files are not deleted.',
                  )) {
                    await history.clear();
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear history'),
              ),
            ],
          ],
        );
      },
    );
  }

  static String _outcome(HistoryOutcome o) => switch (o) {
    HistoryOutcome.completed => 'Completed',
    HistoryOutcome.failed => 'Failed',
    HistoryOutcome.cancelled => 'Cancelled',
  };
}
