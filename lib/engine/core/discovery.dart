import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'diag_log.dart';
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
          onFound(
            Announcement(
              deviceId: j['device_id'] as String,
              name: (j['name'] as String).characters40,
              platform: j['platform'] as String,
              port: j['port'] as int,
              fingerprint: j['fp'] as String,
              host: d.address.address,
              seenAt: DateTime.now(),
            ),
          );
        } catch (_) {
          // Ignore malformed packets.
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

extension on String {
  String get characters40 => length > 40 ? substring(0, 40) : this;
}
