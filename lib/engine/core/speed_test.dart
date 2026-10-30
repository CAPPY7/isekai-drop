// 0.10.1 Speed test: measures each step of a transfer separately, so a slow
// result can be traced to the network, encryption, reading, writing or
// hashing. Only generated zeros travel over the network; the local test
// files are deleted at once.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'bg_hasher.dart';
import 'identity.dart';
import 'send_source.dart';

/// Default amount per step. Each step also stops after [kSpeedStepLimit].
const int kSpeedTestBytes = 200 * 1000 * 1000;
const Duration kSpeedStepLimit = Duration(seconds: 15);

/// Why a Speed test could not run: "busy", "no_address", "old_peer",
/// "not_accepting", "refused", ...
class SpeedTestException implements Exception {
  const SpeedTestException(this.code);
  final String code;

  String get message => switch (code) {
    'busy' => 'A Speed test is already running.',
    'no_address' => 'Address unknown. Open Isekai Drop on the other device, on the same Wi-Fi.',
    'old_peer' => 'The other device has an older app version without the Speed test. Update it first.',
    'not_accepting' => 'The other device is not accepting files right now (turned off in its Settings).',
    _ => 'The other device refused the Speed test ($code).',
  };

  @override
  String toString() => 'SpeedTestException($code)';
}

/// One measured step. MB = 1,000,000 bytes.
class SpeedSample {
  const SpeedSample(this.key, this.bytes, this.micros, {this.note});

  final String key;
  final int bytes;
  final int micros;
  final String? note;

  double? get mbPerSec => micros > 0 && bytes > 0 ? bytes / micros : null;

  /// Failed or not run (the note says why).
  bool get ok => mbPerSec != null;

  String get label => kSpeedLabels[key] ?? key;

  Map<String, Object?> toJson() => {
    'k': key,
    'b': bytes,
    'us': micros,
    if (note != null) 'n': note,
  };

  static SpeedSample? fromJson(Object? j) {
    if (j is! Map) return null;
    final k = j['k'], b = j['b'], us = j['us'], n = j['n'];
    if (k is! String || b is! int || us is! int) return null;
    return SpeedSample(k, b, us, note: n is String ? n : null);
  }

  static SpeedSample failed(String key, String why) =>
      SpeedSample(key, 0, 0, note: why);
}

const Map<String, String> kSpeedLabels = {
  'raw_tcp': 'Network only (plain TCP, no encryption)',
  'raw_tcp_4': 'Network only, 4 TCP streams',
  'native_tcp': 'Network only, Android native code (no Dart)',
  'native_tcp_4': 'Network only, Android native code, 4 streams',
  'tls_lane': 'Encrypted, background thread, 1 stream (0.10.1 transfer path)',
  'tls_lane_4':
      'Encrypted, background thread, 4 streams (0.10.2 transfer path)',
  'tls_main': 'Encrypted, app main thread (old path)',
  'write_old': 'Write, 256 KiB pieces (old receive path)',
  'write_new': 'Write, 4 MiB blocks (0.10.1 receive path)',
  'write_target': 'Write into Downloads (final save)',
  'hash_rx': 'Receiver check (SHA-256 of the file)',
  'read_tx': 'Sender read + SHA-256',
};

/// Platform hooks; the defaults work on every platform with plain Dart.
/// 0.10.2: a TCP throughput probe outside Dart (Android: Java NIO).
/// Only zeros travel; the receiving port takes [streams] connections that
/// each start with the token (plus one index byte when streams > 1).
abstract class NativeSpeedProbe {
  /// Opens a receiving port. Returns (id, port).
  Future<(int, int)> sinkStart(int streams, String token);

  /// Waits until [expect] bytes arrived or all senders closed, then closes
  /// the port. Note: receive buffer size when known.
  Future<SpeedSample> sinkEnd(int id, String key, int expect, Duration wait);

  Future<SpeedSample> send(
    String host,
    int port,
    String token,
    int streams,
    int bytes,
    Duration limit,
    String key,
  );
}

class SpeedProbes {
  const SpeedProbes({
    this.sourceFor,
    this.fileDigest,
    this.writeTarget,
    this.linkInfo,
    this.awake,
    this.native,
  });

  /// 0.10.2: keeps Wi-Fi out of power save and the CPU awake while on
  /// (Android). Returns a short note of what is held.
  final Future<String?> Function(bool on)? awake;

