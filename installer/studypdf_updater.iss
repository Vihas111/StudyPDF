; ====================================================
;  StudyPDF – Updater / Patch
; ====================================================

#define MyAppName      "StudyPDF"
#define MyAppVersion   "1.2.0"
#define MyAppExeName   "studypdf.exe"
#define MySourceRoot   "..\build\installer\stage"

[Setup]
AppId={{1EFD9A25-7C8A-4E0D-9B6E-BF73A0E216B4}
AppName={#MyAppName} Updater
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\{#MyAppName}
OutputDir=..\build\installer\dist
OutputBaseFilename=StudyPDF-Updater-v1.2.0
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=lowest
CreateUninstallRegKey=no
UpdateUninstallLogAppName=no
DisableDirPage=yes
DisableReadyPage=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Registry]
; Update the Add/Remove Programs entry created by the original installer so it shows the new version
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{{1EFD9A25-7C8A-4E0D-9B6E-BF73A0E216B4}_is1"; ValueType: string; ValueName: "DisplayVersion"; ValueData: "{#MyAppVersion}"; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\{{1EFD9A25-7C8A-4E0D-9B6E-BF73A0E216B4}_is1"; ValueType: string; ValueName: "DisplayName"; ValueData: "{#MyAppName} version {#MyAppVersion}"; Flags: uninsdeletevalue


[Files]
Source: "{#MySourceRoot}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch StudyPDF {#MyAppVersion} now"; Flags: nowait postinstall skipifsilent

[Messages]
WizardReady=Ready to Update
ClickNext=Click "Update" to begin updating {#MyAppName} to v{#MyAppVersion}.
ButtonNext=Update
FinishedHeadingLabel=Update complete!
FinishedLabel=StudyPDF has been updated to v{#MyAppVersion}.%nClick Finish to close this wizard.
