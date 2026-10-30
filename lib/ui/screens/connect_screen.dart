import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../engine/core/engine.dart' show kDefaultPort;
import '../app_scope.dart';
import '../guides/guides.dart';
import '../qr_pairing.dart';
import '../pairing_flow.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';
import '../widgets/device_widgets.dart';
import '../widgets/discovery_hint.dart';
import 'fast_direct_screen.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _ip = TextEditingController();
  final _port = TextEditingController(text: '$kDefaultPort');
  String? _error;
  Timer? _autoSearch;

  @override
  void initState() {
    super.initState();
    // Nothing found by discovery after a few seconds: search the network
    // address by address once (routers/hotspots that block discovery).
    _autoSearch = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      final engine = AppScope.of(context).engine;
      if (engine.nearby.isEmpty && !engine.scanning) {
        unawaited(engine.scanNetwork());
      }
    });
  }

  @override
  void dispose() {
    _autoSearch?.cancel();
    _ip.dispose();
    _port.dispose();
    super.dispose();
  }

  void _pair() {
    final host = _ip.text.trim();
    final port = int.tryParse(_port.text.trim());
    if (InternetAddress.tryParse(host) == null) {
      setState(
        () => _error = 'That is not a valid IP address. Example: 192.168.1.23',
      );
      return;
    }
    if (port == null || port < 1 || port > 65535) {
      setState(() => _error = 'Port must be a number from 1 to 65535.');
      return;
    }
    setState(() => _error = null);
    startPairingFlow(context, host, port);
  }

  @override
  Widget build(BuildContext context) {
    final engine = AppScope.of(context).engine;
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) => PageBody(
        children: [
          // 0.11.0 (spec A4): the QR code first - what most people use.
          SectionCard(
            title: 'Pair with a QR code',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'This device: ${engine.myName}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: IdSpacing.sm),
                Wrap(
                  spacing: IdSpacing.sm,
                  runSpacing: IdSpacing.sm,
                  children: [
                    if (canScanQr)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(160, IdLayout.minTouchTarget),
                        ),
                        onPressed: () => scanQrAndPair(context),
                        icon: const Icon(Icons.qr_code_scanner),
                        label: const Text('Scan QR code'),
                      ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(160, IdLayout.minTouchTarget),
                      ),
                      onPressed: () => showMyQr(context),
                      icon: const Icon(Icons.qr_code_2),
                      label: const Text('Show my QR code'),
                    ),
                  ],
                ),
                if (!canScanQr)
                  Padding(
                    padding: const EdgeInsets.only(top: IdSpacing.xs),
                    child: Text(
                      'No camera scanner here: scan this code from your phone.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
          if (Platform.isIOS)
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('On iPhone/iPad'),
                subtitle: const Text(
                  'Keep the app open while sending. PCs do not appear '
                  'automatically: scan their QR code.',
                ),
                onTap: () => openGuide(context, guideIphone),
              ),
            ),
          SectionCard(
            title: 'Found automatically',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (engine.nearby.isEmpty) ...[
                  DiscoveryHint(engine: engine),
                  if (!engine.scanning && engine.lastScanFound == 0)
                    const EmptyLine(
                      icon: Icons.search_off,
                      text: 'The search found nothing on this network.',
                      info:
                          'Check that the other device is on the SAME Wi-Fi or hotspot '
                          'and has Isekai Drop open. A Windows PC must also allow Isekai Drop '
                          'in its firewall (see Help).',
                    ),
                ] else
                  for (final d in engine.nearby)
                    NearbyTile(
                      device: d,
                      onTap: () => startPairingFlow(
                        context,
                        d.host,
                        d.port,
                        peerName: d.name,
                      ),
                    ),
              ],
            ),
          ),
          SectionCard(
            title: 'Fast direct (no router)',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  Platform.isAndroid
                      ? 'Link straight to another device over Wi-Fi - often '
                            'faster than through a router, and works with no '
                            'router at all. Between two Android phones it '
                            'happens automatically for big files.'
                      : 'Join an Android phone\'s fast link (no router in '
                            'between)${Platform.isWindows ? ', or let a phone join this PC\'s Mobile Hotspot' : ''}.',
                ),
                const SizedBox(height: IdSpacing.sm),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(IdLayout.minTouchTarget),
                  ),
                  onPressed: () => openFastDirect(context),
                  icon: const Icon(Icons.bolt),
                  label: const Text('Open Fast direct'),
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'No Wi-Fi router?',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Turn on the normal hotspot of one phone (or Windows Mobile '
                  'Hotspot) and join it with the other device. Mobile data is not used.',
                ),
                for (final g in guidesForThisPlatform())
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: IdLayout.minTouchTarget,
                    leading: Icon(g.icon),
                    title: Text(g.title),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openGuide(context, g),
                  ),
              ],
            ),
          ),
          // 0.11.0 (spec A4): technical details collapsed.
          Card(
            child: Theme(
              data: Theme.of(context)
                  .copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const ValueKey('connect-advanced'),
                leading: const Icon(Icons.tune),
                title: const Text('Advanced'),
                subtitle: const Text('Address, port, key fingerprint, search'),
                childrenPadding: const EdgeInsets.fromLTRB(
                  IdSpacing.md,
                  0,
                  IdSpacing.md,
                  IdSpacing.md,
                ),
                expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ThisDeviceCard(engine: engine),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(
                        IdLayout.minTouchTarget,
                      ),
                    ),
                    onPressed: engine.scanning
                        ? null
                        : () => unawaited(engine.scanNetwork()),
                    icon: const Icon(Icons.radar),
                    label: Text(
                      engine.scanning ? 'Searching...' : 'Search this network',
                    ),
                  ),
                  const SizedBox(height: IdSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Pair by typing the address',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        'Read the address under Advanced on the other device.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: IdSpacing.md),
                      TextField(
                        controller: _ip,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'IP address of the other device',
                          hintText: '192.168.1.23',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: IdSpacing.sm),
                      TextField(
                        controller: _port,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Port',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _pair(),
                      ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: IdSpacing.sm),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: IdSpacing.sm),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(
                            IdLayout.minTouchTarget,
                          ),
                        ),
                        onPressed: _pair,
                        child: const Text('Connect and pair'),
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
