# Speed: measurements and the 0.10.1 changes

Owner's real-device result (0.10.0): OnePlus 8 -> OnePlus 9 over Fast direct
(Wi-Fi Direct, 5 GHz) ran at **7.5 MB/s**. 0.10.1 adds a way to find out which
step is slow on the phones, and moves the encryption off the app's main
thread.

## The in-app Speed test (Diagnostics > Speed test)
Runs between two paired devices on the route they use now (router, or Fast
direct if "Try Fast direct" is on and both are Android). Each step is
measured on its own:

| Step | What it shows |
|---|---|
| Network, plain TCP | The radio/network alone, no encryption (one-time port, see below) |
| Network, TLS data lane | Encryption in a background isolate (how 0.10.1 sends files) |
| Network, TLS main connection | Encryption on the app's main isolate (how 0.10.0 sent files) |
| Disk: read + hash (sender) | Reading a test file and SHA-256 |
| Disk: write (Downloads / MediaStore) | Android: a pending MediaStore item in Downloads/Isekai Drop |
| Disk: write (app temp folder) | The folder the receiver writes into first |
| Native hash | Android's native SHA-256 |
| Wi-Fi link | Link / tx / rx Mbps and band on both ends (when Android tells it) |

The disk steps run on both devices. The report names the slowest step.
"Copy report" copies plain text with no device names, file names or network
names.

Safety: only zeros are sent. Test files are deleted straight away (also on
error). The plain-TCP port is opened only for this test: a random 128-bit
one-time token is sent inside the already-encrypted, already-paired control
connection, and the port accepts one connection and closes. A device that
is not accepting files, or is busy with another speed test, refuses.

## What 0.10.1 changed (ARM bottlenecks)
- **File data now goes over a TLS "data lane" in a background isolate**
  (`lib/engine/core/lane.dart`). The main isolate only handles control
  messages and the UI. The lane uses mutual TLS with the same paired
  certificates and a one-time token. If the lane cannot open, the old
  main-connection path is used (and older peers still work).
- Data moves between isolates as `TransferableTypedData` (no per-message
  copy/serialise). Frame headers are written without copying the payload.
- Writes are pipelined with a 4 MiB flush window (fewer awaits per chunk).
- Socket send/receive buffers are raised to 4 MiB where the OS allows
  (otherwise the OS default is used and Diagnostics says so).
- Hashing was already on a background isolate / native (0.9.2); unchanged.
- Progress UI was already limited to one update per 150 ms (0.9.2);
  the Speed test card updates only when the step changes.
- Not changed (found): on Android, saving into Downloads copies the file
  once more after the transfer (MediaStore, 1 MiB pieces) and the native
  hash reads it again at the end. Both happen after the bytes arrive. The
  Speed test now measures the Downloads write so we can see if it matters.
- Wi-Fi Direct group owner link speed: probably not exposed by a public
  Android API; the joined side reports it (API 31+).

## Box numbers (Linux x86_64 box, loopback, not phones)
| Measurement | Result |
|---|---|
| Raw TCP, AOT | ~1500 MB/s |
| TLS one stream, AOT | ~190 MB/s |
| TLS with the main isolate 25% / 50% busy | 138 / 88 MB/s |
| TLS parallel streams 1 / 2 / 4 | 193 / 280 / 318 MB/s |
| lane_test (JIT) raw / TLS | 639-862 / 138-169 MB/s |
| Engine bench BEFORE (0.10.0), 512 MB | **36.0 MB/s** (14236 ms) |
| Engine bench AFTER, lanes off (`ISEKAI_BENCH_LANES=0`) | 32.3 MB/s |
| Engine bench AFTER, lanes, 512 MB | **90.1 / 82.5 MB/s** (RSS +~310 MB) |
| Engine bench AFTER, lanes, 1536 MB | 83.9 MB/s (RSS +~160 MB) |

Command: `ISEKAI_BENCH=512 [ISEKAI_BENCH_LANES=0] flutter test --no-pub test/loopback_bench_test.dart`.
The engine bench is the whole app path (TLS, hashing, disk) in JIT test mode,
so the release build should be faster. Phones are slower per core than the
box; how much the lane helps on ARM is NOT measured yet.

## Lane stall found and fixed
Closing the lane client right after sending could leave the server never
reading it (about 1 in 5 box runs stalled for 15-28 s). Fix: the server stops
on a byte count sent over the control connection, and the client closes the
lane only after the server reports its result. 40 runs in a row passed.

## NOT TESTED
Everything on phones: the lane on ARM, the MediaStore test write, link speed
readings, Fast direct during the test, and any real-world gain.
