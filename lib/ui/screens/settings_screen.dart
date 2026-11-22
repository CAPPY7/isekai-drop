import 'about_screen.dart';

import 'package:flutter/material.dart';

import '../../engine/transfer_engine.dart';
import '../app_scope.dart';
import '../diag_report.dart' show kAppVersion;
import '../guides/guides.dart';
import 'benchmark_screen.dart';
import 'diagnostics_screen.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';
import 'fast_direct_screen.dart';
import '../../l10n/l10n.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.onTrusted});

  final VoidCallback onTrusted;

  Future<void> _editName(BuildContext context) async {
    final settings = AppScope.of(context).settings;
    final controller = TextEditingController(text: settings.deviceName);
    final name = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr(context).deviceName),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: InputDecoration(labelText: tr(context).deviceNameLabel),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, controller.text),
            child: Text(tr(context).save),
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
        title: Text(tr(context).autoReceiveTitle),
        content: Text(tr(context).autoReceiveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(tr(context).cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr(context).turnOn),
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
        title: Text(tr(context).stopNamesTitle),
        content: Text(tr(context).stopNamesBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, 'keep'),
            child: Text(tr(context).keepOldNames),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(c, 'delete'),
            child: Text(tr(context).deleteOldNames),
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
            title: tr(context).appearance,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(context).theme),
                const SizedBox(height: IdSpacing.sm),
                // 0.11.0 (spec D17): no wrapped "Syste / m" at big font
                // sizes: segments keep their width and scroll if needed.
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text(tr(context).themeSystem, softWrap: false),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        label: Text(tr(context).themeDark, softWrap: false),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text(tr(context).themeLight, softWrap: false),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (s) => settings.setThemeMode(s.first),
                  ),
                ),
                const SizedBox(height: IdSpacing.md),
                // E2: screen language (System / English / Hindi / Kannada).
                Text(tr(context).language),
                DropdownButton<String>(
                  key: const ValueKey('settings-language'),
                  isExpanded: true,
                  value: settings.language,
                  items: [
                    for (final code in kLanguageCodes)
                      DropdownMenuItem(
                        value: code,
                        child: Text(
                          code == 'system'
                              ? tr(context).languageSystem
                              : kLanguageNames[code]!,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) settings.setLanguage(v);
                  },
                ),
                Text(
                  tr(context).languageNote,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SectionCard(
            title: tr(context).thisDevice,
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: IdLayout.minTouchTarget,
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(tr(context).deviceName),
                  subtitle: Text(settings.deviceName),
                  trailing: Icon(
                    Icons.edit_outlined,
                    semanticLabel: tr(context).rename,
                  ),
                  onTap: () => _editName(context),
                ),
                ListTile(
                  key: const Key('settings-version'),
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: IdLayout.minTouchTarget,
                  leading: const Icon(Icons.info_outline),
                  title: Text(tr(context).aboutApp),
                  subtitle: Text(tr(context).aboutSubtitle(kAppVersion)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AboutScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SectionCard(
            title: tr(context).receiving,
            child: Column(
              children: [
                SettingSwitch(
                  value: settings.acceptFiles,
                  onChanged: (v) => settings.setAcceptFiles(v),
                  title: tr(context).receiveTrusted,
                  summary: tr(context).receiveTrustedOff,
                  info: tr(context).receiveTrustedInfo,
                ),
                SettingSwitch(
                  value: settings.autoReceiveVerified,
                  onChanged: settings.acceptFiles
                      ? (v) => _setAuto(context, v)
                      : null,
                  title: tr(context).autoReceive,
                  summary: tr(context).autoReceiveOff,
                  info: tr(context).autoReceiveInfo,
                ),
                SettingSwitch(
                  value: settings.historyFileNames,
                  onChanged: (v) => _setNames(context, v),
                  title: tr(context).saveNames,
                  summary: tr(context).saveNamesSummary,
                  info: tr(context).saveNamesInfo,
                ),
              ],
            ),
          ),
          SectionCard(
            title: tr(context).connection,
            child: Column(
              children: [
                SettingSwitch(
                  value: settings.visibleOnNetwork,
                  onChanged: (v) => settings.setVisibleOnNetwork(v),
                  title: tr(context).visible,
                  summary: tr(context).visibleSummary,
                  info: tr(context).visibleInfo,
                ),
                const FastDirectSetting(),
              ],
            ),
          ),
          SectionCard(
            title: tr(context).security,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: IdLayout.minTouchTarget,
              leading: const Icon(Icons.verified_user_outlined),
              title: Text(tr(context).trustedDevices),
              subtitle: Text(tr(context).trustedDevicesSub),
              trailing: const Icon(Icons.chevron_right),
              onTap: onTrusted,
            ),
          ),
          SectionCard(
            title: tr(context).advanced,
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: IdLayout.minTouchTarget,
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(tr(context).helpGuides),
                  subtitle: Text(tr(context).helpGuidesSub),
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
                  title: Text(tr(context).diagnostics),
                  subtitle: Text(tr(context).diagnosticsSub),
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
                  title: Text(tr(context).benchmarkLog),
                  subtitle: Text(tr(context).benchmarkSub),
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
                  title: Text(tr(context).licencesTitle),
                  subtitle: Text(tr(context).licencesSub),
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
            title: tr(context).aboutThisDevice,
            child: ListenableBuilder(
              listenable: scope.engine,
              builder: (context, _) {
                final e = scope.engine;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tr(context).engineVersion(e.version)),
                    Text(
                      tr(context).receivingPort(
                        e.listeningPort?.toString() ?? tr(context).notRunning,
                      ),
                    ),
                    if (e.startError != null)
                      Text(
                        e.startError!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    Text(
                      tr(context).discoveryState(
                        e.discoveryError ?? tr(context).discoveryOn,
                      ),
                    ),
                    Text(tr(context).nearbySeen('${e.nearby.length}')),
                    Text(
                      tr(context).trustedCount('${e.trustedDevices.length}'),
                    ),
                    Text(
                      tr(context).deviceKey(shortFingerprint(e.myFingerprint)),
                    ),
                    Text(e.secureStorageNote ?? tr(context).deviceKeySecure),
                    Text(tr(context).receivedGoTo(e.receiveLocationNote)),
                    Text(tr(context).encryptionNote),
                    Text(
                      tr(context).historyEntries(
                        e.history?.entries.length.toString() ??
                            tr(context).unavailable,
                      ),
                    ),
                    Text(tr(context).noAnalytics),
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
