import 'package:flutter/material.dart';

import '../../engine/transfer_engine.dart';
import '../app_scope.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onSend,
    required this.onConnect,
    required this.onTrusted,
  });

  final VoidCallback onSend;
  final VoidCallback onConnect;
  final VoidCallback onTrusted;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<DeviceRecord>>? _nearby;
  Future<List<DeviceRecord>>? _trusted;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_nearby == null) _load();
  }

  void _load() {
    final engine = AppScope.of(context).engine;
    setState(() {
      _nearby = engine.nearbyDevices();
      _trusted = engine.trustedDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    final theme = Theme.of(context);
    return PageBody(
      children: [
        Container(
          padding: const EdgeInsets.all(IdSpacing.lg),
          decoration: BoxDecoration(
            gradient: IdColors.brandGradient,
            borderRadius: BorderRadius.circular(IdRadii.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This device: ${settings.deviceName}',
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: IdSpacing.xs),
              const Text(
                'Not connected',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: IdTypeSizes.headline,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text(
                'Real connections are not built yet. They arrive in a later phase.',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: IdSpacing.md),
              Wrap(
                spacing: IdSpacing.sm,
                runSpacing: IdSpacing.sm,
                children: [
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: IdColors.accentBlue,
                      minimumSize: const Size(140, IdLayout.minTouchTarget),
                    ),
                    onPressed: widget.onSend,
                    icon: const Icon(Icons.upload_rounded),
                    label: const Text('Send'),
                  ),
                  Semantics(
                    label: 'Receive. Disabled. Receiving arrives in a later phase.',
                    excludeSemantics: true,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(140, IdLayout.minTouchTarget),
                      ),
                      onPressed: null,
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Receive (later phase)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: IdSpacing.md),
        const DemoBanner(),
        const SizedBox(height: IdSpacing.md),
        SectionCard(
          title: 'Nearby devices',
          trailing: IconButton(
            tooltip: 'Refresh nearby devices',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
          child: AsyncSection<List<DeviceRecord>>(
            future: _nearby!,
            onRetry: _load,
            isEmpty: (d) => d.isEmpty,
            empty: const StateMessage(
              icon: Icons.wifi_find,
              title: 'No devices nearby',
            ),
            builder: (list) => Column(
              children: [
                for (final d in list) _DeviceTile(device: d),
                TextButton(
                  onPressed: widget.onConnect,
                  child: const Text('Connect a device'),
                ),
              ],
            ),
          ),
        ),
        SectionCard(
          title: 'Saved trusted devices',
          trailing: TextButton(
            onPressed: widget.onTrusted,
            child: const Text('Manage'),
          ),
          child: AsyncSection<List<DeviceRecord>>(
            future: _trusted!,
            onRetry: _load,
            isEmpty: (d) => d.isEmpty,
            empty: StateMessage(
              icon: Icons.shield_outlined,
              title: 'No trusted devices yet',
              message: 'Pair a device to trust it.',
              action: TextButton(
                onPressed: widget.onConnect,
                child: const Text('Connect a device'),
              ),
            ),
            builder: (list) => Column(
              children: [for (final d in list) _DeviceTile(device: d)],
            ),
          ),
        ),
        Text(
          'Isekai Drop never uploads your files to the cloud.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device});

  final DeviceRecord device;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: IdLayout.minTouchTarget,
      leading: Icon(platformIcon(device.platform)),
      title: Text(device.name),
      subtitle: TrustBadge(trust: device.trust),
      trailing: const DemoChip(),
    );
  }
}
