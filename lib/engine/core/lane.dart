// 0.10.1 speed: "data lanes". File bytes travel over a second TLS
// connection that lives in its own background isolate on both devices, so
// encryption, socket reads/writes and file writes no longer compete with
// the app's screen updates on the main isolate (measured on the build box:
// a main isolate busy 50% of the time halved single-stream TLS speed,
// a background isolate kept full speed; see docs/SPEED.md).
//
// Security: the lane uses the same mutual TLS identities as the control
// connection. The receiving side trusts ONLY the sender's certificate and
// checks its fingerprint; the sender checks the receiver's fingerprint; and
// the first 32 bytes inside TLS must be a one-time token that was sent over
// the already authenticated control connection. Raw (no TLS) lanes exist
// only for the Speed test and carry generated zeros, never file data.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'bg_hasher.dart';
import 'identity.dart';

/// Bytes the receiving lane collects before one file write.
const int kLaneWriteBlock = 4 * 1024 * 1024;

/// Bytes the sending side may have queued for its lane isolate.
const int kLaneMaxInFlight = 16 * 1024 * 1024;

/// 0.10.2: a lane can use several TCP connections ("streams"). The byte
/// stream is cut into stripes of this size, sent round-robin: stripe k goes
/// over connection k % streams, so the receiver can put them back in order
/// without any extra header.
const int kLaneStripeBytes = 1024 * 1024;

/// Streams a 0.10.2 sender asks for (the receiver may answer fewer; older
/// apps do not answer, which means 1).
const int kLaneStreams = 4;
const int kLaneMaxStreams = 8;

/// Time to wait for the sender's lane connection.
const Duration kLaneAcceptTimeout = Duration(seconds: 15);

class LaneException implements Exception {
  const LaneException(this.code);

  /// "lane_closed", "lane_auth", "lane_timeout", "write_failed",
  /// "connect_failed", "hash_failed".
  final String code;
  @override
  String toString() => 'LaneException($code)';
}

/// Identity material handed to a lane isolate (PEM strings only).
class LaneKeys {
  const LaneKeys({
    required this.certPem,
    required this.keyPem,
    required this.peerCertPem,
    required this.peerFingerprint,
  });
  final String certPem;
  final String keyPem;
  final String peerCertPem;
  final String peerFingerprint;
}

String newLaneToken() => randomHex(32);

// ------------------------------------------------------------ socket tuning

/// Large socket buffers, but only where the limit can be checked: on Linux
/// and Android the kernel caps (and doubles) the value, and setting it turns
/// off automatic tuning, so it is set only when net.core.*mem_max allows at
/// least [bytes]. Elsewhere the OS keeps its own automatic tuning.
/// Returns a short note for the Speed test report.
String tuneSocketBuffers(Socket s, {int bytes = 4 * 1024 * 1024}) {
  if (!(Platform.isLinux || Platform.isAndroid)) return 'os-auto';
  int? max(String name) {
    try {
      return int.tryParse(
        File('/proc/sys/net/core/$name').readAsStringSync().trim(),
      );
    } catch (_) {
      return null;
    }
  }

  final w = max('wmem_max');
  final r = max('rmem_max');
  if (w == null || r == null) return 'os-auto (limits not readable)';
  final notes = <String>[];
  const solSocket = 1, soSndbuf = 7, soRcvbuf = 8; // Linux/Android values
  void set(int opt, int limit, String label) {
    if (limit < bytes) {
      notes.add('$label os-auto (max ${limit ~/ 1024} KiB)');
      return;
    }
    try {
      s.setRawOption(RawSocketOption.fromInt(solSocket, opt, bytes));
      notes.add('$label ${bytes ~/ 1024} KiB');
    } catch (_) {
      notes.add('$label os-auto');
    }
  }

  set(soSndbuf, w, 'send');
  set(soRcvbuf, r, 'recv');
  return notes.join(', ');
}

// ------------------------------------------------------------- receiving

/// Result of one file (or one speed-test stream) on a receiving lane.
class LaneResult {
  const LaneResult(this.bytes, this.micros, this.sha256, [this.note]);
  final int bytes;

  /// Socket facts of the receiving side (buffer sizes, streams).
  final String? note;

  /// From the first to the last byte (speed tests).
  final int micros;
  final String? sha256;
}

