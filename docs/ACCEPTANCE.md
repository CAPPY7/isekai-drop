# Acceptance tests (from docs/SPECIFICATION.txt), status 16 Oct 2026

PASS (automated) = a real test on the build box passed: two real engines, real TLS over localhost. It is **not** a device test.
NOT TESTED = no evidence yet. FAIL = the test was run and failed.
Test run: `flutter test` -> "All tests passed!" (counts in the Phase 7 report).

| # | Acceptance test | Status | Evidence |
|---|---|---|---|
| 1 | Unknown devices cannot receive files or establish trusted sessions without approval | PASS (automated); devices NOT TESTED | loopback_test.dart "unknown (unpaired) device is rejected and never asked about", "pairing declined: nobody is trusted"; phase6_test "a second pairing request while one is open is refused". TLS server trusts only saved certificates (engine.dart `_serverContext`). |
| 2 | Saved devices authenticate using cryptographic identity, not just names | PASS (automated) | loopback_test "identity change is detected and blocks until paired again"; phase6_test "identity change blocks until paired again", "spoofed announcement neither blocks nor redirects (audit #1)". Mutual TLS 1.3, pinned SHA-256 certificate fingerprints. |
| 3 | Revoked devices can no longer connect as trusted | PASS (automated) | loopback_test "revoked device can no longer connect"; phase6_test "revoked device cannot send; record stays revoked"; app_test "revoke asks first, blocks; remove asks first, deletes" |
| 4 | Transfers are encrypted and file integrity is verified | PASS (automated); packet capture NOT TESTED | All traffic is in TLS 1.3 (SecureSocket). loopback_test "tampered chunk is rejected and nothing is kept"; phase6_test "damaged partial data is caught by the full hash". No Wi-Fi capture was done to show the bytes on the air are unreadable. |
| 5 | Large files transfer without loading the entire file into memory | PASS (measured, box only) with a caveat | 1 GiB loopback run: hash matched, RSS +318 MiB (both ends in one process), less than the file size. Phones NOT TESTED. Higher than expected: audit #18. |
| 6 | Interrupted transfers recover safely where supported | PASS (automated); devices NOT TESTED | phase6_test "after a network drop: Retry continues, whole file re-hashed" (measured: 1,048,576 of 3,145,851 bytes not re-sent), "after the receiver app is killed and restarted", "damaged partial data ...", "cancel discards partial state", "audit #9: failed send survives a SENDER restart and resumes" |
| 7 | The app reports actual measured speed, no fabricated speeds | PASS (code review + tests) | Speed is computed only from bytes moved / clock time (jobs.dart `currentSpeed`/`averageSpeed`; resumed bytes excluded). Shows "measuring..." until real data exists. benchmark_test "real transfer -> run: measured numbers only". |
| 8 | Direct transfer works without internet when supported | NOT TESTED | Nothing in the app uses the internet (no servers). Not yet run on a hotspot without internet on real devices. |
| 9 | Cross-platform behaviour and limits documented accurately | NOT TESTED (docs written, not checked on devices) | README, docs/IOS_NOTES.md, docs/CONNECTION_OPTIONS.md, docs/BUILD_AND_INSTALL.md. Real-device checks are needed to confirm. |
| 10 | UI remains responsive during large transfers | NOT TESTED | Risk: TLS and hashing run on the UI isolate (audit #10). Needs a phone test with a 1 GB+ file. |
| 11 | Performance comparisons with LocalSend use identical conditions | NOT TESTED | Plan, steps and template are ready: docs/BENCHMARK_PLAN.md, BENCHMARK_STEPS.md, BENCHMARK_RESULTS_TEMPLATE.md. In-app logger with CSV export. No runs yet. |

Summary: 7 PASS (automated or box-measured; none on devices), 0 FAIL, 4 NOT TESTED.
