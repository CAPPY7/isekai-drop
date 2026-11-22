# Mac: install Isekai Drop

This is for any Mac, including a MacBook Air with an M5 chip (and other
Apple Silicon or Intel Macs). You need macOS 12 or newer.

The file on the download page is `isekai-drop-macos.dmg`. A ".dmg" is a
disk image: a small virtual disk you open, then copy the app out of.

These are test builds. The app is **ad-hoc signed** (stamped by the build
computer only) and **not notarized** (Apple has not checked it). There is
no paid Apple account, so Mac will warn you the first time. That is
expected. Running on a real Mac: **NOT TESTED**.

## Install
1. On your Mac, open
   `https://github.com/CAPPY7/isekai-drop/releases/tag/latest-build`
   (no GitHub account needed).
2. Download **`isekai-drop-macos.dmg`**.
3. In your Downloads folder, double-click that file. A window opens with
   **Isekai Drop** and an **Applications** folder.
4. Drag **Isekai Drop** onto **Applications**.
5. Eject the "Isekai Drop" disk (click the eject icon next to it in
   Finder), then you can delete the .dmg if you want.

## First open (Mac will block it once)
Do **not** only double-click the app the first time; Mac may refuse it.

1. Open **Finder**, go to **Applications**.
2. **Right-click** (or Control-click) **Isekai Drop** and choose **Open**.
3. In the warning, click **Open**. After this, a normal double-click
   works.

If there is no Open button, or Mac still refuses:

1. Open **System Settings** (the gear).
2. Open **Privacy & Security**.
3. Scroll down to the Security section. You should see a message about
   Isekai Drop. Click **Open Anyway**, then confirm.

### If Mac says the app is "damaged"
This can happen with unsigned downloads. It is usually a quarantine flag,
not a real broken file.

1. Open **Terminal** (search for it with Spotlight: press Command + Space
   and type Terminal).
2. Paste this line and press Return:

   `xattr -cr "/Applications/Isekai Drop.app"`

   That command only removes Mac's "this was downloaded" flag from the
   app. It does not change the app itself.
3. Then try **right-click > Open** again.

## Permissions the app may ask for
- **Local Network** (macOS 15 and later): click **Allow**. The app uses
  this to find your other devices on the same Wi-Fi. A "local network" is
  just your home Wi-Fi or a hotspot, not the internet.
- **Camera**: only if you scan a pairing QR code. Nothing is recorded.
- If a firewall prompt appears, allow Isekai Drop.

Received files go to the **Downloads/Isekai Drop** folder.

## Uninstall
Drag **Isekai Drop** from Applications to the Trash, then empty the Trash.
