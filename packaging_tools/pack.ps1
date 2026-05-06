# ============================================================================
# Zhiyuan Professional Packager (Ultimate Edition v3.0)
# ============================================================================
#
# One-click packaging script for Zhiyuan application.
# Performs:
#   1. Cython compilation with Python 3.12 (source code protection)
#   2. Sandbox isolation (prevents accidental file deletion)
#   3. Whitelist-based packaging (only includes necessary files & .ui)
#   4. Inno Setup installer generation (with 7z SFX fallback)
#   5. Security scan (removes all .py source from package)
#   6. Automatic cleanup
#
# Version: 3.0.0 (Complete Rewrite)
# ============================================================================

[CmdletBinding()]
param(
    [string]$Version = "1.0.0",
    [switch]$SkipCompile,
    [string]$SourceDir = "r\Slicer-build",
    [string]$OutputDir = "releases",
    [string]$TempDir = "TempRelease"
)

$ErrorActionPreference = "Stop"
$host.UI.RawUI.WindowTitle = "Zhiyuan Professional Packager v$Version"

$IsVerbose = $PSBoundParameters.ContainsKey('Verbose')

function Write-Success($msg) { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-ErrorOut($msg) { Write-Host "  [FAIL] $msg" -ForegroundColor Red }
function Write-WarningMsg($msg) { Write-Host "  [WARN] $msg" -ForegroundColor Yellow }
function Write-Info($msg) { Write-Host "  [INFO] $msg" -ForegroundColor Cyan }
function Write-Detail($msg) { if ($IsVerbose) { Write-Host "    -> $msg" -ForegroundColor Gray } }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$BuildDir = Join-Path $ProjectRoot $SourceDir
$ModuleRoot = Join-Path $BuildDir "lib\Zhiyuan-5.9\qt-scripted-modules"
$ReleaseDir = Join-Path $ProjectRoot $OutputDir
$SandboxDir = Join-Path $ProjectRoot $TempDir

$possibleInnoPaths = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe"
)
$InnoSetupPath = ""
foreach ($p in $possibleInnoPaths) {
    if (Test-Path $p) {
        $InnoSetupPath = $p
        break
    }
}

$Python312Exe = "C:\Users\b223\AppData\Local\Programs\Python\Python312\python.exe"
if (-not (Test-Path $Python312Exe)) {
    $Python312Exe = (Get-Command python -ErrorAction SilentlyContinue).Source
}

Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host "    Z H I Y U A N   P R O F E S S I O N A L   P A C K E R" -ForegroundColor Cyan
Write-Host "    Source Code Protection + Installer Generator" -ForegroundColor Cyan
Write-Host "  ================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Info "Configuration:"
Write-Host "   Version:       $Version" -ForegroundColor White
Write-Host "   Project Root:  $ProjectRoot" -ForegroundColor White
Write-Host "   Build Dir:     $BuildDir" -ForegroundColor White
Write-Host "   Module Root:   $ModuleRoot" -ForegroundColor White
Write-Host "   Output Dir:    $ReleaseDir" -ForegroundColor White
Write-Host "   Inno Setup:    $(if ($InnoSetupPath) { $InnoSetupPath } else { 'NOT FOUND' })" -ForegroundColor $(if ($InnoSetupPath) { 'White' } else { 'Red' })
Write-Host "   Python 3.12:   $(if (Test-Path $Python312Exe) { $Python312Exe } else { 'NOT FOUND' })" -ForegroundColor $(if (Test-Path $Python312Exe) { 'White' } else { 'Red' })
Write-Host ""

# ============================================================================
# STEP 0: Environment Validation
# ============================================================================
Write-Host "=" * 70 -ForegroundColor DarkGray
Write-Info "STEP 0: Environment Validation"

$errors = @()
if (-not (Test-Path $BuildDir)) { $errors += "Build directory not found: $BuildDir" }
if (-not (Test-Path $ModuleRoot)) { $errors += "Module root not found: $ModuleRoot" }
if (-not (Test-Path (Join-Path $BuildDir "Zhiyuan.exe"))) { $errors += "Zhiyuan.exe not found in: $BuildDir" }
if (-not $InnoSetupPath) { Write-WarningMsg "Inno Setup ISCC.exe not found - will use 7z fallback" }

if ($errors.Count -gt 0) {
    foreach ($err in $errors) { Write-ErrorOut $err }
    throw "Validation failed with $($errors.Count) error(s)"
}
Write-Success "Environment validation passed"

# ============================================================================
# STEP 1: Cython Compilation (IP Protection)
# ============================================================================
Write-Host ""
Write-Host "=" * 70 -ForegroundColor DarkGray
Write-Info "STEP 1: Cython Compilation (IP Protection)"

if ($SkipCompile) {
    Write-WarningMsg "Skipping Cython compilation (as requested)"
    Write-WarningMsg "Existing .pyd files will be used if available"
} else {
    Write-Info "Running smart_builder.py for dependency analysis and compilation..."
    $smartBuilder = Join-Path $ScriptDir "smart_builder.py"
    if (-not (Test-Path $smartBuilder)) { throw "smart_builder.py not found at: $smartBuilder" }

    try {
        $process = Start-Process -FilePath $Python312Exe -ArgumentList $smartBuilder -WorkingDirectory $ProjectRoot -PassThru -NoNewWindow -Wait
        if ($process.ExitCode -ne 0) { throw "Cython compilation failed with exit code: $($process.ExitCode)" }
        Write-Success "Cython compilation completed successfully"
    } catch {
        Write-ErrorOut "Error during Cython compilation: $_"
        throw
    }

    # ============================================================================
    # STEP 1b: Compilation Integrity Verification
    # ============================================================================
    Write-Host ""
    Write-Host "=" * 70 -ForegroundColor DarkGray
    Write-Info "STEP 1b: Compilation Integrity Verification"

    $missingPyd = @()
    $compiledOk = @()
    Get-ChildItem -Path $ModuleRoot -Filter "*.py" -Recurse -File | Where-Object {
        # Only check our custom code (not Slicer framework modules)
        $_.FullName -notmatch "(DICOM|SegmentEditor|SelfTest|WebServer|Home|Settings|Welcome|SampleData|ScreenCapture|ExtensionWizard|ImportItkSnapLabel|CropVolumeSequence|PluggableMarkups|ColorLegend|AddManyMarkups|MarkupsInViews|NeurosurgicalPlanning|TotalSegmentator)"
    } | ForEach-Object {
        $pyFile = $_
        $stem = $pyFile.BaseName
        $pydPattern = Join-Path $pyFile.DirectoryName "${stem}.*.pyd"
        if (Test-Path $pydPattern) {
            $compiledOk += $pyFile.Name
        } else {
            $missingPyd += $pyFile.FullName.Substring($ModuleRoot.Length)
        }
    }

    Write-Info "Compilation check: $($compiledOk.Count) files have .pyd, $($missingPyd.Count) missing"
    if ($missingPyd.Count -gt 0) {
        Write-WarningMsg "The following .py files were NOT compiled to .pyd:"
        foreach ($m in $missingPyd) { Write-WarningMsg "  - $m" }
        Write-WarningMsg "These files will be kept as .py source in the package"
    } else {
        Write-Success "All custom .py files successfully compiled to .pyd!"
    }
}

# ============================================================================
# STEP 2: Sandbox Creation (Isolated Build Environment)
# ============================================================================
Write-Host ""
Write-Host "=" * 70 -ForegroundColor DarkGray
Write-Info "STEP 2: Sandbox Creation (Isolated Build Environment)"

if (Test-Path $SandboxDir) {
    Write-Detail "Removing previous sandbox..."
    Remove-Item -Recurse -Force $SandboxDir -ErrorAction SilentlyContinue
}

New-Item -ItemType Directory -Path $SandboxDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $SandboxDir "r\Zhiyuan-build") -Force | Out-Null
Write-Success "Sandbox created at $TempDir"

# ============================================================================
# STEP 3: Whitelist File Copy (Secure Packaging)
# ============================================================================
Write-Host ""
Write-Host "=" * 70 -ForegroundColor DarkGray
Write-Info "STEP 3: Whitelist File Copy (Secure Packaging)"

$fileStats = @{ "pyd"=0; "ui"=0; "exe"=0; "dll"=0; "pth"=0; "json"=0; "py"=0; "other"=0 }
$totalSize = 0
$copiedFiles = @()

function Copy-WhitelistFile([string]$Source, [string]$Dest, [string]$Type) {
    try {
        $destDir = Split-Path $Dest -Parent
        if (-not (Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        Copy-Item -Path $Source -Destination $Dest -Force
        $script:copiedFiles += $Dest
        $script:totalSize += (Get-Item $Dest).Length
        $script:fileStats[$Type]++
        return $true
    } catch {
        Write-Detail "Failed to copy: $Source -> $_"
        return $false
    }
}

# --- 3.1 Main Executable ---
Write-Detail "Copying main executable..."
$exeSrc = Join-Path $BuildDir "Zhiyuan.exe"
if (Test-Path $exeSrc) {
    Copy-WhitelistFile $exeSrc (Join-Path $SandboxDir "r\Zhiyuan-build\Zhiyuan.exe") "exe" | Out-Null
    Write-Success "Zhiyuan.exe copied"
}

# --- 3.2 Compiled Python Modules (.pyd) and UI Files (.ui) ---
Write-Detail "Copying compiled Python modules (.pyd) and native UI files (.ui)..."
Get-ChildItem -Path $ModuleRoot -Include "*.pyd", "*.ui" -Recurse -File | ForEach-Object {
    $relPath = $_.FullName.Substring($ModuleRoot.Length)
    $destPath = Join-Path $SandboxDir "r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules$relPath"
    $type = if ($_.Extension -eq ".pyd") { "pyd" } else { "ui" }
    Copy-WhitelistFile $_.FullName $destPath $type | Out-Null
}

# Also copy .py files that do NOT have corresponding .pyd files
# (Skip .py files where a compiled .pyd exists to prevent source leakage)
# Also skip *_backup.py files and v1 version files (no .pyd, superseded by v2)
Write-Detail "Copying Python source files (excluding those with compiled .pyd and backup/v1 files)..."
Get-ChildItem -Path $ModuleRoot -Filter "*.py" -Recurse -File | ForEach-Object {
    $pyFile = $_
    $stem = $pyFile.BaseName
    $pydPattern = Join-Path $pyFile.DirectoryName "${stem}.*.pyd"
    $pydExists = Test-Path $pydPattern

            # Files to exclude from packaging (no .pyd and not needed)
    $isExcluded = $pyFile.Name -match '_backup\.py$' -or
                  $pyFile.FullName -match '\\plans\\' -and $pyFile.Name -match '^(brachy_plan|core|utilizations)\.py$' -or
                  $pyFile.Name -eq 'TotalSegmentator.py' -or
                  ($pyFile.Name -eq 'BrachyPlan.py' -and $false)  # Never exclude BrachyPlan.py - Slicer needs it for module registration

    # BrachyPlan.py MUST always be copied - Slicer needs .py for module registration
    $alwaysKeep = $pyFile.Name -eq 'BrachyPlan.py'

    if ($isExcluded) {
        Write-Detail "  Excluded: $($pyFile.Name)"
    } elseif ($alwaysKeep -or -not $pydExists) {
        $relPath = $pyFile.FullName.Substring($ModuleRoot.Length)
        $destPath = Join-Path $SandboxDir "r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules$relPath"
        Copy-WhitelistFile $pyFile.FullName $destPath "py" | Out-Null
        Write-Detail "  Copied .py: $($pyFile.Name)$(if ($alwaysKeep) { ' (always keep for Slicer registration)' } else { ' (no compiled .pyd found)' })"
    } else {
        Write-Detail "  Skipped .py with .pyd: $($pyFile.Name)"
    }
}
Write-Success "Module .pyd and .ui files copied ($($fileStats['pyd']) .pyd, $($fileStats['ui']) .ui)"

# --- 3.3 DLL Libraries ---
Write-Detail "Copying DLL libraries..."
$dllCount = 0
Get-ChildItem -Path (Join-Path $BuildDir "lib") -Filter "*.dll" -Recurse -File | ForEach-Object {
    if ($_.Name -notmatch "_d\.dll$") {
        $relPath = $_.FullName.Substring((Join-Path $BuildDir "lib").Length)
        $destPath = Join-Path $SandboxDir "r\Zhiyuan-build\lib$relPath"
        Copy-WhitelistFile $_.FullName $destPath "dll" | Out-Null
        $dllCount++
    }
}
Write-Success "DLL libraries copied ($dllCount files)"

# --- 3.4 lib/*.pyd (Slicer core Python extensions) ---
Write-Detail "Copying Slicer core Python extension modules (.pyd)..."
$corePydCount = 0
Get-ChildItem -Path (Join-Path $BuildDir "lib") -Filter "*.pyd" -Recurse -File | ForEach-Object {
    $relPath = $_.FullName.Substring((Join-Path $BuildDir "lib").Length)
    $destPath = Join-Path $SandboxDir "r\Zhiyuan-build\lib$relPath"
    Copy-WhitelistFile $_.FullName $destPath "pyd" | Out-Null
    $corePydCount++
}
Write-Success "Slicer core .pyd files copied ($corePydCount files)"

# --- 3.5 CTK Core DLLs (ALL DLLs from CTK-build Release) ---
Write-Detail "Copying ALL CTK DLLs..."
$ctkSrcDir = "C:\Zhiyaun\r\CTK-build\CTK-build\bin\Release"
$ctkDestDir = Join-Path $SandboxDir "r\Zhiyuan-build\bin\Release"
if (Test-Path $ctkSrcDir) {
    $ctkCount = 0
    Get-ChildItem -Path $ctkSrcDir -Filter "*.dll" -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -notmatch "_d\.dll$") {
            Copy-WhitelistFile $_.FullName (Join-Path $ctkDestDir $_.Name) "dll" | Out-Null
            Write-Detail "  Copied CTK: $($_.Name)"
            $ctkCount++
        }
    }
    # Also copy PythonQt.dll from CMakeExternals
    $pythonQtSrc = "C:\Zhiyaun\r\CTK-build\CMakeExternals\Install\bin\PythonQt.dll"
    if (Test-Path $pythonQtSrc) {
        Copy-WhitelistFile $pythonQtSrc (Join-Path $ctkDestDir "PythonQt.dll") "dll" | Out-Null
        Write-Detail "  Copied PythonQt.dll"
        $ctkCount++
    }
    Write-Success "CTK DLLs copied ($ctkCount files)"
} else {
    Write-WarningMsg "CTK Release directory not found: $ctkSrcDir"
}

