import 'dart:io';

import 'package:flutter/material.dart';

import '../../engine/core/engine.dart' show kDefaultPort;
import '../app_scope.dart';
import '../guides/guides.dart';
import '../qr_pairing.dart';
import 'hotspot_screen.dart';
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

  @override
  void dispose() {
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
          SectionCard(
            title: 'Found automatically',
            child: engine.nearby.isEmpty
                ? StateMessage(
                    icon: Icons.wifi_find,
                    title: 'No devices found yet',
                    message:
                        engine.discoveryError ??
                        'Both devices must be on the same Wi-Fi or hotspot with Isekai Drop open. '
                            'Some networks block discovery: then type the address below.',
                  )
                : Column(
                    children: [
                      for (final d in engine.nearby)
                        NearbyTile(
                          device: d,
                          onTap: () =>
                              startPairingFlow(context, d.host, d.port),
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
                  'Both screens will then show a 16-digit code to compare.',
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
                if (Platform.isAndroid)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(
                        IdLayout.minTouchTarget,
                      ),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const HotspotScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.wifi_tethering),
                    label: const Text('Make a hotspot with Isekai Drop'),
                  ),
                for (final g in guidesForThisPlatform())
                  if (g.id != 'app_hotspot' || Platform.isAndroid)
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
