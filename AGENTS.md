# Notes for the builder (decisions so far)

Scope: ONLY this repo and /workspace/isekai-drop. Re-read ROADMAP.md and this
file before every phase. Stop after each phase and wait for "next".

## Decisions
- Framework: **Flutter 3.47.7 stable / Dart 3.13.5** (matches spec; see docs/TECH_CHOICE.md).
- App name "Isekai Drop", package/bundle ID `com.isujaykumar.isekaidrop`, Dart package `isekaidrop`.
- UI (`lib/ui/`) talks only to `TransferEngine` in `lib/engine/transfer_engine.dart`.
  Phase 2: the only engine is `DemoTransferEngine` (`lib/engine/demo_engine.dart`),
  DEMO data, no networking. Every screen showing it has "DEMO - not a real transfer".
  Records (`lib/engine/models.dart`) have id, createdAt, updatedAt.
- Navigation: `lib/ui/shell.dart`. Phone = bottom bar (Home, Send, Connect,
  History, Settings); desktop (>= 900 px) = side rail. Trusted devices and
  Sending open as pushed pages. Back on a non-Home tab goes to Home.
- Settings: `lib/settings/settings_controller.dart` with shared_preferences,
  schema version 1 + migration hook. Saves theme mode and device name.
- Speed: the DEMO Sending screen shows NO speed or time-left number (only measured
  speeds may ever be shown).
- File picking: `file_selector` (BSD). `file_picker` rejected: its Linux part needs
  `dbus` (MPL-2.0). Drag and drop: `desktop_drop` 0.8.x (0.9 conflicts on cross_file).
- Receive approval for untrusted devices is always on (switch locked).
- Design tokens live in `lib/ui/theme/design_tokens.dart`. Dark theme default.
  Desktop layout at width >= 900.
- Android signing: throwaway DEV keystore `android/app/isekai-drop-dev.jks`
  (alias `isekai-drop-dev`, non-secret password `isekai-drop-dev-only`),
  committed by owner's approval. DEV cert SHA-256:
  `5B:36:EE:B0:22:D1:1E:4C:4A:94:70:D4:D7:CA:E3:87:40:7B:A2:38:F4:BB:19:C0:B2:84:7C:EF:B1:B2:57:C1`.
  Release key (since 0.11.1): see "0.11.1 release key" notes below; never committed.
- versionCode = `github.run_number` (via `--build-number`). The arm64 split APK uses
  `--android-project-arg=force-version-code-ignoring-abi=true` so it has the SAME
  versionCode (otherwise it would be 2000+n and block updates to the universal APK).
