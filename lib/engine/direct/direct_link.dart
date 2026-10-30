// 0.10.0 "Fast direct": a one-hop Wi-Fi link between two devices, without
// the Wi-Fi router in the middle. Pure Dart parts (models, QR codes, plain
// error texts, the host-side lifecycle). The platform part (Android) lives
// behind [DirectLinkPlatform].
//
// Security is unchanged: the Wi-Fi password only lets a device JOIN the
// link. Files still move over mutual TLS with the pinned device key.
import 'dart:async';
import 'dart:math';

/// How a direct link was made.
enum DirectKind {
  /// Android Wi-Fi Direct group (this phone is the group owner). Other
  /// Android phones join as Wi-Fi Direct clients; PCs and iPhones can join
  /// it like a normal Wi-Fi network.
  wifiDirect('wifi_direct', 'Wi-Fi Direct'),

  /// Android "local-only hotspot" (fallback). The phone picks the band.
  hotspot('hotspot', 'Phone hotspot (local only)'),

  /// Windows Mobile Hotspot, started on the PC.
  windowsHotspot('windows_hotspot', 'Windows Mobile Hotspot');

  const DirectKind(this.wire, this.label);
  final String wire;
  final String label;

  static DirectKind? fromWire(Object? s) {
    for (final k in values) {
      if (k.wire == s) return k;
    }
    return null;
  }
}

/// Which way the files actually went (shown on the transfer card).
enum LinkRoute {
  router('Wi-Fi router'),
  wifiDirect('Fast direct (Wi-Fi Direct)'),
  hotspot('Fast direct (hotspot link)');

  const LinkRoute(this.label);
  final String label;

  static LinkRoute forKind(DirectKind k) =>
      k == DirectKind.wifiDirect ? LinkRoute.wifiDirect : LinkRoute.hotspot;
}

/// A running (or announced) direct link.
class DirectLinkInfo {
  const DirectLinkInfo({
    required this.kind,
    required this.ssid,
    required this.passphrase,
    required this.hostIp,
    this.frequencyMhz,
    this.note,
  });

  final DirectKind kind;
  final String ssid;
  final String passphrase;

  /// IPv4 address of the hosting device on the link (Wi-Fi Direct group
  /// owner: normally 192.168.49.1).
  final String hostIp;

  /// Channel frequency if the system tells us (Android 10+ Wi-Fi Direct).
  final int? frequencyMhz;

  /// Plain-language detail, e.g. "5 GHz was not available; 2.4 GHz used".
  final String? note;

  String get bandLabel => bandLabelFor(frequencyMhz);

  Map<String, Object?> toJson() => {
    'kind': kind.wire,
    'ssid': ssid,
    'pass': passphrase,
    'host': hostIp,
    if (frequencyMhz != null) 'mhz': frequencyMhz,
    if (note != null) 'note': note,
  };

  /// Validates everything (this comes from the network or a QR code).
  static DirectLinkInfo? tryFromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = DirectKind.fromWire(raw['kind']);
    final ssid = raw['ssid'];
    final pass = raw['pass'];
    final host = raw['host'];
    if (kind == null || ssid is! String || pass is! String || host is! String) {
      return null;
    }
    if (!isValidSsid(ssid) || !isValidPassphrase(pass) || !isIpv4(host)) {
      return null;
    }
    final mhz = raw['mhz'];
    final note = raw['note'];
    return DirectLinkInfo(
      kind: kind,
      ssid: ssid,
      passphrase: pass,
      hostIp: host,
      frequencyMhz: mhz is int && mhz > 0 && mhz < 100000 ? mhz : null,
      note: note is String ? _clean(note, 200) : null,
    );
  }
}

String _clean(String s, int max) {
  final t = s.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
  return t.length > max ? t.substring(0, max) : t;
}

bool isValidSsid(String s) =>
    s.isNotEmpty &&
    s.codeUnits.length <= 32 &&
    !RegExp(r'[\x00-\x1F\x7F]').hasMatch(s);

/// WPA2 passphrase: 8..63 printable ASCII characters.
bool isValidPassphrase(String s) =>
    s.length >= 8 && s.length <= 63 && RegExp(r'^[\x20-\x7E]+$').hasMatch(s);

bool isIpv4(String s) {
  final m = RegExp(r'^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$')
      .firstMatch(s);
  if (m == null) return false;
  for (var i = 1; i <= 4; i++) {
    if (int.parse(m.group(i)!) > 255) return false;
  }
  return true;
}