  /// 0.10.2: native TCP probe (Android), null elsewhere.
  final NativeSpeedProbe? native;

  /// How a file is read when sending (Android: the native reader).
  final SendSource Function(File f)? sourceFor;

  /// Receiver's file check (Android: native SHA-256).
  final Future<String> Function(File f)? fileDigest;

  /// Writes [bytes] zeros where received files end up, measures it and
  /// deletes the test file again (Android: MediaStore Downloads). Null when
  /// that is the same folder as the receive temp folder.
  final Future<SpeedSample> Function(int bytes, Duration limit)? writeTarget;

  /// Wi-Fi facts, no names or addresses: linkMbps, txMbps, rxMbps,
  /// frequencyMhz, transport, and direct* for a joined Fast direct link.
  final Future<Map<String, Object?>> Function()? linkInfo;
}

/// 0.10.2: what kind of network interface a name is (no addresses).
String interfaceKind(String name) {
  final n = name.toLowerCase();
  if (n.startsWith('p2p')) return 'Wi-Fi Direct';
  if (n.startsWith('ap') || n.startsWith('swlan') || n.contains('softap')) {
    return 'hotspot';
  }
  if (n.startsWith('wlan') || n.startsWith('wlp') || n.startsWith('wl')) {
    return 'Wi-Fi';
  }
  if (n.startsWith('rmnet') || n.startsWith('ccmni') || n.startsWith('wwan')) {
    return 'mobile data';
  }
  if (n == 'lo' || n.startsWith('loopback')) return 'loopback';
  if (n.startsWith('eth') || n.startsWith('en')) return 'Ethernet';
  if (n.startsWith('tun') || n.startsWith('wg') || n.startsWith('ppp')) {
    return 'VPN';
  }
  return 'other';
}

/// True for interfaces a Fast direct link uses (Wi-Fi Direct or hotspot).
bool isDirectInterface(String name) {
  final k = interfaceKind(name);
  return k == 'Wi-Fi Direct' || k == 'hotspot';
}

/// Name of the local interface that owns [local] (the socket's own address),
/// e.g. "p2p-wlan0-0" or "wlan0". Null when unknown. The address itself is
/// never reported.
Future<String?> interfaceNameFor(InternetAddress? local) async {
  if (local == null) return null;
  try {
    if (local.isLoopback) return 'lo';
    final list = await NetworkInterface.list(
      includeLoopback: true,
      includeLinkLocal: true,
    );
    for (final i in list) {
      for (final a in i.addresses) {
        if (a.address == local.address) return i.name;
      }
    }
  } catch (_) {}
  return null;
}

/// 0.10.2: warnings about one device's link facts (see [SpeedReport.linkText]).
List<String> linkWarnings(
  String who,
  Map<String, Object?> l, {
  required bool direct,
}) {
  final out = <String>[];
  final iface = l['iface'];
  if (direct && iface is String && !isDirectInterface(iface)) {
    out.add(
      '$who: the test connection used $iface (${interfaceKind(iface)}), '
      'not the Fast direct link, so the data went through the router.',
    );
  }
  final sta = l['frequencyMhz'] ?? l['staMhz'];
  final dm = l['directMhz'];
  if (direct &&
      sta is num &&
      dm is num &&
      sta > 0 &&
      dm > 0 &&
      l['transport'] == 'wifi' &&
      (sta - dm).abs() > 10) {
    out.add(
      '$who is on the router at $sta MHz and on the direct link at $dm MHz: '
      'the Wi-Fi chip keeps switching between the two channels, which '
      'often halves the speed or worse.',
    );
  }
  return out;
}

Future<Map<String, Object?>> readLinkInfo(SpeedProbes p) async {
  try {
    return await p.linkInfo?.call() ?? const {};
  } catch (_) {
    return const {};
  }
}

