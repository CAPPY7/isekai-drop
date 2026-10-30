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
