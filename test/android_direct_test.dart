import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/android_direct.dart';
import 'package:isekaidrop/engine/direct/direct_link.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const ch = MethodChannel('isekai_drop/direct');
  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(ch, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'caps':
          return {'sdk': 34, 'p2p': true, 'canHost': true, 'canJoin': true};
        case 'permissionState':
          return 'granted';
        case 'host':
          return {
            'kind': 'wifi_direct',
            'ssid': 'DIRECT-ab-IsekaiDrop',
            'pass': 'abcdefgh23',
            'host': '192.168.49.1',
            'mhz': 5180,
          };
        case 'join':
          final a = call.arguments as Map;
          if (a['ssid'] == 'DIRECT-zz-busy') {
            throw PlatformException(code: 'busy');
          }
          return {'localIp': '192.168.49.23', 'mbps': 866, 'mhz': 0};
        default:
          return true;
      }
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(ch, null));

  test('caps, host and join map to the Dart types', () async {
    final d = (await AndroidDirectLinks.create())!;
    expect(d.canHost, isTrue);
    expect(d.canJoin, isTrue);
    expect(d.sdk, 34);
    expect(await d.permissionState(), 'granted');
    final link = await d.host();
    expect(link.kind, DirectKind.wifiDirect);
    expect(link.hostIp, '192.168.49.1');
    expect(link.bandLabel, contains('5'));
    expect(calls.last.arguments, {'preferFiveGhz': true});
    final j = await d.join(link, timeout: const Duration(seconds: 7));
    expect(j.localIp, '192.168.49.23');
    expect(j.linkMbps, 866);
    expect(j.frequencyMhz, 5180, reason: 'falls back to the host band');
    final args = calls.last.arguments as Map;
    expect(args['timeoutMs'], 7000);
    expect(args['kind'], 'wifi_direct');
  });

  test('native error codes become DirectLinkException codes', () async {
    final d = (await AndroidDirectLinks.create())!;
    final bad = DirectLinkInfo(
      kind: DirectKind.wifiDirect,
      ssid: 'DIRECT-zz-busy',
      passphrase: 'abcdefgh23',
      hostIp: '192.168.49.1',
    );
    await expectLater(
      d.join(bad),
      throwsA(isA<DirectLinkException>().having((e) => e.code, 'code', 'busy')),
    );
  });

  test('system events reach the events stream', () async {
    final d = (await AndroidDirectLinks.create())!;
    final got = <String>[];
    final sub = d.events.listen(got.add);
    await messenger.handlePlatformMessage(
      'isekai_drop/direct',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall('directEvent', 'host_stopped'),
      ),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(got, ['host_stopped']);
    await sub.cancel();
  });

  test('missing native side means no Fast direct, not a crash', () async {
    messenger.setMockMethodCallHandler(ch, null);
    expect(await AndroidDirectLinks.create(), isNull);
  });
}
