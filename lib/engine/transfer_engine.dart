/// The boundary between the UI and the transfer engine.
///
/// Screens only use [TransferEngine]. The real implementation is
/// IsekaiEngine (lib/engine/core/engine.dart). History is real and
/// persisted (core/history_store.dart) since Phase 6.
library;

import 'package:flutter/foundation.dart';

import 'core/engine.dart';
import 'core/benchmark_store.dart';
import 'core/history_store.dart';
import 'core/jobs.dart';
import 'core/pending_send_store.dart';
import 'core/send_source.dart';
import 'core/trust_store.dart';

export 'core/benchmark_store.dart';
export 'core/history_store.dart';
export 'core/engine.dart' show NearbyDevice, PairingSession, PairingException;
export 'core/identity.dart' show shortFingerprint;
export 'core/jobs.dart';
export 'core/pending_send_store.dart' show PendingSend;
export 'core/send_source.dart';
export 'core/trust_store.dart' show TrustedDevice, TrustStatus;
export 'models.dart';

abstract class TransferEngine implements Listenable {
  String get version;

  String get myName;
  String get myFingerprint;
  String get platformName;
  int? get listeningPort;
  String? get startError;
  String? get discoveryError;
  String? get secureStorageNote;
  String get receiveLocationNote;
  Future<List<String>> localAddresses();

  List<NearbyDevice> get nearby;
  List<TrustedDevice> get trustedDevices;

  /// Audit #5: non-null when damaged trusted-device data was skipped.
  String? get trustLoadWarning;
  List<PendingRequest> get pending;
  List<TransferJob> get jobs;

  Future<void> start();
  Future<void> stop();

  /// Last transfer problem in plain words (no names, no addresses).
  String? get lastError;
  DateTime? get lastErrorAt;
  TransferJob? get lastFinishedJob;

  /// Connects to [host]:[port] for pairing. Throws on network errors.
  /// With [expectFingerprint] (from a scanned QR code) the other device's
  /// key must match exactly, otherwise pairing stops.
  Future<PairingSession> beginPairing(
    String host,
    int port, {
    String? expectFingerprint,
  });

  Future<TransferJob> send(
    TrustedDevice device,
    List<SendSource> files, {
    String? host,
    int? port,
  });

  Future<void> renameTrustedDevice(String id, String newName);
  Future<void> revokeTrustedDevice(String id);
  Future<void> forgetTrustedDevice(String id);

  /// The user compared [codeFor] with the other device: mark as Verified.
  Future<bool> markDeviceVerified(String id);
  String codeFor(TrustedDevice d);

  Future<TransferJob?> retry(TransferJob job);

  /// Audit #9: failed sends saved by an earlier run (retry after restart).
  List<PendingSend> get interruptedSends;
  Future<TransferJob?> retrySaved(String id);
  Future<void> removeSaved(String id);
  void clearFinishedJobs();

  /// Finished transfers (persisted). Null in tests without storage.
  HistoryStore? get history;

  /// Benchmark log (no names, numbers + conditions only).
  BenchmarkStore? get benchmarks;
}
