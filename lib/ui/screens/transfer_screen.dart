import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/platform_engine.dart' show canShareFiles, shareFiles;
import '../../engine/transfer_engine.dart';
import '../app_scope.dart';
import '../file_actions.dart';
import '../shell_nav.dart';
import 'benchmark_screen.dart' show saveJobAsBenchmark;
import '../theme/design_tokens.dart';
import '../widgets/common.dart';
import '../widgets/transfer_parts.dart';
import '../widgets/wifi_band.dart';

String _fmtDuration(Duration d) {
  if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
  if (d.inMinutes > 0) return '${d.inMinutes} min ${d.inSeconds % 60} s';
  return '${d.inSeconds} s';
}

/// Live view of a REAL transfer. Speed and time left come only from
/// measured bytes over time; nothing is estimated in advance.
///
/// 0.11.0 (spec C11/C13/C14): file name, big percent, live speed with a
/// small chart, time left, a route chip ("Router · 5 GHz"), large
/// Pause / Cancel; a finished view (check, names, average speed, Open /
/// Show in folder / Send more); errors as problem + fix + Retry + Details.
class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key, required this.job, this.localLink});

  final TransferJob job;

  /// This device's link for the route chip ("5 GHz", "Ethernet"). Null:
  /// read it from the platform (Android, Windows).
  final Future<String?> Function()? localLink;

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final List<double> _speeds = [];
  Timer? _sampler;
  String? _link;
  JobState? _lastState;

  TransferJob get job => widget.job;

  @override
  void initState() {
    super.initState();
    _lastState = job.state;
    job.addListener(_onJob);
    if (job.isActive) {
      _sampler = Timer.periodic(const Duration(seconds: 1), (_) => _sample());
    }
    (widget.localLink ?? localLinkLabel)().then((v) {
      if (mounted && v != null) setState(() => _link = v);
    });
  }

  void _sample() {
    if (!mounted) return;
    if (!job.isActive) {
      _sampler?.cancel();
      return;
    }
    if (job.state != JobState.running || job.paused || job.pausedByPeer) {
      return;
    }
    final s = job.currentSpeed;
    if (s == null) return;
    setState(() {
      _speeds.add(s);
      if (_speeds.length > 30) _speeds.removeAt(0);
    });
  }

  void _onJob() {
    final s = job.state;
    if (s == _lastState) return;
    _lastState = s;
    // Spec D22: a short buzz when it ends.
    if (s == JobState.completed) {
      HapticFeedback.mediumImpact();
    } else if (s == JobState.failed) {
      HapticFeedback.heavyImpact();
    }
    if (!job.isActive) _sampler?.cancel();
  }

  @override
  void dispose() {
    job.removeListener(_onJob);
    _sampler?.cancel();
    super.dispose();
  }

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

  Future<void> _retry(BuildContext context) async {
    final nav = Navigator.of(context);
    final next = await AppScope.of(context).engine.retry(job);
    if (next != null) {
      nav.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => TransferScreen(job: next)),
      );
    }
  }

  void _sendMore(BuildContext context) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    shellTabRequest.value = ShellTab.send;
  }

  @override
  Widget build(BuildContext context) {
    final sending = job.direction == JobDirection.sending;
    return Scaffold(
      appBar: AppBar(title: Text(sending ? 'Sending' : 'Receiving')),
      body: ListenableBuilder(
        listenable: job,
        builder: (context, _) {
          final body = switch (job.state) {
            JobState.completed => _finished(context),
            JobState.failed when job.message != 'Cancelled' => _failed(context),
            JobState.failed || JobState.cancelled => _cancelled(context),
            _ => _active(context),
          };
          return PageBody(children: body);
        },
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final sending = job.direction == JobDirection.sending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          jobTitle(job.fileNames, job.fileCount),
          key: const ValueKey('transfer-title'),
          style: theme.textTheme.titleLarge,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: IdSpacing.xs),
        Text(
          '${sending ? 'To' : 'From'} ${job.peerName} · '
          '${formatBytes(job.totalBytes)}',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget? _chip() {
    final text = routeChipText(job.route, job.routeDetail, _link);
    if (text == null) return null;
    return RouteChip(
      text: text,
      direct: job.route != null && job.route != LinkRoute.router,
    );
  }

  List<Widget> _active(BuildContext context) {
    final theme = Theme.of(context);
    final status = idStatus(context);
    final pct = (job.progress * 100).floor();
    final left = job.timeLeft;
    final speed = job.currentSpeed;
    final still = MediaQuery.maybeDisableAnimationsOf(context) == true;
    final (
      String statusText,
      Color? color,
      IconData? icon,
    ) = switch (job.state) {
      JobState.waiting => (
        job.queued
            ? 'In the queue - waits for the current send to finish'
            : job.direction == JobDirection.sending
            ? 'Waiting for the other device to accept...'
            : 'Starting...',
        null,
        Icons.hourglass_empty,
      ),
      _ when job.paused => ('Paused', status.warning, Icons.pause_circle),
      _ when job.pausedByPeer => (
        'Paused by the other device',
        status.warning,
        Icons.pause_circle,
      ),
      _ when job.stalled => (
        'Waiting - no data for a few seconds',
        status.warning,
        Icons.hourglass_bottom,
      ),
      _ => ('', null, null),
    };
    final chip = _chip();
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(IdSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context),
              if (chip != null) ...[const SizedBox(height: IdSpacing.sm), chip],
              if (job.route != null && job.routeNote != null) ...[
                const SizedBox(height: IdSpacing.xs),
                Text(job.routeNote!, style: theme.textTheme.bodySmall),
              ],
              const SizedBox(height: IdSpacing.lg),
              Semantics(
                container: true,
                label: 'Progress $pct percent',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$pct%',
                      key: const ValueKey('transfer-percent'),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: IdSpacing.sm),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(IdRadii.pill),
                      child: job.state == JobState.waiting
                          ? const LinearProgressIndicator(minHeight: 12)
                          : TweenAnimationBuilder<double>(
                              // Spec E24: progress glides, not jumps.
                              tween: Tween(end: job.progress),
                              duration: still
                                  ? Duration.zero
                                  : const Duration(milliseconds: 400),
                              builder: (_, v, _) => LinearProgressIndicator(
                                value: v,
                                minHeight: 12,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: IdSpacing.sm),
              Text(
                '${formatBytes(job.bytesDone)} of ${formatBytes(job.totalBytes)}'
                ' · ${job.filesDone} of ${job.fileCount} files verified',
                style: theme.textTheme.bodyMedium,
              ),
              if (statusText.isNotEmpty) ...[
                const SizedBox(height: IdSpacing.sm),
                Row(
                  children: [
                    Icon(icon, size: 20, color: color),
                    const SizedBox(width: IdSpacing.sm),
                    Expanded(
                      child: Text(
                        statusText,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: IdSpacing.md),
              Wrap(
                spacing: IdSpacing.lg,
                runSpacing: IdSpacing.sm,
                children: [
                  _Stat(
                    label: 'Speed',
                    value: speed == null ? 'measuring...' : formatSpeed(speed),
                    valueKey: 'transfer-speed',
                  ),
                  _Stat(
                    label: 'Time left',
                    value: left == null ? '-' : _fmtDuration(left),
                  ),
                ],
              ),
              if (_speeds.length >= 2) ...[
                const SizedBox(height: IdSpacing.sm),
                SpeedSparkline(values: List.of(_speeds)),
              ],
              // 0.9.2: 2.4 GHz hint for the router Wi-Fi (Android).
              if (job.route == null || job.route == LinkRoute.router)
                const WifiBandLine(),
              if (job.resumedBytes > 0)
                Text(
                  'Continued an earlier attempt: ${formatBytes(job.resumedBytes)} '
                  'were already on the receiver (not counted in speed).',
                  style: theme.textTheme.bodySmall,
                ),
              const SizedBox(height: IdSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('transfer-pause'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 56),
                      ),
                      onPressed: !job.canPause
                          ? null
                          : job.paused
                          ? job.resume
                          : job.pause,
                      icon: Icon(job.paused ? Icons.play_arrow : Icons.pause),
                      label: Text(job.paused ? 'Resume' : 'Pause'),
                    ),
                  ),
                  // Spec D15: well apart, so Cancel is not hit by mistake.
                  const SizedBox(width: IdSpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('transfer-cancel'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 56),
                        foregroundColor: status.danger,
                      ),
                      onPressed: () => _cancel(context),
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      Text(
        'Keep Isekai Drop open on both devices until it finishes. '
        'Pause keeps the connection; closing the app stops the transfer.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall,
      ),
    ];
  }

  List<Widget> _finished(BuildContext context) {
    final theme = Theme.of(context);
    final sending = job.direction == JobDirection.sending;
    final avg = job.averageSpeed;
    final names = job.fileNames.isNotEmpty
        ? job.fileNames
        : [for (final s in job.savedTo) s.split(RegExp(r'[\\/]')).last];
    final desktopFiles =
        !sending && canOpenSavedFiles && job.savedTo.isNotEmpty;
    final chip = _chip();
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(IdSpacing.lg),
          child: Column(
            children: [
              const SuccessCheck(),
              const SizedBox(height: IdSpacing.sm),
              Text(
                sending ? 'Sent' : 'Received',
                style: theme.textTheme.headlineSmall,
              ),
              Text(
                '${job.fileCount} file${job.fileCount == 1 ? '' : 's'} · '
                '${formatBytes(job.totalBytes)} · '
                '${sending ? 'to' : 'from'} ${job.peerName}',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: IdSpacing.md),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final n in names.take(5))
                      Text(
                        n,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    if (names.length > 5)
                      Text(
                        '+ ${names.length - 5} more',
                        style: theme.textTheme.bodySmall,
                      ),
                    const SizedBox(height: IdSpacing.sm),
                    Text(
                      'Average speed: ${avg == null ? '-' : formatSpeed(avg)}'
                      ' · ${_fmtDuration(job.elapsed)}',
                      key: const ValueKey('transfer-average'),
                    ),
                    if (chip != null) ...[
                      const SizedBox(height: IdSpacing.sm),
                      chip,
                    ],
                    if (!sending && job.savedTo.isNotEmpty) ...[
                      const SizedBox(height: IdSpacing.sm),
                      Text(
                        'Saved to: ${job.savedTo.first}'
                        '${job.savedTo.length > 1 ? ' (+${job.savedTo.length - 1})' : ''}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: IdSpacing.lg),
              Wrap(
                spacing: IdSpacing.sm,
                runSpacing: IdSpacing.sm,
                alignment: WrapAlignment.center,
                children: [
                  if (desktopFiles && job.savedTo.length == 1)
                    _btn(
                      'Open',
                      Icons.open_in_new,
                      () => openSavedFile(job.savedTo.first),
                    ),
                  if (desktopFiles)
                    _btn(
                      'Show in folder',
                      Icons.folder_open,
                      () => showSavedInFolder(job.savedTo.first),
                    ),
                  if (canShareFiles && job.savedTo.isNotEmpty)
                    _btn(
                      'Share / Save to Files',
                      Icons.ios_share,
                      () => shareFiles(job.savedTo),
                    ),
                  if (benchmarkBlocker(job) == null)
                    _btn(
                      'Save as benchmark run',
                      Icons.speed,
                      () => saveJobAsBenchmark(context, job),
                    ),
                  FilledButton.icon(
                    key: const ValueKey('transfer-send-more'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(140, IdLayout.minTouchTarget),
                    ),
                    onPressed: () => _sendMore(context),
                    icon: const Icon(Icons.send),
                    label: const Text('Send more'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      if (job.resumedBytes > 0)
        Text(
          'Continued an earlier attempt: ${formatBytes(job.resumedBytes)} '
          'were already on the receiver (not counted in speed).',
          style: theme.textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
    ];
  }

  Widget _btn(String label, IconData icon, VoidCallback onTap) =>
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(140, IdLayout.minTouchTarget),
        ),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
      );

  List<Widget> _failed(BuildContext context) {
    final theme = Theme.of(context);
    final (problem, fix) = splitProblem(job.message ?? 'The transfer failed.');
    final engine = AppScope.of(context).engine;
    final codes = [
      for (final e in engine.diagLog.entries)
        if (!e.at.toUtc().isBefore(job.createdAt)) e,
    ];
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(IdSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: idStatus(context).danger,
                    size: 32,
                  ),
                  const SizedBox(width: IdSpacing.sm),
                  Expanded(
                    child: Text(
                      job.direction == JobDirection.sending
                          ? 'Not sent'
                          : 'Not received',
                      style: theme.textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: IdSpacing.sm),
              _header(context),
              const SizedBox(height: IdSpacing.md),
              Text(
                problem,
                key: const ValueKey('error-problem'),
                style: theme.textTheme.titleMedium,
              ),
              if (fix != null) ...[
                const SizedBox(height: IdSpacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline, size: 20),
                    const SizedBox(width: IdSpacing.sm),
                    Expanded(
                      child: Text(fix, key: const ValueKey('error-fix')),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: IdSpacing.lg),
              Wrap(
                spacing: IdSpacing.sm,
                runSpacing: IdSpacing.sm,
                children: [
                  if (job.canRetry)
                    FilledButton.icon(
                      key: const ValueKey('transfer-retry'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(140, IdLayout.minTouchTarget),
                      ),
                      onPressed: () => _retry(context),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  _btn('Close', Icons.close, () => Navigator.of(context).pop()),
                ],
              ),
              const SizedBox(height: IdSpacing.sm),
              ExpansionTile(
                key: const ValueKey('error-details'),
                tilePadding: EdgeInsets.zero,
                title: const Text('Details'),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SelectableText(
                      [
                        'Message: ${job.message ?? '-'}',
                        if (job.routeLine != null) 'Route: ${job.routeLine}',
                        if (job.routeNote != null)
                          'Route note: ${job.routeNote}',
                        'Moved: ${formatBytes(job.bytesDone)} of '
                            '${formatBytes(job.totalBytes)}, '
                            '${job.filesDone} of ${job.fileCount} files verified',
                        'Time: ${_fmtDuration(job.elapsed)}',
                        if (codes.isEmpty) 'Codes: none recorded',
                        for (final e in codes.take(5)) 'Code: ${e.kind}',
                      ].join('\n'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ];
  }

  List<Widget> _cancelled(BuildContext context) {
    final theme = Theme.of(context);
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(IdSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.cancel_outlined, color: idStatus(context).warning),
                  const SizedBox(width: IdSpacing.sm),
                  Text('Cancelled', style: theme.textTheme.headlineSmall),
                ],
              ),
              const SizedBox(height: IdSpacing.sm),
              _header(context),
              const SizedBox(height: IdSpacing.sm),
              const Text('Unfinished files were not kept.'),
              const SizedBox(height: IdSpacing.lg),
              Wrap(
                spacing: IdSpacing.sm,
                runSpacing: IdSpacing.sm,
                children: [
                  if (job.canRetry)
                    FilledButton.icon(
                      key: const ValueKey('transfer-retry'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(140, IdLayout.minTouchTarget),
                      ),
                      onPressed: () => _retry(context),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Send again'),
                    ),
                  _btn('Close', Icons.close, () => Navigator.of(context).pop()),
                ],
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.valueKey});

  final String label;
  final String value;
  final String? valueKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.bodySmall),
          Text(
            value,
            key: valueKey == null ? null : ValueKey<String>(valueKey!),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
