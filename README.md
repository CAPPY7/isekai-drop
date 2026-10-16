# Isekai Drop

A free, private app for sending files **directly** between your own devices
(and friends' and family's). No cloud upload, no accounts, no ads.

**Status: Phase 4.** Folders, pause/resume, queue, QR pairing and
no-router hotspot options added.

Previously, Phase 3: Real, encrypted sending between two devices on the
**same Wi-Fi or hotspot**: pairing with a 16-digit code, approval before every
transfer, SHA-256 check of every file. Transfer History is still **DEMO**.
QR scanning, folders, pause/resume are not built yet.

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
| Devices do not find each other | Some Wi-Fi networks (guest/office/"AP isolation") block devices from seeing each other. Use a phone hotspot instead, or type the address. On Windows allow Isekai Drop in the firewall prompt. |
| No APK in Assets | The latest build may still be running or failed. Check the **Actions** tab. |

## Other platforms
Windows, macOS and Linux builds are downloadable from the **Actions** tab
(each run → Artifacts). iPhone builds are **not installable** yet; see
`docs/BUILD_AND_INSTALL.md`.

## Documents
- `docs/SPECIFICATION.txt`: what the app must do
- `docs/TECH_CHOICE.md`, `docs/ARCHITECTURE.md`, `docs/CONNECTION_OPTIONS.md`, `docs/BUILD_AND_INSTALL.md`
- `ROADMAP.md`, `AGENTS.md`, `PRIVACY.md`, `THIRD_PARTY_NOTICES.md`
