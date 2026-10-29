# Roadmap

## Phase 1 - Project, build pipeline, tech decision, UI plan
- [x] Tech choice researched (Flutter 3.47.7) - docs/TECH_CHOICE.md
- [x] Architecture, connection options, build/install docs
- [x] Flutter project (app name "Isekai Drop", ID com.isujaykumar.isekaidrop)
- [x] One screen "Isekai Drop - Phase 1 works", dark theme, design tokens
- [x] Original placeholder icon
- [x] UI separated from transfer-engine interface (stub only)
- [x] Lint (flutter analyze) and passing tests
- [x] .gitignore for builds, secrets, release keys
- [x] Throwaway DEV signing key; versionCode = GitHub run number
- [x] GitHub Actions: Android, Windows, macOS, Linux, iOS (unsigned attempt)
- [x] README, ROADMAP, AGENTS, PRIVACY, THIRD_PARTY_NOTICES
- [x] Owner installs the APK on Android and confirms (owner said "next")
- [x] DEV key fingerprint identical over two consecutive builds (runs 1 and 2: 5b36ee…57c1)
- [x] Owner chose: iOS signing SKIPPED for now (unsigned compile-only build stays)

## Phase 2 - All UI screens with DEMO data (no networking)
- [x] Design tokens; dark / light / system theme setting, saved on the device
- [x] Separate phone (bottom bar) and desktop (side rail) layouts
- [x] Home, File Selection, Sending, Connect Device, Trusted Devices, History, Settings
- [x] Real system file picker (multi-select) with total size; desktop drag-and-drop
- [x] DEMO data engine behind the TransferEngine interface, labelled "DEMO - not a real transfer"
- [x] Empty, loading and error states; confirm before revoke / clear
- [x] Accessibility labels, 48 px touch targets, Back returns to Home
- [x] Widget tests: theme switch, navigation, revoke confirmation (+ error, clear history)
- [x] Extra smaller arm64 APK (under 25 MB) for chat attachment
- [x] Owner tests the screens on Android (owner said "next")

## Phase 3 - Secure pairing and direct transfer (same network first)
- [x] Per-install identity (ECDSA P-256 + self-signed cert), key in secure storage (fallback noted)
- [x] Discovery (UDP multicast/broadcast) + typed IP/port fallback
- [ ] QR pairing - NOT included: needs a camera/QR library; owner must approve one
- [x] Pairing by 16-digit verification code with approval on both devices
- [x] Mutual TLS 1.3 sessions, peer key pinned by fingerprint; unknown/revoked keys fail TLS
- [x] Identity change detected -> blocked until revoke + pair again
- [x] Chunked streaming, temp .part files, SHA-256 verify before finalising, safe names, no overwrite
- [x] Recipient approval for every incoming transfer; unknown devices cannot send
- [x] Real engine on Home, Connect, Send, Sending/Receiving, Trusted Devices (History still DEMO)
- [x] Measured speed only
- [x] Tests: pairing, hashing, path traversal, tampered chunk, unknown device, revoke, identity change
- [x] Loopback benchmark on the build computer recorded (AGENTS.md)
- [ ] Owner tests on two real devices

## Phase 4 - No router: Android <-> Windows and Android <-> macOS
- [x] Owner chose connection options A + B + C (docs/CONNECTION_OPTIONS.md)
- [x] A: phone-hotspot guide; B: Windows Mobile Hotspot guide (in app)
- [x] C: Android app-made local-only hotspot (permission explained first)
- [x] Guides: local network permission / firewall, keep app open, not found
- [x] QR pairing with mobile_scanner (owner decision); QR shows key fingerprint
- [x] Folder sending with structure kept; multi-file queue (one send at a time)
- [x] Pause / resume / cancel while the app stays open (both sides)
- [x] Diagnostics screen: method, link speed (Android/Windows), last error
- [x] Loopback tests: folders, hostile paths, pause/resume, queue, QR
- [x] Manual test plan: docs/TEST_PLAN_PHASE4.md
- [ ] Owner runs the manual test plan and records numbers

## Phase 5 - iPhone/iPad interoperability and platform fallbacks
- [x] Apple rules researched with real sources: docs/IOS_NOTES.md
- [x] Bonjour `_isekaidrop._tcp` (iOS/macOS advertise+browse, Android NSD advertise+browse, Windows/Linux browse only)
- [x] iOS: UDP discovery off (needs Apple multicast entitlement), IP/QR fallback, Files app (Documents), share sheet, foreground-only note
- [x] Linux build runs headless under xvfb; keyring + no-keyring fallback; XDG-folder fallback
- [ ] iOS runtime on a real iPhone: NOT TESTED (no Mac/iPhone; owner declined paid program, no signing by us)
- [ ] iOS signing: owner decision = NO App Store, NO paid program (2026-10-16)

