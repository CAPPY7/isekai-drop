# Isekai Drop 0.9.0 (DRAFT release notes, test build)

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
