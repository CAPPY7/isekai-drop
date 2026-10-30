// Real end-to-end peer for the Android emulator test (see AGENTS.md,
// "Emulator e2e"). Skipped unless E2E_PEER=1. Runs a real engine on
// 0.0.0.0:47820 (the emulator reaches it as 10.0.2.2:47820), approves
// pairing and incoming files, then sends one file back to the phone via
// `adb forward tcp:$E2E_SEND_PORT tcp:47820` (or to
// $E2E_SEND_HOST:$E2E_SEND_PORT, see e2e_client_test.dart). Progress goes to stdout and
// $E2E_DIR/peer.log.
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/engine.dart';
import 'package:isekaidrop/engine/core/identity.dart';
import 'package:isekaidrop/engine/core/jobs.dart';
import 'package:isekaidrop/engine/core/send_source.dart';
import 'package:isekaidrop/engine/core/trust_store.dart';
import 'package:path/path.dart' as p;

void main() {
  final env = Platform.environment;
  final on = env['E2E_PEER'] == '1';
  test(
    'e2e host peer',
    () async {
      final dir = Directory(env['E2E_DIR'] ?? '/tmp/e2e')
        ..createSync(recursive: true);
      final log = File(p.join(dir.path, 'peer.log'));
      void say(String s) {
        final line = '${DateTime.now().toIso8601String()} $s';
        // ignore: avoid_print
        print(line);
        log.writeAsStringSync('$line\n', mode: FileMode.append);
      }

      final inbox = Directory(p.join(dir.path, 'inbox'))
        ..createSync(recursive: true);
      final store = TrustStore(File(p.join(dir.path, 'trusted.json')));
      await store.load();
      final e = IsekaiEngine(
        identity: Identity.generate(),
        trust: store,
        deviceName: () => 'E2E-Host',
        platformName: 'linux',
        tempDir: inbox,
        finalizer: directoryFinalizer(inbox),
        port: 47820,
        bindAddress: InternetAddress.anyIPv4,
        enableDiscovery: false,
      );
      e.debugAutoDecide = (r) async {
        say('APPROVE ${r.kind.name} from ${r.peerName}');
        return true;
      };
      await e.start();
      say('LISTENING ${e.listeningPort} fp=${e.identity.fingerprint}');
      final wait = Duration(seconds: int.parse(env['E2E_WAIT'] ?? '900'));
      final end = DateTime.now().add(wait);
      final expectName = env['E2E_EXPECT'];
      File? got;
      while (DateTime.now().isBefore(end)) {
        final files = inbox
            .listSync()
            .whereType<File>()
            .where(
              (f) => expectName == null || p.basename(f.path) == expectName,
            )
            .toList();
        if (files.isNotEmpty) {
          got = files.first;
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
      if (got == null) fail('no file received within $wait');
      await Future<void>.delayed(const Duration(milliseconds: 500));
      say(
        'RECEIVED ${p.basename(got.path)} ${got.lengthSync()} bytes '
        'sha256=${sha256.convert(got.readAsBytesSync())}',
      );
      say('TRUSTED ${store.devices.map((d) => '${d.name}:${d.lastPort}')}');
      final sendPort = int.tryParse(env['E2E_SEND_PORT'] ?? '');
      if (sendPort != null) {
        final src = File(env['E2E_SEND_FILE']!);
        say(
          'SENDING ${p.basename(src.path)} ${src.lengthSync()} bytes '
          'sha256=${sha256.convert(src.readAsBytesSync())}',
        );
        final job = await e.send(
          store.devices.single,
          [FileSendSource(src)],
          host: env['E2E_SEND_HOST'] ?? '127.0.0.1',
          port: sendPort,
        );
        while (job.isActive) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        say('SEND RESULT ${job.state.name} ${job.message ?? ''}');
        for (final d in e.diagLog.entries) {
          say('DIAG ${d.kind}: ${d.message}');
        }
        expect(job.state, JobState.completed, reason: job.message);
      }
      final expect2 = env['E2E_EXPECT2'];
      if (expect2 != null) {
        File? got2;
        while (got2 == null && DateTime.now().isBefore(end)) {
          final f = File(p.join(inbox.path, expect2));
          if (f.existsSync()) got2 = f;
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
        if (got2 == null) fail('second file not received');
        await Future<void>.delayed(const Duration(milliseconds: 500));
        say(
          'RECEIVED2 ${p.basename(got2.path)} ${got2.lengthSync()} bytes '
          'sha256=${sha256.convert(got2.readAsBytesSync())}',
        );
      }
      await e.stop();
      say('DONE');
    },
    skip: on ? false : 'set E2E_PEER=1 to run the emulator e2e peer',
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