/// "5 GHz (5180 MHz)", "2.4 GHz (2437 MHz)" or "band unknown".
String bandLabelFor(int? mhz) {
  if (mhz == null || mhz <= 0) return 'band unknown';
  if (mhz >= 2400 && mhz < 2500) return '2.4 GHz ($mhz MHz)';
  if (mhz >= 4900 && mhz < 5900) return '5 GHz ($mhz MHz)';
  if (mhz >= 5925 && mhz < 7200) return '6 GHz ($mhz MHz)';
  return '$mhz MHz';
}

/// Easy-to-type random password (no 0/O/1/l/I).
String randomPassphrase([Random? r, int length = 10]) {
  const abc = 'abcdefghijkmnpqrstuvwxyz23456789';
  final rnd = r ?? Random.secure();
  return List.generate(length, (_) => abc[rnd.nextInt(abc.length)]).join();
}

/// Wi-Fi Direct network names must start with "DIRECT-" and two characters.
String randomDirectSsid([Random? r]) {
  const abc = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final rnd = r ?? Random.secure();
  final xy = List.generate(2, (_) => abc[rnd.nextInt(abc.length)]).join();
  return 'DIRECT-$xy-IsekaiDrop';
}

// ---------------------------------------------------------------------------
// QR codes

/// Escapes a value for the standard Wi-Fi QR format (\ ; , : " are escaped).
String escapeWifiQr(String s) =>
    s.replaceAllMapped(RegExp(r'[\\;,:"]'), (m) => '\\${m[0]}');

/// Standard Wi-Fi QR code ("WIFI:S:..;T:WPA;P:..;;"). The iPhone camera,
/// Android camera / Wi-Fi settings and most QR apps can join from it.
String wifiQrString(String ssid, String passphrase) =>
    'WIFI:S:${escapeWifiQr(ssid)};T:WPA;P:${escapeWifiQr(passphrase)};;';

/// Parses a standard Wi-Fi QR code. Returns (ssid, passphrase) or null.
(String, String)? parseWifiQr(String raw) {
  final t = raw.trim();
  if (!t.toUpperCase().startsWith('WIFI:')) return null;
  final fields = <String, String>{};
  var i = 5;
  while (i < t.length) {
    final colon = t.indexOf(':', i);
    if (colon < 0) break;
    final key = t.substring(i, colon).toUpperCase();
    final sb = StringBuffer();
    var j = colon + 1;
    while (j < t.length && t[j] != ';') {
      if (t[j] == '\\' && j + 1 < t.length) {
        sb.write(t[j + 1]);
        j += 2;
      } else {
        sb.write(t[j]);
        j++;
      }
    }
    if (key.isNotEmpty) fields[key] = sb.toString();
    i = j + 1;
    if (i < t.length && t[i] == ';') break; // ";;" end
  }
  final ssid = fields['S'];
  final pass = fields['P'] ?? '';
  final type = (fields['T'] ?? 'WPA').toUpperCase();
  if (ssid == null || !isValidSsid(ssid)) return null;
  if (type == 'NOPASS') return (ssid, '');
  if (!isValidPassphrase(pass)) return null;
  return (ssid, pass);
}

/// The app's own "Fast direct" QR: link + who is at the other end, so one
/// scan joins the link AND pairs with the exact device key.
class DirectQr {
  DirectQr({
    required this.link,
    required this.port,
    required this.fingerprint,
    required this.name,
  });

  final DirectLinkInfo link;
  final int port;
  final String fingerprint;
  final String name;

  String encode() => Uri(
    scheme: 'isekaidrop',
    path: 'direct',
    queryParameters: {
      'v': '1',
      'k': link.kind.wire,
      's': link.ssid,
      'w': link.passphrase,
      'h': link.hostIp,
      'p': '$port',
      'f': fingerprint,
      'n': name,
      if (link.frequencyMhz != null) 'm': '${link.frequencyMhz}',
    },
  ).toString();

