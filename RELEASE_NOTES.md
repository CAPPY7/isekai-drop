# Isekai Drop 0.11.0 (DRAFT release notes, test build)

## What changed: easier screens (docs/UI_SPEC_0.11.md)
- **First start:** 3 short slides (open on both devices, same Wi-Fi, pick
  files and send). Skip any time; shown once (also once after updating).
- **Home:** Wi-Fi status at the top ("Wi-Fi · 5 GHz", a warning on 2.4 GHz,
  "Ethernet", "No network"). One big **Send** and one **Connect a device**
  button. Empty sections take one line or are hidden.
- **Searching:** a small radar pulse instead of a still icon. After 8 s a
  hint with 3 steps and **Scan QR** / **Search again**.
- **Send:** three steps: 1 pick files, 2 pick a device, 3 the **Send**
  button, which stays at the bottom and works only when both are chosen.
- **Connect:** QR code first. Address, port and key fingerprint are under
  **Advanced** (closed).
- **Settings:** groups (Appearance, This device, Receiving, Connection,
  Security, Advanced). Each switch has one line; the rest is behind an (i)
  button. Theme defaults to **System**. The device name defaults to the
  phone model (e.g. "OnePlus 9").
- **Fast direct:** the new default is **Auto (fastest)** (see below), with
  **Allow** right next to it when a permission is missing. Choices: Auto,
  Router only, Fast direct always.
- **Transfer screen:** file name, big percentage, live speed, time left, a
  small speed graph, a route chip ("Router · 5 GHz"), large **Pause** and
  **Cancel** (Cancel asks first).
- **Finished:** check mark, file names, average speed, **Open** / **Show in
  folder** (PCs), **Share** (iPhone), **Send more**.
- **Errors:** one plain sentence, one suggested fix, **Retry**; codes only
  under **Details**.
- **Receive prompt:** sender, file count and size, big **Accept** and
  **Decline**.
- **Accessibility:** 48 dp touch targets, text contrast at least 4.5:1 in
  both themes, works at 200% text size on 320 dp phones, TalkBack labels
  (progress, route, network, QR, steps), icons next to colours, "reduce
  motion" turns off the pulse, chart animation and page fades. Max content
  width 600 dp. Haptics on send, finish and error.

## Speed: Windows -> Android (separate engine changes)
- **Diagnostics on Windows** now shows the Wi-Fi link (standard, band,
  channel, receive/send rate, signal; never the network name), whether the
  PC uses Ethernet, and the adapter's power saving and roaming settings.
  The Speed test report includes the same link line.
- **Auto (fastest)** route for big sends to Android phones: the first big
  send to a phone uses the router and measures it; Fast direct is tried
  only if the router was slower than 20 MB/s and kept only if it was clearly
  faster. The reason is shown on the transfer and in Diagnostics. Only
  speeds are stored (route_stats.json, this device only).
- A PC still cannot join a phone's Fast direct link by itself (needs the
  manual "Join from a PC" steps). See docs/SPEED.md.

## Known limits / NOT TESTED
- NOT TESTED on real phones or PCs: every screen above, haptics, TalkBack,
  the Windows link report, Open / Show in folder, the Auto route.
- Not done: "Always allow this device" on the receive prompt (needs an
  engine change; use Settings > Auto-receive from verified devices), Open /
  Show in folder on Android, list-item appear animations, automatic Fast
  direct from Windows.
- Windows still not code-signed; Android APKs are signed with the public test
  key (README "Security note").

# Isekai Drop 0.10.3 (DRAFT release notes, test build)

## What changed
- **Windows: one installer file** instead of a zip with many files:
  `isekai-drop-windows-setup.exe` on the latest-build release. Installs for
  your user only (no admin) to `%LOCALAPPDATA%\Programs\Isekai Drop`, Start
  menu entry, optional desktop icon, uninstaller in Settings > Apps.
- The Windows app now shows "Isekai Drop" as product/company name and the
  real version in its file properties (was "isekaidrop" / "com.isujaykumar").
- No app logic changes; Android/iOS builds are the same code as 0.10.2.

## Known limits
- **Not code-signed** (stays unsigned for now). SmartScreen: More info > Run
  anyway. Windows 11 **Smart App Control** (if On) may block the installer
  and the app; then turn Smart App Control off. See `docs/WINDOWS_INSTALL.md`.
