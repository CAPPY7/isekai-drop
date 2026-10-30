# Speed work for 0.9.2 (measured on the build box only)

Report: OnePlus 8 -> OnePlus 9 on the same home Wi-Fi (Wi-Fi 6 router, 2.4 + 5 GHz) gets 6-10 MB/s, mostly 6. Goal: 60-70 MB/s.

**Every number below was measured on the Linux build box (x86-64, shared with other jobs), not on phones.** Phones were NOT tested.

## 1. Stage bench (tool/bench_stages.dart, AOT, 256 MiB, 64 KiB chunks, 2 runs)
| Stage | MB/s |
|---|---|
| read file | 1799 / 1667 |
| Dart SHA-256 (package:crypto) | 116.5 / 117.3 |
| Dart SHA-256 in a background isolate | 116.6 / 115.8 |
| write file | 804 / 790 |
| TLS over loopback (raw) | 170.5 / 177.7 |
| TLS + app frames | 158.5 / 170.4 |
| full pipeline (read + hash + TLS + write + hash) | 114.5 / 113.8 |
| same pipeline without hashing | 150.8 / 147.6 |

Native SHA-256 on the same CPU: `openssl speed sha256` about 1.9 GB/s; `sha256sum` of 256 MiB 0.187 s. Pure-Dart SHA-256 is the slowest stage, ~16x slower than native. On a phone ARM core it is slower still (not measured).

## 2. Two-process end-to-end (two network namespaces, real TLS, 512 MiB, flutter_tester JIT)
Runs interleaved A/B/C to cancel other jobs' load (`tool/bench/netns_run.sh`).
| Run | 0.9.1 | 0.9.2 (Dart hashing, as on Windows/Linux) | 0.9.2 with native hashing (as on Android) |
|---|---|---|---|
| 1 | 59.1 | 60.3 | 63.1 |
| 2 | 57.4 | 58.6 | 63.6 |

Extra delay (3 ms one-way, ~7 ms RTT, `tool/bench/delay_proxy.py`): 0.9.1 58.4 (0 ms) vs 59.3 (7 ms RTT) -> latency is not a limit.
The box e2e is limited by the JIT test runner + loopback TLS; it cannot show the Android-only fixes (file reading, Wi-Fi power save).

## 3. Rejected idea (measured)
An overlapped receive writer (write chunk N while reading N+1) was slower: 51.9 / 52.9 vs direct 58.9 / 56.8 MB/s (interleaved). Removed.

## 4. What changed in 0.9.2
1. Android file reading: 4 MiB per call (was 512 KiB), on a background TaskQueue (was the UI thread), 2 reads in flight.
2. Android hashing is native (Java MessageDigest) on both sides: the sender hashes while reading, the receiver hashes the finished file. Integrity check is unchanged (same SHA-256, wrong digest -> "integrity" error, test/speed_paths_test.dart).
3. Data frames 256 KiB (big chunks are split, max frame stays 2 MiB).
4. Fewer progress samples (1 per 50 ms, UI refresh 150 ms).
5. Wi-Fi lock (high performance) while a transfer runs, Android 13 and older (Android 14+ replaced it with a low-latency lock that the docs say may reduce throughput, so it is not used there).
6. Transfer/Diagnostics show the Wi-Fi band and link speed, and "Use 5 GHz for best speed" on 2.4 GHz.

## 5. Wi-Fi limits (estimate, not measured)
- Meraki, "Wireless Throughput Calculations and Limitations": real aggregate throughput is "typically 50% or less of the advertised data rate", and Wi-Fi is half-duplex.
- Phone -> router -> phone sends every byte over the air twice.
- Estimate: Wi-Fi 6, 2x2, 80 MHz on 5 GHz (link ~1201 Mbps) -> ~600 Mbps one hop -> ~36 MB/s phone-to-phone through the router at best. 2.4 GHz (144-286 Mbps link) -> ~8-17 MB/s one hop, ~4-9 MB/s through the router: this matches the reported 6-10 MB/s.
- So 60-70 MB/s through a home router is unlikely for any app; a direct link (Wi-Fi Direct / hotspot) is the roadmap item.

## Reproduce
```
dart compile exe tool/bench_stages.dart -o /tmp/bs && /tmp/bs 256
sudo tool/bench/netns_run.sh 0 label                 # 0.9.2, Dart hashing
sudo E2E_NATIVE_HASH=1 tool/bench/netns_run.sh 0 n   # 0.9.2, native hashing (sha256sum)
sudo REPO=/path/to/0.9.1-worktree tool/bench/netns_run.sh 0 base
sudo tool/bench/netns_run.sh 3 rtt                   # 3 ms one-way delay proxy
```
