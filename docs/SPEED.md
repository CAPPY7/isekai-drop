# Speed: measurements and the 0.10.1 changes

Owner's real-device result (0.10.0): OnePlus 8 -> OnePlus 9 over Fast direct
(Wi-Fi Direct, 5 GHz) ran at **7.5 MB/s**. 0.10.1 adds a way to find out which
step is slow on the phones, and moves the encryption off the app's main
thread.

## 0.10.2: the network is the slow step
Owner's Speed test on 0.10.1 (OnePlus 8 -> 9, Fast direct, 5240 MHz,
link 432 Mbps, tx/rx 432/216): plain TCP 6.9 MB/s, TLS lane 7.1, TLS main
8.8, disk writes 121-214, read + hash 141-312, Downloads 65-1673 MB/s.
Encryption and disk are not the limit; plain TCP over the link is.
6.9 MB/s is about 55-60 Mbit/s, far below the 432 Mbit/s link rate.

Likely causes found in the code (not confirmed on phones):
1. **Two channels at once (MCC):** the direct group was created with
   "any 5 GHz" while the phones stayed on the router at 5240 MHz. If the group
   picks another channel the chip time-shares between two channels.
   0.10.2 asks for the router's channel when it is non-DFS 5 GHz.
2. **No Wi-Fi lock on Android 14+** (0.9.2 left it out) and none during the
   Speed test. 0.10.2 holds LOW_LATENCY (34+) / HIGH_PERF plus a CPU wake
   lock. Android docs: LOW_LATENCY works only with the screen on, app in the
   foreground and connected to an access point, and "throughput may be
   reduced"; Wi-Fi locks act on the router connection, p2p power save is up
   to the driver.
3. **Routing:** the joiner is not bound to the p2p network; the report now
   names the interface used ("p2p..." = Wi-Fi Direct) and warns if the
   direct test went through the router.
4. **Socket buffers:** not forced (forcing turns off autotuning; at LAN round
   trip times the bandwidth-delay product is small). Native rows show the
   buffer sizes Android gave.

New rows tell the rest apart: if native raw TCP is also ~7 MB/s the limit is
the radio/driver, not Dart; if 4 streams are much faster than 1, it is
per-connection (latency/window) and the 4-stream data lane helps.

### Box numbers 0.10.2 (Linux x86_64 box, loopback, NOT phones)
| Test (512 MB) | 1 stream | 2 streams | 4 streams |
|---|---|---|---|
| raw TCP | 922 MB/s | 933 MB/s | 860 MB/s |
| TLS | 155 MB/s | 241 MB/s | 240 MB/s |

Engine bench (512 MB, lanes, hash + disk on the box, hashMatch true):
1 stream 79.3 MB/s, 4 streams 74.5 / 84.5 MB/s. The box is disk/hash
bound, so 4 streams do not help there; they are meant for the Wi-Fi link.

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
