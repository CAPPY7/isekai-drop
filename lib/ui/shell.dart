import 'dart:async';

import 'package:flutter/material.dart';

import '../engine/platform_engine.dart' show setKeepScreenOn;

import '../engine/transfer_engine.dart';
import 'app_scope.dart';
import 'screens/connect_screen.dart';
import 'screens/transfer_screen.dart';
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
  TransferEngine? _engine;
  PendingRequest? _showing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final e = AppScope.of(context).engine;
    if (e != _engine) {
      _engine?.removeListener(_onEngine);
      _engine = e..addListener(_onEngine);
      WidgetsBinding.instance.addPostFrameCallback((_) => _onEngine());
    }
  }

  @override
  void dispose() {
    _engine?.removeListener(_onEngine);
    super.dispose();
  }

  /// Shows approval dialogs for incoming pairing and transfer requests.
  bool _screenOn = false;

  void _onEngine() {
    if (!mounted) return;
    final active = _engine!.jobs.any((j) => j.isActive);
    if (active != _screenOn) {
      _screenOn = active;
      unawaited(setKeepScreenOn(active));
    }
    if (_showing != null) return;
    PendingRequest? next;
    for (final r in _engine!.pending) {
      if (!r.decided) {
        next = r;
        break;
      }
    }
    if (next == null) return;
    _showing = next;
    final req = next;
    unawaited(
      _ask(req).whenComplete(() {
        _showing = null;
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _onEngine());
        }
      }),
    );
  }

  /// One-tap "pair and send": the files arrive right after the pairing
  /// was accepted, without a second question. Open their progress screen.
  Future<void> _openIncoming(Set<String> before, PendingRequest r) async {
    final nav = Navigator.of(context);
    for (var i = 0; i < 40 && mounted; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      for (final j in _engine?.jobs ?? const <TransferJob>[]) {
        if (!before.contains(j.id) &&
            j.direction == JobDirection.receiving &&
            j.peerName == r.peerName) {
          if (mounted) {
            unawaited(
              nav.push(
                MaterialPageRoute<void>(builder: (_) => TransferScreen(job: j)),
              ),
            );
          }
          return;
        }
      }
    }
  }

  Future<void> _ask(PendingRequest r) async {
    final pairing = r.kind == RequestKind.pairing;
    final nav = Navigator.of(context);
    BuildContext? dialogCtx;
    var open = true;
    // Audit #7: close the dialog when the request ends without an answer
    // here (timeout, or the other device gave up).
    unawaited(
      r.decision.then((_) {
        final c = dialogCtx;
        if (open && c != null && c.mounted) Navigator.of(c).pop();
      }),
    );
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        dialogCtx = c;
        return AlertDialog(
          title: Text(
            pairing
                ? 'Accept ${r.peerName}?'
                : '${r.peerName} wants to send you files',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: pairing
                  ? [
                      Text(
                        r.offerCount > 0
                            ? '${platformLabel(r.peerPlatform)} device "${r.peerName}" wants to send you '
                                  '${r.offerCount} file(s), ${formatBytes(r.totalBytes)}.'
                            : '${platformLabel(r.peerPlatform)} device "${r.peerName}" wants to connect.',
                      ),
                      for (final n in r.fileNames.take(3))
                        Text('- $n', overflow: TextOverflow.ellipsis),
                      const SizedBox(height: IdSpacing.sm),
                      const Text(
                        'Accept to pair: both devices remember each other, so '
                        'next time files go straight to the usual question. '
                        'If you did not start this, tap Decline.',
                      ),
                      if (r.keyChanged) ...[
                        const SizedBox(height: IdSpacing.sm),
                        const Text(
                          'WARNING: a device with this id was paired before with a DIFFERENT key. '
                          'Accept only if you reinstalled or reset Isekai Drop on it. '
                          'Accepting replaces the old key.',
                          style: TextStyle(
                            color: IdColors.danger,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: IdSpacing.md),
                      Text(
                        'Optional check: the other screen shows the same code',
                        style: Theme.of(c).textTheme.bodySmall,
                      ),
                      SelectableText(
                        r.code ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2,
                        ),
                      ),
                    ]
                  : [
                      Text(
                        '${r.fileNames.length} file(s), ${formatBytes(r.totalBytes)} from trusted device "${r.peerName}".',
                      ),
                      const SizedBox(height: IdSpacing.sm),
                      if (r.resumeBytes > 0)
                        Text(
                          'Continues an interrupted transfer: ${formatBytes(r.resumeBytes)} are already here.',
                        ),
                      for (final n in r.fileNames.take(5))
                        Text('- $n', overflow: TextOverflow.ellipsis),
                      if (r.fileNames.length > 5)
                        Text('...and ${r.fileNames.length - 5} more'),
                    ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Decline'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Accept'),
            ),
          ],
        );
      },
    );
    open = false;
    if (r.decided) {
      if (r.expired && mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Request expired - nobody answered in time.'),
          ),
        );
      }
      return;
    }
    if (ok == true) {
      final before = {for (final j in _engine!.jobs) j.id};
      r.approve();
      if (pairing && r.offerCount > 0) unawaited(_openIncoming(before, r));
      final job = r.job;
      if (job != null && mounted) {
        unawaited(
          nav.push(
            MaterialPageRoute<void>(builder: (_) => TransferScreen(job: job)),
          ),
        );
      }
    } else {
      r.decline();
    }
  }

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
