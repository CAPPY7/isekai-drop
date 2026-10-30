# How each platform is built and installed

All builds run free on GitHub Actions (GitHub's build computers). You never
need Android Studio, Xcode or Visual Studio. The repo is public: standard
GitHub-hosted runners are free for public repos (private repos have a
monthly minutes allowance where macOS counts 10x and Windows 2x).

| Platform | Built on | What you get | Installable? | Cost |
|---|---|---|---|---|
| Android | ubuntu runner | Signed `.apk` | **Yes**, after allowing "Install unknown apps" | Free |
| Windows | windows runner | Single installer `isekai-drop-windows-setup.exe` (Inno Setup, per-user, no admin); app folder as CI artifact | Yes, unsigned: SmartScreen warns ("More info → Run anyway"); Windows 11 Smart App Control blocks unsigned apps (see WINDOWS_INSTALL.md) | Free (code-signing certificate optional, paid) |
| macOS | macOS runner | Zip of `Isekai Drop.app`, unsigned, not notarized | Yes with a workaround: right-click → Open, or System Settings → Privacy & Security → "Open Anyway" | Free; proper signing needs the $99/yr Apple program |
| Linux | ubuntu runner | `.tar.gz` with the app bundle | Yes: unpack, run `isekaidrop` | Free |
| iOS / iPadOS | macOS runner | **Unsigned** build | **No.** Proves the code compiles only | See below |

## Android signing
Every test APK is signed with one throwaway development key stored in the
repo (`android/app/isekai-drop-dev.jks`; the repo is now PUBLIC, so this key
is public too and anyone could sign a look-alike APK; move to the release
key, docs/RELEASE_SIGNING.md), so updates install over the
old version. The real release key comes only in the final phase and is never
committed. The version number (versionCode) is the GitHub run number, so it
goes up on every build. APKs built by hand on the build box use versionCode
1001 or higher (file name ends in `-local.apk`) so they never clash with a
GitHub build number; a phone with such a build installed needs an uninstall
before it accepts a lower-numbered GitHub build.

## iPhone / iPad: your options (from Apple's docs, checked 16 Oct 2026)
1. **Free Apple account (Personal Team)**: install via Xcode on a Mac you
   control. Max 3 devices, 3 apps per device, and the app **stops opening
   after 7 days** until rebuilt and reinstalled. Cannot be done from GitHub
   alone; needs a Mac and a cable. Cost: $0.
2. **Apple Developer Program**: **$99 per year**. Lets GitHub build a signed app
   and send it to **TestFlight** (Apple's beta app), where builds last 90 days
   and up to 10,000 external testers (friends/family) can install by link.
   Needs Apple ID with two-factor sign-in and an enrolment you do yourself.
3. Do nothing for now: iOS stays "compiles only, not installable".

**Your choice is needed before Phase 4.** Until then iOS is marked NOT
installable.

## Public repo note
The repo is public, so the Release page and downloads work without logging
in to GitHub. Actions artifacts still need a GitHub login to download.