## Phase 6 - Trusted devices, history, queues, integrity, resume
- [x] Trusted devices: Verified / Trusted / Unknown / Identity changed / Revoked; rename, Check code (re-verify), revoke, remove (all destructive actions ask)
- [x] Identity change blocks until paired again (with key-changed warning); revoked devices rejected by TLS
- [x] Send queue, clear errors, Retry, Clear finished
- [x] Resume: authenticated (sender key + transfer id), offset-based, whole file re-hashed; survives network drop and app restart (receiver state on disk, 7-day expiry)
- [x] Real persisted History (no contents; names optional, hide/delete names; clear asks); DEMO history removed
- [x] Settings: receive on/off, auto-receive (verified only, off by default, confirm), history names, visibility
- [x] Versioned migrations: trust 1->2, settings 1->2, history 0->1; tests (test/phase6_test.dart, app_test.dart)
- [ ] On-device tests (NOT TESTED on phones yet)

## Phase 7 - Benchmark against LocalSend (identical conditions)
- [x] Plan, printable steps, results template (docs/BENCHMARK_*.md); all results NOT TESTED
- [x] In-app benchmark log (measured numbers + conditions only, median/min/max, CSV export)
- [x] Code audit: docs/AUDIT.md (18 items); Security #1, #2 and Crash #17 fixed, each with a test
- [x] docs/ACCEPTANCE.md (7 PASS automated/box, 0 FAIL, 4 NOT TESTED)
- [x] RELEASE_NOTES.md draft, THIRD_PARTY_NOTICES regenerated (77 packages), README limits + friends/family steps
- [x] Release-signing workflow prepared (manual only, secrets not set): docs/RELEASE_SIGNING.md
- [ ] Owner runs the benchmark (docs/BENCHMARK_STEPS.md) -> measured results table
- [ ] Owner picks a signing option and adds secrets

## Phase 7b - Audit fixes before the release key (0.7.1)
- [x] Audit #3-#9 fixed, one commit + test each (docs/AUDIT.md)
- [ ] Devices: Android 9 Downloads, Visible off browsing, Interrupted sends retry (NOT TESTED)

## Phase 7c - Minor audit fixes (0.8.0)
- [x] Audit #10-#16, #18 fixed or improved, plus #19 (hang) found and fixed; tests for each
- [x] Measured loopback speed and memory before/after (docs/AUDIT.md #10, #18)
- [x] Release key created by the owner
- [ ] Release workflow run (draft only): NOT run yet (an earlier tick here was wrong; CI was blocked, see AGENTS.md)
- [ ] Phone measurements (speed, memory, UI smoothness) NOT TESTED

## Phase 7d - Real-device connection fixes (0.8.1)
Owner report on 0.7.1: devices do not find each other, pairing fails, sending fails (Android-Android, Android-PC; home Wi-Fi and app hotspot).
- [x] A: pairing start message (pair_hello) + 2-minute wait while the user compares; clearer dialog (AUDIT #20)
- [x] B: Diagnostics problem log (last 20), counters, multicast lock result, NSD error codes, Copy report (#21)
- [x] C: Android binds to a Wi-Fi without internet; discovery per network incl. subnet broadcast (#22)
- [x] D: address ranking for QR / My addresses (no mobile data / VPN) (#23)
- [x] E: Windows Firewall read-only check + help (#24)
- [x] Local release arm64 APK, versionCode 1001 (dev key)
- [ ] Owner tests on phones + PC; send the Diagnostics "Copy report" if it still fails (NOT TESTED)

## Phase 7e - Make the core flow work (0.9.0)
Owner: "This doesn't work... decide what's best, remove or add things and make this app work".
- [x] Search this network (direct TLS probe of the local /24) + auto-search on Connect (AUDIT #25)
- [x] Unicast reply to discovery (#26); responder saves the peer port (#27)
- [x] Error dialogs with reason + firewall hint (#28)
- [x] Removed the app-made hotspot and its location/nearby permissions (#29)
- [x] Real two-network-stack e2e (netns) on the box; env-gated tests test/e2e_peer_test.dart + e2e_client_test.dart
- [ ] Android emulator e2e (blocked: box KVM fault) - NOT TESTED
- [ ] Owner tests on phones + Windows PC (NOT TESTED)

## Phase 8 - Fix security, compatibility, performance, usability
- [ ] Security tests for all acceptance tests
- [ ] Real release key (never committed)

Note: the owner's phase prompts set the numbering. Spec phases 2-7 moved one step later because the owner made Phase 2 the UI phase.
