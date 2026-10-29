# Isekai Drop

A free, private app for sending files **directly** between your own devices
(and friends' and family's). No cloud upload, no accounts, no ads.

**Status: Phase 7 (test builds, not a public release).** Encrypted direct transfers, QR/code pairing, folders, pause/resume, resume after interruption, trusted-device management, real history and a benchmark log. Nothing has been benchmarked against LocalSend yet (see docs/BENCHMARK_PLAN.md). Device testing so far is limited: see docs/ACCEPTANCE.md and docs/AUDIT.md.

## What works where (honest limits)
| Platform | Install | Finds others | Others find it | Limits |
|---|---|---|---|---|
| Android 8+ | APK from the release (test key) | UDP + Bonjour | yes | Use the phone's normal hotspot when there is no router (Connect > No Wi-Fi router?). Android 9 and older save to the app's own folder (audit #6). Keep the app open while transferring. |
| iPhone / iPad | UNSIGNED .ipa, sideloaded with **your own** Apple ID (AltStore/Sideloadly). Free Apple ID = 7-day expiry, 3 devices. NOT TESTED | Bonjour only | yes (Bonjour) | Must allow Local Network. **Foreground only**: transfers stop in the background. Windows/Linux PCs don't appear: scan their QR code or type their address. No folder picking. |
| Windows 10/11 | Build from Actions (unsigned) | UDP + Bonjour (browse) | UDP only | SmartScreen warns (More info > Run anyway). Allow it in the firewall prompt. iPhones can't find it automatically. |
| macOS | Build from Actions (unsigned) | UDP + Bonjour | yes | Gatekeeper blocks the first start: right-click > Open, or System Settings > Privacy & Security > Open Anyway. Local Network permission on macOS 15+. NOT TESTED on a Mac. |
| Linux x64 | tar.gz from Actions | UDP + Bonjour (browse) | UDP only | Needs GTK 3 and libsecret. Without an unlocked keyring the device key is stored in a private file (mode 600) instead. Open TCP 47820 and UDP 47821 in the firewall. Tested only headless on the build box. |

Speed: no speed is promised. Shown speeds are measured live. Real results depend on your devices and Wi-Fi.

## Friends and family: how to give them the app
The repo is **private**, so other people can't open the release page. Choose one:
1. **Send the file yourself** (easiest): download the APK (or the Windows/Mac/Linux zip) on your device, then share it with them through any messenger or cloud drive. They install it as in "Install on Android" from step 4.
2. **Add them as GitHub collaborators** (Repo > Settings > Collaborators). They need a GitHub account. This is a repo settings change; only you can do it.
Tell them: the app is a test version signed with a test key. They must pair with you by comparing the 16-digit code (or scanning your QR code) and should only accept files from people they know.
When the real release key arrives (docs/RELEASE_SIGNING.md), everyone has to **uninstall the test app once** and install the new one. Pairings must then be made again.

Earlier phases: Phase 3 had real, encrypted sending on the same Wi-Fi or hotspot with code pairing and approval; Phase 4 added folders, pause/resume, queue, QR and hotspot options.

## Send a file between two devices (quick guide)
1. Install and open Isekai Drop on both devices. Put both on the same Wi-Fi.
2. On device A tap **Connect**. Device B should appear under "Found
   automatically". Tap it. (If not: type B's address shown on B's Connect page.)
3. Both screens show a 16-digit code. If they match, tap **Codes match** on A
   and **approve** on B.
4. On A tap **Send**, **Pick files**, choose the files, tap **Send to B**.
5. On B tap **Accept**. (No router? See Connect > "No Wi-Fi router?".) Received files go to **Downloads/Isekai Drop** (Android)
   or **Downloads/Isekai Drop** folder (Windows/Mac/Linux).

## How it works (no computer needed by you)
1. Code changes are pushed to this private GitHub repo.
2. GitHub Actions (GitHub's free build computers) automatically builds the apps.
3. The Android app (APK, the Android install file) is published to the release
   called **latest-build**.

> **Important:** this repo is **private**. The Release page and the download
> only work when you are **logged into GitHub in your phone's browser**
> (Chrome). If you see "404 / Page not found", you are not logged in.

## Install on Android (first time)
1. On your phone, open Chrome and go to `github.com`. Log in.
2. Open `https://github.com/iSujaykumar/Isekai-Drop/releases/tag/latest-build`.
3. Under **Assets**, pick the highest number and tap
   `isekai-drop-android-arm64-<number>.apk` (smaller, works on most phones from
   about 2017 on). If it says "App not installed", use
   `isekai-drop-android-<number>.apk` instead (works on all phones).
4. When Chrome warns about the file, tap **Download anyway**.
5. Tap **Open** when the download finishes.
6. If asked, tap **Settings**, turn on **Allow from this source**, then go back.
7. Tap **Install**. Then tap **Open**.

## Install on iPhone (UNSIGNED .ipa - NOT TESTED)
The iPhone file is **UNSIGNED**. We do not sign it. You sign it yourself with your own free Apple ID. With a free Apple ID the app stops opening after **7 days**; repeat the steps (or refresh) to keep it working.
These steps have NOT been tested by us.

Get the file: open the "latest-build" release on GitHub and download `isekai-drop-ios-unsigned-N.ipa` (highest N = newest).

AltStore (Windows 10+ or macOS 11+):
1. Install AltServer from https://altstore.io/ on your computer.
2. Connect the iPhone by cable and tap "Trust" on the phone.
3. Use AltServer to install AltStore on the iPhone, signing in with your Apple ID.
4. On the iPhone: Settings > General > VPN & Device Management > trust your Apple ID.
5. Copy the .ipa to the iPhone, open AltStore > My Apps > "+", and pick the .ipa.
6. Open AltStore every few days to refresh the app before the 7 days run out.

Sideloadly (Windows or macOS):
1. Install Sideloadly from https://sideloadly.io/.
2. Connect the iPhone by cable and tap "Trust".
3. Drag the .ipa into Sideloadly, type your Apple ID, and press Start.
4. On the iPhone: Settings > General > VPN & Device Management > trust your Apple ID.
5. After 7 days, repeat step 3.

First start on iPhone: allow "Local Network" when asked. Keep the app open while sending.

## Update
Repeat the same steps with the newer APK. It installs over the old one and
keeps your data, because every test build is signed with the same key.

## Troubleshooting
| Problem | Fix |
|---|---|
| Page shows 404 | Log into GitHub in the same browser, then reload. |
| "App not installed" | An older copy signed differently is installed. Uninstall Isekai Drop, then install again. |
| "Install blocked" | Allow "Install unknown apps" for Chrome (Settings → Apps → Chrome → Install unknown apps). |
| Play Protect warning | Tap **More details → Install anyway**. It is warning because the app is not from the Play Store. |
| Devices do not find each other | Some Wi-Fi networks (guest/office/"AP isolation") block devices from seeing each other. Tap Connect > Search this network, use a phone hotspot instead, or type the address. On Windows allow Isekai Drop in the firewall prompt. |
| No APK in Assets | The latest build may still be running or failed. Check the **Actions** tab. |

## Other platforms
Windows, macOS and Linux builds are downloadable from the **Actions** tab (open the newest green run > Artifacts: `isekai-drop-windows`, `isekai-drop-macos`, `isekai-drop-linux`). You must be logged into GitHub.
1. Windows: unzip, run `isekaidrop.exe`. On SmartScreen tap More info > Run anyway. Allow the firewall prompt (Private networks).
2. macOS: unzip, right-click the app > Open > Open.
3. Linux: `tar xzf isekai-drop-linux-x64.tar.gz`, then run `./isekaidrop` inside the folder.
iPhone: see "Install on iPhone" above.

## Documents
- `docs/SPECIFICATION.txt`: what the app must do
- `docs/TECH_CHOICE.md`, `docs/ARCHITECTURE.md`, `docs/CONNECTION_OPTIONS.md`, `docs/BUILD_AND_INSTALL.md`
- `ROADMAP.md`, `AGENTS.md`, `PRIVACY.md`, `THIRD_PARTY_NOTICES.md`, `RELEASE_NOTES.md`
- `docs/AUDIT.md` (bug list), `docs/ACCEPTANCE.md`, `docs/BENCHMARK_PLAN.md`, `docs/BENCHMARK_STEPS.md`, `docs/BENCHMARK_RESULTS_TEMPLATE.md`, `docs/RELEASE_SIGNING.md`, `docs/IOS_NOTES.md`
