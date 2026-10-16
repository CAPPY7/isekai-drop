# Architecture (plan for all phases)

Plain words: the app has two halves. The **UI** (what you see and tap) and the
**transfer engine** (the part that finds devices and moves files safely). They
only talk through one agreed list of commands called an **interface**, so either
half can be improved without breaking the other.

```
 Screens (Flutter UI)  ──>  TransferEngine interface  ──>  Engine modules
 Home, Files, Transfer,      (lib/engine/                 discovery, pairing,
 Connect, Trusted,            transfer_engine.dart)        session, streaming...
 History, Settings                                          + small native add-ons
```

Phase 3: the real engine lives in `lib/engine/core/`; the wire protocol is in `docs/PROTOCOL.md`. Transfer History is still DEMO data.

## Engine modules
| Module | Job |
|---|---|
| Discovery | Find nearby Isekai Drop devices on the same local network (multicast / mDNS, a way for devices to announce themselves locally). Manual fallback: QR code or typed IP address. |
| Pairing / identity | Each install makes its own key pair (a private secret + a public "ID card"). Pairing = scan QR or compare a short code, then you approve. |
| Secure session | Every connection uses TLS 1.3 (the lock used by websites) with both sides proving their key ("mutual authentication"). The other device's key must match the saved one ("pinning"), never just its name or IP. |
| Chunked streaming | Files are read and sent in pieces (for example 1-4 MB), never fully loaded into memory. |
| Integrity check | A SHA-256 hash (a file fingerprint) is checked before a received file is kept. |
| Resume | Remember confirmed pieces so an interrupted transfer can continue. |
| Queue | Several transfers in order; pause and cancel. |
| History | Local list of transfers (status, size, time). No file contents. |
| Settings | Theme, device name, receive rules, connection preferences. |
| Diagnostics | Measured speed and connection info, with no file names or personal data. |

## Security design (from the specification)
1. One cryptographic identity per install. Private key in the platform's secure
   storage (Android Keystore, Apple Keychain, Windows DPAPI/Credential Locker,
   Linux Secret Service where available).
2. New devices are paired only by QR or verification code **and** your approval.
3. Every session is authenticated, including saved devices.
4. Unknown devices are rejected. If a known device's key changes, the app
   blocks and asks you to verify again. Trusted devices can be revoked.
5. Incoming files from untrusted devices need your approval.
6. Names and paths are cleaned (no `../` tricks, no silent overwrite). Files are
   written to a temporary file and only kept after the hash matches.
7. Logs never include file names, contents or personal data.
8. No servers, accounts, analytics or cloud. No internet relay.
9. Every point above must also get a test. We never call the app "perfectly secure".

## Data
Local database with a version number and migrations. Every record has a
unique ID, `created_at` and `updated_at`. Settings and trusted devices survive
updates. Deleting or revoking always asks first.

## Per-platform table
"confirmed from docs" = official documentation says so. "needs testing" = we
must prove it on a real device.

| Topic | Android | iOS / iPadOS | Windows | macOS | Linux |
|---|---|---|---|---|---|
| Hotspot made by the app | Local-only hotspot API exists (Android 8+); random name/password, no internet - confirmed from docs | Apps cannot create a hotspot; user turns on Personal Hotspot in Settings (needs mobile plan support) - confirmed from docs | Mobile Hotspot API exists on supported Wi-Fi hardware - needs testing | No app API; Internet Sharing is manual and needs an internet source - needs testing | NetworkManager can make a hotspot if the Wi-Fi card supports it - needs testing |
| Joining a hotspot / other Wi-Fi | User joins in Settings, or app suggests a network (Android 10+) - confirmed from docs | User joins in Settings (or `NEHotspotConfiguration` with user prompt) - confirmed from docs | User joins normally - confirmed from docs | User joins normally - confirmed from docs | User joins normally - confirmed from docs |
| Peer-to-peer Wi-Fi (no router) | Wi-Fi Direct API - confirmed from docs; speed needs testing | No Wi-Fi Direct; Apple-only peer-to-peer (Multipeer/AWDL) works only with Apple devices - confirmed from docs | Wi-Fi Direct API exists - needs testing | Apple-only peer-to-peer - confirmed from docs | wpa_supplicant P2P, hardware dependent - needs testing |
| Local-network permission | "Nearby Wi-Fi devices" permission for Wi-Fi Direct/hotspot (Android 13+) - confirmed from docs | Local Network permission prompt required (iOS 14+) - confirmed from docs | Firewall prompt on first listen - confirmed from docs | Local Network permission (macOS 15+) and firewall - confirmed from docs | Usually none; firewall may block - needs testing |
| Folder access | System picker (Storage Access Framework), no broad storage permission - confirmed from docs | System document picker, sandboxed - confirmed from docs | Normal file dialogs - confirmed from docs | Sandboxed app uses system open/save panels - confirmed from docs | Normal file dialogs (portal on Flatpak) - confirmed from docs |
| Background limits | Long transfers need a foreground service with visible notification - confirmed from docs | Transfers stop soon after leaving the app; keep the app open - confirmed from docs | No real limit while running - confirmed from docs | No real limit while running (App Nap may slow it) - needs testing | No limit - confirmed from docs |
| Secure key storage | Android Keystore - confirmed from docs | Keychain - confirmed from docs | DPAPI / Credential Locker - confirmed from docs | Keychain - confirmed from docs | Secret Service (libsecret), not always installed - needs testing |
| File pickers | System picker - confirmed from docs | System picker, Photos picker - confirmed from docs | System dialog + drag and drop - confirmed from docs | System dialog + drag and drop - confirmed from docs | GTK/portal dialog + drag and drop - needs testing |

## Risks and open questions
1. iPhone ↔ non-Apple devices without a router realistically needs a hotspot
   (iPhone Personal Hotspot, or Android/Windows hotspot). Needs testing.
2. Real speed on each connection type is unknown until measured (Phase 6).
3. iPhone installs need Apple signing; see BUILD_AND_INSTALL.md (your choice later).
4. Which Dart/Flutter plugins we use for secure storage and pickers will be
   chosen in Phase 2, licence-checked (permissive only), and listed in
   THIRD_PARTY_NOTICES.md.
5. Android Wi-Fi Direct behaviour differs between phone makers. Needs testing.
