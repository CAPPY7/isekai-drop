import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../engine/core/engine.dart' show kDefaultPort;
import '../../engine/direct/wifi_join.dart';
import '../../engine/transfer_engine.dart';
import '../../settings/settings_controller.dart';
import '../app_scope.dart';
import '../pairing_flow.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';

/// Windows Mobile Hotspot's usual own address (Internet Connection Sharing).
const kWindowsHotspotHost = '192.168.137.1';

/// 0.10.0 "Fast direct": a Wi-Fi link between two devices with no router in
/// the middle. Android phones make the link (and use it automatically for
/// big files between two Android phones); PCs and iPhones join it here.
class FastDirectScreen extends StatefulWidget {
  const FastDirectScreen({super.key});

  @override
  State<FastDirectScreen> createState() => _FastDirectScreenState();
}

class _FastDirectScreenState extends State<FastDirectScreen> {
  String? _perm;
  bool _starting = false;
  String? _error;
  DirectLinkInfo? _link;
  late TransferEngine _engine;
  bool _opened = false;

  // Windows hotspot
  WindowsHotspot? _win;
  bool _winBusy = false;

  // PC join
  final _ssid = TextEditingController();
  final _pass = TextEditingController();
  final _paste = TextEditingController();
  bool _joining = false;
  String? _joinMsg;
  bool _joinOk = false;
  String? _joinedSsid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _engine = AppScope.of(context).engine;
    _link ??= _engine.hostedDirectLink;
    if (_perm == null && _engine.canHostDirect) unawaited(_refreshPerm());
  }

  @override
  void dispose() {
    // The link is not cut here: a transfer may still use it. It stops by
    // itself 30 s after the last transfer on it.
    if (_opened) unawaited(_engine.closeDirectLink());
    _ssid.dispose();
    _pass.dispose();
    _paste.dispose();
    super.dispose();
  }

  Future<void> _refreshPerm() async {
    final p = await _engine.directPermissionState();
    if (mounted) setState(() => _perm = p);
  }

  Future<bool> _ensurePermission() async {
    var p = await _engine.directPermissionState();
    if (p == 'denied') {
      if (!mounted) return false;
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.wifi_tethering),
          title: const Text('Allow Fast direct?'),
          content: Text(directPermissionExplanation()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Not now'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      if (go != true) return false;
      p = await _engine.requestDirectPermission();
    }
    if (mounted) setState(() => _perm = p);
    if (p != 'granted') {
      if (mounted) {
        setState(
          () => _error = p == 'denied'
              ? '${explainDirectError('no_permission')} If no prompt '
                    'appears, allow it in Android Settings > Apps > Isekai Drop > Permissions.'
              : explainDirectError(p == 'unsupported' ? 'unsupported' : p),
        );
      }
      return false;
    }
    return true;
  }

  Future<void> _start() async {
    setState(() => _error = null);
    if (!await _ensurePermission()) return;
    if (!mounted) return;
    setState(() => _starting = true);
    try {
      final link = await _engine.openDirectLink();
      _opened = true;
      if (mounted) setState(() => _link = link);
    } on DirectLinkException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'The fast link could not start ($e).');
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _stop() async {
    await _engine.closeDirectLink(now: true);
    _opened = false;
    if (mounted) setState(() => _link = null);
  }

  Future<void> _startWindowsHotspot() async {
    setState(() {
      _winBusy = true;
      _win = null;
    });
    final r = await startWindowsHotspot();
    _engine.diagLog.add(
      r.ok ? 'win_hotspot_ok' : 'win_hotspot_${r.error}',
      r.ok
          ? 'Windows Mobile Hotspot on (${r.band ?? 'band unknown'}).'
          : explainWindowsHotspotError(r.error),
    );
    if (mounted) {
      setState(() {
        _win = r;
        _winBusy = false;
      });
    }
  }

  void _usePasted() {
    final raw = _paste.text.trim();
    final d = DirectQr.tryParse(raw);
    if (d != null) {
      _ssid.text = d.link.ssid;
      _pass.text = d.link.passphrase;
      setState(() => _joinMsg = 'Read the link of ${d.name}.');
      return;
    }
    final w = parseWifiQr(raw);
    if (w != null) {
      _ssid.text = w.$1;
      _pass.text = w.$2;
      setState(() => _joinMsg = null);
      return;
    }
    setState(
      () => _joinMsg =
          'That is not a Wi-Fi code or an Isekai Drop Fast direct link.',
    );
  }

  Future<void> _pcJoin() async {
    final ssid = _ssid.text.trim();
    final pass = _pass.text;
    if (!isValidSsid(ssid) || !isValidPassphrase(pass)) {
      setState(() {
        _joinOk = false;
        _joinMsg =
            'Type the network name and its password (8 to 63 characters).';
      });
      return;
    }
    setState(() {
      _joining = true;
      _joinMsg = null;
    });
    final direct = DirectQr.tryParse(_paste.text.trim());
    final r = await joinWifiFromPc(ssid, pass);
    for (final l in r.log) {
      _engine.diagLog.add('pc_join', l);
    }
    if (!mounted) return;
    setState(() {
      _joining = false;
      _joinOk = r.ok;
      _joinMsg = r.message;
      if (r.ok) _joinedSsid = ssid;
    });
    if (!r.ok) return;
    if (direct != null) {
      _engine.noteDirectPeer(
        direct.link.hostIp,
        direct.port,
        direct.fingerprint,
      );
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      await pairOverDirectLink(context, direct);
    } else {
      unawaited(_engine.scanNetwork());
    }
  }

  Future<void> _pcLeave() async {
    final s = _joinedSsid;
    if (s == null) return;
    await leaveWifiFromPc(s);
    _engine.forgetDirectPeer();
    if (mounted) {
      setState(() {
        _joinedSsid = null;
        _joinOk = false;
        _joinMsg = 'Left $s.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Fast direct (no router)')),
    body: ListenableBuilder(
      listenable: _engine,
      builder: (context, _) {
        final hosted = _engine.hostedDirectLink ?? _link;
        final joined = _engine.joinedDirectLink;
        return PageBody(
          children: [
            const Card(
              child: Padding(
                padding: EdgeInsets.all(IdSpacing.md),
                child: Text(
                  'Fast direct links two devices straight over Wi-Fi, with no '
                  'router in between. Between two Android phones it is used '
                  'automatically for big transfers when both have it on. '
                  'Your normal Wi-Fi is always the fallback.',
                ),
              ),
            ),
            if (_engine.canHostDirect) _hostCard(hosted),
            if (joined != null) _joinedCard(joined),
            if (Platform.isWindows) _windowsCard(),
            if (canJoinFromPc) _pcJoinCard(),
            if (Platform.isIOS) _iphoneCard(),
            if (!_engine.canHostDirect && !canJoinFromPc && !Platform.isIOS)
              const StateMessage(
                icon: Icons.wifi_off,
                title: 'Not available here',
                message: 'This device cannot make or join a fast link.',
              ),
          ],
        );
      },
    ),
  );

  Widget _hostCard(DirectLinkInfo? link) {
    final port = _engine.listeningPort ?? kDefaultPort;
    return SectionCard(
      title: 'Share my fast link',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_perm != null && _perm != 'granted' && link == null)
            Padding(
              padding: const EdgeInsets.only(bottom: IdSpacing.sm),
              child: Text(directPermissionExplanation()),
            ),
          if (link == null) ...[
            const Text(
              'Makes a Wi-Fi link on this phone. Another phone, a PC or an '
              'iPhone joins it by scanning a code. Your internet is not shared.',
            ),
            const SizedBox(height: IdSpacing.sm),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(IdLayout.minTouchTarget),
              ),
              onPressed: _starting ? null : _start,
              icon: _starting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.wifi_tethering),
              label: Text(_starting ? 'Starting...' : 'Start fast link'),
            ),
          ] else ...[
            Text(
              '${link.kind.label} on, ${link.bandLabel}.',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: IdSpacing.sm),
            _LinkQrs(
              appQr: DirectQr(
                link: link,
                port: port,
                fingerprint: _engine.myFingerprint,
                name: _engine.myName,
              ).encode(),
              wifiQr: wifiQrString(link.ssid, link.passphrase),
            ),
            const SizedBox(height: IdSpacing.sm),
            _CopyRow(label: 'Network', value: link.ssid),
            _CopyRow(label: 'Password', value: link.passphrase),
            _CopyRow(label: 'This phone', value: '${link.hostIp}:$port'),
            const SizedBox(height: IdSpacing.sm),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(IdLayout.minTouchTarget),
              ),
              onPressed: _stop,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop fast link'),
            ),
            const SizedBox(height: IdSpacing.xs),
            Text(
              'It also stops by itself 30 seconds after you leave this '
              'screen and nothing is being sent over it.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: IdSpacing.sm),
              child: Text(
                _error!,
                style: TextStyle(color: idStatus(context).danger),
              ),
            ),
        ],
      ),
    );
  }

  Widget _joinedCard(DirectLinkInfo link) => SectionCard(
    title: 'Joined a fast link',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${link.ssid} (${link.kind.label}, ${link.bandLabel}).'),
        const SizedBox(height: IdSpacing.sm),
        OutlinedButton(
          onPressed: () => _engine.leaveDirectLink(),
          child: const Text('Leave fast link'),
        ),
      ],
    ),
  );

  Widget _windowsCard() => SectionCard(
    title: 'Let a phone join this PC',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Turns on Windows Mobile Hotspot so a phone can join this PC '
          'directly. For more speed set its Band to 5 GHz in Settings > '
          'Mobile hotspot (if your Wi-Fi card offers it).',
        ),
        const SizedBox(height: IdSpacing.sm),
        Wrap(
          spacing: IdSpacing.sm,
          runSpacing: IdSpacing.sm,
          children: [
            FilledButton.icon(
              onPressed: _winBusy ? null : _startWindowsHotspot,
              icon: const Icon(Icons.wifi_tethering),
              label: Text(_winBusy ? 'Starting...' : 'Start Windows hotspot'),
            ),
            OutlinedButton.icon(
              onPressed: () => openWindowsHotspotSettings(),
              icon: const Icon(Icons.settings_outlined),
              label: const Text('Open Mobile hotspot settings'),
            ),
          ],
        ),
        if (_win != null && !_win!.ok)
          Padding(
            padding: const EdgeInsets.only(top: IdSpacing.sm),
            child: Text(
              explainWindowsHotspotError(_win!.error),
              style: TextStyle(color: idStatus(context).danger),
            ),
          ),
        if (_win != null && _win!.ok) ...[
          const SizedBox(height: IdSpacing.sm),
          Text(
            'Mobile hotspot is on${_win!.band != null ? ' (${_win!.band})' : ''}. '
            'On the phone: scan this with Isekai Drop (Connect > Scan QR code) '
            'or the camera / Wi-Fi settings. Then open Connect: this PC appears, '
            'or scan its pairing QR code.',
          ),
          const SizedBox(height: IdSpacing.sm),
          Center(
            child: _Qr(
              data: wifiQrString(_win!.ssid!, _win!.passphrase!),
              label: 'Wi-Fi code for this PC\'s hotspot',
            ),
          ),
          _CopyRow(label: 'Network', value: _win!.ssid!),
          _CopyRow(label: 'Password', value: _win!.passphrase!),
          const _CopyRow(label: 'This PC', value: kWindowsHotspotHost),
        ],
      ],
    ),
  );

  Widget _pcJoinCard() => SectionCard(
    title: 'Join a phone\'s fast link',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'On the Android phone open Connect > Fast direct > Start fast link. '
          'Type the network name and password shown there (or paste the '
          'Isekai Drop link text). This PC then joins it with the system '
          'Wi-Fi tools. Your internet may be off while joined.',
        ),
        const SizedBox(height: IdSpacing.sm),
        TextField(
          controller: _paste,
          decoration: InputDecoration(
            labelText: 'Optional: paste isekaidrop:direct... or WIFI:...',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              tooltip: 'Use pasted text',
              icon: const Icon(Icons.input),
              onPressed: _usePasted,
            ),
          ),
          onSubmitted: (_) => _usePasted(),
        ),
        const SizedBox(height: IdSpacing.sm),
        TextField(
          controller: _ssid,
          decoration: const InputDecoration(
            labelText: 'Network name (e.g. DIRECT-xy-IsekaiDrop)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: IdSpacing.sm),
        TextField(
          controller: _pass,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _pcJoin(),
        ),
        const SizedBox(height: IdSpacing.sm),
        Wrap(
          spacing: IdSpacing.sm,
          children: [
            FilledButton(
              onPressed: _joining ? null : _pcJoin,
              child: Text(_joining ? 'Joining...' : 'Join'),
            ),
            if (_joinedSsid != null)
              OutlinedButton(onPressed: _pcLeave, child: const Text('Leave')),
          ],
        ),
        if (_joinMsg != null)
          Padding(
            padding: const EdgeInsets.only(top: IdSpacing.sm),
            child: Text(
              _joinMsg!,
              style: TextStyle(
                color: _joinOk
                    ? idStatus(context).success
                    : idStatus(context).danger,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _iphoneCard() => const SectionCard(
    title: 'Join an Android phone\'s fast link',
    child: Text(
      '1. On the Android phone open Connect > Fast direct > Start fast link '
      'and show the "PC / iPhone camera" code.\n'
      '2. Scan it with the iPhone Camera app and tap Join.\n'
      '3. Back in Isekai Drop tap Connect > Scan QR code and scan the '
      '"Isekai Drop" code on the phone.',
    ),
  );
}

/// Settings > Connection: the Fast direct switch (Android only) and its
/// permission, explained before Android's own prompt.
class FastDirectSetting extends StatefulWidget {
  const FastDirectSetting({super.key});

  @override
  State<FastDirectSetting> createState() => _FastDirectSettingState();
}

class _FastDirectSettingState extends State<FastDirectSetting> {
  String? _perm;
  bool _asked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final engine = AppScope.of(context).engine;
    if (_perm == null && engine.canHostDirect) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    final p = await AppScope.of(context).engine.directPermissionState();
    if (mounted) setState(() => _perm = p);
  }

  Future<void> _allow() async {
    final p = await AppScope.of(context).engine.requestDirectPermission();
    if (mounted) {
      setState(() {
        _perm = p;
        _asked = true;
      });
    }
  }

  static const _labels = {
    SettingsController.routeAuto: 'Auto (fastest)',
    SettingsController.routeRouter: 'Router only',
    SettingsController.routeDirect: 'Fast direct always',
  };

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    if (!scope.engine.canHostDirect) return const SizedBox.shrink();
    final settings = scope.settings;
    final perm = _perm;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final needsPerm =
            settings.fastDirect && perm != null && perm != 'granted';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 0.11.0 (spec A5/A6): one line + info icon; the route choice
            // with the "Allow" button right next to it.
            SettingRow(
              title: 'Fast direct',
              summary: needsPerm && perm == 'denied'
                  ? 'Needs a permission to work'
                  : 'Route for big files to Android phones',
              info:
                  'Auto (fastest): the first big transfer to a phone uses your '
                  'router and its speed is measured. A direct phone-to-phone '
                  'Wi-Fi link is tried later only if the router was slower than '
                  '20 MB/s, and kept only if it was clearly faster. Only speeds '
                  'are remembered, on this device.\n\n'
                  'Router only: never make a direct link.\n\n'
                  'Fast direct always: try a direct link for every big transfer '
                  'to another Android phone (the 0.10 behaviour). If it cannot '
                  'be made, the router is used.\n\n'
                  'The transfer screen shows which route was used.\n\n'
                  '${directPermissionExplanation()}',
              extra: needsPerm && perm == 'denied'
                  ? FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, IdLayout.minTouchTarget),
                      ),
                      onPressed: _allow,
                      child: const Text('Allow'),
                    )
                  : null,
              wideControl: true,
              control: DropdownButton<String>(
                key: const ValueKey('route-mode'),
                value: settings.routeMode,
                items: [
                  for (final m in SettingsController.routeModes)
                    DropdownMenuItem(value: m, child: Text(_labels[m]!)),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  await settings.setRouteMode(v);
                  if (v != SettingsController.routeRouter && perm == 'denied') {
                    await _allow();
                  }
                },
              ),
            ),
            if (needsPerm && perm == 'denied' && _asked)
              Text(
                'Still not allowed. Allow it in Android Settings > Apps > '
                'Isekai Drop > Permissions.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (needsPerm && perm != 'denied')
              EmptyLine(
                icon: Icons.warning_amber_rounded,
                text: explainDirectError(perm),
                info: directPermissionExplanation(),
              ),
          ],
        );
      },
    );
  }
}

