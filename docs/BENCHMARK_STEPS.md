# Benchmark steps (printable)

Status of all results: **NOT TESTED** until you fill them in.
You need: the two devices, both apps, a stopwatch (phone clock app), and 1-2 hours.

## A. Prepare (once)
1. Install LocalSend on both devices. The project recommends an app store or package manager: Play Store / F-Droid / App Store / Microsoft Store / winget / Flathub (https://github.com/localsend/localsend#download). Latest release checked 16 Oct 2026: v1.18.2. Write the version you used.
2. Install Isekai Drop (latest test build) on both devices. Pair them once.
3. Firewall on PCs: allow LocalSend port 53317 (TCP+UDP) and Isekai Drop ports 47820 (TCP) and 47821 (UDP).
4. Make the test files on the SENDING device:
   - Windows (PowerShell): `fsutil file createnew 100MB.bin 104857600`, `fsutil file createnew 1GB.bin 1073741824`, `fsutil file createnew 5GB.bin 5368709120`.
     Note: fsutil files are all zeros. Both apps send them as-is (neither compresses), but random data is more realistic. Use the Linux/macOS method on a PC with Git Bash if you can.
   - macOS / Linux: `head -c 104857600 /dev/urandom > 100MB.bin` (likewise 1073741824 and 5368709120).
   - 1000 small files (macOS/Linux/Git Bash): `mkdir small && for i in $(seq 1 1000); do head -c 102400 /dev/urandom > small/f$i.bin; done`
   - Android as sender: make the files on a PC and copy them to the phone's Download folder by USB first.
5. Plug both devices in. Battery saver off. Close other apps. Turn off VPN.
6. Place the devices at a fixed distance (e.g. 2 m). Don't move them until you finish.

## B. Write the conditions (each session)
7. Write: date, devices (model), OS versions, app versions, network (router / Android hotspot / Windows hotspot), Wi-Fi band, **link speed in Mbps** on both devices (Android: Settings > Wi-Fi > network > details; Windows: Settings > Network > Wi-Fi > properties; macOS: Option-click the Wi-Fi icon; iPhone: not shown, so write "unknown").

## C. Run (repeat 5 times per file set, alternating apps)
8. **Isekai Drop run**: on the sender pick the file(s) -> Send to the paired device -> on the receiver tap Accept and start the stopwatch at the same moment -> stop when the receiver shows "All files received and verified". On the receiver's transfer screen tap **Save as benchmark run**, fill in the conditions, and save. Also log your stopwatch time with **Add run timed by hand** (app = Isekai Drop).
9. Delete the received files on the receiver.
10. **LocalSend run**: close Isekai Drop on both devices. Open LocalSend on both, select the same file(s), send, tap Accept on the receiver and start the stopwatch -> stop when it shows finished. In Isekai Drop: Settings > Benchmark log > **Add run timed by hand** (app = LocalSend), enter files, size, seconds and conditions.
11. Delete the received files. Close LocalSend. Repeat from 8 until each app has 5 runs for this file set.
12. Do steps 8-11 for 100MB, 1GB, 5GB and 1000small.

## D. Export
13. Settings > Benchmark log: check the median/min/max per group. Tap **Export CSV** (Android: Downloads/Isekai Drop; iPhone: share sheet; PC: you choose where to save). Send the CSV to the developer.
14. Re-check the link speed. If it changed a lot, write that down.
