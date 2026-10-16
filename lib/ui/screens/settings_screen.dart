import 'package:flutter/material.dart';

import '../../engine/transfer_engine.dart';
import '../app_scope.dart';
import '../guides/guides.dart';
import 'benchmark_screen.dart';
import 'diagnostics_screen.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.onTrusted});

  final VoidCallback onTrusted;

  Future<void> _editName(BuildContext context) async {
    final settings = AppScope.of(context).settings;
    final controller = TextEditingController(text: settings.deviceName);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Device name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(
            labelText: 'Name other devices will see',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name != null) await settings.setDeviceName(name);
  }

  Future<void> _setAuto(BuildContext context, bool v) async {
    final settings = AppScope.of(context).settings;
    if (!v) return settings.setAutoReceiveVerified(false);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Turn on auto-receive?'),
        content: const Text(
          'Devices marked "Verified" will be able to send files to this device '
          'without asking you. Files still go only to the normal receive folder '
          'and are still checked for damage. You can turn this off at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Turn on'),
          ),
        ],
      ),
    );
    if (ok == true) await settings.setAutoReceiveVerified(true);
  }

  Future<void> _setNames(BuildContext context, bool v) async {
    final scope = AppScope.of(context);
    if (v) return scope.settings.setHistoryFileNames(true);
    final r = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Stop saving file names?'),
        content: const Text(
          'New history entries will not contain file names. '
          'Do you also want to delete the names already saved?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'keep'),
            child: const Text('Keep old names'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: IdColors.danger),
            onPressed: () => Navigator.pop(c, 'delete'),
            child: const Text('Delete old names'),
          ),
        ],
      ),
    );
    if (r == null) return;
    await scope.settings.setHistoryFileNames(false);
    if (r == 'delete') await scope.engine.history?.forgetFileNames();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final settings = scope.settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => PageBody(
        children: [
          SectionCard(
            title: 'Appearance',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Theme'),
                const SizedBox(height: IdSpacing.sm),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode),
                      label: Text('Dark'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode),
                      label: Text('Light'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.settings_suggest),
                      label: Text('System'),
                    ),
                  ],
                  selected: {settings.themeMode},
                  onSelectionChanged: (s) => settings.setThemeMode(s.first),
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'This device',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: IdLayout.minTouchTarget,
              leading: const Icon(Icons.badge_outlined),
              title: const Text('Device name'),
              subtitle: Text(settings.deviceName),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editName(context),
            ),
          ),
          SectionCard(
            title: 'Receiving',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.acceptFiles,
                  onChanged: (v) => settings.setAcceptFiles(v),
                  title: const Text('Receive files from trusted devices'),
                  subtitle: const Text(
                    'When off, every offer is declined. Unknown devices can never send; they must pair first.',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: settings.autoReceiveVerified,
                  onChanged: settings.acceptFiles
                      ? (v) => _setAuto(context, v)
                      : null,
                  title: const Text('Auto-receive from verified devices'),
                  subtitle: const Text(
                    'Off: you are asked every time (recommended). On: only devices marked '
                    '"Verified" can send without asking. "Trusted" and blocked devices are always asked or refused.',
                  ),
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'History',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.historyFileNames,
              onChanged: (v) => _setNames(context, v),
              title: const Text('Save file names in History'),
              subtitle: const Text(
                'Names are kept on this device only and never written to logs. File contents are never saved.',
              ),
            ),
          ),
          SectionCard(
            title: 'Connection',
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: settings.visibleOnNetwork,
              onChanged: (v) => settings.setVisibleOnNetwork(v),
              title: const Text('Visible to nearby devices'),
              subtitle: const Text(
                'Off: this device stops announcing itself (and stops Bonjour). '
                'Paired devices and QR/typed-address connections still work.',
              ),
            ),
          ),
          SectionCard(
            title: 'Security',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: IdLayout.minTouchTarget,
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Trusted devices'),
              subtitle: const Text(
                'Check codes, rename, revoke or remove devices',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: onTrusted,
            ),
          ),
          SectionCard(
            title: 'Help',
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: IdLayout.minTouchTarget,
                  leading: const Icon(Icons.menu_book_outlined),
                  title: const Text('Help & guides'),
                  subtitle: const Text('Hotspot, permissions, troubleshooting'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const GuidesScreen(),
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: IdLayout.minTouchTarget,
                  leading: const Icon(Icons.speed),
                  title: const Text('Benchmark log'),
                  subtitle: const Text(
                    'Measured runs, median/min/max, CSV export',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BenchmarkScreen(),
                    ),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: IdLayout.minTouchTarget,
                  leading: const Icon(Icons.monitor_heart_outlined),
                  title: const Text('Diagnostics'),
                  subtitle: const Text(
                    'Connection method, link speed, last error',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DiagnosticsScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Diagnostics',
            child: ListenableBuilder(
              listenable: scope.engine,
              builder: (context, _) {
                final e = scope.engine;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Engine: ${e.version}'),
                    Text(
                      'Receiving on port: ${e.listeningPort ?? 'not running'}',
                    ),
                    if (e.startError != null)
                      Text(
                        e.startError!,
                        style: const TextStyle(color: IdColors.danger),
                      ),
                    Text('Discovery: ${e.discoveryError ?? 'on'}'),
                    Text('Nearby devices seen: ${e.nearby.length}'),
                    Text('Trusted devices: ${e.trustedDevices.length}'),
                    Text('Device key: ${shortFingerprint(e.myFingerprint)}'),
                    Text(
                      e.secureStorageNote ??
                          'Device key: kept in secure storage',
                    ),
                    Text('Received files go to: ${e.receiveLocationNote}'),
                    const Text(
                      'Encryption: TLS 1.3 with both devices\' keys checked.',
                    ),
                    Text(
                      'History entries: ${e.history?.entries.length ?? 'unavailable'}',
                    ),
                    const Text(
                      'Isekai Drop itself has no analytics, no cloud, no crash reporting. '
                      'On Android the QR scanner (Google ML Kit) sends Google its own usage metrics - see Privacy.',
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
