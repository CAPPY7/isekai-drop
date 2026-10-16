import 'dart:async';
import 'dart:isolate';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Audit #10: SHA-256 runs in a background isolate so the UI isolate does
/// not spend its time hashing. Chunks are handed over as
/// [TransferableTypedData] (one copy, no per-message serialisation).
/// Use one [BgHasher] per file: [add] chunks in order, then [close].
abstract class FileHasher {
  /// Await it: it may wait while the background hasher catches up.
  Future<void> add(List<int> chunk);
  Future<String> close();
  void dispose();
}

/// Files at or above this size are hashed in a background isolate; smaller
/// ones inline (starting an isolate costs a few milliseconds).
const int kBgHashMinBytes = 1024 * 1024;

/// Tests: force one mode. null = by size.
bool? debugForceBgHash;

Future<FileHasher> fileHasher(int size) async =>
    (debugForceBgHash ?? size >= kBgHashMinBytes)
    ? await BgHasher.start()
    : InlineHasher();

class InlineHasher implements FileHasher {
  InlineHasher() {
    _h = sha256.startChunkedConversion(_out);
  }
  final _out = _DigestSink();
  late final ByteConversionSink _h;
  @override
  Future<void> add(List<int> chunk) async => _h.add(chunk);
  @override
  Future<String> close() async {
    _h.close();
    return _out.value.toString();
  }

  @override
  void dispose() {}
}

/// At most this many bytes may wait in the hashing isolate. Above it,
/// [BgHasher.add] waits (audit #18: no unbounded queue if hashing is
/// slower than the network).
const int kBgHashMaxInFlight = 8 * 1024 * 1024;

class BgHasher implements FileHasher {
  BgHasher._(this._to, this._rp, this._isolate);

  final SendPort _to;
  final ReceivePort _rp;
  final Isolate _isolate;
  int _inFlight = 0;
  Completer<void>? _room;
  final Completer<String> _digest = Completer<String>();
  bool _done = false;

  static Future<BgHasher> start() async {
    final rp = ReceivePort();
    final first = Completer<SendPort>();
    late BgHasher h;
    final iso = await Isolate.spawn(
      _main,
      rp.sendPort,
      onError: rp.sendPort,
      onExit: rp.sendPort,
      errorsAreFatal: true,
    );
    rp.listen((m) {
      if (!first.isCompleted) {
        if (m is SendPort) {
          first.complete(m);
        } else {
          first.completeError(StateError('hasher did not start'));
        }
        return;
      }
      h._onMessage(m);
    });
    h = BgHasher._(await first.future, rp, iso);
    return h;
  }

  void _onMessage(Object? m) {
    if (m is int) {
      _inFlight -= m;
      if (_inFlight < kBgHashMaxInFlight) {
        _room?.complete();
        _room = null;
      }
    } else if (m is String) {
      if (!_digest.isCompleted) _digest.complete(m);
    } else {
      // Error or exit before the digest.
      if (!_digest.isCompleted) {
        _digest.completeError(StateError('hasher failed'));
      }
      _room?.completeError(StateError('hasher failed'));
      _room = null;
    }
  }

  /// Bytes waiting in the isolate (tests).
  int get inFlight => _inFlight;

  @override
  Future<void> add(List<int> chunk) async {
    final bytes = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
    _inFlight += bytes.length;
    _to.send(TransferableTypedData.fromList([bytes]));
    if (_inFlight >= kBgHashMaxInFlight) {
      await (_room ??= Completer<void>()).future;
    }
  }

  @override
  Future<String> close() async {
    _to.send(null);
    try {
      return await _digest.future;
    } finally {
      _done = true;
      _rp.close(); // the isolate ends by itself after replying
    }
  }

  @override
  void dispose() {
    if (_done) return;
    _done = true;
    _rp.close();
    _isolate.kill(priority: Isolate.immediate);
  }

  static void _main(SendPort back) {
    final inbox = ReceivePort();
    back.send(inbox.sendPort);
    final out = _DigestSink();
    final h = sha256.startChunkedConversion(out);
    inbox.listen((m) {
      if (m == null) {
        h.close();
        back.send(out.value.toString());
        inbox.close();
        return;
      }
      final b = (m as TransferableTypedData).materialize().asUint8List();
      h.add(b);
      back.send(b.length);
    });
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;
  @override
  void add(Digest data) => value = data;
  @override
  void close() {}
}
