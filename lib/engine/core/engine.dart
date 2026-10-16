import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../transfer_engine.dart';
import 'discovery.dart';
import 'frames.dart';
import 'identity.dart';
import 'safe_files.dart';
import 'trust_store.dart';

/// Moves a verified temp file to its final place. Returns where it went.
/// [safeRelPath] is already cleaned (see sanitizeRelativePath) and may contain
/// "/" for files inside a sent folder.
typedef ReceiveFinalizer = Future<String> Function(
  File temp,
  String safeRelPath,
  ReceiveBatch batch,
);

const int kDefaultPort = 47820;
const int kProtocolVersion = 1;
const Duration kApprovalTimeout = Duration(minutes: 2);

/// Default finalizer for desktop: rename inside [dir] without overwriting.
ReceiveFinalizer directoryFinalizer(Directory dir) =>
    (temp, safeRelPath, batch) async {
      await dir.create(recursive: true);
      final target = await reserveRelativeTarget(dir, safeRelPath, batch);
      await temp.rename(target.path);
      return target.path;
    };

/// The real transfer engine: discovery, pairing, mutual-TLS sessions,
/// chunked streaming and SHA-256 verification.
class IsekaiEngine extends ChangeNotifier implements TransferEngine {
  IsekaiEngine({
    required this.identity,
    required this.trust,
    required this.deviceName,
    required this.platformName,
    required this.tempDir,
    required this.finalizer,
    this.port = kDefaultPort,
    this.bindAddress,
    this.enableDiscovery = true,
    this.secureStorageNote,
    this.receiveLocationNote = '',
    this.discoveryOffNote,
  });

  /// Shown instead of a UDP discovery status when UDP discovery is off
  /// (iPhone/iPad: multicast needs an Apple entitlement; Bonjour is used).
  final String? discoveryOffNote;

  final Identity identity;
  final TrustStore trust;
  final String Function() deviceName;
  @override
  final String platformName;
  final Directory tempDir;
  final ReceiveFinalizer finalizer;
  final int port;
  final InternetAddress? bindAddress;
  final bool enableDiscovery;
  @override
  final String? secureStorageNote;
  @override
  final String receiveLocationNote;

  /// Test hook only: changes outgoing bytes AFTER hashing (simulates tampering).
  @visibleForTesting
  List<int> Function(List<int> chunk)? debugTamper;

  /// Test hook only: decides requests without a UI.
  @visibleForTesting
  Future<bool> Function(PendingRequest request)? debugAutoDecide;

  ServerSocket? _server;
  Discovery? _discovery;
  final Map<String, NearbyDevice> _nearby = {};
  final List<PendingRequest> _pending = [];
  final List<TransferJob> _jobs = [];
  String? _startError;
  Timer? _pruneTimer;
  Future<void> _sendChain = Future.value();
  String? _lastError;
  DateTime? _lastErrorAt;
  TransferJob? _lastFinished;

  /// Last transfer problem, in plain words. Never contains file names,
  /// device names or addresses.
  @override
  String? get lastError => _lastError;
  @override
  DateTime? get lastErrorAt => _lastErrorAt;
  @override
  TransferJob? get lastFinishedJob => _lastFinished;

  void _recordEnd(TransferJob job) {
    if (job.isActive) return;
    _lastFinished = job;
    if (job.state == JobState.failed) {
      _lastError = job.message ?? 'Transfer failed';
      _lastErrorAt = DateTime.now();
    }
  }

  /// Next control message, handling pause/resume notices from the peer.
  /// While the peer is paused we wait much longer before giving up.
  Future<Map<String, dynamic>> _nextControl(
    FrameReader reader,
    TransferJob job, [
    Duration normal = const Duration(seconds: 60),
  ]) async {
    while (true) {
      final m = await reader.nextJson(
        job.pausedByPeer ? const Duration(hours: 6) : normal,
      );
      switch (m['t']) {
        case 'pause':
          job.setPeerPaused(true);
        case 'resume':
          job.setPeerPaused(false);
        default:
          return m;
      }
    }
  }

  @override
  String get version => 'engine-v$kProtocolVersion';
  @override
  bool get isDemo => false;
  @override
  String get myName => deviceName();
  @override
  String get myFingerprint => identity.fingerprint;
  @override
  int? get listeningPort => _server?.port;
  @override
  String? get startError => _startError;
  @override
  String? get discoveryError =>
      _discovery?.error ?? (enableDiscovery ? null : discoveryOffNote);