/// Receiving end of a lane. Lives on the main isolate; the work happens in
/// a background isolate.
class LaneServer {
  LaneServer._(this._iso, this._rp, this.port, this.token);

  final Isolate _iso;
  final ReceivePort _rp;
  final int port;

  /// TCP connections this lane waits for.
  int streams = 1;
  final String token;
  SendPort? _to;
  Completer<LaneResult>? _pending;
  void Function(int bytes)? _onBytes;
  bool _closed = false;
  Object? _failure;

  /// [raw]: no TLS (Speed test only, never file data).
  static Future<LaneServer> start({
    LaneKeys? keys,
    Object? bindAddress,
    bool raw = false,
    int streams = 1,
    int stripe = kLaneStripeBytes,
    Duration acceptTimeout = kLaneAcceptTimeout,
  }) async {
    if (!raw && keys == null) throw ArgumentError('keys');
    if (streams < 1 || streams > kLaneMaxStreams) {
      throw ArgumentError('streams');
    }
    final token = newLaneToken();
    final rp = ReceivePort();
    final ready = Completer<(SendPort, int)>();
    late LaneServer srv;
    final iso = await Isolate.spawn(
      _serverMain,
      (
        rp.sendPort,
        keys?.certPem,
        keys?.keyPem,
        keys?.peerCertPem,
        keys?.peerFingerprint,
        token,
        bindAddress is InternetAddress
            ? bindAddress.address
            : (bindAddress as String?),
        raw,
        acceptTimeout.inMilliseconds,
        streams,
        stripe,
      ),
      onError: rp.sendPort,
      onExit: rp.sendPort,
      errorsAreFatal: true,
    );
    rp.listen((m) {
      if (!ready.isCompleted) {
        if (m is List && m.length == 3 && m[0] == 'port') {
          ready.complete((m[1] as SendPort, m[2] as int));
        } else {
          ready.completeError(const LaneException('lane_closed'));
        }
        return;
      }
      srv._onMessage(m);
    });
    final (to, port) = await ready.future;
    srv = LaneServer._(iso, rp, port, token)
      .._to = to
      ..streams = streams;
    return srv;
  }

  void _onMessage(Object? m) {
    if (m is List && m.isNotEmpty) {
      switch (m[0]) {
        case 'p':
          _onBytes?.call(m[1] as int);
          return;
        case 'done':
          final c = _pending;
          _pending = null;
          c?.complete(
            LaneResult(
              m[1] as int,
              m[2] as int,
              m[3] as String?,
              m.length > 4 ? m[4] as String? : null,
            ),
          );
          return;
        case 'err':
          _fail(LaneException(m[1] as String));
          return;
      }
    }
    // Isolate error or exit.
    _fail(const LaneException('lane_closed'));
  }

  void _fail(Object e) {
    _failure ??= e;
    final c = _pending;
    _pending = null;
    c?.completeError(e);
  }

  Future<LaneResult> _ask(List<Object?> msg, void Function(int)? onBytes) {
    if (_closed) return Future.error(const LaneException('lane_closed'));
    if (_failure != null) return Future.error(_failure!);
    if (_pending != null) throw StateError('lane busy');
    final c = _pending = Completer<LaneResult>();
    _onBytes = onBytes;
    _to!.send(msg);
    return c.future;
  }

  /// Reads exactly [count] bytes from the lane into [path] (appending when
  /// [append]). With [hash], returns the SHA-256 of the whole file: the
  /// first [hashExisting] bytes already in the file are hashed first.
  Future<LaneResult> receiveFile({
    required String path,
    required int count,
    bool append = false,
    bool hash = false,
    int hashExisting = 0,
    void Function(int bytes)? onBytes,
  }) => _ask(['file', path, count, append, hash, hashExisting], onBytes);

  /// Speed test: reads and throws away everything until [sinkEnd]'s count
  /// arrived or the sender closes.
  Future<LaneResult> sink() => _ask(['sink'], null);

  /// The sender reported (over the control connection) that it sent [n]
  /// bytes. Ending on the count does not depend on the TLS close reaching
  /// this side (on the build box it sometimes did not, for many seconds).
  void sinkEnd(int n) {
    if (!_closed) _to?.send(['sink_end', n]);
  }

  /// Stops/starts reading (the sender then waits: TCP back-pressure).
  void setPaused(bool paused) {
    if (!_closed) _to?.send(['pause', paused]);
  }

