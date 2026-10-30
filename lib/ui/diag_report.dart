import '../engine/transfer_engine.dart';

/// App version shown in Diagnostics and the copied report. A test checks it
/// matches pubspec.yaml.
const kAppVersion = '0.10.3';

String _two(int v) => v.toString().padLeft(2, '0');

/// Local time as HH:MM:SS.
String diagTime(DateTime t) {
  final l = t.toLocal();
  return '${_two(l.hour)}:${_two(l.minute)}:${_two(l.second)}';
}

String _yesNo(bool? v) => v == null ? 'unknown' : (v ? 'yes' : 'NO');

/// "Connection checks" lines (also used in the copied report).
/// [ownAddresses] are THIS device's addresses ("wlan0 192.168.1.5"); the
/// owner agreed to show them (Phase 7d). Other devices' addresses and names
/// are never included.
List<String> diagCheckLines(
  TransferEngine e, {
  List<String> ownAddresses = const [],
  String? platformNote,
}) {
  final c = e.diagCounters;
  return [
    'This device\'s addresses: '
        '${ownAddresses.isEmpty ? 'none (not on a network?)' : ownAddresses.join(', ')}',
    'Receiving on port: ${e.listeningPort ?? 'not running'}',
    'Discovery port (UDP 47821) open: ${_yesNo(c.udpBound)}',
    'Discovery targets: ${c.discoveryTargets}',
    'Discovery packets sent: ${c.discoverySent}, send errors: '
        '${c.discoverySendErrors}, received from others: ${c.discoveryReceived}',
    if (c.multicastLock != null)
      'Wi-Fi multicast lock: ${c.multicastLock! ? 'held' : 'REFUSED'}',
    if (c.networkBinding != null) 'Network: ${c.networkBinding}',
    'Bonjour: registered ${_yesNo(c.bonjourRegistered)}, found '
        '${c.bonjourFound}, resolved ${c.bonjourResolved}, errors '
        '${c.bonjourErrors}'
        '${c.bonjourErrorCodes.isEmpty ? '' : ' (${c.bonjourErrorCodes.join(', ')})'}',
    'Incoming connections: ${c.incomingConnections}, refused by secure '
        'setup: ${c.incomingTlsRejected}',
    'Devices seen nearby now: ${e.nearby.length}',
    'Trusted devices: ${e.trustedDevices.where((d) => d.isTrusted).length}',
    ?platformNote,
  ];
}

/// Plain-text report for "Copy report". No file names, no device names,
/// no other device's address, no keys.
String buildDiagReport(
  TransferEngine e, {
  required String platform,
  List<String> ownAddresses = const [],
  String? connectionMethod,
  String? platformNote,
  DateTime? now,
}) {
  final b = StringBuffer()
    ..writeln('Isekai Drop diagnostics report')
    ..writeln('App $kAppVersion, ${e.version}, $platform')
    ..writeln('Time: ${(now ?? DateTime.now()).toUtc().toIso8601String()}');
  if (connectionMethod != null) b.writeln('Connection: $connectionMethod');
  if (e.startError != null) b.writeln('Start error: ${e.startError}');
  if (e.discoveryError != null) b.writeln('Discovery: ${e.discoveryError}');
  b.writeln();
  b.writeln('Checks:');
  for (final l in diagCheckLines(
    e,
    ownAddresses: ownAddresses,
    platformNote: platformNote,
  )) {
    b.writeln('- $l');
  }
  b.writeln();
  final log = e.diagLog.entries;
  b.writeln('Problems (newest first, ${log.length}):');
  if (log.isEmpty) b.writeln('- none since the app started');
  for (final d in log) {
    b.writeln('- ${diagTime(d.at)} [${d.kind}] ${d.message}');
  }
  return b.toString();
}