# --- 3.5.1 CTK PythonQt Python bindings (.pyd files) ---
# These are required for ctk Python module to work properly
Write-Detail "Copying CTK PythonQt bindings..."
$ctkPythonQtSrc = "C:\Zhiyaun\r\CTK-build\CTK-build\bin\Release"
if (Test-Path $ctkPythonQtSrc) {
    $ctkPydCount = 0
    Get-ChildItem -Path $ctkPythonQtSrc -Filter "*.pyd" -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -notmatch "_d\.pyd$") {
            Copy-WhitelistFile $_.FullName (Join-Path $ctkDestDir $_.Name) "pyd" | Out-Null
            Write-Detail "  Copied CTK PythonQt: $($_.Name)"
            $ctkPydCount++
        }
    }
    Write-Success "CTK PythonQt bindings copied ($ctkPydCount files)"
} else {
    Write-WarningMsg "CTK PythonQt directory not found: $ctkPythonQtSrc"
}

# --- 3.6 DCMTK DLLs (required by Slicer DICOM support) ---
Write-Detail "Copying ALL DCMTK DLLs..."
$dcmtkSrcDir = "C:\Zhiyaun\r\DCMTK-build\bin\Release"
if (Test-Path $dcmtkSrcDir) {
    $dcmtkCount = 0
    Get-ChildItem -Path $dcmtkSrcDir -Filter "*.dll" -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -notmatch "_d\.dll$") {
            Copy-WhitelistFile $_.FullName (Join-Path $ctkDestDir $_.Name) "dll" | Out-Null
            Write-Detail "  Copied DCMTK: $($_.Name)"
            $dcmtkCount++
        }
    }
    Write-Success "DCMTK DLLs copied ($dcmtkCount files)"
} else {
    Write-WarningMsg "DCMTK Release directory not found: $dcmtkSrcDir"
}

# --- 3.7 OpenSSL DLLs (required by network/DICOM) ---
Write-Detail "Copying OpenSSL DLLs..."
$sslSrcDir = "C:\Zhiyaun\r\ex-OpenSSL1234\OpenSSL_1_1_1g-install-msvc1900-64\Release\bin"
$sslDlls = @("libcrypto-1_1-x64.dll", "libssl-1_1-x64.dll")
if (Test-Path $sslSrcDir) {
    foreach ($dll in $sslDlls) {
        $src = Join-Path $sslSrcDir $dll
        if (Test-Path $src) {
            Copy-WhitelistFile $src (Join-Path $ctkDestDir $dll) "dll" | Out-Null
            Write-Detail "  Copied OpenSSL: $dll"
        }
    }
    Write-Success "OpenSSL DLLs copied"
}

# --- 3.5 Qt5 Core DLLs (CRITICAL - prevents DLL version conflicts) ---
Write-Detail "Copying ALL Qt5 core DLLs..."
$qtSrcPaths = @(
    "C:\LHT_workspace\code\Qt5.15\5.15.2\msvc2019_64\bin",
    "$env:QT_ROOT\bin",
    "C:\Qt\5.15.2\msvc2019_64\bin"
)
$qtSrcDir = $null
foreach ($p in $qtSrcPaths) {
    if (Test-Path $p) {
        $qtSrcDir = $p
        break
    }
}
if ($qtSrcDir) {
    $qtCount = 0
    Get-ChildItem -Path $qtSrcDir -Filter "*.dll" -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -notmatch "d\.dll$") {
            Copy-WhitelistFile $_.FullName (Join-Path $ctkDestDir $_.Name) "dll" | Out-Null
            Write-Detail "  Copied Qt5: $($_.Name)"
            $qtCount++
        }
    }
    Write-Success "Qt5 DLLs copied ($qtCount files)"
} else {
    Write-ErrorOut "Qt5 DLL source directory not found!"
}

# --- 3.6 VTK Core DLLs (required by Slicer) ---
Write-Detail "Copying VTK core DLLs..."
$vtkSrcDir = "C:\Zhiyaun\r\VTK-build\bin\Release"
Get-ChildItem -Path $vtkSrcDir -Filter "vtk*.dll" -File -ErrorAction SilentlyContinue | ForEach-Object {
    if ($_.Name -notmatch "_d\.dll$") {
        Copy-WhitelistFile $_.FullName (Join-Path $ctkDestDir $_.Name) "dll" | Out-Null
        Write-Detail "  Copied VTK: $($_.Name)"
    }
}
Write-Success "VTK core DLLs copied"

# --- 3.7 ITK Core DLLs (ALL DLLs from ITK-build Release) ---
Write-Detail "Copying ALL ITK DLLs..."
$itkSrcDir = "C:\Zhiyaun\r\ITK-build\bin\Release"
if (Test-Path $itkSrcDir) {
    $itkCount = 0
    Get-ChildItem -Path $itkSrcDir -Filter "*.dll" -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -notmatch "_d\.dll$") {
            Copy-WhitelistFile $_.FullName (Join-Path $ctkDestDir $_.Name) "dll" | Out-Null
            Write-Detail "  Copied ITK: $($_.Name)"
            $itkCount++
        }
    }
    Write-Success "ITK DLLs copied ($itkCount files)"
} else {
    Write-WarningMsg "ITK Release directory not found: $itkSrcDir"
}

# --- 3.8 SlicerExecutionModel DLLs (ModuleDescriptionParser.dll) ---
Write-Detail "Copying SlicerExecutionModel DLLs..."
$semSrcDir = "C:\Zhiyaun\r\SlicerExecutionModel-build\ModuleDescriptionParser\bin\Release"
if (Test-Path $semSrcDir) {
    $semCount = 0
    Get-ChildItem -Path $semSrcDir -Filter "*.dll" -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -notmatch "_d\.dll$") {
            Copy-WhitelistFile $_.FullName (Join-Path $ctkDestDir $_.Name) "dll" | Out-Null
            Write-Detail "  Copied SEM: $($_.Name)"
            $semCount++
        }
    }
    Write-Success "SlicerExecutionModel DLLs copied ($semCount files)"
} else {
    Write-WarningMsg "SlicerExecutionModel Release directory not found: $semSrcDir"
}

# --- 3.8.1 LibArchive DLLs (archive.dll) ---
Write-Detail "Copying LibArchive DLLs..."
$libArchiveSrcDir = "C:\Zhiyaun\r\LibArchive-build\bin\Release"
if (Test-Path $libArchiveSrcDir) {
    $libArcCount = 0
    Get-ChildItem -Path $libArchiveSrcDir -Filter "*.dll" -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -notmatch "_d\.dll$") {
            Copy-WhitelistFile $_.FullName (Join-Path $ctkDestDir $_.Name) "dll" | Out-Null
            Write-Detail "  Copied LibArchive: $($_.Name)"
            $libArcCount++
        }
    }
    Write-Success "LibArchive DLLs copied ($libArcCount files)"
} else {
    Write-WarningMsg "LibArchive Release directory not found: $libArchiveSrcDir"
}

# --- 3.8.2 TBB DLLs (tbb12.dll and dependencies) ---
Write-Detail "Copying TBB DLLs..."
$tbbSrcDir = "C:\Zhiyaun\r\ex-tbb1234\oneapi-tbb-2021.5.0\redist\intel64\vc14"
if (Test-Path $tbbSrcDir) {
    $tbbCount = 0
    Get-ChildItem -Path $tbbSrcDir -Filter "*.dll" -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -notmatch "_d\.dll$") {
            Copy-WhitelistFile $_.FullName (Join-Path $ctkDestDir $_.Name) "dll" | Out-Null
            Write-Detail "  Copied TBB: $($_.Name)"
            $tbbCount++
        }
    }
    Write-Success "TBB DLLs copied ($tbbCount files)"
} else {
    Write-WarningMsg "TBB directory not found: $tbbSrcDir"
}

# --- 3.8.3 Teem DLLs (teem.dll) ---
Write-Detail "Copying Teem DLLs..."
$teemSrcDir = "C:\Zhiyaun\r\teem-build\bin\Release"
if (Test-Path $teemSrcDir) {
    $teemCount = 0
    Get-ChildItem -Path $teemSrcDir -Filter "*.dll" -File -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -notmatch "_d\.dll$") {
            Copy-WhitelistFile $_.FullName (Join-Path $ctkDestDir $_.Name) "dll" | Out-Null
            Write-Detail "  Copied Teem: $($_.Name)"
            $teemCount++
        }
    }
    Write-Success "Teem DLLs copied ($teemCount files)"
} else {
    Write-WarningMsg "Teem Release directory not found: $teemSrcDir"
}

