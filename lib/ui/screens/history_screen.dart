import 'package:flutter/material.dart';

import '../../engine/transfer_engine.dart';
import '../app_scope.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Future<List<TransferRecord>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).engine.history();
  }

  void _reload() => setState(() {
    _future = AppScope.of(context).engine.history();
  });

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text(
          'All entries will be removed. Your files are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: IdColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await AppScope.of(context).engine.clearHistory();
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        const DemoBanner(),
        const SizedBox(height: IdSpacing.md),
        AsyncSection<List<TransferRecord>>(
          future: _future!,
          onRetry: _reload,
          isEmpty: (l) => l.isEmpty,
          empty: const StateMessage(
            icon: Icons.history,
            title: 'No transfers yet',
            message: 'Finished transfers will be listed here.',
          ),
          builder: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final t in list)
                Card(
                  child: ListTile(
                    minTileHeight: IdLayout.minTouchTarget,
                    leading: Icon(
                      t.direction == TransferDirection.sent
                          ? Icons.north_east
                          : Icons.south_west,
                    ),
                    title: Text(
                      '${t.direction == TransferDirection.sent ? 'Sent to' : 'Received from'} ${t.deviceName}',
                    ),
                    subtitle: Text(
                      '${t.outcome.label} - ${t.fileCount} file(s), ${formatBytes(t.totalBytes)}\n'
                      'Saved to: ${t.destination}\n${formatTime(t.createdAt)}',
                    ),
                    isThreeLine: true,
                    trailing: const DemoChip(),
                  ),
                ),
              const SizedBox(height: IdSpacing.sm),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: IdColors.danger,
                  minimumSize: const Size.fromHeight(IdLayout.minTouchTarget),
                ),
                onPressed: _clear,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear history'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
