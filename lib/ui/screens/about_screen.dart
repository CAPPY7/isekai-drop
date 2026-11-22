// E3 (0.12.1): Settings > About.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/platform_engine.dart' show currentBuildNumber;
import '../../engine/transfer_engine.dart';
import '../app_scope.dart';
import '../diag_report.dart';
import '../file_actions.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';

/// Where every test build is published (replaced by each new build).
const kLatestBuildUrl =
    'https://github.com/CAPPY7/isekai-drop/releases/tag/latest-build';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, this.buildNumber = currentBuildNumber});

  /// The build number (GitHub Actions run), null for a local build.
  final Future<String?> Function() buildNumber;

  @override
  Widget build(BuildContext context) {
    final engine = AppScope.of(context).engine;
    final theme = Theme.of(context);
    final fp = engine.myFingerprint;
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: PageBody(
        children: [
          SectionCard(
            title: 'Version',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Isekai Drop $kAppVersion',
                  style: theme.textTheme.titleMedium,
                ),
                FutureBuilder<String?>(
                  future: buildNumber(),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return const Text('Build: ...');
                    }
                    final b = snap.data;
                    return Text(
                      b == null || b.isEmpty
                          ? 'Build: local build (not from GitHub)'
                          : 'Build $b',
                    );
                  },
                ),
                const SizedBox(height: IdSpacing.xs),
                Text(
                  'A test build, not a public release.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'This device\'s key',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Short: ${shortFingerprint(fp)}',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: IdSpacing.xs),
                SelectableText(
                  fp,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                const SizedBox(height: IdSpacing.xs),
                Text(
                  'Your other devices know this device by this key. It '
                  'changes only if the app is reinstalled or reset.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Latest test build',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SelectableText(kLatestBuildUrl),
                const SizedBox(height: IdSpacing.sm),
                Wrap(
                  spacing: IdSpacing.sm,
                  runSpacing: IdSpacing.sm,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, IdLayout.minTouchTarget),
                      ),
                      onPressed: () => Clipboard.setData(
                        const ClipboardData(text: kLatestBuildUrl),
                      ),
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy link'),
                    ),
                    if (savedFileActions.canOpenLinks)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, IdLayout.minTouchTarget),
                        ),
                        onPressed: () => savedFileActions.openLink(
                          Uri.parse(kLatestBuildUrl),
                        ),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Open in browser'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'How to update',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Android: open the link above, download '
                  'isekai-drop-android-arm64.apk (or -universal.apk) and '
                  'install it over this app. Your paired devices and history '
                  'stay.',
                ),
                SizedBox(height: IdSpacing.xs),
                Text(
                  'Windows: download isekai-drop-windows-setup.exe and run it.',
                ),
                SizedBox(height: IdSpacing.xs),
                Text(
                  'Mac: download isekai-drop-macos.dmg and drag the app to '
                  'Applications (NOT TESTED on a Mac).',
                ),
                SizedBox(height: IdSpacing.xs),
                Text(
                  'iPhone/iPad: sign the new .ipa again with your own Apple '
                  'ID (NOT TESTED).',
                ),
                SizedBox(height: IdSpacing.xs),
                Text(
                  'Update both devices: devices with very different versions '
                  'may not understand each other.',
                ),
              ],
            ),
          ),
          SectionCard(
            title: 'Open-source software',
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, IdLayout.minTouchTarget),
                ),
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'Isekai Drop',
                  applicationVersion: kAppVersion,
                ),
                icon: const Icon(Icons.gavel_outlined),
                label: const Text('Licences'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