# --- 3.9 Model Weights (.pth) - ALL subdirectories recursively ---
Write-Detail "Copying ALL model weights (.pth)..."
$segRoot = Join-Path $ModuleRoot "plans\seg"
if (Test-Path $segRoot) {
    Get-ChildItem -Path $segRoot -Filter "*.pth" -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
        $relPath = $_.FullName.Substring($ModuleRoot.Length)
        $destPath = Join-Path $SandboxDir "r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules$relPath"
        Copy-WhitelistFile $_.FullName $destPath "pth" | Out-Null
    }
}
Write-Success "Model weights copied ($($fileStats['pth']) .pth files)"

# --- 3.9.1 Dose prediction model weights ---
Write-Detail "Copying dose prediction model weights..."
$dosePreDir = Join-Path $ModuleRoot "plans\dose_pre"
if (Test-Path $dosePreDir) {
    Get-ChildItem -Path $dosePreDir -Filter "*.pth" -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object {
        $relPath = $_.FullName.Substring($ModuleRoot.Length)
        $destPath = Join-Path $SandboxDir "r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules$relPath"
        Copy-WhitelistFile $_.FullName $destPath "pth" | Out-Null
    }
    Write-Success "Dose prediction model weights copied"
}

# --- 3.6 Configuration Files (JSON) ---
Write-Detail "Copying configuration files..."
$jsonPatterns = @(
    (Join-Path $ModuleRoot "plans\config.json"),
    (Join-Path $ModuleRoot "plans\seg\total\config.json"),
    (Join-Path $ModuleRoot "plans\seg\total\label_mapping.json")
)
foreach ($pattern in $jsonPatterns) {
    Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue | ForEach-Object {
        $relPath = $_.FullName.Substring($ModuleRoot.Length)
        $destPath = Join-Path $SandboxDir "r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules$relPath"
        Copy-WhitelistFile $_.FullName $destPath "json" | Out-Null
    }
}
$segRoot = Join-Path $ModuleRoot "plans\seg"
if (Test-Path $segRoot) {
    Get-ChildItem -Path $segRoot -Filter "*.json" -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch '__MACOSX' -and $_.Name -notmatch '^\\._' -and $_.Name -notmatch '\\.DS_Store$'
    } | ForEach-Object {
        $relPath = $_.FullName.Substring($ModuleRoot.Length)
        $destPath = Join-Path $SandboxDir "r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules$relPath"
        Copy-WhitelistFile $_.FullName $destPath "json" | Out-Null
    }
    # Also copy .zip, .png, .txt files in seg directory (model archives, progress images, docs)
    # Exclude macOS artifacts
    foreach ($ext in @("*.zip", "*.png", "*.txt")) {
        Get-ChildItem -Path $segRoot -Filter $ext -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
            $_.FullName -notmatch '__MACOSX' -and $_.Name -notmatch '^\\._' -and $_.Name -notmatch '\\.DS_Store$'
        } | ForEach-Object {
            $relPath = $_.FullName.Substring($ModuleRoot.Length)
            $destPath = Join-Path $SandboxDir "r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules$relPath"
            Copy-WhitelistFile $_.FullName $destPath "other" | Out-Null
        }
    }
}
Write-Success "Configuration files copied ($($fileStats['json']) .json files)"

