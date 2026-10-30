# Privacy

Isekai Drop collects **no data**.

- No accounts, no sign-up.
- No cloud: files go directly from one of your devices to another.
- Isekai Drop itself: no analytics, no tracking, no ads, no crash-reporting services. Exception outside our control: the Android QR scanner library (Google ML Kit) sends Google its own usage metrics (see "QR scanning on Android" below).
- No servers run by us. No internet relay.
- Settings, device keys and transfer history stay only on your own devices.
- Logs never contain file names, file contents or personal data.

What stays on your device: your device name, theme, your device key
(in secure storage), the list of trusted devices (their names, platform and
key fingerprint, last local address).

On your local network the app announces: device name, platform, port and key
fingerprint, so your other devices can find it. Files and file names are
only ever sent, encrypted, to a device you paired and only after the receiver
accepts. Logs contain no file names or contents.

## Pairing: one tap, and what that means (0.9.1)
Pairing is one tap: the other device asks "Accept NAME?" and both devices
remember each other's key. Comparing the 16-digit code is **optional**.
The trade-off, honestly: if you do not compare the code (or pair by QR
code), someone on the same Wi-Fi who is actively attacking at the moment of
that **first** pairing could pretend to be the other device. Later
connections are safe from this because the keys are remembered and checked.
Devices paired without the check show "Paired (code not checked)";
Trusted devices > Check code makes them "Verified". Automatic receiving
works only for Verified devices. On public or shared Wi-Fi, compare the code.

## QR scanning on Android (Google ML Kit)
The QR scanner on Android uses Google's ML Kit (chosen by the owner). Images
from the camera are processed only on the phone; ML Kit does not send them
or the scan result to Google. However, according to Google, ML Kit itself
sends **usage and performance metrics**, device information (maker, model,
Android version), the app's package name and version, and a per-installation
identifier to Google, when the phone has internet. Isekai Drop adds nothing
to this. If you never use "Scan QR code", the scanner is not started.
Sources: https://developers.google.com/ml-kit/terms and
https://developers.google.com/ml-kit/android-data-disclosure

On iPhone/iPad and Mac, QR scanning uses Apple's built-in frameworks.

## Camera
Used only while the scan screen is open, only to read the pairing QR code.
Nothing is recorded or saved.

## Speed test (0.10.1)
Runs only when you press "Run speed test", only with a paired device. It
sends only zeros. The test files it writes (app temp folder, and on Android
a hidden item in Downloads/Isekai Drop) are deleted straight away, also on
error. The plain (unencrypted) test port is opened for one connection only
and needs a random one-time token that is sent inside the encrypted
connection. The copied report has no device names, file names, network
names or IP addresses.

## Speed test and transfers (0.10.2)
- The Speed test report names the network interface the test used (for
  example "p2p0 (Wi-Fi Direct)" or "wlan0 (Wi-Fi)") and the direct link's
  channel and role. It still has no IP addresses, device, file or network
  names.
- The native speed rows (Android) send only zeros over a one-time port that
  needs a random token sent inside the encrypted connection.
- During a transfer or the Speed test the app holds a Wi-Fi lock and a CPU
  wake lock (WAKE_LOCK permission, already declared) so the phone does not
  slow Wi-Fi down; both are released when it ends (the wake lock after 2 h
  at most).

## Fast direct (0.10.0)
- **Permissions (Android):** "Nearby devices" on Android 13+ (declared
  `neverForLocation`: never used to find your location) or "Location" on
  Android 12 and older (Android requires it for Wi-Fi Direct and app-made
  hotspots; Location must be switched on). Isekai Drop never reads or stores
  your location. The app explains this before Android asks, and you can turn
  Fast direct off in Settings.
- **The link's Wi-Fi password** is random, made new for each link, and only
  shown in the Fast direct QR codes on your screen or sent to an already
  paired device inside the encrypted connection. It is not saved and not
  logged.
- **PCs joining a link:** Windows gets a temporary Wi-Fi profile file with the
  password that is deleted right after `netsh` reads it. On Linux (`nmcli`)
  and macOS (`networksetup`) the password is briefly on the command line of
  the system tool (visible to other programs of the same computer while it
  runs). Diagnostics stores the commands with the password replaced by ***.
- **Windows hotspot:** starting it uses PowerShell and Windows' own
  tethering settings; the name/password come from Windows.
- While a phone or PC is on a fast link it may have no internet; nothing is
  sent anywhere else.

## Bonjour / mDNS (all platforms, Phase 5)
While the app is open it advertises a `_isekaidrop._tcp` service on your local network (not on Windows/Linux, which only look). The service carries: device name, a random device id, your certificate fingerprint, platform name and protocol version. Nothing leaves your local network. On iPhone/iPad, iOS asks for Local Network permission first.

## Transfer History (Phase 6)
History is stored only on this device (history.json in the app's private folder). It holds: direction, other device name/id, file count, sizes, result, times, and (only while "Save file names in History" is on) the file names. File contents are never stored. You can turn names off (and delete old names), delete one entry, or clear everything. The app writes no logs containing file names.

## Interrupted transfers (Phase 6)
To let a transfer continue, the receiver keeps the unfinished file in a hidden folder (.isekai-resume) next to received files, for up to 7 days. It is deleted when the transfer finishes, is cancelled, or fails its integrity check.
