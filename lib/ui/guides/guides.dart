import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';
import '../widgets/common.dart';

/// One step-by-step guide. Text only, no tracking. [platforms] lists where
/// it applies ('android', 'windows', 'macos', 'ios', 'linux'); empty = all.
class Guide {
  const Guide({
    required this.id,
    required this.title,
    required this.summary,
    required this.icon,
    required this.sections,
    this.platforms = const [],
    this.notes = const [],
  });

  final String id;
  final String title;
  final String summary;
  final IconData icon;
  final List<GuideSection> sections;
  final List<String> platforms;
  final List<String> notes;
}

class GuideSection {
  const GuideSection(this.heading, this.steps);
  final String heading;
  final List<String> steps;
}

const guidePhoneHotspot = Guide(
  id: 'phone_hotspot',
  title: 'No router: use your phone\'s hotspot',
  summary: 'Your Android phone makes a Wi-Fi network; the computer joins it.',
  icon: Icons.wifi_tethering,
  sections: [
    GuideSection('On the Android phone', [
      'Open Settings > Network & internet (or Connections) > Hotspot & tethering.',
      'Turn on Wi-Fi hotspot. Note its name and password (tap the hotspot to see them).',
      'Optional, for more speed: in the hotspot settings choose the 5 GHz band if offered.',
      'Open Isekai Drop and keep it open.',
    ]),
    GuideSection('On the Windows PC', [
      'Click the Wi-Fi icon in the taskbar and pick the phone\'s hotspot name. Type the password.',
      'Open Isekai Drop. If Windows asks about the firewall, allow it (tick Private and Public, or at least the type this network uses).',
    ]),
    GuideSection('On the Mac', [
      'Click the Wi-Fi icon in the menu bar and pick the phone\'s hotspot name. Type the password.',
      'Open Isekai Drop. If macOS asks to allow finding devices on the local network, click Allow.',
    ]),
    GuideSection('Then', [
      'On either device open Connect. The other device should appear under "Found automatically". If not, scan its QR code or type its address.',
      'Tap the device, then tap Accept on the other one. Comparing the 16-digit code is optional (see Privacy).',
    ]),
  ],
  notes: [
    'The computer may use the phone\'s mobile data for its own internet while connected. Turn off mobile data on the phone if you do not want that.',
    'No internet is needed for Isekai Drop itself.',
  ],
);

const guideWindowsHotspot = Guide(
  id: 'windows_hotspot',
  title: 'No router: use Windows Mobile Hotspot',
  summary: 'The Windows PC makes a Wi-Fi network; the phone joins it.',
  icon: Icons.laptop_windows,
  platforms: ['windows', 'android', 'ios'],
  sections: [
    GuideSection('On the Windows PC', [
      'Open Settings > Network & internet > Mobile hotspot.',
      'Choose "Share over: Wi-Fi". Note the network name and password (Edit to change them).',
      'Turn Mobile hotspot On. If it says there is no internet connection to share, this PC may not allow it without one - use the phone hotspot guide instead.',
      'Open Isekai Drop. If the firewall asks, allow it.',
    ]),
    GuideSection('On the Android phone', [
      'Open Settings > Wi-Fi and join the PC\'s hotspot name with its password.',
      'If Android says "No internet", choose to stay connected.',
      'Open Isekai Drop and go to Connect.',
    ]),
    GuideSection('Then', [
      'The PC should appear under "Found automatically". If not, scan the QR code shown on the PC or type its address (often 192.168.137.1).',
      'Tap the device, then tap Accept on the other one. Comparing the 16-digit code is optional (see Privacy).',
    ]),
  ],
  notes: [
    'Not every Wi-Fi card supports Mobile hotspot. Speed depends on the PC\'s Wi-Fi card.',
    'Macs have no equivalent. For a Mac use the phone hotspot.',
  ],
);

