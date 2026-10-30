// Real-network e2e client (see AGENTS.md, "Network-namespace e2e").
// Skipped unless E2E_CLIENT=1. Uses "Search this network" to find the
// peer from e2e_peer_test.dart on another network stack, pairs with it
// by address, sends a file, then waits for the peer's file back.
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:path/path.dart' as p;

import 'e2e_native_hash.dart';

void main() {
  final env = Platform.environment;
  test(
    'e2e client: search, pair, send, receive',
    () async {
      final dir = Directory(env['E2E_DIR'] ?? '/tmp/e2e-client')
        ..createSync(recursive: true);
      void say(String s) {
        // ignore: avoid_print
        print('${DateTime.now().toIso8601String()} $s');
      }

      final inbox = Directory(p.join(dir.path, 'inbox'))
        ..createSync(recursive: true);
      final store = TrustStore(File(p.join(dir.path, 'trusted.json')));
      await store.load();
      final e = IsekaiEngine(
        identity: Identity.generate(),
        trust: store,
        deviceName: () => 'E2E-Client',
        platformName: 'linux',
        tempDir: inbox,
        finalizer: directoryFinalizer(inbox),
        fileDigest: e2eNativeHash ? nativeFileSha256 : null,
        port: int.parse(env['E2E_PORT'] ?? '47830'),
        bindAddress: InternetAddress.anyIPv4,
      );
      e.debugAutoDecide = (r) async {
        say('APPROVE ${r.kind.name} from ${r.peerName}');
        return true;
      };
      await e.start();
      final sw = Stopwatch()..start();
      final n = await e.scanNetwork(port: 47820);
      say(
        'SCAN found=$n in ${sw.elapsedMilliseconds} ms: '
        '${e.nearby.map((d) => '${d.name}@${d.host}:${d.port}')}',
      );
      final peer = e.nearby.firstWhere((d) => d.name == 'E2E-Host');
      final src = File(env['E2E_SEND_FILE']!);
      say(
        'SENDING ${p.basename(src.path)} ${src.lengthSync()} bytes '
        'sha256=${sha256.convert(src.readAsBytesSync())}',
      );
      final TransferJob job;
      if (env['E2E_MODE'] == 'classic') {
        final s = await e.beginPairing(peer.host, peer.port);
        await s.confirm();
        say('PAIRED ${e.trustedDevices.map((d) => d.name)}');
        // E2E_VIA=host:port sends through a proxy (for example one that
        // adds network delay); pairing above still goes direct.
        final via = env['E2E_VIA']?.split(':');
        job = await e.send(
          e.trustedDevices.single,
          [e2eNativeHash ? NativeHashFileSource(src) : FileSendSource(src)],
          host: via?[0] ?? peer.host,
          port: via == null ? peer.port : int.parse(via[1]),
        );
      } else {
        // 0.9.1 one tap: send to the UNPAIRED device; it asks once.
        say('ONE-TAP send to unpaired ${peer.name} (trusted=${peer.trusted})');
        job = await e.sendToNearby(peer, [FileSendSource(src)]);
        say(
          'PAIRED ${e.trustedDevices.map((d) => '${d.name}:${d.status.name}')}',
        );
      }
      while (job.isActive) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      say('SEND RESULT ${job.state.name} ${job.message ?? ''}');
      say(
        'SPEED avg=${((job.averageSpeed ?? 0) / 1048576).toStringAsFixed(1)}'
        'MB/s bytes=${job.totalBytes} time=${job.elapsed.inMilliseconds}ms',
      );
      for (final d in e.diagLog.entries) {
        say('DIAG ${d.kind}: ${d.message}');
      }
      expect(job.state, JobState.completed, reason: job.message);
      final end = DateTime.now().add(const Duration(seconds: 120));
      File? got;
      while (got == null && DateTime.now().isBefore(end)) {
        final fs = inbox
            .listSync()
            .whereType<File>()
            .where((f) => !p.basename(f.path).startsWith('.'))
            .toList();
        if (fs.isNotEmpty) got = fs.first;
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      for (final d in e.diagLog.entries) {
        say('DIAG ${d.kind}: ${d.message}');
      }
      expect(got, isNotNull, reason: 'no file back from the peer');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      say(
        'RECEIVED ${p.basename(got!.path)} ${got.lengthSync()} bytes '
        'sha256=${sha256.convert(got.readAsBytesSync())}',
      );
      final second = env['E2E_SEND_FILE2'];
      if (second != null) {
        // Send after pairing (normal path, the peer asks as usual).
        final src2 = File(second);
        say(
          'SENDING2 ${p.basename(src2.path)} ${src2.lengthSync()} bytes '
          'sha256=${sha256.convert(src2.readAsBytesSync())}',
        );
        final j2 = await e.send(
          e.trustedDevices.single,
          [FileSendSource(src2)],
          host: peer.host,
          port: peer.port,
        );
        while (j2.isActive) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        say('SEND2 RESULT ${j2.state.name} ${j2.message ?? ''}');
        expect(j2.state, JobState.completed, reason: j2.message);
      }
      await e.stop();
    },
    skip: env['E2E_CLIENT'] == '1' ? false : 'set E2E_CLIENT=1',
    timeout: const Timeout(Duration(minutes: 10)),
  );
}