- The repo is now public, so the committed Android TEST key is public too:
  only install APKs from the latest-build release (see README "Security note").
- NOT TESTED on a real PC: install, shortcuts, uninstall, upgrade, SAC.

# Isekai Drop 0.10.2 (DRAFT release notes, test build)

Your Speed test (OnePlus 8 -> 9, Fast direct, 5240 MHz, link 432 Mbps) showed
plain TCP 6.9 MB/s, encrypted 7.1-8.8 MB/s, but disk and hashing at
121-312 MB/s: the **network link** is the slow step, not encryption or disk.

## What changed
- **Fast direct group on your router's channel:** when the phone is on a
  5 GHz router channel without radar rules (36-48, 149-165) the direct group
  is now asked to use that same channel. Two channels at once (router +
  direct) make the Wi-Fi chip switch back and forth, which can cut speed a
  lot. If the phone refuses, it falls back to "any 5 GHz" like before.
- **Wi-Fi stays awake during a transfer and the Speed test:** Wi-Fi lock
  (low-latency on Android 14+, high-performance on older Android; 0.10.1 had
  no lock at all on Android 14+) and a CPU wake lock (auto-released after 2 h
  at most). Released when the transfer or test ends.
- **4 TCP streams per data lane** for transfers between two 0.10.2 apps
  (older apps keep 1 stream).
- **Speed test, new rows:** network with 4 streams, Android native code
  (no Dart) with 1 and 4 streams, encrypted with 4 streams. The report now
  shows which interface the test used (for example "p2p0 (Wi-Fi Direct)",
  names only, no addresses), the direct group's channel and role, the lock
  state, and warnings when the direct test went through the router or the
  router and direct link are on different channels.

## Not tested
- Everything on phones: channel matching, Wi-Fi/CPU locks, native rows,
  4 streams over Wi-Fi, the interface report, any real speed gain.

# Isekai Drop 0.10.1 (DRAFT release notes, test build)

## New: Speed test (Diagnostics > Speed test)
Finds which step is slow between two paired devices: network without
encryption, encryption, reading + hashing, writing to Downloads and to the
temp folder, native hash, and Wi-Fi link speed on both ends. "Copy report"
copies the numbers (no device or file names). Only zeros are sent; test
files are deleted at once. Details: docs/SPEED.md.

## Faster engine (measured on the box only)
File data now goes over an encrypted data lane in a background isolate, so
encryption no longer competes with the app's main thread. Box loopback
engine bench: 36.0 MB/s (0.10.0) -> 82-90 MB/s. Falls back to the old path
if the lane can not open. Real phones: NOT measured.

## Not tested
- Everything on phones (lane on ARM, MediaStore test write, link readings,
  real speed gain).

# Isekai Drop 0.10.0 (DRAFT release notes, test build)

## New: Fast direct (no router in the middle)
- **Android ↔ Android:** big files (64 MB and up) between paired phones now
  go over a direct Wi-Fi link automatically (Wi-Fi Direct, 5 GHz asked
  first). If that does not work the app quietly uses your router like before
  and says why on the transfer card. Turn it on once in Settings >
  "Fast direct when possible" (Android asks for "Nearby devices", or
  "Location" on Android 12 and older - the app explains first).
- **No router at all:** Connect > Fast direct > Start fast link on one phone,
  scan the code with the other phone.
- **Android -> PC:** start the fast link on the phone, then on the PC open
  Connect > Fast direct, enter (or paste) the network and password, Join.
- **Android -> iPhone:** iPhone Camera scans the "PC / iPhone camera" code to
  join the Wi-Fi, then Isekai Drop on the iPhone scans the "Isekai Drop" code.
- **Windows as host:** Connect > Fast direct > Start Windows hotspot (or open
  Mobile hotspot settings, pick 5 GHz there); phones scan the Wi-Fi code.
- Transfer card and Diagnostics show the route (Router / Fast direct) and the
  last Fast direct problem.

## Honest speed note
Nothing measured on real radios yet. Estimate only: a direct link removes one
of the two Wi-Fi hops, so on Wi-Fi 6 phones (OnePlus 8/9) up to ~70 MB/s may
be possible and ~50 MB/s on Wi-Fi 5, versus ~36 MB/s best case through a
router. Real Wi-Fi is usually 50% or less of the link speed (Cisco Meraki).

