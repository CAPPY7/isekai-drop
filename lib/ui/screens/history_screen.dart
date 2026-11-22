import 'package:flutter/material.dart';

import '../../engine/transfer_engine.dart';
import '../app_scope.dart';
import '../file_actions.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';
import '../../l10n/l10n.dart';

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
            child: Text(tr(context).cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr(context).delete),
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
      return PageBody(
        children: [
          StateMessage(
            icon: Icons.history,
            title: tr(context).historyUnavailable,
            message: tr(context).historyUnavailableBody,
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
              showNames
                  ? tr(context).historyNoteNames
                  : tr(context).historyNoteNoNames,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: IdSpacing.md),
            if (list.isEmpty)
              // 0.11.0 (spec A1): one line, not a whole card.
              EmptyLine(
                icon: Icons.history,
                text: tr(context).noTransfers,
                info: tr(context).noTransfersInfo,
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
                    t.direction == HistoryDirection.sent
                        ? tr(context).sentTo(t.peerName)
                        : tr(context).receivedFrom(t.peerName),
                  ),
                  subtitle: Text(
                    '${tr(context).historyLine(_outcome(tr(context), t.outcome), '${t.fileCount}', formatBytes(t.totalBytes))}\n'
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
                    Text(tr(context).moved(formatBytes(t.bytesDone))),
                    if (t.resumedBytes > 0)
                      Text(
                        tr(context)
                            .continuedEarlier(formatBytes(t.resumedBytes)),
                      ),
                    if (t.destination != null)
                      Text(tr(context).savedTo(t.destination ?? '')),
                    if (showNames && t.fileNames.isNotEmpty) ...[
                      const SizedBox(height: IdSpacing.xs),
                      for (final n in t.fileNames.take(20))
                        Text('- $n', overflow: TextOverflow.ellipsis),
                      if (t.fileNames.length > 20)
                        Text(tr(context).andMore('${t.fileNames.length - 20}')),
                    ],
                    // D4: the folder received files went to.
                    if (t.direction == HistoryDirection.received &&
                        t.destination != null &&
                        savedFileActions.canOpen)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, IdLayout.minTouchTarget),
                          ),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            final failText = tr(context).folderNotOpened;
                            if (!await savedFileActions.openFolder(
                              t.destination!,
                            )) {
                              messenger.showSnackBar(
                                SnackBar(content: Text(failText)),
                              );
                            }
                          },
                          icon: const Icon(Icons.folder_open),
                          label: Text(tr(context).showFolder),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: idStatus(context).danger,
                        ),
                        onPressed: () async {
                          if (await _ask(
                            context,
                            tr(context).deleteEntryTitle,
                            tr(context).deleteEntryBody,
                          )) {
                            await history.remove(t.id);
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: Text(tr(context).deleteEntry),
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
                    tr(context).clearHistoryTitle,
                    tr(context).clearHistoryBody,
                  )) {
                    await history.clear();
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: Text(tr(context).clearHistory),
              ),
            ],
          ],
        );
      },
    );
  }

  static String _outcome(AppLocalizations l, HistoryOutcome o) => switch (o) {
    HistoryOutcome.completed => l.outcomeCompleted,
    HistoryOutcome.failed => l.outcomeFailed,
    HistoryOutcome.cancelled => l.outcomeCancelled,
  };
}
