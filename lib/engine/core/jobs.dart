import 'dart:async';

import 'package:flutter/foundation.dart';

enum JobDirection { sending, receiving }

enum JobState { waiting, running, completed, failed, cancelled }

/// One transfer. Speed is MEASURED from bytes actually moved over time.
class TransferJob extends ChangeNotifier {
  TransferJob({
    required this.id,
    required this.direction,
    required this.peerName,
    required this.fileCount,
    required this.totalBytes,
  });

  final String id;
  final JobDirection direction;
  final String peerName;
  final int fileCount;
  final int totalBytes;

  JobState state = JobState.waiting;
  int bytesDone = 0;
  int filesDone = 0;
  String? message;
  final List<String> savedTo = [];

  final Stopwatch _clock = Stopwatch();
  final List<(int, int)> _samples = []; // (elapsed ms, bytes)
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);
  bool cancelRequested = false;
  void Function()? onCancel;

  /// Paused on THIS device by the user.
  bool paused = false;

  /// The other device told us it paused.
  bool pausedByPeer = false;

  /// Sent to the other device when we pause/resume (set by the engine).
  void Function(bool paused)? onPauseChanged;

  /// Waiting in the send queue behind another transfer.
  bool queued = false;

  Completer<void>? _resume;
  int _lastProgressMs = 0;

  bool get canPause => state == JobState.running;

  /// True when running, not paused, but no bytes moved for 5 s (for example
  /// the other device paused or the connection is stuck).
  bool get stalled =>
      state == JobState.running &&
      !paused &&
      _clock.elapsedMilliseconds - _lastProgressMs > 5000;

  void pause() {
    if (!canPause || paused) return;
    paused = true;
    _resume = Completer<void>();
    _clock.stop();
    _samples.clear();
    onPauseChanged?.call(true);
    notifyListeners();
  }

  void resume() {
    if (!paused) return;
    paused = false;
    _clock.start();
    _lastProgressMs = _clock.elapsedMilliseconds;
    onPauseChanged?.call(false);
    _resume?.complete();
    _resume = null;
    notifyListeners();
  }

  /// Engine calls this between pieces; returns when not paused.
  Future<void> waitIfPaused() async {
    final r = _resume;
    if (paused && r != null) await r.future;
  }

  void setPeerPaused(bool v) {
    if (pausedByPeer == v) return;
    pausedByPeer = v;
    if (v) {
      _samples.clear();
      _clock.stop();
    } else {
      if (!paused && isActive) _clock.start();
      _lastProgressMs = _clock.elapsedMilliseconds;
    }
    notifyListeners();
  }

  bool get isActive => state == JobState.waiting || state == JobState.running;
  double get progress => totalBytes == 0 ? 1 : bytesDone / totalBytes;
  Duration get elapsed => _clock.elapsed;

  /// Measured speed over the last ~2 seconds, in bytes per second.
  /// Null until enough real data has been measured.
  double? get currentSpeed {
    if (paused || pausedByPeer) return null;
    if (_samples.length < 2) return null;
    final first = _samples.first;
    final last = _samples.last;
    final ms = last.$1 - first.$1;
    if (ms < 300) return null;
    return (last.$2 - first.$2) * 1000 / ms;
  }

  /// Measured average speed for the whole transfer so far.
  double? get averageSpeed {
    final ms = _clock.elapsedMilliseconds;
    if (ms < 300 || bytesDone == 0) return null;
    return bytesDone * 1000 / ms;
  }

  Duration? get timeLeft {
    if (paused || pausedByPeer) return null;
    final s = currentSpeed ?? averageSpeed;
    if (s == null || s <= 0 || state != JobState.running) return null;
    return Duration(seconds: ((totalBytes - bytesDone) / s).ceil());
  }

  void start() {
    queued = false;
    state = JobState.running;
    _clock.start();
    notifyListeners();
  }

  void addBytes(int n) {
    bytesDone += n;
    final now = _clock.elapsedMilliseconds;
    _lastProgressMs = now;
    _samples.add((now, bytesDone));
    while (_samples.length > 2 && now - _samples.first.$1 > 2000) {
      _samples.removeAt(0);
    }
    final t = DateTime.now();
    if (t.difference(_lastNotify).inMilliseconds >= 150) {
      _lastNotify = t;
      notifyListeners();
    }
  }

  void finish(JobState s, [String? msg]) {
    if (!isActive) return;
    _clock.stop();
    paused = false;
    _resume?.complete();
    _resume = null;
    queued = false;
    state = s;
    message = msg;
    notifyListeners();
  }

  void cancel() {
    if (!isActive) return;
    cancelRequested = true;
    onCancel?.call();
    finish(JobState.cancelled, 'Cancelled');
  }
}

enum RequestKind { pairing, transfer }

/// Something the user must approve or decline on THIS device.
class PendingRequest {
  PendingRequest({
    required this.id,
    required this.kind,
    required this.peerName,
    required this.peerPlatform,
    this.code,
    this.fileNames = const [],
    this.totalBytes = 0,
    this.job,
  });

  final String id;
  final RequestKind kind;
  final String peerName;
  final String peerPlatform;
  final String? code;
  final List<String> fileNames;
  final int totalBytes;
  TransferJob? job;
  final Completer<bool> _decision = Completer<bool>();

  Future<bool> get decision => _decision.future;
  bool get decided => _decision.isCompleted;

  void approve() {
    if (!decided) _decision.complete(true);
  }

  void decline() {
    if (!decided) _decision.complete(false);
  }
}
