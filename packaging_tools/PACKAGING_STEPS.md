# Zhiyuan Packaging Guide

> Version: 5.0.0 | Last updated: 2026-05-06
> This document covers the COMPLETE packaging pipeline from source code to distributable installer.
> Written from real-world debugging experience. Any LLM should be able to follow this from scratch without errors.

---

## Table of Contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Directory Layout](#3-directory-layout)
4. [Step-by-Step Pipeline](#4-step-by-step-pipeline)
5. [Critical Technical Details](#5-critical-technical-details)
6. [Known Issues and Fixes](#6-known-issues-and-fixes)
7. [Testing Checklist](#7-testing-checklist)
8. [Quick Reference](#8-quick-reference)

---

## 1. Overview

The packaging pipeline converts Zhiyuan's Python source code into a distributable Windows application:

```
Source (.py) --> [Cython compile] --> Binary (.pyd) --> [Copy to sandbox] --> [Inno Setup] --> .exe installer
                                                                              [7z]         --> .7z portable
```

**Estimated time:** 60-90 minutes
- Cython compilation: 5-10 min
- File copy to sandbox: 5-10 min
- Inno Setup compilation: 45-70 min (handles ~50k files)
- 7z compression: 10-15 min

**Output files:**
- `C:\Zhiyaun\releases\Zhiyuan-Installer.exe` (~7 MB, spans multiple disk slices)
- `C:\Zhiyaun\releases\Zhiyuan-vX.Y.Z.7z` (~7.9 GB)

---

## 2. Prerequisites

### 2.1 Required Software

| Software | Version | Purpose | Verify |
|----------|---------|---------|--------|
| Python 3.12 | 3.12.x (MUST match Slicer's Python) | Cython compilation | `python --version` |
| Cython | latest | Source protection | `python -m pip show cython` |
| NumPy | latest | Cython build dependency | `python -m pip show numpy` |
| setuptools | latest | Cython build dependency | `python -m pip show setuptools` |
| Visual Studio 2022 | any edition | MSVC compiler for .pyd | cl.exe in PATH |
| Inno Setup 6 | 6.x | Installer generator | `ISCC /?` |
| 7-Zip | any | Portable archive | `7z` in PATH |

### 2.2 Python Version - CRITICAL

**The Python version used for Cython compilation MUST exactly match the Slicer embedded Python version.**

Slicer 5.9 uses Python 3.12. If you compile with Python 3.14, the generated `.pyd` files will be named `*.cp314-win_amd64.pyd` and CANNOT be loaded by Python 3.12. You will get `ImportError: DLL load failed`.

```powershell
# Verify
$pythonExe = "C:\Users\b223\AppData\Local\Programs\Python\Python312\python.exe"
& $pythonExe --version  # Must show Python 3.12.x
```

### 2.3 Install Cython Dependencies

```powershell
$pythonExe = "C:\Users\b223\AppData\Local\Programs\Python\Python312\python.exe"
& $pythonExe -m pip install cython numpy setuptools
```

---

## 3. Directory Layout

```
C:\Zhiyaun\                              # Project root
├── r\Slicer-build\                      # Build directory (code runs here)
│   ├── Zhiyuan.exe                      # Main launcher
│   ├── bin\Release\                     # Runtime DLLs (SimpleITK, VTK, ITK, etc.)
│   ├── lib\
│   │   ├── Python\                      # Embedded Python 3.12 runtime (~50k files)
│   │   │   ├── bin\python.exe           # THE python.exe for subprocesses
│   │   │   ├── Lib\sitecustomize.py     # Auto-loaded on startup, reads LibraryPaths
│   │   │   └── Lib\slicer_dll_directories.py  # os.add_dll_directory() helper
│   │   ├── QtPlugins\                   # Qt platform plugins
│   │   ├── *.dll                        # Slicer core DLLs
│   │   └── Zhiyuan-5.9\qt-scripted-modules\
│   │       ├── BrachyPlan.py            # Main module entry point
│   │       ├── plans\                   # Algorithm modules
│   │       │   ├── brachy_plan_v2.py    # Planning entry
│   │       │   ├── core_v2.py           # Optimization
│   │       │   ├── utilizations_v2.py   # Image processing
│   │       │   ├── reinforcement.py     # Numba @njit (NOT compiled, keep as .py)
│   │       │   ├── config.json          # Hyperparameters
│   │       │   ├── dose_pre\            # CNN dose prediction
│   │       │   └── seg\                 # Model weights (~1.2GB)
│   │       │       ├── nnunet_infer.py  # nnU-Net wrapper (bypasses broken __main__)
│   │       └── Resources\               # Icons, .ui files, stylesheets
│   └── share\                           # SplashScreen.png etc.
│
├── Modules\Scripted\BrachyPlan\         # Source directory (Git tracked)
├── packaging_tools\                     # Packaging tools
│   ├── smart_builder.py                 # AST analyzer + Cython compiler
│   ├── pack.ps1                         # One-click packaging script
│   ├── Zhiyuan_Setup.iss                # Inno Setup script
│   └── PACKAGING_STEPS.md              # This file
├── TempRelease\                         # Sandbox (created during packaging)
└── releases\                            # Output directory
```

---

## 4. Step-by-Step Pipeline

### Step 0: Pre-flight Checks

```powershell
# 0.1 Kill any running Zhiyuan (old .pyd files get locked)
taskkill /F /IM Zhiyuan.exe /T 2>$null
taskkill /F /IM ZhiyuanApp-real.exe /T 2>$null

# 0.2 Verify code is up to date in build directory
# Development happens in r\Slicer-build; packaging reads from there directly.
# Git commits require syncing to Modules\Scripted\ separately.

# 0.3 Clean old compilation artifacts
cd C:\Zhiyaun\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules
Get-ChildItem -Filter "*.pyd" -Recurse | Remove-Item -Force
Get-ChildItem -Filter "*.c" -Recurse | Remove-Item -Force
if (Test-Path "_cython_build_temp") { Remove-Item -Recurse -Force "_cython_build_temp" }
```

### Step 1: Cython Compilation

```powershell
cd C:\Zhiyaun\packaging_tools
.\pack.ps1 -Version "1.0.5"
```

Or run `smart_builder.py` standalone for debugging:

```powershell
cd C:\Zhiyaun
python packaging_tools/smart_builder.py
```

#### What smart_builder.py does:

1. **AST dependency analysis** - Parses `BrachyPlan.py`, follows all `import`/`from` statements recursively (BFS), finds all local `.py` dependencies
2. **Cython compilation** - Generates `setup_cython_build.py`, runs `python setup_cython_build.py build_ext --inplace`
3. **Cleanup** - Removes `.c` files, `setup_cython_build.py`, build temp dirs

#### Verify compilation:

```powershell
$moduleDir = "C:\Zhiyaun\r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules"
$requiredPyd = @(
    "BrachyPlan.cp312-win_amd64.pyd",
    "plans\brachy_plan_v2.cp312-win_amd64.pyd",
    "plans\core_v2.cp312-win_amd64.pyd",
    "plans\utilizations_v2.cp312-win_amd64.pyd",
    "plans\visualizer.cp312-win_amd64.pyd",
    "plans\geometry.cp312-win_amd64.pyd",
    "plans\fitting_model.cp312-win_amd64.pyd",
    "plans\dose_pre\myDoseNet.cp312-win_amd64.pyd",
    "SubjectHierarchyPlugins\AbstractScriptedSubjectHierarchyPlugin.cp312-win_amd64.pyd"
)
foreach ($pyd in $requiredPyd) {
    $path = Join-Path $moduleDir $pyd
    if (Test-Path $path) { Write-Host "[OK] $pyd" -ForegroundColor Green }
    else { Write-Host "[MISSING] $pyd" -ForegroundColor Red }
}
```

### Step 2: Sandbox Creation

`pack.ps1` automatically creates `C:\Zhiyaun\TempRelease\r\Zhiyuan-build\` and copies all necessary files into it.

**IMPORTANT:** Do NOT delete TempRelease after packaging. It is needed for testing and debugging.

### Step 3: File Copy (pack.ps1 handles this)

The script copies files in this order:
1. `Zhiyuan.exe` (main launcher)
2. `.pyd` and `.ui` files from qt-scripted-modules
3. `.py` files WITHOUT corresponding `.pyd` (Slicer needs these for module registration)
4. DLLs from multiple sources (CTK, DCMTK, VTK, ITK, Qt5, OpenSSL, TBB, Teem, LibArchive, SlicerExecutionModel)
5. Python runtime (`r\python-install\` -> `lib\Python\`)
6. Qt plugins (platforms, styles, imageformats, iconengines)
7. Model weights (`.pth` files)
8. Configuration files (`.json`)
9. Resources (icons, `.qss`, `.ui`)
10. Launcher settings INI files
11. `CMakeCache.txt` (required for module loading)
12. `bin\` directory contents
13. `share\` directory contents

### Step 4: Path Replacement

All absolute paths in config files are replaced with relative path macros:

| Original | Replacement |
|----------|-------------|
| `C:/Zhiyaun/r/python-install` | `<APPLAUNCHER_SETTINGS_DIR>/lib/Python` |
| `C:\Zhiyaun\r\python-install` | `<APPLAUNCHER_SETTINGS_DIR>/lib/Python` |
| `C:/LHT_workspace/code/Qt5.15/5.15.2/msvc2019_64/bin` | `<APPLAUNCHER_SETTINGS_DIR>/lib/QtPlugins` |
| `Slicer-build` | `Zhiyuan-build` |

**CRITICAL ORDER:** `SLICER_HOME` replacement MUST happen before `Slicer-build -> Zhiyuan-build`. This is handled with `[ordered]@{}` in PowerShell.

### Step 5: Installer Generation

#### Inno Setup (primary):
```powershell
# pack.ps1 runs this automatically, or manually:
$inno = "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
& $inno "C:\Zhiyaun\packaging_tools\Zhiyuan_Setup.iss" /DMyAppVersion="1.0.5"
```

**CRITICAL:** The ISS file uses relative paths from its own location. If you run ISCC from a different working directory, the paths will resolve incorrectly. `pack.ps1` handles this by copying the ISS file to the project root and running from there.

#### 7z portable:
```powershell
# pack.ps1 runs this automatically, or manually:
cd C:\Zhiyaun
7z a -t7z -m0=lzma2 -mx=9 -mfb=256 -md=32m -ms=on releases\Zhiyuan-v1.0.5.7z TempRelease\*
```

---

## 5. Critical Technical Details

### 5.1 Python Executable Discovery in Slicer

**THE PROBLEM:** In 3D Slicer, `sys.executable` points to `PythonSlicer.exe`, which is a launcher that reads `.ini` files and IGNORES environment variables. `sys.prefix` and `shutil.which()` may find a DIFFERENT system Python (e.g., `C:/Python314`), causing module version mismatches.

**THE SOLUTION:** Use `__file__` as the ONLY reliable anchor:

```python
def _get_python_executable(self):
    # __file__ = <app>/r/Zhiyuan-build/lib/Zhiyuan-5.9/qt-scripted-modules/BrachyPlan.py
    # python.exe = <app>/r/Zhiyuan-build/lib/Python/bin/python.exe
    module_dir = os.path.dirname(os.path.abspath(__file__))
    bin_dir = os.path.normpath(os.path.join(module_dir, "..", "..", "Python", "bin"))
    python_exe = os.path.join(bin_dir, "python.exe")
    if os.path.isfile(python_exe):
        return python_exe
    raise RuntimeError("Packaged Python not found: {!r}".format(python_exe))
```

**Why python.exe, NOT PythonSlicer.exe:**
- `python.exe` is standard CPython that respects `PYTHONHOME` environment variable
- `PythonSlicer.exe` is a custom launcher that reads `.ini` files and may compute wrong `PYTHONHOME`
- We need to set `PYTHONHOME` explicitly to the correct path

### 5.2 PYTHONHOME Setup

The subprocess needs correct `PYTHONHOME` to find its standard library:

```python
def _get_clean_subprocess_env(self):
    env = os.environ.copy()
    # Remove variables that interfere with Python initialization
    for var in ("PYTHONPATH", "PYTHONSTARTUP", "PYTHONEXECUTABLE"):
        env.pop(var, None)

    # Set PYTHONHOME: <app>/r/Zhiyuan-build/lib/Python
    module_dir = os.path.dirname(os.path.abspath(__file__))
    python_home = os.path.normpath(os.path.join(module_dir, "..", "..", "Python"))
    env["PYTHONHOME"] = python_home

    # Add bin/Release to LibraryPaths for SimpleITK DLLs (see 5.3)
    bin_release = os.path.normpath(os.path.join(
        module_dir, "..", "..", "..", "bin", "Release"
    ))
    if os.path.isdir(bin_release):
        existing_lp = env.get("LibraryPaths", "")
        env["LibraryPaths"] = bin_release + (os.pathsep + existing_lp if existing_lp else "")

    return env
```

### 5.3 SimpleITK DLL Loading (LibraryPaths mechanism)

**THE PROBLEM:** `SimpleITK._SimpleITK.pyd` depends on `SimpleITKCommon-2.5.dll` etc. located in `bin/Release/`. Since Python 3.8+, Windows ignores `PATH` for DLL loading. `os.add_dll_directory()` must be called instead.

**THE SOLUTION:** The packaged Python has a `sitecustomize.py` at `Lib/sitecustomize.py` (NOT `Lib/site-packages/`) that auto-reads the `LibraryPaths` environment variable:

```
Lib/sitecustomize.py
  --> imports Lib/slicer_dll_directories.py
  --> reads LibraryPaths env var
  --> calls os.add_dll_directory() for each path
```

So we set `LibraryPaths` in the subprocess environment, and the DLLs are found automatically.

**Why `Lib/sitecustomize.py` and not `Lib/site-packages/sitecustomize.py`:**
- Python loads `sitecustomize.py` from `Lib/` first (before `site-packages/`)
- The existing `Lib/sitecustomize.py` was put there by the Slicer build process
- Creating one in `site-packages/` has no effect because Python stops at the first one

### 5.4 cc3d (connected-components-3d) Package

**THE PROBLEM:** The `cc3d` package contains a compiled extension `fastcc3d.cp312-win_amd64.pyd` that can be missing from pip installations. Only the `.pyi` type stub exists.

**THE FIX:** Download the wheel from PyPI and extract the `.pyd`:

```powershell
cd C:\Zhiyaun\TempRelease\r\Zhiyuan-build\lib\Python

# Download wheel
python -m pip download connected-components-3d --only-binary=:all: --platform win_amd64 --python-version 312 -d wheels

# Extract .pyd from wheel (it's a zip file)
# The .pyd is at: cc3d/fastcc3d.cp312-win_amd64.pyd
# Copy to: Lib/site-packages/cc3d/fastcc3d.cp312-win_amd64.pyd
```

**How to verify it's present:**
```powershell
Test-Path "C:\Zhiyaun\TempRelease\r\Zhiyuan-build\lib\Python\Lib\site-packages\cc3d\fastcc3d.cp312-win_amd64.pyd"
# Should return True
```

### 5.5 ISS File and Working Directory

**THE PROBLEM:** Inno Setup resolves relative paths from the `.iss` file's location, NOT from the working directory.

**THE SOLUTION:** `pack.ps1` copies `Zhiyuan_Setup.iss` to the project root (`C:\Zhiyaun\`) before running ISCC, then ISCC runs from the project root. This ensures all `TempRelease\r\Zhiyuan-build\...` paths resolve correctly.

If running ISCC manually, either:
1. Copy the ISS file to `C:\Zhiyaun\` and run from there, OR
2. Modify all paths in the ISS file to be relative to `packaging_tools/`

### 5.6 ISS `**\*` Recursion Limit

**THE PROBLEM:** `lib\Python\**\*` contains ~50,000 files. ISS's internal recursive wildcard handler has a limit and will hang or fail.

**THE FIX:** Split into explicit subdirectory entries:

```pascal
Source: "TempRelease\r\Zhiyuan-build\lib\Python\*"; ...
Source: "TempRelease\r\Zhiyuan-build\lib\Python\bin\*"; ...
Source: "TempRelease\r\Zhiyuan-build\lib\Python\DLLs\*"; ...
Source: "TempRelease\r\Zhiyuan-build\lib\Python\Lib\*"; ...
Source: "TempRelease\r\Zhiyuan-build\lib\Python\Scripts\*"; ...
Source: "TempRelease\r\Zhiyuan-build\lib\Python\include\*"; ...
Source: "TempRelease\r\Zhiyuan-build\lib\Python\Library\*"; ...
Source: "TempRelease\r\Zhiyuan-build\lib\Python\share\*"; ...
```

### 5.7 ISS `**\*` vs `*` for Directories

**THE PROBLEM:** ISS `*` only matches files, not directories. `recursesubdirs` with `*` works for files in subdirectories, but `**\*` is the recursive wildcard.

**THE FIX:** Use `*` + `recursesubdirs` flag instead of `**\*`:
```pascal
; CORRECT:
Source: "path\*"; DestDir: "..."; Flags: recursesubdirs createallsubdirs
; WRONG (causes issues with 50k+ files):
Source: "path\**\*"; DestDir: "..."; Flags: recursesubdirs
```

### 5.8 ISS Installer Hang During Install

**THE PROBLEM:** Setting environment variables via `RegWriteStringValue` + `SendMessage(HWND_BROADCAST, WM_WININICHANGE)` during `[Run]` section can cause the installer to hang.

**THE FIX:** Set env vars in `[Code]` section's `CurStepChanged(ssPostInstall)` instead, and use `PostMessage` (non-blocking) instead of `SendMessage` (blocking):

```pascal
procedure CurStepChanged(CurStep: TSetupStep);
begin
    case CurStep of
        ssPostInstall:
            begin
                RegWriteStringValue(HKCU, 'Environment', 'TOTALSEG_WEIGHTS_PATH', '...');
                PostMessage(HWND_BROADCAST, WM_WININICHANGE, 0, 0);
            end;
    end;
end;
```

### 5.9 PowerShell Hashtable Ordering

**THE PROBLEM:** `@{}` does not guarantee key iteration order. If `Slicer-build -> Zhiyuan-build` runs before `SLICER_HOME=C:/Zhiyaun/r/Slicer-build`, the SLICER_HOME path gets corrupted.

**THE FIX:** Use `[ordered]@{}`:
```powershell
$pathReplacements = [ordered]@{
    "SLICER_HOME=C:/Zhiyaun/r/Slicer-build" = "SLICER_HOME=<APPLAUNCHER_SETTINGS_DIR>"
    # ... other specific replacements first ...
    "Slicer-build" = "Zhiyuan-build"  # LAST
}
```

---

## 6. Known Issues and Fixes

### 6.1 Missing .pyd After Compilation

**Symptom:** Some modules not compiled (e.g., `utilizations_v2.pyd`, `visualizer.pyd` missing)

**Cause:** AST analyzer didn't handle relative imports (`from . import xxx` has `node.module = None`)

**Fix:** Already fixed in `smart_builder.py`. If adding new modules, ensure their directory is in `SCAN_DIRS`:

```python
SCAN_DIRS = [
    ".",
    "plans",
    "plans/dose_pre",
    "SubjectHierarchyPlugins",
    "Resources",
]
```

### 6.2 `__init__.py` Compilation Conflict

**Symptom:** `plans/__init__.py` compiles to `plans.cp312-win_amd64.pyd`, conflicting with the `plans/` directory name.

**Fix:** `__init__.py` is in `EXCLUDE_FILES` in `smart_builder.py`.

### 6.3 Old .pyd Locked by Running Process

**Symptom:** "Permission denied" or "file is being used by another process"

**Fix:**
```powershell
taskkill /F /IM Zhiyuan.exe /T 2>$null
taskkill /F /IM ZhiyuanApp-real.exe /T 2>$null
```

### 6.4 Missing Qt Plugin (Flash and Exit)

**Symptom:** Double-click Zhiyuan.exe, window flashes and closes immediately.

**Cause:** `qwindows.dll` missing from `lib/QtPlugins/platforms/`

**Fix:** Verify `lib/QtPlugins/platforms/qwindows.dll` exists in TempRelease. Check `ZhiyuanLauncherSettings.ini` has `QT_PLUGIN_PATH=<APPLAUNCHER_SETTINGS_DIR>/lib/QtPlugins`.

### 6.5 SimpleITK ImportError on Target Machine

**Symptom:** `ImportError: DLL load failed while importing _SimpleITK: The specified module could not be found.`

**Cause:** `_SimpleITK.pyd` depends on `SimpleITKCommon-2.5.dll` in `bin/Release/`. Python 3.8+ ignores PATH for DLL loading.

**Fix:** Already handled by `_get_clean_subprocess_env()` setting `LibraryPaths` env var. The packaged `Lib/sitecustomize.py` reads this and calls `os.add_dll_directory()`.

### 6.6 cc3d ImportError on Target Machine

**Symptom:** `ImportError: cannot import name 'fastcc3d' from partially initialized module 'cc3d'`

**Cause:** `fastcc3d.cp312-win_amd64.pyd` was missing from the cc3d package.

**Fix:** See section 5.4. Download the wheel from PyPI and extract the `.pyd`.

### 6.7 BrachyPlan.py Must Be Kept as .py

**Symptom:** Slicer fails to register the BrachyPlan module.

**Cause:** Slicer's module loading mechanism requires the `.py` file for registration, even if a `.pyd` exists alongside it.

**Fix:** `pack.ps1` always copies `BrachyPlan.py` even when a `.pyd` exists. The ISS file also explicitly includes it.

### 6.8 nnU-Net `dataset.json` FileNotFoundError

**Symptom:** Pancreatic tumor segmentation fails with:
```
FileNotFoundError: .../Dataset004_Hippocampus/nnUNetTrainer_5epochs__nnUNetPlans__3d_fullres/dataset.json
```

**Cause:** nnunetv2's `predict_from_raw_data.py` has a broken `if __name__ == '__main__':` block (line 1020-1057) that hardcodes `Dataset004_Hippocampus` and `nnUNetTrainer_5epochs` test code. It completely ignores command-line arguments. When BrachyPlan runs `python -m nnunetv2.inference.predict_from_raw_data -d 5 ...`, it executes this hardcoded test code instead of parsing args.

**Fix:** Use a wrapper script `plans/seg/nnunet_infer.py` that calls `predict_entry_point_modelfolder()` with `-m` (direct model folder path) instead of `-d` (dataset ID):

```python
# nnunet_infer.py
def main():
    if "-m" in sys.argv:
        from nnunetv2.inference.predict_from_raw_data import predict_entry_point_modelfolder
        predict_entry_point_modelfolder()
    else:
        from nnunetv2.inference.predict_from_raw_data import predict_entry_point
        predict_entry_point()
```

BrachyPlan invokes:
```python
wrapper_script = os.path.join(module_dir, "plans", "seg", "nnunet_infer.py")
cmd = [python_exe, wrapper_script, "-m", config_dir, "-i", input_folder, "-o", output_folder, "-f", "0"]
```

**Why `-m` mode is better:**
- Bypasses the broken `__main__` block entirely
- Doesn't depend on `nnUNet_results` env var or dataset name resolution
- Points directly to the model folder containing `dataset.json`, `plans.json`, `fold_0/`

**General lesson:** nnunetv2 has many `__main__` blocks with hardcoded developer test paths (`/home/fabian/`, `/media/isensee/`, `Dataset004_Hippocampus`). NEVER use `python -m nnunetv2.xxx` for production. Always use the Python API entry point functions or a wrapper script.

### 6.9 Subprocess UTF-8 Encoding Crash on Chinese Windows

**Symptom:** TotalSegmentator or nnU-Net subprocess crashes with:
```
'utf-8' codec can't decode byte 0xa8 in position 6: invalid start byte
```

**Cause:** On Chinese Windows, `universal_newlines=True` without explicit encoding uses `locale.getpreferredencoding()` (cp936/GBK). If the subprocess outputs bytes that are valid GBK but invalid UTF-8, the pipe crashes.

**Fix:** Always use `encoding='utf-8', errors='replace'` in `subprocess.Popen`:
```python
proc = subprocess.Popen(
    cmd,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
    universal_newlines=True,
    encoding='utf-8',
    errors='replace',  # Replace undecodable bytes with U+FFFD instead of crashing
    env=env
)
```

**This also fixes garbled characters (乱码)** in tqdm progress bars — the `replace` handler outputs `�` instead of crashing.

### 6.10 PYTHONHOME Wrong Path from PythonSlicer.exe .ini

**Symptom:** Subprocess crashes with `ModuleNotFoundError: No module named 'encodings'`

**Cause:** `PythonSlicer.exe` reads `.ini` files and computes `PYTHONHOME` as `<APPLAUNCHER_SETTINGS_DIR>/lib/Python`. But `APPLAUNCHER_SETTINGS_DIR` resolves to the `.ini` file's directory (e.g., `lib/Python/bin/`), making PYTHONHOME = `lib/Python/bin/lib/Python` (wrong).

**Fix:** Two-part fix:
1. Use `python.exe` instead of `PythonSlicer.exe` (respects PYTHONHOME env var)
2. Fix `.ini` files: change `PYTHONHOME=<APPLAUNCHER_SETTINGS_DIR>/lib/Python` to `PYTHONHOME=<APPLAUNCHER_DIR>/..`
3. `pack.ps1` applies this fix automatically as post-processing step

---

## 7. Testing Checklist

After building, test on a CLEAN machine (or after uninstalling previous version):

### 7.1 Basic Startup
- [ ] Double-click `Zhiyuan.exe` - window opens without flashing
- [ ] BrachyPlan module loads in the module selector
- [ ] No ImportError in the Python console

### 7.2 Segmentation (CRITICAL)
- [ ] Load a CT volume
- [ ] Click "TotalSegmentator" segmentation button
- [ ] Verify subprocess starts (check Python console for debug output)
- [ ] Verify segmentation completes without ImportError
- [ ] Check that `cc3d`, `SimpleITK`, `torch`, `totalsegmentator`, `nnunetv2` all import correctly in subprocess
- [ ] Click "Pancreatic Tumor" segmentation button
- [ ] Verify nnU-Net inference completes (should use `nnunet_infer.py` wrapper, NOT `python -m nnunetv2`)
- [ ] Verify no `FileNotFoundError` for `dataset.json`

### 7.3 UI Behavior
- [ ] All collapsible buttons are collapsed by default (except DataTree)
- [ ] Expanding a section doesn't compress other sections
- [ ] Collapsed sections don't leave blank space
- [ ] Sections are top-aligned when collapsed

### 7.4 Environment
- [ ] `TOTALSEG_WEIGHTS_PATH` environment variable is set (check in System Properties)
- [ ] VC++ Runtime is installed
- [ ] CUDA works if GPU is available (check `torch.cuda.is_available()`)

### 7.5 Debug Subprocess Test

Run this in Zhiyuan's Python console to verify the subprocess environment:

```python
import subprocess, os, sys
# This simulates what BrachyPlan does for segmentation
module_dir = os.path.dirname(os.path.abspath(
    sys.modules['BrachyPlan'].__file__
))
python_exe = os.path.normpath(os.path.join(module_dir, "..", "..", "Python", "bin", "python.exe"))
python_home = os.path.normpath(os.path.join(module_dir, "..", "..", "Python"))
bin_release = os.path.normpath(os.path.join(module_dir, "..", "..", "..", "bin", "Release"))

env = os.environ.copy()
for v in ("PYTHONPATH", "PYTHONSTARTUP", "PYTHONEXECUTABLE"):
    env.pop(v, None)
env["PYTHONHOME"] = python_home
lp = env.get("LibraryPaths", "")
env["LibraryPaths"] = bin_release + (os.pathsep + lp if lp else "")

test_code = "import cc3d; import SimpleITK; import torch; import totalsegmentator; import nnunetv2; print('ALL OK')"
result = subprocess.run([python_exe, "-c", test_code], env=env, capture_output=True, text=True)
print("STDOUT:", result.stdout)
print("STDERR:", result.stderr)
print("Return code:", result.returncode)
```

Expected output: `ALL OK` with return code 0.

---

## 8. Quick Reference

### One-Click Packaging

```powershell
cd C:\Zhiyaun\packaging_tools
.\pack.ps1 -Version "1.0.5"
```

### Skip Compilation (reuse existing .pyd)

```powershell
cd C:\Zhiyaun\packaging_tools
.\pack.ps1 -SkipCompile -Version "1.0.5"
```

### Compile Only (no installer)

```powershell
cd C:\Zhiyaun
python packaging_tools/smart_builder.py
```

### Key Paths

| Item | Path |
|------|------|
| Project root | `C:\Zhiyaun` |
| Build directory | `C:\Zhiyaun\r\Slicer-build` |
| Module entry | `r\Slicer-build\lib\Zhiyuan-5.9\qt-scripted-modules\BrachyPlan.py` |
| Packaging tools | `C:\Zhiyaun\packaging_tools\` |
| Output | `C:\Zhiyaun\releases\` |
| Sandbox | `C:\Zhiyaun\TempRelease\` |

### Version Update Checklist

- [ ] Code is up to date in `r\Slicer-build`
- [ ] `Zhiyuan.exe` is not running
- [ ] Old `.pyd` files cleaned
- [ ] `smart_builder.py` EXCLUDE_FILES doesn't need updates
- [ ] Version number set correctly
- [ ] Sufficient disk space (~10 GB temp)
- [ ] `cc3d` `.pyd` is present in Python site-packages
- [ ] `nnunet_infer.py` wrapper exists in `plans/seg/`
- [ ] After build: test on clean machine per section 7

---

*This document is based on real packaging experience across multiple sessions. Every issue listed here was encountered and fixed in production.*