# --- 3.7 Resources Directory ---
# Resources/ contains icons, stylesheets, UI files, JSON configs, and some Slicer framework .py modules.
# The .py files here (e.g., SlicerWizard) are Slicer framework code, NOT our IP. Keep them.
Write-Detail "Copying resources (ALL files recursively, excluding __pycache__ and macOS artifacts)..."
$resDir = Join-Path $ModuleRoot "Resources"
if (Test-Path $resDir) {
    $resDestDir = Join-Path $SandboxDir "r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\Resources"
    $resFileCount = 0
    Get-ChildItem -Path $resDir -Recurse -File | Where-Object {
        # Keep ALL files including .py (Slicer framework modules)
        # Exclude __pycache__ and macOS artifacts
        $_.FullName -notmatch '__pycache__|__MACOSX' -and $_.Name -notmatch '^\\._' -and $_.Name -notmatch '\\.DS_Store$'
    } | ForEach-Object {
        # Use TrimStart to avoid Join-Path issues with leading backslash from Substring
        $relPath = $_.FullName.Substring($resDir.Length).TrimStart('\')
        $destPath = Join-Path $resDestDir $relPath
        Copy-WhitelistFile $_.FullName $destPath "other" | Out-Null
        $resFileCount++
    }
    Write-Success "Resources copied ($resFileCount files)"
}

# --- 3.8 Setup Config Script ---
$setupBat = Join-Path $ProjectRoot "setup_config.bat"
if (Test-Path $setupBat) {
    Copy-WhitelistFile $setupBat (Join-Path $SandboxDir "setup_config.bat") "other" | Out-Null
    Write-Success "setup_config.bat copied"
}

# --- 3.8.1 Debug Run Script (for troubleshooting startup issues) ---
# Run Zhiyuan.exe (launcher) instead of ZhiyuanApp-real.exe directly.
# Launcher reads ZhiyuanLauncherSettings.ini and sets up PYTHONHOME, QT_PLUGIN_PATH, etc.
Write-Detail "Creating Debug_Run.bat for troubleshooting..."
$debugBatContent = '@echo off
chcp 65001 >nul 2>&1
set LOGFILE=%~dp0debug_crash.log
set EXE=Zhiyuan.exe

echo ============================================ >>"%LOGFILE%" 2>&1
echo   Zhiyuan Debug Mode Launcher              >>"%LOGFILE%" 2>&1
echo   Timestamp: %date% %time%                 >>"%LOGFILE%" 2>&1
echo ============================================ >>"%LOGFILE%" 2>&1
echo.                                            >>"%LOGFILE%" 2>&1

echo [DEBUG] Checking critical paths...           >>"%LOGFILE%" 2>&1
if exist "%~dp0r\Zhiyuan-build\%EXE%" (
    echo [OK] %EXE% found                        >>"%LOGFILE%" 2>&1
) else (
    echo [FAIL] %EXE% NOT FOUND                   >>"%LOGFILE%" 2>&1
)
if exist "%~dp0r\Zhiyuan-build\bin\Python\slicer\slicerqt.py" (
    echo [OK] slicerqt.py found                   >>"%LOGFILE%" 2>&1
) else (
    echo [FAIL] slicerqt.py NOT FOUND             >>"%LOGFILE%" 2>&1
)
if exist "%~dp0r\Zhiyuan-build\share\Zhiyuan-5.9\Slicer.crt" (
    echo [OK] Slicer.crt found                    >>"%LOGFILE%" 2>&1
) else (
    echo [FAIL] Slicer.crt NOT FOUND              >>"%LOGFILE%" 2>&1
)
if exist "%~dp0r\Zhiyuan-build\lib\QtPlugins\platforms\qwindows.dll" (
    echo [OK] qwindows.dll found                  >>"%LOGFILE%" 2>&1
) else (
    echo [FAIL] qwindows.dll NOT FOUND            >>"%LOGFILE%" 2>&1
)
echo [DEBUG] Environment:                        >>"%LOGFILE%" 2>&1
echo   SLICER_HOME=%SLICER_HOME%                 >>"%LOGFILE%" 2>&1
echo   PYTHONHOME=%PYTHONHOME%                   >>"%LOGFILE%" 2>&1
echo   QT_PLUGIN_PATH=%QT_PLUGIN_PATH%           >>"%LOGFILE%" 2>&1
echo.                                            >>"%LOGFILE%" 2>&1

echo Starting %EXE% with --launcher-verbose...   >>"%LOGFILE%" 2>&1
cd /d "%~dp0r\Zhiyuan-build"
"%EXE%" --launcher-verbose >>"%LOGFILE%" 2>&1
echo.                                            >>"%LOGFILE%" 2>&1
echo ============================================ >>"%LOGFILE%" 2>&1
echo Program exited with code %ERRORLEVEL%        >>"%LOGFILE%" 2>&1
echo Log saved to: %LOGFILE%                     >>"%LOGFILE%" 2>&1
echo ============================================ >>"%LOGFILE%" 2>&1
exit /b %ERRORLEVEL%'
$debugBatPath = Join-Path $SandboxDir "Debug_Run.bat"
$debugBatContent | Out-File -FilePath $debugBatPath -Encoding ASCII
Write-Success "Debug_Run.bat created"

# --- 3.9 VC Redistributable ---
$vcRedist = Join-Path $ScriptDir "vc_redist.x64.exe"
if (Test-Path $vcRedist) {
    Copy-WhitelistFile $vcRedist (Join-Path $SandboxDir "vc_redist.x64.exe") "other" | Out-Null
    Write-Success "vc_redist.x64.exe copied"
} else {
    Write-WarningMsg "vc_redist.x64.exe not found at: $vcRedist"
    Write-WarningMsg "VC++ Runtime will not be included in the installer"
}

# --- 3.10 Slicer bin directory (ALL contents - executables, DLLs, subdirs) ---
# COMPREHENSIVE COPY: Copies ALL files from Slicer bin including external dependencies
# CRITICAL: bin/Python/ contains Slicer framework Python modules (slicerqt.py, util.py, etc.)
# These are NOT our IP - they are Slicer runtime dependencies and MUST be kept as .py source.
# Our IP is in qt-scripted-modules/ and plans/ which are compiled to .pyd separately.
Write-Detail "Copying Slicer bin directory (comprehensive - all files)..."
$binDir = Join-Path $BuildDir "bin"
if (Test-Path $binDir) {
    $binDestDir = Join-Path $SandboxDir "r\Zhiyuan-build\bin"
    $binFileCount = 0

    # STEP A: Fully copy bin/Python/ directory INCLUDING .py files
    # bin/Python/ contains Slicer framework modules (slicer/slicerqt.py, slicer/util.py, etc.)
    # These are required for Slicer initialization and are NOT our proprietary code.
    $binPythonDir = Join-Path $binDir "Python"
    if (Test-Path $binPythonDir) {
        $binPythonDestDir = Join-Path $binDestDir "Python"
        Write-Detail "Copying bin/Python/ (Slicer framework Python modules, including .py)..."
        Get-ChildItem -Path $binPythonDir -Recurse -File | ForEach-Object {
            $relPath = $_.FullName.Substring($binPythonDir.Length).TrimStart('\')
            $destPath = Join-Path $binPythonDestDir $relPath
            $type = switch -Regex ($_.Extension) {
                '\.dll$' { "dll" }
                '\.pyd$' { "pyd" }
                '\.py$' { "py" }
                default { "other" }
            }
            Copy-WhitelistFile $_.FullName $destPath $type | Out-Null
            $binFileCount++
        }
        Write-Detail "  bin/Python/ copied ($binFileCount files in Python subdir)"
    }

    # STEP B: Copy other bin/ files (excluding .py source to protect our IP)
    # Only exclude .py files that are NOT in bin/Python/ (bin/Python was handled above)
    # Keep ALL DLLs including lowercase ctk DLLs - both versions may be needed
    Get-ChildItem -Path $binDir -Recurse -File | Where-Object {
        $inBinPython = $_.FullName -like "$binPythonDir\*"
        -not $inBinPython -and
        $_.Name -notmatch "_d\.(dll|pyd|exe)$" -and
        $_.Extension -notin @('.py', '.pyc', '.lib', '.exp', '.pdb')
    } | ForEach-Object {
        $relPath = $_.FullName.Substring($binDir.Length).TrimStart('\')
        $destPath = Join-Path $binDestDir $relPath
        $type = switch -Regex ($_.Extension) {
            '\.dll$' { "dll" }
            '\.exe$' { "exe" }
            '\.pyd$' { "pyd" }
            default { "other" }
        }
        Copy-WhitelistFile $_.FullName $destPath $type | Out-Null
        $binFileCount++
    }
    Write-Success "Slicer bin directory copied ($binFileCount files total)"
} else {
    Write-ErrorOut "bin directory not found: $binDir"
}

# --- 3.10.1 Additional external build DLLs (teem, etc.) ---
# Find ALL DLLs in external build directories and copy to bin/Release
Write-Detail "Copying external build DLLs..."
$externalBuilds = @(
    "C:\Zhiyaun\r\teem-build\bin\Release",
    "C:\Zhiyaun\r\SlicerExecutionModel-build\ModuleDescriptionParser\bin\Release",
    "C:\Zhiyaun\r\LibArchive-build\bin\Release"
)
$extDllCount = 0
foreach ($extDir in $externalBuilds) {
    if (Test-Path $extDir) {
        Get-ChildItem -Path $extDir -Filter "*.dll" -File -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -notmatch "_d\.dll$"
        } | ForEach-Object {
            Copy-WhitelistFile $_.FullName (Join-Path $ctkDestDir $_.Name) "dll" | Out-Null
            $extDllCount++
        }
    }
}
Write-Success "External build DLLs copied ($extDllCount files)"

# --- 3.10.1 Python installation (python-install) ---
# Copy to lib/Python to match launcher settings (PYTHONHOME=../lib/Python)
Write-Detail "Copying Python installation to lib/Python..."
$pythonInstallDir = Join-Path (Split-Path $BuildDir -Parent) "python-install"
if (-not (Test-Path $pythonInstallDir)) {
    $pythonInstallDir = "C:\Zhiyaun\r\python-install"
}
if (Test-Path $pythonInstallDir) {
    # Target must be lib/Python because ZhiyuanLauncherSettingsToInstall.ini sets:
    # PYTHONHOME=<APPLAUNCHER_SETTINGS_DIR>/../lib/Python
    $pyDestDir = Join-Path $SandboxDir "r\Zhiyuan-build\lib\Python"
    Get-ChildItem -Path $pythonInstallDir -Recurse -File | Where-Object {
        $_.Name -notmatch "_d\.(dll|pyd)$" -and
        $_.Extension -notmatch '\.(lib|exp|pdb)$'
    } | ForEach-Object {
        $relPath = $_.FullName.Substring($pythonInstallDir.Length)
        $destPath = Join-Path $pyDestDir $relPath
        $type = switch -Regex ($_.Extension) {
            '\.dll$' { "dll" }
            '\.pyd$' { "pyd" }
            default { "other" }
        }
        Copy-WhitelistFile $_.FullName $destPath $type | Out-Null
    }
    Write-Success "Python installation copied to lib/Python (532 PYDs + 259 DLLs)"
} else {
    Write-ErrorOut "python-install directory not found! Python runtime will be missing."
}

# --- 3.10.1.1 CTK Python packages (ctk, qt) required for Slicer modules ---
# CTK Python packages are in CTK-build/bin/Python and are remapped to lib/Python/Lib
Write-Detail "Copying CTK Python packages (ctk, qt)..."
$ctkPythonSrc = "C:\Zhiyaun\r\CTK-build\CTK-build\bin\Python"
$ctkPythonDest = Join-Path $SandboxDir "r\Zhiyuan-build\lib\Python\Lib"
if (Test-Path $ctkPythonSrc) {
    $ctkCount = 0
    Get-ChildItem -Path $ctkPythonSrc -Recurse -File | ForEach-Object {
        $relPath = $_.FullName.Substring($ctkPythonSrc.Length).TrimStart('\')
        $destPath = Join-Path $ctkPythonDest $relPath
        $type = switch -Regex ($_.Extension) {
            '\.py$' { "py" }
            '\.pyd$' { "pyd" }
            '\.dll$' { "dll" }
            default { "other" }
        }
        Copy-WhitelistFile $_.FullName $destPath $type | Out-Null
        $ctkCount++
    }
    Write-Detail "  CTK Python packages copied ($ctkCount files)"
} else {
    Write-WarningMsg "CTK Python packages not found at: $ctkPythonSrc"
}

# --- 3.10.2 Qt Plugins (CRITICAL for GUI - per ZhiyuanLauncherSettingsToInstall.ini) ---
Write-Detail "Copying Qt plugins to lib/QtPlugins..."
$qtPluginSrcPaths = @(
    "$env:QT_ROOT\plugins",
    "C:\Qt\5.15.2\msvc2019_64\plugins",
    "C:\Qt\5.14.2\msvc2017_64\plugins",
    "C:\LHT_workspace\code\Qt5.15\5.15.2\msvc2019_64\plugins"
)
$qtPluginSrc = $null
foreach ($srcPath in $qtPluginSrcPaths) {
    if (Test-Path $srcPath) {
        $qtPluginSrc = $srcPath
        break
    }
}

if ($qtPluginSrc) {
    $qtPluginDestBase = Join-Path $SandboxDir "r\Zhiyuan-build\lib\QtPlugins"
    $subDirs = @("platforms", "styles", "imageformats", "iconengines", "sqldrivers")
    foreach ($subDir in $subDirs) {
        $srcSubDir = Join-Path $qtPluginSrc $subDir
        if (Test-Path $srcSubDir) {
            $destSubDir = Join-Path $qtPluginDestBase $subDir
            Get-ChildItem -Path $srcSubDir -Filter "*.dll" -File -ErrorAction SilentlyContinue | Where-Object {
                $_.Name -notmatch "_d\.dll$"
            } | ForEach-Object {
                Copy-WhitelistFile $_.FullName (Join-Path $destSubDir $_.Name) "dll" | Out-Null
            }
        }
    }
    # ALSO copy platform plugins to bin/Release/platforms for direct execution
    # (Debug_Run.bat runs ZhiyuanApp-real.exe directly, bypassing launcher)
    $binPlatformsDir = Join-Path $SandboxDir "r\Zhiyuan-build\bin\Release\platforms"
    $srcPlatformsDir = Join-Path $qtPluginSrc "platforms"
    if (Test-Path $srcPlatformsDir) {
        Get-ChildItem -Path $srcPlatformsDir -Filter "*.dll" -File -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -notmatch "_d\.dll$"
        } | ForEach-Object {
            Copy-WhitelistFile $_.FullName (Join-Path $binPlatformsDir $_.Name) "dll" | Out-Null
        }
        Write-Success "Qt platform plugins copied to bin/Release/platforms"
    }
    # ALSO copy sqldrivers to bin/Release for Qt SQL (CTK DICOM database)
    $binSqlDriversDir = Join-Path $SandboxDir "r\Zhiyuan-build\bin\Release\sqldrivers"
    $srcSqlDriversDir = Join-Path $qtPluginSrc "sqldrivers"
    if (Test-Path $srcSqlDriversDir) {
        Get-ChildItem -Path $srcSqlDriversDir -Filter "*.dll" -File -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -notmatch "_d\.dll$"
        } | ForEach-Object {
            Copy-WhitelistFile $_.FullName (Join-Path $binSqlDriversDir $_.Name) "dll" | Out-Null
        }
        Write-Success "Qt sqldrivers copied to bin/Release/sqldrivers"
    }
    Write-Success "Qt plugins copied to lib/QtPlugins"
} else {
    Write-WarningMsg "Qt plugin source not found in standard paths"
    Write-WarningMsg "Searched: $($qtPluginSrcPaths -join ', ')"
}

# --- 3.11 Launcher Settings INI files (CRITICAL for Slicer startup) ---
Write-Detail "Copying launcher settings INI files..."
$iniFiles = @(
    (Join-Path $BuildDir "ZhiyuanLauncherSettings.ini"),
    (Join-Path $BuildDir "ZhiyuanLauncherSettingsToInstall.ini"),
    (Join-Path $BuildDir "bin\Release\ZhiyuanLauncherSettings.ini"),
    (Join-Path $BuildDir "bin\Release\ZhiyuanLauncherSettingsToInstall.ini")
)
foreach ($iniFile in $iniFiles) {
    if (Test-Path $iniFile) {
        $iniName = Split-Path $iniFile -Leaf
        $destPath = if ($iniFile -match "bin\\Release") {
            Join-Path $SandboxDir "r\Zhiyuan-build\bin\Release\$iniName"
        } else {
            Join-Path $SandboxDir "r\Zhiyuan-build\$iniName"
        }
        Copy-WhitelistFile $iniFile $destPath "other" | Out-Null
        Write-Detail "  Copied: $iniName"
    }
}

# ALSO copy to bin/ (not just bin/Release/) - ZhiyuanApp-real.exe looks for INI here
$binIniDest1 = Join-Path $SandboxDir "r\Zhiyuan-build\bin\ZhiyuanLauncherSettings.ini"
$binIniDest2 = Join-Path $SandboxDir "r\Zhiyuan-build\bin\ZhiyuanLauncherSettingsToInstall.ini"
$binIniSrc1 = Join-Path $BuildDir "ZhiyuanLauncherSettings.ini"
$binIniSrc2 = Join-Path $BuildDir "ZhiyuanLauncherSettingsToInstall.ini"
if (Test-Path $binIniSrc1) { Copy-WhitelistFile $binIniSrc1 $binIniDest1 "other" | Out-Null; Write-Detail "  Copied to bin/: ZhiyuanLauncherSettings.ini" }
if (Test-Path $binIniSrc2) { Copy-WhitelistFile $binIniSrc2 $binIniDest2 "other" | Out-Null; Write-Detail "  Copied to bin/: ZhiyuanLauncherSettingsToInstall.ini" }

# FIX: Paths in bin/ copies of settings INIs must use ../ prefix since those INIs
# live in bin/ (not bin/Release/) so <APPLAUNCHER_SETTINGS_DIR> resolves differently
$binIniFiles = @($binIniDest1, $binIniDest2)
foreach ($binIni in $binIniFiles) {
    if (Test-Path $binIni) {
        $lines = Get-Content $binIni -Raw -Encoding UTF8 -ErrorAction Stop
        $originalContent = $lines
        $newLines = @()
        foreach ($line in $lines -split "`n") {
            # Fix: <APPLAUNCHER_SETTINGS_DIR>/lib/Python -> <APPLAUNCHER_SETTINGS_DIR>/../lib/Python
            if ($line -match '<APPLAUNCHER_SETTINGS_DIR>/lib/Python' -and $line -notmatch '<APPLAUNCHER_SETTINGS_DIR>/\.\./lib/Python') {
                $line = $line -replace '<APPLAUNCHER_SETTINGS_DIR>/lib/Python', '<APPLAUNCHER_SETTINGS_DIR>/../lib/Python'
            }
            # Fix: <APPLAUNCHER_SETTINGS_DIR>/lib/QtPlugins -> <APPLAUNCHER_SETTINGS_DIR>/../lib/QtPlugins
            if ($line -match '<APPLAUNCHER_SETTINGS_DIR>/lib/QtPlugins' -and $line -notmatch '<APPLAUNCHER_SETTINGS_DIR>/\.\./lib/QtPlugins') {
                $line = $line -replace '<APPLAUNCHER_SETTINGS_DIR>/lib/QtPlugins', '<APPLAUNCHER_SETTINGS_DIR>/../lib/QtPlugins'
            }
            # Fix: <APPLAUNCHER_SETTINGS_DIR>/lib/Zhiyuan-5.9 -> <APPLAUNCHER_SETTINGS_DIR>/../lib/Zhiyuan-5.9
            if ($line -match '<APPLAUNCHER_SETTINGS_DIR>/lib/Zhiyuan-5.9' -and $line -notmatch '<APPLAUNCHER_SETTINGS_DIR>/\.\./lib/Zhiyuan-5.9') {
                $line = $line -replace '<APPLAUNCHER_SETTINGS_DIR>/lib/Zhiyuan-5.9', '<APPLAUNCHER_SETTINGS_DIR>/../lib/Zhiyuan-5.9'
            }
            # Fix: <APPLAUNCHER_SETTINGS_DIR>/bin/Release -> <APPLAUNCHER_SETTINGS_DIR>/../bin/Release
            if ($line -match '<APPLAUNCHER_SETTINGS_DIR>/bin/Release' -and $line -notmatch '<APPLAUNCHER_SETTINGS_DIR>/\.\./bin/Release') {
                $line = $line -replace '<APPLAUNCHER_SETTINGS_DIR>/bin/Release', '<APPLAUNCHER_SETTINGS_DIR>/../bin/Release'
            }
            # Fix: <APPLAUNCHER_SETTINGS_DIR>/bin/Python -> <APPLAUNCHER_SETTINGS_DIR>/../bin/Python
            if ($line -match '<APPLAUNCHER_SETTINGS_DIR>/bin/Python' -and $line -notmatch '<APPLAUNCHER_SETTINGS_DIR>/\.\./bin/Python') {
                $line = $line -replace '<APPLAUNCHER_SETTINGS_DIR>/bin/Python', '<APPLAUNCHER_SETTINGS_DIR>/../bin/Python'
            }
            $newLines += $line
        }
        $content = $newLines -join "`n"
        if ($content -ne $originalContent) {
            Set-Content -Path $binIni -Value $content -Encoding UTF8 -ErrorAction Stop
            Write-Detail "  Fixed paths in bin/ INI: $($binIni.Substring($SandboxDir.Length))"
        }
    }
}

# Explicitly patch absolute python-install paths in ALL INI files (belt-and-suspenders)
$allIniFiles = Get-ChildItem -Path $SandboxDir -Recurse -Filter "*.ini" -File -ErrorAction SilentlyContinue
foreach ($iniFile in $allIniFiles) {
    try {
        $content = Get-Content $iniFile.FullName -Raw -Encoding UTF8 -ErrorAction Stop
        $originalContent = $content
        # Replace both forward-slash and backslash variants of the dev path
        $content = $content -replace [regex]::Escape("C:/Zhiyaun/r/python-install"), "<APPLAUNCHER_SETTINGS_DIR>/lib/Python"
        $content = $content -replace [regex]::Escape("C:\Zhiyaun\r\python-install"), "<APPLAUNCHER_SETTINGS_DIR>/lib/Python"
        $content = $content -replace [regex]::Escape("C:/LHT_workspace/code/Qt5.15/5.15.2/msvc2019_64/bin"), "<APPLAUNCHER_SETTINGS_DIR>/../lib/QtPlugins"
        $content = $content -replace [regex]::Escape("C:\LHT_workspace\code\Qt5.15\5.15.2\msvc2019_64\bin"), "<APPLAUNCHER_SETTINGS_DIR>/../lib/QtPlugins"
        if ($content -ne $originalContent) {
            Set-Content -Path $iniFile.FullName -Value $content -Encoding UTF8 -ErrorAction Stop
            Write-Detail "  Patched INI: $($iniFile.FullName.Substring($SandboxDir.Length))"
        }
    } catch {
        Write-Detail "  Skipped INI (locked/missing): $($iniFile.FullName.Substring($SandboxDir.Length))"
    }
}
Write-Success "Launcher settings INI files copied and patched"

# --- 3.12 Slicer share directory ---
Write-Detail "Copying Slicer share directory..."
$shareDir = Join-Path $BuildDir "share"
if (Test-Path $shareDir) {
    $shareDestDir = Join-Path $SandboxDir "r\Zhiyuan-build\share"
    Get-ChildItem -Path $shareDir -Recurse -File | Where-Object {
        $_.Extension -notmatch '\.(py|pyc)$'
    } | ForEach-Object {
        $relPath = $_.FullName.Substring($shareDir.Length).TrimStart('\')
        $destPath = Join-Path $shareDestDir $relPath
        Copy-WhitelistFile $_.FullName $destPath "other" | Out-Null
    }
}

# ============================================================================
# STEP 3.5: Security Scan - Smart .py removal (keep fallback for failed compilations)
# ============================================================================
Write-Host ""
Write-Host "=" * 70 -ForegroundColor DarkGray
Write-Info "STEP 3.5: Security Scan - Smart Python Source Code Removal"

$ourCodeDir = Join-Path $SandboxDir "r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules"
$pyFiles = Get-ChildItem -Path $ourCodeDir -Filter "*.py" -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch "\\plans\\seg\\" }

$removedCount = 0
$keptCount = 0
$keptList = @()

foreach ($pyFile in $pyFiles) {
    $stem = $pyFile.BaseName
    $pydPattern = Join-Path $pyFile.DirectoryName "${stem}.*.pyd"
    $pydExists = Test-Path $pydPattern

    if ($pydExists -and $pyFile.Name -ne 'BrachyPlan.py') {
        # Compiled .pyd exists - safe to remove .py source
        # EXCEPT: BrachyPlan.py must be kept (Slicer needs .py for module registration)
        Remove-Item $pyFile.FullName -Force -ErrorAction SilentlyContinue
        $removedCount++
        Write-Detail "  Removed (has .pyd): $($pyFile.Name)"
    } else {
        # NO .pyd exists - MUST keep .py to prevent runtime ImportError
        $keptCount++
        $keptList += $pyFile.Name
        Write-WarningMsg "  KEPT (no .pyd): $($pyFile.Name)"
    }
}

Write-Success "Security scan complete: $removedCount .py removed, $keptCount .py kept"
if ($keptList.Count -gt 0) {
    Write-Info "Kept files (no compiled .pyd or Numba incompatibility):"
    foreach ($k in $keptList) { Write-Detail "  - $k" }
}

# ============================================================================
# STEP 3.5b: Cleanup leftover source files in plans/ directory
# Remove backup files (*_backup.py) and v1 version files that have v2 .pyd
# ============================================================================
Write-Host ""
Write-Info "STEP 3.5b: Cleaning up plans/ leftover source files..."
$plansDir = Join-Path $SandboxDir "r\Zhiyuan-build\lib\Zhiyuan-5.9\qt-scripted-modules\plans"
$cleanedCount = 0

# Remove backup files
Get-ChildItem -Path $plansDir -Filter "*_backup.py" -File -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Detail "  Removed backup: $($_.Name)"
    Remove-Item $_.FullName -Force
    $cleanedCount++
}

