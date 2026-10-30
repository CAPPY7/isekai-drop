// 0.11.0: Windows Wi-Fi link details for Diagnostics, the Speed test and
// the route chip. READ-ONLY: only `netsh wlan show interfaces`, `powercfg
// /query` and `Get-NetAdapterAdvancedProperty` are run; nothing is
// changed. Network names (SSID) and BSSIDs are never read into the result.
//
// The labels are the English ones; on a Windows set to another language
// the lines do not match and the values stay "not available".
import 'dart:io';

/// What `netsh wlan show interfaces` says about the connected Wi-Fi.
class WlanLink {
  const WlanLink({
    this.connected = false,
    this.radioType,
    this.band,
    this.channel,
    this.receiveMbps,
    this.transmitMbps,
    this.signalPercent,
    this.adapter,
  });

  final bool connected;

  /// e.g. "802.11ax".
  final String? radioType;

  /// e.g. "5 GHz" (Windows 11 prints it; else derived from the channel).
  final String? band;
  final int? channel;
  final int? receiveMbps;
  final int? transmitMbps;
  final int? signalPercent;

  /// Adapter description, e.g. "Intel(R) Wi-Fi 6 AX201 160MHz".
  final String? adapter;

  /// Channel centre frequency in MHz, from the channel (and band).
  int? get frequencyMhz => channelToMhz(channel, band: band);

  /// "802.11ax, 5 GHz, channel 36, receive 1201 / send 1201 Mbps, signal 90%".
  String get summary {
    if (!connected) return 'Wi-Fi not connected';
    return [
      ?radioType,
      ?(band ?? bandFromMhz(frequencyMhz)),
      if (channel != null) 'channel $channel',
      if (receiveMbps != null || transmitMbps != null)
        'receive ${receiveMbps ?? '?'} / send ${transmitMbps ?? '?'} Mbps',
      if (signalPercent != null) 'signal $signalPercent%',
    ].join(', ');
  }
}

/// Channel -> MHz. 2.4 GHz: 1-13 -> 2407 + 5 ch, 14 -> 2484. 5 GHz:
/// 32-177 -> 5000 + 5 ch. 6 GHz (only when the band says so): 5950 + 5 ch.
int? channelToMhz(int? ch, {String? band}) {
  if (ch == null || ch <= 0) return null;
  if (band != null && band.startsWith('6')) return 5950 + 5 * ch;
  if (ch == 14) return 2484;
  if (ch >= 1 && ch <= 13) return 2407 + 5 * ch;
  if (ch >= 32 && ch <= 177) return 5000 + 5 * ch;
  return null;
}

String? bandFromMhz(int? mhz) {
  if (mhz == null) return null;
  if (mhz >= 5925) return '6 GHz';
  if (mhz >= 4900) return '5 GHz';
  return '2.4 GHz';
}

/// Parses `netsh wlan show interfaces` (first connected interface).
WlanLink parseNetshInterfaces(String out) {
  // Interfaces are separated by "Name :" lines.
  final blocks = <Map<String, String>>[];
  Map<String, String>? cur;
  for (final raw in out.split(RegExp(r'\r?\n'))) {
    final i = raw.indexOf(':');
    if (i <= 0) continue;
    final k = raw.substring(0, i).trim().toLowerCase();
    final v = raw.substring(i + 1).trim();
    if (k == 'name') {
      cur = {};
      blocks.add(cur);
    }
    cur ??= (blocks..add({})).last;
    // Never keep network names or access point addresses.
    if (k == 'ssid' || k.startsWith('bssid') || k == 'ap bssid') continue;
    if (k == 'profile') continue;
    cur.putIfAbsent(k, () => v);
  }
  int? n(String? s) =>
      s == null ? null : double.tryParse(s.replaceAll('%', '').trim())?.round();
  for (final b in blocks) {
    if ((b['state'] ?? '').toLowerCase() != 'connected') continue;
    final band = b['band'];
    return WlanLink(
      connected: true,
      radioType: b['radio type'],
      band: band == null || band.isEmpty ? null : band,
      channel: n(b['channel']),
      receiveMbps: n(b['receive rate (mbps)']),
      transmitMbps: n(b['transmit rate (mbps)']),
      signalPercent: n(b['signal']),
      adapter: b['description'],
    );
  }
  return const WlanLink();
}

/// `powercfg /query SCHEME_CURRENT` (wireless adapter settings, power
/// saving mode): 0 = Maximum Performance ... 3 = Maximum Power Saving.
const kWifiPowerSubgroup = '19cbb8fa-5279-450e-9fac-8a3d5fedd0c1';
const kWifiPowerSetting = '12bbebe6-58d6-4636-95bb-3217ef867c1a';

