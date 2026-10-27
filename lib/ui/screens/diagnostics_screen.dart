import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/platform_engine.dart';
import '../../engine/transfer_engine.dart';
import '../app_scope.dart';
import '../diag_report.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';

/// Connection facts for troubleshooting. Shows no file names, no other
/// device's name or address, nothing personal. Since 0.8.1 it shows THIS
/// device's own local addresses (owner decision, Phase 7d) because they are
/// needed to find network problems.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  ConnectionInfo? _info;
  List<String> _own = const [];

  @override
  void initState() {
    super.initState();
    // AppScope is read in _refresh, so wait for the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final engine = AppScope.of(context).engine;
    final i = await readConnectionInfo();
    final nets = await engine.localNets();
    if (mounted) {
      setState(() {
        _info = i;
        _own = [for (final n in nets) '${n.name} ${n.ip}'];
      });
    }
  }

  String _time(DateTime t) => diagTime(t);

  Future<void> _copyReport(TransferEngine e) async {
    final text = buildDiagReport(
      e,
      platform: Platform.operatingSystem,
      ownAddresses: _own,
      connectionMethod: _info?.method,
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Report copied. It has no file names and no other device\'s name or address.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = AppScope.of(context).engine;
    final i = _info;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: e,
        builder: (context, _) {
          final last = e.lastFinishedJob;
          return PageBody(
            children: [
              SectionCard(
                title: 'Connection',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Method: ${i?.method ?? 'checking...'}'),
                    Text(
                      'Wi-Fi link speed: ${i?.linkMbps != null ? '${i!.linkMbps} Mbps (reported by the system, not measured)' : 'not available'}',
                    ),
                    if (i?.frequencyMhz != null && i!.frequencyMhz! > 0)
                      Text(
                        'Wi-Fi band: ${i.frequencyMhz! >= 5900
                            ? '6 GHz'
                            : i.frequencyMhz! >= 4900
                            ? '5 GHz'
                            : '2.4 GHz'}',
                      ),
                    if (i?.note != null) Text(i!.note!),
                    Text(
                      'Receiving on port: ${e.listeningPort ?? 'not running'}',
                    ),
                    Text('Discovery: ${e.discoveryError ?? 'on'}'),
                    Text('Devices seen nearby now: ${e.nearby.length}'),
                    Text(
                      'Trusted devices: ${e.trustedDevices.where((d) => d.isTrusted).length}',
                    ),
                  ],
                ),
              ),
              SectionCard(
                title: 'Connection checks',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final l in diagCheckLines(e, ownAddresses: _own))
                      Text(l),
                  ],
                ),
              ),
              SectionCard(
                title: 'Last transfer',
                child: last == null
                    ? const Text('None yet since the app started.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${last.direction == JobDirection.sending ? 'Sent' : 'Received'}: '
                            '${last.fileCount} file(s), ${formatBytes(last.bytesDone)} of ${formatBytes(last.totalBytes)}',
                          ),
                          Text('Result: ${last.state.label}'),
                          Text(
                            'Average speed (measured): ${last.averageSpeed == null ? '-' : formatSpeed(last.averageSpeed!)}',
                          ),
                          Text('Active time: ${last.elapsed.inSeconds} s'),
                        ],
                      ),
              ),
              SectionCard(
                title: 'Last error',
                child: Text(
                  e.lastError == null
                      ? 'No errors since the app started.'
                      : '${_time(e.lastErrorAt!)}  ${e.lastError}',
                  style: e.lastError == null
                      ? null
                      : const TextStyle(color: IdColors.danger),
                ),
              ),
              SectionCard(
                title: 'Problems (last 20)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (e.diagLog.entries.isEmpty)
                      const Text('None since the app started.'),
                    for (final d in e.diagLog.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: IdSpacing.xs),
                        child: Text(
                          '${_time(d.at)}  [${d.kind}]  ${d.message}',
                        ),
                      ),
                    const SizedBox(height: IdSpacing.sm),
                    FilledButton.icon(
                      onPressed: () => _copyReport(e),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy report'),
                    ),
                  ],
                ),
              ),
              SectionCard(
                title: 'Security',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Engine: ${e.version}'),
                    Text(
                      e.secureStorageNote ??
                          'Device key: kept in secure storage',
                    ),
                    const Text(
                      'Encryption: TLS 1.3, both devices\' keys checked.',
                    ),
                    if (e.startError != null)
                      Text(
                        e.startError!,
                        style: const TextStyle(color: IdColors.danger),
                      ),
                  ],
                ),
              ),
              Text(
                'This page shows no file names and no other device\'s name or address. '
                'It shows this device\'s own local addresses to help find network problems.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: IdSpacing.md),
            ],
          );
        },
      ),
    );
  }
}
