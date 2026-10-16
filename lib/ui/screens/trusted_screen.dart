import 'package:flutter/material.dart';

import '../../engine/transfer_engine.dart';
import '../app_scope.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';
import '../widgets/device_widgets.dart';

class TrustedDevicesScreen extends StatelessWidget {
  const TrustedDevicesScreen({super.key});

  Future<void> _rename(BuildContext context, TrustedDevice d) async {
    final engine = AppScope.of(context).engine;
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: d.name);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rename device'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'New name (only on this device)',
          ),
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
    if (name == null || name.isEmpty) return;
    try {
      await engine.renameTrustedDevice(d.id, name);
      messenger.showSnackBar(const SnackBar(content: Text('Renamed')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not rename. Please try again.')),
      );
    }
  }

  Future<void> _revoke(BuildContext context, TrustedDevice d) async {
    final engine = AppScope.of(context).engine;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Revoke trust?'),
        content: Text(
          '"${d.name}" will no longer be trusted and cannot connect. '
          'To use it again you must pair again and compare the code.',
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
    if (ok != true) return;
    try {
      await engine.revokeTrustedDevice(d.id);
      messenger.showSnackBar(const SnackBar(content: Text('Trust revoked')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not revoke. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = AppScope.of(context).engine;
    return Scaffold(
      appBar: AppBar(title: const Text('Trusted devices')),
      body: ListenableBuilder(
        listenable: engine,
        builder: (context, _) => PageBody(
          children: [
            if (engine.trustedDevices.isEmpty)
              const StateMessage(
                icon: Icons.shield_outlined,
                title: 'No trusted devices',
                message: 'Devices you pair and approve will appear here.',
              ),
            for (final d in engine.trustedDevices)
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
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: IdSpacing.xs),
                      Text(platformLabel(d.platform)),
                      TrustBadge(trust: trustOf(d)),
                      Text(
                        'Key: ${shortFingerprint(d.fingerprint)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        'Paired: ${formatTime(d.createdAt.toLocal())}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (!d.isTrusted)
                        const Padding(
                          padding: EdgeInsets.only(top: IdSpacing.xs),
                          child: Text(
                            'This device answered with a different key than the one saved. '
                            'It is blocked. To verify it again: Revoke, then pair again and compare the code.',
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
                            onPressed: () => _rename(context, d),
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
                            onPressed: () => _revoke(context, d),
                            icon: const Icon(Icons.remove_moderator_outlined),
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
    );
  }
}
