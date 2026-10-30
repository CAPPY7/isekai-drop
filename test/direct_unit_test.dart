import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/direct/direct_link.dart';
import 'package:isekaidrop/engine/direct/route_choice.dart';
import 'package:isekaidrop/engine/direct/wifi_join.dart';

class _P implements DirectLinkPlatform {
  int hosts = 0, stops = 0;
  Object? error;
  Completer<void>? gate;
  final ev = StreamController<String>.broadcast();
  @override
  bool get canHost => true;
  @override
  bool get canJoin => true;
  @override
  Stream<String> get events => ev.stream;
  @override
  Future<String> permissionState() async => 'granted';
  @override
  Future<String> requestPermission() async => 'granted';
  @override
  Future<DirectLinkInfo> host({bool preferFiveGhz = true}) async {
    hosts++;
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return const DirectLinkInfo(
      kind: DirectKind.wifiDirect,
      ssid: 'DIRECT-AB-x',
      passphrase: 'abcdefgh',
      hostIp: '192.168.49.1',
    );
  }

  @override
  Future<void> stopHost() async => stops++;
  @override
  Future<DirectJoin> join(DirectLinkInfo l, {Duration? timeout}) async =>
      const DirectJoin();
  @override
  Future<void> leave() async {}
}

const fp = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

