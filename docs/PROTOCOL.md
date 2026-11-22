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
- QR code (Phase 4): `isekaidrop:pair?v=1&h=<ip,ip>&p=<port>&f=<sha256 fp>&n=<name>`.
  Nothing secret. The scanner pairs only if the other device's TLS key
  fingerprint equals `f` exactly; the other device still asks its user to
  approve and shows the same 16-digit code.

## Pairing
1. Device A connects with TLS **without** a client certificate. A records
   B's certificate from the handshake and at once sends `pair_hello`
   (0.8.1+). After `pair_hello`, B waits up to 2 minutes for `pair_req`
   (instead of the normal 10 s first-message limit), one such wait at a
   time; a second one gets `pair_denied`/`busy`. Without `pair_hello` the
   10 s limit applies (0.8.0 and older could not pair if A's user needed
   more than 10 s). 0.8.0 servers reject `pair_hello`: update both devices.
2. Both devices can compute a 16-digit code = SHA-256("isekai-drop-pairing-v1|fp1|fp2")
   (fingerprints sorted) → first 8 bytes mod 10^16.
3. 0.9.1 one-tap: A sends `pair_req` with its certificate AT ONCE (no
   button on A). B asks its user ONE question, "Accept NAME?", and shows
   the code small as an optional check. Older versions asked A's user to
   tap "Codes match" first.
   `pair_req` may carry `offer` = `{count, bytes, tid, names[<=3]}` when A
   wants to send files right away ("send to a nearby device that is not
   paired"). B then asks "NAME wants to send you N files (X MB) - Accept?".
   0.11.4 (C2): for such a send A shows the code and asks its user "Does
   the other screen show the same code?" ("Same code, send" / "Cancel").
   `pair_req` goes out at once so B can show the code, but its `offer` then
   has only `{count, bytes, tid}` (no `names`); `names` are sent only when
   A's key match was already proven (QR pairing, or a caller that already
   compared the code). A sends nothing more (no `offer`, no file data) and
   saves nothing until its user tapped "Same code, send" AND B answered
   `pair_ok`; that pairing is saved on A as **Verified**. "Cancel" (or a
   different code) closes the connection: B removes its question and pairs
   nothing (no cooldown is started). If B's user had already tapped Accept,
   B keeps A as paired, but no files arrive. Paired devices and QR pairing
   keep the one-tap flow (no extra question).
   If B accepts, B remembers a one-time pre-approval for A's key and that
   exact transfer id `tid` (see transferIdFor) for 3 minutes; the following
   `offer` with that tid starts without a second question. A different
   tid, a second send, or a later send asks normally.
4. If B approves, B saves A as **trusted** and replies `pair_ok`; A saves B
   as trusted. **Verified** only if A scanned B's QR code (key matched) or
   the user compared the code (Trusted devices > Check code). Re-pairing
   never downgrades an already Verified device.
5. Trust on first use (TOFU): if nobody compares the code, a device in the
   middle on the same network during that FIRST pairing could pose as the
   other device. After pairing the keys are pinned, so a later attacker is
   refused. Comparing the code (or QR pairing) rules this out: a device in
   the middle would produce different codes on the two screens; 16 digits
   (~53 bits) make forcing a match impractical. Auto-receive works only
   for Verified devices.

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

## Phase 4 additions (still protocol version 1, backward compatible)
- `offer` files carry `path` (relative path, "/" separated) for folders.
  The receiver cleans every part (sanitizeRelativePath): "", ".", "..",
  drive letters are dropped, each part cleaned like a file name, max depth 32.
  A received top folder never merges into an existing one ("Album (1)").
- Pause: either side may send `{"t":"pause"}` / `{"t":"resume"}` at any time.
  The sender stops reading the file; the receiver stops reading the socket
  (TCP back-pressure then holds the sender). While the peer is paused the
  idle timeout is 6 hours instead of 60 s. Pause lasts only while both apps
  stay open; there is no resume after closing (later phase).
- Queue: one outgoing transfer at a time per device; later sends wait.
- TCP_NODELAY on all connections (avoids ~40 ms stalls per file; 500 small
  files on loopback went from 22.6 s to 1.5 s).

## Not yet (later phases)
Resume after the app closes, auto-receive, Wi-Fi Direct, real history.

## Phase 5: Bonjour discovery (untrusted hint, same as UDP)
Service type `_isekaidrop._tcp`, port = the TLS port (47820). TXT keys: `id` (device id), `fp` (certificate fingerprint), `pl` (platform), `v` (protocol version, 1). A found service becomes a normal announcement; pairing/TLS pinning rules are unchanged. Own `id` is ignored.

## Phase 6: resume (still protocol version 1, backward compatible)
- `offer` may carry `tid`: 32 hex = SHA-256("isekai-tid-v1|<receiver fp>|<path>|<size>|...")[:32]. Same files to the same device => same id, even after a restart. No file data in it.
- The receiver keys its state by (sender fingerprint from mutual TLS, tid). Another device can never use it.
- `accept` may carry `skip` (indices already verified and saved) and `offsets` ({index: bytes already stored}).
- `file` may carry `offset`; the receiver requires it to equal what it announced. The sender hashes the WHOLE file from byte 0 and sends only bytes after the offset. The receiver hashes the stored bytes again, then the new ones. `file_end` sha256 covers the whole file.
- Hash mismatch => the partial data and state are deleted; the next retry starts fresh.
- Cancel (either side) deletes the state. A completed transfer deletes it. States older than 7 days are deleted at start.
- `decline` reason `not_accepting` = receiving turned off in Settings.
- Old peers without `tid`: unchanged behaviour (no resume).

## 0.11.4 (Phase C, still protocol version 1, backward compatible)
- C1 Android 10+: the receiver writes the file bytes straight into a hidden
  MediaStore Downloads item (`IS_PENDING=1`, Kotlin channel
  `isekai_drop/media`, its own serial background queue). After `file_end`
  it hashes the item with native SHA-256 from byte 0 and compares; only a
  match sets `IS_PENDING=0` (visible). A mismatch, a storage problem or a
  cancel deletes the item. After a lost connection the item stays hidden;
  its id is kept in the resume state (`partial_direct`) so Retry continues
  in it; Retry after 7 days, cancel or a state clean-up deletes it. If the
  item cannot be created, the old path is used (temp file in the no-backup
  folder, copied into Downloads at the end); that path needs free space of
  2 x the bytes still to come + 64 MiB. Android 9 and older: unchanged.
- C2: see Pairing step 3 (no `names` in `pair_req.offer` before the code
  check; Cancel closes the connection and B drops its question).
- C5: an `offer` with a file above 8 TiB or more than 16 TiB in total gets
  `decline` reason `bad_offer` (sizes added with overflow protection). The
  receiver keeps at most 5 resume states per sending device and kept
  partial data of at most half the free space (checked when a new state is
  made; the oldest go first).
- C6: while the other device has paused, it may stay paused for at most 30
  minutes in total per transfer (was: 6 hours per wait); then the transfer
  stops (Retry continues where it stopped).

## 0.12.0 (Phase D, still protocol version 1, no change on the wire)
- Nothing new is sent between devices. "Always allow this device" (D3) is a
  local decision of the receiver: an offer from a VERIFIED device with
  `always_allow` set is accepted without the question, exactly like the
  existing auto-receive switch. The sender cannot ask for it.
- Local file `trusted_devices.json` schema 3: each device gets
  `"always_allow": false` on migration; a non-verified device is always
  read as false.
