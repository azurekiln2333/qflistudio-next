; Inno Setup script for the QFLIStudioN Windows installer.
;
; CI passes AppVersion, SourceDir, OutputDir, OutputBaseFilename and Arch with
; /D. SourceDir is then a staged copy of the release directory that also holds
; the MSVC runtime DLLs. Without the defines the script packages the local
; "flutter build windows --release" output, so it compiles from any directory.
;
; Paths resolve from this file, not from the working directory. ASCII only.

#define AppName "QFLIStudioN"
#define AppPublisher "azurekiln2333"
#define AppURL "https://github.com/azurekiln2333/qflistudio-next"
#define AppExeName "qflistudio.exe"
#define RepoRoot AddBackslash(SourcePath) + "..\.."

; x64 or arm64. The CMake build takes the host architecture, so the caller
; knows which one the release directory holds.
#ifndef Arch
  #define Arch "x64"
#endif

#ifndef SourceDir
  #define SourceDir RepoRoot + "\build\windows\" + Arch + "\runner\Release"
#endif
#ifndef AppVersion
  #define AppVersion GetFileVersion(AddBackslash(SourceDir) + AppExeName)
#endif
#ifndef OutputDir
  #define OutputDir RepoRoot + "\build\windows\installer"
#endif
#ifndef OutputBaseFilename
  #define OutputBaseFilename AppName + "-" + AppVersion + "-windows-" + Arch + "-setup"
#endif

#if Arch == "arm64"
  #define Architectures "arm64"
#else
  ; x64compatible also admits Arm64 Windows with x64 emulation. It needs
  ; Inno Setup 6.3; an older compiler only knows x64.
  #if Ver >= 0x06030000
    #define Architectures "x64compatible"
  #else
    #define Architectures "x64"
  #endif
#endif

[Setup]
; AppId identifies the product for upgrades and uninstall. Never change it.
AppId={{9C4F2E67-5B18-4D3A-8E71-6A0B2D9F3C58}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
DefaultDirName={autopf}\{#AppName}
DisableProgramGroupPage=yes
; A per-user install needs no elevation. The dialog also offers all users.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed={#Architectures}
ArchitecturesInstallIn64BitMode={#Architectures}
; The Flutter Windows engine requires Windows 10 or later.
MinVersion=10.0
LicenseFile={#RepoRoot}\LICENSE
SetupIconFile={#RepoRoot}\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExeName}
UninstallDisplayName={#AppName}
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Static plugin archives and linker by-products are not runtime files.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Excludes: "*.lib,*.exp,*.pdb,*.ilk"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExeName}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
; A silent install never starts the app.
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
