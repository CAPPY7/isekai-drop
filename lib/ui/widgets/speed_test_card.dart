import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/transfer_engine.dart';
import '../diag_report.dart';
import '../theme/design_tokens.dart';
import 'common.dart';

/// 0.10.1 Diagnostics: Speed test with a paired device. Every step of a
/// transfer is measured on its own so the slow one can be found.
class SpeedTestCard extends StatefulWidget {
  const SpeedTestCard({super.key, required this.engine});

  final TransferEngine engine;

  @override
  State<SpeedTestCard> createState() => _SpeedTestCardState();
}

const _stageText = {
  'connect': 'Connecting to the other device...',
  'raw_tcp': 'Network only (plain TCP)...',
  'tls_lane': 'Encrypted, background thread...',
  'tls_main': 'Encrypted, main thread...',
  'local': 'Disk tests on both devices...',
  'write_old': 'Disk: write (old way)...',
  'write_new': 'Disk: write (new way)...',
  'hash_rx': 'Disk: file check (SHA-256)...',
  'read_tx': 'Disk: read + SHA-256...',
  'write_target': 'Disk: write into Downloads...',
};

class _SpeedTestCardState extends State<SpeedTestCard> {
  String? _deviceId;
  bool _fastDirect = false;
  bool _running = false;
  String? _stage;
  SpeedReport? _report;
  String? _error;

  Future<void> _run(TrustedDevice d) async {
    setState(() {
      _running = true;
      _stage = 'connect';
      _report = null;
      _error = null;
    });
    try {
      final r = await widget.engine
          .runSpeedTest(
            d,
            tryFastDirect: _fastDirect,
            appVersion: kAppVersion,
            // A few setState calls per run, not per byte.
            onStage: (s) {
              if (mounted && s != _stage) setState(() => _stage = s);
            },
          )
          .timeout(const Duration(minutes: 4));
      if (mounted) setState(() => _report = r);
    } on SpeedTestException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on TimeoutException {
      if (mounted) {
        setState(
          () => _error = 'The Speed test took too long and was stopped.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error =
              'Speed test failed: ${explainErrorClass(classifyError(e))}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
          _stage = null;
        });
      }
    }
  }

  Future<void> _copy() async {
    final r = _report;
    if (r == null) return;
    await Clipboard.setData(ClipboardData(text: r.toText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Speed report copied. It has no file names, network names or device names.',
        ),
      ),
    );
  }

  Widget _row(SpeedSample s) {
    final v = s.mbPerSec;
    return Padding(
      padding: const EdgeInsets.only(bottom: IdSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(s.label)),
          const SizedBox(width: IdSpacing.sm),
          Text(
            v == null ? (s.note ?? '-') : '${v.toStringAsFixed(1)} MB/s',
            style: v == null
                ? const TextStyle(color: IdColors.warning)
                : const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.engine;
    final devices = [
      for (final d in e.trustedDevices)
        if (d.isTrusted) d,
    ];
    TrustedDevice? sel;
    for (final d in devices) {
      if (d.id == _deviceId) sel = d;
    }
    sel ??= devices.isEmpty ? null : devices.first;
    final r = _report;
    final small = Theme.of(context).textTheme.bodySmall;
    return SectionCard(
      title: 'Speed test',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Measures each step of a transfer on its own: the network, '
            'encryption, and reading, writing and checking files on both '
            'devices. Only zeros are sent; test files are deleted at once. '
            'Open Isekai Drop on the other device first. Takes up to a minute.',
          ),
          const SizedBox(height: IdSpacing.sm),
          if (devices.isEmpty)
            const Text('Pair a device first.')
          else ...[
            DropdownButton<String>(
              isExpanded: true,
              value: sel!.id,
              items: [
                for (final d in devices)
                  DropdownMenuItem(value: d.id, child: Text(d.name)),
              ],
              onChanged: _running ? null : (v) => setState(() => _deviceId = v),
            ),
            if (e.canJoinDirect)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Try Fast direct'),
                subtitle: const Text(
                  'Set up the one-hop Wi-Fi link first, as a large transfer would.',
                ),
                value: _fastDirect,
                onChanged: _running
                    ? null
                    : (v) => setState(() => _fastDirect = v),
              ),
            Row(
              children: [
                FilledButton.icon(
                  onPressed: _running ? null : () => _run(sel!),
                  icon: const Icon(Icons.speed),
                  label: Text(_running ? 'Running...' : 'Run speed test'),
                ),
                if (r != null) ...[
                  const SizedBox(width: IdSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: _copy,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy report'),
                  ),
                ],
              ],
            ),
          ],
          if (_running && _stage != null) ...[
            const SizedBox(height: IdSpacing.sm),
            Text(_stageText[_stage] ?? _stage!),
            const SizedBox(height: IdSpacing.xs),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: IdSpacing.sm),
            Text(_error!, style: const TextStyle(color: IdColors.danger)),
          ],
          if (r != null) ...[
            const SizedBox(height: IdSpacing.md),
            Text('Route: ${r.route}', style: small),
            Text('Wi-Fi here: ${SpeedReport.linkText(r.link)}', style: small),
            Text(
              'Wi-Fi there: ${SpeedReport.linkText(r.peerLink)}',
              style: small,
            ),
            const SizedBox(height: IdSpacing.sm),
            Text('Network', style: Theme.of(context).textTheme.titleSmall),
            for (final s in r.network) _row(s),
            const SizedBox(height: IdSpacing.sm),
            Text(
              'This device (sending)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final s in r.local) _row(s),
            const SizedBox(height: IdSpacing.sm),
            Text(
              'Other device (receiving)',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            for (final s in r.peerLocal) _row(s),
            if (r.bottleneck != null) ...[
              const SizedBox(height: IdSpacing.sm),
              Text(
                'Slowest step: ${r.bottleneck}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            for (final n in r.notes) Text(n, style: small),
            Text('MB = 1,000,000 bytes.', style: small),
          ],
        ],
      ),
    );
  }
}
