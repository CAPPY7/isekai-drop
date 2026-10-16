# Ways to connect devices without the home router or internet

"Speed class" is a rough expectation, **not a promise and not measured yet**.
Real numbers come only from tests in Phase 6.

| # | Method | Works between | Speed class (expected, NOT measured) | What you do |
|---|---|---|---|---|
| 1 | **Phone hotspot** (one device makes a Wi-Fi network, others join) | Everything | High (Wi-Fi 5/6 class) | Turn on hotspot on device A, join it on device B, open Isekai Drop on both |
| 2 | **Android local-only hotspot** made by the app | Android ↔ anything | High | Tap "Create hotspot" in the app; scan the QR on the other device to join |
| 3 | **Wi-Fi Direct** (devices link directly) | Android ↔ Android (maybe Windows) | High | Tap the other device, accept the prompt |
| 4 | **Windows Mobile Hotspot** | Windows ↔ anything | Medium-high (hardware dependent) | Settings → Network → Mobile hotspot → On, then join it |
| 5 | **Apple peer-to-peer** (AWDL) | Apple ↔ Apple only | High | Both Apple devices nearby with Wi-Fi on |
| 6 | **USB / Ethernet cable network** | Desktop ↔ desktop, some phones | Very high | Plug in cable; advanced, later |
| 7 | **Bluetooth** | Most | Very low (fallback only) | Pair in Bluetooth settings; small files only |
| 8 | Same Wi-Fi router (not required, but supported) | Everything | High | Both on the same Wi-Fi |

What each system really allows:
- **Android**: apps can create a local-only hotspot (no internet) and use Wi-Fi
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
