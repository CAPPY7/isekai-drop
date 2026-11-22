import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'diag_log.dart';
import 'names.dart';
import 'net_info.dart';

/// What another device says about itself on the local network. This is NOT
/// trusted: the real identity is checked inside TLS when connecting.
class Announcement {
  Announcement({
    required this.deviceId,
    required this.name,
    required this.platform,
    required this.port,
    required this.fingerprint,
    required this.host,
    required this.seenAt,
  });

  final String deviceId;
  final String name;
  final String platform;
  final int port;
  final String fingerprint;
  final String host;
  final DateTime seenAt;
}

/// Local discovery: small UDP announcements every 3 seconds to a multicast
/// group and the local broadcast address. Contains no file data.
///
/// Phase 7d: also sends from EACH local network (Wi-Fi, hotspot, Ethernet)
/// to its subnet broadcast address and joins the multicast group on each,
/// so a phone with mobile data on, or a PC with several adapters, is still
/// found on the Wi-Fi/hotspot.
class Discovery {
  Discovery({
    required this.ownDeviceId,
    required this.onFound,
    this.shouldAnnounce,
    DiagCounters? counters,
    this.interfaces,
  }) : counters = counters ?? DiagCounters();

  /// THIS device's useful local networks (best first); null = only the
  /// default route is used.
  final Future<List<LocalNet>> Function()? interfaces;

  /// How often the network list is re-read (hotspot turned on, Wi-Fi joined).
  static const int refreshEveryTicks = 10;

  /// Sent/received/error counts for Diagnostics.
  final DiagCounters counters;

  /// Settings "Visible to nearby devices". When false we still listen.
  final bool Function()? shouldAnnounce;

  static final InternetAddress group = InternetAddress('239.255.42.99');
  static const int udpPort = 47821;

  final String ownDeviceId;
  final void Function(Announcement) onFound;

  RawDatagramSocket? _socket;
  Timer? _timer;
  int _tick = 0;
  bool _refreshing = false;

  /// One send socket per local address, with that network's targets.
  final Map<String, ({RawDatagramSocket socket, List<InternetAddress> to})>
  _perNet = {};
  final Set<String> _joined = {};

  /// Tests: where announcements currently go, as "source -> target".
  List<String> get debugTargets => [
    for (final e in _perNet.entries)
      for (final t in e.value.to) '${e.key} -> ${t.address}',
  ];
  Map<String, Object?> Function()? _payload;
  String? error;