void main() {
  group('Wi-Fi QR', () {
    test('escapes and parses back special characters', () {
      const ssid = r'My;Net,"x":\y';
      const pass = r'p;a,s:s"\word';
      final q = wifiQrString(ssid, pass);
      expect(q, r'WIFI:S:My\;Net\,\"x\"\:\\y;T:WPA;P:p\;a\,s\:s\"\\word;;');
      expect(parseWifiQr(q), (ssid, pass));
    });
    test('parses fields in any order and rejects junk', () {
      expect(parseWifiQr('WIFI:T:WPA;P:abcdefgh;S:Home;;'), (
        'Home',
        'abcdefgh',
      ));
      expect(parseWifiQr('WIFI:S:Open;T:nopass;;'), ('Open', ''));
      expect(parseWifiQr('WIFI:S:Home;T:WPA;P:short;;'), isNull);
      expect(parseWifiQr('http://example.com'), isNull);
      expect(parseWifiQr('WIFI:T:WPA;P:abcdefgh;;'), isNull);
    });
  });

  group('Fast direct QR', () {
    test('round trip', () {
      final q = DirectQr(
        link: const DirectLinkInfo(
          kind: DirectKind.hotspot,
          ssid: 'AndroidShare_1234',
          passphrase: 'k3y with space',
          hostIp: '10.4.2.1',
          frequencyMhz: 5745,
        ),
        port: 47820,
        fingerprint: fp,
        name: 'Pixel',
      );
      final back = DirectQr.tryParse(q.encode())!;
      expect(back.link.kind, DirectKind.hotspot);
      expect(back.link.ssid, 'AndroidShare_1234');
      expect(back.link.passphrase, 'k3y with space');
      expect(back.link.hostIp, '10.4.2.1');
      expect(back.link.frequencyMhz, 5745);
      expect(back.port, 47820);
      expect(back.fingerprint, fp);
      expect(back.name, 'Pixel');
    });
    test('rejects bad values', () {
      String make(Map<String, String> q) => Uri(
        scheme: 'isekaidrop',
        path: 'direct',
        queryParameters: {
          'v': '1',
          'k': 'wifi_direct',
          's': 'DIRECT-AB-x',
          'w': 'abcdefgh',
          'h': '192.168.49.1',
          'p': '47820',
          'f': fp,
          ...q,
        },
      ).toString();
      expect(DirectQr.tryParse(make({})), isNotNull);
      expect(DirectQr.tryParse(make({'h': '999.1.1.1'})), isNull);
      expect(DirectQr.tryParse(make({'h': 'evil.example'})), isNull);
      expect(DirectQr.tryParse(make({'w': 'short'})), isNull);
      expect(DirectQr.tryParse(make({'k': 'bluetooth'})), isNull);
      expect(DirectQr.tryParse(make({'p': '0'})), isNull);
      expect(DirectQr.tryParse(make({'f': 'abc'})), isNull);
      expect(DirectQr.tryParse(make({'v': '2'})), isNull);
    });
  });

  test('band labels', () {
    expect(bandLabelFor(5180), '5 GHz (5180 MHz)');
    expect(bandLabelFor(2437), '2.4 GHz (2437 MHz)');
    expect(bandLabelFor(5955), '6 GHz (5955 MHz)');
    expect(bandLabelFor(null), 'band unknown');
  });

  test('random names and passwords are valid', () {
    final r = Random(1);
    for (var i = 0; i < 50; i++) {
      final s = randomDirectSsid(r);
      expect(s, matches(RegExp(r'^DIRECT-[A-Z2-9]{2}-IsekaiDrop$')));
      expect(isValidSsid(s), isTrue);
      expect(isValidPassphrase(randomPassphrase(r)), isTrue);
    }
  });

  test('when Fast direct is tried', () {
    String? w({
      bool e = true,
      bool j = true,
      String p = 'android',
      int b = 1 << 30,
    }) => directSkipReason(
      enabled: e,
      canJoin: j,
      peerPlatform: p,
      totalBytes: b,
    );
    expect(w(), isNull);
    expect(w(e: false), 'off');
    expect(w(j: false), 'unsupported');
    expect(w(p: 'windows'), 'not_android');
    expect(w(b: 1000), 'small');
  });

  test('0.11.0 Auto route decision', () {
    expect(autoRouteSkip(), 'auto_first');
    expect(autoRouteSkip(router: 7e6), isNull);
    expect(autoRouteSkip(router: 30e6), 'auto_router_good');
    expect(autoRouteSkip(direct: 25e6), isNull);
    expect(autoRouteSkip(direct: 5e6), 'auto_direct_slow');
    expect(autoRouteSkip(router: 7e6, direct: 9e6), isNull);
    expect(autoRouteSkip(router: 7e6, direct: 7.5e6), 'auto_router_faster');
    for (final c in [
      'auto_first',
      'auto_router_good',
      'auto_router_faster',
      'auto_direct_slow',
    ]) {
      expect(explainDirectError(c), startsWith('Auto: '));
    }
  });

  test('RouteStats smooths, saves and loads (speeds only)', () async {
    final d = await Directory.systemTemp.createTemp('isekai_rs');
    addTearDown(() => d.delete(recursive: true));
    final f = File('${d.path}/route_stats.json');
    final s = RouteStats(f);
    await s.record('dev1', 'router', 10e6);
    await s.record('dev1', 'router', 20e6);
    await s.record('dev1', 'bogus', 1);
    expect(s.speed('dev1', 'router'), 15e6);
    final t = RouteStats(f);
    await t.load();
    expect(t.speed('dev1', 'router'), 15e6);
    expect(t.speed('dev1', 'direct'), isNull);
    await f.writeAsString('{not json');
    final u = RouteStats(f);
    await u.load();
    expect(u.speed('dev1', 'router'), isNull);
  });

  test('every error code has plain words', () {
    for (final c in [
      'no_permission',
      'location_off',
      'wifi_off',
      'busy',
      'timeout',
      'declined',
      'incompatible_mode',
      'no_channel',
      'peer_no_permission',
    ]) {
      expect(explainDirectError(c), isNot(contains('($c)')));
    }
    expect(explainDirectError('weird'), contains('weird'));
  });

  group('DirectHostManager', () {
    test('ref count + idle stop', () async {
      final p = _P();
      final m = DirectHostManager(p, idle: const Duration(milliseconds: 50));
      await m.acquire();
      await m.acquire();
      expect(p.hosts, 1);
      m.release();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(m.active, isTrue);
      expect(m.hold(), isTrue);
      m.release();
      m.release();
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(m.active, isFalse);
      expect(p.stops, 1);
      expect(m.hold(), isFalse);
    });
    test('concurrent starts make one link', () async {
      final p = _P()..gate = Completer<void>();
      final m = DirectHostManager(p, idle: const Duration(milliseconds: 50));
      final a = m.acquire();
      final b = m.acquire();
      p.gate!.complete();
      await Future.wait([a, b]);
      expect(p.hosts, 1);
      expect(m.users, 2);
    });
    test(
      'failed start stops the half-made link and reports the code',
      () async {
        final p = _P()..error = const DirectLinkException('busy');
        final m = DirectHostManager(p);
        await expectLater(
          m.acquire(),
          throwsA(
            isA<DirectLinkException>().having((e) => e.code, 'code', 'busy'),
          ),
        );
        expect(p.stops, 1);
        expect(m.lastError, 'busy');
        expect(m.active, isFalse);
      },
    );
    test('start timeout', () async {
      final p = _P()..gate = Completer<void>();
      final m = DirectHostManager(
        p,
        startTimeout: const Duration(milliseconds: 50),
      );
      await expectLater(m.acquire(), throwsA(isA<DirectLinkException>()));
      expect(m.lastError, 'timeout');
      expect(p.stops, 1);
    });
    test('pinned stays on; system stop is noticed', () async {
      final p = _P();
      var changes = 0;
      final m = DirectHostManager(
        p,
        idle: const Duration(milliseconds: 30),
        onChange: () => changes++,
      );
      await m.acquire();
      m.setPinned(true);
      m.release();
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(m.active, isTrue);
      p.ev.add('host_stopped');
      await Future<void>.delayed(Duration.zero);
      expect(m.active, isFalse);
      expect(m.lastError, 'stopped');
      expect(changes, greaterThanOrEqualTo(2));
      await m.dispose();
    });
  });

  group('PC join commands', () {
    test('Windows profile escapes XML and has the SSID in hex', () {
      final x = windowsWlanProfileXml('A&B<"x">', 'p&ss<wd>"1');
      expect(x, contains('<name>A&amp;B&lt;&quot;x&quot;&gt;</name>'));
      expect(x, contains('<hex>4126423C2278223E</hex>'));
      expect(
        x,
        contains('<keyMaterial>p&amp;ss&lt;wd&gt;&quot;1</keyMaterial>'),
      );
      expect(x, contains('<connectionMode>manual</connectionMode>'));
      expect(x, isNot(contains('<"')));
    });
    test('commands are argument lists; passwords hidden in logs', () {
      final l = linuxJoinCommands('Net; rm -rf ~', 'secret12').single;
      expect(l.exe, 'nmcli');
      expect(l.args, [
        'device',
        'wifi',
        'connect',
        'Net; rm -rf ~',
        'password',
        'secret12',
      ]);
      expect(l.redacted(), isNot(contains('secret12')));
      final m = macJoinCommands('en0', 'Net', 'secret12').single;
      expect(m.args, ['-setairportnetwork', 'en0', 'Net', 'secret12']);
      expect(m.redacted(), isNot(contains('secret12')));
      final w = windowsJoinCommands('Net', r'C:\t\p.xml');
      expect(w[0].args, contains(r'filename=C:\t\p.xml'));
      expect(w[1].args, ['wlan', 'connect', 'name=Net', 'ssid=Net']);
    });
    test('macOS Wi-Fi device from networksetup output', () {
      const out = '''
Hardware Port: Ethernet
Device: en1
Ethernet Address: aa

Hardware Port: Wi-Fi
Device: en0
Ethernet Address: bb
''';
      expect(macWifiDevice(out), 'en0');
      expect(macWifiDevice('Hardware Port: Ethernet\nDevice: en1\n'), isNull);
    });
    test('join runs the commands through the runner (fake)', () async {
      final calls = <List<String>>[];
      final r = await joinWifiFromPc(
        'DIRECT-AB-x',
        'abcdefgh',
        run: (exe, args) async {
          calls.add([exe, ...args]);
          if (exe == 'networksetup' && args.first == '-listallhardwareports') {
            return ProcessResult(
              1,
              0,
              'Hardware Port: Wi-Fi\nDevice: en0\n',
              '',
            );
          }
          return ProcessResult(1, 0, '', '');
        },
      );
      expect(r.ok, isTrue);
      expect(calls, isNotEmpty);
      expect(r.log.join('\n'), isNot(contains('abcdefgh')));
    });
  });

  group('Windows Mobile Hotspot output', () {
    test('ok', () {
      final h = WindowsHotspot.parse(
        'noise\n{"ok":true,"ssid":"PC-1","pass":"abcdefgh","band":"FiveGigahertz"}\n',
      );
      expect(h.ok, isTrue);
      expect(h.ssid, 'PC-1');
      expect(h.passphrase, 'abcdefgh');
      expect(h.band, 'FiveGigahertz');
    });
    test('errors', () {
      expect(
        WindowsHotspot.parse('{"ok":false,"error":"no_shared_connection"}')
            .error,
        'no_shared_connection',
      );
      expect(WindowsHotspot.parse('').error, 'no_output');
      expect(WindowsHotspot.parse('{bad').error, 'bad_output');
      expect(
        explainWindowsHotspotError('no_shared_connection'),
        contains('network connection to share'),
      );
    });
  });
}