  void close() {
    if (_closed) return;
    _closed = true;
    _fail(const LaneException('lane_closed'));
    try {
      _to?.send(['close']);
    } catch (_) {}
    _rp.close();
    // In case it is stuck in a read.
    Timer(const Duration(seconds: 2), () => _iso.kill());
  }
}

typedef _ServerArgs = (
  SendPort,
  String?,
  String?,
  String?,
  String?,
  String,
  String?,
  bool,
  int,
  int,
  int,
);

Future<void> _serverMain(_ServerArgs a) async {
  final (
    back,
    certPem,
    keyPem,
    peerCertPem,
    peerFp,
    token,
    bind,
    raw,
    acceptMs,
    streams,
    stripe,
  ) = a;
  final acceptTimeout = Duration(milliseconds: acceptMs);
  final inbox = ReceivePort();
  final address = bind == null
      ? InternetAddress.anyIPv6
      : InternetAddress.tryParse(bind) ?? InternetAddress.anyIPv6;
  Stream<Socket> listener;
  Future<void> Function() closeListener;
  int port;
  Future<ServerSocket> bindRaw() async {
    try {
      return await ServerSocket.bind(address, 0);
    } catch (_) {
      if (address != InternetAddress.anyIPv6) rethrow;
      return ServerSocket.bind(InternetAddress.anyIPv4, 0);
    }
  }

  Future<SecureServerSocket> bindTls(SecurityContext ctx) async {
    Future<SecureServerSocket> on(InternetAddress a) => SecureServerSocket.bind(
      a,
      0,
      ctx,
      requestClientCertificate: true,
      requireClientCertificate: true,
    );
    try {
      return await on(address);
    } catch (_) {
      if (address != InternetAddress.anyIPv6) rethrow;
      return on(InternetAddress.anyIPv4);
    }
  }

  try {
    if (raw) {
      final s = await bindRaw();
      listener = s;
      closeListener = s.close;
      port = s.port;
    } else {
      final ctx = SecurityContext(withTrustedRoots: false)
        ..useCertificateChainBytes(utf8.encode(certPem!))
        ..usePrivateKeyBytes(utf8.encode(keyPem!))
        ..setTrustedCertificatesBytes(utf8.encode(peerCertPem!));
      final s = await bindTls(ctx);
      listener = s;
      closeListener = s.close;
      port = s.port;
    }
  } catch (_) {
    back.send(['err', 'bind_failed']);
    return;
  }
  back.send(['port', inbox.sendPort, port]);

  // Accept exactly [streams] authenticated connections. With more than one
  // stream every connection sends its index (one byte) after the token.
  final slots = List<(Socket, StreamIterator<Uint8List>, Uint8List)?>.filled(
    streams,
    null,
  );
  var filled = 0;
  String? tuneNote;
  final accepted = Completer<void>();
  late StreamSubscription<Socket> lsub;
  lsub = listener.listen((sock) async {
    try {
      if (!raw) {
        final cert = (sock as SecureSocket).peerCertificate;
        if (cert == null || fingerprintOfDer(cert.der) != peerFp) {
          sock.destroy();
          return;
        }
      }
      final it = StreamIterator<Uint8List>(sock);
      final want = utf8.encode(token);
      final need = want.length + (streams > 1 ? 1 : 0);
      final got = BytesBuilder(copy: false);
      while (got.length < need) {
        if (!await it.moveNext().timeout(const Duration(seconds: 5))) {
          throw const LaneException('lane_auth');
        }
        got.add(it.current);
      }
      final all = got.takeBytes();
      var same = true;
      for (var i = 0; i < want.length; i++) {
        same &= all[i] == want[i];
      }
      if (!same) throw const LaneException('lane_auth');
      final idx = streams > 1 ? all[want.length] : 0;
      if (accepted.isCompleted || idx >= streams || slots[idx] != null) {
        throw const LaneException('lane_auth');
      }
      tuneNote ??= tuneSocketBuffers(sock);
      slots[idx] = (sock, it, Uint8List.sublistView(all, need));
      filled++;
      if (filled == streams) {
        accepted.complete();
        await lsub.cancel();
        await closeListener();
      }
    } catch (_) {
      sock.destroy();
    }
  }, onError: (_) {});
  final timeout = Timer(acceptTimeout + const Duration(seconds: 15), () {
    if (!accepted.isCompleted) {
      accepted.completeError(const LaneException('lane_timeout'));
    }
  });

  var socks = <Socket>[];
  var its = <StreamIterator<Uint8List>>[];
  var carries = <Uint8List>[];
  // Bytes handed back by a reader that took too much (read first).
  var back0 = Uint8List(0);
  // Bytes taken from the connections so far (decides the stripe).
  var pos = 0;
  var paused = false;
  Completer<void>? unpause;
  var busy = false;
  int? sinkExpect;
  void Function()? sinkCheck;

  String note() =>
      '${tuneNote ?? 'os-auto'}${streams > 1 ? ', $streams streams' : ''}';

  Future<void> connected() async {
    if (socks.isNotEmpty) return;
    try {
      await accepted.future.timeout(acceptTimeout);
    } finally {
      timeout.cancel();
    }
    socks = [for (final x in slots) x!.$1];
    its = [for (final x in slots) x!.$2];
    carries = [for (final x in slots) x!.$3];
  }

  /// Next piece of the (striped) byte stream; null at the end.
  Future<Uint8List?> next() async {
    while (paused) {
      await (unpause ??= Completer<void>()).future;
    }
    if (back0.isNotEmpty) {
      final c = back0;
      back0 = Uint8List(0);
      return c;
    }
    final n = socks.length;
    final i = n == 1 ? 0 : (pos ~/ stripe) % n;
    Uint8List c;
    if (carries[i].isNotEmpty) {
      c = carries[i];
      carries[i] = Uint8List(0);
    } else {
      if (!await its[i].moveNext()) return null;
      c = its[i].current;
    }
    if (n > 1) {
      final left = stripe - pos % stripe;
      if (c.length > left) {
        carries[i] = Uint8List.sublistView(c, left);
        c = Uint8List.sublistView(c, 0, left);
      }
    }
    pos += c.length;
    return c;
  }

  Future<void> doFile(
    String path,
    int count,
    bool append,
    bool hash,
    int hashExisting,
  ) async {
    await connected();
    FileHasher? hasher;
    RandomAccessFile? out;
    try {
      if (hash) {
        try {
          hasher = await fileHasher(count + hashExisting);
          if (hashExisting > 0) {
            var n = 0;
            await for (final c in File(path).openRead(0, hashExisting)) {
              await hasher.add(c);
              n += c.length;
            }
            if (n != hashExisting) throw const LaneException('write_failed');
          }
        } on LaneException {
          rethrow;
        } catch (_) {
          throw const LaneException('write_failed');
        }
      }
      try {
        out = await File(path)
            .open(mode: append ? FileMode.append : FileMode.writeOnly);
      } catch (_) {
        throw const LaneException('write_failed');
      }
      final f = out;
      var got = 0;
      var pend = <Uint8List>[];
      var pendLen = 0;
      Future<void>? writing;
      var lastReport = 0;
      var reported = 0;
      final sw = Stopwatch()..start();
      Future<void> kick() async {
        if (writing != null) await writing;
        if (pendLen == 0) return;
        final Uint8List block;
        if (pend.length == 1) {
          block = pend.single;
        } else {
          final bb = BytesBuilder(copy: false);
          for (final p in pend) {
            bb.add(p);
          }
          block = bb.takeBytes();
        }
        pend = <Uint8List>[];
        pendLen = 0;
        writing = () async {
          try {
            await f.writeFrom(block);
          } catch (_) {
            throw const LaneException('write_failed');
          }
          if (hasher != null) await hasher.add(block);
        }();
        writing!.ignore();
      }

      while (got < count) {
        Uint8List? c;
        try {
          c = await next();
        } on SocketException {
          c = null; // a reset connection: still keep what arrived
        } on TlsException {
          c = null;
        }
        if (c == null) {
          // Keep what arrived (a resumed send continues from there).
          try {
            await kick();
            if (writing != null) await writing;
          } catch (_) {}
          throw const LaneException('lane_closed');
        }
        var piece = c;
        if (got + piece.length > count) {
          final need = count - got;
          back0 = Uint8List.sublistView(piece, need);
          piece = Uint8List.sublistView(piece, 0, need);
        }
        pend.add(piece);
        pendLen += piece.length;
        got += piece.length;
        if (pendLen >= kLaneWriteBlock) await kick();
        final ms = sw.elapsedMilliseconds;
        if (ms - lastReport >= 50) {
          lastReport = ms;
          back.send(['p', got - reported]);
          reported = got;
        }
      }
      await kick();
      if (writing != null) await writing;
      if (got > reported) back.send(['p', got - reported]);
      await f.close();
      out = null;
      String? digest;
      if (hasher != null) {
        digest = await hasher.close();
        hasher = null;
      }
      back.send(['done', got, sw.elapsedMicroseconds, digest, note()]);
    } finally {
      hasher?.dispose();
      try {
        await out?.close();
      } catch (_) {}
    }
  }

  /// Speed test: counts everything from all streams until the sender's
  /// count (sinkEnd) arrived or every stream ended.
  Future<void> doSink() async {
    await connected();
    var n = back0.length;
    back0 = Uint8List(0);
    for (var i = 0; i < carries.length; i++) {
      n += carries[i].length;
      carries[i] = Uint8List(0);
    }
    final sw = Stopwatch();
    if (n > 0) sw.start();
    var lastAt = 0;
    var open = its.length;
    final done = Completer<void>();
    void check() {
      if (done.isCompleted) return;
      if ((sinkExpect != null && n >= sinkExpect!) || open == 0) {
        done.complete();
      }
    }

    sinkCheck = check;
    for (final it in its) {
      unawaited(() async {
        try {
          while (!done.isCompleted && await it.moveNext()) {
            if (!sw.isRunning) sw.start();
            n += it.current.length;
            lastAt = sw.elapsedMicroseconds;
            check();
          }
        } catch (_) {}
        open--;
        check();
      }());
    }
    check();
    await done.future;
    sinkCheck = null;
    back.send(['done', n, lastAt, null, note()]);
  }

  inbox.listen((m) async {
    final msg = m as List;
    switch (msg[0]) {
      case 'pause':
        paused = msg[1] as bool;
        if (!paused) {
          unpause?.complete();
          unpause = null;
        }
      case 'sink_end':
        sinkExpect = msg[1] as int;
        sinkCheck?.call();
      case 'close':
        timeout.cancel();
        inbox.close();
        for (final x in socks) {
          x.destroy();
        }
        for (final x in slots) {
          x?.$1.destroy();
        }
        try {
          await lsub.cancel();
          await closeListener();
        } catch (_) {}
        Isolate.exit();
      case 'file' || 'sink':
        if (busy) return;
        busy = true;
        try {
          if (msg[0] == 'sink') {
            await doSink();
          } else {
            await doFile(
              msg[1] as String,
              msg[2] as int,
              msg[3] as bool,
              msg[4] as bool,
              msg[5] as int,
            );
          }
        } on LaneException catch (e) {
          back.send(['err', e.code]);
        } on TimeoutException {
          back.send(['err', 'lane_timeout']);
        } catch (_) {
          back.send(['err', 'lane_closed']);
        } finally {
          busy = false;
        }
    }
  });
}