const guideLocalNetwork = Guide(
  id: 'local_network',
  title: 'Allow local network access',
  summary: 'Some systems ask before an app may talk to nearby devices.',
  icon: Icons.lan_outlined,
  sections: [
    GuideSection('Mac (macOS 15 and newer)', [
      'When asked "Allow Isekai Drop to find devices on local networks?", click Allow.',
      'If you clicked Don\'t Allow: System Settings > Privacy & Security > Local Network > turn on Isekai Drop.',
    ]),
    GuideSection('iPhone / iPad', [
      'Tap Allow when asked about the local network.',
      'Later: Settings > Privacy & Security > Local Network > Isekai Drop.',
    ]),
    GuideSection('Windows', [
      'When Windows Defender Firewall asks, allow Isekai Drop.',
      'If you blocked it: Settings > Privacy & security > Windows Security > Firewall > Allow an app through firewall > tick Isekai Drop.',
      'A new hotspot is usually a "Public" network - allow Public too, or set that network to Private.',
      'Not sure? Settings > Diagnostics > Check Windows Firewall shows whether it is blocked (it only reads the rules).',
    ]),
    GuideSection('Android', [
      'No permission is needed for normal Wi-Fi or a phone hotspot.',
    ]),
  ],
);

const guideKeepOpen = Guide(
  id: 'keep_open',
  title: 'Keep the app open while sending',
  summary: 'Transfers run only while Isekai Drop is open on both devices.',
  icon: Icons.phone_android,
  sections: [
    GuideSection('While a transfer runs', [
      'Keep Isekai Drop open and on screen on both devices.',
      'On Android the app keeps the screen on during a transfer. Do not switch apps.',
      'On a laptop, plug in power and stop it from sleeping.',
      'If you must stop, tap Pause. Resume continues from where it paused, as long as the app stays open.',
    ]),
  ],
  notes: [
    'If the app is closed during a transfer, unfinished files are deleted and you send again (resume after closing comes later).',
  ],
);

const guideNotFound = Guide(
  id: 'not_found',
  title: 'Devices do not find each other',
  summary: 'What to try when the other device does not appear.',
  icon: Icons.help_outline,
  sections: [
    GuideSection('Try in this order', [
      'Make sure both devices are on the same Wi-Fi or hotspot.',
      'Open Connect on both devices and wait 5 seconds.',
      'Tap "Search this network": it asks every address on your Wi-Fi or hotspot directly. This works even where the router blocks discovery.',
      'Scan the other device\'s QR code (Connect > Show my QR code on the other device).',
      'Or type the address and port shown on the other device.',
      'Guest or office Wi-Fi often blocks devices from seeing each other. Use a hotspot instead.',
      'Check the firewall / local network permission (see that guide).',
    ]),
  ],
);

const guideIphone = Guide(
  platforms: ['ios', 'android', 'macos', 'windows', 'linux'],
  id: 'iphone',
  title: 'iPhone and iPad: how it works',
  summary: 'What Apple allows, and how to connect an iPhone.',
  icon: Icons.phone_iphone,
  sections: [
    GuideSection('Connecting', [
      'Put the iPhone and the other device on the same Wi-Fi, or join the other device\'s hotspot.',
      'The first time, iOS asks to find devices on your local network. Tap Allow.',
      'Android phones and Macs appear automatically (Bonjour). Windows and Linux PCs do NOT appear on iPhone: on the iPhone tap Scan QR code and scan the PC\'s QR code, or type its address.',
      'Tap the device, then tap Accept on the other one, like on any device.',
    ]),
    GuideSection('While sending', [
      'Keep Isekai Drop open and on screen. iOS pauses apps in the background; the screen will not auto-lock during a transfer.',
      'If you switch away, iOS may give a short grace period, then the transfer stops and unfinished files are deleted.',
    ]),
    GuideSection('Where files go', [
      'Files app > On My iPhone > Isekai Drop > Received.',
      'After a transfer tap "Share / Save to Files" to move files elsewhere or into Photos.',
    ]),
  ],
  notes: [
    'If you tapped Don\'t Allow: Settings > Privacy & Security > Local Network > turn on Isekai Drop.',
    'Folders cannot be picked on iPhone yet; pick the files instead.',
  ],
);

const guideLinux = Guide(
  id: 'linux',
  title: 'Linux notes',
  summary: 'What works on Linux and what to install.',
  icon: Icons.computer,
  platforms: ['linux'],
  sections: [
    GuideSection('Setup', [
      'The device key is kept in your keyring (GNOME Keyring / KWallet via Secret Service). Without a keyring the app uses a private file and says so in Diagnostics.',
      'If a firewall (ufw, firewalld) is on, allow TCP port 47820 and UDP port 47821 for your local network.',
      'iPhones do not see Linux PCs automatically: show this PC\'s QR code and scan it on the iPhone.',
    ]),
  ],
);

