/// What a pairing QR code contains. Not secret: addresses, port, the
/// device's public key fingerprint and its name. Scanning it lets the
/// scanner check the other device's key exactly (no typing).
class PairingQr {
  PairingQr({
    required this.hosts,
    required this.port,
    required this.fingerprint,
    required this.name,
  });

  final List<String> hosts;
  final int port;
  final String fingerprint;
  final String name;

  static const scheme = 'isekaidrop';

  String encode() => Uri(
    scheme: scheme,
    path: 'pair',
    queryParameters: {
      'v': '1',
      'h': hosts.join(','),
      'p': '$port',
      'f': fingerprint,
      'n': name,
    },
  ).toString();

  /// Returns null for anything that is not a valid Isekai Drop pairing code.
  static PairingQr? tryParse(String raw) {
    final Uri u;
    try {
      u = Uri.parse(raw.trim());
    } catch (_) {
      return null;
    }
    if (u.scheme != scheme || u.path != 'pair') return null;
    final q = u.queryParameters;
    if (q['v'] != '1') return null;
    final port = int.tryParse(q['p'] ?? '');
    final fp = (q['f'] ?? '').toLowerCase();
    if (port == null || port < 1 || port > 65535) return null;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(fp)) return null;
    final hosts = (q['h'] ?? '')
        .split(',')
        .map((h) => h.trim())
        .where((h) => RegExp(r'^[0-9a-fA-F:.]{2,45}$').hasMatch(h))
        .take(8)
        .toList();
    if (hosts.isEmpty) return null;
    var name = (q['n'] ?? 'Device').replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    if (name.length > 40) name = name.substring(0, 40);
    return PairingQr(hosts: hosts, port: port, fingerprint: fp, name: name);
  }
}
