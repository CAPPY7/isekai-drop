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
- [ ] Owner tests the screens on Android

## Phase 3 - Secure pairing, direct connections, reliable file streaming
- [ ] Device identity keys in secure storage
- [ ] Discovery + QR / code pairing with approval
- [ ] TLS sessions with key pinning, every session authenticated
- [ ] Chunked streaming, temp files, SHA-256 check, safe file names

## Phase 4 - Test Android ↔ Windows and Android ↔ macOS transfers
- [ ] Manual test lists and results recorded

## Phase 5 - iPhone/iPad interoperability and platform fallbacks
- [ ] iOS signing (owner SKIPPED for now; revisit only if owner asks)
- [ ] Hotspot / manual fallbacks documented and tested

## Phase 6 - Trusted devices, history, queues, integrity, resume
- [ ] Trusted Devices screen (rename, revoke, reverify)
- [ ] History, queue, pause/resume/cancel, database migrations

## Phase 7 - Benchmark against LocalSend (identical conditions)
- [ ] Measured results table, no unmeasured claims

## Phase 8 - Fix security, compatibility, performance, usability
- [ ] Security tests for all acceptance tests
- [ ] Real release key (never committed)

Note: the owner's phase prompts set the numbering. Spec phases 2-7 moved one step later because the owner made Phase 2 the UI phase.