const guideFastDirect = Guide(
  id: 'fast_direct',
  title: 'Fast direct: no router in between',
  summary: 'A direct Wi-Fi link from an Android phone. Usually faster.',
  icon: Icons.bolt,
  sections: [
    GuideSection('Android phone to Android phone', [
      'On both phones keep Settings > Fast direct when possible on, and tap Allow once (Nearby devices, or Location on Android 12 and older - your location is not used).',
      'Pair the phones once as usual. Then just send big files (64 MB or more): the phones make a direct link by themselves, 5 GHz when they allow it. The transfer card shows "Route: Fast direct".',
      'No router at all? On one phone open Connect > Fast direct > Start fast link. On the other phone tap Connect > Scan QR code and scan the "Isekai Drop" code.',
    ]),
    GuideSection('Android phone to Windows, Mac or Linux PC', [
      'On the phone open Connect > Fast direct > Start fast link.',
      'On the PC open Connect > Fast direct, type the network name and password shown on the phone and click Join (the Mac can also scan the code). Or join that network from the PC\'s Wi-Fi menu.',
      'The PC then pairs with the phone (tap Accept on the phone) or finds it under Connect.',
    ]),
    GuideSection('Android phone to iPhone', [
      'On the phone open Connect > Fast direct > Start fast link and tap "PC / iPhone camera".',
      'Scan that code with the iPhone Camera app and tap Join.',
      'Open Isekai Drop on the iPhone, tap Connect > Scan QR code and scan the "Isekai Drop" code on the phone.',
    ]),
    GuideSection('Windows PC as the link', [
      'On the PC open Connect > Fast direct > Start Windows hotspot (or Open Mobile hotspot settings and set Band to 5 GHz if offered).',
      'On the phone scan the Wi-Fi code shown on the PC (Isekai Drop Connect > Scan QR code works too), then pair as usual.',
    ]),
  ],
  notes: [
    'While a phone or PC is on a fast link it may have no internet. Leaving the link (or the link stopping) brings the normal Wi-Fi back.',
    'If the direct link cannot be made, Isekai Drop uses your router as before and Diagnostics shows why.',
    'Speed depends on both devices\' Wi-Fi chips. A direct link only helps when the router is the slow part.',
  ],
);

const allGuides = [
  guideFastDirect,
  guideIphone,
  guideLinux,
  guidePhoneHotspot,
  guideWindowsHotspot,
  guideLocalNetwork,
  guideKeepOpen,
  guideNotFound,
];

List<Guide> guidesForThisPlatform() {
  final os = Platform.operatingSystem;
  return [
    for (final g in allGuides)
      if (g.platforms.isEmpty || g.platforms.contains(os)) g,
  ];
}

class GuidesScreen extends StatelessWidget {
  const GuidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final list = guidesForThisPlatform();
    return Scaffold(
      appBar: AppBar(title: const Text('Help & guides')),
      body: PageBody(children: [for (final g in list) GuideTile(guide: g)]),
    );
  }
}

class GuideTile extends StatelessWidget {
  const GuideTile({super.key, required this.guide});
  final Guide guide;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      minTileHeight: IdLayout.minTouchTarget,
      leading: Icon(guide.icon, color: IdColors.accentGlow),
      title: Text(guide.title),
      subtitle: Text(guide.summary),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => openGuide(context, guide),
    ),
  );
}

void openGuide(BuildContext context, Guide g) =>
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => GuideScreen(guide: g)));

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key, required this.guide});
  final Guide guide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var n = 0;
    return Scaffold(
      appBar: AppBar(title: Text(guide.title)),
      body: PageBody(
        children: [
          Text(guide.summary, style: theme.textTheme.bodyLarge),
          for (final s in guide.sections)
            SectionCard(
              title: s.heading,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final step in s.steps)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: IdSpacing.xs,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: IdColors.accentPurple,
                            child: Text(
                              '${++n}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: IdSpacing.sm),
                          Expanded(child: Text(step)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (guide.notes.isNotEmpty)
            SectionCard(
              title: 'Good to know',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final note in guide.notes)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: IdSpacing.xs,
                      ),
                      child: Text('• $note'),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
