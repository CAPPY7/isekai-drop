import 'package:flutter/material.dart';

import 'screens/connect_screen.dart';
import 'screens/files_screen.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/trusted_screen.dart';
import 'theme/design_tokens.dart';

class _Dest {
  const _Dest(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _dests = [
  _Dest('Home', Icons.home_outlined, Icons.home),
  _Dest('Send', Icons.upload_file_outlined, Icons.upload_file),
  _Dest('Connect', Icons.qr_code_2_outlined, Icons.qr_code_2),
  _Dest('History', Icons.history_outlined, Icons.history),
  _Dest('Settings', Icons.settings_outlined, Icons.settings),
];

/// Main frame. Phone/tablet: bottom bar. Desktop: side rail (separate layout).
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _go(int i) => setState(() => _index = i);

  void _openTrusted() => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => const TrustedDevicesScreen()));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final desktop = c.maxWidth >= IdLayout.desktopBreakpoint;
        final pages = [
          HomeScreen(
            onSend: () => _go(1),
            onConnect: () => _go(2),
            onTrusted: _openTrusted,
          ),
          FilesScreen(isDesktop: desktop),
          const ConnectScreen(),
          const HistoryScreen(),
          SettingsScreen(onTrusted: _openTrusted),
        ];
        final body = IndexedStack(index: _index, children: pages);
        final title = _index == 0 ? 'Isekai Drop' : _dests[_index].label;

        // Back on any tab except Home goes to Home first.
        return PopScope(
          canPop: _index == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _go(0);
          },
          child: desktop
              ? Scaffold(
                  body: Row(
                    children: [
                      NavigationRail(
                        extended: c.maxWidth >= 1200,
                        selectedIndex: _index,
                        onDestinationSelected: _go,
                        labelType: c.maxWidth >= 1200
                            ? NavigationRailLabelType.none
                            : NavigationRailLabelType.all,
                        leading: const Padding(
                          padding: EdgeInsets.symmetric(vertical: IdSpacing.md),
                          child: Icon(
                            Icons.water_drop_rounded,
                            color: IdColors.accentPurple,
                            size: 36,
                            semanticLabel: 'Isekai Drop',
                          ),
                        ),
                        destinations: [
                          for (final d in _dests)
                            NavigationRailDestination(
                              icon: Icon(d.icon),
                              selectedIcon: Icon(d.selectedIcon),
                              label: Text(d.label),
                            ),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(
                        child: Scaffold(
                          appBar: AppBar(title: Text(title)),
                          body: body,
                        ),
                      ),
                    ],
                  ),
                )
              : Scaffold(
                  appBar: AppBar(title: Text(title)),
                  body: body,
                  bottomNavigationBar: NavigationBar(
                    selectedIndex: _index,
                    onDestinationSelected: _go,
                    destinations: [
                      for (final d in _dests)
                        NavigationDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.selectedIcon),
                          label: d.label,
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
