// 0.10.0: join a phone's Fast direct link from a PC (Windows / Linux /
// macOS) with the system's own Wi-Fi tools. Commands are run with argument
// lists (never through a shell), so names and passwords cannot inject
// commands. Builders are pure for unit tests.
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// One program call.
class WifiCommand {
  const WifiCommand(this.exe, this.args, {this.secretArgs = const {}});
  final String exe;
  final List<String> args;

  /// Indexes of [args] that hold the password (hidden in Diagnostics).
  final Set<int> secretArgs;

  /// For Diagnostics: the command with the password replaced.
  String redacted() => [
    exe,
    for (var i = 0; i < args.length; i++)
      secretArgs.contains(i) ? '***' : args[i],
  ].join(' ');
}

String _xml(String s) =>
    const HtmlEscape(HtmlEscapeMode.element)
        .convert(s)
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');

/// Windows WLAN profile (WPA2-Personal, AES, manual connect so Windows
/// does not switch to it by itself later).
String windowsWlanProfileXml(String ssid, String passphrase) {
  final hex = utf8
      .encode(ssid)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join()
      .toUpperCase();
  return '''<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
  <name>${_xml(ssid)}</name>
  <SSIDConfig>
    <SSID>
      <hex>$hex</hex>
      <name>${_xml(ssid)}</name>
    </SSID>
  </SSIDConfig>
  <connectionType>ESS</connectionType>
  <connectionMode>manual</connectionMode>
  <MSM>
    <security>
      <authEncryption>
        <authentication>WPA2PSK</authentication>
        <encryption>AES</encryption>
        <useOneX>false</useOneX>
      </authEncryption>
      <sharedKey>
        <keyType>passPhrase</keyType>
        <protected>false</protected>
        <keyMaterial>${_xml(passphrase)}</keyMaterial>
      </sharedKey>
    </security>
  </MSM>
</WLANProfile>
''';
}

List<WifiCommand> windowsJoinCommands(String ssid, String profilePath) => [
  WifiCommand('netsh', [
    'wlan',
    'add',
    'profile',
    'filename=$profilePath',
    'user=current',
  ]),
  WifiCommand('netsh', ['wlan', 'connect', 'name=$ssid', 'ssid=$ssid']),
];

List<WifiCommand> windowsLeaveCommands(String ssid) => [
  WifiCommand('netsh', ['wlan', 'disconnect']),
  WifiCommand('netsh', ['wlan', 'delete', 'profile', 'name=$ssid']),
];

List<WifiCommand> linuxJoinCommands(String ssid, String passphrase) => [
  WifiCommand(
    'nmcli',
    ['device', 'wifi', 'connect', ssid, 'password', passphrase],
    secretArgs: {5},
  ),
];

List<WifiCommand> linuxLeaveCommands(String ssid) => [
  WifiCommand('nmcli', ['connection', 'delete', 'id', ssid]),
];

/// Finds the Wi-Fi device ("en0") in `networksetup -listallhardwareports`.
String? macWifiDevice(String listAllHardwarePorts) {
  final lines = const LineSplitter().convert(listAllHardwarePorts);
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i].trim();
    if (l == 'Hardware Port: Wi-Fi' || l == 'Hardware Port: AirPort') {
      for (var j = i + 1; j < lines.length && j <= i + 3; j++) {
        final m = RegExp(r'^Device:\s*(\S+)').firstMatch(lines[j].trim());
        if (m != null) return m.group(1);
      }
    }
  }
  return null;
}

List<WifiCommand> macJoinCommands(
  String device,
  String ssid,
  String passphrase,
) => [
  WifiCommand(
    'networksetup',
    ['-setairportnetwork', device, ssid, passphrase],
    secretArgs: {3},
  ),
];

/// Result of a join attempt on a PC.
class PcJoinResult {
  const PcJoinResult(this.ok, this.message, this.log);
  final bool ok;
  final String message;

  /// Redacted commands and their exit codes (for Diagnostics).
  final List<String> log;
}

typedef ProcessRunner = Future<ProcessResult> Function(
  String exe,
  List<String> args,
);

Future<ProcessResult> _run(String exe, List<String> args) =>
    Process.run(exe, args, runInShell: false);

