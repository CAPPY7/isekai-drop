# Isekai Drop

A free, private app for sending files **directly** between your own devices
(and friends' and family's). No cloud upload, no accounts, no ads.

**Status: Phase 2.** All seven screens exist with **DEMO data** (labelled
"DEMO - not a real transfer"). Picking files and the theme setting are real.
Sending files between devices is **not built yet** (Phase 3).

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
| No APK in Assets | The latest build may still be running or failed. Check the **Actions** tab. |

## Other platforms
Windows, macOS and Linux builds are downloadable from the **Actions** tab
(each run → Artifacts). iPhone builds are **not installable** yet; see
`docs/BUILD_AND_INSTALL.md`.

## Documents
- `docs/SPECIFICATION.txt`: what the app must do
- `docs/TECH_CHOICE.md`, `docs/ARCHITECTURE.md`, `docs/CONNECTION_OPTIONS.md`, `docs/BUILD_AND_INSTALL.md`
- `ROADMAP.md`, `AGENTS.md`, `PRIVACY.md`, `THIRD_PARTY_NOTICES.md`