  static DirectQr? tryParse(String raw) {
    final Uri u;
    try {
      u = Uri.parse(raw.trim());
    } catch (_) {
      return null;
    }
    if (u.scheme != 'isekaidrop' || u.path != 'direct') return null;
    final q = u.queryParameters;
    if (q['v'] != '1') return null;
    final link = DirectLinkInfo.tryFromJson({
      'kind': q['k'],
      'ssid': q['s'],
      'pass': q['w'],
      'host': q['h'],
      if (int.tryParse(q['m'] ?? '') != null) 'mhz': int.parse(q['m']!),
    });
    final port = int.tryParse(q['p'] ?? '');
    final fp = (q['f'] ?? '').toLowerCase();
    if (link == null || port == null || port < 1 || port > 65535) return null;
    if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(fp)) return null;
    return DirectQr(
      link: link,
      port: port,
      fingerprint: fp,
      name: _clean(q['n'] ?? 'Device', 40),
    );
  }
}

// ---------------------------------------------------------------------------
// Errors in plain language

class DirectLinkException implements Exception {
  const DirectLinkException(this.code, [this.detail]);

  /// Short machine code, e.g. "no_permission" (used in Diagnostics).
  final String code;
  final String? detail;

  String get message => explainDirectError(code);

  @override
  String toString() => 'DirectLinkException($code)';
}

String explainDirectError(String code) => switch (code) {
  'no_permission' =>
    'Isekai Drop is not allowed to use "Nearby devices" (Android 13+) or '
        'Location (Android 12 and older). Android needs it to make a direct '
        'Wi-Fi link. Isekai Drop does not use your location.',
  'location_off' =>
    'Location is turned off. Android 12 and older need Location ON to make '
        'a direct Wi-Fi link (your location is not used).',
  'wifi_off' => 'Wi-Fi is turned off. Turn Wi-Fi on (no network needed).',
  'unsupported' => 'This device cannot make a direct Wi-Fi link.',
  'old_android' => 'Fast direct needs Android 10 or newer.',
  'busy' =>
    'Wi-Fi Direct is busy (another app, a Wi-Fi Direct printer/TV, or the '
        'phone\'s own hotspot may be using it). Turn the phone hotspot off and try again.',
  'incompatible_mode' =>
    'The phone\'s normal hotspot or another Wi-Fi mode is on. Turn the '
        'phone hotspot off and try again.',
  'tethering_disallowed' =>
    'Hotspots are blocked on this phone (work profile or carrier setting).',
  'no_channel' => 'No free Wi-Fi channel right now. Try again in a moment.',
  'timeout' => 'The direct link did not come up in time.',
  'declined' => 'Joining the direct link was not approved on this device.',
  'no_address' => 'The direct link came up but got no network address in time.',
  'stopped' => 'The direct link was stopped by the system.',
  'connect_failed' =>
    'Joined the direct link but could not reach the other device on it.',
  'not_android' => 'The other device cannot make a direct Wi-Fi link.',
  'off' => 'Fast direct is turned off in Settings.',
  'small' => 'Not worth it for small files.',
  'peer_no_permission' =>
    'The other phone has not allowed "Nearby devices"/Location for Isekai '
        'Drop yet. Open Isekai Drop on it: Settings > Fast direct.',
  'peer_off' => 'Fast direct is turned off on the other device.',
  'peer_busy' => 'The other phone could not make a direct link right now.',
  'peer_old' =>
    'The other device runs an older Isekai Drop without Fast direct.',
  _ => 'The direct link could not be made ($code).',
};

// ---------------------------------------------------------------------------
// Platform interface (Android implements it; tests fake it)

/// Result of joining a direct link.
class DirectJoin {
  const DirectJoin({
    this.localIp,
    this.frequencyMhz,
    this.linkMbps,
    this.txMbps,
    this.rxMbps,
  });
  final String? localIp;
  final int? frequencyMhz;
  final int? linkMbps;

  /// 0.10.1: send/receive link speed of the joined link (Android 10+), if
  /// the system reports it.
  final int? txMbps;
  final int? rxMbps;
}

abstract class DirectLinkPlatform {
  /// True if this device can host a link (Android 8+ with Wi-Fi).
  bool get canHost;

  /// True if this device can join a link by itself (Android 10+).
  bool get canJoin;

  /// "granted", "denied", "location_off", "wifi_off" or "unsupported".
  Future<String> permissionState();

  /// Shows the system permission prompt. Returns the new state.
  Future<String> requestPermission();

  /// Starts a link. Throws [DirectLinkException].
  Future<DirectLinkInfo> host({bool preferFiveGhz = true});

  Future<void> stopHost();

