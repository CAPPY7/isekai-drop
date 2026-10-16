import 'dart:async';

import 'package:flutter/material.dart';

import '../../engine/models.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';

enum _DemoState { running, paused, done, cancelled }

/// Sending/Receiving screen. In Phase 2 it plays a DEMO animation only.
/// No speed number is shown: only MEASURED speeds may ever be displayed.
class TransferScreen extends StatefulWidget {
  const TransferScreen({
    super.key,
    required this.fileCount,
    required this.totalBytes,
  });

  final int fileCount;
  final int totalBytes;

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  double _progress = 0;
  _DemoState _state = _DemoState.running;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {
        _progress = (_progress + 0.01).clamp(0, 1);
        if (_progress >= 1) {
          _state = _DemoState.done;
          _timer?.cancel();
        }
      });
    });
  }

  void _pauseResume() {
    setState(() {
      if (_state == _DemoState.running) {
        _timer?.cancel();
        _state = _DemoState.paused;
      } else if (_state == _DemoState.paused) {
        _state = _DemoState.running;
        _start();
      }
    });
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel this transfer?'),
        content: const Text('The DEMO transfer will stop.'),
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
    if (ok == true) {
      _timer?.cancel();
      setState(() => _state = _DemoState.cancelled);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = (widget.totalBytes * _progress).round();
    final pct = (_progress * 100).round();
    final (statusText, statusColor) = switch (_state) {
      _DemoState.running => ('Sending (DEMO)...', IdColors.accentGlow),
      _DemoState.paused => ('Paused (DEMO)', IdColors.warning),
      _DemoState.done => (
        'Finished (DEMO) - nothing was really sent',
        IdColors.success,
      ),
      _DemoState.cancelled => ('Cancelled (DEMO)', IdColors.danger),
    };
    final active = _state == _DemoState.running || _state == _DemoState.paused;
    return Scaffold(
      appBar: AppBar(title: const Text('Sending')),
      body: PageBody(
        children: [
          const DemoBanner(),
          const SizedBox(height: IdSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(IdSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'To: DEMO Pixel phone',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: IdSpacing.xs),
                  Text(
                    statusText,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(height: IdSpacing.md),
                  Semantics(
                    label: 'Progress $pct percent, DEMO',
                    excludeSemantics: true,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(IdRadii.pill),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 12,
                      ),
                    ),
                  ),
                  const SizedBox(height: IdSpacing.sm),
                  Text(
                    '$pct%   ${formatBytes(done)} of ${formatBytes(widget.totalBytes)}'
                    '   (${widget.fileCount} file(s))',
                  ),
                  const SizedBox(height: IdSpacing.xs),
                  Text(
                    'Speed and time left: not shown. Only real measured speeds are '
                    'ever shown, and this is not a real transfer.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: IdSpacing.lg),
                  Wrap(
                    spacing: IdSpacing.sm,
                    runSpacing: IdSpacing.sm,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(140, IdLayout.minTouchTarget),
                        ),
                        onPressed: active ? _pauseResume : null,
                        icon: Icon(
                          _state == _DemoState.paused
                              ? Icons.play_arrow
                              : Icons.pause,
                        ),
                        label: Text(
                          _state == _DemoState.paused ? 'Resume' : 'Pause',
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(140, IdLayout.minTouchTarget),
                          foregroundColor: IdColors.danger,
                        ),
                        onPressed: active ? _cancel : null,
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                      ),
                      if (!active)
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
        ],
      ),
    );
  }
}
