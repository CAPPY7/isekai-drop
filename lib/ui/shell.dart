import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../engine/platform_engine.dart'
    show askNotificationPermission, setKeepScreenOn, takeSharedFiles;
import '../engine/pick_result.dart';

import '../engine/transfer_engine.dart';
import 'app_scope.dart';
import 'notification_ask.dart';
import 'received_text.dart';
import 'ui_env.dart';
import 'shell_nav.dart';
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
  const AppShell({super.key, this.takeShared = takeSharedFiles});

  /// D1: files shared from another app (Android; tests pass a fake).
  final Future<PickResult> Function() takeShared;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
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
  void initState() {
    super.initState();
    shellTabRequest.addListener(_onTabRequest);
    WidgetsBinding.instance.addObserver(this);
    _checkShared();
  }

  /// D1: Android hands over shared files when the app starts or comes
  /// back (Share > Isekai Drop while it was open).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkShared();
  }

  void _checkShared() {
    widget.takeShared().then((r) {
      if (mounted) deliverShared(r);
    }, onError: (Object e) => _engine?.recordException('take_shared', e));
  }

  void _onTabRequest() {
    final i = shellTabRequest.value;
    if (i == null || !mounted) return;
    shellTabRequest.value = null;
    _go(i);
  }

  @override
  void dispose() {
    shellTabRequest.removeListener(_onTabRequest);
    WidgetsBinding.instance.removeObserver(this);
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
      if (active) _askNotifications();
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
    final isText = r.kind == RequestKind.text;
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
    final answer = await showDialog<Object>(
      context: context,
      barrierDismissible: false,
      builder: (c) {
        dialogCtx = c;
        return AlertDialog(
          title: Text(
            pairing
                ? 'Accept ${r.peerName}?'
                : isText
                ? '${r.peerName} wants to send you a text'
                : '${r.peerName} wants to send you files',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: isText
                  ? [
                      // E1: the text itself is shown only after Accept.
                      Text(
                        'A short text (${r.textBody?.characters.length ?? 0} '
                        'characters) from ${platformLabel(r.peerPlatform)} '
                        'device "${r.peerName}". It is shown after you accept.',
                      ),
                    ]
                  : pairing
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
                      if (r.replacesName != null) ...[
                        const SizedBox(height: IdSpacing.sm),
                        Text(
                          'You paired a device named "${r.replacesName}" before, '
                          'with a different key. This is probably that device after '
                          'Isekai Drop was reinstalled or reset on it. Accept only '
                          'if that is true; accepting replaces the old pairing.',
                          key: const ValueKey('pair-replaces'),
                          style: TextStyle(
                            color: idStatus(context).warning,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      if (r.keyChanged) ...[
                        const SizedBox(height: IdSpacing.sm),
                        Text(
                          'WARNING: a device with this id was paired before with a DIFFERENT key. '
                          'Accept only if you reinstalled or reset Isekai Drop on it. '
                          'Accepting replaces the old key.',
                          style: TextStyle(
                            color: idStatus(context).danger,
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
                        '${r.fileNames.length} file(s) · ${formatBytes(r.totalBytes)}',
                        style: Theme.of(c).textTheme.titleMedium,
                      ),
                      Text(
                        'From trusted ${platformLabel(r.peerPlatform)} device "${r.peerName}".',
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
                      // D3: only for a VERIFIED device (code compared).
                      if (r.peerVerified)
                        StatefulBuilder(
                          builder: (c2, set) => CheckboxListTile(
                            key: const ValueKey('request-always'),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            minTileHeight: IdLayout.minTouchTarget,
                            value: r.alwaysAllow,
                            onChanged: (v) =>
                                set(() => r.alwaysAllow = v ?? false),
                            title: const Text('Always allow this device'),
                            subtitle: const Text(
                              'Files from it are received without this '
                              'question. Turn off in Settings > Trusted devices.',
                            ),
                          ),
                        ),
                    ],
            ),
          ),
          // 0.11.0 (spec C12): big, well separated Accept / Decline.
          actionsPadding: const EdgeInsets.fromLTRB(
            IdSpacing.lg,
            0,
            IdSpacing.lg,
            IdSpacing.lg,
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const ValueKey('request-decline'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 56),
                    ),
                    onPressed: () => Navigator.pop(c, false),
                    icon: const Icon(Icons.close),
                    label: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: IdSpacing.md),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('request-accept'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 56),
                    ),
                    onPressed: () => Navigator.pop(c, true),
                    icon: const Icon(Icons.check),
                    label: const Text('Accept'),
                  ),
                ),
              ],
            ),
            // A3: refuse this key from now on, without asking again.
            if (pairing)
              Align(
                alignment: Alignment.center,
                child: TextButton.icon(
                  key: const ValueKey('request-block'),
                  style: TextButton.styleFrom(
                    foregroundColor: idStatus(context).danger,
                    minimumSize: const Size(0, IdLayout.minTouchTarget),
                  ),
                  onPressed: () => Navigator.pop(c, 'block'),
                  icon: const Icon(Icons.block),
                  label: const Text('Block this device'),
                ),
              ),
          ],
        );
      },
    );
    open = false;
    final ok = answer == true;
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
    if (ok == true && isText) {
      r.approve();
      if (mounted) {
        await showReceivedText(context, from: r.peerName, body: r.textBody!);
      }
    } else if (ok == true) {
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
    } else if (answer == 'block') {
      r.block();
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(
            content: Text('Blocked. Unblock it in Settings > Trusted devices.'),
          ),
        );
      }
    } else {
      r.decline();
    }
  }

  /// D2: Android 13+ needs permission for the progress notification.
  /// Asked once, at the first transfer, after our own explanation.
  void _askNotifications() {
    if (!Platform.isAndroid || !UiEnv.of(context).readPlatform) return;
    final settings = AppScope.of(context).settings;
    unawaited(
      maybeAskNotifications(
        context,
        alreadyAsked: () => settings.notificationsAsked,
        markAsked: settings.markNotificationsAsked,
        askSystem: askNotificationPermission,
      ),
    );
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
