import 'package:flutter/material.dart';

import '../app_scope.dart';
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
          const SectionCard(
            title: 'Receiving',
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: true,
                  onChanged: null,
                  title: Text('Ask me before receiving from untrusted devices'),
                  subtitle: Text('Always on for safety. Cannot be turned off.'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: false,
                  onChanged: null,
                  title: Text('Auto-receive from trusted devices'),
                  subtitle: Text('Not built yet - arrives in a later phase.'),
                ),
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
              subtitle: const Text('Rename or revoke devices'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onTrusted,
            ),
          ),
          const SectionCard(
            title: 'Connection preferences',
            child: Text(
              'Not built yet. Choosing hotspot, Wi-Fi Direct or manual '
              'address arrives with real connections.',
            ),
          ),
          SectionCard(
            title: 'Diagnostics',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Engine: ${scope.engine.version}'),
                Text(
                  scope.engine.isDemo
                      ? 'Data source: DEMO data (no networking)'
                      : 'Data source: real engine',
                ),
                const Text('No analytics, no cloud, no crash reporting.'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