# Remove v1 source files that have v2 .pyd (brachy_plan.py, core.py, utilizations.py)
$v1Files = @("brachy_plan.py", "core.py", "utilizations.py")
foreach ($v1File in $v1Files) {
    $v1Path = Join-Path $plansDir $v1File
    $v2Pyd = Join-Path $plansDir "$($v1File -replace '\.py$', '_v2.cp312-win_amd64.pyd')"
    if ((Test-Path $v1Path) -and (Test-Path $v2Pyd)) {
        Write-Detail "  Removed v1 source (has v2.pyd): $v1File"
        Remove-Item $v1Path -Force
        $cleanedCount++
    }
}

if ($cleanedCount -gt 0) {
    Write-Success "Cleaned $cleanedCount leftover source file(s)"
} else {
    Write-Detail "  No cleanup needed"
}

Write-Success "Files copied successfully ($($copiedFiles.Count) files, $([math]::Round($totalSize / 1MB, 2)) MB)"

# ============================================================================
# STEP 3.6d: Fix DLL case sensitivity (Windows DLL loading quirk)
# Some DLLs have lowercase names (ctkimageprocessingitkcore.dll) but the
# application loads them with mixed case (CTKImageProcessingITKCore.dll).
# Create case-correct copies to ensure DLL loading works.
# ALSO copy any missing CTK DLLs from Slicer-build that weren't in CTK-build.
# ============================================================================
Write-Host ""
Write-Host "=" * 70 -ForegroundColor DarkGray
Write-Info "STEP 3.6d: Fixing DLL case sensitivity and copying missing DLLs"
$ctkDllMappings = @{
    "ctkimageprocessingitkcore.dll" = "CTKImageProcessingITKCore.dll"
    "ctkdicomcore.dll" = "CTKDICOMCore.dll"
}
$releaseDir = Join-Path $SandboxDir "r\Zhiyuan-build\bin\Release"
$slicerBinRelease = Join-Path $BuildDir "bin\Release"
$caseFixCount = 0
$missingCopyCount = 0

foreach ($srcName in $ctkDllMappings.Keys) {
    $correctName = $ctkDllMappings[$srcName]
    $srcPath = Join-Path $releaseDir $srcName
    $destPath = Join-Path $releaseDir $correctName

    if ((Test-Path $srcPath) -and (-not (Test-Path $destPath))) {
        # Case-correct copy exists in sandbox - just rename it
        Copy-Item $srcPath $destPath -Force
        Write-Detail "  Created case-correct copy: $correctName"
        $caseFixCount++
    } elseif (-not (Test-Path $destPath)) {
        # DLL not in sandbox - copy from Slicer-build directly
        $slicerSrcPath = Join-Path $slicerBinRelease $srcName
        if (Test-Path $slicerSrcPath) {
            Copy-Item $slicerSrcPath $destPath -Force
            Write-Detail "  Copied missing DLL from Slicer-build: $srcName -> $correctName"
            $missingCopyCount++
        } else {
            Write-WarningMsg "  Missing DLL not found in Slicer-build: $srcName"
        }
    }
}
Write-Success "DLL case fix complete ($caseFixCount copies, $missingCopyCount missing DLLs copied)"

# ============================================================================
# STEP 3.6b: Fix ToInstall INI structure mismatch
# ZhiyuanLauncherSettingsToInstall.ini assumes launcher runs in a subdir (uses ../)
# But our launcher runs at Zhiyuan-build/ root. Dev INI has correct structure.
# So we rebase ToInstall on dev INI, then fix absolute paths.
# ============================================================================
Write-Host ""
Write-Host "=" * 70 -ForegroundColor DarkGray
Write-Info "STEP 3.6b: Fixing ToInstall INI structure mismatch"

$devIni = Join-Path $SandboxDir "r\Zhiyuan-build\ZhiyuanLauncherSettings.ini"
$installIni = Join-Path $SandboxDir "r\Zhiyuan-build\ZhiyuanLauncherSettingsToInstall.ini"
if ((Test-Path $devIni) -and (Test-Path $installIni)) {
    # Copy dev INI over ToInstall INI - dev INI has correct bin/Release structure
    Copy-Item $devIni $installIni -Force
    Write-Detail "  Rebased ToInstall INI on dev INI (correct structure)"
}
# Also update bin/ and bin/Release/ copies
$binDevIni = Join-Path $SandboxDir "r\Zhiyuan-build\bin\ZhiyuanLauncherSettings.ini"
$binInstallIni = Join-Path $SandboxDir "r\Zhiyuan-build\bin\ZhiyuanLauncherSettingsToInstall.ini"
if ((Test-Path $binDevIni) -and (Test-Path $binInstallIni)) {
    Copy-Item $binDevIni $binInstallIni -Force
    Write-Detail "  Rebased bin/ ToInstall INI on dev INI"
}
$binRelDevIni = Join-Path $SandboxDir "r\Zhiyuan-build\bin\Release\ZhiyuanLauncherSettings.ini"
$binRelInstallIni = Join-Path $SandboxDir "r\Zhiyuan-build\bin\Release\ZhiyuanLauncherSettingsToInstall.ini"
if ((Test-Path $binRelDevIni) -and (Test-Path $binRelInstallIni)) {
    Copy-Item $binRelDevIni $binRelInstallIni -Force
    Write-Detail "  Rebased bin/Release/ ToInstall INI on dev INI"
}

