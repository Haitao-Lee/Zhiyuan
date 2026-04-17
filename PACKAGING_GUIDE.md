# Zhiyuan Application Packaging Guide

## Overview

This document describes how to package the Zhiyuan application (based on 3D Slicer) into a standalone Windows installer that can be distributed and installed on other Windows computers.

---

## System Requirements

### Build Machine
- Windows 10/11 (64-bit)
- CMake 3.20+
- Visual Studio 2019/2022 with C++ toolchain
- NSIS (Nullsoft Scriptable Install System) or Inno Setup
- Git

### Target Machine (Installation)
- Windows 10/11 (64-bit)
- No additional software required (all dependencies bundled)
- **Recommended**: 16GB+ RAM, 10GB+ free disk space

---

## Project Structure

```
C:\Zhiyaun\
├── Modules\Scripted\BrachyPlan\    # Source code (Git tracked)
│   ├── BrachyPlan.py              # Main module (~5000 lines)
│   ├── MarkupConstraints.py       # Constraints module
│   ├── CMakeLists.txt            # Build configuration
│   ├── Resources\                 # UI resources
│   │   ├── UI\                    # .ui files
│   │   │   ├── BrachyPlan.ui      # Main UI definition
│   │   │   ├── PlanningParameters.ui
│   │   │   └── Settings.ui
│   │   ├── Icons\                 # Icons
│   │   └── json\                  # Filter definitions (auto-generated)
│   └── plans\                     # Planning algorithms
│       ├── __init__.py           # Package initialization
│       ├── config.py             # Configuration & argparse namespace
│       ├── config.json           # Radiation parameters
│       ├── brachy_plan_v2.py     # Main planning logic (CURRENT)
│       ├── brachy_plan.py        # Legacy planning logic (deprecated)
│       ├── core_v2.py            # Core optimization algorithms v2
│       ├── core.py               # Core optimization algorithms (legacy)
│       ├── utilizations_v2.py    # Utility functions v2 (CURRENT)
│       ├── utilizations.py       # Utility functions (legacy)
│       ├── visualizer.py         # 3D visualization utilities
│       ├── reinforcement.py      # Reinforcement learning module
│       ├── fitting_model.py      # Fitting model utilities
│       ├── geometry.py           # Geometry utilities
│       ├── dose_pre\             # Dose prediction models
│       │   ├── myDoseNet.py      # DoseNet model implementation
│       │   ├── functions.py      # Helper functions
│       │   └── Predict_crop.py   # Prediction preprocessing
│       └── seg\                  # Segmentation models
│           ├── total\            # TotalSegmentator config & weights
│           │   ├── config.json
│           │   ├── label_mapping.json
│           │   └── nnunet\results\  # Model weights (~1.2GB total)
│           └── pancreatic_tumor\  # Pancreatic tumor model
│               └── Dataset005_Pancreas\
│
└── r\Slicer-build\               # Built application
    ├── Zhiyuan.exe              # Main executable
    └── lib\Zhiyuan-5.9\         # Application libraries
```

---

## Required Files for Distribution

