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
- [ ] Owner installs the APK on Android and confirms
- [x] DEV key fingerprint identical over two consecutive builds (runs 1 and 2: 5b36ee…57c1)
- [ ] Owner chooses iOS signing option (needed before Phase 4)

## Phase 2 - Secure pairing, direct connections, reliable file streaming
- [ ] Device identity keys in secure storage
- [ ] Discovery + QR / code pairing with approval
- [ ] TLS sessions with key pinning, every session authenticated
- [ ] Chunked streaming, temp files, SHA-256 check, safe file names
- [ ] Real screens: Home, File Selection, Transfer, Connect Device

## Phase 3 - Test Android ↔ Windows and Android ↔ macOS transfers
- [ ] Manual test lists and results recorded

## Phase 4 - iPhone/iPad interoperability and platform fallbacks
- [ ] iOS signing per owner's choice
- [ ] Hotspot / manual fallbacks documented and tested

## Phase 5 - Trusted devices, history, queues, integrity, resume
- [ ] Trusted Devices screen (rename, revoke, reverify)
- [ ] History, queue, pause/resume/cancel, database migrations

## Phase 6 - Benchmark against LocalSend (identical conditions)
- [ ] Measured results table, no unmeasured claims

## Phase 7 - Fix security, compatibility, performance, usability
- [ ] Security tests for all acceptance tests
- [ ] Real release key (never committed)
