# UI/UX spec for 0.11.0 (from the user, 2026-10-30)

Task: Improve the UI/UX of Isekai Drop (Flutter) for user-friendliness, accessibility and visual polish. Keep the current style: dark theme, rounded cards, blue-purple gradient hero card, Material 3. Do NOT change the transfer engine, protocol or security logic. UI layer only (lib/ui). First audit EVERY screen (Home, Send, Connect, History, Settings, Trusted devices, Diagnostics, Benchmark, Fast direct, receive/accept prompt, transfer progress, finished, error states, light theme) and fix what you find. Then do the list below.

A. Layout and clarity
1. Empty states ("Looking for devices", "Nothing selected", "No trusted devices") must be compact: small icon, one line of text, one action. No full-height cards.
2. Send screen = 3 clear steps: 1 Choose files, 2 Choose device, 3 Send. Sticky Send button at the bottom, enabled only when both are chosen. Show selected files as a compact list with name, size, remove button.
3. Home: one primary action (Send), one secondary (Connect a device). Remove duplicate "Connect a device" links on other screens; keep one clear entry.
4. Connect: QR code (Show / Scan) first. Move IP, port and key fingerprint under a collapsed "Advanced" section.
5. Settings: group as Appearance, This device, Receiving, Connection, Security, Advanced. Move Benchmark log and Diagnostics into Advanced. Each toggle gets a title + ONE short line; longer explanation behind an info icon (bottom sheet). Put the permission "Allow" button directly next to the Fast direct toggle.
6. Fast direct default = Auto (choose the fastest route by measuring). Show the chosen route on the transfer screen as a chip, e.g. "Router · 5 GHz".
7. Default device name from the phone model (e.g. "OnePlus 9"), not "Android phone". Let the user rename it.
8. First-run onboarding: 3 short slides (Open on both devices, same Wi-Fi, Pick files and send). Skippable, shown once.

B. Device discovery feedback
9. While searching, show an animated radar/pulse, then after 8 seconds a friendly hint card with 3 steps (same Wi-Fi, app open on other device, try QR) and buttons: Scan QR / Search again.
10. Show Wi-Fi status at the top of Home (connected network band 5 GHz/2.4 GHz, or "Not connected").

C. Transfer screens
11. Transfer screen: file name, big percentage, live speed, time left, small speed graph, route chip, Pause and Cancel buttons (large, separated so Cancel is not hit by accident; confirm on Cancel).
12. Receive prompt: sender name, file count, total size, big Accept and Decline buttons, "Always allow this device" option.
13. Finished screen: success check animation, file name(s), average speed, buttons Open, Show in folder, Send more.
14. Errors: plain-language message + one suggested fix + Retry button. No technical codes on the main message (put them under "Details").

D. Accessibility
15. Touch targets at least 48x48 dp. Spacing between buttons at least 8 dp.
16. Contrast: text at least 4.5:1 (WCAG AA) in dark and light themes. Lighten the grey description text.
17. Respect system font scale up to 200% without overflow or clipped text. Fix the "System" label wrapping as "Syste / m" in the Theme selector (use shorter label or wider segments, scrollable if needed).
18. Add Semantics labels for all icon buttons, progress bars (announce percentage), toggles and the QR code. Support TalkBack.
19. Do not rely on color alone (add icons or text for success/error).
20. Respect "reduce motion" system setting: disable pulse and graph animations then.
21. Support portrait and landscape, small phones (320 dp wide) and tablets (max content width 600 dp, centered).
22. Add haptic feedback on key actions (send, finish, error).

E. Visual polish
23. One spacing scale (4/8/12/16/24), one corner radius scale, one type scale. Create theme tokens and use them everywhere.
24. Subtle transitions between screens and for list items appearing; progress bar animates smoothly.
25. Use the same icon set everywhere. Bottom bar stays: Home, Send, Connect, History, Settings.
26. Make light theme as polished as dark. Default theme = System.

F. Rules
- Keep all existing features working. Run flutter analyze and all tests; update widget tests for changed screens.
- Add golden or widget tests for: empty states, Send step flow, 200% font scale, TalkBack labels present.
- At the end, list every UI change you made and anything you chose not to do and why.