bool get canJoinFromPc =>
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// Joins a Wi-Fi network on this PC. The temporary Windows profile file
/// (it contains the password) is deleted right after use.
Future<PcJoinResult> joinWifiFromPc(
  String ssid,
  String passphrase, {
  ProcessRunner run = _run,
  Directory? tempDir,
}) async {
  final log = <String>[];
  Future<bool> all(List<WifiCommand> cmds) async {
    for (final c in cmds) {
      try {
        final r = await run(c.exe, c.args);
        log.add('${c.redacted()} -> ${r.exitCode}');
        if (r.exitCode != 0) return false;
      } catch (e) {
        log.add('${c.redacted()} -> could not run (${e.runtimeType})');
        return false;
      }
    }
    return true;
  }

  if (Platform.isWindows) {
    final dir = await (tempDir ?? Directory.systemTemp).createTemp('idrop');
    final f = File(p.join(dir.path, 'isekai-drop-link.xml'));
    try {
      await f.writeAsString(windowsWlanProfileXml(ssid, passphrase));
      final ok = await all(windowsJoinCommands(ssid, f.path));
      return PcJoinResult(
        ok,
        ok
            ? 'Joining "$ssid"...'
            : 'Windows could not join "$ssid". Join it in the Wi-Fi menu '
                  '(taskbar) with the password shown on the phone.',
        log,
      );
    } finally {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }
  if (Platform.isLinux) {
    final ok = await all(linuxJoinCommands(ssid, passphrase));
    return PcJoinResult(
      ok,
      ok
          ? 'Joined "$ssid".'
          : 'Could not join with NetworkManager (nmcli). Join "$ssid" in the '
                'Wi-Fi menu with the password shown on the phone.',
      log,
    );
  }
  if (Platform.isMacOS) {
    String? dev;
    try {
      final r = await run('networksetup', ['-listallhardwareports']);
      dev = macWifiDevice('${r.stdout}');
    } catch (_) {}
    final ok = dev != null && await all(macJoinCommands(dev, ssid, passphrase));
    return PcJoinResult(
      ok,
      ok
          ? 'Joined "$ssid".'
          : 'Could not join automatically. Join "$ssid" in the Wi-Fi menu '
                '(menu bar) with the password shown on the phone.',
      log,
    );
  }
  return const PcJoinResult(false, 'Not supported on this device.', []);
}

/// Forgets the phone's link again (so the PC goes back to its usual Wi-Fi).
Future<void> leaveWifiFromPc(String ssid, {ProcessRunner run = _run}) async {
  final cmds = Platform.isWindows
      ? windowsLeaveCommands(ssid)
      : Platform.isLinux
      ? linuxLeaveCommands(ssid)
      : const <WifiCommand>[];
  for (final c in cmds) {
    try {
      await run(c.exe, c.args);
    } catch (_) {}
  }
}

// ---------------------------------------------------------------------------
// Windows Mobile Hotspot (Windows as the host)

/// PowerShell script that starts Windows Mobile Hotspot through the
/// Windows Runtime tethering API and prints one JSON line with the network
/// name, password and band. Needs a network connection to share (Windows
/// requirement); if it fails, the app opens the Mobile hotspot settings.
const String windowsHotspotScript = r'''
$ErrorActionPreference = 'Stop'
try {
  Add-Type -AssemblyName System.Runtime.WindowsRuntime
  $asTask = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
  function Await($op, $type) { $t = $asTask.MakeGenericMethod($type).Invoke($null, @($op)); $t.Wait(-1) | Out-Null; $t.Result }
  $null = [Windows.Networking.Connectivity.NetworkInformation, Windows.Networking.Connectivity, ContentType = WindowsRuntime]
  $null = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager, Windows.Networking.NetworkOperators, ContentType = WindowsRuntime]
  $profile = [Windows.Networking.Connectivity.NetworkInformation]::GetInternetConnectionProfile()
  if ($null -eq $profile) { '{"ok":false,"error":"no_shared_connection"}'; exit 0 }
  $tm = [Windows.Networking.NetworkOperators.NetworkOperatorTetheringManager]::CreateFromConnectionProfile($profile)
  if ($tm.TetheringOperationalState -ne 'On') {
    $r = Await ($tm.StartTetheringAsync()) ([Windows.Networking.NetworkOperators.NetworkOperatorTetheringOperationResult])
    if ($r.Status -ne 'Success') { '{"ok":false,"error":"' + $r.Status + '"}'; exit 0 }
  }
  $c = $tm.GetCurrentAccessPointConfiguration()
  $band = ''
  try { $band = [string]$c.Band } catch {}
  @{ ok = $true; ssid = $c.Ssid; pass = $c.Passphrase; band = $band } | ConvertTo-Json -Compress
} catch {
  '{"ok":false,"error":"script_failed"}'
}
''';

class WindowsHotspot {
  const WindowsHotspot({
    required this.ok,
    this.ssid,
    this.passphrase,
    this.band,
    this.error,
  });
  final bool ok;
  final String? ssid;
  final String? passphrase;
  final String? band;
  final String? error;

  /// Parses the last JSON line printed by [windowsHotspotScript].
  static WindowsHotspot parse(String out) {
    final lines = const LineSplitter()
        .convert(out)
        .map((l) => l.trim())
        .where((l) => l.startsWith('{'));
    if (lines.isEmpty) {
      return const WindowsHotspot(ok: false, error: 'no_output');
    }
    try {
      final m = jsonDecode(lines.last);
      if (m is! Map) throw const FormatException();
      if (m['ok'] != true) {
        return WindowsHotspot(ok: false, error: '${m['error'] ?? 'failed'}');
      }
      final ssid = m['ssid'];
      final pass = m['pass'];
      if (ssid is! String || pass is! String || ssid.isEmpty) {
        return const WindowsHotspot(ok: false, error: 'bad_output');
      }
      return WindowsHotspot(
        ok: true,
        ssid: ssid,
        passphrase: pass,
        band: m['band'] is String ? m['band'] as String : null,
      );
    } catch (_) {
      return const WindowsHotspot(ok: false, error: 'bad_output');
    }
  }
}

String explainWindowsHotspotError(String? e) => switch (e) {
  'no_shared_connection' =>
    'Windows only starts Mobile Hotspot when the PC has a network '
        'connection to share (Wi-Fi or Ethernet). Connect the PC first, or '
        'use the phone\'s Fast direct link instead.',
  _ =>
    'Windows did not start Mobile Hotspot ($e). Turn it on in Settings > '
        'Network & internet > Mobile hotspot (set Band to 5 GHz if offered).',
};

Future<WindowsHotspot> startWindowsHotspot({ProcessRunner run = _run}) async {
  try {
    final r = await run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-Command',
      windowsHotspotScript,
    ]);
    return WindowsHotspot.parse('${r.stdout}');
  } catch (_) {
    return const WindowsHotspot(ok: false, error: 'powershell_missing');
  }
}

/// Opens Settings > Mobile hotspot (where the 5 GHz band is chosen).
Future<void> openWindowsHotspotSettings({ProcessRunner run = _run}) async {
  try {
    await run('explorer.exe', ['ms-settings:network-mobilehotspot']);
  } catch (_) {}
}
