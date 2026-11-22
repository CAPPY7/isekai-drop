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
import '../../l10n/l10n.dart';

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
      appBar: AppBar(title: Text(tr(context).aboutTitle)),
      body: PageBody(
        children: [
          SectionCard(
            title: tr(context).versionTitle,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context).appVersion(kAppVersion),
                  style: theme.textTheme.titleMedium,
                ),
                FutureBuilder<String?>(
                  future: buildNumber(),
                  builder: (context, snap) {
                    if (snap.connectionState != ConnectionState.done) {
                      return Text(tr(context).buildLoading);
                    }
                    final b = snap.data;
                    return Text(
                      b == null || b.isEmpty
                          ? tr(context).buildLocal
                          : tr(context).buildNumber(b),
                    );
                  },
                ),
                const SizedBox(height: IdSpacing.xs),
                Text(
                  tr(context).testBuildNote,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SectionCard(
            title: tr(context).thisDeviceKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context).shortKey(shortFingerprint(fp)),
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: IdSpacing.xs),
                SelectableText(
                  fp,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
                const SizedBox(height: IdSpacing.xs),
                Text(tr(context).keyHelp, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          SectionCard(
            title: tr(context).latestTestBuild,
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
                      label: Text(tr(context).copyLink),
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
                        label: Text(tr(context).openInBrowser),
                      ),
                  ],
                ),
              ],
            ),
          ),
          SectionCard(
            title: tr(context).howToUpdate,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr(context).updateAndroid),
                SizedBox(height: IdSpacing.xs),
                Text(tr(context).updateWindows),
                SizedBox(height: IdSpacing.xs),
                Text(tr(context).updateMac),
                SizedBox(height: IdSpacing.xs),
                Text(tr(context).updateIos),
                SizedBox(height: IdSpacing.xs),
                Text(tr(context).updateBoth),
              ],
            ),
          ),
          SectionCard(
            title: tr(context).openSource,
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const ValueKey('about-licences'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, IdLayout.minTouchTarget),
                ),
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'Isekai Drop',
                  applicationVersion: kAppVersion,
                ),
                icon: const Icon(Icons.gavel_outlined),
                label: Text(tr(context).licences),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