/// Why Android asks for the permission, in plain words.
String directPermissionExplanation() =>
    'Android needs the "Nearby devices" permission (Android 13 and newer) or '
    'Location (Android 12 and older) before an app may make or join a direct '
    'Wi-Fi link. Isekai Drop never reads your location; it only makes the link.';

class _LinkQrs extends StatefulWidget {
  const _LinkQrs({required this.appQr, required this.wifiQr});
  final String appQr;
  final String wifiQr;

  @override
  State<_LinkQrs> createState() => _LinkQrsState();
}

class _LinkQrsState extends State<_LinkQrs> {
  bool _wifi = false;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: false, label: Text('Isekai Drop')),
          ButtonSegment(value: true, label: Text('PC / iPhone camera')),
        ],
        selected: {_wifi},
        onSelectionChanged: (s) => setState(() => _wifi = s.first),
      ),
      const SizedBox(height: IdSpacing.sm),
      _Qr(
        data: _wifi ? widget.wifiQr : widget.appQr,
        label: _wifi ? 'Wi-Fi code' : 'Isekai Drop Fast direct code',
      ),
      const SizedBox(height: IdSpacing.xs),
      Text(
        _wifi
            ? 'Joins the link from a camera or Wi-Fi settings. Then pair as usual.'
            : 'Scan in Isekai Drop on the other device: joins the link and pairs in one go.',
        textAlign: TextAlign.center,
      ),
    ],
  );
}

