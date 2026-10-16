# Isekai Drop connection protocol (version 1)

Plain words first: every connection is wrapped in **TLS 1.3**, the same
lock websites use. Each device has its own key. After pairing, each device
remembers the other's key **fingerprint** (a short unique summary of the
key) and refuses any connection where the key is different.

No home-made cryptography: TLS is BoringSSL inside Flutter/Dart (`dart:io`
`SecureSocket`); keys and certificates are made with `basic_utils` /
`pointycastle`; hashes use `package:crypto` (SHA-256).

## Identity (per installation)
- ECDSA P-256 key pair + self-signed X.509 certificate (valid 10 years).
- A random device ID (16 bytes).
- Private key stored with `flutter_secure_storage` (Android: Keystore-backed
  encryption; Apple: Keychain; Windows: DPAPI-protected; Linux: Secret
  Service/libsecret). If secure storage fails (e.g. Linux without a keyring),
  it falls back to a private app file and Settings > Diagnostics says so.
- Fingerprint = SHA-256 of the certificate (DER).

## Discovery (untrusted hints only)
- UDP every 3 s to multicast `239.255.42.99:47821` and broadcast
  `255.255.255.255:47821`: `{app, v, device_id, name, platform, port, fp}`.
- Nothing in an announcement is trusted. Android takes a Wi-Fi multicast
  lock (permission `CHANGE_WIFI_MULTICAST_STATE`, no prompt).
- Fallback: type the other device's IP address and port (default 47820).
- QR code: not included yet (needs a camera/scanner library + owner approval).

## Pairing
1. Device A connects with TLS **without** a client certificate. A records
   B's certificate from the handshake.
2. A shows a 16-digit code = SHA-256("isekai-drop-pairing-v1|fp1|fp2")
   (fingerprints sorted) → first 8 bytes mod 10^16. A's user taps
   "Codes match" only if B's screen shows the same code.
3. A sends `pair_req` with its certificate. B shows the same code
   (computed from its own fingerprint and A's certificate) and asks its user.
4. If B approves, B saves A as trusted and replies `pair_ok`; A saves B.
5. A device in the middle would produce different codes on the two screens.
   16 digits (~53 bits) make forcing a match impractical within the 2-minute
   approval window.

## Sessions (every connection after pairing)
- Mutual TLS: A presents its certificate. B's TLS context trusts **only**
  the certificates of currently trusted devices, so an unknown or revoked
  key fails the TLS handshake itself (the app never even sees the request).
- A accepts B only if B's certificate fingerprint equals the saved one. If it
  differs, the device is marked **identity changed** and blocked until the
  user revokes it and pairs again.

## Transfer
- Frames: `[1 byte type][4 bytes length][payload]`; type 1 = JSON control,
  type 2 = file data. Max frame 2 MB.
- `offer` (names + sizes) → receiver user Accept/Decline (always asked).
- Per file: `file` → data frames (read and written in pieces, never the whole
  file in memory) → `file_end` with SHA-256 → receiver compares its own
  SHA-256 of the received bytes → `file_ok` or `file_bad`.
- Received data goes to a hidden temp file `.isekai-<random>.part`. Only after
  the hash matches is it moved to the final name (Android: copied into
  Downloads/Isekai Drop, then the temp file is deleted). On any failure the
  temp file is deleted. Existing files are never overwritten ("name (1).ext").
- File names are cleaned: folders, `..`, hidden dots, control and Windows-
  forbidden characters and reserved names (CON, NUL...) are removed.
- Leftover `.part` files from crashes are deleted at next start.

## Not in version 1 (later phases)
Resume, pause, folders, queue, auto-receive, hotspot/Wi-Fi Direct helpers,
QR scanning, real history.
