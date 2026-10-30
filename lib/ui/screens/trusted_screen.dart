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

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: IdColors.danger),
            onPressed: () => Navigator.pop(c, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _revoke(BuildContext context, TrustedDevice d) async {
    final engine = AppScope.of(context).engine;
    final messenger = ScaffoldMessenger.of(context);
    if (!await _confirm(
      context,
      title: 'Revoke trust?',
      body:
          '"${d.name}" will no longer be trusted and cannot connect or send to you. '
          'To use it again, pair again.',
      action: 'Revoke',
    )) {
      return;
    }
    try {
      await engine.revokeTrustedDevice(d.id);
      messenger.showSnackBar(const SnackBar(content: Text('Trust revoked')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not revoke. Please try again.')),
      );
    }
  }

  Future<void> _forget(BuildContext context, TrustedDevice d) async {
    final engine = AppScope.of(context).engine;
    final messenger = ScaffoldMessenger.of(context);
    if (!await _confirm(
      context,
      title: 'Remove from this list?',
      body:
          '"${d.name}" and its saved key will be deleted from this device. '
          'It cannot connect until you pair again. Your files are not deleted.',
      action: 'Remove',
    )) {
      return;
    }
    try {
      await engine.forgetTrustedDevice(d.id);
      messenger.showSnackBar(const SnackBar(content: Text('Removed')));
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not remove. Please try again.')),
      );
    }
  }

  /// Re-verify without the network: both devices compute the same code from
  /// the two saved keys. The user compares it on both screens.
  Future<void> _verify(BuildContext context, TrustedDevice d) async {
    final engine = AppScope.of(context).engine;
    final messenger = ScaffoldMessenger.of(context);
    final code = engine.codeFor(d);
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Check the code with "${d.name}"'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'On the other device open Settings > Trusted devices > this device > '
              'Check code. Both screens must show exactly this code:',
            ),
            const SizedBox(height: IdSpacing.sm),
            SelectableText(
              code,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: IdColors.danger),
            onPressed: () => Navigator.pop(c, 'no'),
            child: const Text('Codes differ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, 'yes'),
            child: const Text('Codes match'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    if (r == 'yes') {
      final ok = await engine.markDeviceVerified(d.id);
      messenger.showSnackBar(
        SnackBar(content: Text(ok ? 'Marked as verified' : 'Could not verify')),
      );
    } else if (r == 'no') {
      await _revoke(context, d);
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
            if (engine.trustLoadWarning != null)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded),
                  title: const Text('Trusted devices file was damaged'),
                  subtitle: Text(engine.trustLoadWarning!),
                ),
              ),
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
                      Text(
                        'Last change: ${formatTime(d.updatedAt.toLocal())}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (d.status == TrustStatus.trusted)
                        const Padding(
                          padding: EdgeInsets.only(top: IdSpacing.xs),
                          child: Text(
                            'Paired before this version: tap "Check code" to mark it Verified.',
                          ),
                        ),
                      if (d.status == TrustStatus.identityChanged)
                        const Padding(
                          padding: EdgeInsets.only(top: IdSpacing.xs),
                          child: Text(
                            'This device answered with a different key than the one saved. '
                            'It is blocked: it cannot send to you and you cannot send to it. '
                            'If you reinstalled the other app, pair again and compare the code. '
                            'If not, someone may be pretending to be it.',
                            style: TextStyle(color: IdColors.danger),
                          ),
                        ),
                      if (d.status == TrustStatus.revoked)
                        const Padding(
                          padding: EdgeInsets.only(top: IdSpacing.xs),
                          child: Text(
                            'You revoked trust. It is blocked until you pair again.',
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
                          if (d.isTrusted)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                minimumSize: const Size(
                                  0,
                                  IdLayout.minTouchTarget,
                                ),
                              ),
                              onPressed: () => _verify(context, d),
                              icon: const Icon(Icons.pin_outlined),
                              label: Text(
                                'Check code',
                                semanticsLabel: 'Check code with ${d.name}',
                              ),
                            ),
                          if (d.isTrusted)
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
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: IdColors.danger,
                              minimumSize: const Size(
                                0,
                                IdLayout.minTouchTarget,
                              ),
                            ),
                            onPressed: () => _forget(context, d),
                            icon: const Icon(Icons.delete_outline),
                            label: Text(
                              'Remove',
                              semanticsLabel: 'Remove ${d.name}',
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
