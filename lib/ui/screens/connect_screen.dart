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
          ThisDeviceCard(engine: engine),
          if (Platform.isIOS)
            Card(
              child: ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('On iPhone/iPad'),
                subtitle: const Text(
                  'Keep the app open while sending. Windows and Linux PCs do not '
                  'appear automatically: scan their QR code.',
                ),
                onTap: () => openGuide(context, guideIphone),
              ),
            ),
          SectionCard(
            title: 'Found automatically',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (engine.nearby.isEmpty)
                  StateMessage(
                    icon: Icons.wifi_find,
                    title: engine.scanning
                        ? 'Searching this network...'
                        : 'No devices found yet',
                    message: [
                      if (engine.discoveryError != null) engine.discoveryError!,
                      if (!engine.scanning && engine.lastScanFound == 0)
                        'The search found no Isekai Drop on this network. '
                            'Check that the other device is on the SAME Wi-Fi or hotspot '
                            'and has Isekai Drop open. A Windows PC must also allow Isekai Drop '
                            'in its firewall (see Help).',
                      'Or scan the QR code, or type the address below.',
                    ].join(' '),
                  )
                else
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
                const SizedBox(height: IdSpacing.sm),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(IdLayout.minTouchTarget),
                  ),
                  onPressed: engine.scanning
                      ? null
                      : () => unawaited(engine.scanNetwork()),
                  icon: engine.scanning
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.radar),
                  label: Text(
                    engine.scanning ? 'Searching...' : 'Search this network',
                  ),
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Pair by typing the address',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'On the other device open Connect and read its address. Type it here. '
                  'The other device then asks once to accept this one.',
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
                      style: const TextStyle(color: IdColors.danger),
                    ),
                  ),
                const SizedBox(height: IdSpacing.sm),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(IdLayout.minTouchTarget),
                  ),
                  onPressed: _pair,
                  child: const Text('Connect and pair'),
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'QR code',
            child: Wrap(
              spacing: IdSpacing.sm,
              runSpacing: IdSpacing.sm,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(200, IdLayout.minTouchTarget),
                  ),
                  onPressed: () => showMyQr(context),
                  icon: const Icon(Icons.qr_code_2),
                  label: const Text('Show my QR code'),
                ),
                if (canScanQr)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(200, IdLayout.minTouchTarget),
                    ),
                    onPressed: () => scanQrAndPair(context),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan QR code'),
                  )
                else
                  const Text(
                    'This device has no QR scanner: scan this device\'s code '
                    'from your phone instead.',
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
        ],
      ),
    );
  }
}
