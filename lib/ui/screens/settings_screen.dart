import 'package:flutter/material.dart';

import '../../engine/transfer_engine.dart';
import '../app_scope.dart';
import '../guides/guides.dart';
import 'benchmark_screen.dart';
import 'diagnostics_screen.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';
import 'fast_direct_screen.dart';

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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
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
                // 0.11.0 (spec D17): no wrapped "Syste / m" at big font
                // sizes: segments keep their width and scroll if needed.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System', softWrap: false),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text('Dark', softWrap: false),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light', softWrap: false),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (s) => settings.setThemeMode(s.first),
                  ),
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
              trailing: const Icon(
                Icons.edit_outlined,
                semanticLabel: 'Rename',
              ),
              onTap: () => _editName(context),
            ),
          ),
          SectionCard(
            title: 'Receiving',
            child: Column(
              children: [
                SettingSwitch(
                  value: settings.acceptFiles,
                  onChanged: (v) => settings.setAcceptFiles(v),
                  title: 'Receive files from trusted devices',
                  summary: 'Off: every offer is declined',
                  info: 'When off, every offer is declined. Unknown devices can never send; they must pair first.',
                ),
                SettingSwitch(
                  value: settings.autoReceiveVerified,
                  onChanged: settings.acceptFiles
                      ? (v) => _setAuto(context, v)
                      : null,
                  title: 'Auto-receive from verified devices',
                  summary: 'Off: you are asked every time (recommended)',
                  info:
                      'Off: you are asked every time (recommended). On: only devices marked '
                      '"Verified" can send without asking. "Trusted" and blocked devices are always asked or refused.',
                ),
                SettingSwitch(
                  value: settings.historyFileNames,
                  onChanged: (v) => _setNames(context, v),
                  title: 'Save file names in History',
                  summary: 'Kept on this device only',
                  info: 'Names are kept on this device only and never written to logs. File contents are never saved.',
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Connection',
            child: Column(
              children: [
                SettingSwitch(
                  value: settings.visibleOnNetwork,
                  onChanged: (v) => settings.setVisibleOnNetwork(v),
                  title: 'Visible to nearby devices',
                  summary: 'Others on your Wi-Fi can find this device',
                  info:
                      'Off: this device stops announcing itself (and stops Bonjour). '
                      'Paired devices and QR/typed-address connections still work.',
                ),
                const FastDirectSetting(),
              ],
            ),
          ),
          SectionCard(
            title: 'Security',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: IdLayout.minTouchTarget,
              leading: const Icon(Icons.verified_user_outlined),
              title: const Text('Trusted devices'),
              subtitle: const Text('Check codes, rename, revoke or remove'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onTrusted,
            ),
          ),
          SectionCard(
            title: 'Advanced',
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
                  leading: const Icon(Icons.monitor_heart_outlined),
                  title: const Text('Diagnostics'),
                  subtitle: const Text(
                    'Connection, link speed, speed test, last error',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DiagnosticsScreen(),
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
                  leading: const Icon(Icons.gavel_outlined),
                  title: const Text('Open-source licences'),
                  subtitle: const Text(
                    'Full licence texts of included software',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Isekai Drop',
                  ),
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'About this device',
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
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
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