## Install note
CI builds are signed with the dev key (same as 0.9.x), so this installs over
0.9.x without uninstalling.

## Not tested
- Every real-radio path: Wi-Fi Direct groups/5 GHz, local-only hotspot
  fallback, joining with the system approval dialog, PCs/iPhone joining.
- netsh / nmcli / networksetup join commands and the Windows hotspot script.
- The new screens on real devices.

# Isekai Drop 0.9.2 (DRAFT release notes, test build)

**Test build. Not a public release.** Real phones have NOT been tested by me (see "Not tested").

## New in 0.9.2: faster transfers (docs/BENCHMARK_SPEED_0.9.2.md)
Report on 0.9.1: OnePlus 8 -> OnePlus 9 on the same Wi-Fi gets 6-10 MB/s.
- **Faster file reading on Android**: 4 MiB per read (was 512 KiB), off the UI thread, two reads at once.
- **Native SHA-256 on Android**: the integrity check stays, but it now uses the phone's built-in SHA-256 instead of a slow Dart version (Dart SHA-256 was the slowest stage on the build box: ~117 MB/s vs ~1.9 GB/s native).
- **Bigger network frames** (256 KiB) and less progress bookkeeping.
- **Wi-Fi high-performance lock** during transfers (Android 13 and older; not used on Android 14+, see notes).
- **Wi-Fi band shown** on the Transfer and Diagnostics screens (e.g. "Wi-Fi: 5 GHz, link 1201 Mbps"). On 2.4 GHz it says **"Use 5 GHz for best speed"**.
- Box measurement (not phones): 512 MiB between two processes over real TLS, 57-59 MB/s (0.9.1) -> 63-64 MB/s (0.9.2 with native hashing).

### Honest speed note
Through a home router every byte crosses the air twice (phone -> router -> phone), and real Wi-Fi throughput is usually half or less of the link speed. Estimate: about 36 MB/s at best on Wi-Fi 6 5 GHz, and about 4-9 MB/s on 2.4 GHz - which matches 6-10 MB/s. **Put both phones on the 5 GHz network** and check the band line on the Transfer screen. 60-70 MB/s through a router is unlikely for any app; a direct phone-to-phone link is on the roadmap.

### Install note
Install over 0.9.1 (same test key, higher version number): **no uninstall needed**, pairings are kept. Update **both** phones.

### Not tested (honest list)
- Real phones: the speed gain, the Android file-reading and native-hashing code, the Wi-Fi lock, the band line.
- Windows PC, the Android emulator (box KVM fault).
- What WAS tested: 137 tests pass (incl. test/speed_paths_test.dart: 13 MiB with native-style digest, wrong digest -> integrity error, read-ahead order; test/wifi_band_test.dart), box e2e and stage bench above. Kotlin code is compile-checked by CI only.

# Isekai Drop 0.9.1 (DRAFT release notes, test build)

**Test build. Not a public release.** Real phones have NOT been tested by me (see "Not tested").

## New in 0.9.1 (docs/AUDIT.md #31-#34)
Report on 0.9.0: pairing is not user friendly, and sending failed at 0 B with "Could not reach the other device" even though the device showed Verified.
- **Sending fixed (two causes).** (1) A new device key was valid only from the moment it was made; if the other phone's clock was a little behind, it refused the key when the send started. Keys made by 0.9.1 are valid from 2 days earlier. (2) On Android 11+ the app re-opened picked files in a way the system can refuse; it now reads them the official way (ContentResolver).
- **Clear errors.** A failed send now says where it failed: could not connect (app closed / firewall / different network), the other device refused this device's key or a clock is wrong, could not read the file on this phone, the other device could not save it, or the connection was lost at X of Y MB. Diagnostics records the stage.
- **One-tap pairing.** Tap the device; the other one asks once "Accept NAME?". Both remember each other. Comparing the code is optional (Trusted devices > Check code). See PRIVACY.md for the trade-off.
- **Send without pairing first.** Pick files, choose a nearby device that is not paired; it asks once "NAME wants to send you N files - Accept?" and the files start right away. After that both are paired.
- Sending tries every known address of the device.

