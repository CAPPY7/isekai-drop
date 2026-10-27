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
  Real release key: last phase only, never committed.
- versionCode = `github.run_number` (via `--build-number`). The arm64 split APK uses
  `--android-project-arg=force-version-code-ignoring-abi=true` so it has the SAME
  versionCode (otherwise it would be 2000+n and block updates to the universal APK).
- Release `latest-build` gets two assets per run: `isekai-drop-android-N.apk`
  (all phones, ~44 MB) and `isekai-drop-android-arm64-N.apk` (smaller, < 25 MB).
- Workflows: `permissions: {}` at top; build jobs `contents: read`; only the
  Android `publish` job has `contents: write`, publishing to prerelease tag `latest-build`.
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
- Trust DB: `trusted_devices.json` in app support dir, schema_version 1,
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
- macOS: sandbox entitlements network.client/server + user-selected read.
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
- Release key: owner holds it; secrets ISEKAI_RELEASE_* are set. Expected release cert SHA-256 55:35:13:AC:F3:A6:A9:F4:34:97:35:FF:A0:29:DD:58:1C:89:68:3A:B9:CD:45:3D:B5:E6:7A:7A:18:61:98:22. Test builds stay on the dev key (5b36eeb0...57c1). Release workflow makes DRAFT releases only; publishing is the owner's call.

## Phase 7d notes (2026-10-27, 0.8.1)
- Root cause of "pairing fails" on 0.7.1: the client sends pair_req only after its user taps "Codes match", but the server dropped connections with no first message after 10 s (audit #4). Fix: client sends `{'t':'pair_hello'}` right after connect; server then waits `pairCompareTimeout` (2 min) for pair_req, only one such wait at a time (second gets pair_denied busy). Never remove pair_hello or make the first-message limit long for everyone. Tests: test/network_fix_test.dart group A.
- Diagnostics log: core/diag_log.dart. Use `engine.recordProblem(kind, message)` / `recordException(what, e)` instead of setting _lastError. `kind` = short class (classifyError), message in plain words. NEVER put file names, device names, peer addresses or keys in entries (test "report has no names..."). Do not swallow network errors silently: record them (resolve failures and per-packet errors are counted, not logged, to keep the 20 slots useful).
- Privacy decision change (owner OK, 2026-10-27): Diagnostics and the copied report show THIS device's own local addresses + interface names. Other devices' names/addresses still never appear there.
- Address ranking: core/net_info.dart `rankLocalNets` (Wi-Fi/hotspot > Ethernet > other; private ranges +; mobile data rmnet/ccmni/pdp, VPN/tunnels, WSL/Hyper-V, docker, 169.254, 100.64/10 excluded; if nothing is left, keep everything). Used by localAddresses (QR, My addresses, hotspot screen) and discovery.
- Discovery: one listen socket on 0.0.0.0:47821 (joins the group on every interface) + one send socket per ranked address (group, 255.255.255.255, subnet broadcast). Interface list re-read every 30 s. Android exact prefixes come from MainActivity `localNets` (do not confuse with `networkInfo` = link speed for Diagnostics).
- Android: MainActivity binds the process to the only Wi-Fi when the default network is not Wi-Fi (Wi-Fi without internet) and unbinds otherwise (NetworkCallback). Status shows in Diagnostics ("Network:"). NOT TESTED on devices.
- Windows firewall: engine/win_firewall.dart parses English `netsh advfirewall firewall show rule name=all dir=in verbose`; non-English output = unknown (never "allowed"). Read-only: the app never changes firewall rules.
- Local APK builds (box): use `--build-number=1001` or higher (above GitHub run numbers, which are below 1000 for a long time; android-release.yml uses run_number*1000 but is release-key signed, a different key anyway). A phone with 1001 refuses lower GitHub builds until uninstalled. Name: releases/isekai-drop-android-arm64-<versionCode>-local.apk.
