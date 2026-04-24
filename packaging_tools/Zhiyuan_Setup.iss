; ============================================================================
; Zhiyuan Professional Installer - Inno Setup Configuration
; ============================================================================
;
; SECURITY POLICY: Whitelist-based packaging - NO .py source files
; UI files (.ui) are preserved as-is for Slicer private components
; Version: 3.0.0 (Complete Rewrite)
; ============================================================================

#define MyAppName "Zhiyuan"
#define MyAppPublisher "Shanghai Jiao Tong University / Ruijin Hospital"
#define MyAppURL "https://www.sjtu.edu.cn"
#define MyAppExeName "Zhiyuan.exe"

#ifndef MyAppVersion
  #define MyAppVersion "1.0.0"
#endif

[Setup]
; === Application Information ===
AppId={{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}

; === Version Info for Executable ===
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Zhiyuan Brachytherapy Planning System - Professional Edition
VersionInfoVersion={#MyAppVersion}
VersionInfoCopyright=Copyright 2024-2026 Shanghai Jiao Tong University. All rights reserved.
VersionInfoProductName={#MyAppName}
VersionInfoProductVersion={#MyAppVersion}

; === Installation Settings ===
DefaultDirName={autopf}\Zhiyuan
DefaultGroupName=Zhiyuan
OutputBaseFilename=Zhiyuan-Installer
OutputDir=..\releases
DisableProgramGroupPage=no
AllowNoIcons=yes
UninstallDisplayIcon={app}\r\Zhiyuan-build\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
WizardStyle=modern

; === Compression & Size Optimization ===
Compression=lzma2/ultra64
SolidCompression=yes
InternalCompressLevel=ultra
DiskSpanning=no
MinVersion=6.1sp1
PrivilegesRequired=admin
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64

; === UI Customization ===
LanguageDetectionMethod=uilanguage
ShowLanguageDialog=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "runafterinstall"; Description: "Run Zhiyuan after installation"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Types]
Name: "full"; Description: "Full Installation (with all models)"
Name: "compact"; Description: "Compact Installation (without models)"
Name: "custom"; Description: "Custom Installation"; Flags: iscustom

[Components]
Name: "core"; Description: "Core Application Files"; Types: full compact custom; Flags: fixed
Name: "models"; Description: "Segmentation Models (~1.2 GB)"; Types: full
Name: "dosemodel"; Description: "Dose Prediction Model (~50 MB)"; Types: full
Name: "vcredist"; Description: "Visual C++ Runtime"; Types: full compact custom

[Files]
; === Core Main Executable ===
Source: "TempRelease\r\Zhiyuan-build\Zhiyuan.exe"; DestDir: "{app}\r\Zhiyuan-build\"; Components: core; Flags: ignoreversion

; === Slicer bin directory (ALL contents including Release/) ===
Source: "TempRelease\r\Zhiyuan-build\bin\*"; DestDir: "{app}\r\Zhiyuan-build\bin\"; Components: core; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\bin\Release\*"; DestDir: "{app}\r\Zhiyuan-build\bin\Release\"; Components: core; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist

; === Python installation (lib/Python) ===
; Must match PYTHONHOME in ZhiyuanLauncherSettingsToInstall.ini (=../lib/Python)
; Split into root + key subdirs to avoid ISS recursive wildcard issues with 50k+ files
Source: "TempRelease\r\Zhiyuan-build\lib\Python\*"; DestDir: "{app}\r\Zhiyuan-build\lib\Python\"; Components: core; Flags: ignoreversion skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\lib\Python\DLLs\*"; DestDir: "{app}\r\Zhiyuan-build\lib\Python\DLLs\"; Components: core; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\lib\Python\Lib\*"; DestDir: "{app}\r\Zhiyuan-build\lib\Python\Lib\"; Components: core; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\lib\Python\Scripts\*"; DestDir: "{app}\r\Zhiyuan-build\lib\Python\Scripts\"; Components: core; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\lib\Python\include\*"; DestDir: "{app}\r\Zhiyuan-build\lib\Python\include\"; Components: core; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist

; === Qt Plugins in lib/QtPlugins (as per ZhiyuanLauncherSettingsToInstall.ini) ===
; Qt requires qwindows.dll for Windows GUI - without this, app will flash and exit
Source: "TempRelease\r\Zhiyuan-build\lib\QtPlugins\platforms\qwindows.dll"; DestDir: "{app}\r\Zhiyuan-build\lib\QtPlugins\platforms\"; Components: core; Flags: ignoreversion skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\lib\QtPlugins\platforms\qminimal.dll"; DestDir: "{app}\r\Zhiyuan-build\lib\QtPlugins\platforms\"; Components: core; Flags: ignoreversion skipifsourcedoesntexist

; === Qt Styles and Image Formats (in lib/QtPlugins) ===
Source: "TempRelease\r\Zhiyuan-build\lib\QtPlugins\styles\*"; DestDir: "{app}\r\Zhiyuan-build\lib\QtPlugins\styles\"; Components: core; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\lib\QtPlugins\imageformats\*"; DestDir: "{app}\r\Zhiyuan-build\lib\QtPlugins\imageformats\"; Components: core; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\lib\QtPlugins\iconengines\*"; DestDir: "{app}\r\Zhiyuan-build\lib\QtPlugins\iconengines\"; Components: core; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist

; === Launcher Settings INI files ===
; ZhiyuanApp-real.exe looks for INI in bin/ directory, so we place it there too
Source: "TempRelease\r\Zhiyuan-build\ZhiyuanLauncherSettings.ini"; DestDir: "{app}\r\Zhiyuan-build\"; Components: core; Flags: ignoreversion skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\ZhiyuanLauncherSettingsToInstall.ini"; DestDir: "{app}\r\Zhiyuan-build\"; Components: core; Flags: ignoreversion skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\bin\ZhiyuanLauncherSettings.ini"; DestDir: "{app}\r\Zhiyuan-build\bin\"; Components: core; Flags: ignoreversion skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\bin\ZhiyuanLauncherSettingsToInstall.ini"; DestDir: "{app}\r\Zhiyuan-build\bin\"; Components: core; Flags: ignoreversion skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\bin\Release\ZhiyuanLauncherSettings.ini"; DestDir: "{app}\r\Zhiyuan-build\bin\Release\"; Components: core; Flags: ignoreversion skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\bin\Release\ZhiyuanLauncherSettingsToInstall.ini"; DestDir: "{app}\r\Zhiyuan-build\bin\Release\"; Components: core; Flags: ignoreversion skipifsourcedoesntexist

; === Slicer DLL libraries ===
Source: "TempRelease\r\Zhiyuan-build\lib\*.dll"; DestDir: "{app}\r\Zhiyuan-build\lib\"; Components: core; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "TempRelease\r\Zhiyuan-build\lib\*.pyd"; DestDir: "{app}\r\Zhiyuan-build\lib\"; Components: core; Flags: ignoreversion recursesubdirs createallsubdirs

; === Slicer share directory ===
Source: "TempRelease\r\Zhiyuan-build\share\**\*"; DestDir: "{app}\r\Zhiyuan-build\share\"; Components: core; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
; Explicit SplashScreen (launcher hard requirement - MUST NOT be missing)
Source: "TempRelease\r\Zhiyuan-build\share\Zhiyuan-5.9\SplashScreen.png"; DestDir: "{app}\r\Zhiyuan-build\share\Zhiyuan-5.9\"; Components: core; Flags: ignoreversion

; === Module compiled binaries (.pyd) - Cython protected ===
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\BrachyPlan*.pyd"; DestDir: "{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\"; Components: core; Flags: ignoreversion
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\SlicerCustomAppUtilities*.pyd"; DestDir: "{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\"; Components: core; Flags: ignoreversion skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\SubjectHierarchyPlugins\*.pyd"; DestDir: "{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\SubjectHierarchyPlugins\"; Components: core; Flags: ignoreversion
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\MarkupConstraints*.pyd"; DestDir: "{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\"; Components: core; Flags: ignoreversion skipifsourcedoesntexist

; === Plans package compiled modules ===
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\*.pyd"; DestDir: "{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\"; Components: core; Flags: ignoreversion skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\dose_pre\*.pyd"; DestDir: "{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\dose_pre\"; Components: core; Flags: ignoreversion skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\config.json"; DestDir: "{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\"; Components: core; Flags: ignoreversion skipifsourcedoesntexist

; === UI native files (preserved as-is for Slicer private components) ===
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\Resources\UI\*.ui"; DestDir: "{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\Resources\UI\"; Components: core; Flags: ignoreversion
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\Resources\UI\*.pyd"; DestDir: "{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\Resources\UI\"; Components: core; Flags: ignoreversion skipifsourcedoesntexist

; === Resources (Icons, QSS, JSON, etc.) ===
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\Resources\**\*"; DestDir: "{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\Resources\"; Components: core; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist

; === Setup configuration script ===
Source: "TempRelease\setup_config.bat"; DestDir: "{app}\"; Components: core; Flags: ignoreversion skipifsourcedoesntexist

; === Debug launcher script (for troubleshooting startup issues) ===
Source: "TempRelease\Debug_Run.bat"; DestDir: "{app}\"; Components: core; Flags: ignoreversion skipifsourcedoesntexist

; === Segmentation model weights - ALL models (recursesubdirs for deep nesting) ===
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\*.pth"; DestDir: "{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\"; Components: models; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\*.json"; DestDir: "{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\"; Components: models; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\*.pkl"; DestDir: "{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\"; Components: models; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\*.npz"; DestDir: "{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\"; Components: models; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\*.npy"; DestDir: "{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\"; Components: models; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\total\config.json"; DestDir: "{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\total\"; Components: models; Flags: ignoreversion skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\total\label_mapping.json"; DestDir: "{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\total\"; Components: models; Flags: ignoreversion skipifsourcedoesntexist

; === Segmentation model weights - Pancreatic Tumor ===
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\pancreatic_tumor\*.pth"; DestDir: "{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\pancreatic_tumor\"; Components: models; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\pancreatic_tumor\*.json"; DestDir: "{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\pancreatic_tumor\"; Components: models; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist

; === Dose prediction model weights ===
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\dose_pre\dose_128.pth"; DestDir: "{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\dose_pre\"; Components: dosemodel; Flags: ignoreversion skipifsourcedoesntexist
Source: "TempRelease\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\dose_pre\dose_model.pth"; DestDir: "{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\dose_pre\"; Components: dosemodel; Flags: ignoreversion skipifsourcedoesntexist

; === VC Runtime ===
Source: "TempRelease\vc_redist.x64.exe"; DestDir: "{tmp}"; Components: vcredist; Flags: deleteafterinstall skipifsourcedoesntexist

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\r\Zhiyuan-build\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{group}\Zhiyuan (Debug Mode)"; Filename: "{app}\Debug_Run.bat"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\r\Zhiyuan-build\{#MyAppExeName}"; Tasks: desktopicon
Name: "{autodesktop}\Zhiyuan (Debug Mode)"; Filename: "{app}\Debug_Run.bat"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\r\Zhiyuan-build\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
; Kill any leftover Zhiyuan.exe from previous failed installs to prevent DLL locks
Filename: "{cmd}"; Parameters: "/c taskkill /F /IM Zhiyuan.exe /T 2>nul || exit /b 0"; Flags: runhidden

; NOTE: Environment variables are NOT set here to prevent installer hang
; The application uses relative paths and fallback mechanisms, so env vars are optional

; Install VC++ Runtime - NON-BLOCKING, window VISIBLE so user can see errors
; nowait: do NOT block Inno Setup main thread
; skipifdoesntexist: skip if redist file not bundled
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /passive /norestart"; StatusMsg: "Installing Visual C++ Runtime..."; Components: vcredist; Check: VCRedistNeedsInstall; Flags: nowait skipifdoesntexist

; Launch application after installation (optional, based on user task selection)
; nowait: never block the installer; postinstall: show checkbox on finish page; skipifsilent: skip in silent mode
Filename: "{app}\r\Zhiyuan-build\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Tasks: runafterinstall; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
Type: filesandordirs; Name: "{group}"
Type: files; Name: "{autodesktop}\{#MyAppName}.lnk"

[Registry]
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}"; ValueType: string; ValueName: "Version"; ValueData: {#MyAppVersion}
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}"; ValueType: string; ValueName: "Publisher"; ValueData: {#MyAppPublisher}
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppName}"; ValueType: string; ValueName: "DisplayName"; ValueData: "{#MyAppName}"
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppName}"; ValueType: string; ValueName: "UninstallString"; ValueData: """{uninstallexe}"""
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppName}"; ValueType: string; ValueName: "DisplayIcon"; ValueData: """{app}\r\Zhiyuan-build\{#MyAppExeName}"",0"
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppName}"; ValueType: string; ValueName: "Publisher"; ValueData: {#MyAppPublisher}
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppName}"; ValueType: string; ValueName: "DisplayVersion"; ValueData: {#MyAppVersion}
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppName}"; ValueType: dword; ValueName: "NoModify"; ValueData: 1
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppName}"; ValueType: dword; ValueName: "NoRepair"; ValueData: 1
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppName}"; ValueType: dword; ValueName: "EstimatedSize"; ValueData: 0000000000

[Code]
const
    WM_WININICHANGE = $001A;

// Check if VC++ 2015-2022 Runtime is already installed
// Returns True only if the runtime is MISSING (needs install)
// This prevents the deadlock that occurs when the installer already exists
function VCRedistNeedsInstall(): Boolean;
var
    bExists: Boolean;
    dwVersion: Cardinal;
    strVersion: String;
begin
    Result := True;  // Default to install if any check fails

    // Check 1: HKLM\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64 (64-bit)
    if RegQueryDWordValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Bld', dwVersion) then begin
        Result := False;
        Exit;
    end;

    // Check 2: HKLM\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64 (32-bit on 64-bit Windows)
    if RegQueryDWordValue(HKLM, 'SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Bld', dwVersion) then begin
        Result := False;
        Exit;
    end;

    // Check 3: Try to read version string as fallback
    if RegQueryStringValue(HKLM, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Version', strVersion) then begin
        Result := False;
        Exit;
    end;

    // If we get here, runtime is not detected - return True to trigger installation
    Result := True;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
    case CurStep of
        ssPostInstall:
            begin
                RegWriteStringValue(HKCU, 'Environment', 'TOTALSEG_WEIGHTS_PATH',
                    ExpandConstant('{app}\r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans\seg\total\nnunet\results'));
                SendMessage(HWND_BROADCAST, WM_WININICHANGE, 0, 0);
            end;
    end;
end;

function InitializeSetup(): Boolean;
var
    ResultCode: Integer;
begin
    if RegKeyExists(HKLM, 'SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{#MyAppName}') then begin
        if MsgBox('Zhiyuan is already installed. Do you want to uninstall the previous version first?',
            mbConfirmation, MB_YESNO or MB_DEFBUTTON2) = IDYES then begin
            MsgBox('Please uninstall Zhiyuan through Control Panel before proceeding.',
                mbInformation, MB_OK);
            Result := False;
        end else begin
            Result := True;
        end;
    end else begin
        Result := True;
    end;
end;

[Messages]
english.WelcomeLabel1=Welcome to the [name] Setup Wizard
english.WelcomeLabel2=This will install [name] version [ver] on your computer.%n%nClick Next to continue.
english.FinishedHeadingLabel=[name] Setup Complete
english.FinishedLabelNoIcons=[name] has been installed on your computer.%n%n%1%nClick Finish to close this wizard.
english.ClickFinish=&Finish

chinesesimplified.WelcomeLabel1=欢迎使用 [name] 安装向导
chinesesimplified.WelcomeLabel2=这将安装 [name] 版本 [ver] 到您的计算机中。%n%n点击"下一步"继续。
chinesesimplified.FinishedHeadingLabel=[name] 安装完成
chinesesimplified.FinishedLabelNoIcons=[name] 已成功安装到您的计算机。%n%n%1%n点击"完成"关闭此向导。
