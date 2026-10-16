# Benchmark plan: Isekai Drop vs LocalSend

Status: **NOT TESTED**. No benchmark has been run yet, so there are no results and no claims.

## What we compare
Time to move the same files between the same two devices, with both apps, under identical conditions. Speed = total bytes / time, in MB/s (1 MB = 1,048,576 bytes).

## Fixed conditions (write each one down per session)
- **Same two physical devices** for both apps (e.g. Android phone -> Windows PC). Same direction. Same battery state: plugged in, battery saver OFF.
- **Same network**: same router or same hotspot, same Wi-Fi band (2.4 / 5 / 6 GHz) and the same **link speed** in Mbps. Read link speed in the system Wi-Fi details; write it before AND after each block of runs.
- **Same distance and position** (e.g. 2 m, line of sight, devices not moved between apps).
- **Same files**, same storage location, created once (see BENCHMARK_STEPS.md):
  - `100MB`: one 100 MB file
  - `1GB`: one 1 GB file
  - `5GB`: one 5 GB file (skip if a device lacks the space; write "skipped")
  - `1000small`: one folder with 1000 files of 100 KB (about 98 MB in total)
- **Same app state**: only the app under test is open; the other app fully closed. No VPN. Screen on. Both apps on default settings, with encryption ON in LocalSend (Isekai Drop always encrypts).
- **Order**: alternate apps (I, L, I, L...) so slow drift (heat, interference) hits both equally.

## Runs
- At least **5 runs per app per file set**. Report **median, min and max**. More runs if results vary by more than 20%.
- Delete received files between runs (both apps rename duplicates, which would add disk work).
- A run counts only if it completed and the files are complete. A paused or resumed run does not count (Isekai Drop refuses to log those).

## How time is measured
- **Isekai Drop**: the app's own clock, from the receiver's Accept until all files are verified. Saved with "Save as benchmark run" (source = "measured by app").
- **LocalSend**: a stopwatch, from tapping Accept on the receiver until it shows done. Logged with "Add run timed by hand" (source = "entered by hand").
- For a fair comparison also time **Isekai Drop by stopwatch** the same way, at least once per file set, and log those as "entered by hand". Compare stopwatch to stopwatch. The app clock is extra detail.

## Output
docs/BENCHMARK_RESULTS_TEMPLATE.md, filled from the CSV export (Settings > Benchmark log > Export CSV). Unmeasured cells stay "NOT TESTED".