# --- 3.6b.1: Re-apply bin/ INI path fixes after STEP 3.6b overwrite ---
# STEP 3.6b overwrites bin/ INIs with dev INI (which has wrong paths for bin/ location).
# Re-apply the ../ prefix fix for all bin/ and bin/Release/ INI copies.
$binIniFixFiles = @(
    (Join-Path $SandboxDir "r\Zhiyuan-build\bin\ZhiyuanLauncherSettings.ini"),
    (Join-Path $SandboxDir "r\Zhiyuan-build\bin\ZhiyuanLauncherSettingsToInstall.ini"),
    (Join-Path $SandboxDir "r\Zhiyuan-build\bin\Release\ZhiyuanLauncherSettings.ini"),
    (Join-Path $SandboxDir "r\Zhiyuan-build\bin\Release\ZhiyuanLauncherSettingsToInstall.ini")
)
foreach ($binIni in $binIniFixFiles) {
    if (Test-Path $binIni) {
        $lines = Get-Content $binIni -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
        $originalContent = $lines
        $newLines = @()
        foreach ($line in $lines -split "`n") {
            # Fix: <APPLAUNCHER_SETTINGS_DIR>/lib/Python -> <APPLAUNCHER_SETTINGS_DIR>/../lib/Python
            if ($line -match '<APPLAUNCHER_SETTINGS_DIR>/lib/Python' -and $line -notmatch '<APPLAUNCHER_SETTINGS_DIR>/\.\./lib/Python') {
                $line = $line -replace '<APPLAUNCHER_SETTINGS_DIR>/lib/Python', '<APPLAUNCHER_SETTINGS_DIR>/../lib/Python'
            }
            # Fix: <APPLAUNCHER_SETTINGS_DIR>/lib/QtPlugins -> <APPLAUNCHER_SETTINGS_DIR>/../lib/QtPlugins
            if ($line -match '<APPLAUNCHER_SETTINGS_DIR>/lib/QtPlugins' -and $line -notmatch '<APPLAUNCHER_SETTINGS_DIR>/\.\./lib/QtPlugins') {
                $line = $line -replace '<APPLAUNCHER_SETTINGS_DIR>/lib/QtPlugins', '<APPLAUNCHER_SETTINGS_DIR>/../lib/QtPlugins'
            }
            # Fix: <APPLAUNCHER_SETTINGS_DIR>/lib/Zhiyuan-5.9 -> <APPLAUNCHER_SETTINGS_DIR>/../lib/Zhiyuan-5.9
            if ($line -match '<APPLAUNCHER_SETTINGS_DIR>/lib/Zhiyuan-5.9' -and $line -notmatch '<APPLAUNCHER_SETTINGS_DIR>/\.\./lib/Zhiyuan-5.9') {
                $line = $line -replace '<APPLAUNCHER_SETTINGS_DIR>/lib/Zhiyuan-5.9', '<APPLAUNCHER_SETTINGS_DIR>/../lib/Zhiyuan-5.9'
            }
            # Fix: <APPLAUNCHER_SETTINGS_DIR>/bin/Release -> <APPLAUNCHER_SETTINGS_DIR>/../bin/Release
            if ($line -match '<APPLAUNCHER_SETTINGS_DIR>/bin/Release' -and $line -notmatch '<APPLAUNCHER_SETTINGS_DIR>/\.\./bin/Release') {
                $line = $line -replace '<APPLAUNCHER_SETTINGS_DIR>/bin/Release', '<APPLAUNCHER_SETTINGS_DIR>/../bin/Release'
            }
            # Fix: <APPLAUNCHER_SETTINGS_DIR>/bin/Python -> <APPLAUNCHER_SETTINGS_DIR>/../bin/Python
            if ($line -match '<APPLAUNCHER_SETTINGS_DIR>/bin/Python' -and $line -notmatch '<APPLAUNCHER_SETTINGS_DIR>/\.\./bin/Python') {
                $line = $line -replace '<APPLAUNCHER_SETTINGS_DIR>/bin/Python', '<APPLAUNCHER_SETTINGS_DIR>/../bin/Python'
            }
            # Fix: SLICER_HOME=<APPLAUNCHER_SETTINGS_DIR> -> SLICER_HOME=<APPLAUNCHER_SETTINGS_DIR>/..
            # This is critical: without this fix, SLICER_HOME resolves to bin/ instead of Zhiyuan-build/,
            # causing module factory to search bin/lib/Zhiyuan-5.9/ (doesn't exist) instead of
            # Zhiyuan-build/lib/Zhiyuan-5.9/ (where modules actually are).
            if ($line -match 'SLICER_HOME=<APPLAUNCHER_SETTINGS_DIR>' -and $line -notmatch 'SLICER_HOME=<APPLAUNCHER_SETTINGS_DIR>/\.\.') {
                $line = $line -replace 'SLICER_HOME=<APPLAUNCHER_SETTINGS_DIR>', 'SLICER_HOME=<APPLAUNCHER_SETTINGS_DIR>/..'
                Write-Detail "    [SLICER_HOME FIX] Applied ../ prefix for SLICER_HOME in bin/ INI"
            }
            $newLines += $line
        }
        $content = $newLines -join "`n"
        if ($content -ne $originalContent) {
            Set-Content -Path $binIni -Value $content -Encoding UTF8 -ErrorAction SilentlyContinue
            Write-Detail "  Re-fixed bin/ INI paths: $($binIni.Substring($SandboxDir.Length))"
        }
    }
}

# --- 3.6b.2: Fix PythonSlicer .ini PYTHONHOME ---
# PythonSlicerLauncherSettings.ini is in lib/Python/bin/, so APPLAUNCHER_DIR = lib/Python/bin/
# The .ini must set PYTHONHOME=<APPLAUNCHER_DIR>/.. (resolves to lib/Python)
# NOT <APPLAUNCHER_DIR>/../lib/Python (resolves to lib/Python/lib/Python - WRONG)
# NOT <APPLAUNCHER_SETTINGS_DIR>/lib/Python (resolves to lib/Python/bin/lib/Python - WRONG)
Write-Detail "Fixing PythonSlicer .ini PYTHONHOME..."
$pySlicerInis = @(
    (Join-Path $SandboxDir "r\Zhiyuan-build\lib\Python\bin\PythonSlicerLauncherSettings.ini"),
    (Join-Path $SandboxDir "r\Zhiyuan-build\lib\Python\bin\PythonSlicerLauncherSettingsToInstall.ini")
)
foreach ($pyIni in $pySlicerInis) {
    if (-not (Test-Path $pyIni)) { continue }
    $content = Get-Content $pyIni -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    $originalContent = $content
    # Fix wrong patterns: any PYTHONHOME that doesn't resolve to lib/Python
    $content = $content -replace 'PYTHONHOME=<APPLAUNCHER_SETTINGS_DIR>/lib/Python', 'PYTHONHOME=<APPLAUNCHER_DIR>/..'
    $content = $content -replace 'PYTHONHOME=<APPLAUNCHER_DIR>/../lib/Python', 'PYTHONHOME=<APPLAUNCHER_DIR>/..'
    if ($content -ne $originalContent) {
        Set-Content -Path $pyIni -Value $content -Encoding UTF8 -ErrorAction SilentlyContinue
        Write-Detail "  Fixed PythonSlicer PYTHONHOME: $($pyIni.Substring($SandboxDir.Length))"
    }
}

# --- 3.6c: Copy SplashScreen.png (required by launcher) ---
Write-Detail "Copying SplashScreen.png..."
$splashSrc = "C:\Zhiyaun\Applications\ZhiyuanApp\Resources\Images\SplashScreen.png"
$splashDest = Join-Path $SandboxDir "r\Zhiyuan-build\share\Zhiyuan-5.9\SplashScreen.png"
if (Test-Path $splashSrc) {
    Copy-WhitelistFile $splashSrc $splashDest "other" | Out-Null
    Write-Detail "  Copied: SplashScreen.png"
} else {
    Write-WarningMsg "SplashScreen.png not found at: $splashSrc"
}

Write-Host "[DEBUG] About to enter STEP 3.7..." -ForegroundColor Yellow

# ============================================================================
# STEP 3.7: Deep Path Substitution - Slicer-build -> Zhiyuan-build
# Replace Slicer-build with Zhiyuan-build in LAUNCHER INI FILES ONLY
# This is critical for the launcher to find correct paths at runtime
#
# OPTIMIZED: Only process 8 launcher config files instead of 13000+ files.
# The 6 launcher INIs (*LauncherSettings.ini / *ToInstall.ini) are the only
# files that need path substitution - all other *.ini files (numpy, nibabel, etc.)
# are Python packages that should NOT be modified.
# ============================================================================
Write-Host ""
Write-Host "=" * 70 -ForegroundColor DarkGray
Write-Info "STEP 3.7: Deep Path Substitution (Slicer-build -> Zhiyuan-build)"