  /// Adds a device found another way (Bonjour/mDNS). Still untrusted: the
  /// real identity is checked inside TLS.
  void addAnnouncement(Announcement a) {
    if (a.deviceId == identity.deviceId) return;
    _onFound(a);
  }

  @override
  List<NearbyDevice> get nearby {
    final list = _nearby.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  List<TrustedDevice> get trustedDevices => trust.devices;
  @override
  List<PendingRequest> get pending => List.unmodifiable(_pending);
  @override
  List<TransferJob> get jobs => List.unmodifiable(_jobs);

  @override
  Future<List<String>> localAddresses() async {
    try {
      final ifs = await NetworkInterface.list(type: InternetAddressType.IPv4);
      return [
        for (final i in ifs)
          for (final a in i.addresses)
            if (!a.isLoopback) a.address,
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> start() async {
    try {
      final addr = bindAddress ?? InternetAddress.anyIPv4;
      try {
        _server = await ServerSocket.bind(addr, port);
      } on SocketException {
        _server = await ServerSocket.bind(addr, 0);
      }
      _server!.listen(_onIncoming);
    } catch (e) {
      _startError = 'Could not start receiving on this device.';
    }
    if (enableDiscovery && _server != null) {
      _discovery = Discovery(ownDeviceId: identity.deviceId, onFound: _onFound);
      await _discovery!.start(
        () => {
          'device_id': identity.deviceId,
          'name': deviceName(),
          'platform': platformName,
          'port': _server!.port,
          'fp': identity.fingerprint,
        },
      );
    }
    _pruneTimer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      final before = _nearby.length;
      _nearby.removeWhere(
        (_, d) => DateTime.now().difference(d.seenAt).inSeconds > 30,
      );
      if (_nearby.length != before) notifyListeners();
    });
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    _pruneTimer?.cancel();
    _pruneTimer = null;
    _discovery?.stop();
    await _server?.close();
    _server = null;
  }

  void _onFound(Announcement a) {
    final t = trust.byDeviceId(a.deviceId);
    _nearby[a.deviceId] = NearbyDevice(
      deviceId: a.deviceId,
      name: a.name,
      platform: a.platform,
      host: a.host,
      port: a.port,
      seenAt: a.seenAt,
      trusted: t,
      fingerprintMismatch: t != null && t.fingerprint != a.fingerprint,
    );
    if (t != null && t.isTrusted && t.fingerprint == a.fingerprint) {
      unawaited(trust.rememberAddress(t.id, a.host, a.port));
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- approvals

  Future<bool> _ask(PendingRequest r) async {
    if (debugAutoDecide != null) return debugAutoDecide!(r);
    _pending.add(r);
    notifyListeners();
    try {
      return await r.decision.timeout(kApprovalTimeout, onTimeout: () => false);
    } finally {
      _pending.remove(r);
      notifyListeners();
    }
  }

  // ------------------------------------------------------------ TLS contexts

  SecurityContext _ownContext({bool withCert = true}) {
    final c = SecurityContext(withTrustedRoots: false);
    if (withCert) {
      c
        ..useCertificateChainBytes(utf8.encode(identity.certPem))
        ..usePrivateKeyBytes(utf8.encode(identity.keyPem));
    }
    return c;
  }

  /// Server context trusts ONLY certificates of currently trusted devices,
  /// so TLS itself rejects unknown or revoked client certificates.
  SecurityContext _serverContext() {
    final c = _ownContext();
    for (final d in trust.devices.where((d) => d.isTrusted)) {
      c.setTrustedCertificatesBytes(utf8.encode(d.certPem));
    }
    return c;
  }

  // ------------------------------------------------------------------ server

  Future<void> _onIncoming(Socket raw) async {
    SecureSocket s;
    try {
      // Small control messages must not wait ~40 ms (Nagle + delayed ACK).
      raw.setOption(SocketOption.tcpNoDelay, true);
      s = await SecureSocket.secureServer(
        raw,
        _serverContext(),
        requestClientCertificate: true,
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      // Unknown, revoked or broken client certificate: rejected by TLS.
      raw.destroy();
      return;
    }
    final reader = FrameReader(s);
    try {
      final first = await reader.nextJson(const Duration(seconds: 30));
      final peerCert = s.peerCertificate;
      if (peerCert == null) {
        // No client certificate: the only thing allowed is a pairing request.
        if (first['t'] == 'pair_req') {
          await _serverPairing(s, reader, first);
        } else {
          s.add(jsonFrame({'t': 'error', 'reason': 'not_trusted'}));
        }
        return;
      }
      final dev = trust.byFingerprint(fingerprintOfDer(peerCert.der));
      if (dev == null || !dev.isTrusted) {
        s.add(jsonFrame({'t': 'error', 'reason': 'not_trusted'}));
        return;
      }
      switch (first['t']) {
        case 'offer':
          await _serverReceive(s, reader, dev, first);
        case 'ping':
          s.add(jsonFrame({'t': 'pong'}));
        default:
          s.add(jsonFrame({'t': 'error', 'reason': 'unknown_message'}));
      }
    } catch (_) {
      // Connection problems end this session only.
    } finally {
      try {
        await s.flush();
      } catch (_) {}
      s.destroy();
      await reader.cancel();
    }
  }

  Future<void> _serverPairing(
    SecureSocket s,
    FrameReader reader,
    Map<String, dynamic> m,
  ) async {
    final certPem = m['cert'] as String? ?? '';
    final peerId = m['device_id'] as String? ?? '';
    final name = _cleanName(m['name']);
    final platform = _cleanName(m['platform']);
    String peerFp;
    try {
      if (certPem.length > 8192 || peerId.isEmpty) {
        throw const FormatException();
      }
      SecurityContext(withTrustedRoots: false)
          .setTrustedCertificatesBytes(utf8.encode(certPem));
      peerFp = fingerprintOfCertPem(certPem);
    } catch (_) {
      s.add(jsonFrame({'t': 'pair_denied', 'reason': 'bad_certificate'}));
      return;
    }
    if (peerFp == identity.fingerprint) {
      s.add(jsonFrame({'t': 'pair_denied', 'reason': 'same_device'}));
      return;
    }
    final req = PendingRequest(
      id: randomHex(8),
      kind: RequestKind.pairing,
      peerName: name,
      peerPlatform: platform,
      code: verificationCode(identity.fingerprint, peerFp),
    );
    final ok = await _ask(req);
    if (!ok) {
      s.add(jsonFrame({'t': 'pair_denied', 'reason': 'declined'}));
      return;
    }
    await trust.addTrusted(
      deviceId: peerId,
      name: name,
      platform: platform,
      certPem: certPem,
      host: s.remoteAddress.address,
    );
    s.add(
      jsonFrame({
        't': 'pair_ok',
        'device_id': identity.deviceId,
        'name': deviceName(),
        'platform': platformName,
        'port': _server?.port,
      }),
    );
    _refreshNearbyTrust();
    notifyListeners();
  }

  Future<void> _serverReceive(
    SecureSocket s,
    FrameReader reader,
    TrustedDevice dev,
    Map<String, dynamic> offer,
  ) async {
    final files = (offer['files'] as List?) ?? const [];
    if (files.isEmpty || files.length > 10000) {
      s.add(jsonFrame({'t': 'decline', 'reason': 'bad_offer'}));
      return;
    }
    final names = <String>[];
    final sizes = <int>[];
    for (final f in files) {
      final m = f as Map<String, dynamic>;
      final size = m['size'];
      if (size is! int || size < 0) {
        s.add(jsonFrame({'t': 'decline', 'reason': 'bad_offer'}));
        return;
      }
      names.add(
        sanitizeRelativePath(
          (m['path'] as String?) ?? (m['name'] as String? ?? 'file'),
        ),
      );
      sizes.add(size);
    }
    final total = sizes.fold<int>(0, (a, b) => a + b);
    final job = TransferJob(
      id: randomHex(8),
      direction: JobDirection.receiving,
      peerName: dev.name,
      fileCount: names.length,
      totalBytes: total,
    );
    final req = PendingRequest(
      id: job.id,
      kind: RequestKind.transfer,
      peerName: dev.name,
      peerPlatform: dev.platform,
      fileNames: names,
      totalBytes: total,
      job: job,
    );
    if (!await _ask(req)) {
      s.add(jsonFrame({'t': 'decline', 'reason': 'declined'}));
      return;
    }
    _jobs.insert(0, job);
    notifyListeners();
    job.onCancel = () {
      try {
        s.add(jsonFrame({'t': 'cancel'}));
      } catch (_) {}
      s.destroy();
    };
    job.onPauseChanged = (p) {
      try {
        s.add(jsonFrame({'t': p ? 'pause' : 'resume'}));
      } catch (_) {}
    };
    job.start();
    s.add(jsonFrame({'t': 'accept'}));
    await s.flush();
    final batch = ReceiveBatch();
    File? temp;
    RandomAccessFile? out;
    try {
      for (var i = 0; i < names.length; i++) {
        await job.waitIfPaused();
        final head = await _nextControl(reader, job);
        if (head['t'] == 'cancel') {
          job.finish(JobState.cancelled, 'The sender cancelled.');
          return;
        }
        if (head['t'] != 'file' || head['i'] != i) {
          throw const FormatException('Unexpected message');
        }
        temp = await createTempPart(tempDir);
        out = await temp.open(mode: FileMode.writeOnly);
        final digestOut = AccumulatorSink<Digest>();
        final hasher = sha256.startChunkedConversion(digestOut);
        var got = 0;
        while (got < sizes[i]) {
          // Pausing here stops reading; TCP then makes the sender wait.
          await job.waitIfPaused();
          if (!job.isActive) return;
          final fr = await reader.next(
            job.pausedByPeer
                ? const Duration(hours: 6)
                : const Duration(seconds: 60),
          );
          if (fr.type != frameData) {
            final t = fr.isJson ? fr.messageType : '';
            if (t == 'pause' || t == 'resume') {
              job.setPeerPaused(t == 'pause');
              continue;
            }
            if (t == 'cancel') {
              job.finish(JobState.cancelled, 'The sender cancelled.');
              return;
            }
            throw const FormatException('Expected file data');
          }
          if (got + fr.payload.length > sizes[i]) {
            throw const FormatException('More data than announced');
          }
          await out.writeFrom(fr.payload);
          hasher.add(fr.payload);
          got += fr.payload.length;
          job.addBytes(fr.payload.length);
        }
        final end = await _nextControl(reader, job);
        await out.close();
        out = null;
        hasher.close();
        final actual = digestOut.events.single.toString();
        if (end['t'] != 'file_end' ||
            end['i'] != i ||
            end['sha256'] != actual) {
          await temp.delete();
          temp = null;
          s.add(jsonFrame({'t': 'file_bad', 'i': i}));
          job.finish(
            JobState.failed,
            'Integrity check failed. The damaged file was deleted.',
          );
          return;
        }
        final where = await finalizer(temp, names[i], batch);
        temp = null;
        job.savedTo.add(where);
        job.filesDone++;
        s.add(jsonFrame({'t': 'file_ok', 'i': i}));
      }
      final done = await _nextControl(reader, job);
      if (done['t'] == 'done') s.add(jsonFrame({'t': 'done_ok'}));
      job.finish(JobState.completed, 'All files received and verified.');
    } catch (_) {
      job.finish(
        JobState.failed,
        'The transfer stopped. Nothing unverified was kept.',
      );
    } finally {
      try {
        await out?.close();
      } catch (_) {}
      if (temp != null && await temp.exists()) await temp.delete();
      _recordEnd(job);
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------ client

  @override
  Future<PairingSession> beginPairing(
    String host,
    int port, {
    String? expectFingerprint,
  }) async {
    final s = await SecureSocket.connect(
      host,
      port,
      context: _ownContext(withCert: false),
      onBadCertificate: (_) => true, // Not trusted yet: user compares codes.
      timeout: const Duration(seconds: 10),
    );
    final serverCert = s.peerCertificate!;
    final serverFp = fingerprintOfDer(serverCert.der);
    if (serverFp == identity.fingerprint) {
      s.destroy();
      throw const PairingException('That address is this device.');
    }
    if (expectFingerprint != null && serverFp != expectFingerprint) {
      s.destroy();
      throw const PairingException(
        'The device at that address is not the one in the QR code. '
        'Pairing stopped for your safety.',
      );
    }
    return PairingSession._(
      engine: this,
      socket: s,
      host: host,
      port: port,
      serverFp: serverFp,
      serverCertPem: derToPem(serverCert.der),
      code: verificationCode(identity.fingerprint, serverFp),
      verifiedByQr: expectFingerprint != null,
    );
  }

  Future<TrustedDevice> _clientConfirmPairing(PairingSession p) async {
    final s = p._socket;
    final reader = FrameReader(s);
    try {
      s.add(
        jsonFrame({
          't': 'pair_req',
          'v': kProtocolVersion,
          'device_id': identity.deviceId,
          'name': deviceName(),
          'platform': platformName,
          'cert': identity.certPem,
        }),
      );
      await s.flush();
      final r = await reader.nextJson(
        kApprovalTimeout + const Duration(seconds: 10),
      );
      if (r['t'] != 'pair_ok') {
        throw PairingException(
          r['reason'] == 'declined'
              ? 'The other device declined.'
              : 'Pairing was refused.',
        );
      }
      final dev = await trust.addTrusted(
        deviceId: r['device_id'] as String,
        name: _cleanName(r['name']),
        platform: _cleanName(r['platform']),
        certPem: p.serverCertPem,
        host: p.host,
        port: (r['port'] as int?) ?? p.port,
      );
      _refreshNearbyTrust();
      notifyListeners();
      return dev;
    } on TimeoutException {
      throw const PairingException('No answer from the other device.');
    } on SocketException {
      throw const PairingException('The connection was lost.');
    } finally {
      s.destroy();
      await reader.cancel();
    }
  }

  /// Opens an authenticated session: our certificate is checked by the other
  /// side, and theirs must match the saved fingerprint exactly.
  Future<SecureSocket> _connectTrusted(
    TrustedDevice dev,
    String host,
    int port,
  ) async {
    var mismatch = false;
    try {
      final sock = await SecureSocket.connect(
        host,
        port,
        context: _ownContext(),
        onBadCertificate: (c) {
          final ok = fingerprintOfDer(c.der) == dev.fingerprint;
          if (!ok) mismatch = true;
          return ok;
        },
        timeout: const Duration(seconds: 10),
      );
      try {
        sock.setOption(SocketOption.tcpNoDelay, true);
      } catch (_) {}
      return sock;
    } catch (e) {
      if (mismatch) {
        await trust.markIdentityChanged(dev.id);
        _refreshNearbyTrust();
        notifyListeners();
        throw const PairingException(
          'This device\'s identity changed. It is blocked until you pair again.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<TransferJob> send(
    TrustedDevice dev,
    List<SendSource> files, {
    String? host,
    int? port,
  }) async {
    final job = TransferJob(
      id: randomHex(8),
      direction: JobDirection.sending,
      peerName: dev.name,
      fileCount: files.length,
      totalBytes: files.fold<int>(0, (a, f) => a + f.size),
    );
    job.queued = _jobs.any(
      (j) => j.direction == JobDirection.sending && j.isActive,
    );
    job.onCancel = () {}; // replaced once connected
    _jobs.insert(0, job);
    notifyListeners();
    // One send at a time: later sends wait in this queue.
    _sendChain = _sendChain.then(
      (_) => _runSend(
        job,
        dev,
        files,
        host ?? dev.lastHost,
        port ?? dev.lastPort,
      ).catchError((_) {}),
    );
    return job;
  }

  Future<void> _runSend(
    TransferJob job,
    TrustedDevice dev,
    List<SendSource> files,
    String? host,
    int? port,
  ) async {
    if (!job.isActive) return; // cancelled while queued
    job.queued = false;
    job.notifyListeners();
    if (!dev.isTrusted) {
      job.finish(JobState.failed, 'This device is blocked. Pair again first.');
      _recordEnd(job);
      return;
    }
    if (host == null) {
      job.finish(
        JobState.failed,
        'Address unknown. Make sure the other device is open nearby.',
      );
      _recordEnd(job);
      return;
    }
    SecureSocket? s;
    FrameReader? reader;
    try {
      s = await _connectTrusted(dev, host, port ?? kDefaultPort);
      final sock = s;
      reader = FrameReader(sock);
      job.onCancel = () {
        try {
          sock.add(jsonFrame({'t': 'cancel'}));
        } catch (_) {}
        sock.destroy();
      };
      job.onPauseChanged = (p) {
        try {
          sock.add(jsonFrame({'t': p ? 'pause' : 'resume'}));
        } catch (_) {}
      };
      sock.add(
        jsonFrame({
          't': 'offer',
          'v': kProtocolVersion,
          'files': [
            for (final f in files)
              {'name': f.name, 'path': f.relativePath, 'size': f.size},
          ],
        }),
      );
      await sock.flush();
      final answer = await reader.nextJson(
        kApprovalTimeout + const Duration(seconds: 10),
      );
      if (answer['t'] == 'error') {
        job.finish(
          JobState.failed,
          'The other device does not trust this device. Pair again.',
        );
        return;
      }
      if (answer['t'] != 'accept') {
        job.finish(JobState.failed, 'The other device declined.');
        return;
      }
      job.start();
      for (var i = 0; i < files.length; i++) {
        final f = files[i];
        await job.waitIfPaused();
        if (job.cancelRequested) return;
        sock.add(
          jsonFrame({'t': 'file', 'i': i, 'name': f.name, 'size': f.size}),
        );
        final digestOut = AccumulatorSink<Digest>();
        final hasher = sha256.startChunkedConversion(digestOut);
        var sent = 0;
        var sinceFlush = 0;
        await for (final chunk in f.open()) {
          if (job.paused) {
            await sock.flush();
            await job.waitIfPaused();
          }
          if (job.cancelRequested) return;
          if (sent + chunk.length > f.size) {
            throw const FileSystemException('File changed while sending');
          }
          hasher.add(chunk);
          final wire = debugTamper != null ? debugTamper!(chunk) : chunk;
          sock.add(encodeFrame(frameData, wire));
          sent += chunk.length;
          sinceFlush += chunk.length;
          job.addBytes(chunk.length);
          if (sinceFlush >= 4 * 1024 * 1024) {
            sinceFlush = 0;
            await sock.flush();
          }
        }
        await f.close();
        if (sent != f.size) {
          throw const FileSystemException('File size changed');
        }
        hasher.close();
        sock.add(
          jsonFrame({
            't': 'file_end',
            'i': i,
            'sha256': digestOut.events.single.toString(),
          }),
        );
        await sock.flush();
        final r = await _nextControl(reader, job);
        if (r['t'] != 'file_ok') {
          job.finish(
            JobState.failed,
            'The other device rejected the file: integrity check failed.',
          );
          return;
        }
        job.filesDone++;
      }
      sock.add(jsonFrame({'t': 'done'}));
      await sock.flush();
      await _nextControl(reader, job);
      job.finish(JobState.completed, 'Sent and verified by the other device.');
    } on PairingException catch (e) {
      job.finish(JobState.failed, e.message);
    } catch (_) {
      job.finish(
        JobState.failed,
        job.cancelRequested
            ? 'Cancelled'
            : 'Could not reach the other device, or the connection was lost.',
      );
    } finally {
      for (final f in files) {
        try {
          await f.close();
        } catch (_) {}
      }
      s?.destroy();
      await reader?.cancel();
      _recordEnd(job);
      notifyListeners();
    }
  }

  // -------------------------------------------------------- device management

  @override
  Future<void> renameTrustedDevice(String id, String newName) async {
    await trust.rename(id, _cleanName(newName));
    _refreshNearbyTrust();
    notifyListeners();
  }

  @override
  Future<void> revokeTrustedDevice(String id) async {
    await trust.revoke(id);
    _refreshNearbyTrust();
    notifyListeners();
  }

  void _refreshNearbyTrust() {
    for (final k in _nearby.keys.toList()) {
      final n = _nearby[k]!;
      final t = trust.byDeviceId(n.deviceId);
      _nearby[k] = n.withTrust(t);
    }
  }

  String _cleanName(Object? v) {
    final s = (v is String ? v : 'Device')
        .replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '')
        .trim();
    if (s.isEmpty) return 'Device';
    return s.length > 40 ? s.substring(0, 40) : s;
  }
}

class PairingException implements Exception {
  const PairingException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Client side of pairing: shows [code]; the user confirms it matches the
/// other screen, then [confirm] asks the other device to approve.
class PairingSession {
  PairingSession._({
    required IsekaiEngine engine,
    required SecureSocket socket,
    required this.host,
    required this.port,
    required this.serverFp,
    required this.serverCertPem,
    required this.code,
    this.verifiedByQr = false,
  }) : _engine = engine, // ignore: prefer_initializing_formals
       _socket = socket; // ignore: prefer_initializing_formals

  final IsekaiEngine _engine;
  final SecureSocket _socket;
  final String host;
  final int port;
  final String serverFp;
  final String serverCertPem;
  final String code;

  /// The other device's key matched the scanned QR code exactly.
  final bool verifiedByQr;

  Future<TrustedDevice> confirm() => _engine._clientConfirmPairing(this);

  void cancel() => _socket.destroy();
}

/// A device seen on the network. Trust comes only from [trusted].
class NearbyDevice {
  NearbyDevice({
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.host,
    required this.port,
    required this.seenAt,
    this.trusted,
    this.fingerprintMismatch = false,
  });

  final String deviceId;
  final String name;
  final String platform;
  final String host;
  final int port;
  final DateTime seenAt;
  final TrustedDevice? trusted;
  final bool fingerprintMismatch;

  NearbyDevice withTrust(TrustedDevice? t) => NearbyDevice(
    deviceId: deviceId,
    name: name,
    platform: platform,
    host: host,
    port: port,
    seenAt: seenAt,
    trusted: t,
    fingerprintMismatch: fingerprintMismatch && t != null,
  );
}
