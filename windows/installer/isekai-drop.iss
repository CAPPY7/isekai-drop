; Isekai Drop - Windows installer (Inno Setup 6).
; Built in CI (.github/workflows/windows.yml):
;   ISCC /DAppVersion=0.10.3 /DBuildNumber=13 /DSourceDir=<flutter Release dir> isekai-drop.iss
; Per-user install, no admin: %LOCALAPPDATA%\Programs\Isekai Drop.
; NOT code-signed (see README "Windows: Smart App Control").

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef BuildNumber
  #define BuildNumber "0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\build\installer"
#endif

[Setup]
; Fixed id: keep it, so new versions upgrade the old install.
AppId={{7D4B8E2A-3C61-4F0B-9A57-1E2D6C9B4F31}
AppName=Isekai Drop
AppVersion={#AppVersion}
AppVerName=Isekai Drop {#AppVersion}
AppPublisher=Isekai Drop
AppCopyright=Copyright (C) 2026 Isekai Drop
VersionInfoVersion={#AppVersion}.{#BuildNumber}
VersionInfoProductVersion={#AppVersion}.{#BuildNumber}
VersionInfoTextVersion={#AppVersion} (build {#BuildNumber})
VersionInfoProductTextVersion={#AppVersion}
VersionInfoCompany=Isekai Drop
VersionInfoProductName=Isekai Drop
VersionInfoDescription=Isekai Drop Setup
VersionInfoCopyright=Copyright (C) 2026 Isekai Drop
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=
DefaultDirName={autopf}\Isekai Drop
DefaultGroupName=Isekai Drop
DisableProgramGroupPage=yes
DisableDirPage=auto
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\isekaidrop.exe
UninstallDisplayName=Isekai Drop
OutputDir={#OutputDir}
OutputBaseFilename=isekai-drop-windows-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Isekai Drop"; Filename: "{app}\isekaidrop.exe"
Name: "{autodesktop}\Isekai Drop"; Filename: "{app}\isekaidrop.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\isekaidrop.exe"; Description: "{cm:LaunchProgram,Isekai Drop}"; Flags: nowait postinstall skipifsilent