### Install note
Install over 0.9.0 (same test key, higher version number): **no uninstall needed**, pairings are kept. Update **both** devices (a 0.9.0 device still works but asks twice for pair-and-send). If sending still fails, check Settings > Date & time is set to automatic on both phones, then send the Diagnostics report (it now says which stage failed).

### Not tested (honest list)
- Real phones (one-tap pairing, sending, the Android file-reading fix).
- Windows PC, the Android emulator (box KVM fault).
- What WAS tested: test/one_tap_test.dart (11 tests: one-tap pair, unpaired send with one accept, both directions >10 MB, expiry and scope of the pre-approval, read/write/clock errors) and a real two-network-stack e2e (netns): one-tap send to an unpaired device (13 MB, one question), reply 14.5 MB, then a normal send 12.1 MB; all sha256 identical.

# Isekai Drop 0.9.0 (earlier draft notes)

**Test build. Not a public release.** Nothing here has been benchmarked against LocalSend yet. Real phones and a real Windows PC have NOT been tested by me (see "Not tested" below).

## New in 0.9.0 (make the core flow work, docs/AUDIT.md #25-#29)
Report on 0.8.1: "This doesn't work and has many problems". The app now concentrates on one flow: **find the other device -> pair -> send a file**, on home Wi-Fi or a normal phone/Windows hotspot.
- **Search this network** (#25): new button on Connect. It asks every address on your Wi-Fi/hotspot directly (encrypted, one short question per address) instead of relying only on discovery broadcasts, which many routers, hotspots and Windows PCs block. It also runs by itself once if nothing was found 4 seconds after Connect opens. Found devices appear while it runs. A hidden device ("visible to others" off) does not answer.
- **Discovery answers back** (#26): when a device hears another one, it replies directly to it (at most every 10 s), so one-way blocked broadcasts still let both sides see each other.
- **Sending back after pairing** (#27): the device that accepted pairing now saves the other device's port, so it can send back without waiting for discovery.
- **Errors stay on screen** (#28): pairing/connection problems open a dialog with the reason (refused, timed out, no route...) and what to check (same network, app open, Windows firewall), instead of a short message at the bottom.
- **Removed: "Make a hotspot with Isekai Drop"** (#29). It needed location/nearby-devices permissions, often failed or stopped on its own, could not be joined by iPhones, and gave no internet. Use the phone's normal hotspot (Settings) or Windows Mobile Hotspot instead (guides in Connect > No Wi-Fi router?). The app no longer asks for location or nearby-devices permissions.
- Fixed a test-only flake (Windows/Android CI: "Directory not empty" when a test cleaned up): the engine now waits for its background saves when it stops.

### Install note
If you installed the local test build **versionCode 1001** (0.8.1), **uninstall it first**: Android refuses to install a lower version number over it.

### Not tested (honest list)
- Real Android phones (pairing, sending, Search this network, Wi-Fi without internet).
- Real Windows PC (firewall, discovery, Search this network).
- The Android emulator: KVM on the build box crashed when the emulator started (kernel fault in vCPU creation), so the planned emulator test could not run.
- What WAS tested: two real engines on two separate Linux network stacks (network namespace, veth, real TCP/TLS, 10.77.0.0/24): Search found the other device, pairing, a 3 MiB file each way (sha256 identical), both directions. Plus the full unit/loopback test suite.

## New in 0.8.1 (real-device connection fixes, docs/AUDIT.md #20-#24)
Reported on 0.7.1: devices did not find each other, pairing failed and sending failed (Android-Android and Android-PC, home Wi-Fi and the app hotspot). Fixes:
- **Pairing no longer fails while you compare the code** (#20). The other device used to drop the connection after 10 seconds, before most people had finished comparing. Now it waits up to 2 minutes. The code dialog wording says what happens next. **Both devices need 0.8.1** to pair (older versions refuse the new pairing start).
- **Diagnostics shows what went wrong** (#21): the last 20 problems with time and type (for example "connect_refused", "incoming_tls_handshake_failed"), discovery and Bonjour counters, the Android multicast-lock result, this device's own addresses, and a **Copy report** button. The report has no file names and no other device's name or address.
- **Android on a Wi-Fi without internet** (another phone's hotspot, the app hotspot, a router without internet) (#22): the app keeps its traffic on that Wi-Fi instead of mobile data.
- **Discovery on every network** (#22): announcements now go out from each Wi-Fi/hotspot/Ethernet address, also to that network's broadcast address, and the app listens for the group on each.
- **QR code and "My addresses" list the right address first** (#23): Wi-Fi/hotspot, then Ethernet. Mobile data, VPN, Tailscale, WSL and link-local addresses are left out.
- **Windows: firewall check** (#24): Diagnostics > Check Windows Firewall reads the rules (changes nothing) and says Blocked / No allow rule / Allowed, with how to fix it.

None of this is tested on real phones or a Windows PC yet (NOT TESTED). Box tests: see docs/AUDIT.md.

## New in 0.8.0 (minor fixes, docs/AUDIT.md #10-#19)
- Faster: file checksums are calculated in the background. On the test machine (1 GiB, loopback) 17.6-18.0 MB/s became 31.1-32.8 MB/s (#10). Not measured on phones yet.
- Less memory during big transfers: on the test machine the peak was +38 to +318 MiB before and +51 to +58 MiB now (#18).
- Status words are plain English: Sending, Receiving, Paused, Done... (#11).
- Device names found on the network are cleaned of hidden/control characters (#12).
- A different file with the same name and size no longer tries to resume the old one (#14). Transfers interrupted with an older version start again once.
- Android keeps unfinished downloads in a folder the system does not clear (#15).
- The receiver checks free space first and says how much is needed (#16).
- Fixed a rare hang after the receiver cancelled (#19).
- Unused demo code removed (#13; no feature changed).

## New in 0.7.1 (audit fixes, docs/AUDIT.md #3-#9)
- If the device key had to be kept in a file, it now moves into secure storage once that works, and the file is wiped (#3).
- Limits on simultaneous and unauthenticated connections; shorter handshake timeout (#4).
- One damaged trusted-device entry no longer loses all devices: it is skipped, a backup is kept, a warning is shown (#5).
- Android 9 and older: files are saved to the real Downloads/Isekai Drop folder (asks for storage permission once; if refused, the real location is shown) (#6).
- The approval dialog closes itself when it times out ("Request expired") (#7).
- "Visible" off now only hides this device; it still finds others (#8).
- Failed sends are kept and can be retried after the app restarts (Home > Interrupted sends) (#9).

## New in 0.7.0
- **Benchmark log** (Settings > Benchmark log): save a finished transfer as a benchmark run (measured by the app) or add a hand-timed run (e.g. LocalSend). Shows median/min/max per test setup. Export CSV (Android: Downloads/Isekai Drop, iPhone: share sheet, PC: choose a place) or copy CSV. Saves only numbers and conditions: no file names, device names or addresses. Paused or resumed transfers can't be saved (not comparable).
- **Security fixes** from the code audit (docs/AUDIT.md):
  - A device on the network can no longer block your trusted device or change its saved address by sending fake discovery messages (#1).
  - Only one pairing request at a time; floods are refused with "busy" (#2).
  - Fixed a rare uncaught error when two saves of the trusted-device list happened at the same time (#17).
- Open-source licences page in Settings.
- Release-signing workflow prepared but **not active** (docs/RELEASE_SIGNING.md).

## Since the first test builds (summary)
Encrypted transfers (TLS 1.3, both devices' keys checked), pairing with a 16-digit code or QR code, approval for every transfer (optional auto-receive from verified devices), SHA-256 check of every file, folders, pause/resume/cancel, a send queue with Retry, resume after a dropped connection or app restart, trusted devices (verified/trusted/blocked/revoked; rename, check code, revoke, remove), real history (names optional), Android hotspot, Bonjour discovery, iPhone support (unsigned, sideload, foreground only).

## Known problems
See docs/AUDIT.md: #3-#16 and #18 are open (for example a damaged trusted-device file loses the list (#5), Android 9 and older save location (#6), and the approval dialog not closing after a timeout (#7)).

## Upgrade
Install over the previous test build (same dev key). Data is kept.

**Locally built 0.8.1 APK (versionCode 1001):** built on the build box, not by GitHub. Its version number is 1001 so it can never clash with GitHub build numbers (currently below 100). Side effect: after installing it, Android refuses to install a GitHub test build (numbers below 1001) over it. Then uninstall first (this removes pairings and history on that phone) or wait for a local/GitHub build above 1001.
