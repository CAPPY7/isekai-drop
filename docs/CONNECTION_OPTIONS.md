# Ways to connect devices without the home router or internet

"Speed class" is a rough expectation, **not a promise and not measured yet**.
Real numbers come only from tests in Phase 6.

| # | Method | Works between | Speed class (expected, NOT measured) | What you do |
|---|---|---|---|---|
| 1 | **Phone hotspot** (one device makes a Wi-Fi network, others join) | Everything | High (Wi-Fi 5/6 class) | Turn on hotspot on device A, join it on device B, open Isekai Drop on both |
| 2 | ~~Android local-only hotspot made by the app~~ | REMOVED in 0.9.0 (AUDIT #29) | - | Use option 1 |
| 3 | **Wi-Fi Direct** (devices link directly) | Android ↔ Android (maybe Windows) | High | Tap the other device, accept the prompt |
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
