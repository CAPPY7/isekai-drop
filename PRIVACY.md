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

## Sending to a new device (0.11.4)
Nearby devices you never paired with are marked "New device". When you send
to one, your screen shows the 16-digit code and asks "Does the other screen
show the same code?". Until you tap "Same code, send", the other device only
gets your device name, your key, the number of files and their total size:
no file names and no file contents. "Cancel" sends nothing more and pairs
nothing on your device.

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

0.11.4: on Android 10 and newer, a file being received is written straight into a **hidden** item in Downloads/Isekai Drop (other apps do not see it). It becomes visible only after its checksum matched; otherwise it is deleted. An unfinished one is kept hidden for Retry for up to 7 days (Android also removes forgotten hidden items itself). At most 5 unfinished transfers per device are kept, and at most half of the free space; the oldest are deleted first.

## Picked files on Android (0.11.4)
When you pick files or a folder to send, the app asks Android to keep **read** access to exactly those files (or that folder) so "Retry" still works after the app was closed. Nothing is copied. The access is given back when the send finished, was cancelled or you removed it from the list of unfinished sends; any left over is given back at the next start. Some file providers do not allow this; Retry then asks you to pick the files again.

App signing (0.11.1): Android APKs are signed with the owner's release key.
The key only proves who built the app; it does not see or send any of your
data.

## Android 0.12.0: sharing, notifications, opening files
- **Share > Isekai Drop:** another app hands over only the files you shared. They are read only to send them, like picked files. Links that point into an app's private folder (file://) and this app's own links are refused.
- **Notifications:** while a transfer runs, or a device waits for your answer, a notification shows "Sending files", "Receiving files" or "A device wants to send you something", with the MB moved so far and a Cancel button. **No file names and no device names** are shown (they could be seen on the lock screen). Android 13+ asks for permission once, at your first transfer, after the app explains why; saying no only hides the notification.
- **Always allow this device:** an option on the receive question, only for devices whose code you compared (Verified). Files from that device are then received without asking. Saved only in trusted_devices.json on this device; turn it off in Settings > Trusted devices.
- **Open / Show in folder:** opens a received file with the app you choose. That app gets read access to that one file only. On Android 9 and older this goes through a private file link (FileProvider) limited to the "Isekai Drop" download folder.

## 0.12.1: texts, language, About
- **Text or link (E1):** sent only to a paired device, over the same encrypted connection as files. The other device shows it only after its user accepts. The text is kept only in memory while the dialog is open: it is **not** saved in History (only "Text received"), not written to any log or the support report, and a link is never opened by itself.
- **Language (E2):** the chosen language (System / English / Hindi / Kannada) is saved in the app's settings on this device only.
- **About (E3):** shows this device's public key fingerprint (the same one other devices see when pairing). The "latest build" link opens GitHub only when you tap it.

## Android permissions (what each one is for)
| Permission | Why | Asked? |
|---|---|---|
| INTERNET | Direct connections between your devices on your network | No prompt |
| CHANGE_WIFI_MULTICAST_STATE | Hear "I'm here" announcements of your other devices | No prompt |
| ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE | Connection type and Wi-Fi speed in Diagnostics | No prompt |
| WAKE_LOCK | Keep Wi-Fi and the processor awake during a transfer | No prompt |
| CAMERA | Scan a pairing QR code | When you tap Scan |
| WRITE_EXTERNAL_STORAGE (Android 9 and older only) | Save into Downloads/Isekai Drop | When the first file is saved |
| CHANGE_WIFI_STATE, CHANGE_NETWORK_STATE, NEARBY_WIFI_DEVICES (13+), ACCESS_FINE/COARSE_LOCATION (12 and older) | Fast direct phone-to-phone link; never used for your location | When you use Fast direct |
| FOREGROUND_SERVICE, FOREGROUND_SERVICE_DATA_SYNC (0.12.0) | Keep a transfer going when you switch apps | No prompt |
| POST_NOTIFICATIONS (0.12.0, Android 13+) | Progress and "incoming request" notifications | Once, at your first transfer |
