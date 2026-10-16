import 'package:flutter/material.dart';

import '../../engine/platform_engine.dart';
import '../../engine/transfer_engine.dart';
import '../app_scope.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';

/// Connection facts for troubleshooting. Shows no file names, no device or
/// network names, no addresses, nothing personal.
class DiagnosticsScreen extends StatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  State<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends State<DiagnosticsScreen> {
  ConnectionInfo? _info;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final i = await readConnectionInfo();
    if (mounted) setState(() => _info = i);
  }

  String _time(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

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
                'This page shows no file names, device names, network names or addresses.',
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
