import 'dart:io';

/// One IPv4 address of THIS device on a local network.
class LocalNet {
  const LocalNet({
    required this.name,
    required this.ip,
    this.prefix,
    this.isWifi = false,
  });

  /// Interface name, e.g. "wlan0", "ap0", "Wi-Fi", "en0".
  final String name;
  final String ip;

  /// Network prefix length when the system told us (Android native);
  /// null when unknown (Dart's NetworkInterface does not report it).
  final int? prefix;

  /// True when the system says this is Wi-Fi (Android native).
  final bool isWifi;

  /// Subnet broadcast address: exact with [prefix], otherwise a /24 guess
  /// for private ranges (home routers and phone hotspots), else null.
  String? get broadcast {
    final p = prefix ?? (isPrivateIPv4(ip) ? 24 : null);
    if (p == null) return null;
    return subnetBroadcast(ip, p);
  }

  @override
  String toString() => '$name $ip${prefix == null ? '' : '/$prefix'}';
}

List<int>? _octets(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) return null;
  final o = parts.map(int.tryParse).toList();
  if (o.any((x) => x == null || x < 0 || x > 255)) return null;
  return o.cast<int>();
}

/// 10/8, 172.16/12 and 192.168/16.
bool isPrivateIPv4(String ip) {
  final o = _octets(ip);
  if (o == null) return false;
  return o[0] == 10 ||
      (o[0] == 172 && o[1] >= 16 && o[1] <= 31) ||
      (o[0] == 192 && o[1] == 168);
}

/// Broadcast address of [ip]/[prefix] (1..30), else null.
String? subnetBroadcast(String ip, int prefix) {
  final o = _octets(ip);
  if (o == null || prefix < 1 || prefix > 30) return null;
  final v = (o[0] << 24) | (o[1] << 16) | (o[2] << 8) | o[3];
  final mask = (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
  final b = (v & mask) | (~mask & 0xFFFFFFFF);
  return '${(b >> 24) & 255}.${(b >> 16) & 255}.${(b >> 8) & 255}.${b & 255}';
}

// Mobile data, VPNs, tunnels and virtual adapters: other devices on the same
// Wi-Fi/hotspot can never reach us there.
final _excludedName = RegExp(
  r'^(rmnet|ccmni|pdp|tun|ppp|wg|utun|ipsec|clat|v4-|dummy|docker|veth|'
  r'virbr|vmnet|vboxnet|llw|awdl|gif|stf|ham)|'
  r'vethernet|vpn|tap-|tap\d|wireguard|tailscale|zerotier|virtualbox|'
  r'vmware|hyper-v|loopback|bluetooth',
  caseSensitive: false,
);
final _wifiName = RegExp(
  r'^(wlan|ap\d|swlan|softap|wl|wifi|wi-fi|wigig)|wireless|wi-fi|wlan',
  caseSensitive: false,
);
final _wiredName = RegExp(
  r'^(en\d|eth|ethernet|enp|eno|ens|bridge|br\d)',
  caseSensitive: false,
);

/// How useful [ip] on interface [name] is for another device on the same
/// local network: < 0 means "do not offer it" (mobile data, VPN, link-local,
/// carrier-grade NAT, loopback); higher is better.
int addressScore(String name, String ip) {
  final o = _octets(ip);
  if (o == null) return -1;
  if (o[0] == 127 || o[0] == 0) return -1; // loopback / invalid
  if (o[0] == 169 && o[1] == 254) return -1; // link-local
  if (o[0] == 100 && o[1] >= 64 && o[1] <= 127) return -1; // CGNAT/Tailscale
  if (o[0] >= 224) return -1; // multicast / reserved
  if (_excludedName.hasMatch(name)) return -1;
  var score = 100;
  if (_wifiName.hasMatch(name)) {
    score = 300;
  } else if (_wiredName.hasMatch(name)) {
    score = 200;
  }
  if (isPrivateIPv4(ip)) score += 50;
  return score;
}

/// Best-first list of addresses to offer (QR code, "My addresses"). Excluded
/// ones are dropped; if that leaves nothing, all non-loopback ones are kept
/// (better a maybe-wrong address than none). Stable for equal scores.
List<LocalNet> rankLocalNets(Iterable<LocalNet> nets) {
  final all = nets.where((n) => !n.ip.startsWith('127.')).toList();
  final seen = <String>{};
  final unique = [
    for (final n in all)
      if (seen.add(n.ip)) n,
  ];
  final scored = [
    for (var i = 0; i < unique.length; i++)
      (n: unique[i], s: addressScore(unique[i].name, unique[i].ip), i: i),
  ];
  final good = scored.where((x) => x.s >= 0).toList()
    ..sort((a, b) => a.s != b.s ? b.s.compareTo(a.s) : a.i.compareTo(b.i));
  if (good.isEmpty) return unique;
  return [for (final x in good) x.n];
}

/// IPv4 addresses from Dart's [NetworkInterface] (no prefix information).
Future<List<LocalNet>> dartLocalNets() async {
  try {
    final ifs = await NetworkInterface.list(type: InternetAddressType.IPv4);
    return [
      for (final i in ifs)
        for (final a in i.addresses)
          if (!a.isLoopback) LocalNet(name: i.name, ip: a.address),
    ];
  } catch (_) {
    return const [];
  }
}

/// Parses Android's `networkInfo` answer ({nets: [{name, ip, prefix, wifi}],
/// binding: String?}). Bad entries are skipped; junk gives an empty list.
({List<LocalNet> nets, String? binding}) parseNativeNets(Object? raw) {
  if (raw is! Map) return (nets: const <LocalNet>[], binding: null);
  final out = <LocalNet>[];
  final list = raw['nets'];
  if (list is List) {
    for (final m in list) {
      if (m is! Map) continue;
      final name = m['name'];
      final ip = m['ip'];
      final prefix = m['prefix'];
      if (name is! String || ip is! String) continue;
      if (InternetAddress.tryParse(ip)?.type != InternetAddressType.IPv4) {
        continue;
      }
      out.add(
        LocalNet(
          name: name,
          ip: ip,
          prefix: prefix is int && prefix > 0 && prefix <= 32 ? prefix : null,
          isWifi: m['wifi'] == true,
        ),
      );
    }
  }
  final b = raw['binding'];
  return (nets: out, binding: b is String ? b : null);
}
