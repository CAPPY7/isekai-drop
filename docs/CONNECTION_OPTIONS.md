# Ways to connect devices without the home router or internet

"Speed class" is a rough expectation, **not a promise and not measured yet**.
Real numbers come only from tests in Phase 6.

| # | Method | Works between | Speed class (expected, NOT measured) | What you do |
|---|---|---|---|---|
| 1 | **Phone hotspot** (one device makes a Wi-Fi network, others join) | Everything | High (Wi-Fi 5/6 class) | Turn on hotspot on device A, join it on device B, open Isekai Drop on both |
| 2 | **Android local-only hotspot made by the app** | Android -> anything (back in 0.10.0 as the Fast direct fallback) | High (band chosen by Android) | Connect > Fast direct > Start fast link, scan the code |
| 3 | **Wi-Fi Direct** (devices link directly) - built in 0.10.0 | Android ↔ Android automatically; PCs/iPhones join it as a normal Wi-Fi | High (5 GHz requested) | Nothing (automatic for big files) or scan the Fast direct code |
| 4 | **Windows Mobile Hotspot** | Windows ↔ anything | Medium-high (hardware dependent) | Settings → Network → Mobile hotspot → On, then join it |
| 5 | **Apple peer-to-peer** (AWDL) | Apple ↔ Apple only | High | Both Apple devices nearby with Wi-Fi on |
| 6 | **USB / Ethernet cable network** | Desktop ↔ desktop, some phones | Very high | Plug in cable; advanced, later |
| 7 | **Bluetooth** | Most | Very low (fallback only) | Pair in Bluetooth settings; small files only |
| 8 | Same Wi-Fi router (not required, but supported) | Everything | High | Both on the same Wi-Fi |

What each system really allows:
- **Android**: apps can create a local-only hotspot (no internet; Isekai Drop no longer does, 0.9.0) and use Wi-Fi
  Direct; asks "Nearby devices" permission on Android 13+.
- **iPhone/iPad**: apps cannot create a hotspot or use Wi-Fi Direct. Use the
  iPhone's Personal Hotspot (Settings) or join another device's hotspot.
  Asks "Local Network" permission. Keep the app open while sending.
- **Windows**: can host a Mobile Hotspot if the Wi-Fi card supports it.
- **macOS**: no app-made hotspot; join another device's hotspot.
- **Linux**: hotspot possible via NetworkManager on supported cards.

Fallbacks when devices don't find each other: show a QR code with the
connection address and identity, or type the IP address shown on the other
screen. Pairing approval is still required either way.
No internet relay is ever used by default.

## Owner decision (Phase 4, 2026-10-16): build A + B + C
- **A. Phone hotspot, computer joins** - in-app guide. No extra permissions.
- **B. Windows Mobile Hotspot, phone joins** - in-app guide. Windows only
  (Macs have no equivalent).
- **C. App-made Android local-only hotspot** - **REMOVED in 0.9.0** (owner asked to make the app work; too fragile and permission-heavy, docs/AUDIT.md #29). Historical notes: one tap in Connect > "Make a
  hotspot with Isekai Drop". Verified against the Android WifiManager
  reference (2026-10-16): `startLocalOnlyHotspot` needs CHANGE_WIFI_STATE +
  NEARBY_WIFI_DEVICES for apps targeting Android 13+, and CHANGE_WIFI_STATE +
  ACCESS_FINE_LOCATION on Android 12 and older. It has no internet, random
  name/password each time, may fail with ERROR_INCOMPATIBLE_MODE while the
  normal hotspot is on, and can be stopped by the user/system at any time.
  Manifest: NEARBY_WIFI_DEVICES with `neverForLocation`; FINE/COARSE
  location with `maxSdkVersion=32`. The app explains before asking.
  On Android 12 and older Location must also be switched on (NOT TESTED on a
  device).
- **Not built:** Wi-Fi Direct (no macOS support, unreliable Windows interop).

## 0.10.0: Fast direct (owner: "Phone to phone works more speed then what about other speed build this")
Router mode stays the default and the fallback. Fast direct adds a link
with **one air hop** instead of two (phone -> router -> phone).

| Pair | What the app does | User steps |
|---|---|---|
| Android ↔ Android (paired, same router) | Big sends (64 MiB+) ask the receiver over the existing encrypted session to make a Wi-Fi Direct group (5 GHz requested, else any band; else a local-only hotspot). The sender joins it, sends, leaves. Any failure -> router, with the reason on the transfer card and in Diagnostics. | None (Settings > Fast direct when possible, Allow once) |
| Android ↔ Android (no router) | Phone A: Start fast link, shows the "Isekai Drop" code (link + port + key fingerprint + name). Phone B scans it: joins the link, then pairs with exactly that key. | Start on A, scan on B |
| Android -> Windows / Linux / macOS | Phone hosts; the PC joins with the system tools (Windows: temporary netsh WLAN profile, deleted right after; Linux: nmcli; macOS: networksetup), then pairs over the link. | Start on the phone; on the PC Connect > Fast direct, type/paste, Join |
| Android -> iPhone | Phone hosts and shows a standard Wi-Fi code (`WIFI:S:...;T:WPA;P:...;;`). The iPhone Camera joins it; then Isekai Drop on the iPhone scans the "Isekai Drop" code to pair. iPhone apps cannot join Wi-Fi themselves without an extra Apple entitlement (not used). | Camera scan, then app scan |
| Windows as host | Connect > Fast direct > Start Windows hotspot (PowerShell, Windows tethering API; needs a connection to share) or open Settings > Mobile hotspot (5 GHz band setting there). The PC shows a Wi-Fi code; an Android phone running Isekai Drop can scan it and join (approval dialog), or join in Wi-Fi settings. | Start on the PC, scan on the phone |

Android facts used (developer.android.com, checked 2026-10-30):
- WifiP2pConfig.Builder (API 29+): network name must start with "DIRECT-xy", passphrase 8-63 characters; band and frequency are mutually exclusive; a 5 GHz group fails if not possible (the app then retries with any band).
- WifiP2pManager connect/createGroup/requestGroupInfo need NEARBY_WIFI_DEVICES (Android 13+, declared `neverForLocation`) or ACCESS_FINE_LOCATION (12 and older, location switched on). Failure codes ERROR=0, P2P_UNSUPPORTED=1, BUSY=2.
- WifiNetworkSpecifier (API 29+) joins a local-only network after a system approval dialog; onUnavailable when declined/not possible.
- LocalOnlyHotspot (API 26+): band chosen by Android, random name/password, may fail while the normal hotspot is on.

Speed: ESTIMATES only, nothing measured on radios. Real Wi-Fi throughput is
"typically 50% or less" of the link rate (Cisco Meraki,
https://documentation.meraki.com/Wireless/Design_and_Configure/Architecture_and_Best_Practices/Wireless_Throughput_Calculations_and_Limitations).
Wi-Fi 6 2x2 80 MHz (1201 Mbps) -> roughly 600 Mbps -> up to ~70 MB/s direct;
Wi-Fi 5 2x2 (867 Mbps) -> ~50 MB/s; through a router about half of that
(~36 MB/s best case). Whether a phone's Wi-Fi Direct group actually uses
80 MHz / Wi-Fi 6 is chip-dependent and NOT TESTED.