### 1. Core Application Files
| Path | Description | Size |
|------|-------------|------|
| `r\Slicer-build\Zhiyuan.exe` | Main executable | ~50MB |
| `r\Slicer-build\lib\` | All runtime libraries (Qt, VTK, ITK, Python) | ~800MB |

### 2. BrachyPlan Module Files (Required)

#### Main Module
| Path | Description |
|------|-------------|
| `Modules/Scripted/BrachyPlan/BrachyPlan.py` | Main module (entry point) |
| `Modules/Scripted/BrachyPlan/CMakeLists.txt` | Build configuration |
| `Modules/Scripted/BrachyPlan/MarkupConstraints.py` | Markup constraints |

#### Resources
| Path | Description |
|------|-------------|
| `Modules/Scripted/BrachyPlan/Resources/UI/*.ui` | UI definitions |
| `Modules/Scripted/BrachyPlan/Resources/Icons/*.png` | Module icons |
| `Modules/Scripted/BrachyPlan/Resources/*.qrc` | Resource files |
| `Modules/Scripted/BrachyPlan/Resources/*.qss` | Stylesheets |

#### Planning Algorithms (Core - Required)
| Path | Description |
|------|-------------|
| `plans/__init__.py` | Package init |
| `plans/config.py` | Configuration & settings |
| `plans/config.json` | Radiation parameters |
| `plans/brachy_plan_v2.py` | **Main planning logic** (current) |
| `plans/core_v2.py` | **Core algorithms** (current) |
| `plans/utilizations_v2.py` | **Utility functions** (current) |
| `plans/visualizer.py` | 3D visualization |
| `plans/reinforcement.py` | Reinforcement learning (optional) |
| `plans/fitting_model.py` | Model fitting utilities |
| `plans/geometry.py` | Geometry calculations |

#### Dose Prediction (Required for dose calculation)
| Path | Description |
|------|-------------|
| `plans/dose_pre/myDoseNet.py` | DoseNet model |
| `plans/dose_pre/functions.py` | Helper functions |
| `plans/dose_pre/Predict_crop.py` | Preprocessing |

### 3. Configuration Files
| Path | Description |
|------|-------------|
| `plans/config.json` | Radiation parameters (seed size, dose limits, etc.) |
| `plans/seg/total/config.json` | TotalSegmentator configuration |
| `plans/seg/total/label_mapping.json` | Organ label mappings (v2 format) |

### 4. Model Weights (Large Files - Optional but Recommended)

> ⚠️ **Note**: These files are large (~1.2GB). Consider offering a "light" version without these files.

| Path | Description | Approx. Size |
|------|-------------|-------------|
| `plans/seg/total/nnunet/results/Dataset291_TotalSegmentator_part1_organs_1559subj/*/fold_0/checkpoint_final.pth` | Organs segmentation | ~200MB |
| `plans/seg/total/nnunet/results/Dataset292_TotalSegmentator_part2_vertebrae_1532subj/*/fold_0/checkpoint_final.pth` | Vertebrae segmentation | ~150MB |
| `plans/seg/total/nnunet/results/Dataset293_TotalSegmentator_part3_cardiac_1559subj/*/fold_0/checkpoint_final.pth` | Cardiac segmentation | ~150MB |
| `plans/seg/total/nnunet/results/Dataset294_TotalSegmentator_part4_muscles_1559subj/*/fold_0/checkpoint_final.pth` | Muscles segmentation | ~150MB |
| `plans/seg/total/nnunet/results/Dataset295_TotalSegmentator_part5_ribs_1559subj/*/fold_0/checkpoint_final.pth` | Ribs segmentation | ~150MB |
| `plans/seg/pancreatic_tumor/Dataset005_Pancreas/nnUNetTrainer__*/fold_0/checkpoint_final.pth` | Pancreatic tumor | ~100MB |
| `plans/seg/total/Dataset297_TotalSegmentator_total_3mm_1559subj/*/fold_0/checkpoint_final.pth` | Body shell extraction | ~100MB |
| `plans/dose_pre/` (model weights if any) | Dose prediction model | TBD |

**Total model weight size**: ~1.0 - 1.2 GB

---

## Python Dependencies (Complete List)

All Python packages are bundled within the Slicer build at:
`r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\`

### Third-party Packages (Must be present)
| Package | Version | Purpose | Used In |
|---------|---------|---------|---------|
| **numpy** | Latest | Array operations | All modules |
| **scipy** | Latest | Distance transforms, image processing | core_v2.py, utilizations_v2.py |
| **scikit-learn** | Latest | PCA, DBSCAN clustering | utilizations_v2.py, BrachyPlan.py |
| **torch (PyTorch)** | CPU version | Neural networks, dose prediction | core_v2.py, reinforcement.py, myDoseNet.py |
| **SimpleITK** | Latest | Image I/O, processing | BrachyPlan.py, all modules |
| **nibabel** | Latest | NIfTI file handling | BrachyPlan.py |
| **tqdm** | Latest | Progress bars | utilizations_v2.py, reinforcement.py |
| **gymnasium** | Latest | RL environment interface | reinforcement.py |
| **numba** | Latest | JIT compilation for performance | reinforcement.py |

### Slicer Built-in (Already included)
| Package | Purpose |
|---------|---------|
| qt | Qt bindings (PyQt5/PySide2) |
| ctk | CTK widgets |
| vtk | VTK visualization |
| slicer | Slicer API |
| sitkUtils | Slicer-SimpleITK bridge |

### Verification Command
To verify all dependencies are available:
```python
# Run in Slicer Python console
import numpy, scipy, sklearn, torch, SimpleITK, nibabel, tqdm, gymnasium, numba
print("✅ All dependencies loaded successfully")
```

---

## Packaging Methods

### Method 1: NSIS (Recommended for Professional Installers)

NSIS is the same tool used by 3D Slicer and offers the most control over installation behavior.

#### Step 1: Download and Install NSIS
```
https://nsis.sourceforge.io/Download
```

#### Step 2: Create NSIS Script (`Zhiyuan.nsi`)

```nsi
; ============================================================
; Zhiyuan Installer Script
; NSIS 3.x Compatible
; Last Updated: 2026-04-15
; ============================================================

!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"

; --------------------------------------------------
; General Settings
; --------------------------------------------------
Name "Zhiyuan"
OutFile "Zhiyuan-Setup-v1.0.0.exe"
InstallDir "$PROGRAMFILES64\Zhiyuan"
RequestExecutionLevel admin
SetCompressor lzma
SetCompressorDictSize 32  # Better compression for large files

; Version Information
VIProductVersion "1.0.0.0"
VIAddVersionKey "ProductName" "Zhiyuan"
VIAddVersionKey "CompanyName" "Shanghai Jiao Tong University"
VIAddVersionKey "LegalCopyright" "© 2024 Shanghai Jiao Tong University"
VIAddVersionKey "FileDescription" "Zhiyuan Brachytherapy Planning System"
VIAddVersionKey "FileVersion" "1.0.0"
VIAddVersionKey "ProductVersion" "1.0.0"

; --------------------------------------------------
; Interface Settings
; --------------------------------------------------
!define MUI_ABORTWARNING
!define MUI_ICON "${NSISDIR}\Contrib\Graphics\Icons\modern-install.ico"
!define MUI_UNICON "${NSISDIR}\Contrib\Graphics\Icons\modern-uninstall.ico"

!define MUI_WELCOMEPAGE_TITLE_3LINES
!define MUI_HEADERIMAGE
!define MUI_HEADERIMAGE_RIGHT
!define MUI_BGCOLOR "FFFFFF"

; Pages
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${NSISDIR}\Docs\Modern UI\License.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_COMPONENTS
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

; Languages
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "SimpChinese"

; --------------------------------------------------
; Component Selection
; --------------------------------------------------
SectionGroup /e "Zhiyuan Application" SECGRP_APP
    
    Section "Core Files (Required)" SEC_CORE
        SectionIn RO
        SetOutPath "$INSTDIR"
        
        ; Copy main executable and essential files
        File "r\Slicer-build\Zhiyuan.exe"
        
        ; Copy lib directory (runtime libraries)
        File /r /x "__pycache__" /x "*.pyc" /x "*.pyo" \
              /x "Temp" /x "*.log" /x ".git" \
              "r\Slicer-build\lib\*.*"
    SectionEnd
    
    Section "BrachyPlan Module (Required)" SEC_MODULE
        SectionIn RO
        SetOutPath "$INSTDIR\Modules\Scripted\BrachyPlan"
        
        ; Copy module source files
        File "Modules\Scripted\BrachyPlan\BrachyPlan.py"
        File "Modules\Scripted\BrachyPlan\CMakeLists.txt"
        File "Modules\Scripted\BrachyPlan\MarkupConstraints.py"
        
        ; Copy resources
        SetOutPath "$INSTDIR\Modules\Scripted\BrachyPlan\Resources"
        File /r /x "__pycache__" /x "*.pyc" \
              "Modules\Scripted\BrachyPlan\Resources\*.*"
        
        ; Copy planning algorithms
        SetOutPath "$INSTDIR\Modules\Scripted\BrachyPlan\plans"
        File /x "*backup*" /x "__pycache__" /x "*.pyc" \
              "Modules\Scripted\BrachyPlan\plans\*.py"
        File "Modules\Scripted\BrachyPlan\plans\config.json"
        
        ; Copy dose prediction module
        SetOutPath "$INSTDIR\Modules\Scripted\BrachyPlan\plans\dose_pre"
        File /x "__pycache__" /x "*.pyc" \
              "Modules\Scripted\BrachyPlan\plans\dose_pre\*.*"
    SectionEnd
    
    Section /o "Segmentation Models (~1.2GB)" SEC_MODELS
        SetOutPath "$INSTDIR\Modules\Scripted\BrachyPlan\plans\seg"
        
        ; Copy TotalSegmentator models
        File /r /x "__MACOSX" /x "._*" /x "__pycache__" \
              "Modules\Scripted\BrachyPlan\plans\seg\*.*"
    SectionEnd
    
SectionGroupEnd

Section "Visual C++ Redistributable" SEC_VCRED
    SetOutPath "$TEMP"
    
    ; Download and install VC++ redistributable silently
    ; Note: Include the installer in your package or download it
    File "vc_redist.x64.exe"
    ExecWait '"$TEMP\vc_redist.x64.exe" /quiet /norestart'
    Delete "$TEMP\vc_redist.x64.exe"
SectionEnd

; --------------------------------------------------
; Post-Installation
; --------------------------------------------------
Section -Post
    ; Create Start Menu shortcuts
    CreateDirectory "$SMPROGRAMS\Zhiyuan"
    CreateShortcut "$SMPROGRAMS\Zhiyuan\Zhiyuan.lnk" "$INSTDIR\Zhiyuan.exe"
    CreateShortcut "$SMPROGRAMS\Zhiyuan\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
    
    ; Create Desktop shortcut (optional)
    CreateShortcut "$DESKTOP\Zhiyuan.lnk" "$INSTDIR\Zhiyuan.exe"
    
    ; Write uninstaller
    WriteUninstaller "$INSTDIR\Uninstall.exe"
    
    ; Set environment variable for model weights path
    Push $R0
    ReadRegStr $R0 HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "PATH"
    StrCmp $R0 "" doWritePath skipWritePath
doWritePath:
    StrCpy $R0 "$R0;$INSTDIR"
    WriteRegExpandStr HKLM "SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "PATH" $R0
skipWritePath:
    Pop $R0
    
    ; Notify system of environment change
    SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "Environment" 0
    
    ; Write registry info for Add/Remove Programs
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Zhiyuan" \
                 "DisplayName" "Zhiyuan"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Zhiyuan" \
                 "UninstallString" '"$INSTDIR\Uninstall.exe"'
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Zhiyuan" \
                 "DisplayIcon" '$"$INSTDIR\Zhiyuan.exe",0'
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Zhiyuan" \
                 "Publisher" "Shanghai Jiao Tong University"
    WriteRegStr HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Zhiyuan" \
                 "DisplayVersion" "1.0.0"
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Zhiyuan" "NoModify" 1
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Zhiyuan" "NoRepair" 1
    
    ; Get installed size
    ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
    IntFmt $0 "0x%08X" $0
    WriteRegDWORD HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Zhiyuan" \
                      "EstimatedSize" "$0"
SectionEnd

; --------------------------------------------------
; Uninstaller Section
; --------------------------------------------------
Section Uninstall
    ; Remove installed files
    RMDir /r "$INSTDIR"
    
    ; Remove shortcuts
    RMDir /r "$SMPROGRAMS\Zhiyuan"
    Delete "$DESKTOP\Zhiyuan.lnk"
    
    ; Remove registry entries
    DeleteRegKey HKLM "Software\Microsoft\Windows\CurrentVersion\Uninstall\Zhiyuan"
    
    ; Notify system of environment change
    SendMessage ${HWND_BROADCAST} ${WM_WININICHANGE} 0 "Environment" 0
SectionEnd
```

#### Step 3: Create LICENSE.txt
Create a license file in `C:\Zhiyaun\LICENSE.txt`. Example template:

```text
ZHIYUAN SOFTWARE LICENSE AGREEMENT

Copyright (c) 2024 Shanghai Jiao Tong University. All rights reserved.

This software and associated documentation files (the "Software") 
are provided for research and educational purposes only.

[Add your specific license terms here]

For commercial use, please contact [your contact information].
```

#### Step 4: Compile Installer
```powershell
cd C:\Zhiyaun
# Ensure NSIS is in PATH or use full path
"C:\Program Files (x86)\NSIS\makensis.exe" Zhiyuan.nsi
```

#### Output
- `C:\Zhiyaun\Zhiyuan-Setup-v1.0.0.exe` - Full installer with models (~3-5 GB)
- Without models section: ~2 GB

---

### Method 2: Inno Setup (Easier Alternative)

Inno Setup is easier to configure than NSIS.

#### Step 1: Download and Install Inno Setup
```
https://jrsoftware.org/isdl.php
```

#### Step 2: Create Inno Setup Script (`Zhiyuan.iss`)

```iss
; ============================================================
; Zhiyuan Installer Script
; Inno Setup 6.x Compatible
; ============================================================

#define MyAppName "Zhiyuan"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Shanghai Jiao Tong University"
#define MyAppExeName "Zhiyuan.exe"

[Setup]
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL=https://www.sjtu.edu.cn
DefaultDirName={autopf}\Zhiyuan
DefaultGroupName=Zhiyuan
OutputBaseFilename=Zhiyuan-Setup-{#MyAppVersion}
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64
InternalCompressLevel=ultra
DiskSpanning=yes
DiskSliceSize=2GB  # Split into 2GB chunks for DVD distribution
MinVersion=6.1sp1
PrivilegesRequired=admin
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#MyAppExeName}
VersionInfoCompany={#MyAppPublisher}
VersionInfoDescription=Zhiyuan Brachytherapy Planning System
VersionInfoVersion={#MyAppVersion}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked once
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked once

[Types]
Name: "full"; Description: "Full Installation (with all models)"
Name: "compact"; Description: "Compact Installation (without models)"
Name: "custom"; Description: "Custom Installation"; Flags: iscustom

[Components]
Name: "core"; Description: "Core Application Files"; Types: full compact custom; Flags: fixed
Name: "module"; Description: "BrachyPlan Module"; Types: full compact custom; Flags: fixed
Name: "models"; Description: "Segmentation Models (~1.2 GB)"; Types: full
Name: "vcredist"; Description: "Visual C++ Runtime"; Types: full compact custom

[Files]
; === Core Application ===
Source: "r\Slicer-build\Zhiyuan.exe"; DestDir: "{app}"; Components: core; Flags: ignoreversion
Source: "r\Slicer-build\lib\*"; DestDir: "{app}\lib"; Components: core; Flags: ignoreversion recursesubdirs createallsubdirs excludes: "__pycache__,*.pyc,*.pyo,Temp,*.log,.git,__MACOSX,._*"

; === BrachyPlan Module ===
Source: "Modules\Scripted\BrachyPlan\BrachyPlan.py"; DestDir: "{app}\Modules\Scripted\BrachyPlan"; Components: module; Flags: ignoreversion
Source: "Modules\Scripted\BrachyPlan\CMakeLists.txt"; DestDir: "{app}\Modules\Scripted\BrachyPlan"; Components: module; Flags: ignoreversion
Source: "Modules\Scripted\BrachyPlan\MarkupConstraints.py"; DestDir: "{app}\Modules\Scripted\BrachyPlan"; Components: module; Flags: ignoreversion
Source: "Modules\Scripted\BrachyPlan\Resources\*"; DestDir: "{app}\Modules\Scripted\BrachyPlan\Resources"; Components: module; Flags: ignoreversion recursesubdirs createallsubdirs excludes: "__pycache__,*.pyc"
Source: "Modules\Scripted\BrachyPlan\plans\*.py"; DestDir: "{app}\Modules\Scripted\BrachyPlan\plans"; Components: module; Flags: ignoresize excludes: "*backup*,__pycache__,*.pyc"
Source: "Modules\Scripted\BrachyPlan\plans\config.json"; DestDir: "{app}\Modules\Scripted\BrachyPlan\plans"; Components: module; Flags: ignoreversion
Source: "Modules\Scripted\BrachyPlan\plans\dose_pre\*"; DestDir: "{app}\Modules\Scripted\BrachyPlan\plans\dose_pre"; Components: module; Flags: ignoreversion recursubdirs createallsubdirs excludes: "__pycache__,*.pyc"

; === Segmentation Models ===
Source: "Modules\Scripted\BrachyPlan\plans\seg\*"; DestDir: "{app}\Modules\Scripted\BrachyPlan\plans\seg"; Components: models; Flags: ignoreversion recursubdirs createallsubdirs excludes: "__MACOSX,._*,__pycache__"

; === VC++ Runtime ===
Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Components: vcredist; Flags: deleteafterinstall

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/quiet /norestart"; StatusMsg: "Installing Visual C++ Runtime..."; Components: vcredist; Flags: runhidden waituntilterminated
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[Registry]
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}"; ValueType: string; ValueName: "InstallPath"; ValueData: "{app}"
Root: HKLM; Subkey: "SOFTWARE\{#MyAppName}"; ValueType: string; ValueName: "Version"; ValueData: {#MyAppVersion}

[Code]
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then begin
    // Add to PATH environment variable
    // This allows command-line access to executables
  end;
end;
```

#### Step 3: Compile
```powershell
cd C:\Zhiyaun
"C:\Program Files (x86)\Inno Setup 6\ISCC.exe" Zhiyuan.iss
```

---

### Method 3: Portable Archive (Simplest)

For development/testing without formal installer:

```powershell
cd C:\Zhiyaun

# Create portable archive using 7-Zip
7z a -t7z -m0=lzma2 -mx=9 -mfb=256 -md=32m -ms=on `
    Zhiyuan-Portable-v1.0.0.7z `
    @packaging_list.txt

# Or self-extracting archive
7z a -sfx7z.sfx -mLZMA `
    Zhiyuan-Portable-v1.0.0.exe `
    r\Slicer-build
```

Create `packaging_list.txt` with exclusions:
```
r\Slicer-build\
r\Slicer-build\lib\__pycache__\
r\Slicer-build\lib\Temp\
r\Slicer-build\*.log
```

---

## Environment Variables

The following environment variables should be set after installation:

| Variable | Value | Purpose |
|----------|-------|---------|
| `TOTALSEG_WEIGHTS_PATH` | `$INSTALL_DIR\Modules\Scripted\BrachyPlan\plans\seg\total\nnunet\results` | nnU-Net model location |
| `ZHIYUAN_HOME` | `$INSTALL_DIR` | Application root directory |

These are automatically configured by the NSIS/Inno scripts above.

---

## Installation Size Estimation

| Component | Size | Notes |
|-----------|------|-------|
| Slicer runtime (Qt, VTK, ITK, Python) | ~800 MB | Required |
| Python packages (PyTorch, etc.) | ~500 MB | Required |
| BrachyPlan source code | ~5 MB | Required |
| nnU-Net model weights | ~1.2 GB | Optional |
| Dose prediction model | ~200 MB | If available |
| **Total (with models)** | **~2.7 GB** | Full installation |
| **Total (without models)** | **~1.3 GB** | Compact installation |

---

## Pre-Packaging Checklist

Before creating the installer:

### Code Verification
- [ ] Run `python -m py_compile BrachyPlan.py` - no syntax errors
- [ ] Run `python -m py_compile plans/brachy_plan_v2.py` - no syntax errors  
- [ ] Run `python -m py_compile plans/utilizations_v2.py` - no syntax errors
- [ ] Verify all imports work in Slicer Python console

### Functional Testing
- [ ] `Zhiyuan.exe` launches without errors
- [ ] BrachyPlan module loads correctly
- [ ] CT volume loading works
- [ ] CTV/OAR selection works
- [ ] Basic planning (without RL) completes successfully
- [ ] DVH calculation displays results
- [ ] ISO surface renders correctly
- [ ] Reference direction arrow displays and is draggable

### Optional Features Testing (if models included)
- [ ] TotalSegmentator organ segmentation works
- [ ] Pancreatic tumor segmentation works
- [ ] Reinforcement learning planning works
- [ ] Dose prediction model runs

### Cleanup Before Packaging
```powershell
# Remove unnecessary files to reduce package size
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue `
    "r\Slicer-build\lib\__pycache__",
    "Modules\Scripted\BrachyPlan\plans\__pycache__",
    "Modules\Scripted\BrachyPlan\plans\seg\total\__MACOSX"
```

---

## Troubleshooting

### Installation Issues

| Problem | Solution |
|---------|----------|
| "Access Denied" during install | Run installer as Administrator |
| "Insufficient disk space" | Ensure 5GB+ free space (full install) |
| "VC++ Runtime missing" | Include vc_redist.x64.exe in installer |
| "Application won't start" | Check Windows Event Viewer for error details |

### Runtime Issues

| Problem | Solution |
|---------|----------|
| Crashes on startup | Install Visual C++ Redistributable 2019-2022 (x64) |
| Graphics issues | Update GPU drivers to latest version |
| Models not loading | Verify `TOTALSEG_WEIGHTS_PATH` is correct |
| Segmentation fails | Check Python packages: `pip list` in Slicer console |
| Out of memory errors | Close other applications; ensure 16GB+ RAM |

### Debug Mode

Enable debug logging by creating `%APPDATA%\Zhiyuan\debug.ini`:
```ini
[Logging]
Level = DEBUG
File = %APPDATA%\Zhiyuan\logs\debug.log
Console = True
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-04-15 | Initial release packaging guide |

---

## Additional Resources

- **3D Slicer Documentation**: https://slicer.readthedocs.io/
- **NSIS Documentation**: https://nsis.sourceforge.io/Doc/html/
- **Inno Setup Documentation**: https://jrsoftware.org/ishelp/index.php
- **nnU-Net**: https://github.com/MIC-DKFZ/nnUNet
- **PyTorch**: https://pytorch.org/

---

*Last updated: 2026-04-15*
*Author: BrachyPlan Development Team*