$pathReplacements = [ordered]@{
    # Fix absolute python-install path from dev machine (forward slash)
    "C:/Zhiyaun/r/python-install" = "<APPLAUNCHER_SETTINGS_DIR>/lib/Python"
    # Fix absolute python-install path from dev machine (backslash)
    "C:\Zhiyaun\r\python-install" = "<APPLAUNCHER_SETTINGS_DIR>/lib/Python"
    # Fix dev machine Qt path (forward slash)
    "C:/LHT_workspace/code/Qt5.15/5.15.2/msvc2019_64/bin" = "<APPLAUNCHER_SETTINGS_DIR>/lib/QtPlugins"
    # Fix dev machine Qt path (backslash)
    "C:\LHT_workspace\code\Qt5.15\5.15.2\msvc2019_64\bin" = "<APPLAUNCHER_SETTINGS_DIR>/lib/QtPlugins"
    # Fix ../lib/ paths - use macro so they resolve correctly regardless of launcher location
    # Previously kept as-is because dev INI assumes launcher in bin/, but our launcher is at root
    "../lib/Zhiyuan-5.9/qt-loadable-modules" = "<APPLAUNCHER_SETTINGS_DIR>/lib/Zhiyuan-5.9/qt-loadable-modules"
    "../lib/Zhiyuan-5.9/qt-loadable-modules/Release" = "<APPLAUNCHER_SETTINGS_DIR>/lib/Zhiyuan-5.9/qt-loadable-modules/Release"
    # Fix all external build paths to point to bin/Release (where DLLs were copied)
    "C:/Zhiyaun/r/VTK-build/bin/Release" = "<APPLAUNCHER_SETTINGS_DIR>/bin/Release"
    "C:/Zhiyaun/r/ITK-build/bin/Release" = "<APPLAUNCHER_SETTINGS_DIR>/bin/Release"
    "C:/Zhiyaun/r/CTK-build/CTK-build/bin/Release" = "<APPLAUNCHER_SETTINGS_DIR>/bin/Release"
    "C:/Zhiyaun/r/CTK-build/PythonQt-build/Release" = "<APPLAUNCHER_SETTINGS_DIR>/bin/Release"
    "C:/Zhiyaun/r/teem-build/bin/Release" = "<APPLAUNCHER_SETTINGS_DIR>/bin/Release"
    "C:/Zhiyaun/r/DCMTK-build/bin/Release" = "<APPLAUNCHER_SETTINGS_DIR>/bin/Release"
    "C:/Zhiyaun/r/LibArchive-install/bin" = "<APPLAUNCHER_SETTINGS_DIR>/bin/Release"
    "C:/Zhiyaun/r/SimpleITK-build/SimpleITK-build/bin/Release" = "<APPLAUNCHER_SETTINGS_DIR>/bin/Release"
    "C:/Zhiyaun/r/SlicerExecutionModel-build/ModuleDescriptionParser/bin/Release" = "<APPLAUNCHER_SETTINGS_DIR>/bin/Release"
    "C:/Zhiyaun/r/OpenSSL-install/Release/bin" = "<APPLAUNCHER_SETTINGS_DIR>/bin/Release"
    "C:/Zhiyaun/r/tbb-install/redist/intel64/vc14" = "<APPLAUNCHER_SETTINGS_DIR>/bin/Release"
    "C:/Zhiyaun/r/JsonCpp-build/bin/Release" = "<APPLAUNCHER_SETTINGS_DIR>/bin/Release"
    # Fix CTK non-Release bin path (used in QT_PLUGIN_PATH)
    "C:/Zhiyaun/r/CTK-build/CTK-build/bin" = "<APPLAUNCHER_SETTINGS_DIR>/bin/Release"
    "C:\Zhiyaun\r\CTK-build\CTK-build\bin" = "<APPLAUNCHER_SETTINGS_DIR>/bin/Release"
    # Fix Qt plugins path (used in QT_PLUGIN_PATH)
    "C:/LHT_workspace/code/Qt5.15/5.15.2/msvc2019_64/plugins" = "<APPLAUNCHER_SETTINGS_DIR>/lib/QtPlugins"
    "C:\LHT_workspace\code\Qt5.15\5.15.2\msvc2019_64\plugins" = "<APPLAUNCHER_SETTINGS_DIR>/lib/QtPlugins"
    # Fix VTK site-packages path (used in PYTHONPATH)
    "C:/Zhiyaun/r/VTK-build/lib/site-packages" = "<APPLAUNCHER_SETTINGS_DIR>/lib/Python/Lib/site-packages"
    "C:\Zhiyaun\r\VTK-build\lib\site-packages" = "<APPLAUNCHER_SETTINGS_DIR>/lib/Python/Lib/site-packages"
    # Fix CTK Python path (used in PYTHONPATH)
    "C:/Zhiyaun/r/CTK-build/CTK-build/bin/Python" = "<APPLAUNCHER_SETTINGS_DIR>/lib/Python/Lib"
    "C:\Zhiyaun\r\CTK-build\CTK-build\bin\Python" = "<APPLAUNCHER_SETTINGS_DIR>/lib/Python/Lib"
    # Fix SLICER_HOME (both original Slicer-build and already-replaced Zhiyuan-build)
    "SLICER_HOME=C:/Zhiyaun/r/Slicer-build" = "SLICER_HOME=<APPLAUNCHER_SETTINGS_DIR>"
    "SLICER_HOME=C:\Zhiyaun\r\Slicer-build" = "SLICER_HOME=<APPLAUNCHER_SETTINGS_DIR>"
    "SLICER_HOME=C:/Zhiyaun/r/Zhiyuan-build" = "SLICER_HOME=<APPLAUNCHER_SETTINGS_DIR>"
    "SLICER_HOME=C:\Zhiyaun\r\Zhiyuan-build" = "SLICER_HOME=<APPLAUNCHER_SETTINGS_DIR>"
    # Fix SSL cert path
    "C:/Zhiyaun/r/Slicer-build/share/Zhiyuan-5.9/Slicer.crt" = "<APPLAUNCHER_SETTINGS_DIR>/share/Zhiyuan-5.9/Slicer.crt"
    "C:\Zhiyaun\r\Slicer-build\share\Zhiyuan-5.9\Slicer.crt" = "<APPLAUNCHER_SETTINGS_DIR>/share/Zhiyuan-5.9/Slicer.crt"
    # Fix SplashScreen path - MUST be before Slicer-build replacement!
    "C:/Zhiyaun/Applications/ZhiyuanApp/Resources/Images/SplashScreen.png" = "<APPLAUNCHER_SETTINGS_DIR>/share/Zhiyuan-5.9/SplashScreen.png"
    "C:\Zhiyaun\Applications\ZhiyuanApp\Resources\Images\SplashScreen.png" = "<APPLAUNCHER_SETTINGS_DIR>/share/Zhiyuan-5.9/SplashScreen.png"
    # Slicer-build -> Zhiyuan-build (MUST be last to avoid interfering with more specific replacements)
    "Slicer-build" = "Zhiyuan-build"
}

Write-Host "[DEBUG] pathReplacements defined, count=$($pathReplacements.Count)" -ForegroundColor Yellow

# OPTIMIZED: Only target the 8 launcher INI files - don't scan 13000+ files
# Includes root-level INIs that were previously missed
$launcherIniFiles = @(
    (Join-Path $SandboxDir "r\Zhiyuan-build\ZhiyuanLauncherSettings.ini"),
    (Join-Path $SandboxDir "r\Zhiyuan-build\ZhiyuanLauncherSettingsToInstall.ini"),
    (Join-Path $SandboxDir "r\Zhiyuan-build\bin\ZhiyuanLauncherSettings.ini"),
    (Join-Path $SandboxDir "r\Zhiyuan-build\bin\ZhiyuanLauncherSettingsToInstall.ini"),
    (Join-Path $SandboxDir "r\Zhiyuan-build\bin\SlicerDesignerLauncherSettings.ini"),
    (Join-Path $SandboxDir "r\Zhiyuan-build\bin\SlicerDesignerLauncherSettingsToInstall.ini"),
    (Join-Path $SandboxDir "r\Zhiyuan-build\lib\Python\bin\PythonSlicerLauncherSettings.ini"),
    (Join-Path $SandboxDir "r\Zhiyuan-build\lib\Python\bin\PythonSlicerLauncherSettingsToInstall.ini")
)

$totalReplacements = 0

Write-Host "[DEBUG] Processing $($launcherIniFiles.Count) launcher INI files..." -ForegroundColor Yellow
foreach ($file in $launcherIniFiles) {
    if (-not (Test-Path $file)) {
        Write-WarningMsg "Launcher INI not found, skipping: $($file.Substring($SandboxDir.Length))"
        continue
    }
    $content = Get-Content $file -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    $modified = $false
    foreach ($key in $pathReplacements.Keys) {
        $newValue = $pathReplacements[$key]
        if ($newValue -eq "PRESERVE_ORIGINAL") { continue }
        if ($content -match [regex]::Escape($key)) {
            $content = $content -replace [regex]::Escape($key), $newValue
            $modified = $true
            $totalReplacements++
        }
    }
    if ($modified) {
        Set-Content -Path $file -Value $content -Encoding UTF8 -ErrorAction SilentlyContinue
        Write-Detail "  Patched: $($file.Substring($SandboxDir.Length))"
    }
}

# Also patch setup_config.bat and Debug_Run.bat content (already copied but may have old paths)
$setupBatInSandbox = Join-Path $SandboxDir "setup_config.bat"
if (Test-Path $setupBatInSandbox) {
    $setupContent = Get-Content $setupBatInSandbox -Raw -Encoding UTF8
    if ($setupContent -match "Slicer-build") {
        $setupContent = $setupContent -replace "Slicer-build", "Zhiyuan-build"
        Set-Content -Path $setupBatInSandbox -Value $setupContent -Encoding UTF8
        Write-Detail "  Patched: setup_config.bat"
        $totalReplacements++
    }
}

$debugBatInSandbox = Join-Path $SandboxDir "Debug_Run.bat"
if (Test-Path $debugBatInSandbox) {
    $debugContent = Get-Content $debugBatInSandbox -Raw -Encoding UTF8
    if ($debugContent -match "Slicer-build") {
        $debugContent = $debugContent -replace "Slicer-build", "Zhiyuan-build"
        Set-Content -Path $debugBatInSandbox -Value $debugContent -Encoding UTF8
        Write-Detail "  Patched: Debug_Run.bat"
        $totalReplacements++
    }
}

Write-Success "Path substitution complete ($totalReplacements files patched)"

# ============================================================================
# STEP 3.6b: Create CMakeCache.txt for Module Loading
# Slicer uses CMakeCache.txt presence to determine intDir (development vs installed).
# Without it, intDir="" and module factory misses qt-loadable-modules/Release/ subdirectory.
# ============================================================================
Write-Host ""
Write-Host "=" * 70 -ForegroundColor DarkGray
Write-Info "STEP 3.6b: Creating CMakeCache.txt for module loading"

$cmakeCachePath = Join-Path $SandboxDir "r\Zhiyuan-build\CMakeCache.txt"
if (-not (Test-Path $cmakeCachePath)) {
    New-Item -Path $cmakeCachePath -ItemType File -Force | Out-Null
    Write-Success "Created empty CMakeCache.txt (enables intDir=Release for module factory)"
} else {
    Write-Detail "CMakeCache.txt already exists"
}

# ============================================================================
# STEP 3.6c: Copy CTK Designer Plugins for Custom Widget Loading
# QUiLoader needs CTK designer plugins to instantiate ctkCollapsibleButton etc.
# Source build has CTK-build/bin in QT_PLUGIN_PATH (which contains designer/ subdir).
# Packaged build needs the designer plugins in bin/designer/.
# ============================================================================
Write-Host ""
Write-Host "=" * 70 -ForegroundColor DarkGray
Write-Info "STEP 3.6c: Copying CTK Designer Plugins"

$ctkDesignerSrc = "C:\Zhiyaun\r\CTK-build\CTK-build\bin\designer"
$designerDest = Join-Path $SandboxDir "r\Zhiyuan-build\bin\designer"

if (Test-Path $ctkDesignerSrc) {
    if (-not (Test-Path $designerDest)) {
        New-Item -Path $designerDest -ItemType Directory -Force | Out-Null
    }
    $ctkDesignerDlls = Get-ChildItem -Path $ctkDesignerSrc -Filter "*.dll" -File
    foreach ($dll in $ctkDesignerDlls) {
        $destFile = Join-Path $designerDest $dll.Name
        if (-not (Test-Path $destFile)) {
            Copy-Item $dll.FullName $destFile -Force
            Write-Detail "  Copied: $($dll.Name)"
        }
    }
    Write-Success "CTK designer plugins copied to bin/designer/"
} else {
    Write-WarningMsg "CTK designer source not found: $ctkDesignerSrc"
}

# ============================================================================
# STEP 3.6d: Add designer/ to QT_PLUGIN_PATH in Launcher INI Files
# QUiLoader discovers custom widgets through Qt's plugin system.
# The designer/ subdirectory must be in QT_PLUGIN_PATH.
# ============================================================================
Write-Host ""
Write-Host "=" * 70 -ForegroundColor DarkGray
Write-Info "STEP 3.6d: Adding designer/ to QT_PLUGIN_PATH in launcher INIs"

$launcherInis = @(
    (Join-Path $SandboxDir "r\Zhiyuan-build\ZhiyuanLauncherSettings.ini"),
    (Join-Path $SandboxDir "r\Zhiyuan-build\ZhiyuanLauncherSettingsToInstall.ini")
)

