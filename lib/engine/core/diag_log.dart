import 'dart:async';
import 'dart:io';

import 'lane.dart';

/// One problem seen by the engine, for Diagnostics. Never contains file
/// names, device names or the other device's address.
class DiagEntry {
  DiagEntry(this.at, this.kind, this.message);

  final DateTime at;

  /// Short machine-readable class, e.g. `tls_rejected_incoming`.
  final String kind;

  /// Plain words for the user.
  final String message;
}

/// Counters shown on the Diagnostics page (since the app started).
class DiagCounters {
  int discoverySent = 0;
  int discoveryReceived = 0;
  int discoverySendErrors = 0;
  int discoveryTargets = 0;

  /// Bonjour/NSD: advertising registered (null = unknown / not reported).
  bool? bonjourRegistered;
  int bonjourFound = 0;
  int bonjourResolved = 0;
  int bonjourErrors = 0;

  /// Last NSD error codes, e.g. "register_failed:0" (max 5).
  final List<String> bonjourErrorCodes = [];
  int incomingConnections = 0;
  int incomingTlsRejected = 0;

  /// Discovery UDP port could be opened (null = not started).
  bool? udpBound;

  /// Android only: result of acquiring the Wi-Fi multicast lock
  /// (null = not tried / not Android).
  bool? multicastLock;

  /// Android only: what the app did about Wi-Fi without internet
  /// (e.g. "bound to Wi-Fi"), null when nothing was needed or not Android.
  String? networkBinding;
}

/// The last [max] problems, newest first.
class DiagLog {
  DiagLog({this.max = 20});

  final int max;
  final List<DiagEntry> _entries = [];

  List<DiagEntry> get entries => List.unmodifiable(_entries);

  DiagEntry? get latest => _entries.isEmpty ? null : _entries.first;

  DiagEntry add(String kind, String message, {DateTime? at}) {
    final e = DiagEntry(at ?? DateTime.now(), kind, message);
    _entries.insert(0, e);
    if (_entries.length > max) _entries.removeRange(max, _entries.length);
    return e;
  }

  void clear() => _entries.clear();
}

/// Short class for an exception, for the log. Never includes addresses.
String classifyError(Object e) {
  if (e is TimeoutException) return 'timeout';
  if (e is LaneException) {
    return e.code == 'lane_timeout' ? 'timeout' : 'lane_closed';
  }
  if (e is HandshakeException) return 'tls_handshake_failed';
  if (e is TlsException) return 'tls_error';
  if (e is SocketException) {
    final code = e.osError?.errorCode;
    final msg = '${e.osError?.message ?? ''} ${e.message}'.toLowerCase();
    // Linux/Android errno, Windows WSA codes, macOS/iOS errno.
    if (code == 111 || code == 10061 || code == 61 || msg.contains('refused')) {
      return 'connect_refused';
    }
    if (code == 110 ||
        code == 10060 ||
        code == 60 ||
        msg.contains('timed out')) {
      return 'connect_timeout';
    }
    if (code == 101 ||
        code == 113 ||
        code == 10051 ||
        code == 10065 ||
        code == 51 ||
        code == 65 ||
        msg.contains('unreachable') ||
        msg.contains('no route')) {
      return 'network_unreachable';
    }
    if (code == 104 ||
        code == 32 ||
        code == 10054 ||
        code == 54 ||
        msg.contains('reset') ||
        msg.contains('broken pipe')) {
      return 'connection_reset';
    }
    if (msg.contains('connection closed')) return 'connection_closed';
    if (code == 13 ||
        code == 1 ||
        code == 10013 ||
        msg.contains('permission denied')) {
      return 'permission_denied';
    }
    return 'socket_error';
  }
  if (e is FileSystemException) {
    final code = e.osError?.errorCode;
    if (code == 28 || code == 112) return 'disk_full';
    return 'storage_error';
  }
  return e.runtimeType.toString();
}

/// Words for [classifyError] classes.
String explainErrorClass(String kind) => switch (kind) {
  'timeout' => 'No answer in time.',
  'tls_handshake_failed' => 'The secure connection could not be set up.',
  'tls_error' => 'Secure connection error.',
  'connect_refused' =>
    'Connection refused: the app is not open there, or the port is wrong.',
  'connect_timeout' => 'No answer: the address is wrong, a firewall blocks it, or the devices are on different networks.',
  'network_unreachable' => 'Network unreachable: this device has no route to that address (wrong network, or traffic goes over mobile data).',
  'connection_reset' => 'The other device closed the connection.',
  'permission_denied' => 'The system blocked the connection.',
  'connection_closed' => 'The other device closed the connection.',
  'disk_full' => 'The storage is full.',
  'storage_error' => 'Storage error (no permission, or the file is gone).',
  'lane_closed' => 'The background data connection closed (the other device stopped, or the network dropped).',
  _ => 'Connection error.',
};