const _powerNames = [
  'Maximum Performance',
  'Low Power Saving',
  'Medium Power Saving',
  'Maximum Power Saving',
];

/// "plugged in: Maximum Performance, battery: Medium Power Saving", or null.
String? parsePowercfgWifi(String out) {
  int? idx(String which) {
    final m = RegExp('Current $which Power Setting Index:\\s*0x([0-9a-fA-F]+)')
        .firstMatch(out);
    return m == null ? null : int.tryParse(m.group(1)!, radix: 16);
  }

  String name(int? i) => i == null
      ? 'unknown'
      : (i >= 0 && i < _powerNames.length ? _powerNames[i] : 'value $i');
  final ac = idx('AC');
  final dc = idx('DC');
  if (ac == null && dc == null) return null;
  return 'plugged in: ${name(ac)}, battery: ${name(dc)}';
}

/// Advanced adapter properties worth knowing for speed (read-only).
final _interesting = RegExp(
  r'roam|mimo|power|band|throughput|coalesc|channel width|802\.11n/ac|mode',
  caseSensitive: false,
);

/// Lines `Adapter|Property|Value` to `Wi-Fi: Roaming Aggressiveness = 3. Medium`.
List<String> parseAdapterProps(String out) => [
  for (final l in out.split(RegExp(r'\r?\n')))
    if (l.split('|') case [final a, final p, final v]
        when _interesting.hasMatch(p))
      '${a.trim()}: ${p.trim()} = ${v.trim()}',
];

/// Everything above for Diagnostics / the Speed test. Read-only.
class WindowsLinkReport {
  const WindowsLinkReport({
    required this.wlan,
    this.ethernet = false,
    this.powerSaving,
    this.adapterProps = const [],
  });

  final WlanLink wlan;

  /// No Wi-Fi connection, but an "Ethernet" adapter has an address.
  final bool ethernet;
  final String? powerSaving;
  final List<String> adapterProps;

  /// Link type for the route chip: "5 GHz", "Ethernet", ... or null.
  String? get linkLabel => wlan.connected
      ? (wlan.band ?? bandFromMhz(wlan.frequencyMhz))
      : ethernet
      ? 'Ethernet'
      : null;

  List<String> get lines => [
    'Wi-Fi: ${wlan.summary}',
    if (!wlan.connected && ethernet) 'Cable: Ethernet connected',
    'Wi-Fi power saving: ${powerSaving ?? 'not available'}',
    if (adapterProps.isEmpty)
      'Adapter settings (roaming etc.): not available'
    else
      ...adapterProps.map((p) => 'Adapter: $p'),
  ];
}

Future<String> _run(String exe, List<String> args) async {
  try {
    final r = await Process.run(exe, args).timeout(const Duration(seconds: 8));
    return '${r.stdout}';
  } catch (_) {
    return '';
  }
}

WindowsLinkReport? _cached;
DateTime _cachedAt = DateTime.fromMillisecondsSinceEpoch(0);

/// Windows only. [full] also reads power and adapter settings (slower).
Future<WindowsLinkReport?> readWindowsLink({bool full = false}) async {
  if (!Platform.isWindows) return null;
  if (!full &&
      _cached != null &&
      DateTime.now().difference(_cachedAt) < const Duration(seconds: 5)) {
    return _cached;
  }
  final wlan = parseNetshInterfaces(
    await _run('netsh', ['wlan', 'show', 'interfaces']),
  );
  var eth = false;
  if (!wlan.connected) {
    try {
      final ifs = await NetworkInterface.list(type: InternetAddressType.IPv4);
      eth = ifs.any(
        (i) =>
            i.name.toLowerCase().startsWith('ethernet') &&
            i.addresses.any((a) => !a.address.startsWith('169.254.')),
      );
    } catch (_) {}
  }
  String? power;
  var props = const <String>[];
  if (full) {
    power = parsePowercfgWifi(
      await _run('powercfg', [
        '/query',
        'SCHEME_CURRENT',
        kWifiPowerSubgroup,
        kWifiPowerSetting,
      ]),
    );
    props = parseAdapterProps(
      await _run('powershell', [
        '-NoProfile',
        '-NonInteractive',
        '-Command',
        r'Get-NetAdapterAdvancedProperty -ErrorAction SilentlyContinue | '
            r'ForEach-Object { "$($_.Name)|$($_.DisplayName)|$($_.DisplayValue)" }',
      ]),
    );
  }
  final r = WindowsLinkReport(
    wlan: wlan,
    ethernet: eth,
    powerSaving: power,
    adapterProps: props,
  );
  _cached = r;
  _cachedAt = DateTime.now();
  return r;
}