- Release `latest-build` (0.10.2+): stable asset names, each build REPLACES
  them via `.github/scripts/latest_build.sh` (gh release upload --clobber, then
  deletes only that platform's other files): `isekai-drop-android-arm64.apk`,
  `isekai-drop-android-universal.apk`, `isekai-drop-ios-unsigned.ipa`,
  `isekai-drop-windows-setup.exe` (0.10.3+: Inno Setup installer from
  `windows/installer/isekai-drop.iss`, built by ISCC on the Windows job;
  the old `isekai-drop-windows-x64.zip` is removed by the stale pattern
  `^isekai-drop-windows-.*$`; the plain folder is a CI artifact only),
  `isekai-drop-macos.dmg` (universal arm64+x86_64, ad-hoc signed with
  `codesign --force --deep -s -`, packed with hdiutil, not notarized;
  Gatekeeper needs right-click > Open, docs/MAC_INSTALL.md; stale pattern
  `^isekai-drop-macos`). Unsigned Windows:
  Smart App Control blocks it; never add a SAC bypass (docs/WINDOWS_INSTALL.md). Build numbers go into the release text, one
  line per platform (`<!--android-->` etc. markers). Concurrency group per
  platform (`publish-latest-build-<platform>`); never one shared group (a
  newer pending job cancels an older pending one).
- Workflows: `permissions: {}` at top; build jobs `contents: read`; only the
  `publish` jobs (Android, iOS, Windows, macOS) have `contents: write`, publishing to
  prerelease tag `latest-build`. Release title is `Latest test build (not a real release)` (no "DEV-signed").
- Action versions pinned: checkout v7.0.1, setup-java v6.1.0,
  flutter-action v2.23.0, upload-artifact v7.0.2, download-artifact v8.0.2,
  action-gh-release v3.0.3.
- iOS: owner decision (Phase 2): iPhone/iOS signing SKIPPED for now. The unsigned
  iOS workflow stays, labelled not installable. Do not raise it again unless asked.
- Repo moved to `iSujaykumar/Isekai-Drop`; the old lowercase URL still redirects.
- `test.txt` (from the capability check) is left untracked and gitignored.
- Token: used only from an environment variable at run time; never written to
  files, remotes, logs or memory. Check at the end of every phase.
- Box note: Flutter is installed at /home/box/tools/flutter (the /opt copy was
  lost once). If missing, reinstall 3.47.7 there.

## Phase 3 decisions
- Engine: `lib/engine/core/` (engine.dart, identity.dart, trust_store.dart,
  frames.dart, safe_files.dart, discovery.dart, jobs.dart, send_source.dart).
  Platform glue: `lib/engine/platform_engine.dart`. Protocol: `docs/PROTOCOL.md`.
- TLS: dart:io SecureSocket (BoringSSL), TLS 1.3. Dart's TLS server rejects
  unknown self-signed client certs, so the server builds a fresh
  SecurityContext per connection that trusts ONLY trusted peers' certs.
  Pairing connections carry no client cert; they may only send `pair_req`.
- Certificates: basic_utils `generateSelfSignedCertificate` with 3650 days.
  (30 years produced "certificate has expired" in TLS - date encoding issue.)
- Pairing code: 16 digits from SHA-256 of both fingerprints (see PROTOCOL.md).
- Ports: TCP 47820 (falls back to a random port if busy), UDP 47821
  discovery, multicast group 239.255.42.99.
- Trust DB: `trusted_devices.json` in app support dir, schema_version 3 (2: verified/revoked; 3 (0.12.0): `always_allow`),
  migrations in `TrustStore.migrate`, atomic writes.
- Android: `file_selector_android` reads WHOLE files into memory, so Android
  uses our own picker in MainActivity.kt (content URIs streamed through
  /proc/self/fd). Received files: temp in cache, then copied to
  Downloads/Isekai Drop via MediaStore (Android 10+), else app external files.
  Permissions: INTERNET, CHANGE_WIFI_MULTICAST_STATE (no runtime prompts).
  No camera permission (no QR scanner yet).
- iOS: NSLocalNetworkUsageDescription added; received files in
  Documents/Received (Files app). Multicast on iOS needs an Apple entitlement
  (paid account) - discovery likely does not work on iOS; typed IP does.
- macOS: sandbox entitlements network.client/server, user-selected read-write, downloads read-write (received files go to Downloads/Isekai Drop). Info.plist already has NSBonjourServices `_isekaidrop._tcp` and NSLocalNetworkUsageDescription.
- Linux CI needs libsecret-1-dev for flutter_secure_storage.
- History stays DEMO (DemoHistory). Pause/resume/folders/auto-receive later.
- QR: NOT done. Options for owner: mobile_scanner (BSD, but Android uses
  Google ML Kit with Google's own terms) or a zxing-based scanner. Ask first.
- Measured on the build box (Linux VM, 8 vCPU, JIT test mode, localhost):
  1 GiB in 61.9 s = 16.6 MB/s, SHA-256 matched, RSS rose ~283 MB during the
  transfer (file not held in memory). Pure-Dart SHA-256 alone = ~85 MB/s,
  and hashing + I/O run on the UI isolate: this is the main speed limit to
  fix in the performance phase (hash/IO in a background isolate or native
  hashing). Loopback speed is NOT Wi-Fi speed.

## Phase 4 decisions
- Owner chose connection options **A + B + C** (2026-10-16). Wi-Fi Direct not built.
- Owner chose **mobile_scanner** (BSD-3) for QR scanning. On Android it
  bundles Google ML Kit barcode-scanning 17.3.0 (closed source, ML Kit terms;
  sends Google usage metrics + device info, not images) - disclosed in
  PRIVACY.md, THIRD_PARTY_NOTICES.md, Settings and the scan explanation.
  Bundled model (not the Play-services "unbundled" one) so scanning works
  offline. Apple platforms use Apple Vision. Windows/Linux: no scanner, they
  show their QR for the phone to scan.
- QR display: qr_flutter (BSD-3).
- Android permissions added (all least-privilege, explained in manifest
  comments): ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE (diagnostics, no prompt),
  CHANGE_WIFI_STATE (hotspot), NEARBY_WIFI_DEVICES neverForLocation (13+),
  ACCESS_FINE/COARSE_LOCATION maxSdkVersion 32 (hotspot on <=12 only),
  CAMERA (QR, asked on first scan).
- Apple: NSCameraUsageDescription (iOS, macOS), macOS camera entitlement,
  macOS NSLocalNetworkUsageDescription.
- Folders: SendSource.relativePath; receiver sanitizeRelativePath +
  ReceiveBatch (unique top folder). Android folder pick = ACTION_OPEN_DOCUMENT_TREE
  walked in Kotlin; received folders via MediaStore RELATIVE_PATH.
  Android folder-name uniqueness checks only files THIS app saved
  (MediaStore query); MediaStore itself renames duplicate file names.
- Pause/resume: protocol messages pause/resume + TCP back-pressure; 6 h idle
  limit while paused. No resume after app close yet.
- TCP_NODELAY on every connection (measured: 500 small files 22.6 s -> 1.5 s
  on loopback).
- Keep screen on during transfers (Android FLAG_KEEP_SCREEN_ON).
- Diagnostics shows no names/addresses. Link speed: Android WifiInfo
  linkSpeed; Windows parses only "Receive rate (Mbps)" from
  `netsh wlan show interfaces`; macOS/Linux: not available.
- Measured on the build box after Phase 4 (loopback, JIT test mode):
  1 GiB 58.4 s = 17.5 MB/s, hash match, RSS +~300 MB peak;
  500 small files (112 KB total) ~1.2-1.5 s.
- APK size: with bundled ML Kit the arm64 APK was 26.67 MB (run 38900295443,
  over the 25 MB limit). Fix: `packaging.jniLibs.useLegacyPackaging = true`
  (native libs compressed in the APK, extracted on install: smaller download,
  a bit more space used after install). Alternative if ever needed: the
  unbundled ML Kit (needs Google Play services + an internet model download).
- 2026-10-16: Owner decided to KEEP Google ML Kit (via mobile_scanner) for
  Android QR scanning, accepting the disclosed Google usage data. Do not
  replace it unless the owner asks.
- 2026-10-16: Owner decided: NO App Store and NO paid Apple Developer
  Program. iOS stays unsigned in CI. Only free options are documented
  (docs/IOS_NOTES.md); never sign or enrol without a new owner decision.

## Phase 5 decisions and findings (2026-10-16)
- iOS: UDP broadcast discovery disabled (needs Apple's multicast entitlement, which needs Apple approval + paid account). Bonjour is used instead (needs NSBonjourServices + NSLocalNetworkUsageDescription).
- Android: we target SDK 36. If targetSdk is ever raised to 37+, add ACCESS_LOCAL_NETWORK (see docs/IOS_NOTES.md source list).
- Linux: Flutter runs Dart on the GTK main thread; a blocking libsecret call (keyring password dialog) freezes the whole app and Dart timeouts cannot fire. Keep the gdbus "Locked" pre-check + sticky identity_fallback.json (chmod 600).
- Linux: some sessions have no XDG user folders; path_provider throws. Keep _desktopReceiveBase fallbacks.
- Windows/Linux cannot advertise Bonjour (browse only); others find them via UDP or IP/QR.

- 2026-10-16 owner decision: publish an UNSIGNED .ipa (ios.yml -> artifact + latest-build release). The owner sideloads it with their own free Apple ID (AltStore/Sideloadly). We never sign it. Label it UNSIGNED, sideload-only, 7-day expiry.

## Phase 6 decisions (2026-10-16)
- Trust store schema 2: verified | trusted (migrated, code not re-checked) | identityChanged | revoked. Revoke keeps the record (blocked); Remove deletes it. Only re-pairing unblocks.
- Pairing from a known device id with a different key shows a red warning (PendingRequest.keyChanged).
- Auto-receive: settings flag AND device must be VERIFIED (engine enforces). Off by default; turning on asks.
- Resume: see docs/PROTOCOL.md "Phase 6". Receiver state = ResumeStore in <receive dir>/.isekai-resume. Never trust partial bytes: whole-file SHA-256 at the end.
- History: HistoryStore (history.json, schema 1). No contents; names optional. The app must never print/log (test enforces: phase6_test "no file names in logs").
- Always `unawaited(socket.done.then(..., onError: ...))` on SecureSockets, otherwise a broken pipe after the peer leaves is an uncaught async error.

## Phase 7 notes (2026-10-16)
- docs/AUDIT.md is the bug list. Open items wait for owner OK (only Crash/Security may be fixed without asking, each with a test).
- Discovery data is untrusted: never let it change trust records or saved addresses (audit #1). Addresses are saved only after a TLS session succeeds. identityChanged is set only on a key mismatch at the last AUTHENTICATED host:port.
- Benchmark log: numbers + conditions only. Refuse paused/resumed runs. CSV cells starting with = + - @ are escaped.
- Release signing: gradle uses the release key only if ISEKAI_RELEASE_KEYSTORE is set (android-release.yml, manual). NEVER set repo secrets or create the key without the owner's explicit OK. Switching keys forces every user to uninstall once.

## Phase 7b notes (2026-10-16, 0.7.1)
- Audit #3-#9 fixed (see docs/AUDIT.md). Tests: test/audit_fix_test.dart, app_test "audit #7", phase6_test "audit #9".
- Connection limits: kMaxHandshakes 8, kMaxSessions 32, 10 s TLS + 10 s first message (engine.dart). Do not raise without a reason. Since 0.8.1 a pairing client's `pair_hello` opens ONE 2-minute wait (see Phase 7d).
- TrustStore.load never throws on bad data: skips entries, writes .bak-<time>, sets loadWarning.
- WRITE_EXTERNAL_STORAGE is declared with maxSdkVersion=28 only (Android 9 and older have no MediaStore.Downloads). Never request it on 10+.
- BonjourBridge.setVisible(false) keeps browsing (advertise flag to native).
- pending_sends.json keeps failed sends (local file paths/URIs). Removed on success, cancel, peer decline, or user Remove.

## Phase 7c notes (2026-10-16, 0.8.0)
- Hashing: core/bg_hasher.dart. Files >= 1 MiB use a background isolate; ALWAYS `await hasher.add()` (back-pressure, max 8 MiB queued). Small files hash inline.
- Never `await sock.flush()` directly in the engine: use `_flushOrClosed(sock)` (plain flush can hang after the peer destroyed the socket, audit #19).
- Resume id is v2 (name + size + modification time).
- Android incoming/partials: no-backup folder (androidIncomingDir). Free-space check: free_space.dart (null = unknown, no check), margin kFreeSpaceMargin 64 MiB.
- Pause/queue tests use a throttled source: do not make them depend on machine speed.
- (Superseded 2026-10-30: the earlier release key 55:35:13:AC... was LOST; replaced in 0.11.1, see below.)

## Phase 7d notes (2026-10-27, 0.8.1)
- Root cause of "pairing fails" on 0.7.1: the client sends pair_req only after its user taps "Codes match", but the server dropped connections with no first message after 10 s (audit #4). Fix: client sends `{'t':'pair_hello'}` right after connect; server then waits `pairCompareTimeout` (2 min) for pair_req, only one such wait at a time (second gets pair_denied busy). Never remove pair_hello or make the first-message limit long for everyone. Tests: test/network_fix_test.dart group A.
- Diagnostics log: core/diag_log.dart. Use `engine.recordProblem(kind, message)` / `recordException(what, e)` instead of setting _lastError. `kind` = short class (classifyError), message in plain words. NEVER put file names, device names, peer addresses or keys in entries (test "report has no names..."). Do not swallow network errors silently: record them (resolve failures and per-packet errors are counted, not logged, to keep the 20 slots useful).
- Privacy decision change (owner OK, 2026-10-27): Diagnostics and the copied report show THIS device's own local addresses + interface names. Other devices' names/addresses still never appear there.
- Address ranking: core/net_info.dart `rankLocalNets` (Wi-Fi/hotspot > Ethernet > other; private ranges +; mobile data rmnet/ccmni/pdp, VPN/tunnels, WSL/Hyper-V, docker, 169.254, 100.64/10 excluded; if nothing is left, keep everything). Used by localAddresses (QR, My addresses, hotspot screen) and discovery.
- Discovery: one listen socket on 0.0.0.0:47821 (joins the group on every interface) + one send socket per ranked address (group, 255.255.255.255, subnet broadcast). Interface list re-read every 30 s. Android exact prefixes come from MainActivity `localNets` (do not confuse with `networkInfo` = link speed for Diagnostics).
- Android: MainActivity binds the process to the only Wi-Fi when the default network is not Wi-Fi (Wi-Fi without internet) and unbinds otherwise (NetworkCallback). Status shows in Diagnostics ("Network:"). NOT TESTED on devices.
- Windows firewall: engine/win_firewall.dart parses English `netsh advfirewall firewall show rule name=all dir=in verbose`; non-English output = unknown (never "allowed"). Read-only: the app never changes firewall rules.
- Local APK builds (box): use `--build-number=1001` or higher (above GitHub run numbers, which are below 1000 for a long time; android-release.yml uses run_number*1000 but is release-key signed, a different key anyway). A phone with 1001 refuses lower GitHub builds until uninstalled. Name: releases/isekai-drop-android-arm64-<versionCode>-local.apk.

## Phase 7e notes (2026-10-30, 0.9.0)
- Core flow first: discover -> pair -> send. Removed the app-made local-only hotspot (MainActivity hotspot channel methods, platform_engine HotspotPermission/startAppHotspot, hotspot_screen.dart, guideAppHotspot, NEARBY_WIFI_DEVICES / ACCESS_*_LOCATION / CHANGE_WIFI_STATE permissions). Reason: fragile, permission-heavy, no internet, not joinable by iPhone. Do not bring it back without real-device tests. `networkInfo.hotspotByApp` is always false (kept for the Diagnostics map shape).
- "Search this network": engine.scanNetwork() -> probe(host, port) for each address of the first 3 ranked local nets (net_info.dart `scanTargets`: private IPv4 only, /24 max, no network/broadcast/own IP), 64 in parallel, 1.5 s connect timeout. The probe is TLS WITHOUT a client cert and sends `{'t':'info'}` as the first message; the server answers device_id/name/platform/port only when `visible()` and closes. Found devices are kept 5 min (`_keepUntil`) against pruning. Engines built with `enableDiscovery: false` (tests) never scan (widget tests would otherwise probe the real network and never settle).
- discovery.dart: `_replyTo` sends one unicast announcement back to a sender (max once per 10 s per address).
- pair_req carries the client's listening `port`; the server stores it (`addTrusted(port:)`), so the responder can send back (test phase9 "the device that ACCEPTED pairing can send back").
- Errors: pairing_flow.dart `showPairingProblem` dialog; message = classifyError/explainErrorClass + checklist. Never go back to a snack bar for connection errors.
- engine.stop(): waits for sessions (2 s) and for background saves (`_bg`, `_keep()`); use `_keep(future)` instead of `unawaited` for trust/history writes.
- Real e2e on the box (no emulator: /dev/kvm faults in vmx_vcpu_create on this box, see dmesg; the ACL `setfacl -m u:box:rw /dev/kvm` also resets):
  ```
  sudo ip netns add isekai-e2e; sudo ip link add ie2e-h type veth peer name ie2e-p
  sudo ip link set ie2e-p netns isekai-e2e; sudo ip addr add 10.77.0.1/24 dev ie2e-h; sudo ip link set ie2e-h up
  sudo ip netns exec isekai-e2e ip addr add 10.77.0.2/24 dev ie2e-p; sudo ip netns exec isekai-e2e ip link set ie2e-p up
  sudo ip netns exec isekai-e2e ip link set lo up
  sudo ip netns exec isekai-e2e sudo -u box env HOME=/home/box PATH=$PATH E2E_PEER=1 E2E_DIR=/tmp/e2e E2E_EXPECT=to-peer.bin \
    E2E_SEND_HOST=10.77.0.1 E2E_SEND_PORT=47830 E2E_SEND_FILE=/tmp/e2e-files/to-client.bin flutter test --no-pub test/e2e_peer_test.dart &
  E2E_CLIENT=1 E2E_DIR=/tmp/e2e-client E2E_PORT=47830 E2E_SEND_FILE=/tmp/e2e-files/to-peer.bin flutter test --no-pub test/e2e_client_test.dart
  sudo ip netns del isekai-e2e
  ```
  Use `--no-pub` inside the namespace (no DNS there). The peer test can also serve an emulator (10.0.2.2:47820, `adb forward`).

## Phase 7f notes (2026-10-30, 0.9.1)
- "Sending fails at 0 B although Verified" (0.9.0): (1) Identity.generate used notBefore = now; a peer with a slower clock fails the mTLS client-cert check (reproduced: test/one_tap_test "clock skew"). Keep notBefore = now - 2 days. Existing identities are not regenerated. (2) Android read picked files via /proc/self/fd re-open; replaced by MainActivity openRead/readChunk/closeRead (ContentResolver stream, own single thread `readIo`) + send_source.dart chunkedPlatformRead. Never go back to fd paths.
- Send errors are stage-specific (_SendStage connect/answer/transfer, read_file); diag kinds `send_<stage>_<class>`, `receive_write_<class>`; the receiver sends `{'t':'error','reason':'write_failed'}` when it cannot save. Never show the generic "could not reach" text again for a non-network failure.
- _runSend tries all known addresses (given, live nearby with the same id, lastHost).
- Pairing is TOFU: pairing gives TRUSTED on both sides; VERIFIED only via QR or code check. Never downgrade a Verified device on re-pair (done at the call sites, not in TrustStore.addTrusted). Auto-receive stays Verified-only.
- `pair_req.offer` + `_preApproved` (one-time, fingerprint + tid, `preApprovalTtl` 3 min) = one question for "pair and send". engine.sendToNearby / quickPair; UI pairing_flow.dart sendToNearbyFlow / startPairingFlow(peerName:), shell.dart "Accept NAME?" dialog.
- e2e: default client mode is one-tap (`sendToNearby` to the unpaired peer); `E2E_MODE=classic` for the old path; `E2E_SEND_FILE2` (client) + `E2E_EXPECT2` (peer) add a send after pairing.

## Phase 7g notes (2026-10-30, 0.9.2)
- Speed: Dart package:crypto SHA-256 (~117 MB/s on x86 box) is the slowest stage. Android uses native hashing: MainActivity "isekai_drop/android_read" (openRead/readChunk returns bytes + running digest at EOF/readDigest/closeRead) and "isekai_drop/android_hash" (hashFile), both on background TaskQueues. Sources with `hashesItself` use _NoHasher; engine `fileDigest` hook makes the receiver hash the closed temp file natively. Never drop the integrity check.
- kAndroidReadChunk 4 MiB, chunkedPlatformRead ahead=2 (keep reads serial on the Kotlin side). kDataFrameBytes 256 KiB < maxFrameLength 2 MiB.
- Receive writes stay direct (`await out.writeFrom`): an overlapped writer was measured slower; do not re-add without a new measurement.
- WifiLock HIGH_PERF only on SDK < 34 (API 34+ maps it to LOW_LATENCY, which may reduce throughput), held while keepScreenOn is on.
- Bench: tool/bench_stages.dart, tool/bench/netns_run.sh (REPO=, E2E_NATIVE_HASH=1, delay arg), tool/bench/delay_proxy.py. The box is shared: interleave A/B runs.

## Phase 7h notes (2026-10-30, 0.10.0 Fast direct)
- Engine (lib/engine/direct/, engine.dart): over the trusted session `direct_req` -> `direct_ok{link, port}` / `direct_no{reason}` -> `direct_end`. Automatic only Android<->Android and >= kDirectMinBytes (64 MiB). Every failure falls back to the router path with job.routeNote and diag `direct_<stage>_<code>`. Never make the router path depend on Fast direct.
- The direct address is NEVER saved as lastHost. A link joined from a Fast direct QR records `_directPeer` (host, port, fingerprint), tried first in _addressesFor for that device, cleared on leave/join_lost.
- Android: DirectLinks.kt on channel "isekai_drop/direct" (caps, permissionState, requestPermission, host, stopHost, join, leave, openAppSettings; events host_stopped / join_lost). File-level @Suppress("DEPRECATION"); guard API 26 (LOHS) / 29 (P2P config, specifier). MainActivity.evaluateBinding must not rebind while Fast direct owns the process network.
- Manifest: NEARBY_WIFI_DEVICES neverForLocation; FINE/COARSE location maxSdkVersion 32; wifi.direct feature not required.
- PCs join with system tools (wifi_join.dart: netsh temp profile deleted after use, nmcli, networksetup); log lines are redacted (password -> ***). Windows hotspot via PowerShell + WinRT tethering manager (windowsHotspotScript) - NOT TESTED on a real PC.
- DirectQr is `isekaidrop:direct?v=1&k&s&w&h&p&f&n[&m]` (no "//"). Scanner accepts PairingQr, DirectQr, WIFI: codes.
- UI tests must create the engine inside `tester.runAsync` (real file IO), and must not pumpAndSettle while a spinner is showing.
- Local checks that work on the box: `flutter build apk --debug --target-platform android-arm64`, `./gradlew :app:lintDebug` (JDK17 + SDK in /home/box/ls-tools). No emulator (no /dev/kvm access).

## Phase 7i notes (2026-10-30, 0.10.1 Speed test + data lane)
- File data uses a TLS data lane in a background isolate (lib/engine/core/lane.dart): offer carries `lanes: 1`, the receiver answers port + one-time token, mTLS with the paired certs. Any lane failure falls back to in-band frames on the main connection. `useLanes` (Node/engine) and `ISEKAI_BENCH_LANES=0` turn it off for A/B.
- Lane sinks end on a byte count sent over control (`lane_end` / `sinkEnd(n)`); the client closes its lane only after the server's result. Closing right after sending stalled ~1 in 5 runs (15-28 s). Do not go back.
- Speed test: session message `speed` -> `speed_ok`; steps `lane{raw}`, `main`/`main_end`, `local`, `bye`. Core in lib/engine/core/speed_test.dart (SpeedProbes, SpeedReport.toText). The report must never contain device names, file names, SSIDs or IPs (speed_engine_test checks). Android probes: MainActivity `speedWriteDownloads` (always deletes), `networkInfo` tx/rx, DirectLinks `linkNow`.
- Widget tests must not run a real speed test (real sockets + fake clock hang); the engine test covers the run.
- Docs: docs/SPEED.md has the box numbers.

## Phase 7j notes (2026-10-30, 0.10.2 network bottleneck)
- Owner Speed test on 0.10.1: raw TCP 6.9, TLS 7.1/8.8 MB/s vs disk/hash 121-312 MB/s -> network. Suspects: MCC (group made with BAND_5GHZ, not on STA 5240), no Wi-Fi lock on Android 14+, routing.
- DirectLinks.host(): setGroupOperatingFrequency(STA MHz) when the STA is on non-DFS 5 GHz (5170-5250, 5735-5895); failure -> freq 0 (band) -> AUTO -> LOHS. linkNow adds staMhz, and with a group up mhz/role/iface from requestGroupInfo.
- MainActivity setAwake(reason, on): reasons "job" (keepScreenOn) and "speed" (transferAwake). WifiLock LOW_LATENCY on 34+ (only works screen on + foreground + STA connected), HIGH_PERF older; PARTIAL_WAKE_LOCK "isekaidrop:transfer" 2 h timeout. Locks do not control p2p power save (driver).
- NativeSpeed.kt: Java NIO raw TCP sink/sender for the Speed test (nativeSinkStart/End, nativeSend), token + index byte per stream like lanes.
- Lanes: offer `lane_streams`, answer `streams` (clamped 1..8, default kLaneStreams 4), 1 MiB stripes. Client acks a block only after its flush completes (drain() = handed to the socket); acking at add() made phase6 resume-after-drop flaky.
- Speed test caps in speed_ok: `streams`, `native`. Older peers skip the new rows with a note. Report shows interface name + kind only (interfaceKind), never IPs.
- Do not force SO_RCVBUF/SO_SNDBUF smaller: Linux/Android autotuning is disabled once set; LAN BDP is small anyway.
- Lane connect has an overall timeout (2x connect timeout + 2 s, incl. TLS handshakes): a receiver cancelling while 4 streams were connecting left the sender "waiting" forever (phase6 "cancel discards" under CPU load). The lane receiver also keeps what arrived when a stream is reset (SocketException/TlsException).
- phase6 drop tests wait with `receiverDone(b)` (receiver job no longer active): the receiver gives the lane up to 5 s after the main connection drops, slower than `settle()` on a loaded CI machine.

## 2026-10-30: repo PUBLIC, Windows unsigned (owner decisions)
- CAPPY7/isekai-drop is public. Do not write "private repo / log in to download" in docs.
- The committed dev keystore is therefore public (AUDIT #35): recommend release-key signing once the owner re-adds the 4 secrets; do not change signing without that.
- Windows stays unsigned (no paid signing, Store or SignPath for now). Docs: SmartScreen > More info > Run anyway; Smart App Control may block it -> turn SAC off. Never add a SAC bypass.

## Phase 7l notes (2026-10-30, 0.11.0 UI spec + Windows speed)
- UI spec: docs/UI_SPEC_0.11.md. Tokens in lib/ui/theme/design_tokens.dart (IdSpacing, IdRadii, IdLayout.minTouchTarget/maxContentWidth, IdStatusColors). Empty states use `EmptyLine` (one row), not `StateMessage` cards.
- Onboarding: `settings.onboardingDone` (pref `onboarding_done`); IsekaiDropApp(showOnboarding:) defaults to off under FLUTTER_TEST so old widget tests see the shell.
- NetworkStatusLine does not load under FLUTTER_TEST unless `load:` is given (HomeScreen networkLoad).
- FilesScreen(initialFiles:) is @visibleForTesting (pickers need a platform).
- shell_nav.dart `shellTabRequest` switches tabs from pushed screens (Send more).
- Transfer screen: tests must create the engine in setUp (real file IO inside testWidgets hangs).
- Route modes: settings.routeMode 'auto' | 'router' | 'direct'; engine `routeMode` null = 0.10 behaviour. RouteStats (lib/engine/direct/route_choice.dart, route_stats.json) stores only MB/s per device id and route; decision in autoRouteSkip(); reasons 'auto_*' in explainDirectError.
- Windows link: lib/engine/windows_link.dart parses netsh wlan show interfaces (never SSID/BSSID) and powercfg; read-only, nothing is changed on the PC.
- PendingRequest has no device id, so per-device "Always allow" needs an engine change (not done).

## 0.11.1 release key (2026-10-30)
- Owner lost the old release-key backup and approved a NEW key. Alias `isekai-drop`, PKCS12 RSA 4096, CN=Isekai Drop.
- NEW release cert SHA-256: `81:31:62:3F:17:C7:11:DC:42:32:2F:2B:A9:B6:42:6E:DD:29:8D:E2:7F:78:3F:FD:BD:30:D0:4E:30:A9:04:9B` (`8131623f17c711dc42322f2ba9b6426edd298de27f783ffdbd30d04e30a9049b`). The old 55:35:13:AC... key is gone; never expect it.
- Secrets on CAPPY7/isekai-drop: ISEKAI_RELEASE_KEYSTORE_B64, ISEKAI_RELEASE_STORE_PASSWORD, ISEKAI_RELEASE_KEY_PASSWORD, ISEKAI_RELEASE_KEY_ALIAS. Never print, log or commit their values; set them only from files/stdin.
- android.yml signs main builds + latest-build with the release key when all 4 secrets exist (step "Check which key signed the APKs" fails on a mismatch), else falls back to the DEV key with a `::warning`. The latest-build Android line says "release key" / "dev key".
- Dev key (5b36eeb0...b257c1) = local/debug and fallback only. Upgrading from a dev-signed build needs ONE uninstall.
- AUDIT #35 is resolved for anyone who has installed a 0.11.1+ release-signed APK.

## macOS latest-build dmg (2026-11-22)
- macos.yml now ad-hoc signs the release .app, checks `lipo` for arm64+x86_64, packs `isekai-drop-macos.dmg`, and the publish job uploads it to latest-build on main pushes only (stable name, clobber + stale-pattern cleanup).
- No paid Apple account and no notarization. Running on a real Mac: NOT TESTED.

## 0.11.2 identity subject (2026-10-30)
- Certificates up to 0.11.1 all had CN "Isekai Drop device". BoringSSL picks a self-signed client cert from the server's trusted certs BY SUBJECT and needs an exact match, so a receiver with 2+ trusted devices accepted only one. Never give two identities the same subject again.
- Since 0.11.2 CN = "Isekai Drop <deviceId>", O = Isekai Drop. platform_engine `_loadIdentity` renews old identities (same deviceId) and stores them where the old one was; keeps the old one if storing fails. `Identity.generate(legacySubject: true)` is for tests only.
- The receiver side cannot work around old certs (Dart has no server onBadCertificate); senders must be on 0.11.2.

## Phase A / 0.11.2 security decisions (2026-11-22)
- Build plan: 6 phases A-F (0.11.2 ... 0.12.2), one commit per item "<id>: <text>", failing test first, AUDIT rows #37+. Stop after each phase and wait for "next".
- Identity (A1): `lib/engine/core/identity_loader.dart`. A new key ONLY when the key store returns null. A throw is retried once after `kIdentityRetryDelay` (2 s), then `IdentityUnreadable` -> `StartupErrorApp` (Try again / Create a new key, asks first; `resetIdentity()` in platform_engine). Never silently replace an identity. Android: allowBackup=false + res/xml backup_rules + data_extraction_rules (exclude all).
- Discovery (A2): `parseAnnouncement` / `validAnnouncementFields` in discovery.dart; `kMaxNearby` 64, `kMaxNewIdsPerSource` 5 per `kNewIdsWindow` 10 s; paired devices bypass the limits; nearby notifications max 4/s. `cleanDeviceName` lives in core/names.dart (re-exported by engine.dart); settings uses `cleanSystemName`.
- Pairing (A3): `kPairHelloWait` 45 s, `kMaxPairHelloWaits` 2 (one per source address), `kPairCooldown` 60 s by key fingerprint (reason "cooldown"). Blocked keys: `BlockedStore` (`blocked_devices.json`, schema_version 1, atomic), refused with reason "declined" before any dialog. kMaxHandshakes/kMaxSessions unchanged.
- Key files (A4/A5): `secureDelete` overwrites then truncates; `writePrivateFile` (core/private_file.dart) for every fallback write.
- Errors (A6): `lib/startup_guard.dart`; entries `uncaught_<plainErrorClass>`, never the error message or stack. Engine takes `diagLog:` so app and engine share one log.

## Phase B / 0.11.3 CI decisions (2026-11-22)
- `.github/workflows/ci.yml` is the one test job (flutter analyze + flutter test, ubuntu, Flutter 3.47.7). Triggers: push main, pull_request, workflow_dispatch, workflow_call. Job name `flutter analyze + flutter test` = the required status check in docs/BRANCH_PROTECTION.md (do not rename it without updating that doc).
- Every platform workflow has job `ci: uses: ./.github/workflows/ci.yml` (permissions contents: read). Publish jobs: `needs: [build, ci]`. linux.yml build: `needs: ci`. android.yml build has NO analyze/test steps any more (they run in ci); its signing steps are unchanged and hash-checked by test/ci_workflows_test.dart.
- All remote actions are pinned `owner/name@<40-hex SHA> # vX.Y.Z`. New or updated actions: look up the SHA from the action's own tag (git ref API, dereference annotated tags; cross-check with the commits API) and update the expected table in test/ci_workflows_test.dart. Dependabot (weekly, minor/patch grouped) keeps pins and comments updated via PRs; never auto-merge.
- Repo settings (branch protection) are the owner's; the builder never changes them.
- Local workflow lint: actionlint binary in .tools/ (listed in .git/info/exclude), run with `-shellcheck= -pyflakes=`.

## Phase C / 0.11.4 send-and-receive decisions (2026-11-22)
- C1: `DirectSaver`/`DirectSaveTarget` (core/direct_save.dart) and `AndroidMediaSaver` (android_media.dart) <-> Kotlin `MediaWriter.kt` on channel `isekai_drop/media` (serial background task queue; Kotlin owns the file descriptor, Dart never reopens it). Engine params `directSaver:` and `finalizeCopies:` (Android: free space 2x in the copy fallback). Lane isolate writes through `BackgroundIsolateBinaryMessenger` (`DirectWriterSpec`). Resume keeps `partial_direct` (content URI) in the state; `ResumeStore(deleteDirect:)` deletes it. After one direct-write failure the engine uses the copy path until restart (`_directBroken`).
- C2: `sendToNearby(..., confirmCode:)` / `forgetAndPairAgain(..., confirmCode:)`; without a confirmCode an unpaired send is refused. `pair_req.offer.names` only when QR-verified or `codeCompared`. Cancel = `PairingCancelled` (nothing sent, nothing saved). UI: `showCodeCheckDialog`, `runCodeCheckedSend` (pairing_flow.dart). DisplayTrust.unknown label "New device".
- C3: pickers return `PickResult` (files + `SkippedFiles`); never drop files silently.
- C4: Kotlin takes persistable read permission on pick; engine `releaseSourceGrants:` gives it back when no saved or running send needs it (`AndroidUriGrants`).
- C5: `offerSizesOk` (8 TiB / 16 TiB, no overflow); `ResumeStore.create(..., freeBytes:)` keeps <= 5 states per device and partial data <= free/2.
- C6: `UiEnv` + `IsekaiDropApp(showOnboarding/animations/readPlatform)` replace FLUTTER_TEST checks (tests pass them). `requirePeerCertificate`. `kMaxPeerPause` 30 min (`TransferJob.peerPauseLimit`, engine `peerPauseLimit` for tests). MainActivity is a `FlutterFragmentActivity` using the Activity Result API; a picker result that arrives after recreation is kept (`takeLostPick`). Empty `catch (_) {}` only for pure cleanup; file/channel work calls `noteError` (core/error_note.dart -> engine.recordException(quiet: true)); test/c6_empty_catch_test.dart enforces it.
- Local Android compile check: `.tools/kbuild.sh` (SDK, Gradle cache in .tools/, git-excluded).

## Phase D / 0.12.0 daily-use decisions (2026-11-22)
- D1: MainActivity intent-filters ACTION_SEND / ACTION_SEND_MULTIPLE (*/*). Shared URIs are kept in MainActivity until Dart calls `takeShared` on `isekai_drop/android` (AppShell checks at start and on every resume; no push from Kotlin because bonjour.dart owns that channel's Dart handler). Only `content://` links from OTHER apps are accepted (file:// and our own `com.isujaykumar.isekaidrop.*` authority are refused, in Kotlin and in `parseSharedFiles`). `sharedFilesInbox` + `deliverShared` (shell_nav.dart) hand them to FilesScreen ("Shared from another app").
- D2: `TransferService.kt` (foreground service, type dataSync, not exported, START_NOT_STICKY, no locks of its own) driven by `TransferServiceBridge` (lib/engine/transfer_service.dart) on channel `isekai_drop/service` ("update" {sending, receiving, requests, done, total} / "stop"; native -> Dart "cancel"). Counts and measured bytes only, never names. Progress updates at most 1/s. Incoming-request notice only while the app is not on screen. If Android refuses the start (background start on 12+) the app goes on without it. POST_NOTIFICATIONS asked once at the first transfer after our own dialog (`maybeAskNotifications`, settings key `notifications_asked`, no settings schema change).
- D3: `PendingRequest.deviceId/peerVerified/alwaysAllow`; `TrustedDevice.alwaysAllow` is forced false unless status is verified (also when read from the file); `TrustStore.setAlwaysAllow`, engine `setAlwaysAllow`. Auto-receive = one-tap pre-approval, or VERIFIED and (always_allow or the global auto-receive switch).
- D4: `file_actions.dart` builds commands with pure functions (`openFileCommand`, `showInFolderCommand`, `openFolderCommand`; absolute paths only, never through a shell). `savedFileActions` is the instance screens use (tests replace it). Android: `openReceived` finds the MediaStore item by RELATIVE_PATH + DISPLAY_NAME (Android 10+) or uses `androidx.core.content.FileProvider` (`${applicationId}.files`, res/xml/file_paths.xml, Android 9-); `openReceiveFolder` opens Download/Isekai Drop in the Files app, else the Downloads list.

## Phase E / 0.12.1 decisions (2026-11-22)
- E1: `lib/engine/core/text_message.dart` (`kMaxTextBytes` 8192, `textBodyProblem`, `webLinkIn` = whole text is one http/https link, `TextSendException`, `explainTextError`). Engine `sendText(dev, body)` (trusted devices only, `_connectTrusted`), server `case 'text'` -> `PendingRequest(kind: RequestKind.text, textBody)`, ALWAYS asked (no auto-accept, also not with always_allow / auto-receive). History: message 'Text received', 0 files, never the body. Never log the body. UI: `showReceivedText` (lib/ui/received_text.dart), Send screen SegmentedButton 'send-mode'. "Open link": `savedFileActions.openLink` (Android Intent ACTION_VIEW + CATEGORY_BROWSABLE, http/https only; desktops via `openLinkCommand`; iOS none).
- E2: gen-l10n (`generate: true`, l10n.yaml, lib/l10n/*.arb, generated app_localizations*.dart are committed). Screens use `tr(context)` from lib/l10n/l10n.dart (English when no localizations, e.g. bare MaterialApp in tests). Template app_en.arb; app_hi.arb / app_kn.arb carry "@@x-review" and "NEEDS NATIVE-SPEAKER REVIEW" on every key - never claim they were reviewed. New user-visible text in the moved screens must go into the .arb files (test/e2_languages_test.dart scans them). Settings key `language` (system/en/hi/kn), settings schema 4. Engine/diagnostic texts and several screens are still English (see ROADMAP).
- E3: `AboutScreen` (lib/ui/screens/about_screen.dart); build number = Flutter's `appBuildNumber` constant via `currentBuildNumber()` (platform_engine.dart). No workflow change (android.yml must not be edited).
