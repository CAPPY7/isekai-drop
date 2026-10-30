// 0.10.2 striped multi-stream lanes: the bytes go round-robin over several
// TCP connections and must come back whole and in order.
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
  LaneKeys keys(Identity me, Identity peer) => LaneKeys(
    certPem: me.certPem,
    keyPem: me.keyPem,
    peerCertPem: peer.certPem,
    peerFingerprint: peer.fingerprint,
  );

  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('lanes'));
  tearDown(() async => dir.delete(recursive: true));

  Uint8List data(int n, int seed) {
    final r = Random(seed);
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }

  for (final raw in [false, true]) {
    for (final streams in [2, 4]) {
      test('${raw ? 'raw' : 'TLS'}, $streams streams: files arrive whole '
          'and in order', () async {
        const stripe = 64 * 1024; // small, so many stripes are crossed
        final srv = await LaneServer.start(
          keys: raw ? null : keys(b, a),
          raw: raw,
          streams: streams,
          stripe: stripe,
          bindAddress: InternetAddress.loopbackIPv4,
        );
        final cli = await LaneClient.connect(
          host: '127.0.0.1',
          port: srv.port,
          token: srv.token,
          keys: raw ? null : keys(a, b),
          streams: streams,
          stripe: stripe,
        );
        for (final (i, n) in [
          (1, 5 * 1024 * 1024 + 7),
          (2, 1000),
          (3, 77777),
        ]) {
          final bytes = data(n, i);
          final path = p.join(dir.path, 'f$i');
          final rx = srv.receiveFile(path: path, count: n, hash: true);
          // Odd piece sizes, so pieces straddle stripes.
          for (var o = 0; o < n; o += 99991) {
            await cli.add(Uint8List.sublistView(bytes, o, min(n, o + 99991)));
          }
          await cli.drain();
          final r = await rx;
          expect(r.bytes, n);
          expect(r.sha256, sha256.convert(bytes).toString());
          expect(await File(path).readAsBytes(), bytes);
          if (streams > 1) expect(r.note, contains('$streams streams'));
        }
        cli.close();
        srv.close();
      });
    }
  }

  test('speed sink counts all 4 streams', () async {
    final srv = await LaneServer.start(raw: true, streams: 4);
    final cli = await LaneClient.connect(
      host: '127.0.0.1',
      port: srv.port,
      token: srv.token,
      streams: 4,
    );
    final sink = srv.sink();
    final tx = await cli.generate(40 << 20, const Duration(seconds: 10));
    srv.sinkEnd(tx.bytes);
    final r = await sink;
    expect(tx.bytes, 40 << 20);
    expect(r.bytes, 40 << 20);
    cli.close();
    srv.close();
  });

  test('missing streams time out instead of hanging', () async {
    final srv = await LaneServer.start(
      raw: true,
      streams: 4,
      acceptTimeout: const Duration(seconds: 1),
    );
    final cli = await LaneClient.connect(
      host: '127.0.0.1',
      port: srv.port,
      token: srv.token,
      streams: 2,
    );
    await expectLater(
      srv.receiveFile(path: p.join(dir.path, 'm'), count: 10),
      throwsA(isA<LaneException>()),
    );
    cli.close();
    srv.close();
  });

  // Box numbers only: ISEKAI_LANE_BENCH=1 flutter test test/lane_streams_test.dart
  final bench = Platform.environment['ISEKAI_LANE_BENCH'] == '1';
  for (final raw in [true, false]) {
    for (final streams in [1, 2, 4]) {
      test(
        'bench ${raw ? 'raw' : 'TLS'} x$streams',
        skip: bench ? false : 'set ISEKAI_LANE_BENCH=1',
        () async {
          final srv = await LaneServer.start(
            keys: raw ? null : keys(b, a),
            raw: raw,
            streams: streams,
          );
          final cli = await LaneClient.connect(
            host: '127.0.0.1',
            port: srv.port,
            token: srv.token,
            keys: raw ? null : keys(a, b),
            streams: streams,
          );
          final rx = srv.sink();
          final tx = await cli.generate(512 << 20, const Duration(seconds: 15));
          srv.sinkEnd(tx.bytes);
          final r = await rx;
          // ignore: avoid_print
          print(
            'BENCH ${raw ? 'raw' : 'tls'} x$streams: '
            '${(r.bytes / r.micros).toStringAsFixed(1)} MB/s (box loopback)',
          );
          cli.close();
          srv.close();
        },
      );
    }
  }
}