  /// Joins [link]. Throws [DirectLinkException].
  Future<DirectJoin> join(DirectLinkInfo link, {Duration timeout});

  Future<void> leave();

  /// "host_stopped" / "join_lost" events from the system.
  Stream<String> get events;
}

// ---------------------------------------------------------------------------
// Host lifecycle

/// Owns the hosted link on the receiving side: started on demand, shared by
/// all users (ref count), stopped [idle] after the last user is gone, and
/// always stopped on [dispose]. This is the fix for the fragile 0.8 hotspot
/// (that one stayed on until the user stopped it by hand).
class DirectHostManager {
  DirectHostManager(
    this.platform, {
    this.idle = const Duration(seconds: 30),
    this.startTimeout = const Duration(seconds: 25),
    this.onChange,
  }) {
    _events = platform.events.listen((e) {
      if (e == 'host_stopped' && _current != null) {
        _current = null;
        _users = 0;
        _idleTimer?.cancel();
        lastError = 'stopped';
        onChange?.call();
      }
    });
  }

  final DirectLinkPlatform platform;
  final Duration idle;
  final Duration startTimeout;
  final void Function()? onChange;
  StreamSubscription<String>? _events;

  DirectLinkInfo? _current;
  Future<DirectLinkInfo>? _starting;
  int _users = 0;
  Timer? _idleTimer;
  String? lastError;

  /// Set while the user keeps the link open from the "Fast direct" screen.
  bool pinned = false;

  DirectLinkInfo? get current => _current;
  int get users => _users;
  bool get active => _current != null;

  /// Starts the link if needed and counts one more user.
  Future<DirectLinkInfo> acquire() async {
    _idleTimer?.cancel();
    final have = _current;
    if (have != null) {
      _users++;
      return have;
    }
    final f = _starting ??= _start();
    try {
      final info = await f;
      _users++;
      return info;
    } finally {
      _starting = null;
    }
  }

  Future<DirectLinkInfo> _start() async {
    try {
      final info = await platform
          .host(preferFiveGhz: true)
          .timeout(
            startTimeout,
            onTimeout: () => throw const DirectLinkException('timeout'),
          );
      _current = info;
      lastError = null;
      onChange?.call();
      return info;
    } on DirectLinkException catch (e) {
      lastError = e.code;
      // A half-made link must not stay on.
      try {
        await platform.stopHost();
      } catch (_) {}
      rethrow;
    } catch (e) {
      lastError = 'failed';
      try {
        await platform.stopHost();
      } catch (_) {}
      throw const DirectLinkException('failed');
    }
  }

  /// Counts one more user of a link that is ALREADY on (an incoming
  /// transfer over it). Returns false if no link is on.
  bool hold() {
    if (_current == null) return false;
    _idleTimer?.cancel();
    _users++;
    return true;
  }

  /// One user is done. The link stops after [idle] without users.
  void release() {
    if (_users > 0) _users--;
    _armIdle();
  }

  void _armIdle() {
    _idleTimer?.cancel();
    if (_users > 0 || pinned || _current == null) return;
    _idleTimer = Timer(idle, () => unawaited(stop()));
  }

  /// Keep the link on (screen open) or let it idle out.
  void setPinned(bool v) {
    pinned = v;
    if (v) {
      _idleTimer?.cancel();
    } else {
      _armIdle();
    }
  }

  bool isLinkAddress(String localIp) => _current?.hostIp == localIp;

  Future<void> stop() async {
    _idleTimer?.cancel();
    _users = 0;
    pinned = false;
    final had = _current != null;
    _current = null;
    try {
      await platform.stopHost();
    } catch (_) {}
    if (had) onChange?.call();
  }

  Future<void> dispose() async {
    await _events?.cancel();
    await stop();
  }
}

// ---------------------------------------------------------------------------
// When to try

/// Fast direct is only tried where it can win: a big enough transfer to an
/// Android phone, from a device that can join by itself.
const int kDirectMinBytes = 64 * 1024 * 1024;

/// Returns null to try a direct link, or the reason code not to.
String? directSkipReason({
  required bool enabled,
  required bool canJoin,
  required String peerPlatform,
  required int totalBytes,
  int minBytes = kDirectMinBytes,
}) {
  if (!enabled) return 'off';
  if (!canJoin) return 'unsupported';
  if (peerPlatform != 'android') return 'not_android';
  if (totalBytes < minBytes) return 'small';
  return null;
}
