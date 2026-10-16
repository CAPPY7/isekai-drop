import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/platform_engine.dart' show exportBenchmarkCsv;
import '../../engine/transfer_engine.dart';
import '../app_scope.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';

const kFileSets = ['100MB', '1GB', '5GB', '1000small', 'other'];
const kConnections = [
  'home Wi-Fi router',
  'Android app hotspot',
  'Windows Mobile Hotspot',
  'iPhone Personal Hotspot',
  'other',
];
const kBands = ['unknown', '2.4 GHz', '5 GHz', '6 GHz'];
const kPlatforms = ['android', 'ios', 'windows', 'macos', 'linux'];

/// Test conditions typed by the user. Contains no names.
class BenchConditions {
  String fileSet = '1GB';
  String connection = kConnections.first;
  String band = 'unknown';
  int? linkMbps;
  double? distanceM;
  String note = '';
}

/// Median of [v] (v must not be empty).
double median(List<double> v) {
  final s = [...v]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
}

class _ConditionsFields extends StatefulWidget {
  const _ConditionsFields({required this.c});
  final BenchConditions c;
  @override
  State<_ConditionsFields> createState() => _ConditionsFieldsState();
}

class _ConditionsFieldsState extends State<_ConditionsFields> {
  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: c.fileSet,
          decoration: const InputDecoration(labelText: 'File set'),
          items: [
            for (final f in kFileSets)
              DropdownMenuItem(value: f, child: Text(f)),
          ],
          onChanged: (v) => setState(() => c.fileSet = v!),
        ),
        DropdownButtonFormField<String>(
          initialValue: c.connection,
          decoration: const InputDecoration(labelText: 'Connection'),
          items: [
            for (final f in kConnections)
              DropdownMenuItem(value: f, child: Text(f)),
          ],
          onChanged: (v) => setState(() => c.connection = v!),
        ),
        DropdownButtonFormField<String>(
          initialValue: c.band,
          decoration: const InputDecoration(labelText: 'Wi-Fi band'),
          items: [
            for (final f in kBands) DropdownMenuItem(value: f, child: Text(f)),
          ],
          onChanged: (v) => setState(() => c.band = v!),
        ),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Wi-Fi link speed (Mbps, from the system Wi-Fi details)',
          ),
          keyboardType: TextInputType.number,
          onChanged: (v) => c.linkMbps = int.tryParse(v.trim()),
        ),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Distance between devices (m)',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (v) => c.distanceM = double.tryParse(v.trim()),
        ),
        TextField(
          decoration: const InputDecoration(
            labelText: 'Note (no names or personal data)',
          ),
          maxLength: 80,
          onChanged: (v) => c.note = v.trim(),
        ),
      ],
    );
  }
}

