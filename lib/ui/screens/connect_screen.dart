import 'dart:io';

import 'package:flutter/material.dart';

import '../../engine/core/engine.dart' show kDefaultPort;
import '../app_scope.dart';
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
          const SectionCard(
            title: 'QR code',
            child: NotYetButton(
              label: 'Scan QR code',
              reason:
                  'Not included yet: a QR scanner needs a camera library and '
                  'your licence approval. Use the address and 16-digit code instead.',
            ),
          ),
        ],
      ),
    );
  }
}
