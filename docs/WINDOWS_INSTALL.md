# Windows: install and Smart App Control

## The installer (0.10.3+)
Release `latest-build` has ONE Windows file: `isekai-drop-windows-setup.exe`
(Inno Setup). It installs for your Windows user only, no admin needed:

- Folder: `%LOCALAPPDATA%\Programs\Isekai Drop`
- Start menu entry "Isekai Drop"; desktop icon only if you tick the box
- Uninstall: Settings > Apps > Installed apps > Isekai Drop > Uninstall
- Installing a newer setup over an old one updates it (same app id)
- First start: Windows Firewall asks about Isekai Drop. Allow **Private
  networks**, otherwise other devices cannot find or send to this PC.

The plain app folder (`isekaidrop.exe` + DLLs + `data`) is still available
as the CI artifact `isekai-drop-windows` (Actions tab), but is no longer on
the release.

## Why Windows blocks it (honest version)
The installer and the app are **NOT code-signed** (no paid certificate).

- **SmartScreen** ("Windows protected your PC"): click **More info > Run
  anyway**. This works.
- **Smart App Control (SAC, Windows 11)**: if SAC is **On**, it blocks
  unsigned apps it does not already know. That includes this installer AND
  the installed app (`isekaidrop.exe`): a single installer does not get
  around it. There is no "Run anyway" button and no per-app exception.
  This is a Windows security feature; Isekai Drop does not try to bypass it.

Check: Windows Security > App & browser control > Smart App Control settings.

## Options
1. **Turn Smart App Control off** (Windows Security > App & browser control >
   Smart App Control settings > Off). Your choice, it lowers protection.
   - On older Windows 11 builds this was one-way: turning it back on needed
     a Windows reset/reinstall.
   - Microsoft says recent Windows updates allow turning it on again without
     a reinstall. Known issue (Oct 2026 update KB5127648): on some PCs the
     "On" option is greyed out afterwards; Microsoft published a registry
     workaround and says a fix will come. Do not rely on being able to turn
     it back on.
2. **Paid code signing** by the developer, e.g. Microsoft **Azure Trusted
   Signing** (monthly fee, identity check, only some
   countries) or a classic OV/EV certificate. Signed apps pass SAC.
3. **SignPath Foundation** free code signing for open-source projects: needs
   a **public** repo with an OSI licence and an application/approval. This
   repo is private, so it does not qualify today.
4. Use Isekai Drop on Android/other devices, or a PC where SAC is Off or in
   evaluation mode.

None of these is set up; the builds stay unsigned until the owner decides.
