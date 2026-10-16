import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
class Discovery {
  Discovery({required this.ownDeviceId, required this.onFound});

  static final InternetAddress group = InternetAddress('239.255.42.99');
  static const int udpPort = 47821;

  final String ownDeviceId;
  final void Function(Announcement) onFound;

  RawDatagramSocket? _socket;
  Timer? _timer;
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
      s.broadcastEnabled = true;
      try {
        s.joinMulticast(group);
      } catch (_) {
        // Some networks/OSes refuse multicast; broadcast still works.
      }
      s.listen((event) {
        if (event != RawSocketEvent.read) return;
        final d = s.receive();
        if (d == null || d.data.length > 2048) return;
        try {
          final j = jsonDecode(utf8.decode(d.data)) as Map<String, dynamic>;
          if (j['app'] != 'isekai-drop' || j['v'] != 1) return;
          if (j['device_id'] == ownDeviceId) return;
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
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => announce());
      announce();
    } catch (e) {
      error = 'Discovery unavailable on this network';
    }
  }

  void announce() {
    final s = _socket;
    final p = _payload;
    if (s == null || p == null) return;
    final bytes = utf8.encode(
      jsonEncode({'app': 'isekai-drop', 'v': 1, ...p()}),
    );
    for (final target in [group, InternetAddress('255.255.255.255')]) {
      try {
        s.send(bytes, target, udpPort);
      } catch (_) {}
    }
  }

  void stop() {
    _timer?.cancel();
    _socket?.close();
    _socket = null;
  }
}

extension on String {
  String get characters40 => length > 40 ? substring(0, 40) : this;
}
