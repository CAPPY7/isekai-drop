import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../engine/platform_engine.dart';
import '../app_scope.dart';
import '../guides/guides.dart';
import '../qr_pairing.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';

/// Option C: Android makes a local-only hotspot (no internet). The other
/// device joins it, then pairs as usual.
class HotspotScreen extends StatefulWidget {
  const HotspotScreen({super.key});

  @override
  State<HotspotScreen> createState() => _HotspotScreenState();
}

class _HotspotScreenState extends State<HotspotScreen> {
  HotspotDetails? _details;
  String? _error;
  bool _busy = false;
  List<String> _addresses = const [];

  @override
  void dispose() {
    stopAppHotspot();
    super.dispose();
  }

  Future<bool> _explainAndAsk() async {
    var state = await hotspotPermission();
    if (state == HotspotPermission.granted) return true;
    if (!mounted) return false;
    if (state == HotspotPermission.needed) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Permission needed for the hotspot'),
          content: const Text(
            'Android only lets apps create a Wi-Fi hotspot with this permission.\n\n'
            'Android 13 and newer: "Nearby devices". Isekai Drop declares it is never used for location.\n\n'
            'Android 12 and older: "Location". Android requires it for hotspots; '
            'Isekai Drop never reads or stores your location.',
          ),
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
      if (ok != true) return false;
      state = await requestHotspotPermission();
    }
    if (state == HotspotPermission.locationOff) {
      setState(
        () => _error =
            'On Android 12 and older, Location must be switched on (quick settings) for the hotspot. '
            'Turn it on and tap Start again. You can turn it off after.',
      );
      return false;
    }
    if (state != HotspotPermission.granted) {
      setState(
        () => _error =
            'Permission was not given. You can allow it in Settings > Apps > Isekai Drop > Permissions, '
            'or use your phone\'s normal hotspot instead (see the guide).',
      );
      return false;
    }
    return true;
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await _explainAndAsk()) return;
      final d = await startAppHotspot();
      // Give the network a moment to get its address.
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      final addrs = await AppScope.of(context).engine.localAddresses();
      setState(() {
        _details = d;
        _addresses = addrs;
      });
    } on HotspotException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'The hotspot could not start on this phone.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    await stopAppHotspot();
    setState(() => _details = null);
  }

  @override
  Widget build(BuildContext context) {
    final engine = AppScope.of(context).engine;
    final d = _details;
    return Scaffold(
      appBar: AppBar(title: const Text('Make a hotspot')),
      body: PageBody(
        children: [
          const Text(
            'Isekai Drop can make a private Wi-Fi network on this phone, with no internet. '
            'Your computer joins it, then you pair and send as usual. '
            'The hotspot stops when you leave this screen.',
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: IdColors.danger)),
          if (d == null)
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(IdLayout.minTouchTarget),
              ),
              onPressed: _busy ? null : _start,
              icon: const Icon(Icons.wifi_tethering),
              label: Text(_busy ? 'Starting...' : 'Start hotspot'),
            )
          else ...[
            SectionCard(
              title: 'On the computer, join this Wi-Fi',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Network name'),
                  SelectableText(
                    d.ssid,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: IdSpacing.sm),
                  const Text('Password'),
                  SelectableText(
                    d.password,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: IdSpacing.md),
                  Center(
                    child: Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(IdSpacing.sm),
                      child: QrImageView(
                        data: d.wifiQr,
                        size: 200,
                        semanticsLabel: 'Wi-Fi QR code for this hotspot',
                      ),
                    ),
                  ),
                  const Text(
                    'Phones and tablets can join by scanning this Wi-Fi QR code with their camera. '
                    'On Windows or Mac, type the name and password.',
                  ),
                ],
              ),
            ),
            SectionCard(
              title: 'Then pair',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'On the computer open Connect. This phone should appear. '
                    'Or type: ${_addresses.isEmpty ? '(address not ready yet)' : _addresses.join(' or ')}  '
                    'port ${engine.listeningPort ?? '-'}',
                  ),
                  const SizedBox(height: IdSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () => showMyQr(context),
                    icon: const Icon(Icons.qr_code),
                    label: const Text('Show my pairing QR code'),
                  ),
                ],
              ),
            ),
            OutlinedButton(onPressed: _stop, child: const Text('Stop hotspot')),
          ],
          TextButton(
            onPressed: () => openGuide(context, guideAppHotspot),
            child: const Text('Step-by-step guide'),
          ),
        ],
      ),
    );
  }
}
