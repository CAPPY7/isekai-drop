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
