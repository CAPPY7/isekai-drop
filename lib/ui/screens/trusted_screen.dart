import 'package:flutter/material.dart';

import '../../engine/transfer_engine.dart';
import '../app_scope.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';

class TrustedDevicesScreen extends StatefulWidget {
  const TrustedDevicesScreen({super.key});

  @override
  State<TrustedDevicesScreen> createState() => _TrustedDevicesScreenState();
}

class _TrustedDevicesScreenState extends State<TrustedDevicesScreen> {
  Future<List<DeviceRecord>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= AppScope.of(context).engine.trustedDevices();
  }

  void _reload() => setState(() {
    _future = AppScope.of(context).engine.trustedDevices();
  });

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _rename(DeviceRecord d) async {
    final controller = TextEditingController(text: d.name);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rename device'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(labelText: 'New name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await AppScope.of(context).engine.renameTrustedDevice(d.id, name);
      _snack('Renamed (DEMO data)');
    } catch (_) {
      _snack('Could not rename. Please try again.');
    }
    _reload();
  }

  Future<void> _revoke(DeviceRecord d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Revoke trust?'),
        content: Text(
          '"${d.name}" will no longer be trusted. It must pair again with a '
          'QR code or code before it can connect as trusted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: IdColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await AppScope.of(context).engine.revokeTrustedDevice(d.id);
      _snack('Trust revoked (DEMO data)');
    } catch (_) {
      _snack('Could not revoke. Please try again.');
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trusted devices')),
      body: PageBody(
        children: [
          const DemoBanner(),
          const SizedBox(height: IdSpacing.md),
          AsyncSection<List<DeviceRecord>>(
            future: _future!,
            onRetry: _reload,
            isEmpty: (l) => l.isEmpty,
            empty: const StateMessage(
              icon: Icons.shield_outlined,
              title: 'No trusted devices',
              message: 'Devices you pair and approve will appear here.',
            ),
            builder: (list) => Column(
              children: [
                for (final d in list)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(IdSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(platformIcon(d.platform)),
                              const SizedBox(width: IdSpacing.sm),
                              Expanded(
                                child: Text(
                                  d.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                              ),
                              const DemoChip(),
                            ],
                          ),
                          const SizedBox(height: IdSpacing.xs),
                          Text(d.platform.label),
                          TrustBadge(trust: d.trust),
                          if (d.trust == TrustLevel.identityChanged)
                            const Padding(
                              padding: EdgeInsets.only(top: IdSpacing.xs),
                              child: Text(
                                'This device\'s identity key changed. It is blocked '
                                'until you verify it again (re-verify arrives in a later phase).',
                                style: TextStyle(color: IdColors.danger),
                              ),
                            ),
                          const SizedBox(height: IdSpacing.sm),
                          Wrap(
                            spacing: IdSpacing.sm,
                            children: [
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(
                                    0,
                                    IdLayout.minTouchTarget,
                                  ),
                                ),
                                onPressed: () => _rename(d),
                                icon: const Icon(Icons.edit_outlined),
                                label: Text(
                                  'Rename',
                                  semanticsLabel: 'Rename ${d.name}',
                                ),
                              ),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: IdColors.danger,
                                  minimumSize: const Size(
                                    0,
                                    IdLayout.minTouchTarget,
                                  ),
                                ),
                                onPressed: () => _revoke(d),
                                icon: const Icon(
                                  Icons.remove_moderator_outlined,
                                ),
                                label: Text(
                                  'Revoke',
                                  semanticsLabel: 'Revoke ${d.name}',
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
