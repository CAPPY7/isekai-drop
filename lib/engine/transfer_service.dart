// D2 (0.12.0): keeps the Android foreground service (TransferService.kt) in
// step with the engine. The service runs while a transfer is active or a
// request waits for an answer, so Android does not stop the app in the
// background. The notification gets counts and MEASURED bytes only: no
// file names, no device names (it can show on the lock screen).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'core/error_note.dart';
import 'core/jobs.dart';

const MethodChannel kServiceChannel = MethodChannel('isekai_drop/service');

class TransferServiceBridge {
  TransferServiceBridge({
    required this.listenable,
    required this.jobs,
    required this.pending,
    this.channel = kServiceChannel,
    DateTime Function()? now,
    this.tick = const Duration(seconds: 1),
  }) : now = now ?? DateTime.now;

  final Listenable listenable;
  final List<TransferJob> Function() jobs;
  final List<PendingRequest> Function() pending;
  final MethodChannel channel;
  final DateTime Function() now;

  /// How often progress is refreshed while active (null: only on engine
  /// changes; tests call [sync]).
  final Duration? tick;

  Map<String, int>? _last;
  DateTime? _lastAt;
  Timer? _timer;

  void attach() {
    listenable.addListener(_onChange);
    channel.setMethodCallHandler(_onNative);
  }

  void detach() {
    listenable.removeListener(_onChange);
    channel.setMethodCallHandler(null);
    _timer?.cancel();
    _timer = null;
  }

  void _onChange() => unawaited(sync());

  Future<Object?> _onNative(MethodCall call) async {
    if (call.method == 'cancel') {
      // "Cancel" in the notification: every running or waiting transfer.
      for (final j in List.of(jobs())) {
        if (j.isActive) j.cancel();
      }
      await sync();
    }
    return null;
  }

  Map<String, int> _status() {
    var sending = 0, receiving = 0, done = 0, total = 0;
    for (final j in jobs()) {
      if (!j.isActive) continue;
      j.direction == JobDirection.sending ? sending++ : receiving++;
      done += j.bytesDone;
      total += j.totalBytes;
    }
    final requests = pending().where((r) => !r.decided).length;
    return {
      'sending': sending,
      'receiving': receiving,
      'requests': requests,
      'done': done,
      'total': total,
    };
  }

  static bool _sameShape(Map<String, int> a, Map<String, int> b) =>
      a['sending'] == b['sending'] &&
      a['receiving'] == b['receiving'] &&
      a['requests'] == b['requests'] &&
      a['total'] == b['total'];

  /// Starts, updates or stops the service. Progress-only changes are sent
  /// at most once per second.
  Future<void> sync() async {
    final s = _status();
    final active = s['sending']! + s['receiving']! + s['requests']! > 0;
    final last = _last;
    if (!active) {
      _timer?.cancel();
      _timer = null;
      if (last == null) return;
      _last = null;
      await _call('stop');
      return;
    }
    final t = now();
    if (last != null) {
      if (mapEquals(last, s)) return;
      if (_sameShape(last, s) &&
          _lastAt != null &&
          t.difference(_lastAt!) < const Duration(seconds: 1)) {
        return;
      }
    }
    _last = s;
    _lastAt = t;
    final every = tick;
    if (every != null && _timer == null) {
      _timer = Timer.periodic(every, (_) => unawaited(sync()));
    }
    await _call('update', s);
  }

  Future<void> _call(String method, [Object? args]) async {
    try {
      await channel.invokeMethod<Object?>(method, args);
    } catch (e) {
      noteError('service_$method', e);
    }
  }
}
