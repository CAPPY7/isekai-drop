import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../transfer_engine.dart';
import 'bg_hasher.dart';
import 'discovery.dart';
import 'frames.dart';
import 'identity.dart';
import 'pending_send_store.dart';
import 'resume_store.dart';
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

/// Audit #4: limits against connection floods from the local network.
const int kMaxHandshakes = 8; // TLS handshakes + first message at once
const int kMaxSessions = 32; // all incoming connections at once
const Duration kHandshakeTimeout = Duration(seconds: 10);
const Duration kFirstMessageTimeout = Duration(seconds: 10);

/// Audit #16: keep this much space free after receiving.
/// Audit #18: flush (wait for the socket to drain) after this many bytes,
/// so unsent TLS data in memory stays small.
const int kFlushEveryBytes = 1024 * 1024;

const int kFreeSpaceMargin = 64 * 1024 * 1024;

String _mb(int b) => (b / (1024 * 1024)).ceil().toString();

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
    this.history,
    this.benchmarks,
    this.resume,
    this.pendingSends,
    this.freeSpace,
    this.sourceCodec = const SendSourceCodec(),
    bool Function()? acceptingFiles,
    bool Function(TrustedDevice device)? autoAccept,
    bool Function()? saveFileNames,
    bool Function()? visible,
  }) : acceptingFiles = acceptingFiles ?? _yes,
       autoAccept = autoAccept ?? _no,
       saveFileNames = saveFileNames ?? _yes,
       visible = visible ?? _yes;

  static bool _yes() => true;
  static bool _no(TrustedDevice _) => false;

  /// Finished transfers are written here (no file contents).
  @override
  final HistoryStore? history;

  /// Benchmark runs (measured numbers + conditions only).
  @override
  final BenchmarkStore? benchmarks;

  /// Audit #16: free bytes where incoming files are written, or null if
  /// this platform cannot tell (then no check is made).
  final Future<int?> Function(Directory dir)? freeSpace;

  /// Audit #9: failed sends kept for retry after a restart. Null = off.
  final PendingSendStore? pendingSends;
  final SendSourceCodec sourceCodec;

  @override
  List<PendingSend> get interruptedSends => pendingSends?.items ?? const [];

  /// Retries a send saved by an earlier run of the app. Returns null if the
  /// device is gone or a file can no longer be opened (entry is kept).
  @override
  Future<TransferJob?> retrySaved(String id) async {
    final store = pendingSends;
    if (store == null) return null;
    final p = store.items.where((e) => e.id == id).firstOrNull;
    if (p == null) return null;
    final dev = trust.byId(p.trustedId);
    if (dev == null || dev.status == TrustStatus.revoked) return null;
    final files = <SendSource>[];
    for (final m in p.sources) {
      final s = sourceCodec.decode(m);
      if (s == null) return null;
      files.add(s);
    }
    return send(dev, files);
  }

  @override
  Future<void> removeSaved(String id) async {
    await pendingSends?.remove(id);
    notifyListeners();
  }

  void _trackPending(TransferJob job) {
    final store = pendingSends;
    if (store == null || job.direction != JobDirection.sending) return;
    final dev = trust.byId(job.trustedId ?? '');
    if (dev == null || job.sources.isEmpty) return;
    final id = transferIdFor(dev.fingerprint, job.sources);
    if (job.state != JobState.failed || job.refusedByPeer) {
      _keep(store.remove(id));
      return;
    }
    final enc = <Map<String, dynamic>>[];
    for (final s in job.sources) {
      final m = sourceCodec.encode(s);
      if (m == null) return;
      enc.add(m);
    }
    _keep(
      store.put(
        PendingSend(
          id: id,
          trustedId: dev.id,
          peerName: dev.name,
          totalBytes: job.totalBytes,
          createdAt: DateTime.now().toUtc(),
          sources: enc,
        ),
      ),
    );
  }

  /// Receiver-side resume state. Null = interrupted transfers start over.
  final ResumeStore? resume;

  /// Settings: receive files at all (from trusted devices).
  final bool Function() acceptingFiles;

  /// Settings: accept without asking. The engine additionally requires the
  /// device to be VERIFIED; anything else is always asked.
  final bool Function(TrustedDevice device) autoAccept;

  /// Settings: keep file names in History (on this device only).
  final bool Function() saveFileNames;

  /// Settings: announce this device on the network.
  final bool Function() visible;

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

  /// Test hook only: the sender drops the connection after this many bytes
  /// of file data were sent in one attempt (simulates a network drop).
  @visibleForTesting
  int? debugDropAfterBytes;

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

  /// Problems seen since start (newest first, max 20) and counters, for
  /// Diagnostics. Never contain file names, device names or peer addresses.
  @override
  final DiagLog diagLog = DiagLog();
  @override
  final DiagCounters diagCounters = DiagCounters();

  /// Records a problem for Diagnostics and makes it the "Last error".
  void recordProblem(String kind, String message) {
    final e = diagLog.add(kind, message);
    _lastError = message;
    _lastErrorAt = e.at;
    notifyListeners();
  }

  /// Like [recordProblem] for an exception: the class comes from
  /// [classifyError]; [what] says what was being done.
  void recordException(String what, Object e) {
    final kind = e is PairingException ? 'pair_refused' : classifyError(e);
    final words = e is PairingException ? e.message : explainErrorClass(kind);
    recordProblem('${what}_$kind', '$what: $words');
  }

  /// Last problem, in plain words. Never contains file names,
  /// device names or addresses.
  @override
  String? get lastError => _lastError;
  @override
  DateTime? get lastErrorAt => _lastErrorAt;
  @override
  TransferJob? get lastFinishedJob => _lastFinished;

  final Set<String> _recorded = {};

  void _recordEnd(TransferJob job) {
    if (job.isActive) return;
    if (!_recorded.add(job.id)) return;
    _lastFinished = job;
    _trackPending(job);
    final h = history;
    if (h != null) {
      final now = DateTime.now().toUtc();
      _keep(
        h.add(
          HistoryEntry(
            id: job.id,
            direction: job.direction == JobDirection.sending
                ? HistoryDirection.sent
                : HistoryDirection.received,
            outcome: switch (job.state) {
              JobState.completed => HistoryOutcome.completed,
              JobState.cancelled => HistoryOutcome.cancelled,
              _ => HistoryOutcome.failed,
            },
            peerName: job.peerName,
            peerDeviceId: job.peerDeviceId,
            fileCount: job.fileCount,
            totalBytes: job.totalBytes,
            bytesDone: job.bytesDone,
            createdAt: job.createdAt,
            updatedAt: now,
            fileNames: saveFileNames() ? job.fileNames : const [],
            destination: job.direction == JobDirection.receiving
                ? receiveLocationNote
                : null,
            message: job.message,
            resumedBytes: job.resumedBytes,
          ),
        ),
      );
    }
    if (job.state == JobState.failed && job.message != 'Cancelled') {
      recordProblem(
        job.direction == JobDirection.sending
            ? 'send_failed'
            : 'receive_failed',
        job.message ?? 'Transfer failed',
      );
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
  String? get trustLoadWarning => trust.loadWarning;
  @override
  List<PendingRequest> get pending => List.unmodifiable(_pending);
  @override
  List<TransferJob> get jobs => List.unmodifiable(_jobs);

  @override
  Future<List<String>> localAddresses() async => [
    for (final n in await localNets()) n.ip,
  ];

  /// Android: exact interface list from the system (prefix, Wi-Fi flag).
  /// Set by platform_engine; null elsewhere (Dart's list is used).
  Future<List<LocalNet>> Function()? nativeNets;

  /// THIS device's useful local addresses, best first: Wi-Fi/hotspot and
  /// Ethernet first; mobile data, VPN, tunnels and link-local left out
  /// (see rankLocalNets). Used by the QR code, "My addresses" and discovery.
  @override
  Future<List<LocalNet>> localNets() async {
    List<LocalNet> raw = const [];
    final native = nativeNets;
    if (native != null) {
      try {
        raw = await native();
      } catch (_) {
        raw = const [];
      }
    }
    if (raw.isEmpty) raw = await dartLocalNets();
    return rankLocalNets(raw);
  }

  @override
  Future<void> start() async {
    try {
      await resume?.cleanup();
    } catch (_) {}
    try {
      final addr = bindAddress ?? InternetAddress.anyIPv4;
      try {
        _server = await ServerSocket.bind(addr, port);
      } on SocketException catch (e) {
        _server = await ServerSocket.bind(addr, 0);
        recordProblem(
          'port_fallback_${classifyError(e)}',
          'Port $port was busy; receiving on port ${_server!.port} instead. '
              'Typed addresses must use this port.',
        );
      }
      _server!.listen(_onIncoming);
    } catch (e) {
      _startError = 'Could not start receiving on this device.';
      recordProblem('server_bind_${classifyError(e)}', _startError!);
    }
    if (enableDiscovery && _server != null) {
      _discovery = Discovery(
        ownDeviceId: identity.deviceId,
        onFound: _onFound,
        shouldAnnounce: visible,
        counters: diagCounters,
        interfaces: localNets,
      );
      await _discovery!.start(
        () => {
          'device_id': identity.deviceId,
          'name': deviceName(),
          'platform': platformName,
          'port': _server!.port,
          'fp': identity.fingerprint,
        },
      );
      if (_discovery!.error != null) {
        recordProblem('discovery_unavailable', _discovery!.error!);
      }
    }
    _pruneTimer ??= Timer.periodic(const Duration(seconds: 5), (_) {
      final before = _nearby.length;
      final now = DateTime.now();
      _nearby.removeWhere(
        (k, d) =>
            now.difference(d.seenAt).inSeconds > 30 &&
            !(_keepUntil[k]?.isAfter(now) ?? false),
      );
      if (_nearby.length != before) notifyListeners();
    });
    notifyListeners();
  }

  /// Saves started in the background (history, addresses, pending sends).
  /// [stop] waits for them, so nothing writes into a folder after stop.
  final Set<Future<void>> _bg = {};

  void _keep(Future<void> f) {
    final g = f.catchError((Object _) {});
    _bg.add(g);
    g.whenComplete(() => _bg.remove(g));
  }

  @override
  Future<void> stop() async {
    _pruneTimer?.cancel();
    _pruneTimer = null;
    _discovery?.stop();
    await _server?.close();
    _server = null;
    // Let sessions that are just ending finish their own saves (max 2 s).
    final until = DateTime.now().add(const Duration(seconds: 2));
    while (_sessions > 0 && DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    while (_bg.isNotEmpty) {
      await Future.wait(_bg.toList())
          .timeout(const Duration(seconds: 5), onTimeout: () => const []);
      if (DateTime.now().isAfter(until.add(const Duration(seconds: 5)))) break;
    }
  }

  // ------------------------------------------------------- network search

  bool _scanning = false;
  int? _lastScanFound;
  final Map<String, DateTime> _keepUntil = {};

  @override
  bool get scanning => _scanning;
  @override
  int? get lastScanFound => _lastScanFound;

  /// Asks one address "are you Isekai Drop?" (TLS, no client key). Returns
  /// what it says about itself, or null. Untrusted, like an announcement:
  /// the fingerprint comes from the TLS certificate, not from the answer.
  Future<Announcement?> probe(
    String host,
    int port, {
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    SecureSocket? s;
    FrameReader? r;
    try {
      return await () async {
        s = await SecureSocket.connect(
          host,
          port,
          context: _ownContext(withCert: false),
          onBadCertificate: (_) => true,
          timeout: timeout,
        );
        final sock = s!;
        final cert = sock.peerCertificate;
        if (cert == null) return null;
        final fp = fingerprintOfDer(cert.der);
        if (fp == identity.fingerprint) return null;
        unawaited(sock.done.then((_) {}, onError: (_) {}));
        sock.add(jsonFrame({'t': 'info', 'v': kProtocolVersion}));
        r = FrameReader(sock);
        final m = await r!.nextJson(timeout);
        final id = m['device_id'];
        if (m['t'] != 'info' || id is! String || id.isEmpty) return null;
        return Announcement(
          deviceId: id,
          name: _cleanName(m['name']),
          platform: _cleanName(m['platform']),
          port: m['port'] is int ? m['port'] as int : port,
          fingerprint: fp,
          host: host,
          seenAt: DateTime.now(),
        );
      }().timeout(timeout * 2);
    } catch (_) {
      return null;
    } finally {
      s?.destroy();
      try {
        await r?.cancel();
      } catch (_) {}
    }
  }

  /// Searches this device's Wi-Fi/hotspot/cable networks address by
  /// address (max 254 per network). Works where the router or hotspot
  /// blocks discovery packets. Returns how many devices answered.
  @override
  Future<int> scanNetwork({int? port, int parallel = 64}) async {
    // Part of discovery: engines built without it (tests, embedded use)
    // never touch the real network.
    if (_scanning || !enableDiscovery) return 0;
    _scanning = true;
    notifyListeners();
    var found = 0;
    try {
      final nets = await localNets();
      final own = {for (final n in nets) n.ip};
      final targets = <String>{};
      for (final n in nets.take(3)) {
        targets.addAll(scanTargets(n));
      }
      targets.removeAll(own);
      final list = targets.toList();
      var next = 0;
      Future<void> worker() async {
        while (next < list.length && _server != null) {
          final h = list[next++];
          final a = await probe(h, port ?? kDefaultPort);
          if (a != null && a.deviceId != identity.deviceId) {
            found++;
            _keepUntil[a.deviceId] = DateTime.now().add(
              const Duration(minutes: 5),
            );
            _onFound(a);
          }
        }
      }

      await Future.wait([for (var k = 0; k < parallel; k++) worker()]);
    } catch (e) {
      recordException('network_search', e);
    } finally {
      _scanning = false;
      _lastScanFound = found;
      notifyListeners();
    }
    return found;
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
    // Announcements are NOT authenticated, so they never change saved
    // trust data. The address is saved only after a TLS session succeeds.
    notifyListeners();
  }

  // ---------------------------------------------------------------- approvals

  /// How long an approval dialog waits. Changeable only for tests.
  @visibleForTesting
  Duration approvalTimeout = kApprovalTimeout;

  /// Time allowed for the first message after TLS. Changeable only for tests.
  @visibleForTesting
  Duration firstMessageTimeout = kFirstMessageTimeout;

  /// Time a pairing client (after `pair_hello`) has for its user to compare
  /// the code before sending `pair_req`. Changeable only for tests.
  @visibleForTesting
  Duration pairCompareTimeout = kApprovalTimeout;

  @visibleForTesting
  Future<bool> debugAsk(PendingRequest r) => _ask(r);

  Future<bool> _ask(PendingRequest r) async {
    if (debugAutoDecide != null) return debugAutoDecide!(r);
    _pending.add(r);
    notifyListeners();
    try {
      return await r.decision.timeout(
        approvalTimeout,
        onTimeout: () {
          r.expire();
          return false;
        },
      );
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

  int _sessions = 0;
  int _handshaking = 0;

  @visibleForTesting
  int get debugOpenSessions => _sessions;

  Future<void> _onIncoming(Socket raw) async {
    if (_sessions >= kMaxSessions || _handshaking >= kMaxHandshakes) {
      raw.destroy(); // too many at once: refuse immediately
      return;
    }
    _sessions++;
    _handshaking++;
    diagCounters.incomingConnections++;
    var handshakeDone = false;
    void endHandshake() {
      if (!handshakeDone) {
        handshakeDone = true;
        _handshaking--;
      }
    }

    try {
      await _onIncomingSession(raw, endHandshake);
    } finally {
      endHandshake();
      _sessions--;
    }
  }

  Future<void> _onIncomingSession(
    Socket raw,
    void Function() endHandshake,
  ) async {
    SecureSocket s;
    try {
      // Small control messages must not wait ~40 ms (Nagle + delayed ACK).
      raw.setOption(SocketOption.tcpNoDelay, true);
      s = await SecureSocket.secureServer(
        raw,
        _serverContext(),
        requestClientCertificate: true,
      ).timeout(kHandshakeTimeout);
      // Write errors after the peer left (broken pipe) surface here; the
      // session code already handles the lost connection.
      unawaited(s.done.then((_) {}, onError: (_) {}));
    } catch (e) {
      // Unknown, revoked or broken client certificate: rejected by TLS.
      diagCounters.incomingTlsRejected++;
      recordProblem(
        'incoming_${classifyError(e)}',
        'Incoming connection: secure setup failed (not paired with this '
            'device, revoked, or not Isekai Drop).',
      );
      raw.destroy();
      return;
    }
    final reader = FrameReader(s);
    var stage = 'incoming_first_message';
    try {
      var first = await reader.nextJson(firstMessageTimeout);
      endHandshake();
      stage = 'incoming_session';
      final peerCert = s.peerCertificate;
      // "Are you Isekai Drop?" from Search this network. Says only what
      // UDP announcements say anyway, and nothing when not visible.
      if (first['t'] == 'info') {
        if (visible()) {
          s.add(
            jsonFrame({
              't': 'info',
              'v': kProtocolVersion,
              'device_id': identity.deviceId,
              'name': deviceName(),
              'platform': platformName,
              'port': _server?.port,
            }),
          );
        }
        return;
      }
      // Pairing: the client says hello at once, then its user compares the
      // code (can take a while). Only one such slow wait at a time.
      if (peerCert == null && first['t'] == 'pair_hello') {
        if (_pairHelloOpen) {
          s.add(jsonFrame({'t': 'pair_denied', 'reason': 'busy'}));
          return;
        }
        _pairHelloOpen = true;
        stage = 'incoming_pair_wait';
        try {
          first = await reader.nextJson(pairCompareTimeout);
        } finally {
          _pairHelloOpen = false;
        }
      }
      if (peerCert == null) {
        // No client certificate: the only thing allowed is a pairing request.
        if (first['t'] == 'pair_req') {
          stage = 'incoming_pairing';
          await _serverPairing(s, reader, first);
        } else {
          recordProblem(
            'incoming_not_paired',
            'A device that is not paired tried to connect. Pair first.',
          );
          s.add(jsonFrame({'t': 'error', 'reason': 'not_trusted'}));
        }
        return;
      }
      final dev = trust.byFingerprint(fingerprintOfDer(peerCert.der));
      if (dev == null || !dev.isTrusted) {
        recordProblem(
          'incoming_not_trusted',
          'A device that is no longer trusted tried to connect.',
        );
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
    } catch (e) {
      // Connection problems end this session only.
      recordException(stage, e);
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
    // One pairing question at a time: a flood of requests from the network
    // must not fill the screen with prompts.
    if (_pairingOpen) {
      s.add(jsonFrame({'t': 'pair_denied', 'reason': 'busy'}));
      return;
    }
    _pairingOpen = true;
    try {
      final pp = m['port'];
      await _serverPairingAsk(
        s,
        peerId,
        name,
        platform,
        certPem,
        peerFp,
        peerPort: pp is int && pp > 0 && pp < 65536 ? pp : null,
        offer: _PairOffer.parse(m['offer']),
      );
    } finally {
      _pairingOpen = false;
    }
  }

  bool _pairingOpen = false;
  final Map<String, _PreApproval> _preApproved = {};
  bool _pairHelloOpen = false;

  Future<void> _serverPairingAsk(
    SecureSocket s,
    String peerId,
    String name,
    String platform,
    String certPem,
    String peerFp, {
    int? peerPort,
    _PairOffer? offer,
  }) async {
    final known = trust.byDeviceId(peerId);
    final req = PendingRequest(
      id: randomHex(8),
      kind: RequestKind.pairing,
      peerName: name,
      peerPlatform: platform,
      code: verificationCode(identity.fingerprint, peerFp),
      keyChanged: known != null && known.fingerprint != peerFp,
      fileNames: offer?.names ?? const [],
      totalBytes: offer?.bytes ?? 0,
      offerCount: offer?.count ?? 0,
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
      port: peerPort,
      // One tap = trusted on first use (TOFU), not "Verified". Re-pairing
      // the same key keeps an earlier "Verified".
      verified: trust.byFingerprint(peerFp)?.isVerified ?? false,
    );
    if (offer != null && acceptingFiles()) {
      _preApproved[peerFp] = _PreApproval(
        offer.tid,
        DateTime.now().add(const Duration(minutes: 3)),
      );
    }
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
    if (!acceptingFiles()) {
      s.add(jsonFrame({'t': 'decline', 'reason': 'not_accepting'}));
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

    // Resume (optional): only for this sender's key + this transfer id.
    final rawTid = offer['tid'];
    final tid =
        rawTid is String && RegExp(r'^[0-9a-f]{16,64}$').hasMatch(rawTid)
        ? rawTid
        : null;
    final store = tid == null ? null : resume;
    final offerList = [
      for (var i = 0; i < names.length; i++) (names[i], sizes[i]),
    ];
    ResumeState? state;
    var already = 0;
    if (store != null) {
      state = await store.load(dev.fingerprint, tid!);
      if (state != null && !state.matches(offerList)) {
        await store.discard(state.key);
        state = null;
      }
      if (state != null) {
        for (final i in state.done.keys) {
          already += sizes[i];
        }
        final pi = state.partialIndex;
        if (pi != null) already += await store.partialLength(state, pi);
      }
    }

    // Audit #16: refuse at once if this device cannot hold the files.
    final need = total - already + kFreeSpaceMargin;
    int? free;
    try {
      free = await freeSpace?.call(tempDir);
    } catch (_) {}
    if (free != null && free < need) {
      recordProblem(
        'no_free_space',
        'Not enough free space to receive '
            '(${_mb(need)} MB needed, ${_mb(free)} MB free).',
      );
      s.add(
        jsonFrame({
          't': 'decline',
          'reason': 'no_space',
          'need': need,
          'free': free,
        }),
      );
      return;
    }

    final job = TransferJob(
      id: randomHex(8),
      direction: JobDirection.receiving,
      peerName: dev.name,
      fileCount: names.length,
      totalBytes: total,
      peerDeviceId: dev.deviceId,
      peerPlatform: dev.platform,
      trustedId: dev.id,
      fileNames: names,
    );
    final req = PendingRequest(
      id: job.id,
      kind: RequestKind.transfer,
      peerName: dev.name,
      peerPlatform: dev.platform,
      fileNames: names,
      totalBytes: total,
      job: job,
      resumeBytes: already,
    );
    // Auto-receive only from VERIFIED devices, and only when switched on.
    // 0.9.1: or when the user just accepted a one-tap "pair and send" from
    // this exact key for this exact transfer (one-time, expires quickly).
    final pre = _preApproved.remove(dev.fingerprint);
    final preOk =
        pre != null &&
        tid != null &&
        pre.tid == tid &&
        DateTime.now().isBefore(pre.until);
    final auto = preOk || (dev.isVerified && autoAccept(dev));
    if (!auto && !await _ask(req)) {
      s.add(jsonFrame({'t': 'decline', 'reason': 'declined'}));
      return;
    }
    _jobs.insert(0, job);
    notifyListeners();
    var discardState = false;
    job.onCancel = () {
      discardState = true;
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
    if (store != null) {
      state ??= await store.create(dev.fingerprint, tid!, offerList);
    }
    final offsets = <int, int>{};
    if (state != null) {
      final pi = state.partialIndex;
      if (pi != null && !state.done.containsKey(pi)) {
        final n = await store!.partialLength(state, pi);
        if (n > 0) offsets[pi] = n;
      }
      for (final e in state.done.entries) {
        job.savedTo.add(e.value);
        job.filesDone++;
      }
    }
    job.start();
    if (already > 0) job.addResumed(already);
    s.add(
      jsonFrame({
        't': 'accept',
        if (state != null) ...{
          'skip': state.done.keys.toList()..sort(),
          'offsets': {for (final e in offsets.entries) '${e.key}': e.value},
        },
      }),
    );
    await s.flush();
    final batch = state != null ? store!.batchFor(state) : ReceiveBatch();
    File? temp;
    RandomAccessFile? out;
    FileHasher? hasher;
    var keepPartial = false;
    try {
      for (var i = 0; i < names.length; i++) {
        if (state != null && state.done.containsKey(i)) continue;
        await job.waitIfPaused();
        final head = await _nextControl(reader, job);
        if (head['t'] == 'cancel') {
          discardState = true;
          job.finish(JobState.cancelled, 'The sender cancelled.');
          return;
        }
        final offset = offsets[i] ?? 0;
        if (head['t'] != 'file' ||
            head['i'] != i ||
            ((head['offset'] as int?) ?? 0) != offset) {
          throw const FormatException('Unexpected message');
        }
        hasher?.dispose();
        hasher = await fileHasher(sizes[i]);
        if (state != null) {
          temp = store!.partFile(state.key);
          if (offset > 0) {
            // Re-hash what is already on disk; the final check covers the
            // whole file from byte 0.
            var n = 0;
            await for (final c in temp.openRead(0, offset)) {
              await hasher.add(c);
              n += c.length;
            }
            if (n != offset) throw const FileSystemException('Partial changed');
            out = await temp.open(mode: FileMode.append);
          } else {
            await store.dir.create(recursive: true);
            out = await temp.open(mode: FileMode.write);
            state.partialIndex = i;
            await store.save(state);
          }
          keepPartial = true;
        } else {
          try {
            temp = await createTempPart(tempDir);
            out = await temp.open(mode: FileMode.writeOnly);
          } catch (e) {
            throw _WriteFailed(e);
          }
        }
        var got = offset;
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
              discardState = true;
              job.finish(JobState.cancelled, 'The sender cancelled.');
              return;
            }
            throw const FormatException('Expected file data');
          }
          if (got + fr.payload.length > sizes[i]) {
            throw const FormatException('More data than announced');
          }
          try {
            await out.writeFrom(fr.payload);
          } catch (e) {
            throw _WriteFailed(e);
          }
          await hasher.add(fr.payload);
          got += fr.payload.length;
          job.addBytes(fr.payload.length);
        }
        final end = await _nextControl(reader, job);
        await out.close();
        out = null;
        final actual = await hasher.close();
        hasher = null;
        if (end['t'] != 'file_end' ||
            end['i'] != i ||
            end['sha256'] != actual) {
          await temp.delete();
          temp = null;
          keepPartial = false;
          discardState = true;
          s.add(jsonFrame({'t': 'file_bad', 'i': i}));
          job.finish(
            JobState.failed,
            'Integrity check failed. The damaged file was deleted. '
            'Retry sends it again from the start.',
          );
          return;
        }
        final String where;
        try {
          where = await finalizer(temp, names[i], batch);
        } catch (e) {
          throw _WriteFailed(e);
        }
        temp = null;
        keepPartial = false;
        if (state != null) {
          state.done[i] = where;
          state.partialIndex = null;
          state.topFolders
            ..clear()
            ..addAll(batch.topFolders);
          await store!.save(state);
        }
        job.savedTo.add(where);
        job.filesDone++;
        s.add(jsonFrame({'t': 'file_ok', 'i': i}));
      }
      final done = await _nextControl(reader, job);
      if (done['t'] == 'done') s.add(jsonFrame({'t': 'done_ok'}));
      discardState = true;
      job.finish(JobState.completed, 'All files received and verified.');
    } on _WriteFailed catch (w) {
      // Tell the sender it is a storage problem HERE, not the network.
      try {
        s.add(jsonFrame({'t': 'error', 'reason': 'write_failed'}));
        await s.flush();
      } catch (_) {}
      recordProblem(
        'receive_write_${classifyError(w.cause)}',
        'Receiving: could not save the file on this device '
            '(${explainErrorClass(classifyError(w.cause))}).',
      );
      job.finish(
        JobState.failed,
        'Could not save the file on this device (storage problem). '
        'Nothing unverified was kept. Check free space, then ask the sender to retry.',
      );
    } catch (e) {
      recordProblem(
        'receive_${classifyError(e)}',
        'Receiving: the connection ended during the transfer '
            '(${explainErrorClass(classifyError(e))}).',
      );
      job.finish(
        JobState.failed,
        state != null && !discardState
            ? 'The connection was lost. Nothing unverified was saved. '
                  'When the sender taps Retry, it continues where it stopped.'
            : 'The transfer stopped. Nothing unverified was kept.',
      );
    } finally {
      hasher?.dispose();
      try {
        await out?.close();
      } catch (_) {}
      if (state != null) {
        if (discardState || job.cancelRequested) {
          await store!.discard(state.key);
        }
      } else if (!keepPartial && temp != null && await temp.exists()) {
        await temp.delete();
      }
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
    try {
      return await _beginPairing(
        host,
        port,
        expectFingerprint: expectFingerprint,
      );
    } catch (e) {
      recordException('pair_connect', e);
      rethrow;
    }
  }

  /// One-tap pairing: connect, then the other device shows one
  /// "Accept NAME?" question. Both remember each other (trusted on first
  /// use; "Verified" only with a matching QR code).
  @override
  Future<TrustedDevice> quickPair(
    String host,
    int port, {
    String? expectFingerprint,
  }) async {
    final session = await beginPairing(
      host,
      port,
      expectFingerprint: expectFingerprint,
    );
    return session.confirm();
  }

  /// One tap on a nearby device to send [files]. Already paired: sends.
  /// Not paired: the other device gets ONE question ("NAME wants to send
  /// you N files - Accept?"); yes pairs both devices and starts the send
  /// without a second question. Throws [PairingException] if declined.
  @override
  Future<TransferJob> sendToNearby(
    NearbyDevice n,
    List<SendSource> files,
  ) async {
    final t = n.trusted;
    if (t != null && t.isTrusted && !n.fingerprintMismatch) {
      return send(t, files, host: n.host, port: n.port);
    }
    final session = await beginPairing(n.host, n.port);
    final dev = await session.confirm(offer: files);
    return send(dev, files, host: n.host, port: n.port);
  }

  Future<PairingSession> _beginPairing(
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
    s.add(jsonFrame({'t': 'pair_hello', 'v': kProtocolVersion}));
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

  Future<TrustedDevice> _clientConfirmPairing(
    PairingSession p, {
    List<SendSource>? offer,
    bool codeCompared = false,
  }) async {
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
          'port': _server?.port,
          if (offer != null && offer.isNotEmpty)
            'offer': {
              'count': offer.length,
              'bytes': offer.fold<int>(0, (a, f) => a + f.size),
              'tid': transferIdFor(p.serverFp, offer),
              'names': [for (final f in offer.take(3)) f.relativePath],
            },
        }),
      );
      await s.flush();
      final r = await reader.nextJson(
        kApprovalTimeout + const Duration(seconds: 10),
      );
      if (r['t'] != 'pair_ok') {
        throw PairingException(switch (r['reason']) {
          'declined' => 'The other device declined.',
          'busy' => 'The other device is already answering another pairing request. Try again in a moment.',
          _ => 'Pairing was refused.',
        });
      }
      final dev = await trust.addTrusted(
        deviceId: r['device_id'] as String,
        name: _cleanName(r['name']),
        platform: _cleanName(r['platform']),
        certPem: p.serverCertPem,
        host: p.host,
        port: (r['port'] as int?) ?? p.port,
        // One tap = trusted on first use. "Verified" only after the code
        // was compared or the QR code matched the key.
        verified:
            p.verifiedByQr ||
            codeCompared ||
            (trust.byFingerprint(p.serverFp)?.isVerified ?? false),
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
    // Only an address where this device was last AUTHENTICATED counts as
    // evidence of a real identity change. A wrong key anywhere else may be
    // a spoofed announcement: refuse it, but don't block the real device.
    final atKnownAddress = host == dev.lastHost && port == dev.lastPort;
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
      unawaited(sock.done.then((_) {}, onError: (_) {}));
      return sock;
    } catch (e) {
      if (mismatch && !atKnownAddress) {
        throw const PairingException(
          'A device at that address claims to be this device but has a different key. '
          'Not connected. Your saved device was not changed.',
        );
      }
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
      peerDeviceId: dev.deviceId,
      peerPlatform: dev.platform,
      trustedId: dev.id,
      sources: List.unmodifiable(files),
      fileNames: [for (final f in files) f.relativePath],
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
    if (!job.isActive) {
      _recordEnd(job); // cancelled while queued
      return;
    }
    job.queued = false;
    job.notifyListeners();
    if (!dev.isTrusted) {
      job.finish(JobState.failed, 'This device is blocked. Pair again first.');
      _recordEnd(job);
      return;
    }
    // 0.9.1: try every address we know (given, live announcement, last
    // authenticated one) instead of failing on the first stale one.
    final tries = _addressesFor(dev, host, port);
    if (tries.isEmpty) {
      job.finish(
        JobState.failed,
        'Address unknown. Open Isekai Drop on the other device, on the same Wi-Fi, and try again.',
      );
      _recordEnd(job);
      return;
    }
    SecureSocket? s;
    FrameReader? reader;
    var stage = _SendStage.connect;
    try {
      Object? connectError;
      String? usedHost;
      var usedPort = kDefaultPort;
      for (final (h, pt) in tries) {
        try {
          s = await _connectTrusted(dev, h, pt);
          usedHost = h;
          usedPort = pt;
          break;
        } on PairingException {
          rethrow;
        } catch (e) {
          connectError = e;
          final c = classifyError(e);
          diagLog.add(
            c.startsWith('connect_') ? 'send_$c' : 'send_connect_$c',
            'Sending: connecting failed: ${explainErrorClass(c)}',
          );
          if (job.cancelRequested) break;
        }
      }
      if (s == null) throw connectError ?? const SocketException('no address');
      final sock = s;
      stage = _SendStage.answer;
      // Authenticated by TLS (key matched): now it is safe to remember.
      _keep(trust.rememberAddress(dev.id, usedHost!, usedPort));
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
          'tid': transferIdFor(dev.fingerprint, files),
          'files': [
            for (final f in files)
              {'name': f.name, 'path': f.relativePath, 'size': f.size},
          ],
        }),
      );
      await _flushOrClosed(sock);
      final answer = await reader.nextJson(
        kApprovalTimeout + const Duration(seconds: 10),
      );
      if (answer['t'] == 'error') {
        job.refusedByPeer = true;
        job.finish(JobState.failed, _peerErrorText(answer));
        return;
      }
      if (answer['t'] != 'accept') {
        job.refusedByPeer = true;
        job.finish(JobState.failed, switch (answer['reason']) {
          'not_accepting' => 'The other device is not accepting files right now (turned off in its Settings).',
          'no_space' =>
            'The other device does not have enough free space'
                '${answer['need'] is int && answer['free'] is int ? ' (${_mb(answer['need'] as int)} MB needed, ${_mb(answer['free'] as int)} MB free)' : ''}.',
          _ => 'The other device declined.',
        });
        return;
      }
      final skip = <int>{
        for (final x in (answer['skip'] as List? ?? const []))
          if (x is int && x >= 0 && x < files.length) x,
      };
      final offsets = <int, int>{};
      final rawOffsets = answer['offsets'];
      if (rawOffsets is Map) {
        for (final e in rawOffsets.entries) {
          final i = int.tryParse('${e.key}');
          final v = e.value;
          if (i != null &&
              i >= 0 &&
              i < files.length &&
              v is int &&
              v > 0 &&
              v <= files[i].size) {
            offsets[i] = v;
          }
        }
      }
      stage = _SendStage.transfer;
      job.start();
      var resumed = 0;
      for (final i in skip) {
        resumed += files[i].size;
      }
      for (final v in offsets.values) {
        resumed += v;
      }
      if (resumed > 0) job.addResumed(resumed);
      job.filesDone += skip.length;
      var sentThisAttempt = 0;
      FileHasher? sendHasher;
      try {
        for (var i = 0; i < files.length; i++) {
          if (skip.contains(i)) continue;
          final f = files[i];
          final offset = offsets[i] ?? 0;
          await job.waitIfPaused();
          if (job.cancelRequested) return;
          sock.add(
            jsonFrame({
              't': 'file',
              'i': i,
              'name': f.name,
              'size': f.size,
              if (offset > 0) 'offset': offset,
            }),
          );
          final hasher = sendHasher = await fileHasher(f.size);
          var sent = 0;
          var sinceFlush = 0;
          await for (final chunk in f.open().handleError(
            (Object e) => throw e is SourceReadException
                ? e
                : SourceReadException(classifyError(e)),
          )) {
            if (job.paused) {
              await _flushOrClosed(sock);
              await job.waitIfPaused();
            }
            if (job.cancelRequested) return;
            if (sent + chunk.length > f.size) {
              throw const FileSystemException('File changed while sending');
            }
            // The whole file is always hashed from byte 0; bytes the receiver
            // already has are hashed but not sent again.
            await hasher.add(chunk);
            List<int> part = chunk;
            if (sent < offset) {
              final skipN = offset - sent;
              sent += chunk.length;
              if (chunk.length <= skipN) continue;
              part = chunk.sublist(skipN);
            } else {
              sent += chunk.length;
            }
            final wire = debugTamper != null ? debugTamper!(part) : part;
            sock.add(encodeFrame(frameData, wire));
            sinceFlush += part.length;
            sentThisAttempt += part.length;
            job.addBytes(part.length);
            final drop = debugDropAfterBytes;
            if (drop != null && sentThisAttempt >= drop) {
              await _flushOrClosed(sock);
              sock.destroy();
              throw const SocketException('debug drop');
            }
            if (sinceFlush >= kFlushEveryBytes) {
              sinceFlush = 0;
              await _flushOrClosed(sock);
            }
          }
          await f.close();
          if (sent != f.size) {
            throw const FileSystemException('File size changed');
          }
          final digest = await hasher.close();
          sock.add(jsonFrame({'t': 'file_end', 'i': i, 'sha256': digest}));
          await _flushOrClosed(sock);
          final r = await _nextControl(reader, job);
          if (r['t'] != 'file_ok') {
            job.finish(
              JobState.failed,
              r['t'] == 'file_bad'
                  ? 'The other device rejected the file: integrity check failed. Tap Retry.'
                  : _peerErrorText(r),
            );
            return;
          }
          job.filesDone++;
        }
      } finally {
        sendHasher?.dispose();
      }
      sock.add(jsonFrame({'t': 'done'}));
      await _flushOrClosed(sock);
      await _nextControl(reader, job);
      job.finish(JobState.completed, 'Sent and verified by the other device.');
    } on PairingException catch (e) {
      job.finish(JobState.failed, e.message);
    } catch (e) {
      final readFailed = e is SourceReadException || e is FileSystemException;
      final cls = e is SourceReadException ? e.reason : classifyError(e);
      final where = readFailed ? 'read_file' : stage.name;
      if (!job.cancelRequested) {
        // Class only (no address or names); the job message becomes Last error.
        diagLog.add(
          cls.startsWith('${where}_') ? 'send_$cls' : 'send_${where}_$cls',
          'Sending ($where): ${readFailed ? 'could not read the file on this device' : explainErrorClass(cls)}',
        );
      }
      job.finish(
        JobState.failed,
        job.cancelRequested
            ? 'Cancelled'
            : readFailed
            ? (e is FileSystemException && e.message.contains('changed')
                  ? 'The file changed while it was being sent. Tap Retry.'
                  : 'Could not read the file on this device ($cls). '
                        'Pick the file again and send it again.')
            : _sendFailureText(stage, cls, job),
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

  List<(String, int)> _addressesFor(
    TrustedDevice dev,
    String? host,
    int? port,
  ) {
    final out = <(String, int)>[];
    void add(String? h, int? pt) {
      if (h == null || h.isEmpty) return;
      final e = (h, pt ?? kDefaultPort);
      if (!out.contains(e)) out.add(e);
    }

    add(host, port);
    for (final n in _nearby.values) {
      if (n.deviceId == dev.deviceId && !n.fingerprintMismatch) {
        add(n.host, n.port);
      }
    }
    add(dev.lastHost, dev.lastPort);
    return out;
  }

  String _peerErrorText(Map<String, dynamic> m) => switch (m['reason']) {
    'write_failed' =>
      'The other device could not save the file (its storage is full or failed). '
          'Nothing unverified was kept there.',
    'not_trusted' =>
      'The other device does not trust this device any more. Pair again.',
    _ => 'The other device stopped the transfer.',
  };

  String _sendFailureText(_SendStage stage, String cls, TransferJob job) {
    switch (stage) {
      case _SendStage.connect:
        return switch (cls) {
          'connect_refused' =>
            'Could not connect: Isekai Drop is not open on the other device '
                '(or it uses another port). Open it there and try again.',
          'connect_timeout' || 'timeout' =>
            'Could not connect: no answer. Check both devices are on the same '
                'Wi-Fi (not guest Wi-Fi). A Windows PC must allow Isekai Drop in its firewall.',
          'network_unreachable' =>
            'Could not connect: this device has no route to the other one '
                '(different network, or traffic goes over mobile data).',
          'tls_handshake_failed' || 'tls_error' =>
            'The other device refused the secure connection. It may not trust '
                'this device any more (removed or reinstalled). Pair again.',
          _ =>
            'Could not connect to the other device (${explainErrorClass(cls)})',
        };
      case _SendStage.answer:
        return switch (cls) {
          'timeout' =>
            'The other device did not answer in time (nobody accepted).',
          _ =>
            'The other device refused this device\'s secure certificate. '
                'It may not trust this device any more, or one device\'s clock '
                'is wrong. Check date and time on both, then pair again.',
        };
      case _SendStage.transfer:
        return 'The connection was lost during the transfer '
            '(${_mb(job.bytesDone)} of ${_mb(job.totalBytes)} MB). '
            'Tap Retry to continue.';
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

  @override
  Future<void> forgetTrustedDevice(String id) async {
    await trust.forget(id);
    _refreshNearbyTrust();
    notifyListeners();
  }

  @override
  Future<bool> markDeviceVerified(String id) async {
    final ok = await trust.markVerified(id);
    _refreshNearbyTrust();
    notifyListeners();
    return ok;
  }

  @override
  String codeFor(TrustedDevice d) =>
      verificationCode(identity.fingerprint, d.fingerprint);

  /// Sends the same files again to the same device. If the receiver kept
  /// the interrupted part, it continues from there (same transfer id).
  @override
  Future<TransferJob?> retry(TransferJob job) async {
    if (!job.canRetry) return null;
    final dev = trust.byId(job.trustedId ?? '');
    if (dev == null) return null;
    final next = await send(dev, job.sources);
    job.retriedBy = next.id;
    notifyListeners();
    return next;
  }

  /// Removes finished jobs from the list (History keeps the record).
  @override
  void clearFinishedJobs() {
    _jobs.removeWhere((j) => !j.isActive);
    notifyListeners();
  }

  void _refreshNearbyTrust() {
    for (final k in _nearby.keys.toList()) {
      final n = _nearby[k]!;
      final t = trust.byDeviceId(n.deviceId);
      _nearby[k] = n.withTrust(t);
    }
  }

  String _cleanName(Object? v) => cleanDeviceName(v);
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

  /// Sends the pairing request; the other device shows one
  /// "Accept NAME?" question. With [offer], that question also says which
  /// files are coming, and accepting it accepts them too (one-time).
  /// [codeCompared]: this user compared [code] with the other screen.
  Future<TrustedDevice> confirm({
    List<SendSource>? offer,
    bool codeCompared = false,
  }) async {
    try {
      return await _engine._clientConfirmPairing(
        this,
        offer: offer,
        codeCompared: codeCompared,
      );
    } catch (e) {
      _engine.recordException('pair_confirm', e);
      rethrow;
    }
  }

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

/// Same files to the same device => same id, so the receiver can continue an
/// interrupted transfer even after this app was restarted. Contains no
/// file data. A different file with the same name and size gives the same
/// id; the final SHA-256 check then fails and the next retry starts fresh.
String transferIdFor(String peerFingerprint, List<SendSource> files) {
  final b = StringBuffer('isekai-tid-v2|$peerFingerprint');
  for (final f in files) {
    b.write('|${f.relativePath}|${f.size}|${f.versionTag ?? ''}');
  }
  return sha256.convert(utf8.encode(b.toString())).toString().substring(0, 32);
}

/// Display-safe device name from untrusted input (pairing, UDP, Bonjour):
/// removes control and bidi-override characters, collapses spaces, max 40
/// characters. Audit #12.
String cleanDeviceName(Object? v) {
  final s = (v is String ? v : 'Device')
      .replaceAll(
        RegExp(
          r'[\x00-\x1F\x7F-\x9F\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]',
        ),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (s.isEmpty) return 'Device';
  final r = s.runes.toList();
  return r.length > 40 ? String.fromCharCodes(r.take(40)) : s;
}

/// Flushes, but gives up as soon as the socket is closed or broken. A plain
/// flush() can wait forever after the other side has destroyed the
/// connection, because our frame reader pauses the socket between frames.
Future<void> _flushOrClosed(Socket sock) => Future.any<void>([
  sock.flush(),
  sock.done.then<void>(
    (_) => throw const SocketException('Connection closed'),
    onError: (Object _) => throw const SocketException('Connection closed'),
  ),
]);

enum _SendStage { connect, answer, transfer }

/// Receiving: writing to this device's storage failed (not the network).
class _WriteFailed implements Exception {
  _WriteFailed(this.cause);
  final Object cause;
}

/// One-time "this transfer is already accepted" from a one-tap pair+send.
class _PreApproval {
  _PreApproval(this.tid, this.until);
  final String tid;
  final DateTime until;
}

class _PairOffer {
  _PairOffer(this.count, this.bytes, this.tid, this.names);
  final int count;
  final int bytes;
  final String tid;
  final List<String> names;

  static _PairOffer? parse(Object? v) {
    if (v is! Map) return null;
    final c = v['count'];
    final b = v['bytes'];
    final t = v['tid'];
    if (c is! int || c <= 0 || c > 10000 || b is! int || b < 0) return null;
    if (t is! String || !RegExp(r'^[0-9a-f]{16,64}$').hasMatch(t)) return null;
    final n = v['names'];
    return _PairOffer(c, b, t, [
      if (n is List)
        for (final x in n.take(3))
          if (x is String) sanitizeRelativePath(x),
    ]);
  }
}
