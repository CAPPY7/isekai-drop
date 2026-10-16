import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/demo_engine.dart';
import 'package:isekaidrop/engine/models.dart';

void main() {
  test('demo engine is labelled demo and records have ids and times', () async {
    final e = DemoTransferEngine(latency: Duration.zero);
    expect(e.isDemo, isTrue);
    for (final d in await e.trustedDevices()) {
      expect(d.id, isNotEmpty);
      expect(d.name, startsWith('DEMO'));
      expect(d.updatedAt.isBefore(d.createdAt), isFalse);
    }
  });

  test('revoke removes trust and marks nearby device unknown', () async {
    final e = DemoTransferEngine(latency: Duration.zero);
    await e.revokeTrustedDevice('demo-dev-1');
    expect(
      (await e.trustedDevices()).any((d) => d.id == 'demo-dev-1'),
      isFalse,
    );
    final n = (await e.nearbyDevices()).firstWhere((d) => d.id == 'demo-dev-1');
    expect(n.trust, TrustLevel.unknown);
  });

  test('formatBytes', () {
    expect(formatBytes(500), '500 B');
    expect(formatBytes(1536), '1.5 KB');
    expect(formatBytes(1073741824), '1.0 GB');
  });
}
