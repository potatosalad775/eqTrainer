; Inno Setup script for the Windows installer. Build the release first:
;   fvm flutter build windows --release
;   iscc windows\packaging\eq_trainer.iss
; The result lands in build\installer\.

#define BuildDir "..\..\build\windows\x64\runner\Release"
#define AppExe "eq_trainer.exe"

; Read from the build rather than passed in, so the two cannot disagree. The
; string is the pubspec's "2.6.0+260901"; users only need the part before the +.
#define BuildVersion GetStringFileInfo(BuildDir + "\" + AppExe, "ProductVersion")
#define PlusAt Pos("+", BuildVersion)
#define AppVersion (PlusAt > 0 ? Copy(BuildVersion, 1, PlusAt - 1) : BuildVersion)

[Setup]
; Identifies the app across upgrades. Changing it makes a new version install
; beside the old one instead of over it.
AppId=kr.potatosalad775.eq_trainer
AppName=eqTrainer
AppVersion={#AppVersion}
AppVerName=eqTrainer {#AppVersion}
AppPublisher=potatosalad775
AppPublisherURL=https://github.com/potatosalad775/eqTrainer
VersionInfoVersion={#AppVersion}
; Per-user, so no UAC prompt: %LOCALAPPDATA%\Programs\eqTrainer.
PrivilegesRequired=lowest
DefaultDirName={autopf}\eqTrainer
DisableProgramGroupPage=yes
; The mutex wWinMain creates in windows\runner\main.cpp. Keep the two identical:
; the name is case sensitive.
AppMutex=Local\kr.potatosalad775.eq_trainer
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
WizardStyle=modern
Compression=lzma2
SolidCompression=yes
OutputDir=..\..\build\installer
OutputBaseFilename=eqTrainer-{#AppVersion}-windows-x64-setup

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"
Name: "ko"; MessagesFile: "compiler:Languages\Korean.isl"
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "uk"; MessagesFile: "compiler:Languages\Ukrainian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[InstallDelete]
; An upgrade must not keep assets the new version no longer ships. The library
; is in %APPDATA%, not here, so neither this nor the uninstaller touches it.
Type: filesandordirs; Name: "{app}\data"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\eqTrainer"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\eqTrainer"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,eqTrainer}"; Flags: nowait postinstall skipifsilent