  Future<void> start(Map<String, Object?> Function() payload) async {
    _payload = payload;
    try {
      final s = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        udpPort,
        reuseAddress: true,
      );
      _socket = s;
      counters.udpBound = true;
      s.broadcastEnabled = true;
      try {
        s.joinMulticast(group);
      } catch (_) {
        // Some networks/OSes refuse multicast; broadcast still works.
      }
      await refreshInterfaces();
      s.listen((event) {
        if (event != RawSocketEvent.read) return;
        final d = s.receive();
        if (d == null || d.data.length > 2048) return;
        try {
          final j = jsonDecode(utf8.decode(d.data)) as Map<String, dynamic>;
          if (j['app'] != 'isekai-drop' || j['v'] != 1) return;
          if (j['device_id'] == ownDeviceId) return;
          counters.discoveryReceived++;
          // A2: every field is checked; anything odd drops the packet.
          final a = parseAnnouncement(j, d.address.address);
          if (a == null) {
            counters.discoveryDropped++;
            return;
          }
          onFound(a);
          _replyTo(d.address);
        } catch (_) {
          // Ignore malformed packets.
          counters.discoveryDropped++;
        }
      });
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (++_tick % refreshEveryTicks == 0) unawaited(refreshInterfaces());
        announce();
      });
      announce();
    } catch (e) {
      counters.udpBound = false;
      error = 'Discovery unavailable on this network';
    }
  }

  final Map<String, DateTime> _replied = {};

  /// Answers an announcement directly (unicast, max once per 10 s per
  /// address). Then a device whose own broadcasts are lost (some phone
  /// hotspots, some routers) still learns about us. Phase 9.
  void _replyTo(InternetAddress to) {
    final s = _socket;
    final p = _payload;
    if (s == null || p == null) return;
    if (shouldAnnounce != null && !shouldAnnounce!()) return;
    final now = DateTime.now();
    final last = _replied[to.address];
    if (last != null && now.difference(last).inSeconds < 10) return;
    if (_replied.length > 256) _replied.clear();
    _replied[to.address] = now;
    final bytes = utf8.encode(
      jsonEncode({'app': 'isekai-drop', 'v': 1, ...p()}),
    );
    _sendAll(s, [to], bytes);
  }

  void announce() {
    final s = _socket;
    final p = _payload;
    if (s == null || p == null) return;
    if (shouldAnnounce != null && !shouldAnnounce!()) return;
    final bytes = utf8.encode(
      jsonEncode({'app': 'isekai-drop', 'v': 1, ...p()}),
    );
    _sendAll(s, [group, InternetAddress('255.255.255.255')], bytes);
    for (final n in _perNet.values) {
      _sendAll(n.socket, n.to, bytes);
    }
  }

  void _sendAll(
    RawDatagramSocket s,
    List<InternetAddress> targets,
    List<int> bytes,
  ) {
    for (final target in targets) {
      try {
        // send() returns 0 when the OS refused it (e.g. no route).
        if (s.send(bytes, target, udpPort) > 0) {
          counters.discoverySent++;
        } else {
          counters.discoverySendErrors++;
        }
      } catch (_) {
        counters.discoverySendErrors++;
      }
    }
  }

  /// Re-reads the local networks: joins the group on each and keeps one
  /// send socket per address (bound to it, so the packet leaves on that
  /// network) aimed at the group, 255.255.255.255 and the subnet broadcast.
  Future<void> refreshInterfaces() async {
    final listen = _socket;
    final source = interfaces;
    if (listen == null || source == null || _refreshing) return;
    _refreshing = true;
    try {
      List<LocalNet> nets;
      try {
        nets = await source();
      } catch (_) {
        nets = const [];
      }
      List<NetworkInterface> sys = const [];
      try {
        sys = await NetworkInterface.list(type: InternetAddressType.IPv4);
      } catch (_) {}
      final want = {for (final n in nets) n.ip: n};
      for (final ip in _perNet.keys.toList()) {
        if (!want.containsKey(ip)) _perNet.remove(ip)?.socket.close();
      }
      for (final n in want.values) {
        // Multicast membership on the interface that has this address.
        for (final ni in sys) {
          if (!ni.addresses.any((a) => a.address == n.ip)) continue;
          if (_joined.add('${ni.name}/${n.ip}')) {
            try {
              listen.joinMulticast(group, ni);
            } catch (_) {
              // Already joined via the default interface, or refused.
            }
          }
        }
        if (_perNet.containsKey(n.ip) || _socket == null) continue;
        try {
          final sock = await RawDatagramSocket.bind(InternetAddress(n.ip), 0);
          sock.broadcastEnabled = true;
          sock.listen((_) => sock.receive()); // drop anything sent to it
          final to = <InternetAddress>[
            group,
            InternetAddress('255.255.255.255'),
          ];
          final b = n.broadcast;
          if (b != null && b != '255.255.255.255') to.add(InternetAddress(b));
          if (_socket == null) {
            sock.close();
            break;
          }
          _perNet[n.ip] = (socket: sock, to: to);
        } catch (_) {
          counters.discoverySendErrors++;
        }
      }
      counters.discoveryTargets = _perNet.values.fold(
        2,
        (a, n) => a + n.to.length,
      );
    } finally {
      _refreshing = false;
    }
  }

  void stop() {
    _timer?.cancel();
    _socket?.close();
    _socket = null;
    for (final n in _perNet.values) {
      n.socket.close();
    }
    _perNet.clear();
    _joined.clear();
  }
}

/// A2: most devices kept in the Nearby list. When full, new unknown ids
/// are ignored (a paired device is always shown).
const int kMaxNearby = 64;

/// A2: most NEW device ids taken from one source address per
/// [kNewIdsWindow].
const int kMaxNewIdsPerSource = 5;
const Duration kNewIdsWindow = Duration(seconds: 10);

final _safeId = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
final _fp = RegExp(r'^[0-9a-f]{64}$');

/// A2: true when the untrusted fields of an announcement look right:
/// device id 1-64 safe characters, fingerprint exactly 64 lower-case hex,
/// port 1-65535.
bool validAnnouncementFields(String deviceId, String fingerprint, int port) =>
    _safeId.hasMatch(deviceId) &&
    _fp.hasMatch(fingerprint) &&
    port >= 1 &&
    port <= 65535;

/// A2: builds an [Announcement] from a UDP packet, or null when any field
/// is missing or has the wrong type/format. Name and platform are cleaned
/// like pairing names (no control/bidi characters, max 40 runes).
Announcement? parseAnnouncement(
  Map<String, dynamic> j,
  String host, {
  DateTime? now,
}) {
  final id = j['device_id'];
  final fp = j['fp'];
  final port = j['port'];
  final name = j['name'];
  final platform = j['platform'];
  if (id is! String || fp is! String || port is! int) return null;
  if (name is! String || platform is! String) return null;
  if (!validAnnouncementFields(id, fp, port)) return null;
  return Announcement(
    deviceId: id,
    name: cleanDeviceName(name),
    platform: cleanDeviceName(platform),
    port: port,
    fingerprint: fp,
    host: host,
    seenAt: now ?? DateTime.now(),
  );
}
