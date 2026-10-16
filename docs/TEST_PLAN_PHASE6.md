# Phase 6 device test list (NOT TESTED on devices yet)

1. Update to build 0.6.0. Open Trusted devices: old pairings show "Trusted (code not re-checked)". On both devices tap Check code, compare, tap Codes match: becomes "Verified".
2. Revoke a device: it asks first; the other device can no longer send (fails). Remove: asks first; the device disappears.
3. Pair again with the revoked device: it is Verified again and can send.
4. Reinstall the app on one phone (new key). The other side: sending fails with "identity changed", device shows blocked. Pairing again shows the red "different key" warning.
5. Send a large file (1 GB+). Midway, turn Wi-Fi off on the sender for 1 minute, then on. Tap Retry: progress continues (shows "Continued an earlier attempt"). Check the file opens. Write down the measured speed.
6. Same as 5, but swipe the RECEIVER app away (kill) midway, reopen it, then send the same files again from the sender: it continues.
7. Settings > Receiving off: the sender sees "not accepting files". Turn on again.
8. Auto-receive: turn on (it asks). Send from a Verified device: no prompt. From a "Trusted" device: still asked.
9. History: entries for sent/received/failed. Turn "Save file names" off and choose "Delete old names": names disappear. Clear history asks first.
10. Settings > Visible off: the other device stops seeing this one within ~30 s; QR/typed address still works.
