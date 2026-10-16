import 'dart:io';

import 'package:flutter/material.dart';

import '../../engine/transfer_engine.dart';
import '../app_scope.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  Future<List<DeviceRecord>>? _nearby;
  final _ipController = TextEditingController();
  String? _ipMessage;
  bool _ipValid = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _nearby ??= AppScope.of(context).engine.nearbyDevices();
  }

  void _reload() => setState(() {
    _nearby = AppScope.of(context).engine.nearbyDevices();
  });

  void _checkIp() {
    final text = _ipController.text.trim();
    final ok = InternetAddress.tryParse(text) != null;
    setState(() {
      _ipValid = ok;
      _ipMessage = ok
          ? 'Address looks valid. Connecting is not built yet (later phase).'
          : 'That is not a valid IP address. Example: 192.168.43.10';
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageBody(
      children: [
        const DemoBanner(),
        const SizedBox(height: IdSpacing.md),
        SectionCard(
          title: 'Found automatically',
          trailing: IconButton(
            tooltip: 'Search again',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
          child: AsyncSection<List<DeviceRecord>>(
            future: _nearby!,
            onRetry: _reload,
            isEmpty: (l) => l.isEmpty,
            empty: const StateMessage(
              icon: Icons.wifi_find,
              title: 'No devices found',
              message:
                  'Make sure both devices are on the same Wi-Fi or hotspot.',
            ),
            builder: (list) => Column(
              children: [
                for (final d in list)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    minTileHeight: IdLayout.minTouchTarget,
                    leading: Icon(platformIcon(d.platform)),
                    title: Text(d.name),
                    subtitle: TrustBadge(trust: d.trust),
                    trailing: const DemoChip(),
                  ),
                Text(
                  'Pairing with these devices arrives in a later phase.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SectionCard(
          title: 'Pair with QR code or code',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Scan the other device\'s QR code, or compare a short code on '
                'both screens. You always approve before a device is trusted.',
              ),
              SizedBox(height: IdSpacing.md),
              NotYetButton(
                label: 'Scan QR code',
                reason: 'Not built yet - arrives in a later phase.',
              ),
              NotYetButton(
                label: 'Show my code',
                reason: 'Not built yet - arrives in a later phase.',
              ),
            ],
          ),
        ),
        SectionCard(
          title: 'Type an address (fallback)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _ipController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'IP address of the other device',
                  hintText: '192.168.43.10',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _ipMessage = null),
                onSubmitted: (_) => _checkIp(),
              ),
              const SizedBox(height: IdSpacing.sm),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(IdLayout.minTouchTarget),
                ),
                onPressed: _checkIp,
                child: const Text('Check address'),
              ),
              if (_ipMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: IdSpacing.sm),
                  child: Text(
                    _ipMessage!,
                    style: TextStyle(
                      color: _ipValid ? IdColors.success : IdColors.danger,
                    ),
                  ),
                ),
              const SizedBox(height: IdSpacing.sm),
              const NotYetButton(
                label: 'Connect',
                reason: 'Not built yet - networking arrives in a later phase.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