class _Qr extends StatelessWidget {
  const _Qr({required this.data, required this.label});
  final String data;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.all(IdSpacing.sm),
    child: QrImageView(
      key: ValueKey('qr:$data'),
      data: data,
      size: 240,
      semanticsLabel: label,
    ),
  );
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      SizedBox(width: 90, child: Text(label)),
      Expanded(child: SelectableText(value)),
      IconButton(
        tooltip: 'Copy $label',
        icon: const Icon(Icons.copy, size: 18),
        onPressed: () => Clipboard.setData(ClipboardData(text: value)),
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// After scanning a Fast direct or Wi-Fi code

Future<T?> _withProgress<T>(
  BuildContext context,
  String text,
  Future<T> Function() work,
) async {
  final nav = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      content: Row(
        children: [
          const CircularProgressIndicator(semanticsLabel: 'Working'),
          const SizedBox(width: IdSpacing.md),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
  try {
    return await work();
  } finally {
    nav.pop();
  }
}

/// Pairs (or just confirms) with the device from a Fast direct code once
/// this device is on its link.
Future<void> pairOverDirectLink(BuildContext context, DirectQr qr) async {
  final engine = AppScope.of(context).engine;
  final fp = qr.fingerprint.toLowerCase();
  final known = engine.trustedDevices.where(
    (t) => t.fingerprint.toLowerCase() == fp && t.isTrusted,
  );
  if (known.isNotEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'On the fast link with ${known.first.name}. Send files as usual.',
        ),
      ),
    );
    return;
  }
  await startPairingFlow(
    context,
    qr.link.hostIp,
    qr.port,
    expectFingerprint: fp,
    peerName: qr.name,
  );
}

