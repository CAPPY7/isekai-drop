# Phase 4 manual test plan: Android -> Windows and Android -> macOS (no router)

Record every number **as you measured it**. Speeds shown in the app are measured
from real bytes; write down the "Average speed (measured)" shown at the end and
also time it yourself with a stopwatch.

## Prepare test data (on the Android phone)
- `10MB.bin` (about 10 MB, e.g. a short video)
- `1GB.bin` (about 1 GB, e.g. a long video) - any file of roughly this size
- Folder `Small500` with 500 small files (photos or text files), with at least
  one sub-folder

## Before each run, write down
| Field | Example |
|---|---|
| Phone model + Android version | Pixel 7, Android 15 |
| Computer + OS version | ThinkPad, Windows 11 24H2 / MacBook Air M2, macOS 15 |
| Connection method (Settings > Diagnostics > Method) | Phone hotspot / Windows hotspot / App-made hotspot |
| Wi-Fi link speed and band (Diagnostics, Android side and Windows side) | 433 Mbps, 5 GHz |
| Distance between devices | 1 m |
| Battery saver on/off | off |

## Runs (do each for A, B (Windows only) and C)
| # | Test | Numbers to record |
|---|---|---|
| 1 | Pair using QR: computer shows QR, phone scans | worked? seconds from scan to "Paired" |
| 2 | Send `10MB.bin` phone -> computer | stopwatch time, app average speed, file opens? |
| 3 | Send `1GB.bin` phone -> computer | stopwatch time, app average speed, phone memory warnings?, file opens / same size |
| 4 | Send `Small500` folder | stopwatch time, all 500 files arrived?, sub-folders kept? |
| 5 | Send `10MB.bin` computer -> phone | stopwatch time, app average speed |
| 6 | During run 3: Pause on the phone for 30 s, then Resume | resumed? final file OK? |
| 7 | During run 3: Pause on the computer for 30 s, then Resume | resumed? final file OK? |
| 8 | During run 3: Cancel | no partial file left on the computer? |
| 9 | Queue: send `10MB.bin`, then immediately send the folder | second waits "In the queue", both finish? |
| 10 | Send `Small500` twice | second copy is "Small500 (1)", first untouched? |
| 11 | Turn off the hotspot mid-transfer | clear error? Diagnostics > Last error text |

## Option-specific checks
- **A (phone hotspot):** computer joined the hotspot; device found automatically? (yes/no). Windows firewall prompt appeared? macOS Local Network prompt appeared?
- **B (Windows Mobile Hotspot):** Mobile hotspot turned on without internet? Phone stayed connected after "No internet"? PC found automatically or typed 192.168.137.1?
- **C (app-made hotspot):** Android version; permission asked (Nearby devices / Location)? Hotspot started? Name/password shown? Did the phone's normal Wi-Fi turn off? Computer joined and found the phone?

## Where received files go
- Android: Downloads/Isekai Drop
- Windows / macOS: the Downloads folder > Isekai Drop
