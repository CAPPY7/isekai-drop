// 0.10.1 data lanes: background-isolate TLS connections for file bytes.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/lane.dart';
import 'package:path/path.dart' as p;

void main() {
  final a = Identity.generate();
  final b = Identity.generate();
  final c = Identity.generate();
  LaneKeys keys(Identity me, Identity peer) => LaneKeys(
    certPem: me.certPem,
    keyPem: me.keyPem,
    peerCertPem: peer.certPem,
    peerFingerprint: peer.fingerprint,
  );

  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('lane'));
  tearDown(() async => dir.delete(recursive: true));

  Uint8List data(int n, int seed) {
    final r = Random(seed);
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }

  test('two files in a row arrive whole, with the right SHA-256', () async {
    final srv = await LaneServer.start(
      keys: keys(b, a),
      bindAddress: InternetAddress.loopbackIPv4,
    );
    final cli = await LaneClient.connect(
      host: '127.0.0.1',
      port: srv.port,
      token: srv.token,
      keys: keys(a, b),
    );
    for (final (i, n) in [(1, 9 * 1024 * 1024 + 7), (2, 1000)]) {
      final bytes = data(n, i);
      final path = p.join(dir.path, 'f$i');
      var seen = 0;
      final rx = srv.receiveFile(
        path: path,
        count: n,
        hash: true,
        onBytes: (k) => seen += k,
      );
      for (var o = 0; o < n; o += 300000) {
        await cli.add(Uint8List.sublistView(bytes, o, min(n, o + 300000)));
      }
      await cli.drain();
      final r = await rx;
      expect(r.bytes, n);
      expect(seen, n);
      expect(r.sha256, sha256.convert(bytes).toString());
      expect(await File(path).readAsBytes(), bytes);
    }
    cli.close();
    srv.close();
  });

  test('append continues a partial file and hashes all of it', () async {
    final all = data(3 * 1024 * 1024, 5);
    final path = p.join(dir.path, 'part');
    await File(path).writeAsBytes(all.sublist(0, 1000000));
    final srv = await LaneServer.start(keys: keys(b, a));
    final cli = await LaneClient.connect(
      host: '127.0.0.1',
      port: srv.port,
      token: srv.token,
      keys: keys(a, b),
    );
    final rx = srv.receiveFile(
      path: path,
      count: all.length - 1000000,
      append: true,
      hash: true,
      hashExisting: 1000000,
    );
    await cli.add(all.sublist(1000000));
    final r = await rx;
    expect(r.sha256, sha256.convert(all).toString());
    expect(await File(path).readAsBytes(), all);
    cli.close();
    srv.close();
  });

  test('an unpaired certificate is never accepted', () async {
    final srv = await LaneServer.start(
      keys: keys(b, a),
      acceptTimeout: const Duration(seconds: 2),
    );
    // With TLS 1.3 the client may think it connected; the receiver still
    // refuses it, so the receive never starts.
    LaneClient? cli;
    try {
      cli = await LaneClient.connect(
        host: '127.0.0.1',
        port: srv.port,
        token: srv.token,
        keys: keys(c, b),
      );
      await cli.add(Uint8List(10));
    } on LaneException {
      // Refused straight away: also fine.
    }
    await expectLater(
      srv.receiveFile(path: p.join(dir.path, 'z'), count: 10),
      throwsA(isA<LaneException>()),
    );
    expect(File(p.join(dir.path, 'z')).existsSync(), isFalse);
    cli?.close();
    srv.close();
  });

  test('a wrong token is refused', () async {
    final srv = await LaneServer.start(
      keys: keys(b, a),
      acceptTimeout: const Duration(seconds: 2),
    );
    final cli = await LaneClient.connect(
      host: '127.0.0.1',
      port: srv.port,
      token: newLaneToken(),
      keys: keys(a, b),
    );
    final rx = srv.receiveFile(path: p.join(dir.path, 'x'), count: 10);
    await cli.add(Uint8List(10)).catchError((_) {});
    await expectLater(rx, throwsA(isA<LaneException>()));
    cli.close();
    srv.close();
  });

  test('sender closing early fails the receive', () async {
    final srv = await LaneServer.start(keys: keys(b, a));
    final cli = await LaneClient.connect(
      host: '127.0.0.1',
      port: srv.port,
      token: srv.token,
      keys: keys(a, b),
    );
    final rx = srv.receiveFile(path: p.join(dir.path, 'y'), count: 1 << 20);
    await cli.add(Uint8List(1000));
    // (A close in the very first moments of the TLS handshake may not be
    // seen by the lane; the engine also watches the control connection.)
    await Future<void>.delayed(const Duration(milliseconds: 300));
    cli.close();
    await expectLater(rx, throwsA(isA<LaneException>()));
    srv.close();
  });

  for (final raw in [true, false]) {
    test(
      'speed stream (${raw ? 'raw TCP' : 'TLS'}) counts the bytes',
      () async {
        final srv = await LaneServer.start(
          keys: raw ? null : keys(b, a),
          raw: raw,
        );
        final cli = await LaneClient.connect(
          host: '127.0.0.1',
          port: srv.port,
          token: srv.token,
          keys: raw ? null : keys(a, b),
        );
        final rx = srv.sink();
        final tx = await cli.generate(64 << 20, const Duration(seconds: 10));
        final r = await rx;
        expect(tx.bytes, 64 << 20);
        expect(r.bytes, 64 << 20);
        expect(r.micros, greaterThan(0));
        // ignore: avoid_print
        print(
          '${raw ? 'raw' : 'tls'} lane: '
          '${(r.bytes / r.micros).toStringAsFixed(1)} MB/s',
        );
        cli.close();
        srv.close();
      },
    );
  }
}
