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
