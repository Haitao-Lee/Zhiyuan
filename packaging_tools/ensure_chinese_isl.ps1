# ============================================================================
# ensure_chinese_isl.ps1 - Ensure ChineseSimplified.isl exists for Inno Setup
# ============================================================================
#
# If ChineseSimplified.isl is missing from the Inno Setup Languages directory,
# this script downloads it from the official Inno Setup repository.
#
# Usage: .\ensure_chinese_isl.ps1
# ============================================================================

$ErrorActionPreference = "Stop"

$innoSetupDir = $null
$candidateDirs = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 6",
    "C:\Program Files (x86)\Inno Setup 6",
    "C:\Program Files\Inno Setup 6"
)

foreach ($dir in $candidateDirs) {
    if (Test-Path $dir) {
        $innoSetupDir = $dir
        break
    }
}

if (-not $innoSetupDir) {
    Write-Host "[ERROR] Inno Setup 6 directory not found!" -ForegroundColor Red
    Write-Host "Please install Inno Setup 6 first: https://jrsoftware.org/isdl.php" -ForegroundColor Yellow
    exit 1
}

$languagesDir = Join-Path $innoSetupDir "Languages"
$islFile = Join-Path $languagesDir "ChineseSimplified.isl"

if (Test-Path $islFile) {
    Write-Host "[OK] ChineseSimplified.isl already exists at: $islFile" -ForegroundColor Green
    exit 0
}

Write-Host "[INFO] ChineseSimplified.isl not found. Downloading..." -ForegroundColor Cyan

if (-not (Test-Path $languagesDir)) {
    New-Item -ItemType Directory -Path $languagesDir -Force | Out-Null
}

$url = "https://raw.githubusercontent.com/jrsoftware/issrc/main/Files/Languages/Unofficial/ChineseSimplified.isl"

try {
    Write-Host "[INFO] Downloading from: $url" -ForegroundColor Cyan
    Invoke-WebRequest -Uri $url -OutFile $islFile -UseBasicParsing
    Write-Host "[OK] ChineseSimplified.isl downloaded successfully to: $islFile" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to download ChineseSimplified.isl: $_" -ForegroundColor Red
    Write-Host "[INFO] Creating minimal ChineseSimplified.isl from inline content..." -ForegroundColor Yellow

    $minimalIslContent = @"
; Inno Setup Chinese Simplified Language File
; Minimal version for Zhiyuan installer
; Full version available at: https://raw.githubusercontent.com/jrsoftware/issrc/main/Files/Languages/Unofficial/ChineseSimplified.isl

[LangOptions]
LanguageName=Chinese Simplified
LanguageID=$0804
LanguageCodePage=936

[Messages]
SetupAppTitle=安装
SetupWindowTitle=%1 - 安装向导
WelcomeLabel1=欢迎使用 [name] 安装向导
WelcomeLabel2=这将安装 [name] 版本 [ver] 到您的计算机中。%n%n点击"下一步"继续。
SelectDirLabel3=安装程序将把 [name] 安装到以下文件夹中。
SelectDirBrowseLabel=如需安装到其他文件夹，请点击"浏览"。
DiskSpaceGBLabel=至少需要 [gb] GB 的可用磁盘空间。
CannotInstallToNetworkDrive=安装程序无法安装到网络驱动器。
CannotInstallToUNCPath=安装程序无法安装到 UNC 路径。
InvalidPath=请输入完整的驱动器路径，例如:%n%nC:\App%n%n或 UNC 路径:%n%n\\server\share
InvalidDrive=所选驱动器或 UNC 路径不存在或无法访问。请选择其他位置。
DiskSpaceWarning=至少需要 %1 KB 的可用磁盘空间，但所选驱动器只有 %2 KB 可用。%n%n是否仍要继续？
DirNameTooLong=目录名称太长。
DirDoesntExist=目录 %n%n%1%n%n不存在。是否要创建该目录？
DirExistsTitle=目录已存在
DirExists=目录 %n%n%1%n%n已存在。是否仍要安装到此目录？
SelectDirLabel2=安装程序将把 [name] 安装到以下文件夹中。
SelectDir3=选择 [name] 的安装位置：
ReadyLabel1=安装程序已准备好将 [name] 安装到您的计算机中。
ReadyLabel2a=点击"安装"开始安装，或点击"上一步"修改设置。
ReadyLabel2b=点击"安装"开始安装。
ReadyMemoDir=安装位置：
InstallingLabel=正在安装，请稍候...
FinishedHeadingLabel=[name] 安装完成
FinishedLabelNoIcons=[name] 已成功安装到您的计算机。%n%n%1%n点击"完成"关闭此向导。
FinishedLabel=[name] 已成功安装到您的计算机。%n%n%1%n点击"完成"关闭此向导。
ClickFinish=&完成
FinishedRestartLabel=要完成安装，必须重新启动计算机。是否立即重新启动？
FinishedRestartMessage=要完成安装，必须重新启动计算机。%n%n是否立即重新启动？
ShowReadmeCheck=查看自述文件
YesRadio=是，立即重新启动计算机(&Y)
NoRadio=否，稍后重新启动计算机(&N)
RunEntryExec=启动 %1
RunEntryShellExec=查看 %1
ChangeDiskTitle=需要下一张磁盘
SelectDiskLabel2=请插入磁盘 %1 并点击"确定"。%n%n如果文件位于其他位置，请输入正确路径或点击"浏览"。
PathLabel=路径(&P)：
FileNotInDir2=在 "%2" 中找不到文件 "%1"。请输入正确路径或点击"浏览"。
SelectDirectoryLabel=请指定下一张磁盘的位置。
SetupAborted=安装未完成。%n%n请修正问题并重新运行安装程序。
AbortRetryIgnoreSelectAction=选择操作
AbortRetryIgnoreRetryButton=重试(&T)
AbortRetryIgnoreIgnoreButton=忽略错误并继续(&I)
AbortRetryIgnoreAbortButton=中止安装(&A)
ExitSetupTitle=退出安装
ExitSetupMessage=安装尚未完成。如果现在退出，程序将不会被安装。%n%n您可以稍后再次运行安装程序完成安装。%n%n是否退出安装？
AboutSetupMenuItem=关于安装程序(&A)...
AboutSetupTitle=关于安装程序
AboutSetupMessage=%1 版本 %2%n%3%n%n%1 主页:%n%4
TranslatorCredits=简体中文翻译
ButtonNext=下一步(&N) >
ButtonInstall=安装(&I)
ButtonBack=< 上一步(&B)
ButtonCancel=取消
ButtonFinish=完成(&F)
ButtonYes=是(&Y)
ButtonYesToAll=全部是(&A)
ButtonNo=否(&N)
ButtonNoToAll=全部否(&O)
ButtonBrowse=浏览(&R)...
ButtonWizardBrowse=浏览(&R)...
ButtonNewFolder=新建文件夹(&M)
"@

    Set-Content -Path $islFile -Value $minimalIslContent -Encoding UTF8
    Write-Host "[OK] Minimal ChineseSimplified.isl created at: $islFile" -ForegroundColor Green
    Write-Host "[WARN] This is a minimal version. For full translation, download from:" -ForegroundColor Yellow
    Write-Host "       $url" -ForegroundColor Yellow
}

exit 0
