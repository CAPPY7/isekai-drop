# Isekai Drop 0.7.0 (DRAFT release notes, test build)

**Test build, signed with the throwaway dev key. Not a public release.** Nothing here has been benchmarked against LocalSend yet. Device testing is limited (docs/ACCEPTANCE.md).

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
