import 'dart:io';

/// Result of reading Windows Defender Firewall's inbound rules for THIS
/// program. The app only reads rules; it never changes firewall settings.
enum FirewallVerdict {
  /// A Block rule matches this program (Windows: Block beats Allow).
  blocked,

  /// No rule for this program: Windows blocks incoming connections.
  noAllowRule,

  /// Allow rule(s) and no Block rule.
  allowed,

  /// Could not read or understand the rules (e.g. non-English Windows).
  unknown,
}

class FirewallStatus {
  const FirewallStatus(
    this.verdict, {
    this.blockedProfiles = const {},
    this.allowedProfiles = const {},
    this.otherCopies = 0,
  });

  final FirewallVerdict verdict;

  /// Profiles ("Private", "Public", "Domain") with a Block rule.
  final Set<String> blockedProfiles;

  /// Profiles with an Allow rule.
  final Set<String> allowedProfiles;

  /// Rules for a program with the same file name in ANOTHER folder (e.g. an
  /// older unzipped copy). They do not apply to this copy.
  final int otherCopies;

  /// Plain words for the user.
  String get summary => switch (verdict) {
    FirewallVerdict.blocked =>
      'BLOCKED by Windows Firewall (${_list(blockedProfiles)} networks). '
          'Other devices cannot connect to this PC.',
    FirewallVerdict.noAllowRule =>
      'No firewall rule allows Isekai Drop yet. Other devices cannot '
          'connect to this PC until it is allowed.',
    FirewallVerdict.allowed =>
      'Allowed on ${_list(allowedProfiles)} networks'
          '${allowedProfiles.any((p) => ['public', 'all', 'any'].contains(p.toLowerCase())) ? '' : '. Not on Public networks: a phone hotspot is often Public'}.',
    FirewallVerdict.unknown =>
      'Could not read the firewall rules (unknown format or no access).',
  };

  static String _list(Set<String> s) =>
      s.isEmpty ? 'some' : (s.toList()..sort()).join(', ');
}

/// Where to change it (Windows 10 and 11).
const kFirewallHelp =
    'To allow it: Start > Windows Security > Firewall & network protection > '
    'Allow an app through firewall > Change settings > find Isekai Drop '
    '(isekaidrop) > tick Private (and Public if you use a phone hotspot) > OK. '
    'If it shows as blocked, remove the blocked entry there or in '
    '"Advanced settings > Inbound Rules", then restart Isekai Drop and allow it '
    'when Windows asks.';

String _norm(String path) =>
    path.trim().replaceAll('/', r'\').replaceAll('"', '').toLowerCase();

String _base(String path) {
  final n = _norm(path);
  final i = n.lastIndexOf(r'\');
  return i < 0 ? n : n.substring(i + 1);
}

/// Parses `netsh advfirewall firewall show rule name=all dir=in verbose`
/// (English output). Only enabled rules whose Program is [exePath] count.
FirewallStatus parseFirewallRules(String output, String exePath) {
  final text = output.replaceAll('\r\n', '\n');
  if (!text.contains('Rule Name:')) {
    return const FirewallStatus(FirewallVerdict.unknown);
  }
  final me = _norm(exePath);
  final myBase = _base(exePath);
  final blocked = <String>{};
  final allowed = <String>{};
  var other = 0;
  for (final block in text.split(RegExp(r'^Rule Name:', multiLine: true))) {
    final f = <String, String>{};
    for (final line in block.split('\n')) {
      final i = line.indexOf(':');
      if (i <= 0) continue;
      f[line.substring(0, i).trim().toLowerCase()] = line
          .substring(i + 1)
          .trim();
    }
    final program = f['program'];
    if (program == null || program.isEmpty) continue;
    if ((f['enabled'] ?? '').toLowerCase() != 'yes') continue;
    final dir = (f['direction'] ?? 'In').toLowerCase();
    if (dir != 'in') continue;
    if (_norm(program) != me) {
      if (_base(program) == myBase) other++;
      continue;
    }
    final profiles = (f['profiles'] ?? 'All')
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toSet();
    final action = (f['action'] ?? '').toLowerCase();
    if (action == 'block') blocked.addAll(profiles);
    if (action == 'allow') allowed.addAll(profiles);
  }
  if (blocked.isNotEmpty) {
    return FirewallStatus(
      FirewallVerdict.blocked,
      blockedProfiles: blocked,
      allowedProfiles: allowed,
      otherCopies: other,
    );
  }
  if (allowed.isNotEmpty) {
    return FirewallStatus(
      FirewallVerdict.allowed,
      allowedProfiles: allowed,
      otherCopies: other,
    );
  }
  return FirewallStatus(FirewallVerdict.noAllowRule, otherCopies: other);
}

/// Windows only: reads the inbound rules with netsh (read-only, no admin
/// needed). Any failure gives [FirewallVerdict.unknown].
Future<FirewallStatus> checkWindowsFirewall() async {
  if (!Platform.isWindows) {
    return const FirewallStatus(FirewallVerdict.unknown);
  }
  try {
    final r = await Process.run('netsh', [
      'advfirewall',
      'firewall',
      'show',
      'rule',
      'name=all',
      'dir=in',
      'verbose',
    ]).timeout(const Duration(seconds: 20));
    if (r.exitCode != 0 && '${r.stdout}'.trim().isEmpty) {
      return const FirewallStatus(FirewallVerdict.unknown);
    }
    return parseFirewallRules('${r.stdout}', Platform.resolvedExecutable);
  } catch (_) {
    return const FirewallStatus(FirewallVerdict.unknown);
  }
}
