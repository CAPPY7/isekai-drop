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

## App-made hotspot (Android)
Android requires "Nearby devices" (Android 13+, declared never used for
location) or "Location" (Android 12 and older) to create a hotspot. Isekai
Drop never reads or stores your location.

## Bonjour / mDNS (all platforms, Phase 5)
While the app is open it advertises a `_isekaidrop._tcp` service on your local network (not on Windows/Linux, which only look). The service carries: device name, a random device id, your certificate fingerprint, platform name and protocol version. Nothing leaves your local network. On iPhone/iPad, iOS asks for Local Network permission first.

## Transfer History (Phase 6)
History is stored only on this device (history.json in the app's private folder). It holds: direction, other device name/id, file count, sizes, result, times, and (only while "Save file names in History" is on) the file names. File contents are never stored. You can turn names off (and delete old names), delete one entry, or clear everything. The app writes no logs containing file names.

## Interrupted transfers (Phase 6)
To let a transfer continue, the receiver keeps the unfinished file in a hidden folder (.isekai-resume) next to received files, for up to 7 days. It is deleted when the transfer finishes, is cancelled, or fails its integrity check.