/// A scanned Isekai Drop Fast direct code: join the link, then pair.
Future<void> joinScannedDirect(BuildContext context, DirectQr qr) async {
  final engine = AppScope.of(context).engine;
  if (Platform.isIOS) {
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Join the Wi-Fi first'),
        content: Text(
          'iPhone apps cannot join Wi-Fi by themselves. Open Settings > Wi-Fi '
          'and join "${qr.link.ssid}" with password ${qr.link.passphrase} '
          '(or scan the phone\'s "PC / iPhone camera" code with the Camera '
          'app). Then come back and tap Continue.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    engine.noteDirectPeer(qr.link.hostIp, qr.port, qr.fingerprint);
    await pairOverDirectLink(context, qr);
    return;
  }
  try {
    if (engine.canJoinDirect) {
      final perm = await engine.directPermissionState();
      if (perm == 'denied') {
        if (!context.mounted) return;
        final go = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Allow Fast direct?'),
            content: Text(directPermissionExplanation()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text('Not now'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        if (go != true) return;
        await engine.requestDirectPermission();
      }
      if (!context.mounted) return;
      await _withProgress(
        context,
        'Joining the fast link of ${qr.name}... Android may ask you to '
        'confirm the connection.',
        () => engine.joinDirectLink(
          qr.link,
          peerFingerprint: qr.fingerprint,
          peerPort: qr.port,
        ),
      );
    } else if (canJoinFromPc) {
      final r = await _withProgress(
        context,
        'Joining ${qr.link.ssid}...',
        () => joinWifiFromPc(qr.link.ssid, qr.link.passphrase),
      );
      if (r == null || !r.ok) {
        throw DirectLinkException('pc_join', r?.message);
      }
      engine.noteDirectPeer(qr.link.hostIp, qr.port, qr.fingerprint);
      await Future<void>.delayed(const Duration(seconds: 2));
    } else {
      throw const DirectLinkException('old_android');
    }
  } on DirectLinkException catch (e) {
    if (!context.mounted) return;
    await showPairingProblem(
      context,
      'Could not join the fast link',
      '${_problemText(e)}\n\nYou can still pair over your normal '
          'Wi-Fi: scan the other device\'s normal pairing QR code.',
    );
    return;
  }
  if (!context.mounted) return;
  await pairOverDirectLink(context, qr);
}

/// A scanned standard Wi-Fi code (e.g. a Windows PC's Mobile Hotspot):
/// join it, then look for devices there.
Future<void> joinScannedWifi(
  BuildContext context,
  String ssid,
  String pass,
) async {
  final engine = AppScope.of(context).engine;
  try {
    if (engine.canJoinDirect && isValidPassphrase(pass)) {
      await _withProgress(
        context,
        'Joining $ssid... Android may ask you to confirm the connection.',
        () => engine.joinDirectLink(
          DirectLinkInfo(
            kind: DirectKind.windowsHotspot,
            ssid: ssid,
            passphrase: pass,
            hostIp: kWindowsHotspotHost,
          ),
        ),
      );
    } else if (canJoinFromPc && isValidPassphrase(pass)) {
      final r = await _withProgress(
        context,
        'Joining $ssid...',
        () => joinWifiFromPc(ssid, pass),
      );
      if (r == null || !r.ok) throw DirectLinkException('pc_join', r?.message);
    } else {
      throw const DirectLinkException(
        'manual',
        'Join this Wi-Fi in the system Wi-Fi settings, then open Connect.',
      );
    }
  } on DirectLinkException catch (e) {
    if (!context.mounted) return;
    await showPairingProblem(context, 'Could not join $ssid', _problemText(e));
    return;
  }
  unawaited(engine.scanNetwork());
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Joined $ssid. Looking for devices there (or scan their pairing QR code).',
      ),
    ),
  );
}

String _problemText(DirectLinkException e) =>
    (e.code == 'pc_join' || e.code == 'manual') && e.detail != null
    ? e.detail!
    : e.message;

/// Entry for the Connect screen.
void openFastDirect(BuildContext context) => Navigator.of(context)
    .push(MaterialPageRoute<void>(builder: (_) => const FastDirectScreen()));