/// "Save as benchmark run" for a finished Isekai Drop transfer.
Future<void> saveJobAsBenchmark(BuildContext context, TransferJob job) async {
  final engine = AppScope.of(context).engine;
  final store = engine.benchmarks;
  final messenger = ScaffoldMessenger.of(context);
  final why = benchmarkBlocker(job);
  if (store == null || why != null) {
    messenger.showSnackBar(
      SnackBar(content: Text(why ?? 'Benchmark log unavailable.')),
    );
    return;
  }
  final c = BenchConditions();
  final ok = await showDialog<bool>(
    context: context,
    builder: (d) => AlertDialog(
      title: const Text('Save as benchmark run'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Measured by the app: ${formatBytes(job.totalBytes)} in '
              '${(job.elapsed.inMilliseconds / 1000).toStringAsFixed(2)} s. '
              'No file names are saved.',
            ),
            _ConditionsFields(c: c),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(d, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(d, true),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  await store.add(
    BenchmarkStore.fromJob(
      job,
      thisPlatform: engine.platformName,
      otherPlatform: job.peerPlatform.isEmpty ? 'unknown' : job.peerPlatform,
      fileSet: c.fileSet,
      connection: c.connection,
      wifiBand: c.band,
      linkMbps: c.linkMbps,
      distanceM: c.distanceM,
      note: c.note,
    ),
  );
  messenger.showSnackBar(const SnackBar(content: Text('Benchmark run saved')));
}

class BenchmarkScreen extends StatelessWidget {
  const BenchmarkScreen({super.key});

  Future<void> _addManual(BuildContext context, BenchmarkStore store) async {
    final c = BenchConditions();
    var app = 'LocalSend';
    var sender = 'android';
    var receiver = 'windows';
    var direction = 'send';
    var verified = false;
    final count = TextEditingController(text: '1');
    final mb = TextEditingController();
    final secs = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: const Text('Add a run timed by hand'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'For LocalSend (or any run not measured by this app). '
                  'Use a stopwatch from tapping Send until both screens say done.',
                ),
                DropdownButtonFormField<String>(
                  initialValue: app,
                  decoration: const InputDecoration(labelText: 'App'),
                  items: const [
                    DropdownMenuItem(
                      value: 'LocalSend',
                      child: Text('LocalSend'),
                    ),
                    DropdownMenuItem(
                      value: 'Isekai Drop',
                      child: Text('Isekai Drop'),
                    ),
                  ],
                  onChanged: (v) => set(() => app = v!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: sender,
                  decoration: const InputDecoration(labelText: 'Sender'),
                  items: [
                    for (final p in kPlatforms)
                      DropdownMenuItem(value: p, child: Text(platformLabel(p))),
                  ],
                  onChanged: (v) => set(() => sender = v!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: receiver,
                  decoration: const InputDecoration(labelText: 'Receiver'),
                  items: [
                    for (final p in kPlatforms)
                      DropdownMenuItem(value: p, child: Text(platformLabel(p))),
                  ],
                  onChanged: (v) => set(() => receiver = v!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: direction,
                  decoration: const InputDecoration(labelText: 'This device'),
                  items: const [
                    DropdownMenuItem(value: 'send', child: Text('sent')),
                    DropdownMenuItem(value: 'receive', child: Text('received')),
                    DropdownMenuItem(value: 'other', child: Text('neither')),
                  ],
                  onChanged: (v) => set(() => direction = v!),
                ),
                TextField(
                  controller: count,
                  decoration: const InputDecoration(
                    labelText: 'Number of files',
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: mb,
                  decoration: const InputDecoration(
                    labelText: 'Total size (MB, 1 MB = 1,048,576 bytes)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                TextField(
                  controller: secs,
                  decoration: const InputDecoration(
                    labelText: 'Time measured (seconds)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: verified,
                  onChanged: (v) => set(() => verified = v ?? false),
                  title: const Text(
                    'I checked the received files are complete',
                  ),
                ),
                _ConditionsFields(c: c),
                if (error != null)
                  Text(error!, style: const TextStyle(color: IdColors.danger)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final n = int.tryParse(count.text.trim());
                final m = double.tryParse(mb.text.trim());
                final t = double.tryParse(secs.text.trim());
                if (n == null ||
                    n <= 0 ||
                    m == null ||
                    m <= 0 ||
                    t == null ||
                    t <= 0) {
                  set(
                    () => error =
                        'Enter files, size and time as positive numbers.',
                  );
                  return;
                }
                Navigator.pop(d, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final now = DateTime.now().toUtc();
    await store.add(
      BenchmarkRun(
        id: randomHexId(),
        createdAt: now,
        updatedAt: now,
        app: app,
        source: 'entered by hand',
        fileSet: c.fileSet,
        fileCount: int.parse(count.text.trim()),
        totalBytes: (double.parse(mb.text.trim()) * 1024 * 1024).round(),
        durationMs: (double.parse(secs.text.trim()) * 1000).round(),
        senderPlatform: sender,
        receiverPlatform: receiver,
        direction: direction,
        connection: c.connection,
        wifiBand: c.band,
        linkMbps: c.linkMbps,
        distanceM: c.distanceM,
        verified: verified,
        note: c.note,
      ),
    );
  }

  Future<bool> _confirm(BuildContext context, String title) async =>
      await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text(title),
          content: const Text(
            'This cannot be undone. Export first if you need the numbers.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: IdColors.danger),
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ==
      true;

  @override
  Widget build(BuildContext context) {
    final store = AppScope.of(context).engine.benchmarks;
    return Scaffold(
      appBar: AppBar(title: const Text('Benchmark log')),
      body: store == null
          ? const Center(child: Text('Benchmark log unavailable.'))
          : ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                final runs = store.runs;
                final groups = <String, List<BenchmarkRun>>{};
                for (final r in runs) {
                  groups
                      .putIfAbsent(
                        '${r.app} | ${r.fileSet} | ${platformLabel(r.senderPlatform)} -> ${platformLabel(r.receiverPlatform)} | ${r.connection} | ${r.wifiBand}',
                        () => [],
                      )
                      .add(r);
                }
                return PageBody(
                  children: [
                    const Text(
                      'Only measured numbers and test conditions are saved: no file names, '
                      'device names or addresses. See docs/BENCHMARK_STEPS.md for the procedure.',
                    ),
                    const SizedBox(height: IdSpacing.sm),
                    Wrap(
                      spacing: IdSpacing.sm,
                      runSpacing: IdSpacing.sm,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _addManual(context, store),
                          icon: const Icon(Icons.timer_outlined),
                          label: const Text('Add run timed by hand'),
                        ),
                        OutlinedButton.icon(
                          onPressed: runs.isEmpty
                              ? null
                              : () async {
                                  final m = ScaffoldMessenger.of(context);
                                  try {
                                    final where = await exportBenchmarkCsv(
                                      store.toCsv(),
                                    );
                                    if (where != null) {
                                      m.showSnackBar(
                                        SnackBar(
                                          content: Text('Saved: $where'),
                                        ),
                                      );
                                    }
                                  } catch (_) {
                                    m.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Could not export. Try Copy CSV.',
                                        ),
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.file_download_outlined),
                          label: Text(
                            Platform.isIOS
                                ? 'Export CSV (share)'
                                : 'Export CSV',
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: runs.isEmpty
                              ? null
                              : () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: store.toCsv()),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('CSV copied'),
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy CSV'),
                        ),
                      ],
                    ),
                    const SizedBox(height: IdSpacing.md),
                    if (runs.isEmpty)
                      const StateMessage(
                        icon: Icons.speed,
                        title: 'No runs yet',
                        message:
                            'After a completed transfer, tap "Save as benchmark run". '
                            'For LocalSend, use "Add run timed by hand".',
                      ),
                    for (final e in groups.entries)
                      SectionCard(
                        title: e.key,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Builder(
                              builder: (_) {
                                final v = [
                                  for (final r in e.value) r.mbPerSecond,
                                ];
                                final mn = v.reduce((a, b) => a < b ? a : b);
                                final mx = v.reduce((a, b) => a > b ? a : b);
                                return Text(
                                  'Runs: ${v.length}${v.length < 5 ? ' (plan needs 5+)' : ''} - '
                                  'median ${median(v).toStringAsFixed(1)} MB/s, '
                                  'min ${mn.toStringAsFixed(1)}, max ${mx.toStringAsFixed(1)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                );
                              },
                            ),
                            for (final r in e.value)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  '${r.mbPerSecond.toStringAsFixed(1)} MB/s - '
                                  '${formatBytes(r.totalBytes)}, ${r.fileCount} file(s), '
                                  '${(r.durationMs / 1000).toStringAsFixed(2)} s',
                                ),
                                subtitle: Text(
                                  '${r.source}${r.verified ? ', verified' : ''}'
                                  '${r.linkMbps != null ? ', link ${r.linkMbps} Mbps' : ''}'
                                  '${r.distanceM != null ? ', ${r.distanceM} m' : ''}\n'
                                  '${formatTime(r.createdAt.toLocal())}',
                                ),
                                isThreeLine: true,
                                trailing: IconButton(
                                  tooltip: 'Delete run',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    if (await _confirm(
                                      context,
                                      'Delete this run?',
                                    )) {
                                      await store.remove(r.id);
                                    }
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (runs.isNotEmpty)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: IdColors.danger,
                        ),
                        onPressed: () async {
                          if (await _confirm(context, 'Delete all runs?')) {
                            await store.clear();
                          }
                        },
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('Delete all runs'),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
