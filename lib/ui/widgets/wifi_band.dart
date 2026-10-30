import 'dart:io';

import 'package:flutter/material.dart';

import '../../engine/platform_engine.dart'
    show ConnectionInfo, readConnectionInfo;
import '../theme/design_tokens.dart';

/// Wi-Fi band from the channel frequency the system reports, or null.
String? wifiBandLabel(int? mhz) {
  if (mhz == null || mhz <= 0) return null;
  if (mhz >= 5900) return '6 GHz';
  if (mhz >= 4900) return '5 GHz';
  return '2.4 GHz';
}

/// True on 2.4 GHz, where phone-to-phone speed is usually far lower.
bool isSlowWifiBand(int? mhz) => mhz != null && mhz > 0 && mhz < 4900;

const kUse5GhzHint =
    'Use 5 GHz for best speed: connect both phones to the router\'s '
    '5 GHz network.';

/// One-line summary for the Transfer screen, e.g.
/// "Wi-Fi: 5 GHz, link 1201 Mbps (reported by the system)".
String? wifiSummary(ConnectionInfo i) {
  final band = wifiBandLabel(i.frequencyMhz);
  if (band == null && i.linkMbps == null) return null;
  return [
    'Wi-Fi: ${band ?? 'band unknown'}',
    if (i.linkMbps != null) 'link ${i.linkMbps} Mbps (reported by the system)',
  ].join(', ');
}

/// 0.9.2: shows this phone's Wi-Fi band and link speed during a
/// transfer, with a hint on 2.4 GHz. Android only (others report nothing).
class WifiBandLine extends StatefulWidget {
  const WifiBandLine({super.key, this.load});

  /// For tests.
  final Future<ConnectionInfo> Function()? load;

  @override
  State<WifiBandLine> createState() => _WifiBandLineState();
}

class _WifiBandLineState extends State<WifiBandLine> {
  ConnectionInfo? _info;

  @override
  void initState() {
    super.initState();
    final load =
        widget.load ?? (Platform.isAndroid ? readConnectionInfo : null);
    load?.call().then((i) {
      if (mounted) setState(() => _info = i);
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final i = _info;
    if (i == null) return const SizedBox.shrink();
    final s = wifiSummary(i);
    if (s == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(s, style: Theme.of(context).textTheme.bodySmall),
        if (isSlowWifiBand(i.frequencyMhz))
          Text(
            kUse5GhzHint,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: idStatus(context).warning),
          ),
      ],
    );
  }
}

/// 0.11.0 (spec B10): short network status for the top of Home, e.g.
/// "Wi-Fi · 5 GHz", "Ethernet", or a warning with what to do.
/// Returns (text, isProblem, icon).
(String, bool, IconData) networkStatus(ConnectionInfo i) {
  final m = i.method;
  if (m.startsWith('No network')) {
    return (
      'No network - connect to the same Wi-Fi as the other device',
      true,
      Icons.wifi_off,
    );
  }
  if (m.startsWith('Mobile data')) {
    return (
      'Mobile data only - connect to Wi-Fi to send',
      true,
      Icons.signal_cellular_alt,
    );
  }
  if (i.ethernet) return ('Ethernet', false, Icons.settings_ethernet);
  if (m.contains('hotspot')) {
    return ('Sharing a hotspot', false, Icons.wifi_tethering);
  }
  final band = wifiBandLabel(i.frequencyMhz);
  if (band != null) {
    return isSlowWifiBand(i.frequencyMhz)
        ? (
            'Wi-Fi · 2.4 GHz - slower; use 5 GHz if you can',
            true,
            Icons.wifi_2_bar,
          )
        : ('Wi-Fi · $band', false, Icons.wifi);
  }
  if (m.startsWith('Wi-Fi network')) return ('Wi-Fi', false, Icons.wifi);
  return ('Connected to a network', false, Icons.lan_outlined);
}

class NetworkStatusLine extends StatefulWidget {
  const NetworkStatusLine({super.key, this.load});

  /// For tests. Null: the platform (not read under `flutter test`).
  final Future<ConnectionInfo> Function()? load;

  @override
  State<NetworkStatusLine> createState() => _NetworkStatusLineState();
}

class _NetworkStatusLineState extends State<NetworkStatusLine> {
  ConnectionInfo? _info;

  @override
  void initState() {
    super.initState();
    final load =
        widget.load ??
        (Platform.environment.containsKey('FLUTTER_TEST')
            ? null
            : readConnectionInfo);
    load?.call().then((i) {
      if (mounted) setState(() => _info = i);
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final i = _info;
    if (i == null) return const SizedBox.shrink();
    final (text, problem, icon) = networkStatus(i);
    final color = problem
        ? idStatus(context).warning
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Semantics(
      container: true,
      label: 'Network: $text',
      excludeSemantics: true,
      child: Padding(
        key: const ValueKey('network-status'),
        padding: const EdgeInsets.only(bottom: IdSpacing.sm),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: IdSpacing.sm),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: problem ? FontWeight.w600 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