// --------------------------------------------------------------- sending

/// Sending end of a lane (main isolate side).
class LaneClient {
  LaneClient._(this._iso, this._rp);

  final Isolate _iso;
  final ReceivePort _rp;
  late final SendPort _to;
  int _inFlight = 0;
  Completer<void>? _room;
  Completer<void>? _drained;
  Completer<LaneResult>? _gen;
  Object? _failure;
  bool _closed = false;

  /// Socket facts of this side (buffer sizes).
  String? note;

  /// Connects to [host]:[port] and proves itself with [token].
  /// [keys] null = raw TCP (Speed test only).
  static Future<LaneClient> connect({
    required String host,
    required int port,
    required String token,
    LaneKeys? keys,
    int streams = 1,
    int stripe = kLaneStripeBytes,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (streams < 1 || streams > kLaneMaxStreams) {
      throw ArgumentError('streams');
    }
    final rp = ReceivePort();
    final ready = Completer<SendPort>();
    String? tune;
    late LaneClient c;
    final iso = await Isolate.spawn(
      _clientMain,
      (
        rp.sendPort,
        host,
        port,
        token,
        keys?.certPem,
        keys?.keyPem,
        keys?.peerFingerprint,
        timeout.inMilliseconds,
        streams,
        stripe,
      ),
      onError: rp.sendPort,
      onExit: rp.sendPort,
      errorsAreFatal: true,
    );
    rp.listen((m) {
      if (!ready.isCompleted) {
        if (m is List && m.length >= 2 && m[0] == 'ok') {
          tune = m.length > 2 ? m[2] as String? : null;
          ready.complete(m[1] as SendPort);
        } else {
          ready.completeError(
            LaneException(
              m is List && m.length == 2 && m[0] == 'err'
                  ? m[1] as String
                  : 'connect_failed',
            ),
          );
        }
        return;
      }
      c._onMessage(m);
    });
    try {
      // Whole connect incl. TLS handshakes: a receiver that closes its lane
      // half-way (cancel) must not leave the sender waiting forever.
      final to = await ready.future.timeout(
        timeout * 2 + const Duration(seconds: 2),
        onTimeout: () => throw const LaneException('connect_failed'),
      );
      c = LaneClient._(iso, rp)
        .._to = to
        ..note = tune;
      return c;
    } catch (_) {
      rp.close();
      iso.kill();
      rethrow;
    }
  }

  void _onMessage(Object? m) {
    if (m is List && m.isNotEmpty) {
      switch (m[0]) {
        case 'ack':
          _inFlight -= m[1] as int;
          if (_inFlight < kLaneMaxInFlight) {
            _room?.complete();
            _room = null;
          }
          if (_inFlight == 0) {
            _drained?.complete();
            _drained = null;
          }
          return;
        case 'gen':
          final g = _gen;
          _gen = null;
          g?.complete(LaneResult(m[1] as int, m[2] as int, null));
          return;
        case 'err':
          _fail(LaneException(m[1] as String));
          return;
      }
    }
    _fail(const LaneException('lane_closed'));
  }

  void _fail(Object e) {
    _failure ??= e;
    _room?.completeError(e);
    _room = null;
    _drained?.completeError(e);
    _drained = null;
    _gen?.completeError(e);
    _gen = null;
  }

  void _check() {
    if (_failure != null) throw _failure!;
    if (_closed) throw const LaneException('lane_closed');
  }

  /// Queues [bytes] for the lane. Waits while too much is queued.
  Future<void> add(List<int> bytes) async {
    _check();
    if (bytes.isEmpty) return;
    final b = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
    _inFlight += b.length;
    _to.send(TransferableTypedData.fromList([b]));
    if (_inFlight >= kLaneMaxInFlight) {
      await (_room ??= Completer<void>()).future;
    }
  }

  /// Like [add] for several pieces at once (sent as one message).
  Future<void> addAll(List<Uint8List> parts) async {
    _check();
    var n = 0;
    for (final b in parts) {
      n += b.length;
    }
    if (n == 0) return;
    _inFlight += n;
    _to.send(TransferableTypedData.fromList(parts));
    if (_inFlight >= kLaneMaxInFlight) {
      await (_room ??= Completer<void>()).future;
    }
  }

  /// Waits until everything queued was handed to the network.
  Future<void> drain() async {
    _check();
    if (_inFlight == 0) return;
    await (_drained ??= Completer<void>()).future;
  }

  /// Speed test: sends zeros until [bytes] or [limit], then closes.
  /// Returns what this side wrote and how long it took.
  Future<LaneResult> generate(int bytes, Duration limit) {
    _check();
    final g = _gen = Completer<LaneResult>();
    _to.send(['gen', bytes, limit.inMilliseconds]);
    return g.future;
  }

  void close() {
    if (_closed) return;
    _closed = true;
    try {
      _to.send(['close']);
    } catch (_) {}
    _rp.close();
    Timer(const Duration(seconds: 2), () => _iso.kill());
  }
}

typedef _ClientArgs = (
  SendPort,
  String,
  int,
  String,
  String?,
  String?,
  String?,
  int,
  int,
  int,
);

Future<void> _clientMain(_ClientArgs a) async {
  final (
    back,
    host,
    port,
    token,
    certPem,
    keyPem,
    peerFp,
    timeoutMs,
    streams,
    stripe,
  ) = a;
  final timeout = Duration(milliseconds: timeoutMs);
  String? tune;
  Future<Socket> open(int index) async {
    Socket sock;
    if (certPem == null) {
      sock = await Socket.connect(host, port, timeout: timeout);
    } else {
      final ctx = SecurityContext(withTrustedRoots: false)
        ..useCertificateChainBytes(utf8.encode(certPem))
        ..usePrivateKeyBytes(utf8.encode(keyPem!));
      sock = await SecureSocket.connect(
        host,
        port,
        context: ctx,
        onBadCertificate: (c) => fingerprintOfDer(c.der) == peerFp,
        timeout: timeout,
      );
    }
    tune ??= tuneSocketBuffers(sock);
    sock.add([...utf8.encode(token), if (streams > 1) index]);
    await sock.flush().timeout(timeout);
    return sock;
  }

  final List<Socket> socks;
  {
    final tries = [for (var i = 0; i < streams; i++) open(i)];
    final got = <Socket>[];
    var bad = false;
    for (final t in tries) {
      try {
        got.add(await t);
      } catch (_) {
        bad = true;
      }
    }
    if (bad) {
      for (final x in got) {
        x.destroy();
      }
      back.send(['err', 'connect_failed']);
      return;
    }
    socks = got;
  }
  for (final sock in socks) {
    unawaited(sock.done.then((_) {}, onError: (_) {}));
    // Notice when the other side goes away while we are idle.
    sock.listen((_) {}, onError: (_) {}, onDone: () {}, cancelOnError: true);
  }
  final inbox = ReceivePort();
  back.send(['ok', inbox.sendPort, tune]);
  final queue = <Uint8List>[];
  var running = false;
  var failed = false;
  // Position in the striped byte stream, and one flush in flight per stream
  // (so every stream keeps data queued while the others are written).
  var pos = 0;
  final flushes = List<Future<void>?>.filled(streams, null);

  Future<void> sendQueued() async {
    while (queue.isNotEmpty && !failed) {
      final b = queue.removeAt(0);
      var off = 0;
      final parts = <Future<void>>[];
      while (off < b.length) {
        final i = streams == 1 ? 0 : (pos ~/ stripe) % streams;
        final left = streams == 1 ? b.length : stripe - pos % stripe;
        final k = left < b.length - off ? left : b.length - off;
        final piece = off == 0 && k == b.length
            ? b
            : Uint8List.sublistView(b, off, off + k);
        final f = flushes[i];
        if (f != null) await f;
        socks[i].add(piece);
        final nf = flushes[i] = socks[i].flush();
        nf.ignore();
        parts.add(nf);
        off += k;
        pos += k;
      }
      // Acked once handed to the network (drain() relies on that), without
      // waiting here: the next block goes out meanwhile.
      final len = b.length;
      Future.wait(parts).then((_) => back.send(['ack', len]), onError: (_) {});
    }
  }

  Future<void> pump() async {
    if (running) return;
    running = true;
    try {
      while (queue.isNotEmpty && !failed) {
        await sendQueued();
        // Blocks queued while the last flushes ran are sent in the next round.
        for (var i = 0; i < streams; i++) {
          final f = flushes[i];
          flushes[i] = null;
          if (f != null) await f;
        }
      }
    } catch (_) {
      failed = true;
      back.send(['err', 'lane_closed']);
    } finally {
      running = false;
    }
  }

  Future<void> gen(int bytes, int limitMs) async {
    final buf = Uint8List(1024 * 1024);
    final sw = Stopwatch()..start();
    var n = 0;
    Future<void> one(Socket sock) async {
      while (n < bytes && sw.elapsedMilliseconds < limitMs) {
        final k = bytes - n < buf.length ? bytes - n : buf.length;
        n += k;
        sock.add(k == buf.length ? buf : Uint8List.sublistView(buf, 0, k));
        await sock.flush();
      }
    }

    try {
      await Future.wait([for (final x in socks) one(x)]);
      final took = sw.elapsedMicroseconds;
      await Future.wait([for (final x in socks) x.close()]);
      back.send(['gen', n, took]);
    } catch (_) {
      back.send(['err', 'lane_closed']);
    }
  }

  inbox.listen((m) async {
    if (m is TransferableTypedData) {
      queue.add(m.materialize().asUint8List());
      unawaited(pump());
      return;
    }
    final msg = m as List;
    switch (msg[0]) {
      case 'gen':
        await gen(msg[1] as int, msg[2] as int);
      case 'close':
        inbox.close();
        // Let queued bytes go out first (the normal end of a transfer).
        while (running) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        for (final sock in socks) {
          try {
            await sock.close().timeout(const Duration(seconds: 2));
          } catch (_) {}
          sock.destroy();
        }
        Isolate.exit();
    }
  });
}
