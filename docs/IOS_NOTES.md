# iPhone / iPad notes (Phase 5, researched 16 Oct 2026)

Every link below was fetched on 16 Oct 2026. Apple's pages were read through their documentation JSON (the HTML needs JavaScript). Points marked NOT VERIFIED had no source fetched.

## Apple's rules and what they mean for us
| Topic | Rule | What we did |
|---|---|---|
| Local network privacy | iOS asks the user before an app talks to the local network. All Bonjour operations need this. If the permission has not been decided yet, background operations are denied. The Simulator does not support it. Source: TN3179 https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy | Info.plist has NSLocalNetworkUsageDescription. The guide explains how to turn it back on in Settings > Privacy > Local Network. |
| Purpose text | https://developer.apple.com/documentation/bundleresources/information-property-list/nslocalnetworkusagedescription | Set. |
| Bonjour service types | Every Bonjour type the app uses must be listed in NSBonjourServices. https://developer.apple.com/documentation/bundleresources/information-property-list/nsbonjourservices | `_isekaidrop._tcp` (iOS and macOS). |
| Multicast/broadcast | Raw IP multicast or broadcast needs the com.apple.developer.networking.multicast entitlement, which Apple must approve. https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.developer.networking.multicast . TN3179 says macOS does not need it. | Our UDP broadcast discovery is OFF on iOS. Bonjour is used instead; the app shows a note about this. |
| Background | Apps get only a short time after they go to the background (beginBackgroundTask). https://developer.apple.com/documentation/uikit/uiapplication/beginbackgroundtask(withname:expirationhandler:) | Foreground only. The screen is kept awake during a transfer, and the app asks for a short background task if you switch away. The in-app guide says: keep the app open. |
| Files app | UIFileSharingEnabled plus LSSupportsOpeningDocumentsInPlace show the app's Documents folder in Files. https://developer.apple.com/documentation/bundleresources/information-property-list/uifilesharingenabled , https://developer.apple.com/documentation/bundleresources/information-property-list/lssupportsopeningdocumentsinplace | Received files go to Documents and appear under Files > On My iPhone > Isekai Drop. |
| Export | UIActivityViewController https://developer.apple.com/documentation/uikit/uiactivityviewcontroller | "Share / Save to Files" button after a transfer finishes. |
| Peer-to-peer APIs | MultipeerConnectivity works between Apple devices only (it uses Bonjour) https://developer.apple.com/documentation/multipeerconnectivity . Wi-Fi Aware (iOS 26) is for Wi-Fi Aware accessories https://developer.apple.com/documentation/wifiaware . Network.framework is the base for TLS/Bonjour. | Not used: they don't help with Android or desktop. We keep TCP+TLS over normal Wi-Fi. |
| Folder picking | iOS has no simple folder picker in our file picker plugin. | Folder sending is hidden on iOS. Pick files instead. |

## Fallbacks for each pair of platforms
- iPhone ↔ Android / macOS: each side finds the other through Bonjour (both sides advertise). If that fails, use QR or type the IP.
- iPhone ↔ Windows / Linux: they can find the iPhone through Bonjour, but they cannot advertise themselves, and the iPhone has UDP discovery turned off. So, on the iPhone, use "Connect a device" and scan the PC's QR code or type its IP.
- No shared Wi-Fi: turn on the Android app's hotspot or the Windows Mobile Hotspot and join it from the iPhone. An iPhone Personal Hotspot also works (NOT TESTED).

## Installing on an iPhone without the App Store
Owner decision (16 Oct 2026): no App Store and no paid Apple Developer Program. We sign nothing.
| Option | Cost | Needs | Limits | Source |
|---|---|---|---|---|
| Xcode with a free Apple ID ("Personal Team") | Free | A Mac with Xcode, a USB cable, and the source code | The app stops opening after 7 days and must be reinstalled. Max 3 devices and 10 App IDs. | https://developer.apple.com/support/compare-memberships/ |
| AltStore (AltServer) with a free Apple ID | Free | A Mac (macOS 11+) or a Windows 10+ PC; an unsigned .ipa | 7-day refresh, using your own Apple ID | https://altstore.io/ |
| Sideloadly with a free Apple ID | Free | A Mac or Windows PC; an unsigned .ipa | 7 days with a free ID | https://sideloadly.io/ |
| Paid Apple Developer Program (TestFlight / ad hoc) | US$99 per year (Enterprise US$299) | Enrolment | Owner DECLINED | https://developer.apple.com/support/enrollment/ , https://developer.apple.com/programs/whats-included/ |
| EU alternative app marketplaces | n/a | n/a | NOT VERIFIED (no source fetched); a developer account is generally required, so this is out of scope | none |

Note: CI already builds an UNSIGNED Runner.app (iOS workflow artifact). Packaging it as an unsigned .ipa would let AltStore or Sideloadly re-sign it with the owner's own Apple ID. That is not us signing, but it is not done yet; it waits for owner confirmation.

## Linux notes (Phase 5)
- The release build ran headless under xvfb on the build box. The window rendered, TLS was listening on 47820 and UDP on 47821.
- Secure storage: with an unlocked gnome-keyring, the identity went into the keyring (no fallback file was created). With no unlocked keyring, the app uses `identity_fallback.json` (mode 600) instead of freezing on the keyring password dialog. Once used, the fallback is kept (sticky).
- Gaps: no Bonjour advertising (browse only). A firewall (ufw/firewalld) must allow TCP 47820 and UDP 47821 (the app does not change firewall settings). Folders without XDG user dirs fall back to ~/Downloads.