/// Writes, hashes and reads a test file in [dir] (where received files are
/// written first), then deletes it.
Future<List<SpeedSample>> runLocalSpeedTests(
  SpeedProbes probes,
  Directory dir, {
  int bytes = kSpeedTestBytes,
  Duration limit = kSpeedStepLimit,
  void Function(String key)? onStep,
}) async {
  final out = <SpeedSample>[];
  await dir.create(recursive: true);
  final tag = randomHex(6);
  final a = File(p.join(dir.path, '.isekai-speed-$tag-a.part'));
  final b = File(p.join(dir.path, '.isekai-speed-$tag-b.part'));
  try {
    onStep?.call('write_old');
    out.add(await _guard('write_old', () => _writeOld(a, bytes, limit)));
    try {
      await a.delete();
    } catch (_) {}
    onStep?.call('write_new');
    final w = await _guard('write_new', () => _writeNew(b, bytes, limit));
    out.add(w);
    final written = w.ok ? w.bytes : 0;
    const cached =
        'just written, so it may come from memory; real files can be slower';
    if (written > 0) {
      onStep?.call('hash_rx');
      out.add(
        await _guard('hash_rx', () async {
          final sw = Stopwatch()..start();
          final digest = probes.fileDigest;
          if (digest != null) {
            await digest(b);
          } else {
            final h = await fileHasher(written);
            try {
              await for (final c in b.openRead()) {
                await h.add(c);
              }
              await h.close();
            } finally {
              h.dispose();
            }
          }
          return SpeedSample(
            'hash_rx',
            written,
            sw.elapsedMicroseconds,
            note: '${digest != null ? 'native' : 'Dart, background'}; $cached',
          );
        }),
      );
      onStep?.call('read_tx');
      out.add(
        await _guard('read_tx', () async {
          final src = probes.sourceFor?.call(b) ?? FileSendSource(b);
          final sw = Stopwatch()..start();
          var n = 0;
          FileHasher? h;
          try {
            if (!src.hashesItself) h = await fileHasher(written);
            await for (final c in src.open()) {
              n += c.length;
              await h?.add(c);
            }
            if (src.hashesItself) {
              await src.readDigest();
            } else {
              await h!.close();
            }
          } finally {
            h?.dispose();
            await src.close();
          }
          return SpeedSample(
            'read_tx',
            n,
            sw.elapsedMicroseconds,
            note:
                '${src.hashesItself ? 'native reader' : 'Dart reader'}; $cached',
          );
        }),
      );
    }
    final target = probes.writeTarget;
    if (target != null) {
      onStep?.call('write_target');
      out.add(await _guard('write_target', () => target(bytes, limit)));
    }
  } finally {
    for (final f in [a, b]) {
      try {
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }
  return out;
}

Future<SpeedSample> _guard(String key, Future<SpeedSample> Function() f) async {
  try {
    return await f();
  } catch (e) {
    return SpeedSample.failed(key, 'failed (${e.runtimeType})');
  }
}

/// The pre-0.10.1 receive path: one awaited 256 KiB write per frame.
Future<SpeedSample> _writeOld(File f, int bytes, Duration limit) async {
  final buf = Uint8List(256 * 1024);
  final raf = await f.open(mode: FileMode.writeOnly);
  final sw = Stopwatch()..start();
  var n = 0;
  try {
    while (n < bytes && sw.elapsed < limit) {
      final k = bytes - n < buf.length ? bytes - n : buf.length;
      await raf.writeFrom(buf, 0, k);
      n += k;
    }
    await raf.flush();
  } finally {
    await raf.close();
  }
  return SpeedSample('write_old', n, sw.elapsedMicroseconds);
}

/// The 0.10.1 receive path: 4 MiB blocks (as the lane writes them).
Future<SpeedSample> _writeNew(File f, int bytes, Duration limit) async {
  final buf = Uint8List(4 * 1024 * 1024);
  final raf = await f.open(mode: FileMode.writeOnly);
  final sw = Stopwatch()..start();
  var n = 0;
  try {
    while (n < bytes && sw.elapsed < limit) {
      final k = bytes - n < buf.length ? bytes - n : buf.length;
      await raf.writeFrom(buf, 0, k);
      n += k;
    }
    await raf.flush();
  } finally {
    await raf.close();
  }
  return SpeedSample('write_new', n, sw.elapsedMicroseconds);
}

/// Everything one Speed test found.
class SpeedReport {
  SpeedReport({
    required this.appVersion,
    required this.at,
    required this.myPlatform,
    required this.peerName,
    required this.peerPlatform,
    required this.route,
    required this.network,
    required this.local,
    required this.peerLocal,
    required this.link,
    required this.peerLink,
    this.notes = const [],
  });

  final String appVersion;
  final DateTime at;
  final String myPlatform;
  final String peerName;
  final String peerPlatform;
  final String route;
  final List<SpeedSample> network;
  final List<SpeedSample> local;
  final List<SpeedSample> peerLocal;
  final Map<String, Object?> link;
  final Map<String, Object?> peerLink;
  final List<String> notes;

  SpeedSample? _find(List<SpeedSample> l, String k) {
    for (final s in l) {
      if (s.key == k && s.ok) return s;
    }
    return null;
  }

  /// The slowest step of a real transfer from this device to the peer.
  String? get bottleneck {
    final steps = <(String, SpeedSample?)>[
      (
        'the network/encryption',
        _find(network, 'tls_lane_4') ?? _find(network, 'tls_lane'),
      ),
      ('reading on this device', _find(local, 'read_tx')),
      ('writing on the other device', _find(peerLocal, 'write_new')),
    ];
    (String, SpeedSample)? worst;
    for (final (name, s) in steps) {
      if (s == null) continue;
      if (worst == null || s.mbPerSec! < worst.$2.mbPerSec!) worst = (name, s);
    }
    if (worst == null) return null;
    return '${worst.$1} (${worst.$2.mbPerSec!.toStringAsFixed(1)} MB/s)';
  }

  static String _fmt(SpeedSample s) {
    final v = s.mbPerSec;
    final mb = (s.bytes / 1e6).toStringAsFixed(0);
    final secs = (s.micros / 1e6).toStringAsFixed(1);
    return v == null
        ? '${s.label}: ${s.note ?? 'not measured'}'
        : '${s.label}: ${v.toStringAsFixed(1)} MB/s '
              '($mb MB in $secs s${s.note != null ? '; ${s.note}' : ''})';
  }

  static String linkText(Map<String, Object?> l) {
    if (l.isEmpty) return 'not available';
    final parts = <String>[];
    void add(String label, Object? v, [String unit = 'Mbps']) {
      if (v is num && v > 0) parts.add('$label $v $unit');
    }

    final t = l['transport'];
    if (t is String) parts.add(t);
    add('link', l['linkMbps']);
    add('tx', l['txMbps']);
    add('rx', l['rxMbps']);
    add('', l['frequencyMhz'], 'MHz');
    if (l['directMbps'] is num || l['directMhz'] is num) {
      parts.add('Fast direct link:');
      add('link', l['directMbps']);
      add('tx', l['directTxMbps']);
      add('rx', l['directRxMbps']);
      add('', l['directMhz'], 'MHz');
      if (l['directRole'] is String) parts.add('${l['directRole']}');
      if (l['directIface'] is String) parts.add('group ${l['directIface']}');
    }
    final iface = l['iface'];
    if (iface is String) {
      parts.add('test connection on $iface (${interfaceKind(iface)})');
    }
    if (l['awake'] is String) parts.add('${l['awake']}');
    if (l['note'] is String) parts.add('(${l['note']})');
    return parts.isEmpty
        ? 'not available'
        : parts.join(', ').replaceAll(',  ', ', ');
  }

  static String _when(DateTime t) {
    final l = t.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    final off = l.timeZoneOffset;
    final sign = off.isNegative ? '-' : '+';
    final m = off.inMinutes.abs();
    return '${l.year}-${two(l.month)}-${two(l.day)} '
        '${two(l.hour)}:${two(l.minute)} '
        '(UTC$sign${two(m ~/ 60)}:${two(m % 60)})';
  }

  String toText() {
    final b = StringBuffer()
      ..writeln('Isekai Drop Speed test (app $appVersion)')
      ..writeln('When: ${_when(at)}')
      // No device names in a report meant to be shared.
      ..writeln(
        'From: this device ($myPlatform) -> other device ($peerPlatform)',
      )
      ..writeln('Route: $route')
      ..writeln('Wi-Fi (this device): ${linkText(link)}')
      ..writeln('Wi-Fi (other device): ${linkText(peerLink)}')
      ..writeln()
      ..writeln('Network (zeros only, nothing saved):');
    for (final s in network) {
      b.writeln('  ${_fmt(s)}');
    }
    b.writeln('This device ($myPlatform, as sender):');
    for (final s in local) {
      b.writeln('  ${_fmt(s)}');
    }
    b.writeln('Other device ($peerPlatform, as receiver):');
    for (final s in peerLocal) {
      b.writeln('  ${_fmt(s)}');
    }
    final bn = bottleneck;
    if (bn != null) b.writeln('\nSlowest step: $bn');
    for (final n in notes) {
      b.writeln('Note: $n');
    }
    b.writeln('MB = 1,000,000 bytes. Contains no names of files or networks.');
    return b.toString();
  }
}