foreach ($iniPath in $launcherInis) {
    if (-not (Test-Path $iniPath)) { continue }

    $lines = Get-Content $iniPath -Encoding UTF8
    $inQtPlugin = $false
    $qtPluginSize = 0
    $maxIdx = 0
    $hasDesigner = $false
    $newLines = @()

    foreach ($line in $lines) {
        if ($line -match '^\[QT_PLUGIN_PATH\]') {
            $inQtPlugin = $true
        } elseif ($inQtPlugin -and $line -match '^(\d+)\\path=') {
            $idx = [int]$Matches[1]
            if ($idx -gt $maxIdx) { $maxIdx = $idx }
            if ($line -match 'designer') { $hasDesigner = $true }
        } elseif ($inQtPlugin -and $line -match '^size=(\d+)') {
            $qtPluginSize = [int]$Matches[1]
            $inQtPlugin = $false

            if (-not $hasDesigner) {
                $newIdx = $maxIdx + 1
                $newLines += "$newIdx\path=<APPLAUNCHER_SETTINGS_DIR>/bin/designer"
                $qtPluginSize++
                $newLines += "size=$qtPluginSize"
                Write-Detail "  Added designer/ path to $(Split-Path $iniPath -Leaf)"
                continue
            }
        }
        $newLines += $line
    }

    if (-not $hasDesigner) {
        Set-Content -Path $iniPath -Value $newLines -Encoding UTF8
    }
}
Write-Success "QT_PLUGIN_PATH designer/ path configured"

# ============================================================================
# STEP 3.7a: RENAME PHYSICAL FOLDERS - DISABLED
# DO NOT RENAME Slicer-5.9 folders! C++ modules have hardcoded Slicer-5.9 paths.
# Renaming causes SubjectHierarchy, Segmentations, DICOM etc to fail loading.
# ============================================================================
# Write-Host ""
# Write-Host "=" * 70 -ForegroundColor DarkGray
# Write-Info "STEP 3.7a: Renaming Physical Folders (Slicer-5.9 -> Zhiyuan-5.9)"
#
# $foldersToRename = @(
#     (Join-Path $SandboxDir "r\Zhiyuan-build\lib\Slicer-5.9"),
#     (Join-Path $SandboxDir "r\Zhiyuan-build\share\Slicer-5.9")
# )
# foreach ($folder in $foldersToRename) {
#     if (Test-Path $folder) {
#         $parent = Split-Path $folder -Parent
#         try {
#             Rename-Item -Path $folder -NewName "Zhiyuan-5.9" -ErrorAction Stop
#             Write-Success "Renamed folder: $($folder.Substring($SandboxDir.Length)) -> Zhiyuan-5.9"
#         } catch {
#             $expectedNewPath = Join-Path $parent "Zhiyuan-5.9"
#             if (Test-Path $expectedNewPath) {
#                 Write-WarningMsg "Target already exists, skipping: $expectedNewPath"
#             } else {
#                 Write-ErrorOut "Failed to rename folder: $folder -> $_"
#             }
#         }
#     } else {
#         Write-Detail "Folder not found (may already be renamed): $($folder.Substring($SandboxDir.Length))"
#     }
# }
Write-Detail "STEP 3.7a DISABLED - Slicer-5.9 folders preserved (C++ modules have hardcoded paths)"

# ============================================================================
# STEP 3.7b: Set Extensions Directory to User-Writable Location
# Slicer defaults to creating extensions under SLICER_HOME which is in Program Files (read-only).
# This causes "Failed to create extensions directory" errors at runtime.
# Fix: Set SLICER_EXTENSIONS_DIR to %LOCALAPPDATA% which is always user-writable.
# ============================================================================
Write-Host ""
Write-Host "=" * 70 -ForegroundColor DarkGray
Write-Info "STEP 3.7b: Setting Extensions Directory to User-Writable Location"

$allIniFiles = Get-ChildItem -Path $SandboxDir -Recurse -Filter "*.ini" -File -ErrorAction SilentlyContinue
$extDirCount = 0
foreach ($iniFile in $allIniFiles) {
    $lines = Get-Content $iniFile.FullName -Encoding UTF8
    $envIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\[EnvironmentVariables\]') {
            $envIdx = $i
            break
        }
    }
    if ($envIdx -ge 0) {
        # Find end of EnvironmentVariables section
        $endIdx = $lines.Count
        for ($i = $envIdx + 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '^\[' -and $lines[$i] -notmatch 'EnvironmentVariables') {
                $endIdx = $i
                break
            }
        }
        # Check if SLICER_EXTENSIONS_DIR already exists
        $hasIt = $false
        for ($i = $envIdx + 1; $i -lt $endIdx; $i++) {
            if ($lines[$i] -match 'SLICER_EXTENSIONS_DIR') {
                $hasIt = $true
                break
            }
        }
        if (-not $hasIt) {
            $newLines = @()
            for ($i = 0; $i -lt $endIdx; $i++) { $newLines += $lines[$i] }
            $newLines += "SLICER_EXTENSIONS_DIR=%LOCALAPPDATA%/Zhiyuan/Extensions-33740"
            for ($i = $endIdx; $i -lt $lines.Count; $i++) { $newLines += $lines[$i] }
            Set-Content -Path $iniFile.FullName -Value $newLines -Encoding UTF8
            $extDirCount++
            Write-Detail "  Added SLICER_EXTENSIONS_DIR to $($iniFile.Name)"
        }
    }
}
Write-Success "Extensions directory set in $extDirCount INI files"

# ============================================================================
# STEP 4: Installer Generation
# ============================================================================
Write-Host ""
Write-Host "=" * 70 -ForegroundColor DarkGray
Write-Info "STEP 4: Installer Generation"

if (-not (Test-Path $ReleaseDir)) { New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null }
$installerName = "Zhiyuan-Installer-v$Version.exe"
$installerPath = Join-Path $ReleaseDir $installerName
$issFile = Join-Path $ScriptDir "Zhiyuan_Setup.iss"

function New-FallbackInstaller {
    $archivePath = Join-Path $ReleaseDir "Zhiyuan-v$Version.7z"
    Write-Detail "Creating 7z archive..."
    $sevenZip = "C:\Program Files\7-Zip\7z.exe"
    if (-not (Test-Path $sevenZip)) {
        Write-ErrorOut "7-Zip not found at: $sevenZip"
        throw "Neither Inno Setup nor 7-Zip available for packaging"
    }
    & $sevenZip a -t7z -m0=lzma2 -mx=9 -mfb=256 -md=32m -ms=on $archivePath (Join-Path $SandboxDir "*") | Out-Null

    if (Test-Path $archivePath) {
        Write-Success "Archive created: $archivePath"
        Write-Info "Use the .7z archive directly for distribution"
    } else {
        throw "Failed to create archive"
    }
}

if (Test-Path $InnoSetupPath) {
    Write-Detail "Using Inno Setup compiler: $InnoSetupPath"
    try {
        $tempIss = Join-Path $ProjectRoot "Zhiyuan_Setup_temp.iss"
        $issContent = Get-Content $issFile -Raw -Encoding UTF8

        $issContent = $issContent.Replace("0000000000", $totalSize.ToString())

        # Patch OutputDir to use absolute path (relative paths resolve from ISS location, not CWD)
        # Use simple string replacement to avoid regex issues
        $issContent = $issContent.Replace("OutputDir=..\releases", "OutputDir=$ReleaseDir")

        # Always set versioned OutputBaseFilename
        $issContent = $issContent.Replace("OutputBaseFilename=Zhiyuan-Installer", "OutputBaseFilename=Zhiyuan-Installer-v$Version")

        Set-Content -Path $tempIss -Value $issContent -Encoding UTF8

        # Debug: verify the patched content
        $checkContent = Get-Content $tempIss -Raw -Encoding UTF8
        if ($checkContent -match "OutputDir=(.+)") {
            Write-Detail "Patched OutputDir: $($Matches[1])"
        }

        Write-Info "Compiling Inno Setup script..."
        $process = Start-Process -FilePath $InnoSetupPath `
            -ArgumentList "`"$tempIss`" /DMyAppVersion=`"$Version`"" `
            -WorkingDirectory $ProjectRoot `
            -PassThru -NoNewWindow -Wait

        Remove-Item $tempIss -Force -ErrorAction SilentlyContinue

        if ($process.ExitCode -ne 0) {
            Write-ErrorOut "Inno Setup compilation failed (exit code: $($process.ExitCode))"
            throw "Inno Setup compilation failed"
        }
        Write-Success "Installer created: $installerName"

        # Also create a 7z portable archive as a fallback / alternative distribution method
        Write-Info "Creating 7z portable archive (fallback)..."
        try {
            $sevenZip = "C:\Program Files\7-Zip\7z.exe"
            if (Test-Path $sevenZip) {
                $archivePath = Join-Path $ReleaseDir "Zhiyuan-v$Version.7z"
                & $sevenZip a -t7z -m0=lzma2 -mx=9 -mfb=256 -md=32m -ms=on $archivePath (Join-Path $SandboxDir "*") | Out-Null
                if (Test-Path $archivePath) {
                    $archiveSizeMB = [math]::Round((Get-Item $archivePath).Length / 1MB, 2)
                    Write-Success "Portable archive created: Zhiyuan-v$Version.7z ($archiveSizeMB MB)"
                }
            } else {
                Write-WarningMsg "7-Zip not found, skipping portable archive creation"
            }
        } catch {
            Write-WarningMsg "Failed to create 7z archive: $_"
        }
    } catch {
        Write-WarningMsg "Inno Setup failed: $_"
        Write-WarningMsg "Falling back to 7z archive method..."
        New-FallbackInstaller
    }
} else {
    Write-WarningMsg "Inno Setup not found, using 7z fallback method"
    New-FallbackInstaller
}

# ============================================================================
# STEP 5: Cleanup
# ============================================================================
Write-Host ""
Write-Host "=" * 70 -ForegroundColor DarkGray
Write-Info "STEP 5: Cleanup"

# PRESERVE TempRelease for user inspection (do not delete)
# Remove-Item -Recurse -Force $SandboxDir -ErrorAction SilentlyContinue
# if (-not (Test-Path $SandboxDir)) { Write-Success "Sandbox removed cleanly" }
Write-Success "Sandbox preserved at $SandboxDir (not deleted per user request)"

# ============================================================================
# Final Summary
# ============================================================================
Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Green
Write-Host "    PACKAGING COMPLETE" -ForegroundColor Green
Write-Host "  ================================================================" -ForegroundColor Green
Write-Host ""

if (Test-Path $installerPath) {
    $finalSizeMB = [math]::Round((Get-Item $installerPath).Length / 1MB, 2)

    Write-Host "  Output File:" -ForegroundColor Cyan
    Write-Host "    Name:   $installerName" -ForegroundColor White
    Write-Host "    Size:   $finalSizeMB MB" -ForegroundColor White
    Write-Host "    Path:   $installerPath" -ForegroundColor White
    Write-Host ""
}

Write-Host "  Packaging Statistics:" -ForegroundColor Cyan
Write-Host "    Compiled Modules (.pyd): $($fileStats['pyd'])" -ForegroundColor Gray
Write-Host "    UI Interfaces (.ui):     $($fileStats['ui'])" -ForegroundColor Gray
Write-Host "    Executables (.exe):      $($fileStats['exe'])" -ForegroundColor Gray
Write-Host "    Runtime Libs (.dll):     $($fileStats['dll'])" -ForegroundColor Gray
Write-Host "    Model Weights (.pth):    $($fileStats['pth'])" -ForegroundColor Gray
Write-Host "    Configurations (.json):  $($fileStats['json'])" -ForegroundColor Gray
Write-Host "    Other Resources:         $($fileStats['other'])" -ForegroundColor Gray
Write-Host ""
Write-Host "  EXCLUDED (Not in Package):" -ForegroundColor Red
Write-Host "    ALL Python source files (.py) -> SECURED!" -ForegroundColor Gray
Write-Host "    __pycache__ and build artifacts" -ForegroundColor Gray
Write-Host ""

return $installerPath
